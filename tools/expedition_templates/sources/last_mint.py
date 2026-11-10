"""The Last Mint, the level 60 Expedition (Round 72 lane MINT, redesigned in Round 73 lane
MINT): a forge-mint over a lava lake, masonry vaults, basalt and metal. The route, the
packs, the boss, the lake with its pillars and shots, the press, the door, the chest, the
waystones, the ore places and the Round 72 traps stay (round73-expedition-redesign-concept.md
section 3); the floor is a height map with stairs (relief.py), the passages bend
(passages.py), the light comes from what belongs there (emberglass lamps set in the
masonry, furnace mouths, lanterns over the waystones and the boss, candles in wall niches,
three lava falls), two dark passages hold the ambush candidates (pick 1), and critters,
dressing and embers fill it in. tools/r72_mint/portable_test.lua proves it on the written
file with every rule of tools/expedition_templates/proofs.lua on.

The box is 128 x 64 x 128. The lake's tops and landings stand at the first air row 32 over
a lake 24 nodes deep; the rooms' floors lie between 30 and 34. The route runs
0 > 1 (a) > 2 (b) > L > 3 (c) > 4 (d) > 5 (Duewarden) > 6.

Room types, none repeated next to another: 0 terraces climbing west; 1 a sunken sorting
floor; 2 the furnace hall, a lava fall its centrepiece and a raised hearth; L the lake;
3 a slag heap of several levels against the racks; 4 terraces climbing west under a low
iron coffer; 5 Duewarden's sunken arena; 6 the strongroom, flat and square on purpose."""
import dressing
import hazards
import light
import passages
import registry
import relief
from shaping import hang
from template import Template

ROCK = "default:stone"
FLOOR_Y, FEET, EYE = 31, 32, 33
# The lake's air, the passages' landings (Round 72's numbers).
LAKE_TOP, PASS_TOP = 59, 37

BRICK, BLOCK = "default:stonebrick", "default:stone_block"
CLAY = "default:brick"
BASALT = "grug_decor:darkage_basalt_brick"
SLATE = "grug_decor:darkage_slate_tile"
COBBLE, MOSSY = "default:cobble", "default:mossycobble"
OBSIDIAN = "default:obsidianbrick"
IRON, STEEL = "grug_materials:iron_block", "grug_materials:steel_block"
WOOD = "default:wood"
LAVA = "default:lava_source"
TORCH = "default:torch_wall"
LAMP = "grug_materials:emberglass_lamp"          # light 14, set in the masonry
EMBERS = "grug_decor:capital_lava"               # light 6, glowing coals in a furnace mouth
LANTERN = "grug_decor:xdecor_lantern_hanging"
CANDLE = "grug_decor:xdecor_candle"
COBWEB = "grug_decor:xdecor_cobweb"
BONES, SKULL, SHARDS = "grug_nodes:bone_pile", "grug_nodes:skull_human", "grug_nodes:bones_fragments"
MOSS, LICHEN, LICHEN_B = "grug_nodes:moss_carpet", "grug_nodes:lichen_carpet", "grug_nodes:lichen_carpet_b"
EMBER_STAR = "grug_nodes:flower_ember_star"
# The template's ore and gem nodes are T2's: a run's tier writes its own in their
# places (catalogue.swaps), T6's Abyssal Crystal and Diamond at 60-69.
ORE, GEM = "grug_materials:stone_with_anthracite", "grug_materials:stone_with_jade"
DOOR, CHEST = "grug_expeditions:reward_door", "grug_expeditions:reward_chest"
WAYSTONE = "grug_expeditions:waystone"
SEEP, WISP = "grug_mobs:lava_flan", "grug_mobs:ember_wisp"
SENTINEL, BOSS = "grug_mobs:land_guard", "grug_mobs:duewarden"
BAT, CRAWLER, WEEVIL = "grug_mobs:cave_bat", "grug_mobs:cave_crawler", "grug_mobs:bone_weevil"
# The tallest mob: the Sentinel's body at the elite tier's 1.4 (Duewarden, the pack d
# elite), 3.66 nodes; every walking cell keeps 5 nodes of air, and a light hangs at the
# feet + 5 or higher, or sits in the wall (the user, 2026-11-10).
CLEAR = 5
# The wisp rooms keep a wisp within seven nodes of air over the floor (Round 72).
WISP_AIR = 7
FACE_EAST = 3  # the chest's front looks at the door

# Rectangles x0, z0, x1, z1 (upper bounds excluded) and the nodes each outer corner loses.
ROOMS = {
    "arrival": [(8, 101, 32, 113, 2), (12, 96, 31, 101, 1), (15, 113, 28, 121, 2)],
    "bins": [(52, 95, 77, 114, 3), (56, 93, 72, 95, 0)],
    "furnace": [(97, 91, 120, 115, 3)],
    "cooling": [(96, 8, 120, 24, 3), (100, 24, 116, 27, 0)],
    "vestibule": [(50, 49, 78, 71, 3)],
    "press": [(50, 12, 78, 38, 2)],
    "store": [(8, 8, 32, 36, 0), (16, 36, 28, 40, 0)],
}
# Each room's base height (the first air row) and its floor and stair materials.
BASE = {"arrival": 32, "bins": 31, "furnace": 32, "cooling": 33, "vestibule": 32, "press": 32, "store": 32}
FLOOR = {"arrival": BRICK, "bins": BRICK, "furnace": BASALT, "cooling": SLATE, "vestibule": BASALT,
         "press": BASALT, "store": WOOD}
STAIR = {"arrival": "stonebrick", "bins": "stonebrick", "furnace": "obsidianbrick", "cooling": "stone_block",
         "vestibule": "obsidianbrick", "press": "obsidianbrick", "store": "wood"}
WISP_ROOMS = ("furnace", "cooling", "vestibule")

# The lake (Round 72's section): the basin, its two landings and five 4 x 4 pillars, six
# gaps of two node columns, every top at y 31. The lava fills y 2-7.
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
# Each lies on flat floor (its cell and its neighbours at one height).
FLOOR_TRAPS = [("f1", [(101, 108), (114, 109), (98, 96), (111, 95)]),
               ("f2", [(53, 66), (70, 66), (52, 52), (75, 52)]),
               ("f3", [(54, 33), (73, 33), (56, 14), (72, 15)])]
# The static press in its recess, full height so it is no perch; the brand on its face.
PRESS = (58, 8, 70, 12)
# The boss's pillars: four columns flanking his nave, full height.
COLUMNS = [(53, 18, 55, 20), (73, 18, 75, 20), (53, 28, 55, 30), (73, 28, 75, 30)]
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
ROUTE_ORE, ROUTE_GEM = (76, 98), (119, 11)
STORE_ORE = [(8, 31), (31, 33), (31, 27), (8, 11)]
STORE_GEM = [(8, 19), (31, 11)]
MINERALS = [ROUTE_ORE, ROUTE_GEM] + STORE_ORE + STORE_GEM
# The packs, one line per mob at its place (the roster: tools/r72_mint/balance.py).
PACKS = [
    ("pack_a", SEEP, "normal", [(57, 99), (65, 97), (72, 101), (58, 109), (69, 110)]),
    ("pack_b", SEEP, "normal", [(103, 96), (115, 99), (102, 106)]),
    ("pack_b", SEEP, "elite", [(108, 101)]),
    ("pack_b", WISP, "normal", [(112, 106)]),
    ("pack_c", SEEP, "normal", [(101, 14), (112, 13), (108, 10)]),
    ("pack_c", SEEP, "elite", [(108, 15)]),
    ("pack_c", WISP, "normal", [(108, 21)]),
    ("pack_d", SENTINEL, "elite", [(64, 58)]),
    ("pack_d", WISP, "normal", [(54, 57), (71, 61), (64, 66)]),
]
BOSS_AT = (64, 23)
# Critters (Round 73): never in a pack's room. Bats in the arrival's and the store's high
# vaults, a crawler in the niche by the cooling room's door, a weevil by the bones in the
# niche before the reward door.
CRITTERS = [("bats", BAT, 24, 106), ("bats_store", BAT, 14, 30), ("crawlers", CRAWLER, 93, 16),
            ("weevils", WEEVIL, 47, 15)]


def chamfered(rect):
    """The cells of a rectangle less a triangle of `cut` nodes at each corner."""
    x0, z0, x1, z1, cut = rect
    for z in range(z0, z1):
        for x in range(x0, x1):
            if min(x - x0, x1 - 1 - x) + min(z - z0, z1 - 1 - z) >= cut:
                yield x, z


def room_cells(name):
    cells = set()
    for rect in ROOMS[name]:
        cells.update(chamfered(rect))
    if name == "press":
        cells -= {(x, z) for x0, z0, x1, z1 in COLUMNS for x in range(x0, x1) for z in range(z0, z1)}
    return cells - set(MINERALS)


# ---- The passages (route order) -----------------------------------------------------------
# Each joins its rooms at their edges; profile (s, dh) from the first room's base.

def passage_list():
    out = {}
    # 0 > 1: bends twice, narrows, a niche with a crawler, a step down to the bins' floor.
    p = passages.Passage([(29.5, 106.5), (37, 104.5), (43, 109.5), (48, 107), (54.5, 105.5)],
                         width=lambda s: 6 if s < 0.35 else (5 if s < 0.7 else 7))
    p.niche(0.5, side=-1, depth=2, width=3)
    out["p01"] = (p, 32, [(0, 0), (0.55, 0), (0.8, -1)])
    # 1 > 2, the first ambush candidate (a2): north out of the bins, a long straight dark
    # run east to the glow of a lava fall at its end, then south into the furnace hall.
    p = passages.Passage([(69.5, 95), (69.5, 89), (72.5, 86), (99.5, 86)],
                         width=lambda s: 5 if s > 0.2 else 6)
    out["p12"] = (p, 31, [(0, 0), (0.06, 0), (0.16, 1)])
    # The south leg leaves the run three nodes before its end: the run ends in a short bay
    # at the lava fall, the leg's mouth clear of the basin (MOUTH_CLEAR).
    p = passages.Passage([(92, 88), (98, 93)], width=6)
    out["p12s"] = (p, 32, None)
    # 2 > the approach landing: short, a jog and a widening before the lake.
    p = passages.Passage([(109, 93), (108, 87.5), (110, 84), (108.5, 79.5)],
                         width=lambda s: 6 if s < 0.6 else 8)
    out["p2L"] = (p, 32, None)
    # The exit landing > 3: a bend and a stair run up to the cooling room.
    p = passages.Passage([(108, 40.5), (106, 36), (109, 31), (108, 25)],
                         width=lambda s: 6 if s < 0.5 else 7)
    out["pL3"] = (p, 32, [(0, 0), (0.35, 0), (0.6, 1)])
    # 3 > 4, the second ambush candidate (a1): west out of the cooling room, a long
    # straight dark run south beside the lake's rock, a stair run down, west into the
    # vestibule.
    p = passages.Passage([(97.5, 19.5), (91, 19.5), (88, 22.5), (88, 56), (86, 60), (76, 60)],
                         width=lambda s: 6 if s < 0.12 or s > 0.86 else 5)
    p.niche(0.08, side=1, depth=2, width=3)
    out["p34"] = (p, 33, [(0, 0), (0.62, 0), (0.72, -1)])
    # 4 > 5: a jog, a lower stretch under iron ties, into the hall.
    p = passages.Passage([(64, 50.5), (62, 45.5), (65.5, 41.5), (64, 36.5)], width=lambda s: 6 if s < 0.5 else 7)
    out["p45"] = (p, 32, None)
    # 5 > 6: through the reward door at x 44 (its cells z 16-23), a bend before the store.
    p = passages.Passage([(51.5, 21), (47.5, 19.5), (40.5, 19.5), (36, 21.5), (30.5, 21.5)],
                         width=lambda s: 8 if 0.15 < s < 0.6 else 6)
    p.niche(0.2, side=1, depth=2, width=3)
    out["p56"] = (p, 32, None)
    return out


# ---- Relief per room -------------------------------------------------------------------------

def room_heights(name, cells, keep):
    base = BASE[name]
    features = {
        # Terraces climbing west, the receiving floor two steps over the way out.
        "arrival": [relief.terrace(18, 106, angle=170, levels=2, steep=3, seed=3, wobble=0.7, width=16),
                    relief.pit(21, 117, 3.5, depth=1, gentle=90, steep=2, seed=12, wobble=0.3)],
        # A sunken sorting floor, two levels, a long gentle run to the south-east.
        "bins": [relief.pit(63, 104, 7, depth=2, gentle=40, steep=2, stretch=2, seed=11, wobble=0.3)],
        # The raised hearth along the east wall under the furnace mouths.
        "furnace": [relief.rise(118, 101, 6, height=1, gentle=180, seed=5),
                    relief.rise(103, 95, 3.5, height=1, gentle=270, seed=8)],
        # The slag heap against the racks: two levels, steep to the south.
        "cooling": [relief.rise(110, 9, 7, height=2, gentle=200, stretch=2.5, seed=21),
                    relief.pit(117, 21, 2.5, depth=1, gentle=False, seed=4)],
        # Terraces climbing west, a shallow trough by the east wisp.
        "vestibule": [relief.terrace(58, 60, angle=185, levels=2, steep=3, seed=6, wobble=0.7, width=16),
                      relief.pit(70, 64, 5, depth=1, gentle=120, steep=2, seed=9, wobble=0.35)],
        # Duewarden's sunken arena, two rings, its long side toward the door.
        "press": [relief.pit(64, 25, 8, depth=2, gentle=200, steep=2, stretch=2, seed=17, wobble=0.25),
                  relief.pit(59, 29, 3.5, depth=1, gentle=False, seed=2)],
        "store": [],
    }[name]
    if not features:
        return relief.flat(cells, base)
    return relief.vary(cells, base, features, seed=len(name), keep=keep)


def build_floor():
    """The floor's height map, the passages' mouths and every room's cells."""
    cells = {name: room_cells(name) for name in ROOMS}
    routes = passage_list()
    keep = {name: [] for name in ROOMS}
    mouths = []
    for key, (p, base, profile) in routes.items():
        body = p.body()
        for end in (0, 1):
            mouth = p.mouth(end)
            # The flue run's east end is a dead end at its lava fall, not a mouth: the run
            # goes on through the south leg's mouth (p12s).
            if (key, end) != ("p12", 1):
                mouths += mouth
            for name, own in cells.items():
                if any((x + dx, z + dz) in own for x, z in mouth for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    keep[name] += [c for c in mouth if c not in own] + \
                        [(x + dx, z + dz) for x, z in mouth for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))
                         if (x + dx, z + dz) in own]
        del body
    floor = {}
    for name, own in cells.items():
        own_keep = [c for c in keep[name] if c in own]
        floor.update(room_heights(name, own, own_keep))
    for key, (p, base, profile) in routes.items():
        for cell, h in p.heights(base, profile).items():
            floor.setdefault(cell, h)
    return floor, cells, routes, sorted(set(mouths))


# ---- Carving, walls, roofs ---------------------------------------------------------------

def roof_of(name):
    """The last air row over a cell: a function of x, z and its floor h."""
    if name == "arrival":
        return lambda x, z, h: max(h + 7, 42 - max(0, (x - 8) // 5) - (z > 112))
    if name == "bins":
        return lambda x, z, h: max(h + 7, 37 + min(5, max(0, (z - 94) // 2), max(0, (114 - z) // 2)))
    if name in ("furnace", "cooling"):
        return lambda x, z, h: h + (4 if (x * 3 + z) % 7 == 0 else 5)
    if name == "vestibule":
        return lambda x, z, h: h + (4 if x % 6 in (0, 1) or z % 6 in (0, 1) else 5)
    if name == "press":
        return lambda x, z, h: max(h + 9, 47 - max(0, abs(2 * x - 127) // 4 - 1))
    return lambda x, z, h: 39 if z % 6 == 0 else 41


def ceiling_of(name):
    return {
        "arrival": lambda x, z: BLOCK if z % 6 == 0 else BRICK,
        "bins": lambda x, z: BLOCK if z % 5 == 0 else CLAY,
        "furnace": lambda x, z: IRON if z % 4 == 0 else BASALT,
        "cooling": lambda x, z: BLOCK if x % 4 == 0 else SLATE,
        "vestibule": lambda x, z: IRON if x % 6 in (0, 1) or z % 6 in (0, 1) else BASALT,
        "press": lambda x, z: STEEL if z in (18, 19, 28, 29) else BASALT,
        "store": lambda x, z: IRON if z % 6 == 0 else BRICK,
    }[name]


def facing_of(name):
    return {
        "arrival": lambda x, y, z: BLOCK if y % 4 == 0 else BRICK,
        "bins": lambda x, y, z: BLOCK if y % 4 == 0 else CLAY,
        "furnace": lambda x, y, z: IRON if (x + z) % 6 == 0 else BASALT,
        "cooling": lambda x, y, z: SLATE if y % 3 == 0 else BRICK,
        "vestibule": lambda x, y, z: IRON if (x + z) % 6 == 0 else BASALT,
        "press": lambda x, y, z: IRON if (x + z) % 6 == 0 else BASALT,
        "store": lambda x, y, z: IRON if y == 36 or (x + z) % 8 == 0 else BRICK,
    }[name]


def carve(t, floor, cells, top):
    for x, z in sorted(cells):
        h = floor[x, z]
        t.box(x, h, z, x, top(x, z, h), z, "air")


def dress(t, floor, cells, top, ceiling, facing):
    """The roof's underside and the masonry facing the cells (rock only)."""
    for x, z in sorted(cells):
        h = floor[x, z]
        last = top(x, z, h)
        if t.get(x, last + 1, z) == ROCK:
            t.set(x, last + 1, z, ceiling(x, z))
        for dx, dz in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nx, nz = x + dx, z + dz
            for y in range(h, last + 1):
                if t.get(nx, y, nz) == ROCK and (nx, nz) not in MINERALS:
                    t.set(nx, y, nz, facing(nx, y, nz))


def passage_top(key):
    """The passages' last air row: six nodes of air, five under a lower stretch."""
    low = {"p01": (40, 46), "p45": (62, 67), "p56": (35, 39)}
    def top(x, z, h):
        lo = low.get(key)
        if lo and lo[0] <= (x if key != "p45" else z + 20) <= lo[1]:
            return h + CLEAR - 1
        return h + CLEAR
    return top


# ---- The lake, the press, the places -----------------------------------------------------

def lake(t):
    x0, z0, x1, z1 = BASIN
    t.box(x0, LAVA_Y[0], z0, x1 - 1, LAVA_Y[1], z1 - 1, LAVA)
    t.box(x0, LAVA_Y[1] + 1, z0, x1 - 1, LAKE_TOP, z1 - 1, "air")
    for px0, pz0, px1, pz1 in PILLARS:
        t.box(px0, 0, pz0, px1 - 1, FLOOR_Y - 1, pz1 - 1, BASALT)
        t.box(px0, FLOOR_Y, pz0, px1 - 1, FLOOR_Y, pz1 - 1, BLOCK)
    for lx0, lz0, lx1, lz1 in (APPROACH, EXIT):
        t.box(lx0, FEET, lz0, lx1 - 1, PASS_TOP, lz1 - 1, "air")
        t.box(lx0, FLOOR_Y, lz0, lx1 - 1, FLOOR_Y, lz1 - 1, BLOCK)
    # Light on the tops: torches at the tops' own height in each gap's two columns, on
    # both faces, so every top and landing is lit from its edges (Round 72).
    for g0, g1 in gaps():
        for x in range(106, 110):
            t.set(x, FLOOR_Y, g0, TORCH, 5)
            t.set(x, FLOOR_Y, g1, TORCH, 4)
    # The furnace throat: tall piers, pale tie courses and black masonry.
    for x in (95, 120):
        for z in range(44, 76):
            for y in range(8, 61):
                t.set(x, y, z, BLOCK if y in (30, 45, 59) else (IRON if z % 6 == 0 else BASALT))
    for z in (43, 76):
        for x in range(96, 120):
            for y in range(38, 61):
                t.set(x, y, z, BLOCK if y in (45, 59) else BASALT)
    for z in range(44, 76):
        t.box(96, 60, z, 119, 60, z, IRON if z % 6 == 0 else BASALT)


def gaps():
    """The six gaps in crossing order, each its two node rows on z, the lower first."""
    tops = [APPROACH] + PILLARS + [EXIT]
    return [(b[3], a[1] - 1) for a, b in zip(tops, tops[1:])]


def press(t, floor):
    x0, z0, x1, z1 = PRESS
    t.box(x0, FEET, z0, x1 - 1, 47, z1 - 1, BASALT)
    t.box(x0 + 2, FEET, z1 - 1, x1 - 3, FEET + 3, z1 - 1, STEEL)
    # The press's two furnace eyes, emberglass in its steel face.
    for x in (x0 + 3, x1 - 4):
        t.set(x, FEET + 2, z1 - 1, LAMP)
    for row, line in enumerate(BRAND):
        for col, mark in enumerate(line):
            # Seen from the hall (looking towards -z), its left is +x.
            t.set(x1 - 1 - col, BRAND_TOP - row, z1 - 1, IRON if mark == "#" else BLOCK)
    for cx0, cz0, cx1, cz1 in COLUMNS:
        t.box(cx0, 28, cz0, cx1 - 1, 47, cz1 - 1, BASALT)
    t.place("boss_room_min", 48, FEET, 8)
    t.place("boss_room_max", 79, FEET, 39)


def ore(t, floor, node, x, z):
    """A marked node at reach, on a lump of rock at the wall: the plinth at the floor of
    the cells beside it, the node at eye height, rock above (the seam stays closed)."""
    h = min(floor[x + dx, z + dz] for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)) if (x + dx, z + dz) in floor)
    t.box(x, h - 1, z, x, h, z, ROCK)
    t.set(x, h + 1, z, node)
    t.box(x, h + 2, z, x, 47, z, ROCK)


def flat_at(floor, x, z):
    h = floor[x, z]
    if relief.stair_at(floor, x, z):
        raise ValueError(f"last_mint: {x},{z} lies on a stair")
    return h


# ---- Light -------------------------------------------------------------------------------

SIDES = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}


def at_wall(floor, x, z, side):
    """From the floor cell x, z toward `side` to the last floor cell before the wall:
    that cell and the wall cell beyond it."""
    dx, dz = SIDES[side]
    if (x, z) not in floor:
        raise ValueError(f"last_mint: {x},{z} is no floor cell")
    while (x + dx, z + dz) in floor:
        x, z = x + dx, z + dz
    return (x, z), (x + dx, z + dz)


def lamp(t, floor, x, z, side, up=2, node=LAMP, param2=0):
    """A light set into the wall the floor cell x, z faces toward `side` ("+x", ...),
    `up` rows over the feet at the wall: a wall cell, so it hangs over no walking cell."""
    (fx, fz), (wx, wz) = at_wall(floor, x, z, side)
    y = floor[fx, fz] + up
    if t.get(wx, y, wz) == "air":
        raise ValueError(f"last_mint: no wall for a light at {wx},{y},{wz}")
    t.set(wx, y, wz, node, param2)


def niche_candle(t, floor, x, z, side, up=1):
    """A candle in a one-node niche cut into the wall the cell faces: closed above, so no
    body fits in it."""
    (fx, fz), (wx, wz) = at_wall(floor, x, z, side)
    y = floor[fx, fz] + up
    if t.get(wx, y, wz) == "air":
        raise ValueError(f"last_mint: no wall for a candle at {wx},{y},{wz}")
    t.set(wx, y - 1, wz, BLOCK)
    t.set(wx, y, wz, CANDLE, 1)  # wallmounted 1: standing on the niche's floor


def ceiling_lamps(t, floor, cells, count, spacing, seed, avoid=()):
    """Emberglass set into a low vault: the roof cell over each picked floor cell."""
    for x, z in light.spread(cells, count, spacing, seed, avoid):
        y = floor[x, z]
        while t.get(x, y, z) == "air":
            y += 1
        t.set(x, y, z, LAMP)


def lantern(t, floor, x, z, over=5):
    """A lantern on a rope from the vault, `over` nodes over the highest floor round it."""
    h = max(floor.get((x + dx, z + dz), floor[x, z]) for dx in (-1, 0, 1) for dz in (-1, 0, 1))
    hang(t, x, z, h + over, 60)


def lanterns(t, floor, cells, count, spacing, seed, avoid=()):
    """Lanterns on ropes from a high vault, at a seeded irregular spread."""
    for x, z in light.spread(cells, count, spacing, seed, avoid):
        lantern(t, floor, x, z)


def lights(t, floor, cells):
    # 0 Arrival: lanterns over the waystone and the arrival on the receiving terrace,
    # candles in the north wall, lamps by the way out.
    for x, z in ((13, 98), (13, 100), (9, 102), (11, 102), (11, 105), (13, 105), (11, 108), (13, 108)):
        lantern(t, floor, x, z)
    lantern(t, floor, 23, 105, over=7)
    for x in (14, 24):
        niche_candle(t, floor, x, 98, "-z")
    lamp(t, floor, 25, 102, "+x", up=3)
    lamp(t, floor, 23, 117, "+z", up=3)
    lamp(t, floor, 14, 112, "+z", up=3)
    # 1 Bins: lamps in the brick at the mouths and over the bins, lanterns over the pit.
    for x, z, side in ((55, 100, "-x"), (55, 110, "-x"), (61, 110, "+z"), (68, 110, "+z"), (73, 106, "+x"),
                       (62, 97, "-z"), (74, 101, "+x")):
        lamp(t, floor, x, z, side, up=2)
    lanterns(t, floor, cells["bins"], 30, 3.6, 7)
    # 2 Furnace hall: the furnace mouths' coals in the hearth's wall, emberglass in the
    # vault, the lava fall in the south wall (below).
    for z0 in (95, 100, 105):
        for z in range(z0, z0 + 3):
            lamp(t, floor, 115, z, "+x", up=1, node=EMBERS)
    ceiling_lamps(t, floor, cells["furnace"], 40, 3.8, 41, avoid=[(108, 113)])
    for x, z, side in ((100, 100, "-x"), (100, 108, "-x"), (104, 94, "-z"), (113, 94, "-z")):
        lamp(t, floor, x, z, side, up=2)
    # 3 Cooling: emberglass over the racks and in the vault.
    ceiling_lamps(t, floor, cells["cooling"], 40, 3.8, 13)
    for x, z, side in ((99, 13, "-x"), (116, 17, "+x"), (104, 24, "+z"), (112, 24, "+z")):
        lamp(t, floor, x, z, side, up=2)
    # 4 Vestibule: the iron coffer's emberglass, lamps by the die cupboards.
    ceiling_lamps(t, floor, cells["vestibule"], 50, 3.8, 29)
    for x, z, side in ((53, 58, "-x"), (74, 54, "+x"), (74, 66, "+x"), (60, 67, "+z"), (68, 67, "+z")):
        lamp(t, floor, x, z, side, up=2)
    # 5 Press floor: four lanterns round Duewarden, more over the hall, lamps in the
    # columns and the walls.
    ring = ((59, 23), (69, 23), (64, 18), (64, 28), (60, 20))
    for x, z in ring:
        lantern(t, floor, x, z)
    lanterns(t, floor, cells["press"], 30, 4.2, 23, avoid=ring)
    for x, z, side in ((56, 19, "-x"), (71, 19, "+x"), (56, 28, "-x"), (71, 28, "+x"), (53, 25, "-x"),
                       (74, 16, "+x"), (74, 33, "+x"), (58, 34, "+z"), (70, 34, "+z"), (52, 15, "-z"),
                       (75, 15, "-z"), (64, 34, "+z"), (53, 32, "-x"), (53, 15, "-x")):
        lamp(t, floor, x, z, side, up=2)
    # The door: a lamp each side of it in the passage's walls.
    for x in (42, 43, 45, 46):
        lamp(t, floor, x, 19, "-z", up=2)
        lamp(t, floor, x, 20, "+z", up=2)
    # 6 Store: lanterns over the chest and the waystone, candles in the walls.
    for x in (19, 21):
        for z in (22, 24, 14, 16):
            lantern(t, floor, x, z)
    for x, z, side in ((10, 15, "-x"), (10, 27, "-x"), (29, 15, "+x"), (29, 22, "+x"), (20, 10, "-z"),
                       (21, 37, "+z")):
        niche_candle(t, floor, x, z, side)
    for x, z, side in ((12, 10, "-z"), (27, 10, "-z"), (10, 34, "-x"), (29, 30, "+x")):
        lamp(t, floor, x, z, side, up=3)
    # Passages: a lamp at each bend where a light belongs; the dark runs keep theirs at
    # their ends only (the ambush candidates): the north end of the run to the vestibule,
    # its south end, and the lava fall at the end of the run to the furnace hall.
    for x, z, side in ((37, 104, "-z"), (47, 106, "-z"), (107, 89, "-x"), (106, 31, "-x"), (93, 19, "-z"),
                       (66, 43, "+x"), (35, 22, "+z"), (108, 36, "+x"), (88, 21, "-z"), (89, 55, "+z"), (110, 84, "+x")):
        lamp(t, floor, x, z, side, up=2)
    # The lake's landings: a lamp at each end, in the throat's piers.
    for z in (77, 42):
        lamp_at(t, 95, FEET + 2, z)
        lamp_at(t, 120, FEET + 2, z)
    for x in (100, 116):
        lamp_at(t, x, FEET + 2, 80)
        lamp_at(t, x, FEET + 2, 39)


def lamp_at(t, x, y, z):
    if t.get(x, y, z) == "air":
        raise ValueError(f"last_mint: {x},{y},{z} is no wall")
    t.set(x, y, z, LAMP)


# ---- Hazards -----------------------------------------------------------------------------

def falls(t, floor):
    """Three lava falls besides the lake: the end of the first dark run, the furnace hall's
    centrepiece, the east wall of Duewarden's hall."""
    out = []
    out.append(hazards.lava_fall(t, floor, 99, 86, "+x", source=floor[99, 86] + 4,
                                 basin=[(0, 0), (0, -1)], lip=BASALT, rock=BASALT))
    out.append(hazards.lava_fall(t, floor, 108, 114, "+z", source=floor[108, 114] + 5,
                                 basin=[(0, 0), (-1, 0), (1, 0), (0, -1)], lip=IRON, rock=BASALT))
    out.append(hazards.lava_fall(t, floor, 77, 24, "+x", source=floor[77, 24] + 7,
                                 basin=[(0, 0), (0, 1)], lip=STEEL, rock=BASALT))
    return out


AMBUSHES = [
    # a1: the long run south between the cooling room and the vestibule.
    ("a1", "ambush_drift", (86, 37, 90, 39), [((86, 38), "-x"), ((90, 38), "+x")],
     [(SEEP, 84, 37), (SEEP, 84, 39), (SEEP, 92, 38)]),
    # a2: the long run east between the bins and the furnace hall.
    ("a2", "ambush_flue", (80, 84, 82, 88), [((81, 84), "-z"), ((81, 88), "+z")],
     [(SEEP, 80, 82), (SEEP, 82, 82), (SEEP, 81, 90)]),
]


# ---- The template ------------------------------------------------------------------------

def build():
    t = Template("last_mint", (128, 64, 128), ROCK)
    floor, cells, routes, mouths = build_floor()
    # Rooms and passages: air from the floor up.
    for name, own in cells.items():
        carve(t, floor, own, roof_of(name))
    passage_cells = {}
    for key, (p, _, _) in routes.items():
        own = {c for c in p.cells() if c not in set().union(*cells.values())}
        passage_cells[key] = own
        carve(t, floor, own, passage_top(key))
    lake(t)
    press(t, floor)
    # The ambush alcoves join the floor before its nodes are written.
    for group, room, zone, alcoves, markers in AMBUSHES:
        for (x, z), side in alcoves:
            hazards.alcove(t, floor, x, z, side, width=3, depth=2, height=CLEAR + 1, floor=COBBLE,
                           mob=(1, 1.7))
    traps = [c for _, spots in FLOOR_TRAPS for c in spots]
    stair = {}
    material = {}
    for name, own in cells.items():
        for c in own:
            stair[c], material[c] = STAIR[name], FLOOR[name]
    # Moss in the passages away from the heat (concept section 4.7), in patches.
    damp_cells = set().union(*(passage_cells[k] for k in DAMP))
    damp = dressing.clusters(damp_cells, count=7, radius=4.5, seed=31)
    moss = dressing.mossy(damp, seed=37)

    def wet(x, z):
        return (x, z) in damp_cells and moss(x, z)
    relief.write(t, floor, lambda x, z: "mossycobble" if wet(x, z) else stair.get((x, z), "cobble"),
                 floor=lambda x, z: MOSSY if wet(x, z) else runner(x, z) or material.get((x, z), COBBLE), flat=traps)
    for name, own in cells.items():
        dress(t, floor, own, roof_of(name), ceiling_of(name), facing_of(name))
    for key, own in passage_cells.items():
        dress(t, floor, own, passage_top(key), lambda x, z: BRICK if (x + z) % 5 else IRON,
              lambda x, y, z: BRICK if y % 3 else BLOCK)
    dressing.walls(t, {c: floor[c] for c in damp_cells}, MOSSY, damp, seed=41, rows=4, replace=(ROCK, BRICK, BLOCK))
    furnishings(t, floor)
    ore(t, floor, ORE, *ROUTE_ORE)
    ore(t, floor, GEM, *ROUTE_GEM)
    for x, z in STORE_ORE:
        ore(t, floor, ORE, x, z)
    for x, z in STORE_GEM:
        ore(t, floor, GEM, x, z)
    falls(t, floor)
    for group, room, zone, alcoves, markers in AMBUSHES:
        hazards.ambush(t, floor, "ambush", 1, room, zone, markers)
    lights(t, floor, cells)
    places(t, floor)
    for group, spots in FLOOR_TRAPS:
        for x, z in spots:
            t.trap_floor(group, 2, x, flat_at(floor, x, z), z)
    for group, x, z, axis, offset in WALLS:
        t.trap_wall(group, 1, x, SHOT_Y, z, axis, SHOT_PERIOD, offset)
    for room, mob, tier, spots in PACKS:
        for x, z in spots:
            t.encounter(room, mob, 1, tier, x, flat_at(floor, x, z), z)
    t.encounter("boss", BOSS, 1, "boss", BOSS_AT[0], flat_at(floor, *BOSS_AT), BOSS_AT[1])
    for room, mob, x, z in CRITTERS:
        t.encounter(room, mob, 1, "critter", x, floor[x, z], z)
    litter(t, floor, cells, routes, damp_cells, damp, traps)
    for row in PARTICLES:
        t.particles(*row)
    t.dig(ORE)
    t.dig(GEM)
    build.floor, build.mouths = floor, mouths
    return t


# Dressing and particles ----------------------------------------------------------------

DAMP = ("p01", "p34", "p45", "p56")
# Embers at the lava, sparks at the furnace mouths and the press, dust in the still vaults
# (style, box corners, the most live particles): 200 in all.
PARTICLES = [
    ("ember", 98, 32, 84, 100, 36, 87, 20),
    ("ember", 106, 31, 112, 110, 37, 115, 25),
    ("ember", 76, 31, 23, 78, 39, 26, 25),
    ("ember", 100, 8, 46, 116, 14, 74, 60),
    ("spark", 112, 32, 95, 114, 34, 107, 20),
    ("spark", 59, 32, 12, 68, 35, 13, 15),
    ("dust", 10, 35, 98, 28, 40, 118, 20),
    ("dust", 10, 34, 10, 30, 38, 36, 15),
]


def runner(x, z):
    """Iron runners let into the floors of the bins and the vestibule, steel ties in the
    press floor: flat floor cells only (relief.write puts stairs where it steps)."""
    if 52 <= x <= 76 and 95 <= z <= 112 and x in (57, 59, 69, 71) and not 99 <= z <= 109:
        return IRON
    if 50 <= x <= 77 and 49 <= z <= 70 and z in (54, 65) and 58 <= x <= 72:
        return IRON
    if 50 <= x <= 77 and 12 <= z <= 37 and x in (61, 66) and z <= 15:
        return STEEL
    return None


def panel(t, floor, x, z, side, width, rows, node):
    """A band of `node` set into the wall the cell faces, `width` cells along it centred
    on the meeting point, at `rows` over its feet; only where the wall stands."""
    (fx, fz), (wx, wz) = at_wall(floor, x, z, side)
    ax, az = (0, 1) if side in ("+x", "-x") else (1, 0)
    h = floor[fx, fz]
    for i in range(width):
        cx, cz = wx + ax * (i - width // 2), wz + az * (i - width // 2)
        if (cx, cz) in floor:
            continue
        for dy in rows:
            if registry.walkable(t.get(cx, h + dy, cz)) and t.get(cx, h + dy, cz) not in (LAMP, EMBERS, ORE, GEM):
                t.set(cx, h + dy, cz, node)


def furnishings(t, floor):
    """What the workshops kept on their walls: the bins' iron mouths, the cooling racks'
    bands, the vestibule's die cupboards, the arrival's sealed side arch."""
    for x in (60, 66, 72):
        panel(t, floor, x, 106, "+z", 3, range(3, 7), IRON)
    for x in (100, 108, 116):
        panel(t, floor, x, 14, "-z", 5, (3, 5), IRON)
    for z in (54, 64):
        panel(t, floor, 60, z, "-x", 3, range(3, 5), STEEL)
        panel(t, floor, 70, z, "+x", 2, range(3, 5), STEEL)
    panel(t, floor, 14, 106, "-x", 7, range(0, 7), IRON)


def litter(t, floor, cells, routes, damp_cells, damp, traps):
    """Moss and lichen on the damp passages' floors, bones in the niches, ember-stars by
    the furnace hearth, cobwebs high in the old vaults; nothing on a trap, an ambush's
    zone or alcove, a waystone or the chest."""
    keep = set(traps)
    for group, room, zone, alcoves, markers in AMBUSHES:
        x0, z0, x1, z1 = zone
        keep |= {(x, z) for x in range(x0 - 3, x1 + 4) for z in range(z0 - 3, z1 + 4)}
    for name in ("arrival", "start_waystone", "end_waystone", "chest"):
        x, _, z = t.places[name]
        keep.add((x, z))
    dressing.scatter(t, floor, [MOSS, MOSS, LICHEN, LICHEN_B], damp, seed=43, avoid=keep,
                     cells=[c for c in damp_cells if c in floor])
    niches = [c for key in ("p01", "p34", "p56") for _, own in routes[key][0].niches for c in own]
    dressing.scatter(t, floor, [BONES, SHARDS, SKULL], lambda x, z: 0.6, seed=47, avoid=keep,
                     cells=[c for c in niches if c in floor])
    sorting = dressing.clusters(cells["bins"], count=3, radius=3, seed=53, strength=0.5)
    dressing.scatter(t, floor, [SHARDS], sorting, seed=59, avoid=keep, cells=[c for c in cells["bins"] if c in floor])
    hearth = dressing.clusters([c for c in cells["furnace"] if c[0] >= 112], count=2, radius=3, seed=61,
                               strength=0.6)
    dressing.scatter(t, floor, [EMBER_STAR], hearth, seed=67, avoid=keep, cells=[c for c in cells["furnace"] if c in floor])
    for name in ("arrival", "bins", "store"):
        webs = dressing.clusters(cells[name], count=3, radius=4, seed=len(name) * 7, strength=0.45)
        dressing.hang(t, floor, COBWEB, webs, seed=71, clear=CLEAR + 1, cells=[c for c in cells[name] if c in floor])


def places(t, floor):
    t.set(10, flat_at(floor, 10, 101), 101, WAYSTONE)
    t.place("start_waystone", 10, floor[10, 101], 101)
    t.place("arrival", 12, flat_at(floor, 12, 106), 106)
    t.set(20, flat_at(floor, 20, 23), 23, CHEST, FACE_EAST)
    t.place("chest", 20, floor[20, 23], 23)
    t.set(20, flat_at(floor, 20, 15), 15, WAYSTONE)
    t.place("end_waystone", 20, floor[20, 15], 15)
    t.box(44, FEET, 16, 44, PASS_TOP, 23, DOOR)
    t.place("door", 44, FEET + 2, 19)
