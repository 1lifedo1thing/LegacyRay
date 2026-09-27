"""LegacyRay components in cairo, mirroring the CoreGraphics controls"""
import math
import random
import cairo
from skin import *


def power_button(cr, cx, cy, R, t, state='connected', pressed=False):
    glow = {'idle': hexc('#E0452E'), 'connecting': hexc('#FFB02E'),
            'connected': hexc('#3BEA6A'), 'error': hexc('#FF3B30')}[state]
    lit = state != 'idle'
    cr.save()
    # drop shadow on the faceplate
    for i in range(8):
        cr.arc(cx, cy + 3, R + 8 - i, 0, TAU)
        cr.set_source_rgba(0, 0, 0, 0.035)
        cr.fill()
    # recessed seat
    cr.arc(cx, cy, R + 7, 0, TAU)
    cr.set_source(vgrad(cy - R, cy + R, [(0, (0, 0, 0, 0.45)), (1, (1, 1, 1, 0.45))]))
    cr.fill()
    cr.arc(cx, cy, R + 5.5, 0, TAU)
    cr.set_source_rgba(0.08, 0.08, 0.09, 1)
    cr.fill()
    # led ring
    ring_w = R * 0.10
    for i in range(10, 0, -1):
        a = (0.05 if lit else 0.02) * (11 - i) / 10
        cr.arc(cx, cy, R + 4.5, 0, TAU)
        cr.set_line_width(ring_w + i * 1.6)
        cr.set_source_rgba(glow[0], glow[1], glow[2], a)
        cr.stroke()
    cr.arc(cx, cy, R + 4.5 - ring_w * 0.1, 0, TAU)
    cr.set_line_width(ring_w)
    base = glow if lit else lerp(glow, (0.1, 0.1, 0.1, 1), 0.7)
    cr.set_source_rgba(*base)
    cr.stroke()
    # chrome skirt with radial facets (knurled edge)
    cr.arc(cx, cy, R, 0, TAU)
    g = cairo.LinearGradient(cx, cy - R, cx, cy + R)
    g.add_color_stop_rgba(0, 0.93, 0.94, 0.95, 1)
    g.add_color_stop_rgba(0.5, 0.62, 0.64, 0.67, 1)
    g.add_color_stop_rgba(1, 0.86, 0.87, 0.89, 1)
    cr.set_source(g)
    cr.fill()
    cr.save()
    cr.arc(cx, cy, R, 0, TAU)
    cr.clip()
    for k in range(120):
        ang = TAU * k / 120
        cr.move_to(cx + math.cos(ang) * R * 0.80, cy + math.sin(ang) * R * 0.80)
        cr.line_to(cx + math.cos(ang) * R, cy + math.sin(ang) * R)
        cr.set_source_rgba(0, 0, 0, 0.10 if k % 2 else 0.0)
        cr.set_line_width(1.2)
        cr.stroke()
    cr.restore()
    cr.arc(cx, cy, R, 0, TAU)
    cr.set_source_rgba(0, 0, 0, 0.5)
    cr.set_line_width(1)
    cr.stroke()
    # cap: concentric machined face
    rc = R * 0.78
    off = 1.5 if pressed else 0
    cr.arc(cx, cy + off, rc, 0, TAU)
    g = cairo.LinearGradient(cx, cy - rc, cx, cy + rc)
    if pressed:
        g.add_color_stop_rgba(0, 0.70, 0.71, 0.73, 1)
        g.add_color_stop_rgba(1, 0.86, 0.87, 0.89, 1)
    else:
        g.add_color_stop_rgba(0, 0.97, 0.97, 0.98, 1)
        g.add_color_stop_rgba(1, 0.74, 0.75, 0.78, 1)
    cr.set_source(g)
    cr.fill()
    cr.save()
    cr.arc(cx, cy + off, rc, 0, TAU)
    cr.clip()
    rnd = random.Random(5)
    rr = 2
    while rr < rc:
        cr.arc(cx, cy + off, rr, 0, TAU)
        cr.set_source_rgba(1, 1, 1, 0.10) if rnd.random() < 0.5 else cr.set_source_rgba(0, 0, 0, 0.05)
        cr.set_line_width(0.8)
        cr.stroke()
        rr += 1.3 + rnd.random()
    # light sweep (anisotropic highlight of machined metal)
    for ang0 in (-0.9, math.pi - 0.9):
        cr.move_to(cx, cy + off)
        cr.arc(cx, cy + off, rc, ang0, ang0 + 0.45)
        cr.close_path()
        cr.set_source_rgba(1, 1, 1, 0.28)
        cr.fill()
    cr.restore()
    cr.arc(cx, cy + off, rc, 0, TAU)
    cr.set_source_rgba(0, 0, 0, 0.35)
    cr.set_line_width(1)
    cr.stroke()
    # power glyph, engraved and lit by the ring colour when on
    gr = rc * 0.42
    col = lerp(glow, (1, 1, 1, 1), 0.15) if lit else (0.30, 0.31, 0.33, 1)
    for pass_, (dy, c, lw) in enumerate(((1, (1, 1, 1, 0.8), 0), (0, col, 0))):
        cr.set_line_cap(cairo.LINE_CAP_ROUND)
        cr.set_line_width(rc * 0.11)
        cr.set_source_rgba(*c)
        cr.arc(cx, cy + off + dy, gr, -math.pi / 2 + 0.75, -math.pi / 2 - 0.75 + TAU)
        cr.stroke()
        cr.move_to(cx, cy + off + dy - gr * 1.18)
        cr.line_to(cx, cy + off + dy - gr * 0.25)
        cr.stroke()
    cr.restore()


def vu_meter(cr, x, y, w, h, t, value, label, sub):
    """value 0..1 on a log speed scale"""
    cr.save()
    # bezel
    rrect(cr, x - 4, y - 4, w + 8, h + 8, 7)
    cr.set_source(vgrad(y - 4, y + h + 4, [(0, (0.16, 0.16, 0.17, 1)), (1, (0.30, 0.30, 0.32, 1))]))
    cr.fill()
    inset_well(cr, x, y, w, h, 4, t['meter_face_top'], t['meter_face_bot'], 0.9)
    # backlight hotspot
    cr.save()
    rrect(cr, x, y, w, h, 4)
    cr.clip()
    g = cairo.RadialGradient(x + w / 2, y + h * 1.05, 5, x + w / 2, y + h * 1.05, h * 1.2)
    g.add_color_stop_rgba(0, 1, 0.9, 0.55, 0.35)
    g.add_color_stop_rgba(1, 1, 0.9, 0.55, 0.0)
    cr.set_source(g)
    cr.paint()
    cr.restore()
    # scale arc
    pcx, pcy = x + w / 2, y + h * 1.30
    R = h * 1.05
    a0, a1 = math.radians(-140), math.radians(-40)
    ink = t['meter_ink']
    cr.set_source_rgba(*ink)
    cr.set_line_width(1.2)
    cr.arc(pcx, pcy, R, a0, a1)
    cr.stroke()
    # red zone
    cr.set_source_rgba(*t['meter_red'])
    cr.set_line_width(3.5)
    cr.arc(pcx, pcy, R + 2, a0 + (a1 - a0) * 0.78, a1)
    cr.stroke()
    labels = ['1K', '10K', '100K', '1M', '10M']
    for i in range(21):
        f = i / 20
        ang = a0 + (a1 - a0) * f
        major = i % 5 == 0
        l = 7 if major else 4
        cr.move_to(pcx + math.cos(ang) * R, pcy + math.sin(ang) * R)
        cr.line_to(pcx + math.cos(ang) * (R - l), pcy + math.sin(ang) * (R - l))
        cr.set_source_rgba(*(t['meter_red'] if f > 0.78 else ink))
        cr.set_line_width(1.4 if major else 0.9)
        cr.stroke()
        if major:
            cr.select_font_face('Liberation Sans', 0, 1)
            cr.set_font_size(h * 0.10)
            s = labels[i // 5]
            ext = cr.text_extents(s)
            tx = pcx + math.cos(ang) * (R - 16) - ext.x_advance / 2
            ty = pcy + math.sin(ang) * (R - 16) + ext.height / 2
            cr.move_to(tx, ty)
            cr.show_text(s)
    cr.select_font_face('Liberation Serif', 0, 1)
    cr.set_font_size(h * 0.16)
    cr.move_to(x + 9, y + h * 0.80)
    cr.set_source_rgba(*ink)
    cr.show_text(label)
    cr.select_font_face('Liberation Sans', 0, 1)
    cr.set_font_size(h * 0.085)
    ext = cr.text_extents(sub)
    cr.move_to(x + w - 9 - ext.x_advance, y + h * 0.80)
    cr.show_text(sub)
    # needle
    ang = a0 + (a1 - a0) * value
    cr.save()
    rrect(cr, x, y, w, h, 4)
    cr.clip()
    cr.move_to(pcx + 1.5, pcy + 2)
    cr.line_to(pcx + math.cos(ang) * (R + 3) + 1.5, pcy + math.sin(ang) * (R + 3) + 2)
    cr.set_source_rgba(0, 0, 0, 0.18)
    cr.set_line_width(1.6)
    cr.stroke()
    cr.move_to(pcx, pcy)
    cr.line_to(pcx + math.cos(ang) * (R + 3), pcy + math.sin(ang) * (R + 3))
    cr.set_source_rgba(0.08, 0.06, 0.05, 1) if t is DAY else cr.set_source_rgba(1, 0.35, 0.2, 1)
    cr.set_line_width(1.5)
    cr.stroke()
    cr.restore()
    # pivot cover bar
    cr.save()
    rrect(cr, x, y + h - h * 0.10, w, h * 0.10, 0)
    cr.clip()
    cr.set_source(vgrad(y + h * 0.90, y + h, [(0, (0.12, 0.12, 0.13, 1)), (1, (0.22, 0.22, 0.24, 1))]))
    rrect(cr, x, y, w, h, 4)
    cr.fill()
    cr.restore()
    glass_gloss(cr, x, y, w, h, 4)
    cr.restore()


def display(cr, x, y, w, h, t, lines):
    cr.save()
    rrect(cr, x - 5, y - 5, w + 10, h + 10, 10)
    cr.set_source(vgrad(y - 5, y + h + 5, [(0, (0.10, 0.10, 0.11, 1)), (1, (0.26, 0.27, 0.29, 1))]))
    cr.fill()
    inset_well(cr, x, y, w, h, 6, t['glass_top'], t['glass_bot'], 1.0)
    # scanlines
    cr.save()
    rrect(cr, x, y, w, h, 6)
    cr.clip()
    yy = y
    while yy < y + h:
        cr.rectangle(x, yy, w, 1)
        cr.set_source_rgba(0, 0, 0, 0.18)
        cr.fill()
        yy += 3
    g = cairo.RadialGradient(x + w / 2, y + h / 2, 5, x + w / 2, y + h / 2, w * 0.7)
    gl = t['glow']
    g.add_color_stop_rgba(0, gl[0], gl[1], gl[2], 0.10)
    g.add_color_stop_rgba(1, gl[0], gl[1], gl[2], 0.0)
    cr.set_source(g)
    cr.paint()
    cr.restore()
    lines(cr, x, y, w, h)
    glass_gloss(cr, x, y, w, h, 6)
    cr.restore()


def legend_led(cr, x, y, text, on, t, color=None):
    color = color or t['glow']
    cr.save()
    cr.select_font_face('Liberation Sans', 0, 1)
    cr.set_font_size(8.5)
    if on:
        for rad, a in ((1.5, 0.15), (0.8, 0.25)):
            for ang in range(0, 360, 60):
                cr.set_source_rgba(color[0], color[1], color[2], a)
                cr.move_to(x + math.cos(math.radians(ang)) * rad, y + math.sin(math.radians(ang)) * rad)
                cr.show_text(text)
        cr.set_source_rgba(*color)
    else:
        cr.set_source_rgba(color[0], color[1], color[2], 0.16)
    cr.move_to(x, y)
    cr.show_text(text)
    w = cr.text_extents(text).x_advance
    cr.restore()
    return w


def metal_button(cr, x, y, w, h, text, t, dark=False, glyph=None, r=6):
    cr.save()
    rrect(cr, x, y + 1, w, h, r)
    cr.set_source_rgba(1, 1, 1, 0.5) if not dark else cr.set_source_rgba(1, 1, 1, 0.12)
    cr.fill()
    rrect(cr, x, y, w, h, r)
    cr.set_source_rgba(0, 0, 0, 0.55)
    cr.fill()
    rrect(cr, x + 1, y + 1, w - 2, h - 2, r - 1)
    if dark:
        cr.set_source(vgrad(y, y + h, [(0, (0.33, 0.34, 0.36, 1)), (0.5, (0.18, 0.19, 0.20, 1)),
                                       (0.51, (0.13, 0.13, 0.14, 1)), (1, (0.20, 0.20, 0.22, 1))]))
    else:
        cr.set_source(vgrad(y, y + h, [(0, (0.98, 0.98, 0.99, 1)), (0.5, (0.86, 0.87, 0.89, 1)),
                                       (0.51, (0.80, 0.81, 0.83, 1)), (1, (0.89, 0.90, 0.92, 1))]))
    cr.fill()
    rrect(cr, x + 1.5, y + 1.5, w - 3, h - 3, r - 1.5)
    cr.set_source_rgba(1, 1, 1, 0.55 if not dark else 0.10)
    cr.set_line_width(1)
    cr.stroke()
    tt = dict(t)
    if dark:
        tt['engrave'] = hexc('#DADDE1'); tt['engrave_hi'] = (0, 0, 0, 0.9); tt['engrave_dy'] = -1
    else:
        tt['engrave'] = hexc('#3A3D41'); tt['engrave_hi'] = (1, 1, 1, 0.9); tt['engrave_dy'] = 1
    if glyph in ('prev', 'next'):
        cx, cy = x + w / 2, y + h / 2
        d = -1 if glyph == 'prev' else 1
        for dy, col in ((tt['engrave_dy'], tt['engrave_hi']), (0, tt['engrave'])):
            cr.set_source_rgba(*col)
            for k in (-1, 1):
                ox = cx + k * 5
                cr.move_to(ox - 5 * d, cy - 6 + dy)
                cr.line_to(ox + 5 * d, cy + dy)
                cr.line_to(ox - 5 * d, cy + 6 + dy)
                cr.close_path()
                cr.fill()
    else:
        engraved_text(cr, text, x + w / 2, y + h / 2 + 4, 11, tt, align='center', spacing=1.2)
    cr.restore()


def tuning_dial(cr, x, y, w, h, t, stations, sel):
    """the receiver dial: a lit glass scale with a station mark per server
    and a red pointer on the selected one"""
    cr.save()
    rrect(cr, x - 4, y - 4, w + 8, h + 8, 7)
    cr.set_source(vgrad(y - 4, y + h + 4, [(0, (0.14, 0.14, 0.15, 1)), (1, (0.30, 0.30, 0.32, 1))]))
    cr.fill()
    inset_well(cr, x, y, w, h, 4, (0.05, 0.07, 0.08, 1), (0.02, 0.03, 0.04, 1))
    g = t['glow']
    cr.save()
    rrect(cr, x, y, w, h, 4)
    cr.clip()
    gr = cairo.LinearGradient(x, 0, x + w, 0)
    gr.add_color_stop_rgba(0, g[0], g[1], g[2], 0.0)
    gr.add_color_stop_rgba(0.5, g[0], g[1], g[2], 0.12)
    gr.add_color_stop_rgba(1, g[0], g[1], g[2], 0.0)
    cr.set_source(gr)
    cr.paint()
    # fine scale
    n = 60
    for i in range(n + 1):
        xx = x + 14 + (w - 28) * i / n
        tall = i % 5 == 0
        cr.move_to(xx, y + h - 6)
        cr.line_to(xx, y + h - (16 if tall else 11))
        cr.set_source_rgba(g[0], g[1], g[2], 0.55 if tall else 0.3)
        cr.set_line_width(1)
        cr.stroke()
    # station labels
    cr.select_font_face('Liberation Sans', 0, 1)
    cr.set_font_size(9)
    for i, name in enumerate(stations):
        xx = x + 14 + (w - 28) * (i + 0.5) / len(stations)
        ext = cr.text_extents(name)
        col = (g[0], g[1], g[2], 1 if i == sel else 0.55)
        cr.set_source_rgba(*col)
        cr.move_to(xx - ext.x_advance / 2, y + 16)
        cr.show_text(name)
    # pointer
    px = x + 14 + (w - 28) * (sel + 0.5) / len(stations)
    for i in range(4, 0, -1):
        cr.rectangle(px - 1 - i, y + 3, 2 + 2 * i, h - 6)
        cr.set_source_rgba(1, 0.2, 0.1, 0.05)
        cr.fill()
    cr.rectangle(px - 1, y + 3, 2, h - 6)
    cr.set_source_rgba(1, 0.25, 0.15, 1)
    cr.fill()
    cr.restore()
    glass_gloss(cr, x, y, w, h, 4)
    cr.restore()


def toggle_switch(cr, x, y, on, t, label=None, w=62, h=26):
    """illuminated slide switch: recessed slot, chunky knob, led window"""
    cr.save()
    inset_well(cr, x, y, w, h, h / 2, (0.12, 0.12, 0.13, 1), (0.22, 0.22, 0.24, 1))
    led = hexc('#3BEA6A') if on else hexc('#3BEA6A', 0.0)
    # led strip on the uncovered side
    lx = x + 8 if on else x + w - 22
    rrect(cr, lx, y + h / 2 - 3, 14, 6, 3)
    if on:
        for i in range(4, 0, -1):
            rrect(cr, lx - i, y + h / 2 - 3 - i, 14 + 2 * i, 6 + 2 * i, 3 + i)
            cr.set_source_rgba(0.23, 0.92, 0.42, 0.06)
            cr.fill()
        rrect(cr, lx, y + h / 2 - 3, 14, 6, 3)
        cr.set_source_rgba(0.55, 1.0, 0.65, 1)
    else:
        cr.set_source_rgba(0.35, 0.10, 0.08, 1)
    cr.fill()
    kx = x + w - h + 1 if on else x + 1
    # knob
    cr.arc(kx + h / 2 - 1, y + h / 2 + 1.5, h / 2 - 1, 0, TAU)
    cr.set_source_rgba(0, 0, 0, 0.35)
    cr.fill()
    cr.arc(kx + h / 2 - 1, y + h / 2, h / 2 - 1, 0, TAU)
    cr.set_source(vgrad(y, y + h, [(0, (0.98, 0.98, 0.99, 1)), (1, (0.70, 0.71, 0.74, 1))]))
    cr.fill_preserve()
    cr.set_source_rgba(0, 0, 0, 0.45)
    cr.set_line_width(0.8)
    cr.stroke()
    # grip ridges
    for i in (-3, 0, 3):
        cr.move_to(kx + h / 2 - 1 + i, y + h / 2 - 5)
        cr.line_to(kx + h / 2 - 1 + i, y + h / 2 + 5)
        cr.set_source_rgba(0, 0, 0, 0.25)
        cr.set_line_width(1)
        cr.stroke()
    cr.restore()


def signal_bars(cr, x, y, level, color, dim):
    for i in range(5):
        bh = 3 + i * 2.2
        cr.rectangle(x + i * 4, y - bh, 2.6, bh)
        cr.set_source_rgba(*(color if i < level else dim))
        cr.fill()


def paper_card(cr, x, y, w, h, t, selected=False):
    cr.save()
    rrect(cr, x, y + 2, w, h, 5)
    cr.set_source_rgba(0, 0, 0, 0.35)
    cr.fill()
    rrect(cr, x, y, w, h, 5)
    cr.set_source(vgrad(y, y + h, [(0, t['card_top']), (1, t['card_bot'])]))
    cr.fill()
    noise(cr, x, y, w, h, 0.05, seed=int(y), step=2)
    rrect(cr, x + 0.5, y + 0.5, w - 1, h - 1, 5)
    cr.set_source_rgba(1, 1, 1, 0.5 if t is DAY else 0.08)
    cr.set_line_width(1)
    cr.stroke()
    cr.restore()


def brass_plate(cr, x, y, w, h, t, text, meta=None, collapsed=False):
    cr.save()
    rrect(cr, x, y + 1.5, w, h, 4)
    cr.set_source_rgba(0, 0, 0, 0.45)
    cr.fill()
    rrect(cr, x, y, w, h, 4)
    cr.set_source(vgrad(y, y + h, [(0, t['brass_top']), (0.5, lerp(t['brass_top'], t['brass_bot'], 0.55)),
                                   (1, t['brass_bot'])]))
    cr.fill()
    brushed = dict(t)
    brushed['plate_top'] = (0, 0, 0, 0)
    brushed['plate_bot'] = (0, 0, 0, 0)
    brushed['hair_light'] = (1, 1, 1, 0.12)
    brushed['hair_dark'] = (0.3, 0.2, 0, 0.10)
    cr.save()
    rrect(cr, x, y, w, h, 4)
    cr.clip()
    brushed_metal(cr, x, y, w, h, brushed, seed=int(x + y))
    cr.restore()
    rrect(cr, x + 0.5, y + 0.5, w - 1, h - 1, 4)
    cr.set_source_rgba(1, 0.95, 0.8, 0.5)
    cr.set_line_width(1)
    cr.stroke()
    screw(cr, x + 9, y + h / 2, 3.2, t)
    screw(cr, x + w - 9, y + h / 2, 3.2, t, angle=2.1)
    tt = dict(t)
    tt['engrave'] = hexc('#3B2A12'); tt['engrave_hi'] = (1, 0.95, 0.8, 0.6); tt['engrave_dy'] = 1
    engraved_text(cr, text.upper(), x + 20, y + h / 2 + 4, 11, tt, spacing=1.0)
    if meta:
        engraved_text(cr, meta, x + w - 38, y + h / 2 + 3.5, 9, tt, bold=False, align='right')
    # chevron
    cx, cy = x + w - 24, y + h / 2
    cr.set_source_rgba(0.23, 0.16, 0.07, 0.9)
    cr.set_line_width(1.8)
    if collapsed:
        cr.move_to(cx - 3, cy - 4); cr.line_to(cx + 1, cy); cr.line_to(cx - 3, cy + 4)
    else:
        cr.move_to(cx - 4, cy - 2); cr.line_to(cx, cy + 2); cr.line_to(cx + 4, cy - 2)
    cr.stroke()
    cr.restore()
