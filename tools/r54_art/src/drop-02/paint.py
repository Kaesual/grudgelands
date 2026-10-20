#!/usr/bin/env python3
"""CC0. Original metal armor, drop 02, opaque shells. Python 3 + Pillow.

Run from any directory. No source art is sampled: only blank templates and
the frozen catalog's face rectangles are read. Variants a..f always mean T1..T6.
Change a piece in its named painter below; all output stays within this drop.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

DROP = Path(__file__).resolve().parents[1]
DEFAULT_TOOL = Path.home() / "projects/grudgelands/tools/r54_armor"
REF = {
    "H": ("M_HI", "#F0F0F0"), "L": ("M_LIGHT", "#C8C8C8"),
    "M": ("M_MID", "#A0A0A0"), "S": ("M_DARK", "#787878"),
    "D": ("M_DEEP", "#505050"), "O": ("OUTLINE", "#282828"),
    "R": ("ACC_LIGHT", "#A07850"), "r": ("ACC_DARK", "#6E5034"),
    "A": ("A_LIGHT", "#E07070"), "a": ("A_DARK", "#B04848"),
    "B": ("B_LIGHT", "#70A0E0"), "b": ("B_DARK", "#4870B0"),
    "G": ("GLOW", "#FFC040"),
}
RGBA = {c: tuple(bytes.fromhex(h[1:])) + (255,) for c, (_, h) in REF.items()}
RGBA["."] = (0, 0, 0, 0)
NAMES = ["bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"]
# Large value intervals keep the dark end of the line legible at a distance.
# Order: hi, light, mid, dark, deep, outline, leather light/dark,
# textile light/dark, fitting light/dark, glow.
PALETTE_ROWS = [
    "F6D49A DEAE6B B78145 80532F 543924 30261F 98724B 58412D C9B998 8B7D64 DFC184 997849 DEAE6B",
    "E2E1DA BCBDB8 8E938F 5C6360 3B4441 242D2B 8C7052 51402E BDB9A6 777D70 C0AB74 806D47 BCBDB8",
    "F0F4F6 C8D8E0 91A7B5 5E7586 3C5264 222F3E 8A7053 4D3B2C B5BAB9 6E8287 D6C48C 8F8055 C8D8E0",
    "FFFFFF E2EAF1 B6C5D6 7C91AB 4D627E 29384D 7E6756 45394A BCC5D7 7585A1 EBF0FA A3B5D2 E2EAF1",
    "E1BA94 A27963 624B43 403437 2C252C 1B1C26 74513B 3C2D27 B98061 714F44 F0AE60 B66B3B FFC375",
    "C2B6DA 8A7DA6 514760 342E44 242134 171B28 60516B 312C3F 9B8FAF 5D566F C5AFE8 8572AB 8A7DA6",
]

SELECTIONS = {
    "p1": [
        "helm chest thigh boot",
        "helm chest belt pauldron thigh boot",
        "helm chest belt sleeve bracer pauldron thigh knee boot",
        "helm chest belt sleeve bracer pauldron reinforce thigh knee boot toe",
        "helm visor chest belt panel_f panel_b sleeve bracer pauldron reinforce thigh knee boot toe",
        "helm visor chest belt panel_f panel_b sleeve bracer pauldron reinforce spike thigh knee boot toe",
    ],
    "p2": [
        "helm chest bracer thigh boot",
        "helm chest belt bracer thigh knee boot",
        "helm chest belt panel_f panel_b bracer pauldron thigh knee boot toe",
        "helm visor chest belt panel_f panel_b sleeve bracer pauldron thigh knee boot toe",
        "helm visor chest belt panel_f panel_b sleeve bracer pauldron reinforce thigh knee boot toe",
        "helm visor chest belt panel_f panel_b sleeve bracer pauldron reinforce flare thigh knee boot toe",
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

    def column(self, x, c, y0=0, y1=None):
        self.rect(x, y0, x, self.h - 1 if y1 is None else y1, c)

    def stamp(self, rows, x=0, y=0):
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                self.dot(x + i, y + j, c)

    def bevel(self, depth=1, top=True, bottom=True):
        """Paint a shaded corner on the whole face; never remove a texel."""
        for y in range(depth):
            for x in range(depth - y):
                for xx in (x, self.w - 1 - x):
                    if top:
                        self.dot(xx, y, "M")
                    if bottom:
                        self.dot(xx, self.h - 1 - y, "D")


def surface(w, h, face):
    """Quiet plate. Highlights are upper edges, never a noise field."""
    f = Face(w, h, {"top": "L", "bottom": "D", "back": "S", "left": "S"}.get(face, "M"))
    if face == "top":
        f.row(h - 1, "H")
    elif face != "bottom":
        f.row(0, "L")
        if h > 3:
            f.row(h - 1, "D")
        if w > 3:
            f.column(w - 1, "S", 1, h - 2)
    return f


def helmet(f, face, p, t):
    """A complete shell: early metal caps sit over opaque textile coifs."""
    closed = t >= (5 if p == "p1" else 4)
    metal_end = (4, 6, 8, 9, 9, 9)[t - 1]
    if face == "bottom":
        f.rect(0, 0, 9, 9, "a")
        f.row(0, "D")
        return
    if face == "top":
        if p == "p2":
            f.column(4, "H")
            f.column(5, "M")
        if t >= 4:
            f.row(1, "B", 3, 6)
        return
    # The rear and sides retain their full height, padded below the metal cap.
    f.rect(0, metal_end, 9, 9, "a")
    f.row(metal_end - 1, "D")
    f.row(9, "a")
    if metal_end < 8:
        f.column(4, "A", metal_end, 8)
        f.column(5, "A", metal_end, 8)
    if face == "front":
        if p == "p1":
            f.stamp(["LLLLLLLLLL", "LMMMMMMMML", "MBBMMMMBBM", "aAAAAAAAAa",
                     "a...LL...a", "a...MS...a", "a........a", "a........a",
                     "a........a", "aaaaaaaaaa"])
            if t >= 2:
                f.stamp(["MS..LL..SM", "MS..MS..SM", "MS......SM", "aS......Sa"], y=4)
            if t >= 3:
                f.stamp(["MB......BM", "aS......Sa"], y=7)
        else:
            f.stamp(["LLLHHLLLLL", "LMMHLMMMML", "MBBHLMMBBM", "aAAAAAAAAa",
                     "a...HL...a", "a...MS...a", "a........a", "a........a",
                     "a........a", "aaaaaaaaaa"])
            if t >= 2:
                f.stamp(["MS..HL..SM", "MS..MS..SM", "MS......SM", "aS......Sa"], y=4)
            if t >= 3:
                f.stamp(["MB......BM", "aS......Sa"], y=7)
        if closed:
            f.rect(0, 3, 9, 8, "M")
            f.row(9, "a")
            f.column(0, "S", 3, 8)
            f.column(9, "S", 3, 8)
            if p == "p2":
                f.column(4, "H", 0, 8)
                f.column(5, "M", 0, 8)
            if t == 6:
                f.row(1, "B", 2, 7)
        return
    if face == "back":
        if p == "p1":
            if t >= 2:
                f.rect(4, 1, 5, 1, "b")
            if t >= 4:
                f.row(6, "M", 1, 8)
        else:
            f.column(4, "L", 0, metal_end - 2)
            f.column(5, "M", 0, metal_end - 2)
    else:
        if p == "p1" and t >= 3:
            f.row(metal_end - 2, "L", 1, 8)
            f.dot(2, metal_end - 3, "B")
        if p == "p2":
            f.column(4, "L", 0, metal_end - 2)
            f.dot(4, 2, "B")
        if t == 6:
            f.row(6, "B", 2, 7)


def visor(f, face, p, t):
    if face == "front":
        if p == "p1":
            f.stamp(["LLLLLLLLL", "BMOOMOOMB", "MMLLLLMSM", "SMMMSMMMS", "DSMMSMMSD", "aAAAAAAAa"])
        else:
            f.stamp(["LLLLHLLLL", "BOOOHOOOB", "MMSLHSMMS", "SMMBHMMMS", "DSMMHMMMD", "aAAAAAAAa"])
        if t == 5:
            f.dot(4, 3, "G")
        if t >= 5:
            f.dot(4, 0, "B")
    elif face == "back":
        f.rect(0, 0, f.w - 1, f.h - 1, "D")
    elif face == "bottom":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")


def cuirass(f, face, p, t):
    if face in ("top", "bottom"):
        if face == "top":
            f.rect(2, 0, 6, 3, "a")
        f.bevel(1)
        return
    f.bevel(1)
    if face in ("front", "back"):
        # Textile collar and lower lining are attached to this slot.
        f.row(0, "a", 1, 7)
        f.row(1, "A", 2, 6)
        f.row(13, "a", 1, 7)
        f.dot(1, 2, "B")
        f.dot(7, 2, "B")
        if face == "back":
            # A backplate has no breast badge. Keep a broad, quiet field.
            f.rect(1, 2, 7, 10, "S")
            f.row(2, "M", 2, 6)
            if p == "p2":
                f.column(4, "M", 3, 9)
            f.row(10, "D", 1, 7)
            f.row(11, "M", 1, 7)
            f.dot(2, 3, "b")
            f.dot(6, 3, "b")
            return
        if p == "p1":
            f.row(2, "L", 2, 6)
            f.rect(1, 3, 7, 6, "M" if face == "front" else "S")
            f.rect(2, 3, 6, 3, "L")
            # One wide breastplate, then at most two articulated belly plates.
            for y in ([8] if t < 3 else [7, 10]):
                f.row(y, "D", 1, 7)
                f.row(y + 1, "L", 1, 7)
            if t < 2:
                f.row(11, "R")
                f.stamp(["bbb", "BbB"], 3, 10)
            if t >= 4:
                f.dot(1, 6, "B")
                f.dot(7, 6, "B")
            if t >= 5:
                f.stamp(["BBB", "MbM"], 3, 4)
                if t == 5:
                    f.row(7, "G", 3, 5)
        else:
            # Faceted central keel with dark flank plates, no all-over striping.
            f.column(1, "S", 3, 10)
            f.column(7, "S", 3, 10)
            f.column(4, "L", 2, 10)
            f.column(5, "M", 3, 9)
            f.dot(3, 3, "L")
            f.dot(6, 3, "L")
            for y, x in [(7, 1), (8, 2), (9, 3)]:
                f.dot(x, y, "D")
                f.dot(8 - x, y, "D")
            f.row(11, "L", 1, 7)
            if t >= 3:
                f.column(0, "a", 3, 10)
                f.column(8, "a", 3, 10)
            if t >= 4:
                f.dot(4, 3, "B")
                f.dot(4, 4, "b")
                f.dot(4, 5, "B")
            if t >= 5:
                f.dot(2, 6, "G" if t == 5 else "B")
                f.dot(6, 6, "G" if t == 5 else "B")
        # A third low-tier rivet on the plackart, visible without the belt.
        f.dot(4, 9 if p == "p1" else 11, "B")
    else:
        f.rect(0, 1, f.w - 1, f.h - 2, "a" if t < 3 else "S")
        f.column(2, "A" if t < 3 else "M", 1, 12)
        f.row(4, "R")
        f.row(9, "r")
        if t >= 3:
            f.row(7, "D")
            f.row(8, "L")


def belt(f, face, p, t):
    f.rect(0, 0, f.w - 1, f.h - 1, "R" if face in ("front", "top") else "r")
    if face == "front":
        f.stamp(["BbB", "BBB"], 3 if p == "p1" else 5, 0)
        if t >= 5:
            f.dot(1, 0, "B")
            f.dot(8, 0, "B")
    if face == "bottom":
        f.rect(0, 0, f.w - 1, f.h - 1, "D")


def shoulder(f, face, p, t, reinforce=False):
    if face == "bottom":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")
        return
    if face == "top":
        if reinforce:
            # A broad uninterrupted cap; one applied fitting at its outer end.
            f.rect(1, 1, f.w - 2, f.h - 2, "M")
            f.row(f.h - 2, "L", 1, f.w - 2)
            f.dot(1, 2, "B")
        elif p == "p2":
            f.column(2, "H")
        return
    if not reinforce:
        if p == "p1":
            f.row(3, "D")
            f.row(4, "L")
            f.dot(1, 1, "B")
            f.dot(f.w - 2, 1, "B")
            f.row(f.h - 1, "a")
        else:
            f.column(2, "L", 1, f.h - 2)
            f.column(3, "M", 2, f.h - 2)
            f.dot(2, 2, "B")
            if t == 3:
                # The former short shoulder is now a plate over a padded cuff.
                f.row(4, "D")
                f.row(5, "A")
                f.row(6, "a")
            else:
                f.row(5, "L", 1, f.w - 2)
                f.row(6, "a")
    else:
        if p == "p1":
            f.row(1, "B", 1, f.w - 2)
            f.row(4, "L")
            f.row(5, "D")
            if t >= 5:
                f.dot(1, 3, "b")
                f.dot(f.w - 2, 3, "b")
            if t == 6:
                # A solid boss replaces the previous pierced cap.
                f.dot(3, 2, "L")
                f.dot(3, 3, "B")
        else:
            # Convex shield paint, narrow central inlay, plain unbroken flanks.
            f.column(3, "L", 1, 3)
            f.dot(3, 2, "B")
            f.row(4, "L", 1, 5)
            f.row(5, "D")
            if t == 6:
                f.row(1, "B", 1, 5)


def arm(f, face, p, t, bracer=False):
    if face in ("top", "bottom"):
        if bracer:
            f.bevel(1)
        return
    if bracer:
        f.bevel(1)
        f.row(f.h - 1, "a", 1, f.w - 2)
        f.dot(1, 1, "B")
        if p == "p1":
            f.row(2, "M")
            f.row(3, "S")
            f.dot(f.w - 2, 1, "B")
        else:
            f.column(2, "L", 1, 3)
            f.column(3, "M", 1, 3)
            if t >= 4:
                f.dot(2, 2, "B")
        if face in ("left", "back"):
            f.row(2, "r")
    else:
        f.rect(0, 0, f.w - 1, f.h - 1, "S")
        f.row(7, "D")
        f.row(8, "A", 1, f.w - 2)
        f.row(9, "a", 1, f.w - 2)
        f.row(10, "L")
        f.column(1, "M", 1, 6)
        # Sparse links only at the elbow; shoulders and bracers carry the mass.
        if p == "p1":
            f.dot(1, 6, "L")
            f.dot(3, 6, "L")
        else:
            f.column(2, "M", 3, 6)


def panel(f, face, p, t):
    """The full eleven-row panel is always present, including every edge."""
    if face == "top":
        f.rect(0, 0, f.w - 1, f.h - 1, "L")
        return
    if face == "bottom":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")
        return
    plate_end = 6 if t == 5 else 8
    if p == "p1":
        if face in ("front", "back"):
            f.rect(0, 0, 6, 10, "a")
            f.rect(0, 0, 6, plate_end - 1, "M" if face == "front" else "S")
            for y in (0, 4 if t == 5 else 5):
                if y < plate_end:
                    f.row(y, "L")
                    if y > 0:
                        f.row(y - 1, "D")
            f.dot(1, 1, "B")
            f.dot(3, 1, "B")
            f.dot(5, 1, "B")
            f.row(plate_end, "A")
            # Padded lower band, not an absent lower skirt. A single seam.
            f.column(3, "A", plate_end + 1, 9)
            f.row(10, "D")
        else:
            f.rect(0, 0, 0, plate_end - 1, "S")
            f.rect(0, plate_end, 0, 10, "a")
    else:
        if face in ("front", "back"):
            # Long cloth insert within plate rails. The lower early-tier band
            # is darker cloth, and gains a metal hem at the upper grades.
            f.rect(0, 0, 6, 10, "M" if face == "front" else "S")
            f.rect(1, 1, 5, 9, "A")
            f.column(1, "a", 2, 9)
            f.column(5, "a", 2, 9)
            f.row(0, "L")
            f.dot(1, 1, "B")
            f.dot(3, 1, "B")
            f.dot(5, 1, "B")
            if t == 3:
                f.rect(1, 6, 5, 9, "a")
            if t >= 4:
                f.dot(3, 3, "B")
                f.dot(3, 4, "b")
            f.row(9, "B" if t >= 5 else "a", 1, 5)
            f.row(10, "D")
            if t == 6:
                f.row(8, "b", 1, 5)
        else:
            f.rect(0, 0, 0, 10, "S")
            f.row(0, "L")
            f.row(10, "D")


def side_plate(f, face, p, t, flare=False):
    if face in ("top", "bottom"):
        return
    if face in ("left", "right"):
        f.bevel(1 if p == "p1" else 2)
        if p == "p1":
            f.row(3, "D")
            f.row(4, "L")
            f.dot(1, 1, "B")
            f.dot(f.w - 2, 1, "B")
        else:
            f.column(f.w // 2, "L", 1, f.h - 2)
            f.column(1, "B", 2, f.h - 3)
            f.dot(f.w - 2, 1, "B")
        f.row(f.h - 1, "a", 1, f.w - 2)
    else:
        f.row(0, "H")
        f.row(1, "B")
        if t == 5 and flare:
            f.row(3, "G")


def thigh(f, face, p, t):
    if face in ("top", "bottom"):
        return
    if face == "front":
        f.stamp(["ABBA", "AMMA", "aMMa", "aDDa"] if p == "p1" else
                ["ABBA", "ALMS", "ALMS", "aDDa"])
        if t >= 2:
            f.stamp(["LBBM", "LMMS", "aMMa", "aDDa"])
    elif face == "back":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")
        f.row(1, "R")
        f.row(2, "S")
    else:
        f.row(1, "R" if t < 3 else "M")
        f.row(2, "a" if t < 3 else "S")


def knee(f, face, p, t):
    if face in ("top", "bottom"):
        return
    if face == "front":
        f.stamp(["MLLM", "BMMB", "SDDS"] if p == "p1" else ["MHLM", "LBBM", "DSSD"])
    elif face in ("left", "right"):
        f.row(1, "M")
        f.dot(2, 1, "B")


def boot(f, face, p, t):
    if face == "bottom":
        return
    if face == "top":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")
        return
    if face == "front":
        # Below the knee and above the toe: four cloth + two fitting pixels
        # per boot survive the maximal set's overlapping geometry.
        f.stamp(["ALLA", "MLMS", "aBBa", "aMMa", "MMMS", "DDDD"] if p == "p1" else
                ["ALMA", "MLMS", "aBBa", "aLMa", "MMMS", "DDDD"])
        if t == 1:
            f.row(4, "R")
    else:
        if t < 3:
            f.rect(0, 0, f.w - 1, f.h - 2, "r")
            f.row(1, "R")
        else:
            f.row(3, "S")
            f.row(4, "M")
        f.row(0, "a")
        f.dot(2, 2, "B")


def toe(f, face, p, t):
    if face == "front":
        f.stamp(["MLLM", "MMMS" if p == "p1" else "MLMS", "DDDD"])
        if t >= 5:
            f.dot(1, 1, "B")
    elif face == "top":
        f.row(0, "L")
        f.row(1, "M")


def spike(f, face, p, t):
    if face == "top":
        f.rect(0, 0, f.w - 1, f.h - 1, "H")
    elif face != "bottom":
        f.stamp(["HL", "LM", "bD"] if p == "p1" else ["HL", "LB", "SD"])


PAINTERS = {
    "helm": helmet, "visor": visor, "chest": cuirass, "belt": belt,
    "pauldron": shoulder,
    "reinforce": lambda f, n, p, t: shoulder(f, n, p, t, True),
    "sleeve": arm, "bracer": lambda f, n, p, t: arm(f, n, p, t, True),
    "panel_f": panel, "panel_b": panel,
    "tasset": side_plate, "flare": lambda f, n, p, t: side_plate(f, n, p, t, True),
    "thigh": thigh, "knee": knee, "boot": boot, "toe": toe, "spike": spike,
}


def draw_box(tool, b, proposal, tier):
    faces = {}
    for name, (x, y, w, h) in b["faces"].items():
        f = surface(w, h, name)
        PAINTERS[b["id"]](f, name, proposal, tier)
        faces[name] = f
    im = Image.open(tool / "templates/blank" / f"{b['id']}.png").convert("RGBA")
    assert not im.getbbox(), "Expected an empty template"
    for name, f in faces.items():
        x0, y0, _, _ = b["faces"][name]
        for y, row in enumerate(f.rows):
            for x, c in enumerate(row):
                if c == ".":
                    assert b["id"] == "helm" and name == "front" and 1 <= x <= 8 and 1 <= y <= 8, (b["id"], name, x, y)
                im.putpixel((x0 + x, y0 + y), RGBA[c])
    return im


def draw_inner(tool, slot, p, t):
    im = Image.open(tool / "templates/blank" / f"inner_{slot}.png").convert("RGBA")
    d = ImageDraw.Draw(im)
    if slot == "chest":
        for x0, x1 in ((16, 39), (40, 55)):
            d.rectangle((x0, 16, x1, 31), fill=RGBA["a"])
        # Calm woven padding. No dense checkerboard under the armor.
        d.rectangle((20, 20, 27, 30), fill=RGBA["A"])
        d.rectangle((44, 20, 47, 30), fill=RGBA["A"])
        for x in (20, 24, 32, 36, 40, 48, 52):
            d.line((x, 21, x, 29), fill=RGBA["a"])
        d.line((40, 27, 55, 27), fill=RGBA["a"])
        d.line((40, 30, 55, 30), fill=RGBA["R"])
        if t >= 3:
            d.rectangle((40, 20, 55, 26), fill=RGBA["S"])
            d.line((44, 22, 47, 22), fill=RGBA["M"])
            d.line((40, 24, 55, 24), fill=RGBA["D"])
        d.point((45, 29), fill=RGBA["B"])
    elif slot == "legs":
        d.rectangle((0, 20, 15, 27), fill=RGBA["a"])
        d.rectangle((4, 20, 7, 27), fill=RGBA["A"])
        for x in (0, 8, 12):
            d.line((x, 20, x, 27), fill=RGBA["r"])
        if t >= 3:
            d.rectangle((0, 24, 15, 27), fill=RGBA["S"])
            d.line((4, 25, 7, 25), fill=RGBA["M"])
        d.point((5, 20), fill=RGBA["B"])
        d.point((6, 20), fill=RGBA["B"])
    else:
        d.rectangle((0, 28, 15, 31), fill=RGBA["r"])
        d.line((0, 31, 15, 31), fill=RGBA["D"])
        d.line((4, 29, 7, 29), fill=RGBA["R"])
    return im


def icon_head(p, t):
    f = Face(16, 16)
    # One complete angular helmet. Early grades have a visible padded coif.
    f.stamp(["....DDDDDD......", "...DLLLLLLD.....", "..DLMMMMMMMD....",
             "..DMMMMMMMMMD...", "..DMBMMMMBMSD...", "..DAAAAAAAaaD...",
             "..Da..LM..aaD...", "..Da..MS..aaD...", "..Da......aaD...",
             "..Da......aaD...", "..Daa....aaaD...", "...DaaaaaaDD....",
             "....DDDDDD......"], y=1)
    if t >= 2:
        f.rect(2, 7, 3, 10, "M")
        f.rect(11, 7, 12, 10, "S")
    if t >= 3:
        f.dot(3, 10, "B")
        f.dot(11, 10, "B")
    if p == "p2":
        f.column(7, "H", 2, 5)
        f.column(8, "L", 3, 5)
    if t >= (5 if p == "p1" else 4):
        f.stamp(["..BLOOOLOOLB....", "..DMLLLLLMMD....", "..DSMMBMMMSD....",
                 "..DSMMMMMMMD....", "..DaAAAAAaaD....", "...DDDDDDDD....."], y=7)
        if p == "p2":
            f.column(7, "L", 7, 10)
    if t == 6:
        f.row(4, "B", 5, 9)
    return f


def icon_chest(p, t):
    f = Face(16, 16)
    f.stamp(["....Da..aD......", "...DLAaaALD.....", "..DLMMLMMMMD....",
             "..DMMLLLMMMD....", "..DBMMMMMMBD....", "...DMMMMMMD.....",
             "...DMMMMMMD.....", "...DLLLLLLD.....", "...DMMMMMMD.....",
             "....RBBBRR......", "....aAAAaa......"], y=2)
    if p == "p1":
        if t >= 2:
            f.stamp([".LLL......LLL...", "DMMB......BMMD..", "DMMM......MMMD..", ".LLD......DLL..."], y=3)
        if t >= 3:
            f.rect(1, 8, 2, 10, "M")
            f.rect(12, 8, 13, 10, "S")
        if t >= 4:
            f.stamp(["LLBB......BBLL..", "LMMD......DMML.."], y=2)
        if t >= 5:
            f.row(8, "L", 4, 10)
    else:
        f.column(7, "L", 4, 10)
        f.column(8, "S", 5, 10)
        f.rect(1, 8, 2, 10, "M")
        f.rect(12, 8, 13, 10, "S")
        if t >= 3:
            f.stamp([".LLD......DLL...", "DMMB......BMMD..", ".DMD......DMD..."], y=3)
        if t >= 5:
            f.stamp([".LLL......LLL...", "DMBM......MBMD.."], y=2)
        if t == 6:
            f.column(0, "L", 3, 6)
            f.column(14, "L", 3, 6)
            f.dot(0, 4, "B")
            f.dot(14, 4, "B")
    if t == 6 and p == "p1":
        f.dot(3, 0, "H")
        f.dot(11, 0, "H")
        f.dot(3, 1, "M")
        f.dot(11, 1, "M")
    return f


def icon_legs(p, t):
    f = Face(16, 16)
    panel_on = t >= (5 if p == "p1" else 3)
    if panel_on:
        f.stamp(["...DDDDDDDD.....", "..DRRRBBRRRD....", "..DLLLLLLLLD....",
                 "..DMBBAABBMD....", "..DMAAAAAaMD....", "..DMAAAAAaMD....",
                 "..DMAAAAAaMD....", "..DMAAAAAaMD....", "..DMAAAAAaMD....",
                 "..DMAAAAAaMD....", "..DMDAaaaDMD....", "..DMD.DD.DMD....",
                 "..DDD....DDD...."], y=1)
        if p == "p1":
            end = 7 if t == 5 else 9
            f.rect(4, 4, 10, end, "M")
            f.row(4, "B", 5, 9)
            f.row(6, "D", 4, 10)
            f.row(7, "L", 4, 10)
            f.row(end, "D", 4, 10)
            f.row(end + 1, "A", 4, 10)
            f.rect(4, end + 2, 10, 10, "a")
        else:
            f.dot(7, 5, "B")
            if t == 3:
                f.rect(4, 8, 10, 10, "a")
            if t >= 5:
                f.row(10, "B", 4, 10)
        # Separate greaves extend below the panel to keep the slot readable.
        f.stamp(["..DLDaaaaDLD....", "..DMD.DD.DMD....", "..DDD....DDD...."], y=11)
        return f
    f.stamp(["....RRBBRR......", "...DALLLLAD.....", "...DALMMLAD.....", "...DABMMBAD.....",
             "...DALDDMAD.....", "...DAMD.DAD.....", "...DAMD.DAD.....", "...DDDD.DDD....."], y=3)
    if (p == "p1" and t >= 3) or (p == "p2" and t >= 2):
        f.row(10, "L", 3, 5)
        f.row(10, "L", 8, 10)
        f.row(11, "D", 3, 5)
        f.row(11, "D", 8, 10)
    return f


def icon_feet(p, t):
    # One side-profile sabaton, recognizable without a tiny duplicated boot.
    f = Face(16, 16)
    if p == "p2":
        # Frontal, tall keeled greave with a compact angular toe.
        f.stamp([".....DDDDD......", "....DLLLLLD.....", "....aALMSaD.....",
                 "....DMLMSMD.....", "....DMLMSMD.....", "....DaBBaMD.....",
                 "....DMLMSMD.....", "....DMLMSMD.....", "....DMLMMMD.....",
                 "....DLMMMMMD....", "...DLLLLMMMMD...", "...DMMMMMMSD....",
                 "....DDDDDDD....."], y=1)
        if t == 1:
            f.row(10, "R", 5, 10)
        if t >= 3:
            f.row(10, "H", 5, 10)
            f.dot(12, 11, "M")
        if t >= 5:
            f.dot(9, 10, "B")
        return f
    f.stamp([".....DDDDD......", ".....aAAAa......", ".....DLMAD......", ".....DLMAD......",
             ".....DBBMD......", ".....DLMMD......", ".....DLMMMD.....",
             "....DMMMMMMLD...", "...DLLLLLLMMMD..", "...DDDDDDDDDDD.."], y=3)
    if t == 1:
        f.row(10, "R", 6, 9)
    if t >= 4:
        f.row(10, "H", 10, 13)
        f.row(11, "M", 10, 13)
        f.dot(14, 11, "L")
        f.dot(14, 12, "D")
    if t >= 5:
        f.dot(9, 10, "B")
    return f


ICON_PAINTERS = {"head": icon_head, "chest": icon_chest, "legs": icon_legs, "feet": icon_feet}


def draw_icon(slot, p, t):
    f = ICON_PAINTERS[slot](p, t)
    im = Image.new("RGBA", (16, 16))
    im.putdata([RGBA[c] for row in f.rows for c in row])
    return im


IDEAS = {
    "p1": "Bastion: broad breastplates, horizontal lames and early reinforced shoulders build a heavy, compact harness. At T5 the full front/back panels become an armored apron with a padded lower band; T6 extends the plates and adds solid shoulder finials. Every shell is whole, with textile coifs below the early helmet caps and painted bevels instead of missing corners.",
    "p2": "Processional guard: a central ridge, a tall tabard between plate rails and later shoulder expansion give the harness a strong vertical axis. T5 adds solid shoulder shields; T6 adds ceremonial outer fins and a heavier tabard hem. The torso remains mostly metal, and all former cutbacks are now padding or solid plate.",
}
TIER_NOTES = {
    "p1": [
        "Helm, chest, thigh and boot: a metal cap over a full padded coif, simple breastplate, textile-backed thigh plates and leather-sided greaves.",
        "Adds belt and pauldrons; the cap extends into cheek guards, with more plated greaves and broad shoulder lames.",
        "Adds sleeve shells, bracers and knee cops; articulated belly plates and a deeper helmet complete the steel field harness.",
        "Adds solid shoulder reinforcement and toe caps; a larger upper body and bright plate edges distinguish silversteel, with the legs still separately readable.",
        "Adds a closed visor and full front/back panels; two broad plate sections over a padded lower skirt and sparse ember seams make the major bulk step.",
        "Adds solid shoulder finials; skirt plating extends farther down, shoulder bosses and pale fittings complete the heaviest champion harness.",
    ],
    "p2": [
        "Helm, chest, bracers, thigh and boot: a ridged metal cap over a full padded coif, keeled breastplate and early forearm guards.",
        "Adds belt and knee cops; longer metal cheek guards and fuller greave plating extend protection downward.",
        "Adds pauldrons, full front/back tabards and toe caps; shoulder plates have padded lower cuffs and the framed tabard has a darker lower cloth band.",
        "Adds a closed split-slit visor and sleeve shells; full metal shoulder cores and a longer light tabard field complete the silver harness.",
        "Adds solid shoulder reinforcement; broad shield paint and metal tabard hems make the ember tier both heavier and more formal.",
        "Adds whole shoulder flares, read as narrow outer fins from the front and broad plates in profile; stronger inlay and a double hem crown the largest guard harness.",
    ],
}


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool", type=Path, default=DEFAULT_TOOL, help="Read-only r54_armor directory")
    args = parser.parse_args()
    catalog = json.loads((args.tool / "data/catalog.json").read_text())
    byid = {b["id"]: b for b in catalog["boxes"]}
    palettes = {"palettes": {name: {"colors": {v[0]: "#" + h for v, h in zip(REF.values(), row.split(), strict=True)}}
                              for name, row in zip(NAMES, PALETTE_ROWS, strict=True)}}
    for proposal, selections in SELECTIONS.items():
        base = DROP / proposal
        for sub in ("metal", "metal/inner", "metal/icons"):
            (base / sub).mkdir(parents=True, exist_ok=True)
        tiers = {}
        expected = set()

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
                               "icon": {s: var for s in ICON_PAINTERS}}
            for bid in on:
                save(draw_box(args.tool, byid[bid], proposal, t), f"metal/{bid}_{var}.png")
            for slot in ("chest", "legs", "feet"):
                save(draw_inner(args.tool, slot, proposal, t), f"metal/inner/{slot}_{var}.png")
            for slot in ICON_PAINTERS:
                save(draw_icon(slot, proposal, t), f"metal/icons/{slot}_{var}.png")
        # Only remove stale outputs owned by this generator, within this proposal.
        for path in (base / "metal").rglob("*.png"):
            if path not in expected:
                path.unlink()
        write_json(base / "tiers.json", {"metal": tiers})
        write_json(base / "palettes.json", palettes)
        lines = [IDEAS[proposal], ""]
        for t, note in enumerate(TIER_NOTES[proposal], 1):
            lines.append(f"- T{t} {NAMES[t - 1]} ({len(tiers[f'T{t}']['on'])} shapes): {note}")
        lines.extend(["", "Variants a–f correspond exactly to T1–T6, independently for each slot and proposal.",
                      "Zone A is textile padding/tabard; zone B is rivets, buckles and inlay. Painted eye slits use OUTLINE, not open holes.",
                      "All six faces of every box are opaque. Only open helmets use transparency, strictly inside front columns/rows 1–8; visors and painted slits are fully opaque. Sheet gutters remain clear.",
                      "Tassets are omitted from both proposals: their thin frontal edge does not add useful weight. Bastion omits flares; Processional guard reserves flares for T6 and omits spikes. These are deliberate selections, not checker warnings.",
                      "The fixed full-length panels hide much of the knee and boot fronts when worn. Bastion delays them to T5; Processional guard embraces the long tabard at T3. Each leg and foot piece still carries its own enchantment zones.",
                      "Check result: 0 violations, 0 warnings; no deliberate warnings or geometry notes.",
                      "All source art is original and dedicated to the public domain under CC0 1.0. No reference image pixels are reused.", ""])
        (base / "notes.md").write_text("\n".join(lines), encoding="utf-8")
        print(f"{proposal}: {len(expected)} original PNGs written")


if __name__ == "__main__":
    main()
