#ifndef SENKO_RULES_H
#define SENKO_RULES_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RULESET_MAX_RULES 4096
#define RULE_VALUE_MAX 256

typedef enum {
    RULE_TYPE_DOMAIN_SUFFIX = 0,
    RULE_TYPE_DOMAIN_KEYWORD,
    RULE_TYPE_IP_CIDR,
    /* legacyray: one exact name, without the subdomains a suffix would take */
    RULE_TYPE_DOMAIN_FULL,
    /* legacyray: a destination tcp port or an inclusive lo-hi range. names
       never carry a port, so these are enforced by the firewall, not dns */
    RULE_TYPE_PORT
} rule_type_t;

typedef enum {
    RULE_ACTION_PROXY = 0,
    RULE_ACTION_DIRECT,
    RULE_ACTION_BLOCK
} rule_action_t;

typedef struct {
    rule_type_t type;
    rule_action_t action;
    char value[RULE_VALUE_MAX];
    uint8_t address[16];
    uint8_t prefix;
    uint8_t address_len;
    uint16_t port_lo; /* RULE_TYPE_PORT only */
    uint16_t port_hi;
    uint64_t hits;
} rule_t;

typedef struct {
    rule_t entries[RULESET_MAX_RULES];
    size_t count;
} ruleset_t;

typedef enum {
    RULES_OK = 0,
    RULES_ERR_ARG = -1,
    RULES_ERR_TYPE = -2,
    RULES_ERR_ACTION = -3,
    RULES_ERR_VALUE = -4,
    RULES_ERR_FULL = -5,
    RULES_ERR_RANGE = -6
} rules_status_t;

void ruleset_init(ruleset_t *rules);
rules_status_t rules_parse(const char *text, size_t len, rule_t *out);
rules_status_t ruleset_add(ruleset_t *rules, const rule_t *rule, size_t *out_index);
rules_status_t ruleset_add_text(ruleset_t *rules, const char *text, size_t len,
                                size_t *out_index);
rules_status_t ruleset_remove(ruleset_t *rules, size_t index);

rule_action_t ruleset_match_domain(ruleset_t *rules, const char *domain,
                                   size_t *matched_index);
rule_action_t ruleset_match_ip(ruleset_t *rules, const char *ip,
                               size_t *matched_index);

/* how many port rules the firewall layers can carry; ipfw has a fixed number
   range and pf rules are emitted once per interface */
#define RULESET_MAX_PORT_RULES 8

const char *rule_type_name(rule_type_t type);
/* 1 when a rule is enforced by the firewall rather than by the dns proxy */
int rule_is_port(const rule_t *rule);
const char *rule_action_name(rule_action_t action);
uint64_t rule_hit_count(const rule_t *rule);

#ifdef __cplusplus
}
#endif

#endif
