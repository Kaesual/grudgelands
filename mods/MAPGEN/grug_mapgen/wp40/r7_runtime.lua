-- Shared production R7 assembly. Main and emerge load these same pure source
-- bytes and independently rebuild the live content and semantic manifest.

return function(core_api, wp40_directory, schematic_directory, projection, catalog)
	local function fail(message)
		error("WP40 R7 runtime: " .. message, 0)
	end

	if type(core_api) ~= "table" or type(core_api.sha256) ~= "function" or
			type(core_api.get_mapgen_setting) ~= "function" or
			type(wp40_directory) ~= "string" or wp40_directory == "" or
			type(schematic_directory) ~= "string" or schematic_directory == "" or
			type(projection) ~= "table" or type(catalog) ~= "table" then
		fail("construction seam differs")
	end

	local function raw_sha256(bytes)
		local digest = core_api.sha256(bytes, true)
		if type(digest) ~= "string" or #digest ~= 32 then
			fail("core.sha256 raw result differs")
		end
		return digest
	end
	local function sha256_hex(bytes)
		return (raw_sha256(bytes):gsub(".", function(char)
			return string.format("%02x", string.byte(char))
		end))
	end

	local function exact_integer_setting(name, expected)
		local raw = core_api.get_mapgen_setting(name)
		local value = tonumber(raw)
		if type(raw) ~= "string" or type(value) ~= "number" or value ~= value or
				value == math.huge or value == -math.huge or value % 1 ~= 0 or
				value ~= expected then
			fail("mapgen setting " .. name .. " differs")
		end
		return value
	end

	local function flag_set(name, expected)
		local raw = core_api.get_mapgen_setting(name)
		if type(raw) ~= "string" then fail("mapgen flag setting " .. name .. " differs") end
		local actual, count = {}, 0
		for token in raw:gmatch("[^,%s]+") do
			if actual[token] then fail("duplicate mapgen flag " .. token) end
			actual[token], count = true, count + 1
		end
		local expected_count = 0
		for token in pairs(expected) do
			expected_count = expected_count + 1
			if not actual[token] then fail("missing mapgen flag " .. token) end
		end
		if count ~= expected_count then fail("mapgen flag population differs for " .. name) end
	end

	local function validate_live_scalars()
		if core_api.get_mapgen_setting("mg_name") ~= "v7" then
			fail("mg_name must be v7")
		end
		exact_integer_setting("water_level", 1)
		exact_integer_setting("mapgen_limit", 31007)
		exact_integer_setting("chunksize", 5)
		exact_integer_setting("mgv7_dungeon_ymin", -31000)
		exact_integer_setting("mgv7_dungeon_ymax", -193)
		flag_set("mg_flags", {biomes = true, caves = true, decorations = true,
			dungeons = true, light = true, ores = true})
		flag_set("mgv7_spflags", {mountains = true, ridges = true,
			caverns = true, nofloatlands = true})
		local settings_kind = type(core_api.settings)
		if settings_kind ~= "table" and settings_kind ~= "userdata" then
			fail("global settings object differs")
		end
		if type(core_api.settings.get) ~= "function" or
				core_api.settings:get("num_emerge_threads") ~= "1" then
			fail("num_emerge_threads must be explicit integer 1")
		end
		local seed = core_api.get_mapgen_setting("seed")
		if type(seed) ~= "string" or seed == "" or not seed:match("^%-?%d+$") then
			fail("full world seed differs")
		end
		return seed
	end

	local source = dofile(wp40_directory .. "/source/simple_map.lua")
	local schemas = dofile(wp40_directory .. "/schemas.lua")
	local canonical = dofile(wp40_directory .. "/canonical.lua")
	local deterministic = dofile(wp40_directory .. "/deterministic.lua")
	local index128 = dofile(wp40_directory .. "/index128.lua")
	local horizontal_factory = dofile(wp40_directory .. "/simple_map.lua")
	local height_factory = dofile(wp40_directory .. "/height.lua")
	local zones_factory = dofile(wp40_directory .. "/zones.lua")
	local r5_planner_factory = dofile(wp40_directory .. "/planner.lua")
	local r5_adapter_factory = dofile(wp40_directory .. "/map_adapter.lua")
	local r5_manifest_module = dofile(wp40_directory .. "/mapgen_manifest.lua")
	local allocator_factory = dofile(wp40_directory .. "/counting_allocator.lua")
	local r5_factory = dofile(wp40_directory .. "/r5.lua")
	local hash_factory = dofile(wp40_directory .. "/r6_hash.lua")
	local r6_content_factory = dofile(wp40_directory .. "/r6_content.lua")
	local r6_templates_factory = dofile(wp40_directory .. "/r6_templates.lua")
	local r6_planner_factory = dofile(wp40_directory .. "/r6_planner.lua")
	local r6_settlement_factory = dofile(wp40_directory .. "/r6_settlement.lua")
	local r6_factory = dofile(wp40_directory .. "/r6.lua")
	local r7_content_factory = dofile(wp40_directory .. "/r7_content.lua")
	local consumer_payload_factory = dofile(
		wp40_directory .. "/r7_consumer_payload.lua")
	local r7_manifest_factory = dofile(wp40_directory .. "/r7_manifest.lua")
	local r7_p9g_factory = dofile(wp40_directory .. "/r7_p9g.lua")
	local r7_anchor_roster_factory = dofile(
		wp40_directory .. "/r7_anchor_roster.lua")
	local r7_anchor_activation_factory = dofile(
		wp40_directory .. "/r7_anchor_activation.lua")
	local r7_successor_factory = dofile(wp40_directory .. "/r7_successor.lua")
	local r7_zone_overlay_factory = dofile(wp40_directory .. "/r7_zone_overlay.lua")
	local r7_r6_manifest = dofile(wp40_directory .. "/r7_r6_manifest.lua")
	local template_source_factory = dofile(wp40_directory .. "/r7_template_source.lua")
	local fetch_mapgen_object = core_api.get_mapgen_object

	local r6_module = r6_factory({r5_factory = r5_factory,
		zones_factory = zones_factory, r5_planner_factory = r5_planner_factory,
		r5_adapter_factory = r5_adapter_factory, manifest_module = r5_manifest_module,
		allocator_factory = allocator_factory, source = source, schemas = schemas,
		canonical = canonical, deterministic = deterministic, index128 = index128,
		horizontal_factory = horizontal_factory, height_factory = height_factory,
		raw_sha256 = raw_sha256, hash_factory = hash_factory,
		content_factory = r6_content_factory, templates_factory = r6_templates_factory,
		planner_factory = r6_planner_factory, settlement_factory = r6_settlement_factory})
	if type(r6_module.new_runtime) ~= "function" or
			type(r6_module.new_authority) ~= "function" then
		fail("R6 runtime constructor differs")
	end
	local r7_manifest_module = r7_manifest_factory(canonical, raw_sha256)
	local r6_manifest = r7_r6_manifest()
	local template_source = template_source_factory(core_api, schematic_directory)

	local module = {}
	local function build(native_identities, expected_manifest_sha256, evidence_mode,
			authority_only)
		if evidence_mode ~= nil and evidence_mode ~= true and
				evidence_mode ~= "horizontal" then
			fail("evidence mode differs")
		end
		if authority_only ~= nil and authority_only ~= true then
			fail("authority mode differs")
		end
		if authority_only and evidence_mode ~= nil then
			fail("authority/evidence modes overlap")
		end
		local full_seed = validate_live_scalars()
		local content_set = r7_content_factory(core_api, projection, raw_sha256)
		local cultural = catalog.cultural_registrations()
		local gathering_manifest = catalog.manifest()
		local heightmap_fetches = 0
		local mapgen_context = {schema = "grug_wp40_r5_mapgen_context_v1"}
		function mapgen_context.get_heightmap()
			heightmap_fetches = heightmap_fetches + 1
			if type(fetch_mapgen_object) ~= "function" then
				fail("heightmap requested outside emerge callback")
			end
			local heightmap = fetch_mapgen_object("heightmap")
			if type(heightmap) ~= "table" then fail("engine heightmap differs") end
			return heightmap
		end
		function mapgen_context.metrics()
			return {heightmap_fetch_calls = heightmap_fetches,
				heightmap_external_table_allocations = heightmap_fetches,
				metrics_result_table_allocations = 1}
		end
		local successor
		if not authority_only then
			local p9g_successor = r7_p9g_factory(catalog, content_set.p9g, raw_sha256)
			local anchor_successor = r7_anchor_activation_factory(
				r7_anchor_roster_factory, content_set.anchors)
			successor = r7_successor_factory(p9g_successor, anchor_successor)
		end
		local authored_source = dofile(wp40_directory .. "/source/catalog.lua")
		local consumer_payload = consumer_payload_factory(source,
			authored_source, sha256_hex)
		authored_source = nil
		local constructor, session, writer, zones_session, settlement_fixture,
			r6_identity, anchor_roster
		if authority_only then
			zones_session, r6_identity = r6_module.new_authority(full_seed, 1,
				r6_manifest, content_set.production, mapgen_context, projection,
				template_source, cultural)
			if type(zones_session) ~= "table" or type(r6_identity) ~= "table" or
					r6_identity.schema ~= "grug_wp40_r6_authority_identity_v1" or
					type(r6_identity.planner_source) ~= "table" or
					type(r6_identity.planner_source.column_values_at) ~= "function" then
				fail("R6 authority identity differs")
			end
			anchor_roster = r7_anchor_roster_factory(source, zones_session,
				r6_identity.planner_source, raw_sha256)
		else
			if evidence_mode == "horizontal" then constructor = r6_module.new_evidence
			elseif evidence_mode == true then constructor = r6_module.new_capture
			-- Offline evidence keeps the exhaustive constructors. The live callback
			-- builds only the query/writer state needed to generate actual mapblocks.
			else constructor = r6_module.new_runtime end
			session, writer, zones_session, settlement_fixture, r6_identity =
				constructor(full_seed, 1,
				r6_manifest, content_set.production, mapgen_context, projection,
				template_source, cultural, successor)
			if type(session) ~= "table" or type(writer) ~= "table" or
					type(zones_session) ~= "table" then
				fail("production session assembly differs")
			end
			if type(r6_identity) ~= "table" or
					r6_identity.schema ~= "grug_wp40_r6_private_identity_v1" or
					type(r6_identity.planner_source) ~= "table" or
					type(r6_identity.planner_source.column_values_at) ~= "function" then
				fail("R6 private identity differs")
			end
			if type(r6_identity.successor_tail) ~= "table" or
					type(r6_identity.successor_tail.anchor_roster) ~= "function" then
				fail("R7 anchor successor identity differs")
			end
			anchor_roster = r6_identity.successor_tail:anchor_roster()
			local independent_roster = r7_anchor_roster_factory(source, zones_session,
				r6_identity.planner_source, raw_sha256)
			if anchor_roster.sha256 ~= independent_roster.sha256 then
				fail("R7 anchor roster reconstruction differs")
			end
		end
		local public_zones_session = r7_zone_overlay_factory(zones_session, anchor_roster)
		local manifest = r7_manifest_module.new({full_seed = full_seed,
			r5_manifest = r6_manifest.r5_manifest_values,
			r5_manifest_module = r5_manifest_module, r6_manifest = r6_manifest,
			wp43_projection = projection,
			accepted_r6_rows = content_set.accepted_r6_rows(),
			native_identities = native_identities,
			gathering_manifest = gathering_manifest,
			production_content = {schema = content_set.production.schema,
				digest = content_set.production_digest,
				semantic_digest = content_set.production_semantic_digest},
			p9g_content = {schema = content_set.p9g.schema,
				digest = content_set.p9g_digest,
				semantic_digest = content_set.p9g_semantic_digest},
			anchor_content = {schema = content_set.anchors.schema,
				digest = content_set.anchor_digest,
				semantic_digest = content_set.anchor_semantic_digest},
			anchor_roster = anchor_roster.copy_rows(),
			anchor_roster_sha256 = anchor_roster.sha256,
			cultural_registrations = cultural,
			decoded_templates = r6_identity.template_records,
			consumer_payload = consumer_payload})
		r7_manifest_module.validate(manifest, expected_manifest_sha256)
		if authority_only then
			return {schema = "grug_wp40_r7_authority_runtime_v1",
				full_seed = full_seed, manifest = manifest,
				zones_session = public_zones_session, content = content_set,
				anchor_roster = anchor_roster, consumer_payload = consumer_payload,
				mapgen_context = mapgen_context}
		end
		local direct_session, direct_fixture, direct_identity
		if evidence_mode == true then
			local ignored_writer, ignored_zones
			direct_session, ignored_writer, ignored_zones, direct_fixture, direct_identity =
				constructor(full_seed, 1,
				r6_manifest, content_set.production, mapgen_context, projection,
				template_source, cultural)
		elseif evidence_mode == "horizontal" then
			direct_fixture = r6_identity.direct_evidence_fixture
			direct_identity = r6_identity
		end
		local evidence
		if evidence_mode then
			local function scan(fixture, identity, owner_x, owner_z)
				if type(fixture) ~= "table" or type(identity) ~= "table" or
						type(identity.planner_fixture) ~= "table" then
					fail("evidence facade authority differs")
				end
				local cultural_candidates, decoration_candidates = {}, {}
				local groups, coverage, column_count = {}, {}, 0
				for cell_z = owner_z / 16, owner_z / 16 + 4 do
					for cell_x = owner_x / 16, owner_x / 16 + 4 do
						local cultural_rows, decoration_rows, cell_groups, cell_coverage,
							cell_columns = identity.planner_fixture.build_cell(cell_x, cell_z)
						column_count = column_count + cell_columns
						for index = 1, #cultural_rows do
							cultural_candidates[#cultural_candidates + 1] = cultural_rows[index]
						end
						for index = 1, #decoration_rows do
							decoration_candidates[#decoration_candidates + 1] =
								decoration_rows[index]
						end
						for index = 1, #cell_groups do groups[#groups + 1] = cell_groups[index] end
						for index = 1, #cell_coverage do
							coverage[#coverage + 1] = cell_coverage[index]
						end
					end
				end
				return {schema = "grug_wp40_r7_horizontal_owner_evidence_v1",
					owner_x = owner_x, owner_z = owner_z, column_count = column_count,
					groups = groups, coverage = coverage,
					candidates = {cultural = cultural_candidates,
						decorations = decoration_candidates},
					settlement = fixture.scan_horizontal_owner(owner_x, owner_z,
						cultural_candidates, decoration_candidates)}
			end
			evidence = {schema = "grug_wp40_r7_private_evidence_v1"}
			function evidence.scan_owner(owner_x, owner_z)
				return scan(settlement_fixture, r6_identity, owner_x, owner_z)
			end
			function evidence.scan_direct_owner(owner_x, owner_z)
				return scan(direct_fixture, direct_identity, owner_x, owner_z)
			end
			function evidence.probe_p9g_reason(context, catalog_index, x, y, z)
				if type(r6_identity.successor_tail) ~= "table" or
						type(r6_identity.successor_tail.probe_reason) ~= "function" then
					fail("P9G probe authority differs")
				end
				return r6_identity.successor_tail:probe_reason(context, catalog_index,
					x, y, z)
			end
		end
		return {schema = "grug_wp40_r7_runtime_v1", full_seed = full_seed,
			manifest = manifest, session = session, writer = writer,
			zones_session = public_zones_session, content = content_set,
			anchor_roster = anchor_roster,
			consumer_payload = consumer_payload,
			mapgen_context = mapgen_context,
			settlement_fixture = settlement_fixture,
			direct_session = direct_session, direct_fixture = direct_fixture,
			evidence = evidence}
	end

	function module.build(...)
		return build(...)
	end
	function module.build_authority(native_identities, expected_manifest_sha256)
		return build(native_identities, expected_manifest_sha256, nil, true)
	end

	return module
end
