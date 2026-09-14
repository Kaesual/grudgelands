-- Kapok Cradle is authored in local coordinates around the troll start.
-- The caller fits y = 0 to the settlement terrain before projecting the cells.
--
-- The architecture lives in the reusable WP13 building library under
-- `mods/MAPGEN/grug_mapgen/wp13/`; this file only locates that library and
-- returns its Kapok composition, which carries the same bounds contract
-- (x/z [-63, 63], y [-2, 24]), the same landmark keys and the same spawn
-- geometry as the other starts, under its own schema string. Its road, gate
-- and watchpost lie on NEGATIVE z: Kapok Cradle's start gate station is
-- 64 nodes south of its anchor, as every Kragmar start's is.
--
-- `r7_wp13_library.lua`, which sits next to this file, does the locating; the
-- only thing this wrapper has to work out for itself is where "next to this
-- file" is.

local info = debug and debug.getinfo and debug.getinfo(1, "S")
local here = type(info) == "table" and type(info.source) == "string" and
	info.source:sub(1, 1) == "@" and info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not here or here == "" then here = core.get_modpath("grug_mapgen") .. "/wp40" end

return dofile(here .. "/r7_wp13_library.lua").composition("kapok")
