-- Disposable engine probe of Round 71 lane SPIKE. Never shipped: run.sh stages
-- it through tools/luanti_headless.sh (PROBE=) and connects one real client.
--
-- A scenario is a coroutine in scenarios.lua, resumed once per server step; it
-- waits with lib.wait / lib.wait_for and every timed stretch is a "phase". The
-- first globalstep (registered here, so before every mod that loads later, and
-- the only one the probe adds) records the interval between two steps; a phase
-- line carries the percentiles of those intervals, which is what a player feels
-- and what [GRUG-PERF] counts, plus the time inside the probe's own job.
local modpath = core.get_modpath(core.get_current_modname())
local lib = dofile(modpath .. "/lib.lua")
local template = dofile(modpath .. "/template.lua")
local writer = dofile(modpath .. "/writer.lua")
local scenarios = dofile(modpath .. "/scenarios.lua")

local name = core.settings:get("r71spike_scenario") or "smoke"
local script = scenarios[name]
assert(script, "unknown scenario " .. name)

local thread = coroutine.create(function()
	lib.wait_character()
	script(lib, template, writer)
	lib.log("shutdown")
	core.request_shutdown("probe done", false, 0)
end)

local failed = false
lib.on_step = function()
	if failed or coroutine.status(thread) == "dead" then return end
	local ok, err = coroutine.resume(thread)
	if not ok then
		failed = true
		lib.log("SCENARIO ERROR " .. debug.traceback(thread, tostring(err)))
		lib.log("shutdown")
		core.request_shutdown("probe failed", false, 0)
	end
end
