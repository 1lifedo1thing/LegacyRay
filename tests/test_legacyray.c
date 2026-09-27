/* the daemon features legacyray adds on top of senko: exact-domain and port
   rules, the lan bypass switch, the new settings keys and the extra
   subscription metadata that has to survive a save and a reload */
#include "rules.h"
#include "store.h"
#include "routing.h"
#include "settings.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;

static void ok(const char *name, int cond) {
    if (!cond) {
        printf("FAIL %s\n", name);
        ++failures;
    }
}

static void test_rules(void) {
    rule_t rule;
    ok("exact domain parses",
       rules_parse("direct domain Example.COM", 25, &rule) == RULES_OK &&
       rule.type == RULE_TYPE_DOMAIN_FULL && strcmp(rule.value, "example.com") == 0);
    ok("single port parses",
       rules_parse("block port 0443", 15, &rule) == RULES_OK &&
       rule.type == RULE_TYPE_PORT && rule.port_lo == 443 && rule.port_hi == 443 &&
       strcmp(rule.value, "443") == 0);
    ok("port range parses",
       rules_parse("direct port 8000-8999", 21, &rule) == RULES_OK &&
       rule.port_lo == 8000 && rule.port_hi == 8999 &&
       strcmp(rule.value, "8000-8999") == 0);
    ok("reversed range rejected", rules_parse("direct port 9-1", 15, &rule) != RULES_OK);
    ok("port zero rejected", rules_parse("direct port 0", 13, &rule) != RULES_OK);
    ok("port overflow rejected", rules_parse("direct port 70000", 17, &rule) != RULES_OK);
    ok("port junk rejected", rules_parse("direct port 80x", 15, &rule) != RULES_OK);
    ok("type names round trip",
       strcmp(rule_type_name(RULE_TYPE_DOMAIN_FULL), "domain") == 0 &&
       strcmp(rule_type_name(RULE_TYPE_PORT), "port") == 0);

    static ruleset_t set;
    ruleset_init(&set);
    ok("add exact", ruleset_add_text(&set, "direct domain example.com", 25, NULL) == RULES_OK);
    size_t matched = SIZE_MAX;
    ok("exact matches itself",
       ruleset_match_domain(&set, "example.com", &matched) == RULE_ACTION_DIRECT &&
       matched == 0);
    ok("exact skips subdomains",
       ruleset_match_domain(&set, "www.example.com", &matched) == RULE_ACTION_PROXY &&
       matched == SIZE_MAX);

    char text[32];
    for (int i = 0; i < RULESET_MAX_PORT_RULES; ++i) {
        int n = snprintf(text, sizeof text, "block port %d", 1000 + i);
        ok("port rule fits", ruleset_add_text(&set, text, (size_t)n, NULL) == RULES_OK);
    }
    ok("port rule cap enforced",
       ruleset_add_text(&set, "block port 5000", 15, NULL) == RULES_ERR_FULL);
    ok("ports never match names",
       ruleset_match_domain(&set, "1000", &matched) == RULE_ACTION_PROXY);
}

static void test_firewall(void) {
    static ruleset_t set;
    ruleset_init(&set);
    ruleset_add_text(&set, "direct port 8000-8999", 21, NULL);
    ruleset_add_text(&set, "block port 25", 13, NULL);
    const char ifs[1][32] = { "en0" };
    char *pf = malloc(65536);
    size_t len = 0;

    routing_set_policy(1, &set);
    ok("pf with ports builds",
       routing_pf_conf_rules("203.0.113.7", &set, ifs, 1, 40000, 15353,
                             ROUTING_PF_ROUTE_TO_LO0, pf, 65536, &len) == ROUTING_OK);
    pf[len] = '\0';
    ok("direct range uses pf colon syntax",
       strstr(pf, "pass out quick on en0 inet proto tcp from any to any port { 8000:8999 } keep state") != NULL);
    ok("blocked port filtered",
       strstr(pf, "block return out quick on en0 inet proto tcp from any to any port { 25 }") != NULL);
    ok("direct port exempt from nat",
       strstr(pf, "no nat on en0 inet proto tcp from any to any port { 8000:8999 }") != NULL);
    ok("lan ranges bypassed", strstr(pf, "192.168.0.0/16") != NULL &&
                              strstr(pf, "100.64.0.0/10") != NULL);
    ok("port filters precede the redirect",
       strstr(pf, "port { 25 }") < strstr(pf, "route-to lo0"));

    routing_set_policy(0, NULL);
    ok("pf without lan builds",
       routing_pf_conf_rules("203.0.113.7", NULL, ifs, 1, 40000, 15353,
                             ROUTING_PF_RDR_TO, pf, 65536, &len) == ROUTING_OK);
    pf[len] = '\0';
    ok("lan off keeps loopback", strstr(pf, "127.0.0.0/8") != NULL);
    ok("lan off drops private ranges", strstr(pf, "192.168.0.0/16") == NULL &&
                                       strstr(pf, "10.0.0.0/8") == NULL);

    routing_ipfw_rule_t rules[ROUTING_MAX_RULES];
    size_t count = 0;
    routing_set_policy(1, &set);
    ok("ipfw with ports builds",
       routing_ipfw_rules("203.0.113.7", 40000, 1080, 15353, rules,
                          ROUTING_MAX_RULES, &count) == ROUTING_OK);
    int saw_allow = 0, saw_deny = 0, ascending = 1, lan = 0;
    for (size_t i = 0; i < count; ++i) {
        if (strcmp(rules[i].rule_plain, "allow tcp from any to any 8000-8999") == 0) saw_allow = 1;
        if (strcmp(rules[i].rule_plain, "deny tcp from any to any 25") == 0) saw_deny = 1;
        if (strstr(rules[i].rule_plain, "169.254.0.0/16")) lan = 1;
        if (i && rules[i].number <= rules[i - 1].number) ascending = 0;
        ok("ipfw port rules stay below the fwd", rules[i].number <= 12020);
    }
    ok("ipfw direct port", saw_allow);
    ok("ipfw blocked port", saw_deny);
    ok("ipfw lan extras", lan);
    ok("ipfw ascending", ascending);
    routing_set_policy(1, NULL);
    free(pf);
}

static void test_settings(void) {
    daemon_settings_t s;
    daemon_settings_defaults(&s);
    ok("defaults keep full tunnel", s.rules_enabled == 1 && s.rules_default == 0 &&
                                    s.bypass_lan == 1);
    ok("default version", strcmp(s.xray_version, "26.7.28") == 0);
    ok("set rules_default",
       daemon_settings_set(&s, "rules_default", 13, "direct", 6) == SETTINGS_OK &&
       s.rules_default == 1);
    ok("bad rules_default",
       daemon_settings_set(&s, "rules_default", 13, "block", 5) == SETTINGS_ERR_VALUE);
    ok("set version",
       daemon_settings_set(&s, "xray_version", 12, "25.10.15", 8) == SETTINGS_OK &&
       strcmp(s.xray_version, "25.10.15") == 0);
    ok("version needs three parts",
       daemon_settings_set(&s, "xray_version", 12, "25.10", 5) == SETTINGS_ERR_VALUE);
    ok("version parts are bytes",
       daemon_settings_set(&s, "xray_version", 12, "1.256.0", 7) == SETTINGS_ERR_VALUE);
    const char *ua = "Happ/3.26.3/iOS CFNetwork";
    ok("user agent keeps spaces",
       daemon_settings_set(&s, "sub_user_agent", 14, ua, strlen(ua)) == SETTINGS_OK &&
       strcmp(s.sub_user_agent, ua) == 0);
    ok("bypass lan toggles",
       daemon_settings_set(&s, "bypass_lan", 10, "0", 1) == SETTINGS_OK && s.bypass_lan == 0);

    char buf[4096];
    size_t len = 0;
    ok("serialize", daemon_settings_serialize(&s, buf, sizeof buf, &len) == 0);
    daemon_settings_t back;
    daemon_settings_defaults(&back);
    daemon_settings_apply_buf(&back, buf, len);
    ok("round trip", back.rules_default == 1 && back.bypass_lan == 0 &&
                     strcmp(back.xray_version, "25.10.15") == 0 &&
                     strcmp(back.sub_user_agent, ua) == 0);
}

static void test_store_extra(void) {
    static store_t st, back;
    store_init(&st);
    size_t sub = 0;
    ok("add sub", store_add_sub(&st, "panel", "https://panel.example/sub", &sub) == STORE_OK);
    ok("set extra", store_set_sub_extra(&st, sub, 12, 1767225600ULL,
                                        "https://panel.example/me?a=1 b") == STORE_OK);
    static char buf[1 << 20];
    size_t len = 0;
    ok("store serializes", store_serialize(&st, buf, sizeof buf, &len) == STORE_OK);
    buf[len] = '\0';
    ok("extra line written", strstr(buf, "SUBEXTRA ") != NULL);
    ok("store reloads", store_deserialize(&back, buf, len) == STORE_OK);
    ok("extra survives",
       back.subs[sub].update_interval_h == 12 &&
       back.subs[sub].refill_date == 1767225600ULL &&
       strcmp(back.subs[sub].web_page_url, "https://panel.example/me?a=1 b") == 0);
}

int main(void) {
    test_rules();
    test_firewall();
    test_settings();
    test_store_extra();
    if (failures) {
        printf("%d check(s) failed\n", failures);
        return 1;
    }
    printf("all legacyray checks passed\n");
    return 0;
}
