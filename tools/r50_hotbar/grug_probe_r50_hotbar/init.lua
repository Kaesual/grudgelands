-- Disposable engine probe (Round 50 lane HOTBAR): the hotbar switch with
-- layout B shown, for screenshots. Never shipped:
-- tools/r50_hotbar/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) follows tools/r491_view's probe.
--
-- A new Warrior (the kit on A), apples and torches on A; a switch to B
-- (through the Inventory page's own handler, as a click would), then a
-- skill and items placed on B. Shots: the Inventory page (the player's own
-- inventory formspec, shown as a form), a chest beside the human start's
-- waystone (its own right-click) and the quickbar (E).

local P = "[r50hotbar] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r50hotbar_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}
local chest_pos

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r50hotbar_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function row(inv, list)
	local out = {}
	for i = 1, 8 do out[#out + 1] = inv:get_stack(list, i):to_string() end
	return table.concat(out, "|")
end

local SHOTS = {
	{name = "H1_inventory_B", run = function(player)
		local context = sfinv.get_or_create_context(player)
		sfinv.set_page(player, "grug_inventory:inventory")
		core.show_formspec(NAME, "r50hotbar:inventory", sfinv.get_formspec(player, context))
	end},
	{name = "H2_chest_B", run = function(player)
		core.close_formspec(NAME, "")
		local node = core.get_node(chest_pos)
		core.registered_nodes[node.name].on_rightclick(chest_pos, node, player, ItemStack(""))
	end},
	{name = "H3_quickbar_B", run = function(player)
		core.close_formspec(NAME, "")
		grug_quickbar.open(player)
	end},
}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
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
		core.close_formspec(NAME, "")
		local socket
		for _, entry in ipairs(grug_core.settlement_sockets("human")) do
			if entry.role == "waypoint" then socket = entry end
		end
		local base = vector.offset(socket.pos, 3, 0, 0)
		local stand = vector.offset(socket.pos, 3, 0, 3)
		state.phase = "emerge"
		core.emerge_area(vector.offset(base, -8, -4, -8), vector.offset(base, 12, 8, 8),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				core.set_node(base, {name = "default:chest"})
				chest_pos = base
				local chest = core.get_meta(base):get_inventory()
				chest:set_stack("main", 1, ItemStack("default:cobble 20"))
				player:set_pos(stand)
				player:set_look_horizontal(math.pi)
				player:set_look_vertical(0.3)
				local inv = player:get_inventory()
				log("A before the switch: " .. row(inv, "main") .. " (layout " ..
					grug_inventory.active_hotbar(player) .. ", B " .. row(inv, grug_inventory.HOTBAR_STORE) .. ")")
				-- The switch through the Inventory page's handler (sfinv), as a
				-- click on "B" would send it.
				sfinv.set_page(player, "grug_inventory:inventory")
				submit(player, "", {grug_hotbar_b = "B"})
				inv:set_stack("main", 1, ItemStack("grug_abilities:strike"))
				inv:set_stack("main", 2, ItemStack("default:torch 12"))
				inv:set_stack("main", 4, ItemStack("default:apple 5"))
				inv:set_stack("main", 9, ItemStack("default:dirt 30"))
				grug_abilities.normalize_kit(player)
				log("B shown: " .. row(inv, "main") .. " (layout " ..
					grug_inventory.active_hotbar(player) .. "); A hidden: " ..
					row(inv, grug_inventory.HOTBAR_STORE))
				state.phase = "shoot"
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
				log("READY")
			end)
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran = true
			player:set_physics_override({gravity = 0, speed = 0, jump = 0})
			shot.run(player)
			log("ran " .. shot.name)
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
