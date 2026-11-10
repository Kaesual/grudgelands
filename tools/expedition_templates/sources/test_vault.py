"""The tiny test Expedition: a start room, a dark drift with an ambush, a hall with a
stair-ringed rise and a lava fall, the gate, the end room. It proves the format, the
writer and the lanes' hooks; no dialog offers it.

Round 73 (lane GAME) is the format's smallest example of the new lines: the stairs
are written by hand here (the shaping helpers write them for the real templates), the
drift's ambush with its two alcoves, two critters, one particle box."""
from template import Template

STONE = "default:stonebrick"
LAVA = "default:lava_source"
LAVA_FLOWING = "default:lava_flowing"
STAIR = "stairs:stair_stonebrick"
STAIR_INNER = "stairs:stair_inner_stonebrick"
STAIR_OUTER = "stairs:stair_outer_stonebrick"
# A flowing node's param2: its level (0..7) and the falling bit.
FALLING = 8

# param2 of an upright stair (facedir 0..3): facedir p turns the node's +z toward
# (0, 1), (1, 0), (0, -1), (-1, 0) in (x, z). A stair's high half lies toward its +z,
# an outer stair's high quarter toward its (-x, +z) corner, an inner stair's low
# quarter toward its (+x, -z) corner.


def turn(v, p):
    x, z = v
    for _ in range(p):
        x, z = z, -x
    return x, z


def facing(v, local):
    """The facedir that turns the node's `local` direction to the world's `v`."""
    return next(p for p in range(4) if turn(local, p) == v)


def rise(t, cells, y, floor_free):
    """A rise one node high over the cells (x, z), with stairs where it meets the lower
    floor: a normal stair on a side, an outer stair on a convex corner, an inner stair on
    a concave one, full blocks inside. `floor_free(x, z)` names a lower floor cell; a
    wall is neither."""
    cells = set(cells)
    for x, z in sorted(cells):
        sides = [(dx, dz) for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)) if floor_free(x + dx, z + dz)]
        if not sides:
            corner = [(dx, dz) for dx, dz in ((1, 1), (1, -1), (-1, 1), (-1, -1))
                      if floor_free(x + dx, z + dz)]
            if corner:
                t.set(x, y, z, STAIR_INNER, facing(corner[0], (1, -1)))
            else:
                t.set(x, y, z, STONE)
        elif len(sides) == 1:
            dx, dz = sides[0]
            t.set(x, y, z, STAIR, facing((-dx, -dz), (0, 1)))
        else:
            (ax, az), (bx, bz) = sides
            assert ax != -bx or az != -bz, "a ridge one node wide"
            t.set(x, y, z, STAIR_OUTER, facing((-(ax + bx), -(az + bz)), (-1, 1)))


def build():
    t = Template("test_vault", (48, 32, 48), STONE)
    # the start room, floor at y 4, walking cells y 5..9
    t.box(4, 5, 4, 15, 9, 15, "air")
    # The drift (Round 73) from the start room's north side east to the hall: dark from
    # about x 6 to 16, the hall's lantern in sight at its end. Its ambush lies across
    # x 11..13 with an alcove on each side.
    t.box(5, 5, 16, 7, 8, 17, "air")
    t.box(5, 5, 18, 23, 8, 20, "air")
    t.box(12, 5, 21, 12, 7, 21, "air")
    t.box(12, 5, 17, 12, 7, 17, "air")
    t.box(24, 5, 4, 43, 11, 27, "air")
    # the end room north of the hall
    t.box(32, 5, 28, 35, 7, 31, "air")
    t.box(28, 5, 32, 39, 9, 43, "air")
    for x, z, wall in ((4, 7, 3), (15, 12, 2), (24, 15, 3), (43, 15, 2), (28, 38, 3), (39, 38, 2)):
        t.set(x, 8, z, "default:torch_wall", wall)
    # the drift's light at its end, on the hall's floor in line with it
    t.set(31, 5, 19, "grug_decor:xdecor_lantern")
    t.set(8, 5, 6, "grug_expeditions:waystone")
    t.place("start_waystone", 8, 5, 6)
    t.place("arrival", 8, 5, 8)
    t.set(34, 5, 42, "grug_expeditions:waystone")
    t.place("end_waystone", 34, 5, 42)
    t.set(30, 5, 40, "grug_expeditions:reward_chest", 1)
    t.place("chest", 30, 5, 40)
    # the reward door fills the passage; the boss's death opens it
    t.box(32, 5, 29, 35, 7, 29, "grug_expeditions:reward_door")
    t.place("door", 33, 5, 29)
    t.encounter("hall", "grug_mobs:giant_spider", 2, "normal", 30, 5, 12)
    t.encounter("hall", "grug_mobs:giant_spider", 1, "elite", 38, 5, 22)
    t.encounter("court", "grug_mobs:stone_golem", 1, "boss", 34, 5, 24)
    # The drift's ambush (Round 73): two zombies, one in each alcove, after the markers
    # the older fixtures count.
    t.ambush("a1", 1, "drift", 11, 5, 18, 13, 20)
    t.encounter("drift", "grug_mobs:zombie", 1, "normal", 12, 5, 21)
    t.encounter("drift", "grug_mobs:zombie", 1, "normal", 12, 5, 17)
    # The trap gallery (Round 72), closed: probes stand players in it. Floor traps
    # pick 1 of 2 and 2 of 2; a wall pick 1 of 2 across it every 4 s, a second wall
    # 2 s later.
    t.box(4, 5, 24, 19, 9, 43, "air")
    for x, z, wall in ((4, 28, 3), (19, 40, 2)):
        t.set(x, 8, z, "default:torch_wall", wall)
    t.trap_floor("f1", 1, 8, 5, 30)
    t.trap_floor("f1", 1, 14, 5, 30)
    t.trap_floor("f2", 2, 8, 5, 38)
    t.trap_floor("f2", 2, 14, 5, 38)
    t.trap_wall("w1", 1, 3.6, 5.5, 34, "+x", 4, 0)
    t.trap_wall("w1", 1, 19.4, 5.5, 34, "-x", 4, 0)
    t.trap_wall("w2", 1, 3.6, 5.5, 42, "+x", 4, 2)
    # Round 73: a rise against the hall's south wall, an L of stone brick one node
    # high with normal, inner and outer stairs (x 25..30 along the wall, an arm north
    # to z 10); the hall's floor cells lie at y 5.
    rise_cells = [(x, z) for x in range(25, 31) for z in range(4, 8)] + \
        [(x, z) for x in range(25, 29) for z in range(8, 11)]
    in_rise = set(rise_cells)
    rise(t, rise_cells, 5, lambda x, z: 24 <= x <= 43 and 4 <= z <= 27 and (x, z) not in in_rise)
    # A lava fall in the hall's east wall: the source in a niche above head height, the
    # falling column in a recess, the basin in the floor's row at its foot. Every cell
    # written as the engine's flow would leave it; the box's lava hold keeps it so.
    t.set(45, 9, 8, LAVA)
    for y in range(6, 10):
        t.set(44, y, 8, LAVA_FLOWING, FALLING | 7)
    t.set(44, 5, 8, LAVA_FLOWING, 7)
    for x, z in ((44, 8), (43, 8), (43, 9), (42, 8), (42, 9)):
        t.set(x, 4, z, LAVA)
    # Critters (Round 73): a crawler in the start room, a bat in the hall.
    t.encounter("crawlers", "grug_mobs:cave_crawler", 1, "critter", 13, 5, 13)
    t.encounter("bats", "grug_mobs:cave_bat", 1, "critter", 40, 5, 5)
    # Dust in the start room's air.
    t.particles("dust", 5, 5, 5, 14, 9, 14, 24)
    return t
