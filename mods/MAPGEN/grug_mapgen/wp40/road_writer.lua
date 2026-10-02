-- Round 22 Phase 4: dressing the road columns in the writer (world_zones.md
-- §9, plan D44, D47, D48, D74). The terrain already carries the road's cut
-- and fill (height.lua gives road columns their road-adjusted terrain y, so
-- the planner writes natural ground with its own surface on cut slopes and
-- embankments). This pass, first in the R7 successor settle, only replaces
-- what the planner cannot express:
--   * the road surface node on the terrain top, and a slab on top of it
--     where the road stands on a half step (D47);
--   * decks and bridges: the surface node (and slab) at the road height and
--     pillars down to the ground (through water) at pillar columns;
--   * the retaining wall at the foot of a deep cut;
--   * a few nodes of clearance above the road (leaves, decorations).
-- One design, materials per race region (D48). Every road has exactly one
-- surface material, on the ground and on decks alike, with slabs of the
-- same material; no railings (D74) except on the straight decks and bridges
-- of capital streets (D75, the sampler's rail flag). A bridge run (a raised run that
-- crosses water, `road_layout.lua` sampler) takes the bridge material as a
-- whole, surface and slabs. Pillars are the second material. Trails take
-- the same materials as roads, only narrower (D75). Settlement and POI
-- stamps come later in the same settle and overwrite a road where they meet
-- it.
-- The same pass builds the piers of the dragon-island boat landings (Round
-- 30 lane L, boats.md §7) from the landing zone's bridge planks, rail fence
-- and post trunk (`source` is `source/simple_map.lua`).
return function(core_api, source)
	local function fail(message) error("WP40 road writer: " .. message, 0) end
	if type(core_api) ~= "table" or type(core_api.get_content_id) ~= "function" or
			type(core_api.registered_nodes) ~= "table" or type(source) ~= "table" or
			type(source.island_landings) ~= "table" then
		fail("construction seam differs")
	end
	local floor = math.floor

	local MATERIALS = {
		human = {surface = "default:cobble", slab = "stairs:slab_cobble",
			bridge = "default:wood", bridge_slab = "stairs:slab_wood",
			pillar = "default:tree", wall = "default:stonebrick", rail = "default:fence_wood",
			post = "default:tree"},
		dwarf = {surface = "default:stone_block", slab = "stairs:slab_stone_block",
			bridge = "default:pine_wood", bridge_slab = "stairs:slab_pine_wood",
			pillar = "default:stonebrick", wall = "default:stonebrick", rail = "default:fence_pine_wood",
			post = "default:pine_tree"},
		elf = {surface = "default:silver_sandstone_block",
			slab = "stairs:slab_silver_sandstone_block",
			bridge = "default:aspen_wood", bridge_slab = "stairs:slab_aspen_wood",
			pillar = "default:aspen_tree", wall = "default:silver_sandstone_brick", rail = "default:fence_aspen_wood",
			post = "default:aspen_tree"},
		undead = {surface = "default:stonebrick", slab = "stairs:slab_stonebrick",
			bridge = "default:pine_wood", bridge_slab = "stairs:slab_pine_wood",
			pillar = "default:mossycobble", wall = "default:mossycobble", rail = "default:fence_pine_wood",
			post = "default:pine_tree"},
		orc = {surface = "default:desert_cobble", slab = "stairs:slab_desert_cobble",
			bridge = "default:acacia_wood", bridge_slab = "stairs:slab_acacia_wood",
			pillar = "default:acacia_tree", wall = "default:desert_stonebrick", rail = "default:fence_acacia_wood",
			post = "default:acacia_tree"},
		troll = {surface = "default:mossycobble", slab = "stairs:slab_mossycobble",
			bridge = "default:junglewood", bridge_slab = "stairs:slab_junglewood",
			pillar = "default:jungletree", wall = "default:mossycobble", rail = "default:fence_junglewood",
			post = "default:jungletree"},
	}
	-- nodes cleared above a road surface or deck (the walking space)
	local CLEAR_ABOVE = 4

	local function cid(name)
		if not core_api.registered_nodes[name] then fail("road material missing: " .. name) end
		return core_api.get_content_id(name)
	end
	local resolved = {}
	for race, row in pairs(MATERIALS) do
		local r = {}
		for key, name in pairs(row) do r[key] = cid(name) end
		resolved[race] = r
	end
	local air = core_api.CONTENT_AIR or cid("air")
	-- Liquids are never cleared (a ford's water stays).
	local liquid_by_cid = {}
	local function is_liquid(c)
		local v = liquid_by_cid[c]
		if v == nil then
			local name = core_api.get_name_from_content_id(c)
			local def = name and core_api.registered_nodes[name]
			v = def ~= nil and (def.liquidtype or "none") ~= "none"
			liquid_by_cid[c] = v
		end
		return v
	end

	-- Island landing piers (Round 30 lane L, boats.md §7). The shore point is
	-- the last land column on the boat line, walking from the landing toward
	-- the mainland until the first sea column (the same walk as the beach in
	-- `height.lua`). From there a deck of planks PIER_WIDTH nodes wide runs
	-- PIER_LENGTH nodes out over the water at PIER_DECK_Y (one node above the
	-- water) and PIER_ROOT columns back onto the beach's water line. Every
	-- PIER_POST_EVERY nodes from the pier head a row of trunk posts stands on
	-- the floor: under the deck up to the water surface, beside it up to the
	-- deck with a fence on top. Materials: the landing zone's race (planks,
	-- fence, trunk); default planks without one.
	local PIER_LENGTH, PIER_ROOT, PIER_WIDTH, PIER_POST_EVERY = 10, 2, 2, 3
	local PIER_DECK_Y, PIER_WALK = 2, 160
	local piers = {}
	do
		local path_by_id = {}
		for _, path in ipairs(source.boat_paths or {}) do path_by_id[path.id] = path end
		for _, landing in ipairs(source.island_landings) do
			local path = path_by_id[landing.boat_path_id]
			local zone = source.zones[landing.zone_numeric_id]
			if not path or not zone then fail("island landing row differs: " .. tostring(landing.id)) end
			local line = path.centreline
			local dx = line[#line - 1].x - line[#line].x
			local dz = line[#line - 1].z - line[#line].z
			-- the boat paths are axis-aligned: one unit step toward the mainland
			local ux, uz = 0, 0
			if math.abs(dx) >= math.abs(dz) then ux = dx > 0 and 1 or -1 else uz = dz > 0 and 1 or -1 end
			local px, pz = landing.position.x, landing.position.z
			local ex = px + ux * (PIER_WALK + PIER_LENGTH)
			local ez = pz + uz * (PIER_WALK + PIER_LENGTH)
			-- every column the pier can reach, whatever the shore point
			local reach = PIER_WIDTH + 1
			piers[#piers + 1] = {x = px, z = pz, ux = ux, uz = uz,
				m = resolved[zone.race_region] or resolved.human,
				min_x = math.min(px, ex) - reach, max_x = math.max(px, ex) + reach,
				min_z = math.min(pz, ez) - reach, max_z = math.max(pz, ez) + reach}
		end
	end
	-- A sea column: water that is not a river or lake (those stay land).
	local function sea_at(context, x, z)
		local water_class, _, _, _, _, _, _, river_id = context.column_values_at(x, z)
		return water_class ~= "land" and river_id == nil
	end
	local function dress_pier(context, pier, put)
		local sx, sz
		for k = 0, PIER_WALK do
			local x, z = pier.x + k * pier.ux, pier.z + k * pier.uz
			if sea_at(context, x, z) then
				if k > 0 then sx, sz = x - pier.ux, z - pier.uz end
				break
			end
		end
		if not sx then return end
		local m = pier.m
		-- `a` along the pier (1 = the first water column), `b` across it
		local vx, vz = -pier.uz, pier.ux
		for a = 1 - PIER_ROOT, PIER_LENGTH do
			local post_row = a >= 1 and (PIER_LENGTH - a) % PIER_POST_EVERY == 0
			for b = -1, PIER_WIDTH do
				local x, z = sx + a * pier.ux + b * vx, sz + a * pier.uz + b * vz
				local deck = b >= 0 and b < PIER_WIDTH
				if (deck or post_row) and x >= context.min_x and x <= context.max_x and
						z >= context.min_z and z <= context.max_z then
					local ground = select(6, context.column_values_at(x, z))
					local wet = sea_at(context, x, z)
					-- dry land above the water line is the beach: no pier
					if wet or ground < PIER_DECK_Y then
						if deck then
							put(x, PIER_DECK_Y, z, m.bridge)
							if post_row and wet then
								for y = ground + 1, PIER_DECK_Y - 1 do put(x, y, z, m.post) end
							end
						else
							for y = ground + 1, PIER_DECK_Y do put(x, y, z, m.post) end
							put(x, PIER_DECK_Y + 1, z, m.rail)
						end
					end
				end
			end
		end
	end

	local writer = {}
	-- `context`: the R7 successor context (min/max bounds, inside_owner,
	-- settled_at, column_values_at, road_column_at, write_road).
	function writer.dress(context)
		local min_y, max_y = context.min_y, context.max_y
		local write = context.write_road
		local function put(x, y, z, c)
			if y >= min_y and y <= max_y then write(x, y, z, c, 0) end
		end
		local function clear(x, y0, y1, z)
			for y = y0, y1 do
				if y >= min_y and y <= max_y then
					local c = context.settled_at(x, y, z)
					if c ~= air and not is_liquid(c) then write(x, y, z, air, 0) end
				end
			end
		end
		local count = 0
		for z = context.min_z, context.max_z do
			for x = context.min_x, context.max_x do
				local kind, road_y, terrain_y, class, pillar, bridge, wall_base, _, rail =
					context.road_column_at(x, z)
				if kind ~= nil then
					local race = select(5, context.column_values_at(x, z))
					local m = resolved[race] or resolved.human
					if kind == "surface" then
						count = count + 1
						-- the road's one surface material (D74)
						local surface, slab = m.surface, m.slab
						if bridge then surface, slab = m.bridge, m.bridge_slab end
						local top = floor(road_y)
						local half = road_y - top >= 0.5
						if class == "deck" or class == "bridge" then
							put(x, top, z, surface)
							local above = top + 1
							if half then put(x, above, z, slab); above = above + 1 end
							if pillar then
								for y = terrain_y + 1, top - 1 do put(x, y, z, m.pillar) end
							end
							if rail then put(x, above, z, m.rail); above = above + 1 end
							clear(x, above, top + CLEAR_ABOVE, z)
						elseif class == "ford" then
							-- the raised bed under the water; a slab on a half step
							-- (it takes the place of one water node)
							put(x, terrain_y, z, surface)
							if half and top == terrain_y then put(x, terrain_y + 1, z, slab) end
						else
							-- grade, cut, fill: the terrain top is the road bed
							put(x, terrain_y, z, surface)
							local above = terrain_y + 1
							if half and top == terrain_y then put(x, above, z, slab); above = above + 1 end
							clear(x, above, terrain_y + CLEAR_ABOVE, z)
						end
					elseif kind == "wall" and wall_base then
						for y = wall_base, terrain_y do put(x, y, z, m.wall) end
					end
				end
			end
		end
		for index = 1, #piers do
			local pier = piers[index]
			if pier.min_x <= context.max_x and pier.max_x >= context.min_x and
					pier.min_z <= context.max_z and pier.max_z >= context.min_z then
				dress_pier(context, pier, put)
			end
		end
		return count
	end
	return writer
end
