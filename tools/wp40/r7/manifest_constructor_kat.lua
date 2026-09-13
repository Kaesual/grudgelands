-- LuaJIT-only regression for the production R7 manifest constructor. This
-- intentionally decodes the pinned MTS population and builds the bounded
-- anchor roster; it is separate from the portable final micro-KAT.

local repo = assert(arg[1], "repository root required")
if arg[2] ~= nil then error("manifest constructor KAT argument population differs", 0) end

local fixture = dofile(repo .. "/tools/wp40/r7/runtime_fixture.lua")(
	repo, "0", true)
local common, raw_sha256 = fixture.common, fixture.raw_sha256
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local canonical = dofile(wp40 .. "/canonical.lua")
local manifest_module = dofile(wp40 .. "/r7_manifest.lua")(
	canonical, raw_sha256)
local r6_manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
local content_set = dofile(wp40 .. "/r7_content.lua")(
	fixture.core, fixture.projection, raw_sha256)

local r6_hash = dofile(wp40 .. "/r6_hash.lua")(raw_sha256)
local r6_content = dofile(wp40 .. "/r6_content.lua")(
	r6_manifest, content_set.production, fixture.projection)
local template_source = {read = function(filename)
	local directory = filename:match("^grug_gravewood_") and
		repo .. "/mods/ITEMS/grug_trees/schematics/" or
		repo .. "/mods/BASE/default/schematics/"
	return common.read_mts(directory .. filename)
end}
local decoded_templates = dofile(wp40 .. "/r6_templates.lua")(
	r6_hash, r6_content, template_source).records()

local source = dofile(wp40 .. "/source/simple_map.lua")
local zones_module = dofile(wp40 .. "/zones.lua")({source = source,
	schemas = dofile(wp40 .. "/schemas.lua"), canonical = canonical,
	deterministic = dofile(wp40 .. "/deterministic.lua"),
	index128 = dofile(wp40 .. "/index128.lua"),
	horizontal_factory = dofile(wp40 .. "/simple_map.lua"),
	coupled_grade = dofile(wp40 .. "/coupled_grade.lua")(),
	height_factory = dofile(wp40 .. "/height.lua"), raw_sha256 = raw_sha256})
local zones, planner = zones_module.new_with_planner_source_runtime("0", 1)
local anchor_roster = dofile(wp40 .. "/r7_anchor_roster.lua")(
	source, zones, planner, raw_sha256)
local function hex_sha256(bytes) return common.hex(raw_sha256(bytes)) end
local consumer_payload = dofile(wp40 .. "/r7_consumer_payload.lua")(
	source, dofile(wp40 .. "/source/catalog.lua"), hex_sha256)

local inputs = {full_seed = "0",
	r5_manifest = r6_manifest.r5_manifest_values,
	r5_manifest_module = dofile(wp40 .. "/mapgen_manifest.lua"),
	r6_manifest = r6_manifest, wp43_projection = fixture.projection,
	accepted_r6_rows = content_set.accepted_r6_rows(),
	native_identities = fixture.native_identities,
	gathering_manifest = fixture.catalog.manifest(),
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
	cultural_registrations = fixture.catalog.cultural_registrations(),
	decoded_templates = decoded_templates, consumer_payload = consumer_payload}

local receipt = manifest_module.new(inputs)
assert(manifest_module.validate(receipt, receipt.sha256))

local original_semantic = inputs.production_content.semantic_digest
inputs.production_content.semantic_digest = string.rep("0", 64)
local semantic_ok = pcall(manifest_module.new, inputs)
inputs.production_content.semantic_digest = original_semantic
if semantic_ok then error("manifest constructor accepted mutated content semantics", 0) end

local last_template = table.remove(decoded_templates)
local template_ok = pcall(manifest_module.new, inputs)
decoded_templates[#decoded_templates + 1] = last_template
if template_ok then error("manifest constructor accepted truncated templates", 0) end

io.write("WP40 R7 manifest constructor KAT PASS manifest=", receipt.sha256,
	" templates=", tostring(#decoded_templates), "\n")
