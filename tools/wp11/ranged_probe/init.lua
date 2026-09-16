-- Disposable engine probe for the ranged half of the mob-pressure round
-- (user ruling 3, 2026-09-16: "more ranged mobs, with a larger view range
-- than melee mobs").
--
-- What only a real server can say, and what this prints:
--
--   1. THE ROSTER, as the engine holds it after every registration wrapper
--      has had its turn: how many registered mobs carry `dogshoot`, how many
--      carry `dogfight`, and every mob's `view_range` -- so the rule of
--      biomes_mobs.md §3.1 ("a dogshoot family sees 16, a melee family 10-14
--      by habitat") is checked against registrations rather than against a
--      grep of source text.
--   2. THE CAMP SLOT ROLL. The bandit camp's registered config carries the
--      Bandit Archer as its `variant` at 1 in 3, and both families count
--      against ONE head count.
--   3. IT ACTUALLY SHOOTS. One Bandit Archer and one disposable target 12 m
--      apart on a built platform: arrows are counted as they appear in the
--      world and hits are counted on the target.
--
-- The camp's own refill is deliberately NOT exercised here, and that is a
-- property of the engine rather than a gap in the probe: `camp_tick`
-- (grug_mobs/camps.lua) returns early unless a PLAYER is within
-- `PLAYER_RANGE`, and a headless server has no player. What the slot roll
-- does with the config is arithmetic, and it is the config that this checks.
--
-- The arena is a copy of tools/wp11/cadence_probe's, on purpose: these are
-- throwaway probes staged one at a time, and a shared library between two
-- disposable mods would be a third thing to keep alive.
--
-- Staged with PROBE=, never shipped.

local ARENA = {x = 3200, y = 260, z = 3200}
local HALF_Z = 8
local RUN_X = 40
local WINDOW = 15 -- s of shooting
local ARCHER = "grug_mobs:bandit_archer"
local SHOT_RANGE = 12 -- m: inside view_range 16, far outside reach 2

local function log(line)
	core.log("action", "[probe] " .. line)
end

local punches, arrows_seen = 0, 0

core.register_entity("grug_ranged_probe:target", {
	initial_properties = {
		hp_max = 65535,
		physical = false,
		collide_with_objects = false,
		pointable = false,
		collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
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
-- 1. The roster, off the registrations
--

-- The one documented exemption from the 16 m ceiling: the Kraken Guard is
-- aquatic, carries `_grug_no_leash` and its own hand-rolled open-sea leash
-- (kraken.lua), and biomes_mobs.md §3.1 says outright that it is "outside
-- this comparison". Listing it here rather than letting it print as a
-- problem is the difference between a rule and a lint warning nobody reads.
local CEILING_EXEMPT = {["grug_mobs:kraken"] = "aquatic, own open-sea leash"}

local function roster()
	local by_type, ranges, problems = {}, {}, {}
	local total = 0
	for name, def in pairs(core.registered_entities) do
		-- grug_mobs registers through mobs_redo, which puts `_cmi_is_mob` on
		-- every mob prototype; arrows and our own probe entities do not have
		-- it. `name:find("grug_mobs:")` alone would also catch the arrow.
		if def._cmi_is_mob and name:find("^grug_mobs:") then
			total = total + 1
			local kind = def.attack_type or "none"
			by_type[kind] = (by_type[kind] or 0) + 1
			ranges[#ranges + 1] = name .. "=" .. tostring(def.view_range)
			if kind == "dogshoot" and def.view_range ~= 16 then
				problems[#problems + 1] = name .. " is dogshoot but sees " ..
					tostring(def.view_range) .. ", not 16"
			end
			if kind == "dogfight" and def.view_range and def.view_range > 16
					and not CEILING_EXEMPT[name] then
				problems[#problems + 1] = name .. " is melee but sees " ..
					tostring(def.view_range) .. ", above the 16 m ceiling"
			end
		end
	end
	table.sort(ranges)
	local kinds = {}
	for kind, count in pairs(by_type) do
		kinds[#kinds + 1] = kind .. "=" .. count
	end
	table.sort(kinds)
	log("roster registered=" .. total .. " " .. table.concat(kinds, " "))
	log("view_ranges " .. table.concat(ranges, " "))
	local exempt = {}
	for name, why in pairs(CEILING_EXEMPT) do
		exempt[#exempt + 1] = name .. " (" .. why .. ")"
	end
	table.sort(exempt)
	if #problems > 0 then
		log("roster PROBLEMS " .. table.concat(problems, "; "))
	else
		log("roster rule_ok dogshoot=16 melee<=16 exempt=" ..
			table.concat(exempt, ", "))
	end
end

--
-- 2. The camp config
--

local function camp_config()
	local cfg = grug_mobs.registered_camp_types
		and grug_mobs.registered_camp_types.bandit
	if not cfg then
		log("camp PROBLEM the bandit camp type is not registered")
		return
	end
	log("camp mob=" .. tostring(cfg.mob) ..
		" variant=" .. tostring(cfg.variant) ..
		" variant_chance=" .. tostring(cfg.variant_chance) ..
		" count=" .. tostring(cfg.count_min) .. "-" .. tostring(cfg.count_max) ..
		" radius=" .. tostring(cfg.radius))
end

--
-- 3. Arena and the shooting test
--

local function forceload_arena()
	local blocks = 0
	local x = ARENA.x - 16
	while x <= ARENA.x + RUN_X + 16 do
		local z = ARENA.z - HALF_Z - 16
		while z <= ARENA.z + HALF_Z + 16 do
			local y = ARENA.y - 8
			while y <= ARENA.y + 24 do
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
			for dy = 1, 4 do
				core.set_node({x = ARENA.x + dx, y = ARENA.y + dy,
					z = ARENA.z + dz}, {name = "air"})
			end
		end
	end
	return written
end

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

local state = {phase = "wait_starts", clock = 0, total = 0, poll = 0, said = -1}
local archer_object, archer_entity, target_object
local seen_arrows = {}

local function fail(reason)
	log("ranged FAIL " .. reason)
	core.request_shutdown("ranged probe: " .. reason, false, 1)
	state.phase = "done"
end

-- Arrows are counted by IDENTITY, not by a per-step census: an arrow lives
-- several steps, so counting live objects each step would count one arrow
-- many times. `seen_arrows` is keyed by the entity table itself.
local function count_arrows()
	local objects = core.get_objects_inside_radius(
		{x = ARENA.x + SHOT_RANGE / 2, y = ARENA.y + 2, z = ARENA.z},
		SHOT_RANGE + 8)
	for index = 1, #objects do
		local ent = objects[index]:get_luaentity()
		if ent and ent.name == "grug_mobs:arrow_entity"
				and not seen_arrows[ent] then
			seen_arrows[ent] = true
			arrows_seen = arrows_seen + 1
		end
	end
end

core.register_on_mods_loaded(function()
	log("arena x=" .. ARENA.x .. " y=" .. ARENA.y .. " z=" .. ARENA.z ..
		" archer=" .. ARCHER .. " window_s=" .. WINDOW ..
		" shot_range=" .. SHOT_RANGE)
	roster()
	camp_config()
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
		if state.poll < 1 then return end
		state.poll = 0
		local ready, total = grug_core.starts_ready()
		if ready ~= state.said then
			log("starts ready=" .. ready .. " of=" .. total ..
				" t=" .. string.format("%.1f", state.total))
			state.said = ready
		end
		if ready >= total then
			log("forceload blocks=" .. forceload_arena())
			state.phase, state.clock = "wait_blocks", 0
		elseif state.clock > 240 then
			fail("the six start areas did not preload within 240 s")
		end
		return
	end

	if phase == "wait_blocks" then
		state.poll = state.poll + dtime
		if state.poll < 1 then return end
		state.poll = 0
		if arena_loaded() then
			log("arena_loaded t=" .. string.format("%.1f", state.total))
			log("platform nodes=" .. build_platform())
			state.phase, state.clock = "settle", 0
		elseif state.clock > 120 then
			fail("the arena blocks did not emerge within 120 s")
		end
		return
	end

	if phase == "settle" then
		if state.clock < 2 then return end
		target_object = core.add_entity(
			{x = ARENA.x + SHOT_RANGE, y = ARENA.y + 1, z = ARENA.z},
			"grug_ranged_probe:target")
		archer_object = core.add_entity(
			{x = ARENA.x, y = ARENA.y + 1, z = ARENA.z}, ARCHER)
		if not archer_object or not target_object then
			fail("could not spawn the archer/target pair")
			return
		end
		archer_entity = archer_object:get_luaentity()
		if not archer_entity then
			fail("the archer has no luaentity")
			return
		end
		archer_entity.lifetimer = 30000
		archer_entity:do_attack(target_object, true)
		punches, arrows_seen = 0, 0
		state.phase, state.clock = "shoot", 0
		return
	end

	if phase == "shoot" then
		if not archer_object or not archer_object:get_pos()
				or not target_object or not target_object:get_pos() then
			fail("lost an object mid-window")
			return
		end
		-- Hold the target exactly SHOT_RANGE away: the archer must be made to
		-- SHOOT, and mobs_redo forces melee whenever the target is inside
		-- `reach` (api.lua:2366). Standing still at 12 m is the ranged case.
		target_object:set_pos({x = ARENA.x + SHOT_RANGE, y = ARENA.y + 1,
			z = ARENA.z})
		if archer_entity and archer_entity.state ~= "attack" then
			archer_entity:do_attack(target_object, true)
		end
		count_arrows()
		if state.clock >= WINDOW then
			local pos = archer_object:get_pos()
			local dist = math.abs((ARENA.x + SHOT_RANGE) - pos.x)
			log("ranged archer=" .. tostring(archer_entity.name) ..
				" level=" .. tostring(archer_entity._grug_level) ..
				" damage=" .. tostring(archer_entity.damage) ..
				" attack_type=" .. tostring(archer_entity.attack_type) ..
				" view_range=" .. tostring(archer_entity.view_range) ..
				" shoot_interval=" .. tostring(archer_entity.shoot_interval) ..
				" window_s=" .. string.format("%.2f", state.clock) ..
				" arrows=" .. arrows_seen ..
				" hits=" .. punches ..
				" final_dist=" .. string.format("%.2f", dist))
			if arrows_seen == 0 then
				fail("the archer fired no arrow in " .. WINDOW .. " s")
				return
			end
			log("ranged complete")
			core.request_shutdown("ranged probe done", false, 1)
			state.phase = "done"
		end
		return
	end
end)
