-- Disposable engine probe (Round 51 lane MOBS, step M1): the new water mobs
-- in a small studio for screenshots. Never shipped: tools/r51_mobs/capture.sh
-- stages it through tools/luanti_headless.sh and connects one real client.
-- The driver (character creation, the SHOT / ack handshake) is
-- tools/r502_home's probe's.
--
-- After the character is made the probe builds, 40 nodes above the player
-- (after core.emerge_area generated the area), a grass bank and a glass tank
-- of water beside it, and for each shot spawns one line-up (the mobs held
-- still: passive and ordered to stand, side-on to the camera), moves the
-- player to the camera spot and logs "SHOT <name>" and one "mob" line per
-- mob (the name it shows, its level and its shown size).
local P = "[r51shots] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r51shots_settle") or "") or 6
local WATER = "default:water_source"
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r51shots_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The studio, relative to its origin S: the bank x 0..27, z 0..9 (grass top
-- at y 0), the tank x 0..27, z 12..20 (glass walls, water y 1..7).
local S
local function build_studio()
	local minp, maxp = vector.offset(S, -2, -2, -12), vector.offset(S, 30, 10, 22)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local cid = core.get_content_id
	local air, grass, dirt = cid("air"), cid("default:dirt_with_grass"), cid("default:dirt")
	local glass, water, sand = cid("default:glass"), cid(WATER), cid("default:sand")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local rx, ry, rz = x - S.x, y - S.y, z - S.z
				local id = air
				if rx >= 0 and rx <= 27 and rz >= -10 and rz <= 9 and ry <= 0 and ry >= -1 then
					id = ry == 0 and grass or dirt
				elseif rx >= 0 and rx <= 27 and rz >= 12 and rz <= 20 and ry >= 0 and ry <= 8 then
					local wall = rx == 0 or rx == 27 or rz == 12 or rz == 20 or ry == 0
					if ry == 0 then id = sand
					elseif wall then id = glass
					elseif ry <= 7 then id = water end
				end
				data[area:index(x, y, z)] = id
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

-- Shots: mobs at studio offsets (x, y, z), the camera at an offset looking
-- along +z (yaw 0) with a pitch.
local function row(names, x0, dx, y, z)
	local out = {}
	for i, name in ipairs(names) do out[i] = {name = name, at = {x0 + (i - 1) * dx, y, z}} end
	return out
end
local SHOTS = {
	{name = "W1_tortoises", mobs = row({"tortoise_t1", "tortoise_t2", "tortoise_t3",
		"tortoise_t4", "tortoise_t5", "tortoise_t6"}, 3, 4, 1, 4), cam = {13.5, 2.5, -6}, pitch = 0.2},
	{name = "W2_frogs", mobs = row({"frog_t1", "frog_t2", "frog_t3", "frog_t4", "frog_t5",
		"frog_t6"}, 3, 4.2, 1, 4), cam = {13.5, 3, -7}, pitch = 0.25},
	-- The swimmers are shown held above the bank: the client draws the
	-- tank's water nearly opaque, so a swimmer in it barely shows (tried
	-- through the glass and from above).
	{name = "W3_rays", mobs = row({"stingray_t1", "stingray_t2", "stingray_t3",
		"stingray_t4", "stingray_t6"}, 3.5, 5, 1.4, 4), cam = {13.5, 3, -7}, pitch = 0.25},
	{name = "W4_sharks", mobs = {{name = "bay_shark", at = {6, 1.3, 4}},
		{name = "abyssal_shark", at = {18, 1.3, 5}}}, cam = {13.5, 5, -10}, pitch = 0.25},
	{name = "W5_goby", mobs = {{name = "goby", at = {12.5, 1.4, 2}},
		{name = "reed_angelfish", at = {15.5, 1.4, 2}}}, cam = {14, 2.2, -1.5}, pitch = 0.3},
}

local live = {}
local function clear_mobs()
	for _, obj in ipairs(live) do
		if obj:get_pos() then obj:remove() end
	end
	live = {}
end
local function spawn_lineup(shot)
	clear_mobs()
	for _, m in ipairs(shot.mobs) do
		local pos = vector.offset(S, m.at[1] + 0.5, m.at[2], m.at[3] + 0.5)
		local obj = core.add_entity(pos, "grug_mobs:" .. m.name)
		local ent = obj and obj:get_luaentity()
		if ent then
			ent.lifetimer = 20000
			grug_mobs.ensure_init(ent)
			-- Held still for the camera: no acquisition, no walking, side-on.
			ent.passive = true
			ent.order = "stand"
			ent.walk_chance = 0
			grug_mobs.face_yaw(ent, math.pi / 2)
			live[#live + 1] = obj
			local props = obj:get_properties()
			log(("mob %s shows %q L%s tier %s size %.2f"):format(m.name, tostring(ent.description),
				tostring(ent._grug_level), tostring(ent._grug_tier), props.visual_size.x))
		else
			log("mob " .. m.name .. " was not added")
		end
	end
end

-- Keeps the line-up in place against drift (a swimmer bobs, a mob may turn).
local function hold_lineup(shot)
	for i, obj in ipairs(live) do
		local m = shot.mobs[i]
		local ent = obj:get_luaentity()
		if ent and m then
			obj:set_velocity({x = 0, y = 0, z = 0})
			obj:set_pos(vector.offset(S, m.at[1] + 0.5, m.at[2], m.at[3] + 0.5))
			grug_mobs.face_yaw(ent, math.pi / 2)
		end
	end
end

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
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		player:hud_set_flags({hotbar = false, healthbar = false, crosshair = false,
			wielditem = false, breathbar = false, minimap = false, minimap_radar = false})
		local at = vector.round(player:get_pos())
		log("character complete at " .. core.pos_to_string(at))
		S = vector.offset(at, -14, 40, 0)
		state.phase = "emerge"
		core.emerge_area(vector.offset(S, -16, -16, -28), vector.offset(S, 44, 26, 38),
			function(_, _, remaining)
				if remaining > 0 then return end
				core.after(0, function()
					build_studio()
					log("studio at " .. core.pos_to_string(S))
					state.phase, state.shot, state.waited, state.logged = "shoot", 1, 0, false
					log("READY")
				end)
			end)
	elseif state.phase == "shoot" then
		core.set_timeofday(0.5)
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			clear_mobs()
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then
			spawn_lineup(shot)
			player:set_pos(vector.offset(S, shot.cam[1], shot.cam[2], shot.cam[3]))
			player:set_look_horizontal(0)
			player:set_look_vertical(shot.pitch)
		end
		hold_lineup(shot)
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log(("SHOT %s"):format(shot.name))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
