-- Locate the WP13 building library directory (`mods/MAPGEN/grug_mapgen/wp13`)
-- and load one composition out of it.
--
-- The directory is derived from this chunk's own source path, which works for
-- `dofile` from `r7_runtime.lua` inside the engine sandbox (whose
-- `debug.getinfo` is whitelisted) and for the plain interpreters that run
-- `tools/wp13/dump_blueprint.lua` and the WP13 fixtures. If the debug library
-- is unavailable, the engine's own mod path is the fallback.
--
-- Every `r7_*_blueprint.lua` wrapper is then three lines: find this file next
-- to itself, and ask it for its own composition. Both wrappers keep their file
-- names, schema strings, bounds contract, landmark keys and destination ids,
-- so the R7 successor, the manifest and the fixtures stay valid.
--
-- Plain Lua 5.1, no globals.

local M = {}

-- The directory holding the chunk `level` frames up the stack, or nil.
function M.directory_of(level)
	local ok, debug_table = pcall(function() return debug end)
	if not ok or type(debug_table) ~= "table" or
			type(debug_table.getinfo) ~= "function" then
		return nil
	end
	local info = debug_table.getinfo(level, "S")
	local source = type(info) == "table" and info.source or nil
	if type(source) ~= "string" or source:sub(1, 1) ~= "@" then return nil end
	local directory = source:sub(2):match("^(.*)[/\\][^/\\]*$")
	if directory == nil or directory == "" then return nil end
	return directory
end

function M.path()
	local directory = M.directory_of(2)
	if directory ~= nil then return directory .. "/../wp13" end
	local ok, modpath = pcall(function()
		return core.get_modpath("grug_mapgen")
	end)
	if ok and type(modpath) == "string" and modpath ~= "" then
		return modpath .. "/wp13"
	end
	error("WP13: the building library directory is unknown", 0)
end

-- `name` is a composition module in the library, e.g. "hearthpine".
function M.composition(name)
	local library = M.path()
	return dofile(library .. "/" .. name .. ".lua")(library)
end

return M
