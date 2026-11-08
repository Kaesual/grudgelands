-- Disposable engine probe of Round 71 lane GUARD. Never shipped: run.sh stages it
-- through tools/luanti_headless.sh (PROBE=) and connects one real client. A
-- scenario is a coroutine resumed once per server step.
local modpath = core.get_modpath(core.get_current_modname())
local lib = dofile(modpath .. "/lib.lua")
local scenarios = dofile(modpath .. "/scenarios.lua")

local script = scenarios[core.settings:get("r71guard_scenario") or "rules"]
assert(script, "unknown scenario")

-- The same code path with the field empty: the proof's run without the gate.
if core.settings:get("r71guard_gate") == "off" then
	grug_mobs.set_spawn_free_field(math.huge, -math.huge, math.huge, -math.huge)
	lib.log("gate off")
end

local thread = coroutine.create(function()
	local player = lib.wait_character()
	script(lib, player)
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
