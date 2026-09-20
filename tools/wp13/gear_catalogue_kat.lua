-- Known-answer test for the ONE GEAR CATALOGUE (WP13 playtest round 2,
-- 2026-09-15; items_crafting.md §3.0.3).
--
-- What it pins, and why a fixture rather than a comment: §3.0.3 is the rule
-- that there is exactly one item per concept and that the items are named after
-- their MATERIAL. Both halves are invisible at load time -- a generator that
-- quietly re-introduced a bracket adjective, dropped a tier or gave two tiers
-- the same itemstring would still start a server. So the whole catalogue is
-- listed here, name by name and description by description, and the numbers
-- that were explicitly NOT part of the rename (damage, armor, prices, ilvl)
-- are re-derived from the design curves independently of the generator.
--
-- It loads the REAL `mods/ITEMS/grug_gear/init.lua` under a stub `core`, the
-- same way `tools/wp13/character_visuals_kat.lua` does, so there is no second
-- copy of the catalogue anywhere.
--
-- Plain Lua 5.1, no engine.
--
-- Usage (from the repository root):
--   luajit          -e 'io.write(dofile("tools/wp13/gear_catalogue_kat.lua")("."))'
--   tools/bin/lua51 -e 'io.write(dofile("tools/wp13/gear_catalogue_kat.lua")("."))'

local M = {}

local GEAR = "mods/ITEMS/grug_gear/init.lua"

-- The bracket -> material ladders, written out ONCE here as the expected
-- answer. They are the design document's, not the code's: §3.0.1's six metals,
-- §3.5's six Tailor bolt grades and §3.4's six leather grades.
local EXPECTED_METAL = {"Bronze", "Iron", "Steel", "Silversteel",
	"Embersteel", "Abyssal Steel"}
local EXPECTED_CLOTH = {"Patch", "Woven", "Heavy", "Silkweave", "Silk",
	"Stormweave"}
local EXPECTED_LEATHER = {"Light", "Cured", "Heavy", "Scaled", "Sleek",
	"Nightscale"}

-- Every adjective the retired WP7 catalogue used. None of them may survive in
-- an item name -- this is the negative half of the rename.
local RETIRED_ADJECTIVES = {"Crude", "Plain", "Tempered", "Reinforced",
	"Superior", "Grand"}

local WEAPON_FAMILIES = {"sword", "dagger", "greataxe", "staff", "wand", "bow"}
local WEAPON_NOUNS = {sword = "Sword", dagger = "Dagger",
	greataxe = "Greataxe", staff = "Staff", wand = "Wand", bow = "Bow"}
local WEAPON_FACTOR = {sword = 1.0, dagger = 0.7, greataxe = 1.5, staff = 1.2,
	wand = 1.0, bow = 1.0}
local WEAPON_FPI = {sword = 1.0, dagger = 0.7, greataxe = 1.4, staff = 1.4,
	wand = 1.0, bow = 1.0}
local WEAPON_HANDS = {sword = 1, dagger = 1, greataxe = 2, staff = 2,
	wand = 1, bow = 2}
local WEAPON_GROUP = {sword = "sword", dagger = "sword", greataxe = "axe",
	staff = "staff", wand = "wand", bow = "bow"}
local CASTER_IMAGE = {wand = "default_mese_crystal_fragment.png^[colorize:"}
local BOW_IMAGE = {"grug_gear_bow_lebethron.png", "grug_gear_bow_birch.png",
	"grug_gear_bow_birch.png^[hsl:0:-20:16", "grug_gear_bow_mallorn.png",
	"grug_gear_bow_alder.png^[colorize:#b94a24:38",
	"grug_gear_bow_birch.png^[colorize:#69458c:92"}

local ARMOR_NOUNS = {
	metal = {head = "Helm", chest = "Chestplate", legs = "Greaves",
		feet = "Sabatons"},
	leather = {head = "Hood", chest = "Jerkin", legs = "Pants",
		feet = "Boots"},
	cloth = {head = "Cowl", chest = "Robe", legs = "Leggings",
		feet = "Slippers"},
}
local SLOTS = {"head", "chest", "legs", "feet"}

-- ---------------------------------------------------------------------------
-- the stub engine
-- ---------------------------------------------------------------------------
local function load_gear(repo)
	local items, order, logs, mods_loaded = {}, {}, {}, {}
	local core_stub = {registered_items = items}
	local function noop() end

	local function register(name, def)
		if name:sub(1, 1) == ":" then
			name = name:sub(2)
		end
		if items[name] == nil then
			order[#order + 1] = name
		end
		items[name] = def
	end
	core_stub.register_tool = register
	core_stub.register_craftitem = register
	core_stub.register_node = register
	function core_stub.override_item(name, fields)
		local def = items[name]
		if not def then
			return
		end
		for key, value in pairs(fields) do
			def[key] = value
		end
	end
	function core_stub.log(level, message)
		logs[#logs + 1] = tostring(level) .. "\t" .. tostring(message)
	end
	function core_stub.register_on_mods_loaded(fn)
		mods_loaded[#mods_loaded + 1] = fn
	end
	function core_stub.get_modpath(name)
		if name == "grug_gear" then return repo .. "/mods/ITEMS/grug_gear" end
		return repo
	end
	function core_stub.get_current_modname() return "grug_gear" end
	-- The stat line is colorized; the fixture compares the NAME, which is the
	-- first line, so an identity colorize keeps the comparison honest without
	-- teaching the fixture the engine's escape codes.
	function core_stub.colorize(_, text)
		return text
	end
	setmetatable(core_stub, {__index = function(t, key)
		rawset(t, key, noop)
		return noop
	end})

	-- The four `default` items grug_gear makes weapon-slot eligible have to
	-- exist before it overrides them, exactly as they do on a real server.
	-- Registering them here is also how the fixture can tell "the list shrank
	-- correctly" from "the override silently found nothing".
	local VENDORED = {"default:sword_wood", "default:sword_stone",
		"default:sword_bronze", "default:sword_steel",
		"default:axe_wood", "default:axe_stone", "default:axe_bronze",
		"default:axe_steel"}
	local VENDORED_STATS = {
		["default:sword_wood"] = {2, 1.0, "sword"},
		["default:sword_stone"] = {4, 1.2, "sword"},
		["default:sword_bronze"] = {6, 0.8, "sword"},
		["default:sword_steel"] = {6, 0.8, "sword"},
		["default:axe_wood"] = {2, 1.0, "axe"},
		["default:axe_stone"] = {3, 1.2, "axe"},
		["default:axe_bronze"] = {4, 1.0, "axe"},
		["default:axe_steel"] = {4, 1.0, "axe"},
	}
	for _, name in ipairs(VENDORED) do
		local stat = VENDORED_STATS[name]
		register(name, {description = name, groups = {[stat[3]] = 1},
			tool_capabilities = {full_punch_interval = stat[2],
				damage_groups = {fleshy = stat[1]}}})
	end
	local registered_before = {}
	for _, name in ipairs(VENDORED) do
		registered_before[name] = true
	end

	-- `table.copy` is a builtin the engine injects (AGENTS.md, "Globally
	-- injected helpers"); a standalone interpreter has none, and grug_gear's
	-- group-preserving override needs it.
	local had_copy = rawget(table, "copy")
	if not had_copy then
		table.copy = function(source)
			local result = {}
			for key, value in pairs(source) do
				if type(value) == "table" then
					result[key] = table.copy(value)
				else
					result[key] = value
				end
			end
			return result
		end
	end

	local names = {"core", "minetest", "grug_gear"}
	local saved, had = {}, {}
	for _, name in ipairs(names) do
		had[name] = rawget(_G, name) ~= nil
		saved[name] = rawget(_G, name)
	end
	rawset(_G, "core", core_stub)
	rawset(_G, "minetest", core_stub)
	rawset(_G, "grug_gear", nil)

	local function restore()
		for _, name in ipairs(names) do
			rawset(_G, name, had[name] and saved[name] or nil)
		end
		if not had_copy then
			table.copy = nil
		end
	end

	local chunk, load_err = loadfile(repo .. "/" .. GEAR)
	if not chunk then
		restore()
		error("cannot load " .. GEAR .. ": " .. tostring(load_err), 0)
	end
	local ok, err = pcall(chunk)
	if not ok then
		restore()
		error(err, 0)
	end
	-- Registered after grug_gear to prove the on-mods-loaded retrofit catches
	-- material-ladder axes without another name list.
	register("grug_materials:axe_silversteel", {
		description = "Silversteel Axe",
		groups = {axe = 1, grug_equip_weapon = 1},
		tool_capabilities = {full_punch_interval = 0.9,
			damage_groups = {fleshy = 6}},
	})
	for _, callback in ipairs(mods_loaded) do
		callback()
	end
	return {gear = rawget(_G, "grug_gear"), items = items, order = order,
		logs = logs, vendored = VENDORED, restore = restore}
end

-- ---------------------------------------------------------------------------
local function first_line(text)
	return (tostring(text):gsub("\n.*", ""))
end

local function round(v)
	return math.floor(v + 0.5)
end

function M.run(repo)
	repo = repo or "."
	local out, failures = {}, {}
	local function row(...)
		out[#out + 1] = table.concat({...}, "\t")
	end
	local function check(condition, message)
		if not condition then
			failures[#failures + 1] = message
		end
	end

	local loaded = load_gear(repo)
	local gear, items = loaded.gear, loaded.items
	local special_meta = {grug_trinket_special = "Restores 2 Rage on an accepted hit"}
	local trinket_stack = {
		get_definition = function()
			return {groups = {grug_equip_trinket = 1},
				_grug_trinket_special = "definition fallback"}
		end,
		get_meta = function()
			return {get_string = function(_, key) return special_meta[key] or "" end}
		end,
	}
	local trinket_lines = gear.describe_stack_base(trinket_stack, 20, false)
	-- R9-PROF-B: the item-level line precedes the authored special.
	check(#trinket_lines == 2 and trinket_lines[1] == "Item level 20" and
		trinket_lines[2] == special_meta.grug_trinket_special,
		"trinket authored special did not survive base-description regeneration")
	row("wp13_gear_trinket_special", trinket_lines[2] or "missing")

	--
	-- A. the material ladders
	--
	local metal_row, cloth_row, leather_row = {}, {}, {}
	for bracket = 1, 6 do
		local material = gear.MATERIALS[bracket]
		metal_row[bracket] = material.metal.name
		cloth_row[bracket] = material.cloth.name
		leather_row[bracket] = material.leather.name
		check(material.metal.name == EXPECTED_METAL[bracket],
			"metal tier " .. bracket .. " is " .. material.metal.name)
		check(material.cloth.name == EXPECTED_CLOTH[bracket],
			"cloth tier " .. bracket .. " is " .. material.cloth.name)
		check(material.leather.name == EXPECTED_LEATHER[bracket],
			"leather tier " .. bracket .. " is " .. material.leather.name)
	end
	row("wp13_gear_metals", table.concat(metal_row, ","))
	row("wp13_gear_cloth", table.concat(cloth_row, ","))
	row("wp13_gear_leather", table.concat(leather_row, ","))

	--
	-- B. the full catalogue, item by item
	--
	-- 36 weapons + 72 armor pieces + the starter weapons, each listed with the
	-- display name a player reads, the ilvl and the stat the generator gave it.
	-- The stat is recomputed here from items_crafting.md §3.2 / §3.1 so the
	-- rename cannot have moved a number sideways.
	--
	local listed = {}
	for bracket = 1, 6 do
		local br = gear.BRACKETS[bracket]
		local material = gear.MATERIALS[bracket]
		local base = round(4 + 0.35 * br.ilvl)

		for _, family in ipairs(WEAPON_FAMILIES) do
			local name = gear.weapon_item(family, bracket)
			local def = items[name]
			check(def ~= nil, "no such item: " .. tostring(name))
			if def then
				local expect_name = material.metal.name .. " " ..
					WEAPON_NOUNS[family]
				local damage = math.max(1,
					round(base * WEAPON_FACTOR[family]))
				check(first_line(def.description) == expect_name,
					name .. " is called \"" .. first_line(def.description) ..
					"\", expected \"" .. expect_name .. "\"")
				check(def.tool_capabilities.damage_groups.fleshy == damage,
					name .. " deals " ..
					tostring(def.tool_capabilities.damage_groups.fleshy) ..
					", the curve says " .. damage)
				check(def.tool_capabilities.full_punch_interval ==
					WEAPON_FPI[family], name .. " swings at the wrong interval")
				check((def._grug_hands or 1) == WEAPON_HANDS[family],
					name .. " declares the wrong hand count")
				check(def._grug_ilvl == br.ilvl, name .. " has the wrong ilvl")
				local expected_image = CASTER_IMAGE[family] and
					(CASTER_IMAGE[family] .. gear.BRACKET_TINT[bracket] .. ":115") or
					("grug_gear_item_" .. family .. "_" .. material.metal.key .. ".png")
				if family == "bow" then
					expected_image = BOW_IMAGE[bracket]
				end
				check(def.inventory_image == expected_image,
					name .. " does not use its own material sprite")
				check((def.groups or {}).grug_equip_weapon == 1,
					name .. " is not weapon-slot eligible")
				check((def.groups or {})[WEAPON_GROUP[family]] == 1,
					name .. " lacks its family group")
				check(((def.groups or {}).grug_caster_weapon == 1) ==
					(CASTER_IMAGE[family] ~= nil),
					name .. " caster group differs")
				listed[#listed + 1] = name .. "\t" .. expect_name .. "\t" ..
					br.ilvl .. "\t" .. damage
			end
		end

		for _, line in ipairs({"metal", "leather", "cloth"}) do
			for _, slot in ipairs(SLOTS) do
				local name = gear.armor_item(slot, line, bracket)
				local def = items[name]
				check(def ~= nil, "no such item: " .. tostring(name))
				if def then
					local expect_name = material[line].name .. " " ..
						ARMOR_NOUNS[line][slot]
					check(first_line(def.description) == expect_name,
						name .. " is called \"" ..
						first_line(def.description) .. "\", expected \"" ..
						expect_name .. "\"")
					check(def._grug_ilvl == br.ilvl,
						name .. " has the wrong ilvl")
					check(def._grug_bracket == bracket,
						name .. " has the wrong bracket")
					listed[#listed + 1] = name .. "\t" .. expect_name ..
						"\t" .. br.ilvl .. "\t" .. tostring(def._grug_armor)
				end
			end
		end
	end

	for _, entry in ipairs(listed) do
		row("wp13_gear_item", entry)
	end
	row("wp13_gear_count", #listed)
	check(#listed == 108, "the catalogue holds " .. #listed ..
		" items, expected 108")

	-- The six core identities are one definition per tier. Their authored
	-- passive remains descriptive data for the follow-up effects lane.
	local trinket_contract = {
		manawell = {form = "amulet", kind = "mana_regen", stacking = "additive",
			cap = 1, values = {0.05, 0.10, 0.15, 0.25, 0.35, 0.50}},
		last_light = {form = "amulet", kind = "last_light_absorb",
			stacking = "highest", cooldown = 120, values = {3, 4, 5, 6, 8, 10}},
		battlebeat = {form = "ring", kind = "battlebeat_rage",
			stacking = "additive", cap = 4,
			values = {0.25, 0.50, 0.75, 1.00, 1.50, 2.00}},
		apothecary_loop = {form = "ring", kind = "potion_amount",
			stacking = "additive", cap = 30,
			values = {2.5, 5, 7.5, 10, 12.5, 15}},
		mercy_seal = {form = "medallion", kind = "outgoing_healing",
			stacking = "additive", cap = 12, values = {1, 2, 3, 4, 5, 6}},
		reclaimers_mark = {form = "medallion", kind = "reclaimer",
			stacking = "highest", cooldown = 10, values = {1, 1.5, 2, 2.5, 3, 4},
			rage = {1, 2, 3, 4, 5, 6}},
	}
	local trinket_count = 0
	for identity, contract in pairs(trinket_contract) do
		for tier = 1, 6 do
			local name = "grug_gear:" .. identity .. "_t" .. tier
			local def = items[name]
			check(def ~= nil, "missing trinket " .. name)
			if def then
				local ilvl = gear.BRACKETS[tier].ilvl
				check((def.groups or {}).grug_equip_trinket == 1 and
					def.stack_max == 1 and def._grug_quality_family == "trinket" and
					def._grug_quality == 1, name .. " generic fields differ")
				check(def._grug_ilvl == ilvl and def._grug_bracket == tier and
					def.description:find("Item level " .. ilvl, 1, true),
					name .. " did not preserve its authored item level")
				check(def._grug_trinket_identity == identity and
					def._grug_trinket_form == contract.form and
					def._grug_trinket_kind == contract.kind and
					def._grug_trinket_value == contract.values[tier] and
					def._grug_trinket_rage ==
						(contract.rage and contract.rage[tier] or nil) and
					def._grug_trinket_stacking == contract.stacking and
					def._grug_trinket_cap == contract.cap and
					def._grug_trinket_cooldown == contract.cooldown,
					name .. " authored identity fields differ")
				check(type(def._grug_trinket_special) == "string" and
					def._grug_trinket_special ~= "" and
					not def._grug_trinket_special:find("inert", 1, true),
					name .. " live special description missing or marked inert")
				trinket_count = trinket_count + 1
			end
		end
	end
	row("wp13_gear_trinkets", trinket_count)
	check(trinket_count == 36, "the catalogue holds " .. trinket_count ..
		" trinkets, expected 36")

	--
	-- C. the below-ladder starters
	--
	local starter = items[gear.STARTER_STAFF]
	check(starter ~= nil, "the starter staff is not registered")
	if starter then
		check(first_line(starter.description) == "Wooden Staff",
			"the starter staff is called \"" ..
			first_line(starter.description) .. "\"")
		check(starter._grug_ilvl == nil,
			"the starter staff carries an ilvl and would gain a level gate")
		check(starter._grug_hands == 2, "the starter staff is not two-handed")
		check((starter.groups or {}).grug_equip_weapon == 1,
			"the starter staff cannot go in the weapon slot")
		row("wp13_gear_starter", gear.STARTER_STAFF,
			first_line(starter.description), gear.STARTER_SWORD)
	end
	local starter_bow = items[gear.STARTER_BOW]
	check(starter_bow and starter_bow._grug_hands == 2 and
		(starter_bow.groups or {}).grug_bow == 1 and
		starter_bow._grug_ilvl == nil and
		starter_bow.inventory_image == "grug_gear_bow_wood.png",
		"the wooden starter bow contract differs")

	-- Every weapon-slot item with fleshy damage uses the same base-stat line,
	-- including the default starters/hatchets and a later material-ladder axe.
	local retrofit_stats = {
		["default:sword_wood"] = "2 damage, 1.0 s swing",
		["default:sword_stone"] = "4 damage, 1.2 s swing",
		["default:axe_wood"] = "2 damage, 1.0 s swing",
		["default:axe_stone"] = "3 damage, 1.2 s swing",
		["default:axe_bronze"] = "4 damage, 1.0 s swing",
		["default:axe_steel"] = "4 damage, 1.0 s swing",
		["grug_materials:axe_silversteel"] = "6 damage, 0.9 s swing",
	}
	local retrofit_names = {}
	for name, expected in pairs(retrofit_stats) do
		local description = items[name] and items[name].description or ""
		check(description:find("\n" .. expected, 1, true) ~= nil,
			name .. " lacks the tooltip line \"" .. expected .. "\"")
		retrofit_names[#retrofit_names + 1] = name
	end
	table.sort(retrofit_names)
	row("wp13_gear_retrofit", table.concat(retrofit_names, ","))

	--
	-- D. one item per concept
	--
	-- D1: no retired bracket adjective survives in any display name.
	local adjectives = 0
	for name, def in pairs(items) do
		local label = first_line(def.description)
		for _, adjective in ipairs(RETIRED_ADJECTIVES) do
			if label:sub(1, #adjective + 1) == adjective .. " " then
				adjectives = adjectives + 1
				check(false, name .. " is still called \"" .. label .. "\"")
			end
		end
	end
	row("wp13_gear_adjectives", adjectives)

	-- D2: no display name is used twice. The rename's real failure mode is two
	-- items that read identically in a trade window.
	local seen, duplicates = {}, 0
	for bracket = 1, 6 do
		for _, family in ipairs(WEAPON_FAMILIES) do
			local label = first_line(
				items[gear.weapon_item(family, bracket)].description)
			if seen[label] then
				duplicates = duplicates + 1
				check(false, "two items are called \"" .. label .. "\"")
			end
			seen[label] = true
		end
		for _, line in ipairs({"metal", "leather", "cloth"}) do
			for _, slot in ipairs(SLOTS) do
				local label = first_line(
					items[gear.armor_item(slot, line, bracket)].description)
				if seen[label] then
					duplicates = duplicates + 1
					check(false, "two items are called \"" .. label .. "\"")
				end
				seen[label] = true
			end
		end
	end
	row("wp13_gear_duplicates", duplicates)

	-- D3: the two `default` swords the ladder now covers must NOT have been
	-- made weapon-slot eligible any more -- they are unregistered by
	-- grug_materials' curation, and a stale entry here would have re-blessed
	-- an item that no longer exists. The wood/stone starters and the four
	-- hatchets still must be.
	local eligible, ineligible = {}, {}
	for _, name in ipairs(loaded.vendored) do
		local def = items[name]
		if def and (def.groups or {}).grug_equip_weapon == 1 then
			eligible[#eligible + 1] = name
		else
			ineligible[#ineligible + 1] = name
		end
	end
	table.sort(eligible)
	table.sort(ineligible)
	row("wp13_gear_vendored", table.concat(eligible, ","), "not",
		table.concat(ineligible, ","))
	check(table.concat(ineligible, ",") ==
		"default:sword_bronze,default:sword_steel",
		"the retired default swords are not the two left out (" ..
		table.concat(ineligible, ",") .. ")")

	--
	-- E. prices and the vendor catalogue are UNCHANGED by the rename
	--
	local price_rows = {}
	for bracket = 1, 6 do
		local br = gear.BRACKETS[bracket]
		local cat = gear.catalog[bracket]
		check(#cat.fixed == 13, "bracket " .. bracket .. " has " ..
			#cat.fixed .. " fixed items, expected 13")
		check(#cat.extras == 5, "bracket " .. bracket .. " has " ..
			#cat.extras .. " rotating items, expected 5")
		check(#cat.all == 18, "bracket " .. bracket .. " has " .. #cat.all ..
			" items, expected 18")
		local sword = gear.weapon_item("sword", bracket)
		check(gear.get_price(sword) == br.price.weapon,
			sword .. " is not priced at the bracket's weapon price")
		local quality = 3
		local price_stack = {is_empty = function() return false end,
			get_name = function() return sword end,
			get_definition = function() return items[sword] end,
			get_meta = function() return {get_int = function(_, key)
				return key == "grug_quality" and quality or 0
			end} end}
		check(gear.reference_purchase_price(price_stack) == br.price.weapon * 6,
			sword .. " Rare repair reference price differs")
		local metal = gear.MATERIALS[bracket].metal.key
		local shield = items["grug_gear:shield_" .. metal]
		local book = items["grug_gear:spellbook_" .. metal]
		local shield_images = {
			bronze = "grug_gear_shield_bronze.png",
			iron = "grug_gear_shield_iron.png^[hsl:0:-100:-12",
			steel = "grug_gear_shield_steel.png",
			silversteel = "grug_gear_shield_silversteel.png",
			embersteel = "grug_gear_shield_embersteel.png^[colorize:#9f2418:112",
			abyssal_steel = "grug_gear_shield_abyssal_steel.png",
		}
		check(shield and shield.groups.grug_equip_offhand == 1 and
			shield.groups.grug_shield == 1 and shield._grug_armor > 0 and
			shield.inventory_image == shield_images[metal],
			"tier " .. bracket .. " shield contract differs")
		check(book and book.groups.grug_equip_offhand == 1 and
			book.groups.grug_spellbook == 1 and book._grug_max_mana_percent ==
			math.ceil(bracket / 2) and book.inventory_image:find(
			"grug_gear_spellbook.png", 1, true) == 1,
			"tier " .. bracket .. " spellbook contract differs")
		check(gear.get_sell_price(sword) ==
			math.max(1, math.floor(br.price.weapon * 0.25)),
			sword .. " does not buy back at 25%")
		price_rows[#price_rows + 1] = br.ilvl .. ":" .. br.price.weapon ..
			"/" .. br.price.chest .. "/" .. br.price.other
	end
	row("wp13_gear_prices", table.concat(price_rows, " "))

	loaded.restore()

	table.sort(failures)
	row("wp13_gear_result", #failures == 0 and "PASS" or "FAIL", #failures)
	for _, message in ipairs(failures) do
		row("wp13_gear_failure", message)
	end
	return table.concat(out, "\n") .. "\n"
end

return function(repo)
	return M.run(repo)
end
