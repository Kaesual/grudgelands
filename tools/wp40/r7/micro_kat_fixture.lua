-- Compact production-seam fixture for the final R7 LuaJIT/PUC parity gate.
-- It deliberately parses no MTS file and uses no LuaJIT-only facility.

return function(repo)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local rows = {}

	local function fail(message)
		error("WP40 R7 micro KAT: " .. message, 0)
	end

	local function check(value, message)
		if not value then fail(message) end
		return value
	end

	local function row(id, value)
		rows[#rows + 1] = id .. "\t" .. tostring(value) .. "\n"
	end

	local function hex_sha256(bytes)
		return common.hex(raw_sha256(bytes))
	end

	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[copy(key)] = copy(child) end
		return result
	end

	local function less_bytes(left, right)
		return common.less_bytes(left, right)
	end

	local function scalar(value)
		local kind = type(value)
		if kind == "string" then return "s" .. tostring(#value) .. ":" .. value end
		if kind == "boolean" then return value and "b1;" or "b0;" end
		if kind == "number" and value == value and value ~= math.huge and
				value ~= -math.huge and value % 1 == 0 and
				math.abs(value) <= 9007199254740991 then
			return "n" .. string.format("%.0f", value) .. ";"
		end
		fail("unsupported canonical scalar")
	end

	local function graph(value, active)
		if type(value) ~= "table" then return scalar(value) end
		if getmetatable(value) ~= nil then fail("canonical graph has a metatable") end
		active = active or {}
		if active[value] then fail("canonical graph is cyclic") end
		active[value] = true
		local count, key_count, array = #value, 0, true
		for key in pairs(value) do
			key_count = key_count + 1
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				array = false
			end
		end
		if key_count ~= count then array = false end
		local result = {}
		if array then
			result[1] = "a" .. tostring(count) .. "["
			for index = 1, count do
				result[#result + 1] = graph(value[index], active)
			end
			result[#result + 1] = "]"
		else
			local entries = {}
			for key, child in pairs(value) do
				entries[#entries + 1] = graph(key, active) .. graph(child, active)
			end
			table.sort(entries, less_bytes)
			result[1] = "m" .. tostring(#entries) .. "{"
			for index = 1, #entries do result[#result + 1] = entries[index] end
			result[#result + 1] = "}"
		end
		active[value] = nil
		return table.concat(result)
	end

	local function expect_failure(callback, fragment)
		local ok, message = pcall(callback)
		check(not ok and type(message) == "string" and
			message:find(fragment, 1, true),
			"expected failure did not contain " .. fragment)
	end

	row("schema", "grug_wp40_r7_micro_kat_v1")

	-- Exercise the production native module, including all six setters/readbacks
	-- and the closed six-row ore allowlist, with a plain-Lua engine seam.
	local saved_core = rawget(_G, "core")
	local native_state = {setters = {}, readbacks = {}, ores = {}}
	local native_core = {registered_nodes = {}, registered_ores = {}}
	for _, name in ipairs({"default:stone", "default:gravel",
			"grug_materials:slate", "grug_materials:basalt",
			"grug_materials:granite", "grug_materials:emberrock",
			"grug_materials:abyssal_rock"}) do
		native_core.registered_nodes[name] = {name = name}
	end
	function native_core.sha256(bytes, raw)
		check(raw == false, "native module requested a non-hexadecimal digest")
		return hex_sha256(bytes)
	end
	function native_core.set_mapgen_setting_noiseparams(name, definition, override)
		check(override == true, "native noise setter did not force override")
		native_state.setters[#native_state.setters + 1] = name
		local persist = definition.persist
		if persist == 0.6 then persist = 0.60000002384185791015625 end
		native_state.readbacks[name] = {
			offset = definition.offset, scale = definition.scale,
			persist = persist, persistence = persist,
			lacunarity = definition.lacunarity, seed = definition.seed,
			octaves = definition.octaves, flags = definition.flags or "defaults",
			spread = copy(definition.spread),
		}
	end
	function native_core.get_mapgen_setting_noiseparams(name)
		return copy(native_state.readbacks[name])
	end
	function native_core.register_ore(definition)
		native_state.ores[#native_state.ores + 1] = definition
		native_core.registered_ores[definition.name] = definition
		return #native_state.ores
	end
	rawset(_G, "core", native_core)
	local native = dofile(wp40 .. "/r7_native.lua")
	local native_token = native.apply_and_validate_main()
	local native_identities = native.identities()
	local native_handles = native.register_ores(native_token)
	rawset(_G, "core", saved_core)
	check(#native_state.setters == 6 and #native_handles == 6 and
		#native_state.ores == 6, "native six/six population differs")
	check(hex_sha256(native_token.noise_bytes) == native_identities.noise_digest,
		"native noise canonicalization differs")
	check(hex_sha256(native_token.native_bytes) == native_identities.native_digest,
		"native allowlist canonicalization differs")
	row("native/noise_sha256", native_identities.noise_digest)
	row("native/allowlist_sha256", native_identities.native_digest)
	row("native/noise_order", table.concat(native_state.setters, ","))
	local ore_names = {}
	for index = 1, #native_state.ores do ore_names[index] = native_state.ores[index].name end
	row("native/ore_order_sha256", hex_sha256(table.concat(ore_names, "\n") .. "\n"))

	-- Build the actual R7 content identities without loading or parsing an MTS.
	-- The source parser only discovers the production module's closed target list;
	-- node semantics still come from the real registration files through the
	-- dedicated engine-registration fixture.
	local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local content_source = common.read_file(wp40 .. "/r7_content.lua")
	local accepted_block = content_source:match(
		"local ACCEPTED_R6_ROWS = {(.-)\n\t}\n\tlocal CULTURAL_NAMES")
	check(accepted_block, "production accepted-content block is absent")
	local accepted_rows = {}
	for name, mask in accepted_block:gmatch('{"([^"]+)", (%d+)}') do
		accepted_rows[#accepted_rows + 1] = {name, assert(tonumber(mask))}
	end
	check(#accepted_rows == 77, "accepted-content population differs")
	local cultural_rows, p9g_rows = catalog.cultural_sources(), catalog.p9g_sources()
	local semantic_names = {"air", "ignore", "default:water_source",
		"default:water_flowing", "default:river_water_source",
		"default:river_water_flowing"}
	for index = 1, #accepted_rows do
		semantic_names[#semantic_names + 1] = accepted_rows[index][1]
	end
	for index = 1, #cultural_rows do
		semantic_names[#semantic_names + 1] = cultural_rows[index].source_node
	end
	for index = 1, #p9g_rows do
		semantic_names[#semantic_names + 1] = p9g_rows[index].source_node
	end
	local semantic_fixture = dofile(repo ..
		"/tools/wp40/r7/node_semantics_fixture.lua")(
		repo, catalog, semantic_names)
	check(semantic_fixture.target_count == 101,
		"semantic target population differs")

	local material_environment = setmetatable({grug_materials = {},
		core = {get_modpath = function() return nil end}}, {__index = _G})
	local material_chunk = assert(loadfile(repo ..
		"/mods/ITEMS/grug_materials/registry.lua"))
	setfenv(material_chunk, material_environment)
	material_chunk()
	local projection = {schema = "grug_wp43_projection_v1",
		tiers = copy(material_environment.grug_materials.TIERS),
		resources = copy(material_environment.grug_materials.RESOURCES)}

	local cid_by_name, name_by_cid, definitions = {}, {}, {}
	local next_cid = 100
	local function register(name, cid)
		cid = cid or next_cid
		if not cid_by_name[name] and cid == next_cid then next_cid = next_cid + 1 end
		check(not cid_by_name[name] and not name_by_cid[cid],
			"duplicate compact content registration")
		cid_by_name[name], name_by_cid[cid] = cid, name
		definitions[name] = semantic_fixture.definitions[name]
	end
	register("air", 0)
	register("default:water_source", 1)
	register("default:water_flowing", 2)
	register("default:river_water_source", 3)
	register("default:river_water_flowing", 4)
	register("ignore", 65535)
	for index = 1, #accepted_rows do register(accepted_rows[index][1]) end
	for index = 1, #cultural_rows do register(cultural_rows[index].source_node) end
	for index = 1, #p9g_rows do register(p9g_rows[index].source_node) end
	local content_core = {registered_nodes = definitions, CONTENT_AIR = 0,
		CONTENT_IGNORE = 65535}
	function content_core.get_content_id(name)
		return check(cid_by_name[name], "unknown compact content " .. tostring(name))
	end
	function content_core.get_name_from_content_id(cid) return name_by_cid[cid] end
	local content_set = dofile(wp40 .. "/r7_content.lua")(
		content_core, projection, raw_sha256)
	check(content_set.production_semantic_digest ==
		"3e7d2eddded546e39e74656ab03d27dab606ff30867c948808277b724cff4ee2",
		"production semantic identity differs")
	check(content_set.p9g_semantic_digest ==
		"450c35e94af32721768d3771454db89dbdb43099660b2118c178a3ca6b438d49",
		"P9G semantic identity differs")
	row("content/production_sha256", content_set.production_digest)
	row("content/p9g_sha256", content_set.p9g_digest)

	-- Reconstruct the full production receipt at its public validator boundary.
	-- Every non-predecessor value below comes from a production module built in
	-- this process; predecessor digests are the explicit immutable R5/R6 pins.
	local canonical = dofile(wp40 .. "/canonical.lua")
	local manifest_module = dofile(wp40 .. "/r7_manifest.lua")(
		canonical, raw_sha256)
	local r6_manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
	local r5_manifest_module = dofile(wp40 .. "/mapgen_manifest.lua")
	local r5_values = r5_manifest_module.validate(r6_manifest.r5_manifest_values)
	local r5_digest = hex_sha256(r5_manifest_module.canonical_bytes(r5_values))
	local gathering_manifest = catalog.manifest()
	local cultural_registrations = catalog.cultural_registrations()
	local cultural_digests = {}
	for index = 1, #cultural_registrations do
		cultural_digests[index] = cultural_registrations[index].digest
	end
	local p9g_delta = {schema = "grug_wp40_r7_p9g_delta_v1", opcode = 35,
		class = 10, policy = 11, successor_ref_min = 84,
		successor_ref_max = 95, order = "after_r6_p9_before_run_derivation",
		overwrite = false, catalog_sha256 = gathering_manifest.sha256}
	local p9g_delta_digest = manifest_module.graph_digest_for_evidence(p9g_delta)
	local manifest_values = {
		schema = "grug_wp40_r7_mapgen_manifest_v1", full_seed = "0",
		r5_schema = "grug_wp40_r5_mapgen_manifest_v1",
		r5_manifest_sha256 = r5_digest,
		r5_artifact_sha256 =
			"0ffd8cd5c0133645c330703b8e4ea581a21fe6e5891ddcd987236b26a7d07ca0",
		r6_schema = r6_manifest.schema,
		r6_contract_sha256 = r6_manifest.contract_sha256,
		r6_artifact_sha256 =
			"bb3e9674b768f7ef14fc0a703d0dc97022e9767d0c532b48cd5f1c0c741257b4",
		r6_catalog_sha256 =
			"250fefd017d85fe652be66dbe0d6548e0bf3ada64668f4f9cc2f0fd5577edb2d",
		r6_accepted_content_sha256 =
			"b91a815183d93c2ba0de70409f52911d1e019314e7870fa44eff86f363119155",
		r6_template_inputs_sha256 =
			"807ddf131db405974f365c4e08aa124eeba6cac61fa1655e455794507f858a55",
		wp43_projection_sha256 =
			"5ef7343ff7d01346a1af5825a494ccdbd165c51ece8d09137ad8c9e1539f1633",
		noise_schema = native_identities.noise_schema,
		noise_sha256 = native_identities.noise_digest,
		native_schema = native_identities.native_schema,
		native_sha256 = native_identities.native_digest,
		gathering_schema = gathering_manifest.schema,
		gathering_sha256 = gathering_manifest.sha256,
		production_r6_content_schema = content_set.production.schema,
		production_r6_content_sha256 = content_set.production_digest,
		production_r6_semantic_sha256 = content_set.production_semantic_digest,
		cultural_registration_sha256 = table.concat(cultural_digests, ","),
		p9g_content_schema = content_set.p9g.schema,
		p9g_content_sha256 = content_set.p9g_digest,
		p9g_semantic_sha256 = content_set.p9g_semantic_digest,
		p9g_delta_schema = p9g_delta.schema,
		p9g_delta_sha256 = p9g_delta_digest,
		writer_schema = "grug_wp40_r7_single_vm_writer_v1",
		p9g_opcode = 35, p9g_class = 10, p9g_policy = 11,
		p9g_order = p9g_delta.order, p9g_overwrite = false,
		source_projection_sha256 =
			"5a706e174d8499b255b78b2126e0dc1026c9388ba17c774aadd52958bcaea2f1",
		production_enabled = true,
	}
	local manifest_field_order = {
		"schema", "full_seed", "r5_schema", "r5_manifest_sha256",
		"r5_artifact_sha256", "r6_schema", "r6_contract_sha256",
		"r6_artifact_sha256", "r6_catalog_sha256",
		"r6_accepted_content_sha256", "r6_template_inputs_sha256",
		"wp43_projection_sha256", "noise_schema", "noise_sha256",
		"native_schema", "native_sha256", "gathering_schema",
		"gathering_sha256", "production_r6_content_schema",
		"production_r6_content_sha256", "production_r6_semantic_sha256",
		"cultural_registration_sha256", "p9g_content_schema",
		"p9g_content_sha256", "p9g_semantic_sha256", "p9g_delta_schema",
		"p9g_delta_sha256", "writer_schema", "p9g_opcode", "p9g_class",
		"p9g_policy", "p9g_order", "p9g_overwrite", "source_projection_sha256",
		"production_enabled",
	}
	local manifest_rows = {}
	for index = 1, #manifest_field_order do
		local key, value = manifest_field_order[index], manifest_values[manifest_field_order[index]]
		if type(value) == "boolean" then value = value and "true" or "false"
		elseif type(value) == "number" then value = string.format("%.0f", value) end
		manifest_rows[index] = key .. "\t" .. value .. "\n"
	end
	local manifest_bytes = table.concat(manifest_rows)
	local manifest = {schema = manifest_values.schema, values = manifest_values,
		canonical_bytes = manifest_bytes, sha256 = hex_sha256(manifest_bytes)}
	check(manifest_module.validate(manifest, manifest.sha256) == true,
		"full R7 manifest validation failed")
	local damaged_manifest = copy(manifest)
	damaged_manifest.canonical_bytes = damaged_manifest.canonical_bytes .. "x"
	expect_failure(function() manifest_module.validate(damaged_manifest) end,
		"receipt validation differs")
	row("manifest/full_sha256", manifest.sha256)
	row("manifest/p9g_delta_sha256", p9g_delta_digest)

	-- Bind the real successor with the real catalog/content resolvers. Its SHA
	-- seam is real for catalog authentication and deliberately compact for the
	-- synthetic rank domain; the native and output digests above remain SHA-256.
	local function compact_digest(bytes)
		if bytes == gathering_manifest.canonical_bytes then return raw_sha256(bytes) end
		local accumulators = {2166136261, 2246822519, 3266489917, 668265263,
			374761393, 1274126177, 1431374977, 42595009}
		for index = 1, #bytes do
			local slot = (index - 1) % 8 + 1
			accumulators[slot] = (accumulators[slot] * 257 +
				string.byte(bytes, index) + index) % 4294967296
		end
		local output = {}
		for index = 1, 8 do
			local value = accumulators[index]
			output[#output + 1] = string.char(math.floor(value / 16777216) % 256,
				math.floor(value / 65536) % 256, math.floor(value / 256) % 256,
				value % 256)
		end
		return table.concat(output)
	end
	local successor_config = dofile(wp40 .. "/r7_p9g.lua")(
		catalog, content_set.p9g, compact_digest)
	local hash_seam = {}
	function hash_seam.budget(eligible)
		return eligible > 0 and 1 or 0
	end
	local zones_session = {}
	function zones_session.surface_mob_level_at() return 7 end
	local content_wrapper = {}
	function content_wrapper.content_contract() return content_set.production end
	local successor = successor_config.new({full_seed_string = "0",
		hash = hash_seam, planner_source = {}, horizontal = {},
		content = content_wrapper, source = {}, zones_session = zones_session,
		construction_identity = {}})

	local minp, maxp = {x = -32, y = 0, z = -32},
		{x = 47, y = 79, z = 47}
	local column_values = {}
	for index = 1, 6400 * 12 do column_values[index] = 0 end
	local active_column = ((0 - minp.z) * 80 + (0 - minp.x)) * 12
	column_values[active_column + 5] = 5
	local plan = {schema = "grug_wp40_r6_refinement_plan_v1", generation = 1,
		min_x = minp.x, min_y = minp.y, min_z = minp.z,
		max_x = maxp.x, max_y = maxp.y, max_z = maxp.z,
		column_values = column_values, column_count = 6400}
	successor:plan_slice(minp, maxp, plan, 1)

	local production_ref = {}
	for index = 1, #content_set.production.content_names do
		production_ref[content_set.production.content_names[index]] = index
	end
	local corn = p9g_rows[1]
	local corn_zone, corn_biome, support_name = corn.zones[#corn.zones],
		corn.hosts[#corn.hosts].biome, corn.hosts[#corn.hosts].support
	local support_ref = check(production_ref[support_name], "corn support ref is absent")
	local support_cid = content_set.production.content_cids[support_ref]
	local air_cid = content_set.production.r5.resolve(1, 0, 0)
	local function new_context(call_mode, exclusion)
		local written = {}
		local context = {schema = "grug_wp40_r7_successor_context_v1",
			plan = plan, generation = 1, call_mode = call_mode,
			min_x = minp.x, min_y = minp.y, min_z = minp.z,
			max_x = maxp.x, max_y = maxp.y, max_z = maxp.z}
		local function key(x, y, z) return x .. "/" .. y .. "/" .. z end
		function context.inside_owner(x, y, z)
			return x >= minp.x and x <= maxp.x and y >= minp.y and y <= maxp.y and
				z >= minp.z and z <= maxp.z
		end
		function context.original_at() return air_cid, 0 end
		function context.settled_at(x, y, z)
			local value = written[key(x, y, z)]
			if value then return unpack(value) end
			if x == 0 and y == 5 and z == 0 then
				return support_cid, 0, 0, 4, 0, 0, (support_ref - 1) * 256
			end
			return air_cid, 0, 0, 0, 0, 0, 0
		end
		function context.production_content(name)
			local ref = production_ref[name]
			return ref, ref and content_set.production.content_cids[ref] or nil
		end
		function context.analytic_p7_ref(x, y, z)
			return x == 0 and y == 5 and z == 0 and support_ref or nil
		end
		function context.analytic_p7_tuple(x, y, z)
			if x == 0 and y == 5 and z == 0 then
				return support_cid, 0, 0, 4, 0, 0, (support_ref - 1) * 256
			end
			return -1, -1, -3, -1, -1, -1, -1
		end
		function context.exclusion_at(x, z)
			return x == 0 and z == 0 and exclusion or nil
		end
		function context.housing_excluded_at() return false end
		function context.column_values_at(x, z)
			if x == 0 and z == 0 then
				return "land", 1, corn_zone, corn_biome, "human", 5
			end
			return "land", 1, "micro_no_zone", corn_biome, "human", 0
		end
		function context.write_p9g(x, y, z, cid, param2, local_ref, feature)
			written[key(x, y, z)] = {cid, param2, -2, 35, feature, 0,
				(#content_set.production.content_names + local_ref - 1) * 256 + param2}
		end
		return context
	end

	local transaction_context = new_context("fixture", nil)
	local transaction_ledger = successor:settle(transaction_context)
	local replay_ledger = successor:settle(new_context("replay_fixture", nil))
	check(transaction_ledger.accepted == 1 and
		#transaction_ledger.operations == 1,
		"owner-slice successor transaction differs")
	local transaction_graph, replay_graph = graph(transaction_ledger),
		graph(replay_ledger)
	check(transaction_graph == replay_graph,
		"owner-slice successor replay differs " ..
		hex_sha256(transaction_graph) .. "/" .. hex_sha256(replay_graph))
	local metrics = successor:metrics()
	check(metrics.plan_calls == 1 and metrics.settle_calls == 1 and
		metrics.replay_calls == 1 and metrics.accepted == 1,
		"owner-slice successor metrics differ")
	local function probe_context(exclusion)
		local context = new_context("fixture", exclusion)
		return {inside_owner = context.inside_owner,
			original_at = context.original_at, settled_at = context.settled_at,
			production_content = context.production_content,
			analytic_p7_ref = context.analytic_p7_ref,
			analytic_p7_tuple = context.analytic_p7_tuple,
			exclusion_at = context.exclusion_at,
			housing_excluded_at = context.housing_excluded_at,
			column_values_at = context.column_values_at}
	end
	local accepted_reason = successor:probe_reason(
		probe_context(nil), 1, 0, 6, 0)
	local rejected_reason = successor:probe_reason(
		probe_context("fixed_or_protected"), 1, 0, 6, 0)
	check(accepted_reason == "accepted" and rejected_reason == "fixed_or_protected",
		"accepted/rejected P9G probes differ")
	row("p9g/root_pair", accepted_reason .. "/" .. rejected_reason)
	row("p9g/owner_replay_sha256", hex_sha256(transaction_graph))
	row("p9g/owner_metrics", table.concat({metrics.plan_calls,
		metrics.settle_calls, metrics.replay_calls, metrics.accepted}, "/"))

	-- Bind both R6 projection receipts through the production evidence contract.
	local evidence_contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
	local operation = transaction_ledger.operations[1]
	check(operation.accepted == true and operation.prior_cid == air_cid and
		operation.prior_param2 == 0 and operation.prior_occupancy == 0 and
		operation.prior_opcode == 0 and operation.final_opcode == 35,
		"Stage-A removable P9G delta differs")
	local direct_bytes = table.concat({"root", operation.root_x, operation.root_y,
		operation.root_z, operation.prior_cid, operation.prior_param2,
		operation.prior_occupancy, operation.prior_opcode}, "/")
	local direct_digest = hex_sha256(direct_bytes)
	local stage_a = {
		schema = "grug_wp40_r7_stage_a_receipt_v1", seed_slot = 1,
		seed_identity = "micro-seed-0",
		production_r6_content_sha256 = content_set.production_digest,
		p9g_content_sha256 = content_set.p9g_digest,
		p9g_delta_sha256 = p9g_delta_digest,
		operation_count = 2, accepted_count = 1, rejected_count = 1,
		restored_buffers_sha256 = direct_digest,
		direct_buffers_sha256 = direct_digest,
		restored_runs_sha256 = direct_digest, direct_runs_sha256 = direct_digest,
		equal = true,
	}
	evidence_contract.validate_stage_a(stage_a)
	local accepted_content_rows = content_set.accepted_r6_rows()
	local accepted_by_name, normalized_names = {}, {}
	for index = 1, #accepted_content_rows do
		accepted_by_name[accepted_content_rows[index][1]] =
			accepted_content_rows[index][2]
	end
	local cultural_by_name = {}
	for index = 1, #cultural_rows do
		cultural_by_name[cultural_rows[index].source_node] = true
	end
	local substitution_count = 0
	for index = 1, #content_set.production.content_names do
		local name = content_set.production.content_names[index]
		local mask = content_set.production.content_kind_masks[index]
		if cultural_by_name[name] then
			name, substitution_count = "grug_nodes:bone_pile", substitution_count + 1
			check(accepted_by_name[name] == 24,
				"Stage-B synthetic cultural target differs")
		else
			check(accepted_by_name[name] == mask,
				"Stage-B non-cultural name map differs")
		end
		normalized_names[name] = true
	end
	local normalized_population = 0
	for name in pairs(normalized_names) do
		normalized_population = normalized_population + 1
		check(accepted_by_name[name] ~= nil,
			"Stage-B normalization introduced a foreign name")
	end
	check(#accepted_content_rows == 77 and normalized_population == 77 and
		substitution_count == 6,
		"Stage-B 83-to-77 name projection differs")
	local normalized, accepted = {}, {}
	for index = 1, #cultural_registrations do
		local registration = cultural_registrations[index]
		check(#registration.cells == 1 and
			registration.cells[1].node == cultural_rows[index].source_node,
			"cultural projection registration differs")
		normalized[index] = registration.id .. "/grug_nodes:bone_pile/24\n"
		accepted[index] = registration.id .. "/grug_nodes:bone_pile/24\n"
	end
	local normalized_digest = hex_sha256(table.concat(normalized))
	local accepted_digest = hex_sha256(table.concat(accepted))
	check(normalized_digest == accepted_digest, "Stage-B cultural normalization differs")
	local stage_b = {
		schema = "grug_wp40_r7_stage_b_receipt_v1", seed_slot = 1,
		seed_identity = "micro-seed-0",
		production_r6_content_sha256 = content_set.production_digest,
		accepted_r6_projection_sha256 = accepted_digest,
		name_map_population = 83, cultural_name_map_population = 6,
		cultural_substitution_count = substitution_count,
		normalized_artifact_sha256 = normalized_digest,
		candidate_decisions_sha256 = normalized_digest,
		accepted_candidate_decisions_sha256 = accepted_digest, equal = true,
	}
	evidence_contract.validate_stage_b(stage_b)
	row("projection/stage_a_sha256",
		hex_sha256(evidence_contract.stage_a_bytes(stage_a)))
	row("projection/stage_b_sha256",
		hex_sha256(evidence_contract.stage_b_bytes(stage_b)))

	-- Install the actual public authority and protection wrapper around a
	-- deterministic representative session, then exercise stable queries and
	-- fail-closed behavior on both sides of publication.
	local saved_grug_core, saved_grug_zones = rawget(_G, "grug_core"),
		rawget(_G, "grug_zones")
	local protection_core = {}
	function protection_core.is_protected(pos) return pos.prior == true end
	function protection_core.sha256(bytes) return hex_sha256(bytes) end
	function protection_core.check_player_privs(name)
		return name == "bypass"
	end
	rawset(_G, "core", protection_core)
	rawset(_G, "grug_core", {})
	rawset(_G, "grug_zones", nil)
	function grug_core.get_player_faction(name)
		return name == "throng" and "throng" or "accord"
	end
	dofile(repo .. "/mods/CORE/grug_core/zone_authority.lua")
	check(grug_core.world_protected_for_faction({hard = false}, "accord") == true,
		"pre-publication protection did not fail closed")
	dofile(repo .. "/mods/CORE/grug_core/protection.lua")
	check(protection_core.is_protected({hard = false}, "alice") == true,
		"pre-publication engine wrapper did not fail closed")

	local race_ids = {"dwarf", "human", "elf", "undead", "orc", "troll"}
	local factions = {dwarf = "accord", human = "accord", elf = "accord",
		undead = "throng", orc = "throng", troll = "throng"}
	local anchors, position_anchor = {}, {}
	local function add_anchor(numeric_id, zone_id, slot_id, faction)
		local anchor = {id = string.format("anchor_%03d", numeric_id),
			numeric_id = numeric_id, zone_id = zone_id, slot_id = slot_id,
			x = numeric_id * 100, y = 20, z = numeric_id * -100,
			_faction = faction}
		anchors[zone_id .. "\0" .. slot_id] = anchor
		position_anchor[anchor.x .. "/" .. anchor.z] = anchor
		return {zone_id = zone_id, slot_id = slot_id}
	end
	local payload = {schema = "grug_wp40_r7_consumer_payload_v1",
		races = {}, outposts = {}, rare_routes = {}}
	for index = 1, #race_ids do
		local race = race_ids[index]
		payload.races[index] = {race_id = race, faction_id = factions[race],
			start = add_anchor(index, race .. "_start", "start", factions[race]),
			capital = add_anchor(index + 6, race .. "_capital", "capital",
				factions[race])}
	end
	local outpost_index = 0
	for race_index = 1, #race_ids do
		local race = race_ids[race_index]
		for local_index = 1, 4 do
			outpost_index = outpost_index + 1
			payload.outposts[outpost_index] = {race_id = race,
				faction_id = factions[race],
				anchor = add_anchor(24 + outpost_index,
					race .. "_outpost_" .. local_index,
					"outpost_" .. local_index, factions[race])}
		end
	end
	local consumer_source = common.read_file(wp40 .. "/r7_consumer_payload.lua")
	local rare_block = consumer_source:match("local RARE_IDS = {(.-)}")
	check(rare_block, "consumer rare roster is absent")
	local rare_ids = {}
	for id in rare_block:gmatch('"([a-z0-9_]+)"') do
		rare_ids[#rare_ids + 1] = id
	end
	check(#rare_ids == 10, "consumer rare roster population differs")
	for index = 1, #rare_ids do
		payload.rare_routes[index] = {id = rare_ids[index],
			anchor = add_anchor(90 + index, "rare_zone_" .. index,
				"rare_" .. rare_ids[index], "accord"),
			patrol_offsets = {{x = -48, z = -24}, {x = 16, z = 40},
				{x = 56, z = -16}}}
	end
	local payload_bytes = {"schema\tgrug_wp40_r7_consumer_payload_v1\n"}
	for index = 1, #payload.races do
		local value = payload.races[index]
		payload_bytes[#payload_bytes + 1] = table.concat({"race", value.race_id,
			value.faction_id, value.start.zone_id, value.start.slot_id,
			value.capital.zone_id, value.capital.slot_id}, "\t") .. "\n"
	end
	for index = 1, #payload.outposts do
		local value = payload.outposts[index]
		payload_bytes[#payload_bytes + 1] = table.concat({"outpost", value.race_id,
			value.faction_id, value.anchor.zone_id, value.anchor.slot_id}, "\t") .. "\n"
	end
	for index = 1, #payload.rare_routes do
		local value = payload.rare_routes[index]
		local fields = {"rare", value.id, value.anchor.zone_id, value.anchor.slot_id}
		for offset = 1, #value.patrol_offsets do
			fields[#fields + 1] = tostring(value.patrol_offsets[offset].x)
			fields[#fields + 1] = tostring(value.patrol_offsets[offset].z)
		end
		payload_bytes[#payload_bytes + 1] = table.concat(fields, "\t") .. "\n"
	end
	payload.sha256 = hex_sha256(table.concat(payload_bytes))
	local session = {compatibility = {}}
	function session.get(id) return {id = id} end
	function session.at() return {id = "micro_zone"} end
	function session.neighbors() return {} end
	function session.travel_links() return {} end
	function session.anchor(zone_id, slot_id)
		return copy(anchors[zone_id .. "\0" .. slot_id])
	end
	function session.id_at(x, z)
		if type(x) == "table" then x, z = x.x, x.z end
		local anchor = position_anchor[x .. "/" .. z]
		return anchor and anchor.zone_id or "micro_zone"
	end
	function session.biome_at() return "grug_meadows" end
	function session.race_region_at() return "human" end
	function session.faction_at(pos) return pos._faction or "accord" end
	function session.territory_rule_at() return "shared_editable" end
	function session.pvp_rule_at() return "contested" end
	function session.surface_mob_level_at() return 7 end
	function session.mob_level_at() return 7 end
	function session.guard_level_at() return 10 end
	function session.terrain_height_at() return 20 end
	function session.water_class_at() return "land" end
	function session.nearest_route_at() return nil end
	function session.nearest_hydrology_at() return nil end
	function session.housing_eligible_at() return false end
	function session.compatibility.surface_level_at() return 20 end
	function session.compatibility.mob_level_at() return 7 end
	function session.compatibility.guard_level_at() return 10 end
	function session.compatibility.open_sea_at() return false end
	function session.compatibility.territory_at() return "shared_editable" end
	function session.compatibility.zone_at() return "micro_zone" end
	function session.compatibility.world_protected_for_faction(pos)
		return pos.hard == true
	end
	local publish = grug_core.prepare_zone_authority(session, payload)
	check(not grug_core.zone_authority_installed() and rawget(_G, "grug_zones") == nil,
		"authority preparation published partial state")
	check(publish() == true and grug_core.zone_authority_installed(),
		"authority publication failed")
	local start = grug_core.start_position("accord", "human")
	local rare = grug_core.rare_route("grimtusk")
	check(start and start.y == 21 and rare and #rare == 3 and
		grug_zones.biome_at(start) == "grug_meadows",
		"representative stable query/anchor differs")
	check(protection_core.is_protected({hard = false}, "alice") == false and
		protection_core.is_protected({hard = true}, "alice") == true and
		protection_core.is_protected({hard = false, prior = true}, "alice") == true and
		protection_core.is_protected({hard = true}, "bypass") == false and
		protection_core.is_protected({hard = false}, "") == true,
		"protection wrapper semantics differ")
	row("authority/start", table.concat({start.x, start.y, start.z}, "/"))
	row("authority/rare_route_sha256", hex_sha256(graph(rare)))
	row("authority/protection", "pre_closed/post_open/hard/prior/bypass/empty")
	rawset(_G, "core", saved_core)
	rawset(_G, "grug_core", saved_grug_core)
	rawset(_G, "grug_zones", saved_grug_zones)

	-- The production harvest seam denies herbs until its sole authorizer exists,
	-- and only literal true opens the exact current request.
	local harvest_engine = {get_us_time = function() return 0 end,
		chat_send_player = function() end}
	local harvest = dofile(repo .. "/mods/ITEMS/grug_gathering/harvest.lua")({
		core = harvest_engine, materials = {}})
	local herb
	for index = 1, #p9g_rows do
		if p9g_rows[index].key == "gravemoss" then herb = p9g_rows[index] break end
	end
	check(herb, "representative herb row is absent")
	local allowed, reason = harvest.decision({}, nil, herb)
	check(allowed == false and reason == "profession_unavailable",
		"missing herb authorizer did not fail closed")
	harvest.register_herb_authorizer(function(_, key, group)
		return key == "gravemoss" and group == 1
	end)
	allowed, reason = harvest.decision({}, nil, herb)
	check(allowed == true and reason == nil, "authorized herb request was denied")
	expect_failure(function() harvest.register_herb_authorizer(function() end) end,
		"already registered")
	row("gathering/herb_authority", "closed/authorized/single_registration")

	return rows
end
