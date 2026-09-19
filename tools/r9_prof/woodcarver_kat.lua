-- Independent expected surface for the R9 Woodcarver catalog.

return function(repo)
	local recipes = {}
	local function add(tier, station, output, inputs, material, in_place)
		recipes[#recipes + 1] = {tier = tier, station = station, output = output,
			inputs = inputs, material = material, in_place = in_place}
	end
	local function grid(inputs)
		local result = {}
		for index = 1, #inputs do
			local row = math.floor((index - 1) / 3) + 1
			local column = (index - 1) % 3 + 1
			result[row] = result[row] or {}
			result[row][column] = inputs[index]
		end
		return result
	end
	local tiers = {
		{"seasoned", "bronze", "light"},
		{"polished", "iron", "cured"},
		{"hardened", "steel", "heavy"},
		{"inlaid", "silversteel", "scaled", "ruby", "sapphire"},
		{"lacquered", "embersteel", "sleek", "diamond", "ruby"},
		{"heartwood", "abyssal_steel", "nightscale", "sapphire", "diamond"},
	}
	local families = {{"wand", 1}, {"scepter", 2}, {"orb", 3}, {"staff", 4}}
	local reagents = {false, "grug_mobs:venom_gland", "grug_mobs:slime_gel",
		"grug_mobs:croc_tooth", "grug_gathering:stormkelp",
		"grug_mobs:stone_core"}
	for tier = 1, 6 do
		local row = tiers[tier]
		local wood = "grug_artisans:" .. row[1] .. "_wood"
		local material_inputs = tier == 1 and {{"group:wood", "group:wood"}} or
			{{"grug_artisans:" .. tiers[tier - 1][1] .. "_wood", "group:wood"}}
		add(tier, "carving_bench", wood, material_inputs, true)
		for family_index = 1, #families do
			local family = families[family_index]
			local inputs = {}
			for index = 1, family[2] do inputs[#inputs + 1] = wood end
			inputs[#inputs + 1] = "grug_professions:weapon_grip_" .. row[3]
			if tier >= 2 then
				inputs[#inputs + 1] = "grug_professions:metal_fittings_" .. row[2]
			end
			if tier >= 4 then
				inputs[#inputs + 1] = "grug_materials:cut_" .. row[4]
				if family[1] == "staff" then
					inputs[#inputs + 1] = "grug_materials:cut_" .. row[5]
				end
			end
			local output = "grug_gear:" .. family[1] .. "_" .. row[2]
			add(tier, "carving_bench", output, grid(inputs))
			add(tier, "grid", output, {{output, wood}}, false, true)
		end
		if tier >= 2 then
			add(tier, "carving_bench",
				"grug_artisans:wood_oil_imbue_" .. row[1],
				{{wood, reagents[tier]}})
		end
		if tier >= 3 then
			add(tier, "carving_bench",
				"grug_artisans:wood_oil_temper_" .. row[1],
				{{wood, wood, reagents[tier]}})
		end
	end

	local ilvls = {3, 10, 20, 30, 40, 50}
	local runner = dofile(repo .. "/tools/r9_prof/prof_b_kat_lib.lua")
	return runner(repo, {profession = "woodcarver", recipes = recipes,
		verify = function(context)
			for tier = 1, 6 do
				local damage = math.floor(4 + 0.35 * ilvls[tier] + 0.5)
				for _, family in ipairs({"wand", "scepter", "orb"}) do
					local name = "grug_gear:" .. family .. "_" .. tiers[tier][2]
					local definition = context.core.registered_items[name]
					context.check(definition ~= nil, "missing caster 1H " .. name)
					context.check(definition.groups[family] == 1 and
						definition.groups.grug_caster_weapon == 1 and
						definition.groups.grug_equip_weapon == 1,
						name .. " groups differ")
					context.check(definition._grug_ilvl == ilvls[tier] and
						definition._grug_hands == 1 and
						definition.tool_capabilities.full_punch_interval == 1.0 and
						definition.tool_capabilities.damage_groups.fleshy == damage,
						name .. " curve differs")
				end
				context.check(#grug_gear.catalog[tier].extras == 6,
					"caster 1H families did not join vendor rotation")
			end

			local output = "grug_gear:wand_bronze"
			local base = context.stack(output)
			base:set_wear(12345)
			base:get_meta():set_string("prior_meta", "preserved")
			local old_grid = {base, context.stack("grug_artisans:seasoned_wood")}
			for index = 3, 9 do old_grid[index] = context.stack("") end
			local crafted = context.stack(output)
			for index = 1, #context.craft_callbacks do
				crafted = context.craft_callbacks[index](crafted, nil, old_grid) or crafted
			end
			context.check(crafted:get_meta():get_int("grug_refined") == 1,
				"grid refinement did not mark the weapon")
			context.check(crafted:get_wear() == 12345 and
				crafted:get_meta():get_string("prior_meta") == "preserved",
				"grid refinement discarded stack state")
		end})
end
