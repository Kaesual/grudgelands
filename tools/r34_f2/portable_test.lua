-- Round 34 lane F2 portable test (LuaJIT; round34-plan.md §2.3, §4.6).
-- Loads the REAL files under small stubs and checks:
--   A. the Bag of Coins (grug_money/init.lua and coins.lua): the dialog's
--      amount parsing; a withdrawal takes the money and puts one bag holding
--      it (stack_max 1, the amount in its tooltip) into the first empty main
--      slot in one transaction; refusals (no amount, not a whole number, more
--      than the balance, a full inventory) change nothing; the deposit slot
--      takes only a filled bag that fits under grug_money.MAX, destroys it
--      and credits it, and gives nothing back;
--   B. traders: the real price module (grug_traders/prices.lua) pays 0 for a
--      bag, so the sell tab lists it nowhere and the sell path refuses it;
--   C. the damage fit (grug_core/combat.lua): with the Strength fraction a
--      same-level baseline fight of eight swings meets the pool at every
--      level 1-60;
--   D. cooking (grug_cooking/init.lua): within each tier the Caster dish,
--      the strongest (HP and mana regeneration), costs more input value
--      than the Hearty and the Hunter dish.
-- Thin ice is checked in tools/r31_da2, the encounter adds in tools/r33_c1,
-- the map markers in tools/r26_map.
--
-- Usage (repo root): luajit tools/r34_f2/portable_test.lua [REPO]

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
local function read_file(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), "cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end
function string.trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

-- ItemStack double with real metadata semantics (as tools/r33_c5).
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
	return meta
end
ItemStack = function(source)
	local name, count, fields = "", 0, {}
	if type(source) == "table" then
		name, count = source:get_name(), source:get_count()
		for k, v in pairs(source:get_meta().fields) do fields[k] = v end
	elseif type(source) == "string" and source ~= "" then
		name, count = source, 1
	end
	local meta = new_meta(fields)
	local stack = {}
	function stack:get_name() return name end
	function stack:get_count() return count end
	function stack:is_empty() return name == "" or count <= 0 end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[name] or {} end
	function stack:equals(other)
		if other:get_name() ~= name or other:get_count() ~= count then return false end
		local a, b = meta.fields, other:get_meta().fields
		for k, v in pairs(a) do if b[k] ~= v then return false end end
		for k, v in pairs(b) do if a[k] ~= v then return false end end
		return true
	end
	return stack
end

local joins, leaves, receivers, detached, shown = {}, {}, {}, {}, {}
local feed = {}
core = {
	registered_items = registered,
	get_modpath = function(name)
		return ({grug_money = ROOT .. "/mods/PLAYER/grug_money",
			grug_traders = ROOT .. "/mods/ENTITIES/grug_traders"})[name]
	end,
	register_craftitem = function(name, def) registered[name] = def end,
	register_chatcommand = function() end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_player_receive_fields = function(fn) receivers[#receivers + 1] = fn end,
	create_detached_inventory = function(name, callbacks, owner)
		local lists = {}
		local inv = {callbacks = callbacks, owner = owner, lists = lists}
		function inv:set_size(list, size)
			lists[list] = {}
			for i = 1, size do lists[list][i] = ItemStack("") end
		end
		function inv:get_stack(list, i) return ItemStack(lists[list][i]) end
		function inv:set_stack(list, i, stack) lists[list][i] = ItemStack(stack) end
		detached[name] = inv
		return inv
	end,
	remove_detached_inventory = function(name) detached[name] = nil end,
	show_formspec = function(name, formname, fs) shown[#shown + 1] = {name, formname, fs} end,
	formspec_escape = function(text) return text end,
	colorize = function(_, text) return text end,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_all_craft_recipes = function() return nil end,
}
grug_core = {feed = function(_, kind, text) feed[#feed + 1] = text end}

local function new_player(name, money, slots)
	local main = {}
	for i = 1, slots or 4 do main[i] = ItemStack("") end
	local inv = {}
	function inv:get_size(list) return list == "main" and #main or 0 end
	function inv:get_stack(_, i) return ItemStack(main[i]) end
	function inv:set_stack(_, i, stack) main[i] = ItemStack(stack); return true end
	local meta = new_meta()
	local p = {main = main}
	function p:is_player() return true end
	function p:get_player_name() return name end
	function p:get_inventory() return inv end
	function p:get_meta() return meta end
	function p:get_inventory_formspec() return "inventory" end
	grug_money.set(p, money)
	return p
end

------------------------------------------------------------------------------
-- A. The Bag of Coins
------------------------------------------------------------------------------
dofile(ROOT .. "/mods/PLAYER/grug_money/init.lua")
local BAG = grug_money.BAG
do
	local def = registered[BAG]
	check(def and def.stack_max == 1 and def.inventory_image == "grug_money_bag_of_coins.png",
		"A the bag is registered, one per stack")
	check(io.open(ROOT .. "/mods/PLAYER/grug_money/textures/grug_money_bag_of_coins.png", "rb") ~= nil and
		read_file("mods/PLAYER/grug_money/LICENSE-media.md"):find("grug_money_bag_of_coins.png", 1, true),
		"A its texture ships with a licence row")

	-- The dialog's fields.
	local parse = grug_money.parse_amount
	check(parse("1", "2", "3") == 10203, "A 1g 2s 3c is 10203 copper")
	check(parse("", " 5 ", "") == 500, "A empty fields count 0, spaces are trimmed")
	check(parse("0", "0", "250") == 250, "A any whole number per field")
	for _, bad in ipairs({{"", "", ""}, {"0", "0", "0"}, {"-1", "", ""}, {"1.5", "", ""},
			{"", "abc", ""}, {"", "", "1e3"}, {"inf", "", ""}, {"nan", "", ""}}) do
		check(parse(bad[1], bad[2], bad[3]) == nil,
			"A refused: '" .. table.concat(bad, "', '") .. "'")
	end

	-- Withdraw.
	local p = new_player("giver", 20000)
	p.main[1] = ItemStack("default:dirt")
	local changes = 0
	grug_money.register_on_change(function() changes = changes + 1 end)
	local ok = grug_money.withdraw(p, 12345)
	local bag = p.main[2]
	check(ok and grug_money.get(p) == 20000 - 12345, "A a withdrawal takes the amount")
	check(bag:get_name() == BAG and grug_money.bag_amount(bag) == 12345,
		"A ...into one bag in the first empty slot")
	check(bag:get_meta():get_string("description"):find("1g 23s 45c", 1, true) ~= nil,
		"A the tooltip shows the amount")
	check(changes == 1, "A one balance change")
	local function unchanged(label, amount)
		local before, main = grug_money.get(p), {}
		for i = 1, #p.main do main[i] = ItemStack(p.main[i]) end
		local done, why = grug_money.withdraw(p, amount)
		local same = grug_money.get(p) == before
		for i = 1, #p.main do same = same and p.main[i]:equals(main[i]) end
		check(not done and type(why) == "string" and same, "A refused, nothing changes: " .. label)
	end
	unchanged("0", 0)
	unchanged("a fraction", 1.5)
	unchanged("negative", -5)
	unchanged("NaN", 0 / 0)
	unchanged("more than the balance", grug_money.get(p) + 1)
	p.main[3], p.main[4] = ItemStack("default:dirt"), ItemStack("default:dirt")
	unchanged("a full inventory", 1)

	-- The dialog: a full inventory refusal re-shows it with the reason, a
	-- success closes it and returns to the inventory.
	local receive = receivers[#receivers]
	shown = {}
	receive(p, "grug_money:withdraw", {grug_money_confirm = "Withdraw",
		grug_money_gold = "", grug_money_silver = "", grug_money_copper = "5"})
	check(shown[1] and shown[1][2] == "grug_money:withdraw" and
		shown[1][3]:find("Your inventory is full.", 1, true), "A the dialog shows the refusal")
	p.main[4] = ItemStack("")
	shown = {}
	receive(p, "grug_money:withdraw", {key_enter = "true", key_enter_field = "grug_money_copper",
		grug_money_gold = "", grug_money_silver = "", grug_money_copper = "5"})
	check(shown[1] and shown[1][2] == "" and grug_money.bag_amount(p.main[4]) == 5,
		"A Enter withdraws and returns to the inventory")

	-- Deposit through the player's detached slot.
	local q = new_player("taker", 100)
	for _, fn in ipairs(joins) do fn(q) end
	local location, list = grug_money.deposit_location(q)
	local inv = detached[location:match("^detached:(.+)$")]
	check(inv and inv.owner == "taker" and #inv.lists[list] == 1, "A one deposit slot, shown to its owner")
	local cb = inv.callbacks
	check(cb.allow_put(inv, list, 1, bag, p) == 0, "A another player cannot use the slot")
	check(cb.allow_put(inv, list, 1, ItemStack("default:dirt"), q) == 0, "A only a bag is taken")
	check(cb.allow_put(inv, list, 1, ItemStack("default:dirt"), q) == 0 and
		feed[#feed] == "Only a Bag of Coins can be deposited.", "A ...with its reason")
	check(cb.allow_put(inv, list, 1, ItemStack(BAG), q) == 0 and
		feed[#feed] == "This Bag of Coins is empty.", "A an empty bag is refused as empty")
	check(cb.allow_take(inv, list, 1, bag, q) == 0 and cb.allow_move(inv, list, 1, list, 1, 1, q) == 0,
		"A nothing can be taken or moved")
	check(cb.allow_put(inv, list, 1, bag, q) == 1, "A a filled bag is taken")
	inv:set_stack(list, 1, bag) -- the engine moves it, then calls on_put
	cb.on_put(inv, list, 1, bag, q)
	check(grug_money.get(q) == 100 + 12345 and inv:get_stack(list, 1):is_empty(),
		"A on_put destroys the bag and credits its amount")
	grug_money.set(q, grug_money.MAX - 10)
	check(cb.allow_put(inv, list, 1, grug_money.make_bag(11), q) == 0 and
		feed[#feed] == "You cannot carry that much money.", "A refused above grug_money.MAX")
	check(cb.allow_put(inv, list, 1, grug_money.make_bag(10), q) == 1, "A ...up to MAX")
	for _, fn in ipairs(leaves) do fn(q) end
	check(detached[location:match("^detached:(.+)$")] == nil, "A the slot goes with the player")
end

------------------------------------------------------------------------------
-- B. Traders pay nothing for a bag (the real price module).
------------------------------------------------------------------------------
do
	registered["mobs:meat_raw"] = {groups = {}}
	grug_traders = {stock = {}, profession_stock = {}, GEAR_BRACKET = 1,
		bracket_stock = function() return {} end}
	grug_mobs = {read_data_json = function() return {} end}
	grug_materials = {RESOURCES = {}, PROCESSED_MATERIALS = {}}
	grug_gear = {BRACKETS = {}, drop_pool = {}}
	dofile(ROOT .. "/mods/ENTITIES/grug_traders/prices.lua")
	grug_traders.resolve_prices()
	check(grug_traders.sell_price("mobs:meat_raw") == 1, "B the price module runs (raw meat 1c)")
	check(grug_traders.sell_price(BAG) == 0 and
		grug_traders.stack_sell_price(grug_money.make_bag(500)) == 0,
		"B a Bag of Coins pays 0, whatever it holds")
	local trade = read_file("mods/ENTITIES/grug_traders/trade.lua")
	check(trade:find("if unit > 0 then", 1, true) and
		trade:find("if unit <= 0 then\n\t\tshow(player, \"The vendor does not want that.\")", 1, true),
		"B the sell tab lists only paying stacks and the sell path refuses the rest")
	local function sold(path)
		local text = read_file(path)
		return text:find("bag_of_coins", 1, true) ~= nil
	end
	check(not sold("mods/ENTITIES/grug_traders/stock.lua") and
		not sold("mods/ENTITIES/grug_traders/vendors.lua"), "B no vendor sells it")
end

------------------------------------------------------------------------------
-- C. The damage fit with the Strength fraction.
------------------------------------------------------------------------------
do
	local source = read_file("mods/CORE/grug_core/combat.lua")
	local body = source:match("(function grug_core%.base_pool%(level%).-\nfunction grug_core%.level_scale%(level%).-\nend)\n")
	check(body ~= nil, "C the fit block is found in combat.lua")
	grug_core = {}
	assert(loadstring(body))()
	local worst = 0
	for level = 1, 60 do
		local live = grug_core.baseline_weapon_damage(level) + (10 + 3 * (level - 1)) / 10
		local fight = 8 * live * grug_core.level_scale(level)
		worst = math.max(worst, math.abs(fight / grug_core.base_pool(level) - 1))
	end
	check(worst < 1e-9, "C eight same-level baseline swings meet the pool at every level (" ..
		worst .. ")")
end

------------------------------------------------------------------------------
-- D. Cooking: the stronger dish costs more within its tier.
------------------------------------------------------------------------------
do
	local routes = {}
	core = {registered_items = setmetatable({}, {__index = function(_, name)
			return {description = name, groups = {}}
		end}),
		register_craftitem = function() end, override_item = function() end,
		register_craft = function() end}
	grug_food = {register_item = function() return true end}
	grug_jobs = {register_ingredient_tier = function() end,
		register_recipe = function(def) routes[#routes + 1] = def end}
	dofile(ROOT .. "/mods/ITEMS/grug_cooking/init.lua")
	local rules = dofile(ROOT .. "/mods/ENTITIES/grug_traders/price_rules.lua")
	-- The tier the price module resolves for each input (its own tier; a
	-- group counts its cheapest member), measured by the Round 34 engine
	-- probe; every one is a raw or trash good worth class value 1.
	local TIER = {
		["mobs:meat_raw"] = 1, ["grug_mobs:raw_fish"] = 1,
		["group:grug_cooking_staple"] = 1, ["group:grug_cooking_root"] = 1,
		["group:grug_cooking_berry"] = 1, ["group:grug_cooking_fruit"] = 1,
		["group:grug_cooking_early_spice"] = 1, ["grug_cooking:wild_grain"] = 1,
		["grug_cooking:sugar_cane"] = 1, ["grug_gathering:corn"] = 1,
		["grug_gathering:melon"] = 1, ["grug_cooking:pumpkin"] = 2,
		["grug_gathering:mushroom"] = 3, ["grug_cooking:cave_cap"] = 3,
		["grug_cooking:frost_melon"] = 3, ["grug_gathering:marshbloom"] = 4,
		["grug_gathering:stormkelp"] = 5, ["grug_gathering:rock_salt"] = 5,
		["grug_cooking:salt_crust"] = 5, ["grug_gathering:wild_cocoa"] = 6,
	}
	local function cost(inputs)
		local sum = 0
		for _, item in ipairs(inputs) do
			check(TIER[item] ~= nil, "D a known input: " .. item)
			sum = sum + rules.payout("raw", TIER[item] or 1)
		end
		return sum
	end
	local raw = {}
	for _, row in ipairs(grug_cooking.RAW_ASSEMBLIES) do raw[row.output] = row.inputs end
	local by_tier = {}
	for _, dish in ipairs(grug_cooking.DISHES) do
		by_tier[dish.tier] = by_tier[dish.tier] or {}
		by_tier[dish.tier][dish.role] = cost(dish.inputs or raw[dish.item])
	end
	for tier = 1, 6 do
		local row = by_tier[tier]
		check(row and row.caster > row.hearty and row.caster > row.hunter,
			("D T%d: Caster %s > Hearty %s and Hunter %s"):format(tier,
				tostring(row and row.caster), tostring(row and row.hearty),
				tostring(row and row.hunter)))
	end
end

print(("R34 F2 PORTABLE %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL",
	checks, failures))
if failures > 0 then error("R34 F2 PORTABLE FAIL", 0) end
