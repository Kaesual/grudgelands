-- Disposable engine probe (Round 58 lane CAMPS): a T2 and a T4 mining
-- camp, a war camp with its new lift, foreman and vendor sockets, and a
-- camp under construction, for screenshots. Never shipped:
-- tools/r58_camps/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) follows tools/r57_qsys's probe.
--
-- Per shot it emerges the camp's area, hovers the player over the gate side
-- looking at the camp (or at the lift up close), waits for the socket NPCs
-- and logs the node at the lift socket and who stands on which socket.

local P = "[r58camps] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r58camps_settle") or "") or 3
local camps = grug_mapgen.mining_camps

local function log(msg) core.log("action", P .. msg) end

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r58camps_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function face(player, target, pitch)
	local pos = player:get_pos()
	local dx, dz = target.x - pos.x, target.z - pos.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(pitch)
end

-- {name, camp id, view}: "camp" from the gate side, "lift" close to the lift.
local SHOTS = {
	{name = "C1_mining_camp_t2", id = "mining_camp_goldmead_vale", view = "camp"},
	{name = "C2_mining_camp_t2_lift", id = "mining_camp_goldmead_vale", view = "lift"},
	{name = "C3_mining_camp_t4", id = "mining_camp_bannerbreak_mesa", view = "camp"},
	{name = "C4_war_camp", id = "pvp_camp_broken_causeway_accord_low", view = "camp"},
	{name = "C5_war_camp_lift", id = "pvp_camp_broken_causeway_accord_low", view = "lift"},
	{name = "C6_camp_under_construction", id = "camp_site_ashenward_march", view = "camp"},
}

local function census(id)
	local anchor = grug_core.settlement_socket_anchor(id)
	local by_socket = {}
	for _, object in ipairs(core.get_objects_inside_radius(anchor, 40)) do
		local entity = object:get_luaentity()
		if entity and entity._grug_start == id then
			by_socket[#by_socket + 1] = tostring(entity._grug_socket) .. "=" .. tostring(entity.name)
		end
	end
	table.sort(by_socket)
	return table.concat(by_socket, " ")
end

local function report(id)
	local camp = camps.get(id)
	local anchor = grug_core.settlement_socket_anchor(id)
	local parts = {id, "anchor " .. core.pos_to_string(anchor)}
	for _, socket in ipairs(grug_core.settlement_sockets_at(id)) do
		if socket.role == "lift" then
			parts[#parts + 1] = "lift socket " .. core.pos_to_string(socket.pos) .. " node " ..
				core.get_node(socket.pos).name .. " module lift " ..
				tostring(camp and camp.lift.x) .. "," .. tostring(camp and camp.lift.z)
		end
	end
	parts[#parts + 1] = "npcs: " .. census(id)
	log(table.concat(parts, "; "))
end

local function frame(player, shot)
	local camp = camps.get(shot.id)
	local anchor = grug_core.settlement_socket_anchor(shot.id)
	-- the gate side: -z for an Accord camp, +z for a Throng one
	local side = camp.faction == "accord" and -1 or 1
	if shot.view == "lift" then
		local lift
		for _, socket in ipairs(grug_core.settlement_sockets_at(shot.id)) do
			if socket.role == "lift" then lift = socket.pos end
		end
		player:set_pos(vector.new(lift.x - 4 * side, lift.y + 3, lift.z + 6 * side))
		face(player, lift, 0.35)
	else
		player:set_pos(vector.new(anchor.x, anchor.y + 16, anchor.z + 27 * side))
		face(player, anchor, 0.5)
	end
end

local state = {phase = "wait", clock = 0}
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
		core.set_timeofday(0.45)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		player:hud_set_flags({minimap = false, crosshair = false})
		log(("camps: %d with lifts, %d under construction"):format(#camps.camps,
			#camps.under_construction))
		state.phase, state.shot, state.ran = "shoot", 1, false
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran, state.ready, state.waited, state.logged = true, false, 0, false
			local anchor = grug_core.settlement_socket_anchor(shot.id)
			core.emerge_area(vector.offset(anchor, -48, -24, -48), vector.offset(anchor, 48, 32, 48),
				function(_, _, remaining)
					if remaining ~= 0 then return end
					frame(player, shot)
					state.ready = true
				end)
			return
		end
		if not state.ready then return end
		state.waited = state.waited + step
		-- the socket NPCs appear once their area is active
		if not state.logged and state.waited >= SETTLE + 6 then
			state.logged = true
			report(shot.id)
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot, state.ran = state.shot + 1, false
		end
	end
end)
