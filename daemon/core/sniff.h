#ifndef SENKO_SNIFF_H
#define SENKO_SNIFF_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* the name a connection is for, read from the first bytes the client sends.
   a firewall redirect or the connect hook only ever hands the daemon an
   address, and a rule like "this site goes around the vpn" is about names, so
   the name comes from the tls client hello (sni) or the http host header */

typedef enum {
    SNIFF_FOUND = 0,    /* host holds the name */
    SNIFF_NEED_MORE,    /* looks like tls or http, the name is not in yet */
    SNIFF_NONE          /* not tls or http, or no name in it: decide without */
} sniff_status_t;

/* host is lower case without a trailing dot or port; cap must leave room for
   the terminating nul. a buffer that is already full never answers NEED_MORE */
sniff_status_t sniff_host(const uint8_t *buf, size_t len, size_t buf_cap,
                          char *host, size_t cap);

#ifdef __cplusplus
}
#endif

#endif
