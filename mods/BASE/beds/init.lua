-- beds/init.lua

-- GRUG PATCH: beds are DECORATION ONLY in Grudgelands (no sleeping, no night
-- skip, no respawn point, no player attachment). Removed from this loader:
--   * `functions.lua` (deleted) - lie-down/stand-up, physics override, the
--     "x of y players are in bed" formspec, the night skip, the respawn and
--     die/leave callbacks.
--   * `spawns.lua` (deleted) - the `beds_spawns` world file reader/writer,
--     including the "PA's beds mod" old-file-format branch. Player spawn is
--     owned by grug_core; nothing here may write it.
--   * `beds.formspec`, `beds.day_interval` and the `player`/`bed_position`/
--     `pos`/`spawn` runtime tables, which only existed for the above.

-- Load support for MT game translation.
local S = minetest.get_translator("beds")

beds = {}
beds.get_translator = S

local modpath = minetest.get_modpath("beds")

-- Load files

dofile(modpath .. "/api.lua")
dofile(modpath .. "/beds.lua")
