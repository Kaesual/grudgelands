-- The mob attack cadence, as arithmetic, on the shipped api.lua bytes.
--
-- combat_stats.md §4 "Catching up must be enough to hit" (decided
-- 2026-08-13, restated as user ruling 1 on 2026-09-16) makes four claims
-- about the vendored `mods/ENTITIES/mobs/api.lua` dogfight branch, and all
-- four are arithmetic over `dtime`, `punch_interval`, `dist` and `reach`:
--
--   1. THE CLOCK RUNS DURING THE CHASE. `punch_timer` advances on every tick
--      with a live target, not only while the target is inside reach.
--   2. THE BACKLOG IS CAPPED AT ONE. Ten seconds of chasing land one hit on
--      arrival, not ten (combat_stats.md:153, "lag never replays a backlog").
--   3. OUT OF REACH DOES NOT RESET. A cadence that comes due out of reach
--      stays due, so the hit lands on the first tick reach is regained.
--   4. A STANDING TARGET'S RATE IS UNCHANGED. Exactly one punch per
--      `punch_interval`, which is what the patch may not cost.
--
-- This KAT extracts the three patched fragments from the REAL api.lua by
-- their GRUG PATCH markers, asserts they are the expressions the design
-- describes, and then runs the same arithmetic over a simulated chase. It
-- cannot prove the mob FEELS right; that is the headless probe
-- (tools/wp11/cadence_probe.lua) and, finally, the user's playtest.
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.
--
--     luajit          -e 'io.write(dofile("tools/wp11/mob_cadence_kat.lua")("."))'
--     tools/bin/lua51 -e 'io.write(dofile("tools/wp11/mob_cadence_kat.lua")("."))'
--
-- MUTATION=1 restores upstream's "the clock only runs in reach", =2 removes
-- the backlog cap, =3 resets the timer when the cadence is due out of reach.
-- Each must make this KAT fail.

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
		error("wp11 mob cadence: " .. message, 0)
	end
	local function want(condition, message)
		if not condition then
			fail(message)
		end
	end

	-- ------------------------------------------------------------------
	-- 1. The shipped bytes really carry the three fragments.
	-- ------------------------------------------------------------------
	local handle = io.open(repo .. "/mods/ENTITIES/mobs/api.lua")
	want(handle, "cannot read mods/ENTITIES/mobs/api.lua")
	local api = handle:read("*a")
	handle:close()

	-- The accumulator sits at the TOP of the dogfight branch, above the
	-- `dist > reach` test -- that is what "during the chase" means in code.
	local branch = api:find('elseif self.attack_type == "dogfight"', 1, true)
	want(branch, "the dogfight branch is gone")
	local accumulate = api:find(
		"self.punch_timer = (self.punch_timer or 0) + dtime", branch, true)
	local reach_test = api:find(
		"if dist > (self.reach + (self.reach_ext or 0)) then", branch, true)
	want(accumulate and reach_test and accumulate < reach_test,
		"punch_timer no longer accumulates ABOVE the in-reach test: the " ..
		"cadence would run only while the mob stands still, which is the " ..
		"defect combat_stats.md §4 describes")

	-- Exactly one accumulator in the whole file: two would double the rate.
	local count, from = 0, 1
	while true do
		local at = api:find(
			"self.punch_timer = (self.punch_timer or 0) + dtime", from, true)
		if not at then break end
		count = count + 1
		from = at + 1
	end
	want(count == 1, "api.lua advances punch_timer at " .. count ..
		" sites, not one")

	want(api:find("if self.punch_timer > self.punch_interval then", 1, true)
		and api:find("self.punch_timer = self.punch_interval", 1, true),
		"the at-most-one-backlog cap is gone")

	-- The punch's own gate carries the in-reach test.
	want(api:find("if self.punch_timer >= self.punch_interval\n" ..
		"\t\t\tand dist <= (self.reach + (self.reach_ext or 0)) then", 1, true),
		"the punch is no longer gated on being in reach at the moment the " ..
		"cadence is due")

	-- The unconditional in-reach velocity zero is gone, the contact
	-- distance took its place, and `reach` itself is untouched.
	want(api:find("if dist > self.reach * 0.6 then", 1, true),
		"the contact distance is gone; the mob freezes for the whole " ..
		"in-reach branch again")
	local in_reach = api:find("else -- rnd: if inside reach range", 1, true)
	local next_branch = api:find('elseif self.attack_type == "shoot"',
		in_reach or 1, true)
	local segment = api:sub(in_reach or 1, next_branch or #api)
	local zeros, at = 0, 1
	while true do
		local found = segment:find("self:set_velocity(0)", at, true)
		if not found then break end
		zeros = zeros + 1
		at = found + 1
	end
	want(zeros == 1, "the in-reach branch zeroes the velocity at " .. zeros ..
		" sites; exactly one, under the contact-distance test, is the patch")
	want(api:find("punch_interval = def.punch_interval or 1", 1, true),
		"punch_interval is no longer the mobs_redo default of 1 s")
	say("api_fragments", "accumulator_above_reach_test", "cap", "reach_gate",
		"contact_distance")

	-- ------------------------------------------------------------------
	-- 2. The same arithmetic, simulated -- BEFORE and AFTER.
	-- ------------------------------------------------------------------
	-- `upstream` runs vendored mobs_redo's own two rules (the clock advances
	-- only inside the in-reach branch, and the mob freezes for the whole of
	-- it); `patched` runs what api.lua now does. Both are driven by the same
	-- chase model, so the two numbers are comparable, and the "roughly one
	-- landed hit per ten seconds" of combat_stats.md §4 -- which that file
	-- says outright is worked from the server step rather than measured --
	-- finally gets a number of its own.
	local STEP = 0.09 -- dedicated_server_step default (defaultsettings.cpp:498)
	local INTERVAL = 1 -- api.lua's punch_interval default
	local REACH = 2.0 -- 20 of 22 roster values (the card §2)
	local CONTACT = REACH * 0.6 -- the patch's contact distance
	local PLAYER = 4.0 -- movement_speed_walk (mounts.md:50-51)
	local MOB = 4.4 -- the aggressive band (combat_stats.md §3)

	-- One mob tick of the PATCHED branch. `in_reach` is the world model.
	local function tick(mob, dtime, in_reach)
		mob.punch_timer = (mob.punch_timer or 0) + dtime
		if mutation == 1 then
			-- Upstream: the clock advances only while the target is in reach.
			mob.punch_timer = mob.punch_timer - dtime
			if in_reach then
				mob.punch_timer = mob.punch_timer + dtime
			end
		end
		if mutation ~= 2 and mob.punch_timer > mob.punch_interval then
			mob.punch_timer = mob.punch_interval
		end
		if mob.punch_timer >= mob.punch_interval then
			if in_reach then
				mob.punch_timer = 0
				return true
			elseif mutation == 3 then
				mob.punch_timer = 0 -- the defect in a new shape
			end
		end
		return false
	end

	-- The same tick with upstream's rules, used only for the BEFORE column.
	local function upstream_tick(mob, dtime, in_reach)
		if not in_reach then
			return false -- the clock does not advance outside the branch
		end
		mob.punch_timer = (mob.punch_timer or 0) + dtime
		if mob.punch_timer >= mob.punch_interval then
			mob.punch_timer = 0
			return true
		end
		return false
	end

	local ticks = math.floor(10 / STEP)

	-- `freeze` is the movement half: upstream stops the mob for the whole
	-- in-reach branch, the patch runs it down to the contact distance.
	local function chase(step_fn, freeze, target_speed)
		local mob = {punch_interval = INTERVAL}
		local gap, landed, worst = REACH, 0, REACH
		for _ = 1, ticks do
			local in_reach = gap <= REACH
			local mob_speed = MOB
			if freeze then
				if in_reach then mob_speed = 0 end
			elseif gap <= CONTACT then
				mob_speed = 0
			end
			gap = gap + (target_speed - mob_speed) * STEP
			if gap < CONTACT then gap = CONTACT end
			if gap > worst then worst = gap end
			if step_fn(mob, STEP, gap <= REACH) then landed = landed + 1 end
		end
		return landed, worst, mob
	end

	-- 2a. A STANDING target: the control the decided text demands stay
	--     unchanged. The ideal is 10 hits in 10 s; the honest number is 9,
	--     because a landed punch resets the timer to 0 and discards the
	--     overshoot (upstream's own arithmetic, kept), so at a 0.09 s step
	--     the effective interval is ceil(1 / 0.09) x 0.09 = 1.08 s.
	-- MUTATION=1 reverts BOTH halves of the patch, clock and movement, so it
	-- is the honest "put upstream back" mutation rather than half of one.
	local reverted = mutation == 1
	local before_standing = chase(upstream_tick, true, 0)
	local after_standing = chase(tick, reverted, 0)
	want(after_standing == before_standing,
		"a STANDING target took " .. after_standing ..
		" hits in 10 s after the patch against " .. before_standing ..
		" before it -- the control must not move")
	want(after_standing == 9, "the standing rate is " .. after_standing ..
		" per 10 s, not the 9 the 1.08 s effective interval gives")
	say("standing_10s", "before", before_standing, "after", after_standing,
		"step", STEP, "interval", INTERVAL, "effective", 1.08)

	-- 2b. A target RECEDING at the player's walk speed, which is the whole
	--     of ruling 1.
	local before_receding = chase(upstream_tick, true, PLAYER)
	local after_receding, worst = chase(tick, reverted, PLAYER)
	want(before_receding <= 1, "the UNPATCHED arithmetic lands " ..
		before_receding .. " hits per 10 s on a fleeing target; " ..
		"combat_stats.md §4 describes roughly one")
	want(after_receding == after_standing,
		"a target receding at walk speed took " .. after_receding ..
		" hits in 10 s against a standing target's " .. after_standing ..
		" -- ruling 1 asks for the same rate")
	want(worst <= REACH, "the mob fell out of reach: worst gap " .. worst)
	say("receding_10s", "before", before_receding, "after", after_receding,
		"worst_gap", string.format("%.3f", worst), "reach", REACH)

	-- 2c. The backlog cap: 10 s of pure chase out of reach, then arrival.
	local mob = {punch_interval = INTERVAL}
	local landed = 0
	for _ = 1, ticks do
		if tick(mob, STEP, false) then landed = landed + 1 end
	end
	want(landed == 0, "a mob landed " .. landed ..
		" hits while never being in reach")
	want(mob.punch_timer == INTERVAL,
		"after a long chase the timer reads " .. mob.punch_timer ..
		", not the one banked attack the cap allows")
	landed = 0
	for _ = 1, 5 do
		if tick(mob, STEP, true) then landed = landed + 1 end
	end
	want(landed == 1, "arriving after a 10 s chase landed " .. landed ..
		" hits, not exactly one")
	say("backlog", "chase_10s_then_arrive", landed)

	-- 2d. Out of reach when due does not consume the cadence.
	mob = {punch_interval = INTERVAL}
	for _ = 1, 12 do tick(mob, 0.1, false) end -- 1.2 s, all out of reach
	want(mob.punch_timer == INTERVAL,
		"a cadence that came due out of reach was consumed: timer " ..
		mob.punch_timer)
	want(tick(mob, 0.0, true),
		"the banked attack did not land on the first tick back in reach")
	say("no_reset_out_of_reach", "ok")

	say("wp11_mob_cadence", "PASS", "mutation", mutation)
	return table.concat(report)
end
