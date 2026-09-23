return function(repo)
	local checks = 0
	local function check(value, message)
		checks = checks + 1
		if not value then error(message, 0) end
	end

	-- Party preference authority: an empty value uses the new default while an
	-- explicit all-green choice remains canonical and persistent.
	local meta_values = {}
	local player = {name = "Scout"}
	function player:is_player() return true end
	function player:get_player_name() return self.name end
	function player:get_meta()
		return {
			get_int = function(_, key) return meta_values[key] or 0 end,
			set_int = function(_, key, value) meta_values[key] = value end,
			get_string = function(_, key) return meta_values[key] or "" end,
			set_string = function(_, key, value) meta_values[key] = value end,
		}
	end

	local joins = {}
	local party_core = {
		get_current_modname = function() return "grug_parties" end,
		get_modpath = function() return repo .. "/mods/PLAYER/grug_parties" end,
		get_mod_storage = function() return {
			get_string = function() return "" end,
			set_string = function() end,
		} end,
		serialize = function() return "stored" end,
		deserialize = function() return nil end,
		get_us_time = function() return 0 end,
		get_player_by_name = function(name) return name == player.name and player or nil end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function() end,
		register_globalstep = function() end,
		chat_send_player = function() end,
	}
	local party_env = setmetatable({core = party_core, dofile = function() end,
		grug_factions = {get_faction = function() return "accord" end,
			register_on_faction_chosen = function() end},
		grug_classes = {register_on_class_chosen = function() end},
	}, {__index = _G})
	local party_chunk = assert(loadfile(repo .. "/mods/PLAYER/grug_parties/init.lua"))
	setfenv(party_chunk, party_env)
	party_chunk()
	for index = 1, #joins do joins[index](player) end
	check(party_env.grug_parties.health_color_mode(player) == "by_class",
		"missing party color preference did not default by class")
	check(party_env.grug_parties.set_health_color_mode(player, "all_green"),
		"explicit all-green preference was refused")
	check(party_env.grug_parties.health_color_mode(player) == "all_green",
		"explicit all-green preference did not survive")

	-- Load the real status implementation and the real Scout registration.
	local clock = 1000000
	local hooks = {death = {}, leave = {}, step = {}}
	local hud_defs = {}
	function player:hud_add(def) hud_defs[#hud_defs + 1] = def; return #hud_defs end
	function player:hud_change() end
	function player:hud_remove() end
	local core = {
		get_us_time = function() return clock end,
		is_player = function(value) return value == player end,
		register_on_joinplayer = function(fn) hooks.join = fn end,
		register_on_dieplayer = function(fn) hooks.death[#hooks.death + 1] = fn end,
		register_on_leaveplayer = function(fn) hooks.leave[#hooks.leave + 1] = fn end,
		register_globalstep = function(fn) hooks.step[#hooks.step + 1] = fn end,
		get_connected_players = function() return {player} end,
		get_player_by_name = function() return player end,
		registered_items = {},
	}
	local grug_core = {}
	local layout_env = setmetatable({grug_core = grug_core}, {__index = _G})
	local layout_chunk = assert(loadfile(repo .. "/mods/CORE/grug_core/hud_layout.lua"))
	setfenv(layout_chunk, layout_env)
	layout_chunk()
	local status_env = setmetatable({core = core, grug_core = grug_core}, {__index = _G})
	local status_chunk = assert(loadfile(repo .. "/mods/CORE/grug_core/status.lua"))
	setfenv(status_chunk, status_env)
	status_chunk()
	local abilities = {}
	local modifier
	grug_core.set_move_modifier = function(_, name, effect, duration)
		modifier = {name = name, speed = effect.speed,
			expiry = clock + duration * 1000000}
	end
	grug_core.get_move_modifier = function(_, name)
		if modifier and modifier.name == name and modifier.expiry > clock then
			return {speed = modifier.speed,
				remaining = (modifier.expiry - clock) / 1000000}
		end
		return nil
	end
	grug_core.register_on_settled_outgoing_action = function() end
	grug_core.register_on_stun = function() end
	grug_core.register_on_equipment_change = function() end
	local scout_env = setmetatable({
		core = core,
		grug_core = grug_core,
		grug_abilities = {registered = {}, flash = function() end,
			register_ability = function(def) abilities[def.id] = def end},
		grug_projectiles = {register = function() end},
		grug_classes = {}, grug_inventory = {}, player_api = {
			register_control_animation_override = function() end},
	}, {__index = _G})
	local scout_chunk = assert(loadfile(repo .. "/mods/PLAYER/grug_abilities/scout.lua"))
	setfenv(scout_chunk, scout_env)
	scout_chunk()
	check(abilities.sprint.cast(player) == true, "Sprint cast failed")
	check(modifier and modifier.name == "scout_sprint" and modifier.speed == 0.5
		and modifier.expiry == 11000000, "Sprint changed movement authority")
	local text = grug_core.status_text(player)
	check(text:find("Sprint (+50% Speed)  0:10", 1, true) ~= nil,
		"Sprint display label or initial lifetime differs")
	clock = 11000000
	check(grug_core.status_text(player) == "" and
		grug_core.get_move_modifier(player, "scout_sprint") == nil,
		"Sprint status or movement effect survived expiry")
	clock = 12000000
	abilities.sprint.cast(player)
	modifier = nil
	check(grug_core.status_text(player) == "",
		"Sprint display lingered after explicit movement removal")
	abilities.sprint.cast(player)
	-- status.lua was loaded first; its registered death callback owns display
	-- cleanup. Scout's independent draw cleanup is outside this fixture.
	hooks.death[1](player)
	modifier = nil
	check(grug_core.status_text(player) == "", "Sprint display survived death")
	abilities.sprint.cast(player)
	hooks.leave[1](player)
	modifier = nil
	hooks.join(player)
	check(grug_core.status_text(player) == "", "Sprint display survived reconnect")

	local anchor = grug_core.hud_layout.anchors.status_list
	check(anchor.position.x == 0.5 and anchor.position.y == 0
		and anchor.offset.y == 20 and anchor.alignment.x == 0,
		"status HUD is not top-centred")

	-- The real tag-carrier metadata adapter must publish through the registered
	-- entity prototype because mobs_redo does not preserve arbitrary def keys.
	local entity_defs, spawned = {}, {}
	local tag_core = {
		registered_entities = entity_defs,
		settings = {get = function() return nil end,
			get_bool = function(_, _, fallback) return fallback end},
		colorspec_to_colorstring = function(value) return value end,
		register_entity = function(name, def) def.name = name; entity_defs[name] = def end,
		register_globalstep = function() end,
		get_connected_players = function() return {player} end,
	}
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	local function object(def_name, pos, properties, luaentity)
		local obj = {valid = true, pos = pos, properties = properties or {},
			luaentity = luaentity}
		function obj:is_valid() return self.valid end
		function obj:is_player() return false end
		function obj:get_pos() return self.pos end
		function obj:get_properties() return self.properties end
		function obj:get_luaentity() return self.luaentity end
		function obj:set_properties(values)
			for key, value in pairs(values) do self.properties[key] = value end
		end
		function obj:set_attach(parent, _, offset)
			self.parent, self.attach_offset = parent, offset
		end
		function obj:get_attach() return self.parent end
		function obj:set_observers(values) self.observers = values end
		function obj:remove() self.valid = false end
		if def_name then
			local def = entity_defs[def_name]
			obj.luaentity = setmetatable({_grug_observers = {}}, {__index = def})
			obj.luaentity.object = obj
			if def.on_activate then def.on_activate(obj.luaentity) end
		end
		return obj
	end
	tag_core.add_entity = function(pos, name)
		local obj = object(name, pos, {}, nil)
		spawned[#spawned + 1] = obj
		return obj
	end
	local tag_grug = {}
	local tag_env = setmetatable({core = tag_core, grug_core = tag_grug},
		{__index = _G})
	local tag_chunk = assert(loadfile(repo .. "/mods/CORE/grug_core/tag_carrier.lua"))
	setfenv(tag_chunk, tag_env)
	tag_chunk()
	local dragon_defs = {}
	local boss_core = {
		register_node = function() end,
		register_globalstep = function() end,
		is_player = function() return false end,
	}
	local boss_mobs = {
		register_mob = function(name, def) dragon_defs[name] = def end,
		register_homing_arrow = function() end,
	}
	local boss_env = setmetatable({core = boss_core, grug_core = {},
		grug_mobs = boss_mobs}, {__index = _G})
	local boss_chunk = assert(loadfile(repo ..
		"/mods/ENTITIES/grug_mobs/boss_dragons.lua"))
	setfenv(boss_chunk, boss_env)
	boss_chunk()
	boss_mobs.register_dragon_bosses({
		storage = {set_string = function() end}, settle = function() end,
		player_enemy_of = function() return true end, respawn = 1800,
	})
	entity_defs["grug_mobs:ice_dragon"] = dragon_defs["grug_mobs:ice_dragon"]
	entity_defs["grug_mobs:jungle_wyvern"] = dragon_defs["grug_mobs:jungle_wyvern"]
	check(tag_grug.register_hp_bar_presentation("grug_mobs:ice_dragon",
		dragon_defs["grug_mobs:ice_dragon"]._grug_hp_bar_presentation),
		"registered metadata adapter refused dragon presentation")
	check(tag_grug.register_hp_bar_presentation("grug_mobs:jungle_wyvern",
		dragon_defs["grug_mobs:jungle_wyvern"]._grug_hp_bar_presentation),
		"registered metadata adapter refused wyvern presentation")
	local dragon_entity = setmetatable({name = "grug_mobs:ice_dragon",
		_grug_disposition = "aggressive", health = 50, hp_max = 100},
		{__index = entity_defs["grug_mobs:ice_dragon"]})
	local dragon = object(nil, {x = 0, y = 0, z = 0}, {
		visual_size = {x = 8, y = 8}, collisionbox = {-3, 0, -3, 3, 8, 3},
	}, dragon_entity)
	tag_grug.create_tag_carrier(dragon)
	tag_grug.refresh_tag_player_snapshot()
	tag_grug.manage_tag_carriers()
	local dragon_bar = spawned[2]
	check(dragon_bar and dragon_bar.attach_offset.y == 6.25
		and dragon_bar.properties.visual_size.x == 0.375
		and dragon_bar.properties.visual_size.y == 0.03125,
		"dragon metadata did not convert to 5x3x0.25 world geometry: " ..
		tostring(dragon_bar and dragon_bar.attach_offset.y) .. "/" ..
		tostring(dragon_bar and dragon_bar.properties.visual_size.x) .. "/" ..
		tostring(dragon_bar and dragon_bar.properties.visual_size.y))
	local wyvern_entity = setmetatable({name = "grug_mobs:jungle_wyvern",
		_grug_disposition = "aggressive", health = 50, hp_max = 100},
		{__index = entity_defs["grug_mobs:jungle_wyvern"]})
	local wyvern = object(nil, {x = 0, y = 0, z = 0}, {
		visual_size = {x = 8, y = 8},
		collisionbox = {-2.4, 0, -2.4, 2.4, 6.4, 2.4},
	}, wyvern_entity)
	tag_grug.create_tag_carrier(wyvern)
	tag_grug.manage_tag_carriers()
	local wyvern_bar = spawned[4]
	check(wyvern_bar and wyvern_bar.attach_offset.y == 5
		and wyvern_bar.properties.visual_size.x == 0.375
		and wyvern_bar.properties.visual_size.y == 0.03125,
		"wyvern metadata did not convert to 4x3x0.25 world geometry")

	local ordinary_entity = {name = "grug_mobs:rat",
		_grug_disposition = "aggressive", health = 5, hp_max = 10}
	local ordinary = object(nil, {x = 0, y = 0, z = 0}, {
		visual_size = {x = 1, y = 1}, collisionbox = {-0.2, 0, -0.2, 0.2, 1, 0.2},
	}, ordinary_entity)
	tag_grug.create_tag_carrier(ordinary)
	tag_grug.manage_tag_carriers()
	local ordinary_bar = spawned[6]
	check(ordinary_bar and math.abs(ordinary_bar.attach_offset.y - 11.2) < 0.000001
		and ordinary_bar.properties.visual_size.x == 0.8
		and ordinary_bar.properties.visual_size.y == 0.1,
		"ordinary HP bar geometry changed")

	return ("r19-hud\tPASS\tchecks=%d\tparty=by-class\tstatus=top-centre\t" ..
		"sprint=authoritative\tdragon=5x3x0.25\tordinary=0.8x0.1")
		:format(checks)
end
