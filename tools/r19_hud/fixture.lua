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
	local grug_core = {hud_layout = {anchors = {status_list = {
		position = {x = 0.5, y = 0}, offset = {x = 0, y = 20},
		alignment = {x = 0, y = 1},
	}}}}
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
	modifier = nil
	check(grug_core.status_text(player) == "",
		"Sprint display lingered after explicit movement removal")
	modifier = {name = "scout_sprint", speed = 0.5, expiry = 11000000}
	abilities.sprint.cast(player)
	-- status.lua was loaded first; its registered death callback owns display
	-- cleanup. Scout's independent draw cleanup is outside this fixture.
	hooks.death[1](player)
	modifier = nil
	check(grug_core.status_text(player) == "", "Sprint display survived death")

	local anchor = grug_core.hud_layout.anchors.status_list
	check(anchor.position.x == 0.5 and anchor.position.y == 0
		and anchor.offset.y == 20 and anchor.alignment.x == 0,
		"status HUD is not top-centred")

	return ("r19-hud\tPASS\tchecks=%d\tparty=by-class\tstatus=top-centre\tsprint=authoritative")
		:format(checks)
end
