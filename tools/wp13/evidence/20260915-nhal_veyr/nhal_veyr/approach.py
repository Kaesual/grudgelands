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

So this one reads `-approach.tsv`, which `capital_probe` writes for whichever of
the four axes the free terrain falls furthest over 230..261, out to 261 and not
240, and measures the span of EVERY cell in a column -- and, when it is handed
the terrain mode's `-wall.tsv` as well, checks the built road top against the
FREE TERRAIN height rather than against itself.

What it prints, per carriageway column of the axis in the dump:

  * `span`: the full course count of the column as built, fill included.
  * `top`: the road's own top course.
  * `rail`: whether the kerb lane carries the rail course.
  * and at the gate point (|p| = 256), the built top against the free terrain.

The offline gate table of `tools/wp13/nhal_veyr_plots.lua` measures all four
axes on all nine seeds; this is the one that reads a FINISHED MAP back.
"""
import collections
import re
import sys

ROAD = {"grug_decor:castle_pavement_brick",
        "grug_decor:castle_pavement_brick_stair",
        "grug_decor:castle_pavement_brick_slab"}
RAIL = "grug_decor:castle_dungeon_stone"
GATE_POINT = 256
HALF = 2            # avenue.WIDTH == 5: lanes -2..2 are carriageway
CORE = 52           # the core's own paving is not road


def read(path):
    header = ""
    cells = []
    for line in open(path):
        if line.startswith("#"):
            header += line
            continue
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 4:
            continue
        cells.append((int(parts[0]), int(parts[1]), int(parts[2]), parts[3]))
    return header, cells


header, cells = read(sys.argv[1])
match = re.search(r"(north|south|east|west) gate approach", header)
if not match:
    sys.exit("approach.py: %s carries no gate-approach header" % sys.argv[1])
axis = match.group(1)
sign = 1 if axis in ("north", "east") else -1
along = (lambda x, z: z) if axis in ("north", "south") else (lambda x, z: x)
across = (lambda x, z: x) if axis in ("north", "south") else (lambda x, z: z)

ground = {}
if len(sys.argv) > 2:
    for line in open(sys.argv[2]):
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 6 or parts[0] != axis:
            continue
        try:
            ground[(int(parts[3]), int(parts[4]))] = int(parts[5])
        except ValueError:
            continue

column = collections.defaultdict(list)
for x, y, z, name in cells:
    if name == "air":
        continue
    column[(x, z)].append((y, name))

print("axis=%s  columns=%d" % (axis, len(column)))
print("p\tlane\tspan\ttop\tfree\tstep\trail")
histogram = collections.Counter()
worst_span, worst_at = 0, None
bad = []
for (x, z), stack in sorted(column.items(), key=lambda kv: (along(*kv[0]),
                                                            across(*kv[0]))):
    p, lane = along(x, z), across(x, z)
    if abs(lane) > HALF or abs(p) <= CORE:
        continue
    road = [y for y, n in stack if n in ROAD]
    if not road:
        continue
    ys = [y for y, n in stack]
    span = max(ys) - min(ys) + 1
    top = max(road)
    rail = any(n == RAIL and y == top + 1 for y, n in stack)
    free = ground.get((x, z))
    step = "" if free is None else abs(top - free)
    histogram[span] += 1
    if span > worst_span:
        worst_span, worst_at = span, (p, lane)
    if abs(p) == GATE_POINT or span >= 3:
        print("%d\t%d\t%d\t%d\t%s\t%s\t%s" % (p, lane, span, top,
              "-" if free is None else free, "-" if step == "" else step,
              "yes" if rail else "no"))
    if free is not None and abs(p) == GATE_POINT and top != free:
        bad.append((p, lane, top, free))
    # nothing floating: the column must be solid from its own floor up
    holes = set(range(min(ys), max(ys) + 1)) - set(ys)
    if holes:
        bad.append((p, lane, "holes", sorted(holes)))

print("\ndeepest built column: %d courses at %s" % (worst_span, worst_at))
for span in sorted(histogram):
    print("   span %2d: %d columns" % (span, histogram[span]))
if bad:
    print("\nFINDINGS:")
    for row in bad:
        print("  ", row)
    sys.exit(1)
print("\nevery carriageway column is solid and the road top at the gate point "
      "is the free terrain there")
