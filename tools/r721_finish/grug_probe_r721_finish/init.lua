-- Disposable engine probe of Round 72.1 lane FINISH, never shipped: staged by
-- tools/luanti_headless.sh (PROBE=), no client. Two stand-in owners (tables with a
-- name, their level answered here): one opens The Stilled Seam, its boss stubbed
-- dead, finishes it and the probe logs the countdown's minute to its end; the other
-- opens one and cancels it at once, which ends it and marks the canceller.
-- Logs "[r721finish] ..." lines, then shuts the server down.
local E = grug_expeditions
local function log(fmt, ...) core.log("action", "[r721finish] " .. fmt:format(...)) end
local function check(ok, label) log("%s %s", ok and "PASS" or "FAIL", label) end

local function stand_in(name)
	return {probe = true, get_player_name = function() return name end,
		get_hp = function() return 20 end}
end
local level_of = grug_xp.get_level
grug_xp.get_level = function(player)
	if type(player) == "table" and player.probe then return 25 end
	return level_of(player)
end
-- The stub-dead boss: the finisher's run alone.
local rewards_open = E.rewards_open
E.rewards_open = function(run)
	if run.creator == "probe_finisher" then return true end
	return rewards_open(run)
end
local ended = {}
E.register_on_end(function(run, reason) ended[run] = reason end)

local finisher, canceller = stand_in("probe_finisher"), stand_in("probe_canceller")
local t0
local function wait_ready(run, next_step)
	if run.state == "ready" then return next_step() end
	if run.state == "ended" then
		check(false, "the run was prepared")
		return core.request_shutdown("probe failed", false, 0)
	end
	core.after(0.5, function() wait_ready(run, next_step) end)
end

local function cancel_step()
	local run = assert(E.create(canceller, "stilled_seam", 5))
	wait_ready(run, function()
		local ok = E.can_cancel(canceller)
		check(ok and not E.can_finish(canceller), "the unfinished run offers Cancel alone")
		check(E.cancel(canceller) and run.state == "ended" and ended[run] == "cancelled",
			"Cancel with nobody inside ends it at once")
		local left = E.deserter_left("probe_canceller")
		local refused, why = E.can_create(canceller, "stilled_seam", 5)
		log("mark left %s, create refused %s: %s", tostring(left), tostring(not refused), tostring(why))
		check(left == 300 and not refused, "the canceller is marked")
		local icon = grug_core.status_icons.texture("deserter_mark")
		log("icon %s", icon)
		log("shutdown")
		core.request_shutdown("probe done", false, 0)
	end)
end

local function countdown(run, last)
	if run.state == "ended" then
		log("ended %s after %.1f s", tostring(ended[run]), (core.get_us_time() - t0) / 1e6)
		check(ended[run] == "finished" and E.run_of(finisher) == nil, "finished: ended and freed")
		return cancel_step()
	end
	local left = E.closing_left(run)
	if left ~= last then log("closing_left %d at %.1f s", left, (core.get_us_time() - t0) / 1e6) end
	core.after(0.25, function() countdown(run, left) end)
end

core.after(2, function()
	local run = assert(E.create(finisher, "stilled_seam", 5))
	log("created slot %d level %d", run.slot, run.level)
	wait_ready(run, function()
		check(E.can_finish(finisher) and not E.can_cancel(finisher), "the boss dead: Finish alone")
		t0 = core.get_us_time()
		check(E.finish(finisher) and run.closing and E.closing_left(run) == 60, "Finish: a minute")
		log("state %s, text %s", run.state, E.state_text(run))
		countdown(run, nil)
	end)
end)
