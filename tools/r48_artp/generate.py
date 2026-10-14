#!/usr/bin/env python3
"""Round 48 ARTP: original, deterministic 16 x 16 pixel drafts.

Run: python3 tools/r48_artp/generate.py
Tool: Python 3 with installed Pillow 12.3.0. No network or external fonts.
The draft painters never open existing art. Sources are read only by previews.
Code: GPL-3.0-or-later. Original draft artwork: CC0-1.0, GPT-6 Astra.
"""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DATE = "2026-10-14"
CLEAR = (0, 0, 0, 0)
NEAREST = Image.Resampling.NEAREST
GREEN = ["30452b", "486435", "6d8842", "a3b85e"]
OLIVE = ["595b20", "90902e", "c1bf42", "d8d45b"]
WOOD = ["4c372c", "79563a", "af8853", "d5b67b"]


def color(value):
    return tuple(bytes.fromhex(value.lstrip("#"))) + (255,)


class Sprite:
    """Integer pixel geometry only: no filtering, antialiasing or resizing."""

    def __init__(self):
        self.im = Image.new("RGBA", (16, 16), CLEAR)
        self.d = ImageDraw.Draw(self.im)

    def p(self, x, y, c):
        assert 0 <= x < 16 and 0 <= y < 16, (x, y)
        self.im.putpixel((x, y), color(c))

    def line(self, points, c, width=1):
        self.d.line(points, fill=color(c), width=width)

    def poly(self, points, c):
        self.d.polygon(points, fill=color(c))

    def box(self, box, c):
        self.d.rectangle(box, fill=color(c))

    def oval(self, box, c):
        self.d.ellipse(box, fill=color(c))

    def stamp(self, x, y, rows, palette):
        for dy, row in enumerate(rows):
            for dx, char in enumerate(row):
                if char != ".":
                    self.p(x + dx, y + dy, palette[char])


def leaf(s, base, tip, width=2, pal=GREEN):
    """Pointed side-view blade, with a quiet central vein."""
    bx, by = base
    tx, ty = tip
    mx, my = (bx + tx) // 2, (by + ty) // 2
    if abs(tx - bx) >= abs(ty - by):
        points = [base, (mx, my - width), tip, (mx, my + 1)]
        light = [(bx, by - 1), (mx, my - width + 1), tip]
    else:
        points = [base, (mx - width, my), tip, (mx + 1, my)]
        light = [(bx - 1, by), (mx - width + 1, my), tip]
    s.poly(points, pal[1])
    s.line(light, pal[2])
    s.line([base, tip], pal[0])
    s.p(tx, ty, pal[2])


def hand_leaf(s, cx, cy, size=3, pal=GREEN):
    """Five narrow lobes; air gaps are part of the silhouette."""
    ends = [(cx-size, cy-1), (cx-size+1, cy-size), (cx, cy-size-1),
            (cx+size-1, cy-size), (cx+size, cy-1)]
    for n, end in enumerate(ends):
        s.line([(cx, cy), end], pal[1 if n % 2 else 2])
    s.p(cx, cy, pal[0])
    s.p(cx, cy-size, pal[3])


def cassava(variant, stage):
    s = Sprite()
    if variant == "A":
        top = [12, 9, 6, 5][stage-1]
        s.line([(8, 15), (8, top)], WOOD[0])
        s.line([(7, 15), (7, top)], WOOD[1])
        if stage > 1:
            s.p(7, 13, WOOD[2])
        hand_leaf(s, 7, top, 2 if stage < 3 else 3)
        if stage >= 3:
            s.line([(7, 11), (3, 10)], WOOD[1])
            hand_leaf(s, 3, 10, 2)
        if stage == 4:
            s.line([(8, 10), (12, 9)], WOOD[1])
            hand_leaf(s, 12, 9, 2)
            s.p(7, 9, WOOD[2])
    elif variant == "B":
        if stage == 1:
            s.line([(7, 15), (7, 13)], WOOD[1])
            hand_leaf(s, 7, 13, 2)
        else:
            fork = [0, 12, 11, 10][stage-1]
            s.line([(7, 15), (7, fork)], WOOD[0], 2)
            s.line([(6, 15), (6, fork+1)], WOOD[2])
            left = (4, fork-3)
            right = (11, fork-2)
            s.line([(7, fork), left], WOOD[1])
            s.line([(7, fork), right], WOOD[1])
            hand_leaf(s, *left, 2 if stage == 2 else 3)
            hand_leaf(s, *right, 2 if stage == 2 else 3)
            if stage == 4:
                s.line([(7, 10), (8, 5)], WOOD[1])
                hand_leaf(s, 8, 5, 2)
    else:
        stalks = [(7, 15, 6, [12, 10, 7, 5][stage-1])]
        if stage >= 2:
            stalks.append((8, 15, 11, [0, 12, 10, 8][stage-1]))
        if stage == 4:
            stalks.append((6, 15, 3, 11))
        for bx, by, tx, ty in stalks:
            s.line([(bx, by), (tx, ty)], WOOD[1])
            s.p(bx, by-1, WOOD[2])
            hand_leaf(s, tx, ty, 2 if stage < 3 else 3)
        if stage == 4:
            s.p(7, 11, WOOD[3])
    return s.im


def cassava_seed(variant):
    s = Sprite()
    if variant == "A":
        s.poly([(3, 12), (10, 3), (13, 4), (6, 14)], WOOD[0])
        s.line([(5, 12), (11, 4)], WOOD[1], 2)
        s.line([(4, 11), (10, 4)], WOOD[2])
        s.line([(6, 8), (8, 10)], WOOD[0])
        s.line([(9, 5), (11, 7)], WOOD[0])
        s.line([(10, 3), (12, 4)], WOOD[3])
        leaf(s, (8, 7), (4, 4), 1)
    elif variant == "B":
        for x, y in [(3, 4), (7, 3), (10, 5)]:
            s.poly([(x, y), (x+2, y), (x+1, 13), (x-1, 12)], WOOD[0])
            s.line([(x, y+1), (x, 11)], WOOD[2])
            s.line([(x, y), (x+1, y)], WOOD[3])
            s.p(x, y+4, WOOD[0])
        s.line([(3, 9), (11, 10)], "b3a47a")
        s.line([(3, 10), (11, 9)], "dfc591")
    else:
        s.line([(5, 13), (8, 7), (7, 3)], WOOD[0], 3)
        s.line([(8, 8), (12, 5)], WOOD[0], 3)
        s.line([(5, 12), (8, 6), (7, 3)], WOOD[2])
        s.line([(8, 8), (12, 5)], WOOD[1])
        s.p(7, 3, WOOD[3])
        s.p(12, 5, WOOD[3])
        s.p(6, 10, WOOD[0])
        leaf(s, (8, 7), (3, 5), 1)
    return s.im


ONION = ["82441e", "ca733d", "e29258", "ffb77f", "ffd4a0"]


def onion_bulb(s, x, y, w, h):
    s.oval((x, y, x+w-1, y+h-1), ONION[0])
    s.oval((x+1, y, x+w-2, y+h-2), ONION[2])
    if w > 4:
        s.line([(x+2, y+1), (x+1, y+h//2), (x+2, y+h-2)], ONION[3])
        s.line([(x+w-3, y+1), (x+w-2, y+h//2), (x+w-3, y+h-2)], ONION[1])
        s.line([(x+w//2, y+1), (x+w//2-1, y+h-3)], ONION[4])
    s.p(x+w//2, min(15, y+h), ONION[1])


def onion(variant, stage):
    s = Sprite()
    if variant == "A":
        neck = [15, 14, 12, 9][stage-1]
        tips = [[(5, 12), (10, 11)], [(3, 9), (7, 7), (11, 8)],
                [(2, 7), (5, 3), (9, 4), (13, 7)],
                [(2, 5), (5, 2), (9, 1), (13, 4)]][stage-1]
        for i, tip in enumerate(tips):
            s.line([(7+i%2, neck), ((tip[0]+7)//2, tip[1]+2), tip], GREEN[1+i%2])
        if stage >= 3:
            onion_bulb(s, 5 if stage == 3 else 4, neck, 6 if stage == 3 else 8, 3 if stage == 3 else 6)
            s.p(7, neck, ONION[1])
    elif variant == "B":
        for cx, delta in [(5, 0), (11, 1)][:1 if stage == 1 else 2]:
            neck = [15, 14, 12, 10][stage-1] + delta
            height = [3, 5, 7, 8][stage-1]
            s.line([(cx, neck), (cx-1, neck-height+1), (cx-3, neck-height)], GREEN[2])
            s.line([(cx, neck), (cx+2, neck-height), (cx+3, neck-height+2)], GREEN[1])
            if stage >= 3:
                onion_bulb(s, cx-2, neck, 5, 3 if stage == 3 else 4)
            if stage == 4:
                s.line([(cx, neck-1), (cx+1, neck-5)], GREEN[3])
    else:
        neck = [15, 14, 12, 9][stage-1]
        height = [3, 5, 8, 8][stage-1]
        s.line([(8, neck), (8, neck-height+1), (5, neck-height), (4, neck-height+2)], GREEN[2])
        s.line([(8, neck), (11, neck-height+3), (13, neck-height+4)], GREEN[1])
        if stage >= 2:
            s.line([(8, neck), (5, neck-4), (3, neck-3)], GREEN[1])
        if stage >= 3:
            onion_bulb(s, 6, neck, 5, 3 if stage == 3 else 6)
            s.line([(8, neck), (7, neck-2)], ONION[2])
    return s.im


def pumpkin_fruit(s, x, y, w, h):
    pal = ["733b1d", "aa541b", "d97c22", "efaa3e", "f5c165"]
    s.oval((x, y, x+w-1, y+h-1), pal[0])
    s.oval((x+1, y, x+w-2, y+h-2), pal[2])
    for rib in [x+w//3, x+2*w//3]:
        s.line([(rib, y+1), (rib-1, y+h//2), (rib, y+h-2)], pal[1])
        s.line([(rib+1, y+1), (rib, y+h//2), (rib+1, y+h-2)], pal[3])
    s.line([(x+2, y+2), (x+1, y+h//2)], pal[4])
    s.line([(x+w//2, y), (x+w//2, y-2)], OLIVE[0])
    s.p(x+w//2, y-2, OLIVE[2])


def pumpkin(variant):
    s = Sprite()
    if variant == "A":
        s.line([(2, 15), (3, 11), (8, 8), (10, 4)], OLIVE[1])
        leaf(s, (6, 9), (2, 5), 2, OLIVE)
        leaf(s, (10, 5), (13, 4), 1, OLIVE)
        pumpkin_fruit(s, 4, 8, 11, 7)
    elif variant == "B":
        s.line([(1, 14), (6, 11), (7, 5), (9, 3)], OLIVE[1])
        leaf(s, (7, 7), (3, 4), 2, OLIVE)
        leaf(s, (8, 6), (13, 5), 1, OLIVE)
        pumpkin_fruit(s, 8, 9, 7, 6)
        pumpkin_fruit(s, 1, 11, 7, 5)
    else:
        s.line([(1, 15), (3, 12), (5, 10), (5, 5), (8, 3)], OLIVE[1])
        leaf(s, (5, 8), (1, 5), 1, OLIVE)
        leaf(s, (5, 7), (9, 4), 2, OLIVE)
        pumpkin_fruit(s, 7, 5, 8, 10)
        s.line([(2, 14), (2, 12), (4, 12)], OLIVE[2])
    return s.im


MELON_PALETTES = {
    "A": ["665532", "9e8249", "c1a363", "e4ce8b", "f2dfaa"],
    "B": ["4c6240", "7e9558", "b9c983", "dfe5a5", "f1efc0"],
    "C": ["304a35", "4f7042", "7b984b", "b4bb65", "dce091"],
}


def melon_fruit(s, variant, x, y, w, h, young=False):
    pal = GREEN + ["bacd7b"] if young else MELON_PALETTES[variant]
    s.oval((x, y, x+w-1, y+h-1), pal[0])
    s.oval((x+1, y, x+w-2, y+h-2), pal[1])
    s.oval((x+1, y+1, x+w-3, max(y+1, y+h-3)), pal[2])
    if young:
        s.p(x+2, y+1, pal[3])
        return
    if variant == "A":
        # Broken diamond netting, confined to the fruit's original mask.
        for yy in range(y+1, y+h-1):
            for xx in range(x+1, x+w-1):
                if s.im.getpixel((xx, yy))[3] and (xx+yy) % 4 == 0:
                    s.p(xx, yy, pal[3])
                elif s.im.getpixel((xx, yy))[3] and (xx-yy) % 4 == 0:
                    s.p(xx, yy, pal[1])
        s.p(x+3, y+1, pal[4])
    elif variant == "B":
        # Long pale body with two shallow, horizontal seams.
        s.line([(x+2, y+2), (x+w-4, y+1), (x+w-2, y+2)], pal[3])
        s.line([(x+2, y+h-3), (x+w-3, y+h-2)], pal[1])
        s.line([(x+2, y+3), (x+w-4, y+3)], pal[4])
    else:
        # A narrow, pointed woodland-green fruit with interrupted gold stripes.
        for xx in range(x+2, x+w-2):
            yy = y+1+(xx % 3 == 0)
            s.p(xx, yy, pal[3])
            if xx % 3 != 1:
                s.p(xx, y+h-3, pal[2])
        s.p(x+3, y+2, pal[4])


def melon(variant, stage):
    s = Sprite()
    if stage == 1:
        bases = {"A": ((7, 15), (4, 12), (10, 11)),
                 "B": ((6, 15), (3, 12), (9, 12)),
                 "C": ((8, 15), (5, 12), (11, 12))}
        base, a, b = bases[variant]
        leaf(s, base, a, 1)
        leaf(s, base, b, 1)
        return s.im
    if variant == "A":
        s.line([(3, 15), (6, 12), (8, 9), (7, 6)], GREEN[1])
        leaf(s, (6, 12), (2, 9), 2)
        leaf(s, (8, 9), (12, 7), 2)
        if stage >= 3:
            leaf(s, (7, 7), (4, 4), 2)
            melon_fruit(s, variant, 7 if stage == 3 else 5,
                        12 if stage == 3 else 9, 6 if stage == 3 else 10,
                        4 if stage == 3 else 7, stage == 3)
    elif variant == "B":
        s.line([(2, 15), (3, 11), (6, 9), (10, 8)], GREEN[1])
        leaf(s, (4, 11), (2, 6), 2)
        leaf(s, (6, 9), (9, 5), 2)
        if stage >= 3:
            s.line([(10, 8), (12, 7), (13, 8)], GREEN[2])
            melon_fruit(s, variant, 5 if stage == 3 else 3,
                        12 if stage == 3 else 10, 8 if stage == 3 else 12,
                        4 if stage == 3 else 6, stage == 3)
    else:
        s.line([(2, 15), (5, 12), (9, 10), (12, 8)], GREEN[1])
        leaf(s, (5, 12), (2, 8), 1)
        leaf(s, (9, 10), (7, 6), 1)
        if stage >= 3:
            leaf(s, (12, 8), (14, 5), 1)
            melon_fruit(s, variant, 6 if stage == 3 else 2,
                        13 if stage == 3 else 10, 8 if stage == 3 else 13,
                        3 if stage == 3 else 6, stage == 3)
    return s.im


def melon_item(variant):
    s = Sprite()
    # No upright apple stem and no slice silhouette: all fruits lie lengthwise.
    if variant == "A":
        melon_fruit(s, variant, 2, 4, 13, 10)
        s.line([(2, 8), (1, 7), (2, 5)], WOOD[1])
    elif variant == "B":
        melon_fruit(s, variant, 1, 5, 14, 9)
        s.line([(1, 8), (1, 6), (3, 5)], GREEN[1])
    else:
        melon_fruit(s, variant, 1, 6, 14, 7)
        s.line([(2, 8), (1, 6), (3, 4)], GREEN[1])
        leaf(s, (3, 4), (6, 3), 1)
    return s.im


def melon_seed(variant):
    s = Sprite()
    pale = {"s": "8c693f", "m": "c4a467", "h": "eed69c", "l": "fff0c8"}
    if variant == "A":
        for x, y in [(3, 3), (9, 6), (3, 10)]:
            s.stamp(x, y, ["..h.", ".lhs", "hhms", ".ms."], pale)
    elif variant == "B":
        for x, y in [(3, 4), (8, 3), (5, 10), (11, 9)]:
            s.stamp(x, y, [".h.", "lhs", "hms", ".s."], pale)
    else:
        for x, y in [(3, 4), (9, 3), (6, 10)]:
            s.stamp(x, y, ["...h", "..hm", ".hms", "hms.", ".s.."], pale)
    return s.im


FUNGI = {
    "A": {"o": "6d6654", "s": "b0a68a", "m": "d5ccb0", "h": "f1ead0", "g": "8d8069", "w": "fff4d9"},
    "B": {"o": "72502c", "s": "ad7735", "m": "d7a64e", "h": "f1cc75", "g": "9a6c37", "w": "ffe2a0"},
    "C": {"o": "54465c", "s": "83728b", "m": "ab96b2", "h": "d1bed0", "g": "776779", "w": "eedbdf"},
}


def mushroom_shape(s, variant, stage):
    p = FUNGI[variant]
    if variant == "A":
        shapes = [
            (6, 12, [".ss.", "shms", ".mo.", ".go."]),
            (5, 9, ["..ss..", ".hhms.", "shmmms", ".goog.", "..mo..", "..mo..", ".gmo.."]),
            (3, 5, ["....ss....", "..shhhms..", ".shhmmmms.", "shmmmmmmms", ".ogogogoo.", "....ms....", "....ms....", "....ms....", "....ms....", "...smmg...", "...goo...."]),
            (1, 2, [".....sss......", "...shhhmms....", "..shhhmmmms...", ".shhmmmmmmms..", "shmmmmmmmmmms.", "ogogogogogogo.", ".....ms.......", ".....ms.......", ".....ms.......", ".....ms...ss..", ".....ms..shms.", ".....ms...mo..", "....smmg..mo..", "....gooo..go.."]),
        ]
    elif variant == "B":
        shapes = [
            (6, 12, ["s..s", "hmmh", ".ms.", ".go."]),
            (5, 9, ["s....s", "hh..hh", ".hmmh.", "..ms..", "..ms..", "..ms..", "..go.."]),
            (3, 5, ["ss......ss", "hhs....shh", ".hhmssmhh.", "..hmmmmh..", "...gmms...", "...gmms...", "....ms....", "....ms....", "....ms....", "...hms....", "...goo...."]),
            (1, 2, [".ss.......ss..", "shhs.....shhs.", ".hwmsoosmwh..", "..hmmmmmmh...", "...hgmgmh....", "....hmms.....", "....gmms.....", ".....ms......", ".....ms..s..s", ".....ms..hmmh", ".....ms...ms.", "....hms...ms.", "...hmms...ms.", "...gooo...go."]),
        ]
    else:
        shapes = [
            (6, 12, [".ss.", "shms", "omso", ".go."]),
            (5, 9, ["..ss..", ".shms.", "shmmms", "omsmso", "..hs..", "..hs..", "..go.."]),
            (3, 5, ["...ss.....", "..shms....", ".shmmms...", "shmmmmms..", "ogmsgmso..", "...hs.....", "...hs..ss.", "...hs.shms", "...hs..hs.", "...hs..hs.", "...go..go."]),
            (1, 2, ["....ss........", "...shms.......", "..shmmms......", ".shmmmmms.....", ".hmmmmmmms....", "ogmsgmsgmso...", "....hs........", "....hs....ss..", "....hs...shms.", "....hs..shmmms", "....hs..ogmgso", "....hs....hs..", "....hs....hs..", "...smo....go.."]),
        ]
    x, y, rows = shapes[stage-1]
    s.stamp(x, y, rows, p)


def mushroom(variant, stage):
    s = Sprite()
    mushroom_shape(s, variant, stage)
    return s.im


def mushroom_item(variant):
    s = Sprite()
    p = FUNGI[variant]
    if variant == "A":
        s.stamp(1, 2, [".....ss.......", "...shhhms.....", "..shhhmmms....", ".shmmmmmmms...", "shmmmmmmmmms..", "ogogogogogogo.", ".....ms.......", ".....ms.......", ".....ms.......", ".....ms.......", "....hmms......", "....gmmo......", ".....oo......."], p)
    elif variant == "B":
        s.stamp(1, 2, [".ss.......ss..", "shhs.....shhs.", ".hwmsoosmwh..", "..hmmmmmmh...", "...hgmgmh....", "....hmms.....", "....gmms.....", ".....ms......", ".....ms......", "....hms......", "...hmms......", "..hmms.......", "..goo........"], p)
    else:
        s.stamp(2, 1, ["....ss.......", "...shms......", "..shmmms.....", ".shmmmmms....", "shmmmmmmms...", "ogmsgmsgmso..", "....hs.......", "....hs.......", "....hs..ss...", "....hs.shms..", "....hs.ogmso.", "....hs..hs...", "...hms..hs...", "...goo..go..."], p)
    return s.im


def spores(variant):
    s = Sprite()
    p = FUNGI[variant]
    if variant == "A":
        # A radial underside print, with loose pale spore dust below.
        s.oval((3, 2, 12, 9), p["o"])
        s.oval((4, 2, 11, 8), p["m"])
        for end in [(4, 3), (7, 2), (10, 3), (12, 5), (11, 8), (7, 9), (3, 6)]:
            s.line([(7, 5), end], p["g"])
        s.p(7, 5, p["h"])
        for x, y in [(3, 11), (7, 12), (11, 11), (5, 14), (10, 14)]:
            s.p(x, y, p["h"])
            s.p(x+1, y, p["s"])
    elif variant == "B":
        # A folded gill fan shedding a small golden powder heap.
        s.stamp(3, 2, ["s......s", "hhs..shh", ".hmmmmm.", "..gmgm..", "...ms..."], p)
        for x, y in [(4, 8), (9, 8), (7, 10), (11, 10)]:
            s.p(x, y, p["h"])
        s.stamp(3, 12, ["....h....", "..hmmhs..", "shmmmmmos"], p)
    else:
        # Loose lilac spore powder; no seed-shaped kernels or leaf silhouette.
        s.stamp(2, 10, ["....h.......", "...hms.hh...", ".hhmmmhmmh..", "shmmmmmmmmms", ".gmgmggmggo."], p)
        for x, y in [(3, 5), (8, 3), (12, 6), (6, 7), (10, 9)]:
            s.p(x, y, p["h"])
            s.p(x, y+1, p["s"])
    return s.im


SUN = ["5c602d", "94943f", "c9bc53", "f0d778"]


def sunleaf(variant, item=False):
    s = Sprite()
    if variant == "A":
        base = (7, 12 if item else 13)
        s.line([(7, 14 if item else 15), (7, 7)], GREEN[1])
        for tip in [(3, 7), (6, 3), (10, 4), (13, 9)]:
            leaf(s, base, tip, 2, SUN)
        leaf(s, base, (2, 11), 1, GREEN)
        s.p(7, 10, SUN[3])
        s.p(8, 7, SUN[3])
    elif variant == "B":
        s.line([(5, 14 if item else 15), (7, 10), (8, 6), (10, 2)], GREEN[0])
        for base, tip in [((6, 12), (2, 9)), ((7, 10), (12, 9)),
                          ((8, 7), (4, 5)), ((9, 5), (13, 3))]:
            leaf(s, base, tip, 2, SUN)
        s.p(10, 2, SUN[2])
        s.p(4, 8, SUN[3])
        s.p(10, 8, SUN[3])
    else:
        # Three wide, serrated blades make a fan, never a grass tuft.
        s.stamp(1, 2 if item else 3, [
            "......h.......",
            ".....hmh......",
            "...h.hmmh.....",
            "..hmhmsmh..h..",
            ".hmmmsmsh.hmh.",
            ".omsmsms.hmmh.",
            "..hmsmmsomms..",
            "..omssmsmms...",
            "...omsmsms....",
            "....omoms.....",
            ".....ooo......",
            "......o.......",
            "......o.......",
        ], dict(zip("osmh", SUN)))
    return s.im


MOSS = {"o": "35453c", "s": "52675b", "m": "7c9380", "h": "acb7a0",
        "t": "766952", "c": "b4a386"}


def gravemoss(variant, item=False):
    s = Sprite()
    if variant == "A":
        # Low moss stars and sparse capsules: neither round lettuce nor fern.
        ox, oy = (1, 6) if item else (1, 8)
        rows = ["....c.....c...", "....t.....t...", "..h.t.h...t.h.",
                ".hmh.shh..hms.", "hsms.hms.hsmo.", ".mohmsmshmso..",
                "hmsmomsomsmsh.", ".osoomosmsoo.."]
        s.stamp(ox, oy, rows, MOSS)
    elif variant == "B":
        if item:
            rows = ["..shs....sh...", ".shmms..hms...", "..msmshmmo....",
                    "..sommsms.....", ".msmmsmso.....", "..msmsms......",
                    "..sosmsmsh....", "...msm.smo....", "...so..ms.....",
                    "....s..o......", ".......s......"]
            s.stamp(2, 2, rows, MOSS)
        else:
            s.line([(5, 15), (6, 10), (5, 7), (2, 6)], WOOD[0], 2)
            s.line([(6, 10), (10, 6), (13, 7)], WOOD[1])
            s.stamp(1, 5, [".shs....shss..", "shmmh..hmmsmh.", ".msmshmmsmso..",
                          ".sommsms.ms...", ".msmsmso.so...", "..msmsms..s...",
                          "..so.msms.....", "...s..ms......", "......so......", ".......s......"], MOSS)
    else:
        s.stamp(1, 4 if item else 6, [
            "...h......h...",
            ".h.ms...h.ms..",
            "..hms.h.mhms..",
            "...mshm..ms.h.",
            "h.hsmms.hmsms.",
            ".hmmsmsmmsms..",
            "..smmssmsmso..",
            ".hmssmsmsmshs.",
            "..osoossooso..",
            "...o..o..o....",
        ], MOSS)
    return s.im


COCOA = {
    "A": ["6b4223", "a56829", "cf943b", "ecc268"],
    "B": ["60372f", "964f38", "c37b4b", "e1a96b"],
    "C": ["4e3944", "7e5060", "ab7580", "d39d94"],
}
JUNGLE = ["2b4634", "426346", "67865b", "91a572"]


def cocoa_pod(s, variant, x, y, w, h):
    pal = COCOA[variant]
    cx = x+w//2
    s.poly([(cx, y), (x+w-2, y+1), (x+w-1, y+h//2),
            (x+w-2, y+h-2), (cx, y+h-1), (x+1, y+h-2),
            (x, y+h//2), (x+1, y+1)], pal[0])
    s.poly([(cx, y+1), (x+w-2, y+h//2), (cx, y+h-2),
            (x+1, y+h//2)], pal[1])
    s.line([(cx, y+1), (cx-1, y+h//2), (cx, y+h-2)], pal[3])
    if w >= 5:
        s.line([(cx+1, y+2), (cx+1, y+h-3)], pal[2])
        s.p(x+1, y+h//2, pal[2])


def wild_cocoa(variant, item=False):
    s = Sprite()
    if item:
        if variant == "A":
            s.line([(8, 3), (9, 1)], WOOD[1])
            cocoa_pod(s, variant, 3, 3, 10, 12)
        elif variant == "B":
            s.line([(5, 4), (7, 1), (11, 5)], WOOD[1])
            cocoa_pod(s, variant, 1, 4, 8, 10)
            cocoa_pod(s, variant, 8, 6, 7, 9)
        else:
            # Open pod with cream pulp, and two loose dark beans.
            cocoa_pod(s, variant, 2, 1, 9, 14)
            s.poly([(6, 3), (9, 6), (9, 10), (6, 13), (4, 10), (4, 6)], "d9c3a0")
            for x, y in [(5, 4), (7, 6), (5, 8), (7, 10)]:
                s.box((x, y, x+1, y+1), "f1e4c3")
                s.p(x, y+2, "af9678")
            s.stamp(11, 10, [".ss.", "smms", ".so.", "....", "smso"],
                    {"s": "57392e", "m": "a17a50", "o": "382c27"})
        return s.im
    if variant == "A":
        s.line([(8, 15), (8, 8), (7, 3)], WOOD[0], 2)
        s.line([(7, 15), (7, 8), (6, 4)], WOOD[2])
        leaf(s, (7, 4), (1, 2), 2, JUNGLE)
        leaf(s, (7, 4), (13, 1), 2, JUNGLE)
        leaf(s, (8, 6), (14, 5), 2, JUNGLE)
        cocoa_pod(s, variant, 3, 7, 5, 8)
        cocoa_pod(s, variant, 9, 7, 5, 7)
    elif variant == "B":
        s.line([(5, 15), (6, 8), (10, 3)], WOOD[0], 2)
        s.line([(5, 14), (6, 8), (10, 3)], WOOD[1])
        leaf(s, (9, 4), (3, 2), 2, JUNGLE)
        leaf(s, (10, 4), (14, 2), 2, JUNGLE)
        leaf(s, (6, 8), (1, 6), 2, JUNGLE)
        s.line([(9, 5), (12, 6)], WOOD[1])
        cocoa_pod(s, variant, 8, 6, 7, 9)
        cocoa_pod(s, variant, 2, 10, 5, 6)
    else:
        s.line([(4, 15), (5, 9), (9, 6), (13, 6)], WOOD[0], 2)
        s.line([(4, 14), (5, 9), (9, 6)], WOOD[2])
        leaf(s, (6, 8), (1, 4), 2, JUNGLE)
        leaf(s, (9, 6), (10, 1), 2, JUNGLE)
        leaf(s, (11, 6), (15, 3), 2, JUNGLE)
        cocoa_pod(s, variant, 6, 8, 9, 8)
    return s.im


def salt_pan(variant):
    s = Sprite()
    p = {"o": "41372f", "s": "65503e", "m": "8a7052", "h": "b19a75",
         "b": "647b83", "w": "9caeae", "c": "c8d0c9", "l": "f1eee0"}
    if variant == "A":
        s.stamp(1, 5, [
            "..hhhhhhhhhh..",
            ".hbbbbbbbbbbm.",
            "hbcccllcccbbbm",
            "mbcllllllccbbm",
            "mbccllcllcccwm",
            "mbwcccccccwbbm",
            ".hmmmmmmmmmmm.",
            ".msssssssssss.",
            "..oooooooooo..",
        ], p)
    elif variant == "B":
        s.stamp(0, 5, [
            ".....hhhhhh.....",
            "...hhbbbbbbmm...",
            ".ohbcclllccbbmo.",
            "hombcllllllcbsom",
            "osmbcccllcccbsso",
            "..hmbwcccwbbsm..",
            "...hmmmmmmmms...",
            "....ssssssss....",
            ".....oooooo.....",
        ], p)
    else:
        s.stamp(1, 3, [
            "......hh......",
            "....hhbbmm....",
            "..hhbcccbbmm..",
            ".hbccclllcbbm.",
            "hbclllllllcbbm",
            "mbwcclllccwbbm",
            ".mmbwcccwbbms.",
            "..mmbwbbbmmso.",
            "...mmmwmmss...",
            "....hmmmsso...",
            ".....msso.....",
            "......oo......",
        ], p)
    return s.im


IDEAS = {
    "cassava": [
        "One woody trunk with a high crown of five-fingered leaves; one budded stem cutting.",
        "A low forked shrub with two spreading leaf crowns; a tied bundle of stem cuttings.",
        "Three splayed woody canes with narrow hand-shaped leaves; a forked sprouting cutting.",
    ],
    "wild_onion": [
        "One broad golden bulb with a straight fan of green tubular leaves.",
        "Two small cream-gold bulbs with long arching leaves at different heights.",
        "One slender golden bulb with a long neck and curling, bent leaves.",
    ],
    "pumpkin": [
        "One squat, wide, deeply ribbed orange fruit below an olive vine.",
        "Two small ribbed pumpkins of unequal size on a branching vine.",
        "One tall oval pumpkin with pronounced ribs and a trailing side vine.",
    ],
    "melon": [
        "A broad tan oval melon with broken diamond netting; three broad pale seeds.",
        "A long pale honeydew with shallow lengthwise seams; four narrow ivory seeds.",
        "A narrow green melon with tapered ends and broken golden stripes; pointed seeds.",
    ],
    "mushroom": [
        "An ivory parasol with visible gills and a smaller pin; a radial spore print.",
        "An ochre trumpet with a flared rim and narrowing stem; a gill fan shedding spores.",
        "Two lilac bell caps on pale stems; loose lilac spore powder.",
    ],
    "sunleaf": [
        "A low rosette of broad golden leaves with a green basal leaf.",
        "A curved spice sprig with separate pairs of oval golden leaves.",
        "An upright fan of three broad serrated leaves with pale gold veins.",
    ],
    "gravemoss": [
        "A low grey-green star-moss mat with sparse dry spore capsules.",
        "Pale string moss draped over a dark twig; a gathered hanging tuft as the item.",
        "A creeping silver-green mat of small antler-shaped branching fronds.",
    ],
    "wild_cocoa": [
        "A stout stem bearing long golden ribbed pods; one whole pod as the item.",
        "An arching branch with unequal russet pods; a hanging pod pair as the item.",
        "A low spreading branch bearing a broad plum pod; an opened pod with pulp and beans.",
    ],
    "salt_pan": [
        "A shallow rectangular metal tray with chamfered corners and a salt bed.",
        "A shallow oval metal pan with two small side lugs and pooled brine around the salt.",
        "A square metal tray seen corner-first, with a folded rim around crystalline salt.",
    ],
}
TITLES = {key: key.replace("_", " ").title() for key in IDEAS}
FARM = "mods/ITEMS/grug_farming/textures/"
COOK = "mods/ITEMS/grug_cooking/textures/"
BASE = "mods/BASE/default/textures/"


def view(path, label, tint=None, frame=None):
    row = {"path": path, "label": label}
    if tint:
        row["modifier"] = f"^[colorize:#{tint[0]}:{tint[1]}"
    if frame is not None:
        row["frame"] = frame
    return row


def stage_views(key, frames=False):
    return [view(FARM+f"grug_farming_{key}_{n}.png", str(n), frame=0 if frames else None)
            for n in range(1, 5)]


CURRENT = {
    "cassava": stage_views("cassava") + [view(FARM+"grug_farming_seed_potato.png", "seed", ("d8b27a", 32))],
    "wild_onion": stage_views("wild_onion"),
    "pumpkin": stage_views("pumpkin"),
    "melon": [view(BASE+"default_apple.png", role, ("61a94e", 95)) for role in ["world", "item"]],
    "mushroom": [view(BASE+"default_pine_bush_sapling.png", role, ("9b7653", 150)) for role in ["world", "item"]],
    "sunleaf": [view(BASE+"default_grass_3.png", role, ("e5d34a", 105)) for role in ["world", "item"]],
    "gravemoss": [view(BASE+"default_fern_1.png", role, ("526c45", 100)) for role in ["world", "item"]],
    "wild_cocoa": [view(BASE+"default_pine_bush_sapling.png", role, ("70452d", 175)) for role in ["world", "item"]],
    "salt_pan": stage_views("salt_crust", frames=True),
}
NEIGHBORS = {
    "cassava": [view(FARM+f"grug_farming_potato_{n}.png", f"potato {n}") for n in range(1, 5)]
               + [view(FARM+"grug_farming_seed_potato.png", "seed")],
    "wild_onion": [view(COOK+"grug_cooking_wild_onion.png", "harvest")],
    "pumpkin": [view(FARM+f"grug_farming_pumpkin_{n}.png", f"stage {n}") for n in range(1, 4)]
               + [view(COOK+"grug_cooking_pumpkin.png", "harvest")],
    "melon": [view(COOK+"grug_cooking_frost_melon.png", "frost item"),
              view(FARM+"grug_farming_frost_melon_4.png", "frost 4"),
              view(COOK+"grug_cooking_pumpkin.png", "pumpkin"),
              view(FARM+"grug_farming_pumpkin_4.png", "pumpkin 4"),
              view(BASE+"default_apple.png", "apple")],
    "mushroom": [view(FARM+f"grug_farming_cave_cap_{n}.png", f"cave {n}") for n in range(1, 5)]
                + [view(COOK+"grug_cooking_cave_cap.png", "cave item")],
    "sunleaf": [view(BASE+f"default_grass_{n}.png", f"grass {n}") for n in [1, 3, 5]],
    "gravemoss": [view(BASE+"default_fern_1.png", "fern")],
    "wild_cocoa": [view(BASE+"default_pine_bush_sapling.png", "sapling")],
    "salt_pan": [view(FARM+"grug_farming_salt_crust_4.png", "full top", frame=0),
                 view(FARM+"grug_farming_salt_crust_4_side.png", "rim"),
                 view(COOK+"grug_cooking_salt_crust.png", "salt")],
}


def build_drafts():
    """A separate pure drawing pass: no read of shipped pixels."""
    entries, images = [], {}
    for item in IDEAS:
        for n, variant in enumerate("ABC"):
            files, roles = [], []

            def add(name, im, role):
                path = f"tools/r48_artp/drafts/{item}/{variant}/{name}.png"
                assert im.mode == "RGBA" and im.size == (16, 16), path
                assert set(im.getchannel("A").tobytes()) == {0, 255}, path
                files.append(path)
                roles.append(role)
                images[path] = im

            if item in ["cassava", "wild_onion", "melon", "mushroom"]:
                painter = {"cassava": cassava, "wild_onion": onion,
                           "melon": melon, "mushroom": mushroom}[item]
                for stage in range(1, 5):
                    add(f"grug_farming_{item}_{stage}", painter(variant, stage), str(stage))
            if item == "cassava":
                add("grug_farming_seed_cassava", cassava_seed(variant), "cutting")
            elif item == "pumpkin":
                add("grug_farming_pumpkin_4", pumpkin(variant), "4")
            elif item == "melon":
                add("grug_farming_melon_seeds", melon_seed(variant), "seed")
                add("grug_gathering_melon", melon_item(variant), "item")
            elif item == "mushroom":
                add("grug_farming_mushroom_spores", spores(variant), "spores")
                add("grug_gathering_mushroom", mushroom_item(variant), "item")
            elif item in ["sunleaf", "gravemoss", "wild_cocoa"]:
                painter = {"sunleaf": sunleaf, "gravemoss": gravemoss, "wild_cocoa": wild_cocoa}[item]
                add(f"grug_gathering_{item}_plant", painter(variant, False), "world")
                add(f"grug_gathering_{item}", painter(variant, True), "item")
            elif item == "salt_pan":
                add("grug_farming_salt_pan", salt_pan(variant), "item")
            entries.append({"item": item, "draft": variant, "files": files,
                            "idea": IDEAS[item][n], "roles": roles})
    return entries, images


def source_image(spec):
    with Image.open(ROOT / spec["path"]) as src:
        im = src.convert("RGBA")
    if "frame" in spec:
        y = spec["frame"] * 16
        im = im.crop((0, y, 16, y+16))
    assert im.size == (16, 16), spec
    if "modifier" in spec:
        _, rgb, strength = spec["modifier"].split(":")
        strength = int(strength)
        target = color(rgb)
        # Luanti apply_colorize / SColor::getInterpolated: nearest-integer blend
        # of all RGBA channels for nontransparent pixels. All inputs use binary
        # alpha, which is preserved. This is only a reference-preview operation.
        im.putdata([tuple((a*(255-strength) + b*strength + 127)//255
                         for a, b in zip(pixel, target)) if pixel[3] else pixel
                    for pixel in im.get_flattened_data()])
    return im


# Original small label alphabet; no external font pixels in the comparison.
FONT = {
    "A": ["01110", "10001", "11111", "10001", "10001"],
    "B": ["11110", "10001", "11110", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "01111"],
    "D": ["11110", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "11110", "10000", "11111"],
    "F": ["11111", "10000", "11110", "10000", "10000"],
    "G": ["01111", "10000", "10111", "10001", "01111"],
    "H": ["10001", "10001", "11111", "10001", "10001"],
    "I": ["111", "010", "010", "010", "111"],
    "J": ["00111", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "11100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001"],
    "O": ["01110", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "11110", "10000", "10000"],
    "Q": ["01110", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "11110", "10010", "10001"],
    "S": ["01111", "10000", "01110", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10101", "11011", "10001"],
    "X": ["10001", "01010", "00100", "01010", "10001"],
    "Y": ["10001", "01010", "00100", "00100", "00100"],
    "Z": ["11111", "00010", "00100", "01000", "11111"],
    "0": ["01110", "10011", "10101", "11001", "01110"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["11110", "00001", "01110", "10000", "11111"],
    "3": ["11110", "00001", "01110", "00001", "11110"],
    "4": ["10010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "11110"],
    "6": ["01111", "10000", "11110", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "00100"],
    "8": ["01110", "10001", "01110", "10001", "01110"],
    "9": ["01110", "10001", "01111", "00001", "11110"],
    "/": ["00001", "00010", "00100", "01000", "10000"],
    "-": ["000", "000", "111", "000", "000"],
    ".": ["0", "0", "0", "0", "1"],
    ":": ["0", "1", "0", "1", "0"],
    " ": ["000", "000", "000", "000", "000"],
}


def label(im, xy, words, ink, scale=1):
    d = ImageDraw.Draw(im)
    x, y = xy
    for char in words.upper():
        glyph = FONT[char]
        for dy, row in enumerate(glyph):
            for dx, bit in enumerate(row):
                if bit == "1":
                    xx, yy = x+dx*scale, y+dy*scale
                    d.rectangle((xx, yy, xx+scale-1, yy+scale-1), fill=color(ink))
        x += (len(glyph[0])+1)*scale


GROUNDS = [("light", "e6e2d5", "3c433b"), ("dark", "202927", "dadccb"),
           ("soil", "70513d", "f4e6cd")]


def preview(item, entries, images):
    choices = [entry for entry in entries if entry["item"] == item]
    panels = [("CURRENT", [(source_image(s), s["label"]) for s in CURRENT[item]])]
    for entry in choices:
        tiles = [(images[path], role) for path, role in zip(entry["files"], entry["roles"])]
        if item == "pumpkin":
            tiles = [(source_image(s), s["label"]+" kept") for s in CURRENT[item][:3]] + tiles
        panels.append((entry["draft"], tiles))
    cols = max(len(tiles) for _, tiles in panels)
    cw = max(256, 40+cols*76)
    width, height = 4*cw, 770
    out = Image.new("RGBA", (width, height), color("202927"))
    d = ImageDraw.Draw(out)
    label(out, (20, 15), "GRUDGELANDS / "+TITLES[item], "f1e9d1", 2)
    label(out, (20, 37), "R48 ARTP / DRAFTS / 16 X 16 / NEAREST NEIGHBOUR / RAW TILES", "b7c2ac")

    def tiles_at(tiles, x, y, panel_width, ink):
        step = min(76, (panel_width-32)//len(tiles))
        start = x + (panel_width-step*len(tiles))//2
        label(out, (x+9, y+12), "1X", ink)
        label(out, (x+9, y+62), "4X", ink)
        for n, (tile, title) in enumerate(tiles):
            cx = start + n*step + step//2
            out.alpha_composite(tile, (cx-8, y+6))
            out.alpha_composite(tile.resize((64, 64), NEAREST), (cx-32, y+36))
            label(out, (cx-28, y+110), title, ink)

    for row, (ground, bg, ink) in enumerate(GROUNDS):
        y = 58 + row*164
        for col, (name, tiles) in enumerate(panels):
            x = col*cw
            d.rectangle((x+2, y, x+cw-3, y+159), fill=color(bg))
            label(out, (x+12, y+12), name+" / "+ground, ink, 2)
            tiles_at(tiles, x, y+32, cw, ink)
    label(out, (20, 566), "NEIGHBOURS / EXISTING ART / SAME SCALES", "d6dfc9", 2)
    neighbors = [(source_image(s), s["label"]) for s in NEIGHBORS[item]]
    # A single final row, with the same neighbours repeated on each ground.
    nw = width//3
    for n, (ground, bg, ink) in enumerate(GROUNDS):
        x = n*nw
        d.rectangle((x+2, 592, x+nw-3, 742), fill=color(bg))
        label(out, (x+12, 604), ground, ink)
        tiles_at(neighbors, x, 622, nw, ink)
    notes = {
        "pumpkin": "STAGES 1-3 KEPT IN EACH COLUMN. ONLY STAGE 4 IS A DRAFT.",
        "salt_pan": "CURRENT: BASIN TOPS / FIRST ANIMATION FRAME. NO SALT PAN ITEM EXISTS TODAY.",
        "melon": "CURRENT: ONE TINTED IMAGE FOR WORLD AND ITEM. NO CROP STAGES TODAY.",
        "mushroom": "CURRENT: ONE TINTED IMAGE FOR WORLD AND ITEM. NO CROP STAGES TODAY.",
    }
    label(out, (20, 756), notes.get(item, "CURRENT COLOUR MODIFIERS INCLUDED. NEW ART IS UNLIT AND UNFILTERED."), "c9cebc")
    return out


def manifest(entries, previews):
    source_paths = sorted({s["path"] for rows in [*CURRENT.values(), *NEIGHBORS.values()] for s in rows})
    return {
        "schema": 1, "date": DATE, "author": "GPT-6 Astra",
        "path_base": "repository root", "draft_license": "CC0-1.0",
        "draft_size": [16, 16], "draft_mode": "RGBA",
        "stage_order": [1, 2, 3, 4], "picked": False,
        "items": [{"item": key, "current": list(dict.fromkeys(s["path"] for s in CURRENT[key])),
                   "current_views": CURRENT[key], "neighbors": NEIGHBORS[key],
                   "preview": f"tools/r48_artp/previews/{key}.png"} for key in IDEAS],
        "drafts": entries,
        "previews": [{"path": path, "size": list(im.size), "mode": im.mode,
                      "scales": [1, 4], "grounds": [g[0] for g in GROUNDS]} for path, im in previews.items()],
        "reference_sha256": {path: hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in source_paths},
    }


def reference_credit(path):
    """Provenance of comparison-only inputs, from the repository's ledgers."""
    name = Path(path).name
    if path.startswith(BASE):
        author = {"default_apple.png": "celeron55 (Perttu Ahola)",
                  "default_fern_1.png": "Mossmanikin",
                  "default_pine_bush_sapling.png": "paramat"}.get(name, "Gambit")
        url = "https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/"+name
        return author, "CC BY-SA 3.0 Unported", url
    if "cave_cap" in name:
        if path.startswith(COOK):
            original = "goblins_mushroom_brown.png"
        else:
            stage = name.removesuffix(".png").split("_")[-1]
            original = "goblins_mushroom_brown"+("" if stage == "1" else stage)+".png"
        return "Francisco Athens", "CC BY-SA 3.0 Unported", "https://gitlab.com/freelikegnu/goblins/-/blob/ce27b15f87452c9614b515b8a9b53af5d0e8e276/textures/"+original
    if name == "grug_cooking_wild_onion.png":
        return "Oz-tal", "CC BY-SA 3.0 Unported", "https://codeberg.org/tenplus1/farming/src/commit/1a918c7ae3778c3406ad91de6b83a174facad8f0/textures/crops_onion.png"
    exact = {
        "grug_farming_seed_potato.png": "x_farming_potato_seed.png",
        "grug_cooking_pumpkin.png": "x_farming_pumpkin_mash.png",
        "grug_cooking_frost_melon.png": "x_farming_melon.png",
        "grug_cooking_salt_crust.png": "x_farming_salt.png",
        "grug_farming_salt_crust_4_side.png": "x_farming_salt_3_side.png",
    }
    original = exact.get(name)
    if original is None:
        family, stage = name.removeprefix("grug_farming_").removesuffix(".png").rsplit("_", 1)
        if family == "salt_crust":
            original = f"x_farming_salt_{stage}_top.png"
        else:
            source_family = {"cassava": "potato", "potato": "potato", "wild_onion": "beetroot",
                             "pumpkin": "pumpkin", "frost_melon": "melon"}[family]
            source_stage = ([1, 3, 6, 8] if source_family == "potato" else [1, 3, 5, 8])[int(stage)-1]
            original = f"x_farming_{source_family}_{source_stage}.png"
    return "SaKeL", "CC BY-SA 4.0 International", "https://bitbucket.org/minetest_gamers/x_farming/src/ac5f69d5103d4af841b1a5ed3a0b49a4e19d0c84/textures/"+original


def ledger(images, previews, data):
    rows = [
        "# Round 48 ARTP — media ledger", "",
        "Generated by `python3 tools/r48_artp/generate.py`.", "",
        "## Original draft sprites", "",
        "All 87 draft sprites are original pixel art made by **GPT-6 Astra**,",
        f"**{DATE}**, on blank transparent canvases. The project dedicates any",
        "rights it holds in them to **CC0 1.0 Universal (CC0-1.0)**:",
        "<https://creativecommons.org/publicdomain/zero/1.0/>.",
        "No downloaded assets, traced silhouettes or existing texture pixels",
        "are used in these files. The source of every new pixel is",
        "[generate.py](generate.py), including its palettes and shape definitions.",
        "The generator's code follows the repository's GPL-3.0-or-later licence.", "",
        "| File | Author | Date | Licence | Source / treatment |",
        "| --- | --- | --- | --- | --- |",
    ]
    for path in images:
        rel = str(Path(path).relative_to("tools/r48_artp"))
        rows.append(f"| `{rel}` | GPT-6 Astra | {DATE} | CC0-1.0 | [generate.py](generate.py); original pixel art |")
    rows += ["", "## Comparison sheets", "",
             "The separately supplied draft PNGs above remain CC0-1.0. The sheets",
             "below also contain existing art from the repository. They cannot be",
             "relabeled entirely CC0: source tiles retain their original licences.",
             "The new art, layout and original label font contributed to each sheet",
             "are additionally offered under the sheet's listed licence. Modifications",
             "are nearest-neighbour enlargement, compositing on plain grounds, labels,",
             "the recorded runtime colour modifiers and the first-frame crops of salt",
             "animations. No source pixels enter the draft outputs.", "",
             "| File | Author / existing contributors | Date | Sheet licence | Source / treatment |",
             "| --- | --- | --- | --- | --- |"]
    for path in previews:
        item = Path(path).stem
        credits = [reference_credit(s["path"]) for s in CURRENT[item]+NEIGHBORS[item]]
        authors = "; ".join(sorted({c[0] for c in credits}))
        license_name = "CC BY-SA 4.0 International" if any("4.0" in c[1] for c in credits) else "CC BY-SA 3.0 Unported"
        rows.append(f"| `previews/{item}.png` | GPT-6 Astra; {authors} | {DATE} | {license_name} | [generate.py](generate.py); comparison operations listed above |")
    rows += ["", "Licence texts: [CC BY-SA 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/)",
             "and [CC BY-SA 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/).", "",
             "## Existing comparison inputs", "",
             "One row per source file; these are read-only references, not new assets.",
             "Their SHA-256 values and presentation modifiers are recorded in",
             "[drafts/manifest.json](drafts/manifest.json). Attribution follows the",
             "[farming ledger](../../mods/ITEMS/grug_farming/LICENSE-media.md),",
             "[cooking ledger](../../mods/ITEMS/grug_cooking/LICENSE-media.md),",
             "[gathering ledger](../../mods/ITEMS/grug_gathering/LICENSE-media.md),",
             "[default media authors](../../mods/BASE/default/README.txt) and",
             "[default licence](../../mods/BASE/default/license.txt). The source licence",
             "lists were read in the existing pinned reference checkouts; no media",
             "was downloaded. Existing project attributions remain in",
             "[CREDITS.md](../../CREDITS.md).", "",
             "| Existing file | Author | Exact original licence | Pinned original source |",
             "| --- | --- | --- | --- |"]
    for path in data["reference_sha256"]:
        author, license_name, url = reference_credit(path)
        rows.append(f"| `{path}` | {author} | {license_name} | [Source]({url}) |")
    return "\n".join(rows)+"\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="compare generated pixels and manifest without writing")
    args = parser.parse_args()
    entries, images = build_drafts()
    assert len(entries) == 27 and len(images) == 87
    previews = {f"tools/r48_artp/previews/{item}.png": preview(item, entries, images) for item in IDEAS}
    data = manifest(entries, previews)
    document = json.dumps(data, indent=2, ensure_ascii=False)+"\n"
    media_ledger = ledger(images, previews, data)
    outputs = images | previews
    if args.check:
        expected = {ROOT/path for path in outputs}
        actual = set((HERE/"drafts").rglob("*.png")) | set((HERE/"previews").glob("*.png"))
        assert actual == expected, f"Unexpected/missing PNG paths: {actual ^ expected}"
        for path, im in outputs.items():
            with Image.open(ROOT/path) as saved:
                assert saved.mode == im.mode and saved.size == im.size, path
                assert saved.tobytes() == im.tobytes(), f"Stale pixels: {path}"
        assert (HERE/"drafts/manifest.json").read_text() == document, "Stale manifest"
        assert (HERE/"LICENSE-media.md").read_text() == media_ledger, "Stale media ledger"
        print("PASS: 27 drafts, 87 transparent 16x16 RGBA sprites, 9 RGBA previews; pixels, manifest and ledger reproducible.")
    else:
        for path, im in outputs.items():
            target = ROOT/path
            target.parent.mkdir(parents=True, exist_ok=True)
            im.save(target, format="PNG", optimize=False, compress_level=9)
        (HERE/"drafts/manifest.json").write_text(document)
        (HERE/"LICENSE-media.md").write_text(media_ledger)
        print("Wrote 27 drafts / 87 sprites, 9 comparison PNGs, manifest and media ledger.")


if __name__ == "__main__":
    main()
