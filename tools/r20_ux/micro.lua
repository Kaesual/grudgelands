-- Compact final-only fixture. Return a canonical receipt; no engine process.
return function(root)
	local function copy(value)
		if type(value) ~= "table" then return value end
		local out = {}
		for k, v in pairs(value) do out[k] = copy(v) end
		return out
	end
	local env = setmetatable({grug_core = {}}, {__index = _G})
	local joins, leaves, levels, loaded = {}, {}, {}, {}
	local players, saved = {}, nil
	local storage = {get_string = function() return saved and "saved" or "" end,
		set_string = function(_, _, value) saved = copy(value) end}
	env.core = {
		register_globalstep = function() end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		registered_entities = {ordinary = {initial_properties = {show_on_minimap = true}}},
		get_mod_storage = function() return storage end,
		serialize = copy, deserialize = function() return copy(saved) end,
		get_us_time = function() return 10000000 end,
		get_player_by_name = function(name) return players[name] end,
		chat_send_player = function() end,
		get_modpath = function() return "skip" end,
		get_current_modname = function() return "grug_parties" end,
	}
	env.grug_xp = {get_level = function(p) return p.level end,
		register_on_level_change = function(fn) levels[#levels + 1] = fn end}
	env.grug_factions = {get_faction = function() return "accord" end,
		register_on_faction_chosen = function() end}
	env.grug_classes = {get_class = function() return "warrior" end,
		register_on_class_chosen = function() end}
	env.dofile = function() end -- Party UI/HUD have engine-specific presentation.
	local function load(path)
		local fn = assert(loadfile(root .. "/" .. path))
		setfenv(fn, env)()
	end
	load("mods/CORE/grug_core/suffocation.lua")
	local suffocate = env.grug_core.should_suffocate
	assert(suffocate({drawtype = "normal", walkable = true}))
	assert(suffocate({})) -- Engine node defaults are opaque, solid cubes.
	for _, def in ipairs({
		{walkable = false}, {liquidtype = "source"}, {liquidtype = "flowing"},
		{drawtype = "glasslike"}, {drawtype = "normal", sunlight_propagates = true},
		{node_box = {type = "fixed"}}, {collision_box = {type = "fixed"}},
		{drawtype = "mesh"}, {groups = {disable_suffocation = 1}},
	}) do assert(not suffocate(def)) end
	assert(not suffocate({}, true, false) and not suffocate({}, false, true))
	assert(not suffocate(nil) and env.grug_core.suffocation_damage(100) == 5)
	load("mods/PLAYER/grug_map/minimap.lua")
	for _, fn in ipairs(loaded) do fn() end
	assert(env.core.registered_entities.ordinary.initial_properties.show_on_minimap == false)
	local marker
	joins[1]({set_properties = function(_, p) marker = p.show_on_minimap end,
		set_minimap_modes = function() end})
	assert(marker == true)
	joins = {}
	load("mods/PLAYER/grug_parties/init.lua")
	local function player(name, level)
		local p = {level = level, get_player_name = function() return name end,
			is_player = function() return true end, get_hp = function() return 100 end,
			get_properties = function() return {hp_max = 100} end,
			get_meta = function() return {get_int = function() return 0 end} end}
		players[name] = p
		for _, fn in ipairs(joins) do fn(p) end
		return p
	end
	local a, b = player("A", 7), player("B", 11)
	local q = env.grug_parties
	assert(q.invite(a, "B"))
	assert(q.pending(b)[1].level == 7)
	assert(q.accept(b, "A"))
	assert(q.view(a).members[2].level == 11)
	b.level = 12
	for _, fn in ipairs(levels) do fn(b, 11, 12) end
	for _, fn in ipairs(leaves) do fn(b) end
	players.B = nil
	assert(not q.view(a).members[2].online and q.view(a).members[2].level == 12)
	-- Same-version restart retains only the party's member-level snapshot.
	load("mods/PLAYER/grug_parties/init.lua")
	q = env.grug_parties
	assert(q.view("A").members[2].level == 12)
	assert(saved.groups["1"].levels.B == 12)
	return "r20_ux:full-cube+minimap+party-level-persistence:ok"
end
