-- Known-answer test for RIGHT-CLICKING A NODE WITH A SKILL IN HAND
-- (playtest round 1, 2026-09-15).
--
-- The defect: with an ability item wielded, a wooden door would not open. The
-- cause is not a cast eating the click -- an ability never had an `on_place` or
-- an `on_secondary_use`, and casting sits on `on_use`/LMB. It is the swing
-- items' own `pointabilities`: `doors:door_wood_*` carries
-- `oddly_breakable_by_hand`, which those items declare `"blocking"`, so the
-- client's ray stops on the door and reports POINTEDTHING_NOTHING
-- (src/environment.cpp:276). Right-click on nothing sends INTERACT_ACTIVATE and
-- lands in `on_secondary_use`, never in `on_place`.
--
-- This fixture therefore proves three separate things against the real sources:
--
--   A  THE MECHANISM. The real `doors` registry is rebuilt by
--      `stub_registry.lua` and the real `oddly_breakable_by_hand` group is
--      matched against the real `pointabilities` table a swing ability
--      registers. That row is the negative control: remove the pointabilities
--      and it flips.
--   B  THE RULE. The real `mods/PLAYER/grug_abilities/init.lua` is loaded under
--      a stub engine, the real `grug_abilities.register_ability` registers one
--      swing and one cast ability, and the `on_place`/`on_secondary_use`
--      closures the engine would get are driven through twelve cases. Two of
--      them are the OBJECT case: `on_secondary_use` is also what
--      INTERACT_PLACE on an object calls, immediately before the engine runs
--      that object's own right-click (serverpackethandler.cpp:1192-1208), so
--      right-clicking a vendor must not fire the `on_rightclick` of the chest
--      behind him. Two more are the reach cases, because the hand-reach bound
--      is needed on `on_place` as well: a cast item has no blocking
--      pointabilities and a range of up to 20.
--   C  THE CAST PATH IS UNTOUCHED. `grug_abilities.try_cast` is replaced by a
--      counter: every right-click case must leave it at zero, and the cast
--      item's `on_use` must still reach it.
--
-- Every case also asserts HOW OFTEN the code asked for the eye position and
-- whether it cast a ray at all, because "the door 1.5 m away opened" does not
-- show that a gate ran, and "nothing happened" does not show why.
--
-- Plain Lua 5.1, no engine.
--
-- Usage (from the repository root):
--   luajit          -e 'io.write(dofile("tools/wp13/ability_rightclick_kat.lua")("."))'
--   tools/bin/lua51 -e 'io.write(dofile("tools/wp13/ability_rightclick_kat.lua")("."))'

local M = {}

local ABILITIES = "mods/PLAYER/grug_abilities/init.lua"
local DOOR = "doors:door_wood_a"
local PLAIN = "default:stone"

--
-- A minimal `vector` (the engine injects one; a standalone interpreter has
-- none). Only the four operations the pass-through uses.
--
local vector_stub = {}

function vector_stub.new(x, y, z)
	return {x = x or 0, y = y or 0, z = z or 0}
end

function vector_stub.add(a, b)
	return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end

function vector_stub.multiply(a, s)
	return {x = a.x * s, y = a.y * s, z = a.z * s}
end

function vector_stub.normalize(a)
	local length = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
	if length == 0 then
		return {x = 0, y = 0, z = 0}
	end
	return {x = a.x / length, y = a.y / length, z = a.z / length}
end

function vector_stub.distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--
-- Load the real ability mod under a stub engine.
--
-- `setfenv` (both interpreters have it; it is 5.1) keeps every stub out of the
-- fixture's own globals, and the `dofile` in the environment is a no-op so
-- `kits.lua` -- the real ability catalog, which needs the whole game -- is not
-- pulled in. What is exercised is the shipped `register_ability` and the two
-- closures it puts on the tool definition.
--
local function load_abilities(repo, nodes, world)
	local tools = {}
	local noop = function() end
	local core_stub = {registered_nodes = nodes, registered_items = {},
		registered_entities = {}, registered_tools = {}}

	function core_stub.register_tool(name, def)
		tools[name] = def
	end
	function core_stub.get_modpath()
		return repo .. "/mods/PLAYER/grug_abilities"
	end
	function core_stub.get_current_modname()
		return "grug_abilities"
	end
	function core_stub.get_node_or_nil(pos)
		local entry = world.at(pos)
		return entry and {name = entry.node, param1 = 0, param2 = 0} or nil
	end
	core_stub.get_node = core_stub.get_node_or_nil
	function core_stub.get_us_time()
		return 0
	end
	-- The engine's ray, modelled exactly as far as this fixture needs it: hits
	-- are yielded in DELIBERATELY WRONG order (far to near), because the real
	-- Raycast order is not line-of-sight order either and the code under test
	-- has to compare intersection distances rather than trust the iterator.
	function core_stub.raycast(origin, destination, objects, liquids)
		world.objects, world.liquids = objects, liquids
		local reach = vector_stub.distance(origin, destination)
		world.reach = reach
		local hits = {}
		for index = #world.hits, 1, -1 do
			local hit = world.hits[index]
			if hit.distance <= reach + 1e-9 then
				hits[#hits + 1] = {type = "node", under = hit.pos,
					above = hit.pos,
					intersection_point = {x = origin.x, y = origin.y,
						z = origin.z + hit.distance}}
			end
		end
		local at = 0
		return function()
			at = at + 1
			return hits[at]
		end
	end
	setmetatable(core_stub, {__index = function(t, key)
		rawset(t, key, noop)
		return noop
	end})

	local function stub_table(fields)
		return setmetatable(fields or {}, {__index = function(t, key)
			rawset(t, key, noop)
			return noop
		end})
	end

	local grug_core = stub_table({})
	-- Counted, because "the door 1.5 m away opened" says nothing about whether
	-- the hand-reach gate ran at all.
	function grug_core.combat_eye_pos(player)
		world.eye_calls = (world.eye_calls or 0) + 1
		return player and player._eye or nil
	end

	local env = {
		core = core_stub,
		minetest = core_stub,
		vector = vector_stub,
		grug_core = grug_core,
		grug_classes = stub_table({registered_classes = {}}),
		grug_factions = stub_table(),
		grug_xp = stub_table(),
		grug_mobs = stub_table(),
		grug_inventory = stub_table(),
		grug_projectiles = stub_table(),
		grug_gear = stub_table({BRACKETS = {}}),
		dofile = noop,
		math = math, table = table, string = string, os = os, io = io,
		type = type, pairs = pairs, ipairs = ipairs, next = next,
		tostring = tostring, tonumber = tonumber, select = select,
		unpack = unpack, error = error, assert = assert, pcall = pcall,
		setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, rawequal = rawequal,
	}
	env._G = env

	local chunk, load_error = loadfile(repo .. "/" .. ABILITIES)
	if not chunk then
		return nil, "cannot load " .. ABILITIES .. ": " .. tostring(load_error)
	end
	setfenv(chunk, env)
	local ok, run_error = pcall(chunk)
	if not ok then
		return nil, "loading " .. ABILITIES .. " failed: " .. tostring(run_error)
	end
	return {tools = tools, abilities = env.grug_abilities, env = env}
end

function M.run(repo)
	repo = repo or "."
	local out, failures = {}, {}
	local function row(...)
		out[#out + 1] = table.concat({...}, "\t")
	end
	local function check(condition, message)
		if not condition then
			failures[#failures + 1] = message
		end
	end
	local function finish()
		table.sort(failures)
		row("wp13_rmb_result", #failures == 0 and "PASS" or "FAIL", #failures)
		for _, message in ipairs(failures) do
			row("wp13_rmb_failure", message)
		end
		return table.concat(out, "\n") .. "\n"
	end

	--
	-- The real node registry.
	--
	local registry = dofile(repo .. "/tools/wp13/stub_registry.lua").load(repo)
	local real_door = registry.nodes[DOOR]
	local real_plain = registry.nodes[PLAIN]
	check(real_door ~= nil, DOOR .. " is not in the rebuilt registry")
	check(real_plain ~= nil, PLAIN .. " is not in the rebuilt registry")
	if not real_door or not real_plain then
		return finish()
	end
	check(type(real_door.on_rightclick) == "function",
		DOOR .. " has no on_rightclick -- this fixture tests nothing")
	check(real_plain.on_rightclick == nil,
		PLAIN .. " has an on_rightclick; it is no longer a plain control node")

	-- Every interactive node in the game, for the record.
	local interactive = 0
	for _, def in pairs(registry.nodes) do
		if def.on_rightclick then
			interactive = interactive + 1
		end
	end
	row("wp13_rmb_registry", #registry.order, "interactive", interactive)

	--
	-- The world the stub ray sees, and the stub player.
	--
	local world = {hits = {}, at = function() return nil end}
	local recorded = {}
	local function recorder(pos, node, clicker, itemstack, pointed_thing)
		recorded[#recorded + 1] = {pos = pos, node = node and node.name,
			clicker = clicker, itemstack = itemstack,
			pointed = pointed_thing and pointed_thing.type}
		return nil -- like a door: it returns nothing and keeps the stack
	end
	-- The registry's own definitions, with only `on_rightclick` swapped for the
	-- recorder. Everything else about the node -- groups included -- stays real.
	local nodes = {}
	nodes[DOOR] = setmetatable({on_rightclick = recorder},
		{__index = real_door})
	nodes[PLAIN] = real_plain

	local placed = {} -- pos key -> node name
	local function key(pos)
		return pos.x .. ":" .. pos.y .. ":" .. pos.z
	end
	world.at = function(pos)
		local name = placed[key(pos)]
		return name and {node = name} or nil
	end
	local function put(pos, name)
		placed[key(pos)] = name
	end

	local loaded, load_error = load_abilities(repo, nodes, world)
	check(loaded ~= nil, load_error or "")
	if not loaded then
		return finish()
	end

	--
	-- One swing and one cast ability, through the shipped registration.
	--
	local casts = 0
	loaded.abilities.try_cast = function()
		casts = casts + 1
		return true
	end
	local cast_calls = 0
	loaded.abilities.register_ability({
		id = "kat_swing", kind = "swing", target_kind = "hostile",
		universal = true, name = "Kat Swing",
		description = "fixture", color = "#ffffff", range = 4,
	})
	loaded.abilities.register_ability({
		id = "kat_cast", kind = "cast", target_kind = "self",
		universal = true, name = "Kat Cast",
		description = "fixture", color = "#ffffff", range = 4, cooldown = 1,
		cast = function()
			cast_calls = cast_calls + 1
			return true
		end,
	})
	local swing = loaded.tools["grug_abilities:kat_swing"]
	local cast = loaded.tools["grug_abilities:kat_cast"]
	check(swing ~= nil and cast ~= nil, "register_ability registered no tool")
	if not swing or not cast then
		return finish()
	end

	--
	-- A. the mechanism, against the real groups and the real pointabilities
	--
	local blocked_by = nil
	local pointabilities = swing.pointabilities and swing.pointabilities.nodes
	check(pointabilities ~= nil, "the swing item declares no node pointabilities")
	for entry, mode in pairs(pointabilities or {}) do
		local group = entry:match("^group:(.+)$")
		if group and mode == "blocking" and real_door.groups and
				real_door.groups[group] then
			blocked_by = group
		end
	end
	row("wp13_rmb_blocking", DOOR, tostring(blocked_by),
		"swing_on_use", tostring(swing.on_use),
		"cast_on_use", type(cast.on_use))
	check(blocked_by ~= nil, DOOR .. " is not blocked by the swing item's " ..
		"pointabilities any more -- the on_secondary_use repair may be " ..
		"unnecessary, re-read the mechanism")
	check(swing.on_use == nil, "a swing item grew an on_use")
	check(type(cast.on_use) == "function", "the cast item lost its on_use")
	check(type(swing.on_place) == "function" and
		type(swing.on_secondary_use) == "function",
		"the swing item is missing a right-click callback")
	check(type(cast.on_place) == "function" and
		type(cast.on_secondary_use) == "function",
		"the cast item is missing a right-click callback")

	--
	-- B/C. the nine cases, for both kinds
	--
	local EYE = {x = 0, y = 1.5, z = 0}
	local function player(sneak)
		return {
			_eye = EYE,
			is_player = function() return true end,
			get_player_name = function() return "kat" end,
			get_player_control = function() return {sneak = sneak == true} end,
			get_look_dir = function() return {x = 0, y = 0, z = 1} end,
		}
	end

	local function node_pointed(pos)
		return {type = "node", under = pos, above = pos}
	end

	-- `dist` is the eye-to-node-cube distance the case is built around (the eye
	-- is at (0, 1.5, 0) and a node's cube is its centre +-0.5), `eye` how often
	-- the shipped code must ask for the eye position -- one per reach test or
	-- ray origin, zero when a guard returns first -- and `ray` whether the 4 m
	-- server ray must have been cast.
	local CASES = {
		{name = "place_door", sneak = false, call = "on_place",
			pointed = node_pointed({x = 0, y = 1, z = 2}),
			node = {pos = {x = 0, y = 1, z = 2}, name = DOOR},
			dist = 1.5, eye = 1, rightclick = 1},
		{name = "place_plain", sneak = false, call = "on_place",
			pointed = node_pointed({x = 0, y = 1, z = 2}),
			node = {pos = {x = 0, y = 1, z = 2}, name = PLAIN},
			dist = 1.5, eye = 1, rightclick = 0},
		{name = "place_door_sneak", sneak = true, call = "on_place",
			pointed = node_pointed({x = 0, y = 1, z = 2}),
			node = {pos = {x = 0, y = 1, z = 2}, name = DOOR},
			dist = 1.5, eye = 0, rightclick = 0},
		-- HAND REACH ON `on_place` TOO. A cast item has no blocking
		-- pointabilities and a range of up to 20 (plus the elf's +5), so without
		-- this bound the client points a door across a courtyard and builtin's
		-- inherited rule would open it.
		{name = "place_door_far", sneak = false, call = "on_place",
			pointed = node_pointed({x = 0, y = 1, z = 6}),
			node = {pos = {x = 0, y = 1, z = 6}, name = DOOR},
			dist = 5.5, eye = 1, rightclick = 0},
		{name = "activate_door", sneak = false, call = "on_secondary_use",
			pointed = {type = "nothing"},
			node = {pos = {x = 0, y = 1, z = 2}, name = DOOR},
			hits = {{pos = {x = 0, y = 1, z = 2}, distance = 2}},
			eye = 1, ray = true, rightclick = 1},
		{name = "activate_plain", sneak = false, call = "on_secondary_use",
			pointed = {type = "nothing"},
			node = {pos = {x = 0, y = 1, z = 2}, name = PLAIN},
			hits = {{pos = {x = 0, y = 1, z = 2}, distance = 2}},
			eye = 1, ray = true, rightclick = 0},
		{name = "activate_door_sneak", sneak = true, call = "on_secondary_use",
			pointed = {type = "nothing"},
			node = {pos = {x = 0, y = 1, z = 2}, name = DOOR},
			hits = {{pos = {x = 0, y = 1, z = 2}, distance = 2}},
			eye = 0, rightclick = 0},
		{name = "activate_empty", sneak = false, call = "on_secondary_use",
			pointed = {type = "nothing"}, hits = {},
			eye = 1, ray = true, rightclick = 0},
		-- Out of hand reach: the door is 6 m away, the ray is capped at 4.
		{name = "activate_door_far", sneak = false, call = "on_secondary_use",
			pointed = {type = "nothing"},
			node = {pos = {x = 0, y = 1, z = 6}, name = DOOR},
			hits = {{pos = {x = 0, y = 1, z = 6}, distance = 6}},
			eye = 1, ray = true, rightclick = 0},
		-- No reaching through: a wall in front of the door ends the attempt,
		-- and the iterator hands the DOOR over first to make sure of it.
		{name = "activate_door_behind_wall", sneak = false,
			call = "on_secondary_use", pointed = {type = "nothing"},
			node = {pos = {x = 0, y = 1, z = 3}, name = DOOR},
			extra = {pos = {x = 0, y = 1, z = 1}, name = PLAIN},
			hits = {{pos = {x = 0, y = 1, z = 1}, distance = 1},
				{pos = {x = 0, y = 1, z = 3}, distance = 3}},
			eye = 1, ray = true, rightclick = 0},
		-- THE OBJECT CASE. `on_secondary_use` is not only the "pointing at air"
		-- callback: INTERACT_PLACE on an OBJECT calls it too, immediately before
		-- the engine runs that object's own right-click
		-- (serverpackethandler.cpp:1192-1208). Right-clicking a vendor must open
		-- the shop and nothing else -- not the chest standing behind him. The
		-- type guard has to return before the eye is even asked for.
		{name = "activate_object_door_behind", sneak = false,
			call = "on_secondary_use", pointed = {type = "object"},
			node = {pos = {x = 0, y = 1, z = 2}, name = DOOR},
			hits = {{pos = {x = 0, y = 1, z = 2}, distance = 2}},
			eye = 0, rightclick = 0},
		-- The same guard, with sneak off the table: an object click never
		-- reaches the node path however the player holds the keys.
		{name = "activate_object_sneak", sneak = true,
			call = "on_secondary_use", pointed = {type = "object"},
			node = {pos = {x = 0, y = 1, z = 2}, name = DOOR},
			hits = {{pos = {x = 0, y = 1, z = 2}, distance = 2}},
			eye = 0, rightclick = 0},
	}

	local KINDS = {{"swing", swing}, {"cast", cast}}
	for _, kind in ipairs(KINDS) do
		local label, tool = kind[1], kind[2]
		for _, case in ipairs(CASES) do
			placed = {}
			if case.node then
				put(case.node.pos, case.node.name)
			end
			if case.extra then
				put(case.extra.pos, case.extra.name)
			end
			world.hits = case.hits or {}
			world.reach, world.objects, world.liquids = nil, nil, nil
			world.eye_calls = 0
			recorded = {}
			casts = 0
			cast_calls = 0
			local stack = "grug_abilities:" .. (label == "swing" and
				"kat_swing" or "kat_cast")
			local ok, result = pcall(tool[case.call], stack, player(case.sneak),
				case.pointed)
			check(ok, label .. "/" .. case.name .. " raised " .. tostring(result))
			row("wp13_rmb_case", label, case.call, case.name,
				"pointed", tostring(case.pointed and case.pointed.type),
				"node_dist", tostring(case.dist),
				"rightclick", #recorded, "casts", casts + cast_calls,
				"returned", tostring(result),
				"eye_calls", world.eye_calls, "ray_reach",
				tostring(world.reach))
			check(#recorded == case.rightclick, label .. "/" .. case.name ..
				" called on_rightclick " .. #recorded .. " times, expected " ..
				case.rightclick)
			check(casts + cast_calls == 0, label .. "/" .. case.name ..
				" reached the cast path")
			check(ok and result == stack, label .. "/" .. case.name ..
				" did not return the wielded stack unchanged")
			if case.rightclick == 1 then
				local hit = recorded[1]
				check(hit and hit.node == DOOR, label .. "/" .. case.name ..
					" passed the wrong node to on_rightclick")
				check(hit and hit.itemstack == stack, label .. "/" ..
					case.name .. " passed the wrong stack to on_rightclick")
				check(hit and hit.pos and case.node and
					hit.pos.z == case.node.pos.z, label .. "/" ..
					case.name .. " passed the wrong position")
				check(hit and hit.pointed ~= nil, label .. "/" .. case.name ..
					" passed no pointed_thing to on_rightclick")
			end
			-- The eye count is what proves a GATE ran rather than a lucky
			-- distance: an on_place case must have measured hand reach, and an
			-- object or sneak case must have returned before asking at all.
			check(world.eye_calls == case.eye, label .. "/" .. case.name ..
				" asked for the eye position " .. world.eye_calls ..
				" times, expected " .. case.eye)
			if case.ray then
				check(world.reach == 4, label .. "/" .. case.name ..
					" rayed " .. tostring(world.reach) ..
					" m instead of the 4 m hand reach")
				check(world.objects == false and world.liquids == false,
					label .. "/" .. case.name ..
					" asked the ray for objects or liquids")
			else
				check(world.reach == nil, label .. "/" .. case.name ..
					" cast a server ray it should not have cast")
			end
		end
	end

	--
	-- C. the cast path still casts, on LMB.
	--
	casts, cast_calls = 0, 0
	placed = {}
	put({x = 0, y = 1, z = 2}, PLAIN)
	cast.on_use("grug_abilities:kat_cast", player(false),
		node_pointed({x = 0, y = 1, z = 2}))
	row("wp13_rmb_on_use", "casts", casts + cast_calls)
	check(casts + cast_calls == 1,
		"the cast item's on_use no longer reaches the cast path (" ..
		(casts + cast_calls) .. " calls)")

	return finish()
end

return function(repo)
	return M.run(repo)
end
