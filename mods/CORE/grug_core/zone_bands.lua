-- Gameplay level bands that differ from the mapgen's zone records (Round 28
-- Lane S2c; the user, 2026-10-02): Gravesalt Escarpment and The Skyglass
-- Canopy run 51-60, so the level cap is reached in leveling zones (every zone
-- runs to its round level; the dragon islands are not leveling content). The
-- Broken Causeway runs 41-50 beside The Shattered Line (Round 28 W1; the user,
-- 2026-10-02): the three contested zones per faction are 31-40, both
-- Battlegrounds middle zones 41-50.
--
-- The mapgen keeps its own bands (grug_mapgen/wp40/source/simple_map.lua:
-- Gravesalt and Skyglass 51-59, the Causeway 31-40): they shape the analytic
-- level field (grug_zones.surface_mob_level_at) which places plants,
-- resources and P9G content, so changing them there would change the
-- generated world. The Causeway's analytic field, plants and resources stay
-- at 31-40 until the mapgen work of the next round moves them. In these zones the gameplay surface level comes
-- from the spawn regions (spawn_regions.md, "One level truth"), which follow
-- this band.
--
-- grug_zones.get and grug_zones.at serve these bands (zone_authority.lua);
-- the offline tools that build zone records from the mapgen source apply them
-- the same way (dofile this file). Pure data and one helper, no engine API.
local M = {}

M.bands = {
	front_broken_causeway = {41, 50},
	front_gravesalt_escarpment = {51, 60},
	front_skyglass_canopy = {51, 60},
}

-- Sets `record.level_min` / `level_max` to the zone's gameplay band. The
-- record is a copy the caller owns; `zone_id` defaults to `record.id`.
-- Returns the record (nil stays nil).
function M.apply(record, zone_id)
	local band = record and M.bands[zone_id or record.id]
	if band then
		record.level_min, record.level_max = band[1], band[2]
	end
	return record
end

return M
