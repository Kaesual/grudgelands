local P = grug_professions
local C = "grug_professions:"
local THREAD = C .. "thread"

-- The six leather grades. Each grade's recipe (the grade below or a pelt,
-- and Thread) is Basic (grug_jobs/basic_recipes.lua).
local tiers = {
	{key = "light", name = "Light", output = "grug_mobs:light_leather"},
	{key = "cured", name = "Cured", output = C .. "cured_leather"},
	{key = "heavy", name = "Heavy", output = "grug_mobs:heavy_leather"},
	{key = "scaled", name = "Scaled", output = "grug_mobs:scaled_hide"},
	{key = "sleek", name = "Sleek", output = C .. "sleek_leather"},
	{key = "nightscale", name = "Nightscale", output = C .. "nightscale_leather"},
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
end

local bag_outputs = {
	"grug_inventory:bag_leather_pouch", "grug_inventory:bag_leather_satchel",
	"grug_inventory:bag_leather_pack", "grug_inventory:bag_leather_rucksack",
}
local bag_tiers = {1, 2, 4, 5}
-- Eight leathers of the tier and a Thread. Bags give profession XP and need
-- only the profession tier (Round 45 rulings 7 and 8).
for index = 1, #bag_outputs do
	local tier = bag_tiers[index]
	P.register_recipe("leatherworker", {tier = tier, output = bag_outputs[index],
		ingredients = {{item = tiers[tier].output, n = 8}, {item = THREAD, n = 1}},
		time = grug_jobs.DURATIONS.bag})
end

