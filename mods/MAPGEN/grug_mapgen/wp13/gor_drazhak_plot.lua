-- One Gor Drazhak district plot, built from a roster row.
--
-- This is `highcourt_plot.lua`'s builder for the orc capital. That file is the
-- pilot capital's own and is hard-wired to the human palette, its white
-- marble crown and its slate roofs; this one is hard-wired to the orc palette,
-- its ors-stone base courses and its FLAT DECKS BEHIND PARAPETS, which is the
-- thing the contract's section 2.4 orc line names first and the thing that
-- makes Gor Drazhak legible from the gate. Everything else about what a plot
-- IS -- and all of it matters -- is Highcourt's and is restated here because
-- the two builders must not drift apart silently:
--
-- WHAT A PLOT IS. A district plot cannot be anchor-relative. The core is flat
-- at the fitted reference height, but WP40 terraces the rest of the 512
-- envelope in FOUR-node steps for the orc mesa -- the deepest of the six races,
-- with the dwarf -- so two plots sixty nodes apart stand at two different
-- heights. The capitals contract section 2.1 settles that with a REFERENCE
-- COLUMN: each plot is authored around its own origin with y = 0 the ground
-- course, and at settle time the settlement config asks the pure final height
-- of one named column once, caches it, and projects the plot's cells from
-- there. What makes that survive a terrace edge under the plot is the other
-- half of the same rule, and both are built here:
--
--   * a FOUNDATION SKIRT: the perimeter of the plot carried down to y = -6, so
--     a plot whose downhill corner hangs four nodes over the step still stands
--     on masonry and not on air;
--   * a CLEAR VOLUME: the plot's own airspace up to its roof, so the uphill
--     corner of the same step does not push a shoulder of terrace through the
--     building's wall.
--
-- Only the perimeter is skirted and only the airspace is cleared, because a
-- solid block of both would cost a plot four thousand cells of buried stone and
-- put it over the contract's 12,000-cell budget on its own.
--
-- A PLOT NEED NOT BE A BUILDING. A roster row that carries `yard` instead of
-- `module`/`make` builds the same thing without a part in the middle of it:
-- the same ground course, the same skirt, the same cleared airspace, the same
-- sockets, and whatever its own `decorate` plants on it. That is what a field,
-- a corral, a pit, a midden or a rock court is, and it is the same builder
-- because the reason a plot exists is the terrace under it, which does not care
-- whether a hall or a furrow stands on top.
--
-- THE +-13 IS NOT THE CONTRACT'S +-15, AND THAT IS DELIBERATE: every plot
-- stands on a LOT of `gor_drazhak_quadrants.lua`, and a lot is held to one
-- envelope on every seed so that any district may stand in any quadrant. Two
-- nodes of the contract's volume are the margin that buys.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local services = dofile(directory .. "/capital_services.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local capitals = dofile(directory .. "/capitals.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)

	local M = {}

	M.REACH = 13
	M.FLOOR = -6
	-- The LEAST airspace a plot clears, whatever its own roof needs, and the
	-- number the whole lot rule is written against: a lot may rise
	-- `MIN_CLEAR - 2` nodes under a plot (`tools/wp13/gor_drazhak_lots.lua`
	-- reads this constant rather than repeating it), so a part whose deck is
	-- four courses up still stands clear of the shoulder the mesa puts in its
	-- doorway.
	--
	-- NINE AND NOT EIGHT, which is the nine-seed sweep's doing. Eight is
	-- Highcourt's, and it makes the lot rule "rise at most 6"; on three worlds
	-- that placed all 52 lots, and on nine it left one lot of the south-west
	-- quarter -- boxed in by the gate corridor, the ring street and its own
	-- neighbours -- with no legal position within eighty nodes, for a rise of
	-- SEVEN. One more course of authored air is 14 630 cells of the capital's
	-- 400 000 budget and it buys that lot its own ground back, which is a
	-- better trade than moving a house eighty-four nodes out of its district.
	M.MIN_CLEAR = 9

	-- THE SECOND PALETTE HANDLE. Adobe is the orc signature and is already the
	-- `wall` binding, so a capital building made grander by a richer wall
	-- material is not available the way Highcourt's marble crown is. What IS
	-- available, and is the contract's own word, is the ORS-STONE BASE COURSE:
	-- `grug_decor:darkage_ors_block`, the banded red sandstone this palette
	-- already infills its adobe walls with. A civic building built with it
	-- throughout is stone where a dwelling is mud brick, which is the same
	-- distinction Highcourt draws with marble and reads at the same distance.
	M.ORS = {
		wall = "grug_decor:darkage_ors_block",
		wall_infill = "grug_decor:darkage_adobe",
	}

	-- The plot's own ground area: the part's extent grown by two nodes on every
	-- side and then clamped into the envelope, so the kerb, the doorstep path
	-- and the lamps stand on the plot and not beside it.
	local function ground_area(part, ox, oz, turns, margin, reach)
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
		reach = reach or M.REACH
		local function clamp(value)
			if value < -reach then return -reach end
			if value > reach then return reach end
			return value
		end
		margin = margin or 2
		return clamp(x0 - margin), clamp(z0 - margin), clamp(x1 + margin),
			clamp(z1 + margin)
	end

	----------------------------------------------------------------------
	-- socket shapes a roster row may publish, spelled once so four rosters
	-- spell them the same way
	----------------------------------------------------------------------

	-- A GUARD POST is the sockets contract's "a guard stands here and returns
	-- here after fights".
	function M.guard_post(id, x, z, face)
		return {id = "post_" .. id, role = "guard_post", x = x, z = z,
			face = face or 0}
	end

	-- A SPARE is an idle position a walking NPC may use as a DESTINATION and
	-- which the placement engine does not staff with an inhabitant of its own.
	-- `spawn = false` is the whole of it. NO TAG, deliberately: a tag is what an
	-- idle NPC's spoken line reads off, and nobody stands here to say anything.
	function M.spare(id, x, z, face, y)
		return {id = "spare_" .. id, role = "idle", x = x, y = y or 1, z = z,
			face = face or 0, spawn = false}
	end

	-- A WORK SOCKET is the sockets contract's section 8.1: a resident's
	-- workplace, always staffed, always static, naming the ACTIVITY it does and
	-- facing the feature that activity works within three nodes. `y` is the feet
	-- course and defaults to 1; a work socket ON a bench passes 2, because a
	-- seat is walkable and the resident stands on top of it.
	function M.work(id, activity, x, z, face, tags, y)
		return {id = "work_" .. id, role = "work", activity = activity,
			x = x, y = y or 1, z = z, face = face or 0, tags = tags}
	end

	-- A PROFESSION VENDOR is section 8.4. The capital holds at most one of each
	-- kind, which the KAT's family rule asserts across every composition.
	function M.vendor(id, kind, x, z, face)
		return {id = "vendor_" .. id, role = "vendor", kind = kind,
			x = x, z = z, face = face or 0}
	end

	-- An IDLE spot with a tag, for a roster row that wants one somewhere its
	-- part does not publish.
	-- `y` is the feet course and defaults to 1, exactly as `work`'s does: an
	-- idle spot ON a bench passes 2, because a seat is a walkable node and the
	-- resident stands on top of it.
	function M.idle(id, x, z, face, tags, y)
		return {id = "idle_" .. id, role = "idle", x = x, y = y or 1, z = z,
			face = face or 0, tags = tags}
	end

	----------------------------------------------------------------------
	-- the flat deck's parapet
	----------------------------------------------------------------------

	-- THE BREASTWORK. A flat roof reads as a shed lid until something stands
	-- proud of it; the contract's orc line says "adobe flat roofs WITH
	-- PARAPETS", and this is that ring.
	--
	-- It is written column by column over the finished part and only where the
	-- course below it is an opaque full node, which is what keeps a ring from
	-- floating over the eave a rasteriser did not lay: a deck field covers the
	-- block grown by its overhang, but a part built from several blocks has
	-- corners where it does not, and the first version of this helper drew four
	-- straight sides through them. The count is published so the KAT can hold a
	-- plot to a ring it actually got.
	local function breastwork(buf, palette, x0, z0, x1, z1, y)
		local low = palette.node("low_wall")
		local merlon = palette.maybe("signature") or palette.node("wall_accent")
		local placed = 0
		for z = z0, z1 do
			for x = x0, x1 do
				if x == x0 or x == x1 or z == z0 or z == z1 then
					if parts.solid_at(buf, x, y - 1, z) then
						buf:put(x, y, z, low)
						if (x + z) % 2 == 0 then
							buf:put(x, y + 1, z, merlon)
						end
						placed = placed + 1
					end
				end
			end
		end
		return placed
	end

	-- A YARD: the open-ground plot. Its own half-extent, which is the fill
	-- lot's reach or less, and a peak of zero, because nothing of the
	-- composition's own stands above the ground course until `decorate` puts it
	-- there.
	local function yard_area(plot)
		local yard = plot.yard
		local half_x = yard.w or yard.reach
		local half_z = yard.d or yard.reach
		if type(half_x) ~= "number" or type(half_z) ~= "number" or
				half_x < 3 or half_z < 3 then
			error("wp13 gor drazhak plot: the yard " .. tostring(plot.id) ..
				" has no extent", 0)
		end
		if half_x > yard.reach or half_z > yard.reach then
			error("wp13 gor drazhak plot: the yard " .. tostring(plot.id) ..
				" is wider than its own lot", 0)
		end
		return -half_x, -half_z, half_x, half_z
	end

	-- Build one plot from its roster row.
	--
	-- The row: `id`, `module` ("capitals" or "buildings"), `make` (the
	-- generator), `spec` (its arguments), and optionally `turns`, `margin`,
	-- `handle` ("ors"), `parapet` (a flat deck's breastwork), `order` (its
	-- waypoint in the district loop), `decorate`, `socket_overrides` and
	-- `extra_sockets`.
	function M.build(plot, context)
		context = context or {}
		local watch = plot.patrol_group or context.patrol_group
		local local_generators = context.generators
		local base = palettes.new("orc")
		local palette = base
		if plot.handle == "ors" then
			palette = palettes.new("orc", M.ORS)
		end
		local spec = {}
		for key, value in pairs(plot.spec or {}) do spec[key] = value end
		spec.id = plot.id
		if services.service("gor_drazhak", plot.id) == "riding" then
			spec.w, spec.d, spec.open_shelter = 21, 17, true
		end
		local part, turns, rw, rd, ox, oz
		local x0, z0, x1, z1
		if plot.yard then
			turns, rw, rd, ox, oz = 0, 1, 1, 0, 0
			x0, z0, x1, z1 = yard_area(plot)
		else
			-- Three generator tables, not two. `capitals` and `buildings` are
			-- the shared library; the third is the district roster's OWN, which
			-- is how a plan that exists in one quarter of one capital -- the
			-- warrens' round lodge -- is built without editing `buildings.lua`,
			-- a file this lane does not own.
			local module = local_generators
			if plot.module == "capitals" then
				module = capitals
			elseif plot.module == "buildings" then
				module = buildings
			end
			local generator = module and module[plot.make]
			if type(generator) ~= "function" then
				error("wp13 gor drazhak plot: no generator " ..
					tostring(plot.make) .. " in " .. tostring(plot.module), 0)
			end
			part = generator(palette, spec)
			-- The part is centred on the plot origin, which is also the
			-- reference column: the terrain height under the middle of the plot
			-- is the height the whole plot is levelled to. A quarter turn swaps
			-- the footprint, so the centring reads the ROTATED width.
			turns = (plot.turns or 0) % 4
			rw = (turns % 2 == 1) and part.d or part.w
			rd = (turns % 2 == 1) and part.w or part.d
			ox = -math.floor((rw - 1) / 2)
			oz = -math.floor((rd - 1) / 2)
			x0, z0, x1, z1 = ground_area(part, ox, oz, turns, plot.margin,
				plot.reach)
		end
		local peak = part and part.peak or 0

		local buf = parts.buffer()
		-- 1. The plot's ground and its airspace. The clear goes down to the
		-- ground course as well, because the terrace shoulder this plot cuts
		-- through occupies those cells in the world.
		buf:fill(x0, -1, z0, x1, -1, z1, palette.node("subsoil"))
		buf:fill(x0, 0, z0, x1, 0, z1, palette.node("ground"))
		local clear_to = peak + 2
		if clear_to < M.MIN_CLEAR then clear_to = M.MIN_CLEAR end
		buf:clear(x0, 1, z0, x1, clear_to, z1)
		-- 2. The foundation skirt, the perimeter only, down to the contract's
		-- floor.
		for y = -1, M.FLOOR, -1 do
			for z = z0, z1 do
				for x = x0, x1 do
					if x == x0 or x == x1 or z == z0 or z == z1 then
						buf:put(x, y, z, palette.node("foundation"))
					end
				end
			end
		end
		local points = {sockets = {}, doors = {}, room_corner = {}, inside = {}}
		local parapet_columns = 0
		if plot.yard then
			-- A yard's own gate: three columns of path at the street edge, so
			-- the ground is entered from the lane rather than walked into over
			-- its own kerb, and the two lamps every plot carries.
			for z = z0, z0 + 1 do
				for x = -1, 1 do
					buf:put(x, 0, z, palette.node("path"))
				end
			end
			dressing.path_light(buf, palette, x0 + 1, z0 + 1)
			dressing.path_light(buf, palette, x1 - 1, z0 + 1)
		else
			-- 3. The kerb of the plot, and the doorstep path from the part's
			-- own apron out to the street edge of the plot.
			dressing.inlay(buf, palette, x0, z0, x1, z1)
			for z = z0 + 1, oz - 1 do
				for x = -1, 1 do
					buf:put(x, 0, z, palette.node("path"))
				end
			end

			-- 4. The part itself.
			points = parts.stamp(buf, part, ox, 0, oz, turns)

			-- 4b. The breastwork over a flat deck.
			if plot.parapet then
				local grow = plot.parapet.grow or 1
				parapet_columns = breastwork(buf, palette, ox - grow,
					oz - grow, ox + rw - 1 + grow, oz + rd - 1 + grow,
					plot.parapet.y)
				if parapet_columns < (plot.parapet.least or 16) then
					error("wp13 gor drazhak plot: the breastwork of " ..
						tostring(plot.id) .. " found only " ..
						parapet_columns .. " columns of deck", 0)
				end
			end

			-- 5. Two lamps on the street corners of the plot, and a bench
			-- beside the door.
			for _, lamp in ipairs({{x0 + 1, z0 + 1}, {x1 - 1, z0 + 1}}) do
				dressing.path_light(buf, palette, lamp[1], lamp[2])
			end
			dressing.bench(buf, palette, 3, z0 + 2, 0, 3, "x")
		end

		-- 6. Whatever this plot alone wants on its own ground. It is handed the
		-- buffer, the palette and the plot's own ground rectangle, and it runs
		-- BEFORE the sockets are collected so a piece of dressing can stand
		-- where a socket would otherwise be published into a wall.
		local area = {x0 = x0, z0 = z0, x1 = x1, z1 = z1, ox = ox, oz = oz,
			pw = rw, pd = rd, peak = peak, clear_to = clear_to,
			dressing = dressing, parts = parts, palettes = palettes}
		if type(plot.decorate) == "function" then
			plot.decorate(buf, palette, area)
		end

		-- 7. Sockets: the part's own, plus this plot's waypoint in the district
		-- loop where the part publishes none of its own.
		local sockets = {}
		local overrides = {}
		if type(plot.socket_overrides) == "function" then
			overrides = plot.socket_overrides(area)
		end
		for _, entry in ipairs(points.sockets or {}) do
			-- `spawn` travels with the socket: a generator that publishes a
			-- spare must not lose it here.
			local override = overrides[entry.id] or {}
			sockets[#sockets + 1] = {id = entry.id, role = entry.role,
				x = override.x or entry.x, y = override.y or entry.y,
				z = override.z or entry.z,
				face = override.face or entry.face,
				group = entry.group, order = entry.order, kind = entry.kind,
				activity = entry.activity,
				spawn = entry.spawn, tags = override.tags or entry.tags}
		end
		if plot.order then
			sockets[#sockets + 1] = {id = plot.id .. "_watch",
				role = "guard_patrol", x = 0, y = 1, z = z0 + 2, face = 0,
				group = watch, order = plot.order}
		end
		-- Every plot publishes one flair spot at its own gate, on the doorstep
		-- path: the plots built from `buildings.lua` publish no socket of their
		-- own, and a district of nine plots with four inhabited ones is not a
		-- district anybody lives in.
		--
		-- A FILL PLOT'S IS A SPARE, not a resident. A field, a spoil heap or a
		-- wood yard has a way in but no doorstep, and standing somebody at the
		-- gate of a paddock for the life of the world is a resident spent on
		-- nothing. `spawn = false` keeps the position -- it is still somewhere
		-- a walker may go -- and takes the person off it, which is sixteen of
		-- the forty-seven this capital shed to reach the coordinator's
		-- 150..170 resident band (2026-09-15).
		if plot.fill then
			sockets[#sockets + 1] = {id = plot.id .. "_gate_spare",
				role = "idle", x = 0, y = 1, z = z0 + 2, face = 0,
				spawn = false}
		else
			sockets[#sockets + 1] = {id = plot.id .. "_gate_idle",
				role = "idle", x = 0, y = 1, z = z0 + 2, face = 0,
				tags = {"door"}}
		end
		if type(plot.extra_sockets) == "function" then
			for _, entry in ipairs(plot.extra_sockets(area)) do
				sockets[#sockets + 1] = {id = plot.id .. "_" .. entry.id,
					role = entry.role, x = entry.x, y = entry.y or 1,
					z = entry.z, face = entry.face or 0, tags = entry.tags,
					kind = entry.kind, activity = entry.activity,
					spawn = entry.spawn, group = entry.group,
					order = entry.order}
			end
		end
		for _, entry in ipairs(sockets) do
			local dx, dz = parts.facedir_step(entry.face)
			entry.dir = {x = dx, z = dz}
		end

		if spec.open_shelter then
			-- Generic shopfront lamps/benches must not become extra shelter
			-- posts or intrude into the open stable's public approach.
			buf:clear(x0, 1, z0, x1, clear_to, z1)
			parts.stamp(buf, part, ox, 0, oz, turns)
		end
		services.decorate("gor_drazhak", plot.id, buf, palette, sockets, area)
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
			-- compares `blueprint.schema` with the profile's own, so fifty-two
			-- plots behind one string would need fifty-two profiles that all
			-- claim to be the same blueprint.
			schema = "grug_wp13_gor_drazhak_plot_" .. plot.id .. "_v1",
			id = plot.id,
			cells = cells,
			bounds = {min = minp, max = maxp},
			palette = palette_list,
			-- The column whose final terrain height becomes this plot's y = 0.
			-- It is the plot origin, that is the middle of the building: a plot
			-- levels to the ground under its own centre, never to a corner, or
			-- half of every plot on a slope would stand a terrace step too high.
			reference = {x = 0, z = 0},
			-- The airspace this plot actually cleared. `bounds.max.y` is not
			-- that number: a lamp post or a standard written after the clear
			-- reaches above it, so a legality predicate reading the bounds
			-- would credit the plot with headroom it never cut.
			clear_to = clear_to,
			landmarks = {
				arrival = {x = 0, y = 1, z = z0 + 2},
				plot = {min = {x = x0, y = -1, z = z0},
					max = {x = x1, y = peak, z = z1}},
				entry = {x = 0, y = 1, z = z0 + 1},
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = sockets,
				parapet_columns = parapet_columns,
			},
		}
	end

	-- A district: its key, its role, its patrol loop and the ordered plot list,
	-- each entry carrying a builder that returns the composition. The OFFSET is
	-- not here -- a district does not know which quadrant it stands in until the
	-- world seed says so (`gor_drazhak_quadrants.lua`).
	function M.district(definition)
		local district = {
			key = definition.key,
			role = definition.role,
			patrol_group = definition.patrol_group,
			plots = {},
			fill = {},
		}
		local function entries(list, into, yard_reaches)
			for index, plot in ipairs(list or {}) do
				-- A fill row is handed the reach of the fill lot it will stand
				-- on, so a roster says WHAT a dressing is and the quadrants
				-- module stays the only place that says how big its lot is.
				-- A DISTRICT row stands on a district lot and takes that lot's
				-- one reach; a FILL row is handed the reach of the fill lot it
				-- will stand on, so a roster says WHAT a dressing is and the
				-- quadrants module stays the only place that says how big its
				-- lot is. Either way the row is TOLD its reach rather than
				-- left to guess, because a yard's extent is checked against it
				-- and a nil reach there is a comparison against nothing.
				local reach = yard_reaches and yard_reaches[index] or M.REACH
				plot.reach = reach
				plot.fill = (yard_reaches ~= nil)
				if plot.yard then plot.yard.reach = reach end
				into[index] = {
					id = plot.id,
					build = function()
						return M.build(plot,
							{patrol_group = definition.patrol_group,
								generators = definition.generators})
					end,
				}
			end
		end
		entries(definition.plots, district.plots)
		entries(definition.fill, district.fill, definition.fill_reaches)
		return district
	end

	return M
end

return loader
