-- Disposable engine probe for the mob attack cadence (mob-pressure round,
-- user ruling 1 of 2026-09-16; docs/design/combat_stats.md §4 "Catching up
-- must be enough to hit").
--
-- The decided text demands a runtime test in so many words -- "because it
-- changes every mob's feel, the WP that ships it owes a runtime test" -- and
-- says what it must show: a target fleeing at full walk speed takes roughly
-- one hit per `punch_interval`, and a target STANDING STILL takes exactly the
-- rate it took before. So this counts landed punches per 10 s in both
-- scenarios and prints them.
--
-- A headless server has NO PLAYER, and half of the thing under test is how a
-- mob behaves toward a player. Three consequences, stated rather than papered
-- over:
--
--   * The target is a disposable LuaEntity, not a player. It is the mob's
--     `self.attack` (forced through `do_attack(obj, true)`, so acquisition
--     plays no part) and it takes the punch, counts it and survives it. Every
--     line of the branch under test -- the cadence, the in-reach test, the
--     line-of-sight test, `target:punch` -- runs exactly as it does against a
--     player; what does NOT run is the player-specific half of `do_states`
--     (`is_invisible`, the mounted-rider `get_attach`) and the player-side
--     leash, which `grug_mobs/aggro.lua` deliberately never applies to a
--     mob-vs-non-player fight anyway.
--   * The target moves at the engine's own `movement_speed_walk = 4.0`
--     because this probe sets its position each step. A real player's input,
--     jumping and collision are not modelled.
--   * Feel is not measured here and cannot be. The number this prints is the
--     rate; whether the fight FEELS right is the user's playtest.
--
-- The arena is BUILT, not found: a flat stone platform 81 x 17 nodes in
-- forceloaded blocks high above the terrain, so the run is the same on every
-- seed and no hill, tree or cliff can end a chase halfway. `is_at_cliff`
-- stops a mob one node from an edge, which is why the platform is 17 wide for
-- a run along its centre line.
--
-- Staged with PROBE=, never shipped.

local ARENA = {x = 3000, y = 260, z = 3000}
local HALF_Z = 8 -- platform half width in nodes (17 wide)
local RUN_X = 80 -- platform length in nodes
local MOB_NAME = "grug_mobs:boar" -- reach 2, run_velocity 4.4, dogfight
local WINDOW = 10 -- seconds per scenario, the unit the decided text uses
local TARGET_SPEED = 4.0 -- movement_speed_walk (defaultsettings.cpp:520)

local function log(line)
	core.log("action", "[probe] " .. line)
end

local function fields(tbl)
	local parts = {}
	for index = 1, #tbl do
		parts[index] = tbl[index]
	end
	return table.concat(parts, " ")
end

--
-- The target: a disposable entity that counts punches and never dies.
--
-- `on_punch` returns true, which for a LuaEntity cancels the engine's own
-- damage. That is what keeps the target alive through 10 s of hits without
-- the probe having to top its HP up mid-measurement -- and the count is taken
-- BEFORE the cancel, so nothing about the hit is hidden.
--

local punches = 0

core.register_entity("grug_cadence_probe:target", {
	initial_properties = {
		hp_max = 65535,
		physical = false,
		collide_with_objects = false,
		pointable = false,
		collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}, -- a player's box
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

--
-- Arena construction
--

local function forceload_arena()
	local blocks = 0
	local x = ARENA.x - 16
	while x <= ARENA.x + RUN_X + 16 do
		local z = ARENA.z - HALF_Z - 16
		while z <= ARENA.z + HALF_Z + 16 do
			local y = ARENA.y - 8
			while y <= ARENA.y + 24 do
				-- limit = -1 lifts max_forceloaded_blocks (16 by default);
				-- this arena needs more than that.
				if core.forceload_block({x = x, y = y, z = z}, true, -1) then
					blocks = blocks + 1
				end
				y = y + 16
			end
			z = z + 16
		end
		x = x + 16
	end
	return blocks
end

local function build_platform()
	local written = 0
	for dx = -4, RUN_X + 4 do
		for dz = -HALF_Z, HALF_Z do
			core.set_node({x = ARENA.x + dx, y = ARENA.y, z = ARENA.z + dz},
				{name = "default:stone"})
			written = written + 1
			-- Clear the four nodes above, so nothing generated up here can
			-- block the run or hurt the mob.
			for dy = 1, 4 do
				core.set_node({x = ARENA.x + dx, y = ARENA.y + dy,
					z = ARENA.z + dz}, {name = "air"})
			end
		end
	end
	return written
end

--
-- The two scenarios
--

local state = {phase = "wait_starts", clock = 0, total = 0, poll = 0,
	said = -1, results = {}}
local mob_object, mob_entity, target_object

local function despawn()
	if mob_object and mob_object:get_pos() then
		mob_object:remove()
	end
	if target_object and target_object:get_pos() then
		target_object:remove()
	end
	mob_object, mob_entity, target_object = nil, nil, nil
end

-- Fresh pair per scenario: a mob carries chase state (path, punch_timer,
-- stuck flags) and a second run must not inherit the first one's.
local function spawn_pair()
	local ground = ARENA.y + 1
	target_object = core.add_entity(
		{x = ARENA.x + 12, y = ground, z = ARENA.z},
		"grug_cadence_probe:target")
	mob_object = core.add_entity(
		{x = ARENA.x + 10, y = ground, z = ARENA.z}, MOB_NAME)
	if not mob_object or not target_object then
		return false
	end
	mob_entity = mob_object:get_luaentity()
	if not mob_entity then
		return false
	end
	-- Exempt from both mobs_redo removal paths. `state == "attack"` already
	-- exempts a fighting mob (api.lua mob_staticdata / mob_expire), but a
	-- lifetimer above 20000 is the documented exemption and costs nothing.
	mob_entity.lifetimer = 30000
	mob_entity:do_attack(target_object, true)
	return true
end

local function mob_report()
	if not mob_entity then
		return "mob=missing"
	end
	return fields({
		"mob=" .. tostring(mob_entity.name),
		"level=" .. tostring(mob_entity._grug_level),
		"reach=" .. tostring(mob_entity.reach),
		"punch_interval=" .. tostring(mob_entity.punch_interval),
		"run_velocity=" .. tostring(mob_entity.run_velocity),
		"damage=" .. tostring(mob_entity.damage),
		"attack_type=" .. tostring(mob_entity.attack_type),
	})
end

local function run_scenario(name, moving, dtime)
	local mpos = mob_object and mob_object:get_pos()
	local tpos = target_object and target_object:get_pos()
	if not mpos or not tpos then
		return false
	end
	if moving then
		local nx = tpos.x + TARGET_SPEED * dtime
		if nx > ARENA.x + RUN_X then
			nx = ARENA.x + RUN_X
		end
		target_object:set_pos({x = nx, y = ARENA.y + 1, z = ARENA.z})
		tpos = {x = nx, y = ARENA.y + 1, z = ARENA.z}
	end
	local gap = math.sqrt((tpos.x - mpos.x) ^ 2 + (tpos.y - mpos.y) ^ 2 +
		(tpos.z - mpos.z) ^ 2)
	local row = state.results[name]
	row.samples = row.samples + 1
	row.gap_sum = row.gap_sum + gap
	if gap > row.gap_max then row.gap_max = gap end
	if gap < row.gap_min then row.gap_min = gap end
	if mob_entity and mob_entity.state ~= "attack" then
		row.lost = row.lost + 1
		mob_entity:do_attack(target_object, true)
	end
	return true
end

local function new_row()
	return {samples = 0, gap_sum = 0, gap_max = 0, gap_min = 1e9,
		lost = 0, punches = 0, dtime_max = 0}
end

local function finish(name)
	local row = state.results[name]
	row.punches = punches
	-- AFTER the window, not before it: levels.lua assigns hp/damage/XP on the
	-- mob's first active tick, so a report taken at spawn time prints
	-- `level=nil damage=0` for a mob that is perfectly real.
	log(mob_report())
	log(fields({
		"cadence",
		"scenario=" .. name,
		"punches=" .. row.punches,
		"window_s=" .. string.format("%.2f", state.clock),
		"per_10s=" .. string.format("%.2f", row.punches * 10 / state.clock),
		"gap_min=" .. string.format("%.2f", row.gap_min),
		"gap_max=" .. string.format("%.2f", row.gap_max),
		"gap_mean=" .. string.format("%.2f", row.gap_sum / row.samples),
		"steps=" .. row.samples,
		"step_mean=" .. string.format("%.4f", state.clock / row.samples),
		"target_lost=" .. row.lost,
		"dtime_max=" .. string.format("%.3f", row.dtime_max),
	}))
end

--
-- The programme
--
-- Phases are driven off one globalstep with its own clock, and every
-- transition that depends on the MAP is verified rather than timed. The first
-- attempt at this probe timed them, and on a busy box a single globalstep
-- arrived carrying tens of seconds of dtime while mapgen held the main
-- thread: every phase fired at once, the platform was written into unloaded
-- blocks and the mob fell out of the world. So:
--
--   1. wait for grug_core's six-start preload to finish. It saturates the
--      emerge queue for the whole early boot, and a measurement taken while
--      it runs measures the emerge thread rather than the mob.
--   2. forceload the arena and wait until every corner of it READS BACK as a
--      real node rather than "ignore".
--   3. build the platform and read it back before trusting it.
--   4. only then spawn and measure, recording the largest dtime seen inside
--      each window so a spike cannot hide inside an average.
--

local WAIT_STARTS = 240 -- s, hard cap on step 1
local WAIT_BLOCKS = 120 -- s, hard cap on step 2
local POLL = 1

local function corners()
	return {
		{x = ARENA.x - 4, y = ARENA.y, z = ARENA.z - HALF_Z},
		{x = ARENA.x + RUN_X + 4, y = ARENA.y, z = ARENA.z - HALF_Z},
		{x = ARENA.x - 4, y = ARENA.y, z = ARENA.z + HALF_Z},
		{x = ARENA.x + RUN_X + 4, y = ARENA.y, z = ARENA.z + HALF_Z},
		{x = ARENA.x + RUN_X / 2, y = ARENA.y, z = ARENA.z},
	}
end

local function arena_loaded()
	local points = corners()
	for index = 1, #points do
		if core.get_node(points[index]).name == "ignore" then
			return false
		end
	end
	return true
end

local function platform_ok()
	local points = corners()
	for index = 1, #points do
		if core.get_node(points[index]).name ~= "default:stone" then
			return false
		end
	end
	return true
end

local function fail(reason)
	log("cadence FAIL " .. reason)
	core.request_shutdown("cadence probe: " .. reason, false, 1)
	state.phase = "done"
end

core.register_on_mods_loaded(function()
	log(fields({"arena", "x=" .. ARENA.x, "y=" .. ARENA.y, "z=" .. ARENA.z,
		"run=" .. RUN_X, "half_z=" .. HALF_Z, "mob=" .. MOB_NAME,
		"window_s=" .. WINDOW, "target_speed=" .. TARGET_SPEED}))
end)

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	state.total = state.total + dtime
	local phase = state.phase

	if phase == "done" then
		return
	end

	if phase == "wait_starts" then
		state.poll = state.poll + dtime
		if state.poll < POLL then return end
		state.poll = 0
		local ready, total = grug_core.starts_ready()
		if ready ~= state.said then
			log(fields({"starts", "ready=" .. ready, "of=" .. total,
				"t=" .. string.format("%.1f", state.total)}))
			state.said = ready
		end
		if ready >= total then
			log("forceload blocks=" .. forceload_arena())
			state.phase, state.clock = "wait_blocks", 0
		elseif state.clock > WAIT_STARTS then
			fail("the six start areas did not preload within " ..
				WAIT_STARTS .. " s (ready " .. ready .. "/" .. total .. ")")
		end
		return
	end

	if phase == "wait_blocks" then
		state.poll = state.poll + dtime
		if state.poll < POLL then return end
		state.poll = 0
		if arena_loaded() then
			log(fields({"arena_loaded",
				"t=" .. string.format("%.1f", state.total)}))
			state.phase, state.clock = "build", 0
		elseif state.clock > WAIT_BLOCKS then
			fail("the arena blocks did not emerge within " ..
				WAIT_BLOCKS .. " s")
		end
		return
	end

	if phase == "build" then
		log("platform nodes=" .. build_platform())
		if not platform_ok() then
			fail("the platform did not read back as stone")
			return
		end
		state.phase, state.clock = "settle", 0
		return
	end

	if phase == "settle" then
		if state.clock >= 2 then
			state.phase, state.clock = "spawn_receding", 0
		end
		return
	end

	if phase == "spawn_receding" or phase == "spawn_standing" then
		despawn()
		if not spawn_pair() then
			fail("could not spawn the mob/target pair")
			return
		end
		state.phase = phase == "spawn_receding" and "arm_receding"
			or "arm_standing"
		state.clock = 0
		state.results[state.phase == "arm_receding" and "receding"
			or "standing"] = new_row()
		punches = 0
		return
	end

	if phase == "arm_receding" or phase == "arm_standing" then
		-- Two seconds of ordinary approach before the clock starts, so the
		-- measurement window contains no acquisition transient.
		local name = phase == "arm_receding" and "receding" or "standing"
		if not run_scenario(name, phase == "arm_receding", dtime) then
			fail(name .. " lost an object while arming")
			return
		end
		if state.clock >= 2 then
			state.results[name] = new_row()
			punches = 0
			state.phase, state.clock = name, 0
		end
		return
	end

	if phase == "receding" or phase == "standing" then
		local row = state.results[phase]
		if dtime > row.dtime_max then row.dtime_max = dtime end
		if not run_scenario(phase, phase == "receding", dtime) then
			fail(phase .. " lost an object mid-window")
			return
		end
		if state.clock >= WINDOW then
			finish(phase)
			if phase == "receding" then
				state.phase, state.clock = "spawn_standing", 0
			else
				despawn()
				log("cadence complete")
				core.request_shutdown("cadence probe done", false, 1)
				state.phase = "done"
			end
		end
		return
	end
end)
