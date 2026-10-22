#!/usr/bin/env python3
"""Write the painting templates (spec docs/technical/armor-format.md).

  python3 templates.py [--out templates]

templates/boxes/<box>.png     the box sheet at 8x: each face a tinted, labelled
                              rectangle with a pixel grid; hatched texels can be
                              covered by another catalog box when both are worn;
                              legend with orientations and the covering boxes.
templates/inner/<slot>.png    the 64x32 skin at 8x: the slot's region bright, the
                              rest dimmed, every face of head/torso/arm/leg
                              labelled, over a faint human skin.
templates/palette.png         the 13 reference colours with index, name, hex.
templates/blank/<box>.png     exact-size transparent box sheets to paint into;
templates/blank/inner_<slot>.png, templates/blank/icon.png likewise.
templates/parts/<part>.png    a polygon part's sheet at 8x (Round 56, spec
                              section 1a): each face's rect tinted, the polygon
                              outlined, the bleed texels (inside the rect,
                              outside the polygon) hatched; legend with each
                              face's orientation; templates/blank/<part>.png.
"""
import argparse
import shutil
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

import armorlib as L  # noqa: E402
import check  # noqa: E402  (coverage geometry)

S = 8
FACE_TINT = {"top": (250, 226, 160), "bottom": (205, 190, 150), "right": (170, 205, 245),
             "front": (180, 235, 180), "left": (245, 185, 185), "back": (215, 190, 240)}
ORIENT = {
    "top": "seen from above: row 0 = BACK edge, column 0 = character's right",
    "bottom": "seen from below: row 0 = FRONT edge, column 0 = character's right",
    "right": "character's RIGHT side (-x), seen from outside: column 0 = back, row 0 = top",
    "front": "column 0 = character's RIGHT, row 0 = top",
    "left": "character's LEFT side (+x), seen from outside: column 0 = front, row 0 = top",
    "back": "seen from behind: column 0 = character's LEFT, row 0 = top",
}


def font(n):
    return ImageFont.load_default(size=n)


def may_cover(cat):
    """{box id: ({sheet texel}, [(covering box, faces)])}: texels another catalog box covers when both
    are worn (any box may be worn on any tier, so this is catalog-wide)."""
    cov, _ = check.coverage(cat)
    out = {b["id"]: (set(), []) for b in cat["boxes"]}
    for (a, bid), e in sorted(cov.items()):
        for faces in e["faces"].values():
            out[bid][0].update(faces)
        out[bid][1].append((a, sorted(e["faces"])))
    return out


def grid_image(w, h, cells, labels, hatched=frozenset(), base=None):
    """cells: {(x, y): rgb}; labels: [(x, y, w, h, text)] in texels; returns the 8x image."""
    im = Image.new("RGB", (w * S + 1, h * S + 1), (255, 255, 255))
    d = ImageDraw.Draw(im)
    for y in range(h):
        for x in range(w):
            c = cells.get((x, y))
            if c is None:
                # outside every face: light checker = must stay transparent
                c = (238, 238, 238) if (x + y) % 2 else (226, 226, 226)
            d.rectangle([x * S, y * S, x * S + S - 1, y * S + S - 1], fill=c)
            if (x, y) in hatched:
                for k in range(0, S, 3):
                    d.line([(x * S + k, y * S), (x * S, y * S + k)], fill=(120, 120, 120))
                    d.line([(x * S + S - 1, y * S + k), (x * S + k, y * S + S - 1)], fill=(120, 120, 120))
    for x in range(w + 1):
        d.line([(x * S, 0), (x * S, h * S)], fill=(200, 200, 200))
    for y in range(h + 1):
        d.line([(0, y * S), (w * S, y * S)], fill=(200, 200, 200))
    f = font(10)
    for x0, y0, fw, fh, text, short in labels:
        d.rectangle([x0 * S, y0 * S, (x0 + fw) * S, (y0 + fh) * S], outline=(40, 40, 40), width=2)
        for t in (text, short):
            if d.textlength(t, font=f) + 5 <= fw * S and fh * S >= 13:
                d.rectangle([x0 * S + 2, y0 * S + 2, x0 * S + 3 + d.textlength(t, font=f), y0 * S + 13],
                            fill=(255, 255, 255))
                d.text((x0 * S + 3, y0 * S + 2), t, fill=(20, 20, 20), font=f)
                break
    return im


SHORT = {"top": "T", "bottom": "Bt", "right": "R", "front": "F", "left": "L", "back": "B",
         "outer": "O", "inner": "I", "right side": "R", "left side": "L"}


def wrap(text, n=118):
    out, cur = [], ""
    for w in text.split(" "):
        if cur and len(cur) + 1 + len(w) > n:
            out.append(cur)
            cur = "    " + w
        else:
            cur = (cur + " " + w) if cur else w
    return out + [cur]


def compose(title, lines, body):
    f = font(13)
    width = max(body.width + 24, 760)
    lh = 17
    head = 30
    im = Image.new("RGB", (width, head + body.height + 16 + lh * len(lines) + 10), (250, 249, 246))
    d = ImageDraw.Draw(im)
    d.text((10, 7), title, fill=(10, 10, 10), font=font(15))
    im.paste(body, (12, head))
    y = head + body.height + 12
    for ln in lines:
        d.text((12, y), ln, fill=(40, 40, 40), font=f)
        y += lh
    return im


def compose_wrapped(title, lines, body):
    return compose(title, [w for ln in lines for w in wrap(ln)], body)


def box_templates(cat, out):
    hid = may_cover(cat)
    for b in cat["boxes"]:
        SW, SH = b["sheet"]
        W, H, D = b["texels"]
        cells, labels = {}, []
        for face, (fx, fy, fw, fh) in b["faces"].items():
            for y in range(fy, fy + fh):
                for x in range(fx, fx + fw):
                    cells[(x, y)] = FACE_TINT[face]
            labels.append((fx, fy, fw, fh, face, SHORT[face]))
        hatched, covers = hid[b["id"]]
        window = L.open_window(b)
        for xy in window:
            cells[xy] = (255, 255, 255)       # white: the helm's face window, the only texels that may stay open
        chin = L.chin_row(b)
        for xy in chin:
            cells[xy] = (200, 230, 255)       # pale blue: the chin strip, open on cloth and leather T1-T5
        body = grid_image(SW, SH, cells, labels, hatched)
        used = sorted({ln + " " + t for ln in L.LINES for t, T in cat["tiers"][ln].items() if b["id"] in T["on"]})
        rot = f", rotated {b['rot'][1]} deg about {b['rot'][0]}" if b["rot"] else ""
        lines = [
            f"sheet {SW}x{SH} px = 2d+2w by d+h; texels w {W} (x), h {H} (y), d {D} (z); box size "
            f"{b['size'][0]:g} x {b['size'][1]:g} x {b['size'][2]:g} skin px{rot}",
            f"slot {b['slot']}, bone {b['bone']}" + ("; MIRRORED: the left copy shows this sheet mirrored "
                                                    "(paint the right-hand copy)" if b["mirror"] else ""),
        ] + [f"{face:6s} at ({fx},{fy}) {fw}x{fh}: {ORIENT[face]}" for face, (fx, fy, fw, fh) in b["faces"].items()] + [
            "every face texel must be opaque (no transparency in armor)" + (
                "; WHITE = the face window: these texels may stay transparent (the face shows through)" if window
                else "") + ("; PALE BLUE = the chin strip (Round 56 ruling 17): transparent on every cloth head piece "
                            "and on leather T1-T5, opaque on leather T6 (the veil) and metal" if chin else
                            "") + "; light checker = outside the faces, must stay transparent; hatched = another box covers these texels "
            "when both are worn (hidden wherever the cover is opaque; check.py's overlap report has the details "
            "for your tiers.json)",
            "can be covered by: " + ("; ".join(f"{a} ({', '.join(f)})" for a, f in covers) or "nothing"),
            "any box may be worn on any tier; the example selection (tiers_example.json) wears it in: " +
            (", ".join(used) if used else "no tier"),
        ]
        compose_wrapped(f"{b['id']} - {b['label_en']} ({b['label']})", lines, body).save(out / "boxes" / f"{b['id']}.png")
        Image.new("RGBA", (SW, SH), (0, 0, 0, 0)).save(out / "blank" / f"{b['id']}.png")


def part_templates(cat, out):
    """The polygon parts' sheets at 8x: each face's rect tinted, the texels whose centre lies inside the polygon
    brighter, the bleed hatched, the polygon outlined (spec §1a)."""
    tints = [(250, 226, 160), (170, 205, 245), (245, 185, 185), (180, 235, 180), (215, 190, 240),
             (205, 190, 150), (160, 225, 220), (240, 205, 170)]
    for p in cat.get("parts", []):
        SW, SH = p["sheet"]
        cells, labels, bleed = {}, [], set()
        for i, f in enumerate(p["polys"]):
            fx, fy, fw, fh = f["rect"]
            poly = f["uv"]
            for y in range(fy, fy + fh):
                for x in range(fx, fx + fw):
                    cells[(x, y)] = tints[i % len(tints)]
                    if not inside(poly, (x + 0.5, y + 0.5)):
                        bleed.add((x, y))
            labels.append((fx, fy, fw, fh, f["name"], f["name"].split(".")[-1][:1].upper()))
        body = grid_image(SW, SH, cells, labels, bleed)
        d = ImageDraw.Draw(body)
        for f in p["polys"]:
            pts = [(u * S, v * S) for u, v in f["uv"]]
            d.line(pts + pts[:1], fill=(200, 0, 120), width=2)
        used = sorted({ln + " " + t for ln in L.LINES for t, T in cat["tiers"][ln].items() if p["id"] in T["on"]})
        lines = [f"polygon part, sheet {SW}x{SH} px (spec section 1a); slot {p['slot']}, bone {p['bone']}; "
                 f"worn only together with the {p['shell']} (it closes the part); file <line>/{p['id']}_<variant>.png",
                 "every texel of every face's rect must be opaque when the part is worn: HATCHED texels lie outside "
                 "the polygon (magenta outline) and are bleed, painted like their neighbours so a diagonal edge never "
                 "samples a transparent texel; light checker = outside every rect, must stay transparent; a tier "
                 "that does not wear the part leaves the whole sheet transparent (metal: ruling 15)"]
        for f in p["polys"]:
            fx, fy, fw, fh = f["rect"]
            n = f["normal"]
            where = ("up" if n[1] > 0.954 else "down" if n[1] < -0.954 else
                     " ".join(w for w, c in (("right", -n[0]), ("left", n[0]), ("front", n[2]), ("back", -n[2]),
                                             ("up", n[1]), ("down", -n[1])) if c > 0.3))
            top = ("row 0 = BACK edge" if n[1] > 0.954 else "row 0 = FRONT edge" if n[1] < -0.954 else
                   "row 0 = top")
            lines.append(f"{f['name']:8s} at ({fx},{fy}) {fw}x{fh}: faces {where}; seen from outside, columns run "
                         f"to the viewer's right, {top}")
        lines.append("the example selection wears it in: " + (", ".join(used) if used else "no tier (cloth and "
                     "leather tiers name it in their tiers.json 'on' list, always with the helm)"))
        compose_wrapped(f"{p['id']} - {p['label_en']} ({p['label']})", lines, body).save(out / "parts" / f"{p['id']}.png")
        Image.new("RGBA", (SW, SH), (0, 0, 0, 0)).save(out / "blank" / f"{p['id']}.png")


def inside(poly, q):
    """Is the point q inside the convex polygon (any winding)?"""
    sign = 0
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        c = (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0])
        if abs(c) < 1e-9:
            continue
        if sign == 0:
            sign = 1 if c > 0 else -1
        elif (c > 0) != (sign > 0):
            return False
    return True


SKIN_PARTS = [  # name, uv origin, (w, h, d), note for the right/left faces
    ("head", (0, 0), (8, 8, 8), ("right side", "left side")),
    ("hat", (32, 0), (8, 8, 8), ("right side", "left side")),
    ("torso", (16, 16), (8, 12, 4), ("right side", "left side")),
    ("arm", (40, 16), (4, 12, 4), ("outer", "inner")),
    ("leg", (0, 16), (4, 12, 4), ("outer", "inner")),
]


def skin_faces(u, v, w, h, d):
    return {"top": (u + d, v, w, d), "bottom": (u + d + w, v, w, d), "right": (u, v + d, d, h),
            "front": (u + d, v + d, w, h), "left": (u + d + w, v + d, d, h), "back": (u + 2 * d + w, v + d, w, h)}


def inner_templates(cat, out):
    skin = L.load_rgba(L.DATA / "skins" / "human_bald.png")
    for slot in L.INNER_SLOTS:
        allowed = L.skin_region_mask(cat, slot)
        cells, labels = {}, []
        sp = skin.load()
        for y in range(32):
            for x in range(64):
                r, g, b_, a = sp[x, y]
                grey = (r + g + b_) // 3 if a else 235
                if (x, y) in allowed:
                    cells[(x, y)] = (int(150 + grey * 0.25), int(205 + grey * 0.15), int(150 + grey * 0.25))
                else:
                    cells[(x, y)] = (int(90 + grey * 0.25),) * 3
        for name, (u, v), (w, h, d), (rn, ln) in SKIN_PARTS:
            for face, rect in skin_faces(u, v, w, h, d).items():
                nm = {"right": rn, "left": ln}.get(face, face)
                labels.append(rect + (f"{name} {nm}", SHORT[nm]))
        body = grid_image(64, 32, cells, labels)
        regs = cat["slots"][slot]["inner_regions"]
        lines = [
            f"slot {slot}: paint ONLY in the green region " + ", ".join(f"({a},{b})-({c},{e})" for a, b, c, e in regs) +
            " (end exclusive); everything else transparent",
            "classic 64x32 skin layout over a faint human skin; the left arm and leg show the right ones mirrored",
            "arm/leg 'outer' = the right limb's outer side (-x); front column 0 = the character's right",
            "the inner paint is drawn on the body under the worn boxes; the race skin shows where it is transparent",
        ]
        if slot == "chest":
            lines.append("the 4x4 corners left of the top faces and right of the bottom faces are never visible")
        if slot == "legs":
            lines.append("rows 20-27 = the top of the leg to mid-calf; the leg's top/bottom faces (rows 16-19) "
                         "belong to no slot")
        if slot == "feet":
            lines.append("rows 28-31 = the lowest four rows of the leg (the sole, rows 16-19, belongs to no slot)")
        lines.append("short labels: T top, Bt bottom, F front, B back, R / L the character's right / left side, "
                     "O / I the limb's outer / inner side")
        compose_wrapped(f"inner paint - {slot}", lines, body).save(out / "inner" / f"{slot}.png")
        Image.new("RGBA", (64, 32), (0, 0, 0, 0)).save(out / "blank" / f"inner_{slot}.png")
    Image.new("RGBA", (16, 16), (0, 0, 0, 0)).save(out / "blank" / "icon.png")


def palette_sheet(out):
    rows = L.REFERENCE
    im = Image.new("RGB", (760, 40 + 34 * len(rows)), (250, 249, 246))
    d = ImageDraw.Draw(im)
    d.text((10, 10), "reference palette: paint only these 13 colours plus full transparency (alpha 0 or 255)",
           fill=(10, 10, 10), font=font(14))
    for i, (idx, name, hx, meaning) in enumerate(rows):
        y = 40 + i * 34
        d.rectangle([10, y, 70, y + 28], fill=L.hex_rgb(hx), outline=(60, 60, 60))
        d.text((80, y + 6), f"{idx:2d}  {name:9s} {hx}   {meaning}", fill=(20, 20, 20), font=font(13))
    im.save(out / "palette.png")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(L.TOOL / "templates"))
    a = ap.parse_args()
    out = Path(a.out)
    if out.exists():
        shutil.rmtree(out)
    for sub in ("boxes", "inner", "blank", "parts"):
        (out / sub).mkdir(parents=True)
    cat = L.load_catalog()
    box_templates(cat, out)
    part_templates(cat, out)
    inner_templates(cat, out)
    palette_sheet(out)
    print("wrote", out, sum(1 for _ in out.rglob("*.png")), "png")


if __name__ == "__main__":
    main()
