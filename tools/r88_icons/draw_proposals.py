"""Draw the 16 px pick-page artwork. Run with Python and Pillow."""

from dataclasses import dataclass
from pathlib import Path

from PIL import Image

from draw_sheet_2 import BODIES, CORK, GLASS, MARKS, STOPPERS, SWIFT, paint

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "proposals"
TIERS = (
    ("Earthenware", "Cork"),
    ("Earthenware", "Wax seal"),
    ("Blown glass", "Silver disc"),
    ("Blown glass", "Gem point"),
    ("Cut crystal", "Winged clasp"),
    ("Cut crystal", "Amber sun"),
)


@dataclass(frozen=True)
class Drawing:
    title: str
    body: str        # Centred rows of glass, from the throat to the base.
    mark: tuple = () # A small inlay positioned within the colour field.
    top: str = ""    # Single-strength bottles have their own closure.
    start: int = 5


# l/r/d are the light, body and shadow of the brew. h is the emblem, i its recess.
COLOURS = {
    "healing":    ("#ed8479", "#c34853", "#853247", "#ffe2bc", "#a53746"),
    "vigor":      ("#db6b54", "#ad3d49", "#752f41", "#ffd079", "#e8a050"),
    "mana":       ("#79abd9", "#487ac5", "#364d90", "#d4eee6", "#92cbdc"),
    "focus":      ("#728ddd", "#4d5caa", "#383872", "#e0f6ec", "#a4d8fb"),
    "precision":  ("#e9aa51", "#ba792f", "#85512e", "#fff2bb", "#70452d"),
    "stoneskin":  ("#bbc2b6", "#8a9996", "#53636a", "#d6d9c6", "#4c5861"),
    "antivenom":  ("#99b761", "#56894f", "#38624b", "#fff0bb", "#cfda9f"),
    "swiftness":  ("#f3c666", "#d59741", "#935531", "#fff0a9", "#f2b451"),
    "cave":       ("#b99bd4", "#785a9d", "#4a385e", "#f4d9ff", "#493252"),
    "deepwater":  ("#72bbac", "#268a8e", "#245863", "#d9f6dc", "#83d2c7"),
    "merchant":   ("#d68a68", "#ae5b47", "#804538", "#e3b082", "#925040"),
}

# A/B are paired within each family. Dots in the emblems leave the liquid visible.
# The first Healing and Mana studies retain the three hand-drawn material bodies.
DRAWINGS = {
    "healing": (
        Drawing("Round cross flask", BODIES["Healing"]["blown"], MARKS["Healing"]),
        Drawing("Field canteen", """
            kgsk kwggsk kwggggsssk kkwgllllrrrrdskk
            kwllrrrrrrrrrdsk kwlrrrrrrrrrrdsk kglrrrrrrrrrrdsk
            kgrrrrrrrrrrddsk ksrrrrrrrrddsssk kggggggssssk kkkkkkkk
        """, ((5, 8), (".hhhh.", "hhiihh", "hiiiih", "hiiiih", "hhiihh", ".hhhh."))),
    ),
    "vigor": (
        Drawing("Heart chalice", """
            kwgk kkwggskk kkwgllrrrrdskk kwllrrrrrrrdsk
            kglrrrrrrrrdsk ksrrrrrrrrddsk ksrrrrrddskk ksrrddsk
            ksddsk kwggggsssk kkkkkkkk
        """, ((5, 9), ("hh.hh", "hhhhh", ".hhh.", "..h.."))),
        Drawing("Heart urn", """
            kgsk kwggsk kkwgggsskk kwglrrrrrdsk kwlrrrrrrrrdsk
            kglrrrrrrrrdsk kglrrrrrrrrdsk ksrrrrrrddsk ksddsk
            kwggggggsssk kkkkkkkkkk
        """, ((4, 8), (".dd..dd.", "dhhddhhd", "dhhhiihd", ".dhhihd.", "..dhhd..", "...dd..."))),
    ),
    "mana": (
        Drawing("Crescent pear", BODIES["Mana"]["blown"], MARKS["Mana"]),
        Drawing("Tide flask", """
            kwsk kwggsk kkwgggggsskk kwgllrrrrrrdsk
            kwllrrrrrrrrrdsk kglrrrrrrrrrrdsk kgrrrrrrrrrrddsk
            ksrrrrrrrrrrddsk ksrrrrrrddsk kggggssk kkkkkk
        """, ((4, 8), ("...hhhi.", "..hhh...", ".hhi....", "hhh...hh", ".hhhhhi.", "...ii..."))),
    ),
    "focus": (
        Drawing("Star diamond", """
            kwsk kwggsk kkwlrrsk kwllrrrrsk kwllrrrrrdsk
            kglrrrrrrrrdsk ksrrrrrrddsk ksrrrrddsk ksddsk
            kwggggsssk kkkkkkkk
        """, ((4, 7), ("...h....", "...h....", "..ihh...", "ihhhhhhi", "...hhi..", "....h...", "....i..."))),
        Drawing("Astral pillar", """
            kgsk kwggsk kkwllrrdsskk kwlrrrrrrdsk kwlrrrrrrdsk
            kglrrrrrrdsk kglrrrrrrdsk ksrrrrrrddsk ksggggsssk
            kwggggggsssk kkkkkkkkkk
        """, ((4, 7), ("...h....", "...hi...", "..hddh..", "hhd..dhi", "..hddh..", "...ih...", "....h..."))),
    ),
    "precision": (
        Drawing("Sight lens", """
            kgsk kwggsk kkwglrrdskkk kwllrrrrrdsk
            kwllrrrrrrrdsk kglrrrrrrrrdsk kglrrrrrrrrdsk ksrrrrrrddsk
            ksrrddsk kwggggsssk kkkkkkkk
        """, ((4, 8), ("..hhhh..", ".hi..ih.", ".h.hh.h.", ".h.hh.h.", ".hi..ih.", "..hhhh.."))),
        Drawing("Rangefinder", """
            kgsk kwggsk kkwgggsskk kkwllrrrrrrdsskk
            kwlrrrrrrrrrrdsk kglrrrrrrrrrrdsk ksrrrrrrrrrrddsk
            ksrrrrrrrrddsk ksrrrrddsk kwggggggsssk kkkkkkkkkk
        """, ((4, 8), ("hhh..hhh", "hi....ih", "..ihhi..", "..ihhi..", "hi....ih", "hhh..hhh"))),
    ),
    "stoneskin": (
        Drawing("Split slate", """
            kwsk kkwgggggsskk kwllllrrrdsk
            kwllrrrrrrdskk kgrlrrrrrrrdsk kgrrrrrrrrddsk
            ksrrrrrrrdddsk ksrrrrrrrddssk ksrrrrddsssk kwggggsssk kkkkkkkk
        """, ((4, 8), ("hl.i..lh", ".hli.lr.", "..hiih..", "...ii..i", ".iiiiii.", "ii..i..."))),
        Drawing("Shield bottle", """
            kwsk kwggsk kkwgggggsskk kkwllllrrrddsskk
            kwllrrrrrrrrrdsk kglrrrrrrrrdsk kgrrrrrrddsk
            ksrrrrddsk ksddsk kwggggsssk kkkkkkkk
        """, ((4, 8), ("hhhhhhhh", "hliiilri", "hliiirri", ".hiiiri.", "..hiir..", "...hi..."))),
    ),
    "antivenom": (
        Drawing("Fang bottle", """
            kwggsk kkwgggggsskk kwllrrrrrdsk kwlrrrrrrdsk kglrrrrrrdsk
            kglrrrrrrdsk ksrrrrrrddsk kggggggssssk kkkkkkkkkk
        """, ((5, 8), ("hhhhh.", "..ihh.", "...hh.", "..hh..", ".hi...")),
                ". . . kcck kcbk kwggggsk", 6),
        Drawing("Adder flask", """
            kwsk kwggsk kkwggggsskkk kwlrrrrrrdsk kglrrrrrrrrdsk
            kgrrrrrrrrrdsk ksrrrrrrddsk kggggggssk kkkkkkkk
        """, ((4, 9), ("hh....hh", ".hh..hh.", ".ih..hi.", "..h..h..")),
                ". . . kcck kcbk kwggsk", 6),
    ),
    "swiftness": (
        Drawing("Streaked barrel", SWIFT, top=CORK),
        Drawing("Wing flask", """
            kwggsk kkwgggsskk kwllrrrrrdsk kwllrrrrrdsk kglrrrrrrdsk
            kgrrrrrrrdsk kgrrrrrrrdsk ksrrrrrrddsk kggggggssssk kkkkkkkkkk
        """, ((4, 8), (".....hhh", "...hhhi.", "..hh....", ".hhhhhi.", ".hh.....", ".hhhi...")),
                ". . kcck kcbk kwggsk kwggsk", 6),
    ),
    "cave": (
        Drawing("Lantern eye", """
            kwggggsk kkwgggggsskk kwllrrrrrdsk kwllrrrrrrrdsk
            kglrrrrrrrrdsk ksrrrrrrrrddsk ksrrrrddsk kggggssk kkkkkk
        """, ((4, 8), ("..hhhh..", ".hhidhh.", "hhlidhhh", ".hhidhh.", "..hhhh..")),
                ". . . kcccck kbbbbk kwggggsk", 6),
        Drawing("Twilight inkwell", """
            kwsk kwggsk kwggsk kkwgggsskk kwllrrrrrdsk
            kglrrrrrrdsk kgrrrrrrrdsk ksrrrrrrddsk kggggggssssk kkkkkkkkkk
        """, ((5, 8), ("..hh..", ".hiih.", "hh..hh", "hh..hh", ".hiih.", "..hh..")),
                ". . kcck kcbk kwggsk kwggsk", 6),
    ),
    "deepwater": (
        Drawing("Diving bell", """
            kwsk kwggsk kwlrrdsk kwlrrrrdsk kglrrrrrrdsk
            kglrrrrrrdsk kglrrrrrrrrdsk ksrrrrrrrrddsk ksrrrrddsk
            kwggggggsssk kkkkkkkkkk
        """, ((5, 7), ("...hi.", "...id.", "......", ".hhh..", "hddi..", ".iid..", "....hi")), CORK),
        Drawing("Tide globe", """
            kwsk kwggsk kkwgggggsskk kwllrrrrrdsk kwllrrrrrrrdsk
            kglrrrrrrrrdsk kgrrrrrrrrddsk ksrrrrrrddsk ksddsk
            kwggggsssk kkkkkkkk
        """, ((4, 8), ("....hh..", ".hi.h.i.", ".....i..", "ii.....h", ".ihi.hhi", "...ihi..")), CORK),
    ),
    "merchant": (
        Drawing("Clay salve pot", """
            kttk kuttuttttk kutlrrrrrdtk kutlrrrrrdtk kutrrrrrrdtk
            ktrrrrddddtk kttttttttk kkkkkkkk
        """, top=". . . . . kcck kcbk kuttuk", start=8),
        Drawing("Slipware bottle", """
            kttk kttk kuttuk kutrrdtk kulrrdtk kutrrdtk
            kuttuutk kttttttk kkkkkk
        """, top=". . . . kcck kcbk kuttuk", start=7),
    ),
}

# Clay has a deep russet wall, glass a thin green-grey edge. Crystal cuts
# continue into the colour field, catching the light on the lower corners.
CLAY = dict(w="#edbc8b", g="#bf895e", s="#935f48")
CRYSTAL = dict(w="#f3f1d2", g="#c5dcd7", s="#8daeb5", q="#c5ded9", v="#70959e")


def draw(family, variant, tier=None):
    drawing = DRAWINGS[family][variant]
    palette = GLASS | dict(zip("lrdhi", COLOURS[family]))
    if tier is None:
        material = "Earthenware" if family == "merchant" else "Blown glass"
        stopper = drawing.top
    else:
        material = TIERS[tier - 1][0]
        stopper = STOPPERS[tier - 1]
    body = drawing.body
    if family in ("healing", "mana") and variant == 0:
        study = {"Earthenware": "clay", "Blown glass": "blown", "Cut crystal": "crystal"}
        body = BODIES[family.title()][study[material]]
    elif material == "Cut crystal":
        cuts = []
        for y, raw in enumerate(body.split(), drawing.start):
            row = list(raw)
            if y >= 9 and len(row) >= 10 and "r" in row:
                # Progress from the outer wall towards the centre as the cut descends.
                inset = min((len(row) - 6) // 2, 2 + (y - 9) // 2)
                row[inset - 1:inset + 1] = "qv"
                row[-inset - 1:-inset + 1] = "vq"
            cuts.append("".join(row))
        body = " ".join(cuts)
    if material == "Earthenware":
        palette.update(CLAY)
    if material == "Cut crystal":
        palette.update(CRYSTAL)

    icon = Image.new("RGBA", (16, 16))
    paint(icon, body, drawing.start, palette)
    # Use a separate palette for the closure: its metal and gem stay recognisable
    # on clay and crystal, including the red sealing wax (v in the stopper).
    seal_palette = GLASS | dict(d=palette["d"], l=palette["l"])
    paint(icon, stopper, 0, seal_palette)
    if drawing.mark:
        (left, top), rows = drawing.mark
        for dy, row in enumerate(rows):
            for dx, key in enumerate(row):
                if key != ".":
                    point = (left + dx, top + dy)
                    assert icon.getpixel(point)[3] == 255, (family, variant, tier, point)
                    icon.putpixel(point, (*bytes.fromhex(palette[key][1:]), 255))
    return icon


def ranked(family):
    return not DRAWINGS[family][0].top


def filename(family, letter, tier):
    suffix = f"_t{tier}" if tier else ""
    return f"{family}_{letter}{suffix}.png"


def main():
    OUTPUT.mkdir(exist_ok=True)
    for family, choices in DRAWINGS.items():
        for index, drawing in enumerate(choices):
            assert len(drawing.body.split()) + drawing.start <= 16
            for tier in range(1, 7) if ranked(family) else (None,):
                icon = draw(family, index, tier)
                icon.save(OUTPUT / filename(family, chr(65 + index), tier))


if __name__ == "__main__":
    main()
