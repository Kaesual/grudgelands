#!/usr/bin/env python3
"""Original CC0 pixel art; deterministic Python/Pillow, no generated images.

Run python3 -B art/drop-02/src/paint.py. Writes only the 54 icons and notes.md
of each proposal. The 18 final drop-01 icons are deliberately never painted.
All contours are hand-authored integer pixels, all scaling is nearest-neighbor.
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
GAME = Path.home() / "projects/grudgelands"
PICKED = GAME / "tools/r54_art/art"
# r54_art adaptation (Round 55 lane ICONS): assemble.py passes --art <dir of the picked tiers.json>.
if "--art" in sys.argv:
    PICKED = Path(sys.argv[sys.argv.index("--art") + 1])
PREVIOUS = ROOT.parent / "drop-01"
LINES = ("metal", "leather", "cloth")
SLOTS = ("head", "chest", "legs", "feet")
KEPT = {("metal", "chest"), ("metal", "legs"), ("leather", "chest")}
ROWS = [(line, slot) for line in LINES for slot in SLOTS if (line, slot) not in KEPT]
HEX = dict(zip("hlmdeostAaBbG", (
    "F0F0F0", "C8C8C8", "A0A0A0", "787878", "505050", "282828",
    "A07850", "6E5034", "E07070", "B04848", "70A0E0", "4870B0", "FFC040")))
COLORS = {k: tuple(bytes.fromhex(v)) + (255,) for k, v in HEX.items()}


class Icon:
    """A hand-drawn contour with calm masses clipped to its interior."""
    def __init__(self, spans, base="m"):
        self.im = Image.new("RGBA", (16, 16))
        self.cells = {(x, y) for y, runs in spans.items() for lo, hi in runs for x in range(lo, hi+1)}
        self.inside = {p for p in self.cells if all((p[0]+dx, p[1]+dy) in self.cells
                      for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)))}
        for p in self.cells:
            self.im.putpixel(p, COLORS[base if p in self.inside else "o"])

    def rect(self, x0, y0, x1, y1, color, edge=False):
        for x, y in (self.cells if edge else self.inside):
            if x0 <= x <= x1 and y0 <= y <= y1:
                self.im.putpixel((x, y), COLORS[color])
        return self

    def poly(self, pts, color, edge=False):
        mask = Image.new("1", (16, 16))
        ImageDraw.Draw(mask).polygon(pts, fill=1)
        for p in (self.cells if edge else self.inside):
            if mask.getpixel(p):
                self.im.putpixel(p, COLORS[color])
        return self


def frontal_metal(t):
    # Rounded crown, open cheeks and a nasal; no closed ring under the chin.
    spans = {2: [(6, 9)], 3: [(4, 11)], 4: [(3, 12)], 5: [(2, 13)],
             6: [(2, 13)], 7: [(2, 13)]}
    for y in range(8, 13):
        spans[y] = [(2, 4), (11, 13)]
        if y <= 10:
            spans[y] += [(7, 8)]
    spans[13] = [(3, 4), (11, 12)]
    if t >= 3:
        spans[11] = spans[12] = [(2, 5), (10, 13)]
        spans[13] = [(3, 5), (10, 12)]
    if t == 6:
        spans[0] = spans[1] = [(7, 8)]
    f = Icon(spans)
    f.rect(3, 3, 11, 5, "l").rect(5, 3, 8, 3, "h", True)
    f.rect(12, 6, 12, 11, "d")
    f.rect(3, 6, 12, 6, "A")
    f.rect(3, 8, 3, 11, "l", True).rect(12, 8, 12, 11, "m", True)
    f.rect(7, 7, 7, 10, "l", True).rect(8, 7, 8, 10, "d", True)
    f.rect(6, 5, 8, 5, "B")
    if t >= 3:
        f.rect(3, 11, 4, 12, "l", True).rect(11, 11, 12, 12, "m", True)
    if t >= 5:
        f.rect(3, 7, 12, 7, "l", True)
        f.rect(3, 5, 12, 5, "d")
        f.rect(6, 5, 8, 5, "B")
    if t == 6:
        f.rect(7, 1, 7, 4, "B", True).rect(8, 1, 8, 4, "b", True)
    return f


def frontal_leather(t):
    # Domed sewn cap with ear flaps; the face is a broad bottom-open cutout.
    spans = {2: [(5, 10)], 3: [(3, 12)], 4: [(2, 13)], 5: [(2, 13)],
             6: [(2, 13)], 7: [(2, 13)], 8: [(2, 13)],
             9: [(2, 4), (11, 13)], 10: [(2, 4), (11, 13)],
             11: [(2, 4), (11, 13)], 12: [(3, 4), (11, 12)]}
    f = Icon(spans)
    f.rect(3, 3, 9, 5, "l").rect(11, 5, 12, 7, "d")
    f.rect(3, 7, 12, 7, "A")
    f.rect(3, 8, 3, 11, "m", True).rect(12, 8, 12, 11, "d", True)
    f.rect(6, 6, 8, 6, "B")
    if t >= 3:
        f.rect(3, 8, 12, 8, "s", True)
    if t >= 5:
        # A single broad crown panel suggests the upper-tier hide construction.
        f.poly([(4, 4), (6, 3), (9, 3), (11, 4), (10, 5), (5, 5)], "l")
        f.rect(6, 6, 8, 6, "B")
    if t == 6:
        f.rect(4, 8, 11, 8, "A", True)
    return f


def cloth_cap(t):
    # A soft folded cap: bent point on the right, round body, broad rolled cuff.
    # The two-pixel notch below the folded tip is intentional silhouette detail.
    spans = {1: [(8, 10)], 2: [(6, 11)], 3: [(5, 12)], 4: [(4, 12)],
             5: [(4, 8), (11, 13)], 6: [(3, 9), (11, 13)],
             7: [(3, 9)], 8: [(2, 10)], 9: [(2, 11)],
             10: [(2, 12)], 11: [(1, 13)], 12: [(1, 13)], 13: [(2, 12)]}
    f = Icon(spans)
    f.poly([(7, 3), (9, 3), (6, 6), (5, 9), (3, 9), (4, 6)], "l")
    f.rect(8, 8, 10, 10, "d")
    f.rect(12, 4, 12, 5, "m", True)
    f.rect(2, 11, 12, 12, "A")
    f.rect(10, 11, 12, 12, "a")
    f.rect(5, 11, 7, 11, "B")
    if t >= 3:
        f.rect(3, 10, 11, 10, "A")
    if t >= 5:
        f.rect(3, 12, 11, 12, "B")
    if t == 6:
        f.rect(6, 4, 7, 5, "l")
    return f


def profile_metal(t):
    # Right-facing plate helmet: rounded skull, brow and projecting nasal.
    spans = {2: [(5, 9)], 3: [(3, 11)], 4: [(2, 12)], 5: [(2, 13)],
             6: [(1, 13)], 7: [(1, 13)], 8: [(1, 8), (12, 13)],
             9: [(1, 7), (12, 13)], 10: [(1, 7), (12, 13)],
             11: [(2, 7)], 12: [(2, 7)], 13: [(3, 6)]}
    if t >= 3:
        spans[10] = [(1, 8), (12, 13)]
        spans[11] = [(2, 8)]
    if t >= 5:
        spans[6] = [(1, 14)]
        spans[7] = [(1, 14)]
        spans[8] = [(1, 7)]
        spans[9] = [(1, 14)]
        spans[10] = [(1, 13)]
        spans[11] = [(2, 12)]
        spans[12] = [(2, 10)]
        spans[13] = [(3, 8)]
    if t == 6:
        spans[0] = [(6, 8)]
        spans[1] = [(5, 9)]
    f = Icon(spans)
    f.poly([(4, 3), (9, 3), (11, 5), (3, 6), (2, 5)], "l")
    f.rect(4, 3, 7, 3, "h", True)
    f.rect(2, 7, 5, 10, "m").rect(6, 8, 7, 12, "d")
    f.rect(2, 6, 11, 6, "A")
    f.rect(12, 7, 12, 10, "l", True)
    f.rect(6, 7, 7, 8, "B", True)
    if t >= 5:
        f.poly([(8, 7), (14, 6), (14, 7), (10, 8)], "l", True)
        f.rect(11, 9, 13, 9, "l", True)
        f.rect(8, 10, 11, 11, "m", True)
        f.rect(4, 12, 8, 12, "a")
    if t == 6:
        f.rect(6, 1, 8, 2, "B", True)
    return f


def profile_leather(t):
    # Side of a hood: curved back, forward brow, a large open face and nape.
    spans = {2: [(5, 9)], 3: [(3, 10)], 4: [(2, 11)], 5: [(2, 12)],
             6: [(2, 12)], 7: [(2, 10)], 8: [(2, 8)],
             9: [(2, 7)], 10: [(2, 7)], 11: [(2, 7)],
             12: [(2, 7)], 13: [(3, 7)]}
    f = Icon(spans)
    f.poly([(4, 3), (9, 3), (11, 5), (9, 6), (3, 6)], "l")
    f.rect(3, 7, 4, 11, "m").rect(5, 8, 6, 12, "d")
    f.rect(8, 6, 11, 6, "A", True).rect(7, 7, 9, 7, "A", True)
    f.rect(6, 8, 7, 12, "A", True)
    f.rect(5, 8, 5, 10, "B")
    if t >= 3:
        f.rect(3, 5, 10, 5, "s")
    if t >= 5:
        f.rect(4, 4, 9, 5, "l")
        f.rect(5, 8, 6, 10, "B")
    if t == 6:
        f.rect(6, 11, 7, 12, "a", True)
    return f


def cloth_hat(t):
    # A bent pointed hat with a genuine horizontal brim, viewed from the front.
    spans = {1: [(9, 11)], 2: [(7, 11)], 3: [(6, 9)], 4: [(6, 9)],
             5: [(5, 10)], 6: [(5, 10)], 7: [(4, 11)], 8: [(4, 11)],
             9: [(3, 12)], 10: [(3, 12)], 11: [(1, 14)], 12: [(1, 14)],
             13: [(3, 12)]}
    f = Icon(spans)
    f.poly([(8, 3), (9, 3), (7, 8), (5, 8)], "l", True)
    f.poly([(9, 4), (11, 9), (9, 9), (8, 7)], "d")
    f.rect(4, 9, 11, 10, "A")
    f.rect(9, 9, 11, 10, "a")
    f.rect(7, 9, 8, 10, "B")
    f.rect(2, 11, 13, 11, "l", True)
    if t >= 3:
        f.rect(4, 8, 11, 8, "A")
    if t >= 5:
        f.rect(3, 12, 12, 12, "B")
    if t == 6:
        f.rect(6, 6, 7, 7, "l")
    return f


def cloth_chest(t, prop):
    # Deliberate T-shaped sleeves, neck notch and one broad central textile.
    spans = {1: [(4, 5), (10, 11)], 2: [(3, 5), (10, 12)],
             3: [(2, 13)], 4: [(1, 14)], 5: [(1, 14)],
             6: [(1, 14)], 7: [(1, 14)],
             8: [(1, 3), (5, 10), (12, 14)], 9: [(4, 11)],
             10: [(4, 11)], 11: [(4, 11)], 12: [(4, 11)],
             13: [(4, 11)], 14: [(4, 11)]}
    if prop == "p2":
        # A long-sleeved robe bodice, with a straight hem and two clear armpits.
        spans[7] = [(1, 14)]
        spans[8] = spans[9] = [(1, 2), (4, 11), (13, 14)]
        spans[10] = [(2, 2), (4, 11), (13, 13)]
        spans[11] = spans[12] = spans[13] = spans[14] = [(4, 11)]
    f = Icon(spans)
    f.rect(2, 3, 5, 6, "l").rect(5, 4, 6, 12, "l")
    f.rect(10, 4, 13, 8, "d")
    if prop == "p1":
        f.rect(6, 3, 9, 12, "A", True)
        f.rect(9, 6, 9, 12, "a")
        f.rect(6, 11, 9, 11, "B")
    else:
        f.rect(2, 6, 2, 9, "l", True).rect(13, 6, 13, 9, "d", True)
        f.poly([(5, 2), (9, 6), (7, 9), (5, 12), (5, 9), (7, 6), (4, 3)], "A", True)
        f.rect(6, 10, 9, 10, "B")
    if t >= 2:
        f.rect(5, 12, 10, 12, "A")
    if t >= 3:
        y = 7 if prop == "p1" else 9
        f.rect(2, y, 3, y, "A", True).rect(12, y, 13, y, "a", True)
    if t >= 5:
        f.rect(5, 13, 10, 13, "B")
    return f


def trousers(line, t, prop):
    # Modelled on the kept metal legs: broad waist and two straight equal legs.
    spans = {1: [(3, 12)]}
    for y in range(2, 8):
        spans[y] = [(2, 13)]
    for y in range(8, 14):
        spans[y] = [(2, 6), (9, 13)]
    spans[14] = [(3, 6), (9, 12)]
    if prop == "p2" and line == "cloth" and t >= 3:
        # Open robe panels over two legs, with a deep central split, never a cone.
        spans[8] = [(2, 6), (9, 13)]
        for y in range(9, 13):
            spans[y] = [(1, 6), (9, 14)]
        spans[13] = [(2, 6), (9, 13)]
    f = Icon(spans, "A" if line == "leather" and t == 1 else "m")
    f.rect(3, 2, 12, 3, "A")
    f.rect(10, 2, 12, 3, "a")
    f.rect(6, 2, 9, 2, "B")
    if line == "leather":
        f.rect(3, 4, 5, 12, "l").rect(10, 4, 12, 12, "m")
        f.rect(12, 5, 12, 12, "d")
        if t <= 2:
            f.rect(3, 9, 5, 11, "m").rect(10, 9, 12, 11, "d")
        elif prop == "p1":
            f.rect(3, 8, 5, 11, "s").rect(10, 8, 12, 11, "t")
        else:
            f.rect(4, 4, 4, 11, "s").rect(11, 4, 11, 11, "t")
        if t >= 5:
            f.rect(3, 9, 5, 11, "l").rect(10, 9, 12, 11, "l")
        if t == 6:
            f.rect(3, 4, 12, 5, "m")
            f.rect(3, 5, 12, 5, "l")
    else:
        f.rect(3, 4, 4, 12, "l").rect(11, 5, 12, 12, "d")
        f.rect(8, 4, 9, 6, "d")
        if t >= 3:
            f.rect(5, 4, 5, 12, "A").rect(10, 4, 10, 12, "a")
        if t >= 5:
            f.rect(3, 12, 5, 12, "B").rect(10, 12, 12, 12, "B")
        if prop == "p2" and t >= 3:
            f.rect(2, 9, 4, 11, "l").rect(11, 9, 13, 11, "d")
            f.rect(2, 12, 5, 12, "A", True).rect(10, 12, 13, 12, "a", True)
    return f


def boot(line, t, prop):
    # Classic right-facing boot: vertical back, narrow shaft, long toe, heel gap.
    top = 1 if line != "cloth" else 3
    spans = {y: [(2, 8)] for y in range(top, 10)}
    spans[9] = [(2, 9)]
    spans[10] = [(2, 12)]
    spans[11] = [(2, 14)]
    spans[12] = [(2, 14)]
    spans[13] = [(2, 14)]
    spans[14] = [(2, 5), (9, 13)]
    if line == "metal":
        spans[10] = [(2, 13)]
    elif line == "cloth":
        spans[11] = [(2, 13)]
        spans[14] = [(3, 5), (9, 13)]
    if t >= 3 or prop == "p2":
        spans[top] = spans[top+1] = spans[top+2] = [(1, 9)]
    f = Icon(spans)
    f.rect(3, top+1, 7, top+2, "A")
    f.rect(7, top+1, 8, top+2, "a")
    f.rect(3, top+3, 4, 11, "l")
    f.rect(7, top+3, 7, 9, "d")
    f.rect(3, 12, 13, 12, "m")
    f.rect(3, 13, 13, 13, "d", True)
    # One compact buckle, placed above the instep, connected to the upper.
    f.rect(5, 7, 6, 8, "B")
    if line == "metal":
        f.rect(3, top+3, 4, top+3, "h")
        f.rect(8, 11, 12, 11, "l")
        if t >= 4:
            f.rect(8, 10, 12, 10, "h", True)
            f.rect(8, 11, 13, 12, "l")
        if t == 6:
            f.rect(4, 4, 4, 9, "l")
    elif line == "leather":
        f.rect(5, 5, 6, 10, "m")
        f.rect(5, 7, 6, 8, "B")
        if t >= 3:
            f.rect(2, top+2, 8, top+2, "l", True)
        if t >= 5:
            f.rect(8, 11, 12, 11, "l")
    else:
        f.rect(3, 9, 6, 10, "l")
        if t <= 2:
            f.rect(3, 11, 12, 12, "s")
        if t >= 4:
            f.rect(8, 11, 12, 11, "A")
        if t >= 5:
            f.rect(8, 12, 12, 12, "B")
    if prop == "p2":
        f.rect(2, top+2, 8, top+2, "l", True)
        f.rect(3, top+1, 7, top+1, "A", True)
        f.rect(7, top+2, 8, top+2, "a", True)
    return f


IDEAS = {
    "p1": "Everyday silhouettes: a frontal nasal helmet, sewn leather cap and folded cloth cap above straight, symmetric trousers. Every boot faces right with a long foot and a separate heel; the cloth bodice has simple sleeves and a central stole. This proposal chooses familiar slot symbols, including trousers for every cloth tier.",
    "p2": "Profile heads and robe dress: metal and leather headgear face right like the boots; cloth uses a bent pointed hat with a broad brim. The cloth bodice has long sleeves and an overlapping collar, and T3-T6 legwear shows split robe panels with two visible legs. This is the more pictorial alternative, with the same frontal kept torsos and centred legwear.",
}
STEPS = {
    "p1": {
        "metal head": "T1-T2 round dome and nasal; T3-T4 broader cheeks; T5 a raised brow visor; T6 one short crest. The chin stays open.",
        "metal feet": "T1-T2 straight greave; T3 wider cuff; T4-T6 broad sabaton toe plate, with the existing palettes carrying the last steps.",
        "leather head": "T1-T2 sewn cap with ear flaps; T3-T4 bound brow; T5 broad crown panel; T6 stronger lining band.",
        "leather legs": "T1-T2 cloth with knee patches; T3-T4 broad hide patches; T5 knee guards; T6 one upper hide panel. All six retain two full trouser legs.",
        "leather feet": "T1-T2 plain hide boot; T3-T4 turned cuff; T5-T6 a broad reinforced toe. The buckle stays one compact fitting.",
        "cloth head": "T1-T2 soft folded cap with a rolled fabric cuff; T3-T4 deeper cuff; T5-T6 one broad cuff trim.",
        "cloth chest": "T1 straight tunic and stole; T2 lower sash; T3-T4 bound sleeves; T5-T6 one broad hem trim.",
        "cloth legs": "T1-T2 straight trousers; T3-T4 two quiet textile strips suggest the robe lining; T5-T6 bound hems. No added robe mass hides the leg gap.",
        "cloth feet": "T1-T2 cloth upper over hide foot; T3 folded cuff; T4 bound toe; T5-T6 continuous toe trim.",
    },
    "p2": {
        "metal head": "T1-T2 profile dome, brow and nasal; T3-T4 cheek extension; T5 projecting visor and chin plate; T6 a short crest.",
        "metal feet": "T1-T3 cuffed greave; T4-T6 a broad sabaton toe plate, with the existing palettes carrying the last steps.",
        "leather head": "T1-T2 hood in profile with an open face; T3-T4 brow binding; T5-T6 larger side clasp and crown panel.",
        "leather legs": "T1-T2 patched trousers; T3-T4 long hide bindings; T5 knee guards; T6 one upper panel. Full paired legs match the kept metal trousers.",
        "leather feet": "T1-T4 tall turned cuff; T5-T6 reinforced toe, with the same heel and long forward foot.",
        "cloth head": "T1-T2 bent pointed hat and fabric band; T3-T4 deeper band; T5-T6 a single continuous brim trim.",
        "cloth chest": "T1 long sleeves and overlapping collar; T2 sash; T3-T4 bound cuffs; T5-T6 a continuous lower trim.",
        "cloth legs": "T1-T2 trousers; T3-T4 split robe panels beside a deep central gap; T5-T6 bound panel hems. Two trouser ends remain visible.",
        "cloth feet": "T1-T2 turned cloth cuff over hide foot; T3 cloth upper; T4 bound toe; T5-T6 broad toe trim.",
    },
}


def main():
    tiers = json.loads((PICKED / "tiers.json").read_text())
    for prop in ("p1", "p2"):
        expected = set()
        for line, slot in ROWS:
            for t in range(1, 7):
                if slot == "head":
                    painter = {"p1": {"metal": frontal_metal, "leather": frontal_leather, "cloth": cloth_cap},
                               "p2": {"metal": profile_metal, "leather": profile_leather, "cloth": cloth_hat}}[prop][line]
                    im = painter(t).im
                elif slot == "chest":
                    im = cloth_chest(t, prop).im
                elif slot == "legs":
                    im = trousers(line, t, prop).im
                else:
                    im = boot(line, t, prop).im
                variant = tiers[line][f"T{t}"]["icon"][slot]
                assert variant == "abcdef"[t-1]
                pixels = [im.getpixel((x, y)) for y in range(16) for x in range(16)]
                assert set(pixels) <= set(COLORS.values()) | {(0, 0, 0, 0)}
                for zone, minimum in (("Aa", 6), ("Bb", 3)):
                    n = sum(p in (COLORS[zone[0]], COLORS[zone[1]]) for p in pixels)
                    assert n >= minimum, (prop, line, slot, t, zone, n)
                path = ROOT / prop / line / "icons" / f"{slot}_{variant}.png"
                path.parent.mkdir(parents=True, exist_ok=True)
                im.save(path, compress_level=9)
                expected.add(path)
        assert len(expected) == 54
        assert set((ROOT / prop).rglob("*.png")) == expected
        notes = [IDEAS[prop], ""]
        notes += [f"- {line} {slot}: {STEPS[prop][f'{line} {slot}']}" for line, slot in ROWS]
        notes += ["", "The three final rows (metal chest, metal legs, leather chest) are not included here and are never redrawn. The check copy uses their exact drop-01 P1 files. Zone A is fabric lining/binding; zone B is one fitting or broad trim. Original CC0 artwork; no palette or armor-sheet changes.", ""]
        (ROOT / prop / "notes.md").write_text("\n".join(notes))
    print("Painted 108 original 16x16 icons and two notes files; kept rows untouched.")


if __name__ == "__main__":
    main()
