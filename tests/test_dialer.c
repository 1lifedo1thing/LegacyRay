#define _DEFAULT_SOURCE

#include "dialer.h"

#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

static int failed;

static void check(int ok, const char *name) {
    if (!ok) { fprintf(stderr, "FAIL %s\n", name); failed = 1; }
}

static long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static int listener(uint16_t *port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in a;
    memset(&a, 0, sizeof a);
    a.sin_family = AF_INET;
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    socklen_t len = sizeof a;
    if (fd < 0 || bind(fd, (struct sockaddr *)&a, sizeof a) != 0 || listen(fd, 4) != 0 ||
        getsockname(fd, (struct sockaddr *)&a, &len) != 0)
        return -1;
    *port = ntohs(a.sin_port);
    return fd;
}

/* the list the routing bypass is built from: "a, b, c", and nothing but
   ipv4 literals may come out of it */
static void test_pin_parsing(void) {
    dialer_ctx_t d;
    dialer_set_target(&d, "server.example", 443);
    dialer_pin_ipv4(&d, "10.0.0.1, 10.0.0.2,bad, 300.1.1.1,  10.0.0.3,");
    check(d.pinned_n == 3, "pins keep only the ipv4 literals");
    check(d.pinned_n == 3 && strcmp(d.pinned[0], "10.0.0.1") == 0 &&
          strcmp(d.pinned[1], "10.0.0.2") == 0 && strcmp(d.pinned[2], "10.0.0.3") == 0,
          "pins keep their order");
    dialer_pin_ipv4(&d, "1.1.1.1, 1.1.1.2, 1.1.1.3, 1.1.1.4, 1.1.1.5, 1.1.1.6, 1.1.1.7, 1.1.1.8, 1.1.1.9");
    check(d.pinned_n == DIALER_MAX_PINNED, "pins stop at the table size");
    dialer_set_target(&d, "other.example", 443);
    check(d.pinned_n == 0, "a new target drops the old pins");
    dialer_pin_ipv4(&d, NULL);
    check(d.pinned_n == 0, "no list pins nothing");
}

/* once the firewall sends dns into the tunnel, the dialer must reach the
   server without asking dns at all: a name that can never resolve still
   connects through its pinned address */
static void test_pinned_dial_skips_dns(void) {
    uint16_t port = 0;
    int lfd = listener(&port);
    check(lfd >= 0, "listener");
    if (lfd < 0) return;
    dialer_ctx_t d;
    dialer_set_target(&d, "never-resolves.invalid", port);
    dialer_pin_ipv4(&d, "127.0.0.1");
    long start = now_ms();
    int fd = dialer_connect(&d);
    check(fd >= 0, "pinned dial gets a socket without dns");
    check(now_ms() - start < 500, "pinned dial does not wait on a lookup");
    struct pollfd p = { lfd, POLLIN, 0 };
    check(poll(&p, 1, 2000) == 1, "pinned dial reaches the pinned address");
    int afd = accept(lfd, NULL, NULL);
    check(afd >= 0, "listener accepts the pinned dial");
    if (afd >= 0) close(afd);
    if (fd >= 0) close(fd);
    close(lfd);
}

/* without pins the lookup is bounded, so a resolver that never answers
   cannot freeze the loop the dialer runs on */
static void test_unpinned_lookup_is_bounded(void) {
    dialer_ctx_t d;
    dialer_set_target(&d, "never-resolves.invalid", 443);
    long start = now_ms();
    int fd = dialer_connect(&d);
    check(fd < 0, "an unresolvable name gives no socket");
    check(now_ms() - start < 4000, "the lookup gives up within its bound");
    if (fd >= 0) close(fd);
}

int main(void) {
    test_pin_parsing();
    test_pinned_dial_skips_dns();
    test_unpinned_lookup_is_bounded();
    if (failed) return 1;
    printf("all dialer checks passed\n");
    return 0;
}
