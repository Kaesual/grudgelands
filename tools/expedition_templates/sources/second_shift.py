"""The Second Shift, the level 40-69 Expedition for four players (Round 72 lane SHIFT):
the approved build plan docs/planning/round72-second-shift.md, The Stilled Seam's
envelopes mirrored on x, cut to the floor footprint the proofs need. tools/r72_shift/
portable_test.lua proves the route, the door, the ore, the packs, the traps, the
sight and the light on the written file.

The floor footprint, the route, the pack places, the trap places and the ore places
are final; the rough cuts, timber hoods and converging roof are the STYLE pass
(round72-plan.md §2.9). Every floor is flat: the first air cell is y 8 everywhere, with no step and no
dais. Every pack room is cut so that from each of its floor cells at least one mob of
its pack notices a player (view range and sight): no pack can be walked round."""
from template import Template
from shaping import cap_props, cells_of, hang, roof, wall_lights, walls

ROCK = "default:stone"
FEET, EYE = 8, 9
ROOM_TOP, COURT_TOP, PASS_TOP = 18, 22, 13
LANTERN_Y = 11

POST, BEAM, PLANK = "default:tree", "default:pine_wood", "default:wood"
BOARD = "grug_decor:darkage_reinforced_wood"
TORCH = "default:torch_wall"
LANTERN, ROPE = "grug_decor:xdecor_lantern_hanging", "grug_decor:xdecor_rope"
RAIL, CART = "grug_mapgen:mine_rail", "grug_mapgen:mine_cart"
TABLE, BENCH = "grug_decor:cottages_table", "grug_decor:cottages_bench"
BARREL = "grug_decor:cottages_barrel"
SIGN = "default:sign_wall_wood"
# The template's ore and gem places hold the T2 nodes, the markers a run of another
# tier writes its own in (catalogue.lua TEMPLATE_ORE, TEMPLATE_GEM): never anywhere
# else in this template.
ORE, GEM = "grug_materials:stone_with_anthracite", "grug_materials:stone_with_jade"
DOOR, CHEST = "grug_expeditions:reward_door", "grug_expeditions:reward_chest"
WAYSTONE = "grug_expeditions:waystone"
RAIDER, MINER, BOSS = "grug_mobs:skeleton_raider", "grug_mobs:zombie", "grug_mobs:auditor_nemm"

# Floor rectangles x0, z0, x1, z1, upper bounds excluded, as the plan draws them. A room
# is the union of its rectangles; the plan's envelope holds each.
ROOMS = {
    # 0 Arrival, envelope (96, 8, 120, 32)
    "arrival": ((100, 8, 112, 12), (96, 12, 112, 16), (96, 16, 120, 28), (96, 28, 116, 32)),
    # 1 Timekeeper's desk, envelope (48, 8, 80, 40): pack a
    "desk": ((56, 10, 72, 14), (50, 14, 78, 16), (48, 16, 80, 24), (50, 24, 78, 30),
             (49, 30, 74, 34), (49, 34, 68, 37), (54, 37, 64, 39)),
    # 2 Marking floor, envelope (8, 8, 32, 40): pack b
    "marking": ((12, 9, 24, 12), (9, 12, 30, 16), (9, 16, 32, 24), (9, 24, 30, 32),
                (9, 32, 28, 36), (9, 36, 26, 40)),
    # 3 Wage room, envelope (8, 64, 32, 120): packs c and d, the screen between them
    "wage": ((12, 64, 28, 68), (9, 68, 31, 84), (12, 84, 32, 88), (24, 88, 32, 96),
             (9, 96, 32, 112), (9, 112, 31, 113), (12, 113, 30, 116), (14, 116, 24, 118)),
    # 4 Audit court, envelope (48, 88, 80, 120): Auditor Nemm
    "court": ((56, 89, 72, 92), (52, 92, 76, 96), (48, 96, 80, 112), (52, 112, 76, 116),
              (56, 116, 72, 119)),
    # 5 Store, envelope (96, 88, 120, 120)
    "store": ((96, 88, 112, 92), (96, 92, 120, 116), (96, 116, 120, 120)),
}
# In route order: 0 -> 1, 1 -> 2, 2 -> 3, 3 -> 4, 4 -> 5.
PASSAGES = ((80, 16, 96, 24), (32, 16, 48, 24), (16, 40, 24, 64), (32, 104, 48, 112),
            (80, 104, 96, 112))
# The full-height rock screen between packs c and d; the room's bypass runs east of it.
SCREEN = (8, 88, 24, 96)
# Nemm's range (BOSSRESET): the court's envelope, two opposite corners.
COURT_ENVELOPE = (48, 88, 80, 120)
# wallmounted param2 of a torch or sign by the wall behind it.
WEST, EAST, NORTH, SOUTH = 3, 2, 5, 4
FACE_WEST = 1  # the chest's front looks at the door (facedir: towards -x)


def rects(t, rect_list, top, node="air"):
    for x0, z0, x1, z1 in rect_list:
        t.box(x0, FEET, z0, x1 - 1, top, z1 - 1, node)


def floor(t, rect_list, kinds):
    """Rubble underfoot, the same on every build: kinds are (node, weight) rows."""
    total = sum(weight for _, weight in kinds)
    for x0, z0, x1, z1 in rect_list:
        for z in range(z0, z1):
            for x in range(x0, x1):
                roll = ((x * 7349 + 13) ^ (z * 9151 + 7) ^ (x * z * 31)) % total
                for node, weight in kinds:
                    if roll < weight:
                        t.set(x, FEET - 1, z, node)
                        break
                    roll -= weight


def lanterns(t, rect_list, top, step):
    """Lanterns on ropes over every room, every second row shifted, on a grid of the
    whole box so neighbouring rectangles agree."""
    for x0, z0, x1, z1 in rect_list:
        for z in range(z0, z1):
            if (z - 2) % step:
                continue
            row = (z - 2) // step
            for x in range(x0, x1):
                if (x - 2 - (row % 2) * (step // 2)) % step:
                    continue
                hang(t, x, z, LANTERN_Y, top)


def frame_x(t, x, z0, z1, top):
    """A timber frame across a passage running in x: posts at its sides, the beam in the
    roof above the six clear nodes."""
    for z in (z0, z1):
        t.box(x, FEET, z, x, top + 1, z, POST)
    t.box(x, top + 1, z0, x, top + 1, z1, BEAM)


def frame_z(t, z, x0, x1, top):
    """A timber frame across a passage running in z."""
    for x in (x0, x1):
        t.box(x, FEET, z, x, top + 1, z, POST)
    t.box(x0, top + 1, z, x1, top + 1, z, BEAM)


def ore(t, node, x, z):
    """A marked node at reach on a plinth of rock, the hull behind it."""
    t.set(x, FEET, z, ROCK)
    t.set(x, EYE, z, node)
    # Mining leaves no body-sized space over the one-node rock foot.
    t.box(x, FEET + 2, z, x, ROOM_TOP, z, ROCK)


def carve_all(t):
    for rect in PASSAGES:
        rects(t, (rect,), PASS_TOP)
    for name, rect_list in ROOMS.items():
        rects(t, rect_list, COURT_TOP if name == "court" else ROOM_TOP)
    x0, z0, x1, z1 = SCREEN
    t.box(x0, FEET, z0, x1 - 1, ROOM_TOP, z1 - 1, ROCK)
    worn = ((ROCK, 5), ("default:cobble", 3), ("default:gravel", 2))
    floor(t, PASSAGES, worn)
    for name, rect_list in ROOMS.items():
        floor(t, rect_list, ((PLANK, 1),) if name == "store" else worn)


def arrival(t):
    """0: a bent refuge, a boarded collapse and low beams round the waystone."""
    t.box(100, FEET, 8, 111, FEET + 4, 8, BOARD)
    t.box(100, FEET, 8, 100, FEET + 4, 8, POST)
    t.box(111, FEET, 8, 111, FEET + 4, 8, POST)
    for x in (100, 106, 111):
        t.box(x, ROOM_TOP, 12, x, ROOM_TOP, 31, BEAM)
    t.box(98, FEET, 31, 103, FEET, 31, BENCH, 0)
    t.box(118, FEET, 18, 118, FEET, 23, BENCH, 3)
    for x, z in ((96, 12), (97, 12), (96, 13), (119, 27), (115, 31)):
        t.set(x, FEET, z, BARREL)
    t.set(107, FEET, 28, WAYSTONE)
    t.place("start_waystone", 107, FEET, 28)
    t.place("arrival", 107, FEET, 24)
    for z in (17, 26):
        t.set(119, 11, z, TORCH, EAST)
    t.set(96, 11, 26, TORCH, WEST)
    for x in (104, 108):
        t.set(x, 11, 9, TORCH, NORTH)
    t.set(110, 11, 31, TORCH, SOUTH)


def passages(t):
    for x in (84, 90):
        frame_x(t, x, 16, 23, PASS_TOP)
    for z in (46, 52, 58):
        frame_z(t, z, 16, 23, PASS_TOP)
    for x in (36, 40, 84):
        frame_x(t, x, 104, 111, PASS_TOP)
    for x in (82, 88, 93, 34, 40, 46):
        t.set(x, 11, 16, TORCH, NORTH)
        t.set(x, 11, 23, TORCH, SOUTH)
    for x in (34, 38, 42, 46, 81, 86, 92):
        t.set(x, 11, 104, TORCH, NORTH)
        t.set(x, 11, 111, TORCH, SOUTH)
    for z in (43, 49, 55, 61):
        t.set(16, 11, z, TORCH, WEST)
        t.set(23, 11, z, TORCH, EAST)


def desk(t):
    """1: a desk niche with the lit shift board; a cart siding ends in crushed rock."""
    # the siding along the south wall, no track across the floor: floors stay flat
    t.box(55, FEET, 36, 66, FEET, 36, RAIL, 1)
    t.box(67, FEET, 36, 67, FEET, 36, "default:gravel")
    t.set(56, FEET, 36, CART, 1)
    # the timekeeper's desk in its niche on the north wall, the board above it
    t.box(61, FEET, 10, 66, FEET, 10, TABLE)
    t.set(63, 10, 10, SIGN, NORTH)
    t.place("shift_board", 63, 10, 10)
    for x in (56, 71):
        t.box(x, FEET, 10, x, ROOM_TOP, 10, POST)
    ore(t, ORE, 48, 36)
    t.set(52, 11, 37, TORCH, SOUTH)


def marking(t):
    """2: a jagged cutting, roof ribs; broken beams lie flush underfoot."""
    for z in (14, 22, 30):
        t.box(9, ROOM_TOP, z, 29, ROOM_TOP, z, BEAM)
    t.box(12, FEET - 1, 26, 15, FEET - 1, 26, BEAM)
    t.box(22, FEET - 1, 17, 22, FEET - 1, 20, BEAM)
    ore(t, GEM, 8, 36)
    for x in (16, 21):
        t.set(x, 11, 9, TORCH, NORTH)


def wage(t):
    """3: unequal pay bays round the rock screen, benches along the walls."""
    t.box(9, FEET, 70, 9, FEET, 80, BENCH, 1)
    t.box(30, FEET, 70, 30, FEET, 82, TABLE)
    t.box(9, FEET, 99, 9, FEET, 108, BENCH, 1)
    t.box(30, FEET, 96, 30, FEET, 101, TABLE)
    for x, z in ((12, 64), (13, 64), (27, 64), (12, 84), (29, 112), (12, 113)):
        t.set(x, FEET, z, BARREL)
    for z in (74, 102):
        t.box(9, ROOM_TOP, z, 30, ROOM_TOP, z, BEAM)


def court(t):
    """4: the open court round Nemm, high roof ribs converging over him; no dais."""
    for x in (56, 63, 71):
        t.box(x, COURT_TOP, 89, x, COURT_TOP, 118, BEAM)
    for x, z in ((56, 89), (71, 89), (56, 118), (71, 118)):
        t.box(x, FEET, z, x, COURT_TOP, z, POST)
    t.box(48, FEET - 1, 100, 51, FEET - 1, 100, BEAM)
    t.box(76, FEET - 1, 107, 79, FEET - 1, 107, BEAM)
    x0, z0, x1, z1 = COURT_ENVELOPE
    t.place("boss_room_min", x0, FEET, z0)
    t.place("boss_room_max", x1 - 1, FEET, z1 - 1)


def store(t):
    """5: a pocket store, mineral alcoves and the chest by the end waystone."""
    for x, z in ((108, 88), (109, 88), (108, 89), (118, 119), (117, 119)):
        t.set(x, FEET, z, BARREL)
    t.set(107, FEET, 104, CHEST, FACE_WEST)
    t.place("chest", 107, FEET, 104)
    t.set(107, FEET, 112, WAYSTONE)
    t.place("end_waystone", 107, FEET, 112)
    for x, z, node in ((119, 96, ORE), (96, 92, ORE), (96, 100, ORE), (119, 116, ORE),
                       (119, 108, GEM), (96, 116, GEM)):
        ore(t, node, x, z)
    t.set(96, 11, 90, TORCH, WEST)
    t.set(99, 11, 119, TORCH, SOUTH)


def rooms(t):
    arrival(t)
    passages(t)
    desk(t)
    marking(t)
    wage(t)
    court(t)
    store(t)
    shape(t)
    for name, rect_list in ROOMS.items():
        lanterns(t, rect_list, COURT_TOP if name == "court" else ROOM_TOP, 6)
    wall_lights(t, cells_of(sum((list(r) for r in ROOMS.values()), []) + list(PASSAGES)), FEET)


def shape(t):
    """Six different roof silhouettes over the proven floor and sight rows."""
    profiles = {
        "arrival": lambda x, z: 13 + min(3, max(0, (x - 96) // 4)) - (z >= 28),
        "desk": lambda x, z: 14 + min(5, max(0, (z - 10) // 3)) - (x > 71),
        "marking": lambda x, z: 13 + min(5, max(0, (x - 9) // 3)) - ((z // 5) % 2),
        "wage": lambda x, z: (14 + min(3, (x - 9) // 5) if z < 88 else
                               14 + max(0, 5 - abs(x - 21) // 2)),
        "court": lambda x, z: 23 - max(abs(x - 63) // 2, abs(z - 104) // 2),
        "store": lambda x, z: 15 if x % 6 == 0 or z % 8 == 0 else 17,
    }
    for name, rect_list in ROOMS.items():
        cells = cells_of(rect_list)
        top = COURT_TOP if name == "court" else ROOM_TOP
        def material(x, z):
            rib = (z % 7 == 0 if name in ("desk", "marking", "wage") else x % 7 == 0)
            return BEAM if rib or name == "store" else ROCK
        roof(t, cells, top, profiles[name], material)
        # Strata and jammed timber rise into the overhang, rather than repeating a
        # texture at one height. The ore's backing and the two sight rows stay rock.
        walls(t, cells, FEET + 3, top,
              lambda x, y, z: POST if (x + z) % 7 == 0 else
              ("default:cobble" if y == 12 + (x // 4 + z // 5) % 3 else ROCK))
        # Rails stay unhooded: a player stands on them, so a mob needs the full headroom there.
        cap_props(t, cells, FEET, top, (TABLE, BENCH, BARREL, CART, "default:gravel"), BOARD)
    # The sign keeps its fixed place in the hooded desk niche.
    t.set(63, FEET + 1, 10, BOARD)
    t.set(63, 10, 10, SIGN, NORTH)
    # Tally boards: flush wall panels, framed above eye level. No free shelf.
    for z in (17, 25, 33):
        t.box(8, 11, z, 8, 14, z + 2, BOARD)
        for dz in (0, 2):
            t.box(8, 11, z + dz, 8, 13, z + dz, BEAM)
    # Pay bays have different lintels: low and pressed down in c, peaked in d.
    for z in (74, 102):
        for x in range(9, 31):
            y = profiles["wage"](x, z)
            t.set(x, y, z, BEAM)
    # Nemm's four existing posts become splayed shoulders in the high roof.
    for x, z in ((56, 89), (71, 89), (56, 118), (71, 118)):
        t.box(x, 12, z, x, 22, z, POST)
    for x in range(57, 71):
        t.set(x, profiles["court"](x, 104), 104, BEAM)


def door(t):
    t.box(83, FEET, 104, 83, PASS_TOP, 111, DOOR)
    t.place("door", 83, FEET + 2, 108)


def packs(t):
    # a: three raiders across the line the party walks, two miners south of them
    t.encounter("pack_a", RAIDER, 1, "normal", 58, FEET, 21)
    t.encounter("pack_a", RAIDER, 1, "normal", 64, FEET, 18)
    t.encounter("pack_a", RAIDER, 1, "normal", 70, FEET, 22)
    t.encounter("pack_a", MINER, 2, "normal", 59, FEET, 30)
    # b
    t.encounter("pack_b", RAIDER, 1, "normal", 16, FEET, 19)
    t.encounter("pack_b", RAIDER, 1, "normal", 23, FEET, 23)
    t.encounter("pack_b", RAIDER, 1, "normal", 15, FEET, 29)
    t.encounter("pack_b", MINER, 1, "elite", 18, FEET, 32)
    # c
    t.encounter("pack_c", RAIDER, 1, "normal", 16, FEET, 71)
    t.encounter("pack_c", RAIDER, 1, "normal", 24, FEET, 77)
    t.encounter("pack_c", RAIDER, 1, "normal", 17, FEET, 80)
    t.encounter("pack_c", MINER, 1, "elite", 21, FEET, 79)
    # d
    t.encounter("pack_d", RAIDER, 1, "normal", 17, FEET, 101)
    t.encounter("pack_d", RAIDER, 1, "normal", 25, FEET, 104)
    t.encounter("pack_d", RAIDER, 1, "normal", 16, FEET, 110)
    t.encounter("pack_d", MINER, 1, "elite", 20, FEET, 108)
    t.encounter("boss", BOSS, 1, "boss", 63, FEET, 104)


def traps(t):
    # Floor candidates, the plan's groups: room 2 two of four, room 3 one of each pair,
    # the court two of four.
    for x, z in ((27, 20), (11, 20), (27, 32), (11, 32)):
        t.trap_floor("f1", 2, x, FEET, z)
    for x, z in ((27, 76), (11, 80)):
        t.trap_floor("f5", 1, x, FEET, z)
    for x, z in ((27, 104), (11, 112)):
        t.trap_floor("f7", 1, x, FEET, z)
    for x, z in ((71, 96), (55, 96), (71, 112), (55, 112)):
        t.trap_floor("f9", 2, x, FEET, z)
    # The wall: one of two muzzles in the passage between rooms 1 and 2, across it
    # (+z) every 8 s, the first shot on readiness.
    for x in (43, 35):
        t.trap_wall("w1", 1, x, 8.5, 15.6, "+z", 8, 0)


def build():
    t = Template("second_shift", (128, 32, 128), ROCK)
    carve_all(t)
    rooms(t)
    door(t)
    packs(t)
    traps(t)
    t.dig(ORE)
    t.dig(GEM)
    return t
