#!/usr/bin/env python3
"""CC0. Original cloth paint, drop 03. Python standard library + Pillow.

Only catalog geometry is read; all pixels are authored here. No random state.
Run from any directory. All writes stay in this drop. a..f = T1..T6.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

DROP = Path(__file__).resolve().parents[1]
TOOL = Path.home() / "projects/grudgelands/tools/r54_armor"
REF = {
    "H": ("M_HI", "F0F0F0"), "L": ("M_LIGHT", "C8C8C8"),
    "M": ("M_MID", "A0A0A0"), "S": ("M_DARK", "787878"),
    "D": ("M_DEEP", "505050"), "O": ("OUTLINE", "282828"),
    "R": ("ACC_LIGHT", "A07850"), "r": ("ACC_DARK", "6E5034"),
    "A": ("A_LIGHT", "E07070"), "a": ("A_DARK", "B04848"),
    "B": ("B_LIGHT", "70A0E0"), "b": ("B_DARK", "4870B0"),
    "G": ("GLOW", "FFC040"),
}
RGBA = {c: tuple(bytes.fromhex(h)) + (255,) for c, (_, h) in REF.items()}
RGBA["."] = (0, 0, 0, 0)
NAMES = ("patch", "woven", "heavy_cloth", "silkweave", "silk", "stormweave")
# Same palettes in both proposals, so picking slots never changes their dye.
# hi/light/base/shade/deep/outline, cord/lining, A, B, unused glow = light.
PALETTES = (
    "C5B9A2 A99B82 8C7E67 6C604E 4E4439 302D28 997A55 604C36 CBBE9E A3977C B09A70 857352 A99B82",
    "BDCAA9 9EAF89 7D9068 5E714E 43543A 2D382A 9A7D53 604C34 D8D0AF ABA685 D2C08C 9B895E 9EAF89",
    "A5B5CE 8095B6 607A9D 465C7D 32445F 242F44 8B7558 514331 E2D8BA B1AA91 DEC993 A39465 8095B6",
    "F9F2E1 EBE1CA CFC2A5 A99A7C 796C57 403B33 A18A63 6A543D A15B58 773D42 C8A158 95713D EBE1CA",
    "FFFFFF F4F3F7 DADDEB B2B6CD 7D869E 414960 A18CAA 655776 788CBD 506697 E4C26D AF8B43 F4F3F7",
    "879ACA 6079A9 394F7F 2A3B62 1C2A49 141F35 65779E 33415F ACBEDD 748BAE E3ECFF A7BCDD 6079A9",
)
SELECTIONS = {
    "p1": [
        "helm chest boot",
        "helm chest belt boot",
        "helm chest belt sleeve panel_f panel_b boot",
        "helm chest belt sleeve panel_f panel_b boot",
        "helm chest belt sleeve panel_f panel_b boot",
        "helm chest belt sleeve panel_f panel_b boot",
    ],
    "p2": [
        "helm chest boot",
        "helm chest belt pauldron boot",
        "helm chest belt pauldron sleeve thigh boot",
        "helm chest belt pauldron sleeve panel_f panel_b boot",
        "helm chest belt pauldron sleeve panel_f panel_b boot",
        "helm chest belt pauldron sleeve panel_f panel_b boot",
    ],
}


class Face:
    def __init__(self, w, h, fill="."):
        self.w, self.h = w, h
        self.rows = [[fill] * w for _ in range(h)]

    def dot(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.rows[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                self.rows[y][x] = c

    def row(self, y, c, x0=0, x1=None):
        self.rect(x0, y, self.w - 1 if x1 is None else x1, y, c)

    def col(self, x, c, y0=0, y1=None):
        self.rect(x, y0, x, self.h - 1 if y1 is None else y1, c)

    def stamp(self, rows, x=0, y=0, skip=None):
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                if c != skip:
                    self.dot(x + i, y + j, c)

    def image(self):
        im = Image.new("RGBA", (self.w, self.h))
        im.putdata([RGBA[c] for row in self.rows for c in row])
        return im


def textile(w, h, face):
    """Broad, low-contrast folds; no outlined plate perimeter."""
    f = Face(w, h, "L" if face == "top" else "S" if face == "bottom" else "M")
    if face not in ("top", "bottom"):
        if w > 3:
            f.col(w - 1, "S")
            f.col(1, "L", 0, max(1, h // 3))
        if face == "back":
            f.col(w // 2, "S", max(1, h // 3))
    return f


def embroidery(f, y, tier, x0=0, x1=None):
    """Progression: plain binding, seed stitches, braid, branching embroidery."""
    x1 = f.w - 1 if x1 is None else x1
    f.row(y, "B", x0, x1)
    if tier >= 4:
        for x in range(x0 + 1, x1, 3):
            f.dot(x, y - 1, "b")
    if tier >= 5:
        f.row(y + 1, "b", x0, x1)
        for x in range(x0 + 1, x1, 3):
            f.dot(x, y - 1, "B")
    if tier == 6:
        for x in range(x0 + 1, x1, 3):
            f.dot(x + 1, y - 2, "B")


def gem(f, x, y, tier):
    f.stamp([".B.", "BbB", ".b."], x - 1, y - 1, skip=".")
    if tier >= 5:
        f.dot(x, y, "H")
    if tier == 6:
        f.dot(x - 2, y, "B")
        f.dot(x + 2, y, "B")
        f.dot(x, y + 2, "B")


def hood(f, face, p, t):
    if face == "front":
        f.stamp([
            "MLLLLLLLMS", "MAA....AaS", "AA......aa", "A........a",
            "A........a", "A........a", "A........a", "AA......aa",
            "MAA....aaS", "MMAAAAAaSS",
        ])
        if p == "p1":
            f.row(0, "B", 3, 5)
            if t >= 2:
                f.dot(1, 2, "B")
                f.dot(8, 2, "B")
            if t >= 3:
                f.dot(0, 3, "B")
                f.dot(9, 3, "b")
                f.dot(1, 7, "B")
                f.dot(8, 7, "b")
            if t >= 4:
                f.row(0, "B", 2, 7)
                f.dot(0, 5, "B")
                f.dot(9, 5, "b")
            if t >= 5:
                f.dot(4, 1, "B")
                f.dot(5, 1, "B")
                f.dot(2, 8, "B")
                f.dot(7, 8, "b")
            if t == 6:
                f.dot(3, 1, "b")
                f.dot(6, 1, "b")
                f.row(9, "B", 3, 6)
        else:
            # Squarer cowl with a brow circlet; always a full cloth shell.
            f.row(1, ".", 2, 7)
            f.row(2, ".", 1, 8)
            f.row(7, ".", 1, 8)
            f.row(8, ".", 2, 7)
            f.row(0, "a", 1, 8)
            f.row(0, "B", 3, 5)
            if t >= 2:
                f.row(0, "B", 2, 7)
            if t >= 3:
                f.row(0, "B", 1, 8)
                f.dot(4, 1, "b")
                f.dot(5, 1, "B")
            if t >= 4:
                f.dot(1, 2, "B")
                f.dot(8, 2, "b")
            if t >= 5:
                f.dot(4, 1, "H")
                f.dot(4, 2, "B")
                f.dot(1, 7, "B")
                f.dot(8, 7, "B")
            if t == 6:
                f.dot(2, 1, "B")
                f.dot(7, 1, "B")
                f.dot(0, 4, "B")
                f.dot(9, 4, "b")
        return
    if face == "bottom":
        f.rect(0, 0, 9, 9, "a")
        return
    if face == "top":
        f.rect(0, 0, 1, 9, "M")
        f.rect(8, 0, 9, 9, "M")
        f.col(5, "M", 0, 6)
        if t >= 4:
            f.row(8, "b", 2, 7)
        if t == 6:
            f.stamp([".B.", "BMB", ".B."], 4, 3, skip=".")
        return
    # The fold runs down the back. The front edge has lining, not a slit.
    f.row(9, "a")
    if face == "back":
        f.col(4, "L", 1, 6)
        f.col(5, "M", 0, 7)
        if t >= 2:
            f.row(8, "a", 2, 7)
        if t >= 3:
            embroidery(f, 8, t, 1, 8)
        if t >= 5:
            if p == "p1":
                f.stamp(["..B..", ".BMB.", "BMMMB", ".BMB.", "..B.."], 2, 2, skip=".")
            else:
                gem(f, 4, 4, t)
    else:
        edge = 9 if face == "right" else 0
        f.col(edge, "a", 1)
        f.col(3 if face == "right" else 6, "L", 2, 5)
        if p == "p2" and t >= 2:
            f.row(1, "b", 1, 8)
        if t >= 3:
            embroidery(f, 8, t, 1, 8)
        if t >= 5:
            f.dot(4, 5, "B")
            f.dot(5, 4, "B")
        if t == 6:
            f.dot(6, 3, "B")
            f.dot(3, 4, "b")


def robe(f, face, p, t):
    if face in ("top", "bottom"):
        if face == "top":
            f.rect(2, 0, 6, f.h - 1, "a")
        return
    if face not in ("front", "back"):
        f.col(2, "L", 2, 10)
        f.row(12, "a")
        f.row(13, "S")
        if t >= 4:
            embroidery(f, 11, t)
        return
    if p == "p1":
        if face == "front":
            # A single broad stole makes a continuous axis with panel_f.
            f.rect(3, 0, 5, 13, "A")
            f.col(5, "a", 2)
            f.row(0, "a", 2, 6)
            f.row(1, "A", 2, 6)
            if t == 1:
                f.rect(0, 8, 1, 10, "S")
                f.dot(0, 8, "R")
                f.dot(1, 10, "R")
                f.row(10, "R", 2, 7)
                f.row(11, "B", 3, 5)
            else:
                f.row(3, "B", 3, 5)
            if t >= 3:
                f.col(2, "b", 2)
                f.col(6, "b", 2)
            if t >= 4:
                f.row(2, "B", 2, 6)
                f.dot(1, 3, "B")
                f.dot(7, 3, "B")
                f.stamp([".B.", "BAB", ".B."], 3, 6, skip=".")
            if t >= 5:
                f.col(2, "B", 4)
                f.col(6, "B", 4)
                f.dot(0, 3, "B")
                f.dot(8, 3, "B")
                f.dot(1, 4, "b")
                f.dot(7, 4, "b")
            if t == 6:
                f.stamp(["B.B", ".B.", "B.B"], 3, 6, skip=".")
                f.dot(1, 6, "B")
                f.dot(7, 6, "B")
                f.dot(1, 9, "b")
                f.dot(7, 9, "b")
        else:
            f.rect(3, 0, 5, 2, "a")
            if t >= 3:
                f.rect(3, 3, 5, 13, "a")
                f.col(3, "A", 2)
                if t >= 4:
                    f.row(3, "B", 2, 6)
                    f.col(2, "b", 4)
                    f.col(6, "b", 4)
                if t >= 5:
                    f.stamp([".B.", "BaB", ".B."], 3, 6, skip=".")
                if t == 6:
                    f.dot(1, 4, "B")
                    f.dot(7, 4, "B")
                    f.row(10, "B", 3, 5)
        if t <= 2:
            f.row(12, "a")
            f.row(13, "S")
    else:
        # The mantle is painted over the whole chest: stepped edge is cloth.
        for x in range(9):
            edge = 3 + min(x, 8 - x) // 2
            f.col(x, "A" if face == "front" else "a", 0, edge)
            f.dot(x, edge + 1, "b" if t >= 2 else "a")
        # Offset sash emerges below the mantle; no diagonal leather straps.
        sx = 5 if face == "front" else 2
        f.rect(sx, 5, sx + 1, 13, "A" if face == "front" else "a")
        if t == 1:
            f.row(10, "R")
            f.row(11, "B", 4, 6)
            f.rect(0, 9, 1, 11, "S")
        elif face == "front":
            gem(f, 4, 3, t)
        if t >= 3:
            f.col(sx - 1, "b", 6)
            f.dot(sx, 9, "B")
        if t >= 4:
            f.row(1, "B", 1, 7)
            f.dot(0, 4, "B")
            f.dot(8, 4, "B")
        if t >= 5:
            f.dot(2, 3, "B")
            f.dot(6, 3, "B")
            f.col(sx + 2, "b", 6)
        if t == 6:
            f.row(5, "B", 2, 6)
            f.dot(sx, 8, "B")
            f.dot(sx + 1, 10, "B")
            f.dot(sx, 12, "B")
        f.row(12, "a", 0, 3)
        f.row(13, "S")


def sash(f, face, p, t):
    f.rect(0, 0, f.w - 1, f.h - 1, "a")
    if face in ("top", "bottom"):
        return
    f.row(0, "A")
    if face == "front":
        # Flat tied cloth, never an oversized metal belt buckle.
        x = 4 if p == "p1" else 7
        f.dot(x, 0, "B")
        f.dot(x + 1, 0, "B")
        f.dot(x, 1, "b")
        if t >= 4:
            f.dot(x - 1, 1, "B")
        if t >= 5:
            f.row(1, "b")
            f.dot(x, 1, "B")
        if t == 6:
            f.dot(1, 0, "B")
            f.dot(8, 0, "B")


def sleeve(f, face, p, t):
    if face == "bottom":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")
        return
    if face == "top":
        return
    f.rect(0, 10, f.w - 1, 12, "a")
    f.row(10, "A")
    embroidery(f, 11, t)
    if p == "p1":
        if t >= 4:
            f.col(2, "a", 1, 5)
            f.dot(2, 3, "B")
        if t >= 5:
            f.stamp([".B.", "BMB", ".B."], 1, 2, skip=".")
        if t == 6:
            f.dot(2, 6, "B")
            f.dot(1, 7, "B")
            f.dot(3, 7, "b")
    else:
        # A jewel at the wrist and a calm sleeve below the separate mantle.
        if t >= 4 and face in ("front", "right"):
            gem(f, 2, 9, t)
        if t == 6:
            f.col(2, "a", 6, 7)
            f.dot(2, 6, "B")


def mantle(f, face, p, t):
    if face == "top":
        f.rect(0, 0, f.w - 1, f.h - 1, "A")
        return
    if face == "bottom":
        f.rect(0, 0, f.w - 1, f.h - 1, "S")
        return
    # The lower edge of the little cape is painted onto its whole shell.
    f.rect(0, 0, f.w - 1, 4, "a" if face == "back" else "A")
    f.row(5, "b")
    if t >= 3:
        f.dot(2, 5, "B")
        f.dot(3, 5, "B")
    if t >= 4 and face != "left":
        gem(f, 2, 2, t)
    if t >= 5:
        f.col(0, "B", 1, 4)
        f.col(5, "b", 1, 4)
        f.row(5, "B")
    if t == 6:
        f.dot(1, 4, "B")
        f.dot(4, 4, "B")
        f.row(6, "b", 1, 4)


def panel(f, face, p, t, rear=False):
    if face in ("top", "bottom"):
        return
    if f.w == 1:
        f.col(0, "M")
        f.dot(0, 9, "B")
        f.dot(0, 10, "b" if t >= 5 else "S")
        return
    # Both sides of each fabric panel are painted, including the inner lining.
    outer = face == ("back" if rear else "front")
    if not outer:
        f.rect(0, 0, 6, 10, "S")
        f.col(2, "M", 0, 8)
        f.row(9, "b")
        return
    if p == "p1":
        f.rect(2, 0, 4, 9, "a" if rear else "A")
        f.col(4, "a", 0, 9)
        f.col(1, "b", 0, 8)
        f.col(5, "b", 0, 8)
        if t >= 4:
            f.col(1, "B", 0, 8)
            f.col(5, "B", 0, 8)
            f.stamp([".B.", "BAB", ".B."], 2, 5, skip=".")
        if t >= 5:
            f.dot(0, 7, "B")
            f.dot(6, 7, "B")
            f.dot(3, 3, "B")
        if t == 6:
            f.stamp(["B.B", ".B.", "B.B"], 2, 3, skip=".")
            f.dot(0, 5, "b")
            f.dot(6, 5, "b")
        embroidery(f, 9, t)
    else:
        # A short tunic is suggested by a painted upper hem; the lower area
        # remains an opaque, lighter underskirt. No geometric cutback.
        f.rect(0, 0, 6, 4, "M")
        f.rect(0, 6, 6, 10, "L")
        f.col(6, "M", 6, 10)
        sx = 4 if not rear else 1
        f.rect(sx, 0, sx + 1, 9, "A" if not rear else "a")
        f.col(sx - 1, "b", 0, 8)
        f.row(5, "b", 0, 6)
        f.row(9, "B")
        f.row(10, "M")
        if t >= 5:
            gem(f, sx, 3, t)
            f.row(5, "B")
            f.dot(1, 8, "B")
            f.dot(5, 8, "B")
        if t == 6:
            f.row(10, "b")
            f.stamp([".B.B.", "B...B"], 1, 7, skip=".")
            f.dot(1, 2, "B")


def thigh(f, face, p, t):
    if face in ("top", "bottom"):
        return
    f.col(0, "A")
    f.row(3, "b")
    f.dot(1, 2, "B")
    f.dot(2, 2, "B")


def slippers(f, face, p, t):
    if face == "bottom":
        f.rect(0, 0, f.w - 1, f.h - 1, "r")
        return
    if face == "top":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")
        return
    f.rect(0, 0, f.w - 1, 4, "M" if t >= 3 else "R")
    f.row(5, "r")
    if face == "front":
        # At least three A texels per mirrored foot, above the soft vamp.
        f.stamp(["AAAA", "aMMa", "MBBM", "MMMS", "MMMS", "rrrr"])
        if t <= 2:
            f.row(3, "R")
            f.row(4, "R")
        if t >= 2:
            f.dot(1, 1, "B")
        if p == "p2":
            f.col(1, "A", 1, 3)
            f.dot(2, 2, "B")
            f.dot(2, 3, "b")
            if t >= 2:
                f.dot(2, 1, "B")
                f.dot(3, 2, "b")
        if t >= 4:
            f.row(4, "B", 1, 2)
        if t >= 5:
            f.dot(2, 1, "B")
            f.dot(0, 4, "b")
        if t == 6:
            f.dot(1, 3, "B")
            f.dot(3, 4, "B")
    else:
        f.row(0, "a")
        f.row(1, "A")
        if t >= 2:
            f.row(2, "b")
        if t >= 4:
            f.dot(2, 3, "B")
        if t >= 5:
            f.row(4, "b")
        if t == 6:
            f.dot(1, 3, "B")
            f.dot(3, 3, "B")


PAINTERS = {"helm": hood, "chest": robe, "belt": sash, "sleeve": sleeve,
            "pauldron": mantle, "panel_f": panel,
            "panel_b": lambda f, n, p, t: panel(f, n, p, t, True),
            "thigh": thigh, "boot": slippers}


def draw_box(b, p, t):
    im = Image.new("RGBA", tuple(b["sheet"]))
    for face, (x0, y0, w, h) in b["faces"].items():
        f = textile(w, h, face)
        PAINTERS[b["id"]](f, face, p, t)
        for y, row in enumerate(f.rows):
            for x, c in enumerate(row):
                if c == ".":
                    assert b["id"] == "helm" and face == "front" and 1 <= x <= 8 and 1 <= y <= 8
        im.paste(f.image(), (x0, y0))
    return im


def draw_inner(slot, p, t):
    f = Face(64, 32)
    if slot == "chest":
        f.rect(16, 16, 55, 31, "M")
        f.rect(20, 16, 27, 19, "L")
        f.rect(44, 16, 47, 19, "L")
        for x in (16, 28, 32, 40, 48, 52):
            f.col(x, "S", 20, 31)
        f.rect(23, 20, 25, 31, "A")
        f.rect(40, 29, 55, 31, "a")
        f.row(29, "A", 40, 55)
        f.row(30, "B", 44, 47)
        f.row(30, "b", 40, 43)
        f.row(30, "b", 48, 55)
        if t >= 2:
            f.dot(45, 28, "B")
            f.dot(46, 28, "B")
        if p == "p2":
            f.rect(40, 20, 55, 24, "A")
            f.row(25, "b", 40, 55)
        if t >= 4:
            f.dot(45, 23, "B")
            f.dot(46, 24, "B")
    elif slot == "legs":
        f.rect(0, 20, 15, 27, "M")
        for x in (0, 8, 12):
            f.col(x, "S", 20, 27)
        f.col(5, "L", 20, 27)
        # The bound side seam remains visible when this piece is worn alone.
        f.col(4, "A", 20, 27)
        f.row(26, "b", 4, 7)
        if t >= 2:
            f.col(7, "a", 20, 27)
            f.row(26, "B", 4, 7)
            f.dot(6, 25, "B")
        if t >= 3:
            f.row(27, "B", 0, 15)
        if p == "p2" and t >= 4:
            f.rect(0, 25, 15, 27, "L")
            f.col(4, "A", 25, 27)
            f.row(27, "B", 4, 7)
    else:
        f.rect(0, 28, 15, 31, "M" if t >= 3 else "R")
        f.row(28, "A", 0, 15)
        f.row(29, "a", 4, 7)
        f.row(30, "B", 5, 6)
        f.row(31, "r", 0, 15)
    return f.image()


def icon_head(p, t):
    f = Face(16, 16)
    f.stamp(["......SSSS......", "....SLLLLLS.....", "...SLMMMMLMS....",
             "..SLMAAAAAMMS...", "..SMA....aMMS...", "..SA......aMS...",
             "..SA......aMS...", "..SA......aMS...", "..SMA....aMMS...",
             "...MAA..aaMS....", "..SMAAAAAaaMS...", ".SMMMMaaaaMMMS..",
             "..SSMMMMMMSSS...", "....SSSSSSS....."], y=1)
    f.row(4, "B", 6, 8)
    if p == "p2":
        f.row(4, "A", 4, 10)
        f.row(4, "B", 5, 9)
        if t >= 3:
            f.dot(7, 5, "B")
    if t >= 2:
        f.dot(4, 5, "B")
        f.dot(10, 5, "b")
    if t >= 4:
        f.dot(4, 9, "B")
        f.dot(10, 9, "B")
    if t >= 5:
        f.dot(7, 4, "H" if p == "p2" else "B")
        f.row(12, "B", 5, 9)
    if t == 6:
        f.dot(5, 3, "B")
        f.dot(9, 3, "B")
        f.dot(7, 2, "B")
    return f


def icon_chest(p, t):
    f = Face(16, 16)
    f.stamp([".....Sa.aS......", "....SMAAAMS.....", "...SMLAAAMMS....",
             "..SMMMAAAMMMS...", ".SMMMMAAAMMMMS..", ".SMMMMAAaMMMMS..",
             ".SaMSMAAaSMaaS..", ".SaaSMAAaSaaaS..", "..SSSMAAaSSSS...",
             "....MMAAaMS.....", "...SMMAAaMMS....", "...SMMBBBMaS....",
             "....SSSSSSS....."], y=1)
    if p == "p2":
        f.rect(4, 4, 10, 10, "M")
        f.rect(8, 5, 9, 11, "A")
        f.stamp(["..AAAAaAAAAAA...", ".AAaaaaAaaaaAA..", ".aBBBBBabBBBaa..", "..aMMMaBaMMMa..."], y=3)
        if t >= 3:
            f.dot(7, 5, "B")
        if t >= 4:
            f.dot(7, 4, "H")
    else:
        f.row(4, "B", 6, 8)
        if t >= 3:
            f.col(5, "b", 4, 11)
            f.col(9, "b", 4, 11)
    if t >= 2:
        f.row(10, "A", 4, 10)
    if t >= 4:
        f.row(8, "B", 1, 3)
        f.row(8, "B", 11, 13)
    if t >= 5:
        f.dot(7, 7, "B")
        f.row(12, "B", 4, 10)
    if t == 6:
        f.dot(6, 6, "B")
        f.dot(8, 6, "B")
        f.dot(2, 7, "B")
        f.dot(12, 7, "B")
    return f


def icon_legs(p, t):
    f = Face(16, 16)
    if t >= (3 if p == "p1" else 4):
        f.stamp([".....AAAAAA.....", "....SMLAAMMS....", "....MMLAAMMS....",
                 "....MMLAAMMS....", "...SMMLAAMMMS...", "...MMMLAAMMMS...",
                 "...MMMLAAMMMS...", "..SMMMLAAMMMMS..", "..MMMMLAAMMMMS..",
                 "..MMMMLAAMMMMS..", ".SMMMMLAaMMMMMS.", ".SMBBBBBBBBBMMS.",
                 "..SSSSSSSSSSSS.."], y=1)
        if p == "p2":
            f.rect(3, 8, 12, 11, "L")
            f.row(7, "b", 3, 12)
            f.rect(9, 2, 10, 10, "A")
            f.row(12, "B", 3, 12)
        else:
            f.col(5, "b", 2, 11)
            f.col(8, "b", 2, 11)
        if t >= 4:
            f.dot(6 if p == "p1" else 9, 8, "B")
        if t >= 5:
            f.row(11, "B", 3, 12)
            f.dot(7 if p == "p1" else 10, 7, "B")
        if t == 6:
            f.dot(4, 10, "B")
            f.dot(11, 10, "B")
            f.dot(7, 5, "B")
    else:
        f.stamp(["....AAAAAAA.....", "...SMLMMMLMS....", "...SMLMMMLMS....",
                 "...SMLMMMLMS....", "...SMLMSMLMS....", "...SMLSSMLMS....",
                 "...SAMS.SAMS....", "...SAMS.SAMS....", "...SAMS.SAMS....",
                 "...SBBM.SBBM....", "....SSS..SSS...."], y=2)
        if t >= 2:
            f.row(10, "B", 4, 5)
            f.row(10, "B", 9, 10)
        if t == 3:
            f.row(5, "B", 4, 6)
            f.row(5, "B", 8, 10)
    return f


def icon_feet(p, t):
    f = Face(16, 16)
    f.stamp(["......SSSSS.....", ".....SAAAAaS....", ".....SaMMMaS....",
             ".....SMLMMMS....", ".....SMLBMMS....", ".....SMLMMMS....",
             ".....SMLMMMS....", "....SMLMMMMMS...", "...SMLMMMMMMMS..",
             "..SMMMMMMMMMMS..", "...rrrrrrrrrr..."], y=3)
    if t <= 2:
        f.rect(6, 6, 9, 10, "R")
        f.dot(8, 7, "B")
    if p == "p2":
        f.col(8, "A", 5, 10)
        f.dot(8, 7, "B")
        f.dot(9, 8, "b")
    if t >= 2:
        f.row(5, "B", 6, 9)
    if t >= 4:
        f.row(11, "B", 6, 10)
    if t >= 5:
        f.dot(8, 8, "B")
        f.dot(9, 7, "B")
    if t == 6:
        f.dot(10, 10, "B")
        f.dot(7, 9, "B")
    return f


ICONS = {"head": icon_head, "chest": icon_chest, "legs": icon_legs, "feet": icon_feet}
IDEAS = {
    "p1": "Cantor: a narrow hood, continuous central stole and long robe establish a quiet vertical line. Rank grows through bound edges, seed embroidery, branching silverwork and decorated sleeve fabric, with no added shoulder mass after T3.",
    "p2": "Lamplighter: a brow circlet over a full cloth cowl, a short shoulder mantle and an offset sash frame a more mobile tunic. Later tiers layer the painted tunic hem over a pale underskirt, and gem clasps develop into small settings on the mantle and cuffs.",
}
TIER_NOTES = {
    "p1": [
        "Hood, tunic shell, soft boots and skin-painted sleeves/trousers; one neat repair, cord tie and a modest bound stole.",
        "Adds a sash shell; hood stitches, cleaner cuffs, bound trouser seams and a small stole bar replace the workaday repair.",
        "Adds long front/back robe panels and whole sleeve shells; the stole continues to the hem, with a fine border and bound cuffs.",
        "Same seven shapes; paired gold borders, a diamond stitch on the stole, collar embroidery and sleeve tabs distinguish the cream robe.",
        "Same seven shapes; brighter full stole borders, shoulder rosettes painted on the sleeves, deeper braided hems and shoe embroidery enrich the silk.",
        "Same seven shapes; a branching silver stole motif, double embroidered hems, sleeve branches and a decorated hood crown complete the storm robe.",
    ],
    "p2": [
        "Cowl, tunic shell, soft boots and skin-painted sleeves/trousers; a painted shoulder kerchief, offset sash and cord tie start the line.",
        "Adds sash and shoulder shells as a cloth mantle; a longer brow band, one breast clasp and a bound mantle edge give a tailored silhouette.",
        "Adds sleeve and thigh shells; the circlet gains a pendant, the short tunic wears decorated breeches and the mantle gains a braided hem.",
        "Replaces thigh shells with full front/back skirt panels; a painted short tunic hem above a pale underskirt, shoulder gems and cuff clasps mark the formal tier.",
        "Same eight shapes; circlet stone, inset mantle clasps, framed mantle borders and a jeweled sash over the underskirt enrich the white silk.",
        "Same eight shapes; larger silver gem settings, linked mantle ornament, branching underskirt embroidery and decorated cuffs complete the formal dress.",
    ],
}


def write_json(path, obj):
    path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool", type=Path, default=TOOL)
    args = parser.parse_args()
    catalog = json.loads((args.tool / "data/catalog.json").read_text())
    boxes = {b["id"]: b for b in catalog["boxes"]}
    palettes = {"palettes": {name: {"colors": {value[0]: "#" + h for value, h in zip(REF.values(), row.split(), strict=True)}}
                              for name, row in zip(NAMES, PALETTES, strict=True)}}
    for p, selections in SELECTIONS.items():
        base = DROP / p
        for sub in ("cloth", "cloth/inner", "cloth/icons"):
            (base / sub).mkdir(parents=True, exist_ok=True)
        expected = set()
        tiers = {}

        def save(im, relative):
            path = base / relative
            im.save(path, compress_level=9)
            expected.add(path)

        for t, selection in enumerate(selections, 1):
            var = chr(96 + t)
            on = selection.split()
            tiers[f"T{t}"] = {"palette": NAMES[t - 1], "on": on,
                               "variant": {b: var for b in on},
                               "inner": {s: var for s in ("chest", "legs", "feet")},
                               "icon": {s: var for s in ICONS}}
            for bid in on:
                save(draw_box(boxes[bid], p, t), f"cloth/{bid}_{var}.png")
            for slot in ("chest", "legs", "feet"):
                save(draw_inner(slot, p, t), f"cloth/inner/{slot}_{var}.png")
            for slot, fn in ICONS.items():
                save(fn(p, t).image(), f"cloth/icons/{slot}_{var}.png")
        for path in (base / "cloth").rglob("*.png"):
            if path not in expected:
                path.unlink()
        write_json(base / "tiers.json", {"cloth": tiers})
        write_json(base / "palettes.json", palettes)
        notes = IDEAS[p] + "\n\n" + "\n".join(f"- T{t} {NAMES[t-1]}: {n}" for t, n in enumerate(TIER_NOTES[p], 1))
        notes += "\n\nVariants a-f identify T1-T6. Both proposals share all six palettes for slot mixing.\n"
        notes += "Zone A is the stole, sash, lining and bound seams; zone B is embroidery, hem binding, clasps and circlet. Every slot has its own zones even when another slot covers it.\n"
        notes += "Every box face is opaque except the permitted hood face window. All short hems, mantle edges and folds are paint on whole shells.\n"
        notes += "Both omit tassets, flares, reinforcement, spikes, knee cops, toe caps and visors. The front edges of the thin side shapes do not help these calm cloth silhouettes. The full hood cannot be reduced to a bare circlet; P2 paints its circlet over an opaque cloth cowl. These are deliberate shape selections, not checker warnings.\n"
        notes += "The fixed front/back panels cover much of the boots at rest and open in the walking pose; the sides are cloth-painted legs. P1 has a robe from T3; P2 keeps a short tunic through T3 and gains an opaque layered skirt at T4.\n"
        notes += "Original art and scripts, dedicated to the public domain under CC0 1.0. No pixels sampled from references or test art.\n"
        (base / "notes.md").write_text(notes, encoding="utf-8")
        print(f"{p}: {len(expected)} production PNGs")


if __name__ == "__main__":
    main()
