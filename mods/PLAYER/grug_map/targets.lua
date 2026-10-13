-- Quest targets on the map window (Round 44, the UI rework spec ruling 14
-- and §3.6). Selecting a quest in the window marks where its open
-- objectives are done:
--   * a kill objective whose role is a named leader: a crosshair at the
--     leader's spot (spawn_regions.lua SR.leader_pos);
--   * any other kill objective: rings around the spawn regions of its area
--     (a kind or camp of a recipe, "zone/id") or, without an area, the
--     regions of the quest's zone whose kind or camp spawns its role (the
--     names that count come from those slots, grug_quests labels.lua
--     target_names);
--   * a kill objective whose area is no recipe region (a PvP garrison camp,
--     "zone/<settlement key>"): a crosshair at the camp; a role that spawns
--     in no region of the quest's zone but has a place of its own (the rift
--     boss at its site): a crosshair there. These may lie in the other
--     faction's land: a quest target shows wherever it is (the user,
--     2026-10-08);
--   * a talk objective: a crosshair at the NPC; a use objective: a crosshair
--     at its place.
-- Crosshairs come first (a quest "kill seven bandits and their leader"
-- shows the leader's crosshair however many rings there are); then at most
-- MAX_RINGS rings, the regions nearest the player. Every crosshair and ring
-- names the objectives it marks (their indices in def.objectives, Round 47:
-- the map's tooltips show their lines). A finished kill or use
-- objective marks nothing; a talk objective counts from the start (a
-- travel quest's destination), so its NPC stays marked while the quest is
-- active. Item objectives (gathering, ore, quest drops) and roles outside
-- the region maps without a place of their own (underground, water, rare
-- and critter spawns) mark nothing; the quest text suffices. Two objectives
-- at one spot share one crosshair.
--
-- The region index is built once at start from the cached region maps:
-- role -> regions and "zone/area" -> regions, each region {zone, x, z,
-- size} with its centroid and its size in cells; and leader role -> spot.
-- PURE Lua: the sources are injected, so the fixture runs it without the
-- engine.
local M = {}

M.MAX_RINGS = 5

-- sources: zone_ids() -> sorted list; map(zone) -> compact region map
-- (spawn_regions_cache.lua rehydrate) or nil; leader_roles() -> list;
-- leader_pos(role) -> {x, z} or nil. Returns the index.
function M.build(sources)
	local index = {roles = {}, areas = {}, leaders = {}, entries = 0}
	local function add(list_by, key, entry)
		local list = list_by[key]
		if not list then
			list = {}
			list_by[key] = list
		end
		list[#list + 1] = entry
	end
	for _, zone in ipairs(sources.zone_ids()) do
		local map = sources.map(zone)
		for _, region in ipairs(map and map.regions or {}) do
			local unit = region.kind
			local entry = {zone = zone, x = region.x, z = region.z, size = region.size}
			index.entries = index.entries + 1
			add(index.areas, zone .. "/" .. unit.id, entry)
			local roles = {}
			for role in pairs(unit.roles or {}) do roles[#roles + 1] = role end
			table.sort(roles)
			for _, role in ipairs(roles) do add(index.roles, role, entry) end
		end
	end
	for _, role in ipairs(sources.leader_roles()) do
		local spot = sources.leader_pos(role)
		if spot then index.leaders[role] = {x = spot.x, z = spot.z} end
	end
	return index
end

-- {roles, entries, areas, leaders}: the index's size, for the log.
function M.size(index)
	local roles, areas, leaders = 0, 0, 0
	for _ in pairs(index.roles) do roles = roles + 1 end
	for _ in pairs(index.areas) do areas = areas + 1 end
	for _ in pairs(index.leaders) do leaders = leaders + 1 end
	return {roles = roles, entries = index.entries, areas = areas, leaders = leaders}
end

-- The targets of quest `def` for a player at `pos` ({x, z}): {crosshairs =
-- {{x, z, objectives}, ...}, rings = {{x, z, size, objectives}, ...}}, with
-- `objectives` the indices of the objectives each marks, ascending. `progress` is the journal's
-- objective rows (count, required) in the order of def.objectives;
-- `lookup.npc(id)` and `lookup.place(ref)` give a talk NPC's and a use
-- place's {x, z} or nil; `lookup.area(ref)` a garrison camp's and
-- `lookup.role(role)` a role's own place (or nil).
function M.targets(index, def, progress, pos, lookup)
	local crosshairs, rings, seen = {}, {}, {}
	local spots = {}
	local current -- the objective being marked
	local function note(list)
		if list[#list] ~= current then list[#list + 1] = current end
	end
	local function crosshair(spot)
		local key = spot and (spot.x .. "," .. spot.z)
		if not key then return end
		local mark = spots[key]
		if not mark then
			mark = {x = spot.x, z = spot.z, objectives = {}}
			spots[key] = mark
			crosshairs[#crosshairs + 1] = mark
		end
		note(mark.objectives)
	end
	-- True when a region of the list (in `zone`, if given) is marked.
	local function ring_list(list, zone)
		local matched = false
		for _, entry in ipairs(list or {}) do
			if not zone or entry.zone == zone then
				local objectives = seen[entry]
				if not objectives then
					objectives = {}
					seen[entry] = objectives
					rings[#rings + 1] = entry
				end
				note(objectives)
				matched = true
			end
		end
		return matched
	end
	for index_, objective in ipairs(def.objectives) do
		current = index_
		local row = progress and progress[index_]
		local open = not row or row.count < row.required
		if objective.type == "talk" then
			crosshair(lookup.npc(objective.npc))
		elseif objective.type == "use" and open then
			crosshair(objective.place and lookup.place(objective.place))
		elseif objective.type == "kill" and open then
			for _, mob in ipairs(objective.mobs or {}) do
				local role = mob:match("^grug_mobs:(.+)$") or mob
				local leader = index.leaders[role]
				if leader then
					crosshair(leader)
				elseif objective.area then
					if index.areas[objective.area] then
						ring_list(index.areas[objective.area])
					else
						crosshair(lookup.area and lookup.area(objective.area))
					end
				else
					if not ring_list(index.roles[role], def.zone) then
						crosshair(lookup.role and lookup.role(role))
					end
				end
			end
		end
	end
	local function distance(entry)
		local dx, dz = entry.x - pos.x, entry.z - pos.z
		return dx * dx + dz * dz
	end
	table.sort(rings, function(a, b)
		local da, db = distance(a), distance(b)
		if da ~= db then return da < db end
		if a.x ~= b.x then return a.x < b.x end
		return a.z < b.z
	end)
	local nearest = {}
	for k = 1, math.min(M.MAX_RINGS, #rings) do
		local entry = rings[k]
		nearest[k] = {x = entry.x, z = entry.z, size = entry.size, objectives = seen[entry]}
	end
	return {crosshairs = crosshairs, rings = nearest}
end

-- A ring's radius in nodes for a region of `size` cells of `cell` nodes:
-- the radius of a disc of the region's area.
function M.ring_radius(size, cell)
	return math.sqrt(size * cell * cell / math.pi)
end

return M
