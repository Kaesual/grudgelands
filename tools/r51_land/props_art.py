#!/usr/bin/env python3
"""Round 51 ARTL pass 2. Original pixel/box art, GPT-6 Astra, CC0-1.0.

python3 -I tools/r51_land/props_art.py [--check]
Only Pillow is needed. No downloads, source-asset sampling, or game writes.
The preview reads the CC0 pass-1 grounds and the Round 47 CC0 pixel font.
"""

import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import re
import runpy

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CLEAR = (0, 0, 0, 0)
NEAREST = Image.Resampling.NEAREST
FACES = ("top", "bottom", "right", "left", "back", "front")
NORMALS = ((0, 1, 0), (0, -1, 0), (1, 0, 0), (-1, 0, 0),
           (0, 0, 1), (0, 0, -1))
FONT = dict(runpy.run_path(str(ROOT / "tools/r47_art/swamp/generate.py"))["FONT_ROWS"])
FONT["_"] = "000/000/000/000/111"
FONT["="] = "000/111/000/111/000"
PALETTES = {
    "bone": ("81715a", "afa087", "c9bda3", "e0d6bd", "eee5cd"),
    "grave": ("55554f", "6e6e63", "858577", "9b9c8c", "b0b0a0"),
    "cairn": ("565953", "72756c", "898d80", "9da191", "adb09f"),
    "silver": ("88877b", "aaa999", "c6c5b2", "d8d7c2", "e5e3d0"),
    "obelisk": ("4c5052", "65696a", "7c8080", "959997", "acb0a9"),
    "wood": ("65665f", "888b81", "a7aba1", "c5c8ba", "dedfd0"),
}


def rgba(value):
    return tuple(bytes.fromhex(value)) + (255,)


def face_rect(box, face):
    """Half-open texel rectangle: the six mappings in the binding README."""
    x1, y1, z1, x2, y2, z2 = box
    return ((x1 + 8, 8 - z2, x2 + 8, 8 - z1),
            (x1 + 8, z1 + 8, x2 + 8, z2 + 8),
            (z1 + 8, 8 - y2, z2 + 8, 8 - y1),
            (8 - z2, 8 - y2, 8 - z1, 8 - y1),
            (8 - x2, 8 - y2, 8 - x1, 8 - y1),
            (x1 + 8, 8 - y2, x2 + 8, 8 - y1))[face]


def face_masks(boxes):
    masks = []
    for face in range(6):
        mask = Image.new("1", (16, 16))
        for box in boxes:
            u1, v1, u2, v2 = face_rect(box, face)
            ImageDraw.Draw(mask).rectangle((u1, v1, u2 - 1, v2 - 1), fill=1)
        masks.append(mask)
    return masks


def grain(x, y, seed):
    # Integer-only, stable across processes and Python versions.
    value = (x * 374761393 + y * 668265263 + seed * 1442695041) & 0xffffffff
    value = ((value ^ (value >> 13)) * 1274126177) & 0xffffffff
    return (value ^ (value >> 16)) & 255


def tiles_for(key, boxes, material, seed):
    """Paint only projected face strips. All unused texels stay plain."""
    palette = [rgba(c) for c in PALETTES[material]]
    masks = face_masks(boxes)
    tiles = []
    for face, mask in enumerate(masks):
        tile = Image.new("RGBA", (16, 16), palette[2])
        for y in range(16):
            for x in range(16):
                if not mask.getpixel((x, y)):
                    continue
                g = grain(x // 2, y // 2, seed + face)
                index = 1 if g < 28 else 3 if g > 215 else 2
                # A restrained, interrupted lip describes the small silhouettes.
                if y > 0 and not mask.getpixel((x, y - 1)):
                    index = 3
                if y < 15 and not mask.getpixel((x, y + 1)):
                    index = 1
                if grain(x, y, seed + face + 30) > 247:
                    index = min(4, index + 1)
                tile.putpixel((x, y), palette[index])
        tiles.append(tile)
    return tiles, masks


def mark(tiles, masks, face, points, color):
    """An authored mark cannot leak into a strip no box uses."""
    value = CLEAR if color is None else rgba(color)
    for x, y in points:
        if 0 <= x < 16 and 0 <= y < 16 and masks[face].getpixel((x, y)):
            tiles[face].putpixel((x, y), value)


def stroke(tiles, masks, face, points, color):
    mask = Image.new("1", (16, 16))
    ImageDraw.Draw(mask).line(points, fill=1)
    mark(tiles, masks, face,
         [(x, y) for y in range(16) for x in range(16) if mask.getpixel((x, y))], color)


def paint_details(key, tiles, masks):
    if key == "skull_human":
        # Dark recessed sockets survive both backgrounds; the nose is pierced.
        mark(tiles, masks, 5, [(x, y) for x in (5, 6, 9, 10) for y in (11, 12)], "524b3f")
        mark(tiles, masks, 5, [(5, 11), (9, 11)], "70634f")
        mark(tiles, masks, 5, [(7, 13), (8, 13)], None)
        mark(tiles, masks, 5, [(6, 15), (8, 15), (10, 15)], "73634d")
        stroke(tiles, masks, 0, [(8, 5), (7, 6), (8, 7), (8, 9)], "afa087")
        for f in (2, 3):
            stroke(tiles, masks, f, [(6, 12), (7, 13), (9, 13)], "81715a")
    elif key == "skull_horned":
        for f in (2, 3):
            mark(tiles, masks, f, [(7, 10), (8, 10), (7, 11), (8, 11)], "514a3b")
            stroke(tiles, masks, f, [(3, 14), (5, 14), (6, 13)], "8e7b5c")
        mark(tiles, masks, 5, [(6, 14), (9, 14)], "5e523f")
        mark(tiles, masks, 0, [(7, 13), (8, 13), (7, 14)], None)
        stroke(tiles, masks, 0, [(8, 6), (8, 9), (7, 11)], "a29275")
        for f in (0, 4):
            mark(tiles, masks, f, [(2, 5), (3, 6), (12, 5), (13, 6)], "928064")
    elif key.startswith("ribcage") or key.startswith("spine") or key.startswith("bones"):
        # Sparse cracks and exposed darker ends; no dark outlines on thin ribs.
        for f in (0, 2, 5):
            mark(tiles, masks, f, [(4, 12), (9, 14), (6, 7), (11, 4)], "a7977a")
            mark(tiles, masks, f, [(5, 12), (10, 14), (7, 7), (12, 4)], "eee5cd")
    elif key.startswith("gravestone"):
        for f in (4, 5):
            stroke(tiles, masks, f, [(10, 1), (9, 3), (10, 4), (9, 6)], "55554f")
            stroke(tiles, masks, f, [(11, 2), (10, 3)], "b0b0a0")
            # Dull organic growth stays at the damp foot, not mineral streaks.
            mark(tiles, masks, f, [(3, 14), (4, 14), (5, 15), (10, 15), (11, 14)], "656b50")
        if key == "gravestone_slab":
            for f in (4, 5):
                stroke(tiles, masks, f, [(7, 4), (5, 6), (7, 8), (9, 6), (7, 4)], "65665c")
                stroke(tiles, masks, f, [(6, 6), (7, 7), (8, 6)], "b0b0a0")
                stroke(tiles, masks, f, [(5, 10), (9, 10)], "68695e")
                mark(tiles, masks, f, [(5, 12), (6, 12), (8, 12)], "68695e")
        else:
            stroke(tiles, masks, 5, [(7, 8), (7, 12)], "55554f")
            stroke(tiles, masks, 5, [(4, 10), (10, 10)], "55554f")
            mark(tiles, masks, 5, [(8, 8), (8, 9), (9, 9)], "b0b0a0")
    elif key.startswith("cairn"):
        for f in (2, 3, 4, 5):
            for y in ((5, 10, 13) if key == "cairn_course" else (11, 14)):
                stroke(tiles, masks, f, [(3, y), (6, y), (7, y - 1), (11, y - 1)], "62685f")
                mark(tiles, masks, f, [(4, y + 1), (5, y + 1)], "adb09f")
        mark(tiles, masks, 0, [(3, 5), (4, 5), (4, 6), (10, 9), (11, 9)], "81876d")
    elif key == "statue_veiled_head":
        # Nearly erased features underneath a heavy hood, no glowing eyes.
        stroke(tiles, masks, 5, [(4, 5), (5, 6), (5, 10), (6, 12)], "88877b")
        stroke(tiles, masks, 5, [(11, 5), (10, 7), (10, 11)], "88877b")
        mark(tiles, masks, 5, [(6, 8), (8, 8), (9, 8)], "88877b")
        mark(tiles, masks, 5, [(7, 9), (7, 10)], "e5e3d0")
        mark(tiles, masks, 5, [(7, 12), (8, 12)], "aaa999")
        stroke(tiles, masks, 0, [(10, 6), (9, 7), (10, 8)], "88877b")
    elif key == "statue_broken_torso":
        for f in (4, 5):
            stroke(tiles, masks, f, [(4, 4), (6, 7), (7, 9), (6, 14)], "99998b")
            stroke(tiles, masks, f, [(11, 5), (9, 8), (10, 12), (10, 15)], "99998b")
            stroke(tiles, masks, f, [(5, 5), (7, 8), (8, 8)], "e5e3d0")
            mark(tiles, masks, f, [(3, 13), (4, 14), (5, 15)], "9b9e83")
        stroke(tiles, masks, 0, [(10, 7), (11, 8), (11, 10), (13, 11)], "88877b")
    elif key == "obelisk_broken_tip":
        for f in (2, 5):
            stroke(tiles, masks, f, [(9, 4), (8, 6), (9, 8), (8, 10), (8, 12), (6, 15)], "4c5052")
            stroke(tiles, masks, f, [(10, 6), (10, 8), (9, 9)], "959997")
        stroke(tiles, masks, 0, [(6, 5), (7, 7), (9, 7), (10, 9)], "65696a")
    elif key.startswith("driftwood"):
        # Grain follows each limb in the top view; cut ends have broken rings.
        for y in (6, 8, 10):
            stroke(tiles, masks, 0, [(1, y), (5, y), (7, y - 1), (12, y - 1), (14, y)], "888b81")
            stroke(tiles, masks, 0, [(3, y + 1), (7, y), (10, y)], "dedfd0")
        for f in (4, 5):
            stroke(tiles, masks, f, [(1, 13), (4, 12), (9, 12), (14, 13)], "888b81")
            stroke(tiles, masks, f, [(3, 14), (7, 14), (12, 13)], "dedfd0")
        for f in (2, 3):
            stroke(tiles, masks, f, [(6, 12), (9, 12), (10, 13), (9, 14), (6, 14), (5, 13), (6, 12)], "65665f")
            mark(tiles, masks, f, [(7, 13), (8, 13)], "dedfd0")
        if key == "driftwood_fork":
            stroke(tiles, masks, 0, [(7, 8), (9, 5), (11, 3), (12, 1)], "888b81")
            stroke(tiles, masks, 0, [(8, 8), (10, 5), (12, 3)], "dedfd0")


def build_props():
    props = {}

    def add(key, name, drop, material, boxes, note, clip=False):
        tiles, masks = tiles_for(key, boxes, material, 5100 + len(props) * 19)
        paint_details(key, tiles, masks)
        spec = dict(name=name, drop=drop,
                    tiles=[key + "_" + f + ".png" for f in FACES], boxes=boxes,
                    rotate=True, note=note)
        if clip:
            spec["alpha"] = "clip"
        props[key] = dict(spec=spec, tiles=tiles, masks=masks, material=material)

    bone_note = "Rare single find or occasional pair; drops nothing like today's bone_pile. The user may prefer grug_mobs:bone."
    add("skull_human", "Skull, humanoid", "", "bone", [
        [-4, -7, -2, 4, -1, 4], [-3, -1, -1, 3, 0, 3],
        [-4, -5, -3, 4, -2, -2], [-3, -8, -4, 3, -6, 1],
        [-4, -7, -3, -2, -5, -2], [2, -7, -3, 4, -5, -2],
        [-1, -7, -3, 1, -4, -2]], bone_note, clip=True)
    add("skull_horned", "Skull, horned animal", "", "bone", [
        [-3, -7, -2, 3, -1, 4], [-2, -8, -7, 2, -5, -1],
        [-2, -5, -4, 2, -3, 1], [-2, -1, 0, 2, 0, 3],
        [-5, -5, 2, -3, -2, 4], [3, -5, 2, 5, -2, 4],
        [-7, -4, 2, -5, -1, 4], [5, -4, 2, 7, -1, 4],
        [-7, -2, 3, -6, 0, 5], [6, -2, 3, 7, -1, 5]], bone_note, clip=True)
    ribs = [[-1, -8, -6, 1, -6, 7], [-1, -3, -3, 1, -2, 5]]
    for z, width, top in ((-5, 3, -4), (-2, 5, -2), (1, 5, -2), (4, 4, -3)):
        ribs.extend([[-width, -8, z, -width + 1, top - 1, z + 1],
                     [width - 1, -8, z, width, top - 1, z + 1],
                     [-width, top - 2, z, width, top - 1, z + 1],
                     [-width + 1, top - 1, z, width - 1, top, z + 1]])
    add("ribcage_human", "Ribcage, humanoid", "", "bone", ribs,
        bone_note + " Rib gaps are geometry; no alpha mask is needed.")
    spine = [[-1, -8, -7, 1, -6, 7]]
    for z, x in ((-6, 0), (-3, 0), (0, 1), (3, 0), (6, -1)):
        spine.append([x - 2, -7, z - 1, x + 2, -5, z + 1])
        if z < 6:
            spine.append([x - 4, -7, z, x + 4, -6, z + 1])
    spine.extend([[-5, -8, 3, -3, -5, 7], [2, -8, 4, 4, -5, 7],
                  [-4, -7, 3, 3, -6, 4]])
    add("spine_animal", "Spine, small animal", "", "bone", spine, bone_note)
    add("bones_scattered", "Bones, scattered long bones", "", "bone", [
        [-6, -8, -4, 3, -7, -2], [-7, -8, -5, -5, -6, -1],
        [2, -8, -4, 4, -6, -1], [1, -8, 1, 3, -7, 6],
        [0, -8, 0, 4, -6, 2], [1, -8, 5, 4, -6, 7],
        [-5, -8, 3, -3, -7, 5]],
        bone_note + " Recommended piece to retain the grug_nodes:bone_pile node name.")
    add("bones_fragments", "Bones, broken jaw and splinters", "", "bone", [
        [-5, -8, -4, -3, -6, 1], [-4, -8, 0, 1, -6, 2],
        [0, -8, -3, 2, -6, 1], [4, -8, -5, 6, -7, -1],
        [-1, -8, 5, 4, -7, 6]], bone_note)
    add("gravestone_slab", "Gravestone, weathered stele", "default:cobble", "grave", [
        [-6, -8, -3, 6, -6, 3], [-5, -6, -1, 4, 3, 2],
        [-4, 3, -1, 5, 6, 2], [-3, 6, -1, 4, 8, 2]],
        "A rounded stele alone; add gravestone_cross one node above for a taller memorial. Offset courses suggest a lean.")
    add("gravestone_cross", "Gravestone, chipped cross crown", "default:cobble", "grave", [
        [-2, -8, -1, 2, 2, 2], [-6, -4, -1, 5, -1, 2],
        [-5, -1, -1, 4, 0, 2], [-1, 2, -1, 2, 4, 2]],
        "Low wayside cross alone, or the crown on gravestone_slab. Keep the same quarter-turn when stacking.")
    add("cairn_course", "Cairn, rough stone course", "default:cobble", "cairn", [
        [-6, -8, -5, 6, -5, 5], [-7, -7, -3, 6, -4, 4],
        [-5, -4, -6, 5, 0, 5], [-6, -2, -4, 4, 1, 4],
        [-5, 1, -4, 6, 5, 5], [-5, 5, -4, 5, 8, 4]],
        "Stack one or two courses, then cairn_cap, for a compact two- or three-node waymark. Every course reaches the next node.")
    add("cairn_cap", "Cairn, offset cap stones", "default:cobble", "cairn", [
        [-4, -8, -3, 5, -5, 4], [-5, -7, -2, 4, -4, 3],
        [-3, -4, -3, 3, -1, 2], [-2, -1, -1, 2, 1, 2]],
        "Finish a cairn_course stack with this low, off-centre cap; do not repeat caps vertically.")
    add("statue_veiled_head", "Statue, worn veiled head", "default:silver_sandstone", "silver", [
        [-2, -8, -2, 2, -5, 2], [-4, -5, -3, 4, 4, 3],
        [-3, 4, -2, 3, 6, 3], [-5, -5, -2, -4, 2, 3],
        [4, -3, -2, 5, 2, 3], [-3, -4, -4, 3, 2, -3],
        [-4, 2, -4, 4, 4, -3]],
        "Weathered silver sandstone, an erased face beneath a hood. Stack above statue_broken_torso with the same quarter-turn.")
    add("statue_broken_torso", "Statue, broken draped torso", "default:silver_sandstone", "silver", [
        [-5, -8, -3, 5, -3, 3], [-4, -3, -3, 4, 4, 3],
        [-6, 1, -3, 5, 6, 3], [-3, 6, -2, 3, 8, 2],
        [-7, -2, -2, -5, 3, 2], [5, 2, -2, 7, 4, 2],
        [-3, -6, -4, -1, 1, -3], [1, -8, -4, 3, 0, -3]],
        "Silver sandstone with a missing arm and worn drapery. Use plain silver-sandstone blocks for the plinth, optionally add the head.")
    add("obelisk_broken_tip", "Obelisk, fractured stone tip", "default:stone", "obelisk", [
        [-6, -8, -6, 6, -3, 6], [-5, -3, -5, 5, 1, 5],
        [-4, 1, -4, 4, 4, 4], [-3, 4, -3, 2, 6, 3],
        [-2, 6, -1, 0, 8, 2]],
        "Cracked grey stone for an undead obelisk; the shaft and plinth use ordinary default:stone blocks.")
    add("driftwood_log", "Driftwood, bleached log", "default:wood", "wood", [
        [-7, -8, -2, 7, -4, 3], [-6, -7, -3, 6, -5, 4],
        [-5, -4, -1, 5, -3, 2], [5, -7, -2, 8, -5, 1]],
        "Recommend default:wood for the substantial low log; pale grain and broken end rings suggest sea-worn wood.")
    add("driftwood_fork", "Driftwood, forked branch", "default:stick", "wood", [
        [-7, -8, -1, 5, -6, 1], [-5, -7, -2, 3, -5, 1],
        [1, -8, 0, 3, -6, 4], [2, -8, 3, 5, -6, 6],
        [4, -8, 5, 6, -7, 8], [4, -8, -2, 7, -7, 0]],
        "Recommend default:stick for the thin fork, reserving default:wood for driftwood_log.")
    return props


def face_corners(box, face):
    x1, y1, z1, x2, y2, z2 = box
    # Top-left, top-right, bottom-left in the face's texture coordinates.
    return (((x1, y2, z2), (x2, y2, z2), (x1, y2, z1)),
            ((x1, y1, z1), (x2, y1, z1), (x1, y1, z2)),
            ((x2, y2, z1), (x2, y2, z2), (x2, y1, z1)),
            ((x1, y2, z2), (x1, y2, z1), (x1, y1, z2)),
            ((x2, y2, z2), (x1, y2, z2), (x2, y1, z2)),
            ((x1, y2, z1), (x2, y2, z1), (x1, y1, z1)))[face]


def turn(point, rotation):
    x, y, z = point
    for _ in range(rotation % 4):
        x, z = -z, x
    return x, y, z


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


class Renderer:
    """Pixel-centre orthographic rasterizer with UVs, backface culling and depth.

    No interpolation of texels, outlines, antialiasing or contact shadows.
    Every box face is submitted, including touching faces, as in the format.
    """

    def __init__(self, size, origin, front=False):
        self.image = Image.new("RGBA", size, CLEAR)
        self.depth = [-math.inf] * (size[0] * size[1])
        self.origin = origin
        if front:
            self.horizontal, self.vertical, self.camera = (1, 0, 0), (0, -1, 0), (0, 0, -1)
        else:
            self.horizontal = (math.sqrt(3) / 2, 0, .5)
            self.vertical = (.25, -math.sqrt(3) / 2, -math.sqrt(3) / 4)
            self.camera = (math.sqrt(3) / 4, .5, -.75)

    def project(self, p):
        return (dot(p, self.horizontal) + self.origin[0],
                dot(p, self.vertical) + self.origin[1], dot(p, self.camera))

    def box(self, box, tiles, offset=(0, 0, 0), rotation=0):
        for face, normal in enumerate(NORMALS):
            normal = turn(normal, rotation)
            if dot(normal, self.camera) <= 0:
                continue
            points = [tuple(a + b for a, b in zip(turn(p, rotation), offset))
                      for p in face_corners(box, face)]
            p, q, r = [self.project(point) for point in points]
            au, av = q[0] - p[0], q[1] - p[1]
            bu, bv = r[0] - p[0], r[1] - p[1]
            det = au * bv - av * bu
            if abs(det) < 1e-8:
                continue
            fourth = (q[0] + r[0] - p[0], q[1] + r[1] - p[1])
            xs, ys = [a[0] for a in (p, q, r, fourth)], [a[1] for a in (p, q, r, fourth)]
            u1, v1, u2, v2 = face_rect(box, face)
            tile = tiles[min(face, len(tiles) - 1)]
            shade = 1.0 if normal[1] > 0 else .80 if normal[0] else .91
            for y in range(max(0, math.floor(min(ys))), min(self.image.height, math.ceil(max(ys)))):
                for x in range(max(0, math.floor(min(xs))), min(self.image.width, math.ceil(max(xs)))):
                    dx, dy = x + .5 - p[0], y + .5 - p[1]
                    u, v = (dx * bv - dy * bu) / det, (dy * au - dx * av) / det
                    if not (0 <= u < 1 and 0 <= v < 1):
                        continue
                    depth = p[2] + u * (q[2] - p[2]) + v * (r[2] - p[2])
                    index = y * self.image.width + x
                    if depth < self.depth[index] - 1e-8:
                        continue
                    color = tile.getpixel((math.floor(u1 + u * (u2 - u1)) % 16,
                                           math.floor(v1 + v * (v2 - v1)) % 16))
                    if not color[3]:
                        continue
                    self.depth[index] = depth
                    self.image.putpixel((x, y), tuple(round(c * shade) for c in color[:3]) + (255,))

    def prop(self, prop, position=(0, 0, 0), rotation=0):
        for box in prop["spec"]["boxes"]:
            self.box(box, prop["tiles"], position, rotation)


def label(canvas, x, y, value, color, scale=2):
    draw = ImageDraw.Draw(canvas)
    for char in value.upper():
        for dy, row in enumerate(FONT[char].split("/")):
            for dx, bit in enumerate(row):
                if bit == "1":
                    px, py = x + dx * scale, y + dy * scale
                    draw.rectangle((px, py, px + scale - 1, py + scale - 1), fill=color)
        x += 4 * scale


def show(canvas, image, x, y, scale=1):
    canvas.alpha_composite(image.resize((image.width * scale, image.height * scale), NEAREST), (x, y))


def context_tile(material):
    # Original neutral stand-ins for ordinary blocks, never proposed new props.
    palette = PALETTES[material]
    image = Image.new("RGBA", (16, 16), rgba(palette[2]))
    for y in range(16):
        for x in range(16):
            if grain(x // 2, y // 2, 83) > 205:
                image.putpixel((x, y), rgba(palette[1]))
    return image


def scene(props, kind):
    r = Renderer((176, 112), (88, 66))
    ground = dict(wild="blight_dirt", town="bone_litter_top", cairn="bone_litter_top",
                  bones="blight_dirt", badlands="mesa_clay", elf="silver_litter_top",
                  beach="sand", obelisk="blight_dirt")[kind]
    with Image.open(HERE / "grounds" / (ground + "_32.png")) as source:
        ground_tile = source.convert("RGBA")
    for x in range(-3, 3):
        for z in range(-2, 3):
            tile = ground_tile.crop(((x % 2) * 16, (z % 2) * 16,
                                     (x % 2) * 16 + 16, (z % 2) * 16 + 16))
            r.box([-8, -2, -8, 8, 0, 8], [tile], (x * 16 + 8, 0, z * 16))

    def put(key, x, level, z, rotation=0):
        r.prop(props[key], (x * 16, level * 16 + 8, z * 16), rotation)

    def block(material, x, level, z):
        r.box([-8, -8, -8, 8, 8, 8], [context_tile(material)], (x * 16, level * 16 + 8, z * 16))

    if kind == "wild":
        put("gravestone_slab", -2, 0, 0, 0)
        put("gravestone_cross", 0, 0, 1, 1)
        put("gravestone_slab", 2, 0, -1, 0)
        put("gravestone_slab", 0, 0, -1, 0)
        put("gravestone_cross", 0, 1, -1, 0)
        for x, height in ((-36, 13), (-12, 9), (12, 14)):
            r.box([-1, 0, -1, 1, height, 1], [context_tile("wood")], (x, 0, 30))
        r.box([-36, 6, 29, -12, 8, 31], [context_tile("wood")])
    elif kind == "town":
        for x in (-2, 0, 2):
            put("gravestone_slab", x, 0, 0)
            put("gravestone_cross", x, 1, 0)
    elif kind == "cairn":
        put("cairn_course", -1, 0, 0)
        put("cairn_cap", -1, 1, 0, 1)
        put("cairn_course", 1, 0, 0)
        put("cairn_course", 1, 1, 0, 1)
        put("cairn_cap", 1, 2, 0, 2)
    elif kind == "bones":
        put("skull_human", 0, 0, -1)
        put("ribcage_human", 0, 0, 0)
    elif kind == "badlands":
        put("skull_horned", 0, 0, -1, 1)
        put("spine_animal", 1, 0, -1, 1)
    elif kind == "elf":
        block("silver", 0, 0, 0)
        put("statue_broken_torso", 0, 1, 0)
        put("statue_veiled_head", 0, 2, 0)
        block("silver", -2, 0, 1)
    elif kind == "beach":
        put("driftwood_log", -1, 0, 0)
        put("driftwood_fork", 1, 0, -1, 1)
    elif kind == "obelisk":
        block("obelisk", 0, 0, 0)
        block("obelisk", 0, 1, 0)
        put("obelisk_broken_tip", 0, 2, 0)
    return r.image


def preview(props):
    scenes = [("wild", "WILD GRAVEYARD / FOUR CROOKED STONES", "GRAVESTONE_SLAB + GRAVESTONE_CROSS / DEFAULT:COBBLE"),
              ("town", "TOWN ROW / THREE MATCHING MEMORIALS", "GRAVESTONE_SLAB + GRAVESTONE_CROSS / DEFAULT:COBBLE"),
              ("cairn", "CAIRNS / TWO AND THREE NODES HIGH", "CAIRN_COURSE + CAIRN_CAP / DEFAULT:COBBLE"),
              ("bones", "ONE FIND / HUMANOID SKULL AND RIBCAGE", "SKULL_HUMAN + RIBCAGE_HUMAN / NOTHING"),
              ("badlands", "ORC BADLANDS / HORNED SKULL AND SPINE", "SKULL_HORNED + SPINE_ANIMAL / NOTHING"),
              ("elf", "ELF RELIC / WORN SANDSTONE ON SILVER LITTER", "STATUE_BROKEN_TORSO + STATUE_VEILED_HEAD / DEFAULT:SILVER_SANDSTONE"),
              ("obelisk", "UNDEAD RELIC / FRACTURED OBELISK ON A PLAIN SHAFT", "OBELISK_BROKEN_TIP / DEFAULT:STONE / SHAFT USES ORDINARY BLOCKS"),
              ("beach", "BEACH / BLEACHED WOOD ON SAND", "DRIFTWOOD_LOG / DEFAULT:WOOD + DRIFTWOOD_FORK / DEFAULT:STICK")]
    start = 112 + len(props) * 208
    out = Image.new("RGBA", (1600, start + 80 + len(scenes) * 520))
    for column, (bg, fg) in enumerate((("eee9dd", "373d35"), ("252d2b", "dddacb"))):
        ox, color = column * 800, rgba(fg)
        ImageDraw.Draw(out).rectangle((ox, 0, ox + 799, out.height), fill=rgba(bg))
        label(out, ox + 24, 20, "LAND PROPS / ROUND 51 / ARTL PASS 2", color)
        label(out, ox + 24, 44, "ORIGINAL CC0 PIXELS + NODE BOXES / GPT-6 ASTRA", color, 1)
        label(out, ox + 24, 62, "1X = 16 TEXELS PER NODE / 4X = NEAREST NEIGHBOUR", color, 1)
        label(out, ox + 24, 80, "FRONT IS -Z / THREE-QUARTER SHOWS FRONT + RIGHT + TOP", color, 1)
        for i, (key, prop) in enumerate(props.items()):
            y = 112 + i * 208
            ImageDraw.Draw(out).line((ox + 24, y - 8, ox + 775, y - 8), fill=rgba("99998b"))
            for f, x in ((True, 24), (False, 232)):
                render = Renderer((32, 32), (16, 16), front=f)
                render.prop(prop)
                label(out, ox + x, y + 2, "FRONT" if f else "THREE-QUARTER", color, 1)
                show(out, render.image, ox + x, y + 50)
                show(out, render.image, ox + x + 48, y + 14, 4)
                label(out, ox + x, y + 94, "1X", color, 1)
                label(out, ox + x + 100, y + 143, "4X", color, 1)
            label(out, ox + 448, y + 4, "FACE STRIPS / 2X", color, 1)
            for face, tile in enumerate(prop["tiles"]):
                x = ox + 448 + face * 54
                label(out, x, y + 28, ("+Y", "-Y", "+X", "-X", "+Z", "-Z")[face], color, 1)
                # Plain unused texels remain in the asset; dim them on this
                # diagnostic strip so only the projected face coverage reads.
                swatch = tile.copy()
                for v in range(16):
                    for u in range(16):
                        if not prop["masks"][face].getpixel((u, v)):
                            swatch.putpixel((u, v), rgba(bg))
                show(out, swatch, x, y + 44, 2)
            label(out, ox + 448, y + 94, str(len(prop["spec"]["boxes"])) + " BOXES / " +
                  ("CLIP" if "alpha" in prop["spec"] else "OPAQUE"), color, 1)
            label(out, ox + 24, y + 166, key, color)
            label(out, ox + 24, y + 187, "DROP: " + (prop["spec"]["drop"] or "NOTHING"), color, 1)
        label(out, ox + 24, start + 12, "SMALL COMPOSITIONS / KIT STUDIES", color)
        label(out, ox + 24, start + 38, "FULL NODE SPACING / QUARTER-TURNS ONLY / NO TILTED OR SCALED BOXES", color, 1)
        label(out, ox + 24, start + 55, "CONTEXT BLOCKS ARE ORIGINAL COLOUR STAND-INS / NO ENGINE LIGHTING", color, 1)
        for i, (kind, title, drops) in enumerate(scenes):
            y = start + 80 + i * 520
            label(out, ox + 24, y + 2, title, color, 1)
            picture = scene(props, kind)
            show(out, picture, ox + 24, y + 24, 4)
            # Native crop is useful for assessing distance, with identical pixels.
            show(out, picture, ox + 584, y + 354)
            label(out, ox + 584, y + 478, "1X", color, 1)
            label(out, ox + 24, y + 478, "4X", color, 1)
            label(out, ox + 24, y + 500, drops, color, 1)
    return out


def encoded_png(image):
    stream = io.BytesIO()
    image.save(stream, format="PNG", optimize=False)
    return stream.getvalue()


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def validate_folder(folder):
    """Read every delivered prop, not just the generator's in-memory data."""
    assert re.fullmatch(r"[a-z0-9_]+", folder.name), folder
    spec = json.loads((folder / "prop.json").read_text(encoding="utf-8"))
    assert isinstance(spec, dict), folder
    assert set(spec) <= {"name", "drop", "tiles", "boxes", "alpha", "rotate", "note"}, folder
    for field in ("name", "drop"):
        assert isinstance(spec.get(field), str), (folder, field)
    assert spec["name"].strip() and "\n" not in spec["name"], folder
    assert spec["drop"] == "" or re.fullmatch(r"default:[a-z0-9_]+", spec["drop"]), folder
    assert spec.get("alpha") in (None, "clip"), folder
    assert type(spec.get("rotate", True)) is bool, folder
    assert isinstance(spec.get("note", ""), str) and "\n" not in spec.get("note", ""), folder
    boxes = spec.get("boxes")
    assert isinstance(boxes, list) and boxes, folder
    for box in boxes:
        assert isinstance(box, list) and len(box) == 6, (folder, box)
        assert all(type(v) in (int, float) and math.isfinite(v) and -8 <= v <= 8 for v in box), (folder, box)
        assert all(box[axis] < box[axis + 3] for axis in range(3)), (folder, box)
    names = spec.get("tiles")
    assert isinstance(names, list) and 1 <= len(names) <= 6, folder
    images = {}
    for name in names:
        assert isinstance(name, str) and re.fullmatch(
            re.escape(folder.name) + r"(?:_(?:top|bottom|side|front|back|right|left))?\.png", name), (folder, name)
        path = folder / name
        assert path.is_file(), path
        with Image.open(path) as image:
            assert image.size == (16, 16) and image.mode == "RGBA", path
            pixels = list(image.get_flattened_data())
            alphas = sorted({p[3] for p in pixels})
            assert set(alphas) <= ({0, 255} if spec.get("alpha") == "clip" else {255}), path
            assert all(p[3] or p == CLEAR for p in pixels), path
            images[name] = dict(size=list(image.size), mode=image.mode, alpha=alphas,
                                sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    assert {p.name for p in folder.iterdir()} == {"prop.json", *names}, folder
    return dict(name=spec["name"], drop=spec["drop"], boxes=len(boxes),
                bounds=[min(b[a] for b in boxes) for a in range(3)] +
                       [max(b[a + 3] for b in boxes) for a in range(3)],
                prop_sha256=hashlib.sha256((folder / "prop.json").read_bytes()).hexdigest(), images=images)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate all folders and compare generated bytes without writing")
    args = parser.parse_args()
    props = build_props()
    outputs = {}
    for key, prop in props.items():
        outputs[HERE / "props" / key / "prop.json"] = json_bytes(prop["spec"])
        for name, tile in zip(prop["spec"]["tiles"], prop["tiles"]):
            outputs[HERE / "props" / key / name] = encoded_png(tile)
    outputs[HERE / "preview-props.png"] = encoded_png(preview(props))
    for path, data in outputs.items():
        if args.check:
            assert path.is_file() and path.read_bytes() == data, "Stale output: " + str(path)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    folders = sorted((HERE / "props").iterdir())
    assert {p.name for p in folders} == set(props), "Unexpected prop folder"
    report = {p.name: validate_folder(p) for p in folders}
    record = json_bytes(dict(format="README.md / Prop format", props=report,
                             preview_sha256=hashlib.sha256(outputs[HERE / "preview-props.png"]).hexdigest()))
    path = HERE / "props-checks.json"
    if args.check:
        assert path.read_bytes() == record, "Stale props-checks.json"
    else:
        path.write_bytes(record)
    print("PASS: %d props, %d RGBA tiles, all schemas, alpha, paths and bounds; %s." %
          (len(props), sum(len(p["tiles"]) for p in props.values()),
           "byte-identical regeneration checked without writes" if args.check else "outputs generated and reopened"))


if __name__ == "__main__":
    main()
