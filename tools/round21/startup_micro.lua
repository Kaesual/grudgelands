-- Compact registration regressions; the real-engine probe remains authoritative.
local repo = assert(arg[1])
dofile(repo .. "/tools/r21_aquatic/fish_spawn_kat.lua")
core.get_current_modname = function() return "grug_jobs" end
core.get_modpath = function() return repo .. "/mods/PLAYER/grug_jobs" end
local policy = dofile(repo .. "/mods/PLAYER/grug_jobs/basics_presentation.lua")
local records = {}
for _, row in ipairs(dofile(repo .. "/mods/PLAYER/grug_jobs/basics_routes.lua")) do
	local items = row.inputs
	if row.output == "grug_gear:arrow" then
		-- Exact items array observed from the native engine: no trailing empties.
		items = {"", "", "grug_materials:bronze_bar", "", "group:stick", "", "group:stick"}
	end
	records[#records + 1] = {station = row.station, output_name = row.output,
		method = row.method, width = row.width, shapeless = row.shapeless, display_items = items}
end
local found = false
for _, row in ipairs(policy.bind(records)) do
	if row.output_name == "grug_gear:arrow" then
		assert(row.basics_presentation.starter == true and row.width == 3)
		found = true
	end
end
assert(found, "arrow Basics route missing")
print("r21_startup_micro\tPASS fish-disposition+native-arrow-route")
