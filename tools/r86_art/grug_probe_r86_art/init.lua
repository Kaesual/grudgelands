-- Disposable engine probe (Round 86 lane ART): the Claim Stone's new look
-- ("Under One Roof") in the real engine, for tools/r86_art/capture.sh. Never
-- shipped. The driver (character creation, SHOT / HOVER / ack handshake)
-- follows tools/r86_stone's probe.
--
-- Once the character stands beside the human start's waystone, the probe
-- lays a grass patch and sets the six stone nodes on it in a row (personal
-- draft, fuelled, empty; a gap; account draft, fuelled, empty), doors toward
-- -Z (param2 0, as every stone of a 0.85.0 world), and one fuelled personal
-- stone turned toward +X (param2 1) behind them. Shots: the row from the
-- front and from an angle by day and at night, close-ups of each kind, a
-- fuelled stone in a small built room, each item in the hand, both items in
-- the inventory with a tooltip each, the player's own activated stone on
-- the map (Travel layer) and the minimap, and a stone set by stone.lua's
-- facing rule for a placer on its -X side, seen from there. It logs each
-- check ("check ... ok"). The setting r86art_only picks shots by name.
-- Fix round 1 (F1-F7): the row and a closed room at night with the new
-- light, the pointed box of both kinds, and the player's own stone form at
-- GUI scale 1.5 and, after the client restart "SWITCH", at 1.

local P = "[r86art] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r86art_settle") or "") or 3
-- r86art_only: a comma list of shot names to take (default every shot).
local ONLY = core.settings:get("r86art_only") or ""

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r86art_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function expect(ok, what)
	log(("check %s %s"):format(what, ok and "ok" or "FAIL"))
end

local H = grug_housing
local base, row_z
local ROW = {
	{-4, H.DRAFT_STONE}, {-3, H.STONE_ITEM}, {-2, H.EMPTY_STONE},
	{2, "grug_housing:account_stone_draft"}, {3, H.ACCOUNT_ITEM},
	{4, "grug_housing:account_stone_empty"},
}

local function at(dx, dy, dz) return vector.offset(base, dx, dy, dz) end

local function fill(from, to, name)
	for x = from.x, to.x do
		for y = from.y, to.y do
			for z = from.z, to.z do core.set_node({x = x, y = y, z = z}, {name = name}) end
		end
	end
end

local function view(player, pos, yaw, pitch)
	player:set_pos(pos)
	player:set_look_horizontal(yaw)
	player:set_look_vertical(pitch)
end

local function day() core.set_timeofday(0.5) end

local function hold(player, item)
	local inv = player:get_inventory()
	-- main[1] is the first hotbar slot, the one in hand after the join.
	inv:set_stack("main", 1, ItemStack(item))
end

local function layout()
	-- A grass patch with three free nodes above, the row on it.
	fill(at(-7, -1, row_z - 6), at(7, -1, row_z + 4), "default:dirt_with_grass")
	fill(at(-7, 0, row_z - 6), at(7, 4, row_z + 4), "air")
	for _, entry in ipairs(ROW) do
		core.set_node(at(entry[1], 0, row_z), {name = entry[2], param2 = 0})
	end
	core.set_node(at(0, 0, row_z + 2), {name = H.STONE_ITEM, param2 = 1})
	-- A small room to the south: wooden walls, a cobble roof, the front open.
	local room = row_z - 12
	fill(at(-3, -1, room - 3), at(3, -1, room + 3), "default:wood")
	fill(at(-3, 0, room - 3), at(3, 4, room + 3), "air")
	fill(at(-3, 0, room - 3), at(3, 2, room - 3), "default:wood")
	fill(at(-3, 0, room - 3), at(-3, 2, room + 2), "default:wood")
	fill(at(3, 0, room - 3), at(3, 2, room + 2), "default:wood")
	fill(at(-3, 3, room - 3), at(3, 3, room + 2), "default:cobble")
	core.set_node(at(-3, 1, room - 1), {name = "default:glass"})
	core.set_node(at(3, 1, room - 1), {name = "default:glass"})
	core.set_node(at(0, 0, room - 1), {name = H.STONE_ITEM, param2 = 0})
	core.set_node(at(2, 0, room - 2), {name = "default:wood"})
	core.set_node(at(-2, 0, room - 2), {name = "default:cobble"})
	core.set_node(at(-2, 1, room - 2), {name = "default:cobble"})
	return room
end

local room
local claim_pos

local SHOTS = {
	{name = "A1_row_front_day", run = function(player)
		day()
		view(player, at(0, 0, row_z - 4.5), 0, 0.32)
		local ok = true
		for _, entry in ipairs(ROW) do
			ok = ok and core.get_node(at(entry[1], 0, row_z)).name == entry[2]
		end
		expect(ok, "A1 the six nodes stand")
	end},
	{name = "A2_row_angle_day", run = function(player)
		day()
		view(player, at(5.5, 1.2, row_z - 4.5), math.atan2(5.5, 4.5), 0.38)
	end},
	{name = "A3_personal_close_day", run = function(player)
		day()
		view(player, at(-1.2, 0.2, row_z - 1.9), math.atan2(1.8, 1.9), 0.55)
	end},
	{name = "A4_account_close_day", run = function(player)
		day()
		view(player, at(4.8, 0.2, row_z - 1.9), math.atan2(1.8, 1.9), 0.55)
	end},
	{name = "A5_row_front_night", run = function(player)
		core.set_timeofday(0)
		view(player, at(0, 0, row_z - 4.5), 0, 0.32)
	end},
	{name = "A6_row_angle_night", run = function(player)
		core.set_timeofday(0)
		view(player, at(5.5, 1.2, row_z - 4.5), math.atan2(5.5, 4.5), 0.38)
	end},
	{name = "A7_back_and_turned", run = function(player)
		-- From behind: the row's back walls, the turned stone's door toward +X.
		day()
		view(player, at(2.5, 0.6, row_z + 4), math.atan2(2.5, -2), 0.5)
	end},
	{name = "A8_room", run = function(player)
		day()
		view(player, at(0, 0, room + 3.5), math.pi, 0.38)
	end},
	{name = "A9_hand_personal", run = function(player)
		day()
		hold(player, H.STONE_ITEM)
		view(player, at(0, 0, row_z - 4.5), 0, 0.2)
	end},
	{name = "A10_hand_account", run = function(player)
		hold(player, H.ACCOUNT_ITEM)
	end},
	-- The tooltips: main slot 1 (x 0.5 + 0.5) and slot 2 (x 0.5 + 1.25 + 0.5), y 0.7 + 0.5.
	{name = "A11_inventory_personal", hover = {11, 3, 1.0, 1.2}, run = function(player)
		local inv = player:get_inventory()
		inv:set_stack("main", 1, ItemStack(H.STONE_ITEM))
		inv:set_stack("main", 2, ItemStack(H.ACCOUNT_ITEM))
		core.show_formspec(NAME, "grug_probe_r86_art:inv", "formspec_version[6]size[11,3]" ..
			"label[0.5,0.3;Claim Stone and Account Claim Stone]" ..
			"list[current_player;main;0.5,0.7;8,1;]")
	end},
	{name = "A12_inventory_account", hover = {11, 3, 2.25, 1.2}, run = function() end},
	{name = "A13_map", run = function(player)
		core.close_formspec(NAME, "")
		-- The player's own activated stone: the fuelled personal stone of the row.
		claim_pos = at(-3, 0, row_z)
		local claim = H.model.create(NAME, claim_pos, "")
		local lumps = H.model.activate(claim, 20)
		H.sync_stone_node(claim)
		local row = grug_home.claim_waypoint(player)
		expect(lumps > 0 and row ~= nil and row.texture == H.STONE_TEXTURE,
			"A13 the activated stone is a waypoint with STONE_TEXTURE")
		-- Away from the stone (above the roofs), so its marker and the
		-- player's arrow do not cover each other; the Travel layer.
		view(player, at(-3, 12, row_z - 30), 0, 0.2)
		grug_map.window.open(player)
		for _ = 1, 3 do grug_map.window.handle_fields(player, {grug_map_zoom_in = "+"}) end
		grug_map.window.handle_fields(player, {grug_map_layer_towns = "Travel"})
	end},
	{name = "A14_minimap", run = function(player)
		core.close_formspec(NAME, grug_map.window.FORMNAME)
		grug_map.minimap.set_enabled(player, true)
		view(player, at(-3, 12, row_z - 20), 0, 0.2)
	end},
	{name = "A15_faces_placer", run = function(player)
		-- A stone set with stone.lua's placement rule for a placer on its -X
		-- side: the door must face that placer (the camera).
		local stone, from = at(-5, 0, row_z - 3), at(-7, 0, row_z - 3)
		local param2 = core.dir_to_fourdir({x = stone.x - from.x, y = 0, z = stone.z - from.z})
		core.set_node(stone, {name = H.STONE_ITEM, param2 = param2})
		expect(param2 == 1, "A15 param2 1 for a placer on the -X side")
		day()
		view(player, from, -math.pi / 2, 0.5)
	end},
	-- Fix round 1 (ruling 20: only the fuelled stone gives light, level 8;
	-- the pointed box around the house; the stone form at two GUI scales).
	{name = "F1_row_front_night", run = function(player)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(0)
		view(player, at(0, 0, row_z - 4.5), 0, 0.32)
	end},
	{name = "F2_row_angle_night", run = function(player)
		core.set_timeofday(0)
		view(player, at(5.5, 1.2, row_z - 4.5), math.atan2(5.5, 4.5), 0.38)
	end},
	{name = "F3_dark_room", run = function(player)
		-- The room closed (front wall, no windows), its stone's door toward
		-- the camera; night, so the stone is the only light.
		fill(at(-3, 0, room + 3), at(3, 2, room + 3), "default:wood")
		fill(at(-3, 3, room + 3), at(3, 3, room + 3), "default:cobble")
		core.set_node(at(-3, 1, room - 1), {name = "default:wood"})
		core.set_node(at(3, 1, room - 1), {name = "default:wood"})
		core.swap_node(at(0, 0, room - 1), {name = H.STONE_ITEM, param2 = 2})
		core.set_timeofday(0)
		view(player, at(0, 0, room + 2), math.pi, 0.4)
	end},
	{name = "F4_outline_personal", run = function(player)
		day()
		core.set_node(at(-5, 0, row_z - 3), {name = H.STONE_ITEM, param2 = 1})
		view(player, at(-7, 0, row_z - 3), -math.pi / 2, 0.7)
	end},
	{name = "F5_outline_account", run = function(player)
		core.set_node(at(-5, 0, row_z - 3), {name = H.ACCOUNT_ITEM, param2 = 1})
		view(player, at(-7, 0, row_z - 3), -math.pi / 2, 0.7)
	end},
	{name = "F6_form_scale15", settle = 5, run = function(player)
		-- The player's own activated stone, inside its 12-hour pick-up wait.
		local claim = H.model.claim_at(at(-3, 0, row_z))
		if not claim then
			claim = H.model.create(NAME, at(-3, 0, row_z), "")
			H.model.activate(claim, 20)
			H.sync_stone_node(claim)
		end
		expect(H.model.is_active(claim) and H.model.pickup_wait(claim) > 0,
			"F6 an activated stone inside its pick-up wait")
		view(player, at(-3, 0, row_z - 2), 0, 0.4)
		H.open_stone_interface(player, H.model.claim_at(at(-3, 0, row_z)))
	end},
	{name = "SWITCH", switch = true},
	{name = "F7_form_scale1", settle = 10, run = function(player)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		view(player, at(-3, 0, row_z - 2), 0, 0.4)
		H.open_stone_interface(player, H.model.claim_at(at(-3, 0, row_z)))
	end},
}
if ONLY ~= "" then
	local wanted, kept = {}, {}
	for name in ONLY:gmatch("[^,%s]+") do wanted[name] = true end
	for _, shot in ipairs(SHOTS) do
		if wanted[shot.name] then kept[#kept + 1] = shot end
	end
	SHOTS = kept
end

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
		base = vector.offset(socket.pos, 3, 0, 0)
		row_z = 6
		state.phase = "emerge"
		core.emerge_area(vector.offset(base, -12, -4, -40), vector.offset(base, 12, 8, 14),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				player:set_physics_override({gravity = 0, speed = 0, jump = 0})
				room = layout()
				log("READY")
				state.phase = "shoot"
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
			end)
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if shot.switch then
			-- capture.sh restarts the client at its second GUI scale; on
			-- with the next shot once the new client's player is in.
			if not state.ran then
				state.ran, state.old = true, player
				log("SWITCH")
			elseif read_ack() == "SWITCH" and player ~= state.old then
				state.shot = state.shot + 1
				state.waited, state.logged, state.ran = 0, false, false
			end
			return
		end
		if not state.ran then
			state.ran = true
			shot.run(player)
			log("ran " .. shot.name)
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= (shot.settle or SETTLE) then
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
