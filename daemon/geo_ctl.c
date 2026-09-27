#define _DEFAULT_SOURCE
#include "geo_ctl.h"
#include "core/geo.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define GEO_MAX_CODES 64
/* big enough for dlc.dat and a full geoip.dat, small enough to refuse the
   70 MB geosite builds an old phone cannot hold */
#define GEO_SITE_CAP (16u * 1024 * 1024)
#define GEO_IP_CAP   (24u * 1024 * 1024)
#define GEO_LIST_CAP (2u * 1024 * 1024)
#define GEO_FETCH_MS 180000

typedef struct {
    const char *site[GEO_MAX_CODES];
    size_t nsite;
    const char *ip[GEO_MAX_CODES];
    size_t nip;
} geo_codes_t;

static void add_code(const char **list, size_t *n, const char *code) {
    for (size_t i = 0; i < *n; ++i) if (strcmp(list[i], code) == 0) return;
    if (*n < GEO_MAX_CODES) list[(*n)++] = code;
}

static void collect(const ruleset_t *rules, geo_codes_t *c) {
    memset(c, 0, sizeof *c);
    if (!rules) return;
    for (size_t i = 0; i < rules->count; ++i) {
        const rule_t *r = &rules->entries[i];
        if (r->type == RULE_TYPE_GEOSITE) add_code(c->site, &c->nsite, r->value);
        else if (r->type == RULE_TYPE_GEOIP) add_code(c->ip, &c->nip, r->value);
    }
}

static int ensure_dir(void) {
    if (mkdir(LR_GEO_DIR, 0755) == 0 || errno == EEXIST) return 0;
    return -1;
}

static int have_list(char kind, const char *code) {
    char path[512];
    return geo_file_path(path, sizeof path, LR_GEO_DIR, kind, code) == 0 &&
           access(path, R_OK) == 0;
}

static uint8_t *read_file(const char *path, size_t *len) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return NULL; }
    long n = ftell(f);
    if (n <= 0 || (unsigned long)n > GEO_IP_CAP) { fclose(f); return NULL; }
    rewind(f);
    uint8_t *buf = (uint8_t *)malloc((size_t)n);
    if (buf && fread(buf, 1, (size_t)n, f) != (size_t)n) { free(buf); buf = NULL; }
    fclose(f);
    if (buf) *len = (size_t)n;
    return buf;
}

static int write_file_atomic(const char *path, const uint8_t *buf, size_t len) {
    char tmp[512];
    if (snprintf(tmp, sizeof tmp, "%s.part", path) >= (int)sizeof tmp) return -1;
    FILE *f = fopen(tmp, "wb");
    if (!f) return -1;
    int ok = fwrite(buf, 1, len, f) == len;
    if (fclose(f) != 0) ok = 0;
    if (!ok || rename(tmp, path) != 0) { unlink(tmp); return -1; }
    return 0;
}

/* pull whatever is missing out of the kept .dat files */
static void extract_missing(const geo_codes_t *c) {
    const char *want[GEO_MAX_CODES];
    long found[GEO_MAX_CODES];
    size_t n = 0;
    for (size_t i = 0; i < c->nsite; ++i)
        if (!have_list('s', c->site[i])) want[n++] = c->site[i];
    if (n) {
        size_t len = 0;
        uint8_t *dat = read_file(LR_GEO_DIR "/geosite.dat", &len);
        if (dat) {
            (void)geo_extract_sites(dat, len, want, n, LR_GEO_DIR, found);
            free(dat);
        }
    }
    n = 0;
    for (size_t i = 0; i < c->nip; ++i) {
        if (have_list('i', c->ip[i])) continue;
        if (strcmp(c->ip[i], "private") == 0) { (void)geo_write_private(LR_GEO_DIR); continue; }
        want[n++] = c->ip[i];
    }
    if (n) {
        size_t len = 0;
        uint8_t *dat = read_file(LR_GEO_DIR "/geoip.dat", &len);
        if (dat) {
            (void)geo_extract_ips(dat, len, want, n, LR_GEO_DIR, found);
            free(dat);
        }
    }
}

int geo_ctl_reload(const ruleset_t *rules, char *msg, size_t cap) {
    geo_codes_t c;
    collect(rules, &c);
    if (!c.nsite && !c.nip) {
        geo_publish(NULL);
        if (msg && cap) snprintf(msg, cap, "no geo rules");
        return 0;
    }
    (void)ensure_dir();
    extract_missing(&c);
    geo_db_t *db = geo_db_new();
    if (!db) return -1;
    int missing = 0;
    size_t off = 0;
    if (msg && cap) msg[0] = '\0';
    for (size_t i = 0; i < c.nsite + c.nip; ++i) {
        int site = i < c.nsite;
        const char *code = site ? c.site[i] : c.ip[i - c.nsite];
        long r = geo_db_load(db, site ? 's' : 'i', code, LR_GEO_DIR);
        if (r < 0) {
            ++missing;
            if (msg && off + 1 < cap) {
                int k = snprintf(msg + off, cap - off, "%s%s:%s", off ? " " : "missing ",
                                 site ? "geosite" : "geoip", code);
                if (k > 0) off += (size_t)k < cap - off ? (size_t)k : cap - off - 1;
            }
        }
    }
    geo_publish(db);
    if (msg && cap && !missing) snprintf(msg, cap, "%zu geosite, %zu geoip loaded", c.nsite, c.nip);
    fprintf(stderr, "legacyrayd: geo: %s\n", msg && msg[0] ? msg : "loaded");
    return missing;
}

static int fetch_to(geo_fetch_fn fetch, void *ctx, const char *url, size_t cap,
                    uint8_t **out, size_t *len) {
    uint8_t *buf = (uint8_t *)malloc(cap);
    if (!buf) return -1;
    size_t n = 0;
    if (fetch(ctx, url, buf, cap, &n, GEO_FETCH_MS) != 0 || n == 0) {
        free(buf);
        return -1;
    }
    *out = buf;
    *len = n;
    return 0;
}

int geo_ctl_update(geo_fetch_fn fetch, void *ctx, const daemon_settings_t *s,
                   const ruleset_t *rules, char *msg, size_t cap) {
    if (!fetch || !s) return -1;
    if (ensure_dir() != 0) {
        if (msg && cap) snprintf(msg, cap, "cannot create %s", LR_GEO_DIR);
        return -1;
    }
    geo_codes_t c;
    collect(rules, &c);
    int failures = 0;
    char why[160] = "";

    uint8_t *dat = NULL;
    size_t len = 0;
    if (fetch_to(fetch, ctx, s->geosite_url, GEO_SITE_CAP, &dat, &len) == 0) {
        long found[GEO_MAX_CODES];
        if (geo_extract_sites(dat, len, c.site, c.nsite, LR_GEO_DIR, found) == GEO_OK &&
            write_file_atomic(LR_GEO_DIR "/geosite.dat", dat, len) == 0) {
            fprintf(stderr, "legacyrayd: geo: geosite.dat updated (%zu bytes)\n", len);
        } else {
            ++failures;
            snprintf(why, sizeof why, "geosite download is not a geosite list");
        }
        free(dat);
    } else {
        ++failures;
        snprintf(why, sizeof why, "geosite download failed (too big or unreachable)");
    }

    const char *per_country = strstr(s->geoip_url, "%s");
    if (per_country) {
        for (size_t i = 0; i < c.nip; ++i) {
            if (strcmp(c.ip[i], "private") == 0) { (void)geo_write_private(LR_GEO_DIR); continue; }
            char url[SETTINGS_URL_MAX + GEO_CODE_MAX];
            size_t head = (size_t)(per_country - s->geoip_url);
            snprintf(url, sizeof url, "%.*s%s%s", (int)head, s->geoip_url, c.ip[i],
                     per_country + 2);
            if (fetch_to(fetch, ctx, url, GEO_LIST_CAP, &dat, &len) == 0) {
                if (geo_save_ip_list((const char *)dat, len, c.ip[i], LR_GEO_DIR) <= 0) {
                    ++failures;
                    snprintf(why, sizeof why, "geoip %s: not an address list", c.ip[i]);
                }
                free(dat);
            } else {
                ++failures;
                snprintf(why, sizeof why, "geoip %s download failed", c.ip[i]);
            }
        }
    } else if (c.nip) {
        if (fetch_to(fetch, ctx, s->geoip_url, GEO_IP_CAP, &dat, &len) == 0) {
            long found[GEO_MAX_CODES];
            if (geo_extract_ips(dat, len, c.ip, c.nip, LR_GEO_DIR, found) == GEO_OK)
                (void)write_file_atomic(LR_GEO_DIR "/geoip.dat", dat, len);
            else {
                ++failures;
                snprintf(why, sizeof why, "geoip download is not a geoip list");
            }
            free(dat);
        } else {
            ++failures;
            snprintf(why, sizeof why, "geoip download failed (too big or unreachable)");
        }
    }

    char loaded[256];
    int missing = geo_ctl_reload(rules, loaded, sizeof loaded);
    if (msg && cap)
        snprintf(msg, cap, "%s%s%s", failures ? why : "updated", "; ", loaded);
    return failures && missing ? -1 : 0;
}

static long file_size(const char *path, long *mtime) {
    struct stat st;
    if (stat(path, &st) != 0) return -1;
    if (mtime) *mtime = (long)st.st_mtime;
    return (long)st.st_size;
}

size_t geo_ctl_status(const ruleset_t *rules, char *buf, size_t cap) {
    if (!buf || cap == 0) return 0;
    geo_codes_t c;
    collect(rules, &c);
    size_t off = 0;
    buf[0] = '\0';
#define GEO_EMIT(...) do { int k = snprintf(buf + off, cap - off, __VA_ARGS__); \
                           if (k < 0 || (size_t)k >= cap - off) return off; \
                           off += (size_t)k; } while (0)
    for (size_t i = 0; i < c.nsite; ++i) {
        long n = geo_count('s', c.site[i]);
        if (n >= 0) GEO_EMIT("GEO site %s %ld\n", c.site[i], n);
        else GEO_EMIT("GEO site %s missing\n", c.site[i]);
    }
    for (size_t i = 0; i < c.nip; ++i) {
        long n = geo_count('i', c.ip[i]);
        if (n >= 0) GEO_EMIT("GEO ip %s %ld\n", c.ip[i], n);
        else GEO_EMIT("GEO ip %s missing\n", c.ip[i]);
    }
    long mtime = 0, size = file_size(LR_GEO_DIR "/geosite.dat", &mtime);
    if (size >= 0) GEO_EMIT("GEO file geosite.dat %ld %ld\n", size, mtime);
    size = file_size(LR_GEO_DIR "/geoip.dat", &mtime);
    if (size >= 0) GEO_EMIT("GEO file geoip.dat %ld %ld\n", size, mtime);
#undef GEO_EMIT
    return off;
}
