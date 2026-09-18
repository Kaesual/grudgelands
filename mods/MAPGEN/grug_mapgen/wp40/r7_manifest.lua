-- Closed semantic identity for the production R7 mapgen assembly. The same
-- constructor runs in the main and emerge environments; numeric content IDs
-- are therefore authenticated instead of being trusted through IPC.

-- `settlement_order` is derived from the WP13 roster in roster order
-- (`r7_settlement.lua`, contract section 2.2.2): one row per settlement, each
-- carrying its blueprints in blueprint order. Before this increment the field
-- list and the settlement roster were typed out here per settlement, which
-- meant a capital could not be added without editing two closed literals that
-- had to agree with a third. What is closed now is the SHAPE -- the fixed head
-- and tail fields, the ten fields every blueprint publishes, and the rule that
-- the order is the roster's -- and the roster is the single authority for which
-- settlements and blueprints exist. Every start keeps its own field prefix, so
-- `hearthpine_blueprint_sha256` is still spelled exactly that.
return function(canonical, raw_sha256, settlement_order)
	local SCHEMA = "grug_wp40_r7_mapgen_manifest_v1"
	local ACCEPTED_R6_ARTIFACT_SHA256 =
		"bb3e9674b768f7ef14fc0a703d0dc97022e9767d0c532b48cd5f1c0c741257b4"
	local ACCEPTED_R5_ARTIFACT_SHA256 =
		"0ffd8cd5c0133645c330703b8e4ea581a21fe6e5891ddcd987236b26a7d07ca0"
	-- WP13 playtest round 3, 2026-09-15: the template anchor fix moves exactly
	-- one of the six frozen limbs, `decoded_templates`, and with it this roll-up.
	-- `r6_templates` now anchors a template by its lowest OCCUPIED slice, so the
	-- three bush schematics' all-air bottom slice and the two transcribed
	-- `offset_y_plus_1` rules no longer add a second node of ground clearance;
	-- five of the twenty-one decoded records move their `min_y`/`max_y` by one and
	-- nothing else in the projection changes. Was
	-- `de79b1fe983d8b5a...`, with `decoded_templates` `ab77c5efa9587823...`.
	-- R8-MAP-A, 2026-09-18: four shipped shallow-terrain nodes extend the
	-- accepted/production content vocabularies. Geometry and horizontal layout
	-- inputs are unchanged; the content limb and this roll-up move together.
	local SOURCE_PROJECTION_SHA256 =
		"80e5068e4a508cb75c34f41d319e1f2a78d2625ca16314f03ca9a92da3e7523d"
	local FIELD_HEAD = {
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
		"settlement_content_schema", "settlement_content_sha256",
		"settlement_semantic_sha256", "settlement_content_count",
	}
	local FIELD_TAIL = {
		"functional_anchor_y_min", "writer_schema", "p9g_opcode", "p9g_class",
		"p9g_policy", "p9g_order", "p9g_overwrite", "source_projection_sha256",
		"production_enabled",
	}
	-- The eleven fields every WP13 blueprint publishes. `population` is the
	-- blueprint's own size in the unit its kind HAS: a cell count for a
	-- blueprint made of cells, a run count for an overlay, which has none until
	-- a surface arrives. `population_kind` says which, so the row cannot be read
	-- as a cell count it never was.
	local BLUEPRINT_FIELDS = {"blueprint_schema", "blueprint_sha256",
		"population", "population_kind", "delta_schema", "delta_sha256",
		"opcode", "class", "policy", "order", "overwrite"}

	local function fail(message)
		error("WP40 R7 manifest: " .. message, 0)
	end

	-- The roster-derived settlement order, validated once here so every
	-- consumer below can read it as authored data.
	local SETTLEMENT_ORDER = {}
	if type(settlement_order) ~= "table" or #settlement_order < 1 then
		fail("settlement order differs")
	end
	local seen_key, seen_prefix = {}, {}
	for index = 1, #settlement_order do
		local row = settlement_order[index]
		if type(row) ~= "table" or type(row.key) ~= "string" or row.key == "" or
				seen_key[row.key] or type(row.anchor_id) ~= "string" or
				row.anchor_id == "" or type(row.delta_schema) ~= "string" or
				row.delta_schema == "" or type(row.blueprints) ~= "table" or
				#row.blueprints < 1 then
			fail("settlement order row differs at " .. index)
		end
		seen_key[row.key] = true
		local blueprints = {}
		for blueprint_index = 1, #row.blueprints do
			local blueprint = row.blueprints[blueprint_index]
			if type(blueprint) ~= "table" or type(blueprint.id) ~= "string" or
					blueprint.id == "" or type(blueprint.prefix) ~= "string" or
					blueprint.prefix == "" or seen_prefix[blueprint.prefix] or
					type(blueprint.identity_schema) ~= "string" or
					blueprint.identity_schema == "" or
					type(blueprint.kind) ~= "string" or blueprint.kind == "" or
					type(blueprint.bounds) ~= "table" or
					type(blueprint.bounds.min) ~= "table" or
					type(blueprint.bounds.max) ~= "table" then
				fail("settlement blueprint order differs at " .. index .. "/" ..
					blueprint_index)
			end
			seen_prefix[blueprint.prefix] = true
			blueprints[blueprint_index] = {id = blueprint.id,
				prefix = blueprint.prefix, kind = blueprint.kind,
				identity_schema = blueprint.identity_schema,
				bounds = {min = {x = blueprint.bounds.min.x, y = blueprint.bounds.min.y,
						z = blueprint.bounds.min.z},
					max = {x = blueprint.bounds.max.x, y = blueprint.bounds.max.y,
						z = blueprint.bounds.max.z}}}
		end
		SETTLEMENT_ORDER[index] = {key = row.key, anchor_id = row.anchor_id,
			delta_schema = row.delta_schema, blueprints = blueprints}
	end

	local FIELD_ORDER = {}
	for index = 1, #FIELD_HEAD do FIELD_ORDER[#FIELD_ORDER + 1] = FIELD_HEAD[index] end
	for index = 1, #SETTLEMENT_ORDER do
		local blueprints = SETTLEMENT_ORDER[index].blueprints
		for blueprint_index = 1, #blueprints do
			local prefix = blueprints[blueprint_index].prefix
			for field_index = 1, #BLUEPRINT_FIELDS do
				FIELD_ORDER[#FIELD_ORDER + 1] = prefix .. "_" ..
					BLUEPRINT_FIELDS[field_index]
			end
		end
	end
	for index = 1, #FIELD_TAIL do FIELD_ORDER[#FIELD_ORDER + 1] = FIELD_TAIL[index] end

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
			settlement_content = true, settlement_blueprints = true,
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
				"9b7a978d178352521ae61fb87b897c5f79e12838b0829caa229ad90832ddedb8" or
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
			-- WHAT GRADES A CAPITAL ANCHOR'S OWN COLUMN. It used to be a ROUTE:
			-- a capital anchor sits on its zone hub and every route that named
			-- that zone ran to the hub, so `route_002`, `route_005`, ... were
			-- written across the middle of the city and the anchor column
			-- carried the first of them. Playtest round 4 ruled the routes back
			-- to the gates on the envelope edge (`source/simple_map.lua`,
			-- `CAPITAL_GATE_SIDES`), so nothing but the capital's own fitting
			-- reaches the anchor column any more and the feature is the fitting's
			-- id, which is the anchor's.
			--
			-- This is the only field of the roster row that moves, and it moves
			-- the roster digest with it. A POI anchor is unchanged: its spur
			-- still ends on it.
			local expected_feature = numeric <= 12 and
				string.format("anchor_%03d", numeric) or
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
		-- One opcode-37 content channel serves every WP13 settlement; the
		-- blueprint identities are per BLUEPRINT and are published in roster
		-- order, then blueprint order.
		local settlement_content = inputs.settlement_content
		if type(settlement_content) ~= "table" or
				settlement_content.schema ~= "grug_wp13_settlement_content_v1" or
				type(settlement_content.digest) ~= "string" or
				#settlement_content.digest ~= 64 or
				type(settlement_content.semantic_digest) ~= "string" or
				#settlement_content.semantic_digest ~= 64 or
				type(settlement_content.count) ~= "number" or
				settlement_content.count < 1 or settlement_content.count % 1 ~= 0 then
			fail("settlement content identity differs")
		end
		local settlement_blueprints = inputs.settlement_blueprints
		if type(settlement_blueprints) ~= "table" or
				#settlement_blueprints ~= #SETTLEMENT_ORDER then
			fail("settlement blueprint population differs")
		end
		for index = 1, #SETTLEMENT_ORDER do
			local row = settlement_blueprints[index]
			local expect = SETTLEMENT_ORDER[index]
			if type(row) ~= "table" or row.key ~= expect.key or
					row.anchor_id ~= expect.anchor_id or
					row.delta_schema ~= expect.delta_schema or
					type(row.blueprints) ~= "table" or
					#row.blueprints ~= #expect.blueprints then
				fail("settlement blueprint population differs at " .. index)
			end
			for blueprint_index = 1, #expect.blueprints do
				local entry = row.blueprints[blueprint_index]
				local wanted = expect.blueprints[blueprint_index]
				-- The authorized volume is the BLUEPRINT'S OWN, from the roster
				-- profile (`r7_settlement.M.BOUNDS`). It used to be the start's
				-- +-63 / y -2..24 typed out here, which is the third of the three
				-- places contract section 2.2.1 names.
				local bounds = wanted.bounds
				-- A blueprint with cells publishes `cell_count`; an OVERLAY has no
				-- cells until a surface arrives and publishes `run_count`
				-- instead. Exactly one of the two, so a row cannot quietly claim
				-- a cell count it does not have.
				local population = entry.kind == "overlay" and
					entry.identity.run_count or entry.identity.cell_count
				if type(entry) ~= "table" or entry.id ~= wanted.id or
						entry.prefix ~= wanted.prefix or entry.kind ~= wanted.kind or
						type(entry.identity) ~= "table" or
						entry.identity.schema ~= wanted.identity_schema or
						type(entry.identity.sha256) ~= "string" or
						#entry.identity.sha256 ~= 64 or
						type(population) ~= "number" or population < 1 or
						(entry.kind == "overlay") ~=
							(entry.identity.cell_count == nil) or
						(entry.kind == "overlay") ~=
							(entry.identity.run_count ~= nil) or
						type(entry.identity.min_x) ~= "number" or
						type(entry.identity.max_x) ~= "number" or
						type(entry.identity.min_y) ~= "number" or
						type(entry.identity.max_y) ~= "number" or
						type(entry.identity.min_z) ~= "number" or
						type(entry.identity.max_z) ~= "number" or
						entry.identity.min_x < bounds.min.x or
						entry.identity.max_x > bounds.max.x or
						entry.identity.min_y < bounds.min.y or
						entry.identity.max_y > bounds.max.y or
						entry.identity.min_z < bounds.min.z or
						entry.identity.max_z > bounds.max.z then
					fail("settlement blueprint identity differs at " .. index .. "/" ..
						blueprint_index)
				end
			end
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
				#inputs.decoded_templates ~= 21 then
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
				"71686cbaff9a2b6acb0415a3eda0ebc2d056412db1879c1bf4fcb162e14f4f74" or
			frozen.accepted_r6_content ~=
				"466abcd49cac58c68aabf26b17e0ae3925425e1396ab73bc61f8d27de8cf996b" or
			frozen.decoded_templates ~=
				"faa8fdd2beabd0807b5a41cd207163bbbb741fa8ee263a212bd7fbe34f2ff4df" or
			frozen.wp43_projection ~=
				"c8088a4b6802c0fc1a74d8826e3df0bb49b64f9ab4c6e93bcbd66aa2a16b9895" or
			frozen.cultural ~=
				"263b9bf0a470295b62791f85effd59eee9090c82d5f4d050e4f97ba88bb79fb6" or
			frozen.consumer_payload ~=
				"c6132247f268c6def7d5f8c60a1de7d93e52d99c5da9367526182c0d89d902b7" or
			graph_digest(frozen) ~= SOURCE_PROJECTION_SHA256 then
			fail("frozen source projection differs: accepted=" ..
				frozen.accepted_r6_content .. " decoded=" .. frozen.decoded_templates ..
				" wp43=" .. frozen.wp43_projection .. " cultural=" .. frozen.cultural ..
				" consumer=" .. frozen.consumer_payload ..
				" projection=" .. graph_digest(frozen))
		end
		local p9g_delta = {
			schema = "grug_wp40_r7_p9g_delta_v1", opcode = 35,
			class = 10, policy = 11, successor_ref_min = 89,
			successor_ref_max = 100, order = "after_r6_p9_before_run_derivation",
			overwrite = false, catalog_sha256 = gathering.sha256,
		}
		local anchor_delta = {
			schema = "grug_wp40_r7_anchor_delta_v1", opcode = 36,
			class = 12, policy = 12, successor_ref_min = 97,
			successor_ref_max = 98, order = "after_p9g_before_run_derivation",
			overwrite = false, roster_sha256 = inputs.anchor_roster_sha256,
			root = "anchor_y_plus_one",
			support = "settled_predecessor_support_v1",
			capital_count = 6, outpost_count = 24, bandit_count = 12,
			functional_protection_schema =
				"grug_wp40_r7_functional_anchor_protection_v1",
			functional_columns = 36, functional_y_min = -700,
		}
		-- Every settlement carries the same opcode, class, policy, order and
		-- successor-ref window, because they share one content channel; what
		-- separates them is the anchor and the blueprint digest. A settlement
		-- that owns several blueprints publishes one delta per BLUEPRINT, whose
		-- `kind` says how its cells reach the world -- anchor-relative,
		-- projected from a reference column, or computed per mapchunk from the
		-- plan's own column surface.
		local settlement_deltas = {}
		for index = 1, #settlement_blueprints do
			local row = settlement_blueprints[index]
			settlement_deltas[index] = {}
			for blueprint_index = 1, #row.blueprints do
				local entry = row.blueprints[blueprint_index]
				settlement_deltas[index][blueprint_index] = {
					schema = row.delta_schema, opcode = 37,
					class = 13, policy = 13,
					order = "after_anchor_activation_before_run_derivation",
					overwrite = true, anchor_id = row.anchor_id,
					blueprint_id = entry.id, blueprint_kind = entry.kind,
					blueprint_sha256 = entry.identity.sha256,
					content_sha256 = settlement_content.digest,
					successor_ref_min = 99,
					successor_ref_max = 98 + settlement_content.count,
					population = entry.kind == "overlay" and
						entry.identity.run_count or entry.identity.cell_count,
					population_kind = entry.kind == "overlay" and "runs" or "cells",
					reach_min_x = entry.identity.min_x,
					reach_min_y = entry.identity.min_y,
					reach_min_z = entry.identity.min_z,
					reach_max_x = entry.identity.max_x,
					reach_max_y = entry.identity.max_y,
					reach_max_z = entry.identity.max_z,
					clipping = "current_mapchunk_owner_intersection_v1",
				}
			end
		end
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
			settlement_content_schema = settlement_content.schema,
			settlement_content_sha256 = settlement_content.digest,
			settlement_semantic_sha256 = settlement_content.semantic_digest,
			settlement_content_count = settlement_content.count,
			writer_schema = "grug_wp40_r7_single_vm_writer_v1",
			p9g_opcode = 35, p9g_class = 10, p9g_policy = 11,
			p9g_order = p9g_delta.order, p9g_overwrite = false,
			source_projection_sha256 = SOURCE_PROJECTION_SHA256,
			production_enabled = true,
		}
		for index = 1, #settlement_blueprints do
			local row = settlement_blueprints[index]
			for blueprint_index = 1, #row.blueprints do
				local entry = row.blueprints[blueprint_index]
				local delta = settlement_deltas[index][blueprint_index]
				local prefix = entry.prefix
				values[prefix .. "_blueprint_schema"] = entry.identity.schema
				values[prefix .. "_blueprint_sha256"] = entry.identity.sha256
				values[prefix .. "_population"] = delta.population
				values[prefix .. "_population_kind"] = delta.population_kind
				values[prefix .. "_delta_schema"] = delta.schema
				values[prefix .. "_delta_sha256"] = graph_digest(delta)
				values[prefix .. "_opcode"] = 37
				values[prefix .. "_class"] = 13
				values[prefix .. "_policy"] = 13
				values[prefix .. "_order"] = delta.order
				values[prefix .. "_overwrite"] = true
			end
		end
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
