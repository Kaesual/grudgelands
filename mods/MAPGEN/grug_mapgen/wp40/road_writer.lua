-- Round 22 Phase 4: dressing the road columns in the writer (world_zones.md
-- §9, plan D44, D47, D48). The terrain already carries the road's cut and
-- fill (height.lua gives road columns their road-adjusted terrain y, so the
-- planner writes natural ground with its own surface on cut slopes and
-- embankments). This pass, first in the R7 successor settle, only replaces
-- what the planner cannot express:
--   * the road surface node on the terrain top, and a slab on top of it
--     where the road stands on a half step (D47);
--   * decks and bridges: the deck node (and slab) at the road height,
--     pillars down to the ground (through water) at pillar columns, a rail
--     on the open edge;
--   * the retaining wall at the foot of a deep cut;
--   * a few nodes of clearance above the road (leaves, decorations).
-- One design, materials per race region (D48); trails take gravel with the
-- race's stone slab on half steps. Settlement and POI stamps come later in
-- the same settle and overwrite a road where they meet it.
return function(core_api)
	local function fail(message) error("WP40 road writer: " .. message, 0) end
	if type(core_api) ~= "table" or type(core_api.get_content_id) ~= "function" or
			type(core_api.registered_nodes) ~= "table" then
		fail("construction seam differs")
	end
	local floor = math.floor

	local MATERIALS = {
		human = {surface = "default:cobble", slab = "stairs:slab_cobble",
			deck = "default:wood", deck_slab = "stairs:slab_wood",
			pillar = "default:tree", rail = "default:fence_rail_wood",
			wall = "default:stonebrick"},
		dwarf = {surface = "default:stone_block", slab = "stairs:slab_stone_block",
			deck = "default:pine_wood", deck_slab = "stairs:slab_pine_wood",
			pillar = "default:stonebrick", rail = "default:fence_rail_pine_wood",
			wall = "default:stonebrick"},
		elf = {surface = "default:silver_sandstone_block",
			slab = "stairs:slab_silver_sandstone_block",
			deck = "default:aspen_wood", deck_slab = "stairs:slab_aspen_wood",
			pillar = "default:aspen_tree", rail = "default:fence_rail_aspen_wood",
			wall = "default:silver_sandstone_brick"},
		undead = {surface = "default:stonebrick", slab = "stairs:slab_stonebrick",
			deck = "default:pine_wood", deck_slab = "stairs:slab_pine_wood",
			pillar = "default:mossycobble", rail = "default:fence_rail_pine_wood",
			wall = "default:mossycobble"},
		orc = {surface = "default:desert_cobble", slab = "stairs:slab_desert_cobble",
			deck = "default:acacia_wood", deck_slab = "stairs:slab_acacia_wood",
			pillar = "default:acacia_tree", rail = "default:fence_rail_acacia_wood",
			wall = "default:desert_stonebrick"},
		troll = {surface = "default:mossycobble", slab = "stairs:slab_mossycobble",
			deck = "default:junglewood", deck_slab = "stairs:slab_junglewood",
			pillar = "default:jungletree", rail = "default:fence_rail_junglewood",
			wall = "default:mossycobble"},
	}
	local TRAIL_SURFACE = "default:gravel"
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
		r.trail_surface = cid(TRAIL_SURFACE)
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
				local kind, road_y, terrain_y, class, pillar, rail, wall_base, road_kind =
					context.road_column_at(x, z)
				if kind ~= nil then
					local race = select(5, context.column_values_at(x, z))
					local m = resolved[race] or resolved.human
					if kind == "surface" then
						count = count + 1
						local top = floor(road_y)
						local half = road_y - top >= 0.5
						if class == "deck" or class == "bridge" then
							put(x, top, z, m.deck)
							local above = top + 1
							if half then put(x, above, z, m.deck_slab); above = above + 1 end
							if pillar then
								for y = terrain_y + 1, top - 1 do put(x, y, z, m.pillar) end
							end
							if rail then put(x, top + 1, z, m.rail); above = top + 2 end
							clear(x, above, top + CLEAR_ABOVE, z)
						elseif class == "ford" then
							-- the raised bed under the water; a slab on a half step
							-- (it takes the place of one water node)
							put(x, terrain_y, z, road_kind == "trail" and m.trail_surface or m.surface)
							if half and top == terrain_y then put(x, terrain_y + 1, z, m.slab) end
						else
							-- grade, cut, fill: the terrain top is the road bed
							put(x, terrain_y, z, road_kind == "trail" and m.trail_surface or m.surface)
							local above = terrain_y + 1
							if half and top == terrain_y then put(x, above, z, m.slab); above = above + 1 end
							clear(x, above, terrain_y + CLEAR_ABOVE, z)
						end
					elseif kind == "wall" and wall_base then
						for y = wall_base, terrain_y do put(x, y, z, m.wall) end
					end
				end
			end
		end
		return count
	end
	return writer
end
