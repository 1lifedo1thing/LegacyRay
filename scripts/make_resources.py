#!/usr/bin/env python3
"""generate app/Resources: icons, launch images and the mechanical sounds.

uses the cairo prototype of the skin (scripts/design) so the static art is
drawn with the same primitives as the running app. run from anywhere:
    python3 scripts/make_resources.py
needs python3-cairo (apt install python3-cairo)."""
import math
import os
import random
import struct
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'design'))
import cairo  # noqa: E402
from skin import DAY, brushed_metal, rrect, vgrad, engraved_text, screw, noise, TAU  # noqa: E402
from components import power_button  # noqa: E402

OUT = os.path.join(HERE, '..', 'app', 'Resources')


def icon(size):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
    cr = cairo.Context(s)
    k = size / 114.0
    cr.scale(k, k)
    t = DAY
    brushed_metal(cr, 0, 0, 114, 114, t, seed=3)
    # a warm vignette so the knob pops
    g = cairo.RadialGradient(57, 52, 10, 57, 57, 80)
    g.add_color_stop_rgba(0, 1, 1, 1, 0.0)
    g.add_color_stop_rgba(1, 0, 0, 0, 0.28)
    cr.set_source(g)
    cr.paint()
    # rays behind the knob
    cr.save()
    for i in range(24):
        a = TAU * i / 24
        cr.move_to(57, 57)
        cr.arc(57, 57, 70, a, a + TAU / 48)
        cr.close_path()
        cr.set_source_rgba(0.23, 0.92, 0.42, 0.10 if i % 2 else 0.04)
        cr.fill()
    cr.restore()
    power_button(cr, 57, 57, 33, t, 'connected')
    # top gloss, classic prerendered icon style
    cr.save()
    rrect(cr, 0, 0, 114, 114, 20)
    cr.clip()
    cr.move_to(0, 0)
    cr.line_to(114, 0)
    cr.line_to(114, 40)
    cr.curve_to(80, 56, 34, 56, 0, 44)
    cr.close_path()
    cr.set_source(vgrad(0, 56, [(0, (1, 1, 1, 0.38)), (1, (1, 1, 1, 0.06))]))
    cr.fill()
    cr.restore()
    return s


def launch(w, h, scale):
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, w * scale, h * scale)
    cr = cairo.Context(s)
    cr.scale(scale, scale)
    brushed_metal(cr, 0, 0, w, h, DAY, seed=7)
    cr.new_path()
    for (x, y, a) in ((12, 12, 0.6), (w - 12, 12, 2.0), (12, h - 12, 1.1), (w - 12, h - 12, 0.3)):
        screw(cr, x, y, 4, DAY, a)
    engraved_text(cr, 'LegacyRay', w / 2, h * 0.46, 30, DAY, align='center', font='Liberation Serif')
    engraved_text(cr, 'FULL-DEVICE  VLESS  RECEIVER', w / 2, h * 0.46 + 22, 9, DAY, align='center',
                  spacing=1.8)
    return s


def flat_launch(w, h, scale):
    """ios 7 launch images: the flat shell the app opens into, as apple asks
    for, with the header under a transparent status bar"""
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
    # key click: a short noise burst through a resonance, like a hardware key
    click = []
    for i in range(int(rate * 0.018)):
        t = i / rate
        env = math.exp(-t * 380)
        click.append(env * (0.55 * (rnd.random() * 2 - 1) + 0.5 * math.sin(TAU * 2600 * t)))
    write_wav('click.wav', click)
    # power knob: a heavier latch, low thump plus a metallic tick
    clunk = []
    for i in range(int(rate * 0.09)):
        t = i / rate
        thump = math.exp(-t * 60) * math.sin(TAU * 110 * t) * 0.9
        tick = math.exp(-t * 500) * (rnd.random() * 2 - 1) * 0.6
        ring = math.exp(-t * 90) * math.sin(TAU * 1750 * t) * 0.15
        clunk.append(thump + tick + ring)
    write_wav('clunk.wav', clunk)
    # tuning detent
    tick = []
    for i in range(int(rate * 0.008)):
        t = i / rate
        tick.append(math.exp(-t * 700) * math.sin(TAU * 4200 * t) * 0.5)
    write_wav('tick.wav', tick)


def main():
    os.makedirs(OUT, exist_ok=True)
    icons = {
        'Icon.png': 57, 'Icon@2x.png': 114, 'Icon-72.png': 72, 'Icon-72@2x.png': 144,
        'Icon-60@2x.png': 120, 'Icon-76.png': 76, 'Icon-76@2x.png': 152,
        'Icon-Small.png': 29, 'Icon-Small@2x.png': 58, 'Icon-Small-50.png': 50,
        'Icon-Small-50@2x.png': 100,
    }
    for name, size in icons.items():
        icon(size).write_to_png(os.path.join(OUT, name))
    launches = [
        ('Default.png', 320, 480, 1), ('Default@2x.png', 320, 480, 2), ('Default-568h@2x.png', 320, 568, 2),
        ('Default-Portrait~ipad.png', 768, 1004, 1), ('Default-Portrait@2x~ipad.png', 768, 1004, 2),
        ('Default-Landscape~ipad.png', 1024, 748, 1), ('Default-Landscape@2x~ipad.png', 1024, 748, 2),
    ]
    for name, w, h, scale in launches:
        launch(w, h, scale).write_to_png(os.path.join(OUT, name))
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
