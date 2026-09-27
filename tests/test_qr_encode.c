/* the share screens draw qr codes with lr_qr; every one of them has to scan.
   this reads symbols of many sizes and every level back with zbar */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <zbar.h>
#include "lr_qr.h"

static int failures;

static int decode(const lr_qr_t *q, int scale, char *out, size_t cap) {
    int quiet = 4;
    unsigned w = (unsigned)((q->size + quiet * 2) * scale);
    uint8_t *px = (uint8_t *)malloc((size_t)w * w);
    memset(px, 255, (size_t)w * w);
    for (int y = 0; y < q->size; ++y)
        for (int x = 0; x < q->size; ++x) {
            if (!lr_qr_dark(q, x, y)) continue;
            for (int dy = 0; dy < scale; ++dy)
                memset(px + (size_t)((y + quiet) * scale + dy) * w + (size_t)(x + quiet) * scale,
                       0, (size_t)scale);
        }
    zbar_image_scanner_t *scanner = zbar_image_scanner_create();
    zbar_image_t *image = zbar_image_create();
    zbar_image_scanner_enable_cache(scanner, 0);
    zbar_image_set_format(image, zbar_fourcc('Y', '8', '0', '0'));
    zbar_image_set_size(image, w, w);
    zbar_image_set_data(image, px, (unsigned long)w * w, zbar_image_free_data);
    int found = zbar_scan_image(scanner, image);
    int ok = -1;
    if (found >= 1) {
        const zbar_symbol_t *sym = zbar_image_first_symbol(image);
        unsigned n = zbar_symbol_get_data_length(sym);
        if (n < cap) {
            memcpy(out, zbar_symbol_get_data(sym), n);
            out[n] = '\0';
            ok = (int)n;
        }
    }
    zbar_image_destroy(image);
    zbar_image_scanner_destroy(scanner);
    return ok;
}

static void check(size_t len, lr_qr_ecc_t ecc, unsigned seed) {
    static char text[3000], back[4000];
    static const char alphabet[] =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~:/?#[]@!$&'()*+,;=%";
    srand(seed);
    for (size_t i = 0; i < len; ++i) text[i] = alphabet[rand() % (int)(sizeof alphabet - 1)];
    text[len] = '\0';
    static lr_qr_t q;
    if (lr_qr_encode((const uint8_t *)text, len, ecc, &q) != 0) {
        printf("FAIL encode len=%zu ecc=%d\n", len, (int)ecc);
        ++failures;
        return;
    }
    int n = decode(&q, q.size > 100 ? 3 : 4, back, sizeof back);
    if (n != (int)len || memcmp(back, text, len) != 0) {
        printf("FAIL decode len=%zu ecc=%d version=%d got=%d\n", len, (int)ecc, q.version, n);
        ++failures;
    }
}

int main(void) {
    static const size_t lens[] = { 1, 7, 14, 17, 25, 32, 53, 78, 106, 134, 154, 192, 230, 271, 321,
                                   367, 425, 458, 520, 586, 644, 718, 792, 858, 929, 1003, 1091,
                                   1171, 1273, 1367, 1465, 1528, 1628, 1732, 1840, 1952, 2068,
                                   2188, 2303, 2431, 2563, 2699, 2809, 2953 };
    for (size_t i = 0; i < sizeof lens / sizeof lens[0]; ++i)
        check(lens[i], LR_QR_ECC_L, (unsigned)i + 1);
    for (int e = 0; e < 4; ++e)
        for (size_t len = 5; len < 1300; len = len * 3 / 2 + 7)
            check(len, (lr_qr_ecc_t)e, (unsigned)(len * 13 + (size_t)e));
    static lr_qr_t q;
    char big[3000];
    memset(big, 'a', sizeof big);
    if (lr_qr_encode((const uint8_t *)big, sizeof big, LR_QR_ECC_L, &q) == 0) {
        printf("FAIL oversized input encoded\n");
        ++failures;
    }
    if (failures) {
        printf("%d qr check(s) failed\n", failures);
        return 1;
    }
    printf("all qr encode checks passed\n");
    return 0;
}
