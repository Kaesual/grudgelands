-- The capital plot engine: one district plot of any of the six capitals,
-- built from a roster row (Round 82, audit W2-01).
--
-- Until Round 82 each capital carried its own copy of this builder
-- (`<capital>_plot.lua`), written once for Highcourt and then again in each
-- race's palette; the copies drifted in a handful of places. Each
-- `<capital>_plot.lua` is now that capital's short configuration of this
-- engine (`SPEC` below), and every place the copies differed is a named
-- option there, reproducing that capital's plots cell for cell.
--
-- WHAT A PLOT IS. A district plot cannot be anchor-relative. The core is flat
-- at the fitted reference height, but WP40 terraces the rest of the capital
-- envelope (step 2 for the human plateau, up to 4 for the dwarf and orc
-- terraces), so two plots sixty nodes apart stand at two different heights.
-- The capitals contract section 2.1 settles that with a REFERENCE COLUMN:
-- each plot is authored around its own origin with y = 0 the ground course,
-- and at settle time the settlement config asks the pure final height of one
-- named column once, caches it, and projects the plot's cells from there.
-- What makes that survive a terrace edge under the plot is the other half of
-- the same rule, and both are built here:
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
-- canonical cells, bounds (x/z inside the plot's reach, y [-6, 24]), sorted
-- palette and landmarks, plus `reference` and the `sockets` of the NPC
-- contract.
--
-- A PLOT NEED NOT BE A BUILDING (playtest round 3). A roster row that carries
-- `yard` instead of `template` builds the same thing without a part in the
-- middle of it: the same ground course, the same foundation skirt, the same
-- cleared airspace, the same sockets -- and whatever its own `decorate`
-- plants on it. That is what a field, an orchard, a paddock, a graveyard or a
-- pond is, and it is the same builder because the reason a plot exists is the
-- terrace under it, which does not care whether a house or a furrow stands on
-- top. A yard's ground is authored as a half-extent rather than grown from a
-- part's footprint, because there is no footprint to grow from.
--
-- THE REACH (13, Lethariel 11) IS NOT THE CONTRACT'S +-15, AND THAT IS
-- DELIBERATE. Every plot of every district stood on a LOT of the pre-Round-22
-- lot tables, and a lot was held to one envelope on every gate seed so that
-- any district may stand in any quadrant. Two nodes of the contract's volume
-- are the margin that buys.
--
-- THE SPEC (`<capital>_plot.lua`):
--
--   * `key`, the capital (its roster, its services, its schema prefix), and
--     `label`, its name in errors;
--   * `reach` (default 13), the ground a plot may lay, and `min_clear`
--     (default 8), the least airspace a plot clears;
--   * `main(plot)`, the roster palette a plot is built in, and
--     `roof(plot, main)`, the palette its roof channel takes (nil: none);
--   * `lamp` (default `{kind = "path_light", inset = 1, row = 1}`), the two
--     lamps of a building plot at `x0 + inset`, `x1 - inset`, `z0 + row`,
--     and `yard_lamp_inset` (default 1), the path lights of a yard's gate;
--   * `garden` (`{tree, size, spots}`), what a roster row's `garden = true`
--     plants; `spots` "front" puts the four trees on the plot's corners,
--     "back" on its back corners and beside the building. Without it a
--     garden row is an error, unless `garden_ignored` (W2-02 below);
--   * `lights`, the optional light roles a plot's lights list also counts;
--   * `area`, extra modules handed to `decorate` in its `area` table
--     (`{name = "<file without .lua>"}`);
--   * `parapet_columns`, the plot's landmarks carry the template's
--     `parapet_columns` (0 for a yard);
--   * the drift of the copies, kept as each capital built it (audit W2-02,
--     W2-05, W2-06; a later decision):
--       `garden_ignored` -- a row's `garden = true` plants nothing;
--       `clear_to_top`   -- the clear also reaches the template's `top`, not
--                           only `peak + 2`;
--       `extra_group_order` -- an `extra_sockets` entry keeps its `group`
--                           and `order`;
--     and Gor Drazhak's `fill_gate_spare`: a fill plot's gate spot is a spare
--     (`spawn = false`) rather than a resident.
--
-- `dofile(directory .. "/capital_plot.lua")(directory, spec, context)`
-- (`context`: the build's optional loader context, `templates.lua`) returns the
-- plot module: `M.build`, `M.district`, the socket shapes `M.guard_post`,
-- `M.spare`, `M.idle`, `M.work`, `M.vendor`, the shopfront `M.shop_counter`
-- and `M.shop_vendor`, and `M.REACH`, `M.FLOOR`, `M.MIN_CLEAR`,
-- `M.FILL_REACHES`.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory, spec, context)
	local parts = dofile(directory .. "/parts.lua")
	local services = dofile(directory .. "/capital_services.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local dressing = dofile(directory .. "/dressing.lua")(directory, context)
	local layout = dofile(directory .. "/layout.lua")(directory, context)
	local templates = dofile(directory .. "/templates.lua")(directory, context)
	local composition = dofile(directory .. "/composition.lua")(parts, layout, templates)
	local KEY, LABEL = spec.key, spec.label
	local CAPITAL = templates.capital(KEY)
	local modules = {}
	for name, file in pairs(spec.area or {}) do
		modules[name] = dofile(directory .. "/" .. file .. ".lua")(directory, context)
	end
	local LAMP = spec.lamp or {kind = "path_light", inset = 1, row = 1}
	local YARD_LAMP = spec.yard_lamp_inset or 1

	local M = {}

	-- The plot envelope this builder holds itself to. `REACH` is the ground
	-- the plot may lay; `FLOOR` is how far the skirt reaches down, and it is
	-- the contract's own -6.
	M.REACH = spec.reach or 13
	M.FLOOR = -6
	-- The LEAST airspace a plot clears, whatever its own roof needs. A lot was
	-- allowed to rise 6 nodes under a plot (the pre-Round-22 lot tables), and
	-- a part whose ridge is four courses up would have cleared 6 and stood
	-- with a shoulder of terrace in its doorway. This floor is the low plots'
	-- -- the well court, the wain shed. Gor Drazhak's is 9 (a nine-seed
	-- decision of its own).
	M.MIN_CLEAR = spec.min_clear or 8
	-- The four fill lots of a district, in roster order: a fill row is handed
	-- the reach of the fill lot it stands on, so a roster says WHAT a dressing
	-- is and only its own `fill_reaches` (or this) says how big its lot is.
	M.FILL_REACHES = {11, 11, 8, 5}

	-- The plot's own ground area: the part's extent grown by the margin (two
	-- nodes unless the row says otherwise) on every side and then clamped
	-- into the lot's reach, so the doorstep path and the lamps stand on the
	-- plot and not beside it. The extent is the template's `extent` (the
	-- building's non-air cells as its generator built them, format doc §4.1),
	-- turned with the part.
	local function ground_area(part, ox, oz, turns, margin, reach)
		local e = part.extent
		local ax, az = parts.rotate_footprint(e[1], e[2], part.w, part.d, turns)
		local bx, bz = parts.rotate_footprint(e[3], e[4], part.w, part.d, turns)
		local x0, x1 = ox + math.min(ax, bx), ox + math.max(ax, bx)
		local z0, z1 = oz + math.min(az, bz), oz + math.max(az, bz)
		local function clamp(value)
			if value < -reach then return -reach end
			if value > reach then return reach end
			return value
		end
		margin = margin or 2
		return clamp(x0 - margin), clamp(z0 - margin), clamp(x1 + margin),
			clamp(z1 + margin)
	end

	-- The extra socket shapes a district roster may publish through
	-- `plot.extra_sockets`, spelled once so every district spells them the
	-- same way.
	--
	-- A GUARD POST is the sockets contract's "a guard stands here and returns
	-- here after fights"; the martial district is where they belong.
	function M.guard_post(id, x, z, face)
		return {id = "post_" .. id, role = "guard_post", x = x, z = z,
			face = face or 0}
	end

	-- A SPARE is an idle position a walking NPC may use as a DESTINATION and
	-- which the placement engine does not staff with an inhabitant of its own.
	-- `spawn = false` is the whole of it, and the registry of
	-- `grug_core/settlement_sockets.lua` accepts it on an `idle` socket and on
	-- nothing else. NO TAG, deliberately: a tag is what an idle NPC's spoken
	-- line reads off, and nobody stands here to say anything. `y` is the feet
	-- course (default 1).
	function M.spare(id, x, z, face, y)
		return {id = "spare_" .. id, role = "idle", x = x, y = y or 1, z = z,
			face = face or 0, spawn = false}
	end

	-- An IDLE spot a resident stands at, with the tags its spoken line reads.
	function M.idle(id, x, z, face, tags, y)
		return {id = "idle_" .. id, role = "idle", x = x, y = y or 1, z = z,
			face = face or 0, tags = tags}
	end

	-- A WORK SOCKET is the sockets contract's section 8.1: a resident's
	-- workplace, always staffed, always static, naming the ACTIVITY it does and
	-- facing the feature that activity works within three nodes. The closed
	-- vocabulary is the registry's (`grug_core/settlement_sockets.lua`).
	-- `y` is the feet course and defaults to 1, the first walkable course over
	-- the plot's ground. A work socket ON a bench passes 2, because a seat is
	-- a walkable node and the resident stands (sits) on top of it.
	function M.work(id, activity, x, z, face, tags, y)
		return {id = "work_" .. id, role = "work", activity = activity,
			x = x, y = y or 1, z = z, face = face or 0, tags = tags}
	end

	-- A PROFESSION VENDOR is section 8.4: a trader with a stock table of its
	-- own profession, standing at the counter of the building that sells it.
	function M.vendor(id, kind, x, z, face)
		return {id = "vendor_" .. id, role = "vendor", kind = kind,
			x = x, z = z, face = face or 0}
	end

	-- The shopfront a profession house carries: a four-node trestle counter on
	-- the street row of the plot's own ring, clear of the two lamps at the
	-- corners and of the doorstep path down the middle. The vendor stands
	-- OUTSIDE it on the plot's outermost row and looks at it, which is what a
	-- trader at a counter is and also what makes the socket's `dir` name the
	-- feature (section 8.1). `face` (default 0, the shop) turns a trader whose
	-- shop front has a post where the counter would be (Round 47, NPCs face
	-- away from walls).
	function M.shop_counter(buf, palette, area)
		area.dressing.counter(buf, palette, area.x1 - 5, area.z0 + 1, 4, "x")
	end
	function M.shop_vendor(id, kind, area, face)
		return M.vendor(id, kind, area.x1 - 4, area.z0, face or 0)
	end

	-- A YARD: the roster row's own half-extent, which is its lot's reach or
	-- less, and a peak of zero, because nothing of the composition's own
	-- stands above the ground course until `decorate` puts it there.
	local function yard_area(plot, reach)
		local yard = plot.yard
		local half_x = yard.w or reach
		local half_z = yard.d or reach
		if type(half_x) ~= "number" or type(half_z) ~= "number" or
				half_x < 3 or half_z < 3 then
			error("wp13 " .. LABEL .. " plot: the yard " .. tostring(plot.id) ..
				" has no extent", 0)
		end
		if half_x > reach or half_z > reach then
			error("wp13 " .. LABEL .. " plot: the yard " .. tostring(plot.id) ..
				" is wider than its own lot", 0)
		end
		return -half_x, -half_z, half_x, half_z
	end

	-- Build one plot from its roster row.
	--
	-- The row: `id`, `template` (its building template, Round 56) or `yard`,
	-- and optionally `turns` (quarter turns of the part on its own plot),
	-- `margin` (extra ground all round), `handle` and `roof` (the spec's
	-- `main` and `roof` read them), `garden`, `order` (its waypoint in the
	-- district loop), `gate_face`, `drop` (part socket roles it publishes
	-- none of), `decorate`, `socket_overrides` and `extra_sockets`.
	-- `context` is the district's: its `patrol_group`, the lot's `reach` and
	-- whether the row is a `fill` row.
	function M.build(plot, context)
		context = context or {}
		local watch = plot.patrol_group or context.patrol_group
		local reach = context.reach or M.REACH
		local main = spec.main(plot)
		local palette = CAPITAL.palettes[main]
		local roof = spec.roof and spec.roof(plot, main)
		-- The riding service's stable is an open shelter (its template is
		-- the 21 x 17 one), re-stamped over the plot's own lamps below.
		local open_shelter = services.service(KEY, plot.id) == "riding"
		local part, turns, rw, rd, ox, oz
		local x0, z0, x1, z1
		if plot.yard then
			turns, rw, rd, ox, oz = 0, 1, 1, 0, 0
			x0, z0, x1, z1 = yard_area(plot, reach)
		else
			part = CAPITAL.part(plot.template, plot.id, main, roof)
			-- The part is centred on the plot origin, which is also the
			-- reference column: the terrain height under the middle of the
			-- plot is the height the whole plot is levelled to. A quarter turn
			-- swaps the footprint, so the centring reads the ROTATED width.
			turns = (plot.turns or 0) % 4
			rw = (turns % 2 == 1) and part.d or part.w
			rd = (turns % 2 == 1) and part.w or part.d
			ox = -math.floor((rw - 1) / 2)
			oz = -math.floor((rd - 1) / 2)
			x0, z0, x1, z1 = ground_area(part, ox, oz, turns, plot.margin, reach)
		end
		local peak = part and part.peak or 0

		local buf = parts.buffer()
		-- 1. The plot's ground and its airspace. The clear goes down to the
		-- ground course as well, because the terrace shoulder this plot cuts
		-- through occupies those cells in the world.
		buf:fill(x0, -1, z0, x1, -1, z1, palette.node("subsoil"))
		buf:fill(x0, 0, z0, x1, 0, z1, palette.node("ground"))
		local clear_to = peak + 2
		-- W2-05: Dur Brannoc and Kezamba also clear to the part's highest
		-- cell as its generator built it (the template's `top`, format doc
		-- §4.1); the other four only to `peak + 2`.
		if spec.clear_to_top and part and part.top > clear_to then
			clear_to = part.top
		end
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
			-- the field is entered from the lane rather than across its edge, and
			-- the two lamps every plot carries.
			for z = z0, z0 + 1 do
				for x = -1, 1 do
					buf:put(x, 0, z, palette.node("path"))
				end
			end
			dressing.path_light(buf, palette, x0 + YARD_LAMP, z0 + 1)
			dressing.path_light(buf, palette, x1 - YARD_LAMP, z0 + 1)
		else
			-- 3. The doorstep path from the part's own apron out to the street
			-- edge of the plot (no kerb round the plot since Round 47: the user
			-- disliked the stone frame round every capital building).
			for z = z0 + 1, oz - 1 do
				for x = -1, 1 do
					buf:put(x, 0, z, palette.node("path"))
				end
			end

			-- 4. The part itself.
			points = parts.stamp(buf, part, ox, 0, oz, turns)

			-- 5. Two lamps on the street corners of the plot, and a bench
			-- beside the door, its back to the house and its seat to the
			-- street (face 2: it looks along -z).
			for _, lamp in ipairs({{x0 + LAMP.inset, z0 + LAMP.row},
					{x1 - LAMP.inset, z0 + LAMP.row}}) do
				dressing[LAMP.kind](buf, palette, lamp[1], lamp[2])
			end
			dressing.bench(buf, palette, 3, z0 + 2, 2, 3, "x")
		end

		-- 5b. A garden plot plants the ring its wider ground bought: a tree at
		-- each of four spots, a planter and a bench between them, and the
		-- carrier's crates by the gate. Everything stands on the plot's own
		-- turf, outside the part's paving, which is why only a plot with a
		-- margin may ask for it.
		if plot.garden then
			local garden = spec.garden
			if garden then
				local spots = {{x0 + 2, z0 + 2}, {x1 - 2, z0 + 2},
					{x0 + 2, z1 - 2}, {x1 - 2, z1 - 2}}
				if garden.spots == "back" then
					-- never on the two street corners, where a crown would
					-- bury the lamp post
					spots = {{x0 + 2, z1 - 2}, {x1 - 2, z1 - 2},
						{x0 + 2, oz}, {x1 - 2, oz}}
				end
				for _, spot in ipairs(spots) do
					dressing[garden.tree](buf, palette, spot[1], spot[2], garden.size)
				end
				dressing.planter(buf, palette, x0 + 1, oz - 1, x0 + 2, oz + 1)
				dressing.planter(buf, palette, x1 - 2, oz - 1, x1 - 1, oz + 1)
				dressing.bench(buf, palette, -1, z1 - 2, 2, 3, "x")
				dressing.crates(buf, palette, x1 - 2, z0 + 4, 2)
			elseif not spec.garden_ignored then
				error("wp13 " .. LABEL .. " plot: " .. tostring(plot.id) ..
					" asks for a garden this capital does not plant", 0)
			end
		end

		-- 5c. Whatever this plot alone wants on its own ground: the drill
		-- yard's posts and standards, the herb garden's beds, the tavern's
		-- trestles. It is handed the buffer, the palette and the plot's own
		-- ground rectangle, and it runs BEFORE the sockets are collected so a
		-- piece of dressing can stand where a socket would otherwise be
		-- published into a wall. `area.part` builds another template of the
		-- roster in the plot's palette (Nhal Veyr's ruin close stamps two).
		local area = {x0 = x0, z0 = z0, x1 = x1, z1 = z1, ox = ox, oz = oz,
			pw = rw, pd = rd, peak = peak, clear_to = clear_to, reach = reach,
			dressing = dressing, parts = parts, palettes = palettes,
			part = function(template, id) return CAPITAL.part(template, id, main) end}
		for name, module in pairs(modules) do area[name] = module end
		if type(plot.decorate) == "function" then
			plot.decorate(buf, palette, area)
		end

		-- 6. Sockets: the part's own, plus this plot's waypoint in the
		-- district loop where the part publishes none of its own.
		local sockets = {}
		-- What this plot changes about the sockets its PART published. A
		-- template knows its own building and nothing about the composition
		-- it is built into, so it cannot know which of its walls faces a lane
		-- or where this plot's path runs; the roster says so instead of the
		-- template being edited per composition. Keyed by socket id, and a
		-- function of the plot's own ground rectangle, because that is where
		-- the answers are.
		local overrides = {}
		if type(plot.socket_overrides) == "function" then
			overrides = plot.socket_overrides(area)
		end
		for _, entry in ipairs(points.sockets or {}) do
			-- `drop` is the row's socket policy (Kezamba's: a part offering a
			-- role the capital holds elsewhere). `spawn` travels with the
			-- socket: a template that publishes a spare must not lose it here.
			if not (plot.drop and plot.drop[entry.role]) then
				local override = overrides[entry.id] or {}
				sockets[#sockets + 1] = {id = entry.id, role = entry.role,
					x = override.x or entry.x, y = override.y or entry.y,
					z = override.z or entry.z,
					face = override.face or entry.face,
					group = entry.group, order = entry.order, kind = entry.kind,
					activity = entry.activity,
					spawn = entry.spawn, tags = override.tags or entry.tags}
			end
		end
		if plot.order then
			sockets[#sockets + 1] = {id = plot.id .. "_watch",
				role = "guard_patrol", x = 0, y = 1, z = z0 + 2, face = 0,
				group = watch, order = plot.order}
		end
		-- Every plot publishes one flair spot at its own gate, on the
		-- doorstep path: the plot templates frozen from the start-town
		-- generators publish no socket of their own, and a district of nine
		-- plots with four inhabited ones is not a district anybody lives in.
		--
		-- Gor Drazhak's FILL PLOT'S IS A SPARE, not a resident. A field, a
		-- spoil heap or a wood yard has a way in but no doorstep, and standing
		-- somebody at the gate of a paddock for the life of the world is a
		-- resident spent on nothing; `spawn = false` keeps the position and
		-- takes the person off it (sixteen of the forty-seven residents that
		-- capital shed to reach the 150..170 band, 2026-09-15).
		if spec.fill_gate_spare and context.fill then
			sockets[#sockets + 1] = {id = plot.id .. "_gate_spare",
				role = "idle", x = 0, y = 1, z = z0 + 2, face = plot.gate_face or 0,
				spawn = false}
		else
			sockets[#sockets + 1] = {id = plot.id .. "_gate_idle", role = "idle",
				x = 0, y = 1, z = z0 + 2, face = plot.gate_face or 0, tags = {"door"}}
		end
		-- Whatever this plot alone publishes: the martial district's guard
		-- posts, a district's spare wander spots. It is handed the same ground
		-- rectangle the decoration was, because a socket is a promise that
		-- somebody can stand there and only the plot knows which of its
		-- corners is still free after its own dressing.
		if type(plot.extra_sockets) == "function" then
			local group_order = spec.extra_group_order
			for _, entry in ipairs(plot.extra_sockets(area)) do
				sockets[#sockets + 1] = {id = plot.id .. "_" .. entry.id,
					role = entry.role, x = entry.x, y = entry.y or 1,
					z = entry.z, face = entry.face or 0, tags = entry.tags,
					kind = entry.kind, activity = entry.activity,
					spawn = entry.spawn,
					-- W2-06: only Gor Drazhak's and Lethariel's copies kept these
					group = group_order and entry.group or nil,
					order = group_order and entry.order or nil}
			end
		end
		composition.face_dirs(sockets)

		if open_shelter then
			-- Generic shopfront lamps/benches must not become extra shelter
			-- posts or intrude into the open stable's public approach.
			buf:clear(x0, 1, z0, x1, clear_to, z1)
			parts.stamp(buf, part, ox, 0, oz, turns)
		end
		services.decorate(KEY, plot.id, buf, palette, sockets, area)
		-- (Every closed room's small touches, the Round 36 decor kit, are the
		-- template's own since Round 56.)
		parts.resolve_panes(buf)

		-- Round 47 town greening: the race's trees on the plot's open wild
		-- ground (the same in every world, as the plot is).
		layout.green(buf, palette, M.REACH, sockets, points.doors)
		local cells, bounds, palette_list, lights =
			composition.finish(buf, palette, {lights = spec.lights})

		local doorways, rooms = {}, {}
		composition.collect(points, plot.id, doorways, rooms)
		local destinations = {}
		local spot = (points.inside or {})[1]
		if spot then
			destinations[1] = {id = plot.id, x = spot.x, y = spot.y, z = spot.z}
		end

		local landmarks = {
			arrival = {x = 0, y = 1, z = z0 + 2},
			plot = {min = {x = x0, y = -1, z = z0},
				max = {x = x1, y = peak, z = z1}},
			entry = {x = 0, y = 1, z = z0 + 1},
			destinations = destinations,
			doors = doorways,
			rooms = rooms,
			lights = lights,
			sockets = sockets,
		}
		if spec.parapet_columns then
			landmarks.parapet_columns = part and part.parapet_columns or 0
		end
		return {
			-- One schema per plot, not one for the district: the successor
			-- compares `blueprint.schema` with the profile's own
			-- (`r7_settlement.validate`), so nine plots behind one string
			-- would need nine profiles that all claim to be the same
			-- blueprint.
			schema = "grug_wp13_" .. KEY .. "_plot_" .. plot.id .. "_v1",
			id = plot.id,
			cells = cells,
			bounds = bounds,
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
			-- bounds would credit the plot with headroom it never cut.
			-- `r7_settlement.audit_terrain` holds the rise under the plot
			-- against it, and the capital planner caps a site's rise at it.
			clear_to = clear_to,
			landmarks = landmarks,
		}
	end

	-- A district: its key, its role, its patrol loop and the ordered plot and
	-- fill lists, each entry carrying a builder that returns the
	-- composition. Where it stands is not here -- a district does not know
	-- where it stands until the capital planner places it. A building row
	-- stands on a lot of `REACH`; a fill row is handed the reach of the fill
	-- lot it stands on, its district's `fill_reaches` (default
	-- `FILL_REACHES`), one per fill row.
	function M.district(definition)
		local district = {
			key = definition.key,
			role = definition.role,
			patrol_group = definition.patrol_group,
			plots = {},
			fill = {},
		}
		local function entries(list, into, reaches)
			list = list or {}
			if reaches and #list ~= #reaches then
				error("wp13 " .. LABEL .. ": " .. tostring(definition.key) .. " has " ..
					#list .. " fill rows for " .. #reaches .. " fill lots", 0)
			end
			for index, plot in ipairs(list) do
				local context = {patrol_group = definition.patrol_group,
					reach = reaches and reaches[index], fill = reaches ~= nil}
				into[index] = {
					id = plot.id,
					build = function() return M.build(plot, context) end,
				}
			end
		end
		entries(definition.plots, district.plots)
		entries(definition.fill, district.fill,
			definition.fill_reaches or M.FILL_REACHES)
		return district
	end

	return M
end

return loader
