-- Disposable real-client capture driver. Only staged in a throwaway game/world.
-- Game forms and data are real; the platform and NPC ObjectRef stand-in make
-- the same scene repeatable without depending on spawn timing or mouse input.
local NAME, P = "grugcap", "[uifidelity] "
local state = {phase = "wait", clock = 0, index = 1}
local settle = tonumber(core.settings:get("uifidelity_settle")) or 3
local base, chest
local scenes = {"dark", "bright"}
local pages = {"inventory", "achievements", "talents", "crafting", "chest", "quest", "map", "privileged"}
local ids = {inventory = "grug_inventory:inventory", achievements = "grug_inventory:character",
	talents = "grug_classes:talents", crafting = "sfinv:crafting", privileged = "grug_inventory:inventory"}
local function log(s) core.log("action", P .. s) end
local function submit(player, form, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, form, fields) then return end
	end
end
local protected = grug_core.interaction_protected
function grug_core.interaction_protected(pos, name)
	if chest and vector.equals(vector.round(pos), chest) then return false end
	return protected(pos, name)
end
local function scene(player, bright)
	for x = -18, 18 do for z = -18, 18 do
		core.set_node(vector.offset(base, x, -1, z), {name = bright and "default:snowblock" or "default:stone"})
	end end
	core.set_timeofday(bright and 0.5 or 0)
	player:override_day_night_ratio(bright and 1 or 0.18)
	player:set_sky({type = "plain", base_color = bright and "#d5e4ef" or "#101824", clouds = false})
	player:set_pos(base)
	player:set_look_horizontal(0)
	player:set_look_vertical(0.28)
end
local function quest(player)
	local sockets = {}
	for socket in pairs(grug_quests.npc_by_socket) do sockets[#sockets + 1] = socket end
	table.sort(sockets)
	for _, socket in ipairs(sockets) do
		local id = grug_quests.npc_by_socket[socket]
		local npc = grug_quests.registered_npcs[id]
		if socket:match("^dawnmere/") and grug_factions.serves(npc.faction, player) and
				#grug_quests.npc_quests(player, id) > 0 then
			local start, key = socket:match("^(.-)/(.*)$")
			local entity = {_grug_start = start, _grug_socket = key,
				object = {is_valid = function() return true end, get_pos = function() return base end}}
			assert(grug_quests.open_npc(player, entity))
			log("quest giver " .. id)
			return
		end
	end
	error("No real human-start quest giver available")
end
local function show(player, kind)
	-- Close through existing owners before changing the view.
	submit(player, "grug_map:window", {quit = "true"})
	submit(player, "grug_quests:dialogue", {quit = "true"})
	core.close_formspec(NAME, "")
	core.set_player_privs(NAME, {interact = true, shout = true,
		creative = kind == "privileged" or nil, mail_admin = kind == "privileged" or nil})
	if ids[kind] then
		sfinv.set_page(player, ids[kind])
		local ctx = sfinv.get_or_create_context(player)
		if kind == "achievements" then ctx.grug_character_tab = "achievements" end
		local fs = sfinv.get_formspec(player, ctx)
		core.show_formspec(NAME, "", fs)
		log(kind .. " bytes=" .. #fs)
	elseif kind == "chest" then
		local node = core.get_node(chest)
		core.registered_nodes[node.name].on_rightclick(chest, node, player, ItemStack(""))
	elseif kind == "quest" then quest(player)
	elseif kind == "map" then grug_map.window.open(player) end
end
core.register_globalstep(function(dt)
	state.clock = state.clock + dt
	if state.clock < 0.5 then return end
	local elapsed = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		state.phase = "emerge"
		base = vector.offset(vector.round(player:get_pos()), 0, 20, 0)
		core.emerge_area(vector.offset(base, -20, -2, -20), vector.offset(base, 20, 5, 20), function(_, _, left)
			if left ~= 0 then return end
			player = core.get_player_by_name(NAME)
			if not player then return end
			player:set_physics_override({gravity = 0, speed = 0, jump = 0})
			player:hud_set_flags({hotbar = false, crosshair = false, wielditem = false, minimap = false})
			grug_xp.set_xp(player, grug_xp.xp_for_level(30))
			grug_jobs.admin_set(player, "weaponsmith", 3, 1)
			local inv = player:get_inventory()
			for _, item in ipairs({"default:wood 32", "default:cobble 48", "default:coal_lump 24",
				"default:stick 12", "default:apple 8", "default:paper 5", "default:book 2"}) do
				inv:add_item("main", item)
			end
			chest = vector.offset(base, 2, 0, 1)
			core.set_node(chest, {name = "default:chest"})
			core.get_meta(chest):get_inventory():add_item("main", "default:wood 48")
			state.phase = "shots"
			log("READY")
		end)
	elseif state.phase == "shots" then
		local index = state.index
		local scene_id = math.floor((index - 1) / #pages) + 1
		if not scenes[scene_id] then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("fidelity capture complete", false, 0)
			return
		end
		local page = pages[(index - 1) % #pages + 1]
		local shot = scenes[scene_id] .. "_" .. page
		if not state.ran then
			if (index - 1) % #pages == 0 then scene(player, scene_id == 2) end
			show(player, page)
			state.ran, state.waited = true, 0
		end
		state.waited = state.waited + elapsed
		if not state.logged and state.waited >= settle then
			state.logged = true
			log("SHOT " .. shot)
		elseif state.logged then
			local file = io.open(core.get_worldpath() .. "/uifidelity_ack", "r")
			local ack = file and file:read("*l")
			if file then file:close() end
			if ack == shot then
				state.index = index + 1
				state.ran, state.logged = false, false
			end
		end
	end
end)
