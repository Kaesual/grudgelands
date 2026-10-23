-- Disposable engine probe (Round 58 lane ROOMS): screenshots of Miner's
-- Guild rooms. Never shipped: tools/r58_rooms/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r58_camps's probe.
--
-- Setting r58roomshots_camp: the camp whose rooms are shot (default the
-- seed-42 war camp whose -650 room has lava and water at its mantle). Shots:
-- R1 its T4 room from inside (a corner, towards the lift), R2 the same room
-- along its +x exit, R3 its T5 room at -950.

local P = "[r58roomshots] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r58roomshots_settle") or "") or 3
local CAMP = core.settings:get("r58roomshots_camp") or "pvp_camp_skyglass_canopy_throng_low"

local function log(msg) core.log("action", P .. msg) end

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r58roomshots_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- {name, tier, eye offset {dx, dz} from the lift column at floor_y, target offset}
local SHOTS = {
	{name = "R1_room_inside_t4", tier = 4, at = {3, 3}, look = {-1, 0.6, -2}},
	{name = "R2_room_exit_t4", tier = 4, at = {-3, 0}, look = {6, 1.0, 0}},
	{name = "R3_room_t5_minus950", tier = 5, at = {-3, 3}, look = {2, 0.6, -2}},
}

local function room_of(tier)
	for _, room in ipairs(grug_mapgen.guild_rooms.rooms_for_camp(CAMP) or {}) do
		if room.tier == tier then return room end
	end
end

local function frame(player, shot, room)
	local c = room.lift_cell
	local eye = {x = c.x + shot.at[1], y = room.floor_y - 0.5, z = c.z + shot.at[2]}
	player:set_pos(eye)
	local t = {x = c.x + shot.look[1], y = room.floor_y + shot.look[2], z = c.z + shot.look[3]}
	local dx, dy, dz = t.x - eye.x, t.y - (eye.y + 1.5), t.z - eye.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
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
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		player:hud_set_flags({minimap = false, crosshair = false, wielditem = false})
		log("camp " .. CAMP)
		state.phase, state.shot, state.ran = "shoot", 1, false
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		local room = room_of(shot.tier)
		if not room then
			log("no T" .. shot.tier .. " room of " .. CAMP)
			state.shot = state.shot + 1
			return
		end
		if not state.ran then
			state.ran, state.ready, state.waited, state.logged = true, false, 0, false
			core.emerge_area(vector.subtract(room.minp, 16), vector.add(room.maxp, 16),
				function(_, _, remaining)
					if remaining ~= 0 then return end
					frame(player, shot, room)
					state.ready = true
				end)
			return
		end
		if not state.ready then return end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE + 2 then
			state.logged = true
			local c = room.lift_cell
			log(("%s: %s T%d floor %d at %d,%d, lift %s param2 %d, arrival light %s"):format(
				shot.name, CAMP, room.tier, room.floor_y, c.x, c.z, core.get_node(c).name,
				core.get_node(c).param2, tostring(core.get_node_light(vector.round(room.arrival)))))
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot, state.ran = state.shot + 1, false
		end
	end
end)
