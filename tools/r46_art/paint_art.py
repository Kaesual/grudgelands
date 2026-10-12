#!/usr/bin/env python3
"""Original, AI-assisted repair marker proposals by GPT-6 Astra; CC0-1.0.

Python 3 + Pillow. Each sprite is authored as a native 16x16 character grid.
No downloads, randomness, antialiasing or image-generation service.
Run without arguments to render; --check verifies every PNG without writing.
Existing service sprites and the map font are read only for the review sheets.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageColor

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
MAP = ROOT / "mods/PLAYER/grug_map"
OUT = HERE / "repair"
NEAREST = Image.Resampling.NEAREST

# Existing service outline; steel/wood/brass from the shipped trainer palette;
# the steel shadow is also used by the Crownbinder's anvil.
PALETTE = {
    ".": (0, 0, 0, 0),
    "#": "#19150F",  # contour
    "s": "#5C6068",  # steel shadow
    "m": "#A9BBC0",  # steel
    "h": "#FFE5AB",  # warm highlight
    "w": "#AE7244",  # wooden handle
    "g": "#E6B64D",  # brass repair straps
}

# All positions, including the transparent margin, are authored here.
GRIDS = {
    "A": (
        "................",
        "..######........",
        ".#hhhmm#........",
        ".#mmmmm#........",
        "..#sss#w#.......",
        "...###.ww#......",
        ".......#ww#.....",
        "........#w#.....",
        "..###########...",
        ".#hhmmmmmmmmm#..",
        "..#mmmmmmsss#...",
        "...###sss###....",
        ".....#sms#......",
        "....#mmsss#.....",
        "...#########....",
        "................",
    ),
    "B": (
        "................",
        "..##..##..###...",
        ".#hm..ms##hmm#..",
        ".#hm..ms##mmm#..",
        ".#hm..ms#.###...",
        "..#hmms##ww#....",
        "...#mm##ww#.....",
        "....#m#wg#......",
        "....#wmh#.......",
        "...#ww#hm#......",
        "..#ww#.#hm#.....",
        ".#ww#...#hm#....",
        ".#w#.....#m#....",
        "..#.......#.....",
        "................",
        "................",
    ),
    "C": (
        "................",
        "...##########...",
        "..#hhmm#mmmmm#..",
        "..#hmmm#mmmms#..",
        "..#hm#gggh#ms#..",
        "..#mmm#m#mmms#..",
        "..#hmmm#mmmms#..",
        "..#mm#gggh#ms#..",
        "..#mmm#m#mmms#..",
        "..#mmm#mmmmss#..",
        "...#m#gggh#s#...",
        "...#mm#m#ss#....",
        "....#mmmss#.....",
        ".....#mss#......",
        "......###.......",
        "................",
    ),
    "D": (
        "................",
        "...........####.",
        "..........#hmm#.",
        ".........#hmms#.",
        "........#hmms#..",
        ".......#hmm##...",
        "......#ghgm#....",
        ".....#hmwgh#....",
        "..##.#mm#g#.....",
        ".#hg##m##.......",
        "..#hg###........",
        "...#wg#.........",
        "..#ww#hg#.......",
        ".#ww#.##........",
        "..##............",
        "................",
    ),
    # A corrections: straight shafts meet the middle of compact steel heads.
    # A1's head axis (-1, 2) is perpendicular to its shaft (2, 1);
    # A3 mirrors those directions vertically.
    # A's anvil keeps its face, neck and foot; one bevel row is removed to
    # leave a clear gap under the longer handles. All three use that anvil.
    "A1": (
        "...####.........",
        "...#hm#.........",
        "..#hm#..........",
        "..#ms#w#........",
        ".####.#ww#......",
        "........#ww#....",
        "..........#ww#..",
        "............##..",
        "................",
        "..###########...",
        ".#hhmmmmmmmmm#..",
        "...###sss###....",
        ".....#sms#......",
        "....#mmsss#.....",
        "...#########....",
        "................",
    ),
    "A2": (
        "................",
        "................",
        ".####...........",
        ".#hm###########.",
        ".#mswwwwwwwwww#.",
        ".#ms###########.",
        ".####...........",
        "................",
        "................",
        "..###########...",
        ".#hhmmmmmmmmm#..",
        "...###sss###....",
        ".....#sms#......",
        "....#mmsss#.....",
        "...#########....",
        "................",
    ),
    "A3": (
        "................",
        "............##..",
        "..........#ww#..",
        "........#ww#....",
        ".####.#ww#......",
        "..#ms#w#........",
        "..#hm#..........",
        "...#hm#.h.......",
        "...####h........",
        "..###########...",
        ".#hhmmmmmmmmm#..",
        "...###sss###....",
        ".....#sms#......",
        "....#mmsss#.....",
        "...#########....",
        "................",
    ),
    # A1a keeps A1's hammer and the empty separation row pixel for pixel.
    # The face stays at y=9; three steel rows fill the body, the horn points
    # left, and the wider waist and foot use the last row of the canvas.
    "A1a": (
        "...####.........",
        "...#hm#.........",
        "..#hm#..........",
        "..#ms#w#........",
        ".####.#ww#......",
        "........#ww#....",
        "..........#ww#..",
        "............##..",
        "................",
        "....###########.",
        ".###hhmmmmmmmm#.",
        "#hmmmmmmmmmsss#.",
        ".####smmmmmss#..",
        ".....#smmmss#...",
        "....#mmmmssss#..",
        "...###########..",
    ),
    # A1b keeps the head and shaft angle but removes one 2:1 shaft step.
    # The anvil starts one row higher and has four steel rows in its body.
    "A1b": (
        "...####.........",
        "...#hm#.........",
        "..#hm#..........",
        "..#ms#w#........",
        ".####.#ww#......",
        "........#ww#....",
        "..........##....",
        "................",
        "....###########.",
        ".###hhmmmmmmmm#.",
        "#hmmmmmmmmmsss#.",
        ".###smmmmmmsss#.",
        "....#smmmmmss#..",
        ".....#smmmss#...",
        "....#mmmmssss#..",
        "...###########..",
    ),
    # A1a's complete hammer translated down by one pixel, without rotation.
    # The heavy anvil remains pixel-identical at y=9..15.
    "A1c": (
        "................",
        "...####.........",
        "...#hm#.........",
        "..#hm#..........",
        "..#ms#w#........",
        ".####.#ww#......",
        "........#ww#....",
        "..........#ww#..",
        "............##..",
        "....###########.",
        ".###hhmmmmmmmm#.",
        "#hmmmmmmmmmsss#.",
        ".####smmmmmss#..",
        ".....#smmmss#...",
        "....#mmmmssss#..",
        "...###########..",
    ),
    # The same translation by two pixels. Only the grip's two contour pixels
    # share the anvil's top contour (x=12..13, y=9); no fill is covered.
    "A1d": (
        "................",
        "................",
        "...####.........",
        "...#hm#.........",
        "..#hm#..........",
        "..#ms#w#........",
        ".####.#ww#......",
        "........#ww#....",
        "..........#ww#..",
        "....###########.",
        ".###hhmmmmmmmm#.",
        "#hmmmmmmmmmsss#.",
        ".####smmmmmss#..",
        ".....#smmmss#...",
        "....#mmmmssss#..",
        "...###########..",
    ),
}

TITLES = {
    "A": "HAMMER AND ANVIL",
    "B": "CROSSED REPAIR TOOLS",
    "C": "MENDED SHIELD",
    "D": "RIVETED BLADE",
    "A1": "RAISED SMITH'S HAMMER",
    "A2": "HORIZONTAL SMITH'S HAMMER",
    "A3": "STRIKING SMITH'S HAMMER",
    "A1a": "HEAVY ANVIL - ORIGINAL HAMMER",
    "A1b": "HEAVY ANVIL - SHORTER SHAFT",
    "A1c": "HAMMER ONE PIXEL CLOSER",
    "A1d": "HAMMER TWO PIXELS CLOSER",
}
DESCRIPTIONS = {
    "A": "A LIGHT HAMMER ABOVE A LOW STEEL ANVIL.",
    "B": "AN OPEN WRENCH CROSSED WITH A SMALL HAMMER.",
    "C": "THREE BRASS STAPLES BRIDGE A SPLIT SHIELD.",
    "D": "A DIAGONAL BLADE JOINED BY A BRASS REPAIR STRAP.",
    "A1": "AN ANGLED STEEL HEAD WITH A LONG, STRAIGHT WOODEN SHAFT.",
    "A2": "A SQUARE-ENDED HEAD ACROSS A HORIZONTAL WOODEN SHAFT.",
    "A3": "A LOW STRIKING HEAD WITH TWO SPARK PIXELS AT THE ANVIL FACE.",
    "A1a": "A1'S HAMMER UNCHANGED, A THREE-ROW STEEL BODY, LEFT HORN AND BROAD FOOT.",
    "A1b": "ONE LESS SHAFT STEP, A FOUR-ROW STEEL BODY MAKES THE ANVIL DOMINANT.",
    "A1c": "A1a'S COMPLETE HAMMER ONE PIXEL LOWER, THE SAME HEAVY ANVIL.",
    "A1d": "A1a'S COMPLETE HAMMER TWO PIXELS LOWER, THE SAME HEAVY ANVIL.",
}

# Exact base colours from grug_map/base.lua REGION.human, REGION.troll and
# grug_map/minimap.lua SEA. Swatches omit shading to isolate legibility.
BACKGROUNDS = (
    ("LIGHT WORLD MAP", "#C6C280"),
    ("GREEN GRASSLAND", "#86B274"),
    ("DARK MINIMAP", "#1C3A52"),
)
REFERENCES = (
    ("WS", "WEAPONSMITH", "trainer_weaponsmith"),
    ("AS", "ARMORSMITH", "trainer_armorsmith"),
    ("CB", "CROWNBINDER", "crownbinder"),
    ("TL", "TAILOR", "trainer_tailor"),
    ("LW", "LEATHERWORKER", "trainer_leatherworker"),
    ("WC", "WOODCARVER", "trainer_woodcarver"),
    ("GS", "GOLDSMITH", "trainer_goldsmith"),
    ("AL", "ALCHEMIST", "trainer_alchemist"),
    ("CK", "COOKING", "trainer_cooking"),
    ("IN", "INNKEEPER", "innkeeper"),
    ("DM", "DECOR MERCHANT", "decor_merchant"),
    ("HS", "HOUSING STEWARD", "housing_steward"),
    ("HM", "HOME", "home"),
)


def rgba(value):
    return ImageColor.getcolor(value, "RGBA") if isinstance(value, str) else value


def sprite(letter):
    rows = GRIDS[letter]
    assert len(rows) == 16 and all(len(row) == 16 for row in rows), letter
    result = Image.new("RGBA", (16, 16))
    result.putdata([rgba(PALETTE[ch]) for row in rows for ch in row])
    assert result.getchannel("A").getextrema() == (0, 255)
    assert set(result.getchannel("A").tobytes()) == {0, 255}
    assert len(result.getcolors()) <= 7
    return result


def map_letters():
    """Read the original game font's red-marker atlas without modifying it."""
    with Image.open(MAP / "art/font.png") as opened:
        atlas = opened.convert("RGBA")
    chars = (MAP / "art/font.txt").read_text().strip("\n")
    starts = [x for x in range(atlas.width) if atlas.getpixel((x, 0)) == (255, 0, 0, 255)]
    assert len(chars) == len(starts)
    ends = starts[1:] + [atlas.width]
    return {ch: atlas.crop((start, 1, end - 1, 8))
            for ch, start, end in zip(chars, starts, ends)}


def text_image(message, letters, scale=1, colour="#F5ECD7"):
    glyphs = [letters[ch] for ch in message.upper()]
    width = sum(im.width + 1 for im in glyphs) - 1
    result = Image.new("RGBA", (width, 7))
    x = 0
    for glyph in glyphs:
        tinted = Image.new("RGBA", glyph.size, colour)
        tinted.putalpha(glyph.getchannel("A"))
        result.alpha_composite(tinted, (x, 0))
        x += glyph.width + 1
    return result.resize((width * scale, 7 * scale), NEAREST)


def preview(icons, letters, variant=None, corrections=False, anvils=False, closer=False):
    sheet = Image.new("RGBA", (1280, 870), "#191F23")

    def label(message, x, y, scale=1, colour="#F5ECD7", centered=False):
        rendered = text_image(message, letters, scale, colour)
        sheet.alpha_composite(rendered, (x - rendered.width // 2 if centered else x, y))

    label("GRUDGELANDS - ROUND 46 - REPAIR MARKER", 32, 24, 2, "#E6B64D")
    title = f"{variant} - {TITLES[variant]}" if variant else "FOUR WAYS TO MEND"
    description = DESCRIPTIONS[variant] if variant else (
        "A HAMMER AND ANVIL    B CROSSED TOOLS    C MENDED SHIELD    D RIVETED BLADE")
    if corrections:
        title = "A - THREE CLEARER HAMMERS"
        description = "A ORIGINAL    A1 RAISED    A2 HORIZONTAL    A3 STRIKING"
    if anvils:
        title = "A1 - TWO HEAVIER ANVILS"
        description = "A1 PREVIOUS    A1a ORIGINAL HAMMER, HEAVY ANVIL    A1b SHORTER SHAFT, LARGER ANVIL"
    if closer:
        title = "A1a - HAMMER CLOSER TO THE ANVIL"
        description = "A1a PICKED ORIGINAL    A1c ONE PIXEL LOWER    A1d TWO PIXELS LOWER"
    label(title, 32, 53, 3)
    label(description, 32, 91)

    refs = []
    for code, _, name in REFERENCES:
        with Image.open(MAP / f"textures/grug_map_{name}.png") as opened:
            im = opened.copy()
        assert im.size == (16, 16) and im.mode == "RGBA", name
        refs.append((code, im, False))
    keys = ("A", "A1", "A2", "A3") if corrections else "ABCD"
    if anvils:
        keys = ("A1", "A1a", "A1b")
    if closer:
        keys = ("A1a", "A1c", "A1d")
    if variant:
        keys = (variant,)
    proposals = [(key, icons[key], True) for key in keys]
    # The three smithing-adjacent services immediately precede every proposal.
    entries = refs[:3] + proposals + refs[3:]
    pitch = 68 if variant is None else 82
    start = (1280 - len(entries) * pitch) // 2
    for row, (name, colour) in enumerate(BACKGROUNDS):
        y = 127 + row * 196
        label(name, 32, y, 2)
        label(colour.lstrip("#"), 1248, y + 4, centered=True, colour="#C4CFD0")
        sheet.paste(rgba(colour), (24, y + 25, 1256, y + 174))
        label("1X", 30, y + 39, colour="#FFE5AB" if row == 2 else "#19150F")
        label("4X", 30, y + 93, colour="#FFE5AB" if row == 2 else "#19150F")
        for i, (code, im, proposed) in enumerate(entries):
            cx = start + i * pitch + pitch // 2
            sheet.alpha_composite(im, (cx - 8, y + 35))
            sheet.alpha_composite(im.resize((64, 64), NEAREST), (cx - 32, y + 70))
            label(code, cx, y + 151, 2, "#FFE5AB" if row == 2 else "#19150F", True)
            # A small underline identifies proposals without framing the icon.
            if proposed:
                sheet.paste(rgba("#FFE5AB" if row == 2 else "#19150F"),
                            (cx - 9, y + 168, cx + 9, y + 170))

    label("EXISTING SERVICES", 32, 726, 2, "#E6B64D")
    for i, (code, name, _) in enumerate(REFERENCES):
        label(f"{code}  {name}", 32 + (i % 4) * 310, 759 + (i // 4) * 18)
    label("16 BY 16 RGBA - NEAREST NEIGHBOUR - ORIGINAL ART - AI ASSISTED - CC0 1.0",
          32, 846, colour="#A9BBC0")
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Compare all generated PNGs without writing")
    args = parser.parse_args()
    icons = {key: sprite(key) for key in GRIDS}
    assert len({im.tobytes() for im in icons.values()}) == len(GRIDS)
    letters = map_letters()
    outputs = {OUT / "overview.png": preview(icons, letters)}
    outputs[OUT / "overview-a.png"] = preview(icons, letters, corrections=True)
    outputs[OUT / "overview-a1.png"] = preview(icons, letters, anvils=True)
    outputs[OUT / "overview-a1c.png"] = preview(icons, letters, closer=True)
    for key, im in icons.items():
        outputs[OUT / key / "grug_map_repair.png"] = im
        outputs[OUT / key / "preview.png"] = preview(icons, letters, key)
    failures = []
    for path, expected in outputs.items():
        if args.check:
            if not path.is_file():
                failures.append(f"Missing: {path.relative_to(ROOT)}")
                continue
            with Image.open(path) as actual:
                if (actual.size, actual.mode, actual.tobytes()) != (
                        expected.size, expected.mode, expected.tobytes()):
                    failures.append(f"Mismatch: {path.relative_to(ROOT)}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            expected.save(path)
    if failures:
        raise SystemExit("\n".join(failures))
    for key, im in icons.items():
        print(f"{key}: {im.width}x{im.height} {im.mode}, "
              f"{len(im.getcolors()) - 1} opaque colours, binary alpha")
    print(f"{'Verified' if args.check else 'Wrote'} {len(outputs)} PNGs.")


if __name__ == "__main__":
    main()
