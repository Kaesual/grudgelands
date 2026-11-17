-- Round 81 lane PASSES: call counts of the passes and readers the lane
-- changed, on any tree of the game (the base and the branch alike), under
-- LuaJIT and stubs.
--
--   luajit tools/r81_passes/measure.lua [REPO]
--
-- Prints one line per scenario. As a module, dofile(...) returns
-- {measure = function(repo) -> numbers, sandboxes = {...}} for
-- tools/r81_passes/portable_test.lua. Every scenario loads grug_core's REAL
-- join slots (player_slots.lua) and fires its join callbacks, so a pass of
-- the tree that uses them is spread and one that does not walks every
-- player at once. The scenarios:
--   status    the REAL status.lua: 100 players (50 with two timed statuses,
--             one ticking every second), 2 s of 0.09 s server steps: the most
--             players one step handles, and table.sort calls per player visit
--             (each status-list build sorts once; the row adds two);
--   env       the REAL environment_damage.lua: 100 players, 10 s of 0.09 s
--             steps, 10 with a stone head: the most players one step
--             handles, and the hits (one per player and second);
--   regen     the REAL grug_abilities/init.lua (tools/r81_hot's sandbox):
--             100 Mages, 2 s of 0.09 s steps: the most players one step
--             handles, max-mana computations and property reads per visit;
--   identity  the REAL grug_xp, grug_factions and grug_classes (init.lua,
--             stats.lua, perks.lua) and grug_traders/potion.lua: 100
--             players, each read 50 times through every identity accessor
--             (level, XP, class, race, faction, a race perk) and the potion
--             cooldown, then 20 hp changes (the nametag): player-meta reads
--             and property reads.
local function exists(repo, path)
	local f = io.open(repo .. "/" .. path, "r")
	if f then f:close() end
	return f ~= nil
end
local function load_into(repo, env, path)
	local chunk = assert(loadfile(repo .. "/" .. path))
	setfenv(chunk, env)
	return chunk()
end
local function noop() end
-- A table whose missing fields are no-op functions.
local function permissive(t)
	return setmetatable(t, {__index = function() return noop end})
end
local function vec(x, y, z) return {x = x, y = y, z = z} end
local STEP = 0.09

-- An engine stub that captures the callbacks the slot helper and the passes
-- register; `step(dtime)` runs every globalstep in order.
local function engine(extra)
	local steps, joins, leaves = {}, {}, {}
	local now = 1e9
	local list = {}
	local core = permissive({
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		get_us_time = function() return now end,
		get_connected_players = function() return list end,
		log = noop,
	})
	for k, v in pairs(extra or {}) do core[k] = v end
	local box = {core = core, list = list}
	function box.join(p)
		list[#list + 1] = p
		for _, fn in ipairs(joins) do fn(p) end
	end
	function box.step(dtime)
		now = now + dtime * 1e6
		for _, fn in ipairs(steps) do fn(dtime) end
	end
	function box.now() return now end
	return box
end

-- The most distinct players `touch` saw in one step, and the visits per
-- player (one per step that touched it): `touch(player)` is called from
-- inside the pass.
local function visit_counter()
	local c = {step = 0, max = 0, seen = {}, visits = {}}
	function c.touch(p)
		local key = c.step
		local seen = c.seen[key]
		if not seen then
			seen = {n = 0}
			c.seen[key] = seen
		end
		if not seen[p] then
			seen[p] = true
			seen.n = seen.n + 1
			if seen.n > c.max then c.max = seen.n end
			c.visits[p] = (c.visits[p] or 0) + 1
		end
	end
	return c
end

------------------------------------------------------------------------------
-- status
------------------------------------------------------------------------------
local function status_sandbox(repo)
	local E = engine({get_player_window_information = false})
	local sorts = 0
	local my_table = setmetatable({sort = function(t, f)
		sorts = sorts + 1
		return table.sort(t, f)
	end}, {__index = table})
	local env = setmetatable({core = E.core, grug_core = {}, table = my_table},
		{__index = _G})
	load_into(repo, env, "mods/CORE/grug_core/player_slots.lua")
	load_into(repo, env, "mods/CORE/grug_core/hud_layout.lua")
	load_into(repo, env, "mods/CORE/grug_core/status_icons.lua")
	load_into(repo, env, "mods/CORE/grug_core/status.lua")
	local G = env.grug_core
	local counter = visit_counter()
	-- A source is asked once per player visit (the icon row), on both trees.
	G.register_status_source(function(p)
		counter.touch(p)
		return nil
	end)
	local function new_player(name)
		local p = {name = name, huds = 0}
		function p:get_player_name() return self.name end
		function p:is_player() return true end
		function p:hud_add() self.huds = self.huds + 1 return self.huds end
		function p:hud_change() end
		return p
	end
	return {E = E, G = G, counter = counter, new_player = new_player,
		sorts = function() return sorts end}
end

local function measure_status(repo)
	local S = status_sandbox(repo)
	for i = 1, 100 do
		local p = S.new_player("p" .. i)
		S.E.join(p)
		if i % 2 == 0 then
			S.G.set_status(p, "sprint", {duration = 30})
			S.G.set_status(p, "poison", {duration = 30, interval = 1,
				on_tick = noop})
		end
	end
	local before = S.sorts()
	local visits = 0
	for step = 1, 23 do -- 2.07 s
		S.counter.step = step
		S.E.step(STEP)
	end
	for _, n in pairs(S.counter.visits) do visits = visits + n end
	return {max_per_step = S.counter.max, visits = visits,
		sorts_per_visit = (S.sorts() - before) / visits}
end

------------------------------------------------------------------------------
-- env
------------------------------------------------------------------------------
local function env_sandbox(repo)
	local E = engine({
		registered_nodes = {air = {walkable = false}, ["default:stone"] = {}},
		get_node = function(pos) return {name = pos.x >= 90 and "default:stone" or "air"} end,
		get_player_privs = function() return {} end,
		check_player_privs = function() return true end,
	})
	local env = setmetatable({core = E.core, grug_core = {}, vector = vector},
		{__index = _G})
	load_into(repo, env, "mods/CORE/grug_core/player_slots.lua")
	if exists(repo, "mods/CORE/grug_core/privs.lua") then
		load_into(repo, env, "mods/CORE/grug_core/privs.lua")
	end
	env.grug_core.unseen_by = function() return false end
	load_into(repo, env, "mods/CORE/grug_core/combat_ray.lua")
	load_into(repo, env, "mods/CORE/grug_core/environment_damage.lua")
	local counter = visit_counter()
	local function new_player(name, x)
		local p = {name = name, hp = 1e9, x = x, hits = {}}
		function p:get_player_name() return self.name end
		function p:is_player() return true end
		function p:get_hp() return self.hp end
		function p:set_hp(hp) self.hits[#self.hits + 1] = self.hp - hp; self.hp = hp end
		function p:get_pos() counter.touch(self) return vec(self.x, 0, 0) end
		function p:get_breath() return 10 end
		function p:get_armor_groups() return {} end
		function p:get_flags() return {} end
		function p:get_properties()
			return {hp_max = 100, eye_height = 1.47, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}}
		end
		return p
	end
	return {E = E, G = env.grug_core, counter = counter, new_player = new_player}
end

local function measure_env(repo)
	local S = env_sandbox(repo)
	local stone = {}
	for i = 1, 100 do
		local p = S.new_player("p" .. i, i - 1)
		S.E.join(p)
		if i > 90 then stone[#stone + 1] = p end
	end
	for step = 1, 111 do -- 9.99 s
		S.counter.step = step
		S.E.step(STEP)
	end
	local hits, single = 0, true
	for _, p in ipairs(stone) do
		hits = hits + #p.hits
		for _, amount in ipairs(p.hits) do
			if amount ~= 5 then single = false end
		end
	end
	return {max_per_step = S.counter.max, stone_hits = hits,
		one_tick_each = single}
end

------------------------------------------------------------------------------
-- regen
------------------------------------------------------------------------------
-- This file's own tree: tools/r81_hot's sandbox (with its `prepare` hook)
-- comes from here, the measured mods from `repo`.
local TOOLS = (debug.getinfo(1, "S").source:match("^@(.*)/tools/r81_passes/measure%.lua$")) or "."

local function regen_sandbox(repo)
	-- tools/r81_hot/measure.lua prints its own report when arg[0] names a
	-- measure.lua, as this file's may.
	local saved_arg = arg
	arg = nil
	local hot = dofile(TOOLS .. "/tools/r81_hot/measure.lua")
	arg = saved_arg
	local box = hot.abilities_sandbox(repo, function(env)
		load_into(repo, env, "mods/CORE/grug_core/player_slots.lua")
	end)
	-- The joins of the slots, init.lua and the crosshair (the other files'
	-- joins are not what is measured).
	local joins = {}
	for _, fn in ipairs(box.callbacks.join or {}) do
		local source = debug.getinfo(fn, "S").source
		if source:find("player_slots%.lua$") or source:find("grug_abilities/init%.lua$") or
				source:find("crosshair%.lua$") then
			joins[#joins + 1] = fn
		end
	end
	function box.join(p)
		for _, fn in ipairs(joins) do fn(p) end
	end
	function box.step(dtime)
		box.advance(dtime * 1e6)
		for _, fn in ipairs(box.callbacks.step or {}) do fn(dtime) end
	end
	return box
end

local function measure_regen(repo)
	local box = regen_sandbox(repo)
	local counter = visit_counter()
	local counts = {max_mana = 0, props = 0}
	local C = box.env.grug_classes
	local get_max_mana = C.get_max_mana
	C.get_max_mana = function(p)
		counts.max_mana = counts.max_mana + 1
		return get_max_mana(p)
	end
	for i = 1, 100 do
		local p = box.new_player("m" .. i, "mage")
		local get_properties = p.get_properties
		-- The bars read the breath on every visit (and every other draw).
		function p:get_breath()
			counter.touch(self)
			return 10
		end
		function p:get_properties()
			counts.props = counts.props + 1
			return get_properties(self)
		end
		box.join(p)
	end
	-- The pool doubles after the join's refill: every visit regenerates
	-- (the stub's maximum is the player's `max_mana`).
	for _, p in ipairs(box.list) do p.max_mana = 2000 end
	-- Only the pass: the joins drew the bars once.
	counts.max_mana, counts.props = 0, 0
	counter.max, counter.seen, counter.visits = 0, {}, {}
	for step = 1, 23 do -- 2.07 s
		counter.step = step
		box.step(STEP)
	end
	local visits = 0
	for _, n in pairs(counter.visits) do visits = visits + n end
	return {max_per_step = counter.max, visits = visits,
		max_mana_per_visit = counts.max_mana / visits, props_per_visit = counts.props / visits}
end

------------------------------------------------------------------------------
-- identity
------------------------------------------------------------------------------
local function identity_sandbox(repo)
	local counts = {meta = 0, props = 0}
	local callbacks = {hp = {}, join = {}, level = {}}
	local players = {}
	local core = permissive({
		get_modpath = function(name)
			return repo .. "/mods/" .. (name == "grug_traders" and "ENTITIES/" or "PLAYER/") .. name
		end,
		register_on_player_hpchange = function(fn, modifier)
			if not modifier then callbacks.hp[#callbacks.hp + 1] = fn end
		end,
		register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
		get_player_by_name = function(name) return players[name] end,
		get_us_time = function() return 1e9 end,
		settings = {get = noop, get_bool = function(_, _, d) return d end},
	})
	local env
	local current = "grug_xp"
	core.get_current_modname = function() return current end
	core.global_exists = function(name) return rawget(env, name) ~= nil end
	local grug_core = permissive({
		factions = {accord = {name = "Accord"}, throng = {name = "Throng"}},
		zone_authority_installed = function() return true end,
		status_modifier_sum = function() return 0 end,
		base_pool = function(level) return 100 + 10 * level end,
		create_tag_carrier = function() return {} end,
		set_tag_carrier_text = function() return true end,
		particles = permissive({}),
	})
	env = setmetatable({core = core, grug_core = grug_core,
		grug_sounds = permissive({}), vector = vector}, {__index = _G})
	env.dofile = function(path)
		-- grug_classes: only its stats and perks besides init.lua.
		if path:find("grug_classes/", 1, true) and not (path:find("/stats%.lua$") or
				path:find("/perks%.lua$")) then
			return nil
		end
		return setfenv(assert(loadfile(path)), env)()
	end
	load_into(repo, env, "mods/CORE/grug_core/hud_layout.lua")
	load_into(repo, env, "mods/PLAYER/grug_xp/init.lua")
	current = "grug_factions"
	load_into(repo, env, "mods/PLAYER/grug_factions/init.lua")
	current = "grug_classes"
	env.grug_classes = nil
	load_into(repo, env, "mods/PLAYER/grug_classes/init.lua")
	local C = env.grug_classes
	C.get_talent_bonus = function() return 0 end
	C.get_scout_dodge_add = function() return 0 end
	C.get_scout_dodge_cap = function() return 30 end
	C.on_level_change_talents = noop
	current = "grug_traders"
	env.grug_traders = {}
	load_into(repo, env, "mods/ENTITIES/grug_traders/potion.lua")

	local function new_player(name, store)
		store = store or {}
		local props = {hp_max = 20, breath_max = 10}
		local p = {name = name, store = store, hp = 20, props = props}
		local meta = {
			get_string = function(_, k) return store[k] or "" end,
			set_string = function(_, k, v) store[k] = v ~= "" and v or nil end,
			get_int = function(_, k) return tonumber(store[k]) or 0 end,
			set_int = function(_, k, v) store[k] = tostring(v) end,
		}
		function p:get_player_name() return self.name end
		function p:is_player() return true end
		function p:get_meta() counts.meta = counts.meta + 1 return meta end
		function p:get_properties()
			counts.props = counts.props + 1
			local copy = {}
			for k, v in pairs(props) do copy[k] = v end
			return copy
		end
		function p:get_hp() return self.hp end
		-- As the engine: the hp-change callbacks run before the value is
		-- stored, and a lower hp_max clamps HP inside set_properties.
		function p:set_hp(hp, reason)
			for _, fn in ipairs(callbacks.hp) do fn(self, hp - self.hp, reason or {type = "set_hp"}) end
			self.hp = hp
		end
		function p:set_properties(t)
			for k, v in pairs(t) do props[k] = v end
			if t.hp_max and self.hp > t.hp_max then
				self:set_hp(t.hp_max, {type = "set_hp"})
			end
		end
		function p:get_pos() return vec(0, 0, 0) end
		function p:get_inventory()
			return {get_stack = function() return {is_empty = function() return true end} end,
				set_stack = noop}
		end
		function p:hud_add() return 1 end
		p.hud_change, p.set_nametag_attributes = noop, noop
		players[name] = p
		return p
	end
	return {env = env, C = C, X = env.grug_xp, F = env.grug_factions,
		T = env.grug_traders, counts = counts, callbacks = callbacks,
		new_player = new_player, join = function(p)
			for _, fn in ipairs(callbacks.join) do fn(p) end
		end}
end

local function measure_identity(repo)
	local S = identity_sandbox(repo)
	local races = {"human", "orc"}
	local list = {}
	for i = 1, 100 do
		local faction = i % 2 == 0 and "accord" or "throng"
		local p = S.new_player("p" .. i, {
			["grug_xp:xp"] = tostring(S.X.xp_for_level(1 + i % 60)),
			["grug_factions:faction"] = faction,
			["grug_classes:race"] = faction == "accord" and "human" or "orc",
			["grug_classes:class"] = "warrior",
		})
		list[i] = p
	end
	local _ = races
	S.counts.meta, S.counts.props = 0, 0
	for _, p in ipairs(list) do
		for _ = 1, 50 do
			S.X.get_level(p)
			S.X.get_xp(p)
			S.C.get_class(p)
			S.C.get_race(p)
			S.F.get_faction(p)
			S.C.get_race_perk(p, "zombie_truce")
			S.T.potion_cooldown_left(p)
		end
	end
	local reads = S.counts.meta
	-- The nametag on hp changes, after the stats were applied once.
	for _, p in ipairs(list) do S.C.apply_stats(p) end
	S.counts.props = 0
	for _, p in ipairs(list) do
		for _ = 1, 20 do p:set_hp(p.hp - 1) end
	end
	return {meta_reads = reads, tag_props = S.counts.props}
end

local function measure(repo)
	return {
		status = measure_status(repo),
		env = measure_env(repo),
		regen = measure_regen(repo),
		identity = measure_identity(repo),
	}
end

if arg and arg[0] and arg[0]:find("r81_passes/measure%.lua$") then
	local result = measure(arg[1] or ".")
	local names = {}
	for name in pairs(result) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		local fields = {}
		for key, value in pairs(result[name]) do
			fields[#fields + 1] = key .. "=" .. tostring(value)
		end
		table.sort(fields)
		print(name .. " " .. table.concat(fields, " "))
	end
end
return {measure = measure, status_sandbox = status_sandbox, env_sandbox = env_sandbox,
	identity_sandbox = identity_sandbox, regen_sandbox = regen_sandbox,
	engine = engine}
