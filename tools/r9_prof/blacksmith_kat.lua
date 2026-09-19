-- Independent expected surface for the R9 Blacksmith catalog.

return function(repo)
	local recipes = {}
	local function add(tier, station, output, inputs)
		recipes[#recipes + 1] = {tier = tier, station = station,
			output = output, inputs = inputs}
	end
	local metals = {
		{"bronze", "grug_materials:bronze_bar"},
		{"iron", "grug_materials:iron_bar"},
		{"steel", "grug_materials:steel_bar"},
		{"silversteel", "grug_materials:silversteel_bar"},
		{"embersteel", "grug_materials:embersteel_bar"},
		{"abyssal_steel", "grug_materials:abyssal_steel_bar"},
	}
	local reagents = {false, "grug_mobs:venom_gland", "grug_mobs:slime_gel",
		"grug_mobs:croc_tooth", "grug_gathering:stormkelp",
		"grug_mobs:stone_core"}
	for tier = 1, 6 do
		local key, bar = metals[tier][1], metals[tier][2]
		local fitting = "grug_professions:metal_fittings_" .. key
		add(tier, "forge", fitting, {bar, bar})
		for _, family in ipairs({"sword", "dagger", "greataxe"}) do
			local gear = "grug_gear:" .. family .. "_" .. key
			add(tier, "grid", gear, {gear, fitting})
		end
		for _, slot in ipairs({"head", "chest", "legs", "feet"}) do
			local gear = "grug_gear:" .. slot .. "_metal_" .. key
			add(tier, "grid", gear, {gear, fitting})
		end
		if tier >= 2 then
			add(tier, "forge", "grug_professions:whetstone_imbue_" .. key,
				{fitting, reagents[tier], "grug_professions:whetstone_blank"})
		end
		if tier >= 3 then
			add(tier, "forge", "grug_professions:whetstone_temper_" .. key,
				{fitting, reagents[tier], "grug_professions:whetstone_blank",
					"grug_professions:whetstone_blank"})
			add(tier, "forge", "grug_professions:armor_polish_imbue_" .. key,
				{fitting, reagents[tier], "default:clay_lump"})
		end
		if tier >= 5 then
			add(tier, "forge", "grug_professions:armor_polish_temper_" .. key,
				{fitting, reagents[tier], "grug_professions:flux"})
		end
	end
	local runner = dofile(repo .. "/tools/r9_prof/catalog_kat_lib.lua")
	return runner(repo, {profession = "blacksmith", recipes = recipes,
		refinement = {output = "grug_gear:sword_bronze", word = "Honed"}})
end
