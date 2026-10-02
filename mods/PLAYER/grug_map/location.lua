-- Zone and town names for players (Round 28 Lane M1; docs/design/world_map.md
-- "Zone and town names"). Why: players could not tell which zone they were
-- in, and quest texts and level routes now name zones.
--
--   * one location per player, sampled every second: the zone's display
--     name, or the town's name inside a start town or capital city (their
--     protected footprint, grug_zones.hard_footprint_in); villages, outposts,
--     camps and POIs keep the zone's name;
--   * the line under the minimap shows it (minimap.lua reads text_of);
--   * the entry banner shows a new location top centre for DISPLAY seconds,
--     debounced (location_view.lua);
--   * the Map tab gets one marker per zone with its name and level band in
--     the tooltip, placed once at startup from the analytic world (whose
--     zone grid a later start reads from the world folder).
--
-- Pure rules: location_view.lua.

local atlas = grug_map.atlas
local layout = grug_core.hud_layout
local L = dofile(core.get_modpath(core.get_current_modname()) .. "/location_view.lua")
local M = {view = L}
grug_map.location = M

-- Half the capital city's reserved square (source/simple_map.lua,
-- hard_capital_city_v1 bound_width 532), which is larger than a start town's
-- (152): a town is asked about only inside this box round its anchor.
local TOWN_REACH = 266
-- The zone marker grid step in nodes, and the marker art.
local GRID_STEP = 32
local ZONE_TEXTURE = "grug_map_zone.png"
-- Formspec units on the Map tab at zoom 1 (the closest markers ever get;
-- zooming in spreads them): page.lua draws markers about 0.34 wide, and a
-- zone marker keeps its centre GAP_UNITS from every other marker's centre
-- on both axes (square buttons), a tenth of a unit between the edges.
local GAP_UNITS = 0.45
local TICK = 0.1
local COLOR = grug_core.FEED_COLOR.notice

-- Comparison figures for the report: samples and their summed cost.
M.stats = {samples = 0, us = 0}

local resolve
local zone_markers = {}

local function zone_names()
	return setmetatable({}, {__index = function(names, id)
		local record = grug_zones.get(id)
		local name = record and record.display_name or id
		rawset(names, id, name)
		return name
	end})
end

-- The start towns and capital cities: every registered settlement whose
-- anchor column lies in a hard "town" footprint (villages, outposts and
-- camps have none).
local function build_resolver()
	if not grug_core.zone_authority_installed() then return nil end
	local towns = {}
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		local a = row.anchor
		local id, kind = grug_zones.hard_footprint_in(a.x, a.z, a.x, a.z)
		if kind == "town" then
			towns[#towns + 1] = {name = row.display_name or row.key, x = a.x, z = a.z,
				footprint = id}
		end
	end
	return L.resolver({zone_at = grug_zones.id_at, names = zone_names(),
		towns = towns, reach = TOWN_REACH,
		footprint_at = function(x, z) return (grug_zones.hard_footprint_in(x, z, x, z)) end})
end
resolve = build_resolver()

-- The location text at a position ("" before the world authority exists).
function M.text_at(pos)
	return resolve and resolve(pos.x, pos.z) or ""
end

-- ---------------------------------------------------------------------------
-- Zone markers on the Map tab
-- ---------------------------------------------------------------------------

-- The land of every zone on a GRID_STEP grid over the atlas bounds.
local function sample_grid(view)
	local nx = math.ceil((view.max_x - view.min_x) / GRID_STEP)
	local nz = math.ceil((view.max_z - view.min_z) / GRID_STEP)
	local cells, seen = {}, {}
	for gz = 0, nz - 1 do
		local z = math.floor(view.max_z - (gz + 0.5) * GRID_STEP)
		for gx = 0, nx - 1 do
			local x = math.floor(view.min_x + (gx + 0.5) * GRID_STEP)
			local id = false
			if grug_zones.water_class_at(x, z) == "land" then
				id = grug_zones.id_at(x, z) or false
				if id then seen[id] = true end
			end
			cells[gz * nx + gx + 1] = id
		end
	end
	return {nx = nx, nz = nz, step = GRID_STEP, min_x = view.min_x,
		max_z = view.max_z, cells = cells}, seen
end

-- The sampled grid depends on the world alone, so a later start of the same
-- world reads it from the world folder (Round 30 P3; the placement itself
-- runs every start, its markers may move). Key: the world-layout cache's
-- parts (grug_mapgen.wp40.world_key: seed, mapgen tree, mapgen settings,
-- interpreter), the zone queries' seam (grug_core/zone_authority.lua), this
-- file (the sampling rule), the view and the step. The file ends in a
-- SHA-256 over every byte before it; anything that does not decode samples
-- afresh and replaces the file.
local GRID_FORMAT = "grug_map_zone_grid_v1"
local GRID_FILE = core.get_worldpath() .. "/grug_map_zone_grid.txt"

local function read_file(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local data = file:read("*a")
	file:close()
	return data
end

-- The grid's key (one line), or nil when this start has no world key.
local function grid_key(view)
	local mapgen = rawget(_G, "grug_mapgen")
	local world = type(mapgen) == "table" and type(mapgen.wp40) == "table" and
		mapgen.wp40.world_key
	local seam = read_file(core.get_modpath("grug_core") .. "/zone_authority.lua")
	local rule = read_file(core.get_modpath("grug_map") .. "/location.lua")
	if type(world) ~= "table" or not seam or not rule then return nil end
	return core.sha256(table.concat({GRID_FORMAT, world.seed, world.source, world.settings,
		world.interpreter, core.sha256(seam), core.sha256(rule), view.min_x, view.max_x,
		view.min_z, view.max_z, GRID_STEP}, "\n"))
end

-- The file of a grid: the zone ids, then one byte per cell (the id's index,
-- 0 for no zone land).
local function encode_grid(key, grid)
	local ids, index, bytes = {}, {}, {}
	for n = 1, grid.nx * grid.nz do
		local id = grid.cells[n]
		if id and not index[id] then
			ids[#ids + 1] = id
			index[id] = #ids
		end
		bytes[n] = string.char(id and index[id] or 0)
	end
	assert(#ids < 256, "too many zones for the zone grid file")
	local head = table.concat({GRID_FORMAT, "\nkey ", key, "\nids ", table.concat(ids, " "),
		"\ngrid ", grid.nx, " ", grid.nz, "\n", table.concat(bytes), "\n"})
	return head .. "end " .. core.sha256(head) .. "\n"
end

-- {grid, seen} from the file bytes, or nil when they do not match the key.
local function decode_grid(bytes, key, view)
	if type(bytes) ~= "string" then return nil end
	local head, digest = bytes:match("^(.*\n)end (%x+)\n$")
	if not head or core.sha256(head) ~= digest then return nil end
	local format, k, id_line, nx, nz, pos = head:match(
		"^([^\n]*)\nkey (%x+)\nids ([^\n]*)\ngrid (%d+) (%d+)\n()")
	if format ~= GRID_FORMAT or k ~= key then return nil end
	nx, nz = tonumber(nx), tonumber(nz)
	if #head ~= pos + nx * nz then return nil end
	local ids = {}
	for id in id_line:gmatch("%S+") do ids[#ids + 1] = id end
	local cells, seen = {}, {}
	for n = 1, nx * nz do
		local b = head:byte(pos + n - 1)
		if b > #ids then return nil end
		local id = b > 0 and ids[b] or false
		cells[n] = id
		if id then seen[id] = true end
	end
	return {nx = nx, nz = nz, step = GRID_STEP, min_x = view.min_x, max_z = view.max_z,
		cells = cells}, seen
end

-- The zone grid of this world: from the file when it is current, else
-- sampled (and stored). Returns grid, seen and how it was obtained.
local function zone_grid(view)
	local key = grid_key(view)
	if key then
		local ok, grid, seen = pcall(decode_grid, read_file(GRID_FILE), key, view)
		if ok and grid then return grid, seen, "from the file" end
	end
	local grid, seen = sample_grid(view)
	if not key then return grid, seen, "sampled, not cached (no world key)" end
	if not core.safe_file_write(GRID_FILE, encode_grid(key, grid)) then
		core.log("warning", "[grug_map] the zone grid file could not be written: " .. GRID_FILE)
		return grid, seen, "sampled"
	end
	return grid, seen, "sampled and stored"
end

local function place_zone_markers()
	if not grug_core.zone_authority_installed() then return end
	local started = core.get_us_time()
	local view = atlas.view()
	local page = grug_map.page_layout
	local nodes = (view.max_x - view.min_x) / page.map_w
	local gap = GAP_UNITS * nodes
	-- Every fixed marker of the Map tab: services, kings, dragons, quest
	-- givers, settlements and innkeepers; the region names as text boxes.
	local obstacles = {}
	local function add(pos)
		obstacles[#obstacles + 1] = {x = pos.x, z = pos.z, rx = gap, rz = gap}
	end
	for _, pos in ipairs(grug_map.static_marker_positions()) do add(pos) end
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do add(row.anchor) end
	for _, row in ipairs(grug_home.locations()) do add(row.pos) end
	for _, row in ipairs(page.region_labels) do
		obstacles[#obstacles + 1] = L.text_obstacle(row[1], row[2], row[3], row[4],
			GAP_UNITS, nodes)
	end
	local grid, seen, source = zone_grid(view)
	local sampled = core.get_us_time()
	local records, order = {}, {}
	for id in pairs(seen) do
		records[id] = grug_zones.get(id)
		order[#order + 1] = id
	end
	table.sort(order, function(a, b) return records[a].numeric_id < records[b].numeric_id end)
	-- Zone markers keep the same spacing from each other.
	local points = L.place_labels(grid, order, obstacles, gap)
	zone_markers = {}
	for _, id in ipairs(order) do
		local point = points[id]
		if point then
			local record = records[id]
			zone_markers[#zone_markers + 1] = {id = id,
				label = record.display_name or id, detail = L.zone_tooltip(record),
				position = {x = point.x, z = point.z}, kind = "zone",
				texture = ZONE_TEXTURE}
		end
	end
	local finished = core.get_us_time()
	core.log("action", ("[grug_map] placed %d zone markers in %.3f s (grid %dx%d %s " ..
		"in %.3f s)"):format(#zone_markers, (finished - started) / 1e6,
		grid.nx, grid.nz, source, (sampled - started) / 1e6))
end

-- After providers.lua's own mods-loaded hook (registered earlier, so it runs
-- first): the quest givers and services are known by then.
core.register_on_mods_loaded(place_zone_markers)

atlas.register_marker_provider("zone", function() return zone_markers end)

-- ---------------------------------------------------------------------------
-- Per-player location and the entry banner
-- ---------------------------------------------------------------------------

-- player name -> {state, text, next_sample, banner, offset_y}
local players = {}
-- player name -> true while a banner display runs
local busy = {}

local function now_seconds()
	return core.get_us_time() / 1000000
end

-- The player's current location text ("" before the first sample).
function M.text_of(player)
	local name = type(player) == "string" and player or player:get_player_name()
	local rec = players[name]
	return rec and rec.text or ""
end

local function sample(player, rec)
	local started = core.get_us_time()
	local text = M.text_at(player:get_pos())
	M.stats.samples = M.stats.samples + 1
	M.stats.us = M.stats.us + (core.get_us_time() - started)
	rec.text = text
	return text ~= "" and text or nil
end

local function display(player, rec, text)
	local name = player:get_player_name()
	local offset = layout.zone_banner_offset(core.get_player_window_information(name))
	if rec.offset_y ~= offset.y then
		rec.offset_y = offset.y
		player:hud_change(rec.banner, "offset", offset)
	end
	player:hud_change(rec.banner, "text", text)
	busy[name] = true
end

-- Players joining one after another sample in different phases.
local JOIN_PHASE = 0.2
local joined = 0
core.register_on_joinplayer(function(player)
	joined = joined + 1
	local anchor = layout.anchors.zone_banner
	players[player:get_player_name()] = {state = L.new_state(), text = "",
		next_sample = now_seconds() + (joined * JOIN_PHASE) % L.SAMPLE,
		offset_y = anchor.offset.y,
		banner = player:hud_add(layout.text_element("zone_banner", {number = COLOR,
			text = "", size = {x = layout.ZONE_BANNER_SIZE}, style = 1, z_index = 2}))}
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	players[name], busy[name] = nil, nil
end)

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < TICK then return end
	elapsed = 0
	local now = now_seconds()
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local rec = players[name]
		-- During character creation the player stands at the engine's spawn
		-- spot: no sample, so neither the line nor the banner names it; the
		-- first sample after release shows the start town.
		if rec and now >= rec.next_sample and not (grug_core.player_in_creation_stasis and
				grug_core.player_in_creation_stasis(name)) then
			-- A late step does not make up for missed samples.
			local next_sample = rec.next_sample + L.SAMPLE
			rec.next_sample = next_sample > now and next_sample or now + L.SAMPLE
			local text = L.sample(rec.state, sample(player, rec), now)
			if text then display(player, rec, text) end
		end
	end
	for name in pairs(busy) do
		local rec = players[name]
		local player = rec and core.get_player_by_name(name)
		if not player then
			busy[name] = nil
		elseif now >= rec.state.busy_until then
			-- A fresh sample decides: the player may have come back already.
			local result = L.expire(rec.state, sample(player, rec), now)
			if result then
				display(player, rec, result)
			else
				player:hud_change(rec.banner, "text", "")
				busy[name] = nil
			end
		end
	end
end)
