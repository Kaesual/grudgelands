-- Compact real-code KAT for the start-footprint hostile-spawn refusal
-- (user decision 2026-09-14): no mob that can attack players spawns inside
-- one of the six 148 x 148 hard-protected start footprints, while passive
-- critters keep spawning there.
--
-- Drives the production spawn_policy.lua directly — that function is the one
-- gate mobs:spawn_abm_check calls for every ABM spawn candidate.
--
-- Runs under LuaJIT and tools/bin/lua51 alike; prints one canonical digest.

local repo = arg[1] or "."

local function assert_equal(actual, expected, context)
	if actual ~= expected then
		error((context or "value") .. ": expected " .. tostring(expected) ..
			", got " .. tostring(actual), 2)
	end
end

-- hard_start_core_v1 is a centred half-open square of total width 148:
-- anchor - 74 .. anchor + 73 inclusive, so anchor - 75 and anchor + 74 are
-- the first columns outside it (wp40/source/catalog.lua).
local INSIDE_LOW, INSIDE_HIGH = -74, 73
local OUTSIDE_LOW, OUTSIDE_HIGH = -75, 74

local ANCHORS = {
	{race_id = "dwarf", faction_id = "accord", x = -550, y = 40, z = -900,
		zone = "elandor_hearthpine_vale"},
	{race_id = "human", faction_id = "accord", x = 10, y = 30, z = -900,
		zone = "elandor_dawnmere_fields"},
	{race_id = "elf", faction_id = "accord", x = 560, y = 35, z = -900,
		zone = "elandor_silverleaf_glades"},
	{race_id = "undead", faction_id = "throng", x = -550, y = 20, z = 900,
		zone = "kragmar_stillgrave_hollow"},
	{race_id = "orc", faction_id = "throng", x = 10, y = 35, z = 900,
		zone = "kragmar_sunscar_flats"},
	{race_id = "troll", faction_id = "throng", x = 560, y = 25, z = 900,
		zone = "kragmar_kapok_cradle"},
}

grug_mobs = {}
grug_core = {}
function grug_core.start_identities()
	local result = {}
	for i = 1, #ANCHORS do
		local row = ANCHORS[i]
		result[i] = {
			race_id = row.race_id,
			faction_id = row.faction_id,
			anchor = {x = row.x, y = row.y, z = row.z},
		}
	end
	return result
end

-- Every start sits in a `settled` zone; that is what makes the zombie's and
-- the rabbit's rows reach these columns at all. Everything outside the six
-- footprints is the same settled zone here, so an accepted candidate just
-- outside an edge proves the footprint — not the palette — did the refusing.
grug_zones = {
	id_at = function() return "kragmar_stillgrave_hollow" end,
	pvp_rule_at = function() return "contested" end,
	race_region_at = function() return "undead" end,
	biome_at = function() return "grug_blight" end,
}

dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")

--
-- 1. The derived hostile role reads exactly the mobs_redo fields.
--
assert_equal(grug_mobs.register_spawn_role("grug_mobs:zombie",
	{type = "monster", attack_players = true}), true, "monster is hostile")
assert_equal(grug_mobs.register_spawn_role("grug_mobs:giant_spider",
	{type = "monster"}), true, "attack_players defaults to hostile")
assert_equal(grug_mobs.register_spawn_role("grug_mobs:rabbit",
	{type = "animal", passive = true}), false, "a passive critter is not hostile")
-- grug_mobs.passive_prey (verbs.lua) sets exactly these fields.
assert_equal(grug_mobs.register_spawn_role("grug_mobs:stag",
	{type = "animal", passive = false, attack_players = false,
		attack_npcs = false}), false, "passive prey is not hostile")
assert_equal(grug_mobs.spawn_role_hostile("grug_mobs:zombie"), true,
	"stored zombie role")
assert_equal(grug_mobs.spawn_role_hostile("grug_mobs:rabbit"), false,
	"stored rabbit role")
assert_equal(grug_mobs.spawn_role_hostile("grug_mobs:unregistered"), false,
	"unregistered role")

--
-- 2. All six footprints refuse a hostile row at every half-open edge and
--    accept it one column further out. The zombie's 24 h blight row is the
--    row that has to stop at Stillgrave Hollow's footprint.
--
local refused, accepted = 0, 0
local function candidate(x, z, y)
	return {x = x, y = y or 12, z = z}
end

for i = 1, #ANCHORS do
	local anchor = ANCHORS[i]
	local context = anchor.race_id .. " (" .. anchor.zone .. ")"

	-- Centre and all four half-open corners are inside.
	local inside = {
		{0, 0},
		{INSIDE_LOW, INSIDE_LOW}, {INSIDE_HIGH, INSIDE_HIGH},
		{INSIDE_LOW, INSIDE_HIGH}, {INSIDE_HIGH, INSIDE_LOW},
		{INSIDE_LOW, 0}, {INSIDE_HIGH, 0},
		{0, INSIDE_LOW}, {0, INSIDE_HIGH},
	}
	for index = 1, #inside do
		local dx, dz = inside[index][1], inside[index][2]
		assert_equal(grug_mobs.spawn_policy_allows("grug_mobs:zombie",
			candidate(anchor.x + dx, anchor.z + dz)), false,
			"hostile refused inside " .. context .. " at " .. dx .. "/" .. dz)
		assert_equal(grug_mobs.in_start_footprint(anchor.x + dx, anchor.z + dz),
			true, "footprint membership inside " .. context)
		refused = refused + 1
		-- A passive critter keeps its ordinary palette authority in there.
		assert_equal(grug_mobs.spawn_policy_allows("grug_mobs:rabbit",
			candidate(anchor.x + dx, anchor.z + dz)), true,
			"critter accepted inside " .. context)
	end

	-- One column further out on every side the same row spawns again.
	local outside = {
		{OUTSIDE_LOW, 0}, {OUTSIDE_HIGH, 0},
		{0, OUTSIDE_LOW}, {0, OUTSIDE_HIGH},
		{OUTSIDE_LOW, OUTSIDE_LOW}, {OUTSIDE_HIGH, OUTSIDE_HIGH},
	}
	for index = 1, #outside do
		local dx, dz = outside[index][1], outside[index][2]
		assert_equal(grug_mobs.in_start_footprint(anchor.x + dx, anchor.z + dz),
			false, "footprint membership outside " .. context ..
			" at " .. dx .. "/" .. dz)
		assert_equal(grug_mobs.spawn_policy_allows("grug_mobs:zombie",
			candidate(anchor.x + dx, anchor.z + dz)), true,
			"hostile accepted outside " .. context .. " at " .. dx .. "/" .. dz)
		accepted = accepted + 1
	end
end

--
-- 3. The refusal is horizontal and height-independent: the footprint is a
--    column, so the underground zombie row is refused inside it too.
--
local under = candidate(ANCHORS[4].x, ANCHORS[4].z, -120)
assert_equal(grug_mobs.spawn_policy_allows("grug_mobs:zombie", under), false,
	"underground hostile refused inside Stillgrave")
assert_equal(grug_mobs.spawn_policy_allows("grug_mobs:zombie",
	candidate(ANCHORS[4].x + OUTSIDE_LOW, ANCHORS[4].z, -120)), true,
	"underground hostile accepted outside Stillgrave")

--
-- 4. An independent authority does not buy a way past the footprint.
--
grug_mobs.register_spawn_role("grug_mobs:kraken", {type = "monster"})
assert_equal(grug_mobs.spawn_policy_allows("grug_mobs:kraken",
	candidate(ANCHORS[1].x, ANCHORS[1].z)), false,
	"independent authority refused inside a start")

print(table.concat({
	"wp45_start_footprint_v1",
	"starts=" .. #ANCHORS,
	"hostile_refused=" .. refused,
	"hostile_accepted=" .. accepted,
}, "|"))
