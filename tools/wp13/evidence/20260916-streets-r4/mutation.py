"""Break one round-4 street rule on purpose, run tools/wp13/street_kat.lua, and
show it goes red. Restores every file afterwards.

    python3 mutation.py <repo>

The round-3 catalogue lives in ../20260916-streets/mutation.py and
mutation-review.py and still applies; these are the mutations of the rules this
round added -- the verge clearance of goal A (section 11) and Lethariel's
lane/ring inventory of goal B (section 8).

The two clearance mutations are deliberately NOT "turn the rule off": each of
them leaves the rule on and narrows it so that exactly ONE of the two shapes
section 11 builds keeps its rail. That is what says the section holds the butt
joint and the crossing separately rather than holding one of them twice.
"""
import subprocess, sys, os

repo = sys.argv[1]
PLAN = "mods/MAPGEN/grug_mapgen/wp13/street_plan.lua"
AVENUE = "mods/MAPGEN/grug_mapgen/wp13/avenue.lua"
QUADRANTS = "mods/MAPGEN/grug_mapgen/wp13/lethariel_quadrants.lua"

MUTANTS = [
    ("goal A -- the rail kept at a BUTT JOINT: the clearance clamped to the "
     "run's interior, so the end column a joining run lands on keeps its "
     "parapet", PLAN,
     """						if low ~= nil then
							if low < street.from then low = street.from end
							if high > street.to then high = street.to end""",
     """						if low ~= nil then
							if low < street.from + 1 then low = street.from + 1 end
							if high > street.to - 1 then high = street.to - 1 end"""),
    ("goal A -- the rail kept at a CROSSING: the clearance restricted to "
     "joints at a run's own end, so a street crossed in the middle keeps its "
     "parapet across the other road", PLAN,
     """							if line >= other.from and line <= other.to then
								low, high = other.at - half, other.at + half
							end""",
     """							if line >= other.from and line <= other.to and
									(other.at + half >= street.to or
										other.at - half <= street.from) then
								low, high = other.at - half, other.at + half
							end"""),
    ("goal A -- the clearance applied to the wrong SIDE, which leaves the "
     "furniture where a street joins and takes the parapet where none does",
     AVENUE,
     """					local side = (offset < 0) and -1 or 1""",
     """					local side = (offset < 0) and 1 or -1"""),
    ("goal B -- a district lane back beside the ring street, two nodes off "
     "its centre line: the side-by-side inventory section 8 pins",
     QUADRANTS,
     """			{id = "lane_northwest_spine", axis = "z", at = -RING_AT,
				from = LANE_START, to = LANE_END},""",
     """			{id = "lane_northwest_spine", axis = "z", at = -RING_AT - 2,
				from = 0, to = LANE_END},"""),
    # THE INDEPENDENT REVIEW'S OWN MUTATION (2026-09-16). It pulls every
    # district lane twenty columns off the ring end it continues -- five streets
    # left hanging in the fields with a 19-column hole in front of each -- and
    # when the review ran it, EVERY gate in the tree stayed green: street_kat,
    # lethariel_kat, highcourt_kat, lethariel_plots and walkability alike. That
    # is the hole section 8's reachability rule now closes.
    ("goal B -- every district lane pulled twenty columns off the ring end it "
     "continues: the review's own mutation, which nothing caught",
     QUADRANTS,
     """	M.LANE_START = M.RING_AT + 1""",
     """	M.LANE_START = M.RING_AT + 20"""),
    # And the half-step version: the lane still reaches its junction, so it is
    # not lonely, but it leaves a column of centre line nobody paves.
    ("goal B -- a district lane one column short of the ring end, leaving a "
     "column of its own centre line unpaved",
     QUADRANTS,
     """	M.LANE_START = M.RING_AT + 1
	local RING_AT, LANE_END, LANE_START = M.RING_AT, M.LANE_END, M.LANE_START""",
     """	M.LANE_START = M.RING_AT + 2
	local RING_AT, LANE_END, LANE_START = M.RING_AT, M.LANE_END, M.LANE_START"""),
    # And the literal the lanes are built against, pulled off the ring's own.
    ("goal B -- RING_AT drifted off the ring street's own centre line",
     QUADRANTS,
     """	M.RING_AT = 96""",
     """	M.RING_AT = 94"""),
]

failures = 0
originals = {}
for label, rel, old, new in MUTANTS:
    path = os.path.join(repo, rel)
    if rel not in originals:
        originals[rel] = open(path).read()
    original = originals[rel]
    assert old in original, "mutation anchor missing: " + label
    open(path, "w").write(original.replace(old, new, 1))
    proc = subprocess.run(
        ["luajit", "-e", "io.write(dofile('tools/wp13/street_kat.lua')('.'))"],
        cwd=repo, capture_output=True, text=True,
        env=dict(os.environ, LC_ALL="C"))
    line = (proc.stderr.strip().splitlines() or ["(no output)"])[0]
    open(path, "w").write(original)
    if proc.returncode == 0:
        print("NOT CAUGHT  %s" % label)
        failures += 1
    else:
        print("RED         %s\n            %s" % (label, line))
for rel, text in originals.items():
    open(os.path.join(repo, rel), "w").write(text)
proc = subprocess.run(
    ["luajit", "-e", "io.write(dofile('tools/wp13/street_kat.lua')('.'))"],
    cwd=repo, capture_output=True, text=True, env=dict(os.environ, LC_ALL="C"))
print("restored    street_kat exit %d" % proc.returncode)
sys.exit(1 if failures or proc.returncode else 0)
