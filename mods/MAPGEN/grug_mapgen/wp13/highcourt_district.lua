-- Highcourt, the market and professions district: nine terrain-relative plots
-- along the east avenue and the ring street.
--
-- A district plot cannot be anchor-relative. The core is flat at the fitted
-- reference height, but WP40 terraces the rest of the 512 envelope (step 2 for
-- the human plateau, up to 4 elsewhere), so two plots sixty nodes apart stand
-- at two different heights. The capitals contract section 2.1 settles that
-- with a REFERENCE COLUMN: each plot is authored around its own origin with
-- y = 0 the ground course, and at settle time the settlement config asks the
-- pure final height of one named column once, caches it, and projects the
-- plot's cells from there. What makes that survive a terrace edge under the
-- plot is the other half of the same rule, and both are built here:
--
--   * a FOUNDATION SKIRT: the perimeter of the plot carried down to y = -6,
--     so a plot whose downhill corner hangs four nodes over the step still
--     stands on masonry and not on air;
--   * a CLEAR VOLUME: the plot's own airspace up to its roof, so the uphill
--     corner of the same step does not push a shoulder of terrace through
--     the building's wall.
--
-- Only the perimeter is skirted and only the airspace is cleared, because a
-- solid block of both would cost a plot four thousand cells of buried stone
-- and put it over the contract's 12,000-cell budget on its own.
--
-- Every plot is a SELF-CONTAINED composition in the shape of a start: schema,
-- canonical cells, bounds (x/z [-15, 15], y [-6, 24]), sorted palette and
-- landmarks, plus `reference` and the `sockets` of the NPC contract.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local capitals = dofile(directory .. "/capitals.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)

	local M = {}

	-- The contract's plot envelope.
	local REACH = 15
	local FLOOR = -6

	local WATCH = "highcourt_market_watch"

	-- The civic roof of the capital, as in `highcourt.lua`: the two public
	-- plots of the district carry slate, the working ones plank.
	local SLATE = {
		roof_stair = "grug_decor:darkage_slate_tile_stair",
		roof_stair_outer = "grug_decor:darkage_slate_tile_stair_outer",
		roof_stair_inner = "grug_decor:darkage_slate_tile_stair_inner",
		roof_slab = "grug_decor:darkage_slate_tile_slab",
		roof_ridge = "grug_decor:darkage_slate_tile",
	}

	-- The roster. `x`/`z` is the plot origin's offset from the CAPITAL
	-- anchor, so a settle-time projection is `anchor + offset + cell`; the
	-- east avenue runs along z = 0 from the core edge at 48 out to the gate
	-- station at 256, and the ring street crosses it at x = 96.
	--
	-- `order` is the plot's waypoint in the district's own patrol loop, which
	-- is one loop with one group and no gaps: the KAT walks it.
	local PLOTS = {
		{id = "market_granary", module = "capitals", make = "granary",
			x = 72, z = -28, order = 1, along = "avenue",
			spec = {w = 11, d = 15, wall_h = 5}},
		{id = "market_stable", module = "capitals", make = "stable",
			x = 72, z = 28, order = 2, along = "avenue",
			spec = {w = 15, d = 11, wall_h = 5}},
		-- The workshop's chimney stacks are passed explicitly. Its default
		-- pair stands one of them on the middle cell of the z- gable
		-- (`math.floor(w / 2)`, z = 0), which is exactly where a centred
		-- door in that gable goes, and the stack is written after the door:
		-- the leaf ends up bricked over and the building still has a door
		-- landmark pointing at masonry. Dawnmere's smithy opens in the x-
		-- wall, so no start ever asked for the two at once.
		-- The workshop opens in its x- wall, like Dawnmere's smithy, and the
		-- PLOT is turned so that wall faces the street. Its z- gable cannot
		-- carry the door: the `workshop` interior kit stands the forge's
		-- cauldrons on the odd cells of the inner run of that very wall, and
		-- a double door takes an odd cell whichever index it is given, so
		-- the doorway opens onto a hearth. The same wall also carries the
		-- generator's default chimney stack at its middle cell.
		{id = "market_workshop", module = "buildings", make = "workshop",
			x = 116, z = -28, order = 3, along = "avenue", turns = 3,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true}},
		{id = "market_counting_house", module = "capitals",
			make = "scriptorium", x = 116, z = 28, order = 4,
			along = "avenue", roof = "slate",
			spec = {w = 13, d = 17, wall_h = 6}},
		-- The well court is the district's public garden, so its plot is
		-- five nodes wider all round than a building's and the ring that
		-- buys is planted. On the first render it was a paved square with a
		-- well on it standing in a field, which is what a court with a
		-- two-node verge looks like from outside.
		{id = "market_well", module = "capitals", make = "well_court",
			x = 152, z = -28, order = 5, along = "avenue", margin = 5,
			garden = true, spec = {size = 11}},
		-- The watch stands at z = 31, not 28: the gate corridor WP40 keeps
		-- clear is 32 nodes wide (z -16..16) and a 21-deep barracks centred
		-- on 28 reaches z = 15. Nothing enforces that width anywhere in the
		-- tree, so it is kept here.
		{id = "market_watch", module = "capitals", make = "barracks",
			x = 152, z = 31, along = "avenue", roof = "slate",
			spec = {w = 15, d = 21, wall_h = 5, patrol_group = WATCH,
				order = 6}},
		{id = "market_grove", module = "capitals", make = "grove",
			x = 76, z = -64, order = 7, along = "ring",
			spec = {size = 15, kind = "broadleaf", height = 6}},
		{id = "market_orchard", module = "capitals", make = "orchard_edge",
			x = 76, z = 64, along = "ring",
			spec = {len = 21, d = 11, patrol_group = WATCH, order = 8}},
		-- Door index 4, single leaf: the `store` kit stands its roof posts
		-- on the odd cells of the gable's inner run, so an eleven-wide
		-- longhouse's centred door opens onto a post (see the same note in
		-- `highcourt.lua` for the household store).
		{id = "market_store", module = "buildings", make = "longhouse",
			x = 116, z = -64, order = 10, along = "ring",
			spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
				door_index = 4, infill = true}},
	}

	-- The plot's own ground area: the part's extent grown by two nodes on
	-- every side and then clamped into the envelope, so the kerb, the
	-- doorstep path and the lamps stand on the plot and not beside it.
	local function ground_area(part, ox, oz, turns, margin)
		local order, count = part.buffer:cells()
		local x0, x1, z0, z1
		for index = 1, count do
			local cell = order[index]
			if cell.name ~= parts.AIR then
				local rx, rz = parts.rotate_footprint(cell.x, cell.z,
					part.w, part.d, turns)
				local x, z = ox + rx, oz + rz
				if x0 == nil or x < x0 then x0 = x end
				if x1 == nil or x > x1 then x1 = x end
				if z0 == nil or z < z0 then z0 = z end
				if z1 == nil or z > z1 then z1 = z end
			end
		end
		local function clamp(value)
			if value < -REACH then return -REACH end
			if value > REACH then return REACH end
			return value
		end
		margin = margin or 2
		return clamp(x0 - margin), clamp(z0 - margin), clamp(x1 + margin),
			clamp(z1 + margin)
	end

	-- Build one plot.
	local function build(plot)
		local palette = palettes.new("human")
		local slate = palettes.new("human", SLATE)
		local spec = {}
		for key, value in pairs(plot.spec) do spec[key] = value end
		spec.id = plot.id
		if plot.roof == "slate" then spec.roof_palette = slate end
		local module = (plot.module == "capitals") and capitals or buildings
		local generator = module[plot.make]
		if type(generator) ~= "function" then
			error("wp13 highcourt district: no generator " .. plot.make, 0)
		end
		local part = generator(palette, spec)
		-- The part is centred on the plot origin, which is also the
		-- reference column: the terrain height under the middle of the plot
		-- is the height the whole plot is levelled to. A quarter turn swaps
		-- the footprint, so the centring reads the ROTATED width.
		local turns = (plot.turns or 0) % 4
		local rw = (turns % 2 == 1) and part.d or part.w
		local rd = (turns % 2 == 1) and part.w or part.d
		local ox = -math.floor((rw - 1) / 2)
		local oz = -math.floor((rd - 1) / 2)
		local x0, z0, x1, z1 = ground_area(part, ox, oz, turns, plot.margin)

		local buf = parts.buffer()
		-- 1. The plot's ground and its airspace. The clear goes down to the
		-- ground course as well, because the terrace shoulder this plot cuts
		-- through occupies those cells in the world.
		buf:fill(x0, -1, z0, x1, -1, z1, palette.node("subsoil"))
		buf:fill(x0, 0, z0, x1, 0, z1, palette.node("ground"))
		buf:clear(x0, 1, z0, x1, part.peak + 2, z1)
		-- 2. The foundation skirt, the perimeter only, down to the
		-- contract's floor.
		for y = -1, FLOOR, -1 do
			for z = z0, z1 do
				for x = x0, x1 do
					if x == x0 or x == x1 or z == z0 or z == z1 then
						buf:put(x, y, z, palette.node("foundation"))
					end
				end
			end
		end
		-- 3. The kerb of the plot, and the doorstep path from the part's own
		-- apron out to the street edge of the plot.
		dressing.inlay(buf, palette, x0, z0, x1, z1)
		for z = z0 + 1, oz - 1 do
			for x = -1, 1 do
				buf:put(x, 0, z, palette.node("path"))
			end
		end

		-- 4. The part itself.
		local points = parts.stamp(buf, part, ox, 0, oz, turns)

		-- 5. Two lamps on the street corners of the plot, and a bench beside
		-- the door.
		local lamps = {{x0 + 1, z0 + 1}, {x1 - 1, z0 + 1}}
		for _, lamp in ipairs(lamps) do
			dressing.path_light(buf, palette, lamp[1], lamp[2])
		end
		dressing.bench(buf, palette, 3, z0 + 2, 0, 3, "x")

		-- 5b. A garden plot plants the ring its wider ground bought: a fruit
		-- tree at each corner, a planter and a bench between them, and the
		-- carrier's crates by the gate. Everything stands on the plot's own
		-- turf, outside the part's paving, which is why only a plot with a
		-- margin may ask for it.
		if plot.garden then
			for _, spot in ipairs({{x0 + 2, z0 + 2}, {x1 - 2, z0 + 2},
					{x0 + 2, z1 - 2}, {x1 - 2, z1 - 2}}) do
				dressing.broadleaf(buf, palette, spot[1], spot[2], 5)
			end
			dressing.planter(buf, palette, x0 + 1, oz - 1, x0 + 2, oz + 1)
			dressing.planter(buf, palette, x1 - 2, oz - 1, x1 - 1, oz + 1)
			dressing.bench(buf, palette, -1, z1 - 2, 2, 3, "x")
			dressing.crates(buf, palette, x1 - 2, z0 + 4, 2)
		end

		-- 6. Sockets: the part's own, plus this plot's waypoint in the
		-- district loop where the part publishes none of its own.
		local sockets = {}
		for _, entry in ipairs(points.sockets or {}) do
			sockets[#sockets + 1] = {id = entry.id, role = entry.role,
				x = entry.x, y = entry.y, z = entry.z, face = entry.face,
				group = entry.group, order = entry.order, kind = entry.kind,
				tags = entry.tags}
		end
		if plot.order then
			sockets[#sockets + 1] = {id = plot.id .. "_watch",
				role = "guard_patrol", x = 0, y = 1, z = z0 + 2, face = 0,
				group = WATCH, order = plot.order}
		end
		-- Every plot publishes one flair spot at its own gate, on the
		-- doorstep path: the plots built from `buildings.lua` publish no
		-- socket of their own (a start generator knows nothing about the
		-- NPC seam), and a district of nine plots with four inhabited ones
		-- is not a district anybody lives in.
		sockets[#sockets + 1] = {id = plot.id .. "_gate_idle", role = "idle",
			x = 0, y = 1, z = z0 + 2, face = 0, tags = {"door"}}
		for _, entry in ipairs(sockets) do
			local dx, dz = parts.facedir_step(entry.face)
			entry.dir = {x = dx, z = dz}
		end

		parts.resolve_panes(buf)

		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		table.sort(cells, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		local light_names = {[palette.node("light_post")] = true,
			[palette.node("light_wall")] = true,
			[palette.node("light_indoor")] = true}
		local lights = {}
		local names, palette_list = {}, {}
		local minp = {x = cells[1].x, y = cells[1].y, z = cells[1].z}
		local maxp = {x = cells[1].x, y = cells[1].y, z = cells[1].z}
		for index = 1, #cells do
			local cell = cells[index]
			if light_names[cell.name] then
				lights[#lights + 1] = {x = cell.x, y = cell.y, z = cell.z}
			end
			if not names[cell.name] then
				names[cell.name] = true
				palette_list[#palette_list + 1] = cell.name
			end
			if cell.x < minp.x then minp.x = cell.x end
			if cell.y < minp.y then minp.y = cell.y end
			if cell.z < minp.z then minp.z = cell.z end
			if cell.x > maxp.x then maxp.x = cell.x end
			if cell.y > maxp.y then maxp.y = cell.y end
			if cell.z > maxp.z then maxp.z = cell.z end
		end
		table.sort(palette_list, parts.less_bytes)

		local doorways = {}
		for _, door in ipairs(points.doors or {}) do
			doorways[#doorways + 1] = {x = door.x, y = door.y, z = door.z,
				face = door.face, id = plot.id}
		end
		local rooms = {}
		for index = 1, #(points.room_corner or {}), 2 do
			local a = points.room_corner[index]
			local b = points.room_corner[index + 1]
			rooms[#rooms + 1] = {
				min = {x = math.min(a.x, b.x), y = a.y, z = math.min(a.z, b.z)},
				max = {x = math.max(a.x, b.x), y = a.y, z = math.max(a.z, b.z)},
				top = a.top, closed = a.closed, id = plot.id,
			}
		end
		local destinations = {}
		local spot = (points.inside or {})[1]
		if spot then
			destinations[1] = {id = plot.id, x = spot.x, y = spot.y,
				z = spot.z}
		end

		return {
			-- One schema per plot, not one for the district: the successor
			-- compares `blueprint.schema` with the profile's own
			-- (`r7_settlement.validate`), so nine plots behind one string
			-- would need nine profiles that all claim to be the same
			-- blueprint.
			schema = "grug_wp13_highcourt_plot_" .. plot.id .. "_v1",
			id = plot.id,
			cells = cells,
			bounds = {min = minp, max = maxp},
			palette = palette_list,
			-- The column whose final terrain height becomes this plot's
			-- y = 0. It is the plot origin, that is the middle of the
			-- building: a plot levels to the ground under its own centre,
			-- never to a corner, or half of every plot on a slope would
			-- stand a terrace step too high.
			reference = {x = 0, z = 0},
			landmarks = {
				arrival = {x = 0, y = 1, z = z0 + 2},
				plot = {min = {x = x0, y = -1, z = z0},
					max = {x = x1, y = part.peak, z = z1}},
				entry = {x = 0, y = 1, z = z0 + 1},
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = sockets,
			},
		}
	end

	-- The district: its key, the quadrant it occupies and the ordered plot
	-- list. Each entry carries the plot's offset from the capital anchor and
	-- a builder that returns the plot composition.
	M.market = {
		key = "highcourt_market",
		role = "market_professions",
		quadrant = "east",
		patrol_group = WATCH,
		plots = {},
	}
	for index, plot in ipairs(PLOTS) do
		M.market.plots[index] = {
			id = plot.id,
			x = plot.x,
			z = plot.z,
			along = plot.along,
			build = function() return build(plot) end,
		}
	end

	return M
end

return loader
