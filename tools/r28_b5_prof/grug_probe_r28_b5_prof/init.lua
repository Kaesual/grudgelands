-- Disposable engine probe (Round 28 Lane B5). Never shipped:
-- tools/r28_b5_prof/run.sh stages it through tools/luanti_headless.sh.
--
-- Once every mod has loaded, audits the real registry: enchant operations
-- built from data/enchants.json, no metal fittings anywhere, the six
-- furnace-only dishes and the cross-profession check. (Universal reagents
-- were removed in Round 33.)

local P = "[r28_b5_probe] "
local failures, checks = 0, 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if failures <= 40 then core.log("error", P .. "FAIL " .. msg) end
	end
	return ok
end

local METALS = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}
local OWN = {
	sword = function(t) return "grug_materials:" .. METALS[t] .. "_bar" end,
	metal_armor = function(t) return "grug_materials:" .. METALS[t] .. "_bar" end,
	leather_armor = function(t)
		return ({"grug_mobs:light_leather", "grug_professions:cured_leather",
			"grug_mobs:heavy_leather", "grug_mobs:scaled_hide",
			"grug_professions:sleek_leather", "grug_professions:nightscale_leather"})[t]
	end,
	cloth_armor = function(t)
		return "grug_professions:bolt_" .. ({"patch", "woven", "heavy", "silkweave",
			"silk", "stormweave"})[t]
	end,
	-- Round 33: bows belong to the Leatherworker (the leather grade).
	bow = function(t)
		return ({"grug_mobs:light_leather", "grug_professions:cured_leather",
			"grug_mobs:heavy_leather", "grug_mobs:scaled_hide",
			"grug_professions:sleek_leather", "grug_professions:nightscale_leather"})[t]
	end,
	trinket = function(t)
		return "grug_artisans:setting_" .. ({"tin", "iron", "copper_inlaid_steel", "gold",
			"gold_filigreed_embersteel", "gold_filigreed_abyssal_steel"})[t]
	end,
}

local function run()
	local data = grug_professions.ENCHANT_DATA
	-- 1. Every enchant operation: own material + the channel's loot (Round 33)
	-- + family input, 588 in all (the 36 upgrades are tools/r33_c4's).
	local operations = {}
	for _, op in ipairs(grug_jobs.station_operations()) do
		if op.operation == "enchant" then operations[#operations + 1] = op end
	end
	check(#operations == 588, "588 enchant operations (got " .. #operations .. ")")
	local per_profession, sampled = {}, 0
	for _, op in ipairs(operations) do
		per_profession[op.profession] = (per_profession[op.profession] or 0) + 1
		local inputs = op.flat_inputs
		check(#inputs == 3, op.id .. " has three inputs")
		check(inputs[2] == data[op.tier][op.enchant_channel .. "_loot"][op.enchant_stat],
			op.id .. " loot " .. tostring(inputs[2]))
		check(inputs[3] == data[op.tier].family_input[op.family],
			op.id .. " family input " .. tostring(inputs[3]))
		local own = OWN[op.family]
		if own then
			sampled = sampled + 1
			check(inputs[1] == own(op.tier), op.id .. " own material " .. tostring(inputs[1]))
		end
		for _, item in ipairs(inputs) do
			check(not item:find("fitting", 1, true), op.id .. " uses no fitting")
		end
	end
	local counts = {}
	for profession, count in pairs(per_profession) do counts[#counts + 1] = profession .. "=" .. count end
	table.sort(counts)
	log("operations per profession: " .. table.concat(counts, " ") .. "; own material checked on " ..
		sampled)
	check(per_profession.weaponsmith == 204 and per_profession.armorsmith == 84 and
		per_profession.leatherworker == 120 and per_profession.tailor == 96 and
		per_profession.woodcarver == 48 and per_profession.goldsmith == 36,
		"operations per profession")
	-- Sample costs, written out.
	local sword = grug_jobs.station_operation("enchant:sword:prefix:str:t1")
	check(sword and table.concat(sword.flat_inputs, ",") ==
		"grug_materials:bronze_bar,grug_mobs:boar_tusk,grug_materials:tin_bar", "sword T1 Heavy cost")
	local staff = grug_jobs.station_operation("enchant:caster_weapon:suffix:int:t3")
	check(staff and table.concat(staff.flat_inputs, ",") ==
		"grug_artisans:hardened_wood,grug_mobs:bound_wisp_mote,grug_materials:rough_citrine",
		"staff T3 of the Owl cost")
	local ring = grug_jobs.station_operation("enchant:trinket:suffix:crit_percent:t6")
	check(ring and table.concat(ring.flat_inputs, ",") ==
		"grug_artisans:setting_gold_filigreed_abyssal_steel,grug_mobs:glass_cat_claw," ..
		"grug_materials:rough_diamond", "trinket T6 of the Eagle cost")

	-- 2. Metal fittings are gone: no item, no recipe, no group member.
	for _, metal in ipairs(METALS) do
		check(not core.registered_items["grug_professions:metal_fittings_" .. metal],
			"no " .. metal .. " fittings item")
	end
	for name, def in pairs(core.registered_items) do
		check(not (def.groups or {}).grug_weaponsmith_fitting, name .. " is no fitting")
	end
	for _, recipe in ipairs(grug_jobs.recipes) do
		check(not recipe.output:find("fitting", 1, true), "recipe makes " .. recipe.output)
	end

	-- 3. Cooking: six furnace-only dishes, twelve Cooking recipes (Round 45:
	-- recipe lists, no grid route).
	local furnace_only = {hearty_stew = true, pumpkin_stew = true, foragers_pot = true,
		marsh_roast = true, kelp_wrapped_roast = true, grand_feast = true}
	local grid_dishes = 0
	for _, dish in ipairs(grug_cooking.DISHES) do
		local routes = core.get_all_craft_recipes(dish.item) or {}
		local normal, cooking = 0, 0
		for _, route in ipairs(routes) do
			if route.method == "normal" then normal = normal + 1 end
			if route.method == "cooking" then cooking = cooking + 1 end
		end
		local listed = #grug_jobs.recipes_for_output(dish.item)
		check(normal == 0, dish.id .. " has no grid route")
		if furnace_only[dish.id] then
			check(listed == 0, dish.id .. " has no Cooking recipe")
			check(cooking == 1, dish.id .. " cooks from its raw assembly (" .. cooking .. ")")
		else
			grid_dishes = grid_dishes + 1
			check(listed == 1, dish.id .. " keeps its Cooking recipe")
		end
	end
	check(grid_dishes == 12, "twelve grid dishes (got " .. grid_dishes .. ")")
	local raw = core.get_craft_result({method = "cooking", width = 1,
		items = {"grug_cooking:raw_stew_pot"}})
	check(raw.item:get_name() == "grug_cooking:hearty_stew", "Raw Hearty Stew bakes into Hearty Stew")

	-- 4. Products per profession, and the cross-profession check catching a
	-- foreign input.
	local products = grug_professions.profession_products()
	local by_profession = {}
	for item, profession in pairs(products) do
		by_profession[profession] = by_profession[profession] or {}
		table.insert(by_profession[profession], item)
	end
	local professions = {}
	for profession in pairs(by_profession) do professions[#professions + 1] = profession end
	table.sort(professions)
	for _, profession in ipairs(professions) do
		table.sort(by_profession[profession])
		log(("products %s (%d): %s"):format(profession, #by_profession[profession],
			table.concat(by_profession[profession], " ")))
	end
	check(products["grug_artisans:setting_tin"] == "goldsmith", "settings are Goldsmith products")
	local offences = grug_professions.enchant_data.foreign_inputs(products, {
		{profession = "weaponsmith", label = "probe", inputs = {"grug_artisans:setting_tin"}},
		{profession = "goldsmith", label = "own", inputs = {"grug_artisans:setting_tin"}},
	})
	check(#offences == 1, "foreign input found (" .. table.concat(offences, "; ") .. ")")

	log(("RESULT %s (%d checks, %d failures)"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function() core.after(1, run) end)
