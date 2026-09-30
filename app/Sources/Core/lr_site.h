/* sites for split tunnelling: what the user typed or pasted, reduced to the
   host a routing rule can match, and the head domain of a host.

   a site is matched in one of two ways (the daemon's rule types):
     exact  ("domain")         xyz.abc.com: every page of xyz.abc.com only
     head   ("domain-suffix")  abc.com: every page of abc.com and of every
                               name under it (www.abc.com, xyz.abc.com...)
   paths never matter: routing sees the host (dns name, tls sni), not the
   page, so the ui's "abc.com/..." just means every page of abc.com.

   plain c with no allocation so the host tests run it */
#ifndef LR_SITE_H
#define LR_SITE_H

#include <stddef.h>

#define LR_SITE_MAX 256

typedef enum {
    LR_SITE_NAME = 0,     /* a domain name, ascii (idn labels in punycode) */
    LR_SITE_IPV4,         /* 1.2.3.4 */
    LR_SITE_CIDR          /* 1.2.3.0/24 */
} lr_site_kind_t;

/* reduce input to a host: trims, lower cases, drops a scheme, user info, a
   port, a path, a query; "*.abc.com" and ".abc.com" set *wildcard; an idn
   name ("пример.рф", "Straße.de") becomes punycode ("xn--e1afmkfd.xn--p1ai").
   returns 0 and fills out/kind, or -1 when this is not a host */
int lr_site_parse(const char *input, char *out, size_t cap, lr_site_kind_t *kind, int *wildcard);

/* the registrable ("head") domain of a host: the label left of its public
   suffix, with the suffix. "music.youtube.com" -> "youtube.com",
   "news.bbc.co.uk" -> "bbc.co.uk", "user.github.io" -> "user.github.io".
   a host that is already a head (or a single label) comes back as it is.
   returns a pointer into host */
const char *lr_site_head(const char *host);

/* the host for people: xn-- labels back in their own letters (utf-8).
   a label that does not decode is kept as it is */
void lr_site_display(const char *host, char *out, size_t cap);

/* punycode one label of code points (rfc 3492), without the xn-- prefix.
   returns the length written, or -1 when it does not fit */
int lr_punycode_encode(const unsigned *cp, size_t n, char *out, size_t cap);
/* and back: returns the number of code points, or -1 */
int lr_punycode_decode(const char *in, size_t len, unsigned *cp, size_t cap);

#endif
