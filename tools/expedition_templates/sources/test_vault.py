"""The tiny test Expedition: a start room, a gate, a hall, the end room. It proves
the format, the writer and the lanes' hooks; no dialog offers it."""
from template import Template

STONE = "default:stonebrick"


def build():
    t = Template("test_vault", (48, 32, 48), STONE)
    # the start room, floor at y 4, walking cells y 5..9
    t.box(4, 5, 4, 15, 9, 15, "air")
    # a passage east to the hall, its gate at x 19
    t.box(16, 5, 9, 23, 7, 10, "air")
    t.box(24, 5, 4, 43, 11, 27, "air")
    # the end room north of the hall
    t.box(32, 5, 28, 35, 7, 31, "air")
    t.box(28, 5, 32, 39, 9, 43, "air")
    for x, z, wall in ((4, 7, 3), (15, 12, 2), (24, 15, 3), (43, 15, 2), (28, 38, 3), (39, 38, 2)):
        t.set(x, 8, z, "default:torch_wall", wall)
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
    return t
