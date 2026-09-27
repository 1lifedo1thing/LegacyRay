"""LegacyRay skin prototype in cairo.

the app draws everything with CoreGraphics at runtime; this module mirrors
those primitives so the look can be previewed on a desktop and so the static
assets (icons, launch images) come from the same drawing code."""
import math
import random
import cairo

TAU = math.pi * 2


def hexc(h, a=1.0):
    h = h.lstrip('#')
    return (int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0, a)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))


DAY = dict(
    plate_top=hexc('#E6E8EA'), plate_bot=hexc('#C3C6CA'),
    hair_light=(1, 1, 1, 0.10), hair_dark=(0, 0, 0, 0.05),
    engrave=hexc('#34373B'), engrave_hi=(1, 1, 1, 0.75), engrave_dy=1,
    glass_top=hexc('#0E171C'), glass_bot=hexc('#04080A'),
    glow=hexc('#8FE3FF'), glow_dim=hexc('#8FE3FF', 0.18),
    meter_face_top=hexc('#F7EDCF'), meter_face_bot=hexc('#E3CF97'),
    meter_ink=hexc('#2A2218'), meter_red=hexc('#C8321E'),
    leather=hexc('#6A4125'), leather_dark=hexc('#4A2B17'), stitch=hexc('#E9D8AE', 0.85),
    card_top=hexc('#FBF6E8'), card_bot=hexc('#EFE6CD'), card_ink=hexc('#3A2A1B'),
    card_muted=hexc('#8A7458'), brass_top=hexc('#E0C27A'), brass_bot=hexc('#A47F3A'),
    walnut=hexc('#5B3A22'), walnut_dark=hexc('#3A2414'),
    linen=hexc('#D9DCE0'), linen_dark=hexc('#C9CDD2'),
)

NIGHT = dict(DAY)
NIGHT.update(
    plate_top=hexc('#45484C'), plate_bot=hexc('#26282B'),
    hair_light=(1, 1, 1, 0.06), hair_dark=(0, 0, 0, 0.10),
    engrave=hexc('#C8CCD1'), engrave_hi=(0, 0, 0, 0.85), engrave_dy=-1,
    glow=hexc('#FFB04A'), glow_dim=hexc('#FFB04A', 0.16),
    meter_face_top=hexc('#3A2A12'), meter_face_bot=hexc('#1E1609'),
    meter_ink=hexc('#FFC46B'), meter_red=hexc('#FF5A3C'),
    leather=hexc('#242120'), leather_dark=hexc('#151312'), stitch=hexc('#77706A', 0.9),
    card_top=hexc('#35322F'), card_bot=hexc('#2A2826'), card_ink=hexc('#ECE6DC'),
    card_muted=hexc('#A29A8E'), brass_top=hexc('#9C8150'), brass_bot=hexc('#5E4A28'),
)


def rrect(cr, x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


def vgrad(y0, y1, stops):
    g = cairo.LinearGradient(0, y0, 0, y1)
    for off, c in stops:
        g.add_color_stop_rgba(off, *c)
    return g


def brushed_metal(cr, x, y, w, h, t, seed=7):
    cr.save()
    cr.rectangle(x, y, w, h)
    cr.clip()
    cr.set_source(vgrad(y, y + h, [(0, t['plate_top']), (1, t['plate_bot'])]))
    cr.paint()
    rnd = random.Random(seed)
    yy = y
    cr.set_line_width(1)
    while yy < y + h:
        c = t['hair_light'] if rnd.random() < 0.5 else t['hair_dark']
        a = c[3] * (0.4 + rnd.random() * 0.9)
        cr.set_source_rgba(c[0], c[1], c[2], a)
        x0 = x + rnd.random() * w * 0.3 - w * 0.1
        cr.move_to(x0, yy + 0.5)
        cr.line_to(x0 + w * (0.6 + rnd.random() * 0.6), yy + 0.5)
        cr.stroke()
        yy += 1 + rnd.random() * 1.5
    # soft specular sweep
    g = cairo.LinearGradient(x, y, x + w, y + h)
    g.add_color_stop_rgba(0, 1, 1, 1, 0.0)
    g.add_color_stop_rgba(0.45, 1, 1, 1, 0.10)
    g.add_color_stop_rgba(0.55, 1, 1, 1, 0.0)
    cr.set_source(g)
    cr.paint()
    cr.restore()


def noise(cr, x, y, w, h, amount, seed=3, step=2):
    rnd = random.Random(seed)
    cr.save()
    cr.rectangle(x, y, w, h)
    cr.clip()
    for yy in range(int(y), int(y + h), step):
        for xx in range(int(x), int(x + w), step):
            v = rnd.random()
            if v < 0.5:
                cr.set_source_rgba(0, 0, 0, amount * (0.5 - v))
            else:
                cr.set_source_rgba(1, 1, 1, amount * (v - 0.5) * 0.6)
            cr.rectangle(xx, yy, step, step)
            cr.fill()
    cr.restore()


def leather(cr, x, y, w, h, t, seed=11):
    cr.save()
    cr.rectangle(x, y, w, h)
    cr.clip()
    g = cairo.RadialGradient(x + w / 2, y + h * 0.35, 10, x + w / 2, y + h / 2, max(w, h) * 0.8)
    g.add_color_stop_rgba(0, *t['leather'])
    g.add_color_stop_rgba(1, *t['leather_dark'])
    cr.set_source(g)
    cr.paint()
    rnd = random.Random(seed)
    # pebbled grain: many small irregular dark/light blobs
    for _ in range(int(w * h / 18)):
        px = x + rnd.random() * w
        py = y + rnd.random() * h
        r = 0.6 + rnd.random() * 1.6
        if rnd.random() < 0.55:
            cr.set_source_rgba(0, 0, 0, 0.10 + rnd.random() * 0.10)
        else:
            cr.set_source_rgba(1, 1, 1, 0.04 + rnd.random() * 0.05)
        cr.arc(px, py, r, 0, TAU)
        cr.fill()
    cr.restore()


def stitching(cr, x, y, w, h, r, t, inset=7):
    cr.save()
    # groove shadow
    rrect(cr, x + inset, y + inset + 1, w - 2 * inset, h - 2 * inset, r)
    cr.set_source_rgba(0, 0, 0, 0.35)
    cr.set_line_width(2.2)
    cr.set_dash([5, 3])
    cr.stroke()
    rrect(cr, x + inset, y + inset, w - 2 * inset, h - 2 * inset, r)
    cr.set_source_rgba(*t['stitch'])
    cr.set_line_width(1.6)
    cr.stroke()
    cr.restore()


def engraved_text(cr, text, x, y, size, t, bold=True, align='left', font='Liberation Sans',
                  color=None, spacing=0.0):
    cr.save()
    cr.select_font_face(font, cairo.FONT_SLANT_NORMAL,
                        cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
    cr.set_font_size(size)
    ext = cr.text_extents(text)
    width = ext.x_advance + spacing * max(0, len(text) - 1)
    if align == 'center':
        x -= width / 2
    elif align == 'right':
        x -= width

    def draw(dx, dy, col):
        cr.set_source_rgba(*col)
        if spacing:
            cx = x + dx
            for ch in text:
                cr.move_to(cx, y + dy)
                cr.show_text(ch)
                cx += cr.text_extents(ch).x_advance + spacing
        else:
            cr.move_to(x + dx, y + dy)
            cr.show_text(text)
    draw(0, t['engrave_dy'], t['engrave_hi'])
    draw(0, 0, color or t['engrave'])
    cr.restore()
    return width


def glow_text(cr, text, x, y, size, color, align='left', font='Liberation Sans', bold=True):
    cr.save()
    cr.select_font_face(font, cairo.FONT_SLANT_NORMAL,
                        cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
    cr.set_font_size(size)
    ext = cr.text_extents(text)
    if align == 'center':
        x -= ext.x_advance / 2
    elif align == 'right':
        x -= ext.x_advance
    # fake blur: stacked translucent offsets
    for rad, a in ((3.0, 0.08), (2.0, 0.12), (1.0, 0.18)):
        for ang in range(0, 360, 45):
            cr.set_source_rgba(color[0], color[1], color[2], a)
            cr.move_to(x + math.cos(math.radians(ang)) * rad, y + math.sin(math.radians(ang)) * rad)
            cr.show_text(text)
    cr.set_source_rgba(min(1, color[0] * 0.3 + 0.75), min(1, color[1] * 0.3 + 0.75),
                       min(1, color[2] * 0.3 + 0.75), 1)
    cr.move_to(x, y)
    cr.show_text(text)
    cr.restore()
    return ext.x_advance


def screw(cr, cx, cy, r, t, angle=0.6):
    cr.save()
    g = cairo.RadialGradient(cx - r * 0.3, cy - r * 0.3, r * 0.1, cx, cy, r)
    g.add_color_stop_rgba(0, 0.95, 0.95, 0.96, 1)
    g.add_color_stop_rgba(1, 0.55, 0.57, 0.60, 1)
    cr.arc(cx, cy, r, 0, TAU)
    cr.set_source(g)
    cr.fill_preserve()
    cr.set_source_rgba(0, 0, 0, 0.45)
    cr.set_line_width(0.8)
    cr.stroke()
    cr.set_line_width(r * 0.32)
    cr.set_source_rgba(0.25, 0.26, 0.28, 0.9)
    dx, dy = math.cos(angle) * r * 0.7, math.sin(angle) * r * 0.7
    cr.move_to(cx - dx, cy - dy)
    cr.line_to(cx + dx, cy + dy)
    cr.stroke()
    cr.restore()


def inset_well(cr, x, y, w, h, r, fill_top, fill_bot, depth=1.0):
    """a recessed area: outer highlight lip, dark rim, inner shadow"""
    cr.save()
    rrect(cr, x - 1, y - 1, w + 2, h + 3, r + 1)
    cr.set_source_rgba(1, 1, 1, 0.35 * depth)
    cr.fill()
    rrect(cr, x - 1, y - 1, w + 2, h + 2, r + 1)
    cr.set_source_rgba(0, 0, 0, 0.55 * depth)
    cr.fill()
    rrect(cr, x, y, w, h, r)
    cr.set_source(vgrad(y, y + h, [(0, fill_top), (1, fill_bot)]))
    cr.fill()
    # inner top shadow
    cr.save()
    rrect(cr, x, y, w, h, r)
    cr.clip()
    cr.set_source(vgrad(y, y + 10, [(0, (0, 0, 0, 0.55 * depth)), (1, (0, 0, 0, 0))]))
    cr.rectangle(x, y, w, 10)
    cr.fill()
    cr.restore()
    cr.restore()


def glass_gloss(cr, x, y, w, h, r):
    cr.save()
    rrect(cr, x, y, w, h, r)
    cr.clip()
    cr.move_to(x, y)
    cr.line_to(x + w, y)
    cr.line_to(x + w, y + h * 0.22)
    cr.curve_to(x + w * 0.6, y + h * 0.42, x + w * 0.3, y + h * 0.30, x, y + h * 0.48)
    cr.close_path()
    cr.set_source(vgrad(y, y + h * 0.5, [(0, (1, 1, 1, 0.16)), (1, (1, 1, 1, 0.02))]))
    cr.fill()
    cr.restore()


def seven_segment(cr, text, x, y, h, color, dim):
    """classic 7 segment digits with colons, drawn as slanted polygons"""
    w = h * 0.55
    th = h * 0.13
    slant = h * 0.08
    segs = {
        '0': 'abcdef', '1': 'bc', '2': 'abged', '3': 'abgcd', '4': 'fgbc', '5': 'afgcd',
        '6': 'afgedc', '7': 'abc', '8': 'abcdefg', '9': 'abcdfg', '-': 'g', ' ': ''}

    def seg_poly(name, ox):
        half = h / 2
        pts = {
            'a': [(th * .6, 0), (w - th * .6, 0), (w - th * 1.5, th), (th * 1.5, th)],
            'd': [(th * 1.5, h - th), (w - th * 1.5, h - th), (w - th * .6, h), (th * .6, h)],
            'g': [(th, half), (th * 1.7, half - th / 2), (w - th * 1.7, half - th / 2), (w - th, half),
                  (w - th * 1.7, half + th / 2), (th * 1.7, half + th / 2)],
            'f': [(0, th * .6), (th, th * 1.5), (th, half - th * .7), (th * .5, half - th * .2), (0, half - th * .6)],
            'e': [(0, half + th * .6), (th * .5, half + th * .2), (th, half + th * .7), (th, h - th * 1.5), (0, h - th * .6)],
            'b': [(w, th * .6), (w, half - th * .6), (w - th * .5, half - th * .2), (w - th, half - th * .7), (w - th, th * 1.5)],
            'c': [(w, half + th * .6), (w, h - th * .6), (w - th, h - th * 1.5), (w - th, half + th * .7), (w - th * .5, half + th * .2)],
        }[name]
        cr.new_path()
        for i, (px, py) in enumerate(pts):
            sx = ox + px + slant * (1 - py / h)
            if i == 0:
                cr.move_to(sx, y + py)
            else:
                cr.line_to(sx, y + py)
        cr.close_path()

    cx = x
    for ch in text:
        if ch == ':':
            for yy in (h * 0.32, h * 0.72):
                cr.arc(cx + th * 0.9 + slant * (1 - yy / h), y + yy, th * 0.55, 0, TAU)
                cr.set_source_rgba(*color)
                cr.fill()
            cx += th * 2.2
            continue
        lit = segs.get(ch, '')
        for s in 'abcdefg':
            seg_poly(s, cx)
            if s in lit:
                for grow, a in ((2.0, 0.10), (1.0, 0.20)):
                    cr.set_source_rgba(color[0], color[1], color[2], a)
                    cr.set_line_width(grow * 2)
                    cr.stroke_preserve()
                cr.set_source_rgba(*color)
                cr.fill()
            else:
                cr.set_source_rgba(*dim)
                cr.fill()
        cx += w + th * 0.9
    return cx - x
