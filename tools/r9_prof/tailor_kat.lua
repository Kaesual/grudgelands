-- Independent expected surface for the R9 Tailor catalog.

return function(repo)
	local recipes = {}
	local function add(tier, station, output, inputs)
		recipes[#recipes + 1] = {tier = tier, station = station,
			output = output, inputs = inputs}
	end
	local C = "grug_professions:"
	local thread = C .. "thread"
	local bolts = {
		{"patch", {"grug_mobs:linen_scrap", "grug_mobs:linen_scrap", thread}},
		{"woven", {"grug_mobs:linen_cloth", "grug_mobs:linen_cloth", thread}},
		{"heavy", {"grug_mobs:heavy_cloth", "grug_mobs:heavy_cloth", thread}},
		{"silkweave", {C .. "bolt_heavy", "grug_mobs:spider_silk", thread}},
		{"silk", {"group:grug_tailor_pure_silk",
			"group:grug_tailor_pure_silk", thread}},
		{"stormweave", {"grug_mobs:spider_silk",
			"group:grug_tailor_storm_fiber", thread}},
	}
	for tier = 1, 6 do
		local key, inputs = bolts[tier][1], bolts[tier][2]
		local bolt = C .. "bolt_" .. key
		add(tier, "tailor_bench", bolt, inputs)
		for _, slot in ipairs({"head", "chest", "legs", "feet"}) do
			local gear = "grug_gear:" .. slot .. "_cloth_" .. key
			add(tier, "grid", gear, {gear, bolt})
		end
		if tier >= 2 then
			add(tier, "tailor_bench", C .. "embroidery_imbue_" .. key,
				{bolt, C .. "parchment"})
		end
		if tier >= 3 then
			add(tier, "tailor_bench", C .. "embroidery_temper_" .. key,
				{bolt, C .. "parchment", thread})
		end
	end
	add(2, "tailor_bench", C .. "woven_bolt_bundle",
		{C .. "bolt_woven", C .. "bolt_woven", C .. "bolt_woven",
			C .. "bolt_woven"})
	add(3, "tailor_bench", C .. "heavy_bolt_bundle",
		{C .. "bolt_heavy", C .. "bolt_heavy", C .. "bolt_heavy",
			C .. "bolt_heavy", C .. "bolt_heavy"})
	add(1, "tailor_bench", "grug_inventory:bag_small",
		{C .. "bolt_patch", C .. "bolt_patch", C .. "bolt_patch",
			C .. "bolt_patch", "grug_mobs:light_leather", C .. "bolt_patch",
			C .. "bolt_patch", "grug_mobs:light_leather"})
	add(2, "tailor_bench", "grug_inventory:bag_medium",
		{C .. "woven_bolt_bundle", C .. "woven_bolt_bundle",
			C .. "cured_leather", C .. "cured_leather"})
	add(4, "tailor_bench", "grug_inventory:bag_large",
		{C .. "heavy_bolt_bundle", C .. "heavy_bolt_bundle",
			"grug_mobs:spider_silk", "grug_mobs:spider_silk",
			"grug_mobs:heavy_leather", "grug_mobs:spider_silk",
			"grug_mobs:heavy_leather", "grug_mobs:spider_silk"})
	local runner = dofile(repo .. "/tools/r9_prof/catalog_kat_lib.lua")
	return runner(repo, {profession = "tailor", recipes = recipes,
		refinement = {output = "grug_gear:head_cloth_patch", word = "Ornate"}})
end
