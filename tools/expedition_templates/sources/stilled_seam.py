"""The Stilled Seam: the first, abandoned mine (Round 71 L20, Round 72 STYLE), redesigned
in Round 73 (lane SEAM; round73-expedition-redesign-concept.md section 5).

The oldest and roughest working: moss and lichen, timber supports, collapses with
rubble stairs, dripping water, bats. The six rooms keep their order, their packs, the
ore and gem places, the door, the chest and the waystones; every room and passage is
reshaped round them:

  0 Arrival       a timber refuge, nearly flat, a rubble slump at the boarded entrance
  1 Cart bay      a raised loading floor in the north-west, a sump in the south, rails
  2 Prop room     a collapse: a rubble ramp three levels up under a broken roof, a
                  hot seam's lava fall in the east wall
  3 Sorting floor bay c a sunken sorting floor beside a spoil heap; bay d a square
                  work room, flat on purpose
  4 Working face  Flintback's court, a sunken arena of uneven levels, a lava fall in
                  its wall
  5 Store         a square timber store, flat on purpose

The floor is one height map (tools/expedition_templates/relief.py writes every stair);
the passages bend (passages.py). The two ambush candidates (concept section 4.5) lie in
the two long dark drifts after the first pack: the haulage drift from the cart bay to
the prop room, and the drift down from the prop room to the sorting bays. Light comes
from things in the mine: lanterns on the timber, candles on the old tables and carts,
miners' lamp niches cut into the rock, the lava; no grid. tools/r71_l20/portable_test.lua
proves it on the written file.
"""
import math

import dressing
import hazards
import light
import passages
import registry
import relief
from shaping import cells_of
from template import Template

ROCK = "default:stone"
FEET, EYE = 5, 6
POST, BEAM, PLANK = "default:tree", "default:pine_wood", "default:wood"
BOARD = "grug_decor:darkage_reinforced_wood"
# The miners' lamps in their rock niches: the seam's own anthracite torch (light 14).
LAMP = "grug_materials:anthracite_torch_wall"
CANDLE = "grug_decor:xdecor_candle"
CART, TABLE, BARREL = "grug_mapgen:mine_cart", "grug_decor:cottages_table", "grug_decor:cottages_barrel"
RAIL = "grug_mapgen:mine_rail"
ORE, JADE = "grug_materials:stone_with_anthracite", "grug_materials:stone_with_jade"
DOOR, CHEST = "grug_expeditions:reward_door", "grug_expeditions:reward_chest"
WAYSTONE = "grug_expeditions:waystone"
SPIDER, GOLEM, BOSS = "grug_mobs:giant_spider", "grug_mobs:stone_golem", "grug_mobs:flintback"
BAT, CRAWLER, WEEVIL = "grug_mobs:cave_bat", "grug_mobs:cave_crawler", "grug_mobs:bone_weevil"
MOSS = ("grug_nodes:moss_carpet", "grug_nodes:lichen_carpet", "grug_nodes:lichen_carpet_b")
BONES = ("grug_nodes:bone_pile", "grug_nodes:bones_fragments", "grug_nodes:skull_human")
COBWEB, STRAND = "grug_decor:xdecor_cobweb", "grug_trees:swamp_hanging_moss_strand"
FACE_EAST = 3
# A spider's body (spider.lua collisionbox, 2.1 wide, 0.75 high): an ambush alcove's size.
SPIDER_BODY = (2.1, 0.75)

# Fighting chambers and quiet rooms, [x0, z0, x1, z1) rectangles (Round 72 STYLE's cuts;
# tools/r71_l20/portable_test.lua CHAMBERS holds the same).
ROOMS = {
    "arrival": ((12, 12, 27, 16), (10, 16, 32, 24), (12, 24, 29, 29), (16, 29, 24, 31)),
    "cart_bay": ((55, 18, 66, 21), (51, 21, 70, 24), (49, 24, 73, 33),
                 (52, 33, 71, 36), (56, 36, 66, 39)),
    "prop_room": ((104, 14, 114, 18), (99, 18, 120, 23), (99, 23, 119, 33),
                  (103, 33, 119, 38), (104, 38, 114, 39)),
    "sorting_c": ((99, 67, 117, 78), (100, 78, 117, 83), (102, 83, 114, 85)),
    "sorting_d": ((99, 101, 118, 119),),
    "court": ((63, 94, 72, 97), (59, 97, 76, 100), (57, 100, 79, 104),
              (54, 104, 80, 112), (56, 112, 79, 115), (60, 115, 76, 118), (63, 118, 72, 120)),
    "store": ((12, 88, 28, 92), (8, 92, 32, 120)),
}
COURT_ENVELOPE = (54, 94, 80, 120)
DOOR_X = 44
# Room cells that hold a prop, not floor: the refuge's and the store's hooded displays
# and the store's capped mineral seams.
PROPS = {(x, 12) for x in range(13, 18)} | {(x, 88) for x in range(16, 24)} | \
    {(8, 100), (31, 92), (31, 100), (8, 116), (8, 108), (31, 116)}


def passage_plan():
    """The passages in route order, as polylines (passages.py). Widths stay six nodes or
    more in the connecting tunnels (Round 72). Returns {name: (Passage, profile)}."""
    plan = {}
    # The refuge's way to the cart bay: a bend round a rubble hump, a niche on the left.
    p1 = passages.Passage([(29, 20), (36, 17.5), (43, 21.5), (51, 28)],
                          width=lambda s: 6 + (0.35 < s < 0.6) * 2)
    p1.niche(0.48, side=1, depth=3, width=4)
    plan["p1"] = (p1, [(0, 0), (0.22, 0), (0.32, 1), (0.55, 1), (0.66, 0), (1, 0)])
    # The blind siding to the cart bay's ore, after the pack (Round 72).
    siding = passages.Passage([(69, 31.5), (78.5, 36)], width=5)
    plan["siding"] = (siding, None)
    # The haulage drift (ambush candidate "haulage"): a short dip at the bay, then long,
    # straight and dark.
    p2 = passages.Passage([(68, 21.5), (77, 19.5), (101, 19.5)], width=6)
    plan["p2"] = (p2, [(0, 0), (0.1, 0), (0.17, -1), (0.27, -1), (0.34, 0), (1, 0)])
    # The drift down to the sorting bays (ambush candidate "drift"): from the prop room's
    # south-west corner, long, straight and dark, then an elbow into bay c's west side,
    # so bay c's pack never looks up it.
    drift = passages.Passage([(105, 38), (98.5, 47), (98.5, 61), (97.5, 66), (100, 71), (102, 72)],
                             width=lambda s: 6 + (s > 0.7))
    plan["drift"] = (drift, None)
    # The sorting bays' side way past the rock screen, a stair run down and up again.
    strip = passages.Passage([(101.5, 80), (98, 89), (98.5, 99), (100, 104)],
                             width=lambda s: 6 + (0.3 < s < 0.5))
    strip.niche(0.55, side=-1, depth=3, width=3)
    plan["strip"] = (strip, [(0, 0), (0.25, 0), (0.33, -1), (0.6, -1), (0.68, 0), (1, 0)])
    # From bay d to the working face, bending, a widening without a pack.
    p3 = passages.Passage([(100, 108), (92, 105.5), (86, 108), (80, 108)],
                          width=lambda s: 6 + 2 * (0.25 < s < 0.5))
    p3.niche(0.62, side=-1, depth=3, width=3)
    plan["p3"] = (p3, [(0, 0), (0.2, 0), (0.3, -1), (0.48, -1), (0.58, 0), (1, 0)])
    # Past the door to the store: straight through the door, then bent.
    p4 = passages.Passage([(55, 107.5), (40, 107.5), (35, 105.5), (30, 106.5)], width=8)
    plan["p4"] = (p4, None)
    return plan


def room_relief(name, cells, keep):
    """Each room's height map (concept section 4.1.10): uneven, or flat on purpose."""
    vary = lambda features, seed: relief.vary(cells, FEET, features, seed=seed, keep=keep)
    if name == "arrival":
        # A rubble slump at the boarded entrance, two levels, its long side south.
        return vary([relief.rise(13, 13, 5, height=2, gentle=70, seed=11)], 1)
    if name == "cart_bay":
        # The loading floor rises in two levels to the north-west; a sump in the south.
        return vary([relief.rise(56, 19, 6, height=2, gentle=10, seed=21),
                     relief.pit(61, 37, 4, depth=1, gentle=180, seed=22)], 2)
    if name == "prop_room":
        # The collapse: a rubble ramp three levels up to the north-east, the long run
        # down to the west; a shallow scour in the south-west.
        return vary([relief.rise(118, 15, 9, height=3, gentle=200, seed=31),
                     relief.pit(102, 30, 3, depth=1, gentle=0, seed=32)], 3)
    if name == "sorting_c":
        # The sunken sorting floor, two levels deep, its gentle side to the north-east;
        # a low spoil heap against the tables in the east wall.
        return vary([relief.pit(110, 79, 5, depth=2, gentle=300, seed=41),
                     relief.rise(116, 70, 4, height=1, gentle=180, seed=42)], 4)
    if name == "court":
        # Flintback's arena: a broad shallow hollow, gentle to the west, and a deeper pit
        # off his place to the south-west; a rim terrace in the north, a spoil bank two
        # levels up in the south-east.
        return vary([relief.pit(70, 106, 10, depth=1, gentle=180, stretch=4, seed=51),
                     relief.pit(66, 111, 5, depth=2, gentle=135, seed=53, wobble=0.3),
                     relief.rise(67, 95, 5, height=1, gentle=270, seed=52),
                     relief.rise(76, 117, 6, height=2, gentle=160, seed=54)], 5)
    return relief.flat(cells, FEET)  # sorting_d and the store: square, flat on purpose


def plan_floor():
    """The floor's height map and each cell's owner (a room or a passage)."""
    plan = passage_plan()
    rooms = {name: cells_of(rects) - PROPS for name, rects in ROOMS.items()}
    in_room = set().union(*rooms.values())
    owner = {}
    heights = {}
    for name, (p, profile) in plan.items():
        part = {c: h for c, h in p.heights(FEET, profile).items() if c not in in_room}
        heights = relief.merge(heights, part)
        for c in part:
            owner.setdefault(c, name)
    near = lambda c: any((c[0] + dx, c[1] + dz) in heights for dx in (-1, 0, 1) for dz in (-1, 0, 1))
    fixed = {"arrival": [(20, 26), (20, 27), (20, 25)], "store": [],
             "prop_room": [(118, 36)] + [(x, z) for x in (116, 117, 118) for z in range(28, 32)],
             # the lava basins' floor, flat round them (no stair's foot beside lava)
             "court": [(x, z) for x in range(73, 78) for z in range(97, 102)]}
    for name, cells in rooms.items():
        keep = sorted(c for c in cells if near(c)) + fixed.get(name, [])
        heights = relief.merge(heights, room_relief(name, cells, keep))
        for c in cells:
            owner[c] = name
    relief.check(heights)
    return plan, heights, owner


def ceiling(name, x, z, h):
    """The first solid row's floor: air from the feet to here, at least the tallest mob
    plus one node and a hanging light's row (concept 4.1.4)."""
    r = dressing.roll(7, x, z, 3)
    tops = {
        "arrival": 9 + min(3, max(0, (x - 10) // 4)),
        "cart_bay": 10 + max(0, 4 - abs(x - 60) // 3) - (z >= 33),
        "prop_room": 11 + min(5, max(0, (x - 99) // 3)) + (r < 0.3),
        "sorting_c": 10 + min(3, max(0, (z - 64) // 4)),
        "sorting_d": 11,
        "court": 20 - max(abs(x - 68) // 2, abs(z - 108) // 2) - (r < 0.25),
        "store": 13,
    }
    own = tops.get(name)
    if own is None:  # a passage: four rows over the feet, now and then one more
        return h + 4 + (r < 0.15)
    return max(own, h + 4)


def build_shell(t, heights, owner):
    """Air over the floor, the floor nodes and stairs, the roof and the walls."""
    tops = {c: ceiling(owner[c], c[0], c[1], h) for c, h in heights.items()}
    relief.carve(t, heights, lambda x, z: tops[x, z])
    wet = dressing.clusters(heights, count=16, radius=6, seed=73)
    # The hot working face and the dry store keep little moss; the rest is the oldest
    # and dampest mine of the three.
    dry = {"court": 0.3, "store": 0.0, "sorting_d": 0.5}
    damp = lambda x, z: wet(x, z) * dry.get(owner[x, z], 1.0) if (x, z) in owner else 0.0
    mossy = dressing.mossy(damp, seed=9)

    def stair(x, z):
        name = owner[x, z]
        if mossy(x, z):
            return "mossycobble"
        return "cobble" if name in ("prop_room", "arrival", "p1", "strip") else "stone"

    def floor(x, z):
        name = owner[x, z]
        if name == "store":
            return PLANK
        if mossy(x, z):
            return "default:mossycobble"
        r = dressing.roll(5, x, z)
        return ROCK if r < 0.5 else "default:cobble" if r < 0.8 else "default:gravel"

    relief.write(t, heights, stair, floor=floor)
    for (x, z), top in tops.items():
        name = owner[x, z]
        r = dressing.roll(11, x, z)
        node = BEAM if name == "store" and z % 6 == 0 else \
            "default:cobble" if r < 0.2 else BEAM if name in ("arrival", "cart_bay") and r > 0.85 else ROCK
        t.set(x, top + 1, z, node)
    # The walls: rock, cobble streaks, timber posts here and there, moss where it is damp.
    for (x, z), h in heights.items():
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = x + dx, z + dz
            if (nx, nz) in heights or not (0 < nx < t.sx - 1 and 0 < nz < t.sz - 1):
                continue
            post = dressing.roll(13, nx, nz) < 0.07 and owner[x, z] != "court"
            for y in range(h, tops[x, z] + 1):
                if t.get(nx, y, nz) != ROCK:
                    continue
                if post:
                    t.set(nx, y, nz, POST)
                elif dressing.roll(17, nx, nz, y) < 0.18:
                    t.set(nx, y, nz, "default:cobble")
    dressing.walls(t, heights, "default:mossycobble", damp, seed=19, rows=5)
    return tops, damp


def supports(t, heights, tops, p, at_list):
    """Timber sets across a passage at `at_list` (fractions along it): a post in each
    wall and a beam under the roof."""
    for at in at_list:
        (px, pz), (dx, dz) = p.at(at)
        nx, nz = -dz, dx
        row = []
        for side in (1, -1):
            k = 0
            while True:
                cx, cz = round(px + nx * side * k), round(pz + nz * side * k)
                if (cx, cz) not in heights:
                    break
                row.append((cx, cz))
                k += 1
            if k == 0:
                continue
            h = heights[row[-1]]
            if t.get(cx, h, cz) in (ROCK, "default:cobble", "default:mossycobble"):
                t.box(cx, h, cz, cx, tops[row[-1]], cz, POST)
        for cx, cz in row:
            t.set(cx, tops[cx, cz] + 1, cz, BEAM)


def lantern(t, heights, tops, x, z):
    """A lantern on its rope from the roof, its body over the tallest mob's head room."""
    light.lantern(t, x, z, heights[x, z] + 4, tops[x, z])


def lamp_niche(t, heights, x, z, side, up=2):
    """A miner's lamp: a torch in a one-node niche cut into the wall beside x, z, at
    `up` over the local feet (a wall cell: no floor under it, no perch)."""
    dx, dz = hazards.AXES[side]
    wx, wz = x + dx, z + dz
    if (wx, wz) in heights:
        raise ValueError(f"stilled_seam: {wx},{wz} is floor, no wall for a lamp")
    y = heights[x, z] + up
    if t.get(wx + dx, y, wz + dz) == "air":
        raise ValueError(f"stilled_seam: the lamp niche at {wx},{y},{wz} breaks through")
    t.set(wx, y, wz, LAMP, light.WALL[dx, dz])


def candle(t, x, y, z):
    """A candle standing on a table, a barrel or a cart (wallmounted 1: on the floor)."""
    if t.get(x, y, z) != "air" or not registry.walkable(t.get(x, y - 1, z)):
        raise ValueError(f"stilled_seam: no place for a candle at {x},{y},{z}")
    t.set(x, y, z, CANDLE, 1)


def display(t, heights, x0, x1, z, node, top, candles=()):
    """A wall recess with a low display and a closed hood, not a climbable prop; its
    floor at the local floor in front of it. Candles stand on it in the recess."""
    h = max(heights.get((x + dx, z + dz), 0) for x in range(x0, x1 + 1)
            for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    t.box(x0, h - 1, z, x1, h - 1, z, ROCK)
    t.box(x0, h, z, x1, h + 1, z, "air")
    t.box(x0, h, z, x1, h, z, node)
    t.box(x0, h + 2, z, x1, top, z, BOARD)
    for x in candles:
        candle(t, x, h + 1, z)


def ore(t, node, x, z, top=13):
    t.set(x, FEET, z, ROCK)
    t.set(x, EYE, z, node)
    # The rock above the seam closes the plinth even after its ore is dug.
    t.box(x, FEET + 2, z, x, top, z, ROCK)


def arrival(t, heights, tops):
    # The closed original entrance, now a small timber refuge.
    t.box(16, FEET, 11, 23, 10, 11, BOARD)
    for x in (16, 23):
        t.box(x, FEET, 11, x, 11, 11, POST)
    display(t, heights, 13, 17, 12, BARREL, 12, candles=(14, 16))
    t.set(20, FEET, 28, WAYSTONE)
    t.place("start_waystone", 20, FEET, 28)
    t.place("arrival", 20, FEET, 26)
    for x, z in ((20, 24), (24, 27), (27, 19)):
        lantern(t, heights, tops, x, z)
    lamp_niche(t, heights, 17, 30, "+z")


def cart_bay(t, heights, tops):
    # The hooded cart is embedded in the north wall, a candle on it for the loaders.
    display(t, heights, 59, 62, 17, CART, 13, candles=(60,))
    ore(t, ORE, 79, 36)
    for x, z in ((54, 25), (63, 23), (66, 30), (58, 34), (70, 27), (52, 30)):
        lantern(t, heights, tops, x, z)
    lantern(t, heights, tops, 60, 27)
    lantern(t, heights, tops, 59, 30)
    for x, z, side in ((61, 38, "+z"), (72, 29, "+x"), (65, 36, "+x"), (65, 18, "+x"), (51, 21, "-x"),
                       (49, 32, "-x")):
        lamp_niche(t, heights, x, z, side)


def prop_room(t, heights, tops):
    # Heavy timber pairs stand in the walls; a broken beam lies flush in the floor.
    for z in (20, 28, 35):
        for x in (98, 120):
            if (x, z) in heights or (x - 1, z) not in heights and (x + 1, z) not in heights:
                continue
            h = heights.get((x + 1, z), heights.get((x - 1, z)))
            t.box(x, h, z, x, h + 8, z, POST)
    for x in range(105, 112):
        if not relief.stair_at(heights, x, 33):
            t.set(x, heights[x, 33] - 1, 33, BEAM)
    ore(t, JADE, 119, 36)
    lantern(t, heights, tops, 104, 40)  # the drift's head, before its dark straight
    for x, z in ((103, 20), (110, 21), (106, 27), (113, 30), (108, 35), (101, 32), (116, 21),
                 (108, 15), (112, 24), (106, 22)):
        lantern(t, heights, tops, x, z)
    for x, z, side in ((114, 37, "+z"), (99, 27, "-x"), (103, 33, "-x")):
        lamp_niche(t, heights, x, z, side)


def sorting(t, heights, tops):
    # Abandoned sorting tables in their hooded recesses, candles left on them.
    for z in range(70, 78):
        display(t, heights, 117, 117, z, TABLE, 13, candles=(117,) if z in (71, 76) else ())
    display(t, heights, 105, 112, 119, TABLE, 13, candles=(107, 111))
    # The drift's end: a lantern at its elbow, in sight down the dark straight.
    lantern(t, heights, tops, 97, 68)
    lamp_niche(t, heights, 99, 75, "-x")
    lamp_niche(t, heights, 108, 67, "-z")
    for x, z in ((104, 70), (112, 70), (108, 77), (103, 80), (113, 82), (108, 84)):
        lantern(t, heights, tops, x, z)
    for x, z in ((103, 105), (114, 105), (108, 109), (103, 115), (114, 115), (110, 80), (109, 111), (100, 101)):
        lantern(t, heights, tops, x, z)
    for x, z, side in ((107, 101, "-z"), (99, 112, "-x"),
                       (117, 107, "+x")):
        lamp_niche(t, heights, x, z, side)
    # The rock screen between the bays shows the old boarded cuts.
    for z in (90, 96):
        t.box(104, 7, z, 104, 11, z, BOARD)


def court(t, heights, tops):
    # Torn rock piers stand in the court's edge; no platform under Flintback.
    for x, z in ((59, 96), (75, 96), (55, 113), (77, 116)):
        h = min(heights.get((x + dx, z + dz), 99) for dx in (-1, 0, 1) for dz in (-1, 0, 1))
        t.box(x, h, z, x, 16, z, "default:cobble")
        heights.pop((x, z), None)
    x0, z0, x1, z1 = COURT_ENVELOPE
    t.place("boss_room_min", x0, FEET, z0)
    t.place("boss_room_max", x1 - 1, FEET, z1 - 1)
    for x, z in ((62, 101), (74, 101), (68, 104), (60, 109), (76, 109), (64, 114), (72, 114), (68, 117),
                 (74, 107), (66, 111), (64, 103), (57, 111), (61, 99)):
        lantern(t, heights, tops, x, z)
    for x, z, side in ((66, 94, "-z"), (55, 104, "-z"), (79, 104, "-z")):
        lamp_niche(t, heights, x, z, side)


def store(t, heights, tops):
    # A square timber store after the rough working face.
    display(t, heights, 16, 23, 88, BARREL, 13, candles=(17, 22))
    t.set(20, FEET, 108, CHEST, FACE_EAST)
    t.place("chest", 20, FEET, 108)
    t.set(20, FEET, 116, WAYSTONE)
    t.place("end_waystone", 20, FEET, 116)
    for x, z, node in ((8, 100, ORE), (31, 92, ORE), (31, 100, ORE), (8, 116, ORE),
                       (8, 108, JADE), (31, 116, JADE)):
        ore(t, node, x, z)
    # A lantern pair over the chest and one over the end waystone; a few in the bays.
    for x, z in ((18, 107), (22, 109), (18, 117), (22, 115), (13, 95), (25, 96), (28, 104), (12, 112),
                 (27, 113)):
        lantern(t, heights, tops, x, z)


def door(t, heights):
    t.box(DOOR_X, FEET, 104, DOOR_X, FEET + 4, 111, DOOR)
    t.place("door", DOOR_X, FEET + 2, 108)
    # The old guild's lamps frame the reward door on both sides.
    for x, z, side in ((42, 104, "-z"), (46, 104, "-z"), (42, 111, "+z"), (46, 111, "+z")):
        lamp_niche(t, heights, x, z, side)


def packs(t, heights):
    def at(room, mob, count, tier, x, z):
        t.encounter(room, mob, count, tier, x, heights[x, z], z)
    at("pack_a", SPIDER, 4, "normal", 60, 28)
    at("pack_b", SPIDER, 2, "normal", 108, 28)
    at("pack_b", GOLEM, 1, "elite", 112, 24)
    at("pack_c", SPIDER, 3, "normal", 108, 74)
    at("pack_c", GOLEM, 1, "elite", 108, 70)
    at("pack_d", SPIDER, 3, "normal", 108, 110)
    at("pack_d", GOLEM, 1, "elite", 108, 114)
    at("boss", BOSS, 1, "boss", 68, 108)


def ambushes(t, heights):
    """Two candidates, one armed per run (concept section 4.5): two spiders, one in an
    alcove on each side of a zone across the drift. An alcove is two nodes deep and three
    wide: a spider (2.1 wide) crouches in it with its front at the passage's edge, and
    every cell of it is two steps from the passage, where the light at the drift's end is
    in sight (the proof's sight rule for alcoves). hazards.alcove's own fit asks for a
    body wholly inside, three deep, which that rule cannot pass."""
    width, height = math.ceil(SPIDER_BODY[0]), math.ceil(SPIDER_BODY[1] + 1) + 2
    backs = []
    for group_room, zone, sides in (
            ("drift", (96, 51, 101, 53), (("-x", 96, 52), ("+x", 101, 52))),
            ("haulage", (83, 17, 85, 22), (("-z", 84, 17), ("+z", 84, 22)))):
        markers = []
        for side, x, z in sides:
            hazards.alcove(t, heights, x, z, side, width=width, depth=2, height=height)
            dx, dz = hazards.AXES[side]
            markers.append((SPIDER, x + dx, z + dz))
        hazards.ambush(t, heights, "seam", 1, group_room, zone, markers)
        backs += [(x + 2 * hazards.AXES[side][0], z + 2 * hazards.AXES[side][1]) for side, x, z in sides]
    return backs


def lava_falls(t, heights):
    """The hot seam the miners cut into (concept section 4.6): a fall in the prop room's
    east wall beside pack b, and one in the working face's north-east wall over
    Flintback's arena. Each lights its room; a pack's hits can push a player in."""
    for x, z, wall, basin in ((118, 29, "+x", ((0, 0), (0, 1))), (75, 98, "+x", ((0, 0), (0, 1)))):
        hazards.lava_fall(t, heights, x, z, wall, source=heights[x, z] + 5, basin=basin)


def rails(t, heights, cells, param2):
    """The old track: a rail on each flat cell of `cells` (4dir 0 along z, 1 along x)."""
    for x, z in cells:
        h = heights.get((x, z))
        if h is None or relief.stair_at(heights, x, z) or t.get(x, h, z) != "air" \
                or t.get(x, h - 1, z) in ("air",) or not registry.walkable(t.get(x, h - 1, z)):
            continue
        t.set(x, h, z, RAIL, param2)


def deepest(p, index=0):
    """The niche cell farthest from its passage's line."""
    return max(p.niches[index][1], key=lambda c: (p.nearest(*c)[0], c))


def dress(t, heights, owner, damp, plan, zones):
    """Moss, lichen and bones on the floor, cobwebs and moss strands under the roof, in
    clusters (concept section 4.7); nothing walkable on a walking cell."""
    rails(t, heights, [(x, 28) for x in range(50, 68)] + [(x, 20) for x in range(70, 99)], 1)
    rails(t, heights, [(98, z) for z in range(47, 62)], 0)
    dressing.scatter(t, heights, MOSS, density=lambda x, z: 0.75 * damp(x, z), seed=23)
    # Bones where something died: the niches, the alcoves' backs, the arena's rim.
    spots = [deepest(plan["p1"][0]), deepest(plan["strip"][0]), deepest(plan["p3"][0]),
             (61, 102), (73, 115), (58, 109)] + zones
    bones = lambda x, z: 0.55 if min((x - a) ** 2 + (z - b) ** 2 for a, b in spots) <= 4 else 0
    dressing.scatter(t, heights, BONES, density=bones, seed=29)
    # Cobwebs in the spiders' rooms, high up; moss strands where it is damp.
    webs = dressing.clusters([c for c, n in owner.items() if n in ("cart_bay", "prop_room", "sorting_c",
                                                                    "sorting_d", "court", "drift", "p2")],
                             count=16, radius=4, seed=31, strength=0.45)
    dressing.hang(t, heights, COBWEB, webs, seed=37)
    dressing.hang(t, heights, STRAND, lambda x, z: 0.4 * damp(x, z), seed=41)


def niche_candles(t, heights, plan):
    """A miner's candle stub left in the deepest cell of each passage niche: the niche's
    light in sight (concept section 4.4)."""
    for name in ("p1", "strip", "p3"):
        x, z = deepest(plan[name][0])
        candle(t, x, heights[x, z], z)


def critters(t, heights, plan):
    """Three to six critters (concept section 4.8), never in a pack's room: bats under
    the refuge's and the store's roofs, crawlers and a weevil in the passages' niches."""
    beside = lambda name: sorted(plan[name][0].niches[0][1] - {deepest(plan[name][0])})[0]
    for room, mob, (x, z) in (("bats_refuge", BAT, (24, 19)), ("crawlers_hump", CRAWLER, beside("p1")),
                              ("weevils_screen", WEEVIL, beside("strip")),
                              ("crawlers_bend", CRAWLER, beside("p3")),
                              ("bats_store", BAT, (14, 102))):
        t.encounter(room, mob, 1, "critter", x, heights[x, z], z)


def particles(t, heights, plan):
    """Dripping water where it is damp, dust in the lantern light (concept section 4.8)."""
    def over(cells, style, amount, low=2, high=4):
        hs = [heights[c] for c in cells if c in heights]
        xs, zs = [c[0] for c in cells], [c[1] for c in cells]
        t.particles(style, min(xs), min(hs) + low, min(zs), max(xs), max(hs) + high, max(zs), amount)
    over(plan["p1"][0].niches[0][1], "drip", 12)
    over(plan["strip"][0].niches[0][1], "drip", 12)
    over([(x, z) for x in range(113, 118) for z in range(15, 21)], "drip", 18, 3, 6)
    over([(x, z) for x in range(97, 101) for z in range(43, 47)], "drip", 10)
    over([(x, z) for x in range(54, 67) for z in range(23, 33)], "dust", 25)
    over([(x, z) for x in range(61, 76) for z in range(101, 116)], "dust", 30, 1, 6)
    over([(x, z) for x in range(14, 27) for z in range(15, 26)], "dust", 15)


def build():
    t = Template("stilled_seam", (128, 32, 128), ROCK)
    plan, heights, owner = plan_floor()
    tops, damp = build_shell(t, heights, owner)
    supports(t, heights, tops, plan["p1"][0], (0.15, 0.4, 0.78))
    supports(t, heights, tops, plan["p2"][0], (0.12, 0.33, 0.8))
    supports(t, heights, tops, plan["drift"][0], (0.12, 0.3, 0.72, 0.9))
    supports(t, heights, tops, plan["strip"][0], (0.2, 0.75))
    supports(t, heights, tops, plan["p3"][0], (0.12, 0.8))
    arrival(t, heights, tops)
    cart_bay(t, heights, tops)
    prop_room(t, heights, tops)
    sorting(t, heights, tops)
    court(t, heights, tops)
    store(t, heights, tops)
    door(t, heights)
    lava_falls(t, heights)
    packs(t, heights)
    zones = ambushes(t, heights)
    niche_candles(t, heights, plan)
    critters(t, heights, plan)
    particles(t, heights, plan)
    dress(t, heights, owner, damp, plan, zones)
    t.dig(ORE)
    t.dig(JADE)
    build.last = {"heights": heights, "owner": owner, "tops": tops, "plan": plan}
    return t
