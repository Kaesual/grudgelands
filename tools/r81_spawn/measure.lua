-- Round 81 SPAWN: call counts of the spawn paths this lane changed (LuaJIT).
--
--   luajit tools/r81_spawn/measure.lua REPO      (prints the counts)
--   local m = dofile(repo .. "/tools/r81_spawn/measure.lua")(repo)
--
-- Runs the real code of REPO, so the same file measures the base and the
-- branch alike (round81-plan.md §3.1: call counts, no engine run):
--   S. mobs/api.lua spawn_specific's spawn_action, cut out, on stand-ins:
--      per scenario its outcome and how often it called the spawn policy,
--      count_mobs and find_nodes_in_area (MOB2-01);
--   D. grug_mobs/density.lua region_density_allows on a crowded area at its
--      budget: get_luaentity calls (X4-06);
--   H. grug_mobs/start_npcs.lua's heartbeat, cut out, 60 settlements over
--      20 s of 0.09 s steps: the most rows one step served, and how often each
--      row was served (MOB2-02).
local function read(repo, path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function spawn_action_counts(repo)
	local api = read(repo, "mods/ENTITIES/mobs/api.lua")
	local src = api:match("\n(function mobs:spawn_specific%(.-\nend)\n\n%-%- GRUG PATCH %(Round 30 P2%): see the call above")
	assert(src, "spawn_specific not found")
	local NAME = "grug_mobs:probe"
	local w -- the scenario's world
	local calls
	local env = {
		mobs = {spawning_mobs = {[NAME] = {}}},
		mobs_spawn = true, peaceful_only = false, mob_chance_multiplier = 1,
		max_per_block = 99, random = math.random, max = math.max, floor = math.floor,
		mob_nospawn_range = 12, mob_area_spawn = false, spawn_protected = true,
		spawn_monster_protected = true, mob_log_spawn = false,
		settings = {get = function() return nil end},
		at_limit = function() return false end,
		count_mobs = function()
			calls.count = calls.count + 1
			return w.count or 0, true
		end,
		node_ok = function() return {name = "air"} end,
		get_distance = function(a, b)
			local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
			return math.sqrt(x * x + y * y + z * z)
		end,
		pairs = pairs, tonumber = tonumber,
	}
	env.mobs.register_spawn_abm = function(spec) env.action = spec.action end
	function env.mobs:spawn_abm_check()
		calls.policy = calls.policy + 1
		return w.policy_refuses
	end
	env.core = {
		registered_entities = {[NAME] = {type = "monster", base_colbox = {-0.4, 0, -0.4, 0.4, 1, 0.4},
			initial_properties = {collisionbox = {-0.4, 0, -0.4, 0.4, 1, 0.4}}}},
		registered_nodes = {air = {walkable = false}},
		registered_aliases = {},
		get_timeofday = function() return w.time end,
		get_node_light = function() return w.light end,
		find_nodes_in_area = function()
			calls.find = calls.find + 1
			return w.repellent and {{x = 0, y = 0, z = 0}} or {}
		end,
		is_protected = function() return false end,
		get_connected_players = function() return {} end,
		add_entity = function() calls.added = calls.added + 1 end,
		log = function() end,
	}
	local chunk = assert(loadstring("local mobs = mobs\n" .. src))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	chunk()
	-- A day row (prepare_spawn_row's form: min_light 10, day_toggle) at
	-- interval 20, chance 1000, aoc 3, y 0..600.
	env.mobs:spawn_specific(NAME, {"default:dirt"}, {"air"}, 10, 15, 20, 1000, 3, 0, 600, true)
	local scenarios = {
		{"night", {time = 0.0, light = 15}},
		{"dark", {time = 0.5, light = 4}},
		{"too high", {time = 0.5, light = 15, y = 600}},
		{"policy refuses", {time = 0.5, light = 15, policy_refuses = true}},
		{"cap full", {time = 0.5, light = 15, count = 3}},
		{"spawns", {time = 0.5, light = 15}},
		{"repellent (registered)", {time = 0.5, light = 15, repellent = true, registered = true}},
	}
	local out = {}
	for _, row in ipairs(scenarios) do
		w = row[2]
		calls = {policy = 0, count = 0, find = 0, added = 0}
		env.core.registered_nodes["mobs:mob_repellent"] = w.registered and {} or nil
		env.action({x = 0, y = w.y or 10, z = 0}, {name = "default:dirt"}, 0, 0)
		out[#out + 1] = {name = row[1], spawned = calls.added > 0, policy = calls.policy,
			count = calls.count, find = calls.find}
	end
	return out
end

local function density_counts(repo)
	local saved = {grug_mobs = rawget(_G, "grug_mobs"), core = rawget(_G, "core")}
	local objects, reads = {}, 0
	_G.core = {
		settings = {get = function() return nil end},
		get_objects_inside_radius = function() return objects end,
	}
	_G.grug_mobs = {spawn_regions = {core = {DENSITY = {sparse = 0.5, normal = 0.75, dense = 1}},
		area_by_tag = function() return {is_camp = false} end}}
	dofile(repo .. "/mods/ENTITIES/grug_mobs/density.lua")
	local G = _G.grug_mobs
	local function object(ent)
		return {get_luaentity = function() reads = reads + 1; return ent end}
	end
	-- A crowded area: 30 counted region mobs of the clock (the point budget is
	-- 15 by day at density normal x 0.75 -> 11) among 570 other objects
	-- (players, carriers, bars, drops), the mobs first in the engine's list.
	for i = 1, 30 do
		objects[#objects + 1] = object({name = i % 3 == 0 and "grug_mobs:fox" or "grug_mobs:boar",
			_grug_area = "zone/kind", _grug_spawn_clock = "day"})
	end
	for _ = 1, 570 do objects[#objects + 1] = object(nil) end
	local kind = {density = "normal"}
	reads = 0
	local first = G.region_density_allows({x = 0, y = 0, z = 0}, "zone", "day", kind,
		"grug_mobs:fox", 1, 2)
	local first_reads = reads
	-- The same area with the mobs last in the list.
	local reversed = {}
	for i = #objects, 1, -1 do reversed[#reversed + 1] = objects[i] end
	objects = reversed
	reads = 0
	local last = G.region_density_allows({x = 0, y = 0, z = 0}, "zone", "day", kind,
		"grug_mobs:fox", 1, 2)
	local last_reads = reads
	for name, value in pairs(saved) do rawset(_G, name, value) end
	return {objects = 600, first = first, first_reads = first_reads, last = last,
		last_reads = last_reads}
end

local function heartbeat_counts(repo)
	local npcs = read(repo, "mods/ENTITIES/grug_mobs/start_npcs.lua")
	local a = npcs:find("\nlocal ready_served = {}", 1, true)
	local b = npcs:find("\ncore.register_on_mods_loaded(function()\n\tbuild_rows()", 1, true)
	assert(a and b and b > a, "heartbeat section not found")
	local steps, rows = {}, {}
	for i = 1, 60 do rows[i] = {key = "row" .. i} end
	local served, step_served = {}, 0
	local env = {
		rows = rows, PLACE_INTERVAL = 5,
		settlement_ready = function() return false end,
		serve = function(row)
			served[row.key] = (served[row.key] or 0) + 1
			step_served = step_served + 1
			return 0, 0
		end,
		log_row = function() end,
		core = {register_globalstep = function(fn) steps[#steps + 1] = fn end},
	}
	local chunk = assert(loadstring(npcs:sub(a + 1, b)))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	chunk()
	assert(#steps == 1, "one heartbeat globalstep")
	local most, t = 0, 0
	while t < 20 - 1e-9 do
		step_served = 0
		steps[1](0.09)
		t = t + 0.09
		if step_served > most then most = step_served end
	end
	local low, high = math.huge, 0
	for _, row in ipairs(rows) do
		local n = served[row.key] or 0
		if n < low then low = n end
		if n > high then high = n end
	end
	-- One long step of a whole heartbeat (the old fixtures' `fn(5)`).
	served = {}
	steps[1](5)
	local whole = 0
	for _, row in ipairs(rows) do whole = whole + (served[row.key] or 0) end
	return {rows = #rows, most_per_step = most, served_low = low, served_high = high,
		long_step_serves = whole}
end

local function measure(repo)
	return {spawn = spawn_action_counts(repo), density = density_counts(repo),
		heartbeat = heartbeat_counts(repo)}
end

if arg and arg[0] and arg[0]:match("measure%.lua$") then
	local m = measure(arg[1] or ".")
	for _, s in ipairs(m.spawn) do
		print(("S %-24s spawned=%-5s policy=%d count_mobs=%d find_nodes=%d"):format(s.name,
			tostring(s.spawned), s.policy, s.count, s.find))
	end
	local d = m.density
	print(("D %d objects, budget full: mobs first -> %s after %d get_luaentity; " ..
		"mobs last -> %s after %d"):format(d.objects, tostring(d.first), d.first_reads,
		tostring(d.last), d.last_reads))
	local h = m.heartbeat
	print(("H %d rows, 20 s of 0.09 s steps: at most %d rows in one step; each row served " ..
		"%d..%d times; one 5 s step serves %d"):format(h.rows, h.most_per_step, h.served_low,
		h.served_high, h.long_step_serves))
end

return measure
