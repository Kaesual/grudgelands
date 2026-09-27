-- Main-environment half of the atomic R7 cutover. All fallible semantic work
-- finishes before the native registrations, IPC publication, sole mapgen
-- script registration and assignment-only public authority installation.

return function(core_api, mapgen_modpath, materials, gathering, core_owner)
	local IPC_KEY = "grug_mapgen:r7_runtime_v1"
	local function fail(message)
		error("WP40 R7 loader: " .. message, 0)
	end
	if type(core_api) ~= "table" or type(core_api.ipc_set) ~= "function" or
			type(core_api.log) ~= "function" or
			type(core_api.register_mapgen_script) ~= "function" or
			type(mapgen_modpath) ~= "string" or mapgen_modpath == "" or
			type(materials) ~= "table" or type(gathering) ~= "table" or
			type(core_owner) ~= "table" or
			type(core_owner.prepare_zone_authority) ~= "function" then
		fail("construction seam differs")
	end
	local wp40 = mapgen_modpath .. "/wp40"
	local default_path = core_api.get_modpath("default")
	local gathering_path = core_api.get_modpath("grug_gathering")
	if type(default_path) ~= "string" or type(gathering_path) ~= "string" then
		fail("required mod path differs")
	end
	local handoff = dofile(mapgen_modpath .. "/wp43_handoff.lua")
	local projection = handoff.project(materials)
	handoff.validate_public(materials, projection)
	handoff.validate_registrations(projection, core_api.registered_items,
		core_api.registered_nodes)
	handoff.validate_target_names(materials, projection)
	local catalog = dofile(gathering_path .. "/catalog.lua")
	local native = dofile(wp40 .. "/r7_native.lua")
	local native_token = native.apply_and_validate_main()

	-- THE WORLD-FOLDER LAYOUT CACHE (plan D71, world_zones.md §13.4). The
	-- water, road and capital layout texts are built on a world's first start
	-- and stored in the world folder; a later boot whose key matches hands
	-- them to the runtime exactly as emerge gets them from the payload, so
	-- main skips the three builds. Any other key, or a damaged file, builds
	-- afresh and replaces the file. Main only; emerge still takes the texts
	-- from the payload.
	local now = type(core_api.get_us_time) == "function" and function()
		return core_api.get_us_time() / 1000000 end or os.clock
	local layout_cache, cache_key, cached, cache_reason, cache_damaged
	local world_dir = type(core_api.get_worldpath) == "function" and
		core_api.get_worldpath() or nil
	if type(world_dir) == "string" and world_dir ~= "" and
			type(core_api.get_dir_list) == "function" and
			type(core_api.safe_file_write) == "function" then
		layout_cache = dofile(wp40 .. "/layout_cache.lua")({sha256 = core_api.sha256,
			list_dir = core_api.get_dir_list, write = core_api.safe_file_write,
			identity = dofile(wp40 .. "/preparation_identity.lua")})
		local seed = core_api.get_mapgen_setting("seed")
		if type(seed) ~= "string" or not seed:match("^%-?%d+$") then
			fail("full world seed differs")
		end
		local settings = {}
		for _, name in ipairs({"mg_name", "water_level", "mapgen_limit", "chunksize",
				"mg_flags", "mgv7_spflags"}) do
			settings[#settings + 1] = name .. ":" .. tostring(core_api.get_mapgen_setting(name))
		end
		local jit_table = rawget(_G, "jit")
		-- A mapgen source file that cannot be read leaves no trustworthy key:
		-- build afresh and cache nothing this boot (a warning, not a stop).
		local digest_ok, source_digest = pcall(layout_cache.source_digest, mapgen_modpath)
		if digest_ok then
			cache_key = layout_cache.key(seed, source_digest, table.concat(settings, ";"),
				type(jit_table) == "table" and tostring(jit_table.version) or _VERSION)
			-- A file that cannot even be read builds afresh like a damaged one.
			local ok, result, reason, damaged = pcall(layout_cache.load, world_dir, cache_key)
			if ok then
				cached, cache_reason, cache_damaged = result, reason, damaged
			else
				cached, cache_reason, cache_damaged = nil, "unreadable: " .. tostring(result), true
			end
		else
			layout_cache = nil
			cache_reason, cache_damaged = "no source key, not cached: " ..
				tostring(source_digest), true
		end
	else
		cache_reason = "no world folder"
	end
	local function construct(texts)
		local started = now()
		local constructed = dofile(wp40 .. "/r7_runtime.lua")(core_api, wp40,
			default_path .. "/schematics", projection, catalog,
			texts and texts.water, texts and texts.road, texts and texts.capital)
		local seconds = now() - started
		return constructed, constructed.build_authority(native.identities()), seconds
	end
	local runtime, built, construction_seconds
	if cached then
		-- A hit passed every hash, so a failure here means texts this code
		-- cannot build from (e.g. a hand-edited, re-hashed file): warn and
		-- build afresh; the miss below replaces the file.
		local ok, constructed, authority, seconds = pcall(construct, cached)
		if ok then
			runtime, built, construction_seconds = constructed, authority, seconds
		else
			cached, cache_damaged = nil, true
			cache_reason = "the cached layouts did not construct: " .. tostring(constructed)
		end
	end
	if not runtime then runtime, built, construction_seconds = construct(nil) end
	local publish_authority = core_owner.prepare_zone_authority(
		built.zones_session, built.consumer_payload)
	if type(publish_authority) ~= "function" then
		fail("prepared authority seam differs")
	end
	-- WP13 NPC sockets (docs/research/wp13-npc-sockets-contract.md section 3).
	-- Every blueprint is prepared and every settlement anchor is fitted, so the
	-- socket sets can be published to the runtime registry in grug_core here,
	-- BEFORE the irreversible cutover below: registration validates authored
	-- data and fails loudly, and a broken socket must stop the load while
	-- nothing is registered rather than after the writer is live. Sockets are
	-- landmarks, so this reads nothing the writer owns and enters no digest.
	--
	-- The starts come first, in roster order, and every capital after them,
	-- which is what the contract's "a settlement key is unique, a race id is
	-- not" rule needs: `settlement_sockets(race_id)` answers with the FIRST
	-- settlement registered for a race, i.e. its start.
	if type(core_owner.register_settlement_sockets) ~= "function" then
		fail("settlement socket registry differs")
	end
	local socket_rows = runtime.settlement_sockets(built)
	if type(socket_rows) ~= "table" or #socket_rows < 1 then
		fail("settlement socket roster differs")
	end
	-- The registration ORDER is "every start, then everything else", and the
	-- list of slots is derived from the roster rather than typed here: a roster
	-- that gains a village or an outpost slot must register it, not be silently
	-- skipped by a literal pair. Only the position of "start" is a rule -- it is
	-- what makes `settlement_sockets(race_id)` answer with a race's START -- so
	-- starts go first and every other slot follows in roster order.
	local socket_count = 0
	local slot_order, slot_seen = {"start"}, {start = true}
	for index = 1, #socket_rows do
		local slot = socket_rows[index].slot
		if type(slot) ~= "string" or slot == "" then
			fail("settlement slot differs: " .. tostring(socket_rows[index].key))
		end
		if not slot_seen[slot] then
			slot_seen[slot] = true
			slot_order[#slot_order + 1] = slot
		end
	end
	local registered_rows = 0
	for _, wanted in ipairs(slot_order) do
		for index = 1, #socket_rows do
			local row = socket_rows[index]
			-- The anchor is the same fitted one the settlement writer projects the
			-- cells against, from the same session, so socket y = 1 is the node
			-- above the settlement's own ground course.
			if type(row.anchor) ~= "table" or type(row.sockets) ~= "table" then
				fail("settlement socket anchor differs: " .. tostring(row.key))
			end
			if row.slot == wanted then
				registered_rows = registered_rows + 1
				socket_count = socket_count + core_owner.register_settlement_sockets(
					row.key, row.race, row.anchor, row.sockets, row.label)
			end
		end
	end
	if registered_rows ~= #socket_rows then
		fail("a settlement was never registered: " .. registered_rows .. " of " ..
			#socket_rows)
	end

	-- The layout build diagnostics below (capital and road figures, road
	-- showcase spots) exist only where the layouts were built; a cache hit
	-- repeats the ones the first start stored with the texts.
	local diagnostics = {}
	local function diagnose(level, text)
		core_api.log(level, text)
		diagnostics[#diagnostics + 1] = {level, text}
	end
	if cached then
		for _, row in ipairs(cached.meta.logs) do core_api.log(row[1], row[2]) end
	end

	-- THE CAPITAL LAYOUTS (Round 22 capital planner): one line per capital
	-- with the planner's figures, so a playtest log says what this world got.
	local capital_stats = runtime.capital_stats()
	for _, st in ipairs(capital_stats or {}) do
		diagnose("action", string.format("[grug_mapgen] capital %s: area %.0f m2, " ..
			"built %.1f %%, plots %d of %d (overflowed %d, left out %d fill, %d " ..
			"buildings), required %d of %d, relaxed %d, streets %d (open arcs %d, " ..
			"cross-lanes %d, squares %d), infeasible profiles %d, connector " ..
			"failures %d, shore avenues %d, gate run-outs %d, wet avenue ends %d%s, " ..
			"planned in %.2f s",
			st.key, st.area, 100 * st.built, st.placed, st.total, st.overflowed,
			st.left_out - st.left_out_buildings, st.left_out_buildings, st.required,
			st.required_total, st.relaxed, st.streets, st.open_arcs, st.cross_lanes,
			st.squares, st.infeasible, st.connector_failed, st.shore_avenues,
			st.gate_runouts, st.wet_avenue_ends,
			st.no_route and (", no route:" .. st.no_route) or "", st.seconds))
	end

	-- THE GROUND UNDER THE PLACED CAPITAL PLOTS, on THIS world's final
	-- terrain. The planner placed every plot on its own sample of the fitted
	-- ground, before its streets' cut and fill; this says where a plot no
	-- longer stands on the final ground. A WARNING and nothing else: the
	-- capital is still built, and a diagnosable finding is the whole point.
	-- Off by default (setting `grug_mapgen_terrain_audit`): it walks every
	-- placed plot's ground on the final terrain, seconds of main start.
	if core_api.settings and type(core_api.settings.get_bool) == "function" and
			core_api.settings:get_bool("grug_mapgen_terrain_audit", false) then
		local findings = runtime.settlement_terrain_findings(built)
		for index = 1, #findings do
			local finding = findings[index]
			core_api.log("warning", "[grug_mapgen] WP13 " .. finding.settlement ..
				": the plot " .. tostring(finding.plot_id or finding.id) ..
				" at offset " .. finding.x .. "," .. finding.z ..
				" does not stand on this world's ground -- submerged columns " ..
				finding.submerged .. ", perimeter fall " .. finding.fall ..
				" against a skirt of " .. finding.skirt .. ", rise " ..
				finding.rise .. " against a clear of " .. finding.clear .. ".")
		end
		core_api.log("action", "[grug_mapgen] capital plot terrain findings: " ..
			#findings)
	end

	-- The inland water, road and capital layouts travel with the payload, so
	-- emerge never rebuilds them (plan D37). The road layout carries the
	-- capital streets and connectors (the capital planner joined them to it
	-- in main). Main keeps the same texts in the world-folder cache (D71).
	local payload = {schema = "grug_wp40_r7_ipc_v1",
		manifest_sha256 = built.manifest.sha256, full_seed = built.full_seed,
		projection = projection, water_layout = runtime.water_layout_text(),
		road_layout = runtime.road_layout_text(),
		capital_layout = runtime.capital_layout_text(),
		-- Main's preparations of every lazy blueprint (identity, palette,
		-- landmarks), so emerge does not build and hash them all again.
		prepared_blueprints = runtime.prepared_handover()}

	-- Roads (Round 22 Phase 4): one log line with the construction figures
	-- and one with a showcase spot per road feature (a serpentine, a gallery,
	-- a short valley crossing, a bridge, the deepest cut, a junction, a
	-- ford), so a playtest can find them in a fresh world; `/road_spots`
	-- repeats the spots in chat.
	local road_layout = runtime.road_layout()
	local road_spot_lines, road_spots = {}, {}
	if cached then road_spots = cached.meta.spots end
	if road_layout then
		local st = road_layout.stats
		local roads_n, trails_n = 0, 0
		for _, road in ipairs(road_layout.roads) do
			if road.kind == "trail" then trails_n = trails_n + 1 else roads_n = roads_n + 1 end
		end
		local dropped = st.pins_dropped or {}
		diagnose("action", string.format("[grug_mapgen] roads: %d roads, %d trails " ..
			"(%d of %d trail candidates), %d loops, %d core pins dropped, built in " ..
			"%.1f s, payload %d bytes (with the capital streets), capital layouts " ..
			"%d bytes",
			roads_n, trails_n, st.trails_built or 0, st.trails_tried or 0, st.loops or 0,
			#dropped, st.t_total or 0, #payload.road_layout, #payload.capital_layout))
		if #dropped > 0 then
			diagnose("warning", "[grug_mapgen] roads: the core pin did not fit, " ..
				"the road may meet its village or POI with a step: " ..
				table.concat(dropped, ", "))
		end
		road_spots = runtime.road_module().showcase(road_layout)
	end
	for _, spot in ipairs(road_spots) do
		road_spot_lines[#road_spot_lines + 1] = string.format("%s (%s) at %d,%d,%d",
			spot.name, spot.kind, spot.x, spot.y, spot.z)
	end
	if road_layout then
		diagnose("action", "[grug_mapgen] road showcase: " ..
			table.concat(road_spot_lines, "; "))
	end

	-- No fallible semantic validation follows this line.
	native.register_ores(native_token)
	core_api.ipc_set(IPC_KEY, payload)
	core_api.register_mapgen_script(mapgen_modpath .. "/wp40/r7_mapgen.lua")
	publish_authority()
	if type(core_api.register_chatcommand) == "function" then
		core_api.register_chatcommand("road_spots", {
			description = "List one place per road feature (serpentine, gallery, " ..
				"valley crossing, bridge, deepest cut, junction, ford)",
			privs = {teleport = true},
			func = function()
				if #road_spot_lines == 0 then return true, "No roads in this world." end
				return true, table.concat(road_spot_lines, "\n")
			end,
		})
	end

	-- One line per boot about the layout cache. A miss stores this boot's
	-- texts (atomic replace) with its diagnostics; a failed write only warns.
	if cached then
		local s = cached.meta.seconds
		core_api.log("action", string.format("[grug_mapgen] world layouts: cache hit " ..
			"(%s), runtime construction %.1f s; skipped layout builds of the first " ..
			"start: water %.1f s, roads %.1f s, capitals %.1f s (its construction took " ..
			"%.1f s); the capital and road figures above are from that start",
			layout_cache.FILE, construction_seconds, s.water, s.roads, s.capitals,
			s.construction))
	else
		local built_seconds = runtime.layout_build_seconds() or {}
		local stored, bytes, store_error = false, 0, nil
		if layout_cache then
			local ok, result, count = pcall(layout_cache.store, world_dir, cache_key,
				{water = payload.water_layout, road = payload.road_layout,
					capital = payload.capital_layout},
				{logs = diagnostics, spots = road_spots, seconds = {
					construction = construction_seconds, water = built_seconds.water,
					roads = built_seconds.roads, capitals = built_seconds.capitals}})
			if ok then stored, bytes = result, count else store_error = tostring(result) end
		end
		core_api.log(cache_damaged and "warning" or "action", string.format(
			"[grug_mapgen] world layouts: cache miss (%s), built in runtime " ..
			"construction %.1f s (water %.1f s, roads %.1f s, capitals %.1f s)%s",
			cache_reason or "?", construction_seconds, built_seconds.water or 0,
			built_seconds.roads or 0, built_seconds.capitals or 0,
			stored and string.format(", stored %s (%d bytes)", layout_cache.FILE, bytes)
				or ""))
		if layout_cache and not stored then
			core_api.log("warning", "[grug_mapgen] world layouts: the cache file " ..
				"could not be written: " .. (store_error or layout_cache.path(world_dir)))
		end
	end

	return {schema = "grug_wp40_r7_loader_status_v1", enabled = true,
		production_enabled = true, writer_count = 1,
		manifest_sha256 = built.manifest.sha256, full_seed = built.full_seed,
		settlement_sockets = socket_count,
		zones = rawget(_G, "grug_zones"), planner_source = built.planner_source,
		preparation_source = built.preparation_source,
		-- The inland water layout for the world map: its text (cache key) and
		-- river centrelines (the relief grid is too coarse for rivers).
		water_layout_text = runtime.water_layout_text(),
		river_polylines = runtime.river_polylines(),
		-- The road network for the world map (Round 22 Phase 4).
		road_layout_text = payload.road_layout,
		road_polylines = runtime.road_polylines(), road_spots = road_spots,
		-- The capital layouts of this world (capital planner; the text
		-- `capital_planner.deserialize` reads), e.g. for the world map.
		capital_layout_text = payload.capital_layout}
end
