#define _DEFAULT_SOURCE
#include "geo.h"

#include <arpa/inet.h>
#include <ctype.h>
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* ---- codes ------------------------------------------------------------ */

int geo_code_normalize(const char *text, size_t len, char *out, size_t cap) {
    if (!text || !out || cap == 0) return -1;
    while (len && isspace((unsigned char)text[0])) { ++text; --len; }
    while (len && isspace((unsigned char)text[len - 1])) --len;
    if (len == 0 || len >= cap || len >= GEO_CODE_MAX) return -1;
    int at = 0;
    for (size_t i = 0; i < len; ++i) {
        unsigned char c = (unsigned char)text[i];
        if (c == '@') {
            if (at || i == 0 || i + 1 == len) return -1;
            at = 1;
            out[i] = '@';
            continue;
        }
        if (!(isalnum(c) || c == '-' || c == '_' || c == '.' || c == '!')) return -1;
        out[i] = (char)tolower(c);
    }
    out[len] = '\0';
    return 0;
}

/* the category part and the optional attribute of "google@cn" */
static void split_code(const char *code, char *base, size_t cap, const char **attr) {
    const char *at = strchr(code, '@');
    size_t n = at ? (size_t)(at - code) : strlen(code);
    if (n >= cap) n = cap - 1;
    memcpy(base, code, n);
    base[n] = '\0';
    *attr = at ? at + 1 : NULL;
}

/* ---- a bounds-checked protobuf reader --------------------------------- */

typedef struct {
    const uint8_t *p;
    const uint8_t *end;
} pb_t;

static int pb_varint(pb_t *r, uint64_t *out) {
    uint64_t v = 0;
    for (int shift = 0; shift < 64; shift += 7) {
        if (r->p >= r->end) return -1;
        uint8_t b = *r->p++;
        v |= (uint64_t)(b & 0x7f) << shift;
        if (!(b & 0x80)) { *out = v; return 0; }
    }
    return -1;
}

/* the next field: its number, and for length-delimited fields the payload */
static int pb_next(pb_t *r, uint32_t *field, uint32_t *wire, pb_t *payload, uint64_t *value) {
    uint64_t key;
    if (r->p >= r->end || pb_varint(r, &key) != 0) return -1;
    *field = (uint32_t)(key >> 3);
    *wire = (uint32_t)(key & 7);
    switch (*wire) {
        case 0:
            return pb_varint(r, value);
        case 1:
            if (r->end - r->p < 8) return -1;
            r->p += 8;
            return 0;
        case 2: {
            uint64_t n;
            if (pb_varint(r, &n) != 0 || n > (uint64_t)(r->end - r->p)) return -1;
            payload->p = r->p;
            payload->end = r->p + n;
            r->p += n;
            return 0;
        }
        case 5:
            if (r->end - r->p < 4) return -1;
            r->p += 4;
            return 0;
        default:
            return -1;
    }
}

static int pb_string_eq_ci(const pb_t *s, const char *want) {
    size_t n = (size_t)(s->end - s->p);
    if (n != strlen(want)) return 0;
    for (size_t i = 0; i < n; ++i)
        if (tolower(s->p[i]) != (unsigned char)want[i]) return 0;
    return 1;
}

/* the country_code field of one GeoSite / GeoIP message */
static int pb_country(const pb_t *msg, pb_t *out) {
    pb_t r = *msg;
    uint32_t field, wire;
    pb_t payload;
    uint64_t value;
    while (r.p < r.end) {
        if (pb_next(&r, &field, &wire, &payload, &value) != 0) return -1;
        if (field == 1 && wire == 2) { *out = payload; return 0; }
    }
    return -1;
}

/* ---- file output -------------------------------------------------------- */

int geo_file_path(char *out, size_t cap, const char *dir, char kind, const char *code) {
    if (!out || !dir || !code) return -1;
    int n = snprintf(out, cap, "%s/%s-%s.txt", dir, kind == 's' ? "site" : "ip", code);
    return n > 0 && (size_t)n < cap ? 0 : -1;
}

static int path_for(char *out, size_t cap, const char *dir, char kind, const char *code) {
    return geo_file_path(out, cap, dir, kind, code);
}

typedef struct {
    FILE *f;
    char tmp[512];
    char final[512];
    long count;
} geo_out_t;

static int out_open(geo_out_t *o, const char *dir, char kind, const char *code) {
    memset(o, 0, sizeof *o);
    if (path_for(o->final, sizeof o->final, dir, kind, code) != 0) return -1;
    if (snprintf(o->tmp, sizeof o->tmp, "%s.part", o->final) >= (int)sizeof o->tmp) return -1;
    o->f = fopen(o->tmp, "w");
    return o->f ? 0 : -1;
}

static int out_close(geo_out_t *o, int keep) {
    if (!o->f) return -1;
    int bad = ferror(o->f);
    if (fclose(o->f) != 0) bad = 1;
    o->f = NULL;
    if (!keep || bad) { unlink(o->tmp); return -1; }
    if (rename(o->tmp, o->final) != 0) { unlink(o->tmp); return -1; }
    return 0;
}

/* ---- geosite ------------------------------------------------------------ */

/* one Domain message: type 0 keyword, 1 regex, 2 domain (suffix), 3 full */
static int site_domain(const pb_t *msg, const char *attr, geo_out_t *o) {
    pb_t r = *msg;
    uint32_t field, wire;
    pb_t payload, value_s = { NULL, NULL };
    uint64_t value, type = 0;
    int have_value = 0, attr_ok = attr == NULL;
    while (r.p < r.end) {
        if (pb_next(&r, &field, &wire, &payload, &value) != 0) return -1;
        if (field == 1 && wire == 0) type = value;
        else if (field == 2 && wire == 2) { value_s = payload; have_value = 1; }
        else if (field == 3 && wire == 2 && attr && !attr_ok) {
            pb_t key;
            if (pb_country(&payload, &key) == 0 && pb_string_eq_ci(&key, attr)) attr_ok = 1;
        }
    }
    if (!have_value || !attr_ok) return 0;
    size_t n = (size_t)(value_s.end - value_s.p);
    if (n == 0 || n > 253) return 0;
    for (size_t i = 0; i < n; ++i)
        if (value_s.p[i] == '\n' || value_s.p[i] == '\r' || value_s.p[i] == 0) return 0;
    const char *prefix = type == 3 ? "full:" : type == 2 ? "domain:" :
                         type == 1 ? "regexp:" : "keyword:";
    fputs(prefix, o->f);
    for (size_t i = 0; i < n; ++i) {
        int c = value_s.p[i];
        fputc(type == 1 ? c : tolower(c), o->f);
    }
    fputc('\n', o->f);
    o->count++;
    return 0;
}

geo_status_t geo_extract_sites(const uint8_t *dat, size_t len,
                               const char *const *codes, size_t ncodes,
                               const char *dir, long *found) {
    if (!dat || !codes || !dir || !found) return GEO_ERR_ARG;
    for (size_t i = 0; i < ncodes; ++i) found[i] = -1;
    pb_t top = { dat, dat + len };
    uint32_t field, wire;
    pb_t site;
    uint64_t value;
    int any = 0;
    while (top.p < top.end) {
        if (pb_next(&top, &field, &wire, &site, &value) != 0) return GEO_ERR_FORMAT;
        if (field != 1 || wire != 2) continue;
        any = 1;
        pb_t country;
        if (pb_country(&site, &country) != 0) continue;
        for (size_t c = 0; c < ncodes; ++c) {
            char base[GEO_CODE_MAX];
            const char *attr;
            split_code(codes[c], base, sizeof base, &attr);
            if (found[c] >= 0 || !pb_string_eq_ci(&country, base)) continue;
            geo_out_t o;
            if (out_open(&o, dir, 's', codes[c]) != 0) return GEO_ERR_IO;
            pb_t r = site;
            pb_t payload;
            int bad = 0;
            while (r.p < r.end) {
                if (pb_next(&r, &field, &wire, &payload, &value) != 0) { bad = 1; break; }
                if (field == 2 && wire == 2 && site_domain(&payload, attr, &o) != 0) { bad = 1; break; }
            }
            long count = o.count;
            if (out_close(&o, !bad) != 0) return bad ? GEO_ERR_FORMAT : GEO_ERR_IO;
            found[c] = count;
        }
    }
    return any ? GEO_OK : GEO_ERR_FORMAT;
}

/* ---- geoip -------------------------------------------------------------- */

static int ip_cidr(const pb_t *msg, geo_out_t *o) {
    pb_t r = *msg;
    uint32_t field, wire;
    pb_t payload, ip = { NULL, NULL };
    uint64_t value, prefix = 0;
    while (r.p < r.end) {
        if (pb_next(&r, &field, &wire, &payload, &value) != 0) return -1;
        if (field == 1 && wire == 2) ip = payload;
        else if (field == 2 && wire == 0) prefix = value;
    }
    if (!ip.p || ip.end - ip.p != 4 || prefix > 32) return 0; /* ipv6 is skipped */
    fprintf(o->f, "%u.%u.%u.%u/%u\n", ip.p[0], ip.p[1], ip.p[2], ip.p[3], (unsigned)prefix);
    o->count++;
    return 0;
}

geo_status_t geo_extract_ips(const uint8_t *dat, size_t len,
                             const char *const *codes, size_t ncodes,
                             const char *dir, long *found) {
    if (!dat || !codes || !dir || !found) return GEO_ERR_ARG;
    for (size_t i = 0; i < ncodes; ++i) found[i] = -1;
    pb_t top = { dat, dat + len };
    uint32_t field, wire;
    pb_t entry;
    uint64_t value;
    int any = 0;
    while (top.p < top.end) {
        if (pb_next(&top, &field, &wire, &entry, &value) != 0) return GEO_ERR_FORMAT;
        if (field != 1 || wire != 2) continue;
        any = 1;
        pb_t country;
        if (pb_country(&entry, &country) != 0) continue;
        for (size_t c = 0; c < ncodes; ++c) {
            if (found[c] >= 0 || !pb_string_eq_ci(&country, codes[c])) continue;
            geo_out_t o;
            if (out_open(&o, dir, 'i', codes[c]) != 0) return GEO_ERR_IO;
            pb_t r = entry;
            pb_t payload;
            int bad = 0, reverse = 0;
            while (r.p < r.end) {
                if (pb_next(&r, &field, &wire, &payload, &value) != 0) { bad = 1; break; }
                if (field == 2 && wire == 2 && ip_cidr(&payload, &o) != 0) { bad = 1; break; }
                if (field == 3 && wire == 0 && value) reverse = 1;
            }
/* a reverse-match entry means "everything but"; a firewall table cannot say
   that, so such a country is reported missing rather than inverted */
            long count = o.count;
            if (out_close(&o, !bad && !reverse) != 0) {
                if (bad) return GEO_ERR_FORMAT;
                if (!reverse) return GEO_ERR_IO;
                continue;
            }
            found[c] = count;
        }
    }
    return any ? GEO_OK : GEO_ERR_FORMAT;
}

static int parse_cidr4(const char *s, size_t n, uint32_t *net, unsigned *prefix) {
    char buf[32];
    if (n == 0 || n >= sizeof buf) return -1;
    memcpy(buf, s, n);
    buf[n] = '\0';
    char *slash = strchr(buf, '/');
    unsigned p = 32;
    if (slash) {
        *slash++ = '\0';
        char *end = NULL;
        unsigned long v = strtoul(slash, &end, 10);
        if (!*slash || *end || v > 32) return -1;
        p = (unsigned)v;
    }
    struct in_addr a;
    if (inet_pton(AF_INET, buf, &a) != 1) return -1;
    uint32_t h = ntohl(a.s_addr);
    uint32_t mask = p ? 0xffffffffu << (32 - p) : 0;
    *net = h & mask;
    *prefix = p;
    return 0;
}

long geo_save_ip_list(const char *text, size_t len, const char *code, const char *dir) {
    if (!text || !code || !dir) return GEO_ERR_ARG;
    geo_out_t o;
    if (out_open(&o, dir, 'i', code) != 0) return GEO_ERR_IO;
    size_t i = 0;
    while (i < len) {
        size_t e = i;
        while (e < len && text[e] != '\n') ++e;
        size_t a = i, b = e;
        while (a < b && isspace((unsigned char)text[a])) ++a;
        while (b > a && isspace((unsigned char)text[b - 1])) --b;
        if (b > a && text[a] != '#' && text[a] != ';') {
            uint32_t net;
            unsigned prefix;
            if (parse_cidr4(text + a, b - a, &net, &prefix) == 0) {
                fprintf(o.f, "%u.%u.%u.%u/%u\n", net >> 24, (net >> 16) & 255,
                        (net >> 8) & 255, net & 255, prefix);
                o.count++;
            }
        }
        i = e + 1;
    }
    long count = o.count;
    if (count == 0) { out_close(&o, 0); return GEO_ERR_FORMAT; }
    return out_close(&o, 1) == 0 ? count : GEO_ERR_IO;
}

long geo_write_private(const char *dir) {
    static const char list[] =
        "0.0.0.0/8\n10.0.0.0/8\n100.64.0.0/10\n127.0.0.0/8\n169.254.0.0/16\n"
        "172.16.0.0/12\n192.0.0.0/24\n192.168.0.0/16\n198.18.0.0/15\n"
        "224.0.0.0/4\n240.0.0.0/4\n255.255.255.255/32\n";
    return geo_save_ip_list(list, sizeof list - 1, "private", dir);
}

/* ---- loaded sets -------------------------------------------------------- */

typedef struct {
    char   **slots;
    uint32_t mask;   /* capacity - 1, capacity a power of two */
} strset_t;

typedef struct geo_set {
    char kind;
    char code[GEO_CODE_MAX];
    char *arena;             /* the file text; entries point into it */
    strset_t full;
    strset_t suffix;
    char **keywords;
    size_t nkeywords;
    uint32_t *lo;            /* ip ranges, sorted and merged */
    uint32_t *hi;
    size_t nranges;
    long count;
    struct geo_set *next;
} geo_set_t;

struct geo_db {
    geo_set_t *sets;
};

static uint32_t fnv1a(const char *s) {
    uint32_t h = 2166136261u;
    while (*s) { h ^= (uint8_t)*s++; h *= 16777619u; }
    return h;
}

static int strset_init(strset_t *s, size_t n) {
    uint32_t cap = 16;
    while (cap < n * 2 + 1 && cap < (1u << 30)) cap <<= 1;
    s->slots = (char **)calloc(cap, sizeof *s->slots);
    if (!s->slots) return -1;
    s->mask = cap - 1;
    return 0;
}

static void strset_add(strset_t *s, char *key) {
    uint32_t i = fnv1a(key) & s->mask;
    while (s->slots[i]) {
        if (strcmp(s->slots[i], key) == 0) return;
        i = (i + 1) & s->mask;
    }
    s->slots[i] = key;
}

static int strset_has(const strset_t *s, const char *key) {
    if (!s->slots) return 0;
    uint32_t i = fnv1a(key) & s->mask;
    while (s->slots[i]) {
        if (strcmp(s->slots[i], key) == 0) return 1;
        i = (i + 1) & s->mask;
    }
    return 0;
}

static void set_free(geo_set_t *set) {
    if (!set) return;
    free(set->arena);
    free(set->full.slots);
    free(set->suffix.slots);
    free(set->keywords);
    free(set->lo);
    free(set->hi);
    free(set);
}

geo_db_t *geo_db_new(void) {
    return (geo_db_t *)calloc(1, sizeof(geo_db_t));
}

void geo_db_free(geo_db_t *db) {
    if (!db) return;
    geo_set_t *s = db->sets;
    while (s) {
        geo_set_t *next = s->next;
        set_free(s);
        s = next;
    }
    free(db);
}

static geo_set_t *db_find(const geo_db_t *db, char kind, const char *code) {
    for (geo_set_t *s = db ? db->sets : NULL; s; s = s->next)
        if (s->kind == kind && strcmp(s->code, code) == 0) return s;
    return NULL;
}

static char *read_all(const char *path, size_t *len) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return NULL; }
    long size = ftell(f);
    if (size < 0 || size > 64L * 1024 * 1024) { fclose(f); return NULL; }
    rewind(f);
    char *buf = (char *)malloc((size_t)size + 1);
    if (!buf) { fclose(f); return NULL; }
    if (fread(buf, 1, (size_t)size, f) != (size_t)size) { free(buf); fclose(f); return NULL; }
    fclose(f);
    buf[size] = '\0';
    *len = (size_t)size;
    return buf;
}

typedef struct { uint32_t lo, hi; } range_t;

static int range_cmp(const void *a, const void *b) {
    const range_t *x = (const range_t *)a, *y = (const range_t *)b;
    return x->lo < y->lo ? -1 : x->lo > y->lo ? 1 : 0;
}

static long load_sites(geo_set_t *set) {
    size_t lines = 0;
    for (char *p = set->arena; *p; ++p) if (*p == '\n') ++lines;
    if (strset_init(&set->full, lines) != 0 || strset_init(&set->suffix, lines) != 0)
        return GEO_ERR_MEMORY;
    set->keywords = (char **)calloc(lines + 1, sizeof *set->keywords);
    if (!set->keywords) return GEO_ERR_MEMORY;
    char *p = set->arena;
    while (*p) {
        char *nl = strchr(p, '\n');
        if (nl) *nl = '\0';
        if (strncmp(p, "full:", 5) == 0 && p[5]) { strset_add(&set->full, p + 5); set->count++; }
        else if (strncmp(p, "domain:", 7) == 0 && p[7]) { strset_add(&set->suffix, p + 7); set->count++; }
        else if (strncmp(p, "keyword:", 8) == 0 && p[8]) {
            set->keywords[set->nkeywords++] = p + 8;
            set->count++;
        }
        /* regexp: lines are kept in the file for a later matcher, not used */
        if (!nl) break;
        p = nl + 1;
    }
    return set->count;
}

static long load_ips(geo_set_t *set, size_t len) {
    size_t lines = 1;
    for (size_t i = 0; i < len; ++i) if (set->arena[i] == '\n') ++lines;
    range_t *r = (range_t *)malloc(lines * sizeof *r);
    if (!r) return GEO_ERR_MEMORY;
    size_t n = 0;
    char *p = set->arena;
    while (*p && n < lines) {
        char *nl = strchr(p, '\n');
        size_t l = nl ? (size_t)(nl - p) : strlen(p);
        uint32_t net;
        unsigned prefix;
        if (parse_cidr4(p, l, &net, &prefix) == 0) {
            r[n].lo = net;
            r[n].hi = prefix ? net | ~(0xffffffffu << (32 - prefix)) : 0xffffffffu;
            ++n;
        }
        if (!nl) break;
        p = nl + 1;
    }
    qsort(r, n, sizeof *r, range_cmp);
    size_t m = 0;
    for (size_t i = 0; i < n; ++i) {
        int touches = m && (r[i].lo <= r[m - 1].hi ||
                            (r[m - 1].hi != 0xffffffffu && r[i].lo == r[m - 1].hi + 1));
        if (touches) {
            if (r[i].hi > r[m - 1].hi) r[m - 1].hi = r[i].hi;
        } else {
            r[m++] = r[i];
        }
    }
    set->lo = (uint32_t *)malloc((m ? m : 1) * sizeof(uint32_t));
    set->hi = (uint32_t *)malloc((m ? m : 1) * sizeof(uint32_t));
    if (!set->lo || !set->hi) { free(r); return GEO_ERR_MEMORY; }
    for (size_t i = 0; i < m; ++i) { set->lo[i] = r[i].lo; set->hi[i] = r[i].hi; }
    set->nranges = m;
    set->count = (long)n;
    free(r);
/* the text is not needed once the ranges exist */
    free(set->arena);
    set->arena = NULL;
    return set->count;
}

long geo_db_load(geo_db_t *db, char kind, const char *code, const char *dir) {
    if (!db || (kind != 's' && kind != 'i') || !code || !dir) return GEO_ERR_ARG;
    if (db_find(db, kind, code)) return geo_db_count(db, kind, code);
    char path[512];
    if (path_for(path, sizeof path, dir, kind, code) != 0) return GEO_ERR_ARG;
    geo_set_t *set = (geo_set_t *)calloc(1, sizeof *set);
    if (!set) return GEO_ERR_MEMORY;
    set->kind = kind;
    snprintf(set->code, sizeof set->code, "%s", code);
    size_t len = 0;
    set->arena = read_all(path, &len);
    if (!set->arena) { free(set); return errno == ENOENT ? GEO_ERR_MISSING : GEO_ERR_IO; }
    long r = kind == 's' ? load_sites(set) : load_ips(set, len);
    if (r < 0) { set_free(set); return r; }
    set->next = db->sets;
    db->sets = set;
    return r;
}

int geo_db_site_match(const geo_db_t *db, const char *code, const char *name) {
    const geo_set_t *s = db_find(db, 's', code);
    if (!s || !name || !*name) return 0;
    if (strset_has(&s->full, name)) return 1;
    for (const char *p = name; p; ) {
        if (strset_has(&s->suffix, p)) return 1;
        p = strchr(p, '.');
        if (p) ++p;
    }
    for (size_t i = 0; i < s->nkeywords; ++i)
        if (strstr(name, s->keywords[i])) return 1;
    return 0;
}

int geo_db_ip_match(const geo_db_t *db, const char *code, const uint8_t addr[4]) {
    const geo_set_t *s = db_find(db, 'i', code);
    if (!s || !addr || !s->nranges) return 0;
    uint32_t a = (uint32_t)addr[0] << 24 | (uint32_t)addr[1] << 16 |
                 (uint32_t)addr[2] << 8 | addr[3];
    size_t lo = 0, hi = s->nranges;
    while (lo < hi) {
        size_t mid = lo + (hi - lo) / 2;
        if (s->lo[mid] <= a) lo = mid + 1;
        else hi = mid;
    }
    return lo > 0 && a <= s->hi[lo - 1];
}

long geo_db_count(const geo_db_t *db, char kind, const char *code) {
    const geo_set_t *s = db_find(db, kind, code);
    return s ? s->count : -1;
}

/* ---- the published database ---------------------------------------------- */

static pthread_rwlock_t g_lock = PTHREAD_RWLOCK_INITIALIZER;
static geo_db_t *g_db;

void geo_publish(geo_db_t *db) {
    pthread_rwlock_wrlock(&g_lock);
    geo_db_t *old = g_db;
    g_db = db;
    pthread_rwlock_unlock(&g_lock);
    geo_db_free(old);
}

int geo_site_match(const char *code, const char *name) {
    pthread_rwlock_rdlock(&g_lock);
    int r = geo_db_site_match(g_db, code, name);
    pthread_rwlock_unlock(&g_lock);
    return r;
}

int geo_ip_match(const char *code, const uint8_t addr[4]) {
    pthread_rwlock_rdlock(&g_lock);
    int r = geo_db_ip_match(g_db, code, addr);
    pthread_rwlock_unlock(&g_lock);
    return r;
}

long geo_count(char kind, const char *code) {
    pthread_rwlock_rdlock(&g_lock);
    long r = geo_db_count(g_db, kind, code);
    pthread_rwlock_unlock(&g_lock);
    return r;
}
