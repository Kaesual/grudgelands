#!/usr/bin/env python3
"""Round 73 TOOLS fixture, the Python half (portable_test.lua runs it).

  python3 tools/r73_tools/cases.py OUT_DIR

1. The authoring helpers on hand-made maps: relief's stairs (shape and param2 at a
   straight edge, an outer and an inner corner) and every refusal (a step of two, a
   ridge, a trench, a peak, a diagonal ridge, a trap cell not flat, two surfaces, a pit
   too deep, a material with no stair set); `vary` on several seeds; a passage's width
   and niche; the light spread's spacing; dressing's refusals; the lava fall's shape
   and refusals; an alcove that does not fit its mob.
2. Small templates for the proof: `base.exp` meets every rule; each `<rule>.exp` breaks
   one (portable_test.lua knows which). Prints "CASES OK <n>" at the end.
"""
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[0] / "expedition_templates"))
import dressing  # noqa: E402
import hazards  # noqa: E402
import light  # noqa: E402
import passages  # noqa: E402
import relief  # noqa: E402
from template import Template  # noqa: E402

checks = 0


def check(ok, label):
    global checks
    checks += 1
    if not ok:
        raise SystemExit(f"FAIL {label}")


def refuses(fn, label, text=""):
    try:
        fn()
    except ValueError as error:
        check(text in str(error), f"{label}: refused, but {error}")
        return
    check(False, f"{label}: not refused")


def square(x0, z0, x1, z1):
    return {(x, z) for x in range(x0, x1) for z in range(z0, z1)}


# ---- 1. The helpers ---------------------------------------------------------------------
# An L-shaped rise of one level in a flat floor: its stairs, by hand. The arms are four
# wide; x grows east, z north.
room = relief.flat(square(0, 0, 16, 16), 5)
for x, z in square(4, 4, 12, 8) | square(4, 8, 8, 12):
    room[x, z] = 6
relief.check(room)
WANT = {
    (6, 4): ("normal", 0),   # south edge: the low side at -z, param2 0
    (11, 6): ("normal", 3),  # east edge: low at +x
    (4, 6): ("normal", 1),   # west edge: low at -x
    (9, 7): ("normal", 2),   # north edge of the long arm: low at +z
    (4, 4): ("outer", 1),    # the south-west corner, the high quarter north-east
    (11, 4): ("outer", 0),   # the south-east corner, the high quarter north-west
    (11, 7): ("outer", 3),   # the north-east corner of the long arm
    (7, 7): ("inner", 3),    # the inner corner: only its north-east quarter low
    (5, 5): None, (5, 9): None, (0, 0): None,
}
for cell, want in WANT.items():
    check(relief.stair_at(room, *cell) == want, f"relief stair at {cell}: {relief.stair_at(room, *cell)} != {want}")
# The quarter masks against the node boxes: a normal stair's high half is +z at param2
# 0 and +x at param2 1 (facedir 1 turns +z to +x).
check(relief.SHAPES[frozenset({(-1, 1), (1, 1)})] == ("normal", 0), "relief normal p0")
check(relief.SHAPES[frozenset({(1, 1), (1, -1)})] == ("normal", 1), "relief normal p1")

broken = {
    "a step of two": ({**relief.flat(square(0, 0, 6, 6), 5), **{c: 7 for c in square(3, 0, 6, 6)}},
                      "more than one node"),
    "a ridge": ({**relief.flat(square(0, 0, 8, 8), 5), **{c: 6 for c in square(4, 0, 5, 8)}}, "ridge"),
    "a trench": ({**relief.flat(square(0, 0, 8, 8), 6), **{c: 5 for c in square(4, 0, 5, 8)}}, "trench"),
    "a peak": ({**relief.flat(square(0, 0, 6, 6), 5), (2, 2): 6}, "no stair fits"),
    "a diagonal ridge": ({**relief.flat(square(0, 0, 8, 8), 5),
                          **{(i, i): 6 for i in range(8)}, **{(i + 1, i): 6 for i in range(7)}}, "no stair fits"),
    "a pit too deep": (relief.flat(square(0, 0, 4, 4), 2), "less than two rows"),
}
for label, (heights, text) in broken.items():
    refuses(lambda h=heights: relief.check(h), "relief refuses " + label, text)
trap_map = relief.flat(square(0, 0, 8, 8), 5)
trap_map.update({c: 6 for c in square(4, 0, 8, 8)})
refuses(lambda: relief.check(trap_map, flat=[(3, 3)]), "relief refuses a trap beside a stair", "not flat")
relief.check(trap_map, flat=[(1, 3)])
refuses(lambda: relief.merge({(1, 1): 5}, {(1, 1): 6}), "relief refuses two surfaces", "two surfaces")
t = Template("unit", (16, 16, 16), "default:stone")
refuses(lambda: relief.write(t, room, "gravel"), "relief refuses gravel stairs", "no stair set")
relief.carve(t, room, 9)
relief.write(t, room, "cobble", floor="default:stone")
check(t.get(11, 5, 4) == "stairs:stair_outer_cobble" and t.param2[t.index(11, 5, 4)] == 0, "relief writes the outer stair")
check(t.get(7, 5, 7) == "stairs:stair_inner_cobble" and t.param2[t.index(7, 5, 7)] == 3, "relief writes the inner stair")
check(t.get(5, 5, 5) == "default:stone" and t.get(1, 4, 1) == "default:stone" and t.get(1, 5, 1) == "air",
      "relief writes the floor and carves the air")

# Variety out of the box: features of several levels, a gentle and a steep side, on
# several seeds; every map holds the rules, and is not even.
blob = {(x, z) for x in range(30) for z in range(24) if (x - 15) ** 2 / 225 + (z - 12) ** 2 / 144 <= 1}
for seed in range(6):
    heights = relief.vary(blob, 8, seed=seed, keep=[(1, 12), (28, 12)], features=[
        relief.pit(17, 12, 7, depth=3, gentle=0, seed=seed),
        relief.rise(7, 16, 4, height=2, seed=seed + 1),
        relief.terrace(15, 4, angle=-90, levels=1, seed=seed + 2)])
    levels = set(heights.values())
    check(min(levels) <= 6 and max(levels) >= 9, f"vary seed {seed}: pits and rises of several levels: {sorted(levels)}")
    check(heights[1, 12] == 8 and heights[28, 12] == 8, f"vary seed {seed}: the kept mouths stay at the base")

# A passage: its width across, a niche beside it, a stair run down.
p = passages.Passage([(0, 9.5), (20, 9.5)], width=6)
check(sorted({z for (x, z) in p.cells() if x == 10}) == list(range(7, 13)), "passage six wide across")
nook = p.niche(0.5, side=1, depth=3, width=3)
check(len(nook) == 9 and all(13 <= z <= 15 for _, z in nook), f"passage niche on the left: {sorted(nook)}")
hp = p.heights(8, profile=[(0, 0), (0.4, 0), (0.6, -2)])
relief.check(hp)
check(hp[2, 9] == 8 and hp[18, 9] == 6, "passage stair run down two")
check(len(p.mouth(0)) == 6 and all(x <= 1 for x, _ in p.mouth(0)), "passage mouth")
bent = passages.Passage([(0, 4.5), (10, 4.5), (16, 12.5)], width=lambda s: 6 + 2 * (0.4 < s < 0.6))
check(len(bent.cells()) > 6 * 18, "a bent passage with a widening")

# The light spread: seeded, irregular, never closer than its spacing.
spots = light.spread(square(0, 0, 40, 40), 8, spacing=9, seed=5)
check(len(spots) == 8 and spots == light.spread(square(0, 0, 40, 40), 8, spacing=9, seed=5), "light spread")
check(all((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 >= 81 for a in spots for b in spots if a != b), "light spacing")
check(len({x % 3 for x, _ in spots}) > 1 and len({z % 3 for _, z in spots}) > 1, "light spread on no grid")

# Dressing: never a walkable node, a harvestable one or a cobweb on a walking cell.
t2 = Template("unit2", (16, 16, 16), "default:stone")
relief.carve(t2, room, 9)
for node, text in (("default:cobble", "walkable"), ("grug_mapgen:ember_moss_source", "harvested"),
                   ("grug_decor:xdecor_cobweb", "walking cell")):
    refuses(lambda n=node: dressing.scatter(t2, room, [n], lambda x, z: 1, 1), "dressing refuses " + node, text)
done = dressing.scatter(t2, room, ["grug_nodes:moss_carpet"], dressing.clusters(room, 2, 4, 3), 3, avoid=[(5, 5)])
check(done and (5, 5) not in done and len(done) < len(room) // 2, "dressing in clusters")
done = dressing.scatter(t2, room, ["grug_nodes:moss_carpet"], lambda x, z: 1, 3)
check(done and not any(relief.stair_at(room, x, z) for x, z in done), "dressing leaves the stairs bare")
# Uneven by default: a pit's slope differs by side unless gentle=False.
uneven = relief.pit(0, 0, 8, depth=3, seed=4)
even = relief.pit(0, 0, 8, depth=3, seed=4, gentle=False)
runs = [uneven.run(math.radians(a)) for a in range(0, 360, 45)]
check(max(runs) > 2 * min(runs) and len({even.run(math.radians(a)) for a in range(0, 360, 45)}) == 1,
      "vary: a seeded gentle side by default, even only on request")

# The lava fall: closed, the basin out of the floor, refusals.
t3 = Template("unit3", (16, 16, 16), "default:stone")
floor3 = relief.flat(square(2, 2, 10, 10), 5)
relief.carve(t3, floor3, 12)
relief.write(t3, floor3, "cobble")
refuses(lambda: hazards.lava_fall(t3, dict(floor3), 9, 5, "+x", source=7), "lava refuses a low source", "head height")
refuses(lambda: hazards.lava_fall(t3, dict(floor3), 8, 5, "+x", source=10), "lava refuses a floor wall", "not wall")
basin = hazards.lava_fall(t3, floor3, 9, 5, "+x", source=10, basin=[(0, 0), (0, 1)])
check((9, 5) not in floor3 and (9, 6) not in floor3 and len(basin) == 2, "lava: the basin leaves the floor")
check(t3.get(10, 10, 5) == hazards.LAVA and t3.get(9, 10, 5) == "default:stone", "lava: the source behind its lip")
check(t3.get(10, 7, 5) == hazards.FLOWING and t3.param2[t3.index(10, 7, 5)] == 15, "lava: the falling column")
check(t3.param2[t3.index(10, 4, 5)] == 7 and t3.param2[t3.index(9, 4, 5)] == 6 and t3.param2[t3.index(9, 4, 6)] == 5,
      "lava: the basin's flowing levels")
refuses(lambda: hazards.alcove(t3, floor3, 5, 2, "-z", 1, 1, 3, mob=(2, 2.4)), "alcove refuses a big mob", "fit")
t4 = Template("unit4", (16, 16, 16), "default:stone")
refuses(lambda: hazards.ambush(t4, room, "a1", 1, "drift", (2, 2, 5, 5), [("grug_mobs:zombie", 1, 1)]),
        "ambush refuses a zone over a stair", "no flat floor")
refuses(lambda: hazards.ambush(t4, room, "a1", 1, "drift", (0, 0, 1, 1), [("grug_mobs:zombie", 6, 6)]),
        "ambush refuses a marker off its floor", "not on its floor")
check(hazards.ambush(t4, room, "a1", 1, "drift", (0, 0, 1, 1), [("grug_mobs:zombie", 0, 2)]) and
      t4.ambushes == [("a1", 1, "drift", 0, 5, 0, 1, 1)] and t4.encounters[-1][3] == "normal",
      "ambush writes its line and a normal marker through template.py")


# ---- 2. Templates for the proof ----------------------------------------------------------
FEET = 5
ROCK = "default:stone"
SPIDER = "grug_mobs:giant_spider"


def base(variant=None):
    t = Template("case_" + (variant or "base"), (80, 32, 48), ROCK)
    # Room A, x 4..27, z 4..27, with an L-shaped rise; the store behind a door to the
    # east, at the end of a long straight drift (x 28..67) with an ambush in its dark
    # middle (x 44..46) and an alcove on each side.
    floor = relief.flat(square(4, 4, 28, 28), FEET)
    for cell in square(16, 16, 24, 20) | square(16, 20, 20, 24):
        floor[cell] = FEET + 1
    floor.update(relief.flat(square(28, 12, 68, 16), FEET))
    floor.update(relief.flat(square(68, 8, 80 - 1, 20), FEET))
    if variant == "sight":
        floor.update(relief.flat(square(6, 28, 8, 44), FEET))
        floor.update(relief.flat(square(8, 42, 22, 44), FEET))
    relief.carve(t, floor, lambda x, z: 12 if x < 28 and z < 28 else 9)
    relief.write(t, floor, "cobble")
    north = hazards.alcove(t, floor, 45, 12, "-z", width=1, depth=1, height=4, mob=(1, 1.9))
    south = hazards.alcove(t, floor, 45, 15, "+z", width=1, depth=1, height=4, mob=(1, 1.9))
    zone = (44, 12, 46, 13) if variant == "ambush" else (44, 12, 46, 15)
    hazards.ambush(t, floor, "a1", 1, "drift", zone,
                   [("grug_mobs:zombie", *north[0]), ("grug_mobs:zombie", *south[0])])
    t.particles("dust", 5, FEET, 5, 14, FEET + 4, 14, 24)
    # The arrival in room A's south-west corner, the drift out of its sight.
    t.set(6, FEET, 24, "grug_expeditions:waystone")
    t.place("start_waystone", 6, FEET, 24)
    t.place("arrival", 8, FEET, 24)
    t.box(66, FEET, 12, 66, 9, 15, "grug_expeditions:reward_door")
    t.place("door", 66, 7, 13)
    t.set(76, FEET, 14, "grug_expeditions:reward_chest", 1)
    t.place("chest", 76, FEET, 14)
    t.set(76, FEET, 10, "grug_expeditions:waystone")
    t.place("end_waystone", 76, FEET, 10)
    t.encounter("pack", SPIDER, 1, "normal", 12, FEET, 12)
    t.encounter("gate", SPIDER, 1, "normal", 31, FEET, 13)  # the drift's first fight
    t.encounter("boss", "grug_mobs:stone_golem", 1, "boss", 22, FEET, 24)
    t.trap_floor("f1", 1, 10, FEET, 22)
    # Light at things: lanterns over the pack and the rise, at the arrival, in the store
    # and the passage; head room four nodes over the feet.
    for x, z in ((12, 12), (9, 8), (16, 9), (10, 17), (21, 21), (25, 12), (14, 24), (26, 26),
                 (6, 5), (11, 5), (5, 10), (7, 21), (12, 23), (5, 25), (9, 14), (21, 26), (10, 26)):
        if variant == "light" and (x, z) in ((12, 12), (9, 8), (16, 9), (10, 17), (6, 5), (11, 5), (5, 10), (9, 14)):
            continue  # the pack's and the arrival's light gone
        light.lantern(t, x, z, 9 + (floor[x, z] - FEET), 12)
    for x, z in ((72, 14), (77, 12), (29, 14), (77, 8), (78, 17), (67, 12), (73, 9), (64, 13), (32, 13)):
        light.lantern(t, x, z, 9, 9)
    hazards.lava_fall(t, floor, 27, 6, "+x", source=10)
    dressing.scatter(t, floor, ["grug_nodes:moss_carpet", "grug_nodes:lichen_carpet"],
                     dressing.clusters(square(4, 4, 16, 28), 2, 4, 7), 7, avoid=[(10, 22)])
    if variant == "surface":
        t.set(0, 10, 10, "air")
    elif variant == "relief":
        t.set(19, FEET, 16, "stairs:stair_cobble", 2)  # facing the high side
    elif variant == "free_height":
        t.set(5, FEET + 2, 26, ROCK)
    elif variant == "head_room":
        t.set(5, FEET + 3, 26, ROCK)
    elif variant == "perches":
        t.set(6, FEET, 26, "grug_decor:cottages_table")
    elif variant == "perches_rail":
        # A nook south of room A, its one-wide way in over a rail: a free table in it.
        t.box(24, FEET, 28, 24, FEET + 3, 29, "air")
        t.box(23, FEET, 30, 25, FEET + 3, 32, "air")
        t.set(24, FEET, 28, "grug_mapgen:mine_rail")
        t.set(24, FEET, 31, "grug_decor:cottages_table")
    elif variant == "dressing":
        t.set(6, FEET, 25, "grug_decor:xdecor_cobweb")
    elif variant == "route":
        t.box(40, 14, 40, 42, 16, 42, "air")
        t.encounter("lost", SPIDER, 1, "normal", 41, 14, 41)
    elif variant == "lava":
        t.set(3, FEET, 20, hazards.LAVA)
    elif variant == "traps":
        t.trap_floor("f2", 1, 15, FEET, 18)
    elif variant == "particles":
        t.particles("ash", 40, 20, 40, 41, 21, 41, 10)
    return t


cases = ["base", "surface", "relief", "free_height", "head_room", "perches", "dressing", "route", "light",
         "sight", "ambush", "lava", "traps", "particles", "perches_rail"]
out = Path(sys.argv[1])
for name in cases:
    template = base(None if name == "base" else name)
    (out / f"{name}.exp").write_bytes(template.to_bytes())
print(f"CASES OK {checks} {len(cases)}")
