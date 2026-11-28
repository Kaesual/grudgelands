-- The Character page's stat sheet (Round 88 STATS, plan ruling 8): per stat
-- the list value, the hover line of an attribute, and the detail: one
-- sentence, the direct effects, where the value comes from, the rule.
--
-- Every shown value is read from the accessors combat uses (grug_classes'
-- attributes, pools, crit and dodge; grug_core's armor rating and
-- reduction). The "where it comes from" lines split it by source: the
-- class's base and growth, each equipment slot (grug_quality's per-slot
-- pass, grug_inventory's armor pieces), talents and effects. They repeat the
-- formulas of grug_classes/stats.lua and grug_quality's overrides, so a
-- source those formulas gain later shows as an "Other" line instead of a
-- sum that no longer adds up. Built on a page build only; nothing stored.

local S = {}

-- A number rounded to `decimals` places, trailing zeros dropped.
local function num(value, decimals)
	local text = ("%." .. (decimals or 1) .. "f"):format(value)
	if text:find("%.") then text = text:gsub("0+$", ""):gsub("%.$", "") end
	if text == "-0" then text = "0" end
	return text
end
local function signed(value, decimals)
	return (value < 0 and "−" .. num(-value, decimals) or "+" .. num(value, decimals))
end
local function pct(value, decimals)
	return num(value, decimals) .. " %"
end
local function signed_pct(value, decimals)
	return signed(value, decimals) .. " %"
end
S.num, S.pct = num, pct

local EPSILON = 1e-6

-- The slot's name as the gear box labels it, and the item's name.
local function slot_title(class_id, list)
	local name = grug_inventory.slot_label(class_id, list)
	if not name then
		for _, slot in ipairs(grug_inventory.equipment_slots) do
			if slot.list == list then name = slot.label end
		end
	end
	return name == "Caster offhand" and "Offhand" or name or list
end
local function item_title(itemname)
	local def = core.registered_items[itemname]
	local text = def and def.description or itemname
	text = core.strip_colors and core.strip_colors(text) or text
	return (text:gsub("\n.*", ""))
end

-- Per-slot sources: {list, label, stats} in slot order (grug_quality's
-- pass; empty without it).
local function slot_sources(player, class_id)
	local items = rawget(_G, "grug_items")
	local out = {}
	if not (items and items.get_equipment_slot_sources) then return out end
	for _, entry in ipairs(items.get_equipment_slot_sources(player)) do
		out[#out + 1] = {list = entry.list, stats = entry.stats,
			label = slot_title(class_id, entry.list) .. " · " .. item_title(entry.name)}
	end
	return out
end

-- Adds a source line {text, label, n = value, kind}.
local function add(lines, text, label, n, kind)
	lines[#lines + 1] = {text, label, n = n, kind = kind or "add"}
end

-- The "Other" line for a remainder the known sources do not explain.
local function other(lines, remainder, format)
	if math.abs(remainder) > EPSILON then
		add(lines, format(remainder), "Other sources", remainder)
	end
end

local function status_sum(player, key)
	return grug_core.status_modifier_sum and grug_core.status_modifier_sum(player, key) or 0
end
local function talent(player, key)
	return grug_classes.get_talent_bonus and grug_classes.get_talent_bonus(player, key) or 0
end

--
-- The pools
--

local function pool_entry(player, ctx, pool)
	local b = grug_classes.get_pool_breakdown(player, pool)
	local key = pool == "hp" and "max_hp_percent" or "max_mana_percent"
	local lines = {}
	add(lines, tostring(b.base), ("Level %d base pool"):format(ctx.level), b.base, "base")
	if pool == "hp" then
		add(lines, "× " .. num(b.class_factor, 2), ctx.class_name .. " class factor",
			b.class_factor, "factor")
	end
	local gear = 0
	for _, slot in ipairs(ctx.slots) do
		local value = slot.stats[key] or 0
		if math.abs(value) > EPSILON then
			add(lines, signed_pct(value), slot.label, value, "percent")
			gear = gear + value
		end
	end
	if math.abs(b.gear_percent - gear) > EPSILON then
		add(lines, signed_pct(b.gear_percent - gear), "Other equipment",
			b.gear_percent - gear, "percent")
	end
	if math.abs(b.talent_percent) > EPSILON then
		add(lines, signed_pct(b.talent_percent), "Talents", b.talent_percent, "percent")
	end
	if math.abs(b.status_percent) > EPSILON then
		add(lines, signed_pct(b.status_percent), "Effects (food, elixirs)",
			b.status_percent, "percent")
	end
	if pool == "hp" then
		return {id = "hp", name = "Maximum HP", value = tostring(b.final), amount = b.final,
			what = "The damage you can take before you die. HP does not regenerate " ..
				"on its own: food, potions and healing restore it.",
			effects = {{tostring(b.final), "maximum HP"}},
			sources = lines, total = {tostring(b.final), "Maximum HP"},
			rule = "Base pool × class factor × (1 + the percentages from gear, " ..
				"talents and effects), rounded once. The base pool grows with your level."}
	end
	return {id = "mana", name = "Maximum mana", value = tostring(b.final), amount = b.final,
		what = "Spent by your abilities; it refills over time, faster out of combat.",
		effects = {{tostring(b.final), "maximum mana"}},
		sources = lines, total = {tostring(b.final), "Maximum mana"},
		rule = "Base pool × (1 + the percentages from gear, talents and effects), " ..
			"rounded once. The class factor applies to HP only."}
end

local function rage_entry()
	return {id = "rage", name = "Maximum rage", value = "100", amount = 100,
		what = "Warriors build rage by fighting and spend it on abilities; out of " ..
			"combat it decays.",
		effects = {{"100", "maximum rage, the same at every level"}},
		sources = {}, total = {"100", "Fixed for Warriors"},
		rule = "Rage does not grow with level or gear."}
end

--
-- The attributes
--

local ATTRIBUTE_NAMES = {str = "Strength", int = "Intelligence", dex = "Dexterity"}

local function attribute_sources(ctx, key)
	local lines = {}
	add(lines, "10", "Base, every class", 10)
	local growth = ctx.growth[key] or 0
	if growth ~= 0 then
		add(lines, signed(growth * (ctx.level - 1), 0), ("Level %d · %s +%d per level")
			:format(ctx.level, ctx.class_name, growth), growth * (ctx.level - 1))
	end
	local sum = 10 + growth * (ctx.level - 1)
	for _, slot in ipairs(ctx.slots) do
		local value = slot.stats[key] or 0
		if math.abs(value) > EPSILON then
			add(lines, signed(value, 1), slot.label, value)
			sum = sum + value
		end
	end
	other(lines, ctx.attributes[key] - sum, function(v) return signed(v, 1) end)
	return lines
end

local function attribute_entry(ctx, key, entry)
	local value = ctx.attributes[key]
	entry.id, entry.name = key, ATTRIBUTE_NAMES[key]
	entry.value, entry.amount = num(value, 1), value
	entry.sources = attribute_sources(ctx, key)
	entry.total = {num(value, 1), ATTRIBUTE_NAMES[key]}
	return entry
end

local function strength_entry(player, ctx)
	local scout = ctx.class_id == "scout"
	local melee = grug_classes.get_melee_bonus(player)
	return attribute_entry(ctx, "str", {
		tip = scout and "Strength: no effect for Scouts, who hit with Dexterity." or
			"Strength: +" .. num(melee, 1) .. " melee damage per hit.",
		what = scout and "Raises the damage of melee hits, for every class but the Scout." or
			"Raises the damage of melee hits.",
		effects = scout and {{"–", "no effect: Scouts hit with Dexterity in melee and with the bow"}} or
			{{"+" .. num(melee, 1), "melee damage on every hit"}},
		rule = "Strength ÷ 10 is added to each melee hit, for every class but the " ..
			"Scout. Each point counts at once.",
	})
end

local function intelligence_entry(player, ctx)
	local caster = ctx.class_id == "mage" or ctx.class_id == "priest"
	local spell = grug_classes.get_spell_power_bonus(player)
	local support = (grug_classes.get_support_factor(player) - 1) * 100
	local own = 10 + (ctx.growth.int or 0) * (ctx.level - 1)
	local gear = ctx.attributes.int - own
	local base_hit = grug_core.baseline_melee_total(math.max(1, math.min(60, ctx.level)))
	local effects = {}
	if caster then
		effects[1] = {"+" .. num(spell, 1), "spell power, added to every damage spell"}
	else
		effects[1] = {"–", ("spell power: %ss cast no damage spells"):format(ctx.class_name)}
	end
	effects[2] = {signed_pct(support), math.abs(gear) > EPSILON and
		("healing and absorbs, from the %s Intelligence on your gear"):format(num(gear, 1)) or
		"healing and absorbs: only Intelligence from gear counts"}
	local tip = caster and ("Intelligence: +%s spell power."):format(num(spell, 1)) or
		("Intelligence: no spell power for %ss."):format(ctx.class_name)
	if math.abs(gear) > EPSILON then
		tip = tip .. ("\nHealing and absorbs %s (Intelligence from gear)."):format(signed_pct(support))
	end
	return attribute_entry(ctx, "int", {
		tip = tip,
		what = "Raises the damage of spells; Intelligence from gear also raises " ..
			"healing and absorbs.",
		effects = effects,
		rule = ("Spell power = Intelligence ÷ 10, the flat part of each damage spell. " ..
			"Healing and absorbs grow only by the Intelligence above your class's " ..
			"own growth, measured against a level-%d base hit (%s)."):format(
			ctx.level, num(base_hit, 1)),
	})
end

local function dexterity_entry(player, ctx)
	local scout = ctx.class_id == "scout"
	local dex = ctx.attributes.dex
	local effects = {}
	if scout then
		effects[1] = {"+" .. num(grug_classes.get_melee_bonus(player), 1),
			"melee and bow damage on every hit"}
	end
	effects[#effects + 1] = {"+" .. pct(0.05 * dex, 2), "Crit chance (0.05 % per point)"}
	effects[#effects + 1] = {"+" .. pct(0.1 * dex, 1), "Dodge chance (0.1 % per point)"}
	local tip = ("Dexterity: +%s Crit, +%s Dodge."):format(pct(0.05 * dex, 2), pct(0.1 * dex, 1))
	if scout then
		tip = tip .. ("\n+%s melee and bow damage per hit."):format(
			num(grug_classes.get_melee_bonus(player), 1))
	end
	return attribute_entry(ctx, "dex", {
		tip = tip,
		what = scout and "Raises Crit and Dodge, and for Scouts the damage of every hit." or
			"Raises Crit and Dodge.",
		effects = effects,
		rule = "Crit and Dodge are each capped at 30 %." .. (scout and
			" Scouts add Dexterity ÷ 10 to melee and bow hits instead of Strength." or ""),
	})
end

--
-- Armor, Dodge, Crit
--

local function armor_entry(player, ctx)
	local total = grug_core.get_armor_rating(player)
	local shown = grug_gear.format_armor
	local function signed_armor(value)
		return value < 0 and "−" .. shown(-value) or "+" .. shown(value)
	end
	local lines, sum = {}, 0
	local pieces = grug_inventory.equipped_armor_pieces and
		grug_inventory.equipped_armor_pieces(player) or {}
	local items = rawget(_G, "grug_items")
	local shield = items and items.get_equipment_armor_rating_bonus and
		items.get_equipment_armor_rating_bonus(player) or 0
	for _, slot in ipairs(ctx.slots) do
		local value = (pieces[slot.list] or 0) + (slot.stats.armor_rating or 0) +
			(slot.list == "grug_offhand" and shield or 0)
		if value > EPSILON then
			add(lines, signed_armor(value), slot.label, value)
			sum = sum + value
		end
	end
	local from_talents = talent(player, "armor_percent_add")
	if math.abs(from_talents) > EPSILON then
		add(lines, signed_armor(from_talents), "Talents", from_talents)
		sum = sum + from_talents
	end
	local from_effects = status_sum(player, "armor")
	if math.abs(from_effects) > EPSILON then
		add(lines, signed_armor(from_effects), "Effects (elixirs)", from_effects)
		sum = sum + from_effects
	end
	local mult = grug_core.get_race_perk and grug_core.get_race_perk(player, "armor_rating_mult")
	local applies = mult and sum > 0
	other(lines, (applies and total / mult or total) - sum, signed_armor)
	if applies then
		local race = grug_classes.get_race_def and grug_classes.get_race_def(player)
		add(lines, "× " .. num(mult, 2), (race and race.name or "Race") .. " race", mult, "factor")
	end
	local effects = {}
	for _, gap in ipairs({-5, 0, 5, 10}) do
		local level = math.max(1, ctx.level + gap)
		effects[#effects + 1] = {pct(grug_core.armor_reduction(total, level, 0.70) * 100, 1),
			("level %d%s"):format(level, gap == 0 and ", your level" or "")}
	end
	local k = grug_core.armor_k(ctx.level) * 10
	return {id = "armor", name = "Armor", value = shown(total), amount = total,
		what = "Reduces the damage of every hit you take; how much depends on the " ..
			"attacker's level.",
		effects_note = "Less damage from an enemy of",
		effects = effects, sources = lines, total = {shown(total), "Armor rating"},
		rule = ("Reduction = rating ÷ (rating + 200 + 5 per attacker level), %s " ..
			"against level %d; above level 60 it rises by 85 per level. Capped at 70 %%. " ..
			"Falls, lava and drowning ignore armor. Each armor piece carries its share of " ..
			"the set (chest 35 %%, legs 27 %%, head 22 %%, feet 16 %%); a shield carries a " ..
			"whole metal set."):format(num(k, 0), ctx.level)}
end

-- A capped chance: its source lines in percent and the cap line.
local function chance_lines(lines, sum, raw, capped)
	other(lines, (raw - sum) * 100, function(v) return signed_pct(v, 2) end)
	if raw - capped > EPSILON then
		add(lines, signed_pct((capped - raw) * 100, 2), "Above the 30 % cap", (capped - raw) * 100)
	end
end

local function slot_percent_lines(lines, ctx, key)
	local sum = 0
	for _, slot in ipairs(ctx.slots) do
		local value = slot.stats[key] or 0
		if math.abs(value) > EPSILON then
			add(lines, signed_pct(value, 1), slot.label, value)
			sum = sum + value / 100
		end
	end
	return sum
end

local function dodge_entry(player, ctx)
	local dex = ctx.attributes.dex
	local lines = {}
	add(lines, "+" .. pct(0.1 * dex, 1), "Dexterity " .. num(dex, 1), 0.1 * dex)
	local sum = 0.001 * dex + slot_percent_lines(lines, ctx, "dodge_percent")
	local from_talents = talent(player, "dodge_chance_add")
	if math.abs(from_talents) > EPSILON then
		add(lines, signed_pct(from_talents, 1), "Talents", from_talents)
		sum = sum + from_talents / 100
	end
	local from_effects = grug_core.absorb_modifier and grug_core.absorb_modifier(player, "dodge_percent") or 0
	if math.abs(from_effects) > EPSILON then
		add(lines, signed_pct(from_effects, 1), "Effects", from_effects)
		sum = sum + from_effects / 100
	end
	local sidestep = grug_classes.get_scout_dodge_add and grug_classes.get_scout_dodge_add(player) or 0
	if sidestep ~= 0 then
		add(lines, signed_pct(sidestep, 1), "Sidestep", sidestep)
		sum = sum + sidestep / 100
	end
	local capped = grug_classes.get_dodge_chance(player)
	chance_lines(lines, sum, grug_classes.get_dodge_chance_raw(player), capped)
	return {id = "dodge", name = "Dodge", value = pct(capped * 100, 1), amount = capped * 100,
		what = "The chance that a hit misses you completely.",
		effects = {{pct(capped * 100, 1), "chance to avoid a hit entirely"}},
		sources = lines, total = {pct(capped * 100, 1), "Dodge"},
		rule = "0.1 % per point of Dexterity plus gear, talents and effects. Capped at 30 %."}
end

local function crit_entry(player, ctx)
	local dex = ctx.attributes.dex
	local lines = {}
	add(lines, "5 %", "Base, every class", 5)
	add(lines, "+" .. pct(0.05 * dex, 2), "Dexterity " .. num(dex, 1), 0.05 * dex)
	local sum = 0.05 + 0.0005 * dex + slot_percent_lines(lines, ctx, "crit_percent")
	local from_talents = talent(player, "crit_chance_add")
	if math.abs(from_talents) > EPSILON then
		add(lines, signed_pct(from_talents, 1), "Talents", from_talents)
		sum = sum + from_talents / 100
	end
	local from_effects = status_sum(player, "crit_percent")
	if math.abs(from_effects) > EPSILON then
		add(lines, signed_pct(from_effects, 1), "Effects (elixirs)", from_effects)
		sum = sum + from_effects / 100
	end
	local capped = grug_classes.get_crit_chance(player)
	chance_lines(lines, sum, grug_classes.get_crit_chance_raw(player), capped)
	return {id = "crit", name = "Crit", value = pct(capped * 100, 1), amount = capped * 100,
		what = "The chance that a hit, or a heal, counts double.",
		effects = {{pct(capped * 100, 1), "chance of a critical hit or heal (×2)"}},
		sources = lines, total = {pct(capped * 100, 1), "Crit"},
		rule = "Capped at 30 %. Area hits and splashes never crit."}
end

-- The list in its order; "gap" marks a separator between groups.
function S.sheet(player)
	local class = grug_classes.get_class_def(player)
	local class_id = grug_classes.get_class(player)
	local ctx = {
		level = grug_xp.get_level(player),
		class_id = class_id,
		class_name = class and class.name or "Character",
		growth = class and class.growth or {},
		attributes = grug_classes.get_attributes(player),
		slots = slot_sources(player, class_id),
	}
	return {
		pool_entry(player, ctx, "hp"),
		class and class.resource == "mana" and pool_entry(player, ctx, "mana") or rage_entry(),
		"gap",
		strength_entry(player, ctx),
		intelligence_entry(player, ctx),
		dexterity_entry(player, ctx),
		"gap",
		armor_entry(player, ctx),
		dodge_entry(player, ctx),
		"gap",
		crit_entry(player, ctx),
	}
end

grug_inventory.stat_sheet = S
