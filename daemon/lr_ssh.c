/* legacyray-ssh: the app's way onto a user's own server, for setting up and
   managing it the way the amnezia client does. it runs as the mobile user and
   talks to the app over pipes:

     legacyray-ssh <host> <port> <user>

   stdin, one line each (values base64):
     AUTH password <pass>            or   AUTH key <pem> [<passphrase>]
     HOSTKEY <sha256 base64> | -     (- only prints the key and stops)
     RUN <script>                    (run with bash as root, via sudo -S when needed)

   stdout, one line each:
     HOSTKEY <type> <sha256 base64>
     STAGE connected | authenticated | running
     OUT <text> / ERR <text>         remote output as it arrives
     EXIT <status>
     FAIL <reason>                   and a non-zero exit status */
#define _DEFAULT_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#include <libssh2.h>
#include <openssl/crypto.h>

#include "core/b64.h"

#define LR_SSH_CONNECT_MS 12000
#define LR_SSH_IO_MS      30000
#define LR_SSH_MAX_LINE   (512 * 1024)

static void fail(const char *fmt, const char *detail) {
    printf("FAIL ");
    printf(fmt, detail ? detail : "");
    printf("\n");
    fflush(stdout);
}

static char *read_line(FILE *f) {
    size_t cap = 4096, len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) return NULL;
    int c;
    while ((c = fgetc(f)) != EOF && c != '\n') {
        if (len + 1 >= cap) {
            if (cap >= LR_SSH_MAX_LINE) { free(buf); return NULL; }
            cap *= 2;
            char *n = (char *)realloc(buf, cap);
            if (!n) { free(buf); return NULL; }
            buf = n;
        }
        buf[len++] = (char)c;
    }
    if (c == EOF && len == 0) { free(buf); return NULL; }
    if (len && buf[len - 1] == '\r') --len;
    buf[len] = '\0';
    return buf;
}

/* a base64 field decoded into a fresh nul-terminated buffer */
static char *decode_field(const char *text, size_t *out_len) {
    size_t n = strlen(text);
    size_t cap = b64_decoded_maxlen(n) + 1;
    unsigned char *out = (unsigned char *)malloc(cap);
    size_t len = 0;
    if (!out || b64_decode(text, n, out, cap, &len) != 0) { free(out); return NULL; }
    out[len] = '\0';
    if (out_len) *out_len = len;
    return (char *)out;
}

static void b64_line(const char *tag, const unsigned char *data, size_t len) {
    size_t cap = b64_encoded_maxlen(len) + 1;
    char *out = (char *)malloc(cap);
    size_t n = 0;
    if (out && b64_encode(data, len, out, cap, &n) == 0) {
        out[n] = '\0';
        printf("%s%s", tag, out);
    }
    free(out);
}

static int dial(const char *host, const char *port) {
    struct addrinfo hints, *res = NULL;
    memset(&hints, 0, sizeof hints);
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_family = AF_UNSPEC;
    if (getaddrinfo(host, port, &hints, &res) != 0 || !res) return -1;
    int fd = -1;
    for (struct addrinfo *ai = res; ai; ai = ai->ai_next) {
        fd = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
        if (fd < 0) continue;
        int fl = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, fl | O_NONBLOCK);
        int rc = connect(fd, ai->ai_addr, ai->ai_addrlen);
        if (rc != 0 && errno == EINPROGRESS) {
            struct pollfd pfd = { fd, POLLOUT, 0 };
            int err = 0;
            socklen_t el = sizeof err;
            if (poll(&pfd, 1, LR_SSH_CONNECT_MS) == 1 &&
                getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &el) == 0 && err == 0)
                rc = 0;
        }
        if (rc == 0) {
            fcntl(fd, F_SETFL, fl);
            break;
        }
        close(fd);
        fd = -1;
    }
    freeaddrinfo(res);
    return fd;
}

static const char *key_type_name(int type) {
    switch (type) {
        case LIBSSH2_HOSTKEY_TYPE_RSA: return "ssh-rsa";
        case LIBSSH2_HOSTKEY_TYPE_DSS: return "ssh-dss";
#ifdef LIBSSH2_HOSTKEY_TYPE_ECDSA_256
        case LIBSSH2_HOSTKEY_TYPE_ECDSA_256: return "ecdsa-sha2-nistp256";
        case LIBSSH2_HOSTKEY_TYPE_ECDSA_384: return "ecdsa-sha2-nistp384";
        case LIBSSH2_HOSTKEY_TYPE_ECDSA_521: return "ecdsa-sha2-nistp521";
#endif
#ifdef LIBSSH2_HOSTKEY_TYPE_ED25519
        case LIBSSH2_HOSTKEY_TYPE_ED25519: return "ssh-ed25519";
#endif
        default: return "unknown";
    }
}

/* forward what arrived on one channel stream as OUT / ERR lines */
typedef struct {
    char buf[8192];
    size_t len;
} line_buf_t;

static void flush_lines(line_buf_t *lb, const char *tag, int final) {
    size_t start = 0;
    for (size_t i = 0; i < lb->len; ++i) {
        if (lb->buf[i] != '\n') continue;
        size_t n = i - start;
        if (n && lb->buf[start + n - 1] == '\r') --n;
        printf("%s %.*s\n", tag, (int)n, lb->buf + start);
        start = i + 1;
    }
    if (start) {
        memmove(lb->buf, lb->buf + start, lb->len - start);
        lb->len -= start;
    }
    if ((final && lb->len) || lb->len == sizeof lb->buf) {
        printf("%s %.*s\n", tag, (int)lb->len, lb->buf);
        lb->len = 0;
    }
    fflush(stdout);
}

static int pump_stream(LIBSSH2_CHANNEL *ch, int stream, line_buf_t *lb, const char *tag) {
    int got = 0;
    for (;;) {
        size_t room = sizeof lb->buf - lb->len;
        ssize_t n = libssh2_channel_read_ex(ch, stream, lb->buf + lb->len, room);
        if (n > 0) {
            lb->len += (size_t)n;
            got = 1;
            flush_lines(lb, tag, 0);
            continue;
        }
        if (n == LIBSSH2_ERROR_EAGAIN || n == 0) break;
        return -1;
    }
    return got;
}

/* servers that turn plain password sign-in off often still take the same
   password through keyboard-interactive, answering every prompt with it */
static const char *g_kbd_password;

static void kbd_answer(const char *name, int name_len, const char *instruction, int instruction_len,
                       int num_prompts, const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
                       LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses, void **abstract) {
    (void)name; (void)name_len; (void)instruction; (void)instruction_len;
    (void)prompts; (void)abstract;
    for (int i = 0; i < num_prompts; ++i) {
        size_t n = g_kbd_password ? strlen(g_kbd_password) : 0;
        responses[i].text = n ? strdup(g_kbd_password) : NULL;
        responses[i].length = responses[i].text ? (unsigned int)n : 0;
    }
}

static const char *shell_quote_free_b64(const char *s) {
    for (const char *p = s; *p; ++p)
        if (!((*p >= 'A' && *p <= 'Z') || (*p >= 'a' && *p <= 'z') || (*p >= '0' && *p <= '9') ||
              *p == '+' || *p == '/' || *p == '='))
            return NULL;
    return s;
}

int main(int argc, char **argv) {
    signal(SIGPIPE, SIG_IGN);
    OPENSSL_init_crypto(OPENSSL_INIT_NO_ATEXIT, NULL);
    if (argc != 4) {
        fail("usage: legacyray-ssh <host> <port> <user>%s", NULL);
        return 2;
    }
    const char *host = argv[1], *port = argv[2], *user = argv[3];

    char *auth = read_line(stdin);
    char *hostkey_line = read_line(stdin);
    char *run = read_line(stdin);
    if (!auth || !hostkey_line || strncmp(auth, "AUTH ", 5) != 0 ||
        strncmp(hostkey_line, "HOSTKEY ", 8) != 0) {
        fail("bad request%s", NULL);
        return 2;
    }
    const char *expect = hostkey_line + 8;
    int probe = strcmp(expect, "-") == 0;
    if (!probe && (!run || strncmp(run, "RUN ", 4) != 0 || !shell_quote_free_b64(run + 4))) {
        fail("bad request%s", NULL);
        return 2;
    }

    if (libssh2_init(0) != 0) { fail("libssh2 did not start%s", NULL); return 1; }
    int fd = dial(host, port);
    if (fd < 0) { fail("could not reach %s", host); return 1; }
    LIBSSH2_SESSION *session = libssh2_session_init();
    if (!session) { fail("no memory%s", NULL); return 1; }
    libssh2_session_set_timeout(session, LR_SSH_IO_MS);
    if (libssh2_session_handshake(session, fd) != 0) {
        char *msg = NULL;
        libssh2_session_last_error(session, &msg, NULL, 0);
        fail("ssh handshake failed: %s", msg);
        return 1;
    }
    printf("STAGE connected\n");

    size_t key_len = 0;
    int key_type = 0;
    (void)libssh2_session_hostkey(session, &key_len, &key_type);
    const unsigned char *hash = (const unsigned char *)
        libssh2_hostkey_hash(session, LIBSSH2_HOSTKEY_HASH_SHA256);
    if (!hash) { fail("the server sent no host key%s", NULL); return 1; }
    printf("HOSTKEY %s ", key_type_name(key_type));
    b64_line("", hash, 32);
    printf("\n");
    fflush(stdout);
    if (probe) {
        libssh2_session_disconnect(session, "bye");
        libssh2_session_free(session);
        close(fd);
        return 0;
    }
    {
        size_t cap = b64_encoded_maxlen(32) + 1, n = 0;
        char seen[64];
        if (cap > sizeof seen || b64_encode(hash, 32, seen, sizeof seen, &n) != 0) return 1;
        seen[n] = '\0';
        if (strcmp(seen, expect) != 0) {
            fail("the server's host key changed%s", NULL);
            return 3;
        }
    }

    /* authentication */
    char *secret = NULL;
    const char *a = auth + 5;
    int rc = -1;
    if (strncmp(a, "password ", 9) == 0) {
        secret = decode_field(a + 9, NULL);
        if (secret) rc = libssh2_userauth_password(session, user, secret);
        if (rc != 0 && secret) {
            const char *methods = libssh2_userauth_list(session, user, (unsigned int)strlen(user));
            if (methods && strstr(methods, "keyboard-interactive")) {
                g_kbd_password = secret;
                rc = libssh2_userauth_keyboard_interactive(session, user, kbd_answer);
                g_kbd_password = NULL;
            }
        }
    } else if (strncmp(a, "key ", 4) == 0) {
        char *fields = strdup(a + 4);
        char *space = fields ? strchr(fields, ' ') : NULL;
        if (space) *space++ = '\0';
        size_t pem_len = 0;
        char *pem = fields ? decode_field(fields, &pem_len) : NULL;
        char *pass = space ? decode_field(space, NULL) : NULL;
        if (pem)
            rc = libssh2_userauth_publickey_frommemory(session, user, strlen(user), NULL, 0,
                                                       pem, pem_len, pass);
        if (pem) { OPENSSL_cleanse(pem, pem_len); free(pem); }
        if (pass) { secret = pass; }
        free(fields);
    }
    if (rc != 0) {
        char *msg = NULL;
        libssh2_session_last_error(session, &msg, NULL, 0);
        fail("sign-in refused: %s", msg);
        return 4;
    }
    printf("STAGE authenticated\n");
    fflush(stdout);

    /* the script goes as base64 in the command, lands in a private temp file
       and runs under bash; a non-root user goes through sudo -S, which takes
       the password from the channel's stdin */
    LIBSSH2_CHANNEL *ch = libssh2_channel_open_session(session);
    if (!ch) { fail("could not open a channel%s", NULL); return 1; }
    const char *script = run + 4;
    size_t cmd_cap = strlen(script) + 512;
    char *cmd = (char *)malloc(cmd_cap);
    if (!cmd) return 1;
    snprintf(cmd, cmd_cap,
             "umask 077; f=$(mktemp /tmp/legacyray.XXXXXX) || exit 97; "
             "echo '%s' | base64 -d > \"$f\" || exit 98; "
             "if [ \"$(id -u)\" = 0 ]; then bash \"$f\"; rc=$?; "
             "else sudo -S -p '' bash \"$f\"; rc=$?; fi; rm -f \"$f\"; exit $rc",
             script);
    if (libssh2_channel_exec(ch, cmd) != 0) {
        char *msg = NULL;
        libssh2_session_last_error(session, &msg, NULL, 0);
        fail("the server did not run the script: %s", msg);
        return 1;
    }
    free(cmd);
    if (secret && strncmp(a, "password ", 9) == 0 && strcmp(user, "root") != 0) {
        (void)libssh2_channel_write(ch, secret, strlen(secret));
        (void)libssh2_channel_write(ch, "\n", 1);
    }
    if (secret) { OPENSSL_cleanse(secret, strlen(secret)); free(secret); }
    (void)libssh2_channel_send_eof(ch);
    printf("STAGE running\n");
    fflush(stdout);

    /* long installs are quiet for minutes, so reads block without a timeout
       and the socket is polled instead */
    libssh2_session_set_timeout(session, 0);
    libssh2_session_set_blocking(session, 0);
    static line_buf_t out, err;
    for (;;) {
        int a1 = pump_stream(ch, 0, &out, "OUT");
        int a2 = pump_stream(ch, SSH_EXTENDED_DATA_STDERR, &err, "ERR");
        if (a1 < 0 || a2 < 0) break;
        if (libssh2_channel_eof(ch)) break;
        if (!a1 && !a2) {
            struct pollfd pfd = { fd, POLLIN, 0 };
            int dir = libssh2_session_block_directions(session);
            pfd.events = (short)((dir & LIBSSH2_SESSION_BLOCK_INBOUND ? POLLIN : 0) |
                                 (dir & LIBSSH2_SESSION_BLOCK_OUTBOUND ? POLLOUT : 0));
            if (!pfd.events) pfd.events = POLLIN;
            if (poll(&pfd, 1, 600000) == 0) {
                fail("the server stopped answering%s", NULL);
                return 1;
            }
        }
    }
    flush_lines(&out, "OUT", 1);
    flush_lines(&err, "ERR", 1);
    libssh2_session_set_blocking(session, 1);
    libssh2_session_set_timeout(session, LR_SSH_IO_MS);
    (void)libssh2_channel_close(ch);
    (void)libssh2_channel_wait_closed(ch);
    int status = libssh2_channel_get_exit_status(ch);
    libssh2_channel_free(ch);
    libssh2_session_disconnect(session, "done");
    libssh2_session_free(session);
    close(fd);
    libssh2_exit();
    printf("EXIT %d\n", status);
    fflush(stdout);
    return status == 0 ? 0 : 5;
}
