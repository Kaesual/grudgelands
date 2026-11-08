#!/usr/bin/env python3
"""Draw the Round 72 proposals, not game templates. Python 3 + Pillow.

Run from any directory; writes PNGs, coordinate tables and four-node text grids.
--grid prints both grids; --check compares all generated content without writing.
Rectangles are node indices with exclusive upper bounds, as in stilled_seam.py.
The lake section uses physical node faces (index +/- 0.5), not air-cell centres.
"""
import argparse
from copy import deepcopy
from io import BytesIO
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/planning/round72-expeditions"
SCALE = 8
ORIGIN = (64, 152)
COLORS = {"rock": "#435158", "floor": "#e7decb", "ink": "#243942",
          "muted": "#56666b", "paper": "#f6f2e9", "trap": "#a54848",
          "water": "#ad432b", "safe": "#c9ded7", "boss": "#e8c1ab",
          "dais": "#cf9f7c", "press": "#625a54"}

COMMON_ROOMS = [("0", "Arrival", (8, 8, 32, 32)),
                ("1", "Timekeeper's desk", (48, 8, 80, 40)),
                ("2", "Marking floor", (96, 8, 120, 40))]
COURT_TRAPS = [(56, 96), (72, 96), (56, 112), (72, 112)]
FIRST_TRAPS = [(100, 20), (116, 20), (100, 32), (116, 32)]
STORE = [("o", 8, 96), ("o", 31, 92), ("o", 31, 100), ("o", 8, 116),
         ("g", 8, 108), ("g", 31, 116), ("C", 20, 104), ("E", 20, 112)]
SECOND = {
    "id": "second-shift", "title": "THE SECOND SHIFT", "level": "40-69",
    "y": 8,
    "rooms": COMMON_ROOMS + [("3", "Wage room", (96, 64, 120, 120)),
                             ("4", "Audit court", (48, 88, 80, 120)),
                             ("5", "Store", (8, 88, 32, 120))],
    "passages": [(32, 16, 48, 24), (80, 16, 96, 24), (104, 40, 112, 64),
                 (80, 104, 96, 112), (32, 104, 48, 112)],
    "screens": [(104, 88, 120, 96)], "lake": None,
    "features": [("S", 20, 28), ("a", 60, 28), ("o", 79, 36),
                 ("b", 108, 28), ("g", 119, 36), ("c", 108, 72),
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
    "features": [("S", 20, 28), ("a", 60, 28), ("o", 79, 36),
                 ("b", 108, 28), ("c", 108, 116), ("g", 119, 116),
                 ("d", 64, 68), ("B", 64, 104), ("D", 44, 108)] + STORE,
    "floor": FIRST_TRAPS + [(52, 60), (76, 60), (52, 76), (76, 76)] + COURT_TRAPS,
    "walls": [((96, 58.5), (120, 58.5)), ((120, 64.5), (96, 64.5)),
              ((96, 70.5), (120, 70.5)), ((120, 76.5), (96, 76.5))],
    "picks": ["F1-F4: pick 2; F5-F8: pick 2", "F9-F12: pick 2",
              "W1-W2: pick 1; W3-W4: pick 1", "Period 6 s; arrows show +x / -x"],
    "route": "0 > 1 (a) > 2 (b) > L > 3 (c) > 4 (d) > 5 (B) > 6",
}
# Author shapes in the original route's envelopes, then reflect ALL geometry.
# Cuts are full-height rock, not holes in the walking floor. The small stepped
# bites suggest hewn stone / masonry without defining Round 72's node dressing.
SECOND["cuts"] = {
    "0": [(8, 8, 16, 16), (28, 8, 32, 12), (8, 28, 12, 32)],
    "1": [(48, 8, 56, 14), (56, 8, 60, 10), (72, 8, 80, 12),
          (48, 34, 54, 40), (54, 38, 60, 40)],
    "2": [(96, 8, 102, 14), (102, 8, 106, 10), (114, 8, 120, 14),
          (96, 36, 100, 40), (116, 38, 120, 40)],
    "3": [(96, 64, 100, 68), (116, 64, 120, 70), (116, 84, 120, 88),
          (96, 116, 102, 120), (116, 116, 120, 120)],
    "4": [(48, 88, 56, 92), (48, 92, 52, 96), (72, 88, 80, 92),
          (76, 92, 80, 96), (48, 116, 56, 120), (48, 112, 52, 116),
          (72, 116, 80, 120), (76, 112, 80, 116)],
    "5": [(8, 88, 16, 92), (28, 88, 32, 90), (12, 88, 20, 90),
          (8, 118, 12, 120), (28, 118, 32, 120)],
}
LAST["cuts"] = {
    "0": [(8, 8, 16, 16), (28, 8, 32, 12), (8, 28, 14, 32)],
    "1": [(48, 8, 58, 14), (74, 8, 80, 14), (48, 32, 56, 40),
          (56, 36, 60, 40)],
    "2": [(96, 8, 102, 14), (114, 8, 120, 14), (96, 36, 102, 40),
          (114, 36, 120, 40)],
    "L": [(96, 48, 100, 50), (116, 48, 120, 50),
          (96, 86, 100, 88), (116, 86, 120, 88)],
    "3": [(96, 96, 102, 102), (114, 96, 120, 102), (96, 116, 100, 120)],
    "4": [(48, 56, 52, 60), (76, 56, 80, 60), (48, 76, 52, 80),
          (78, 78, 80, 80)],
    "5": [(48, 88, 54, 94), (74, 88, 80, 94), (48, 114, 54, 120),
          (74, 114, 80, 120)],
    "6": [(8, 88, 16, 92), (28, 88, 32, 90), (8, 118, 12, 120),
          (28, 118, 32, 120)],
}
SECOND["press"] = []
LAST["press"] = [(58, 116, 70, 120)]  # full-height wall recess; no perch
for plan in (SECOND, LAST):
    plan["dais"] = [(60, 100, 68, 108)]  # one-node step, accessible all round
    plan["arrival"] = (20, 24)
    plan["door"] = (44, 104, 45, 112)
LAST["landings"] = [(96, 48, 120, 52), (96, 84, 120, 88)]
LAST["pack_c"] = [(106, 116), (110, 116), (108, 114), (108, 118)]


def reflected(plan, axis):
    """Nodes/physical points reflect at 63.5; exclusive index bounds at 64."""
    result = deepcopy(plan)
    def point(p):
        x, z = p
        return (127 - x, z) if axis == "x" else (x, 127 - z)
    def rect(r):
        x0, z0, x1, z1 = r
        return ((128 - x1, z0, 128 - x0, z1) if axis == "x" else
                (x0, 128 - z1, x1, 128 - z0))
    result["rooms"] = [(n, title, rect(r)) for n, title, r in plan["rooms"]]
    for key in ("passages", "screens", "pillars", "dais", "press", "landings"):
        if key in plan:
            result[key] = [rect(r) for r in plan[key]]
    result["cuts"] = {n: [rect(r) for r in rs] for n, rs in plan["cuts"].items()}
    result["features"] = [(c, *point((x, z))) for c, x, z in plan["features"]]
    result["floor"] = [point(p) for p in plan["floor"]]
    result["walls"] = [(point(start), point(end)) for start, end in plan["walls"]]
    result["arrival"] = point(plan["arrival"])
    result["door"] = rect(plan["door"])
    if plan["lake"]:
        result["lake"] = rect(plan["lake"])
        result["pack_c"] = [point(p) for p in plan["pack_c"]]
    result["mirror"] = axis
    return result


SECOND = reflected(SECOND, "x")
LAST = reflected(LAST, "z")
PLANS = (SECOND, LAST)


def inside(x, z, rect):
    x0, z0, x1, z1 = rect
    return x0 <= x < x1 and z0 <= z < z1


def blocked(plan, x, z):
    return any(inside(x, z, r) for r in
               plan["screens"] + plan["press"] +
               [r for rs in plan["cuts"].values() for r in rs])


def floor_cell(plan, x, z):
    if blocked(plan, x, z):
        return "#"
    if not any(inside(x, z, r) for r in [r[2] for r in plan["rooms"]] + plan["passages"]):
        return "#"
    if plan["lake"] and inside(x, z, plan["lake"]):
        return "p" if any(inside(x, z, r) for r in plan["pillars"]) else "~"
    return "^" if any(inside(x, z, r) for r in plan["dais"]) else "."


def room_label(plan, rect):
    x0, z0, x1, z1 = rect
    symbols = plan["floor"] + [(x, z) for _, x, z in plan["features"]]
    for z in range(z0 + 2, z1 - 2):
        for x in range(x0 + 2, x1 - 2):
            clear = all(floor_cell(plan, x + dx, z + dz) in ".^" for dx, dz in
                        ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)))
            unmarked = all((x - sx) ** 2 + (z - sz) ** 2 >= 25 for sx, sz in symbols)
            if clear and unmarked:
                return x, z
    raise ValueError("Room has no label space")


def text_grid(plan):
    rows = [[floor_cell(plan, x, z) for x in range(2, 128, 4)]
            for z in range(2, 128, 4)]
    # Coarse symbols mark cells containing a feature, not its exact centre.
    for n, _, rect in plan["rooms"]:
        x, z = room_label(plan, rect)
        rows[z // 4][x // 4] = n
    for x, z in plan["floor"]:
        rows[z // 4][x // 4] = "f"
    for (x, z), _ in plan["walls"]:
        rows[int(z // 4)][min(int(x // 4), 31)] = "w"
    for c, x, z in plan["features"]:
        rows[z // 4][x // 4] = c
    return "\n".join("".join(row) for row in rows)


def coordinate_table(plan):
    def points(ps):
        return ", ".join(f"({x:g},{z:g})" for x, z in ps)
    def rect(r):
        return "[" + ",".join(str(v) for v in r) + ")"
    def features(chars):
        return [(x, z) for c, x, z in plan["features"] if c in chars]
    rows = [("Pack anchors a / b / c / d; boss", points(features("abcd")) + "; " + points(features("B"))),
            ("F1–F4; pick 2", points(plan["floor"][:4]))]
    if plan["lake"]:
        rows.append(("F5–F8; pick 2", points(plan["floor"][4:8])))
    else:
        rows.append(("F5–F6; pick 1; F7–F8; pick 1", points(plan["floor"][4:6]) + "; " + points(plan["floor"][6:8])))
    rows.append(("F9–F12; pick 2", points(plan["floor"][8:])))
    for i in range(0, len(plan["walls"]), 2):
        shots = []
        for start, end in plan["walls"][i:i + 2]:
            direction = ("+x" if end[0] > start[0] else "−x") if end[0] != start[0] else "+z"
            shots.append(points([start]) + " → " + points([end]) + ", " + direction)
        rows.append((f"W{i + 1} / W{i + 2}; pick 1", " / ".join(shots)))
    mines = [(c, x, z) for c, x, z in plan["features"] if c in "og"]
    rows.extend([
        ("Ore / gem on route", points([m[1:] for m in mines[:2]])),
        ("Store ore / gems", points([m[1:] for m in mines[2:] if m[0] == "o"]) + " / " + points([m[1:] for m in mines[2:] if m[0] == "g"])),
        ("Start / arrival / chest / end", points(features("S") + [plan["arrival"]] + features("C") + features("E"))),
    ])
    x0, z0, _, z1 = plan["door"]
    dx, dz = features("D")[0]
    rows.extend([
        ("Reward door", f"x={x0}, z={z0}–{z1 - 1}, y={plan['y']}–{plan['y'] + 5}; marker ({dx},{plan['y'] + 2},{dz})"),
        ("Passages, in route order", ", ".join(rect(r) for r in plan["passages"])),
        ("Boss dais; top node y", rect(plan["dais"][0]) + f"; y={plan['y']} (one step)"),
    ])
    if plan["screens"]:
        rows.append(("Full-height rock screen", rect(plan["screens"][0])))
    if plan["lake"]:
        rows.extend([
            ("Basin; approach / exit landing", rect(plan["lake"]) + "; " + " / ".join(rect(r) for r in plan["landings"])),
            ("P1–P5, in crossing order", ", ".join(rect(r) for r in plan["pillars"])),
            ("Pack c: 2 normal Seeps / elite Seep / Wisp", points(plan["pack_c"])),
            ("Static press recess", rect(plan["press"][0])),
        ])
    return "| Places | Coordinates (x,z), in listed order |\n|---|---|\n" + "\n".join(f"| {name} | {value} |" for name, value in rows)


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
    for cuts in plan["cuts"].values():
        for rect in cuts:
            box(rect, COLORS["rock"])
    for rect in plan["press"]:
        box(rect, COLORS["press"])
    for rect in plan["dais"]:
        box(rect, COLORS["dais"])
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
    # Trace the carved silhouette, including niches and wall-side recesses.
    for z in range(128):
        for x in range(128):
            if floor_cell(plan, x, z) == "#":
                continue
            for dx, dz, start, end in (
                (-1, 0, (x, z), (x, z + 1)),
                (1, 0, (x + 1, z), (x + 1, z + 1)),
                (0, -1, (x, z), (x + 1, z)),
                (0, 1, (x, z + 1), (x + 1, z + 1)),
            ):
                if floor_cell(plan, x + dx, z + dz) == "#":
                    draw.line((point(*start), point(*end)), fill=COLORS["ink"], width=2)
    for n, _, rect in plan["rooms"]:
        label(point(*room_label(plan, rect)), n, 20, anchor="mm")
    for x0, z0, x1, z1 in plan["press"]:
        label(point((x0 + x1) / 2, (z0 + z1) / 2), "press", 17, "white", "mm")
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
            box(plan["door"], color)
            x0, z0, x1, _ = plan["door"]
            label(point((x0 + x1) / 2, z0 - 2), c, 18, color, "mm")
        else:
            radius = 14 if c in "og" else 19
            draw.ellipse((px - radius, pz - radius, px + radius, pz + radius), fill=color)
            label((px, pz), c, 20, "white", "mm")
    sx, y = 1130, 154
    label((sx, y), "ROOM ENVELOPES / [x0,z0,x1,z1)", 21)
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
    label((sx, y + 127), "Stepped outlines = solid wall / rock cuts", 18)
    label((sx, y + 156), "Darker boss floor = one-node dais", 18)
    label((sx, y + 185), "Geometry reflected on " + plan["mirror"] + " (127 - coordinate)", 18)
    label((64, 1210), plan["route"], 25)
    label((64, 1255), "a-d packs  |  B boss  |  D locked reward door  |  C personal chest inventory  |  S / E waystones", 22)
    label((64, 1293), "o ore place  |  g gem place  |  six floor traps selected  |  untouched rock seals every other route", 22)
    label((64, 1331), "The lake is crossed before the boss. Five pillars, six jumps; its section gives the exact gaps."
          if plan["lake"] else "One level. A full-height rock screen separates packs c and d. The boss court is solid and connected.", 21)
    return png_bytes(im)


def render_section():
    im, draw, label = canvas((1650, 1180))
    label((64, 30), "THE LAST MINT / LAKE SECTION", 36)
    label((64, 82), "Cut at x = 108; z DECREASES along the crossing. Physical node faces. Full box height: 64 nodes.", 22)
    # Equal scale in y and z. Read the reflected geometry, including passage roofs.
    ox, oy, scale = 110, 958, 12
    def p(z, y):
        return ox + (83 - z) * scale, oy - (y + 0.5) * scale
    def rect(z0, y0, z1, y1, fill):
        a, b = p(z0, y1), p(z1, y0)
        draw.rectangle((min(a[0], b[0]), a[1], max(a[0], b[0]), b[1]), fill=fill)
    rect(34.5, -0.5, 83.5, 63.5, COLORS["rock"])
    lake_room = next(r for n, _, r in LAST["rooms"] if n == "L")
    for z in range(35, 84):
        if inside(108, z, LAST["lake"]):
            rect(z - 0.5, 7.5, z + 0.5, 59.5, "#eee4d2")
            rect(z - 0.5, 1.5, z + 0.5, 7.5, COLORS["water"])
        elif inside(108, z, lake_room):
            rect(z - 0.5, 31.5, z + 0.5, 59.5, "#eee4d2")
        elif any(inside(108, z, r) for r in LAST["passages"]):
            rect(z - 0.5, 31.5, z + 0.5, 37.5, "#eee4d2")
    for i, (_, z0, _, z1) in enumerate(LAST["pillars"], 1):
        rect(z0 - 0.5, 1.5, z1 - 0.5, 31.5, COLORS["floor"])
        label(p((z0 + z1 - 1) / 2, 30), f"P{i}", 18, anchor="mt")
    for y in (0, 8, 16, 24, 32, 40, 48, 56, 64):
        yy = y - 0.5
        px, py = p(83.5, yy)
        draw.line((px - 6, py, px, py), fill=COLORS["ink"], width=2)
        label((px - 16, py), str(yy), 17, anchor="rm")
    label((35, 142), "y", 21)
    for z in (80, 76, 70, 64, 58, 52, 46, 40):
        label(p(z - 0.5, -2), str(z - 0.5), 14, anchor="mt")
    label((755, 997), "z", 21)
    # Walk from the approach, across P1..P5, onto the exit landing.
    tops = [LAST["landings"][0]] + LAST["pillars"] + [LAST["landings"][1]]
    for before, after in zip(tops, tops[1:]):
        start, end = before[1] - 0.5, after[3] - 0.5
        pts = [p(start + (end - start) * t / 20, 31.5 + 4 * (t / 20) * (1 - t / 20)) for t in range(21)]
        draw.line(pts, fill="#276c64", width=2)
    for i, ((_, z), _) in enumerate(LAST["walls"], 1):
        px, py = p(z, 32.5)
        draw.ellipse((px - 4, py - 4, px + 4, py + 4), fill=COLORS["trap"])
        label(p(z, 36.5), f"W{i}", 15, COLORS["trap"], "mm")
    label(p(59.5, 46), "6 gaps x 2 nodes / rise 0", 20, anchor="mm")
    label(p(59.5, 41), "4 x 4 tops; all at y = 31.5", 18, anchor="mm")
    label(p(59.5, 11), "Lava surface y = 7.5", 20, anchor="mm")
    label(p(81.5, 42), "37.5", 16, "#fff3cd", "mm")
    label(p(37, 42), "37.5", 16, "#fff3cd", "mm")
    sx, sy = 820, 170
    rows = [
        ("GEOMETRY", 25),
        ("Box: node centres y=0..63; faces -0.5..63.5", 21),
        ("Sealed roof: y=60..63; bottom: y=0..1", 21),
        ("Rim and tops: solid through node y=31", 21),
        ("Passage air y=32..37; ceiling face 37.5", 21),
        ("Lava: y=2..7; 24 nodes below the tops", 21),
        ("No ledge, ladder, low shelf or route round the rim", 21),
        ("", 18),
        ("ORDINARY JUMPS", 25),
        ("Five pillars; six equal, level jumps", 21),
        ("Every gap is 2 empty node columns", 21),
        ("4 nodes of runway and 4 x 4 landing space", 21),
        ("Walk speed 4; jump speed 6.5; gravity 19.62", 21),
        ("Ideal rise 1.08; flight 0.663 s; travel 2.65", 21),
        ("Approach at walking speed; no Sprint or Blink", 21),
        ("Arcs schematic. Desktop + web test remains open.", 20),
        ("", 18),
        ("FIREBALLS", 25),
        ("Two of four wall sockets; period 6 s; speed 8", 21),
        ("Shots cross x at y=32.5, through the gaps", 21),
        ("All tops safe: wait one step back, then jump", 21),
        ("No mobs or floor traps on the pillars", 21),
        ("Fall: lava takes 20% of actual max HP each second", 21),
    ]
    for text, size in rows:
        label((sx, sy), text, size)
        sy += 34 if size < 25 else 42
    label((64, 1060), "Approach z=[76,80), exit z=[40,44); passage roofs remain above the run-up and the way out.", 22)
    label((64, 1100), "Room 2 > approach > P1 > P2 > P3 > P4 > P5 > exit > room 3. Boss room 5 is on solid floor.", 21)
    return png_bytes(im)


def sync_document(plan, check):
    path = ROOT / f"docs/planning/round72-{plan['id']}.md"
    text = path.read_text()
    for name, body in (("coordinates", coordinate_table(plan)),
                       ("grid", "```text\n" + text_grid(plan) + "\n```")):
        start, end = f"<!-- floorplan-{name}:start -->", f"<!-- floorplan-{name}:end -->"
        a, b = text.index(start), text.index(end) + len(end)
        text = text[:a] + start + "\n" + body + "\n" + end + text[b:]
    if check:
        return text == path.read_text()
    path.write_text(text)
    return True


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
    for plan in PLANS:
        if not sync_document(plan, args.check):
            bad.append(f"docs/planning/round72-{plan['id']}.md (table/grid)")
    if bad:
        raise SystemExit("Stale: " + ", ".join(bad))
    print("Three PNGs, both coordinate tables and both grids " +
          ("match the generator." if args.check else "written."))


if __name__ == "__main__":
    main()
