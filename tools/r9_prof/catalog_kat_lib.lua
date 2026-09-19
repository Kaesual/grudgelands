-- Shared stub runner for the three independently specified R9 catalog KATs.

return function(repo, spec)
	local names = {"core", "ItemStack", "grug_jobs", "grug_professions",
		"grug_inventory", "grug_gear", "grug_traders"}
	local saved = {}
	for index = 1, #names do
		local name = names[index]
		saved[index] = {name = name, present = rawget(_G, name) ~= nil,
			value = rawget(_G, name)}
	end
	local function restore()
		for index = 1, #saved do
			local row = saved[index]
			if row.present then
				rawset(_G, row.name, row.value)
			else
				rawset(_G, row.name, nil)
			end
		end
	end
	local function run()
	local function fail(message)
		error("r9 " .. spec.profession .. " catalog: " .. message, 0)
	end
	local function check(value, message) if not value then fail(message) end end

	local Meta = {}
	Meta.__index = Meta
	function Meta:get_int(name) return self.ints[name] or 0 end
	function Meta:set_int(name, value) self.ints[name] = value end
	function Meta:get_string(name) return self.strings[name] or "" end
	function Meta:set_string(name, value) self.strings[name] = value end
	function Meta:set_tool_capabilities(value) self.owner.capabilities = value end

	local Stack = {}
	Stack.__index = Stack
	local function stack(value)
		if type(value) == "table" and getmetatable(value) == Stack then
			local result = setmetatable({name = value.name, count = value.count,
				capabilities = value.capabilities, wear = value.wear}, Stack)
			result.meta = setmetatable({ints = {}, strings = {}, owner = result}, Meta)
			for k, v in pairs(value.meta.ints) do result.meta.ints[k] = v end
			for k, v in pairs(value.meta.strings) do result.meta.strings[k] = v end
			return result
		end
		local text = tostring(value or "")
		local name = text:match("^%s*([^%s]+)") or ""
		local count = tonumber(text:match("%s+(%d+)%s*$")) or (name == "" and 0 or 1)
		local result = setmetatable({name = name, count = count}, Stack)
		result.meta = setmetatable({ints = {}, strings = {}, owner = result}, Meta)
		return result
	end
	function Stack:get_name() return self.name end
	function Stack:get_count() return self.count end
	function Stack:get_wear() return self.wear or 0 end
	function Stack:set_wear(value) self.wear = value end
	function Stack:is_empty() return self.name == "" or self.count == 0 end
	function Stack:get_meta() return self.meta end
	function Stack:get_definition() return core.registered_items[self.name] or {} end
	function Stack:get_tool_capabilities()
		return self.capabilities or self:get_definition().tool_capabilities or {}
	end
	ItemStack = stack

	local engine_recipes, predicts, crafts, mods_loaded = {}, {}, {}, {}
	core = {registered_items = {}, registered_nodes = {},
		registered_craft_predicts = predicts, registered_on_crafts = crafts}
	function core.get_modpath(name)
		if name == "grug_professions" then
			return repo .. "/mods/ITEMS/grug_professions"
		end
		return nil
	end
	function core.get_current_modname() return "grug_professions" end
	function core.register_craftitem(name, definition)
		name = name:gsub("^:", "")
		core.registered_items[name] = definition
	end
	function core.override_item(name, changes)
		local definition = assert(core.registered_items[name])
		for key, value in pairs(changes) do definition[key] = value end
	end
	function core.register_craft(definition)
		local output = definition.output:match("^([^%s]+)")
		local list = engine_recipes[output] or {}
		list[#list + 1] = {method = definition.type == "cooking" and
			"cooking" or "normal", items = definition.recipe,
			output = definition.output}
		engine_recipes[output] = list
	end
	function core.get_all_craft_recipes(output) return engine_recipes[output] end
	function core.get_item_group(name, group)
		local definition = core.registered_items[name]
		return definition and definition.groups and definition.groups[group] or 0
	end
	function core.register_craft_predict(callback) predicts[#predicts + 1] = callback end
	function core.register_on_craft(callback) crafts[#crafts + 1] = callback end
	function core.register_on_mods_loaded(callback)
		mods_loaded[#mods_loaded + 1] = callback
	end
	function core.chat_send_player() end
	function core.colorize(_, text) return text end
	function core.log() end

	local function base(name, definition)
		core.registered_items[name] = definition or {description = name}
	end
	for _, name in ipairs({
		"default:stone", "default:clay_lump", "default:coal_lump", "mobs:leather",
		"grug_materials:bronze_bar", "grug_materials:iron_bar",
		"grug_materials:steel_bar", "grug_materials:silversteel_bar",
		"grug_materials:embersteel_bar", "grug_materials:abyssal_steel_bar",
		"grug_materials:abyssal_crystal", "grug_mobs:venom_gland",
		"grug_mobs:slime_gel", "grug_mobs:croc_tooth",
		"grug_mobs:stone_core", "grug_gathering:stormkelp",
		"grug_mobs:light_leather", "grug_mobs:heavy_leather",
		"grug_mobs:scaled_hide", "grug_mobs:sleek_pelt",
		"grug_mobs:linen_scrap", "grug_mobs:linen_cloth",
		"grug_mobs:heavy_cloth", "grug_mobs:spider_silk",
		"grug_inventory:bag_small", "grug_inventory:bag_medium",
		"grug_inventory:bag_large",
	}) do base(name) end

	local metals = {"bronze", "iron", "steel", "silversteel", "embersteel",
		"abyssal_steel"}
	local picks = {"default:pick_bronze", "grug_materials:pick_iron",
		"default:pick_steel", "grug_materials:pick_silversteel",
		"grug_materials:pick_embersteel", "grug_materials:pick_abyssal_steel"}
	local cloth = {"patch", "woven", "heavy", "silkweave", "silk",
		"stormweave"}
	for tier = 1, 6 do
		base(picks[tier], {description = metals[tier] .. " pick\nItem level " .. tier,
			tool_capabilities = {full_punch_interval = 1,
				damage_groups = {fleshy = tier + 2}, groupcaps = {}},
			_grug_quality = 1})
		for _, family in ipairs({"sword", "dagger", "greataxe"}) do
			base("grug_gear:" .. family .. "_" .. metals[tier], {
				description = metals[tier] .. " " .. family .. "\nItem level " .. tier,
				tool_capabilities = {full_punch_interval = 1,
					damage_groups = {fleshy = tier + 4}, groupcaps = {}},
				_grug_quality = 1,
			})
		end
		for _, slot in ipairs({"head", "chest", "legs", "feet"}) do
			base("grug_gear:" .. slot .. "_metal_" .. metals[tier], {
				description = metals[tier] .. " metal " .. slot ..
					"\nItem level " .. tier, _grug_armor = tier + 1,
				_grug_quality = 1})
			base("grug_gear:" .. slot .. "_cloth_" .. cloth[tier], {
				description = cloth[tier] .. " cloth " .. slot ..
					"\nItem level " .. tier, _grug_armor = tier,
				_grug_quality = 1})
		end
	end

	grug_inventory = {get_equipped_armor = function() return 0 end}
	grug_gear = {initialize_weapon_tooltip = function() return false end}
	grug_traders = {register_all_vendor_stock = function() end}
	grug_jobs = {}
	dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
	for _, station in ipairs({"grid", "forge", "tanning_rack", "tailor_bench",
		"carving_bench", "jewellers_bench"}) do
		grug_jobs.register_station(station, {register_recipe = station == "grid" and
			function(recipe)
				core.register_craft({output = recipe.output, recipe = recipe.inputs})
			end or function() end})
	end

	dofile(repo .. "/mods/ITEMS/grug_professions/init.lua")
	for index = 1, #mods_loaded do mods_loaded[index]() end

	local actual = grug_jobs.recipes_for(spec.profession)
	check(#actual == #spec.recipes, "recipe count differs: " .. #actual ..
		" != " .. #spec.recipes)
	local expected = {}
	local function sorted_inputs(inputs)
		local flat = grug_jobs._flatten_inputs(inputs)
		table.sort(flat)
		return table.concat(flat, "|")
	end
	for index = 1, #spec.recipes do
		local row = spec.recipes[index]
		check(not expected[row.output], "expected output duplicated: " .. row.output)
		expected[row.output] = row
	end
	local actual_outputs = {}
	local function group_member(token)
		local group = token:match("^group:(.+)$")
		if not group then return core.registered_items[token] and token or nil end
		local names = {}
		for name in pairs(core.registered_items) do names[#names + 1] = name end
		table.sort(names)
		for index = 1, #names do
			if core.get_item_group(names[index], group) > 0 then return names[index] end
		end
		return nil
	end
	for index = 1, #actual do
		local recipe = actual[index]
		local row = expected[recipe.output_name]
		check(row ~= nil, "unexpected output " .. recipe.output_name)
		check(not actual_outputs[recipe.output_name],
			"actual output duplicated: " .. recipe.output_name)
		actual_outputs[recipe.output_name] = true
		check(recipe.tier == row.tier, recipe.output_name .. " tier differs")
		check(recipe.station == row.station,
			recipe.output_name .. " station differs")
		check(sorted_inputs(recipe.inputs) == sorted_inputs(row.inputs),
			recipe.output_name .. " inputs differ")
		if recipe.output_name:match("^grug_gear:") then
			local in_place = false
			for input_index = 1, #recipe.flat_inputs do
				if recipe.flat_inputs[input_index] == recipe.output_name then
					in_place = true
				end
			end
			check(in_place, recipe.output_name .. " was duplicated instead of refined")
		end

		local own_tier = false
		for input_index = 1, #recipe.flat_inputs do
			local input = recipe.flat_inputs[input_index]
			check(group_member(input) ~= nil,
				recipe.output_name .. " input is unregistered: " .. input)
			local tier = grug_jobs.ingredient_tier(input)
			if tier == recipe.tier then own_tier = true end
			check(tier == nil or tier <= recipe.tier,
				recipe.output_name .. " hides a higher-tier input")
		end
		check(own_tier, recipe.output_name .. " lacks its own-tier ingredient")

		local concrete = {}
		if recipe.shaped then
			for grid_index = 1, 9 do concrete[grid_index] = stack("") end
			for grid_row = 1, #recipe.inputs do
				for grid_column = 1, 3 do
					local token = recipe.inputs[grid_row][grid_column] or ""
					concrete[(grid_row - 1) * 3 + grid_column] =
						stack(group_member(token) or token)
				end
			end
		else
			for input_index = 1, #recipe.flat_inputs do
				local token = recipe.flat_inputs[input_index]
				concrete[input_index] = stack(group_member(token) or token)
			end
		end
		check(grug_jobs.recipe_for_craft(recipe.station, stack(recipe.output_name),
			concrete) == recipe, recipe.output_name .. " does not resolve")
		for _, foreign in ipairs({"grid", "forge", "tanning_rack", "tailor_bench"}) do
			if foreign ~= recipe.station then
				check(grug_jobs.recipe_for_craft(foreign, stack(recipe.output_name),
					concrete) == nil, recipe.output_name .. " escaped to " .. foreign)
			end
		end
	end
	for output in pairs(expected) do
		check(actual_outputs[output], "missing output " .. output)
	end

	-- Forward closure begins with gathered/mined/smelted inputs, universal base
	-- gear, and ordinary job supplies. Every authored intermediate/output must
	-- become reachable; a refinement is reachable because its base item is.
	local reachable = {}
	for name in pairs(core.registered_items) do
		if not name:match("^grug_professions:") or name == "grug_professions:thread" or
				name == "grug_professions:flux" or
				name == "grug_professions:parchment" or
				name == "grug_professions:whetstone_blank" then
			reachable[name] = true
		end
	end
	local changed = true
	while changed do
		changed = false
		for index = 1, #actual do
			local recipe, available = actual[index], true
			for input_index = 1, #recipe.flat_inputs do
				local token = recipe.flat_inputs[input_index]
				local member = group_member(token)
				if not reachable[token] and not (member and reachable[member]) then
					available = false
				end
			end
			if available and not reachable[recipe.output_name] then
				reachable[recipe.output_name], changed = true, true
			end
		end
	end
	for output in pairs(expected) do
		check(reachable[output], "unreachable output " .. output)
	end

	check(grug_jobs.validate_recipe_collisions(), "final collision audit failed")
	if spec.refinement then
		local row = expected[spec.refinement.output]
		local grid = {}
		for index = 1, #row.inputs do grid[index] = stack(row.inputs[index]) end
		local base_stack
		for index = 1, #grid do
			if grid[index]:get_name() == spec.refinement.output then
				base_stack = grid[index]
				break
			end
		end
		check(base_stack ~= nil, "refinement does not contain its base stack")
		base_stack:set_wear(12345)
		base_stack:get_meta():set_string("prior_meta", "preserved")
		local output = stack(spec.refinement.output)
		local callback_result
		for index = 1, #crafts do
			callback_result = crafts[index](output, nil, grid) or callback_result
		end
		output = callback_result or output
		check(output:get_meta():get_int("grug_refined") == 1,
			"refinement did not mark the output stack")
		check(output:get_meta():get_string("description"):find(
			spec.refinement.word, 1, true) ~= nil,
			"refinement word is absent")
		check(output:get_wear() == 12345, "refinement discarded base wear")
		check(output:get_meta():get_string("prior_meta") == "preserved",
			"refinement discarded base metadata")
		local base_armor = output:get_definition()._grug_armor
		if base_armor then
			check(grug_inventory.armor_points_of(output, base_armor) ==
				output:get_meta():get_int("grug_refined_armor"),
				"refined armor was not folded into the cache hook")
		end
	end

	return string.format("PASS r9 %s catalog recipes=%d outputs=%d\n",
		spec.profession, #actual, #spec.recipes)
	end

	local ok, result = pcall(run)
	restore()
	if not ok then error(result, 0) end
	return result
end
