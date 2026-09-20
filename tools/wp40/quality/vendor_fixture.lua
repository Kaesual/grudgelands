-- Bounded current-version registration and save/reload checks, isolated globals.
return function(repo)
	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[key] = copy(child) end
		return result
	end
	local function noop() end
	local function translate(text, ...)
		local args = {...}
		return (text:gsub("@(%d+)", function(i) return tostring(args[tonumber(i)]) end))
	end
	local env = setmetatable({}, {__index = _G})
	env._G = env
	env.table = copy(table)
	env.table.copy = copy
	local callbacks, lbms, abms, loaded = {}, {}, {}, {}
	local registered = {[""] = {groups = {}}, air = {groups = {}}, ignore = {groups = {}}}
	local api = {registered_items = registered, registered_nodes = copy(registered),
		registered_entities = {}, registered_aliases = {}, registered_tools = {},
		registered_craftitems = {}, registered_chatcommands = {}, features = {}, LIGHT_MAX = 14}
	env.core, env.minetest = api, api -- The vendored engine alias remains current.
	api.settings = {get = function() return nil end,
		get_bool = function(_, name) return name == "enable_damage" end}
	api.get_translator, api.formspec_escape = function() return translate end, function(s) return s end
	api.global_exists = function(name) return rawget(env, name) ~= nil end
	api.get_modpath = function(name)
		local groups = {default = "BASE", stairs = "BASE", creative = "BASE",
			player_api = "BASE", mobs = "ENTITIES", grug_nodes = "ITEMS"}
		if groups[name] then return repo .. "/mods/" .. groups[name] .. "/" .. name end
	end
	local function register(kind, name, def)
		name = name:gsub("^:", "")
		def.name, def.groups = name, def.groups or {}
		registered[name] = def
		api["registered_" .. kind][name] = def
	end
	api.register_node = function(name, def) register("nodes", name, def) end
	api.register_tool = function(name, def) register("tools", name, def) end
	api.register_craftitem = function(name, def) register("craftitems", name, def) end
	api.register_entity = function(name, def) api.registered_entities[name:gsub("^:", "")] = def end
	api.override_item = function(name, fields)
		assert(registered[name], name)
		for k, v in pairs(fields) do registered[name][k] = v end
	end
	api.register_alias = function(name, target) api.registered_aliases[name] = target end
	api.register_lbm = function(def) lbms[#lbms + 1] = def end
	api.register_abm = function(def) abms[#abms + 1] = def end
	api.create_detached_inventory = function() return {set_size=noop} end
	api.get_craft_result = function() return {time=0} end
	api.get_item_group = function(name, group)
		return registered[name] and registered[name].groups[group] or 0
	end
	api.get_mapgen_setting = function(name) return name == "mg_name" and "v7" or "0" end
	api.check_player_privs = function(name) return name == "builder" end
	api.is_creative_enabled = function() return false end
	api.get_translated_string = function(_, text) return text end
	api.get_builtin_path = function() return repo .. "/reference_projects/luanti/builtin/" end
	api.get_current_modname = function() return "fixture" end
	api.get_worldpath = function() return "/tmp" end
	api.get_mod_storage = function() return {get_string = function() return "" end, set_string = noop} end
	for _, name in ipairs({"register_craft", "register_privilege", "register_chatcommand",
		"register_ore", "register_biome", "register_decoration", "log", "after", "sound_play",
		"sound_stop", "sound_fade", "handle_node_drops", "item_eat", "rotate_node", "calculate_knockback", "get_node_raw", "get_name_from_content_id", "get_node"}) do api[name] = noop end
	setmetatable(api, {__index = function(_, name)
		if name:match("^register_on_") or name == "register_globalstep" then
			return function(fn)
				callbacks[name] = callbacks[name] or {}
				callbacks[name][#callbacks[name] + 1] = fn
			end
		end
		error("unmodeled core API: " .. name)
	end})
	env.vector = {direction = noop, multiply = noop, subtract = noop, add = noop,
		new = function(x,y,z) return type(x) == "table" and copy(x) or {x=x or 0,y=y or 0,z=z or 0} end}
	env.ItemStack = function() return {add_wear_by_uses = noop} end
	env.PcgRandom = function() return {next = function(_, a) return a end} end
	env.sfinv = {pages = {}, register_page = noop, override_page = noop}
	env.player_api = {player_attached = {}, set_animation = noop}
	env.dofile = function(path)
		loaded[#loaded + 1] = path:sub(#repo + 2)
		return setfenv(assert(loadfile(path)), env)()
	end
	-- Full loaders include every changed default file and avoid hiding stale paths.
	local join_count = #(callbacks.register_on_joinplayer or {})
	env.dofile(repo .. "/mods/BASE/player_api/api.lua")
	local player_props = {}
	local player = {get_player_name=function() return "fixture_player" end,
		set_properties=function(_, changes) for key,value in pairs(changes) do player_props[key]=value end end,
		set_animation=noop, set_local_animation=noop}
	callbacks.register_on_joinplayer[join_count + 1](player)
	env.player_api.register_model("fixture.b3d", {textures={"player.png"}, animations={
		stand={x=0,y=1}, walk={x=2,y=3}, mine={x=4,y=5}, walk_mine={x=6,y=7}}})
	env.player_api.set_model(player, "fixture.b3d")
	env.player_api.set_textures(player, {"changed.png"})
	env.player_api.set_animation(player, "walk", 10)
	assert(env.player_api.get_animation(player).animation == "walk")
	assert(player_props.mesh == "fixture.b3d" and player_props.textures[1] == "changed.png")
	env.dofile(repo .. "/mods/BASE/default/init.lua")
	env.dofile(repo .. "/mods/BASE/stairs/init.lua")
	env.dofile(repo .. "/mods/BASE/creative/init.lua")
	env.dofile(repo .. "/mods/ENTITIES/mobs/api.lua")
	env.dofile(repo .. "/mods/ENTITIES/mobs/mount.lua")
	env.dofile(repo .. "/mods/ENTITIES/mobs/crafts.lua")
	env.grug_mobs = {ambusher = noop, atlas_textures = function(texture, count)
		local textures = {}; for i=1,count do textures[i]=texture end; return textures
	end, register_mob = function(name, def) env.mobs:register_mob(name, def) end,
		-- The non-combatant verb (WP13 playtest round 2): vendors.lua wraps
		-- every definition in it, so a stub without it stopped this fixture at
		-- the first `register_vendor`. A pass-through that sets the flag is
		-- what the real verb does to a definition; the verb's own behaviour is
		-- `tools/wp13/start_npcs_kat.lua`'s.
		noncombatant = function(def) def._grug_noncombatant = true; return def end}
	env.grug_materials = {natural_groups = function(groups) return groups end}
	env.grug_traders = {}
	env.grug_core = {faction_ids = {"accord", "throng"}, factions = {accord={name="Accord"}, throng={name="Throng"}}, capital_anchor = function() return {x=0,y=30,z=0} end}
	env.grug_classes = {registered_races = {}}
	for _, race in ipairs({"dwarf", "human", "elf", "undead", "orc", "troll"}) do
		env.grug_classes.registered_races[race] = {name=race,
			faction=(race == "dwarf" or race == "human" or race == "elf") and "accord" or "throng"}
	end
	env.dofile(repo .. "/mods/ITEMS/grug_nodes/init.lua")
	env.dofile(repo .. "/mods/ENTITIES/grug_mobs/crocodile.lua")
	env.dofile(repo .. "/mods/ENTITIES/grug_mobs/kraken.lua")
	env.dofile(repo .. "/mods/ENTITIES/grug_traders/vendors.lua")
	assert(api.registered_entities["grug_mobs:crocodile"].floats == true)
	assert(api.registered_entities["grug_mobs:kraken"].floats == true)
	local vendor_count = 0
	for name in pairs(env.grug_traders.vendors) do
		assert(api.registered_entities[name].floats == true)
		vendor_count = vendor_count + 1
	end
	-- Two faction Quartermasters, six race vendors and the TWELVE profession
	-- vendors of sockets contract section 8.4 (five from WP13 playtest round 3,
	-- seven from the wave-2 vocabulary lane of 2026-09-15).
	assert(vendor_count == 20)
	assert(api.is_creative_enabled("builder") and not api.is_creative_enabled("player"))
	assert(api.registered_nodes["default:torch_wall"].paramtype2 == "wallmounted")
	assert(api.registered_nodes["stairs:stair_pine_wood"].paramtype2 == "facedir")
	assert(api.registered_nodes["default:furnace"].on_timer)
	local close_chest
	for _, def in ipairs(lbms) do
		assert(def.name ~= "default:upgrade_chest_v2" and def.name ~= "default:convert_saplings_to_node_timer")
		if def.name == "default:close_chest_open" then close_chest = def end
	end
	assert(close_chest, "same-version chest recovery lost")
	local node = {name = "default:chest_open", param2 = 3}
	api.swap_node = function(_, replacement) node = replacement end
	close_chest.action({x=0,y=0,z=0}, node)
	assert(node.name == "default:chest" and node.param2 == 3)
	local shown
	api.show_formspec = function(_, _, form) shown = form end
	local book_fields = {owner = "author", title = "Current title", text = "Saved contents", page = "1", page_max = "1"}
	local book = {get_meta = function() return {to_table = function() return {fields = copy(book_fields)} end} end}
	api.registered_items["default:book_written"].on_use(book, {get_player_name = function() return "reader" end, get_wield_index = function() return 1 end})
	assert(shown:find("Current title", 1, true) and shown:find("Saved contents", 1, true))
	local mob_def = {type="npc", textures={{"fixture.png"}}, hp_min=10, hp_max=10, floats=true}
	env.mobs:register_mob("fixture:mob", mob_def)
	local entity_def = assert(api.registered_entities["fixture:mob"])
	local props = copy(entity_def.initial_properties)
	local object = {
		get_properties = function() return props end,
		set_properties = function(_, changes) for k,v in pairs(changes) do props[k]=copy(v) end end,
		get_pos = function() return {x=0,y=20,z=0} end,
		set_armor_groups = noop, set_yaw = noop, set_texture_mod = noop,
		get_velocity = function() return {x=0,y=0,z=0} end,
	}
	local function instance()
		local ent = setmetatable(copy(entity_def), getmetatable(entity_def))
		ent.object, ent.set_yaw, ent.set_animation = object, noop, noop
		return ent
	end
	local saved
	api.serialize = function(data) saved=copy(data); return "current-staticdata" end
	api.deserialize = function(text) return text == "current-staticdata" and copy(saved) or nil end
	local entity = instance()
	entity:on_activate("", 0)
	entity:update_tag("Current name")
	entity.health, entity.tamed, entity.owner = 7, true, "keeper"
	local staticdata = entity:get_staticdata()
	local reloaded = instance()
	reloaded:on_activate(staticdata, 20)
	reloaded:update_tag()
	assert(reloaded.health == 7 and reloaded.owner == "keeper" and reloaded.tamed)
	assert(reloaded._nametag == "Current name" and
		(props.nametag == nil or props.nametag == ""))
	assert(reloaded.textures[1] == "fixture.png" and reloaded.floats == true)
	local reset = instance()
	local reset_props = copy(props)
	local reset_object = copy(object)
	reset_object.get_luaentity = function() return reset end
	reset_object.get_properties = function() return reset_props end
	reset_object.set_properties = function(_, changes)
		for key, value in pairs(changes) do reset_props[key] = copy(value) end
	end
	reset.object = reset_object
	local removed = false
	object.get_luaentity = function() return reloaded end
	object.remove = function() removed = true end
	api.add_entity = function() return reset_object end
	api.registered_tools["mobs:mob_reset_stick"].on_use({}, {
		get_player_control = function() return {} end,
	}, {type="object", ref=object})
	assert(removed and reset._nametag == "Current name" and reset.owner == "keeper")
	local reset_saved = reset:get_staticdata()
	local reset_reloaded = instance()
	reset_reloaded:on_activate(reset_saved, 20)
	reset_reloaded:update_tag()
	assert(reset_reloaded._nametag == "Current name" and
		(props.nametag == nil or props.nametag == ""))
	local mount_actions, velocity = 0
	reloaded.driver = {
		get_player_control = function() return {up=true, LMB=true, sneak=true} end,
		get_look_dir = function() return {x=1,y=0,z=0} end,
		get_look_horizontal = function() return 0 end,
	}
	object.set_velocity = function(_, value) velocity = value end
	reloaded.do_mount_action = function() mount_actions = mount_actions + 1 end
	env.mobs.fly(reloaded, 0.1, 4, "walk", "stand")
	assert(velocity.x == 4 and velocity.y == 2 and mount_actions == 1)
	return "vendor_current_version\tPASS\tplayer-appearance,book,chest,creative,torch,stairs,furnace,mob-reload,mob-reset-reload,mount\n"
end
