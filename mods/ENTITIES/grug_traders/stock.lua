-- What a vendor offers: the level-independent core stock (items_crafting.md
-- §3.7 / §8.2), the T1 gear shelf (round33-plan.md §2.6) and the profession
-- shelves.

--
-- Same-race discount (world.md §7: a race's Quartermaster serves its whole
-- faction and gives its own race the discount; Round 56 ruling 9). 10% is
-- the WP7 decision and is documented alongside it. It applies to BUY prices
-- only; buy-back is never discounted, or the discount would widen the
-- buy/sell spread into a money loop at the race vendor.
--
grug_traders.RACE_DISCOUNT = 0.10

-- max(1, ...) so a 1c item can never become free (and never 0-priced, which
-- would let grug_money.take succeed on an empty purse).
function grug_traders.discounted_price(price)
	return math.max(1, math.floor(price * (1 - grug_traders.RACE_DISCOUNT)))
end

--
-- Core stock (economy-vendor-plan.md §2.3; items_crafting.md §3.7): the small
-- bag, the weak healing potion, torches, wood and stone tools, the bronze
-- pick and player arrows -- a start town has only its race vendor, and a
-- Scout must be able to restock there. The job supplies (thread, parchment,
-- vial) are added by the mods that own them through
-- register_all_vendor_stock below, so they reach every shelf.
--
-- Every vendor offers this list, in every territory and at every level --
-- that is what "level-independent" means. The T1 gear shelf sits on top of
-- it, on its own tab.
--

grug_traders.stock = {} -- ordered; the UI renders it in registration order

-- {item = <name>, price = <copper>, category = "goods" | "tools"}
function grug_traders.register_stock(def)
	assert(type(def) == "table", "grug_traders.register_stock: table expected")
	assert(type(def.item) == "string" and def.item ~= "",
		"grug_traders.register_stock: item name missing")
	local price = tonumber(def.price)
	assert(price and price > 0 and price == math.floor(price),
		"grug_traders.register_stock: price must be a positive whole copper " ..
		"amount (" .. tostring(def.item) .. ")")
	local category = def.category or "goods"
	assert(category == "goods" or category == "tools",
		"grug_traders.register_stock: unknown category '" .. tostring(category) ..
		"' (" .. def.item .. ")")
	table.insert(grug_traders.stock, {
		item = def.item,
		price = price,
		category = category,
	})
end

grug_traders.register_stock({item = "grug_inventory:bag_small", price = 20, category = "goods"})
grug_traders.register_stock({item = "grug_traders:potion_healing_weak", price = 8, category = "goods"})
grug_traders.register_stock({item = "default:torch", price = 1, category = "goods"})
grug_traders.register_stock({item = "grug_gear:arrow", price = 3, category = "goods"})

grug_traders.register_stock({item = "grug_materials:pick_wood", price = 5, category = "tools"})
grug_traders.register_stock({item = "grug_materials:shovel_wood", price = 5, category = "tools"})
grug_traders.register_stock({item = "grug_materials:axe_wood", price = 5, category = "tools"})
grug_traders.register_stock({item = "grug_materials:pick_stone", price = 10, category = "tools"})
grug_traders.register_stock({item = "grug_materials:shovel_stone", price = 10, category = "tools"})
grug_traders.register_stock({item = "grug_materials:axe_stone", price = 10, category = "tools"})
grug_traders.register_stock({item = "grug_materials:pick_bronze", price = 40, category = "tools"})

--
-- The gear shelf (round33-plan.md §2.6, item_tiers.md §6). Vendors sell the
-- T1 bases only: every weapon family and armour piece of the first material
-- tier, Common, at its slot price. From T2 the bases come from Basics
-- crafting or drops; buy-back of every tier stays with prices.lua.
--
grug_traders.GEAR_BRACKET = 1

local gear_shelf -- built on first use; grug_gear's catalog is final by then

function grug_traders.bracket_stock(bracket)
	if tonumber(bracket) ~= grug_traders.GEAR_BRACKET then
		return {}
	end
	if not gear_shelf then
		gear_shelf = {}
		local tier = grug_traders.GEAR_BRACKET
		local ilvl = grug_gear.BRACKETS[tier].ilvl
		for _, itemname in ipairs(grug_gear.catalog[tier].all) do
			gear_shelf[#gear_shelf + 1] = {
				item = itemname,
				price = grug_gear.get_price(itemname),
				ilvl = ilvl,
			}
		end
	end
	return gear_shelf
end

-- Profession equipment shops are views over the one authoritative gear
-- shelf above; in particular, Tanner does not own a copied list of the
-- leather ladder.
local BRACKET_FILTERS = {
	bow = function(def)
		return ((def.groups or {}).grug_bow or 0) > 0
	end,
	leather = function(def)
		return ((def.groups or {}).grug_armor_class or 0) == 2
	end,
}

-- `true` means the full shared catalog; a string names the filter above.
-- vendors.lua consumes this table when it registers the profession entities,
-- keeping UI entitlement and stock selection on one declaration.
grug_traders.PROFESSION_BRACKETS = {
	smith = true,
	armourer = true,
	bowyer = "bow",
	tanner = "leather",
}

function grug_traders.vendor_bracket_stock(vendor, bracket)
	if not vendor then return {} end
	local entries = grug_traders.bracket_stock(bracket)
	local filter = BRACKET_FILTERS[vendor.bracket_filter]
	if not filter then return entries end
	local result = {}
	for _, entry in ipairs(entries) do
		local def = core.registered_items[entry.item]
		if def and filter(def) then
			result[#result + 1] = entry
		end
	end
	return result
end

-- Highest bracket a vendor shows: the T1 gear shelf, at every level.
function grug_traders.max_bracket()
	return grug_traders.GEAR_BRACKET
end

-- UI label of a bracket ("1-10", "11-20", ...).
function grug_traders.bracket_label(bracket)
	local br = grug_gear.BRACKETS[bracket]
	if not br then
		return "?"
	end
	return br.min_level .. "-" .. br.max_level
end

--
-- PROFESSION SHELVES (WP13 playtest round 3, sockets contract section 8.4).
--
-- `vendor.kind` grew from {race, general} to also carry butcher, smith,
-- fishmonger, baker and tailor, and in wave 2 (2026-09-15) mason, brewer,
-- bowyer, herbalist, armourer, tanner and embalmer. A profession vendor is an
-- ordinary trader with
-- ONE difference: its General tab is its own shelf instead of the
-- level-independent core stock above. Everything else -- the money, the sell
-- side, the buy-back prices, the formspec -- is the same code, and the two
-- original families are untouched.
--
-- WHAT IS ON THEM (economy-vendor-plan.md §2): a shelf of the trade's
-- supplies, food to eat, flavour goods and a few T1 basics -- never an enchant
-- input and never a material above T1, because those come from hunting,
-- mining and gathering. Since Round 57 (ruling 28) no shelf sells leather,
-- cloth, ores or metal bars of any tier either: hides and cloth come off the
-- start zones' beasts and dead, copper and tin out of their rock. Thread
-- stays as a job supply and the tailor keeps its two wools (bed decor);
-- traders still buy all of them (the Bronze Bar, off the shelves, pays its
-- inputs like any bar: 2c). tools/r57_vendormat pins this.
-- The audit at the bottom of this file enforces the tier rule at
-- load, together with the older rule that a shelf names only registered
-- items (an unregistered one renders as a buyable "unknown item" button): a
-- failing entry is DROPPED from its shelf and reported as an error.
--
-- The SMITH and ARMOURER keep the full T1 gear tab. Bowyer and Tanner expose
-- filtered views of that same tab for bows and leather armor respectively,
-- so the gear itself comes from `grug_gear`'s own catalog (items_crafting.md
-- section 3.0.3: the vendor catalog and the base craft ladder are the same
-- items). The others sell no equipment and carry no gear tab.
--
-- Prices are in COPPER (economy.md section 1) and sit above what the vendor
-- pays for the same item as loot (prices.lua), so buying from a profession
-- vendor and selling it back is a loss; init.lua's audit 2 proves it.
--
grug_traders.profession_stock = {}

local function profession_shelf(kind, entries)
	assert(type(kind) == "string" and kind ~= "",
		"grug_traders profession shelf: kind missing")
	assert(grug_traders.profession_stock[kind] == nil,
		"grug_traders profession shelf: " .. kind .. " already has a shelf")
	local shelf = {}
	for index = 1, #entries do
		local row = entries[index]
		local price = tonumber(row[2])
		assert(type(row[1]) == "string" and row[1] ~= "" and price and
			price > 0 and price == math.floor(price),
			"grug_traders profession shelf: " .. kind .. " entry " .. index ..
			" differs")
		shelf[index] = {item = row[1], price = price,
			category = row[3] or "goods"}
	end
	grug_traders.profession_stock[kind] = shelf
	return shelf
end

-- Supplies used by every profession belong on both the core shelf and every
-- profession-only shelf, because those vendors do not merge the two lists.
-- The Decor Merchant is no trade's shop and carries none.
local NO_SUPPLIES = {culture = true}
function grug_traders.register_all_vendor_stock(def)
	grug_traders.register_stock(def)
	local source = grug_traders.stock[#grug_traders.stock]
	for kind, shelf in pairs(grug_traders.profession_stock) do
		if not NO_SUPPLIES[kind] then
			shelf[#shelf + 1] = {
				item = source.item, price = source.price, category = source.category,
			}
		end
	end
end

-- The butcher: raw and cooked meat.
profession_shelf("butcher", {
	{"mobs:meat_raw", 4},
	{"mobs:meat", 9},
})

-- The fishmonger: the ordinary catch; band fish are caught, not bought.
profession_shelf("fishmonger", {
	{"grug_mobs:raw_fish", 5},
})

-- The baker: the T1 field crops and the bread made from wild grain.
profession_shelf("baker", {
	{"grug_gathering:corn", 3},
	{"grug_gathering:potato", 3},
	{"grug_gathering:melon", 4},
	{"grug_cooking:bread", 6},
})

-- The tailor: the two wools of a settlement's beds and bolts.
profession_shelf("tailor", {
	{"wool:white", 6},
	{"wool:brown", 6},
})

-- The smith: the bronze tools. The GEAR is the T1 gear tab this vendor keeps
-- (see the note above), not a list here.
profession_shelf("smith", {
	{"grug_materials:pick_bronze", 40, "tools"},
	{"grug_materials:axe_bronze", 36, "tools"},
	{"grug_materials:shovel_bronze", 32, "tools"},
})

-- The mason: the ground a district is paved and walled with. All of it is made
-- from free stone and clay, so traders pay nothing for it (prices.lua). No
-- Cobblestone or Gravel since Round 58; the user keeps it so in Round 70
-- (plan §2.6), although buying what gives reputation is allowed now. Vendors
-- still buy them (the bulk lots).
profession_shelf("mason", {
	{"default:clay_brick", 2},
	{"default:stonebrick", 5},
	{"default:sandstonebrick", 5},
	{"default:stone_block", 6},
})

-- The brewer: the one vendor potion and an apple. The potion keeps the core
-- stock's own 8c -- it is the same item on another counter.
profession_shelf("brewer", {
	{"grug_traders:potion_healing_weak", 8},
	{"default:apple", 3},
})

-- The bowyer: player ammunition and the stick-and-feather goods behind it.
-- `grug_mobs:arrow` is the obsolete loot bundle, not usable ammunition. A
-- stick at 2c is below the buy-back floor: traders never buy sticks.
profession_shelf("bowyer", {
	{"grug_gear:arrow", 3},
	{"default:stick", 2},
	{"grug_mobs:feather", 3},
})

-- The herbalist: the potion. Herbs are gathered by Alchemists only
-- (professions.md §1), so no counter sells them to everyone; vial and
-- parchment arrive with the job supplies.
profession_shelf("herbalist", {
	{"grug_traders:potion_healing_weak", 8},
})

-- The armourer: its offer is the T1 gear tab; the General tab carries only
-- the job supplies (thread, parchment, vial).
profession_shelf("armourer", {})

-- The tanner: its gear tab filters the shared T1 gear shelf to the four
-- pieces of the matching leather grade; the General tab carries only the job
-- supplies.
profession_shelf("tanner", {})

-- The embalmer: the undead capital's own trade.
profession_shelf("embalmer", {
	{"grug_mobs:bone", 3},
	{"grug_decor:xdecor_candle", 4},
	{"grug_mobs:zombie_flesh", 5},
})

-- The Decor Merchant: affordable household details and original wall art.
-- Prices are copper, independent of player level; normal 5% buy-back applies.
-- Plain frames/stands are Basic crafts. Expedition paintings are rewards only.
-- The design and all price families live in docs/design/decorations.md.
profession_shelf("culture", {
	{"grug_decor:darkage_marble", 25},
	{"grug_decor:darkage_marble_tile", 25},
	{"grug_decor:darkage_serpentine", 25},
	{"grug_decor:darkage_slate_tile", 25},
	{"grug_decor:darkage_ors_brick", 25},
	{"grug_decor:darkage_basalt_brick", 25},
	{"grug_decor:darkage_chalked_bricks", 25},
	{"grug_decor:castle_pavement_brick", 25},
	{"grug_decor:darkage_glass_round", 25},
	{"grug_decor:darkage_glass_square", 25},
	{"grug_decor:darkage_wood_frame", 25},
	{"grug_decor:darkage_iron_grille", 25},
	{"grug_decor:xdecor_lantern", 100},
	{"grug_decor:xdecor_lantern_hanging", 1000},
	{"grug_decor:cottages_wagon_wheel", 200},
	{"grug_decor:xdecor_painting_1", 10000},
	{"grug_decor:xdecor_painting_2", 10000},
	{"grug_decor:xdecor_painting_3", 10000},
	{"grug_decor:xdecor_painting_4", 10000},
	{"grug_decor:xdecor_table", 100},
	{"grug_decor:cottages_table", 80},
	{"grug_decor:xdecor_chair", 60},
	{"grug_decor:cottages_bench", 60},
	{"grug_decor:xdecor_empty_shelf", 120},
	{"grug_decor:cottages_shelf", 100},
	{"grug_decor:xdecor_barrel", 75},
	{"grug_decor:cottages_barrel", 75},
	{"grug_decor:cottages_barrel_open", 75},
	{"grug_decor:cottages_barrel_lying", 75},
	{"grug_decor:cottages_barrel_lying_open", 75},
	{"grug_decor:cottages_tub", 60},
	{"grug_decor:cottages_washing", 100},
	{"grug_decor:xdecor_cushion", 25},
	{"grug_decor:xdecor_cushion_block", 35},
	{"grug_decor:xdecor_curtain", 50},
	{"grug_decor:xdecor_curtain_open", 50},
	{"grug_decor:xdecor_ivy", 15},
	{"grug_decor:xdecor_stonepath", 10},
	{"grug_decor:cottages_straw_mat", 15},
	{"grug_decor:cottages_straw_bale", 30},
	{"grug_decor:cottages_window_shutter_open", 35},
	{"grug_decor:cottages_window_shutter_closed", 35},
	{"grug_decor:xdecor_workbench", 150},
	{"grug_decor:xdecor_cauldron", 150},
	{"grug_decor:xdecor_candle", 4},
	{"grug_decor:xdecor_potted_dandelion_white", 30},
	{"grug_decor:xdecor_potted_dandelion_yellow", 30},
	{"grug_decor:xdecor_potted_geranium", 30},
	{"grug_decor:xdecor_potted_rose", 30},
	{"grug_decor:xdecor_potted_tulip", 30},
	{"grug_decor:xdecor_potted_viola", 30},
	{"grug_decor:xdecor_potted_tulip_black", 30},
	{"grug_decor:xdecor_potted_chrysanthemum_green", 30},
	{"grug_displays:frame_iron", 500},
	{"grug_displays:frame_carved", 800},
	{"grug_displays:frame_brass", 1500},
	{"grug_displays:armor_stand_iron", 1000},
	{"grug_displays:armor_stand_carved", 1500},
	{"grug_displays:weapon_holder", 100},
	{"grug_decor:plate_wood", 12},
	{"grug_decor:plate_ceramic", 18},
	{"grug_decor:bowl_wood", 14},
	{"grug_decor:bowl_ceramic", 20},
	{"grug_decor:jug", 28},
	{"grug_decor:mug", 12},
	{"grug_decor:bread_board", 24},
	{"grug_decor:meal_platter", 32},
	{"grug_decor:fruit_basket", 38},
	{"grug_decor:vegetable_basket", 38},
	{"grug_decor:sack_closed", 35},
	{"grug_decor:sack_grain", 42},
	{"grug_decor:crate_vegetables", 48},
	{"grug_decor:crate_fish", 48},
	{"grug_decor:crate_meat", 48},
	{"grug_decor:crate_ore", 55},
	{"grug_decor:wicker_basket", 30},
	{"grug_decor:wicker_tray", 22},
	{"grug_decor:book_stack", 35},
	{"grug_decor:book_open", 30},
	{"grug_decor:lectern", 180},
	{"grug_decor:writing_set", 45},
	{"grug_decor:scroll", 18},
	{"grug_decor:scroll_bundle", 32},
	{"grug_decor:map_sheet", 28},
	{"grug_decor:alchemy_set", 50},
	{"grug_decor:herb_bundle", 24},
	{"grug_decor:tool_board", 75},
	{"grug_decor:material_ore", 35},
	{"grug_decor:material_metal", 42},
	{"grug_decor:material_gems", 50},
	{"grug_decor:cloth_rolls", 45},
	{"grug_decor:yarn", 22},
	{"grug_decor:leather_bundle", 45},
	{"grug_decor:fur_bundle", 48},
	{"grug_decor:rope_coil", 35},
	{"grug_decor:oar", 65},
	{"grug_decor:candle_bundle", 24},
	{"grug_decor:wax_bowl", 20},
	{"grug_decor:candle_group", 110},
	{"grug_decor:sconce_iron", 320},
	{"grug_decor:sconce_wood", 240},
	{"grug_decor:chandelier", 1500},
	{"grug_decor:fire_basket", 550},
	{"grug_decor:hearth", 900},
	{"grug_decor:rug_red", 120},
	{"grug_decor:rug_green", 120},
	{"grug_decor:rug_blue", 120},
	{"grug_decor:runner_red", 160},
	{"grug_decor:runner_blue", 160},
	{"grug_decor:wall_shelf", 85},
	{"grug_decor:wall_shelf_filled", 125},
	{"grug_decor:planter", 110},
	{"grug_decor:hanging_plant", 180},
	{"grug_decor:tapestry_accord", 2500},
	{"grug_decor:tapestry_throng", 2500},
	{"grug_decor:painting_highcourt", 10000},
	{"grug_decor:painting_dur_brannoc", 10000},
	{"grug_decor:painting_lethariel", 10000},
	{"grug_decor:painting_gor_drazhak", 10000},
	{"grug_decor:painting_kezamba", 10000},
	{"grug_decor:painting_nhal_veyr", 10000},
	{"grug_decor:painting_silverwood", 5000},
	{"grug_decor:painting_marsh", 5000},
	{"grug_decor:painting_savanna", 5000},
	{"grug_decor:painting_still_life", 5000},
	{"grug_decor:painting_charter", 10000},
	{"grug_decor:painting_tavern", 5000},
	{"grug_decor:painting_trade_map", 10000},
})

--
-- The audit. A shelf entry is dropped and reported when its item is not
-- registered, is an enchant input (grug_professions/data/enchants.json stat
-- loot or family input) or is a material above T1 (prices.lua's
-- grug_traders.shelf_tier: a food's own tier, else the higher of its own and
-- its ingredient tier). The rule is cheap to break by a later shelf edit
-- and cheap to check here. A clean roster reports itself, so a check nobody
-- sees the result of does not become a check nobody notices breaking.
--

-- Enchant inputs from the enchant table; grug_professions loads after this
-- mod (it depends on it), so it is read once every mod has loaded.
local function enchant_inputs()
	local set = {}
	local professions = rawget(_G, "grug_professions")
	if professions and professions.ENCHANT_DATA then
		for _, ref in ipairs(professions.enchant_data.referenced_items(
				professions.ENCHANT_DATA)) do
			set[ref.item] = true
		end
	end
	return set
end

core.register_on_mods_loaded(function()
	local shelves = {core = grug_traders.stock}
	local names = {"core"}
	for kind, shelf in pairs(grug_traders.profession_stock) do
		shelves[kind] = shelf
		names[#names + 1] = kind
	end
	-- Sorted: `pairs` order over the shelf table is not reproducible and a log
	-- line that reorders itself is a log line nobody can diff.
	table.sort(names)
	local entries = {}
	for _, kind in ipairs(names) do
		for _, entry in ipairs(shelves[kind]) do
			entries[#entries + 1] = {kind = kind, item = entry.item}
		end
	end
	local failed = {}
	for _, finding in ipairs(grug_traders.price_rules.shelf_findings(entries,
			enchant_inputs(), grug_traders.shelf_tier)) do
		failed[finding.kind .. "\0" .. finding.item] = finding.reason
	end
	local offers, dropped = 0, {}
	for _, kind in ipairs(names) do
		local kept = {}
		for _, entry in ipairs(shelves[kind]) do
			local reason = failed[kind .. "\0" .. entry.item]
			if not core.registered_items[entry.item] then
				reason = "not registered"
			end
			if reason then
				dropped[#dropped + 1] = kind .. "=" .. entry.item .. " (" .. reason .. ")"
			else
				kept[#kept + 1] = entry
			end
		end
		-- Refill in place: vendors.lua and trade.lua hold these tables.
		for index = #shelves[kind], 1, -1 do shelves[kind][index] = nil end
		for index, entry in ipairs(kept) do shelves[kind][index] = entry end
		offers = offers + #kept
	end
	if #dropped == 0 then
		core.log("action", "[grug_traders] core stock and " .. (#names - 1) ..
			" profession shelves, " .. offers .. " offers, all registered and " ..
			"none an enchant input or above T1")
		return
	end
	core.log("error", "[grug_traders] shelf entries break the vendor rule " ..
		"(economy-vendor-plan.md §2.4) and are dropped: " .. table.concat(dropped, " "))
end)
