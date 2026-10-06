#include "sniff.h"

#include <string.h>

static int copy_name(const uint8_t *p, size_t n, char *host, size_t cap) {
    if (n == 0 || n >= cap) return -1;
    /* a trailing dot names the same host */
    while (n > 0 && p[n - 1] == '.') --n;
    if (n == 0) return -1;
    for (size_t i = 0; i < n; ++i) {
        uint8_t ch = p[i];
        if (ch >= 'A' && ch <= 'Z') ch = (uint8_t)(ch - 'A' + 'a');
        if (!((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') ||
              ch == '-' || ch == '.' || ch == '_'))
            return -1;
        host[i] = (char)ch;
    }
    host[n] = '\0';
    return 0;
}

static uint16_t be16(const uint8_t *p) { return (uint16_t)((p[0] << 8) | p[1]); }

/* one tls record holding the start of a client hello. the hello has to fit
   in the first record, which every client of the era does */
static sniff_status_t sniff_tls(const uint8_t *buf, size_t len, size_t buf_cap,
                                char *host, size_t cap) {
    if (len < 5) return SNIFF_NEED_MORE;
    size_t rec_len = be16(buf + 3);
    if (rec_len < 4) return SNIFF_NONE;
    if (len < 5 + rec_len) {
        /* a record larger than the buffer can never complete in it */
        return 5 + rec_len > buf_cap ? SNIFF_NONE : SNIFF_NEED_MORE;
    }
    const uint8_t *p = buf + 5;
    const uint8_t *end = p + rec_len;
    if (p[0] != 0x01) return SNIFF_NONE; /* client hello */
    size_t hs_len = ((size_t)p[1] << 16) | ((size_t)p[2] << 8) | p[3];
    p += 4;
    if (hs_len < (size_t)(end - p)) end = p + hs_len;
    /* version, random */
    if (end - p < 2 + 32 + 1) return SNIFF_NONE;
    p += 2 + 32;
    size_t sid = *p++;
    if ((size_t)(end - p) < sid + 2) return SNIFF_NONE;
    p += sid;
    size_t suites = be16(p);
    p += 2;
    if ((size_t)(end - p) < suites + 1) return SNIFF_NONE;
    p += suites;
    size_t comp = *p++;
    if ((size_t)(end - p) < comp) return SNIFF_NONE;
    p += comp;
    if (end - p < 2) return SNIFF_NONE; /* no extensions: an ssl 3 hello */
    size_t ext_total = be16(p);
    p += 2;
    if ((size_t)(end - p) < ext_total) ext_total = (size_t)(end - p);
    const uint8_t *ext_end = p + ext_total;
    while (ext_end - p >= 4) {
        uint16_t type = be16(p);
        size_t elen = be16(p + 2);
        p += 4;
        if ((size_t)(ext_end - p) < elen) return SNIFF_NONE;
        if (type == 0x0000) { /* server_name */
            const uint8_t *q = p;
            const uint8_t *qend = p + elen;
            if (qend - q < 2) return SNIFF_NONE;
            q += 2; /* list length */
            while (qend - q >= 3) {
                uint8_t name_type = q[0];
                size_t nlen = be16(q + 1);
                q += 3;
                if ((size_t)(qend - q) < nlen) return SNIFF_NONE;
                if (name_type == 0)
                    return copy_name(q, nlen, host, cap) == 0 ? SNIFF_FOUND : SNIFF_NONE;
                q += nlen;
            }
            return SNIFF_NONE;
        }
        p += elen;
    }
    return SNIFF_NONE;
}

static int is_http_method(const uint8_t *buf, size_t len) {
    static const char *const methods[] = {
        "GET ", "POST ", "HEAD ", "PUT ", "DELETE ", "OPTIONS ", "PATCH ",
        "CONNECT ", "TRACE ", "PROPFIND ", "PROPPATCH ", "MKCOL ", "COPY ",
        "MOVE ", "LOCK ", "UNLOCK ", "REPORT ", "SEARCH "
    };
    for (size_t i = 0; i < sizeof methods / sizeof methods[0]; ++i) {
        size_t ml = strlen(methods[i]);
        size_t n = len < ml ? len : ml;
        if (memcmp(buf, methods[i], n) == 0) return n == ml ? 1 : 2; /* 2: maybe */
    }
    return 0;
}

static sniff_status_t sniff_http(const uint8_t *buf, size_t len, size_t buf_cap,
                                 char *host, size_t cap) {
    int m = is_http_method(buf, len);
    if (m == 0) return SNIFF_NONE;
    if (m == 2) return len >= buf_cap ? SNIFF_NONE : SNIFF_NEED_MORE;
    /* walk header lines after the request line */
    size_t i = 0;
    while (i < len && buf[i] != '\n') ++i;
    if (i >= len) return len >= buf_cap ? SNIFF_NONE : SNIFF_NEED_MORE;
    ++i;
    while (i < len) {
        size_t start = i;
        while (i < len && buf[i] != '\n') ++i;
        if (i >= len) break; /* partial line */
        size_t line_end = i;
        if (line_end > start && buf[line_end - 1] == '\r') --line_end;
        ++i;
        if (line_end == start) return SNIFF_NONE; /* end of headers, no host */
        if (line_end - start > 5 &&
            (buf[start] == 'H' || buf[start] == 'h') &&
            (buf[start + 1] == 'O' || buf[start + 1] == 'o') &&
            (buf[start + 2] == 'S' || buf[start + 2] == 's') &&
            (buf[start + 3] == 'T' || buf[start + 3] == 't') &&
            buf[start + 4] == ':') {
            size_t v = start + 5;
            while (v < line_end && (buf[v] == ' ' || buf[v] == '\t')) ++v;
            size_t ve = line_end;
            while (ve > v && (buf[ve - 1] == ' ' || buf[ve - 1] == '\t')) --ve;
            if (ve > v && buf[v] == '[') return SNIFF_NONE; /* an ipv6 literal */
            /* drop the port */
            size_t colon = v;
            while (colon < ve && buf[colon] != ':') ++colon;
            return copy_name(buf + v, colon - v, host, cap) == 0 ? SNIFF_FOUND : SNIFF_NONE;
        }
    }
    return len >= buf_cap ? SNIFF_NONE : SNIFF_NEED_MORE;
}

sniff_status_t sniff_host(const uint8_t *buf, size_t len, size_t buf_cap,
                          char *host, size_t cap) {
    if (!host || cap == 0) return SNIFF_NONE;
    host[0] = '\0';
    if (!buf || len == 0) return SNIFF_NEED_MORE;
    if (buf_cap < len) buf_cap = len;
    /* tls handshake record, any 3.x version */
    if (buf[0] == 0x16) {
        if (len >= 2 && buf[1] != 0x03) return SNIFF_NONE;
        return sniff_tls(buf, len, buf_cap, host, cap);
    }
    return sniff_http(buf, len, buf_cap, host, cap);
}
