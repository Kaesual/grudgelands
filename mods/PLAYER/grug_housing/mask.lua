-- The claim mask of this world (Round 85 lane MASK): claim_mask.lua over the
-- published world plan, built once every mod has loaded (after the region
-- maps, grug_mobs/spawn_regions.lua), with its two world-folder files
-- (claim_mask_store.lua; docs/technical/claim-mask-format.md):
--   grug_claim_ground.txt  the column scans, so a later start of the same
--                          world plan scans nothing (the world-layout cache's
--                          key parts and a digest of the mask's files);
--   grug_claim_mask.txt    the map's snapshot, written at the start whose map
--                          has none yet (its record names the map: the seed
--                          and the map-reset record), never at a later start.
-- Published as grug_housing.mask (claim_mask.lua's mask: ground, list,
-- ground_in, kind_columns, kinds, quota_refusal); nil before the mods have
-- loaded and after a failed build (a recipe zone without its region map
-- counts as one), which is reported as severe and leaves every placement to
-- refuse. A failed snapshot is reported as severe too but leaves the mask in
-- use; the next start writes the snapshot again. grug_housing.claim_mask is the pure module
-- (chunk_of, chunk_bounds, the constants).
local modpath = core.get_modpath("grug_housing")
local CM = dofile(modpath .. "/claim_mask.lua")
grug_housing.claim_mask = CM

local function read_file(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local text = file:read("*a")
	file:close()
	return text
end

local STORE = dofile(modpath .. "/claim_mask_store.lua")({
	sha256 = function(bytes) return core.sha256(bytes) end,
	read = read_file,
	write = function(path, bytes) return core.safe_file_write(path, bytes) end,
})

-- The files whose bytes decide the column scans beside the mapgen tree.
local BUILDER_FILES = {
	{"grug_housing", "claim_mask.lua"},
	{"grug_housing", "mask.lua"},
	{"grug_core", "zone_authority.lua"},
}

-- The claim mask's world (claim_mask.lua `world`) from what grug_zones,
-- grug_core, grug_mapgen and grug_mobs publish.
local function build_world()
	local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
	local source = dofile(wp40 .. "/source/simple_map.lua")
	local world = {bounds = source.world_bounds, zones = {}}
	local records = {}
	for _, row in ipairs(source.zones) do
		local record = grug_zones.get(row.id)
		records[row.id] = record
		world.zones[#world.zones + 1] = record
	end
	local water_class_at, id_at = grug_zones.water_class_at, grug_zones.id_at
	local territory_rule_at = grug_zones.territory_rule_at
	function world.water_at(x, z) return water_class_at(x, z) end
	function world.zone_at(x, z)
		local id = id_at(x, z)
		return id and records[id] or nil
	end
	function world.territory_at(x, z) return territory_rule_at({x = x, y = 30000, z = z}) end
	function world.height_at(x, z) return grug_zones.terrain_height_at(x, z) end
	-- api.lua's feature_in, with the id
	function world.feature_in(min_x, min_z, max_x, max_z, margin)
		local hit, kind, id = grug_core.world_feature_boxes_in(min_x, min_z, max_x, max_z, margin)
		if hit then return "site", id or kind end
		local hid, hkind = grug_zones.hard_footprint_in(min_x - margin, min_z - margin,
			max_x + margin, max_z + margin)
		return hkind, hid
	end
	-- every road corridor of the layout text (world_protection.lua, as
	-- r7_loader.lua builds the protection)
	local wp = dofile(wp40 .. "/world_protection.lua")
	world.roads = {}
	for _, c in ipairs(wp.road_corridors(dofile(wp40 .. "/road_layout.lua"),
			grug_mapgen.wp40.road_layout_text)) do
		world.roads[#world.roads + 1] = {id = c.id, X = c.X, Z = c.Z, R = c.R,
			reach = c.half_width + c.side}
	end
	world.cities = {}
	local shapes = grug_mapgen.wp40.capital_protection
	local ids = {}
	for id in pairs(shapes) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		world.cities[#world.cities + 1] = {id = id, anchor = shapes[id].anchor,
			rows = shapes[id].rows}
	end
	-- the region maps' camps, leaders, quest places and quest-named kinds,
	-- and the named rares' routes
	local SR = grug_mobs.spawn_regions
	world.spawn = CM.new_spawn()
	-- Every recipe zone needs its map: without it its camps, leaders and
	-- quest places would be claim ground and its kinds outside the quota, so
	-- the mask fails closed instead (the caller reports it).
	for _, zone_id in ipairs(SR.zone_ids()) do
		local map = SR.map(zone_id)
		local record = records[zone_id]
		if not map or not record then
			error("the region map of " .. zone_id .. " is missing (" ..
				(record and "its build failed" or "no such zone in the world plan") .. ")", 0)
		end
		CM.add_zone_spawn(world.spawn, zone_id, function(fn) SR.each_cell(zone_id, fn) end,
			map.leaders, map.places,
			CM.zone_allowed("accord", record) or CM.zone_allowed("throng", record))
	end
	local rares = {}
	for id in pairs(grug_mobs.registered_rares or {}) do rares[#rares + 1] = id end
	table.sort(rares)
	for _, id in ipairs(rares) do
		local route = grug_core.rare_route(id)
		if route then CM.add_rare_route(world.spawn, route) end
	end
	return world
end

-- The cache key: the world-layout cache's key parts and the builder files'
-- digest; nil and the reason when this start has none.
local function cache_key()
	local key = grug_mapgen.wp40.world_key
	if type(key) ~= "table" then return nil, "no world key from grug_mapgen" end
	local lines = {}
	for _, file in ipairs(BUILDER_FILES) do
		local bytes = read_file(core.get_modpath(file[1]) .. "/" .. file[2])
		if not bytes then return nil, "cannot read " .. file[1] .. "/" .. file[2] end
		lines[#lines + 1] = file[1] .. "/" .. file[2] .. " " .. core.sha256(bytes)
	end
	return {{"seed", key.seed}, {"mapgen", key.source}, {"settings", key.settings},
		{"interpreter", key.interpreter},
		{"builder", core.sha256(table.concat(lines, "\n"))}}
end

-- The map's snapshot: kept when its record names this map (the seed and the
-- map-reset record), else written for this map. Raises on any failure; the
-- file is then left as it was, so the next start writes it again.
local function snapshot(mask, world, world_dir, key)
	local seed = core.get_mapgen_setting("seed")
	local applied = tostring(grug_core.map_reset.applied)
	local old, reason = STORE.load_snapshot(world_dir)
	if old and old.header.seed == seed and old.header.map_reset == applied then
		core.log("action", "[grug_housing] claim mask: the map's snapshot " ..
			STORE.SNAPSHOT_FILE .. " is kept (written by " .. tostring(old.header.game) .. ")")
	else
		if not old and reason ~= "no file" then
			core.log("warning", "[grug_housing] claim mask: the snapshot " ..
				STORE.SNAPSHOT_FILE .. " is damaged (" .. tostring(reason) ..
				") and is written anew")
		end
		local t1 = core.get_us_time()
		local native = dofile(core.get_modpath("grug_mapgen") .. "/wp40/r7_native.lua").identities()
		local wk = grug_mapgen.wp40.world_key or {}
		local header = {
			{"game", grug_core.world_version.game or "?"}, {"seed", seed},
			{"map_reset", applied}, {"mapgen", wk.source or "?"},
			{"settings", wk.settings or "?"}, {"interpreter", wk.interpreter or "?"},
			{"noise", native.noise_digest}, {"native", native.native_digest},
			{"mask", key and key[5][2] or "?"}, {"chunk", CM.CHUNK}, {"origin", CM.ORIGIN},
			{"strip", CM.STRIP}, {"step", CM.STEP}, {"digest", CM.DIGEST_HEX}}
		local rows = CM.fingerprints(mask, world, function(bytes) return core.sha256(bytes) end)
		local written, bytes = STORE.store_snapshot(world_dir, header, rows)
		if not written then error("cannot write " .. STORE.snapshot_path(world_dir), 0) end
		core.log("action", ("[grug_housing] claim mask: the map's snapshot %s written " ..
			"(%d chunks, %d bytes) in %.2f s"):format(STORE.SNAPSHOT_FILE, #rows, bytes,
			(core.get_us_time() - t1) / 1e6))
	end
end

local function start()
	local t0 = core.get_us_time()
	local world_dir = core.get_worldpath()
	local world = build_world()
	local t_world = core.get_us_time()
	local key, why = cache_key()
	local scans, cache_state, damaged
	if key then
		local ok, a, b, c = pcall(STORE.load_cache, world_dir, key)
		if ok then
			scans, cache_state, damaged = a, b, c
		else
			cache_state, damaged = "unreadable: " .. tostring(a), true
		end
	else
		cache_state = why
	end
	local hit = scans ~= nil
	scans = scans or {}
	local mask = CM.build(world, scans)
	local t_mask = core.get_us_time()
	local stored
	if key and mask.new_scans > 0 then
		local ok, result, bytes = pcall(STORE.store_cache, world_dir, key, scans)
		if ok and result then
			stored = bytes
		else
			core.log("warning", "[grug_housing] claim mask: the scan cache could not be " ..
				"written: " .. tostring(ok and STORE.cache_path(world_dir) or result))
		end
	end
	core.log(damaged and "warning" or "action", ("[grug_housing] claim mask: %d chunks " ..
		"of The Accord, %d of The Throng, %d quest kinds; %s, %d column scans " ..
		"(%d new)%s; world %.2f s, mask %.2f s"):format(mask.stats.accord, mask.stats.throng,
		#mask.kinds, hit and "cache hit" or ("cache miss (" .. tostring(cache_state) .. ")"),
		mask.stats.scanned, mask.new_scans,
		stored and (", stored " .. stored .. " bytes") or "",
		(t_world - t0) / 1e6, (t_mask - t_world) / 1e6))

	-- The snapshot has its own guard: a failure there leaves the mask in use.
	local ok, err = pcall(snapshot, mask, world, world_dir, key)
	if not ok then
		grug_core.severe.report("grug_housing", "the claim mask's snapshot " ..
			STORE.SNAPSHOT_FILE .. " was not written; the mask is in use, and the next " ..
			"start tries the snapshot again", tostring(err), "claim_mask_snapshot")
	end
	return mask
end

core.register_on_mods_loaded(function()
	local ok, result = pcall(start)
	if ok then
		grug_housing.mask = result
	else
		grug_core.severe.report("grug_housing", "the claim mask could not be built",
			tostring(result), "claim_mask")
	end
end)
