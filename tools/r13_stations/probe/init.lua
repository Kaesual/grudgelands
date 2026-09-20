local storage = core.get_mod_storage()
local path = core.get_modpath(core.get_current_modname())
grug_core.request_starts_preload = function() end
core.register_craftitem("grug_r13_stations_probe:input", {description = "Fixture input"})
core.register_craftitem("grug_r13_stations_probe:output", {description = "Fixture output"})
core.register_craftitem("grug_r13_stations_probe:fuel", {description = "Fixture fuel"})
core.register_craftitem("grug_r13_stations_probe:jar", {description = "Fixture jar"})
grug_jobs.register_ingredient_tier("grug_r13_stations_probe:input", 1)
grug_jobs.register_recipe({profession = "weaponsmith", tier = 1, station = "forge",
	inputs = {{"grug_r13_stations_probe:input"}}, output = "grug_r13_stations_probe:output 4",
	hint = "Native transaction fixture"})
core.register_craft({type = "fuel", recipe = "grug_r13_stations_probe:fuel", burntime = 10,
	replacements = {{"grug_r13_stations_probe:fuel", "grug_r13_stations_probe:jar"}}})
-- The fixture uses registered game cooking recipes to avoid changing the
-- complete runtime catalog audited by the ordinary production startup.
core.register_on_mods_loaded(function()
	core.after(0.1, function()
		local ok, reason = pcall(function() dofile(path .. "/scenarios.lua")(storage) end)
		if not ok then core.log("error", "R13 STATIONS FAIL " .. tostring(reason)) end
		core.request_shutdown("R13 station probe complete", false, 0)
	end)
end)
