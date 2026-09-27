#include "rules.h"

#include <arpa/inet.h>
#include <ctype.h>
#include <stdio.h>
#include <string.h>

static int action_rank(rule_action_t action) {
    if (action == RULE_ACTION_BLOCK) return 3;
    if (action == RULE_ACTION_DIRECT) return 2;
    return 1;
}

const char *rule_type_name(rule_type_t type) {
    if (type == RULE_TYPE_DOMAIN_SUFFIX) return "domain-suffix";
    if (type == RULE_TYPE_DOMAIN_KEYWORD) return "domain-keyword";
    if (type == RULE_TYPE_IP_CIDR) return "ip-cidr";
    if (type == RULE_TYPE_DOMAIN_FULL) return "domain";
    if (type == RULE_TYPE_PORT) return "port";
    if (type == RULE_TYPE_GEOSITE) return "geosite";
    if (type == RULE_TYPE_GEOIP) return "geoip";
    return NULL;
}

const char *rule_action_name(rule_action_t action) {
    if (action == RULE_ACTION_PROXY) return "proxy";
    if (action == RULE_ACTION_DIRECT) return "direct";
    if (action == RULE_ACTION_BLOCK) return "block";
    return NULL;
}

uint64_t rule_hit_count(const rule_t *rule) {
    if (!rule) return 0;
    return __sync_fetch_and_add((uint64_t *)&rule->hits, 0);
}

void ruleset_init(ruleset_t *rules) {
    if (rules) memset(rules, 0, sizeof *rules);
}

static int parse_action(const char *text, size_t len, rule_action_t *out) {
    if (len == 5 && memcmp(text, "proxy", 5) == 0) *out = RULE_ACTION_PROXY;
    else if (len == 6 && memcmp(text, "direct", 6) == 0) *out = RULE_ACTION_DIRECT;
    else if (len == 5 && memcmp(text, "block", 5) == 0) *out = RULE_ACTION_BLOCK;
    else return -1;
    return 0;
}

static int parse_type(const char *text, size_t len, rule_type_t *out) {
    if (len == 13 && memcmp(text, "domain-suffix", 13) == 0)
        *out = RULE_TYPE_DOMAIN_SUFFIX;
    else if (len == 14 && memcmp(text, "domain-keyword", 14) == 0)
        *out = RULE_TYPE_DOMAIN_KEYWORD;
    else if (len == 7 && memcmp(text, "ip-cidr", 7) == 0)
        *out = RULE_TYPE_IP_CIDR;
    else if (len == 6 && memcmp(text, "domain", 6) == 0)
        *out = RULE_TYPE_DOMAIN_FULL;
    else if (len == 4 && memcmp(text, "port", 4) == 0)
        *out = RULE_TYPE_PORT;
    else if (len == 7 && memcmp(text, "geosite", 7) == 0)
        *out = RULE_TYPE_GEOSITE;
    else if (len == 5 && memcmp(text, "geoip", 5) == 0)
        *out = RULE_TYPE_GEOIP;
    else return -1;
    return 0;
}

static int normalize_domain(const char *text, size_t len, char *out, size_t cap) {
    while (len > 0 && text[0] == '.') {
        ++text;
        --len;
    }
    while (len > 0 && text[len - 1] == '.') --len;
    if (len == 0 || len >= cap || len > 253) return -1;
    size_t label = 0;
    for (size_t i = 0; i < len; ++i) {
        unsigned char c = (unsigned char)text[i];
        if (c == '.') {
            if (label == 0 || label > 63) return -1;
            label = 0;
            out[i] = '.';
            continue;
        }
        if (c >= 0x80 || isspace(c) || c == '/' || c == '\\') return -1;
        out[i] = (char)tolower(c);
        ++label;
    }
    if (label == 0 || label > 63) return -1;
    out[len] = '\0';
    return 0;
}

/* a geosite / geoip code, the same canonical form geo.c writes files for:
   lower case [a-z0-9._-!], one optional @attribute */
static int normalize_geo_code(const char *text, size_t len, char *out, size_t cap) {
    if (len == 0 || len >= cap || len >= 64) return -1;
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

static int parse_cidr(rule_t *rule, const char *text, size_t len) {
    char input[RULE_VALUE_MAX];
    char canonical[INET6_ADDRSTRLEN];
    if (len == 0 || len >= sizeof input) return -1;
    memcpy(input, text, len);
    input[len] = '\0';
    char *slash = strchr(input, '/');
    if (!slash || slash == input || !slash[1]) return -1;
    *slash++ = '\0';
    unsigned prefix = 0;
    for (const char *p = slash; *p; ++p) {
        if (*p < '0' || *p > '9') return -1;
        prefix = prefix * 10u + (unsigned)(*p - '0');
        if (prefix > 128) return -1;
    }
    int family;
    if (inet_pton(AF_INET, input, rule->address) == 1) {
        if (prefix > 32) return -1;
        family = AF_INET;
        rule->address_len = 4;
    } else if (inet_pton(AF_INET6, input, rule->address) == 1) {
        family = AF_INET6;
        rule->address_len = 16;
    } else {
        return -1;
    }
    rule->prefix = (uint8_t)prefix;
    unsigned whole = prefix / 8;
    unsigned bits = prefix % 8;
    if (bits && whole < rule->address_len)
        rule->address[whole] &= (uint8_t)(0xffu << (8 - bits));
    for (unsigned i = whole + (bits ? 1u : 0u); i < rule->address_len; ++i)
        rule->address[i] = 0;
    if (!inet_ntop(family, rule->address, canonical, sizeof canonical)) return -1;
    int n = snprintf(rule->value, sizeof rule->value, "%s/%u", canonical, prefix);
    return n > 0 && (size_t)n < sizeof rule->value ? 0 : -1;
}

/* "443" or "8000-8999"; the canonical text drops leading zeros so two
   spellings of one range are one rule */
static int parse_port_range(rule_t *rule, const char *text, size_t len) {
    unsigned long lo = 0, hi = 0;
    size_t i = 0;
    int digits = 0;
    if (len == 0 || len > 11) return -1;
    while (i < len && text[i] >= '0' && text[i] <= '9') {
        lo = lo * 10ul + (unsigned long)(text[i++] - '0');
        if (lo > 65535ul) return -1;
        digits = 1;
    }
    if (!digits) return -1;
    hi = lo;
    if (i < len) {
        if (text[i++] != '-') return -1;
        hi = 0;
        digits = 0;
        while (i < len && text[i] >= '0' && text[i] <= '9') {
            hi = hi * 10ul + (unsigned long)(text[i++] - '0');
            if (hi > 65535ul) return -1;
            digits = 1;
        }
        if (!digits || i != len) return -1;
    }
    if (lo == 0 || hi < lo) return -1;
    rule->port_lo = (uint16_t)lo;
    rule->port_hi = (uint16_t)hi;
    int n = lo == hi
        ? snprintf(rule->value, sizeof rule->value, "%lu", lo)
        : snprintf(rule->value, sizeof rule->value, "%lu-%lu", lo, hi);
    return n > 0 && (size_t)n < sizeof rule->value ? 0 : -1;
}

int rule_is_port(const rule_t *rule) {
    return rule && rule->type == RULE_TYPE_PORT;
}

rules_status_t rules_parse(const char *text, size_t len, rule_t *out) {
    if (!text || !out) return RULES_ERR_ARG;
    memset(out, 0, sizeof *out);
    while (len > 0 && (text[len - 1] == '\n' || text[len - 1] == '\r')) --len;
    const char *first = memchr(text, ' ', len);
    if (!first) return RULES_ERR_ACTION;
    size_t action_len = (size_t)(first - text);
    if (parse_action(text, action_len, &out->action) != 0) return RULES_ERR_ACTION;
    const char *type = first + 1;
    size_t left = len - action_len - 1;
    const char *second = memchr(type, ' ', left);
    if (!second) return RULES_ERR_TYPE;
    size_t type_len = (size_t)(second - type);
    if (parse_type(type, type_len, &out->type) != 0) return RULES_ERR_TYPE;
    const char *value = second + 1;
    size_t value_len = left - type_len - 1;
    if (value_len == 0 || memchr(value, ' ', value_len)) return RULES_ERR_VALUE;
    if (out->type == RULE_TYPE_IP_CIDR) {
        if (parse_cidr(out, value, value_len) != 0) return RULES_ERR_VALUE;
    } else if (out->type == RULE_TYPE_PORT) {
        if (parse_port_range(out, value, value_len) != 0) return RULES_ERR_VALUE;
    } else if (out->type == RULE_TYPE_GEOSITE || out->type == RULE_TYPE_GEOIP) {
        if (normalize_geo_code(value, value_len, out->value, sizeof out->value) != 0)
            return RULES_ERR_VALUE;
        if (out->type == RULE_TYPE_GEOIP && strchr(out->value, '@'))
            return RULES_ERR_VALUE;
    } else if (normalize_domain(value, value_len, out->value,
                                sizeof out->value) != 0) {
        return RULES_ERR_VALUE;
    }
    return RULES_OK;
}

rules_status_t ruleset_add(ruleset_t *rules, const rule_t *rule, size_t *out_index) {
    if (!rules || !rule || !rule_type_name(rule->type) ||
        !rule_action_name(rule->action) || !rule->value[0]) return RULES_ERR_ARG;
    for (size_t i = 0; i < rules->count; ++i) {
        rule_t *old = &rules->entries[i];
        if (old->type != rule->type || strcmp(old->value, rule->value) != 0) continue;
        old->action = rule->action;
        old->hits = 0;
        if (out_index) *out_index = i;
        return RULES_OK;
    }
    if (rules->count >= RULESET_MAX_RULES) return RULES_ERR_FULL;
    if (rule->type == RULE_TYPE_PORT) {
        size_t ports = 0;
        for (size_t i = 0; i < rules->count; ++i)
            if (rules->entries[i].type == RULE_TYPE_PORT) ++ports;
        if (ports >= RULESET_MAX_PORT_RULES) return RULES_ERR_FULL;
    }
    rules->entries[rules->count] = *rule;
    rules->entries[rules->count].hits = 0;
    if (out_index) *out_index = rules->count;
    ++rules->count;
    return RULES_OK;
}

rules_status_t ruleset_add_text(ruleset_t *rules, const char *text, size_t len,
                                size_t *out_index) {
    rule_t rule;
    rules_status_t status = rules_parse(text, len, &rule);
    if (status != RULES_OK) return status;
    return ruleset_add(rules, &rule, out_index);
}

rules_status_t ruleset_remove(ruleset_t *rules, size_t index) {
    if (!rules) return RULES_ERR_ARG;
    if (index >= rules->count) return RULES_ERR_RANGE;
    if (index + 1 < rules->count)
        memmove(&rules->entries[index], &rules->entries[index + 1],
                (rules->count - index - 1) * sizeof rules->entries[0]);
    --rules->count;
    memset(&rules->entries[rules->count], 0, sizeof rules->entries[0]);
    return RULES_OK;
}

static rules_geo_site_fn g_geo_site;

void rules_set_geo_site_matcher(rules_geo_site_fn fn) {
    g_geo_site = fn;
}

static int suffix_matches(const char *domain, const char *suffix) {
    size_t dl = strlen(domain);
    size_t sl = strlen(suffix);
    if (dl < sl || memcmp(domain + dl - sl, suffix, sl) != 0) return 0;
    return dl == sl || domain[dl - sl - 1] == '.';
}

rule_action_t ruleset_match_domain(ruleset_t *rules, const char *domain,
                                   size_t *matched_index) {
    char normalized[RULE_VALUE_MAX];
    int best_rank = 0;
    size_t best = SIZE_MAX;
    if (matched_index) *matched_index = SIZE_MAX;
    if (!rules || !domain ||
        normalize_domain(domain, strlen(domain), normalized, sizeof normalized) != 0)
        return RULE_ACTION_PROXY;
    for (size_t i = 0; i < rules->count; ++i) {
        rule_t *rule = &rules->entries[i];
        int match = rule->type == RULE_TYPE_DOMAIN_SUFFIX
            ? suffix_matches(normalized, rule->value)
            : rule->type == RULE_TYPE_DOMAIN_KEYWORD
                ? strstr(normalized, rule->value) != NULL
                : rule->type == RULE_TYPE_DOMAIN_FULL
                    ? strcmp(normalized, rule->value) == 0
                    : rule->type == RULE_TYPE_GEOSITE && g_geo_site
                        ? g_geo_site(rule->value, normalized) != 0 : 0;
        int rank = action_rank(rule->action);
        if (match && rank > best_rank) {
            best_rank = rank;
            best = i;
        }
    }
    if (best == SIZE_MAX) return RULE_ACTION_PROXY;
    (void)__sync_fetch_and_add(&rules->entries[best].hits, 1);
    if (matched_index) *matched_index = best;
    return rules->entries[best].action;
}

static int cidr_matches(const uint8_t *address, const rule_t *rule) {
    unsigned whole = rule->prefix / 8;
    unsigned bits = rule->prefix % 8;
    if (whole && memcmp(address, rule->address, whole) != 0) return 0;
    if (!bits) return 1;
    uint8_t mask = (uint8_t)(0xffu << (8 - bits));
    return (address[whole] & mask) == rule->address[whole];
}

rule_action_t ruleset_match_ip(ruleset_t *rules, const char *ip,
                               size_t *matched_index) {
    uint8_t address[16];
    uint8_t address_len;
    int best_rank = 0;
    size_t best = SIZE_MAX;
    if (matched_index) *matched_index = SIZE_MAX;
    if (!rules || !ip) return RULE_ACTION_PROXY;
    if (inet_pton(AF_INET, ip, address) == 1) address_len = 4;
    else if (inet_pton(AF_INET6, ip, address) == 1) address_len = 16;
    else return RULE_ACTION_PROXY;
    for (size_t i = 0; i < rules->count; ++i) {
        rule_t *rule = &rules->entries[i];
        if (rule->type != RULE_TYPE_IP_CIDR || rule->address_len != address_len ||
            !cidr_matches(address, rule)) continue;
        int rank = action_rank(rule->action);
        if (rank > best_rank) {
            best_rank = rank;
            best = i;
        }
    }
    if (best == SIZE_MAX) return RULE_ACTION_PROXY;
    (void)__sync_fetch_and_add(&rules->entries[best].hits, 1);
    if (matched_index) *matched_index = best;
    return rules->entries[best].action;
}
