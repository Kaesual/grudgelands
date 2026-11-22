-- Round 85 MASK: the claim mask's world (claim_mask.lua `world`) on the seed
-- fleet's runtime (tools/seed_fleet/runtime.lua: the real R7 planner under
-- LuaJIT, no engine), built the way the game's mask.lua builds it from the
-- published world: the zones session's column answers, the placement world's
-- feature_in (the world protection index as r7_loader.lua builds it and the
-- session's hard footprints), every road corridor of the layout text, the
-- capitals' protected cities, every recipe zone's region map
-- (spawn_regions_core.lua with the arena's fringe reserved, as
-- spawn_regions.lua and tools/seed_fleet/seed.lua build them) and the
-- named rares' routes (the consumer payload, as grug_core.rare_route serves
-- them).
--
--   local W = dofile(repo .. "/tools/r85_mask/world.lua")(repo, R)
--   W.world   the claim mask's world
--   W.seconds {regions = CPU seconds of the region map builds}
return function(repo, R)
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local CM = dofile(repo .. "/mods/PLAYER/grug_housing/claim_mask.lua")
	local SOURCE = dofile(wp40 .. "/source/simple_map.lua")
	local Z = R.built.zones_session

	-- The world protection, as r7_loader.lua builds it.
	local wp = dofile(wp40 .. "/world_protection.lua")
	local prepared = R.main.prepared_handover()
	local box_rows = {}
	for _, row in ipairs(R.main.settlement_sockets(R.built)) do
		if row.slot ~= "start" and row.slot ~= "capital" then
			box_rows[#box_rows + 1] = {key = row.key, slot = row.slot, anchor = row.anchor,
				bounds = prepared[row.key].bounds}
		end
	end
	local corridors = wp.road_corridors(R.main.road_module(), R.main.road_layout_text())
	local boxes = wp.settlement_boxes(box_rows)
	-- the arena Breach Road (Round 85 lane TERRITORY), as r7_loader.lua builds
	-- its layout: its protected box here, its fringe reserved for the region
	-- maps below
	local breach_layout = dofile(wp40 .. "/breach_layout.lua")
	local breach = breach_layout.world(breach_layout.from_placement(
		R.main.placement_layout_text()))
	boxes[#boxes + 1] = wp.arena_box(breach)
	local WP = wp.new(dofile(wp40 .. "/index128.lua"), {corridors = corridors,
		boxes = boxes})

	local world = {bounds = SOURCE.world_bounds, zones = {}}
	local records = {}
	for _, zr in ipairs(SOURCE.zones) do
		local rec = Z.get(zr.id)
		records[zr.id] = rec
		world.zones[#world.zones + 1] = rec
	end
	function world.water_at(x, z) return Z.water_class_at(x, z) end
	function world.zone_at(x, z)
		local id = Z.id_at(x, z)
		return id and records[id] or nil
	end
	function world.territory_at(x, z) return Z.territory_rule_at({x = x, y = 30000, z = z}) end
	function world.height_at(x, z) return Z.terrain_height_at(x, z) end
	-- grug_housing api.lua's feature_in, with the id
	function world.feature_in(min_x, min_z, max_x, max_z, margin)
		local kind, id = WP.boxes_in(min_x, min_z, max_x, max_z, margin)
		if kind then return "site", id end
		local hid, hkind = Z.hard_footprint_in(min_x - margin, min_z - margin, max_x + margin,
			max_z + margin)
		return hkind, hid
	end
	world.roads = {}
	for _, c in ipairs(corridors) do
		world.roads[#world.roads + 1] = {id = c.id, X = c.X, Z = c.Z, R = c.R,
			reach = c.half_width + c.side}
	end
	world.cities = {}
	do
		local shapes = R.main.capital_protection()
		local ids = {}
		for id in pairs(shapes) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			world.cities[#world.cities + 1] = {id = id, anchor = shapes[id].anchor,
				rows = shapes[id].rows}
		end
	end

	-- Every recipe zone's region map.
	local t0 = os.clock()
	local core = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local function read(path)
		local h = io.open(path, "rb")
		if not h then return nil end
		local text = h:read("*a")
		h:close()
		return text
	end
	local catalogue = {}
	do
		local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/subtypes.json"))
		for _, row in ipairs(data[1] and data or data.subtypes) do catalogue[row.role] = row end
	end
	local labels = {}
	for _, row in ipairs(dofile(wp40 .. "/r7_settlement.lua").roster) do
		if row.anchor_id then labels[row.anchor_id] = row.label end
	end
	local q = core.queries({zones = Z, column_values_at = R.planner_source.column_values_at,
		road_polylines = R.main.road_polylines(), source = SOURCE,
		reserved = core.reserved_of(breach)})
	world.spawn = CM.new_spawn()
	for _, zr in ipairs(SOURCE.zones) do
		local text = read(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. zr.id .. ".spawns.json")
		if text then
			local data = json.parse(text)
			local rec = records[zr.id]
			local recipe = core.parse_recipe(zr.id, data.recipe, {
				band = {rec.level_min, rec.level_max},
				role_levels = function(r) return catalogue[r] and catalogue[r].levels end,
				leader = function(r) return catalogue[r] ~= nil and catalogue[r].leader == true end,
				pois = function(id) return core.zone_pois(SOURCE, id, labels) end,
			})
			local map = core.build(zr.id, q, recipe)
			local quota = CM.zone_allowed("accord", rec) or CM.zone_allowed("throng", rec)
			CM.add_zone_spawn(world.spawn, zr.id, function(fn)
				for _, c in ipairs(map.order) do
					if c.region then fn(c.i, c.j, c.region) end
				end
			end, map.leaders, map.places, quota)
		end
	end
	for _, row in ipairs(R.built.consumer_payload.rare_routes) do
		local a = Z.anchor(row.anchor.zone_id, row.anchor.slot_id)
		local route = {}
		for n, o in ipairs(row.patrol_offsets) do route[n] = {x = a.x + o.x, z = a.z + o.z} end
		CM.add_rare_route(world.spawn, route)
	end
	return {world = world, seconds = {regions = os.clock() - t0}}
end
