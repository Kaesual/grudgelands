-- The composition skeleton the six capital cores and the capital plot engine
-- share (Round 82, audit W2-04): the steps every one of them wrote out in
-- full and in the same words, kept here once. Each composition keeps its own
-- authored data and its own steps; what is here is only the bookkeeping
-- round them:
--
--   * `new(buf, label)`, the working state of one composition: the buffer,
--     its doorways, rooms, sockets and placed buildings;
--   * `place(c, plot, part, opts)`, one building stamped at its pad anchor
--     with the cell claim (two buildings never share a cell), its doors,
--     rooms, inside point and sockets collected;
--   * `paved_prop(c, site)`, the prop guard: every prop a composition asks
--     for MUST land, a prop quietly skipped is a hole in the authored scene
--     no fixture can see (the Dawnmere lesson, wp13-hearthpine-library.md
--     round A);
--   * `finish(buf, palette, opts)`, the canonical cell list, its bounds, the
--     sorted palette and the lights;
--   * `outdoors`, `pave`, `socket`, `face_dirs`, `destinations`, `box` and
--     `door_of`.
--
-- The start towns still carry their own copies; they can move onto this
-- module the same way (a later round).
--
-- `dofile(directory .. "/composition.lua")(parts, layout, templates)`, with
-- the caller's own loaded modules. Plain Lua 5.1, pure, no engine calls, no
-- globals.

local function loader(parts, layout, templates)
	local C = {}

	-- The working state of one composition. `label` names it in errors
	-- ("highcourt", "dur brannoc").
	function C.new(buf, label)
		return {buf = buf, label = label, doorways = {}, rooms = {}, sockets = {},
			placed = {}, inside_by_id = {}, plot_order = {}, claimed = {}, stamped = {}}
	end

	-- A stamped part's doors and rooms, recorded under the building `id`.
	function C.collect(points, id, doorways, rooms)
		for _, door in ipairs(points.doors or {}) do
			doorways[#doorways + 1] = {x = door.x, y = door.y, z = door.z,
				face = door.face, id = id}
		end
		for index = 1, #(points.room_corner or {}), 2 do
			local a = points.room_corner[index]
			local b = points.room_corner[index + 1]
			rooms[#rooms + 1] = {
				min = {x = math.min(a.x, b.x), y = a.y, z = math.min(a.z, b.z)},
				max = {x = math.max(a.x, b.x), y = a.y, z = math.max(a.z, b.z)},
				top = a.top, closed = a.closed, id = id,
			}
		end
	end

	-- One authored building of a core: `plot` is its row ({id, x, z, turns,
	-- drop, recast}), `part` the built template. Returns the stamp's points
	-- and the index of its first socket in `c.sockets`.
	--
	-- Two plots may not share a cell. `parts.stamp` writes; it does not ask. A
	-- plot laid over another one therefore cuts a silent hole in the first --
	-- a wall, a roof valley or a doorway simply replaced -- and the pad still
	-- builds, which is the shape of defect that cost Dawnmere twenty-two
	-- props. Overwriting the streets and the ground under a plot is intended
	-- (a plot brings its own apron); overwriting another plot never is, so
	-- every cell a plot writes is claimed here and a second claim is fatal.
	-- Overhangs are included, because an eave over a neighbour's roof is
	-- exactly the case a footprint rectangle misses.
	--
	-- `opts`:
	--   * `check(plot, part, turns, box)`, the composition's own site rule,
	--     called before the stamp with the claimed cells' extent `box`
	--     ({min_x, max_x, min_y, max_y, min_z, max_z});
	--   * `stamped(plot, part, turns, points)`, called right after the stamp;
	--   * `activity`, what the copy of a part socket does with its `activity`
	--     (audit W2-06, the copies drifted): nil drops it, "copy" copies it,
	--     "copy_unless_recast" copies it and a recast clears it.
	function C.place(c, plot, part, opts)
		opts = opts or {}
		local turns = plot.turns % 4
		local claimed = c.claimed
		local box
		local source, count = part.buffer:cells()
		for index = 1, count do
			local cell = source[index]
			local rx, rz = parts.rotate_footprint(cell.x, cell.z, part.w, part.d, turns)
			local x, z = plot.x + rx, plot.z + rz
			if box == nil then
				box = {min_x = x, max_x = x, min_y = cell.y, max_y = cell.y,
					min_z = z, max_z = z}
			else
				if x < box.min_x then box.min_x = x end
				if x > box.max_x then box.max_x = x end
				if cell.y < box.min_y then box.min_y = cell.y end
				if cell.y > box.max_y then box.max_y = cell.y end
				if z < box.min_z then box.min_z = z end
				if z > box.max_z then box.max_z = z end
			end
			local key = x .. ":" .. cell.y .. ":" .. z
			local owner = claimed[key]
			if owner ~= nil then
				error("wp13 " .. c.label .. ": the plot " .. plot.id .. " writes " ..
					cell.name .. " into " .. owner .. " at " .. key, 0)
			end
			claimed[key] = plot.id
		end
		if opts.check then opts.check(plot, part, turns, box) end
		local points = parts.stamp(c.buf, part, plot.x, 0, plot.z, turns)
		if opts.stamped then opts.stamped(plot, part, turns, points) end
		local footprint = points.footprint[1]
		c.placed[plot.id] = {x = plot.x, z = plot.z, w = footprint.w,
			d = footprint.d, peak = part.peak}
		c.plot_order[#c.plot_order + 1] = c.placed[plot.id]
		C.collect(points, plot.id, c.doorways, c.rooms)
		local spot = (points.inside or {})[1]
		if spot then
			c.inside_by_id[plot.id] = {x = spot.x, y = spot.y, z = spot.z}
		end
		-- The building's own sockets; a socket point without a role is the
		-- position of one of the composition's own sockets.
		templates.collect_sockets(c.stamped, points, plot.id)
		local sockets = c.sockets
		local first = #sockets + 1
		local activity = opts.activity
		for _, entry in ipairs(points.sockets or {}) do
			local drop = entry.role == nil or (plot.drop and plot.drop[entry.role])
			if not drop then
				-- `drop` and `recast` are the socket policy: a part does not
				-- know how many of a thing a capital may have, so a socket the
				-- capital holds only once (a throne, a travel pad, a vendor
				-- family) is dropped or re-published as what it is there.
				-- `spawn` travels with the socket: a template that publishes a
				-- spare must not lose it here.
				local recast = plot.recast and plot.recast[entry.role]
				local out = {id = entry.id, role = entry.role,
					x = entry.x, y = entry.y, z = entry.z,
					face = entry.face, group = entry.group,
					order = entry.order, kind = entry.kind,
					activity = activity and entry.activity or nil,
					spawn = entry.spawn, tags = entry.tags}
				if recast then
					out.role = recast.role
					out.tags = recast.tags
					out.kind, out.group, out.order = nil, nil, nil
					if activity == "copy_unless_recast" then out.activity = nil end
					if recast.from then
						out.id = out.id:gsub(recast.from, recast.to, 1)
					end
				end
				sockets[#sockets + 1] = out
			end
		end
		return points, first
	end

	-- True where (x, z) is outside every placed building's footprint.
	function C.outdoors(c)
		local plot_order = c.plot_order
		return function(x, z)
			for _, plot in ipairs(plot_order) do
				if x >= plot.x and x <= plot.x + plot.w - 1 and
						z >= plot.z and z <= plot.z + plot.d - 1 then
					return false
				end
			end
			return true
		end
	end

	-- The prop guard of a capital: `paved_prop(name, x1, z1, x2, z2, build)`
	-- refuses a prop whose rectangle is taken (`layout.free_area`, four
	-- courses of headroom) or which `build` could not complete (it returned
	-- false). `site(x1, z1, x2, z2)` is the composition's own ground rule:
	-- nil, or why the rectangle cannot carry a prop (Lethariel's mere,
	-- Kezamba's lake and gorge).
	function C.paved_prop(c, site)
		local buf, label = c.buf, c.label
		local function refuse(name, x, z, reason)
			error("wp13 " .. label .. ": prop " .. name .. " at " .. x .. "," .. z ..
				" was not placed: " .. reason, 0)
		end
		return function(name, x1, z1, x2, z2, build)
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then
				refuse(name, x1, z1, "the space is taken")
			end
			local reason = site and site(x1, z1, x2, z2)
			if reason then refuse(name, x1, z1, reason) end
			if build() == false then
				refuse(name, x1, z1, "the prop could not be completed")
			end
		end
	end

	-- A paved rectangle with its headroom cleared to `height` (default 4),
	-- written from a node NAME rather than from a role: the citadel paving
	-- is an optional role with a fallback, which `layout.pave` cannot take.
	function C.pave(c)
		local buf = c.buf
		return function(name, x1, z1, x2, z2, height)
			for z = z1, z2 do
				for x = x1, x2 do
					buf:put(x, 0, z, name)
				end
			end
			buf:clear(x1, 1, z1, x2, height or 4, z2)
		end
	end

	-- The composition's own socket: `socket(id, role, x, y, z, face, extra)`
	-- appends one to `c.sockets`, `extra` copied field by field.
	function C.socket(c)
		local sockets = c.sockets
		return function(id, role, x, y, z, face, extra)
			local entry = {id = id, role = role, x = x, y = y, z = z, face = face % 4}
			for key, value in pairs(extra or {}) do entry[key] = value end
			sockets[#sockets + 1] = entry
		end
	end

	-- The canonical cell list (sorted z, y, x), its bounds, the palette
	-- (ASCII byte order, not Lua's `<`, which is `strcoll`; see
	-- `parts.less_bytes`) and the lights.
	--
	-- `opts`:
	--   * `keep(cell)`: only the cells it accepts are the composition's;
	--   * `lights`, optional light roles beyond the light post, the wall light
	--     and the indoor light, counted where the palette binds them.
	function C.finish(buf, palette, opts)
		opts = opts or {}
		local source, count = buf:cells()
		local cells = {}
		local keep = opts.keep
		for index = 1, count do
			local cell = source[index]
			if not keep or keep(cell) then cells[#cells + 1] = cell end
		end
		parts.sort_cells_zyx(cells)
		local light_names = {[palette.node("light_post")] = true,
			[palette.node("light_wall")] = true,
			[palette.node("light_indoor")] = true}
		for _, role in ipairs(opts.lights or {}) do
			local name = palette.maybe(role)
			if name then light_names[name] = true end
		end
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
		return cells, {min = minp, max = maxp}, palette_list, lights
	end

	-- The sockets contract carries `dir` as a unit vector; the parts carry
	-- `face` as a facedir, because a facedir is what rotates with a stamped
	-- part. This is the settlement boundary, so it is converted here, with
	-- the library's own table rather than with `core.facedir_to_dir`, which
	-- is an engine call.
	function C.face_dirs(sockets)
		for _, entry in ipairs(sockets) do
			local dx, dz = parts.facedir_step(entry.face)
			entry.dir = {x = dx, z = dz}
		end
	end

	-- The destinations in `order` (part of the consumer contract, never
	-- changed): each building's inside point.
	function C.destinations(c, order)
		local destinations = {}
		for _, id in ipairs(order) do
			local spot = c.inside_by_id[id]
			if not spot then
				error("wp13 " .. c.label .. ": destination " .. id .. " is missing", 0)
			end
			destinations[#destinations + 1] = {id = id, x = spot.x, y = spot.y, z = spot.z}
		end
		return destinations
	end

	-- A placed building's box, grown by `margin` and lifted `lift` over its
	-- peak, and its first door.
	function C.box(c, id, margin, lift)
		local plot = c.placed[id]
		return {
			min = {x = plot.x - margin, y = -1, z = plot.z - margin},
			max = {x = plot.x + plot.w - 1 + margin,
				y = plot.peak + lift, z = plot.z + plot.d - 1 + margin},
		}
	end
	function C.door_of(c, id)
		for _, door in ipairs(c.doorways) do
			if door.id == id then
				return {x = door.x, y = door.y, z = door.z}
			end
		end
		error("wp13 " .. c.label .. ": no door for " .. id, 0)
	end

	return C
end

return loader
