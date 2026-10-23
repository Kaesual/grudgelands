#!/usr/bin/env python3
"""Write the six Miner's Guild house templates (Round 58 lane HALLS).

    python3 tools/r58_halls/make_halls.py          # write the six .tpl files
    python3 tools/r58_halls/make_halls.py --check  # the committed files are
                                                   # this script's output

One parametric guild house, the same institution in every capital and built
from that capital's palette (docs/technical/building-template-format.md §3):
a hall of `w` x `d` nodes with a two-row forecourt on its street side (the
winch, the ore cart and two lamp posts), a single door in the middle of the
front wall, the guild's banners beside it and its emblem over it (placeholders
from shipped textures: wool in the guild's colours and a metal plaque, until
the picked emblems of lane LIFTART), the exchange counter on the east side,
the clerk's desk on the west side, the leader's desk at the back under a
frieze of the six tier stones (the depths the guild mines), and a gable roof
(the human, dwarf, elf and undead capitals) or a flat deck behind a breastwork
(the orc and troll capitals). Every material is a palette role except the
mining props, the banners, the plaque and the frieze.

The template frame (format doc §2): x east, z north, the street side is
z = -1 (the front), the door faces -z; the capital's code turns the house.

The hall socket contract (settlements.md, "The Miner's Guild houses"): the
points `{id}_leader` (role quest), `{id}_exchange` (role idle, tag work: the
exchange counter, taken over by lane CAMPNPC as a service socket) and three
residents (`{id}_clerk`, `{id}_sorter`, `{id}_porter`).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "building_templates", "editor"))

import tplfile  # noqa: E402

OUT = os.path.join(REPO, "mods", "MAPGEN", "grug_mapgen", "building_templates",
                   "templates")

# The guilds' placeholder colours and plaques (lane LIFTART picks the emblems).
GUILDS = {
    "charter": {"main": "node wool:blue", "accent": "node wool:yellow",
                "plaque": "node grug_materials:gold_block"},
    "oathdelvers": {"main": "node wool:red", "accent": "node wool:black",
                    "plaque": "node grug_materials:copper_block"},
}

# The six houses: footprint (pivot) w x d in the template frame, the roof
# style, the guild, the placing race, and whether the roof uses the `roof`
# channel. The footprints are those of the buildings they replace (Dur
# Brannoc, Gor Drazhak and Nhal Veyr: the core's guild house slot; Highcourt:
# the city workshop's, turned once; Kezamba: the granary's) and Lethariel's
# new corner by the quay.
SPECS = [
    {"capital": "highcourt", "label": "Highcourt", "race": "human",
     "w": 13, "d": 16, "roof": "gable", "guild": "charter"},
    {"capital": "dur_brannoc", "label": "Dur Brannoc", "race": "dwarf",
     "w": 13, "d": 17, "roof": "gable", "guild": "charter"},
    {"capital": "lethariel", "label": "Lethariel", "race": "elf",
     "w": 13, "d": 13, "roof": "gable", "guild": "charter"},
    {"capital": "nhal_veyr", "label": "Nhal Veyr", "race": "undead",
     "w": 13, "d": 17, "roof": "gable", "guild": "oathdelvers"},
    {"capital": "gor_drazhak", "label": "Gor Drazhak", "race": "orc",
     "w": 13, "d": 17, "roof": "deck", "merlons": True, "guild": "oathdelvers"},
    {"capital": "kezamba", "label": "Kezamba", "race": "troll",
     "w": 11, "d": 15, "roof": "deck", "merlons": False, "guild": "oathdelvers"},
]

FORECOURT = 2     # rows of open yard between the street edge and the front wall
WALL_TOP = 5      # the walls' top course
# The frieze: the host stones of the six depths, T1 to T6 (registry.lua tier_at).
TIERS = ["node default:stone", "node grug_materials:t2_stone",
         "node grug_materials:t3_stone", "node grug_materials:t4_stone",
         "node grug_materials:t5_stone", "node grug_materials:t6_stone"]


def build(spec):
    """The house as {(x, y, z): entry text}, its points and its peak."""
    w, d = spec["w"], spec["d"]
    guild = GUILDS[spec["guild"]]
    cells = {}
    points = {"doors": [], "inside": [], "room_corner": [], "lights": [],
              "sockets": []}

    def put(x, y, z, entry):
        cells[(x, y, z)] = entry

    cx = (w - 1) // 2          # the door column
    zf = FORECOURT             # the front wall
    zb = d - 1                 # the back wall
    hz0, hz1 = zf + 1, zb - 1  # the hall's first and last row
    # 1. The ground: the apron ring and the forecourt in the path, the
    # foundation under the walls, the floor, a runner up the aisle.
    for z in range(-1, d + 1):
        for x in range(-1, w + 1):
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

    # 2. The walls: masonry quoins and plinth, the timber or stone of the
    # palette between, windows two high, the door, the banners and plaque.
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
                entry = "role wall"
                if corner or y in (1, WALL_TOP):
                    entry = "role wall_accent"
                elif x in (0, w - 1) and z in side_windows and y in (2, 3):
                    entry = "role window o=facedir:3"
                elif z == zf and x in (2, w - 3) and y in (2, 3):
                    entry = "role window o=facedir:0"
                put(x, y, z, entry)
    # the door and its frame
    put(cx, 1, zf, "role door variant=_a")
    put(cx, 2, zf, "role door_hidden")
    for x in (cx - 1, cx + 1):
        for y in (1, 2, 3):
            put(x, y, zf, "role wall_accent")
    put(cx, 3, zf, "role wall_accent")
    put(cx, 4, zf, guild["plaque"])
    for x in (cx - 2, cx + 2):
        put(x, 2, zf, guild["main"])
        put(x, 3, zf, guild["main"])
        put(x, 4, zf, guild["accent"])
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

    # 3. The roof.
    top = WALL_TOP
    peak = WALL_TOP
    if spec["roof"] == "gable":
        # Ridge along z, the gables to the street and the back; one node of
        # overhang all round (the stairs on the apron's columns, as the
        # frozen guild house has them).
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
            top = y
            if left == right:
                peak = y
                for z in range(zf - 1, zb + 2):
                    put(left, y + 1, z, "role roof_slab channel=roof")
                top = y + 1
                break
            if left + 1 == right:
                peak = y
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
        top = y + 2 if spec.get("merlons") else y + 1
        peak = top

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
    # the stores in the back corners and the sample shelves by the frieze
    for x, face in ((1, 1), (w - 2, 3)):
        put(x, 1, hz1, "role storage o=facedir:%d" % face)
        put(x, 2, hz1, "role storage o=facedir:%d" % face)
    for x in (2, w - 3):
        put(x, 1, hz1, "role shelf o=facedir:2")
        put(x, 2, hz1, "role shelf o=facedir:2")
    # two tie beams across the hall under the top course
    for z in (hz0 + 3, hz1 - 3):
        for x in range(1, w - 1):
            put(x, WALL_TOP, z, "role beam")
    # lights on the side walls and at the door
    for z in (hz0, hz1):
        put(1, 3, z, "role light_wall o=wallmounted:3")
        put(w - 2, 3, z, "role light_wall o=wallmounted:2")
        points["lights"] += [(1, 3, z, ""), (w - 2, 3, z, "")]
    for x in (cx - 1, cx + 1):
        put(x, 3, zf - 1, "role light_wall o=wallmounted:4")
        points["lights"].append((x, 3, zf - 1, ""))

    # 5. The forecourt: the winch over its tub on the west, the ore cart and
    # its heap on the east, the door path between them open.
    for x in (0, 2):
        for y in (1, 2, 3):
            put(x, y, 0, "role fence")
    for x in (0, 1, 2):
        put(x, 4, 0, "role beam")
    put(1, 3, 0, "node grug_decor:xdecor_rope")
    put(1, 2, 0, "node grug_decor:xdecor_rope")
    put(1, 1, 0, "node grug_decor:cottages_tub")
    put(0, 1, 1, "node grug_decor:castle_rubble")
    put(w - 2, 1, 0, "node grug_decor:cottages_wagon_load")
    put(w - 3, 1, 0, "node grug_decor:cottages_wagon_wheel o=wallmounted:2")
    put(w - 1, 1, 0, "node grug_decor:cottages_wagon_wheel o=wallmounted:3")
    put(w - 1, 1, 1, "node grug_decor:castle_rubble")
    put(w - 2, 1, 1, "node default:coalblock")

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
    return cells, points, peak, top


def model(spec):
    cells, points, peak, top = build(spec)
    w, d = spec["w"], spec["d"]
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
        "# Round 58 lane HALLS: the Miner's Guild house of %s, written by" % spec["label"],
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
