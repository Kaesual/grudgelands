-- Disposable engine probe (Round 66 lane MAP): the minimap and the map
-- window's PvP layer for screenshots (marker size, camps by faction). Never
-- shipped: tools/r66_map/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) is tools/r65_hud's probe.
--
-- Shot 1: the minimap over the Accord war camp nearest the world's middle
-- (its Throng neighbour in the same battleground often inside the window);
-- shot 2: the map window on the PvP layer (both factions' war camps and
-- the camps under construction). The window information the server holds
-- and the marker sizes it gives are logged.

local P = "[r66map] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r66map_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r66map_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function camp()
	local best
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		if type(row.slot) == "string" and row.slot:match("^pvp_accord_") then
			local d = math.abs(row.anchor.x) + math.abs(row.anchor.z)
			if not best or d < best.d then best = {d = d, row = row} end
		end
	end
	return best and best.row
end

local SHOTS = {
	{name = "M1_minimap_war_camp", run = function(player)
		local row = assert(camp(), "no Accord war camp")
		player:set_pos({x = row.anchor.x + 40, y = row.anchor.y + 60, z = row.anchor.z + 40})
		log(("camp %s %s at %d,%d"):format(row.key, row.slot, row.anchor.x, row.anchor.z))
		local info = core.get_player_window_information(NAME)
		if info then
			log(("window %dx%d hud %.2f gui %.2f"):format(info.size.x, info.size.y,
				info.real_hud_scaling, info.real_gui_scaling))
		end
	end},
	{name = "M2_map_window_pvp", run = function(player)
		local W = grug_map.window
		W.sessions[NAME] = W.new_state()
		W.sessions[NAME].layer = "pvp"
		W.open(player)
		local layout = W.sessions[NAME].layout
		log(("map window %.2f x %.2f units, map %.2f units"):format(layout.w, layout.form_h,
			layout.map_w))
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
		if not grug_map.minimap.available() then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_elf = "Elf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.5)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		player:set_look_vertical(0.6)
		state.phase = "next"
		state.shot = 1
	elseif state.phase == "next" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		state.waited, state.logged, state.ran = 0, false, false
		state.phase = "shoot"
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not state.ran then
			state.ran = true
			local ok, err = pcall(shot.run, player)
			log("run " .. shot.name .. ": " .. (ok and "ok" or tostring(err)))
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.phase = "next"
		end
	end
end)
