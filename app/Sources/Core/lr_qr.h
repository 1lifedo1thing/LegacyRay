/* a qr code encoder for sharing links and profiles: byte mode, versions 1-40,
   the usual error correction levels, mask chosen by the standard penalty
   rules. written from the iso 18004 description; the host tests read every
   size back with the zbar decoder the app scans with */
#ifndef LR_QR_H
#define LR_QR_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    LR_QR_ECC_L = 0,  /* ~7% of the symbol can be lost */
    LR_QR_ECC_M,      /* ~15% */
    LR_QR_ECC_Q,      /* ~25% */
    LR_QR_ECC_H       /* ~30% */
} lr_qr_ecc_t;

#define LR_QR_MAX_SIZE 177   /* version 40 */
#define LR_QR_MAX_BYTES 2953 /* version 40 at level L */

typedef struct {
    int size;                                   /* modules per side */
    int version;
    uint8_t modules[LR_QR_MAX_SIZE * LR_QR_MAX_SIZE]; /* row major, 1 = dark */
} lr_qr_t;

/* encode len bytes at the smallest version that holds them at ecc, raising
   ecc for free when the chosen version has room. returns 0, or -1 when the
   data does not fit even version 40 */
int lr_qr_encode(const uint8_t *data, size_t len, lr_qr_ecc_t ecc, lr_qr_t *out);

static inline int lr_qr_dark(const lr_qr_t *q, int x, int y) {
    return q->modules[y * q->size + x] != 0;
}

#ifdef __cplusplus
}
#endif

#endif
