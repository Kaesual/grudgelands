local P = grug_professions
local C = "grug_professions:"
local THREAD = C .. "thread"

local tiers = {
	{key = "light", name = "Light", output = "grug_mobs:light_leather",
		inputs = {"mobs:leather", THREAD}, recipe_tier = 1},
	{key = "cured", name = "Cured", output = C .. "cured_leather",
		inputs = {"grug_mobs:light_leather", THREAD}, recipe_tier = 2,
		material = true},
	{key = "heavy", name = "Heavy", output = "grug_mobs:heavy_leather",
		inputs = {C .. "cured_leather", THREAD}, recipe_tier = 3, material = true},
	{key = "scaled", name = "Scaled", output = "grug_mobs:scaled_hide",
		inputs = {"grug_mobs:heavy_leather", THREAD}, recipe_tier = 4,
		material = true},
	{key = "sleek", name = "Sleek", output = C .. "sleek_leather",
		inputs = {"grug_mobs:sleek_pelt", THREAD}, recipe_tier = 5},
	{key = "nightscale", name = "Nightscale", output = C .. "nightscale_leather",
		inputs = {"grug_mobs:scaled_hide", "grug_mobs:sleek_pelt"},
		recipe_tier = 6, material = true},
}

for tier = 1, #tiers do
	local row = tiers[tier]
	if not core.registered_items[row.output] then
		P.register_item(row.output, row.name .. " Leather",
			"mobs_leather.png^[colorize:#" ..
			({"b88b60", "9b7453", "785339", "6b704f", "51443d", "302c42"})[tier] ..
			":75", {grug_profession_material = 1, grug_leather_grade = tier})
	end
	P.register_ingredient(row.output, tier)
	if tier == 1 then
		P.register_ingredient("mobs:leather", tier)
	elseif tier == 5 then
		P.register_ingredient("grug_mobs:sleek_pelt", tier)
	end
	core.register_craft({output = row.output, recipe = {row.inputs}})
end

local bag_outputs = {
	"grug_inventory:bag_leather_pouch", "grug_inventory:bag_leather_satchel",
	"grug_inventory:bag_leather_pack", "grug_inventory:bag_leather_rucksack",
}
local bag_tiers = {1, 2, 4, 5}
for index = 1, #bag_outputs do
	local tier = bag_tiers[index]
	local leather = tiers[tier].output
	P.register_recipe("leatherworker", {tier = tier, station = "tanning_rack",
		inputs = {{leather, leather, leather}, {leather, THREAD, leather},
			{leather, leather, leather}}, output = bag_outputs[index],
		mastery_required = index,
		hint = "Sew at a Tanning Rack"})
end

