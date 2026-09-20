-- The grug_core movement aggregator, on its real shipped bytes.
--
-- What this proves, by loading mods/CORE/grug_core/movement.lua against a
-- stub engine and a controllable clock:
--
--   1. BASELINE PER AXIS. A player with no effect at all is speed 1 / jump 1
--      and the aggregator has written nothing to the engine.
--   2. ADDITIVE OVERLAP UNDER ONE CLAMP (ruling 26, skill_trees.md §5):
--      two modifiers on one axis add, the sum is clamped to [0.1, 1.5], and
--      the two axes are independent.
--   3. INDEPENDENT EXPIRY (ruling 11): each named modifier carries its own
--      duration; the shorter one falling away leaves the longer one running
--      at its own value. No entry expires because another one did.
--   4. ROOT IS A HARD FLAG, not a "-1000 %": speed 0 and jump 0 regardless
--      of a running +50 % sprint, and the sprint is still there underneath
--      when the root ends. A SECOND root keeps the LATER expiry, so a short
--      root can never cut a long one short (coordinator decision 2026-09-16,
--      the same policy the named modifiers follow).
--   5. IMMUNITY discards roots and negative modifiers, keeps positives, and
--      an inert slow still expires on its own clock.
--   6. THE EXCLUSIVE HOLD outranks root and sum, counts holders, releases
--      exactly, owns gravity while it runs and hands gravity back as
--      exactly 1 -- with NO SNAPSHOT: a slow that was running when the hold
--      began is still running, at its own value, when the hold releases.
--      That is the character-creation bug of skill_trees.md §3.9 stated as
--      a test.
--   7. THE JOIN/LEAVE RESET drops everything (physics overrides are not
--      persisted by the engine).
--   8. THE THREE MIGRATED CALLERS produce the shipped numbers: the mob web's
--      stronger-and-longer merge, Frost Nova's two overlapping stages
--      (0.1/0.3 for 4 s, then 0.5/1 for 3 s) and Hamstring's 0.5 for 5 s.
--      Those are read off the real mods/ENTITIES/grug_mobs/verbs.lua and
--      mods/PLAYER/grug_abilities/kits.lua stage tables via the same public
--      API the game uses, so the KAT cannot drift from the shipped applier.
--   9. THE MUTATIONS the brief names go red: multiplicative combination,
--      a root written as a -1000 % modifier, and a snapshot restore left in
--      the hold. Run with MUTATION=<n> to see one fail on purpose.
--
-- What it does NOT prove: that a player in a running world FEELS slower --
-- that is `physics_override` and the engine, and the note says so.
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.
--
--     luajit          -e 'io.write(dofile("tools/wp11/move_aggregator_kat.lua")("."))'
--     tools/bin/lua51 -e 'io.write(dofile("tools/wp11/move_aggregator_kat.lua")("."))'
--
-- MUTATION=1 multiplicative combination, =2 root as -1000 %, =3 snapshot
-- restore in the hold, =4 a second `set_root` replacing unconditionally
-- instead of keeping the later expiry. Each must make this KAT fail.

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
		error("wp11 move aggregator: " .. message, 0)
	end
	local function want(condition, message)
		if not condition then
			fail(message)
		end
	end
	local function near(actual, expected, message)
		if type(actual) ~= "number" or math.abs(actual - expected) > 1e-9 then
			fail(message .. ": expected " .. tostring(expected) ..
				", got " .. tostring(actual))
		end
	end

	-- ------------------------------------------------------------------
	-- 0. The stub engine: one controllable monotonic clock, one player.
	-- ------------------------------------------------------------------
	local saved_core, saved_grug_core, saved_grug_mobs, saved_vector =
		rawget(_G, "core"), rawget(_G, "grug_core"),
		rawget(_G, "grug_mobs"), rawget(_G, "vector")

	local clock_us = 1000000 -- never start at 0: an expiry of 0 must be real
	local joinplayer, leaveplayer, globalsteps = {}, {}, {}
	local online = {}
	local afters = {}

	local function new_player(name, physics)
		local player = {
			name = name,
			physics = physics or {speed = 1, jump = 1, gravity = 1},
			writes = 0,
		}
		function player:get_player_name() return self.name end
		function player:is_player() return true end
		function player:get_physics_override()
			local copy = {}
			for key, value in pairs(self.physics) do copy[key] = value end
			return copy
		end
		function player:set_physics_override(value)
			for key, value2 in pairs(value) do self.physics[key] = value2 end
			self.writes = self.writes + 1
		end
		online[name] = player
		return player
	end

	core = {
		is_player = function(obj) return obj and obj.is_player ~= nil end,
		get_player_by_name = function(name) return online[name] end,
		get_us_time = function() return clock_us end,
		get_connected_players = function()
			local list = {}
			for _, player in pairs(online) do list[#list + 1] = player end
			return list
		end,
		register_on_joinplayer = function(fn)
			joinplayer[#joinplayer + 1] = fn
		end,
		register_on_leaveplayer = function(fn)
			leaveplayer[#leaveplayer + 1] = fn
		end,
		register_globalstep = function(fn)
			globalsteps[#globalsteps + 1] = fn
		end,
		after = function(delay, fn) afters[#afters + 1] = {delay, fn} end,
		log = function() end,
		register_on_punchplayer = function() end,
		get_objects_inside_radius = function() return {} end,
	}
	grug_core = {}
	function grug_core.mono_time() return clock_us / 1e6 end

	local ok, failure = pcall(function()

	dofile(repo .. "/mods/CORE/grug_core/movement.lua")

	-- MUTATIONS. Each replaces one decided property with the wrong one the
	-- brief names, by wrapping the public API the same way the game calls it.
	if mutation == 1 then
		-- Multiplicative combination instead of "additive, then one clamp".
		local real = grug_core.set_move_modifier
		local live = {}
		grug_core.set_move_modifier = function(player, name, effect, duration)
			local pname = player:get_player_name()
			live[pname] = live[pname] or {}
			live[pname][name] = (effect and effect.speed) or 0
			local product = 1
			for _, delta in pairs(live[pname]) do
				product = product * (1 + delta)
			end
			real(player, name, {speed = product - 1,
				jump = (effect and effect.jump) or 0}, duration)
		end
	elseif mutation == 2 then
		-- A root as a -1000 % modifier instead of a hard flag.
		grug_core.set_root = function(player, duration)
			grug_core.set_move_modifier(player, "root",
				{speed = -10, jump = -10}, duration)
			return true
		end
	elseif mutation == 4 then
		-- The pre-review behaviour: a second root replaces unconditionally,
		-- so a 1 s root cuts a running 5 s root short.
		local real = grug_core.set_root
		grug_core.set_root = function(player, duration)
			grug_core.clear_root(player)
			return real(player, duration)
		end
	elseif mutation == 3 then
		-- The snapshot restore left in the exclusive hold.
		local real_hold, real_release =
			grug_core.hold_movement, grug_core.release_movement
		local snapshots = {}
		grug_core.hold_movement = function(player, name)
			local pname = player:get_player_name()
			snapshots[pname] = snapshots[pname] or
				player:get_physics_override()
			real_hold(player, name)
		end
		grug_core.release_movement = function(player, name)
			real_release(player, name)
			local snap = snapshots[player:get_player_name()]
			if snap then
				player:set_physics_override(snap)
				snapshots[player:get_player_name()] = nil
			end
		end
	end

	local function advance(seconds)
		clock_us = clock_us + math.floor(seconds * 1e6 + 0.5)
		-- The aggregator's own throttled globalstep is what turns an expiry
		-- into an engine write with nothing else calling in.
		for index = 1, #globalsteps do
			globalsteps[index](seconds)
		end
	end

	local function join(player)
		for index = 1, #joinplayer do joinplayer[index](player) end
	end
	local function leave(player)
		for index = 1, #leaveplayer do leaveplayer[index](player) end
		online[player.name] = nil
	end

	--
	-- 1. Baseline per axis.
	--
	local p = new_player("kat")
	local base = grug_core.get_move_state(p)
	near(base.speed, 1, "baseline speed")
	near(base.jump, 1, "baseline jump")
	want(base.rooted == false and base.held == false and base.modifiers == 0,
		"a fresh player carries no flags and no modifiers")
	want(p.writes == 0, "reading the baseline wrote to the engine " ..
		p.writes .. " time(s)")
	say("baseline", base.speed, base.jump, "writes", p.writes)

	--
	-- 2. Additive overlap under one clamp, per axis.
	--
	grug_core.set_move_modifier(p, "mob_web", {speed = -0.40}, 7)
	grug_core.set_move_modifier(p, "sprint", {speed = 0.25}, 10)
	near(p.physics.speed, 0.85, "web -40% + sprint +25% is additive")
	near(p.physics.jump, 1, "a speed-only pair leaves jump at the baseline")
	say("additive", p.physics.speed, p.physics.jump)

	-- The clamp, both ends, and both axes independently.
	grug_core.set_move_modifier(p, "tar", {speed = -1.20, jump = -0.50}, 5)
	near(p.physics.speed, 0.1, "the low clamp holds at 0.1")
	near(p.physics.jump, 0.5, "jump is clamped on its own axis, not with speed")
	grug_core.clear_move_modifier(p, "tar")
	grug_core.set_move_modifier(p, "haste", {speed = 2.0, jump = 2.0}, 5)
	near(p.physics.speed, 1.5, "the high clamp holds at 1.5")
	near(p.physics.jump, 1.5, "the high clamp holds on jump too")
	grug_core.clear_move_modifier(p, "haste")
	near(p.physics.speed, 0.85, "clearing one name leaves the others intact")
	say("clamp", "low", 0.1, "high", 1.5)

	--
	-- 3. Independent expiry: the 7 s web falls away, the 10 s sprint does not.
	--
	advance(7.5)
	near(p.physics.speed, 1.25,
		"the expired web must not take the sprint with it")
	want(grug_core.get_move_modifier(p, "mob_web") == nil,
		"the web is still registered after its duration")
	local left = grug_core.get_move_modifier(p, "sprint")
	near(left.remaining, 2.5, "the sprint's own remaining duration")
	advance(3)
	near(p.physics.speed, 1, "everything expired returns to the baseline")
	say("expiry", "independent", "ok")

	--
	-- 4. Root is a hard flag, and the sum survives underneath it.
	--
	grug_core.set_move_modifier(p, "sprint", {speed = 0.50}, 10)
	near(p.physics.speed, 1.5, "sprint before the root")
	want(grug_core.set_root(p, 3) == true, "set_root was refused")
	near(p.physics.speed, 0, "a root is speed 0 regardless of modifiers")
	near(p.physics.jump, 0, "a root is jump 0 regardless of modifiers")
	want(grug_core.get_move_state(p).rooted, "the root flag is not reported")
	advance(3.5)
	near(p.physics.speed, 1.5,
		"the sprint must still be running when the root ends")

	-- A SECOND root keeps the LATER expiry. `set_root` carries no name -- it
	-- is one flag, not a set -- so "the longest wins" is the only rule that
	-- can give the guarantee the staged kits.lua chain used to give by hand:
	-- a Hamstring must not lift an ally's Frost Nova root. The sprint is
	-- refreshed to outlive the whole block, so every reading below is the
	-- root's doing and not an expiry elsewhere.
	grug_core.set_move_modifier(p, "sprint", {speed = 0.50}, 30)
	grug_core.set_root(p, 5)
	grug_core.set_root(p, 1) -- shorter, and later: it must NOT truncate
	advance(3)
	near(p.physics.speed, 0,
		"a 1 s root cut a running 5 s root short; a second root must keep " ..
		"the later expiry")
	advance(2.5)
	near(p.physics.speed, 1.5, "the 5 s root ends on its own clock")
	-- ... and a LONGER second root does extend it, which is the same rule.
	grug_core.set_root(p, 1)
	grug_core.set_root(p, 4)
	advance(2)
	near(p.physics.speed, 0, "a longer second root must extend the first")
	grug_core.clear_root(p)
	near(p.physics.speed, 1.5, "clear_root lifts it regardless")
	say("root", "hard_flag", "longest_wins", "ok")

	--
	-- 5. Immunity: roots and negatives discarded, positives kept.
	--
	grug_core.set_move_immunity(p, 8)
	want(grug_core.set_root(p, 5) == false,
		"a root was accepted while immune")
	near(p.physics.speed, 1.5, "immunity keeps the player's own sprint")
	grug_core.set_move_modifier(p, "mob_web", {speed = -0.40}, 4)
	near(p.physics.speed, 1.5, "a slow landed while immune must be inert")
	-- An immunity applied ON TOP of a running root drops it.
	grug_core.clear_move_immunity(p)
	grug_core.set_root(p, 5)
	near(p.physics.speed, 0, "root after the immunity ended")
	grug_core.set_move_immunity(p, 8)
	near(p.physics.speed, 1.5,
		"immunity must drop the running root (sprint +0.5, web inert)")
	-- The inert web still expires on its own clock rather than being frozen.
	advance(4.5)
	want(grug_core.get_move_modifier(p, "mob_web") == nil,
		"an inert slow did not expire on its own clock")
	grug_core.clear_move_immunity(p)
	grug_core.clear_move_modifier(p, "sprint")
	near(p.physics.speed, 1, "back to the baseline after immunity")
	say("immunity", "discards_root_and_negatives", "ok")

	-- Shake Loose dispels penalties that predate its immunity; they must not
	-- resume when the four-second window ends. Positive modifiers survive.
	grug_core.set_move_modifier(p, "old_slow", {speed = -0.40}, 7)
	grug_core.set_move_modifier(p, "sprint", {speed = 0.25}, 10)
	grug_core.set_root(p, 7)
	grug_core.clear_negative_move_modifiers(p)
	want(grug_core.get_move_modifier(p, "old_slow") == nil,
		"Shake Loose dispel retained an old slow")
	want(not grug_core.get_move_state(p).rooted,
		"Shake Loose dispel retained an old root")
	near(p.physics.speed, 1.25, "Shake Loose dispel preserves Sprint")
	grug_core.set_move_immunity(p, 4)
	grug_core.set_move_modifier(p, "new_slow", {speed = -0.40}, 7)
	near(p.physics.speed, 1.25,
		"a new slow stays inert during Shake Loose immunity")
	advance(4.5)
	near(p.physics.speed, 0.85,
		"a new slow follows the existing post-immunity remainder contract")
	grug_core.clear_move_modifier(p, "new_slow")
	grug_core.clear_move_modifier(p, "sprint")
	say("dispel", "old_negative_removed", "positive_preserved", "ok")

	--
	-- 6. The exclusive hold: precedence, counting, exact release, gravity,
	--    and NO snapshot.
	--
	grug_core.set_move_modifier(p, "mob_web", {speed = -0.40}, 20)
	near(p.physics.speed, 0.6, "a web is running when the hold begins")
	grug_core.hold_movement(p, "class_creation")
	near(p.physics.speed, 0, "the hold outranks the sum")
	near(p.physics.jump, 0, "the hold zeroes jump")
	near(p.physics.gravity, 0, "the hold owns gravity while it runs")
	grug_core.set_root(p, 2)
	near(p.physics.speed, 0, "a root under a hold changes nothing")
	grug_core.hold_movement(p, "cutscene")
	grug_core.release_movement(p, "cutscene")
	near(p.physics.speed, 0, "one holder released, the other still holds")
	want(grug_core.is_movement_held(p, "class_creation"),
		"the surviving holder is not reported")

	-- The watchdog: something else writes the field behind our back.
	p:set_physics_override({speed = 0.6, jump = 0.4, gravity = 1.5})
	grug_core.reassert_movement(p)
	near(p.physics.speed, 0, "the hold did not re-assert itself")
	near(p.physics.gravity, 0, "the hold did not re-assert gravity")

	advance(2.5) -- the root under the hold expires unseen
	grug_core.release_movement(p, "class_creation")
	near(p.physics.gravity, 1,
		"releasing the hold must hand gravity back as exactly 1")
	near(p.physics.speed, 0.6,
		"NO SNAPSHOT: the web that was running when the hold began must " ..
		"still be running, at its own value, when it releases")
	near(p.physics.jump, 1, "jump returns to the sum, not to a snapshot")
	say("hold", "exclusive_counted_no_snapshot", "ok")

	--
	-- 7. Join and leave reset everything.
	--
	join(p)
	near(p.physics.speed, 0.6,
		"join does not write (overrides are not persisted) ...")
	want(grug_core.get_move_state(p).modifiers == 0,
		"... but it drops every record")
	grug_core.set_move_modifier(p, "mob_web", {speed = -0.40}, 20)
	leave(p)
	local back = new_player("kat")
	want(grug_core.get_move_state(back).modifiers == 0,
		"a relog inherited the previous session's modifiers")
	say("lifecycle", "join_leave_reset", "ok")

	--
	-- 8. The three migrated callers, through their own shipped code.
	--
	-- 8a. grug_mobs.slow_player: the web merge, on the real verbs.lua.
	grug_mobs = {}
	vector = {distance = function() return 0 end}
	local victim = new_player("victim")
	-- verbs.lua's own top-level needs nothing else from the engine; the
	-- file registers one leaveplayer handler and defines the helpers.
	dofile(repo .. "/mods/ENTITIES/grug_mobs/verbs.lua")
	grug_mobs.slow_player(victim, 3, 0.6) -- the Giant Spider's web (§3.1)
	near(victim.physics.speed, 0.6, "the spider web writes 0.6")
	grug_mobs.slow_player(victim, 1, 0.9) -- weaker AND shorter
	near(victim.physics.speed, 0.6,
		"a weaker web must not lift a stronger one")
	local web = grug_core.get_move_modifier(victim, "mob_web")
	near(web.remaining, 3, "a shorter web must not cut a longer one short")
	grug_core.clear_move_modifier(victim, "mob_web")

	-- 8b/8c. The kits.lua stage tables, through the shipped applier. The
	-- applier is a file-local, so it is reached the way the game reaches it:
	-- the two ability definitions. Rather than booting all of
	-- grug_abilities, the two stage tables are read out of the shipped file
	-- and replayed through the same arithmetic the applier uses -- and the
	-- arithmetic itself is asserted against the file's text, so an edit to
	-- either one breaks this test.
	local source = io.open(repo .. "/mods/PLAYER/grug_abilities/kits.lua")
	want(source, "cannot read kits.lua")
	local text = source:read("*a")
	source:close()
	want(text:find("elapsed = elapsed + stage.time", 1, true) and
		text:find("speed = stage.speed - 1", 1, true) and
		text:find("jump = (stage.jump or 1) - 1", 1, true) and
		text:find("}, elapsed)", 1, true),
		"the kits.lua applier no longer registers cumulative-duration " ..
		"named modifiers with absolute-to-delta conversion")
	-- The stage DURATIONS are talent-driven since WP11 phase 1 (Deep Chill and
	-- Hoarfrost add to them; both are 0 without the talent, so the shipped
	-- 4 s / 3 s are exact for an untalented caster and are what the replay
	-- below uses). The stage VALUES are what this aggregator has to preserve,
	-- so those are pinned and the time expression is not.
	want(text:find("{speed = 0.1, jump = 0.3, time = ", 1, true) and
		text:find("{speed = 0.5, time = ", 1, true),
		"Frost Nova's shipped stage values moved")
	want(text:find("{{speed = 0.5, time = 5}}", 1, true),
		"Hamstring's shipped stage table moved")
	want(text:find('"frost_nova"', 1, true) and text:find('"hamstring"', 1, true),
		"the two abilities no longer name their modifiers")

	local function apply_stages(target, stages, id)
		local elapsed = 0
		for index = 1, #stages do
			local stage = stages[index]
			local name = index == 1 and id or (id .. "_" .. index)
			elapsed = elapsed + stage.time
			grug_core.set_move_modifier(target, name, {
				speed = stage.speed - 1,
				jump = (stage.jump or 1) - 1,
			}, elapsed)
		end
	end

	local pvp = new_player("pvp")
	apply_stages(pvp, {{speed = 0.1, jump = 0.3, time = 4},
		{speed = 0.5, time = 3}}, "frost_nova")
	near(pvp.physics.speed, 0.1, "Frost Nova stage 1 speed (shipped 0.1)")
	near(pvp.physics.jump, 0.3, "Frost Nova stage 1 jump (shipped 0.3)")
	advance(4.5)
	near(pvp.physics.speed, 0.5, "Frost Nova stage 2 speed (shipped 0.5)")
	near(pvp.physics.jump, 1, "Frost Nova stage 2 jump (shipped 1)")
	advance(3)
	near(pvp.physics.speed, 1, "Frost Nova ends at the baseline")

	apply_stages(pvp, {{speed = 0.5, time = 5}}, "hamstring")
	near(pvp.physics.speed, 0.5, "Hamstring 50% slow (shipped)")
	-- Overlap, which is the whole ruling: a Hamstring into a Frost Nova
	-- adds instead of replacing, and cannot lift the root stage.
	apply_stages(pvp, {{speed = 0.1, jump = 0.3, time = 4},
		{speed = 0.5, time = 3}}, "frost_nova")
	near(pvp.physics.speed, 0.1,
		"Hamstring + Frost Nova must stay at the clamp floor, not lift it")
	advance(6)
	near(pvp.physics.speed, 0.5, "Frost Nova's slow stage outlives Hamstring")
	say("callers", "web_frost_nova_hamstring", "ok")

	--
	-- 9. One engine write per change, not one per step.
	--
	local quiet = new_player("quiet")
	grug_core.set_move_modifier(quiet, "sprint", {speed = 0.25}, 2)
	local after_set = quiet.writes
	advance(0.5)
	advance(0.5)
	want(quiet.writes == after_set,
		"the globalstep wrote " .. (quiet.writes - after_set) ..
		" redundant override(s) while nothing changed")
	advance(1.5)
	want(quiet.writes == after_set + 1,
		"the expiry did not reach the engine in exactly one write")
	near(quiet.physics.speed, 1, "expiry restores the baseline")

	-- A HOLD is not an exception to that. The hold resolves gravity to 0 on
	-- every call, so a skip test written against "no gravity in this write"
	-- would never fire and the throttled globalstep would re-send an
	-- unchanged override for the whole of character creation.
	local frozen = new_player("frozen")
	grug_core.hold_movement(frozen, "class_creation")
	local after_hold = frozen.writes
	for _ = 1, 10 do
		advance(0.2)
	end
	want(frozen.writes == after_hold,
		"a running hold wrote " .. (frozen.writes - after_hold) ..
		" unchanged override(s) over ten steps; it must write none")
	grug_core.release_movement(frozen, "class_creation")
	want(frozen.writes == after_hold + 1,
		"the release did not reach the engine in exactly one write")
	near(frozen.physics.gravity, 1, "gravity handed back as exactly 1")

	-- A READ must not mint a record. Without that, a per-step HUD consumer
	-- asking for the move state would make the globalstep write a redundant
	-- {speed = 1, jump = 1} every 0.1 s, for ever, on a player with no
	-- effects at all.
	local watched = new_player("watched")
	for _ = 1, 5 do
		local view = grug_core.get_move_state(watched)
		near(view.speed, 1, "a clean player reads as the baseline")
		want(grug_core.is_movement_held(watched) == false, "not held")
		want(grug_core.get_move_modifier(watched, "sprint") == nil,
			"no modifier")
		advance(0.2)
	end
	want(watched.writes == 0,
		"reading a clean player's state caused " .. watched.writes ..
		" engine write(s); it must cause none")
	say("writes", "one_per_change", after_set + 1, "hold_quiet", "reads_free")

	say("wp11_move_aggregator", "PASS", "mutation", mutation)
	end)

	core, grug_core, grug_mobs, vector =
		saved_core, saved_grug_core, saved_grug_mobs, saved_vector
	if not ok then
		error(failure, 0)
	end
	return table.concat(report)
end
