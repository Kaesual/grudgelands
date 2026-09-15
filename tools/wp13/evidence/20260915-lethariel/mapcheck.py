#!/usr/bin/env python3
"""What the BUILT MAP says about the east gate and the mere.

    python3 mapcheck.py <run output dir>

Reads the probe's own anchor-relative `<key>-avenue.tsv` -- the region it dumped
back OUT OF THE FINISHED MAP -- and answers the two questions the fix round of
2026-09-16 exists for:

  1. the threshold over the gate leaves the road its headroom;
  2. the road over the mere is a deck on piers, and the water under it is still
     one sheet.
"""
import collections
import sys

root = sys.argv[1]
MIN_CLEAR = 3

WATER = {"default:river_water_source", "default:river_water_flowing",
         "default:water_source", "default:water_flowing"}
AIR = {"air", "ignore"}
PILLAR = "castle_pillar"
DECK = {"grug_decor:castle_pavement_brick", "grug_decor:darkage_serpentine"}


def read(path):
    cells, anchor = {}, None
    with open(path) as handle:
        for line in handle:
            if line.startswith("#"):
                if line.startswith("# anchor"):
                    anchor = line.split()[2]
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 4:
                continue
            cells[(int(parts[0]), int(parts[1]), int(parts[2]))] = parts[3]
    return cells, anchor


cells, anchor = read(root + "/lethariel-avenue.tsv")
base_y = int(anchor.split(",")[1])
ys = [y for (_, y, _) in cells]
print("avenue dump: %d cells, anchor %s, relative y %d..%d"
      % (len(cells), anchor, min(ys), max(ys)))

# ---- 1. the east threshold -------------------------------------------------
GATE = 256
print("\n== the east threshold, x = %d (absolute y) ==" % GATE)
deck = None
for (x, y, z), name in cells.items():
    if x == GATE and -2 <= z <= 2 and name in DECK:
        if deck is None or y > deck:
            deck = y
pillar_top = None
for (x, y, z), name in cells.items():
    if 254 <= x <= 258 and PILLAR in name:
        if pillar_top is None or y > pillar_top:
            pillar_top = y
pillars = {(x, z) for (x, y, z), n in cells.items()
           if 254 <= x <= 258 and PILLAR in n}
print("  the road's deck at the gate: y = %d" % (base_y + deck))
print("  the threshold's pillars: %d columns at %s, top course y = %d"
      % (len(pillars), sorted(pillars), base_y + pillar_top))
print("  the lintel stands one course over the pillars: y = %d"
      % (base_y + pillar_top + 1))
air = pillar_top + 1 - deck - 1
print("  air over the carriageway: %d (MIN_CLEAR %d) -> %s"
      % (air, MIN_CLEAR, "OK" if air >= MIN_CLEAR else "TOO LOW"))
print("  (the dump's own ceiling is relative y %d, so the lintel course itself"
      % max(ys))
print("   is one node above the window; the pillar top is what the map shows.)")

# ---- 2. the mere under the road -------------------------------------------
print("\n== the mere in the avenue dump ==")
water = [(x, y, z) for (x, y, z), n in cells.items() if n in WATER]
if not water:
    print("  no water in this dump")
    sys.exit(0)
top = max(y for _, y, _ in water)
surface = {(x, z) for (x, y, z) in water if y == top}
print("  water cells %d, surface at relative y %d (absolute %d), %d columns"
      % (len(water), top, base_y + top, len(surface)))

# Columns of the CARRIAGEWAY that are over the lake: those whose column holds
# water anywhere. At the water surface each of them is either open water or a
# pier.
wet_columns = {(x, z) for (x, y, z) in water}
road_wet = {c for c in wet_columns if -2 <= c[1] <= 2}
open_, blocked = 0, 0
for (x, z) in sorted(road_wet):
    name = cells.get((x, top, z))
    if name in WATER:
        open_ += 1
    elif name is not None and name not in AIR:
        blocked += 1
print("  carriageway columns over the lake: %d" % len(road_wet))
print("    open water at the surface: %d" % open_)
print("    solid at the surface:      %d" % blocked)

# AND THE OTHER WAY TO LOSE A LAKE: not paving it but EMPTYING it. A column of
# the deck's own footprint that holds no water cell at the surface layer is a
# hole, and a row of them under the deck separates the water either side of the
# crossing exactly as a causeway would. The first bridge cleared the cell one
# under the deck unconditionally, which with a lift of one node IS the surface;
# the fix of 2026-09-16 stops the clear at the surface.
deck_columns = {(x, z) for (x, y, z), n in cells.items()
                if n in DECK and -2 <= z <= 2} & road_wet
holes = sorted(c for c in deck_columns
               if cells.get((c[0], top, c[1])) is None
               or cells.get((c[0], top, c[1])) in AIR)
print("  carriageway deck columns whose surface layer is air (a hole): %d -> %s"
      % (len(holes), "OK" if not holes else "TRENCH at %s" % holes[:8]))

verge_wet = {c for c in wet_columns if abs(c[1]) == 3}
piers = 0
for (x, z) in sorted(verge_wet):
    name = cells.get((x, top, z))
    if name is not None and name not in AIR and name not in WATER:
        piers += 1
print("  verge columns over the lake: %d, of which %d carry a pier"
      % (len(verge_wet), piers))

seen, bodies = set(), []
for cell in surface:
    if cell in seen:
        continue
    stack, size = [cell], 0
    seen.add(cell)
    while stack:
        cx, cz = stack.pop()
        size += 1
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nxt = (cx + dx, cz + dz)
            if nxt in surface and nxt not in seen:
                seen.add(nxt)
                stack.append(nxt)
    bodies.append(size)
bodies.sort(reverse=True)
print("  connected bodies of that surface inside the dump window: %d  sizes %s"
      % (len(bodies), bodies[:8]))
print("  (the window is the AVENUE CORRIDOR only -- seven lanes plus verges --")
print("   so a body count here says whether the strip is continuous, not")
print("   whether the mere is: that is `lethariel_plots.lua --bodies`, which")
print("   counts the whole 533x533 window and is the ruling's measurement.)")
