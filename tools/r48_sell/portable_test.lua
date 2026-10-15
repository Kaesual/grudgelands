-- Round 48 lane SELL portable test (LuaJIT; round48-plan.md §4.5, sell plan
-- §3.5 and §6 "SELL, window"). Loads the REAL grug_traders/trade.lua,
-- prices.lua and price_rules.lua under small stubs (the item values are a
-- table here; tools/r29_e1 checks how they are resolved) and drives the sell
-- tab through its field handler:
--   A. one row for Cobblestone in three slots over main and a bag, "1c per
--      50" and one button "All (2c)"; a single good keeps a row per slot with
--      "1" and "All"; the new hint line;
--   B. All sells whole lots over several slots with remove_item and leaves
--      the rest ("Sold 100 Cobblestone for 2c. 43 left.");
--   C. 49 Sand shows the greyed "Need 50 to sell" row without a button, and
--      a forged All or "1" for a lot row sells nothing;
--   D. a stack moved out between render and click refuses without loss;
--   E. the money ceiling refuses before anything is removed;
--   F. a single good still sells one unit, at its quality factor;
--   G. the real resolution: a block with a free 1 -> 9 unpack pays nine
--      times its item, a one-way block is halved (Round 48 Q2 ruling);
--   H. (Round 49 ruling 2) every row's image carries the tooltip of its
--      stack's own description: a quality stack shows its quality line, a
--      lot row its first stack's.
--
-- Usage (repo root): luajit tools/r48_sell/portable_test.lua [REPO]

local ROOT = arg and arg[1] or "."
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

------------------------------------------------------------------------------
-- Stubs
------------------------------------------------------------------------------
local STACK_MAX = {["default:cobble"] = 99, ["default:sand"] = 99, ["t:gem"] = 99}

local function new_meta()
	local ints, strings = {}, {}
	return {get_int = function(_, key) return ints[key] or 0 end,
		set_int = function(_, key, value) ints[key] = value end,
		get_string = function(_, key) return strings[key] or "" end,
		set_string = function(_, key, value) strings[key] = value end}
end

local Stack = {}
Stack.__index = Stack
function ItemStack(value) -- luacheck: ignore (global stub)
	if getmetatable(value) == Stack then
		local copy = setmetatable({name = value.name, count = value.count, meta = new_meta()}, Stack)
		copy.meta:set_int("grug_quality", value.meta:get_int("grug_quality"))
		copy.meta:set_string("description", value.meta:get_string("description"))
		return copy
	end
	local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)$")
	count = tonumber(count) or (name ~= "" and 1 or 0)
	if name == "" then count = 0 end
	return setmetatable({name = name, count = count, meta = new_meta()}, Stack)
end
function Stack:is_empty() return self.count == 0 or self.name == "" end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:set_count(n) self.count = n end
function Stack:get_meta() return self.meta end
function Stack:get_stack_max() return STACK_MAX[self.name] or 99 end
-- As the engine: the meta description first, else the item's own.
local DESCRIPTIONS = {["default:cobble"] = "Cobblestone", ["default:sand"] = "Sand", ["t:gem"] = "Gem"}
function Stack:get_description()
	local own = self.meta:get_string("description")
	return own ~= "" and own or DESCRIPTIONS[self.name] or self.name
end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = ItemStack(self)
	taken.count = n
	self.count = self.count - n
	if self.count == 0 then self.name = "" end
	return taken
end

-- An inventory with the engine's remove_item (from the end of the list, by
-- name, metadata ignored); remove_item calls are counted.
local removes = 0
local function new_inv(sizes)
	local lists = {}
	for list, size in pairs(sizes) do
		lists[list] = {}
		for i = 1, size do lists[list][i] = ItemStack("") end
	end
	local inv = {lists = lists}
	function inv:get_size(list) return lists[list] and #lists[list] or 0 end
	function inv:get_list(list)
		local out = {}
		for i, stack in ipairs(lists[list] or {}) do out[i] = ItemStack(stack) end
		return out
	end
	function inv:get_stack(list, i) return ItemStack(lists[list][i]) end
	function inv:set_stack(list, i, stack) lists[list][i] = ItemStack(stack) end
	function inv:remove_item(list, stack)
		removes = removes + 1
		local want, removed = stack:get_count(), ItemStack(stack:get_name())
		removed.count = 0
		for i = #lists[list], 1, -1 do
			local slot = lists[list][i]
			if removed.count >= want then break end
			if slot:get_name() == stack:get_name() then
				removed.count = removed.count + slot:take_item(want - removed.count):get_count()
			end
		end
		return removed
	end
	return inv
end
local function count_of(inv, name)
	local n = 0
	for _, list in pairs(inv.lists) do
		for _, stack in ipairs(list) do
			if stack:get_name() == name then n = n + stack:get_count() end
		end
	end
	return n
end

local shown -- the last formspec
core = { -- luacheck: ignore (global stub)
	registered_items = {},
	formspec_escape = function(text)
		return (text:gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\["):gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
	show_formspec = function(_, _, formspec) shown = formspec end,
	close_formspec = function() end,
	chat_send_player = function() end,
	get_modpath = function() return ROOT .. "/mods/ENTITIES/grug_traders" end,
}
local handler
function core.register_on_player_receive_fields(fn) handler = fn end
function core.register_on_leaveplayer() end
vector = {distance = function() return 0 end} -- luacheck: ignore

local money = 0
grug_money = {MAX = 2147483647, -- luacheck: ignore
	get = function() return money end,
	add = function(_, copper) money = math.min(money + copper, 2147483647) return true end,
	take = function(_, copper) if money < copper then return false end money = money - copper return true end,
	format = function(copper) return copper .. "c" end}
grug_sounds = {play = function() end} -- luacheck: ignore
grug_factions = {serves = function() return true end, refuse = function() end} -- luacheck: ignore
grug_core = {item_name = function(name) -- luacheck: ignore
	return ({["default:cobble"] = "Cobblestone", ["default:sand"] = "Sand", ["t:gem"] = "Gem"})[name] or name
end}
grug_inventory = { -- luacheck: ignore
	carried_lists = function(inv)
		local lists = {"main"}
		if inv:get_size("bag1") > 0 then lists[#lists + 1] = "bag1" end
		return lists
	end,
	give = function() error("nothing is given back in these cases") end,
}

grug_traders = {} -- luacheck: ignore
dofile(ROOT .. "/mods/ENTITIES/grug_traders/prices.lua")
-- The values as the resolver would leave them: cobble and sand 20 mc (1c per
-- 50), a gem 4c singly.
local VALUES = {["default:cobble"] = 20, ["default:sand"] = 20, ["t:gem"] = 4000}
grug_traders.sell_value = function(name) return VALUES[name] or 0 end
local VENDOR = {nametag = "Quartermaster"}
grug_traders.get_vendor = function() return VENDOR end
grug_traders.can_trade = function() return true end
grug_traders.has_discount = function() return false end
grug_traders.apply_discount = function(price) return price end
grug_traders.max_bracket = function() return 0 end
grug_traders.stock = {}
dofile(ROOT .. "/mods/ENTITIES/grug_traders/trade.lua")

local inv
local player = {
	get_player_name = function() return "ann" end,
	get_inventory = function() return inv end,
	get_pos = function() return {x = 0, y = 0, z = 0} end,
	is_player = function() return true end,
}
-- Fresh inventory: main 12 slots, one bag of 4; opens the sell tab.
local function setup(slots, start_money)
	inv = new_inv({main = 12, bag1 = 4})
	for _, slot in ipairs(slots) do
		inv:set_stack(slot[1], slot[2], ItemStack(slot[3]))
	end
	money = start_money or 0
	removes = 0
	grug_traders.open(player, "grug_traders:vendor_general_accord", {x = 0, y = 0, z = 0}, "accord")
	handler(player, "grug_traders:trade", {mode_sell = "Sell"})
end
local function click(field)
	handler(player, "grug_traders:trade", {[field] = "x"})
end
local function has(text) return shown:find(text, 1, true) ~= nil end

------------------------------------------------------------------------------
-- A. One row per lot good over the carried lists.
------------------------------------------------------------------------------
setup({{"main", 9, "default:cobble 50"}, {"main", 11, "default:cobble 50"},
	{"bag1", 2, "default:cobble 43"}, {"main", 10, "t:gem 2"}, {"bag1", 1, "t:gem 3"}})
check(has("Cobblestone x143"), "A one row Cobblestone x143 over main and a bag")
local _, cobble_rows = shown:gsub("Cobblestone x", "")
eq(cobble_rows, 1, "A exactly one Cobblestone row")
check(has("label[7.4,2.85;1c per 50]"), "A the first row reads 1c per 50")
check(has("button[11.5,2.50;2.0,0.7;sellall_1;All (2c)]"), "A one button All (2c)")
check(not has("sell1_1;"), "A no single button on a lot row")
check(has("Gem x2") and has("Gem x3") and has("4c each"), "A a single good keeps one row per slot")
check(has("sell1_2;1]") and has("sellall_2;All (8c)]") and has("sellall_3;All (12c)]"),
	"A single rows keep 1 and All")
check(has(core.formspec_escape("The vendor buys most things you carry.\nCheap goods sell " ..
	"in lots, e.g. 1c per 50; the rest stays with you.")), "A the new hint line")

------------------------------------------------------------------------------
-- B. All sells whole lots over several slots and leaves the rest.
------------------------------------------------------------------------------
click("sellall_1")
eq(money, 2, "B 143 Cobblestone pay 2c")
eq(count_of(inv, "default:cobble"), 43, "B 43 Cobblestone stay")
check(removes >= 1, "B the units go through remove_item")
check(has("Sold 100 Cobblestone for 2c. 43 left."), "B the status line")
eq(count_of(inv, "t:gem"), 5, "B the single goods are untouched")
check(has("Cobblestone x43") and has("Need 50 to sell"), "B the rest shows as a greyed row")

------------------------------------------------------------------------------
-- C. Below the lot size: greyed, no button, nothing sells.
------------------------------------------------------------------------------
setup({{"main", 9, "default:sand 30"}, {"bag1", 1, "default:sand 19"}})
check(has("Sand x49"), "C one row Sand x49")
check(has("Need 50 to sell") and has("\27(c@#8a8a8a)"), "C the row is greyed with Need 50 to sell")
check(not has("sellall_1") and not has("sell1_1"), "C no button")
click("sellall_1")
click("sell1_1")
eq(money, 0, "C a forged All or 1 sells nothing")
eq(count_of(inv, "default:sand"), 49, "C nothing removed")
setup({{"main", 9, "default:sand 60"}})
click("sell1_1")
eq(money, 0, "C a forged 1 on a sellable lot row sells nothing")
eq(count_of(inv, "default:sand"), 60, "C ...and removes nothing")

------------------------------------------------------------------------------
-- D. A stack moved out between render and click refuses without loss.
------------------------------------------------------------------------------
setup({{"main", 9, "default:cobble 60"}, {"bag1", 1, "default:cobble 40"}})
check(has("Cobblestone x100") and has("All (2c)"), "D shown: 100 Cobblestone for 2c")
inv:set_stack("bag1", 1, ItemStack("")) -- moved into a chest
click("sellall_1")
eq(money, 0, "D nothing paid")
eq(count_of(inv, "default:cobble"), 60, "D nothing removed")
check(has("Your items have changed."), "D the refusal re-renders")
check(has("Cobblestone x60"), "D the fresh row")

------------------------------------------------------------------------------
-- E. The money ceiling refuses before anything is removed.
------------------------------------------------------------------------------
setup({{"main", 9, "default:cobble 99"}, {"main", 10, "default:cobble 1"}}, grug_money.MAX - 1)
click("sellall_1")
eq(money, grug_money.MAX - 1, "E no money added")
eq(count_of(inv, "default:cobble"), 100, "E nothing removed")
eq(removes, 0, "E remove_item never called")
check(has("You cannot carry that much money."), "E the refusal")

------------------------------------------------------------------------------
-- F. A single good sells one unit at its quality factor.
------------------------------------------------------------------------------
local blue = ItemStack("t:gem 2")
blue:get_meta():set_int("grug_quality", 2)
setup({})
inv:set_stack("main", 9, blue)
handler(player, "grug_traders:trade", {mode_sell = "Sell"})
check(has("12c each"), "F a blue gem sells at x3")
click("sell1_1")
eq(money, 12, "F one sold for 12c")
eq(count_of(inv, "t:gem"), 1, "F one left")

------------------------------------------------------------------------------
-- H. Each row's image carries its stack's own tooltip.
------------------------------------------------------------------------------
do
	local fine = ItemStack("t:gem 1")
	fine:get_meta():set_int("grug_quality", 3)
	fine:get_meta():set_string("description", "Gem\nQuality: Fine")
	setup({{"main", 9, "default:cobble 50"}})
	inv:set_stack("main", 10, fine)
	inv:set_stack("bag1", 1, ItemStack("t:gem 2"))
	handler(player, "grug_traders:trade", {mode_sell = "Sell"})
	check(has("item_image[0.7,2.50;0.7,0.7;default:cobble]tooltip[0.7,2.50;0.7,0.7;Cobblestone]"),
		"H the lot row's image carries its tooltip")
	check(has("item_image[0.7,3.30;0.7,0.7;t:gem]tooltip[0.7,3.30;0.7,0.7;" ..
		core.formspec_escape("Gem\nQuality: Fine") .. "]"),
		"H a quality stack's tooltip shows its own description")
	check(has("tooltip[0.7,4.10;0.7,0.7;Gem]"), "H a plain stack shows the item's description")
	local _, tips = shown:gsub("tooltip%[", "")
	eq(tips, 3, "H one tooltip per row")
end

------------------------------------------------------------------------------
-- G. The real resolution (prices.lua under registry stubs): a block that nine
-- items pack into and that unpacks into the nine back pays nine times its item
-- (no halving); a block that does not unpack is a crafted good (halved).
------------------------------------------------------------------------------
do
	local GROUPS = {["t:lump"] = {grug_trash_loot = 1}}
	core.registered_items = {["t:lump"] = {}, ["t:lumpblock"] = {}, ["t:oneway"] = {}}
	core.get_item_group = function(name, group) return (GROUPS[name] or {})[group] or 0 end
	core.get_all_craft_recipes = function() return {} end
	grug_jobs = {recipes = { -- luacheck: ignore
		{output = "t:lumpblock", count = 1, area = "basic", ingredients = {{item = "t:lump", n = 9}}},
		{output = "t:lump", count = 9, area = "basic", ingredients = {{item = "t:lumpblock", n = 1}}},
		{output = "t:oneway", count = 1, area = "basic", ingredients = {{item = "t:lump", n = 9}}},
	}, ingredient_token = function(entry) return entry.item end}
	grug_mobs = {read_data_json = function() return {} end} -- luacheck: ignore
	grug_materials = {RESOURCES = {}, PROCESSED_MATERIALS = {}} -- luacheck: ignore
	grug_gear = {BRACKETS = {}, drop_pool = {}} -- luacheck: ignore
	grug_traders = {stock = {}, profession_stock = {}, GEAR_BRACKET = 1, -- luacheck: ignore
		bracket_stock = function() return {} end, discounted_price = function(p) return p end}
	dofile(ROOT .. "/mods/ENTITIES/grug_traders/prices.lua")
	grug_traders.resolve_prices()
	eq(grug_traders.sell_price("t:lump"), 1, "G a trash lump pays 1c")
	eq(grug_traders.sell_price("t:lumpblock"), 9, "G a block that unpacks for free pays nine lumps")
	eq(grug_traders.sell_price("t:oneway"), 4, "G a block without the way back is halved (9c / 2)")
end

if failures > 0 then
	error(("R48 SELL PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R48 SELL PORTABLE PASS checks=%d"):format(checks))
