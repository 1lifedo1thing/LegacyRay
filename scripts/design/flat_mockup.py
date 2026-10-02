"""the flat (ios 7+) finish of the main screen and the servers, as the app
draws it (the flat branches of LRConsoleScreen, LRPowerButton, LRServerCard
and LRStationCells):  python3 scripts/design/flat_mockup.py docs/preview-flat-iphone.png"""
import math
import os
import sys
import cairo

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from classic import hexc, rrect, text, glyph, TAU, RES  # noqa: E402

WHITE = (1, 1, 1, 1)
BG = hexc('#EFEFF4')
PAGE = hexc('#F7F7F7')
INK = hexc('#000000')
MUTED = hexc('#8E8E93')
LINE = hexc('#C8C7CC')
TINT = hexc('#007AFF')
GREEN = hexc('#4CD964')
GOOD = hexc('#2BB24C')
RED = hexc('#FF3B30')
FONT = 'Nimbus Sans'


def flag(cr, code, x, y, d):
    try:
        img = cairo.ImageSurface.create_from_png(os.path.join(RES, 'flags', 'flag-%s.png' % code))
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
    cr.new_path()


def status_bar(cr, w):
    text(cr, '●●●●○ LegacyNet', 6, 14.5, 12, INK)
    text(cr, '9:41', w / 2, 14.5, 12, INK, bold=True, align='center')
    cr.set_source_rgba(*INK)
    cr.rectangle(w - 30, 6, 22, 9)
    cr.set_line_width(1)
    cr.stroke()
    cr.rectangle(w - 28, 8, 16, 5)
    cr.fill()


def bar(cr, w, title, left=None, right=None):
    cr.rectangle(0, 0, w, 64)
    cr.set_source_rgba(0.97, 0.97, 0.97, 1)
    cr.fill()
    cr.rectangle(0, 63.5, w, 0.5)
    cr.set_source_rgba(*LINE)
    cr.fill()
    status_bar(cr, w)
    text(cr, title, w / 2, 48, 17, INK, bold=True, align='center')
    if left:
        text(cr, left, 10, 48, 17, TINT)
    if right:
        text(cr, right, w - 12, 48, 20, TINT, align='right')


def power(cr, cx, cy, R, color):
    cr.new_path()
    cr.arc(cx, cy, R - 1.5, 0, TAU)
    cr.set_source_rgba(*color)
    cr.set_line_width(3)
    cr.stroke()
    rc = R - 7
    cr.arc(cx, cy, rc, 0, TAU)
    cr.fill()
    cr.set_source_rgba(*WHITE)
    cr.set_line_width(max(2.0, rc * 0.07))
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    gr = rc * 0.36
    cr.new_path()
    cr.arc(cx, cy, gr, -math.pi / 2 + 0.72, -math.pi / 2 - 0.72 + TAU)
    cr.stroke()
    cr.move_to(cx, cy - gr * 1.22)
    cr.line_to(cx, cy - gr * 0.28)
    cr.stroke()


def phone(path):
    W, H = 320, 480
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, (W * 2 + 20) * 2, H * 2)
    cr = cairo.Context(s)
    cr.scale(2, 2)
    cr.set_source_rgb(1, 1, 1)
    cr.paint()
    # the main screen: LRConsoleLayoutFor with a 416 point content box
    cr.rectangle(0, 0, W, H)
    cr.set_source_rgba(*PAGE)
    cr.fill()
    bar(cr, W, 'LegacyRay', right='⚙')
    text(cr, '+', 12, 49, 24, TINT)
    top, R = 64, 70
    side = R * 2 + 24
    cy = top + 30 + side / 2
    power(cr, W / 2, cy, R, GREEN)
    sy = cy + side / 2 + 14
    text(cr, 'Подключено', W / 2, sy + 22, 24, INK, align='center', font='Lato Light')
    text(cr, '01:24:07    ↓ 318 МБ    ↑ 12,4 МБ', W / 2, sy + 46, 15, MUTED, align='center')
    cy2 = H - 64 - 12
    rrect(cr, 10, cy2, W - 20, 64, 12)
    cr.set_source_rgba(*WHITE)
    cr.fill_preserve()
    cr.set_source_rgba(*LINE)
    cr.set_line_width(0.5)
    cr.stroke()
    flag(cr, 'nl', 26, cy2 + 17.5, 29)
    text(cr, 'Amsterdam', 66, cy2 + 29, 17, INK)
    text(cr, 'VLESS · Reality · XHTTP', 66, cy2 + 47, 13, MUTED)
    text(cr, '48 ms', W - 42, cy2 + 37, 15, GOOD, align='right')
    text(cr, '›', W - 22, cy2 + 40, 24, hexc('#C7C7CC'), align='right')
    # the servers
    cr.translate(W + 20, 0)
    cr.rectangle(0, 0, W, H)
    cr.set_source_rgba(*BG)
    cr.fill()
    y = 64
    # the subscription's plate: title, then its traffic and the provider's line
    cr.rectangle(0, y, W, 63)
    cr.set_source_rgba(*BG)
    cr.fill()
    text(cr, 'NEBULA VPN', 16, y + 21, 13, hexc('#6D6D72'))
    text(cr, '5 серверов', W - 36, y + 21, 12, hexc('#8E8E93'), align='right')
    text(cr, '18,4 ГБ из 100 ГБ · осталось 12 дн.', 16, y + 37, 12, hexc('#8E8E93'))
    text(cr, 'Продление и поддержка — в боте @nebula_vpn_bot', 16, y + 52, 12, hexc('#8E8E93'))
    y += 63
    rows = [('nl', 'Amsterdam', 'VLESS · Reality', '48 ms', GOOD, True),
            ('de', 'Frankfurt', 'VLESS · XHTTP', '61 ms', GOOD, False),
            ('fi', 'Helsinki', 'VLESS · gRPC', '97 ms', GOOD, False),
            ('us', 'New York', 'Trojan · TLS', '144 ms', GOOD, False),
            ('jp', 'Tokyo', 'VLESS · WS', 'нет сигнала', RED, False)]
    for i, (code, name, proto, ms, col, sel) in enumerate(rows):
        cr.rectangle(0, y, W, 56)
        cr.set_source_rgba(*WHITE)
        cr.fill()
        mid = y + 28
        if sel:
            cr.set_source_rgba(*TINT)
            cr.set_line_width(2)
            cr.set_line_cap(cairo.LINE_CAP_ROUND)
            cr.move_to(14, mid)
            cr.line_to(18.5, mid + 5)
            cr.line_to(27, mid - 7)
            cr.stroke()
        flag(cr, code, 36, mid - 12, 24)
        text(cr, name, 70, mid - 3, 17, INK)
        text(cr, proto, 70, mid + 15, 13, MUTED)
        text(cr, ms, W - 40, mid + 5, 14, col, align='right')
        cr.new_path()
        cr.arc(W - 22, mid, 10, 0, TAU)
        cr.set_source_rgba(*TINT)
        cr.set_line_width(1)
        cr.stroke()
        text(cr, 'i', W - 22, mid + 5, 14, TINT, align='center')
        last = i == len(rows) - 1
        cr.rectangle(0 if last else 44, y + 55.5, W, 0.5)
        cr.set_source_rgba(*LINE)
        cr.fill()
        y += 56
    text(cr, 'ВРУЧНУЮ', 16, y + 22, 13, hexc('#6D6D72'))
    bar(cr, W, 'Серверы', left='‹ Назад', right='•••   +')
    s.write_to_png(path)


if __name__ == '__main__':
    phone(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(RES), '..', 'docs',
                                                              'preview-flat-iphone.png'))
    print('rendered')
