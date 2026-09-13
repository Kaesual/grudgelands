-- Compact final-byte interpreter-parity fixture for quality geometry.

local repo = ...
assert(type(repo) == "string" and repo:sub(1, 1) == "/",
	"absolute repository root required")
local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local deterministic = dofile(directory .. "/deterministic.lua")
local factory = dofile(directory .. "/height.lua")
local module = factory({
	source = {},
	canonical = {},
	deterministic = deterministic,
	raw_sha256 = function() return string.rep("\0", 32) end,
	coupled_grade = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/coupled_grade.lua")(),
	horizontal_session = {},
})
io.write(module.quality_geometry_micro_kat())
