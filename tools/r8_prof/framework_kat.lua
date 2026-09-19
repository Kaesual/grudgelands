-- Real-code KAT for the profession registry, state and grid permission gate.
-- Usage: <lua> -e 'io.write(dofile(".../framework_kat.lua")("/abs/repo"))'

return function(repo)
	local report = {}
	local function line(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end
	local saved = {core = rawget(_G, "core"), grug_jobs = rawget(_G, "grug_jobs"),
		grug_xp = rawget(_G, "grug_xp"), default = rawget(_G, "default"),
		ItemStack = rawget(_G, "ItemStack"), grug_mobs = rawget(_G, "grug_mobs"),
		grug_smelting = rawget(_G, "grug_smelting"),
		grug_items = rawget(_G, "grug_items")}
	local function restore()
		rawset(_G, "core", saved.core)
		rawset(_G, "grug_jobs", saved.grug_jobs)
		rawset(_G, "grug_xp", saved.grug_xp)
		rawset(_G, "default", saved.default)
		rawset(_G, "ItemStack", saved.ItemStack)
		rawset(_G, "grug_mobs", saved.grug_mobs)
		rawset(_G, "grug_smelting", saved.grug_smelting)
		rawset(_G, "grug_items", saved.grug_items)
	end
	local function fail(message)
		restore()
		error("r8 profession framework: " .. message, 0)
	end
	local function check(value, message) if not value then fail(message) end end

	local hooks = {predict = {}, craft = {}, mods_loaded = {}, leave = {},
		receive = {}, after = {}}
	local registered = {}
	local universal = {}
	local chats = {}
	local logs = {}
	local shown = {}
	local station_values = {}
	local station_meta = {
		get_string = function(self, key) return station_values[key] or "" end,
		set_string = function(self, key, value) station_values[key] = tostring(value) end,
		get_int = function(self, key) return tonumber(station_values[key]) or 0 end,
		set_int = function(self, key, value) station_values[key] = tostring(value) end,
		get_inventory = function()
			return {get_stack = function() return ItemStack("test:batch") end}
		end,
	}
	core = {registered_nodes = {['default:furnace'] = {}}, registered_items = {},
		registered_craft_predicts = hooks.predict, registered_on_crafts = hooks.craft}
	function core.register_craft(definition)
		registered[#registered + 1] = definition
		local name = tostring(definition.output):match("^%s*([^%s]+)") or ""
		if name ~= "" and not core.registered_items[name] then
			core.registered_items[name] = {description = name}
		end
	end
	function core.get_all_craft_recipes(output)
		local result = {}
		local existing = universal[output] or {}
		for index = 1, #existing do result[#result + 1] = existing[index] end
		for index = 1, #registered do
			local definition = registered[index]
			local name = tostring(definition.output):match("^%s*([^%s]+)") or ""
			if name == output then
				result[#result + 1] = {
					method = definition.type == "cooking" and "cooking" or "normal",
					items = definition.recipe,
					output = definition.output,
				}
			end
		end
		return #result > 0 and result or nil
	end
	function core.register_craft_predict(fn) hooks.predict[#hooks.predict + 1] = fn end
	function core.register_on_craft(fn) hooks.craft[#hooks.craft + 1] = fn end
	-- Byte-for-byte callback threading semantics of builtin/game/register.lua:
	-- every returned replacement becomes the next callback's input.
	function core.craft_predict(itemstack, player, old_craft_grid, craft_inv)
		for _, fn in ipairs(core.registered_craft_predicts) do
			itemstack = ItemStack(fn(itemstack, player, old_craft_grid, craft_inv) or
				itemstack)
		end
		return itemstack
	end
	function core.on_craft(itemstack, player, old_craft_grid, craft_inv)
		for _, fn in ipairs(core.registered_on_crafts) do
			itemstack = ItemStack(fn(itemstack, player, old_craft_grid, craft_inv) or
				itemstack)
		end
		return itemstack
	end
	function core.register_on_mods_loaded(fn) hooks.mods_loaded[#hooks.mods_loaded + 1] = fn end
	function core.after(delay, fn) hooks.after[#hooks.after + 1] = fn end
	function core.register_on_leaveplayer(fn) hooks.leave[#hooks.leave + 1] = fn end
	function core.register_on_player_receive_fields(fn)
		hooks.receive[#hooks.receive + 1] = fn
	end
	function core.show_formspec(name, formname, formspec)
		shown[#shown + 1] = {name = name, formname = formname, formspec = formspec}
	end
	function core.formspec_escape(value) return tostring(value) end
	function core.chat_send_player(name, text) chats[#chats + 1] = name .. ":" .. text end
	function core.log(level, text) logs[#logs + 1] = level .. ":" .. text end
	function core.get_item_group(name, group)
		local definition = core.registered_items[name]
		return definition and definition.groups and definition.groups[group] or 0
	end
	function core.get_gametime() return #chats + 1 end
	function core.get_meta() return station_meta end
	function core.override_item(name, changes)
		local definition = core.registered_nodes[name]
		for key, value in pairs(changes) do definition[key] = value end
	end
	default = {}
	local trainer_role
	grug_mobs = {}
	grug_smelting = {RECIPES = {
		{output = "test:dual_existing", inputs = {"test:t1", "test:base"}},
	}}
	function grug_mobs.register_start_socket_role(role, resolver)
		if role == "trainer" then trainer_role = resolver end
	end
	function ItemStack(value)
		local name = type(value) == "table" and value:get_name() or
			(tostring(value):match("^%s*([^%s]+)") or "")
		local count = type(value) == "table" and value:get_count() or
			(tonumber(tostring(value):match("%s+(%d+)%s*$")) or
				(name == "" and 0 or 1))
		return {get_name = function() return name end,
			get_count = function() return count end,
			is_empty = function() return name == "" end}
	end
	grug_xp = {get_level = function(player) return player.level end}
	grug_jobs = {}

	dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
	dofile(repo .. "/mods/PLAYER/grug_jobs/state.lua")
	dofile(repo .. "/mods/PLAYER/grug_jobs/stations.lua")

	local mutation = tonumber(os.getenv("R8_PROF_MUTATION") or "") or 0
	if mutation == 1 then
		local real = grug_jobs.register_recipe
		grug_jobs.register_recipe = function(definition)
			if definition.output == "test:c" then
				return {output_name = "test:c"}
			end
			return real(definition)
		end
	elseif mutation == 5 then
		local real = grug_jobs.register_recipe
		grug_jobs.register_recipe = function(definition)
			if definition.output == "test:b" then
				return {output_name = "test:b"}
			end
			return real(definition)
		end
	elseif mutation == 6 then
		local real = grug_jobs.register_recipe
		grug_jobs.register_recipe = function(definition)
			if definition.output == "test:dish" and definition.hint == "Grid" then
				return {output_name = "test:dish"}
			end
			return real(definition)
		end
	elseif mutation == 2 then
		local real = grug_jobs.learn
		grug_jobs.learn = function(player, profession)
			if profession == "tailor" then
				player:get_meta():set_string("grug_jobs:primary:2", profession)
				return true
			end
			return real(player, profession)
		end
	elseif mutation == 3 then
		local real = grug_jobs.record_craft
		grug_jobs.record_craft = function(player, profession, tier)
			if tier < grug_jobs.profession_level(player, profession) then
				player:get_meta():set_int("grug_jobs:crafts:" .. profession,
					player:get_meta():get_int("grug_jobs:crafts:" .. profession) + 1)
			end
			return real(player, profession, tier)
		end
	elseif mutation == 4 then
		grug_jobs.can_craft_recipe = function() return true end
	elseif mutation == 7 then
		local real = grug_jobs.profession_level
		grug_jobs.profession_level = function(player, profession)
			if not grug_jobs.has(player, profession) then return 1 end
			return real(player, profession)
		end
	elseif mutation == 8 then
		local real = grug_jobs.unlearn
		grug_jobs.unlearn = function(player, profession)
			local ok, text = real(player, profession)
			if ok then player:get_meta():set_int("grug_jobs:learned:" .. profession, 1) end
			return ok, text
		end
	elseif mutation == 10 then
		local real = grug_jobs.learn
		grug_jobs.learn = function(player, profession)
			if profession == "test_secondary" then return false end
			return real(player, profession)
		end
	elseif mutation == 11 then
		-- Model the old implementation: callbacks stay where init registered them.
		hooks.mods_loaded = {}
	elseif mutation == 12 then
		local real = grug_jobs.record_craft
		grug_jobs.record_craft = function(player, profession, tier)
			local advanced, level = real(player, profession, tier)
			if player:get_player_name() == "novice" and
					player:get_meta():get_int("grug_jobs:crafts:cooking") == 10 then
				player:get_meta():set_int("grug_jobs:level:cooking", 2)
				player:get_meta():set_int("grug_jobs:crafts:cooking", 0)
			end
			return advanced, level
		end
	elseif mutation == 13 then
		local real = grug_jobs.register_recipe
		grug_jobs.register_recipe = function(definition)
			if definition.output == "test:universal" then
				return {output_name = "test:universal"}
			end
			return real(definition)
		end
	elseif mutation == 14 then
		local real = hooks.craft[1]
			hooks.craft[1] = function(itemstack, player, grid, inventory)
			local result = real(itemstack, player, grid, inventory)
			if result and result:is_empty() and inventory and inventory.set_list then
				inventory:set_list("craft", grid)
			end
			return result
		end
	elseif mutation == 15 then
		-- Model the old timing: finalization runs inside grug_jobs' earlier
		-- mods-loaded callback, before a dependent mod's callback.
		core.after = function(delay, fn) fn() end
	elseif mutation == 16 then
		local real = grug_jobs.register_recipe
		grug_jobs.register_recipe = function(definition)
			if definition.output == "test:overlap_b" then
				return {output_name = "test:overlap_b"}
			end
			return real(definition)
		end
	elseif mutation == 17 then
		local real = grug_jobs.register_recipe
		grug_jobs.register_recipe = function(definition)
			if definition.output == "test:profession_override" then
				return {output_name = "test:profession_override"}
			end
			return real(definition)
		end
	elseif mutation == 18 then
		local real = grug_jobs.recipe_for_craft
		grug_jobs.recipe_for_craft = function(...)
			local recipe_value = real(...)
			return recipe_value
		end
	elseif mutation == 19 then
		grug_jobs.validate_recipe_collisions = function() return true end
	end

	local function meta()
		local values = {}
		return {
			get_string = function(self, key) return values[key] or "" end,
			set_string = function(self, key, value) values[key] = tostring(value) end,
			get_int = function(self, key) return tonumber(values[key]) or 0 end,
			set_int = function(self, key, value) values[key] = tostring(value) end,
		}
	end
	local function player(name, level)
		local metadata = meta()
		return {level = level, get_meta = function() return metadata end,
			get_player_name = function() return name end,
			is_player = function() return true end,
			get_pos = function() return {x = 0, y = 0, z = 0} end}
	end

	grug_jobs.register_ingredient_tier("test:t1", 1)
	grug_jobs.register_ingredient_tier("test:t2", 2)
	grug_jobs.register_ingredient_tier("test:t3", 3)
	grug_jobs.register_ingredient_tier("test:raw_path", 1)
	grug_jobs.register_ingredient_tier("test:universal_t1", 1)
	grug_jobs.register_ingredient_tier("test:material_t2", 2)
	core.registered_items["test:pine"] = {groups = {wood = 1}}
	core.registered_items["test:oak"] = {groups = {wood = 1}}
	universal["test:universal"] = {{method = "normal", items = {"test:base"},
		output = "test:universal"}}
	core.registered_items["test:universal"] = {description = "Universal"}
	universal["test:universal_inputs"] = {{method = "normal",
		items = {"test:universal_t1", "test:base"},
		output = "test:universal_inputs"}}
	core.registered_items["test:universal_inputs"] = {description = "Universal inputs"}
	universal["test:refinable"] = {{method = "normal", items = {"test:base"},
		output = "test:refinable"}}
	core.registered_items["test:refinable"] = {description = "Refinable"}
	check(table.concat(grug_jobs.CRAFTS_TO_ADVANCE, ",") == "10,15,20,25,30",
		"craft thresholds differ")
	local recipe = grug_jobs.register_recipe({profession = "cooking", tier = 1,
		station = "grid", inputs = {{"test:t1", "test:base"}},
		output = "test:dish", hint = "Crafting grid"})
	check(recipe.output_name == "test:dish" and #registered == 1,
		"valid grid recipe was not installed")
	recipe.quality_mode = "masterwork"
	grug_items = {
		can_craft_quality = function(player_value)
			if player_value.level < 31 then
				return false, "Expert mastery is required for Masterwork quality."
			end
			return true
		end,
		crafted_output = function() return true end,
	}
	local in_place_recipe = grug_jobs.register_recipe({profession = "cooking", tier = 1,
		station = "grid", inputs = {{"test:refinable", "test:t1"}},
		output = "test:refinable", in_place = true, hint = "Refine in grid"})
	check(in_place_recipe.in_place and
		#(core.get_all_craft_recipes("test:refinable") or {}) == 2,
		"in-place recipe did not share its universal output")
	local material_recipe = grug_jobs.register_recipe({profession = "cooking",
		tier = 2, station = "grid", inputs = {"test:t1"},
		output = "test:material_t2", material = true, hint = "Convert material"})
	local lower_tier_gear_ok = pcall(grug_jobs.register_recipe, {
		profession = "cooking", tier = 2, station = "grid", inputs = {"test:t1"},
		output = "test:gear_t2", hint = "Craft gear"})
	check(material_recipe.material and not lower_tier_gear_ok,
		"material tier exception escaped into gear")
	line("material_tier", "lower_input_accepted_at_output_tier",
		"gear_lower_input_refused")

	local function refused(label, definition)
		local ok = pcall(grug_jobs.register_recipe, definition)
		check(not ok, "accepted " .. label)
		line("refused", label)
	end
	refused("unknown profession", {profession = "fishing", tier = 1,
		station = "grid", inputs = {"test:t1"}, output = "test:a", hint = "Grid"})
	refused("unknown station", {profession = "cooking", tier = 1,
		station = "campfire", inputs = {"test:t1"}, output = "test:b", hint = "Fire"})
	refused("missing tier ingredient", {profession = "cooking", tier = 2,
		station = "grid", inputs = {"test:t1", "test:base"},
		output = "test:c", hint = "Grid"})
	refused("higher tier ingredient", {profession = "cooking", tier = 2,
		station = "grid", inputs = {"test:t2", "test:t3"},
		output = "test:d", hint = "Grid"})
	refused("duplicate output", {profession = "cooking", tier = 1,
		station = "grid", inputs = {"test:t1"}, output = "test:dish", hint = "Grid"})
	refused("universal output collision", {profession = "cooking", tier = 1,
		station = "grid", inputs = {"test:t1"}, output = "test:universal",
		hint = "Grid"})
	refused("dual-furnace output collision", {profession = "cooking", tier = 1,
		station = "grid", inputs = {"test:t1"}, output = "test:dual_existing",
		hint = "Grid"})
	refused("universal input collision", {profession = "cooking", tier = 1,
		station = "grid", inputs = {"test:universal_t1", "test:base"},
		output = "test:profession_override", hint = "Grid"})
	local non_grid_ok = pcall(grug_jobs.register_recipe, {profession = "cooking",
		tier = 1, station = "forge", inputs = {"test:refinable", "test:t1"},
		output = "test:refinable", in_place = true, hint = "Forge"})
	local missing_self_ok = pcall(grug_jobs.register_recipe, {profession = "cooking",
		tier = 1, station = "grid", inputs = {"test:t1", "test:base"},
		output = "test:missing_self", in_place = true, hint = "Grid"})
	check(not non_grid_ok and not missing_self_ok,
		"invalid in-place recipe was accepted")
	line("in_place", "universal_output_accepted", "ordinary_collision_refused",
		"non_grid_refused", "missing_output_input_refused")
	local overlap_recipe = grug_jobs.register_recipe({profession = "cooking", tier = 1,
		station = "grid", inputs = {"test:t1", "group:wood", "test:oak"},
		output = "test:overlap_a", hint = "Grid"})
	refused("overlapping group inputs", {profession = "cooking", tier = 1,
		station = "grid", inputs = {"test:t1", "test:pine", "group:wood"},
		output = "test:overlap_b", hint = "Grid"})
	check(#(core.get_all_craft_recipes("test:universal") or {}) == 1 and
		grug_jobs.recipe_for_output("test:universal") == nil,
		"refused collision damaged the universal recipe")
	check(overlap_recipe.output_name == "test:overlap_a",
		"non-ambiguous group recipe was not registered")
	universal["test:late_universal"] = {{method = "normal",
		items = {"test:t1", "test:base"}, output = "test:late_universal"}}
	core.registered_items["test:late_universal"] = {description = "Late universal"}
	check(not pcall(grug_jobs.validate_recipe_collisions),
		"final audit accepted a later universal input collision")
	universal["test:late_universal"] = nil
	core.registered_items["test:late_universal"] = nil
	check(grug_jobs.validate_recipe_collisions(),
		"final audit did not recover after collision fixture removal")
	line("registry", "recipes=" .. #grug_jobs.recipes, "engine=" .. #registered,
		"input_collisions_refused", "group_overlap_refused",
		"late_collision_audited")

	local crafter = player("crafter", 60)
	check(grug_jobs.learn(crafter, "blacksmith"), "first primary refused")
	check(grug_jobs.learn(crafter, "alchemist"), "second primary refused")
	check(not grug_jobs.learn(crafter, "tailor"), "third primary accepted")
	check(grug_jobs.learn(crafter, "cooking"), "secondary refused")
	grug_jobs.PROFESSIONS.test_secondary = {name = "Test Secondary", class = "secondary"}
	check(grug_jobs.learn(crafter, "test_secondary"), "second secondary refused")
	line("slots", grug_jobs.primary_at(crafter, 1), grug_jobs.primary_at(crafter, 2),
		"secondary_unlimited")

	local novice = player("novice", 10)
	grug_jobs.learn(novice, "cooking")
	for _ = 1, grug_jobs.CRAFTS_TO_ADVANCE[1] do
		grug_jobs.record_craft(novice, "cooking", 1)
	end
	check(grug_jobs.profession_level(novice, "cooking") == 1,
		"character band cap was bypassed")
	check(novice:get_meta():get_int("grug_jobs:level:cooking") == 1,
		"stored profession level exceeded the character band")
	check(grug_jobs.crafts_in_tier(novice, "cooking") == 10,
		"capped threshold was not retained in saturated form")
	novice.level = 11
	check(grug_jobs.profession_level(novice, "cooking") == 1,
		"profession advanced automatically with the character band")
	grug_jobs.record_craft(novice, "cooking", 1)
	check(grug_jobs.profession_level(novice, "cooking") == 2 and
		grug_jobs.crafts_in_tier(novice, "cooking") == 0,
		"next craft did not open the saturated tier")
	local before = grug_jobs.crafts_in_tier(novice, "cooking")
	grug_jobs.record_craft(novice, "cooking", 1)
	check(grug_jobs.crafts_in_tier(novice, "cooking") == before,
		"lower tier craft counted")
	line("levels", "tier=" .. grug_jobs.profession_level(novice, "cooking"),
		"count=" .. before, "band=2")

	local locked = player("locked", 60)
	grug_jobs.register_recipe({profession = "cooking", tier = 2,
		station = "grid", inputs = {"test:t2"}, output = "test:t2dish",
		hint = "Crafting grid"})
	local furnace_recipe = grug_jobs.register_recipe({profession = "cooking",
		tier = 1, station = "furnace", inputs = {"test:t1"},
		output = "test:batch 4", hint = "Furnace"})
	local alternate_path = grug_jobs.register_recipe({profession = "cooking",
		tier = 1, station = "furnace", inputs = {"test:raw_path"},
		output = "test:dish", hint = "Furnace"})
	check(alternate_path.output_name == recipe.output_name and
		grug_jobs.recipe_for_output("test:dish", "grid") == recipe and
		grug_jobs.recipe_for_output("test:dish", "furnace") == alternate_path,
		"one edible output did not retain its grid and furnace routes")
	local dish_grid = {ItemStack("test:t1"), ItemStack("test:base")}
	local tier2_grid = {ItemStack("test:t2")}
	local ambiguous_grid = {ItemStack("test:t1"), ItemStack("test:pine"),
		ItemStack("test:oak")}
	local later_predict = function(itemstack, player_value, grid)
		if grug_jobs._inputs_match({"test:t1", "test:base"}, grid) then
			return ItemStack("test:dish")
		elseif grug_jobs._inputs_match(
				{"test:t1", "test:pine", "test:oak"}, grid) then
			return ItemStack("test:foreign_output")
		end
	end
	local later_craft = function(itemstack, player_value, grid)
		if grug_jobs._inputs_match({"test:t1", "test:base"}, grid) then
			return ItemStack("test:callback_output")
		end
	end
	local raw_register_predict = core.register_craft_predict
	local raw_register_craft = core.register_on_craft
	-- This callback belongs to a dependent mod: it runs after grug_jobs'
	-- mods-loaded callback and only then appends output-replacing craft hooks.
	core.register_on_mods_loaded(function()
		core.register_craft_predict(later_predict)
		core.register_on_craft(later_craft)
	end)
	local audit_calls = 0
	local real_validate = grug_jobs.validate_recipe_collisions
	grug_jobs.validate_recipe_collisions = function(...)
		audit_calls = audit_calls + 1
		return real_validate(...)
	end
	local mods_loaded_count = #hooks.mods_loaded
	for index = 1, mods_loaded_count do hooks.mods_loaded[index]() end
	check(audit_calls == 0 and hooks.predict[#hooks.predict] == later_predict and
		hooks.craft[#hooks.craft] == later_craft,
		"authority finalized before later mods-loaded callbacks")
	local function run_after()
		while #hooks.after > 0 do table.remove(hooks.after, 1)() end
	end
	run_after()
	check(audit_calls == 1, "deferred collision audit did not run once")
	check(hooks.predict[#hooks.predict] ~= later_predict and
		hooks.craft[#hooks.craft] ~= later_craft,
		"profession gates were not finalized after later mods-loaded callbacks")
	local universal_predicted = core.craft_predict(ItemStack("test:universal"),
		locked, {ItemStack("test:base")})
	check(universal_predicted:get_name() == "test:universal",
		"refused profession collision made the universal recipe uncraftable")
	local universal_inputs_predicted = core.craft_predict(
		ItemStack("test:universal_inputs"), locked,
		{ItemStack("test:universal_t1"), ItemStack("test:base")})
	check(universal_inputs_predicted:get_name() == "test:universal_inputs",
		"same-input collision refusal damaged the universal recipe")
	local predicted = core.craft_predict(ItemStack("test:dish"), locked, dish_grid)
	check(predicted and predicted:is_empty(), "grid recipe predicted without book")
	local quality_novice = player("quality_novice", 30)
	grug_jobs.learn(quality_novice, "cooking")
	local quality_refused = core.craft_predict(ItemStack("test:dish"),
		quality_novice, dish_grid)
	check(quality_refused:is_empty() and
		chats[#chats]:find("Expert mastery", 1, true),
		"grid prediction did not refuse below-Expert Masterwork")
	grug_jobs.learn(locked, "cooking")
	check(not core.craft_predict(ItemStack("test:dish"), locked,
		dish_grid):is_empty(),
		"learned grid recipe was refused")
	local above = core.craft_predict(ItemStack("test:t2dish"), locked, tier2_grid)
	check(above and above:is_empty(), "grid recipe above profession level predicted")
	check(chats[#chats]:find("Cooking tier 2 required", 1, true) ~= nil,
		"grid denial did not name its profession-tier requirement")
	local restored = 0
	local craft_inventory = {set_list = function() restored = restored + 1 end}
	local emergency = core.on_craft(ItemStack("test:dish"),
		player("emergency", 60), dish_grid, craft_inventory)
	check(emergency:is_empty() and restored == 0,
		"on-craft emergency veto restored inputs or leaked replacement output")
	local crafted = core.on_craft(ItemStack("test:dish"), locked, dish_grid,
		craft_inventory)
	check(crafted:get_name() == "test:callback_output",
		"allowed later craft replacement was not preserved")
	check(grug_jobs.crafts_in_tier(locked, "cooking") == 1,
		"allowed craft was not recorded")
	line("permission", "locked_refused", "learned_allowed",
		"above_level_refused", "requirement_named", "last_in_real_chain",
		"masterwork_preconsume_refused", "emergency_no_restore",
		"universal_still_craftable", "craft_recorded")

	local late_predict = function(itemstack, player_value, grid)
		if grug_jobs._inputs_match({"test:t2"}, grid) then
			return ItemStack("test:late_predict_output")
		end
	end
	local late_craft = function(itemstack, player_value, grid)
		if grug_jobs._inputs_match({"test:t2"}, grid) then
			return ItemStack("test:late_craft_output")
		end
	end
	if mutation == 20 then
		core.register_craft_predict = function(callback)
			hooks.predict[#hooks.predict + 1] = callback
		end
		core.register_on_craft = function(callback)
			hooks.craft[#hooks.craft + 1] = callback
		end
	end
	local terminal_log_count = #logs
	core.register_craft_predict(late_predict)
	core.register_on_craft(late_craft)
	check(hooks.predict[#hooks.predict] ~= late_predict and
		hooks.craft[#hooks.craft] ~= late_craft,
		"late registration left the profession gate non-terminal")
	check(#logs == terminal_log_count + 1,
		"late callback registration was not logged exactly once")
	local first_late_predict = core.craft_predict(ItemStack("test:t2dish"),
		locked, tier2_grid)
	local first_late_craft = core.on_craft(ItemStack("test:t2dish"),
		locked, tier2_grid)
	check(first_late_predict:is_empty() and first_late_craft:is_empty(),
		"first craft after late output replacers escaped the terminal gate")

	-- A caller retaining the pre-finalisation functions bypasses the public API
	-- wrappers. The running gate must still move itself synchronously and let its
	-- newly terminal invocation make the one authoritative decision.
	local stale_predict = function() return ItemStack("test:stale_predict_output") end
	local stale_craft = function() return ItemStack("test:stale_craft_output") end
	raw_register_predict(stale_predict)
	raw_register_craft(stale_craft)
	check(core.craft_predict(ItemStack("test:t2dish"), locked,
		tier2_grid):is_empty(), "stale predict registrar escaped synchronous fallback")
	check(core.on_craft(ItemStack("test:t2dish"), locked,
		tier2_grid):is_empty(), "stale craft registrar escaped synchronous fallback")
	check(hooks.predict[#hooks.predict] ~= stale_predict and
		hooks.craft[#hooks.craft] ~= stale_craft,
		"synchronous fallback did not restore terminal gates")
	line("authority", "deferred_after_mods_loaded", "late_inserted_before_gate",
		"first_craft_refused", "stale_registrar_fail_closed", "logged_once")

	-- Inject the otherwise unregistrable second language to exercise the
	-- runtime fail-closed safety net against later group-definition drift.
	grug_jobs.recipes[#grug_jobs.recipes + 1] = {
		profession = "cooking", tier = 1, station = "grid",
		inputs = {"test:t1", "test:pine", "group:wood"},
		flat_inputs = {"test:t1", "test:pine", "group:wood"},
		output = "test:overlap_b", output_name = "test:overlap_b",
		hint = "Grid",
	}
	local ambiguous_actor = player("ambiguous", 60)
	local log_count = #logs
	local ambiguous = core.craft_predict(ItemStack("test:overlap_a"),
		ambiguous_actor, ambiguous_grid)
	check(ambiguous:is_empty(),
		"ambiguous group recipes failed open after an output replacer")
	core.craft_predict(ItemStack("test:overlap_a"), ambiguous_actor, ambiguous_grid)
	check(#logs == log_count + 1 and
		logs[#logs]:find("ambiguous profession grid", 1, true) ~= nil,
		"ambiguous craft was not logged exactly once")
	check(chats[#chats]:find("ambiguous profession recipe inputs", 1, true) ~= nil,
		"ambiguous craft denial did not reach the player")
	line("ambiguity", "overlap_registration_refused", "output_replaced",
		"runtime_fail_closed", "logged_once", "player_notified")

	local furnace = core.registered_nodes['default:furnace']
	local station_locked = player("station_locked", 60)
	check(furnace.allow_metadata_inventory_take({}, "dst", 1,
		ItemStack("test:batch"), station_locked) == 0,
		"station output was available without its profession")
	local station_actor = player("station_actor", 60)
	grug_jobs.learn(station_actor, "cooking")
	check(furnace.allow_metadata_inventory_move({}, "dst", 1, "src", 1, 1,
		station_actor) == 0, "station inventory move bypassed the take gate")
	for index = 1, 3 do
		check(furnace.allow_metadata_inventory_take({}, "dst", 1,
			ItemStack("test:batch"), station_actor) == 1,
			"station refused a learned recipe")
		furnace.on_metadata_inventory_take({}, "dst", 1,
			ItemStack("test:batch"), station_actor)
		check(grug_jobs.crafts_in_tier(station_actor, "cooking") == 0,
			"partial station output over-counted a craft")
	end
	furnace.on_metadata_inventory_take({}, "dst", 1,
		ItemStack("test:batch"), station_actor)
	check(grug_jobs.crafts_in_tier(station_actor, "cooking") == 1,
		"complete station batch was not recorded once")
	check(furnace_recipe.output_name == "test:batch", "station recipe differs")
	line("station", "locked_refused", "move_bypass_refused",
		"partial_batches_coalesced", "craft_recorded")

	for _ = 2, grug_jobs.CRAFTS_TO_ADVANCE[1] do
		grug_jobs.record_craft(locked, "cooking", 1)
	end
	check(grug_jobs.profession_level(locked, "cooking") == 2,
		"progression setup differs")
	check(grug_jobs.unlearn(locked, "cooking"), "unlearn refused")
	check(not grug_jobs.has(locked, "cooking") and
		grug_jobs.profession_level(locked, "cooking") == 0 and
		grug_jobs.crafts_in_tier(locked, "cooking") == 0,
		"unlearn retained progression")
	line("unlearn", "state_wiped")

	dofile(repo .. "/mods/PLAYER/grug_jobs/trainers.lua")
	check(type(trainer_role) == "function" and
		trainer_role({}, {race_id = "dwarf"}) == "grug_mobs:villager_dwarf",
		"trainer socket role was not installed")
	local trainee = player("trainee", 60)
	check(grug_jobs.open_trainer(trainee, "cooking", {x = 0, y = 0, z = 0}),
		"trainer formspec did not open")
	check(shown[#shown].formspec:find("Learn Cooking", 1, true) ~= nil,
		"trainer did not offer its profession")
	hooks.receive[1](trainee, "grug_jobs:trainer", {grug_jobs_learn = true})
	check(grug_jobs.has(trainee, "cooking") and
		shown[#shown].formspec:find("You already know Cooking", 1, true) ~= nil,
		"trainer did not learn the profession")
	hooks.receive[1](trainee, "grug_jobs:trainer", {grug_jobs_unlearn = true})
	check(shown[#shown].formspec:find("permanently loses progression", 1, true) ~= nil,
		"trainer skipped unlearn confirmation")
	hooks.receive[1](trainee, "grug_jobs:trainer", {grug_jobs_confirm = true})
	check(not grug_jobs.has(trainee, "cooking"),
		"trainer confirmation did not unlearn")
	line("trainer", "role_installed", "learned", "confirmed_unlearn")

	restore()
	return table.concat(report)
end
