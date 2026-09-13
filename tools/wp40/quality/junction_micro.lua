-- Compact final-byte interpreter fixture for the production junction helpers.

return function(repo)
	local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local deterministic = dofile(directory .. "/deterministic.lua")
	local module = dofile(directory .. "/height.lua")({
		source = {}, canonical = {}, deterministic = deterministic,
		raw_sha256 = function() return string.rep("\0", 32) end,
		horizontal_session = {},
	})
	return module.junction_micro_kat()
end
