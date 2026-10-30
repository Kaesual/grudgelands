-- Round 53 lane INTEG portable test (LuaJIT): the online part of the
-- migration step 0.53.0 (grug_core/migrations.lua; the offline step is
-- tools/migration/steps/v0_53_0.py, its tests tools/r53_ms/test_step.py and
-- e2e.py) and the class HP factors of 0.53.0 (grug_classes/stats.lua). It
-- stays in tools/run_fixtures.sh for good: the old handler runs against new
-- game code (round workflow §3 "Migration steps").
--
-- Loads the REAL grug_core/migrations.lua and grug_classes/stats.lua under
-- minimal stubs:
--   A. the registry: 0.53.0 listed last, after 0.48.0, with a character
--      handler only;
--   B. a character with a class gets exactly "Your talent points have been
--      reset." through chat, once per run, and nothing else is touched (its
--      inventory, meta and properties are not read or written);
--   C. a character without a class gets nothing; without grug_classes the
--      handler does nothing;
--   D. the HP class factors: Warrior 1.2, Scout 1.0, Priest 0.8, Mage 0.8
--      (no class: 1); the maximum HP at levels 1, 30 and 60 is the base pool
--      times the factor, rounded;
--   E. a Mage saved with full HP under the 0.52.1 factor joins: apply_stats
--      lowers the maximum and clamps the HP to it, with the clamp marker.
--
--   luajit tools/r53_ms/portable_test.lua [REPO]
-- Prints "R53 MS PORTABLE PASS checks=<n>" or the failures (exit 1).

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

local LINE = "Your talent points have been reset."
local sent = {}
local function noop() end
core = setmetatable({
	chat_send_player = function(name, text) sent[#sent + 1] = {name = name, text = text} end,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
	return nil
end})
grug_core = {}

-- A player that fails on everything but its name (B): the handler may only
-- name it and ask grug_classes for its class.
local function strict_player(name, class)
	return setmetatable({class = class}, {__index = function(_, key)
		if key == "get_player_name" then return function() return name end end
		error("the 0.53.0 handler touched player:" .. tostring(key), 2)
	end})
end

dofile(ROOT .. "/mods/CORE/grug_core/migrations.lua")
local registry = grug_core.migrations

-- A. The registry.
-- Round 67 lists 0.67.0 after it: 0.53.0 is listed, right after 0.48.0.
local listed = {}
for index, version in ipairs(registry.versions) do listed[version] = index end
check(listed["0.53.0"] ~= nil, "A 0.53.0 is a declared step")
eq(listed["0.48.0"] and listed["0.48.0"] + 1, listed["0.53.0"], "A after 0.48.0")
local handler = registry.handlers["0.53.0"]
check(handler and type(handler.character) == "function" and handler.world == nil,
	"A 0.53.0 has a character handler and no world handler")
local run = handler.character

-- B, C. The chat line.
grug_classes = {get_class = function(player) return rawget(player, "class") end}
local ok, err = pcall(run, strict_player("mira", "mage"), "1")
check(ok, "B the handler runs for a Mage: " .. tostring(err))
eq(#sent, 1, "B one chat line")
eq(sent[1] and sent[1].name, "mira", "B to the character")
eq(sent[1] and sent[1].text, LINE, "B the exact line")
for _, class in ipairs({"warrior", "priest", "scout"}) do
	sent = {}
	run(strict_player("p_" .. class, class), "1")
	check(#sent == 1 and sent[1].text == LINE and sent[1].name == "p_" .. class,
		"B one line for a " .. class)
end
sent = {}
ok, err = pcall(run, strict_player("nobody", nil), "1")
check(ok, "C the handler runs for a character without a class: " .. tostring(err))
eq(#sent, 0, "C no line without a class")
grug_classes = nil
ok, err = pcall(run, strict_player("early", "mage"), "1")
check(ok and #sent == 0, "C without grug_classes: no error, no line " .. tostring(err))

-- D. The HP class factors (the REAL stats.lua).
local level = 30
grug_core = {
	base_pool = function(l)
		l = math.max(1, math.min(60, math.floor(tonumber(l) or 1)))
		return math.floor(20 + 5 * l + 0.66 * l * l + 0.5)
	end,
	status_modifier_sum = function() return 0 end,
	MAX_HP_CLAMP_CUSTOM_TYPE = "grug_max_hp_clamp",
}
setmetatable(grug_core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
	return nil
end})
grug_xp = {get_level = function() return level end, register_on_level_change = noop}
local CLASSES = {warrior = {growth = {str = 3, dex = 1}}, mage = {growth = {int = 3, dex = 1}},
	priest = {growth = {str = 1, int = 2, dex = 1}}, scout = {growth = {str = 1, int = 1, dex = 2}}}
grug_classes = {
	get_class = function(player) return player.class end,
	get_class_def = function(player) return CLASSES[player.class] end,
	get_talent_bonus = function() return 0 end,
}
dofile(ROOT .. "/mods/PLAYER/grug_classes/stats.lua")
local WANT = {warrior = 1.2, scout = 1.0, priest = 0.8, mage = 0.8}
for class, factor in pairs(WANT) do
	eq(grug_classes.get_hp_class_factor({class = class}), factor, "D " .. class .. " factor")
	for _, l in ipairs({1, 30, 60}) do
		level = l
		eq(grug_classes.get_max_hp({class = class}),
			math.floor(grug_core.base_pool(l) * factor + 0.5),
			"D " .. class .. " maximum HP at level " .. l)
	end
end
eq(grug_classes.get_hp_class_factor({}), 1, "D no class: factor 1")
level = 30
eq(grug_classes.get_max_hp({class = "mage"}), 611, "D a level-30 Mage: 611 HP (764 x 0.8)")
eq(grug_classes.get_max_hp({class = "priest"}), 611, "D a level-30 Priest: 611 HP")
eq(grug_classes.get_max_hp({class = "warrior"}), 917, "D a level-30 Warrior: 917 HP")
eq(grug_classes.get_max_hp({class = "scout"}), 764, "D a level-30 Scout: 764 HP")

-- E. A Mage joins with the HP 0.52.1 saved (full at 0.9: 688 at level 30).
local mage = {class = "mage", hp = 688, props = {hp_max = 20}, reasons = {}}
function mage:get_properties() return {hp_max = self.props.hp_max} end
function mage:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
function mage:get_hp() return self.hp end
function mage:set_hp(hp, reason)
	self.hp = hp
	self.reasons[#self.reasons + 1] = reason
end
grug_classes.apply_stats(mage)
eq(mage.props.hp_max, 611, "E the maximum drops to 611")
eq(mage.hp, 611, "E the saved 688 HP clamped to it")
check(mage.reasons[1] and mage.reasons[1].custom_type == "grug_max_hp_clamp",
	"E the clamp carries grug_core's clamp marker (no damage)")

if failures > 0 then
	error("R53 MS PORTABLE FAIL failures=" .. failures .. " checks=" .. checks, 0)
end
print("R53 MS PORTABLE PASS checks=" .. checks)
