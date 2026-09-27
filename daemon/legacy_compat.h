/* legacyray: shims for ios 4.0-4.2. everything the daemon calls exists on
   ios 5, which is what senko targeted; the few libsystem entry points that
   arrived later than ios 4.0 are replaced here so the binary still launches
   there instead of dying in dyld on a missing symbol. forced in with -include
   by Makefile.ios, never by the host tests */
#ifndef LEGACYRAY_COMPAT_H
#define LEGACYRAY_COMPAT_H

#if defined(__APPLE__) && defined(__arm__)
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* arc4random_buf is ios 4.3+; arc4random itself has been there since 2.0 */
static inline void legacyray_arc4random_buf(void *buf, size_t n) {
    unsigned char *p = (unsigned char *)buf;
    while (n >= 4) {
        uint32_t v = arc4random();
        memcpy(p, &v, 4);
        p += 4;
        n -= 4;
    }
    if (n) {
        uint32_t v = arc4random();
        memcpy(p, &v, n);
    }
}
#define arc4random_buf legacyray_arc4random_buf
#endif

#endif
