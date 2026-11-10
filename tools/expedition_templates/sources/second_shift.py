"""The Second Shift, the level 40-69 Expedition for four players (Round 72 lane SHIFT, its
build plan docs/planning/round72-second-shift.md; Round 73 lane SHIFT, the redesign of
docs/planning/round73-expedition-redesign-concept.md section 5): a working mine still
keeping its books, order gone sour. tools/r72_shift/portable_test.lua proves the written
file on the shared proof (tools/expedition_templates/proofs.lua) with every rule on.

The route, the packs, the boss, the ore and gem places, the door, the chest, the
waystones, the Round 72 traps and the shift board stay (concept section 3). Round 73
reshapes the rest:

- the floor is a height map with stairs (relief.py): the arrival's raised bench, the
  timekeeper's square office with its sunken cart siding, the marking floor's terraces
  stepping down west, the wage hall stepping down south to bay d's sunken pay floor, the
  audit court's sunken floor round Nemm under the auditors' gallery; the store stays
  flat and square on purpose;
- the passages bend, change width and height and have niches (passages.py); the two
  drifts after the marking floor and after the wage hall are long and straight on
  purpose: each holds an ambush candidate (hazards.py), dark, the next light in sight;
- light comes from desks, pay tables, coffers, lamp niches, doors and two lava falls;
  lights hang at the feet plus four (Nemm, 2.8 nodes tall, plus one), sit on the walls
  there, or stand in a wall cell (fill_lights: where the floor is still dark, never on a
  grid);
- moss in the old drifts, cobwebs on the office side, bones where miners fell; critters
  in the side niches; paper over the desks, ash at the lava, dust in the old drifts.
"""
import math

import dressing
import hazards
import light
import passages
import registry
import relief
from template import Template

ROCK = "default:stone"
COBBLE, GRAVEL, MOSSY = "default:cobble", "default:gravel", "default:mossycobble"
BRICK, BLOCK = "default:stonebrick", "default:stone_block"
FEET = 8
CLEAR = 4  # the tallest mob (Nemm, 1.98 x 1.4) plus one: air rows over every walking cell

POST, BEAM, PLANK = "default:tree", "default:pine_wood", "default:wood"
BOARD = "grug_decor:darkage_reinforced_wood"
SHELF = "default:bookshelf"
TORCH, LANTERN, CANDLE = light.TORCH, light.LANTERN, light.CANDLE
STAND_LAMP = "grug_decor:xdecor_lantern"
RAIL, CART = "grug_mapgen:mine_rail", "grug_mapgen:mine_cart"
TABLE, BENCH = "grug_decor:cottages_table", "grug_decor:cottages_bench"
BARREL = "grug_decor:cottages_barrel"
SIGN = "default:sign_wall_wood"
COBWEB = "grug_decor:xdecor_cobweb"
MOSS, LICHEN, LICHEN_B = "grug_nodes:moss_carpet", "grug_nodes:lichen_carpet", "grug_nodes:lichen_carpet_b"
BONES, SKULL = "grug_nodes:bones_fragments", "grug_nodes:skull_human"
# The template's ore and gem places hold the T2 nodes, the markers a run of another
# tier writes its own in (catalogue.lua TEMPLATE_ORE, TEMPLATE_GEM): never anywhere
# else in this template.
ORE, GEM = "grug_materials:stone_with_anthracite", "grug_materials:stone_with_jade"
DOOR, CHEST = "grug_expeditions:reward_door", "grug_expeditions:reward_chest"
WAYSTONE = "grug_expeditions:waystone"
RAIDER, MINER, BOSS = "grug_mobs:skeleton_raider", "grug_mobs:zombie", "grug_mobs:auditor_nemm"
BAT, CRAWLER, WEEVIL = "grug_mobs:cave_bat", "grug_mobs:cave_crawler", "grug_mobs:bone_weevil"
NORTH = 5  # wallmounted param2 of the shift board on its north wall
FACE_WEST = 1  # the chest's front looks at the door (facedir: towards -x)

# Floor rectangles x0, z0, x1, z1, upper bounds excluded. A room is the union of its
# rectangles; the Round 72 envelope (the fixture's ENVELOPES) holds each.
ROOMS = {
    # 0 Arrival, envelope (96, 8, 120, 32)
    "arrival": ((100, 9, 112, 12), (96, 12, 112, 16), (96, 16, 120, 28), (96, 28, 116, 32)),
    # 1 Timekeeper's office, envelope (48, 8, 80, 40): pack a. Square on purpose; the
    # desk niche north, the sunken cart siding south, the ore bay west.
    "desk": ((56, 10, 72, 12), (50, 12, 78, 36), (52, 36, 70, 39), (49, 30, 50, 37), (50, 36, 52, 37), (78, 16, 80, 24)),
    # 2 Marking floor, envelope (8, 8, 32, 40): pack b, terraces stepping down west
    "marking": ((12, 9, 24, 12), (9, 12, 30, 16), (9, 16, 32, 24), (9, 24, 30, 32), (9, 32, 31, 40)),
    # 3 Wage hall, envelope (8, 64, 32, 120): packs c and d, the screen between them
    "wage": ((12, 64, 31, 68), (9, 68, 31, 84), (12, 84, 32, 88), (24, 88, 32, 96),
             (9, 96, 32, 112), (9, 112, 31, 113), (12, 113, 30, 116), (14, 116, 24, 118)),
    # 4 Audit court, envelope (48, 88, 80, 120): Auditor Nemm
    "court": ((56, 88, 62, 89), (56, 89, 72, 92), (52, 92, 76, 96), (48, 96, 80, 112),
              (52, 112, 76, 116), (56, 116, 72, 118), (57, 118, 70, 119)),
    # 5 Store, envelope (96, 88, 120, 120): flat and square on purpose
    "store": ((96, 88, 112, 92), (96, 92, 120, 116), (96, 116, 120, 120)),
}
# The Round 72 envelopes of the pack rooms: their floor is fighting floor.
ENVELOPES = {"desk": (48, 8, 80, 40), "marking": (8, 8, 32, 40), "wage": (8, 64, 32, 120),
             "court": (48, 88, 80, 120)}
# The full-height rock screen between packs c and d; the hall's bypass runs east of it.
SCREEN = (8, 88, 24, 96)
# Nemm's range (BOSSRESET): the court's envelope, two opposite corners.
COURT_ENVELOPE = (48, 88, 80, 120)
# The ambush candidates (group a1, pick 1 of 2): zone x0, z0, x1, z1 (both included).
AMBUSH_GRAIN = (25, 50, 30, 52)  # the grain drift, from the marking floor to the wage hall
AMBUSH_PAY = (36, 92, 41, 94)    # the pay drift, from the wage hall towards the court
USUAL_SPARE = 0.2  # the fighting floor below light 6 at most (the proof allows 25 %, the user 2026-11-10)
AMBUSH_MINERS = 3                # Buried Miners per ambush (tools/r72_shift/balance.py)
TRAPS_FLOOR = {"f1": (2, ((27, 20), (11, 20), (27, 32), (11, 32))), "f5": (1, ((27, 76), (11, 80))),
               "f7": (1, ((27, 104), (11, 112))), "f9": (2, ((71, 96), (55, 96), (71, 112), (55, 112)))}
ORES = ((ORE, 48, 36), (GEM, 8, 36), (ORE, 119, 96), (ORE, 96, 92), (ORE, 96, 100), (ORE, 119, 116),
        (GEM, 119, 108), (GEM, 96, 116))


def rect_cells(rects):
    return {(x, z) for x0, z0, x1, z1 in rects for z in range(z0, z1) for x in range(x0, x1)}


def wave(t, *parts):
    """A smooth irregular offset: a sum of (amplitude, period, phase) sines."""
    return sum(a * math.sin(t / p + ph) for a, p, ph in parts)


def near(cells, points, r):
    return [c for c in cells if any(max(abs(c[0] - x), abs(c[1] - z)) <= r for x, z in points)]


# ---- The floor -----------------------------------------------------------------------

def passage_cells():
    """{name: (cells, heights, tops)}: the passages' own cells (outside the rooms)."""
    out = {}
    # P01 arrival -> office: a bent cut with a hump over an old fall and a niche.
    p = passages.Passage([(98, 19.5), (92, 18), (86.5, 21.5), (77.5, 19.5)],
                         width=lambda s: 6 + 2 * (0.42 < s < 0.62))
    p.niche(0.3, side=-1, depth=2, width=3)
    heights = p.heights(FEET, profile=[(0, 0), (0.3, 0), (0.4, 1), (0.64, 1), (0.74, 0), (1, 0)])
    out["p01"] = (heights, lambda x, z, h: h + 4 + (85 <= x <= 92))
    # P12 office -> marking floor: the wall trap's gallery, straight where the fireball
    # flies (x 35 and 43, z 16 to 23), a pay window niche north and a widening south.
    cells = rect_cells(((32, 16, 50, 24), (38, 13, 41, 16), (44, 24, 48, 26)))
    out["p12"] = ({c: FEET for c in cells}, lambda x, z, h: h + 5)
    # P23 marking floor -> wage hall: the grain drift, straight and dark, dipping a node
    # over its middle; the first ambush candidate.
    cells = rect_cells(((25, 40, 31, 64), (24, 42, 25, 45)))
    out["p23"] = ({(x, z): FEET - (46 <= z <= 57) for x, z in cells},
                  lambda x, z, h: h + 4 + (z < 46 or z > 57))
    # P34 wage hall -> court: a stub east, the pay drift north (the second candidate),
    # then east under a low roof, rising a node, and south into the court.
    cells = rect_cells(((32, 103, 42, 109), (36, 78, 42, 103), (36, 76, 62, 82), (56, 82, 62, 88),
                        (47, 82, 50, 84)))
    out["p34"] = ({(x, z): FEET - 1 + (x >= 47 and z <= 81 or z >= 82 and x >= 56) for x, z in cells},
                  lambda x, z, h: h + (3 if 44 <= x <= 52 and z <= 81 else 4))
    # P45 court -> store: the door's cut, then a jog into the store.
    cells = rect_cells(((80, 104, 88, 112), (88, 102, 96, 110)))
    out["p45"] = ({c: FEET for c in cells}, lambda x, z, h: 13 if x <= 86 else h + 5)
    return out


def room_heights(name, cells):
    if name == "arrival":
        keep = [(x, z) for x, z in cells if abs(x - 107) <= 3 and 21 <= z <= 31] + \
            [(96, z) for z in range(16, 24)]
        return relief.vary(cells, FEET, [relief.rise(117, 20, 5, height=1, gentle=200, seed=3),
                                         relief.rise(99, 30, 3, height=1, gentle=False, seed=8)],
                           keep=keep, keep_radius=1)
    if name == "desk":
        return {(x, z): FEET - (52 <= x <= 69 and z >= 36) for x, z in cells}
    if name == "marking":
        def h(x, z):
            e1 = 22.5 + wave(z, (1.1, 3.4, 1.0), (0.6, 2.1, 2.3))
            e2 = 15.5 + wave(z, (1.0, 3.9, 0.3), (0.6, 2.3, 1.7))
            return FEET if x >= e1 else FEET - 1 if x >= e2 else FEET - 2
        traps = TRAPS_FLOOR["f1"][1]
        return relief.repair({(x, z): h(x, z) for x, z in cells}, FEET, frozen=near(cells, traps, 2))
    if name == "wage":
        bay_d = {(x, z) for x, z in cells if z >= 96}
        out = {}
        for x, z in cells:
            if z < 96:
                out[x, z] = FEET if z < 72.5 + wave(x, (1.4, 2.0, 0.4)) else FEET - 1
        keep = [(27, 104), (11, 112)] + [(31, z) for z in range(103, 109)] + [(x, 96) for x in range(24, 32)]
        out.update(relief.vary(bay_d, FEET - 1, [relief.pit(16, 104, 5, depth=2, gentle=250, seed=11)],
                               keep=keep, keep_radius=2))
        return out
    if name == "court":
        keep = [p for _, (_, spots) in TRAPS_FLOOR.items() for p in spots if 48 <= p[0] < 80 and p[1] >= 88]
        keep += [(x, 88) for x in range(56, 62)] + [(79, z) for z in range(104, 112)]
        return relief.vary(cells, FEET, [relief.pit(63, 104, 6.5, depth=1, gentle=0, seed=5),
                                         relief.rise(63, 122, 9, height=1, gentle=False, seed=2),
                                         relief.rise(49, 104, 4, height=2, gentle=180, seed=9)],
                           keep=keep, keep_radius=2)
    return relief.flat(cells, FEET)


class Layout:
    """The floor of the whole Expedition: heights, tops (the last air row) and which part
    each column belongs to."""

    def __init__(self):
        self.part, self.floor, self.top = {}, {}, {}
        rooms = {}
        for name, rects in ROOMS.items():
            cells = rect_cells(rects)
            if name == "wage":
                cells -= rect_cells((SCREEN,))
            rooms[name] = cells
        taken = set().union(*rooms.values())
        for name, cells in rooms.items():
            for cell, h in room_heights(name, cells).items():
                self.floor[cell] = h
                self.part[cell] = name
        for name, (heights, top) in passage_cells().items():
            for (x, z), h in heights.items():
                if (x, z) not in taken:
                    self.floor[x, z] = h
                    self.part[x, z] = name
                    self.top[x, z] = top(x, z, h)
        for (x, z), h in self.floor.items():
            if (x, z) not in self.top:
                self.top[x, z] = max(h + CLEAR, ROOF[self.part[x, z]](x, z))

    def cells(self, *parts):
        return {c for c, p in self.part.items() if p in parts and c in self.floor}


# Room roofs: the first air row from the top, irregular in y (Round 72's rule stays).
ROOF = {
    "arrival": lambda x, z: 13 + min(3, max(0, (x - 96) // 4)) - (z >= 28),
    "desk": lambda x, z: 14 + min(4, max(0, (z - 10) // 4)),
    "marking": lambda x, z: 12 + min(5, max(0, (x - 9) // 4)) + (wave(z, (1, 3, 0)) > 0.4),
    "wage": lambda x, z: (13 + min(3, (x - 9) // 6) if z < 88 else 13 + max(0, 4 - abs(x - 21) // 3)),
    "court": lambda x, z: 22 - max(abs(x - 63) // 3, abs(z - 104) // 3),
    "store": lambda x, z: 15,
}


# ---- Building --------------------------------------------------------------------------

def floor_node(lay):
    def node(x, z):
        part = lay.part[x, z]
        r = dressing.roll(31, x, z)
        if part == "desk":
            return PLANK
        if part == "store":
            return PLANK
        if part == "court":
            return BRICK if r < 0.8 else BLOCK
        if part == "wage":
            return BLOCK if r < 0.55 else BRICK if r < 0.85 else COBBLE
        if part in ("p23", "p34") and r < 0.3:
            return MOSSY
        return ROCK if r < 0.5 else COBBLE if r < 0.8 else GRAVEL
    return node


def stair_material(lay):
    def material(x, z):
        part = lay.part[x, z]
        if part == "desk":
            return "wood"
        if part in ("court", "wage"):
            return "stonebrick"
        if part in ("p23", "p34") and dressing.roll(32, x, z) < 0.4:
            return "mossycobble"
        return "cobble"
    return material


def walls(t, lay):
    """The rock facing the floor: timber posts, cobble strata, plank wainscot in the office,
    brick in the court and the wage hall; chosen per column by a seeded roll."""
    for (x, z), h in sorted(lay.floor.items()):
        part = lay.part[x, z]
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = x + dx, z + dz
            if (nx, nz) in lay.floor or not (0 < nx < t.sx - 1 and 0 < nz < t.sz - 1):
                continue
            r = dressing.roll(17, nx, nz)
            for y in range(h, lay.top[x, z] + 2):
                if t.get(nx, y, nz) != ROCK:
                    continue
                if part in ("court", "wage") and y < h + 3:
                    node = BRICK if dressing.roll(18, nx, nz, y) < 0.85 else BLOCK
                elif part == "desk" and y < h + 3:
                    node = PLANK
                elif r < 0.09 and part not in ("p23", "p34"):
                    node = POST
                elif dressing.roll(19, nx, nz, y // 2) < 0.18:
                    node = COBBLE
                elif part in ("p23", "p34") and dressing.roll(20, nx, nz, y) < 0.12:
                    node = MOSSY
                else:
                    continue
                t.set(nx, y, nz, node)


def roofs(t, lay):
    """Timber ribs under the rooms' roofs, along authored lines."""
    ribs = {"desk": lambda x, z: z in (15, 22, 29) or x in (56, 71),
            "marking": lambda x, z: z in (14, 22, 30),
            "wage": lambda x, z: z in (74, 102),
            "court": lambda x, z: x in (56, 63, 71) or z == 104,
            "arrival": lambda x, z: x in (100, 106, 111),
            "store": lambda x, z: z in (95, 103, 111) or x in (101, 113)}
    for (x, z), part in lay.part.items():
        rib = ribs.get(part)
        y = lay.top[x, z] + 1
        if rib and rib(x, z) and y < t.sy - 1:
            t.set(x, y, z, BEAM)


def prop(t, lay, x, z, node, param2=0, hood=BOARD, on=None):
    """Furniture on a floor cell, its column off the floor: a hood two over its feet keeps
    anyone from standing on it (no perch); `on` sits on top of it (a candle, a lamp)."""
    h = lay.floor.pop((x, z))
    lay.part.pop((x, z))
    top = lay.top.pop((x, z))
    t.set(x, h - 1, z, ROCK)
    t.set(x, h, z, node, param2)
    t.set(x, h + 1, z, on or "air")
    # A shelf stands up to the roof; a board hangs alone, the air over it open.
    t.box(x, h + 2, z, x, top, z, hood if hood == SHELF else "air")
    t.set(x, h + 2, z, hood)
    return h, top


def solid_column(t, lay, x, z):
    """Takes a floor column back into the rock (an ore's place, a post)."""
    h = lay.floor.pop((x, z))
    lay.part.pop((x, z))
    lay.top.pop((x, z))
    return h


def ore(t, lay, node, x, z):
    """A marked node at reach on a plinth of rock, the hull behind it: its height is the
    floor's beside it."""
    if (x, z) in lay.floor:
        h = solid_column(t, lay, x, z)
    else:
        h = min(lay.floor[x + dx, z + dz] for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if (x + dx, z + dz) in lay.floor)
    t.set(x, h, z, ROCK)
    t.set(x, h + 1, z, node)
    # Mining leaves no body-sized space over the rock foot, and the rock behind stays.
    t.box(x, h + 2, z, x, h + 12, z, ROCK)
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        if (x + dx, z + dz) not in lay.floor and 0 < x + dx < t.sx - 1 and 0 < z + dz < t.sz - 1:
            t.set(x + dx, h + 1, z + dz, ROCK)


def furnish(t, lay):
    """Everything that takes a floor column: furniture, the ore columns. Before the
    floor's stairs are written, so no stair sees a column that is not floor."""
    # 0 Arrival: the boarded collapse north, hooded benches and barrels.
    for x in (98, 99, 100, 101):
        prop(t, lay, x, 31, BENCH, 0)
    for z in (18, 19, 20):
        prop(t, lay, 119, z, BENCH, 3)
    for x, z in ((96, 12), (97, 12), (96, 13), (119, 27), (115, 31)):
        prop(t, lay, x, z, BARREL)
    # 1 The office: the timekeeper's desk in its niche under the shelves, two rows of
    # clerks' desks, candles on some; the cart at the siding's end.
    for x in range(61, 67):
        prop(t, lay, x, 10, TABLE, 0, hood=SHELF, on=CANDLE if x in (61, 66) else None)
    for x0, z in ((54, 24), (66, 24), (66, 31)):
        for x in range(x0, x0 + 4):
            prop(t, lay, x, z, TABLE, 0, hood=BOARD, on=CANDLE if (x - x0) in (0, 2) else None)
    prop(t, lay, 53, 37, CART, 1)
    # 2 The marking floor: tally benches on the terraces' edges.
    for z in range(13, 16):
        prop(t, lay, 9, z, BENCH, 1)
    for x in (16, 17, 18):
        prop(t, lay, x, 38, BENCH, 0)
    # 3 The wage hall: the pay tables, lit, and the benches of those who waited.
    for z in range(70, 75):
        prop(t, lay, 9, z, BENCH, 1)
    for z in (69, 70, 71, 79, 80, 81):
        prop(t, lay, 30, z, TABLE, 0, on=STAND_LAMP if z in (70, 80) else None)
    for z in range(99, 104):
        prop(t, lay, 9, z, BENCH, 1)
    for x, z in ((12, 64), (13, 64), (27, 64), (29, 112), (12, 113)):
        prop(t, lay, x, z, BARREL)
    for x in (18, 19, 20):
        prop(t, lay, x, 117, TABLE, 0, on=STAND_LAMP if x == 19 else None)
    # 5 The store: coffers along the walls.
    for x, z in ((108, 88), (109, 88), (108, 89), (118, 119), (117, 119), (119, 92)):
        prop(t, lay, x, z, BARREL, on=STAND_LAMP if (x, z) in ((109, 88), (117, 119)) else None)
    for node, x, z in ORES:
        if (x, z) in lay.floor:
            solid_column(t, lay, x, z)


def build_floor(t, lay):
    traps = [p for _, spots in TRAPS_FLOOR.values() for p in spots]
    relief.check(lay.floor, flat=traps)
    relief.carve(t, lay.floor, lambda x, z: lay.top[x, z])
    relief.write(t, lay.floor, stair_material(lay), floor=floor_node(lay), flat=traps)


def places(t, lay):
    t.set(107, FEET, 28, WAYSTONE)
    t.place("start_waystone", 107, FEET, 28)
    t.place("arrival", 107, FEET, 24)
    t.set(107, FEET, 104, CHEST, FACE_WEST)
    t.place("chest", 107, FEET, 104)
    t.set(107, FEET, 112, WAYSTONE)
    t.place("end_waystone", 107, FEET, 112)
    for cell in ((107, 28), (107, 104), (107, 112)):
        lay.floor.pop(cell)
        lay.part.pop(cell)
    # The shift board on the timekeeper's desk.
    t.set(63, FEET + 1, 10, BOARD)
    t.set(63, FEET + 2, 10, SIGN, NORTH)
    t.place("shift_board", 63, FEET + 2, 10)
    t.set(63, FEET + 3, 10, SHELF)
    # The door fills the cut between the court and the store.
    t.box(83, FEET, 104, 83, 13, 111, DOOR)
    t.place("door", 83, FEET + 2, 108)
    for z in range(104, 112):
        lay.floor.pop((83, z))
        lay.part.pop((83, z))
    x0, z0, x1, z1 = COURT_ENVELOPE
    t.place("boss_room_min", x0, FEET, z0)
    t.place("boss_room_max", x1 - 1, FEET, z1 - 1)
    for node, x, z in ORES:
        ore(t, lay, node, x, z)
    t.dig(ORE)
    t.dig(GEM)
    # The arrival's boarded collapse; the store's coffers are reinforced.
    t.box(100, FEET, 8, 111, FEET + 4, 8, BOARD)
    for x in (100, 111):
        t.box(x, FEET, 8, x, FEET + 4, 8, POST)
    # The siding's rails, along the office's south side to the crushed end.
    for x in range(54, 70):
        t.set(x, FEET - 1, 37, RAIL, 1)


def lava(t, lay):
    """Two falls: the marking floor's west wall and the court's north wall, beside the
    fighting floor (the user, 2026-11-10), never at a mouth, a stair's foot or in the dark."""
    falls = ((9, 26, "-x", [(0, 0), (0, -1), (0, 1)]), (66, 89, "-z", [(0, 0), (-1, 0), (1, 0), (0, 1)]))
    for x, z, wall, basin in falls:
        h = lay.floor[x, z]
        hazards.lava_fall(t, lay.floor, x, z, wall, source=h + 5, basin=basin)
    return falls


def ambushes(t, lay):
    """Two candidates of one group, one armed per run: Buried Miners (melee) in alcoves
    beside a dark zone across a straight drift."""
    rows = []
    for room, zone in (("grain_drift", AMBUSH_GRAIN), ("pay_drift", AMBUSH_PAY)):
        x0, z0, x1, z1 = zone
        zm = (z0 + z1) // 2
        west = hazards.alcove(t, lay.floor, x0, zm, "-x", width=3, depth=2, height=CLEAR, mob=(1, 1.9))
        east = hazards.alcove(t, lay.floor, x1, zm, "+x", width=3, depth=2, height=CLEAR, mob=(1, 1.9))
        for cell in west + east:
            lay.part[cell] = "alcove"
            lay.top[cell] = lay.floor[cell] + CLEAR - 1
        markers = [(MINER, x0 - 2, zm), (MINER, x1 + 2, zm - 1), (MINER, x1 + 2, zm + 1)][:AMBUSH_MINERS]
        hazards.ambush(t, lay.floor, "a1", 1, room, zone, markers)
        rows.append((zone, west + east))
    return rows


def dark_cells(lay, rows):
    """The eye cells an ambush needs at light 0: its zone with two nodes round it, its alcoves."""
    out = set()
    for (x0, z0, x1, z1), alcoves in rows:
        for z in range(z0 - 2, z1 + 3):
            for x in range(x0 - 2, x1 + 3):
                if (x, z) in lay.floor:
                    out.add((x, lay.floor[x, z] + 1, z))
        for x, z in alcoves:
            out.add((x, lay.floor[x, z] + 1, z))
    return out


def authored_lights(t, lay):
    """Light where something is, in groups with darker floor between: the waystone's lamp
    and the collapse's torches; the trap gallery's torches at its muzzles; lamp niches by
    the office's siding and the timekeeper's desk, by the marking floor's tally wall and
    the wage hall's benches; the pay drift's lamp at its far end; the door's torches. The
    desks' candles and the tables' lamps stand with the furniture (furnish); the lava
    falls light their walls. The passages between the rooms stay dim."""
    def lamp(x, z):
        light.lantern(t, x, z, lay.floor[x, z] + CLEAR, lay.top[x, z])

    def torch(x, z, wall):
        light.torch(t, x, lay.floor[x, z] + CLEAR, z, wall)
    # Arrival: over the waystone, by the collapse, at the way out.
    lamp(107, 26)
    torch(104, 9, "-z")
    torch(108, 9, "-z")
    torch(96, 25, "-x")
    # P12, the wall trap's gallery: a torch pair at each muzzle station, the pay window.
    for x in (35, 43):
        torch(x, 16, "-z")
        torch(x, 23, "+z")
    lamp(39, 14)
    # Lamp niches where people worked: the timekeeper's desk, the siding's buffer, the
    # marking floor's tally wall and the bays' benches.
    for x, z in ((57, 11), (70, 11), (55, 38), (61, 38), (67, 38), (9, 17), (9, 21), (9, 33), (9, 37),
                 (10, 69), (10, 77), (10, 98), (10, 106), (9, 110)):
        wall_lamp(t, lay, x, z)
    # The store's mineral faces and the arrival's far corners: a lamp by each, the floor
    # between them dim.
    for x, z in ((119, 94), (96, 95), (96, 113), (119, 111), (119, 24), (97, 30)):
        wall_lamp(t, lay, x, z)
    # The grain drift: none inside; the lamps of the rooms at its ends are in sight.
    # The pay drift: one lamp at its north bend, in sight down the drift.
    lamp(38, 79)
    lamp(58, 79)
    wall_lamp(t, lay, 49, 83)
    torch(56, 86, "-x")
    # P45: the door's torches on both sides.
    for x in (81, 85):
        torch(x, 104, "-z")
        torch(x, 111, "+z")
    lamp(81, 108)
    lamp(86, 108)


def fill_lights(t, lay, targets, kind, avoid, seed):
    """Light the darkest target cells until each holds its level, chosen by darkness,
    never on a grid; never within reach of the cells that must stay dark. Returns the
    cells left short."""
    order = {c: dressing.roll(seed, *c) for c in targets}
    for _ in range(400):
        levels = light.levels(t)
        short = sorted(((levels[light.index(t, x, lay.floor[x, z] + 1, z)], order[x, z], x, z)
                        for (x, z), need in targets.items()
                        if (x, z) in lay.floor and levels[light.index(t, x, lay.floor[x, z] + 1, z)] < need))
        if not short:
            return []
        placed = []
        for _, _, x, z in short:
            if any(max(abs(x - px), abs(z - pz)) < 13 for px, pz in placed):
                continue
            k, clear = kind(x, z)
            spot = place_light(t, lay, x, z, k, avoid, clear)
            if spot:
                placed.append((x, z))
        if not placed:
            return [(x, z) for _, _, x, z in short]
    return ["..."]


def wall_lamp(t, lay, x, z):
    """A lamp in a wall cell beside the floor cell x, z, at its eye height: a lamp niche.
    Not over a walking cell, so it needs no head room. Returns the undo list or None."""
    h = lay.floor[x, z]
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        wx, wz = x + dx, z + dz
        if (wx, wz) in lay.floor or (wx, wz) in lay.part or not (1 < wx < t.sx - 2 and 1 < wz < t.sz - 2):
            continue
        if t.get(wx, h + 1, wz) in (ROCK, COBBLE, BRICK, BLOCK, PLANK) and t.get(wx, h + 2, wz) != "air" \
                and t.get(wx, h, wz) != "air":
            undo = [(wx, h + 1, wz, t.get(wx, h + 1, wz))]
            t.set(wx, h + 1, wz, STAND_LAMP)
            return undo
    return None


def keep_clear():
    """Floor cells no post may take: the markers and their spread cells, the critters, the
    traps and their rings, the places and the passages' mouths round the rooms."""
    out = set()
    for _, _, _, x, z, _ in PACKS:
        for dx, dz in ((0, 0), (3, 0), (-3, 0), (0, 3), (0, -3)):
            out |= {(x + dx + ex, z + dz + ez) for ex in (-1, 0, 1) for ez in (-1, 0, 1)}
    for _, _, x, z in CRITTERS:
        out |= {(x + ex, z + ez) for ex in (-1, 0, 1) for ez in (-1, 0, 1)}
    for _, spots in TRAPS_FLOOR.values():
        for x, z in spots:
            out |= {(x + ex, z + ez) for ex in range(-3, 4) for ez in range(-3, 4)}
    return out


VIEW = {RAIDER: 16, MINER: 14, BOSS: 20}
ROOM_PACKS = {"desk": ("pack_a",), "marking": ("pack_b",), "wage": ("pack_c", "pack_d"), "court": ("boss",)}


class Sight:
    """Which mobs of a pack room see each of its floor cells, flat on the plan (a column
    off the floor blocks): a prop may stand only where every cell keeps a mob that sees
    it, so no pack can be walked round (the proof's coverage, with a node to spare)."""

    def __init__(self, lay):
        self.lay, self.seers, self.through = lay, {}, {}
        for room, keys in ROOM_PACKS.items():
            x0, z0, x1, z1 = ENVELOPES[room]
            cells = [c for c in lay.floor if x0 <= c[0] < x1 and z0 <= c[1] < z1]
            spots = []
            for key, mob, _, x, z, count in PACKS:
                if key in keys:
                    for dx, dz in ((0, 0), (3, 0), (-3, 0), (0, 3))[:count]:
                        if lay.floor.get((x + dx, z + dz)) == lay.floor[x, z]:
                            spots.append((x + dx, z + dz, VIEW[mob] - 1))
                        else:
                            spots.append((x, z, VIEW[mob] - 1))
            for cell in cells:
                self.seers[cell] = set()
                for i, (sx, sz, view) in enumerate(spots):
                    if (sx - cell[0]) ** 2 + (sz - cell[1]) ** 2 > view * view:
                        continue
                    line = self.line(sx, sz, *cell)
                    if all(c in lay.floor for c in line):
                        self.seers[cell].add((room, i))
                        for c in line:
                            self.through.setdefault(c, []).append((cell, (room, i)))

    @staticmethod
    def line(x0, z0, x1, z1):
        n = int(max(abs(x1 - x0), abs(z1 - z0)) * 4)
        out = set()
        for k in range(1, n):
            f = k / n
            for ex in (-0.2, 0.2):
                for ez in (-0.2, 0.2):
                    out.add((math.floor(x0 + (x1 - x0) * f + 0.5 + ex), math.floor(z0 + (z1 - z0) * f + 0.5 + ez)))
        out.discard((x0, z0))
        out.discard((x1, z1))
        return out

    def allows(self, cell):
        lost = {}
        for seen, seer in self.through.get(cell, ()):
            lost.setdefault(seen, set()).add(seer)
        return all(self.seers[seen] - gone for seen, gone in lost.items() if seen in self.seers and seen != cell)

    def take(self, cell):
        for seen, seer in self.through.get(cell, ()):
            if seen in self.seers:
                self.seers[seen].discard(seer)
        self.seers.pop(cell, None)


def post_light(t, lay, x, z, clear):
    """A timber prop on a flat floor cell, torches on its sides at the feet plus four: a
    group of light in a room's middle. Returns the undo list or None."""
    h = lay.floor.get((x, z))
    if h is None or (x, z) in clear or lay.part[x, z] not in ENVELOPES or not lay.sight.allows((x, z)):
        return None
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            n = (x + dx, z + dz)
            if lay.floor.get(n) != h or relief.stair_at(lay.floor, *n) or lay.top[n] < h + CLEAR:
                return None
            for y in range(h, h + CLEAR):
                if t.get(n[0], y, n[1]) != "air":
                    return None
    undo = [(x, y, z, t.get(x, y, z)) for y in range(h, lay.top[x, z] + 1)]
    sides = [(dx, dz, wall) for dx, dz, wall in ((1, 0, "-x"), (-1, 0, "+x"), (0, 1, "-z"), (0, -1, "+z"))
             if t.get(x + dx, h + CLEAR, z + dz) == "air"]
    if len(sides) < 2:
        return None
    t.box(x, h, z, x, lay.top[x, z], z, POST)
    # Two or three of its sides, by a seeded roll: the light falls unevenly round it.
    roll = dressing.roll(61, x, z)
    picked = sides[int(roll * len(sides)):] + sides[:int(roll * len(sides))]
    for dx, dz, wall in picked[:2 + (roll < 0.4)]:
        undo.append((x + dx, h + CLEAR, z + dz, "air"))
        light.torch(t, x + dx, h + CLEAR, z + dz, wall)
    lay.floor.pop((x, z))
    lay.sight.take((x, z))
    lay.post = getattr(lay, "post", set()) | {(x, z)}
    return undo


def wall_torch(t, lay, x, z):
    """A torch at the feet plus four on a wall beside the floor cell x, z. Returns the undo
    list or None."""
    h = lay.floor[x, z]
    y = h + CLEAR
    if y > lay.top[x, z] or t.get(x, y, z) != "air":
        return None
    for dx, dz, wall in ((1, 0, "+x"), (-1, 0, "-x"), (0, 1, "+z"), (0, -1, "-z")):
        if (x + dx, z + dz) not in lay.floor and registry.walkable(t.get(x + dx, y, z + dz)):
            light.torch(t, x, y, z, wall)
            return [(x, y, z, "air")]
    return None


def bench_lamp(t, lay, x, z, clear):
    """A tally bench with a lamp on it under a board, on a flat floor cell: a low glow at a
    work place. The bench lies below a mob's eye and the board above it, so it hides
    nobody from a pack. Returns the undo list or None."""
    h = lay.floor.get((x, z))
    if h is None or (x, z) in clear or lay.part[x, z] not in ENVELOPES or lay.top[x, z] < h + 2:
        return None
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            n = (x + dx, z + dz)
            if lay.floor.get(n) != h or relief.stair_at(lay.floor, *n):
                return None
    if any(t.get(x, y, z) != "air" for y in (h, h + 1, h + 2)):
        return None
    undo = [(x, y, z, "air") for y in (h, h + 1, h + 2)]
    t.set(x, h, z, BENCH, int(dressing.roll(62, x, z) * 4))
    t.set(x, h + 1, z, STAND_LAMP)
    t.set(x, h + 2, z, BOARD)
    lay.floor.pop((x, z))
    lay.post = getattr(lay, "post", set()) | {(x, z)}
    return undo


def place_light(t, lay, x, z, kind, avoid, clear=frozenset()):
    """One light for the dark cell x, z (or a neighbour): `kind` "wall" a lamp niche, "post"
    a lamp niche, a timber prop with torches or a lamp on a bench, else a hanging lantern.
    Returns the cell or None."""
    cells = sorted(((x + dx, z + dz) for dx in range(-5, 6) for dz in range(-5, 6)),
                   key=lambda c: (max(abs(c[0] - x), abs(c[1] - z)), abs(c[0] - x) + abs(c[1] - z), c))
    for cx, cz in cells:
        if (cx, cz) not in lay.floor or lay.part[cx, cz] == "alcove":
            continue
        y = lay.floor[cx, cz] + CLEAR
        undo = None
        if kind == "wall":
            undo = wall_lamp(t, lay, cx, cz)
        if undo is None and kind == "post":
            # In a pack room the filler's light hangs high (feet + 4) and is a little weaker,
            # so it leaves dim floor between the bright groups at things: a timber prop with
            # torches, else a torch on the wall, else a lamp on a bench.
            undo = post_light(t, lay, cx, cz, clear) or wall_torch(t, lay, cx, cz) or \
                bench_lamp(t, lay, cx, cz, clear)
        if undo is None:
            if y > lay.top[cx, cz] or t.get(cx, y, cz) != "air":
                continue
            undo = [(cx, cy, cz, t.get(cx, cy, cz)) for cy in range(y, lay.top[cx, cz] + 1)]
            light.lantern(t, cx, cz, y, lay.top[cx, cz])
        # Near a cell that must stay dark (by straight distance): the engine's light decides.
        if any(abs(ax - ux) + abs(ay - uy) + abs(az - uz) < 14 for ax, ay, az in avoid
               for ux, uy, uz, _ in undo[-1:]):
            levels = light.levels(t)
            if any(levels[light.index(t, *cell)] for cell in avoid):
                for ux, uy, uz, node in undo:
                    t.set(ux, uy, uz, node)
                if (cx, cz) in getattr(lay, "post", ()):
                    lay.floor[cx, cz] = lay.floor.get((cx, cz), y - CLEAR)
                    lay.post.discard((cx, cz))
                continue
        # Kept for thinning (lights): what it wrote, and the floor a prop took.
        lay.placed = getattr(lay, "placed", [])
        lay.placed.append((cx, cz, undo, None if (cx, cz) in lay.floor else y - CLEAR))
        return cx, cz
    return None


def thin(t, lay, fight, targets, share):
    """Takes filled lights out again, hanging lanterns first, wherever the floor keeps its
    rules without them: light 4 on the fighting floor (6 by the service places) and 6 on
    `share` of it. What stays are the groups at things; dimmer floor lies between them."""
    def rank(entry):
        cx, cz, undo, _ = entry
        nodes = {t.get(ux, uy, uz) for ux, uy, uz, _ in undo}
        return (0 if LANTERN in nodes else 1 if POST in nodes else 2, dressing.roll(64, cx, cz))

    def holds():
        levels = light.levels(t)
        usual = 0
        for (x, z), need in targets.items():
            if (x, z) not in lay.floor:
                continue
            v = levels[light.index(t, x, lay.floor[x, z] + 1, z)]
            if v < need:
                return False
            usual += (x, z) in fight and v >= 6
        return usual >= share * sum(1 for c in fight if c in lay.floor)
    for entry in sorted(getattr(lay, "placed", []), key=rank):
        cx, cz, undo, popped = entry
        now = [(ux, uy, uz, t.get(ux, uy, uz)) for ux, uy, uz, _ in undo]
        for ux, uy, uz, node in undo:
            t.set(ux, uy, uz, node)
        if popped is not None:
            lay.floor[cx, cz] = popped
        if not holds():
            for ux, uy, uz, node in now:
                t.set(ux, uy, uz, node)
            if popped is not None:
                lay.floor.pop((cx, cz))


def lights(t, lay, dark):
    authored_lights(t, lay)
    # The fighting floor as the proof reads it: every floor cell in a pack room's envelope.
    fight = {(x, z) for x, z in lay.floor
             if any(x0 <= x < x1 and z0 <= z < z1 for x0, z0, x1, z1 in ENVELOPES.values())}
    for (_, spots) in TRAPS_FLOOR.values():
        fight |= set(near(lay.floor, spots, 2))
    fight |= set(near(lay.floor, [(x, z) for x in (35, 43) for z in range(16, 24)], 2))
    targets = {c: 4 for c in fight}
    # The service places at 6 (arrival, waystones, chest, door); the rest of the arrival,
    # the store and the passages may be dim, a light in sight.
    for px, pz in ((107, 24), (107, 28), (107, 104), (107, 112), (83, 108)):
        for c in lay.floor:
            if (c[0] - px) ** 2 + (c[1] - pz) ** 2 <= 9:
                targets[c] = 6
    clear = keep_clear()
    lay.sight = Sight(lay)

    def kind(x, z):
        return "post" if lay.part[x, z] in ENVELOPES else "wall"
    left = fill_lights_with(t, lay, targets, kind, dark, clear)
    if left:
        raise ValueError(f"second_shift: no light for {left[:8]}")
    # Then the fighting floor's usual light: 6 or more on the share the build aims for (80 %, the proof asks 75 %),
    # with a little to spare; a light where most cells below 6 lie together.
    for _ in range(200):
        levels = light.levels(t)
        low = {c for c in fight if c in lay.floor and levels[light.index(t, c[0], lay.floor[c] + 1, c[1])] < 6}
        if len(low) <= USUAL_SPARE * len(fight):
            break
        best = max(sorted(low), key=lambda c: sum((c[0] + dx, c[1] + dz) in low
                                                  for dx in range(-3, 4) for dz in range(-3, 4)))
        if not place_light(t, lay, best[0], best[1], kind(*best), dark, clear):
            raise ValueError(f"second_shift: no light at {best}")
    thin(t, lay, fight, targets, 1 - USUAL_SPARE)


def fill_lights_with(t, lay, targets, kind, dark, clear):
    return fill_lights(t, lay, targets, lambda x, z: (kind(x, z), clear), dark, seed=73)


def dressing_pass(t, lay):
    floor = lay.floor
    drifts = lay.cells("p23", "p34", "alcove")
    damp = dressing.clusters(drifts, count=4, radius=5, seed=41, strength=0.7)
    dressing.scatter(t, floor, [MOSS, LICHEN, LICHEN_B], damp, seed=42, cells=drifts)
    dressing.walls(t, {c: floor[c] for c in drifts}, MOSSY, damp, seed=43)
    # Cobwebs on the office side: the desk niche and the office's corners.
    office = lay.cells("desk", "p12")
    webs = dressing.clusters(office, count=5, radius=4, seed=44, strength=0.9)
    dressing.hang(t, floor, COBWEB, webs, seed=45, clear=CLEAR + 1, cells=office)
    # Bones where miners fell: the wage hall's corners, the pay drift's bend.
    dead = lay.cells("wage", "p34")
    bones = dressing.clusters(dead, count=3, radius=3, seed=46, strength=0.5)
    traps = {(x + dx, z + dz) for _, spots in TRAPS_FLOOR.values() for x, z in spots
             for dx in range(-2, 3) for dz in range(-2, 3)}
    dressing.scatter(t, floor, [BONES, BONES, SKULL], bones, seed=47, cells=dead, avoid=traps)
    # A few lichen carpets in the marking floor's damp west.
    west = {c for c in lay.cells("marking") if c[0] <= 13}
    lich = dressing.clusters(west, count=2, radius=3, seed=48, strength=0.6)
    dressing.scatter(t, floor, [LICHEN, LICHEN_B], lich, seed=49, cells=west, avoid=traps)


CRITTERS = (("bats_arrival", BAT, 110, 14), ("weevils_p01", WEEVIL, 87, 25), ("weevils_p12", WEEVIL, 45, 25),
            ("crawlers_p34", CRAWLER, 48, 83), ("bats_store", BAT, 114, 100))


def critters(t, lay):
    """Five, in the side niches and the high rooms, never in a pack's room."""
    for room, mob, x, z in CRITTERS:
        t.encounter(room, mob, 1, "critter", x, lay.floor[x, z], z)


def particles(t, lay):
    """Paper over the office's desks and the pay tables, ash at the two lava falls, dust in
    the passages before the first fight and in the store. 170 live at most."""
    for style, x0, z0, x1, z1, amount in (
            ("paper", 53, 22, 70, 33, 40), ("paper", 12, 66, 29, 84, 30), ("ash", 9, 23, 13, 29, 25),
            ("ash", 63, 89, 69, 93, 25), ("dust", 84, 17, 94, 23, 20), ("dust", 98, 92, 117, 116, 30)):
        y = min(lay.floor.get((x, z), FEET) for x in range(x0, x1 + 1) for z in range(z0, z1 + 1))
        t.particles(style, x0, y + 1, z0, x1, y + 4, z1, amount)


# The packs: room, mob, tier, x, z, count.
PACKS = (
    # a: three raiders across the line the party walks, two miners south of them
    ("pack_a", RAIDER, "normal", 58, 21, 1), ("pack_a", RAIDER, "normal", 64, 18, 1),
    ("pack_a", RAIDER, "normal", 70, 22, 1), ("pack_a", MINER, "normal", 59, 29, 2),
    ("pack_b", RAIDER, "normal", 16, 19, 1), ("pack_b", RAIDER, "normal", 23, 23, 1),
    ("pack_b", RAIDER, "normal", 15, 29, 1), ("pack_b", MINER, "elite", 20, 32, 1),
    ("pack_c", RAIDER, "normal", 16, 71, 1), ("pack_c", RAIDER, "normal", 24, 77, 1),
    ("pack_c", RAIDER, "normal", 17, 80, 1), ("pack_c", MINER, "elite", 21, 79, 1),
    ("pack_d", RAIDER, "normal", 17, 101, 1), ("pack_d", RAIDER, "normal", 25, 104, 1),
    ("pack_d", RAIDER, "normal", 16, 110, 1), ("pack_d", MINER, "elite", 20, 108, 1),
    ("boss", BOSS, "boss", 63, 104, 1))


def packs(t, lay):
    for room, mob, tier, x, z, count in PACKS:
        t.encounter(room, mob, count, tier, x, lay.floor[x, z], z)


def traps(t, lay):
    # Floor candidates, the plan's groups: room 2 two of four, room 3 one of each pair,
    # the court two of four.
    for group, (pick, spots) in TRAPS_FLOOR.items():
        for x, z in spots:
            t.trap_floor(group, pick, x, lay.floor[x, z], z)
    # The wall: one of two muzzles in the gallery between rooms 1 and 2, across it (+z)
    # every 2 s (8 s until Round 74), the first shot on readiness.
    for x in (43, 35):
        t.trap_wall("w1", 1, x, 8.5, 15.6, "+z", 2, 0)


def build():
    t = Template("second_shift", (128, 32, 128), ROCK)
    lay = Layout()
    furnish(t, lay)
    build_floor(t, lay)
    walls(t, lay)
    roofs(t, lay)
    places(t, lay)
    lava(t, lay)
    rows = ambushes(t, lay)
    dark = dark_cells(lay, rows)
    lights(t, lay, dark)
    lit = hazards.dark(t, sorted(dark))
    if lit:
        raise ValueError(f"second_shift: an ambush is lit: {lit[:6]}")
    dressing_pass(t, lay)
    critters(t, lay)
    particles(t, lay)
    packs(t, lay)
    traps(t, lay)
    return t
