-- Pure validators and canonical encoders for WP40 R7 evidence receipts.
-- Production map semantics stay behind integration_adapter.lua; this module
-- validates only closed identities, populations and proof-result schemas.

local module = {}

local MAX_SAFE = 9007199254740991
local HEX64 = "^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]" ..
	string.rep("[0-9a-f]", 56) .. "$"

local EXPECTED_IDS = {
	new_p9g_source = {
		"wp33_corn_source_v1",
		"wp33_crimson_lotus_source_v1",
		"wp33_dragonweed_source_v1",
		"wp33_gravemoss_source_v1",
		"wp33_marshbloom_source_v1",
		"wp33_melon_source_v1",
		"wp33_mushroom_source_v1",
		"wp33_potato_source_v1",
		"wp33_rock_salt_source_v1",
		"wp33_stormkelp_source_v1",
		"wp33_sunleaf_source_v1",
		"wp33_wild_cocoa_source_v1",
	},
	reuse_r6_source = {
		"wp33_apple_r6_reuse_v1",
		"wp33_blueberry_r6_reuse_v1",
		"wp33_gravewood_r6_reuse_v1",
		"wp33_kapok_r6_reuse_v1",
		"wp33_mountain_pine_r6_reuse_v1",
		"wp33_oak_r6_reuse_v1",
		"wp33_silverwood_r6_reuse_v1",
		"wp33_spikethorn_acacia_r6_reuse_v1",
	},
	r6_cultural_slot = {
		"wp33_gravesalt_source_v1",
		"wp33_moonresin_source_v1",
		"wp33_red_ochre_source_v1",
		"wp33_runeslate_source_v1",
		"wp33_spirit_resin_source_v1",
		"wp33_sunwax_source_v1",
	},
}

local INTEGRATION_CASES = {
	"fail_closed_initialization",
	"gathering_closed_manifest",
	"native_input_aggregation",
	"one_callback_one_transaction",
	"owner_and_support_boundaries",
	"p9g_all_rejections",
	"p9g_all_sources",
	"p9g_non_overwrite_no_retry",
	"protection_and_query_adapters",
	"replay_parity",
	"stage_a_projection",
	"stage_b_projection",
}

local REJECTION_REASONS = {
	"clipped_owner",
	"fixed_or_protected",
	"route_or_water",
	"housing_exclusion",
	"content_ignore",
	"wrong_zone",
	"wrong_biome",
	"wrong_shore",
	"wrong_support",
	"insufficient_clearance",
	"r6_occupancy",
}

local function fail(message)
	error("WP40 R7 evidence contract: " .. message, 0)
end

local function plain_table(value, label)
	if type(value) ~= "table" then fail(label .. " is not a table") end
	if getmetatable(value) ~= nil then fail(label .. " has a metatable") end
	return value
end

local function exact_keys(value, keys, label)
	plain_table(value, label)
	local count = 0
	for key in pairs(value) do
		count = count + 1
		if not keys[key] then fail(label .. " has unknown field " .. tostring(key)) end
	end
	local expected = 0
	for key in pairs(keys) do
		expected = expected + 1
		if rawget(value, key) == nil then fail(label .. " is missing field " .. key) end
	end
	if count ~= expected then fail(label .. " field count differs") end
	return value
end

local function dense(value, count, label)
	plain_table(value, label)
	if #value ~= count then fail(label .. " population differs") end
	local seen = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not a dense array")
		end
		seen = seen + 1
	end
	if seen ~= count then fail(label .. " dense population differs") end
	return value
end

local function text(value, label)
	if type(value) ~= "string" or value == "" or
			value:find("\0", 1, true) or value:find("\r", 1, true) or
			value:find("\n", 1, true) or value:find("\t", 1, true) then
		fail(label .. " is not one nonempty TSV-safe string")
	end
	return value
end

local function sha256(value, label)
	if type(value) ~= "string" or #value ~= 64 or not value:match(HEX64) then
		fail(label .. " is not a lowercase SHA-256")
	end
	return value
end

local function unsigned(value, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < 0 or
			value > MAX_SAFE then
		fail(label .. " is not an exact unsigned integer")
	end
	return value
end

local function positive(value, label)
	unsigned(value, label)
	if value == 0 then fail(label .. " is not positive") end
	return value
end

local function bool(value, label)
	if type(value) ~= "boolean" then fail(label .. " is not boolean") end
	return value
end

local function copy(value, active)
	if type(value) ~= "table" then return value end
	active = active or {}
	if active[value] then fail("cannot copy a cyclic receipt") end
	active[value] = true
	local result = {}
	for key, child in pairs(value) do result[copy(key, active)] = copy(child, active) end
	active[value] = nil
	return result
end

local function validate_ascii_order(rows, class)
	local expected = EXPECTED_IDS[class]
	dense(rows, #expected, class)
	for index = 1, #expected do
		local row = plain_table(rows[index], class .. " row " .. index)
		if row.placement_class ~= class then
			fail(class .. " row " .. index .. " has the wrong placement class")
		end
		if row.id ~= expected[index] then
			fail(class .. " ID/order differs at row " .. index)
		end
		if index > 1 and not (rows[index - 1].id < row.id) then
			fail(class .. " IDs are not ASCII ordered")
		end
	end
end

function module.expected_ids()
	return copy(EXPECTED_IDS)
end

function module.integration_cases()
	return copy(INTEGRATION_CASES)
end

function module.rejection_reasons()
	return copy(REJECTION_REASONS)
end

function module.validate_catalog(snapshot, raw_sha256)
	exact_keys(snapshot, {
		manifest = true, p9g_sources = true, reuse_sources = true,
		cultural_sources = true, cultural_registrations = true,
	}, "catalog snapshot")
	local manifest = exact_keys(snapshot.manifest, {
		schema = true, sha256 = true, canonical_bytes = true,
		source_files = true, placement = true, population = true,
	}, "catalog manifest")
	if manifest.schema ~= "grug_wp33_gathering_catalog_v1" then
		fail("catalog schema differs")
	end
	sha256(manifest.sha256, "catalog digest")
	if type(manifest.canonical_bytes) ~= "string" or
			manifest.canonical_bytes == "" then
		fail("catalog canonical bytes are absent")
	end
	if type(raw_sha256) ~= "function" then fail("raw SHA-256 adapter is absent") end
	local actual = raw_sha256(manifest.canonical_bytes)
	if type(actual) ~= "string" or #actual ~= 32 then
		fail("raw SHA-256 adapter result differs")
	end
	local hexadecimal = (actual:gsub(".", function(byte)
		return string.format("%02x", string.byte(byte))
	end))
	if hexadecimal ~= manifest.sha256 then fail("catalog canonical digest differs") end
	exact_keys(manifest.population, {
		new_p9g_source = true, reuse_r6_source = true, r6_cultural_slot = true,
	}, "catalog population")
	if manifest.population.new_p9g_source ~= 12 or
			manifest.population.reuse_r6_source ~= 8 or
			manifest.population.r6_cultural_slot ~= 6 then
		fail("catalog 12/8/6 population differs")
	end
	validate_ascii_order(snapshot.p9g_sources, "new_p9g_source")
	validate_ascii_order(snapshot.reuse_sources, "reuse_r6_source")
	validate_ascii_order(snapshot.cultural_sources, "r6_cultural_slot")
	dense(snapshot.cultural_registrations, 6, "cultural registrations")
	local registration_ids = {}
	for index = 1, 6 do
		local registration = plain_table(snapshot.cultural_registrations[index],
			"cultural registration " .. index)
		text(registration.id, "cultural registration ID")
		if registration.id ~= EXPECTED_IDS.r6_cultural_slot[index] then
			fail("cultural registration ID/order differs at row " .. index)
		end
		sha256(registration.digest, "cultural registration digest")
		if registration_ids[registration.id] then fail("duplicate cultural registration") end
		registration_ids[registration.id] = true
	end
	return copy(snapshot)
end

function module.catalog_receipt(snapshot)
	local manifest = snapshot.manifest
	local rows = {
		"schema\tgrug_wp40_r7_catalog_gate_receipt_v1\n",
		"catalog_schema\t" .. manifest.schema .. "\n",
		"catalog_sha256\t" .. manifest.sha256 .. "\n",
		"population\tnew_p9g_source\t12\n",
		"population\treuse_r6_source\t8\n",
		"population\tr6_cultural_slot\t6\n",
	}
	for _, class in ipairs({"new_p9g_source", "reuse_r6_source",
			"r6_cultural_slot"}) do
		local source = class == "new_p9g_source" and snapshot.p9g_sources or
			(class == "reuse_r6_source" and snapshot.reuse_sources or
				snapshot.cultural_sources)
		for index = 1, #source do
			rows[#rows + 1] = "id\t" .. class .. "\t" .. index .. "\t" ..
				source[index].id .. "\n"
		end
	end
	for index = 1, #snapshot.cultural_registrations do
		local row = snapshot.cultural_registrations[index]
		rows[#rows + 1] = "cultural_registration\t" .. row.id .. "\t" ..
			row.digest .. "\n"
	end
	return table.concat(rows)
end

function module.validate_integration_receipt(receipt)
	exact_keys(receipt, {
		schema = true, r7_manifest_sha256 = true,
		production_r6_content_sha256 = true, p9g_content_sha256 = true,
		catalog_sha256 = true, cases = true,
	}, "integration receipt")
	if receipt.schema ~= "grug_wp40_r7_integration_kat_receipt_v1" then
		fail("integration receipt schema differs")
	end
	for _, field in ipairs({"r7_manifest_sha256", "production_r6_content_sha256",
			"p9g_content_sha256", "catalog_sha256"}) do
		sha256(receipt[field], "integration receipt " .. field)
	end
	exact_keys(receipt.cases, (function()
		local keys = {}
		for index = 1, #INTEGRATION_CASES do keys[INTEGRATION_CASES[index]] = true end
		return keys
	end)(), "integration cases")
	for index = 1, #INTEGRATION_CASES do
		if receipt.cases[INTEGRATION_CASES[index]] ~= true then
			fail("integration case did not pass: " .. INTEGRATION_CASES[index])
		end
	end
	return copy(receipt)
end

function module.integration_receipt_bytes(receipt)
	module.validate_integration_receipt(receipt)
	local rows = {
		"schema\t" .. receipt.schema .. "\n",
		"r7_manifest_sha256\t" .. receipt.r7_manifest_sha256 .. "\n",
		"production_r6_content_sha256\t" ..
			receipt.production_r6_content_sha256 .. "\n",
		"p9g_content_sha256\t" .. receipt.p9g_content_sha256 .. "\n",
		"catalog_sha256\t" .. receipt.catalog_sha256 .. "\n",
	}
	for index = 1, #INTEGRATION_CASES do
		rows[#rows + 1] = "case\t" .. INTEGRATION_CASES[index] .. "\ttrue\n"
	end
	return table.concat(rows)
end

function module.validate_stage_a(receipt)
	exact_keys(receipt, {
		schema = true, seed_slot = true, seed_identity = true,
		production_r6_content_sha256 = true, p9g_content_sha256 = true,
		p9g_delta_sha256 = true, operation_count = true, accepted_count = true,
		rejected_count = true, restored_buffers_sha256 = true,
		direct_buffers_sha256 = true, restored_runs_sha256 = true,
		direct_runs_sha256 = true, equal = true,
	}, "Stage-A receipt")
	if receipt.schema ~= "grug_wp40_r7_stage_a_receipt_v1" then
		fail("Stage-A schema differs")
	end
	if positive(receipt.seed_slot, "Stage-A seed slot") > 32 then
		fail("Stage-A seed slot exceeds the frozen corpus")
	end
	text(receipt.seed_identity, "Stage-A seed identity")
	for _, field in ipairs({"production_r6_content_sha256", "p9g_content_sha256",
			"p9g_delta_sha256", "restored_buffers_sha256", "direct_buffers_sha256",
			"restored_runs_sha256", "direct_runs_sha256"}) do
		sha256(receipt[field], "Stage-A " .. field)
	end
	unsigned(receipt.operation_count, "Stage-A operation count")
	unsigned(receipt.accepted_count, "Stage-A accepted count")
	unsigned(receipt.rejected_count, "Stage-A rejected count")
	if receipt.accepted_count + receipt.rejected_count ~= receipt.operation_count then
		fail("Stage-A operation partition differs")
	end
	if receipt.equal ~= true or
			receipt.restored_buffers_sha256 ~= receipt.direct_buffers_sha256 or
			receipt.restored_runs_sha256 ~= receipt.direct_runs_sha256 then
		fail("Stage-A removable-delta equality failed")
	end
	return copy(receipt)
end

function module.validate_stage_b(receipt)
	exact_keys(receipt, {
		schema = true, seed_slot = true, seed_identity = true,
		production_r6_content_sha256 = true, accepted_r6_projection_sha256 = true,
		name_map_population = true, cultural_name_map_population = true,
		cultural_substitution_count = true, normalized_artifact_sha256 = true,
		candidate_decisions_sha256 = true, accepted_candidate_decisions_sha256 = true,
		equal = true,
	}, "Stage-B receipt")
	if receipt.schema ~= "grug_wp40_r7_stage_b_receipt_v1" then
		fail("Stage-B schema differs")
	end
	if positive(receipt.seed_slot, "Stage-B seed slot") > 32 then
		fail("Stage-B seed slot exceeds the frozen corpus")
	end
	text(receipt.seed_identity, "Stage-B seed identity")
	for _, field in ipairs({"production_r6_content_sha256",
			"accepted_r6_projection_sha256", "normalized_artifact_sha256",
			"candidate_decisions_sha256", "accepted_candidate_decisions_sha256"}) do
		sha256(receipt[field], "Stage-B " .. field)
	end
	if receipt.name_map_population ~= 83 or
			receipt.cultural_name_map_population ~= 6 then
		fail("Stage-B total name map differs")
	end
	unsigned(receipt.cultural_substitution_count,
		"Stage-B cultural substitution count")
	if receipt.equal ~= true or
			receipt.normalized_artifact_sha256 ~= receipt.accepted_r6_projection_sha256 or
			receipt.candidate_decisions_sha256 ~=
			receipt.accepted_candidate_decisions_sha256 then
		fail("Stage-B accepted-evidence equality failed")
	end
	return copy(receipt)
end

function module.validate_pilot_result(receipt)
	exact_keys(receipt, {
		schema = true, seed_slot = true, seed_identity = true,
		canonical_output_sha256 = true, stage_a_sha256 = true,
		stage_b_sha256 = true, p9g_delta_sha256 = true,
	}, "pilot result")
	if receipt.schema ~= "grug_wp40_r7_pilot_result_v1" then
		fail("pilot result schema differs")
	end
	if positive(receipt.seed_slot, "pilot seed slot") > 32 then
		fail("pilot seed slot exceeds the frozen corpus")
	end
	text(receipt.seed_identity, "pilot seed identity")
	for _, field in ipairs({"canonical_output_sha256", "stage_a_sha256",
			"stage_b_sha256", "p9g_delta_sha256"}) do
		sha256(receipt[field], "pilot result " .. field)
	end
	return copy(receipt)
end

function module.pilot_result_bytes(receipt)
	module.validate_pilot_result(receipt)
	return table.concat({
		"schema\t", receipt.schema, "\n",
		"seed_slot\t", tostring(receipt.seed_slot), "\n",
		"seed_identity\t", receipt.seed_identity, "\n",
		"canonical_output_sha256\t", receipt.canonical_output_sha256, "\n",
		"stage_a_sha256\t", receipt.stage_a_sha256, "\n",
		"stage_b_sha256\t", receipt.stage_b_sha256, "\n",
		"p9g_delta_sha256\t", receipt.p9g_delta_sha256, "\n",
	})
end

return module
