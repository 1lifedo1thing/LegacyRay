#!/usr/bin/env python3
"""art/icon-1024.png from the logo (a 1024 px render of the badge on white):
crops the square inside the badge's edge and fills the rounded corners, where
the white page showed, with cloth from a clean patch. ios masks the corners
anyway; this keeps a light fringe out of them.
    python3 scripts/icon_from_logo.py logo.webp"""
import math
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'art', 'icon-1024.png')


def main(src):
    im = Image.open(src).convert('RGB')
    edge, far = 78, 946                      # just inside the badge (73..950)
    side = far - edge
    sq = im.crop((edge, edge, far, far))
    px = sq.load()
    r = 147.0                                # the badge's corner radius, a hair in
    c = 150.0 - (edge - 73)
    patch = (110, 330, 140)                  # plain cloth: no stitch, no letter
    for cx in (c, side - 1 - c):
        for cy in (c, side - 1 - c):
            xs = range(0, int(c) + 1) if cx < side / 2 else range(int(cx), side)
            ys = range(0, int(c) + 1) if cy < side / 2 else range(int(cy), side)
            for y in ys:
                for x in xs:
                    if math.hypot(x - cx, y - cy) > r:
                        px[x, y] = px[patch[0] + x % patch[2], patch[1] + y % patch[2]]
    sq.resize((1024, 1024), Image.LANCZOS).save(OUT)
    print('icon master written to', os.path.normpath(OUT))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'art', 'logo.png'))
