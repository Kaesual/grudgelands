-- Round 33 lane DS portable test (LuaJIT): the enchant value rule in Lua.
--
-- docs/design/item_tiers.md section 1.1 is computed by the Python scripts in
-- this folder; lane C4 codes it in grug_quality. This fixture is the same
-- rule written in plain Lua 5.1 (what C4 will write), checked against the
-- design file's tier-top table, so a rounding difference between the two
-- languages or a typo in a coefficient shows up before wave 2:
--   A. the tier-top values T1..T6 (L = 10 T) and T7 at 65 and 70;
--   B. the plain-base values (item level 3/10/20/30/40/50);
--   C. the tier cap: an enchant never reads above 10 x its tier, the crown's
--      +1 tier lets a T6 enchant on item level 65 reach the T7 value;
--   D. every curve is non-decreasing over item levels 1..70 and keeps its
--      minimum.
--
--   luajit tools/r33_ds/portable_test.lua [REPO]
-- Prints "R33 DS PORTABLE PASS checks=<n>" or the failures.

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end

-- stat = {a, b, c, decimals, minimum}: value = a + b L + c L^2, rounded.
local CURVES = {
	str = {0.8, 0.15, 0.0025, 0, 1},
	int = {0.8, 0.15, 0.0025, 0, 1},
	dex = {0.6, 0.1, 0.0018, 0, 1},
	crit_percent = {3.6, 0.08, 0, 1, 0},
	attack_speed_percent = {1.6, 0.04, 0, 1, 0},
	max_hp_percent = {1.6, 0.04, 0, 1, 0},
	max_mana_percent = {2.2, 0.03, 0, 1, 0},
	dodge_percent = {1.5, 0.032, 0, 1, 0},
	armor_rating = {0, 0.08, 0, 1, 0.5},
}

local function curve_value(stat, level)
	local k = CURVES[stat]
	local raw = k[1] + k[2] * level + k[3] * level * level
	local factor = k[4] == 1 and 10 or 1
	return math.max(k[5], math.floor(raw * factor + 0.5) / factor)
end

local function enchant_value(stat, ilvl, tier)
	local level = math.max(1, math.min(ilvl, 10 * tier, 70))
	return curve_value(stat, level)
end

-- item_tiers.md section 1.1, "Values at the tier tops": T1..T6, T7 65, T7 70.
local TOPS = {
	str = {3, 5, 8, 11, 15, 19, 21, 24},
	dex = {2, 3, 5, 7, 10, 13, 15, 16},
	int = {3, 5, 8, 11, 15, 19, 21, 24},
	crit_percent = {4.4, 5.2, 6.0, 6.8, 7.6, 8.4, 8.8, 9.2},
	attack_speed_percent = {2.0, 2.4, 2.8, 3.2, 3.6, 4.0, 4.2, 4.4},
	max_hp_percent = {2.0, 2.4, 2.8, 3.2, 3.6, 4.0, 4.2, 4.4},
	max_mana_percent = {2.5, 2.8, 3.1, 3.4, 3.7, 4.0, 4.2, 4.3},
	dodge_percent = {1.8, 2.1, 2.5, 2.8, 3.1, 3.4, 3.6, 3.7},
	armor_rating = {0.8, 1.6, 2.4, 3.2, 4.0, 4.8, 5.2, 5.6},
}
-- "Values on plain bases": item level 3/10/20/30/40/50 with the base's tier.
local BASES = {
	str = {1, 3, 5, 8, 11, 15},
	dex = {1, 2, 3, 5, 7, 10},
	crit_percent = {3.8, 4.4, 5.2, 6.0, 6.8, 7.6},
	max_mana_percent = {2.3, 2.5, 2.8, 3.1, 3.4, 3.7},
	armor_rating = {0.5, 0.8, 1.6, 2.4, 3.2, 4.0},
}
local BASE_ILVL = {3, 10, 20, 30, 40, 50}

local function near(a, b)
	return math.abs(a - b) < 1e-9
end

-- A
for stat, row in pairs(TOPS) do
	for tier = 1, 6 do
		local got = enchant_value(stat, 10 * tier, tier)
		check(near(got, row[tier]), ("A %s T%d top: %s, doc %s"):format(stat, tier, got, row[tier]))
	end
	check(near(enchant_value(stat, 65, 7), row[7]), "A " .. stat .. " T7 65")
	check(near(enchant_value(stat, 70, 7), row[8]), "A " .. stat .. " T7 70")
end

-- B
for stat, row in pairs(BASES) do
	for tier = 1, 6 do
		local got = enchant_value(stat, BASE_ILVL[tier], tier)
		check(near(got, row[tier]), ("B %s base T%d: %s, doc %s"):format(stat, tier, got, row[tier]))
	end
end

-- C: a T5 enchant on item level 60 stays at its level-50 value; the crown
-- turns a T6 enchant on item level 65 into T7 and reaches the 65 value.
check(near(enchant_value("str", 60, 5), enchant_value("str", 50, 5)), "C T5 capped at 50")
check(near(enchant_value("str", 65, 6), TOPS.str[6]), "C T6 on 65 reads 60")
check(near(enchant_value("str", 65, 7), TOPS.str[7]), "C crowned T7 on 65")
check(near(enchant_value("crit_percent", 75, 7), TOPS.crit_percent[8]), "C item level clamps at 70")

-- D
for stat, k in pairs(CURVES) do
	local last = -1
	for level = 1, 70 do
		local value = curve_value(stat, level)
		check(value >= last, ("D %s non-decreasing at %d"):format(stat, level))
		check(value >= k[5], ("D %s minimum at %d"):format(stat, level))
		last = value
	end
end

if failures > 0 then
	print(("R33 DS PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R33 DS PORTABLE PASS checks=%d"):format(checks))
