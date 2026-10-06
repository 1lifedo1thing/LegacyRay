#include "../daemon/loop.c"
#include <assert.h>
#include <stdlib.h>
#include <signal.h>

/* the site: answers "pong:" and the request, then closes */
static int g_site_fd = -1;
static uint16_t g_site_port;
static int g_bypass_calls;
static int g_dials;

static void *site_main(void *arg) {
    int n_conns = *(int *)arg;
    for (int k = 0; k < n_conns; ++k) {
        int fd = accept(g_site_fd, NULL, NULL);
        if (fd < 0) return NULL;
        char buf[512];
        ssize_t n = read(fd, buf, sizeof buf);
        if (n > 0) {
            assert(write(fd, "pong:", 5) == 5);
            assert(write(fd, buf, (size_t)n) == n);
        }
        close(fd);
    }
    return NULL;
}

static int count_dial(void *ctx) {
    (void)ctx;
    ++g_dials;
    return -1; /* the tunnel is not part of this test */
}

static loop_route_t route(void *ctx, const vless_dest_t *dest, const char *host) {
    (void)ctx;
    assert(dest->atyp == VLESS_ADDR_IPV4 && dest->port == g_site_port);
    if (!host) return LOOP_ROUTE_SNIFF;
    if (strcmp(host, "direct.test") == 0) return LOOP_ROUTE_DIRECT;
    if (strcmp(host, "block.test") == 0) return LOOP_ROUTE_BLOCK;
    return LOOP_ROUTE_PROXY;
}

static int bypass(void *ctx, const char *ip) {
    (void)ctx;
    assert(ip && strcmp(ip, "127.0.0.1") == 0);
    ++g_bypass_calls;
    return 0;
}

typedef struct {
    uint16_t proxy_port;
    const char *host;
    char got[1024];
    size_t got_len;
    int reply_ok;
    volatile int done;
} client_t;

static void *client_main(void *arg) {
    client_t *cl = (client_t *)arg;
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in sa;
    memset(&sa, 0, sizeof sa);
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    sa.sin_port = htons(cl->proxy_port);
    assert(connect(fd, (struct sockaddr *)&sa, sizeof sa) == 0);
    uint8_t greet[3] = { 5, 1, 0 };
    assert(write(fd, greet, 3) == 3);
    uint8_t r[16];
    assert(read(fd, r, 2) == 2 && r[0] == 5 && r[1] == 0);
    uint8_t req[10] = { 5, 1, 0, 1, 127, 0, 0, 1, 0, 0 };
    req[8] = (uint8_t)(g_site_port >> 8);
    req[9] = (uint8_t)g_site_port;
    assert(write(fd, req, 10) == 10);
    /* the reply arrives before any byte reaches a server */
    assert(read(fd, r, 10) == 10);
    cl->reply_ok = r[0] == 5 && r[1] == 0;
    char http[256];
    int hl = snprintf(http, sizeof http, "GET / HTTP/1.1\r\nHost: %s\r\n\r\n", cl->host);
    assert(write(fd, http, (size_t)hl) == hl);
    for (;;) {
        ssize_t n = read(fd, cl->got + cl->got_len, sizeof cl->got - 1 - cl->got_len);
        if (n <= 0) break;
        cl->got_len += (size_t)n;
    }
    cl->got[cl->got_len] = '\0';
    close(fd);
    cl->done = 1;
    return NULL;
}

static void run_client(loop_t *lp, client_t *cl) {
    pthread_t t;
    cl->proxy_port = loop_listen_port(lp);
    assert(pthread_create(&t, NULL, client_main, cl) == 0);
    for (int i = 0; i < 400 && !cl->done; ++i) assert(loop_step(lp, 25) == LOOP_OK);
    assert(cl->done);
    pthread_join(t, NULL);
}

int main(void) {
    signal(SIGPIPE, SIG_IGN);
    g_site_fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in sa;
    memset(&sa, 0, sizeof sa);
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    assert(bind(g_site_fd, (struct sockaddr *)&sa, sizeof sa) == 0);
    assert(listen(g_site_fd, 8) == 0);
    socklen_t sl = sizeof sa;
    assert(getsockname(g_site_fd, (struct sockaddr *)&sa, &sl) == 0);
    g_site_port = ntohs(sa.sin_port);
    int expected = 1;
    pthread_t site;
    assert(pthread_create(&site, NULL, site_main, &expected) == 0);

    loop_t *lp = calloc(1, sizeof *lp);
    assert(loop_init(lp, 0, 0, &transport_tcp, count_dial, NULL, VL_PROTO_HTTP,
                     NULL, NULL, NULL, NULL) == LOOP_OK);
    loop_set_router(lp, route, bypass, NULL);

    client_t direct;
    memset(&direct, 0, sizeof direct);
    direct.host = "direct.test";
    run_client(lp, &direct);
    assert(direct.reply_ok);
    assert(strncmp(direct.got, "pong:GET / HTTP/1.1\r\nHost: direct.test", 38) == 0);
    assert(g_bypass_calls == 1 && g_dials == 0);
    pthread_join(site, NULL);

    client_t blocked;
    memset(&blocked, 0, sizeof blocked);
    blocked.host = "block.test";
    run_client(lp, &blocked);
    assert(blocked.reply_ok && blocked.got_len == 0 && g_dials == 0);

    /* a site the router keeps in the tunnel goes to the dialer */
    client_t proxied;
    memset(&proxied, 0, sizeof proxied);
    proxied.host = "other.test";
    run_client(lp, &proxied);
    assert(proxied.got_len == 0 && g_dials > 0);

    for (int i = 0; i < 20; ++i) (void)loop_step(lp, 10);
    loop_close(lp);
    free(lp);
    close(g_site_fd);
    puts("all loop routing checks passed");
    return 0;
}
