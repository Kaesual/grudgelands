-- Round 46 lane CK portable test (LuaJIT; round46-plan.md §4.7, ruling 13).
-- Loads the REAL files under small stubs and checks:
--   A. food roles (grug_food/init.lua): every tier has the plain role, with
--      HP regeneration only and no secondary, weaker than the Hearty, Caster
--      and Hunter dishes of its tier (less of every term, less of at least
--      one); a plain dish registers and its tooltip reads its regeneration;
--   B. the cooking catalog (grug_cooking/init.lua): one plain dish per tier
--      with a Cooking recipe of 1 s, from T2 with the band's own fish; the
--      staple group holds potato, corn, carrot and cassava; the T4/T5 fish
--      dishes take any raw fish; each band fish has its band's ingredient
--      tier;
--   C. locality (tools/r46_ck/locality.lua over the shipped world data):
--      every start zone cooks at least two T1 recipes, every 11-20 zone the
--      T1 and the T2 plain dish, every zone the plain dish of its level band,
--      and Frostbarrow (the Dwarf's 21-30 zone) a T3 recipe;
--   D. the craft count (the real grug_jobs registry.lua and jobs.lua through
--      jobs_harness.lua): ×N (crafts_from_counts) equals what
--      take_ingredients can take for every Cooking recipe on several
--      inventories, an item in two groups included (carrot and cassava are a
--      root and a staple); the review's worst case (128 full slots) reads the
--      job ceiling + 1. Timing: bench_count.lua.
-- The fix round (the user, 2026-10-12) also checks: Cooked Meat, the Meat
-- Block, Cooked Fish and Bread are plain; the four higher-tier swaps.
-- The before/after lists per race: luajit tools/r46_ck/cook_local.lua.
--
-- Usage (repo root): luajit tools/r46_ck/portable_test.lua [REPO]

local ROOT = arg and arg[1] or "."
local checks, failures = 0, 0

local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end

local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", want " ..
		tostring(expected) .. ")")
end

local ROLES = {"hearty", "caster", "hunter"}

------------------------------------------------------------------------------
-- A. Food roles.
------------------------------------------------------------------------------
do
	local registered = setmetatable({}, {__index = function(_, name)
		return {description = name, groups = {}}
	end})
	core = {registered_items = registered,
		override_item = function(name, def)
			local merged = {}
			for key, value in pairs(registered[name]) do merged[key] = value end
			for key, value in pairs(def) do merged[key] = value end
			rawset(registered, name, merged)
		end,
		register_on_leaveplayer = function() end}
	grug_gathering = {p9g_sources = function() return {} end}
	dofile(ROOT .. "/mods/ITEMS/grug_food/init.lua")
	for tier = 1, 6 do
		local plain = grug_food.effect_for(tier, "dish", "plain")
		check(plain ~= nil, ("A T%d has the plain role"):format(tier))
		if plain then
			check(plain.regen.hp and plain.regen.mana == nil and next(plain.modifiers) == nil,
				("A T%d plain: HP regeneration, no mana, no secondary"):format(tier))
			for _, role in ipairs(ROLES) do
				local other = grug_food.effect_for(tier, "dish", role)
				local weaker = plain.regen.hp < other.regen.hp or other.regen.mana ~= nil or
					next(other.modifiers) ~= nil
				check(plain.regen.hp <= other.regen.hp and weaker,
					("A T%d plain (%d%%) is weaker than %s (%d%%)"):format(tier,
						plain.regen.hp, role, other.regen.hp))
			end
		end
	end
	check(grug_food.register_item("t:plain", 1, "dish", "plain"), "A a plain dish registers")
	local text = registered["t:plain"].description
	check(text:find("Restores 5 HP instantly.", 1, true) ~= nil and
		text:find("Regenerates 3% of maximum HP every 5 s", 1, true) ~= nil and
		text:find("Grants", 1, true) == nil,
		"A the plain T1 tooltip: tier HP, 3% regeneration, no bonus")
	eq(registered["t:plain"].groups.grug_food_role_plain, 1, "A the plain role group")
	-- The furnace conversions are plain dishes (the user, 2026-10-12).
	for _, name in ipairs({"mobs:meat", "mobs:meatblock", "grug_fishing:cooked_fish"}) do
		local def = rawget(registered, name)
		check(def and def.groups.grug_food_role_plain == 1 and
			def.description:find("Regenerates 3% of maximum HP", 1, true) ~= nil,
			"A " .. name .. " is a plain T1 dish (3 %)")
	end
end

------------------------------------------------------------------------------
-- B. The cooking catalog.
------------------------------------------------------------------------------
local BAND_FISH = {[2] = "grug_fishing:silver_trout", [3] = "grug_fishing:mire_carp",
	[4] = "grug_fishing:frostfin", [5] = "grug_fishing:ember_eel",
	[6] = "grug_fishing:storm_tuna"}
do
	local routes, tiers, groups = {}, {}, {}
	core = {registered_items = setmetatable({}, {__index = function(_, name)
			return {description = name, groups = {}}
		end}),
		register_craftitem = function() end,
		override_item = function(name, def)
			for group in pairs(def.groups or {}) do
				groups[group] = groups[group] or {}
				groups[group][name] = true
			end
		end,
		register_craft = function() end,
		register_on_joinplayer = function() end}
	grug_classes = {register_on_arrival = function() end}
	local food_roles = {}
	grug_food = {register_item = function(name, _, _, role)
		food_roles[name] = role
		return true
	end}
	grug_jobs = {DURATIONS = {food = 1},
		register_ingredient_tier = function(item, tier) tiers[item] = tier end,
		register_recipe = function(def) routes[def.output] = def end,
		ingredient_list = function(tokens) return tokens end}
	dofile(ROOT .. "/mods/ITEMS/grug_cooking/init.lua")
	local plain = {}
	for _, dish in ipairs(grug_cooking.DISHES) do
		if dish.role == "plain" then
			check(plain[dish.tier] == nil, "B one plain dish at T" .. dish.tier)
			plain[dish.tier] = dish
		end
	end
	for tier = 1, 6 do
		local dish = plain[tier]
		check(dish ~= nil, "B T" .. tier .. " has a plain dish")
		if dish then
			local route = routes[dish.item]
			check(route and route.area == "cooking" and route.tier == tier and route.time == 1,
				dish.id .. " is a T" .. tier .. " Cooking recipe of 1 s")
			check(#dish.inputs <= 2, dish.id .. " takes at most two ingredients")
			if tier >= 2 then
				local has_fish = false
				for _, input in ipairs(dish.inputs) do
					has_fish = has_fish or input == BAND_FISH[tier]
				end
				check(has_fish, dish.id .. " uses the band's fish")
			end
		end
	end
	for tier, fish in pairs(BAND_FISH) do
		eq(tiers[fish], tier, "B " .. fish .. " ingredient tier")
	end
	for _, item in ipairs({"grug_gathering:potato", "grug_gathering:corn",
			"grug_cooking:carrot", "grug_cooking:cassava"}) do
		check((groups.grug_cooking_staple or {})[item], "B the staple group holds " .. item)
	end
	local by_id = {}
	for _, dish in ipairs(grug_cooking.DISHES) do by_id[dish.id] = dish end
	for _, id in ipairs({"marshbloom_chowder", "stormkelp_broth", "salt_crusted_fish"}) do
		local any = false
		for _, input in ipairs(by_id[id].inputs) do
			any = any or input == "group:food_fish_raw"
			check(input ~= "grug_mobs:raw_fish", id .. " no longer needs Raw Fish alone")
		end
		check(any, id .. " takes any raw fish")
	end
	eq(tiers["group:food_fish_raw"], 1, "B the raw fish group counts as T1")
	eq(food_roles["grug_cooking:bread"], "plain", "B Bread is a plain dish")
	-- The four higher-tier swaps (the user, 2026-10-12).
	local function has(inputs, token)
		for _, input in ipairs(inputs) do if input == token then return true end end
		return false
	end
	local raw_pot
	for _, row in ipairs(grug_cooking.RAW_ASSEMBLIES) do
		if row.id == "raw_foragers_pot" then raw_pot = row end
	end
	check(has(by_id.mushroom_skewer.inputs, "group:grug_cooking_fruit"),
		"B Mushroom Skewer takes any fruit")
	check(has(raw_pot.inputs, "grug_cooking:pumpkin") and
		not has(raw_pot.inputs, "group:grug_cooking_staple"), "B Forager's Pot takes Pumpkin")
	for _, id in ipairs({"salt_crusted_fish", "stormkelp_broth"}) do
		check(has(by_id[id].inputs, "grug_cooking:salt_crust") and
			not has(by_id[id].inputs, "grug_gathering:rock_salt"), "B " .. id .. " takes Salt Crust")
	end
	check(has(by_id.cocoa_rubbed_game.inputs, "grug_gathering:rock_salt") and
		not has(by_id.cocoa_rubbed_game.inputs, "group:grug_cooking_early_spice"),
		"B Cocoa-Rubbed Game takes Rock Salt")
end

------------------------------------------------------------------------------
-- C. Locality over the shipped world data.
------------------------------------------------------------------------------
do
	local locality = dofile(ROOT .. "/tools/r46_ck/locality.lua")
	local world = locality.load(ROOT)
	local frostbarrow
	for _, zone in ipairs(world.zones) do
		local cookable, plain_tiers, t1 = locality.cookable(world, zone.id), {}, 0
		for _, row in ipairs(cookable) do
			if row.recipe.role == "plain" then plain_tiers[row.recipe.tier] = true end
			if row.recipe.tier == 1 then t1 = t1 + 1 end
		end
		local band = locality.band_of(zone.level_max)
		check(plain_tiers[band], zone.display_name .. " cooks the T" .. band .. " plain dish")
		if zone.level_max <= 10 then
			check(t1 >= 2, zone.display_name .. " cooks at least two T1 recipes (" .. t1 .. ")")
		elseif zone.level_max <= 20 then
			check(plain_tiers[1] and plain_tiers[2],
				zone.display_name .. " cooks the T1 and the T2 plain dish")
		end
		if zone.id == "elandor_frostbarrow_shelf" then
			frostbarrow = false
			for _, row in ipairs(cookable) do
				frostbarrow = frostbarrow or row.recipe.tier == 3
			end
		end
	end
	check(frostbarrow == true, "Frostbarrow Shelf cooks a T3 recipe")
end

------------------------------------------------------------------------------
-- D. The craft count against the take.
------------------------------------------------------------------------------
do
	local H = dofile(ROOT .. "/tools/r46_ck/jobs_harness.lua")(ROOT)
	local player_with, recipes, items = H.player_with, H.recipes, H.items
	check(#recipes == 24, "D 24 Cooking recipes (got " .. #recipes .. ")")
	local mash = grug_jobs.recipes_for_output("grug_cooking:sweetroot_mash")[1]
	local function crafts(list, recipe)
		return grug_jobs.crafts_from_counts(grug_jobs.ingredient_counts(player_with(list)), recipe)
	end
	eq(crafts({"grug_cooking:cassava 2", "grug_cooking:wild_grain 1"}, mash), 0,
		"D 2 Cassava + 1 Wild Grain: no Sweetroot Mash")
	eq(crafts({"grug_cooking:cassava 4", "grug_cooking:wild_grain 1"}, mash), 1,
		"D 4 Cassava + 1 Wild Grain: one Sweetroot Mash")
	eq(crafts({"grug_cooking:cassava 6", "grug_cooking:wild_grain 2"}, mash), 2,
		"D 6 Cassava + 2 Wild Grain: two")
	eq(crafts({"grug_gathering:potato 1", "grug_cooking:carrot 2", "grug_cooking:wild_grain 3"},
		mash), 1, "D a potato as the staple: one")
	-- The review's worst case (128 slots, half Cassava 99, half Wild Grain
	-- 99; Round 46 fix round): 2112 crafts fit, more than one job takes (the
	-- output area holds 4 x 99), so ×N reads the ceiling + 1, which a take
	-- still manages. With 8 Cassava stacks the search finds the exact 264.
	local worst, search = {}, {}
	for index = 1, 128 do
		worst[index] = (index % 2 == 1 and "grug_cooking:cassava" or "grug_cooking:wild_grain") .. " 99"
		search[index] = (index <= 8 and "grug_cooking:cassava" or "grug_cooking:wild_grain") .. " 99"
	end
	local function count_in(list)
		return grug_jobs.crafts_from_counts(grug_jobs.ingredient_counts(player_with(list, 64)), mash)
	end
	eq(count_in(worst), 397, "D the worst case reads the job ceiling + 1")
	check(grug_jobs.take_ingredients(player_with(worst, 64), mash.ingredients, 2112) ~= nil and
		grug_jobs.take_ingredients(player_with(worst, 64), mash.ingredients, 2113) == nil,
		"D ...where the take manages 2112 and no more")
	eq(count_in(search), 264, "D the searched case: 264")
	check(grug_jobs.take_ingredients(player_with(search, 64), mash.ingredients, 264) ~= nil and
		grug_jobs.take_ingredients(player_with(search, 64), mash.ingredients, 265) == nil,
		"D ...exactly what the take manages")
	-- Every recipe on a few inventories: the count is exactly what the take
	-- can take (it succeeds at ×N and fails at every quantity above, up to the
	-- per-entry total).
	local names = {}
	for name in pairs(items) do names[#names + 1] = name end
	table.sort(names)
	local seed = 7
	local function roll(n)
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed % n
	end
	-- Per recipe three inventories of its own inputs (1-2 stacks of 1-4 of a
	-- random accepted item per entry), shuffled, plus two random stacks.
	local inventories = {}
	for _, recipe in ipairs(recipes) do
		for _ = 1, 3 do
			local list = {}
			for _, entry in ipairs(recipe.ingredients) do
				local members = {}
				for _, name in ipairs(names) do
					if grug_jobs.ingredient_accepts(entry, name) then members[#members + 1] = name end
				end
				for _ = 1, roll(2) + 1 do
					list[#list + 1] = members[roll(#members) + 1] .. " " .. (roll(4) + 1)
				end
			end
			for _ = 1, 2 do list[#list + 1] = names[roll(#names) + 1] .. " " .. (roll(4) + 1) end
			for i = #list, 2, -1 do
				local j = roll(i) + 1
				list[i], list[j] = list[j], list[i]
			end
			inventories[#inventories + 1] = list
		end
	end
	local mismatches, positive = 0, 0
	for _, list in ipairs(inventories) do
		for _, recipe in ipairs(recipes) do
			local n = crafts(list, recipe)
			if n > 0 then positive = positive + 1 end
			local ok_n = n == 0 or grug_jobs.take_ingredients(player_with(list),
				recipe.ingredients, n) ~= nil
			local counts = grug_jobs.ingredient_counts(player_with(list))
			local bound = n + 1
			for _, entry in ipairs(recipe.ingredients) do
				bound = math.max(bound, math.floor(grug_jobs.ingredient_have(counts, entry) / entry.n))
			end
			local more
			for quantity = n + 1, bound do
				more = more or grug_jobs.take_ingredients(player_with(list), recipe.ingredients,
					quantity)
			end
			if not ok_n or more ~= nil then
				mismatches = mismatches + 1
				print("D mismatch " .. recipe.output .. " x" .. n .. ": " .. table.concat(list, ", "))
			end
		end
	end
	eq(mismatches, 0, "D xN equals the takeable count")
	print(("D %d recipe x inventory cases, %d craftable"):format(#inventories * #recipes, positive))
end

print(("R46 CK PORTABLE %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL",
	checks, failures))
if failures > 0 then error("R46 CK PORTABLE FAIL", 0) end
