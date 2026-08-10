-- Focused plain-Lua-5.1 test for WP39's runtime combat-debug seam.

local repo = arg[1] or "."
local command
local leave_callback
local now = 0
local clock_reads = 0
local logs = {}

core = {
	register_chatcommand = function(name, def)
		assert(name == "combatdebug")
		command = def
	end,
	register_on_leaveplayer = function(callback)
		leave_callback = callback
	end,
	get_us_time = function()
		clock_reads = clock_reads + 1
		return now
	end,
	log = function(level, message)
		logs[#logs + 1] = {level = level, message = message}
	end,
}
grug_core = {}

dofile(repo .. "/mods/CORE/grug_core/combat_debug.lua")

assert(command)
assert(command.privs and command.privs.server == true)
assert(command.params == "on|off")
assert(leave_callback)

-- The disabled hot path is one enabled-state lookup: no clock or log work.
assert(grug_core.combat_debug_enabled("admin") == false)
assert(grug_core.combat_debug_due("admin", "swing:ray", 0.25) == false)
assert(clock_reads == 0)
assert(grug_core.combat_debug_log("admin", "input", "hidden") == false)
assert(#logs == 0)

local ok, message = command.func("admin", " invalid ")
assert(ok == false)
assert(message == "Usage: /combatdebug on|off")

ok, message = command.func("admin", " on ")
assert(ok == true)
assert(message:match("enabled"))
assert(grug_core.combat_debug_enabled("admin") == true)

now = 1000000
assert(grug_core.combat_debug_due("admin", "swing:ray", 0.25) == true)
assert(clock_reads == 1)
assert(grug_core.combat_debug_due("admin", "swing:ray", 0.25) == false)
assert(clock_reads == 2)
-- Rate keys are independent for future swing/cast/projectile instrumentation.
assert(grug_core.combat_debug_due("admin", "projectile:step", 0.25) == true)
assert(clock_reads == 3)
now = 1250000
assert(grug_core.combat_debug_due("admin", "swing:ray", 0.25) == true)
assert(clock_reads == 4)
assert(grug_core.combat_debug_due("admin", "swing:outcome", 0) == true)
assert(clock_reads == 4)

assert(grug_core.combat_debug_log("admin", "swing_outcome", "accepted") == true)
assert(#logs == 1)
assert(logs[1].level == "action")
assert(logs[1].message ==
	"[combatdebug][admin][swing_outcome] accepted")

-- Off and leave both clear enabled state and limiter history.
ok = command.func("admin", "off")
assert(ok == true)
assert(grug_core.combat_debug_enabled("admin") == false)
assert(grug_core.combat_debug_due("admin", "swing:ray", 0.25) == false)
assert(clock_reads == 4)

assert(command.func("admin", "on"))
assert(grug_core.combat_debug_due("admin", "swing:ray", 0.25) == true)
assert(clock_reads == 5)
leave_callback({
	get_player_name = function()
		return "admin"
	end,
})
assert(grug_core.combat_debug_enabled("admin") == false)
assert(grug_core.combat_debug_due("admin", "swing:ray", 0.25) == false)
assert(clock_reads == 5)

print("combat_debug_test: ok")
