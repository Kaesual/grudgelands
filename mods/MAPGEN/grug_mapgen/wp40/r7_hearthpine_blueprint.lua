-- Hearthpine Vale is authored in local coordinates around the dwarf start.
-- The caller fits y = 0 to the settlement terrain before projecting the cells.
--
-- The architecture itself lives in the reusable WP13 building library under
-- `mods/MAPGEN/grug_mapgen/wp13/`; this file only locates that library and
-- returns its Hearthpine composition unchanged, so the schema string, bounds
-- contract, landmark keys and destination ids of the first two increments
-- stay exactly as the R7 successor, the manifest and the fixtures expect.
--
-- The library directory is derived from this chunk's own source path, which
-- works for `dofile` from `r7_runtime.lua` inside the engine sandbox (whose
-- `debug.getinfo` is whitelisted) and for the plain interpreters that run
-- `tools/wp13/dump_blueprint.lua` and `tools/wp13/blueprint_kat.lua`. If the
-- debug library is unavailable, the engine's own mod path is the fallback.

local debug_table
do
	local ok, value = pcall(function() return debug end)
	if ok then debug_table = value end
end

local library
if type(debug_table) == "table" and type(debug_table.getinfo) == "function" then
	local info = debug_table.getinfo(1, "S")
	local source = type(info) == "table" and info.source or nil
	if type(source) == "string" and source:sub(1, 1) == "@" then
		local directory = source:sub(2):match("^(.*)[/\\][^/\\]*$")
		if directory and directory ~= "" then
			library = directory .. "/../wp13"
		end
	end
end
if library == nil then
	local ok, modpath = pcall(function()
		return core.get_modpath("grug_mapgen")
	end)
	if ok and type(modpath) == "string" and modpath ~= "" then
		library = modpath .. "/wp13"
	end
end
if library == nil then
	error("WP13 Hearthpine: the building library directory is unknown", 0)
end

return dofile(library .. "/hearthpine.lua")(library)
