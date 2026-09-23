-- Round 18 population policy fixture. Loads the production policy and drives
-- its public registration/check seams with authoritative-query stubs.

local root = arg[1] or "."

local points = {}
local function point(x, zone, level, biome)
	points[x] = {zone = zone, level = level, biome = biome or "grug_meadows"}
	return {x = x, y = 5, z = 0}
end

core = {
	get_timeofday = function() return 0.5 end,
}
grug_core = {
	DAY_PHASE_START = 0.1875,
	DAY_PHASE_END = 0.8125,
	start_identities = function()
		local out = {}
		for i = 1, 6 do
			out[i] = {anchor = {x = 1000 * i, y = 5, z = 1000}}
		end
		return out
	end,
}
grug_zones = {
	id_at = function(x) return points[x] and points[x].zone end,
	mob_level_at = function(pos) return points[pos.x] and points[pos.x].level end,
	biome_at = function(x) return points[x] and points[x].biome end,
	pvp_rule_at = function() return "accord_home" end,
	race_region_at = function() return "human" end,
}
grug_mobs = {}
mobs = {spawn = function() end}

assert(loadfile(root .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua"))()

local function role(name, clock, min_level, hostile)
	grug_mobs.register_spawn_role(name, {
		clock = clock,
		_grug_min_level = min_level,
		attack_players = hostile,
	})
end

role("grug_mobs:boar", "day", 1, false)
role("grug_mobs:plague_boar", "day", 1, false)
role("grug_mobs:jungle_boar", "day", 1, false)
role("grug_mobs:jungle_lynx", "day", 10, true)
role("grug_mobs:tapir", "day", 1, false)
role("grug_mobs:zombie", {settled = "night", war = "night"}, 3, true)
role("grug_mobs:sun_dried_husk", "night", 3, true)
role("grug_mobs:giant_spider", "night", 1, true)
role("grug_mobs:jungle_spider", "night", 1, true)
role("grug_mobs:panther", "night", 1, true)
role("grug_mobs:skeleton_archer", {forest = "night", mountain = "night",
	war = "night"}, 1, true)
role("grug_mobs:skeleton_raider", "night", 1, true)
role("grug_mobs:frost_stray", "night", 1, true)

local starts = {
	{"elandor_hearthpine_vale", "grug_mobs:boar"},
	{"elandor_dawnmere_fields", "grug_mobs:boar"},
	{"elandor_silverleaf_glades", "grug_mobs:boar"},
	{"kragmar_stillgrave_hollow", "grug_mobs:plague_boar"},
	{"kragmar_sunscar_flats", "grug_mobs:boar"},
	{"kragmar_kapok_cradle", "grug_mobs:jungle_boar"},
}

local start_levels = {1, 3, 4, 9, 10}
local point_id = 0
for i = 1, #starts do
	for j = 1, #start_levels do
		point_id = point_id + 1
		local pos = point(point_id, starts[i][1], start_levels[j])
		assert(grug_mobs.spawn_policy_allows(starts[i][2], pos),
			"selected start boar refused: " .. starts[i][1])
		for _, candidate in ipairs({"grug_mobs:boar", "grug_mobs:plague_boar",
				"grug_mobs:jungle_boar"}) do
			assert((candidate == starts[i][2]) ==
				grug_mobs.spawn_policy_allows(candidate, pos),
				"boar variant drift: " .. starts[i][1] .. " / " .. candidate)
		end
	end
end

local low_lynx = point(40, "kragmar_kapok_cradle", 9, "grug_jungle_edge")
local natural_lynx = point(41, "kragmar_kapok_cradle", 10, "grug_jungle_edge")
assert(not grug_mobs.spawn_policy_allows("grug_mobs:jungle_lynx", low_lynx))
assert(grug_mobs.spawn_policy_allows("grug_mobs:jungle_lynx", natural_lynx))
local troll_main_quest = point(47, "kragmar_kapok_cradle", 8,
	"grug_jungle_edge")
assert(grug_mobs.spawn_policy_allows("grug_mobs:tapir", troll_main_quest))
local whitebridge = point(48, "elandor_whitebridge_shire", 25)
assert(grug_mobs.spawn_policy_allows("grug_mobs:boar", whitebridge),
	"Whitebridge's mixed settled/forest palette lost its settled boar")
assert(not grug_mobs.spawn_policy_allows("grug_mobs:plague_boar", whitebridge))
assert(not grug_mobs.spawn_policy_allows("grug_mobs:jungle_boar", whitebridge))

local low_zombie = point(42, "elandor_dawnmere_fields", 2)
local natural_zombie = point(43, "elandor_dawnmere_fields", 3)
core.get_timeofday = function() return 0 end
assert(not grug_mobs.spawn_policy_allows("grug_mobs:zombie", low_zombie))
assert(grug_mobs.spawn_policy_allows("grug_mobs:zombie", natural_zombie))

local desert = point(44, "kragmar_sunscar_flats", 7, "grug_savanna")
assert(not grug_mobs.spawn_policy_allows("grug_mobs:zombie", desert))
assert(grug_mobs.spawn_policy_allows("grug_mobs:sun_dried_husk", desert))

local mixed_jungle = point(45, "elandor_glassroot_wilds", 35,
	"grug_jungle_fringe")
assert(not grug_mobs.spawn_policy_allows("grug_mobs:giant_spider", mixed_jungle))
assert(grug_mobs.spawn_policy_allows("grug_mobs:jungle_spider", mixed_jungle))
assert(grug_mobs.spawn_policy_allows("grug_mobs:panther", mixed_jungle))
core.get_timeofday = function() return 0.5 end
assert(not grug_mobs.spawn_policy_allows("grug_mobs:jungle_lynx", mixed_jungle))
core.get_timeofday = function() return 0 end

local cold_war = point(46, "front_wyrmglass_crown", 60, "grug_crags_snowy")
assert(not grug_mobs.spawn_policy_allows("grug_mobs:skeleton_archer", cold_war))
assert(not grug_mobs.spawn_policy_allows("grug_mobs:skeleton_raider", cold_war))
assert(grug_mobs.spawn_policy_allows("grug_mobs:frost_stray", cold_war))

-- Spawn refusal is bounded to the authored start footprint. It says nothing
-- about an already-live mob later walking or chasing across the boundary.
points[1000] = {zone = "elandor_dawnmere_fields", level = 5,
	biome = "grug_meadows"}
assert(not grug_mobs.spawn_policy_allows("grug_mobs:zombie",
	{x = 1000, y = 5, z = 1000}))

io.write("r18-populations-policy: PASS\n")
