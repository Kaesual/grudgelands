"""Does the avenue arrive at its gate point on its own ground, AS BUILT?

    python3 approach.py <key>-approach.tsv [<key>-wall.tsv]

This replaces `embankment.py`, which the wave-2 review of 2026-09-16 showed
could not see the case it was quoted for, for three reasons worth keeping
written down:

  * it read the probe's `-avenue.tsv`, which dumps the EAST avenue and only the
    east avenue -- the flat axis at this capital, while the north road was the
    one standing over its ground;
  * it clipped at |x|, |z| <= 240, and the avenues run to 261, so the gate
    approach -- the exact band where the ground runs out -- was excluded by
    construction;
  * it measured `max - min` over the PAVING NAMES in a column. An embankment is
    fill under the road. Dur Brannoc's own threshold is the span of ALL the
    piece's cells in a kerb column.

So this one reads `-approach.tsv`, the region `capital_probe` writes for
whichever of the four axes the free terrain falls furthest over 230..261, out to
261 and not 240.

READING A ROAD OUT OF A MAP, and the two traps in it. The dump is
ANCHOR-RELATIVE in all three axes (its own `# anchor` line gives the origin) and
it SKIPS AIR, so a column's rows are the solid nodes only. And the highest
road-named cell in a gate column is not the road: a gatehouse's fighting floor
is laid in the same paving, twelve courses above the tunnel the road runs
through. So the road top here is found by CLIMBING FROM THE GROUND -- the last
solid course of the run that starts at the column's own terrain -- which is what
"the road stands on its own ground" means and is the only reading that cannot
pick up a storey of masonry by accident.

What it then checks:

  1. THE RAMP. Along the centre lane the road top changes by at most one node
     per column, over the whole dumped run.
  2. THE ARRIVAL. At the gate point (|p| = 256) the road top IS the free terrain
     there, read from the terrain mode's `-wall.tsv` when it is given one.
  3. NOTHING FLOATS. No carriageway column has air under its road top.
  4. THE RAIL. Wherever the road stands three or more courses above the free
     terrain, the kerb lanes carry their rail course.

The offline gate table of `tools/wp13/nhal_veyr_plots.lua` measures all four
axes on all nine seeds; this is the one that reads a FINISHED MAP back.
"""
import collections
import re
import sys

# The undead avenue's own surface vocabulary: the paving it lays flat, and the
# TREAD it caps a step with, which on a ramp descending a node a column is most
# of the road. Leaving the tread out is why the first version of this file found
# seventy-eight carriageway columns where the dump carries three hundred.
ROAD = {"grug_decor:castle_pavement_brick",
        "grug_decor:castle_pavement_brick_stair",
        "grug_decor:castle_pavement_brick_slab",
        "grug_decor:castle_dungeon_stone_stair"}
RAIL = "grug_decor:castle_dungeon_stone"
GATE_POINT = 256
HALF = 2            # avenue.WIDTH == 5: lanes -2..2 are carriageway
KERB = 2
RAIL_FILL = 3


def read(path):
    header, anchor, cells = "", None, []
    for line in open(path):
        if line.startswith("#"):
            header += line
            m = re.match(r"# anchor (-?\d+),(-?\d+),(-?\d+)", line)
            if m:
                anchor = tuple(int(v) for v in m.groups())
            continue
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 4:
            continue
        cells.append((int(parts[0]), int(parts[1]), int(parts[2]), parts[3]))
    return header, anchor, cells


header, anchor, cells = read(sys.argv[1])
match = re.search(r"(north|south|east|west) gate approach", header)
if not match:
    sys.exit("approach.py: %s carries no gate-approach header" % sys.argv[1])
if anchor is None:
    sys.exit("approach.py: %s carries no anchor line" % sys.argv[1])
anchor_y = anchor[1]
axis = match.group(1)
along = (lambda x, z: z) if axis in ("north", "south") else (lambda x, z: x)
across = (lambda x, z: x) if axis in ("north", "south") else (lambda x, z: z)

# The free terrain of the line the gate stands on, anchor-relative, out of the
# terrain mode's wall dump (whose heights are absolute).
ground = {}
if len(sys.argv) > 2:
    for line in open(sys.argv[2]):
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 6 or parts[0] != axis:
            continue
        try:
            ground[(int(parts[3]), int(parts[4]))] = int(parts[5]) - anchor_y
        except ValueError:
            continue

column = collections.defaultdict(dict)
for x, y, z, name in cells:
    column[(x, z)][y] = name

findings = []
tops, rails, fills = {}, {}, {}
for (x, z), stack in column.items():
    lane = across(x, z)
    if abs(lane) > HALF:
        continue
    free = ground.get((x, z))
    if free is None:
        # No terrain row for this column: start the climb at the lowest solid
        # course the dump carries, which is the bottom of the region.
        start = min(stack)
    else:
        start = free
        while start not in stack and start > min(stack):
            start -= 1          # the road may sit in a cutting
    if start not in stack:
        continue
    y = start
    while (y + 1) in stack:
        y += 1
    if stack[y] not in ROAD:
        continue                # not a carriageway column of this road
    tops[(x, z)] = y
    if free is not None:
        fills[(x, z)] = y - free
        if free not in stack:
            findings.append(("floating", x, z, y, free))
    rails[(x, z)] = stack.get(y + 1) == RAIL

# 1. the ramp, along the centre lane
centre = sorted((along(x, z), y) for (x, z), y in tops.items()
                if across(x, z) == 0)
worst_step, worst_at = 0, None
for (p, y), (q, w) in zip(centre, centre[1:]):
    if q == p + 1 and abs(w - y) > worst_step:
        worst_step, worst_at = abs(w - y), q
if worst_step > 1:
    findings.append(("ramp", worst_at, worst_step))

print("axis=%s  anchor_y=%d  carriageway columns=%d" % (axis, anchor_y,
                                                        len(tops)))
print("worst step along the centre lane: %d node(s)%s" % (
    worst_step, "" if worst_at is None else " at %d" % worst_at))
print("\np\tlane\ttop(abs)\tfree(abs)\tstep\tfill\trail")
gate_rows = 0
for (x, z), y in sorted(tops.items(), key=lambda kv: (along(*kv[0]),
                                                      across(*kv[0]))):
    p, lane = along(x, z), across(x, z)
    free = ground.get((x, z))
    if free is None:
        continue
    fill = fills[(x, z)]
    step = abs(y - free) if abs(p) == GATE_POINT else ""
    print("%d\t%d\t%d\t%d\t%s\t%d\t%s" % (p, lane, y + anchor_y,
                                          free + anchor_y, step, fill,
                                          "yes" if rails[(x, z)] else "no"))
    gate_rows += 1
    if abs(p) == GATE_POINT and y != free:
        findings.append(("arrival", p, lane, y + anchor_y, free + anchor_y))
    if abs(lane) == KERB and fill >= RAIL_FILL and not rails[(x, z)]:
        findings.append(("unrailed", p, lane, fill))

print("\ncolumns with a known free terrain: %d" % gate_rows)
if findings:
    print("\nFINDINGS:")
    for row in findings:
        print("  ", row)
    sys.exit(1)
print("\nthe road steps at most one node a column, arrives at the gate point at "
      "the free terrain there, stands on its own ground, and is railed wherever "
      "it stands three courses above it")
