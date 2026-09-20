local root = arg[1] or "."
core = {
	get_modpath = function() return root .. "/mods/PLAYER/grug_jobs" end,
	get_current_modname = function() return "grug_jobs" end,
}

local function load_policy()
	return assert(loadfile(root ..
		"/mods/PLAYER/grug_jobs/basics_presentation.lua"))()
end

local function records_from(policy)
	local records = {}
	for _, declaration in pairs(policy.declarations) do
		records[#records + 1] = {
			station = declaration.station, output_name = declaration.output,
			method = declaration.method, width = declaration.width,
			shapeless = declaration.shapeless,
			display_items = declaration.inputs,
		}
	end
	return records
end

local policy = load_policy()
local records = records_from(policy)
local basics = policy.bind(records)
assert(#records == 830 and #basics == 596)
local starter, bronze_armor, dual = 0, 0, 0
for index = 1, #basics do
	local recipe, declaration = basics[index], basics[index].basics_presentation
	if declaration.starter then starter = starter + 1 end
	if recipe.output_name:match("^grug_gear:[a-z]+_metal_bronze$") then
		assert(declaration.starter); bronze_armor = bronze_armor + 1
	end
	if recipe.station == "dual_furnace" then
		assert(declaration.main_material == recipe.display_items[1])
		dual = dual + 1
	end
	assert(recipe.output_name ~= "grug_cooking:bread")
	assert(recipe.output_name ~= "mobs:meat")
	assert(recipe.output_name ~= "grug_fishing:cooked_fish")
end
assert(starter == 63 and bronze_armor == 4 and dual == 5)
local cooking = policy.records_for_profession("cooking")
assert(#cooking == 3, "Cooking refinement ownership differs")

local stale = load_policy()
local stale_records = records_from(stale)
table.remove(stale_records)
assert(not pcall(stale.bind, stale_records), "stale declaration passed")

local missing = load_policy()
local missing_records = records_from(missing)
missing_records[#missing_records + 1] = {station = "grid", output_name = "test:new",
	method = "normal", width = 1, shapeless = false, display_items = {"test:ore"}}
assert(not pcall(missing.bind, missing_records), "missing declaration passed")

local duplicate = load_policy()
local duplicate_records = records_from(duplicate)
duplicate_records[#duplicate_records + 1] = duplicate_records[1]
assert(not pcall(duplicate.bind, duplicate_records), "duplicate route passed")

print("R12 RECIPES presentation PASS routes=830 general=596 profession=234 " ..
	"starter=63 dual=5 bronze_armor=4 audit=missing+stale+duplicate")
