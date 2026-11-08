"""The Last Mint, the level 60 Expedition (Round 72 lane MINT): the approved plan of
docs/planning/round72-last-mint.md, The Stilled Seam's envelope mirrored on z, with the
user's rulings of the round on top (round72-plan.md section 2.9): every floor flat (no
step, no dais), and rooms small enough that no pack can be walked round. The STYLE
pass gives each workshop its masonry vault and metalwork, keeping
the floor footprint, the route, the pack places, the trap places, the pillars and the
ore places. tools/r72_mint/portable_test.lua proves them on the written file.

The box is 128 x 64 x 128. Every walking cell stands on y 31, its first air at y 32:
the lake below is 24 nodes deep to its lava. The route runs
0 > 1 (a) > 2 (b) > L > 3 (c) > 4 (d) > 5 (Duewarden) > 6."""
from template import Template
from shaping import hang, roof, walls

ROCK = "default:stone"
FLOOR_Y, FEET, EYE = 31, 32, 33
# The last air row: rooms 0, 1 and 6; the wisp rooms 2, 3 and 4 (seven air nodes, so a
# wisp stays in reach); the boss's hall; passages and landings; the lake's air.
ROOM_TOP, WISP_TOP, BOSS_TOP, PASS_TOP, LAKE_TOP = 43, 38, 47, 37, 59
LANTERN_Y = FEET + 3

BRICK, BLOCK = "default:stonebrick", "default:stone_block"
BASALT = "grug_decor:darkage_basalt_brick"
SLATE = "grug_decor:darkage_slate_tile"
COBBLE = "default:cobble"
IRON, STEEL = "grug_materials:iron_block", "grug_materials:steel_block"
LAVA = "default:lava_source"
TORCH = "default:torch_wall"
LANTERN, ROPE = "grug_decor:xdecor_lantern_hanging", "grug_decor:xdecor_rope"
# The template's ore and gem nodes are T2's: a run's tier writes its own in their
# places (catalogue.swaps), T6's Abyssal Crystal and Diamond at 60-69.
ORE, GEM = "grug_materials:stone_with_anthracite", "grug_materials:stone_with_jade"
DOOR, CHEST = "grug_expeditions:reward_door", "grug_expeditions:reward_chest"
WAYSTONE = "grug_expeditions:waystone"
SEEP, WISP = "grug_mobs:lava_flan", "grug_mobs:ember_wisp"
SENTINEL, BOSS = "grug_mobs:land_guard", "grug_mobs:duewarden"

# Rectangles x0, z0, x1, z1, upper bounds excluded, as the plan writes them, and how many
# nodes each outer corner is clipped by. A room is the union of its rectangles.
ROOMS = {
    "arrival": {"rects": [(8, 100, 32, 112, 0), (12, 96, 32, 100, 0), (16, 112, 28, 120, 0)],
                "top": ROOM_TOP, "floor": BRICK},
    "bins": {"rects": [(52, 94, 76, 114, 3)], "top": ROOM_TOP, "floor": BRICK},
    "furnace": {"rects": [(97, 91, 119, 114, 3)], "top": WISP_TOP, "floor": BASALT},
    "cooling": {"rects": [(96, 8, 120, 24, 3), (100, 24, 116, 27, 0)], "top": WISP_TOP, "floor": SLATE},
    "vestibule": {"rects": [(50, 49, 78, 71, 3)], "top": WISP_TOP, "floor": BASALT},
    "press": {"rects": [(50, 12, 78, 38, 2)], "top": BOSS_TOP, "floor": BASALT},
    "store": {"rects": [(8, 8, 32, 36, 0), (16, 36, 28, 40, 0)], "top": ROOM_TOP, "floor": "default:wood"},
}
# The way between the rooms, in route order. Each reaches into the rooms it joins.
PASSAGES = [
    (32, 104, 53, 112),   # 0 > 1
    (75, 104, 98, 112),   # 1 > 2
    (104, 80, 112, 92),   # 2 > the approach landing
    (104, 26, 112, 40),   # the exit landing > 3: the regrouping room
    (90, 16, 99, 24),     # 3 > the long passage
    (84, 16, 92, 64),     # the long passage, beside the lake's rock
    (77, 56, 85, 64),     # > 4
    (60, 37, 68, 50),     # 4 > 5
    (32, 16, 51, 24),     # 5 > 6, the reward door at x 44
]
# The lake (the plan's section): the basin, its two landings and five 4 x 4 pillars,
# six gaps of two node columns, every top at y 31. The lava fills y 2-7.
BASIN = (96, 44, 120, 76)
APPROACH, EXIT = (96, 76, 120, 80), (96, 40, 120, 44)
PILLARS = [(106, 70, 110, 74), (106, 64, 110, 68), (106, 58, 110, 62), (106, 52, 110, 56),
           (106, 46, 110, 50)]
LAVA_Y = (2, 7)
# A fireball crosses each gap at its middle, a node and a half over the tops: two of
# four, one per group, the second group 3 s after the first (traps.lua).
SHOT_Y = 32.5
WALLS = [("w1", 95.6, 68.5, "+x", 0), ("w1", 119.4, 62.5, "-x", 0),
         ("w2", 95.6, 56.5, "+x", 3), ("w2", 119.4, 50.5, "-x", 3)]
SHOT_PERIOD = 6
# Floor traps, two of four per room: the furnace room, the vestibule, the press floor.
FLOOR_TRAPS = [("f1", [(100, 107), (116, 107), (100, 95), (116, 95)]),
               ("f2", [(52, 67), (76, 67), (52, 51), (76, 51)]),
               ("f3", [(56, 31), (72, 31), (56, 15), (72, 15)])]
# The static press in its recess, full height so it is no perch; the brand on its face.
PRESS = (58, 8, 70, 12)
# The boss's pillars: four columns flanking his nave, full height.
COLUMNS = [(53, 18, 55, 20), (73, 18, 75, 20), (53, 28, 55, 30), (73, 28, 75, 30)]
# The broken circle and the two hooks, row by row from the top (Iron Blocks on pale
# Stone Blocks), on the press's face, x 58..69 from the left as one looks at it.
BRAND = [
    "....####....",
    "..##....##..",
    ".#..#..#..#.",
    ".#..#..#....",
    ".#..##.##.#.",
    "..##....##..",
    "....##.#....",
]
BRAND_TOP = 44
# Ore and gem: one ore after pack a, one gem after pack c, four ore and two gems in the
# store; each on a rock plinth at the wall, hull behind.
ROUTE_ORE, ROUTE_GEM = (75, 98), (119, 11)
STORE_ORE = [(8, 31), (31, 33), (31, 27), (8, 11)]
STORE_GEM = [(8, 19), (31, 11)]
# The packs, one line per mob at its place (the roster: tools/r72_mint/balance.py).
PACKS = [
    ("pack_a", SEEP, "normal", [(57, 99), (64, 97), (71, 99), (58, 109), (70, 109)]),
    ("pack_b", SEEP, "normal", [(102, 97), (114, 97), (104, 109)]),
    ("pack_b", SEEP, "elite", [(108, 100)]),
    ("pack_b", WISP, "normal", [(112, 107)]),
    ("pack_c", SEEP, "normal", [(101, 17), (115, 17), (108, 9)]),
    ("pack_c", SEEP, "elite", [(108, 13)]),
    ("pack_c", WISP, "normal", [(108, 18)]),
    ("pack_d", SENTINEL, "elite", [(64, 58)]),
    ("pack_d", WISP, "normal", [(57, 62), (71, 62), (64, 66)]),
]
BOSS_AT = (64, 23)
# wallmounted param2 of a torch by the wall behind it.
WEST, EAST, NORTH, SOUTH = 3, 2, 5, 4
FACE_EAST = 3  # the chest's front looks at the door


def chamfered(rect):
    """The cells of a rectangle less a triangle of `cut` nodes at each corner."""
    x0, z0, x1, z1, cut = rect
    for z in range(z0, z1):
        for x in range(x0, x1):
            dx = min(x - x0, x1 - 1 - x)
            dz = min(z - z0, z1 - 1 - z)
            if dx + dz >= cut:
                yield x, z


def room_cells(room):
    cells = set()
    for rect in room["rects"]:
        cells.update(chamfered(rect))
    return cells


def rect_cells(rect):
    x0, z0, x1, z1 = rect
    return {(x, z) for z in range(z0, z1) for x in range(x0, x1)}


def carve(t, cells, top, floor):
    for x, z in cells:
        t.box(x, FEET, z, x, top, z, "air")
        t.set(x, FLOOR_Y, z, floor)


def lanterns(t, cells, top, step=6):
    """Lanterns on ropes over the floor, every second row shifted, clear of the walls."""
    xs = sorted({x for x, _ in cells})
    zs = sorted({z for _, z in cells})
    for row, z in enumerate(range(zs[0] + 3, zs[-1] - 1, step)):
        for x in range(xs[0] + 3 + (row % 2) * (step // 2), xs[-1] - 1, step):
            near = all((x + dx, z + dz) in cells for dx in (-1, 0, 1) for dz in (-1, 0, 1))
            if near and t.get(x, LANTERN_Y, z) == "air":
                hang(t, x, z, LANTERN_Y, top)


def ore(t, node, x, z):
    """A marked node at reach, on a lump of rock at the wall."""
    t.set(x, FEET, z, ROCK)
    t.set(x, EYE, z, node)


def rooms(t):
    for name, room in ROOMS.items():
        carve(t, room_cells(room), room["top"], room["floor"])
    for rect in PASSAGES:
        x0, z0, x1, z1 = rect
        for z in range(z0, z1):
            for x in range(x0, x1):
                if t.get(x, FEET, z) == ROCK:
                    t.box(x, FEET, z, x, PASS_TOP, z, "air")
                    t.set(x, FLOOR_Y, z, COBBLE)


def lake(t):
    x0, z0, x1, z1 = BASIN
    # The basin: rock below the lava, lava, then air to the roof; pillars solid to y 31.
    t.box(x0, LAVA_Y[0], z0, x1 - 1, LAVA_Y[1], z1 - 1, LAVA)
    t.box(x0, LAVA_Y[1] + 1, z0, x1 - 1, LAKE_TOP, z1 - 1, "air")
    for px0, pz0, px1, pz1 in PILLARS:
        t.box(px0, 0, pz0, px1 - 1, FLOOR_Y - 1, pz1 - 1, BASALT)
        t.box(px0, FLOOR_Y, pz0, px1 - 1, FLOOR_Y, pz1 - 1, BLOCK)
    # The two landings: a floor at y 31 under the passage's roof, the full width.
    for lx0, lz0, lx1, lz1 in (APPROACH, EXIT):
        t.box(lx0, FEET, lz0, lx1 - 1, PASS_TOP, lz1 - 1, "air")
        t.box(lx0, FLOOR_Y, lz0, lx1 - 1, FLOOR_Y, lz1 - 1, BLOCK)
    # Light on the tops: torches at the tops' own height in each gap's two columns, on
    # both faces, so every top and landing is lit from its edges.
    for g0, g1 in gaps():
        for x in range(106, 110):
            t.set(x, FLOOR_Y, g0, TORCH, NORTH)
            t.set(x, FLOOR_Y, g1, TORCH, SOUTH)


def gaps():
    """The six gaps in crossing order, each its two node rows on z, the lower first."""
    tops = [APPROACH] + PILLARS + [EXIT]
    return [(b[3], a[1] - 1) for a, b in zip(tops, tops[1:])]


def press(t):
    x0, z0, x1, z1 = PRESS
    t.box(x0, FEET, z0, x1 - 1, BOSS_TOP, z1 - 1, BASALT)
    t.box(x0 + 2, FEET, z1 - 1, x1 - 3, FEET + 3, z1 - 1, STEEL)
    for row, line in enumerate(BRAND):
        y = BRAND_TOP - row
        for col, mark in enumerate(line):
            # Seen from the hall (looking towards -z), its left is +x.
            t.set(x1 - 1 - col, y, z1 - 1, IRON if mark == "#" else BLOCK)
    for x0, z0, x1, z1 in COLUMNS:
        t.box(x0, FEET, z0, x1 - 1, BOSS_TOP, z1 - 1, BASALT)
    # Duewarden's light: lanterns round his place.
    for x, z in ((60, 23), (68, 23), (64, 19), (64, 27)):
        t.box(x, LANTERN_Y + 1, z, x, BOSS_TOP, z, ROPE)
        t.set(x, LANTERN_Y, z, LANTERN)
    # His range (BOSSRESET): the hall's envelope, two opposite corners.
    t.place("boss_room_min", 48, FEET, 8)
    t.place("boss_room_max", 79, FEET, 39)


def arrival(t):
    t.set(20, FEET, 99, WAYSTONE)
    t.place("start_waystone", 20, FEET, 99)
    t.place("arrival", 20, FEET, 103)
    for z in (102, 108):
        t.set(8, FEET + 3, z, TORCH, WEST)


def store(t):
    t.set(20, FEET, 23, CHEST, FACE_EAST)
    t.place("chest", 20, FEET, 23)
    t.set(20, FEET, 15, WAYSTONE)
    t.place("end_waystone", 20, FEET, 15)
    for x, z in STORE_ORE:
        ore(t, ORE, x, z)
    for x, z in STORE_GEM:
        ore(t, GEM, x, z)


def door(t):
    t.box(44, FEET, 16, 44, PASS_TOP, 23, DOOR)
    t.place("door", 44, FEET + 2, 19)


def traps(t):
    for group, spots in FLOOR_TRAPS:
        for x, z in spots:
            t.trap_floor(group, 2, x, FEET, z)
    for group, x, z, axis, offset in WALLS:
        t.trap_wall(group, 1, x, SHOT_Y, z, axis, SHOT_PERIOD, offset)


def packs(t):
    for room, mob, tier, spots in PACKS:
        for x, z in spots:
            t.encounter(room, mob, 1, tier, x, FEET, z)
    t.encounter("boss", BOSS, 1, "boss", BOSS_AT[0], FEET, BOSS_AT[1])


def wall_torches(t, step=3):
    """A torch at eye height on every wall beside the floor, every `step` nodes along it;
    the floor is every open cell at y 32 over the masonry of y 31."""
    for z in range(1, 127):
        for x in range(1, 127):
            if t.get(x, FEET, z) != "air" or t.get(x, FLOOR_Y, z) in ("air", LAVA, TORCH):
                continue
            for dx, dz, face in ((-1, 0, WEST), (1, 0, EAST), (0, -1, NORTH), (0, 1, SOUTH)):
                along = z if dx else x
                if along % step == 0 and t.get(x + dx, FEET + 3, z + dz) in \
                        (ROCK, BRICK, BLOCK, BASALT, SLATE, IRON, STEEL) and \
                        t.get(x, FEET + 3, z) == "air":
                    t.set(x, FEET + 3, z, TORCH, face)


def light(t):
    for name, room in ROOMS.items():
        lanterns(t, room_cells(room), room["top"])
    wall_torches(t)


def shape(t):
    """Masonry courses, closed wall displays and vaults over the unchanged floor.

    Wisp rooms alternate first-solid rows 38/39 (six/seven clear nodes).
    The press's pillars continue into the roof; no cornice has an open top.
    """
    profiles = {
        "arrival": lambda x, z: 38 + min(4, max(0, (x - 8) // 3)) - (z > 111),
        "bins": lambda x, z: 38 + min(6, max(0, (z - 94) // 2), max(0, (114 - z) // 2)),
        "furnace": lambda x, z: 38 if z % 4 == 0 or x in (98, 117) else 39,
        "cooling": lambda x, z: 38 if x % 4 == 0 or z in (9, 25) else 39,
        "vestibule": lambda x, z: 38 if x % 6 in (0, 1) or z % 6 in (0, 1) else 39,
        "press": lambda x, z: 48 - max(0, abs(2 * x - 127) // 4 - 1),
        "store": lambda x, z: 40 if z % 6 == 0 else 42,
    }
    for name, room in ROOMS.items():
        cells = room_cells(room)
        def material(x, z):
            if name == "furnace":
                return IRON if z % 4 == 0 else BASALT
            if name == "cooling":
                return BLOCK if x % 4 == 0 else SLATE
            if name == "vestibule":
                return IRON if x % 6 in (0, 1) or z % 6 in (0, 1) else BASALT
            if name == "press":
                return STEEL if z in (18, 19, 28, 29) else BASALT
            if name == "store":
                return IRON if z % 6 == 0 else BRICK
            return BLOCK if z % 6 == 0 else BRICK
        roof(t, cells, room["top"], profiles[name], material)
        def facing(x, y, z):
            if name == "cooling":
                return SLATE if y % 3 == 0 else BRICK
            if name in ("furnace", "vestibule", "press"):
                return IRON if (x + z) % 6 == 0 else BASALT
            if name == "store":
                return IRON if y == 36 or (x + z) % 8 == 0 else BRICK
            return BLOCK if y % 4 == 0 else BRICK
        # Leave the mineral's rock backing intact. The upper walls are dressed
        # throughout; below, the stone jambs around each ore seam stay exposed.
        walls(t, cells, FEET + 2, room["top"], facing)
        for x, z in sorted(cells):
            for dx, dz in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, nz = x + dx, z + dz
                minerals = [ROUTE_ORE, ROUTE_GEM] + STORE_ORE + STORE_GEM
                if any(abs(nx - ox) + abs(nz - oz) <= 2 for ox, oz in minerals):
                    continue
                for y in (FEET, EYE):
                    if t.get(nx, y, nz) == ROCK:
                        t.set(nx, y, nz, facing(nx, y, nz))
    # Receiving recess: a blind side arch, sealed with iron, its staggered crown
    # reads in the wall without opening another room or making a shelf.
    for z in range(102, 110):
        crown = 39 - abs(z - 106) // 2
        t.box(7, FEET, z, 7, crown, z, IRON)
        t.set(7, crown + 1, z, BLOCK)
    # The bins are closed wall pockets. Three iron mouths descend from the vault;
    # their bottoms remain at least three nodes above the working floor.
    for x in (56, 63, 70):
        t.box(x, 35, 93, x + 2, 40, 93, IRON)
        t.box(x, 41, 93, x + 2, 43, 93, BRICK)
        # Full blocks in the floor, not raised rail nodes or a grate over a hole.
        for rail_x in (x, x + 2):
            t.box(rail_x, FLOOR_Y, 96, rail_x, FLOOR_Y, 103, IRON)
    # Cooling racks: bands in the back wall, not bars the player can climb.
    for y in (35, 37):
        t.box(101, y, 7, 114, y, 7, IRON)
    # Vestibule die cupboards, capped into the outer wall.
    for z in (54, 64):
        t.box(49, 35, z, 49, 37, z + 2, STEEL)
        t.box(78, 35, z, 78, 37, z + 2, STEEL)
    for x in (61, 66):
        t.box(x, FLOOR_Y, 13, x, FLOOR_Y, 36, STEEL)
    for z in (54, 65):
        t.box(53, FLOOR_Y, z, 74, FLOOR_Y, z, IRON)
    # The furnace throat keeps its basin, pillars and every shot cell untouched.
    # Alternating tall piers, pale tie courses and black masonry give it scale.
    for x in (95, 120):
        for z in range(44, 76):
            for y in range(8, 61):
                node = BLOCK if y in (30, 45, 59) else (IRON if z % 6 == 0 else BASALT)
                t.set(x, y, z, node)
    for z in (43, 76):
        for x in range(96, 120):
            for y in range(38, 61):
                t.set(x, y, z, BLOCK if y in (45, 59) else BASALT)
    for z in range(44, 76):
        t.box(96, 60, z, 119, 60, z, IRON if z % 6 == 0 else BASALT)


def build():
    t = Template("last_mint", (128, 64, 128), ROCK)
    rooms(t)
    lake(t)
    press(t)
    arrival(t)
    store(t)
    door(t)
    ore(t, ORE, *ROUTE_ORE)
    ore(t, GEM, *ROUTE_GEM)
    shape(t)
    light(t)
    traps(t)
    packs(t)
    t.dig(ORE)
    t.dig(GEM)
    return t
