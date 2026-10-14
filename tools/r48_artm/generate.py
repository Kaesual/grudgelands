#!/usr/bin/env python3
"""Round 48 ARTM proposals. Original pixel art, GPT-6 Astra, CC0-1.0.

Python 3 standard library only. Run from any directory; --check is read-only.
All paths written are below this script. Existing CC0 waystone and cooldown
images are read only for the previews. No fonts, downloads or engine runs.
"""

import argparse
import hashlib
import json
import math
import struct
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DATE = "2026-10-14"
CLEAR = (0, 0, 0, 0)


def color(value):
    return tuple(bytes.fromhex(value.lstrip("#"))) + (255,) if isinstance(value, str) else value


class Image:
    """Small integer raster: opaque painting and RGBA source-over blits."""

    def __init__(self, w, h, fill=CLEAR):
        self.w, self.h = w, h
        self.p = [color(fill)] * (w * h)

    def get(self, x, y):
        return self.p[y * self.w + x]

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[y * self.w + x] = color(c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if (x0, y0) == (x1, y1):
                return
            e = 2 * err
            if e >= dy:
                err += dy
                x0 += sx
            if e <= dx:
                err += dx
                y0 += sy

    def poly(self, points, c):
        for y in range(min(p[1] for p in points), max(p[1] for p in points) + 1):
            hits = []
            for a, b in zip(points, points[1:] + points[:1]):
                if min(a[1], b[1]) <= y + 0.5 < max(a[1], b[1]):
                    hits.append(a[0] + (y + 0.5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
            hits.sort()
            for a, b in zip(hits[::2], hits[1::2]):
                self.rect(math.ceil(a - 0.5), y, math.floor(b - 0.5), y, c)
        for a, b in zip(points, points[1:] + points[:1]):
            self.line(*a, *b, c)

    def ellipse(self, x0, y0, x1, y1, c):
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        rx, ry = (x1 - x0 + 1) / 2, (y1 - y0 + 1) / 2
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                    self.put(x, y, c)

    def blit(self, other, x0, y0):
        for y in range(other.h):
            for x in range(other.w):
                s = other.get(x, y)
                if not s[3] or not (0 <= x + x0 < self.w and 0 <= y + y0 < self.h):
                    continue
                d = self.get(x + x0, y + y0)
                a = s[3] + d[3] * (255 - s[3]) / 255
                c = tuple(round((s[k] * s[3] + d[k] * d[3] * (255 - s[3]) / 255) / a)
                          for k in range(3)) + (round(a),)
                self.put(x + x0, y + y0, c)

    def scale(self, n):
        out = Image(self.w * n, self.h * n)
        out.p = [self.get(x // n, y // n) for y in range(out.h) for x in range(out.w)]
        return out


def png(im):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)
    raw = b"".join(b"\0" + bytes(v for px in im.p[y * im.w:(y + 1) * im.w] for v in px)
                   for y in range(im.h))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", im.w, im.h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def read_png(data):
    """Decode the repository's non-interlaced 8-bit RGBA reference images."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Not PNG")
    off, packed, header = 8, bytearray(), None
    while off < len(data):
        length = struct.unpack(">I", data[off:off + 4])[0]
        kind, body = data[off + 4:off + 8], data[off + 8:off + 8 + length]
        crc = struct.unpack(">I", data[off + 8 + length:off + 12 + length])[0]
        if zlib.crc32(kind + body) & 0xffffffff != crc:
            raise ValueError("PNG CRC mismatch")
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            packed.extend(body)
        off += 12 + length
    if header is None or header[2:] != (8, 6, 0, 0, 0):
        raise ValueError("Expected non-interlaced 8-bit RGBA PNG")
    w, h = header[:2]
    im, prev, raw = Image(w, h), [0] * (w * 4), zlib.decompress(packed)
    if len(raw) != h * (w * 4 + 1):
        raise ValueError("PNG decompressed size mismatch")
    for y in range(h):
        start = y * (w * 4 + 1)
        filt, row = raw[start], list(raw[start + 1:start + 1 + w * 4])
        for i, v in enumerate(row):
            a, b, c = row[i - 4] if i >= 4 else 0, prev[i], prev[i - 4] if i >= 4 else 0
            p = a + b - c
            distances = [abs(p - a), abs(p - b), abs(p - c)]
            paeth = (a, b, c)[distances.index(min(distances))]
            predictors = (0, a, b, (a + b) // 2, paeth)
            row[i] = (v + predictors[filt]) % 256
        im.p[y * w:(y + 1) * w] = [tuple(row[i:i + 4]) for i in range(0, w * 4, 4)]
        prev = row
    return im


# Original compact lettering for preview captions only; no external font.
FONT = dict(zip("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-:+/.() ", [
    "010/101/111/101/101", "110/101/110/101/110", "011/100/100/100/011",
    "110/101/101/101/110", "111/100/110/100/111", "111/100/110/100/100",
    "011/100/101/101/011", "101/101/111/101/101", "111/010/010/010/111",
    "001/001/001/101/010", "101/101/110/101/101", "100/100/100/100/111",
    "101/111/111/101/101", "101/111/111/111/101", "010/101/101/101/010",
    "110/101/110/100/100", "010/101/101/111/011", "110/101/110/101/101",
    "011/100/010/001/110", "111/010/010/010/010", "101/101/101/101/111",
    "101/101/101/101/010", "101/101/111/111/101", "101/101/010/101/101",
    "101/101/010/010/010", "111/001/010/100/111",
    "111/101/101/101/111", "010/110/010/010/111", "110/001/010/100/111",
    "110/001/010/001/110", "101/101/111/001/001", "111/100/110/001/110",
    "011/100/111/101/111", "111/001/010/010/010", "111/101/111/101/111",
    "111/101/111/001/110", "000/000/111/000/000", "000/010/000/010/000",
    "000/010/111/010/000", "001/001/010/100/100", "000/000/000/000/010",
    "001/010/010/010/001", "100/010/010/010/100", "000/000/000/000/000",
]))


def text(im, x, y, value, ink="d6dbd5", scale=2):
    for ch in value.upper():
        for yy, row in enumerate(FONT[ch].split("/")):
            for xx, bit in enumerate(row):
                if bit == "1":
                    im.rect(x + xx * scale, y + yy * scale,
                            x + (xx + 1) * scale - 1, y + (yy + 1) * scale - 1, ink)
        x += 4 * scale


INK, PAPER, GOLD = "292b29", "f5e3b1", "caa66a"


def envelope(im, x, y, w, h, outline=INK, paper=PAPER):
    im.rect(x, y, x + w - 1, y + h - 1, outline)
    im.rect(x + 1, y + 1, x + w - 2, y + h - 2, paper)
    im.line(x + 1, y + 1, x + w // 2, y + h // 2, outline)
    im.line(x + w // 2, y + h // 2, x + w - 2, y + 1, outline)


# Nodebox coordinates are authored on a 1/16-node grid; every box belongs to
# one node with six shared face textures. Front is -Z, top is +Y.
BOXES = {
    "A": [("foot", (-3, -8, -3, 3, -7, 3)), ("post", (-2, -7, -2, 2, -1, 2)),
          ("wide_box", (-7, -1, -4, 7, 6, 5)), ("flat_lid", (-8, 6, -5, 8, 8, 6))],
    "B": [("foot", (-3, -8, -3, 3, -7, 3)), ("post", (-1, -7, -1, 1, -3, 1)),
          ("tall_box", (-5, -3, -4, 5, 7, 4)), ("cap", (-6, 7, -5, 6, 8, 5))],
    "C": [("foot", (-3, -8, -3, 3, -7, 3)), ("post", (-2, -7, -2, 2, -2, 2)),
          ("box", (-6, -2, -4, 6, 4, 4)), ("eave", (-8, 4, -6, 8, 5, 6)),
          ("roof_lower", (-6, 5, -5, 6, 6, 5)), ("roof_upper", (-4, 6, -4, 4, 7, 4)),
          ("ridge", (-2, 7, -3, 2, 8, 3))],
}
IDEAS = {
    "mailbox": {
        "A": ("Wayside chest", "A broad oak box with a flat metal lid and a bright envelope plaque."),
        "B": ("Letter pillar", "A narrow upright iron cassette with a brass mail slot and envelope plate."),
        "C": ("Sheltered post", "A squat wooden letter box under a stepped copper roof on a stout post."),
    },
    "icon": {
        "A": ("Open letter", "An open folded letter exposes a pale written page above its envelope."),
        "B": ("Sealed envelope", "A broad closed envelope has a crisp dark flap and a small wax closure."),
        "C": ("Ribbon seal", "A scalloped wax seal with a tiny envelope impression hangs over two paper tails."),
    },
    "band": {
        "A": ("Brass channel", "A fine brass rectangle carries an eight-ray sun, crescent and single pointer."),
        "B": ("Carved timber", "Notched timber holds a diamond sun and half moon between opposing pointers."),
        "C": ("Slate rails", "Open slate rails bracket a round sun and cut moon under a small bead and hairline."),
    },
}


def mailbox(draft):
    wood = ("5b4230", "755239", "8d6644", "a17b50")
    metal = ("3b494d", "4e6061", "627574", "7c8e88")
    out = {}
    for face in ("top", "side", "front", "back"):
        im = Image(16, 16)
        for y in range(16):
            for x in range(16):
                palette = metal if draft == "B" and y < 12 else wood
                n = ((x // 3) * 3 + y // 5 + (1 if (x * 7 + y * 3) % 13 == 0 else 0)) % 4
                im.put(x, y, palette[n])
        if face == "top":
            base = {"A": "596967", "B": "667b7c", "C": "91704a"}[draft]
            im.rect(0, 0, 15, 15, base)
            for x in (3, 8, 13):
                im.line(x, 0, x, 15, {"A": "43514f", "B": "465758", "C": "6b4b36"}[draft])
                im.line(x + 1, 0, x + 1, 15, {"A": "7c8880", "B": "879b93", "C": "b08c5c"}[draft])
            for x, y in ((2, 3), (12, 3), (2, 12), (12, 12)):
                im.put(x, y, GOLD)
        else:
            # The post uses the lower portion of each vertical face tile.
            im.line(6, 10, 6, 14, "b18a59")
            im.line(9, 10, 9, 14, "4d392b")
            im.rect(5, 15, 10, 15, "4b5351")
            if draft == "A":
                im.rect(0, 0, 15, 0, "87918a")
                im.rect(0, 1, 15, 1, "3d504f")
                im.line(1, 2, 1, 8, "43362c")
                im.line(14, 2, 14, 8, "43362c")
                if face == "front":
                    im.rect(4, 2, 11, 2, "262c29")
                    envelope(im, 3, 4, 10, 5)
                    im.put(8, 7, "a35435")
                elif face == "side":
                    envelope(im, 5, 4, 6, 4, "4c392a", "d0b37a")
                else:
                    im.rect(2, 7, 13, 7, "454b44")
                for x in (2, 13):
                    im.put(x, 3, GOLD)
                    im.put(x, 8, GOLD)
            elif draft == "B":
                im.rect(0, 0, 15, 0, "97aaa1")
                im.line(3, 1, 3, 10, "a38e60")
                im.line(12, 1, 12, 10, "293a3d")
                if face == "front":
                    im.rect(4, 2, 11, 3, "b59761")
                    im.rect(5, 3, 10, 3, "222f32")
                    envelope(im, 4, 5, 8, 5, "313c3c", "e7ce91")
                    im.rect(7, 10, 8, 10, "d6bd82")
                else:
                    im.line(5, 3, 5, 9, "3a4d50")
                    im.line(6, 3, 6, 9, "84948c")
                    im.put(10, 2, "c4ad7c")
                    im.put(10, 9, "c4ad7c")
            else:
                for y in range(4):
                    im.rect(0, y, 15, y, ("b09060", "604b36", "a38051", "4e4030")[y])
                im.line(2, 4, 2, 9, "4e392b")
                im.line(13, 4, 13, 9, "4e392b")
                if face == "front":
                    im.rect(4, 4, 11, 4, "292c27")
                    envelope(im, 3, 5, 10, 5, "4a382a", "ead6a2")
                elif face == "side":
                    im.line(4, 8, 11, 5, "4c3c2b")
                    im.line(4, 9, 11, 6, "b29161")
                else:
                    im.rect(3, 5, 12, 5, "af8b57")
                    im.rect(3, 9, 12, 9, "4e3a2b")
        out[face] = im
    return out


def outline(im, ink, radius=1):
    out = Image(im.w, im.h)
    for y in range(im.h):
        for x in range(im.w):
            if im.get(x, y)[3]:
                out.rect(x - radius, y - radius, x + radius, y + radius, ink)
    out.blit(im, 0, 0)
    return out


def icon(draft):
    im = Image(32, 32)
    if draft == "A":
        im.poly([(4, 12), (14, 4), (25, 12), (25, 20), (4, 24)], "806c4d")
        im.rect(8, 3, 21, 19, "e1c98f")
        im.rect(9, 4, 20, 17, "f8eac2")
        im.poly([(18, 3), (21, 6), (18, 6)], "b59d71")
        im.rect(11, 8, 18, 8, "8d7b57")
        im.rect(11, 11, 17, 11, "8d7b57")
        im.poly([(4, 13), (14, 19), (25, 13), (25, 20), (17, 20), (16, 24), (4, 24)], "dfc68d")
        im.line(5, 14, 12, 18, "fff0ca")
        im.line(12, 19, 5, 23, "a78b5b")
        im.line(16, 19, 23, 15, "9b8154")
    elif draft == "B":
        im.rect(3, 7, 27, 20, "ba9d68")
        im.rect(4, 8, 26, 19, "f0dfb1")
        im.line(4, 18, 11, 13, "ab905f")
        im.line(19, 13, 26, 18, "ab905f")
        im.poly([(4, 8), (15, 16), (26, 8)], "fff0c8")
        im.line(4, 9, 15, 17, "75654c")
        im.line(15, 17, 26, 9, "75654c")
        im.ellipse(13, 14, 17, 18, "9a482e")
        im.put(14, 15, "e69c63")
    else:
        im.poly([(7, 15), (12, 16), (10, 25), (7, 23), (4, 24)], "eed9a3")
        im.poly([(12, 16), (17, 14), (20, 20), (16, 20), (16, 24)], "c3a675")
        im.poly([(8, 3), (16, 3), (18, 5), (21, 6), (21, 14), (19, 17),
                 (16, 19), (8, 19), (6, 17), (3, 15), (3, 7), (6, 5)], "a04e36")
        im.ellipse(5, 5, 19, 17, "c16b45")
        im.ellipse(7, 7, 17, 15, "a75436")
        im.line(8, 4, 15, 4, "edb47d")
        im.line(4, 8, 4, 13, "e39761")
        envelope(im, 8, 8, 9, 6, "f5d493", "a75436")
    # Pale outer keyline and dark inner contour work on both terrain values.
    im = outline(outline(im, "262a28"), "d8caa6")
    # Explicit reserved rectangle for the 13x9-pixel two-character badge.
    im.rect(18, 22, 31, 31, CLEAR)
    return im


BAND = {
    "A": {"day": "bda778", "night": "273d50", "dawn_dusk": "b88563", "blend_width_px": 8},
    "B": {"day": "a7b894", "night": "314843", "dawn_dusk": "bbaa79", "blend_width_px": 0},
    "C": {"day": "8eabb5", "night": "283149", "dawn_dusk": "b28f89", "blend_width_px": 12},
}


def band_parts(draft):
    sun, moon, frame, marker = Image(16, 16), Image(16, 16), Image(168, 40), Image(10, 40)
    if draft == "A":
        for a, b in [((7, 0), (7, 2)), ((7, 13), (7, 15)), ((0, 7), (2, 7)),
                     ((13, 7), (15, 7)), ((2, 2), (3, 3)), ((12, 3), (13, 2)),
                     ((2, 13), (3, 12)), ((12, 12), (13, 13))]:
            sun.line(*a, *b, "fff0b0")
        sun.ellipse(3, 3, 12, 12, "654932")
        sun.ellipse(4, 4, 11, 11, "f6ce71")
        sun.line(5, 5, 9, 5, "fff2ba")
        moon.ellipse(2, 1, 13, 14, "dbe9df")
        moon.ellipse(6, 0, 15, 10, CLEAR)
        moon.line(4, 5, 4, 10, "f4f1cc")
        moon.put(13, 3, "bdcfc7")
        moon.put(14, 4, "bdcfc7")
        frame.rect(1, 5, 166, 34, "222d2b")
        frame.rect(2, 6, 165, 33, "c0a36d")
        frame.rect(3, 7, 164, 32, "695942")
        frame.rect(4, 8, 163, 31, CLEAR)
        for x in (2, 164):
            frame.put(x, 6, "f2db9b")
            frame.put(x, 33, "4f4232")
        marker.poly([(0, 1), (9, 1), (5, 10)], "222a29")
        marker.poly([(2, 2), (7, 2), (5, 7)], "fff0c1")
        marker.rect(4, 32, 5, 37, "222a29")
        marker.rect(4, 33, 4, 36, "e2c98b")
    elif draft == "B":
        sun.poly([(7, 0), (9, 5), (15, 7), (10, 9), (8, 15), (5, 10), (0, 8), (5, 5)], "49513a")
        sun.poly([(7, 2), (9, 6), (13, 7), (9, 9), (8, 13), (6, 9), (2, 8), (6, 6)], "f0d393")
        sun.rect(6, 6, 9, 9, "fff1bc")
        moon.ellipse(2, 1, 13, 14, "95b3ac")
        moon.rect(8, 0, 15, 15, CLEAR)
        moon.line(7, 2, 7, 13, "e4ead3")
        moon.put(4, 6, "d2decb")
        moon.put(5, 10, "d2decb")
        for x, y in ((11, 3), (12, 11)):
            moon.put(x, y, "d9ddbc")
        frame.poly([(2, 4), (165, 4), (165, 6), (167, 6), (167, 33), (165, 33),
                    (165, 35), (2, 35), (2, 33), (0, 33), (0, 6), (2, 6)], "2c3027")
        frame.rect(2, 6, 165, 33, "69583f")
        frame.line(5, 5, 162, 5, "bca578")
        frame.line(6, 34, 161, 34, "463c2d")
        frame.rect(4, 8, 163, 31, CLEAR)
        for x in (2, 165):
            for y in (8, 30):
                frame.put(x, y, "dfcc94")
        marker.poly([(1, 0), (8, 0), (8, 4), (5, 9), (1, 4)], "25352f")
        marker.poly([(3, 1), (6, 1), (6, 4), (5, 6), (3, 4)], "f4e9b8")
        marker.poly([(1, 39), (8, 39), (8, 35), (5, 30), (1, 35)], "25352f")
        marker.poly([(3, 38), (6, 38), (6, 35), (5, 33), (3, 35)], "f4e9b8")
    else:
        sun.ellipse(2, 2, 13, 13, "d5a064")
        sun.ellipse(3, 3, 12, 12, "ffe6a3")
        sun.line(5, 3, 10, 3, "fff2d1")
        for x, y in ((7, 0), (7, 15), (0, 7), (15, 7)):
            sun.put(x, y, "fff2c1")
        moon.ellipse(2, 1, 13, 14, "d0dce3")
        moon.ellipse(0, 0, 10, 9, CLEAR)
        moon.line(10, 10, 12, 8, "f0efdd")
        moon.put(3, 3, "eee1b6")
        frame.rect(1, 6, 166, 33, "252d36")
        frame.rect(4, 8, 163, 31, CLEAR)
        frame.line(5, 6, 162, 6, "b1c0c3")
        frame.line(5, 33, 162, 33, "75888c")
        for x0 in (0, 164):
            frame.rect(x0, 4, x0 + 3, 35, "303d46")
            frame.line(x0 + 1, 5, x0 + 1, 34, "96a8ab")
        marker.ellipse(1, 0, 8, 7, "26313b")
        marker.ellipse(3, 2, 6, 5, "fff1c5")
        marker.line(5, 8, 5, 31, "26313b")
        marker.line(4, 8, 4, 31, "f7e7b9")
        marker.rect(2, 33, 7, 35, "26313b")
        marker.line(3, 34, 6, 34, "e6d8ac")
    return {"sun": sun, "moon": moon, "frame": frame, "marker": marker}


def phase_color(draft, phase):
    p = BAND[draft]
    base = color(p["day"] if phase < 120 else p["night"])
    width = p["blend_width_px"]
    if width:
        distance = min(phase, 160 - phase, abs(phase - 120))
        amount = max(0, 1 - distance / (width / 2))
        blend = color(p["dawn_dusk"])
        base = tuple(round(a * (1 - amount) + b * amount) for a, b in zip(base, blend))
    return base


def compose_band(draft, parts, phase):
    # 160 visible pixels, plus four frame pixels on either side. The fixed
    # marker is at x=84, halfway through the cycle window [4,164).
    out = Image(168, 40)
    for x in range(160):
        c = phase_color(draft, (x + phase - 80) % 160)
        out.rect(x + 4, 8, x + 4, 31, c)
    for centre, name in ((60, "sun"), (140, "moon")):
        x = (centre - phase + 80) % 160
        for wrap in (-160, 0, 160):
            sprite = parts[name]
            for yy in range(sprite.h):
                for xx in range(sprite.w):
                    dest = x - 8 + xx + wrap
                    if 0 <= dest < 160 and sprite.get(xx, yy)[3]:
                        out.put(4 + dest, 12 + yy, sprite.get(xx, yy))
    out.blit(parts["frame"], 0, 0)
    out.blit(parts["marker"], 79, 0)
    return out


def ref(path, refs):
    data = (ROOT / path).read_bytes()
    refs[path] = hashlib.sha256(data).hexdigest()
    return read_png(data)


def digit(char, refs):
    src = ref("mods/PLAYER/grug_abilities/textures/grug_abilities_cd_digit_" + char + ".png", refs)
    out = Image(7, 9)
    for y in range(9):
        for x in range(7):
            out.put(x, y, src.get(x * 4, y * 4))
    return out


def preview_plus(four):
    """Preview-only cross from the existing 4's horizontal/vertical strokes.

    The HUD lane owns the final + glyph; this never produces a glyph asset.
    Take the five white pixels of the 4's crossbar and reuse that same stroke
    vertically, then use the digit's existing black for its one-cell outline.
    """
    im = Image(7, 9)
    for i in range(5):
        im.put(1 + i, 4, four.get(1 + i, 5))
        im.put(3, 2 + i, four.get(1 + i, 5))
    return outline(im, four.get(0, 5))


def badged(sprite, count, digits):
    im = Image(32, 32)
    im.blit(sprite, 0, 0)
    if count == "3":
        im.blit(digits["3"], 24, 22)
    elif count == "9+":
        im.blit(digits["9"], 18, 22)
        im.blit(digits["+"], 24, 22)
    return im


def ground(w, h, kind):
    palettes = {
        "grass": ("84975e", "7c9056", "91a26b"), "sand": ("d5c491", "ccba88", "dfcea0"),
        "forest": ("233b30", "294336", "304937"), "night": ("192631", "1e2d38", "243440"),
    }
    im = Image(w, h)
    for y in range(h):
        for x in range(w):
            k = ((x // 7) * 3 + (y // 5) * 7 + (x // 21)) % 11
            im.put(x, y, palettes[kind][0 if k < 7 else 1 if k < 10 else 2])
    return im


def paving(x, z):
    u, v = math.floor(x * 16), math.floor(z * 16)
    ux = (u + (8 if (v // 8) % 2 else 0)) % 16
    if ux == 0 or v % 8 == 0:
        return color("555b54")
    if ux == 1 or v % 8 == 1:
        return color("9a9d88")
    return color(("7b8275", "858a7b", "8b907f")[(u // 3 + v // 2) % 3])


def normalize(v):
    length = math.sqrt(sum(x * x for x in v))
    return tuple(x / length for x in v)


def ray_box(origin, direction, box):
    near, far, face = -1e9, 1e9, None
    for axis in range(3):
        if abs(direction[axis]) < 1e-8:
            if not box[axis] <= origin[axis] <= box[axis + 3]:
                return None
            continue
        a = (box[axis] - origin[axis]) / direction[axis]
        b = (box[axis + 3] - origin[axis]) / direction[axis]
        side = -1 if a < b else 1
        a, b = min(a, b), max(a, b)
        if a > near:
            near, face = a, (axis, side)
        far = min(far, b)
        if near > far:
            return None
    return (near, face) if far > 0 else None


def node_sample(textures, p, face):
    x, y, z = p
    axis, side = face
    if axis == 1:
        name, u, v = "top", x + 0.5, 0.5 - z if side == 1 else z + 0.5
    elif axis == 0:
        name, u, v = "side", z + 0.5 if side == 1 else 0.5 - z, 0.5 - y
    else:
        name, u, v = ("front", x + 0.5, 0.5 - y) if side == -1 else ("back", 0.5 - x, 0.5 - y)
    tex = textures[name]
    c = tex.get(math.floor(u * 16) % 16, math.floor(v * 16) % 16)
    shade = {0: 0.77, 1: 1.0, 2: 0.92}[axis]
    return tuple(round(v * shade) for v in c[:3]) + (c[3],)


def render_node(draft, textures, mode="iso"):
    # Orthographic raster at 24 pixels per node. A tiny CPU raycaster keeps
    # all boxes, occlusion and cropped node-aligned UVs faithful to the data.
    w, h = (84, 58) if mode == "iso" else (38, 38)
    view = normalize({"iso": (1, 0.7, -1.7), "front": (0, 0, -1), "side": (1, 0, 0)}[mode])
    right = normalize((-view[2], 0, view[0]))
    up = (-view[1] * right[2], view[0] * right[2] - view[2] * right[0], view[1] * right[0])
    direction = tuple(-v for v in view)
    boxes = [tuple(v / 16 for v in box) for _, box in BOXES[draft]]
    im = Image(w, h, "414b46")
    for sy in range(h):
        for sx in range(w):
            u, v = (sx + 0.5 - w / 2) / 24, (h / 2 - sy - 0.5) / 24
            origin = tuple(view[i] * 10 + right[i] * u + up[i] * v for i in range(3))
            best = None
            for box in boxes:
                hit = ray_box(origin, direction, box)
                if hit and (best is None or hit[0] < best[0]):
                    best = hit
            if best:
                p = tuple(origin[i] + best[0] * direction[i] for i in range(3))
                im.put(sx, sy, node_sample(textures, p, best[1]))
            elif direction[1] < -1e-6:
                t = (-0.5 - origin[1]) / direction[1]
                x, z = origin[0] + t * direction[0], origin[2] + t * direction[2]
                c = paving(x, z)
                if (x - 0.16) ** 2 / 0.7 + (z - 0.16) ** 2 / 0.4 < 1:
                    c = tuple(round(v * 0.75) for v in c[:3]) + (255,)
                im.put(sx, sy, c)
            elif sy >= h // 2 + 12:
                im.put(sx, sy, paving((sx - w / 2) / 24, (sy - h / 2 - 12) / 12))
    return im


def sheet(title, subtitle, h):
    im = Image(1200, h, "192521")
    text(im, 24, 22, title, "f0dfb5", 3)
    text(im, 24, 50, subtitle, "9dab9f", 2)
    im.rect(24, 73, 1175, 74, "455249")
    return im


def preview_mailbox(mailboxes, waystone, waytop):
    im = sheet("MAILBOX / THREE SILHOUETTES", "R48 ARTM / ORIGINAL PIXEL ART / NODEBOX STUDIES", 748)
    for i, draft in enumerate("ABC"):
        x = 24 + i * 392
        text(im, x, 94, draft + " / " + IDEAS["mailbox"][draft][0], scale=2)
        im.blit(render_node(draft, mailboxes[draft]).scale(4), x + 12, 120)
        text(im, x, 367, "FRONT 4X", scale=2)
        text(im, x + 185, 367, "SIDE 4X", scale=2)
        im.blit(render_node(draft, mailboxes[draft], "front").scale(4), x, 389)
        im.blit(render_node(draft, mailboxes[draft], "side").scale(4), x + 185, 389)
        text(im, x, 562, "FRONT  SIDE   TOP   BACK", scale=2)
        for j, name in enumerate(("front", "side", "top", "back")):
            im.blit(mailboxes[draft][name].scale(4), x + j * 74, 585)
        im.blit(waystone.scale(4), x, 672)
        im.blit(waytop.scale(4), x + 74, 672)
        text(im, x + 153, 678, "WAYSTONE", scale=2)
        text(im, x + 153, 700, "EXISTING / 4X", scale=2)
    return im


def preview_icons(icons, digits):
    im = sheet("UNREAD MAIL / LETTER - ENVELOPE - SEAL", "NATIVE 32X32 / EXISTING COOLDOWN DIGITS / LOWER-RIGHT BADGE", 840)
    for i, draft in enumerate("ABC"):
        x = 24 + i * 392
        text(im, x, 94, draft + " / " + IDEAS["icon"][draft][0], scale=2)
        for j, bg in enumerate(("grass", "sand", "forest", "night")):
            y = 128 + j * 165
            text(im, x, y, bg, "c4cfbd", 2)
            tile = ground(360, 133, bg)
            # Each row includes the undecorated candidate plus both badges at
            # native size and nearest-neighbour 2x; no enlarged-only judgement.
            for k, count in enumerate(("", "3", "9+")):
                tile.blit(badged(icons[draft], count, digits), 14 + k * 117, 7)
                tile.blit(badged(icons[draft], count, digits).scale(2), 7 + k * 117, 57)
                text(tile, 72 + k * 117, 15, count or "BASE", "f3eed9", 1)
                text(tile, 78 + k * 117, 86, "2X", "f3eed9", 1)
            im.blit(tile, x, y + 22)
    text(im, 24, 810, "TOP IN EACH TILE: 1X / BOTTOM: 2X / PLUS IS A PREVIEW COMPOSITION OF DIGIT STROKES", "9dab9f", 1)
    return im


def preview_bands(parts):
    # Use a spacious vertical sheet to keep every enlarged band at true 3x.
    out = sheet("DAYTIME / THREE FRAMES AND MARKERS", "DAY 120 PX + NIGHT 40 PX / FIXED NOW / THE STRIP MOVES LEFT", 1664)
    for i, draft in enumerate("ABC"):
        y = 96 + i * 510
        text(out, 24, y, draft + " / " + IDEAS["band"][draft][0], "f0dfb5", 2)
        for j, (label, phase) in enumerate((("NOON", 60), ("DUSK", 120), ("MIDNIGHT", 140))):
            yy = y + 31 + j * 148
            band = compose_band(draft, parts[draft], phase)
            text(out, 24, yy + 8, label, "c4cfbd", 2)
            text(out, 184, yy + 8, "1X", "9dab9f", 2)
            text(out, 445, yy + 8, "3X", "9dab9f", 2)
            bg = "grass" if j < 2 else "night"
            out.blit(ground(208, 80, bg), 184, yy + 26)
            out.blit(band, 204, yy + 46)
            out.blit(ground(528, 124, bg), 445, yy + 26)
            out.blit(band.scale(3), 457, yy + 28)
        text(out, 1004, y + 64, "SUN", scale=2)
        out.blit(parts[draft]["sun"].scale(4), 1004, y + 86)
        text(out, 1004, y + 175, "MOON", scale=2)
        out.blit(parts[draft]["moon"].scale(4), 1004, y + 197)
        for j, key in enumerate(("day", "night", "dawn_dusk")):
            out.rect(1004, y + 302 + j * 29, 1035, y + 321 + j * 29, BAND[draft][key])
            text(out, 1045, y + 310 + j * 29, ("DAY", "NIGHT", "BLEND")[j], scale=1)
    return out


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=True) + "\n").encode()


def build():
    outputs, images, entries, refs = {}, {}, [], {}

    def add(path, im):
        images[path] = im
        outputs[path] = png(im)
        return {"path": path, "size": [im.w, im.h], "mode": "RGBA"}

    mailboxes = {d: mailbox(d) for d in "ABC"}
    icons = {d: icon(d) for d in "ABC"}
    parts = {d: band_parts(d) for d in "ABC"}
    for thing, variants in (("mailbox", mailboxes), ("icon", icons), ("band", parts)):
        for draft, art in variants.items():
            prefix = "drafts/" + thing + "/" + draft + "/"
            title, idea = IDEAS[thing][draft]
            entry = {"thing": thing, "draft": draft, "title": title, "idea": idea, "files": []}
            if thing == "mailbox":
                for face, im in art.items():
                    entry["files"].append(add(prefix + "grug_mapgen_mailbox_" + face + ".png", im))
                entry["boxes"] = [{"part": part, "bounds": [v / 16 for v in box]} for part, box in BOXES[draft]]
                entry["box_units"] = "node units; xmin,ymin,zmin,xmax,ymax,zmax; +Y up; front -Z"
                entry["tile_order"] = ["top", "top", "side", "side", "back", "front"]
                entry["uv"] = "node-aligned, 16 px per node; shared face tiles for every box, no per-box stretching"
            elif thing == "icon":
                entry["files"].append(add(prefix + "grug_map_mail.png", art))
                entry["badge_reserved_rect"] = [18, 22, 14, 10]
                entry["badge_example_origins"] = {"3": [24, 22], "9+": [18, 22]}
            else:
                for name, im in art.items():
                    entry["files"].append(add(prefix + name + ".png", im))
                palette = {key: ("#" + value if isinstance(value, str) else value) for key, value in BAND[draft].items()}
                palette.update({"cycle_px": 160, "day_px": 120, "night_px": 40,
                                "sun_phase_px": 60, "moon_phase_px": 140,
                                "frame_size": [168, 40], "viewport": [4, 8, 160, 24],
                                "frame_mode": "exact-size overlay", "marker_origin": [79, 0],
                                "now_x": 84, "symbol_y": 12,
                                "blend_rule": "Linear blend toward dawn_dusk within blend_width_px/2 on each side of phase 0 and 120; 0 disables blending.",
                                "scroll_rule": "phase=(viewport_x + now_phase - 80) modulo 160; increasing now_phase moves symbols left"})
                outputs[prefix + "palette.json"] = json_bytes(palette)
                entry["files"].append({"path": prefix + "palette.json", "type": "application/json"})
                entry["geometry"] = palette
            entries.append(entry)

    waystone = ref("mods/MAPGEN/grug_mapgen/textures/grug_mapgen_waystone.png", refs)
    waytop = ref("mods/MAPGEN/grug_mapgen/textures/grug_mapgen_waystone_top.png", refs)
    digits = {c: digit(c, refs) for c in "349"}
    digits["+"] = preview_plus(digits["4"])
    previews = [add("previews/mailbox.png", preview_mailbox(mailboxes, waystone, waytop)),
                add("previews/icon.png", preview_icons(icons, digits)),
                add("previews/band.png", preview_bands(parts))]
    manifest = {"schema": 1, "stage": "Round 48 ARTM step 1; proposals awaiting user picks",
                "author": "GPT-6 Astra", "date": DATE, "license": "CC0-1.0", "upgrade_class": "compatible",
                "generator": "generate.py", "drafts": entries, "previews": previews,
                "preview_references": [{"path": p, "sha256": h, "license": "CC0-1.0"} for p, h in sorted(refs.items())],
                "preview_plus": "Cross assembled from existing digit 4 strokes, preview only; HUD owns the final + glyph.",
                "runtime_validation": "No engine run. Ten-node mailbox recognition and desktop/web HUD readability await the user's GUI check."}
    outputs["drafts/manifest.json"] = json_bytes(manifest)
    rows = ["# Media licence ledger — Round 48 ARTM step 1", "",
            "Original pixel art and preview compositions by GPT-6 Astra, 2026-10-14.",
            "The project dedicates these works to CC0 1.0 Universal (CC0-1.0),",
            "to the extent any rights exist. No downloads or external fonts.", "",
            "All paths are relative to this directory. The generator and palette",
            "data are also CC0-1.0. One row per PNG and palette follows.", "",
            "| File | Author | Date | Licence | Source / modifications |",
            "| --- | --- | --- | --- | --- |"]
    for path in sorted(outputs):
        if not (path.endswith(".png") or path.endswith("palette.json")):
            continue
        source = "Own work; generated by generate.py"
        if path == "previews/mailbox.png":
            source += "; includes existing CC0 waystone textures by GPT-6 Astra, unchanged nearest scaling"
        elif path == "previews/icon.png":
            source += "; includes existing CC0 cooldown digits, reduced to glyph cells; preview + reuses their strokes"
        rows.append(f"| `{path}` | GPT-6 Astra | {DATE} | CC0-1.0 | {source} |")
    rows += ["", "## Existing preview sources", "",
             "- Waystone side/top: `../../mods/MAPGEN/grug_mapgen/textures/`,",
             "  CC0-1.0, GPT-6 Astra; source ledger:",
             "  [grug_mapgen](../../mods/MAPGEN/grug_mapgen/LICENSE-media.md).",
             "- Cooldown digits 3, 4 and 9: `../../mods/PLAYER/grug_abilities/textures/`,",
             "  project-generated CC0, Round 40; source ledger:",
             "  [grug_abilities](../../mods/PLAYER/grug_abilities/LICENSE-media.md).",
             "  The composition credit above is not a new claim of authorship of those digits.",
             "- Ground swatches and paving are original to this generator.",
             "  Reference PNG SHA-256 values are recorded in the manifest.", ""]
    outputs["LICENSE-media.md"] = "\n".join(rows).encode()
    return outputs, images


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify deterministic output and all PNG dimensions/modes without writing")
    args = parser.parse_args()
    outputs, images = build()
    failures = []
    for path, data in sorted(outputs.items()):
        dest = HERE / path
        if args.check:
            if not dest.exists() or dest.read_bytes() != data:
                failures.append(path + ": missing or differs")
        else:
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
    expected_pngs = set(images)
    actual_pngs = {p.relative_to(HERE).as_posix() for p in HERE.rglob("*.png")}
    for path in sorted(actual_pngs - expected_pngs):
        failures.append(path + ": unexpected PNG")
    for path, expected in sorted(images.items()):
        dest = HERE / path
        if not dest.exists():
            continue
        try:
            decoded = read_png(dest.read_bytes())
            if (decoded.w, decoded.h) != (expected.w, expected.h) or decoded.p != expected.p:
                failures.append(path + ": size or pixel mismatch")
        except (ValueError, IndexError, struct.error, zlib.error) as err:
            failures.append(path + ": " + str(err))
    for draft in "ABC":
        im = images[f"drafts/icon/{draft}/grug_map_mail.png"]
        if any(im.get(x, y)[3] for y in range(22, 32) for x in range(18, 32)):
            failures.append("Icon " + draft + ": occupied badge reserve")
    for path, im in images.items():
        if any(p[3] not in (0, 255) or (p[3] == 0 and p != CLEAR) for p in im.p):
            failures.append(path + ": non-binary alpha or nonzero transparent RGB")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"{'Verified' if args.check else 'Wrote'} {len(outputs)} files; {len(images)} PNGs: size, RGBA, CRC, pixels and alpha PASS.")
    for path, im in sorted(images.items()):
        print(f"{path}: {im.w}x{im.h} RGBA")
    return 0


if __name__ == "__main__":
    sys.exit(main())
