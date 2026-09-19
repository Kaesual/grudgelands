-- Independent expected surface for the R9 Goldsmith catalog.

return function(repo)
	local recipes = {}
	local function add(tier, station, output, inputs, material)
		recipes[#recipes + 1] = {tier = tier, station = station, output = output,
			inputs = inputs, material = material}
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
	local cuts = {
		{"quartz", 1, "grug_materials:quartz"},
		{"citrine", 2, "grug_materials:rough_citrine"},
		{"garnet", 2, "grug_materials:rough_garnet"},
		{"jade", 2, "grug_materials:rough_jade"},
		{"diamond", 4, "grug_materials:rough_diamond"},
		{"sapphire", 4, "grug_materials:rough_sapphire"},
		{"ruby", 4, "grug_materials:rough_ruby"},
	}
	for index = 1, #cuts do
		local row = cuts[index]
		add(row[2], "jewellers_bench", "grug_materials:cut_" .. row[1],
			{{row[3]}}, true)
	end
	local settings = {
		{"tin", {"grug_materials:tin_bar", "grug_materials:tin_bar"}},
		{"iron", {"grug_materials:iron_bar", "grug_materials:iron_bar"}},
		{"copper_inlaid_steel",
			{"grug_materials:steel_bar", "grug_materials:copper_bar"}},
		{"gold", {"grug_materials:gold_bar", "grug_materials:gold_bar"}},
		{"gold_filigreed_embersteel",
			{"grug_materials:embersteel_bar", "grug_materials:gold_bar"}},
		{"gold_filigreed_abyssal_steel",
			{"grug_materials:abyssal_steel_bar", "grug_materials:gold_bar"}},
	}
	for tier = 1, 6 do
		add(tier, "jewellers_bench", "grug_artisans:setting_" .. settings[tier][1],
			{settings[tier][2]}, true)
	end
	local trinkets = {
		{"manawell", 1, "citrine", "sapphire"},
		{"last_light", 2, "jade", "sapphire"},
		{"battlebeat", 3, "garnet", "ruby"},
		{"apothecary_loop", 4, "jade", "ruby"},
		{"mercy_seal", 5, "citrine", "sapphire"},
		{"reclaimers_mark", 6, "garnet", "ruby"},
	}
	local function gems(row, tier)
		if tier == 1 then return {"grug_materials:cut_quartz"} end
		if tier <= 3 then return {"grug_materials:cut_" .. row[3]} end
		if tier == 4 then return {"grug_materials:cut_" .. row[4]} end
		if tier == 5 then
			return {"grug_materials:cut_sapphire", "grug_materials:cut_ruby"}
		end
		return {"grug_materials:cut_diamond", "grug_materials:cut_sapphire",
			"grug_materials:cut_ruby"}
	end
	for tier = 1, 6 do
		local setting = "grug_artisans:setting_" .. settings[tier][1]
		for index = 1, #trinkets do
			local row, inputs = trinkets[index], {}
			for count = 1, row[2] do inputs[#inputs + 1] = setting end
			local tier_gems = gems(row, tier)
			for gem_index = 1, #tier_gems do inputs[#inputs + 1] = tier_gems[gem_index] end
			add(tier, "jewellers_bench", "grug_gear:" .. row[1] .. "_t" .. tier,
				grid(inputs))
		end
	end
	local reagents = {false, "grug_mobs:venom_gland", "grug_mobs:slime_gel",
		"grug_mobs:croc_tooth", "grug_gathering:stormkelp",
		"grug_mobs:stone_core"}
	for tier = 2, 6 do
		local setting = "grug_artisans:setting_" .. settings[tier][1]
		add(tier, "jewellers_bench", "grug_artisans:gem_setting_imbue_t" .. tier,
			{{setting, reagents[tier]}})
		if tier >= 3 then
			add(tier, "jewellers_bench", "grug_artisans:gem_setting_temper_t" .. tier,
				{{setting, setting, reagents[tier]}})
			add(tier, "jewellers_bench", "grug_artisans:ornament_components_t" .. tier,
				{{setting, "grug_materials:gold_bar", reagents[tier]}})
		end
	end

	local values = {
		manawell = {0.05, 0.10, 0.15, 0.25, 0.35, 0.50},
		last_light = {3, 4, 5, 6, 8, 10},
		battlebeat = {0.25, 0.50, 0.75, 1.00, 1.50, 2.00},
		apothecary_loop = {2.5, 5, 7.5, 10, 12.5, 15},
		mercy_seal = {1, 2, 3, 4, 5, 6},
		reclaimers_mark = {1, 1.5, 2, 2.5, 3, 4},
	}
	local ilvls = {3, 10, 20, 30, 40, 50}
	local special_contract = {
		manawell = {kind = "mana_regen", stacking = "additive", cap = 1},
		last_light = {kind = "last_light_absorb", stacking = "highest",
			cooldown = 120},
		battlebeat = {kind = "battlebeat_rage", stacking = "additive", cap = 4},
		apothecary_loop = {kind = "potion_amount", stacking = "additive", cap = 30},
		mercy_seal = {kind = "outgoing_healing", stacking = "additive", cap = 12},
		reclaimers_mark = {kind = "reclaimer", stacking = "highest", cooldown = 10,
			rage = {1, 2, 3, 4, 5, 6}},
	}
	local runner = dofile(repo .. "/tools/r9_prof/prof_b_kat_lib.lua")
	return runner(repo, {profession = "goldsmith", recipes = recipes,
		verify = function(context)
			for tier = 1, 6 do
				for index = 1, #trinkets do
					local key = trinkets[index][1]
					local name = "grug_gear:" .. key .. "_t" .. tier
					local definition = context.core.registered_items[name]
					context.check(definition and definition.groups.grug_equip_trinket == 1,
						"missing trinket slot group on " .. name)
					context.check(definition._grug_ilvl == ilvls[tier] and
						definition._grug_trinket_identity == key and
						definition._grug_trinket_value == values[key][tier],
						name .. " authored stats differ")
					local contract = special_contract[key]
					context.check(definition._grug_trinket_kind == contract.kind and
						definition._grug_trinket_stacking == contract.stacking and
						definition._grug_trinket_cap == contract.cap and
						definition._grug_trinket_cooldown == contract.cooldown and
						definition._grug_trinket_rage ==
							(contract.rage and contract.rage[tier] or nil),
						name .. " stacking contract differs")
					context.check(type(definition._grug_trinket_special) == "string" and
						definition._grug_trinket_special ~= "",
						name .. " special text missing")
				end
			end
			context.check(type(context.harvest_callback) == "function",
				"goldsmith bonus harvest hook missing")
			local awarded = {}
			local inventory = {add_item = function(_, _, item)
				awarded[#awarded + 1] = item
				return context.stack("")
			end}
			local player = {goldsmith = true, profession_level = 1,
				is_player = function() return true end,
				get_inventory = function() return inventory end,
				get_pos = function() return {x = 0, y = 0, z = 0} end}
			local event = {resource = {grade = "G1"},
				raw_item = "grug_materials:rough_citrine", digger = player,
				pos = {x = 0, y = -100, z = 0}}
			context.check(grug_artisans.settle_goldsmith_bonus(event, 10) and
				#awarded == 1, "Apprentice 10% bonus boundary failed")
			context.check(not grug_artisans.settle_goldsmith_bonus(event, 11) and
				#awarded == 1, "Apprentice bonus exceeded 10%")
			player.profession_level = 2
			context.check(grug_artisans.settle_goldsmith_bonus(event, 20) and
				#awarded == 2, "Journeyman 20% bonus boundary failed")
			context.check(not grug_artisans.settle_goldsmith_bonus(event, 21) and
				#awarded == 2, "Journeyman bonus exceeded 20%")
			event.resource.grade = nil
			context.check(not grug_artisans.settle_goldsmith_bonus(event, 1),
				"non-regional mineral received a gem bonus")
		end})
end
