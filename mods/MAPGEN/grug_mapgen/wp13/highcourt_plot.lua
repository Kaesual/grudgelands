-- One Highcourt district plot, built from a roster row.
--
-- This is the builder the market and professions district carried privately
-- until the other three districts arrived (`highcourt_district.lua` and the
-- three `highcourt_district_*.lua` files). Four districts building the same
-- thing four times would be four places to fix the next plot defect in, so
-- the builder moved here unchanged and the district files became what they
-- should be: rosters.
--
-- WHAT A PLOT IS. A district plot cannot be anchor-relative. The core is flat
-- at the fitted reference height, but WP40 terraces the rest of the 512
-- envelope (step 2 for the human plateau, up to 4 elsewhere), so two plots
-- sixty nodes apart stand at two different heights. The capitals contract
-- section 2.1 settles that with a REFERENCE COLUMN: each plot is authored
-- around its own origin with y = 0 the ground course, and at settle time the
-- settlement config asks the pure final height of one named column once,
-- caches it, and projects the plot's cells from there. What makes that
-- survive a terrace edge under the plot is the other half of the same rule,
-- and both are built here:
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
-- canonical cells, bounds (x/z inside [-13, 13], y [-6, 24]), sorted palette
-- and landmarks, plus `reference` and the `sockets` of the NPC contract.
--
-- THE +-13 IS NOT THE CONTRACT'S +-15, AND THAT IS DELIBERATE. Every plot of
-- every district stands on a LOT of `highcourt_quadrants.lua`, and a lot is
-- held to one envelope on both gate seeds so that any district may stand in
-- any quadrant. Two nodes of the contract's volume are the margin that buys.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local capitals = dofile(directory .. "/capitals.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)

	local M = {}

	-- The plot envelope this builder holds itself to. `REACH` is the ground
	-- the plot may lay; `FLOOR` is how far the skirt reaches down, and it is
	-- the contract's own -6.
	M.REACH = 13
	M.FLOOR = -6
	-- The LEAST airspace a plot clears, whatever its own roof needs. A lot is
	-- allowed to rise 6 nodes under a plot (`highcourt_quadrants.lua`), and a
	-- part whose ridge is four courses up would have cleared 6 and stood with
	-- a shoulder of terrace in its doorway. Every plot the market district
	-- authored already clears 9 or more, so this floor is the low ones' --
	-- the well court, the wain shed -- and changes no cell of theirs.
	M.MIN_CLEAR = 8

	-- The crown's white stone, and the civic slate roof, exactly as
	-- `highcourt.lua` binds them for the core: `signature` is the role every
	-- capital part dresses itself in, so rebinding it turns one part from a
	-- city building into a royal one without a second generator, and a civic
	-- building roofed in the same boards as a cottage reads as a big cottage.
	M.WHITE = {
		signature = "grug_decor:darkage_marble",
		signature_stair = "grug_decor:darkage_marble_stair",
		signature_slab = "grug_decor:darkage_marble_slab",
	}
	M.SLATE = {
		roof_stair = "grug_decor:darkage_slate_tile_stair",
		roof_stair_outer = "grug_decor:darkage_slate_tile_stair_outer",
		roof_stair_inner = "grug_decor:darkage_slate_tile_stair_inner",
		roof_slab = "grug_decor:darkage_slate_tile_slab",
		roof_ridge = "grug_decor:darkage_slate_tile",
	}

	local function merged(...)
		local out = {}
		for _, source in ipairs({...}) do
			for key, value in pairs(source) do out[key] = value end
		end
		return out
	end

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
			if value < -M.REACH then return -M.REACH end
			if value > M.REACH then return M.REACH end
			return value
		end
		margin = margin or 2
		return clamp(x0 - margin), clamp(z0 - margin), clamp(x1 + margin),
			clamp(z1 + margin)
	end

	-- The two extra socket shapes a district roster may publish through
	-- `plot.extra_sockets`, spelled once so four districts spell them the
	-- same way.
	--
	-- A GUARD POST is the sockets contract's "a guard stands here and returns
	-- here after fights"; the martial district is where they belong.
	function M.guard_post(id, x, z, face)
		return {id = "post_" .. id, role = "guard_post", x = x, z = z,
			face = face or 0}
	end

	-- A SPARE is an idle position a walking NPC may use as a DESTINATION and
	-- which the placement engine does not staff with an inhabitant of its own
	-- -- two per district. `spawn = false` is the whole of it, and the registry
	-- of `grug_core/settlement_sockets.lua` accepts it on an `idle` socket and
	-- on nothing else.
	--
	-- NO TAG, deliberately, and the same rule the core's ten spares follow: a
	-- tag is what an idle NPC's spoken line reads off, and nobody stands here
	-- to say anything. A spare is a place to stand.
	function M.spare(id, x, z, face)
		return {id = "spare_" .. id, role = "idle", x = x, z = z,
			face = face or 0, spawn = false}
	end

	-- Build one plot from its roster row.
	--
	-- The row: `id`, `module` ("capitals" or "buildings"), `make` (the
	-- generator), `spec` (its arguments), and optionally `turns` (quarter
	-- turns of the part on its own plot), `margin` (extra ground all round),
	-- `handle` ("human" or "white"), `roof` ("slate"), `garden`, `order` (its
	-- waypoint in the district loop), `decorate` and `extra_sockets`.
	function M.build(plot, context)
		context = context or {}
		local watch = plot.patrol_group or context.patrol_group
		local base = palettes.new("human")
		local palette = base
		if plot.handle == "white" then
			palette = palettes.new("human", M.WHITE)
		end
		local roof_palette
		if plot.roof == "slate" then
			if plot.handle == "white" then
				roof_palette = palettes.new("human", merged(M.WHITE, M.SLATE))
			else
				roof_palette = palettes.new("human", M.SLATE)
			end
		end
		local spec = {}
		for key, value in pairs(plot.spec) do spec[key] = value end
		spec.id = plot.id
		if roof_palette then spec.roof_palette = roof_palette end
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
		local clear_to = part.peak + 2
		if clear_to < M.MIN_CLEAR then clear_to = M.MIN_CLEAR end
		buf:clear(x0, 1, z0, x1, clear_to, z1)
		-- 2. The foundation skirt, the perimeter only, down to the
		-- contract's floor.
		for y = -1, M.FLOOR, -1 do
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

		-- 5c. Whatever this plot alone wants on its own ground: the drill
		-- yard's posts and standards, the herb garden's beds, the tavern's
		-- trestles. It is handed the buffer, the palette and the plot's own
		-- ground rectangle, and it runs BEFORE the sockets are collected so a
		-- piece of dressing can stand where a socket would otherwise be
		-- published into a wall.
		local area = {x0 = x0, z0 = z0, x1 = x1, z1 = z1, ox = ox, oz = oz,
			pw = rw, pd = rd, peak = part.peak, dressing = dressing,
			parts = parts}
		if type(plot.decorate) == "function" then
			plot.decorate(buf, palette, area)
		end

		-- 6. Sockets: the part's own, plus this plot's waypoint in the
		-- district loop where the part publishes none of its own.
		local sockets = {}
		-- What this plot changes about the sockets its PART published. A
		-- generator in `capitals.lua` knows its own building and nothing about
		-- the composition it is built into, so it cannot know which of its
		-- walls faces a lane or where this plot's path runs; the roster says
		-- so instead of the library being edited per composition. Keyed by
		-- socket id, and a function of the plot's own ground rectangle,
		-- because that is where the answers are.
		local overrides = {}
		if type(plot.socket_overrides) == "function" then
			overrides = plot.socket_overrides(area)
		end
		for _, entry in ipairs(points.sockets or {}) do
			-- `spawn` travels with the socket: a generator that publishes a
			-- spare must not lose it here, the way the first version of this
			-- copy would have (`highcourt.lua` carries the same field in the
			-- core's own copy for the same reason).
			--
			local override = overrides[entry.id] or {}
			sockets[#sockets + 1] = {id = entry.id, role = entry.role,
				x = override.x or entry.x, y = override.y or entry.y,
				z = override.z or entry.z,
				face = override.face or entry.face,
				group = entry.group, order = entry.order, kind = entry.kind,
				spawn = entry.spawn, tags = override.tags or entry.tags}
		end
		if plot.order then
			sockets[#sockets + 1] = {id = plot.id .. "_watch",
				role = "guard_patrol", x = 0, y = 1, z = z0 + 2, face = 0,
				group = watch, order = plot.order}
		end
		-- Every plot publishes one flair spot at its own gate, on the
		-- doorstep path: the plots built from `buildings.lua` publish no
		-- socket of their own (a start generator knows nothing about the
		-- NPC seam), and a district of nine plots with four inhabited ones
		-- is not a district anybody lives in.
		sockets[#sockets + 1] = {id = plot.id .. "_gate_idle", role = "idle",
			x = 0, y = 1, z = z0 + 2, face = 0, tags = {"door"}}
		-- Whatever this plot alone publishes: the martial district's guard
		-- posts, a district's two spare wander spots. It is handed the same
		-- ground rectangle the decoration was, because a socket is a promise
		-- that somebody can stand there and only the plot knows which of its
		-- corners is still free after its own dressing.
		if type(plot.extra_sockets) == "function" then
			for _, entry in ipairs(plot.extra_sockets(area)) do
				sockets[#sockets + 1] = {id = plot.id .. "_" .. entry.id,
					role = entry.role, x = entry.x, y = entry.y or 1,
					z = entry.z, face = entry.face or 0, tags = entry.tags,
					spawn = entry.spawn}
			end
		end
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
			-- The airspace this plot actually cleared. `bounds.max.y` is not
			-- that number: a lamp post or a fruit tree written after the
			-- clear reaches above it, so a legality predicate reading the
			-- bounds would credit the plot with headroom it never cut. This
			-- is what `tools/wp13/highcourt_plots.lua` holds the lot's rise
			-- against.
			clear_to = clear_to,
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

	-- A district: its key, its role, its patrol loop and the ordered plot
	-- list, each entry carrying a builder that returns the composition. The
	-- OFFSET is not here -- a district does not know which quadrant it stands
	-- in until the world seed says so (`highcourt_quadrants.lua`).
	function M.district(definition)
		local district = {
			key = definition.key,
			role = definition.role,
			patrol_group = definition.patrol_group,
			plots = {},
		}
		for index, plot in ipairs(definition.plots) do
			district.plots[index] = {
				id = plot.id,
				build = function()
					return M.build(plot, {patrol_group = definition.patrol_group})
				end,
			}
		end
		return district
	end

	return M
end

return loader
