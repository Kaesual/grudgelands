#!/usr/bin/env python3
"""Write the offhand painting templates (Round 55 lane VIEWER; the format is
docs/technical/offhand-format.md section 6).

Everything is derived from params.json, data/atlas.json and the shipped
player model, so a re-tune regenerates the templates:

  templates/shield.png          the shield sheet at 8x: front left, back right,
                                the outline, the ridge column, the boss base,
                                every texel that must be opaque (darker: the
                                rim and the slanted edges sample it), which way
                                each edge points on the character
  templates/book_<box>.png      each book box sheet at 8x, every face labelled
                                with what it is on the open book; faces that
                                count for the zone minimum marked
  templates/wings.png           the 16 x 32 wing texture at 8x: the sampled
                                triangles, hinge and outer corner
  templates/cloak.png           the cloak's 32 x 32 layout at 8x: outer face,
                                lining, the edges, where the wings hinge
  templates/palette.png         Round 54's reference palette
  templates/blank/*.png         every sheet at its exact size, transparent

Hatched texels were not seen in a visibility pass of the shipped model (26
directions round the item in Stand, mid-walk and the item's pose; the body
opaque, no armor): hidden by the item itself, the hand or the body.

  python3 templates.py            rewrite templates/
  python3 templates.py --check    exit 1 if templates/ is stale (pixels)
"""
import argparse
import importlib.util
import shutil
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
TOOL = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL))

from PIL import Image, ImageDraw  # noqa: E402

import render as R  # noqa: E402  (the model, the visibility pass; imports offhand, bake, armorlib)

O, B, G, L = R.O, R.B, R.G, R.L
OUT = TOOL / "templates"
S = 8                                     # pixels per texel


def r54_templates():
    """Round 54's templates.py (grid_image, compose_wrapped, palette_sheet)."""
    spec = importlib.util.spec_from_file_location("r54_templates", R.ROOT / "tools/r54_armor/templates.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


T54 = r54_templates()
FACE_TINT = T54.FACE_TINT
ZONE_TINT = (255, 214, 120)               # a face that counts for the zone minimum
CUT = 0.62                                # a crossed texel: the face tint darkened


def darker(c, k=CUT):
    return tuple(int(v * k) for v in c)


def direction(v):
    """Where a catalog direction points on the character, in words."""
    names = (("the character's left (away from the body)", "the character's right (towards the body)"),
             ("up", "down"), ("forwards (the face)", "backwards"))
    order = sorted(range(3), key=lambda k: -abs(v[k]))
    main = names[order[0]][0 if v[order[0]] > 0 else 1]
    if abs(v[order[1]]) > 0.35:
        main += ", a little %s" % names[order[1]][0 if v[order[1]] > 0 else 1].split(" (")[0]
    return main


def to_px(col, row, x0=0):
    return ((x0 + col) * S, row * S)


# --- shield ---------------------------------------------------------------------------
def shield_template(model, params, atlas, out):
    shape, boss = params["shield"]["shape"], params["shield"].get("boss")
    poly, lv = O.shield_outline(shape)
    Wt, Ht = O.texels(shape["width"]), O.texels(shape["height"])
    sheets = atlas["sheets"]
    frames = [model.frame(p) for p in ("stand", "walk", "block")]
    seen = set()                           # sheet texels seen on any size copy
    for step in range(len(params["shield"]["sizes"])):
        sid = "shield_%d" % step
        sel = {"offhand": model.sheet_tris("offhand", [sheets[sid]["rect"]], atlas["size"])}
        ox, oy = sheets[sid]["rect"][:2]
        seen |= {(x - ox, y - oy) for x, y in R.seen_texels(model, sel, frames, atlas["size"])}
    cells, hatched = {}, set()
    for side, x_off in (("front", 0), ("back", Wt)):
        tint = FACE_TINT["front" if side == "front" else "back"]
        opaque = O.shield_texels(shape, side)
        for cx, cy in opaque:
            # a border texel (a neighbour outside the outline or the sheet): the rim samples it
            border = any((cx + dx, cy + dy) not in opaque for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            cells[(x_off + cx, cy)] = darker(tint) if border else tint
            if (x_off + cx, cy) not in seen:
                hatched.add((x_off + cx, cy))
    body = T54.grid_image(2 * Wt, Ht, cells, [], hatched)
    d = ImageDraw.Draw(body)

    def at(side, x, y):
        col = (x + lv["W"]) / (2 * lv["W"]) * Wt if side == "front" else (lv["W"] - x) / (2 * lv["W"]) * Wt
        return ((col + (0 if side == "front" else Wt)) * S, (lv["T"] - y) / shape["height"] * Ht * S)

    by = (lv["T"] + lv["B"]) / 2 + (lv["T"] - (lv["T"] + lv["B"]) / 2) * (boss["lift"] if boss else 0)
    for side in ("front", "back"):
        d.line([at(side, x, y) for x, y in poly + poly[:1]], fill=(200, 20, 20), width=2)
        top, bottom = at(side, 0, lv["T"]), at(side, 0, lv["B"])
        for k in range(int(top[1]), int(bottom[1]), 6):        # the ridge, dashed
            d.line([(top[0], k), (top[0], min(k + 3, bottom[1]))], fill=(20, 60, 200), width=2)
        if boss and side == "front":
            r = boss["radius"]
            d.rectangle([at(side, -r, by + r), at(side, r, by - r)], outline=(160, 0, 160), width=2)
    T54_font = T54.font(11)
    for side, x_off in (("front", 0), ("back", Wt)):
        d.rectangle([x_off * S + 2, 2, x_off * S + 4 + d.textlength(side.upper(), font=T54_font), 15],
                    fill=(255, 255, 255))
        d.text((x_off * S + 3, 2), side.upper(), fill=(20, 20, 20), font=T54_font)
    pl = params["shield"]["place"]
    Rm = O.euler(pl["rot"], pl["order"])
    col = [tuple(Rm[i][k] for i in range(3)) for k in range(3)]     # the item's axes in the catalog frame
    sizes = params["shield"]["sizes"]
    steps = params["shield"]["tier_step"]
    lines = [
        "sheet %dx%d px: FRONT columns 0-%d, BACK columns %d-%d; one sheet for every size step "
        "(%s; tiers %s): a bigger tier shows the same texels bigger"
        % (2 * Wt, Ht, Wt - 1, Wt, 2 * Wt - 1, ", ".join("x%g" % s for s in sizes),
           ", ".join("T%s step %d" % kv for kv in sorted(steps.items()))),
        "FRONT: seen from the front (the outside), column 0 = the shield's left edge as you look at it, row 0 = the "
        "top. BACK: seen from behind (the arm side), so column %d = the same edge as the front's last column" % Wt,
        "on the character at rest (Stand): the front faces %s; seen from the front, column 0 points %s and the "
        "last column %s; the top points %s" % (direction(col[2]), direction(tuple(-c for c in col[0])),
                                                direction(col[0]), direction(col[1])),
        "red line = the outline; blue dashes = the ridge (the front bulges %g px along it; the back follows it); "
        "purple square = the boss's base (a %g px pyramid on the front, painted with the texels under it)"
        % (shape["ridge"], boss["height"] if boss else 0) if boss else
        "red line = the outline; blue dashes = the ridge (the front bulges %g px along it)" % shape["ridge"],
        "tinted = must be OPAQUE (every texel the outline contains or crosses); darker = the border texels: the "
        "rim (%g px thick) and the slanted edges sample them, so they colour the shield's edge too; light checker "
        "= never sampled, leave transparent" % shape["thick"],
        "zones: at least 6 zone A and 3 zone B texels on the FRONT (the bake counts the front's opaque texels)",
        "hatched = not seen on any size copy in the visibility pass (Stand, mid-walk, Block; 26 directions): hidden "
        "by the arm or the shield itself; paint it, but plainly",
    ]
    T54.compose_wrapped("shield - %s" % ("form with boss" if boss else "form"), lines, body).save(out / "shield.png")
    Image.new("RGBA", (2 * Wt, Ht), (0, 0, 0, 0)).save(out / "blank" / "shield.png")


# --- book -----------------------------------------------------------------------------
BOOK_MEANING = {
    ("cover_f", "front"): ("front cover, OUTSIDE", "COVER"),
    ("cover_f", "back"): ("front cover, inside: shows as the margin round the left page", "in"),
    ("cover_f", "left"): ("front cover's fore-edge", "edge"),
    ("cover_f", "right"): ("front cover's spine edge (next to the spine)", "sp"),
    ("cover_f", "top"): ("front cover's top edge", "T"),
    ("cover_f", "bottom"): ("front cover's bottom edge", "Bt"),
    ("cover_b", "back"): ("back cover, OUTSIDE", "COVER"),
    ("cover_b", "front"): ("back cover, inside: shows as the margin round the right page", "in"),
    ("cover_b", "left"): ("back cover's fore-edge", "edge"),
    ("cover_b", "right"): ("back cover's spine edge (next to the spine)", "sp"),
    ("cover_b", "top"): ("back cover's top edge", "T"),
    ("cover_b", "bottom"): ("back cover's bottom edge", "Bt"),
    ("pages_f", "back"): ("the LEFT page, readable (row 0 = the page top, column 0 = its outer edge)", "LEFT"),
    ("pages_f", "left"): ("fore-edge of the left page block (the page edges)", "edge"),
    ("pages_f", "right"): ("gutter edge of the left page block: lines the groove between the halves", "gut"),
    ("pages_f", "top"): ("top edge of the left page block", "T"),
    ("pages_f", "bottom"): ("bottom edge of the left page block", "Bt"),
    ("pages_b", "front"): ("the RIGHT page, readable (row 0 = the page top, column 0 = the gutter)", "RIGHT"),
    ("pages_b", "left"): ("fore-edge of the right page block (the page edges)", "edge"),
    ("pages_b", "right"): ("gutter edge of the right page block: lines the groove between the halves", "gut"),
    ("pages_b", "top"): ("top edge of the right page block", "T"),
    ("pages_b", "bottom"): ("bottom edge of the right page block", "Bt"),
    ("spine", "right"): ("spine OUTSIDE (lies on the palm)", "OUT"),
    ("spine", "left"): ("spine inside: closes the groove between the open halves from behind", "in"),
    ("spine", "front"): ("spine's side beside the front cover's spine edge", "f"),
    ("spine", "back"): ("spine's side beside the back cover's spine edge", "b"),
    ("spine", "top"): ("head of the spine (top end)", "T"),
    ("spine", "bottom"): ("tail of the spine (bottom end)", "Bt"),
    ("ribbon", "front"): ("ribbon, front side", "F"),
    ("ribbon", "back"): ("ribbon, back side", "B"),
    ("ribbon", "left"): ("ribbon, fore-edge side", "L"),
    ("ribbon", "right"): ("ribbon, spine side", "R"),
    ("ribbon", "bottom"): ("ribbon's end", "Bt"),
}
# armor-format.md section 4 orientation in the book's closed frame (x = towards the
# fore-edge, y = up, z = towards the front half), each face seen from outside
BOOK_ORIENT = {
    "front": "column 0 = the spine side, row 0 = the top",
    "back": "seen from behind: column 0 = the fore-edge side, row 0 = the top",
    "right": "the spine side: column 0 = the back half, row 0 = the top",
    "left": "the fore-edge side: column 0 = the front half, row 0 = the top",
    "top": "from above: column 0 = the spine side, row 0 = the back half",
    "bottom": "from below: column 0 = the spine side, row 0 = the front half",
}


def book_templates(model, params, atlas, out):
    sheets = atlas["sheets"]
    frames = [model.frame(p) for p in ("stand", "walk", "cast1")]
    sel = {"offhand": model.sheet_tris("offhand", [sheets[b]["rect"] for b in O.BOOK_BOXES], atlas["size"])}
    seen = R.seen_texels(model, sel, frames, atlas["size"])
    counted = set(B.BOOK_SEEN)
    shape = params["book"]["shape"]
    for box in O.BOOK_BOXES:
        x0, y0, w, h = sheets[box]["rect"]
        faces = B.local_faces(sheets[box])
        cells, hatched, labels = {}, set(), []
        for face, (fx, fy, fw, fh) in faces.items():
            zone = (box, face) in counted
            for y in range(fy, fy + fh):
                for x in range(fx, fx + fw):
                    cells[(x, y)] = ZONE_TINT if zone else FACE_TINT[face]
                    if (x0 + x, y0 + y) not in seen:
                        hatched.add((x, y))
            text, short = BOOK_MEANING[(box, face)]
            labels.append((fx, fy, fw, fh, short, short[:2]))
        body = T54.grid_image(w, h, cells, labels, hatched)
        lines = ["sheet %dx%d px (the classic box unwrap of armor-format.md section 4 in the closed book's axes); "
                 "every face texel must be opaque; light checker = outside the faces" % (w, h)]
        for face, (fx, fy, fw, fh) in faces.items():
            text, _ = BOOK_MEANING[(box, face)]
            n = sum((x0 + x, y0 + y) in seen for x in range(fx, fx + fw) for y in range(fy, fy + fh))
            lines.append("%-6s at (%d,%d) %dx%d: %s%s - %s; seen %d/%d" % (
                face, fx, fy, fw, fh, text, " [ZONES COUNT HERE]" if (box, face) in counted else "",
                BOOK_ORIENT[face], n, fw * fh))
        if O.BOOK_SKIP.get(box):
            lines.append("no texels for the %s face (the model leaves it out: it lies against another box)"
                         % " and ".join(O.BOOK_SKIP[box]))
        lines += [
            "gold = a face that counts for the zone minimum (per tier at least 6 zone A and 3 zone B texels on the "
            "covers' outsides and the two readable pages together)",
            "the open book: the halves stand %g deg apart (each %g deg from the spine's plane); seen by the "
            "reader the front half (cover_f, pages_f) is on the LEFT, the back half (cover_b, pages_b) on the RIGHT"
            % (shape["open"], shape["open"] / 2),
            "hatched = not seen in the visibility pass (Stand, mid-walk, Cast 1; 26 directions round the book, the "
            "body opaque): hidden by the hand or the book itself; paint it, but plainly",
        ]
        T54.compose_wrapped("book - %s" % box, lines, body).save(out / ("book_%s.png" % box))
        Image.new("RGBA", (w, h), (0, 0, 0, 0)).save(out / "blank" / ("book_%s.png" % box))


# --- wings and cloak ----------------------------------------------------------------------
def tri_cells(tri, size):
    """Texels a UV triangle (texel coords) overlaps with positive area."""
    xs, ys = [p[0] for p in tri], [p[1] for p in tri]
    out = set()
    for y in range(max(0, int(min(ys))), min(size[1], int(max(ys)) + 1)):
        for x in range(max(0, int(min(xs))), min(size[0], int(max(xs)) + 1)):
            if O._clip_area(tri, x, y, x + 1, y + 1) > 1e-6:
                out.add((x, y))
    return out


def wings_template(model, params, out):
    tw, th = O.WINGS_SIZE
    uv = model.uv[model.tris[R.SLOTS.index("wings")]] * (tw, th)
    outer, lining, edge = set(), set(), set()
    for tri in {tuple(map(tuple, t.round(4))) for t in uv}:
        (ax, ay), (bx, by), (cx, cy) = tri
        area = abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay))
        if area < 1e-6:                    # an edge quad: a line along the outer face's border texels
            for a, b in ((0, 1), (1, 2), (0, 2)):
                for k in range(65):
                    t = k / 64
                    x, y = (tri[a][0] + (tri[b][0] - tri[a][0]) * t, tri[a][1] + (tri[b][1] - tri[a][1]) * t)
                    edge.add((min(tw - 1, int(x)), min(th - 1, int(y))))
            continue
        cells = tri_cells(list(tri), (tw, th))
        (outer if sum(p[0] for p in tri) / 3 < tw / 2 else lining).update(cells)
    cells = {p: FACE_TINT["back"] for p in outer}
    cells.update({p: FACE_TINT["front"] for p in lining})
    cells.update({p: darker(FACE_TINT["back"]) for p in edge if p in outer})
    half = tw // 2
    labels = [(0, 0, half, 3, "OUTER", "O"), (half, 0, half, 3, "LINING", "L")]
    body = T54.grid_image(tw, th, cells, labels)
    d = ImageDraw.Draw(body)
    for c, r in ((half - 1, 0), (half - 1, th - 1), (0, th - 1), (half, 0), (half, th - 1), (tw - 1, th - 1)):
        d.ellipse([c * S + 1, r * S + 1, c * S + S - 2, r * S + S - 2], outline=(200, 20, 20), width=2)
    w = params["wings"]
    lines = [
        "16x32 px, the texture of one cloak (wings_<id>.png next to cloak_<id>.png); not palette-swapped, not baked",
        "columns 0-%d: the LEFT wing's OUTER face seen from behind; the hinge (on the cloak's side) is column %d, "
        "rows 0-%d top to hem; the outer corner is column 0, row %d" % (half - 1, half - 1, th - 1, th - 1),
        "columns %d-%d: its LINING seen from the front; the hinge is column %d, the outer corner column %d, row %d"
        % (half, tw - 1, half, tw - 1, th - 1),
        "tinted = sampled (the triangle on and below the diagonal); darker = also the wing's two thin edges (the "
        "bottom and the slanted edge sample the outer face's border texels); light checker = never sampled",
        "the right wing shows the same texels mirrored; red circles: hinge top, hinge at the hem, outer corner",
        "on the model: %g px wide, turned %g deg towards the body's side, %g px thick, from the hem up to %g px "
        "below the cloak's top" % (w["width"], w["angle"], w["thick"], w["drop"]),
    ]
    T54.compose_wrapped("wings (cloak wings, optional)", lines, body).save(out / "wings.png")
    Image.new("RGBA", O.WINGS_SIZE, (0, 0, 0, 0)).save(out / "blank" / "wings.png")


def cloak_template(params, out):
    cells = {}
    for y in range(32):
        for x in range(32):
            cells[(x, y)] = FACE_TINT["back"] if x < 16 else FACE_TINT["front"]
    for y in range(32):
        cells[(0, y)] = cells[(15, y)] = darker(FACE_TINT["back"])
    for x in range(16):
        cells[(x, 0)] = cells[(x, 31)] = darker(FACE_TINT["back"])
    body = T54.grid_image(32, 32, cells, [(0, 1, 16, 3, "OUTER (from behind)", "O"),
                                          (16, 1, 16, 3, "LINING (from front)", "L")])
    d = ImageDraw.Draw(body)
    top, length = G.TOP / G.PX, G.LENGTH / G.PX              # skin px: shoulders, length
    w = params["wings"]
    hinge_top = top - w["drop"]
    r0 = max(0, int((top - hinge_top) / length * 32))
    for c in (0, 15):
        d.line([(c * S + S // 2, r0 * S), (c * S + S // 2, 32 * S)], fill=(200, 20, 20), width=3)
    # the Scout's weapon card on the cloak, in outer-face texels
    pl = params["back"]["cloak"]
    half = params["back"]["size"] / 2
    pts = [O.place(pl, (sx * half, sy * half, 0)) for sx in (-1, 1) for sy in (-1, 1)]
    hw = O.CLOAK_HALF_W
    cols = [(hw - p[0]) / (2 * hw) * 16 for p in pts]
    rows = [(top - p[1]) / length * 32 for p in pts]
    box = [max(0, min(cols)) * S, max(0, min(rows)) * S, min(16, max(cols)) * S, min(32, max(rows)) * S]
    for k in range(int(box[0]), int(box[2]), 6):
        d.line([(k, box[1]), (min(k + 3, box[2]), box[1])], fill=(20, 60, 200), width=2)
        d.line([(k, box[3]), (min(k + 3, box[2]), box[3])], fill=(20, 60, 200), width=2)
    for k in range(int(box[1]), int(box[3]), 6):
        d.line([(box[0], k), (box[0], min(k + 3, box[3]))], fill=(20, 60, 200), width=2)
        d.line([(box[2], k), (box[2], min(k + 3, box[3]))], fill=(20, 60, 200), width=2)
    lines = [
        "32x32 px (cloak_<id>.png), the cloak's own format (character_visuals.md section 5b): not baked, not "
        "palette-swapped",
        "columns 0-15: the OUTER face seen from behind, column 0 = the character's LEFT, row 0 = the shoulders, row "
        "31 = the hem; columns 16-31: the LINING seen from the front, column 16 = the character's right",
        "darker = the cloak's thin edges take the outer face's border texels (column 0: the left side, column 15: the "
        "right side, row 0: the top, row 31: the hem); keep the outer face opaque (transparent texels are holes)",
        "red lines = the wings' hinges (column 0: the left wing, column 15: the right wing, rows %d-31): a cloak "
        "with wings_<id>.png grows a wing on each side there; the side faces cover the seam" % r0,
        "blue dashes = where the Scout's weapon card hangs over the cloak (back.cloak in params.json, %g px, the "
        "item image is mostly transparent)" % params["back"]["size"],
    ]
    T54.compose_wrapped("cloak (32 x 32 layout)", lines, body).save(out / "cloak.png")
    Image.new("RGBA", (32, 32), (0, 0, 0, 0)).save(out / "blank" / "cloak.png")


# --- main -----------------------------------------------------------------------------
def write(out):
    if out.exists():
        shutil.rmtree(out)
    (out / "blank").mkdir(parents=True)
    params, atlas, _ = B.load_contract()
    model = R.Model()
    shield_template(model, params, atlas, out)
    book_templates(model, params, atlas, out)
    wings_template(model, params, out)
    cloak_template(params, out)
    T54.palette_sheet(out)
    Image.new("RGBA", O.ICON_SIZE, (0, 0, 0, 0)).save(out / "blank" / "icon.png")


def same(a, b):
    with Image.open(a) as x, Image.open(b) as y:
        return x.mode == y.mode and x.size == y.size and x.tobytes() == y.tobytes()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare with templates/ instead of writing")
    ap.add_argument("--out", default=str(OUT))
    a = ap.parse_args()
    out = Path(a.out)
    if not a.check:
        write(out)
        print("templates: wrote %s (%d png)" % (out, sum(1 for _ in out.rglob("*.png"))))
        return 0
    with tempfile.TemporaryDirectory(prefix="r55-templates-") as tmp:
        fresh = Path(tmp) / "templates"
        write(fresh)
        want = sorted(p.relative_to(fresh) for p in fresh.rglob("*.png"))
        have = sorted(p.relative_to(out) for p in out.rglob("*.png")) if out.exists() else []
        problems = ["missing %s" % p for p in want if p not in have]
        problems += ["extra %s" % p for p in have if p not in want]
        problems += ["differs %s" % p for p in want if p in have and not same(fresh / p, out / p)]
    for p in problems:
        print("FAIL", p)
    print("templates check: %s (%d files)" % ("FAIL, run python3 tools/r55_offhand/templates.py" if problems
                                              else "ok", len(want)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
