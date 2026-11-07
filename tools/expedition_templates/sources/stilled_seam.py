"""The Stilled Seam, the level 20 Expedition (Round 71 lane L20): the approved floor
plan of docs/planning/round71-l20-description.md, one floor, x and z as drawn there.
tools/r71_l20/portable_test.lua proves the route, the door, the ore, the packs and
the light on the written file.

Every walking cell starts at y 5. Decor stays on the walls, so passages keep six
free nodes and the court stays open."""
from template import Template

ROCK = "default:stone"
FEET, EYE = 5, 6
ROOM_TOP, COURT_TOP, PASS_TOP = 13, 16, 9
LANTERN_Y = 8

POST, BEAM, PLANK = "default:tree", "default:pine_wood", "default:wood"
BOARD = "grug_decor:darkage_reinforced_wood"
TORCH = "default:torch_wall"
LANTERN, ROPE = "grug_decor:xdecor_lantern_hanging", "grug_decor:xdecor_rope"
RAIL, CART = "grug_mapgen:mine_rail", "grug_mapgen:mine_cart"
TABLE, BENCH = "grug_decor:cottages_table", "grug_decor:cottages_bench"
BARREL = "grug_decor:cottages_barrel"
GOLD, JADE = "default:stone_with_gold", "grug_materials:stone_with_jade"
DOOR, CHEST = "grug_expeditions:reward_door", "grug_expeditions:reward_chest"
WAYSTONE = "grug_expeditions:waystone"
SPIDER, GOLEM, BOSS = "grug_mobs:giant_spider", "grug_mobs:stone_golem", "grug_mobs:flintback"

# Rectangles x0, z0, x1, z1, upper bounds excluded, as the plan's script draws them.
ROOMS = {
    "arrival": (8, 8, 32, 32),
    "cart_bay": (48, 8, 80, 40),
    "prop_room": (96, 8, 120, 40),
    "sorting": (96, 64, 120, 120),
    "court": (48, 88, 80, 120),
    "store": (8, 88, 32, 120),
}
PASSAGES = ((32, 16, 48, 24), (80, 16, 96, 24), (104, 40, 112, 64),
            (80, 104, 96, 112), (32, 104, 48, 112))
SCREEN = (104, 88, 120, 96)
# wallmounted param2 of a torch by the wall behind it.
WEST, EAST, NORTH, SOUTH = 3, 2, 5, 4
FACE_EAST = 3  # the chest's front looks at the door


def carve(t, rect, top):
    x0, z0, x1, z1 = rect
    t.box(x0, FEET, z0, x1 - 1, top, z1 - 1, "air")


def floor(t, rect, kinds):
    """Rubble underfoot, the same on every build: kinds are (node, weight) rows."""
    x0, z0, x1, z1 = rect
    total = sum(weight for _, weight in kinds)
    for z in range(z0, z1):
        for x in range(x0, x1):
            roll = ((x * 7349 + 13) ^ (z * 9151 + 7) ^ (x * z * 31)) % total
            for node, weight in kinds:
                if roll < weight:
                    t.set(x, FEET - 1, z, node)
                    break
                roll -= weight


def lanterns(t, rect, top, step, inset=3):
    """Lanterns on ropes, every second row shifted: the rooms are too wide for torches."""
    x0, z0, x1, z1 = rect
    for row, z in enumerate(range(z0 + inset, z1 - 1, step)):
        for x in range(x0 + inset + (row % 2) * (step // 2), x1 - 1, step):
            if t.get(x, LANTERN_Y, z) != "air" or t.get(x, FEET, z) != "air":
                continue
            t.box(x, LANTERN_Y + 1, z, x, top, z, ROPE)
            t.set(x, LANTERN_Y, z, LANTERN)


def frame_x(t, x, z0, z1, top):
    """A timber frame across a passage running in x."""
    for z in (z0, z1):
        t.box(x, FEET, z, x, top, z, POST)
    t.box(x, top, z0, x, top, z1, BEAM)


def frame_z(t, z, x0, x1, top):
    """A timber frame across a passage running in z."""
    for x in (x0, x1):
        t.box(x, FEET, z, x, top, z, POST)
    t.box(x0, top, z, x1, top, z, BEAM)


def prop(t, x, z, top):
    t.box(x, FEET, z, x, top, z, POST)


def sealed_cut(t, x0, x1, z, wall):
    """A cut the crew boarded up: scenery in the wall, nothing behind it."""
    t.box(x0, FEET, z, x1, FEET + 4, z, BOARD)
    t.box(x0, FEET, z, x0, FEET + 4, z, POST)
    t.box(x1, FEET, z, x1, FEET + 4, z, POST)
    t.box(x0, FEET + 4, z, x1, FEET + 4, z, BEAM)


def track_x(t, x0, x1, z):
    t.box(x0, FEET, z, x1, FEET, z, RAIL, 1)


def ore(t, node, x, z):
    """A marked node at reach, on a lump of rock against the wall."""
    t.set(x, FEET, z, ROCK)
    t.set(x, EYE, z, node)


def carve_all(t):
    for rect in PASSAGES:
        carve(t, rect, PASS_TOP)
    for name, rect in ROOMS.items():
        carve(t, rect, COURT_TOP if name == "court" else ROOM_TOP)
    x0, z0, x1, z1 = SCREEN
    t.box(x0, FEET, z0, x1 - 1, ROOM_TOP, z1 - 1, ROCK)
    worn = ((ROCK, 5), ("default:cobble", 3), ("default:gravel", 2))
    for rect in PASSAGES:
        floor(t, rect, worn)
    for name, rect in ROOMS.items():
        floor(t, rect, ((PLANK, 1),) if name == "store" else worn)
    x0, z0, x1, z1 = SCREEN
    t.box(x0, FEET - 1, z0, x1 - 1, FEET - 1, z1 - 1, ROCK)


def arrival(t):
    x0, z0, x1, z1 = ROOMS["arrival"]
    sealed_cut(t, 16, 23, z0 - 1, NORTH)
    for x, z in ((x0, z0), (x1 - 1, z0), (x0, z1 - 1), (x1 - 1, z1 - 1)):
        prop(t, x, z, ROOM_TOP)
    t.box(x0, ROOM_TOP, z0, x1 - 1, ROOM_TOP, z0, BEAM)
    t.box(x0, ROOM_TOP, z1 - 1, x1 - 1, ROOM_TOP, z1 - 1, BEAM)
    t.box(10, FEET, 12, 10, FEET, 17, BENCH, 1)
    t.box(29, FEET, 26, 29, FEET, 29, BENCH, 3)
    for x, z in ((9, 9), (10, 9), (9, 10), (30, 9), (30, 10)):
        t.set(x, FEET, z, BARREL)
    t.set(20, FEET, 28, WAYSTONE)
    t.place("start_waystone", 20, FEET, 28)
    t.place("arrival", 20, FEET, 26)
    for z in (14, 26):
        t.set(8, 8, z, TORCH, WEST)
    t.set(31, 8, 12, TORCH, EAST)
    t.set(31, 8, 27, TORCH, EAST)


def passages(t):
    for x in (36, 42, 84, 90):
        frame_x(t, x, 16, 23, PASS_TOP)
    for z in (44, 50, 56):
        frame_z(t, z, 104, 111, PASS_TOP)
    for x in (84, 90, 36):
        frame_x(t, x, 104, 111, PASS_TOP)
    for x, z0, z1 in ((34, 16, 23), (39, 16, 23), (45, 16, 23), (82, 16, 23), (87, 16, 23), (93, 16, 23),
                      (82, 104, 111), (87, 104, 111), (93, 104, 111), (34, 104, 111), (38, 104, 111),
                      (42, 104, 111), (46, 104, 111)):
        t.set(x, 8, z0, TORCH, NORTH)
        t.set(x, 8, z1, TORCH, SOUTH)
    for z in (42, 47, 53, 59, 62):
        t.set(104, 8, z, TORCH, WEST)
        t.set(111, 8, z, TORCH, EAST)


def cart_bay(t):
    x0, z0, x1, z1 = ROOMS["cart_bay"]
    # the main track runs through, a siding along the far wall holds the carts
    track_x(t, 30, 100, 20)
    track_x(t, 50, 72, 37)
    t.set(52, FEET, 37, CART, 1)
    t.set(53, FEET, 37, CART, 1)
    t.set(69, FEET, 37, CART, 1)
    t.set(76, FEET, 11, CART, 0)
    for x in (56, 64, 72):
        t.box(x, FEET, z0, x, ROOM_TOP, z0, POST)
        t.box(x, FEET, z1 - 1, x, ROOM_TOP, z1 - 1, POST)
        t.box(x, ROOM_TOP, z0, x, ROOM_TOP, z1 - 1, BEAM)
    for x, z in ((49, 9), (50, 9), (49, 10), (78, 9), (77, 9)):
        t.set(x, FEET, z, BARREL)
    sealed_cut(t, 60, 67, z0 - 1, NORTH)
    ore(t, GOLD, 79, 36)
    t.set(77, 8, 39, TORCH, SOUTH)


def prop_room(t):
    x0, z0, x1, z1 = ROOMS["prop_room"]
    for x, z in ((100, 13), (100, 26), (100, 36), (108, 13), (108, 36), (116, 13), (116, 20),
                 (116, 28), (104, 32), (112, 34)):
        prop(t, x, z, ROOM_TOP)
    for x in (100, 108, 116):
        t.box(x, ROOM_TOP, z0, x, ROOM_TOP, z1 - 1, BEAM)
    # a prop that gave way
    t.box(103, FEET, 8, 106, FEET, 8, BEAM)
    t.set(112, FEET, 10, BEAM)
    t.set(113, FEET, 11, BEAM)
    sealed_cut(t, 104, 111, z0 - 1, NORTH)
    ore(t, JADE, 119, 36)
    t.set(119, 8, 33, TORCH, EAST)


def sorting(t):
    x0, z0, x1, z1 = ROOMS["sorting"]
    # the sorting benches, along both walls, ore baskets at their ends
    t.box(96, FEET, 67, 96, FEET, 84, TABLE)
    t.box(97, FEET, 67, 97, FEET, 84, TABLE)
    t.box(118, FEET, 67, 118, FEET, 84, TABLE)
    t.box(119, FEET, 67, 119, FEET, 84, TABLE)
    t.box(118, FEET, 98, 118, FEET, 117, TABLE)
    t.box(119, FEET, 98, 119, FEET, 117, TABLE)
    for x, z in ((96, 66), (97, 66), (118, 66), (119, 66), (118, 85), (119, 85), (96, 85),
                 (118, 118), (119, 118), (118, 97)):
        t.set(x, FEET, z, BARREL)
    t.box(96, FEET, 113, 96, FEET, 118, BENCH, 1)
    for z in (70, 80, 110):
        t.box(x0, ROOM_TOP, z, x1 - 1, ROOM_TOP, z, BEAM)
    t.set(103, FEET, 118, CART, 0)
    t.set(104, FEET, 118, CART, 0)


def court(t):
    x0, z0, x1, z1 = ROOMS["court"]
    # the open court: timber only in the walls, the last props torn down
    for x in (56, 64, 72):
        t.box(x, FEET, z0, x, ROOM_TOP, z0, POST)
        t.box(x, FEET, z1 - 1, x, ROOM_TOP, z1 - 1, POST)
    t.box(50, FEET, 118, 53, FEET, 118, BEAM)
    t.box(74, FEET, 89, 77, FEET, 89, BEAM)
    for x, z in ((49, 89), (78, 118), (49, 118)):
        t.set(x, FEET, z, "default:cobble")
    t.set(77, 8, 119, TORCH, SOUTH)


def store(t):
    x0, z0, x1, z1 = ROOMS["store"]
    for x, z in ((x0, z0), (x1 - 1, z0), (x0, z1 - 1), (x1 - 1, z1 - 1)):
        prop(t, x, z, ROOM_TOP)
    for x, z in ((16, 90), (17, 90), (16, 91), (22, 90), (23, 90)):
        t.set(x, FEET, z, BARREL)
    t.set(28, FEET, 96, CART, 0)
    t.set(20, FEET, 108, CHEST, FACE_EAST)
    t.place("chest", 20, FEET, 108)
    t.set(20, FEET, 116, WAYSTONE)
    t.place("end_waystone", 20, FEET, 116)
    for x, z, node in ((8, 100, GOLD), (31, 92, GOLD), (31, 100, GOLD), (8, 116, GOLD),
                       (8, 108, JADE), (31, 116, JADE)):
        ore(t, node, x, z)


def rooms(t):
    arrival(t)
    passages(t)
    cart_bay(t)
    prop_room(t)
    sorting(t)
    court(t)
    store(t)
    for name, rect in ROOMS.items():
        lanterns(t, rect, COURT_TOP if name == "court" else ROOM_TOP, 6)


def door(t):
    t.box(44, FEET, 104, 44, PASS_TOP, 111, DOOR)
    t.place("door", 44, FEET + 2, 108)


def packs(t):
    t.encounter("pack_a", SPIDER, 4, "normal", 60, FEET, 28)
    t.encounter("pack_b", SPIDER, 2, "normal", 108, FEET, 28)
    t.encounter("pack_b", GOLEM, 1, "elite", 112, FEET, 24)
    t.encounter("pack_c", SPIDER, 3, "normal", 108, FEET, 74)
    t.encounter("pack_c", GOLEM, 1, "elite", 108, FEET, 70)
    t.encounter("pack_d", SPIDER, 3, "normal", 108, FEET, 110)
    t.encounter("pack_d", GOLEM, 1, "elite", 108, FEET, 114)
    t.encounter("boss", BOSS, 1, "boss", 68, FEET, 108)


def build():
    t = Template("stilled_seam", (128, 32, 128), ROCK)
    carve_all(t)
    rooms(t)
    door(t)
    packs(t)
    t.dig(GOLD)
    t.dig(JADE)
    return t
