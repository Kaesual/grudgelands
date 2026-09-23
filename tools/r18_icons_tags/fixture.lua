return function(repo)
	local function read(path)
		local file = assert(io.open(repo .. "/" .. path, "rb"))
		local data = assert(file:read("*a"))
		file:close()
		return data
	end
	local ability_source = read("mods/PLAYER/grug_abilities/init.lua")
	local first = assert(ability_source:find("local function def_image", 1, true))
	local last = assert(ability_source:find("-- Native swing items", first, true))
	local skin_source = ("local SKIN_VERSION = 3\n" ..
		"local SKIN_TOKEN_KEY = \"grug_skin\"\n" ..
		ability_source:sub(first, last - 1)):gsub(
		"local function apply_skin", "function apply_skin", 1)
	local logs = {}
	local env = {
		core = {log = function(_, text) logs[#logs + 1] = text end},
		math = math, string = string, table = table, type = type,
		pairs = pairs, ipairs = ipairs, tostring = tostring,
	}
	env._G = env
	local chunk = assert(loadstring(skin_source, "@grug_abilities/init.lua:skin"))
	setfenv(chunk, env)
	chunk()

	local function stack(old_inventory)
		local values = {inventory_image = old_inventory or ""}
		local meta = {}
		function meta:get_string(key) return values[key] or "" end
		function meta:set_string(key, value) values[key] = value end
		return {get_meta = function() return meta end}, values
	end
	local sword, sword_meta = stack("old_weapon_overlay.png")
	assert(env.apply_skin(sword, {}, "sword.png"))
	assert(sword_meta.inventory_image == "" and sword_meta.wield_image == "sword.png")
	assert(not env.apply_skin(sword, {}, "sword.png"))
	assert(env.apply_skin(sword, {}, "axe.png") and sword_meta.wield_image == "axe.png")
	-- The Scout draw owns the temporary wield override; the next ordinary skin
	-- refresh restores the same equipped bow without touching the semantic icon.
	sword_meta.wield_image = "grug_abilities_bow_draw_2.png"
	sword_meta.grug_skin = ""
	assert(env.apply_skin(sword, {}, "axe.png") and sword_meta.wield_image == "axe.png")
	assert(env.apply_skin(sword, {}, "") and sword_meta.wield_image == "")
	local bad, bad_meta = stack()
	assert(env.apply_skin(bad, {}, "broken(") and bad_meta.wield_image == "")
	assert(#logs == 1)

	local ids = {}
	for _, path in ipairs({"mods/PLAYER/grug_abilities/kits.lua",
			"mods/PLAYER/grug_abilities/scout.lua"}) do
		for id in read(path):gmatch('id%s*=%s*"([a-z_]+)"') do ids[id] = true end
	end
	local icon_count = 0
	for id in pairs(ids) do
		local icon = "mods/PLAYER/grug_abilities/textures/grug_abilities_skill_" .. id .. ".png"
		local png = read(icon)
		assert(png:sub(1, 8) == "\137PNG\13\10\26\10", "bad ability icon: " .. id)
		icon_count = icon_count + 1
	end
	assert(icon_count == 22)
	assert(ability_source:find('inventory_image = skill_icon', 1, true))
	assert(ability_source:find('wield_image = skill_icon', 1, true))

	local entities, roles = {}, {}
	local cap_core = {registered_items = { ["gear:sword"] = {} },
		register_entity = function(name, def) entities[name] = def end,
		register_start_socket_role = function() end,
		deserialize = function(value) return value end,
		serialize = function(value) return value end,
		dir_to_yaw = function() return 0 end}
	local carrier_count, removed_count = 0, 0
	local carriers = setmetatable({}, {__mode = "k"})
	local cap_grug_core = {
		settlement_sockets_at = function() return {} end,
		create_tag_carrier = function(parent)
			if carriers[parent] and carriers[parent].valid then return carriers[parent] end
			carrier_count = carrier_count + 1
			local carrier = {valid = true}
			carriers[parent] = carrier
			return carrier
		end,
		set_tag_carrier_text = function(carrier, text) carrier.text = text end,
		remove_tag_carrier = function(carrier)
			if carrier and carrier.valid then carrier.valid = false; removed_count = removed_count + 1 end
		end,
	}
	local cap_grug_mobs = {register_start_socket_role = function(role, callback) roles[role] = callback end,
		start_npc_claim = function() return true end,
		start_npc_deactivate = function() end}
	local cap_grug_mounts = {MODELS = {human = {description = "Horse", mesh = "horse.b3d",
		textures = {"horse.png"}, visual_size = {x = 1, y = 1},
		collisionbox = {0, 0, 0, 0, 0, 0}, animation = {stand = {1, 1, 1}}}}}
	local cap_grug_gear = {weapon_item = function() return "gear:sword" end}
	local cap_env = {core = cap_core, grug_core = cap_grug_core,
		grug_mobs = cap_grug_mobs, grug_mounts = cap_grug_mounts,
		grug_gear = cap_grug_gear, math = math, type = type, tonumber = tonumber,
		ipairs = ipairs, pairs = pairs, assert = assert}
	cap_env._G = cap_env
	local cap_chunk = assert(loadfile(repo .. "/mods/ENTITIES/grug_mobs/capital_displays.lua"))
	setfenv(cap_chunk, cap_env)
	cap_chunk()
	local def = assert(entities["grug_mobs:capital_display"])
	local properties, pos = {}, {x = 0, y = 1, z = 0}
	local object = {set_properties = function(_, value) properties = value end,
		set_armor_groups = function() end, set_yaw = function() end,
		set_animation = function() end, get_pos = function() return pos end,
		set_pos = function(_, value) pos = value end}
	local display = setmetatable({object = object, _grug_socket_role = "mount_display",
		_grug_display_race = "human", _grug_display_tag = "2",
		_grug_display_floor = 1, _grug_start = "highcourt", _grug_socket = "mount",
		_grug_placed_at = 1}, {__index = def})
	cap_grug_mobs.configure_capital_display(display)
	assert(properties.nametag == "" and display._grug_tag_carrier.text == "Horse")
	cap_grug_mobs.configure_capital_display(display)
	assert(carrier_count == 1, "reconfigure duplicated stable tag")
	display._grug_socket_role = "gear_display"
	display._grug_display_tag = "weapon"
	cap_grug_mobs.configure_capital_display(display)
	assert(removed_count == 1 and display._grug_tag_carrier == nil)
	display._grug_socket_role = "mount_display"
	display._grug_display_tag = "2"
	cap_grug_mobs.configure_capital_display(display)
	display:on_deactivate(false)
	assert(removed_count == 2 and display._grug_tag_carrier == nil)
	assert(roles.mount_display and roles.gear_display)
	return "r18_icons_tags_v1\ticons=22\twield=weapon_swap_empty_bow_contract" ..
		"\ttags=dedup_remove_npc_peaceful\n"
end
