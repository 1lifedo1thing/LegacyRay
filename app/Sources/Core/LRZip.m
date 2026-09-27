#import "LRZip.h"
#include <zlib.h>

static const NSUInteger kMaxEntry = 32u * 1024u * 1024u;

static uint16_t LRLE16(const unsigned char *p) { return (uint16_t)(p[0] | (p[1] << 8)); }
static uint32_t LRLE32(const unsigned char *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

BOOL LRZipLooksLikeZip(NSData *data) {
    const unsigned char *b = [data bytes];
    return [data length] >= 22 && b[0] == 'P' && b[1] == 'K' && b[2] == 3 && b[3] == 4;
}

static NSData *LRInflate(const unsigned char *src, size_t len, size_t expected, NSString **error) {
    if (expected > kMaxEntry) { if (error) *error = @"entry too large"; return nil; }
    NSMutableData *out = [NSMutableData dataWithLength:expected ? expected : len * 4 + 1024];
    z_stream zs;
    memset(&zs, 0, sizeof zs);
    if (inflateInit2(&zs, -MAX_WBITS) != Z_OK) { if (error) *error = @"inflate failed"; return nil; }
    zs.next_in = (Bytef *)src;
    zs.avail_in = (uInt)len;
    int rc;
    do {
        if (zs.total_out >= [out length]) {
            if ([out length] * 2 > kMaxEntry) { inflateEnd(&zs); if (error) *error = @"entry too large"; return nil; }
            [out setLength:[out length] * 2];
        }
        zs.next_out = (Bytef *)[out mutableBytes] + zs.total_out;
        zs.avail_out = (uInt)([out length] - zs.total_out);
        rc = inflate(&zs, Z_NO_FLUSH);
    } while (rc == Z_OK);
    [out setLength:zs.total_out];
    inflateEnd(&zs);
    if (rc != Z_STREAM_END) { if (error) *error = @"the archive is damaged"; return nil; }
    return out;
}

NSData *LRZipEntryNamed(NSData *zip, NSString *name, NSString **error) {
    const unsigned char *b = [zip bytes];
    size_t n = [zip length];
    if (n < 22) { if (error) *error = @"not a zip archive"; return nil; }
    /* the end of central directory record sits in the last 64k + 22 bytes */
    size_t eocd = SIZE_MAX;
    size_t floor = n > 65557 ? n - 65557 : 0;
    for (size_t i = n - 22 + 1; i-- > floor;) {
        if (LRLE32(b + i) == 0x06054b50) { eocd = i; break; }
    }
    if (eocd == SIZE_MAX) { if (error) *error = @"not a zip archive"; return nil; }
    uint16_t count = LRLE16(b + eocd + 10);
    uint32_t cdOffset = LRLE32(b + eocd + 16);
    size_t p = cdOffset;
    for (uint16_t i = 0; i < count; ++i) {
        if (p + 46 > n || LRLE32(b + p) != 0x02014b50) break;
        uint16_t method = LRLE16(b + p + 10);
        uint32_t csize = LRLE32(b + p + 20), usize = LRLE32(b + p + 24);
        uint16_t nameLen = LRLE16(b + p + 28), extraLen = LRLE16(b + p + 30), commentLen = LRLE16(b + p + 32);
        uint32_t local = LRLE32(b + p + 42);
        if (p + 46 + nameLen > n) break;
        NSString *entry = [[[NSString alloc] initWithBytes:b + p + 46 length:nameLen
                                                  encoding:NSUTF8StringEncoding] autorelease];
        p += 46 + nameLen + extraLen + commentLen;
        if ([[entry lastPathComponent] caseInsensitiveCompare:name] != NSOrderedSame) continue;
        if ((size_t)local + 30 > n || LRLE32(b + local) != 0x04034b50) break;
        size_t data = local + 30 + LRLE16(b + local + 26) + LRLE16(b + local + 28);
        if (data + csize > n) { if (error) *error = @"the archive is truncated"; return nil; }
        if (method == 0) return [NSData dataWithBytes:b + data length:csize];
        if (method == 8) return LRInflate(b + data, csize, usize, error);
        if (error) *error = @"unsupported compression";
        return nil;
    }
    if (error) *error = [NSString stringWithFormat:@"%@ is not in the archive", name];
    return nil;
}
