-- Round-5 combat-AI KAT. This loads the same small production state module
-- that mobs/api.lua calls; there is no duplicated obstacle model here.

return function(repo)
	repo = repo or "."
	local report = {}

	local function say(...)
		local parts = {}
		for index = 1, select("#", ...) do
			parts[index] = tostring((select(index, ...)))
		end
		report[#report + 1] = table.concat(parts, "\t") .. "\n"
	end

	local function fail(message)
		error("wp11 combat obstacle: " .. message, 0)
	end

	local function want(condition, message)
		if not condition then fail(message) end
	end

	local function read(path)
		local handle = io.open(repo .. "/" .. path)
		want(handle, "cannot read " .. path)
		local bytes = handle:read("*a")
		handle:close()
		return bytes
	end

	local api = read("mods/ENTITIES/mobs/api.lua")
	local kits = read("mods/PLAYER/grug_abilities/kits.lua")
	local telegraph = read("mods/ENTITIES/grug_mobs/telegraph.lua")
	local core_init = read("mods/CORE/grug_core/init.lua")
	local obstacle = assert(loadfile(repo
			.. "/mods/ENTITIES/mobs/grug_obstacle.lua"))()

	-- Bind the tested module to the shipped attack branch.
	want(api:find('dofile(core.get_modpath("mobs") .. "/grug_obstacle.lua")',
			1, true), "api.lua does not load the tested production module")
	want(api:find("grug_obstacle.target_visible(self, s, target_pos)", 1, true),
			"attack state bypasses canonical target LOS")
	want(api:find("grug_obstacle.try_melee_attack({", 1, true),
			"attack state bypasses the tested punch gate")
	want(api:find("self:smart_mobs(s, target_pos, dist, dtime, false, in_sight)",
			1, true), "ordinary A* does not reuse canonical target LOS")
	want(api:find("grug_obstacle.should_close_contact(", 1, true),
			"contact stop bypasses the tested production decision")
	want(api:find("grug_obstacle.note_exhausted_blocked_path(obstacle_state)",
			1, true), "exhausted blocked paths bypass the sidestep fallback")
	want(not api:find("local p2, s2 = p, s", 1, true),
			"legacy waypoint-aliasing final LOS returned")

	-- One fresh target snapshot and one LOS ray. A visible waypoint must not
	-- authorize a punch through a wall to the real target.
	local source_target = {x = 2, y = 0, z = 0}
	local source_mob = {x = 0, y = 0, z = 0}
	local waypoint = {x = 0, y = 0, z = 1}
	local target_snapshot = obstacle.copy_pos(source_target)
	local movement_snapshot = obstacle.copy_pos(waypoint)
	movement_snapshot.y = 99
	want(waypoint.y == 0, "movement mutated the stored waypoint")
	local los_calls = 0
	local fake = {
		object = {get_properties = function()
			return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3}}
		end},
		attack = {get_properties = function()
			return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3}}
		end},
		line_of_sight = function(_, target_eye, mob_eye)
			los_calls = los_calls + 1
			want(target_eye.x == source_target.x and mob_eye.x == source_mob.x,
					"canonical LOS was aimed at a waypoint")
			return false
		end,
	}
	local target_visible = obstacle.target_visible(fake, source_mob, target_snapshot)
	want(not target_visible and los_calls == 1,
			"canonical target LOS was not exactly one blocked ray")
	want(source_target.y == 0 and target_snapshot.y == 0 and source_mob.y == 0,
			"target LOS mutated a source position")
	local punches = 0
	local landed, consumed = obstacle.try_melee_attack({
		ready = true,
		in_reach = true,
		custom_allows = true,
		target_visible = target_visible,
		waypoint_visible = true,
		punch = function() punches = punches + 1 end,
	})
	want(not landed and not consumed and punches == 0,
			"visible waypoint authorized a punch through blocked target LOS")

	-- Blocked-LOS delay and server-wide A* budget/backoff.
	local state = {}
	for _ = 1, 9 do
		want(not obstacle.close_path_due(state, 0.11, true, true, false),
				"A* became due before about one second")
	end
	want(obstacle.close_path_due(state, 0.11, true, true, false),
			"A* was not due after about one second")
	obstacle.begin_server_step()
	local first, second, third = {}, {}, {}
	want(obstacle.claim_path_budget(first), "first A* token was denied")
	want(obstacle.claim_path_budget(second), "second A* token was denied")
	want(not obstacle.claim_path_budget(third), "third A* escaped per-step cap")
	want(third.grug_obstacle_backoff == obstacle.path_backoff,
			"budget denial did not install per-mob backoff")
	obstacle.tick_backoff(third, obstacle.path_backoff - 0.01)
	want(not obstacle.claim_path_budget(third), "backoff ended too early")
	obstacle.tick_backoff(third, 0.02)
	obstacle.begin_server_step()
	want(obstacle.claim_path_budget(third), "mob did not retry after backoff")

	-- A blocked close path persists; visible contact may finish it.
	want(obstacle.keep_path(2.5, 3, false),
			"close path was abandoned while target LOS stayed blocked")
	want(not obstacle.keep_path(2.5, 3, true),
			"visible close contact did not finish the detour")
	want(obstacle.should_close_contact(1.5, 3, false),
			"blocked LOS stopped movement at contact distance")
	want(not obstacle.should_close_contact(1.5, 3, true),
			"visible target did not stop movement at contact distance")

	state = {}
	obstacle.note_exhausted_blocked_path(state)
	want(state.grug_obstacle_sidestep == obstacle.sidestep_time,
			"exhausted blocked path did not start the sidestep fallback")
	want(state.grug_obstacle_backoff == obstacle.path_backoff
			and state.grug_obstacle_blocked == obstacle.path_delay,
			"exhausted blocked path did not retain a backoff-ready A* request")

	-- Nil paths alternate their preferred side. Direction safety is tested on
	-- the actual candidate vector: unsafe first side tries the opposite; two
	-- unsafe sides stand.
	state = {}
	obstacle.note_path_result(state, false)
	local first_side = state.grug_obstacle_side
	obstacle.note_path_result(state, false)
	local second_side = state.grug_obstacle_side
	want(first_side == -second_side, "nil-path sidesteps did not alternate")
	local probes = {}
	local velocity, chosen = obstacle.choose_sidestep(source_mob, source_target,
			1, 4.6, function(candidate)
			probes[#probes + 1] = candidate.z
			return candidate.z < 0
		end)
	want(#probes == 2 and velocity and chosen == -1 and velocity.z < 0,
			"unsafe preferred side did not fall back to safe opposite side")
	velocity = obstacle.choose_sidestep(source_mob, source_target, 1, 4.6,
			function() return false end)
	want(velocity == nil, "two unsafe sidestep directions did not stand")

	-- Cover banks a ready swing; visible contact lands it. A custom decline is
	-- still the one non-hit path that consumes cadence.
	landed, consumed = obstacle.try_melee_attack({
		ready = true, in_reach = true, custom_allows = true,
		target_visible = true, punch = function() punches = punches + 1 end,
	})
	want(landed and consumed and punches == 1,
			"banked swing did not land on visible target contact")
	landed, consumed = obstacle.try_melee_attack({
		ready = true, in_reach = true, custom_allows = false,
		target_visible = true, punch = function() punches = punches + 1 end,
	})
	want(not landed and consumed and punches == 1,
			"custom decline lost its cadence-consuming behavior")

	-- R1/R2/R14/R15 values on their real definitions.
	local reach_files = {
		"bandit.lua", "bear.lua", "boar.lua", "boar_variants.lua",
		"bog_ooze.lua", "crocodile.lua", "eagle.lua", "golem.lua",
		"guard.lua", "hyena.lua", "jungle_ape.lua", "jungle_lynx.lua",
		"mirefolk.lua", "panther.lua", "serpent.lua", "skeleton_archer.lua",
		"skeleton_raider.lua", "spider.lua", "wolf.lua", "zombie.lua",
	}
	for index = 1, #reach_files do
		local path = "mods/ENTITIES/grug_mobs/" .. reach_files[index]
		want(read(path):find("reach = 3,", 1, true), path .. " is not reach 3")
	end

	local speed_values = {
		["stag.lua"] = "run_velocity = 4.6",
		["ram.lua"] = "run_velocity = 4.6",
		["zebra.lua"] = "run_velocity = 4.6",
		["carrion_crow.lua"] = "run_velocity = 4.6",
		["zombie.lua"] = "run_velocity = 4.6",
		["golem.lua"] = "run_velocity = 4.6",
		["bandit_archer.lua"] = "run_velocity = 4.0",
		["skeleton_archer.lua"] = "run_velocity = 4.0",
		["skeleton_raider.lua"] = "run_velocity = 4.0",
		["bog_ooze.lua"] = "run_velocity = 2.6",
		["kraken.lua"] = "run_velocity = 5",
	}
	for file, needle in pairs(speed_values) do
		local path = "mods/ENTITIES/grug_mobs/" .. file
		want(read(path):find(needle, 1, true), path .. " lost " .. needle)
	end

	local swing_ids = {"strike", "mighty_blow", "hamstring"}
	for index = 1, #swing_ids do
		local start_at = kits:find('id = "' .. swing_ids[index] .. '"', 1, true)
		local range_at = start_at and kits:find("range = 3,", start_at, true)
		local close_at = start_at and kits:find("})", start_at, true)
		want(start_at and range_at and close_at and range_at < close_at,
				"swing " .. swing_ids[index] .. " is not range 3")
	end
	want(telegraph:find("(self.reach or 3) + RANGE_BONUS", 1, true),
			"telegraph cone fallback did not move with mob reach")
	want(api:find("local kb = 0", 1, true)
			and api:find('damage_groups["knockback"] or kb', 1, true),
			"zero ordinary knockback or explicit override hook is missing")
	want(api:find("collide_with_objects = false,", 1, true),
			"mob object collision is still enabled")
	want(core_init:find("player:set_properties({collide_with_objects = false})",
			1, true), "player object collision is still enabled")

	say("production", "module", "grug_obstacle.lua", "target_los_calls", los_calls,
			"path_budget", obstacle.path_budget_per_step,
			"path_backoff", obstacle.path_backoff)
	say("obstacle", "delay", obstacle.path_delay, "path_retained", true,
			"sidesteps", first_side, second_side, "blocked_contact_moves", true,
			"visible_contact_stops", true, "blocked_swing_banked", true)
	say("wp11_combat_obstacle", "PASS")
	return table.concat(report)
end
