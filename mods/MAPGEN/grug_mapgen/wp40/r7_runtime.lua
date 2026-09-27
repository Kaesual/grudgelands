-- Shared production R7 assembly. Main and emerge load these same pure source
-- bytes and rebuild the live content and semantic manifest. Emerge takes the
-- layout texts and the identities of the lazy blueprints from main (see
-- `prepared_handover` below); its own check of a lazy blueprint is the
-- per-blueprint rebuild at first touch (`r7_settlement.lua` config,
-- `cells_of`), not a second preparation at load.

-- `water_layout_text`, `road_layout_text` and `capital_layout_text` are the
-- serialized inland water, road and capital layouts main built and handed
-- over (emerge), or main's own from the world-folder layout cache on a later
-- boot (`layout_cache.lua`, plan D71); nil in main on a world's first start,
-- which builds them (plan D37, D60).
--
-- `prepared_handover` (emerge only): main's preparations of every LAZY
-- blueprint that has cells, keyed by manifest prefix (`module.
-- prepared_handover`), so emerge does not build and hash every capital plot
-- a second time at load. Each one's cells are rebuilt on the first mapchunk
-- that touches it and checked there against main's identity and landmarks
-- (`r7_settlement.lua` config); nil in main.
return function(core_api, wp40_directory, schematic_directory, projection, catalog,
		water_layout_text, road_layout_text, capital_layout_text, prepared_handover)
	local function fail(message)
		error("WP40 R7 runtime: " .. message, 0)
	end

	if type(core_api) ~= "table" or type(core_api.sha256) ~= "function" or
			type(core_api.get_mapgen_setting) ~= "function" or
			type(wp40_directory) ~= "string" or wp40_directory == "" or
			type(schematic_directory) ~= "string" or schematic_directory == "" or
			type(projection) ~= "table" or type(catalog) ~= "table" or
			(water_layout_text ~= nil and type(water_layout_text) ~= "string") or
			(road_layout_text ~= nil and type(road_layout_text) ~= "string") or
			(capital_layout_text ~= nil and type(capital_layout_text) ~= "string") or
			((road_layout_text == nil) ~= (capital_layout_text == nil)) or
			(prepared_handover ~= nil and (type(prepared_handover) ~= "table" or
				capital_layout_text == nil)) then
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

	local function flag_set(name, expected, expected_raw)
		local raw = core_api.get_mapgen_setting(name)
		if type(raw) ~= "string" then fail("mapgen flag setting " .. name .. " differs") end
		if expected_raw ~= nil and raw ~= expected_raw then
			fail("mapgen flag setting " .. name .. " canonical form differs: " .. raw)
		end
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
		if count ~= expected_count then
			fail("mapgen flag population differs for " .. name .. ": " .. raw)
		end
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
			caverns = true, nofloatlands = true},
			"mountains, ridges, nofloatlands, caverns")
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
	-- The capitals' protected cities (plan D76) are a function of the capital
	-- layouts, which main plans after the first horizontal session exists; every
	-- horizontal session this runtime builds shares this holder, filled below
	-- once the layouts are parsed (before any claim or protection query).
	local capital_protection = dofile(wp40_directory .. "/capital_protection.lua")
	local protection_holder = {}
	local simple_map_factory = dofile(wp40_directory .. "/simple_map.lua")(
		dofile(wp40_directory .. "/zone_field.lua"))
	local function horizontal_factory(dependencies)
		local bound = {}
		for key, value in pairs(dependencies) do bound[key] = value end
		bound.capital_protection = protection_holder
		return simple_map_factory(bound)
	end
	local terrain_data = dofile(wp40_directory .. "/terrain_data.lua")
	local terrain_field = dofile(wp40_directory .. "/terrain_field.lua")(terrain_data)
	-- Inland water: one layout per environment, shared by every height session
	-- this runtime builds (main builds it once, emerge deserializes main's).
	local water = {module = dofile(wp40_directory .. "/water_layout.lua")(
		terrain_data.water), text = water_layout_text,
		-- the planned canals are appended below, before any world session
		authored = dofile(wp40_directory .. "/water_authored.lua")(terrain_data.water)}
	-- Roads (Round 22 Phase 4): one layout per environment like the water,
	-- routed once in main after it, deserialized in emerge.
	-- The capital planner's streets and connectors join this layout (main:
	-- `height.lua` add_roads; emerge: already in the text), its squares are
	-- set below from the capital layouts.
	local roads = {module = dofile(wp40_directory .. "/road_layout.lua"),
		text = road_layout_text}
	-- Main plans the capitals on a height session of its own before the world
	-- is built; that session (streets and canals added, memos flushed) is
	-- handed to the world build's first height session request instead of
	-- building a second one (`height.lua` new_runtime).
	local reuse = {}
	local height_module_factory = dofile(wp40_directory .. "/height.lua")
	local function height_factory(dependencies)
		local bound = {}
		for key, value in pairs(dependencies) do bound[key] = value end
		bound.water = water
		bound.roads = roads
		bound.reuse = reuse
		return height_module_factory(bound)
	end
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
	local world_catalog = dofile(wp40_directory .. "/world_content_catalog.lua")
	local habitat_registry = dofile(wp40_directory .. "/habitat_registry.lua")
	local world_factory = dofile(wp40_directory .. "/world_content.lua")
	local consumer_payload_factory = dofile(
		wp40_directory .. "/r7_consumer_payload.lua")
	local r7_manifest_factory = dofile(wp40_directory .. "/r7_manifest.lua")
	local r7_p9g_factory = dofile(wp40_directory .. "/r7_p9g.lua")
	local r7_anchor_roster_factory = dofile(
		wp40_directory .. "/r7_anchor_roster.lua")
	local r7_anchor_activation_factory = dofile(
		wp40_directory .. "/r7_anchor_activation.lua")
	local r7_settlement_module = dofile(wp40_directory .. "/r7_settlement.lua")
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
		terrain_field = terrain_field,
		raw_sha256 = raw_sha256, hash_factory = hash_factory,
		content_factory = r6_content_factory, templates_factory = r6_templates_factory,
		planner_factory = r6_planner_factory, settlement_factory = r6_settlement_factory})
	if type(r6_module.new_runtime) ~= "function" or
			type(r6_module.new_authority) ~= "function" then
		fail("R6 runtime constructor differs")
	end
	local r6_manifest = r7_r6_manifest()
	local template_source = template_source_factory(core_api, schematic_directory,
		wp40_directory .. "/../../../ITEMS/grug_trees/schematics")
	-- Every WP13 settlement, in the fixed roster order, plus the sorted ASCII
	-- union of every blueprint's palette: one opcode-37 content channel serves
	-- them all, so a cell's content ref is an index into this union.
	--
	-- `prepare` is where main BUILDS every blueprint once and hashes it. A lazy
	-- settlement's cells are released again straight away (contract section
	-- 2.2.4): what has to exist at load is the identity the manifest publishes
	-- and the palette the channel is closed over, and neither of them is a
	-- 100,000-cell buffer. Emerge builds only the starts and the city edge
	-- overlays here; every other blueprint's preparation comes from main's
	-- handover and is checked when its cells are first rebuilt.
	--
	-- THE SEED IS VALIDATED HERE ONCE. The capital layouts are a function of it
	-- (main plans them from it; emerge takes main's text), and `build` refuses
	-- to run if its own validation answers anything else, so both environments
	-- agree about where a capital stands exactly when they agree about
	-- `full_seed`, the check `r7_mapgen.lua` makes.
	local construction_seed = validate_live_scalars()
	local blueprint_options = {full_seed = construction_seed,
		raw_sha256 = raw_sha256}

	-- THE CAPITAL LAYOUTS (Round 22 capital planner, plan D60, D69-D73).
	-- Every capital's plots are prepared first (identity and bounds do not
	-- depend on where a plot stands); main then plans the six capitals on a
	-- height session of its own, after height, water and roads, and both
	-- environments build the capitals from the parsed payload text.
	local capitals = dofile(wp40_directory .. "/r7_capitals.lua")(wp40_directory)
	local capital_profiles, capital_kits, capital_plots = {}, {}, {}
	for index = 1, #r7_settlement_module.roster do
		local profile = r7_settlement_module.roster[index]
		if profile.slot == "capital" then
			capital_profiles[#capital_profiles + 1] = profile
			local kit = capitals.source.kit(profile.key)
			capital_kits[profile.key] = kit
			if capital_layout_text == nil then
				for _, plot in ipairs(kit.plots) do
					capital_plots[profile.key .. "_" .. plot.id] =
						r7_settlement_module.prepare_plot(profile, plot, raw_sha256)
				end
			end
		end
	end
	-- CPU seconds of main's layout builds (nil when the texts came in: emerge,
	-- or main on a world-folder cache hit), for the cache's log line.
	local capital_stats, layout_seconds
	if capital_layout_text == nil then
		local planning_horizontal = horizontal_factory({source = source,
			schemas = schemas, canonical = canonical, deterministic = deterministic,
			raw_sha256 = raw_sha256}).new(construction_seed)
		local planning_session = height_factory({source = source,
			canonical = canonical, deterministic = deterministic,
			raw_sha256 = raw_sha256, horizontal_session = planning_horizontal,
			terrain_field = terrain_field}).new_runtime(construction_seed)
		-- The canal rows plan_all returns are not needed here: it already
		-- hands them to the planning session, and the rows below are
		-- re-derived from the layout text like in emerge.
		local _
		capital_layout_text, _, capital_stats = capitals.plan_all({
			seed = construction_seed, session = planning_session,
			roads = roads.module, anchors = source.anchors,
			profiles = capital_profiles, kits = capital_kits,
			prepared = capital_plots, authored = water.authored,
			simplex = terrain_field.simplex, proxy = terrain_data.water.LAKE_PROXY})
		reuse.session, reuse.seed = planning_session, construction_seed
		local capitals_seconds = 0
		for _, st in ipairs(capital_stats) do capitals_seconds = capitals_seconds + st.seconds end
		local water_stats = water.cache and water.cache.stats
		local road_stats = roads.cache and roads.cache.layout and roads.cache.layout.stats
		layout_seconds = {water = water_stats and water_stats.t_total or 0,
			roads = road_stats and road_stats.t_total or 0, capitals = capitals_seconds}
	end
	local capital_layouts = capitals.parse(capital_layout_text)
	-- the protected cities (plan D76), each with its civic lake if it has one
	local civic_lakes = {}
	for _, profile in ipairs(capital_profiles) do
		local lake_id = capital_kits[profile.key].cfg.lake
		if lake_id then
			for _, row in ipairs(water.authored) do
				if row.id == lake_id then civic_lakes[profile.anchor_id] = row end
			end
			if not civic_lakes[profile.anchor_id] then
				fail("civic lake missing: " .. lake_id)
			end
		end
	end
	capital_protection.install(protection_holder, capital_layouts, civic_lakes)
	local all_squares = {}
	for _, profile in ipairs(capital_profiles) do
		local entry = capital_layouts[profile.anchor_id]
		if not entry then fail("capital layout missing: " .. profile.key) end
		if entry.layout.anchor.x ~= profile.x or entry.layout.anchor.z ~= profile.z then
			fail("capital layout anchor differs: " .. profile.key)
		end
		if entry.layout.canal then
			water.authored[#water.authored + 1] = capitals.canal_row(
				"canal_" .. profile.key, entry.layout.anchor, entry.layout.canal,
				terrain_data.water.LAKE_PROXY)
		end
		for _, q in ipairs(capitals.squares(entry.layout)) do
			all_squares[#all_squares + 1] = q
		end
	end
	if road_layout_text ~= nil then roads.squares = all_squares end
	local settlements = {}
	local settlement_palette, settlement_seen = {}, {}
	local settlement_keys, settlement_order = {}, {}
	for index = 1, #r7_settlement_module.roster do
		local profile = r7_settlement_module.roster[index]
		local source
		if profile.slot == "capital" then
			local entry = capital_layouts[profile.anchor_id]
			source = capitals.source.source(profile.key, entry.layout, entry.text,
				capital_kits[profile.key])
		else
			source = dofile(wp40_directory .. "/" .. profile.blueprint_file)(
				blueprint_options, profile)
			if type(source) == "function" then source = source(blueprint_options) end
		end
		if profile.slot=="start" then
			source=dofile(wp40_directory.."/r20_civic.lua")(source,profile)
		end
		local prepared = r7_settlement_module.prepare(profile, source, raw_sha256,
			prepared_handover or capital_plots)
		settlements[index] = {profile = profile, prepared = prepared}
		settlement_keys[index] = profile.key
		local blueprints = {}
		for blueprint_index = 1, #prepared.blueprints do
			local blueprint = prepared.blueprints[blueprint_index]
			blueprints[blueprint_index] = {id = blueprint.descriptor.id,
				prefix = blueprint.descriptor.prefix,
				kind = blueprint.descriptor.kind,
				identity_schema = blueprint.descriptor.identity_schema,
				bounds = blueprint.descriptor.bounds}
		end
		settlement_order[index] = {key = profile.key, anchor_id = profile.anchor_id,
			delta_schema = profile.delta_schema, blueprints = blueprints}
		for palette_index = 1, #prepared.palette do
			local name = prepared.palette[palette_index]
			if not settlement_seen[name] then
				settlement_seen[name] = true
				settlement_palette[#settlement_palette + 1] = name
			end
		end
	end
	-- Byte order, never Lua's locale-dependent `<`: `r7_content.lua` accepts
	-- this union only if it is sorted the way IT compares names.
	table.sort(settlement_palette, r7_settlement_module.less_bytes)
	-- Emerge: main's handover must hold exactly this roster's lazy cell
	-- blueprints, one record each, so none of them was prepared here.
	if prepared_handover ~= nil then
		local expected = {}
		for index = 1, #settlements do
			local prepared = settlements[index].prepared
			if prepared.profile.lazy then
				for blueprint_index = 1, #prepared.blueprints do
					local descriptor = prepared.blueprints[blueprint_index].descriptor
					if descriptor.kind ~= "overlay" then expected[descriptor.prefix] = true end
				end
			end
		end
		for prefix in pairs(prepared_handover) do
			if not expected[prefix] then fail("prepared handover differs: " .. tostring(prefix)) end
			expected[prefix] = nil
		end
		local missing = next(expected)
		if missing then fail("prepared handover lacks " .. missing) end
	end
	-- The manifest's field order and settlement order are derived from the
	-- roster (contract section 2.2.2) and therefore constructed here, with the
	-- roster in hand, not typed inside the manifest.
	local r7_manifest_module = r7_manifest_factory(canonical, raw_sha256,
		settlement_order)

	local module = {}
	-- The water, road and capital layout texts this environment's sessions
	-- sample, as one digest. The full-world preparation identity binds it, so
	-- its "authority changed" guard fires exactly when a world's layouts
	-- change, wherever they came from (a fresh build or the world-folder
	-- cache, plan D71).
	local function layouts_digest()
		if not water.cache or type(water.cache.text) ~= "string" or not roads.cache or
				type(roads.cache.text) ~= "string" or type(capital_layout_text) ~= "string" then
			fail("layout texts missing for the preparation identity")
		end
		return sha256_hex(sha256_hex(water.cache.text) .. ":" ..
			sha256_hex(roads.cache.text) .. ":" .. sha256_hex(capital_layout_text))
	end
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
		-- The blueprints were built against `construction_seed`, and a
		-- capital's district offsets are a function of it. If the live seed
		-- has moved since, every offset in this environment is stale and the
		-- cross-environment comparison of `full_seed` would not notice.
		if full_seed ~= construction_seed then
			fail("the world seed moved after the blueprints were built")
		end
		local content_set = r7_content_factory(core_api, projection, raw_sha256,
			settlement_palette)
		local settlement_configs, settlement_identities = {}, {}
		for index = 1, #settlements do
			local row = settlements[index]
			local settlement_config = r7_settlement_module.config(row.prepared,
				content_set.settlement, raw_sha256)
			settlement_configs[index] = settlement_config
			settlement_identities[index] = {key = row.profile.key,
				anchor_id = row.profile.anchor_id,
				delta_schema = row.profile.delta_schema,
				blueprints = settlement_config.identities}
		end
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
			local p9g_successor = r7_p9g_factory(catalog, content_set.p9g, raw_sha256,
				habitat_registry)
			local anchor_successor = r7_anchor_activation_factory(
				r7_anchor_roster_factory, content_set.anchors)
			successor = r7_successor_factory(p9g_successor, anchor_successor,
				settlement_configs, settlement_keys,
				world_factory(world_catalog, content_set.p9g, habitat_registry),
				dofile(wp40_directory .. "/road_writer.lua")(core_api))
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
			world_content_rules = world_catalog,
			p9g_content = {schema = content_set.p9g.schema,
				digest = content_set.p9g_digest,
				semantic_digest = content_set.p9g_semantic_digest},
			anchor_content = {schema = content_set.anchors.schema,
				digest = content_set.anchor_digest,
				semantic_digest = content_set.anchor_semantic_digest},
			settlement_content = {schema = content_set.settlement.schema,
				digest = content_set.settlement_digest,
				semantic_digest = content_set.settlement_semantic_digest,
				count = #content_set.settlement.content_names},
			settlement_blueprints = settlement_identities,
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
				-- The pure column query, published so the load-time socket export
				-- can ask the final height of a district plot's reference column
				-- with the same function the writer projects that plot with.
				planner_source = r6_identity.planner_source,
				preparation_source = dofile(wp40_directory .. "/preparation_source.lua")(
					r6_identity.planner_source, r6_identity.template_records, cultural,
					settlements, public_zones_session, anchor_roster,
					full_seed .. ":" .. manifest.values.source_projection_sha256 .. ":" ..
						dofile(wp40_directory .. "/preparation_identity.lua")(
							wp40_directory, core_api.sha256) .. ":" .. layouts_digest(),
					core_api.sha256),
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

	-- The authored WP13 NPC sockets of every settlement, in roster order, with
	-- the fitted anchor they are relative to. Read off the blueprints this
	-- factory already prepared: sockets are landmarks, not identity bytes, so
	-- nothing here enters a digest, and a second construction would cost every
	-- composition again for pure landmark data.
	--
	-- `built` is what `build_authority` returned. A capital plot's sockets are
	-- turned and lifted with the plot (its layout's turns and base height, the
	-- ones the writer projects the cells with); `r7_settlement.M.sockets` owns
	-- that correction.
	function module.settlement_sockets(built)
		if type(built) ~= "table" or type(built.zones_session) ~= "table" or
				type(built.zones_session.anchor) ~= "function" then
			fail("settlement socket authority differs")
		end
		local rows = {}
		for index = 1, #settlements do
			local row = settlements[index]
			local profile = row.profile
			local anchor = built.zones_session.anchor(profile.zone_id, profile.slot)
			if type(anchor) ~= "table" or anchor.id ~= profile.anchor_id or
					type(anchor.y) ~= "number" then
				fail("settlement socket anchor differs: " .. profile.key)
			end
			rows[index] = {key = profile.key, label = profile.label, race = profile.race,
				slot = profile.slot, zone_id = profile.zone_id, anchor = anchor,
				sockets = r7_settlement_module.sockets(row.prepared, anchor)}
		end
		return rows
	end

	-- Every placed capital plot whose ground this world's final terrain does
	-- not actually support, in roster order (a log diagnostic: the planner
	-- placed it on its own sample, before the streets' cut and fill).
	-- `r7_settlement.audit_terrain` is the rule.
	function module.settlement_terrain_findings(built)
		if type(built) ~= "table" or type(built.zones_session) ~= "table" or
				type(built.zones_session.anchor) ~= "function" or
				type(built.planner_source) ~= "table" or
				type(built.planner_source.column_values_at) ~= "function" then
			fail("settlement terrain authority differs")
		end
		local rows = {}
		for index = 1, #settlements do
			local row = settlements[index]
			local profile = row.profile
			local anchor = built.zones_session.anchor(profile.zone_id, profile.slot)
			if type(anchor) ~= "table" or anchor.id ~= profile.anchor_id then
				fail("settlement terrain anchor differs: " .. profile.key)
			end
			local findings = r7_settlement_module.audit_terrain(row.prepared,
				anchor, built.planner_source.column_values_at)
			for finding_index = 1, #findings do
				local finding = findings[finding_index]
				finding.settlement = profile.key
				rows[#rows + 1] = finding
			end
		end
		return rows
	end

	function module.build(...)
		return build(...)
	end
	-- Main only: the plain-data preparations of every lazy cell blueprint,
	-- keyed by manifest prefix, for the ipc_set payload (emerge passes them
	-- back in as `prepared_handover`; `r7_settlement.handover`).
	function module.prepared_handover()
		if prepared_handover ~= nil then fail("emerge hands nothing over") end
		local out = {}
		for index = 1, #settlements do
			r7_settlement_module.handover(settlements[index].prepared, out)
		end
		return out
	end
	-- The serialized water layout of the last built session (main hands it to
	-- emerge through ipc_set).
	function module.water_layout_text()
		if not water.cache or type(water.cache.text) ~= "string" then
			fail("water layout was never built")
		end
		return water.cache.text
	end
	-- River centrelines of that layout for drawing (the world map).
	function module.river_polylines()
		if not water.cache or not water.cache.sampler then
			fail("water layout was never built")
		end
		return water.cache.sampler.polylines()
	end
	-- The serialized capital layouts (main hands them to emerge through
	-- ipc_set) and main's planner statistics (nil in emerge).
	function module.capital_layout_text()
		return capital_layout_text
	end
	function module.capital_stats()
		return capital_stats
	end
	-- Main's layout build CPU seconds {water, roads, capitals}; nil when the
	-- layout texts were handed in.
	function module.layout_build_seconds()
		return layout_seconds
	end
	-- The serialized road layout of the last built session (main hands it to
	-- emerge through ipc_set).
	function module.road_layout_text()
		if not roads.cache or type(roads.cache.text) ~= "string" then
			fail("road layout was never built")
		end
		return roads.cache.text
	end
	-- Road and trail centrelines for drawing (the world map).
	function module.road_polylines()
		if not roads.cache then fail("road layout was never built") end
		return roads.module.polylines(roads.module.deserialize(roads.cache.text))
	end
	-- Main only: the built network layout (statistics, showcase spots); the
	-- capital streets are in the text, not here.
	function module.road_layout()
		return roads.cache and roads.cache.layout or nil
	end
	function module.road_module()
		return roads.module
	end
	function module.build_authority(native_identities, expected_manifest_sha256)
		return build(native_identities, expected_manifest_sha256, nil, true)
	end

	return module
end
