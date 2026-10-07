-- Disposable Round 42 NV0 probe (tools/r42_nv0/run.sh). Never shipped.
--
-- Builds the navigation test scenes (scenes.lua) as side-by-side lanes on a
-- forceloaded stone floor high above deep ocean and drives REAL mobs on the
-- REAL code through them, one mover kind per batch (every lane at once):
--   combat  boar (the pig), wolf, bear (wide), bandit (tall): forced to attack
--           a punchable dummy standing on the goal;
--   post    an Accord guard whose post is the goal (start_post_tick);
--   follow  a royal guard whose leader (a stand-in with the king's fields)
--           waits on the goal (bosses.lua royal_guard_tick);
--   villager a walker whose second idle spot is the goal (amble_tick).
-- Per trial it records reached or not and when, every core.find_path call the
-- mob makes (count, found, cost, the largest), the stuck triggers today's code
-- fires (smart_mobs outcomes, sidesteps, give-ups, path nudges, snaps) and a
-- per-step track (position, commanded speed, attack/following flags, node
-- collisions) from which tools/r42_nv0/summarize.py derives the self-movement
-- ratios for the calibration.
--
-- Phases (setting grug_nv0_phases, comma separated, default "scenes"):
--   scenes    the batches above;
--   calib     find_path against padding and distance (the scenes, a flat
--             field with and without a path), the candidate fan, the
--             walkable-line test's cost, natural-terrain samples;
--   chasers40 Round 30's stress: 40 chasers round an enclosed target.
-- Results go to <world>/nv0_results.json; every log line carries "[nv0]".

local MOD = core.get_current_modname()
local MP = core.get_modpath(MOD)
local scenes = dofile(MP .. "/scenes.lua")
local P = "[nv0] "
local now = core.get_us_time
local function log(s) core.log("action", P .. s) end
local floor, sqrt, max, min, abs = math.floor, math.sqrt, math.max, math.min,
	math.abs

local PHASES = {}
for word in (core.settings:get("grug_nv0_phases") or "scenes"):gmatch("[%w_]+") do
	PHASES[#PHASES + 1] = word
end
-- Optional filters for a quick debug run: only these movers / scenes.
local function name_set(setting)
	local value = core.settings:get(setting)
	if not value or value == "" then return nil end
	local set = {}
	for word in value:gmatch("[%w_]+") do set[word] = true end
	return set
end
local ONLY_MOVERS = name_set("grug_nv0_movers")
local ONLY_SCENES = name_set("grug_nv0_scenes")

local results = {
	meta = {phases = PHASES, settings = {}},
	movers = {},
	trials = {},
	batches = {},
}

local function sanitize(value)
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		return value
	elseif kind == "table" then
		local out = {}
		for k, v in pairs(value) do out[k] = sanitize(v) end
		return out
	elseif kind == "string" or kind == "boolean" then
		return value
	end
	return nil
end

local function write_results()
	local path = core.get_worldpath() .. "/nv0_results.json"
	local text = core.write_json(sanitize(results))
	if not text or not core.safe_file_write(path, text) then
		core.log("error", P .. "could not write " .. path)
		return
	end
	log("wrote " .. path .. " (" .. #text .. " bytes)")
end

local function r2(value) return floor(value * 100 + 0.5) / 100 end

---------------------------------------------------------------------------
-- Instrumentation (wrappers around the real code; they only observe)
---------------------------------------------------------------------------
local mc = mobs.mob_class
local OB = mobs.grug_obstacle
local current -- the mob whose on_step runs right now
local tracked = setmetatable({}, {__mode = "k"}) -- luaentity -> trial record
local step_acc = {mob_us = 0, fp_n = 0, fp_us = 0}
local step_rows -- per-step rows of the batch being recorded (or nil)

local function trial_time(rec)
	return (now() - rec.t0) / 1e6
end

local function event(rec, kind, detail)
	if not rec.t0 then return end
	local row = {r2(trial_time(rec)), kind}
	if detail ~= nil then row[3] = detail end
	rec.events[#rec.events + 1] = row
end

local function count(rec, key, by)
	rec.counts[key] = (rec.counts[key] or 0) + (by or 1)
end

do
	local orig = mc.on_step
	mc.on_step = function(self, dtime, moveresult)
		local previous = current
		current = self
		local rec = tracked[self]
		if rec and moveresult and moveresult.collisions then
			for _, c in ipairs(moveresult.collisions) do
				if c.type == "node" and c.axis ~= "y" then
					rec.coll = true
				end
			end
		end
		local t0 = now()
		local r = orig(self, dtime, moveresult)
		local dt = now() - t0
		current = previous
		step_acc.mob_us = step_acc.mob_us + dt
		return r
	end
end

local orig_find_path = core.find_path
core.find_path = function(pos1, pos2, searchdistance, max_jump, max_drop, algo)
	local t0 = now()
	local path = orig_find_path(pos1, pos2, searchdistance, max_jump, max_drop,
		algo)
	local dt = now() - t0
	step_acc.fp_n = step_acc.fp_n + 1
	step_acc.fp_us = step_acc.fp_us + dt
	local rec = current and tracked[current]
	if rec and rec.t0 then
		local fp = rec.fp
		fp.n = fp.n + 1
		fp.us = fp.us + dt
		if dt > fp.max then fp.max = dt end
		if path then fp.found = fp.found + 1 end
		local d = abs(pos1.x - pos2.x) + abs(pos1.z - pos2.z)
		event(rec, "fp", {searchdistance, r2(d), path and #path or 0, dt})
	end
	return path
end

do
	local orig = mc.smart_mobs
	mc.smart_mobs = function(self, s, p, dist, dtime, force, visible)
		local r = orig(self, s, p, dist, dtime, force, visible)
		local rec = tracked[self]
		if rec and r and rec.t0 then
			local key = (force and "close_" or "chase_") .. r
			rec.sm[key] = (rec.sm[key] or 0) + 1
			event(rec, "sm", key)
		end
		return r
	end
end

do
	local orig = OB.note_path_result
	OB.note_path_result = function(temp, has_path)
		local rec = current and tracked[current]
		if rec and rec.t0 and not has_path then
			count(rec, "sidestep")
			event(rec, "sidestep")
		end
		return orig(temp, has_path)
	end
	local orig_exhausted = OB.note_exhausted_blocked_path
	OB.note_exhausted_blocked_path = function(temp)
		local rec = current and tracked[current]
		if rec and rec.t0 then
			count(rec, "path_exhausted")
			event(rec, "path_exhausted")
		end
		return orig_exhausted(temp)
	end
	local orig_claim = OB.claim_path_budget
	OB.claim_path_budget = function(temp)
		local ok, generation = orig_claim(temp)
		local rec = current and tracked[current]
		if rec and rec.t0 and not ok then count(rec, "budget_refused") end
		return ok, generation
	end
	local orig_spare = OB.spare_path_budget
	OB.spare_path_budget = function()
		local ok = orig_spare()
		local rec = current and tracked[current]
		if rec and rec.t0 and not ok then count(rec, "budget_refused") end
		return ok
	end
end

do
	local orig = mc.set_velocity
	mc.set_velocity = function(self, v)
		if tracked[self] then
			local value = v or 0.01
			if self.order == "stand" then value = 0 end
			self._nv0_cmd = value
		end
		return orig(self, v)
	end
end

-- grug_mobs wrappers. Installed at load: grug_mobs is a dependency, and its
-- callers look these up in the table at call time.
local re_engage -- set below (combat give-up emulation)
do
	local G = grug_mobs
	local orig_nudge = G.path_nudge
	G.path_nudge = function(self, x, z, pos)
		local ok = orig_nudge(self, x, z, pos)
		local rec = tracked[self]
		if rec and rec.t0 then
			count(rec, ok and "nudge_path" or "nudge_nopath")
			event(rec, ok and "nudge_path" or "nudge_nopath")
		end
		return ok
	end
	local orig_snap = G.snap_to
	G.snap_to = function(self, pos, x, z, after)
		local ok = orig_snap(self, pos, x, z, after)
		local rec = tracked[self]
		if rec and rec.t0 and ok then
			count(rec, "snap")
			event(rec, "snap")
		end
		return ok
	end
	local orig_place = G.place_on_ground
	G.place_on_ground = function(obj, pos)
		local ent = obj and obj.get_luaentity and obj:get_luaentity()
		local rec = ent and tracked[ent]
		if rec and rec.t0 then
			count(rec, "teleport")
			event(rec, "teleport")
		end
		return orig_place(obj, pos)
	end
	local orig_give_up = G.give_up_target
	G.give_up_target = function(self)
		local rec = tracked[self]
		if rec and rec.t0 then
			count(rec, "give_up")
			event(rec, "give_up")
		end
		orig_give_up(self)
		if rec and rec.t0 and re_engage then re_engage(rec) end
	end
	local orig_leash = G.leash_reset
	G.leash_reset = function(self)
		local rec = tracked[self]
		if rec and rec.t0 then count(rec, "leash_reset") end
		return orig_leash(self)
	end
	local orig_stall = G.stall_clock
	G.stall_clock = function(self, x, z, pos, elapsed)
		local stalled, total = orig_stall(self, x, z, pos, elapsed)
		local rec = tracked[self]
		if rec and rec.t0 then
			if stalled > (rec.stall_max or 0) then rec.stall_max = stalled end
		end
		return stalled, total
	end
end

---------------------------------------------------------------------------
-- Entities: the punchable target and the royal leader stand-in
---------------------------------------------------------------------------
local hits = setmetatable({}, {__mode = "k"}) -- dummy luaentity -> trial rec

core.register_entity(MOD .. ":dummy", {
	initial_properties = {
		physical = true, collide_with_objects = false, static_save = false,
		hp_max = 1000, visual = "cube",
		textures = {"default_stone.png", "default_stone.png", "default_stone.png",
			"default_stone.png", "default_stone.png", "default_stone.png"},
		visual_size = {x = 0.6, y = 1.77},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3},
	},
	on_punch = function(self, puncher)
		local rec = hits[self]
		if rec and rec.t0 and puncher and rec.obj and puncher == rec.obj then
			if not rec.hit_t then
				rec.hit_t = r2(trial_time(rec))
				event(rec, "hit")
			end
			count(rec, "hits")
		end
		return true
	end,
})

core.register_entity(MOD .. ":leader", {
	initial_properties = {
		physical = false, static_save = false, hp_max = 1000, visual = "cube",
		textures = {"default_gold_block.png", "default_gold_block.png",
			"default_gold_block.png", "default_gold_block.png",
			"default_gold_block.png", "default_gold_block.png"},
		visual_size = {x = 0.6, y = 1.9},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.9, 0.3},
		pointable = false,
	},
	on_punch = function() return true end,
})

---------------------------------------------------------------------------
-- The arena
---------------------------------------------------------------------------
local FLOOR_Y = 300 -- y of the floor's top node
local LANES_X = 10 -- arena x of u = 0
local LANE_Z0 = 14 -- arena z of lane 1's v = 0
local FIELD_X, FIELD_Z, FIELD_W = 44, 4, 100 -- the flat calibration field
local ARENA_W, ARENA_D = 148, 380
local origin

local function lane_count() return #scenes.list end

local function lane_base(index)
	return origin.x + LANES_X, origin.z + LANE_Z0 + (index - 1) * scenes.LANE_PITCH
end

-- World position of lane cell (u, v, h): the node's centre.
local function cell_pos(index, u, v, h)
	local x, z = lane_base(index)
	return {x = x + u, y = FLOOR_Y + h, z = z + v}
end

local function find_origin()
	for r = 0, 40 do
		for i = -r, r do
			for _, c in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = c[1] * 256, c[2] * 256
				local ok = true
				for _, d in ipairs({{0, 0}, {ARENA_W, 0}, {0, ARENA_D},
						{ARENA_W, ARENA_D}, {0, ARENA_D / 2}, {ARENA_W, ARENA_D / 2}}) do
					if grug_zones.water_class_at(x + d[1], z + d[2]) ~= "deep_ocean" then
						ok = false
						break
					end
				end
				if ok then return vector.new(x, 0, z) end
			end
		end
	end
end

local NODES = {
	solid = "default:stone",
	trunk = "default:tree",
	fence = "default:fence_wood",
	water = "default:water_source",
	air = "air",
}

local function arena_box()
	return vector.new(origin.x, FLOOR_Y + scenes.FLOOR_DEPTH - 1, origin.z),
		vector.new(origin.x + ARENA_W - 1, FLOOR_Y + 8, origin.z + ARENA_D - 1)
end

local function place_door(index, u, v, open)
	local pos = cell_pos(index, u, v, 1)
	-- param2 1: the panel spans v, so it closes a lane walked along u.
	core.set_node(pos, {name = "doors:door_wood_a", param2 = 1})
	core.set_node(vector.offset(pos, 0, 1, 0), {name = "doors:hidden", param2 = 1})
	core.get_meta(pos):set_int("state", 0)
	if open then
		local door = doors.get(pos)
		local ok = door and door:open(nil)
		log(("door lane %d open -> %s (%s)"):format(index, tostring(ok),
			core.get_node(pos).name))
	end
end

local function build_arena()
	local minp, maxp = arena_box()
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c = {}
	for kind, name in pairs(NODES) do c[kind] = core.get_content_id(name) end
	local top = FLOOR_Y
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local rim = x == minp.x or x == maxp.x or z == minp.z or z == maxp.z
			for y = minp.y, maxp.y do
				local id = c.air
				if y <= top and y >= top + scenes.FLOOR_DEPTH then id = c.solid
				elseif rim and y <= top + 3 then id = c.solid end
				data[area:index(x, y, z)] = id
			end
		end
	end
	-- Lane separators (3 high) at v = +-(LANE_HALF + 1) and the lane ends.
	local half = scenes.LANE_HALF
	for index = 1, lane_count() do
		local bx, bz = lane_base(index)
		for u = -scenes.LANE_BACK - 1, scenes.LANE_FRONT + 1 do
			for _, v in ipairs({-half - 1, half + 1}) do
				for h = 1, 3 do data[area:index(bx + u, top + h, bz + v)] = c.solid end
			end
		end
		for v = -half - 1, half + 1 do
			for _, u in ipairs({-scenes.LANE_BACK - 1, scenes.LANE_FRONT + 1}) do
				for h = 1, 3 do data[area:index(bx + u, top + h, bz + v)] = c.solid end
			end
		end
		local scene = scenes.list[index]
		for _, op in ipairs(scene.ops) do
			if op[1] == "fill" then
				local id = c[op[2]]
				for u = min(op[3], op[6]), max(op[3], op[6]) do
					for v = min(op[4], op[7]), max(op[4], op[7]) do
						for h = min(op[5], op[8]), max(op[5], op[8]) do
							data[area:index(bx + u, top + h, bz + v)] = id
						end
					end
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
	for index, scene in ipairs(scenes.list) do
		for _, op in ipairs(scene.ops) do
			if op[1] == "door" then place_door(index, op[2], op[3], op[4]) end
		end
	end
end

-- The calibration field: an open floor (already laid by build_arena) with two
-- rows; row B gets a closed stone box round every goal (no path).
local FIELD_D = {8, 12, 16, 24, 32}
local function field_pos(dx, dz, h)
	return {x = origin.x + FIELD_X + dx, y = FLOOR_Y + (h or 1),
		z = origin.z + FIELD_Z + dz}
end
local FIELD_START_X, ROW_A, ROW_B = 30, 25, 75

local function build_field_boxes()
	for _, d in ipairs(FIELD_D) do
		local g = field_pos(FIELD_START_X + d, ROW_B)
		for dx = -1, 1 do
			for dz = -1, 1 do
				for dy = 0, 2 do
					local p = {x = g.x + dx, y = g.y + dy, z = g.z + dz}
					if dx ~= 0 or dz ~= 0 or dy == 2 then
						core.set_node(p, {name = "default:stone"})
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Node helpers (calibration)
---------------------------------------------------------------------------
local get_node = core.get_node
local function walkable(x, y, z)
	local node = get_node({x = x, y = y, z = z})
	if node.name == "ignore" then return true end
	local def = core.registered_nodes[node.name]
	return not def or def.walkable == true
end
local function liquid(x, y, z)
	local def = core.registered_nodes[get_node({x = x, y = y, z = z}).name]
	return def and def.liquidtype and def.liquidtype ~= "none"
end
-- Feet cell (x, y, z) free for a mob `height` cells tall, ground below it.
local function standable(x, y, z, height)
	for dy = 0, (height or 2) - 1 do
		if walkable(x, y + dy, z) then return false end
	end
	if liquid(x, y, z) then return false end
	return walkable(x, y - 1, z)
end
local function find_standable(x, z, y0, band, height)
	if standable(x, y0, z, height) then return y0 end
	for dy = 1, band do
		if standable(x, y0 + dy, z, height) then return y0 + dy end
		if standable(x, y0 - dy, z, height) then return y0 - dy end
	end
end

-- A prototype of ruling 7's walkable-line test, for its cost and for the
-- scene geometry only (NV1 builds the real one): samples every half node,
-- each sample and its two side points (half width `w`) must be standable for
-- `height`, within `step` up and `drop` down of the previous sample.
local function line_walkable(a, b, height, w, step, drop)
	local dx, dz = b.x - a.x, b.z - a.z
	local len = sqrt(dx * dx + dz * dz)
	if len < 0.01 then return true end
	local n = math.ceil(len / 0.5)
	local px, pz = -dz / len * w, dx / len * w
	local y = a.y
	for i = 1, n do
		local x, z = a.x + dx * i / n, a.z + dz * i / n
		local found
		for dy = step, -drop, -1 do
			local yy = y + dy
			if standable(floor(x + 0.5), yy, floor(z + 0.5), height)
					and (w <= 0 or (standable(floor(x + px + 0.5), yy, floor(z + pz + 0.5), height)
					and standable(floor(x - px + 0.5), yy, floor(z - pz + 0.5), height))) then
				found = yy
				break
			end
		end
		if not found then return false end
		y = found
	end
	return true
end

local function median(values)
	local s = {}
	for i = 1, #values do s[i] = values[i] end
	table.sort(s)
	if #s == 0 then return nil end
	return s[math.ceil(#s / 2)]
end

local function pct(sorted, p)
	if #sorted == 0 then return nil end
	return sorted[max(1, min(#sorted, math.ceil(#sorted * p)))]
end

local function timed_path(a, b, pad, jump, drop, reps)
	local costs, path = {}, nil
	for i = 1, reps or 3 do
		local t0 = now()
		path = orig_find_path(a, b, pad, jump or 1, drop or 6, "A*_noprefetch")
		costs[i] = now() - t0
	end
	return path, median(costs), costs
end

-- Head-room and width violations of an engine path (ruling 6), for a mob
-- `height` cells tall and, separately, a mob wider than one node.
local function path_violations(path, height)
	local head, wide = 0, 0
	for i = 1, #path do
		local p = path[i]
		for dy = 1, height - 1 do
			if walkable(p.x, p.y + dy, p.z) then head = head + 1; break end
		end
		local q = path[i + 1] or path[i - 1]
		if q then
			local sx, sz = q.z - p.z, q.x - p.x -- perpendicular of the step
			if (sx ~= 0 or sz ~= 0) and (walkable(p.x + sx, p.y, p.z + sz)
					or walkable(p.x - sx, p.y, p.z - sz)) then
				wide = wide + 1
			end
		end
	end
	return head, wide
end

---------------------------------------------------------------------------
-- Movers and batches
---------------------------------------------------------------------------
local RACES = {"human", "elf", "dwarf", "orc", "troll", "undead"}
local function first_race(prefix)
	for _, race in ipairs(RACES) do
		if core.registered_entities[prefix .. race] then return race end
	end
end

local MOVERS = {
	{id = "boar", kind = "combat", entity = "grug_mobs:boar", T = 20,
		note = "the pig (0.9 wide)"},
	{id = "wolf", kind = "combat", entity = "grug_mobs:wolf", T = 20,
		note = "narrow chaser"},
	{id = "bear", kind = "combat", entity = "grug_mobs:bear", T = 20,
		note = "wide mob (1.4)"},
	{id = "bandit", kind = "combat", entity = "grug_mobs:bandit", T = 20,
		note = "tall mob (1.7)"},
	{id = "post_guard", kind = "post", entity = "grug_mobs:guard_accord", T = 45,
		note = "a fixed walk back to its post (start_post_tick)"},
	{id = "royal_guard", kind = "follow", entity = "grug_mobs:royal_guard_", T = 30,
		note = "follows an idle leader on the goal (royal_guard_tick)"},
	{id = "villager", kind = "villager", entity = "grug_mobs:villager_", T = 30,
		note = "a walker whose next idle spot is the goal (amble_tick)"},
}
local ARRIVE = {post = 2, follow = 5, villager = 1.6}

local active = {} -- trial records of the running batch

local function lane_selected(scene)
	return not ONLY_SCENES or ONLY_SCENES[scene.name]
end

local function clear_arena_objects()
	local minp, maxp = arena_box()
	for _, obj in ipairs(core.get_objects_in_area(vector.offset(minp, -2, -4, -2),
			vector.offset(maxp, 2, 8, 2))) do
		if not obj:is_player() then obj:remove() end
	end
end

local function spawn_at(name, pos)
	local obj = core.add_entity(pos, name)
	if not obj then return end
	local ent = obj:get_luaentity()
	if not ent then return end
	return obj, ent
end

local function feet(pos)
	return {x = pos.x, y = pos.y - 0.5, z = pos.z}
end

local function horizontal(a, b)
	local dx, dz = a.x - b.x, a.z - b.z
	return sqrt(dx * dx + dz * dz)
end

local function mover_entity(mover, lane)
	if mover.kind == "follow" then
		-- Same-race lanes sit 6 pitches (144 nodes) apart: beyond the guard's
		-- 80-node leader scan, so every guard follows its own lane's leader.
		local race = RACES[(lane - 1) % #RACES + 1]
		if not core.registered_entities[mover.entity .. race] then
			race = first_race(mover.entity)
		end
		return mover.entity .. race, race
	elseif mover.kind == "villager" then
		local race = first_race(mover.entity)
		return mover.entity .. race, race
	end
	return mover.entity
end

local function new_rec(mover, scene, lane)
	return {mover = mover.id, kind = mover.kind, scene = scene.name, lane = lane,
		track = {}, events = {}, fp = {n = 0, found = 0, us = 0, max = 0},
		sm = {}, counts = {}, cycles = 0}
end

-- Combat give-up: a player that moves one node is acquired again; the dummy
-- steps one node (alternating) and the mob is sent at it after 1 s.
re_engage = function(rec)
	if rec.kind ~= "combat" then return end
	rec.cycles = rec.cycles + 1
	core.after(1, function()
		if not rec.t0 or rec.done then return end
		local dummy, ent = rec.dummy, rec.ent
		if not dummy or not dummy:get_pos() or not ent or not ent.object
				or not ent.object:get_pos() then
			return
		end
		local shift = (rec.cycles % 2 == 1) and 1 or -1
		local g = cell_pos(rec.lane, scenes.GOAL_U, shift == 1 and 1 or 0,
			rec.goal_h)
		dummy:set_pos(feet(g))
		rec.goal = feet(g)
		event(rec, "re_engage", rec.cycles)
		ent:do_attack(dummy, true)
	end)
end

local function start_trial(rec, mover)
	local ent, obj = rec.ent, rec.obj
	if not ent or not obj or not obj:get_pos() then
		rec.lost = true
		return
	end
	local scene = scenes.by_name(rec.scene)
	local s = cell_pos(rec.lane, scene.start[1], scene.start[2], 1)
	local g = cell_pos(rec.lane, scene.goal[1], scene.goal[2], scene.goal_h)
	rec.goal_h = scene.goal_h
	grug_mobs.place_on_ground(obj, feet(s))
	obj:set_velocity({x = 0, y = 0, z = 0})
	ent:set_yaw(-math.pi / 2, 0) -- facing +x (mobs_redo yaw 0 faces +z)
	rec.goal = feet(g)
	if mover.kind == "combat" then
		local dummy = core.add_entity(feet(g), MOD .. ":dummy")
		rec.dummy = dummy
		local dent = dummy and dummy:get_luaentity()
		if dent then hits[dent] = rec end
		rec.t0 = now()
		ent:do_attack(dummy, true)
	elseif mover.kind == "post" then
		ent._grug_post_x, ent._grug_post_z, ent._grug_post_yaw = g.x, g.z, 0
		rec.t0 = now()
	elseif mover.kind == "follow" then
		local leader = core.add_entity(feet(g), MOD .. ":leader")
		local lent = leader and leader:get_luaentity()
		if lent then
			lent._grug_boss_id = "king:" .. rec.race
			lent._grug_royal_king = true
		end
		rec.leader = leader
		rec.t0 = now()
	elseif mover.kind == "villager" then
		ent._grug_idle_spots = {
			{x = s.x, z = s.z, yaw = 0},
			{x = g.x, z = g.z, yaw = 0},
		}
		ent._grug_walker = true
		ent._grug_idle_spot = 2
		ent._grug_idle_dwell = nil
		rec.spot = 2
		rec.t0 = now()
	end
	ent._nv0_cmd = 0
end

local function sample(rec)
	if not rec.t0 or rec.done then return end
	local obj = rec.obj
	local pos = obj and obj:get_pos()
	if not pos then
		if not rec.lost then
			rec.lost = true
			event(rec, "lost")
		end
		return
	end
	local ent = rec.ent
	local t = trial_time(rec)
	local bx, bz = lane_base(rec.lane)
	local flags = 0
	if ent.state == "attack" then flags = flags + 1 end
	if ent.path and ent.path.following then flags = flags + 2 end
	if rec.coll then flags = flags + 4 end
	if ent.temp and ent.temp.grug_evading then flags = flags + 8 end
	rec.coll = false
	local cmd = ent._nv0_cmd or 0
	rec.track[#rec.track + 1] = {r2(t), r2(pos.x - bx), r2(pos.z - bz),
		r2(pos.y - FLOOR_Y - 0.5), r2(cmd), flags}
	local d = horizontal(pos, rec.goal)
	if not rec.min_d or d < rec.min_d then rec.min_d = d end
	local radius = ARRIVE[rec.kind]
	if radius and not rec.arrive_t and d <= radius then
		rec.arrive_t = r2(t)
		event(rec, "arrive")
	end
	for _, r in ipairs({1.5, 3, 5}) do
		local key = "t_within_" .. r
		if not rec[key] and d <= r then rec[key] = r2(t) end
	end
	if rec.kind == "villager" and ent._grug_idle_spot ~= rec.spot then
		if not rec.arrive_t then
			count(rec, "villager_next_spot")
			event(rec, "next_spot", ent._grug_idle_spot)
		end
		rec.spot = ent._grug_idle_spot
	end
end

core.register_globalstep(function()
	if step_rows then
		step_rows[#step_rows + 1] = {step_acc.mob_us, step_acc.fp_n, step_acc.fp_us}
	end
	step_acc.mob_us, step_acc.fp_n, step_acc.fp_us = 0, 0, 0
	for i = 1, #active do sample(active[i]) end
end)

local function finish_trial(rec, mover)
	rec.done = true
	local reached
	if rec.kind == "combat" then
		reached = rec.hit_t ~= nil
	else
		reached = rec.arrive_t ~= nil
	end
	local row = {
		scene = rec.scene, mover = rec.mover, kind = rec.kind, lane = rec.lane,
		entity = rec.entity, T = mover.T, reached = reached,
		t_goal = rec.kind == "combat" and rec.hit_t or rec.arrive_t,
		t_within_1_5 = rec["t_within_1.5"], t_within_3 = rec.t_within_3,
		t_within_5 = rec.t_within_5, min_d = rec.min_d and r2(rec.min_d),
		searches = rec.fp.n, found = rec.fp.found, search_us = rec.fp.us,
		search_max_us = rec.fp.max, smart_mobs = rec.sm, counts = rec.counts,
		stall_max = rec.stall_max and r2(rec.stall_max), cycles = rec.cycles,
		lost = rec.lost, events = rec.events, track = rec.track,
	}
	results.trials[#results.trials + 1] = row
	local sm = {}
	for k, v in pairs(rec.sm) do sm[#sm + 1] = k .. "=" .. v end
	table.sort(sm)
	local cn = {}
	for k, v in pairs(rec.counts) do cn[#cn + 1] = k .. "=" .. v end
	table.sort(cn)
	log(("TRIAL %-11s %-11s reached=%-5s t=%-6s min_d=%-5s fp=%d found=%d us=%d max=%d sm[%s] %s"):format(
		rec.mover, rec.scene, tostring(reached), tostring(row.t_goal),
		tostring(row.min_d), rec.fp.n, rec.fp.found, rec.fp.us, rec.fp.max,
		table.concat(sm, " "), table.concat(cn, " ")))
end

local function batch_summary(mover, rows, seconds)
	local mob, fpn, fpus = {}, 0, 0
	local fpmax = 0
	for i = 1, #rows do
		mob[i] = rows[i][1]
		fpn = fpn + rows[i][2]
		fpus = fpus + rows[i][3]
		if rows[i][3] > fpmax then fpmax = rows[i][3] end
	end
	table.sort(mob)
	local summary = {mover = mover, steps = #rows, seconds = r2(seconds),
		mob_us_p50 = pct(mob, 0.5), mob_us_p90 = pct(mob, 0.9),
		mob_us_p99 = pct(mob, 0.99), mob_us_max = mob[#mob],
		fp_calls = fpn, fp_us = fpus, fp_max_step_us = fpmax}
	results.batches[#results.batches + 1] = summary
	log(("BATCH %s steps=%d mob_us p50=%s p99=%s max=%s fp_calls=%d fp_us=%d"):format(
		mover, #rows, tostring(summary.mob_us_p50), tostring(summary.mob_us_p99),
		tostring(summary.mob_us_max), fpn, fpus))
end

local function run_batch(mover, done)
	clear_arena_objects()
	core.set_timeofday(0.45)
	active = {}
	local recs = {}
	for lane, scene in ipairs(scenes.list) do
		if lane_selected(scene) then
			local name, race = mover_entity(mover, lane)
			local s = cell_pos(lane, scene.start[1], scene.start[2], 1)
			local obj, ent = spawn_at(name, feet(s))
			local rec = new_rec(mover, scene, lane)
			rec.entity, rec.race = name, race
			if obj then
				rec.obj, rec.ent = obj, ent
				if mover.kind == "combat" then ent._grug_level = 10 end
				tracked[ent] = rec
			else
				rec.lost = true
				log("could not spawn " .. tostring(name))
			end
			recs[#recs + 1] = rec
		end
	end
	-- One second for activation (levels, tiers, visuals), then the start.
	core.after(1, function()
		for _, rec in ipairs(recs) do
			local ok, err = pcall(start_trial, rec, mover)
			if not ok then core.log("error", P .. "start " .. rec.scene .. ": " .. tostring(err)) end
			active[#active + 1] = rec
		end
		-- The mover's live dimensions, once.
		local probe = recs[1] and recs[1].ent
		if probe and probe.object and not results.movers[mover.id] then
			local box = probe._grug_cbox or probe.object:get_properties().collisionbox
			results.movers[mover.id] = {entity = recs[1].entity, kind = mover.kind,
				note = mover.note, T = mover.T,
				width = r2(box[4] - box[1]), height = r2(box[5] - box[2]),
				walk_velocity = probe.walk_velocity, run_velocity = probe.run_velocity,
				stepheight = probe.object:get_properties().stepheight,
				jump_height = probe.jump_height, fear_height = probe.fear_height,
				reach = probe.reach, floats = probe.floats, pathfinding = probe.pathfinding,
				tier = probe._grug_tier}
			log(("MOVER %s %s width=%.2f height=%.2f walk=%s run=%s step=%s"):format(
				mover.id, recs[1].entity, box[4] - box[1], box[5] - box[2],
				tostring(probe.walk_velocity), tostring(probe.run_velocity),
				tostring(probe.object:get_properties().stepheight)))
		end
		step_rows = {}
		local t_start = now()
		core.after(mover.T, function()
			local rows = step_rows
			step_rows = nil
			for _, rec in ipairs(recs) do
				local ok, err = pcall(finish_trial, rec, mover)
				if not ok then core.log("error", P .. "finish " .. rec.scene .. ": " .. tostring(err)) end
				if rec.ent then tracked[rec.ent] = nil end
			end
			active = {}
			batch_summary(mover.id, rows, (now() - t_start) / 1e6)
			clear_arena_objects()
			write_results()
			core.after(0.5, done)
		end)
	end)
end

local function phase_scenes(done)
	local queue = {}
	for _, mover in ipairs(MOVERS) do
		if not ONLY_MOVERS or ONLY_MOVERS[mover.id] then queue[#queue + 1] = mover end
	end
	local i = 0
	local function next_batch()
		i = i + 1
		local mover = queue[i]
		if not mover then return done() end
		log("batch " .. mover.id)
		run_batch(mover, next_batch)
	end
	next_batch()
end

---------------------------------------------------------------------------
-- Calibration
---------------------------------------------------------------------------
local calib = {}
results.calib = calib
local PADS = {1, 2, 3, 4, 6, 8, 12, 16, 24}

-- C1: every scene, from its start and from its blocked cell to the goal,
-- against the padding; head-room/width violations of the found path; the
-- smallest fan radius that clears the obstacle (rings and the evade search).
local FAN_ANGLES = {0, 30, -30, 60, -60, 90, -90}
local FAN_RADII = {2, 3, 4, 5, 6, 8, 10}

local function fan_clear(index, from, to, w, band)
	-- The smallest radius r for which a candidate (standable within band,
	-- in the goal's direction, reachable with padding 4) has a walkable
	-- straight line on to the goal.
	local dx, dz = to.x - from.x, to.z - from.z
	local base = math.atan2(dz, dx)
	for _, r in ipairs(FAN_RADII) do
		for _, a in ipairs(FAN_ANGLES) do
			local ang = base + a * math.pi / 180
			local cx = floor(from.x + math.cos(ang) * r + 0.5)
			local cz = floor(from.z + math.sin(ang) * r + 0.5)
			local cy = find_standable(cx, cz, from.y, band, 2)
			if cy then
				local cand = {x = cx, y = cy, z = cz}
				if line_walkable(cand, to, 2, w, 1, 2) then
					local path = orig_find_path(from, cand, 4, 1, 6, "A*_noprefetch")
					if path then return r, a end
				end
			end
		end
	end
end

local function calib_scenes()
	local rows = {}
	for index, scene in ipairs(scenes.list) do
		local g = cell_pos(index, scene.goal[1], scene.goal[2], scene.goal_h)
		local starts = {
			{"start", cell_pos(index, scene.start[1], scene.start[2], 1)},
			{"blocked", cell_pos(index, scene.blocked[1], scene.blocked[2],
				scene.blocked[3] or 1)},
		}
		for _, pair in ipairs(starts) do
			local which, s = pair[1], pair[2]
			local row = {scene = scene.name, from = which, pads = {}}
			for _, pad in ipairs(PADS) do
				local path, cost = timed_path(s, g, pad, 1, 6, 3)
				local cell = {pad = pad, found = path ~= nil, us = cost,
					len = path and #path or 0}
				if path then
					cell.head2, cell.wide = path_violations(path, 2)
					cell.head3 = path_violations(path, 3)
				end
				row.pads[#row.pads + 1] = cell
				if path and not row.min_pad then row.min_pad = pad end
			end
			row.line_clear = line_walkable(s, g, 2, 0.3, 1, 2)
			row.fan_r_narrow, row.fan_a_narrow = fan_clear(index, s, g, 0.3, 2)
			row.fan_r_wide, row.fan_a_wide = fan_clear(index, s, g, 0.7, 2)
			rows[#rows + 1] = row
			log(("C1 %-11s from=%-7s min_pad=%s fan_r narrow=%s wide=%s"):format(
				scene.name, which, tostring(row.min_pad), tostring(row.fan_r_narrow),
				tostring(row.fan_r_wide)))
		end
	end
	calib.scenes = rows
end

-- C2: the flat field: found (row A, open) and not found (row B, boxed goal)
-- against distance and padding.
local FIELD_PADS = {2, 4, 6, 8, 12, 16, 24}
local function calib_field()
	build_field_boxes()
	local rows = {}
	for _, d in ipairs(FIELD_D) do
		for _, pad in ipairs(FIELD_PADS) do
			local sa = field_pos(FIELD_START_X, ROW_A)
			local ga = field_pos(FIELD_START_X + d, ROW_A)
			local pa, ca, all_a = timed_path(sa, ga, pad, 1, 6, 5)
			local sb = field_pos(FIELD_START_X, ROW_B)
			local gb = field_pos(FIELD_START_X + d, ROW_B)
			local pb, cb, all_b = timed_path(sb, gb, pad, 1, 6, 5)
			-- a diagonal leg (d along both axes / sqrt 2)
			local k = floor(d / 1.4142 + 0.5)
			local gd = field_pos(FIELD_START_X + k, ROW_A + k)
			local pd, cd = timed_path(sa, gd, pad, 1, 6, 5)
			table.sort(all_a)
			table.sort(all_b)
			rows[#rows + 1] = {d = d, pad = pad,
				found_us = ca, found_max = all_a[#all_a], found_ok = pa ~= nil,
				diag_us = cd, diag_ok = pd ~= nil,
				nopath_us = cb, nopath_max = all_b[#all_b], nopath_ok = pb == nil,
				box_cells = (d + 2 * pad + 1) * (2 * pad + 1)}
			log(("C2 d=%2d pad=%2d found %6d us (%s) diag %6d us  nopath %7d us (max %d)"):format(
				d, pad, ca, tostring(pa ~= nil), cd, cb, all_b[#all_b]))
		end
	end
	calib.field = rows
end

-- C3: the walkable-line prototype's cost (field, open line).
local function calib_line()
	local rows = {}
	for _, d in ipairs({8, 16, 32}) do
		local a = field_pos(FIELD_START_X, ROW_A)
		local b = field_pos(FIELD_START_X + d, ROW_A + floor(d / 3))
		local n = 300
		local t0 = now()
		local ok
		for _ = 1, n do ok = line_walkable(a, b, 2, 0.3, 1, 2) end
		local us = (now() - t0) / n
		rows[#rows + 1] = {d = d, us = r2(us), clear = ok}
		log(("C3 line test d=%d %.1f us (clear=%s)"):format(d, us, tostring(ok)))
	end
	calib.line = rows
end

-- C4: natural terrain. Land points with a spawn recipe, emerged around them:
-- found paths against distance with padding 4 and 24, and the candidate fan
-- (rings 4/6/10/16, height bands 1/2/3).
local LAND_N = 4
local LAND_R = 36
local land_points = {}

local function random_land()
	local SR = grug_mobs.spawn_regions
	for _ = 1, 20000 do
		local x, z = math.random(-4000, 4000), math.random(-4000, 4000)
		local zone = grug_zones.id_at(x, z)
		if zone and SR.zone_has_recipe(zone) then
			local h = grug_zones.terrain_height_at(x, z)
			if h and h >= 4 and h <= 120 then
				return {x = x, y = h, z = z, zone = zone}
			end
		end
	end
end

local function emerge_land(done)
	math.randomseed(4242)
	for i = 1, LAND_N do land_points[i] = random_land() end
	local pending = 0
	local t0 = now()
	for _, p in ipairs(land_points) do
		pending = pending + 1
		core.emerge_area({x = p.x - LAND_R - 8, y = p.y - 24, z = p.z - LAND_R - 8},
			{x = p.x + LAND_R + 8, y = p.y + 24, z = p.z + LAND_R + 8},
			function(_, _, remaining)
				if remaining == 0 then
					pending = pending - 1
					if pending == 0 then
						log(("land emerged in %.1f s"):format((now() - t0) / 1e6))
						done()
					end
				end
			end)
	end
	if pending == 0 then done() end
end

local function land_start(p)
	-- The surface standing cell nearest the recorded terrain height.
	for dy = 0, 20 do
		for _, y in ipairs({p.y + 1 + dy, p.y + 1 - dy}) do
			if standable(p.x, y, p.z, 2) then
				local below = get_node({x = p.x, y = y - 1, z = p.z}).name
				if core.get_item_group(below, "leaves") == 0
						and core.get_item_group(below, "tree") == 0 then
					return {x = p.x, y = y, z = p.z}
				end
			end
		end
	end
end

local function calib_land()
	local found_rows, fan_rows = {}, {}
	local DIRS = 8
	for li, p in ipairs(land_points) do
		local s = land_start(p)
		if not s then
			log("C4 land " .. li .. " no start cell")
		else
			log(("C4 land %d at %d,%d,%d zone %s"):format(li, s.x, s.y, s.z, p.zone))
			for _, d in ipairs({8, 12, 16, 24, 32}) do
				for k = 0, DIRS - 1 do
					local ang = k * 2 * math.pi / DIRS
					local tx = floor(s.x + math.cos(ang) * d + 0.5)
					local tz = floor(s.z + math.sin(ang) * d + 0.5)
					local ty = find_standable(tx, tz, s.y, 8, 2)
					local row = {land = li, d = d, dir = k, target = ty ~= nil}
					if ty then
						local t = {x = tx, y = ty, z = tz}
						local p4, c4 = timed_path(s, t, 4, 1, 6, 1)
						local p24, c24 = timed_path(s, t, 24, 1, 6, 1)
						row.dy = ty - s.y
						row.ok4, row.us4, row.len4 = p4 ~= nil, c4, p4 and #p4 or 0
						row.ok24, row.us24, row.len24 = p24 ~= nil, c24, p24 and #p24 or 0
						row.line = line_walkable(s, t, 2, 0.3, 1, 6)
					end
					found_rows[#found_rows + 1] = row
				end
			end
			for _, r in ipairs({4, 6, 10, 16}) do
				for _, band in ipairs({1, 2, 3}) do
					for k = 0, DIRS - 1 do
						local base = k * 2 * math.pi / DIRS
						local row = {land = li, r = r, band = band, dir = k}
						for _, a in ipairs({0, 20, -20, 40, -40}) do
							local ang = base + a * math.pi / 180
							local cx = floor(s.x + math.cos(ang) * r + 0.5)
							local cz = floor(s.z + math.sin(ang) * r + 0.5)
							local t0 = now()
							local cy = find_standable(cx, cz, s.y, band, 2)
							row.check_us = (row.check_us or 0) + (now() - t0)
							if cy then
								row.standable = true
								row.angle = a
								local path, cost = timed_path(s, {x = cx, y = cy, z = cz},
									4, 1, 6, 1)
								row.path4, row.us4 = path ~= nil, cost
								break
							end
						end
						fan_rows[#fan_rows + 1] = row
					end
				end
			end
		end
	end
	calib.land = found_rows
	calib.fan = fan_rows
	calib.land_points = land_points
end

---------------------------------------------------------------------------
-- 40 blocked chasers (Round 30 perf review, probe A's "path40" phase)
---------------------------------------------------------------------------
local function phase_chasers40(done)
	clear_arena_objects()
	core.set_timeofday(0)
	local c = field_pos(50, 50)
	-- The hollow stone box of probe A (inner 3x3x3) round the target.
	for dx = -2, 2 do
		for dz = -2, 2 do
			for dy = 0, 4 do
				local edge = abs(dx) == 2 or abs(dz) == 2 or dy == 4
				core.set_node({x = c.x + dx, y = c.y + dy, z = c.z + dz},
					{name = edge and "default:stone" or "air"})
			end
		end
	end
	local dummy = core.add_entity(feet(c), MOD .. ":dummy")
	local recs = {}
	local sm_total = {}
	local n = 0
	for i = 1, 40 do
		local ang = i / 40 * 2 * math.pi
		local d = 5 + (i % 5) * 3
		local p = {x = c.x + math.cos(ang) * d, y = c.y, z = c.z + math.sin(ang) * d}
		local name = i % 3 == 0 and "grug_mobs:bandit" or "grug_mobs:zombie"
		local obj, ent = spawn_at(name, feet(p))
		if obj then
			ent._grug_level = 20
			local rec = {mover = name, kind = "chaser", scene = "chasers40", lane = 0,
				track = {}, events = {}, fp = {n = 0, found = 0, us = 0, max = 0},
				sm = sm_total, counts = {}, cycles = 0, t0 = now(), goal = feet(c)}
			rec.obj, rec.ent = obj, ent
			tracked[ent] = rec
			recs[#recs + 1] = rec
			ent:do_attack(dummy, true)
			n = n + 1
		end
	end
	log("chasers40: " .. n .. " chasers round an enclosed target")
	core.after(3, function()
		step_rows = {}
		for _, rec in ipairs(recs) do
			rec.fp = {n = 0, found = 0, us = 0, max = 0}
			rec.counts = {}
		end
		for k in pairs(sm_total) do sm_total[k] = nil end
		local t_start = now()
		local cpu0 = os.clock()
		core.after(20, function()
			local rows = step_rows
			step_rows = nil
			local seconds = (now() - t_start) / 1e6
			local fpn, fpus, fpmax, found, gave = 0, 0, 0, 0, 0
			local refused = 0
			for _, rec in ipairs(recs) do
				fpn = fpn + rec.fp.n
				fpus = fpus + rec.fp.us
				found = found + rec.fp.found
				if rec.fp.max > fpmax then fpmax = rec.fp.max end
				gave = gave + (rec.counts.give_up or 0)
				refused = refused + (rec.counts.budget_refused or 0)
				if rec.ent then tracked[rec.ent] = nil end
			end
			local mob, fpstep = {}, {}
			for i = 1, #rows do
				mob[i] = rows[i][1] + rows[i][3]
				fpstep[i] = rows[i][3]
			end
			table.sort(mob)
			table.sort(fpstep)
			calib.chasers40 = {
				chasers = n, seconds = r2(seconds), steps = #rows,
				cpu_s = r2(os.clock() - cpu0),
				fp_calls = fpn, fp_found = found, fp_per_s = r2(fpn / seconds),
				fp_ms_per_s = r2(fpus / 1000 / seconds), fp_max_us = fpmax,
				fp_mean_us = fpn > 0 and r2(fpus / fpn) or 0,
				fp_step_us_p99 = pct(fpstep, 0.99), fp_step_us_max = fpstep[#fpstep],
				mob_step_us_p50 = pct(mob, 0.5), mob_step_us_p90 = pct(mob, 0.9),
				mob_step_us_p99 = pct(mob, 0.99), mob_step_us_max = mob[#mob],
				smart_mobs = sm_total, give_ups = gave, budget_refused = refused,
			}
			local sm = {}
			for k, v in pairs(sm_total) do sm[#sm + 1] = k .. "=" .. v end
			table.sort(sm)
			log(("CHASERS40 %.1f s: find_path %d calls (%.1f/s, found %d), %.2f ms/s, mean %.0f us, max %d us; step mob+fp us p50=%s p99=%s max=%s; give_ups=%d refused=%d; sm[%s]"):format(
				seconds, fpn, fpn / seconds, found, fpus / 1000 / seconds,
				fpn > 0 and fpus / fpn or 0, fpmax, tostring(calib.chasers40.mob_step_us_p50),
				tostring(calib.chasers40.mob_step_us_p99), tostring(mob[#mob]),
				gave, refused, table.concat(sm, " ")))
			clear_arena_objects()
			core.set_timeofday(0.45)
			write_results()
			done()
		end)
	end)
end

local function phase_calib(done)
	local ok, err = pcall(calib_scenes)
	if not ok then core.log("error", P .. "calib_scenes: " .. tostring(err)) end
	ok, err = pcall(calib_field)
	if not ok then core.log("error", P .. "calib_field: " .. tostring(err)) end
	ok, err = pcall(calib_line)
	if not ok then core.log("error", P .. "calib_line: " .. tostring(err)) end
	write_results()
	emerge_land(function()
		local ok2, err2 = pcall(calib_land)
		if not ok2 then core.log("error", P .. "calib_land: " .. tostring(err2)) end
		write_results()
		done()
	end)
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
local PHASE_FN = {scenes = phase_scenes, calib = phase_calib,
	chasers40 = phase_chasers40}

local function run_phases()
	local i = 0
	local function next_phase()
		i = i + 1
		local name = PHASES[i]
		if not name then
			write_results()
			log("RESULT DONE")
			core.request_shutdown("nv0 done", false, 0)
			return
		end
		local fn = PHASE_FN[name]
		if not fn then
			core.log("error", P .. "unknown phase " .. name)
			return next_phase()
		end
		log("phase " .. name)
		local t0 = now()
		fn(function()
			log(("phase %s done in %.1f s"):format(name, (now() - t0) / 1e6))
			next_phase()
		end)
	end
	next_phase()
end

core.after(1, function()
	math.randomseed(12345)
	for _, key in ipairs({"mob_pathfinding_searchdistance",
			"mob_pathfinding_stuck_timeout", "mob_pathfinding_stuck_path_timeout",
			"mob_pathfinding_algorithm", "dedicated_server_step"}) do
		results.meta.settings[key] = core.settings:get(key)
	end
	results.meta.path_budget_us = OB.path_budget_us
	results.meta.close_searchdistance = OB.close_searchdistance
	results.meta.give_up_after = OB.give_up_after
	results.meta.seed = core.get_mapgen_setting("seed")
	results.meta.scenes = {}
	for _, scene in ipairs(scenes.list) do
		results.meta.scenes[#results.meta.scenes + 1] = {name = scene.name,
			note = scene.note, reachable = scene.reachable, goal_h = scene.goal_h,
			blocked = scene.blocked}
	end
	origin = find_origin()
	if not origin then
		core.log("error", P .. "no deep-ocean arena origin")
		return core.request_shutdown("nv0 fail", false, 0)
	end
	local minp, maxp = arena_box()
	results.meta.origin = {x = origin.x, z = origin.z, floor_y = FLOOR_Y}
	log("arena " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	local blocks = 0
	for bx = floor(minp.x / 16), floor(maxp.x / 16) do
		for bz = floor(minp.z / 16), floor(maxp.z / 16) do
			for by = floor(minp.y / 16), floor(maxp.y / 16) do
				if core.forceload_block(vector.new(bx * 16, by * 16, bz * 16), true, -1) then
					blocks = blocks + 1
				end
			end
		end
	end
	log("forceloaded blocks: " .. blocks)
	local t0 = now()
	core.emerge_area(vector.offset(minp, -16, -16, -16), vector.offset(maxp, 16, 16, 16),
		function(_, _, remaining)
			if remaining ~= 0 then return end
			log(("arena emerged in %.1f s"):format((now() - t0) / 1e6))
			core.after(0, function()
				local ok, err = pcall(build_arena)
				if not ok then
					core.log("error", P .. "build: " .. tostring(err))
					return core.request_shutdown("nv0 fail", false, 0)
				end
				log("arena built")
				core.after(1, run_phases)
			end)
		end)
end)
