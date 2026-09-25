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
	local runtime = dofile(wp40 .. "/r7_runtime.lua")(core_api, wp40,
		default_path .. "/schematics", projection, catalog)
	local built = runtime.build_authority(native.identities())
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

	-- THE GROUND UNDER THE TERRAIN-RELATIVE BLUEPRINTS, on THIS world.
	--
	-- A capital's district plots are placed at positions that were measured
	-- against two seeds and are legal on both, and the writer projects them
	-- from one column without a water or a fall test of its own. On a third
	-- seed a plot can stand in a river or half-buried and nothing says so.
	-- This is the sentence that says so. It is a WARNING and nothing else: the
	-- capital is still built, because half a world is not worth refusing over
	-- one plot, and a diagnosable failure is the whole point.
	if type(runtime.settlement_terrain_findings) == "function" then
		local findings = runtime.settlement_terrain_findings(built)
		for index = 1, #findings do
			local finding = findings[index]
			core_api.log("warning", "[grug_mapgen] WP13 " .. finding.settlement ..
				": the plot " .. tostring(finding.plot_id or finding.id) ..
				" at offset " .. finding.x .. "," .. finding.z ..
				" does not stand on this world's ground -- submerged columns " ..
				finding.submerged .. ", perimeter fall " .. finding.fall ..
				" against a skirt of " .. finding.skirt .. ", rise " ..
				finding.rise .. " against a clear of " .. finding.clear ..
				". Re-run tools/wp13/capital_lots.lua against this seed's " ..
				"field dump.")
		end
	end

	-- The inland water layout travels with the payload, so emerge never
	-- rebuilds it (plan D37: no cache file).
	local payload = {schema = "grug_wp40_r7_ipc_v1",
		manifest_sha256 = built.manifest.sha256, full_seed = built.full_seed,
		projection = projection, water_layout = runtime.water_layout_text()}

	-- No fallible semantic validation follows this line.
	native.register_ores(native_token)
	core_api.ipc_set(IPC_KEY, payload)
	core_api.register_mapgen_script(mapgen_modpath .. "/wp40/r7_mapgen.lua")
	publish_authority()

	return {schema = "grug_wp40_r7_loader_status_v1", enabled = true,
		production_enabled = true, writer_count = 1,
		manifest_sha256 = built.manifest.sha256, full_seed = built.full_seed,
		settlement_sockets = socket_count,
		zones = rawget(_G, "grug_zones"), planner_source = built.planner_source,
		preparation_source = built.preparation_source,
		-- The inland water layout for the world map: its text (cache key) and
		-- river centrelines (the relief grid is too coarse for rivers).
		water_layout_text = runtime.water_layout_text(),
		river_polylines = runtime.river_polylines()}
end
