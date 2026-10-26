-- Export the shipped camp builders through the existing blueprint viewer.
-- Environment inputs are selected by build.py, not player input.
return function()
	local race = assert(os.getenv("CAMP_REVIEW_RACE"))
	local faction = assert(os.getenv("CAMP_REVIEW_FACTION"))
	local kind = assert(os.getenv("CAMP_REVIEW_KIND"))
	local file = kind == "mining_camp" and "r58_camp_blueprint.lua" or "r31_pvp_poi_blueprint.lua"
	local bp = dofile("mods/MAPGEN/grug_mapgen/wp40/" .. file)({}, {
		blueprint_schema = 1, art = {kind = kind, faction = faction,
			race = race, contested = true, turns = 0},
	})
	local landmarks = {}
	for _, socket in ipairs(bp.landmarks.sockets) do landmarks[socket.id] = socket end
	bp.landmarks = landmarks
	return bp
end
