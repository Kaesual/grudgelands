#!/usr/bin/env python3
"""Paint the 41 selected Round 33 cloaks at their native pixel resolution.

Run with Python + Pillow. No game files or external inputs are written.
Each palette is copied from the approved proposal; there is no dithering,
antialiasing, random noise, or interpolated colour in the texture assets.
"""

from pathlib import Path
import hashlib
import json

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "cloaks"
PALETTES = {
    "plain_grey": ("#797B7C", "#575A5C", "#8A8C8D"),
    "hunter": ("#203B29", "#14261B", "#34543B"),
    "kingslayer": ("#342A46", "#1D1929", "#C6A45C", "#EEE0AE"),
    "wyvernslayer": ("#216343", "#113828", "#44905A", "#A7C970"),
    "dragonslayer": ("#245D96", "#142E55", "#62AAD0", "#D5F1F3"),
    "honored": ("#9A303A", "#531E29", "#D1D4CD", "#BDA063"),
    "zombie_slayer": ("#51455F", "#2B2534", "#B8AD91", "#DBD4BA"),
    "boaring_work": ("#8B623D", "#463423", "#D8AB88", "#F1E2BF"),
    "rat_race": ("#827449", "#49432F", "#C8BEA1", "#CB9292"),
    "suppers_ready": ("#B07646", "#68442E", "#F0D7A2", "#7C8D58"),
    "bottle_service": ("#315B58", "#1D3433", "#A8D3BC", "#CEAC70"),
    "loose_bones": ("#3F5156", "#243136", "#D9D5B7", "#A7AD9D"),
    "stone_deaf": ("#6D716C", "#3B413D", "#C9C8B4", "#AA8257"),
    "final_notice": ("#D2C09A", "#806D51", "#913F3E", "#F0E4C7"),
    "rust_in_peace": ("#744B36", "#3D2B23", "#B9C3BE", "#D5A56D"),
    "no_more_orders": ("#414966", "#242A40", "#DED8BD", "#A8845D"),
    "last_word": ("#65465C", "#362635", "#D2B682", "#ECE0C5"),
    "grounded": ("#94724F", "#503C2D", "#D9C6A0", "#6E858C"),
}
FAMILIES = [
    ("plain_grey", 1, None),
    ("hunter", 3, "C-U1"),
    ("kingslayer", 3, "C-U2"),
    ("wyvernslayer", 3, "C-U3"),
    ("dragonslayer", 3, "C-U4"),
    ("honored", 3, "C-U5"),
    ("zombie_slayer", 3, "C1"),
    ("boaring_work", 3, "C2"),
    ("rat_race", 2, "C10"),
    ("suppers_ready", 3, "C7"),
    ("bottle_service", 3, "C8"),
    ("loose_bones", 3, "C12"),
    ("stone_deaf", 2, "C16"),
    ("final_notice", 1, "C17"),
    ("rust_in_peace", 2, "C19"),
    ("no_more_orders", 1, "C20"),
    ("last_word", 1, "C22"),
    ("grounded", 1, "C24"),
]


def palette_for(family, tier):
    palette = PALETTES[family]
    if family == "hunter" and tier > 1:
        palette = ("#203B29", "#14261B", "#648052",
                   "#A8AD78" if tier == 2 else "#D5C88B")
    elif family == "wyvernslayer" and tier == 3:
        palette = palette[:3] + ("#D9D68D",)
    elif family == "honored" and tier == 3:
        palette = palette[:3] + ("#E1C16C",)
    elif family == "bottle_service" and tier == 3:
        palette = palette[:2] + ("#D5E8CE", "#E0BE74")
    return palette


class Cloth:
    def __init__(self, family, tier):
        self.palette = palette_for(family, tier)
        self.base, self.shadow = self.palette[:2]
        self.motif = self.palette[2]
        self.accent = self.palette[-1]
        self.edge = self.shadow
        self.image = Image.new("RGBA", (16, 32), self.base)
        self.d = ImageDraw.Draw(self.image)
        # Short tapered creases stay at the edges, away from the badge.
        self.poly([(1, 1), (3, 1), (2, 4), (2, 8), (1, 11)], self.shadow)
        self.poly([(12, 1), (14, 1), (14, 10), (13, 7), (13, 4)], self.shadow)
        self.rect((1, 23, 1, 30), self.shadow)
        self.rect((14, 21, 14, 30), self.shadow)
        self.rect((2, 28, 2, 30), self.shadow)
        self.rect((13, 27, 13, 30), self.shadow)

    def rect(self, box, color):
        self.d.rectangle(box, fill=color)

    def poly(self, points, color):
        self.d.polygon(points, fill=color)

    def line(self, points, color, width=1):
        self.d.line(points, fill=color, width=width)

    def frame(self, box, color, width=1):
        self.d.rectangle(box, outline=color, width=width)

    def stamp(self, rows, x, y, colors):
        for dy, row in enumerate(rows):
            for dx, key in enumerate(row):
                if key != ".":
                    self.d.point((x + dx, y + dy), fill=colors[key])

    def hem(self, color, y=28, width=2):
        self.rect((1, y, 14, y + width - 1), color)

    def finish(self):
        # All four edge strips share a single edge colour, including corners.
        self.frame((0, 0, 15, 31), self.edge)
        atlas = Image.new("RGBA", (32, 32), self.shadow)
        atlas.paste(self.image, (0, 0))
        return atlas


def plain(c, tier):
    # A few long, stepped ridges suggest cloth; never add an emblem.
    c.line([(5, 2), (5, 9), (4, 10), (4, 23)], c.motif)
    c.line([(10, 3), (10, 13), (11, 14), (11, 28)], c.motif)
    c.line([(7, 26), (7, 30)], c.shadow)


def hunter(c, tier):
    if tier == 1:
        plain(c, tier)
    elif tier == 2:
        # Exactly one narrow olive border, no badge.
        c.edge = c.motif
    else:
        c.hem(c.motif, 25, 6)
        for x in (3, 7, 11):
            c.stamp([".L.", ".LL", "LLL", "LL.", ".L."],
                    x - 1, 25, {"L": c.accent})


def kingslayer(c, tier):
    if tier == 3:
        # Open at the top: throne arms and seat, not a closed picture frame.
        c.rect((1, 9, 2, 24), c.motif)
        c.rect((13, 9, 14, 24), c.motif)
        c.rect((1, 23, 14, 25), c.motif)
        # Leave a full cloth pixel between the crown and both throne arms.
        c.stamp([
            "...HH...", "G..GG..G", "GG.GG.GG", "GGGGGGGG",
            "GGGGGGGG", ".GGGGGG.", ".HHHHHH.", ".GGGGGG.",
            ".GGGGGG.",
        ], 4, 10, {"G": c.motif, "H": c.accent})
    else:
        c.stamp([
            ".....HH.....", "G....GG....G", "GG...GG...GG",
            "GGG.GGGG.GGG", "GGGGGGGGGGGG", ".GGGGGGGGGG.",
            ".GGGGGGGGGG.", ".HHHHHHHHHH.", ".GGGGGGGGGG.",
        ], 2, 10, {"G": c.motif, "H": c.accent})
    if tier >= 2:
        c.rect((4 if tier == 3 else 3, 19, 11 if tier == 3 else 12, 20), c.motif)
        c.hem(c.motif, 28, 2)


def scales(c, icy=False):
    # Interlocking, offset rows: six-pixel scales rather than stippled noise.
    for row, y in enumerate(range(5, 29, 5)):
        for x in range(-3 if row % 2 else 0, 16, 6):
            if icy:
                shape = ["SS..SS", ".SSSS.", "..SS.."]
            else:
                shape = ["S....S", "SS..SS", ".SSSS.", "..SS.."]
            c.stamp(shape, x, y, {"S": c.motif})


def shoulder_chevron(c, color):
    c.poly([(1, 3), (7, 7), (8, 7), (14, 3),
            (14, 6), (8, 11), (7, 11), (1, 6)], color)


def wyvernslayer(c, tier):
    scales(c)
    if tier >= 2:
        c.rect((6, 7, 9, 28), c.shadow)
        c.rect((7, 6, 8, 29), c.accent)
        for y in (10, 16, 22):
            c.rect((6, y, 9, y + 1), c.accent)
    if tier == 3:
        shoulder_chevron(c, c.accent)


def dragonslayer(c, tier):
    scales(c, icy=True)
    if tier >= 2:
        for y in range(2, 31):
            width = 2 if (y // 4) % 2 else 1
            c.rect((1, y, width, y), c.accent)
            c.rect((15 - width, y, 14, y), c.accent)
    if tier == 3:
        shoulder_chevron(c, c.accent)
        c.hem(c.accent, 27, 4)
        c.rect((4, 26, 5, 27), c.accent)
        c.rect((10, 26, 11, 27), c.accent)


def honored(c, tier):
    if tier >= 2:
        c.poly([(2, 8), (13, 8), (13, 17), (11, 21),
                (8, 24), (7, 24), (4, 21), (2, 17)], c.shadow)
        c.hem(c.motif)
    if tier == 3:
        c.rect((1, 6, 2, 26), c.accent)
        c.rect((13, 6, 14, 26), c.accent)
    # Twelve-pixel crossed blades, clear gold guards, grips below the guards.
    c.poly([(3, 9), (5, 10), (11, 16), (10, 18), (3, 11)], c.motif)
    c.poly([(12, 9), (10, 10), (4, 16), (5, 18), (12, 11)], c.motif)
    c.line([(3, 16), (6, 19)], c.accent, 2)
    c.line([(12, 16), (9, 19)], c.accent, 2)
    c.line([(4, 19), (2, 21)], c.accent, 2)
    c.line([(11, 19), (13, 21)], c.accent, 2)


def zombie_slayer(c, tier):
    if tier == 3:
        c.stamp([
            "....AAAA....", "..AAAAAAAA..", ".AAA....AAA.",
            "AAA......AAA", "AA........AA", "AA........AA",
            "AA........AA", "AA........AA",
        ], 2, 8, {"A": c.accent})
        c.hem(c.accent, 25, 2)
    if tier >= 2:
        c.rect((3, 15, 4, 20), c.motif)
        c.rect((11, 15, 12, 20), c.motif)
        c.rect((3, 15, 4, 15), c.accent)
        c.rect((11, 15, 12, 15), c.accent)
        c.hem(c.accent, 29, 2)
    c.rect((3, 18, 12, 20), c.motif)
    c.rect((3, 18, 12, 18), c.accent)


def boaring_work(c, tier):
    if tier == 3:
        c.poly([(2, 9), (6, 11), (9, 11), (13, 9), (13, 17),
                (11, 21), (4, 21), (2, 17)], c.shadow)
        c.poly([(3, 10), (5, 11), (4, 13)], c.motif)
        c.poly([(12, 10), (10, 11), (11, 13)], c.motif)
        c.rect((4, 13, 5, 13), c.accent)
        c.rect((10, 13, 11, 13), c.accent)
    c.stamp([
        "..PPPPPP..", ".PPPPPPPP.", "PPPPPPPPPP", "PPDDPPDDPP",
        "PPDDPPDDPP", ".PPPPPPPP.", "..PPPPPP..",
    ], 3, 15, {"P": c.motif, "D": c.shadow})
    if tier >= 2:
        c.poly([(1, 13), (2, 16), (3, 18), (4, 18), (4, 21),
                (2, 20), (1, 17)], c.accent)
        c.poly([(14, 13), (13, 16), (12, 18), (11, 18), (11, 21),
                (13, 20), (14, 17)], c.accent)


def rat_race(c, tier):
    if tier == 1:
        c.poly([(6, 14), (10, 14), (12, 16), (12, 18),
                (10, 20), (6, 20), (4, 18), (4, 16)], c.motif)
        c.poly([(6, 14), (3, 15), (2, 17), (3, 18), (7, 18)], c.motif)
        c.rect((3, 13, 4, 14), c.motif)
        c.rect((6, 13, 7, 14), c.motif)
        c.rect((4, 16, 4, 16), c.shadow)
        c.line([(12, 18), (13, 19), (13, 22), (10, 22)], c.accent)
    else:
        c.poly([(5, 13), (10, 13), (12, 15), (13, 17), (13, 19),
                (11, 22), (5, 22), (3, 19), (3, 16)], c.motif)
        c.poly([(5, 14), (2, 16), (1, 18), (3, 19), (7, 18)], c.motif)
        c.rect((3, 11, 5, 13), c.motif)
        c.rect((7, 11, 9, 13), c.motif)
        c.rect((4, 16, 4, 16), c.shadow)
        c.line([(13, 18), (14, 20), (14, 24), (10, 24)], c.accent)
        c.hem(c.accent, 27, 4)
        # Bite marks remove pink trim, not cloth or opacity.
        for x, y in ((3, 27), (9, 27), (6, 29), (12, 29)):
            c.rect((x, y, x + 1, y + 1), c.base)


def steam(c, x):
    c.stamp([".SS", ".SS", "SS.", "SS.", ".SS", ".SS"],
            x, 9, {"S": c.motif})


def suppers_ready(c, tier):
    if tier == 1:
        steam(c, 6)
    else:
        steam(c, 4)
        steam(c, 9)
        c.hem(c.accent, 29, 2)
    c.stamp([
        "BBBBBBBBBBBB", "BBBBBBBBBBBB", ".BBBBBBBBBB.",
        "..BBBBBBBB..", "...BBBBBB...", "....BBBB....",
    ], 2, 17, {"B": c.motif})
    if tier == 3:
        c.hem(c.motif, 24, 2)
        c.hem(c.accent, 27, 1)


def bottle_service(c, tier):
    if tier == 2:
        c.rect((1, 5, 1, 26), c.motif)
        c.rect((14, 5, 14, 26), c.motif)
        c.hem(c.accent, 24, 3)
    if tier == 3:
        c.edge = c.accent
        c.frame((2, 2, 13, 29), c.accent)
    left, right = (4, 11) if tier < 3 else (3, 12)
    c.rect((6, 9, 9, 10), c.accent)
    c.rect((6, 11, 9, 13), c.motif)
    c.rect((left + 1, 13, right - 1, 14), c.motif)
    c.rect((left, 15, right, 22), c.motif)
    # Broad liquid window, with a light glass edge retained on every side.
    c.rect((left + 2, 18, right - 2, 20), c.base)
    if tier == 3:
        c.rect((left, 23, right, 24), c.motif)
        c.rect((left + 2, 21, right - 2, 22), c.base)


def loose_bones(c, tier):
    if tier == 1:
        c.stamp([
            "..BBBBBBBB", ".BBBBBBBBB", "BBB.......", "BB........",
            "BB........", "BBB.......", ".BBBBBBB..", "..BBBBBB..",
        ], 3, 12, {"B": c.motif})
    elif tier == 2:
        c.stamp([".BBBBBBBBBB.", "BBBBBBBBBBBB", "BB........BB"],
                2, 10, {"B": c.motif})
        c.stamp([".BBBB..BBBB.", "BBBBB..BBBBB", "BB........BB"],
                2, 15, {"B": c.motif})
        c.stamp(["BB........BB", "BBBBBBBBBBBB", ".BBBBBBBBBB."],
                2, 20, {"B": c.motif})
    else:
        c.frame((1, 8, 14, 25), c.accent)
        for y in (11, 16, 21):
            c.stamp(["BBBBBBBBBB", "BBBBBBBBBB", "BB......BB"],
                    3, y, {"B": c.motif})


def stone_deaf(c, tier):
    if tier == 1:
        c.rect((3, 11, 12, 21), c.motif)
        c.line([(8, 11), (6, 15), (9, 17), (7, 21)], c.shadow, 2)
    else:
        c.poly([(2, 10), (7, 10), (5, 14), (7, 16),
                (5, 21), (2, 21)], c.motif)
        c.poly([(10, 11), (13, 11), (13, 22), (8, 22),
                (10, 17), (8, 15)], c.motif)
        c.hem(c.accent, 25, 2)
        c.hem(c.accent, 29, 2)


def final_notice(c, tier):
    c.rect((2, 9, 13, 24), c.shadow)
    c.rect((3, 9, 13, 23), c.accent)
    c.stamp([
        "RR.....RR", "RR.....RR", ".RR...RR.", "..RR.RR..",
        "...RRR...", "...RRR...", "...RRR...", "..RR.RR..",
        ".RR...RR.", "RR.....RR", "RR.....RR",
    ], 4, 11, {"R": c.motif})


def rust_in_peace(c, tier):
    if tier == 1:
        c.stamp([
            "..RRRRRRRR..", ".RRRRRRRRRR.", "RRR......RRR",
            "RR..SSSS..RR", "RR..SSSS..RR", "RR..SSSS..RR",
            "RR..SSSS..RR", "RRR......RRR", ".RRRRRRRRRR.",
            "..RRRRRRRR..",
        ], 2, 11, {"R": c.accent, "S": c.motif})
    else:
        # The right-hand tooth of a four-cardinal-tooth cog is absent.
        c.stamp([
            "....RRRR....", "....RRRR....", "..RRRRRRRR..",
            "..RRRRRRRR..", "RRRR....RR..", "RRRR.SS.RR..",
            "RRRR.SS.RR..", "RRRR....RR..", "..RRRRRRRR..",
            "..RRRRRRRR..", "....RRRR....", "....RRRR....",
        ], 2, 10, {"R": c.accent, "S": c.motif})
        c.hem(c.motif)


def no_more_orders(c, tier):
    c.stamp([
        "BB..........BB", "BB..........BB", "BB..........BB",
        "BB..........BB", "BB..........BB", "BB..........BB",
        "BB.BB.BB.BB.BB", "BB.BB.BB.BB.BB", "BBBBBBBBBBBBBB",
        ".BBBBBBBBBBBB.", "..BBBBBBBBBB..",
    ], 1, 11, {"B": c.motif})


def last_word(c, tier):
    c.stamp([
        "....GGGG....", "..GGGGGGGG..", ".GGGGGGGGGG.",
        ".GGGGGGGGGG.", "GGGGGGGGGGGG", "GGGGGGGGGGGG",
        "GGGGGGGGGGGG", "GGGGGGGGGGGG", ".GGGGGGGGGG.",
        ".GGGGGGGGGG.", "..GGGGGGGG..", "....GGGG....",
    ], 2, 10, {"G": c.motif})
    c.rect((1, 15, 14, 17), c.accent)


def grounded(c, tier):
    c.rect((2, 10, 13, 21), c.motif)
    c.stamp([
        "..SSSS....", ".SSSSSS.SS", "SSSSSSS.SS",
        "SSSSSSS.SS", ".SSSSSS.SS", "..SSSS....",
    ], 3, 13, {"S": c.shadow})


PAINTERS = {"plain_grey": plain}
for _family, _, _ in FAMILIES[1:]:
    PAINTERS[_family] = globals()[_family]


def rgb(color):
    return tuple(bytes.fromhex(color.removeprefix("#")))


def get_font(size):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)


def contact_sheet(entries):
    columns, cw, ch = 7, 148, 180
    margin, top = 24, 88
    rows = (len(entries) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cw + margin * 2, top + rows * ch + 28),
                      "#181E22")
    d = ImageDraw.Draw(sheet)
    d.text((margin, 20), "GRUDGELANDS / CLOAKS", font=get_font(22), fill="#E9DDBF")
    d.text((margin, 53), "ROUND 33   /   41 APPEARANCES   /   OUTER FACE x4   /   NEAREST NEIGHBOUR",
           font=get_font(12), fill="#A3B1B6")
    for i, entry in enumerate(entries):
        x = margin + (i % columns) * cw
        y = top + (i // columns) * ch
        d.rectangle((x + 3, y + 2, x + cw - 5, y + ch - 8), fill="#242D32")
        d.text((x + 10, y + 7), f"{i + 1:02}", font=get_font(10), fill="#90A2AA")
        with Image.open(OUT / entry["file"]) as texture:
            face = texture.crop((0, 0, 16, 32))
            sheet.paste(face.resize((64, 128), Image.Resampling.NEAREST),
                        (x + (cw - 64) // 2, y + 12))
        label = entry["id"]
        font = get_font(11)
        text_width = d.textbbox((0, 0), label, font=font)[2]
        d.text((x + (cw - text_width) // 2, y + 149), label, font=font, fill="#E5E7DC")
    sheet.save(ROOT / "cloaks_sheet.png")


def legend(entries):
    lines = [
        "# Round 33 cloak textures", "",
        "41 original cloak textures, painted at 32 × 32 pixels in RGBA.",
        "The contact sheet shows only columns 0–15 at exactly ×4 nearest-neighbour",
        "scale, in the requested order. Each label is the filename suffix.", "",
        "## Format and art choices", "",
        "- Columns 0–15: outer back, shoulders at row 0 and hem at row 31.",
        "- Columns 16–31: plain lining in the proposal's dark shadow colour.",
        "- All four outer border strips are exactly one pixel wide in the edge colour.",
        "- Every texture is fully opaque, including the rat's cloth-coloured bite notches.",
        "- Each selected proposal's exact palette is used, with no additional shades.",
        "- No motif or palette departures. The required edge on untrimmed cloaks is",
        "  a dark cloth seam; Hunter II uses its proposed olive edge. Rat II's bites",
        "  interrupt the pink trim without cutting holes in the outer face.",
        "- The new plain grey starting cloak uses `#797B7C`, `#575A5C`, `#8A8C8D`.",
        "- The permitted Pillow generator contains hand-placed pixel shapes; no",
        "  image-generation service, game-file changes, or external artwork is involved.", "",
        "## Ordered legend", "", "| # | ID | Proposal | Edge | Palette |",
        "|---|---|---|---|---|",
    ]
    for i, e in enumerate(entries, 1):
        palette = ", ".join(f"`{color}`" for color in e["palette"])
        lines.append(f"| {i} | `{e['id']}` | {e['proposal'] or 'Starting cloak'} | "
                     f"`{e['edge']}` | {palette} |")
    lines += ["", "## Reproduction and checks", "",
              "Run `python3 astra_out/paint_cloaks.py` from the worktree with Pillow installed.",
              "The script verifies the exact 41-file set, PNG format, 32 × 32 RGBA,",
              "opaque alpha, palette membership, four continuous border strips,",
              "plain dark lining, and uniqueness of all 41 decoded pixel arrays.",
              "`validation.json` records file hashes and the results.", "",
              "## In-game visual check after integration", "",
              "Inspect the back from near and far, compare all tiers of each family,",
              "then rotate the character and make the cloak swing to inspect its lining",
              "and thin edges. No runtime test or game integration was performed here.", ""]
    (ROOT / "cloaks_sheet.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for family, tiers, proposal in FAMILIES:
        for tier in range(1, tiers + 1):
            id_ = family if family == "plain_grey" else f"{family}_{tier}"
            c = Cloth(family, tier)
            PAINTERS[family](c, tier)
            texture = c.finish()
            filename = f"grug_achievements_cloak_{id_}.png"
            texture.save(OUT / filename, optimize=True)
            entries.append({"id": id_, "file": filename,
                            "proposal": f"{proposal}.{tier}" if proposal else None,
                            "palette": c.palette, "edge": c.edge})

    assert len(entries) == 41
    assert {p.name for p in OUT.iterdir()} == {e["file"] for e in entries}
    pixel_hashes = set()
    for entry in entries:
        path = OUT / entry["file"]
        with Image.open(path) as texture:
            assert texture.format == "PNG" and texture.mode == "RGBA"
            assert texture.size == (32, 32)
            assert texture.getchannel("A").getextrema() == (255, 255)
            allowed = {rgb(color) + (255,) for color in entry["palette"]}
            assert {color for _, color in texture.getcolors(1024)} <= allowed
            edge = rgb(entry["edge"]) + (255,)
            for x in range(16):
                assert texture.getpixel((x, 0)) == edge
                assert texture.getpixel((x, 31)) == edge
            for y in range(32):
                assert texture.getpixel((0, y)) == edge
                assert texture.getpixel((15, y)) == edge
            lining = texture.crop((16, 0, 32, 32))
            assert lining.getcolors(512) == [(512, rgb(entry["palette"][1]) + (255,))]
            digest = hashlib.sha256(texture.tobytes()).hexdigest()
            assert digest not in pixel_hashes, entry["id"]
            pixel_hashes.add(digest)
            entry["pixel_sha256"] = digest
        entry["file_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    contact_sheet(entries)
    legend(entries)
    (ROOT / "validation.json").write_text(json.dumps({
        "texture_count": 41, "size": [32, 32], "mode": "RGBA",
        "format": "PNG", "all_opaque": True, "exact_palettes": True,
        "continuous_one_pixel_edges": True, "solid_dark_linings": True,
        "unique_pixel_arrays": 41, "entries": entries,
    }, indent=2) + "\n", encoding="utf-8")
    print("PASS: 41 unique 32x32 RGBA PNGs; exact palettes, opaque faces, "
          "continuous edges, dark linings. Contact sheet and legend written.")


if __name__ == "__main__":
    main()
