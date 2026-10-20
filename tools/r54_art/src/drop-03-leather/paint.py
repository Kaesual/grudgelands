#!/usr/bin/env python3
"""Original CC0 leather paint. Deterministic Python + Pillow; no sampled art.

Run from any directory. All writes stay under art/drop-03-leather.
Each named painter works in face-local texels. Inclusive rectangle endpoints.
Tiers have distinct variants a..f, so a chosen slot can be replaced independently.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

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
NAMES = ("light", "cured", "heavy_leather", "hardened", "sleek", "nightscale")
LABELS = ("Light", "Cured", "Heavy leather", "Hardened", "Sleek", "Nightscale")
# Same palette in both proposals: mixed slots retain a consistent material.
# Above-light is reserved; broad leather surfaces never use M_HI or GLOW.
PALETTE_ROWS = (
    "D7B994 C6A27A A37B52 795638 573C28 33291F 936B45 59402A D8CCB0 A09378 BEA475 826B45 C6A27A",
    "C19871 B08660 88603F 60412B 432E20 2D241C 9B7651 49301E C8B898 94836A C5A773 887047 B08660",
    "AD8764 937052 6C4D35 4C3526 35271D 241E19 96714F 422D20 B7A588 7F725D CBAA76 8D7049 937052",
    "B98C66 A17450 7D4E31 573623 3A281C 271E18 A48158 462C1B BAA687 867258 D2B17A 917148 A17450",
    "ACA5A2 8D8887 646268 44434B 302F38 211F28 8F7963 484039 B2ABA7 7D777B C1B7AD 827B80 8D8887",
    "AAA0B9 82788F 51495F 373143 272232 1B1923 83717A 40323F ADA1B8 776884 BAA6D3 817096 82788F",
)
SELECTIONS = {
    "p1": (
        "helm chest boot",
        "helm chest belt thigh boot",
        "helm chest belt panel_b sleeve thigh boot",
        "helm chest belt panel_b sleeve bracer thigh boot",
        "helm chest belt panel_b sleeve bracer pauldron thigh knee boot",
        "helm chest belt panel_f panel_b sleeve bracer pauldron thigh knee boot",
    ),
    "p2": (
        "helm chest boot",
        "helm chest belt pauldron boot",
        "helm chest belt sleeve pauldron thigh boot",
        "helm chest belt sleeve bracer pauldron thigh knee boot",
        "helm chest belt sleeve bracer pauldron thigh knee boot toe",
        "helm chest belt sleeve bracer pauldron reinforce thigh knee boot toe",
    ),
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

    def stamp(self, rows, x=0, y=0):
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                self.dot(x + i, y + j, c)

    def image(self):
        im = Image.new("RGBA", (self.w, self.h))
        im.putdata([RGBA[c] for row in self.rows for c in row])
        return im


def surface(w, h, side):
    """Matte hide, an interrupted single-pixel upper light, shaded corners."""
    fill = {"top": "M", "bottom": "D", "back": "S", "left": "S"}.get(side, "M")
    f = Face(w, h, fill)
    if side == "top":
        f.row(1 if h > 2 else 0, "L", 1, w - 2)
    elif side != "bottom":
        f.row(0, "L" if side != "back" else "M", 1, w - 2)
        f.row(h - 1, "S")
        f.dot(0, 0, "S")
        f.dot(w - 1, 0, "S")
        f.dot(0, h - 1, "D")
        f.dot(w - 1, h - 1, "D")
    return f


def scales(f, x0, y0, x1, y1, kind="round", subdued=False):
    """A few 3x3 scallops / long overlapping leaves, never pixel noise."""
    for row, y in enumerate(range(y0, y1 + 1, 3)):
        for x in range(x0 - (row % 2) * 2, x1 + 1, 4):
            points = ((0, 0, "M"), (1, 0, "L"), (2, 0, "L"), (3, 0, "M"),
                      (0, 1, "M"), (1, 1, "M"), (2, 1, "M"), (3, 1, "S"),
                      (0, 2, "S"), (1, 2, "M"), (2, 2, "S"), (3, 2, "S"))
            if kind == "leaf":
                points = ((0, 0, "M"), (1, 0, "L"), (2, 0, "M"), (3, 0, "S"),
                          (0, 1, "M"), (1, 1, "L"), (2, 1, "M"), (3, 1, "S"),
                          (0, 2, "S"), (1, 2, "M"), (2, 2, "S"), (3, 2, "S"))
            for dx, dy, c in points:
                if x0 <= x + dx <= x1 and y0 <= y + dy <= y1:
                    f.dot(x + dx, y + dy, {"L": "M", "M": "S", "S": "S"}.get(c, c) if subdued else c)


def hood(f, side, p, t):
    if side == "bottom":
        f.rect(0, 0, 9, 9, "a")
        return
    if p == "p1":
        if side == "front":
            f.stamp([
                "SMLLLLLMSS", "MLMMMMMMLS", "MA......aM", "MA......aM", "Ma......aS",
                "Sa......aS", "Sa......aS", "Sa......aS", "SaB....BaS", "SaAAABaaaS",
            ])
            if t >= 2:
                f.dot(2, 1, "B")
                f.dot(7, 1, "b")
                f.dot(1, 7, "R")
            if t >= 3:
                f.stamp(["SMMLLLMMSS", "MLSRRRSMLS"], y=0)
                f.dot(2, 2, "A")
                f.dot(7, 2, "a")
            if t == 4:
                f.row(1, "R", 3, 6)
                f.dot(4, 1, "B")
                f.dot(5, 1, "b")
            if t >= 5:
                f.stamp(["SMLMLMLMSS", "MLMSMSMMLS"], y=0)
                f.dot(0, 4, "B")
                f.dot(9, 4, "b")
            if t == 6:
                # A leather dust wrap inside the permitted opening; eyes stay open.
                f.row(7, "R", 2, 7)
                f.row(8, "M", 3, 6)
                f.dot(4, 7, "B")
                f.dot(5, 8, "b")
                f.dot(2, 6, "a")
                f.dot(7, 6, "a")
            return
        if side == "top":
            f.col(4, "S", 1, 8)
            f.col(5, "M", 1, 8)
            if t >= 3:
                f.dot(4, 2, "R")
                f.dot(4, 6, "R")
            if t >= 5:
                f.col(2, "R", 2, 7)
                f.col(7, "r", 2, 7)
                if t == 6:
                    f.dot(2, 2, "B")
                    f.dot(7, 7, "b")
            return
        f.row(9, "a", 1, 8)
        if side == "back":
            f.col(4, "S", 2, 7)
            f.col(5, "M", 2, 7)
            # A sewn fold turns toward the nape, not a bright plated rim.
            f.stamp(["SSMMSSMMSS", "SSSMLLMSSS", "SSSaAAaSSS"], y=6)
            if t >= 3:
                f.dot(4, 4, "R")
            if t >= 5:
                # The leather hood stays calm behind the scalloped brow trim.
                f.row(2, "M", 2, 7)
                f.dot(3, 3, "R")
                f.dot(6, 3, "R")
        else:
            front_x = 8 if side == "right" else 1
            f.col(front_x, "R", 2, 7)
            f.dot(front_x, 7, "B")
            f.dot(front_x - 1 if side == "right" else front_x + 1, 8, "A")
            if t >= 4:
                f.col(4, "M", 2, 6)
                f.dot(4, 3, "b")
            if t >= 5:
                f.row(2, "M", 2, 6)
                f.dot(3, 3, "R")
                if t == 6:
                    f.dot(5, 4, "B")
    else:
        # Stitched cap plus an opaque textile coif. Its lower half is paint,
        # never an absent side of the fixed helmet box.
        if side == "front":
            f.stamp([
                "SMLLLLMSSS", "LMMRMMRMLS", "SMMRMMRMSS", "aAAABBAAaa", "a........a",
                "a........a", "a........a", "a........a", "aB......Ba", "aaaAAAAaaa",
            ])
            if t >= 2:
                f.dot(2, 2, "B")
                f.dot(7, 2, "b")
            if t >= 3:
                f.dot(1, 4, "M")
                f.dot(8, 4, "S")
                f.dot(1, 5, "M")
                f.dot(8, 5, "S")
            if t >= 4:
                f.col(1, "M", 5, 7)
                f.col(8, "S", 5, 7)
                f.dot(1, 7, "B")
                f.dot(8, 7, "b")
            if t >= 5:
                f.stamp(["SMLMLMLMSS", "LMMRMMRMLS", "SMLRMLRMSS"])
            if t == 6:
                f.dot(2, 1, "B")
                f.dot(7, 1, "b")
                f.row(9, "R", 3, 6)
            return
        if side == "top":
            f.col(3, "R", 0, 9)
            f.col(6, "R", 0, 9)
            if t >= 5:
                f.row(3, "M", 1, 8)
                f.dot(3, 2, "B")
                if t == 6:
                    f.dot(6, 6, "b")
            return
        cap_end = (3, 4, 5, 6, 6, 7)[t - 1]
        f.rect(0, cap_end, 9, 9, "a")
        f.row(cap_end, "R")
        f.col(4, "A", cap_end + 1, 8)
        f.col(5, "A", cap_end + 1, 8)
        f.col(3, "R", 0, cap_end - 1)
        f.col(6, "R", 0, cap_end - 1)
        if t >= 2:
            f.dot(4, cap_end, "B")
        if t >= 5:
            f.row(cap_end - 1, "M", 1, 8)
            f.dot(3, cap_end - 2, "b")
            if t == 6:
                f.dot(6, cap_end - 2, "B")


def chest(f, side, p, t):
    if side in ("top", "bottom"):
        if side == "top":
            f.rect(2, 1, 6, 3, "a")
        return
    if side in ("left", "right"):
        f.col(2, "R", 3, 9)
        f.dot(2, 5, "b")
        f.row(11, "r")
        f.row(12, "a")
        if t >= 3:
            f.col(1, "S", 2, 8)
        if t >= 5:
            scales(f, 1, 3, 3, 8, "round" if p == "p1" else "leaf", subdued=True)
        return
    if side == "back":
        f.row(1, "M", 2, 6)
        f.row(2, "a", 3, 5)
        if p == "p1":
            for y in range(3, 10):
                x = 1 + (y - 3) // 2
                f.dot(x, y, "R")
                f.dot(x + 1, y, "r")
            f.col(6, "M", 3, 9)
        else:
            f.col(2, "M", 3, 9)
            f.col(6, "M", 3, 9)
            f.row(4, "R", 2, 6)
        f.row(11, "r")
        f.row(12, "R", 1, 7)
        if t >= 4:
            f.dot(2, 8, "b")
            f.dot(6, 8, "b")
        if t >= 5:
            scales(f, 2, 5, 6, 9, "round" if p == "p1" else "leaf", subdued=True)
        return
    if p == "p1":
        f.stamp([
            "SaAAAAaaS", "MaAAAAaMM", "MMAaaMMMS", "LMMMMMMMS", "MMMMMMMMS",
            "MMMMMMMMS", "MMMMMMMMS", "MMMMMMMMS", "MMMMMMMMS", "SMMMMMMSS",
            "SRRRRRRrS", "SrrBBrrrS", "aMMMMMMMa", "aaSSSSSaa",
        ])
        if t == 1:
            f.rect(3, 3, 4, 5, "A")
            f.dot(3, 6, "a")
        if t >= 3:
            f.col(1, "R", 4, 8)
            f.col(7, "S", 4, 8)
            f.row(9, "R", 2, 6)
        if t == 4:
            # Broad shaped boiled-hide insert; emphatically no scales on T4.
            f.stamp(["MLLLM", "LMMMS", "MMMMS", "MMMMS", "MSSSM"], x=2, y=4)
            f.dot(2, 8, "B")
            f.dot(6, 8, "b")
        if t >= 5:
            scales(f, 1, 4, 7, 8)
            if t == 6:
                scales(f, 1, 2, 7, 9)
                f.row(10, "A", 1, 7)
        # One continuous asymmetrical sling dominates the design.
        for y in range(2, 10):
            x = 7 - (y - 2) * 6 // 7
            f.dot(x, y, "R")
            f.dot(x - 1, y, "r")
        f.stamp(["Bb", "bR"], x=4, y=4)
        if t >= 2:
            f.dot(2, 9, "b")
        if t >= 6:
            f.dot(7, 9, "B")
    else:
        f.stamp([
            "SaAAAAaaS", "MLAaAAMMS", "LMMAaMMMS", "LMMaMMMMS", "MMMRSMMMS",
            "MMMRSMMMS", "MMMRSMMMS", "MMMRSMMMS", "MMMRSMMMS", "SMMRSMMSS",
            "SRRRRRRrS", "SrrBBrrrS", "aMMMMMMMa", "aaSSSSSaa",
        ])
        f.stamp(["BbB"], x=2, y=4)
        f.dot(3, 7, "B")
        if t >= 2:
            f.stamp(["BbB"], x=2, y=7)
            f.col(6, "S", 4, 9)
        if t >= 3:
            f.row(3, "R", 5, 7)
            f.dot(6, 4, "b")
            f.row(9, "R", 1, 7)
        if t == 4:
            f.col(1, "L", 4, 7)
            f.col(6, "L", 5, 8)
            f.dot(1, 8, "S")
            f.dot(7, 5, "b")
        if t >= 5:
            scales(f, 5, 4, 7, 9, "leaf")
            if t == 6:
                scales(f, 0, 4, 2, 9, "leaf")
                f.dot(3, 9, "B")
                f.row(10, "A", 1, 7)


def belt(f, side, p, t):
    f.rect(0, 0, f.w - 1, f.h - 1, "r")
    if side in ("top", "bottom"):
        if side == "top":
            f.row(f.h - 1, "R", 1, f.w - 2)
        return
    f.row(0, "R")
    if side == "front":
        x = 2 if p == "p1" else 5
        f.stamp(["BB", "bR"], x=x)
        if t >= 3:
            f.dot(8 if p == "p1" else 1, 1, "b")
        if t >= 5:
            f.dot(7 if p == "p1" else 2, 0, "B")
    elif side in ("left", "right") and t >= 3:
        f.dot(2, 0, "b")


def sleeve(f, side, p, t):
    if side == "bottom":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")
        return
    if side == "top":
        return
    f.rect(0, 6, 4, 12, "a")
    if side in ("front", "right"):
        f.rect(1, 7, 3, 11, "A")
    f.row(6, "R")
    f.col(3 if side == "right" else 1, "S", 2, 5)
    f.dot(1, 5, "b")
    if t >= 4:
        f.rect(0, 6, 4, 9, "S")
        f.row(6, "M", 1, 3)
    if t >= 5:
        scales(f, 1, 1, 3, 5, "round" if p == "p1" else "leaf", subdued=True)


def bracer(f, side, p, t):
    if side in ("top", "bottom"):
        return
    f.row(0, "R", 1, 4)
    f.row(4, "r")
    if p == "p1":
        f.col(4, "R", 1, 3)
        f.dot(4, 1, "B")
        f.dot(4, 3, "b")
        f.col(1, "L", 1, 2)
    else:
        f.row(2, "R")
        f.dot(2, 2, "B")
        f.dot(3, 2, "b")
    if t >= 5:
        scales(f, 1, 1, 3, 3, "round" if p == "p1" else "leaf")
        f.dot(4, 3, "B")


def shoulder(f, side, p, t, reinforced=False):
    if side == "bottom":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")
        return
    if side == "top":
        f.col(2, "R", 1, f.h - 2)
        if t >= 5:
            scales(f, 1, 1, f.w - 2, f.h - 2, "round" if p == "p1" else "leaf")
        return
    # Lower textile remains fully opaque; painted diagonal welt rounds the pad.
    f.row(f.h - 1, "a")
    f.dot(0, f.h - 2, "a")
    f.dot(f.w - 1, f.h - 2, "a")
    f.row(f.h - 2, "R" if t < 5 else "S", 1, f.w - 2)
    f.dot(0, f.h - 3, "R" if t < 5 else "S")
    f.dot(f.w - 1, f.h - 3, "r")
    f.dot(1, 1, "B")
    if t >= 3:
        f.col(2, "R", 2, 3)
        f.dot(3, 3, "b")
    if t >= 4:
        f.row(2, "M", 2, f.w - 2)
        f.dot(f.w - 2, 3, "B")
    if t >= 5:
        scales(f, 1, 1, f.w - 2, f.h - 3, "round" if p == "p1" else "leaf")
    if reinforced:
        f.row(f.h - 1, "r", 1, f.w - 2)
        f.dot(1, f.h - 2, "B")
        f.dot(f.w - 2, f.h - 2, "b")


def panel(f, side, p, t, back=False):
    if side in ("top", "bottom"):
        return
    if f.w == 1:
        f.rect(0, 0, 0, f.h - 1, "S")
        f.dot(0, 9, "R")
        return
    f.rect(0, 0, 6, 10, "M" if side == "front" else "S")
    if back:
        # Full-length coat tail. The central dark fold is paint on solid hide.
        f.col(3, "D", 2, 10)
        f.col(4, "M", 3, 8)
        f.col(1, "R", 1, 8)
        f.col(5, "R", 1, 8)
        f.row(9, "R", 1, 5)
        f.row(10, "a")
        f.row(0, "A", 1, 5)
        f.dot(1, 2, "b")
        f.dot(5, 2, "b")
        if t >= 4:
            f.dot(1, 6, "B")
            f.dot(5, 6, "b")
        if t >= 5:
            scales(f, 1, 1, 5, 5, subdued=side == "front")
        if t == 6:
            scales(f, 1, 4, 5, 8, subdued=side == "front")
            f.dot(1, 8, "B")
            f.dot(5, 8, "b")
    else:
        # Short scaled overskirt PAINTED over an opaque long textile lining.
        f.rect(0, 5, 6, 10, "a")
        f.rect(1, 5, 5, 8, "A")
        f.col(3, "a", 6, 10)
        f.row(0, "R")
        scales(f, 0, 1, 6, 4)
        f.dot(1, 1, "B")
        f.dot(3, 1, "B")
        f.dot(5, 1, "B")
        f.row(4, "R")
        f.row(9, "R", 1, 5)
        f.dot(1, 8, "b")
        f.dot(5, 8, "b")


def thigh(f, side, p, t):
    if side in ("top", "bottom"):
        return
    if side == "front":
        f.stamp(["ABBM", "AMMS", "aMMS", "aSDS"] if p == "p1" else
                ["MBBA", "LMMA", "MMSa", "SDSa"])
        if t >= 4:
            f.dot(2 if p == "p1" else 1, 1, "L")
        if t >= 5:
            f.stamp(["LM", "SD"], x=1, y=1)
        if t == 6:
            f.dot(2, 2, "B")
    elif side == "back":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")
        f.row(1, "R")
        f.dot(1, 1, "b")
    else:
        f.row(1, "R")
        f.dot(2, 1, "b")
        if t >= 5:
            scales(f, 1, 1, 3, 3, "round" if p == "p1" else "leaf")


def knee(f, side, p, t):
    if side in ("top", "bottom"):
        return
    if side == "front":
        f.stamp(["MLMS", "MMbM", "aSSa"] if p == "p1" else ["SLLS", "MBMS", "aSSa"])
        if t == 6:
            f.dot(2, 0, "B")
    else:
        f.row(1, "R")
        f.dot(2, 1, "b")


def boot(f, side, p, t):
    if side == "bottom":
        f.rect(0, 0, f.w - 1, f.h - 1, "D")
        return
    if side == "top":
        f.rect(0, 0, f.w - 1, f.h - 1, "a")
        f.row(f.h - 1, "M", 1, f.w - 2)
        return
    if side == "front":
        patterns = {
            "p1": (
                ["aAAa", "RMMr", "MBbM", "rRMS", "MMRS", "SDDS"],
                ["aAAa", "RLLr", "MBbM", "rMMS", "MRRS", "SDDS"],
                ["aAAa", "MLLM", "RBbr", "RMMS", "RMMS", "SDDS"],
                ["aAAa", "MLLM", "RBbr", "RLMS", "RMSM", "SDDS"],
                ["aAAa", "MLLM", "RBbr", "RMLS", "RSMS", "SDDS"],
                ["aAAa", "BLMb", "RBbr", "RLMS", "RMBS", "SDDS"],
            ),
            "p2": (
                ["aAAa", "MLMR", "BbMR", "MSRr", "MMSR", "SDDS"],
                ["aAAa", "MLMR", "BbMR", "RRRr", "MMSR", "SDDS"],
                ["aAAa", "MLLM", "BbMR", "MMMR", "RRRr", "SDDS"],
                ["aAAa", "MLLM", "BbMR", "MLMR", "RRRr", "SDDS"],
                ["aAAa", "MLLM", "BbMR", "MSMR", "RRRr", "SDDS"],
                ["aAAa", "bLMB", "BbMR", "MLMR", "RRRr", "SDDS"],
            ),
        }
        f.stamp(patterns[p][t - 1])
        return
    f.row(0, "a")
    f.row(5, "D")
    if t < 3:
        for y in range(1, 5):
            x = y - 1 if p == "p1" else 5 - y
            f.dot(x, y, "R")
            f.dot(x + 1, y, "r")
    else:
        f.row(1, "M", 1, f.w - 2)
        f.col(2 if p == "p1" else 3, "R", 2, 4)
    f.dot(2, 2, "B")
    if t >= 4:
        f.dot(2, 4, "b")
    if t >= 5:
        f.dot(1, 3, "M")
        f.dot(1, 4, "S")


def toe(f, side, p, t):
    if side == "front":
        f.stamp(["MLMS", "MMMS", "SDDS"])
        if t == 6:
            f.dot(1, 1, "B")
    elif side == "top":
        f.row(0, "R")
        f.row(1, "M")


PAINTERS = {"helm": hood, "chest": chest, "belt": belt, "sleeve": sleeve,
            "bracer": bracer, "pauldron": shoulder, "thigh": thigh,
            "knee": knee, "boot": boot, "toe": toe,
            "reinforce": lambda *args: shoulder(*args, reinforced=True),
            "panel_f": panel, "panel_b": lambda *args: panel(*args, back=True)}


def draw_box(box, p, t):
    im = Image.new("RGBA", tuple(box["sheet"]))
    for side, (x0, y0, w, h) in box["faces"].items():
        f = surface(w, h, side)
        PAINTERS[box["id"]](f, side, p, t)
        for y, row in enumerate(f.rows):
            for x, c in enumerate(row):
                if c == ".":
                    assert box["id"] == "helm" and side == "front" and 1 <= x <= 8 and 1 <= y <= 8
                im.putpixel((x0 + x, y0 + y), RGBA[c])
    return im


def draw_inner(slot, p, t):
    f = Face(64, 32)
    if slot == "chest":
        f.rect(16, 16, 39, 31, "a")
        f.rect(20, 20, 27, 31, "A")
        # Rolled linen sleeves at low tiers, exposed skin below the roll.
        f.rect(40, 16, 55, 26, "a")
        f.rect(44, 20, 47, 25, "A")
        f.row(26, "A", 40, 55)
        if t >= 2:
            f.rect(40, 20, 55, 22, "M")
            f.row(20, "L", 44, 46)
            f.dot(45, 22, "b")
        if t >= 3:
            f.rect(40, 23, 55, 30, "a")
            f.rect(44, 24, 47, 29, "A")
            f.row(30, "R", 40, 55)
        f.row(29, "R", 20, 27)
    elif slot == "legs":
        f.rect(0, 20, 15, 27, "a")
        f.rect(4, 20, 7, 27, "A")
        f.col(4 if p == "p1" else 7, "a", 20, 27)
        f.rect(5, 23, 6, 25, "M")
        f.row(24, "R", 0, 15)
        f.dot(5, 24, "B")
        f.dot(6, 24, "b")
        # Top skin pixels emerge above thigh shells; lower cloth at the knee.
        if t >= 2:
            f.rect(0, 25, 15, 27, "S")
            f.rect(4, 25, 7, 26, "a")
        if t >= 4:
            f.row(26, "R", 4, 7)
    else:
        f.rect(0, 28, 15, 31, "S")
        f.row(31, "D", 0, 15)
        f.rect(4, 28, 7, 30, "M")
    return f.image()


def icon_head(p, t):
    f = Face(16, 16)
    if p == "p1":
        f.stamp([
            "......DDD.......", "....DMLLLMD.....", "...DMMMMMMMD....", "..DMMMAAaMMMD...",
            "..DMMA...aMSD...", "..DMA.....aSD...", "..DMA.....aSD...", "..DMa.....aSD...",
            "..DMa.....aSD...", "..DMa.....aSD...", "...MRB...BRD....", "...DRRAAarD.....",
            "....DRBrrD......", ".....DDD........",
        ], y=1)
        if t >= 3:
            f.row(3, "R", 5, 9)
            f.dot(3, 10, "B")
        if t >= 5:
            f.dot(5, 2, "L")
            f.dot(7, 3, "S")
            f.dot(9, 2, "L")
        if t == 6:
            f.row(10, "R", 5, 9)
            f.row(11, "M", 6, 8)
            f.dot(7, 10, "B")
    else:
        f.stamp([
            ".....DDDDD......", "...DMLLRMMD.....", "..DMMMRMMRMD....", "..DMMMRMMRMSD...",
            "..DRRRBBRRRrD...", "...AA.....aa....", "...Aa.....aa....", "...Aa.....aa....",
            "...Aa.....aa....", "...AB.....Ba....", "....AAaaaAa.....", ".....DrrrD......",
        ], y=2)
        if t >= 2:
            f.dot(4, 5, "B")
        if t >= 3:
            f.rect(3, 7, 4, 8, "M")
            f.rect(10, 7, 11, 8, "S")
        if t >= 4:
            f.rect(3, 8, 4, 10, "M")
            f.rect(10, 8, 11, 10, "S")
            f.dot(4, 10, "B")
        if t >= 5:
            f.row(3, "L", 5, 6)
            f.dot(8, 4, "L")
        if t == 6:
            f.dot(10, 3, "B")
            f.dot(10, 10, "b")
    return f


def icon_chest(p, t):
    f = Face(16, 16)
    f.stamp([
        "....DD...DD.....", "...DMMAAaMMD....", "..DMMMAaMMMMD...", "..DMMMaaMMMMD...",
        "...DMMMMMMMD....", "...DMMMMMMMD....", "...DMMMMMMMD....", "...DMMMMMMMD....",
        "...DMMMMMMMD....", "...DRRRRRRrD....", "...DRRRBBrrD....", "...DMMSMMMMD....",
        "....DDDDDDD.....",
    ], y=1)
    if t >= 3:
        f.col(2, "M", 5, 8)
        f.col(12, "S", 5, 8)
        f.dot(2, 9, "a")
        f.dot(12, 9, "a")
    if t >= 4:
        f.stamp(["RM", "Bb"], x=1, y=8)
        f.stamp(["MS", "bB"], x=12, y=8)
    if t >= (5 if p == "p1" else 2):
        f.stamp(["MLLM", "MMSM", "aRRr"], x=1, y=2)
        f.stamp(["MLMS", "MSSM", "RRra"], x=11, y=2)
    if t >= 5:
        scales(f, 4, 6, 10, 9, "round" if p == "p1" else "leaf")
    if p == "p1":
        for y in range(2, 11):
            x = 10 - (y - 2) * 6 // 8
            f.dot(x, y, "R")
            f.dot(x - 1, y, "r")
        f.stamp(["BB", "bR"], x=7, y=5)
    else:
        f.col(6, "R", 5, 9)
        f.row(6, "B", 5, 7)
        if t >= 2:
            f.row(9, "b", 5, 7)
        if t == 6:
            f.stamp(["MLLM", "MBMM"], x=0, y=2)
            f.stamp(["MLMS", "MMbS"], x=12, y=2)
    return f


def icon_legs(p, t):
    f = Face(16, 16)
    if p == "p1" and t >= 3:
        # Three-quarter trousers in front of a visible long rear tail.
        f.stamp([
            "...DRRRRRRD.....", "...DAAAAaMRD....", "...DAAAAaMSRD...", "...DABBMaMSRD...",
            "...DAMMMaMSRD...", "...DAMSaaMSRD...", "...DAMS.aMSRD...", "...DAMS.aMSRD...",
            "...DaSS.aMSRD...", "...DaSS.aMSRD...", "....DDD.DRRRD...", ".........DDD....",
        ], y=2)
        if t >= 4:
            f.dot(12, 7, "B")
        if t >= 5:
            scales(f, 9, 4, 11, 8)
            f.dot(5, 10, "B")
        if t == 6:
            f.rect(4, 4, 9, 7, "M")
            scales(f, 4, 4, 9, 7)
            f.rect(4, 8, 9, 11, "A")
            f.col(7, "a", 8, 11)
            f.row(12, "R", 4, 9)
            f.row(4, "B", 5, 7)
        return f
    f.stamp([
        "....DRRRRRD.....", "...DAAAAAaaD....", "...DAAAAAaaD....", "...DABBaBBaD....",
        "...DAMMaMMaD....", "...DAMMaMMaD....", "...DAMS.aMSD....", "...DAMS.aMSD....",
        "...DaSS.aSSD....", "....DDD.DDD.....",
    ], y=3)
    if t >= (2 if p == "p1" else 3):
        f.rect(4, 6, 5, 9, "M")
        f.rect(9, 6, 10, 9, "M")
        f.dot(4, 6, "B")
        f.dot(10, 6, "b")
    if t >= 4:
        f.stamp(["MLM", "MBM"], x=3, y=10)
        f.stamp(["MLS", "MbM"], x=8, y=10)
    if t >= 5:
        f.dot(4, 7, "L")
        f.dot(9, 8, "L")
    if t == 6:
        f.dot(5, 8, "B")
        f.dot(10, 8, "b")
    return f


def icon_feet(p, t):
    f = Face(16, 16)
    if p == "p1":
        f.stamp([
            ".....DDDDD......", ".....aAAAa......", ".....RMMMr......", ".....MRMMD......",
            ".....MBBMD......", ".....MMSMD......", ".....MMSMD......", "....DMMMSMD.....",
            "...DMMMMMMMD....", "..DMMMMMMMMMD...", "...DDDDDDDDD....",
        ], y=3)
        if t >= 3:
            f.row(5, "L", 6, 8)
            f.col(6, "R", 6, 9)
        if t >= 4:
            f.dot(6, 9, "b")
        if t >= 5:
            f.stamp(["LM", "SD"], x=8, y=8)
        if t == 6:
            f.dot(8, 5, "B")
    else:
        f.stamp([
            ".....DDDDD......", "....DaAAAaD.....", "....DMMLMrD.....", "....DMMMRrD.....",
            "....DBBMrrD.....", "....DMMMRrD.....", "....DMMMRrD.....", "....DMMMRrD.....",
            "....DMMMMSMD....", "....DMMMMMMMD...", ".....DDDDDDD....",
        ], y=3)
        if t >= 2:
            f.row(8, "R", 5, 9)
        if t >= 3:
            f.row(5, "L", 5, 9)
        if t >= 4:
            f.dot(9, 9, "B")
        if t >= 5:
            f.row(11, "R", 7, 11)
            f.row(12, "M", 7, 11)
        if t == 6:
            f.dot(9, 5, "B")
            f.dot(10, 12, "b")
    return f


ICON_PAINTERS = {"head": icon_head, "chest": icon_chest, "legs": icon_legs, "feet": icon_feet}
IDEAS = {
    "p1": "Trail coat: a hood, one diagonal sling and a long rear coat tail make a narrow, travelling silhouette. Rounded scallops spread from the upper coat at T5 to a scaled overskirt at T6, with an opaque textile lower lining and a leather dust wrap below the eyes. The coat stays open at the front through T5 by omitting the front panel entirely.",
    "p2": "Toggle jerkin: a stitched cap over a textile coif, an offset toggle jerkin and separate leg guards form a compact field harness. Shoulder pads arrive early, while long leaf-shaped scales and a final shoulder cap make the upper tiers richer without a long skirt. The face stays open throughout.",
}
TIER_NOTES = {
    "p1": (
        "Helm, chest, boot; a plain lined hood, sling over a light jerkin, rolled shirt sleeves, cloth trousers with knee patches and wrapped boots.",
        "Adds belt and thigh shells; hood clasp, doubled boot cuff and stronger sewn thigh patches add structure.",
        "Adds sleeve shells and full rear coat panel; a bound hood, cuffed boots and long stitched tail establish the coat silhouette.",
        "Adds bracers; broad boiled-hide chest insert, stronger hood binding and doubled tail stitches. Hardened leather, no scales.",
        "Adds shoulder cores and knees; rounded scales begin on chest, shoulders, upper tail and small limb inserts.",
        "Adds the full front panel: scaled upper skirt over a long textile lining; scales extend down the rear tail, while a lower-face leather wrap and extra boot fittings complete the set.",
    ),
    "p2": (
        "Helm, chest, boot; a stitched cap above a full cloth coif, single-toggle jerkin, rolled shirt sleeves, cloth trousers and side-strapped boots.",
        "Adds belt and shoulder cores; a second toggle and a second boot strap make the first layered harness.",
        "Adds sleeve and thigh shells; sewn shoulder layering, a bound jerkin hem, deeper cap and folded boot cuffs.",
        "Adds bracers and knee shells; broad boiled-hide panels, longer cheek straps and reinforced boots. Hardened leather, no scales.",
        "Adds toe caps; long leaf scales appear on one chest panel, shoulders and thigh guards, leaving calm leather between them.",
        "Adds shoulder reinforcement; leaf scales spread to both chest panels, the cap deepens and paired fittings finish the boots and guards.",
    ),
}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool", type=Path, default=TOOL)
    args = parser.parse_args()
    catalog = json.loads((args.tool / "data/catalog.json").read_text())
    boxes = {b["id"]: b for b in catalog["boxes"]}
    palettes = {"palettes": {name: {"name": label, "colors": {
        pair[0]: "#" + value for pair, value in zip(REF.values(), row.split(), strict=True)}}
        for name, label, row in zip(NAMES, LABELS, PALETTE_ROWS, strict=True)}}
    for p, choices in SELECTIONS.items():
        base = DROP / p
        for sub in ("leather", "leather/inner", "leather/icons"):
            (base / sub).mkdir(parents=True, exist_ok=True)
        expected = set()

        def save(im, rel):
            path = base / rel
            im.save(path, compress_level=9)
            expected.add(path)

        tiers = {}
        for t, choice in enumerate(choices, 1):
            var = chr(96 + t)
            on = choice.split()
            tiers[f"T{t}"] = {"palette": NAMES[t - 1], "on": on,
                              "variant": {bid: var for bid in on},
                              "inner": {s: var for s in ("chest", "legs", "feet")},
                              "icon": {s: var for s in ICON_PAINTERS}}
            for bid in on:
                save(draw_box(boxes[bid], p, t), f"leather/{bid}_{var}.png")
            for slot in ("chest", "legs", "feet"):
                save(draw_inner(slot, p, t), f"leather/inner/{slot}_{var}.png")
            for slot, painter in ICON_PAINTERS.items():
                save(painter(p, t).image(), f"leather/icons/{slot}_{var}.png")
        for path in (base / "leather").rglob("*.png"):
            if path not in expected:
                path.unlink()
        write_json(base / "tiers.json", {"leather": tiers})
        write_json(base / "palettes.json", palettes)
        notes = [IDEAS[p], ""]
        notes.extend(f"- T{t} {LABELS[t - 1]} ({len(tiers[f'T{t}']['on'])} shapes): {note}"
                     for t, note in enumerate(TIER_NOTES[p], 1))
        notes.extend(["", "Zone A: hood/coif lining, shirt, trousers, boot cuff and skirt lining. Zone B: clasps, buckles and occasional decorative stitches.",
                      "Every box face is opaque except the permitted helm face window. Shorter leather sections and split folds are painted onto whole opaque parts. No visor, tassets, flares or spikes are worn; their fixed silhouettes do not serve these designs.",
                      "Variants a–f identify T1–T6 in both proposals, independently per slot. Both proposals use identical palettes, allowing slot mixing within a tier.",
                      "Check outcomes are recorded in ../checks/summary.json and ../report.md. Omitted shapes are deliberate selections, not warnings.",
                      "Original art, CC0 1.0. No image pixels are sampled from references, templates or earlier art.", ""])
        (base / "notes.md").write_text("\n".join(notes), encoding="utf-8")
        print(f"{p}: {len(expected)} original PNGs written")


if __name__ == "__main__":
    main()
