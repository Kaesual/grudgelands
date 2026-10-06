-- Round 38 lane B2 portable test (LuaJIT): the accepted names in the game.
--
--   luajit tools/r38_b2/portable_test.lua [REPO]
--
-- Loads every grug_mobs file the way tools/r24_density_xp/roster.lua does
-- (a permissive stub engine, the real data/names.json) and checks:
--   C  the names the code builds (kings, royal guards, the General's
--      bodyguards, the dragons and their whelps, the rift boss) are their
--      slots' names in data/names.json, and every registered entity whose
--      role has one name there registers under it (no second copy differs);
--   W  the whelps are level 60 (the user, plan §6 item 12), normal tier, and
--      the inventory's slot key follows (L60-60);
--   K  the kings keep the user's mixed forms ("King of Highcourt", "Dur
--      Brannoc King", plan §6 item 13) in the broadcasts' table.
-- Prints "R38 B2 PORTABLE PASS checks=<n>" or the failures.
local repo = arg and arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

local names = dofile(repo .. "/tools/r38_b1/names_stub.lua").shipped(repo)
local roster = dofile(repo .. "/tools/r24_density_xp/roster.lua")(repo)
eq(#roster.failed, 0, "every mob file loads (" .. table.concat(roster.failed, "; ") .. ")")
local defs = roster.defs

-- C: the code-built names.
local races = {dwarf = 1, human = 1, elf = 1, undead = 1, orc = 1, troll = 1}
for race in pairs(races) do
	eq(defs["grug_mobs:king_" .. race] and defs["grug_mobs:king_" .. race].description,
		names.required("king_" .. race), "C the " .. race .. " king")
	eq(defs["grug_mobs:royal_guard_" .. race] and defs["grug_mobs:royal_guard_" .. race].description,
		names.required("royal_guard_" .. race), "C the " .. race .. " royal guard")
end
for _, faction in ipairs({"accord", "throng"}) do
	eq(defs["grug_mobs:bodyguard_" .. faction] and defs["grug_mobs:bodyguard_" .. faction].description,
		names.required("pvp_fortress_" .. faction .. ".bodyguard"), "C the " .. faction .. " bodyguard")
end
for _, role in ipairs({"ice_dragon", "jungle_wyvern", "ice_whelp", "storm_whelp", "rift_boss"}) do
	eq(defs["grug_mobs:" .. role] and defs["grug_mobs:" .. role].description, names.required(role), "C " .. role)
end
local differ = {}
for name, def in pairs(defs) do
	local only = names.only(name:match("^grug_mobs:(.+)$") or name)
	if only and def.description ~= only then
		differ[#differ + 1] = name .. " registers " .. tostring(def.description) .. ", names.json " .. only
	end
end
table.sort(differ)
eq(#differ, 0, "C every single-named entity registers its names.json name (" .. table.concat(differ, "; ") .. ")")

-- W: the whelps.
for _, role in ipairs({"ice_whelp", "storm_whelp"}) do
	local def = defs["grug_mobs:" .. role]
	eq(def and def._grug_fixed_level, 60, "W " .. role .. " is level 60")
	eq(def and def._grug_tier, "normal", "W " .. role .. " stays a normal-tier add")
end
eq(names.lookup("ice_whelp", "front_wyrmglass_crown", 60), names.required("ice_whelp"),
	"W the whelp's slot is L60-60 in names.json")
check(names.levels_of(names.required("ice_whelp"))[1] == 60, "W ...and nothing names it at 20")

-- K: the kings' mixed forms (the user, plan §6 item 13).
eq(names.required("king_human"), "King of Highcourt", "K King of Highcourt")
eq(names.required("king_dwarf"), "Dur Brannoc King", "K Dur Brannoc King")

if #failures == 0 then
	print("R38 B2 PORTABLE PASS checks=" .. checks)
else
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R38 B2 PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
