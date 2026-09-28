-- Pure plant-habitat vocabulary shared by initial mapgen and runtime renewal.
-- It reads no engine global and owns the renewable/excluded source boundary.
local M = {}

local EXCLUDED = {rock_salt = true, salt_crust = true}

function M.is_renewable(key)
	return type(key) == "string" and not EXCLUDED[key]
end

function M.initial_denominator(key, denominator)
	assert(type(denominator) == "number" and denominator > 0)
	return M.is_renewable(key) and denominator * 2 or denominator
end

-- Expected natural plants per eligible column (or cave-floor node) of one
-- resource source: the writer settles one in `initial_denominator` eligible
-- candidates (world_content.lua hash test, r7_p9g.lua cell budget).
function M.natural_probability(key, denominator)
	return 1 / M.initial_denominator(key, denominator)
end

-- Density multiplier of decoration vegetation ("cover": grass, ferns,
-- shrubs; "woody": trees and bushes) at one site, `values` as in
-- `habitat_matches` plus `terrain_y`. Round 23 Phase 2 puts the tree line,
-- its transition band and the forest-density noise field here; the mapgen
-- planner and runtime renewal (vegetation_density.lua) then read the same
-- rule. Until then every site keeps its catalog density.
function M.vegetation_factor(class, values)
	assert(class == "cover" or class == "woody")
	assert(type(values) == "table")
	return 1
end

local function set(values)
	local result = {}
	for index = 1, #(values or {}) do result[values[index]] = true end
	return result
end

function M.compile_world(row)
	local compiled = {key = row.key, node = row.node, kind = "world", row = row,
		zones = set(row.zones), hosts = {}, shore = row.shore or "none"}
	for biome, values in pairs(row.hosts) do
		compiled.hosts[biome == "any" and "*" or biome] = set(values)
	end
	return compiled
end

function M.compile_p9g(row)
	local compiled = {key = row.key, node = row.source_node, kind = "p9g",
		row = row, zones = set(row.zones), hosts = {},
		shore = row.shore_predicate or "none",
		shore_classes = set(row.shore_water_classes)}
	for index = 1, #row.hosts do
		local host = row.hosts[index]
		local biome = compiled.hosts[host.biome] or {}
		local support = biome[host.support] or {}
		support[host.zone or "*"] = true
		biome[host.support] = support
		compiled.hosts[host.biome] = biome
	end
	return compiled
end

-- Support node names a compiled source accepts in one logical biome and zone
-- (the eligible ground renewal counts), sorted; empty when none.
function M.host_names(source, biome, zone)
	local result = {}
	if source.kind == "world" then
		local supports = source.row.mode == "cave" and source.hosts.stone or
			source.hosts[biome] or source.hosts["*"]
		for name in pairs(supports or {}) do result[#result + 1] = name end
	else
		for name, zones in pairs(source.hosts[biome] or {}) do
			if zones[zone] or zones["*"] then result[#result + 1] = name end
		end
	end
	table.sort(result)
	return result
end

-- The writer's geographic predicate for one candidate site. `values`:
--   mode      "surface" (open ground at the planned surface or on
--             player-made ground) or "cave" (at least two below the planned
--             terrain surface, world_content.lua cave rows);
--   y         the plant position; level the zone's surface mob level
--             (surface rows band by level, world_content.lua), zone, biome
--             (the planner's logical biome) and support (node name below).
-- Shore predicates need neighbouring columns and are answered by the caller
-- (vegetation_density.lua), exactly as the writers do.
function M.habitat_matches(source, values)
	local row = source.row
	if source.kind == "world" then
		if row.mode == "cave" then
			if values.mode ~= "cave" or values.y < row.min or values.y > row.max then
				return false
			end
			local supports = source.hosts.stone
			return supports ~= nil and supports[values.support] == true
		end
		if values.mode ~= "surface" or type(values.level) ~= "number" or
				values.level < row.min or values.level > row.max or
				(#row.zones > 0 and not source.zones[values.zone]) then
			return false
		end
		local supports = source.hosts[values.biome] or source.hosts["*"]
		return supports ~= nil and supports[values.support] == true
	end
	if values.mode ~= "surface" or not source.zones[values.zone] then return false end
	local biome = source.hosts[values.biome]
	local zones = biome and biome[values.support]
	return zones ~= nil and (zones[values.zone] or zones["*"]) == true
end

return M
