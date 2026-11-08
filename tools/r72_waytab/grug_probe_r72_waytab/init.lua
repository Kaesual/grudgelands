-- Disposable engine probe (Round 72 lane WAYTAB): the Expeditions tab of a capital
-- waystone with nothing to enter and with a run, entering from it, the waystone
-- window of a stone inside, a trip out to Dawnmere and back in by Dawnmere's tab,
-- with one real client. Never shipped: tools/r72_waytab/capture.sh stages it. The
-- driver (character creation, SHOT / ack) is tools/r71_ui's. The rules are
-- tools/r72_waytab/portable_test.lua's; a party of two needs two clients, so that
-- proof is the user's GUI check.
local P = "[r72waytab] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r72waytab_settle") or "") or 5
local E = grug_expeditions
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0, shot = 1, waited = 0}

-- The last form shown to the player, so a press reaches grug_home's dialog.
local shown_name = ""
local show = core.show_formspec
function core.show_formspec(name, formname, formspec)
	if name == NAME then shown_name = formname end
	return show(name, formname, formspec)
end

local function press(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, shown_name, fields) then return end
	end
end

-- Character creation, as tools/r71_ui's driver submits it.
local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r72waytab_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function stand_at(player, id)
	local stone = grug_home.waystone_pos(id)
	player:set_pos(vector.offset(stone, 2, -0.49, 0))
	player:set_look_horizontal(math.pi / 2)
	return stone
end

local function open_tab(player, id)
	core.close_formspec(NAME, "")
	grug_home.use_waystone(player, stand_at(player, id))
	press(player, {waystone_tab_2 = "Expeditions"})
end

local function where(player)
	local run = E.run_inside(player)
	return ("%s, inside run %s, origin %s"):format(core.pos_to_string(player:get_pos(), 1),
		tostring(run and run.id), tostring(E.saved_origin(player)))
end

local run
local SHOTS = {
	{name = "W1_nothing_to_enter", setup = function(player) open_tab(player, "highcourt") end},
	{name = "W2_listed", setup = function(player)
		run = assert(E.create(player, "test_vault", 4))
		state.wait_ready = true
	end, before = function(player) open_tab(player, "highcourt") end},
	{name = "W3_inner_window", setup = function(player)
		press(player, {["enter_" .. run.id] = "Enter"})
		state.wait_inside = run
	end, before = function(player)
		log("CHECK entered: " .. where(player))
		core.close_formspec(NAME, "")
		E.use_waystone(player, run.places.start_waystone)
	end},
	{name = "W4_out_at_dawnmere", setup = function(player)
		press(player, {go_dawnmere = "Travel"})
		state.wait_inside = false
	end, before = function(player)
		log(("CHECK out: %s; run %s, place kept %s"):format(where(player), run.state,
			tostring(run.entered[NAME] == true)))
		open_tab(player, "dawnmere")
	end},
	{name = "W5_back_in", setup = function(player)
		press(player, {["enter_" .. run.id] = "Enter"})
		state.wait_inside = run
	end, before = function(player) log("CHECK back in: " .. where(player)) end},
}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.2 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
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
		grug_xp.set_xp(player, grug_xp.xp_for_level(24))
		local at = grug_home.waystone_pos("highcourt")
		core.emerge_area(vector.offset(at, -32, -16, -32), vector.offset(at, 32, 16, 32),
			function(_, _, remaining)
				if remaining == 0 then state.emerged = true end
			end)
		log("character complete, level " .. grug_xp.get_level(player))
		state.phase = "travel"
	elseif state.phase == "travel" then
		if not state.emerged then return end
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		stand_at(player, "highcourt")
		log("READY at " .. core.pos_to_string(player:get_pos(), 1))
		state.phase = "shoot"
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("CHECK end: " .. where(player))
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 and not state.set then
			log("setup " .. shot.name)
			state.set = true
			shot.setup(player)
		end
		if state.wait_ready then
			if run.state ~= "ready" then return end
			state.wait_ready = nil
		end
		if state.wait_inside ~= nil then
			local inside = E.run_inside(player)
			if (state.wait_inside and inside ~= state.wait_inside) or
					(state.wait_inside == false and inside ~= nil) then
				state.waited = state.waited + step
				if state.waited > 60 then
					log("CHECK timed out waiting: " .. where(player))
					state.wait_inside = nil
				end
				return
			end
			state.wait_inside = nil
			state.waited = 0
		end
		if shot.before and not state.before then
			state.before = true
			shot.before(player)
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= (shot.settle or SETTLE) then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.set, state.before = 0, false, nil, nil
		end
	end
end)
