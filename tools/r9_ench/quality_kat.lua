-- Real-code KAT for R9-ENCH quality, affix, craft and player-tagged drop rules.
-- Usage: luajit -e 'io.write(dofile("tools/r9_ench/quality_kat.lua")("."))'

return function(repo)
	local globals = {"core", "PcgRandom", "ItemStack", "grug_items",
		"grug_gear", "grug_mobs", "grug_inventory", "grug_classes",
		"grug_xp", "grug_core", "grug_zones", "mobs"}
	local saved = {}
	for index = 1, #globals do saved[globals[index]] = rawget(_G, globals[index]) end
	local function restore()
		for index = 1, #globals do rawset(_G, globals[index], saved[globals[index]]) end
	end
	local function fail(message)
		restore()
		error("r9 enchant quality: " .. message, 0)
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
				values = clone(value.values), caps = clone(value.caps)}, Stack)
		end
		local text = tostring(value or "")
		return setmetatable({name = text:match("^%s*([^%s]+)") or "",
			count = text == "" and 0 or 1, values = {}, caps = nil}, Stack)
	end
	function Stack:is_empty() return self.name == "" or self.count == 0 end
	function Stack:get_name() return self.name end
	function Stack:get_count() return self.count end
	function Stack:set_count(value) self.count = value end
	function Stack:get_definition() return definitions[self.name] or {} end
	function Stack:get_meta() return new_meta(self) end
	function Stack:get_tool_capabilities()
		return clone(self.caps or (self:get_definition().tool_capabilities or {}))
	end
	ItemStack = make_stack

	local function serialize(value)
		local parts = {"return {"}
		for index = 1, #value do
			parts[#parts + 1] = string.format("{stat=%q,value=%.10g},",
				value[index].stat, value[index].value)
		end
		parts[#parts + 1] = "}"
		return table.concat(parts)
	end
	local leave_callbacks, ground_drops = {}, {}
	core = {}
	function core.serialize(value) return serialize(value) end
	function core.deserialize(text)
		local chunk = loadstring(text)
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
	function grug_gear.initialize_weapon_tooltip() return false end

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
	grug_inventory = {equipment_slots = equipment_slots,
		equipment_changed = function() end,
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
	grug_core = {status_modifier_sum = function() return 0 end,
		get_player_level = function(player) return player.level or 1 end,
		can_use_item_level = function(player, item)
			local def = item:get_definition()
			local required = def._grug_ilvl
			return not required or (player.level or 1) >= required, required,
				player.level or 1
		end}

	dofile(repo .. "/mods/ENTITIES/grug_mobs/kraken.lua")
	check(registered_mobs["grug_mobs:kraken"]._grug_no_quality_loot == true,
		"production Kraken lacks its authoritative no-quality-loot field")
	dofile(repo .. "/mods/ITEMS/grug_quality/init.lua")
	check(type(grug_items) == "table", "global API was not published")
	check(type(installed_kill_hook) == "function", "mob kill-loot hook was not installed")
	check(type(installed_boss_reward_hook) == "function",
		"boss-ledger reward hook was not installed")

	local report = {}
	local function row(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end
	local function same_members(actual, expected, label)
		local set = {}
		for index = 1, #actual do set[actual[index]] = true end
		for index = 1, #expected do
			check(set[expected[index]], label .. " misses " .. expected[index])
		end
		check(#actual == #expected, label .. " size differs")
	end

	-- A. Exact §6.2 pools.
	same_members(grug_items.POOLS.melee_weapon,
		{"str", "dex", "attack_speed_percent", "crit_percent",
			"max_hp_percent"}, "melee pool")
	same_members(grug_items.POOLS.caster_weapon,
		{"int", "max_mana_percent", "crit_percent", "max_hp_percent"},
		"caster pool")
	same_members(grug_items.POOLS.metal_armor,
		{"str", "max_hp_percent", "armor_percent", "dodge_percent"},
		"metal pool")
	same_members(grug_items.POOLS.leather_armor,
		{"dex", "max_hp_percent", "crit_percent", "dodge_percent"},
		"leather pool")
	same_members(grug_items.POOLS.cloth_armor,
		{"int", "max_mana_percent", "max_hp_percent", "crit_percent"},
		"cloth pool")
	row("pools", "five ordinary families", "exact")

	-- B. Every family x ilvl band x source window: legal, unique and bounded.
	local families = {
		{"test:melee", "melee_weapon"}, {"test:caster", "caster_weapon"},
		{"test:metal", "metal_armor"}, {"test:leather", "leather_armor"},
		{"test:cloth", "cloth_armor"},
	}
	local levels = {1, 16, 31, 46, 75}
	local windows = {"world", "crafted-fine", "elite", "rare",
		"crafted-masterwork", "boss"}
	local matrix = 0
	for family_index = 1, #families do
		local item, family = families[family_index][1], families[family_index][2]
		local legal = {}
		for index = 1, #grug_items.POOLS[family] do
			legal[grug_items.POOLS[family][index]] = true
		end
		for level_index = 1, #levels do
			for window_index = 1, #windows do
				local stack = ItemStack(item)
				stack:get_meta():set_int("grug_quality", 3)
				stack:get_meta():set_int("grug_refined", 1)
				local count = math.min(4, #grug_items.POOLS[family])
				local ok = grug_items.roll_enchants(stack, levels[level_index],
					windows[window_index], count,
					1000 + family_index * 100 + level_index * 10 + window_index)
				check(ok, family .. " matrix roll failed")
				local seen, affixes = {}, grug_items.get_affixes(stack)
				check(#affixes == count, family .. " fixed count differs")
				for index = 1, #affixes do
					local affix = affixes[index]
					check(legal[affix.stat], family .. " rolled illegal " .. affix.stat)
					check(not seen[affix.stat], family .. " duplicated " .. affix.stat)
					seen[affix.stat] = true
					local minimum, maximum = grug_items.range_for(affix.stat,
						levels[level_index])
					check(affix.value >= minimum and affix.value <= maximum,
						affix.stat .. " escaped its ilvl band")
				end
				matrix = matrix + 1
			end
		end
	end
	row("roll_matrix", tostring(matrix), "legal unique bounded")

	-- C. Refined-only gate and the fixed trinket exception.
	local plain = ItemStack("test:melee")
	plain:get_meta():set_int("grug_quality", 2)
	local plain_ok = grug_items.roll_enchants(plain, 20, "world", 1, 77)
	check(not plain_ok and #grug_items.get_affixes(plain) == 0,
		"unrefined ordinary item accepted an enchant")
	local found = ItemStack("test:melee")
	found:get_meta():set_int("grug_quality", 2)
	check(grug_items.roll_enchants(found, 20, "world", nil, 77) and
		found:get_meta():get_int("grug_refined") == 1 and
		#grug_items.get_affixes(found) >= 1,
		"crafterless world source did not arrive refined and enchanted")
	local trinket = ItemStack("test:trinket")
	trinket:get_meta():set_int("grug_quality", 3)
	trinket:get_meta():set_string("grug_trinket_special",
		"Restores 2 Rage on an accepted hit")
	check(grug_items.roll_enchants(trinket, 20, "rare", 4, 77),
		"trinket exception was refused")
	local trinket_affixes = grug_items.get_affixes(trinket)
	check(#trinket_affixes == 2, "trinket did not keep fixed two-affix shape")
	local prefix_ok = {str = true, int = true, dex = true}
	local suffix_ok = {max_hp_percent = true, max_mana_percent = true,
		crit_percent = true}
	check(prefix_ok[trinket_affixes[1].stat] and
		suffix_ok[trinket_affixes[2].stat], "trinket channels crossed pools")
	check(trinket:get_meta():get_string("description"):find(
		"Restores 2 Rage on an accepted hit", 1, true),
		"trinket authored special was lost during regeneration")
	row("trinket", "one prefix", "one suffix", "unrefined exception")

	-- D. §6.4's exact crafted-quality source table and mastery slot counts.
	local crafted = grug_items.CRAFTED_QUALITY
	check(crafted.base.quality == 1 and crafted.base.chance == 100 and
		not crafted.base.refined, "base crafted row differs")
	check(crafted.refinement.quality == 1 and crafted.refinement.refined and
		crafted.refinement.chance == 100, "refinement crafted row differs")
	check(crafted.fine.quality == 2 and crafted.fine.minimum == 1 and
		crafted.fine.maximum == 2 and crafted.fine.window == "crafted-fine",
		"fine crafted row differs")
	check(crafted.masterwork.quality == 3 and crafted.masterwork.minimum == 3 and
		crafted.masterwork.maximum == 4 and
		crafted.masterwork.window == "crafted-masterwork",
		"masterwork crafted row differs")
	local refused_masterwork = ItemStack("test:melee")
	local masterwork_ok, masterwork_reason = grug_items.apply_crafted_quality(
		refused_masterwork, "masterwork", {level = 30}, 900)
	check(not masterwork_ok and masterwork_reason:find("Expert", 1, true) and
		#grug_items.get_affixes(refused_masterwork) == 0,
		"below-Expert crafter was promoted into Masterwork slots")
	local permission_ok = grug_items.can_craft_quality({level = 30},
		{quality_mode = "masterwork"})
	check(not permission_ok, "Masterwork pre-consumption permission did not refuse")
	for _, sample in ipairs({{level = 1, mode = "fine", count = 1},
		{level = 16, mode = "fine", count = 2},
		{level = 31, mode = "masterwork", count = 3},
		{level = 46, mode = "masterwork", count = 4}}) do
		local stack = ItemStack("test:melee")
		check(grug_items.apply_crafted_quality(stack, sample.mode, sample, 900),
			"crafted " .. sample.mode .. " failed")
		check(#grug_items.get_affixes(stack) == sample.count,
			"crafted mastery count differs at " .. sample.level)
	end
	row("crafted", "Common/refined/Fine/Masterwork", "100% exact rows")

	-- E. §5.1 source chances and drop material/ilvl rules.
	local drop = grug_items.DROP_CHANCES
	check(drop.normal.uncommon == 3 and drop.normal.rare == 0 and
		drop.normal.window == "world", "normal chance row differs")
	check(drop.elite.uncommon == 20 and drop.elite.rare == 3 and
		drop.elite.window == "elite", "elite chance row differs")
	check(drop.rare.uncommon == 100 and drop.rare.rare == 25 and
		drop.rare.window == "rare", "rare chance row differs")
	check(drop.boss.uncommon == 0 and drop.boss.rare == 100 and
		drop.boss.window == "boss", "boss chance row differs")
	local king = {_grug_tier = "elite", _grug_royal_king = true,
		_grug_boss_id = "king:dwarf",
		_grug_level = 65, name = "test:king"}
	local king_drops = grug_items.roll_mob_gear(king, 11)
	check(#king_drops == 1 and king_drops[1]:get_name() == tier_item[6] and
		king_drops[1]:get_meta():get_int("grug_ilvl") == 70 and
		king_drops[1]:get_meta():get_int("grug_quality") == 3,
		"King ledger reward was not T6 ilvl 70 Rare")
	local dragon = {_grug_tier = "boss", _grug_boss_id = "dragon:wyrmglass",
		_grug_level = 60, name = "test:dragon"}
	local dragon_drops = installed_boss_reward_hook(dragon)
	check(#dragon_drops == 1 and dragon_drops[1]:get_name() == tier_item[6] and
		dragon_drops[1]:get_meta():get_int("grug_ilvl") == 75 and
		dragon_drops[1]:get_meta():get_int("grug_quality") == 3,
		"dragon ledger reward was not T6 ilvl 75 Rare")
	local kraken = grug_items.roll_mob_gear({_grug_tier = "normal",
		_grug_level = 100, _grug_no_quality_loot = true,
		name = "grug_mobs:kraken"}, 1)
	check(#kraken == 0, "lootless Kraken gained quality gear")
	local critter = grug_items.roll_mob_gear({_grug_tier = "critter",
		_grug_level = 1}, 1)
	check(#critter == 0, "food-only critter gained gear")
	local ordinary
	for seed = 1, 500 do
		local sample = grug_items.roll_mob_gear({_grug_tier = "normal",
			_grug_level = 21, name = "test:normal"}, seed)
		if #sample > 0 then ordinary = sample break end
	end
	check(ordinary and ordinary[1]:get_name() == tier_item[3] and
		ordinary[1]:get_meta():get_int("grug_ilvl") == 21,
		"level-21 drop escaped T3 or lost ilvl")
	local allowed, required = grug_core.can_use_item_level({level = 20}, ordinary[1])
	check(not allowed and required == 21,
		"per-stack drop level did not override the catalog anchor")
	local armor_level = ItemStack("test:metal")
	armor_level:get_meta():set_int("grug_refined", 1)
	check(grug_items.roll_enchants(armor_level, 46, "boss", 4, 13),
		"armor requirement probe did not roll")
	check(armor_level:get_meta():get_int("grug_req_level") == 0,
		"weapon-only level requirement leaked onto armor")
	local additive
	for seed = 1, 100 do
		local sample = grug_items.roll_mob_gear({_grug_tier = "rare",
			_grug_level = 42, name = "test:rare"}, seed)
		check(#sample >= 1 and sample[1]:get_meta():get_int("grug_quality") == 2,
			"named rare lost guaranteed Uncommon")
		if #sample == 2 then additive = sample break end
	end
	check(additive and additive[2]:get_meta():get_int("grug_quality") == 3,
		"named-rare independent Rare was never additive")
	local hook_mob = {_grug_tier = "boss", _grug_level = 60,
		name = "test:boss", object = {get_pos = function()
			return {x = 0, y = 0, z = 0}
		end}}
	installed_kill_hook(hook_mob, "tagger")
	local ground_before = #ground_drops
	installed_kill_hook(king, "tagger")
	installed_kill_hook(dragon, "tagger")
	check(#ground_drops == ground_before,
		"ledger boss escaped into the generic ground-drop hook")
	row("drop", "3/20+3/100+25/100", "ledger hook", "King 70 Dragon 75")

	-- F. Determinism, prefix/suffix naming and description idempotence.
	local function rolled(seed)
		local stack = ItemStack("test:melee")
		stack:get_meta():set_int("grug_quality", 3)
		stack:get_meta():set_int("grug_refined", 1)
		check(grug_items.roll_enchants(stack, 46, "boss", 4, seed),
			"determinism roll failed")
		return stack
	end
	local first, second = rolled(424242), rolled(424242)
	check(first:get_meta():get_string("grug_ench") ==
		second:get_meta():get_string("grug_ench"), "fixed seed changed affixes")
	check(first:get_meta():get_string("description") ==
		second:get_meta():get_string("description"), "fixed seed changed description")
	local meta = first:get_meta()
	local ench_before = meta:get_string("grug_ench")
	local quality_before = meta:get_int("grug_quality")
	local description = meta:get_string("description")
	check(description:find("Refined", 1, true) and
		description:find("Item level 46", 1, true),
		"description lost refined marker or item level")
	grug_items.regenerate_description(first)
	local once = meta:get_string("description")
	grug_items.regenerate_description(first)
	check(meta:get_string("description") == once,
		"description regeneration was not idempotent")
	check(meta:get_string("grug_ench") == ench_before and
		meta:get_int("grug_quality") == quality_before,
		"description round-trip changed authoritative meta")
	local affixes = grug_items.get_affixes(first)
	check(#affixes == 4, "four-slot description lost affixes")
	local suffix_one = grug_items.AFFIXES[affixes[2].stat].suffix:gsub("^of the ", "")
	local suffix_two = grug_items.AFFIXES[affixes[4].stat].suffix:gsub("^of the ", "")
	check(description:find("of " .. suffix_one .. " and " .. suffix_two, 1, true),
		"two suffixes did not combine positionally")
	local caps = first:get_tool_capabilities()
	local speed
	for index = 1, #affixes do
		if affixes[index].stat == "attack_speed_percent" then
			speed = affixes[index].value
		end
	end
	if speed then
		check(math.abs(caps.full_punch_interval - 1 / (1 + speed / 100)) < 0.000001,
			"attack speed did not use fpi/(1+p)")
	end
	row("description", "meta round-trip", "prefix/suffix positional",
		"fixed seed 424242")

	-- G. The new per-stack stats reach the existing aggregate consumers.
	local equipped = rolled(12345)
	local pool_stack = ItemStack("test:caster")
	pool_stack:get_meta():set_string("grug_ench", core.serialize({
		{stat = "max_hp_percent", value = 4},
		{stat = "max_mana_percent", value = 3},
	}))
	definitions["test:caster"]._grug_max_hp_percent = 2
	local inventory_reads = 0
	local inventory = {}
	function inventory:get_stack(listname)
		inventory_reads = inventory_reads + 1
		if listname == "grug_weapon" then return ItemStack(equipped) end
		if listname == "grug_offhand" then return ItemStack(pool_stack) end
		return ItemStack("")
	end
	local player = {level = 60,
		get_player_name = function() return "quality_player" end,
		get_inventory = function() return inventory end}
	grug_inventory.equipment_changed(player, "grug_weapon")
	local attributes = grug_classes.get_attributes(player)
	local totals = {str = 0, dex = 0, int = 0}
	for index = 1, #grug_items.get_affixes(equipped) do
		local slot = grug_items.get_affixes(equipped)[index]
		if totals[slot.stat] ~= nil then totals[slot.stat] = totals[slot.stat] + slot.value end
	end
	check(attributes.str == 10 + totals.str and attributes.dex == 10 + totals.dex and
		attributes.int == 10 + totals.int, "attribute consumers missed affixes")
	local reads_after_fill = inventory_reads
	local expected_hp, expected_mana = 2, 0
	for _, stack in ipairs({equipped, pool_stack}) do
		for _, slot in ipairs(grug_items.get_affixes(stack)) do
			if slot.stat == "max_hp_percent" then
				expected_hp = expected_hp + slot.value
			elseif slot.stat == "max_mana_percent" then
				expected_mana = expected_mana + slot.value
			end
		end
	end
	check(grug_classes.get_equipment_pool_percent(player, "hp") == expected_hp and
		grug_classes.get_equipment_pool_percent(player, "mana") == expected_mana,
		"pool percentages missed the equipment cache")
	check(inventory_reads == reads_after_fill,
		"cached pool percentage accessor rescanned equipment")
	row("consumers", "attributes", "crit/dodge/armor/pools cached")

	restore()
	return table.concat(report)
end
