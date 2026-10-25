"""Round 61 story art drop 03: the two picked sprites (both P1). CC0-1.0.

GPT-6 Astra, 2026-10-25. Original, AI-assisted pixel art. Copied from the
drop's paint.py, trimmed to the user's picks (proposal P1): the storm
vessel, a squat smoked-clay crock holding one pale lightning tear under a
rope-bound cork on two low forked wooden feet, and the Runner's Packet's
16x16 inventory icon, a flat waxed-hide envelope with a triangular closing
flap and an offset carrying strap. Integer Pillow drawing only; no input
images, image models, random numbers, text drawing or antialiasing.
"""
from PIL import Image, ImageDraw

PAL = {
    'edge': '#242729', 'deep': '#342d2b',
    'clay_s': '#403836', 'clay': '#584b43', 'clay_l': '#796754',
    'storm_s': '#9baea6', 'storm': '#d3ded4', 'storm_l': '#f0efda',
    'wood': '#896643', 'wood_l': '#b28a55',
    'cork_s': '#806244', 'cork': '#b39768', 'cork_l': '#d6bd8a',
    'cord_s': '#8e7850', 'cord': '#cdbb89', 'cord_l': '#eee0b5',
    'hide_s': '#88613e', 'hide': '#b28d59', 'hide_l': '#d8b77b',
    'flax_l': '#e5d6aa',
    'strap_s': '#493b2f', 'strap': '#705139', 'strap_l': '#a47b49',
}


class Brush:
    def __init__(self, side=32):
        self.im = Image.new('RGBA', (side, side), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, box, c):
        self.d.rectangle(box, fill=PAL.get(c, c))

    def poly(self, points, c):
        self.d.polygon(points, fill=PAL.get(c, c))

    def line(self, points, c, width=1):
        self.d.line(points, fill=PAL.get(c, c), width=width)

    def dot(self, xy, c):
        self.d.point(xy, fill=PAL.get(c, c))


def clay_crock():
    b = Brush()
    # Two low forked supports; separated feet touch the bottom row.
    for x in (5, 23):
        b.rect((x, 23, x+3, 30), 'edge')
        b.rect((x+1, 24, x+2, 29), 'wood')
        b.line([(x+1, 24), (x+1, 28)], 'wood_l')
        b.rect((x-2, 30, x+5, 31), 'edge')
        b.line([(x-1, 30), (x+4, 30)], 'wood')
    # Broad smoked-clay body. Its round shoulders are unlike a framed pane.
    b.poly([(10, 10), (21, 10), (25, 12), (28, 16), (28, 23),
            (25, 27), (21, 29), (10, 29), (6, 27), (3, 23),
            (3, 16), (6, 12)], 'edge')
    b.poly([(10, 11), (21, 11), (25, 14), (27, 17), (27, 22),
            (24, 26), (20, 28), (11, 28), (7, 26), (4, 22),
            (4, 17), (7, 13)], 'clay_s')
    b.poly([(10, 12), (21, 12), (24, 15), (25, 20), (23, 25),
            (10, 26), (6, 22), (5, 17), (8, 13)], 'clay')
    b.line([(10, 12), (8, 13), (6, 16), (6, 20)], 'clay_l')
    b.line([(8, 24), (10, 25), (13, 26)], 'clay_l')
    # One large lightning tear, contained entirely inside the belly.
    b.poly([(15, 14), (21, 14), (18, 18), (22, 18),
            (15, 25), (16, 21), (11, 21)], 'storm_s')
    b.poly([(15, 14), (20, 14), (17, 18), (21, 18),
            (15, 24), (16, 20), (12, 20)], 'storm')
    b.poly([(15, 14), (19, 14), (16, 18), (19, 18),
            (16, 21), (17, 19), (13, 19)], 'storm_l')
    # Low front holder leaves the belly unobstructed.
    b.poly([(4, 25), (7, 25), (9, 28), (23, 28), (25, 25),
            (28, 25), (26, 30), (6, 30)], 'edge')
    b.line([(5, 26), (8, 29), (24, 29), (27, 26)], 'wood')
    b.line([(9, 29), (22, 29)], 'wood_l')
    # Rolled lip and an oversized pale fibre-bound cork.
    b.rect((9, 9, 22, 12), 'edge')
    b.rect((10, 10, 21, 11), 'clay')
    b.line([(10, 10), (15, 10)], 'clay_l')
    b.poly([(11, 2), (20, 2), (22, 4), (21, 9), (11, 9), (9, 5)], 'edge')
    b.poly([(11, 3), (19, 3), (21, 4), (20, 8), (12, 8), (10, 5)], 'cork_s')
    b.poly([(11, 3), (19, 3), (20, 4), (19, 7), (12, 7), (11, 5)], 'cork')
    b.line([(12, 3), (18, 3)], 'cork_l')
    b.line([(10, 6), (21, 6)], 'cord_s', 2)
    b.line([(11, 6), (20, 6)], 'cord')
    b.line([(15, 3), (15, 9)], 'cord_s', 2)
    b.line([(15, 3), (15, 8)], 'cord_l')
    b.rect((14, 6, 17, 9), 'deep')
    b.rect((14, 6, 16, 8), 'cord')
    b.dot((15, 6), 'cord_l')
    b.line([(17, 8), (19, 10), (22, 10)], 'cord')
    return b.im


def flat_envelope():
    b = Brush(16)
    # Short carrying loop above a wide, closed waxed-hide envelope.
    b.poly([(9, 1), (12, 1), (13, 3), (13, 6), (8, 6), (8, 3)], 'edge')
    b.line([(9, 4), (9, 2), (11, 2), (12, 4)], 'strap_l')
    b.rect((10, 3, 11, 4), (0, 0, 0, 0))
    b.poly([(2, 4), (13, 4), (14, 5), (14, 12), (13, 13),
            (2, 13), (1, 12), (1, 5)], 'edge')
    b.rect((2, 5, 13, 12), 'hide_s')
    b.rect((3, 6, 12, 11), 'hide')
    b.line([(2, 11), (5, 8)], 'hide_l')
    b.line([(2, 12), (9, 12)], 'hide_l')
    # Strong downward flap seam, without paper layers, seal or writing.
    b.poly([(2, 5), (13, 5), (8, 10), (6, 10)], 'strap_s')
    b.poly([(2, 5), (12, 5), (7, 9)], 'hide_l')
    b.line([(3, 5), (11, 5)], 'flax_l')
    # Offset broad strap preserves most of the triangular closing flap.
    b.rect((10, 4, 12, 13), 'strap_s')
    b.rect((10, 4, 11, 13), 'strap')
    b.line([(10, 5), (10, 12)], 'strap_l')
    return b.im
