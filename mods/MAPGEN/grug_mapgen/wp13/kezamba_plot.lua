-- One Kezamba district plot, built from a roster row.
--
-- This is `highcourt_plot.lua`'s builder in the troll palette. It is a copy and
-- not a shared module for the reason `dur_brannoc_district.lua` gives for the
-- same decision: a district is a COMPOSITION and not a generator, the Highcourt
-- files are the pilot capital's own and frozen against its blueprint digests,
-- and a shared builder would make every future plot defect a change to four
-- capitals at once. What IS shared is the rule, and the rule is the capitals
-- contract's section 2.1:
--
--   * a district plot cannot be anchor-relative, because WP40 terraces the 512
--     envelope (step 3 for the troll cenote terrace), so each plot names one
--     REFERENCE COLUMN whose final height the settlement config asks once per
--     session and projects the whole plot from;
--   * a FOUNDATION SKIRT, the perimeter carried down to y = -6, so a downhill
--     corner stands on masonry and not on air;
--   * a CLEAR VOLUME, the plot's own airspace up to its roof, so an uphill
--     shoulder of terrace is not left standing inside a wall.
--
-- A PLOT NEED NOT BE A BUILDING. A roster row carrying `yard` instead of
-- `module`/`make` builds the same ground, skirt, clear volume, gate path, lamps
-- and sockets with no part in the middle of it, and whatever its own `decorate`
-- plants on it. That is what a field, a vine terrace, a log yard, a moot green
-- or a basin is.
--
-- WHERE THIS DIFFERS FROM HIGHCOURT'S, and both differences are Kezamba's own:
--
--   * the REACH is the lot's own and is carried in from `kezamba_lots.lua`
--     rather than fixed at 13, because Kezamba's lots were SEARCHED against the
--     terrain and each fill slot has a size of its own;
--   * a plot walks on TIMBER. The troll palette binds `path` to junglewood --
--     "in a basin that floods, a settlement walks on boardwalks, not on stone"
--     (`palette.lua`) -- so a plot's gate path and kerb are deck and not
--     paving, and that one binding is what makes the whole capital read as one
--     continuous timber walk.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local capitals = dofile(directory .. "/capitals.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local troll = dofile(directory .. "/troll_parts.lua")(directory)
	local handles = dofile(directory .. "/troll_palette.lua")()

	local M = {}

	M.FLOOR = -6
	-- The LEAST airspace a plot clears, whatever its own roof needs. The lot
	-- predicate (`tools/wp13/kezamba_lots.lua`) holds every lot's rise against
	-- this number, so the two have to be the same number and it is spelled once
	-- here and once there with a comment in each pointing at the other.
	M.MIN_CLEAR = 8

	M.BASALT = handles.BASALT
	M.WATER = handles.WATER
	M.CROP = handles.CROP

	-- ---- the socket shapes a roster may publish -----------------------

	function M.guard_post(id, x, z, face)
		return {id = "post_" .. id, role = "guard_post", x = x, z = z,
			face = face or 0}
	end

	-- A SPARE: a real standing position nobody is ever placed on, so a
	-- villager's amble has somewhere to go that is not another villager's
	-- doorstep. `spawn = false` is the whole of it and it carries NO TAG --
	-- a tag is what a spoken line reads off and a spare has nothing to say
	-- (sockets contract section 6).
	function M.spare(id, x, z, face)
		return {id = "spare_" .. id, role = "idle", x = x, z = z,
			face = face or 0, spawn = false}
	end

	-- A WORK socket (sockets contract section 8.1): always staffed, always
	-- static, naming its ACTIVITY and facing the feature that activity works
	-- within three nodes. `y` defaults to 1, the first walkable course over the
	-- plot's ground; a `sit` socket on a bench passes 2, because a seat is a
	-- walkable node and the resident sits on top of it.
	function M.work(id, activity, x, z, face, tags, y)
		return {id = "work_" .. id, role = "work", activity = activity,
			x = x, y = y or 1, z = z, face = face or 0, tags = tags}
	end

	-- A PROFESSION VENDOR (section 8.4). The capital holds at most one of each
	-- kind, which the KAT asserts across every composition at once.
	function M.vendor(id, kind, x, z, face)
		return {id = "vendor_" .. id, role = "vendor", kind = kind,
			x = x, z = z, face = face or 0}
	end

	-- ---- the builder --------------------------------------------------

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
		local function clamp(value)
			if value < -reach then return -reach end
			if value > reach then return reach end
			return value
		end
		margin = margin or 2
		return clamp(x0 - margin), clamp(z0 - margin), clamp(x1 + margin),
			clamp(z1 + margin)
	end

	local function yard_area(plot, reach)
		local yard = plot.yard
		local half_x = yard.w or reach
		local half_z = yard.d or reach
		if half_x < 3 or half_z < 3 then
			error("wp13 kezamba plot: the yard " .. tostring(plot.id) ..
				" has no extent", 0)
		end
		if half_x > reach or half_z > reach then
			error("wp13 kezamba plot: the yard " .. tostring(plot.id) ..
				" is wider than its own lot", 0)
		end
		return -half_x, -half_z, half_x, half_z
	end

	function M.build(plot, context)
		context = context or {}
		local watch = plot.patrol_group or context.patrol_group
		local reach = plot.reach or 13
		local palette = palettes.new("troll")
		if plot.handle == "basalt" then
			palette = palettes.new("troll", handles.BASALT)
		elseif plot.handle == "water" then
			palette = palettes.new("troll", handles.WATER)
		elseif plot.handle == "basalt_water" then
			palette = palettes.new("troll",
				handles.merged(handles.BASALT, handles.WATER))
		elseif plot.handle == "crop" then
			-- The crop handle is the one a FIELD asks for, and only a field:
			-- binding `crop` everywhere would change `dressing.plant` too --
			-- it reads `flower or crop or grass_tuft` -- and put reeds in
			-- every grove, pasture and terrace this capital dresses. The
			-- three fields of `kezamba_districts.lua` name it and nothing
			-- else does.
			palette = palettes.new("troll", handles.CROP)
		end
		local spec = {}
		for key, value in pairs(plot.spec or {}) do spec[key] = value end
		spec.id = plot.id

		local part, turns, rw, rd, ox, oz
		local x0, z0, x1, z1
		if plot.yard then
			turns, rw, rd, ox, oz = 0, 1, 1, 0, 0
			x0, z0, x1, z1 = yard_area(plot, reach)
		else
			local module = capitals
			if plot.module == "buildings" then module = buildings
			elseif plot.module == "troll" then module = troll end
			local generator = module[plot.make]
			if type(generator) ~= "function" then
				error("wp13 kezamba plot: no generator " .. tostring(plot.make),
					0)
			end
			part = generator(palette, spec)
			turns = (plot.turns or 0) % 4
			rw = (turns % 2 == 1) and part.d or part.w
			rd = (turns % 2 == 1) and part.w or part.d
			ox = -math.floor((rw - 1) / 2)
			oz = -math.floor((rd - 1) / 2)
			x0, z0, x1, z1 = ground_area(part, ox, oz, turns, plot.margin,
				reach)
		end
		local peak = part and part.peak or 0

		local buf = parts.buffer()
		-- 1. The plot's ground and its airspace. The clear reaches the ground
		-- course too, because the terrace shoulder this plot cuts through
		-- occupies those cells in the world.
		buf:fill(x0, -1, z0, x1, -1, z1, palette.node("subsoil"))
		buf:fill(x0, 0, z0, x1, 0, z1, palette.node("ground"))
		local clear_to = peak + 2
		if part then
			local order, count = part.buffer:cells()
			for index = 1, count do
				if order[index].y > clear_to then clear_to = order[index].y end
			end
		end
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
		if plot.yard then
			-- A yard's own gate: three columns of boardwalk at the street edge,
			-- and the two lamps every plot carries.
			for z = z0, z0 + 1 do
				for x = -1, 1 do
					buf:put(x, 0, z, palette.node("path"))
				end
			end
			-- THE LAMPS STAND ON THE PLOT'S OUTERMOST COLUMNS and not one node
			-- in. A lamp at x0 + 1 occupies the very cell a roster's own work
			-- or vendor socket wants -- the street row is where a shopfront,
			-- its trader and its worker all stand -- and the first version of
			-- this builder put one there, which the KAT found as "blocked at
			-- y 1" on the butcher.
			dressing.path_light(buf, palette, x0, z0 + 1)
			dressing.path_light(buf, palette, x1, z0 + 1)
		else
			dressing.inlay(buf, palette, x0, z0, x1, z1)
			for z = z0 + 1, oz - 1 do
				for x = -1, 1 do
					buf:put(x, 0, z, palette.node("path"))
				end
			end
			points = parts.stamp(buf, part, ox, 0, oz, turns)
			for _, lamp in ipairs({{x0, z0 + 1}, {x1, z0 + 1}}) do
				dressing.path_light(buf, palette, lamp[1], lamp[2])
			end
			dressing.bench(buf, palette, 3, z0 + 2, 0, 3, "x")
		end

		-- 3. Whatever this plot alone wants on its own ground. It runs BEFORE
		-- the sockets are collected, so a piece of dressing can stand where a
		-- socket would otherwise be published into a wall.
		local area = {x0 = x0, z0 = z0, x1 = x1, z1 = z1, ox = ox, oz = oz,
			pw = rw, pd = rd, peak = peak, clear_to = clear_to, reach = reach,
			dressing = dressing, parts = parts, palettes = palettes,
			troll = troll}
		if type(plot.decorate) == "function" then
			plot.decorate(buf, palette, area)
		end

		-- 4. Sockets: the part's own, this plot's waypoint in the district
		-- loop, its gate spot and whatever it alone publishes.
		local sockets = {}
		local overrides = {}
		if type(plot.socket_overrides) == "function" then
			overrides = plot.socket_overrides(area)
		end
		for _, entry in ipairs(points.sockets or {}) do
			-- DROP: what a plot takes away from the sockets its PART published.
			-- A capital has exactly one throne, one travel pad and one quest
			-- shell, and a generator cannot know that -- `capitals.temple`
			-- publishes a quest socket wherever it stands. The roster says so
			-- instead of the shared library being edited per composition, which
			-- is the hook `dur_brannoc.lua` settled on.
			local drop = plot.drop and plot.drop[entry.role]
			local override = overrides[entry.id] or {}
			if not drop then
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
		-- Every plot publishes one flair spot at its own gate: the plots built
		-- from `buildings.lua` publish no socket of their own, and a district of
		-- nine plots with four inhabited ones is not a district anybody lives
		-- in.
		sockets[#sockets + 1] = {id = plot.id .. "_gate_idle", role = "idle",
			x = 0, y = 1, z = z0 + 2, face = 0, tags = {"door"}}
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
			-- compares `blueprint.schema` with the profile's own, so 52 plots
			-- behind one string would need 52 profiles all claiming to be the
			-- same blueprint.
			schema = "grug_wp13_kezamba_plot_" .. plot.id .. "_v1",
			id = plot.id,
			cells = cells,
			bounds = {min = minp, max = maxp},
			palette = palette_list,
			reference = {x = 0, z = 0},
			-- The airspace this plot actually CUT, which is not the top of its
			-- bounds: a lamp post or a tree written after the clear reaches
			-- above it. `r7_settlement.audit_terrain` holds the rise under the
			-- plot against this number.
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

	-- A district: its key, its role, its patrol loop and the ordered plot and
	-- fill lists, each entry carrying a builder. The OFFSET is not here: it
	-- comes from `kezamba_lots.lua`, which is where the terrain answered.
	function M.district(definition, lots, fill_lots)
		local district = {
			key = definition.key,
			role = definition.role,
			patrol_group = definition.patrol_group,
			plots = {},
			fill = {},
		}
		local function entries(list, into, available)
			for index, plot in ipairs(list or {}) do
				local lot = available[index]
				if lot == nil then
					error("wp13 kezamba: " .. definition.key ..
						" has no lot for " .. tostring(plot.id), 0)
				end
				plot.reach = lot.reach
				into[index] = {
					id = plot.id,
					build = function()
						return M.build(plot,
							{patrol_group = definition.patrol_group})
					end,
				}
			end
			if #(list or {}) ~= #available then
				error("wp13 kezamba: " .. definition.key .. " has " ..
					#(list or {}) .. " rows for " .. #available .. " lots", 0)
			end
		end
		entries(definition.plots, district.plots, lots)
		entries(definition.fill, district.fill, fill_lots)
		return district
	end

	return M
end

return loader
