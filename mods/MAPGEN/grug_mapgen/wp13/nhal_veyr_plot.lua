-- One Nhal Veyr district plot, built from a roster row.
--
-- This is `highcourt_plot.lua`'s builder in the undead palette. The pilot
-- capital's own file is frozen against its four shipped districts and its
-- 52 blueprint identities, and it binds `palettes.new("human")` in three
-- places; a shared builder would therefore have had to grow a race argument
-- and move every Highcourt cell that argument touched. So this file is the
-- same rule written for one other race, which is what the lane brief's
-- "extend the library through NEW files" means here, and the two are held
-- to the same KAT rules rather than to each other.
--
-- WHAT A PLOT IS. A district plot cannot be anchor-relative. The core is flat
-- at the fitted reference height, but WP40 terraces the rest of the 512
-- envelope -- step 3 for the undead raised necropolis -- so two plots sixty
-- nodes apart stand at two different heights. The capitals contract section
-- 2.1 settles that with a REFERENCE COLUMN: each plot is authored around its
-- own origin with y = 0 the ground course, and at settle time the settlement
-- config asks the pure final height of one named column once, caches it, and
-- projects the plot's cells from there. What makes that survive a terrace
-- edge under the plot is the other half of the same rule, and both are built
-- here:
--
--   * a FOUNDATION SKIRT: the perimeter of the plot carried down to y = -6,
--     so a plot whose downhill corner hangs three nodes over the step still
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
-- A PLOT NEED NOT BE A BUILDING. A roster row that carries `yard` instead of
-- `module`/`make` builds the same thing without a part in the middle of it:
-- the same ground course, the same foundation skirt, the same cleared
-- airspace, the same sockets -- and whatever its own `decorate` plants on it.
-- That is what a graveyard field, a bone yard, a ruin close or a candle court
-- is, and it is the same builder because the reason a plot exists is the
-- terrace under it, which does not care whether a tomb or a grave row stands
-- on top.
--
-- THE +-13 IS NOT THE CONTRACT'S +-15, AND THAT IS DELIBERATE. Every plot of
-- every district stands on a LOT of `nhal_veyr_quadrants.lua`, and a lot is
-- held to one envelope on both gate seeds so that any district may stand in
-- any quadrant. Two nodes of the contract's volume are the margin that buys.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local services = dofile(directory .. "/capital_services.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local capitals = dofile(directory .. "/capitals.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	-- This capital's own two parts, addressed by a roster row as
	-- `module = "undead"` beside the library's "capitals" and "buildings".
	local undead = dofile(directory .. "/undead_parts.lua")(directory)

	local M = {}

	-- The plot envelope this builder holds itself to. `REACH` is the ground
	-- the plot may lay; `FLOOR` is how far the skirt reaches down, and it is
	-- the contract's own -6.
	M.REACH = 13
	M.FLOOR = -6
	-- The LEAST airspace a plot clears, whatever its own roof needs. A lot is
	-- allowed to rise 6 nodes under a plot (`nhal_veyr_quadrants.lua`), and a
	-- part whose ridge is four courses up would have cleared 6 and stood with
	-- a shoulder of terrace in its doorway. Every plot the market district
	-- authored already clears 9 or more, so this floor is the low ones' --
	-- the well court, the wain shed -- and changes no cell of theirs.
	M.MIN_CLEAR = 8

	-- The two handles of this capital, exactly as `nhal_veyr.lua` binds them
	-- for the core, so a district building and a civic one are dressed the same
	-- way wherever they stand.
	--
	-- CRYPT is the masonry handle: the contract's section 2.4 line for Nhal
	-- Veyr is "dungeon stone and obsidian brick, mausoleum core", and the
	-- Stillgrave palette this capital is built on is a TIMBER palette -- its
	-- `wall` is gravewood board, because a hamlet of the Hollow is boards on an
	-- obsidian footing. A crypt, an ossuary and a mausoleum are not boards, so
	-- the handle rebinds the four fabric roles to the castle kit's dungeon
	-- stone over obsidian brick and lays their floors in castle pavement.
	-- Rebinding a handle rather than writing a second generator is the same
	-- move Highcourt's white stone is.
	--
	-- `post` and `beam` are NOT rebound, and that is the one line in this table
	-- worth arguing about. A masonry column would be the obvious fifth role and
	-- the castle kit ships one -- but `pillar` is a three-piece NODEBOX family,
	-- and `post` is what `dressing.path_light` stacks a lamp standard out of
	-- and what `parts.floor_torch` demands an opaque full cube of. Rebinding it
	-- turns every lamp on a crypt plot into a torch standing on a pillar it
	-- cannot stand on, which is a construction-time error and was one. A tomb's
	-- own candle standards are written in masonry at their own call site
	-- (`undead_parts.mausoleum`), where the cube is known.
	M.CRYPT = {
		wall = "grug_decor:castle_dungeon_stone",
		wall_accent = "default:obsidianbrick",
		floor = "grug_decor:castle_pavement_brick",
		ceiling = "grug_decor:castle_dungeon_stone",
	}
	-- And the roof to go over it: DRESSED STONE BRICK, a mid grey.
	--
	-- Pale and not black, and that is a render's verdict rather than a taste.
	-- The first version roofed a crypt in the same dungeon stone its walls are
	-- built of and the mausoleum came out of the engine as one unbroken black
	-- mass with a lantern on top -- the "big cottage" defect Highcourt's slate
	-- fixed, in reverse. A grey lid over black walls is what makes a tomb read
	-- as a tomb from the end of an avenue.
	--
	-- `stairs:` and not the castle kit's own shapes, and this is the second
	-- thing the attempt taught: `grug_decor.register_shapes` gives its stairs
	-- NO paramtype2, so `parts.put` refuses them outright -- a roof stair has
	-- to carry a facedir or the rasteriser cannot turn it. The `stairs` mod's
	-- families do, which is why every roof in this library comes from one.
	M.VAULT = {
		roof_stair = "stairs:stair_stonebrick",
		roof_stair_outer = "stairs:stair_outer_stonebrick",
		roof_stair_inner = "stairs:stair_inner_stonebrick",
		roof_slab = "stairs:slab_stonebrick",
		roof_ridge = "default:stonebrick",
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
		-- A plot on a FILL lot is clamped to that lot's own reach and not to
		-- the district lot's 13: the fill lots are four deliberately different
		-- sizes and a building that overran one would be a building the lot
		-- predicate never measured.
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

	-- A WORK SOCKET is the sockets contract's section 8.1: a resident's
	-- workplace, always staffed, always static, naming the ACTIVITY it does and
	-- facing the feature that activity works within three nodes. The closed
	-- vocabulary is the registry's (`grug_core/settlement_sockets.lua`) and the
	-- KAT measures the feature; this is only the shape, spelled once so five
	-- rosters spell it the same way.
	-- `y` is the feet course and defaults to 1, the first walkable course over
	-- the plot's ground. A work socket ON a bench passes 2, because a seat is
	-- a walkable node and the resident stands (sits) on top of it.
	function M.work(id, activity, x, z, face, tags, y)
		return {id = "work_" .. id, role = "work", activity = activity,
			x = x, y = y or 1, z = z, face = face or 0, tags = tags}
	end

	-- A PROFESSION VENDOR is section 8.4: a trader with a stock table of its
	-- own profession, standing at the counter of the building that sells it.
	-- The capital holds at most one of each kind, which the KAT's family rule
	-- asserts across every composition at once.
	function M.vendor(id, kind, x, z, face)
		return {id = "vendor_" .. id, role = "vendor", kind = kind,
			x = x, z = z, face = face or 0}
	end

	-- Build one plot from its roster row.
	--
	-- The row: `id`, `module` ("capitals" or "buildings"), `make` (the
	-- generator), `spec` (its arguments), and optionally `turns` (quarter
	-- turns of the part on its own plot), `margin` (extra ground all round),
	-- `handle` ("undead" or "crypt"), `roof` ("vault"), `garden`, `order` (its
	-- waypoint in the district loop), `decorate` and `extra_sockets`.
	-- A YARD: the open-ground plot of playtest round 3. It is the roster row's
	-- own half-extent, which is the fill lot's reach or less, and a peak of
	-- zero, because nothing of the composition's own stands above the ground
	-- course until `decorate` puts it there.
	local function yard_area(plot)
		local yard = plot.yard
		local half_x = yard.w or yard.reach
		local half_z = yard.d or yard.reach
		if type(half_x) ~= "number" or type(half_z) ~= "number" or
				half_x < 3 or half_z < 3 then
			error("wp13 nhal veyr plot: the yard " .. tostring(plot.id) ..
				" has no extent", 0)
		end
		if half_x > yard.reach or half_z > yard.reach then
			error("wp13 nhal veyr plot: the yard " .. tostring(plot.id) ..
				" is wider than its own lot", 0)
		end
		return -half_x, -half_z, half_x, half_z
	end

	function M.build(plot, context)
		context = context or {}
		local watch = plot.patrol_group or context.patrol_group
		local base = palettes.new("undead")
		local palette = base
		if plot.handle == "crypt" then
			palette = palettes.new("undead", M.CRYPT)
		end
		local roof_palette
		if plot.roof == "vault" then
			if plot.handle == "crypt" then
				roof_palette = palettes.new("undead", merged(M.CRYPT, M.VAULT))
			else
				roof_palette = palettes.new("undead", M.VAULT)
			end
		end
		local spec = {}
		for key, value in pairs(plot.spec or {}) do spec[key] = value end
		spec.id = plot.id
		if services.service("nhal_veyr", plot.id) == "riding" then
			spec.w, spec.d, spec.open_shelter = 21, 17, true
		end
		if roof_palette then spec.roof_palette = roof_palette end
		local part, turns, rw, rd, ox, oz
		local x0, z0, x1, z1
		if plot.yard then
			turns, rw, rd, ox, oz = 0, 1, 1, 0, 0
			x0, z0, x1, z1 = yard_area(plot)
		else
			local module = buildings
			if plot.module == "capitals" then module = capitals end
			if plot.module == "undead" then module = undead end
			local generator = module[plot.make]
			if type(generator) ~= "function" then
				error("wp13 nhal veyr district: no generator " ..
					tostring(plot.make), 0)
			end
			part = generator(palette, spec)
			-- The part is centred on the plot origin, which is also the
			-- reference column: the terrain height under the middle of the
			-- plot is the height the whole plot is levelled to. A quarter turn
			-- swaps the footprint, so the centring reads the ROTATED width.
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
		local points = {sockets = {}, doors = {}, room_corner = {}, inside = {}}
		if plot.yard then
			-- A yard's own gate: three columns of path at the street edge, so
			-- the field is entered from the lane rather than walked into over
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

			-- 5. Two lamps on the street corners of the plot, and a bench
			-- beside the door.
			local lamps = {{x0 + 1, z0 + 1}, {x1 - 1, z0 + 1}}
			for _, lamp in ipairs(lamps) do
				dressing.path_light(buf, palette, lamp[1], lamp[2])
			end
			dressing.bench(buf, palette, 3, z0 + 2, 0, 3, "x")
		end

		-- 5b. A garden plot plants the ring its wider ground bought: a
		-- GRAVEWOOD at each corner, a planter and a bench between them, and
		-- the carrier's crates by the gate. Everything stands on the plot's
		-- own turf, outside the part's paving, which is why only a plot with a
		-- margin may ask for it.
		--
		-- A gravewood and not the `broadleaf` Highcourt's gardens plant: the
		-- broadleaf silhouette is a rounded canopy and this palette's tree is
		-- the bent, mostly bare dead tree of the blight, whose own dressing
		-- draws the three arms and the four leaf remnants that make it read as
		-- one. Planting a broadleaf out of gravewood log and gravewood leaves
		-- would be a dense black ball where the composition wants a skeleton.
		if plot.garden then
			for _, spot in ipairs({{x0 + 2, z0 + 2}, {x1 - 2, z0 + 2},
					{x0 + 2, z1 - 2}, {x1 - 2, z1 - 2}}) do
				dressing.gravewood(buf, palette, spot[1], spot[2], 5)
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
		-- The four generator modules travel in the area table beside the
		-- dressing, because a yard's own `decorate` may want to STAMP a part on
		-- open ground -- the vigil district's ruin close puts two of
		-- `buildings.ruin`'s half-standing shells on one lot -- and a roster
		-- reaching for `dofile` of its own would load the library twice.
		local area = {x0 = x0, z0 = z0, x1 = x1, z1 = z1, ox = ox, oz = oz,
			pw = rw, pd = rd, peak = peak, clear_to = clear_to,
			dressing = dressing, parts = parts, palettes = palettes,
			buildings = buildings, capitals = capitals, undead = undead}
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
			-- copy would have (`nhal_veyr.lua` carries the same field in the
			-- core's own copy for the same reason).
			--
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
					kind = entry.kind, activity = entry.activity,
					spawn = entry.spawn}
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
		services.decorate("nhal_veyr", plot.id, buf, palette, sockets, area)
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
			schema = "grug_wp13_nhal_veyr_plot_" .. plot.id .. "_v1",
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
			-- is what `tools/wp13/nhal_veyr_plots.lua` holds the lot's rise
			-- against.
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
			},
		}
	end

	-- A district: its key, its role, its patrol loop and the ordered plot
	-- list, each entry carrying a builder that returns the composition. The
	-- OFFSET is not here -- a district does not know which quadrant it stands
	-- in until the world seed says so (`nhal_veyr_quadrants.lua`).
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
				if yard_reaches then
					local reach = yard_reaches[index]
					plot.reach = reach
					if plot.yard then plot.yard.reach = reach end
				end
				into[index] = {
					id = plot.id,
					build = function()
						return M.build(plot,
							{patrol_group = definition.patrol_group})
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
