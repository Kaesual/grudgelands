-- Direct stable-query spawn gates. Surface mobs require both their existing
-- node whitelist and the owning named zone's explicit mob palette
-- (docs/design/world_zones.md Section 8). The old radial spawn buckets are
-- not reconstructed.

local VALID_DOMAINS = {
	contested = true,
	underground = true,
}

local VALID_CLOCKS = {
	day = true,
	night = true,
	any = true,
}

local NIGHT_FALLBACKS = {
	settled = "grug_mobs:zombie",
	war = "grug_mobs:zombie",
	forest = "grug_mobs:skeleton_archer",
	mountain = "grug_mobs:skeleton_archer",
	jungle = "grug_mobs:jungle_spider",
	swamp = "grug_mobs:bog_ooze",
}

-- Closed named-zone mob palettes (world_zones.md Section 8), the boar tint
-- and the lookalike choices per zone. Since Round 28 they are data: the
-- `palette` of each zone's data/zones/<zone_id>.spawns.json, read by
-- spawn_areas.lua. Capitals deliberately have empty palettes. Lorindor is
-- intentionally literal: its row names pale stags, not the complete forest
-- family. A zone whose data defines spawn areas (ruling 34) ignores its
-- palette for surface mobs; see spawn_policy_allows.
local ZONE_MOB_PALETTES, BOAR_VARIANT_BY_ZONE, ZONE_LOOKALIKE_SELECTION =
	grug_mobs.spawn_areas.fallback_palettes()

-- A mob may name more than one Section 8 family where the catalog says so.
-- Existing mobs:spawn node lists remain the narrower habitat selector.
-- Section 3.1 makes Jungle Lynx the inner/outer bridge and Parrot the
-- jungle-edge critter; lower-jungle, jungle and high-jungle use the remaining
-- outer/coast jungle family, with the zone level supplying the adjective.
local MOB_PALETTES = {
	["grug_mobs:boar"] = {settled = true},
	["grug_mobs:plague_boar"] = {settled = true},
	["grug_mobs:jungle_boar"] = {settled = true},
	["grug_mobs:rabbit"] = {settled = true},
	["grug_mobs:hare"] = {settled = true},
	["grug_mobs:zombie"] = {settled = true, war = true},

	["grug_mobs:wolf"] = {forest = true},
	["grug_mobs:blightfang_wolf"] = {forest = true},
	["grug_mobs:bear"] = {forest = true},
	["grug_mobs:plaguehide_bear"] = {forest = true},
	["grug_mobs:stag"] = {forest = true},
	["grug_mobs:gaunt_stag"] = {forest = true},
	["grug_mobs:giant_spider"] = {forest = true},
	["grug_mobs:pale_spider"] = {forest = true},
	["grug_mobs:skeleton_archer"] = {forest = true, war = true},
	["grug_mobs:bone_weevil"] = {forest = true},

	["grug_mobs:crag_eagle"] = {mountain = true},
	["grug_mobs:vulture"] = {mountain = true},
	["grug_mobs:stone_golem"] = {mountain = true},
	["grug_mobs:mesa_golem"] = {mountain = true},
	["grug_mobs:mountain_ram"] = {mountain = true},
	["grug_mobs:hyena"] = {mountain = true, savanna = true},
	["grug_mobs:zebra"] = {savanna = true},

	["grug_mobs:jungle_lynx"] = {jungle_edge = true, jungle = true},
	["grug_mobs:panther"] = {jungle = true},
	["grug_mobs:serpent"] = {jungle = true},
	["grug_mobs:jungle_ape"] = {jungle = true},
	["grug_mobs:jungle_spider"] = {jungle = true},
	["grug_mobs:parrot"] = {jungle_edge = true},

	["grug_mobs:crocodile"] = {swamp = true},
	["grug_mobs:bog_ooze"] = {swamp = true},
	["grug_mobs:bog_fowl"] = {swamp = true},

	["grug_mobs:skeleton_raider"] = {war = true},
	["grug_mobs:carrion_crow"] = {war = true},

	["grug_mobs:poacher"] = {poacher = true},
	["grug_mobs:frost_stray"] = {frost_stray = true},
	["grug_mobs:sun_dried_husk"] = {sun_dried_husk = true},
	["grug_mobs:song_bird"] = {song_bird = true},
	["grug_mobs:fox"] = {fox = true},
	["grug_mobs:ibex"] = {ibex = true},
	["grug_mobs:wild_turkey"] = {wild_turkey = true},
	["grug_mobs:plains_runner"] = {plains_runner = true},
	["grug_mobs:tapir"] = {tapir = true},
	["grug_mobs:giant_rat"] = {giant_rat = true},
	["grug_mobs:scorpion"] = {scorpion = true},
	["grug_mobs:viper"] = {viper = true},
	["grug_mobs:goblin_raider"] = {goblin_raid = true},
	["grug_mobs:goblin_slinger"] = {goblin_raid = true},
	["grug_mobs:goblin_hound"] = {goblin_raid = true},
	["grug_mobs:snow_leopard"] = {snow_leopard = true},
	["grug_mobs:wisp"] = {wisp = true},
	["grug_mobs:ashen_treant"] = {ashen_treant = true},
	["grug_mobs:gravewood_treant"] = {gravewood_treant = true},
	["grug_mobs:war_construct"] = {war_construct = true},
	["grug_mobs:speargrass_tiger"] = {speargrass_tiger = true},
	["grug_mobs:bog_witch"] = {bog_witch = true},
	["grug_mobs:rift_spawn"] = {rift_spawn = true},
}

-- Boars share one family budget and one visual identity per named zone. The
-- node whitelist remains a habitat check, but a biome patch inside a zone may
-- no longer switch the family to a second lookalike registration. The zone's
-- tint is its palette's `boar` (BOAR_VARIANT_BY_ZONE above).
local BOAR_VARIANTS = {
	["grug_mobs:boar"] = true,
	["grug_mobs:plague_boar"] = true,
	["grug_mobs:jungle_boar"] = true,
}

-- Other shared-model regional tints use the same zone-level selection. Rows
-- with genuinely different silhouettes or combat roles are not folded into
-- this table merely because their imported mesh is shared. A zone's choice
-- per family is its palette's `lookalikes` (ZONE_LOOKALIKE_SELECTION above).
local LOOKALIKE_FAMILY = {
	["grug_mobs:zombie"] = "zombie",
	["grug_mobs:sun_dried_husk"] = "zombie",
	["grug_mobs:giant_spider"] = "spider",
	["grug_mobs:pale_spider"] = "spider",
	["grug_mobs:jungle_spider"] = "spider",
	["grug_mobs:jungle_lynx"] = "cat",
	["grug_mobs:panther"] = "cat",
	["grug_mobs:snow_leopard"] = "cat",
	["grug_mobs:skeleton_archer"] = "skeleton_archer",
	["grug_mobs:skeleton_raider"] = "skeleton_archer",
	["grug_mobs:frost_stray"] = "skeleton_archer",
}

-- Kraken has an independent authority instead of a named-zone mob palette:
-- water_class_at == deep_ocean in kraken.lua.
local INDEPENDENT_AUTHORITY = {
	["grug_mobs:kraken"] = true,
	["grug_mobs:reed_angelfish"] = true,
}

-- The existing cave rows are exact. Keeping this list closed preserves their
-- y < -40 behavior without letting a new Grudgelands family silently bypass
-- the named-zone policy merely because it added a negative-height ABM.
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
	["grug_mobs:land_guard"] = true,
	["grug_mobs:rift_spawn"] = true,
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
-- deliberately NOT covered here: their named zones' mob palettes are empty,
-- so no ordinary row reaches the city or the ground around it anyway. Round
-- 28 ruling 3 adds the capital city for every ambient non-critter spawn
-- (grug_mobs.protected_spawn_surface below), which spawn areas in a capital
-- zone's outskirts need.
local START_PAD_LOW = 64 -- the pad: anchor - 64 .. anchor + 63, half-open
local START_PAD_HIGH = 63
local START_BAND = 12
local start_pads

-- Round 24 ruling 30: a start town is hard-protected only from its floor
-- (placement height - 100, owned by the zone authority) upward, so the
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
-- is looked at (api.lua:1853-1859) and `not self.attack_players` drops every
-- player (api.lua:1871-1885). attack_players defaults to TRUE in mob_class
-- (api.lua:157-218), hence the explicit `== false`; grug_mobs.passive_prey
-- (verbs.lua) sets it for the four non-passive prey animals. Deriving it
-- keeps it from drifting the way a hand-kept hostile list would.
local hostile_spawns = {}
local claim_hostile_spawns = {}
local spawn_clocks = {}
local ambient_density_spawns = {}
local natural_min_levels = {}
local zone_palette_at

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
	for palette, value in pairs(clock) do
		if type(palette) ~= "string" or not VALID_CLOCKS[value] then
			error("[grug_mobs] invalid palette spawn clock for " .. name)
		end
		count = count + 1
	end
	if count == 0 then
		error("[grug_mobs] empty palette spawn clock for " .. name)
	end
end

function grug_mobs.register_spawn_role(name, def)
	validate_clock(def.clock, name)
	hostile_spawns[name] = def.passive ~= true and def.attack_players ~= false
	-- Settlement people (guards, royal guards, villagers, vendors: all
	-- `type = "npc"`) are never refused by a housing claim (ruling 24).
	claim_hostile_spawns[name] = hostile_spawns[name] and def.type ~= "npc"
	spawn_clocks[name] = def.clock
	natural_min_levels[name] = def._grug_min_level or 1
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

local function clock_for_palette(name, palette)
	local clock = spawn_clocks[name]
	if type(clock) == "table" then
		return clock[palette]
	end
	return clock
end

-- A clock table may name one named zone with a "zone:<zone id>" key (Round
-- 24 ruling 31: the Sunscar Scorpion and the Kapok Viper keep their night
-- clock elsewhere and spawn around the clock in their start zone). It wins
-- over the palette keys, so the choice never depends on table order.
local function zone_clock_key(clock, zone_id)
	local key = zone_id and ("zone:" .. zone_id)
	return key and clock[key] and key or nil
end

-- `zone_id` is optional: when given it selects the zone key; otherwise the
-- zone of `pos`; with neither there is no zone key (a caller that asks for a
-- zone palette without a position).
local function clock_palette_at(name, pos, zone_palette, zone_id)
	local clock = spawn_clocks[name]
	if type(clock) ~= "table" then
		return nil
	end
	if zone_id == nil and pos then
		zone_id = grug_zones.id_at(pos.x, pos.z)
	end
	local zone_key = zone_clock_key(clock, zone_id)
	if zone_key then
		return zone_key
	end
	if clock.blight and pos and grug_zones.biome_at(pos.x, pos.z) == "grug_blight" then
		return "blight"
	end
	if clock.war and zone_palette and zone_palette.war then
		return "war"
	end
	if clock.settled and zone_palette and zone_palette.settled then
		return "settled"
	end
	for palette in pairs(clock) do
		if zone_palette and zone_palette[palette] then
			return palette
		end
	end
	return nil
end

-- `zone_id` is optional and wins over the zone of `pos` (clock_palette_at).
function grug_mobs.spawn_clock_for(name, pos, zone_id)
	if pos and pos.y < -40 then
		return "any"
	end
	local zone_palette = zone_id and ZONE_MOB_PALETTES[zone_id] or
		(pos and zone_palette_at(pos)) or nil
	local palette = (pos or zone_id) and
		clock_palette_at(name, pos, zone_palette, zone_id) or nil
	return clock_for_palette(name, palette)
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

-- Round 24 ruling 27: ordinary natural surface species that own a named-zone
-- palette row share one per-area budget per zone and clock (density.lua).
-- Mobs with an independent authority (Kraken, Reed Angelfish), level-split
-- shore rows and every other ambient species without a palette keep the
-- Round 16 per-species rule below.
function grug_mobs.density_budgeted(name)
	return ambient_density_spawns[name] == true and MOB_PALETTES[name] ~= nil
		and not INDEPENDENT_AUTHORITY[name]
end

-- Family clocks own the mobs_redo row convention. Underground rows remain
-- light-driven and keep their explicit max_light without a day_toggle.
function grug_mobs.prepare_spawn_row(def)
	local row = {}
	for key, value in pairs(def) do
		if key ~= "_grug_clock_palette" then
			row[key] = value
		end
	end
	if row.max_height and row.max_height <= -40 then
		row.day_toggle = nil
		return row
	end
	local budgeted = grug_mobs.density_budgeted(row.name)
	if budgeted then
		-- The budget (density.lua) owns the area cap. The row's own
		-- per-species cap is lifted to the largest budget so mobs_redo's
		-- count never binds first; the registered cap is the species weight.
		-- Attempt frequency rises by the same first-pass factor.
		grug_mobs.note_density_row(row)
		if row.chance then
			row.chance = math.max(1, math.floor(
				row.chance / grug_mobs.DENSITY_ATTEMPT_SCALE + 0.5))
		end
		row.active_object_count = grug_mobs.density_row_cap()
	elseif ambient_density_spawns[row.name] then
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
	local clock = clock_for_palette(row.name, def._grug_clock_palette)
	if not clock then
		error("[grug_mobs] spawn row has no clock role: " .. tostring(row.name))
	end
	row.min_light = nil
	row.max_light = nil
	row.day_toggle = nil
	if clock == "day" then
		row.min_light = 10
		-- mobs_redo's day window (api.lua day_toggle: 4500..19500 of 24000)
		-- is DAY_PHASE_START..END. Without it a day row also fires at night
		-- on torch light >= 10, and a zone-keyed day row (the Sunscar Scorpion)
		-- would pass the night clock outside its zone.
		row.day_toggle = true
	elseif clock == "night" then
		row.max_light = 5
		row.day_toggle = false
		if row.active_object_count and not budgeted then
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

zone_palette_at = function(pos)
	local zone_id = grug_zones.id_at(pos.x, pos.z)
	return zone_id and ZONE_MOB_PALETTES[zone_id] or nil
end

local function night_fallback_allows(name, zone_palette)
	local count = 0
	for mob_name, mob_palettes in pairs(MOB_PALETTES) do
		local matched_palette
		if zone_palette.exact_mobs and zone_palette.exact_mobs[mob_name] then
			matched_palette = "exact"
		else
			for palette in pairs(mob_palettes) do
				if zone_palette[palette] then
					matched_palette = palette
					break
				end
			end
		end
		if matched_palette then
			local role_clock = matched_palette == "exact" and
				clock_for_palette(mob_name, nil) or
				clock_for_palette(mob_name, matched_palette)
			if role_clock == "night" then count = count + 1 end
		end
	end
	for palette, fallback in pairs(NIGHT_FALLBACKS) do
		if fallback == name and (zone_palette[palette] or
				(zone_palette.night_fallback and
				zone_palette.night_fallback[palette])) then
			if count < 2 then
				return true
			end
		end
	end
	return false
end

function grug_mobs.zone_clock_cast(zone_id, clock)
	if not VALID_CLOCKS[clock] or clock == "any" then
		error("[grug_mobs] cast clock must be day or night")
	end
	local zone_palette = ZONE_MOB_PALETTES[zone_id]
	if not zone_palette then
		return nil
	end
	local cast = {}
	for mob_name, mob_palettes in pairs(MOB_PALETTES) do
		local matched_palette
		if zone_palette.exact_mobs and zone_palette.exact_mobs[mob_name] then
			matched_palette = "exact"
		else
			for palette in pairs(mob_palettes) do
				if zone_palette[palette] then
					matched_palette = palette
					break
				end
			end
		end
		if matched_palette then
			local role_clock = matched_palette == "exact" and
				clock_for_palette(mob_name, nil) or
				clock_for_palette(mob_name, matched_palette)
			local mob_clock = spawn_clocks[mob_name]
			local zone_key = type(mob_clock) == "table" and
				zone_clock_key(mob_clock, zone_id)
			if zone_key then role_clock = mob_clock[zone_key] end
			if role_clock == clock or role_clock == "any" then
				cast[#cast + 1] = mob_name
			end
		end
	end
	if clock == "night" then
		for palette, fallback in pairs(NIGHT_FALLBACKS) do
			if zone_palette[palette] or (zone_palette.night_fallback and
					zone_palette.night_fallback[palette]) then
				local present = false
				for i = 1, #cast do
					if cast[i] == fallback then present = true; break end
				end
				if not present and night_fallback_allows(fallback, zone_palette) then
					cast[#cast + 1] = fallback
				end
			end
		end
	end
	table.sort(cast)
	return cast
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
	if pos.y < -40 then
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

-- Used by the Skeleton Archer's row-specific check: forest host nodes remain
-- valid in forest palettes, while its generic settled-top row requires the
-- explicit war palette rather than merely any contested zone.
function grug_mobs.zone_spawn_palette_allows(palette, pos)
	local zone_palette = zone_palette_at(pos)
	return zone_palette and zone_palette[palette] == true or false
end

-- Variant-side authority for mob pairs whose surface nodes are shared across
-- both continents. Contested zones deliberately have no political faction,
-- so their stable cultural race region selects the matching variant.
function grug_mobs.race_region_spawn_allows(faction_id, pos)
	return RACE_FACTIONS[grug_zones.race_region_at(pos.x, pos.z)] ==
		faction_id
end

-- The zone-level half of the surface policy: one regional variant per
-- lookalike family, the zone's palette and its night fallback.
local function zone_allows(mob_name, zone_id)
	if BOAR_VARIANTS[mob_name] and BOAR_VARIANT_BY_ZONE[zone_id] ~= mob_name then
		return false
	end
	local family = LOOKALIKE_FAMILY[mob_name]
	local selection = zone_id and ZONE_LOOKALIKE_SELECTION[zone_id]
	if family and selection and selection[family] and
			selection[family] ~= mob_name then
		return false
	end
	local mob_palettes = MOB_PALETTES[mob_name]
	if not mob_palettes then
		return false
	end
	local zone_palette = zone_id and ZONE_MOB_PALETTES[zone_id] or nil
	if not zone_palette then
		return false
	end
	if zone_palette.exact_mobs and zone_palette.exact_mobs[mob_name] then
		return true
	end
	for palette in pairs(mob_palettes) do
		if zone_palette[palette] then
			return true
		end
	end
	return night_fallback_allows(mob_name, zone_palette)
end

--
-- Round 28 ruling 3: no ambient non-critter spawn on the exact protected
-- surface: a road corridor or bridge and a village's building core
-- (grug_core.world_feature_at, the half width + 1 corridor of ruling 1 and
-- the village boxes), a start town's footprint and a capital city
-- (grug_zones.hard_protection_kind_at "town"). No margin beyond them: the
-- idle push of ruling 2 keeps aggressive mobs off roads and towns, a margin
-- of aggro range would empty land trails run through. Camps and other POIs
-- are not refused, and critters may still appear in towns.
--
-- Called for ABM rows (spawn_policy_allows, ordinary natural rows only) and
-- for every non-critter area spawn (spawn_areas.lua). `pos` is where the mob
-- stands or the node it stands on: the road corridor reaches +-5 around the
-- road surface and the other shapes are full columns, so both answer alike.
-- The start footprint is the plain-number test above; the capital query is
-- asked only in the six capital zones. The density budget asks the policy
-- for several species at one point in a row, so the last answer is kept.
--
local capital_zones
local last_x, last_y, last_z, last_protected

local function capital_zone(zone_id)
	if not capital_zones then
		capital_zones = {}
		for zone_id_ in pairs(ZONE_MOB_PALETTES) do
			if grug_zones.anchor(zone_id_, "capital") then
				capital_zones[zone_id_] = true
			end
		end
	end
	return capital_zones[zone_id] == true
end

function grug_mobs.protected_spawn_surface(pos)
	local x, y, z = pos.x, pos.y, pos.z
	if x == last_x and y == last_y and z == last_z then
		return last_protected
	end
	local protected = grug_mobs.in_start_footprint(x, z, y)
	if not protected then
		local kind = grug_core.world_feature_at(pos)
		protected = kind == "road" or kind == "bridge" or kind == "village"
	end
	if not protected and capital_zone(grug_zones.id_at(x, z)) then
		protected = grug_zones.hard_protection_kind_at(pos) == "town"
	end
	last_x, last_y, last_z, last_protected = x, y, z, protected
	return protected
end

-- Allocation-free spawn policy. Unknown ABM families fail closed.
function grug_mobs.spawn_policy_allows(mob_name, pos)
	-- Before every other authority, the Kraken's included: a start footprint
	-- refuses each hostile row outright, the zombie's 24 h blight row inside
	-- Stillgrave Hollow among them. Passive critters keep spawning there.
	if hostile_spawns[mob_name] and
			grug_mobs.in_start_footprint(pos.x, pos.z, pos.y) then
		return false
	end
	if INDEPENDENT_AUTHORITY[mob_name] then
		return true
	end
	if pos.y < -40 then
		return UNDERGROUND_MOBS[mob_name] == true
	end
	if not grug_mobs.spawn_clock_allows(mob_name, pos) then
		return false
	end
	-- The cave ABMs end at -40, but the stable depth domain begins strictly
	-- below it. Surface ABMs begin at zero, so the intervening band is closed.
	if pos.y < 0 then
		return false
	end
	local zone_id = grug_zones.id_at(pos.x, pos.z)
	-- Round 28 ruling 34: a zone whose data defines spawn areas spawns its
	-- surface mobs only from them (spawn_areas.lua). Its ABM rows keep the
	-- critters its data lists; crabs and every other row are refused. The
	-- Gull keeps its beach host.
	if zone_id and grug_mobs.spawn_areas.zone_has_areas(zone_id) then
		if not grug_mobs.spawn_areas.zone_critter(zone_id, mob_name) then
			return false
		end
		if mob_name == "grug_mobs:gull" then
			return grug_zones.biome_at(pos.x, pos.z) == "grug_beach"
		end
		return true
	end
	local local_level = grug_zones.mob_level_at(pos)
	if not local_level or local_level < (natural_min_levels[mob_name] or 1) then
		return false
	end
	-- The Gull follows the logical beach palette. Crab rows ignore palettes:
	-- their host is dry `default:sand` near water (shore_crab.lua, D36), and
	-- the level splits every such shore between the neutral Shore Crab below
	-- level 45 and the elite Reef Lurker from 45 to 60. The node host is
	-- enforced by mobs_redo before this allocation-free policy callback.
	local allowed
	if mob_name == "grug_mobs:gull" then
		allowed = grug_zones.biome_at(pos.x, pos.z) == "grug_beach"
	elseif mob_name == "grug_mobs:shore_crab" then
		allowed = local_level < 45
	elseif mob_name == "grug_mobs:reef_lurker" then
		allowed = local_level >= 45 and local_level <= 60
	else
		allowed = zone_allows(mob_name, zone_id)
	end
	-- Ruling 3, last: only an otherwise allowed ordinary natural row pays it.
	if allowed and ambient_density_spawns[mob_name] and
			grug_mobs.protected_spawn_surface(pos) then
		return false
	end
	return allowed
end

-- Round 24 ruling 27: the budgeted species a zone can host at a clock, with
-- the zone-level half of spawn_policy_allows (regional variant, palette,
-- night fallback) and the palette's static clock. Level gates, row checks
-- and host nodes stay point properties; density.lua resolves those at the
-- spawn position. Sorted, so every consumer sees the same order.
function grug_mobs.zone_density_cast(zone_id, clock)
	local zone_palette = ZONE_MOB_PALETTES[zone_id]
	local cast = {}
	if not zone_palette then
		return cast
	end
	for mob_name in pairs(MOB_PALETTES) do
		if grug_mobs.density_budgeted(mob_name) and
				zone_allows(mob_name, zone_id) then
			local role_clock
			if zone_palette.exact_mobs and zone_palette.exact_mobs[mob_name] then
				role_clock = clock_for_palette(mob_name, nil)
			else
				-- The zone id selects a "zone:<id>" clock key (ruling 31).
				role_clock = clock_for_palette(mob_name,
					clock_palette_at(mob_name, nil, zone_palette, zone_id))
			end
			if role_clock == clock or role_clock == "any" then
				cast[#cast + 1] = mob_name
			end
		end
	end
	table.sort(cast)
	return cast
end

function grug_mobs.density_zone_ids()
	local ids = {}
	for zone_id in pairs(ZONE_MOB_PALETTES) do
		ids[#ids + 1] = zone_id
	end
	table.sort(ids)
	return ids
end
