-- Per-stack equipment quality and affixes (items_crafting.md §§5.1, 6, 6b).
--
-- This mod deliberately publishes the historical `grug_items` API name: the
-- shipped trader probes that one global before offering rolled Uncommons.
-- The mod itself is named grug_quality so its ownership remains explicit.
--
-- Shared item-meta keys (all belong to one concrete ItemStack):
--   grug_quality       integer 1 Common / 2 Uncommon / 3 Rare / 4 reserved
--   grug_ench          ordered {channel, stat, tier, value} affixes; the value
--                      is the enchant rule at the item level and tier
--                      (item_tiers.md §1.1), rewritten whenever either changes
--   grug_ilvl          per-stack item level; absent falls back to _grug_ilvl
--   grug_crowned       1 once a Fallen Crown was applied (crown_item)
--   grug_req_level     per-stack equip requirement, absent without an ilvl
--   grug_base_name     uncolored, unaffixed definition name used on rebuild
--   grug_roll_seed     exact PcgRandom seed used for the last affix roll
--   grug_trinket_special authored passive text preserved across regeneration
--
-- Derived consumer keys are rebuilt from grug_ench and are not authorities:
--   _grug_strength, _grug_dexterity, _grug_intelligence,
--   _grug_max_hp_percent, _grug_max_mana_percent, _grug_crit_percent,
--   _grug_dodge_percent, _grug_armor_rating, _grug_attack_speed_percent.

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
		prefix = "Stout", suffix = "of the Ox", decimals = 1, percent = true},
	max_mana_percent = {label = "maximum Mana", short = "Max Mana",
		prefix = "Attuned", suffix = "of the Raven", decimals = 1,
		percent = true},
	crit_percent = {label = "Crit", short = "Crit", prefix = "Lucky",
		suffix = "of the Eagle", decimals = 1, percent = true},
	attack_speed_percent = {label = "attack speed", short = "Attack speed",
		prefix = "Swift", suffix = "of the Hornet", decimals = 1,
		percent = true},
	dodge_percent = {label = "Dodge", short = "Dodge", prefix = "Elusive",
		suffix = "of the Cat", decimals = 1, percent = true},
	armor_rating = {label = "armor rating", short = "Armor", prefix = "Stalwart",
		suffix = "of the Tortoise", decimals = 1},
}

local POOLS = {
	greataxe = {"str", "attack_speed_percent", "crit_percent", "max_hp_percent"},
	sword = {"str", "dex", "attack_speed_percent", "crit_percent",
		"max_hp_percent", "max_mana_percent"},
	dagger = {"str", "dex", "int", "attack_speed_percent", "crit_percent",
		"max_hp_percent", "max_mana_percent"},
	bow = {"dex", "crit_percent", "attack_speed_percent", "max_hp_percent",
		"max_mana_percent"},
	caster_weapon = {"int", "max_mana_percent", "crit_percent",
		"max_hp_percent"},
	shield = {"str", "dex", "max_hp_percent", "armor_rating"},
	spellbook = {"int", "max_mana_percent", "crit_percent", "max_hp_percent"},
	metal_armor = {"str", "max_hp_percent", "armor_rating"},
	leather_armor = {"dex", "max_hp_percent", "max_mana_percent",
		"crit_percent", "dodge_percent"},
	cloth_armor = {"int", "max_mana_percent", "max_hp_percent", "crit_percent"},
	trinket_prefix = {"str", "int", "dex"},
	trinket_suffix = {"max_hp_percent", "max_mana_percent", "crit_percent"},
}

-- Gear drops per kill (round33-plan.md §2.1), percent of a white, a blue and
-- a gold item. One roll decides, so a kill drops at most one item. Named
-- rares (tier "rare"), zone leaders and war-camp captains (§2.9a, whatever
-- their tier) share the elite row; a critter drops no gear.
local ELITE_DROPS = {white = 10, blue = 10, gold = 5}
grug_items.DROP_CHANCES = {
	normal = {white = 5, blue = 2, gold = 1},
	elite = ELITE_DROPS,
	rare = ELITE_DROPS,
}

-- Bosses: the Kings and the dragons through their reward ledger, a fortress
-- General on every enemy player's kill of him (Round 31: he has no ledger).
-- Always `count` items, each gold at `gold` percent, else blue, at a fixed
-- item level. Their other loot (Fallen Crown, Scaled Hide, war trophies)
-- comes from their own code.
grug_items.BOSS_DROPS = {count = 2, gold = 50,
	ilvl = {king = 65, general = 65, dragon = 70}}

-- A bag from any mob, independent of the gear roll: `chance` percent per
-- kill, the size by the mob's level.
grug_items.BAG_DROPS = {chance = 0.1, sizes = {
	{maximum = 15, item = "grug_inventory:bag_small"},
	{maximum = 30, item = "grug_inventory:bag_medium"},
	{maximum = 45, item = "grug_inventory:bag_large"},
	{item = "grug_inventory:bag_great"},
}}

-- The enchant tier of an item level (round33-plan.md §2.3): 1-10 is T1 ...
-- 51-60 T6; above 60 (boss drops) T7.
function grug_items.enchant_tier(ilvl)
	ilvl = math.floor(tonumber(ilvl) or 1)
	if ilvl > 60 then return 7 end
	return math.max(1, math.ceil(ilvl / 10))
end

-- The enchant value rule (item_tiers.md §1.1): value = a + b L + c L^2 with
-- L = clamp(min(item level, 10 x tier), 1, 70), rounded to the stat's
-- decimals and at least `minimum`. An enchant grows with its item's level up
-- to its tier's top; T7 (boss drops, the crown) reaches item level 70.
local CURVES = {
	str = {a = 0.8, b = 0.15, c = 0.0025, minimum = 1},
	dex = {a = 0.8, b = 0.13, c = 0.0019, minimum = 1},
	int = {a = 0.8, b = 0.15, c = 0.0025, minimum = 1},
	crit_percent = {a = 1.7, b = 0.044, c = 0, minimum = 0},
	attack_speed_percent = {a = 1.6, b = 0.04, c = 0, minimum = 0},
	max_hp_percent = {a = 1.6, b = 0.04, c = 0, minimum = 0},
	max_mana_percent = {a = 2.2, b = 0.03, c = 0, minimum = 0},
	dodge_percent = {a = 1.5, b = 0.032, c = 0, minimum = 0},
	armor_rating = {a = 0, b = 0.08, c = 0, minimum = 0.5},
}
grug_items.ENCHANT_CURVES = CURVES

function grug_items.enchant_value(stat, ilvl, tier)
	local curve = CURVES[stat]
	if not curve then return nil end
	local level = math.max(1, math.min(math.floor(tonumber(ilvl) or 1),
		10 * (tonumber(tier) or 1), 70))
	local raw = curve.a + curve.b * level + curve.c * level * level
	local factor = AFFIX[stat].decimals == 1 and 10 or 1
	return math.max(curve.minimum, math.floor(raw * factor + 0.5) / factor)
end

-- The value an enchant of `tier` reaches at its tier's top (the station's
-- "up to" label).
function grug_items.enchant_top_value(stat, tier)
	return grug_items.enchant_value(stat, 10 * tier, tier)
end

grug_items.QUALITY = QUALITY
grug_items.AFFIXES = AFFIX
grug_items.POOLS = POOLS

-- Trinket identity specials do not change the two channel-specific pools.
function grug_items.enchant_pool(family, channel)
	return POOLS[family == "trinket" and ("trinket_" .. channel) or family]
end

local DERIVED_KEYS = {
	"_grug_strength", "_grug_dexterity", "_grug_intelligence",
	"_grug_max_hp_percent", "_grug_max_mana_percent", "_grug_crit_percent",
	"_grug_dodge_percent", "_grug_armor_rating",
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
	armor_rating = "_grug_armor_rating",
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

-- Every equipment family carries the requirement min(ilvl, 60), or its
-- definition's up to the definition's own item level, so a first-bracket
-- item stays level 1 up to its item level 3 (round33-plan.md §2.2).
-- Callers pass equipment stacks only (family_for is not "tool").
local function write_item_level_meta(stack, meta, ilvl)
	meta:set_int("grug_ilvl", ilvl)
	local definition = stack:get_definition() or {}
	local authored = ilvl <= (tonumber(definition._grug_ilvl) or 0) and
		tonumber(definition._grug_req_level) or nil
	meta:set_int("grug_req_level", authored or math.min(ilvl, 60))
end

-- A stack's equip requirement: its own, else its definition's; nil for none.
local function required_level(stack)
	local value = stack:get_meta():get_int("grug_req_level")
	if value > 0 then return value end
	return tonumber((stack:get_definition() or {})._grug_req_level)
end

function grug_items.effective_ilvl(stack)
	if not stack or stack:is_empty() then return nil end
	return effective_ilvl(stack)
end

local function family_for(stack)
	local def = stack:get_definition() or {}
	if ((def.groups or {}).grug_gathering_tool or 0) > 0 then return "tool" end
	if type(def._grug_quality_family) == "string" then
		return def._grug_quality_family
	end
	local groups = def.groups or {}
	if (groups.grug_equip_trinket or 0) > 0 then return "trinket" end
	if (groups.grug_equip_weapon or 0) > 0 then
		if (groups.grug_bow or 0) > 0 then return "bow" end
		if (groups.staff or 0) > 0 or (groups.wand or 0) > 0 or
				(groups.grug_caster_weapon or 0) > 0 then
			return "caster_weapon"
		end
		return grug_gear.weapon_family(stack)
	end
	local rank = tonumber(groups.grug_armor_class)
	if rank == 3 then return "metal_armor" end
	if rank == 2 then return "leather_armor" end
	if rank == 1 then return "cloth_armor" end
	if (groups.grug_shield or 0) > 0 then return "shield" end
	if (groups.grug_spellbook or 0) > 0 then return "spellbook" end
	if (groups.pickaxe or 0) > 0 or (groups.shovel or 0) > 0 or
			(groups.axe or 0) > 0 or (groups.hoe or 0) > 0 then
		return "tool"
	end
	return nil
end

function grug_items.family_for(stack)
	if not stack or stack:is_empty() then return nil end
	return family_for(stack)
end

-- One found enchant (a drop, a boss reward, a vendor's rolled item): the
-- item's tier, so it is worth exactly the rule at its item level.
local function found_affix(channel, stat, ilvl)
	return {channel = channel, stat = stat, tier = grug_items.enchant_tier(ilvl)}
end

local function read_affixes(meta)
	local text = meta:get_string("grug_ench")
	if text == "" then return {} end
	local value = core.deserialize(text)
	if type(value) ~= "table" then return {} end
	local out, seen, channels = {}, {}, {}
	for index = 1, math.min(2, #value) do
		local slot = value[index]
		if type(slot) == "table" and AFFIX[slot.stat] and
				type(slot.value) == "number" and not seen[slot.stat] and
				type(slot.tier) == "number" and slot.tier % 1 == 0 and
				slot.tier >= 1 and slot.tier <= 7 and
				(slot.channel == "prefix" or slot.channel == "suffix") and
				not channels[slot.channel] then
			seen[slot.stat] = true
			channels[slot.channel] = true
			out[#out + 1] = {channel = slot.channel, stat = slot.stat,
				value = slot.value, tier = slot.tier}
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

-- An enchant value as the tooltip shows it (whole attributes, one decimal
-- for the percentages and armor).
function grug_items.format_enchant_value(stat, value)
	return format_number(value, AFFIX[stat].decimals)
end

local function suffix_tail(word)
	return word:gsub("^of the ", "")
end

local function generated_name(base_name, affixes)
	local prefixes, suffixes = {}, {}
	for index = 1, #affixes do
		local definition = AFFIX[affixes[index].stat]
		if affixes[index].channel == "prefix" then
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

local function base_lines(stack, ilvl)
	if grug_gear and type(grug_gear.describe_stack_base) == "function" then
		return grug_gear.describe_stack_base(stack, ilvl)
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
		extra = grug_classes.pool_percent_amount(player, pool, slot.value) ..
			" at your level"
	end
	return "+" .. value .. (definition.percent and "% " or " ") ..
		definition.label .. " (T" .. slot.tier .. (extra ~= "" and "; " .. extra or "") .. ")"
end

-- The enchant colours (round31-plan.md §2.2): the per-stack inventory image
-- of an item with affixes carries the prefix and suffix colour layers
-- (grug_gear.enchant_image); without affixes the key stays empty, so a plain
-- stack has no image meta at all. The engine draws the wielded item from the
-- same image, and so do the visible weapon entity (grug_visuals) and the
-- ability items (grug_abilities). A broken stack is cracked over this image by
-- grug_repair.refresh_appearance, which regenerate_description runs next.
-- Returns true when the key changed.
local function refresh_enchant_image(stack, affixes)
	local def = stack:get_definition()
	if not grug_gear.has_enchant_masks(def) then return false end
	local prefix, suffix
	for index = 1, #affixes do
		if affixes[index].channel == "prefix" then
			prefix = affixes[index].stat
		else
			suffix = affixes[index].stat
		end
	end
	local desired = ""
	if prefix or suffix then
		desired = grug_gear.enchant_image(def.inventory_image, prefix, suffix)
	end
	local meta = stack:get_meta()
	local current = meta:get_string("inventory_image")
	if current == desired then return false end
	-- A broken stack shows grug_repair's cracked rendering and keeps the
	-- uncracked image as its saved base: unchanged when that base is ours.
	local drawn = meta:get_string("_grug_broken_drawn_inventory_image")
	if drawn ~= "" and current == drawn and
			meta:get_string("_grug_broken_base_inventory_image") == desired then
		return false
	end
	meta:set_string("inventory_image", desired)
	return true
end

grug_items.refresh_enchant_image = refresh_enchant_image

-- The colour legend of the enchanting stations (round31-plan.md §2.2.2):
-- formspec elements for a 4.2 x 1.3 area at (x, y), the nine stats in three
-- rows with their swatches. Short words: the area ends before the station's
-- repair button.
local LEGEND_WORD = {str = "Str", dex = "Dex", int = "Int", max_hp_percent = "HP",
	max_mana_percent = "Mana", crit_percent = "Crit", attack_speed_percent = "Speed",
	dodge_percent = "Dodge", armor_rating = "Armor"}

function grug_items.enchant_legend_formspec(x, y)
	local out = {("label[%.2f,%.2f;%s]"):format(x, y,
		core.formspec_escape("Prefix / suffix colours"))}
	for index, stat in ipairs(grug_gear.ENCHANT_ORDER) do
		local column, row = (index - 1) % 3, math.floor((index - 1) / 3)
		local cx, cy = x + column * 1.35, y + 0.3 + row * 0.36
		out[#out + 1] = ("box[%.2f,%.2f;0.24,0.24;%s]"):format(cx, cy,
			grug_gear.ENCHANT_COLORS[stat])
		out[#out + 1] = ("label[%.2f,%.2f;%s]"):format(cx + 0.32, cy + 0.12,
			LEGEND_WORD[stat])
	end
	return table.concat(out)
end

function grug_items.regenerate_description(stack, player)
	if not stack or stack:is_empty() then return false end
	local family = family_for(stack)
	if not family then return false end
	local meta = stack:get_meta()
	local affixes = read_affixes(meta)
	local image_changed = refresh_enchant_image(stack, affixes)
	local ilvl = effective_ilvl(stack)
	local base_name = ensure_base_name(stack)
	local display_name = generated_name(base_name, affixes)
	local quality = meta:get_int("grug_quality")
	if quality < 1 or quality > 4 then
		quality = tonumber((stack:get_definition() or {})._grug_quality) or 1
		quality = clamp(math.floor(quality), 1, 4)
		meta:set_int("grug_quality", quality)
	end
	local lines = {core.colorize(QUALITY[quality].color, display_name)}
	local inherited = base_lines(stack, ilvl)
	for index = 1, #inherited do lines[#lines + 1] = inherited[index] end
	for index = 1, #affixes do lines[#lines + 1] = affix_line(affixes[index], player) end
	if meta:get_int("grug_crowned") == 1 then lines[#lines + 1] = "Crowned" end
	lines[#lines + 1] = grug_gear.usable_by(stack)
	local requirement = family ~= "tool" and
		grug_gear.requirement_line(required_level(stack))
	if requirement then lines[#lines + 1] = requirement end
	local repair = rawget(_G, "grug_repair")
	if repair then
		local durability = repair.durability_line(stack)
		if durability then lines[#lines + 1] = durability end
		repair.refresh_appearance(stack)
	end
	write_derived(meta, affixes)
	local desired = table.concat(lines, "\n")
	if meta:get_string("description") == desired then return image_changed end
	meta:set_string("description", desired)
	return true
end

local function apply_capabilities(stack, totals)
	local def = stack:get_definition() or {}
	local base = def.tool_capabilities
	if type(base) ~= "table" then return end
	local caps = copy_table(base)
	local _, described = grug_gear.describe_stack_base(stack,
		effective_ilvl(stack))
	local damage = described and described.damage or
		(caps.damage_groups and caps.damage_groups.fleshy)
	if type(damage) == "number" and damage > 0 and caps.damage_groups then
		caps.damage_groups.fleshy = damage
	end
	local speed = totals.attack_speed_percent or 0
	if speed > 0 and type(caps.full_punch_interval) == "number" then
		caps.full_punch_interval = caps.full_punch_interval / (1 + speed / 100)
	end
	local meta = stack:get_meta()
	if stack:get_wear() >= 65535 then
		-- Enchanting never repairs an item. Keep the new usable capabilities
		-- for the existing repair service while the concrete stack stays broken.
		meta:set_string("_grug_repair_caps", core.serialize(caps))
		meta:set_tool_capabilities({full_punch_interval = 1.4,
			damage_groups = {fleshy = 0}, groupcaps = {}, punch_attack_uses = 0})
	else
		meta:set_tool_capabilities(caps)
	end
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

-- Every write of a stack's enchants comes here: each value is the rule at
-- the stack's item level and the enchant's tier (item_tiers.md §1.1). Values
-- are derived on write, not on read: only this mod writes an item level or
-- an enchant tier (rolls, enchants, upgrades, the crown), while tooltips and
-- the equipment totals read far more often. Quality is the enchant count
-- plus one (Common 1, Uncommon 2, Rare 3).
local function store_affixes(stack, affixes, player)
	local meta = stack:get_meta()
	local ilvl = effective_ilvl(stack) or 1
	for index = 1, #affixes do
		local affix = affixes[index]
		affix.value = grug_items.enchant_value(affix.stat, ilvl, affix.tier)
	end
	meta:set_string("grug_ench", #affixes > 0 and core.serialize(affixes) or "")
	meta:set_int("grug_quality", #affixes + 1)
	apply_capabilities(stack, write_derived(meta, affixes))
	grug_items.regenerate_description(stack, player)
end

-- A found item at item level `ilvl` with `count` (0, 1 or 2) random enchants
-- of the item level's tier; without a count, the stack's preset quality
-- decides it. Zero makes a plain Common at that item level. A trinket's
-- prefix and suffix draw from their own pools, so its single enchant takes
-- either channel at even odds.
function grug_items.roll_enchants(stack, ilvl, count, seed)
	if not stack or stack:is_empty() then return false, "empty item" end
	local family = family_for(stack)
	if not family or (family ~= "trinket" and not POOLS[family]) then
		return false, "item has no enchant pool"
	end
	ilvl = effective_ilvl(stack, ilvl)
	if not ilvl then return false, "item has no item level" end
	local meta = stack:get_meta()
	local rng, used_seed = rng_for(seed, stack:get_name())
	local wanted = count == nil and meta:get_int("grug_quality") - 1 or count
	wanted = clamp(math.floor(tonumber(wanted) or 0), 0, 2)
	local affixes = {}
	if family == "trinket" then
		local channels = wanted == 2 and {"prefix", "suffix"} or
			(wanted == 1 and {rng:next(1, 2) == 1 and "prefix" or "suffix"} or {})
		for index, channel in ipairs(channels) do
			local pool = POOLS["trinket_" .. channel]
			affixes[index] = found_affix(channel, pool[rng:next(1, #pool)], ilvl)
		end
	else
		local stats = choose_unique(POOLS[family], wanted, rng)
		for index = 1, #stats do
			affixes[index] = found_affix(index == 1 and "prefix" or "suffix",
				stats[index], ilvl)
		end
	end
	write_item_level_meta(stack, meta, ilvl)
	meta:set_int("grug_roll_seed", used_seed)
	store_affixes(stack, affixes)
	return true, used_seed
end

local function material_tier(stack)
	return tonumber((stack:get_definition() or {})._grug_bracket)
end

local function enchant_name(affix)
	return "T" .. affix.tier .. " " .. AFFIX[affix.stat].label
end

-- The one item a station operation works on (`accepts(family)`), the
-- consumption of every listed material, and no unrelated stack.
local function gather_inputs(recipe, inputs, accepts, noun)
	local source, source_index
	for index = 1, #inputs do
		local stack = inputs[index]
		if stack and not stack:is_empty() and accepts(family_for(stack)) then
			if source or stack:get_count() ~= 1 then
				return nil, "Insert exactly one item to " .. noun .. "."
			end
			source, source_index = ItemStack(stack), index
		end
	end
	if not source then return nil, "Insert an item of the selected family." end
	local consume = {[source_index] = 1}
	for _, token in ipairs(recipe.flat_inputs) do
		local found
		for index = 1, #inputs do
			local stack = inputs[index]
			if index ~= source_index and stack and stack:get_name() == token and
					stack:get_count() > (consume[index] or 0) then
				consume[index] = (consume[index] or 0) + 1
				found = true
				break
			end
		end
		if not found then return nil, "Insert the required " .. noun .. " materials." end
	end
	-- Refuse unrelated stacks so the selected operation describes the full grid.
	for index = 1, #inputs do
		if inputs[index] and not inputs[index]:is_empty() and not consume[index] then
			return nil, "Remove unrelated items from the station."
		end
	end
	return source, consume
end

-- An enchant writes the recipe's tier into its channel. Overwriting stays
-- allowed; `warning` names a replaced enchant of a higher tier (a crowned or
-- boss item's T7, a better found one), whose cap the new one never reaches.
local function enchant_plan(recipe, inputs, player)
	local source, consume = gather_inputs(recipe, inputs, function(family)
		return family == recipe.family
	end, "enchant")
	if not source then return nil, consume end
	local tier = material_tier(source)
	if not tier or tier < recipe.tier then
		return nil, "The item tier must be at least the enchantment tier."
	end
	local current = read_affixes(source:get_meta())
	local channels = {}
	for index = 1, #current do
		local affix = current[index]
		if affix.channel ~= recipe.enchant_channel and affix.stat == recipe.enchant_stat then
			return nil, "The other channel already uses this stat."
		end
		if affix.channel == recipe.enchant_channel and affix.stat == recipe.enchant_stat and
				affix.tier == recipe.tier then
			return nil, "This enchantment would not change the item."
		end
		channels[affix.channel] = affix
	end
	local replaced = channels[recipe.enchant_channel]
	local added = {channel = recipe.enchant_channel, stat = recipe.enchant_stat,
		tier = recipe.tier}
	channels[recipe.enchant_channel] = added
	local affixes = {}
	for _, channel in ipairs({"prefix", "suffix"}) do
		if channels[channel] then affixes[#affixes + 1] = channels[channel] end
	end
	store_affixes(source, affixes, player)
	local warning
	if replaced and replaced.tier > recipe.tier then
		warning = "Replaces " .. enchant_name(replaced) .. " with " ..
			enchant_name(added) .. "."
	end
	return {output = source, consume = consume, recipe = recipe, warning = warning}
end

-- A profession upgrade (item_tiers.md §3.1): an item of the recipe's material
-- tier T below item level 10 T rises to 10 T, never lower; its enchants keep
-- stat, channel and tier and follow the new item level.
local function upgrade_plan(recipe, inputs, player)
	local source, consume = gather_inputs(recipe, inputs, function(family)
		return recipe.family_set[family] == true
	end, "upgrade")
	if not source then return nil, consume end
	if material_tier(source) ~= recipe.tier then
		return nil, "This upgrade takes tier " .. recipe.tier .. " items."
	end
	local target = 10 * recipe.tier
	if (effective_ilvl(source) or target) >= target then
		return nil, "The item is already at item level " .. target .. " or higher."
	end
	local meta = source:get_meta()
	write_item_level_meta(source, meta, target)
	store_affixes(source, read_affixes(meta), player)
	return {output = source, consume = consume, recipe = recipe}
end

-- Deterministic operations work on copies. The station owns the atomic
-- capacity check, material consumption, output delivery and progression.
-- A plan is {output, consume, recipe, warning?}.
function grug_items.operation_plan(recipe, inputs, player)
	if type(inputs) ~= "table" or type(recipe) ~= "table" or
			grug_jobs.station_operation(recipe.id) ~= recipe then
		return nil, "Select a registered operation."
	end
	local allowed, reason = grug_jobs.can_craft_recipe(player, recipe)
	if not allowed then return nil, reason end
	if recipe.operation == "upgrade" then return upgrade_plan(recipe, inputs, player) end
	return enchant_plan(recipe, inputs, player)
end

function grug_items.preview_station_operation(recipe, inputs, player)
	local plan, reason = grug_items.operation_plan(recipe, inputs, player)
	return plan and plan.output or nil, reason
end

function grug_items.apply_station_operation(recipe, inputs, player)
	return grug_items.preview_station_operation(recipe, inputs, player)
end

-- The crown (round33-plan.md §2.5, item_tiers.md §4): one Fallen Crown lifts
-- one item to its material tier's top + 5 and every enchant one tier (T7 at
-- most); once per item. Refused where it would lower the item level or
-- change nothing. Returns the crowned copy and the preview text, or nil and
-- the refusal. The crown NPC (grug_traders) takes the crown and the fee.
local function crown_plan(stack)
	if not stack or stack:is_empty() then return nil, "Hand over the item to crown." end
	local family = family_for(stack)
	if not family or family == "tool" then return nil, "Only equipment can be crowned." end
	if stack:get_count() ~= 1 then return nil, "Hand over exactly one item." end
	local tier = material_tier(stack)
	local ilvl = effective_ilvl(stack)
	if not tier or not ilvl then return nil, "This item has no tier." end
	local meta = stack:get_meta()
	if meta:get_int("grug_crowned") == 1 then return nil, "This item is already crowned." end
	local target = 10 * tier + 5
	if target < ilvl then
		return nil, "The crown would lower this item's level (" .. ilvl .. " to " ..
			target .. ")."
	end
	local affixes = read_affixes(meta)
	local lines, raised = {}, false
	if target ~= ilvl then
		lines[1] = "Item level " .. ilvl .. " becomes " .. target .. "."
	end
	for index = 1, #affixes do
		local affix = affixes[index]
		if affix.tier < 7 then
			raised = true
			lines[#lines + 1] = enchant_name(affix) .. " becomes T" .. (affix.tier + 1) .. "."
			affix.tier = affix.tier + 1
		end
	end
	if target == ilvl and not raised then
		return nil, "The crown would change nothing on this item."
	end
	local out = ItemStack(stack)
	local out_meta = out:get_meta()
	out_meta:set_int("grug_crowned", 1)
	write_item_level_meta(out, out_meta, target)
	store_affixes(out, affixes)
	return out, table.concat(lines, " ")
end

-- The preview text of crowning `stack`, or nil and the refusal reason.
function grug_items.crown_preview(stack)
	local out, text = crown_plan(stack)
	if not out then return nil, text end
	return text
end

-- Applies a Fallen Crown to a copy of `stack`: the crowned ItemStack and the
-- preview text, or nil and the refusal reason. The caller swaps the stack.
function grug_items.crown_item(stack, player)
	local out, text = crown_plan(stack)
	if out and player then grug_items.regenerate_description(out, player) end
	return out, text
end

function grug_items.mastery_band(player)
	local level = grug_xp.get_level(player)
	if level >= 46 then return 4 end
	if level >= 31 then return 3 end
	if level >= 16 then return 2 end
	return 1
end

-- Every crafted equipment base is deterministic Common gear with empty
-- channels. Authored identity specials are retained by description generation.
function grug_items.crafted_output(stack, player)
	if not stack or stack:is_empty() or not family_for(stack) then return false end
	local meta = stack:get_meta()
	ensure_base_name(stack)
	meta:set_int("grug_quality", 1)
	meta:set_string("grug_ench", "")
	local ilvl = effective_ilvl(stack)
	if ilvl and family_for(stack) ~= "tool" then write_item_level_meta(stack, meta, ilvl) end
	local totals = write_derived(meta, {})
	apply_capabilities(stack, totals)
	grug_items.regenerate_description(stack, player)
	if grug_gear and type(grug_gear.initialize_weapon_tooltip) == "function" then
		grug_gear.initialize_weapon_tooltip(stack, player)
	end
	return true
end

local function gear_stack(itemname, ilvl, quality, rng, seed)
	local stack = ItemStack(itemname)
	-- A child seed keeps each independently dropped stack reproducible without
	-- sharing mutable RNG state with its affix sequence.
	local child_seed = seed + rng:next(1, 1000000)
	grug_items.roll_enchants(stack, ilvl, quality - 1, child_seed)
	return stack
end

-- "king", "dragon" or "general" for a boss that rolls BOSS_DROPS, else nil.
-- The General leads a "general:" encounter; his bodyguards share the id but
-- are no leader, and a King's royal guards share his.
local function boss_kind(self)
	local id = self._grug_boss_id
	if type(id) ~= "string" then return nil end
	if id:match("^dragon:") then return "dragon" end
	if not self._grug_royal_king then return nil end
	if id:match("^king:") then return "king" end
	if id:match("^general:") then return "general" end
	return nil
end

-- A zone leader (a leader sub-type, placed with `_grug_leader`) or a
-- Battlegrounds camp captain.
local function named_leader(self)
	if self._grug_leader then return true end
	local name = self.name or ""
	local subtype = type(grug_mobs.subtype) == "function" and grug_mobs.subtype(name)
	if type(subtype) == "table" and subtype.leader then return true end
	local garrison = grug_mobs.pvp_garrison
	return type(garrison) == "table" and garrison.pvp_kind(name) == "captain"
end

local function bag_for(level)
	for _, row in ipairs(grug_items.BAG_DROPS.sizes) do
		if not row.maximum or level <= row.maximum then return row.item end
	end
end

-- What one kill drops (round33-plan.md §2.1): at most one gear item by the
-- mob's tier at its level, two at a boss's fixed item level, and,
-- independently, a bag. A list of ItemStacks and the seed used.
function grug_items.roll_mob_gear(self, seed)
	if not self or self._grug_no_quality_loot then return {} end
	local tier = self._grug_tier or "normal"
	local boss = boss_kind(self)
	local level = math.max(1, math.floor(tonumber(self._grug_level) or 1))
	local ilvl = boss and grug_items.BOSS_DROPS.ilvl[boss] or math.min(level, 60)
	-- The pool of the item level's material tier; boss drops above 60 are T6.
	local items = grug_gear.drop_pool[grug_items.enchant_tier(math.min(ilvl, 60))]
	local rng, used_seed = rng_for(seed,
		(self.name or "mob") .. ":" .. (boss or tier) .. ":" .. ilvl)
	local out = {}
	local function add(quality)
		local itemname = items[rng:next(1, #items)]
		out[#out + 1] = gear_stack(itemname, ilvl, quality, rng,
			used_seed + #out * 104729)
	end
	if boss then
		for _ = 1, grug_items.BOSS_DROPS.count do
			add(random_chance(rng, grug_items.BOSS_DROPS.gold) and 3 or 2)
		end
	elseif tier ~= "critter" then
		local row = named_leader(self) and grug_items.DROP_CHANCES.elite or
			grug_items.DROP_CHANCES[tier] or grug_items.DROP_CHANCES.normal
		local roll = rng:next(1, 10000)
		if roll <= row.white * 100 then
			add(1)
		elseif roll <= (row.white + row.blue) * 100 then
			add(2)
		elseif roll <= (row.white + row.blue + row.gold) * 100 then
			add(3)
		end
	end
	if random_chance(rng, grug_items.BAG_DROPS.chance) then
		out[#out + 1] = ItemStack(bag_for(level))
	end
	return out, used_seed
end

-- The existing grug_mobs death hook is reached only after its shared
-- player-tag/enemy-kill predicate. It drops concrete ItemStacks so their meta
-- survives, including on bosses whose ordinary string-drop list is empty.
grug_mobs.register_kill_loot_hook(function(self, tagger_name)
	-- Encounters reward through their ledger, except a fortress General, who
	-- has none (Round 31): his gear drops here, on the same enemy-player kill
	-- that drops his war trophies. His bodyguards drop no gear, like royal
	-- guards.
	local general = type(self._grug_boss_id) == "string" and
		self._grug_boss_id:match("^general:") and self._grug_royal_king
	if (self._grug_boss_id or self._grug_royal_king) and not general then return end
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

grug_mobs.register_boss_reward_hook(function(self, id, player)
	local rewards = grug_items.roll_mob_gear(self)
	for index = 1, #rewards do
		local stack = rewards[index]
		if grug_gear and
				type(grug_gear.initialize_weapon_tooltip) == "function" then
			-- This initializer first regenerates every quality description with
			-- the receiving player, then adds the effective-level line for
			-- weapons.  Do this before give_or_queue may serialize the stack.
			grug_gear.initialize_weapon_tooltip(stack, player)
		else
			grug_items.regenerate_description(stack, player)
		end
	end
	return rewards
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
		dodge_percent = 0, armor_rating = 0, max_hp_percent = 0,
		max_mana_percent = 0}
	local inventory = player:get_inventory()
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		local stack = inventory:get_stack(slot.list, 1)
		if stack and not stack:is_empty() and
				not grug_core.equipment_is_broken(stack) then
			local meta = stack:get_meta()
			local affixes = read_affixes(meta)
			for index = 1, #affixes do
				local affix = affixes[index]
				totals[affix.stat] = (totals[affix.stat] or 0) + affix.value
			end
			local def = stack:get_definition() or {}
			totals.max_hp_percent = totals.max_hp_percent +
				(tonumber(def._grug_max_hp_percent) or 0)
			totals.max_mana_percent = totals.max_mana_percent +
				(tonumber(def._grug_max_mana_percent) or 0)

		end
	end
	aggregate_cache[name] = totals
	return totals
end

function grug_items.get_equipment_affix_totals(player)
	local source = equipment_totals(player)
	local result = {}
	for key, value in pairs(source) do result[key] = value end
	return result
end

-- Rating contribution outside base armor and affixes: the shield's full-set
-- base rating. Affixes remain separately
-- visible through get_equipment_affix_totals for the combat breakdown.
function grug_items.get_equipment_armor_rating_bonus(player)
	local shield = grug_inventory.get_equipped_offhand(player)
	local shield_rating = 0
	if shield and not grug_core.equipment_is_broken(shield) and
			core.get_item_group(shield:get_name(), "grug_shield") > 0 then
		local _, described = grug_gear.describe_stack_base(shield, effective_ilvl(shield))
		shield_rating = tonumber(described and described.armor) or 0
	end
	return shield_rating
end

local original_equipment_changed = grug_inventory.equipment_changed
grug_inventory.equipment_changed = function(player, listname, reason)
	if player and player.get_player_name then
		aggregate_cache[player:get_player_name()] = nil
	end
	return original_equipment_changed(player, listname, reason)
end
grug_inventory.invalidate_armor = grug_inventory.equipment_changed

grug_classes.get_equipment_pool_percent = function(player, pool)
	local totals = equipment_totals(player)
	if pool == "hp" then return totals.max_hp_percent or 0 end
	if pool == "mana" then
		return totals.max_mana_percent or 0
	end
	return 0
end

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
	local base = grug_inventory.get_equipped_armor(player)
	local affixes = grug_items.get_equipment_affix_totals(player)
	local equipment_bonus = grug_items.get_equipment_armor_rating_bonus(player)
	local talent = grug_classes.get_talent_bonus(player, "armor_percent_add")
	local status = grug_core.status_modifier_sum(player, "armor")
	local before_unbroken = base + (affixes.armor_rating or 0) +
		equipment_bonus + talent + status
	local multiplier = grug_classes.talent_rank(player, "unbroken") > 0
		and grug_core.PROTECTION_ARMOR_MULTIPLIER or 1
	local emergency = grug_classes.get_talent_bonus(player,
		"armor_rating_add_low_hp")
	return before_unbroken * multiplier + emergency, {
		base = before_unbroken,
		multiplier = multiplier,
		emergency = emergency,
		result = before_unbroken * multiplier + emergency,
	}
end

grug_core.get_armor_rating = raw_armor
grug_core.get_armor_rating_breakdown = function(player)
	local _, breakdown = raw_armor(player)
	return breakdown
end

core.register_on_leaveplayer(function(player)
	aggregate_cache[player:get_player_name()] = nil
end)

core.log("action", "[grug_quality] deterministic PcgRandom quality rolls enabled")
