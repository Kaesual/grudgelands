-- Round 81 lane HOT: call counts of the hot spots the lane changed, on any
-- tree of the game (the base and the branch alike), under LuaJIT and stubs.
--
--   luajit tools/r81_hot/measure.lua [REPO]
--
-- Prints one line per scenario. As a module, dofile(...) returns
-- {measure = function(repo) -> numbers, abilities_sandbox = function(repo)}
-- for tools/r81_hot/portable_test.lua. The scenarios:
--   input    the REAL grug_abilities/init.lua (the tools/r53_hooks sandbox):
--            100 idle players, 11 passes of the 0.05 s input globalstep
--            (one second of 0.09 s server steps): wielded-item copies and
--            privilege lookups;
--   env      the REAL environment_damage.lua: 100 players for 10 s of 0.09 s
--            steps, 90 in air and 10 with a stone head (5 with `noclip`):
--            get_properties() calls and privilege lookups;
--   eye      the REAL combat_ray.lua: 670 combat_eye_pos calls (a second of
--            the crosshair at 100 players): get_properties() calls;
--   homing   the REAL homing.lua: a 2 s lock on a player and on a mob, 22
--            steps each: get_properties() calls;
--   status   the REAL status.lua: 100 000 status_modifier_sum calls for a
--            player with four statuses: table.sort calls, KB allocated and
--            CPU seconds (os.clock; a comparison, not a target);
--   engage   the REAL combat.lua: 1000 hits on a mob already engaged,
--            engage_mob three times each: engine reads (get_hp, get_pos).
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
local function any()
	return setmetatable({}, {__index = function() return any() end,
		__call = function() return nil end})
end
local function with_any(t)
	return setmetatable(t, {__index = function() return any() end})
end
local function vec(x, y, z) return {x = x, y = y, z = z} end
local real_vector = {
	new = function(x, y, z)
		if type(x) == "table" then return vec(x.x, x.y, x.z) end
		return vec(x, y, z)
	end,
	copy = function(v) return vec(v.x, v.y, v.z) end,
	add = function(a, b) return vec(a.x + b.x, a.y + b.y, a.z + b.z) end,
	multiply = function(a, s) return vec(a.x * s, a.y * s, a.z * s) end,
	offset = function(v, x, y, z) return vec(v.x + x, v.y + y, v.z + z) end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
	length = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end,
	equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
}

-- The tools/r53_hooks sandbox around the REAL grug_abilities/init.lua (with
-- its dofile chain) of `repo`: {env, callbacks (kind -> list), new_player
-- (name, class), counts (wield copies, privilege lookups), list (the
-- connected players), classes, advance(us), now()}. The privilege cache is
-- the tree's own when it has one. `prepare(env)` (optional, Round 81
-- PASSES) runs just before init.lua loads, e.g. to load grug_core's join
-- slots into env.grug_core.
local function abilities_sandbox(repo, prepare)
	local now_us = 1e9
	local Stack = {}
	Stack.__index = Stack
	local function ItemStack(spec)
		if type(spec) == "table" and getmetatable(spec) == Stack then
			local copy = setmetatable({name = spec.name, count = spec.count, fields = {}}, Stack)
			for k, v in pairs(spec.fields) do copy.fields[k] = v end
			return copy
		end
		local name = type(spec) == "string" and spec:match("^(%S*)") or ""
		return setmetatable({name = name, count = name == "" and 0 or 1, fields = {}}, Stack)
	end
	function Stack:get_name() return self.name end
	function Stack:is_empty() return self.name == "" end
	function Stack:get_count() return self.count end
	function Stack:get_meta()
		local fields = self.fields
		return {get_string = function(_, k) return fields[k] or "" end,
			set_string = function(_, k, v) fields[k] = v ~= "" and v or nil end,
			get_int = function(_, k) return tonumber(fields[k]) or 0 end,
			set_int = function(_, k, v) fields[k] = tostring(v) end,
			set_tool_capabilities = function() end}
	end
	function Stack:get_tool_capabilities() return {full_punch_interval = 1} end
	local LISTS = {"main", "grug_hotbar_store", "grug_bag1", "craft", "grug_weapon"}
	local function new_inventory()
		local inv = {lists = {}}
		for _, l in ipairs(LISTS) do
			local list = {}
			for i = 1, 32 do list[i] = ItemStack("") end
			inv.lists[l] = list
		end
		function inv:get_size(l) return self.lists[l] and #self.lists[l] or 0 end
		function inv:get_stack(l, i) return ItemStack(self.lists[l][i]) end
		function inv:set_stack(l, i, s) self.lists[l][i] = ItemStack(s) end
		function inv:get_list(l)
			local list = {}
			for i, s in ipairs(self.lists[l] or {}) do list[i] = ItemStack(s) end
			return list
		end
		function inv:get_lists()
			local lists = {}
			for _, l in ipairs(LISTS) do lists[l] = self:get_list(l) end
			return lists
		end
		function inv:contains_item() return false end
		return inv
	end
	local counts = {wield = 0, privs = 0}
	local players, list = {}, {}
	local function new_player(name, class)
		local p = {name = name, class = class or "warrior", ranks = {}, bonus = {}, hp = 100,
			inv = new_inventory(), wield = 1}
		function p:get_player_name() return self.name end
		function p:get_inventory() return self.inv end
		function p:is_player() return true end
		function p:get_hp() return self.hp end
		function p:get_pos() return vec(0, 0, 0) end
		function p:get_look_dir() return vec(0, 0, 1) end
		function p:get_wielded_item()
			counts.wield = counts.wield + 1
			return self.inv:get_stack("main", self.wield)
		end
		function p:get_wield_index() return self.wield end
		function p:get_wield_list() return "main" end
		function p:get_player_control() return {} end
		function p:get_meta() return ItemStack("x"):get_meta() end
		function p:get_properties() return {hp_max = 100, eye_height = 1.47} end
		function p:get_breath() return 10 end
		function p:hud_get_hotbar_itemcount() return 8 end
		function p:hud_add() return 1 end
		function p:hud_change() end
		function p:hud_remove() end
		function p:hud_set_flags() end
		players[name] = p
		list[#list + 1] = p
		return p
	end
	local callbacks = {}
	local function capture(kind)
		return function(fn)
			callbacks[kind] = callbacks[kind] or {}
			table.insert(callbacks[kind], fn)
		end
	end
	local fake_core = with_any({
		register_on_dieplayer = capture("die"),
		register_on_leaveplayer = capture("leave"),
		register_on_joinplayer = capture("join"),
		register_globalstep = capture("step"),
		get_modpath = function() return repo .. "/mods/PLAYER/grug_abilities" end,
		get_current_modname = function() return "grug_abilities" end,
		get_us_time = function() return now_us end,
		global_exists = function(n) return n == "grug_inventory" end,
		registered_items = {},
		get_item_group = function(name, group)
			return (group == "grug_ability" and name:find("^grug_abilities:")) and 1 or 0
		end,
		get_player_by_name = function(name) return players[name] end,
		get_connected_players = function() return list end,
		check_player_privs = function()
			counts.privs = counts.privs + 1
			return true
		end,
		get_player_privs = function()
			counts.privs = counts.privs + 1
			return {interact = true}
		end,
		log = function() end,
	})
	local fake_grug_core = with_any({
		get_melee_weapon = function() return ItemStack("") end,
		is_stunned = function() return false end,
		player_has_live_mount = function() return false end,
		player_in_creation_stasis = function() return false end,
		scale_player_damage = false,
		base_pool = function() return 100 end,
		get_player_level = function() return 30 end,
		combat_eye_pos = function() return vec(0, 1.47, 0) end,
		aim_raycast = function() return function() return nil end end,
		unseen_by = function() return false end,
		register_native_melee_handler = function() end,
	})
	local registered_classes = {warrior = {name = "Warrior", resource = "rage"},
		mage = {name = "Mage", resource = "mana"}}
	local fake_classes = with_any({
		registered_classes = registered_classes,
		registered_talents = {},
		get_class = function(p) return p.class end,
		get_class_def = function(p) return registered_classes[p.class] end,
		talent_rank = function() return 0 end,
		get_talent_bonus = function() return 0 end,
		get_melee_bonus = function() return 0 end,
		get_race_perk = function() return nil end,
		get_max_mana = function(p) return p.max_mana or 1000 end,
		talent_window_active = function() return false end,
	})
	local fake_inventory = with_any({
		HOTBAR_STORE = "grug_hotbar_store", HOTBAR_SIZE = 8, BAG_COUNT = 1,
		content_list = function(i) return "grug_bag" .. i end,
		get_cosmetic_hand = function() return nil end,
		hand_list = function() return "grug_weapon" end,
		melee_list = function() return "grug_weapon" end,
		equipment_changed = function() end,
	})
	local env = setmetatable({
		core = fake_core, ItemStack = ItemStack,
		grug_core = fake_grug_core, grug_classes = fake_classes,
		grug_inventory = fake_inventory, vector = real_vector,
	}, {__index = function(_, k)
		local g = rawget(_G, k)
		if g ~= nil and k ~= "core" and k ~= "minetest" and k ~= "grug_core" and
				k ~= "vector" and k ~= "ItemStack" then return g end
		return any()
	end})
	env.dofile = function(path)
		return setfenv(assert(loadfile(path)), env)()
	end
	env._G = env
	if exists(repo, "mods/CORE/grug_core/privs.lua") then
		local privs_env = setmetatable({grug_core = fake_grug_core, core = fake_core},
			{__index = _G})
		load_into(repo, privs_env, "mods/CORE/grug_core/privs.lua")
	end
	if prepare then prepare(env) end
	load_into(repo, env, "mods/PLAYER/grug_abilities/init.lua")
	return {env = env, callbacks = callbacks, new_player = new_player, counts = counts,
		list = list, classes = registered_classes,
		advance = function(us) now_us = now_us + us end,
		now = function() return now_us end}
end

local function measure(repo)
local out = {}
------------------------------------------------------------------------------
-- input: the 0.05 s input globalstep of the real init.lua.
------------------------------------------------------------------------------
do
	local box = abilities_sandbox(repo)
	local callbacks, new_player, counts = box.callbacks, box.new_player, box.counts
	-- The input globalstep: the first one init.lua itself registers.
	local input_step, line
	for _, fn in ipairs(callbacks.step or {}) do
		local info = debug.getinfo(fn, "S")
		if info.source:find("grug_abilities/init%.lua$") and
				(not line or info.linedefined < line) then
			input_step, line = fn, info.linedefined
		end
	end
	assert(input_step, "measure: the input globalstep")
	-- The joins of init.lua (bars, mana, the kit) and of the crosshair (its
	-- HUD); the other files' joins are not what is measured.
	local joins = {}
	for _, fn in ipairs(callbacks.join or {}) do
		local source = debug.getinfo(fn, "S").source
		if source:find("grug_abilities/init%.lua$") or source:find("crosshair%.lua$") then
			joins[#joins + 1] = fn
		end
	end
	for i = 1, 100 do
		local p = new_player("p" .. i)
		for _, fn in ipairs(joins) do fn(p) end
	end
	counts.wield, counts.privs = 0, 0
	for _ = 1, 11 do
		box.advance(90000)
		input_step(0.09)
	end
	out.input = {wield = counts.wield, privs = counts.privs}
end

------------------------------------------------------------------------------
-- env: environment damage, 100 players for 10 s.
------------------------------------------------------------------------------
do
	local counts = {props = 0, privs = 0}
	local steps, players = {}, {}
	local fake_core = setmetatable({
		registered_nodes = {air = {walkable = false}, ["default:stone"] = {}},
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		get_connected_players = function() return players end,
		get_node = function(pos) return {name = pos.x >= 90 and "default:stone" or "air"} end,
		get_item_group = function() return 0 end,
		get_player_privs = function(name)
			counts.privs = counts.privs + 1
			return {noclip = tonumber(name:sub(2)) % 2 == 0 or nil}
		end,
		check_player_privs = function() counts.privs = counts.privs + 1 return true end,
	}, {__index = function(_, k)
		if type(k) == "string" and k:match("^register_") then return function() end end
	end})
	local env = setmetatable({core = fake_core, grug_core = {}, vector = real_vector},
		{__index = _G})
	if exists(repo, "mods/CORE/grug_core/privs.lua") then
		load_into(repo, env, "mods/CORE/grug_core/privs.lua")
	end
	env.grug_core.unseen_by = function() return false end
	-- Round 81 PASSES: on a tree where the pass registers through grug_core,
	-- every player in one call per period, as before.
	if exists(repo, "tools/r81_passes/all_players_pass.lua") then
		dofile(repo .. "/tools/r81_passes/all_players_pass.lua")(env.grug_core, fake_core)
	end
	load_into(repo, env, "mods/CORE/grug_core/combat_ray.lua")
	load_into(repo, env, "mods/CORE/grug_core/environment_damage.lua")
	for i = 1, 100 do
		local p = {name = "p" .. i, hp = 1e9, x = i - 1}
		function p:get_player_name() return self.name end
		function p:get_hp() return self.hp end
		function p:set_hp(hp) self.hp = hp end
		function p:get_pos() return vec(self.x, 0, 0) end
		function p:get_breath() return 10 end
		function p:get_armor_groups() return {} end
		function p:get_flags() return {} end
		function p:get_properties()
			counts.props = counts.props + 1
			return {hp_max = 100, eye_height = 1.47, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}}
		end
		players[i] = p
	end
	local step = steps[#steps]
	for _ = 1, 111 do step(0.09) end
	local hurt = 0
	for _, p in ipairs(players) do
		if p.hp < 1e9 then hurt = hurt + 1 end
	end
	out.env = {props = counts.props, privs = counts.privs, hurt = hurt}
end

------------------------------------------------------------------------------
-- eye and homing.
------------------------------------------------------------------------------
do
	local counts = {props = 0}
	local fake_core = setmetatable({
		registered_nodes = {}, register_on_joinplayer = function() end,
		register_on_dieplayer = function() end, register_on_respawnplayer = function() end,
		register_on_leaveplayer = function() end,
		raycast = function() return function() return nil end end,
	}, {__index = function(_, k)
		if type(k) == "string" and k:match("^register_") then return function() end end
	end})
	local env = setmetatable({core = fake_core, grug_core = {unseen_by = function() return false end},
		vector = real_vector}, {__index = _G})
	load_into(repo, env, "mods/CORE/grug_core/combat_ray.lua")
	load_into(repo, env, "mods/CORE/grug_core/homing.lua")
	local function player(name, pos)
		local p = {name = name, pos = pos}
		function p:get_player_name() return self.name end
		function p:is_player() return true end
		function p:get_hp() return 100 end
		function p:get_pos() return vec(self.pos.x, self.pos.y, self.pos.z) end
		function p:get_velocity() return vec(0, 0, 0) end
		function p:get_attach() return nil end
		function p:get_eye_offset() return vec(0, 0, 0) end
		function p:get_look_dir() return vec(0, 0, 1) end
		function p:get_look_horizontal() return 0 end
		function p:get_properties()
			counts.props = counts.props + 1
			return {hp_max = 100, eye_height = 1.47, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}}
		end
		return p
	end
	local a, b = player("a", vec(0, 0, 0)), player("b", vec(0, 0, 10))
	fake_core.get_player_by_name = function(name) return name == "a" and a or name == "b" and b end
	for _ = 1, 670 do env.grug_core.combat_eye_pos(a) end
	out.eye = {props = counts.props}
	counts.props = 0
	local entity = {health = 10, _grug_cbox = {-0.5, 0, -0.5, 0.5, 1, 0.5}}
	local mob = {pos = vec(0, 0, 10)}
	function mob:is_player() return false end
	function mob:get_luaentity() return entity end
	function mob:get_pos() return vec(self.pos.x, self.pos.y, self.pos.z) end
	function mob:get_velocity() return vec(0, 0, 0) end
	function mob:get_attach() return nil end
	function mob:get_properties()
		counts.props = counts.props + 1
		return {collisionbox = {-0.5, 0, -0.5, 0.5, 1, 0.5}}
	end
	local aims = {}
	for _, target in ipairs({b, mob}) do
		local lock = env.grug_core.homing_lock(a, target, vec(0, 1.5, 0), 5)
		for _ = 1, 22 do
			local aim = env.grug_core.homing_step(lock, 0.09)
			aims[#aims + 1] = aim and aim.y
		end
	end
	out.homing = {props = counts.props, player_aim_y = aims[1], mob_aim_y = aims[23]}
end

------------------------------------------------------------------------------
-- status: status_modifier_sum.
------------------------------------------------------------------------------
do
	local now = 1e9
	local fake_core = setmetatable({get_us_time = function() return now end},
		{__index = function(_, k)
			if type(k) == "string" and k:match("^register_") then return function() end end
		end})
	local env = setmetatable({core = fake_core, grug_core = {}}, {__index = _G})
	-- Round 81 PASSES: the status pass registers through grug_core.
	env.grug_core.register_player_pass = function() end
	load_into(repo, env, "mods/CORE/grug_core/hud_layout.lua")
	load_into(repo, env, "mods/CORE/grug_core/status_icons.lua")
	load_into(repo, env, "mods/CORE/grug_core/status.lua")
	local G = env.grug_core
	local p = {}
	function p:is_player() return true end
	function p:get_player_name() return "p" end
	G.set_status(p, "a_mantle", {duration = 60, modifiers = {armor = 0.2 * 30.5}})
	G.set_status(p, "b_stand", {duration = 60, modifiers = {armor = 0.5 * 37.5, crit_percent = 1}})
	G.set_status(p, "c_elixir", {duration = 60, modifiers = {hp_pool_percent = 6}})
	G.set_status(p, "d_plain", {duration = 60})
	local sorts, sort = 0, table.sort
	table.sort = function(...) sorts = sorts + 1 return sort(...) end
	local keys = {"armor", "crit_percent", "spell_damage_percent", "hp_pool_percent"}
	local total = 0
	collectgarbage()
	collectgarbage("stop")
	local before = collectgarbage("count")
	local started = os.clock()
	for i = 1, 100000 do
		total = total + G.status_modifier_sum(p, keys[i % 4 + 1])
	end
	local seconds = os.clock() - started
	local kb = collectgarbage("count") - before
	collectgarbage("restart")
	table.sort = sort
	out.status = {sorts = sorts, kb = kb, seconds = seconds, total = total,
		armor = G.status_modifier_sum(p, "armor")}
end

------------------------------------------------------------------------------
-- engage: engage_mob on an engaged mob.
------------------------------------------------------------------------------
do
	local counts = {reads = 0}
	local fake_core = setmetatable({
		is_player = function(p) return type(p) == "table" and p.is_player ~= nil end,
		get_us_time = function() return 1e9 end,
		settings = {get = function() return nil end, get_bool = function() return nil end},
	}, {__index = function(_, k)
		if type(k) == "string" and k:match("^register_") then return function() end end
	end})
	local env = setmetatable({core = fake_core, grug_core = {particles = {play = function() end}},
		grug_mobs = {registered_cadence = {["test:mob"] = true}}, vector = real_vector},
		{__index = _G})
	load_into(repo, env, "mods/CORE/grug_core/hud_layout.lua")
	load_into(repo, env, "mods/CORE/grug_core/item_names.lua")
	load_into(repo, env, "mods/CORE/grug_core/combat.lua")
	local p = {}
	function p:is_player() return true end
	function p:get_player_name() return "p" end
	function p:get_hp() counts.reads = counts.reads + 1 return 100 end
	local object = {}
	function object:get_pos() counts.reads = counts.reads + 1 return vec(0, 0, 0) end
	local mob = {name = "test:mob", object = object, health = 10, state = "attack"}
	env.grug_core.engage_mob(mob, p)
	counts.reads = 0
	for _ = 1, 1000 do
		for _ = 1, 3 do env.grug_core.engage_mob(mob, p) end
	end
	out.engage = {reads = counts.reads, edge = mob.temp.grug_engaged.p == true}
end

return out
end

if arg and arg[0] and arg[0]:find("measure%.lua$") then
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
return {measure = measure, abilities_sandbox = abilities_sandbox}
