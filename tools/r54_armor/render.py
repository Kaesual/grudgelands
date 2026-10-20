#!/usr/bin/env python3
"""Render armor art on the character.

Engines: `soft` (default) is a pure-Python software renderer (softrender.py,
Pillow + numpy) that runs anywhere, including the painter's sandbox;
`chromium` runs the same scene in headless chromium with the vendored three.js
(the coordinator's pick pages). Both use the same perspective camera.

  python3 render.py --art <dir> [--line metal|leather|cloth|all] [--tiers T1,T3]
                    [--race human,orc] [--detail] [--palettes FILE] --out <dir>

The tier selection (which boxes, variants, palette) comes from <art>/tiers.json
(spec §7); without it the example selection in data/catalog.json is used.

Contact sheet per line and race: <out>/<line>_<race>.png. Rows = tiers;
columns = front, back, right side, front three-quarter (character's left),
back three-quarter (character's right), walking (legs at +-0.6 rad, seen from
the front right). Right of the views: the tier's four icons at 32 and 16 px.
--detail: one large sheet per tier instead, <out>/<line>_<tier>_<race>.png.

The tier palette is applied by exact colour match (reference -> tier colour).
Missing art renders as a magenta/black checker and is listed in the row label.
Deterministic: no clock, no randomness.
"""
import argparse
import base64
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

import armorlib as L  # noqa: E402
import softrender  # noqa: E402

ENGINE = "soft"   # set by --engine

BG = (201, 205, 211)
# camera directions (from the target); front3q = the prototype's start camera (42, 30, 80)
VIEWS = {
    "front": {"dir": (0, 0.1, 1), "walk": False, "label": "front"},
    "back": {"dir": (0, 0.1, -1), "walk": False, "label": "back"},
    "right": {"dir": (-1, 0.1, 0), "walk": False, "label": "right side"},
    "left": {"dir": (1, 0.1, 0), "walk": False, "label": "left side"},
    "front3q": {"dir": (42, 13, 80), "walk": False, "label": "front 3/4 (left)"},
    "front3q_r": {"dir": (-42, 13, 80), "walk": False, "label": "front 3/4 (right)"},
    "back3q": {"dir": (-42, 13, -80), "walk": False, "label": "back 3/4 (right)"},
    "back3q_l": {"dir": (42, 13, -80), "walk": False, "label": "back 3/4 (left)"},
    "walk_l": {"dir": (42, 13, 80), "walk": True, "label": "walking, front 3/4 (left)"},
    "walk_back": {"dir": (-42, 13, -80), "walk": True, "label": "walking, back 3/4 (right)"},
    "walk": {"dir": (-42, 13, 80), "walk": True, "label": "walking, front 3/4 (right)"},
    "walk_side": {"dir": (-1, 0.1, 0), "walk": True, "label": "walking, right side"},
}
SHEET_VIEWS = ["front", "back", "right", "front3q", "back3q", "walk"]
DETAIL_VIEWS = ["front", "back", "right", "left", "front3q", "front3q_r", "back3q", "back3q_l",
                "walk_l", "walk", "walk_side", "walk_back"]
CHROME = shutil.which("chromium-browser") or shutil.which("chromium") or "chromium-browser"


def font(size):
    return ImageFont.load_default(size=size)


def b64_rgba(img):
    """raw RGBA, rows bottom-up (three.js DataTexture, flipY false)."""
    return base64.b64encode(img.transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes()).decode()


def tier_assets(cat, pals, art, line, tid, race):
    """palette-mapped box sheets, composed skin, icons, and the list of missing files."""
    tier = cat["tiers"][line][tid]
    mapping = L.palette_map(pals, tier["palette"])
    byid = {b["id"]: b for b in cat["boxes"]}
    missing, boxes = [], []
    for bid in [b["id"] for b in cat["boxes"] if b["id"] in tier["on"]]:
        b = byid[bid]
        v = L.tier_variant(tier, bid)
        p = L.box_file(art, line, bid, v)
        if p.exists():
            im = L.apply_palette(L.load_rgba(p), mapping)
            if list(im.size) != b["sheet"]:
                im = im.resize(tuple(b["sheet"]), Image.Resampling.NEAREST)
        else:
            missing.append(f"{bid}_{v}")
            im = L.checker(tuple(b["sheet"]))
        boxes.append({"id": bid, "box": b["box"], "bone": b["bone"], "rot": b["rot"], "mirror": b["mirror"],
                      "sheet": b["sheet"], "img": im})
    helm = any(x in tier["on"] for x in ("helm", "visor"))
    skin = L.load_rgba(L.DATA / "skins" / f"{race}_{'bald' if helm else 'hair'}.png")
    for slot in L.INNER_SLOTS:
        v = (tier.get("inner") or {}).get(slot)
        if not v:
            continue
        p = L.inner_file(art, line, slot, v)
        if p.exists():
            im = L.load_rgba(p)
            if im.size != (64, 32):
                im = im.resize((64, 32), Image.Resampling.NEAREST)
            skin.alpha_composite(L.apply_palette(im, mapping))
        else:
            missing.append(f"inner/{slot}_{v}")
            chk = L.checker((64, 32))
            mask = Image.new("L", (64, 32), 0)
            d = ImageDraw.Draw(mask)
            for x0, y0, x1, y1 in cat["slots"][slot]["inner_regions"]:
                d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=255)
            skin.paste(chk, (0, 0), mask)
    icons = {}
    for slot in L.SLOTS:
        v = (tier.get("icon") or {}).get(slot)
        if not v:
            continue
        p = L.icon_file(art, line, slot, v)
        if p.exists():
            im = L.apply_palette(L.load_rgba(p), mapping)
            if im.size != (16, 16):
                im = im.resize((16, 16), Image.Resampling.NEAREST)
        else:
            missing.append(f"icons/{slot}_{v}")
            im = L.checker((16, 16), cell=4)
        icons[slot] = im
    return {"boxes": boxes, "skin_img": skin}, icons, missing


PAGE = r"""<!doctype html>
<html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;overflow:hidden;background:#c9cdd3}canvas{display:block}</style></head>
<body><canvas id="c"></canvas>
<script src="__THREE__"></script>
<script>
"use strict";
try {
const D = __DATA__;
const canvas = document.getElementById("c");
const renderer = new THREE.WebGLRenderer({canvas, antialias: false, preserveDrawingBuffer: true});
renderer.setPixelRatio(1); renderer.setSize(D.width, D.height, false);
canvas.style.width = D.width + "px"; canvas.style.height = D.height + "px";
renderer.setScissorTest(true); renderer.autoClear = false;
renderer.setClearColor(new THREE.Color(D.bg[0] / 255, D.bg[1] / 255, D.bg[2] / 255), 1);
renderer.setViewport(0, 0, D.width, D.height); renderer.setScissor(0, 0, D.width, D.height); renderer.clear();
const scene = new THREE.Scene();
scene.add(new THREE.HemisphereLight(0xffffff, 0x6a6458, 0.75));
const sun = new THREE.DirectionalLight(0xffffff, 0.62); scene.add(sun); scene.add(sun.target);

function tex(b64, w, h) {
  const s = atob(b64), a = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) a[i] = s.charCodeAt(i);
  const t = new THREE.DataTexture(a, w, h, THREE.RGBAFormat);
  t.magFilter = THREE.NearestFilter; t.minFilter = THREE.NearestFilter; t.generateMipmaps = false; t.needsUpdate = true;
  return t;
}
// classic box unwrap; BoxGeometry face order +x (left), -x (right), +y (top), -y (bottom), +z (front), -z (back)
function region(u, v, w, h, d) { return [[u + d + w, v + d, d, h], [u, v + d, d, h], [u + d, v, w, d], [u + d + w, v, w, d], [u + d, v + d, w, h], [u + 2 * d + w, v + d, w, h]]; }
function uvGeo(box, uvo, dims, SW, SH) {
  const [x0, y0, z0, x1, y1, z1] = box;
  const geo = new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0);
  const regs = region(uvo[0], uvo[1], dims[0], dims[1], dims[2]);
  const uv = geo.attributes.uv;
  for (let f = 0; f < 6; f++) { const [rx, ry, rw, rh] = regs[f];
    for (let k = 0; k < 4; k++) { const i = f * 4 + k, u = uv.getX(i), v = uv.getY(i);
      uv.setXY(i, (rx + u * rw) / SW, 1 - (ry + (1 - v) * rh) / SH); } }
  return geo;
}

// skeleton (pivots from character.b3d), left limbs = right ones mirrored
const root = new THREE.Group(); scene.add(root);
const bones = {};
function bone(name, parent, pivot, pp) { const g = new THREE.Group(); g.position.set(pivot[0] - pp[0], pivot[1] - pp[1], pivot[2] - pp[2]); parent.add(g); bones[name] = g; }
const B = D.bones, O = [0, 0, 0];
bone("body", root, B.body, O);
["head", "arm_r", "arm_l", "leg_r", "leg_l", "panel_f", "panel_b"].forEach(n => bone(n, bones.body, B[n], B.body));
const mir = {};
["arm_l", "leg_l", "body"].forEach(n => { const m = new THREE.Group(); m.scale.x = -1; bones[n].add(m); mir[n] = m; });

const skinMat = new THREE.MeshLambertMaterial({alphaTest: 0.5});
D.body.forEach(b => {
  const geo = uvGeo(b.box, b.uv, b.dims, 64, 32);
  const pv = B[b.bone], [x0, y0, z0, x1, y1, z1] = b.box;
  const parents = [bones[b.bone]]; if (b.mirror) parents.push(mir[b.bone.replace("_r", "_l")]);
  parents.forEach(p => { const m = new THREE.Mesh(geo, skinMat); m.position.set((x0 + x1) / 2 - pv[0], (y0 + y1) / 2 - pv[1], (z0 + z1) / 2 - pv[2]); p.add(m); });
});

let armor = [];
function buildTier(T) {
  armor.forEach(g => g.parent.remove(g)); armor = [];
  skinMat.map = tex(T.skin, 64, 32); skinMat.needsUpdate = true;
  T.boxes.forEach(s => {
    const [x0, y0, z0, x1, y1, z1] = s.box, w = x1 - x0, h = y1 - y0, d = z1 - z0;
    const W = Math.max(1, Math.floor(w + 0.5)), H = Math.max(1, Math.floor(h + 0.5)), Dd = Math.max(1, Math.floor(d + 0.5));
    const mat = new THREE.MeshLambertMaterial({map: tex(s.rgba, s.sheet[0], s.sheet[1]), alphaTest: 0.5, side: THREE.FrontSide});
    const geo = uvGeo([-w / 2, -h / 2, -d / 2, w / 2, h / 2, d / 2], [0, 0], [W, H, Dd], s.sheet[0], s.sheet[1]);
    const pivot = B[s.bone];
    const parents = [bones[s.bone]];
    if (s.mirror) parents.push(s.bone === "body" ? mir.body : mir[s.bone.replace("_r", "_l")]);
    parents.forEach(p => {
      const g = new THREE.Group(), mesh = new THREE.Mesh(geo, mat);
      if (s.rot) {
        const [axis, deg, o] = s.rot;
        g.position.set(o[0] - pivot[0], o[1] - pivot[1], o[2] - pivot[2]);
        g.rotation[axis] = deg * Math.PI / 180;
        mesh.position.set((x0 + x1) / 2 - o[0], (y0 + y1) / 2 - o[1], (z0 + z1) / 2 - o[2]);
      } else mesh.position.set((x0 + x1) / 2 - pivot[0], (y0 + y1) / 2 - pivot[1], (z0 + z1) / 2 - pivot[2]);
      g.add(mesh); p.add(g); armor.push(g);
    });
  });
}
function pose(walk) {
  // walking: legs at +-0.6 rad (the prototype's walk at sin = 0.6 / 0.785), arms opposite, panels 0.06 + 1.2|leg| / 0.06 + 1.1|leg|
  const legA = walk ? 0.6 : 0, s = legA / 0.785, armR = -s * 0.6, armL = s * 0.6;
  bones.leg_r.rotation.x = legA; bones.leg_l.rotation.x = -legA;
  bones.arm_r.rotation.x = armR; bones.arm_l.rotation.x = armL;
  const lf = Math.abs(legA);
  bones.panel_f.rotation.x = -(0.06 + 1.2 * lf); bones.panel_b.rotation.x = 0.06 + 1.1 * lf;
}
const camera = new THREE.PerspectiveCamera(30, 1, 1, 400);
const groups = {};
D.cells.forEach(c => (groups[c.tier] = groups[c.tier] || []).push(c));
Object.keys(groups).forEach(ti => {
  const T = D.tiers[ti];
  buildTier(T);
  root.scale.setScalar(D.stature);
  groups[ti].forEach(c => {
    pose(c.walk);
    const dir = new THREE.Vector3(...c.dir).normalize();
    // fixed camera for every race, so stature differences show
    const tgt = new THREE.Vector3(0, 17.5, 0);
    camera.aspect = c.w / c.h; camera.position.copy(tgt).addScaledVector(dir, D.dist);
    camera.up.set(0, 1, 0); camera.lookAt(tgt); camera.updateProjectionMatrix();
    // sun from the camera's upper left so every view is lit
    const side = new THREE.Vector3().crossVectors(dir, new THREE.Vector3(0, 1, 0)).normalize();
    sun.position.copy(tgt).addScaledVector(dir, 40).addScaledVector(side, 25).add(new THREE.Vector3(0, 45, 0));
    sun.target.position.copy(tgt);
    const y = D.height - c.y - c.h;
    renderer.setViewport(c.x, y, c.w, c.h); renderer.setScissor(c.x, y, c.w, c.h);
    renderer.clear(); renderer.render(scene, camera);
  });
});
console.log("RENDER_OK");
} catch (e) { console.log("RENDER_ERR " + (e && e.stack || e)); }
</script></body></html>
"""


def run_chromium(html_path, png_path, w, h):
    with tempfile.TemporaryDirectory(prefix="armor-chrome-") as prof:
        cmd = [CHROME, "--headless=new", "--no-sandbox", "--enable-unsafe-swiftshader", "--use-angle=swiftshader",
               "--disable-gpu-sandbox", "--hide-scrollbars", "--force-device-scale-factor=1",
               f"--user-data-dir={prof}", "--no-first-run", "--enable-logging=stderr", "--v=0",
               f"--window-size={w},{h}", f"--screenshot={Path(png_path).resolve()}", Path(html_path).resolve().as_uri()]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    log = r.stderr + r.stdout
    ok = "RENDER_OK" in log
    err = [ln for ln in log.splitlines() if "RENDER_ERR" in ln or "Uncaught" in ln]
    if not ok or not Path(png_path).exists():
        raise RuntimeError("chromium render failed:\n" + ("\n".join(err) or log[-3000:]))
    return Image.open(png_path).convert("RGB")


def render_cells(cat, pals, art, line, tids, race, cells, W, H, dist, workdir, stem):
    tiers, icons, missing = [], {}, {}
    for tid in tids:
        t, ic, miss = tier_assets(cat, pals, art, line, tid, race)
        tiers.append(t)
        icons[tid], missing[tid] = ic, miss
    if ENGINE == "soft":
        return softrender.render(cat, tiers, cells, W, H, dist, cat["stature"].get(race, 1.0), BG), icons, missing
    js_tiers = [{"skin": b64_rgba(t["skin_img"]),
                 "boxes": [dict({k: v for k, v in b.items() if k != "img"}, rgba=b64_rgba(b["img"])) for b in t["boxes"]]}
                for t in tiers]
    data = {"width": W, "height": H, "bg": BG, "bones": cat["bones"], "body": cat["body"],
            "stature": cat["stature"].get(race, 1.0), "dist": dist, "tiers": js_tiers, "cells": cells}
    html = PAGE.replace("__THREE__", (L.TOOL / "vendor" / "three.min.js").as_uri()).replace(
        "__DATA__", json.dumps(data, separators=(",", ":")))
    hp = workdir / f"{stem}.html"
    hp.write_text(html)
    shot = run_chromium(hp, workdir / f"{stem}_raw.png", W, H)
    if shot.size != (W, H):
        canvas = Image.new("RGB", (W, H), BG)
        canvas.paste(shot.crop((0, 0, min(W, shot.width), min(H, shot.height))), (0, 0))
        shot = canvas
    return shot, icons, missing


def icon_block(icons, slots, scale_big=32):
    """icons: 32 px on the background, 16 px on the background and on a dark slot."""
    cw = scale_big + 16 + 16 + 14
    im = Image.new("RGB", (cw * len(slots), scale_big + 18), BG)
    d = ImageDraw.Draw(im)
    for i, slot in enumerate(slots):
        x = i * cw
        ic = icons.get(slot)
        if ic is None:
            continue
        big = ic.resize((scale_big, scale_big), Image.Resampling.NEAREST)
        im.paste(big, (x, 0), big)
        im.paste(ic, (x + scale_big + 4, 0), ic)
        dark = Image.new("RGB", (16, 16), (48, 46, 52))
        dark.paste(ic, (0, 0), ic)
        im.paste(dark, (x + scale_big + 4, 16))
        d.text((x, scale_big + 3), slot, fill=(30, 30, 30), font=font(11))
    return im


def wrap(text, width_chars):
    out, cur = [], ""
    for word in text.split(" "):
        if len(cur) + len(word) + 1 > width_chars and cur:
            out.append(cur)
            cur = word
        else:
            cur = (cur + " " + word).strip()
    if cur:
        out.append(cur)
    return out


def contact_sheet(cat, pals, art, line, tids, race, out, workdir):
    cw, ch, dist = 220, 300, 82
    views = SHEET_VIEWS
    cells = [{"tier": r, "x": c * cw, "y": r * ch, "w": cw, "h": ch, "dir": VIEWS[v]["dir"],
              "walk": VIEWS[v]["walk"]} for r in range(len(tids)) for c, v in enumerate(views)]
    W, H = cw * len(views), ch * len(tids)
    shot, icons, missing = render_cells(cat, pals, art, line, tids, race, cells, W, H, dist, workdir, f"{line}_{race}")
    lab_w, head_h, col_h = 170, 34, 20
    ib = icon_block({}, L.SLOTS)
    ic_w = ib.width + 16
    sheet = Image.new("RGB", (lab_w + W + ic_w, head_h + col_h + H), (236, 234, 229))
    d = ImageDraw.Draw(sheet)
    d.text((8, 8), f"{line} - race {race} - art {Path(art).resolve()} - tiers: {cat['tier_source']} - "
                   f"renderer: {ENGINE}",
           fill=(20, 20, 20), font=font(16))
    for c, v in enumerate(views):
        d.text((lab_w + c * cw + 6, head_h + 3), VIEWS[v]["label"], fill=(60, 60, 60), font=font(12))
    d.text((lab_w + W + 8, head_h + 3), "icons 32 / 16 px", fill=(60, 60, 60), font=font(12))
    sheet.paste(shot, (lab_w, head_h + col_h))
    for r, tid in enumerate(tids):
        y0 = head_h + col_h + r * ch
        tier = cat["tiers"][line][tid]
        d.line([(0, y0), (sheet.width, y0)], fill=(150, 150, 150))
        d.text((8, y0 + 6), tid, fill=(20, 20, 20), font=font(20))
        pname = pals["palettes"][tier["palette"]]["name"]
        d.text((8, y0 + 32), f"{tier['palette']}", fill=(40, 40, 40), font=font(12))
        d.text((8, y0 + 46), f"({pname})", fill=(90, 90, 90), font=font(11))
        yy = y0 + 66
        for ln in wrap("on: " + ", ".join(tier["on"]), 26):
            d.text((8, yy), ln, fill=(60, 60, 60), font=font(11))
            yy += 13
        if missing[tid]:
            yy += 4
            d.text((8, yy), f"MISSING ({len(missing[tid])}):", fill=(200, 0, 160), font=font(12))
            yy += 15
            for ln in wrap(", ".join(missing[tid]), 26)[:8]:
                d.text((8, yy), ln, fill=(200, 0, 160), font=font(11))
                yy += 13
        sheet.paste(icon_block(icons[tid], L.SLOTS), (lab_w + W + 8, y0 + 8))
    p = Path(out) / f"{line}_{race}.png"
    sheet.save(p)
    return p, missing


def detail_sheet(cat, pals, art, line, tid, race, out, workdir):
    cw, ch, dist, cols = 360, 480, 80, 4
    views = DETAIL_VIEWS
    cells = [{"tier": 0, "x": (i % cols) * cw, "y": (i // cols) * ch, "w": cw, "h": ch, "dir": VIEWS[v]["dir"],
              "walk": VIEWS[v]["walk"]} for i, v in enumerate(views)]
    rows = math.ceil(len(views) / cols)
    W, H = cw * cols, ch * rows
    shot, icons, missing = render_cells(cat, pals, art, line, [tid], race, cells, W, H, dist, workdir,
                                        f"{line}_{tid}_{race}")
    head_h, foot_h = 40, 130
    sheet = Image.new("RGB", (W, head_h + H + foot_h), (236, 234, 229))
    d = ImageDraw.Draw(sheet)
    tier = cat["tiers"][line][tid]
    d.text((8, 8), f"{line} {tid} - palette {tier['palette']} - race {race} - renderer: {ENGINE} - on: "
                   f"{', '.join(tier['on'])}",
           fill=(20, 20, 20), font=font(15))
    sheet.paste(shot, (0, head_h))
    for i, v in enumerate(views):
        d.text(((i % cols) * cw + 6, head_h + (i // cols) * ch + 4), VIEWS[v]["label"], fill=(40, 40, 40), font=font(13))
    y = head_h + H + 8
    x = 8
    for slot in L.SLOTS:
        ic = icons[tid].get(slot)
        if ic is None:
            continue
        for s in (64, 32, 16):
            big = ic.resize((s, s), Image.Resampling.NEAREST)
            bgim = Image.new("RGB", (s, s), BG)
            bgim.paste(big, (0, 0), big)
            sheet.paste(bgim, (x, y))
            x += s + 6
        d.text((x - 6 - 16 - 6 - 32 - 6 - 64, y + 68), slot, fill=(30, 30, 30), font=font(12))
        x += 24
    if missing[tid]:
        d.text((x + 10, y), "MISSING: " + ", ".join(missing[tid]), fill=(200, 0, 160), font=font(13))
    p = Path(out) / f"{line}_{tid}_{race}.png"
    sheet.save(p)
    return p, missing


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--art", required=True, help="art directory (contains metal/, leather/, cloth/)")
    ap.add_argument("--line", default="all", choices=L.LINES + ["all"])
    ap.add_argument("--tiers", default="", help="comma list, e.g. T1,T3 (default all six)")
    ap.add_argument("--race", default="human", help="comma list of races (human,dwarf,elf,orc,troll,undead)")
    ap.add_argument("--detail", action="store_true", help="one large sheet per tier (12 views, icons at 64/32/16)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--engine", default="soft", choices=["soft", "chromium"],
                    help="soft (default): pure Python, runs anywhere incl. sandboxes; chromium: three.js in headless "
                         "chromium (needs a working chromium)")
    ap.add_argument("--palettes", help="palettes JSON laid over data/palettes.json (default: <art>/palettes.json "
                                       "when it exists)")
    ap.add_argument("--keep-html", action="store_true", help="keep the generated pages in <out>/_work")
    a = ap.parse_args()
    global ENGINE
    ENGINE = a.engine
    cat = L.load_catalog()
    pals, pnotes, perrors = L.load_palettes(a.art, a.palettes)
    tiers, notes, errors = L.load_tiers(cat, pals, a.art)
    notes, errors = pnotes + notes, perrors + errors
    for n in notes:
        print("note:", n)
    for e in errors:
        print("PROBLEM (run check.py):", e)
    cat = dict(cat, tiers=tiers, tier_source=("art/tiers.json" if (Path(a.art) / "tiers.json").exists()
                                             else "EXAMPLE selection (no art/tiers.json)"))
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    workdir = out / "_work"
    workdir.mkdir(exist_ok=True)
    lines = L.LINES if a.line == "all" else [a.line]
    races = [r.strip() for r in a.race.split(",") if r.strip()]
    for r in races:
        if r not in cat["stature"]:
            sys.exit(f"unknown race {r}; known: {', '.join(cat['stature'])}")
    for line in lines:
        tids = [t.strip() for t in a.tiers.split(",") if t.strip()] or list(cat["tiers"][line])
        for t in tids:
            if t not in cat["tiers"][line]:
                sys.exit(f"unknown tier {t} for {line}")
        for race in races:
            if a.detail:
                for tid in tids:
                    p, miss = detail_sheet(cat, pals, a.art, line, tid, race, out, workdir)
                    print(p, "(missing: %d)" % len(miss[tid]))
            else:
                p, miss = contact_sheet(cat, pals, a.art, line, tids, race, out, workdir)
                n = sum(len(v) for v in miss.values())
                print(p, "(missing files: %d)" % n)
                for tid, v in miss.items():
                    if v:
                        print(f"  {tid} missing: {', '.join(v)}")
    if not a.keep_html:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    main()
