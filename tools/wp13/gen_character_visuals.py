#!/usr/bin/env python3
"""Generate the WP13 character-visuals art: six race skins and eight armor
overlays for `character.b3d`, plus optional review composites.

All art is original work of this project (CC0 1.0, the licence every other
own-art mod in this tree uses -- see mods/PLAYER/grug_visuals/LICENSE-media.md)
and is produced deterministically: re-running this script reproduces every PNG
byte for byte, which is what lets `LICENSE-media.md` name a generator instead of
a hand-edited file.

UV layout: the classic 64x32 Minecraft-1.7 skin layout, which is exactly what
`mods/BASE/player_api/models/character.b3d` uses (the same layout the mirefolk
generator in docs/research/assets/wp6_model_notes.md paints against, verified
again here by parsing the mesh: bones Body/Head/Arm_Left/Arm_Right/Leg_Right/
Leg_Left, and the opaque regions of `character.png` land exactly on the boxes
below).

    python3 tools/wp13/gen_character_visuals.py                # write textures
    python3 tools/wp13/gen_character_visuals.py --renders DIR  # + composites

Requires Pillow. No game runtime, no engine.
"""
import argparse
import random
from pathlib import Path

from PIL import Image

W, H = 64, 32
SEED = 20260914

# --------------------------------------------------------------------------
# The 64x32 box layout. Every value is (x, y, w, h); `bottom` faces are the
# under-sides (chin, palm, sole), `back` is the rear face.
# --------------------------------------------------------------------------
HEAD = {"top": (8, 0, 8, 8), "bottom": (16, 0, 8, 8), "right": (0, 8, 8, 8),
        "front": (8, 8, 8, 8), "left": (16, 8, 8, 8), "back": (24, 8, 8, 8)}
# The "hat" layer: a slightly larger cube around the head. Hair, beards,
# helmets and hoods live here, which is what lets an overlay cover a helmet
# over hair without touching the face underneath.
HAT = {"top": (40, 0, 8, 8), "bottom": (48, 0, 8, 8), "right": (32, 8, 8, 8),
       "front": (40, 8, 8, 8), "left": (48, 8, 8, 8), "back": (56, 8, 8, 8)}
TORSO = {"top": (20, 16, 8, 4), "bottom": (28, 16, 8, 4),
         "right": (16, 20, 4, 12), "front": (20, 20, 8, 12),
         "left": (28, 20, 4, 12), "back": (32, 20, 8, 12)}
ARM = {"top": (44, 16, 4, 4), "bottom": (48, 16, 4, 4),
       "right": (40, 20, 4, 12), "front": (44, 20, 4, 12),
       "left": (48, 20, 4, 12), "back": (52, 20, 4, 12)}
LEG = {"top": (4, 16, 4, 4), "bottom": (8, 16, 4, 4),
       "right": (0, 20, 4, 12), "front": (4, 20, 4, 12),
       "left": (8, 20, 4, 12), "back": (12, 20, 4, 12)}

SIDES = ("right", "front", "left", "back")


def canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


class Paint:
    """Pixel helpers over one image; `rng` is seeded per file so the speckle is
    part of the deterministic output."""

    def __init__(self, image, seed):
        self.px = image.load()
        self.rng = random.Random(seed)

    def box(self, x, y, w, h, col):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.px[i, j] = col

    def fill(self, region, col):
        self.box(*region, col=col)

    def row(self, region, r, col, x0=0, w=None):
        x, y, rw, _ = region
        self.box(x + x0, y + r, w if w is not None else rw - x0, 1, col)

    def col(self, region, c, col, y0=0, h=None):
        x, y, _, rh = region
        self.box(x + c, y + y0, 1, h if h is not None else rh - y0, col)

    def speckle(self, region, dark, light, rate=0.14):
        x, y, w, h = region
        for j in range(y, y + h):
            for i in range(x, x + w):
                r = self.rng.random()
                if r < rate:
                    self.px[i, j] = dark
                elif r < rate * 1.7:
                    self.px[i, j] = light

    def edges(self, region, dark):
        """One darker pixel column down each vertical seam: cheap volume."""
        x, y, w, h = region
        for j in range(y, y + h):
            self.px[x, j] = dark
            self.px[x + w - 1, j] = dark


# --------------------------------------------------------------------------
# Race palettes. Six clearly separated silhouettes-by-colour: skin hue, hair
# mass and dress colour all differ, so a race is readable at hotbar distance
# even before the stature scale is applied.
# --------------------------------------------------------------------------
RACES = {
    "human": dict(
        skin=(224, 176, 140), skin_d=(190, 142, 108), skin_l=(240, 202, 170),
        hair=(96, 60, 34), hair_d=(66, 40, 22),
        cloth=(78, 96, 132), cloth_d=(56, 70, 100), cloth_l=(106, 126, 162),
        trouser=(88, 70, 52), trouser_d=(62, 48, 36),
        boot=(62, 46, 32), boot_d=(40, 28, 20),
        accent=(170, 142, 84), eye=(42, 60, 98),
        style="short_hair", bare_chest=False, tusks=False),
    "dwarf": dict(
        skin=(216, 160, 124), skin_d=(180, 126, 94), skin_l=(236, 188, 156),
        hair=(196, 90, 44), hair_d=(148, 60, 28),
        cloth=(74, 104, 74), cloth_d=(52, 78, 52), cloth_l=(100, 132, 98),
        trouser=(92, 72, 48), trouser_d=(66, 50, 32),
        boot=(66, 46, 30), boot_d=(44, 30, 18),
        accent=(194, 158, 74), eye=(74, 46, 22),
        style="beard", bare_chest=False, tusks=False),
    "elf": dict(
        skin=(238, 222, 200), skin_d=(210, 190, 166), skin_l=(252, 242, 228),
        hair=(228, 216, 168), hair_d=(188, 174, 126),
        cloth=(104, 132, 108), cloth_d=(74, 100, 78), cloth_l=(138, 166, 140),
        trouser=(96, 112, 96), trouser_d=(70, 86, 70),
        boot=(78, 66, 50), boot_d=(54, 44, 32),
        accent=(200, 208, 182), eye=(108, 152, 120),
        style="long_hair", bare_chest=False, tusks=False),
    "undead": dict(
        skin=(150, 164, 140), skin_d=(114, 128, 106), skin_l=(180, 192, 170),
        hair=(88, 82, 94), hair_d=(60, 56, 66),
        cloth=(78, 64, 92), cloth_d=(54, 44, 66), cloth_l=(104, 88, 120),
        trouser=(64, 60, 66), trouser_d=(44, 42, 48),
        boot=(52, 46, 46), boot_d=(32, 28, 28),
        accent=(200, 194, 172), eye=(198, 222, 112),
        style="patchy", bare_chest=False, tusks=False),
    "orc": dict(
        skin=(108, 148, 72), skin_d=(78, 114, 50), skin_l=(140, 178, 100),
        hair=(34, 32, 36), hair_d=(20, 18, 22),
        cloth=(110, 76, 44), cloth_d=(80, 54, 30), cloth_l=(138, 100, 64),
        trouser=(74, 60, 44), trouser_d=(52, 42, 30),
        boot=(58, 42, 28), boot_d=(36, 26, 16),
        accent=(178, 152, 112), eye=(208, 72, 48),
        style="topknot", bare_chest=True, tusks=True),
    "troll": dict(
        skin=(96, 132, 150), skin_d=(68, 100, 118), skin_l=(128, 164, 180),
        hair=(46, 58, 96), hair_d=(30, 40, 70),
        cloth=(176, 140, 72), cloth_d=(142, 110, 50), cloth_l=(202, 172, 110),
        trouser=(120, 96, 60), trouser_d=(90, 70, 44),
        boot=(78, 62, 40), boot_d=(52, 40, 26),
        accent=(228, 222, 198), eye=(238, 196, 76),
        style="mane", bare_chest=True, tusks=True),
}

TUSK = (236, 230, 206)
EYE_WHITE = (238, 240, 232)


# --------------------------------------------------------------------------
# Race skin
# --------------------------------------------------------------------------
def paint_head(p, c):
    for face in SIDES:
        p.fill(HEAD[face], c["skin"])
        p.speckle(HEAD[face], c["skin_d"], c["skin_l"], 0.08)
        p.edges(HEAD[face], c["skin_d"])
    p.fill(HEAD["top"], c["skin"])
    p.fill(HEAD["bottom"], c["skin_d"])

    f = HEAD["front"]
    # Brow, eyes, nose, mouth. Rows are counted inside the 8x8 face.
    p.row(f, 2, c["skin_d"], 1, 6)
    for ex in (1, 5):
        p.box(f[0] + ex, f[1] + 3, 2, 2, EYE_WHITE)
    p.box(f[0] + 2, f[1] + 3, 1, 2, c["eye"])
    p.box(f[0] + 5, f[1] + 3, 1, 2, c["eye"])
    p.box(f[0] + 3, f[1] + 4, 2, 2, c["skin_d"])
    p.row(f, 6, c["skin_d"], 2, 4)
    if c["tusks"]:
        p.box(f[0] + 1, f[1] + 5, 1, 2, TUSK)
        p.box(f[0] + 6, f[1] + 5, 1, 2, TUSK)
    if c["style"] == "patchy":
        # Sunken sockets instead of a brow: the pallid look needs the shadow.
        p.box(f[0] + 1, f[1] + 2, 2, 1, c["skin_d"])
        p.box(f[0] + 5, f[1] + 2, 2, 1, c["skin_d"])
        p.box(f[0] + 2, f[1] + 3, 1, 1, c["eye"])
        p.box(f[0] + 5, f[1] + 3, 1, 1, c["eye"])


def paint_hair(p, c):
    style = c["style"]
    hair, dark = c["hair"], c["hair_d"]
    if style == "short_hair":
        p.fill(HAT["top"], hair)
        for face in ("right", "left", "back"):
            p.box(HAT[face][0], HAT[face][1], 8, 4, hair)
        p.box(HAT["front"][0], HAT["front"][1], 8, 2, hair)
        p.row(HAT["front"], 2, dark, 0, 8)
    elif style == "long_hair":
        p.fill(HAT["top"], hair)
        for face in ("right", "left"):
            p.box(HAT[face][0], HAT[face][1], 8, 8, hair)
        p.fill(HAT["back"], hair)
        p.box(HAT["front"][0], HAT["front"][1], 8, 2, hair)
        p.row(HAT["front"], 2, dark, 0, 8)
        # Pointed ears: the one silhouette cue the hat layer can carry.
        p.box(HAT["right"][0] + 5, HAT["right"][1] + 3, 2, 1, c["skin_l"])
        p.box(HAT["left"][0] + 1, HAT["left"][1] + 3, 2, 1, c["skin_l"])
    elif style == "beard":
        p.fill(HAT["top"], hair)
        for face in ("right", "left", "back"):
            p.fill(HAT[face], hair)
        # Face: a brow fringe on top, a full beard below, eyes left clear.
        p.box(HAT["front"][0], HAT["front"][1], 8, 2, hair)
        p.box(HAT["front"][0], HAT["front"][1] + 5, 8, 3, hair)
        p.box(HAT["front"][0] + 3, HAT["front"][1] + 5, 2, 1, dark)
        p.box(HAT["right"][0] + 4, HAT["right"][1] + 4, 4, 4, hair)
        p.box(HAT["left"][0], HAT["left"][1] + 4, 4, 4, hair)
    elif style == "topknot":
        p.box(HAT["top"][0] + 3, HAT["top"][1], 2, 8, hair)
        p.box(HAT["back"][0] + 3, HAT["back"][1], 2, 6, hair)
        p.box(HAT["back"][0] + 3, HAT["back"][1], 2, 1, dark)
    elif style == "mane":
        p.fill(HAT["top"], hair)
        p.fill(HAT["back"], hair)
        for face in ("right", "left"):
            p.box(HAT[face][0], HAT[face][1], 8, 3, hair)
        p.box(HAT["front"][0], HAT["front"][1], 8, 1, dark)
    elif style == "patchy":
        # Torn scalp: a few strands, nothing on the face.
        for cx in (0, 2, 5, 7):
            p.box(HAT["top"][0] + cx, HAT["top"][1], 1, 8, hair)
        p.box(HAT["back"][0] + 1, HAT["back"][1], 1, 4, hair)
        p.box(HAT["back"][0] + 5, HAT["back"][1], 1, 5, dark)


def paint_torso(p, c):
    for face in SIDES:
        p.fill(TORSO[face], c["cloth"])
        p.speckle(TORSO[face], c["cloth_d"], c["cloth_l"], 0.10)
        p.edges(TORSO[face], c["cloth_d"])
    p.fill(TORSO["top"], c["cloth_l"])
    p.fill(TORSO["bottom"], c["trouser_d"])
    # Collar (the neck opening) and belt.
    p.row(TORSO["front"], 0, c["skin_d"], 2, 4)
    for face in SIDES:
        p.row(TORSO[face], 8, c["trouser_d"])
        p.row(TORSO[face], 9, c["trouser_d"])
    p.box(TORSO["front"][0] + 3, TORSO["front"][1] + 8, 2, 2, c["accent"])
    if c["bare_chest"]:
        # Harness instead of a shirt: chest and back skin, two straps.
        p.box(TORSO["front"][0] + 1, TORSO["front"][1] + 1, 6, 7, c["skin"])
        p.speckle((TORSO["front"][0] + 1, TORSO["front"][1] + 1, 6, 7),
                  c["skin_d"], c["skin_l"], 0.10)
        p.box(TORSO["back"][0] + 1, TORSO["back"][1] + 1, 6, 7, c["skin"])
        p.box(TORSO["front"][0] + 2, TORSO["front"][1] + 1, 1, 7, c["cloth_d"])
        p.box(TORSO["front"][0] + 5, TORSO["front"][1] + 1, 1, 7, c["cloth_d"])
        p.box(TORSO["back"][0] + 3, TORSO["back"][1] + 1, 2, 7, c["cloth_d"])
    if c["style"] == "patchy":
        # Ribs showing through a torn wrap.
        for r in (2, 4, 6):
            p.row(TORSO["front"], r, c["skin_d"], 1, 6)
            p.row(TORSO["back"], r, c["cloth_d"], 1, 6)


def paint_arms(p, c):
    bare = c["bare_chest"]
    for face in SIDES:
        region = ARM[face]
        if bare:
            p.fill(region, c["skin"])
            p.speckle(region, c["skin_d"], c["skin_l"], 0.08)
            p.box(region[0], region[1] + 2, region[2], 2, c["accent"])
        else:
            p.fill(region, c["cloth"])
            p.speckle(region, c["cloth_d"], c["cloth_l"], 0.10)
            p.box(region[0], region[1] + 6, region[2], 6, c["skin"])
            p.box(region[0], region[1] + 6, region[2], 1, c["skin_d"])
        p.box(region[0], region[1] + 10, region[2], 2, c["skin_d"])
        p.edges(region, c["skin_d"] if bare else c["cloth_d"])
    p.fill(ARM["top"], c["skin"] if bare else c["cloth_l"])
    p.fill(ARM["bottom"], c["skin_d"])


def paint_legs(p, c):
    for face in SIDES:
        region = LEG[face]
        p.fill(region, c["trouser"])
        p.speckle(region, c["trouser_d"], c["cloth_l"], 0.08)
        p.box(region[0], region[1] + 8, region[2], 4, c["boot"])
        p.box(region[0], region[1] + 8, region[2], 1, c["boot_d"])
        p.edges(region, c["trouser_d"])
    p.fill(LEG["top"], c["trouser_d"])
    p.fill(LEG["bottom"], c["boot_d"])


def race_skin(race):
    c = RACES[race]
    image = canvas()
    p = Paint(image, SEED + sum(ord(ch) for ch in race))
    paint_head(p, c)
    paint_hair(p, c)
    paint_torso(p, c)
    paint_arms(p, c)
    paint_legs(p, c)
    return image


# --------------------------------------------------------------------------
# Armor overlays. Transparent everywhere they do not cover, drawn in the
# bracket-6 ("Grand") colour so `^[multiply:<bracket tint>` darkens them down
# the ladder exactly the way grug_gear tints its item images -- #ffffff, the
# bracket-6 tint, is a no-op.
# --------------------------------------------------------------------------
def shade(col, factor):
    """Darken a palette entry so legs and feet read apart from the chest even
    after the bracket tint has multiplied everything by the same colour."""
    return tuple(min(255, int(round(v * factor))) for v in col[:3]) + \
        (col[3] if len(col) > 3 else 255,)


def shaded_line(line, factor):
    return dict((k, shade(v, factor)) for k, v in LINES[line].items())


LINES = {
    "metal": dict(base=(196, 202, 212), dark=(146, 154, 168),
                  light=(232, 238, 246), trim=(178, 146, 74),
                  rivet=(112, 118, 132)),
    "cloth": dict(base=(150, 128, 196), dark=(112, 92, 158),
                  light=(186, 168, 222), trim=(204, 186, 118),
                  rivet=(84, 68, 120)),
}


def overlay_head(line):
    c = LINES[line]
    image = canvas()
    p = Paint(image, SEED + 11 + len(line))
    p.fill(HAT["top"], c["base"])
    p.box(HAT["top"][0] + 3, HAT["top"][1], 2, 8, c["light"])
    for face in ("right", "left", "back"):
        p.fill(HAT[face], c["base"])
        p.edges(HAT[face], c["dark"])
    if line == "metal":
        # Helm: full brow band, open face, nasal bar.
        p.box(HAT["front"][0], HAT["front"][1], 8, 3, c["base"])
        p.row(HAT["front"], 2, c["dark"], 0, 8)
        p.box(HAT["front"][0] + 3, HAT["front"][1] + 3, 2, 3, c["base"])
        p.box(HAT["front"][0] + 3, HAT["front"][1] + 5, 2, 1, c["dark"])
        for face in ("right", "left", "back"):
            p.row(HAT[face], 5, c["trim"], 0, 8)
        p.box(HAT["right"][0] + 1, HAT["right"][1] + 2, 1, 1, c["rivet"])
        p.box(HAT["left"][0] + 6, HAT["left"][1] + 2, 1, 1, c["rivet"])
    else:
        # Cowl: a brim over the brow, the face left open, a longer back.
        p.box(HAT["front"][0], HAT["front"][1], 8, 3, c["base"])
        p.row(HAT["front"], 2, c["dark"], 0, 8)
        for face in ("right", "left"):
            p.box(HAT[face][0], HAT[face][1] + 6, 8, 2, (0, 0, 0, 0))
        p.row(HAT["back"], 7, c["dark"], 0, 8)
        p.box(HAT["top"][0] + 3, HAT["top"][1] + 6, 2, 2, c["trim"])
    return image


def overlay_chest(line):
    c = LINES[line]
    image = canvas()
    p = Paint(image, SEED + 22 + len(line))
    for face in SIDES:
        p.fill(TORSO[face], c["base"])
        p.speckle(TORSO[face], c["dark"], c["light"], 0.05)
        p.edges(TORSO[face], c["dark"])
    p.fill(TORSO["top"], c["light"])
    p.fill(TORSO["bottom"], c["dark"])
    if line == "metal":
        # Breastplate: centre ridge, waist band, pauldrons on the shoulders.
        p.box(TORSO["front"][0] + 3, TORSO["front"][1], 2, 12, c["light"])
        p.row(TORSO["front"], 8, c["trim"], 0, 8)
        p.row(TORSO["back"], 8, c["trim"], 0, 8)
        p.box(TORSO["front"][0] + 1, TORSO["front"][1] + 1, 1, 1, c["rivet"])
        p.box(TORSO["front"][0] + 6, TORSO["front"][1] + 1, 1, 1, c["rivet"])
        sleeve = 5
    else:
        # Robe: a lighter yoke, a girdle, long sleeves.
        p.box(TORSO["front"][0] + 2, TORSO["front"][1], 4, 3, c["light"])
        p.row(TORSO["front"], 7, c["trim"], 0, 8)
        p.row(TORSO["back"], 7, c["trim"], 0, 8)
        p.row(TORSO["front"], 11, c["dark"], 0, 8)
        p.row(TORSO["back"], 11, c["dark"], 0, 8)
        sleeve = 9
    p.fill(ARM["top"], c["light"])
    for face in SIDES:
        region = ARM[face]
        p.box(region[0], region[1], region[2], sleeve, c["base"])
        p.speckle((region[0], region[1], region[2], sleeve),
                  c["dark"], c["light"], 0.05)
        p.box(region[0], region[1] + sleeve - 1, region[2], 1, c["dark"])
    return image


def overlay_legs(line):
    c = shaded_line(line, 0.86)
    image = canvas()
    p = Paint(image, SEED + 33 + len(line))
    p.fill(LEG["top"], c["light"])
    for face in SIDES:
        region = LEG[face]
        p.box(region[0], region[1], region[2], 8, c["base"])
        p.speckle((region[0], region[1], region[2], 8),
                  c["dark"], c["light"], 0.05)
        p.box(region[0], region[1], region[2], 1, c["trim"])
        if line == "metal":
            p.box(region[0], region[1] + 5, region[2], 2, c["light"])
            p.box(region[0], region[1] + 7, region[2], 1, c["dark"])
        else:
            p.box(region[0], region[1] + 7, region[2], 1, c["dark"])
        p.box(region[0], region[1], 1, 8, c["dark"])
        p.box(region[0] + region[2] - 1, region[1], 1, 8, c["dark"])
    return image


def overlay_feet(line):
    c = shaded_line(line, 0.70)
    image = canvas()
    p = Paint(image, SEED + 44 + len(line))
    p.fill(LEG["bottom"], c["dark"])
    top = 8 if line == "metal" else 9
    for face in SIDES:
        region = LEG[face]
        h = 12 - top
        p.box(region[0], region[1] + top, region[2], h, c["base"])
        p.speckle((region[0], region[1] + top, region[2], h),
                  c["dark"], c["light"], 0.05)
        p.box(region[0], region[1] + top, region[2], 1, c["trim"])
        p.box(region[0], region[1] + 11, region[2], 1, c["dark"])
        p.box(region[0], region[1] + top, 1, h, c["dark"])
        p.box(region[0] + region[2] - 1, region[1] + top, 1, h, c["dark"])
    return image


OVERLAYS = {"head": overlay_head, "chest": overlay_chest,
            "legs": overlay_legs, "feet": overlay_feet}


# --------------------------------------------------------------------------
# Review composites: a flat front paper doll, because nobody in this lane can
# open the game and look at the mesh.
# --------------------------------------------------------------------------
def paper_doll(layers, scale=8):
    """layers: list of RGBA 64x32 images, composited in order."""
    flat = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for layer in layers:
        flat = Image.alpha_composite(flat, layer)
    doll = Image.new("RGBA", (16, 32), (0, 0, 0, 0))

    def blit(src_region, dx, dy, mirror=False):
        x, y, w, h = src_region
        part = flat.crop((x, y, x + w, y + h))
        if mirror:
            part = part.transpose(Image.FLIP_LEFT_RIGHT)
        doll.alpha_composite(part, (dx, dy))

    blit(HEAD["front"], 4, 0)
    blit(HAT["front"], 4, 0)
    blit(TORSO["front"], 4, 8)
    blit(ARM["front"], 0, 8, mirror=True)
    blit(ARM["front"], 12, 8)
    blit(LEG["front"], 4, 20)
    blit(LEG["front"], 8, 20, mirror=True)
    return doll.resize((16 * scale, 32 * scale), Image.NEAREST)


def contact_sheet(dolls, cols, gap=8, bg=(36, 38, 42, 255)):
    w, h = dolls[0].size
    rows = (len(dolls) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (w + gap) + gap, rows * (h + gap) + gap),
                      bg)
    for index, doll in enumerate(dolls):
        r, c = divmod(index, cols)
        sheet.alpha_composite(doll, (gap + c * (w + gap), gap + r * (h + gap)))
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--textures", type=Path,
                        default=Path("mods/PLAYER/grug_visuals/textures"))
    parser.add_argument("--renders", type=Path, default=None,
                        help="also write review composites into this directory")
    args = parser.parse_args()
    args.textures.mkdir(parents=True, exist_ok=True)

    skins, written = {}, []
    for race in sorted(RACES):
        image = race_skin(race)
        skins[race] = image
        path = args.textures / ("grug_visuals_skin_%s.png" % race)
        image.save(path, optimize=True)
        written.append(path)

    overlays = {}
    for line in sorted(LINES):
        for slot in ("head", "chest", "legs", "feet"):
            image = OVERLAYS[slot](line)
            overlays[line, slot] = image
            path = args.textures / ("grug_visuals_%s_%s.png" % (line, slot))
            image.save(path, optimize=True)
            written.append(path)

    for path in written:
        print(path)

    if args.renders:
        args.renders.mkdir(parents=True, exist_ok=True)
        for race in sorted(RACES):
            variants = [paper_doll([skins[race]])]
            for line in ("cloth", "metal"):
                variants.append(paper_doll(
                    [skins[race]] + [overlays[line, slot]
                                     for slot in ("head", "chest", "legs",
                                                  "feet")]))
            sheet = contact_sheet(variants, 3)
            out = args.renders / ("race-%s.png" % race)
            sheet.save(out, optimize=True)
            print(out)
        allraces = contact_sheet([paper_doll([skins[r]])
                                  for r in sorted(RACES)], 6)
        allraces.save(args.renders / "races-bare.png", optimize=True)
        print(args.renders / "races-bare.png")
        for line in ("cloth", "metal"):
            sheet = contact_sheet(
                [paper_doll([skins[r]] + [overlays[line, slot]
                                          for slot in ("head", "chest",
                                                       "legs", "feet")])
                 for r in sorted(RACES)], 6)
            sheet.save(args.renders / ("races-%s.png" % line), optimize=True)
            print(args.renders / ("races-%s.png" % line))


if __name__ == "__main__":
    main()
