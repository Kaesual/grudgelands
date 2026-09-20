-- Bounded real-module fixture for named enchant catalogs and pure transactions.

return function(repo)
	local globals = {"core", "PcgRandom", "ItemStack", "grug_items",
		"grug_gear", "grug_mobs", "grug_inventory", "grug_classes",
		"grug_xp", "grug_core", "grug_zones", "mobs", "grug_jobs",
		"grug_professions", "grug_artisans", "grug_traders", "grug_materials"}
	local saved = {}
	for index = 1, #globals do saved[globals[index]] = rawget(_G, globals[index]) end
	local function restore()
		for index = 1, #globals do rawset(_G, globals[index], saved[globals[index]]) end
	end
	local function fail(message)
		restore()
		error("r13 enchants: " .. message, 0)
	end
	local function check(value, message) if not value then fail(message) end end

	local function clone(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[key] = clone(child) end
		return result
	end

	-- Stable, interpreter-neutral stand-in for the engine's PcgRandom API. The
	-- production module still constructs PcgRandom for every roll; this fixture
	-- controls only its deterministic number stream.
	PcgRandom = function(seed)
		local state = math.floor(tonumber(seed) or 1) % 2147483647
		if state == 0 then state = 1 end
		return {next = function(self, minimum, maximum)
			state = (state * 48271) % 2147483647
			return minimum + (state % (maximum - minimum + 1))
		end}
	end

	local definitions = {}
	local serialized_stacks = {}
	local serialized_stack_id = 0
	local Stack = {}
	Stack.__index = Stack
	local function new_meta(owner)
		return {
			get_string = function(_, key) return owner.values[key] or "" end,
			set_string = function(_, key, value)
				owner.values[key] = tostring(value or "")
			end,
			get_int = function(_, key)
				return math.floor(tonumber(owner.values[key]) or 0)
			end,
			set_int = function(_, key, value)
				owner.values[key] = tostring(math.floor(tonumber(value) or 0))
			end,
			set_tool_capabilities = function(_, value) owner.caps = clone(value) end,
		}
	end
	local function make_stack(value)
		if getmetatable(value) == Stack then
			return setmetatable({name = value.name, count = value.count,
				values = clone(value.values), caps = clone(value.caps), wear=value.wear}, Stack)
		end
		if type(value) == "string" and serialized_stacks[value] then
			return make_stack(serialized_stacks[value])
		end
		local text = tostring(value or "")
		return setmetatable({name = text:match("^%s*([^%s]+)") or "",
			count = tonumber(text:match("%s+(%d+)$")) or (text == "" and 0 or 1), values = {}, caps = nil}, Stack)
	end
	function Stack:is_empty() return self.name == "" or self.count == 0 end
	function Stack:get_name() return self.name end
	function Stack:get_count() return self.count end
	function Stack:set_count(value) self.count = value end
	function Stack:get_wear() return self.wear or 0 end
	function Stack:set_wear(value) self.wear = value end
	function Stack:get_definition() return definitions[self.name] or {} end
	function Stack:get_meta() return new_meta(self) end
	function Stack:get_tool_capabilities()
		return clone(self.caps or (self:get_definition().tool_capabilities or {}))
	end
	function Stack:to_string()
		serialized_stack_id = serialized_stack_id + 1
		local key = "quality_kat_stack_" .. serialized_stack_id
		serialized_stacks[key] = make_stack(self)
		return key
	end
	ItemStack = make_stack

	local function serialize(value)
		if type(value) == "string" then return string.format("%q", value) end
		if type(value) ~= "table" then return tostring(value) end
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local out = {"{"}
		for _, key in ipairs(keys) do
			out[#out + 1] = "[" .. serialize(key) .. "]=" .. serialize(value[key]) .. ","
		end
		out[#out + 1] = "}"
		return table.concat(out)
	end
	local leave_callbacks, ground_drops = {}, {}
	core = {}
	function core.serialize(value) return serialize(value) end
	function core.deserialize(text)
		local chunk = loadstring("return " .. text)
		return chunk and chunk() or nil
	end
	function core.colorize(_, text) return text end
	function core.get_us_time() return 123456789 end
	function core.get_gametime() return 123 end
	function core.add_item(_, stack)
		ground_drops[#ground_drops + 1] = ItemStack(stack)
		return {stack = ItemStack(stack), set_velocity = function() end}
	end
	function core.register_on_leaveplayer(callback)
		leave_callbacks[#leave_callbacks + 1] = callback
	end
	function core.log() end

	local function weapon(name, groups, damage, fpi, ilvl)
		definitions[name] = {description = name:gsub("test:", "Test "),
			groups = groups, _grug_ilvl = ilvl, _grug_quality = 1,
			tool_capabilities = {full_punch_interval = fpi,
				damage_groups = {fleshy = damage}, groupcaps = {},
				max_drop_level = 0}}
	end
	weapon("test:melee", {grug_equip_weapon = 1, sword = 1}, 10, 1.0, 20)
	weapon("test:caster", {grug_equip_weapon = 1, staff = 1}, 9, 1.4, 20)
	weapon("test:bow", {grug_equip_weapon = 1, grug_bow = 1}, 9, 1.0, 20)
	definitions["test:shield"] = {description = "Test Shield",
		groups = {grug_equip_offhand = 1, grug_shield = 1},
		_grug_ilvl = 20, _grug_quality = 1, _grug_armor = 12}
	definitions["test:spellbook"] = {description = "Test Spellbook",
		groups = {grug_equip_offhand = 1, grug_spellbook = 1},
		_grug_ilvl = 20, _grug_quality = 1, _grug_max_mana_percent = 1}
	definitions["test:metal"] = {description = "Test Metal",
		groups = {grug_equip_chest = 1, grug_armor_class = 3},
		_grug_ilvl = 20, _grug_quality = 1, _grug_armor = 12}
	definitions["test:leather"] = {description = "Test Leather",
		groups = {grug_equip_chest = 1, grug_armor_class = 2},
		_grug_ilvl = 20, _grug_quality = 1, _grug_armor = 8}
	definitions["test:cloth"] = {description = "Test Cloth",
		groups = {grug_equip_chest = 1, grug_armor_class = 1},
		_grug_ilvl = 20, _grug_quality = 1, _grug_armor = 4}
	definitions["test:trinket"] = {description = "Test Trinket",
		groups = {grug_equip_trinket = 1}, _grug_ilvl = 20, _grug_quality = 1}

	grug_gear = {catalog = {}}
	local tier_item = {}
	for tier = 1, 6 do
		local name = "test:tier" .. tier
		tier_item[tier] = name
		weapon(name, {grug_equip_weapon = 1, sword = 1}, 3 + tier, 1.0,
			(tier - 1) * 10 + 1)
		grug_gear.catalog[tier] = {all = {name}}
	end
	function grug_gear.describe_stack_base(stack, ilvl, refined)
		local lines = {}
		if ilvl then lines[#lines + 1] = "Item level " .. ilvl end
		local def = stack:get_definition()
		if ((def.groups or {}).grug_equip_trinket or 0) > 0 then
			local special = stack:get_meta():get_string("grug_trinket_special")
			if special == "" then special = def._grug_trinket_special or "" end
			if special ~= "" then lines[#lines + 1] = special end
			return lines
		end
		local damage = def.tool_capabilities and
			def.tool_capabilities.damage_groups.fleshy
		local armor = def._grug_armor
		if damage then
			if refined then damage = math.floor(damage * 1.15 + 0.5) end
			lines[#lines + 1] = damage .. " damage, 1.0 s swing"
		elseif armor then
			if refined then armor = math.floor(armor * 1.15 + 0.5) end
			lines[#lines + 1] = armor .. " armor (-" .. armor .. "% damage taken)"
		end
		return lines
	end
	function grug_gear.initialize_weapon_tooltip(stack, player)
		grug_items.regenerate_description(stack, player)
		local groups = stack:get_definition().groups or {}
		if (groups.grug_equip_weapon or 0) > 0 then
			local meta = stack:get_meta()
			meta:set_string("description", meta:get_string("description") ..
				"\nEffective at level " .. player.level .. ": 99 damage per swing")
		end
		return true
	end

	local installed_kill_hook, installed_boss_reward_hook
	local registered_mobs = {}
	grug_mobs = {register_kill_loot_hook = function(callback)
		installed_kill_hook = callback
	end, register_boss_reward_hook = function(callback)
		installed_boss_reward_hook = callback
	end, register_mob = function(name, definition)
		registered_mobs[name] = definition
	end}
	grug_zones = {water_class_at = function() return "deep_ocean" end}
	mobs = {spawn = function() end}
	local equipment_slots = {
		{list = "grug_head"}, {list = "grug_chest"}, {list = "grug_legs"},
		{list = "grug_feet"}, {list = "grug_weapon"}, {list = "grug_offhand"},
		{list = "grug_trinket1"}, {list = "grug_trinket2"},
	}
	local forwarded_equipment_reason
	grug_inventory = {equipment_slots = equipment_slots,
		equipment_changed = function(_, _, reason)
			forwarded_equipment_reason = reason
		end,
		get_equipped_armor = function() return 0 end}
	grug_inventory.invalidate_armor = grug_inventory.equipment_changed
	grug_xp = {get_level = function(player) return player.level or 1 end}
	grug_classes = {
		get_attributes = function() return {str = 10, dex = 10, int = 10} end,
		get_crit_chance_raw = function() return 0.06 end,
		get_dodge_chance_raw = function() return 0.01 end,
		get_talent_bonus = function() return 0 end,
		pool_percent_amount = function(_, _, percent) return percent * 10 end,
		get_equipment_pool_percent = function() return 0 end,
	}
	grug_core = {PROTECTION_ARMOR_MULTIPLIER = 1.65,
		status_modifier_sum = function() return 0 end,
		equipment_is_broken = function() return false end,
		get_player_level = function(player) return player.level or 1 end,
		can_use_item_level = function(player, item)
			local def = item:get_definition()
			local required = def._grug_ilvl
			return not required or (player.level or 1) >= required, required,
				player.level or 1
		end}

	local old_table_copy = table.copy
	table.copy = clone
	local current_mod, mods_loaded = "grug_gear", {}
	core.registered_items, core.registered_nodes = definitions, {}
	function core.get_current_modname() return current_mod end
	function core.get_modpath(name)
		return repo .. "/mods/" .. (name == "grug_jobs" and "PLAYER/" or "ITEMS/") .. name
	end
	function core.register_tool(name, def) definitions[name:gsub("^:", "")] = def end
	core.register_craftitem = core.register_tool
	function core.override_item(name, changes)
		local def = assert(definitions[name], name)
		for key, value in pairs(changes) do def[key] = value end
	end
	function core.get_item_group(name, group)
		return ((definitions[name] or {}).groups or {})[group] or 0
	end
	function core.register_on_mods_loaded(callback) mods_loaded[#mods_loaded + 1] = callback end
	function core.register_on_joinplayer() end
	function core.register_on_craft() end
	function core.register_on_item_pickup() end
	function core.register_on_player_inventory_action() end
	function core.register_allow_player_inventory_action() end
	function core.register_craft() end
	function core.clear_craft() end
	function core.chat_send_player() end
	grug_core.register_on_equipment_change = function() end
	grug_classes.register_on_class_chosen = function() end
	grug_traders = {register_all_vendor_stock = function() end}
	grug_materials = {register_on_harvest = function() end}
	for _, name in ipairs({"default:sword_wood", "default:sword_stone", "default:axe_wood",
			"default:axe_stone", "default:axe_bronze", "default:axe_steel"}) do
		weapon(name, {axe = 1}, 4, 1, 1)
	end
	dofile(repo .. "/mods/ITEMS/grug_gear/init.lua")
	dofile(repo .. "/mods/ITEMS/grug_quality/init.lua")
	grug_jobs = {}
	dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
	dofile(repo .. "/mods/PLAYER/grug_jobs/state.lua")
	-- Shipped dependency resources; the tested content modules register their
	-- own components, real recipes and every enchant operation below.
	for _, name in ipairs({"default:coal_lump", "default:paper", "default:stick",
			"mobs:leather", "grug_mobs:light_leather", "grug_mobs:heavy_leather",
			"grug_mobs:scaled_hide", "grug_mobs:sleek_pelt", "grug_mobs:linen_scrap",
			"grug_mobs:linen_cloth", "grug_mobs:heavy_cloth", "grug_mobs:spider_silk",
			"grug_mobs:venom_gland", "grug_mobs:slime_gel", "grug_mobs:croc_tooth",
			"grug_mobs:stone_core", "grug_gathering:stormkelp",
			"grug_inventory:bag_small", "grug_inventory:bag_medium", "grug_inventory:bag_large",
			"grug_inventory:bag_great", "grug_inventory:bag_leather_pouch",
			"grug_inventory:bag_leather_satchel", "grug_inventory:bag_leather_pack",
			"grug_inventory:bag_leather_rucksack", "grug_inventory:quiver"}) do
		definitions[name] = {description = name}
	end
	definitions["default:wood"] = {groups = {wood = 1}}
	for _, name in ipairs({"bronze", "iron", "steel", "silversteel", "embersteel",
			"abyssal_steel", "tin", "copper", "gold"}) do
		definitions["grug_materials:" .. name .. "_bar"] = {description = name}
	end
	for _, name in ipairs({"quartz", "citrine", "garnet", "jade", "diamond", "sapphire", "ruby"}) do
		definitions["grug_materials:" .. (name == "quartz" and name or "rough_" .. name)] = {}
		definitions["grug_materials:cut_" .. name] = {}
	end
	current_mod = "grug_professions"
	dofile(repo .. "/mods/ITEMS/grug_professions/init.lua")
	current_mod = "grug_artisans"
	dofile(repo .. "/mods/ITEMS/grug_artisans/init.lua")
	for _, callback in ipairs(mods_loaded) do callback() end

	local player = {level = 60, values = {}}
	function player:get_player_name() return "enchanter" end
	function player:get_meta() return new_meta(self) end
	check(grug_jobs.learn(player, "weaponsmith"), "learn failed")
	-- Exercise the real progression API instead of inventing metadata keys.
	for _ = 1, 110 do
		grug_jobs.record_craft(player, "weaponsmith", grug_jobs.profession_level(player, "weaponsmith"))
	end
	check(grug_jobs.profession_level(player, "weaponsmith") == 6, "profession progression setup")
	local operations = grug_jobs.station_operations()
	check(#operations == 420, "complete named catalog must have 420 operations")
	local masters = {weaponsmith = player}
	local tested = 0
	for _, recipe in ipairs(operations) do
		local master = masters[recipe.profession]
		if not master then
			master = {level = 60, values = {}, get_meta = player.get_meta,
				get_player_name = player.get_player_name}
			check(grug_jobs.learn(master, recipe.profession), "catalog profession setup")
			for _ = 1, 110 do
				grug_jobs.record_craft(master, recipe.profession,
					grug_jobs.profession_level(master, recipe.profession))
			end
			masters[recipe.profession] = master
		end
		local grid = {ItemStack(recipe.output_name)}
		for _, token in ipairs(recipe.flat_inputs) do grid[#grid + 1] = ItemStack(token) end
		local result = assert(grug_items.operation_plan(recipe, grid, master))
		local affixes = grug_items.get_affixes(result.output)
		check(#affixes == 1 and affixes[1].stat == recipe.enchant_stat and
			affixes[1].channel == recipe.enchant_channel and
			affixes[1].value == recipe.enchant_value, "catalog operation mismatch")
		local consumed = 0
		for _, amount in pairs(result.consume) do consumed = consumed + amount end
		check(consumed == #recipe.flat_inputs + 1, "catalog consumption mismatch")
		check(grid[1]:get_meta():get_string("grug_ench") == "", "catalog preview mutated target")
		tested = tested + 1
	end
	check(tested == 420, "catalog application coverage")
	local operation = assert(grug_jobs.station_operation("enchant:melee_weapon:suffix:str:t1"))
	local target = ItemStack("grug_gear:sword_abyssal_steel")
	target:set_wear(12345)
	target:get_meta():set_string("_grug_repair_item_id", "identity-1")
	target:get_meta():set_string("_grug_wear_remainder", "321")
	local function inputs(recipe, item)
		local result = {ItemStack(item)}
		for _, token in ipairs(recipe.flat_inputs) do result[#result + 1] = ItemStack(token) end
		return result
	end
	local staged = inputs(operation, target)
	local plan = assert(grug_items.operation_plan(operation, staged, player))
	check(plan.output:get_wear() == 12345 and staged[1]:get_meta():get_string("grug_ench") == "",
		"preview mutated input or wear")
	check(plan.output:get_meta():get_string("_grug_repair_item_id") == "identity-1" and
		plan.output:get_meta():get_string("_grug_wear_remainder") == "321", "lost identity/remainder")
	local affix = grug_items.get_affixes(plan.output)[1]
	check(affix.channel == "suffix" and affix.value == 2 and affix.tier == 1,
		"T1 suffix scaled to target or wrong channel")
	check(plan.output:get_meta():get_string("description"):find("of the Bear", 1, true),
		"suffix-first name became prefix")
	check(not grug_items.operation_plan(operation, inputs(operation, plan.output), player), "no-op accepted")
	local prefix_same = grug_jobs.station_operation("enchant:melee_weapon:prefix:str:t6")
	check(not grug_items.operation_plan(prefix_same, inputs(prefix_same, plan.output), player),
		"duplicate opposite stat accepted")
	local prefix = grug_jobs.station_operation("enchant:melee_weapon:prefix:dex:t6")
	local both = assert(grug_items.operation_plan(prefix, inputs(prefix, plan.output), player)).output
	local both_affixes = grug_items.get_affixes(both)
	check(#both_affixes == 2 and both_affixes[1].value == 10 and both_affixes[2].value == 2,
		"adding prefix changed suffix")
	local replacement = grug_jobs.station_operation("enchant:melee_weapon:suffix:max_hp_percent:t4")
	local changed = assert(grug_items.operation_plan(replacement, inputs(replacement, both), player)).output
	check(grug_items.get_affixes(changed)[1].stat == "dex" and
		grug_items.get_affixes(changed)[2].value == 3, "replacement changed opposite channel")
	local speed_recipe = grug_jobs.station_operation("enchant:melee_weapon:prefix:attack_speed_percent:t6")
	local fast = assert(grug_items.operation_plan(speed_recipe, inputs(speed_recipe, target), player)).output
	check(fast:get_tool_capabilities().full_punch_interval < target:get_tool_capabilities().full_punch_interval,
		"attack-speed capability not applied")
	local replaced_speed = assert(grug_items.operation_plan(prefix, inputs(prefix, fast), player)).output
	check(replaced_speed:get_tool_capabilities().full_punch_interval == target:get_tool_capabilities().full_punch_interval,
		"replaced speed remained in capability")
	local low = ItemStack("grug_gear:sword_bronze")
	check(not grug_items.operation_plan(prefix, inputs(prefix, low), player), "higher enchant on low item")
	local novice = {level = 1, values = {}, get_meta = player.get_meta,
		get_player_name = player.get_player_name}
	check(grug_jobs.learn(novice, "weaponsmith"), "novice learning")
	-- Root's canonical starter definition grants level-one use at item level 3.
	definitions["grug_gear:sword_bronze"]._grug_req_level = 1
	check(grug_items.apply_crafted_quality(low, "base", novice), "starter initialization")
	check(low:get_meta():get_int("grug_req_level") == 1 and grug_core.can_use_item_level(novice, low),
		"fresh Bronze starter blocked at level one")
	local novice_plan = assert(grug_items.operation_plan(operation, inputs(operation, low), novice))
	check(grug_core.can_use_item_level(novice, novice_plan.output), "enchant blocked Bronze starter")
	check(grug_jobs.crafts_in_tier(novice, "weaponsmith") == 0, "preview awarded progress")
	grug_jobs.record_craft(novice, operation.profession, operation.tier)
	check(grug_jobs.crafts_in_tier(novice, "weaponsmith") == 1, "recipe-tier craft credit failed")
	local elevated = ItemStack("grug_gear:sword_bronze")
	elevated:get_meta():set_int("grug_quality", 3)
	check(grug_items.roll_enchants(elevated, 20, "world", nil, 8), "elevated found Bronze setup")
	check(elevated:get_meta():get_int("grug_req_level") == 20 and
		not grug_core.can_use_item_level(novice, elevated), "starter exception lowered found requirement")
	check(not grug_items.operation_plan(prefix, inputs(prefix, target), novice), "above-profession-tier allowed")
	definitions["test:gathering"] = {description = "Gathering Axe", _grug_bracket = 6,
		_grug_quality_family = "melee_weapon", groups = {grug_gathering_tool = 1, axe = 1}}
	check(grug_items.family_for(ItemStack("test:gathering")) == "tool", "gathering tool classified as weapon")
	check(not grug_items.operation_plan(operation, inputs(operation, ItemStack("test:gathering")), player),
		"gathering tool accepted as enchantable weapon")
	local wrong_family = inputs(operation, ItemStack("grug_gear:staff_abyssal_steel"))
	check(not grug_items.operation_plan(operation, wrong_family, player), "wrong target family accepted")
	local missing = inputs(operation, target)
	missing[3] = ItemStack("")
	check(not grug_items.operation_plan(operation, missing, player), "missing material accepted")
	local stranger = {level = 60, values = {}}
	stranger.get_meta, stranger.get_player_name = player.get_meta, player.get_player_name
	check(not grug_items.operation_plan(operation, staged, stranger), "unqualified operation accepted")
	target:set_wear(65535)
	local broken = assert(grug_items.operation_plan(prefix, inputs(prefix, target), player)).output
	check(broken:get_wear() == 65535 and broken:get_tool_capabilities().damage_groups.fleshy == 0,
		"enchanting repaired broken item")
	check(core.deserialize(broken:get_meta():get_string("_grug_repair_caps")).damage_groups.fleshy > 0,
		"broken repair capability snapshot missing")
	local found = ItemStack("grug_gear:sword_abyssal_steel")
	found:get_meta():set_int("grug_quality", 3)
	check(grug_items.roll_enchants(found, 75, "boss", nil, 7), "found roll failed")
	check(#grug_items.get_affixes(found) == 2 and found:get_meta():get_string("grug_refined") == "",
		"found gear lost affixes or created refined marker")
	local trinket = ItemStack(grug_gear.trinket_item("last_light", 6))
	check(grug_items.apply_crafted_quality(trinket, "fine", player, 7), "trinket assembly failed")
	local trinket_affixes = grug_items.get_affixes(trinket)
	check(#trinket_affixes == 2 and trinket_affixes[1].channel == "prefix" and
		trinket_affixes[2].channel == "suffix", "trinket exception lost fixed channels")
	check(grug_items.set_refined == nil and grug_items.append_affix == nil and
		grug_items.apply_upgrade_kit == nil, "retired operation API survived")
	for _, recipe in ipairs(grug_jobs.recipes) do
		check(recipe.operation == nil, "old refinement/affix recipe survived")
	end
	for name in pairs(definitions) do
		check(not name:find("_imbue_", 1, true) and not name:find("_temper_", 1, true),
			"retired kit remains registered")
	end
	table.copy = old_table_copy
	restore()
	return "PASS r13 enchants operations=420 applications=420 suffix-first fixed-tier replacement no-op profession family materials metadata broken found trinket starter-level speed-replacement\n"
end
