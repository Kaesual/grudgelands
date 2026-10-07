-- Round 42 NV0: the navigation test scenes (pure data, no engine calls).
--
-- Loaded by the engine probe (init.lua) and by tools/r42_nv0/portable_test.lua.
-- Every scene is one lane in lane-local cells: u runs along the lane (the mob
-- starts at u = 0 and its goal is at u = GOAL_U), v across it, h is the height
-- above the floor's top layer (h = 1 is the layer a mob stands in; h = 0 the
-- floor's top; h < 0 is dug into the floor). A lane covers u -LANE_BACK ..
-- LANE_FRONT and v -LANE_HALF .. LANE_HALF; the floor is solid from FLOOR_DEPTH
-- to h = 0 under the whole lane.
--
-- Ops, applied in order:
--   {"fill", node, u1, v1, h1, u2, v2, h2}   a box of one node kind
--   {"door", u, v, open}                      a wooden door at h 1..2 whose
--                                             panel spans v (the mob walks u)
-- Node kinds are symbolic ("solid", "trunk", "fence", "water", "air"); the
-- probe maps them to node names.
--
-- Each scene names its start and goal cells, a `blocked` cell {u, v[, h]} (a
-- feet cell right in front of the obstacle on the start side, where a
-- straight-walking mob ends up; h defaults to 1), the goal's height (2 on the
-- step) and whether a mob of one node's width can reach the goal at all
-- (`reachable`).

local scenes = {}

scenes.GOAL_U = 14
scenes.LANE_BACK = 6
scenes.LANE_FRONT = 22
scenes.LANE_HALF = 11
scenes.LANE_PITCH = 24 -- lanes sit side by side along v, this far apart
scenes.FLOOR_DEPTH = -4

local G = scenes.GOAL_U

local H = scenes.LANE_HALF

local function wall(u, v1, v2, top)
	return {"fill", "solid", u, v1, 1, u, v2, top}
end

-- A fence ring round the goal, `top` nodes high.
local function fence_ring(top)
	return {
		{"fill", "fence", G - 2, -2, 1, G + 2, -2, top},
		{"fill", "fence", G - 2, 2, 1, G + 2, 2, top},
		{"fill", "fence", G - 2, -1, 1, G - 2, 1, top},
		{"fill", "fence", G + 2, -1, 1, G + 2, 1, top},
	}
end

local list = {
	{
		name = "open",
		note = "control: flat open ground",
		ops = {},
	},
	{
		name = "trunk",
		note = "one tree trunk in the middle of the straight line",
		ops = {{"fill", "trunk", 7, 0, 1, 7, 0, 5}},
		blocked = {6, 0},
	},
	{
		name = "trunk_near",
		note = "the target 2 nodes behind a trunk (within melee reach of its front)",
		ops = {{"fill", "trunk", 12, 0, 1, 12, 0, 5}},
		blocked = {11, 0},
	},
	{
		name = "row",
		note = "a row of 7 trunks across the line, 1-node gaps, row ends at v +-6",
		ops = {
			{"fill", "trunk", 7, -6, 1, 7, -6, 5},
			{"fill", "trunk", 7, -4, 1, 7, -4, 5},
			{"fill", "trunk", 7, -2, 1, 7, -2, 5},
			{"fill", "trunk", 7, 0, 1, 7, 0, 5},
			{"fill", "trunk", 7, 2, 1, 7, 2, 5},
			{"fill", "trunk", 7, 4, 1, 7, 4, 5},
			{"fill", "trunk", 7, 6, 1, 7, 6, 5},
		},
		blocked = {6, 0},
	},
	{
		name = "doorway",
		note = "a 3-high wall across the lane with a 1-wide, 2-high doorway at v +4",
		ops = {
			wall(7, -H, H, 3),
			{"fill", "air", 7, 4, 1, 7, 4, 2},
		},
		blocked = {6, 0},
	},
	{
		name = "lcorner",
		note = "an L: wall u 7 (v -5..2) and wall v 2 (u 3..7), the way round at v -6",
		ops = {
			wall(7, -5, 2, 3),
			{"fill", "solid", 3, 2, 1, 7, 2, 3},
		},
		blocked = {6, 0},
	},
	{
		name = "fence",
		note = "a 2-high wooden fence ring round the target (visible, not walkable)",
		ops = fence_ring(2),
		blocked = {G - 3, 0},
		reachable = false,
	},
	{
		name = "fence_low",
		note = "a 1-high wooden fence ring (collision 1.0 high: below a 1.1 step)",
		ops = fence_ring(1),
		blocked = {G - 3, 0},
	},
	{
		name = "pillar",
		note = "a 3x3 stone pillar, 4 high",
		ops = {{"fill", "solid", 6, -1, 1, 8, 1, 4}},
		blocked = {5, 0},
	},
	{
		name = "ditch",
		note = "a 2-wide, 2-deep ditch across the lane; a 1-deep crossing at v 4..5",
		ops = {
			{"fill", "air", 6, -H, -1, 7, H, 0},
			{"fill", "solid", 6, 4, -1, 7, 5, -1},
		},
		blocked = {6, 0, -1},
	},
	{
		name = "step",
		note = "the ground rises by one node from u 7 on (a plain step up)",
		ops = {{"fill", "solid", 7, -H, 1, scenes.LANE_FRONT, H, 1}},
		goal_h = 2,
		blocked = {6, 0},
	},
	{
		name = "lowgap",
		note = "a 4-high wall across the lane, a 1-high hole on the line (v 0), a 2-high gap at v +5",
		ops = {
			wall(7, -H, H, 4),
			{"fill", "air", 7, 0, 1, 7, 0, 1},
			{"fill", "air", 7, 5, 1, 7, 5, 2},
		},
		blocked = {6, 0},
	},
	{
		name = "pond",
		note = "a 2-deep pond (u 4..10, v -6..6) on the line, one-node banks",
		ops = {{"fill", "water", 4, -6, -1, 10, 6, 0}},
		blocked = {3, 0},
	},
	{
		name = "door_closed",
		note = "a 3-high wall across the lane, a closed wooden door on the line",
		ops = {wall(7, -H, H, 3), {"door", 7, 0, false}},
		blocked = {6, 0},
		reachable = false,
	},
	{
		name = "door_open",
		note = "the same wall with the wooden door open",
		ops = {wall(7, -H, H, 3), {"door", 7, 0, true}},
		blocked = {6, 0},
	},
}

for index, scene in ipairs(list) do
	scene.index = index
	scene.start = {0, 0}
	scene.goal = {G, 0}
	scene.goal_h = scene.goal_h or 1
	scene.blocked = scene.blocked or {0, 0}
	if scene.reachable == nil then scene.reachable = true end
end

scenes.list = list

function scenes.by_name(name)
	for _, scene in ipairs(list) do
		if scene.name == name then return scene end
	end
end

-- The node kind of one cell after every op of the scene (no door handling:
-- a door cell reads "door", the cell above it "door_top").
function scenes.cell(scene, u, v, h)
	local kind
	if h <= 0 and h >= scenes.FLOOR_DEPTH then kind = "solid" else kind = "air" end
	for _, op in ipairs(scene.ops) do
		if op[1] == "fill" then
			local u1, u2 = math.min(op[3], op[6]), math.max(op[3], op[6])
			local v1, v2 = math.min(op[4], op[7]), math.max(op[4], op[7])
			local h1, h2 = math.min(op[5], op[8]), math.max(op[5], op[8])
			if u >= u1 and u <= u2 and v >= v1 and v <= v2 and h >= h1
					and h <= h2 then
				kind = op[2]
			end
		elseif op[1] == "door" then
			if u == op[2] and v == op[3] then
				if h == 1 then kind = "door" elseif h == 2 then kind = "door_top" end
			end
		end
	end
	return kind
end

-- Kinds a mob cannot stand in (the engine's `walkable`; water is not).
scenes.WALKABLE = {solid = true, trunk = true, fence = true, door = true,
	door_top = true}

return scenes
