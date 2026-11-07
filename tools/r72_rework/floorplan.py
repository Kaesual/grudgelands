#!/usr/bin/env python3
"""Draw the Round 72 proposals, not game templates. Python 3 + Pillow.

Run from any directory; --grid prints both matching four-node text grids.
--check compares the PNGs and the embedded grids without writing anything.
Rectangles are node indices with exclusive upper bounds, as in stilled_seam.py.
The lake section uses physical node faces (index +/- 0.5), not air-cell centres.
"""
import argparse
from io import BytesIO
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/planning/round72-expeditions"
SCALE = 8
ORIGIN = (64, 152)
COLORS = {"rock": "#435158", "floor": "#e7decb", "ink": "#243942",
          "muted": "#56666b", "paper": "#f6f2e9", "trap": "#a54848",
          "water": "#ad432b", "safe": "#c9ded7", "boss": "#e8c1ab"}

COMMON_ROOMS = [("0", "Arrival", (8, 8, 32, 32)),
                ("1", "Timekeeper's desk", (48, 8, 80, 40)),
                ("2", "Marking floor", (96, 8, 120, 40))]
COURT_TRAPS = [(56, 96), (72, 96), (56, 112), (72, 112)]
FIRST_TRAPS = [(100, 20), (116, 20), (100, 32), (116, 32)]
STORE = [("o", 12, 96), ("o", 28, 92), ("o", 28, 100), ("o", 12, 116),
         ("g", 12, 108), ("g", 28, 116), ("C", 20, 104), ("E", 20, 112)]
SECOND = {
    "id": "second-shift", "title": "THE SECOND SHIFT", "level": "40-69",
    "y": 8,
    "rooms": COMMON_ROOMS + [("3", "Wage room", (96, 64, 120, 120)),
                             ("4", "Audit court", (48, 88, 80, 120)),
                             ("5", "Store", (8, 88, 32, 120))],
    "passages": [(32, 16, 48, 24), (80, 16, 96, 24), (104, 40, 112, 64),
                 (80, 104, 96, 112), (32, 104, 48, 112)],
    "screens": [(104, 88, 120, 96)], "lake": None,
    "features": [("S", 20, 28), ("a", 60, 28), ("o", 76, 36),
                 ("b", 108, 28), ("g", 116, 36), ("c", 108, 72),
                 ("d", 108, 108), ("B", 64, 104), ("D", 44, 108)] + STORE,
    "floor": FIRST_TRAPS + [(100, 76), (116, 80), (100, 104), (116, 112)] + COURT_TRAPS,
    "walls": [((84, 15), (84, 24)), ((92, 15), (92, 24))],
    "picks": ["F1-F4: pick 2", "F5-F6: pick 1; F7-F8: pick 1", "F9-F12: pick 2",
              "W1-W2: pick 1; period 8 s; +z"],
    "route": "0 > 1 (a) > 2 (b) > 3 (c, d) > 4 (B) > 5",
}
LAST = {
    "id": "last-mint", "title": "THE LAST MINT", "level": "60-69", "y": 32,
    "rooms": [("0", "Arrival", (8, 8, 32, 32)),
              ("1", "Salvage bins", (48, 8, 80, 40)),
              ("2", "Furnace room", (96, 8, 120, 40)),
              ("L", "Lava crossing", (96, 48, 120, 88)),
              ("3", "Cooling room", (96, 96, 120, 120)),
              ("4", "Press vestibule", (48, 56, 80, 80)),
              ("5", "Press floor", (48, 88, 80, 120)),
              ("6", "Store", (8, 88, 32, 120))],
    "passages": [(32, 16, 48, 24), (80, 16, 96, 24), (104, 40, 112, 48),
                 (104, 88, 112, 96), (92, 104, 96, 112), (84, 64, 92, 112),
                 (80, 64, 84, 72), (60, 80, 68, 88), (32, 104, 48, 112)],
    "screens": [], "lake": (96, 52, 120, 84),
    "pillars": [(106, z, 110, z + 4) for z in (54, 60, 66, 72, 78)],
    "features": [("S", 20, 28), ("a", 60, 28), ("o", 76, 36),
                 ("b", 108, 28), ("c", 108, 116), ("g", 116, 116),
                 ("d", 64, 68), ("B", 64, 104), ("D", 44, 108)] + STORE,
    "floor": FIRST_TRAPS + [(52, 60), (76, 60), (52, 76), (76, 76)] + COURT_TRAPS,
    "walls": [((96, 56), (120, 56)), ((120, 62), (96, 62)),
              ((96, 74), (120, 74)), ((120, 80), (96, 80))],
    "picks": ["F1-F4: pick 2; F5-F8: pick 2", "F9-F12: pick 2",
              "W1-W2: pick 1; W3-W4: pick 1", "Period 6 s; arrows show +x / -x"],
    "route": "0 > 1 (a) > 2 (b) > L > 3 (c) > 4 (d) > 5 (B) > 6",
}
PLANS = (SECOND, LAST)


def inside(x, z, rect):
    x0, z0, x1, z1 = rect
    return x0 <= x < x1 and z0 <= z < z1


def text_grid(plan):
    floors = [r[2] for r in plan["rooms"]] + plan["passages"]
    rows = []
    for z in range(2, 128, 4):
        row = []
        for x in range(2, 128, 4):
            cell = "." if any(inside(x, z, r) for r in floors) else "#"
            if any(inside(x, z, r) for r in plan["screens"]):
                cell = "#"
            if plan["lake"] and inside(x, z, plan["lake"]):
                cell = "~"
                if any(inside(x, z, r) for r in plan["pillars"]):
                    cell = "p"
            row.append(cell)
        rows.append(row)
    # Coarse symbols mark cells containing a feature, not its exact centre.
    for n, _, (x0, z0, _, _) in plan["rooms"]:
        rows[(z0 + 2) // 4][(x0 + 2) // 4] = n
    for x, z in plan["floor"]:
        rows[z // 4][x // 4] = "f"
    for (x, z), _ in plan["walls"]:
        rows[z // 4][min(x // 4, 31)] = "w"
    for c, x, z in plan["features"]:
        rows[z // 4][x // 4] = c
    return "\n".join("".join(row) for row in rows)


def canvas(size):
    from PIL import Image, ImageDraw, ImageFont
    im = Image.new("RGB", size, COLORS["paper"])
    draw = ImageDraw.Draw(im)

    def label(xy, text, size=20, fill=None, anchor=None):
        draw.text(xy, text, font=ImageFont.load_default(size=size),
                  fill=fill or COLORS["ink"], anchor=anchor)
    return im, draw, label


def png_bytes(im):
    out = BytesIO()
    im.save(out, format="PNG")
    return out.getvalue()


def render_plan(plan):
    im, draw, label = canvas((1650, 1390))
    ox, oz = ORIGIN

    def point(x, z):
        return ox + x * SCALE, oz + z * SCALE

    def box(rect, color):
        x0, z0, x1, z1 = rect
        draw.rectangle((point(x0, z0), point(x1, z1)), fill=color)

    label((64, 28), plan["title"], 38)
    label((64, 82), f"Levels {plan['level']}  |  4 players  |  128 x 64 x 128 nodes  |  proposal", 23)
    box((0, 0, 128, 128), COLORS["rock"])
    for rect in plan["passages"]:
        box(rect, COLORS["floor"])
    for n, title, rect in plan["rooms"]:
        color = COLORS["safe"] if title in ("Arrival", "Store") else COLORS["floor"]
        if title in ("Audit court", "Press floor"):
            color = COLORS["boss"]
        box(rect, color)
    for rect in plan["screens"]:
        box(rect, COLORS["rock"])
    if plan["lake"]:
        box(plan["lake"], COLORS["water"])
        for i, rect in enumerate(plan["pillars"], 1):
            box(rect, COLORS["floor"])
            label(point((rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2),
                  str(i), 16, anchor="mm")
    for tick in range(0, 129, 8):
        x, z = point(tick, tick)
        draw.line((x, oz, x, oz + 1024), fill="#9c9b8c", width=1)
        draw.line((ox, z, ox + 1024, z), fill="#9c9b8c", width=1)
        if tick % 16 == 0:
            label((x, oz - 20), str(tick), 16, anchor="mm")
            label((ox - 23, z), str(tick), 16, anchor="mm")
    label((1104, 130), "x", 20)
    label((29, 1190), "z", 20)
    for n, _, rect in plan["rooms"]:
        label(point(rect[0] + 1, rect[1] + 1), n, 20)
    for i, (x, z) in enumerate(plan["floor"], 1):
        px, pz = point(x, z)
        draw.ellipse((px - 16, pz - 16, px + 16, pz + 16), outline=COLORS["trap"], width=2)
        label((px, pz), str(i), 15, COLORS["trap"], "mm")
    for i, ((x, z), (ex, ez)) in enumerate(plan["walls"], 1):
        px, pz = point(x, z)
        tx, tz = point(ex, ez)
        draw.line((px, pz, tx, tz), fill=COLORS["ink"], width=5)
        draw.line((px, pz, tx, tz), fill="#ffe39c", width=2)
        dx, dz = ex - x, ez - z
        length = (dx * dx + dz * dz) ** 0.5
        ux, uz = dx / length, dz / length
        draw.polygon([(tx, tz), (tx - 12 * ux + 5 * uz, tz - 12 * uz - 5 * ux),
                      (tx - 12 * ux - 5 * uz, tz - 12 * uz + 5 * ux)], fill=COLORS["ink"])
        label((px - 4 if x <= ex else px + 4, pz - 16), f"W{i}", 15,
              "#fff3cd", "rm" if x <= ex else "lm")
    for c, x, z in plan["features"]:
        px, pz = point(x, z)
        color = "#287969" if c in "SEg" else "#9a681a" if c in "oC" else "#713b35"
        if c == "D":
            draw.rectangle((px - 5, pz - 32, px + 5, pz + 32), fill=color)
            label((px, pz - 45), c, 18, color, "mm")
        else:
            radius = 14 if c in "og" else 19
            draw.ellipse((px - radius, pz - radius, px + radius, pz + radius), fill=color)
            label((px, pz), c, 20, "white", "mm")
    sx, y = 1130, 154
    label((sx, y), "ROOMS / [x0,z0,x1,z1)", 23)
    y += 40
    for n, title, rect in plan["rooms"]:
        label((sx, y), f"{n}  {title}", 21)
        label((sx + 27, y + 27), str(rect), 18, COLORS["muted"])
        y += 62
    y += 10
    label((sx, y), "RANDOM TRAPS PER CREATION", 21)
    y += 35
    for line in plan["picks"]:
        label((sx, y), line, 19)
        y += 29
    y += 20
    label((sx, y), "F: ring radius 2; warning 1.5 s", 19)
    label((sx, y + 29), "Numbers in circles = F candidates", 19)
    label((sx, y + 58), "Arrows = W candidate shot paths", 19)
    label((sx, y + 98), f"First air cell y = {plan['y']}", 20)
    label((sx, y + 127), "All rectangles exclude upper bounds.", 18)
    label((sx, y + 156), "Full coordinates and picks in the document.", 18)
    label((64, 1210), plan["route"], 25)
    label((64, 1255), "a-d packs  |  B boss  |  D locked reward door  |  C personal chest inventory  |  S / E waystones", 22)
    label((64, 1293), "o ore place  |  g gem place  |  six floor traps selected  |  untouched rock seals every other route", 22)
    label((64, 1331), "The lake is crossed before the boss. Five pillars, six jumps; its section gives the exact gaps."
          if plan["lake"] else "One level. A full-height rock screen separates packs c and d. The boss court is solid and connected.", 21)
    return png_bytes(im)


def render_section():
    im, draw, label = canvas((1650, 1180))
    label((64, 30), "THE LAST MINT / LAKE SECTION", 36)
    label((64, 82), "Cut at x = 108; z increases along the crossing. Physical node faces shown. Full box height: 64 nodes.", 22)
    # Equal scale in y and z, for an honest view of the drop and the head room.
    ox, oy, scale = 110, 958, 12
    def p(z, y):
        return ox + (z - 44) * scale, oy - (y + 0.5) * scale
    def rect(z0, y0, z1, y1, fill):
        draw.rectangle((p(z0, y1), p(z1, y0)), fill=fill)
    rect(43.5, -0.5, 92.5, 63.5, COLORS["rock"])
    # Source lava y=2..7, basin bottom y=1; full-height solid rims.
    rect(51.5, 7.5, 83.5, 59.5, "#eee4d2")
    rect(51.5, 1.5, 83.5, 7.5, COLORS["water"])
    rect(43.5, 31.5, 51.5, 59.5, "#eee4d2")
    rect(83.5, 31.5, 92.5, 59.5, "#eee4d2")
    for i, (_, z0, _, z1) in enumerate(LAST["pillars"], 1):
        rect(z0 - 0.5, 1.5, z1 - 0.5, 31.5, COLORS["floor"])
        label(p((z0 + z1 - 1) / 2, 30), f"P{i}", 18, anchor="mt")
    for y in (0, 8, 16, 24, 32, 40, 48, 56, 64):
        yy = y - 0.5
        px, py = p(43.5, yy)
        draw.line((px - 6, py, px, py), fill=COLORS["ink"], width=2)
        label((px - 16, py), str(yy), 17, anchor="rm")
    label((35, 142), "y", 21)
    for z in (48, 52, 58, 64, 70, 76, 82, 88):
        label(p(z - 0.5, -2), str(z - 0.5), 14, anchor="mt")
    label((755, 997), "z", 21)
    for z0 in (51.5, 57.5, 63.5, 69.5, 75.5, 81.5):
        # Schematic arcs; their endpoints are faces, not a physics simulation.
        pts = [p(z0 + 2 * t / 20, 31.5 + 4 * (t / 20) * (1 - t / 20)) for t in range(21)]
        draw.line(pts, fill="#276c64", width=2)
    label(p(68, 40), "6 gaps x 2 nodes / rise 0", 20, anchor="mm")
    label(p(68, 35), "4 x 4 tops; all at y = 31.5", 18, anchor="mm")
    label(p(68, 11), "Lava surface y = 7.5", 20, anchor="mm")
    sx, sy = 820, 170
    rows = [
        ("GEOMETRY", 25),
        ("Box: node centres y=0..63; faces -0.5..63.5", 21),
        ("Sealed roof: y=60..63; bottom: y=0..1", 21),
        ("Rim and tops: solid through node y=31", 21),
        ("First standing air cell: y=32", 21),
        ("Lava: y=2..7; 24 nodes below the tops", 21),
        ("No ledge, ladder, low shelf or route round the rim", 21),
        ("", 18),
        ("ORDINARY JUMPS", 25),
        ("Five pillars; six equal, level jumps", 21),
        ("Every gap is 2 empty node columns", 21),
        ("4 nodes of runway and 4 x 4 landing space", 21),
        ("Walk speed 4; jump speed 6.5; gravity 19.62", 21),
        ("Ideal rise 1.08; flight 0.663 s; travel 2.65", 21),
        ("No sprint, mount or class movement required", 21),
        ("Arcs are schematic. Desktop + web test remains open.", 20),
        ("", 18),
        ("FIREBALLS", 25),
        ("Two of four wall sockets; period 6 s; speed 8", 21),
        ("Shots cross x at y=32.5, over P1/P2 and P4/P5", 21),
        ("P3 has no shot line: stop and read the next beat", 21),
        ("No mobs or floor traps on the pillars", 21),
        ("Fall: lava takes 20% of actual max HP each second", 21),
    ]
    for text, size in rows:
        label((sx, sy), text, size)
        sy += 34 if size < 25 else 42
    label((64, 1060), "The approach and exit span x=[96,120); only pillar tops occupy the basin at route height.", 22)
    label((64, 1100), "Room 2 > approach > P1 > P2 > P3 > P4 > P5 > exit > room 3. Boss room 5 is elsewhere on solid floor.", 21)
    return png_bytes(im)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--grid", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.grid:
        for plan in PLANS:
            print(plan["title"] + "\n" + text_grid(plan) + "\n")
        return
    outputs = {OUT / f"{p['id']}-plan.png": render_plan(p) for p in PLANS}
    outputs[OUT / "last-mint-section.png"] = render_section()
    bad = []
    for path, content in outputs.items():
        if args.check:
            if not path.exists() or path.read_bytes() != content:
                bad.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    if args.check:
        for plan in PLANS:
            path = ROOT / f"docs/planning/round72-{plan['id']}.md"
            block = "<!-- floorplan-grid:start -->\n```text\n" + text_grid(plan) + "\n```\n<!-- floorplan-grid:end -->"
            if not path.exists() or block not in path.read_text():
                bad.append(str(path.relative_to(ROOT)) + " (grid)")
        if bad:
            raise SystemExit("Stale: " + ", ".join(bad))
        print("Three PNGs and both document grids match the generator.")
    else:
        print("Wrote three floor-plan images. --grid prints the matching document grids.")


if __name__ == "__main__":
    main()
