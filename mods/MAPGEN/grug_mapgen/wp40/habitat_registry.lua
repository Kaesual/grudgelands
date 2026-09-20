-- Pure plant-habitat vocabulary shared by initial mapgen and runtime renewal.
-- It reads no engine globals and owns the renewable/excluded source boundary.
local M = {}

local EXCLUDED = {rock_salt = true, salt_crust = true}

function M.is_renewable(key)
	return type(key) == "string" and not EXCLUDED[key]
end

function M.initial_denominator(key, denominator)
	assert(type(denominator) == "number" and denominator > 0)
	return M.is_renewable(key) and denominator * 2 or denominator
end

local function set(values)
	local result = {}
	for index = 1, #(values or {}) do result[values[index]] = true end
	return result
end

function M.compile_world(row)
	local compiled = {key = row.key, node = row.node, kind = "world", row = row,
		zones = set(row.zones), hosts = {}}
	for biome, values in pairs(row.hosts) do
		compiled.hosts[biome == "any" and "*" or biome] = set(values)
	end
	return compiled
end

function M.compile_p9g(row)
	local compiled = {key = row.key, node = row.source_node, kind = "p9g",
		row = row, zones = set(row.zones), hosts = {}}
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

function M.habitat_matches(source, values)
	local row = source.row
	if source.kind == "world" then
		if values.y < row.min or values.y > row.max or
				(#row.zones > 0 and not source.zones[values.zone]) then
			return false
		end
		local supports = source.hosts[values.biome] or
			source.hosts[values.analytic_biome] or source.hosts["*"] or
			source.hosts.stone
		return supports ~= nil and supports[values.support] == true and
			(row.mode ~= "surface" or values.y == values.terrain_y + 1)
	end
	if not source.zones[values.zone] then return false end
	local biome = source.hosts[values.analytic_biome]
	local zones = biome and biome[values.support]
	return zones ~= nil and (zones[values.zone] or zones["*"]) == true
end

return M
