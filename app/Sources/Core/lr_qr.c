#include "lr_qr.h"

#include <stdlib.h>
#include <string.h>

/* error correction codewords per block and blocks per symbol, by level and
   version (iso 18004 table 9); index 0 is unused */
static const int8_t kEccPerBlock[4][41] = {
    {-1,  7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28,
         28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},
    {-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26,
         26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28},
    {-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30,
         28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},
    {-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28,
         30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},
};
static const int8_t kBlocks[4][41] = {
    {-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8,
         8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25},
    {-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16,
         17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49},
    {-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20,
         23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68},
    {-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25,
         25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81},
};

/* the format field's two-bit level code: L 01, M 00, Q 11, H 10 */
static const int kEccFormatBits[4] = { 1, 0, 3, 2 };

static int raw_data_modules(int ver) {
    int result = (16 * ver + 128) * ver + 64;
    if (ver >= 2) {
        int align = ver / 7 + 2;
        result -= (25 * align - 10) * align - 55;
        if (ver >= 7) result -= 36;
    }
    return result;
}

static int data_codewords(int ver, int ecc) {
    return raw_data_modules(ver) / 8 - kEccPerBlock[ecc][ver] * kBlocks[ecc][ver];
}

/* byte mode: 4 mode bits, then 8 or 16 length bits */
static int bits_needed(int ver, size_t len) {
    return 4 + (ver <= 9 ? 8 : 16) + (int)len * 8;
}

/* ---- reed-solomon over GF(256), polynomial 0x11d ---------------------------- */

static uint8_t gf_mul(uint8_t x, uint8_t y) {
    int z = 0;
    for (int i = 7; i >= 0; --i) {
        z = (z << 1) ^ ((z >> 7) * 0x11d);
        z ^= ((y >> i) & 1) * x;
    }
    return (uint8_t)z;
}

static void rs_divisor(int degree, uint8_t *out) {
    memset(out, 0, (size_t)degree);
    out[degree - 1] = 1;
    uint8_t root = 1;
    for (int i = 0; i < degree; ++i) {
        for (int j = 0; j < degree; ++j) {
            out[j] = gf_mul(out[j], root);
            if (j + 1 < degree) out[j] ^= out[j + 1];
        }
        root = gf_mul(root, 0x02);
    }
}

static void rs_remainder(const uint8_t *data, int len, const uint8_t *div, int degree,
                         uint8_t *out) {
    memset(out, 0, (size_t)degree);
    for (int i = 0; i < len; ++i) {
        uint8_t factor = data[i] ^ out[0];
        memmove(out, out + 1, (size_t)degree - 1);
        out[degree - 1] = 0;
        for (int j = 0; j < degree; ++j) out[j] ^= gf_mul(div[j], factor);
    }
}

/* ---- the symbol --------------------------------------------------------- */

typedef struct {
    int size;
    uint8_t *m;     /* modules */
    uint8_t *fn;    /* 1 where a function pattern sits */
} grid_t;

static void put(grid_t *g, int x, int y, int dark) {
    g->m[y * g->size + x] = (uint8_t)(dark ? 1 : 0);
    g->fn[y * g->size + x] = 1;
}

static void finder(grid_t *g, int cx, int cy) {
    for (int dy = -4; dy <= 4; ++dy)
        for (int dx = -4; dx <= 4; ++dx) {
            int x = cx + dx, y = cy + dy;
            if (x < 0 || y < 0 || x >= g->size || y >= g->size) continue;
            int d = abs(dx) > abs(dy) ? abs(dx) : abs(dy);
            put(g, x, y, d != 2 && d != 4);
        }
}

static void alignment(grid_t *g, int cx, int cy) {
    for (int dy = -2; dy <= 2; ++dy)
        for (int dx = -2; dx <= 2; ++dx) {
            int d = abs(dx) > abs(dy) ? abs(dx) : abs(dy);
            put(g, cx + dx, cy + dy, d != 1);
        }
}

static int alignment_positions(int ver, int size, int *out) {
    if (ver == 1) return 0;
    int n = ver / 7 + 2;
    int step = ver == 32 ? 26 : (ver * 4 + n * 2 + 1) / (n * 2 - 2) * 2;
    out[0] = 6;
    for (int i = n - 1, pos = size - 7; i >= 1; --i, pos -= step) out[i] = pos;
    return n;
}

static void format_bits(grid_t *g, int ecc, int mask) {
    int data = kEccFormatBits[ecc] << 3 | mask;
    int rem = data;
    for (int i = 0; i < 10; ++i) rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    int bits = (data << 10 | rem) ^ 0x5412;
    int s = g->size;
    for (int i = 0; i <= 5; ++i) put(g, 8, i, (bits >> i) & 1);
    put(g, 8, 7, (bits >> 6) & 1);
    put(g, 8, 8, (bits >> 7) & 1);
    put(g, 7, 8, (bits >> 8) & 1);
    for (int i = 9; i < 15; ++i) put(g, 14 - i, 8, (bits >> i) & 1);
    for (int i = 0; i < 8; ++i) put(g, s - 1 - i, 8, (bits >> i) & 1);
    for (int i = 8; i < 15; ++i) put(g, 8, s - 15 + i, (bits >> i) & 1);
    put(g, 8, s - 8, 1); /* the dark module */
}

static void version_bits(grid_t *g, int ver) {
    if (ver < 7) return;
    int rem = ver;
    for (int i = 0; i < 12; ++i) rem = (rem << 1) ^ ((rem >> 11) * 0x1f25);
    long bits = (long)ver << 12 | rem;
    for (int i = 0; i < 18; ++i) {
        int bit = (int)((bits >> i) & 1);
        int a = g->size - 11 + i % 3, b = i / 3;
        put(g, a, b, bit);
        put(g, b, a, bit);
    }
}

static void function_patterns(grid_t *g, int ver) {
    int s = g->size;
    for (int i = 0; i < s; ++i) {
        put(g, 6, i, i % 2 == 0);
        put(g, i, 6, i % 2 == 0);
    }
    finder(g, 3, 3);
    finder(g, s - 4, 3);
    finder(g, 3, s - 4);
    int pos[7];
    int n = alignment_positions(ver, s, pos);
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j) {
            if ((i == 0 && j == 0) || (i == 0 && j == n - 1) || (i == n - 1 && j == 0)) continue;
            alignment(g, pos[i], pos[j]);
        }
    format_bits(g, 0, 0); /* reserves the cells; drawn for real once the mask is known */
    version_bits(g, ver);
}

static void place_codewords(grid_t *g, const uint8_t *data, int len) {
    int s = g->size;
    int i = 0;
    for (int right = s - 1; right >= 1; right -= 2) {
        if (right == 6) right = 5;
        for (int vert = 0; vert < s; ++vert) {
            for (int j = 0; j < 2; ++j) {
                int x = right - j;
                int upward = ((right + 1) & 2) == 0;
                int y = upward ? s - 1 - vert : vert;
                if (g->fn[y * s + x] || i >= len * 8) continue;
                g->m[y * s + x] = (uint8_t)((data[i >> 3] >> (7 - (i & 7))) & 1);
                ++i;
            }
        }
    }
}

static int mask_bit(int mask, int x, int y) {
    switch (mask) {
        case 0: return (x + y) % 2 == 0;
        case 1: return y % 2 == 0;
        case 2: return x % 3 == 0;
        case 3: return (x + y) % 3 == 0;
        case 4: return (x / 3 + y / 2) % 2 == 0;
        case 5: return x * y % 2 + x * y % 3 == 0;
        case 6: return (x * y % 2 + x * y % 3) % 2 == 0;
        default: return ((x + y) % 2 + x * y % 3) % 2 == 0;
    }
}

static void apply_mask(grid_t *g, int mask) {
    int s = g->size;
    for (int y = 0; y < s; ++y)
        for (int x = 0; x < s; ++x)
            if (!g->fn[y * s + x] && mask_bit(mask, x, y)) g->m[y * s + x] ^= 1;
}

/* the four penalty rules. rule 3 looks for 1:1:3:1:1 finder lookalikes
   with four light modules on one side */
static long penalty(const grid_t *g) {
    int s = g->size;
    long score = 0;
    for (int pass = 0; pass < 2; ++pass) {
        for (int a = 0; a < s; ++a) {
            int run = 0, color = -1;
            for (int b = 0; b < s; ++b) {
                int v = pass ? g->m[b * s + a] : g->m[a * s + b];
                if (v == color) {
                    ++run;
                    if (run == 5) score += 3;
                    else if (run > 5) score += 1;
                } else {
                    color = v;
                    run = 1;
                }
            }
            for (int b = 0; b + 7 <= s; ++b) {
                int p[7];
                for (int k = 0; k < 7; ++k)
                    p[k] = pass ? g->m[(b + k) * s + a] : g->m[a * s + b + k];
                if (!(p[0] && !p[1] && p[2] && p[3] && p[4] && !p[5] && p[6])) continue;
                int light_before = 1, light_after = 1;
                for (int k = 1; k <= 4; ++k) {
                    int bb = b - k, ba = b + 6 + k;
                    if (bb >= 0 && (pass ? g->m[bb * s + a] : g->m[a * s + bb])) light_before = 0;
                    if (ba < s && (pass ? g->m[ba * s + a] : g->m[a * s + ba])) light_after = 0;
                }
                if (light_before || light_after) score += 40;
            }
        }
    }
    for (int y = 0; y + 1 < s; ++y)
        for (int x = 0; x + 1 < s; ++x) {
            int v = g->m[y * s + x];
            if (v == g->m[y * s + x + 1] && v == g->m[(y + 1) * s + x] &&
                v == g->m[(y + 1) * s + x + 1])
                score += 3;
        }
    long dark = 0;
    for (int i = 0; i < s * s; ++i) dark += g->m[i];
    long total = (long)s * s;
    long k = (labs(dark * 20 - total * 10) + total - 1) / total - 1;
    if (k > 0) score += k * 10;
    return score;
}

int lr_qr_encode(const uint8_t *data, size_t len, lr_qr_ecc_t ecc, lr_qr_t *out) {
    if ((!data && len) || !out || (int)ecc < 0 || ecc > LR_QR_ECC_H) return -1;
    int ver;
    for (ver = 1; ver <= 40; ++ver)
        if (bits_needed(ver, len) <= data_codewords(ver, ecc) * 8) break;
    if (ver > 40) return -1;
    for (int e = (int)ecc + 1; e <= LR_QR_ECC_H; ++e)
        if (bits_needed(ver, len) <= data_codewords(ver, e) * 8) ecc = (lr_qr_ecc_t)e;

    int cap = data_codewords(ver, ecc);
    uint8_t *cw = (uint8_t *)calloc((size_t)cap, 1);
    if (!cw) return -1;
    /* the bit stream: mode, count, bytes, terminator, byte padding */
    long bit = 0;
#define PUT(value, n) do { for (int _i = (n) - 1; _i >= 0; --_i, ++bit) \
                               if (((value) >> _i) & 1) cw[bit >> 3] |= (uint8_t)(0x80 >> (bit & 7)); } while (0)
    PUT(4, 4);
    PUT((long)len, ver <= 9 ? 8 : 16);
    for (size_t i = 0; i < len; ++i) PUT(data[i], 8);
    long room = (long)cap * 8 - bit;
    PUT(0, room < 4 ? (int)room : 4);
    bit = (bit + 7) & ~7L;
    for (int pad = 0xec; bit < (long)cap * 8; pad ^= 0xec ^ 0x11) PUT(pad, 8);
#undef PUT

    /* split into blocks, add error correction, interleave */
    int nblocks = kBlocks[ecc][ver], eccl = kEccPerBlock[ecc][ver];
    int raw = raw_data_modules(ver) / 8;
    int nshort = nblocks - raw % nblocks;
    int short_len = raw / nblocks;
    uint8_t *all = (uint8_t *)malloc((size_t)raw);
    uint8_t *blocks = (uint8_t *)malloc((size_t)nblocks * (short_len + 1));
    uint8_t div[30], rem[30];
    if (!all || !blocks) { free(cw); free(all); free(blocks); return -1; }
    rs_divisor(eccl, div);
    for (int i = 0, k = 0; i < nblocks; ++i) {
        int dlen = short_len - eccl + (i < nshort ? 0 : 1);
        uint8_t *blk = blocks + (size_t)i * (short_len + 1);
        memcpy(blk, cw + k, (size_t)dlen);
        k += dlen;
        rs_remainder(blk, dlen, div, eccl, rem);
        /* short blocks leave a gap where long ones have one more data byte */
        int at = dlen + (i < nshort ? 1 : 0);
        memcpy(blk + at, rem, (size_t)eccl);
    }
    int n = 0;
    for (int i = 0; i < short_len + 1; ++i)
        for (int j = 0; j < nblocks; ++j) {
            if (i == short_len - eccl && j < nshort) continue;
            all[n++] = blocks[(size_t)j * (short_len + 1) + i];
        }
    free(blocks);
    free(cw);

    int s = ver * 4 + 17;
    grid_t g;
    g.size = s;
    g.m = (uint8_t *)calloc((size_t)s * s, 1);
    g.fn = (uint8_t *)calloc((size_t)s * s, 1);
    uint8_t *best = (uint8_t *)malloc((size_t)s * s);
    if (!g.m || !g.fn || !best) {
        free(all); free(g.m); free(g.fn); free(best);
        return -1;
    }
    function_patterns(&g, ver);
    place_codewords(&g, all, n);
    free(all);

    long best_score = -1;
    for (int mask = 0; mask < 8; ++mask) {
        apply_mask(&g, mask);
        format_bits(&g, ecc, mask);
        long p = penalty(&g);
        if (best_score < 0 || p < best_score) {
            best_score = p;
            memcpy(best, g.m, (size_t)s * s);
        }
        apply_mask(&g, mask); /* xor again to undo */
    }
    out->size = s;
    out->version = ver;
    memset(out->modules, 0, sizeof out->modules);
    memcpy(out->modules, best, (size_t)s * s);
    free(g.m);
    free(g.fn);
    free(best);
    return 0;
}
