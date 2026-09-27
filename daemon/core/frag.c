#define _DEFAULT_SOURCE
#include "frag.h"

#include <errno.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

#include <openssl/rand.h>

static volatile int g_enabled;
static volatile int g_min = 100;
static volatile int g_max = 200;
static volatile int g_delay = 10;

void frag_configure(int enabled, int min_bytes, int max_bytes, int delay_ms) {
    if (min_bytes < 1) min_bytes = 1;
    if (min_bytes > 1000) min_bytes = 1000;
    if (max_bytes < min_bytes) max_bytes = min_bytes;
    if (max_bytes > 1000) max_bytes = 1000;
    if (delay_ms < 0) delay_ms = 0;
    if (delay_ms > 500) delay_ms = 500;
    g_min = min_bytes;
    g_max = max_bytes;
    g_delay = delay_ms;
    g_enabled = enabled ? 1 : 0;
}

int frag_enabled(void) {
    return g_enabled;
}

static int wait_writable(int fd, int *budget_ms) {
    if (*budget_ms <= 0) return -1;
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = POLLOUT;
    pfd.revents = 0;
    int slice = *budget_ms > 1000 ? 1000 : *budget_ms;
    int pr = poll(&pfd, 1, slice);
    *budget_ms -= slice;
    return pr < 0 && errno != EINTR ? -1 : 0;
}

static int write_span(int fd, const uint8_t *buf, size_t len, int *budget_ms) {
    size_t off = 0;
    while (off < len) {
        ssize_t w = send(fd, buf + off, len - off, 0);
        if (w > 0) { off += (size_t)w; continue; }
        if (w < 0 && errno == EINTR) continue;
        if (w < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            if (wait_writable(fd, budget_ms) != 0) return -1;
            continue;
        }
        return -1;
    }
    return 0;
}

int frag_write_all(int fd, const uint8_t *buf, size_t len, int budget_ms) {
    if (fd < 0 || (!buf && len)) return -1;
    if (!g_enabled || len <= 1) return write_span(fd, buf, len, &budget_ms);

    int min = g_min, max = g_max, delay = g_delay;
    int on = 1, off = 0;
    (void)setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &on, sizeof on);
    size_t at = 0;
    int rc = 0;
    while (at < len) {
        unsigned span = (unsigned)min;
        if (max > min) {
            unsigned char r[2];
            if (RAND_bytes(r, sizeof r) == 1)
                span += ((unsigned)r[0] << 8 | r[1]) % (unsigned)(max - min + 1);
        }
        if (span > len - at) span = (unsigned)(len - at);
/* the rest of a record goes in one piece once the hello's name is past */
        if (at >= 512) span = (unsigned)(len - at);
        if (write_span(fd, buf + at, span, &budget_ms) != 0) { rc = -1; break; }
        at += span;
        if (at < len && delay > 0) usleep((useconds_t)delay * 1000u);
    }
    (void)setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &off, sizeof off);
    return rc;
}
