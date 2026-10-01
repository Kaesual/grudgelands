--
-- Round 28 rulings 34, 37 and 38: spawn areas, the per-zone spawn data.
--
-- Every named zone has ONE data file, data/zones/<zone_id>.spawns.json
-- (design frame §4.6). It carries
--   * `palette`  today's named-zone mob palette (world_zones.md §8 families,
--                the zone's boar tint and lookalike choices) as data; it is
--                the zone's whole surface rule while `areas` is empty;
--   * `critters` the ambient critters that keep their own ABM rows once the
--                zone has areas (rabbits, turkeys, gulls ...);
--   * `areas`    spawn areas; the TRIGGER (ruling 34): a zone whose list is
--                empty keeps today's palette and level field exactly, a zone
--                with areas spawns its surface mobs only from them;
--   * `leaders`  named leaders at fixed spots (ruling 38).
-- A missing file means no palette and no areas.
--
-- An area is relative to an anchor (an atlas anchor id, a settlement key, a
-- slot such as `start`, `capital`, `village_1`, `rare_<name>`, or `zone`,
-- the zone hub) plus an `offset` [x, z] in world axes. Shapes: `circle`
-- (r), `ring` (r = [min, max]), `zone` (all of it) and `band`: `forward`
-- [from, to] along the zone's front axis (positive toward the Battlegrounds:
-- +z on Elandor, -z on Kragmar) and `side` [from, to] along +x, both
-- measured from anchor + offset. Areas are clipped to their zone: a point
-- only ever meets the areas of the zone that owns it.
--
-- At a point, time and host an area MATCHES when the point lies in its shape,
-- its clock is `both` or the current one, and its hosts admit the point:
-- `hosts.biomes` (atlas biome ids, `grug_` optional, or `any`) against the
-- column's logical biome, and `hosts.shore = true` against the Shore Crab's
-- host (dry `default:sand` within 6 nodes of sea water, shore_crab.lua).
-- Overlapping areas add their species weights; the one `fallback` area
-- matches only where no other area of the zone matches point, clock and host.
-- Camp areas (`camp`) cover their ground for that rule but spawn through
-- their own slots (camps.lua), never as ambient picks.
--
-- Every mob an area spawns carries `_grug_area = "<zone_id>/<area_id>"` (a
-- plain field, persisted with the mob) and its fixed level, rolled in the
-- area's range (`_grug_spawn_level`, levels.lua). Leaders carry
-- `_grug_leader = true` and no area.
--
-- Unchanged by areas: underground spawns, water spawns and swimmers, rares,
-- vendors, guards and guard posts, mapgen content.
--

local SA = {}
grug_mobs.spawn_areas = SA

local MOD_PREFIX = "grug_mobs:"
local DATA_DIR = core.get_modpath(core.get_current_modname()) .. "/data/zones"

local CLOCKS = {day = true, night = true, both = true}
local SHAPES = {circle = true, ring = true, band = true, zone = true}
local AREA_KEYS = {id = true, anchor = true, offset = true, shape = true,
	hosts = true, clock = true, levels = true, species = true, cap = true,
	camp = true, fallback = true, notes = true}
local LEADER_KEYS = {role = true, anchor = true, offset = true, level = true,
	respawn = true, notes = true}
local FILE_KEYS = {zone = true, palette = true, critters = true, areas = true,
	leaders = true, notes = true}
local PALETTE_KEYS = {families = true, exact_mobs = true, night_fallback = true,
	boar = true, lookalikes = true}
local LEVEL_CAP = 60

-- The Shore Crab's host (shore_crab.lua): dry sand with water at or below
-- the sea surface within NEAR_WATER nodes.
local NEAR_WATER = 6
local SEA_SURFACE = 1

-- Front axis per continent (design frame §4.6): the zone record's macro
-- region. Battlegrounds and islands have no front axis, so no band.
local FRONT_SIGN = {elandor_mainland = 1, kragmar_mainland = -1}

local zones = {} -- zone_id -> record (see install_zone)
local area_by_tag = {} -- "zone/area" -> area
local camp_areas = {} -- camp areas in install order
local leaders = {} -- role -> leader
local leader_order = {}

local function fail(where, message)
	error("[grug_mobs] spawn areas " .. where .. ": " .. message, 0)
end

local function is_int(value, lo, hi)
	return type(value) == "number" and value % 1 == 0 and
		(lo == nil or value >= lo) and (hi == nil or value <= hi)
end

local function is_num(value)
	return type(value) == "number" and value == value and
		value ~= math.huge and value ~= -math.huge
end

local function pair(value, ordered)
	return type(value) == "table" and #value == 2 and is_num(value[1]) and
		is_num(value[2]) and (not ordered or value[1] <= value[2])
end

local function known_keys(row, allowed, where)
	for key in pairs(row) do
		if not allowed[key] then
			fail(where, "unknown field " .. tostring(key))
		end
	end
end

-- Atlas biome ids carry the grug_ prefix; designers may omit it.
local function biome_key(name)
	if type(name) == "string" and name:sub(1, 5) == "grug_" then
		return name:sub(6)
	end
	return name
end
SA.biome_key = biome_key

--
-- Anchor references
--

-- Atlas anchor ids (`anchor_015`) name a mapgen anchor row; the zone session
-- resolves anchors by zone and slot, so the id -> slot table is read once
-- from the mapgen's own fixed source (data only, no engine calls).
local anchor_slots

local function anchor_slot(anchor_id)
	if not anchor_slots then
		anchor_slots = {}
		local source = dofile(core.get_modpath("grug_mapgen") ..
			"/wp40/source/simple_map.lua")
		for i = 1, #source.anchors do
			local row = source.anchors[i]
			local zone = source.zones[row.zone_numeric_id]
			anchor_slots[row.id] = {zone = zone and zone.id, slot = row.slot_id}
		end
	end
	return anchor_slots[anchor_id]
end

-- World x, z (and y where an anchor has one) of an anchor reference in a
-- zone; nil when the reference does not name anything in that zone.
function SA.resolve_anchor(zone_id, ref)
	if type(ref) ~= "string" or ref == "" then
		return nil
	end
	if ref == "zone" then
		local record = grug_zones.get(zone_id)
		if record and record.hub then
			return record.hub.x, record.hub.z, nil
		end
		return nil
	end
	local anchor = grug_zones.anchor(zone_id, ref)
	if not anchor and ref:match("^anchor_%d+$") then
		local row = anchor_slot(ref)
		if row and row.zone == zone_id then
			anchor = grug_zones.anchor(zone_id, row.slot)
		end
	end
	if anchor then
		return anchor.x, anchor.z, anchor.y
	end
	local settlement = grug_core.settlement_socket_anchor(ref)
	if settlement and grug_zones.id_at(settlement.x, settlement.z) == zone_id then
		return settlement.x, settlement.z, settlement.y
	end
	return nil
end

--
-- Parsing
--

local function parse_shape(shape, where, sign)
	if type(shape) ~= "table" or not SHAPES[shape.kind] then
		fail(where, "shape needs kind circle, ring, band or zone")
	end
	local out = {kind = shape.kind}
	if shape.kind == "circle" then
		if not is_num(shape.r) or shape.r <= 0 then
			fail(where, "circle needs r > 0")
		end
		out.r2 = shape.r * shape.r
		out.extent = shape.r
	elseif shape.kind == "ring" then
		local r = shape.r
		if not pair(r, true) or r[1] < 0 or r[1] >= r[2] then
			fail(where, "ring needs r = [min, max] with 0 <= min < max")
		end
		out.rmin, out.rmax = r[1], r[2]
		out.rmin2, out.rmax2 = r[1] * r[1], r[2] * r[2]
		out.extent = r[2]
	elseif shape.kind == "band" then
		if not sign then
			fail(where, "band needs a front axis (not in front zones or islands)")
		end
		if not pair(shape.forward, true) or not pair(shape.side, true) or
				shape.forward[1] == shape.forward[2] or
				shape.side[1] == shape.side[2] then
			fail(where, "band needs forward and side [from, to] with from < to")
		end
		out.sign = sign
		out.f0, out.f1 = shape.forward[1], shape.forward[2]
		out.s0, out.s1 = shape.side[1], shape.side[2]
		local f = math.max(math.abs(out.f0), math.abs(out.f1))
		local s = math.max(math.abs(out.s0), math.abs(out.s1))
		out.extent = math.sqrt(f * f + s * s)
	end
	return out
end

local function parse_offset(offset, where)
	if offset == nil then
		return 0, 0
	end
	if not pair(offset) or not is_int(offset[1]) or not is_int(offset[2]) then
		fail(where, "offset must be [x, z] integers (world axes)")
	end
	return offset[1], offset[2]
end

local function parse_area(zone_id, row, where, sign)
	if type(row) ~= "table" then
		fail(where, "area must be an object")
	end
	known_keys(row, AREA_KEYS, where)
	if type(row.id) ~= "string" or not row.id:match("^[a-z][a-z0-9_]*$") then
		fail(where, "area id must be snake_case")
	end
	where = zone_id .. "/" .. row.id
	local ax, az, ay = SA.resolve_anchor(zone_id, row.anchor)
	if not ax then
		fail(where, "anchor " .. tostring(row.anchor) .. " is not an anchor of the zone")
	end
	local ox, oz = parse_offset(row.offset, where)
	local area = {
		cy = (ox == 0 and oz == 0) and ay or nil,
		id = row.id,
		zone = zone_id,
		tag = where,
		anchor = row.anchor,
		offset = {ox, oz},
		cx = ax + ox,
		cz = az + oz,
		shape = parse_shape(row.shape, where, sign),
		clock = row.clock,
		fallback = row.fallback == true,
		notes = row.notes,
	}
	if row.fallback ~= nil and type(row.fallback) ~= "boolean" then
		fail(where, "fallback must be true or false")
	end
	if not CLOCKS[row.clock] then
		fail(where, "clock must be day, night or both")
	end
	local hosts = row.hosts
	if type(hosts) ~= "table" or type(hosts.biomes) ~= "table" or
			#hosts.biomes == 0 then
		fail(where, "hosts needs a non-empty biomes list ('any' allowed)")
	end
	if hosts.shore ~= nil and type(hosts.shore) ~= "boolean" then
		fail(where, "hosts.shore must be true or false")
	end
	local biomes = {}
	local any = false
	for i = 1, #hosts.biomes do
		local biome = hosts.biomes[i]
		if type(biome) ~= "string" or biome == "" then
			fail(where, "biome ids must be strings")
		end
		if biome == "any" then
			any = true
		else
			biomes[biome_key(biome)] = true
		end
	end
	area.hosts = {biomes = hosts.biomes, shore = hosts.shore == true}
	area.biome_set = not any and biomes or nil
	area.shore = hosts.shore == true
	local levels = row.levels
	if not pair(levels, true) or not is_int(levels[1], 1, LEVEL_CAP) or
			not is_int(levels[2], 1, LEVEL_CAP) then
		fail(where, "levels must be [lo, hi] integers within 1..60")
	end
	area.levels = {levels[1], levels[2]}
	if type(row.species) ~= "table" or #row.species == 0 then
		fail(where, "species must be a non-empty list")
	end
	area.species = {}
	area.roles = {}
	area.weight = 0
	for i = 1, #row.species do
		local sp = row.species[i]
		if type(sp) ~= "table" or type(sp.role) ~= "string" or sp.role == "" or
				not is_num(sp.weight) or sp.weight <= 0 then
			fail(where, "species entries need a role and a positive weight")
		end
		if area.roles[sp.role] then
			fail(where, "species " .. sp.role .. " is listed twice")
		end
		area.species[i] = {role = sp.role, weight = sp.weight}
		area.roles[sp.role] = sp.weight
		area.weight = area.weight + sp.weight
	end
	if row.cap ~= nil then
		if not is_int(row.cap, 1) then
			fail(where, "cap must be an integer >= 1")
		end
		area.cap = row.cap
	end
	if row.camp ~= nil then
		local camp = row.camp
		if type(camp) ~= "table" or not is_int(camp.slots, 1) or
				not pair(camp.respawn, true) or not is_int(camp.respawn[1], 1) or
				not is_int(camp.respawn[2], 1) or
				not is_num(camp.min_player_distance) or
				camp.min_player_distance < 0 then
			fail(where, "camp needs slots >= 1, respawn [min, max] seconds and " ..
				"min_player_distance")
		end
		if area.fallback then
			fail(where, "the fallback area cannot be a camp")
		end
		area.camp = {slots = camp.slots, respawn = {camp.respawn[1], camp.respawn[2]},
			min_player_distance = camp.min_player_distance}
	end
	return area
end

local function parse_leader(zone_id, row, where)
	if type(row) ~= "table" then
		fail(where, "leader must be an object")
	end
	known_keys(row, LEADER_KEYS, where)
	if type(row.role) ~= "string" or row.role == "" then
		fail(where, "leader needs a role")
	end
	where = zone_id .. " leader " .. row.role
	local ax, az, ay = SA.resolve_anchor(zone_id, row.anchor)
	if not ax then
		fail(where, "anchor " .. tostring(row.anchor) .. " is not an anchor of the zone")
	end
	local ox, oz = parse_offset(row.offset, where)
	if not is_int(row.level, 1, LEVEL_CAP) then
		fail(where, "level must be an integer 1..60")
	end
	if not is_int(row.respawn, 1) then
		fail(where, "respawn must be seconds (integer >= 1)")
	end
	return {
		role = row.role,
		name = MOD_PREFIX .. row.role,
		zone = zone_id,
		anchor = row.anchor,
		x = ax + ox,
		z = az + oz,
		anchor_y = (ox == 0 and oz == 0) and ay or nil,
		level = row.level,
		respawn = row.respawn,
	}
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

-- Installs one zone's data (the decoded JSON object). The loader below calls
-- it for every file; a probe may install a sample in place of a zone's file
-- before the mods have loaded. Fails loudly on any format error.
function SA.install_zone(zone_id, data)
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
	local old = zones[zone_id]
	if old then
		for _, area in ipairs(old.areas) do
			area_by_tag[area.tag] = nil
		end
		for i = #camp_areas, 1, -1 do
			if camp_areas[i].zone == zone_id then
				table.remove(camp_areas, i)
			end
		end
		for _, leader in ipairs(old.leaders) do
			leaders[leader.role] = nil
		end
	end
	local record = grug_zones.get(zone_id)
	local sign = FRONT_SIGN[record.macro_region]
	local palette, boar, lookalikes = parse_palette(data.palette, where)
	local rec = {
		id = zone_id,
		palette = palette,
		boar = boar,
		lookalikes = lookalikes,
		critters = set_of(data.critters, where, "critters"),
		areas = {},
		ambient = {},
		fallback = nil,
		by_id = {},
		leaders = {},
	}
	if data.areas ~= nil and type(data.areas) ~= "table" then
		fail(where, "areas must be a list (empty keeps today's palette)")
	end
	local areas = data.areas or {}
	for i = 1, #areas do
		local area = parse_area(zone_id, areas[i], where .. " areas[" .. i .. "]", sign)
		if rec.by_id[area.id] then
			fail(area.tag, "duplicate area id")
		end
		rec.by_id[area.id] = area
		rec.areas[#rec.areas + 1] = area
		if area.fallback then
			if rec.fallback then
				fail(where, "a zone with areas needs exactly one fallback area")
			end
			rec.fallback = area
		elseif area.camp then
			camp_areas[#camp_areas + 1] = area
		end
		area_by_tag[area.tag] = area
	end
	if #rec.areas > 0 and not rec.fallback then
		fail(where, "a zone with areas needs exactly one fallback area")
	end
	-- Matching order: every non-fallback area, camps included (they cover
	-- their ground for the fallback rule).
	for i = 1, #rec.areas do
		if not rec.areas[i].fallback then
			rec.ambient[#rec.ambient + 1] = rec.areas[i]
		end
	end
	if data.leaders ~= nil and type(data.leaders) ~= "table" then
		fail(where, "leaders must be a list")
	end
	for i = 1, #(data.leaders or {}) do
		local leader = parse_leader(zone_id, data.leaders[i],
			where .. " leaders[" .. i .. "]")
		if leaders[leader.role] then
			fail(where, "leader role " .. leader.role .. " already has a fixed spot")
		end
		leaders[leader.role] = leader
		rec.leaders[#rec.leaders + 1] = leader
	end
	zones[zone_id] = rec
	leader_order = {}
	for role in pairs(leaders) do
		leader_order[#leader_order + 1] = role
	end
	table.sort(leader_order)
	return rec
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

-- Every data file, at load (the zone authority is installed before
-- grug_mobs loads, so anchors resolve here).
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
			SA.install_zone(zone_id, data)
		end
	end
end
load_all()

--
-- Seams (B4 and the other lanes; design frame §4.6, b-interfaces)
--

function SA.zone_has_areas(zone_id)
	local rec = zones[zone_id]
	return rec ~= nil and #rec.areas > 0
end

-- The parsed area (read-only): id, zone, tag, anchor, offset {x, z}, cx/cz
-- (anchor + offset), shape (kind plus derived numbers), hosts, clock,
-- levels {lo, hi}, species {{role, weight}}, cap, camp, fallback.
function SA.get_area(zone_id, area_id)
	local rec = zones[zone_id]
	return rec and rec.by_id[area_id] or nil
end

function SA.area_by_tag(tag)
	return area_by_tag[tag]
end

-- Set of the roles an area spawns (role -> true).
function SA.area_roles(zone_id, area_id)
	local area = SA.get_area(zone_id, area_id)
	if not area then
		return nil
	end
	local out = {}
	for role in pairs(area.roles) do
		out[role] = true
	end
	return out
end

-- {zone, pos = {x, y, z}, level, respawn} of a named leader, or nil. `y` is
-- the anchor's height where the spot is the anchor itself, else the terrain
-- height of the column; the spawner snaps the leader to the real surface.
function SA.leader(role)
	local leader = leaders[role]
	if not leader then
		return nil
	end
	local y = leader.anchor_y or grug_zones.terrain_height_at(leader.x, leader.z)
	return {zone = leader.zone, pos = {x = leader.x, y = y, z = leader.z},
		level = leader.level, respawn = leader.respawn}
end

function SA.leader_roles()
	local out = {}
	for i = 1, #leader_order do out[i] = leader_order[i] end
	return out
end

function SA.zone_critter(zone_id, mob_name)
	local rec = zones[zone_id]
	if not rec or mob_name:sub(1, #MOD_PREFIX) ~= MOD_PREFIX then
		return false
	end
	return rec.critters[mob_name:sub(#MOD_PREFIX + 1)] == true
end

function SA.zone_ids()
	local ids = {}
	for zone_id in pairs(zones) do
		ids[#ids + 1] = zone_id
	end
	table.sort(ids)
	return ids
end

function SA.camp_areas()
	return camp_areas
end

-- The three fallback tables spawn_policy.lua consumes, keyed by zone id:
-- named-zone palettes, the boar tint and the lookalike choices.
function SA.fallback_palettes()
	local palettes, boars, lookalikes = {}, {}, {}
	for zone_id, rec in pairs(zones) do
		palettes[zone_id] = rec.palette
		boars[zone_id] = rec.boar
		lookalikes[zone_id] = rec.lookalikes
	end
	return palettes, boars, lookalikes
end

--
-- Matching
--

function SA.in_shape(area, x, z)
	local shape = area.shape
	local kind = shape.kind
	if kind == "zone" then
		return true
	end
	local dx, dz = x - area.cx, z - area.cz
	if kind == "circle" then
		return dx * dx + dz * dz <= shape.r2
	elseif kind == "ring" then
		local d2 = dx * dx + dz * dz
		return d2 >= shape.rmin2 and d2 <= shape.rmax2
	end
	local forward = shape.sign * dz
	return forward >= shape.f0 and forward <= shape.f1 and
		dx >= shape.s0 and dx <= shape.s1
end

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

-- A candidate point: the ground node (x, y, z, its name). Biome and shore
-- are looked up at most once per point and only when an area asks.
function SA.point(x, y, z, node)
	return {x = x, y = y, z = z, node = node}
end

local function point_biome(pt)
	local biome = pt.biome
	if biome == nil then
		biome = biome_key(grug_zones.biome_at(pt.x, pt.z)) or false
		pt.biome = biome
	end
	return biome
end

local function point_shore(pt)
	local shore = pt.shore
	if shore == nil then
		shore = pt.node == "default:sand" and near_sea_water(pt.x, pt.y, pt.z)
		pt.shore = shore
	end
	return shore
end

function SA.hosts_ok(area, pt)
	if area.shore and not point_shore(pt) then
		return false
	end
	local set = area.biome_set
	return set == nil or set[point_biome(pt)] == true
end

local function clock_ok(area, clock)
	return area.clock == "both" or area.clock == clock
end

-- The ambient areas of `zone_id` that match point `pt` (in that zone) at
-- `clock`, written to `out`; returns their count. Camp areas cover their
-- ground (they keep the fallback away) but are never returned.
function SA.areas_at(zone_id, pt, clock, out)
	local rec = zones[zone_id]
	if not rec or #rec.areas == 0 then
		return 0
	end
	local n, covered = 0, false
	local list = rec.ambient
	for i = 1, #list do
		local area = list[i]
		if clock_ok(area, clock) and SA.in_shape(area, pt.x, pt.z) and
				SA.hosts_ok(area, pt) then
			covered = true
			if not area.camp then
				n = n + 1
				out[n] = area
			end
		end
	end
	local fallback = rec.fallback
	if not covered and clock_ok(fallback, clock) and
			SA.in_shape(fallback, pt.x, pt.z) and SA.hosts_ok(fallback, pt) then
		n = 1
		out[1] = fallback
	end
	return n
end

-- One (area, role) pick over the matched areas, weighted by the species
-- weights (overlap = union: a role's chance is its summed weight). Also
-- returns the role's summed weight and the total, for the density share.
function SA.pick(areas, n, roll)
	local total = 0
	for i = 1, n do
		total = total + areas[i].weight
	end
	if total <= 0 then
		return nil
	end
	local target = (roll or math.random()) * total
	local chosen_area, chosen_role
	for i = 1, n do
		local species = areas[i].species
		for j = 1, #species do
			target = target - species[j].weight
			if not chosen_role and target < 0 then
				chosen_area, chosen_role = areas[i], species[j].role
			end
		end
	end
	if not chosen_role then
		local last = areas[n].species
		chosen_area, chosen_role = areas[n], last[#last].role
	end
	local role_weight = 0
	for i = 1, n do
		role_weight = role_weight + (areas[i].roles[chosen_role] or 0)
	end
	return chosen_area, chosen_role, role_weight, total
end

-- A level in the area's fixed range.
function SA.roll_level(area)
	return math.random(area.levels[1], area.levels[2])
end

-- A random column inside an area's shape (camp slots). A `zone` shape has no
-- centre of its own; its camp spots are drawn within ZONE_CAMP_RADIUS of the
-- anchor point.
local ZONE_CAMP_RADIUS = 40
function SA.sample_xz(area)
	local shape = area.shape
	local kind = shape.kind
	local x, z
	if kind == "band" then
		local f = shape.f0 + math.random() * (shape.f1 - shape.f0)
		local s = shape.s0 + math.random() * (shape.s1 - shape.s0)
		x, z = area.cx + s, area.cz + shape.sign * f
	else
		local lo, hi = 0, ZONE_CAMP_RADIUS
		if kind == "circle" then
			hi = math.sqrt(shape.r2)
		elseif kind == "ring" then
			lo, hi = shape.rmin, shape.rmax
		end
		local angle = math.random() * 2 * math.pi
		local dist = math.sqrt(lo * lo + math.random() * (hi * hi - lo * lo))
		x, z = area.cx + math.cos(angle) * dist, area.cz + math.sin(angle) * dist
	end
	return math.floor(x + 0.5), math.floor(z + 0.5)
end

-- How far an area's mobs may stand from its anchor point (shape reach plus
-- the wander leash and a margin), for head counts.
function SA.reach(area)
	return (area.shape.extent or ZONE_CAMP_RADIUS) + 48
end

-- A height near an area's anchor point: the anchor's own y where the area
-- sits on it, else the terrain height of the column (cached).
function SA.center_y(area)
	if not area.cy then
		area.cy = grug_zones.terrain_height_at(area.cx, area.cz)
	end
	return area.cy
end

--
-- Spawning (ambient picks here; camp slots in camps.lua; leaders below)
--

-- The players the spawner works around. A seam so the engine probe can
-- stand in stationary points for players.
function SA.players()
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
-- y_center +- reach, or nil (unloaded, water, nothing natural).
function SA.ground_at(x, z, y_center, reach)
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
	return SA.point(best.x, best.y, best.z, core.get_node(best).name)
end

local function clock_now()
	local value = core.get_timeofday() or 0.5
	local day_start = grug_core.DAY_PHASE_START or 0.1875
	local day_end = grug_core.DAY_PHASE_END or 0.8125
	return (value >= day_start and value <= day_end) and "day" or "night"
end
SA.clock_now = clock_now

local function critter(name)
	local def = core.registered_entities[name]
	return def ~= nil and def._grug_disposition == "critter"
end

-- No player closer than `range` to `pos`.
function SA.players_clear(pos, range, players)
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

-- Puts one area mob on ground point `g`: the role's entity, the area tag and
-- a level from the area's range. Returns the entity or nil.
function SA.spawn_area_mob(area, role, g)
	local name = MOD_PREFIX .. role
	if not core.registered_entities[name] then
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
	-- Both plain fields, persisted with the mob; ensure_init (levels.lua)
	-- reads the level on the first tick, before which nothing has levelled.
	ent._grug_area = area.tag
	ent._grug_spawn_level = SA.roll_level(area)
	return ent
end

-- The gates every area spawn passes at its standing position: ruling 3's
-- protected surface (non-critters), an active housing claim (hostiles).
function SA.spawn_refused(name, stand)
	if not critter(name) and grug_mobs.protected_spawn_surface(stand) then
		return "protected"
	end
	if grug_mobs.claim_refuses_spawn(name, stand) then
		return "claim"
	end
	return nil
end

SA.stats = {}
local function count(reason)
	SA.stats[reason] = (SA.stats[reason] or 0) + 1
	return reason
end

local nospawn_range
local scratch = {}

-- One ambient attempt around a player position: a random column in the ring
-- nospawn_range .. ATTEMPT_RANGE, only in a zone with areas (the ABM rows
-- serve every other zone). Returns the outcome (a reason or "spawned").
SA.ATTEMPT_RANGE = 64
SA.GROUND_REACH = 48
function SA.attempt(player_pos, players, clock, roll_angle, roll_dist)
	if not nospawn_range then
		nospawn_range = tonumber(core.settings:get("mob_nospawn_range")) or 24
	end
	local angle = (roll_angle or math.random()) * 2 * math.pi
	local lo, hi = nospawn_range, SA.ATTEMPT_RANGE
	local dist = math.sqrt(lo * lo + (roll_dist or math.random()) * (hi * hi - lo * lo))
	local x = math.floor(player_pos.x + math.cos(angle) * dist + 0.5)
	local z = math.floor(player_pos.z + math.sin(angle) * dist + 0.5)
	local zone_id = grug_zones.id_at(x, z)
	if not zone_id or not SA.zone_has_areas(zone_id) then
		return count("no_area_zone")
	end
	local g = SA.ground_at(x, z, math.floor(player_pos.y + 0.5), SA.GROUND_REACH)
	if not g or g.y < 0 then
		return count("no_ground")
	end
	local n = SA.areas_at(zone_id, g, clock, scratch)
	if n == 0 then
		return count("no_area")
	end
	local area, role, role_weight, total = SA.pick(scratch, n)
	for i = 1, n do scratch[i] = nil end
	local name = MOD_PREFIX .. role
	local stand = {x = g.x, y = g.y + 1, z = g.z}
	if not SA.players_clear(stand, nospawn_range, players) then
		return count("player_near")
	end
	local refused = SA.spawn_refused(name, stand)
	if refused then
		return count(refused)
	end
	if not grug_mobs.area_density_allows(stand, zone_id, clock, area, name,
			role_weight, total) then
		return count("density")
	end
	if not SA.spawn_area_mob(area, role, g) then
		return count("no_room")
	end
	return count("spawned")
end

--
-- Leaders (ruling 38): fixed spot, fixed level, ~5 min respawn after a kill.
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
SA.LEADER_RANGE = 96 -- horizontal player distance that wakes a spot
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

-- The highest standable node in the leader's column: any walkable node with
-- two air nodes above (a leader may stand on a camp's built floor).
local function leader_ground(leader)
	local y0 = leader.anchor_y
	if not y0 then
		leader.terrain_y = leader.terrain_y or
			grug_zones.terrain_height_at(leader.x, leader.z)
		y0 = leader.terrain_y
	end
	for y = y0 + LEADER_REACH, y0 - LEADER_REACH, -1 do
		local here = core.get_node_or_nil({x = leader.x, y = y, z = leader.z})
		if here and here.name ~= "air" and here.name ~= "ignore" and
				core.get_item_group(here.name, "leaves") == 0 and
				core.get_item_group(here.name, "tree") == 0 then
			local def = core.registered_nodes[here.name]
			if def and def.walkable then
				local a1 = core.get_node_or_nil({x = leader.x, y = y + 1, z = leader.z})
				local a2 = core.get_node_or_nil({x = leader.x, y = y + 2, z = leader.z})
				if a1 and a2 and a1.name == "air" and a2.name == "air" then
					return {x = leader.x, y = y + 1, z = leader.z}
				end
				return nil
			end
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
SA.player_near_xz = player_near_xz

function SA.leader_tick(now, players)
	for i = 1, #leader_order do
		local leader = leaders[leader_order[i]]
		if not leader_alive(leader.role) and
				now >= storage:get_int("leader_next:" .. leader.role) and
				player_near_xz(leader.x, leader.z, SA.LEADER_RANGE, players) then
			local pos = leader_ground(leader)
			if pos and not grug_mobs.claim_refuses_spawn(leader.name, pos) then
				local ent = grug_mobs.add_mob(pos, {name = leader.name, ignore_count = true})
				if ent then
					ent._grug_leader = true
					ent._grug_spawn_level = leader.level
					ent.object:set_properties({static_save = false})
					live_leaders[leader.role] = ent.object
					count("leader_spawned")
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
		local leader = leaders[role]
		if leader then
			storage:set_int("leader_next:" .. role,
				core.get_gametime() + leader.respawn)
			live_leaders[role] = nil
		end
	end
	return settle_mob_death(self)
end

--
-- The one throttled globalstep: one ambient attempt per player per second;
-- camp slots and leaders every five seconds.
--

SA.ATTEMPT_PERIOD = 1
SA.SLOW_PERIOD = 5
local attempt_acc, slow_acc = 0, 0
local spawning = core.settings:get_bool("mobs_spawn") ~= false

local function any_areas()
	for _, rec in pairs(zones) do
		if #rec.areas > 0 or #rec.leaders > 0 then
			return true
		end
	end
	return false
end

core.register_globalstep(function(dtime)
	attempt_acc = attempt_acc + dtime
	slow_acc = slow_acc + dtime
	if attempt_acc < SA.ATTEMPT_PERIOD then
		return
	end
	attempt_acc = 0
	if not spawning or not any_areas() then
		slow_acc = 0
		return
	end
	local players = SA.players()
	local clock = clock_now()
	for i = 1, #players do
		local pos = players[i]:get_pos()
		if pos and pos.y > -40 then
			SA.attempt(pos, players, clock)
		end
	end
	if slow_acc >= SA.SLOW_PERIOD then
		slow_acc = 0
		local now = core.get_gametime()
		grug_mobs.area_camp_tick(now, players, clock)
		SA.leader_tick(now, players)
	end
end)

-- Roles exist once every mob file has registered (sub-types included).
core.register_on_mods_loaded(function()
	ground_list()
	local function need(name, where)
		if not core.registered_entities[name] then
			fail(where, name .. " is not a registered mob")
		end
	end
	for zone_id, rec in pairs(zones) do
		for role in pairs(rec.critters) do
			local name = MOD_PREFIX .. role
			need(name, zone_id .. " critters")
			if not critter(name) then
				fail(zone_id .. " critters", role .. " is not a critter")
			end
		end
		for _, area in ipairs(rec.areas) do
			for role in pairs(area.roles) do
				need(MOD_PREFIX .. role, area.tag)
			end
		end
		for _, leader in ipairs(rec.leaders) do
			need(leader.name, zone_id .. " leader")
		end
	end
end)
