#define _DEFAULT_SOURCE

#include "session.h"
#include "socks5.h"

#include <stdio.h>
#include <string.h>

static int g_fail = 0;
static void ok(const char *what, int cond) {
    if (cond) return;
    g_fail++;
    fprintf(stderr, "FAIL %s\n", what);
}

typedef struct {
    const uint8_t *rx;
    size_t rx_len;
    int rx_done;
    int write_calls;
    int raw_calls;
    int mark_calls;
    uint8_t raw_buf[64];
    size_t raw_len;
} fake_transport_t;

static void *fake_open(int fd, const transport_tls_cfg_t *cfg) {
    (void)fd;
    (void)cfg;
    return NULL;
}

static int fake_read(void *h, uint8_t *buf, size_t len) {
    fake_transport_t *ft = (fake_transport_t *)h;
    if (ft->rx_done) return TRANSPORT_WANT_READ;
    size_t n = ft->rx_len < len ? ft->rx_len : len;
    memcpy(buf, ft->rx, n);
    ft->rx_done = 1;
    return (int)n;
}

static int fake_write(void *h, const uint8_t *buf, size_t len) {
    (void)buf;
    fake_transport_t *ft = (fake_transport_t *)h;
    /* len 0 is a flush probe (reality wpend); not a real app write */
    if (len == 0) return 0;
    ft->write_calls++;
    return (int)len;
}

static int fake_raw_write(void *h, const uint8_t *buf, size_t len) {
    fake_transport_t *ft = (fake_transport_t *)h;
    if (len == 0) {
        ft->mark_calls++;
        return 0;
    }
    ft->raw_calls++;
    if (len > sizeof ft->raw_buf) len = sizeof ft->raw_buf;
    memcpy(ft->raw_buf, buf, len);
    ft->raw_len = len;
    return (int)len;
}

static void fake_close(void *h) {
    (void)h;
}

static const transport_vt_t fake_vt = {
    fake_open, fake_read, fake_write, fake_raw_write, fake_close, NULL
};

/* an inner tls 1.2 stream ends the vision padding with END, not DIRECT. the
   server keeps reading the rest through the outer tls, so every later byte
   has to be sealed; bare bytes get a protocol_version alert back */
static void check_tls12_end_stays_sealed(const uint8_t uuid[VLESS_UUID_LEN]) {
    fake_transport_t ft;
    memset(&ft, 0, sizeof ft);
    ft.rx_done = 1;

    session_t s;
    ok("tls12 init", session_init(&s, &fake_vt, &ft, VL_PROTO_VLESS,
                                  uuid, "xtls-rprx-vision", NULL, NULL) == SESS_OK);
    s.state = SESS_RELAY;
    s.u.vc.state = VC_ST_OPEN;

    size_t consumed = 0;
    uint8_t hello[] = {0x16, 0x03, 0x01, 0x00, 0x04, 0x01, 0x00, 0x00, 0x00};
    ok("tls12 hello", session_feed_client(&s, hello, sizeof hello, &consumed) == SESS_OK &&
                      consumed == sizeof hello);
    uint8_t app[] = {0x17, 0x03, 0x03, 0x00, 0x03, 'a', 'b', 'c'};
    ok("tls12 app data", session_feed_client(&s, app, sizeof app, &consumed) == SESS_OK &&
                         consumed == sizeof app);
    ok("tls12 padding ended", s.vwrap.end_sent == 1 && s.vwrap.direct_sent == 0);
    ok("tls12 upstream not direct", s.vision_upstream_direct == 0 &&
                                    s.vision_upstream_direct_pending == 0);
    ok("tls12 transport not marked raw", ft.mark_calls == 0);

    ok("tls12 more data", session_feed_client(&s, app, sizeof app, &consumed) == SESS_OK &&
                          consumed == sizeof app);
    ok("tls12 later bytes sealed", ft.write_calls == 3 && ft.raw_calls == 0);
    printf("ok tls 1.2 end stays sealed\n");
}

/* trojan and shadowsocks carry no distinct response header, so the local
   socks client only learns the tunnel is up from the connect reply below */
static void check_socks_connect_ack(vl_proto_t proto, const char *user,
                                    const char *pass, const char *what) {
    fake_transport_t ft;
    memset(&ft, 0, sizeof ft);
    ft.rx_done = 1;

    session_t s;
    ok(what, session_init(&s, &fake_vt, &ft, proto, NULL, NULL, user, pass) == SESS_OK);

    uint8_t greet[] = {0x05, 0x01, 0x00};
    size_t consumed = 0;
    ok(what, session_feed_client(&s, greet, sizeof greet, &consumed) == SESS_OK);
    ok(what, consumed == sizeof greet);

    uint8_t req[] = {0x05, 0x01, 0x00, 0x01, 93, 184, 216, 34, 0x01, 0xbb};
    ok(what, session_feed_client(&s, req, sizeof req, &consumed) == SESS_OK);
    ok(what, s.state == SESS_RELAY);

    uint8_t out[32];
    size_t got = session_take_client(&s, out, sizeof out);
    uint8_t expect[12] = {0x05, 0x00, 0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0};
    ok(what, got == sizeof expect && memcmp(out, expect, sizeof expect) == 0);

    printf("ok %s\n", what);
}

int main(void) {
    uint8_t uuid[VLESS_UUID_LEN];
    for (size_t i = 0; i < sizeof uuid; ++i) uuid[i] = (uint8_t)(i + 1);

    uint8_t direct[16 + 5 + 3];
    memcpy(direct, uuid, 16);
    direct[16] = VISION_CMD_DIRECT;
    direct[17] = 0;
    direct[18] = 0;
    direct[19] = 0;
    direct[20] = 0;
    memcpy(direct + 21, "RAW", 3);

    fake_transport_t ft;
    memset(&ft, 0, sizeof ft);
    ft.rx = direct;
    ft.rx_len = sizeof direct;

    session_t s;
    ok("session init", session_init(&s, &fake_vt, &ft, VL_PROTO_VLESS,
                                    uuid, "xtls-rprx-vision", NULL, NULL) == SESS_OK);
    s.state = SESS_RELAY;
    s.u.vc.state = VC_ST_OPEN;

    ok("pump direct", session_pump_remote(&s) == SESS_OK);
    ok("downstream direct latched", s.vision_downstream_direct == 1);
    ok("upstream direct stays framed", s.vision_upstream_direct == 0);
    ok("transport raw stays framed", ft.mark_calls == 0);

    uint8_t out[8];
    size_t got = session_take_client(&s, out, sizeof out);
    ok("direct payload delivered", got == 3 && memcmp(out, "RAW", 3) == 0);

    size_t consumed = 0;
    ok("feed raw client", session_feed_client(&s, (const uint8_t *)"GET", 3, &consumed) == SESS_OK);
    ok("client consumed", consumed == 3);
    ok("framed write used", ft.write_calls == 1);
    ok("raw write not used", ft.raw_calls == 0);

    check_tls12_end_stays_sealed(uuid);
    check_socks_connect_ack(VL_PROTO_TROJAN, NULL, "secret", "trojan socks connect ack");
    check_socks_connect_ack(VL_PROTO_SHADOWSOCKS, "aes-256-gcm", "secret", "shadowsocks socks connect ack");

    if (g_fail) {
        fprintf(stderr, "%d check(s) failed\n", g_fail);
        return 1;
    }
    printf("all session direct checks passed\n");
    return 0;
}
