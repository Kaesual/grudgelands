#!/usr/bin/env python3
"""Generate the character-visuals art for `character.b3d`: the look layers
(round31-plan.md §2.1 -- skin, the race dress, eyes, hairstyles and lower-face
features as engine-coloured masks plus detail, see
mods/PLAYER/grug_visuals/looks.lua), the royal tabard and crown, the helmet
face window and the eight WP13 armor overlays.

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

    python3 tools/wp13/gen_character_visuals.py

Requires Pillow. No game runtime, no engine. Pictures of composed looks:
tools/r31_a/preview.py.
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
# Race dress palettes: the one dress each people wears under any armour, so a
# race stays readable at a distance. Skin, hair and eye colours are options of
# a look and live in looks.lua; they are not baked into any file.
# --------------------------------------------------------------------------
RACES = {
    "human": dict(
        cloth=(78, 96, 132), cloth_d=(56, 70, 100), cloth_l=(106, 126, 162),
        trouser=(88, 70, 52), trouser_d=(62, 48, 36),
        boot=(62, 46, 32), boot_d=(40, 28, 20),
        accent=(170, 142, 84), bare_chest=False, undead=False),
    "dwarf": dict(
        cloth=(74, 104, 74), cloth_d=(52, 78, 52), cloth_l=(100, 132, 98),
        trouser=(92, 72, 48), trouser_d=(66, 50, 32),
        boot=(66, 46, 30), boot_d=(44, 30, 18),
        accent=(194, 158, 74), bare_chest=False, undead=False),
    "elf": dict(
        cloth=(104, 132, 108), cloth_d=(74, 100, 78), cloth_l=(138, 166, 140),
        trouser=(96, 112, 96), trouser_d=(70, 86, 70),
        boot=(78, 66, 50), boot_d=(54, 44, 32),
        accent=(200, 208, 182), bare_chest=False, undead=False),
    "undead": dict(
        cloth=(78, 64, 92), cloth_d=(54, 44, 66), cloth_l=(104, 88, 120),
        trouser=(64, 60, 66), trouser_d=(44, 42, 48),
        boot=(52, 46, 46), boot_d=(32, 28, 28),
        accent=(200, 194, 172), bare_chest=False, undead=True),
    "orc": dict(
        cloth=(110, 76, 44), cloth_d=(80, 54, 30), cloth_l=(138, 100, 64),
        trouser=(74, 60, 44), trouser_d=(52, 42, 30),
        boot=(58, 42, 28), boot_d=(36, 26, 16),
        accent=(178, 152, 112), bare_chest=True, undead=False),
    "troll": dict(
        cloth=(176, 140, 72), cloth_d=(142, 110, 50), cloth_l=(202, 172, 110),
        trouser=(120, 96, 60), trouser_d=(90, 70, 44),
        boot=(78, 62, 40), boot_d=(52, 40, 26),
        accent=(228, 222, 198), bare_chest=True, undead=False),
}

TUSK = (236, 230, 206)
EYE_WHITE = (238, 240, 232)


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
# Round 31 appearance layers (round31-plan.md §2.1). A character is what a
# player chooses: a skin TONE, EYES, a HAIRSTYLE in a hair colour, and the
# race's lower-face FEATURE, over the race's one dress. Colours are NOT baked in: a
# colourable layer is a white MASK the engine colours with `^[multiply:<c>`,
# plus a DETAIL layer on top with the shading (semi-transparent black and
# white) and the fixed-colour pixels -- the mcl_skins technique, our own art.
# The option lists (ids, colours, counts) live in
# mods/PLAYER/grug_visuals/looks.lua; the ids below must match it (the
# r31_a fixture checks every file it names exists).
#
# One rule every layer keeps: a semi-transparent pixel only ever lands on a
# pixel that is opaque by then (the skin mask covers the whole base body, a
# hair or feature detail sits on its own mask). The engine draws the mesh with
# alpha clipping, so a half-transparent pixel on the hat layer would flicker
# between there and gone. `check_layer_alpha` asserts it on every run.
# --------------------------------------------------------------------------
SKIN_D = (0, 0, 0, 44)          # skin shadow, about skin_d of the old palettes
SKIN_L = (255, 255, 255, 56)    # skin highlight
SOCKET = (0, 0, 0, 150)         # undead eye sockets: the tone, much darker
HAIR_D = (0, 0, 0, 80)
HAIR_L = (255, 255, 255, 44)
HAIR_TIE = (0, 0, 0, 130)       # a tie or band: darker than a strand
INK = (0, 0, 0, 90)             # an ear's inner shadow, a beard's mouth line
BONE = (214, 206, 182, 255)
BONE_D = (178, 168, 142, 255)
GAP = (40, 30, 34, 255)
WARPAINT = (140, 28, 24, 255)
ELF_MARK = (64, 150, 140, 255)
BEAD = (200, 160, 60, 255)

# The helmet face window, in the hat layer's front face: columns 1..6 and
# rows 3..7 (eyes, nose, mouth, chin). Cut from every helmet at composition,
# so the eyes and every head-layer pixel of a feature must sit inside it.
FACE_WINDOW = (1, 3, 6, 5)


class Layer:
    """A mask image and a detail image painted together, face-relative."""

    def __init__(self, seed):
        self.mask, self.detail = canvas(), canvas()
        self.m, self.d = self.mask.load(), self.detail.load()
        self.rng = random.Random(seed)

    def box(self, region, x0, y0, w, h, alpha=255):
        x, y = region[0], region[1]
        for j in range(y + y0, y + y0 + h):
            for i in range(x + x0, x + x0 + w):
                self.m[i, j] = (255, 255, 255, alpha)

    def dot(self, region, x0, y0, w, h, col):
        x, y = region[0], region[1]
        for j in range(y + y0, y + y0 + h):
            for i in range(x + x0, x + x0 + w):
                self.d[i, j] = col

    def stripes(self, region, x0, y0, w, h, col=HAIR_D, phase=0):
        """Every other row darker: a braid."""
        for r in range(h):
            if (r + phase) % 2 == 0:
                self.dot(region, x0, y0 + r, w, 1, col)

    def shade(self, dark=HAIR_D, light=HAIR_L, rate=0.10):
        """Speckle every opaque mask pixel that has no detail yet. Runs last,
        in a fixed pixel order, so the output stays deterministic."""
        for j in range(H):
            for i in range(W):
                if self.m[i, j][3] == 255 and self.d[i, j][3] == 0:
                    r = self.rng.random()
                    if r < rate:
                        self.d[i, j] = dark
                    elif r < rate * 1.7:
                        self.d[i, j] = light


def mirror_x(face_w, x0, w):
    """The same span seen on the opposite side face (right <-> left)."""
    return face_w - x0 - w


def both_sides(l, x0, y0, w, h, alpha=255):
    """Paint a span on the hat's right face and its mirror on the left face.
    Columns are counted on the RIGHT face, whose column 7 meets the front."""
    l.box(HAT["right"], x0, y0, w, h, alpha)
    l.box(HAT["left"], mirror_x(8, x0, w), y0, w, h, alpha)


def both_sides_dot(l, x0, y0, w, h, col):
    l.dot(HAT["right"], x0, y0, w, h, col)
    l.dot(HAT["left"], mirror_x(8, x0, w), y0, w, h, col)


def both_cheeks(l, x0, y0, w, h, col):
    """A fixed-colour span on the hat front and its left-right mirror."""
    l.dot(HAT["front"], x0, y0, w, h, col)
    l.dot(HAT["front"], mirror_x(8, x0, w), y0, w, h, col)


# --- skin: one shared mask, one body file per race ------------------------
def layer_skin_mask():
    image = canvas()
    p = Paint(image, 0)
    for group in (HEAD, TORSO, ARM, LEG):
        for region in group.values():
            p.fill(region, (255, 255, 255, 255))
    return image


def layer_body(race):
    """Face, skin shading and the race's one dress, over the toned skin mask.
    The dress is opaque; skin is a hole in it, shaded semi-transparently."""
    c = RACES[race]
    image = canvas()
    p = Paint(image, SEED + 100 + sum(ord(ch) for ch in race))
    undead = c["undead"]

    # Head: shading, then the face.
    for face in SIDES:
        p.speckle(HEAD[face], SKIN_D, SKIN_L, 0.08)
        p.edges(HEAD[face], SKIN_D)
    p.fill(HEAD["bottom"], SKIN_D)
    f = HEAD["front"]
    p.row(f, 2, SKIN_D, 1, 6)
    if undead:
        for ex in (1, 5):
            p.box(f[0] + ex, f[1] + 3, 2, 2, SOCKET)
    else:
        for ex in (1, 5):
            p.box(f[0] + ex, f[1] + 3, 2, 2, EYE_WHITE + (255,))
    p.box(f[0] + 3, f[1] + 4, 2, 2, SKIN_D)
    p.row(f, 6, SKIN_D, 2, 4)

    # Torso: the dress, with the collar (and a bare chest) left to the skin.
    for face in SIDES:
        p.fill(TORSO[face], c["cloth"])
        p.speckle(TORSO[face], c["cloth_d"], c["cloth_l"], 0.10)
        p.edges(TORSO[face], c["cloth_d"])
    p.fill(TORSO["top"], c["cloth_l"])
    p.fill(TORSO["bottom"], c["trouser_d"])
    p.row(TORSO["front"], 0, SKIN_D, 2, 4)
    for face in SIDES:
        p.row(TORSO[face], 8, c["trouser_d"])
        p.row(TORSO[face], 9, c["trouser_d"])
    p.box(TORSO["front"][0] + 3, TORSO["front"][1] + 8, 2, 2, c["accent"])
    if c["bare_chest"]:
        for face in ("front", "back"):
            chest = (TORSO[face][0] + 1, TORSO[face][1] + 1, 6, 7)
            p.box(*chest, col=(0, 0, 0, 0))
            p.speckle(chest, SKIN_D, SKIN_L, 0.10)
        p.box(TORSO["front"][0] + 2, TORSO["front"][1] + 1, 1, 7, c["cloth_d"])
        p.box(TORSO["front"][0] + 5, TORSO["front"][1] + 1, 1, 7, c["cloth_d"])
        p.box(TORSO["back"][0] + 3, TORSO["back"][1] + 1, 2, 7, c["cloth_d"])
    if undead:
        # Ribs: the skin showing, darker, through a torn wrap.
        for r in (2, 4, 6):
            p.row(TORSO["front"], r, SKIN_D, 1, 6)
            p.row(TORSO["back"], r, c["cloth_d"], 1, 6)

    # Arms: sleeves (or armbands on a bare arm), the hand is skin.
    bare = c["bare_chest"]
    for face in SIDES:
        region = ARM[face]
        if bare:
            p.speckle(region, SKIN_D, SKIN_L, 0.08)
            p.box(region[0], region[1] + 2, region[2], 2, c["accent"])
        else:
            p.box(region[0], region[1], region[2], 6, c["cloth"])
            p.speckle((region[0], region[1], region[2], 6),
                      c["cloth_d"], c["cloth_l"], 0.10)
            p.box(region[0], region[1] + 6, region[2], 1, SKIN_D)
        p.box(region[0], region[1] + 10, region[2], 2, SKIN_D)
        if bare:
            p.edges(region, SKIN_D)
        else:
            p.edges((region[0], region[1], region[2], 6), c["cloth_d"])
    if not bare:
        p.fill(ARM["top"], c["cloth_l"])
    p.fill(ARM["bottom"], SKIN_D)

    # Legs: trousers and boots, fully dressed.
    for face in SIDES:
        region = LEG[face]
        p.fill(region, c["trouser"])
        p.speckle(region, c["trouser_d"], c["cloth_l"], 0.08)
        p.box(region[0], region[1] + 8, region[2], 4, c["boot"])
        p.box(region[0], region[1] + 8, region[2], 1, c["boot_d"])
        p.edges(region, c["trouser_d"])
    p.fill(LEG["top"], c["trouser_d"])
    p.fill(LEG["bottom"], c["boot_d"])
    return image


# --- eyes: the iris (undead: the glow), coloured in the engine -----------
def layer_eyes(undead):
    image = canvas()
    p = Paint(image, 0)
    f = HEAD["front"]
    white = (255, 255, 255, 255)
    if undead:
        p.box(f[0] + 1, f[1] + 3, 2, 1, white)
        p.box(f[0] + 5, f[1] + 3, 2, 1, white)
    else:
        p.box(f[0] + 2, f[1] + 3, 1, 2, white)
        p.box(f[0] + 5, f[1] + 3, 1, 2, white)
    return image


# --- the helmet face window (a [mask: white keeps, transparent cuts) ------
def layer_helmet_window():
    image = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    p = Paint(image, 0)
    x0, y0, w, h = FACE_WINDOW
    p.box(HAT["front"][0] + x0, HAT["front"][1] + y0, w, h, (0, 0, 0, 0))
    return image


# --- hairstyles ------------------------------------------------------------
T, FR, BK = HAT["top"], HAT["front"], HAT["back"]


def hair_human_crop(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 4)
    l.box(BK, 0, 0, 8, 4)
    l.box(FR, 0, 0, 8, 3)
    l.dot(FR, 0, 2, 8, 1, HAIR_D)


def hair_human_swept(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 5)
    l.box(BK, 0, 0, 8, 6)
    l.box(FR, 0, 0, 8, 1)
    l.box(FR, 0, 1, 6, 1)
    l.box(FR, 0, 2, 3, 1)
    l.dot(FR, 3, 1, 3, 1, HAIR_D)
    l.dot(FR, 0, 2, 3, 1, HAIR_D)


def hair_human_long(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 8)
    l.box(BK, 0, 0, 8, 8)
    l.box(FR, 0, 0, 8, 2)
    l.box(FR, 0, 2, 1, 5)
    l.box(FR, 7, 2, 1, 5)
    l.dot(FR, 0, 1, 8, 1, HAIR_D)
    for cx in (2, 5):
        l.dot(BK, cx, 1, 1, 7, HAIR_D)


def hair_human_tail(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 3)
    l.box(BK, 0, 0, 8, 3)
    l.box(BK, 3, 3, 2, 5)
    l.box(FR, 0, 0, 8, 2)
    l.dot(BK, 3, 3, 2, 1, HAIR_TIE)
    l.dot(FR, 0, 1, 8, 1, HAIR_D)


def hair_dwarf_full(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 4)
    both_sides(l, 0, 4, 4, 4)
    l.box(BK, 0, 0, 8, 8)
    l.box(FR, 0, 0, 8, 2)
    l.dot(FR, 0, 1, 8, 1, HAIR_D)


def hair_dwarf_crown(l):
    # Bald on top: a horseshoe of hair round the back and the sides.
    l.box(T, 0, 0, 8, 3)
    l.box(T, 0, 3, 1, 5)
    l.box(T, 7, 3, 1, 5)
    both_sides(l, 0, 1, 6, 5)
    l.box(BK, 0, 0, 8, 7)
    l.dot(BK, 0, 6, 8, 1, HAIR_D)


def hair_dwarf_braid(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 5)
    l.box(BK, 0, 0, 8, 8)
    l.box(FR, 0, 0, 8, 2)
    l.stripes(BK, 3, 0, 2, 8)
    l.dot(BK, 3, 7, 2, 1, BEAD)
    l.dot(FR, 0, 1, 8, 1, HAIR_D)


def hair_elf_long(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 8)
    l.box(BK, 0, 0, 8, 8)
    l.box(FR, 0, 0, 8, 3)
    l.dot(FR, 0, 2, 8, 1, HAIR_D)


def hair_elf_tail(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 3)
    l.box(BK, 0, 0, 8, 3)
    l.box(BK, 2, 3, 4, 1)
    l.box(BK, 3, 4, 2, 4)
    l.box(FR, 0, 0, 8, 2)
    l.dot(BK, 2, 3, 4, 1, HAIR_TIE)


def hair_elf_braid(l):
    # A braid round the crown and one long braid down the back.
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 4)
    l.box(BK, 0, 0, 8, 4)
    l.box(BK, 3, 4, 2, 4)
    l.box(FR, 0, 0, 8, 1)
    l.box(FR, 0, 1, 2, 1)
    l.box(FR, 6, 1, 2, 1)
    both_sides_dot(l, 0, 2, 8, 1, HAIR_D)
    l.dot(BK, 0, 2, 8, 1, HAIR_D)
    l.stripes(BK, 3, 4, 2, 4, phase=1)


def hair_elf_short(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 3)
    l.box(BK, 0, 0, 8, 5)
    l.box(FR, 0, 0, 8, 1)
    l.box(FR, 2, 1, 6, 1)
    l.dot(FR, 2, 1, 6, 1, HAIR_D)


def hair_orc_topknot(l):
    # A strip over the crown, a knot at the back of the head, a short tail.
    l.box(T, 3, 0, 2, 8)
    l.box(BK, 2, 0, 4, 2)
    l.box(BK, 3, 2, 2, 5)
    l.dot(BK, 3, 2, 2, 1, HAIR_TIE)


def hair_orc_mohawk(l):
    # A broad ridge from the brow down to the neck.
    l.box(T, 2, 0, 4, 8)
    l.box(FR, 2, 0, 4, 2)
    l.box(BK, 2, 0, 4, 8)
    l.dot(FR, 2, 1, 4, 1, HAIR_D)
    for x0 in (2, 5):
        l.dot(T, x0, 0, 1, 8, HAIR_D)
        l.dot(BK, x0, 0, 1, 8, HAIR_D)


def hair_orc_shaved(l):
    # Stubble on the HEAD layer itself: a thin, semi-transparent hair colour
    # over the opaque scalp, nothing on the hat layer.
    l.box(HEAD["top"], 0, 0, 8, 8, alpha=110)
    for face in ("right", "left", "back"):
        l.box(HEAD[face], 0, 0, 8, 2, alpha=110)
    l.box(HEAD["front"], 0, 0, 8, 1, alpha=110)


def hair_orc_braids(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 2)
    l.box(BK, 0, 0, 8, 3)
    l.box(BK, 1, 3, 1, 5)
    l.box(BK, 6, 3, 1, 5)
    l.box(FR, 0, 0, 8, 1)
    l.stripes(BK, 1, 3, 1, 5)
    l.stripes(BK, 6, 3, 1, 5)


def hair_troll_mane(l):
    l.box(T, 0, 0, 8, 8)
    l.box(BK, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 3)
    l.box(FR, 0, 0, 8, 1)
    l.dot(FR, 0, 0, 8, 1, HAIR_D)


def hair_troll_crest(l):
    l.box(T, 2, 0, 4, 8)
    l.box(FR, 2, 0, 4, 2)
    l.box(BK, 2, 0, 4, 8)
    l.dot(FR, 2, 1, 4, 1, HAIR_D)
    l.dot(BK, 2, 0, 1, 8, HAIR_D)
    l.dot(BK, 5, 0, 1, 8, HAIR_D)


def hair_troll_swept(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 4)
    both_sides(l, 0, 4, 4, 4)
    l.box(BK, 0, 0, 8, 8)
    l.box(FR, 0, 0, 8, 1)
    for cy in (2, 5):
        both_sides_dot(l, 0, cy, 4, 1, HAIR_D)


def hair_troll_twintails(l):
    l.box(T, 0, 0, 8, 8)
    both_sides(l, 0, 0, 8, 3)
    l.box(BK, 0, 0, 8, 3)
    l.box(BK, 0, 3, 2, 5)
    l.box(BK, 6, 3, 2, 5)
    l.box(FR, 0, 0, 8, 1)
    l.dot(BK, 0, 3, 2, 1, HAIR_TIE)
    l.dot(BK, 6, 3, 2, 1, HAIR_TIE)


def hair_undead_patchy(l):
    for cx in (0, 2, 5, 7):
        l.box(T, cx, 0, 1, 8)
    l.box(BK, 1, 0, 1, 4)
    l.box(BK, 5, 0, 1, 5)
    l.dot(BK, 5, 0, 1, 5, HAIR_D)


def hair_undead_stringy(l):
    for cx in (0, 1, 3, 4, 6, 7):
        l.box(T, cx, 0, 1, 8)
    for cx, h in ((0, 8), (1, 6), (3, 7), (5, 8)):
        both_sides(l, cx, 0, 1, h)
    for cx, h in ((0, 7), (2, 8), (3, 5), (5, 8), (7, 6)):
        l.box(BK, cx, 0, 1, h)
    l.box(FR, 0, 0, 1, 5)
    l.box(FR, 7, 0, 1, 4)


def hair_undead_bald(l):
    l.box(T, 2, 0, 1, 4)
    l.box(T, 5, 1, 1, 4)
    l.box(BK, 3, 0, 1, 3)


HAIRSTYLES = {
    "human": {"crop": hair_human_crop, "swept": hair_human_swept,
              "long": hair_human_long, "tail": hair_human_tail},
    "dwarf": {"full": hair_dwarf_full, "crown": hair_dwarf_crown,
              "braid": hair_dwarf_braid},
    "elf": {"long": hair_elf_long, "tail": hair_elf_tail,
            "braid": hair_elf_braid, "short": hair_elf_short},
    "orc": {"topknot": hair_orc_topknot, "mohawk": hair_orc_mohawk,
            "shaved": hair_orc_shaved, "braids": hair_orc_braids},
    "troll": {"mane": hair_troll_mane, "crest": hair_troll_crest,
              "swept": hair_troll_swept, "twintails": hair_troll_twintails},
    "undead": {"patchy": hair_undead_patchy, "stringy": hair_undead_stringy,
               "bald": hair_undead_bald},
}


# --- lower-face features -----------------------------------------------------
# `tinted` features paint a mask (hair colour or skin tone, per looks.lua);
# the others paint fixed colours into the detail only.
def feat_human_stubble(l):
    l.box(HEAD["front"], 1, 5, 6, 3, alpha=64)
    l.box(HEAD["right"], 6, 5, 2, 3, alpha=64)
    l.box(HEAD["left"], 0, 5, 2, 3, alpha=64)


def feat_human_beard(l):
    l.box(FR, 0, 6, 8, 2)
    l.box(FR, 0, 5, 2, 1)
    l.box(FR, 6, 5, 2, 1)
    both_sides(l, 5, 5, 3, 3)
    l.dot(FR, 3, 6, 2, 1, INK)


def feat_human_moustache(l):
    l.box(FR, 2, 5, 4, 1)
    l.box(FR, 1, 6, 1, 1)
    l.box(FR, 6, 6, 1, 1)
    l.dot(FR, 2, 5, 4, 1, HAIR_D)


def beard_face(l):
    """The dwarf beard's face part, shared by all four beards."""
    l.box(FR, 0, 5, 8, 3)
    both_sides(l, 4, 4, 4, 4)
    l.dot(FR, 3, 5, 2, 1, INK)


def feat_dwarf_full(l):
    beard_face(l)
    l.box(TORSO["front"], 1, 0, 6, 3)
    l.box(TORSO["front"], 2, 3, 4, 1)


def feat_dwarf_braided(l):
    beard_face(l)
    l.box(TORSO["front"], 1, 0, 6, 1)
    l.box(TORSO["front"], 1, 1, 2, 4)
    l.box(TORSO["front"], 5, 1, 2, 4)
    l.stripes(TORSO["front"], 1, 1, 2, 4, phase=1)
    l.stripes(TORSO["front"], 5, 1, 2, 4, phase=1)
    l.dot(TORSO["front"], 1, 4, 2, 1, BEAD)
    l.dot(TORSO["front"], 5, 4, 2, 1, BEAD)


def feat_dwarf_forked(l):
    beard_face(l)
    l.box(TORSO["front"], 1, 0, 6, 2)
    l.box(TORSO["front"], 1, 2, 2, 1)
    l.box(TORSO["front"], 5, 2, 2, 1)
    l.box(TORSO["front"], 1, 3, 1, 1)
    l.box(TORSO["front"], 6, 3, 1, 1)
    l.dot(TORSO["front"], 3, 1, 2, 1, HAIR_D)


def feat_dwarf_short(l):
    l.box(FR, 0, 5, 8, 3)
    both_sides(l, 5, 5, 3, 3)
    l.dot(FR, 3, 5, 2, 1, INK)


def ears(l, swept):
    if swept:
        spans = ((6, 4, 1), (4, 3, 3), (2, 2, 3), (2, 1, 1))
    else:
        spans = ((6, 4, 1), (4, 3, 3), (4, 2, 1))
    for x0, y0, w in spans:
        both_sides(l, x0, y0, w, 1)
    both_sides_dot(l, 5, 3, 1, 1, INK)


def feat_elf_pointed(l):
    ears(l, False)


def feat_elf_swept(l):
    ears(l, True)


def feat_elf_marked(l):
    ears(l, False)
    f = HEAD["front"]
    for x0 in (1, 6):
        l.dot(f, x0, 5, 1, 2, ELF_MARK)
    l.dot(f, 3, 7, 2, 1, ELF_MARK)


def tusk(l, x0, y0, h):
    """One tusk on the hat front, tip on top, a darker root row."""
    l.dot(FR, x0, y0, 1, h, TUSK + (255,))
    l.dot(FR, x0, y0 + h - 1, 1, 1, BONE_D)


def feat_orc_tusks_small(l):
    tusk(l, 1, 5, 2)
    tusk(l, 6, 5, 2)


def feat_orc_tusks_large(l):
    for x0 in (1, 6):
        tusk(l, x0, 5, 3)
    both_cheeks(l, 2, 6, 1, 2, TUSK + (255,))
    both_cheeks(l, 2, 7, 1, 1, BONE_D)


def feat_orc_tusks_broken(l):
    tusk(l, 1, 5, 3)
    l.dot(FR, 2, 6, 1, 2, TUSK + (255,))
    l.dot(FR, 2, 7, 1, 1, BONE_D)
    tusk(l, 6, 6, 2)
    l.dot(FR, 6, 6, 1, 1, BONE_D)


def feat_orc_warpaint(l):
    feat_orc_tusks_small(l)
    f = HEAD["front"]
    l.dot(f, 0, 2, 8, 1, WARPAINT)
    l.dot(f, 2, 5, 1, 1, WARPAINT)
    l.dot(f, 5, 5, 1, 1, WARPAINT)
    l.dot(f, 3, 7, 2, 1, WARPAINT)


def feat_troll_tusks_small(l):
    tusk(l, 1, 6, 2)
    tusk(l, 6, 6, 2)


def feat_troll_tusks_large(l):
    both_cheeks(l, 1, 6, 1, 2, TUSK + (255,))
    both_cheeks(l, 1, 7, 1, 1, BONE_D)
    both_cheeks(l, 0, 4, 1, 2, TUSK + (255,))


def feat_troll_tusks_huge(l):
    feat_troll_tusks_large(l)
    both_cheeks(l, 2, 7, 1, 1, BONE_D)
    both_sides_dot(l, 7, 3, 1, 2, TUSK + (255,))
    both_sides_dot(l, 6, 2, 1, 1, TUSK + (255,))


def feat_undead_jaw(l):
    f = HEAD["front"]
    l.dot(f, 1, 5, 6, 3, BONE)
    for x0 in (1, 3, 5):
        l.dot(f, x0, 6, 1, 1, GAP)
    l.dot(f, 1, 7, 1, 1, GAP)
    l.dot(f, 6, 7, 1, 1, GAP)
    l.dot(f, 2, 5, 4, 1, BONE_D)


def feat_undead_stitches(l):
    f = HEAD["front"]
    l.dot(f, 1, 6, 6, 1, GAP)
    for x0 in (2, 4):
        l.dot(f, x0, 5, 1, 1, GAP)
        l.dot(f, x0, 7, 1, 1, GAP)
    l.dot(f, 6, 5, 1, 1, GAP)


def feat_undead_nose(l):
    f = HEAD["front"]
    l.dot(f, 3, 4, 2, 1, GAP)
    l.dot(f, 3, 5, 2, 1, (70, 50, 56, 255))


FEATURES = {
    "human": {"stubble": feat_human_stubble, "beard": feat_human_beard,
              "moustache": feat_human_moustache},
    "dwarf": {"full": feat_dwarf_full, "braided": feat_dwarf_braided,
              "forked": feat_dwarf_forked, "short": feat_dwarf_short},
    "elf": {"pointed": feat_elf_pointed, "swept": feat_elf_swept,
            "marked": feat_elf_marked},
    "orc": {"tusks_small": feat_orc_tusks_small,
            "tusks_large": feat_orc_tusks_large,
            "tusks_broken": feat_orc_tusks_broken,
            "warpaint": feat_orc_warpaint},
    "troll": {"tusks_small": feat_troll_tusks_small,
              "tusks_large": feat_troll_tusks_large,
              "tusks_huge": feat_troll_tusks_huge},
    "undead": {"jaw": feat_undead_jaw, "stitches": feat_undead_stitches,
               "nose": feat_undead_nose},
}


# --- royal attire: a tabard in the race's colours and a king's crown -------
# The tabard is two masks (cloth panel, trim band) the engine colours with the
# race's royal colours (looks.lua ROYAL) plus a detail layer (the darker hem,
# a gold emblem). The crown is fixed colour, on the hat layer, above the eyes.
GOLD = (232, 184, 58, 255)
GOLD_D = (150, 104, 28, 255)
GEM = (116, 220, 238, 255)


def layer_tabard():
    l = Layer(0)
    trim = canvas()
    t = trim.load()
    for face in ("front", "back"):
        l.box(TORSO[face], 2, 0, 4, 12)
        l.dot(TORSO[face], 2, 9, 4, 3, (0, 0, 0, 64))
    for face in SIDES:
        x, y = TORSO[face][0], TORSO[face][1]
        for i in range(TORSO[face][2]):
            t[x + i, y + 7] = (255, 255, 255, 255)
    for dx, dy in ((3, 3), (4, 4), (5, 3)):
        l.dot(TORSO["front"], dx, dy, 1, 1, GOLD)
    return l.mask, trim, l.detail


def layer_crown():
    image = canvas()
    p = Paint(image, 0)
    for face in SIDES:
        x, y = HAT[face][0], HAT[face][1]
        p.box(x, y + 1, 8, 1, GOLD)
        p.box(x, y + 2, 8, 1, GOLD_D)
        for dx in (0, 3, 4, 7):
            p.box(x + dx, y, 1, 1, GOLD)
    x, y = HAT["top"][0], HAT["top"][1]
    for i in range(8):
        for j in (0, 7):
            p.box(x + i, y + j, 1, 1, GOLD_D)
            p.box(x + j, y + i, 1, 1, GOLD_D)
    p.box(HAT["front"][0] + 3, HAT["front"][1] + 1, 2, 1, GEM)
    return image


def has_pixels(image):
    return image.getbbox() is not None


def build_layers():
    """name -> image for every look layer. A feature without a mask (fixed
    colour) writes no mask file; looks.lua knows which by its `tint`."""
    out = {"grug_visuals_skin_mask.png": layer_skin_mask(),
           "grug_visuals_eyes_mask.png": layer_eyes(False),
           "grug_visuals_eyes_undead_mask.png": layer_eyes(True),
           "grug_visuals_helmet_window.png": layer_helmet_window(),
           "grug_visuals_crown.png": layer_crown()}
    (out["grug_visuals_tabard_mask.png"], out["grug_visuals_tabard_trim_mask.png"],
     out["grug_visuals_tabard.png"]) = layer_tabard()
    for race in sorted(RACES):
        out["grug_visuals_%s_body.png" % race] = layer_body(race)
        salt = sum(ord(ch) for ch in race)
        for kind, table in (("hair", HAIRSTYLES), ("feature", FEATURES)):
            for ident in sorted(table[race]):
                stem = "grug_visuals_%s_%s_%s" % (race, kind, ident)
                l = Layer(SEED + 200 + salt + sum(ord(ch) for ch in stem))
                table[race][ident](l)
                if kind == "hair":
                    l.shade()
                elif has_pixels(l.mask):
                    l.shade(rate=0.08)
                if has_pixels(l.mask):
                    out[stem + "_mask.png"] = l.mask
                out[stem + ".png"] = l.detail
    return out


def check_layer_alpha(layers):
    """Every combination a look can make, drawn with white for every colour:
    the result must be fully opaque or fully transparent at every pixel (see
    the section comment), and the eyes and every head-front pixel of a
    feature must lie inside the helmet face window."""
    problems = []
    base = Image.alpha_composite(layers["grug_visuals_skin_mask.png"],
                                 Image.new("RGBA", (W, H), (0, 0, 0, 0)))
    fx, fy, fw, fh = FACE_WINDOW
    hx, hy = HEAD["front"][0], HEAD["front"][1]
    window = set((hx + fx + i, hy + fy + j)
                 for i in range(fw) for j in range(fh))
    head_front = set((hx + i, hy + j) for i in range(8) for j in range(8))
    for race in sorted(RACES):
        body = Image.alpha_composite(base, layers["grug_visuals_%s_body.png"
                                                  % race])
        eyes = "grug_visuals_eyes_undead_mask.png" if race == "undead" \
            else "grug_visuals_eyes_mask.png"
        body = Image.alpha_composite(body, layers[eyes])

        def stack(img, stem):
            if stem + "_mask.png" in layers:
                img = Image.alpha_composite(img, layers[stem + "_mask.png"])
            return Image.alpha_composite(img, layers[stem + ".png"])

        for style in sorted(HAIRSTYLES[race]):
            for feature in sorted(FEATURES[race]):
                img = stack(body, "grug_visuals_%s_hair_%s" % (race, style))
                img = stack(img, "grug_visuals_%s_feature_%s"
                            % (race, feature))
                px = img.load()
                bad = [(i, j) for j in range(H) for i in range(W)
                       if 0 < px[i, j][3] < 255]
                if bad:
                    problems.append("%s %s+%s: %d half-transparent pixels, "
                                    "first %s" % (race, style, feature,
                                                  len(bad), bad[0]))
        for feature in sorted(FEATURES[race]):
            stem = "grug_visuals_%s_feature_%s" % (race, feature)
            for name in (stem + ".png", stem + "_mask.png"):
                if name not in layers:
                    continue
                px = layers[name].load()
                outside = [p for p in head_front
                           if px[p][3] > 0 and p not in window]
                # War paint deliberately crosses the brow; under a helmet
                # that part is hidden, as a helmet hides a brow.
                if outside and not feature == "warpaint":
                    problems.append("%s: head-front pixels outside the face "
                                    "window %s" % (name, sorted(outside)[:3]))
    for eyes in ("grug_visuals_eyes_mask.png",
                 "grug_visuals_eyes_undead_mask.png"):
        px = layers[eyes].load()
        if any(px[p][3] > 0 and p not in window for p in head_front):
            problems.append("%s: an eye outside the face window" % eyes)
    return problems


# What each overlay is REQUIRED to cover, per face, as
# (box group, faces, rule, value). Rules:
#   "full"    every pixel of the face is opaque,
#   "min"     at least `value` opaque pixels,
#   "open"    between 1 and full-1 -- the face is partly covered ON PURPOSE.
#
# Asserted by the generator on every run, because "the back of the chestpiece
# is missing" is a claim a flat front render can neither prove nor disprove,
# and one measurement settles it for good. The "open" rules are just as
# load-bearing as the "full" ones: a helmet that covers the whole face is as
# wrong as a chestplate with no back.
REQUIRED_COVER = {
    "chest": [
        (TORSO, ("top", "bottom", "right", "front", "left", "back"), "full", 0),
        (ARM, ("top",), "full", 0),
        (ARM, ("right", "front", "left", "back"), "min", 16),
    ],
    "legs": [
        (LEG, ("top",), "full", 0),
        (LEG, ("right", "front", "left", "back"), "min", 32),
    ],
    "feet": [
        (LEG, ("bottom",), "full", 0),
        (LEG, ("right", "front", "left", "back"), "min", 12),
    ],
    "head": [
        (HAT, ("top", "back"), "full", 0),
        # The cowl ends above the jaw, so its side faces are deliberately short.
        (HAT, ("right", "left"), "min", 48),
        # The face stays visible: a brow band, never a closed helmet.
        (HAT, ("front",), "open", 0),
    ],
}


def check_coverage(overlays):
    """Returns a list of complaint strings; empty means every overlay covers
    exactly the faces its slot promises, and leaves open the ones it must."""
    problems = []
    for (line, slot), image in sorted(overlays.items()):
        px = image.load()
        for group, faces, rule, value in REQUIRED_COVER[slot]:
            for face in faces:
                x, y, w, h = group[face]
                total = w * h
                opaque = sum(1 for j in range(y, y + h)
                             for i in range(x, x + w) if px[i, j][3] > 0)
                bad = None
                if rule == "full" and opaque != total:
                    bad = "must be fully covered"
                elif rule == "min" and opaque < value:
                    bad = "must cover at least %d" % value
                elif rule == "open" and not (0 < opaque < total):
                    bad = "must be partly open"
                if bad:
                    problems.append("%s_%s %s: %s (%d/%d opaque)"
                                    % (line, slot, face, bad, opaque, total))
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--textures", type=Path,
                        default=Path("mods/PLAYER/grug_visuals/textures"))
    args = parser.parse_args()
    args.textures.mkdir(parents=True, exist_ok=True)

    written = []
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

    layers = build_layers()
    for name in sorted(layers):
        path = args.textures / name
        layers[name].save(path, optimize=True)
        print(path)

    problems = check_coverage(overlays)
    for problem in problems:
        print("COVERAGE: " + problem)
    layer_problems = check_layer_alpha(layers)
    for problem in layer_problems:
        print("LAYERS: " + problem)
    problems = problems + layer_problems

    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
