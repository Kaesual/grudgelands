-- Round 42 NV0 portable fixture: the navigation test scenes stay what NV1-DR
-- compare against. Loads the probe's pure scene data and checks every scene
-- with a small grid search modelled on the engine's pathfinder (four
-- directions, a walkable node blocks, max_jump 1, max_drop 6, no head-room
-- check), plus the same search with head room for a two-node mob.
--   luajit tools/r42_nv0/portable_test.lua <repo>
local repo = arg[1] or "."
local scenes = dofile(repo .. "/tools/r42_nv0/grug_probe_r42_nv0/scenes.lua")

local failures = 0
local function check(cond, msg)
	if not cond then
		failures = failures + 1
		print("FAIL " .. msg)
	end
end

local WALK = scenes.WALKABLE
local function walkable(scene, u, v, h)
	if u < -scenes.LANE_BACK or u > scenes.LANE_FRONT or v < -scenes.LANE_HALF
			or v > scenes.LANE_HALF then
		return true -- the lane's own walls
	end
	return WALK[scenes.cell(scene, u, v, h)] == true
end

-- Breadth-first search over feet cells, engine rules (pathfinder.cpp
-- calcCost): same height onto walkable ground, a drop of up to `drop`, a jump
-- of up to `jump` with a free column above both cells. `head` > 1 also asks
-- for that many free cells at every feet cell (ruling 6's head room).
local function search(scene, from, to, head)
	local function key(u, v, h) return u .. "," .. v .. "," .. h end
	local function free(u, v, h)
		for dy = 0, head - 1 do
			if walkable(scene, u, v, h + dy) then return false end
		end
		return true
	end
	local seen, queue, first = {}, {{from[1], from[2], from[3]}}, 1
	seen[key(from[1], from[2], from[3])] = {}
	while first <= #queue do
		local c = queue[first]
		first = first + 1
		if c[1] == to[1] and c[2] == to[2] and c[3] == to[3] then
			local path, k = {}, key(c[1], c[2], c[3])
			while seen[k] and seen[k].from do
				path[#path + 1] = seen[k].cell
				k = seen[k].from
			end
			return path
		end
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local u, v, h = c[1] + d[1], c[2] + d[2], c[3]
			local nh
			if not walkable(scene, u, v, h) then
				local y = h
				while y > h - 7 and not walkable(scene, u, v, y - 1) do y = y - 1 end
				if walkable(scene, u, v, y - 1) and h - y <= 6 then nh = y end
			elseif not walkable(scene, u, v, h + 1)
					and not walkable(scene, c[1], c[2], h + 1) then
				nh = h + 1
			end
			if nh and free(u, v, nh) and (nh <= h or free(c[1], c[2], h)) then
				local k = key(u, v, nh)
				if not seen[k] then
					seen[k] = {from = key(c[1], c[2], c[3]), cell = {u, v, nh}}
					queue[#queue + 1] = {u, v, nh}
				end
			end
		end
	end
end

-- Engine reachability per scene (head room 1) and with head room 2.
local EXPECT = {
	open = {true, true}, trunk = {true, true}, trunk_near = {true, true},
	row = {true, true}, doorway = {true, true}, lcorner = {true, true},
	fence = {false, false}, fence_low = {true, true}, pillar = {true, true},
	ditch = {true, true}, step = {true, true}, lowgap = {true, true},
	pond = {true, true}, door_closed = {false, false},
	door_open = {false, false},
}

local names = {}
for _, scene in ipairs(scenes.list) do
	check(not names[scene.name], "duplicate scene " .. scene.name)
	names[scene.name] = true
	check(EXPECT[scene.name] ~= nil, scene.name .. ": no expectation")
	local s = {scene.start[1], scene.start[2], 1}
	local g = {scene.goal[1], scene.goal[2], scene.goal_h}
	local b = {scene.blocked[1], scene.blocked[2], scene.blocked[3] or 1}
	for label, cell in pairs({start = s, goal = g, blocked = b}) do
		check(not walkable(scene, cell[1], cell[2], cell[3])
			and not walkable(scene, cell[1], cell[2], cell[3] + 1)
			and walkable(scene, cell[1], cell[2], cell[3] - 1),
			scene.name .. ": " .. label .. " cell is not standable for a 2-node mob")
	end
	local e = EXPECT[scene.name] or {}
	local p1 = search(scene, s, g, 1)
	local p2 = search(scene, s, g, 2)
	check((p1 ~= nil) == e[1], scene.name .. ": engine-model reachability " ..
		tostring(p1 ~= nil) .. ", expected " .. tostring(e[1]))
	check((p2 ~= nil) == e[2], scene.name .. ": head-room reachability " ..
		tostring(p2 ~= nil) .. ", expected " .. tostring(e[2]))
	-- The straight line is blocked in every scene but the control and the step.
	local straight = true
	for u = 1, scenes.GOAL_U - 1 do
		local h = 1
		if scene.name == "step" and u >= 7 then h = 2 end
		if walkable(scene, u, 0, h) or walkable(scene, u, 0, h + 1)
				or not walkable(scene, u, 0, h - 1) then
			straight = false
		end
	end
	local open_line = scene.name == "open" or scene.name == "step"
	check(straight == open_line, scene.name .. ": straight line open = " ..
		tostring(straight))
	if scene.name == "lowgap" then
		-- The engine model goes through the 1-high hole on the line; with
		-- head room the search must use the 2-high gap at v 5 instead.
		local through = false
		for _, c in ipairs(p1 or {}) do
			if c[1] == 7 and c[2] == 0 then through = true end
		end
		check(through, "lowgap: the engine model should use the 1-high hole")
		local gap = false
		for _, c in ipairs(p2 or {}) do
			if c[1] == 7 then gap = c[2] == 5 end
		end
		check(gap, "lowgap: the head-room search should use the gap at v 5")
	end
end
check(#scenes.list == 15, "15 scenes, got " .. #scenes.list)

if failures > 0 then
	error(("R42 NV0 PORTABLE FAIL %d"):format(failures), 0)
end
print("r42_nv0 scenes: " .. #scenes.list .. " scenes OK")
