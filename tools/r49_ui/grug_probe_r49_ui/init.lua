-- Disposable engine probe (Round 49 lane UI): the mailbox Write tab with
-- the postage rule, the result line of a Send, and the vendor's Sell tab with
-- a row's tooltip, for screenshots. Never shipped: tools/r49_ui/capture.sh
-- stages it through tools/luanti_headless.sh and connects one real client.
-- The driver (character creation, SHOT / ack handshake) follows
-- tools/r48_mail's probe; a "HOVER" line asks the script to move the pointer
-- onto a form position (form units) before the shot.

local P = "[r49ui] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r49ui_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}
local mailbox, vendor_pos

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function mail_fields(player, fields)
	local session = grug_mail.session(NAME)
	submit(player, session and session.formname or "", fields)
end

-- The last trade form sent (to log where the quality row's tooltip sits).
local trade_form = ""
local show_formspec = core.show_formspec
core.show_formspec = function(name, formname, formspec)
	if formname == "grug_traders:trade" then trade_form = formspec end
	return show_formspec(name, formname, formspec)
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r49ui_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function clear_carried(player)
	local inv = player:get_inventory()
	for _, list in ipairs(grug_inventory.carried_lists(inv)) do
		for index = 1, inv:get_size(list) do inv:set_stack(list, index, ItemStack("")) end
	end
end

-- The Sell tab's rows: a blue bronze sword (one enchant), 143 Cobblestone
-- (a lot row) and apples.
local function sell_inventory(player)
	clear_carried(player)
	local inv = player:get_inventory()
	local sword = ItemStack("grug_gear:sword_bronze")
	log("roll_enchants " .. tostring(grug_items.roll_enchants(sword, 10, 1, 7)))
	inv:set_stack("main", 9, sword)
	inv:set_stack("main", 10, ItemStack("default:cobble 99"))
	inv:set_stack("main", 11, ItemStack("default:cobble 44"))
	inv:set_stack("main", 12, ItemStack("default:apple 7"))
	log("sword description: " .. sword:get_description():gsub("\n", " / "))
end

local SHOTS = {
	{name = "W1_write_rule", run = function(player)
		local node = core.get_node(mailbox)
		core.registered_nodes[node.name].on_rightclick(mailbox, node, player, ItemStack(""))
		local inv = player:get_inventory()
		inv:set_stack(grug_mail.ATTACH_LIST, 1, ItemStack("grug_materials:iron_bar 12"))
		inv:set_stack(grug_mail.ATTACH_LIST, 2, ItemStack("default:apple 5"))
		local session = grug_mail.session(NAME)
		session.draft = {to = "Brakka", subject = "Ingots for the forge",
			body = "Here are the ingots and some apples.\n\nSee you at the forge."}
		mail_fields(player, {grug_mail_tab = "3"})
	end},
	{name = "W2_write_sent", run = function(player)
		local session = grug_mail.session(NAME)
		local draft = session.draft
		mail_fields(player, {mail_to = draft.to, mail_subject = draft.subject,
			mail_body = draft.body, ["write_send_" .. session.draw] = "Send"})
		log("status: " .. tostring(grug_mail.session(NAME).status))
	end},
	{name = "S1_sell_tooltip", hover = {14, 10.2, 1.05, 2.85}, run = function(player)
		mail_fields(player, {quit = "true"})
		core.close_formspec(NAME, "")
		sell_inventory(player)
		grug_traders.open(player, "grug_traders:vendor_general_accord", vendor_pos, "accord")
		submit(player, "grug_traders:trade", {mode_sell = "Sell"})
		for line in trade_form:gmatch("tooltip%[[^%]]*") do
			log("trade " .. line:sub(1, 80):gsub("\n", " / "))
		end
	end},
	{name = "S2_sell_lot_tooltip", hover = {14, 10.2, 1.05, 3.65}, run = function() end},
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
		mailbox = vector.offset(socket.pos, 3, 0, 0)
		local stand = vector.offset(socket.pos, 3, 0, 2)
		vendor_pos = stand
		state.phase = "emerge"
		core.emerge_area(vector.offset(mailbox, -8, -4, -8), vector.offset(mailbox, 8, 8, 8),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				if core.get_node(mailbox).name ~= "grug_mapgen:mailbox" then
					core.set_node(mailbox, {name = "grug_mapgen:mailbox"})
				end
				player:set_pos(stand)
				grug_money.set(player, 500)
				-- A recipient of the player's faction for the Send.
				grug_mail.store.index_player("Brakka", "accord")
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
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			if shot.hover then
				log(("HOVER %s %s %s %s %s"):format(shot.name, unpack(shot.hover)))
			end
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
