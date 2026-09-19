-- Per-stack equipment quality and affixes (items_crafting.md §§5.1, 6, 6b).
--
-- This mod deliberately publishes the historical `grug_items` API name: the
-- shipped trader probes that one global before offering rolled Uncommons.
-- The mod itself is named grug_quality so its ownership remains explicit.
--
-- Shared item-meta keys (all belong to one concrete ItemStack):
--   grug_quality       integer 1 Common / 2 Uncommon / 3 Rare / 4 reserved
--   grug_ench          core.serialize ordered {stat=..., value=...} slots
--   grug_upgrades      integer 0..2 (reserved for temper applications)
--   grug_refined       integer boolean; every ordinary enchanted item has 1
--   grug_ilvl          per-stack item level; absent falls back to _grug_ilvl
--   grug_req_level     per-stack weapon requirement, absent without an ilvl
--   grug_base_name     uncolored, unaffixed definition name used on rebuild
--   grug_roll_window   last §6.3 source window (diagnostic/provenance)
--   grug_roll_seed     exact PcgRandom seed used for the last affix roll
--   grug_craft_roll    recipe id whose station output was already finalized
--
-- Derived consumer keys are rebuilt from grug_ench and are not authorities:
--   _grug_strength, _grug_dexterity, _grug_intelligence,
--   _grug_max_hp_percent, _grug_max_mana_percent, _grug_crit_percent,
--   _grug_dodge_percent, _grug_armor_percent, _grug_attack_speed_percent.

grug_items = {}

local QUALITY = {
	[1] = {name = "Common", color = "#FFFFFF"},
	[2] = {name = "Uncommon", color = "#4A90FF"},
	[3] = {name = "Rare", color = "#FFD700"},
	[4] = {name = "Unique", color = "#FF8000"},
}

local AFFIX = {
	str = {label = "Strength", short = "Str", prefix = "Heavy",
		suffix = "of the Bear", decimals = 0},
	dex = {label = "Dexterity", short = "Dex", prefix = "Quick",
		suffix = "of the Fox", decimals = 0},
	int = {label = "Intelligence", short = "Int", prefix = "Clever",
		suffix = "of the Owl", decimals = 0},
	max_hp_percent = {label = "maximum HP", short = "Max HP",
		prefix = "Stout", suffix = "of the Ox", decimals = 0, percent = true},
	max_mana_percent = {label = "maximum Mana", short = "Max Mana",
		prefix = "Attuned", suffix = "of the Raven", decimals = 0,
		percent = true},
	crit_percent = {label = "Crit", short = "Crit", prefix = "Lucky",
		suffix = "of the Eagle", decimals = 1, percent = true},
	attack_speed_percent = {label = "attack speed", short = "Attack speed",
		prefix = "Swift", suffix = "of the Hornet", decimals = 0,
		percent = true},
	dodge_percent = {label = "Dodge", short = "Dodge", prefix = "Elusive",
		suffix = "of the Cat", decimals = 1, percent = true},
	armor_percent = {label = "Armor", short = "Armor", prefix = "Stalwart",
		suffix = "of the Tortoise", decimals = 0, percent = true},
}

local POOLS = {
	melee_weapon = {"str", "dex", "attack_speed_percent", "crit_percent",
		"max_hp_percent"},
	caster_weapon = {"int", "max_mana_percent", "crit_percent",
		"max_hp_percent"},
	metal_armor = {"str", "max_hp_percent", "armor_percent", "dodge_percent"},
	leather_armor = {"dex", "max_hp_percent", "crit_percent", "dodge_percent"},
	cloth_armor = {"int", "max_mana_percent", "max_hp_percent", "crit_percent"},
	trinket_prefix = {"str", "int", "dex"},
	trinket_suffix = {"max_hp_percent", "max_mana_percent", "crit_percent"},
}

local BANDS = {
	{maximum = 15, values = {
		attribute = {1, 3}, pool = {1, 2}, chance = {0.5, 1.0},
		attack_speed = {3, 6}, armor = {1, 2},
	}},
	{maximum = 30, values = {
		attribute = {2, 5}, pool = {2, 3}, chance = {0.5, 1.5},
		attack_speed = {4, 8}, armor = {1, 3},
	}},
	{maximum = 45, values = {
		attribute = {4, 8}, pool = {3, 4}, chance = {1.0, 2.0},
		attack_speed = {6, 12}, armor = {2, 4},
	}},
	{maximum = 75, values = {
		attribute = {6, 12}, pool = {4, 5}, chance = {1.5, 3.0},
		attack_speed = {8, 16}, armor = {3, 6},
	}},
}

local WINDOWS = {
	world = {0.00, 0.60},
	["crafted-fine"] = {0.30, 0.80},
	elite = {0.30, 0.90},
	rare = {0.50, 1.00},
	["crafted-masterwork"] = {0.60, 1.00},
	boss = {0.80, 1.00},
}

-- Percentages are independent. The named-rare Uncommon and Rare rows are
-- intentionally additive, not an upgrade ladder.
grug_items.DROP_CHANCES = {
	normal = {uncommon = 3, rare = 0, window = "world"},
	elite = {uncommon = 20, rare = 3, window = "elite"},
	rare = {uncommon = 100, rare = 25, window = "rare"},
	boss = {uncommon = 0, rare = 100, window = "boss"},
}

-- §6.4 is an exact source table: the apparent "chance" of each listed result
-- is 100%. Affix counts are decided separately by mastery or a crafterless
-- 60/40 (Uncommon) / 70/30 (Rare) roll.
grug_items.CRAFTED_QUALITY = {
	base = {quality = 1, refined = false, chance = 100},
	refinement = {quality = 1, refined = true, chance = 100},
	fine = {quality = 2, refined = true, chance = 100,
		window = "crafted-fine", minimum = 1, maximum = 2},
	masterwork = {quality = 3, refined = true, chance = 100,
		window = "crafted-masterwork", minimum = 3, maximum = 4},
}

grug_items.QUALITY = QUALITY
grug_items.AFFIXES = AFFIX
grug_items.POOLS = POOLS
grug_items.BANDS = BANDS
grug_items.WINDOWS = WINDOWS

local DERIVED_KEYS = {
	"_grug_strength", "_grug_dexterity", "_grug_intelligence",
	"_grug_max_hp_percent", "_grug_max_mana_percent", "_grug_crit_percent",
	"_grug_dodge_percent", "_grug_armor_percent",
	"_grug_attack_speed_percent",
}

local STAT_META = {
	str = "_grug_strength",
	dex = "_grug_dexterity",
	int = "_grug_intelligence",
	max_hp_percent = "_grug_max_hp_percent",
	max_mana_percent = "_grug_max_mana_percent",
	crit_percent = "_grug_crit_percent",
	dodge_percent = "_grug_dodge_percent",
	armor_percent = "_grug_armor_percent",
	attack_speed_percent = "_grug_attack_speed_percent",
}

local roll_serial = 0

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function first_line(text)
	return (tostring(text or ""):gsub("\n.*", ""))
end

local function copy_table(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in pairs(value) do out[key] = copy_table(child) end
	return out
end

local function string_hash(text)
	local value = 5381
	for index = 1, #text do
		value = (value * 33 + text:byte(index)) % 2147483647
	end
	return value
end

local function automatic_seed(salt)
	roll_serial = (roll_serial + 1) % 1000000
	local clock = type(core.get_us_time) == "function" and core.get_us_time()
		or ((type(core.get_gametime) == "function" and core.get_gametime() or 0)
			* 1000000)
	return (math.floor(clock % 2147483647) + string_hash(salt or "")
		+ roll_serial * 7919) % 2147483647
end

local function rng_for(seed, salt)
	seed = tonumber(seed)
	if not seed then seed = automatic_seed(salt) end
	seed = math.floor(math.abs(seed)) % 2147483647
	return PcgRandom(seed), seed
end

local function random_fraction(rng)
	return rng:next(0, 1000000) / 1000000
end

local function random_chance(rng, percent)
	if percent <= 0 then return false end
	if percent >= 100 then return true end
	return rng:next(1, 10000) <= percent * 100
end

local function effective_ilvl(stack, supplied)
	if tonumber(supplied) then return clamp(math.floor(tonumber(supplied)), 1, 75) end
	local meta = stack:get_meta()
	local value = meta:get_int("grug_ilvl")
	if value > 0 then return clamp(value, 1, 75) end
	local def = stack:get_definition() or {}
	value = tonumber(def._grug_ilvl)
	return value and clamp(math.floor(value), 1, 75) or nil
end

local function write_item_level_meta(stack, meta, ilvl)
	meta:set_int("grug_ilvl", ilvl)
	local groups = (stack:get_definition() or {}).groups or {}
	if (groups.grug_equip_weapon or 0) > 0 then
		meta:set_int("grug_req_level", math.min(ilvl, 60))
	else
		-- The requirement is weapon-only (§6.1). Clearing this also makes a
		-- rebuilt armor/offhand stack fail closed against stale derived meta.
		meta:set_string("grug_req_level", "")
	end
end

function grug_items.effective_ilvl(stack)
	if not stack or stack:is_empty() then return nil end
	return effective_ilvl(stack)
end

local function family_for(stack)
	local def = stack:get_definition() or {}
	if type(def._grug_quality_family) == "string" then
		return def._grug_quality_family
	end
	local groups = def.groups or {}
	if (groups.grug_equip_trinket or 0) > 0 then return "trinket" end
	if (groups.grug_equip_weapon or 0) > 0 then
		if (groups.staff or 0) > 0 or (groups.wand or 0) > 0 or
				(groups.grug_caster_weapon or 0) > 0 then
			return "caster_weapon"
		end
		return "melee_weapon"
	end
	local rank = tonumber(groups.grug_armor_class)
	if rank == 3 then return "metal_armor" end
	if rank == 2 then return "leather_armor" end
	if rank == 1 then return "cloth_armor" end
	if (groups.grug_equip_offhand or 0) > 0 then return "caster_weapon" end
	return nil
end

function grug_items.family_for(stack)
	if not stack or stack:is_empty() then return nil end
	return family_for(stack)
end

local function band_for(ilvl)
	for index = 1, #BANDS do
		if ilvl <= BANDS[index].maximum then return BANDS[index], index end
	end
	return BANDS[#BANDS], #BANDS
end

local function range_for(stat, ilvl)
	local values = band_for(ilvl).values
	if stat == "str" or stat == "dex" or stat == "int" then
		return values.attribute
	elseif stat == "max_hp_percent" or stat == "max_mana_percent" then
		return values.pool
	elseif stat == "crit_percent" or stat == "dodge_percent" then
		return values.chance
	elseif stat == "attack_speed_percent" then
		return values.attack_speed
	elseif stat == "armor_percent" then
		return values.armor
	end
	error("grug_quality: unknown affix stat " .. tostring(stat), 0)
end

function grug_items.range_for(stat, ilvl)
	local range = range_for(stat, clamp(math.floor(tonumber(ilvl) or 1), 1, 75))
	return range[1], range[2]
end

local function rounded_value(stat, raw)
	local decimals = AFFIX[stat].decimals or 0
	local factor = 10 ^ decimals
	return math.floor(raw * factor + 0.5) / factor
end

local function roll_value(stat, ilvl, window, rng)
	local range = range_for(stat, ilvl)
	local source = WINDOWS[window]
	if not source then error("grug_quality: unknown roll window " .. tostring(window), 0) end
	local window_fraction = source[1] + random_fraction(rng) *
		(source[2] - source[1])
	return rounded_value(stat, range[1] + window_fraction *
		(range[2] - range[1]))
end

local function read_affixes(meta)
	local text = meta:get_string("grug_ench")
	if text == "" then return {} end
	local value = core.deserialize(text)
	if type(value) ~= "table" then return {} end
	local out, seen = {}, {}
	for index = 1, math.min(4, #value) do
		local slot = value[index]
		if type(slot) == "table" and AFFIX[slot.stat] and
				type(slot.value) == "number" and not seen[slot.stat] then
			seen[slot.stat] = true
			out[#out + 1] = {stat = slot.stat, value = slot.value}
		end
	end
	return out
end

function grug_items.get_affixes(stack)
	if not stack or stack:is_empty() then return {} end
	return read_affixes(stack:get_meta())
end

local function write_derived(meta, affixes)
	for index = 1, #DERIVED_KEYS do meta:set_string(DERIVED_KEYS[index], "") end
	local totals = {}
	for index = 1, #affixes do
		local slot = affixes[index]
		totals[slot.stat] = (totals[slot.stat] or 0) + slot.value
	end
	for stat, value in pairs(totals) do
		meta:set_string(STAT_META[stat], tostring(value))
	end
	return totals
end

local function format_number(value, decimals)
	if decimals == 1 then return string.format("%.1f", value) end
	return tostring(math.floor(value + 0.5))
end

local function suffix_tail(word)
	return word:gsub("^of the ", "")
end

local function generated_name(base_name, affixes)
	local prefixes, suffixes = {}, {}
	for index = 1, #affixes do
		local definition = AFFIX[affixes[index].stat]
		if index % 2 == 1 then
			prefixes[#prefixes + 1] = definition.prefix
		else
			suffixes[#suffixes + 1] = definition.suffix
		end
	end
	local name = (#prefixes > 0 and table.concat(prefixes, " ") .. " " or "")
		.. base_name
	if #suffixes == 1 then
		name = name .. " " .. suffixes[1]
	elseif #suffixes == 2 then
		name = name .. " of " .. suffix_tail(suffixes[1]) .. " and " ..
			suffix_tail(suffixes[2])
	end
	return name
end

local REFINEMENT_WORD = {
	melee_weapon = "Honed", caster_weapon = "Honed",
	metal_armor = "Reinforced", leather_armor = "Reinforced",
	cloth_armor = "Ornate",
}

local function ensure_base_name(stack)
	local meta = stack:get_meta()
	local name = meta:get_string("grug_base_name")
	if name ~= "" then return name end
	local def = stack:get_definition() or {}
	name = first_line(def.description)
	if name == "" then name = stack:get_name() end
	meta:set_string("grug_base_name", name)
	return name
end

local function base_lines(stack, ilvl, refined)
	if grug_gear and type(grug_gear.describe_stack_base) == "function" then
		return grug_gear.describe_stack_base(stack, ilvl, refined)
	end
	local def = stack:get_definition() or {}
	local lines = {}
	for line in tostring(def.description or ""):gmatch("[^\n]+") do
		lines[#lines + 1] = line
	end
	table.remove(lines, 1)
	return lines
end

local function affix_line(slot, player)
	local definition = AFFIX[slot.stat]
	local value = format_number(slot.value, definition.decimals)
	local extra = ""
	if player and (slot.stat == "max_hp_percent" or
			slot.stat == "max_mana_percent") and grug_classes and
			type(grug_classes.pool_percent_amount) == "function" then
		local pool = slot.stat == "max_hp_percent" and "hp" or "mana"
		extra = " (" .. grug_classes.pool_percent_amount(player, pool,
			slot.value) .. " at your level)"
	end
	return "+" .. value .. (definition.percent and "% " or " ") ..
		definition.label .. extra
end

function grug_items.regenerate_description(stack, player)
	if not stack or stack:is_empty() then return false end
	local family = family_for(stack)
	if not family then return false end
	local meta = stack:get_meta()
	local affixes = read_affixes(meta)
	local refined = family ~= "trinket" and meta:get_int("grug_refined") == 1
	local ilvl = effective_ilvl(stack)
	local base_name = ensure_base_name(stack)
	local display_name = generated_name(base_name, affixes)
	if #affixes == 0 and refined then
		display_name = (REFINEMENT_WORD[family] or "Refined") .. " " .. base_name
	end
	local quality = meta:get_int("grug_quality")
	if quality < 1 or quality > 4 then
		quality = tonumber((stack:get_definition() or {})._grug_quality) or 1
		quality = clamp(math.floor(quality), 1, 4)
		meta:set_int("grug_quality", quality)
	end
	local lines = {core.colorize(QUALITY[quality].color, display_name)}
	local inherited = base_lines(stack, ilvl, refined)
	for index = 1, #inherited do lines[#lines + 1] = inherited[index] end
	if #affixes > 0 and refined then
		lines[#lines + 1] = core.colorize("#9aa0a6", "Refined")
	end
	for index = 1, #affixes do lines[#lines + 1] = affix_line(affixes[index], player) end
	write_derived(meta, affixes)
	local desired = table.concat(lines, "\n")
	if meta:get_string("description") == desired then return false end
	meta:set_string("description", desired)
	return true
end

local function apply_capabilities(stack, totals, refined)
	local def = stack:get_definition() or {}
	local base = def.tool_capabilities
	if type(base) ~= "table" then return end
	local caps = copy_table(base)
	local _, described = grug_gear.describe_stack_base(stack,
		effective_ilvl(stack), refined)
	local damage = described and described.damage or
		(caps.damage_groups and caps.damage_groups.fleshy)
	if type(damage) == "number" and damage > 0 and caps.damage_groups then
		caps.damage_groups.fleshy = damage
	end
	local speed = totals.attack_speed_percent or 0
	if speed > 0 and type(caps.full_punch_interval) == "number" then
		caps.full_punch_interval = caps.full_punch_interval / (1 + speed / 100)
	end
	stack:get_meta():set_tool_capabilities(caps)
end

local function rolled_count(quality, rng)
	if quality == 2 then return random_chance(rng, 60) and 1 or 2 end
	if quality == 3 then return random_chance(rng, 70) and 3 or 4 end
	return 0
end

local function choose_unique(pool, count, rng)
	local choices = {}
	for index = 1, #pool do choices[index] = pool[index] end
	for index = #choices, 2, -1 do
		local other = rng:next(1, index)
		choices[index], choices[other] = choices[other], choices[index]
	end
	local out = {}
	for index = 1, math.min(count, #choices) do out[index] = choices[index] end
	return out
end

function grug_items.roll_enchants(stack, ilvl, window, count, seed)
	if not stack or stack:is_empty() then return false, "empty item" end
	local family = family_for(stack)
	if not family then return false, "item has no quality family" end
	ilvl = effective_ilvl(stack, ilvl)
	if not ilvl then return false, "item has no item level" end
	if not WINDOWS[window] then return false, "unknown roll window" end
	local meta = stack:get_meta()
	if family ~= "trinket" and meta:get_int("grug_refined") ~= 1 then
		-- Crafterless found/vendor sources arrive pre-enchanted (§5.1), hence
		-- refined by definition. The shipped trader's three-argument `world`
		-- call is one such source. An explicit crafted count, and both crafted
		-- windows, still require an already-refined input and fail closed.
		local found_source = count == nil and
			(window == "world" or window == "elite" or window == "rare" or
				window == "boss")
		if not found_source then return false, "item is not refined" end
		meta:set_int("grug_refined", 1)
	end
	local rng, used_seed = rng_for(seed, stack:get_name() .. ":" .. window)
	local quality = meta:get_int("grug_quality")
	if quality < 1 or quality > 4 then quality = 1 end
	local stats = {}
	if family == "trinket" then
		stats[1] = POOLS.trinket_prefix[rng:next(1, #POOLS.trinket_prefix)]
		stats[2] = POOLS.trinket_suffix[rng:next(1, #POOLS.trinket_suffix)]
		if quality < 2 then quality = 2 end
	else
		local wanted = count == nil and rolled_count(quality, rng) or
			clamp(math.floor(tonumber(count) or 0), 0, 4)
		if wanted == 0 then return false, "quality has no affix budget" end
		stats = choose_unique(POOLS[family], wanted, rng)
		if #stats <= 2 then quality = 2 else quality = 3 end
	end
	local affixes = {}
	for index = 1, #stats do
		affixes[index] = {stat = stats[index],
			value = roll_value(stats[index], ilvl, window, rng)}
	end
	meta:set_int("grug_quality", quality)
	write_item_level_meta(stack, meta, ilvl)
	meta:set_string("grug_ench", core.serialize(affixes))
	meta:set_string("grug_roll_window", window)
	meta:set_int("grug_roll_seed", used_seed)
	local totals = write_derived(meta, affixes)
	apply_capabilities(stack, totals, family ~= "trinket")
	grug_items.regenerate_description(stack)
	return true, used_seed
end

function grug_items.set_refined(stack, refined)
	if not stack or stack:is_empty() or family_for(stack) == "trinket" then
		return false
	end
	local meta = stack:get_meta()
	meta:set_int("grug_refined", refined and 1 or 0)
	if not refined then
		meta:set_string("grug_ench", "")
		meta:set_int("grug_quality", 1)
	end
	local affixes = read_affixes(meta)
	local totals = write_derived(meta, affixes)
	apply_capabilities(stack, totals, refined == true)
	grug_items.regenerate_description(stack)
	return true
end

local function mastery_slots(player)
	local level = grug_xp.get_level(player)
	if level >= 46 then return 4 end
	if level >= 31 then return 3 end
	if level >= 16 then return 2 end
	return 1
end

function grug_items.apply_crafted_quality(stack, mode, player, seed)
	if not stack or stack:is_empty() or not family_for(stack) then return false end
	mode = mode or "base"
	local row = grug_items.CRAFTED_QUALITY[mode]
	if not row then return false, "unknown crafted quality" end
	local meta = stack:get_meta()
	ensure_base_name(stack)
	meta:set_int("grug_quality", row.quality)
	meta:set_int("grug_refined", row.refined and 1 or 0)
	meta:set_string("grug_ench", "")
	local ilvl = effective_ilvl(stack)
	if ilvl then
		write_item_level_meta(stack, meta, ilvl)
	end
	if row.window then
		local slots = mastery_slots(player)
		local count = mode == "fine" and math.min(2, slots) or slots
		count = clamp(count, row.minimum, row.maximum)
		return grug_items.roll_enchants(stack, ilvl, row.window, count, seed)
	end
	local totals = write_derived(meta, {})
	apply_capabilities(stack, totals, row.refined)
	grug_items.regenerate_description(stack, player)
	return true
end

-- One entry point for both grug_jobs output seams. Catalogs may attach
-- `quality_mode` (base, refinement, fine or masterwork) to their retained recipe
-- object; an ordinary recipe defaults to the §6.4 Common base result.
function grug_items.crafted_output(stack, player, recipe, seed)
	local mode = recipe and (recipe.quality_mode or recipe._grug_quality_mode)
	local marker = recipe and recipe.id or ""
	local meta = stack and not stack:is_empty() and stack:get_meta() or nil
	if meta and marker ~= "" and meta:get_string("grug_craft_roll") == marker then
		return false, "already rolled"
	end
	local changed, detail = grug_items.apply_crafted_quality(stack,
		mode or "base", player, seed)
	if changed and meta and marker ~= "" then
		meta:set_string("grug_craft_roll", marker)
	end
	if changed and grug_gear and
			type(grug_gear.initialize_weapon_tooltip) == "function" then
		grug_gear.initialize_weapon_tooltip(stack, player)
	end
	return changed, detail
end

local function gear_stack(itemname, ilvl, quality, window, rng, seed)
	local stack = ItemStack(itemname)
	local meta = stack:get_meta()
	meta:set_int("grug_quality", quality)
	meta:set_int("grug_refined", 1)
	write_item_level_meta(stack, meta, ilvl)
	-- A child seed keeps each independently dropped stack reproducible without
	-- sharing mutable RNG state with its affix sequence.
	local child_seed = seed + rng:next(1, 1000000)
	grug_items.roll_enchants(stack, ilvl, window, nil, child_seed)
	return stack
end

function grug_items.roll_mob_gear(self, seed)
	local tier = self and self._grug_tier or "normal"
	if tier == "critter" then return {} end
	local source = (self and self._grug_royal_king) and "boss" or tier
	if not grug_items.DROP_CHANCES[source] then source = "normal" end
	local row = grug_items.DROP_CHANCES[source]
	local level = clamp(math.floor(tonumber(self and self._grug_level) or 1), 1, 60)
	local material_tier = clamp(math.floor((level - 1) / 10) + 1, 1, 6)
	local catalog = grug_gear.catalog[material_tier]
	local items = catalog and catalog.all or {}
	if #items == 0 then return {} end
	local rng, used_seed = rng_for(seed,
		(self and self.name or "mob") .. ":" .. source .. ":" .. level)
	local out = {}
	local function add(quality)
		local itemname = items[rng:next(1, #items)]
		out[#out + 1] = gear_stack(itemname, level, quality, row.window, rng,
			used_seed + #out * 104729)
	end
	if random_chance(rng, row.uncommon) then add(2) end
	if random_chance(rng, row.rare) then add(3) end
	return out, used_seed
end

-- The existing grug_mobs death hook is reached only after its shared
-- player-tag/enemy-kill predicate. It drops concrete ItemStacks so their meta
-- survives, including on bosses whose ordinary string-drop list is empty.
grug_mobs.register_kill_loot_hook(function(self, tagger_name)
	local rolled = grug_items.roll_mob_gear(self)
	local pos = self.object and self.object:get_pos()
	if not pos then return end
	for index = 1, #rolled do
		local object = core.add_item(pos, rolled[index])
		if object then
			local rng = rng_for(automatic_seed(tagger_name .. ":drop"), tagger_name)
			object:set_velocity({x = random_fraction(rng) - 0.5, y = 5,
				z = random_fraction(rng) - 0.5})
		end
	end
end)

-- Affix aggregates that do not already have a native per-stack consumer.
-- Cache invalidation wraps the one equipment write seam before its deliberately
-- first grug_classes consumer runs, so max-pool clamping sees current rolls.
local aggregate_cache = {}

local function equipment_totals(player)
	local name = player:get_player_name()
	local cached = aggregate_cache[name]
	if cached then return cached end
	local totals = {str = 0, dex = 0, int = 0, crit_percent = 0,
		dodge_percent = 0, armor_percent = 0, refined_armor = 0}
	local inventory = player:get_inventory()
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		local stack = inventory:get_stack(slot.list, 1)
		if stack and not stack:is_empty() then
			local meta = stack:get_meta()
			local affixes = read_affixes(meta)
			for index = 1, #affixes do
				local affix = affixes[index]
				totals[affix.stat] = (totals[affix.stat] or 0) + affix.value
			end
			local def = stack:get_definition() or {}
			local armor = tonumber(def._grug_armor) or 0
			if armor > 0 and meta:get_int("grug_refined") == 1 then
				local _, described = grug_gear.describe_stack_base(stack,
					effective_ilvl(stack), true)
				local effective = described and described.armor or
					math.floor(armor * 1.15 + 0.5)
				totals.refined_armor = totals.refined_armor + effective - armor
			end
		end
	end
	aggregate_cache[name] = totals
	return totals
end

local original_equipment_changed = grug_inventory.equipment_changed
grug_inventory.equipment_changed = function(player, listname)
	if player and player.get_player_name then
		aggregate_cache[player:get_player_name()] = nil
	end
	return original_equipment_changed(player, listname)
end
grug_inventory.invalidate_armor = grug_inventory.equipment_changed

-- Dropped gear may carry an off-anchor ilvl above its registered material
-- item's catalog anchor. Preserve the shared gate for definition-only items,
-- but let the concrete stack requirement win when this mod wrote one.
local original_can_use_item_level = grug_core.can_use_item_level
grug_core.can_use_item_level = function(player, item)
	if type(item) ~= "string" and item and item.get_meta then
		local required = item:get_meta():get_int("grug_req_level")
		if required > 0 then
			local current = grug_core.get_player_level(player)
			return current >= required, required, current
		end
	end
	return original_can_use_item_level(player, item)
end

local original_attributes = grug_classes.get_attributes
grug_classes.get_attributes = function(player)
	local base = original_attributes(player)
	local totals = equipment_totals(player)
	base.str = base.str + (totals.str or 0)
	base.dex = base.dex + (totals.dex or 0)
	base.int = base.int + (totals.int or 0)
	return base
end

local original_crit_raw = grug_classes.get_crit_chance_raw
grug_classes.get_crit_chance_raw = function(player)
	return original_crit_raw(player) +
		(equipment_totals(player).crit_percent or 0) / 100
end

local original_dodge_raw = grug_classes.get_dodge_chance_raw
grug_classes.get_dodge_chance_raw = function(player)
	return original_dodge_raw(player) +
		(equipment_totals(player).dodge_percent or 0) / 100
end

local function raw_armor(player)
	local totals = equipment_totals(player)
	return grug_inventory.get_equipped_armor(player) + totals.refined_armor +
		(totals.armor_percent or 0) +
		grug_classes.get_talent_bonus(player, "armor_percent_add") +
		grug_core.status_modifier_sum(player, "armor")
end

grug_core.get_armor_percent_raw = raw_armor
grug_core.get_armor_percent = function(player)
	return math.min(60, raw_armor(player))
end

core.register_on_leaveplayer(function(player)
	aggregate_cache[player:get_player_name()] = nil
end)

core.log("action", "[grug_quality] deterministic PcgRandom quality rolls enabled")
