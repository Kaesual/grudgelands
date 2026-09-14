-- Hearthpine Vale is authored in local coordinates around the dwarf start.
-- The caller fits y = 0 to the settlement terrain before projecting the cells.
--
-- The architecture itself lives in the reusable WP13 building library under
-- `mods/MAPGEN/grug_mapgen/wp13/`; this file only locates that library and
-- returns its Hearthpine composition unchanged, so the schema string, bounds
-- contract, landmark keys and destination ids of the first two increments
-- stay exactly as the R7 successor, the manifest and the fixtures expect.
--
-- `r7_wp13_library.lua`, which sits next to this file, does the locating; the
-- only thing this wrapper has to work out for itself is where "next to this
-- file" is.

local info = debug and debug.getinfo and debug.getinfo(1, "S")
local here = type(info) == "table" and type(info.source) == "string" and
	info.source:sub(1, 1) == "@" and info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not here or here == "" then here = core.get_modpath("grug_mapgen") .. "/wp40" end

return dofile(here .. "/r7_wp13_library.lua").composition("hearthpine")
