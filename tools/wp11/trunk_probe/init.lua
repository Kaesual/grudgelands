-- Disposable engine probe for the round-5 melee-obstacle ruling.
--
-- A boar and a player-sized target start 1.9 nodes apart with one two-node-high
-- tree-trunk column intersecting their attack-height eye ray. The arena is
-- otherwise empty. The probe counts punches during a ten-second window after
-- a short settle period.
-- It is staged with tools/luanti_headless.sh PROBE= and never shipped.

local ARENA = {x = 3040, y = 260, z = 3040}
local MOB_POS = {x = ARENA.x, y = ARENA.y + 1, z = ARENA.z}
local TARGET_POS = {x = ARENA.x + 1.9, y = ARENA.y + 1, z = ARENA.z}
local TRUNK_POS = {x = ARENA.x + 1, y = ARENA.y + 1, z = ARENA.z}
local MOB_NAME = "grug_mobs:boar"
local WINDOW = 10

local punches = 0
local state = {phase = "wait_starts", clock = 0, total = 0, poll = 0,
	ready = -1}
local mob_object, target_object

local function log(message)
	core.log("action", "[trunk_probe] " .. message)
end

core.register_entity("grug_trunk_probe:target", {
	initial_properties = {
		hp_max = 65535,
		physical = false,
		collide_with_objects = false,
		pointable = false,
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
		visual = "cube",
		visual_size = {x = 0.6, y = 1.7, z = 0.6},
		textures = {"default_stone.png", "default_stone.png",
			"default_stone.png", "default_stone.png",
			"default_stone.png", "default_stone.png"},
		static_save = false,
	},
	on_punch = function()
		punches = punches + 1
		return true
	end,
})

local function forceload_arena()
	local count = 0
	for x = ARENA.x - 16, ARENA.x + 16, 16 do
		for z = ARENA.z - 16, ARENA.z + 16, 16 do
			for y = ARENA.y - 8, ARENA.y + 24, 16 do
				if core.forceload_block({x = x, y = y, z = z}, true, -1) then
					count = count + 1
				end
			end
		end
	end
	return count
end

local function arena_loaded()
	return core.get_node(ARENA).name ~= "ignore"
end

local function build_arena()
	for dx = -8, 10 do
		for dz = -8, 8 do
			core.set_node({x = ARENA.x + dx, y = ARENA.y,
				z = ARENA.z + dz}, {name = "default:stone"})
			for dy = 1, 4 do
				core.set_node({x = ARENA.x + dx, y = ARENA.y + dy,
					z = ARENA.z + dz}, {name = "air"})
			end
		end
	end
	-- Exactly one node-wide trunk column. Two vertical nodes make the attack
	-- eye ray unambiguously blocked for both the boar and player-sized target.
	core.set_node(TRUNK_POS, {name = "default:tree"})
	core.set_node({x = TRUNK_POS.x, y = TRUNK_POS.y + 1, z = TRUNK_POS.z},
		{name = "default:tree"})
	return core.get_node(TRUNK_POS).name == "default:tree" and
		core.get_node({x = TRUNK_POS.x, y = TRUNK_POS.y + 1,
			z = TRUNK_POS.z}).name == "default:tree"
end

local function attack_line_of_sight(mob)
	local mpos = mob_object:get_pos()
	local tpos = target_object:get_pos()
	local mbox = mob_object:get_properties().collisionbox
	local tbox = target_object:get_properties().collisionbox
	local moffset = mbox[2] + ((mbox[5] - mbox[2]) * 0.9)
	local toffset = tbox[2] + ((tbox[5] - tbox[2]) * 0.9)
	local from = {x = tpos.x, y = tpos.y + toffset, z = tpos.z}
	local to = {x = mpos.x, y = mpos.y + moffset, z = mpos.z}
	return mob:line_of_sight(from, to)
end

local function spawn_pair()
	target_object = core.add_entity(TARGET_POS, "grug_trunk_probe:target")
	mob_object = core.add_entity(MOB_POS, MOB_NAME)
	local mob = mob_object and mob_object:get_luaentity()
	if not mob or not target_object then
		return false
	end
	mob.lifetimer = 30000
	mob:do_attack(target_object, true)
	local initial_los = attack_line_of_sight(mob) == true
	log("initial_attack_los=" .. tostring(initial_los) ..
		" expected=false target_distance=1.9 trunk_height=2")
	return true
end

local function fail(message)
	log("FAIL " .. message)
	core.request_shutdown("trunk probe: " .. message, false, 1)
	state.phase = "done"
end

core.register_on_mods_loaded(function()
	log("arena x=" .. ARENA.x .. " y=" .. ARENA.y .. " z=" .. ARENA.z ..
		" mob=" .. MOB_NAME .. " target_distance=1.9 window_s=" .. WINDOW)
end)

core.register_globalstep(function(dtime)
	if state.phase == "done" then return end
	state.clock = state.clock + dtime
	state.total = state.total + dtime

	if state.phase == "wait_starts" then
		state.poll = state.poll + dtime
		if state.poll < 1 then return end
		state.poll = 0
		local ready, total = grug_core.starts_ready()
		if ready ~= state.ready then
			log("starts ready=" .. ready .. " of=" .. total)
			state.ready = ready
		end
		if ready >= total then
			log("forceload blocks=" .. forceload_arena())
			state.phase, state.clock = "wait_arena", 0
		elseif state.clock > 90 then
			fail("start preload timeout")
		end
		return
	end

	if state.phase == "wait_arena" then
		if arena_loaded() then
			if not build_arena() then
				fail("trunk did not read back")
				return
			end
			state.phase, state.clock = "settle", 0
		elseif state.clock > 20 then
			fail("arena emerge timeout")
		end
		return
	end

	if state.phase == "settle" then
		if state.clock >= 1 then
			if not spawn_pair() then
				fail("could not spawn pair")
				return
			end
			state.phase, state.clock = "arm", 0
		end
		return
	end

	if state.phase == "arm" then
		if state.clock >= 1 then
			punches = 0
			state.phase, state.clock = "measure", 0
		end
		return
	end

	if state.phase == "measure" then
		if not mob_object or not mob_object:get_pos() or
				not target_object or not target_object:get_pos() then
			fail("an object disappeared")
			return
		end
		if state.clock >= WINDOW then
			local mob = mob_object:get_luaentity()
			local mpos = mob_object:get_pos()
			local tpos = target_object:get_pos()
			local gap = vector.distance(mpos, tpos)
			log("result punches=" .. punches .. " window_s=" ..
				string.format("%.2f", state.clock) .. " gap=" ..
				string.format("%.2f", gap) .. " reach=" ..
				tostring(mob and mob.reach) .. " path_following=" ..
				tostring(mob and mob.path and mob.path.following))
			core.request_shutdown("trunk probe done", false, 1)
			state.phase = "done"
		end
	end
end)
