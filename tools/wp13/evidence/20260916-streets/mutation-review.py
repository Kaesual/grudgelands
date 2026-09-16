"""Reviewer's own mutations of Lane S, run against tools/wp13/street_kat.lua."""
import subprocess, sys, os

repo = sys.argv[1]
AV = os.path.join(repo, "mods/MAPGEN/grug_mapgen/wp13/avenue.lua")
PLAN = os.path.join(repo, "mods/MAPGEN/grug_mapgen/wp13/street_plan.lua")

MUTANTS = [
    ("A. the junction square applied ONE COLUMN OFF-CENTRE", AV,
     """\t\t\t\tif best ~= nil then\n\t\t\t\t\tfor p = junction.low, junction.high do""",
     """\t\t\t\tif best ~= nil then\n\t\t\t\t\tfor p = junction.low + 1, junction.high + 1 do"""),
    ("B. the pillar rhythm doubled (PIER 8 -> 16)", AV,
     """	M.PIER = 8""",
     """	M.PIER = 16"""),
    ("C. piers never reach under the water (PIER_DEPTH 4 -> 0)", AV,
     """	M.PIER_DEPTH = 4""",
     """	M.PIER_DEPTH = 0"""),
    ("D. the junction square is a RECTANGLE: only half the width levelled", PLAN,
     """		local half = (width - 1) / 2""",
     """		local half = (width - 1) / 2 - 1"""),
    ("E. two squares sharing a column are NOT merged", PLAN,
     """				if shared then join(a, b) end""",
     """				if shared then local _ = a end"""),
    ("F. the other run's window clipped to the square (no reach)", AV,
     """\t\t\t\tlocal low = other.low - reach\n\t\t\t\tlocal high = other.high + reach""",
     """\t\t\t\tlocal low = other.low\n\t\t\t\tlocal high = other.high"""),
]

failures = 0
for label, path, old, new in MUTANTS:
    original = open(path).read()
    if old not in original:
        print("ANCHOR MISSING  %s" % label)
        failures += 1
        continue
    open(path, "w").write(original.replace(old, new, 1))
    proc = subprocess.run(
        ["luajit", "-e", "io.write(dofile('tools/wp13/street_kat.lua')('.'))"],
        cwd=repo, capture_output=True, text=True,
        env=dict(os.environ, LC_ALL="C"))
    open(path, "w").write(original)
    line = (proc.stderr.strip().splitlines() or ["(no stderr)"])[0]
    if proc.returncode == 0:
        print("NOT CAUGHT  %s" % label)
        failures += 1
    else:
        print("RED         %s\n            %s" % (label, line))
print("mutations not caught: %d" % failures)
