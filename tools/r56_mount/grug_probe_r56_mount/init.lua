-- Disposable engine probe (Round 56 lane MOUNT): a rider on the apprentice
-- horse in the real engine. Never shipped: tools/r56_mount/run.sh stages it
-- through tools/luanti_headless.sh and joins one protocol client
-- (tools/r43_it/client.py). The character driver is the 0.53.1 FLIGHT
-- probe's.
--
-- After the character is made (Accord, Human, Warrior) the probe builds a
-- stone floor 60 nodes over the player, with a 2-node step on it, and runs:
--   DROP 11 / DROP 20   the horse spawned that high over the floor with its
--                       rider: HP before and after, still mounted, the fall
--                       time and the impact speed;
--   JUMP                one jump in place: the apex over the floor;
--   NOJUMP              running at the step without jumping: blocked;
--   STEP                running at the step with jump held: on top;
--   PUNCH               damage of type punch: dismounted.
-- The rider's controls come from the probe (ObjectRef:get_player_control is
-- wrapped for this player only).
local P = "[r56mount] "
local NAME = "grugmount"
local FACTION = "accord"
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function hp_max(player)
	return tonumber((player:get_properties() or {}).hp_max) or 0
end

local function mount_object(player)
	local record = grug_mounts.active[NAME]
	return record and record.object and record.object:is_valid() and record.object or nil
end

-- The tests, in order. `x` is the spawn column relative to the base.
local TESTS = {
	{name = "DROP 11", kind = "drop", height = 11, x = -3},
	{name = "DROP 20", kind = "drop", height = 20, x = -3},
	{name = "JUMP", kind = "jump", x = -3},
	{name = "NOJUMP", kind = "run", x = -3, control = {up = true}},
	{name = "STEP", kind = "run", x = -3, control = {up = true, jump = true}},
	{name = "PUNCH", kind = "punch", x = -3},
}

local function build(base)
	local stone = "default:stone"
	for x = -6, 12 do
		for z = -3, 3 do
			for y = 1, 26 do
				core.set_node({x = base.x + x, y = base.y + y, z = base.z + z}, {name = "air"})
			end
			core.set_node({x = base.x + x, y = base.y, z = base.z + z}, {name = stone})
			if x >= 1 then
				core.set_node({x = base.x + x, y = base.y + 1, z = base.z + z}, {name = stone})
				core.set_node({x = base.x + x, y = base.y + 2, z = base.z + z}, {name = stone})
			end
		end
	end
end

local function start_test(player, test)
	grug_mounts.dismount(player, nil, true)
	state.control = nil
	local props = player:get_properties()
	player:set_hp(hp_max(player), {type = "set_hp"})
	local top = state.base.y + 0.5
	local pos = {x = state.base.x + test.x, y = top + 0.01 + (test.height or 0), z = state.base.z}
	player:set_pos(pos)
	player:set_look_horizontal(3 * math.pi / 2) -- forward is +x
	local ok, err = grug_mounts.spawn_entity(player, 1, pos)
	state.t, state.hp_before, state.min_vy, state.max_y = 0, player:get_hp(), 0, pos.y
	state.landed_at, state.fall_time, state.done = nil, nil, false
	log(("%s: spawn %s at y %+.2f over the floor, HP %d/%d, immortal %s"):format(test.name,
		ok and "ok" or tostring(err), pos.y - top, state.hp_before, hp_max(player),
		tostring((player:get_armor_groups() or {}).immortal or 0)))
	return props
end

local function finish(player, test, text)
	log(test.name .. ": " .. text)
	state.done = true
	state.control = nil
end

local function run_test(player, test, dtime)
	state.t = state.t + dtime
	local object = mount_object(player)
	local top = state.base.y + 0.5
	local pos = object and object:get_pos()
	local vel = object and object:get_velocity()
	if pos then state.max_y = math.max(state.max_y, pos.y) end
	if vel then state.min_vy = math.min(state.min_vy, vel.y) end
	if test.kind == "drop" then
		if pos and not state.fall_time and pos.y < top + 0.05 then state.fall_time = state.t end
		if state.t >= 3 then
			local hp, max = player:get_hp(), hp_max(player)
			finish(player, test, ("HP %d -> %d of %d (lost %d = %.1f %% of the pool), mounted %s, " ..
				"attached %s, fell %.2f nodes in about %.2f s, impact speed %.2f nodes/s, gravity %s"):format(
				state.hp_before, hp, max, state.hp_before - hp, (state.hp_before - hp) * 100 / max,
				tostring(grug_mounts.is_mounted(player)), tostring(player:get_attach() ~= nil),
				test.height, state.fall_time or -1, -state.min_vy,
				object and tostring(object:get_acceleration().y) or "?"))
		end
	elseif test.kind == "jump" then
		if state.t >= 0.5 and not state.jumped then
			state.control = {jump = true}
			if vel and vel.y > 0 then
				state.jumped, state.control = vel.y, nil
				state.max_y = pos.y
			end
		end
		if state.t >= 2.5 then
			finish(player, test, ("impulse %.2f nodes/s, apex %.3f nodes over the floor, back on it %s"):format(
				state.jumped or -1, state.max_y - top, tostring(pos and math.abs(pos.y - top - 0.01) < 0.05)))
			state.jumped = nil
		end
	elseif test.kind == "run" then
		if state.t >= 0.5 then state.control = test.control end
		local on_top = pos and pos.y >= top + 2 and vel and math.abs(vel.y) < 0.01
		if on_top or state.t >= 2.5 then
			finish(player, test, ("after %.2f s: the box bottom %.2f nodes over the floor, x %+.2f " ..
				"(the step face at +0.50), on top of the step %s, mounted %s"):format(state.t - 0.5,
				pos and pos.y - 0.01 - top or -1, pos and pos.x - state.base.x or 0,
				tostring(on_top and true or false), tostring(grug_mounts.is_mounted(player))))
		end
	elseif test.kind == "punch" then
		if state.t >= 0.5 and object then
			local before = player:get_hp()
			player:set_hp(before - 2, {type = "punch"})
			finish(player, test, ("a punch (2 HP; a dodge would keep it): HP %d -> %d, mounted %s, attached %s"):format(
				before, player:get_hp(), tostring(grug_mounts.is_mounted(player)),
				tostring(player:get_attach() ~= nil)))
		elseif state.t >= 2 then
			finish(player, test, "no mount to punch")
		end
	end
end

core.register_on_joinplayer(function(player)
	if player:get_player_name() ~= NAME or state.wrapped then return end
	local methods = getmetatable(player)
	local original = methods.get_player_control
	methods.get_player_control = function(self)
		if state.control and self:is_player() and self:get_player_name() == NAME then
			return state.control
		end
		return original(self)
	end
	state.wrapped = true
end)

core.register_globalstep(function(dtime)
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		state.clock = state.clock + dtime
		if state.clock < 0.5 then return end
		state.clock = 0
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
		local at = vector.round(player:get_pos())
		state.base = {x = at.x, y = at.y + 60, z = at.z}
		log(("character complete at %s, faction %s, base %s"):format(core.pos_to_string(at), FACTION,
			core.pos_to_string(state.base)))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_pos({x = state.base.x - 3, y = state.base.y + 3, z = state.base.z})
		state.phase = "emerge"
		local b = state.base
		core.emerge_area({x = b.x - 8, y = b.y - 2, z = b.z - 8}, {x = b.x + 14, y = b.y + 28, z = b.z + 8},
			function(_, _, remaining)
				if remaining == 0 then
					build(state.base)
					state.phase, state.clock = "settle", 0
					log("built the floor and the step")
				end
			end)
	elseif state.phase == "settle" then
		state.clock = state.clock + dtime
		if state.clock < 3 then return end
		state.phase, state.index = "test", 1
		start_test(player, TESTS[1])
	elseif state.phase == "test" then
		local test = TESTS[state.index]
		if not state.done then run_test(player, test, dtime) return end
		state.index = state.index + 1
		if not TESTS[state.index] then
			state.phase = "done"
			grug_mounts.dismount(player, nil, true)
			log("RESULT done")
			core.request_shutdown("probe done", false, 0)
			return
		end
		start_test(player, TESTS[state.index])
	end
end)
