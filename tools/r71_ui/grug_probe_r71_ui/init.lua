-- Disposable engine probe (Round 71 lane UI): the registrar's window as solo
-- player, leader and member, the invitation warning, the arrival and the maps
-- inside a box, with one real client. Never shipped: tools/r71_ui/capture.sh
-- stages it. The driver (character creation, SHOT / ack) is tools/r502_home's.
--
-- One client is one player, so the other members are stand-ins: grug_parties.view
-- and the invitation readers answer for a party that does not exist, and
-- core.get_player_by_name answers with two stand-in bodies for the minimap's
-- arrows. grug_expeditions.list offers the hidden test row. The window, the hooks,
-- the run and the box are the real ones; the rules are tools/r71_ui/portable_test.lua's.
local P = "[r71ui] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r71ui_settle") or "") or 5
local CAPITAL = "highcourt"
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0, shot = 1, waited = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r71ui_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- ---- Stand-ins ----------------------------------------------------------------
local fake_party
local real_view = grug_parties.view
grug_parties.view = function(player)
	local name = type(player) == "string" and player or player:get_player_name()
	if fake_party then
		for _, member in ipairs(fake_party.members) do
			if member.name == name then return fake_party end
		end
	end
	return real_view(player)
end
local real_in_party = grug_parties.in_party
grug_parties.in_party = function(player)
	return fake_party ~= nil or real_in_party(player)
end
local function member(name, level, online)
	return {name = name, level = level, online = online, class = "warrior", hp = 20, hp_max = 20}
end

local fake_invite = false
local real_newest, real_pending = grug_parties.newest_invitation, grug_parties.pending
grug_parties.newest_invitation = function(player)
	if fake_invite then return {inviter = "Bram", seconds = 118, more = 0} end
	return real_newest(player)
end
grug_parties.pending = function(player)
	if fake_invite then
		return {{inviter = "Bram", level = 24, expires_in = 118, party = nil}}
	end
	return real_pending(player)
end

local bodies = {}
local real_get = core.get_player_by_name
core.get_player_by_name = function(name) return bodies[name] or real_get(name) end
local function body(name, pos)
	return {get_pos = function() return vector.new(pos) end,
		get_look_horizontal = function() return 1 end, is_player = function() return true end,
		get_player_name = function() return name end}
end

grug_expeditions.list = function() return {grug_expeditions.definition("test_vault")} end

-- ---- Places -------------------------------------------------------------------
local function registrar_pos()
	for _, socket in ipairs(grug_core.settlement_sockets_at(CAPITAL)) do
		if socket.role == "expedition_registrar" then return socket.pos end
	end
end

local function registrar()
	for _, object in ipairs(core.get_objects_inside_radius(registrar_pos(), 6)) do
		local entity = object:get_luaentity()
		if entity and entity._grug_socket_role == "expedition_registrar" then return entity end
	end
end

local function open(player)
	core.close_formspec(NAME, "")
	return grug_expeditions.open_registrar(player, registrar())
end

local function press(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, grug_expeditions.registrar.FORMNAME, fields) then return end
	end
end

-- ---- The shots ----------------------------------------------------------------
local run
local SHOTS = {
	{name = "U1_solo", setup = function(player) fake_party = nil; open(player) end},
	{name = "U2_leader_warning", setup = function(player)
		fake_party = {id = 7001, leader = NAME, members = {member(NAME, 20, true),
			member("Bram", 19, true), member("Ilse", 24, true), member("Oskar", 21, false)}}
		open(player)
		press(player, {level = "3"})
	end},
	{name = "U3_member", setup = function(player)
		fake_party = {id = 7001, leader = "Bram", members = {member("Bram", 24, true),
			member(NAME, 20, true), member("Ilse", 24, true)}}
		open(player)
	end},
	{name = "U4_preparing", setup = function(player)
		fake_party = {id = 7001, leader = NAME, members = {member(NAME, 20, true),
			member("Bram", 19, true), member("Ilse", 24, true)}}
		open(player)
		press(player, {level = "3"})
		press(player, {open = "x"})
		run = grug_expeditions.run_of(player)
		log("CHECK run " .. tostring(run and run.state) .. " level " .. tostring(run and run.level))
	end, settle = 1},
	{name = "U5_ready", wait_ready = true, setup = function() end},
	{name = "U6_refused_below_entry", setup = function(player)
		-- The window with this player at 19 and +2: level 22 needs 20.
		grug_xp.set_xp(player, grug_xp.xp_for_level(19))
		open(player)
		press(player, {enter = "x"})
	end},
	{name = "U7_invitation_warning_hud", setup = function(player)
		core.close_formspec(NAME, grug_expeditions.registrar.FORMNAME)
		fake_party = nil
		grug_expeditions.end_run(run, "released")
		grug_xp.set_xp(player, grug_xp.xp_for_level(20))
		run = grug_expeditions.create(player, "test_vault", 0)
		fake_invite = true
	end, settle = 14},
	{name = "U8_invitation_warning_social", setup = function(player)
		sfinv.set_page(player, grug_parties.PAGE)
		core.show_formspec(NAME, "r71ui:social", player:get_inventory_formspec())
	end},
	{name = "U9_arrival", burst = true, setup = function(player)
		core.close_formspec(NAME, "r71ui:social")
		fake_invite = false
		grug_expeditions.end_run(run, "released")
		fake_party = {id = 7002, leader = NAME, members = {member(NAME, 20, true),
			member("Near", 20, true), member("Home", 20, true)}}
		run = grug_expeditions.create(player, "test_vault", 0)
		state.enter_when_ready = true
	end},
	{name = "U10_minimap_in_box", setup = function(player)
		local at = player:get_pos()
		bodies.Near = body("Near", {x = at.x + 14, y = at.y, z = at.z + 6})
		bodies.Home = body("Home", registrar_pos())
		log(("CHECK inside %s, slot %s, location %q, minimap texture %q"):format(
			core.pos_to_string(at, 1), tostring(grug_expeditions.slot_at(at)),
			(grug_map.location.text_of(player)), tostring(grug_map.minimap.texture_of(player))))
	end, settle = 8},
	{name = "U11_map_window", setup = function(player)
		grug_map.window.open(player)
	end},
}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.2 then return end
	local step = state.clock
	state.clock = 0
	local player = real_get(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, {faction_accord = "Accord"})
			submit(player, {race_human = "Human"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		grug_xp.set_xp(player, grug_xp.xp_for_level(20))
		local at = registrar_pos()
		core.emerge_area(vector.offset(at, -32, -16, -32), vector.offset(at, 32, 16, 32),
			function(_, _, remaining)
				if remaining == 0 then state.emerged = true end
			end)
		log("character complete, level " .. grug_xp.get_level(player))
		state.phase = "travel"
	elseif state.phase == "travel" then
		if not state.emerged then return end
		local at = registrar_pos()
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_pos(vector.offset(at, 2, 0.5, 0))
		player:set_look_horizontal(math.pi / 2)
		state.phase = "registrar"
	elseif state.phase == "registrar" then
		if not registrar() then return end
		log("READY the registrar stands at " .. core.pos_to_string(registrar_pos()))
		state.phase = "shoot"
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then
			log("setup " .. shot.name)
			shot.setup(player)
		end
		state.waited = state.waited + step
		-- The burst starts first: the client has no box yet.
		if state.enter_when_ready and run.state == "ready" then
			state.enter_when_ready = false
			log("SHOT " .. shot.name)
			core.after(1, function()
				open(player)
				press(player, {enter = "x"})
				log("CHECK enter pressed, the window's session " ..
					tostring(grug_expeditions.registrar.sessions[NAME] ~= nil))
			end)
		end
		if shot.wait_ready and run.state ~= "ready" then return end
		if not state.logged and not shot.burst and state.waited >= (shot.settle or SETTLE) then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif (state.logged or shot.burst) and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
