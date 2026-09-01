-- Closed semantic identity for the production R7 mapgen assembly. The same
-- constructor runs in the main and emerge environments; numeric content IDs
-- are therefore authenticated instead of being trusted through IPC.

return function(canonical, raw_sha256)
	local SCHEMA = "grug_wp40_r7_mapgen_manifest_v1"
	local ACCEPTED_R6_ARTIFACT_SHA256 =
		"bb3e9674b768f7ef14fc0a703d0dc97022e9767d0c532b48cd5f1c0c741257b4"
	local ACCEPTED_R5_ARTIFACT_SHA256 =
		"0ffd8cd5c0133645c330703b8e4ea581a21fe6e5891ddcd987236b26a7d07ca0"
	local SOURCE_PROJECTION_SHA256 =
		"eca4015a075b8aa5cace19cdc57cb06370481fa8c30185bf1f88f72e3b5e1571"
	local FIELD_ORDER = {
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
		"p9g_delta_sha256", "anchor_content_schema", "anchor_content_sha256",
		"anchor_semantic_sha256", "anchor_roster_schema", "anchor_roster_sha256",
		"anchor_delta_schema", "anchor_delta_sha256", "anchor_opcode",
		"anchor_class", "anchor_policy", "anchor_order", "anchor_overwrite",
		"functional_anchor_protection_schema", "functional_anchor_columns",
		"functional_anchor_y_min", "writer_schema", "p9g_opcode", "p9g_class",
		"p9g_policy", "p9g_order", "p9g_overwrite", "source_projection_sha256",
		"production_enabled",
	}

	local function fail(message)
		error("WP40 R7 manifest: " .. message, 0)
	end

	local function hex(bytes)
		return (bytes:gsub(".", function(char)
			return string.format("%02x", string.byte(char))
		end))
	end

	local function sha256_hex(bytes)
		local digest = raw_sha256(bytes)
		if type(digest) ~= "string" or #digest ~= 32 then
			fail("raw SHA-256 seam differs")
		end
		return hex(digest)
	end

	local function scalar(value)
		if type(value) == "string" then
			if value:find("\0", 1, true) or value:find("\t", 1, true) or
					value:find("\r", 1, true) or value:find("\n", 1, true) then
				fail("manifest text is not line-safe")
			end
			return value
		elseif type(value) == "boolean" then
			return value and "true" or "false"
		elseif type(value) == "number" and value == value and
				value ~= math.huge and value ~= -math.huge and value % 1 == 0 and
				math.abs(value) <= 9007199254740991 then
			return string.format("%.0f", value)
		end
		fail("manifest scalar differs")
	end

	local function canonical_bytes(values)
		if type(values) ~= "table" or getmetatable(values) ~= nil then
			fail("manifest values are not a plain table")
		end
		local allowed = {}
		for index = 1, #FIELD_ORDER do allowed[FIELD_ORDER[index]] = true end
		for key in pairs(values) do
			if not allowed[key] then fail("unexpected field " .. tostring(key)) end
		end
		local rows = {}
		for index = 1, #FIELD_ORDER do
			local key = FIELD_ORDER[index]
			if values[key] == nil then fail("missing field " .. key) end
			rows[index] = key .. "\t" .. scalar(values[key]) .. "\n"
		end
		return table.concat(rows)
	end

	local function typed_graph(value, active)
		local kind = type(value)
		if kind == "string" then return canonical.bytes(value) end
		if kind == "boolean" then return canonical.boolean(value) end
		if kind == "number" and value == value and value ~= math.huge and
				value ~= -math.huge and value % 1 == 0 then
			if value < 0 then return canonical.signed(value) end
			return canonical.unsigned(value)
		end
		if kind ~= "table" or getmetatable(value) ~= nil or active[value] then
			fail("manifest graph value differs: " .. kind .. "/" .. tostring(value))
		end
		active[value] = true
		local count, array, key_count = #value, true, 0
		for key in pairs(value) do
			key_count = key_count + 1
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				array = false
				break
			end
		end
		if key_count ~= count then array = false end
		local result
		if array then
			local children = {}
			for index = 1, count do
				children[index] = typed_graph(value[index], active)
			end
			result = canonical.array(children)
		else
			local pairs_array = {}
			for key, child in pairs(value) do
				local key_kind = type(key)
				if key_kind ~= "string" and key_kind ~= "number" and
						key_kind ~= "boolean" then
					fail("manifest graph key differs")
				end
				pairs_array[#pairs_array + 1] = {
					typed_graph(key, active), typed_graph(child, active)}
			end
			result = canonical.map(pairs_array)
		end
		active[value] = nil
		return result
	end

	local function graph_digest(value)
		if type(canonical) ~= "table" or type(canonical.checksum) ~= "function" or
				type(canonical.hex) ~= "function" then
			fail("canonical checksum seam differs")
		end
		return canonical.hex(canonical.checksum(typed_graph(value, {}), raw_sha256))
	end

	local module = {}
	function module.new(inputs)
		if type(inputs) ~= "table" or getmetatable(inputs) ~= nil then
			fail("input graph differs")
		end
		local expected = {
			full_seed = true, r5_manifest = true, r5_manifest_module = true,
			r6_manifest = true, wp43_projection = true, accepted_r6_rows = true,
			native_identities = true, gathering_manifest = true,
			production_content = true, p9g_content = true,
			anchor_content = true, anchor_roster = true,
			anchor_roster_sha256 = true,
			cultural_registrations = true, decoded_templates = true,
			consumer_payload = true,
		}
		for key in pairs(inputs) do
			if not expected[key] then fail("unexpected input " .. tostring(key)) end
		end
		for key in pairs(expected) do
			if inputs[key] == nil then fail("missing input " .. key) end
		end
		if type(inputs.full_seed) ~= "string" or inputs.full_seed == "" or
				not inputs.full_seed:match("^%-?%d+$") then
			fail("full seed differs")
		end
		local r5_validated = inputs.r5_manifest_module.validate(inputs.r5_manifest)
		local r5_digest = sha256_hex(
			inputs.r5_manifest_module.canonical_bytes(r5_validated))
		local r6 = inputs.r6_manifest
		if r6.schema ~= "grug_wp40_r6_manifest_values_v1" or
			r6.contract_sha256 ~=
				"814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f" then
			fail("R6 predecessor identity differs")
		end
		local native = inputs.native_identities
		if native.noise_schema ~= "grug_wp40_r7_noiseparams_v1" or
			native.noise_digest ~=
				"5a1183a0db4dcbf7c2fce382e907660bfd26e53325d370f62a2d9e78c04d8738" or
			native.native_schema ~= "grug_wp40_r7_native_allowlist_v1" or
			native.native_digest ~=
				"d1fe4ac1c7cbe5525af65bde48cc4309870c01e4d474785f2cf0cda3d2639480" then
			fail("native identity differs")
		end
		local gathering = inputs.gathering_manifest
		if gathering.schema ~= "grug_wp33_gathering_catalog_v1" or
			gathering.sha256 ~=
				"d03533037c5a38cf62b85963a59b19efe9f48f770b5b6f3885f20f7b17f0af53" or
			sha256_hex(gathering.canonical_bytes) ~= gathering.sha256 then
			fail("gathering identity differs")
		end
		if inputs.production_content.semantic_digest ~=
				"3e7d2eddded546e39e74656ab03d27dab606ff30867c948808277b724cff4ee2" or
				inputs.p9g_content.semantic_digest ~=
				"450c35e94af32721768d3771454db89dbdb43099660b2118c178a3ca6b438d49" then
			fail("frozen content semantics differ")
		end
		local anchors = inputs.anchor_content
		if anchors.schema ~= "grug_wp40_r7_anchor_content_v1" or
				type(anchors.digest) ~= "string" or #anchors.digest ~= 64 or
				type(anchors.semantic_digest) ~= "string" or
				#anchors.semantic_digest ~= 64 then
			fail("anchor content identity differs")
		end
		if type(inputs.anchor_roster) ~= "table" or #inputs.anchor_roster ~= 42 or
				type(inputs.anchor_roster_sha256) ~= "string" or
				#inputs.anchor_roster_sha256 ~= 64 then
			fail("anchor roster identity differs")
		end
		local family_counts, seen = {capital = 0, outpost = 0, bandit = 0}, {}
		for index = 1, 42 do
			local row = inputs.anchor_roster[index]
			local numeric = (index <= 6 and index + 6) or
				(index <= 30 and index + 18) or index + 18
			local family = index <= 6 and "capital" or
				(index <= 30 and "outpost" or "bandit")
			local ref = family == "bandit" and 1 or 2
			local expected_feature = numeric <= 12 and
				string.format("route_%03d", (numeric - 7) * 3 + 2) or
				string.format("poi_spur_%03d", numeric)
			if type(row) ~= "table" or row.numeric_id ~= numeric or
					row.id ~= string.format("anchor_%03d", numeric) or
					row.family ~= family or row.content_ref ~= ref or seen[row.id] or
					type(row.x) ~= "number" or type(row.y) ~= "number" or
					type(row.z) ~= "number" or
					type(row.functional_kind) ~= "string" or
					row.functional_kind == "" or row.functional_y ~= row.y or
					row.functional_feature_id ~= expected_feature or
					type(row.hard_foundation) ~= "boolean" then
				fail("anchor roster row differs")
			end
			seen[row.id] = true
			family_counts[family] = family_counts[family] + 1
		end
		if family_counts.capital ~= 6 or family_counts.outpost ~= 24 or
				family_counts.bandit ~= 12 then
			fail("anchor roster population differs")
		end
		local cultural = inputs.cultural_registrations
		if #cultural ~= 6 then fail("cultural population differs") end
		local cultural_digests = {}
		for index = 1, 6 do
			local row = cultural[index]
			if type(row) ~= "table" or type(row.digest) ~= "string" or
					#row.digest ~= 64 then
				fail("cultural registration digest differs")
			end
			cultural_digests[index] = row.digest
		end
		if type(inputs.decoded_templates) ~= "table" or
				#inputs.decoded_templates ~= 19 then
			fail("decoded template population differs")
		end
		local frozen = {
			schema = "grug_wp40_r7_source_projection_v1",
			r6_catalog = graph_digest({surfaces = r6.surfaces,
				resources = r6.resources, cultural = r6.cultural,
				decorations = r6.decorations}),
			accepted_r6_content = graph_digest(inputs.accepted_r6_rows),
			decoded_templates = graph_digest(inputs.decoded_templates),
			wp43_projection = graph_digest(inputs.wp43_projection),
			production_semantics = inputs.production_content.semantic_digest,
			p9g_semantics = inputs.p9g_content.semantic_digest,
			native_noise = native.noise_digest,
			native_allowlist = native.native_digest,
			gathering = gathering.sha256,
			cultural = graph_digest(cultural),
			consumer_payload = graph_digest(inputs.consumer_payload),
		}
		if frozen.r6_catalog ~=
				"250fefd017d85fe652be66dbe0d6548e0bf3ada64668f4f9cc2f0fd5577edb2d" or
			frozen.accepted_r6_content ~=
				"b91a815183d93c2ba0de70409f52911d1e019314e7870fa44eff86f363119155" or
			frozen.decoded_templates ~=
				"807ddf131db405974f365c4e08aa124eeba6cac61fa1655e455794507f858a55" or
			frozen.wp43_projection ~=
				"5ef7343ff7d01346a1af5825a494ccdbd165c51ece8d09137ad8c9e1539f1633" or
			frozen.cultural ~=
				"263b9bf0a470295b62791f85effd59eee9090c82d5f4d050e4f97ba88bb79fb6" or
			frozen.consumer_payload ~=
				"c6132247f268c6def7d5f8c60a1de7d93e52d99c5da9367526182c0d89d902b7" or
			graph_digest(frozen) ~= SOURCE_PROJECTION_SHA256 then
			fail("frozen source projection differs")
		end
		local p9g_delta = {
			schema = "grug_wp40_r7_p9g_delta_v1", opcode = 35,
			class = 10, policy = 11, successor_ref_min = 84,
			successor_ref_max = 95, order = "after_r6_p9_before_run_derivation",
			overwrite = false, catalog_sha256 = gathering.sha256,
		}
		local anchor_delta = {
			schema = "grug_wp40_r7_anchor_delta_v1", opcode = 36,
			class = 12, policy = 12, successor_ref_min = 96,
			successor_ref_max = 97, order = "after_p9g_before_run_derivation",
			overwrite = false, roster_sha256 = inputs.anchor_roster_sha256,
			root = "anchor_y_plus_one",
			support = "settled_predecessor_support_v1",
			capital_count = 6, outpost_count = 24, bandit_count = 12,
			functional_protection_schema =
				"grug_wp40_r7_functional_anchor_protection_v1",
			functional_columns = 36, functional_y_min = -700,
		}
		local values = {
			schema = SCHEMA, full_seed = inputs.full_seed,
			r5_schema = "grug_wp40_r5_mapgen_manifest_v1",
			r5_manifest_sha256 = r5_digest,
			r5_artifact_sha256 = ACCEPTED_R5_ARTIFACT_SHA256,
			r6_schema = r6.schema, r6_contract_sha256 = r6.contract_sha256,
			r6_artifact_sha256 = ACCEPTED_R6_ARTIFACT_SHA256,
			r6_catalog_sha256 = frozen.r6_catalog,
			r6_accepted_content_sha256 = frozen.accepted_r6_content,
			r6_template_inputs_sha256 = frozen.decoded_templates,
			wp43_projection_sha256 = frozen.wp43_projection,
			noise_schema = native.noise_schema, noise_sha256 = native.noise_digest,
			native_schema = native.native_schema, native_sha256 = native.native_digest,
			gathering_schema = gathering.schema, gathering_sha256 = gathering.sha256,
			production_r6_content_schema = inputs.production_content.schema,
			production_r6_content_sha256 = inputs.production_content.digest,
			production_r6_semantic_sha256 = inputs.production_content.semantic_digest,
			cultural_registration_sha256 = table.concat(cultural_digests, ","),
			p9g_content_schema = inputs.p9g_content.schema,
			p9g_content_sha256 = inputs.p9g_content.digest,
			p9g_semantic_sha256 = inputs.p9g_content.semantic_digest,
			p9g_delta_schema = p9g_delta.schema,
			p9g_delta_sha256 = graph_digest(p9g_delta),
			anchor_content_schema = anchors.schema,
			anchor_content_sha256 = anchors.digest,
			anchor_semantic_sha256 = anchors.semantic_digest,
			anchor_roster_schema = "grug_wp40_r7_anchor_roster_v1",
			anchor_roster_sha256 = inputs.anchor_roster_sha256,
			anchor_delta_schema = anchor_delta.schema,
			anchor_delta_sha256 = graph_digest(anchor_delta),
			anchor_opcode = 36, anchor_class = 12, anchor_policy = 12,
			anchor_order = anchor_delta.order, anchor_overwrite = false,
			functional_anchor_protection_schema =
				anchor_delta.functional_protection_schema,
			functional_anchor_columns = 36, functional_anchor_y_min = -700,
			writer_schema = "grug_wp40_r7_single_vm_writer_v1",
			p9g_opcode = 35, p9g_class = 10, p9g_policy = 11,
			p9g_order = p9g_delta.order, p9g_overwrite = false,
			source_projection_sha256 = SOURCE_PROJECTION_SHA256,
			production_enabled = true,
		}
		local bytes = canonical_bytes(values)
		return {schema = SCHEMA, sha256 = sha256_hex(bytes),
			canonical_bytes = bytes, values = values}
	end

	-- Private construction-time helper. It exists so the offline acceptance
	-- tools can bind the same typed graph without duplicating its encoding.
	function module.graph_digest_for_evidence(value)
		return graph_digest(value)
	end

	function module.validate(receipt, expected_sha256)
		if type(receipt) ~= "table" or receipt.schema ~= SCHEMA or
			type(receipt.values) ~= "table" or
			receipt.canonical_bytes ~= canonical_bytes(receipt.values) or
			receipt.sha256 ~= sha256_hex(receipt.canonical_bytes) or
			(type(expected_sha256) == "string" and receipt.sha256 ~= expected_sha256) then
			fail("receipt validation differs")
		end
		return true
	end

	return module
end
