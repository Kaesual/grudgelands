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
	local agents = read("AGENTS.md")
	local vendor = read("VENDOR.md")
	local obstacle = assert(loadfile(repo
			.. "/mods/ENTITIES/mobs/grug_obstacle.lua"))()

	-- Bind the tested module to the shipped attack branch.
	want(api:find('local mobs_modpath = core.get_modpath("mobs")', 1, true)
			and api:find('source:match("^@(.+)/[^/]+$")', 1, true)
			and api:find('dofile(mobs_modpath .. "/grug_obstacle.lua")', 1, true),
			"api.lua does not robustly load the tested production module")
	want(api:find("grug_obstacle.target_visible(self, s, target_pos,", 1, true),
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
	want(api:find("custom_attack = self.custom_attack and function()", 1, true)
			and not api:find("local custom_allows", 1, true),
			"custom attack is not owned by the canonical LOS gate")
	want(api:find("strike_in_sight = grug_obstacle.strike_target_visible(self, s,",
			1, true), "non-ground melee bypasses its collision-box strike LOS")
	local deactivate_at = api:find("function mob_class:on_deactivate", 1, true)
	local deactivate_end = deactivate_at and api:find("-- return True if mob limit",
			deactivate_at, true)
	local deactivate_cancel = deactivate_at and api:find(
			"grug_obstacle.cancel_path_request(self.temp)", deactivate_at, true)
	want(deactivate_cancel and deactivate_end and deactivate_cancel < deactivate_end,
			"on_deactivate does not invalidate its queued A* request")
	local death_at = api:find("death boundary first invalidates any queued A* request",
			1, true)
	local death_drop = death_at and api:find("self:item_drop()", death_at, true)
	local death_cancel = death_at and api:find(
			"grug_obstacle.cancel_path_request(self.temp)", death_at, true)
	want(death_cancel and death_drop and death_cancel < death_drop,
			"death boundary does not invalidate its queued A* request")

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
	local target_visible = obstacle.target_visible(fake, source_mob,
			target_snapshot, true)
	want(not target_visible and los_calls == 1,
			"canonical target LOS was not exactly one blocked ray")
	want(source_target.y == 0 and target_snapshot.y == 0 and source_mob.y == 0,
			"target LOS mutated a source position")
	local punches = 0
	local custom_calls = 0
	local landed, consumed = obstacle.try_melee_attack({
		ready = true,
		in_reach = true,
		target_visible = target_visible,
		waypoint_visible = true,
		custom_attack = function()
			custom_calls = custom_calls + 1
			return true
		end,
		punch = function() punches = punches + 1 end,
	})
	want(not landed and not consumed and punches == 0 and custom_calls == 0,
			"blocked target LOS invoked a custom attack or punch")

	-- Non-ground attacks retain the old fixed +0.5 LOS endpoints instead of
	-- inheriting collision-box eye heights from Lane C ground melee.
	local legacy_calls = 0
	local legacy = {
		line_of_sight = function(_, mob_eye, target_eye)
			legacy_calls = legacy_calls + 1
			want(mob_eye.x == source_mob.x and mob_eye.y == 0.5,
					"non-ground source LOS geometry changed")
			want(target_eye.x == source_target.x and target_eye.y == 0.5,
					"non-ground target LOS geometry changed")
			return true
		end,
	}
	want(obstacle.target_visible(legacy, source_mob, source_target, false)
			and legacy_calls == 1,
			"non-ground attack did not use exactly one legacy LOS ray")

	-- Dogshoot melee and flying/swimming dogfight retain both historical rays:
	-- the common +0.5 ray and then the collision-box strike ray. This uses the
	-- shipped Kraken and player collision boxes from their real definitions.
	local kraken_calls = 0
	local kraken = {
		object = {get_properties = function()
			return {collisionbox = {-0.8, 0, -0.8, 0.8, 1.8, 0.8}}
		end},
		attack = {get_properties = function()
			return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}}
		end},
		line_of_sight = function(_, first, second)
			kraken_calls = kraken_calls + 1
			if first.y == 0.5 and second.y == 0.5 then return true end
			want(first.x == source_target.x and first.y == 1.53,
					"Kraken strike ray missed the player collision-box eye")
			want(second.x == source_mob.x and second.y == 1.62,
					"Kraken strike ray missed the mob collision-box eye")
			return false
		end,
	}
	local kraken_common = obstacle.target_visible(kraken, source_mob,
			source_target, false)
	local kraken_strike = obstacle.strike_target_visible(kraken, source_mob,
			source_target, kraken_common, false)
	landed, consumed = obstacle.try_melee_attack({
		ready = true, in_reach = true,
		target_visible = kraken_common and kraken_strike,
		custom_attack = function()
			custom_calls = custom_calls + 1
			return true
		end,
		punch = function() punches = punches + 1 end,
	})
	want(kraken_common and not kraken_strike and kraken_calls == 2,
			"Kraken LOS fixture did not split common and strike geometry")
	want(not landed and not consumed and custom_calls == 0 and punches == 0,
			"non-ground melee crossed a blocked collision-box strike ray")

	-- Blocked-LOS delay and fair server-wide A* budget. Stable object order
	-- must not let the first mobs monopolize the two starts per server step.
	local state = {}
	for _ = 1, 9 do
		want(not obstacle.close_path_due(state, 0.11, true, true, false),
				"A* became due before about one second")
	end
	want(obstacle.close_path_due(state, 0.11, true, true, false),
			"A* was not due after about one second")
	local contenders = {}
	local attempted = {}
	local attempt_count = 0
	local last_attempt_step = 0
	for index = 1, 100 do contenders[index] = {} end
	for step = 1, 200 do
		obstacle.begin_server_step()
		local starts = 0
		for index = 1, 100 do
			if not attempted[index]
			and obstacle.claim_path_budget(contenders[index]) then
				attempted[index] = true
				attempt_count = attempt_count + 1
				last_attempt_step = step
				starts = starts + 1
			end
		end
		want(starts <= obstacle.path_budget_per_step,
				"more than two A* starts escaped one server step")
		if attempt_count == 100 then break end
	end
	want(attempt_count == 100,
			"stable object order starved at least one of 100 A* waiters")
	want(last_attempt_step * 0.09 < 18,
			"A* FIFO did not serve every mob before attack patience expired")

	-- Death/unload invalidation releases the queue's strong temp reference
	-- immediately and lets the next live waiter use the very next grant.
	obstacle.begin_server_step()
	want(obstacle.claim_path_budget({}), "lifecycle fixture lost first token")
	want(obstacle.claim_path_budget({}), "lifecycle fixture lost second token")
	local dead = {}
	local unloaded = {}
	local live = {}
	want(not obstacle.claim_path_budget(dead), "dead fixture was not queued")
	want(not obstacle.claim_path_budget(unloaded), "unload fixture was not queued")
	want(not obstacle.claim_path_budget(live), "live fixture was not queued")
	local released = setmetatable({dead, unloaded}, {__mode = "v"})
	obstacle.cancel_path_request(dead)
	obstacle.cancel_path_request(unloaded)
	dead = nil
	unloaded = nil
	collectgarbage("collect")
	collectgarbage("collect")
	want(released[1] == nil and released[2] == nil,
			"cancelled queue entry retained a dead or unloaded temp table")
	obstacle.begin_server_step()
	want(obstacle.claim_path_budget(live),
			"dead or unloaded queue entries consumed a later A* grant")

	-- Abort + re-enqueue gets a new generation at the tail. The stale C slot
	-- must not jump ahead of D just because both slots refer to the same temp.
	obstacle.begin_server_step()
	want(obstacle.claim_path_budget({}), "generation fixture lost first token")
	want(obstacle.claim_path_budget({}), "generation fixture lost second token")
	local waiter_a, waiter_c, waiter_d, waiter_e = {}, {}, {}, {}
	local _, generation_a = obstacle.claim_path_budget(waiter_a)
	local _, old_generation_c = obstacle.claim_path_budget(waiter_c)
	local _, generation_d = obstacle.claim_path_budget(waiter_d)
	local _, generation_e = obstacle.claim_path_budget(waiter_e)
	obstacle.cancel_path_request(waiter_c)
	local queued, new_generation_c = obstacle.claim_path_budget(waiter_c)
	want(not queued and new_generation_c > old_generation_c,
			"re-enqueued waiter did not receive a new generation")
	want(not obstacle.path_request_current(waiter_c, old_generation_c)
			and obstacle.path_request_current(waiter_c, new_generation_c),
			"stale generation remained current after re-enqueue")
	obstacle.begin_server_step()
	want(obstacle.claim_path_budget(waiter_a), "FIFO did not grant A first")
	want(not obstacle.claim_path_budget(waiter_c),
			"re-enqueued C reused its stale queue slot")
	want(obstacle.claim_path_budget(waiter_d),
			"FIFO did not grant D after stale C was skipped")
	want(not obstacle.claim_path_budget(waiter_e),
			"third live waiter escaped the two-start cap")
	obstacle.cancel_path_request(waiter_c)
	obstacle.cancel_path_request(waiter_e)

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

	-- Cover banks a ready swing without invoking custom effects; visible
	-- contact invokes the hook exactly once and lands. A custom decline is
	-- still the one non-hit path that consumes cadence.
	landed, consumed = obstacle.try_melee_attack({
		ready = true, in_reach = true,
		target_visible = true, punch = function() punches = punches + 1 end,
		custom_attack = function()
			custom_calls = custom_calls + 1
			return true
		end,
	})
	want(landed and consumed and punches == 1 and custom_calls == 1,
			"visible target did not invoke one custom hook and land")
	landed, consumed = obstacle.try_melee_attack({
		ready = true, in_reach = true,
		target_visible = true, punch = function() punches = punches + 1 end,
		custom_attack = function()
			custom_calls = custom_calls + 1
			return false
		end,
	})
	want(not landed and consumed and punches == 1 and custom_calls == 2,
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
	-- The inventory number in AGENTS.md must equal the marker count in the
	-- vendored file; a literal number here went stale twice in round 5.
	local documented = tonumber(agents:match("(%d+) `GRUG PATCH` sites"))
	local counted = select(2, api:gsub("GRUG PATCH", ""))
	want(documented and documented == counted,
			"AGENTS.md patch inventory is stale: documents "
			.. tostring(documented) .. ", api.lua carries " .. counted)
	want(vendor:find("**59 markers in `mobs/api.lua`", 1, true),
			"VENDOR.md patch inventory is stale")

	say("production", "module", "grug_obstacle.lua", "target_los_calls", los_calls,
			"path_budget", obstacle.path_budget_per_step,
			"path_backoff", obstacle.path_backoff, "fifo_mobs", attempt_count,
			"fifo_last_step", last_attempt_step, "lifecycle_release", true,
			"generation_fifo", generation_a, old_generation_c, generation_d,
			generation_e, new_generation_c, "kraken_los_calls", kraken_calls)
	say("obstacle", "delay", obstacle.path_delay, "path_retained", true,
			"sidesteps", first_side, second_side, "blocked_contact_moves", true,
			"visible_contact_stops", true, "blocked_swing_banked", true)
	say("wp11_combat_obstacle", "PASS")
	return table.concat(report)
end
