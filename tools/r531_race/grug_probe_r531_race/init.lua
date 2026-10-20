-- Disposable engine probe (0.53.1 lane RACE, ruling 9): the three
-- bow-shooting skeletons holding the shipped bow, for screenshots. Never
-- shipped: tools/r531_race/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, the SHOT / ack handshake) is tools/r51_mobs's
-- grug_probe_r51_shots'.
--
-- After the character is made the probe builds, 40 nodes above the player,
-- a grass floor, and for each shot places the Skeleton Archer, Skeleton
-- Raider and Frost Stray in a row, frozen (their on_step replaced on the
-- instance) in one animation clip and facing one yaw, moves the player to
-- the camera spot and logs "SHOT <name>" and one "mob" line per mob (its
-- third texture slot).
local P = "[r531race] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r531race_settle") or "") or 6
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r531race_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The studio: a grass floor x 0..20, z -10..10 at y 0 relative to S.
local S
local function build_studio()
	local minp, maxp = vector.offset(S, -2, -2, -12), vector.offset(S, 22, 10, 12)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local cid = core.get_content_id
	local air, grass, dirt = cid("air"), cid("default:dirt_with_grass"), cid("default:dirt")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local rx, ry, rz = x - S.x, y - S.y, z - S.z
				local id = air
				if rx >= 0 and rx <= 20 and rz >= -10 and rz <= 10 and ry <= 0 and ry >= -1 then
					id = ry == 0 and grass or dirt
				end
				data[area:index(x, y, z)] = id
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

local MOBS = {"skeleton_archer", "skeleton_raider", "frost_stray"}
-- Clips from skeleton_archer.lua's animation table (frozen on one frame for
-- "shoot_frame", looping otherwise).
local CLIPS = {
	shoot = {x = 70, y = 90, speed = 15},
	shoot_frame = {x = 82, y = 82, speed = 0},
	stand = {x = 0, y = 40, speed = 15},
}
local SHOTS = {
	{name = "B1_side_shoot", yaw = math.pi / 2, clip = "shoot_frame", cam = {10.5, 2.0, -5}, pitch = 0.15},
	{name = "B2_front_shoot", yaw = math.pi, clip = "shoot_frame", cam = {10.5, 2.0, -5}, pitch = 0.15},
	{name = "B3_other_side_stand", yaw = -math.pi / 2, clip = "stand", cam = {10.5, 2.0, -5}, pitch = 0.15},
	{name = "B4_close_side_shoot", yaw = math.pi / 2, clip = "shoot_frame", cam = {7.5, 2.2, 0.5}, pitch = 0.2},
	{name = "B5_three_quarter_shoot", yaw = math.pi * 0.75, clip = "shoot_frame", cam = {10.5, 2.0, -5}, pitch = 0.15},
}

local live = {}
local function clear_mobs()
	for _, obj in ipairs(live) do
		if obj:get_pos() then obj:remove() end
	end
	live = {}
end

local function place(shot)
	for i, obj in ipairs(live) do
		local ent = obj:get_luaentity()
		if ent then
			obj:set_velocity({x = 0, y = 0, z = 0})
			obj:set_pos(vector.offset(S, 7.5 + (i - 1) * 3, 1, 2.5))
			obj:set_yaw(shot.yaw)
		end
	end
end

local function spawn_lineup(shot)
	clear_mobs()
	local clip = CLIPS[shot.clip]
	for i, name in ipairs(MOBS) do
		local pos = vector.offset(S, 7.5 + (i - 1) * 3, 1, 2.5)
		local obj = core.add_entity(pos, "grug_mobs:" .. name)
		local ent = obj and obj:get_luaentity()
		if ent then
			grug_mobs.ensure_init(ent)
			-- Frozen for the camera: the instance's on_step shadows the
			-- mob's own, so nothing walks, turns or changes the clip.
			ent.on_step = function() end
			obj:set_animation({x = clip.x, y = clip.y}, clip.speed, 0, clip.speed > 0)
			live[#live + 1] = obj
			local props = obj:get_properties()
			log(("mob %s shows %q slot3 %s size %.2f"):format(name, tostring(ent.description),
				tostring(props.textures and props.textures[3]), props.visual_size.x))
		else
			log("mob " .. name .. " was not added")
		end
	end
	place(shot)
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
		S = vector.offset(at, -10, 40, 0)
		state.phase = "emerge"
		core.emerge_area(vector.offset(S, -16, -16, -28), vector.offset(S, 36, 26, 28),
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
		place(shot)
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
