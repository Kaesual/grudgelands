-- Native craft matching, consumption and Basics discovery for the approved
-- six-tier caster/bow patterns. Expected layouts are independent of the recipe
-- registration loop; the strict production catalog audit also runs at startup.
return function(check, make_player)
	local metals = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}
	local occult = {"boar_tusk", "zombie_flesh", "bone", "bear_claw", "sharp_feather", "venom_sac"}
	local woods = {"seasoned", "polished", "hardened", "inlaid", "lacquered", "heartwood"}
	local stick, thread = "default:stick", "grug_professions:thread"
	local function craft(items, expected)
		local stacks = {}
		for index = 1, 9 do stacks[index] = ItemStack(items[index] or "") end
		local result, remaining = core.get_craft_result({method="normal", width=3, items=stacks})
		check(result.item:get_name() == expected, "native weapon output: " .. expected)
		check(result.item:get_count() == 1, "single weapon output: " .. expected)
		for _, stack in ipairs(remaining.items) do
			check(stack:is_empty(), "weapon ingredient debit: " .. expected)
		end
	end
	local function reject(items, forbidden)
		local result = core.get_craft_result({method="normal", width=3, items=items})
		check(result.item:get_name() ~= forbidden, "retired/incomplete pattern still crafts " .. forbidden)
	end
	for tier, metal in ipairs(metals) do
		local bar, component = "grug_materials:" .. metal .. "_bar", "grug_mobs:" .. occult[tier]
		local wand, staff, bow = "grug_gear:wand_" .. metal,
			"grug_gear:staff_" .. metal, "grug_gear:bow_" .. metal
		craft({"",component,"", "",bar,"", "",stick,""}, wand)
		craft({component,bar,component, "",stick,"", "",stick,""}, staff)
		craft({"",stick,thread, bar,"",thread, "",stick,thread}, bow)
		craft({thread,stick,"", thread,"",bar, thread,stick,""}, bow)
		local wood = "grug_artisans:" .. woods[tier] .. "_wood"
		reject({"",wood,"", "",wood,"", "",wood,""}, staff)
		reject({"",wood,"", "",stick,"", "","",""}, wand)
		reject({"",wood,"", "","grug_professions:metal_rod_" .. metal,"", "","",""}, wand)
		reject({"",wood,thread, wood,"",thread, "",wood,thread}, bow)
		reject({"",component,"", "","","", "",stick,""}, wand)
		reject({component,"",component, "",stick,"", "",stick,""}, staff)
		reject({"",stick,thread, stick,"",thread, "",stick,thread}, bow)
		check(#core.get_all_craft_recipes(wand) == 1, "wand has one current route")
		check(#core.get_all_craft_recipes(staff) == 1, "staff has one current route")
		check(#core.get_all_craft_recipes(bow) == 2, "bow retains both mirrored routes")
		local player = make_player("occult_recipe_" .. tier, 6 + tier)
		player.level = 1
		local records = {}
		for _, recipe in ipairs(grug_jobs.book_records(player, "general")) do
			if recipe.output_name == wand or recipe.output_name == staff or recipe.output_name == bow then
				records[#records + 1] = recipe
				check(grug_jobs.recipe_discovered(player, recipe) == (tier == 1), "initial book visibility")
				check(recipe.profession == "general", "profession-free Basics owner")
				local grid = {}
				for index = 1, 9 do
					local ingredient = recipe.display_items[index] or ""
					grid[index] = ItemStack(ingredient == "group:stick" and stick or ingredient)
				end
				local preview = core.craft_predict(ItemStack(recipe.output_name),
					player, grid, player:get_inventory())
				check(preview:get_name() == recipe.output_name, "level-one profession-free preview")
				if tier > 1 then
					check(recipe.basics_presentation.main_material == bar, "metal is discovery material")
				end
			end
		end
		check(#records == 4, "exact Basics weapon routes per tier")
		player:get_inventory():set_stack("main", 1, ItemStack(wood))
		player:get_inventory():set_stack("main", 2, ItemStack(component))
		grug_jobs._scan_discovery(player)
		for _, recipe in ipairs(records) do
			check(grug_jobs.recipe_discovered(player, recipe) == (tier == 1), "wood/drop alone reveals no later tier")
		end
		player:get_inventory():set_stack("main", 3, ItemStack(bar))
		grug_jobs._scan_discovery(player)
		for _, recipe in ipairs(records) do
			check(grug_jobs.recipe_discovered(player, recipe), "collected metal reveals weapons")
		end
	end
	core.log("action", "OCCULT WEAPON RECIPES PASS tiers=6 outputs=18 routes=24")
end
