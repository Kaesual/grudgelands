-- Round 36 lane K portable test (class fine-tuning, round36-plan.md §2.12,
-- the user's picks of 2026-10-05). Loads the REAL grug_classes/stats.lua, the
-- real fit block and damage settlement of grug_core/combat.lua, the real
-- support/spell helpers, Fireball's and Smite's values cut out of
-- grug_abilities/kits.lua and the real enchant curves of grug_quality, and
-- checks:
--   A. the support factor: 1 + gear Int / 10 / B(L), where gear Int is the
--      Intelligence above the class's own level growth; exactly 1 without
--      Intelligence gear (Priest and Mage), and support_value feeds it;
--   B. the Priest's Heal rises with Intelligence as the Mage's Fireball does:
--      a full Intelligence set at item level 60 and 70 gives the same gain on
--      Heal as on a Mage's Fireball (+35 % / +44 % at level 60), against
--      +13 % / +17 % under the old 1 + Int/1000;
--   C. the Dexterity curve (c = 0.0011): tier tops 13 / 14 / 15 at item
--      level 60 / 65 / 70, and the Scout's full damage set lands in the band
--      (45-60 % at item level 60, no higher than the Warrior at 65 and 70);
--   D. spells floor once after the level scalar: spell_damage_value keeps
--      fractions, Fireball and Smite settle to 337 and 437 at level 60
--      (339 and 439 with the old pre-scalar rounding), Smite's inner rounding
--      is gone;
--   E. "(30% cap holds)" on Keen Edge, Cold Eye, Firebrand and Hard Faith.
--
-- Usage (repo root): luajit tools/r36_k/portable_test.lua [REPO]
local ROOT = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function near(a, b, label, eps)
	check(math.abs(a - b) < (eps or 1e-9), label .. " (" .. tostring(a) ..
		" vs " .. tostring(b) .. ")")
end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), "cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function cut(text, pattern, label)
	local chunk = text:match(pattern)
	check(chunk ~= nil, label .. " is found")
	return chunk
end

-- The real fit block and the damage settlement of grug_core.
grug_core = {}
local combat = read("mods/CORE/grug_core/combat.lua")
assert(loadstring(cut(combat, "(function grug_core%.base_pool%(level%).-\n" ..
	"function grug_core%.level_scale%(level%).-\nend)\n", "the fit block")))()
assert(loadstring(cut(combat, "(function grug_core%.level_malus%(.-\nend)\n", "level_malus")))()
assert(loadstring(cut(combat, "(function grug_core%.scale_player_damage%(.-\nend)\n",
	"scale_player_damage")))()

-- Stubs for stats.lua: a player is {class, level, gear_int}.
local GROWTH = {warrior = {str = 3, int = 0, dex = 1}, mage = {str = 0, int = 3, dex = 1},
	priest = {str = 1, int = 2, dex = 1}, scout = {str = 1, int = 1, dex = 2}}
grug_core.get_player_level = function(player) return player.level end
grug_core.status_modifier_sum = function() return 0 end
grug_core.absorb_modifier = function() return 0 end
grug_core.register_on_status_modifiers_changed = function() end
grug_core.register_on_equipment_change = function() end
grug_xp = {get_level = function(player) return player.level end,
	register_on_level_change = function() end}
grug_classes = {
	get_class = function(player) return player.class end,
	get_class_def = function(player) return {growth = GROWTH[player.class]} end,
	get_talent_bonus = function(player, key) return (player.talents or {})[key] or 0 end,
	get_scout_dodge_add = function() return 0 end,
	get_scout_dodge_cap = function() return 30 end,
}
dofile(ROOT .. "/mods/PLAYER/grug_classes/stats.lua")
-- grug_quality's override adds the equipment's attributes.
local level_attributes = grug_classes.get_attributes
grug_classes.get_attributes = function(player)
	local a = level_attributes(player)
	a.int = a.int + (player.gear_int or 0)
	return a
end

-- The real enchant curves and rule (grug_quality/init.lua).
local quality = read("mods/ITEMS/grug_quality/init.lua")
local CURVES = assert(loadstring("return " .. cut(quality,
	"local CURVES = (%b{})", "grug_quality CURVES")))()
local function enchant(stat, ilvl)
	local tier = math.min(7, math.floor((ilvl - 1) / 10) + 1)
	local curve = CURVES[stat]
	local level = math.max(1, math.min(ilvl, 10 * tier, 70))
	local raw = curve.a + curve.b * level + curve.c * level * level
	local factor = (stat == "str" or stat == "dex" or stat == "int") and 1 or 10
	return math.max(curve.minimum, math.floor(raw * factor + 0.5) / factor)
end

-- The real helpers and values of kits.lua.
local kits = read("mods/PLAYER/grug_abilities/kits.lua")
local helpers = cut(kits, "(local function spell_damage_value%(player, amount%).-\nend\n.-" ..
	"local function support_value%(player, percent%).-\nend)\n", "spell_damage_value and support_value")
local fireball = cut(kits, "(local function fireball_values%(user%).-\nend)\n", "fireball_values")
local smite = cut(kits, 'id = "smite",.-\n\tvalues = (function%(user, assume_shielded%).-\n\tend),',
	"Smite's values")
local spell_damage_value, support_value, fireball_values, smite_values = assert(loadstring(
	helpers .. "\n" .. fireball .. "\nreturn spell_damage_value, support_value, fireball_values, " ..
	smite))()
grug_classes.get_spell_damage_percent = function() return 0 end
grug_core.get_absorb = function() return 0 end

local function P(level) return grug_core.base_pool(level) end
local function B(level) return grug_core.baseline_melee_total(level) end

-- A. The support factor.
for _, level in ipairs({1, 10, 30, 45, 60}) do
	for _, class in ipairs({"priest", "mage"}) do
		near(grug_classes.get_support_factor({class = class, level = level}), 1,
			"A " .. class .. " " .. level .. " without Intelligence gear heals the listed share")
	end
	local gear = 8 * enchant("int", level)
	near(grug_classes.get_support_factor({class = "priest", level = level, gear_int = gear}),
		1 + gear / 10 / B(level), "A Priest " .. level .. " gear Int over a base hit")
end
local naked60 = {class = "priest", level = 60}
local geared60 = {class = "priest", level = 60, gear_int = 8 * enchant("int", 60)}
near(support_value(naked60, 25), P(60) * 0.25, "A support_value: 25 % of the base pool")
check(math.floor(support_value(naked60, 25)) == 674, "A Heal at level 60 without gear is 674")
check(math.floor(support_value(geared60, 25)) == 908, "A Heal at level 60 with an Int set is 908")
check(not kits:find("get_spell_power_bonus(player)\n\treturn base", 1, true)
	and not kits:find("spell_power_percent", 1, true), "A support_value no longer reads spell power")

-- B. Heal rises with Intelligence like Fireball.
for _, ilvl in ipairs({60, 70}) do
	local gear = 8 * enchant("int", ilvl)
	local priest = {class = "priest", level = 60, gear_int = gear}
	local heal_gain = support_value(priest, 25) / support_value(naked60, 25) - 1
	local mage_int = 10 + 3 * 59
	local fire_gain = (grug_core.baseline_weapon_damage(60) + (mage_int + gear) / 10)
		/ (grug_core.baseline_weapon_damage(60) + mage_int / 10) - 1
	near(heal_gain, fire_gain, "B ilvl " .. ilvl .. " Heal gains what Fireball gains", 1e-12)
	local old_gain = (1 + (128 + gear) / 1000) / (1 + 128 / 1000) - 1
	check(heal_gain > 2.5 * old_gain, "B ilvl " .. ilvl .. " Intelligence matters: " ..
		string.format("%.1f %% vs %.1f %%", 100 * heal_gain, 100 * old_gain))
	near(heal_gain, ilvl == 60 and 0.348 or 0.439, "B ilvl " .. ilvl .. " gain", 0.001)
end

-- C. The Dexterity curve and the Scout's full damage set (the models of
-- tools/r33_ds/models.py: Loose at full draw, Strike plus Mighty Blow).
near(CURVES.dex.c, 0.0011, "C Dexterity c")
check(enchant("dex", 60) == 13 and enchant("dex", 65) == 14 and enchant("dex", 70) == 15,
	"C Dexterity tier tops 13 / 14 / 15")
local function rnd(x) return math.floor(x + 0.5) end
local function weapon(ilvl) return math.max(1, rnd(rnd(4 + 0.35 * ilvl))) end
local function crit_factor(dex, extra) return 1 + math.min(0.30, 0.05 + 0.0005 * dex + extra / 100) end
local function scout(ilvl, add)
	local dex = 10 + 2 * 59 + (add.dex or 0)
	local shots = (1 + (add.speed or 0) / 100) / 2.5
	return shots * (weapon(ilvl) + dex / 10) * 2.25 * crit_factor(dex, add.crit or 0)
end
local function warrior(ilvl, add)
	local str, dex = 10 + 3 * 59 + (add.str or 0), 10 + 59
	local w = weapon(ilvl)
	local swings = 1 + (add.speed or 0) / 100
	local taken = 1 - math.min(0.30, 0.001 * dex)
	local procs = math.min(swings, (8 * swings + 3 * taken) / 25)
	return (swings * (w + str / 10) + procs * (math.floor(1.5 * w) - w)) * crit_factor(dex, add.crit or 0)
end
local gains = {}
for _, ilvl in ipairs({60, 65, 70}) do
	local crit, speed = 2 * enchant("crit_percent", ilvl), enchant("attack_speed_percent", ilvl)
	local s = scout(ilvl, {dex = 8 * enchant("dex", ilvl), crit = crit, speed = speed}) / scout(60, {}) - 1
	local w = warrior(ilvl, {str = 8 * enchant("str", ilvl), crit = crit, speed = speed}) / warrior(60, {}) - 1
	gains[ilvl] = {s, w}
end
near(gains[60][1], 0.490, "C Scout set at item level 60", 0.001)
near(gains[70][1], 0.694, "C Scout set at item level 70", 0.001)
near(gains[60][2], 0.470, "C Warrior set at item level 60 (the reference)", 0.001)
check(gains[60][1] >= 0.45 and gains[60][1] <= 0.60, "C Scout in the band at item level 60")
check(gains[65][1] <= gains[65][2] + 0.025 and gains[70][1] <= gains[70][2] + 1e-9,
	"C Scout no higher than the Warrior at item level 65 and 70")

-- D. Spells floor once after the level scalar.
near(spell_damage_value({}, 43.7), 43.7, "D spell_damage_value keeps the fraction")
local mage60 = {class = "mage", level = 60}
local priest60 = {class = "priest", level = 60}
check(grug_core.scale_player_damage(mage60, nil, fireball_values(mage60).damage) == 337,
	"D Fireball at level 60 settles to 337 (339 rounded first)")
check(grug_core.scale_player_damage(mage60, nil, 44) == 339, "D the old pre-rounded value was 339")
near(smite_values(priest60, false).damage, (25 + 12.8) * 1.5, "D Smite keeps its fraction", 1e-9)
check(grug_core.scale_player_damage(priest60, nil, smite_values(priest60, false).damage) == 437,
	"D Smite at level 60 settles to 437 (439 rounded first)")
priest60.talents = {smite_damage_add = 0.2 * B(60)}
near(smite_values(priest60, false).damage, (25 + 12.8) * 1.5 + 0.2 * B(60),
	"D Smite plus Sharpened Word, no rounding in between", 1e-9)
check(not smite:find("+ 0.5", 1, true), "D Smite's inner rounding is gone")
local mighty = cut(kits, "(local damage = math%.floor%(ctx%.weapon_damage %* mult%) %+ ctx%.melee_bonus)",
	"Mighty Blow's weapon floor")
check(mighty ~= nil, "D Mighty Blow keeps flooring the weapon part")

-- E. Crit talent texts.
local talents = read("mods/PLAYER/grug_classes/talents.lua") ..
	read("mods/PLAYER/grug_classes/scout_talents.lua")
for _, id in ipairs({"keen_edge", "cold_eye", "firebrand", "hard_faith"}) do
	local text = cut(talents, 'id = "' .. id .. '",.-description = "([^"]*)"', id .. "'s text")
	check(text:find("(30% cap holds)", 1, true) ~= nil, "E " .. id .. " says the cap holds")
end

print("R36 K PORTABLE PASS checks=" .. checks)
