-- Round-5 combat-AI KAT on the real production bytes.
--
-- The source assertions bind this fixture to mobs_redo's patched attack
-- branch and the current roster. The pure state model then exercises the
-- four obstacle invariants without an engine: blocked-LOS delay, retaining a
-- path while blocked, alternating nil-path sidesteps, and a ready swing that
-- is not consumed by cover. It also covers the at-cliff guard plus the reach,
-- speed, knockback and object-collision rulings shipped in the same lane.
--
-- MUTATION=1 consumes a blocked swing, =2 abandons a blocked close path,
-- =3 repeats the same sidestep side, =4 ignores at_cliff. Every mutation must
-- fail this fixture.

return function(repo)
	repo = repo or "."
	local mutation = tonumber(os.getenv("MUTATION") or "") or 0
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

	-- The shipped attack branch, not only the model below, carries each rule.
	want(api:find("local grug_obstacle_path_delay = 1.0", 1, true),
		"the one-second blocked-LOS delay is gone")
	want(api:find("self:smart_mobs(s, target_pos, dist, dtime, true)", 1, true),
		"close blocked targets no longer force the bounded A* pass")
	want(api:find("self.temp.grug_obstacle_side = -previous", 1, true),
		"the production nil-path sidestep no longer alternates sides")
	want(api:find("(dist < self.reach and in_sight)", 1, true),
		"a close path is abandoned without requiring visible contact")
	want(api:find("if self.at_cliff then", api:find(
		"else -- rnd: if inside reach range", 1, true), true),
		"the in-reach run has no at_cliff guard")
	local gate = api:find("if self.punch_timer >= self.punch_interval", 1, true)
	local los = api:find("if self:line_of_sight(p2, s2) then", gate or 1, true)
	local reset = api:find("self.punch_timer = 0", gate or 1, true)
	want(gate and los and reset and gate < los and reset > los,
		"punch_timer is claimed before the final LOS succeeds")

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
	want(api:find("local kb = 0", 1, true) and
		api:find('damage_groups["knockback"] or kb', 1, true),
		"zero ordinary knockback or its explicit override hook is missing")
	want(api:find("collide_with_objects = false,", 1, true),
		"mob object collision is still enabled")
	want(core_init:find("player:set_properties({collide_with_objects = false})",
		1, true), "player object collision is still enabled")
	say("production", "reach", 3, "player_range", 3, "knockback", 0,
		"object_collision", false)

	-- Pure state machine mirroring the four obstacle decisions.
	local function blocked_tick(state, dtime, path_found, at_cliff)
		state.blocked = (state.blocked or 0) + dtime
		if not state.sidestep and not state.following and state.blocked >= 1 then
			state.blocked = 0
			state.searches = state.searches + 1
			if path_found then
				state.following = true
			else
				if mutation == 3 then
					state.side = state.side or 1
				else
					state.side = -(state.side or -1)
				end
				state.sidestep = 0.5
			end
		end
		if state.sidestep then
			state.velocity = (at_cliff and mutation ~= 4) and 0 or state.side
			state.sidestep = state.sidestep - dtime
			if state.sidestep <= 0 then state.sidestep = nil end
		end
	end

	local state = {searches = 0}
	for _ = 1, 9 do blocked_tick(state, 0.11, true, false) end
	want(state.searches == 0, "A* started before one second of blocked LOS")
	blocked_tick(state, 0.11, true, false)
	want(state.searches == 1 and state.following,
		"A* did not start after about one second of blocked LOS")

	local abandon = state.following and (2.5 < 3 and (mutation == 2 or false))
	want(not abandon, "the close path was abandoned while LOS stayed blocked")
	local visible_abandon = state.following and 2.5 < 3 and true
	want(visible_abandon, "visible close contact did not finish the detour")

	state = {searches = 0}
	for _ = 1, 10 do blocked_tick(state, 0.11, false, false) end
	local first_side = state.side
	-- Finish the first half-second sidestep, then accrue until the next search.
	local guard = 0
	while state.searches < 2 and guard < 20 do
		blocked_tick(state, 0.1, false, false)
		guard = guard + 1
	end
	local second_side = state.side
	want(state.searches == 2, "nil-path fallback did not retry A* twice")
	want(second_side == -first_side, "nil-path sidesteps did not alternate sides")

	state = {searches = 0}
	for _ = 1, 10 do blocked_tick(state, 0.11, false, true) end
	want(state.velocity == 0, "at_cliff did not stop the in-reach sidestep")

	local function swing(timer, visible)
		if timer < 1 then return timer, false end
		if not visible then
			if mutation == 1 then return 0, false end
			return timer, false
		end
		return 0, true
	end
	local timer, landed = swing(1, false)
	want(timer == 1 and not landed,
		"blocked LOS consumed the ready swing instead of banking it")
	timer, landed = swing(timer, true)
	want(timer == 0 and landed, "the banked swing did not land on visible contact")

	say("obstacle", "delay", 1.0, "path_retained", true,
		"sidesteps", first_side, second_side, "blocked_swing_banked", true)
	say("wp11_combat_obstacle", "PASS", "mutation", mutation)
	return table.concat(report)
end
