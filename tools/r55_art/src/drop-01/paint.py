#!/usr/bin/env python3
"""Drop 01 original pixel art. Python standard library + Pillow; no random input.

Run: python3 -B art/drop-01/src/paint.py
Only writes the two proposals beside this source directory. inputs.json captures
the frozen sheet contract and the selected Round 54 metal colors, not artwork.
All pixel designs, including all inventory icons, are original and CC0.
"""
import copy
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
INPUT = json.loads((Path(__file__).parent / "inputs.json").read_text())
GRADES = INPUT["grades"]
NAMES = dict(zip("hlmdeostAaBbG", INPUT["reference"]))
# h/l/m/d/e/o = material ramp; s/t = wood/leather; A/a and B/b = zones.
COLORS = {ch: tuple(bytes.fromhex(INPUT["reference"][name][1:])) + (255,)
          for ch, name in NAMES.items()}
CELLS = {tuple(p) for p in INPUT["shield_cells"]}


def blank(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def rows(data):
    assert len({len(r) for r in data}) == 1, data
    im = blank((len(data[0]), len(data)))
    for y, row in enumerate(data):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), COLORS[ch])
    return im


def save(im, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=False, compress_level=9)


def tier_palettes(proposal):
    out = {}
    # Lacquer and cloth fields. Calm chroma, brighter metal at the perimeter.
    fields = (
        [("#A38B61", "#766346"), ("#875A50", "#593E39"),
         ("#627B89", "#3F5361"), ("#67738B", "#434E66"),
         ("#865245", "#573730"), ("#514863", "#302C42")],
        [("#8C7755", "#60523D"), ("#697263", "#444E43"),
         ("#596D72", "#39494F"), ("#596C80", "#394C61"),
         ("#67483E", "#442F2D"), ("#423D55", "#292638")],
    )[proposal - 1]
    book_fields = (
        [("#966B46", "#654831"), ("#68725B", "#424E3C"),
         ("#546C81", "#354A60"), ("#6B6583", "#47435F"),
         ("#875542", "#57382E"), ("#50445F", "#322B42")],
        [("#846346", "#594332"), ("#726354", "#4E453D"),
         ("#596A65", "#394C47"), ("#526475", "#344556"),
         ("#674A42", "#422F2E"), ("#413A52", "#292436")],
    )[proposal - 1]
    ribbons = ["#AC6453", "#A46955", "#B17B52", "#A75B63", "#D18E53", "#B7A0C7"]
    for t, grade in enumerate(GRADES):
        p = copy.deepcopy(INPUT["metal_palettes"][grade])
        p["name"] = grade.replace("_", " ").title()
        p["colors"].update(A_LIGHT=fields[t][0], A_DARK=fields[t][1],
                            ACC_LIGHT="#98734F", ACC_DARK="#5D4432")
        out[grade] = p
        metal = INPUT["metal_palettes"][grade]["colors"]
        # Paper does not become metal; the named grade appears in the fittings.
        out["book_" + grade] = {
            "name": grade.replace("_", " ").title() + " binding", "tier": "T" + str(t + 1),
            "colors": {
                "M_HI": "#F2E8CF", "M_LIGHT": "#D9CAA8", "M_MID": "#B7A587",
                "M_DARK": "#81735C", "M_DEEP": "#514735", "OUTLINE": "#2C2926",
                "ACC_LIGHT": "#A58259", "ACC_DARK": "#684B35",
                "A_LIGHT": book_fields[t][0], "A_DARK": book_fields[t][1],
                "B_LIGHT": metal["B_LIGHT"] if t >= 4 else metal["M_LIGHT"],
                "B_DARK": metal["B_DARK"] if t >= 4 else metal["M_DARK"],
                "GLOW": ribbons[t],
            },
        }
    return {"palettes": out}


def shield_front(proposal, tier):
    im = blank((11, 13))
    def put(x, y, c):
        if (x, y) in CELLS:
            im.putpixel((x, y), COLORS[c])
    for x, y in CELLS:
        edge = any((x + dx, y + dy) not in CELLS
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        c = "A" if x < 5 and y < 9 else "a"
        if edge:
            c = "l" if y == 0 else "m" if x < 5 else "d"
            if y >= 10:
                c = "d" if x < 5 else "e"
        put(x, y, c)
    if proposal == 1:
        # A narrow blade-like ridge over an uninterrupted painted field.
        for y in range(1, 12):
            put(5, y, "l" if y < 7 else "m")
        if tier >= 2:
            for x in (1, 9):
                put(x, 1, "B"); put(x, 2, "b")
        if tier >= 3:
            for x in range(2, 9):
                put(x, 1, "l" if x < 6 else "m")
            for x in (1, 9):
                put(x, 8, "B")
        if tier >= 4:
            # One clear chevron at the foot, not a field full of micro-symbols.
            for x, y in ((2, 8), (3, 9), (4, 10), (5, 11), (6, 10), (7, 9), (8, 8)):
                put(x, y, "B" if x <= 5 else "b")
        if tier >= 5:
            for x in range(1, 10):
                put(x, 2, "B" if x < 6 else "b")
            for y in range(3, 8):
                put(1, y, "m"); put(9, y, "d")
            for x in (3, 7):
                put(x, 1, "B")
        if tier == 6:
            # A continuous coronet and doubled ceremonial foot, no extra shape.
            for x in (2, 5, 8):
                put(x, 0, "B"); put(x, 1, "B")
            for x, y in ((2, 9), (3, 10), (4, 11), (5, 12), (6, 11), (7, 10), (8, 9)):
                put(x, y, "m" if x <= 5 else "d")
            for y in (3, 7, 8):
                put(4, y, "B"); put(6, y, "b")
    else:
        # Structural ironwork: a wider spine, then a belt, then a boss frame.
        for y in range(1, 12):
            put(4, y, "m"); put(5, y, "l"); put(6, y, "d")
        if tier >= 2:
            for x in range(1, 10):
                put(x, 7, "m" if x < 5 else "d")
            for x in (1, 9):
                put(x, 7, "B")
        if tier >= 3:
            for x in (1, 9):
                put(x, 1, "B"); put(x, 2, "b")
                put(x, 9, "b")
        if tier >= 4:
            for x, y in ((3, 4), (4, 3), (5, 2), (6, 3), (7, 4),
                         (3, 6), (4, 7), (5, 8), (6, 7), (7, 6)):
                put(x, y, "l" if x < 6 and y < 6 else "m")
        if tier >= 5:
            for y in (1, 2):
                for x in range(2, 9):
                    put(x, y, "m" if y == 2 else "l")
            for x in (2, 8):
                put(x, 3, "B")
            for x in range(3, 8):
                put(x, 10, "m" if x < 6 else "d")
        if tier == 6:
            for x in (1, 2, 8, 9):
                put(x, 1, "B" if x < 6 else "b")
            # Join the diamond into one broad escutcheon. Solid steps avoid
            # isolated light/dark squares at character distance.
            for y in range(3, 8):
                half = 2 if y in (3, 7) else 3
                for x in range(5 - half, 6 + half):
                    put(x, y, "m" if x < 5 else "d")
            for x in range(3, 8):
                put(x, 3, "B" if x <= 5 else "b")
            for y in (4, 5, 6):
                put(2, y, "B"); put(8, y, "b")
            for x in range(3, 8):
                put(x, 7, "b")
    # The real square pyramid is at rows 4..6; every visible boss texel is B.
    for y in range(4, 7):
        for x in range(4, 7):
            put(x, y, "B" if y == 4 or (x == 4 and y == 5) else "b")
    put(5, 5, "B")
    return im


def shield_sheet(proposal, tier):
    im = blank((22, 13)); im.paste(shield_front(proposal, tier), (0, 0))
    for x, y in CELLS:
        edge = any((x + dx, y + dy) not in CELLS
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        # Calm wooden planks, two leather arm loops; darker loop at the grip.
        c = "s" if x not in (3, 7) else "t"
        if y >= 10:
            c = "t"
        if edge:
            c = "d"
        if (x in (2, 3, 7, 8) and 3 <= y <= 7):
            c = "t" if x in (2, 7) else "o"
        if y in (3, 7) and x in (2, 3, 7, 8):
            c = "t"
        if x in (4, 5, 6) and y in (5, 6):
            c = "o" if y == 6 else "t"
        if tier >= 3 and y in (2, 8) and x in (2, 8):
            c = "b"
        if tier >= 5 and y in (1, 9) and 2 <= x <= 8:
            c = "d"
        im.putpixel((11 + x, y), COLORS[c])
    return im


def cover_face(proposal, tier, back=False):
    im = rows(["AAAAa", "AAAAa", "AAAAa", "AAAAa", "aaaaa", "aaaaa"])
    px = im.load()
    def p(x, y, c):
        px[x, y] = COLORS[c]
    # Three discreet hardware texels on each T1 outer cover meet the zone rule.
    if proposal == 1:
        for x, y in ((4, 0), (4, 2), (4, 5)):
            p(x, y, "B" if y < 3 else "b")
        if tier >= 2:
            p(0, 0, "B"); p(0, 5, "b")
        if tier >= 3:
            for y in range(1, 5):
                p(0, y, "b")
        if tier >= 4:
            p(2, 2, "B"); p(2, 3, "b")
        if tier >= 5:
            for x in range(5):
                p(x, 0, "B"); p(x, 5, "b")
        if tier == 6:
            # A long seal, with broad uninterrupted leather on either side.
            p(2, 1, "B"); p(2, 4, "b")
    else:
        # A broad strap across the cover makes the relic line different at T1.
        for x in range(5):
            p(x, 2, "t")
        for y in (1, 2, 3):
            p(4, y, "B" if y < 3 else "b")
        if tier >= 2:
            p(0, 0, "B"); p(4, 0, "B")
        if tier >= 3:
            p(0, 5, "b"); p(4, 5, "b")
            p(2, 2, "B")
        if tier >= 4:
            p(3, 2, "B"); p(3, 3, "b")
        if tier >= 5:
            for x in (0, 1, 3, 4):
                p(x, 0, "B"); p(x, 5, "b")
        if tier == 6:
            # Complete the two rails and the fore-edge clasp, leaving the
            # center leather calm instead of alternating isolated fittings.
            p(2, 0, "B"); p(2, 5, "b")
            for y in (1, 3, 4):
                p(4, y, "b")
    return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if back else im


def page_face(proposal, tier, right=False):
    # Four by five. Two separated text lines; no tiny letters or texture noise.
    data = ["hhhl", "lddl", "hhhl", "ldhl", "llll"]
    if proposal == 1:
        if tier >= 3:
            data[0] = "Ghhl"  # rubricated initial
        if tier >= 5:
            data[3] = "lddl"
        if tier == 6:
            data[4] = "lBll"  # a single illuminator's seal
    else:
        if tier >= 3:
            data[0] = "Ghhl"
        if tier >= 4 and right:
            data = ["hGhl", "hdhl", "dddl", "hdhl", "llll"]
        if tier >= 6 and right:
            data = ["hBhl", "hddl", "BhdB", "hddl", "lBll"]
    im = rows(data)
    return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if right else im


def book_sheet(proposal, tier, box):
    w, h, faces = INPUT["sheets"][box]
    im = blank((w, h))
    for face, (fx, fy, fw, fh) in faces.items():
        if box.startswith("cover"):
            outside = (box, face) in (("cover_f", "front"), ("cover_b", "back"))
            if outside:
                f = cover_face(proposal, tier, box == "cover_b")
            else:
                f = Image.new("RGBA", (fw, fh), COLORS["a"])
                if face == "top":
                    f = Image.new("RGBA", (fw, fh), COLORS["A"])
                if face == "bottom":
                    f = Image.new("RGBA", (fw, fh), COLORS["a"])
                if tier >= 5 and face in ("top", "bottom"):
                    f.putpixel((fw - 1, 0), COLORS["B" if face == "top" else "b"])
        elif box.startswith("pages"):
            readable = (box, face) in (("pages_f", "back"), ("pages_b", "front"))
            if readable:
                f = page_face(proposal, tier, box == "pages_b")
            else:
                f = Image.new("RGBA", (fw, fh), COLORS["l" if face == "top" else "m"])
                if face == "left":
                    for y in range(fh):
                        f.putpixel((0, y), COLORS["l" if y % 2 == 0 else "m"])
        elif box == "spine":
            f = Image.new("RGBA", (fw, fh), COLORS["a"])
            if face == "right":
                for y in ((1, 4) if tier >= 3 else (2,)):
                    f.putpixel((0, y), COLORS["b" if tier >= 3 else "t"])
                if tier == 6:
                    f.putpixel((0, 0), COLORS["B"])
        else:
            f = Image.new("RGBA", (fw, fh), COLORS["G"])
            if face == "right":
                f = Image.new("RGBA", (fw, fh), COLORS["a"])
            if tier >= 4 and face != "bottom":
                f.putpixel((0, fh - 1), COLORS["B" if tier >= 5 else "b"])
        assert f.size == (fw, fh)
        im.paste(f, (fx, fy))
    return im


def shield_icon(proposal, tier):
    # Original front silhouette: straight top, long shoulders, pointed foot.
    # The silhouette stays consistent with the geometry, independent of tier.
    im = blank((16, 16)); dr = ImageDraw.Draw(im)
    outline = [(2, 1), (12, 1), (12, 8), (11, 10), (7, 14), (3, 10), (2, 8)]
    dr.polygon(outline, fill=COLORS["o"])
    front = shield_front(proposal, tier)
    for y in range(12):
        for x in range(9):
            # Draw original icon paint using the same design language at 9x12.
            if (y <= 7 or abs(x - 4) <= (11 - y)):
                sx = round(x * 10 / 8); sy = round(y * 12 / 11)
                c = front.getpixel((sx, sy))
                if c[3]:
                    im.putpixel((3 + x, 2 + y), c)
    # Boss remains legible at 16 px; upper face catches the light.
    for x, y, c in ((7, 6, "B"), (6, 7, "B"), (7, 7, "B"), (8, 7, "b"), (7, 8, "b")):
        im.putpixel((x, y), COLORS[c])
    return im


def book_icon(proposal, tier):
    if proposal == 1:
        # An oblique open notebook, paper above a clearly visible leather lip.
        im = rows([
            "................", "................", "...oooo.........", "..ohhhhoo.oooo..",
            ".olhhhhhoohhhho.", ".olhddhhohhhhlAo", ".olhhhhhohddhlAo", ".olhddhhohhhhlAo",
            ".olhhhhhohddhlAo", ".oAlllllohhhhlAo", "..oAAAAGollllAAo", "...ooaaGoAAAAoo.",
            ".....ooGoaaoo...", ".......Gooo.....", ".......G........", "................",
        ])
    else:
        # A front-facing, open grimoire: two calm pages over a heavier binding.
        im = rows([
            "................", "..ooooo.ooooo...", ".oAAAAAoAAAAAo..", ".oAllllollllAo..",
            ".oAhhhhohhhhAo..", ".oAhddhohddhAo..", ".oAhhhhohhhhAo..", ".oAhddhohddhAo..",
            ".oAhhhhohhhhAo..", ".oAllllollllAo..", ".oaaaaaGaaaaao..", "..oooooGooooo...",
            ".......G........", ".......G........", ".......G........", "................",
        ])
    p = im.load()
    # Fittings follow the same progression as the tiny physical covers.
    if proposal == 1:
        p[13, 5] = COLORS["B"]; p[13, 9] = COLORS["b"]
        if tier >= 2:
            p[2, 8] = COLORS["b"]
        if tier >= 3:
            p[3, 9] = COLORS["B"]; p[4, 10] = COLORS["b"]
            p[4, 4] = COLORS["G"]
        if tier >= 4:
            p[12, 10] = COLORS["B"]
        if tier >= 5:
            p[11, 11] = COLORS["b"]; p[12, 11] = COLORS["b"]
            p[13, 10] = COLORS["B"]
        if tier == 6:
            p[3, 3] = COLORS["B"]; p[12, 3] = COLORS["B"]
            p[7, 14] = COLORS["B"]
    else:
        p[2, 6] = COLORS["B"]; p[12, 6] = COLORS["B"]
        if tier >= 2:
            p[2, 2] = COLORS["B"]; p[12, 2] = COLORS["B"]
        if tier >= 3:
            p[2, 10] = COLORS["b"]; p[12, 10] = COLORS["b"]
            p[4, 4] = COLORS["G"]
        if tier >= 4:
            for x, y in ((10, 5), (9, 6), (10, 6), (11, 6), (10, 7)):
                p[x, y] = COLORS["d"]
        if tier >= 5:
            for x in (3, 4, 10, 11):
                p[x, 2] = COLORS["B"]; p[x, 10] = COLORS["b"]
        if tier == 6:
            for x, y in ((10, 4), (9, 6), (11, 6), (10, 8), (7, 14)):
                p[x, y] = COLORS["B"]
    return im


def cloak_pair(proposal):
    # Color bands use the same row coordinate on cloak and wings, including
    # their lining. Hinge texels match exactly: the pieces are a single garment.
    palette = ({"body": "#303E53", "light": "#3D4D62", "fold": "#283447",
                "lining": "#242D3C", "trim": "#9E8960", "darktrim": "#75674E",
                "mark": "#C2AE7B"} if proposal == 1 else
               {"body": "#34463E", "light": "#405449", "fold": "#293A33",
                "lining": "#26342E", "trim": "#A0987D", "darktrim": "#756F5C",
                "mark": "#BEB18F"})
    c = {k: tuple(bytes.fromhex(v[1:])) + (255,) for k, v in palette.items()}
    def band(y, lining=False):
        if y == 29:
            return c["darktrim"]
        if y == 30:
            return c["trim"]
        if y == 31:
            return c["fold"]
        if lining:
            return c["lining"]
        if y <= (3 if proposal == 1 else 5):
            return c["light"]
        return c["body"]
    cloak = blank((32, 32))
    for y in range(32):
        for x in range(32):
            color = band(y, x >= 16)
            if x < 16 and 5 < y < 29:
                if x in (3, 12):
                    color = c["fold"]
                elif x in (4, 11):
                    color = c["light"]
            cloak.putpixel((x, y), color)
    d = ImageDraw.Draw(cloak)
    if proposal == 1:
        # A single small seed/lozenge: early contributions carried forward.
        for x, y in ((7, 19), (8, 19), (6, 20), (9, 20), (6, 21), (9, 21),
                     (7, 22), (8, 22), (7, 23), (8, 23)):
            cloak.putpixel((x, y), c["trim"])
        cloak.putpixel((7, 20), c["mark"])
        cloak.putpixel((7, 21), c["mark"])
    else:
        # Paired mending stitches beneath a restrained shoulder yoke.
        d.line((2, 6, 13, 6), fill=c["darktrim"])
        for x in (6, 9):
            d.line((x, 20, x, 24), fill=c["trim"])
        d.line((5, 21, 10, 21), fill=c["mark"])
        d.line((5, 23, 10, 23), fill=c["darktrim"])
    wings = blank((16, 32))
    for y in range(32):
        for k in range(8):
            # Any positive overlap with the fixed triangle is painted, including
            # the sloping edge's partly sampled texels. No alpha cutouts.
            if k * 4 < y + 1:
                wings.putpixel((7 - k, y), band(y))
                wings.putpixel((8 + k, y), band(y, True))
    return cloak, wings


SHIELD_STEPS = {
    1: ["Plain lacquered field, narrow bronze rim, small boss; wood and two leather loops behind.",
        "Adds paired shoulder rivets and restrained iron reinforcement.",
        "Adds a full brow plate and lower anchors; the physical shield grows to 0.92.",
        "Adds a silver chevron at the foot, giving the field a heraldic base.",
        "Adds a broad brow fitting and heavier side rails; the physical shield grows to 1.0.",
        "Adds a three-point coronet, doubled foot and boss brackets; dark noble lacquer holds the bright fittings."],
    2: ["Plain lacquer beneath a broad raised metal spine; small boss and wooden back.",
        "Adds a horizontal reinforcing belt with two large fasteners.",
        "Adds shoulder plates and lower anchors; the physical shield grows to 0.92.",
        "Adds a continuous diamond frame around the boss.",
        "Adds a heavy brow and foot plate; the physical shield grows to 1.0.",
        "Joins the boss frame into a broad solid escutcheon with wide corner caps; calm lacquer remains around it."],
}
BOOK_STEPS = {
    1: ["Plain leather notebook, three small fittings on each cover, two quiet script lines and a plain ribbon.",
        "Adds spine-side corner protection to the notebook.",
        "Adds a bound spine edge, two spine bands and a rubricated initial.",
        "Adds a central cover seal and a small ribbon end fitting.",
        "Adds continuous head and foot plates and a second complete script line.",
        "Extends the cover seal into a long vertical plate and adds an illuminated page seal and crowned spine."],
    2: ["Plain leather folio with a broad closing strap and a three-texel clasp on each cover.",
        "Adds two upper corner caps to protect the travelling volume.",
        "Adds lower corner caps, a strap buckle, spine bands and a rubricated initial.",
        "Expands the buckle to a broad clasp and introduces a diagram on the right page.",
        "Adds wide paired corner plates and a metal ribbon end.",
        "Joins the corner plates into head and foot rails with a full fore-edge clasp, and illuminates the diagram's four cardinal marks."],
}


def notes(proposal):
    idea = ("P1 — Standard & Ledger\n\nBroad heraldic fields and a slender ridge grow from a mercenary's shield into a coroneted standard. The scholar's notebook gains careful binding and illumination; the midnight Supporter mantle carries a quiet seed emblem and a continuous bronze hem." if proposal == 1 else
            "P2 — Brace & Seal\n\nA broad metal spine grows into a reinforced frame around four calm lacquer panels. The strapped folio becomes a clasped grimoire; the pine Supporter mantle honors repeated contributions with a pair of mending stitches and a continuous pewter hem.")
    lines = [idea, "", "Progression", ""]
    for item, steps in (("Shield", SHIELD_STEPS[proposal]), ("Book", BOOK_STEPS[proposal])):
        for t, desc in enumerate(steps, 1):
            lines.append(f"- {item} T{t} ({GRADES[t - 1]}): {desc}")
    lines += ["", "- Supporter cloak: one premium tier; matching body/wing hinge colors, matching lining, and a hem that continues across all three pieces.",
              "", "Origin and license", "",
              "All art in this proposal is original and dedicated to CC0 1.0, including all six shield icons and all six book icons. Icons were drawn freely, not adapted: no source pixels, traced outlines or source-image imports are used. The existing gear icons and achievement cloaks were inspected only as style references.",
              "", "The shield material ramps reuse the selected Round 54 metal palette names and colors, with new lacquer colors and natural wood/leather accents. Book palettes use separate book_<grade> names so their parchment stays parchment; fittings share the grade's metal colors. A is exclusively the painted field/binding, B is hardware or illumination, and GLOW is a flat-color ribbon accent, not an emissive effect.",
              "", "Reproduce both proposals: python3 -B art/drop-01/src/paint.py. Every painted PNG is generated by that deterministic script using src/inputs.json; no image model or randomness is involved.", ""]
    return "\n".join(lines)


def main():
    for proposal in (1, 2):
        out = ROOT / f"p{proposal}"
        tiers = {"shield": {}, "book": {}}
        for tier, grade in enumerate(GRADES, 1):
            v = chr(96 + tier)
            save(shield_sheet(proposal, tier), out / "shield" / f"{v}.png")
            for box in INPUT["sheets"]:
                save(book_sheet(proposal, tier, box), out / "book" / f"{box}_{v}.png")
            save(shield_icon(proposal, tier), out / "icons" / f"shield_{v}.png")
            save(book_icon(proposal, tier), out / "icons" / f"book_{v}.png")
            for item in tiers:
                tiers[item][f"T{tier}"] = {"palette": grade if item == "shield" else "book_" + grade,
                                          "variant": v, "icon": v}
        cloak, wings = cloak_pair(proposal)
        save(cloak, out / "cloak_supporter.png")
        save(wings, out / "wings_supporter.png")
        (out / "tiers.json").write_text(json.dumps(tiers, indent=2) + "\n")
        (out / "palettes.json").write_text(json.dumps(tier_palettes(proposal), indent=2) + "\n")
        (out / "notes.md").write_text(notes(proposal))
        print(f"p{proposal}: 56 original PNGs, tiers.json, palettes.json, notes.md")


if __name__ == "__main__":
    main()
