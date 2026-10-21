#!/usr/bin/env python3
"""Test of render.py on the offhand test art (Round 55 lane VIEWER).

  python3 tools/r55_offhand/test_render.py      exit 1 on a failure

Follows the live params.json (no pinned position). Proves: the model's
triangles wind as the renderer culls them; every tier's offhand layer and icon
equal bake.py's own output; the shield alone, flat lit, shows every inner front
texel from the front and every inner back texel from behind in its painted
tier colour (so the F and B glyphs read unmirrored); on the character the
shield's front shows from the character's left; the cloak card shows when a
cloak is worn, the body card when none is, and the body card hides under a
cloak; a cloak wing shows its wing texture's texel; missing art is a checker
and listed; a tiers.json without some tiers or an item renders those as a
checker, listed; a render is deterministic; a whole sheet renders; the
README's painter table gives the live sheet sizes.
"""
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
TOOL = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL))

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

import render as R  # noqa: E402

O, B, L = R.O, R.B, R.L
FAILS = []


def ok(cond, what):
    if not cond:
        FAILS.append(what)


ART = TOOL / "test_art"
MODEL = R.Model()
A = R.Art(ART)
REF = {L.hex_rgb(h): n for _, n, h, _ in L.REFERENCE}


def art_names(path):
    im = Image.open(path).convert("RGBA")
    return {(x, y): REF[im.getpixel((x, y))[:3]] for y in range(im.height) for x in range(im.width)
            if im.getpixel((x, y))[3]}


def pixel(img, xy):
    return img.getpixel((int(xy[0]), int(xy[1])))[:3]


def test_winding():
    """-cross(v1 - v0, v2 - v0) of every triangle points along the vertex normals."""
    data = R.MODEL.read_bytes()
    root = R.G.parse(data, 0, len(data))
    vrts = R.G.kid(R.G.kid(R.G.find_node(root, "Player"), "MESH"), "VRTS")
    n = (len(vrts.raw) - 12) // 32
    normals = np.frombuffer(vrts.raw, "<f4", n * 8, 12).reshape(n, 8)[:, 3:6] * R.FLIP
    for slot, tris in zip(R.SLOTS, MODEL.tris):
        p = MODEL.rest[tris]
        out = -np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
        good = np.einsum("ij,ij->i", out, normals[tris[:, 0]]) > 0
        ok(good.all(), "winding: %d of %d %s triangles face inwards" % ((~good).sum(), len(tris), slot))


def test_layers_equal_bake():
    files, icons = B.bake(ART, icons=True)
    for item in ("shield", "book"):
        for n, tid in enumerate(L.TIER_IDS):
            grade = A.grades[n]
            layer, icon, missing = A.layer(item, tid)
            ok(not missing, "layer %s %s: unexpected missing %s" % (item, tid, missing))
            want = files[O.layer_file(item, grade)]
            ok(layer.tobytes() == want.tobytes(), "layer %s %s differs from bake.py's" % (item, tid))
            want = icons[O.icon_file(item, grade)]
            ok(icon.tobytes() == want.tobytes(), "icon %s %s differs from bake.py's" % (item, tid))


def test_shield_alone():
    """Flat front and back views of every size step: each inner texel shows its painted colour."""
    shape = A.params["shield"]["shape"]
    _, lv = O.shield_outline(shape)
    Wt, Ht = O.texels(shape["width"]), O.texels(shape["height"])
    names = art_names(ART / "shield" / "a.png")
    for step_tid in ("T1", "T3", "T6"):
        layer, _, _ = A.layer("shield", step_tid)
        colors = A.colors(A.tiers["shield"][step_tid]["palette"])
        sel, local = R.item_positions(MODEL, A, "shield", step_tid)
        tris = R.triangles(MODEL, 0, {"offhand": layer}, select=sel, positions=local)
        pts = local[MODEL.tris[R.SLOTS.index("offhand")][sel["offhand"]].ravel()]
        for side, dirv, x_off in (("front", (0, 0, 1), 0), ("back", (0, 0, -1), Wt)):
            target, dist, fov = R.near_ortho(pts, dirv)
            img = R.render_view(tris, dirv, 420, 420, target, dist, fov, flat=True)
            inside = O.shield_texels(shape, side)
            checked = bad = 0
            for cx, cy in inside:
                if any((cx + dx, cy + dy) not in inside for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    continue                       # border texels: the rim's business
                u = (cx + 0.5) / Wt
                x = -lv["W"] + 2 * lv["W"] * u if side == "front" else lv["W"] - 2 * lv["W"] * u
                y = lv["T"] - (cy + 0.5) / Ht * shape["height"]
                z = O.shield_front_z(shape, x) - (0 if side == "front" else shape["thick"])
                xy = R.screen_point((x, y, z), dirv, 420, 420, target, dist, fov)
                want = L.hex_rgb(colors[names[(x_off + cx, cy)]])
                checked += 1
                bad += pixel(img, xy) != want
            ok(checked > 20 and bad == 0, "shield %s %s alone: %d of %d inner texels off their colour"
               % (step_tid, side, bad, checked))


def test_shield_on_character():
    """From the character's left (Stand, flat) the shield's front glyph texels show."""
    shape = A.params["shield"]["shape"]
    _, lv = O.shield_outline(shape)
    Wt, Ht = O.texels(shape["width"]), O.texels(shape["height"])
    names = art_names(ART / "shield" / "a.png")
    tid = "T6"
    layer, _, _ = A.layer("shield", tid)
    colors = A.colors(A.tiers["shield"][tid]["palette"])
    step = O.tier_step(A.params, 6)
    scale = A.params["shield"]["sizes"][step]
    look = R.Look(A, "human")
    tris = R.triangles(MODEL, 0, look.textures(layer))
    w, h = 440, 600
    img = R.render_view(tris, R.VIEWS["left"][0], w, h, R.FULL["target"], R.FULL["dist"], flat=True)
    glyph = [(cx, cy) for (cx, cy), n in names.items() if n == "OUTLINE" and cx < Wt and 0 < cx < Wt - 1
             and 0 < cy < Ht - 1]
    hits = 0
    for cx, cy in glyph:
        x = -lv["W"] + 2 * lv["W"] * (cx + 0.5) / Wt
        y = lv["T"] - (cy + 0.5) / Ht * shape["height"]
        rest = O.place(A.params["shield"]["place"], (x, y, O.shield_front_z(shape, x)), scale)
        p = MODEL.carry("Offhand_Shield", 0, rest)
        xy = R.screen_point(p, R.VIEWS["left"][0], w, h, R.FULL["target"], R.FULL["dist"])
        hits += pixel(img, xy) == L.hex_rgb(colors["OUTLINE"])
    ok(len(glyph) >= 5 and hits >= len(glyph) - 1,
       "shield on the character from the left: %d of %d front glyph texels show" % (hits, len(glyph)))


def card_pixel(cloak, half, bone, card, view="back"):
    """The colour at a back card's centre (flat, Stand) with a red image in one half."""
    img16 = Image.new("RGBA", (16, 16), (230, 20, 20, 255))
    back = R.back_texture(img16, half == "cloak")
    look = R.Look(A, "human")
    tex = dict(look.textures(None), back=back, cloak=cloak)
    tris = R.triangles(MODEL, 0, tex)
    w, h = 300, 400
    centre = MODEL.carry(bone, 0, A.params["back"][card]["pos"])
    img = R.render_view(tris, R.VIEWS[view][0], w, h, R.FULL["target"], R.FULL["dist"], flat=True)
    return pixel(img, R.screen_point(centre, R.VIEWS[view][0], w, h, R.FULL["target"], R.FULL["dist"]))


def test_back_cards():
    plain = Image.open(R.PLAIN_CLOAK).convert("RGBA")
    red = (230, 20, 20)
    ok(card_pixel(plain, "cloak", "Cloak", "cloak") == red, "cloak card: the image does not show on the cloak")
    ok(card_pixel(None, "body", "Body", "body") == red, "body card: the image does not show without a cloak")
    under = card_pixel(plain, "body", "Body", "body")
    ok(under != red, "body card: shows through a worn cloak (%s)" % (under,))


def test_wings():
    cloak, wings, notes = A.cloak("test")
    ok(wings is not None and any("plain grey" in n for n in notes), "cloak test: wings_test.png on the plain cloak")
    tex = {"skin": R.skin_image("human"), "cloak": cloak, "wings": wings}
    tw, th = O.WINGS_SIZE
    wslot = R.SLOTS.index("wings")
    P = MODEL.positions(0)
    best = None
    for tri in MODEL.tris[wslot]:
        p = P[tri]
        n = -np.cross(p[1] - p[0], p[2] - p[0])
        if np.linalg.norm(n) < 1e-9 or MODEL.uv[tri][:, 0].mean() >= 0.5:
            continue
        facing = (n / np.linalg.norm(n)) @ np.array([0.0, 0.0, -1.0])
        if p[:, 0].mean() > 0 and (best is None or facing > best[0]):
            best = (facing, tri)
    ok(best is not None, "wings: no outer face triangle on the left wing")
    if best is None:
        return
    tri = best[1]
    centre = P[tri].mean(axis=0)
    uv = MODEL.uv[tri].mean(axis=0) * (tw, th)
    want = wings.getpixel((int(uv[0]), int(uv[1])))[:3]
    w, h = 300, 400
    img = R.render_view(R.triangles(MODEL, 0, tex), R.VIEWS["back"][0], w, h, R.FULL["target"], R.FULL["dist"],
                        flat=True)
    got = pixel(img, R.screen_point(centre, R.VIEWS["back"][0], w, h, R.FULL["target"], R.FULL["dist"]))
    ok(got == want, "wings: the left wing's outer face shows %s, its texture %s" % (got, want))


def test_missing_and_sheets():
    with tempfile.TemporaryDirectory(prefix="r55-render-test-") as tmp:
        art = Path(tmp) / "art"
        shutil.copytree(ART, art)
        (art / "shield" / "a.png").unlink()
        a = R.Art(art)
        ok(a.bake_problems, "missing art: bake.py's problems not reported")
        layer, _, missing = a.layer("shield", "T1")
        ok(any("shield/a.png" in m for m in missing), "missing art: not listed (%s)" % missing)
        x, y, _, _ = a.sheets["shield_%d" % O.tier_step(a.params, 1)]["faces"]["front"]
        ok(layer.getpixel((x, y)) in R.CHECK and layer.getpixel((x + 1, y)) in R.CHECK,
           "missing art: no checker in the shield's sheet")
        out = Path(tmp) / "out"
        out.mkdir()
        p, miss = R.contact_sheet(MODEL, a, R.Look(a, "human"), "shield", ["T1", "T2"], out)
        ok(p.exists() and miss["T1"] and Image.open(p).width > 1000, "contact sheet with missing art")
        p, _ = R.detail_sheet(MODEL, A, R.Look(A, "orc"), "book", "T4", out)
        ok(p.exists(), "detail sheet")


def test_partial_tiers():
    """Only shield T1 in tiers.json: every other tier and the whole book are a checker, listed."""
    with tempfile.TemporaryDirectory(prefix="r55-render-test-") as tmp:
        art = Path(tmp) / "art"
        shutil.copytree(ART, art)
        tiers = json.loads((art / "tiers.json").read_text())
        (art / "tiers.json").write_text(json.dumps({"shield": {"T1": tiers["shield"]["T1"]}}))
        a = R.Art(art)
        layer, _, missing = a.layer("shield", "T1")
        ok(not missing, "partial tiers.json: shield T1 lists %s" % missing)
        for item, tid in (("shield", "T4"), ("book", "T1"), ("book", "T6")):
            layer, icon, missing = a.layer(item, tid)
            ok(missing == ["no tiers.json entry"], "partial tiers.json: %s %s lists %s" % (item, tid, missing))
            sid = "shield_%d" % O.tier_step(a.params, int(tid[1])) if item == "shield" else "cover_f"
            x, y, _, _ = a.sheets[sid]["faces"]["front"]
            ok(layer.getpixel((x, y)) in R.CHECK and icon.getpixel((0, 0)) in R.CHECK,
               "partial tiers.json: %s %s not a checker" % (item, tid))
            ok(a.label(item, tid)[0] == "(no tiers.json entry)", "partial tiers.json: %s %s label" % (item, tid))
        out = Path(tmp) / "out"
        out.mkdir()
        for item in ("shield", "book"):
            p, miss = R.contact_sheet(MODEL, a, R.Look(a, "human"), item, ["T1", "T2"], out)
            ok(p.exists() and miss["T2"] == ["no tiers.json entry"], "partial tiers.json: %s sheet" % item)


def test_readme_sizes():
    """The painter's table in README.md names the live sheet sizes (it went stale once)."""
    text = (TOOL / "README.md").read_text()

    def row(start):
        line = next((ln for ln in text.splitlines() if ln.startswith(start)), "")
        return re.findall(r"(\d+) × (\d+)", line.rsplit("|", 2)[-2] if line.count("|") > 2 else "")
    want = [tuple(str(v) for v in A.sheets["shield_0"]["rect"][2:])]
    ok(row("| `art/shield/") == want, "README: shield size %s, the atlas %s" % (row("| `art/shield/"), want))
    want = [tuple(str(v) for v in A.sheets[b]["rect"][2:]) for b in O.BOOK_BOXES]
    ok(row("| `art/book/") == want, "README: book sizes %s, the atlas %s" % (row("| `art/book/"), want))


def test_deterministic():
    layer, _, _ = A.layer("book", "T2")
    look = R.Look(A, "elf", cloak="test", back=str(R.DEFAULT_BACK))
    imgs = [R.render_view(R.triangles(MODEL, MODEL.frame("cast1"), look.textures(layer)), R.VIEWS["front3q_l"][0],
                          160, 220, R.FULL["target"], R.FULL["dist"]).tobytes() for _ in range(2)]
    ok(imgs[0] == imgs[1], "render not deterministic")


def main():
    for t in (test_winding, test_layers_equal_bake, test_shield_alone, test_shield_on_character, test_back_cards,
              test_wings, test_missing_and_sheets, test_partial_tiers, test_readme_sizes, test_deterministic):
        t()
    for f in FAILS:
        print("FAIL", f)
    print("r55 offhand render test: %s" % ("FAIL (%d)" % len(FAILS) if FAILS else "PASS"))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
