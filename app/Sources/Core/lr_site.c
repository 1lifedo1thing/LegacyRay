#include "lr_site.h"

#include <string.h>

/* public suffixes of two labels that sites register under. not the whole
   public suffix list: the ones people meet, so "bbc.co.uk" and not "co.uk"
   is the head of news.bbc.co.uk. a suffix missing here only makes the head
   one label too short, and the confirmation shows it before it is saved */
static const char *const kTwoLabelSuffixes[] = {
    /* country second levels */
    "ac.uk", "co.uk", "gov.uk", "ltd.uk", "me.uk", "net.uk", "org.uk", "plc.uk", "sch.uk",
    "asn.au", "com.au", "edu.au", "gov.au", "id.au", "net.au", "org.au",
    "ac.nz", "co.nz", "geek.nz", "govt.nz", "net.nz", "org.nz",
    "ac.jp", "co.jp", "ed.jp", "go.jp", "gr.jp", "lg.jp", "ne.jp", "or.jp",
    "ac.kr", "co.kr", "go.kr", "ne.kr", "or.kr", "re.kr",
    "ac.cn", "com.cn", "edu.cn", "gov.cn", "net.cn", "org.cn",
    "com.hk", "edu.hk", "gov.hk", "net.hk", "org.hk",
    "com.tw", "edu.tw", "gov.tw", "idv.tw", "net.tw", "org.tw",
    "com.sg", "edu.sg", "gov.sg", "net.sg", "org.sg",
    "com.my", "edu.my", "gov.my", "net.my", "org.my",
    "ac.in", "co.in", "edu.in", "firm.in", "gen.in", "gov.in", "ind.in", "net.in", "org.in",
    "art.br", "blog.br", "com.br", "edu.br", "gov.br", "net.br", "org.br",
    "com.ar", "edu.ar", "gob.ar", "net.ar", "org.ar",
    "com.mx", "edu.mx", "gob.mx", "net.mx", "org.mx",
    "biz.tr", "com.tr", "edu.tr", "gen.tr", "gov.tr", "net.tr", "org.tr",
    "com.ua", "edu.ua", "gov.ua", "in.ua", "kiev.ua", "net.ua", "org.ua",
    "com.ru", "msk.ru", "net.ru", "org.ru", "pp.ru", "spb.ru",
    "com.by", "com.kz", "org.kz", "co.uz", "com.uz",
    "ac.za", "co.za", "gov.za", "net.za", "org.za",
    "ac.il", "co.il", "gov.il", "net.il", "org.il",
    "ac.id", "co.id", "go.id", "or.id", "web.id",
    "ac.th", "co.th", "go.th", "in.th", "or.th",
    "com.vn", "edu.vn", "gov.vn", "net.vn", "org.vn",
    "com.ph", "net.ph", "org.ph", "com.pk", "net.pk", "org.pk",
    "com.eg", "com.sa", "co.ae", "net.ae", "org.ae",
    "com.es", "org.es", "com.pl", "net.pl", "org.pl",
    /* hosting where every customer is a site of their own */
    "appspot.com", "azurewebsites.net", "blogspot.com", "cloudfront.net", "ddns.net",
    "duckdns.org", "dyndns.org", "firebaseapp.com", "fly.dev", "github.io", "gitlab.io",
    "glitch.me", "herokuapp.com", "netlify.app", "ngrok.io", "onrender.com", "pages.dev",
    "vercel.app", "web.app", "workers.dev",
};

static int is_digit(char c) { return c >= '0' && c <= '9'; }

static int is_ipv4(const char *s, size_t n) {
    int parts = 0;
    size_t i = 0;
    while (i < n) {
        unsigned v = 0;
        size_t digits = 0;
        while (i < n && is_digit(s[i])) {
            v = v * 10 + (unsigned)(s[i] - '0');
            if (++digits > 3 || v > 255) return 0;
            ++i;
        }
        if (!digits) return 0;
        ++parts;
        if (i == n) break;
        if (s[i] != '.' || parts == 4) return 0;
        ++i;
        if (i == n) return 0;
    }
    return parts == 4;
}

/* punycode, rfc 3492 */

enum { PC_BASE = 36, PC_TMIN = 1, PC_TMAX = 26, PC_SKEW = 38, PC_DAMP = 700,
       PC_BIAS = 72, PC_N = 128 };

static unsigned pc_adapt(unsigned delta, unsigned points, int first) {
    unsigned k = 0;
    delta = first ? delta / PC_DAMP : delta / 2;
    delta += delta / points;
    while (delta > ((PC_BASE - PC_TMIN) * PC_TMAX) / 2) {
        delta /= PC_BASE - PC_TMIN;
        k += PC_BASE;
    }
    return k + (PC_BASE - PC_TMIN + 1) * delta / (delta + PC_SKEW);
}

static char pc_digit(unsigned d) {
    return (char)(d < 26 ? 'a' + d : '0' + (d - 26));
}

int lr_punycode_encode(const unsigned *cp, size_t n, char *out, size_t cap) {
    size_t len = 0;
    unsigned basic = 0;
    for (size_t i = 0; i < n; ++i) {
        if (cp[i] < 0x80) {
            if (len + 1 >= cap) return -1;
            out[len++] = (char)cp[i];
            ++basic;
        }
    }
    if (basic > 0) {
        if (len + 1 >= cap) return -1;
        out[len++] = '-';
    }
    unsigned code = PC_N, delta = 0, bias = PC_BIAS, handled = basic;
    while (handled < n) {
        unsigned m = 0xFFFFFFFFu;
        for (size_t i = 0; i < n; ++i)
            if (cp[i] >= code && cp[i] < m) m = cp[i];
        if ((m - code) > (0xFFFFFFFFu - delta) / (handled + 1)) return -1;
        delta += (m - code) * (handled + 1);
        code = m;
        for (size_t i = 0; i < n; ++i) {
            if (cp[i] < code && ++delta == 0) return -1;
            if (cp[i] != code) continue;
            unsigned q = delta;
            for (unsigned k = PC_BASE;; k += PC_BASE) {
                unsigned t = k <= bias ? PC_TMIN : (k >= bias + PC_TMAX ? PC_TMAX : k - bias);
                if (q < t) break;
                if (len + 1 >= cap) return -1;
                out[len++] = pc_digit(t + (q - t) % (PC_BASE - t));
                q = (q - t) / (PC_BASE - t);
            }
            if (len + 1 >= cap) return -1;
            out[len++] = pc_digit(q);
            bias = pc_adapt(delta, handled + 1, handled == basic);
            delta = 0;
            ++handled;
        }
        ++delta;
        ++code;
    }
    out[len] = '\0';
    return (int)len;
}

static int pc_value(char c) {
    if (c >= 'a' && c <= 'z') return c - 'a';
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= '0' && c <= '9') return c - '0' + 26;
    return -1;
}

int lr_punycode_decode(const char *in, size_t len, unsigned *cp, size_t cap) {
    size_t n = 0, start = 0;
    for (size_t i = len; i > 0; --i)
        if (in[i - 1] == '-') { start = i; break; }
    /* the basic code points before the last hyphen */
    for (size_t i = 0; start && i < start - 1; ++i) {
        if ((unsigned char)in[i] >= 0x80 || n >= cap) return -1;
        cp[n++] = (unsigned char)in[i];
    }
    unsigned code = PC_N, bias = PC_BIAS, i = 0;
    size_t pos = start;
    while (pos < len) {
        unsigned old = i, w = 1;
        for (unsigned k = PC_BASE;; k += PC_BASE) {
            if (pos >= len) return -1;
            int d = pc_value(in[pos++]);
            if (d < 0 || (unsigned)d > (0xFFFFFFFFu - i) / w) return -1;
            i += (unsigned)d * w;
            unsigned t = k <= bias ? PC_TMIN : (k >= bias + PC_TMAX ? PC_TMAX : k - bias);
            if ((unsigned)d < t) break;
            if (w > 0xFFFFFFFFu / (PC_BASE - t)) return -1;
            w *= PC_BASE - t;
        }
        bias = pc_adapt(i - old, (unsigned)n + 1, old == 0);
        if (i / (n + 1) > 0x10FFFF - code) return -1;
        code += i / ((unsigned)n + 1);
        i %= (unsigned)n + 1;
        if (n >= cap) return -1;
        memmove(cp + i + 1, cp + i, (n - i) * sizeof *cp);
        cp[i++] = code;
        ++n;
    }
    return (int)n;
}

static size_t put_utf8(unsigned c, char *out, size_t cap) {
    if (c < 0x80) { if (cap < 1) return 0; out[0] = (char)c; return 1; }
    if (c < 0x800) {
        if (cap < 2) return 0;
        out[0] = (char)(0xC0 | (c >> 6)); out[1] = (char)(0x80 | (c & 0x3F));
        return 2;
    }
    if (c < 0x10000) {
        if (cap < 3) return 0;
        out[0] = (char)(0xE0 | (c >> 12)); out[1] = (char)(0x80 | ((c >> 6) & 0x3F));
        out[2] = (char)(0x80 | (c & 0x3F));
        return 3;
    }
    if (cap < 4 || c > 0x10FFFF) return 0;
    out[0] = (char)(0xF0 | (c >> 18)); out[1] = (char)(0x80 | ((c >> 12) & 0x3F));
    out[2] = (char)(0x80 | ((c >> 6) & 0x3F)); out[3] = (char)(0x80 | (c & 0x3F));
    return 4;
}

void lr_site_display(const char *host, char *out, size_t cap) {
    if (!cap) return;
    size_t len = 0;
    const char *p = host;
    out[0] = '\0';
    while (*p) {
        const char *dot = strchr(p, '.');
        size_t ln = dot ? (size_t)(dot - p) : strlen(p);
        unsigned cps[64];
        int n = -1;
        if (ln > 4 && (p[0] == 'x' || p[0] == 'X') && (p[1] == 'n' || p[1] == 'N') && p[2] == '-' && p[3] == '-')
            n = lr_punycode_decode(p + 4, ln - 4, cps, 64);
        if (n > 0) {
            for (int i = 0; i < n; ++i) {
                size_t w = put_utf8(cps[i], out + len, cap - len - 1);
                if (!w) { out[len] = '\0'; return; }
                len += w;
            }
        } else {
            if (len + ln >= cap) { out[len] = '\0'; return; }
            memcpy(out + len, p, ln);
            len += ln;
        }
        if (!dot) break;
        if (len + 1 >= cap) break;
        out[len++] = '.';
        p = dot + 1;
    }
    out[len] = '\0';
}

/* names */

/* lower case for the scripts people type domains in; full idna mapping is
   not needed to find the right site */
static unsigned lower_cp(unsigned c) {
    if (c >= 'A' && c <= 'Z') return c + 32;
    if (c >= 0xC0 && c <= 0xDE && c != 0xD7) return c + 32;          /* latin-1 */
    if (c >= 0x391 && c <= 0x3A9 && c != 0x3A2) return c + 32;       /* greek */
    if (c >= 0x410 && c <= 0x42F) return c + 32;                     /* cyrillic */
    if (c >= 0x400 && c <= 0x40F) return c + 80;                     /* Ѐ..Џ */
    return c;
}

/* the next code point of utf-8 text, 0 on a malformed sequence */
static unsigned next_cp(const unsigned char **p, const unsigned char *end) {
    const unsigned char *s = *p;
    unsigned c = s[0];
    int more;
    if (c < 0x80) {
        *p = s + 1;
        return c;
    }
    if ((c & 0xE0) == 0xC0) { more = 1; c &= 0x1F; }
    else if ((c & 0xF0) == 0xE0) { more = 2; c &= 0x0F; }
    else if ((c & 0xF8) == 0xF0) { more = 3; c &= 0x07; }
    else return 0;
    if (end - s <= more) return 0;
    for (int i = 1; i <= more; ++i) {
        if ((s[i] & 0xC0) != 0x80) return 0;
        c = (c << 6) | (s[i] & 0x3F);
    }
    *p = s + more + 1;
    return c;
}

static int is_dot(unsigned c) {
    return c == '.' || c == 0x3002 || c == 0xFF0E || c == 0xFF61;
}

static int name_char(unsigned c) {
    return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_';
}

/* appends one label (code points) to out as ascii or xn--punycode */
static int put_label(const unsigned *cp, size_t n, char *out, size_t *len, size_t cap) {
    if (n == 0) return -1;
    int ascii = 1;
    for (size_t i = 0; i < n; ++i) {
        if (cp[i] >= 0x80) ascii = 0;
        else if (!name_char(cp[i])) return -1;
    }
    char label[64];
    size_t ln;
    if (ascii) {
        if (n > 63) return -1;
        for (size_t i = 0; i < n; ++i) label[i] = (char)cp[i];
        ln = n;
    } else {
        char code[64];
        int k = lr_punycode_encode(cp, n, code, sizeof code);
        if (k < 0 || k + 4 > 63) return -1;
        memcpy(label, "xn--", 4);
        memcpy(label + 4, code, (size_t)k);
        ln = (size_t)k + 4;
    }
    if (*len + ln + 2 > cap) return -1;
    if (*len) out[(*len)++] = '.';
    memcpy(out + *len, label, ln);
    *len += ln;
    out[*len] = '\0';
    return 0;
}

int lr_site_parse(const char *input, char *out, size_t cap, lr_site_kind_t *kind, int *wildcard) {
    if (!input || !out || cap < 2) return -1;
    if (wildcard) *wildcard = 0;
    const char *s = input, *e = input + strlen(input);
    while (s < e && (*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n')) ++s;
    while (e > s && (e[-1] == ' ' || e[-1] == '\t' || e[-1] == '\r' || e[-1] == '\n')) --e;
    const char *scheme = NULL;
    for (const char *p = s; p + 2 < e; ++p)
        if (p[0] == ':' && p[1] == '/' && p[2] == '/') { scheme = p; break; }
    if (scheme) s = scheme + 3;
    /* an address range keeps its slash */
    const char *slash = memchr(s, '/', (size_t)(e - s));
    if (slash && is_ipv4(s, (size_t)(slash - s))) {
        const char *q = slash + 1;
        size_t digits = 0;
        unsigned bits = 0;
        while (q < e && is_digit(*q) && digits < 3) bits = bits * 10 + (unsigned)(*q++ - '0'), ++digits;
        if (!digits || q != e || bits > 32 || (size_t)(e - s) >= cap) return -1;
        memcpy(out, s, (size_t)(e - s));
        out[e - s] = '\0';
        if (kind) *kind = LR_SITE_CIDR;
        return 0;
    }
    for (const char *p = s; p < e; ++p)
        if (*p == '/' || *p == '?' || *p == '#') { e = p; break; }
    for (const char *p = e; p > s; --p)
        if (p[-1] == '@') { s = p; break; }
    const char *colon = memchr(s, ':', (size_t)(e - s));
    if (colon) {
        for (const char *p = colon + 1; p < e; ++p)
            if (!is_digit(*p)) return -1;      /* ipv6 and other oddities */
        e = colon;
    }
    int wild = 0;
    if (e - s >= 2 && s[0] == '*' && s[1] == '.') { s += 2; wild = 1; }
    else if (e > s && s[0] == '.') { s += 1; wild = 1; }
    while (e > s && e[-1] == '.') --e;
    if (e <= s) return -1;
    if (is_ipv4(s, (size_t)(e - s))) {
        if (wild || (size_t)(e - s) >= cap) return -1;
        memcpy(out, s, (size_t)(e - s));
        out[e - s] = '\0';
        if (kind) *kind = LR_SITE_IPV4;
        return 0;
    }
    unsigned cps[64];
    size_t n = 0, len = 0;
    out[0] = '\0';
    const unsigned char *p = (const unsigned char *)s, *end = (const unsigned char *)e;
    while (p < end) {
        unsigned c = next_cp(&p, end);
        if (!c) return -1;
        if (is_dot(c)) {
            if (put_label(cps, n, out, &len, cap) < 0) return -1;
            n = 0;
            continue;
        }
        if (n == 64) return -1;
        cps[n++] = lower_cp(c);
    }
    if (put_label(cps, n, out, &len, cap) < 0) return -1;
    if (len > 253) return -1;
    if (kind) *kind = LR_SITE_NAME;
    if (wildcard) *wildcard = wild;
    return 0;
}

const char *lr_site_head(const char *host) {
    size_t n = strlen(host);
    if (is_ipv4(host, n) || memchr(host, '/', n)) return host;
    const char *dots[3] = { NULL, NULL, NULL };
    int found = 0;
    for (const char *p = host + n; p > host && found < 3; --p)
        if (p[-1] == '.') dots[found++] = p - 1;
    if (found < 2) return host;
    const char *two = dots[1] + 1;
    for (size_t i = 0; i < sizeof kTwoLabelSuffixes / sizeof kTwoLabelSuffixes[0]; ++i) {
        if (strcmp(two, kTwoLabelSuffixes[i]) == 0)
            return found < 3 ? host : dots[2] + 1;
    }
    return two;
}
