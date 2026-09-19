-- Independent expected surface for the R9 Leatherworker catalog.

return function(repo)
	local recipes = {}
	local function add(tier, output, inputs)
		recipes[#recipes + 1] = {tier = tier, station = "tanning_rack",
			output = output, inputs = inputs}
	end
	local C = "grug_professions:"
	local thread = C .. "thread"
	local grades = {
		{"light", "grug_mobs:light_leather", {"mobs:leather", thread}},
		{"cured", C .. "cured_leather",
			{"grug_mobs:light_leather", thread}, 1},
		{"heavy", "grug_mobs:heavy_leather",
			{C .. "cured_leather", thread}, 2},
		{"scaled", "grug_mobs:scaled_hide",
			{"grug_mobs:heavy_leather", thread}, 3},
		{"sleek", C .. "sleek_leather", {"grug_mobs:sleek_pelt", thread}},
		{"nightscale", C .. "nightscale_leather",
			{"grug_mobs:scaled_hide", "grug_mobs:sleek_pelt"}, 5},
	}
	for tier = 1, 6 do
		local key, leather, inputs = grades[tier][1], grades[tier][2], grades[tier][3]
		add(grades[tier][4] or tier, leather, inputs)
		local grip = C .. "weapon_grip_" .. key
		add(tier, grip, {leather, leather})
		if tier >= 2 then
			add(tier, C .. "leather_armor_imbue_" .. key, {leather, grip})
		end
		if tier >= 3 then
			add(tier, C .. "leather_armor_temper_" .. key,
				{leather, grip, "default:coal_lump"})
		end
	end
	local runner = dofile(repo .. "/tools/r9_prof/catalog_kat_lib.lua")
	return runner(repo, {profession = "leatherworker", recipes = recipes})
end
