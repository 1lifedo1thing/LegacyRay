#include "sniff.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

/* a minimal tls 1.2 client hello carrying one server_name */
static size_t make_hello(uint8_t *out, const char *name) {
    uint8_t body[512];
    size_t n = 0;
    body[n++] = 0x03; body[n++] = 0x03;          /* version */
    memset(body + n, 0x11, 32); n += 32;         /* random */
    body[n++] = 0;                               /* session id */
    body[n++] = 0; body[n++] = 2; body[n++] = 0x00; body[n++] = 0x2f; /* suites */
    body[n++] = 1; body[n++] = 0;                /* compression */
    size_t nl = strlen(name);
    size_t sni_len = 2 + 1 + 2 + nl;
    size_t ext_len = 4 + 4 + 4 + sni_len;        /* a dummy extension, then sni */
    body[n++] = (uint8_t)(ext_len >> 8); body[n++] = (uint8_t)ext_len;
    body[n++] = 0xff; body[n++] = 0x01; body[n++] = 0; body[n++] = 0; /* empty ext */
    body[n++] = 0x00; body[n++] = 0x17; body[n++] = 0; body[n++] = 0; /* another */
    body[n++] = 0; body[n++] = 0;                /* server_name */
    body[n++] = (uint8_t)(sni_len >> 8); body[n++] = (uint8_t)sni_len;
    body[n++] = (uint8_t)((sni_len - 2) >> 8); body[n++] = (uint8_t)(sni_len - 2);
    body[n++] = 0;
    body[n++] = (uint8_t)(nl >> 8); body[n++] = (uint8_t)nl;
    memcpy(body + n, name, nl); n += nl;

    size_t m = 0;
    out[m++] = 0x16; out[m++] = 0x03; out[m++] = 0x01;
    out[m++] = (uint8_t)((n + 4) >> 8); out[m++] = (uint8_t)(n + 4);
    out[m++] = 0x01; out[m++] = 0; out[m++] = (uint8_t)(n >> 8); out[m++] = (uint8_t)n;
    memcpy(out + m, body, n);
    return m + n;
}

int main(void) {
    char host[256];
    uint8_t hello[600];
    size_t len = make_hello(hello, "Www.Example.COM.");

    assert(sniff_host(hello, len, 16384, host, sizeof host) == SNIFF_FOUND);
    assert(strcmp(host, "www.example.com") == 0);
    for (size_t cut = 1; cut < len; ++cut)
        assert(sniff_host(hello, cut, 16384, host, sizeof host) == SNIFF_NEED_MORE);
    /* a record that cannot fit the buffer is not waited for */
    assert(sniff_host(hello, 20, 30, host, sizeof host) == SNIFF_NONE);

    const char *http = "GET /x HTTP/1.1\r\nUser-Agent: a\r\nhost:  Ya.RU:8080 \r\n\r\n";
    assert(sniff_host((const uint8_t *)http, strlen(http), 16384, host, sizeof host) == SNIFF_FOUND);
    assert(strcmp(host, "ya.ru") == 0);
    assert(sniff_host((const uint8_t *)http, 20, 16384, host, sizeof host) == SNIFF_NEED_MORE);
    assert(sniff_host((const uint8_t *)"GE", 2, 16384, host, sizeof host) == SNIFF_NEED_MORE);

    const char *nohost = "GET / HTTP/1.0\r\nAccept: */*\r\n\r\n";
    assert(sniff_host((const uint8_t *)nohost, strlen(nohost), 16384, host, sizeof host) == SNIFF_NONE);
    const char *banner = "SSH-2.0-OpenSSH\r\n";
    assert(sniff_host((const uint8_t *)banner, strlen(banner), 16384, host, sizeof host) == SNIFF_NONE);
    const char *bad = "GET / HTTP/1.1\r\nHost: evil host\r\n\r\n";
    assert(sniff_host((const uint8_t *)bad, strlen(bad), 16384, host, sizeof host) == SNIFF_NONE);
    assert(sniff_host(NULL, 0, 16384, host, sizeof host) == SNIFF_NEED_MORE);

    puts("all sniff checks passed");
    return 0;
}
