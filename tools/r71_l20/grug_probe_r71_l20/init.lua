-- Disposable engine probe of Round 71 lane L20. Never shipped: run.sh stages it
-- through tools/luanti_headless.sh (PROBE=) and connects one real client. The
-- scenario is a coroutine resumed once per server step.
local modpath = core.get_modpath(core.get_current_modname())
local lib = dofile(modpath .. "/lib.lua")
-- run.sh with SCENARIO=range stages a copy holding a `scenario_name` file: lane RANGE's.
local chosen = io.open(modpath .. "/scenario_name")
local name = chosen and chosen:read("*l") or "scenario"
if chosen then chosen:close() end
local scenario = dofile(modpath .. "/" .. name .. ".lua")

local thread = coroutine.create(function()
	local player = lib.wait_character()
	scenario(lib, player)
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
