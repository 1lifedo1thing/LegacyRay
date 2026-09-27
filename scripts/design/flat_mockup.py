"""the flat (ios 7+) skin of the console and the station log, as a prototype"""
import math
import sys
import cairo
from skin import hexc, rrect, TAU

WHITE = (1, 1, 1, 1)
BG = hexc('#EFEFF4')
INK = hexc('#000000')
MUTED = hexc('#8E8E93')
LINE = hexc('#C8C7CC')
TINT = hexc('#007AFF')
GREEN = hexc('#4CD964')
ORANGE = hexc('#FF9500')
FLAG_DIR = '../../app/Resources/flags'


def text(cr, s, x, y, size, col, weight=0, align='left', font='Liberation Sans'):
    cr.select_font_face(font, 0, weight)
    cr.set_font_size(size)
    w = cr.text_extents(s).x_advance
    if align == 'center':
        x -= w / 2
    elif align == 'right':
        x -= w
    cr.set_source_rgba(*col)
    cr.move_to(x, y)
    cr.show_text(s)
    return w


def flag(cr, code, x, y, d):
    try:
        img = cairo.ImageSurface.create_from_png('%s/flag-%s.png' % (FLAG_DIR, code))
    except Exception:
        return
    cr.save()
    cr.arc(x + d / 2, y + d / 2, d / 2, 0, TAU)
    cr.clip()
    cr.translate(x, y)
    cr.scale(d / img.get_width(), d / img.get_height())
    cr.set_source_surface(img, 0, 0)
    cr.paint()
    cr.restore()


def card(cr, x, y, w, h, r=12):
    rrect(cr, x, y, w, h, r)
    cr.set_source_rgba(*WHITE)
    cr.fill_preserve()
    cr.set_source_rgba(*LINE)
    cr.set_line_width(0.5)
    cr.stroke()


def meter(cr, x, y, w, h, value, caption):
    card(cr, x, y, w, h, 10)
    pcx, pcy, R = x + w / 2, y + h * 1.28, h * 1.06
    a0, a1 = math.radians(-140), math.radians(-40)
    cr.save()
    rrect(cr, x, y, w, h, 10)
    cr.clip()
    cr.set_source_rgba(*MUTED)
    cr.set_line_width(1)
    cr.arc(pcx, pcy, R, a0, a1)
    cr.stroke()
    for i in range(21):
        a = a0 + (a1 - a0) * i / 20
        l = 6 if i % 5 == 0 else 3
        cr.move_to(pcx + math.cos(a) * R, pcy + math.sin(a) * R)
        cr.line_to(pcx + math.cos(a) * (R - l), pcy + math.sin(a) * (R - l))
        cr.set_source_rgba(*(hexc('#FF3B30') if i > 15 else MUTED))
        cr.stroke()
    a = a0 + (a1 - a0) * value
    cr.move_to(pcx, pcy)
    cr.line_to(pcx + math.cos(a) * (R + 2), pcy + math.sin(a) * (R + 2))
    cr.set_source_rgba(*ORANGE)
    cr.set_line_width(1.6)
    cr.stroke()
    cr.restore()
    text(cr, 'VU', x + w / 2, y + h * 0.62, h * 0.17, MUTED, 0, 'center')
    text(cr, caption, x + w / 2, y + h * 0.80, h * 0.085, MUTED, 1, 'center')


def status_bar(cr, W):
    """the ios 7 status bar: no strip of its own, dark text on the app"""
    text(cr, '●●●●○ LegacyNet', 6, 14, 11, INK, 0)
    text(cr, '9:41', W / 2, 14, 12, INK, 1, 'center')
    x, y = W - 30, 6
    cr.rectangle(x, y, 22, 10)
    cr.set_source_rgba(*INK)
    cr.set_line_width(1)
    cr.stroke()
    cr.rectangle(x + 22, y + 3, 2, 4)
    cr.fill()
    cr.rectangle(x + 2, y + 2, 14, 6)
    cr.fill()


def phone(path):
    W, H = 320, 480
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, (W * 2 + 20) * 2, H * 2)
    cr = cairo.Context(s)
    cr.scale(2, 2)
    # console
    cr.rectangle(0, 0, W, H)
    cr.set_source_rgba(*hexc('#F7F7F7'))
    cr.fill()
    status_bar(cr, W)
    text(cr, 'LegacyRay', W / 2, 52, 22, INK, 0, 'center')
    card(cr, 16, 66, W - 32, 112)
    text(cr, 'CONNECTED', 30, 88, 12, TINT, 1)
    lx = W - 30
    for leg, on in (('STEALTH', False), ('ROUTING', True), ('AUTO', True)):
        cr.set_font_size(8.5)
        lx -= cr.text_extents(leg).x_advance
        text(cr, leg, lx, 88, 8.5, TINT if on else (0.56, 0.56, 0.58, 0.35), 1)
        lx -= 8
    flag(cr, 'nl', 30, 97, 16)
    text(cr, 'Amsterdam', 52, 111, 16, INK, 0)
    text(cr, 'VLESS · REALITY · XHTTP  ·  48 ms', 30, 128, 10.5, MUTED)
    text(cr, '01:24:07', 27, 168, 42, INK, 0, font='Lato Light')
    text(cr, '↑ 12.4 MB', W - 30, 150, 11, MUTED, 0, 'right')
    text(cr, '↓ 318 MB', W - 30, 165, 11, MUTED, 0, 'right')
    meter(cr, 16, 190, 138, 82, 0.34, 'UPLINK B/s')
    meter(cr, 166, 190, 138, 82, 0.63, 'DOWNLINK B/s')
    cx, cy, R = W / 2, 344, 56
    cr.new_path()
    cr.arc(cx, cy, R - 1.5, 0, TAU)
    cr.set_source_rgba(*GREEN)
    cr.set_line_width(3)
    cr.stroke()
    cr.arc(cx, cy, R - 7, 0, TAU)
    cr.set_source_rgba(*GREEN)
    cr.fill()
    cr.set_source_rgba(*WHITE)
    cr.set_line_width(3.5)
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    gr = (R - 7) * 0.36
    cr.new_path()
    cr.arc(cx, cy, gr, -math.pi / 2 + 0.75, -math.pi / 2 - 0.75 + TAU)
    cr.stroke()
    cr.move_to(cx, cy - gr * 1.18)
    cr.line_to(cx, cy - gr * 0.25)
    cr.stroke()
    text(cr, 'Power', cx, cy + R + 16, 11, MUTED, 0, 'center')
    for sx, glyph in ((cx - R - 70, '◀◀'), (cx + R + 20, '▶▶')):
        text(cr, 'Seek', sx + 25, cy + 30, 11, MUTED, 0, 'center')
        cr.set_source_rgba(*TINT)
        d = -1 if sx < cx else 1
        for k in (-1, 1):
            ox = sx + 25 + k * 5
            cr.move_to(ox - 5 * d, cy - 6)
            cr.line_to(ox + 5 * d, cy)
            cr.line_to(ox - 5 * d, cy + 6)
            cr.close_path()
            cr.fill()
    for i, lab in enumerate(('Stations', 'Import', 'Setup')):
        text(cr, lab, 56 + i * 104, 450, 16, TINT, 0, 'center')
    # station log
    cr.translate(W + 20, 0)
    cr.rectangle(0, 0, W, H)
    cr.set_source_rgba(*BG)
    cr.fill()
    cr.rectangle(0, 0, W, 64)
    cr.set_source_rgba(0.973, 0.973, 0.973, 1)
    cr.fill()
    status_bar(cr, W)
    cr.rectangle(0, 63.5, W, 0.5)
    cr.set_source_rgba(*LINE)
    cr.fill()
    text(cr, 'Stations', W / 2, 48, 17, INK, 1, 'center')
    text(cr, '‹ Back', 8, 48, 17, TINT)
    text(cr, '•••   +', W - 12, 48, 17, TINT, 0, 'right')
    y = 64
    text(cr, 'NEBULA VPN', 16, y + 22, 13, hexc('#6D6D72'))
    text(cr, '82% · 12 d', W - 36, y + 22, 12, hexc('#6D6D72'), 0, 'right')
    y += 34
    rows = [('nl', 'Amsterdam', 'VLESS · REALITY', '48 ms', True), ('de', 'Frankfurt', 'VLESS · XHTTP', '61 ms', False),
            ('fi', 'Helsinki', 'VLESS · GRPC', '97 ms', False), ('us', 'New York', 'TROJAN · TLS', '144 ms', False),
            ('jp', 'Tokyo', 'VLESS · WS', 'no signal', False)]
    for i, (code, name, proto, ms, sel) in enumerate(rows):
        cr.rectangle(0, y, W, 58)
        cr.set_source_rgba(*WHITE)
        cr.fill()
        cr.arc(20, y + 29, 4, 0, TAU)
        cr.set_source_rgba(*(GREEN if sel else (0.78, 0.78, 0.8, 1)))
        cr.fill()
        flag(cr, code, 36, y + 10, 20)
        text(cr, name, 64, y + 26, 17, INK)
        text(cr, proto, 36, y + 45, 12, MUTED)
        col = hexc('#2BB24C') if ms.endswith('ms') and int(ms.split()[0]) < 150 else (hexc('#FF9500') if ms.endswith('ms') else hexc('#FF3B30'))
        text(cr, ms, W - 16, y + 24, 13, col, 0, 'right')
        cr.rectangle(58 if i < len(rows) - 1 else 0, y + 57.5, W, 0.5)
        cr.set_source_rgba(*LINE)
        cr.fill()
        y += 58
    text(cr, 'MANUAL', 16, y + 22, 13, hexc('#6D6D72'))
    s.write_to_png(path)


if __name__ == '__main__':
    phone(sys.argv[1])
    print('rendered')
