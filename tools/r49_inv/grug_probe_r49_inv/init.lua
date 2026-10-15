-- Disposable engine probe (Round 49 lane INV): the starter hotbar, the
-- Inventory tab with the Claim Stone in a bag, and the Housing Steward's
-- window in each state, for screenshots. Never shipped:
-- tools/r49_inv/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) follows tools/r48_mail's probe.
--
-- The Steward's window is opened through grug_housing.open_manager with a
-- stand-in for the NPC on its real socket in the Accord capital (the
-- dialog's checks: role, capital, socket, talking range); the player stands
-- two nodes beside it with gravity off.

local P = "[r49inv] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r49inv_settle") or "") or 3
local STONE = "grug_housing:claim_stone"

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}
local steward

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r49inv_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function hotbar(player)
	local inv, out = player:get_inventory(), {}
	for slot = 1, 8 do
		local stack = inv:get_stack("main", slot)
		out[#out + 1] = slot .. "=" .. stack:get_name() .. " " .. stack:get_count()
	end
	return table.concat(out, " ")
end

local function where_stone(player)
	local inv = player:get_inventory()
	for list in pairs(inv:get_lists()) do
		for index = 1, inv:get_size(list) do
			if inv:get_stack(list, index):get_name() == STONE then return list .. "#" .. index end
		end
	end
	return "none"
end

local function open_steward(player)
	local ok = grug_housing.open_manager(player, steward)
	local can, reason = grug_housing.can_receive_stone(player)
	log("steward opened " .. tostring(ok) .. " can_receive " .. tostring(can) ..
		" reason " .. tostring(reason) .. " stone " .. where_stone(player))
end

local function set_level(player, level)
	grug_xp.set_xp(player, grug_xp.xp_for_level(level))
	log("level " .. grug_xp.get_level(player))
end

local SHOTS = {
	{name = "H1_starter_hotbar", run = function(player)
		core.close_formspec(NAME, "")
		log("hotbar " .. hotbar(player))
	end},
	{name = "S1_below_level_20", run = function(player)
		open_steward(player)
	end},
	{name = "S2_button", run = function(player)
		set_level(player, 20)
		open_steward(player)
	end},
	{name = "S3_after_hand_out", run = function(player)
		submit(player, "grug_housing:manager", {receive = "Receive Claim Stone"})
		log("steward after the click: stone " .. where_stone(player))
	end},
	{name = "I1_stone_in_bag", run = function(player)
		core.close_formspec(NAME, "grug_housing:manager")
		local inv = player:get_inventory()
		inv:set_stack("grug_bag1", 1, "grug_inventory:bag_small")
		inv:set_size("grug_bag1_content", 4)
		local from = where_stone(player)
		local list, index = from:match("^(.-)#(%d+)$")
		if list then
			inv:set_stack(list, tonumber(index), "")
			inv:set_stack("grug_bag1_content", 2, STONE)
		end
		log("stone moved from " .. from .. " to " .. where_stone(player))
		sfinv.set_page(player, "grug_inventory:inventory")
		core.show_formspec(NAME, "grug_probe_r49_inv:inventory",
			sfinv.get_formspec(player, sfinv.get_or_create_context(player)))
	end},
	{name = "S4_stone_in_bag", run = function(player)
		core.close_formspec(NAME, "grug_probe_r49_inv:inventory")
		open_steward(player)
	end},
	{name = "S5_stone_placed", run = function(player)
		core.close_formspec(NAME, "grug_housing:manager")
		player:get_inventory():set_stack("grug_bag1_content", 2, "")
		-- The registry's placed state (no node: the window reads the model).
		grug_housing.model.create(NAME, vector.offset(player:get_pos(), 0, -3, 40))
		open_steward(player)
	end},
	{name = "S6_full_inventory", run = function(player)
		core.close_formspec(NAME, "grug_housing:manager")
		-- The stone's periodic check may already have dropped the claim
		-- (no node at its centre: "vanished"); either way none is placed.
		local claim = grug_housing.model.player_claim(NAME)
		if claim then grug_housing.model.remove(claim, "removed") end
		local inv = player:get_inventory()
		for _, list in ipairs({"main", "grug_bag1_content"}) do
			for index = 1, inv:get_size(list) do
				if inv:get_stack(list, index):is_empty() then
					inv:set_stack(list, index, "default:cobble 99")
				end
			end
		end
		open_steward(player)
		submit(player, "grug_housing:manager", {receive = "Receive Claim Stone"})
		log("steward full inventory: stone " .. where_stone(player))
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
		log("hotbar " .. hotbar(player))
		local socket
		for _, row in ipairs(grug_housing.manager_sockets()) do
			if row.settlement == "highcourt" then socket = row end
		end
		steward = {_grug_socket_role = "housing_manager", _grug_start = socket.settlement,
			_grug_socket = socket.socket, object = {get_pos = function() return socket.pos end}}
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_pos(vector.offset(socket.pos, 2, 0, 0))
		log("steward socket " .. core.pos_to_string(socket.pos))
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
		log("READY")
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
			shot.run(player)
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
