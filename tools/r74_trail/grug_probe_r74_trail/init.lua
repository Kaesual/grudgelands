-- Disposable engine probe of Round 74 lane TRAIL (round74-plan.md §4 TRAIL). Never
-- shipped: tools/r74_trail/run_probe.sh stages it through tools/luanti_headless.sh
-- (PROBE=), on this branch and on the base commit (GAME_PATCH= the reverse diff of
-- aggro.lua), with no client.
--
-- A walled arena is built in the air (floor at y 992, one mapblock layer, every
-- block forceloaded, so the mobs are active without a player). Twelve cells, six
-- scenes twice: a long wall, a pen open to the far side, a house with one door, a
-- ridge with one gap, a kite back and forth past a boulder, a platform with stairs
-- and a drop. In each a Bandit chases a decoy (an inert entity that walks a course
-- round the obstacle, waiting while the mob is more than 6 nodes behind); at the
-- course's end the mob gets the boss reset (grug_mobs.reset_home: healed, target
-- dropped, the evade home). Counted per cell: the chase held to the end, the trail's
-- points (branch), the evade's end: home (within 4.5 nodes, no teleport), the 40 s
-- teleport (grug_mobs.place_on_ground wrapped), or neither within 50 s.
local P = "[r74trail] "
local function log(fmt, ...) core.log("action", P .. fmt:format(...)) end

local FY = 992 -- the floor's y; the mobs stand on y 993
local X0, Z0 = 2000, 2000
local CELL, COLS, ROWS = 64, 4, 3
local SPEED = 3 -- the decoy's nodes per second
local WAIT_GAP = 6 -- the decoy waits while the mob is further behind

core.register_entity("grug_probe_r74_trail:decoy", {
	initial_properties = {
		physical = false, collide_with_objects = false, pointable = true,
		hp_max = 1000, visual = "cube", visual_size = {x = 0.4, y = 0.4},
		textures = {"default_stone.png", "default_stone.png", "default_stone.png",
			"default_stone.png", "default_stone.png", "default_stone.png"},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}, static_save = false,
	},
	on_activate = function(self) self.object:set_armor_groups({immortal = 1}) end,
	on_punch = function() return true end,
})

-- Scenes: walls (x1, z1, x2, z2, height; relative to the cell, on the floor), home,
-- course. Heights 3 (a mob steps up 1, jumps no wall).
local SCENES = {
	{name = "wall", walls = {{16, 2, 16, 50, 3}}, home = {10, 20},
		course = {{12, 20}, {12, 55}, {22, 55}, {22, 20}, {50, 20}}},
	{name = "pen", walls = {{24, 24, 36, 24, 3}, {24, 24, 24, 36, 3}, {36, 24, 36, 36, 3}},
		home = {30, 30}, course = {{30, 32}, {30, 42}, {44, 42}, {44, 14}, {30, 10}}},
	{name = "house", walls = {{20, 20, 30, 20, 3}, {20, 20, 20, 30, 3}, {30, 20, 30, 30, 3},
		{20, 30, 24, 30, 3}, {26, 30, 30, 30, 3}},
		home = {25, 25}, course = {{25, 27}, {25, 34}, {34, 34}, {34, 15}, {25, 12}, {25, 6}}},
	{name = "ridge", walls = {{2, 30, 49, 30, 3}, {52, 30, 61, 30, 3}},
		home = {10, 22}, course = {{12, 22}, {50.5, 22}, {50.5, 38}, {10, 38}}},
	{name = "kite", walls = {{29, 29, 31, 31, 3}},
		home = {10, 10}, course = {{12, 12}, {40, 40}, {20, 45}, {45, 20}, {25, 24}, {52, 52}}},
	{name = "ledge", walls = {{20, 20, 40, 30, 3}, {17, 24, 17, 26, 1}, {18, 24, 18, 26, 2},
		{19, 24, 19, 26, 3}},
		home = {8, 25}, course = {{10, 25}, {16, 25}, {38, 25}, {46, 25}, {56, 25}}},
}

local cells = {}
for row = 0, ROWS - 1 do
	for col = 0, COLS - 1 do
		local k = #cells
		cells[#cells + 1] = {scene = SCENES[k % #SCENES + 1], rep = math.floor(k / #SCENES) + 1,
			ox = X0 + col * CELL, oz = Z0 + row * CELL}
	end
end

local minp = {x = X0 - 16, y = FY - 16, z = Z0 - 16}
local maxp = {x = X0 + COLS * CELL + 15, y = FY + 31, z = Z0 + ROWS * CELL + 15}

local function build()
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(minp, maxp)
	local area = VoxelArea:new({MinEdge = e1, MaxEdge = e2})
	local data = vm:get_data()
	local stone, air = core.get_content_id("default:stone"), core.CONTENT_AIR
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			for y = FY - 1, FY + 8 do
				data[area:index(x, y, z)] = y <= FY and stone or air
			end
		end
	end
	for _, c in ipairs(cells) do
		for _, w in ipairs(c.scene.walls) do
			for x = math.min(w[1], w[3]), math.max(w[1], w[3]) do
				for z = math.min(w[2], w[4]), math.max(w[2], w[4]) do
					for h = 1, w[5] do data[area:index(c.ox + x, FY + h, c.oz + z)] = stone end
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
	local n = 0
	for x = minp.x, maxp.x, 16 do
		for z = minp.z, maxp.z, 16 do
			if core.forceload_block({x = x, y = FY, z = z}, true, -1) then n = n + 1 end
		end
	end
	log("built: %d cells, %d blocks forceloaded", #cells, n)
end

-- The feet height at (x, z): on the highest walkable node of the column.
local function feet(x, z)
	for y = FY + 6, FY - 1, -1 do
		local node = core.get_node({x = math.floor(x + 0.5), y = y, z = math.floor(z + 0.5)})
		local def = core.registered_nodes[node.name]
		if def and def.walkable then return y + 0.5 end
	end
	return FY + 0.5
end

local teleported = {}
local place = grug_mobs.place_on_ground
grug_mobs.place_on_ground = function(obj, pos)
	local ent = obj and obj:get_luaentity()
	if ent then teleported[ent] = true end
	return place(obj, pos)
end

local clock, phase, phase_at = 0, "emerge", 0
local emerged = false
local function hd(a, x, z)
	return math.sqrt((a.x - x) * (a.x - x) + (a.z - z) * (a.z - z))
end

local function spawn(c)
	local h = c.scene.home
	c.hx, c.hz = c.ox + h[1], c.oz + h[2]
	c.mob = core.add_entity({x = c.hx, y = feet(c.hx, c.hz), z = c.hz}, "grug_mobs:bandit")
	local s = c.scene.course[1]
	c.decoy = core.add_entity({x = c.ox + s[1], y = feet(c.ox + s[1], c.oz + s[2]),
		z = c.oz + s[2]}, "grug_probe_r74_trail:decoy")
	c.leg, c.stage = 2, "spawned"
end

local function step_cell(c, dtime)
	local ent = c.mob and c.mob:get_luaentity()
	if not ent then
		if c.stage ~= "done" then
			log("CELL %s rep %d: the mob is gone (%s)", c.scene.name, c.rep, c.stage)
			c.stage = "done"
		end
		return
	end
	local pos = c.mob:get_pos()
	if c.stage == "spawned" then
		ent._grug_no_leash = true
		ent._grug_home = {x = c.hx, y = feet(c.hx, c.hz), z = c.hz}
		ent:do_attack(c.decoy)
		c.stage, c.started, c.waited = "chase", clock, 0
		return
	end
	if c.stage == "chase" then
		local course = c.scene.course
		local goal = course[c.leg]
		local d = c.decoy:get_pos()
		if not goal then
			c.stage = "reset_wait"
			c.reset_at = clock + 1
			return
		end
		if hd(pos, d.x, d.z) > WAIT_GAP then
			c.waited = c.waited + dtime
			if c.waited > 20 then
				log("CELL %s rep %d: the mob lost the decoy", c.scene.name, c.rep)
				c.stage = "reset_wait"
				c.reset_at = clock
			end
			return
		end
		c.waited = 0
		local gx, gz = c.ox + goal[1], c.oz + goal[2]
		local dist = hd(d, gx, gz)
		local move = SPEED * dtime
		local nx, nz
		if dist <= move then
			nx, nz = gx, gz
			c.leg = c.leg + 1
		else
			nx, nz = d.x + (gx - d.x) / dist * move, d.z + (gz - d.z) / dist * move
		end
		c.decoy:set_pos({x = nx, y = feet(nx, nz), z = nz})
		return
	end
	if c.stage == "reset_wait" then
		if clock < c.reset_at then return end
		c.chase_held = ent.state == "attack" and ent.attack == c.decoy
		local tr = ent.temp and ent.temp.grug_evade_trail
		c.trail = grug_mobs.register_evade_guide and (tr and #tr or 0) or -1
		c.chase_s = clock - c.started
		c.from = hd(pos, c.hx, c.hz)
		grug_mobs.reset_home(ent)
		c.decoy:remove()
		c.stage, c.evade_at = "evade", clock
		if not (ent.temp and ent.temp.grug_evading) then
			log("CELL %s rep %d: no evade (%.1f from home)", c.scene.name, c.rep, c.from)
			c.stage = "done"
		end
		return
	end
	if c.stage == "evade" then
		local evading = ent.temp and ent.temp.grug_evading
		if evading and clock - c.evade_at < 50 then return end
		local result = teleported[ent] and "teleport" or evading and "timeout"
			or (hd(pos, c.hx, c.hz) <= 4.5 and "home" or "stopped")
		log("RESULT scene %s rep %d chase_held %s chase_s %.1f trail %d from %.1f result %s evade_s %.1f",
			c.scene.name, c.rep, tostring(c.chase_held), c.chase_s, c.trail, c.from, result,
			clock - c.evade_at)
		c.stage = "done"
	end
end

core.register_globalstep(function(dtime)
	clock = clock + dtime
	if phase == "emerge" then
		phase = "emerging"
		local t0 = clock
		core.emerge_area(minp, maxp, function(_, _, left)
			if left == 0 then
				emerged = true
				log("emerged in %.1f s", clock - t0)
			end
		end)
	elseif phase == "emerging" then
		if emerged then
			build()
			phase, phase_at = "settle", clock
		end
	elseif phase == "settle" then
		if clock - phase_at > 3 then
			for _, c in ipairs(cells) do spawn(c) end
			phase, phase_at = "run", clock
			log("spawned %d cells", #cells)
		end
	elseif phase == "run" then
		local open = 0
		for _, c in ipairs(cells) do
			if clock - phase_at > 0.5 then step_cell(c, dtime) end
			if c.stage ~= "done" then open = open + 1 end
		end
		if open == 0 or clock - phase_at > 170 then
			log("shutdown (%d open)", open)
			phase = "over"
			core.request_shutdown("probe done", false, 0)
		end
	end
end)
