"""The Stilled Seam: the first, abandoned mine, reshaped in Round 72 STYLE.

The six rooms keep their order and all encounter, mineral and service places.
Compact fighting chambers open into short approach/exit cuts inside the old
room envelopes. Those cuts are passages, not extra combat floor: the fixed
cart-bay ore and original mouths lie beyond the spiders' twelve-node sight.
All paths between the mouths cross the chamber's covered floor.
"""
from template import Template
from shaping import cells_of, hang, roof, wall_lights, walls

ROCK = "default:stone"
FEET, EYE = 5, 6
ROOM_TOP, COURT_TOP, PASS_TOP = 13, 19, 9
POST, BEAM, PLANK = "default:tree", "default:pine_wood", "default:wood"
BOARD = "grug_decor:darkage_reinforced_wood"
TORCH = "default:torch_wall"
LANTERN = "grug_decor:xdecor_lantern_hanging"
CART, TABLE, BARREL = "grug_mapgen:mine_cart", "grug_decor:cottages_table", "grug_decor:cottages_barrel"
ORE, JADE = "grug_materials:stone_with_anthracite", "grug_materials:stone_with_jade"
DOOR, CHEST = "grug_expeditions:reward_door", "grug_expeditions:reward_chest"
WAYSTONE = "grug_expeditions:waystone"
SPIDER, GOLEM, BOSS = "grug_mobs:giant_spider", "grug_mobs:stone_golem", "grug_mobs:flintback"
WEST, EAST, NORTH, SOUTH = 3, 2, 5, 4
FACE_EAST = 3

# Authored floor cuts [x0,z0,x1,z1), not the old rectangular room envelopes.
ROOMS = {
    "arrival": ((12, 12, 27, 16), (10, 16, 32, 24), (12, 24, 29, 29), (16, 29, 24, 31)),
    "cart_bay": ((55, 18, 66, 21), (51, 21, 70, 24), (49, 24, 73, 33),
                 (52, 33, 71, 36), (56, 36, 66, 39)),
    "prop_room": ((104, 14, 116, 18), (99, 18, 120, 23), (99, 23, 119, 33),
                  (103, 33, 119, 38), (104, 38, 114, 39)),
    "sorting_c": ((102, 64, 114, 67), (99, 67, 117, 78), (100, 78, 117, 83), (102, 83, 114, 85)),
    "sorting_d": ((102, 100, 114, 102), (99, 102, 118, 115), (102, 115, 116, 119)),
    "court": ((63, 94, 72, 97), (59, 97, 76, 100), (57, 100, 79, 104),
              (54, 104, 80, 112), (56, 112, 79, 115), (60, 115, 76, 118), (63, 118, 72, 120)),
    "store": ((12, 88, 28, 92), (8, 92, 32, 120)),
}
PASSAGES = ((32, 16, 48, 24), (80, 16, 96, 24), (104, 40, 112, 64),
            (80, 104, 96, 112), (32, 104, 48, 112))
# The original mouths meet the smaller rooms through these low cuts. The ore
# cut is a blind siding after the cart pack, not a route around the fight.
CUTS = ((48, 16, 55, 24), (69, 16, 80, 24), (71, 30, 79, 38),
        (96, 16, 100, 24), (104, 39, 112, 40), (96, 80, 104, 112), (48, 104, 54, 112))
COURT_ENVELOPE = (54, 94, 80, 120)


def carve(t, cells, top, timber=False):
    for x, z in sorted(cells):
        t.box(x, FEET, z, x, top, z, "air")
        roll = ((x * 7349 + 13) ^ (z * 9151 + 7) ^ (x * z * 31)) % 10
        node = PLANK if timber else ROCK if roll < 5 else "default:cobble" if roll < 8 else "default:gravel"
        t.set(x, FEET - 1, z, node)


def ore(t, node, x, z):
    t.set(x, FEET, z, ROCK)
    t.set(x, EYE, z, node)
    # The rock above the seam closes the plinth even after its ore is dug.
    t.box(x, FEET + 2, z, x, ROOM_TOP, z, ROCK)


def display(t, x0, x1, z, node, top=ROOM_TOP):
    """A wall recess with a low display and a closed hood, not a climbable prop."""
    t.box(x0, FEET, z, x1, FEET, z, node)
    t.box(x0, FEET + 2, z, x1, top, z, BOARD)


def build_rooms(t):
    for name, rects in ROOMS.items():
        carve(t, cells_of(rects), COURT_TOP if name == "court" else ROOM_TOP, name == "store")
    carve(t, cells_of(PASSAGES + CUTS), PASS_TOP)
    # Compact chambers have different ceilings: a low refuge, a crooked cart
    # vault, a supported cleft, unequal sorting bays, then Flintback's torn dome.
    profiles = {
        "arrival": lambda x, z: 9 + min(3, max(0, (x - 10) // 4)),
        "cart_bay": lambda x, z: 10 + max(0, 4 - abs(x - 60) // 3) - (z >= 33),
        "prop_room": lambda x, z: 9 + min(5, max(0, (x - 99) // 3)) - (z % 8 == 0),
        "sorting_c": lambda x, z: 10 + min(3, max(0, (z - 64) // 4)),
        "sorting_d": lambda x, z: 10 + max(0, 4 - abs(x - 108) // 2),
        "court": lambda x, z: 20 - max(abs(x - 68) // 2, abs(z - 108) // 2) - ((x + z) % 9 == 0),
        "store": lambda x, z: 11 if z % 6 == 0 else 13,
    }
    for name, rects in ROOMS.items():
        top = COURT_TOP if name == "court" else ROOM_TOP
        cells = cells_of(rects)
        def material(x, z):
            if name == "court":
                return "default:cobble" if (x + 2 * z) % 7 < 2 else ROCK
            return BEAM if z % 6 == 0 or name == "store" else ROCK
        roof(t, cells, top, profiles[name], material)
        walls(t, cells, FEET + 3, top,
              lambda x, y, z: POST if (x + z) % 6 == 0 and name != "court" else
              ("default:cobble" if y == 9 + (x // 3 + z // 4) % 3 else ROCK))
    # Low connecting tunnels retain at least six nodes of clear width.
    # Their roof remains above the old PASS_TOP even where a chamber touches it.
    for x, z in sorted(cells_of(PASSAGES + CUTS)):
        t.box(x, FEET, z, x, PASS_TOP, z, "air")
        t.box(x, PASS_TOP + 1, z, x, COURT_TOP + 1, z, ROCK)
        if (x + z) % 7 == 0:
            t.set(x, PASS_TOP + 1, z, BEAM)


def arrival(t):
    # The closed original entrance, now a small timber refuge.
    t.box(16, FEET, 11, 23, 10, 11, BOARD)
    for x in (16, 23):
        t.box(x, FEET, 11, x, 11, 11, POST)
    display(t, 13, 17, 12, BARREL)
    t.set(20, FEET, 28, WAYSTONE)
    t.place("start_waystone", 20, FEET, 28)
    t.place("arrival", 20, FEET, 26)


def cart_bay(t):
    # Old sleepers lie flush; the hooded cart is embedded in the north wall.
    t.box(53, FEET - 1, 25, 68, FEET - 1, 25, BEAM)
    t.box(53, FEET - 1, 27, 68, FEET - 1, 27, BEAM)
    display(t, 59, 62, 17, CART)
    t.box(59, FEET, 16, 62, ROOM_TOP, 16, ROCK)
    ore(t, ORE, 79, 36)
    # A slumped rock eyebrow closes the blind mineral cut, flat floor below.
    t.box(76, 10, 30, 78, 12, 37, "default:cobble")


def prop_room(t):
    # Pairs of heavy timbers are in the walls, never free-standing sight screens.
    for z in (20, 28, 35):
        for x in (98, 120):
            t.box(x, FEET, z, x, ROOM_TOP, z, POST)
        for x in range(99, 119):
            if (x, z) in cells_of(ROOMS["prop_room"]):
                y = 9 + min(5, max(0, (x - 99) // 3)) - (z % 8 == 0)
                t.set(x, y, z, BEAM)
    t.box(105, FEET - 1, 33, 111, FEET - 1, 33, BEAM)
    ore(t, JADE, 119, 36)


def sorting(t):
    # Short abandoned sorting tables disappear into the rock screen at the bend.
    t.box(98, FEET, 70, 98, FEET, 77, TABLE)
    t.box(98, FEET + 2, 70, 98, ROOM_TOP, 77, BOARD)
    display(t, 105, 112, 119, TABLE)
    for x in (103, 112):
        t.box(x, FEET, 63, x, ROOM_TOP, 63, POST)
    for z in (73, 109):
        t.box(99, FEET - 1, z, 116, FEET - 1, z, PLANK)
    # The screen is solid through the hull. Its side shows the old boarded cuts.
    for z in (87, 96):
        t.box(104, 8, z, 104, 12, z, BOARD)


def court(t):
    # Torn rock piers and a high fractured dome; no platform under Flintback.
    for x, z in ((59, 96), (75, 96), (55, 113), (77, 116)):
        t.box(x, FEET, z, x, 15, z, "default:cobble")
    t.box(61, FEET - 1, 116, 66, FEET - 1, 116, BEAM)
    x0, z0, x1, z1 = COURT_ENVELOPE
    t.place("boss_room_min", x0, FEET, z0)
    t.place("boss_room_max", x1 - 1, FEET, z1 - 1)


def store(t):
    # An intentionally square timber store after the rough working face.
    display(t, 16, 23, 88, BARREL)
    t.set(20, FEET, 108, CHEST, FACE_EAST)
    t.place("chest", 20, FEET, 108)
    t.set(20, FEET, 116, WAYSTONE)
    t.place("end_waystone", 20, FEET, 116)
    for x, z, node in ((8, 100, ORE), (31, 92, ORE), (31, 100, ORE), (8, 116, ORE),
                       (8, 108, JADE), (31, 116, JADE)):
        ore(t, node, x, z)


def light(t):
    cells = cells_of(PASSAGES + CUTS + tuple(r for rects in ROOMS.values() for r in rects))
    for x, z in sorted(cells):
        if (z - 2) % 6 == 0 and (x - 2 - ((z - 2) // 6 % 2) * 3) % 6 == 0:
            hang(t, x, z, FEET + 3, COURT_TOP)
    wall_lights(t, cells, FEET)
    # An open chamber's centre gets a different light from its old access cut.
    for x, z in ((60, 28), (108, 28), (108, 74), (108, 110), (64, 105), (72, 105), (68, 113)):
        hang(t, x, z, FEET + 3, COURT_TOP)


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
    build_rooms(t)
    arrival(t)
    cart_bay(t)
    prop_room(t)
    sorting(t)
    court(t)
    store(t)
    door(t)
    packs(t)
    light(t)
    t.dig(ORE)
    t.dig(JADE)
    return t
