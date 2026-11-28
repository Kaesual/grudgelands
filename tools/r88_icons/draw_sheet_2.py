"""Render the second approval sheet. Each bottle is drawn on a 16 px grid."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from draw_sheet import BASE, HEALING_TINTS, NEAREST, STATUS, study, tinted

HERE = Path(__file__).resolve().parent
TINTS = {
    "Healing": HEALING_TINTS,
    "Mana": ["#356ed1", "#2f63c2", "#2a57b2", "#253ea3", "#203893", "#1b3184"],
}
SHELF = (
    ("Healing", "Instant potion", HEALING_TINTS[2], None),
    ("Mana", "Instant potion", TINTS["Mana"][2], None),
    ("Vigor", "Elixir", "#a52c29", "elixir_vigor"),
    ("Stoneskin", "Elixir", "#747474", "elixir_stoneskin"),
    ("Swiftness", "Draught", "#e9c83b", "alchemy_swiftness"),
)

# Each row is centred on the neck. A dot lets the sheet show through.
# Paint the two families' marks last so the glass cuts frame them at every rank.
GLASS = dict(k="#302928", w="#e0dcc2", g="#acb8ad", s="#718081",
             c="#c58d5e", b="#835538", t="#a8714f", u="#d6a174",
             z="#e8bb64", a="#a56f3b", j="#f4d590", m="#9b394e", v="#db6a67")
LIQUID = {
    "Healing": dict(l="#e47871", r="#c34853", d="#883645", h="#ffdfbb"),
    "Mana": dict(l="#709fce", r="#456fbb", d="#3a4a85", h="#d3ebdf"),
    "Swiftness": dict(l="#f3c666", r="#d59741", d="#935531", h="#fff0a9"),
}

# The stopper and lip occupy rows 0–4. The vessel starts on row 5.
CORK = ". . kcck kcbk kgwggk"
STOPPERS = (
    CORK,
    ". kcck kvvvmk kvmvvmmk kwgmmk",
    ". . kwwwwwsk kggggssk kwggsk",
    "kk kwgk kwglsk kggdsk kwggsk",
    "kk....kk kjk..kzk kjzkkzak kazzjzak kwggsk",
    "kkkk kjjjzk kzjjjzzk kazzak kwzzsk",
)

# Three bodies per family, each with a second finish. The fluted glass
# has its own drawing because its ribs and heel also change the outline.
BODIES = {
    "Healing": {
        "clay": """
            kttk kuttuk kutttrdttk
            kutlrrrrrdtk kutlrrrrrdtk kutrrrrrrdtk kutrrrrrrdtk
            kutrrrrrrdtk ktrrrrddtk kttttttk kkkkkk
        """,
        "blown": """
            kgsk kkwggskk kkwgggggsskk
            kwgllrrrrrrdsk kwllrrrrrrrdsk kglrrrrrrrrdsk kgrrrrrrrrrdsk
            ksrrrrrrrrddsk ksrrrrrdddsk kggggssssk kkkkkkkk
        """,
        "fluted": """
            kgsk kkwggskk kkkwgggggsskkk
            kwglrrrrrrdsgk kwglrrrrrrdsgk kwglrrrrrrdsgk kwglrrrrrrdsgk
            kwglrrrrrrdsgk kgldrrrrddsgsk kwggggggsssssk kkkkkkkkkkkk
        """,
        "crystal": """
            kgsk kkwggskk kkkwggggggskkk
            kwllrrrrrrrdggsk kwlldrrrrrrddqvk kqlldrrrrrrddqvk kqvldrrrrrrddqvk
            kqvvldrrrrddqqvk kqqvldrrddvqqk kqqqqvvvvqqk kkkkkkkk
        """,
    },
    "Mana": {
        "clay": """
            kttk kttk kuttuk
            kutrrdtk kutlrrrdtk kutlrrrrrdtk kutrrrrrrdtk
            kutrrrrrrdtk ktrrrrddtk kttttttk kkkkkk
        """,
        "blown": """
            kgsk kwsk kwggsk
            kwgggssk kwglrrrrsk kkwllrrrrrdskk kglrrrrrrrrdsk
            kgrrrrrrrrrdsk ksrrrrrrddsk kggggssk kkkkkk
        """,
        "fluted": """
            kgsk kwsk kwggsk
            kwgggssk kkwlrrrdsgkk kwglrrrrrdsgsk kwglrrrrrrrdsgsk
            kwglrrrrrrrdsgsk kgldrrrrddsgsk kwggggggsssssk kkkkkkkkkkkk
        """,
        "crystal": """
            kgsk kwsk kwwgsk
            kwggggsk kkwggrrrdskk kwllrrrrrrdsgk kqvldrrrrrrddqvk
            kqvvldrrrrddqqvk kqqvldrrddvqqk kqqqqvvvvqqk kkkkkkkk
        """,
    },
}
SWIFT = """
    kwggsk kkwggggskk kwllllrrrdsk kkwlrrrrhhrrdskk kglrrrhhrrrrdssk
    kglrhhlrrrrhhddk kgrlrrrrrhhrrddk ksrrrrrhhlrrddsk ksrrrrlrrdddsk
    kgggggsssssk kkkkkkkk
"""
MARKS = {
    "Healing": ((5, 8), ("..hh..", "..hh..", "hhhhhh", "hhhhhh", "..hh..", "..hh..")),
    "Mana": ((5, 9), ("hh...", "hh...", "hh..h", ".hhhh", "..hh.")),
}
MATERIALS = ("Earthenware", "Dipped glaze", "Blown glass", "Fluted glass", "Cut crystal", "Gilt crystal")
SEALS = ("Cork", "Wax seal", "Silver disc", "Gem point", "Winged clasp", "Amber sun")


def paint(icon, rows, y, palette):
    brush = ImageDraw.Draw(icon)
    for dy, row in enumerate(rows.split()):
        assert len(row) <= 16 and (row == "." or len(row) % 2 == 0), row
        left = (16 - len(row)) // 2
        for dx, key in enumerate(row):
            if key != ".":
                brush.point((left + dx, y + dy), fill=palette[key])


def bottle(family, tier, direction):
    palette = GLASS | LIQUID[family]
    bodies = BODIES[family]
    if direction == "Glasswork":
        cut = ("clay", "clay", "blown", "fluted", "crystal", "crystal")[tier - 1]
        body, stopper = bodies[cut], CORK
        if cut == "crystal":
            palette.update(q="#bbd4cf", v="#779799", w="#f4f2d6", s="#688184")
            if tier == 6:
                palette.update(q="#f3c676", v="#b18047")
        if tier == 2:
            # An ivory slip-dip across the heel and coloured glaze up to the lip.
            palette.update(t=palette["r"], u=palette["l"])
            body = body.replace("kttttttk", "kuwwgguk")
    else:
        body, stopper = bodies["blown"], STOPPERS[tier - 1]

    icon = Image.new("RGBA", (16, 16))
    paint(icon, body, 5, palette)
    paint(icon, stopper, 0, palette)
    (x, y), rows = MARKS[family]
    brush = ImageDraw.Draw(icon)
    for dy, row in enumerate(rows):
        for dx, key in enumerate(row):
            if key == "h":
                brush.point((x + dx, y + dy), fill=palette[key])
    return icon


def family_study(family):
    if family in TINTS:
        return bottle(family, 3, "Glasswork")
    if family == "Swiftness":
        icon = Image.new("RGBA", (16, 16))
        paint(icon, SWIFT, 5, GLASS | LIQUID[family])
    else:
        # Keep the first plate's approved pixels from the neck down.
        icon = study(family)
        icon.paste((0, 0, 0, 0), (0, 0, 16, 5))
    paint(icon, CORK, 0, GLASS)
    return icon


PAPER, INK, MUTED = "#f3eee2", "#2f322d", "#585d51"
RULE, ACCENT = "#c6c4b4", "#865036"
SLOT, SLOT_RULE, LIGHT, QUIET = "#343a36", "#535a51", "#ffefda", "#cdc8b5"


def font(size, serif=False):
    face = "LiberationSerif-Regular.ttf" if serif else "LiberationSans-Regular.ttf"
    try:
        return ImageFont.truetype(face, size)
    except OSError:
        return ImageFont.load_default(size=size)


def sheet():
    page = Image.new("RGB", (980, 924), PAPER)
    pen = ImageDraw.Draw(page)
    with Image.open(BASE) as source:
        base = source.convert("RGBA")

    def text(x, y, words, size, colour=INK, anchor="lm", serif=False):
        pen.text((x, y), words, font=font(size, serif), fill=colour, anchor=anchor)

    def paste(icon, cx, cy, size):
        stamp = icon.resize((size, size), NEAREST)
        page.paste(stamp, (cx - size // 2, cy - size // 2), stamp)

    def pair(icon, cx, cy):
        paste(icon, cx - 13, cy, 32)
        paste(icon, cx + 17, cy, 16)

    def line(y, colour=RULE):
        pen.line((30, y, 949, y), fill=colour)

    text(30, 23, "GRUDGELANDS   /   ALCHEMY", 13, MUTED)
    text(949, 23, "ROUND 88   /   STUDY 02", 13, MUTED, "rm")
    line(39)
    text(29, 70, "The alchemist’s bottles", 42, serif=True)
    text(949, 76, "FAMILY STUDIES", 13, ACCENT, "rm")

    text(31, 157, "Bottle detail", 18, serif=True)
    text(32, 180, "6× enlargement", 13, MUTED)
    pen.rectangle((30, 253, 949, 366), fill=SLOT)
    for y in (291, 329):
        line(y, SLOT_RULE)
    for y, label in ((272, "Study"), (310, "Today’s tint"), (348, "Active effect")):
        text(43, y, label, 15, LIGHT)
    text(31, 236, "32 + 16 px below", 13, MUTED)
    for i, (name, kind, tint, effect) in enumerate(SHELF):
        x = 226 + 157 * i
        icon = family_study(name)
        paste(icon, x, 153, 96)
        text(x, 214, name, 24, anchor="mm", serif=True)
        text(x, 237, kind, 14, MUTED, "mm")
        pair(icon, x, 272)
        pair(tinted(base, tint), x, 310)
        if effect:
            with Image.open(STATUS / f"grug_status_{effect}.png") as badge:
                paste(badge.convert("RGBA"), x, 348, 32)
        else:
            text(x, 348, "Instant", 13, QUIET, "mm")

    def tier_panel(top, name, description, captions):
        text(30, top, name, 32, serif=True)
        text(949, top + 4, "4× DETAIL    /    INVENTORY PAIRS AT 32 + 16 PX", 12, MUTED, "rm")
        text(31, top + 34, description, 16, MUTED)
        line(top + 54)
        grid = top + 87
        pen.rectangle((30, grid, 949, grid + 149), fill=SLOT)
        for offset in (37, 75, 112):
            line(grid + offset, SLOT_RULE)
        text(43, top + 71, "Tier", 14, MUTED)
        for i, caption in enumerate(captions):
            x = 203 + i * 134
            text(x, top + 71, f"{i + 1}  ·  {caption}", 14, anchor="mm")
            for family, offset in (("Healing", 0), ("Mana", 75)):
                y = grid + offset + 18
                icon = bottle(family, i + 1, name)
                pen.rectangle((x - 61, y - 16, x + 4, y + 53), fill="#556159")
                paste(icon, x - 28, y + 18, 64)
                pair(icon, x + 36, y)
                pair(tinted(base, TINTS[family][i]), x + 36, y + 37)
        for offset, label in ((18, "Healing"), (55, "Today’s tint"),
                              (93, "Mana"), (130, "Today’s tint")):
            reference = label == "Today’s tint"
            text(43, grid + offset, label, 14 if reference else 19,
                 QUIET if reference else LIGHT, serif=not reference)

    tier_panel(395, "Glasswork", "Follow the belly and heel. The smooth walls at tier 3 give way to deep ribs at tier 4.", MATERIALS)
    tier_panel(665, "Stoppers", "Follow the closure. The flat silver disc at tier 3 becomes a pointed gem at tier 4.", SEALS)
    return page


if __name__ == "__main__":
    sheet().save(HERE / "concept_sheet_2.png")
