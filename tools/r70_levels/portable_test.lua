-- Round 70 lane LEVELS (round70-plan.md §2.10): the boss numbers where they
-- live. The real levels.lua on a small stub derives the HP, damage and XP;
-- the fixed levels are read from the entity definitions' source, which the
-- fixtures that load those files (tools/r31_g for the General and the Kings'
-- chassis) exercise on a fake engine. The item levels and the crown are
-- tools/r33_c1 and tools/r33_c4; the encounter numbers tools/r70_levels/numbers.py.
-- Prints "R70 LEVELS PORTABLE PASS checks=<n>" or the failures.
local ROOT = arg and arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(a, b, label)
	return check(a == b, label .. " (" .. tostring(a) .. " vs " .. tostring(b) .. ")")
end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- The derived stats through the real file.
rawset(_G, "core", {settings = {get = function() return nil end}, log = function() end})
rawset(_G, "grug_mobs", {})
rawset(_G, "grug_core", {nearest_tag_player_d2 = function() end})
rawset(_G, "grug_xp", {mob_xp = function(level) return 25 + 5 * level end})
dofile(ROOT .. "/mods/ENTITIES/grug_mobs/levels.lua")
local stats_for = grug_mobs.stats_for

local hp = stats_for(75, "boss")
eq(hp, 30000, "A a dragon has 30,000 HP")
eq((stats_for(1, "boss")), 30000, "A the boss tier's HP is flat")
local _, damage, xp = stats_for(75, "boss")
eq(damage, 78.9, "A a level 75 boss hits at the normal curve")
eq(xp, 400, "A and pays the normal XP of its level")
eq((stats_for(70, "elite")), 10812, "A a King at 70 has an elite's HP of his level")
eq((stats_for(65, "elite")), 9401, "A a General stays at a level 65 elite's HP")

-- The fixed levels, each at its definition.
local bosses = read("mods/ENTITIES/grug_mobs/bosses.lua")
local king_def = bosses:match("local function king_def%(race, row%)(.-)\nend\n")
check(king_def ~= nil, "B king_def found")
check(king_def and king_def:find("_grug_fixed_level = 70", 1, true) ~= nil,
	"B a King is level 70")
check(bosses:find("general._grug_fixed_level = garrison.GENERAL_LEVEL", 1, true) ~= nil,
	"B a General leaves the King's level for his own")
local garrison = dofile(ROOT .. "/mods/ENTITIES/grug_mobs/pvp_garrison.lua")
eq(garrison.GENERAL_LEVEL, 65, "B a General stays level 65")
check(read("mods/ENTITIES/grug_mobs/boss_dragons.lua"):find(
	'_grug_fixed_level = 75, _grug_tier = "boss"', 1, true) ~= nil, "B a dragon is level 75")
check(read("mods/ENTITIES/grug_mobs/rift.lua"):find(
	'_grug_fixed_level = 60, _grug_tier = "elite"', 1, true) ~= nil,
	"B the rift boss stays a level 60 elite")
-- Only the dragons stand on the flat boss tier.
for _, file in ipairs({"bosses.lua", "kraken.lua", "shark.lua", "rift.lua"}) do
	check(not read("mods/ENTITIES/grug_mobs/" .. file):find('_grug_tier = "boss"', 1, true),
		"B " .. file .. " has no flat boss-tier mob")
end

-- The non-boss drop cap Round 71 lifts for instance mobs stays as it is.
check(read("mods/ITEMS/grug_quality/init.lua"):find(
	"BOSS_DROPS.ilvl[boss] or math.min(level, 60)", 1, true) ~= nil,
	"C every non-boss mob stays capped at item level 60")

if failures > 0 then
	print("R70 LEVELS PORTABLE FAIL " .. failures .. " of " .. checks)
	os.exit(1)
end
print("R70 LEVELS PORTABLE PASS checks=" .. checks)
