-- Direct stable-query spawn gates for the ABM rows. Every named zone spawns
-- its surface mobs from its spawn recipe's regions (spawn_regions.lua); its
-- ABM rows keep only the recipe's critters and RECIPE_ZONE_ROWS. The named-
-- zone mob palettes that once served a zone without a recipe are gone
-- (Round 81, ruling 6), with the surface rows only they could reach.

local VALID_DOMAINS = {
	contested = true,
	underground = true,
}

local VALID_CLOCKS = {
	day = true,
	night = true,
	any = true,
}

-- Kraken has an independent authority instead of the recipe rule below:
-- water_class_at == deep_ocean in kraken.lua. Round 51 adds the fixed-level
-- sharks and the sea's critter fish (world slots in data/names.json,
-- tools/r38_names/inventory.py); their spawn rows by water band are MOBS
-- step M2's.
local INDEPENDENT_AUTHORITY = {
	["grug_mobs:kraken"] = true,
	["grug_mobs:reed_angelfish"] = true,
	["grug_mobs:bay_shark"] = true,
	["grug_mobs:abyssal_shark"] = true,
	["grug_mobs:goby"] = true,
}

-- Surface rows a spawn-recipe zone keeps beside its critters, in the zones
-- whose palette carried them before the recipes (Round 28 S2c; the
-- catalogue: Rift Spawn keeps its current spawning; the zones are the
-- atlas's). Unlike the independent authorities above, the row still meets
-- the start footprint, its night clock and the protected surface (ruling 3);
-- its host ground decides there. It keeps exactly its own ABM chance and
-- object cap (Round 28 S2c review): prepare_spawn_row leaves both alone.
local RECIPE_ZONE_ROWS = {
	["grug_mobs:rift_spawn"] = {front_gravesalt_escarpment = true,
		front_skyglass_canopy = true, front_stormscale_summit = true,
		front_wyrmglass_crown = true},
}

-- Round 46 ruling 15: the underground begins just below the surface. A row
-- is an underground row when its top (`max_height`, where the mob stands)
-- is at most UNDERGROUND_TOP; mobs_redo raises the matched node by one
-- before the height test, so such a row matches nodes y <= -2, and the
-- policy's underground domain is exactly the nodes y < UNDERGROUND_TOP.
-- Until Round 46 both stood at -40 and the band -1 .. -40 spawned nothing.
local UNDERGROUND_TOP = -1
grug_mobs.UNDERGROUND_TOP = UNDERGROUND_TOP

-- The existing cave rows are exact. Keeping this list closed preserves their
-- underground behavior without letting a new Grudgelands family silently
-- bypass the named-zone policy merely because it added a negative-height ABM.
local UNDERGROUND_MOBS = {
	["grug_mobs:zombie"] = true,
	["grug_mobs:giant_spider"] = true,
	["grug_mobs:stone_golem"] = true,
	["grug_mobs:mesa_golem"] = true,
	["grug_mobs:cave_bat"] = true,
	["grug_mobs:cave_crawler"] = true,
	["grug_mobs:spiderling"] = true,
	["grug_mobs:blood_bat"] = true,
	["grug_mobs:stone_mite"] = true,
	["grug_mobs:giant_rat"] = true,
	["grug_mobs:goblin_miner"] = true,
	["grug_mobs:goblin_miner_slinger"] = true,
	["grug_mobs:oerkki"] = true,
	["grug_mobs:glowwing"] = true,
	["grug_mobs:crystal_shard"] = true,
	["grug_mobs:dungeon_master"] = true,
	["grug_mobs:lava_flan"] = true,
	["grug_mobs:ember_wisp"] = true,
	-- The Land Guard and the Rift Spawn have no cave row since Round 46: below
	-- y -1000 the depth pulse brings them (depth_pulse.lua), which bypasses
	-- this ABM policy like the spawn regions do.
}

local RACE_FACTIONS = {
	dwarf = "accord",
	human = "accord",
	elf = "accord",
	undead = "throng",
	orc = "throng",
	troll = "throng",
}

--
-- Start-footprint hostile-spawn refusal (user decision, 2026-09-14).
--
-- No mob that can attack players spawns inside one of the six start towns.
-- A start town is its protected footprint (world.md Section 2 R1, plan D78):
-- the 128-node pad, a half-open square centred on the start anchor (anchor
-- - 64 .. anchor + 63), and every column within 12 nodes of it, measured as
-- the true distance between column centres, so the corners are rounded
-- (wp40/source/simple_map.lua, recipe hard_start_town_v1: pad_width 128,
-- band 12).
--
-- grug_zones.territory_rule_at(pos) == "hard_protected" is the same
-- predicate, but it normalizes a position table, walks a sparse footprint
-- index and allocates a candidate list on every call. This gate runs on
-- every ABM spawn candidate, so the six pads are compiled once from
-- grug_core.start_anchor's authority and tested as plain number
-- comparisons: at most six boxes and one distance, no allocation.
--
-- Capitals (their protected cities, plan D76) are hard-protected too and are
-- deliberately NOT covered here: every capital zone has a spawn recipe, so
-- spawn_policy_allows refuses its surface rows (none keeps critters or the
-- Rift Spawn there), and Round 28 ruling 3 refuses the capital city itself
-- for every ambient non-critter spawn, ABM row or region
-- (grug_mobs.protected_spawn_surface below). Only the city is protected: the
-- rest of a capital zone carries its recipe's hostile regions.
local START_PAD_LOW = 64 -- the pad: anchor - 64 .. anchor + 63, half-open
local START_PAD_HIGH = 63
local START_BAND = 12
local start_pads

-- Round 24 ruling 30: a start town is hard-protected only from its floor
-- (placement height minus the protection depth, owned by the zone authority:
-- `source.protection_depth_below_placement`) upward, so the
-- hostile refusal ends there too; caves below keep their ordinary
-- population. The authority's public query answers "town" exactly at and
-- above that floor in the anchor column, so the floor is found once per
-- town by bisection instead of restating the depth here.
local function protected_floor(anchor)
	local function town(y)
		return grug_zones.hard_protection_kind_at(
			{x = anchor.x, y = y, z = anchor.z}) == "town"
	end
	local low, high = -31000, anchor.y
	if not town(high) then
		error("[grug_mobs] start footprint: the anchor is not a protected town")
	end
	if town(low) then
		return low
	end
	while high - low > 1 do
		local middle = math.floor((low + high) / 2)
		if town(middle) then high = middle else low = middle end
	end
	return high
end

local function compile_start_pads()
	local pads = {}
	local identities = grug_core.start_identities()
	if #identities ~= 6 then
		error("[grug_mobs] start footprints: expected 6 start anchors, got " ..
			#identities)
	end
	for i = 1, #identities do
		local anchor = identities[i].anchor
		pads[#pads + 1] = {
			min_x = anchor.x - START_PAD_LOW,
			max_x = anchor.x + START_PAD_HIGH,
			min_z = anchor.z - START_PAD_LOW,
			max_z = anchor.z + START_PAD_HIGH,
			anchor = anchor,
		}
	end
	return pads
end

-- Exposed for the regression harness; production reads it through
-- spawn_policy_allows below. `y` is optional: without it only the columns
-- are tested.
function grug_mobs.in_start_footprint(x, z, y)
	if not start_pads then
		start_pads = compile_start_pads()
	end
	for i = 1, #start_pads do
		local pad = start_pads[i]
		if x >= pad.min_x - START_BAND and x <= pad.max_x + START_BAND and
				z >= pad.min_z - START_BAND and z <= pad.max_z + START_BAND then
			local ex = math.max(pad.min_x - x, x - pad.max_x, 0)
			local ez = math.max(pad.min_z - z, z - pad.max_z, 0)
			if ex * ex + ez * ez <= START_BAND * START_BAND then
				if y == nil then
					return true
				end
				-- Resolved on the first query inside this town, not at load.
				pad.min_y = pad.min_y or protected_floor(pad.anchor)
				return y >= pad.min_y
			end
		end
	end
	return false
end

-- Hostile role, derived from exactly the fields mobs_redo's general_attack
-- tests for a player candidate: `self.passive` returns before any candidate
-- is looked at (api.lua general_attack) and `not self.attack_players` drops every
-- player (api.lua general_attack). attack_players defaults to TRUE in mob_class
-- (api.lua's mob_class defaults), hence the explicit `== false`; grug_mobs.passive_prey
-- (verbs.lua) sets it for the four non-passive prey animals. Deriving it
-- keeps it from drifting the way a hand-kept hostile list would.
local hostile_spawns = {}
local claim_hostile_spawns = {}
local spawn_clocks = {}
local ambient_density_spawns = {}
local elite_spawns = {} -- mobs whose definition is elite (golems, Land Guard)

local function validate_clock(clock, name)
	if type(clock) == "string" then
		if not VALID_CLOCKS[clock] then
			error("[grug_mobs] invalid spawn clock for " .. name .. ": " ..
				tostring(clock))
		end
		return
	end
	if type(clock) ~= "table" then
		error("[grug_mobs] missing spawn clock for " .. name)
	end
	local count = 0
	for key, value in pairs(clock) do
		if type(key) ~= "string" or not VALID_CLOCKS[value] then
			error("[grug_mobs] invalid spawn clock table for " .. name)
		end
		count = count + 1
	end
	if count == 0 then
		error("[grug_mobs] empty spawn clock table for " .. name)
	end
end

function grug_mobs.register_spawn_role(name, def)
	validate_clock(def.clock, name)
	hostile_spawns[name] = def.passive ~= true and def.attack_players ~= false
	-- Settlement people (guards, royal guards, villagers, vendors: all
	-- `type = "npc"`) are never refused by a housing claim (ruling 24).
	claim_hostile_spawns[name] = hostile_spawns[name] and def.type ~= "npc"
	spawn_clocks[name] = def.clock
	elite_spawns[name] = def._grug_tier == "elite"
	-- Ordinary natural rows include hostile creatures and neutral huntable
	-- wildlife. Critters are scenery, while NPC/rare/boss/encounter populations
	-- have authored or dedicated owners and never inherit ambient tuning.
	local tier = def._grug_tier or "normal"
	ambient_density_spawns[name] = def.type ~= "npc" and
		tier ~= "critter" and tier ~= "rare" and tier ~= "boss"
	return hostile_spawns[name]
end

function grug_mobs.spawn_role_hostile(name)
	return hostile_spawns[name] == true
end

--
-- Round 25 ruling 24: no hostile spawn inside an active housing claim. Mobs
-- may still walk in, and an expired (unfuelled) claim spawns normally.
--
-- Hostile here is the start-footprint role above (a mob that attacks a
-- player unprovoked) minus `type = "npc"`: neutral prey that only fights
-- back, passive critters, fish and every settlement NPC keep spawning.
--
-- `pos` is where the mob will stand (for an ABM row, its matched node + 1).
-- A claim is a column from grug_housing.MIN_Y upward, so cave spawns below a
-- home down to that floor are refused too; claim_at owns that test.
--
-- The claim core is looked up at run time, not through a mod dependency:
-- grug_housing depends on grug_mobs, so a dependency this way round would be
-- a cycle. rawget keeps strict.lua quiet while the mod is absent. At most
-- one claim_at call per hostile attempt and none for any other mob; nothing
-- is stored, so a refusal is an ordinary failed attempt.
function grug_mobs.claim_refuses_spawn(name, pos)
	if not claim_hostile_spawns[name] then
		return false
	end
	local housing = rawget(_G, "grug_housing")
	if not housing then
		return false
	end
	local claim = housing.claim_at(pos)
	return claim ~= nil and housing.is_active(claim) == true
end

--
-- Round 46 ruling 15: what an underground row's spawn adds, called from the
-- row's on_spawn (prepare_spawn_row) right after mobs_redo created the mob,
-- before its first tick. Hostile mobs only; critters keep their own sight
-- and never turn elite.
--
-- Sight: an underground spawn is never closer than `mob_nospawn_range` (24)
-- to a player, beyond every cave mob's own view range (10-16), so a fresh
-- mob never saw the player it spawned for. Its view range is raised to
-- reach that distance plus two nodes (the mob stands one node above the
-- tested point and looks from its eye). A plain entity field, so it is
-- saved with the mob; the def and the surface rows of the same mob keep
-- theirs.
--
-- Elite roll: UNDERGROUND_ELITE_CHANCE of these spawns become elite
-- (set_tier: x3 HP, x1.8 damage, x4 XP and the elite wind-up telegraph),
-- never inside a start footprint and never below UNDERGROUND_ELITE_MIN_LEVEL.
-- A def-elite (golems, the Land Guard) stays what it is. `skip_elite` lets a
-- caller with its own spawn rule (the depth pulse) keep the sight without
-- the roll.
--
grug_mobs.UNDERGROUND_ELITE_CHANCE = 0.04
grug_mobs.UNDERGROUND_ELITE_MIN_LEVEL = 5

-- mobs_redo's own default for the setting is 12; read on the first spawn.
local underground_view_range
function grug_mobs.underground_view_range()
	if not underground_view_range then
		underground_view_range =
			(tonumber(core.settings:get("mob_nospawn_range")) or 12) + 2
	end
	return underground_view_range
end

function grug_mobs.underground_spawned(ent, pos, skip_elite)
	if not ent or not ent.object or not hostile_spawns[ent.name] then
		return false
	end
	local sight = grug_mobs.underground_view_range()
	if (ent.view_range or 0) < sight then
		ent.view_range = sight
	end
	if skip_elite or math.random() >= grug_mobs.UNDERGROUND_ELITE_CHANCE or
			grug_mobs.in_start_footprint(pos.x, pos.z, pos.y) then
		return false
	end
	local level = grug_mobs.pending_level(ent)
	if not level or level < grug_mobs.UNDERGROUND_ELITE_MIN_LEVEL then
		return false
	end
	grug_mobs.set_tier(ent, "elite")
	return ent._grug_tier == "elite"
end

-- A family's clock is "day", "night" or "any", or a table that picks one by
-- where the mob would stand: a "zone:<zone id>" key for one named zone (it
-- wins, so the choice never depends on table order) and a "blight" key for
-- the grug_blight biome; elsewhere such a table names no clock. No family
-- with a kept surface row has a table today (Round 81 removed the rows that
-- had one).
local function clock_key_at(clock, pos, zone_id)
	if zone_id == nil and pos then
		zone_id = grug_zones.id_at(pos.x, pos.z)
	end
	local zone_key = zone_id and ("zone:" .. zone_id)
	if zone_key and clock[zone_key] then
		return zone_key
	end
	if clock.blight and pos and grug_zones.biome_at(pos.x, pos.z) == "grug_blight" then
		return "blight"
	end
	return nil
end

-- `zone_id` is optional and wins over the zone of `pos` (clock_key_at).
function grug_mobs.spawn_clock_for(name, pos, zone_id)
	if pos and pos.y < UNDERGROUND_TOP then
		return "any"
	end
	local clock = spawn_clocks[name]
	if type(clock) ~= "table" then
		return clock
	end
	local key = (pos or zone_id) and clock_key_at(clock, pos, zone_id)
	return key and clock[key] or nil
end

function grug_mobs.spawn_clock_allows(name, pos, timeofday)
	local clock = grug_mobs.spawn_clock_for(name, pos)
	if not clock or clock == "any" then
		return true
	end
	local value = timeofday
	if value == nil and core and core.get_timeofday then
		value = core.get_timeofday()
	end
	if value == nil then
		return true
	end
	local day_start = grug_core.DAY_PHASE_START or 0.1875
	local day_end = grug_core.DAY_PHASE_END or 0.8125
	local daylight = value >= day_start and value <= day_end
	return clock == (daylight and "day" or "night")
end

-- Family clocks own the mobs_redo row convention. Underground rows remain
-- light-driven and keep their explicit max_light without a day_toggle.
function grug_mobs.prepare_spawn_row(def)
	local row = {}
	for key, value in pairs(def) do
		row[key] = value
	end
	if row.max_height and row.max_height <= UNDERGROUND_TOP then
		row.day_toggle = nil
		-- Round 46: the sight and the elite roll of an underground spawn
		-- (grug_mobs.underground_spawned below), after the row's own hook.
		local own = row.on_spawn
		row.on_spawn = function(ent, pos)
			if own then own(ent, pos) end
			grug_mobs.underground_spawned(ent, pos)
		end
		return row
	end
	-- A recipe zone's kept row states its final chance and cap (above).
	local exact = RECIPE_ZONE_ROWS[row.name] ~= nil
	if ambient_density_spawns[row.name] and not exact then
		-- `chance` is one success per N ABM hits, so division raises attempt
		-- frequency. Nearest-integer caps keep small species budgets close to
		-- the same 1.3x target without inventing fractional entities.
		if row.chance then
			row.chance = math.max(1, math.floor(row.chance / 1.3 + 0.5))
		end
		if row.active_object_count then
			row.active_object_count = math.max(1,
				math.floor(row.active_object_count * 1.3 + 0.5))
		end
	end
	-- A surface row takes its family's plain clock (a table answers per
	-- position, which a row cannot).
	local clock = spawn_clocks[row.name]
	if type(clock) ~= "string" then
		error("[grug_mobs] spawn row has no clock role: " .. tostring(row.name))
	end
	row.min_light = nil
	row.max_light = nil
	row.day_toggle = nil
	if clock == "day" then
		row.min_light = 10
		-- mobs_redo's day window (api.lua day_toggle: 4500..19500 of 24000)
		-- is DAY_PHASE_START..END. Without it a day row also fires at night
		-- on torch light >= 10.
		row.day_toggle = true
	elseif clock == "night" then
		row.max_light = 5
		row.day_toggle = false
		if row.active_object_count and not exact then
			row.active_object_count = math.ceil(row.active_object_count * 5 / 4)
		end
	end
	return row
end

function grug_mobs.install_spawn_clock_wrapper()
	if grug_mobs._spawn_clock_wrapper_installed then
		return
	end
	local original = mobs.spawn
	function mobs:spawn(def)
		if spawn_clocks[def.name] then
			def = grug_mobs.prepare_spawn_row(def)
		end
		return original(self, def)
	end
	grug_mobs._spawn_clock_wrapper_installed = true
end

function grug_mobs.compile_spawn_domains(domains, mob_name)
	if type(domains) ~= "table" or #domains == 0 then
		error("[grug_mobs] invalid spawn domains for " .. mob_name)
	end
	local result = {}
	for i = 1, #domains do
		local domain = domains[i]
		if not VALID_DOMAINS[domain] or result[domain] then
			error("[grug_mobs] invalid spawn domain for " .. mob_name ..
				": " .. tostring(domain))
		end
		result[domain] = true
	end
	return result
end

function grug_mobs.spawn_domain_at(pos)
	if pos.y < UNDERGROUND_TOP then
		return "underground"
	end
	if grug_zones.pvp_rule_at(pos) == "contested" then
		return "contested"
	end
	return nil
end

function grug_mobs.spawn_domains_allow(domains, pos)
	return domains[grug_mobs.spawn_domain_at(pos)] == true
end

-- Variant-side authority for mob pairs whose surface nodes are shared across
-- both continents. Contested zones deliberately have no political faction,
-- so their stable cultural race region selects the matching variant.
function grug_mobs.race_region_spawn_allows(faction_id, pos)
	return RACE_FACTIONS[grug_zones.race_region_at(pos.x, pos.z)] ==
		faction_id
end

--
-- Round 28 ruling 3: no ambient non-critter spawn on the exact protected
-- surface: a road corridor or bridge, a village's building core and a
-- Round 31 PvP fortress or war camp with its margin, a Round 58 mining camp
-- (grug_core.world_feature_at, the half width + 1 corridor of ruling 1 and
-- the village, fortress, war-camp and mining-camp boxes; a camp under
-- construction answers "war_camp"), a start town's footprint and a
-- capital city (grug_zones.hard_protection_kind_at "town"). No margin
-- beyond them: the idle push of ruling 2 keeps aggressive mobs off roads and
-- towns, a margin of aggro range would empty land trails run through.
-- Bandit and Mirefolk camps and other POIs are not refused (their own mobs
-- spawn there), and critters may still appear in towns.
--
-- Called for ABM rows (spawn_policy_allows, ordinary natural rows only) and
-- for every non-critter region spawn (spawn_regions.lua). `pos` is where the mob
-- stands or the node it stands on: the road corridor reaches +-5 around the
-- road surface and the other shapes are full columns, so both answer alike.
-- The start footprint is the plain-number test above; the capital query is
-- asked only in the six capital zones. The last answer is kept, so asking
-- again at the same point is free.
--
local capital_zones = {} -- zone id -> bool, from the zone authority
local last_x, last_y, last_z, last_protected

-- A capital zone is one whose zone session publishes a `capital` anchor.
local function capital_zone(zone_id)
	if not zone_id then
		return false
	end
	local known = capital_zones[zone_id]
	if known == nil then
		known = grug_zones.anchor(zone_id, "capital") ~= nil
		capital_zones[zone_id] = known
	end
	return known
end

function grug_mobs.protected_spawn_surface(pos)
	local x, y, z = pos.x, pos.y, pos.z
	if x == last_x and y == last_y and z == last_z then
		return last_protected
	end
	local protected = grug_mobs.in_start_footprint(x, z, y)
	if not protected then
		local kind = grug_core.world_feature_at(pos)
		protected = kind == "road" or kind == "bridge" or kind == "village" or
			kind == "fortress" or kind == "war_camp" or kind == "mining_camp"
	end
	if not protected and capital_zone(grug_zones.id_at(x, z)) then
		protected = grug_zones.hard_protection_kind_at(pos) == "town"
	end
	last_x, last_y, last_z, last_protected = x, y, z, protected
	return protected
end

-- The Miner's Guild rooms (Round 58, grug_mapgen.guild_rooms): no ambient
-- underground spawn in a room's box, an allocation-free test that returns at
-- once outside the rooms' few y bands.
local guild_rooms = rawget(_G, "grug_mapgen") and grug_mapgen.guild_rooms

-- A rectangle no natural mob spawns in, at any y, the sea's own rows included
-- (Round 71, the user's ruling: no random mob's nametag through an Expedition's
-- wall). grug_expeditions sets it; empty until then. One comparison on the map.
local free_min_x, free_max_x, free_min_z, free_max_z =
	math.huge, -math.huge, math.huge, -math.huge

function grug_mobs.set_spawn_free_field(min_x, max_x, min_z, max_z)
	free_min_x, free_max_x, free_min_z, free_max_z = min_x, max_x, min_z, max_z
end

-- Allocation-free spawn policy. Unknown ABM families fail closed.
function grug_mobs.spawn_policy_allows(mob_name, pos)
	if pos.x >= free_min_x and pos.x <= free_max_x and
			pos.z >= free_min_z and pos.z <= free_max_z then
		return false
	end
	-- Before every other authority, the Kraken's included: a start footprint
	-- refuses each hostile row outright. Passive critters keep spawning there.
	if hostile_spawns[mob_name] and
			grug_mobs.in_start_footprint(pos.x, pos.z, pos.y) then
		return false
	end
	if INDEPENDENT_AUTHORITY[mob_name] then
		return true
	end
	if pos.y < UNDERGROUND_TOP then
		if not UNDERGROUND_MOBS[mob_name] then
			return false
		end
		if guild_rooms and guild_rooms.room_at(pos) then
			return false
		end
		-- Round 46: the elite floor of the underground elite roll
		-- (underground_spawned) holds for an elite by definition too, so a
		-- shallow cave of a start zone never spawns an elite golem.
		if elite_spawns[mob_name] then
			local level = grug_zones.mob_level_at(pos)
			return level ~= nil and level >= grug_mobs.UNDERGROUND_ELITE_MIN_LEVEL
		end
		return true
	end
	if not grug_mobs.spawn_clock_allows(mob_name, pos) then
		return false
	end
	-- Surface rows begin at zero and the underground domain below -1: the
	-- one node layer at y = -1 between them stays closed.
	if pos.y < 0 then
		return false
	end
	local zone_id = grug_zones.id_at(pos.x, pos.z)
	-- Round 28 ruling 34: every zone spawns its surface mobs from its spawn
	-- recipe's regions (spawn_regions.lua). Its ABM rows keep the critters
	-- the recipe lists and RECIPE_ZONE_ROWS (Rift Spawn); every other row is
	-- refused. The Gull keeps its beach host. Outside every zone no surface
	-- row spawns (the land there is none: spawn_row_kept below).
	if not zone_id or not grug_mobs.spawn_regions.zone_has_recipe(zone_id) then
		return false
	end
	local kept = RECIPE_ZONE_ROWS[mob_name]
	if kept then
		-- Ruling 3 still last: never on a protected surface.
		return kept[zone_id] == true and not grug_mobs.protected_spawn_surface(pos)
	end
	if not grug_mobs.spawn_regions.zone_critter(zone_id, mob_name) then
		return false
	end
	if mob_name == "grug_mobs:gull" then
		return grug_zones.biome_at(pos.x, pos.z) == "grug_beach"
	end
	return true
end

--
-- Which ABM spawn rows still run (Round 30 P2, the user's ruling on perf
-- review 2026-10 #11, round30-plan.md §1). The spawn regions own the surface
-- of every zone, where spawn_policy_allows refuses every row but the
-- recipe's critters and RECIPE_ZONE_ROWS. A surface row of any other mob
-- could only spawn outside every zone, and the dry ground outside every zone
-- is none: the only zone-less land columns are dragon-channel floors at
-- height 0, under the sea at water level 1 (checked on seeds 12345 and 42).
-- Such a row is retired: no ABM is registered for it. Round 81 (ruling 6)
-- removed the 56 surface rows this retired; the rule stays for a new row.
-- Underground rows (top at or below UNDERGROUND_TOP) and the independent
-- authorities (Kraken, Reed Angelfish, the sharks, the Tide Goby) stay,
-- merged by spawn_abms.lua. `max_y` is the row's top.
function grug_mobs.spawn_row_kept(name, max_y)
	if max_y <= UNDERGROUND_TOP or INDEPENDENT_AUTHORITY[name] or
			RECIPE_ZONE_ROWS[name] then
		return true
	end
	local SR = grug_mobs.spawn_regions
	for _, zone_id in ipairs(SR.zone_ids()) do
		if SR.zone_critter(zone_id, name) then
			return true
		end
	end
	return false
end
