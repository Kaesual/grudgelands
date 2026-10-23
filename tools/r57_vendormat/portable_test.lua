-- Round 57 lane VENDORMAT portable fixture (ruling 28: no vendor sells
-- leather, cloth, ores or metal bars). Run: luajit portable_test.lua <repo>
--
-- A. Every shelf a vendor shows -- the core stock of the race and general
--    Quartermasters, the thirteen profession shelves, and the gear tab of
--    every bracket for every vendor shape vendors.lua builds -- offers none
--    of Leather, Light Leather, Linen Scrap or the Bronze Bar and no other
--    leather, cloth, ore or bar (from the material registry, the loot
--    catalogue and by name). A shelf takes no territory or level: the General
--    tab is the vendor's own shelf and the gear tab is the T1 catalog only.
-- B. Thread (with parchment and vial) still reaches every trade's shelf and
--    the core stock; the tailor still sells White and Brown Wool.
-- C. Traders still buy the four (prices.lua under registry stubs): Leather
--    and Light Leather 2c and Linen Scrap 1c by their loot class, as with the
--    old shelves put back; the Bronze Bar, off the shelves, takes the general
--    rule for processed goods, its inputs (Copper Bar + Tin Bar, 2c), where
--    its old 7c shelf capped it at 1c.
-- The engine counterpart over the real registry is tools/r57_vendormat/probe.sh.

local ROOT = arg and arg[1] or "."
local checks, failures = 0, 0
local function check(cond, message)
	checks = checks + 1
	if not cond then
		failures = failures + 1
		print("FAIL " .. message)
	end
end
local function eq(actual, expected, message)
	check(actual == expected, message .. ": expected " .. tostring(expected) ..
		", got " .. tostring(actual))
end
local function read_file(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local FOUR = {"mobs:leather", "grug_mobs:light_leather", "grug_mobs:linen_scrap",
	"grug_materials:bronze_bar"}

------------------------------------------------------------------------------
-- The forbidden set: the four, every mined resource and processed material
-- of grug_materials' registry, and every leather or cloth of the catalogue.
------------------------------------------------------------------------------
local forbidden = {}
for _, item in ipairs(FOUR) do forbidden[item] = "ruling 28" end
do
	local registry = read_file("mods/ITEMS/grug_materials/registry.lua")
	local resources = registry:match("grug_materials%.RESOURCES = (%b{})")
	local processed = registry:match("grug_materials%.PROCESSED_MATERIALS = (%b{})")
	check(resources and processed, "the material registry tables are found")
	for _, block in ipairs({resources or "", processed or ""}) do
		for field, item in block:gmatch("([%w_]+) = \"([%w_]+:[%w_]+)\"") do
			if field == "raw_item" or field == "cut_item" or field == "natural_node" or
					field == "item" or field == "bar_item" or field == "block_node" then
				forbidden[item] = forbidden[item] or "material registry " .. field
			end
		end
	end
	local catalogue = read_file("mods/ENTITIES/grug_mobs/data/items.json")
	for id, name in catalogue:gmatch('"id": "([^"]+)",%s*"name": "([^"]+)"') do
		local text = (id .. " " .. name):lower()
		for _, word in ipairs({"leather", "cloth", "linen", "silk", "hide", "pelt", "wool"}) do
			if text:find(word, 1, true) then forbidden[id] = forbidden[id] or "catalogue " .. word end
		end
	end
	check(forbidden["default:copper_lump"] and forbidden["grug_materials:iron_bar"] and
		forbidden["grug_mobs:linen_cloth"] and forbidden["grug_mobs:heavy_cloth"] and
		forbidden["grug_mobs:spider_silk"], "the forbidden set holds ores, bars and cloth")
end
-- Anything else that reads as one by name. The tailor's two wools are kept
-- (bed decor, ruling 28); equipment is not a material.
local NAME_PATTERNS = {"leather", "linen", "cloth", "silk", "pelt", "hide", "_bar$",
	"lump", "ingot", "_ore$", "stone_with_", "^wool:"}
local KEPT = {["wool:white"] = "tailor", ["wool:brown"] = "tailor"}
local function material(item, shelf, gear)
	if KEPT[item] == shelf then return nil end
	if forbidden[item] then return forbidden[item] end
	if gear then return nil end
	for _, pattern in ipairs(NAME_PATTERNS) do
		if item:find(pattern) then return "name ~ " .. pattern end
	end
	return nil
end

------------------------------------------------------------------------------
-- The shelves (stock.lua under a minimal stub).
------------------------------------------------------------------------------
core = { -- luacheck: ignore (global stub)
	register_on_mods_loaded = function() end,
	log = function() end,
	registered_items = {},
}
local GEAR_T1 = {"g:sword_t1", "g:chest_leather_t1", "g:bow_t1"}
local GEAR_DEFS = {["g:sword_t1"] = {groups = {grug_gear = 1}},
	["g:chest_leather_t1"] = {groups = {grug_gear = 1, grug_armor_class = 2}},
	["g:bow_t1"] = {groups = {grug_gear = 1, grug_bow = 1}}}
for name, def in pairs(GEAR_DEFS) do core.registered_items[name] = def end
grug_gear = {BRACKETS = {}, catalog = {}} -- luacheck: ignore
for bracket = 1, 6 do
	grug_gear.BRACKETS[bracket] = {min_level = bracket * 10 - 9, max_level = bracket * 10,
		ilvl = bracket * 10 - 9}
	grug_gear.catalog[bracket] = {all = {"g:above_t1_" .. bracket}}
end
grug_gear.catalog[1] = {all = GEAR_T1}
grug_gear.get_price = function() return 25 end
grug_traders = {} -- luacheck: ignore
dofile(ROOT .. "/mods/ENTITIES/grug_traders/stock.lua")

-- The job supplies arrive from their own mods, as at load.
local professions = read_file("mods/ITEMS/grug_professions/init.lua")
check(professions:find('{"thread", "Thread"', 1, true) and
	professions:find("grug_traders.register_all_vendor_stock", 1, true),
	"B grug_professions still registers Thread for every vendor")
check(read_file("mods/ITEMS/grug_alchemy/recipes.lua"):find(
	"grug_traders.register_all_vendor_stock({item = VIAL", 1, true),
	"B grug_alchemy still registers the vial for every vendor")
grug_traders.register_all_vendor_stock({item = "grug_professions:thread", price = 1})
grug_traders.register_all_vendor_stock({item = "grug_professions:parchment", price = 5})
grug_traders.register_all_vendor_stock({item = "vessels:glass_bottle", price = 3})

-- The General tab reads only the vendor's own shelf key (no territory, no
-- level), so checking each shelf once checks it everywhere.
local trade = read_file("mods/ENTITIES/grug_traders/trade.lua")
check(trade:find("local function general_shelf(vendor)\n\tlocal kind = vendor and vendor.stock\n" ..
	"\tif kind then\n\t\treturn grug_traders.profession_stock[kind] or {}\n\tend\n" ..
	"\treturn grug_traders.stock\nend", 1, true),
	"A the General tab is the vendor's shelf, whatever the territory or level")

-- Every vendor shape vendors.lua registers: the two Quartermaster families
-- (no stock key: the core stock and the full gear tab) and one per profession.
local vendors = {{label = "quartermaster", stock = nil}}
local kinds = {}
for kind in pairs(grug_traders.profession_stock) do kinds[#kinds + 1] = kind end
table.sort(kinds)
eq(#kinds, 13, "A thirteen profession shelves")
for _, kind in ipairs(kinds) do
	local brackets = grug_traders.PROFESSION_BRACKETS[kind]
	vendors[#vendors + 1] = {label = kind, stock = kind, brackets = brackets and true or nil,
		bracket_filter = type(brackets) == "string" and brackets or nil}
end
local vendors_lua = read_file("mods/ENTITIES/grug_traders/vendors.lua")
check(vendors_lua:find("stock = row.kind,", 1, true) and
	vendors_lua:find("brackets = grug_traders.PROFESSION_BRACKETS[row.kind] and true or nil,", 1, true),
	"A vendors.lua builds the profession vendors as this fixture does")

local function offers(list, item)
	for _, entry in ipairs(list) do if entry.item == item then return true end end
	return false
end
local SELLS_GEAR = function(vendor) return vendor.stock == nil or vendor.brackets == true end
local shelves_seen = 0
for _, vendor in ipairs(vendors) do
	local general = vendor.stock and grug_traders.profession_stock[vendor.stock] or grug_traders.stock
	shelves_seen = shelves_seen + 1
	for _, entry in ipairs(general) do
		local reason = material(entry.item, vendor.label, false)
		check(reason == nil, "A " .. vendor.label .. " offers " .. entry.item ..
			" (" .. tostring(reason) .. ")")
	end
	if vendor.label ~= "culture" then
		check(offers(general, "grug_professions:thread"), "B " .. vendor.label .. " offers Thread")
	end
	for bracket = 1, 6 do
		local tab = SELLS_GEAR(vendor) and grug_traders.vendor_bracket_stock(vendor, bracket) or {}
		for _, entry in ipairs(tab) do
			local reason = material(entry.item, vendor.label, true)
			check(reason == nil and GEAR_DEFS[entry.item] ~= nil, "A " .. vendor.label ..
				" gear " .. bracket .. " offers " .. entry.item .. " (" .. tostring(reason) .. ")")
		end
		if bracket ~= 1 then
			eq(#tab, 0, "A " .. vendor.label .. " shows no gear tab above T1 (bracket " .. bracket .. ")")
		end
	end
end
eq(shelves_seen, 14, "A the core stock and thirteen profession shelves walked")
for _, item in ipairs(FOUR) do
	for _, vendor in ipairs(vendors) do
		local general = vendor.stock and grug_traders.profession_stock[vendor.stock] or grug_traders.stock
		check(not offers(general, item), "A " .. vendor.label .. " does not sell " .. item)
	end
end
check(offers(grug_traders.profession_stock.tailor, "wool:white") and
	offers(grug_traders.profession_stock.tailor, "wool:brown"), "B the tailor sells both wools")
check(offers(grug_traders.stock, "grug_professions:thread"), "B the core stock offers Thread")
-- The two shelves left with only the supplies, as the report describes them.
eq(#grug_traders.profession_stock.armourer, 3, "A the armourer's General tab is the three supplies")
eq(#grug_traders.profession_stock.tanner, 3, "A the tanner's General tab is the three supplies")

------------------------------------------------------------------------------
-- C. Buy-back of the four (prices.lua under registry stubs).
------------------------------------------------------------------------------
do
	local REG = {
		["mobs:leather"] = {}, ["grug_mobs:light_leather"] = {},
		["grug_mobs:linen_scrap"] = {}, ["grug_materials:bronze_bar"] = {},
		["grug_materials:copper_bar"] = {}, ["grug_materials:tin_bar"] = {},
		["default:copper_lump"] = {}, ["default:tin_lump"] = {},
	}
	core.registered_items = REG
	core.get_item_group = function(name, group)
		return ((REG[name] or {}).groups or {})[group] or 0
	end
	core.get_all_craft_recipes = function(item)
		local lump = ({["grug_materials:copper_bar"] = "default:copper_lump",
			["grug_materials:tin_bar"] = "default:tin_lump"})[item]
		return lump and {{method = "cooking", output = item, items = {lump}}} or nil
	end
	grug_mobs = {read_data_json = function() return {items = { -- luacheck: ignore
		{id = "mobs:leather", kind = "generic", tier = 1},
		{id = "grug_mobs:light_leather", kind = "generic", tier = 1},
		{id = "grug_mobs:linen_scrap", kind = "generic", tier = 1},
	}} end}
	grug_materials = { -- luacheck: ignore
		RESOURCES = {{raw_item = "default:copper_lump", harvest_tier = 1},
			{raw_item = "default:tin_lump", harvest_tier = 1}},
		PROCESSED_MATERIALS = {
			{kind = "bar", item = "grug_materials:copper_bar"},
			{kind = "bar", item = "grug_materials:tin_bar"},
			{kind = "bar", tier = 1, item = "grug_materials:bronze_bar"},
		},
	}
	grug_smelting = {RECIPES = {{output = "grug_materials:bronze_bar", -- luacheck: ignore
		inputs = {"grug_materials:copper_bar", "grug_materials:tin_bar"}}}}
	grug_gear.drop_pool = {}
	for bracket = 1, 6 do grug_gear.drop_pool[bracket] = {} end
	grug_gear.get_price = function() return nil end
	grug_traders.bracket_stock = function() return {} end
	core.get_modpath = function() return ROOT .. "/mods/ENTITIES/grug_traders" end
	dofile(ROOT .. "/mods/ENTITIES/grug_traders/prices.lua")


	local function payouts()
		grug_traders.resolve_prices()
		local out = {}
		for _, item in ipairs(FOUR) do out[item] = grug_traders.sell_price(item) end
		return out
	end
	local now = payouts()
	eq(now["mobs:leather"], 2, "C Leather sells for 2c")
	eq(now["grug_mobs:light_leather"], 2, "C Light Leather sells for 2c")
	eq(now["grug_mobs:linen_scrap"], 1, "C Linen Scrap sells for 1c")
	eq(now["grug_materials:bronze_bar"], 2, "C the Bronze Bar sells for its inputs, 2c")
	-- The old shelves put back (stock.lua at main a90990d5) pay the same.
	local RETIRED = {{"butcher", "mobs:leather", 8}, {"butcher", "grug_mobs:light_leather", 6},
		{"tailor", "grug_mobs:linen_scrap", 3}, {"smith", "grug_materials:bronze_bar", 7},
		{"armourer", "grug_materials:bronze_bar", 7}, {"tanner", "mobs:leather", 8},
		{"tanner", "grug_mobs:light_leather", 6}, {"embalmer", "grug_mobs:linen_scrap", 3}}
	for _, row in ipairs(RETIRED) do
		table.insert(grug_traders.profession_stock[row[1]], {item = row[2], price = row[3]})
	end
	local OLD = payouts()
	for _, item in ipairs({"mobs:leather", "grug_mobs:light_leather", "grug_mobs:linen_scrap"}) do
		eq(now[item], OLD[item], "C " .. item .. " buys back as with the old shelves")
	end
	eq(OLD["grug_materials:bronze_bar"], 1, "C the old 7c shelf capped the Bronze Bar at 1c")
end

if failures > 0 then
	error(("R57 VENDORMAT PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R57 VENDORMAT PORTABLE PASS checks=%d"):format(checks))
