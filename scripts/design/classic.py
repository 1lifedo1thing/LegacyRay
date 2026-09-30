"""the classic (ios 4-6) LegacyRay finish, as a cairo prototype.

black denim with copper stitching from the icon for the chrome (navigation
bars, the main screen), the stock ios 6 grouped tables for everything else.
LRDraw.m, LRButton.m, LRToggleSwitch.m and friends draw the same shapes with
the same numbers in CoreGraphics; this module previews them on a desktop and
draws the static art (launch images, the denim tile)."""
import math
import os
import random
import cairo

TAU = math.pi * 2
HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.normpath(os.path.join(HERE, '..', '..', 'app', 'Resources'))
FONT = 'Nimbus Sans'


def hexc(h, a=1.0):
    h = h.lstrip('#')
    return (int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0, a)


# palette, the same values LRSkin.m sets for the classic finish
STITCH = hexc('#B8966F')           # copper thread
STITCH_SHADOW = (0, 0, 0, 0.55)
GROUP_BG = hexc('#C5CCD4')         # ios 6 pinstripes
GROUP_STRIPE = hexc('#CBD2D8')
CELL_BORDER = hexc('#ABABAB')
CELL_LINE = hexc('#E0E0E0')
INK = hexc('#000000')
DETAIL = hexc('#385487')           # ios 6 value blue
MUTED = hexc('#7F7F7F')
HEADER = hexc('#4C566C')
CHEVRON = hexc('#8C8C8C')
BLUE_TOP = hexc('#058CF5')         # selection / switch
BLUE_BOTTOM = hexc('#015EE6')
GOOD = hexc('#3E8E41')
WARN = hexc('#C07A12')
BAD = hexc('#C4372B')
LIT_GREEN = hexc('#4DB853')
LIT_AMBER = hexc('#E3A437')
LIT_RED = hexc('#D5483B')
PEARL_TOP = hexc('#FBFBFA')
PEARL_BOTTOM = hexc('#D4D5D2')


def rrect(cr, x, y, w, h, r):
    r = min(r, w / 2.0, h / 2.0)
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


def text(cr, s, x, y, size, col, bold=False, align='left', shadow=None, dy=1, font=FONT, maxw=None, fit=None):
    """y is the baseline; fit shrinks the text down to that size before
    cutting it, like adjustsFontSizeToFitWidth"""
    cr.select_font_face(font, cairo.FONT_SLANT_NORMAL,
                        cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
    cr.set_font_size(size)
    if maxw is not None and fit:
        while size > fit and cr.text_extents(s).x_advance > maxw:
            size -= 0.5
            cr.set_font_size(size)
    if maxw is not None:
        while cr.text_extents(s).x_advance > maxw and len(s) > 2:
            s = s[:-2] + '…'
    w = cr.text_extents(s).x_advance
    if align == 'center':
        x -= w / 2
    elif align == 'right':
        x -= w
    if shadow:
        cr.set_source_rgba(*shadow)
        cr.move_to(x, y + dy)
        cr.show_text(s)
    cr.set_source_rgba(*col)
    cr.move_to(x, y)
    cr.show_text(s)
    cr.new_path()      # show_text leaves a current point an arc would join
    return w


# ---------------------------------------------------------------- denim

def denim_tile_image(N=210, p=6.0, L=10.5, seed=7, base=(7, 8, 9), thread=(128, 129, 132)):
    """a seamless tile of right hand twill: 45 degree ribs of short slanted
    floats. N/p ribs and N/L floats cross the tile, both whole numbers, and
    every random-looking term is a sum of waves with whole periods over them,
    so the tile repeats without a seam. the 1x tile is drawn on its own
    (N=105, p=3): a 2x tile scaled down would beat against the pixel grid.
    returns a PIL image"""
    from PIL import Image
    R, J = int(round(N / p)), int(round(N / L))
    rnd = random.Random(seed)
    terms = [(rnd.randint(1, 9), rnd.randint(1, 9), rnd.random() * TAU, 0.5 + rnd.random()) for _ in range(6)]
    norm = sum(t[3] for t in terms)
    rib_terms = [(rnd.randint(1, 9), rnd.random() * TAU, 0.5 + rnd.random()) for _ in range(3)]
    rn = sum(t[2] for t in rib_terms)
    im = Image.new('RGB', (N, N))
    px = im.load()
    sub = (0.125, 0.375, 0.625, 0.875)
    for y in range(N):
        for x in range(N):
            acc = 0.0
            for sy in sub:
                for sx in sub:
                    X, Y = x + sx, y + sy
                    u = X + Y
                    i = math.floor(u / p)
                    w = (u - i * p) / p
                    rib = math.sin(math.pi * w) ** 1.2
                    t = (Y - X) - 1.6 * (w * p)
                    j = math.floor(t / L)
                    f = (t - j * L) / L
                    dash = math.sin(math.pi * f) ** 0.45
                    gi = sum(c * math.sin(TAU * k * i / R + ph) for k, ph, c in rib_terms) / rn
                    g = sum(c * math.sin(TAU * (k * i / R + m * j / J) + ph) for k, m, ph, c in terms) / norm
                    acc += rib * dash * (0.78 + 0.12 * gi + 0.30 * g)
            k = acc / 16.0 * (1.0 + (rnd.random() - 0.5) * 0.12)
            k = max(0.0, min(1.0, k))
            px[x, y] = tuple(int(base[c] + (thread[c] - base[c]) * k) for c in range(3))
    return im


_tiles = {}


def denim_surface(retina=True):
    """the tile from the app resources (made on first use): the @2x one for
    retina drawing, the 1x one for 1x, as the app picks them"""
    name = 'denim@2x.png' if retina else 'denim.png'
    if name not in _tiles:
        path = os.path.join(RES, name)
        if not os.path.exists(path):
            write_denim_tiles()
        _tiles[name] = cairo.ImageSurface.create_from_png(path)
    return _tiles[name]


def denim_pattern(cr):
    """a repeating pattern of the tile right for the context's scale"""
    retina = cr.get_matrix().xx > 1.5
    pat = cairo.SurfacePattern(denim_surface(retina))
    pat.set_extend(cairo.EXTEND_REPEAT)
    if retina:
        m = cairo.Matrix()
        m.scale(2, 2)          # tile pixels per point
        pat.set_matrix(m)
    return pat


def write_denim_tiles():
    denim_tile_image().save(os.path.join(RES, 'denim@2x.png'))
    denim_tile_image(N=105, p=3.0, L=5.25).save(os.path.join(RES, 'denim.png'))


def denim(cr, x, y, w, h, shade=0.0):
    """the tile repeats every 105 points; shade darkens it"""
    cr.save()
    cr.rectangle(x, y, w, h)
    cr.clip()
    cr.set_source(denim_pattern(cr))
    cr.paint()
    if shade:
        cr.set_source_rgba(0, 0, 0, shade)
        cr.paint()
    cr.restore()


def stitch_line(cr, x0, y0, x1, y1, width=1.3):
    for pass_ in (0, 1):
        cr.save()
        cr.set_dash([4.0, 2.5])
        cr.set_line_width(width + (0.6 if pass_ == 0 else 0))
        cr.set_line_cap(cairo.LINE_CAP_BUTT)
        cr.set_source_rgba(*(STITCH_SHADOW if pass_ == 0 else STITCH))
        dy = 0.8 if pass_ == 0 else 0
        cr.move_to(x0, y0 + dy)
        cr.line_to(x1, y1 + dy)
        cr.stroke()
        cr.restore()


def stitch_circle(cr, cx, cy, r, width=1.3):
    circ = TAU * r
    n = max(8, int(round(circ / 6.5)))
    on = circ / n * 0.64
    off = circ / n - on
    for pass_ in (0, 1):
        cr.save()
        cr.set_dash([on, off])
        cr.set_line_width(width + (0.6 if pass_ == 0 else 0))
        cr.set_source_rgba(*(STITCH_SHADOW if pass_ == 0 else STITCH))
        cr.new_path()
        cr.arc(cx, cy + (0.8 if pass_ == 0 else 0), r, 0, TAU)
        cr.stroke()
        cr.restore()


def stitch_rrect(cr, x, y, w, h, r, width=1.3):
    for pass_ in (0, 1):
        cr.save()
        cr.set_dash([4.0, 2.5])
        cr.set_line_width(width + (0.6 if pass_ == 0 else 0))
        cr.set_source_rgba(*(STITCH_SHADOW if pass_ == 0 else STITCH))
        rrect(cr, x, y + (0.8 if pass_ == 0 else 0), w, h, r)
        cr.stroke()
        cr.restore()


# ---------------------------------------------------------------- chrome

def status_bar(cr, w, carrier='LegacyNet', time_='9:41'):
    cr.set_source_rgb(0, 0, 0)
    cr.rectangle(0, 0, w, 20)
    cr.fill()
    text(cr, carrier, 6, 14.5, 12, (0.82, 0.82, 0.82, 1), bold=True)
    text(cr, time_, w / 2, 14.5, 12, (0.82, 0.82, 0.82, 1), bold=True, align='center')
    cr.set_source_rgba(0.82, 0.82, 0.82, 1)
    cr.rectangle(w - 30, 6, 22, 9)
    cr.set_line_width(1)
    cr.stroke()
    cr.rectangle(w - 28, 8, 16, 5)
    cr.fill()
    cr.rectangle(w - 7.5, 8.5, 1.5, 4)
    cr.fill()


def nav_bar(cr, x, y, w, title, h=44.0, left=None, right=None, extra=None):
    """denim bar: the twill a shade lighter than the page, a soft top light,
    a copper seam just above the bottom edge and a shadow on the page"""
    denim(cr, x, y, w, h)
    cr.rectangle(x, y, w, h)
    cr.set_source(vgrad(y, y + h, [(0, (1, 1, 1, 0.13)), (0.5, (1, 1, 1, 0.05)), (0.5, (1, 1, 1, 0.0)),
                                   (1, (0, 0, 0, 0.12))]))
    cr.fill()
    cr.set_source_rgba(1, 1, 1, 0.16)
    cr.rectangle(x, y, w, 1)
    cr.fill()
    stitch_line(cr, x, y + h - 4.5, x + w, y + h - 4.5)
    cr.set_source_rgba(0, 0, 0, 0.85)
    cr.rectangle(x, y + h - 1, w, 1)
    cr.fill()
    # the bar's shadow on the page
    cr.rectangle(x, y + h, w, 4)
    cr.set_source(vgrad(y + h, y + h + 4, [(0, (0, 0, 0, 0.35)), (1, (0, 0, 0, 0))]))
    cr.fill()
    side = 0
    if left:
        side = max(side, bar_item(cr, x + 5, y + 7, left, anchor='left') + 10)
    if right:
        rw = bar_item(cr, x + w - 5, y + 7, right, anchor='right')
        used = rw + 10
        if extra:
            used += bar_item(cr, x + w - 5 - rw - 6, y + 7, extra, anchor='right') + 6
        side = max(side, used)
    text(cr, title, x + w / 2, y + 28.5, 20, (1, 1, 1, 1), bold=True, align='center',
         shadow=(0, 0, 0, 0.6), dy=-1, maxw=w - side * 2 - 8)


def bar_button_shape(cr, x, y, w, h, back=False):
    r = 5.0
    if not back:
        rrect(cr, x, y, w, h, r)
        return
    point = h * 0.36
    cr.move_to(x, y + h / 2)
    cr.line_to(x + point, y + 1)
    cr.curve_to(x + point + 0.6, y, x + point + 2, y, x + point + 3, y)
    cr.line_to(x + w - r, y)
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.line_to(x + point + 3, y + h)
    cr.curve_to(x + point + 2, y + h, x + point + 0.6, y + h, x + point, y + h - 1)
    cr.close_path()


def bar_button(cr, x, y, w, h=30.0, kind='plain', pressed=False):
    back = kind == 'back'
    # the light lip under the key, then the dark rim
    cr.save()
    cr.translate(0, 1)
    bar_button_shape(cr, x, y, w, h, back)
    cr.set_source_rgba(1, 1, 1, 0.12)
    cr.fill()
    cr.restore()
    bar_button_shape(cr, x, y, w, h, back)
    cr.set_source_rgba(0, 0, 0, 0.78)
    cr.fill()
    cr.save()
    bar_button_shape(cr, x + 1, y + 1, w - 2, h - 2, back)
    cr.clip()
    if kind == 'done':
        top, bot = hexc('#5B8FE6'), hexc('#2458C4')
        if pressed:
            top, bot = hexc('#3A6BC4'), hexc('#1B449C')
        cr.set_source(vgrad(y, y + h, [(0, top), (0.5, lerp(top, bot, 0.45)), (0.5, lerp(top, bot, 0.62)), (1, bot)]))
        cr.paint()
    else:
        denim(cr, x, y, w, h)
        a, b = (0.22, 0.07) if not pressed else (0.04, 0.0)
        cr.set_source(vgrad(y, y + h, [(0, (1, 1, 1, a)), (0.5, (1, 1, 1, (a + b) / 2)),
                                       (0.5, (1, 1, 1, b)), (1, (1, 1, 1, b * 0.6))]))
        cr.paint()
        if pressed:
            cr.set_source_rgba(0, 0, 0, 0.3)
            cr.paint()
    cr.restore()
    # inner top light
    cr.save()
    bar_button_shape(cr, x + 1.5, y + 1.5, w - 3, h - 3, back)
    cr.clip()
    cr.set_source_rgba(1, 1, 1, 0.22 if not pressed else 0.05)
    cr.rectangle(x, y + 1, w, 1)
    cr.fill()
    cr.restore()


def bar_item(cr, x, y, item, anchor='left'):
    """item: ('text', 'Back', kind) or ('glyph', name). returns its width"""
    kind = item[2] if len(item) > 2 else 'plain'
    if item[0] == 'glyph':
        w = 36.0
    else:
        cr.select_font_face(FONT, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(12)
        w = cr.text_extents(item[1]).x_advance + (26 if kind == 'back' else 20)
        w = max(w, 50)
    bx = x if anchor == 'left' else x - w
    bar_button(cr, bx, y, w, 30, kind)
    if item[0] == 'glyph':
        glyph(cr, item[1], bx + w / 2, y + 15, 17, (1, 1, 1, 1), shadow=(0, 0, 0, 0.6))
    else:
        tx = bx + w / 2 + (4 if kind == 'back' else 0)
        text(cr, item[1], tx, y + 19.5, 12, (1, 1, 1, 1), bold=True, align='center',
             shadow=(0, 0, 0, 0.55), dy=-1)
    return w


def glyph(cr, name, cx, cy, s, col, shadow=None):
    for pass_ in ((0, shadow), (1, col)):
        if pass_[1] is None:
            continue
        cr.save()
        cr.translate(0, -1 if pass_[0] == 0 else 0)
        cr.set_source_rgba(*pass_[1])
        if name == 'plus':
            t = s * 0.15
            cr.rectangle(cx - s * 0.36, cy - t / 2, s * 0.72, t)
            cr.rectangle(cx - t / 2, cy - s * 0.36, t, s * 0.72)
            cr.fill()
        elif name == 'gear':
            ro, ri, teeth = s * 0.48, s * 0.36, 8
            for k in range(teeth * 2):
                a0, a1 = TAU * k / (teeth * 2), TAU * (k + 1) / (teeth * 2)
                r = ri if k % 2 else ro
                if k == 0:
                    cr.move_to(cx + math.cos(a0) * r, cy + math.sin(a0) * r)
                cr.line_to(cx + math.cos(a0) * r, cy + math.sin(a0) * r)
                cr.line_to(cx + math.cos(a1) * r, cy + math.sin(a1) * r)
            cr.close_path()
            cr.new_sub_path()
            cr.arc_negative(cx, cy, s * 0.15, TAU, 0)
            cr.close_path()
            cr.set_fill_rule(cairo.FILL_RULE_EVEN_ODD)
            cr.fill()
        elif name == 'dots':
            for k in range(3):
                cr.arc(cx + (k - 1) * s * 0.3, cy, s * 0.09, 0, TAU)
                cr.fill()
        cr.restore()


# ---------------------------------------------------------------- grouped tables

def pinstripes(cr, x, y, w, h):
    cr.save()
    cr.rectangle(x, y, w, h)
    cr.clip()
    cr.set_source_rgba(*GROUP_BG)
    cr.paint()
    cr.set_source_rgba(*GROUP_STRIPE)
    sx = x - (x % 7)
    while sx < x + w:
        cr.rectangle(sx + 5, y, 2, h)
        sx += 7
    cr.fill()
    cr.restore()


def cell_path(cr, x, y, w, h, pos, r=10.0):
    top = pos in ('single', 'top')
    bottom = pos in ('single', 'bottom')
    cr.new_path()
    cr.move_to(x, y + (r if top else 0))
    if top:
        cr.arc(x + r, y + r, r, math.pi, 1.5 * math.pi)
        cr.arc(x + w - r, y + r, r, 1.5 * math.pi, 2 * math.pi)
    else:
        cr.line_to(x, y)
        cr.line_to(x + w, y)
    if bottom:
        cr.arc(x + w - r, y + h - r, r, 0, 0.5 * math.pi)
        cr.arc(x + r, y + h - r, r, 0.5 * math.pi, math.pi)
    else:
        cr.line_to(x + w, y + h)
        cr.line_to(x, y + h)
    cr.close_path()


def group_cell(cr, x, y, w, h, pos, pressed=False, on_dark=False):
    """a white grouped row: grey border, a white lip under the last row"""
    bottom = pos in ('single', 'bottom')
    if bottom and not on_dark:
        cr.save()
        cr.translate(0, 1)
        cell_path(cr, x, y, w, h - 1, pos)
        cr.set_source_rgba(1, 1, 1, 0.8)
        cr.fill()
        cr.restore()
    hh = h - (1 if bottom else 0)
    cell_path(cr, x, y, w, hh, pos)
    if pressed:
        cr.set_source(vgrad(y, y + hh, [(0, BLUE_TOP), (1, BLUE_BOTTOM)]))
    elif on_dark:
        cr.set_source(vgrad(y, y + hh, [(0, hexc('#FDFDFD')), (1, hexc('#EDEDEE'))]))
    else:
        cr.set_source_rgba(1, 1, 1, 1)
    cr.fill()
    if not bottom and not pressed:
        cr.set_source_rgba(*CELL_LINE)
        cr.rectangle(x + 1, y + hh - 1, w - 2, 1)
        cr.fill()
    cell_path(cr, x + 0.5, y + 0.5, w - 1, hh - (0 if bottom else -0.5) - 1 + (0.5 if not bottom else 0), pos, 9.5)
    cr.set_source_rgba(*((0, 0, 0, 0.75) if on_dark else CELL_BORDER))
    cr.set_line_width(1)
    cr.stroke()


def chevron(cr, x, y, col=CHEVRON, s=4.5):
    cr.save()
    cr.set_source_rgba(*col)
    cr.set_line_width(2.6)
    cr.set_line_cap(cairo.LINE_CAP_SQUARE)
    cr.set_line_join(cairo.LINE_JOIN_MITER)
    cr.move_to(x - s * 0.6, y - s)
    cr.line_to(x + s * 0.4, y)
    cr.line_to(x - s * 0.6, y + s)
    cr.stroke()
    cr.restore()


def checkmark(cr, x, y, col=DETAIL):
    cr.save()
    cr.set_source_rgba(*col)
    cr.set_line_width(2.6)
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    cr.set_line_join(cairo.LINE_JOIN_ROUND)
    cr.move_to(x, y)
    cr.line_to(x + 4.5, y + 5)
    cr.line_to(x + 13, y - 7)
    cr.stroke()
    cr.restore()


def detail_disclosure(cr, cx, cy):
    """the blue (>) button of ios 6"""
    r = 10.5
    cr.arc(cx, cy + 1, r, 0, TAU)
    cr.set_source_rgba(1, 1, 1, 0.9)
    cr.fill()
    cr.arc(cx, cy, r, 0, TAU)
    cr.set_source_rgba(0, 0, 0, 0.35)
    cr.fill()
    cr.arc(cx, cy, r - 1, 0, TAU)
    cr.set_source(vgrad(cy - r, cy + r, [(0, hexc('#5D9CF4')), (0.5, hexc('#2A76E3')), (1, hexc('#1459CF'))]))
    cr.fill()
    cr.save()
    cr.arc(cx, cy, r - 1, 0, TAU)
    cr.clip()
    cr.arc(cx, cy - r * 0.9, r * 1.05, 0, TAU)
    cr.set_source_rgba(1, 1, 1, 0.22)
    cr.fill()
    cr.restore()
    cr.arc(cx, cy, r - 1, 0, TAU)
    cr.set_source_rgba(1, 1, 1, 0.9)
    cr.set_line_width(2)
    cr.stroke()
    chevron(cr, cx + 0.5, cy, (1, 1, 1, 1), 3.6)


def switch(cr, x, y, on, w=79.0, h=27.0, on_text='ON', off_text='OFF'):
    """the ios 6 switch, drawn so it looks the same on ios 4 and under a
    classic theme on ios 7"""
    r = h / 2
    kx = x + (w - h if on else 0)
    cr.save()
    rrect(cr, x, y, w, h, r)
    cr.clip()
    # the track slides with the knob: blue on the left of it, grey on the right
    cr.rectangle(x, y, kx + r - x, h)
    cr.set_source(vgrad(y, y + h, [(0, hexc('#0A5FD1')), (1, hexc('#3C8FF2'))]))
    cr.fill()
    cr.rectangle(kx + r, y, x + w - kx - r, h)
    cr.set_source(vgrad(y, y + h, [(0, hexc('#E6E6E6')), (1, hexc('#FDFDFD'))]))
    cr.fill()
    # inner shadow along the top
    cr.rectangle(x, y, w, 6)
    cr.set_source(vgrad(y, y + 6, [(0, (0, 0, 0, 0.28)), (1, (0, 0, 0, 0))]))
    cr.fill()
    size = 16
    cr.select_font_face(FONT, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    while size > 10:
        cr.set_font_size(size)
        if max(cr.text_extents(on_text).x_advance, cr.text_extents(off_text).x_advance) <= w - h - 8:
            break
        size -= 1
    if on:
        text(cr, on_text, x + (w - h) / 2, y + 19, size, (1, 1, 1, 1), bold=True, align='center',
             shadow=(0, 0, 0, 0.35), dy=-1)
    else:
        text(cr, off_text, x + h + (w - h) / 2, y + 19, size, hexc('#7F7F7F'), bold=True, align='center')
    cr.restore()
    rrect(cr, x + 0.5, y + 0.5, w - 1, h - 1, r - 0.5)
    cr.set_source_rgba(0, 0, 0, 0.33)
    cr.set_line_width(1)
    cr.stroke()
    # knob
    cr.arc(kx + r, y + r + 0.5, r, 0, TAU)
    cr.set_source_rgba(0, 0, 0, 0.25)
    cr.fill()
    cr.arc(kx + r, y + r, r - 0.5, 0, TAU)
    cr.set_source(vgrad(y, y + h, [(0, hexc('#C9C9C9')), (1, hexc('#FDFDFD'))]))
    cr.fill()
    cr.arc(kx + r, y + r, r - 1.5, 0, TAU)
    cr.set_source(vgrad(y, y + h, [(0, hexc('#FDFDFD')), (1, hexc('#E4E4E4'))]))
    cr.fill()
    cr.arc(kx + r, y + r, r - 0.5, 0, TAU)
    cr.set_source_rgba(0, 0, 0, 0.35)
    cr.set_line_width(1)
    cr.stroke()


def section_header(cr, s, x, y):
    text(cr, s, x, y, 17, HEADER, bold=True, shadow=(1, 1, 1, 1), dy=1)


def footer(cr, s, cx, y, w=280):
    words = s.split(' ')
    line, lines = '', []
    cr.select_font_face(FONT, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
    cr.set_font_size(15)
    for wd in words:
        t = (line + ' ' + wd).strip()
        if cr.text_extents(t).x_advance > w and line:
            lines.append(line)
            line = wd
        else:
            line = t
    lines.append(line)
    for i, l in enumerate(lines):
        text(cr, l, cx, y + i * 19, 15, HEADER, align='center', shadow=(1, 1, 1, 1), dy=1)
    return len(lines) * 19


def flag(cr, code, x, y, d, ring=True):
    try:
        img = cairo.ImageSurface.create_from_png(os.path.join(RES, 'flags', 'flag-%s.png' % code))
    except Exception:
        return
    cr.save()
    cr.arc(x + d / 2, y + d / 2 + 0.6, d / 2, 0, TAU)
    cr.set_source_rgba(0, 0, 0, 0.25)
    cr.fill()
    cr.arc(x + d / 2, y + d / 2, d / 2, 0, TAU)
    cr.clip()
    cr.translate(x, y)
    cr.scale(d / img.get_width(), d / img.get_height())
    cr.set_source_surface(img, 0, 0)
    cr.paint()
    cr.restore()
    cr.save()
    cr.arc(x + d / 2, y + d / 2, d / 2, 0, TAU)
    cr.clip()
    cr.rectangle(x, y, d, d / 2)
    cr.set_source(vgrad(y, y + d / 2, [(0, (1, 1, 1, 0.35)), (1, (1, 1, 1, 0.06))]))
    cr.fill()
    cr.restore()
    if ring:
        cr.arc(x + d / 2, y + d / 2, d / 2 - 0.5, 0, TAU)
        cr.set_source_rgba(0, 0, 0, 0.28)
        cr.set_line_width(1)
        cr.stroke()


# ---------------------------------------------------------------- the main screen

def power_button(cr, cx, cy, R, state='off', pressed=False):
    """a pearl button sewn into the denim: a stitched ring, a soft well and a
    matte white cap whose engraved glyph lights up with the tunnel"""
    well = R + 9
    stitch_circle(cr, cx, cy, R + 17)
    # the well: darker cloth pressed in, shade from the top edge, light lip below
    cr.arc(cx, cy, well, 0, TAU)
    cr.set_source_rgba(0, 0, 0, 0.42)
    cr.fill()
    cr.save()
    cr.arc(cx, cy, well, 0, TAU)
    cr.clip()
    cr.rectangle(cx - well, cy - well, well * 2, well)
    cr.set_source(vgrad(cy - well, cy - well + 14, [(0, (0, 0, 0, 0.5)), (1, (0, 0, 0, 0))]))
    cr.fill()
    cr.restore()
    cr.arc(cx, cy + 0.5, well, math.pi * 0.15, math.pi * 0.85)
    cr.set_source_rgba(1, 1, 1, 0.10)
    cr.set_line_width(1)
    cr.stroke()
    # the cap's shadow in the well
    oy = 1.5 if pressed else 3.0
    for i in range(7):
        cr.arc(cx, cy + oy, R + 3.5 - i * 0.6, 0, TAU)
        cr.set_source_rgba(0, 0, 0, 0.08)
        cr.fill()
    py = cy + (1 if pressed else 0)
    cr.save()
    cr.arc(cx, py, R, 0, TAU)
    cr.clip()
    top, bot = (PEARL_TOP, PEARL_BOTTOM) if not pressed else (hexc('#E4E4E2'), hexc('#C4C5C2'))
    cr.set_source(vgrad(py - R, py + R, [(0, top), (1, bot)]))
    cr.paint()
    # the white twill of the L in the icon, very faint
    cr.save()
    cr.set_operator(cairo.OPERATOR_MULTIPLY)
    cr.set_source(denim_pattern(cr))
    cr.paint_with_alpha(0.035)
    cr.restore()
    g = cairo.RadialGradient(cx - R * 0.25, py - R * 0.55, 0, cx - R * 0.25, py - R * 0.55, R * 1.2)
    g.add_color_stop_rgba(0, 1, 1, 1, 0.55)
    g.add_color_stop_rgba(1, 1, 1, 1, 0)
    cr.set_source(g)
    cr.paint()
    cr.restore()
    cr.arc(cx, py, R - 0.5, 0, TAU)
    cr.set_source_rgba(0, 0, 0, 0.55)
    cr.set_line_width(1)
    cr.stroke()
    cr.arc(cx, py, R - 1.5, math.pi * 1.1, math.pi * 1.9)
    cr.set_source_rgba(1, 1, 1, 0.9)
    cr.stroke()
    # the glyph: engraved grey at rest, lit from behind otherwise
    ink = {'off': hexc('#A2A5A9'), 'tuning': LIT_AMBER, 'on': LIT_GREEN, 'error': LIT_RED}[state]
    gr, lw = R * 0.34, max(2.0, R * 0.085)

    def power_path(dy):
        cr.new_path()
        cr.arc(cx, py + dy, gr, -math.pi / 2 + 0.72, -math.pi / 2 - 0.72 + TAU)
        cr.move_to(cx, py + dy - gr * 1.22)
        cr.line_to(cx, py + dy - gr * 0.28)
    cr.save()
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    power_path(1)
    cr.set_source_rgba(1, 1, 1, 0.95)
    cr.set_line_width(lw)
    cr.stroke()
    if state != 'off':
        for k in range(4, 0, -1):
            power_path(0)
            cr.set_source_rgba(ink[0], ink[1], ink[2], 0.07)
            cr.set_line_width(lw + k * 2.2)
            cr.stroke()
    power_path(-0.6)
    cr.set_source_rgba(0, 0, 0, 0.18)
    cr.set_line_width(lw)
    cr.stroke()
    power_path(0)
    cr.set_source_rgba(*ink)
    cr.set_line_width(lw)
    cr.stroke()
    cr.restore()


def server_card(cr, x, y, w, h, code, name, detail, ping=None, ping_col=DETAIL):
    """the current station, a single grouped row laid on the denim"""
    cr.save()
    for i in range(3):
        rrect(cr, x - 0.5 + i * 0.2, y + 1.5 + i * 0.6, w + 1 - i * 0.4, h, 10)
        cr.set_source_rgba(0, 0, 0, 0.14)
        cr.fill()
    cr.restore()
    group_cell(cr, x, y, w, h, 'single', on_dark=True)
    fx = x + 12
    if code:
        flag(cr, code, fx, y + (h - 29) / 2, 29)
        tx = fx + 40
    else:
        tx = fx + 2
    right = x + w - 14
    chevron(cr, right - 2, y + h / 2)
    right -= 16
    pw = 0
    if ping:
        pw = text(cr, ping, right, y + h / 2 + 5.5, 15, ping_col, align='right')
    text(cr, name, tx, y + h / 2 - 3, 17, INK, bold=True, maxw=right - pw - 10 - tx)
    text(cr, detail, tx, y + h / 2 + 15, 13, MUTED, maxw=right - pw - 10 - tx)


def main_background(cr, x, y, w, h, cy):
    """the pattern a shade darker and LRVignetteImage stretched round cy"""
    denim(cr, x, y, w, h, shade=0.18)
    g = cairo.RadialGradient(x + w / 2, cy, 0, x + w / 2, cy, max(w, h) * 0.85)
    g.add_color_stop_rgba(0, 1, 1, 1, 0.06)
    g.add_color_stop_rgba(0.45, 0, 0, 0, 0.0)
    g.add_color_stop_rgba(1, 0, 0, 0, 0.55)
    cr.save()
    cr.rectangle(x, y, w, h)
    cr.clip()
    cr.set_source(g)
    cr.paint()
    cr.restore()


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))
