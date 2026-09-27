"""render iphone and ipad mockups of the legacyray console + station log"""
import sys
import math
import cairo
from skin import *
from components import *

FLAG_DIR = '../../app/Resources/flags'


def flag(cr, code, x, y, h=12):
    try:
        img = cairo.ImageSurface.create_from_png('%s/flag-%s.png' % (FLAG_DIR, code))
    except Exception:
        return
    s = h / img.get_height()
    cr.save()
    cr.translate(x, y)
    cr.scale(s, s)
    cr.set_source_surface(img, 0, 0)
    cr.paint()
    cr.restore()


def display_content(t, state, compact=False):
    def draw(cr, x, y, w, h):
        g = t['glow']
        glow_text(cr, {'connected': 'CONNECTED', 'idle': 'STANDBY', 'connecting': 'TUNING...'}[state],
                  x + 12, y + 20, 13, g)
        lx = x + w - 12
        for text, on in (('STEALTH', False), ('ROUTING', True), ('AUTO', True)):
            cr.select_font_face('Liberation Sans', 0, 1)
            cr.set_font_size(8.5)
            lx -= cr.text_extents(text).x_advance
            legend_led(cr, lx, y + 18, text, on, t)
            lx -= 8
        flag(cr, 'nl', x + 12, y + 30, 13)
        glow_text(cr, 'Amsterdam  ·  NL-3', x + 34, y + 41, 15, g, bold=True)
        glow_text(cr, 'VLESS  REALITY  XHTTP', x + 12, y + 58, 9.5, lerp(g, (0.5, 0.5, 0.5, 1), 0.25), bold=False)
        dh = 26 if compact else 30
        seven_segment(cr, '01:24:07', x + 12, y + h - dh - 10, dh, lerp(g, (1, 1, 1, 1), 0.1), t['glow_dim'])
        glow_text(cr, '↑ 12.4 MB', x + w - 12, y + h - 26, 11, g, align='right', bold=False)
        glow_text(cr, '↓ 318 MB', x + w - 12, y + h - 11, 11, g, align='right', bold=False)
    return draw


def console(cr, x, y, w, h, t, state='connected', ipad=False):
    brushed_metal(cr, x, y, w, h, t)
    # top title plate
    engraved_text(cr, 'LegacyRay', x + w / 2, y + 30, 20, t, align='center', font='Liberation Serif')
    engraved_text(cr, 'FULL-DEVICE  VLESS  RECEIVER', x + w / 2, y + 44, 7.5, t, align='center', spacing=1.5)
    cr.new_path()
    screw(cr, x + 12, y + 12, 4, t)
    screw(cr, x + w - 12, y + 12, 4, t, 2.0)
    screw(cr, x + 12, y + h - 12, 4, t, 1.1)
    screw(cr, x + w - 12, y + h - 12, 4, t, 0.3)
    pad = 18
    dy = y + 58
    dh = 118 if not ipad else 150
    display(cr, x + pad, dy, w - 2 * pad, dh, t, display_content(t, state, compact=not ipad))
    my = dy + dh + 20
    mw = (w - 2 * pad - 16) / 2
    mh = mw * 0.62
    if ipad:
        tuning_dial(cr, x + pad, my, w - 2 * pad, 44, t,
                    ['AMS', 'FRA', 'HEL', 'NYC', 'TYO', 'LON', 'WAW'], 0)
        my += 64
        mw = min(mw, 250); mh = mw * 0.60
        gap = (w - 2 * mw) / 3
        vu_meter(cr, x + gap, my, mw, mh, t, 0.34, 'VU', 'UPLINK  B/s')
        vu_meter(cr, x + 2 * gap + mw, my, mw, mh, t, 0.63, 'VU', 'DOWNLINK  B/s')
    else:
        vu_meter(cr, x + pad, my, mw, mh, t, 0.34, 'VU', 'UP  B/s')
        vu_meter(cr, x + pad + mw + 16, my, mw, mh, t, 0.63, 'VU', 'DOWN  B/s')
    py = my + mh + (70 if ipad else 64)
    R = 52 if not ipad else 70
    power_button(cr, x + w / 2, py, R, t, state)
    engraved_text(cr, 'POWER', x + w / 2, py + R + 24, 8, t, align='center', spacing=2)
    # seek buttons
    bw = 50
    metal_button(cr, x + w / 2 - R - 30 - bw, py - 14, bw, 28, '◀◀', t)
    metal_button(cr, x + w / 2 + R + 30, py - 14, bw, 28, '▶▶', t)
    engraved_text(cr, 'SEEK', x + w / 2 - R - 30 - bw / 2, py + 28, 7, t, align='center', spacing=1.5)
    engraved_text(cr, 'SEEK', x + w / 2 + R + 30 + bw / 2, py + 28, 7, t, align='center', spacing=1.5)
    if ipad:
        ty = py + R + 50
        items = (('AUTO-RECONNECT', True), ('ROUTING', True), ('LAN BYPASS', True), ('STEALTH', False))
        cw = (w - 2 * pad) / len(items)
        for i, (label, on) in enumerate(items):
            cx = x + pad + cw * i + cw / 2
            toggle_switch(cr, cx - 31, ty, on, t)
            engraved_text(cr, label, cx, ty + 44, 7.5, t, align='center', spacing=1.2)
    else:
        by = y + h - 50
        bw = (w - 2 * pad - 16) / 3
        for i, label in enumerate(('STATIONS', 'IMPORT', 'SETUP')):
            metal_button(cr, x + pad + i * (bw + 8), by, bw, 32, label, t, dark=(t is NIGHT))


def station_log(cr, x, y, w, h, t, header=True):
    leather(cr, x, y, w, h, t)
    stitching(cr, x, y, w, h, 10, t, inset=6)
    cy = y + 16
    if header:
        tt = dict(t)
        tt['engrave'] = t['stitch']
        tt['engrave_hi'] = (0, 0, 0, 0.6)
        tt['engrave_dy'] = -1
        engraved_text(cr, 'STATION LOG', x + w / 2, y + 34, 13, tt, align='center', font='Liberation Serif', spacing=2)
        cy = y + 50
    pad = 14
    brass_plate(cr, x + pad, cy, w - 2 * pad, 26, t, 'Nebula VPN', '82% · 12 days')
    cy += 34
    rows = [('nl', 'Amsterdam', 'VLESS · REALITY', 48, True), ('de', 'Frankfurt', 'VLESS · XHTTP', 61, False),
            ('fi', 'Helsinki', 'VLESS · GRPC', 97, False), ('us', 'New York', 'TROJAN · TLS', 144, False),
            ('jp', 'Tokyo', 'VLESS · WS', -1, False)]
    for code, name, proto, ms, sel in rows:
        paper_card(cr, x + pad, cy, w - 2 * pad, 44, t, sel)
        # led
        led = hexc('#3BEA6A') if sel else (0.35, 0.3, 0.25, 0.35)
        if sel:
            for i in range(5, 0, -1):
                cr.arc(x + pad + 14, cy + 22, 3.5 + i, 0, TAU)
                cr.set_source_rgba(0.23, 0.92, 0.42, 0.07)
                cr.fill()
        cr.arc(x + pad + 14, cy + 22, 3.5, 0, TAU)
        cr.set_source_rgba(*led)
        cr.fill()
        flag(cr, code, x + pad + 26, cy + 9, 12)
        cr.select_font_face('Liberation Sans', 0, 1)
        cr.set_font_size(14)
        cr.set_source_rgba(*t['card_ink'])
        cr.move_to(x + pad + 46, cy + 20)
        cr.show_text(name)
        cr.select_font_face('Liberation Sans', 0, 0)
        cr.set_font_size(9.5)
        cr.set_source_rgba(*t['card_muted'])
        cr.move_to(x + pad + 26, cy + 35)
        cr.show_text(proto)
        lvl = 0 if ms < 0 else (5 if ms < 60 else 4 if ms < 100 else 3 if ms < 160 else 2)
        col = hexc('#2E9E4F') if ms >= 0 and ms < 100 else hexc('#C98A1B') if ms >= 0 else hexc('#B03A2E')
        signal_bars(cr, x + w - pad - 60, cy + 28, lvl, col, (0.5, 0.45, 0.4, 0.3))
        cr.set_font_size(10)
        txt = ('%d ms' % ms) if ms >= 0 else 'no signal'
        ext = cr.text_extents(txt)
        cr.set_source_rgba(*col)
        cr.move_to(x + w - pad - 10 - ext.x_advance, cy + 20)
        cr.show_text(txt)
        cy += 50
    brass_plate(cr, x + pad, cy + 4, w - 2 * pad, 26, t, 'Manual', '2 stations', collapsed=True)


def header_bar(cr, x, y, w, t, title):
    brushed_metal(cr, x, y, w, 44, t, seed=21)
    cr.rectangle(x, y + 43, w, 1)
    cr.set_source_rgba(0, 0, 0, 0.5)
    cr.fill()
    engraved_text(cr, title, x + w / 2, y + 28, 17, t, align='center', font='Liberation Serif')


def status_bar(cr, w):
    cr.rectangle(0, 0, w, 20)
    cr.set_source_rgba(0, 0, 0, 1)
    cr.fill()
    cr.select_font_face('Liberation Sans', 0, 1)
    cr.set_font_size(12)
    cr.set_source_rgba(1, 1, 1, 1)
    cr.move_to(w / 2 - 18, 14)
    cr.show_text('9:41')


def iphone(theme, path, scale=2):
    t = DAY if theme == 'day' else NIGHT
    W, H = 320, 480
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W * scale * 2 + 20 * scale, H * scale)
    cr = cairo.Context(s)
    cr.scale(scale, scale)
    status_bar(cr, W)
    console(cr, 0, 20, W, H - 20, t, 'connected')
    cr.translate(W + 20, 0)
    status_bar(cr, W)
    header_bar(cr, 0, 20, W, t, 'Stations')
    station_log(cr, 0, 64, W, H - 64, t, header=False)
    s.write_to_png(path)


def ipad(theme, path, scale=1):
    t = DAY if theme == 'day' else NIGHT
    W, H = 1024, 768
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W * scale, H * scale)
    cr = cairo.Context(s)
    cr.scale(scale, scale)
    status_bar(cr, W)
    # walnut case frames the console like a hi-fi receiver
    cw = 620
    cx0 = W - cw
    cr.rectangle(cx0, 20, cw, H - 20)
    cr.set_source_rgba(*t['walnut'])
    cr.fill()
    import random
    rnd = random.Random(2)
    for i in range(200):
        yy = 20 + rnd.random() * (H - 20)
        cr.move_to(cx0, yy)
        cr.curve_to(cx0 + cw * 0.3, yy + rnd.uniform(-6, 6), cx0 + cw * 0.6, yy + rnd.uniform(-6, 6), W, yy + rnd.uniform(-4, 4))
        cr.set_source_rgba(0.1, 0.05, 0.02, 0.05 + rnd.random() * 0.08)
        cr.set_line_width(0.5 + rnd.random() * 1.5)
        cr.stroke()
    console(cr, cx0 + 18, 38, cw - 36, H - 56, t, 'connected', ipad=True)
    station_log(cr, 0, 20, cx0, H - 20, t, header=True)
    s.write_to_png(path)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    iphone('day', out + '/iphone-day.png')
    iphone('night', out + '/iphone-night.png')
    ipad('day', out + '/ipad-day.png')
    ipad('night', out + '/ipad-night.png')
    print('rendered')
