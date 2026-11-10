#!/usr/bin/env python3
"""Round 73 lane GAME: template.py's new writers and refusals (plan section 3.1).
Run by tools/r73_game/portable_test.lua; prints "R73 GAME WRITERS PASS checks=<n>".

  python3 tools/r73_game/writers_test.py [REPO]
"""
import sys
from pathlib import Path

REPO = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
sys.path.insert(0, str(REPO / "tools/expedition_templates"))
import template as tpl  # noqa: E402

checks = 0


def check(ok, label):
    global checks
    checks += 1
    if not ok:
        raise SystemExit(f"FAIL {label}")


def walkable(node):
    return node != "air"


def base():
    t = tpl.Template("x", (16, 16, 16), "default:stone")
    t.box(1, 2, 1, 14, 5, 14, "air")
    t.set(2, 2, 2, tpl.WAYSTONE)
    t.place("start_waystone", 2, 2, 2)
    t.set(4, 2, 2, tpl.WAYSTONE)
    t.place("end_waystone", 4, 2, 2)
    t.place("arrival", 2, 2, 4)
    return t


def raises(fn, label):
    try:
        fn()
    except ValueError:
        check(True, label)
        return
    check(False, label + " was accepted")


def refused(build, needle):
    t = base()
    build(t)
    found = t.problems(walkable)
    check(any(needle in p for p in found), f"refused {needle}: {found}")


# The lines, exactly plan section 3.1, corners in either order.
t = base()
t.encounter("drift", "grug_mobs:zombie", 1, "normal", 5, 2, 9)
t.encounter("bats", "grug_mobs:cave_bat", 2, "critter", 9, 2, 9)
t.ambush("a1", 1, "drift", 7, 2, 8, 5, 6)
t.particles("ember", 9, 4, 9, 7, 2, 7, 40)
check(t.problems(walkable) == [], f"a good template: {t.problems(walkable)}")
head = tpl.read_back(t.to_bytes())[0]
check("ambush a1 1 drift 5 2 6 7 8" in head, f"the ambush line {head}")
check("particles ember 7 2 7 9 4 9 40" in head, "the particles line")
check("encounter bats grug_mobs:cave_bat 2 critter 9 2 9" in head, "a critter marker")
check(head[-1].startswith("data "), "data last")
check(head.index("ambush a1 1 drift 5 2 6 7 8") < head.index("particles ember 7 2 7 9 4 9 40"),
      "ambush before particles")

# Writer refusals.
raises(lambda: base().ambush("a", 0, "r", 1, 2, 1, 2, 2), "pick 0")
raises(lambda: base().ambush("a", 1, "two words", 1, 2, 1, 2, 2), "a room of two words")
raises(lambda: base().ambush("a", 1, "r", 1, 2, 1, 20, 2), "a zone outside")
raises(lambda: base().particles("fog", 1, 2, 1, 2, 3, 2, 5), "an unknown style")
raises(lambda: base().particles("dust", 1, 2, 1, 2, 3, 2, 0), "amount 0")
raises(lambda: base().particles("dust", 1, 2, 1, 2, 3, 2, 2.5), "amount not whole")
raises(lambda: base().particles("dust", 1, 2, 1, 2, 30, 2, 5), "a box outside")
raises(lambda: base().ambush("a", 1, "r", 11.5, 2, 1, 12, 2), "an ambush corner not whole")
raises(lambda: base().ambush("a", 1, "r", 1, 2.0, 1, 2, 2), "an ambush floor row as a float")
raises(lambda: base().ambush("a", 1, "r", 1, 2, 1, True, 2), "an ambush corner as a bool")
raises(lambda: base().particles("dust", 1, 2.5, 1, 2, 3, 2, 5), "a particle box corner not whole")

# Build refusals, as the reader's (template.lua).
refused(lambda t: (t.encounter("r", "grug_mobs:zombie", 1, "normal", 5, 2, 9),
                   t.ambush("a", 1, "r", 5, 2, 5, 6, 6), t.ambush("a", 2, "s", 5, 2, 7, 6, 7)),
        "disagrees with itself")
refused(lambda t: (t.encounter("r", "grug_mobs:zombie", 1, "normal", 5, 2, 9),
                   t.ambush("f", 1, "r", 5, 2, 5, 6, 6), t.trap_floor("f", 1, 8, 2, 8)),
        "disagrees with itself")
refused(lambda t: (t.encounter("r", "grug_mobs:zombie", 1, "normal", 5, 2, 9),
                   t.ambush("a", 2, "r", 5, 2, 5, 6, 6)), "picks 2 of 1")
refused(lambda t: t.ambush("a", 1, "r", 5, 2, 5, 6, 6), "names no markers")
refused(lambda t: (t.encounter("r", "grug_mobs:zombie", 1, "elite", 5, 2, 9),
                   t.ambush("a", 1, "r", 5, 2, 5, 6, 6)), "holds a elite")
refused(lambda t: (t.encounter("r", "grug_mobs:zombie", 1, "normal", 5, 2, 9),
                   t.ambush("a", 1, "r", 5, 2, 5, 6, 6), t.ambush("b", 1, "r", 7, 2, 5, 8, 6)),
        "has two ambushes")
refused(lambda t: (t.encounter("r", "grug_mobs:zombie", 1, "normal", 5, 2, 9),
                   t.encounter("r", "grug_mobs:cave_bat", 1, "critter", 6, 2, 9)),
        "mixes critters and a pack")
refused(lambda t: t.encounter("r", "grug_mobs:zombie", 1, "king", 5, 2, 9), "tier king")
refused(lambda t: [t.particles("dust", 1, 2, 1, 2, 3, 2, 100) for _ in range(4)], "over the budget of 300")

# The shipped templates hold to it, the test vault's new lines included.
sys.path.insert(0, str(REPO / "tools/expedition_templates/sources"))
import test_vault  # noqa: E402
vault = test_vault.build()
check(vault.problems(walkable) == [], f"the test vault: {vault.problems(walkable)}")
check(len(vault.ambushes) == 1 and len(vault.particle_boxes) == 1, "its lines")
print(f"R73 GAME WRITERS PASS checks={checks}")
