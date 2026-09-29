-- Round 24 Lane D3 portable fixture (LuaJIT): the thin start-zone cells of
-- ruling 31 through the real grug_mobs spawn policy, disposition, level engine
-- and family files (start_zone_families.lua, jungle_lynx.lua) on stubbed
-- engine and zone authorities.
--
--   luajit tools/r24_mobs/cells_fixture.lua <repo>
--
-- Checks:
--   * the Scorpion spawns by day and night in Sunscar (band 2 and up), by
--     night only in Redtusk; the Viper likewise in Kapok and Raincall;
--   * the zone clock key wins over the palette key in both spawn_clock_for
--     and zone_clock_cast, so the day casts list them only in their start zone;
--   * each family's night row keeps max_light 5 and the day toggle off, the
--     new day row carries min_light 10, with the night row's chance and aoc;
--   * the Plains Runner is neutral fighting prey on the normal tier (level,
--     HP, damage and XP from the zone field, XP > 0), no longer a critter;
--   * the Jungle Lynx is eligible by day in Kapok from L4 (band 2), not in
--     band 1, and is levelled by the field (L4 at L4);
--   * the Fox (Dwarf/Human/Elf) still needs L4, so band 1 by day stays
--     peaceful there.
local repo = assert(arg[1], "usage: cells_fixture.lua <repo>")
local mobs_dir = repo .. "/mods/ENTITIES/grug_mobs/"

local failures, checks = 0, 0
local function check(ok, message)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. message)
	end
	return ok
end

-- Stubbed authorities. A test position is {x = <id>, y = 5, z = 0}; the id
-- selects its zone, level and biome.
local SPOTS = {}
local function spot(zone, level, biome)
	SPOTS[#SPOTS + 1] = {zone = zone, level = level, biome = biome}
	return {x = #SPOTS, y = 5, z = 0}
end
local timeofday = 0.5
_G.core = {
	settings = {get = function() return nil end, get_bool = function() return nil end},
	log = function() end,
	global_exists = function() return false end,
	get_timeofday = function() return timeofday end,
	registered_entities = {},
	is_player = function() return false end,
}
_G.grug_core = {
	DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125,
	nearest_tag_player_d2 = function() end,
	start_identities = function()
		local out = {}
		for i = 1, 6 do out[i] = {anchor = {x = 100000 + i * 1000, z = 100000}} end
		return out
	end,
}
_G.grug_zones = {
	id_at = function(x) return SPOTS[x] and SPOTS[x].zone end,
	biome_at = function(x) return SPOTS[x] and SPOTS[x].biome end,
	mob_level_at = function(pos) return SPOTS[pos.x] and SPOTS[pos.x].level end,
	race_region_at = function() return "orc" end,
	pvp_rule_at = function() return "peaceful" end,
}
local rows, defs = {}, {}
_G.grug_mobs = {}
_G.mobs = {spawn = function(_, def)
	rows[#rows + 1] = grug_mobs.prepare_spawn_row(def)
end}
dofile(mobs_dir .. "spawn_policy.lua")
dofile(mobs_dir .. "levels.lua")
dofile(mobs_dir .. "disposition.lua")
-- The parts of init.lua's register_mob these checks need.
function grug_mobs.register_mob(name, def)
	grug_mobs.apply_disposition(name, def)
	grug_mobs.register_level_cfg(name, def)
	grug_mobs.register_spawn_role(name, def)
	defs[name] = def
	core.registered_entities[name] = def
end
local spawn_checks = {}
local register = grug_mobs.register_mob
function grug_mobs.register_mob(name, def)
	register(name, def)
	spawn_checks[name] = def._grug_spawn_check
end
function grug_mobs.melee_rider() end
function grug_mobs.camp_swarm() end
function grug_mobs.pack_hunter() end
function grug_mobs.poison_player() end
function grug_mobs.atlas_textures() return {} end
function grug_mobs.passive_prey(def)
	-- verbs.lua:719-726, verbatim.
	def.passive = false
	def.attack_players = false
	def.attack_npcs = false
	def.runaway = false
	def.attack_type = def.attack_type or "dogfight"
	return def
end
dofile(mobs_dir .. "start_zone_families.lua")
dofile(mobs_dir .. "jungle_lynx.lua")

-- The full gate of init.lua's mobs:spawn_abm_check (policy + per-mob check).
local function admits(name, pos, time)
	timeofday = time
	if not grug_mobs.spawn_policy_allows(name, pos) then return false end
	local gate = spawn_checks[name]
	return not gate or gate(pos) == true
end
local NOON, MIDNIGHT = 0.5, 0.0

local sunscar = {spot("kragmar_sunscar_flats", 3, "grug_savanna"),
	spot("kragmar_sunscar_flats", 4, "grug_savanna"),
	spot("kragmar_sunscar_flats", 8, "grug_savanna")}
local redtusk = spot("kragmar_redtusk_savanna", 13, "grug_savanna")
local kapok = {spot("kragmar_kapok_cradle", 3, "grug_jungle_edge"),
	spot("kragmar_kapok_cradle", 4, "grug_jungle_edge"),
	spot("kragmar_kapok_cradle", 9, "grug_jungle_edge")}
local raincall = spot("kragmar_raincall_basin", 12, "grug_jungle_edge")
local hearthpine = {spot("elandor_hearthpine_vale", 3, "grug_pine_hills"),
	spot("elandor_hearthpine_vale", 5, "grug_pine_hills")}

local function cell(name, place, time)
	return admits(name, place, time)
end
for _, family in ipairs({{"grug_mobs:scorpion", sunscar, redtusk},
		{"grug_mobs:viper", kapok, raincall}}) do
	local name, start, home = family[1], family[2], family[3]
	check(not cell(name, start[1], NOON) and not cell(name, start[1], MIDNIGHT),
		name .. ": band 1 of its start zone stays closed")
	for band = 2, 3 do
		check(cell(name, start[band], NOON), name .. ": band " .. band .. " by day")
		check(cell(name, start[band], MIDNIGHT), name .. ": band " .. band .. " by night")
	end
	check(not cell(name, home, NOON), name .. ": the home zone keeps the night clock (day closed)")
	check(cell(name, home, MIDNIGHT), name .. ": the home zone keeps its night spawns")
	check(grug_mobs.spawn_clock_for(name, start[2]) == "any" and
		grug_mobs.spawn_clock_for(name, home) == "night",
		name .. ": zone clock any in the start zone, night elsewhere")
	-- Rows: one night row, one day row, same chance and aoc before the clock.
	local night, day
	for _, row in ipairs(rows) do
		if row.name == name and row.max_light == 5 then night = row end
		if row.name == name and row.min_light == 10 then day = row end
	end
	check(night and night.day_toggle == false and day and day.max_light == nil,
		name .. ": a night row (max_light 5, no day toggle) and a day row (min_light 10)")
	if night and day then
		check(night.chance == day.chance and day.active_object_count *
			5 / 4 >= night.active_object_count - 1,
			name .. ": the day row has the night row's chance and base cap")
	end
end
local sunscar_day = table.concat(grug_mobs.zone_clock_cast("kragmar_sunscar_flats", "day"), " ")
local redtusk_day = table.concat(grug_mobs.zone_clock_cast("kragmar_redtusk_savanna", "day"), " ")
local kapok_day = table.concat(grug_mobs.zone_clock_cast("kragmar_kapok_cradle", "day"), " ")
local raincall_day = table.concat(grug_mobs.zone_clock_cast("kragmar_raincall_basin", "day"), " ")
check(sunscar_day:find("scorpion", 1, true) and not redtusk_day:find("scorpion", 1, true),
	"day cast: Scorpion in Sunscar, not Redtusk")
check(kapok_day:find("viper", 1, true) and not raincall_day:find("viper", 1, true),
	"day cast: Viper in Kapok, not Raincall")
print("Sunscar day cast: " .. sunscar_day)
print("Kapok day cast: " .. kapok_day)

-- Plains Runner: neutral fighting prey on the normal tier.
local runner = defs["grug_mobs:plains_runner"]
check(runner._grug_disposition == "neutral" and runner.passive == false and
	runner.attack_players == false and runner.attack_type == "dogfight" and
	runner.runaway == false and runner._grug_tier == nil,
	"Plains Runner: neutral prey that fights back, normal tier")
check(runner.run_velocity == 4.6, "Plains Runner: the 4.6 melee band when it fights back")
for _, band in ipairs({1, 2, 3}) do
	local place = sunscar[band]
	check(cell("grug_mobs:plains_runner", place, NOON) and
		not cell("grug_mobs:plains_runner", place, MIDNIGHT),
		"Plains Runner: day in Sunscar band " .. band)
end
for _, level in ipairs({3, 5, 10}) do
	local hp, damage, xp = grug_mobs.stats_for(level, nil)
	print(("Plains Runner at L%d: HP %d, damage %.2f, XP %d (critter was HP 1, XP 0)"):format(
		level, hp, damage, xp))
	check(xp > 0 and hp > 1, "Plains Runner: normal-tier HP and XP at L" .. level)
end

-- Jungle Lynx: Kapok by day from band 2.
check(not cell("grug_mobs:jungle_lynx", kapok[1], NOON), "Jungle Lynx: not in Kapok band 1")
check(cell("grug_mobs:jungle_lynx", kapok[2], NOON) and
	cell("grug_mobs:jungle_lynx", kapok[3], NOON), "Jungle Lynx: Kapok bands 2 and 3 by day")
check(not cell("grug_mobs:jungle_lynx", kapok[2], MIDNIGHT), "Jungle Lynx: stays a day family")
check(cell("grug_mobs:jungle_lynx", raincall, NOON), "Jungle Lynx: Raincall unchanged")

-- Dwarf/Human/Elf band 1 by day stays peaceful (the Fox keeps its L4 gate).
check(not cell("grug_mobs:fox", hearthpine[1], NOON) and cell("grug_mobs:fox", hearthpine[2], NOON),
	"Fox: Hearthpine from band 2 only")

print(("checks %d failures %d"):format(checks, failures))
print(failures == 0 and "RESULT PASS" or "RESULT FAIL")
