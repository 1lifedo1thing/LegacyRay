#!/usr/bin/env python3
"""generate app/Resources: icons, the denim tile, launch images and sounds.

the icons come from art/icon-1024.png (scripts/icon_from_logo.py makes it
from the logo); the rest is drawn with the cairo prototype of the classic
finish (scripts/design/classic.py), the same shapes the app draws. run from
anywhere:    python3 scripts/make_resources.py
needs python3-cairo and pillow."""
import math
import os
import random
import struct
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'design'))
import cairo  # noqa: E402
from PIL import Image  # noqa: E402
import classic  # noqa: E402

OUT = os.path.join(HERE, '..', 'app', 'Resources')
ART = os.path.join(HERE, '..', 'art', 'icon-1024.png')
TAU = math.pi * 2


def icons():
    master = Image.open(ART).convert('RGB')
    sizes = {
        'Icon.png': 57, 'Icon@2x.png': 114, 'Icon-72.png': 72, 'Icon-72@2x.png': 144,
        'Icon-60@2x.png': 120, 'Icon-76.png': 76, 'Icon-76@2x.png': 152,
        'Icon-Small.png': 29, 'Icon-Small@2x.png': 58, 'Icon-Small-50.png': 50,
        'Icon-Small-50@2x.png': 100,
    }
    for name, size in sizes.items():
        master.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name))


def classic_launch(w, h, scale, status_bar):
    """ios 4-6: the shell the app opens into, as apple asks: bars, no words.
    iphone images include the status bar strip, ipad ones do not"""
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, int(w * scale), int(h * scale))
    cr = cairo.Context(s)
    cr.scale(scale, scale)
    top = 20 if status_bar else 0
    if status_bar:
        cr.set_source_rgb(0, 0, 0)
        cr.rectangle(0, 0, w, 20)
        cr.fill()
    pane = 320 if w >= 700 else 0
    if pane:
        classic.pinstripes(cr, 0, top + 44, pane, h - top - 44)
        classic.nav_bar(cr, 0, top, pane, '')
        cr.set_source_rgb(0, 0, 0)
        cr.rectangle(pane, top, 1, h - top)
        cr.fill()
        pane += 1
    body = h - top - 44
    focus = top + 44 + (body * 0.36 if pane else 30 + 88 + (10 if body >= 440 else 0))
    classic.main_background(cr, pane, top + 44, w - pane, body, focus)
    classic.nav_bar(cr, pane, top, w - pane, '')
    return s


def save_quantized(surface, path):
    """a textured launch image is a quarter of the size in 32 colours, which the
    eye cannot tell from the full ones; libimagequant
    keeps the copper thread, which median cut loses. without it the image is
    saved as it is"""
    import io
    buf = io.BytesIO()
    surface.write_to_png(buf)
    im = Image.open(io.BytesIO(buf.getvalue())).convert('RGB')
    try:
        from PIL import features
        if features.check_feature('libimagequant'):
            im = im.quantize(colors=32, method=Image.Quantize.LIBIMAGEQUANT, dither=Image.Dither.NONE)
    except Exception:
        pass
    im.save(path, optimize=True)


def flat_launch(w, h, scale):
    """ios 7 launch images: the flat shell the app opens into, with the header
    under a transparent status bar"""
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, w * scale, h * scale)
    cr = cairo.Context(s)
    cr.scale(scale, scale)
    cr.set_source_rgb(0.969, 0.969, 0.969)
    cr.paint()
    cr.set_source_rgb(0.973, 0.973, 0.973)
    cr.rectangle(0, 0, w, 64)
    cr.fill()
    cr.set_source_rgb(0.698, 0.698, 0.698)
    cr.rectangle(0, 64 - 1.0 / scale, w, 1.0 / scale)
    cr.fill()
    return s


def write_wav(name, samples, rate=22050):
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b''.join(struct.pack('<h', max(-32767, min(32767, int(v * 32767)))) for v in samples))


def sounds():
    rate = 22050
    rnd = random.Random(9)
    # key click: a short noise burst through a resonance
    click = []
    for i in range(int(rate * 0.018)):
        t = i / rate
        env = math.exp(-t * 380)
        click.append(env * (0.55 * (rnd.random() * 2 - 1) + 0.5 * math.sin(TAU * 2600 * t)))
    write_wav('click.wav', click)
    # the big button: a heavier latch, low thump plus a tick
    clunk = []
    for i in range(int(rate * 0.09)):
        t = i / rate
        thump = math.exp(-t * 60) * math.sin(TAU * 110 * t) * 0.9
        tick = math.exp(-t * 500) * (rnd.random() * 2 - 1) * 0.6
        ring = math.exp(-t * 90) * math.sin(TAU * 1750 * t) * 0.15
        clunk.append(thump + tick + ring)
    write_wav('clunk.wav', clunk)
    tick = []
    for i in range(int(rate * 0.008)):
        t = i / rate
        tick.append(math.exp(-t * 700) * math.sin(TAU * 4200 * t) * 0.5)
    write_wav('tick.wav', tick)


def main():
    os.makedirs(OUT, exist_ok=True)
    icons()
    classic.write_denim_tiles()
    launches = [
        ('Default.png', 320, 480, 1, True), ('Default@2x.png', 320, 480, 2, True),
        ('Default-568h@2x.png', 320, 568, 2, True),
        ('Default-Portrait~ipad.png', 768, 1004, 1, False), ('Default-Portrait@2x~ipad.png', 768, 1004, 2, False),
        ('Default-Landscape~ipad.png', 1024, 748, 1, False), ('Default-Landscape@2x~ipad.png', 1024, 748, 2, False),
    ]
    for name, w, h, scale, bar in launches:
        save_quantized(classic_launch(w, h, scale, bar), os.path.join(OUT, name))
    flat_launches = [
        ('LaunchImage-700@2x.png', 320, 480, 2), ('LaunchImage-700-568h@2x.png', 320, 568, 2),
        ('LaunchImage-700-Portrait~ipad.png', 768, 1024, 1), ('LaunchImage-700-Portrait@2x~ipad.png', 768, 1024, 2),
        ('LaunchImage-700-Landscape~ipad.png', 1024, 768, 1), ('LaunchImage-700-Landscape@2x~ipad.png', 1024, 768, 2),
    ]
    for name, w, h, scale in flat_launches:
        flat_launch(w, h, scale).write_to_png(os.path.join(OUT, name))
    sounds()
    print('resources written to', os.path.normpath(OUT))


if __name__ == '__main__':
    main()
