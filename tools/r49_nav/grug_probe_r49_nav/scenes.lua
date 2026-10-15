-- Round 49 NAV: the short-range chase scenes (pure data, no engine calls).
--
-- Loaded by the engine probe (init.lua). Every scene is one lane in
-- lane-local cells: u runs along the lane (the mob starts at u = 0, v = 0),
-- v across it, h is the height above the floor's top layer (h = 1 is the
-- layer a mob stands in on the floor; h = 0 the floor's top). A lane covers
-- u -LANE_BACK .. LANE_FRONT and v -LANE_HALF .. LANE_HALF inside a wall
-- WALL_H high (taller than a terrace plus a step, so no mob leaves its lane).
--
-- The user's cases (round49-gameplay-draft.md §4 NAV): a zombie chasing a
-- player who stands 1-2 nodes higher behind bushes, a giant rat chasing a
-- player behind a tree trunk, distances 3-8. Bushes are built as the
-- shipped schematics with every leaf present: `default:bush` (bush.mts) a
-- stem with 3x3x2 leaves, `default:blueberry_bush` (blueberry_bush.mts) one
-- 3x3 layer. Every bush node is a walkable full cube.
--
-- Ops, applied in order: {"fill", kind, u1, v1, h1, u2, v2, h2}. Kinds are
-- symbolic (init.lua maps them to node names).
--
-- Each scene names the target's feet cell {u, v, h}.

local scenes = {}

scenes.LANE_BACK = 4
scenes.LANE_FRONT = 14
scenes.LANE_HALF = 11
scenes.WALL_H = 6
scenes.FLOOR_DEPTH = -3

local F, H = scenes.LANE_FRONT, scenes.LANE_HALF

local function fill(kind, u1, v1, h1, u2, v2, h2)
	return {"fill", kind, u1, v1, h1, u2, v2, h2}
end

-- A raised level over the lane's whole width from u = e on, `top` nodes high.
local function terrace(e, top)
	return fill("solid", e, -H, 1, F, H, top)
end

-- A 2-wide step up to a 2-high terrace starting at u = e (one node at h 1 in
-- front of the edge).
local function ramp(e, v)
	return fill("solid", e - 1, v, 1, e - 1, v + 1, 1)
end

-- default:bush centred on (u, v), its lowest layer at h.
local function bush(ops, u, v, h)
	ops[#ops + 1] = fill("bush_leaves", u - 1, v - 1, h, u + 1, v + 1, h + 1)
	ops[#ops + 1] = fill("bush_stem", u, v, h, u, v, h)
end

-- default:blueberry_bush centred on (u, v) at h.
local function blueberry(ops, u, v, h)
	ops[#ops + 1] = fill("blueberry", u - 1, v - 1, h, u + 1, v + 1, h)
end

local function trunk(ops, u, v)
	ops[#ops + 1] = fill("trunk", u, v, 1, u, v, 5)
end

-- A small tree: a 5-high trunk under a canopy (5x5 at h 4-5, 3x3 at h 6).
local function tree(ops, u, v)
	ops[#ops + 1] = fill("leaves", u - 2, v - 2, 4, u + 2, v + 2, 5)
	ops[#ops + 1] = fill("leaves", u - 1, v - 1, 6, u + 1, v + 1, 6)
	trunk(ops, u, v)
end

local list = {}
local function add(name, note, target, build)
	local ops = {}
	build(ops)
	list[#list + 1] = {name = name, note = note, target = target, ops = ops}
end

-- Bushes and height (the zombie's case).
add("flat_bush_d4", "control: a bush on flat ground, the target right behind it",
	{4, 0, 1}, function(ops) bush(ops, 2, 0, 1) end)
add("t1_bush_d5", "1-high terrace from u 4, a bush at its foot, target on top",
	{5, 0, 2}, function(ops)
		ops[#ops + 1] = terrace(4, 1)
		bush(ops, 2, 0, 1)
	end)
add("t1_bush_d8", "1-high terrace from u 7, a bush at its foot, target on top",
	{8, 0, 2}, function(ops)
		ops[#ops + 1] = terrace(7, 1)
		bush(ops, 5, 0, 1)
	end)
add("t1_bushtop_d6", "1-high terrace from u 3, a bush on its edge, target behind it",
	{6, 0, 2}, function(ops)
		ops[#ops + 1] = terrace(3, 1)
		bush(ops, 4, 0, 2)
	end)
add("t1_blue_d4", "1-high terrace from u 1, a blueberry bush on its edge, target behind",
	{4, 0, 2}, function(ops)
		ops[#ops + 1] = terrace(1, 1)
		blueberry(ops, 2, 0, 2)
	end)
add("t1_blue_d7", "1-high terrace from u 4, a blueberry bush on its edge, target behind",
	{7, 0, 2}, function(ops)
		ops[#ops + 1] = terrace(4, 1)
		blueberry(ops, 5, 0, 2)
	end)
add("t2_open_d4", "control: 2-high terrace from u 3, a step up at v 4-5, no bush",
	{4, 0, 3}, function(ops)
		ops[#ops + 1] = terrace(3, 2)
		ops[#ops + 1] = ramp(3, 4)
	end)
add("t2_bush_d5", "2-high terrace from u 4, step up at v 4-5, a bush at its foot",
	{5, 0, 3}, function(ops)
		ops[#ops + 1] = terrace(4, 2)
		ops[#ops + 1] = ramp(4, 4)
		bush(ops, 2, 0, 1)
	end)
add("t2_bush_d8", "2-high terrace from u 7, step up at v 4-5, a bush at its foot",
	{8, 0, 3}, function(ops)
		ops[#ops + 1] = terrace(7, 2)
		ops[#ops + 1] = ramp(7, 4)
		bush(ops, 5, 0, 1)
	end)
add("t2_bush_d6_far", "2-high terrace from u 5, the step up at v 9-10 (outside a padding-6 box), a bush at its foot",
	{6, 0, 3}, function(ops)
		ops[#ops + 1] = terrace(5, 2)
		ops[#ops + 1] = ramp(5, 9)
		bush(ops, 3, 0, 1)
	end)
add("t2_blue_d5", "2-high terrace from u 2, step up at v 4-5, a blueberry bush on its edge",
	{5, 0, 3}, function(ops)
		ops[#ops + 1] = terrace(2, 2)
		ops[#ops + 1] = ramp(2, 4)
		blueberry(ops, 3, 0, 3)
	end)

-- Trunks (the giant rat's case).
add("trunk_d3", "a trunk at u 2, the target right behind it",
	{3, 0, 1}, function(ops) trunk(ops, 2, 0) end)
add("trunk_d5", "a trunk at u 4, the target right behind it",
	{5, 0, 1}, function(ops) trunk(ops, 4, 0) end)
add("trunk_d8", "a trunk at u 6, the target 2 behind it",
	{8, 0, 1}, function(ops) trunk(ops, 6, 0) end)
add("trunk_off_d5", "a trunk at u 4, the target behind it one node aside",
	{5, 1, 1}, function(ops) trunk(ops, 4, 0) end)
add("tree_d6", "a tree (trunk at u 4, canopy from h 4), the target 2 behind it",
	{6, 0, 1}, function(ops) tree(ops, 4, 0) end)
add("trunks_gap_d6", "two trunks at u 4, v -1 and +1 (a 1-wide gap on the line)",
	{6, 0, 1}, function(ops)
		trunk(ops, 4, -1)
		trunk(ops, 4, 1)
	end)

scenes.list = list

-- The second list (phase "extra"): a target that strafes behind its cover as
-- a player does (`strafe`: a sine of `amp` nodes across the lane over
-- `period` s), a target standing on a bush, and a grove of trunks with
-- 1-wide gaps (a 1.28-wide rat fits only round the grove's ends).
list = {}
add("trunk_d5_strafe", "a trunk at u 4, the target behind it strafing v -2..2 every 6 s",
	{5, 0, 1}, function(ops) trunk(ops, 4, 0) end)
list[#list].strafe = {amp = 2, period = 6}
add("t1_bush_d5_strafe", "as t1_bush_d5, the target strafing v -3..3 every 6 s",
	{5, 0, 2}, function(ops)
		ops[#ops + 1] = terrace(4, 1)
		bush(ops, 2, 0, 1)
	end)
list[#list].strafe = {amp = 3, period = 6}
add("t2_bush_d5_strafe", "as t2_bush_d5, the target strafing v -3..3 every 6 s",
	{5, 0, 3}, function(ops)
		ops[#ops + 1] = terrace(4, 2)
		ops[#ops + 1] = ramp(4, 4)
		bush(ops, 2, 0, 1)
	end)
list[#list].strafe = {amp = 3, period = 6}
add("bushtop_d3", "the target on top of a 2-high bush (u 2..4) on flat ground",
	{3, 0, 3}, function(ops) bush(ops, 3, 0, 1) end)
add("bluetop_d3", "the target on top of a blueberry bush (u 2..4) on flat ground",
	{3, 0, 2}, function(ops) blueberry(ops, 3, 0, 1) end)
add("grove_d7", "a grove: trunks at u 3 (v -4,-2,0,2,4) and u 5 (v -3,-1,1,3), target at u 7",
	{7, 0, 1}, function(ops)
		for v = -4, 4, 2 do trunk(ops, 3, v) end
		for v = -3, 3, 2 do trunk(ops, 5, v) end
	end)
add("trunk_root_d5", "a trunk at u 4 with 1-high stubs (roots) at u 3 and v +-1 round it",
	{5, 0, 1}, function(ops)
		trunk(ops, 4, 0)
		ops[#ops + 1] = fill("trunk", 3, 0, 1, 3, 0, 1)
		ops[#ops + 1] = fill("trunk", 4, -1, 1, 4, -1, 1)
		ops[#ops + 1] = fill("trunk", 4, 1, 1, 4, 1, 1)
	end)
scenes.extra = list

for index, scene in ipairs(scenes.list) do scene.index = index end
for index, scene in ipairs(scenes.extra) do scene.index = index end

function scenes.by_name(name)
	for _, l in ipairs({scenes.list, scenes.extra}) do
		for _, scene in ipairs(l) do
			if scene.name == name then return scene end
		end
	end
end

return scenes
