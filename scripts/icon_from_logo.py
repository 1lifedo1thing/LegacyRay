#!/usr/bin/env python3
"""art/icon-1024.png from the logo (a 1024 px render of the badge on white):
the badge itself, cut along its own outer edge with its dark rim and its own
rounded corners, and transparent outside them. that is the icon as it was
drawn; ios masks it with a radius as large or larger, so the rim shows all
the way round on the home screen and the white page never does.
    python3 scripts/icon_from_logo.py logo.webp"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'art', 'icon-1024.png')

EDGE, FAR = 73, 951   # the badge's outer edge, rim included (73..950)
DARK = 90             # the rim is darker than this, the page and the shadow lighter


def badge_mask(im):
    """the badge's own silhouette, row by row: everything between the first
    and the last pixel of its dark rim. its corners are not circles, so a
    drawn shape would leave a light sliver where they flatten into the edge.
    the pixel just outside the rim keeps the coverage its brightness shows"""
    lum = im.convert('L')
    w, h = lum.size
    px = lum.load()
    mask = Image.new('L', (w, h), 0)
    out = mask.load()

    def coverage(x, y, step):
        # how much of the rim the pixel outside it holds, against the
        # background a little further out (white page, or the soft shadow)
        bg = px[min(max(x - step * 2, 0), w - 1), y]
        if bg <= DARK:
            return 0
        return max(0, min(255, int(round(255.0 * (bg - px[x, y]) / (bg - 30)))))

    for y in range(h):
        left = next((x for x in range(w) if px[x, y] < DARK), None)
        if left is None:
            continue
        right = next(x for x in range(w - 1, -1, -1) if px[x, y] < DARK)
        for x in range(left, right + 1):
            out[x, y] = 255
        if left > 0:
            out[left - 1, y] = coverage(left - 1, y, 1)
        if right < w - 1:
            out[right + 1, y] = coverage(right + 1, y, -1)
    return mask


def main(src):
    im = Image.open(src).convert('RGB').crop((EDGE, EDGE, FAR, FAR))
    rgba = im.convert('RGBA')
    rgba.putalpha(badge_mask(im))
    # resize premultiplied, or the white page bleeds into the rim's edge
    out = rgba.convert('RGBa').resize((1024, 1024), Image.LANCZOS).convert('RGBA')
    out.save(OUT)
    print('icon master written to', os.path.normpath(OUT))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'art', 'logo.png'))
