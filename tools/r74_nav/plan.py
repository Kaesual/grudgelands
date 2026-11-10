#!/usr/bin/env python3
"""The engine run's points (Round 74 NAV, round74-plan.md section 4 NAV, verification 3).

    python3 tools/r74_nav/plan.py OUT.lua

Writes one Lua table the probe (grug_probe_r74_nav) reads, the same for the run on the
lane's branch and the baseline on 0.73.1, so both drag the same mobs to the same cells.
Per Expedition, box-relative cells {x, y, z} (y the feet row):

  drags[home]   {corner, stairs}: for a pack mob whose home is `home` ("x,y,z", the
                marker or a spread cell), a cell 20 to 40 nodes' walk away whose straight
                line home is blocked (behind corners), and a cell 15 to 35 nodes' walk away
                at another height, the most different first (across stairs); each the k-th best for
                the k-th home of its room, so a pack spreads out
  lake          The Last Mint: cells on the far side of the lake, for three mobs of the
                near side's packs (no walk home over the grid: mobs do not leap)
  centre        the walking cell nearest the box's middle: the player stands there while
                the mobs walk, so every block of the box stays active
  chase[room]   a cell 15 to 30 nodes' walk from the room's markers, out of their
                straight lines, within 26 nodes of every marker (the pack's jump range 32
                less the spread), 5 from every drop (the lake, a pit), outside the boss's
                room, 24 nodes from every other pack's markers and 4 from every
                ambush zone (relaxed to 12 to 30 and 16 nodes, then to no distance and half
                the markers out of sight, where none is)

Walks are over the walk grid (walkgrid.py), for the body class of the room's widest mob.
"""
import heapq
import importlib.util
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATES = HERE.parent / "expedition_templates"
sys.path.insert(0, str(TEMPLATES))
import registry  # noqa: E402
import walkgrid  # noqa: E402

NAMES = ("stilled_seam", "second_shift", "last_mint")
SPREAD = ((0, 0), (3, 0), (-3, 0), (0, 3), (0, -3), (3, 3), (-3, 3), (3, -3), (-3, -3))
# tools/r74_nav/portable_test.lua WIDTH: the larger side of each roster mob's box.
WIDTH = {"grug_mobs:giant_spider": 2.1, "grug_mobs:stone_golem": 0.6, "grug_mobs:flintback": 0.6,
         "grug_mobs:lava_flan": 1.0, "grug_mobs:ember_wisp": 0.4, "grug_mobs:land_guard": 1.0,
         "grug_mobs:duewarden": 1.0, "grug_mobs:zombie": 0.6, "grug_mobs:skeleton_raider": 0.6,
         "grug_mobs:auditor_nemm": 0.6}


def class_of(width):
    if width <= 1:
        return 1
    if width <= 2:
        return 2
    return math.ceil(width / 2 - 0.5) + 2


def usable(g, x, z, cls):
    h = g.h(x, z)
    if h is None or g.flags[g.at(x, z)] & 1:
        return False
    if cls == 1:
        return True
    if cls == 2:
        return g.flags[g.at(x, z)] >= 2
    return g.clear[g.at(x, z)] >= cls - 1


def distances(g, start, cls):
    """Walk distances in nodes (5 a straight move, 7 a diagonal, divided by 5)."""
    dist = {start: 0}
    queue = [(0, start)]
    while queue:
        d, (x, z) = heapq.heappop(queue)
        if d > dist[(x, z)]:
            continue
        mask = g.mask[g.at(x, z)]
        for bit, (dx, dz) in enumerate(walkgrid.MOVES):
            n = (x + dx, z + dz)
            if mask & (1 << bit) and usable(g, *n, cls):
                nd = d + (7 if bit >= 4 else 5)
                if nd < dist.get(n, 1 << 30):
                    dist[n] = nd
                    heapq.heappush(queue, (nd, n))
    return {cell: d / 5 for cell, d in dist.items()}


def line_blocked(g, a, b):
    """The straight line from cell a to b leaves the walking cells or steps more than one."""
    (ax, az), (bx, bz) = a, b
    steps = max(1, int(math.hypot(bx - ax, bz - az) * 4))
    last = g.h(ax, az)
    for k in range(steps + 1):
        x = int(math.floor(ax + (bx - ax) * k / steps + 0.5))
        z = int(math.floor(az + (bz - az) * k / steps + 0.5))
        h = g.h(x, z)
        if h is None or abs(h - last) > 1:
            return True
        last = h
    return False


def standable(t, x, y, z):
    def walk(n):
        return n != "air" and registry.definition(n).get("walkable", True) and not registry.liquid(n)
    try:
        return not walk(t.get(x, y, z)) and not walk(t.get(x, y + 1, z)) and \
            not registry.liquid(t.get(x, y, z)) and walk(t.get(x, y - 1, z))
    except ValueError:
        return False


def lua(value):
    if isinstance(value, dict):
        return "{" + ", ".join(f"[{lua(k)}] = {lua(v)}" for k, v in value.items()) + "}"
    if isinstance(value, (list, tuple)):
        return "{" + ", ".join(lua(v) for v in value) + "}"
    if isinstance(value, str):
        return '"' + value + '"'
    return str(value)


def plan_for(t, g):
    rooms = {}
    for room, mob, count, tier, x, y, z in t.encounters:
        if tier == "critter":
            continue
        rooms.setdefault(room, []).append((mob, count, tier, x, y, z))
    ambush_rooms = {row[2] for row in t.ambushes}
    out = {"drags": {}, "chase": {}, "lake": []}
    for room, rows in sorted(rooms.items()):
        cls = max(class_of(WIDTH[mob] * (1.4 if tier in ("elite", "boss") else 1)) for mob, *_ in rows)
        homes = []
        for mob, count, tier, x, y, z in rows:
            for k in range(count):
                ox, oz = SPREAD[k % len(SPREAD)]
                cand = [(x + ox, y, z + oz), (x, y, z)]
                homes += [c for c in cand if c not in homes]
        for k, (hx, hy, hz) in enumerate(homes):
            if not usable(g, hx, hz, cls):
                continue
            dist = distances(g, (hx, hz), cls)
            corner = sorted(((d / max(1.0, math.hypot(x - hx, z - hz)), (x, z)) for (x, z), d in dist.items()
                             if 20 <= d <= 40 and line_blocked(g, (hx, hz), (x, z))), reverse=True)
            stairs = sorted(((abs(g.h(x, z) - hy), d / max(1.0, math.hypot(x - hx, z - hz)), (x, z))
                             for (x, z), d in dist.items()
                             if 15 <= d <= 35 and abs(g.h(x, z) - hy) >= 1), reverse=True)
            pick = []
            for ranked in (corner, stairs):
                if ranked:
                    x, z = ranked[min(k * 3, len(ranked) - 1)][-1]
                    pick.append((x, g.h(x, z), z))
                else:
                    pick.append(None)
            out["drags"][f"{hx},{hy},{hz}"] = [p if p else "none" for p in pick]
        if room in ambush_rooms or any(tier == "boss" for _, _, tier, *_ in rows):
            continue
        markers = [(x, z) for *_, x, _, z in rows]
        near = [distances(g, m, 1) for m in markers if usable(g, *m, 1)]
        others = [(x, z) for r, rr in rooms.items() if r != room for *_, x, _, z in rr]
        boss = None
        if "boss_room_min" in t.places:
            (bx0, _, bz0), (bx1, _, bz1) = t.places["boss_room_min"], t.places["boss_room_max"]
            boss = (min(bx0, bx1) - 2, min(bz0, bz1) - 2, max(bx0, bx1) + 2, max(bz0, bz1) + 2)

        def near_drop(x, z, h):
            """A column within 5 with no floor and air at the cell's body rows: a lake, a pit."""
            for dz in range(-5, 6):
                for dx in range(-5, 6):
                    nx, nz = x + dx, z + dz
                    if 0 <= nx < g.sx and 0 <= nz < g.sz and g.h(nx, nz) is None and \
                            t.get(nx, h, nz) == "air" and t.get(nx, h + 1, nz) == "air":
                        return True
            return False
        best = None
        for apart, low in ((24, 15), (16, 12), (0, 12)):
            for (x, z), d in near[0].items():
                if not low <= d <= 30 or g.flags[g.at(x, z)] & 1:
                    continue
                if any(math.hypot(x - ox, z - oz) < apart for ox, oz in others):
                    continue
                if any(x0 - 4 <= x <= x1 + 4 and z0 - 4 <= z <= z1 + 4 for _, _, _, x0, _, z0, x1, z1 in t.ambushes):
                    continue
                blocked = sum(1 for m in markers if line_blocked(g, m, (x, z)))
                if blocked < (len(markers) if apart else (len(markers) + 1) // 2):
                    continue
                # Round 74 fix round: every member within the pack's jump range (32,
                # packs.lua JUMP_RANGE) with the spread's 4 to spare, no drop near (the
                # player is pushed by the pack's hits), outside the boss's room.
                if any(math.hypot(x - mx, z - mz) > 26 for mx, mz in markers):
                    continue
                if boss and boss[0] <= x <= boss[2] and boss[1] <= z <= boss[3]:
                    continue
                if near_drop(x, z, g.h(x, z)):
                    continue
                score = sum(n.get((x, z), 99) for n in near) / len(near)
                if best is None or score > best[0]:
                    best = (score, (x, g.h(x, z), z))
            if best:
                break
        out["chase"][room] = best[1] if best else "none"
    cx, cz = g.sx // 2, g.sz // 2
    x, z = min(((x, z) for z in range(g.sz) for x in range(g.sx) if g.h(x, z) is not None),
               key=lambda c: (c[0] - cx) ** 2 + (c[1] - cz) ** 2)
    out["centre"] = (x, g.h(x, z), z)
    if t.name == "last_mint":
        comp = walkgrid.components(g)
        far = sorted(((abs(x - 108) + abs(z - 40), (x, z)) for (x, z), k in comp.items()
                      if k == comp[(64, 23)] and usable(g, x, z, 2)))
        out["lake"] = [(x, g.h(x, z), z) for _, (x, z) in far[0:9:3]]
    return out


def main():
    out_path = Path(sys.argv[1])
    spec = importlib.util.spec_from_file_location("build", TEMPLATES / "build.py")
    build = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(build)
    plans = {}
    for template, grid in build.build_all():
        if template.name in NAMES:
            plans[template.name] = plan_for(template, grid)
            p = plans[template.name]
            print(template.name, len(p["drags"]), "homes,",
                  sum(1 for v in p["drags"].values() if v[0] != "none"), "corner,",
                  sum(1 for v in p["drags"].values() if v[1] != "none"), "stairs; chase",
                  p["chase"], "lake", p["lake"])
    out_path.write_text("-- Written by tools/r74_nav/plan.py; the engine run's points.\nreturn " + lua(plans) + "\n")


if __name__ == "__main__":
    main()
