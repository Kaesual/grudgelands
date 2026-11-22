-- Round 85 lane TERRITORY: the arena "Breach Road" as a place of the game on
-- one seed's real world plan (LuaJIT, no engine).
--
--   luajit tools/r85_territory/seeds.lua <repo> <seed> <outdir>
--   luajit tools/r85_territory/seeds.lua <repo> <seed> <outdir> place
--
-- The full mode builds the seed's world as main builds it
-- (tools/r28_zone_atlas/world.lua: placement, water, roads, capitals, the
-- zones session with the R7 overlay) and checks, on the arena's layout of
-- that world (`source.breach.world`):
--   territory   every node of both halls' interiors answers its faction
--               (grug_pvp/rules.lua R.zone_answers on the world's zones
--               session), a sample of the footprint's columns at six heights
--               outside the halls and the node beyond each face of each box
--               answer contested for both factions;
--   protection  the arena box (world_protection.lua arena_box in the index)
--               answers "arena" at its corners and centre, nil beyond;
--   spawns      the zones whose land the fringe touches: their region maps
--               built with the fringe reserved (as spawn_regions.lua builds
--               them in the game) hold no camp centre, camp cell, leader or
--               quest place on the fringe; the same maps built without it
--               say what the rule moved; no rare's patrol point lies on the
--               fringe.
-- Writes <outdir>/<seed>.tsv (one "key<TAB>value" line per figure) and
-- prints "OK <seed> ..." or "FAIL <seed> <what>" (and raises).
-- The place mode writes only the placement text, <outdir>/<seed>.placement
-- (for comparing trees: the rare patrol rule changes the placement).
local repo, seed, out, mode = arg[1], arg[2], arg[3], arg[4]
assert(repo and seed and out, "usage: seeds.lua <repo> <seed> <outdir> [place]")
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local floor = math.floor

local function write(path, text)
	local f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
end

if mode == "place" then
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local A = dofile(wp40 .. "/world_assembly.lua")(wp40, common.new_sha256())
	local W = A.world(seed, nil, {protection = A.square_cities(120)})
	W.place()
	write(out .. "/" .. seed .. ".placement", W.placement_text)
	print("PLACED " .. seed)
	return
end

local t0 = os.clock()
local W = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, seed)
local world_seconds = os.clock() - t0
local S, source = W.session, W.source
local site = source.breach
local B = site.world
local rows, failures = {}, {}
local function put(key, value) rows[#rows + 1] = key .. "\t" .. tostring(value) end
local function fail(what) failures[#failures + 1] = what end
put("seed", seed)
put("site", ("%d,%d datum %d reach %d"):format(site.x, site.z, site.y, site.reach))
put("world_seconds", ("%.1f"):format(world_seconds))

-- ---------------------------------------------------------------------------
-- Territory
-- ---------------------------------------------------------------------------
local R = dofile(repo .. "/mods/PLAYER/grug_pvp/rules.lua")
local halls = {}
for _, faction in ipairs({"accord", "throng"}) do
	local box = B.halls[faction].interior
	halls[#halls + 1] = {faction = faction, min = box.min, max = box.max}
end
local function territory(pos, own)
	local rule, here = R.zone_answers(S, halls, pos)
	return R.territory(rule, here, own)
end
local hall_zones = {}
for _, hall in ipairs(halls) do
	local other = hall.faction == "accord" and "throng" or "accord"
	local lo, hi, good, total = hall.min, hall.max, 0, 0
	for x = lo.x, hi.x do
		for y = lo.y, hi.y do
			for z = lo.z, hi.z do
				total = total + 1
				local pos = {x = x, y = y, z = z}
				if territory(pos, hall.faction) == "friendly" and territory(pos, other) == "enemy" then
					good = good + 1
				end
			end
		end
	end
	put("hall_" .. hall.faction, ("%d of %d interior nodes right"):format(good, total))
	if good ~= total then fail("hall " .. hall.faction .. " interior") end
	local cx, cz, fy = floor((lo.x + hi.x) / 2), floor((lo.z + hi.z) / 2), lo.y
	hall_zones[#hall_zones + 1] = hall.faction .. ":" .. tostring(S.id_at(cx, cz))
	for _, p in ipairs({{lo.x - 1, fy, cz}, {hi.x + 1, fy, cz}, {cx, fy, lo.z - 1},
			{cx, fy, hi.z + 1}, {cx, hi.y + 1, cz}, {cx, lo.y - 1, cz}}) do
		local pos = {x = p[1], y = p[2], z = p[3]}
		if territory(pos, "accord") ~= "contested" or territory(pos, "throng") ~= "contested" then
			fail(("beyond the %s hall at %d,%d,%d not contested"):format(hall.faction, p[1], p[2], p[3]))
		end
	end
end
put("hall_zones", table.concat(hall_zones, " "))
local open, open_bad = 0, 0
local fp = B.footprint
for x = fp.min.x, fp.max.x, 4 do
	for z = fp.min.z, fp.max.z, 4 do
		for _, ly in ipairs({1, 4, 7, 10, 14, 20}) do
			local pos = {x = x, y = B.datum + ly, z = z}
			if not R.hall_at(halls, pos) then
				open = open + 1
				if territory(pos, "accord") ~= "contested" or territory(pos, "throng") ~= "contested" then
					open_bad = open_bad + 1
				end
			end
		end
	end
end
put("open_contested", ("%d of %d samples"):format(open - open_bad, open))
if open_bad > 0 then fail(open_bad .. " open samples not contested") end

-- ---------------------------------------------------------------------------
-- Protection
-- ---------------------------------------------------------------------------
local wp = dofile(wp40 .. "/world_protection.lua")
local box = wp.arena_box(B)
local index = wp.new(dofile(wp40 .. "/index128.lua"), {boxes = {box}})
local corners = 0
for _, x in ipairs({box.min_x, box.max_x, site.x}) do
	for _, y in ipairs({box.min_y, box.max_y, site.y}) do
		for _, z in ipairs({box.min_z, box.max_z, site.z}) do
			if index.kind_at(x, y, z) == "arena" then corners = corners + 1 end
		end
	end
end
local beyond = 0
for _, p in ipairs({{box.min_x - 1, site.y, site.z}, {box.max_x + 1, site.y, site.z},
		{site.x, box.min_y - 1, site.z}, {site.x, box.max_y + 1, site.z},
		{site.x, site.y, box.min_z - 1}, {site.x, site.y, box.max_z + 1}}) do
	if index.kind_at(p[1], p[2], p[3]) == nil then beyond = beyond + 1 end
end
put("protected_box", ("x %d..%d y %d..%d z %d..%d; %d/27 inside, %d/6 beyond"):format(box.min_x,
	box.max_x, box.min_y, box.max_y, box.min_z, box.max_z, corners, beyond))
if corners ~= 27 or beyond ~= 6 then fail("protected box") end

-- ---------------------------------------------------------------------------
-- Spawns: region maps with and without the fringe reserved
-- ---------------------------------------------------------------------------
local CORE = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local function read(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end
local catalogue = {}
do
	local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/subtypes.json"))
	if not data[1] then data = data.subtypes end
	for _, row in ipairs(data) do catalogue[row.role] = row end
end
local f = B.fringe
local rect = {min_x = f.min.x, max_x = f.max.x, min_z = f.min.z, max_z = f.max.z}
local function on_fringe(x, z)
	return x >= rect.min_x and x <= rect.max_x and z >= rect.min_z and z <= rect.max_z
end
put("fringe", ("x %d..%d z %d..%d"):format(rect.min_x, rect.max_x, rect.min_z, rect.max_z))
local env = {zones = S, column_values_at = W.planner_source.column_values_at,
	road_polylines = W.wp40.road_polylines, source = source}
local q_with = CORE.queries(setmetatable({reserved = CORE.reserved_of(B)}, {__index = env}))
local q_without = CORE.queries(env)
local touched, zone_ids = {}, {}
for x = rect.min_x, rect.max_x, 8 do
	for z = rect.min_z, rect.max_z, 8 do
		local id = S.id_at(x, z)
		if id and not touched[id] then
			touched[id] = true
			zone_ids[#zone_ids + 1] = id
		end
	end
end
table.sort(zone_ids)
put("fringe_zones", table.concat(zone_ids, " "))
local function spots(map)
	local list = {}
	for _, u in ipairs(map.camps) do
		list[#list + 1] = {what = "camp " .. u.id, x = u.x, z = u.z, camp = u}
	end
	for _, l in ipairs(map.leaders) do list[#list + 1] = {what = "leader " .. l.role, x = l.x, z = l.z} end
	for _, p in ipairs(map.places) do list[#list + 1] = {what = "place " .. p.id, x = p.x, z = p.z} end
	return list
end
local moved, build_with, build_without = {}, 0, 0
for _, zone in ipairs(zone_ids) do
	local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. zone ..
		".spawns.json") or "{}")
	if data.recipe then
		local record = S.get(zone)
		local recipe = CORE.parse_recipe(zone, data.recipe, {
			band = {record.level_min, record.level_max},
			role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
			leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
			pois = function(id) return CORE.zone_pois(source, id, nil) end,
		})
		local t1 = os.clock()
		local with = CORE.build(zone, q_with, recipe)
		local t2 = os.clock()
		local without = CORE.build(zone, q_without, recipe)
		build_with, build_without = build_with + (t2 - t1), build_without + (os.clock() - t2)
		local reserved_cells = 0
		for _, c in ipairs(with.order) do if c.reserved then reserved_cells = reserved_cells + 1 end end
		local camp_cells = 0
		for _, c in ipairs(with.order) do
			if c.camp and c.reserved then camp_cells = camp_cells + 1 end
		end
		if camp_cells > 0 then fail(zone .. ": " .. camp_cells .. " camp cells on the fringe") end
		local count = 0
		for _, s in ipairs(spots(with)) do
			count = count + 1
			if on_fringe(s.x, s.z) then fail(zone .. ": " .. s.what .. " on the fringe") end
		end
		local after = {}
		for _, s in ipairs(spots(with)) do after[s.what] = s end
		for _, s in ipairs(spots(without)) do
			local a = after[s.what]
			if not a or a.x ~= s.x or a.z ~= s.z then
				moved[#moved + 1] = ("%s %s %d,%d -> %s%s"):format(zone, s.what, s.x, s.z,
					a and (a.x .. "," .. a.z) or "none", on_fringe(s.x, s.z) and " (was on the fringe)" or "")
			end
		end
		put("zone_" .. zone, ("%d reserved cells, %d camps/leaders/places, regions %d (without: %d)"):format(
			reserved_cells, count, #with.regions, #without.regions))
		if #with.regions ~= #without.regions then fail(zone .. ": the regions changed") end
	end
end
put("moved", #moved == 0 and "none" or table.concat(moved, "; "))
put("region_build_seconds", ("%.2f with, %.2f without"):format(build_with, build_without))

-- the rares' patrol points (zone_authority.lua: the anchor plus the offsets)
local rare_points, rare_bad = 0, 0
for _, a in ipairs(source.anchors) do
	if a.template_id == "rare_route" then
		local zone
		for _, z in ipairs(source.zones) do
			if z.numeric_id == a.zone_numeric_id then zone = z.id end
		end
		local anchor = S.anchor(zone, a.slot_id)
		for _, p in ipairs(source.rare_patrol_shape) do
			rare_points = rare_points + 1
			if on_fringe(anchor.x + p.x, anchor.z + p.z) then
				rare_bad = rare_bad + 1
				fail(("rare %s point %d,%d on the fringe"):format(a.slot_id, anchor.x + p.x, anchor.z + p.z))
			end
		end
	end
end
put("rare_points", ("%d points, %d on the fringe"):format(rare_points, rare_bad))
write(out .. "/" .. seed .. ".tsv", table.concat(rows, "\n") .. "\n")
if #failures > 0 then
	print("FAIL " .. seed .. " " .. table.concat(failures, "; "))
	error("seed " .. seed .. ": checks failed", 0)
end
print(("OK %s site %d,%d zones %s moved %d"):format(seed, site.x, site.z, table.concat(zone_ids, ","),
	#moved))
