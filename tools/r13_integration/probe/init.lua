-- Only preload scheduling is disabled; production catalog auditing stays active.
grug_core.request_starts_preload = function() end
local path = core.get_modpath(core.get_current_modname())
core.register_on_mods_loaded(function()
	core.after(0.1, function()
		local ok, reason = pcall(function() dofile(path .. "/scenarios.lua")() end)
		if not ok then core.log("error", "R13 INTEGRATION FAIL " .. tostring(reason)) end
		core.request_shutdown("R13 combined integration complete", false, 0)
	end)
end)
