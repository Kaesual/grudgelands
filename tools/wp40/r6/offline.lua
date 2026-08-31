-- Engine-free constructor for disabled WP40 R6 sessions and tool seams.

return function(repo)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()
	local fixtures = dofile(repo .. "/tools/wp40/r6/fixtures.lua")(
		repo, common, raw_sha256)
	local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local source = dofile(directory .. "/source/simple_map.lua")
	local schemas = dofile(directory .. "/schemas.lua")
	local canonical = dofile(directory .. "/canonical.lua")
	local deterministic = dofile(directory .. "/deterministic.lua")
	local index128 = dofile(directory .. "/index128.lua")
	local horizontal_factory = dofile(directory .. "/simple_map.lua")
	local height_factory = dofile(directory .. "/height.lua")
	local zones_factory = dofile(directory .. "/zones.lua")
	local r5_planner_factory = dofile(directory .. "/planner.lua")
	local r5_adapter_factory = dofile(directory .. "/map_adapter.lua")
	local manifest_module = dofile(directory .. "/mapgen_manifest.lua")
	local allocator_factory = dofile(directory .. "/counting_allocator.lua")
	local r5_factory = dofile(directory .. "/r5.lua")
	local hash_factory = dofile(directory .. "/r6_hash.lua")
	local content_factory = dofile(directory .. "/r6_content.lua")
	local templates_factory = dofile(directory .. "/r6_templates.lua")
	local planner_factory = dofile(directory .. "/r6_planner.lua")
	local settlement_factory = dofile(directory .. "/r6_settlement.lua")
	local r6_factory = dofile(directory .. "/r6.lua")
	local vm_module = dofile(repo .. "/tools/wp40/simple_map_r5_vm.lua")
	local seed_corpus = dofile(directory .. "/seed_corpus.lua")

	local r5_module = r5_factory({zones_factory = zones_factory,
		planner_factory = r5_planner_factory, adapter_factory = r5_adapter_factory,
		manifest_module = manifest_module, allocator_factory = allocator_factory,
		source = source, schemas = schemas, canonical = canonical,
		deterministic = deterministic, index128 = index128,
		horizontal_factory = horizontal_factory, height_factory = height_factory,
		raw_sha256 = raw_sha256})
	local r6_module = r6_factory({r5_factory = r5_factory,
		zones_factory = zones_factory, r5_planner_factory = r5_planner_factory,
		r5_adapter_factory = r5_adapter_factory, manifest_module = manifest_module,
		allocator_factory = allocator_factory, source = source, schemas = schemas,
		canonical = canonical, deterministic = deterministic, index128 = index128,
		horizontal_factory = horizontal_factory, height_factory = height_factory,
		raw_sha256 = raw_sha256, hash_factory = hash_factory,
		content_factory = content_factory, templates_factory = templates_factory,
		planner_factory = planner_factory, settlement_factory = settlement_factory})

	local loader = {repo = repo, common = common, fixtures = fixtures,
		raw_sha256 = raw_sha256, seed_corpus = seed_corpus,
		source = source, schemas = schemas, canonical = canonical,
		deterministic = deterministic, index128 = index128,
		vm_module = vm_module, r6_module = r6_module}

	local function new_heightmap(value)
		local result = {}
		for index = 1, 6400 do result[index] = value end
		return result
	end

	function loader.new_public(seed, heightmap, with_cultural)
		local contract, cid_by_name, ref_by_name = fixtures.new_content_contract()
		local cultural_records = with_cultural and
			fixtures.cultural_records(r6_module) or {}
		local context = fixtures.context(heightmap or new_heightmap(-31007))
		local session = r6_module.new(seed, 1, fixtures.r6_manifest(), contract,
			context, fixtures.projection(), fixtures.template_source(), cultural_records)
		return {session = session, content_contract = contract,
			cid_by_name = cid_by_name, ref_by_name = ref_by_name,
			context = context, cultural_records = cultural_records}
	end

	function loader.new_capture(seed, heightmap, with_cultural)
		local contract, cid_by_name, ref_by_name = fixtures.new_content_contract()
		local cultural_records = with_cultural and
			fixtures.cultural_records(r6_module) or {}
		local context = fixtures.context(heightmap or new_heightmap(-31007))
		local session, _, zones_session, settlement_fixture = r6_module.new_capture(seed, 1,
			fixtures.r6_manifest(), contract, context, fixtures.projection(),
			fixtures.template_source(), cultural_records)
		return {session = session, content_contract = contract,
			cid_by_name = cid_by_name, ref_by_name = ref_by_name,
			context = context, cultural_records = cultural_records,
			zones_session = zones_session, settlement_fixture = settlement_fixture}
	end

	function loader.new_internal(seed, heightmap, with_cultural, need_settlement)
		local contract, cid_by_name, ref_by_name = fixtures.new_content_contract()
		local context = fixtures.context(heightmap or new_heightmap(-31007))
		local hash = hash_factory(raw_sha256)
		local content = content_factory(fixtures.r6_manifest(), contract,
			fixtures.projection())
		local templates = templates_factory(hash, content, fixtures.template_source())
		local cultural_records = with_cultural and
			fixtures.cultural_records(r6_module) or {}
		for index = 1, #cultural_records do
			for cell = 1, #cultural_records[index].cells do
				cultural_records[index].cells[cell].content_ref =
					assert(content.content_ref(cultural_records[index].cells[cell].node))
			end
		end
		local _, planner_source, r5_planner, r5_adapter = r5_module.new(seed, 1,
			fixtures.r5_manifest(), contract.r5, context)
		local horizontal = horizontal_factory({source = source, schemas = schemas,
			canonical = canonical, deterministic = deterministic,
			raw_sha256 = raw_sha256}).new(seed)
		local identity = {value = false}
		local planner_allocator = allocator_factory.new(
			"grug_wp40_r6_planner_allocator_v1")
		local planner, planner_fixture = planner_factory.new({full_seed_string = seed,
			planner_source = planner_source, r5_planner = r5_planner,
			horizontal = horizontal, content = content, templates = templates,
			hash = hash, source = source, construction_identity = identity,
			counting_allocator = planner_allocator})
		local settlement, settlement_fixture
		if need_settlement ~= false then
			local settlement_allocator = allocator_factory.new(
				"grug_wp40_r6_settlement_allocator_v1")
			settlement, settlement_fixture = settlement_factory.new({
				full_seed_string = seed, r5_adapter = r5_adapter, content = content,
				templates = templates, hash = hash, horizontal = horizontal,
				planner_source = planner_source, construction_identity = identity,
				cultural_registrations = cultural_records, source = source,
				counting_allocator = settlement_allocator})
		end
		return {planner = planner, planner_fixture = planner_fixture,
			settlement = settlement, settlement_fixture = settlement_fixture,
			content = content, templates = templates, hash = hash,
			content_contract = contract, cid_by_name = cid_by_name,
			ref_by_name = ref_by_name, context = context, horizontal = horizontal,
			planner_source = planner_source, r5_planner = r5_planner,
			r5_adapter = r5_adapter, cultural_records = cultural_records}
	end

	function loader.new_static()
		local contract, cid_by_name, ref_by_name = fixtures.new_content_contract()
		local hash = hash_factory(raw_sha256)
		local content = content_factory(fixtures.r6_manifest(), contract,
			fixtures.projection())
		local templates = templates_factory(hash, content, fixtures.template_source())
		return {hash = hash, content = content, templates = templates,
			content_contract = contract, cid_by_name = cid_by_name,
			ref_by_name = ref_by_name}
	end

	-- Lightweight exhaustive lane: it uses the production R6 candidate core but
	-- does not construct R5's VM-sized planner/adapter buffers. It never calls
	-- plan_slice or settlement and therefore cannot become a second world writer.
	function loader.new_evidence(seed, with_cultural)
		if with_cultural ~= nil and type(with_cultural) ~= "boolean" then
			common.fail("evidence Cultural mode differs")
		end
		local contract, cid_by_name, ref_by_name = fixtures.new_content_contract()
		local hash = hash_factory(raw_sha256)
		local content = content_factory(fixtures.r6_manifest(), contract,
			fixtures.projection())
		local templates = templates_factory(hash, content, fixtures.template_source())
		local zones_module = zones_factory({source = source, schemas = schemas,
			canonical = canonical, deterministic = deterministic, index128 = index128,
			horizontal_factory = horizontal_factory, height_factory = height_factory,
			raw_sha256 = raw_sha256})
		local _, planner_source = zones_module.new_with_planner_source(seed, 1)
		local horizontal = horizontal_factory({source = source, schemas = schemas,
			canonical = canonical, deterministic = deterministic,
			raw_sha256 = raw_sha256}).new(seed)
		local unavailable = {plan_slice = function()
			common.fail("evidence-only planner cannot plan a VM slice")
		end}
		local planner_allocator = allocator_factory.new(
			"grug_wp40_r6_planner_allocator_v1")
		local planner, planner_fixture = planner_factory.new_evidence({full_seed_string = seed,
			planner_source = planner_source, r5_planner = unavailable,
			horizontal = horizontal, content = content, templates = templates,
			hash = hash, source = source, construction_identity = {value = false},
			counting_allocator = planner_allocator})
		local cultural_records = with_cultural and
			fixtures.cultural_records(r6_module) or {}
		for index = 1, #cultural_records do
			for cell = 1, #cultural_records[index].cells do
				cultural_records[index].cells[cell].content_ref =
					assert(content.content_ref(cultural_records[index].cells[cell].node))
			end
		end
		local settlement_allocator = allocator_factory.new(
			"grug_wp40_r6_settlement_allocator_v1")
		local settlement, settlement_fixture = settlement_factory.new_evidence({
			full_seed_string = seed, r5_adapter = {apply = function()
				common.fail("evidence-only settlement cannot invoke the R5 adapter")
			end}, content = content, templates = templates, hash = hash,
			horizontal = horizontal, planner_source = planner_source,
			construction_identity = {value = false},
			cultural_registrations = cultural_records, source = source,
			counting_allocator = settlement_allocator,
			planner_stable_refs = planner_fixture.stable_refs()})
		return {planner = planner, planner_fixture = planner_fixture,
			settlement = settlement, settlement_fixture = settlement_fixture,
			planner_source = planner_source, horizontal = horizontal,
			content = content, templates = templates, hash = hash,
			content_contract = contract, cid_by_name = cid_by_name,
			ref_by_name = ref_by_name, cultural_records = cultural_records}
	end

	function loader.heightmap(value) return new_heightmap(value) end
	return loader
end
