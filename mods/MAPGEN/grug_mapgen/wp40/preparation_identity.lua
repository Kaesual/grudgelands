-- One load-time guard for the live column/selection code. Runtime content IDs
-- are deliberately absent: normal engine restarts can assign different IDs.
return function(directory, sha256)
	local files = {
		"source/simple_map.lua", "schemas.lua", "canonical.lua",
		"deterministic.lua", "index128.lua", "simple_map.lua", "height.lua",
		"terrain_field.lua", "terrain_data.lua", "zones.lua", "r5.lua", "r6.lua",
		"r7_runtime.lua", "preparation_source.lua", "preparation_identity.lua",
		"../../../CORE/grug_core/preparation_plan.lua",
	}
	local parts = {}
	for _, name in ipairs(files) do
		local file = assert(io.open(directory .. "/" .. name, "rb"),
			"Preparation authority source unavailable: " .. name)
		local bytes = assert(file:read("*a"))
		file:close()
		parts[#parts + 1] = name .. ":" .. sha256(bytes)
	end
	return sha256(table.concat(parts, "\n"))
end
