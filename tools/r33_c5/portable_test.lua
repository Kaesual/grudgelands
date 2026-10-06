-- Round 33 lane C5 portable test (vendors, capitals, potions, stat pass,
-- round33-plan.md §2.5-2.7, §2.9a, docs/design/item_tiers.md §1.0, §4-§6).
-- Loads the REAL files under small stubs and checks:
--   A. crit and dodge from Dexterity (0.05 / 0.1 points per point), the
--      attribute terms with their fractions (Str/10, Dex/10, Int/10);
--   B. a crit doubles a melee hit and a heal (grug_core/combat.lua), the
--      ability-damage crit uses the same multiplier, no early floor of half
--      the spell power is left in kits.lua;
--   C. vendors sell the T1 bases only, every weapon family and armour piece,
--      with no rotation and no blue item; the buy-back stays for T2+ gear
--      and exists for shields, spellbooks and trinkets (item_tiers.md §6.1),
--      times 3 / 6 for blue / gold;
--   D. repair costs factor 1.00 of the reference price times the missing
--      durability;
--   E. potions restore 70 / 200 / 400 / 650 / 1000 / 1350 at tiers I-VI,
--      the Weak Healing Potion 35, every potion shares one 60 s clock, the
--      elixirs carry item_tiers' values, no two recipes share their inputs
--      and every input is at most the recipe's tier;
--   F. the Crownbinder against a stub of the crown operation: the fee and
--      one Fallen Crown are taken together with the crowned item written,
--      or nothing changes (no crown, not enough money, a changed item, the
--      operation's refusal, no operation at all);
--   G. the Decor Merchant's shelf: grug_decor items in the four price bands,
--      no profession supplies, 5 % buy-back; both capital services in every
--      capital's service plots.
--
-- Usage (repo root): luajit tools/r33_c5/portable_test.lua [REPO]

grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
local ROOT = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-9,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function read_file(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), "cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function permissive(base)
	return setmetatable(base, {__index = function()
		return function() end
	end})
end
local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
	offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
}

-- One registry and ItemStack double with real metadata semantics.
local registered = {}
local function new_meta(fields)
	fields = fields or {}
	local meta = {fields = fields}
	function meta:get_string(key) return fields[key] or "" end
	function meta:set_string(key, value)
		if value == "" then fields[key] = nil else fields[key] = value end
	end
	function meta:get_int(key) return math.floor(tonumber(fields[key]) or 0) end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:set_tool_capabilities() end
	return meta
end
ItemStack = function(source)
	local name, count, fields, wear = "", 0, {}, 0
	if type(source) == "table" then
		name, count, wear = source:get_name(), source:get_count(), source:get_wear()
		fields = deep_copy(source:get_meta().fields)
	elseif type(source) == "string" and source ~= "" then
		name, count = source, 1
	end
	local meta = new_meta(fields)
	local stack = {}
	function stack:get_name() return name end
	function stack:get_count() return count end
	function stack:is_empty() return name == "" or count <= 0 end
	function stack:get_meta() return meta end
	function stack:get_wear() return wear end
	function stack:set_wear(value) wear = value end
	function stack:get_definition() return registered[name] or {} end
	function stack:get_short_description() return name end
	function stack:get_tool_capabilities() return (registered[name] or {}).tool_capabilities end
	function stack:take_item(n)
		n = n or 1
		count = math.max(0, count - n)
		if count == 0 then name = "" end
	end
	function stack:equals(other)
		if other:get_name() ~= name or other:get_count() ~= count then return false end
		local a, b = meta.fields, other:get_meta().fields
		for k, v in pairs(a) do if b[k] ~= v then return false end end
		for k, v in pairs(b) do if a[k] ~= v then return false end end
		return true
	end
	return stack
end

local current_mod = "grug_gear"
local modpaths = {
	grug_gear = ROOT .. "/mods/ITEMS/grug_gear",
	grug_traders = ROOT .. "/mods/ENTITIES/grug_traders",
	grug_mapgen = ROOT .. "/mods/MAPGEN/grug_mapgen",
	grug_money = ROOT .. "/mods/PLAYER/grug_money", -- coins.lua (Round 34)
}
core = permissive({
	registered_items = registered,
	registered_nodes = {},
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	colorize = function(_, text) return text end,
	formspec_escape = function(text) return text end,
	register_tool = function(name, def) registered[name] = def end,
	register_craftitem = function(name, def) registered[name] = def end,
	register_node = function(name, def) registered[name] = def end,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_all_craft_recipes = function() return nil end,
	get_us_time = function() return 1 end,
})

------------------------------------------------------------------------------
-- A. Crit, dodge and attributes (grug_classes/stats.lua).
------------------------------------------------------------------------------
do
	local level, class = 60, "warrior"
	local defs = {
		warrior = {growth = {str = 3, int = 0, dex = 1}, resource = "rage"},
		scout = {growth = {str = 1, int = 1, dex = 2}, resource = "mana"},
		mage = {growth = {str = 0, int = 3, dex = 1}, resource = "mana"},
	}
	grug_xp = permissive({get_level = function() return level end})
	grug_core = permissive({
		status_modifier_sum = function() return 0 end,
		absorb_modifier = function() return 0 end,
		base_pool = function() return 100 end,
	})
	grug_classes = permissive({
		get_class = function() return class end,
		get_class_def = function() return defs[class] end,
		get_talent_bonus = function() return 0 end,
		get_scout_dodge_add = function() return 0 end,
		get_scout_dodge_cap = function() return 30 end,
	})
	dofile(ROOT .. "/mods/PLAYER/grug_classes/stats.lua")
	local p = {}
	-- Warrior 60: Str 187, Dex 69.
	near(grug_classes.get_crit_chance(p), 0.05 + 0.0005 * 69, "A crit = 5 % + 0.05 % per Dex")
	near(grug_classes.get_dodge_chance(p), 0.001 * 69, "A dodge = 0.1 % per Dex")
	near(grug_classes.get_melee_bonus(p), 18.7, "A Warrior melee bonus Str/10 keeps its fraction")
	class = "scout" -- Dex 128
	near(grug_classes.get_melee_bonus(p), 12.8, "A Scout melee bonus Dex/10")
	near(grug_classes.get_ranged_bonus(p), 12.8, "A Scout ranged bonus Dex/10")
	near(grug_classes.get_crit_chance(p), 0.05 + 0.0005 * 128, "A Scout crit from Dex 128")
	class = "mage" -- Int 187
	near(grug_classes.get_spell_power_bonus(p), 18.7, "A spell power Int/10 keeps its fraction")
	level = 1
	near(grug_classes.get_crit_chance(p), 0.055, "A level 1: Dex 10 gives 5.5 % crit")
	-- The cap holds: a very high Dexterity stops at 30 %.
	class, level = "scout", 600
	near(grug_classes.get_crit_chance(p), 0.30, "A crit capped at 30 %")
	near(grug_classes.get_dodge_chance(p), 0.30, "A dodge capped at 30 %")
	local help = read_file("mods/PLAYER/grug_inventory/help.lua")
	check(help:find("0.05 percentage point of Crit", 1, true) ~= nil and
		help:find("Crit doubles damage and healing", 1, true) ~= nil and
		not help:find("floor(Strength", 1, true), "A help text states the new rules")
end

------------------------------------------------------------------------------
-- B. Crit x2 (grug_core/combat.lua).
------------------------------------------------------------------------------
do
	grug_core = {}
	-- Round 40: combat.lua plays its crit and absorb through the particle helper.
	grug_core.particles = {play = function() end}
	grug_core.get_crit_chance = nil
	dofile(ROOT .. "/mods/CORE/grug_core/combat.lua")
	local chance = 1
	grug_core.get_crit_chance = function() return chance end
	local damage, mult, critical = grug_core.roll_melee_crit({}, 7.5)
	check(damage == 15 and mult == 2 and critical == true, "B a melee crit doubles the hit")
	chance = 0
	damage, mult, critical = grug_core.roll_melee_crit({}, 7.5)
	check(damage == 7.5 and mult == 1 and critical == false, "B no crit leaves the hit")
	-- A heal crit doubles the heal (heal_player, its one roll).
	local target = {hp = 10, max = 500}
	function target:get_hp() return self.hp end
	function target:set_hp(hp) self.hp = hp end
	function target:get_properties() return {hp_max = self.max} end
	function target:get_pos() return {x = 0, y = 0, z = 0} end
	function target:is_player() return true end
	function target:get_player_name() return "t" end
	grug_core.add_heal_threat = function() end
	grug_core.scale_player_value = function(_, amount) return amount end
	grug_core.trinket_outgoing_heal = nil
	chance = 1
	local healed = grug_core.heal_player(target, target, 41)
	eq(healed, 82, "B a heal crit heals x2")
	target.hp = 10
	eq(grug_core.heal_player(target, target, 41, {no_crit = true}), 41,
		"B no_crit keeps the amount")
	local source = read_file("mods/CORE/grug_core/combat.lua")
	local _, uses = source:gsub("CRIT_MULTIPLIER%)", "")
	check(source:find("local CRIT_MULTIPLIER = 2\n", 1, true) ~= nil and uses >= 2 and
		not source:find("* 1.5)", 1, true), "B ability, heal and melee crits share x2")
	local kits = read_file("mods/PLAYER/grug_abilities/kits.lua")
	check(not kits:find("math.floor(power / 2)", 1, true) and
		not kits:find("math.floor(\n\t\t\t\t\tgrug_classes.get_spell_power_bonus", 1, true),
		"B no early floor of half the spell power")
end

------------------------------------------------------------------------------
-- C. Vendor stock and buy-back (grug_gear, grug_traders prices/stock).
------------------------------------------------------------------------------
grug_core = permissive({level_scale = function() return 1 end})
grug_classes = permissive({get_melee_bonus = function() return 0 end})
grug_mobs = permissive({read_data_json = function() return {} end})
grug_materials = {RESOURCES = {}, PROCESSED_MATERIALS = {}}
grug_inventory = permissive({})
current_mod = "grug_gear"
dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
grug_traders = {}
current_mod = "grug_traders"
dofile(ROOT .. "/mods/ENTITIES/grug_traders/prices.lua")
dofile(ROOT .. "/mods/ENTITIES/grug_traders/stock.lua")
grug_traders.resolve_prices()
do
	local shelf = grug_traders.bracket_stock(1)
	local cat = grug_gear.catalog[1].all
	eq(#shelf, #cat, "C the gear shelf holds the whole T1 catalog")
	eq(#cat, 18, "C ...six weapon families and twelve armour pieces")
	local families = {}
	for _, entry in ipairs(shelf) do
		local def = registered[entry.item]
		if def._grug_weapon_family then families[def._grug_weapon_family] = true end
		check(def._grug_bracket == 1 and entry.price == grug_gear.get_price(entry.item) and
			entry.uncommon == nil, "C " .. entry.item .. " is a Common T1 base at its slot price")
	end
	for _, family in ipairs({"sword", "dagger", "greataxe", "staff", "wand", "bow"}) do
		check(families[family], "C the shelf sells the " .. family)
	end
	for bracket = 2, 6 do
		eq(#grug_traders.bracket_stock(bracket), 0, "C no T" .. bracket .. " shelf")
	end
	eq(grug_traders.max_bracket(), 1, "C one gear tab at every level")
	check(grug_traders.make_stack == nil and grug_traders.rotation_index == nil,
		"C the rotation and the blue item are gone")
	-- Buy-back: 5 % of the reference price, rounded up.
	eq(grug_traders.sell_price(grug_gear.weapon_item("sword", 1)), 2, "C T1 sword buys back 2c")
	eq(grug_traders.sell_price(grug_gear.weapon_item("sword", 2)), 4, "C T2 sword buys back 4c")
	eq(grug_traders.sell_price(grug_gear.weapon_item("bow", 6)), 125, "C T6 bow buys back 1s 25c")
	eq(grug_traders.sell_price(grug_gear.armor_item("chest", "metal", 4)), 16,
		"C T4 chest buys back 16c")
	local metal = grug_gear.MATERIALS
	eq(grug_traders.sell_price("grug_gear:shield_" .. metal[6].metal.key), 63,
		"C a T6 shield buys back 63c")
	eq(grug_traders.sell_price("grug_gear:spellbook_" .. metal[3].metal.key), 4,
		"C a T3 spellbook buys back 4c")
	for tier, value in ipairs({1, 2, 4, 10, 25, 63}) do
		local trinket = grug_gear.trinket_item(grug_gear.TRINKETS[1].key, tier)
		eq(grug_traders.sell_price(trinket), value, "C a T" .. tier .. " trinket buys back")
	end
	local blue = ItemStack("grug_gear:shield_" .. metal[6].metal.key)
	blue:get_meta():set_int("grug_quality", 2)
	eq(grug_traders.stack_sell_price(blue), 189, "C a blue T6 shield sells for 1s 89c")
	blue:get_meta():set_int("grug_quality", 3)
	eq(grug_traders.stack_sell_price(blue), 378, "C a gold one for 3s 78c")
	-- A reference price never undercuts a sold item: buy-back stays below it.
	local loops = 0
	for _, entry in ipairs(shelf) do
		if grug_traders.sell_price(entry.item) >= grug_traders.discounted_price(entry.price) then
			loops = loops + 1
		end
	end
	eq(loops, 0, "C no buy-then-sell loop on the gear shelf")
	local potion = read_file("mods/ENTITIES/grug_traders/stock.lua")
	check(potion:find('item = "grug_inventory:bag_small", price = 80', 1, true) ~= nil,
		"C the 8-slot bag stays on sale")
end

------------------------------------------------------------------------------
-- D. Repair factor (grug_repair/service.lua).
------------------------------------------------------------------------------
do
	grug_repair = {}
	dofile(ROOT .. "/mods/ITEMS/grug_repair/service.lua")
	eq(grug_repair.FACTOR, 1.00, "D repair factor 1.00")
	local sword = ItemStack(grug_gear.weapon_item("sword", 6))
	sword:set_wear(65535)
	eq(grug_repair.cost(sword), 2500, "D a worn-out T6 sword costs its price")
	sword:set_wear(32768)
	eq(grug_repair.cost(sword), 1251, "D half worn: half the price, rounded up")
	sword:get_meta():set_int("grug_quality", 2)
	sword:set_wear(65535)
	eq(grug_repair.cost(sword), 7500, "D a blue item: x3")
	sword:set_wear(0)
	eq(grug_repair.cost(sword), 0, "D an intact item costs nothing")
end

------------------------------------------------------------------------------
-- E. Potions and elixirs (grug_traders/potion.lua, grug_alchemy).
------------------------------------------------------------------------------
do
	local now = 1000000
	os.time = function() return now end
	dofile(ROOT .. "/mods/ENTITIES/grug_traders/potion.lua")
	local healed, restored, statuses, feed = {}, {}, {}, {}
	grug_core = permissive({
		heal_player = function(_, _, amount, opts)
			healed[#healed + 1] = {amount = amount, no_crit = opts and opts.no_crit}
		end,
		can_use_item_level = function(player, stack)
			local def = registered[stack:get_name()] or {}
			local need = def._grug_ilvl or 0
			return player.level >= need, need
		end,
		feed = function(_, _, text) feed[#feed + 1] = text end,
		set_status = function(_, key, status) statuses[key] = status end,
		trinket_instant_potion = false,
	})
	grug_classes = {get_max_hp = function(p) return p.max_hp end,
		get_max_mana = function(p) return p.max_mana end}
	grug_abilities = {restore_mana = function(_, amount) restored[#restored + 1] = amount end}
	grug_jobs = permissive({})
	grug_brewing = {NODE = "grug_brewing:brewing_stand"}
	grug_gathering = permissive({})
	local catalogue = {}
	local json = read_file("mods/ENTITIES/grug_mobs/data/items.json")
	for object in json:gmatch("%b{}") do
		local id = object:match('"id"%s*:%s*"([^"]+)"')
		local tier = tonumber(object:match('"tier"%s*:%s*(%d+)'))
		if id and tier then catalogue[#catalogue + 1] = {id = id, tier = tier} end
	end
	grug_mobs = {read_data_json = function() return catalogue end}
	local tiers = {}
	grug_jobs.register_ingredient_tier = function(item, tier) tiers[item] = tier end
	grug_alchemy = {}
	dofile(ROOT .. "/mods/ITEMS/grug_alchemy/effects.lua")
	dofile(ROOT .. "/mods/ITEMS/grug_alchemy/recipes.lua")

	local function player(level)
		local meta = new_meta()
		local p = {level = level, hp = 10, max_hp = 5000, max_mana = 5000}
		function p:is_player() return true end
		function p:get_player_name() return "drinker" end
		function p:get_hp() return self.hp end
		function p:get_meta() return meta end
		function p:get_properties() return {hp_max = self.max_hp} end
		return p
	end
	local function drink(p, item)
		local stack = ItemStack(item)
		return registered[item].on_use(stack, p, {}), stack
	end
	local roman = {"I", "II", "III", "IV", "V", "VI"}
	local amounts = {70, 200, 400, 650, 1000, 1350}
	for tier = 1, 6 do
		local p = player(60)
		healed = {}
		drink(p, "grug_alchemy:potion_healing_t" .. tier)
		check(healed[1] and healed[1].amount == amounts[tier] and healed[1].no_crit,
			"E Healing Potion " .. roman[tier] .. " restores " .. amounts[tier])
		check(registered["grug_alchemy:potion_healing_t" .. tier].description:find(
			"^Healing Potion " .. roman[tier] .. "\n") ~= nil, "E ...named with its numeral")
		restored = {}
		now = now + 61
		drink(p, "grug_alchemy:potion_mana_t" .. tier)
		eq(restored[1], amounts[tier], "E Mana Potion " .. roman[tier] .. " restores")
		now = now + 61
	end
	-- One shared clock: healing, mana, a draught and the vendor potion.
	local p = player(60)
	healed, restored = {}, {}
	drink(p, "grug_alchemy:potion_healing_t3")
	drink(p, "grug_alchemy:potion_mana_t3")
	drink(p, "grug_traders:potion_healing_weak")
	drink(p, "grug_alchemy:potion_swiftness")
	check(#healed == 1 and #restored == 0 and statuses.alchemy_swiftness == nil,
		"E every potion waits for the one shared clock")
	eq(grug_traders.potion_cooldown_left(p), 60, "E the clock runs 60 s")
	now = now + 60
	drink(p, "grug_traders:potion_healing_weak")
	eq(healed[2] and healed[2].amount, 35, "E the Weak Healing Potion heals a fixed 35 HP")
	eq(grug_traders.potion_cooldown_left(p), 60, "E ...and starts the same clock")
	-- The level requirement is the tier's first level.
	local low = player(10)
	healed = {}
	drink(low, "grug_alchemy:potion_healing_t2")
	check(#healed == 0, "E Healing Potion II needs level 11")
	-- Elixirs: item_tiers.md §5 values, no potion clock.
	local values = {
		vigor = {"hp_pool_percent", {4.0, 4.8, 5.6, 6.4, 7.2, 8.0}},
		focus = {"mana_pool_percent", {5.0, 5.6, 6.2, 6.8, 7.4, 8.0}},
		precision = {"crit_percent", {4.2, 5.2, 6.0, 7.0, 7.8, 8.6}},
		stoneskin = {"armor", {0.8, 1.6, 2.4, 3.2, 4.0, 4.8}},
	}
	for key, row in pairs(values) do
		for tier = 1, 6 do
			statuses = {}
			local q = player(60)
			drink(q, "grug_alchemy:elixir_" .. key .. "_t" .. tier)
			local status = statuses.elixir
			check(status and status.modifiers[row[1]] == row[2][tier],
				"E elixir " .. key .. " " .. roman[tier] .. " gives " .. row[2][tier])
			eq(grug_traders.potion_cooldown_left(q), 0, "E ...and leaves the potion clock")
		end
	end
	-- Recipes: unique inputs, tiers, no removed reagents, one vial each.
	local seen, ids = {}, {}
	for _, row in ipairs(grug_alchemy.CATALOG) do
		ids[row.id] = true
		local key = table.concat(row.inputs, "+")
		check(not seen[key], "E " .. row.id .. " shares no recipe (" .. key .. ")")
		seen[key] = row.id
		local own = false
		for _, input in ipairs(row.inputs) do
			local tier = tiers[input]
			if input:find("^grug_cooking:") then
				tier = ({["grug_cooking:sugar_cane"] = 2, ["grug_cooking:cave_cap"] = 3,
					["grug_cooking:ember_moss"] = 5})[input]
			elseif input == "group:grug_cooking_root" then
				tier = 1
			end
			if input ~= "vessels:glass_bottle" then
				check(tier ~= nil and tier <= row.tier, "E " .. row.id .. " input " ..
					input .. " is at most T" .. row.tier)
				if tier == row.tier then own = true end
			end
			check(not input:find("slime_gel") and not input:find("croc_tooth") and
				not input:find("stone_core"), "E " .. row.id .. " uses no one-faction reagent")
		end
		check(own, "E " .. row.id .. " has an input of its own tier")
	end
	eq(#grug_alchemy.CATALOG, 40, "E 36 tiered products and four draughts")
	check(ids.potion_antivenom and ids.potion_swiftness and ids.potion_cave and
		ids.elixir_deepwater, "E the four draughts stay")
	check(not ids.potion_greater_healing and not ids.elixir_stoneskin,
		"E the old Greater potions and the single Stoneskin are gone")
	-- The Basics catalog declares exactly these mixtures.
	local routes = dofile(ROOT .. "/mods/PLAYER/grug_jobs/basics_routes.lua")
	local declared = {}
	for _, route in ipairs(routes) do
		local id = route.output:match("^grug_alchemy:mixture_(.+)$")
		if id then
			declared[id] = table.concat(route.inputs, "+")
		end
	end
	local all = true
	for _, row in ipairs(grug_alchemy.CATALOG) do
		if declared[row.id] ~= table.concat(row.inputs, "+") then all = false end
		declared[row.id] = nil
	end
	check(all and next(declared) == nil, "E basics_routes.lua declares every mixture, no other")
end

------------------------------------------------------------------------------
-- F. The Crownbinder (grug_traders/crown.lua) with the real crown operation
--    of grug_quality (grug_items.crown_preview / crown_item).
------------------------------------------------------------------------------
do
	local equipment_changed = 0
	grug_inventory = {
		equipment_slots = {{list = "grug_weapon"}, {list = "grug_chest"}},
		BAG_COUNT = 1,
		content_list = function(i) return "grug_bag_" .. i end,
		is_equipment_list = function(list) return list:find("^grug_") ~= nil and
			not list:find("^grug_bag_") end,
		equipment_changed = function() equipment_changed = equipment_changed + 1 end,
	}
	grug_money = nil
	dofile(ROOT .. "/mods/PLAYER/grug_money/init.lua")
	-- Without the operation the NPC refuses cleanly.
	grug_items = nil
	dofile(ROOT .. "/mods/ENTITIES/grug_traders/crown.lua")
	local none, why = grug_traders.crown_operation(ItemStack(grug_gear.weapon_item("sword", 5)))
	check(none == nil and type(why) == "string", "F no crown operation: a refusal, no error")
	-- The real operation (grug_quality/init.lua, lane C4).
	local wearer_level = 60
	grug_core = permissive({level_scale = function() return 1 end,
		get_player_level = function() return wearer_level end})
	-- The real level gate of grug_core (combat.lua), which grug_quality wraps.
	do
		local source = read_file("mods/CORE/grug_core/combat.lua")
		local body = source:match("(function grug_core%.can_use_item_level%(player, item%).-\nend)\n")
		check(body ~= nil, "F can_use_item_level found in combat.lua")
		assert(loadstring(body))()
	end
	grug_classes = permissive({get_melee_bonus = function() return 0 end})
	grug_mobs = permissive({})
	grug_jobs = permissive({})
	grug_xp = permissive({get_level = function() return 60 end})
	grug_factions = permissive({serves = function() return true end})
	local tooltips = 0
	local real_tooltip = grug_gear.initialize_weapon_tooltip
	grug_gear.initialize_weapon_tooltip = function(stack, player)
		tooltips = tooltips + 1
		return real_tooltip(stack, player)
	end
	grug_repair = nil -- section D's partial module; descriptions skip durability
	-- Park-Miller: enough for the one drop roll below.
	PcgRandom = function(seed)
		local state = seed % 2147483647
		if state == 0 then state = 1 end
		return {next = function(_, low, high)
			state = (state * 48271) % 2147483647
			return low + state % (high - low + 1)
		end}
	end
	modpaths.grug_quality = ROOT .. "/mods/ITEMS/grug_quality"
	current_mod = "grug_quality"
	dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
	current_mod = "grug_traders"
	registered["grug_mobs:fallen_crown"] = {groups = {}}

	local function new_player(money)
		local lists = {main = {}, grug_weapon = {}, grug_chest = {}, grug_bag_1 = {}}
		for name, list in pairs(lists) do
			for i = 1, (name == "main" and 8 or 1) do list[i] = ItemStack("") end
		end
		local inv = {}
		function inv:get_list(name) return lists[name] end
		function inv:get_size(name) return lists[name] and #lists[name] or 0 end
		function inv:get_stack(name, i) return ItemStack(lists[name][i]) end
		function inv:set_stack(name, i, stack) lists[name][i] = ItemStack(stack); return true end
		local meta = new_meta()
		local p = {lists = lists}
		function p:is_player() return true end
		function p:get_player_name() return "crowner" end
		function p:get_inventory() return inv end
		function p:get_meta() return meta end
		function p:get_hp() return 20 end
		function p:get_pos() return {x = 0, y = 0, z = 0} end
		grug_money.set(p, money)
		return p
	end
	eq(grug_traders.CROWN_FEE, 14800, "F the fee is 1g 48s (income.py --check keeps it)")
	local sword = grug_gear.weapon_item("sword", 5)
	local p = new_player(20000)
	p.lists.grug_weapon[1] = ItemStack(sword)
	p.lists.main[1] = ItemStack("default:dirt")
	local rows = grug_traders.crown_rows(p)
	eq(#rows, 1, "F only gear is offered")
	check(rows[1] and rows[1].result and rows[1].text and
		rows[1].text:find("Item level 40 becomes 55", 1, true) ~= nil,
		"F ...with the operation's preview (" .. tostring(rows[1] and rows[1].text) .. ")")
	-- No Fallen Crown: nothing changes.
	local ok, message = grug_traders.crown_apply(p, rows[1])
	check(not ok and message == "You need a Fallen Crown." and grug_money.get(p) == 20000,
		"F refused without a Fallen Crown")
	-- Not enough money: nothing changes.
	p.lists.grug_bag_1[1] = ItemStack("grug_mobs:fallen_crown")
	grug_money.set(p, 14799)
	ok, message = grug_traders.crown_apply(p, rows[1])
	check(not ok and message:find("^You need 1g 48s") ~= nil and
		p.lists.grug_bag_1[1]:get_name() == "grug_mobs:fallen_crown" and
		p.lists.grug_weapon[1]:get_meta():get_string("grug_crowned") == "",
		"F refused without the fee, crown and item untouched")
	-- A changed item: refused.
	grug_money.set(p, 20000)
	p.lists.grug_weapon[1]:get_meta():set_string("note", "moved")
	ok, message = grug_traders.crown_apply(p, rows[1])
	check(not ok and message:find("changed") ~= nil, "F a changed item is refused")
	-- Success: fee, crown and item in one transaction.
	rows = grug_traders.crown_rows(p)
	ok, message = grug_traders.crown_apply(p, rows[1])
	check(ok and grug_money.get(p) == 20000 - 14800, "F the fee is taken")
	check(p.lists.grug_bag_1[1]:is_empty(), "F one Fallen Crown is consumed")
	local crowned = p.lists.grug_weapon[1]
	check(crowned:get_meta():get_int("grug_crowned") == 1 and
		grug_items.effective_ilvl(crowned) == 55, "F the crowned item (item level 55) replaces the old one")
	eq(equipment_changed, 1, "F an equipped item refreshes the equipment")
	check(tooltips >= 1, "F the weapon's effective-damage line is rebuilt")
	-- Once per item: the operation's refusal is shown, no button.
	p.lists.main[2] = ItemStack("grug_mobs:fallen_crown")
	rows = grug_traders.crown_rows(p)
	check(rows[1] and not rows[1].result and rows[1].reason == "This item is already crowned.",
		"F a crowned item shows the refusal")
	ok, message = grug_traders.crown_apply(p, rows[1])
	check(not ok and grug_money.get(p) == 5200 and p.lists.main[2]:get_name() ==
		"grug_mobs:fallen_crown", "F ...and crowning it again changes nothing")
	-- A worn item must stay wearable: a level-55 Warrior's worn T6 sword
	-- (requirement 60 once crowned) is not offered, and the apply path
	-- refuses it as a guard; the same sword in the bag is offered.
	wearer_level = 55
	local w = new_player(20000)
	w.lists.grug_weapon[1] = ItemStack(grug_gear.weapon_item("sword", 6))
	w.lists.main[1] = ItemStack(grug_gear.weapon_item("sword", 6))
	w.lists.main[2] = ItemStack("grug_mobs:fallen_crown")
	local worn_rows = grug_traders.crown_rows(w)
	local worn, carried
	for _, row in ipairs(worn_rows) do
		if row.list == "grug_weapon" then worn = row else carried = row end
	end
	check(worn and not worn.result and worn.reason ==
		"The crowned item needs level 60; take it off first.",
		"F a worn item the wearer could no longer wear gets no Crown button (" ..
		tostring(worn and worn.reason) .. ")")
	check(carried and carried.result, "F ...the same item in the bag is offered")
	ok, message = grug_traders.crown_apply(w, {list = worn.list, index = worn.index,
		expected = worn.expected, result = true})
	check(not ok and message == "The crowned item needs level 60; take it off first." and
		grug_money.get(w) == 20000 and w.lists.main[2]:get_name() == "grug_mobs:fallen_crown" and
		w.lists.grug_weapon[1]:get_meta():get_int("grug_crowned") == 0,
		"F crown_apply refuses it too and nothing changes")
	wearer_level = 60
	-- A boss drop above the crown's target is refused (never lowering).
	local drop = ItemStack(grug_gear.weapon_item("sword", 6))
	grug_items.roll_enchants(drop, 70, 1, 7)
	local text, reason = grug_traders.crown_preview(drop)
	check(text == nil and reason and reason:find("lower", 1, true) ~= nil,
		"F an item-level-70 drop is not lowered to 65")
end

------------------------------------------------------------------------------
-- G. The Decor Merchant and the capital services.
------------------------------------------------------------------------------
do
	local shelf = grug_traders.profession_stock.culture
	check(shelf ~= nil and #shelf > 0, "G the culture shelf exists")
	local bands = {[25] = 0, [100] = 0, [1000] = 0, [10000] = 0}
	for _, entry in ipairs(shelf or {}) do
		check(bands[entry.price] ~= nil, "G " .. entry.item .. " is in a price band")
		bands[entry.price] = (bands[entry.price] or 0) + 1
		check(entry.item:find("^grug_decor:") ~= nil, "G " .. entry.item .. " is grug_decor's")
	end
	for price, count in pairs(bands) do
		check(count > 0, "G the " .. price .. "c band has an item")
	end
	-- grug_alchemy (section E) registered the vial for every vendor.
	local function sells(list, item)
		for _, entry in ipairs(list) do if entry.item == item then return true end end
		return false
	end
	check(sells(grug_traders.profession_stock.butcher, "vessels:glass_bottle") and
		not sells(shelf, "vessels:glass_bottle"), "G no profession supplies on the culture shelf")
	-- The 5 % buy-back of a sold good.
	grug_gathering = nil
	grug_traders.resolve_prices()
	eq(grug_traders.sell_price("grug_decor:xdecor_painting_1"), 500, "G a 1g painting buys back 5s")
	eq(grug_traders.sell_price("grug_decor:darkage_marble_tile"), 2, "G a 25c tile buys back 2c")
	local services = dofile(ROOT .. "/mods/MAPGEN/grug_mapgen/wp13/capital_services.lua")
	local cities = 0
	for _, plots in pairs(services.PLOTS) do
		cities = cities + 1
		check(type(plots.goldsmith) == "string" and type(plots.woodcarver) == "string",
			"G every capital has the goldsmith and woodcarver halls")
	end
	eq(cities, 6, "G six capitals")
	local vendors = read_file("mods/ENTITIES/grug_traders/vendors.lua")
	check(vendors:find('role = "crownbinder", plot = "goldsmith"', 1, true) ~= nil and
		vendors:find('role = "culture_vendor", plot = "woodcarver"', 1, true) ~= nil,
		"G the Crownbinder and the Decor Merchant take those halls' gate residents")
	local sockets = read_file("mods/CORE/grug_core/settlement_sockets.lua")
	check(sockets:find("crownbinder = true, culture_vendor = true", 1, true) ~= nil,
		"G both are service roles")
end

if failures > 0 then
	error(("R33 C5 FAIL checks=%d failures=%d"):format(checks, failures), 0)
end
print(("R33 C5 PASS checks=%d"):format(checks))
