-- Disposable engine probe (Round 28 Lane B5). Never shipped:
-- tools/r28_b5_prof/run.sh stages it through tools/luanti_headless.sh.
--
-- Registers two sample universal reagents through the real loader (the
-- shipped reagents.json is empty until Lane E1), then, once every mod has
-- loaded, audits the real registry: enchant operations built from
-- data/enchants.json, no metal fittings anywhere, the six furnace-only
-- dishes, the sample reagents' crafts and the cross-profession check.

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

local GLITTER = "grug_professions:probe_glittering_tin"
local CINDER = "grug_materials:probe_cinder_flint"
grug_professions.register_reagents({
	{id = GLITTER, name = "Probe Glittering Tin", tier = 1, method = "grid",
		inputs = {"grug_materials:tin_bar", "grug_materials:quartz"}, output_count = 2},
	{id = CINDER, name = "Probe Cinder Flint", tier = 2, method = "furnace",
		inputs = {"default:flint"}, output_count = 1},
})

-- A data row may never replace an existing item or land in a foreign mod.
local replaced_ok, replaced_err = pcall(grug_professions.register_reagents, {
	{id = "grug_materials:tin_bar", name = "Bad", tier = 1, method = "grid",
		inputs = {"grug_materials:quartz"}, output_count = 1}})
local foreign_ok, foreign_err = pcall(grug_professions.register_reagents, {
	{id = "grug_mapgen:probe_bad", name = "Bad", tier = 1, method = "grid",
		inputs = {"grug_materials:quartz"}, output_count = 1}})

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
	bow = function(t)
		return "grug_artisans:" .. ({"seasoned", "polished", "hardened", "inlaid",
			"lacquered", "heartwood"})[t] .. "_wood"
	end,
	trinket = function(t)
		return "grug_artisans:setting_" .. ({"tin", "iron", "copper_inlaid_steel", "gold",
			"gold_filigreed_embersteel", "gold_filigreed_abyssal_steel"})[t]
	end,
}

local function run()
	local data = grug_professions.ENCHANT_DATA
	-- 1. Every operation: own material + stat loot + family input, 588 in all.
	local operations = grug_jobs.station_operations()
	check(#operations == 588, "588 enchant operations (got " .. #operations .. ")")
	local per_profession, sampled = {}, 0
	for _, op in ipairs(operations) do
		per_profession[op.profession] = (per_profession[op.profession] or 0) + 1
		local inputs = op.flat_inputs
		check(#inputs == 3, op.id .. " has three inputs")
		check(inputs[2] == data[op.tier].stat_loot[op.enchant_stat],
			op.id .. " stat loot " .. tostring(inputs[2]))
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
		per_profession.leatherworker == 60 and per_profession.tailor == 48 and
		per_profession.woodcarver == 108 and per_profession.goldsmith == 84,
		"operations per profession")
	-- Sample costs, written out.
	local sword = grug_jobs.station_operation("enchant:sword:prefix:str:t1")
	check(sword and table.concat(sword.flat_inputs, ",") ==
		"grug_materials:bronze_bar,default:coal_lump,default:tin_lump", "sword T1 Heavy cost")
	local staff = grug_jobs.station_operation("enchant:caster_weapon:suffix:int:t3")
	check(staff and table.concat(staff.flat_inputs, ",") ==
		"grug_artisans:hardened_wood,grug_mobs:slime_gel,grug_materials:silver_lump",
		"staff T3 of the Owl cost")
	local ring = grug_jobs.station_operation("enchant:trinket:suffix:crit_percent:t6")
	check(ring and table.concat(ring.flat_inputs, ",") ==
		"grug_artisans:setting_gold_filigreed_abyssal_steel,grug_mobs:stone_core," ..
		"grug_materials:abyssal_crystal", "trinket T6 of the Eagle cost")

	-- 2. Metal fittings are gone: no item, no recipe, no group member.
	for _, metal in ipairs(METALS) do
		check(not core.registered_items["grug_professions:metal_fittings_" .. metal],
			"no " .. metal .. " fittings item")
	end
	for name, def in pairs(core.registered_items) do
		check(not (def.groups or {}).grug_weaponsmith_fitting, name .. " is no fitting")
	end
	for _, recipe in ipairs(grug_jobs.recipes) do
		check(not recipe.output_name:find("fitting", 1, true), "recipe makes " .. recipe.output_name)
	end

	-- 3. Cooking: six furnace-only dishes, twelve grid dishes.
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
		local profession_grid = 0
		for _, recipe in ipairs(grug_jobs.recipes) do
			if recipe.output_name == dish.item and recipe.station == "grid" then
				profession_grid = profession_grid + 1
			end
		end
		if furnace_only[dish.id] then
			check(normal == 0 and profession_grid == 0, dish.id .. " has no grid route")
			check(cooking == 1, dish.id .. " cooks from its raw assembly (" .. cooking .. ")")
		else
			grid_dishes = grid_dishes + 1
			check(normal + profession_grid >= 1, dish.id .. " keeps its grid route")
		end
	end
	check(grid_dishes == 12, "twelve grid dishes (got " .. grid_dishes .. ")")
	local raw = core.get_craft_result({method = "cooking", width = 1,
		items = {"grug_cooking:raw_stew_pot"}})
	check(raw.item:get_name() == "grug_cooking:hearty_stew", "Raw Hearty Stew bakes into Hearty Stew")

	-- 4. Sample reagents: items, tiers and real crafts.
	check(core.registered_items[GLITTER] and core.registered_items[CINDER], "reagent items")
	check(grug_jobs.ingredient_tier(GLITTER) == 1 and grug_jobs.ingredient_tier(CINDER) == 2,
		"reagent ingredient tiers")
	local made = core.get_craft_result({method = "normal", width = 3,
		items = {"grug_materials:quartz", "", "", "", "grug_materials:tin_bar"}})
	check(made.item:get_name() == GLITTER and made.item:get_count() == 2,
		"grid reagent crafts 2 (got " .. made.item:to_string() .. ")")
	local cooked = core.get_craft_result({method = "cooking", width = 1, items = {"default:flint"}})
	check(cooked.item:get_name() == CINDER, "furnace reagent (got " .. cooked.item:to_string() .. ")")
	check(#grug_professions.REAGENTS == 2, "two sample reagents recorded")
	check(core.get_item_group(GLITTER, "grug_reagent") == 1, "reagent group")
	check(not replaced_ok and tostring(replaced_err):find("already a registered item", 1, true),
		"existing id refused (" .. tostring(replaced_err) .. ")")
	check(not foreign_ok and tostring(foreign_err):find("does not depend on", 1, true),
		"foreign mod refused (" .. tostring(foreign_err) .. ")")
	check(core.registered_items["grug_materials:tin_bar"].description ~= "Bad",
		"tin bar untouched")

	-- 5. Products per profession, and the cross-profession check catching a
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
	}, {{id = "probe:reagent", inputs = {"grug_materials:cut_quartz"}}})
	check(#offences == 2, "foreign inputs found (" .. table.concat(offences, "; ") .. ")")

	log(("RESULT %s (%d checks, %d failures)"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function() core.after(1, run) end)
