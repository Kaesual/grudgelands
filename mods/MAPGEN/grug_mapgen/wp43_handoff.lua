-- Pure WP43 material-registry projection for WP40.
--
-- The caller supplies the live grug_materials table. This module owns no
-- material identity, depth boundary, density value or registration; it only
-- copies the published WP43 placement surface into a canonical private graph.
-- It is deliberately safe to load in plain Lua 5.1 and in every Luanti Lua
-- environment. Numeric content ids never enter the projection.

local handoff = {}

local function fail(message)
	error("grug_mapgen WP43 handoff: " .. message, 0)
end

local function copy_array(values)
	local result = {}
	for i = 1, #(values or {}) do
		result[i] = values[i]
	end
	return result
end

local function copy_map(values)
	local result = {}
	for key, value in pairs(values or {}) do
		result[key] = value
	end
	return result
end

local function copy_graph(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		fail("published registry graph contains a cycle")
	end
	seen[value] = true
	local result = {}
	for key, child in pairs(value) do
		if type(key) ~= "string" and type(key) ~= "number" then
			fail("unsupported registry key type " .. type(key))
		end
		if type(child) == "function" or type(child) == "userdata" or
				type(child) == "thread" then
			fail("unsupported registry value type " .. type(child))
		end
		result[key] = copy_graph(child, seen)
	end
	seen[value] = nil
	return result
end

local function sorted_keys(values)
	local keys = {}
	for key in pairs(values or {}) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function sorted_rows(values)
	local rows = {}
	for _, key in ipairs(sorted_keys(values)) do
		local row = copy_graph(values[key])
		row._projection_key = key
		rows[#rows + 1] = row
	end
	return rows
end

local function gcd(a, b)
	while b ~= 0 do
		a, b = b, a % b
	end
	return a
end

-- WP43 currently publishes its deep multipliers as Lua numbers. They are
-- finite design rationals, but floating-point values may not enter WP40's
-- canonical manifest encoder. Project them as a reduced integer ratio before
-- T1 sees the graph. This searches for the smallest exact practical
-- denominator instead of copying either published multiplier as a literal.
local function ratio(value)
	if type(value) ~= "number" or value <= 0 or value ~= value or
			value == math.huge then
		fail("density multiplier is not a positive finite number")
	end
	for denominator = 1, 1000000 do
		local scaled = value * denominator
		local numerator = math.floor(scaled + 0.5)
		if math.abs(scaled - numerator) < 0.000000000001 then
			local divisor = gcd(numerator, denominator)
			return numerator / divisor, denominator / divisor
		end
	end
	fail("density multiplier is not an accepted finite rational")
end

local function project_density(density)
	local result = {
		g1 = copy_graph(density.g1),
		g2 = copy_graph(density.g2),
		abyssal_crystal = copy_graph(density.abyssal_crystal),
		deep_bands = {},
	}
	for i, band in ipairs(density.deep_bands or {}) do
		local numerator, denominator = ratio(band.multiplier)
		result.deep_bands[i] = {
			y_max = band.y_max,
			y_min = band.y_min,
			multiplier_numerator = numerator,
			multiplier_denominator = denominator,
		}
	end
	return result
end

local PUBLIC_SYMBOL_TYPES = {
	TIERS = "table",
	TIER_BY_KEY = "table",
	tier_at = "function",
	stratum_node_for = "function",
	max_depth_for_pick_tier = "function",
	can_mine_natural_at = "function",
	NATURAL_GROUND_NODES = "table",
	NATURAL_GROUND_SET = "table",
	natural_groups = "function",
	RESOURCES = "table",
	RESOURCE_BY_KEY = "table",
	RESOURCE_BY_NODE = "table",
	resource = "function",
	resource_for_node = "function",
	resource_node = "function",
	PROCESSED_MATERIALS = "table",
	PROCESSED_BY_KEY = "table",
	processed = "function",
	GEM_GRADES = "table",
	CULTURAL_MATERIALS = "table",
	SIGNATURE_WOODS = "table",
	RACE_REGIONS = "table",
	DENSITY = "table",
	SHORTFALL_MULTIPLIERS = "table",
	PICK_PROFILES = "table",
	build_pick_capabilities = "function",
	pick_tier_for_stack = "function",
	is_natural_node = "function",
	mining_decision = "function",
	resource_ore_description = "function",
	register_on_harvest = "function",
	emit_mining_failure = "function",
	is_shattering = "function",
	node_dig_wrapper = "function",
	CURRENT_SCATTER_RESOURCES = "table",
	LEGACY_ALIASES = "table",
	STORAGE_DERIVATIVES = "table",
	FORBIDDEN_RUNTIME_STEMS = "table",
	canonical_name = "function",
}

function handoff.validate_symbols(materials)
	if type(materials) ~= "table" then
		fail("grug_materials table is unavailable")
	end
	for symbol, expected in pairs(PUBLIC_SYMBOL_TYPES) do
		if type(materials[symbol]) ~= expected then
			fail("missing or invalid public symbol " .. symbol)
		end
	end
	return true
end

function handoff.project(materials)
	handoff.validate_symbols(materials)
	local projection = {
		schema = "grug_wp43_projection_v1",
		tiers = copy_graph(materials.TIERS),
		natural_ground_nodes = copy_array(materials.NATURAL_GROUND_NODES),
		resources = copy_graph(materials.RESOURCES),
		processed_materials = copy_graph(materials.PROCESSED_MATERIALS),
		gem_grades = {},
		cultural_materials = sorted_rows(materials.CULTURAL_MATERIALS),
		signature_woods = sorted_rows(materials.SIGNATURE_WOODS),
		race_regions = sorted_rows(materials.RACE_REGIONS),
		density = project_density(materials.DENSITY),
	}
	for _, grade in ipairs(sorted_keys(materials.GEM_GRADES)) do
		projection.gem_grades[#projection.gem_grades + 1] = {
			grade = grade,
			resources = copy_array(materials.GEM_GRADES[grade]),
		}
	end
	return projection
end

-- There is deliberately no encoder or checksum function here. T1 owns the
-- one canonical tagged big-endian integer/Q encoder and hashes this projected
-- graph through that seam. A T0-specific textual encoding would create the
-- forbidden second manifest/checksum authority.

local function build_lookups(projection)
	local by_key, by_node = {}, {}
	for _, resource in ipairs(projection.resources) do
		by_key[resource.key] = resource
		by_node[resource.natural_node] = resource
	end
	return by_key, by_node
end

function handoff.tier_at(projection, y)
	for i = 1, #projection.tiers do
		if y >= projection.tiers[i].y_min then
			return i
		end
	end
	return #projection.tiers
end

function handoff.stratum_node_for(projection, y)
	return projection.tiers[handoff.tier_at(projection, y)].node
end

function handoff.resource(projection, key)
	local by_key = build_lookups(projection)
	return by_key[key]
end

function handoff.resource_for_node(projection, node_name)
	local _, by_node = build_lookups(projection)
	return by_node[node_name]
end

function handoff.resource_node(projection, key)
	local resource = handoff.resource(projection, key)
	return resource and resource.natural_node or nil
end

local function expect_registration(registry, name, label)
	if type(name) ~= "string" or not registry[name] then
		fail("unresolved " .. label .. " registration " .. tostring(name))
	end
	return registry[name]
end

function handoff.validate_registrations(projection, registered_items,
		registered_nodes)
	registered_items = registered_items or {}
	registered_nodes = registered_nodes or {}
	for _, tier in ipairs(projection.tiers) do
		local node = expect_registration(registered_nodes, tier.node, "stratum")
		if (node.groups or {}).grug_stratum ~= tier.id or
				(node.groups or {}).grug_natural ~= 1 then
			fail("misclassified stratum registration " .. tier.node)
		end
		expect_registration(registered_items, tier.bar_item, "tier bar")
		local block = expect_registration(registered_nodes, tier.block_node,
			"tier block")
		if (block.groups or {}).grug_natural then
			fail("crafted tier block is registered as natural " .. tier.block_node)
		end
	end
	for _, name in ipairs(projection.natural_ground_nodes) do
		local node = expect_registration(registered_nodes, name, "natural ground")
		if (node.groups or {}).grug_natural ~= 1 then
			fail("natural ground lacks marker " .. name)
		end
	end
	for _, resource in ipairs(projection.resources) do
		local node = expect_registration(registered_nodes, resource.natural_node,
			"resource node")
		local groups = node.groups or {}
		if groups.grug_natural ~= 1 or
				groups.grug_resource ~= resource.harvest_tier then
			fail("misclassified resource registration " .. resource.natural_node)
		end
		expect_registration(registered_items, resource.raw_item, "raw resource")
		if resource.cut_item then
			expect_registration(registered_items, resource.cut_item, "cut resource")
		end
		if resource.block_node then
			local block = expect_registration(registered_nodes, resource.block_node,
				"resource block")
			if (block.groups or {}).grug_natural then
				fail("crafted resource block is natural " .. resource.block_node)
			end
		end
	end
	for _, material in ipairs(projection.processed_materials) do
		expect_registration(registered_items, material.item, "processed material")
		local block = expect_registration(registered_nodes, material.block_node,
			"processed block")
		if (block.groups or {}).grug_natural then
			fail("processed block is natural " .. material.block_node)
		end
	end
	for _, material in ipairs(projection.cultural_materials) do
		expect_registration(registered_items, material.item, "cultural material")
	end
	for _, wood in ipairs(projection.signature_woods) do
		expect_registration(registered_nodes, wood.tree, "signature tree")
		expect_registration(registered_nodes, wood.wood, "signature wood")
	end
	return true
end

function handoff.validate_public(materials, projection)
	if #projection.tiers ~= #materials.TIERS then
		fail("tier projection count mismatch")
	end
	for i, tier in ipairs(projection.tiers) do
		if materials.TIER_BY_KEY[tier.key] ~= materials.TIERS[i] or
				materials.max_depth_for_pick_tier(i) ~= tier.max_depth then
			fail("tier public lookup mismatch for " .. tier.key)
		end
		for _, y in ipairs({tier.y_min - 1, tier.y_min, tier.y_min + 1,
				tier.y_max}) do
			if handoff.tier_at(projection, y) ~= materials.tier_at(y) or
					handoff.stratum_node_for(projection, y) ~=
					materials.stratum_node_for(y) then
				fail("tier boundary projection mismatch for " .. tier.key)
			end
		end
		local allowed = materials.can_mine_natural_at(i, tier.max_depth)
		local below = materials.can_mine_natural_at(i, tier.max_depth - 1)
		if not allowed or below then
			fail("inclusive depth predicate mismatch for " .. tier.key)
		end
	end
	for _, resource in ipairs(projection.resources) do
		if materials.resource(resource.key) ~=
				materials.RESOURCE_BY_KEY[resource.key] or
				materials.resource_for_node(resource.natural_node) ~=
				materials.RESOURCE_BY_NODE[resource.natural_node] or
				materials.resource_node(resource.key) ~= resource.natural_node or
				handoff.resource_node(projection, resource.key) ~=
				resource.natural_node or
				handoff.resource_for_node(projection, resource.natural_node).key ~=
				resource.key then
			fail("resource public lookup mismatch for " .. resource.key)
		end
	end
	for _, material in ipairs(projection.processed_materials) do
		if materials.processed(material.key) ~=
				materials.PROCESSED_BY_KEY[material.key] then
			fail("processed public lookup mismatch for " .. material.key)
		end
	end
	return true
end

function handoff.validate_target_names(materials, projection)
	local values = {}
	local function collect(value, seen)
		if type(value) == "string" then
			values[#values + 1] = value:lower()
		elseif type(value) == "table" and not seen[value] then
			seen[value] = true
			for key, child in pairs(value) do
				collect(key, seen)
				collect(child, seen)
			end
		end
	end
	collect(projection, {})
	for _, stem in ipairs(materials.FORBIDDEN_RUNTIME_STEMS) do
		for _, value in ipairs(values) do
			if value:find(stem:lower(), 1, true) then
				fail("forbidden runtime stem in target projection: " .. stem)
			end
		end
	end
	for _, value in ipairs(values) do
		if materials.LEGACY_ALIASES[value] then
			fail("migration-source id in target projection: " .. value)
		end
	end
	return true
end

return handoff
