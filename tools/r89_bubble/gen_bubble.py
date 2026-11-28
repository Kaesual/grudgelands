#!/usr/bin/env python3
"""Round 89 lane BUBBLE: the shield bubble's mesh and its three textures.

Writes, deterministically and from nothing else:

  mods/CORE/grug_core/models/grug_core_shield_bubble.obj
      a low-poly ellipsoid around its own origin (SEGMENTS around, RINGS from
      pole to pole), authored at 10 units = 1 node like every mesh in the
      game; grug_core/shield_bubble.lua attaches its centre CENTER_Y above
      the player's feet. Standard OBJ conventions (right-handed, faces
      counter-clockwise seen from outside, v up): the engine's loader turns
      both the handedness and the winding (irr/src/COBJMeshFileLoader.cpp
      readVec3 and the face loop), as for any exported OBJ. u runs once
      around, v from the bottom pole (0) to the top pole (1). Normals point
      outward. One material, no mtllib.
  mods/CORE/grug_core/textures/grug_core_shield_bubble_<colour>.png
      one per colour (gold, frost, plain) in the shipped look, SHIPPED_LOOK
      (picked in the look rounds of Round 89):
        web      256 x 128: a soft tint (alpha 32, thicker toward both poles)
                 under a fine, irregular network of light veins -- random
                 walks with a fixed seed that wander and branch, seamless in
                 u and fading out toward the poles (VEINS) -- SHIPPED
        marble   256 x 128: fewer, longer main veins with a soft halo and
                 faint hairline branches
        lightning 256 x 128: jagged bolts that fork often, sparse
        hex      128 x 64: bright seams of a hexagon lattice (10 cells around)
        panels   128 x 64: the seams of the mesh's own 16 x 8 panels
        lattice  128 x 64: a diamond lattice and two rings of light
        classic  32 x 32: Round 1's thin tint with four meridian bands
      The other looks stay reproducible with --look/--out-textures.

Usage: gen_bubble.py [--check] [--rx N --ry N --out-mesh PATH]
       [--look LOOK --out-textures PREFIX] [REPO]
  --check   compare with the files in the repository instead of writing them
            (exit 1 on any difference)
  --rx/--ry and --out-mesh write a variant mesh elsewhere (the screenshot
            probe's comparison shape); never into the repository.
  --look and --out-textures write one look's three textures to
            PREFIX_<colour>.png (the probe's comparison); never into the
            repository.
"""

import argparse
import io
import math
import os
import random
import sys

from PIL import Image, ImageDraw

SEGMENTS = 16          # around the vertical axis
RINGS = 8              # latitude bands, pole to pole
RX = 8.5               # horizontal radius (units; 10 = 1 node)
RY = 10.5              # vertical radius
SIZE = 32              # texture edge in pixels
BANDS = 4              # meridian bands around

MESH = "mods/CORE/grug_core/models/grug_core_shield_bubble.obj"
TEXTURE = "mods/CORE/grug_core/textures/grug_core_shield_bubble_{}.png"

# colour -> (fill RGB, band RGB, edge RGB)
COLOURS = {
    "gold": ((255, 204, 72), (255, 236, 150), (196, 136, 20)),
    "frost": ((120, 186, 255), (196, 228, 255), (52, 112, 200)),
    "plain": ((226, 230, 236), (252, 252, 252), (138, 146, 160)),
}
ALPHA_EQUATOR = 54     # the thin middle of the shell
ALPHA_POLE = 128       # toward both poles
ALPHA_BAND = 30        # added inside a band
ALPHA_EDGE = 110       # a band's edge line


def mesh_text(rx, ry):
    lines = ["# Grudgelands shield bubble (tools/r89_bubble/gen_bubble.py), CC0",
             "# %d x %d ellipsoid, rx %.2f ry %.2f units (10 = 1 node)" % (
                 SEGMENTS, RINGS, rx, ry),
             "o shield_bubble"]
    verts, normals, uvs = [], [], []
    # (ring + 1) x (SEGMENTS + 1) grid: the seam column repeats with u = 1.
    for ring in range(RINGS + 1):
        theta = math.pi * ring / RINGS          # 0 at the bottom pole
        y = -math.cos(theta)
        r = math.sin(theta)
        for seg in range(SEGMENTS + 1):
            phi = 2 * math.pi * seg / SEGMENTS
            x, z = r * math.cos(phi), r * math.sin(phi)
            verts.append((x * rx, y * ry, z * rx))
            # The ellipsoid's outward normal: the gradient of its equation.
            nx, ny, nz = x / rx, y / ry, z / rx
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            normals.append((nx / length, ny / length, nz / length))
            uvs.append((seg / SEGMENTS, ring / RINGS))
    for v in verts:
        lines.append("v %.4f %.4f %.4f" % v)
    for t in uvs:
        lines.append("vt %.4f %.4f" % t)
    for n in normals:
        lines.append("vn %.4f %.4f %.4f" % n)
    lines.append("s off")

    def index(ring, seg):
        return ring * (SEGMENTS + 1) + seg + 1

    triangles = 0
    for ring in range(RINGS):
        for seg in range(SEGMENTS):
            a, b = index(ring, seg), index(ring, seg + 1)
            c, d = index(ring + 1, seg + 1), index(ring + 1, seg)
            # Seen from outside the quad a b c d runs clockwise (phi grows
            # toward -x from +z in a right-handed view), so the faces take
            # a d c and a c b; the pole rings drop their degenerate half.
            quads = []
            if ring != RINGS - 1:
                quads.append((a, d, c))
            if ring != 0:
                quads.append((a, c, b))
            for tri in quads:
                lines.append("f " + " ".join("%d/%d/%d" % (i, i, i) for i in tri))
                triangles += 1
    return "\n".join(lines) + "\n", triangles


def classic_rgba(colour):
    """Round 1's look: a thin tint, four meridian bands with darker edges."""
    fill, band, edge = COLOURS[colour]
    size = 32
    period = size // BANDS
    rows = []
    for row in range(size):
        # row 0 is the image top = the top pole (v = 1).
        v = 1 - (row + 0.5) / size
        lat = abs(2 * v - 1)                   # 0 at the equator, 1 at a pole
        alpha = ALPHA_EQUATOR + (ALPHA_POLE - ALPHA_EQUATOR) * lat ** 3
        line = []
        for col in range(size):
            phase = col % period
            rgb, a = fill, alpha
            if phase in (1, period - 3):
                rgb, a = edge, max(alpha, ALPHA_EDGE)
            elif 1 < phase < period - 3:
                rgb, a = band, alpha + ALPHA_BAND
            line.append(rgb + (a,))
        rows.append(line)
    return size, size, rows


# The patterned looks (look round, Round 89): a clear interior, bright lines
# that carry the colour and drift as the bubble turns, a rim that thickens
# toward both poles. W x H covers u (once around) x v (pole to pole); lines
# are supersampled (SS x SS per pixel) so their edges are soft.
W, H, SS = 128, 64, 4
LINE_RGB = {"gold": (255, 232, 140), "frost": (186, 226, 255), "plain": (255, 255, 255)}
TINT_RGB = {"gold": (255, 196, 60), "frost": (96, 168, 255), "plain": (214, 220, 230)}
INTERIOR = 30       # alpha of the clear interior at the equator
POLE = 110          # interior alpha at the poles
LINE = 220          # alpha of a full line


def hex_coverage(u, v):
    """1 on the seams of a hexagon lattice (10 cells around), else 0."""
    w = W / 10.0
    h = w * 2 / math.sqrt(3)
    dy = 0.75 * h
    best = second = 1e9
    row0 = int(v // dy)
    for r in range(row0 - 1, row0 + 3):
        cy = r * dy
        off = (w / 2) if r % 2 else 0.0
        c0 = int((u - off) // w)
        for c in range(c0 - 1, c0 + 3):
            cx = c * w + off
            d = (u - cx) ** 2 + (v - cy) ** 2
            if d < best:
                best, second = d, best
            elif d < second:
                second = d
    return 1.0 if math.sqrt(second) - math.sqrt(best) < 1.6 else 0.0


def panel_coverage(u, v):
    """1 on the seams between the mesh's own panels (16 x 8, 8 px each)."""
    pu, pv = u % (W / SEGMENTS), v % (H / RINGS)
    return 1.0 if pu < 1.2 or pv < 1.2 else 0.0


def lattice_coverage(u, v):
    """1 on a diamond lattice (8 diamonds around) and on two rings of light."""
    period = W / 8.0
    a = (u + v * 1.0) % period
    b = (u - v * 1.0) % period
    if a < 1.3 or b < 1.3:
        return 1.0
    if abs(v - H * 0.5) < 1.0 or abs(v - H * 0.25) < 0.7:
        return 0.75
    return 0.0


COVERAGE = {"hex": hex_coverage, "panels": panel_coverage, "lattice": lattice_coverage}


def patterned_rgba(colour, look):
    coverage = COVERAGE[look]
    tint, line_rgb = TINT_RGB[colour], LINE_RGB[colour]
    rows = []
    for row in range(H):
        v_mid = 1 - (row + 0.5) / H
        lat = abs(2 * v_mid - 1)
        interior = INTERIOR + (POLE - INTERIOR) * lat ** 4
        # The panels: each one a little brighter toward its upper seam.
        line = []
        for col in range(W):
            c = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    c += coverage(col + (sx + 0.5) / SS, row + (sy + 0.5) / SS)
            c /= SS * SS
            a = interior
            rgb = tint
            if look == "panels":
                pv = (row % (H // RINGS)) / float(H // RINGS)
                a = interior + 26 * (1 - pv)
            if c > 0:
                a = a + (LINE - a) * c
                rgb = tuple(int(round(t + (l - t) * c)) for t, l in zip(tint, line_rgb))
            line.append(rgb + (a,))
        rows.append(line)
    return W, H, rows


# The vein looks (look round 3, Round 89): irregular fine lines of light that
# wander and branch, drawn once on a VW x VH map with a fixed seed. Each vein
# is a random walk; the map wraps seamlessly in u (every segment is also drawn
# one map width to the left and right), and the veins fade out toward both
# poles, where the UV sphere pinches. One map serves all three colours.
VW, VH, VSS = 256, 128, 4
VEINS = {
    # long, gently wandering main veins with a soft halo, branching into
    # faint hairlines: marble
    "marble": dict(seed=8901, mains=8, main_len=(140, 240), step=3.0, turn=0.16,
                   course=0.9, branch=0.035, child_len=(18, 70), depth=2, main_w=1.0,
                   hair_w=0.55,
                   main_i=1.0, hair_i=0.5, halo=True, tint=26),
    # jagged, sharply kinked bolts that fork often: frozen lightning
    "lightning": dict(seed=4417, mains=9, main_len=(26, 48), step=4.5, turn=0.08,
                      course=0.8,
                      kink=0.75, branch=0.16, child_len=(5, 16), depth=3, main_w=1.0,
                      hair_w=0.55, main_i=1.0, hair_i=0.65, halo=False, tint=24),
    # many short hairlines and no dominant vein: a fine web
    "web": dict(seed=2203, mains=26, main_len=(30, 80), step=2.5, turn=0.20,
                branch=0.045, child_len=(8, 30), depth=2, main_w=0.75, hair_w=0.5,
                main_i=0.75, hair_i=0.5, halo=False, tint=32),
}
VEIN_LINE_A = 215   # alpha of a full-strength vein
VEIN_POLE_FADE = 0.22  # veins fade out over this share of v next to each pole


def vein_map(params):
    """VW x VH rows of vein intensity 0..1 (seamless in u)."""
    rng = random.Random(params["seed"])
    big = Image.new("L", (VW * VSS, VH * VSS), 0)
    draw = ImageDraw.Draw(big)
    strokes = []  # (points, width px, intensity, halo)

    kink = params.get("kink")

    def walk(x, y, angle, steps, level):
        points = [(x, y)]
        for _ in range(steps):
            angle += rng.gauss(0, params["turn"])
            heading, length = angle, params["step"]
            if kink:
                # A bolt: straight pieces of random length, each bent off
                # its slowly drifting course by a sharp random kink.
                heading = angle + rng.uniform(-kink, kink)
                length = params["step"] * rng.uniform(0.4, 1.6)
            x += math.cos(heading) * length
            y += math.sin(heading) * length * 0.8
            if y < 1 or y > VH - 1:
                break
            points.append((x, y))
            if level < params["depth"] and rng.random() < params["branch"]:
                side = rng.choice((-1, 1))
                walk(x, y, angle + side * rng.uniform(0.35, 1.0),
                     rng.randint(*params["child_len"]), level + 1)
        main = level == 0
        strokes.append((points, params["main_w"] if main else params["hair_w"],
                        params["main_i"] if main else params["hair_i"] / level,
                        main and params["halo"]))

    # `course`: a main vein sets out within this many radians of the
    # horizontal (either way round), so it crosses the egg rather than
    # running into a pole; without it any direction.
    def start_angle():
        if params.get("course"):
            return rng.uniform(-params["course"], params["course"]) + rng.choice((0, math.pi))
        return rng.uniform(0, 2 * math.pi)

    # Stratified in u (one start per slice, jittered) so no side of the egg
    # stays bare; v and the direction are free.
    for index in range(params["mains"]):
        walk((index + rng.uniform(0.1, 0.9)) * VW / params["mains"],
             rng.uniform(0.2 * VH, 0.8 * VH), start_angle(),
             rng.randint(*params["main_len"]), 0)
    # Faint first, strong last, so a hairline never darkens a main vein.
    strokes.sort(key=lambda stroke: stroke[2])
    for halo_pass in (True, False):
        for points, width, intensity, halo in strokes:
            if halo_pass and not halo:
                continue
            w = (width * 3.5 if halo_pass else width) * VSS
            value = int(round(255 * intensity * (0.18 if halo_pass else 1.0)))
            for shift in (-VW, 0, VW):
                scaled = [((px + shift) * VSS, py * VSS) for px, py in points]
                if len(scaled) > 1:
                    draw.line(scaled, fill=value, width=max(1, int(round(w))), joint="curve")
    small = big.resize((VW, VH), Image.BOX)
    data = small.tobytes()
    return [[data[row * VW + col] / 255.0 for col in range(VW)] for row in range(VH)]


def vein_rgba(colour, look):
    params = VEINS[look]
    veins = vein_map(params)
    tint, line_rgb = TINT_RGB[colour], LINE_RGB[colour]
    rows = []
    for row in range(VH):
        v_mid = 1 - (row + 0.5) / VH
        lat = abs(2 * v_mid - 1)
        interior = params["tint"] + (POLE - params["tint"]) * lat ** 4
        edge = min(1.0, (1 - lat) / (2 * VEIN_POLE_FADE))
        line = []
        for col in range(VW):
            c = veins[row][col] * edge
            a = interior + (VEIN_LINE_A - interior) * c
            rgb = tuple(int(round(t + (l - t) * min(1.0, c * 1.4)))
                        for t, l in zip(tint, line_rgb))
            line.append(rgb + (a,))
        rows.append(line)
    return VW, VH, rows


LOOKS = ("classic", "hex", "panels", "lattice") + tuple(sorted(VEINS))
SHIPPED_LOOK = "web"


def texture_png(colour, look=None):
    look = look or SHIPPED_LOOK
    if look == "classic":
        w, h, rows = classic_rgba(colour)
    elif look in VEINS:
        w, h, rows = vein_rgba(colour, look)
    else:
        w, h, rows = patterned_rgba(colour, look)
    image = Image.new("RGBA", (w, h))
    image.putdata([px[:3] + (int(round(min(255, px[3]))),) for line in rows for px in line])
    out = io.BytesIO()
    image.save(out, format="PNG", optimize=True)
    return out.getvalue()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--rx", type=float)
    parser.add_argument("--ry", type=float)
    parser.add_argument("--out-mesh")
    parser.add_argument("--look", choices=LOOKS,
                        help="with --out-textures: the look to write (default: the shipped one)")
    parser.add_argument("--out-textures",
                        help="write PREFIX_<colour>.png for --look (outside the repository)")
    parser.add_argument("repo", nargs="?",
                        default=os.path.join(os.path.dirname(__file__), "..", ".."))
    args = parser.parse_args()
    if args.out_textures:
        for colour in COLOURS:
            path = "%s_%s.png" % (args.out_textures, colour)
            with open(path, "wb") as handle:
                handle.write(texture_png(colour, args.look))
        print("look %s: %d textures at %s_<colour>.png" % (
            args.look or SHIPPED_LOOK, len(COLOURS), args.out_textures))
        return 0
    if args.out_mesh:
        text, triangles = mesh_text(args.rx or RX, args.ry or RY)
        with open(args.out_mesh, "w") as handle:
            handle.write(text)
        print("variant mesh %s: %d triangles" % (args.out_mesh, triangles))
        return 0
    text, triangles = mesh_text(RX, RY)
    files = {MESH: text.encode()}
    for colour in COLOURS:
        files[TEXTURE.format(colour)] = texture_png(colour)
    bad = 0
    for rel, data in files.items():
        path = os.path.join(args.repo, rel)
        if args.check:
            try:
                with open(path, "rb") as handle:
                    same = handle.read() == data
            except FileNotFoundError:
                same = False
            if not same:
                print("DIFFERS " + rel)
                bad += 1
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as handle:
                handle.write(data)
    print("%s: mesh %d triangles, %d textures" % (
        "check" if args.check else "wrote", triangles, len(COLOURS)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
