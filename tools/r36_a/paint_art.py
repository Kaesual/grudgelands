#!/usr/bin/env python3
"""Paint Round 36's 21 original textures; Python 3 + Pillow, no downloads.

GPT-6 Astra, 2026-10-05. AI-assisted original pixel art, CC0-1.0.
Run from any directory: python3 tools/r36_a/paint_art.py
Writes only the named textures and uncommitted astra_out/ previews/checks.
All marks are drawn at native resolution with integer pixel coordinates.
The existing skins are read for contact-sheet comparisons only; their pixels
are never used in a shipped texture. The Dungeon Master mesh's UV islands
are retained at exactly 2x scale, including its overlapping body/limb islands.
"""

from pathlib import Path
import hashlib
import json
import math

from PIL import Image, ImageColor, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "astra_out"
CLOAKS = ROOT / "mods/PLAYER/grug_achievements/textures"
MOBS = ROOT / "mods/ENTITIES/grug_mobs/textures"
QUESTS = ROOT / "mods/PLAYER/grug_quests/textures"
ASSETS = []

# Material colours: the Undertithe's four anchors recur across the evidence.
INK = "#17171D"
COAL = "#20191B"
SOOT = "#383036"
RUST = "#813526"
EMBER = "#E56C32"
FIRE = "#FFE3A3"
IRON = "#515760"
STEEL = "#899595"
SILVER = "#C8D6D3"
STONE = "#737777"
STONE_D = "#474B53"
STONE_L = "#ADB7AC"
PAPER = "#D7C59C"
PAPER_L = "#EADDB9"
GOLD = "#B99451"
WOOD_D = "#49342E"
WOOD = "#76503A"
WOOD_L = "#AB8054"


def rgba(colour):
    return ImageColor.getcolor(colour, "RGBA")


def canvas(size=(32, 32), colour=(0, 0, 0, 0)):
    return Image.new("RGBA", size, colour)


def save(im, folder, filename, kind):
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / filename
    im.save(path, optimize=False)
    ASSETS.append((path, kind))


def brand(d, x, y, colour=EMBER, scale=1):
    """The same 11x12 stamp everywhere: open-bottom circle, two inward hooks.

    Top at y=0, circle sides at x=0/10. Each lower end curls inward and
    upward into the gap; the middle column remains open through the base.
    """
    rows = (
        "...#####...", "..#.....#..", ".#.......#.", "#.........#",
        "#.........#", "#.........#", "#.........#", ".#.......#.",
        "..#.....#..", "..#.#.#.#..", "..###.###..", "...........",
    )
    for yy, row in enumerate(rows):
        for xx, ch in enumerate(row):
            if ch == "#":
                d.rectangle((x + xx * scale, y + yy * scale,
                             x + (xx + 1) * scale - 1,
                             y + (yy + 1) * scale - 1), fill=colour)


def small_brand(d, x, y, colour=COAL):
    """Seven-pixel coin stamp; paired curls are retained at the small scale."""
    for yy, row in enumerate(("..###..", ".#...#.", "#.....#", "#.....#",
                              ".##.##.", "..#.#..")):
        for xx, ch in enumerate(row):
            if ch == "#":
                d.point((x + xx, y + yy), fill=colour)


def coin(d, x, y, hot=False):
    d.rectangle((x, y + 1, x + 3, y + 2), fill=RUST if hot else WOOD_D)
    d.line((x + 1, y, x + 2, y), fill=EMBER if hot else PAPER)
    d.line((x, y + 1, x + 2, y + 1), fill=GOLD)


def cloaks():
    specs = (
        ("unburnt_roll", "#20374F", "#B69B5C", "#162637"),
        ("unbought_banner", "#522A31", "#CB9141", "#351C23"),
        ("broken_due", "#211E28", "#8B3D32", "#15131B"),
    )
    for name, base, edge, lining in specs:
        im = canvas(colour=lining)
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 15, 31), fill=base, outline=edge)
        if name == "unburnt_roll":
            # An arch shelters three separate strokes; damage stays at the hem.
            d.line([(2, 23), (2, 10), (3, 8), (5, 6), (10, 6),
                    (12, 8), (13, 10), (13, 23)], fill=edge, width=2)
            for x in (4, 7, 10):
                d.rectangle((x, 12, x + 1, 21), fill="#C8D6D3")
            d.polygon([(1, 30), (1, 26), (3, 28), (4, 25), (6, 28),
                       (8, 27), (10, 29), (12, 26), (14, 27), (14, 30)],
                      fill="#40332D")
            d.line((5, 24, 10, 24), fill=edge)
        elif name == "unbought_banner":
            for x in (3, 7, 11):
                d.rectangle((x, 6, x + 1, 17), fill=edge)
            d.rectangle((2, 10, 13, 11), fill="#D7C59C")
            d.point((2, 12), fill="#D7C59C")
            d.point((13, 9), fill="#D7C59C")
            d.ellipse((3, 20, 12, 28), outline="#262329", width=2)
            d.polygon([(9, 19), (11, 20), (5, 30), (3, 29)], fill=base)
            d.point((10, 22), fill="#D7C59C")
            d.point((5, 27), fill="#D7C59C")
        else:
            d.ellipse((2, 6, 13, 21), outline=edge, width=3)
            d.ellipse((3, 7, 12, 20), outline="#EB8847", width=2)
            # Clear space around the pale slash visibly severs the ring.
            d.polygon([(1, 18), (13, 11), (14, 15), (2, 22)], fill=base)
            d.line((2, 20, 13, 13), fill="#F1DCAC", width=2)
            d.line([(3, 24), (3, 28), (6, 28), (6, 26)], fill="#EB8847")
            d.line([(12, 25), (12, 29), (9, 29), (9, 27)], fill="#EB8847")
        # Reassert the exact full-length seam after painting near the edges.
        d.rectangle((0, 0, 15, 31), outline=edge)
        save(im, CLOAKS, f"grug_achievements_cloak_{name}.png", "cloak")


def commanders():
    # character.b3d UV, confirmed against tools/wp13/gen_character_visuals.py:
    # torso front (20,20)..(27,31), back (32,20)..(39,31), top (20,16)..(27,19).
    # Arm top (44,16)..(47,19); only first three rows of arm sides are shoulders.
    for faction, base, shoulder, pale, dark in (
        ("accord", "#253D58", "#C9D4CF", "#B99451", "#272C33"),
        ("throng", "#58262D", "#CF9844", "#C8B78D", "#29242A"),
    ):
        im = canvas((64, 32))
        d = ImageDraw.Draw(im)
        d.rectangle((20, 16, 27, 19), fill=base)
        for x in (20, 32):
            d.rectangle((x, 20, x + 7, 31), fill=base)
            d.line((x, 20, x, 31), fill=dark)
            d.line((x + 7, 20, x + 7, 31), fill=dark)
            d.line((x + 1, 31, x + 6, 31), fill=pale)
            if faction == "accord":
                # A closed gate (filled pale metal), crossed by one upright.
                d.rectangle((x + 2, 23, x + 5, 28), fill=shoulder)
                d.line((x + 1, 23, x + 6, 23), fill=pale)
                d.line((x + 3, 21, x + 3, 29), fill=pale)
                d.line((x + 1, 30, x + 6, 30), fill=shoulder)
            else:
                # Two rock halves, a jagged central split, exactly three cords.
                d.polygon([(x + 2, 22), (x + 3, 22), (x + 3, 24),
                           (x + 2, 26), (x + 3, 28), (x + 1, 28)], fill=pale)
                d.polygon([(x + 5, 22), (x + 6, 23), (x + 6, 28),
                           (x + 5, 29), (x + 4, 27), (x + 4, 25)], fill=pale)
                d.line([(x + 4, 22), (x + 4, 24), (x + 3, 25),
                        (x + 3, 26), (x + 4, 27), (x + 4, 29)], fill=dark)
                for y in (23, 25, 27):
                    d.line((x + 1, y, x + 6, y), fill=shoulder)
        d.rectangle((44, 16, 47, 19), fill=shoulder)
        d.rectangle((40, 20, 55, 22), fill=shoulder)
        d.line((40, 22, 55, 22), fill=dark)
        for x in (41, 45, 49, 53):
            d.point((x, 20), fill=pale)
        save(im, MOBS, f"grug_mobs_commander_{faction}_overlay.png", "overlay")


def rift():
    # A periodic 15-pixel field repeats its first samples at row/column 15.
    # Both opposite edges match, and vein paths cross those edges continuously.
    im = canvas((16, 16), "#0E0B10")
    for y in range(16):
        for x in range(16):
            xx, yy = x % 15, y % 15
            wave = math.cos(xx * math.tau / 15) + math.sin(yy * math.tau / 15)
            im.putpixel((x, y), rgba("#161117" if wave > 0.8 else "#100D12"))
    d = ImageDraw.Draw(im)
    # Wrapped strokes are drawn in a tile with matching boundaries.
    paths = [[(0, 3), (2, 4), (2, 6), (4, 7)],
             [(15, 3), (13, 2), (12, 2)],
             [(7, 0), (8, 2), (8, 3), (10, 4)],
             [(7, 15), (6, 13), (6, 11), (4, 10), (4, 9)],
             [(6, 13), (9, 13), (10, 12)]]
    for path in paths:
        d.line(path, fill="#36201E")
    for point in ((2, 5), (8, 2), (6, 12), (8, 13)):
        d.point(point, fill="#5C2A22")
    d.point((2, 6), fill="#813526")
    save(im, MOBS, "grug_mobs_rift_void.png", "void")

    im = canvas((8, 8))
    d = ImageDraw.Draw(im)
    d.polygon([(3, 1), (5, 2), (6, 4), (4, 7), (1, 5), (1, 3)],
              fill=(32, 25, 27, 35))
    d.polygon([(3, 2), (5, 3), (5, 5), (3, 6), (2, 4)],
              fill=(32, 25, 27, 125))
    d.rectangle((3, 3, 4, 4), fill=(48, 31, 30, 205))
    d.point((4, 3), fill=(129, 53, 38, 195))
    d.point((4, 2), fill=(229, 108, 50, 85))
    save(im, MOBS, "grug_mobs_rift_particle.png", "particle")

    im = canvas((16, 16))
    d = ImageDraw.Draw(im)
    d.polygon([(3, 2), (8, 3), (8, 5), (12, 7), (14, 10), (13, 13),
               (10, 15), (7, 14), (5, 11), (1, 8), (5, 9)],
              fill=(129, 53, 38, 65))
    d.polygon([(2, 1), (7, 4), (7, 7), (11, 6), (13, 9), (13, 12),
               (10, 14), (7, 13), (5, 10), (3, 8), (6, 9)], fill=COAL)
    d.line([(6, 5), (8, 8), (11, 9), (12, 12), (10, 13), (8, 12)], fill=RUST)
    d.line([(7, 7), (9, 9), (9, 11), (11, 12)], fill=EMBER)
    d.point((10, 12), fill=FIRE)
    d.point((2, 4), fill=(129, 53, 38, 130))
    d.point((4, 6), fill=(229, 108, 50, 160))
    save(im, MOBS, "grug_mobs_rift_bolt.png", "bolt")


def isquarre():
    # UV rectangles below are in the original 31x39 atlas. Front head:
    # x=1.86..12.93,y=2.18..9.91; front/back torso x=16.17..30.91,y=1.70..17.88.
    # Arms lie sideways across x=0..25.5,y=17.24..26.98; legs x=19..30,y=19..29.
    # Torso sides/top share this same island: keep the emblem within its middle.
    im = canvas((62, 78), COAL)
    d = ImageDraw.Draw(im)
    # Deliberately authored broad slag facets, never sampled source colours.
    for box, shade in (((0, 0, 29, 35), "#292024"),
                       ((32, 3, 61, 35), "#2C2225"),
                       ((1, 35, 45, 53), "#261E23"),
                       ((38, 38, 60, 57), "#302428")):
        d.rectangle(box, fill=shade)
    for points, shade in (
        ([(4, 4), (14, 5), (12, 10), (5, 13)], "#42302C"),
        ([(16, 4), (24, 5), (25, 9), (17, 10)], "#34272A"),
        ([(5, 20), (14, 22), (9, 33), (3, 34)], "#35272A"),
        ([(19, 23), (24, 22), (26, 33), (17, 32)], "#171419"),
        ([(33, 5), (40, 4), (42, 10), (38, 14), (33, 13)], "#46312D"),
        ([(50, 5), (59, 6), (59, 15), (54, 13)], "#3A2A2C"),
        ([(34, 24), (40, 25), (43, 33), (33, 34)], "#161318"),
        ([(54, 25), (59, 22), (60, 33), (52, 34)], "#19151B"),
        ([(4, 37), (21, 38), (19, 42), (3, 42)], "#46312D"),
        ([(6, 46), (29, 47), (33, 51), (8, 50)], "#35272A"),
        ([(42, 40), (45, 42), (44, 49), (40, 48)], "#4B312B"),
        ([(50, 40), (52, 44), (51, 50), (47, 49)], "#48302B"),
        ([(56, 40), (58, 42), (57, 49), (54, 49)], "#3B2B2A"),
    ):
        d.polygon(points, fill=shade)
    # Glowering eyes and a broad furnace mouth within the original head island.
    d.line((7, 8, 11, 9), fill=INK, width=2)
    d.line((17, 9, 21, 8), fill=INK, width=2)
    d.rectangle((8, 10, 10, 11), fill=EMBER)
    d.rectangle((18, 10, 20, 11), fill=EMBER)
    d.point((9, 10), fill=FIRE)
    d.point((19, 10), fill=FIRE)
    d.polygon([(8, 14), (20, 14), (22, 17), (19, 19), (10, 19), (7, 17)], fill=RUST)
    d.rectangle((9, 15, 20, 17), fill=FIRE)
    d.line((11, 18, 18, 18), fill=EMBER)
    for x in (12, 17):
        d.point((x, 15), fill=COAL)
    # A circular scorched coin impression, open underneath like the brand.
    # The torso UV is much taller on the mesh than in the atlas. Compress
    # only the painted stamp so its coin looks round on the existing body.
    d.arc((34, 13, 59, 31), 135, 405, fill="#503027", width=3)
    stamp = canvas((11, 12))
    brand(ImageDraw.Draw(stamp), 0, 0, EMBER)
    stamp = stamp.resize((24, 17), Image.Resampling.NEAREST)
    im.alpha_composite(stamp, (35, 14))
    d.point((40, 15), fill=FIRE)
    d.point((39, 16), fill=FIRE)
    # Few hot fissures keep the body predominantly kiln-black.
    for path in ([(36, 8), (38, 9), (38, 12)],
                 [(57, 18), (59, 21), (58, 24)],
                 [(8, 38), (11, 39), (15, 38), (17, 39)],
                 [(24, 48), (28, 47), (31, 48)],
                 [(41, 42), (42, 44), (41, 46)],
                 [(55, 45), (56, 46), (55, 48)]):
        d.line(path, fill=RUST)
    for p in ((38, 10), (59, 21), (11, 39), (28, 47), (42, 44), (56, 46)):
        d.point(p, fill=EMBER)
    save(im, MOBS, "grug_mobs_isquarre.png", "boss")


def quest_objects():
    # Front-facing evidence props with a small visible top plane. No lettering.
    # The local helpers only share materials; every object has its own silhouette.
    def new():
        im = canvas()
        return im, ImageDraw.Draw(im)

    def finish(im, name):
        save(im, QUESTS, f"grug_quests_obj_{name}.png", "quest")

    im, d = new()
    # Iron tray with bevelled lip, a wrapped purse rising above it.
    d.polygon([(1, 25), (4, 22), (27, 22), (30, 25), (28, 31), (3, 31)], fill=INK)
    d.polygon([(2, 25), (5, 23), (26, 23), (29, 25), (27, 29), (4, 29)], fill=STEEL)
    d.polygon([(4, 25), (7, 24), (24, 24), (27, 25), (25, 28), (6, 28)], fill=IRON)
    d.line((4, 30, 27, 30), fill=IRON)
    d.polygon([(7, 26), (6, 19), (9, 14), (12, 12), (11, 8), (20, 8),
               (19, 13), (24, 18), (25, 26)], fill=INK)
    d.polygon([(8, 25), (8, 18), (12, 14), (13, 12), (18, 12),
               (22, 18), (23, 25)], fill=WOOD)
    d.polygon([(13, 9), (18, 9), (17, 13), (14, 13)], fill=WOOD_L)
    d.line((10, 18, 10, 23), fill=WOOD_L)
    d.polygon([(7, 17), (14, 16), (22, 19), (22, 25), (8, 24)], fill=PAPER)
    d.polygon([(8, 18), (13, 17), (16, 19), (9, 20)], fill=PAPER_L)
    d.line((15, 13, 15, 25), fill=GOLD)
    d.line((11, 13, 20, 13), fill=PAPER_L)
    d.ellipse((16, 20, 21, 25), fill=COAL)
    d.line((17, 21, 19, 21), fill=RUST)
    finish(im, "impounded_pay")

    im, d = new()
    d.polygon([(3, 16), (9, 12), (27, 14), (29, 18), (28, 29),
               (23, 31), (3, 28)], fill=INK)
    d.polygon([(4, 17), (10, 13), (26, 15), (27, 18), (22, 23)], fill=WOOD_L)
    d.polygon([(4, 19), (22, 24), (22, 30), (4, 27)], fill=WOOD)
    d.polygon([(23, 24), (28, 19), (27, 28), (23, 30)], fill=WOOD_D)
    d.line((6, 25, 20, 28), fill=WOOD_D)
    d.line((7, 17, 21, 20), fill=PAPER)
    d.line((6, 20, 20, 23), fill=GOLD)
    for x in (7, 23):
        d.line((x, 16, x - 1, 28), fill=IRON, width=2)
        d.point((x, 18), fill=STEEL)
    d.ellipse((12, 15, 21, 24), fill=COAL)
    d.ellipse((13, 16, 20, 23), outline=RUST)
    d.line([(14, 18), (18, 19), (16, 21), (19, 22)], fill=EMBER)
    finish(im, "false_requisition")

    im, d = new()
    d.polygon([(3, 30), (5, 9), (9, 4), (23, 5), (26, 9), (28, 30)], fill=INK)
    d.polygon([(7, 10), (10, 6), (22, 7), (25, 12), (24, 29), (6, 29)], fill=STONE)
    d.polygon([(10, 7), (21, 8), (24, 11), (8, 13)], fill=STONE_L)
    d.polygon([(7, 13), (21, 10), (24, 12), (23, 28), (8, 29)], fill=PAPER)
    d.polygon([(8, 14), (21, 12), (22, 26), (9, 27)], fill=PAPER_L)
    brand(d, 10, 14, SOOT)
    d.line((7, 9, 5, 30), fill=WOOD_D, width=2)
    d.line((25, 9, 27, 30), fill=WOOD_D, width=2)
    d.line((5, 9, 25, 9), fill=WOOD_L, width=2)
    d.line((4, 30, 28, 30), fill=WOOD_L, width=2)
    d.point((7, 9), fill=PAPER_L)
    d.point((24, 9), fill=PAPER_L)
    finish(im, "brand_rubbing")

    im, d = new()
    d.polygon([(2, 30), (3, 11), (7, 5), (15, 7), (19, 13),
               (17, 20), (19, 30)], fill=INK)
    d.polygon([(4, 28), (5, 12), (8, 7), (14, 9), (17, 14),
               (15, 20), (17, 28)], fill=STONE)
    d.polygon([(5, 13), (8, 8), (13, 10), (12, 15)], fill=STONE_L)
    d.line([(7, 24), (11, 22), (9, 18)], fill=STONE_D)
    d.line([(5, 17), (9, 16), (12, 13), (14, 15), (13, 19)], fill=RUST, width=3)
    d.line([(6, 17), (9, 17), (12, 14), (14, 15)], fill=EMBER)
    d.point((12, 14), fill=FIRE)
    d.line((6, 26, 12, 25), fill=STONE_L)
    d.ellipse((15, 22, 30, 31), fill=INK)
    d.ellipse((16, 23, 29, 30), fill=IRON)
    d.ellipse((16, 22, 29, 27), fill=PAPER)
    d.ellipse((18, 23, 27, 26), fill="#506975")
    d.line((19, 23, 25, 23), fill=SILVER)
    d.point((23, 25), fill=STEEL)
    finish(im, "ash_slab")

    im, d = new()
    # A squat, portable toll stone. Its coffer front carries the orange stamp.
    d.polygon([(4, 17), (6, 12), (22, 11), (27, 16), (28, 30),
               (24, 31), (2, 31)], fill=INK)
    d.polygon([(5, 18), (7, 14), (22, 13), (26, 17), (24, 29), (4, 29)], fill=STONE_D)
    d.polygon([(5, 17), (9, 14), (23, 14), (25, 17)], fill=STONE_L)
    d.line((5, 30, 23, 30), fill=STONE)
    d.rectangle((7, 10, 24, 27), fill=COAL, outline=IRON)
    d.polygon([(7, 10), (11, 7), (27, 7), (24, 10)], fill=STEEL)
    d.polygon([(25, 11), (27, 8), (27, 24), (25, 27)], fill=SOOT)
    d.line((13, 5, 21, 5), fill=STEEL)
    d.line((12, 6, 12, 8), fill=IRON)
    d.line((22, 6, 22, 8), fill=IRON)
    brand(d, 10, 13)
    for p in ((8, 11), (23, 11), (8, 26), (23, 26)):
        d.point(p, fill=STEEL)
    finish(im, "toll_box")

    im, d = new()
    d.polygon([(4, 22), (7, 17), (25, 17), (28, 21), (27, 29),
               (30, 31), (2, 31), (5, 28)], fill=INK)
    d.polygon([(5, 23), (26, 22), (25, 30), (7, 30)], fill=WOOD)
    for x in (7, 12, 22, 25):
        d.line((x, 24, x - 1, 29), fill=WOOD_D)
    d.ellipse((5, 17, 27, 24), fill=WOOD_L)
    d.arc((8, 18, 24, 23), 10, 300, fill=WOOD_D)
    # Satchel behind an open ledger, with its arched strap clear above it.
    d.arc((9, 4, 24, 18), 180, 355, fill=INK, width=3)
    d.arc((9, 4, 24, 18), 180, 355, fill=WOOD_L)
    d.rounded_rectangle((8, 10, 25, 22), radius=2, fill=WOOD_D, outline=INK)
    d.line((9, 11, 23, 11), fill=WOOD_L)
    d.polygon([(2, 17), (9, 15), (15, 18), (23, 16), (27, 22),
               (17, 26), (12, 25), (3, 24)], fill=INK)
    d.polygon([(3, 18), (9, 16), (14, 19), (15, 24), (4, 23)], fill=PAPER)
    d.polygon([(15, 19), (23, 17), (25, 22), (17, 25)], fill=PAPER_L)
    d.line((14, 19, 16, 24), fill=WOOD)
    d.line((6, 19, 11, 20), fill=WOOD_L)
    d.line((6, 21, 11, 22), fill=WOOD_L)
    d.line((18, 21, 21, 20), fill=WOOD_L)
    coin(d, 19, 22, hot=True)
    d.rectangle((26, 14, 30, 19), fill=INK)
    d.line((27, 13, 29, 13), fill=STEEL)
    d.point((27, 15), fill=STEEL)
    finish(im, "courier_ledger")

    im, d = new()
    d.polygon([(1, 26), (6, 22), (11, 21), (26, 22), (30, 26),
               (29, 29), (24, 31), (5, 31)], fill=WOOD_D)
    d.polygon([(3, 26), (8, 23), (22, 23), (27, 26), (24, 29),
               (9, 30), (5, 28)], fill=WOOD)
    d.ellipse((6, 24, 24, 29), fill=INK)
    d.line((11, 29, 20, 29), fill=SOOT)
    for p in ((4, 25), (8, 23), (27, 28), (22, 30), (3, 28)):
        d.point(p, fill=WOOD_L)
    # Short spade planted at one side; a D-shaped handle, no floating pixels.
    d.polygon([(4, 20), (11, 18), (12, 23), (9, 27), (5, 24)], fill=INK)
    d.polygon([(5, 21), (10, 20), (11, 23), (9, 25), (6, 24)], fill=STEEL)
    d.line((8, 20, 11, 10), fill=WOOD_L, width=2)
    d.rectangle((9, 5, 15, 10), outline=INK, width=2)
    d.line((10, 6, 14, 6), fill=WOOD_L)
    d.polygon([(17, 16), (22, 15), (26, 18), (28, 25), (25, 28),
               (17, 27), (15, 24)], fill=INK)
    d.polygon([(17, 19), (24, 18), (26, 24), (24, 26), (18, 25)], fill=WOOD)
    d.ellipse((16, 15, 25, 21), fill=WOOD_L)
    d.ellipse((17, 16, 24, 20), fill=COAL)
    for x, y in ((18, 17), (21, 16), (21, 19), (25, 27)):
        coin(d, x, y, hot=True)
    finish(im, "branded_pay_pit")

    im, d = new()
    d.line((4, 18, 2, 30), fill=WOOD_D, width=3)
    d.line((28, 18, 29, 30), fill=WOOD_D, width=3)
    d.line((3, 30, 6, 25), fill=WOOD_L)
    d.line((28, 30, 26, 25), fill=WOOD_L)
    d.polygon([(3, 14), (28, 14), (29, 27), (25, 28), (20, 27),
               (17, 30), (13, 28), (5, 29)], fill=INK)
    d.polygon([(5, 16), (26, 16), (27, 26), (24, 26), (20, 25),
               (16, 28), (13, 26), (6, 27)], fill="#885957")
    d.line((6, 17, 25, 17), fill=PAPER)
    d.polygon([(6, 19), (11, 18), (12, 25), (7, 26)], fill="#A97765")
    d.line((24, 19, 25, 24), fill="#58262D")
    d.ellipse((12, 18, 22, 26), outline=COAL, width=2)
    # Individual stitches across the black circular seam, no lettering.
    for p in ((13, 19), (16, 18), (20, 19), (22, 22), (20, 25), (15, 26), (12, 23)):
        d.point(p, fill=WOOD_D)
    d.line((2, 14, 29, 14), fill=WOOD_L, width=2)
    d.line((4, 15, 4, 17), fill=PAPER)
    d.line((27, 15, 27, 17), fill=PAPER)
    finish(im, "pledged_standard")

    im, d = new()
    d.polygon([(6, 28), (6, 7), (10, 3), (21, 3), (25, 8),
               (24, 28), (28, 31), (3, 31)], fill=INK)
    d.polygon([(8, 27), (8, 8), (11, 5), (21, 5), (23, 9),
               (22, 28)], fill="#C9CDC0")
    d.polygon([(9, 8), (12, 5), (20, 5), (21, 8), (20, 25),
               (9, 25)], fill="#E5E5CF")
    d.line((8, 27, 22, 27), fill=STONE_L)
    d.line((6, 30, 25, 30), fill=STONE)
    d.line((7, 29, 24, 29), fill=SILVER)
    for y in (11, 17):
        for x in (11, 14, 18):
            d.line((x, y, x, y + 3), fill=RUST)
            d.point((x, y + 3), fill=COAL)
        d.line((10, y + 2, 19, y + 1), fill=COAL)
    d.line([(18, 24), (20, 22), (19, 20)], fill=STONE)
    d.point((11, 23), fill=RUST)
    finish(im, "tally_stone")

    im, d = new()
    d.polygon([(1, 27), (4, 22), (9, 21), (18, 23), (20, 28),
               (16, 31), (4, 31)], fill=INK)
    d.polygon([(3, 27), (5, 23), (9, 23), (12, 25), (17, 24),
               (18, 28), (15, 30), (5, 30)], fill=STONE)
    d.line((4, 25, 8, 23), fill=STONE_L)
    d.line((12, 29, 16, 28), fill=STONE_L)
    d.polygon([(6, 26), (7, 19), (4, 14), (5, 11), (9, 16),
               (10, 11), (15, 6), (18, 6), (14, 13), (14, 18),
               (19, 14), (21, 15), (17, 21), (15, 26)], fill=INK)
    d.polygon([(8, 25), (9, 19), (7, 15), (11, 18), (12, 12),
               (16, 8), (12, 19), (18, 17), (14, 22), (14, 25)], fill=SOOT)
    d.line([(9, 24), (10, 21), (13, 19), (12, 16), (13, 13)], fill=RUST, width=2)
    d.line([(10, 24), (11, 21), (14, 20)], fill=EMBER)
    d.point((11, 22), fill=FIRE)
    # The pale folded cover remains a clearly separate piece beside the root.
    d.polygon([(20, 23), (27, 22), (30, 26), (30, 30), (20, 31),
               (17, 28)], fill=INK)
    d.polygon([(21, 24), (26, 23), (29, 26), (27, 28), (19, 28)], fill=PAPER_L)
    d.polygon([(19, 29), (27, 29), (29, 27), (29, 29), (21, 30)], fill=PAPER)
    d.line((22, 25, 27, 26), fill=GOLD)
    finish(im, "rootmark")

    im, d = new()
    for points in (
        [(3, 29), (5, 25), (13, 23), (25, 25), (29, 30), (27, 31), (3, 31)],
        [(7, 24), (7, 19), (12, 17), (22, 18), (25, 22), (22, 27), (9, 27)],
        [(9, 18), (9, 7), (13, 3), (21, 5), (23, 10), (22, 18), (18, 21)],
    ):
        d.polygon(points, fill=INK)
    d.polygon([(5, 29), (7, 26), (15, 25), (24, 27), (26, 30), (6, 30)], fill=STONE_L)
    d.line((8, 26, 14, 26), fill=SILVER)
    d.polygon([(9, 23), (9, 20), (14, 19), (21, 20), (23, 22), (21, 25), (11, 25)], fill=STEEL)
    d.line((10, 20, 19, 20), fill=PAPER_L)
    d.polygon([(11, 17), (11, 8), (14, 5), (20, 7), (21, 10), (20, 17), (17, 19)], fill=SILVER)
    d.line((12, 8, 14, 6), fill="#ECF0DD")
    d.ellipse((12, 8, 20, 17), fill=GOLD)
    d.line((14, 8, 17, 8), fill=FIRE)
    small_brand(d, 13, 10)
    d.line((19, 18, 20, 16), fill=STONE_D)
    finish(im, "survey_cairn")

    im, d = new()
    # Waterline is part of the prop's base, with alpha everywhere beyond it.
    d.polygon([(1, 29), (7, 27), (24, 27), (30, 29), (28, 31), (2, 31)], fill="#344C59")
    d.line((4, 31, 10, 31), fill="#A4C1C0")
    d.line((22, 30, 28, 30), fill="#718F93")
    for y in (23, 26, 29):
        d.polygon([(2, y), (26, y - 1), (29, y + 1), (5, y + 2)], fill=WOOD_D)
        d.line((4, y, 25, y - 1), fill=STEEL)
    d.polygon([(5, 15), (7, 8), (23, 7), (27, 12), (25, 20), (8, 22)], fill=INK)
    d.polygon([(7, 15), (9, 10), (23, 9), (25, 12), (23, 17), (9, 19)], fill=WOOD)
    d.line((10, 11, 22, 10), fill=WOOD_L)
    d.polygon([(19, 8), (18, 13), (21, 14), (17, 19), (21, 17), (23, 12)], fill=INK)
    d.polygon([(5, 19), (9, 16), (25, 15), (28, 19), (27, 25),
               (22, 28), (6, 26)], fill=INK)
    d.polygon([(7, 20), (10, 18), (24, 17), (26, 19), (22, 22)], fill=COAL)
    for x, y in ((10, 18), (14, 18), (19, 18), (22, 19)):
        coin(d, x, y)
    d.polygon([(7, 22), (14, 23), (15, 26), (7, 25)], fill=WOOD)
    d.polygon([(17, 23), (22, 24), (26, 21), (26, 24), (22, 27), (16, 26)], fill=WOOD_L)
    d.line((9, 21, 9, 25), fill=IRON, width=2)
    d.line((24, 22, 23, 26), fill=IRON, width=2)
    d.point((9, 23), fill=SILVER)
    for x, y in ((15, 24), (16, 27), (21, 28), (24, 29), (11, 28)):
        coin(d, x, y)
    finish(im, "wreck_pay_chest")


def checker(size):
    im = Image.new("RGBA", size, "#30353C")
    d = ImageDraw.Draw(im)
    for y in range(0, size[1], 8):
        for x in range(0, size[0], 8):
            if (x // 8 + y // 8) % 2:
                d.rectangle((x, y, x + 7, y + 7), fill="#383E45")
    return im


def font(size):
    try:
        return ImageFont.truetype("DejaVuSans.ttf", size)
    except OSError:
        return ImageFont.load_default()


def contact_sheet():
    sheet = Image.new("RGBA", (1200, 1550), "#1D222B")
    d = ImageDraw.Draw(sheet)
    d.text((24, 18), "THE UNDERTITHE  /  ROUND 36", font=font(25), fill=PAPER_L)
    d.text((24, 52), "21 original textures | exact 4x nearest-neighbour previews | GPT-6 Astra",
           font=font(14), fill=SILVER)

    def put(im, x, y):
        preview = checker(im.size)
        preview.alpha_composite(im)
        sheet.alpha_composite(preview.resize((im.width * 4, im.height * 4),
                                             Image.Resampling.NEAREST), (x, y))

    def label(path, x, y):
        prefix, suffix = "", path.name
        # Two lines retain the complete filename without reducing legibility.
        for p in ("grug_achievements_cloak_", "grug_quests_obj_", "grug_mobs_commander_"):
            if path.name.startswith(p):
                prefix, suffix = p, path.name[len(p):]
                break
        d.text((x, y), prefix, font=font(12), fill=STEEL)
        d.text((x, y + 16), suffix, font=font(14), fill=PAPER_L)

    for i, (path, kind) in enumerate(a for a in ASSETS if a[1] == "cloak"):
        x = 24 + i * 400
        label(path, x, 84)
        im = Image.open(path)
        put(im.crop((0, 0, 16, 32)), x, 126)
        put(im, x + 94, 126)
        d.text((x, 260), "back face       full atlas / dark lining", font=font(12), fill=STEEL)

    guard = Image.open(MOBS / "grug_mobs_guard_accord.png").convert("RGBA")
    for i, (path, kind) in enumerate(a for a in ASSETS if a[1] == "overlay"):
        x = 24 + i * 600
        label(path, x, 296)
        im = Image.open(path)
        put(im, x, 338)
        put(Image.alpha_composite(guard, im), x + 280, 338)
        d.text((x, 472), "transparent overlay                         on guard_accord (reference only)",
               font=font(12), fill=STEEL)

    boss = next(path for path, kind in ASSETS if kind == "boss")
    label(boss, 24, 507)
    put(Image.open(boss), 24, 549)
    put(Image.open(MOBS / "grug_mobs_dungeon_master.png"), 304, 549)
    d.text((304, 716), "grug_mobs_", font=font(12), fill=STEEL)
    d.text((304, 732), "dungeon_master.png", font=font(12), fill=PAPER_L)
    d.text((24, 867), "62 x 78 new atlas       31 x 39 original atlas (reference only)",
           font=font(12), fill=STEEL)
    for i, (path, kind) in enumerate(a for a in ASSETS if a[1] in ("void", "particle", "bolt")):
        x = 485 + i * 235
        label(path, x, 507)
        put(Image.open(path), x, 549)
    tile = Image.open(MOBS / "grug_mobs_rift_void.png")
    repeat = canvas((48, 48))
    for x in range(3):
        for y in range(3):
            repeat.paste(tile, (x * 16, y * 16))
    put(repeat, 485, 650)
    d.text((696, 662), "Void tile, 3 x 3 repeat", font=font(14), fill=PAPER_L)
    d.text((696, 689), "Opposite boundary pixels match.", font=font(12), fill=STEEL)
    d.text((696, 713), "All previews use nearest neighbour.", font=font(12), fill=STEEL)
    d.text((696, 737), "Quest objects: base on bottom rows.", font=font(12), fill=STEEL)

    for i, (path, kind) in enumerate(a for a in ASSETS if a[1] == "quest"):
        x, y = 24 + (i % 4) * 300, 912 + (i // 4) * 207
        label(path, x, y)
        put(Image.open(path), x + 52, y + 44)
    sheet.convert("RGB").save(OUT / "sheet.png")


def mesh_preview():
    """A front orthographic UV check from the actual B3D triangles, no engine.

    Uses the mesh-local bind pose, nearest texture samples and a z buffer.
    It intentionally adds no lighting: this checks painted region placement.
    This is a preview only, not a claim about animated in-game appearance.
    """
    import struct

    data = (MOBS.parent / "models/grug_mobs_dungeon_master.b3d").read_bytes()
    vertices, triangles = [], []

    def chunks(start, end):
        while start < end:
            tag = data[start:start + 4]
            size = struct.unpack_from("<i", data, start + 4)[0]
            a, b = start + 8, start + 8 + size
            if tag == b"BB3D":
                chunks(a + 4, b)
            elif tag == b"NODE":
                chunks(data.index(b"\0", a) + 41, b)
            elif tag == b"MESH":
                chunks(a + 4, b)
            elif tag == b"VRTS":
                flags, sets, size = struct.unpack_from("<3i", data, a)
                assert (flags, sets, size) == (1, 1, 2)
                vertices.extend(struct.unpack_from("<8f", data, p)
                                for p in range(a + 12, b, 32))
            elif tag == b"TRIS":
                triangles.extend(struct.unpack_from("<3i", data, p)
                                 for p in range(a + 4, b, 12))
            start = b

    chunks(0, len(data))

    def render(texture):
        im = canvas((272, 416))
        zbuf = [-math.inf] * (im.width * im.height)
        verts = [(136 + v[0] * 14, 248 - v[1] * 14, v[2], v[6], v[7])
                 for v in vertices]
        for ids in triangles:
            a, b, c = [verts[i] for i in ids]
            den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(den) < 1e-8:
                continue
            for y in range(max(0, int(min(a[1], b[1], c[1]))),
                           min(im.height, math.ceil(max(a[1], b[1], c[1])))):
                for x in range(max(0, int(min(a[0], b[0], c[0]))),
                               min(im.width, math.ceil(max(a[0], b[0], c[0])))):
                    u = ((b[1] - c[1]) * (x + .5 - c[0]) + (c[0] - b[0]) * (y + .5 - c[1])) / den
                    v = ((c[1] - a[1]) * (x + .5 - c[0]) + (a[0] - c[0]) * (y + .5 - c[1])) / den
                    w = 1 - u - v
                    if min(u, v, w) < -1e-6:
                        continue
                    z = u * a[2] + v * b[2] + w * c[2]
                    if z < zbuf[y * im.width + x]:
                        continue
                    zbuf[y * im.width + x] = z
                    tx = max(0, min(texture.width - 1, int((u * a[3] + v * b[3] + w * c[3]) * texture.width)))
                    ty = max(0, min(texture.height - 1, int((u * a[4] + v * b[4] + w * c[4]) * texture.height)))
                    im.putpixel((x, y), texture.getpixel((tx, ty)))
        return im

    sheet = Image.new("RGBA", (840, 510), "#343941")
    d = ImageDraw.Draw(sheet)
    d.text((24, 12), "B3D front UV placement / unlit bind pose", font=font(19), fill=PAPER_L)
    for x, name in ((0, "dungeon_master"), (280, "isquarre")):
        sheet.alpha_composite(render(Image.open(MOBS / f"grug_mobs_{name}.png")), (x, 70))
        d.text((x + 24, 48), name, font=font(15), fill=SILVER)

    def doll(skin):
        im = canvas((16, 32))
        for source, dest in (((8, 8, 16, 16), (4, 0)),
                             ((20, 20, 28, 32), (4, 8)),
                             ((44, 20, 48, 32), (0, 8)),
                             ((44, 20, 48, 32), (12, 8)),
                             ((4, 20, 8, 32), (4, 20)),
                             ((4, 20, 8, 32), (8, 20))):
            im.paste(skin.crop(source), dest)
        return im.resize((96, 192), Image.Resampling.NEAREST)

    guard = Image.open(MOBS / "grug_mobs_guard_accord.png")
    for x, faction in ((590, "accord"), (714, "throng")):
        overlay = Image.open(MOBS / f"grug_mobs_commander_{faction}_overlay.png")
        sheet.alpha_composite(doll(Image.alpha_composite(guard, overlay)), (x, 134))
        d.text((x, 105), faction, font=font(14), fill=SILVER)
    d.text((579, 365), "Flat front skin faces", font=font(15), fill=PAPER_L)
    d.text((579, 390), "Guard is reference only.", font=font(12), fill=SILVER)
    sheet.convert("RGB").save(OUT / "uv_preview.png")


def validate():
    assert len(ASSETS) == 21
    sizes = {"cloak": (32, 32), "overlay": (64, 32), "boss": (62, 78),
             "void": (16, 16), "particle": (8, 8), "bolt": (16, 16), "quest": (32, 32)}
    report = []
    for path, kind in ASSETS:
        im = Image.open(path)
        assert im.mode == "RGBA" and im.size == sizes[kind], path
        alpha = im.getchannel("A")
        if kind in ("cloak", "boss", "void"):
            assert alpha.getextrema() == (255, 255), path
        else:
            assert alpha.getextrema()[0] == 0 and alpha.getextrema()[1] > 0, path
        if kind == "cloak":
            edge = im.getpixel((0, 0))
            assert all(im.getpixel((x, y)) == edge for x in range(16) for y in range(32)
                       if x in (0, 15) or y in (0, 31)), path
            assert len(im.crop((16, 0, 32, 32)).getcolors()) == 1, path
        elif kind == "overlay":
            allowed = Image.new("1", im.size)
            d = ImageDraw.Draw(allowed)
            for box in ((20, 20, 27, 31), (32, 20, 39, 31), (20, 16, 27, 19),
                        (44, 16, 47, 19), (40, 20, 55, 22)):
                d.rectangle(box, fill=1)
            assert all(a == 0 or allowed.getpixel((x, y))
                       for y in range(32) for x in range(64)
                       for a in (alpha.getpixel((x, y)),)), path
        elif kind == "quest":
            assert alpha.getbbox()[3] >= 31, path
            assert alpha.getpixel((0, 0)) == 0 and alpha.getpixel((31, 0)) == 0, path
        elif kind == "void":
            assert all(im.getpixel((0, y)) == im.getpixel((15, y)) for y in range(16))
            assert all(im.getpixel((x, 0)) == im.getpixel((x, 15)) for x in range(16))
        report.append({"file": str(path.relative_to(ROOT)), "size": list(im.size),
                       "mode": im.mode, "alpha_extrema": list(alpha.getextrema()),
                       "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Validated {len(report)} RGBA textures: exact sizes, cloak borders/linings, "
          "overlay UV masks, object grounding, seamless void edges.")
    print("Contact sheet: astra_out/sheet.png; UV preview: astra_out/uv_preview.png")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    cloaks()
    commanders()
    rift()
    isquarre()
    quest_objects()
    validate()
    contact_sheet()
    mesh_preview()
