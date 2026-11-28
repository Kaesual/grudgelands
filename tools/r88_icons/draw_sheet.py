"""Draw the Round 88 approval sheet with Pillow. All studies stay on the sheet."""

from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
MODS = HERE.parents[1] / "mods"
BASE = MODS / "ENTITIES/grug_traders/textures/grug_traders_item_potion_healing_weak.png"
STATUS = MODS / "CORE/grug_core/textures"
NEAREST = Image.Resampling.NEAREST

# Each character is one painted pixel. Omitted pixels on the right are clear.
# k outlines, b is leather, c is cork, and w/g/s are the glass lip and edges.
GLASS = dict(k="#332a2a", b="#52382e", c="#bb8055", w="#e0d7ba",
             g="#a7afa0", s="#737c77", p="#ffe19a")
STUDS = [(6, 2), (8, 2), (10, 2), (6, 4), (8, 4), (10, 4)]
STUDIES = {
    "Healing": (dict(l="#f18b78", r="#c94c4f", d="#8a3644"), """
.
......kccck
.....kbbbbbk
.....kbbbbbk
.....kbbbbbk
..kkkwwgggsk
.kwggkgggggskk
kwk..klllrrrrsk
kgk..klrrrrrrdsk
kggkklrrrrrrrdsk
.kkkslrrrrrrrdsk
...ksrrrrrrrrdsk
...ksrrrrrrrddsk
....kgdddddddsk
.....kggsssssk
......kkkkkkk
"""),
    "Vigor": (dict(l="#e06b54", r="#b44446", d="#833441", h="#f6c972"), """
......kccck
......kccck
.....kbbbbbk
.....kbbbbbk
.....kbbbbbk
......kwgsk
....kkwwggskk
..kkwwllrrrdskk
..kwlllrrrrrdsk
..kglrhhrhhrdsk
..ksrrhhhhhddsk
...ksrrhhhddsk
....ksrrhddsk
.....ksdddsk
....kwwgggssk
....kkkkkkkkk
"""),
    "Stoneskin": (dict(l="#c7c7b8", r="#909a97", d="#505c62"), """
......kccck
......kccck
.....kbbbbbk
.....kbbbbbk
.....kbbbbbk
......kwgsk
...kkwwgggggkk
..kwlllllrrrdsk
..kwllldllrrdsk
..kgrlldlrrrdsk
..kgrrldrrdddsk
..ksdrrdrddrrsk
..ksddrddrrrdsk
...ksdddddddsk
....kwggggssk
....kkkkkkkkk
"""),
    "Swiftness": (dict(l="#f4cd70", r="#d89a42", d="#995d35"), """
.
...........kccck
...........kccck
..........kwwgsk
...........kgsk
......r...kwgsk
...rll..kwlrddk
..rr....kglrdk
.......kwlrddk
....rl.kglrdk
.rllr.kwlrddk
rr....kglrdk
.....kwlrddk
.....kgrddk
.....ksggk
......kkk
"""),
}

# The comparison is the 0.87.0 bottle with the recipe's RGB tint at 90/255.
HEALING_TINTS = ["#d13b45", "#c3313b", "#b42631", "#a81729", "#961222", "#850e1c"]
# family, caption, displayed tier's tint, active-effect art
EXAMPLES = [
    ("Healing", "Potion  /  Tier 1", HEALING_TINTS[0], None),
    ("Vigor", "Elixir  /  Tier 1", "#c4483e", "elixir_vigor"),
    ("Stoneskin", "Elixir  /  Tier 1", "#8a8a8a", "elixir_stoneskin"),
    ("Swiftness", "Draught  /  Single strength", "#e9c83b", "alchemy_swiftness"),
]


def study(name, tier=None):
    accents, pixels = STUDIES[name]
    palette = GLASS | accents
    icon = Image.new("RGBA", (16, 16))
    rows = pixels.strip().splitlines()
    assert len(rows) == 16 and all(len(row) <= 16 for row in rows)
    brush = ImageDraw.Draw(icon)
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            if key != ".":
                brush.point((x, y), fill=palette[key])
    for point in STUDS[:tier or 0]:
        brush.point(point, fill=palette["p"])
    return icon


def tinted(base, colour):
    """Use rounded RGB interpolation and keep the original bottle's alpha."""
    channels = []
    for channel, target in zip(base.split(), ImageColor.getrgb(colour)):
        channels.append(channel.point(lambda v: (165 * v + 90 * target + 127) // 255))
    return Image.merge("RGBA", [*channels, base.getchannel("A")])


def sheet():
    paper, ink, muted, rule = "#f4eddf", "#342d2a", "#65574e", "#c9bdab"
    slot, light, brass = "#343330", "#f4e7d0", "#d8b67e"
    page = Image.new("RGB", (820, 626), paper)
    pen = ImageDraw.Draw(page)

    def label(x, y, words, size, colour=ink, anchor="lm", serif=False):
        if serif:
            try:
                face = ImageFont.truetype("LiberationSerif-Regular.ttf", size)
            except OSError:
                face = ImageFont.load_default(size=size)
        else:
            face = ImageFont.load_default(size=size)
        pen.text((x, y), words, font=face, fill=colour, anchor=anchor)

    def paste(icon, cx, cy, width):
        height = width * icon.height // icon.width
        scaled = icon.resize((width, height), NEAREST)
        page.paste(scaled, (cx - width // 2, cy - height // 2), scaled)

    def pair(icon, x, y):
        paste(icon, x - 15, y, 32)
        paste(icon, x + 18, y, 16)

    def sample_row(y, title, sizes):
        label(39, y - 6, title, 15, light)
        label(39, y + 11, sizes, 11, brass)

    with Image.open(BASE) as source:
        base = source.convert("RGBA")
    label(27, 21, "GRUDGELANDS   /   ALCHEMY", 12, muted)
    label(793, 21, "ROUND 88   /   CONCEPT", 12, muted, "rm")
    label(26, 57, "The alchemist's bottles", 39, serif=True)
    pen.line((27, 87, 792, 87), fill=rule)
    label(29, 119, "Family studies", 20, serif=True)
    label(30, 144, "5x enlargement", 13, muted)

    pen.rectangle((27, 237, 792, 367), fill=slot)
    for y in (280, 323):
        pen.line((39, y, 780, y), fill="#57524a")
    sample_row(258, "Proposed", "32 px   /   16 px")
    sample_row(301, "Current item", "32 px   /   16 px")
    sample_row(345, "Active effect", "32 px")

    for x, (name, kind, tint, effect) in zip((235, 389, 543, 697), EXAMPLES):
        icon = study(name, 1 if name != "Swiftness" else None)
        label(x, 120, name, 23, anchor="mm", serif=True)
        label(x, 144, kind, 12, muted, "mm")
        paste(icon, x, 192, 80)
        pair(icon, x, 258)
        pair(tinted(base, tint), x, 301)
        if effect:
            with Image.open(STATUS / f"grug_status_{effect}.png") as badge:
                paste(badge.convert("RGBA"), x, 345, 32)
        else:
            label(x, 345, "Instant heal", 12, brass, "mm")

    label(27, 397, "Reading the neckband", 28, serif=True)
    label(792, 399, "HEALING POTION   /   SIX TIERS", 12, muted, "rm")
    label(29, 427, "Each brass stud marks one tier. Fill the top row first, then the row beneath it.", 15)
    pen.line((27, 449, 792, 449), fill=rule)
    label(30, 471, "Tier", 15)
    label(30, 498, "Band detail, 4x", 13, muted)
    pen.rectangle((27, 520, 792, 606), fill=slot)
    pen.line((39, 563, 780, 563), fill="#57524a")
    sample_row(541, "Proposed", "32 px   /   16 px")
    sample_row(585, "Current item", "32 px   /   16 px")
    for tier, tint in enumerate(HEALING_TINTS, 1):
        x = 110 + 104 * tier
        icon = study("Healing", tier)
        label(x, 471, str(tier), 16, anchor="mm")
        paste(icon.crop((5, 1, 12, 6)), x, 498, 28)
        pair(icon, x, 541)
        pair(tinted(base, tint), x, 585)
    return page


if __name__ == "__main__":
    sheet().save(HERE / "concept_sheet.png")
