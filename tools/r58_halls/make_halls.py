#!/usr/bin/env python3
"""Write the six Miner's Guild house templates (Round 58 lanes HALLS, HALLS2).

    python3 tools/r58_halls/make_halls.py          # write the six .tpl files
    python3 tools/r58_halls/make_halls.py --check  # the committed files are
                                                   # this script's output

One parametric guild house, the same institution in every capital and built
from that capital's palette (docs/technical/building-template-format.md §3),
on a district plot of its own (HALLS2: the user moved it out of the civic
core so it has room for a miners' look; settlements.md "The Miner's Guild
houses"). The footprint is 17 x 17 (19 x 19 with its apron), which fits the
smallest district lot (Lethariel's, 23 x 23 with the plot's two-node ring):

  * the HALL on the west, 11 x 14: a stone plinth two courses high under a
    timber frame (posts at the corners and every third column, a top
    plate), the guild's emblem plaque over the door and its banners beside
    it, a gable roof in the civic roof (the human, dwarf, elf and undead
    capitals) or a flat deck behind a breastwork (the orc and troll ones);
    inside as HALLS built it: the exchange counter on the east side, the
    clerk's desk and the ore sorter's table on the west side, the leader's
    desk at the back under a frieze of the six tier stones;
  * the ORE YARD on the east, 6 wide, open to the street: a HEADFRAME over a
    grated shaft collar, four timber legs 15 high with three rings of beams,
    two sheave wheels on its head beam and the rope down to a tub, the
    guild's banners on its front; a rail from the shaft to the street with
    two ore carts; six heaps, one per tier (its host stone under its ore:
    copper, gold, silver, emberglass, abyssal crystal, diamond, as storage
    blocks, never ore nodes, which Ore Sense would mark); a stack of pit
    props, barrels and a coal bunker; mine lamps on the yard posts and under
    the headframe; a fence round the yard's two outer sides.

Every material is a palette role except the mining props, the banners, the
plaque, the heaps and the frieze. The banners and plaques are the picked
guild art (grug_mapgen `guild_banner_*`, `guild_emblem_*`), the rail and the
carts grug_mapgen's yard pieces.

The template frame (format doc §2): x east, z north, the street side is
z = -1 (the front), the hall's door faces -z; the district plot stands the
house unturned, so the front faces the plot's street.

The hall socket contract (settlements.md, "The Miner's Guild houses"): the
points `{id}_leader` (role quest), `{id}_exchange` (role idle, tag work: the
exchange counter, taken over by lane CAMPNPC as a service socket) and three
residents (`{id}_clerk`, `{id}_sorter`, `{id}_porter`); on the district plot
`miners_guild` the settlement registers them as `miners_guild/<id>`
(capital_services.lua `GUILD_HALL`).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "building_templates", "editor"))

import tplfile  # noqa: E402

OUT = os.path.join(REPO, "mods", "MAPGEN", "grug_mapgen", "building_templates",
                   "templates")

# The guilds' banners and emblem plaques (the user's pick, 2026-10-23).
GUILDS = {
    "charter": {"banner": "grug_mapgen:guild_banner_charter",
                "emblem": "grug_mapgen:guild_emblem_charter"},
    "oathdelvers": {"banner": "grug_mapgen:guild_banner_oathdelvers",
                    "emblem": "grug_mapgen:guild_emblem_oathdelvers"},
}

# The six houses: the roof style, the guild and the placing race. One
# footprint for all six (W x D), so every district lot holds it.
SPECS = [
    {"capital": "highcourt", "label": "Highcourt", "race": "human",
     "roof": "gable", "guild": "charter"},
    {"capital": "dur_brannoc", "label": "Dur Brannoc", "race": "dwarf",
     "roof": "gable", "guild": "charter"},
    {"capital": "lethariel", "label": "Lethariel", "race": "elf",
     "roof": "gable", "guild": "charter"},
    {"capital": "nhal_veyr", "label": "Nhal Veyr", "race": "undead",
     "roof": "gable", "guild": "oathdelvers"},
    {"capital": "gor_drazhak", "label": "Gor Drazhak", "race": "orc",
     "roof": "deck", "merlons": True, "guild": "oathdelvers"},
    {"capital": "kezamba", "label": "Kezamba", "race": "troll",
     "roof": "deck", "merlons": False, "guild": "oathdelvers"},
]

W, D = 17, 17     # the pivot footprint
HW = 11           # the hall's width (walls at x = 0 and HW - 1)
ZF = 3            # the hall's front wall; z = -1 .. ZF - 1 is the forecourt
WALL_TOP = 5      # the walls' top course
YX = HW           # the ore yard's first column (x = YX .. W - 1)
# The headframe: its four legs, its rings of beams, its head beam.
HF_X, HF_Z = (12, 15), (9, 12)
HF_RINGS = (5, 10, 15)
HF_HEAD = 16
# The frieze and the heaps: the host stones of the six depths, T1 to T6
# (registry.lua tier_at), and each tier's ore as its storage block.
TIERS = ["node default:stone", "node grug_materials:t2_stone",
         "node grug_materials:t3_stone", "node grug_materials:t4_stone",
         "node grug_materials:t5_stone", "node grug_materials:t6_stone"]
ORES = ["node grug_materials:copper_block", "node grug_materials:gold_block",
        "node grug_materials:silver_block", "node grug_materials:emberglass_block",
        "node grug_materials:abyssal_crystal_block",
        "node grug_materials:diamond_block"]
RAIL = "node grug_mapgen:mine_rail o=facedir:0"
CART = "node grug_mapgen:mine_cart o=facedir:0"
LANTERN = "node grug_decor:xdecor_lantern"
HANGING = "node grug_decor:xdecor_lantern_hanging"


def build(spec):
    """The house as {(x, y, z): entry text}, its points, its peak and top."""
    guild = GUILDS[spec["guild"]]
    banner = "node %s o=wallmounted:4" % guild["banner"]
    emblem = "node %s o=wallmounted:4" % guild["emblem"]
    cells = {}
    points = {"doors": [], "inside": [], "room_corner": [], "lights": [],
              "sockets": []}

    def put(x, y, z, entry):
        cells[(x, y, z)] = entry

    w = HW
    cx = (w - 1) // 2          # the door column
    zf = ZF                    # the front wall
    zb = D - 1                 # the back wall
    hz0, hz1 = zf + 1, zb - 1  # the hall's first and last row
    # 1. The ground: the apron ring, the forecourt and the yard in the path,
    # the foundation under the walls, the floor, a runner up the aisle.
    for z in range(-1, D + 1):
        for x in range(-1, W + 1):
            inside_walls = 0 <= x <= w - 1 and zf <= z <= zb
            on_wall = inside_walls and (x in (0, w - 1) or z in (zf, zb))
            if on_wall:
                put(x, 0, z, "role foundation")
            elif inside_walls:
                put(x, 0, z, "role floor")
            else:
                put(x, 0, z, "role path")
    for z in range(hz0, hz1 - 1):
        put(cx, 0, z, "role rug")

    # 2. The walls: a stone plinth two courses high, then the timber frame
    # (posts at the corners and every third column, the infill between, a
    # top plate), windows two high, the door in a stone surround, the
    # emblem plaque over it and the banners beside it.
    def window_rows(length):
        rows = set()
        z = 2
        while z + 1 <= length - 3:
            rows.update((z, z + 1))
            z += 4
        return rows
    side_windows = {hz0 - 1 + r for r in window_rows(zb - zf)}
    for y in range(1, WALL_TOP + 1):
        for z in range(zf, zb + 1):
            for x in range(0, w):
                if not (x in (0, w - 1) or z in (zf, zb)):
                    continue
                corner = x in (0, w - 1) and z in (zf, zb)
                along = x if z in (zf, zb) else z - zf
                if y <= 2:
                    entry = "role foundation"
                elif y == WALL_TOP:
                    entry = "role beam"
                elif corner or along % 3 == 0:
                    entry = "role post"
                else:
                    entry = "role wall"
                if x in (0, w - 1) and not corner and z in side_windows and y in (2, 3):
                    entry = "role window o=facedir:3"
                elif z == zf and x in (2, w - 3) and y in (2, 3):
                    entry = "role window o=facedir:0"
                put(x, y, z, entry)
    put(cx, 1, zf, "role door variant=_a")
    put(cx, 2, zf, "role door_hidden")
    for x in (cx - 1, cx + 1):
        for y in (1, 2, 3):
            put(x, y, zf, "role wall_accent")
    put(cx, 3, zf, "role wall_accent")
    put(cx, 3, zf - 1, emblem)
    for x in (cx - 2, cx + 2):
        put(x, 3, zf - 1, banner)
    # the frieze of the six depths behind the leader, set into the back wall
    # two courses high between two posts under a beam
    for index, entry in enumerate(TIERS):
        put(cx - 3 + index, 2, zb, entry)
        put(cx - 3 + index, 3, zb, entry)
    for x in (cx - 4, cx + 3):
        for y in (1, 2, 3):
            put(x, y, zb, "role post")
    for x in range(cx - 4, cx + 4):
        put(x, 4, zb, "role beam")
    points["doors"].append((cx, 1, zf, "face=0"))

    # 3. The hall's roof.
    if spec["roof"] == "gable":
        # Ridge along z, the gables to the street and the back; one node of
        # overhang all round.
        k = 0
        while True:
            y = WALL_TOP + 1 + k
            left, right = -1 + k, w - k
            if left > right:
                break
            for z in range(zf - 1, zb + 2):
                if left == right:
                    put(left, y, z, "role roof_ridge")
                else:
                    put(left, y, z, "role roof_stair channel=roof o=facedir:1")
                    put(right, y, z, "role roof_stair channel=roof o=facedir:3")
            for x in range(left + 1, right):
                put(x, y, zf, "role wall")
                put(x, y, zb, "role wall")
            if left == right:
                for z in range(zf - 1, zb + 2):
                    put(left, y + 1, z, "role roof_slab channel=roof")
                break
            if left + 1 == right:
                break
            k += 1
    else:
        # A flat deck behind a breastwork, merlons on every other column.
        y = WALL_TOP + 1
        for z in range(zf, zb + 1):
            for x in range(0, w):
                put(x, y, z, "role ceiling")
                if x in (0, w - 1) or z in (zf, zb):
                    put(x, y + 1, z, "role wall_accent")
                    if spec.get("merlons") and (x + z) % 2 == 0:
                        put(x, y + 2, z, "role wall_accent")

    # 4. The hall. The exchange counter on the east side, its keeper behind
    # it facing west; the clerk's desk on the west side; the ore sorter's
    # sample table behind it; the leader's desk at the back.
    def counter(x, z):
        put(x, 1, z, "role table_leg")
        put(x, 2, z, "role table_top")
    zc = hz0 + 2
    for z in (zc, zc + 1, zc + 2):
        counter(w - 3, z)
    put(w - 2, 1, zc - 1, "role storage o=facedir:3")
    put(w - 2, 1, zc - 2, "node default:coalblock")
    put(w - 2, 2, zc - 2, "node grug_materials:copper_block")
    counter(2, zc + 1)
    counter(2, zc + 4)
    put(1, 1, zc + 5, "role storage o=facedir:1")
    zl = hz1 - 1
    for x in (cx - 1, cx, cx + 1):
        counter(x, zl)
    for x, face in ((1, 1), (w - 2, 3)):
        put(x, 1, hz1, "role storage o=facedir:%d" % face)
        put(x, 2, hz1, "role storage o=facedir:%d" % face)
    for x in (2, w - 3):
        put(x, 1, hz1, "role shelf o=facedir:2")
        put(x, 2, hz1, "role shelf o=facedir:2")
    for z in (hz0 + 3, hz1 - 3):
        for x in range(1, w - 1):
            put(x, WALL_TOP, z, "role beam")
    for z in (hz0, hz1):
        put(1, 3, z, "role light_wall o=wallmounted:3")
        put(w - 2, 3, z, "role light_wall o=wallmounted:2")
        points["lights"] += [(1, 3, z, ""), (w - 2, 3, z, "")]
    for x in (cx - 1, cx + 1):
        put(x, 3, zf - 1, "role light_wall o=wallmounted:4")
        points["lights"].append((x, 3, zf - 1, ""))

    # 5. The ore yard. Its fence on the two outer sides, a lamp post at the
    # gate and in the far corner.
    for z in range(1, D):
        put(W - 1, 1, z, "role fence")
    for x in range(YX, W - 1):
        put(x, 1, D - 1, "role fence")
    for z in (0, D - 1):
        put(W - 1, 1, z, "role post")
        put(W - 1, 2, z, "role post")
        put(W - 1, 3, z, LANTERN)
        points["lights"].append((W - 1, 3, z, ""))
    # The headframe: four legs, three rings of beams, the head beam across
    # the back legs with two sheave wheels on its street face, the rope from
    # the east wheel down to a tub on the grated shaft collar, a lamp under
    # the lowest ring, the guild's banners on the front of the middle ring.
    x0, x1 = HF_X
    z0, z1 = HF_Z
    for x in (x0, x1):
        for z in (z0, z1):
            for y in range(1, HF_RINGS[-1] + 1):
                put(x, y, z, "role post")
    for y in HF_RINGS:
        for x in range(x0, x1 + 1):
            for z in range(z0, z1 + 1):
                if x in (x0, x1) or z in (z0, z1):
                    put(x, y, z, "role beam")
    for x in range(x0, x1 + 1):
        put(x, HF_HEAD, z1 - 1, "role beam")
    for x in (x0 + 1, x0 + 2):
        put(x, HF_HEAD, z1 - 2, "node grug_decor:cottages_wagon_wheel o=wallmounted:4")
    for y in range(2, HF_HEAD):
        put(x0 + 1, y, z1 - 2, "node grug_decor:xdecor_rope")
    put(x0 + 1, 1, z1 - 2, "node grug_decor:cottages_tub")
    for x in (x0 + 1, x0 + 2):
        for z in (z1 - 2, z1 - 1):
            put(x, 0, z, "node grug_decor:darkage_iron_grille")
    put(x0 + 2, HF_RINGS[0] - 1, z0, HANGING)
    points["lights"].append((x0 + 2, HF_RINGS[0] - 1, z0, ""))
    for x in (x0 + 1, x0 + 2):
        put(x, HF_RINGS[1], z0 - 1, banner)
    # The rail from the shaft to the street, two ore carts on it.
    rx = x0 + 1
    for z in range(1, z0 + 1):
        put(rx, 1, z, RAIL)
    for z in (3, 6):
        put(rx, 1, z, CART)
    # The six heaps along the east fence, T1 nearest the street: the tier's
    # stone, its ore on top, a block of ore spilled toward the rail.
    for index in range(6):
        z = 1 + index
        put(W - 2, 1, z, TIERS[index])
        put(W - 2, 2, z, ORES[index])
        if index % 2 == 0:
            put(W - 3, 1, z, ORES[index])
    # Pit props stacked behind the heaps, the coal bunker and barrels at the
    # back of the yard.
    for x in (W - 3, W - 2):
        for z in (7, 8):
            put(x, 1, z, "role beam")
        put(x, 2, 8, "role beam")
    put(W - 2, 1, D - 2, "node grug_decor:cottages_barrel")
    put(W - 2, 1, D - 3, "node grug_decor:cottages_barrel")
    put(W - 3, 1, D - 2, "node default:coalblock")
    put(YX + 1, 1, D - 2, "node grug_decor:cottages_wagon_load")

    # 6. The points.
    points["inside"].append((cx, 1, hz0 + 1, "id={id}"))
    points["room_corner"].append((1, 0, hz0, "closed=true id={id} top=%d" % WALL_TOP))
    points["room_corner"].append((w - 2, 0, hz1, ""))
    points["sockets"] += [
        (cx, 1, hz1, "face=2 id={id}_leader role=quest"),
        (w - 2, 1, zc + 1, "face=3 id={id}_exchange role=idle tags=[work]"),
        (1, 1, zc + 1, "face=1 id={id}_clerk role=idle tags=[work]"),
        (1, 1, zc + 4, "face=1 id={id}_sorter role=idle tags=[work]"),
        (cx + 2, 1, zf - 1, "face=0 id={id}_porter role=idle tags=[door]"),
    ]
    top = max(y for (_, y, _) in cells)
    return cells, points, top, top


def model(spec):
    cells, points, peak, top = build(spec)
    w, d = W, D
    name = "%s_miners_guild" % spec["capital"]
    x0, y0, z0 = -1, 0, -1
    sx, sy, sz = w + 2, top + 1, d + 2
    entries = sorted(set(cells.values()))
    if len(entries) > len(tplfile.ALPHABET):
        raise SystemExit("make_halls: %s needs more legend keys" % name)
    key_of = {entry: tplfile.ALPHABET[i] for i, entry in enumerate(entries)}
    m = tplfile.Model()
    m.name, m.cell = name, 1
    m.origin, m.size, m.pivot = (x0, y0, z0), (sx, sy, sz), (w, d)
    m.races = [spec["race"]]
    m.head = [
        "# Round 58 lanes HALLS, HALLS2: the Miner's Guild house of %s, written by" % spec["label"],
        "# tools/r58_halls/make_halls.py (edit the script, not this file).",
        "name %s" % name,
        "pivot %d %d" % (w, d),
        "origin %d %d %d" % (x0, y0, z0),
        "size %d %d %d" % (sx, sy, sz),
        "cell 1",
        "meta extent=[%d,%d,%d,%d] peak=%d top=%d" % (x0, z0, x0 + sx - 1, z0 + sz - 1,
                                                    peak, top),
        "races %s" % spec["race"],
    ]
    m.legend = [[key_of[entry], entry] for entry in entries]
    for y in range(y0, y0 + sy):
        rows = []
        for z in range(z0, z0 + sz):
            row = []
            for x in range(x0, x0 + sx):
                entry = cells.get((x, y, z))
                row.append(key_of[entry] if entry else ".")
            rows.append("".join(row))
        m.layers.append(rows)
    for group in ("doors", "inside", "room_corner", "lights", "sockets"):
        for x, y, z, rest in points[group]:
            m.points.append([group, x, y, z, rest])
    return name, tplfile.dump(m)


def main(argv):
    check = argv == ["--check"]
    if argv and not check:
        raise SystemExit(__doc__)
    stale = []
    for spec in SPECS:
        name, text = model(spec)
        path = os.path.join(OUT, name + ".tpl")
        if check:
            old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
            if old != text:
                stale.append(name)
        else:
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(text)
            print("wrote", os.path.relpath(path, REPO))
    if check:
        if stale:
            raise SystemExit("make_halls --check: FAIL, not the script's output: " +
                             ", ".join(stale))
        print("make_halls --check: PASS (%d templates)" % len(SPECS))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
