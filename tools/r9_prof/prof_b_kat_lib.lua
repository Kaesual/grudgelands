-- Shared isolated-engine runner for the independently specified PROF-B KATs.

return function(repo, spec)
	local globals = {"core", "ItemStack", "grug_core", "grug_inventory",
		"grug_gear", "grug_jobs", "grug_items", "grug_materials",
		"grug_artisans", "grug_professions", "grug_classes", "grug_xp",
		"grug_mobs", "PcgRandom", "default", "vector"}
	local saved = {}
	for index = 1, #globals do
		local name = globals[index]
		saved[index] = {name = name, present = rawget(_G, name) ~= nil,
			value = rawget(_G, name)}
	end
	local old_table_copy = table.copy
	local function restore()
		for index = 1, #saved do
			local row = saved[index]
			if row.present then rawset(_G, row.name, row.value)
			else rawset(_G, row.name, nil) end
		end
		table.copy = old_table_copy
	end

	local function run()
		local function fail(message)
			error("r9 " .. spec.profession .. " catalog: " .. message, 0)
		end
		local function check(value, message) if not value then fail(message) end end
		vector = {distance = function(first, second)
			local dx, dy, dz = first.x-second.x, first.y-second.y, first.z-second.z
			return math.sqrt(dx*dx+dy*dy+dz*dz)
		end}

		if not table.copy then
			function table.copy(value)
				local out = {}
				for key, child in pairs(value or {}) do out[key] = child end
				return out
			end
		end
		local function copy(value)
			if type(value) ~= "table" then return value end
			local out = {}
			for key, child in pairs(value) do out[copy(key)] = copy(child) end
			return out
		end

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
					wear = value.wear, capabilities = value.capabilities}, Stack)
				result.meta = setmetatable({ints = {}, strings = {}, owner = result}, Meta)
				for key, child in pairs(value.meta.ints) do result.meta.ints[key] = child end
				for key, child in pairs(value.meta.strings) do
					result.meta.strings[key] = child
				end
				return result
			end
			local text = tostring(value or "")
			local name = text:match("^%s*([^%s]+)") or ""
			local count = tonumber(text:match("%s+(%d+)%s*$")) or
				(name == "" and 0 or 1)
			local result = setmetatable({name = name, count = count}, Stack)
			result.meta = setmetatable({ints = {}, strings = {}, owner = result}, Meta)
			return result
		end
		function Stack:get_name() return self.name end
		function Stack:get_count() return self.count end
		function Stack:is_empty() return self.name == "" or self.count <= 0 end
		function Stack:get_meta() return self.meta end
		function Stack:get_wear() return self.wear or 0 end
		function Stack:set_wear(value) self.wear = value end
		function Stack:take_item(amount)
			amount = math.min(self.count, tonumber(amount) or 1)
			self.count = self.count - amount
			if self.count <= 0 then self.name, self.count = "", 0 end
			return self
		end
		function Stack:get_definition() return core.registered_items[self.name] or {} end
		function Stack:get_tool_capabilities()
			return self.capabilities or self:get_definition().tool_capabilities or {}
		end
		ItemStack = stack

		local engine_recipes, mods_loaded = {}, {}
		local craft_predicts, craft_callbacks = {}, {}
		local allow_inventory_callbacks = {}
		local registration_count = {}
		local serialized, serial = {}, 0
		local node_meta = {}
		local current_mod = "grug_gear"
		core = {registered_items = {}, registered_nodes = {},
			registered_craft_predicts = craft_predicts,
			registered_on_crafts = craft_callbacks}
		function core.get_current_modname() return current_mod end
		function core.get_modpath(name)
			if name == "grug_gear" then return repo .. "/mods/ITEMS/grug_gear" end
			if name == "grug_jobs" then return repo .. "/mods/PLAYER/grug_jobs" end
			if name == "grug_artisans" then
				return repo .. "/mods/ITEMS/grug_artisans"
			end
			return nil
		end
		function core.serialize(value)
			serial = serial + 1
			local key = "kat:" .. serial
			serialized[key] = copy(value)
			return key
		end
		function core.deserialize(value) return copy(serialized[value]) end
		function core.get_us_time() return 123456789 end
		function core.get_gametime() return 123 end
		local function register(name, definition)
			name = name:gsub("^:", "")
			registration_count[name] = (registration_count[name] or 0) + 1
			check(core.registered_items[name] == nil, "duplicate registration " .. name)
			core.registered_items[name] = definition
		end
		core.register_craftitem = register
		core.register_tool = register
		function core.register_node(name, definition)
			name = name:gsub("^:", "")
			core.registered_nodes[name] = definition
			core.registered_items[name] = definition
		end
		function core.override_item(name, changes)
			local definition = assert(core.registered_items[name], name)
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
		function core.clear_craft(definition)
			if definition and definition.output then engine_recipes[definition.output] = nil end
		end
		function core.get_all_craft_recipes(output) return engine_recipes[output] end
		function core.get_item_group(name, group)
			local definition = core.registered_items[name]
			return definition and definition.groups and definition.groups[group] or 0
		end
		function core.register_on_mods_loaded(callback)
			mods_loaded[#mods_loaded + 1] = callback
		end
		function core.register_craft_predict(callback)
			craft_predicts[#craft_predicts + 1] = callback
		end
		function core.register_on_craft(callback)
			craft_callbacks[#craft_callbacks + 1] = callback
		end
		function core.register_on_item_pickup() end
		function core.register_on_leaveplayer() end
		function core.register_on_joinplayer() end
		function core.register_on_player_inventory_action() end
		function core.register_allow_player_inventory_action(callback)
			allow_inventory_callbacks[#allow_inventory_callbacks + 1] = callback
		end
		function core.register_lbm() end
		function core.after(_, callback) callback() end
		function core.formspec_escape(text) return text end
		function core.is_protected() return false end
		function core.remove_node() end
		function core.colorize(_, text) return text end
		function core.chat_send_player() end
		function core.log() end
		function core.add_item(_, item) return {item = item} end

		local Inventory = {}
		Inventory.__index = Inventory
		function Inventory:set_size(listname, size)
			self.sizes[listname] = size
			self.lists[listname] = self.lists[listname] or {}
		end
		function Inventory:get_size(listname) return self.sizes[listname] or 0 end
		function Inventory:get_stack(listname, index)
			return stack((self.lists[listname] or {})[index] or "")
		end
		function Inventory:set_stack(listname, index, value)
			self.lists[listname] = self.lists[listname] or {}
			self.lists[listname][index] = stack(value)
		end
		function Inventory:get_list(listname)
			local out = {}
			for index = 1, self:get_size(listname) do
				out[index] = self:get_stack(listname, index)
			end
			return out
		end
		function Inventory:is_empty(listname)
			for index = 1, self:get_size(listname) do
				if not self:get_stack(listname, index):is_empty() then return false end
			end
			return true
		end
		local function meta_for(pos)
			local key = pos.x .. ":" .. pos.y .. ":" .. pos.z
			if not node_meta[key] then
				local inv = setmetatable({sizes = {}, lists = {}}, Inventory)
				node_meta[key] = {strings = {}, ints = {}, inventory = inv}
			end
			local record = node_meta[key]
			return {
				get_inventory = function() return record.inventory end,
				get_string = function(_, name) return record.strings[name] or "" end,
				set_string = function(_, name, value) record.strings[name] = value end,
				get_int = function(_, name) return record.ints[name] or 0 end,
				set_int = function(_, name, value) record.ints[name] = value end,
			}
		end
		core.get_meta = meta_for

		PcgRandom = function(seed)
			local state = math.floor(tonumber(seed) or 1) % 2147483647
			return {next = function(_, minimum, maximum)
				state = (state * 48271) % 2147483647
				return minimum + state % (maximum - minimum + 1)
			end}
		end
		default = {
			get_hotbar_bg = function() return "" end,
			get_inventory_drops = function() end,
			set_inventory_action_loggers = function() end,
			node_sound_metal_defaults = function() return {} end,
			node_sound_wood_defaults = function() return {} end,
		}

		local function base(name, definition)
			core.registered_items[name] = definition or {description = name}
		end
		local defaults = {"default:sword_wood", "default:sword_stone",
			"default:axe_wood", "default:axe_stone", "default:axe_bronze",
			"default:axe_steel"}
		for index = 1, #defaults do
			base(defaults[index], {description = defaults[index], groups = {axe = 1},
				tool_capabilities = {full_punch_interval = 1,
					damage_groups = {fleshy = 4}, groupcaps = {}}})
		end
		base("default:wood", {description = "Wood", groups = {wood = 1}})
		base("default:coal_lump", {description = "Coal Lump"})
		base("grug_professions:parchment", {description = "Parchment"})

		grug_core = {register_on_equipment_change = function() end,
			notify_equipment_change = function() end,
			level_scale = function() return 1 end,
			mono_time = function() return 123 end,
			can_use_item_level = function() return true end,
			status_modifier_sum = function() return 0 end}
		grug_inventory = {}
		grug_classes = {
			class_ids = {"warrior", "mage", "priest"},
			get_armor_rank = function() return 3 end,
			get_class_def = function() return {name = "KAT"} end,
			get_talent_bonus = function() return 0 end,
			get_melee_bonus = function() return 0 end,
			register_on_class_chosen = function() end,
			pool_percent_amount = function(_, _, value) return value end,
		}
		grug_xp = {get_level = function(player) return player and player.level or 1 end}
		grug_mobs = {register_kill_loot_hook = function() end,
			register_boss_reward_hook = function() end}
		current_mod = "grug_gear"
		dofile(repo .. "/mods/ITEMS/grug_gear/init.lua")
		current_mod = "grug_quality"
		dofile(repo .. "/mods/ITEMS/grug_quality/init.lua")

		local material_items = {
			"grug_materials:quartz", "grug_materials:cut_quartz",
			"grug_materials:rough_citrine", "grug_materials:cut_citrine",
			"grug_materials:rough_garnet", "grug_materials:cut_garnet",
			"grug_materials:rough_jade", "grug_materials:cut_jade",
			"grug_materials:rough_diamond", "grug_materials:cut_diamond",
			"grug_materials:rough_sapphire", "grug_materials:cut_sapphire",
			"grug_materials:rough_ruby", "grug_materials:cut_ruby",
			"grug_materials:tin_bar", "grug_materials:copper_bar",
			"grug_materials:iron_bar", "grug_materials:steel_bar",
			"grug_materials:gold_bar", "grug_materials:embersteel_bar",
			"grug_materials:abyssal_steel_bar",
		}
		for index = 1, #material_items do base(material_items[index]) end
		for _, item in ipairs({"grug_mobs:venom_gland", "grug_mobs:slime_gel",
				"grug_mobs:croc_tooth", "grug_mobs:stone_core",
				"grug_gathering:stormkelp"}) do
			base(item)
		end
		local metals = {"bronze", "iron", "steel", "silversteel", "embersteel",
			"abyssal_steel"}
		local leathers = {"light", "cured", "heavy", "scaled", "sleek",
			"nightscale"}
		for tier = 1, 6 do
			base("grug_professions:metal_fittings_" .. metals[tier])
			base("grug_professions:weapon_grip_" .. leathers[tier])
		end

		local harvest_callback
		grug_materials = {
			register_on_harvest = function(callback) harvest_callback = callback end,
		}
		grug_professions = {}

		grug_jobs = {}
		dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
		grug_jobs.has = function(player, profession)
			return profession == "goldsmith" and player.goldsmith == true
		end
		grug_jobs.profession_level = function(player)
			return player.profession_level or 1
		end
		grug_jobs.can_craft_recipe = function() return true end
		grug_jobs.record_craft = function() end
		grug_jobs.station_book_button = function() return "" end
		grug_jobs.open_book = function() end
		dofile(repo .. "/mods/PLAYER/grug_jobs/stations.lua")
		for _, station in ipairs({"grid", "forge", "tanning_rack", "tailor_bench",
				"carving_bench", "jewellers_bench"}) do
			if station ~= "grid" then
				grug_jobs.register_station(station, {register_recipe = function() end})
			end
		end

		current_mod = "grug_artisans"
		dofile(repo .. "/mods/ITEMS/grug_artisans/init.lua")
		for index = 1, #mods_loaded do mods_loaded[index]() end

		local station_factory = dofile(repo ..
			"/mods/PLAYER/grug_jobs/station_nodes.lua")
		station_factory.register_nodes()
		dofile(repo .. "/mods/PLAYER/grug_inventory/equipment.lua")

		local actual = grug_jobs.recipes_for(spec.profession)
		check(#actual == #spec.recipes, "recipe count differs: " .. #actual ..
			" != " .. #spec.recipes)
		local function sorted_inputs(inputs)
			local flat = grug_jobs._flatten_inputs(inputs)
			table.sort(flat)
			return table.concat(flat, "|")
		end
		local function recipe_key(station, output, inputs)
			return station .. "::" .. output .. "::" .. sorted_inputs(inputs)
		end
		local expected, expected_outputs = {}, {}
		for index = 1, #spec.recipes do
			local row = spec.recipes[index]
			local key = recipe_key(row.station, row.output, row.inputs)
			check(not expected[key], "expected route duplicated: " .. key)
			expected[key] = row
			expected_outputs[row.output] = true
		end
		local actual_routes = {}
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
			local key = recipe_key(recipe.station, recipe.output_name, recipe.inputs)
			local row = expected[key]
			check(row ~= nil, "unexpected route " .. key)
			check(not actual_routes[key], "actual route duplicated: " .. key)
			actual_routes[key] = true
			check(recipe.tier == row.tier, key .. " tier differs")
			check(recipe.material == (row.material == true), key .. " material differs")
			check(recipe.in_place == (row.in_place == true), key .. " in-place differs")
			check(sorted_inputs(recipe.inputs) == sorted_inputs(row.inputs),
				key .. " inputs differ")
			local own_tier = false
			for input_index = 1, #recipe.flat_inputs do
				local input = recipe.flat_inputs[input_index]
				check(group_member(input) ~= nil, key .. " input is unregistered: " .. input)
				local tier = grug_jobs.ingredient_tier(input)
				if tier == recipe.tier then own_tier = true end
				check(tier == nil or tier <= recipe.tier,
					key .. " hides a higher-tier input")
			end
			if recipe.material then
				check(grug_jobs.ingredient_tier(recipe.output_name) == recipe.tier,
					key .. " material output tier differs")
			else
				check(own_tier, key .. " lacks its own-tier ingredient")
			end

			local concrete = {}
			if recipe.shaped then
				for grid_index = 1, 9 do concrete[grid_index] = stack("") end
				for row_index = 1, #recipe.inputs do
					for column = 1, 3 do
						local token = recipe.inputs[row_index][column] or ""
						concrete[(row_index - 1) * 3 + column] =
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
				concrete) == recipe, key .. " does not resolve")
			if recipe.station ~= "grid" then
				check(grug_jobs.recipe_for_craft("grid", stack(recipe.output_name),
					concrete) == nil, key .. " escaped into the grid")
			end
		end
		for key in pairs(expected) do
			check(actual_routes[key], "missing route " .. key)
		end

		local reachable = {}
		for name in pairs(core.registered_items) do
			if not expected_outputs[name] then reachable[name] = true end
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
		for output in pairs(expected_outputs) do
			check(reachable[output], "unreachable output " .. output)
		end

		for name, count in pairs(registration_count) do
			if name:match("^grug_artisans:") or name:match("^grug_gear:.*_t%d$") or
					name:match("^grug_gear:wand_") or
					name:match("^grug_gear:scepter_") or
					name:match("^grug_gear:orb_") then
				check(count == 1, "duplicate item concept " .. name)
			end
		end
		check(grug_jobs.validate_recipe_collisions(), "final collision audit failed")

		if spec.verify then
			spec.verify({check = check, core = core, stack = stack,
				actual = actual, craft_callbacks = craft_callbacks,
				craft_predicts = craft_predicts, harvest_callback = harvest_callback,
				allow_inventory = allow_inventory_callbacks[1],
				meta_for = meta_for})
		end
		return string.format("PASS r9 %s catalog recipes=%d outputs=%d\n",
			spec.profession, #actual, (function()
				local count = 0
				for _ in pairs(expected_outputs) do count = count + 1 end
				return count
			end)())
	end
	local ok, result = pcall(run)
	restore()
	if not ok then error(result, 0) end
	return result
end
