"""Break one rule of wp13/avenue.lua on purpose, run tools/wp13/street_kat.lua,
and show it goes red. Restores the file afterwards.

    python3 mutate.py <repo>
"""
import subprocess, sys, os

repo = sys.argv[1]
path = os.path.join(repo, "mods/MAPGEN/grug_mapgen/wp13/avenue.lua")
original = open(path).read()

MUTANTS = [
    ("ruling 1 -- a lane walked at its own level, not the road's",
     """				local surface_name = (offset == -half or offset == half) and
					KERB or PAVING""",
     """				local surface_name = (offset == -half or offset == half) and
					KERB or PAVING
				local top = level[p] - ((offset < 0) and 1 or 0)"""),
    ("ruling 2 -- a junction level taken from this run alone",
     """					for member = 1, #junction.members do
						local other = junction.members[member]
						local across = other_envelope(other)
						if across ~= nil and (best == nil or across > best) then
							best = across
						end
					end""",
     """					for member = 1, #junction.members do
						local _ = junction.members[member]
					end"""),
    ("ruling 3 -- a standard back on the ground beside the street",
     """					if is_lamp then
						buf:put(x, top + 1, z, palette.node("post"))""",
     """					if is_lamp then
						top = foot
						buf:put(x, top, z, KERB)
						buf:put(x, top + 1, z, palette.node("post"))"""),
    ("ruling 4 -- a raised street filled solid again",
     """				if raise > 0 and not wetlane[offset][p] and
						(raise < M.MIN_CLEAR or on_deck) then""",
     """				if raise > 0 and not wetlane[offset][p] then"""),
    ("ruling 5 -- a causeway over the water instead of a bridge",
     """				local carried = soaked and (y + M.LIFT) or y
				if top == nil or carried > top then top = carried end""",
     """				local carried = y
				soaked = false
				if top == nil or carried > top then top = carried end"""),
]

failures = 0
for label, old, new in MUTANTS:
    assert old in original, "mutation anchor missing: " + label
    open(path, "w").write(original.replace(old, new, 1))
    proc = subprocess.run(
        ["luajit", "-e", "io.write(dofile('tools/wp13/street_kat.lua')('.'))"],
        cwd=repo, capture_output=True, text=True,
        env=dict(os.environ, LC_ALL="C"))
    line = (proc.stderr.strip().splitlines() or ["(no output)"])[0]
    if proc.returncode == 0:
        print("NOT CAUGHT  %s" % label)
        failures += 1
    else:
        print("RED         %s\n            %s" % (label, line))
open(path, "w").write(original)
proc = subprocess.run(
    ["luajit", "-e", "io.write(dofile('tools/wp13/street_kat.lua')('.'))"],
    cwd=repo, capture_output=True, text=True, env=dict(os.environ, LC_ALL="C"))
print("restored    street_kat exit %d" % proc.returncode)
sys.exit(1 if failures or proc.returncode else 0)
