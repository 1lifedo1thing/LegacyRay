#ifndef DIALER_H
#define DIALER_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define DIALER_MAX_PINNED 8

typedef struct {
    char     host[256];
    char     port[8]; /* keep the service in getaddrinfo format */
/* the addresses a full-device connect resolved before routing came up. after
   that the firewall hands every dns query to the tunnel, so a lookup here
   would wait on the very tunnel it is dialing */
    char     pinned[DIALER_MAX_PINNED][16];
    size_t   pinned_n;
} dialer_ctx_t;

/* a new target drops the addresses pinned for the previous one */
void dialer_set_target(dialer_ctx_t *d, const char *host, int port);

/* ip_list is the comma separated ipv4 list the routing bypass was built from */
void dialer_pin_ipv4(dialer_ctx_t *d, const char *ip_list);

int dialer_connect(void *ctx);

#ifdef __cplusplus
}
#endif

#endif /* dialer_h */
