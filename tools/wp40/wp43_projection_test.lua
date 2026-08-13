-- T0: exercise the real WP43 owner mod, then verify WP40's pure projection.

local repo = assert(arg[1], "repository root is required")
local output_path = assert(arg[2], "projection output path is required")

-- The WP43 suite installs its complete engine stub, loads the real owner mod,
-- loads the current mapgen consumer, and runs the startup audit. Reusing it
-- keeps this test from growing a weaker parallel registration model.
local previous_arg = arg
arg = {repo}
dofile(repo .. "/tools/wp43/materials_test.lua")
arg = previous_arg

local handoff = dofile(repo ..
	"/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
local projection = handoff.project(grug_materials)

handoff.validate_public(grug_materials, projection)
handoff.validate_registrations(projection, core.registered_items,
	core.registered_nodes)
handoff.validate_target_names(grug_materials, projection)

-- Projection is a copy, never a mutable alias of WP43's public tables.
local public_key = grug_materials.TIERS[1].key
grug_materials.TIERS[1].key = "wp40_copy_probe"
assert(projection.tiers[1].key == public_key,
	"projection aliases grug_materials.TIERS")
grug_materials.TIERS[1].key = public_key

local function graph_equal(a, b, seen)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	seen = seen or {}
	if seen[a] then
		return seen[a] == b
	end
	seen[a] = b
	for key, value in pairs(a) do
		if not graph_equal(value, b[key], seen) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

assert(graph_equal(projection, handoff.project(grug_materials)),
	"projection graph is not repeatable")

-- Canonical T1 encoding accepts integers/Q records only. Catch an accidental
-- float in this handoff before the single T1 encoder exists.
local function assert_integer_graph(value, path, seen)
	local kind = type(value)
	if kind == "number" then
		assert(value == math.floor(value), "non-integer projection value at " .. path)
	elseif kind == "table" and not seen[value] then
		seen[value] = true
		for key, child in pairs(value) do
			assert_integer_graph(child, path .. "." .. tostring(key), seen)
		end
	end
end
assert_integer_graph(projection, "projection", {})

local file = assert(io.open(output_path, "wb"))
assert(file:write("schema\twp40_t0_wp43_projection_audit_v1\n"))
assert(file:write("projection_schema\t", projection.schema, "\n"))
assert(file:write("tiers\t", #projection.tiers, "\n"))
assert(file:write("resources\t", #projection.resources, "\n"))
assert(file:write("processed_materials\t", #projection.processed_materials,
	"\n"))
assert(file:write("race_regions\t", #projection.race_regions, "\n"))
for i, tier in ipairs(projection.tiers) do
	assert(file:write("boundary\t", i, "\t", tier.key, "\t",
		tier.y_min, "\t", tier.y_max, "\t", tier.node, "\n"))
end
for _, resource in ipairs(projection.resources) do
	assert(file:write("resource\t", resource.key, "\t", resource.scope,
		"\t", resource.grade or "-", "\t", resource.harvest_tier, "\t",
		resource.natural_node, "\n"))
end
for _, race in ipairs(projection.race_regions) do
	assert(file:write("race_region\t", race.race, "\t", race.faction, "\t",
		race.g1, "\t", race.g2, "\t", race.cultural, "\t",
		race.signature_wood, "\n"))
end
for _, band in ipairs(projection.density.deep_bands) do
	assert(file:write("deep_band_ratio\t", band.y_max, "\t", band.y_min,
		"\t", band.multiplier_numerator, "\t",
		band.multiplier_denominator, "\n"))
end
assert(file:close())

print(("WP40 T0 WP43 projection passed: %d tiers, %d resources, " ..
	"%d processed materials, %d race regions")
	:format(#projection.tiers, #projection.resources,
		#projection.processed_materials, #projection.race_regions))
