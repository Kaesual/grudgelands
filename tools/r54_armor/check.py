#!/usr/bin/env python3
"""Check armor art against the texture contract (docs/technical/armor-format.md).

  python3 check.py --art <dir> [--line metal|leather|cloth|all] [--quiet-overlaps]

The tier selection (which boxes each line/tier wears, variants, palette) is read
from <art>/tiers.json (spec §7); without it the example selection in
data/catalog.json is used, and the output says so. Any box may be on any tier.

Violations (exit code 1 if any):
  - tiers.json problems (unknown line, tier, box, palette or slot);
  - unknown file names, missing files the selection needs;
  - wrong sheet size (box sheets per catalog, inner 64x32, icons 16x16);
  - colours outside the reference palette; partial alpha (only 0 or 255);
  - paint outside the six face rectangles of a box sheet, or outside the
    slot's skin regions on an inner sheet;
  - a transparent texel inside a box sheet's faces (armor is opaque; only the
    helm's face window may be open);
  - per line, tier and slot fewer than 6 zone A or 3 zone B pixels seen from
    the front (an approximation, see the zone section of the output).
Warnings (printed, exit code unchanged): a sheet no tier uses.
Information: the overlap report (catalog-wide which
box can cover which, and the pairs each tier wears together).
"""
import argparse
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.dont_write_bytecode = True
import armorlib as L  # noqa: E402

ZONE_MIN = {"A": 6, "B": 3}
COVER_GAP = 0.6   # a face within this distance outside another box's volume counts as covered


class Report:
    def __init__(self):
        self.violations, self.warnings = [], []

    def v(self, msg):
        self.violations.append(msg)
        print("  VIOLATION", msg)

    def w(self, msg):
        self.warnings.append(msg)
        print("  WARNING", msg)


def coords(lst, n=6):
    s = ", ".join(f"({x},{y})" for x, y in lst[:n])
    return s + (f" ... (+{len(lst) - n})" if len(lst) > n else "")


def check_pixels(rep, rel, im, allowed=None, allowed_name=""):
    """palette, hard alpha, paint outside `allowed` (set of (x, y) or None)."""
    px = im.load()
    off, partial, outside = defaultdict(list), [], []
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if a != 255:
                partial.append((x, y))
            if (r, g, b) not in L.REF_RGB:
                off[(r, g, b)].append((x, y))
            if allowed is not None and (x, y) not in allowed:
                outside.append((x, y))
    for c, lst in off.items():
        rep.v(f"{rel}: colour {L.rgb_hex(c)} is not in the reference palette, {len(lst)} px at {coords(lst)}")
    if partial:
        rep.v(f"{rel}: partial alpha (only 0 or 255 allowed), {len(partial)} px at {coords(partial)}")
    if outside:
        rep.v(f"{rel}: paint outside {allowed_name}, {len(outside)} px at {coords(outside)}")


def face_cells(b):
    s = set()
    for fx, fy, fw, fh in b["faces"].values():
        for y in range(fy, fy + fh):
            for x in range(fx, fx + fw):
                s.add((x, y))
    return s


# ---------- file checks ----------
NAME = re.compile(r"^([a-z_]+)_([a-z0-9]+)\.png$")


def check_opaque(rep, rel, im, b):
    """Every texel of every face is opaque (the user, 2026-10-20: no transparency in armor, it shows holes);
    the only exception is the helm's face window (armorlib.open_window)."""
    px = im.load()
    window = L.open_window(b)
    holes = [(x, y) for x, y in sorted(face_cells(b), key=lambda q: (q[1], q[0]))
             if px[x, y][3] < 128 and (x, y) not in window]
    if holes:
        rep.v(f"{rel}: {len(holes)} transparent texel(s) inside the faces at {coords(holes)} (sheet pixels; armor "
              f"is opaque, only the helm's face window may be open)")


def check_files(cat, art, lines, rep):
    """Returns {(kind, line, key, variant): Image} for every valid-size file."""
    byid = {b["id"]: b for b in cat["boxes"]}
    good = {}
    print("== files ==")
    nfiles = 0
    for line in lines:
        base = Path(art) / line
        if not base.exists():
            continue
        for p in sorted(base.rglob("*")):
            if p.is_dir():
                continue
            rel = p.relative_to(art)
            parts = p.relative_to(base).parts
            m = NAME.match(parts[-1])
            kind = {1: "box", 2: {"inner": "inner", "icons": "icon"}.get(parts[0])}.get(len(parts))
            key = m.group(1) if m else None
            if not m or kind is None or (kind == "box" and key not in byid) or \
                    (kind == "inner" and key not in L.INNER_SLOTS) or (kind == "icon" and key not in L.SLOTS):
                rep.v(f"{rel}: unknown file name (expected <box>_<variant>.png, inner/<chest|legs|feet>_<variant>.png "
                      f"or icons/<head|chest|legs|feet>_<variant>.png; boxes: {', '.join(byid)})")
                continue
            nfiles += 1
            var = m.group(2)
            try:
                raw = L.Image.open(p)
                im = raw.convert("RGBA")
            except Exception as e:  # noqa: BLE001
                rep.v(f"{rel}: cannot read ({e})")
                continue
            if kind == "box":
                b = byid[key]
                if list(im.size) != b["sheet"]:
                    W, H, D = b["texels"]
                    rep.v(f"{rel}: sheet size {im.width}x{im.height}, expected {b['sheet'][0]}x{b['sheet'][1]} "
                          f"(box {key}: w {W}, h {H}, d {D} texels; 2d+2w by d+h)")
                    continue
                check_pixels(rep, rel, im, face_cells(b), "the six face rectangles")
                check_opaque(rep, rel, im, b)
            elif kind == "inner":
                if im.size != (64, 32):
                    rep.v(f"{rel}: size {im.width}x{im.height}, expected 64x32")
                    continue
                check_pixels(rep, rel, im, L.skin_region_mask(cat, key),
                             f"the {key} region {cat['slots'][key]['inner_regions']}")
            else:
                if im.size != (16, 16):
                    rep.v(f"{rel}: icon size {im.width}x{im.height}, expected 16x16")
                    continue
                check_pixels(rep, rel, im)
            good[(kind, line, key, var)] = im
    print(f"  {nfiles} files with known names checked")
    return good


def check_missing(cat, art, lines, good, rep):
    print("== files the tiers need ==")
    seen = set()
    n = 0
    for line in lines:
        for tid, tier in cat["tiers"][line].items():
            for kind, key, v, p in L.expected_files(cat, art, line, tier):
                n += 1
                if not p.exists() and (line, kind, key, v) not in seen:
                    seen.add((line, kind, key, v))
                    users = [t for t, T in cat["tiers"][line].items()
                             if any(e[:3] == (kind, key, v) for e in L.expected_files(cat, art, line, T))]
                    rep.v(f"{p.relative_to(art)}: missing (needed by {line} {', '.join(users)})")
    used = {(k, ln, key, v) for ln in lines for T in cat["tiers"][ln].values()
            for k, key, v, _ in L.expected_files(cat, art, ln, T)}
    unused = sorted(set(good) - used)
    for k, ln, key, v in unused:
        sub = {"box": "", "inner": "inner/", "icon": "icons/"}[k]
        rep.w(f"{ln}/{sub}{key}_{v}.png: no tier in tiers.json uses it (a second proposal? fine if intended)")


# ---------- front view zone count ----------
class FrontLayer:
    """A front-facing (+z) textured rectangle in the rest pose: a worn box's front
    face (z-rotation allowed) or a body part's front face on the skin."""

    def __init__(self, inst=None, sheet=None, body=None, mirrored=False, skin=None, slot_of_texel=None):
        self.inst, self.sheet = inst, sheet
        self.body, self.mirrored, self.skin, self.slot_of_texel = body, mirrored, skin, slot_of_texel
        if inst:
            b = inst.b
            self.z = inst.to_world((0, 0, b["box"][5]))[2]
        else:
            self.z = body["box"][5]

    def texel_at(self, x, y):
        """(sheet image, tx, ty) of the texel at world x, y on this layer, or None."""
        if self.inst:
            b = self.inst.b
            lx, ly, _ = self.inst.to_local((x, y, self.z))
            x0, y0, _, x1, y1, _ = b["box"]
            if not (x0 - 1e-9 <= lx <= x1 + 1e-9 and y0 - 1e-9 <= ly <= y1 + 1e-9):
                return None
            W, H, D = b["texels"]
            tx = min(W - 1, max(0, int(math.floor((lx - x0) / (x1 - x0) * W))))
            ty = min(H - 1, max(0, int(math.floor((y1 - ly) / (y1 - y0) * H))))
            return (self.sheet, D + tx, D + ty)
        bx = -x if self.mirrored else x
        x0, y0, _, x1, y1, _ = self.body["box"]
        if not (x0 - 1e-9 <= bx <= x1 + 1e-9 and y0 - 1e-9 <= y <= y1 + 1e-9):
            return None
        u, v = self.body["uv"]
        w, h, d = self.body["dims"]
        tx = min(w - 1, max(0, int(math.floor(bx - x0))))
        ty = min(h - 1, max(0, int(math.floor(y1 - y))))
        return (self.skin, u + d + tx, v + d + ty)

    def opaque(self, x, y):
        t = self.texel_at(x, y)
        if t is None:
            return False
        if self.inst is None:
            return True            # the body skin is opaque
        im, tx, ty = t
        return im.getpixel((tx, ty))[3] >= 128

    def texels(self):
        """yield (world x, y, rgb, texel id) of every opaque texel on this face."""
        if self.inst:
            b = self.inst.b
            W, H, D = b["texels"]
            for ty in range(H):
                for tx in range(W):
                    r, g, bl, a = self.sheet.getpixel((D + tx, D + ty))
                    if a < 128:
                        continue
                    p = self.inst.to_world(L.face_point(b["box"], "front", (tx + 0.5) / W, (ty + 0.5) / H))
                    yield p[0], p[1], (r, g, bl), (self.inst.name, tx, ty)
        else:
            u, v = self.body["uv"]
            w, h, d = self.body["dims"]
            x0, _, _, _, y1, _ = self.body["box"]
            for ty in range(h):
                for tx in range(w):
                    r, g, bl, a = self.skin.getpixel((u + d + tx, v + d + ty))
                    if a < 128:
                        continue
                    x = x0 + tx + 0.5
                    yield (-x if self.mirrored else x), y1 - ty - 0.5, (r, g, bl), (self.body["id"], self.mirrored, tx, ty)


def zone_counts(cat, tier, sheets, inner):
    """{slot: {"A": n, "B": n}} visible zone texels from the front, rest pose."""
    byid = {b["id"]: b for b in cat["boxes"]}
    on = [byid[i] for i in tier["on"]]
    layers = []
    for inst in L.instances(on):
        if inst.rot and inst.rot[0] != "z":
            continue   # not front-facing after rotation (none in the catalog)
        layers.append((inst.b["slot"], FrontLayer(inst=inst, sheet=sheets[inst.id])))
    skin = L.Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    region_slot = {}
    for slot, im in inner.items():
        skin.alpha_composite(im)
        for xy in L.skin_region_mask(cat, slot):
            region_slot[xy] = slot
    for body in cat["body"]:
        if body["id"] in ("head", "hat"):
            continue
        for mirrored in ([False, True] if body["mirror"] else [False]):
            layers.append((None, FrontLayer(body=body, mirrored=mirrored, skin=skin)))
    counts = {s: {"A": 0, "B": 0} for s in L.SLOTS}
    for slot, lay in layers:
        for x, y, rgb, tid in lay.texels():
            zone = "A" if rgb in L.ZONE_A else "B" if rgb in L.ZONE_B else None
            if not zone:
                continue
            s = slot
            if s is None:
                u, v = lay.body["uv"]
                w, h, d = lay.body["dims"]
                s = region_slot.get((u + d + tid[2], v + d + tid[3]))
                if s is None:
                    continue
            # only the body and boxes of the SAME slot hide a slot's zones (a robe may cover the boots)
            if any(o is not lay and (os_ is None or os_ == s) and o.z > lay.z + 1e-6 and o.opaque(x, y)
                   for os_, o in layers):
                continue
            counts[s][zone] += 1
    return counts


def check_zones(cat, art, lines, good, rep):
    print("== zones seen from the front (approximation) ==")
    print("  Counts zone A (indices 9-10) and zone B (11-12) texels on the front faces of the worn boxes and on the\n"
          "  inner paint of the body's front faces, in an orthographic front view of the rest pose. Texels hidden\n"
          "  (by the texel centre) behind the body or a worn box of the SAME slot do not count; boxes of other\n"
          "  slots are ignored (each piece must show its zones when worn on its own; a robe may cover the boots).\n"
          "  Both mirrored copies count. Perspective, side faces and the walk are ignored. Minimum per slot:\n"
          "  A >= 6, B >= 3.")
    byid = {b["id"]: b for b in cat["boxes"]}
    for line in lines:
        rows = []
        for tid, tier in cat["tiers"][line].items():
            sheets, inner, missing = {}, {}, []
            for bid in tier["on"]:
                v = L.tier_variant(tier, bid)
                im = good.get(("box", line, bid, v))
                if im is None:
                    missing.append(f"{bid}_{v}")
                sheets[bid] = im
            for slot, v in (tier.get("inner") or {}).items():
                if v:
                    im = good.get(("inner", line, slot, v))
                    if im is None:
                        missing.append(f"inner/{slot}_{v}")
                    else:
                        inner[slot] = im
            bad_slots = {byid[m.rsplit("_", 1)[0]]["slot"] if not m.startswith("inner/") else m[6:].rsplit("_", 1)[0]
                         for m in missing}
            for bid in list(sheets):
                if sheets[bid] is None:
                    sheets[bid] = L.Image.new("RGBA", tuple(byid[bid]["sheet"]), (0, 0, 0, 0))
            counts = zone_counts(cat, tier, sheets, inner)
            cells = []
            for slot in L.SLOTS:
                c = counts[slot]
                if slot in bad_slots:
                    cells.append(f"{slot} (files missing/invalid, skipped)")
                    continue
                cells.append(f"{slot} A{c['A']} B{c['B']}")
                low = [z for z in ("A", "B") if c[z] < ZONE_MIN[z]]
                if low:
                    rep.v(f"{line} {tid} {slot}: " + ", ".join(f"zone {z} {c[z]} < {ZONE_MIN[z]}" for z in low) +
                          " seen from the front (approximation)")
            rows.append(f"  {line} {tid}: " + " | ".join(cells))
        print("\n".join(rows))


# ---------- overlap report ----------
def world_bone(inst):
    return inst.b["bone"].replace("_r", "_l") if inst.mirrored else inst.b["bone"]


def coverage(cat):
    """{(A id, B id): {"faces": {face: set((sx, sy))}, "sides": set, "rigid": bool}}: texels of B's
    faces hidden by A in the rest pose (inside A, or A within COVER_GAP in front of them)."""
    insts = L.instances(cat["boxes"])
    aabb = {id(i): i.world_aabb() for i in insts}
    res, zfights = {}, {}
    for B in insts:
        b = B.b
        W, H, D = b["texels"]
        for A in insts:
            if A.id == B.id:
                continue
            ea, eb = aabb[id(A)], aabb[id(B)]
            if any(ea[k] > eb[k + 3] + COVER_GAP or eb[k] > ea[k + 3] + COVER_GAP for k in range(3)):
                continue
            for face, (fx, fy, fw, fh) in b["faces"].items():
                n = B.dir_to_world(L.FACE_NORMAL[face])
                hit, zf = set(), set()
                for ty in range(fh):
                    for tx in range(fw):
                        p = B.to_world(L.face_point(b["box"], face, (tx + 0.5) / fw, (ty + 0.5) / fh))
                        if A.contains_segment(p, n, COVER_GAP):
                            hit.add((fx + tx, fy + ty))
                        if A.id < B.id and zfight(A, p, n):
                            zf.add((fx + tx, fy + ty))
                if zf:
                    zfights.setdefault((A.id, B.id), set()).add((face, len(zf)))
                if hit:
                    e = res.setdefault((A.id, B.id), {"faces": defaultdict(set), "sides": set(),
                                                      "rigid": world_bone(A) == world_bone(B)})
                    e["faces"][face] |= hit
                    e["sides"].add(B.side or "-")
    return res, zfights


def zfight(A, p, n, gap=0.25):
    """Does world point p (on a face with world normal n) lie on a same-facing face of A,
    closer than `gap` to its plane (z-fighting; the catalog rule wants >= 0.25 px)?"""
    lp = A.to_local(p)
    ln = (-n[0], n[1], n[2]) if A.mirrored else tuple(n)
    if A.rot:
        ln = L._rot(ln, A.rot[0], A.rot[1], (0, 0, 0), inverse=True)
    k = max(range(3), key=lambda i: abs(ln[i]))
    if abs(abs(ln[k]) - 1) > 1e-6:
        return False
    plane = A.box[k + 3] if ln[k] > 0 else A.box[k]
    if abs(lp[k] - plane) >= gap - 1e-9:
        return False
    return all(A.box[i] - 1e-9 <= lp[i] <= A.box[i + 3] + 1e-9 for i in range(3) if i != k)


def pair_detail(b, e):
    parts = []
    for face in ("front", "back", "right", "left", "top", "bottom"):
        hit = e["faces"].get(face)
        if not hit:
            continue
        fx, fy, fw, fh = b["faces"][face]
        xs, ys = [x for x, _ in hit], [y for _, y in hit]
        full = len(hit) == fw * fh
        parts.append(f"{face} {'ALL' if full else f'{len(hit)}/{fw * fh}'} (x{min(xs)}-{max(xs)} y{min(ys)}-{max(ys)})")
    return "; ".join(parts)


def overlap_report(cat, lines, cov, zf):
    print("== overlap report (information, rest pose; mirrored copies included) ==")
    print(f"  'A covers B: face ...' = those texels of B's sheet lie inside A or at most {COVER_GAP} px behind A's\n"
          "  surface, so A hides them wherever A is opaque. Rectangles are in B's sheet pixels (x0-x1, y0-y1).\n"
          "  [moves] = different bones (e.g. a hip panel and a leg): true in the rest pose only.")
    byid = {b["id"]: b for b in cat["boxes"]}
    print(f"  -- catalog: which box can cover which ({len(cov)} pairs, whatever the tiers wear) --")
    for (a, bid) in sorted(cov, key=lambda k: ([x["id"] for x in cat["boxes"]].index(k[1]), k[0])):
        e = cov[(a, bid)]
        print(f"    {a} covers {bid}{'' if e['rigid'] else ' [moves]'}: {pair_detail(byid[bid], e)}")
    for (a, bid), faces in sorted(zf.items()):
        print(f"    GEOMETRY NOTE: {a} and {bid} have same-facing faces closer than 0.25 px (z-fighting): "
              f"{bid} " + ", ".join(f"{f} {n} texels" for f, n in sorted(faces)))
    if not zf:
        print("    (no coplanar same-facing faces: no z-fighting between any two boxes in the rest pose)")

    def fmt(ps):
        return ", ".join(f"{a}>{b}" for a, b in sorted(ps, key=lambda k: (k[1], k[0])))
    for line in lines:
        print(f"  -- {line}: pairs worn together, from the tier selection (A>B = A covers B; details above) --")
        prev = None
        for tid, tier in cat["tiers"][line].items():
            on = set(tier["on"])
            pairs = {k for k in cov if k[0] in on and k[1] in on}
            if prev is None:
                print(f"  {tid} ({len(pairs)} pairs): {fmt(pairs) or '(none)'}")
            else:
                add, rem = pairs - prev, prev - pairs
                delta = (("+ " + fmt(add)) if add else "") + ("; " if add and rem else "") + \
                        (("- " + fmt(rem)) if rem else "")
                print(f"  {tid} ({len(pairs)} pairs): {delta or 'same as the tier before'}")
            prev = pairs


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--art", required=True)
    ap.add_argument("--line", default="all", choices=L.LINES + ["all"])
    ap.add_argument("--palettes", help="palettes JSON laid over data/palettes.json (default: <art>/palettes.json "
                                       "when it exists)")
    ap.add_argument("--quiet-overlaps", action="store_true", help="skip the overlap report")
    a = ap.parse_args()
    cat = L.load_catalog()
    lines = L.LINES if a.line == "all" else [a.line]
    rep = Report()
    if not Path(a.art).is_dir():
        sys.exit(f"no such art directory: {a.art}")
    pals, pnotes, perrors = L.load_palettes(a.art, a.palettes)
    tiers, notes, errors = L.load_tiers(cat, pals, a.art)
    notes, errors = pnotes + notes, perrors + errors
    print("== tier selection ==")
    for n in notes:
        print("  note:", n)
    for e in errors:
        rep.v(e)
    cat = dict(cat, tiers=tiers)
    good = check_files(cat, a.art, lines, rep)
    check_missing(cat, a.art, lines, good, rep)
    check_zones(cat, a.art, lines, good, rep)
    if not a.quiet_overlaps:
        cov, zf = coverage(cat)
        overlap_report(cat, lines, cov, zf)
    n, nw = len(rep.violations), len(rep.warnings)
    print((f"== {n} violation{'s' if n != 1 else ''}" if n else "== OK: no violations") +
          f", {nw} warning{'s' if nw != 1 else ''} (warnings do not fail the check) ==")
    sys.exit(1 if n else 0)


if __name__ == "__main__":
    main()
