-- Round 56 lane SMALL portable test (LuaJIT; round56-plan.md §2 rulings
-- 8-10, §4 SMALL). Loads the REAL grug_inventory/storage.lua (the consumer
-- lists), grug_traders trade.lua, prices.lua and price_rules.lua, the access
-- and discount functions cut out of grug_traders/vendors.lua and stock.lua,
-- grug_factions/service.lua, grug_food/init.lua, grug_alchemy/effects.lua and
-- grug_classes' get_max_mana (cut out of stats.lua), under small stubs:
--   S  the sell list (ruling 8): items only on the inactive hotbar layout are
--      listed with no marker, a single good sells from its own slot there,
--      a lot good is counted over main and the inactive layout and taken
--      from main first, then the inactive layout;
--   Q  the Quartermaster (ruling 9): a player of the vendor's faction but
--      another race trades at the full price, the vendor's own race gets the
--      10 % discount, a player of the other faction is refused with the
--      shared line, and a faction change while the form is open closes it on
--      the next action;
--   F  mana food (ruling 10): a Warrior eats a Caster dish (eaten, instant
--      HP and HP regeneration, no mana restored, the status detail without
--      the mana parts), a Mage's detail keeps them, the item tooltip keeps
--      them, the mana pool bonus adds nothing to a pool a class does not
--      have, and a mana potion is still refused.
--
-- Usage (repo root): luajit tools/r56_small/portable_test.lua [REPO]

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
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function read(path)
	local file = assert(io.open(ROOT .. "/" .. path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end
-- A block cut out of a file by a pattern, run in the current globals.
local function cut(path, pattern, label)
	local block = read(path):match(pattern)
	check(block ~= nil, label .. " found in " .. path)
	assert(loadstring(block or "", "=" .. label))()
end
local noop = function() end

------------------------------------------------------------------------------
-- Stubs for S and Q
------------------------------------------------------------------------------
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
		return setmetatable({name = value.name, count = value.count, meta = new_meta()}, Stack)
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
function Stack:get_stack_max() return 99 end
function Stack:get_description() return self.name end
function Stack:to_string()
	return self:is_empty() and "" or (self.count == 1 and self.name or self.name .. " " .. self.count)
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
-- name).
local function new_inv(sizes)
	local lists = {}
	for list, size in pairs(sizes) do
		lists[list] = {}
		for i = 1, size do lists[list][i] = ItemStack("") end
	end
	local inv = {lists = lists}
	function inv:get_size(list) return lists[list] and #lists[list] or 0 end
	function inv:get_list(list)
		if not lists[list] then return nil end
		local out = {}
		for i, stack in ipairs(lists[list]) do out[i] = ItemStack(stack) end
		return out
	end
	function inv:get_stack(list, i) return ItemStack(lists[list][i]) end
	function inv:set_stack(list, i, stack) lists[list][i] = ItemStack(stack) end
	function inv:remove_item(list, stack)
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

local shown, closed, chat = {}, {}, {}
local us = 0
core = { -- luacheck: ignore (global stub)
	registered_items = {},
	formspec_escape = function(text)
		return (text:gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\["):gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
	show_formspec = function(name, _, formspec) shown[name] = formspec end,
	close_formspec = function(name) closed[name] = (closed[name] or 0) + 1 end,
	chat_send_player = function(name, text) chat[name] = text end,
	get_modpath = function() return ROOT .. "/mods/ENTITIES/grug_traders" end,
	get_us_time = function() return us end,
	register_on_joinplayer = noop,
	register_allow_player_inventory_action = noop,
	register_on_item_pickup = noop,
	register_on_leaveplayer = noop,
	handle_node_drops = noop,
}
local handler
function core.register_on_player_receive_fields(fn) handler = fn end
vector = {distance = function() return 0 end} -- luacheck: ignore

local purse = {}
grug_money = {MAX = 2147483647, -- luacheck: ignore
	get = function(p) return purse[p:get_player_name()] or 0 end,
	add = function(p, copper)
		purse[p:get_player_name()] = (purse[p:get_player_name()] or 0) + copper
		return true
	end,
	take = function(p, copper)
		local have = purse[p:get_player_name()] or 0
		if have < copper then return false end
		purse[p:get_player_name()] = have - copper
		return true
	end,
	format = function(copper) return copper .. "c" end}
grug_sounds = {play = noop} -- luacheck: ignore
grug_core = {item_name = function(name) return name end} -- luacheck: ignore

-- The real consumer lists: one bag, the inactive layout.
local STORE = "grug_hotbar_store"
local BAG = "grug_bag1_content"
grug_inventory = {BAG_COUNT = 1, -- luacheck: ignore
	content_list = function(i) return "grug_bag" .. i .. "_content" end}
dofile(ROOT .. "/mods/PLAYER/grug_inventory/storage.lua")
eq(grug_inventory.HOTBAR_STORE, STORE, "S the hidden list's name")
-- A purchase lands in the player's inventory; where is storage.lua's own
-- business (tools/r44_ih), not this lane's.
local given = {}
grug_inventory.fits = function() return true end
grug_inventory.give = function(p, stack) given[#given + 1] = p:get_player_name() .. ":" .. stack:to_string() end

-- Races and factions; the real refusal line.
grug_classes = {registered_races = { -- luacheck: ignore
	human = {name = "Human", faction = "accord"},
	dwarf = {name = "Dwarf", faction = "accord"},
	orc = {name = "Orc", faction = "throng"},
}}
function grug_classes.get_race(player) return player.race end
grug_factions = { -- luacheck: ignore
	get_faction = function(player) return player.faction end,
	display_name = function(id) return ({accord = "The Accord", throng = "The Throng"})[id] end,
}
dofile(ROOT .. "/mods/PLAYER/grug_factions/service.lua")

grug_traders = {} -- luacheck: ignore
dofile(ROOT .. "/mods/ENTITIES/grug_traders/prices.lua")
-- The values as the resolver would leave them: cobble 20 mc (1c per 50), a
-- gem 4c singly.
local VALUES = {["default:cobble"] = 20, ["t:gem"] = 4000}
grug_traders.sell_value = function(name) return VALUES[name] or 0 end
cut("mods/ENTITIES/grug_traders/stock.lua",
	"\n(grug_traders%.RACE_DISCOUNT = .-\nend)\n", "the discount")
cut("mods/ENTITIES/grug_traders/vendors.lua",
	"\n(function grug_traders%.get_vendor.-)\n%-%-\n%-%- Entity definition", "the access rules")
local HUMAN_QM = "grug_traders:vendor_race_human"
grug_traders.vendors = {[HUMAN_QM] = {name = HUMAN_QM, kind = "race", race = "human",
	nametag = "Human Quartermaster"}}
grug_traders.max_bracket = function() return 0 end
grug_traders.stock = {{item = "t:torch", price = 10}}
dofile(ROOT .. "/mods/ENTITIES/grug_traders/trade.lua")

local function new_player(name, race, faction, sizes)
	local inv = new_inv(sizes or {main = 16, [BAG] = 4, [STORE] = 8})
	return {name = name, race = race, faction = faction, inv = inv,
		get_player_name = function(self) return self.name end,
		get_inventory = function(self) return self.inv end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		is_player = function() return true end}
end
local function open(p)
	grug_traders.open(p, HUMAN_QM, {x = 0, y = 0, z = 0},
		grug_traders.vendor_faction(grug_traders.vendors[HUMAN_QM]))
end
local function click(p, field)
	handler(p, "grug_traders:trade", {[field] = "x"})
end
local function has(p, text) return (shown[p.name] or ""):find(text, 1, true) ~= nil end
local function at(p, list, index) return p.inv:get_stack(list, index):to_string() end

------------------------------------------------------------------------------
-- S. The sell list takes the inactive hotbar layout (ruling 8).
------------------------------------------------------------------------------
do
	-- Everything on the inactive layout only.
	local ann = new_player("ann", "human", "accord")
	ann.inv:set_stack(STORE, 3, ItemStack("t:gem 2"))
	ann.inv:set_stack(STORE, 6, ItemStack("default:cobble 60"))
	eq(table.concat(grug_inventory.consume_lists(ann.inv), ","), "main," .. BAG .. "," .. STORE,
		"S the sell list's lists: main, the bag, the inactive layout last")
	open(ann)
	click(ann, "mode_sell")
	check(has(ann, "label[1.7,2.85;t:gem x2]"), "S the gem on the inactive layout is row 1, unmarked")
	check(has(ann, "sell1_1;1]") and has(ann, "sellall_1;All (8c)]"), "S ...with 1 and All")
	check(has(ann, "label[1.7,3.65;default:cobble x60]"), "S the cobble lot is row 2, unmarked")
	check(has(ann, "sellall_2;All (1c)]"), "S ...with All (1c)")
	check(not has(ann, "You carry nothing this vendor wants."), "S the list is not empty")

	click(ann, "sell1_1")
	eq(purse.ann, 4, "S one gem sold for 4c")
	eq(at(ann, STORE, 3), "t:gem", "S ...taken from its slot on the inactive layout")
	check(has(ann, "Sold 1x t:gem for 4c."), "S ...the status line")

	-- A lot over main and the inactive layout: counted together, taken from
	-- main first (the consumer order), the rest of the lot from the layout.
	ann.inv:set_stack("main", 10, ItemStack("default:cobble 30"))
	click(ann, "mode_sell")
	check(has(ann, "default:cobble x90"), "S the lot counts main and the inactive layout (x90)")
	local lot_row = has(ann, "sellall_1;All (1c)]") and "sellall_1" or "sellall_2"
	click(ann, lot_row)
	eq(purse.ann, 5, "S one lot of 50 sold for 1c")
	eq(at(ann, "main", 10), "", "S ...main's 30 taken first")
	eq(at(ann, STORE, 6), "default:cobble 40", "S ...then 20 from the inactive layout")
	check(has(ann, "Sold 50 default:cobble for 1c. 40 left."), "S ...the status line counts right")
	eq(#given, 0, "S nothing given back")

	-- A player without the hidden list yet (no layout switch ever made)
	-- still gets main and the bag.
	local bob = new_player("bob", "human", "accord", {main = 16, [BAG] = 4})
	bob.inv:set_stack("main", 9, ItemStack("t:gem 1"))
	eq(table.concat(grug_inventory.consume_lists(bob.inv), ","), "main," .. BAG,
		"S no hidden list: main and the bag")
	open(bob)
	click(bob, "mode_sell")
	check(has(bob, "t:gem x1"), "S ...and the sell list works")
end

------------------------------------------------------------------------------
-- Q. A race's Quartermaster serves its faction; the discount stays its race's.
------------------------------------------------------------------------------
do
	local vendor = grug_traders.vendors[HUMAN_QM]
	eq(grug_traders.vendor_faction(vendor), "accord", "Q the human Quartermaster serves the Accord")
	local ann = new_player("ann_q", "human", "accord")
	local dag = new_player("dag", "dwarf", "accord")
	local org = new_player("org", "orc", "throng")
	check(grug_traders.can_trade(dag, vendor, "accord"), "Q can_trade: a dwarf of the Accord")
	check(not grug_traders.has_discount(dag, vendor), "Q ...without the discount")
	check(grug_traders.has_discount(ann, vendor), "Q the human has the discount")
	local ok, message = grug_traders.can_trade(org, vendor, "accord")
	check(not ok, "Q can_trade: an orc of the Throng is refused")
	eq(message, "<Human Quartermaster> I serve only The Accord.", "Q ...with the shared line")

	-- Through the form: the dwarf pays the full price.
	purse.dag, purse.ann_q = 100, 100
	open(dag)
	check(shown.dag ~= nil, "Q the dwarf's form opens")
	check(not has(dag, "Kinship discount"), "Q ...without the discount line")
	check(has(dag, "Price: 10c") and not has(dag, "normally"), "Q ...at the full price")
	click(dag, "buy_1")
	eq(purse.dag, 90, "Q the dwarf buys a torch for 10c")
	eq(given[#given], "dag:t:torch", "Q ...and gets it")

	-- The human gets 10 % off.
	open(ann)
	check(has(ann, "Kinship discount: -10% on every purchase"), "Q the human sees the discount line")
	check(has(ann, "Price: 9c") and has(ann, "(normally 10c)"), "Q ...and 9c instead of 10c")
	click(ann, "buy_1")
	eq(purse.ann_q, 91, "Q the human buys a torch for 9c")

	-- The other faction gets no form and the refusal line.
	open(org)
	eq(shown.org, nil, "Q the orc gets no form")
	eq(chat.org, "<Human Quartermaster> I serve only The Accord.", "Q ...but the refusal line")

	-- The re-check while the form is open: an admin moves the dwarf to the
	-- Throng; the next action closes the form and buys nothing.
	open(dag)
	dag.faction = "throng"
	local before = closed.dag or 0
	click(dag, "buy_1")
	eq(purse.dag, 90, "Q a faction change while open: nothing bought")
	eq((closed.dag or 0) - before, 1, "Q ...the form closes")
	eq(chat.dag, "<Human Quartermaster> I serve only The Accord.", "Q ...with the refusal line")
end

-- The race rule is gone from the code, and no player-facing line still
-- claims it.
check(not read("mods/ENTITIES/grug_traders/vendors.lua"):find("trades only with", 1, true),
	"Q no 'trades only with' line left")

------------------------------------------------------------------------------
-- F. Mana food for every class (ruling 10). A fresh fake engine: grug_food
-- registers every current food at load.
------------------------------------------------------------------------------
local function permissive(t)
	return setmetatable(t, {__index = function() return noop end})
end
local overrides = {}
core = permissive({ -- luacheck: ignore (global stub)
	registered_items = setmetatable({["t:skewer"] = {description = "Mushroom Skewer"}},
		{__index = function() return {} end}),
	override_item = function(name, def) overrides[name] = def end,
	get_modpath = function() return ROOT .. "/mods/ITEMS/grug_food" end,
	get_current_modname = function() return "grug_food" end,
	get_us_time = function() return 0 end,
})
minetest = core -- luacheck: ignore
vector = permissive({}) -- luacheck: ignore
local statuses, feed, mana_restored = {}, {}, {}
grug_core = permissive({ -- luacheck: ignore
	set_status = function(player, id, def)
		statuses[player.name] = def
		return {id = id}
	end,
	in_combat = function() return false end,
	can_use_item_level = function() return true end,
	status_icons = {item_icon = function() return "" end},
	feed = function(player, _, text) feed[player.name] = text end,
	trinket_instant_potion = false,
})
grug_abilities = permissive({ -- luacheck: ignore
	restore_mana = function(player, amount)
		mana_restored[player.name] = (mana_restored[player.name] or 0) + amount
		return amount
	end,
})
grug_gathering = permissive({p9g_sources = function() return {} end}) -- luacheck: ignore
grug_sounds = permissive({}) -- luacheck: ignore
grug_traders = permissive({potion_cooldown_left = function() return 0 end}) -- luacheck: ignore
grug_classes = { -- luacheck: ignore
	get_race_perk = function() return nil end,
	get_max_hp = function(player) return player.max_hp end,
	get_class_def = function(player) return {resource = player.resource} end,
	get_pool_breakdown = function(player) return {final = player.mana_pool} end,
}
-- The real get_max_mana: a class without the mana resource has no pool,
-- whatever a food's mana pool bonus adds.
cut("mods/PLAYER/grug_classes/stats.lua",
	"\n(function grug_classes%.get_max_mana%(player%).-\nend)\n", "get_max_mana")
assert(loadfile(ROOT .. "/mods/ITEMS/grug_food/init.lua"))()

local function eater(name, resource)
	local p = {name = name, hp = 100, max_hp = 1000, resource = resource, mana_pool = 1000}
	function p.get_hp(self) return self.hp end
	function p.set_hp(self, value) self.hp = value end
	function p.is_player() return true end
	function p.get_player_name(self) return self.name end
	return p
end
local function food()
	local stack = permissive({taken = 0})
	function stack.take_item(self) self.taken = self.taken + 1 end
	function stack.get_definition() return {description = "Mushroom Skewer"} end
	return stack
end

do
	local warrior, mage = eater("warrior", "rage"), eater("mage", "mana")
	eq(grug_classes.get_max_mana(warrior), 0, "F the Warrior has no mana pool")
	eq(grug_classes.get_max_mana(mage), 1000, "F the Mage has one")

	-- T3 Caster dish: 40 instant HP, 6 % HP and 6 % mana per tick, +2 % mana pool.
	local skewer = food()
	grug_food.eat(skewer, warrior, 3, "dish", "caster")
	eq(skewer.taken, 1, "F the Warrior eats the Caster dish")
	eq(feed.warrior, nil, "F ...without a refusal")
	eq(warrior.hp, 140, "F ...the instant HP")
	local status = statuses.warrior
	eq(status and status.detail, "+6% HP/5s", "F ...the status detail without the mana parts")
	eq(status and status.label, "Mushroom Skewer", "F ...the status name")
	eq(status and status.modifiers and status.modifiers.mana_pool_percent, 2,
		"F ...the status keeps the effect's modifiers (they add to no pool)")
	if status then status.on_tick(warrior) end
	eq(warrior.hp, 200, "F a tick regenerates the Warrior's HP")
	eq(mana_restored.warrior, nil, "F ...and restores no mana")

	local stew = food()
	grug_food.eat(stew, mage, 3, "dish", "caster")
	eq(stew.taken, 1, "F the Mage eats it too")
	eq(statuses.mage and statuses.mage.detail, "+6% HP, +6% Mana/5s, +2% Mana pool",
		"F ...the Mage's detail keeps the mana parts")
	if statuses.mage then statuses.mage.on_tick(mage) end
	eq(mana_restored.mage, 60, "F ...and the Mage's tick restores 6 % mana")

	-- Non-mana parts stay for the Warrior (a T3 Hearty dish's HP pool bonus).
	grug_food.eat(food(), warrior, 3, "dish", "hearty")
	eq(statuses.warrior.detail, "+6% HP/5s, +2% HP pool", "F the Warrior's Hearty detail is whole")
	eq(grug_food.status_detail(grug_food.effect_for(6, "dish", "caster"), 1, true), "+10% HP/5s",
		"F a T6 Caster dish without a mana pool")

	-- The item tooltip keeps the mana lines.
	check(grug_food.register_item("t:skewer", 3, "dish", "caster"), "F the test dish registers")
	eq(overrides["t:skewer"] and overrides["t:skewer"].description,
		"Mushroom Skewer\nRestores 40 HP instantly.\n" ..
		"Regenerates 6% of maximum HP and 6% of maximum Mana every 5 s for 5 min.\n" ..
		"Grants +2% maximum Mana while active.\n" ..
		"Cannot eat in combat. Regeneration pauses in combat; other bonuses stay.\n" ..
		"Requires level 21.\nHold RMB for 1.5 s to eat one portion.",
		"F the tooltip is unchanged and names the mana parts")

	-- A mana potion is still refused without a mana pool.
	grug_alchemy = {} -- luacheck: ignore
	dofile(ROOT .. "/mods/ITEMS/grug_alchemy/effects.lua")
	local potion = permissive({taken = 0})
	function potion.take_item(self) self.taken = self.taken + 1 end
	feed.warrior = nil
	grug_alchemy.potion_use("mana", 50)(potion, warrior)
	eq(potion.taken, 0, "F a mana potion is not drunk by the Warrior")
	eq(feed.warrior, "Mana potions have no effect without a mana pool.", "F ...the refusal line")
	grug_alchemy.potion_use("mana", 50)(potion, mage)
	eq(potion.taken, 1, "F the Mage drinks it")
end

if failures > 0 then
	error(("R56 SMALL PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R56 SMALL PORTABLE PASS checks=%d"):format(checks))
