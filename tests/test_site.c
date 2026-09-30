/* the split tunnel site modes: what a typed or pasted site becomes, its head
   domain, and that the two rule types the modes save match what the user was
   shown ("only this domain" and "the head domain with every subdomain") */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "lr_site.h"
#include "rules.h"

static int failures;

#define CHECK(cond, ...) do { \
    if (!(cond)) { ++failures; fprintf(stderr, "FAIL %s:%d: ", __FILE__, __LINE__); \
                   fprintf(stderr, __VA_ARGS__); fputc('\n', stderr); } } while (0)

static void expect(const char *input, int ok, const char *host, lr_site_kind_t kind, int wild) {
    char out[LR_SITE_MAX];
    lr_site_kind_t k = (lr_site_kind_t)-1;
    int w = -1;
    int r = lr_site_parse(input, out, sizeof out, &k, &w);
    if (!ok) {
        CHECK(r < 0, "%s should not parse, got %s", input, out);
        return;
    }
    CHECK(r == 0, "%s did not parse", input);
    if (r) return;
    CHECK(strcmp(out, host) == 0, "%s -> %s, want %s", input, out, host);
    CHECK(k == kind, "%s kind %d, want %d", input, (int)k, (int)kind);
    if (kind == LR_SITE_NAME) CHECK(w == wild, "%s wildcard %d, want %d", input, w, wild);
}

static void head(const char *host, const char *want) {
    const char *h = lr_site_head(host);
    CHECK(strcmp(h, want) == 0, "head of %s is %s, want %s", host, h, want);
}

static void punycode(const char *utf8, const char *want) {
    char out[LR_SITE_MAX];
    lr_site_kind_t k;
    int w;
    CHECK(lr_site_parse(utf8, out, sizeof out, &k, &w) == 0 && strcmp(out, want) == 0,
          "%s -> %s, want %s", utf8, out, want);
}

static void test_parse(void) {
    expect("abc.com", 1, "abc.com", LR_SITE_NAME, 0);
    expect("  Xyz.ABC.com  ", 1, "xyz.abc.com", LR_SITE_NAME, 0);
    expect("https://xyz.abc.com/some/page?x=1#top", 1, "xyz.abc.com", LR_SITE_NAME, 0);
    expect("xyz.abc.com/*", 1, "xyz.abc.com", LR_SITE_NAME, 0);
    expect("*.abc.com/*", 1, "abc.com", LR_SITE_NAME, 1);
    expect("*.abc.com", 1, "abc.com", LR_SITE_NAME, 1);
    expect(".abc.com", 1, "abc.com", LR_SITE_NAME, 1);
    expect("abc.com.", 1, "abc.com", LR_SITE_NAME, 0);
    expect("user:secret@abc.com:8443", 1, "abc.com", LR_SITE_NAME, 0);
    expect("ftp://files.abc.com", 1, "files.abc.com", LR_SITE_NAME, 0);
    expect("_dmarc.abc.com", 1, "_dmarc.abc.com", LR_SITE_NAME, 0);
    expect("localhost", 1, "localhost", LR_SITE_NAME, 0);
    expect("1.2.3.4", 1, "1.2.3.4", LR_SITE_IPV4, 0);
    expect("http://1.2.3.4:80/x", 1, "1.2.3.4", LR_SITE_IPV4, 0);
    expect("10.0.0.0/8", 1, "10.0.0.0/8", LR_SITE_CIDR, 0);
    expect("10.0.0.0/33", 0, NULL, 0, 0);
    expect("10.0.0.0/x", 0, NULL, 0, 0);
    expect("*.1.2.3.4", 0, NULL, 0, 0);
    expect("", 0, NULL, 0, 0);
    expect("   ", 0, NULL, 0, 0);
    expect("*.", 0, NULL, 0, 0);
    expect("bad site.com", 0, NULL, 0, 0);
    expect("a..b", 0, NULL, 0, 0);
    expect("[::1]", 0, NULL, 0, 0);
    expect("2001:db8::1", 0, NULL, 0, 0);
    expect("abc.com:http", 0, NULL, 0, 0);
    expect("a!b.com", 0, NULL, 0, 0);
    /* a 64 letter label is one too long */
    expect("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.com", 0, NULL, 0, 0);
    expect("\xff\xfe.com", 0, NULL, 0, 0);
}

static void test_idn(void) {
    /* rfc 3492 and well known registrations */
    punycode("пример.рф", "xn--e1afmkfd.xn--p1ai");
    punycode("ПРИМЕР.РФ", "xn--e1afmkfd.xn--p1ai");
    punycode("https://госуслуги.рф/help", "xn--c1aapkosapc.xn--p1ai");
    punycode("bücher.de", "xn--bcher-kva.de");
    punycode("München.de", "xn--mnchen-3ya.de");
    punycode("点看.cn", "xn--3pxu8k.cn");
    punycode("пример\xe3\x80\x82рф", "xn--e1afmkfd.xn--p1ai");   /* ideographic full stop */
    unsigned cps[] = { 0x0644, 0x064A, 0x0647, 0x0645, 0x0627, 0x0628, 0x062A, 0x0643, 0x0644,
                       0x0645, 0x0648, 0x0634, 0x0639, 0x0631, 0x0628, 0x064A, 0x061F };
    char out[64];
    int n = lr_punycode_encode(cps, sizeof cps / sizeof cps[0], out, sizeof out);
    CHECK(n > 0 && strcmp(out, "egbpdaj6bu4bxfgehfvwxn") == 0, "rfc 3492 (a) -> %s", out);
    char tiny[4];
    CHECK(lr_punycode_encode(cps, sizeof cps / sizeof cps[0], tiny, sizeof tiny) < 0, "tiny buffer");
}

static void display(const char *host, const char *want) {
    char out[LR_SITE_MAX];
    lr_site_display(host, out, sizeof out);
    CHECK(strcmp(out, want) == 0, "display %s -> %s, want %s", host, out, want);
}

static void test_display(void) {
    display("xn--e1afmkfd.xn--p1ai", "пример.рф");
    display("www.xn--c1aapkosapc.xn--p1ai", "www.госуслуги.рф");
    display("xn--bcher-kva.de", "bücher.de");
    display("xn--3pxu8k.cn", "点看.cn");
    display("abc.com", "abc.com");
    display("xn--.com", "xn--.com");
    display("xn--99999999999.com", "xn--99999999999.com");
    unsigned back[64];
    int n = lr_punycode_decode("egbpdaj6bu4bxfgehfvwxn", 22, back, 64);
    CHECK(n == 17 && back[0] == 0x0644 && back[16] == 0x061F, "rfc 3492 (a) back: %d", n);
    char tiny[6];
    lr_site_display("xn--e1afmkfd.xn--p1ai", tiny, sizeof tiny);
    CHECK(strlen(tiny) < sizeof tiny, "display into a small buffer stays terminated");
}

static void test_head(void) {
    head("abc.com", "abc.com");
    head("xyz.abc.com", "abc.com");
    head("a.b.xyz.abc.com", "abc.com");
    head("music.youtube.com", "youtube.com");
    head("news.bbc.co.uk", "bbc.co.uk");
    head("bbc.co.uk", "bbc.co.uk");
    head("co.uk", "co.uk");
    head("user.github.io", "user.github.io");
    head("docs.user.github.io", "user.github.io");
    head("m.vk.com", "vk.com");
    head("www.site.com.ru", "site.com.ru");
    head("localhost", "localhost");
    head("1.2.3.4", "1.2.3.4");
    head("10.0.0.0/8", "10.0.0.0/8");
    head("xn--e1afmkfd.xn--p1ai", "xn--e1afmkfd.xn--p1ai");
    head("www.xn--e1afmkfd.xn--p1ai", "xn--e1afmkfd.xn--p1ai");
}

/* the two modes, as the daemon matches them */
static ruleset_t rules;   /* a megabyte: not on the stack */

static int matches(const char *type, const char *value, const char *name) {
    ruleset_init(&rules);
    char line[512];
    int n = snprintf(line, sizeof line, "direct %s %s", type, value);
    if (ruleset_add_text(&rules, line, (size_t)n, NULL) != RULES_OK) return -1;
    size_t hit = SIZE_MAX;
    rule_action_t a = ruleset_match_domain(&rules, name, &hit);
    return hit != SIZE_MAX && a == RULE_ACTION_DIRECT;
}

static void test_modes(void) {
    /* only this domain: xyz.abc.com and abc.com each match themselves */
    CHECK(matches("domain", "xyz.abc.com", "xyz.abc.com") == 1, "exact xyz");
    CHECK(matches("domain", "xyz.abc.com", "abc.com") == 0, "exact xyz vs head");
    CHECK(matches("domain", "xyz.abc.com", "a.xyz.abc.com") == 0, "exact xyz vs sub");
    CHECK(matches("domain", "abc.com", "abc.com") == 1, "exact abc");
    CHECK(matches("domain", "abc.com", "www.abc.com") == 0, "exact abc vs www");
    /* the head domain: abc.com and everything under it, nothing beside it */
    CHECK(matches("domain-suffix", "abc.com", "abc.com") == 1, "head itself");
    CHECK(matches("domain-suffix", "abc.com", "xyz.abc.com") == 1, "head sub");
    CHECK(matches("domain-suffix", "abc.com", "a.b.xyz.abc.com") == 1, "head deep");
    CHECK(matches("domain-suffix", "abc.com", "notabc.com") == 0, "head lookalike");
    CHECK(matches("domain-suffix", "abc.com", "abc.com.evil.net") == 0, "head suffix trick");
}

int main(void) {
    test_parse();
    test_idn();
    test_head();
    test_display();
    test_modes();
    if (failures) {
        fprintf(stderr, "%d failures\n", failures);
        return 1;
    }
    printf("site modes: ok\n");
    return 0;
}
