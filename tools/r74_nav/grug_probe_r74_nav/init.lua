-- Disposable engine probe of Round 74 lane NAV. Never shipped: run.sh stages it through
-- tools/luanti_headless.sh (PROBE=) with plan.lua (tools/r74_nav/plan.py) and config.lua
-- written beside it, and connects one real client. The scenario is a coroutine resumed
-- once per server step.
local modpath = core.get_modpath(core.get_current_modname())
local lib = dofile(modpath .. "/lib.lua")
local scenario = dofile(modpath .. "/scenario.lua")
local config = dofile(modpath .. "/config.lua")
local plan = dofile(modpath .. "/plan.lua")

local thread = coroutine.create(function()
	local player = lib.wait_character()
	scenario(lib, player, config, plan[config.expedition])
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
