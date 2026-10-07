-- The platform's map reset (grug_core/map_reset.lua, the upgrade contract):
-- every record in this mod's storage describes the old map's authored actors
-- and goes -- the settlement NPC markers and their respawn times
-- (start_npcs.lua), the rares (rares.lua), the island dragons (bosses.lua),
-- the zone leaders' timers (spawn_regions.lua), the rift's written crack and
-- its boss timer (rift.lua) and the liveness places and absences
-- (liveness.lua). The world then fills as a fresh one does. Only the liveness
-- generations (`live_gen:<key>`) count on: monotonic, so a copy of an older
-- generation can never come back. Runs before any of those files reads the
-- storage; idempotent.
local storage = grug_mobs.storage
local KEEP = "live_gen:"

grug_core.map_reset.clear("the grug_mobs actor records", function()
	for _, key in ipairs(storage:get_keys()) do
		if key:sub(1, #KEEP) ~= KEEP then
			storage:set_string(key, "")
		end
	end
end)
