#ifndef LEGACYRAY_FRAG_H
#define LEGACYRAY_FRAG_H

/* tls hello fragmentation, happ's "fragmentation": the first flight of a tls
   or reality handshake goes out as several small tcp segments with a short
   pause between them. a dpi box that reads the server name out of the first
   segment it sees gets a few bytes of it instead. the server reassembles the
   stream as always, so nothing changes on its side, reality included */

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* sizes are clamped to 1..1000 bytes and the delay to 0..500 ms */
void frag_configure(int enabled, int min_bytes, int max_bytes, int delay_ms);
int  frag_enabled(void);

/* write all of buf. when fragmentation is on it goes out in segments with
   TCP_NODELAY set for the duration; otherwise it is a plain full write.
   waits up to budget_ms in total for a socket that is not writable */
int frag_write_all(int fd, const uint8_t *buf, size_t len, int budget_ms);

#ifdef __cplusplus
}
#endif

#endif
