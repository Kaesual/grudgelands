--
-- Round 28 Lane S1: the region map of a zone (pure Lua 5.1, no engine call).
--
-- A zone's spawn data holds a RECIPE (rules), never coordinates. From the
-- recipe and the analytic world (the same model the mapgen builds terrain
-- from) this module builds the zone's REGION MAP on a 32x32-node cell grid.
-- The game (spawn_regions.lua) and the offline renderer (tools/r28_regions)
-- run this very file with the same query adapter (M.queries), so the images
-- reviewed are exactly what spawns in the game, for any seed.
--
--   local core = dofile(".../spawn_regions_core.lua")
--   local recipe = core.parse_recipe(zone_id, data.recipe, ctx)  -- or error
--   local q = core.queries(env)                                  -- adapter
--   local map = core.build(zone_id, q, recipe)
--   map.region_at(x, z) -> region or nil
--
-- The steps (docs/design/spawn_regions.md):
--   1. Cells: the zone's land on a grid aligned to world multiples of 32,
--      each cell sampled on a 4x4 sub-grid (8-node pitch). A cell belongs to
--      the zone owning most of its samples; a cell with fewer than half land
--      samples is water. Per land cell: majority biome, mean height, slope,
--      the shares of its land samples near sea water (shore), near river or
--      lake water (bank), inside the 16-node road/town/village drift band
--      and on protected ground, and its distance to the nearest road.
--   2. Progress: graph distances over the land cells (8 neighbours) from the
--      recipe's `from` (anchors, or the land border with the zones the
--      player enters from) and to its `to`; progress = d_from / (d_from +
--      d_to), or with `to` core the rank of d_from alone (the cells farthest
--      from every source are the top belt). Cells cut off over land take the
--      progress of the nearest reachable cell.
--   3. Belts: land cells sorted by progress, cut by area share; a belt's
--      optional `max_from` pushes cells farther than that to the next belt.
--   4. Types: shore > bank > swamp > forest > highland > open.
--   5. Regions: connected cells of one kind (the kind a belt gives a type);
--      small fragments merge into the neighbour they share most edges with
--      (same belt preferred), large ones split into compact parts.
--   6. Population: a kind's day and night rosters, levels belt-range x role
--      range, a density class.
--   7. Camps: on a camp POI of the world model (the cells the camp radius
--      reaches), or scored by rule (a 3x3-cell region each).
--   8. Leaders: at a camp centre or deep inside the largest region of a kind.
-- Deterministic: no random numbers, no dependence on `pairs` order.
--
local M = {}

M.CELL = 32           -- cell side, nodes
M.SUB = 4             -- samples per cell side
M.PITCH = 8           -- sample pitch, nodes (CELL / SUB)
M.SHORE_REACH = 16    -- a land sample this close to sea water is shore ground
M.BANK_REACH = 16     -- ... to river or lake water is bank ground
M.DRIFT = 16          -- the road/town/village drift band (Round 28 ruling 2)
M.CORRIDOR = 4        -- road centreline distance counted as protected ground
M.SITE_HALF = 12      -- half side of a village/POI/camp core box
M.ROAD_CAP = 128      -- road distances are measured up to this
-- Type thresholds (shares of a cell's land samples, heights in nodes).
M.SHORE_SHARE = 0.25
M.BANK_SHARE = 0.25
M.HIGH_SLOPE = 0.5    -- mean |dh| per node between neighbouring samples
M.HIGH_RANK = 0.9     -- height rank among the zone's land cells ...
M.HIGH_ABOVE = 16     -- ... and at least this far above the zone median
-- Region sizes in cells (a cell is 32 x 32 nodes).
M.MIN_CELLS = 8
M.MIN_STRIP = 3       -- shore kinds: a narrow beach stays its own region
M.MAX_CELLS = 40
M.SPLIT_TARGET = 25
M.LLOYD_ROUNDS = 3
-- Camps: a 3x3-cell block, rule-scored.
M.CAMP_ROAD_MIN = 48
M.CAMP_SLOPE = 0.35
M.CAMP_RADIUS = 40    -- slot spots are drawn within this of the centre
-- Camp POIs of the world model (the zone atlas's `camps`): the anchor
-- template -> the POI type a recipe camp's site names. Guard posts are
-- listed so a recipe naming one gets a clear error; they are no mob camp.
M.POI_TYPES = {bandit_home = "bandit", bandit_frontier = "bandit",
	mirefolk = "mirefolk", outpost = "guard post"}
M.CAMP_POIS = {bandit = true, mirefolk = true}
-- Density classes: the share of the zone's density budget a region may use
-- (never above the budget itself).
M.DENSITY = {sparse = 0.5, normal = 0.75, dense = 1}
M.TYPES = {"shore", "bank", "swamp", "forest", "highland", "open"}
M.FOREST_BIOMES = {deep_forest = true, elf_forest = true, pine_hills = true,
	bone_forest = true, deep_jungle = true, jungle_edge = true, jungle_fringe = true}
M.MAX_MINOR = 0.25    -- a roster's minor role: at most this share of weight

local floor, sqrt, huge = math.floor, math.sqrt, math.huge
local OFF, SPAN = 32768, 65536

local function key(i, j)
	return (i + OFF) * SPAN + (j + OFF)
end

local function fail(where, message)
	error("[grug_mobs] spawn recipe " .. where .. ": " .. message, 0)
end

local function is_int(value, lo, hi)
	return type(value) == "number" and value % 1 == 0 and
		(lo == nil or value >= lo) and (hi == nil or value <= hi)
end

local function is_num(value)
	return type(value) == "number" and value == value and
		value ~= huge and value ~= -huge
end

local function snake(id)
	return type(id) == "string" and id:match("^[a-z][a-z0-9_]*$") ~= nil
end

local function known_keys(row, allowed, where)
	local bad = {}
	for k in pairs(row) do
		if not allowed[k] then bad[#bad + 1] = tostring(k) end
	end
	if #bad > 0 then
		table.sort(bad)
		fail(where, "unknown field " .. table.concat(bad, ", "))
	end
end

local function level_pair(value)
	return type(value) == "table" and #value == 2 and is_int(value[1], 1, 60) and
		is_int(value[2], 1, 60) and value[1] <= value[2]
end

--
-- Recipe parsing
--
-- `ctx`: band = {lo, hi} (the zone's levels), role_levels(role) -> {lo, hi}
-- or nil (an existing mob outside the catalogue: no limit), leader(role) ->
-- true when the catalogue marks the role a leader. Errors name the zone and
-- the recipe path.
--

local RECIPE_KEYS = {from = true, to = true, belts = true, camps = true,
	leaders = true, critters = true, notes = true}
local BELT_KEYS = {id = true, share = true, levels = true, max_from = true,
	kinds = true, notes = true}
local KIND_KEYS = {id = true, name = true, day = true, night = true,
	density = true, notes = true}
local CAMP_KEYS = {id = true, name = true, belt = true, site = true, roster = true,
	slots = true, respawn = true, min_player_distance = true, apart = true,
	notes = true}
local LEADER_KEYS = {role = true, at = true, respawn = true, notes = true}
local TYPE_SET = {}
for _, t in ipairs(M.TYPES) do TYPE_SET[t] = true end

-- One roster: a list of {role, weight}, one main role and at most one minor
-- role of at most MAX_MINOR of the weight.
local function parse_roster(list, where)
	if type(list) ~= "table" or #list == 0 or #list > 2 then
		fail(where, "a roster lists one main role and at most one minor role")
	end
	local out, total, seen = {}, 0, {}
	for i = 1, #list do
		local row = list[i]
		if type(row) ~= "table" or type(row.role) ~= "string" or row.role == "" or
				not is_num(row.weight) or row.weight <= 0 then
			fail(where, "roster entries need a role and a positive weight")
		end
		known_keys(row, {role = true, weight = true}, where)
		if seen[row.role] then
			fail(where, "role " .. row.role .. " is listed twice")
		end
		seen[row.role] = true
		out[i] = {role = row.role, weight = row.weight}
		total = total + row.weight
	end
	if #out == 2 then
		local minor = math.min(out[1].weight, out[2].weight)
		if minor > total * M.MAX_MINOR + 1e-9 then
			fail(where, "the minor role may hold at most " ..
				floor(M.MAX_MINOR * 100 + 0.5) .. " % of the weight")
		end
	end
	return {list = out, total = total}
end

-- Levels of `role` inside `levels` (a belt): the intersection, or an error.
local function role_range(ctx, role, levels, where)
	local lo, hi = levels[1], levels[2]
	local own = ctx.role_levels and ctx.role_levels(role)
	if own then
		lo, hi = math.max(lo, own[1]), math.min(hi, own[2])
		if lo > hi then
			fail(where, ("%s (levels %d-%d) never meets the belt's levels %d-%d"):format(
				role, own[1], own[2], levels[1], levels[2]))
		end
	end
	return {lo, hi}
end

-- A unit's level table: per role its range, and the union over the roles.
local function unit_levels(ctx, unit, rosters, levels, where)
	unit.levels_by_role = {}
	unit.roles = {}
	local lo, hi
	for _, roster in ipairs(rosters) do
		for _, row in ipairs(roster.list) do
			local range = role_range(ctx, row.role, levels, where)
			unit.levels_by_role[row.role] = range
			unit.roles[row.role] = true
			lo = lo and math.min(lo, range[1]) or range[1]
			hi = hi and math.max(hi, range[2]) or range[2]
		end
	end
	unit.levels = {lo, hi}
end

-- Coverage (the user, 2026-10-02): every zone runs to its round level (a
-- start zone to 10, the next zone to 20, ...), so the next zone starts at
-- the next round level. A kind's roster covers its whole belt at each clock:
-- the union of its roles' ranges (each already cut to the belt) has no gap
-- and runs from the belt's bottom to its top. A camp may start above its
-- belt's bottom (bandits L9-10 in an L8-10 belt) but has no gap and reaches
-- the top.
local function check_cover(unit, roster, levels, from_bottom, where)
	local ranges = {}
	for _, row in ipairs(roster.list) do
		ranges[#ranges + 1] = unit.levels_by_role[row.role]
	end
	table.sort(ranges, function(a, b) return a[1] < b[1] end)
	local lo = from_bottom and levels[1] or ranges[1][1]
	local reached = lo - 1
	for _, range in ipairs(ranges) do
		if range[1] > reached + 1 then break end
		if range[2] > reached then reached = range[2] end
	end
	if reached < levels[2] or (from_bottom and ranges[1][1] > levels[1]) then
		local parts = {}
		for _, range in ipairs(ranges) do
			parts[#parts + 1] = range[1] == range[2] and ("L" .. range[1]) or
				("L%d-%d"):format(range[1], range[2])
		end
		fail(where, ("roles cover %s of the belt's L%d-%d: %s [cover]"):format(
			table.concat(parts, ", "), levels[1], levels[2], from_bottom and
			"every kind covers its whole belt at each clock" or
			"a camp has no gap and reaches its belt's top"))
	end
end

function M.parse_recipe(zone_id, recipe, ctx)
	local where = tostring(zone_id)
	if type(recipe) ~= "table" then
		fail(where, "recipe must be an object")
	end
	known_keys(recipe, RECIPE_KEYS, where)
	local band = ctx.band or {1, 60}
	local out = {zone = zone_id, belts = {}, kinds = {}, kind_by_id = {},
		camps = {}, camp_by_id = {}, leaders = {}, critters = {}}
	-- from / to (Round 28 S2): `from` names anchors of the zone or the zones
	-- whose land border is the entry; `to` the exit border or the zone's
	-- core. A one-belt recipe has no progression and may omit `to` (and then
	-- `from`).
	local one_belt = type(recipe.belts) == "table" and #recipe.belts == 1
	local function zone_ids(value, w)
		local list = type(value) == "string" and {value} or value
		if type(list) ~= "table" or #list == 0 then
			fail(w, "needs a zone id or a list of zone ids")
		end
		local ids = {}
		for i = 1, #list do
			if type(list[i]) ~= "string" or list[i] == "" or list[i] == zone_id then
				fail(w, "border entries are other zones' ids")
			end
			ids[i] = list[i]
		end
		return ids
	end
	local from, to = recipe.from, recipe.to
	if to == nil and not one_belt then
		fail(where .. " to", "needs {\"border\": <zone id or list>} or {\"core\": true} " ..
			"(only a one-belt recipe may omit it)")
	end
	if from == nil and to ~= nil then
		fail(where .. " from", "needs {\"anchor\": <slot or anchor id, or a list>} or " ..
			"{\"border\": <zone id or list>}")
	end
	if from ~= nil then
		if type(from) ~= "table" or (from.anchor == nil) == (from.border == nil) then
			fail(where .. " from", "needs {\"anchor\": <slot or anchor id, or a list>} or " ..
				"{\"border\": <zone id or list>}")
		end
		known_keys(from, {anchor = true, border = true}, where .. " from")
		if from.anchor ~= nil then
			local list = type(from.anchor) == "string" and {from.anchor} or from.anchor
			if type(list) ~= "table" or #list == 0 then
				fail(where .. " from", "anchor is a slot or anchor id, or a list of them")
			end
			out.from = {anchors = {}}
			for i = 1, #list do
				if type(list[i]) ~= "string" or list[i] == "" then
					fail(where .. " from", "anchor is a slot or anchor id, or a list of them")
				end
				out.from.anchors[i] = list[i]
			end
		else
			out.from = {border = zone_ids(from.border, where .. " from")}
		end
	end
	if to ~= nil then
		if type(to) ~= "table" or (to.border == nil) == (to.core == nil) then
			fail(where .. " to", "needs {\"border\": <zone id or list>} or {\"core\": true}")
		end
		known_keys(to, {border = true, core = true}, where .. " to")
		if to.core ~= nil then
			if to.core ~= true then fail(where .. " to", "core must be true") end
			out.to = {core = true}
		else
			out.to = {border = zone_ids(to.border, where .. " to")}
			for _, id in ipairs(out.to.border) do
				for _, other in ipairs(out.from.border or {}) do
					if other == id then
						fail(where .. " to", id .. " is both the entry and the exit border")
					end
				end
			end
		end
	end
	-- belts
	if type(recipe.belts) ~= "table" or #recipe.belts == 0 then
		fail(where, "belts must be a non-empty list")
	end
	local share_sum, belt_ids = 0, {}
	for b = 1, #recipe.belts do
		local row = recipe.belts[b]
		local bw = where .. " belts[" .. b .. "]"
		if type(row) ~= "table" then fail(bw, "belt must be an object") end
		known_keys(row, BELT_KEYS, bw)
		if not snake(row.id) or belt_ids[row.id] then
			fail(bw, "belt id must be snake_case and unique")
		end
		belt_ids[row.id] = b
		bw = where .. " belt " .. row.id
		if not is_num(row.share) or row.share <= 0 then
			fail(bw, "share must be a positive percentage")
		end
		share_sum = share_sum + row.share
		if not level_pair(row.levels) then
			fail(bw, "levels must be [lo, hi] integers within 1..60")
		end
		if row.levels[1] < band[1] or row.levels[2] > band[2] then
			fail(bw, ("levels %d-%d leave the zone's band %d-%d"):format(
				row.levels[1], row.levels[2], band[1], band[2]))
		end
		if row.max_from ~= nil and (not is_num(row.max_from) or row.max_from <= 0) then
			fail(bw, "max_from must be a positive distance in nodes")
		end
		local belt = {index = b, id = row.id, share = row.share,
			levels = {row.levels[1], row.levels[2]}, max_from = row.max_from, kinds = {}}
		if type(row.kinds) ~= "table" or type(row.kinds.open) ~= "table" then
			fail(bw, "every belt defines kinds.open (the parent of its other types)")
		end
		for t in pairs(row.kinds) do
			if not TYPE_SET[t] then
				fail(bw, "kinds." .. tostring(t) .. " is not a terrain type")
			end
		end
		-- Types in fixed order: the open entry first (the others inherit
		-- from it), then the rest.
		local order = {"open"}
		for _, t in ipairs(M.TYPES) do
			if t ~= "open" then order[#order + 1] = t end
		end
		for _, t in ipairs(order) do
			local krow = row.kinds[t]
			if krow ~= nil then
				local kw = bw .. " kinds." .. t
				if type(krow) ~= "table" then fail(kw, "kind must be an object") end
				known_keys(krow, KIND_KEYS, kw)
				if not snake(krow.id) then fail(kw, "kind id must be snake_case") end
				if out.kind_by_id[krow.id] then
					fail(kw, "kind id " .. krow.id .. " is used twice in the zone")
				end
				if type(krow.name) ~= "string" or krow.name == "" then
					fail(kw, "kind needs a display name")
				end
				if not M.DENSITY[krow.density] then
					fail(kw, "density must be sparse, normal or dense")
				end
				local kind = {id = krow.id, name = krow.name, type = t, belt = belt,
					density = krow.density, tag = zone_id .. "/" .. krow.id, rosters = {}}
				for _, clock in ipairs({"day", "night"}) do
					local value = krow[clock]
					if value == "open" then
						if t == "open" then
							fail(kw, clock .. " \"open\" names the parent; the open kind lists roles")
						end
						kind.rosters[clock] = belt.kinds.open.rosters[clock]
						kind.inherits = kind.inherits or {}
						kind.inherits[clock] = true
					elseif value == nil then
						fail(kw, "needs a " .. clock .. " roster (a role list, or \"open\")")
					else
						kind.rosters[clock] = parse_roster(value, kw .. "." .. clock)
					end
				end
				unit_levels(ctx, kind, {kind.rosters.day, kind.rosters.night},
					belt.levels, kw)
				for _, clock in ipairs({"day", "night"}) do
					check_cover(kind, kind.rosters[clock], belt.levels, true, kw .. "." .. clock)
				end
				belt.kinds[t] = kind
				out.kinds[#out.kinds + 1] = kind
				out.kind_by_id[kind.id] = kind
			end
		end
		out.belts[b] = belt
	end
	if math.abs(share_sum - 100) > 1e-6 then
		fail(where, "belt shares must add up to 100 (they add up to " .. share_sum .. ")")
	end
	-- The last belt (the exit) ends at the top of the zone's band.
	local top = out.belts[#out.belts].levels[2]
	if top ~= band[2] then
		fail(where .. " belt " .. out.belts[#out.belts].id, ("the last belt ends at L%d, " ..
			"the zone's band at L%d: every zone runs to its round level [cover]"):format(top, band[2]))
	end
	-- camps
	if recipe.camps ~= nil and type(recipe.camps) ~= "table" then
		fail(where, "camps must be a list")
	end
	-- `site`: "generate" (default) or {"poi": <type>, "name": <POI name>}.
	-- ctx.pois(zone) lists the zone's camp POIs (M.zone_pois); a type the
	-- zone does not have is an error, so is a type it has twice unnamed.
	local poi_used = {}
	local function parse_site(site, cw)
		if site == nil or site == "generate" then
			return "generate"
		end
		if type(site) ~= "table" or type(site.poi) ~= "string" then
			fail(cw, "site is \"generate\" or {\"poi\": <type>, \"name\": <POI name>}")
		end
		known_keys(site, {poi = true, name = true}, cw .. " site")
		if not M.CAMP_POIS[site.poi] then
			fail(cw, "site.poi " .. site.poi .. " is not a mob camp POI (bandit or mirefolk; " ..
				"guard posts keep their guards)")
		end
		if site.name ~= nil and (type(site.name) ~= "string" or site.name == "") then
			fail(cw, "site.name must be the POI's name")
		end
		local found, names = {}, {}
		for _, poi in ipairs(ctx.pois and ctx.pois(zone_id) or {}) do
			if poi.poi == site.poi then
				names[#names + 1] = poi.name
				if site.name == nil or poi.name == site.name then
					found[#found + 1] = poi
				end
			end
		end
		if #found == 0 then
			fail(cw, ("the zone has no %s POI%s"):format(site.poi, site.name and
				(" named " .. site.name .. " (its " .. site.poi .. " POIs: " ..
				(#names > 0 and table.concat(names, ", ") or "none") .. ")") or ""))
		end
		if #found > 1 then
			fail(cw, ("the zone has %d %s POIs (%s): site.name picks one"):format(
				#found, site.poi, table.concat(names, ", ")))
		end
		local poi = found[1]
		if poi_used[poi.id] then
			fail(cw, "POI " .. poi.name .. " already holds camp " .. poi_used[poi.id])
		end
		poi_used[poi.id] = cw
		return {poi = site.poi, name = poi.name, anchor = poi.id}
	end
	for c = 1, #(recipe.camps or {}) do
		local row = recipe.camps[c]
		local cw = where .. " camps[" .. c .. "]"
		if type(row) ~= "table" then fail(cw, "camp must be an object") end
		known_keys(row, CAMP_KEYS, cw)
		if not snake(row.id) or out.kind_by_id[row.id] or out.camp_by_id[row.id] then
			fail(cw, "camp id must be snake_case and unique among kinds and camps")
		end
		cw = where .. " camp " .. row.id
		if type(row.name) ~= "string" or row.name == "" then
			fail(cw, "camp needs a display name")
		end
		-- The site: generated by rule (the default), or a camp POI of the
		-- world model (Round 28 S2), whose belt is the one it lies in unless
		-- the camp states one.
		local site = parse_site(row.site, cw)
		local b = belt_ids[row.belt]
		if not b and (row.belt ~= nil or site == "generate") then
			fail(cw, "belt " .. tostring(row.belt) .. " is not a belt of the recipe")
		end
		if not is_int(row.slots, 1) then fail(cw, "slots must be an integer >= 1") end
		if not (type(row.respawn) == "table" and #row.respawn == 2 and
				is_int(row.respawn[1], 1) and is_int(row.respawn[2], row.respawn[1])) then
			fail(cw, "respawn must be [min, max] seconds")
		end
		if not is_num(row.min_player_distance) or row.min_player_distance < 0 then
			fail(cw, "min_player_distance must be a distance in nodes")
		end
		if site ~= "generate" then
			if row.apart ~= nil then
				fail(cw, "apart places a generated site; a camp on a POI stands where the POI is")
			end
		elseif not is_int(row.apart, 1) then
			fail(cw, "apart (cells between two camps) must be an integer >= 1")
		end
		local roster = parse_roster(row.roster, cw .. ".roster")
		local camp = {id = row.id, name = row.name, belt = b and out.belts[b] or nil,
			site = site, tag = zone_id .. "/" .. row.id, roster = roster,
			rosters = {day = roster, night = roster}, density = "dense",
			slots = row.slots, respawn = {row.respawn[1], row.respawn[2]},
			min_player_distance = row.min_player_distance, apart = row.apart,
			is_camp = true}
		if camp.belt then
			unit_levels(ctx, camp, {roster}, camp.belt.levels, cw)
			check_cover(camp, roster, camp.belt.levels, false, cw)
		else
			-- The belt is the POI's on each seed: the roles' levels within the
			-- zone's band here; the build cuts them to the belt and checks the
			-- cover there (M.camp_levels).
			unit_levels(ctx, camp, {roster}, band, cw)
		end
		out.camps[#out.camps + 1] = camp
		out.camp_by_id[camp.id] = camp
	end
	-- leaders
	if recipe.leaders ~= nil and type(recipe.leaders) ~= "table" then
		fail(where, "leaders must be a list")
	end
	local leader_roles = {}
	for l = 1, #(recipe.leaders or {}) do
		local row = recipe.leaders[l]
		local lw = where .. " leaders[" .. l .. "]"
		if type(row) ~= "table" or type(row.role) ~= "string" or row.role == "" then
			fail(lw, "leader needs a role")
		end
		known_keys(row, LEADER_KEYS, lw)
		lw = where .. " leader " .. row.role
		if leader_roles[row.role] then fail(lw, "is placed twice") end
		leader_roles[row.role] = true
		if ctx.leader and not ctx.leader(row.role) then
			fail(lw, "the catalogue does not mark " .. row.role .. " a leader")
		end
		if not is_int(row.respawn, 1) then fail(lw, "respawn must be seconds") end
		local at = row.at
		if type(at) ~= "table" then fail(lw, "needs at: {camp} or {kind, pick}") end
		known_keys(at, {camp = true, kind = true, pick = true}, lw .. " at")
		local leader = {role = row.role, respawn = row.respawn}
		local belt
		if at.camp ~= nil then
			if at.kind ~= nil or at.pick ~= nil then fail(lw, "at names a camp or a kind, not both") end
			local camp = out.camp_by_id[at.camp]
			if not camp then fail(lw, "camp " .. tostring(at.camp) .. " is not a camp of the recipe") end
			if not camp.belt then
				-- A leader's level is fixed (ruling 38); a POI's belt may
				-- differ per seed.
				fail(lw, "camp " .. camp.id .. " states no belt: a leader's camp states its " ..
					"belt, so the leader's level is the same on every seed")
			end
			leader.camp, belt = camp, camp.belt
		else
			local kind = out.kind_by_id[at.kind]
			if not kind then fail(lw, "kind " .. tostring(at.kind) .. " is not a kind of the recipe") end
			if at.pick ~= "farthest_from_roads" then
				fail(lw, "pick must be farthest_from_roads")
			end
			leader.kind, leader.pick, belt = kind, at.pick, kind.belt
		end
		-- The top of the leader's region, within the leader role's levels.
		local range = role_range(ctx, row.role, belt.levels, lw)
		leader.level = range[2]
		out.leaders[#out.leaders + 1] = leader
	end
	-- critters
	if recipe.critters ~= nil and type(recipe.critters) ~= "table" then
		fail(where, "critters must be a list of roles")
	end
	for i = 1, #(recipe.critters or {}) do
		local role = recipe.critters[i]
		if type(role) ~= "string" or role == "" then
			fail(where, "critters must be a list of roles")
		end
		out.critters[role] = true
	end
	return out
end

-- The kind a belt gives a terrain type: its own entry or the belt's open
-- entry (the explicit parent rule).
function M.kind_for(belt, cell_type)
	return belt.kinds[cell_type] or belt.kinds.open
end

-- The zone's camp POIs, {id, slot, poi, name} in anchor order: the anchors
-- of the world model's source (simple_map: seed-independent identities; the
-- position is fitted per seed) whose template M.POI_TYPES names. `labels`:
-- anchor id -> the POI's name (the settlement roster's label); the anchor id
-- without one.
function M.zone_pois(source, zone_id, labels)
	local numeric
	for _, row in ipairs(source.zones) do
		if row.id == zone_id then numeric = row.numeric_id end
	end
	local out = {}
	for _, row in ipairs(source.anchors) do
		local poi = row.zone_numeric_id == numeric and M.POI_TYPES[row.template_id]
		if poi then
			out[#out + 1] = {id = row.id, slot = row.slot_id, poi = poi,
				name = labels and labels[row.id] or row.id}
		end
	end
	return out
end

-- A camp in `belt`: {levels_by_role, levels} with each role's levels cut to
-- the belt, and the camp cover rule (no gap, reaches the belt's top). For a
-- camp on a POI without its own belt, on the belt the POI lies in; errors
-- name the camp.
function M.camp_levels(zone_id, camp, belt)
	if camp.belt then
		return {levels_by_role = camp.levels_by_role, levels = camp.levels}
	end
	local cw = zone_id .. " camp " .. camp.id .. " (on " .. camp.site.name ..
		", belt " .. belt.id .. ")"
	local unit = {levels_by_role = {}}
	local lo, hi
	for _, row in ipairs(camp.roster.list) do
		local own = camp.levels_by_role[row.role]
		local a, b = math.max(own[1], belt.levels[1]), math.min(own[2], belt.levels[2])
		if a > b then
			fail(cw, ("%s (levels %d-%d) never meets the belt's levels %d-%d"):format(
				row.role, own[1], own[2], belt.levels[1], belt.levels[2]))
		end
		unit.levels_by_role[row.role] = {a, b}
		lo, hi = lo and math.min(lo, a) or a, hi and math.max(hi, b) or b
	end
	unit.levels = {lo, hi}
	check_cover(unit, camp.roster, belt.levels, false, cw)
	return unit
end

--
-- The query adapter, shared by the game and the renderer.
--
-- `env`: zones (grug_zones or the offline session: id_at, water_class_at,
-- terrain_height_at, biome_at, hard_protection_kind_at, anchor, get),
-- column_values_at (the planner column source: its 8th value names inland
-- water), road_polylines (list of {kind, points = {{x, z}}}), source (the
-- mapgen's simple_map source: zones and anchors). Returns the queries the
-- builder reads for one zone at a time.
--
function M.queries(env)
	local zones, column_values_at = env.zones, env.column_values_at
	local q = {}
	function q.zone_at(x, z)
		return zones.id_at(x, z)
	end
	-- "land", "sea" or "inland" (rivers and lakes are planned water that
	-- the planner names; the rest of the water is the sea's).
	function q.water_at(x, z)
		local wc = zones.water_class_at(x, z)
		if wc == "land" then
			return "land"
		end
		if wc == "planned_water" then
			local _, _, _, _, _, _, _, river = column_values_at(x, z)
			if river ~= nil then
				return "inland"
			end
		end
		return "sea"
	end
	function q.height_at(x, z)
		return zones.terrain_height_at(x, z)
	end
	function q.biome_at(x, z)
		local b = zones.biome_at(x, z)
		if type(b) == "string" and b:sub(1, 5) == "grug_" then
			return b:sub(6)
		end
		return b
	end
	function q.protection_at(x, y, z)
		return zones.hard_protection_kind_at({x = x, y = y, z = z})
	end
	function q.hub(zone_id)
		local record = zones.get(zone_id)
		return record and record.hub
	end
	q.roads = env.road_polylines or {}
	-- The zone's anchors: {id, slot, x, z}, in source order.
	function q.anchors(zone_id)
		local out, numeric = {}, nil
		for _, row in ipairs(env.source.zones) do
			if row.id == zone_id then numeric = row.numeric_id end
		end
		for _, row in ipairs(env.source.anchors) do
			if row.zone_numeric_id == numeric then
				local a = zones.anchor(zone_id, row.slot_id)
				if a then
					out[#out + 1] = {id = row.id, slot = row.slot_id, x = a.x, z = a.z}
				end
			end
		end
		return out
	end
	return q
end

--
-- Building
--

-- A tiny binary heap of {d, order, item} (smallest d, then order).
local function heap_push(h, d, o, item)
	local n = #h + 1
	h[n] = {d, o, item}
	while n > 1 do
		local p = floor(n / 2)
		local a, b = h[p], h[n]
		if a[1] < b[1] or (a[1] == b[1] and a[2] <= b[2]) then break end
		h[p], h[n] = b, a
		n = p
	end
end

local function heap_pop(h)
	local top = h[1]
	local n = #h
	h[1] = h[n]
	h[n] = nil
	n = n - 1
	local i = 1
	while true do
		local l, r, m = 2 * i, 2 * i + 1, i
		if l <= n and (h[l][1] < h[m][1] or (h[l][1] == h[m][1] and h[l][2] < h[m][2])) then m = l end
		if r <= n and (h[r][1] < h[m][1] or (h[r][1] == h[m][1] and h[r][2] < h[m][2])) then m = r end
		if m == i then break end
		h[i], h[m] = h[m], h[i]
		i = m
	end
	return top
end

local N8 = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
local N4 = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
local SQRT2 = sqrt(2)

-- Graph distances (in cells) over `cells` (key -> cell with .order) from the
-- sources, 8 neighbours, diagonal steps sqrt(2).
local function dijkstra(cells, sources, field)
	local h = {}
	for _, c in ipairs(sources) do
		c[field] = 0
		heap_push(h, 0, c.order, c)
	end
	while #h > 0 do
		local top = heap_pop(h)
		local d, c = top[1], top[3]
		if d <= c[field] then
			for n = 1, 8 do
				local o = N8[n]
				local nb = cells[key(c.i + o[1], c.j + o[2])]
				if nb then
					local nd = d + (n > 4 and SQRT2 or 1)
					if nd < nb[field] - 1e-12 then
						nb[field] = nd
						heap_push(h, nd, nb.order, nb)
					end
				end
			end
		end
	end
end

-- Segment distance from (px, pz) to (ax, az)-(bx, bz).
local function seg_dist(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = 0
	if len2 > 0 then
		t = ((px - ax) * dx + (pz - az) * dz) / len2
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
	end
	local ex, ez = ax + t * dx - px, az + t * dz - pz
	return sqrt(ex * ex + ez * ez)
end

local function box_dist(px, pz, x0, z0, x1, z1)
	local dx = px < x0 and x0 - px or (px > x1 and px - x1 or 0)
	local dz = pz < z0 and z0 - pz or (pz > z1 and pz - z1 or 0)
	return sqrt(dx * dx + dz * dz)
end

-- Sample offsets (in samples) within `reach` nodes.
local function disk(reach)
	local r = floor(reach / M.PITCH)
	local out = {}
	for a = -r, r do
		for b = -r, r do
			if (a * a + b * b) * M.PITCH * M.PITCH <= reach * reach then
				out[#out + 1] = {a, b}
			end
		end
	end
	return out
end

function M.build(zone_id, q, recipe)
	local CELL, SUB, PITCH = M.CELL, M.SUB, M.PITCH
	local problems = {}
	local map = {zone = zone_id, recipe = recipe, problems = problems}

	-- Samples: global sample coords (sx, sz) at world (8 sx + 4, 8 sz + 4).
	local s_owner, s_water, s_h, s_biome, s_prot = {}, {}, {}, {}, {}
	local WATER_CODE = {land = 1, sea = 2, inland = 3}
	local function sample(sx, sz)
		local k = key(sx, sz)
		if s_water[k] then return k end
		local x, z = sx * PITCH + PITCH / 2, sz * PITCH + PITCH / 2
		s_owner[k] = q.zone_at(x, z) or false
		local w = WATER_CODE[q.water_at(x, z)] or 2
		s_water[k] = w
		if w == 1 and s_owner[k] == zone_id then
			local h = q.height_at(x, z)
			s_h[k] = h
			s_biome[k] = q.biome_at(x, z) or false
			s_prot[k] = q.protection_at(x, h + 1, z) or false
		end
		return k
	end

	-- 1. Cells: a flood over every cell with at least one own sample, plus
	-- a one-cell margin (sampled for water and owner only).
	local seen, touched = {}, {}
	local all_cells = {} -- key -> {i, j, own = n, land = n, owner = id}
	local queue, head = {}, 1
	local function enqueue(i, j)
		local k = key(i, j)
		if not seen[k] then
			seen[k] = true
			queue[#queue + 1] = {i, j}
		end
	end
	local starts = {}
	local hub = q.hub(zone_id)
	if hub then starts[#starts + 1] = {hub.x, hub.z} end
	local anchors = q.anchors(zone_id)
	local anchor_by_ref = {}
	for _, a in ipairs(anchors) do
		anchor_by_ref[a.slot] = a
		anchor_by_ref[a.id] = a
	end
	local from_anchors = {}
	for _, ref in ipairs(recipe.from and recipe.from.anchors or {}) do
		local a = anchor_by_ref[ref]
		if not a then
			error("[grug_mobs] spawn regions " .. zone_id .. ": from anchor " ..
				ref .. " is not an anchor of the zone", 0)
		end
		from_anchors[#from_anchors + 1] = a
		starts[#starts + 1] = {a.x, a.z}
	end
	for _, s in ipairs(starts) do
		enqueue(floor(s[1] / CELL), floor(s[2] / CELL))
	end
	while head <= #queue do
		local i, j = queue[head][1], queue[head][2]
		head = head + 1
		local own, land = 0, 0
		local counts = {}
		for a = 0, SUB - 1 do
			for b = 0, SUB - 1 do
				local k = sample(i * SUB + a, j * SUB + b)
				local o = s_owner[k]
				if o then counts[o] = (counts[o] or 0) + 1 end
				if o == zone_id then own = own + 1 end
				if s_water[k] == 1 then land = land + 1 end
			end
		end
		-- The plurality owner; a tie with the zone itself goes to the zone,
		-- other ties to the smaller id.
		local best, best_n = false, 0
		local ids = {}
		for id in pairs(counts) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local n = counts[id]
			if n > best_n or (n == best_n and id == zone_id) then
				best, best_n = id, n
			end
		end
		local k = key(i, j)
		all_cells[k] = {i = i, j = j, own = own, land = land, owner = best}
		if own > 0 then
			touched[k] = true
			for n = 1, 8 do
				enqueue(i + N8[n][1], j + N8[n][2])
			end
		end
	end
	if not next(touched) then
		error("[grug_mobs] spawn regions " .. zone_id .. ": no cell of the zone at its hub", 0)
	end
	-- Margin samples (cells beside touched ones are sampled by the flood
	-- already: every touched cell enqueues its eight neighbours).

	-- The zone's land cells, in a fixed order (z, then x).
	local cells, order = {}, {}
	local LAND_MIN = SUB * SUB / 2
	for k, c in pairs(all_cells) do
		if touched[k] and c.owner == zone_id and c.land >= LAND_MIN then
			order[#order + 1] = c
		end
	end
	table.sort(order, function(a, b)
		if a.j ~= b.j then return a.j < b.j end
		return a.i < b.i
	end)

	-- Road segments near the zone (bbox of the sampled cells + ROAD_CAP).
	local min_x, min_z, max_x, max_z = huge, huge, -huge, -huge
	for k in pairs(all_cells) do
		local c = all_cells[k]
		min_x = math.min(min_x, c.i * CELL)
		max_x = math.max(max_x, c.i * CELL + CELL)
		min_z = math.min(min_z, c.j * CELL)
		max_z = math.max(max_z, c.j * CELL + CELL)
	end
	local segs = {}
	local cap = M.ROAD_CAP
	for _, line in ipairs(q.roads) do
		local pts = line.points or line
		for p = 1, #pts - 1 do
			local a, b = pts[p], pts[p + 1]
			local ax, az = a.x or a[1], a.z or a[2]
			local bx, bz = b.x or b[1], b.z or b[2]
			if math.max(ax, bx) >= min_x - cap and math.min(ax, bx) <= max_x + cap and
					math.max(az, bz) >= min_z - cap and math.min(az, bz) <= max_z + cap then
				segs[#segs + 1] = {ax, az, bx, bz}
			end
		end
	end
	-- Sites: villages drift, every other settlement core is protected.
	local sites = {}
	for _, a in ipairs(anchors) do
		local slot = a.slot
		if slot ~= "start" and slot ~= "capital" and not slot:match("^rare_") then
			sites[#sites + 1] = {x = a.x, z = a.z, village = slot:match("^village_%d+$") ~= nil}
		end
	end
	-- Road distance of a column (capped).
	local function road_dist(x, z)
		local best = cap
		for s = 1, #segs do
			local g = segs[s]
			if math.min(g[1], g[3]) - best <= x and math.max(g[1], g[3]) + best >= x and
					math.min(g[2], g[4]) - best <= z and math.max(g[2], g[4]) + best >= z then
				local d = seg_dist(x, z, g[1], g[2], g[3], g[4])
				if d < best then best = d end
			end
		end
		return best
	end

	local shore_disk, bank_disk, drift_disk = disk(M.SHORE_REACH), disk(M.BANK_REACH), disk(M.DRIFT)
	local function near(sx, sz, offsets, test)
		for n = 1, #offsets do
			local k = key(sx + offsets[n][1], sz + offsets[n][2])
			if test(k) then return true end
		end
		return false
	end
	local function is_sea(k) return s_water[k] == 2 end
	local function is_inland(k) return s_water[k] == 3 end
	local function is_town(k) return s_prot[k] == "town" end

	local heights = {}
	for idx, c in ipairs(order) do
		c.order = idx
		c.key = key(c.i, c.j)
		cells[c.key] = c
		c.x, c.z = c.i * CELL + CELL / 2, c.j * CELL + CELL / 2
		local n, hsum, shore, bank, drift, prot = 0, 0, 0, 0, 0, 0
		local road = cap
		local biomes = {}
		local grid = {}
		for a = 0, SUB - 1 do
			for b = 0, SUB - 1 do
				local sx, sz = c.i * SUB + a, c.j * SUB + b
				local k = key(sx, sz)
				if s_water[k] == 1 and s_owner[k] == zone_id then
					n = n + 1
					local h = s_h[k]
					hsum = hsum + h
					grid[a * SUB + b] = h
					local bi = s_biome[k]
					if bi then biomes[bi] = (biomes[bi] or 0) + 1 end
					if near(sx, sz, shore_disk, is_sea) then shore = shore + 1 end
					if near(sx, sz, bank_disk, is_inland) then bank = bank + 1 end
					local x, z = sx * PITCH + PITCH / 2, sz * PITCH + PITCH / 2
					local rd = road_dist(x, z)
					if rd < road then road = rd end
					local in_drift = rd <= M.DRIFT or near(sx, sz, drift_disk, is_town)
					local protected = s_prot[k] ~= false or rd <= M.CORRIDOR
					for si = 1, #sites do
						local site = sites[si]
						local d = box_dist(x, z, site.x - M.SITE_HALF, site.z - M.SITE_HALF,
							site.x + M.SITE_HALF, site.z + M.SITE_HALF)
						if d == 0 then protected = true end
						if site.village and d <= M.DRIFT then in_drift = true end
					end
					if in_drift then drift = drift + 1 end
					if protected then prot = prot + 1 end
				end
			end
		end
		if n == 0 then
			-- Land by count, but none of it the zone's own: treat as water.
			c.dead = true
		else
			local bids = {}
			for bi in pairs(biomes) do bids[#bids + 1] = bi end
			table.sort(bids)
			local best, best_n = nil, 0
			for _, bi in ipairs(bids) do
				if biomes[bi] > best_n then best, best_n = bi, biomes[bi] end
			end
			c.biome = best
			c.h = hsum / n
			-- Slope: mean |dh| per node over neighbouring own land samples.
			local ssum, sn = 0, 0
			for a = 0, SUB - 1 do
				for b = 0, SUB - 1 do
					local h = grid[a * SUB + b]
					if h then
						if a < SUB - 1 and grid[(a + 1) * SUB + b] then
							ssum = ssum + math.abs(grid[(a + 1) * SUB + b] - h)
							sn = sn + 1
						end
						if b < SUB - 1 and grid[a * SUB + b + 1] then
							ssum = ssum + math.abs(grid[a * SUB + b + 1] - h)
							sn = sn + 1
						end
					end
				end
			end
			c.slope = sn > 0 and ssum / sn / PITCH or 0
			c.n = n
			c.shore, c.bank = shore / n, bank / n
			c.drift, c.prot = drift / n, prot / n
			c.road = road
			c.forest = M.FOREST_BIOMES[best] == true
			heights[#heights + 1] = c.h
		end
	end
	-- Drop dead cells (no own land sample) from the order.
	do
		local kept = {}
		for _, c in ipairs(order) do
			if c.dead then cells[c.key] = nil else kept[#kept + 1] = c end
		end
		order = kept
		for idx, c in ipairs(order) do c.order = idx end
	end
	if #order == 0 then
		error("[grug_mobs] spawn regions " .. zone_id .. ": the zone has no land cell", 0)
	end
	map.cells, map.order = cells, order

	-- Zone height statistics for the highland rule.
	table.sort(heights)
	local function quantile(p)
		local idx = math.max(1, math.min(#heights, floor(p * (#heights - 1) + 0.5) + 1))
		return heights[idx]
	end
	local median = quantile(0.5)
	local high_line = math.max(quantile(M.HIGH_RANK), median + M.HIGH_ABOVE)
	map.heights = {median = median, high_line = high_line}

	-- 2. Progress.
	local function nearest_cell(x, z)
		local best, bd = nil, huge
		for _, c in ipairs(order) do
			local dx, dz = c.x - x, c.z - z
			local d = dx * dx + dz * dz
			if d < bd then best, bd = c, d end
		end
		return best
	end
	-- The zone's land cells bordering any of `ids` (a land cell of theirs
	-- among the eight around).
	local function border_cells(ids)
		local set, out = {}, {}
		for _, id in ipairs(ids) do set[id] = true end
		for _, c in ipairs(order) do
			for n = 1, 8 do
				local nb = all_cells[key(c.i + N8[n][1], c.j + N8[n][2])]
				if nb and set[nb.owner] and nb.land >= LAND_MIN then
					out[#out + 1] = c
					break
				end
			end
		end
		return out
	end
	for _, c in ipairs(order) do
		c.d_from, c.d_to = huge, huge
	end
	-- Sources (d_from = 0): the cells of the `from` anchors, or the land
	-- cells bordering the `from` zones (where the player enters).
	local sources, from_text = {}, "the zone"
	if recipe.from and recipe.from.border then
		sources = border_cells(recipe.from.border)
		from_text = "the border with " .. table.concat(recipe.from.border, ", ")
		if #sources == 0 then
			error("[grug_mobs] spawn regions " .. zone_id .. ": no land border with " ..
				table.concat(recipe.from.border, ", ") .. " (from)", 0)
		end
	elseif recipe.from then
		from_text = table.concat(recipe.from.anchors, ", ")
		for _, a in ipairs(from_anchors) do
			sources[#sources + 1] = cells[key(floor(a.x / CELL), floor(a.z / CELL))] or
				nearest_cell(a.x, a.z)
		end
	end
	map.from_cell = sources[1]
	map.from_cells = sources
	if #sources > 0 then
		dijkstra(cells, sources, "d_from")
	else
		-- No `from` (a one-belt recipe): progress plays no part.
		for _, c in ipairs(order) do c.d_from = 0 end
	end
	local reachable = {}
	local to = recipe.to
	if to and to.border then
		-- Progress = d_from / (d_from + d_to): 0 at the entry, 1 at the exit.
		local targets = border_cells(to.border)
		map.to_cells = targets
		local reach_targets = {}
		for _, c in ipairs(targets) do
			if c.d_from < huge then reach_targets[#reach_targets + 1] = c end
		end
		if #reach_targets == 0 then
			error("[grug_mobs] spawn regions " .. zone_id .. ": no land border with " ..
				table.concat(to.border, ", ") .. " reachable over land from " ..
				from_text, 0)
		end
		dijkstra(cells, reach_targets, "d_to")
		for _, c in ipairs(order) do
			if c.d_from < huge and c.d_to < huge then
				local s = c.d_from + c.d_to
				c.progress = s > 0 and c.d_from / s or 0
				reachable[#reachable + 1] = c
			end
		end
	else
		-- `to` core: the rank of d_from alone, so the cells farthest from all
		-- sources form the top belt. No `to` (one belt): 0 everywhere.
		local top = 0
		for _, c in ipairs(order) do
			if c.d_from < huge and c.d_from > top then top = c.d_from end
		end
		for _, c in ipairs(order) do
			if c.d_from < huge then
				c.progress = (to and top > 0) and c.d_from / top or 0
				reachable[#reachable + 1] = c
			end
		end
	end
	local islets = 0
	for _, c in ipairs(order) do
		if not c.progress then
			islets = islets + 1
			local best, bd = nil, huge
			for _, r in ipairs(reachable) do
				local dx, dz = r.i - c.i, r.j - c.j
				local d = dx * dx + dz * dz
				if d < bd then best, bd = r, d end
			end
			c.progress, c.d_from = best.progress, best.d_from
			c.islet = true
		end
	end
	map.islet_cells = islets

	-- 3. Belts.
	local sorted = {}
	for idx, c in ipairs(order) do sorted[idx] = c end
	table.sort(sorted, function(a, b)
		if a.progress ~= b.progress then return a.progress < b.progress end
		return a.order < b.order
	end)
	-- The cut is by rank: belt b holds the ranks of its cumulative share. A
	-- belt's max_from only moves a cell on to the next belt, so the belts
	-- after it keep their shares and the capped belt may end smaller.
	local belts = recipe.belts
	local nb_belts = #belts
	local ends, cum = {}, 0
	for b = 1, nb_belts do
		cum = cum + belts[b].share
		ends[b] = b == nb_belts and #sorted or floor(cum / 100 * #sorted + 0.5)
	end
	local k = 1
	for rank, c in ipairs(sorted) do
		while k < nb_belts and rank > ends[k] do k = k + 1 end
		local b = k
		while b < nb_belts and belts[b].max_from and c.d_from * CELL > belts[b].max_from do
			b = b + 1
		end
		c.belt = b
	end
	-- Smoothing: where the exit lies close to the start (progress climbs
	-- faster than a belt is wide) the cut alone can skip a belt between two
	-- neighbours. A cell sits at most one belt above any neighbour; cells
	-- above that step down until none does.
	local smoothed = 0
	local changed = true
	while changed do
		changed = false
		for _, c in ipairs(order) do
			for n = 1, 8 do
				local nb = cells[key(c.i + N8[n][1], c.j + N8[n][2])]
				if nb and c.belt > nb.belt + 1 then
					c.belt = nb.belt + 1
					smoothed = smoothed + 1
					changed = true
				end
			end
		end
	end
	map.smoothed_cells = smoothed

	-- 4. Types.
	for _, c in ipairs(order) do
		local t
		if c.shore >= M.SHORE_SHARE then
			t = "shore"
		elseif c.bank >= M.BANK_SHARE then
			t = "bank"
		elseif c.biome == "swamp" then
			t = "swamp"
		elseif c.forest then
			t = "forest"
		elseif c.slope >= M.HIGH_SLOPE or c.h >= high_line then
			t = "highland"
		else
			t = "open"
		end
		c.type = t
		c.kind = M.kind_for(belts[c.belt], t)
	end

	-- 7. Camps (before regions: a camp's cells are its own region).
	local camps = {}
	map.camps = camps
	-- A camp unit: the parsed camp, its centre and cell, its belt and its
	-- levels in that belt (what the camp spawns at). It spawns in the camp's
	-- stead (spawn_regions.lua spawn_mob: tag, rosters, levels_by_role).
	local function new_camp(camp, cell, x, z, belt, levels)
		local unit = {id = camp.id, camp = camp, cell = cell, x = x, z = z,
			tag = camp.tag, rosters = camp.rosters, is_camp = true, belt = belt,
			levels_by_role = levels.levels_by_role, levels = levels.levels}
		camps[#camps + 1] = unit
		return unit
	end
	-- Camps on POIs first (Round 28 S2): the centre is the POI's fitted
	-- anchor, the cells are the zone's land cells the camp radius reaches,
	-- the belt the one the POI's cell lies in unless the camp states one.
	for _, camp in ipairs(recipe.camps) do
		if camp.site ~= "generate" then
			local a = anchor_by_ref[camp.site.anchor]
			local cell = a and (cells[key(floor(a.x / CELL), floor(a.z / CELL))] or
				nearest_cell(a.x, a.z))
			if not cell then
				problems[#problems + 1] = "no position for " .. camp.id .. " on " .. camp.site.name
			else
				local belt = camp.belt or belts[cell.belt]
				local ok, levels = pcall(M.camp_levels, zone_id, camp, belt)
				if not ok then
					problems[#problems + 1] = (tostring(levels):gsub("^%[grug_mobs%] spawn recipe ", ""))
				else
					local unit = new_camp(camp, cell, a.x, a.z, belt, levels)
					unit.site = camp.site
					for _, c in ipairs(order) do
						if not c.camp and box_dist(a.x, a.z, c.i * CELL, c.j * CELL,
								c.i * CELL + CELL, c.j * CELL + CELL) < M.CAMP_RADIUS then
							c.camp = unit
						end
					end
					-- A POI just off the zone's land keeps its nearest cell.
					if not cell.camp then cell.camp = unit end
				end
			end
		end
	end
	-- Generated sites, by rule score.
	local generated = {}
	for _, camp in ipairs(recipe.camps) do
		if camp.site == "generate" then generated[#generated + 1] = camp end
	end
	for _, camp in ipairs(generated) do
		local best, best_score
		for _, c in ipairs(order) do
			if belts[c.belt] == camp.belt and not c.camp then
				local ok, slope_sum, road = true, 0, huge
				local has_high = false
				for a = -1, 1 do
					for b = -1, 1 do
						local n = cells[key(c.i + a, c.j + b)]
						if not n or n.camp or n.prot > 0 or n.drift > 0 then
							ok = false
						else
							slope_sum = slope_sum + n.slope
							if n.road < road then road = n.road end
							if n.type == "highland" then has_high = true end
						end
					end
				end
				if ok and road >= M.CAMP_ROAD_MIN and slope_sum / 9 <= M.CAMP_SLOPE then
					for _, other in ipairs(camps) do
						if math.max(math.abs(other.cell.i - c.i), math.abs(other.cell.j - c.j)) <
								camp.apart then
							ok = false
						end
					end
				end
				if ok and road >= M.CAMP_ROAD_MIN and slope_sum / 9 <= M.CAMP_SLOPE then
					-- Forest edge: forest within two cells, but not forest all
					-- round.
					local forest, total = 0, 0
					for a = -2, 2 do
						for b = -2, 2 do
							local n = cells[key(c.i + a, c.j + b)]
							if n then
								total = total + 1
								if n.forest then forest = forest + 1 end
							end
						end
					end
					local edge = forest > 0 and forest < total
					local score = (edge and 2 or 0) + (has_high and 1 or 0) +
						0.5 * (1 - math.min(1, slope_sum / 9)) +
						0.25 * math.min(road, cap) / cap
					if not best_score or score > best_score + 1e-9 then
						best, best_score = c, score
					end
				end
			end
		end
		if best then
			local unit = new_camp(camp, best, best.x, best.z, camp.belt,
				M.camp_levels(zone_id, camp, camp.belt))
			unit.score = best_score
			for a = -1, 1 do
				for b = -1, 1 do
					cells[key(best.i + a, best.j + b)].camp = unit
				end
			end
		else
			problems[#problems + 1] = "no valid camp cell for " .. camp.id ..
				" in belt " .. camp.belt.id
		end
	end

	-- 5. Regions: components of one kind (8 neighbours), outside camps.
	local regions = {}
	local function new_region(kind, belt)
		local r = {kind = kind, belt = belt, cells = {}}
		regions[#regions + 1] = r
		return r
	end
	for _, c in ipairs(order) do
		if not c.camp and not c.region then
			local r = new_region(c.kind, c.belt)
			local stack = {c}
			c.region = r
			while #stack > 0 do
				local cur = table.remove(stack)
				r.cells[#r.cells + 1] = cur
				for n = 1, 8 do
					local nb = cells[key(cur.i + N8[n][1], cur.j + N8[n][2])]
					if nb and not nb.camp and not nb.region and nb.kind == c.kind then
						nb.region = r
						stack[#stack + 1] = nb
					end
				end
			end
		end
	end
	local function sort_cells(r)
		table.sort(r.cells, function(a, b) return a.order < b.order end)
	end
	for _, r in ipairs(regions) do sort_cells(r) end

	-- Merge fragments below the minimum into the neighbour region they
	-- share most edges with (same belt first). Smallest first.
	local function min_size(r)
		return r.kind.type == "shore" and M.MIN_STRIP or M.MIN_CELLS
	end
	local merged_away = {}
	while true do
		local small = {}
		for _, r in ipairs(regions) do
			if not merged_away[r] and not r.stuck and #r.cells < min_size(r) then
				small[#small + 1] = r
			end
		end
		if #small == 0 then break end
		table.sort(small, function(a, b)
			if #a.cells ~= #b.cells then return #a.cells < #b.cells end
			return a.cells[1].order < b.cells[1].order
		end)
		local r = small[1]
		local edges, rank = {}, {}
		local list = {}
		for _, c in ipairs(r.cells) do
			for n = 1, 8 do
				local nb = cells[key(c.i + N8[n][1], c.j + N8[n][2])]
				local other = nb and nb.region
				if other and other ~= r then
					if not edges[other] then
						edges[other] = 0
						list[#list + 1] = other
					end
					-- An edge counts 1, a corner contact a little.
					edges[other] = edges[other] + (n <= 4 and 1 or 0.01)
				end
			end
		end
		-- A merge into another belt must not put the fragment two belts
		-- from one of its other neighbours.
		local function smooth_with(belt)
			for _, c in ipairs(r.cells) do
				for n = 1, 8 do
					local nb = cells[key(c.i + N8[n][1], c.j + N8[n][2])]
					if nb and nb.region ~= r and math.abs(nb.belt - belt) > 1 then
						return false
					end
				end
			end
			return true
		end
		local best, best_key
		for _, other in ipairs(list) do
			rank[other] = (other.belt == r.belt and 1000 or 0) +
				(smooth_with(other.belt) and 100 or 0) + edges[other]
			if not best or rank[other] > best_key + 1e-12 or
					(math.abs(rank[other] - best_key) <= 1e-12 and
						other.cells[1].order < best.cells[1].order) then
				best, best_key = other, rank[other]
			end
		end
		if not best then
			r.stuck = true -- an isolated fragment (an islet): it stays
		else
			for _, c in ipairs(r.cells) do
				c.region = best
				c.kind = best.kind
				c.belt = best.belt
				best.cells[#best.cells + 1] = c
			end
			sort_cells(best)
			r.cells = {}
			merged_away[r] = true
		end
	end
	do
		local kept = {}
		for _, r in ipairs(regions) do
			if not merged_away[r] then kept[#kept + 1] = r end
		end
		regions = kept
	end

	-- Split regions above the maximum into compact parts: farthest-point
	-- seeds, grown together over the region's own cells, then a few Lloyd
	-- rounds (each seed moves to the cell nearest its part's centroid).
	local function bfs(r_cells, seeds, member)
		local owner, dist = {}, {}
		local q2, h2 = {}, 1
		for s, c in ipairs(seeds) do
			owner[c] = s
			dist[c] = 0
			q2[#q2 + 1] = c
		end
		while h2 <= #q2 do
			local cur = q2[h2]
			h2 = h2 + 1
			for n = 1, 8 do
				local nb = cells[key(cur.i + N8[n][1], cur.j + N8[n][2])]
				if nb and member[nb] and not owner[nb] then
					owner[nb] = owner[cur]
					dist[nb] = dist[cur] + 1
					q2[#q2 + 1] = nb
				end
			end
		end
		return owner, dist
	end
	local split = {}
	for _, r in ipairs(regions) do
		local size = #r.cells
		if size > M.MAX_CELLS then
			local member = {}
			for _, c in ipairs(r.cells) do member[c] = true end
			local parts_n = math.ceil(size / M.SPLIT_TARGET)
			-- Seeds: the cell farthest from the first cell, then each next
			-- the cell farthest from all seeds so far.
			local _, d0 = bfs(r.cells, {r.cells[1]}, member)
			local seed = r.cells[1]
			for _, c in ipairs(r.cells) do
				if (d0[c] or -1) > (d0[seed] or -1) then seed = c end
			end
			local seeds = {seed}
			while #seeds < parts_n do
				local _, d = bfs(r.cells, seeds, member)
				local far = nil
				for _, c in ipairs(r.cells) do
					if d[c] and (not far or d[c] > d[far]) then far = c end
				end
				seeds[#seeds + 1] = far
			end
			local owner
			for _ = 1, M.LLOYD_ROUNDS do
				owner = bfs(r.cells, seeds, member)
				for s = 1, #seeds do
					local sx, sz, n = 0, 0, 0
					for _, c in ipairs(r.cells) do
						if owner[c] == s then sx, sz, n = sx + c.i, sz + c.j, n + 1 end
					end
					if n > 0 then
						sx, sz = sx / n, sz / n
						local best, bd = seeds[s], huge
						for _, c in ipairs(r.cells) do
							if owner[c] == s then
								local dx, dz = c.i - sx, c.j - sz
								local d = dx * dx + dz * dz
								if d < bd - 1e-12 then best, bd = c, d end
							end
						end
						seeds[s] = best
					end
				end
			end
			owner = bfs(r.cells, seeds, member)
			for s = 1, #seeds do
				local part = {kind = r.kind, belt = r.belt, cells = {}}
				for _, c in ipairs(r.cells) do
					if owner[c] == s then
						part.cells[#part.cells + 1] = c
						c.region = part
					end
				end
				if #part.cells > 0 then split[#split + 1] = part end
			end
		else
			split[#split + 1] = r
		end
	end
	regions = split
	-- Camp regions.
	for _, unit in ipairs(camps) do
		local r = {kind = unit.camp, belt = unit.belt.index, cells = {}, camp = unit}
		for _, c in ipairs(order) do
			if c.camp == unit then
				r.cells[#r.cells + 1] = c
				c.region = r
				c.kind = unit.camp
				c.belt = unit.belt.index
			end
		end
		unit.region = r
		regions[#regions + 1] = r
	end
	-- Ids by first cell, centroids, levels.
	table.sort(regions, function(a, b) return a.cells[1].order < b.cells[1].order end)
	local by_kind = {}
	for idx, r in ipairs(regions) do
		r.id = idx
		local sx, sz = 0, 0
		for _, c in ipairs(r.cells) do sx, sz = sx + c.x, sz + c.z end
		r.x, r.z = sx / #r.cells, sz / #r.cells
		r.size = #r.cells
		local levels = belts[r.belt].levels
		r.levels = r.camp and r.camp.levels or r.kind.levels
		r.level = floor((levels[1] + levels[2]) / 2 + 0.5)
		local list = by_kind[r.kind.id]
		if not list then
			list = {}
			by_kind[r.kind.id] = list
		end
		list[#list + 1] = r
	end
	map.regions, map.by_kind = regions, by_kind

	-- 8. Leaders.
	local leaders = {}
	map.leaders = leaders
	for _, leader in ipairs(recipe.leaders) do
		local spot
		if leader.camp then
			for _, unit in ipairs(camps) do
				if unit.camp == leader.camp then
					spot = {x = unit.x, z = unit.z, region = unit.region}
				end
			end
		else
			local largest
			for _, r in ipairs(by_kind[leader.kind.id] or {}) do
				if not largest or r.size > largest.size then largest = r end
			end
			if largest then
				-- Depth: steps from the region's edge.
				local member, edge = {}, {}
				for _, c in ipairs(largest.cells) do member[c] = true end
				for _, c in ipairs(largest.cells) do
					for n = 1, 4 do
						local nb = cells[key(c.i + N4[n][1], c.j + N4[n][2])]
						if not nb or not member[nb] then
							edge[#edge + 1] = c
							break
						end
					end
				end
				local _, depth = bfs(largest.cells, edge, member)
				local best
				for _, c in ipairs(largest.cells) do
					if not best or c.road > best.road + 1e-9 or
							(math.abs(c.road - best.road) <= 1e-9 and
								(depth[c] or 0) > (depth[best] or 0)) then
						best = c
					end
				end
				spot = {x = best.x, z = best.z, region = largest}
			end
		end
		if spot then
			leaders[#leaders + 1] = {role = leader.role, x = floor(spot.x),
				z = floor(spot.z), level = leader.level, respawn = leader.respawn,
				region = spot.region}
		else
			problems[#problems + 1] = "no spot for leader " .. leader.role
		end
	end

	-- The region at a point: its cell's, else the nearest zone land cell
	-- among the eight around it (a coast fringe, a border notch).
	function map.region_at(x, z)
		local i, j = floor(x / CELL), floor(z / CELL)
		local c = cells[key(i, j)]
		if c then return c.region end
		local best, bd
		for n = 1, 8 do
			local nb = cells[key(i + N8[n][1], j + N8[n][2])]
			if nb then
				local dx, dz = nb.x - x, nb.z - z
				local d = dx * dx + dz * dz
				if not bd or d < bd then best, bd = nb, d end
			end
		end
		return best and best.region or nil
	end
	return map
end

--
-- Helpers for the game and the tools
--

local COMPASS = {"north", "northeast", "east", "southeast", "south",
	"southwest", "west", "northwest"}
-- The compass word from (x0, z0) toward (x1, z1); +z is north.
function M.compass(x0, z0, x1, z1)
	local dx, dz = x1 - x0, z1 - z0
	if dx == 0 and dz == 0 then
		return nil
	end
	local angle = math.atan2(dx, dz) -- 0 = north, clockwise toward east
	local sector = floor(angle / (math.pi / 4) + 0.5) % 8
	return COMPASS[sector + 1]
end

-- Directions for quest texts.
M.NEAR = 80    -- nodes: a target closer than this is "near" its reference
M.HEART = 0.3  -- zone mode: within this share of the zone's half extent

-- Where a describe target stands: a leader role (its spot), a camp id (its
-- centre) or a kind id (the centroid of the kind's LARGEST region, ties to
-- the lower region id; one patch for every phrasing, so two placeholders in
-- one quest never point at different patches). Nil when the map has none.
function M.target_of(map, target)
	for _, l in ipairs(map.leaders) do
		if l.role == target then
			return {x = l.x, z = l.z, what = "leader", region = l.region}
		end
	end
	for _, unit in ipairs(map.camps) do
		if unit.id == target then
			return {x = unit.x, z = unit.z, what = "camp", region = unit.region}
		end
	end
	local largest
	for _, r in ipairs(map.by_kind[target] or {}) do
		if not largest or r.size > largest.size then largest = r end
	end
	if largest then
		return {x = largest.x, z = largest.z, what = "kind", region = largest}
	end
	return nil
end

-- The zone's land centre and half extent (centroid and bounding box of its
-- land cells), cached on the map.
function M.zone_frame(map)
	if not map.frame then
		local sx, sz, x0, z0, x1, z1 = 0, 0, huge, huge, -huge, -huge
		for _, c in ipairs(map.order) do
			sx, sz = sx + c.x, sz + c.z
			x0, x1 = math.min(x0, c.x), math.max(x1, c.x)
			z0, z1 = math.min(z0, c.z), math.max(z1, c.z)
		end
		local n = #map.order
		map.frame = {x = sx / n, z = sz / n,
			hx = math.max(M.CELL, (x1 - x0) / 2 + M.CELL / 2),
			hz = math.max(M.CELL, (z1 - z0) / 2 + M.CELL / 2)}
	end
	return map.frame
end

-- describe(map, target, mode, ref, zone_name) -> {dir, distance,
-- phrase_key, phrase, x, z} or nil, reason.
--   "of"   ref = {x, z, name}: "southeast of Highcourt"; closer than NEAR:
--          "near Highcourt" (dir nil, phrase_key "near").
--   "from" ref = {x, z} (the speaker): "southeast from here"; closer than
--          NEAR: "nearby" (phrase_key "nearby").
--   "zone" the target against the zone's land centre, measured in shares of
--          the zone's half extent (so a long zone's east end reads east):
--          "in the southeast of Dawnmere Fields"; within HEART of the
--          centre: "in the heart of Dawnmere Fields" (phrase_key
--          "zone_heart"). distance = nodes from the centre.
function M.describe(map, target, mode, ref, zone_name)
	local t = M.target_of(map, target)
	if not t then
		return nil, "no " .. tostring(target) .. " in the region map"
	end
	local out = {x = t.x, z = t.z, what = t.what}
	if mode == "of" or mode == "from" then
		if type(ref) ~= "table" or not is_num(ref.x) or not is_num(ref.z) then
			return nil, "mode " .. mode .. " needs a reference position"
		end
		local dx, dz = t.x - ref.x, t.z - ref.z
		out.distance = floor(sqrt(dx * dx + dz * dz) + 0.5)
		local near = out.distance < M.NEAR
		out.dir = not near and M.compass(ref.x, ref.z, t.x, t.z) or nil
		if mode == "of" then
			local name = ref.name or "there"
			out.phrase_key = near and "near" or "dir_of"
			out.phrase = near and ("near " .. name) or (out.dir .. " of " .. name)
		else
			out.phrase_key = near and "nearby" or "dir_from_here"
			out.phrase = near and "nearby" or (out.dir .. " from here")
		end
	elseif mode == "zone" then
		local f = M.zone_frame(map)
		local u, v = (t.x - f.x) / f.hx, (t.z - f.z) / f.hz
		local dx, dz = t.x - f.x, t.z - f.z
		out.distance = floor(sqrt(dx * dx + dz * dz) + 0.5)
		local name = zone_name or map.zone
		if sqrt(u * u + v * v) < M.HEART then
			out.phrase_key = "zone_heart"
			out.phrase = "in the heart of " .. name
		else
			out.dir = M.compass(0, 0, u, v)
			out.phrase_key = "zone_dir"
			out.phrase = "in the " .. out.dir .. " of " .. name
		end
	else
		return nil, "mode must be of, from or zone"
	end
	return out
end

-- Summary numbers of a built map (the renderer's stats, the fixtures).
function M.stats(map)
	local recipe = map.recipe
	local n = #map.order
	local out = {cells = n, belts = {}, kinds = {}, regions = #map.regions,
		sizes = {}, islet_cells = map.islet_cells, camps = {}, leaders = {},
		problems = map.problems}
	for b, belt in ipairs(recipe.belts) do
		out.belts[b] = {id = belt.id, levels = belt.levels, cells = 0}
	end
	local kind_cells = {}
	for _, c in ipairs(map.order) do
		out.belts[c.belt].cells = out.belts[c.belt].cells + 1
		kind_cells[c.kind.id] = (kind_cells[c.kind.id] or 0) + 1
	end
	for _, belt in ipairs(out.belts) do
		belt.share = belt.cells / n
	end
	local ids = {}
	for id in pairs(kind_cells) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		out.kinds[#out.kinds + 1] = {id = id, cells = kind_cells[id],
			share = kind_cells[id] / n, regions = #(map.by_kind[id] or {})}
	end
	for i, r in ipairs(map.regions) do out.sizes[i] = r.size end
	table.sort(out.sizes)
	-- Adjacent regions: the largest belt difference.
	local jump = 0
	for _, c in ipairs(map.order) do
		for n4 = 1, 4 do
			local nb = map.cells[key(c.i + N4[n4][1], c.j + N4[n4][2])]
			if nb and nb.region ~= c.region then
				jump = math.max(jump, math.abs(nb.belt - c.belt))
			end
		end
	end
	out.max_belt_jump = jump
	for _, unit in ipairs(map.camps) do
		out.camps[#out.camps + 1] = {id = unit.id, x = unit.x, z = unit.z,
			score = unit.score, road = unit.cell.road, poi = unit.site and unit.site.name}
	end
	for _, l in ipairs(map.leaders) do
		out.leaders[#out.leaders + 1] = {role = l.role, x = l.x, z = l.z, level = l.level}
	end
	return out
end

M.key = key
return M
