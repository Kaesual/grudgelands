--
-- Round 28 rulings 34, 37 and 38, Lane S1: rule-based spawn regions.
--
-- Every named zone has ONE data file, data/zones/<zone_id>.spawns.json. It
-- carries either
--   * `palette`  today's named-zone mob palette (world_zones.md §8 families,
--                the boar tint and lookalike choices) for the zone's ABM
--                rows: a zone WITHOUT a recipe keeps today's spawning exactly
--                (the trigger of ruling 34); or
--   * `recipe`   the rules its spawn regions are built from (belts, kinds,
--                camps, leaders, quest places, critters;
--                docs/design/spawn_regions.md). A
--                zone WITH a recipe spawns its surface mobs only from its
--                regions; its ABM rows keep the recipe's critters.
-- A recipe holds no coordinate: the world differs per seed. Every recipe
-- zone's REGION MAP is built from the analytic world (spawn_regions_core.lua,
-- the same file the offline renderer tools/r28_regions runs) once at server
-- start (mods loaded) and kept in its compact form for the session
-- (spawn_regions_cache.lua); a later start of the same world reads the maps
-- back from the world folder instead of building them.
--
-- Spawning at a point uses the region there: the roster of the current clock,
-- a level in the region's range for the role (belt range x role range), the
-- region's density class as its share of the zone's density budget. Every
-- mob carries `_grug_area = "<zone_id>/<kind or camp id>"` (quests credit by
-- kind, so a kill objective works on every seed however many patches a kind
-- has) and `_grug_spawn_clock`. Camps spawn through their slots (camps.lua);
-- leaders stand at their rule-placed spot with a fixed level.
--
-- Unchanged: underground spawns, water spawns and swimmers, rares, vendors,
-- guards and guard posts, mapgen content.
--

local SR = {}
grug_mobs.spawn_regions = SR

local MOD_PREFIX = "grug_mobs:"
local MODPATH = core.get_modpath(core.get_current_modname())
local DATA_DIR = MODPATH .. "/data/zones"
local CORE = dofile(MODPATH .. "/spawn_regions_core.lua")
SR.core = CORE

local FILE_KEYS = {zone = true, palette = true, recipe = true, notes = true}
local PALETTE_KEYS = {families = true, exact_mobs = true, night_fallback = true,
	boar = true, lookalikes = true}

local zones = {} -- zone_id -> {id, palette, boar, lookalikes, recipe}
-- The fallback tables spawn_policy.lua reads, kept current by install_zone.
local palette_by_zone, boar_by_zone, lookalikes_by_zone = {}, {}, {}
local unit_by_tag = {} -- "zone/kind" or "zone/camp" -> kind or camp (recipe)
local leader_by_role = {} -- role -> {zone, leader (parsed)}
local maps = {} -- zone_id -> compact map, or false after a failed build
-- Zones whose data came from their shipped file (load_all), the only ones the
-- world-folder cache serves: a probe's install_zone data is not that file.
local from_file = {}

local function fail(where, message)
	error("[grug_mobs] spawn data " .. where .. ": " .. message, 0)
end

local function known_keys(row, allowed, where)
	for k in pairs(row) do
		if not allowed[k] then
			fail(where, "unknown field " .. tostring(k))
		end
	end
end

local function read_file(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()
	return text
end

-- The compact form and the world-folder file (spawn_regions_cache.lua).
local CACHE = dofile(MODPATH .. "/spawn_regions_cache.lua")({
	sha256 = function(bytes) return core.sha256(bytes) end,
	read = read_file,
	write = function(path, bytes) return core.safe_file_write(path, bytes) end,
	cell = CORE.CELL,
})
SR.cache = CACHE

-- The sub-type catalogue's levels and leader flags (subtypes.lua registers
-- the roles later; the recipe only needs these two facts at load).
local catalogue
local function catalogue_rows()
	if not catalogue then
		catalogue = {}
		local text = read_file(MODPATH .. "/data/subtypes.json")
		local data = text and core.parse_json(text) or nil
		if type(data) == "table" and not data[1] then data = data.subtypes end
		for _, row in ipairs(type(data) == "table" and data or {}) do
			if type(row) == "table" and type(row.role) == "string" then
				catalogue[row.role] = row
			end
		end
	end
	return catalogue
end

local function set_of(list, where, what)
	if list == nil then
		return {}
	end
	if type(list) ~= "table" then
		fail(where, what .. " must be a list")
	end
	local out = {}
	for i = 1, #list do
		if type(list[i]) ~= "string" or list[i] == "" then
			fail(where, what .. " entries must be strings")
		end
		out[list[i]] = true
	end
	return out
end

-- Today's named-zone palette, in the shape spawn_policy.lua reads.
local function parse_palette(palette, where)
	if palette == nil then
		return nil
	end
	if type(palette) ~= "table" then
		fail(where, "palette must be an object")
	end
	known_keys(palette, PALETTE_KEYS, where .. " palette")
	local out = set_of(palette.families, where, "palette.families")
	if palette.exact_mobs ~= nil then
		out.exact_mobs = set_of(palette.exact_mobs, where, "palette.exact_mobs")
	end
	if palette.night_fallback ~= nil then
		out.night_fallback = set_of(palette.night_fallback, where,
			"palette.night_fallback")
	end
	if palette.boar ~= nil and type(palette.boar) ~= "string" then
		fail(where, "palette.boar must be an entity name")
	end
	local lookalikes
	if palette.lookalikes ~= nil then
		if type(palette.lookalikes) ~= "table" then
			fail(where, "palette.lookalikes must be an object")
		end
		lookalikes = {}
		for family, name in pairs(palette.lookalikes) do
			if type(family) ~= "string" or type(name) ~= "string" then
				fail(where, "palette.lookalikes maps a family to an entity name")
			end
			lookalikes[family] = name
		end
	end
	return out, palette.boar, lookalikes
end

-- The world model's anchor source (simple_map) and settlement roster, read
-- on first need: the region builder, the POI list of a recipe camp's site
-- and the place names of describe share them.
local mapgen_source, settlement_roster
local function world_source()
	if not mapgen_source then
		mapgen_source = dofile(core.get_modpath("grug_mapgen") .. "/wp40/source/simple_map.lua")
	end
	return mapgen_source
end
local function roster()
	if not settlement_roster then
		settlement_roster = dofile(core.get_modpath("grug_mapgen") ..
			"/wp40/r7_settlement.lua").roster
	end
	return settlement_roster
end

-- The zone's camp POIs with their names (the roster labels).
local function zone_pois(zone_id)
	local labels = {}
	for _, row in ipairs(roster()) do
		if row.anchor_id then labels[row.anchor_id] = row.label end
	end
	return CORE.zone_pois(world_source(), zone_id, labels)
end

-- The context a recipe is parsed in: the zone's band, the catalogue and
-- the zone's camp POIs.
local function recipe_context(zone_id)
	local record = grug_zones.get(zone_id)
	local rows = catalogue_rows()
	return {
		pois = zone_pois,
		band = {record.level_min or 1, record.level_max or 60},
		role_levels = function(role)
			local row = rows[role]
			return row and row.levels or nil
		end,
		leader = function(role)
			local row = rows[role]
			return row ~= nil and row.leader == true
		end,
	}
end

-- Installs one zone's data (the decoded JSON object). The loader below calls
-- it for every file; a probe may install a sample before the mods have
-- loaded. Fails loudly on any format error and leaves the zone's previous
-- data in place then.
function SR.install_zone(zone_id, data)
	local where = tostring(zone_id)
	if type(zone_id) ~= "string" or not grug_zones.get(zone_id) then
		fail(where, "not a zone of the world")
	end
	if type(data) ~= "table" then
		fail(where, "spawns file must be an object")
	end
	known_keys(data, FILE_KEYS, where)
	if data.zone ~= zone_id then
		fail(where, "zone " .. tostring(data.zone) .. " does not match the file")
	end
	local palette, boar, lookalikes = parse_palette(data.palette, where)
	local recipe
	if data.recipe ~= nil then
		recipe = CORE.parse_recipe(zone_id, data.recipe, recipe_context(zone_id))
	elseif not palette then
		-- Without a recipe the palette IS the zone's surface rule.
		fail(where, "a zone without a recipe needs its palette (today's spawn rule)")
	end
	if recipe then
		for _, leader in ipairs(recipe.leaders) do
			local taken = leader_by_role[leader.role]
			if taken and taken.zone ~= zone_id then
				fail(where, "leader role " .. leader.role .. " is placed by " .. taken.zone)
			end
		end
	end
	-- Everything parsed: replace the zone's previous data in one go.
	local old = zones[zone_id]
	if old and old.recipe then
		for _, kind in ipairs(old.recipe.kinds) do unit_by_tag[kind.tag] = nil end
		for _, camp in ipairs(old.recipe.camps) do unit_by_tag[camp.tag] = nil end
		for _, leader in ipairs(old.recipe.leaders) do leader_by_role[leader.role] = nil end
	end
	if recipe then
		for _, kind in ipairs(recipe.kinds) do unit_by_tag[kind.tag] = kind end
		for _, camp in ipairs(recipe.camps) do unit_by_tag[camp.tag] = camp end
		for _, leader in ipairs(recipe.leaders) do
			leader_by_role[leader.role] = {zone = zone_id, leader = leader}
		end
	end
	zones[zone_id] = {id = zone_id, palette = palette, boar = boar,
		lookalikes = lookalikes, recipe = recipe}
	maps[zone_id] = nil
	from_file[zone_id] = nil
	palette_by_zone[zone_id] = palette
	boar_by_zone[zone_id] = boar
	lookalikes_by_zone[zone_id] = lookalikes
	return zones[zone_id]
end

-- Every data file, at load (the zone authority is installed before
-- grug_mobs loads).
local function load_all()
	local names = core.get_dir_list(DATA_DIR, false) or {}
	table.sort(names)
	for _, name in ipairs(names) do
		local zone_id = name:match("^([%w_]+)%.spawns%.json$")
		if zone_id then
			local text = read_file(DATA_DIR .. "/" .. name)
			local data, err = core.parse_json(text or "", nil, true)
			if data == nil then
				fail(name, "unreadable JSON: " .. tostring(err))
			end
			SR.install_zone(zone_id, data)
			from_file[zone_id] = true
		end
	end
end
load_all()

--
-- Region maps
--

-- The world the builder reads, as grug_zones and grug_mapgen publish it.
local query_env
local function queries()
	if not query_env then
		local wp40 = grug_mapgen.wp40
		query_env = CORE.queries({
			zones = grug_zones,
			column_values_at = wp40.planner_source.column_values_at,
			road_polylines = wp40.road_polylines,
			source = world_source(),
		})
	end
	return query_env
end
SR.queries = queries

SR.build_stats = {} -- zone_id -> {ms, cells, regions}

-- The zone's FULL region map, built afresh (spawn_regions_core.build): every
-- cell with its fields and every region's cells. The game keeps only the
-- compact form (SR.map); this is for the tools that read cells. Nil and the
-- reason for a zone without a recipe or when the build fails.
function SR.full_map(zone_id)
	local rec = zones[zone_id]
	if not rec or not rec.recipe then
		return nil, "no recipe"
	end
	local ok, built = pcall(CORE.build, zone_id, queries(), rec.recipe)
	if not ok then
		return nil, tostring(built)
	end
	return built
end

-- The start hook keeps every zone's payload until it has stored the file
-- (then nil): zone_id -> payload.
local payloads = {}

-- Builds the zone's map and keeps its compact form. Returns the map, or nil
-- after a failed build (logged once).
local function build_map(zone_id, rec)
	local t0 = core.get_us_time()
	local ok, built, payload = pcall(function()
		local full = CORE.build(zone_id, queries(), rec.recipe)
		local compact = CACHE.compact(full)
		local map = assert(CACHE.rehydrate(zone_id, compact, rec.recipe))
		return {cells = #full.order, regions = #full.regions, camps = #full.camps,
			leaders = #full.leaders, map = map}, compact
	end)
	local ms = (core.get_us_time() - t0) / 1000
	if not ok then
		maps[zone_id] = false
		core.log("error", "[grug_mobs] spawn regions " .. zone_id ..
			": the region map could not be built: " .. tostring(built))
		return nil
	end
	local map = built.map
	maps[zone_id] = map
	if payloads then payloads[zone_id] = payload end
	SR.build_stats[zone_id] = {ms = ms, cells = built.cells, regions = built.regions}
	core.log("action", ("[grug_mobs] spawn regions %s: %d land cells, %d regions, " ..
		"%d camps, %d leaders, built in %.0f ms"):format(zone_id,
		built.cells, built.regions, built.camps, built.leaders, ms))
	for _, problem in ipairs(map.problems) do
		core.log("warning", "[grug_mobs] spawn regions " .. zone_id .. ": " .. problem)
	end
	for _, warning in ipairs(map.warnings) do
		core.log("warning", "[grug_mobs] spawn regions " .. zone_id .. ": " .. warning)
	end
	return map
end

-- The zone's region map (compact form), built on first need; nil for a zone
-- without a recipe or whose build failed (logged once).
function SR.map(zone_id)
	local map = maps[zone_id]
	if map ~= nil then
		return map or nil
	end
	local rec = zones[zone_id]
	if not rec or not rec.recipe then
		return nil
	end
	return build_map(zone_id, rec)
end

-- The region at a world column and its zone (nil, zone without a region).
function SR.region_at(x, z)
	local zone_id = grug_zones.id_at(x, z)
	local rec = zone_id and zones[zone_id]
	if not rec or not rec.recipe then
		return nil, zone_id
	end
	local map = SR.map(zone_id)
	return map and map.region_at(x, z) or nil, zone_id
end

-- One level truth (Round 28 S1): in a zone with a recipe the surface level
-- of a column is its region's level (the middle of its belt), so mob, ore
-- and fishing levels match the mob map. Registered with grug_core as the
-- runtime layer over the analytic level field, which the mapgen alone reads.
function SR.level_at(x, z)
	local region = SR.region_at(x, z)
	return region and region.level or nil
end
grug_core.register_level_overlay(SR.level_at)

--
-- Seams (B4 and the other lanes)
--

function SR.zone_has_recipe(zone_id)
	local rec = zones[zone_id]
	return rec ~= nil and rec.recipe ~= nil
end

-- What a quest may reference as an "area" (`<zone>/<id>`): a kind or a camp
-- of the zone's recipe, with its levels {lo, hi} (union over its roles),
-- levels_by_role, roles (set), name and tag. Static: no map is built.
function SR.get_area(zone_id, id)
	return unit_by_tag[tostring(zone_id) .. "/" .. tostring(id)]
end

function SR.area_by_tag(tag)
	return unit_by_tag[tag]
end

-- Set of the roles a kind or camp spawns (role -> true), day and night.
function SR.area_roles(zone_id, id)
	local unit = SR.get_area(zone_id, id)
	if not unit then
		return nil
	end
	local out = {}
	for role in pairs(unit.roles) do out[role] = true end
	return out
end

-- The ids of the zone's kinds and camps, in recipe order.
function SR.zone_area_ids(zone_id)
	local rec = zones[zone_id]
	local out = {}
	if rec and rec.recipe then
		for _, kind in ipairs(rec.recipe.kinds) do out[#out + 1] = kind.id end
		for _, camp in ipairs(rec.recipe.camps) do out[#out + 1] = camp.id end
	end
	return out
end

-- {zone, level, respawn} of a named leader, or nil. Static (no map build).
function SR.leader(role)
	local entry = leader_by_role[role]
	if not entry then
		return nil
	end
	return {zone = entry.zone, level = entry.leader.level,
		respawn = entry.leader.respawn}
end

-- The leader's spot {x, y, z} (builds the zone's map); nil without one.
function SR.leader_pos(role)
	local entry = leader_by_role[role]
	local map = entry and SR.map(entry.zone)
	if not map then
		return nil
	end
	for _, spot in ipairs(map.leaders) do
		if spot.role == role then
			return {x = spot.x, y = grug_zones.terrain_height_at(spot.x, spot.z), z = spot.z}
		end
	end
	return nil
end

-- {zone, id, name} of a quest place of the zone's recipe (Round 36, a
-- "use at a place" objective), or nil. Static (no map build).
function SR.zone_place(zone_id, id)
	local rec = zones[zone_id]
	local place = rec and rec.recipe and rec.recipe.place_by_id[id]
	return place and {zone = zone_id, id = id, name = place.name} or nil
end

-- The quest place's spot {x, z, name} on this world (the zone's map), or nil.
function SR.place_spot(zone_id, id)
	local map = SR.map(zone_id)
	for _, spot in ipairs(map and map.places or {}) do
		if spot.id == id then
			return {x = spot.x, z = spot.z, name = spot.name}
		end
	end
	return nil
end

function SR.leader_roles()
	local out = {}
	for role in pairs(leader_by_role) do out[#out + 1] = role end
	table.sort(out)
	return out
end

function SR.zone_critter(zone_id, mob_name)
	local rec = zones[zone_id]
	if not rec or not rec.recipe or mob_name:sub(1, #MOD_PREFIX) ~= MOD_PREFIX then
		return false
	end
	return rec.recipe.critters[mob_name:sub(#MOD_PREFIX + 1)] == true
end

function SR.zone_ids()
	local ids = {}
	for zone_id in pairs(zones) do ids[#ids + 1] = zone_id end
	table.sort(ids)
	return ids
end

-- The three fallback tables spawn_policy.lua consumes, keyed by zone id:
-- named-zone palettes, the boar tint and the lookalike choices. Live tables
-- (read-only for the caller): a later install_zone shows through.
function SR.fallback_palettes()
	return palette_by_zone, boar_by_zone, lookalikes_by_zone
end

--
-- Directions for quest texts (Lane S1, the user's brief of 2026-10-02)
--
-- describe(zone_id, target, mode, ref) -> result or nil, reason
--   target  a leader role, a quest place id, a camp id or a kind id of the
--           zone's recipe;
--   mode    "of"   relative to a named place: ref = a settlement key or
--                  anchor id ("highcourt", "anchor_008") or {x, z, name};
--           "from" relative to the speaker: ref = {x, z} (the giver);
--           "zone" within the zone: no ref.
-- The result: {dir, distance, phrase_key, phrase, x, z} (core.describe).
--

local places
local function place(ref)
	if type(ref) == "table" then
		return ref
	end
	if not places then
		places = {}
		for _, row in ipairs(roster()) do
			places[row.key] = row
			places[row.anchor_id] = row
		end
	end
	local row = places[ref]
	if not row then
		return nil
	end
	local a = grug_zones.anchor(row.zone_id, row.slot)
	return a and {x = a.x, z = a.z, name = row.label} or nil
end
-- {x, z, name} of a named place (a settlement key or anchor id), or nil:
-- the "of" reference, also for checking quest placeholders at load.
SR.place = place

-- A clash site (a Round 20 anchor of kind "clash", world_zones.md §16) by
-- its settlement key ("r20_anchor_076"): {key, zone, name}, or nil. A quest
-- place of the zones that have one (Round 36); SR.place gives its position.
local clash_rows
function SR.clash_site(key)
	if not clash_rows then
		clash_rows = {}
		for _, row in ipairs(roster()) do
			if row.art and row.art.kind == "clash" then clash_rows[row.key] = row end
		end
	end
	local row = clash_rows[key]
	return row and {key = row.key, zone = row.zone_id, name = row.label} or nil
end

function SR.describe(zone_id, target, mode, ref)
	local map = SR.map(zone_id)
	if not map then
		return nil, "no region map"
	end
	local where
	if mode == "of" then
		where = place(ref)
		if not where then
			return nil, "unknown place " .. tostring(ref)
		end
	elseif mode == "from" then
		where = ref
	end
	local record = grug_zones.get(zone_id)
	return CORE.describe(map, target, mode, where, record and record.display_name)
end

-- The bare compass word from `from_pos` toward a kind, camp or leader.
function SR.direction(zone_id, target, from_pos)
	local result = SR.describe(zone_id, target, "from", from_pos)
	return result and result.dir or nil
end

--
-- Spawning (ambient picks here; camp slots in camps.lua; leaders below)
--

-- The players the spawner works around. A seam so the engine probe can
-- stand in stationary points for players.
function SR.players()
	return core.get_connected_players()
end

local ground_nodes -- natural surface tops, set on mods loaded

-- Natural ground a mob may be set on: the named-zone biome surfaces and
-- their fertile and exposed variants (wp40 r6_content surface rows), never
-- leaves, wood, roads' built courses or water.
local GROUND = {
	"default:dirt_with_grass", "default:dirt", "default:dirt_with_coniferous_litter",
	"default:dry_dirt_with_dry_grass", "default:dry_dirt",
	"default:dirt_with_rainforest_litter", "default:gravel", "default:sand",
	"default:snowblock", "default:snow", "default:dirt_with_snow", "default:stone",
	"grug_nodes:dirt_with_silver_litter", "grug_nodes:dirt_with_moss",
	"grug_nodes:dirt_with_forest_litter", "grug_nodes:dirt_with_canopy_litter",
	"grug_nodes:dirt_with_bone_litter", "grug_nodes:blight_dirt",
	"grug_nodes:ash_ground", "grug_nodes:mesa_clay", "grug_nodes:mud",
}

local function ground_list()
	if not ground_nodes then
		ground_nodes = {}
		for _, name in ipairs(GROUND) do
			if core.registered_nodes[name] then
				ground_nodes[#ground_nodes + 1] = name
			end
		end
	end
	return ground_nodes
end

-- The highest natural ground node with air above in column x, z within
-- y_center +- reach: {x, y, z, node} or nil (unloaded, water, nothing
-- natural).
function SR.ground_at(x, z, y_center, reach)
	local found = core.find_nodes_in_area_under_air(
		{x = x, y = y_center - reach, z = z},
		{x = x, y = y_center + reach, z = z}, ground_list())
	local best
	for i = 1, #found do
		if not best or found[i].y > best.y then
			best = found[i]
		end
	end
	if not best then
		return nil
	end
	return {x = best.x, y = best.y, z = best.z, node = core.get_node(best).name}
end

-- The Shore Crab's host (shore_crab.lua, D36): dry sand with water at or
-- below the sea surface within NEAR_WATER nodes. Crab-family roles keep it.
local NEAR_WATER = 6
local SEA_SURFACE = 1
local SHORE_FAMILIES = {crab = true}

local function near_sea_water(x, y, z)
	local top = math.min(y + NEAR_WATER, SEA_SURFACE)
	if top < y - NEAR_WATER then
		return false
	end
	return #core.find_nodes_in_area(
		{x = x - NEAR_WATER, y = y - NEAR_WATER, z = z - NEAR_WATER},
		{x = x + NEAR_WATER, y = top, z = z + NEAR_WATER},
		"group:water") > 0
end

function SR.shore_ok(role, g)
	local family = grug_mobs.family_of and grug_mobs.family_of(role) or role
	if not SHORE_FAMILIES[family] then
		return true
	end
	return g.node == "default:sand" and near_sea_water(g.x, g.y, g.z)
end

local function clock_now()
	local value = core.get_timeofday() or 0.5
	local day_start = grug_core.DAY_PHASE_START or 0.1875
	local day_end = grug_core.DAY_PHASE_END or 0.8125
	return (value >= day_start and value <= day_end) and "day" or "night"
end
SR.clock_now = clock_now

local function critter(name)
	local def = core.registered_entities[name]
	return def ~= nil and def._grug_disposition == "critter"
end

-- No player closer than `range` to `pos`.
function SR.players_clear(pos, range, players)
	local r2 = range * range
	for i = 1, #players do
		local pp = players[i]:get_pos()
		if pp then
			local dx, dy, dz = pp.x - pos.x, pp.y - pos.y, pp.z - pos.z
			if dx * dx + dy * dy + dz * dz < r2 then
				return false
			end
		end
	end
	return true
end

-- One role of a roster ({list, total}), weighted.
function SR.pick_role(roster, roll)
	local target = (roll or math.random()) * roster.total
	local list = roster.list
	for i = 1, #list do
		target = target - list[i].weight
		if target < 0 then
			return list[i].role, list[i].weight
		end
	end
	return list[#list].role, list[#list].weight
end

-- The blight identity (biomes_mobs.md §3.1, zombie.lua's blight row): on
-- blight dirt a zombie does not burn in daylight. mobs_redo reads
-- `self.light_damage` per entity on every environment tick, and a plain
-- number field persists in staticdata, so clearing it on the one mob keeps
-- every other zombie's daylight burn. The legacy blight ABM uses the same
-- helper.
SR.BLIGHT_GROUND = "grug_nodes:blight_dirt"
function grug_mobs.blight_sunproof(ent)
	ent.light_damage = 0
end

-- A zombie-family role, or any leader, set on blight dirt is sunproof (a
-- leader's fixed spot on blight survives the day, as the catalogue asks of
-- Mortuary-Clerk Hush). Returns true when it applied.
function SR.sunproof_on_blight(ent, role, node, leader)
	if node ~= SR.BLIGHT_GROUND then
		return false
	end
	local family = grug_mobs.family_of and grug_mobs.family_of(role) or role
	if not leader and family ~= "zombie" then
		return false
	end
	grug_mobs.blight_sunproof(ent)
	return true
end

-- Puts one mob of `unit` (a kind or a camp) on ground point `g`: the role's
-- entity, the unit's tag, the spawn clock and a level in the role's range.
-- Returns the entity or nil.
function SR.spawn_mob(unit, role, g, clock)
	local name = MOD_PREFIX .. role
	local def = core.registered_entities[name]
	if not def then
		return nil
	end
	-- By day a mob that burns in daylight spawns only where it is sunproof
	-- (a zombie on blight dirt; the catalogue: a day source needs that host).
	if clock == "day" and (def.light_damage or 0) > 0 and not (g.node == SR.BLIGHT_GROUND and
			(grug_mobs.family_of and grug_mobs.family_of(role) or role) == "zombie") then
		return nil
	end
	local spot = mobs:can_spawn({x = g.x, y = g.y + 1, z = g.z}, name)
	if not spot then
		return nil
	end
	local ent = grug_mobs.add_mob(spot, {name = name, ignore_count = true})
	if not ent then
		return nil
	end
	-- Plain fields, persisted with the mob.
	ent._grug_area = unit.tag
	ent._grug_spawn_clock = clock
	SR.sunproof_on_blight(ent, role, g.node, false)
	local range = unit.levels_by_role[role]
	grug_mobs.relevel(ent, math.random(range[1], range[2]))
	return ent
end

-- The gates every region spawn passes at its standing position: ruling 3's
-- protected surface (non-critters), an active housing claim (hostiles).
function SR.spawn_refused(name, stand)
	if not critter(name) and grug_mobs.protected_spawn_surface(stand) then
		return "protected"
	end
	if grug_mobs.claim_refuses_spawn(name, stand) then
		return "claim"
	end
	return nil
end

-- The drift band (ruling 2, the region design): an aggressive role never
-- spawns within DRIFT nodes of a road, bridge, village, start town or capital
-- city. The point check samples the spot and two rings of eight around it
-- with the same probe the idle push uses (roam_avoid.lua).
SR.DRIFT = CORE.DRIFT
local DRIFT_RINGS = {SR.DRIFT / 2, SR.DRIFT}
local probe = {x = 0, y = 0, z = 0}
function SR.in_drift(pos)
	if grug_mobs.roam_avoid_hit(pos) then
		return true
	end
	local dirs = grug_mobs.ROAM_AVOID_DIRS
	probe.y = pos.y
	for r = 1, #DRIFT_RINGS do
		local radius = DRIFT_RINGS[r]
		for i = 1, #dirs do
			probe.x = pos.x + dirs[i][1] * radius
			probe.z = pos.z + dirs[i][2] * radius
			if grug_mobs.roam_avoid_hit(probe) then
				return true
			end
		end
	end
	return false
end

-- Today's light behaviour of the ABM rows:
--   * surface only: the spot's NATURAL light at noon is 10 or more, so no
--     cave floor and no roofed room is picked, even under a lamp;
--   * a day pick needs light >= 10 now, like a day row's min_light;
--   * at night a hostile pick needs light <= 5, like a night row's
--     max_light, so torch-lit ground stays safe.
function SR.light_allows(name, stand, clock)
	local noon = core.get_natural_light(stand, 0.5)
	if not noon or noon < 10 then
		return false
	end
	if clock == "day" then
		local light = core.get_node_light(stand)
		return light ~= nil and light >= 10
	end
	if grug_mobs.spawn_role_hostile(name) then
		local light = core.get_node_light(stand)
		return light ~= nil and light <= 5
	end
	return true
end

SR.stats = {}
local function count(reason)
	SR.stats[reason] = (SR.stats[reason] or 0) + 1
	return reason
end

local nospawn_range

-- One ambient attempt around a player position: a random column in the ring
-- nospawn_range .. ATTEMPT_RANGE, only in a zone with a recipe (the ABM rows
-- serve every other zone). Returns the outcome (a reason or "spawned").
SR.ATTEMPT_RANGE = 64
SR.GROUND_REACH = 48
function SR.attempt(player_pos, players, clock, roll_angle, roll_dist)
	if not nospawn_range then
		nospawn_range = tonumber(core.settings:get("mob_nospawn_range")) or 24
	end
	local angle = (roll_angle or math.random()) * 2 * math.pi
	local lo, hi = nospawn_range, SR.ATTEMPT_RANGE
	local dist = math.sqrt(lo * lo + (roll_dist or math.random()) * (hi * hi - lo * lo))
	local x = math.floor(player_pos.x + math.cos(angle) * dist + 0.5)
	local z = math.floor(player_pos.z + math.sin(angle) * dist + 0.5)
	local zone_id = grug_zones.id_at(x, z)
	if not zone_id or not SR.zone_has_recipe(zone_id) then
		return count("no_recipe_zone")
	end
	local map = SR.map(zone_id)
	if not map then
		return count("no_map")
	end
	local g = SR.ground_at(x, z, math.floor(player_pos.y + 0.5), SR.GROUND_REACH)
	if not g or g.y < 0 then
		return count("no_ground")
	end
	local region = map.region_at(g.x, g.z)
	if not region then
		return count("no_region")
	end
	if region.camp then
		return count("camp") -- camps spawn through their slots
	end
	local kind = region.kind
	local roster = kind.rosters[clock]
	local role, weight = SR.pick_role(roster)
	local name = MOD_PREFIX .. role
	if not SR.shore_ok(role, g) then
		return count("shore")
	end
	local stand = {x = g.x, y = g.y + 1, z = g.z}
	if not SR.players_clear(stand, nospawn_range, players) then
		return count("player_near")
	end
	local refused = SR.spawn_refused(name, stand)
	if refused then
		return count(refused)
	end
	if grug_mobs.disposition(name) == "aggressive" and SR.in_drift(stand) then
		return count("drift")
	end
	if not SR.light_allows(name, stand, clock) then
		return count("light")
	end
	if not grug_mobs.region_density_allows(stand, zone_id, clock, kind, name,
			weight, roster.total) then
		return count("density")
	end
	if not SR.spawn_mob(kind, role, g, clock) then
		return count("no_room")
	end
	return count("spawned")
end

-- The camps of the built maps of `zone_ids`, default every zone (camps.lua
-- ticks their slots).
function SR.camp_units(zone_ids)
	local out = {}
	for _, zone_id in ipairs(zone_ids or SR.zone_ids()) do
		local map = maps[zone_id]
		if map then
			for _, unit in ipairs(map.camps) do out[#out + 1] = unit end
		end
	end
	return out
end

--
-- Leaders (ruling 38): rule-placed spot, fixed level, ~5 min respawn after a
-- kill.
--
-- A leader is an ordinary mob of its role that is never saved with the map
-- (static_save = false): it exists while its spot is loaded and nowhere
-- else, so a runtime ObjectRef answers "is it out there" exactly and no scan
-- can mistake an unloaded leader for a dead one. Only a kill starts the
-- respawn timer (mod storage, game time, survives restarts); a leader that
-- vanished with its unloaded block is back on the next visit.
--

local storage = grug_mobs.storage
local live_leaders = {} -- role -> ObjectRef (runtime only)
-- The horizontal player distance that wakes a spot stays inside the active
-- blocks round the player (active_block_range mapblocks, less one): an
-- unsaved object added to an inactive block is dropped at once and would be
-- added again every few seconds. 48 nodes at the default range of 4.
SR.LEADER_RANGE = math.max(32,
	((tonumber(core.settings:get("active_block_range")) or 4) - 1) * 16)
SR.LEADER_CLEAR = 24 -- never appears closer than this to a player
local LEADER_REACH = 40

local function leader_alive(role)
	local obj = live_leaders[role]
	if not obj then
		return false
	end
	local ent = obj:get_luaentity()
	if ent and (ent.health or 0) > 0 then
		return true
	end
	live_leaders[role] = nil
	return false
end

-- The highest standable node in a column: any walkable node with two air
-- nodes above (a leader may stand on a camp's built floor).
local function column_ground(x, z, y0)
	for y = y0 + LEADER_REACH, y0 - LEADER_REACH, -1 do
		local here = core.get_node_or_nil({x = x, y = y, z = z})
		if here and here.name ~= "air" and here.name ~= "ignore" and
				core.get_item_group(here.name, "leaves") == 0 and
				core.get_item_group(here.name, "tree") == 0 then
			local def = core.registered_nodes[here.name]
			if def and def.walkable then
				local a1 = core.get_node_or_nil({x = x, y = y + 1, z = z})
				local a2 = core.get_node_or_nil({x = x, y = y + 2, z = z})
				if a1 and a2 and a1.name == "air" and a2.name == "air" then
					return {x = x, y = y + 1, z = z}
				end
				return nil
			end
		end
	end
	return nil
end

-- The spot's own column, else the nearest standable one within a few nodes
-- (a rule-placed spot may land on a tree trunk or a boulder).
local SPOT_RINGS = {{0, 0}, {2, 0}, {-2, 0}, {0, 2}, {0, -2}, {2, 2}, {-2, 2}, {2, -2},
	{-2, -2}, {4, 0}, {-4, 0}, {0, 4}, {0, -4}}
-- Offsets on a 4-node grid within PREFER_REACH of a spot, nearest first.
local PREFER_REACH = 16
local prefer_offsets
local function near_offsets()
	if not prefer_offsets then
		prefer_offsets = {}
		for dx = -PREFER_REACH, PREFER_REACH, 4 do
			for dz = -PREFER_REACH, PREFER_REACH, 4 do
				if dx * dx + dz * dz <= PREFER_REACH * PREFER_REACH then
					prefer_offsets[#prefer_offsets + 1] = {dx, dz, dx * dx + dz * dz}
				end
			end
		end
		table.sort(prefer_offsets, function(a, b)
			if a[3] ~= b[3] then return a[3] < b[3] end
			if a[1] ~= b[1] then return a[1] < b[1] end
			return a[2] < b[2]
		end)
	end
	return prefer_offsets
end

-- `prefer`: a ground node the leader should stand on when one is within
-- PREFER_REACH of its spot (a zombie leader on blight dirt survives the day;
-- the spot is a cell centre and a cell is typed by its majority biome, so
-- its own column may be another biome's).
local function leader_ground(spot, prefer)
	spot.terrain_y = spot.terrain_y or grug_zones.terrain_height_at(spot.x, spot.z)
	if prefer then
		for _, o in ipairs(near_offsets()) do
			local pos = column_ground(spot.x + o[1], spot.z + o[2], spot.terrain_y)
			local below = pos and core.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
			if below and below.name == prefer then
				return pos
			end
		end
	end
	for i = 1, #SPOT_RINGS do
		local pos = column_ground(spot.x + SPOT_RINGS[i][1], spot.z + SPOT_RINGS[i][2],
			spot.terrain_y)
		if pos then
			return pos
		end
	end
	return nil
end

local function player_near_xz(x, z, range, players)
	for i = 1, #players do
		local pp = players[i]:get_pos()
		if pp then
			local dx, dz = pp.x - x, pp.z - z
			if dx * dx + dz * dz <= range * range then
				return true
			end
		end
	end
	return false
end
SR.player_near_xz = player_near_xz

-- The leaders of `zone_ids` (default: every zone).
function SR.leader_tick(now, players, zone_ids)
	for _, zone_id in ipairs(zone_ids or SR.zone_ids()) do
		local map = maps[zone_id]
		for _, spot in ipairs(map and map.leaders or {}) do
			local role = spot.role
			local name = MOD_PREFIX .. role
			if not leader_alive(role) and
					now >= storage:get_int("leader_next:" .. role) and
					player_near_xz(spot.x, spot.z, SR.LEADER_RANGE, players) then
				local family = grug_mobs.family_of and grug_mobs.family_of(role) or role
				local pos = leader_ground(spot, family == "zombie" and SR.BLIGHT_GROUND or nil)
				if pos and SR.players_clear(pos, SR.LEADER_CLEAR, players) and
						not grug_mobs.claim_refuses_spawn(name, pos) then
					-- Authored (Round 37 MP): placed at mobs_redo's active-mob
					-- limit too and not counted against it.
					local ent = grug_mobs.add_mob(pos, {name = name, ignore_count = true,
						_grug_authored = true})
					if ent then
						ent._grug_leader = true
						local below = core.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
						SR.sunproof_on_blight(ent, role, below and below.name, true)
						grug_mobs.relevel(ent, spot.level)
						ent.object:set_properties({static_save = false})
						live_leaders[role] = ent.object
						count("leader_spawned")
					end
				end
			end
		end
	end
end

-- The shared mobs_redo death boundary (init.lua) starts a leader's timer.
local settle_mob_death = grug_mobs.settle_mob_death
function grug_mobs.settle_mob_death(self)
	if self._grug_leader and self.name and
			self.name:sub(1, #MOD_PREFIX) == MOD_PREFIX then
		local role = self.name:sub(#MOD_PREFIX + 1)
		local entry = leader_by_role[role]
		if entry then
			storage:set_int("leader_next:" .. role,
				core.get_gametime() + entry.leader.respawn)
			live_leaders[role] = nil
		end
	end
	return settle_mob_death(self)
end

--
-- The one throttled globalstep: one ambient attempt per player per second;
-- camp slots and leaders of every zone every five seconds.
--

SR.ATTEMPT_PERIOD = 1
SR.SLOW_PERIOD = 5
-- The second is cut into SLICES steps; each step serves the players whose
-- index falls in its slice, so many players' attempts spread over the second.
local SLICES = 4
-- The five seconds are cut the same way into SLOW_SLICES steps of the zones
-- (Round 32, perf review R3): each serves the camps and leaders of the zones
-- whose index falls in its slice, so no step weighs every camp and leader
-- against every player, and each zone is still served once per SLOW_PERIOD.
SR.SLOW_SLICES = SR.SLOW_PERIOD * SLICES / SR.ATTEMPT_PERIOD
local SLOW_STEP = SR.SLOW_PERIOD / SR.SLOW_SLICES
local attempt_acc, slow_acc, slice, slow_slice = 0, 0, 0, 0
local spawning = core.settings:get_bool("mobs_spawn") ~= false

local function any_recipe()
	for _, rec in pairs(zones) do
		if rec.recipe then
			return true
		end
	end
	return false
end

core.register_globalstep(function(dtime)
	attempt_acc = attempt_acc + dtime
	slow_acc = slow_acc + dtime
	if attempt_acc < SR.ATTEMPT_PERIOD / SLICES then
		return
	end
	attempt_acc = 0
	if not spawning or not any_recipe() then
		slow_acc = 0
		return
	end
	local players = SR.players()
	local clock = clock_now()
	slice = (slice + 1) % SLICES
	for i = 1, #players do
		if i % SLICES == slice then
			local pos = players[i]:get_pos()
			if pos and pos.y > -40 then
				SR.attempt(pos, players, clock)
			end
		end
	end
	-- A pass comes a whole server step after its quarter second or later:
	-- a pass a slow step behind serves two, so the period stays
	-- SLOW_PERIOD; a longer stall is not caught up.
	local due = slow_acc >= 2 * SLOW_STEP and 2 or slow_acc >= SLOW_STEP and 1 or 0
	slow_acc = math.min(slow_acc - due * SLOW_STEP, SLOW_STEP)
	local zone_ids = due > 0 and SR.zone_ids()
	for _ = 1, due do
		slow_slice = (slow_slice + 1) % SR.SLOW_SLICES
		local mine = {}
		for i = 1, #zone_ids do
			if i % SR.SLOW_SLICES == slow_slice then mine[#mine + 1] = zone_ids[i] end
		end
		local now = core.get_gametime()
		grug_mobs.region_camp_tick(now, players, clock, mine)
		SR.leader_tick(now, players, mine)
	end
end)

--
-- The region maps at start and the world-folder cache (Round 30 P3)
--

-- What the builder reads besides the world (whose identity is the mapgen
-- key) and a zone's recipe file (its own digest): the builder part of the
-- cache key. The input-coverage test (tools/r30_p3) checks every file a
-- build reads against this list.
SR.BUILDER_FILES = {
	{"grug_mobs", "spawn_regions_core.lua"},
	{"grug_mobs", "spawn_regions.lua"},
	{"grug_mobs", "spawn_regions_cache.lua"},
	{"grug_mobs", "data/subtypes.json"},
	{"grug_core", "zone_authority.lua"},
}

-- The cache key of this start and the world folder, or nil, nil and the
-- reason: the world-layout cache's key parts (seed, mapgen tree digest,
-- mapgen settings, interpreter: grug_mapgen.wp40.world_key) and a digest of
-- the builder's files.
local function cache_key()
	local world_dir = type(core.get_worldpath) == "function" and core.get_worldpath()
	if type(world_dir) ~= "string" or world_dir == "" then
		return nil, nil, "no world folder"
	end
	local mapgen = rawget(_G, "grug_mapgen")
	local world = type(mapgen) == "table" and type(mapgen.wp40) == "table" and
		mapgen.wp40.world_key
	if type(world) ~= "table" then
		return nil, nil, "no world key from grug_mapgen"
	end
	local rows = {}
	for _, file in ipairs(SR.BUILDER_FILES) do
		local name = file[1] .. "/" .. file[2]
		local bytes = read_file(core.get_modpath(file[1]) .. "/" .. file[2])
		if not bytes then
			return nil, nil, "cannot read " .. name
		end
		rows[#rows + 1] = {name, bytes}
	end
	return CACHE.key(world.seed, world.source, world.settings, world.interpreter,
		CACHE.files_digest(rows)), world_dir
end

-- The digest of a zone's shipped recipe file (stored with its block).
local function recipe_digest(zone_id)
	local bytes = read_file(DATA_DIR .. "/" .. zone_id .. ".spawns.json")
	return bytes and core.sha256(bytes) or nil
end

-- Every recipe zone's map: read back from the world-folder cache where the
-- file matches this start's key and the zone's block matches its recipe
-- file, built (SR.map) everywhere else. Anything built, or a file that holds
-- other zones than this start, replaces the file atomically. A cache failure
-- means a build and a warning (a damaged file) or an action line (a file of
-- another key), never a stop.
function SR.start_maps()
	local t0, heap0 = core.get_us_time(), collectgarbage("count")
	local ids = {}
	for _, zone_id in ipairs(SR.zone_ids()) do
		if zones[zone_id].recipe then ids[#ids + 1] = zone_id end
	end
	local key, world_dir, cached, reason, damaged, size
	do
		local ok, a, b, c = pcall(cache_key)
		if not ok then
			reason, damaged = "no cache key: " .. tostring(a), true
		elseif not a then
			reason = c
		else
			key, world_dir = a, b
			local read_ok, d, e, f, g = pcall(CACHE.load, world_dir, key)
			if read_ok then
				cached, reason, damaged, size = d, e, f, g
			else
				reason, damaged = "unreadable: " .. tostring(d), true
			end
		end
	end
	local hits, built, failed, unfit, build_us = 0, 0, 0, 0, 0
	local digests = {}
	for _, zone_id in ipairs(ids) do
		if key and from_file[zone_id] then digests[zone_id] = recipe_digest(zone_id) end
		local entry = cached and cached[zone_id]
		if maps[zone_id] == nil and entry and entry.digest == digests[zone_id] then
			local ok, map, why = pcall(CACHE.rehydrate, zone_id, entry.payload,
				zones[zone_id].recipe)
			if ok and map then
				maps[zone_id] = map
				payloads[zone_id] = entry.payload
				hits = hits + 1
				SR.build_stats[zone_id] = {ms = 0, cells = map.cell_count,
					regions = #map.regions, cached = true}
				-- The log reads as after a build: the build's own findings.
				for _, problem in ipairs(map.problems) do
					core.log("warning", "[grug_mobs] spawn regions " .. zone_id .. ": " .. problem)
				end
				for _, warning in ipairs(map.warnings) do
					core.log("warning", "[grug_mobs] spawn regions " .. zone_id .. ": " .. warning)
				end
			else
				unfit = unfit + 1
				core.log("warning", "[grug_mobs] spawn regions " .. zone_id .. ": the cached " ..
					"map does not fit the recipe, building afresh: " .. tostring(ok and why or map))
			end
		end
		if maps[zone_id] == nil then
			local b0 = core.get_us_time()
			if build_map(zone_id, zones[zone_id]) then built = built + 1 else failed = failed + 1 end
			build_us = build_us + core.get_us_time() - b0
		end
	end
	-- The file holds every ready zone of a shipped recipe file, in id order.
	local entries = {}
	for _, zone_id in ipairs(ids) do
		if maps[zone_id] and payloads[zone_id] and digests[zone_id] then
			entries[#entries + 1] = {zone = zone_id, digest = digests[zone_id],
				payload = payloads[zone_id]}
		end
	end
	payloads = nil
	local in_file = 0
	for _ in pairs(cached or {}) do in_file = in_file + 1 end
	local stored, store_error
	if key and not (hits == #entries and in_file == hits) then
		local ok, result, count = pcall(CACHE.store, world_dir, key, entries)
		if ok and result then
			stored, size = true, count
		else
			store_error = ok and CACHE.path(world_dir) or tostring(result)
		end
	end
	local state
	if not key then
		state = "not cached (" .. tostring(reason) .. ")"
	elseif not cached then
		state = "cache miss (" .. tostring(reason) .. ")"
	elseif hits == #ids then
		state = "cache hit"
	else
		state = "cache partly current"
	end
	core.log((damaged or unfit > 0) and "warning" or "action", ("[grug_mobs] spawn regions: " ..
		"%d region maps ready at start in %.1f ms (%d from %s, %d built in %.1f s, %d failed); " ..
		"%s%s; Lua heap %.0f -> %.0f MiB"):format(#ids - failed,
		(core.get_us_time() - t0) / 1000, hits, CACHE.FILE, built, build_us / 1000000, failed,
		state, stored and (", stored " .. size .. " bytes") or
			((size or 0) > 0 and (", file " .. size .. " bytes") or ""),
		heap0 / 1024, collectgarbage("count") / 1024))
	if store_error then
		core.log("warning", "[grug_mobs] spawn regions: the region map cache could not be " ..
			"written: " .. store_error)
	end
	-- A build pass leaves about 1 GiB of garbage: collected now, not on top
	-- of what the boot allocates next (peak memory, Round 30 P3).
	if built > 0 then collectgarbage("collect") end
end

-- Roles exist once every mob file has registered (sub-types included).
core.register_on_mods_loaded(function()
	ground_list()
	local function need(name, where)
		if not core.registered_entities[name] then
			fail(where, name .. " is not a registered mob")
		end
	end
	for _, zone_id in ipairs(SR.zone_ids()) do
		local recipe = zones[zone_id].recipe
		if recipe then
			for role in pairs(recipe.critters) do
				local name = MOD_PREFIX .. role
				need(name, zone_id .. " critters")
				if not critter(name) then
					fail(zone_id .. " critters", role .. " is not a critter")
				end
			end
			for _, kind in ipairs(recipe.kinds) do
				for role in pairs(kind.roles) do need(MOD_PREFIX .. role, kind.tag) end
			end
			for _, camp in ipairs(recipe.camps) do
				for role in pairs(camp.roles) do need(MOD_PREFIX .. role, camp.tag) end
			end
			for _, leader in ipairs(recipe.leaders) do
				need(MOD_PREFIX .. leader.role, zone_id .. " leader")
			end
		end
	end
	-- Every recipe zone's region map is ready here, once, before players
	-- can join (the user, 2026-10-02): a build blocks the server for about
	-- 0.3 s, so neither a player entering a zone nor a quest text's direction
	-- ever builds one at runtime.
	SR.start_maps()
end)
