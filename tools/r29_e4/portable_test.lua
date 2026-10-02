-- Round 29 Lane E4 portable test (LuaJIT): the respec prices from the income
-- estimate. Loads the REAL grug_classes/talents_ui.lua under a minimal stub:
--   A. the first respec is free, then the bracket price (ceil(level / 10));
--   B. a paid respec takes exactly that price; too little money leaves the
--      build untouched.
-- The mount and boat prices are covered by tools/r29_b/portable_test.lua;
-- `python3 tools/r29_e4/income.py --check` ties both tables to the estimate.
--
--   luajit tools/r29_e4/portable_test.lua [REPO]
-- Prints "R29 E4 PORTABLE PASS checks=<n>" or the failures.

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

local function noop() end
core = {
	formspec_escape = function(text) return text end,
	colorize = function(_, text) return text end,
	register_on_mods_loaded = noop,
	register_on_player_receive_fields = noop,
}
sfinv = {register_page = noop}
local level, money, spent, resets = 1, 0, 0, 0
grug_xp = {get_level = function() return level end, register_on_level_change = noop}
grug_money = {
	take = function(_, amount)
		if money < amount then return false end
		money = money - amount
		return true
	end,
	format = function(copper) return copper .. "c" end,
}
grug_classes = {
	register_on_talents_changed = noop,
	talent_points_spent = function() return spent end,
	respec = function()
		resets = resets + 1
		local returned = spent
		spent = 0
		return returned
	end,
}
dofile(ROOT .. "/mods/PLAYER/grug_classes/talents_ui.lua")

local meta = {}
local player = {get_meta = function()
	return {
		get_int = function(_, key) return meta[key] or 0 end,
		set_int = function(_, key, value) meta[key] = value end,
	}
end}

------------------------------------------------------------------------------
-- A. Prices per bracket.
------------------------------------------------------------------------------
local prices = grug_classes.RESPEC_PRICES
eq(#prices, 6, "six brackets")
for index = 2, 6 do
	check(prices[index] > prices[index - 1], "bracket " .. index .. " costs more")
end
level = 60
eq(grug_classes.respec_price(player), 0, "the first respec is free")
spent, money = 5, 0
local ok, returned, price = grug_classes.buy_respec(player)
check(ok and returned == 5 and price == 0, "free first respec without money")
for _, case in ipairs({{1, 1}, {10, 1}, {11, 2}, {20, 2}, {21, 3}, {35, 4}, {41, 5}, {59, 6}, {60, 6}}) do
	level = case[1]
	eq(grug_classes.respec_price(player), prices[case[2]], "level " .. case[1] .. " pays bracket " .. case[2])
end

------------------------------------------------------------------------------
-- B. The transaction.
------------------------------------------------------------------------------
level, spent, money, resets = 45, 7, prices[5] - 1, 0
ok, returned = grug_classes.buy_respec(player)
check(not ok and returned == "You need " .. prices[5] .. "c to respec.", "too little money refused")
eq(spent, 7, "the build is untouched")
eq(resets, 0, "no reset without payment")
money = prices[5] + 3
ok, returned, price = grug_classes.buy_respec(player)
check(ok and returned == 7 and price == prices[5], "paid respec at the bracket price")
eq(money, 3, "exactly the price taken")
spent = 0
ok, returned = grug_classes.buy_respec(player)
check(not ok and returned == "No talent ranks are spent.", "nothing to reset")

if failures > 0 then
	print(("%d checks, %d failures"):format(checks, failures))
	os.exit(1)
end
print(("R29 E4 PORTABLE PASS checks=%d"):format(checks))
