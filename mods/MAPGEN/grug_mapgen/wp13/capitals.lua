-- WP13 capital-scale parts: the pieces a capital composition assembles into
-- a core and four districts.
--
-- Same contract as `buildings.lua`: a generator takes a palette handle and a
-- spec and returns a PART -- `{buffer, w, d, peak, points}` in its own local
-- frame, x running 0..w-1, z running 0..d-1, y = 0 the ground node and y = 1
-- the first walkable course -- which `parts.stamp` places at any of the four
-- rotations. Everything is addressed through palette roles, so one generator
-- serves all six races.
--
-- Two things are new here and both come out of
-- docs/research/wp13-capitals-pois-contract.md:
--
--   * the CAPITAL VOCABULARY. `castle_wall`, `castle_wall_stair`,
--     `castle_wall_slab`, `castle_paving`, `castle_rubble`, `castle_slit`,
--     `pillar` and the three `signature` roles are all OPTIONAL, so every
--     accessor below has a fallback into the start vocabulary. That is not
--     defensive habit: it is what lets these parts be built for a palette
--     that has not been given a capital binding yet, and what keeps the six
--     shipped start blueprints byte-identical, since none of them reads a
--     role that did not already exist.
--   * NPC SOCKETS. `points.sockets` is the array of
--     docs/research/wp13-npc-sockets-contract.md section 2: a named standing
--     position with a role, in the part's own local frame, carrying a
--     `face` (a facedir) that `parts.stamp` rotates with the part. `finish`
--     below refuses a socket whose cell or headroom is occupied or whose
--     floor is air, so a part cannot publish a standing position an NPC
--     cannot stand in; `tools/wp13/library_kat.lua` section 12 repeats the
--     test against the real registry, where `walkable` is a fact and not an
--     absence of cells.
--
-- Bounds discipline (contract section 2.1): a district plot stays inside
-- 32 x 32 and y -6..24, and the king's hall inside 48 x 48 and y -2..40.
-- Every generator's comment states its own extent; the KAT measures it.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local roofs = dofile(directory .. "/roofs.lua")
	local interiors = dofile(directory .. "/interiors.lua")
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local buildings = dofile(directory .. "/buildings.lua")(directory)

	local M = {}

	-- -------------------------------------------------------------------
	-- the capital vocabulary, each with its fallback
	-- -------------------------------------------------------------------

	local function stone(palette)
		return palette.maybe("castle_wall") or palette.node("wall_accent")
	end
	local function stone_stair(palette)
		return palette.maybe("castle_wall_stair") or palette.node("roof_stair")
	end
	local function stone_slab(palette)
		return palette.maybe("castle_wall_slab") or palette.node("roof_slab")
	end
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function spoil(palette)
		return palette.maybe("castle_rubble") or palette.node("rubble")
	end
	local function mark(palette)
		return palette.maybe("signature") or palette.node("wall_accent")
	end
	local function mark_slab(palette)
		return palette.maybe("signature_slab") or palette.node("roof_slab")
	end
	local function mark_stair(palette)
		return palette.maybe("signature_stair") or palette.node("roof_stair")
	end

	-- A one-node inlaid band of a NAMED material. `dressing.inlay` takes a
	-- palette ROLE and resolves it with `node`, which refuses an unbound
	-- optional role outright, so a band of the citadel paving -- an optional
	-- role with a fallback -- is laid through here instead.
	local function band(buf, x0, z0, x1, z1, name)
		for z = z0, z1 do
			for x = x0, x1 do
				if x == x0 or x == x1 or z == z0 or z == z1 then
					buf:put(x, 0, z, name)
				end
			end
		end
	end

	-- Bear the bell frame of a stamped belfry on its own lantern ring.
	--
	-- `buildings.belfry` hangs the bell under a cross-beam whenever the
	-- lantern is taller than three courses, and writes that beam as a single
	-- cell at the centre of the plan (mods/MAPGEN/grug_mapgen/wp13/
	-- buildings.lua, the bell frame). Its beam ring is the EDGE cells only,
	-- so beam and bell touch each other and nothing else: a two-cell island
	-- floating inside the lantern. Nothing catches it, because every rule
	-- this library has asks whether a cell touches another cell, and these
	-- two do.
	--
	-- The frame is therefore carried across to the ring here, in the two
	-- cells between the centre and the plan's mid-side beams. This is a fix
	-- scoped to the CAPITAL parts on purpose: Silverleaf Glade's shrine
	-- stamps the same four-course lantern and its blueprint identity is
	-- frozen, so `buildings.belfry` itself must not move a cell -- the same
	-- reasoning as the well kerb in `well_court`. A composition that stamps
	-- a lantern taller than three courses must call this.
	local function bear_bell(buf, palette, ox, oy, oz, height)
		if height - 1 <= 2 then return false end
		for _, offset in ipairs({1, 3}) do
			buf:put(ox + offset, oy + height, oz + 2, palette.node("beam"))
		end
		return true
	end

	-- A dressed column from y0 to y1. The castle kit's pillar is THREE
	-- registered nodes -- base, shaft and capital -- and only that order
	-- reads as a column (`palette.prefix_roles`); a race with no pillar
	-- binding gets a plain timber post of the same height.
	local function column(buf, palette, x, y0, y1, z)
		local bottom = palette.variant("pillar", "_bottom")
		if bottom == nil then
			for y = y0, y1 do buf:put(x, y, z, palette.node("post")) end
			return
		end
		buf:put(x, y0, z, bottom)
		for y = y0 + 1, y1 - 1 do
			buf:put(x, y, z, palette.variant("pillar", "_middle"))
		end
		if y1 > y0 then
			buf:put(x, y1, z, palette.variant("pillar", "_top"))
		end
	end

	-- An arrowslit looking along (dx, dz).
	--
	-- The slit's opening runs from z = 0.3125 to z = 0.5 of its own node,
	-- that is on the node's +Z face (mods/ITEMS/grug_decor/castle.lua,
	-- `register_arrowslit`), and a facedir node's +Z face looks along
	-- `facedir_to_dir(param2)` -- the same rule the shutter of
	-- `buildings.build` obeys. A race with no slit binding gets a blind
	-- course of its own masonry, which is what a wall without loopholes is.
	local function arrowslit(buf, palette, x, y, z, dx, dz)
		local name = palette.maybe("castle_slit")
		if name == nil then
			buf:put(x, y, z, stone(palette))
			return false
		end
		buf:put(x, y, z, name, parts.step_facedir(dx, dz))
		return true
	end

	-- A foundation skirt: the perimeter of a footprint carried down to
	-- `depth` courses below the ground node, so a plot that straddles a
	-- terrace edge still stands on something (contract section 2.1). Only
	-- the perimeter, because the interior of a plot never hangs over the
	-- step -- it is the edge that does -- and a solid block would cost a
	-- plot four thousand cells of buried stone.
	local function skirt(buf, palette, x0, z0, x1, z1, depth, name)
		name = name or palette.node("foundation")
		for y = -1, -depth, -1 do
			for z = z0, z1 do
				for x = x0, x1 do
					if x == x0 or x == x1 or z == z0 or z == z1 then
						buf:put(x, y, z, name)
					end
				end
			end
		end
	end

	-- -------------------------------------------------------------------
	-- sockets
	-- -------------------------------------------------------------------

	local SOCKET_ROLES = {guard_post = true, guard_patrol = true,
		vendor = true, idle = true, quest = true, king = true,
		waypoint = true}

	-- Publish one socket. `face` is a facedir; `extra` carries the optional
	-- fields of the contract (`group`/`order` for a patrol loop, `kind` for
	-- a vendor, `tags` for an idle spot).
	local function socket(list, id, role, x, y, z, face, extra)
		local entry = {id = id, role = role, x = x, y = y, z = z,
			face = face % 4}
		for key, value in pairs(extra or {}) do entry[key] = value end
		list[#list + 1] = entry
		return entry
	end

	-- Close a part: validate every socket against the finished buffer, then
	-- return the part table.
	--
	-- A socket is a promise that an NPC can stand there, and the cheapest
	-- moment to break that promise is while the cells are still in front of
	-- us. The three tests are the construction-time half of the contract:
	-- the cell and the one above it are free, and the cell below is not air.
	-- Whether that cell below is WALKABLE is a registry question and belongs
	-- to `library_kat` section 12, which asks it of the real definitions.
	-- The highest non-air course a part actually writes.
	--
	-- Declaring `peak` by hand is how a part comes to claim a height it does
	-- not have: the first water channel called its peak the kerb rail at
	-- y = 1 while its lamp standards stood two courses higher, and a
	-- composition that reserves clearance from that number would have clipped
	-- them. Every generator measures instead.
	local function top_of(buf)
		local order, count = buf:cells()
		local peak = 0
		for index = 1, count do
			local cell = order[index]
			if cell.name ~= parts.AIR and cell.y > peak then peak = cell.y end
		end
		return peak
	end

	-- `points` may hold ONLY named lists of points: `parts.stamp` walks it
	-- with `pairs` and rotates every entry of every list, so a counter left
	-- in there is a number the stamp tries to take the length of. Authored
	-- populations therefore travel in `extra`, which lands on the part table
	-- beside `w`, `d` and `peak`, where the KAT reads them.
	local function finish(buf, w, d, peak, points, extra)
		local seen = {}
		for _, entry in ipairs(points.sockets or {}) do
			if not SOCKET_ROLES[entry.role] then
				error("wp13 capitals: socket " .. tostring(entry.id) ..
					" has the unknown role " .. tostring(entry.role), 0)
			end
			if seen[entry.id] then
				error("wp13 capitals: duplicate socket id " ..
					tostring(entry.id), 0)
			end
			seen[entry.id] = true
			for _, level in ipairs({entry.y, entry.y + 1}) do
				local cell = buf:at(entry.x, level, entry.z)
				if cell ~= nil and cell.name ~= parts.AIR then
					error("wp13 capitals: socket " .. entry.id .. " at " ..
						entry.x .. "," .. entry.y .. "," .. entry.z ..
						" is blocked by " .. cell.name .. " at y " .. level, 0)
				end
			end
			local below = buf:at(entry.x, entry.y - 1, entry.z)
			if below == nil or below.name == parts.AIR then
				error("wp13 capitals: socket " .. entry.id .. " at " ..
					entry.x .. "," .. entry.y .. "," .. entry.z ..
					" stands on air", 0)
			end
		end
		local part = {buffer = buf, w = w, d = d, peak = peak, points = points}
		for key, value in pairs(extra or {}) do
			if part[key] ~= nil then
				error("wp13 capitals: the population " .. tostring(key) ..
					" collides with a part field", 0)
			end
			part[key] = value
		end
		return part
	end

	-- A patrol loop's waypoints share a group and carry their order.
	local function patrol(list, id, group, order, x, y, z, face)
		return socket(list, id, "guard_patrol", x, y, z, face,
			{group = group, order = order})
	end

	-- -------------------------------------------------------------------
	-- 1. the king's hall
	-- -------------------------------------------------------------------

	-- The core of every capital, and the one part that is not a box.
	--
	-- The first version was: one 31 x 39 rectangle, walls all round, one
	-- gable over the lot. The render was a barn -- a single unbroken wall
	-- plane under a single unbroken roof plane, with the windows too small
	-- to break either. What a great hall needs is a SECTION, so this one is a
	-- basilica: a tall narrow nave between two arcades, a low aisle either
	-- side under its own lean-to, and the nave wall carried on the arcade
	-- rising clear above the aisle roofs as a clerestory. That gives the
	-- silhouette three roof planes at two heights, and it gives the long
	-- elevation four bands -- aisle wall, aisle roof, clerestory, nave roof
	-- -- instead of one. Four corner turrets and a buttress every sixth bay
	-- carry the rest.
	--
	-- Inside: a carpet approach from the great door to a three-step dais, the
	-- throne under a canopy of two columns and a lintel, royal hangings on
	-- the end wall, benches down both aisles and a service door for the
	-- household in the west aisle wall.
	--
	-- Extent at the default 31 x 39: x -3..w+1 and z -3..d+1, so 36 x 44
	-- including the forecourt steps and the buttresses -- inside the
	-- capitals contract's 48 x 48 for a core -- and y -2..22, inside its
	-- y -2..40.
	--
	-- The shell is built the way `buildings.build` builds one, from the roof
	-- DOWN: the roof height field is made first and every perimeter column is
	-- carried to one node below the roof above it, so the gable ends close
	-- themselves and no wall leaves a gap under its eave.
	function M.king_hall(palette, spec)
		local w = spec.w or 31
		local d = spec.d or 39
		local rise = spec.rise or 7
		-- y = 0 apron, y = 1 podium, y = 2 hall floor, y = 3 first air course.
		local base = 2
		local arcade_x = spec.arcade or 5
		local right = w - 1 - arcade_x
		local aisle_eave = base + 4
		local nave_eave = base + 14
		local arcade_head = base + 6
		local lintel = arcade_head + 1
		local centre = math.floor((w - 1) / 2)
		local buf = parts.buffer()
		local lights, doors, sockets = {}, {}, {}
		if right - arcade_x < 8 then
			error("wp13 capitals: the king's hall has no nave", 0)
		end

		-- Three roofs, unioned: the nave's gable rides over the two aisle
		-- lean-tos, and where they meet the higher surface wins, which is
		-- what leaves the clerestory its wall.
		local field = roofs.combine({
			-- The nave roof lands ON the clerestory wall and does not
			-- oversail it. A one-node overhang looked right in section and
			-- wrong at the gable, where it left a plank ledge four courses
			-- clear of the aisle roof below it with nothing under its nose.
			roofs.gable({x0 = arcade_x, x1 = right, z0 = -1, z1 = d,
				base = nave_eave, axis = "z", rise = rise}),
			-- The aisle pitch is the width of the aisle, so the lean-to is
			-- not clipped: a clipped one ends in a flat three-node deck
			-- against the clerestory, which reads as a gutter running the
			-- whole length of the building.
			roofs.lean_to({x0 = -1, x1 = arcade_x - 1, z0 = -1, z1 = d,
				base = aisle_eave, up = "x+", rise = arcade_x}),
			roofs.lean_to({x0 = right + 1, x1 = w, z0 = -1, z1 = d,
				base = aisle_eave, up = "x-", rise = arcade_x}),
		})
		local peak = base
		for z = -1, d do
			for x = -1, w do
				local y = field.height(x, z)
				if y and y > peak then peak = y end
			end
		end
		local function wall_top(x, z)
			return (field.height(x, z) or (base + 1)) - 1
		end

		-- The forecourt reaches three nodes clear of the gable end, because
		-- the entrance steps take two of them and the service steps on the
		-- long wall take the third: a walker leaving either door has to land
		-- on paving the part itself wrote, not on whatever the composition
		-- happens to put there.
		buf:clear(-3, 1, -3, w + 1, peak + 6, d + 1)
		buf:fill(-3, 0, -3, w + 1, 0, d + 1, paving(palette))
		skirt(buf, palette, -1, -1, w, d, 2, stone(palette))
		-- Podium and floor. The podium course is the signature material, so
		-- the hall reads as its race from the ground up; the floor above it
		-- is the citadel paving every court in the capital is laid with.
		buf:fill(0, 1, 0, w - 1, 1, d - 1, mark(palette))
		buf:fill(0, base, 0, w - 1, base, d - 1, paving(palette))
		-- The kerb of the podium: a signature slab skirt one cell proud of
		-- the wall, which is what stops the elevation meeting its apron in a
		-- single vertical line.
		for z = -1, d do
			for x = -1, w do
				if x == -1 or x == w or z == -1 or z == d then
					buf:put(x, 1, z, mark_slab(palette))
				end
			end
		end

		-- The outer shell: aisle walls and the two gable ends, each column
		-- carried to one node under the roof above it, with signature string
		-- courses at the plinth and at the springing.
		for z = 0, d - 1 do
			for x = 0, w - 1 do
				if x == 0 or x == w - 1 or z == 0 or z == d - 1 then
					for y = base + 1, wall_top(x, z) do
						local name = stone(palette)
						if y == base + 1 or y == lintel then
							name = mark(palette)
						end
						buf:put(x, y, z, name)
					end
				end
			end
		end

		-- The two arcades: a column every fourth bay from the floor to the
		-- springing, a signature lintel on top of them, and the clerestory
		-- wall carried on that lintel up to the nave's own eave. Between the
		-- columns the arcade is OPEN, which is what makes nave and aisle one
		-- room.
		local bays = 0
		for _, x in ipairs({arcade_x, right}) do
			for z = 1, d - 2 do
				if z % 4 == 0 then
					column(buf, palette, x, base + 1, arcade_head, z)
					bays = bays + 1
				end
				buf:put(x, lintel, z, mark(palette))
				for y = lintel + 1, wall_top(x, z) do
					buf:put(x, y, z, stone(palette))
				end
			end
		end

		-- Windows. Three bands, one per storey of the section: a pair of
		-- lights in every fourth aisle bay, a clerestory light over every
		-- arcade opening, and the rose over the great door.
		local slits = 0
		for z = 2, d - 3, 4 do
			for _, x in ipairs({0, w - 1}) do
				for y = base + 2, base + 3 do
					parts.pane(buf, palette, x, y, z, "z")
				end
				for _, frame in ipairs({z - 1, z + 1}) do
					for y = base + 1, wall_top(x, frame) do
						buf:put(x, y, frame, mark(palette))
					end
				end
			end
			-- The clerestory lights sit ABOVE the aisle roof, which reaches
			-- `aisle_eave + arcade_x` at the arcade line; a band any lower is
			-- a window looking into the roof beside it.
			for _, x in ipairs({arcade_x, right}) do
				for y = lintel + 4, lintel + 5 do
					parts.pane(buf, palette, x, y, z, "z")
				end
			end
		end
		-- The rose over the great door, and the three lancets over the
		-- throne, both framed in the signature material. The throne end is
		-- the elevation a district avenue looks at from behind; without its
		-- own light it was a blank gable the height of the nave.
		local door_x = spec.door_x or centre
		for x = door_x - 2, door_x + 3 do
			for y = base + 4, base + 8 do
				buf:put(x, y, 0, mark(palette))
			end
		end
		for x = door_x - 1, door_x + 2 do
			for y = base + 5, base + 7 do
				parts.pane(buf, palette, x, y, 0, "x")
			end
		end
		-- and a single light carried on up the gable, so the twelve courses
		-- of wall above the rose are not one blank triangle.
		for y = base + 9, base + 12 do
			buf:put(door_x - 1, y, 0, mark(palette))
			buf:put(door_x + 2, y, 0, mark(palette))
			parts.pane(buf, palette, door_x, y, 0, "x")
			parts.pane(buf, palette, door_x + 1, y, 0, "x")
		end
		for x = centre - 3, centre + 3 do
			for y = base + 4, base + 10 do
				buf:put(x, y, d - 1, mark(palette))
			end
		end
		for _, x in ipairs({centre - 2, centre, centre + 2}) do
			for y = base + 5, base + 9 do
				parts.pane(buf, palette, x, y, d - 1, "x")
			end
		end

		-- Buttresses against both aisle walls, every sixth bay. They stop one
		-- course under the eave, which then lands on them.
		local buttresses = 0
		for z = 4, d - 5, 6 do
			for _, x in ipairs({-1, w}) do
				for y = 1, aisle_eave - 1 do
					buf:put(x, y, z, stone(palette))
				end
				buttresses = buttresses + 1
			end
		end

		-- The great door and its forecourt steps.
		buf:clear(door_x, base + 1, 0, door_x + 1, base + 2, 0)
		local partner_x = parts.double_door(buf, palette, door_x, base + 1, 0, 0)
		doors[#doors + 1] = {x = door_x, y = base + 1, z = 0, face = 0}
		doors[#doors + 1] = {x = partner_x, y = base + 1, z = 0, face = 0}
		buf:fill(door_x - 2, 1, -1, door_x + 3, 1, -1, mark(palette))
		for x = door_x - 2, door_x + 3 do
			parts.stair(buf, x, 1, -2, mark_stair(palette), 0)
			parts.stair(buf, x, 2, -1, mark_stair(palette), 0)
		end
		for _, x in ipairs({door_x - 2, door_x + 3}) do
			parts.wall_torch(buf, palette, x, base + 3, -1, 0, 0, 1)
			lights[#lights + 1] = {x = x, y = base + 3, z = -1}
		end

		-- The service door: a single leaf in the west aisle wall at the
		-- throne end, for the household rather than for the court. Its bay is
		-- chosen clear of the buttress rhythm and of the window rhythm.
		local service_z = spec.service_z or (d - 8)
		buf:clear(0, base + 1, service_z, 0, base + 2, service_z)
		parts.door(buf, palette, 0, base + 1, service_z, 1, false)
		doors[#doors + 1] = {x = 0, y = base + 1, z = service_z, face = 1}
		buf:put(-1, 1, service_z, paving(palette))
		parts.stair(buf, -1, base, service_z, mark_stair(palette), 1)
		parts.stair(buf, -2, base - 1, service_z, mark_stair(palette), 1)

		-- The carpet approach, three cells wide from the door to the foot of
		-- the dais, written INTO the floor course so it is a full node and
		-- nothing stands half a node above it.
		local dais_z = spec.dais_z or (d - 9)
		for z = 1, dais_z - 1 do
			for x = centre - 1, centre + 1 do
				buf:put(x, base, z, palette.node("rug_accent"))
			end
		end

		-- The dais: three steps of signature masonry with stair risers, the
		-- throne on top under a canopy of two columns and a lintel, and the
		-- royal hangings on the end wall behind it.
		local steps = {{7, 0}, {5, 1}, {3, 2}}
		for step_index, step in ipairs(steps) do
			local reach, lift = step[1], step[2]
			local y = base + 1 + lift
			buf:fill(centre - reach, y, dais_z + step_index - 1,
				centre + reach, y, d - 2, mark(palette))
			for x = centre - reach, centre + reach do
				parts.stair(buf, x, y, dais_z + step_index - 2,
					mark_stair(palette), 0)
			end
		end
		local dais_top = base + 3
		local throne_z = d - 3
		-- A chair alone on a fifteen-node dais is a chair nobody can find.
		-- The seat gets a screen of signature masonry behind it, two courses
		-- taller than the man sitting in it, which is what makes the throne
		-- read as the end of the approach rather than as furniture.
		for x = centre - 1, centre + 1 do
			for y = dais_top + 1, dais_top + 3 do
				buf:put(x, y, throne_z + 1, mark(palette))
			end
		end
		buf:put(centre, dais_top + 4, throne_z + 1, mark_slab(palette))
		buf:put(centre, dais_top + 1, throne_z,
			palette.maybe("throne") or palette.node("seat"), 2)
		for _, x in ipairs({centre - 2, centre + 2}) do
			column(buf, palette, x, dais_top + 1, dais_top + 4, throne_z)
		end
		for x = centre - 2, centre + 2 do
			buf:put(x, dais_top + 5, throne_z, mark(palette))
		end
		-- The hangings touch the end wall across a face, which is what holds
		-- a column of cloth up.
		for _, x in ipairs({centre - 3, centre + 3}) do
			for y = base + 5, base + 8 do
				buf:put(x, y, d - 2, palette.node("rug_accent"))
			end
			buf:put(x, base + 9, d - 2, palette.node("rug"))
		end
		-- The two standing lights of the throne, on the top step of the dais
		-- itself: the step reaches centre +- 3, so a light at +- 4 would have
		-- stood on the step below and, on the render, in mid air.
		for _, x in ipairs({centre - 3, centre + 3}) do
			parts.floor_torch(buf, palette, x, dais_top + 1, throne_z - 1)
			lights[#lights + 1] = {x = x, y = dais_top + 1, z = throne_z - 1}
		end

		-- The aisles: benches facing the nave, a brazier at the foot of every
		-- other arcade column, and lamps along both aisle walls.
		local room = {x1 = 1, z1 = 1, x2 = w - 2, z2 = d - 2,
			y = base, h = base + 12}
		local benches = 0
		for z = 8, dais_z - 4, 8 do
			interiors.settle(buf, parts, palette, room, 1, z, "z", 3, 1)
			interiors.settle(buf, parts, palette, room, w - 2, z, "z", 3, 3)
			benches = benches + 2
		end
		for z = 8, d - 9, 8 do
			for _, x in ipairs({arcade_x - 1, right + 1}) do
				parts.floor_torch(buf, palette, x, base + 1, z)
				lights[#lights + 1] = {x = x, y = base + 1, z = z}
			end
		end
		for z = 6, d - 7, 8 do
			interiors.wall_light(buf, parts, palette, room, 1, base + 3, z,
				lights)
			interiors.wall_light(buf, parts, palette, room, w - 2, base + 3, z,
				lights)
		end

		-- Sockets. The king stands on the dais in front of his seat; two of
		-- his guards stand on the first dais step and two inside the great
		-- door, with the travel waypoint on the carpet between them.
		socket(sockets, "king", "king", centre, dais_top + 1, throne_z - 1, 2)
		socket(sockets, "throne_guard_west", "guard_post",
			centre - 7, base + 2, dais_z + 2, 2)
		socket(sockets, "throne_guard_east", "guard_post",
			centre + 7, base + 2, dais_z + 2, 2)
		socket(sockets, "door_guard_west", "guard_post",
			centre - 3, base + 1, 2, 0)
		socket(sockets, "door_guard_east", "guard_post",
			centre + 4, base + 1, 2, 0)
		socket(sockets, "hall_waypoint", "waypoint", centre, base + 1, 4, 0)
		socket(sockets, "hall_idle_west", "idle", 2, base + 1, 10, 1,
			{tags = {"bench"}})
		socket(sockets, "hall_idle_east", "idle", w - 3, base + 1, 10, 3,
			{tags = {"bench"}})
		socket(sockets, "hall_idle_service", "idle", 2, base + 1, service_z, 1,
			{tags = {"door"}})

		roofs.raster(buf, spec.roof_palette or palette, field)

		-- The four corner turrets, written AFTER the roof: they rise through
		-- the aisle lean-to, so a turret laid before the rasteriser would
		-- have three courses cut out of it where the roof passes.
		--
		-- They are HOLLOW above the hall floor and they carry four storeys
		-- of loopholes and a corbelled crown. The first version was three by
		-- three of solid masonry twenty-two courses high with two slits in
		-- it, and the render read as four chimneys: at this scale what makes
		-- a turret a turret is the openings up its height and the course
		-- that oversails at the top, not its plan.
		local turret_top = nave_eave + 6
		local merlons, corbels = 0, 0
		local turrets = {{0, 0, -1, -1}, {w - 3, 0, 1, -1},
			{0, d - 3, -1, 1}, {w - 3, d - 3, 1, 1}}
		for _, corner in ipairs(turrets) do
			for z = corner[2], corner[2] + 2 do
				for x = corner[1], corner[1] + 2 do
					local shaft = (x == corner[1] + 1) and (z == corner[2] + 1)
					for y = 1, turret_top do
						local name = stone(palette)
						if y == base + 1 or y == lintel or y == turret_top then
							name = mark(palette)
						end
						if shaft and y > base and y < turret_top then
							buf:clear(x, y, z, x, y, z)
						else
							buf:put(x, y, z, name)
						end
					end
					if (x + z) % 2 == 0 then
						buf:put(x, turret_top + 1, z, stone(palette))
						buf:put(x, turret_top + 2, z, mark_slab(palette))
						merlons = merlons + 1
					end
				end
			end
			-- The corbel table: a course oversailing the two OUTWARD faces,
			-- one node clear of the shaft. That overhang is what throws a
			-- shadow across the top of a turret and stops it reading as a
			-- stack of masonry.
			local ox = (corner[3] < 0) and (corner[1] - 1) or (corner[1] + 3)
			local oz = (corner[4] < 0) and (corner[2] - 1) or (corner[2] + 3)
			for step = 0, 2 do
				buf:put(ox, turret_top - 1, corner[2] + step, mark_slab(palette))
				buf:put(corner[1] + step, turret_top - 1, oz, mark_slab(palette))
				corbels = corbels + 2
			end
			buf:put(ox, turret_top - 1, oz, mark_slab(palette))
			corbels = corbels + 1
		end
		-- Loopholes in the outward faces of every turret, four storeys up.
		for _, face in ipairs({{0, 1, -1, 0}, {1, 0, 0, -1},
				{w - 1, 1, 1, 0}, {w - 2, 0, 0, -1},
				{0, d - 2, -1, 0}, {1, d - 1, 0, 1},
				{w - 1, d - 2, 1, 0}, {w - 2, d - 1, 0, 1}}) do
			for _, y in ipairs({base + 4, base + 8, base + 12, base + 16}) do
				if arrowslit(buf, palette, face[1], y, face[2],
						face[3], face[4]) then
					slits = slits + 1
				end
			end
		end

		-- The ridge lantern over the dais end: the library's own belfry,
		-- stamped on the ridge plateau, whose five by five floor closes the
		-- hole it stands over. Without it the nave roof is one unbroken
		-- plane thirty-nine nodes long, which is what the first render of
		-- this hall was.
		-- `peak` and not `top_of(buf)`: the lantern stands on the ROOF, and
		-- the highest cell in the buffer by this point is a turret merlon
		-- cap, which would have hung it a course above the ridge.
		parts.stamp(buf, buildings.belfry(palette,
			{roof_palette = spec.roof_palette, height = 4}),
			centre - 2, peak, d - 10, 0)
		bear_bell(buf, palette, centre - 2, peak, d - 10, 4)

		-- Dormers. The review of the second render was right that the nave
		-- roof is one unbroken plane thirty-nine nodes long on each side,
		-- and that the ridge lantern only interrupts the ridge. Four
		-- lucarnes per slope, three wide and three tall, each standing on
		-- the course of roof it interrupts: a signature cheek, a light and a
		-- slab hood.
		local dormers = 0
		for _, x in ipairs({arcade_x + 2, right - 2}) do
			for z = 9, d - 10, 8 do
				local h = field.height(x, z)
				if h then
					for offset = -1, 1 do
						buf:put(x, h + 1, z + offset, mark(palette))
						buf:put(x, h + 3, z + offset,
							palette.node("roof_slab"))
					end
					buf:put(x, h + 2, z - 1, mark(palette))
					buf:put(x, h + 2, z + 1, mark(palette))
					parts.pane(buf, palette, x, h + 2, z, "z")
					dormers = dormers + 1
				end
			end
		end

		local inside = spec.inside or {x = centre, y = base + 1, z = 6}
		buf:clear(inside.x, inside.y, inside.z, inside.x, inside.y + 1, inside.z)

		return finish(buf, w, d, top_of(buf), {
			doors = doors,
			lights = lights,
			sockets = sockets,
			inside = {{x = inside.x, y = inside.y, z = inside.z, id = spec.id}},
			-- The room's `top` is the AISLE head, not the nave's. A room
			-- corner's top is the course above which a roof has to cover
			-- every interior column, and in a basilica the lowest roofed
			-- level is the aisle: naming the nave head instead declares the
			-- aisles open to the sky when they are roofed four courses
			-- lower.
			room_corner = {
				{x = 1, y = base, z = 1, top = aisle_eave, closed = true,
					id = spec.id},
				{x = w - 2, y = base, z = d - 2},
			},
		}, {arcade_bays = bays, arrowslits = slits, merlons = merlons,
			buttresses = buttresses, benches = benches,
			dormers = dormers, corbels = corbels})
	end

	-- -------------------------------------------------------------------
	-- 2. the curtain wall
	-- -------------------------------------------------------------------

	-- A linear segment of city wall: rubble core between two masonry faces,
	-- a three-wide walkway at y = 6, a crenellated outer parapet and a solid
	-- inner one, loopholes in the outer face, and -- where the composition
	-- asks for it -- an internal flight from the ground to the walkway.
	--
	-- Every cell lies inside x 0..len-1 and z 0..4, so consecutive segments
	-- ABUT exactly: chaining is stamping the same part at len-node intervals.
	-- `spec.phase` carries the merlon rhythm across the joint, so a chained
	-- wall does not restart its crenellation at every segment.
	--
	-- Extent: len x 5, y -2..9.
	function M.wall_segment(palette, spec)
		local len = spec.len or 8
		local phase = spec.phase or 0
		local thick = 5
		local walk = 6
		local buf = parts.buffer()
		local lights, doors, sockets = {}, {}, {}
		if len < 4 then error("wp13 capitals: wall segment too short", 0) end

		buf:clear(0, 1, 0, len - 1, 10, thick - 1)
		buf:fill(0, -2, 0, len - 1, 0, thick - 1, stone(palette))
		-- Core and faces.
		buf:fill(0, 1, 1, len - 1, walk - 1, thick - 2, spoil(palette))
		for y = 1, walk do
			for x = 0, len - 1 do
				local name = stone(palette)
				if y == 3 then name = mark(palette) end
				buf:put(x, y, 0, name)
				buf:put(x, y, thick - 1, name)
			end
		end
		buf:fill(0, walk, 1, len - 1, walk, thick - 2, paving(palette))

		-- Loopholes in the outer face, on the same four-node rhythm as the
		-- merlons above them so the wall reads as one piece of masonry.
		local slits = 0
		for x = 0, len - 1 do
			if (x + phase) % 4 == 2 then
				if arrowslit(buf, palette, x, 4, 0, 0, -1) then
					slits = slits + 1
				end
			end
		end

		-- Parapets: the outer one crenellated two courses high and capped
		-- with a signature slab on every merlon; the inner one a solid
		-- waist-high course, because a walkway with a fall on both sides is
		-- not a walkway.
		local merlons = 0
		for x = 0, len - 1 do
			buf:put(x, walk + 1, thick - 1, stone(palette))
			local merlon = (x + phase) % 4
			if merlon == 0 or merlon == 1 then
				buf:put(x, walk + 1, 0, stone(palette))
				buf:put(x, walk + 2, 0, stone(palette))
				buf:put(x, walk + 3, 0, mark_slab(palette))
				merlons = merlons + 1
			else
				buf:put(x, walk + 1, 0, stone(palette))
			end
		end

		-- The optional stair chamber: a run up the inside of the core with a
		-- doorway in the inner face.
		--
		-- A flight from a floor at y = f to a floor at y = g carries
		-- g - f treads, at y = f + 1 .. g, and the TOP one replaces a cell of
		-- the upper floor. Stopping a tread short leaves the climber's feet
		-- one whole node below the deck he is trying to reach -- a jump, not
		-- a step -- which is what the first five-tread version of every
		-- flight in this file did. Here: the landing is the wall's own base
		-- course at y = 0 and the walkway is at y = 6, so six treads,
		-- x = 2..7, and the last of them stands in the walkway.
		if spec.stair then
			if len < 10 then
				error("wp13 capitals: a wall stair needs ten nodes", 0)
			end
			-- A LANDING behind the door, then the treads. The first version
			-- started the flight in the doorway itself, so a walker stepping
			-- out of the door put his foot on the raised half of a stair
			-- rather than on a floor.
			buf:clear(1, 1, thick - 2, 7, walk + 2, thick - 2)
			for run = 1, walk do
				parts.stair(buf, run + 1, run, thick - 2,
					stone_stair(palette), 1)
			end
			buf:clear(1, 1, thick - 1, 1, 2, thick - 1)
			parts.door(buf, palette, 1, 1, thick - 1, 2, false)
			doors[#doors + 1] = {x = 1, y = 1, z = thick - 1, face = 2}
			parts.wall_torch(buf, palette, 1, 3, thick - 2, -1, 0, 0)
			lights[#lights + 1] = {x = 1, y = 3, z = thick - 2}
		end

		-- Lamps along the walkway, on the inner face of the OUTER parapet.
		-- That face is the only masonry at lamp height that is there in
		-- every segment: the inner parapet is a single waist course, and the
		-- deck itself is cut away by the stair chamber below.
		for x = 2, len - 2, 4 do
			parts.wall_torch(buf, palette, x, walk + 1, 1, 0, 0, -1)
			lights[#lights + 1] = {x = x, y = walk + 1, z = 1}
		end

		local group = spec.patrol_group or "rampart"
		local order = spec.order or 1
		patrol(sockets, (spec.id or "wall") .. "_patrol_a", group, order,
			1, walk + 1, 2, 1)
		patrol(sockets, (spec.id or "wall") .. "_patrol_b", group, order + 1,
			len - 2, walk + 1, 2, 3)

		return finish(buf, len, thick, top_of(buf), {
			doors = doors,
			lights = lights,
			sockets = sockets,
			inside = {},
			room_corner = {},
		}, {merlons = merlons, arrowslits = slits})
	end

	-- -------------------------------------------------------------------
	-- 3. the corner tower
	-- -------------------------------------------------------------------

	-- A nine by nine drum at the corner of a curtain wall: a ground chamber
	-- with a door, two straight flights to the rampart floor and on to the
	-- fighting top, rampart openings in two adjacent faces at the height of
	-- the walkway, loopholes on all four, and a crenellated crown.
	--
	-- Extent: 9 x 9, y -2..15.
	function M.wall_tower(palette, spec)
		local side = 9
		local walk = 6
		local head = 12
		local buf = parts.buffer()
		local lights, doors, sockets = {}, {}, {}
		local last = side - 1

		buf:clear(0, 1, 0, last, 16, last)
		buf:fill(0, -2, 0, last, 0, last, stone(palette))
		for y = 1, head do
			for z = 0, last do
				for x = 0, last do
					if x == 0 or x == last or z == 0 or z == last then
						local name = stone(palette)
						if y == 4 or y == 8 or y == head then
							name = mark(palette)
						end
						buf:put(x, y, z, name)
					end
				end
			end
		end

		-- The two floors and the two flights.
		--
		-- Both flights run along X, against the two faces the rampart does
		-- NOT arrive at. That is not a stylistic choice: the rampart enters
		-- this tower through the z = 0 face and leaves through the x = 0
		-- face, so a walker turning the corner crosses the whole of the
		-- z = 3..5 band, and a stairwell cut through the rampart floor
		-- anywhere in that band is a hole in the wall walk. The first
		-- version ran both flights along Z at x = 1 and x = 7 and cut
		-- exactly that hole.
		--
		-- Six treads each (`walk` from the ground floor to the rampart
		-- floor, `head - walk` from there to the fighting top), the last of
		-- each standing in the floor it lands on.
		buf:fill(1, walk, 1, last - 1, walk, last - 1, paving(palette))
		buf:fill(1, head, 1, last - 1, head, last - 1, paving(palette))
		-- The stairwell of each flight is cut over its OWN treads only: the
		-- cell beyond the top tread is the landing, and clearing that as
		-- well leaves the climber stepping off his last tread into a hole.
		buf:clear(1, 1, last - 1, walk, walk + 2, last - 1)
		buf:clear(1, walk + 1, 1, walk, head + 2, 1)
		for run = 1, walk do
			parts.stair(buf, run, run, last - 1, stone_stair(palette), 1)
			parts.stair(buf, run, walk + run, 1, stone_stair(palette), 1)
		end

		-- Rampart openings, three wide and two high, in the two faces a
		-- chained wall arrives at. They line up with the three-wide walkway
		-- of `wall_segment`, which sits two nodes in from the face of a
		-- five-deep wall centred on this nine-deep tower.
		for step = 3, 5 do
			buf:clear(step, walk + 1, 0, step, walk + 2, 0)
			buf:clear(0, walk + 1, step, 0, walk + 2, step)
		end

		-- The ground door, in the face that looks into the city.
		buf:clear(4, 1, last, 4, 2, last)
		parts.door(buf, palette, 4, 1, last, 2, false)
		doors[#doors + 1] = {x = 4, y = 1, z = last, face = 2}

		-- Loopholes: one per face at the height of the ground chamber and
		-- one per face above the rampart floor.
		local slits = 0
		local faces = {{4, 0, 0, -1}, {4, last, 0, 1}, {0, 4, -1, 0},
			{last, 4, 1, 0}}
		for _, face in ipairs(faces) do
			for _, y in ipairs({3, 9}) do
				if not (face[1] == 4 and face[2] == last and y == 3) then
					if arrowslit(buf, palette, face[1], y, face[2],
							face[3], face[4]) then
						slits = slits + 1
					end
				end
			end
		end

		-- The crown: a parapet ring, merlons on the diagonal rhythm and a
		-- signature cap on each of them.
		local merlons = 0
		for z = 0, last do
			for x = 0, last do
				if x == 0 or x == last or z == 0 or z == last then
					buf:put(x, head + 1, z, stone(palette))
					if (x + z) % 2 == 0 then
						buf:put(x, head + 2, z, stone(palette))
						buf:put(x, head + 3, z, mark_slab(palette))
						merlons = merlons + 1
					end
				end
			end
		end

		-- Light in the ground chamber and on the fighting top.
		parts.wall_torch(buf, palette, 2, 3, 1, 0, 0, -1)
		lights[#lights + 1] = {x = 2, y = 3, z = 1}
		for _, corner in ipairs({{2, 2}, {last - 2, last - 2}}) do
			parts.floor_torch(buf, palette, corner[1], head + 1, corner[2])
			lights[#lights + 1] = {x = corner[1], y = head + 1, z = corner[2]}
		end

		local id = spec.id or "tower"
		socket(sockets, id .. "_top", "guard_post", 4, head + 1, 4, 2)
		patrol(sockets, id .. "_rampart", spec.patrol_group or "rampart",
			spec.order or 1, 4, walk + 1, 4, 2)
		socket(sockets, id .. "_gate_idle", "idle", 6, 1, 6, 2,
			{tags = {"door"}})

		return finish(buf, side, side, top_of(buf), {
			doors = doors,
			lights = lights,
			sockets = sockets,
			inside = {{x = 4, y = walk + 1, z = 4, id = spec.id}},
			room_corner = {
				{x = 1, y = 0, z = 1, top = walk - 1, closed = true,
					id = spec.id},
				{x = last - 1, y = 0, z = last - 1},
			},
		}, {merlons = merlons, arrowslits = slits})
	end

	-- -------------------------------------------------------------------
	-- 4. the gatehouse
	-- -------------------------------------------------------------------

	-- Two piers carrying a chamber over a five-wide passage, with the street
	-- running clean through it: x 4..8 is open air from the ground course to
	-- the springing of the arch, which is the width and the headroom a city
	-- avenue needs (contract section 2.1, the 32-node gate corridor). Each
	-- pier holds a guard chamber with its own door to the street.
	--
	-- The chamber above the passage is a RAMPART ROOM, not a dead end. Its
	-- floor is the wall walk's own level and both end faces carry an opening
	-- three wide and two high, so a walker on the curtain wall walks through
	-- the gate rather than stopping at it. The first version walled those
	-- two faces solid and the wall walk dead-ended at every gate in the city.
	-- The openings sit at z 2..4: a five-deep wall centred on this
	-- seven-deep gatehouse is inset one node, so its z 1..3 walkway arrives
	-- at z 2..4 (the corner tower is nine deep, so the same walkway arrives
	-- there at z 3..5).
	--
	-- Nothing cuts that floor. There is deliberately NO flight from the
	-- ground to the chamber: any stairwell wide enough to climb would be a
	-- hole in the wall walk, and a gate tower is reached from the rampart,
	-- which is what the rampart is for. The fighting deck above is reached
	-- from the chamber by a flight in the city-side row, clear of the
	-- through-band.
	--
	-- Extent: 13 x 7, y -2..14. The deck is y = 11 and its merlons y 12..14,
	-- three courses above the curtain wall's own crown at y 7..9.
	function M.gatehouse(palette, spec)
		local w, d = 13, 7
		local gate_x0, gate_x1 = 4, 8
		local buf = parts.buffer()
		local lights, doors, sockets = {}, {}, {}

		buf:clear(0, 1, 0, w - 1, 14, d - 1)
		buf:fill(0, -2, 0, w - 1, 0, d - 1, stone(palette))
		buf:fill(gate_x0, 0, 0, gate_x1, 0, d - 1, paving(palette))

		-- The piers, solid masonry with a signature band, hollowed out for
		-- one guard chamber each.
		for z = 0, d - 1 do
			for x = 0, w - 1 do
				if x < gate_x0 or x > gate_x1 then
					for y = 1, 6 do
						buf:put(x, y, z, (y == 3) and mark(palette) or
							stone(palette))
					end
				end
			end
		end
		buf:clear(1, 1, 1, 2, 3, 5)
		buf:clear(w - 3, 1, 1, w - 2, 3, 5)
		buf:fill(1, 0, 1, 2, 0, 5, palette.node("floor"))
		buf:fill(w - 3, 0, 1, w - 2, 0, 5, palette.node("floor"))

		-- The passage walls carry the loopholes that cover the road, and the
		-- arch springs from a stone stair on each side.
		local slits = 0
		for _, z in ipairs({1, d - 2}) do
			if arrowslit(buf, palette, gate_x0 - 1, 3, z, 1, 0) then
				slits = slits + 1
			end
			if arrowslit(buf, palette, gate_x1 + 1, 3, z, -1, 0) then
				slits = slits + 1
			end
		end
		for z = 0, d - 1 do
			parts.stair(buf, gate_x0, 5, z, stone_stair(palette), 1)
			parts.stair(buf, gate_x1, 5, z, stone_stair(palette), 3)
			for x = gate_x0, gate_x1 do
				buf:put(x, 6, z, stone(palette))
			end
		end

		-- The chamber floor: unbroken, because it is the wall walk.
		buf:fill(0, 6, 0, w - 1, 6, d - 1, palette.node("floor"))

		-- The chamber: walls, windows on the city face, loopholes on the
		-- field face.
		for z = 0, d - 1 do
			for x = 0, w - 1 do
				if x == 0 or x == w - 1 or z == 0 or z == d - 1 then
					for y = 7, 10 do
						buf:put(x, y, z, (y == 10) and mark(palette) or
							stone(palette))
					end
				end
			end
		end
		for _, x in ipairs({3, 6, 9}) do
			if arrowslit(buf, palette, x, 8, 0, 0, -1) then
				slits = slits + 1
			end
			for y = 8, 9 do
				parts.pane(buf, palette, x, y, d - 1, "x")
			end
		end

		-- The rampart openings, and the flight from the chamber to the deck.
		-- Five treads, y 7..11, the last of them standing in the deck, in the
		-- city-side row so the through-band z 2..4 stays clear.
		for step = 2, 4 do
			buf:clear(0, 7, step, 0, 8, step)
			buf:clear(w - 1, 7, step, w - 1, 8, step)
		end

		-- The deck and its crenellation.
		buf:fill(0, 11, 0, w - 1, 11, d - 1, paving(palette))
		for run = 0, 4 do
			buf:clear(2 + run, 7 + run, d - 2, 2 + run, 9 + run, d - 2)
			parts.stair(buf, 2 + run, 7 + run, d - 2, stone_stair(palette), 1)
		end
		local merlons = 0
		for z = 0, d - 1 do
			for x = 0, w - 1 do
				if x == 0 or x == w - 1 or z == 0 or z == d - 1 then
					-- Two courses and a cap, the same crenellation the corner
					-- tower and the curtain wall carry. A single course with
					-- a slab on every other cell is a dentil band, not a
					-- battlement, which is what the first render showed.
					buf:put(x, 12, z, stone(palette))
					if (x + z) % 2 == 0 then
						buf:put(x, 13, z, stone(palette))
						buf:put(x, 14, z, mark_slab(palette))
						merlons = merlons + 1
					end
				end
			end
		end

		-- The two chamber doors, on the city face of each pier.
		for _, entry in ipairs({{1, "west"}, {w - 2, "east"}}) do
			local x = entry[1]
			buf:clear(x, 1, d - 1, x, 2, d - 1)
			parts.door(buf, palette, x, 1, d - 1, 2, false)
			doors[#doors + 1] = {x = x, y = 1, z = d - 1, face = 2}
		end

		-- Lamps: one in each guard chamber and one on each gate jamb.
		for _, x in ipairs({1, w - 2}) do
			parts.wall_torch(buf, palette, x, 3, 1, 0, 0, -1)
			lights[#lights + 1] = {x = x, y = 3, z = 1}
		end
		-- The gate jambs. The step is the one FROM the torch TO the pier it
		-- hangs on, so the west jamb points at x - 1 and the east at x + 1;
		-- the other sign hangs both of them in the middle of the road.
		for _, entry in ipairs({{gate_x0, -1}, {gate_x1, 1}}) do
			parts.wall_torch(buf, palette, entry[1], 4, 1, entry[2], 0, 0)
			lights[#lights + 1] = {x = entry[1], y = 4, z = 1}
		end

		local id = spec.id or "gate"
		socket(sockets, id .. "_post_west", "guard_post",
			gate_x0, 1, 1, 2)
		socket(sockets, id .. "_post_east", "guard_post",
			gate_x1, 1, 1, 2)
		-- The rampart waypoint is in the WALL's loop, at the wall's own
		-- height, because the wall walk runs through this chamber. The deck
		-- is five courses higher and is reached only by the flight inside,
		-- so it is a loop of its own: a patrol that mixed the two would ask
		-- an NPC to walk from y = 7 to y = 12 with nothing between.
		patrol(sockets, id .. "_rampart", spec.patrol_group or "rampart",
			spec.order or 1, 6, 7, 3, 2)
		patrol(sockets, id .. "_deck",
			spec.deck_group or (id .. "_deck"), 1, 6, 12, 3, 2)
		socket(sockets, id .. "_idle_west", "idle", 1, 1, 4, 2,
			{tags = {"fire"}})
		socket(sockets, id .. "_idle_east", "idle", w - 2, 1, 4, 2,
			{tags = {"fire"}})

		return finish(buf, w, d, top_of(buf), {
			doors = doors,
			lights = lights,
			sockets = sockets,
			inside = {{x = 1, y = 1, z = 3, id = spec.id}},
			room_corner = {
				{x = 1, y = 0, z = 1, top = 3, closed = true, id = spec.id},
				{x = 2, y = 0, z = 5},
			},
		}, {merlons = merlons, arrowslits = slits})
	end

	-- -------------------------------------------------------------------
	-- 5. the colonnade
	-- -------------------------------------------------------------------

	-- An open-sided walk: two rows of columns on a paved terrace under a
	-- flat cornice, with a solid pier every third bay because a column is a
	-- nodebox and nothing may hang a lamp on one.
	--
	-- Extent: len x 5 plus a one-node apron and cornice oversail, y 0..7.
	function M.colonnade(palette, spec)
		local len = spec.len or 15
		local d = spec.d or 5
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if len < 7 then error("wp13 capitals: colonnade too short", 0) end

		buf:clear(-1, 1, -1, len, 8, d)
		buf:fill(-1, 0, -1, len, 0, d, paving(palette))
		dressing.inlay(buf, palette, 0, 0, len - 1, d - 1, "plaza_edge")

		local piers, columns = 0, 0
		for x = 0, len - 1, 2 do
			for _, z in ipairs({0, d - 1}) do
				if x % 6 == 0 then
					for y = 1, 4 do buf:put(x, y, z, stone(palette)) end
					piers = piers + 1
				else
					column(buf, palette, x, 1, 4, z)
					columns = columns + 1
				end
			end
		end
		-- Architrave, cornice and the oversailing drip course.
		for x = 0, len - 1 do
			for _, z in ipairs({0, d - 1}) do
				buf:put(x, 5, z, mark(palette))
			end
		end
		buf:fill(0, 6, 0, len - 1, 6, d - 1, paving(palette))
		for x = -1, len do
			buf:put(x, 7, -1, mark_slab(palette))
			buf:put(x, 7, d, mark_slab(palette))
		end
		for z = 0, d - 1 do
			buf:put(-1, 7, z, mark_slab(palette))
			buf:put(len, 7, z, mark_slab(palette))
		end

		-- Benches against the piers, and a lamp on every pier that has one.
		local benches = 0
		for x = 0, len - 1, 6 do
			for _, z in ipairs({0, d - 1}) do
				local step = (z == 0) and 1 or -1
				if x + 1 <= len - 1 then
					parts.seat(buf, palette, x + 1, 1, z,
						parts.step_facedir(0, step))
					benches = benches + 1
					parts.wall_torch(buf, palette, x + 1, 3, z, -1, 0, 0)
					lights[#lights + 1] = {x = x + 1, y = 3, z = z}
				end
			end
		end

		local id = spec.id or "colonnade"
		socket(sockets, id .. "_idle_a", "idle", 2, 1, 1, 0, {tags = {"bench"}})
		socket(sockets, id .. "_idle_b", "idle", len - 3, 1, d - 2, 2,
			{tags = {"bench"}})
		patrol(sockets, id .. "_walk", spec.patrol_group or "civic",
			spec.order or 1, math.floor(len / 2), 1, math.floor(d / 2), 1)

		return finish(buf, len, d, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {},
			room_corner = {},
		}, {piers = piers, columns = columns, benches = benches})
	end

	-- -------------------------------------------------------------------
	-- 6. the market square
	-- -------------------------------------------------------------------

	-- A paved square with four awninged stalls round a central kerb, benches
	-- and planters along the edges and a lamp at each corner. The stalls are
	-- the library's own `dressing.stall`, so a capital market is built out of
	-- the same booth a start market is.
	--
	-- Extent: size x size, y 0..7; the default 25 is inside the 32-node plot.
	function M.market_square(palette, spec)
		local size = spec.size or 25
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if size < 17 then error("wp13 capitals: market square too small", 0) end
		local last = size - 1
		local centre = math.floor(last / 2)

		buf:clear(0, 1, 0, last, 8, last)
		buf:fill(0, 0, 0, last, 0, last, palette.node("plaza"))
		dressing.inlay(buf, palette, 0, 0, last, last, "plaza_edge")
		band(buf, 3, 3, last - 3, last - 3, paving(palette))
		for step = 0, last do
			buf:put(centre, 0, step, paving(palette))
			buf:put(step, 0, centre, paving(palette))
		end

		-- Four stalls, one per quadrant, each looking at the crossing.
		-- A booth is three by three and every one of its nine cells is taken
		-- -- four posts, a three-cell counter, a crate and a bale -- so the
		-- trader stands one cell OUTSIDE it, on the side away from the
		-- crossing and still under the canopy, looking back at the square.
		local stalls = {
			{x = 4, z = 4, face = 1, vz = 3, vface = 0, kind = "race"},
			{x = last - 6, z = 4, face = 3, vz = 3, vface = 0,
				kind = "general"},
			{x = 4, z = last - 6, face = 1, vz = last - 3, vface = 2,
				kind = "general"},
			{x = last - 6, z = last - 6, face = 3, vz = last - 3, vface = 2,
				kind = "race"},
		}
		local id = spec.id or "market"
		for index, stall in ipairs(stalls) do
			dressing.stall(buf, palette, stall.x, stall.z, stall.face)
			dressing.crates(buf, palette, stall.x - 1, stall.vz, stall.vface)
			socket(sockets, id .. "_vendor_" .. index, "vendor",
				stall.x + 1, 1, stall.vz, stall.vface, {kind = stall.kind})
		end

		-- The market cross at the crossing. The first render of this square
		-- was four booths round thirteen by thirteen nodes of bare paving
		-- with a signpost on it: a market needs something at its centre to
		-- stand round, and a stepped cross is what a market square has.
		buf:fill(centre - 2, 1, centre - 2, centre + 2, 1, centre + 2,
			mark(palette))
		buf:fill(centre - 1, 2, centre - 1, centre + 1, 2, centre + 1,
			mark(palette))
		column(buf, palette, centre, 3, 6, centre)
		buf:put(centre, 7, centre, mark_slab(palette))
		for _, corner in ipairs({{-2, -2}, {2, -2}, {-2, 2}, {2, 2}}) do
			parts.floor_torch(buf, palette, centre + corner[1], 2,
				centre + corner[2])
			lights[#lights + 1] = {x = centre + corner[1], y = 2,
				z = centre + corner[2]}
		end

		-- Benches and planters round the rim, goods stacked beside every
		-- booth, and a lamp at each corner and each gate of the square.
		local benches = 0
		for _, edge in ipairs({{2, "z"}, {last - 2, "z"}}) do
			for z = 5, last - 5, 6 do
				local face = (edge[1] == 2) and 1 or 3
				parts.seat(buf, palette, edge[1], 1, z, face)
				parts.seat(buf, palette, edge[1], 1, z + 1, face)
				benches = benches + 2
			end
		end
		for _, edge in ipairs({2, last - 2}) do
			for x = 5, last - 5, 6 do
				local face = (edge == 2) and 0 or 2
				parts.seat(buf, palette, x, 1, edge, face)
				parts.seat(buf, palette, x + 1, 1, edge, face)
				benches = benches + 2
			end
		end
		dressing.planter(buf, palette, 1, 1, 1, 3)
		dressing.planter(buf, palette, last - 1, last - 3, last - 1, last - 1)
		dressing.planter(buf, palette, 1, last - 3, 1, last - 1)
		dressing.planter(buf, palette, last - 1, 1, last - 1, 3)
		for _, spot in ipairs({{2, 2}, {last - 2, 2}, {2, last - 2},
				{last - 2, last - 2}, {centre, 1}, {centre, last - 1},
				{1, centre}, {last - 1, centre}}) do
			dressing.path_light(buf, palette, spot[1], spot[2], lights)
		end
		dressing.signpost(buf, palette, 3, centre)

		socket(sockets, id .. "_idle_west", "idle", 3, 1, 5, 1,
			{tags = {"bench"}})
		socket(sockets, id .. "_idle_east", "idle", last - 3, 1, last - 5, 3,
			{tags = {"bench"}})
		-- The waypoint stands clear of the market cross, on the paving of
		-- the north arm of the crossing.
		socket(sockets, id .. "_waypoint", "waypoint", centre, 1, centre - 4, 0)

		return finish(buf, size, size, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {},
			room_corner = {},
		}, {stalls = #stalls, benches = benches})
	end

	-- -------------------------------------------------------------------
	-- 7. the well court
	-- -------------------------------------------------------------------

	-- A small paved court with the library's draw well at its centre, a kerb
	-- of low wall, four benches and two planters.
	--
	-- Extent: size x size, y 0..5; the default 11 is a quarter-plot.
	function M.well_court(palette, spec)
		local size = spec.size or 11
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if size < 9 then error("wp13 capitals: well court too small", 0) end
		local last = size - 1
		local centre = math.floor(last / 2)

		buf:clear(0, 1, 0, last, 6, last)
		buf:fill(0, 0, 0, last, 0, last, paving(palette))
		dressing.inlay(buf, palette, 0, 0, last, last, "plaza_edge")
		dressing.well(buf, palette, centre, centre, lights)
		-- `dressing.well` stands its two frame posts on its own kerb, and the
		-- kerb is the palette's `low_wall`. For the three starts that draw a
		-- well that is a `walls:` nodebox, a full-height cube; for the elf it
		-- is `grug_decor:darkage_serpentine_slab`, a BOTTOM slab whose surface
		-- lies half a node down, so both posts would ride half a node clear of
		-- their footing -- the round-A defect, in a piece of dressing no
		-- pale-stone race had drawn yet. The two bearing cells are therefore
		-- re-laid in the court's own paving, which is a full cube in every
		-- palette. The fix is scoped to this part on purpose: changing
		-- `dressing.well` itself would move cells in Hearthpine, Dawnmere and
		-- Stillgrave, whose blueprint identities are frozen.
		for _, corner in ipairs({{-1, -1}, {1, 1}}) do
			buf:put(centre + corner[1], 1, centre + corner[2], paving(palette))
		end

		local benches = 0
		for _, entry in ipairs({{centre, 1, 0}, {centre, last - 1, 2},
				{1, centre, 1}, {last - 1, centre, 3}}) do
			parts.seat(buf, palette, entry[1], 1, entry[2], entry[3])
			benches = benches + 1
		end
		dressing.planter(buf, palette, 1, 1, 2, 2)
		dressing.planter(buf, palette, last - 2, last - 2, last - 1, last - 1)

		local id = spec.id or "well"
		socket(sockets, id .. "_idle_a", "idle", centre, 1, 2, 0,
			{tags = {"bench"}})
		socket(sockets, id .. "_idle_b", "idle", centre, 1, last - 2, 2,
			{tags = {"bench"}})

		return finish(buf, size, size, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {},
			room_corner = {},
		}, {benches = benches})
	end

	-- -------------------------------------------------------------------
	-- 8. the statue plinth
	-- -------------------------------------------------------------------

	-- A stepped plinth carrying a standing figure, with a lamp at each
	-- corner of the base. The figure is masonry, not a mesh: two courses of
	-- body, a pair of slab arms and a signature head, which at node scale is
	-- what a monument looks like.
	--
	-- Extent: 9 x 9, y 0..8.
	function M.statue_plinth(palette, spec)
		local size = 9
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		local last = size - 1
		local c = 4

		buf:clear(0, 1, 0, last, 9, last)
		buf:fill(0, 0, 0, last, 0, last, paving(palette))
		dressing.inlay(buf, palette, 0, 0, last, last, "plaza_edge")
		-- The plinth is the citadel masonry and the figure is the signature
		-- material, all of it. The first version alternated the two up the
		-- figure and the render was a striped totem: a monument reads as
		-- carved out of ONE stone, standing on another.
		buf:fill(2, 1, 2, last - 2, 1, last - 2, stone(palette))
		buf:fill(3, 2, 3, last - 3, 2, last - 3, stone(palette))
		-- The risers of the two steps, so the plinth is climbable rather
		-- than a pair of stacked boxes.
		for step = 2, last - 2 do
			parts.stair(buf, step, 1, 1, stone_stair(palette), 0)
			parts.stair(buf, step, 1, last - 1, stone_stair(palette), 2)
			parts.stair(buf, 1, 1, step, stone_stair(palette), 1)
			parts.stair(buf, last - 1, 1, step, stone_stair(palette), 3)
		end

		-- The figure: an armoured man with a standard.
		--
		-- What carries a statue at node scale is the SILHOUETTE, and the
		-- second version's was still a column with two arms on it. This one
		-- is read from the ground up as a flared skirt, a shield arm on one
		-- side, a body, two stair shoulders whose raised halves fall
		-- outward, a head, a helm crest -- and, off the other shoulder, a
		-- standard with a banner on it, which is the piece that makes the
		-- outline unmistakably a figure rather than a pillar.
		for _, spot in ipairs({{0, 0}, {-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
			buf:put(c + spot[1], 3, c + spot[2], mark(palette))
		end
		buf:put(c, 4, c, mark(palette))
		buf:put(c - 1, 4, c, mark(palette))
		buf:put(c, 5, c, mark(palette))
		parts.stair(buf, c - 1, 5, c, mark_stair(palette), 3)
		parts.stair(buf, c + 1, 5, c, mark_stair(palette), 1)
		buf:put(c, 6, c, mark(palette))
		buf:put(c, 7, c, mark_slab(palette))
		-- The standard rises off the right shoulder and the banner hangs
		-- from it; both touch what carries them across a face, which is what
		-- the connectivity flood of `library_kat` section 12 asks of every
		-- cell of a capital part.
		for y = 6, 8 do
			buf:put(c + 1, y, c, palette.node("post"))
		end
		buf:put(c + 1, 9, c, mark_slab(palette))
		for y = 7, 8 do
			buf:put(c + 2, y, c, palette.node("rug_accent"))
		end

		for _, corner in ipairs({{1, 1}, {last - 1, 1}, {1, last - 1},
				{last - 1, last - 1}}) do
			parts.floor_torch(buf, palette, corner[1], 1, corner[2])
			lights[#lights + 1] = {x = corner[1], y = 1, z = corner[2]}
		end

		local id = spec.id or "statue"
		socket(sockets, id .. "_idle", "idle", c, 1, 0, 0, {tags = {"bench"}})

		return finish(buf, size, size, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {},
			room_corner = {},
		})
	end

	-- -------------------------------------------------------------------
	-- 9-13. the five district buildings
	-- -------------------------------------------------------------------
	--
	-- Each is an ordinary `buildings.build` block with a capital interior
	-- kit, so it inherits the library's walls, framed windows, real doors and
	-- rasterised roof unchanged. The generator adds the sockets, which is the
	-- only thing `buildings.build` does not know how to publish; every socket
	-- stands in the centre aisle the kits deliberately keep clear.
	--
	-- All five ask for half timbering and shutters by default. Both are
	-- optional roles, so a race that binds neither gets plain planks and open
	-- reveals and nothing fails; a race that binds them gets a wall with a
	-- rhythm in it, which is what stops a district plot reading as a shed.
	--
	-- Extent of all five at their defaults: at most 17 x 23 including the
	-- apron, y 0..14 -- inside the 32 x 32 / y -6..24 plot envelope.

	local function district(part, sockets)
		part.points.sockets = sockets
		return finish(part.buffer, part.w, part.d, top_of(part.buffer),
			part.points)
	end

	local function dress(spec)
		local infill = spec.infill
		if infill == nil then infill = true end
		-- Shutters are NOT on by default. `cottages_window_shutter_closed` is
		-- the only shutter in the tree and it is the CLOSED leaf, so a plot
		-- that asks for shutters everywhere renders as a boarded-up building
		-- -- which is what the first temple looked like. A composition that
		-- wants a shuttered building asks for one.
		local shutters = spec.shutters
		if shutters == nil then shutters = false end
		return infill, shutters
	end

	-- The garrison hall: bunks down both walls, arms racked at the far end
	-- and a fire by the door under a real chimney stack.
	function M.barracks(palette, spec)
		local w, d = spec.w or 15, spec.d or 21
		local wall_h = spec.wall_h or 5
		local infill, shutters = dress(spec)
		local cx = math.floor(w / 2)
		local part = buildings.build(palette, {
			id = spec.id, infill = infill, shutters = shutters,
			roof_palette = spec.roof_palette,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1,
				wall_h = wall_h, roof = spec.roof or "gable",
				ridge_axis = "z", rise = spec.rise or 4, kit = "barracks"}},
			chimneys = {{x = w - 1, z = 1}},
			doors = {{side = "z-", index = cx, double = true}},
			inside = {x = cx, y = 1, z = 3},
		})
		local id = spec.id or "barracks"
		local sockets = {}
		socket(sockets, id .. "_post", "guard_post", cx, 1, 2, 0)
		socket(sockets, id .. "_muster", "idle", cx, 1, d - 4, 2,
			{tags = {"fire"}})
		patrol(sockets, id .. "_yard", spec.patrol_group or "garrison",
			spec.order or 1, cx, 1, d - 7, 0)
		return district(part, sockets)
	end

	-- The temple: the tallest plot of a district, hip roofed, with the
	-- library's own belfry on its ridge -- the same silhouette Dawnmere's
	-- meeting hall carries, which is what makes a civic building read as one
	-- from the far end of an avenue.
	function M.temple(palette, spec)
		local w, d = spec.w or 13, spec.d or 19
		local wall_h = spec.wall_h or 7
		local infill, shutters = dress(spec)
		local cx = math.floor(w / 2)
		local part = buildings.chapel(palette, {
			id = spec.id, w = w, d = d, wall_h = wall_h,
			roof = spec.roof or "hip", rise = spec.rise or 5,
			door_side = "z-", door_index = cx, kit = "temple",
			infill = infill, shutters = shutters,
			roof_palette = spec.roof_palette,
			inside = {x = cx, y = 1, z = 3},
		})
		parts.stamp(part.buffer, buildings.belfry(palette,
			{roof_palette = spec.roof_palette, height = 4}),
			cx - 2, part.peak, math.floor(d / 2) - 2, 0)
		bear_bell(part.buffer, palette, cx - 2, part.peak,
			math.floor(d / 2) - 2, 4)
		local id = spec.id or "temple"
		local sockets = {}
		socket(sockets, id .. "_altar", "idle", cx, 1, d - 4, 2,
			{tags = {"work"}})
		socket(sockets, id .. "_quest", "quest", cx, 1, 3, 0)
		return district(part, sockets)
	end

	-- The scriptorium: shelving the length of both walls, desks in front of
	-- it, and a saltbox roof so its rear wall stands taller than its front.
	function M.scriptorium(palette, spec)
		local w, d = spec.w or 13, spec.d or 17
		local wall_h = spec.wall_h or 6
		local infill, shutters = dress(spec)
		local cx = math.floor(w / 2)
		local part = buildings.build(palette, {
			id = spec.id, infill = infill, shutters = shutters,
			roof_palette = spec.roof_palette,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1,
				wall_h = wall_h, roof = spec.roof or "saltbox",
				ridge_axis = "z", lift = 2, rise = 3, kit = "scriptorium"}},
			doors = {{side = "z-", index = cx}},
			inside = {x = cx, y = 1, z = 3},
		})
		local id = spec.id or "scriptorium"
		local sockets = {}
		socket(sockets, id .. "_desk_a", "idle", cx, 1, 4, 1, {tags = {"work"}})
		socket(sockets, id .. "_desk_b", "idle", cx, 1, d - 5, 3,
			{tags = {"work"}})
		return district(part, sockets)
	end

	-- The granary: bins of grain along both walls, a cart-wide double door
	-- in the gable end and a saltbox roof.
	function M.granary(palette, spec)
		local w, d = spec.w or 11, spec.d or 15
		local wall_h = spec.wall_h or 5
		local infill, shutters = dress(spec)
		local cx = math.floor(w / 2)
		local part = buildings.build(palette, {
			id = spec.id, infill = infill, shutters = shutters,
			roof_palette = spec.roof_palette,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1,
				wall_h = wall_h, roof = spec.roof or "saltbox",
				ridge_axis = "z", lift = 2, rise = 4, kit = "granary"}},
			doors = {{side = "z-", index = cx, double = true}},
			inside = {x = cx, y = 1, z = 3},
		})
		local id = spec.id or "granary"
		local sockets = {}
		socket(sockets, id .. "_work", "idle", cx, 1, d - 4, 2,
			{tags = {"work"}})
		return district(part, sockets)
	end

	-- The stable: fence partitions between the boxes, bedding in each one, a
	-- feed trough against the head wall and the aisle left open for a cart.
	function M.stable(palette, spec)
		local w, d = spec.w or 15, spec.d or 11
		local wall_h = spec.wall_h or 5
		local infill, shutters = dress(spec)
		local cx = math.floor(w / 2)
		local part = buildings.build(palette, {
			id = spec.id, infill = infill, shutters = shutters,
			roof_palette = spec.roof_palette,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1,
				wall_h = wall_h, roof = spec.roof or "gable",
				ridge_axis = "x", rise = spec.rise or 4, kit = "stable"}},
			doors = {{side = "z-", index = cx, double = true}},
			inside = {x = cx, y = 1, z = 3},
		})
		local id = spec.id or "stable"
		local sockets = {}
		socket(sockets, id .. "_groom", "idle", cx, 1, d - 3, 2,
			{tags = {"work"}})
		socket(sockets, id .. "_gate", "idle", cx, 1, 2, 0, {tags = {"door"}})
		return district(part, sockets)
	end

	-- -------------------------------------------------------------------
	-- 14-17. the open-edge pieces
	-- -------------------------------------------------------------------

	-- The hedge and orchard edge: what Highcourt has instead of a wall.
	-- A kerbed ring street, a clipped hedge behind it, two rows of fruit
	-- trees and a gap with a gate for the orchard track.
	--
	-- Extent: len x 11, y 0..(tree height + 4).
	function M.orchard_edge(palette, spec)
		local len = spec.len or 21
		local d = spec.d or 11
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if len < 13 then error("wp13 capitals: orchard edge too short", 0) end
		local gap = math.floor(len / 2)

		buf:clear(0, 1, 0, len - 1, 16, d - 1)
		buf:fill(0, 0, 0, len - 1, 0, d - 1, palette.node("ground"))
		buf:fill(0, 0, 0, len - 1, 0, 1, palette.node("path"))
		dressing.low_wall_line(buf, palette, 0, 2, gap - 2, 2)
		dressing.low_wall_line(buf, palette, gap + 2, 2, len - 1, 2)

		-- The hedge, broken at the gate. `hedge_line` degrades to nothing
		-- for a race with no hedge, which is why the kerb above carries the
		-- boundary on its own.
		local hedged = dressing.hedge_line(buf, palette, 0, 3, gap - 2, 3, 3)
		hedged = hedged + dressing.hedge_line(buf, palette, gap + 2, 3,
			len - 1, 3, 3)
		local gate = palette.maybe("fence_gate")
		for x = gap - 1, gap + 1 do
			buf:put(x, 0, 3, palette.node("path"))
		end
		if gate then
			buf:put(gap, 1, 3, gate)
		end

		-- Two rows of trees on the field side.
		local trees = 0
		for x = 3, len - 4, 5 do
			dressing.broadleaf(buf, palette, x, 6, 5)
			dressing.broadleaf(buf, palette, x + 2, d - 2, 4)
			trees = trees + 2
		end
		dressing.undergrowth(buf, palette, 0, 4, len - 1, d - 1, 7)

		local id = spec.id or "orchard"
		for x = 4, len - 5, 8 do
			dressing.path_light(buf, palette, x, 1, lights)
		end
		socket(sockets, id .. "_work", "idle", gap, 1, 5, 0, {tags = {"work"}})
		patrol(sockets, id .. "_street_a", spec.patrol_group or "ring",
			spec.order or 1, 2, 1, 0, 1)
		patrol(sockets, id .. "_street_b", spec.patrol_group or "ring",
			(spec.order or 1) + 1, len - 3, 1, 0, 3)

		return finish(buf, len, d, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {},
			room_corner = {},
		}, {trees = trees, hedge = hedged})
	end

	-- A grove: the kept trees between two plots, with a paved walk crossing
	-- and lanterns on the walk. `spec.kind` names the dressing silhouette, so
	-- one generator gives a pine grove, a broadleaf grove, a columnar aspen
	-- grove or a kapok stand.
	--
	-- Extent: size x size, y 0..(tree height + 6).
	function M.grove(palette, spec)
		local size = spec.size or 17
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if size < 11 then error("wp13 capitals: grove too small", 0) end
		local last = size - 1
		local centre = math.floor(last / 2)
		local kind = spec.kind or "tree"
		local plant = dressing[kind]
		if type(plant) ~= "function" then
			error("wp13 capitals: unknown grove kind " .. tostring(kind), 0)
		end

		buf:clear(0, 1, 0, last, 24, last)
		buf:fill(0, 0, 0, last, 0, last, palette.node("ground"))
		for step = 0, last do
			for offset = -1, 1 do
				buf:put(centre + offset, 0, step, palette.node("path"))
				buf:put(step, 0, centre + offset, palette.node("path"))
			end
		end

		local trees = 0
		for _, spot in ipairs({{2, 2}, {last - 2, 2}, {2, last - 2},
				{last - 2, last - 2}, {centre - 4, centre + 4}}) do
			plant(buf, palette, spot[1], spot[2], spec.height or 8)
			trees = trees + 1
		end
		dressing.undergrowth(buf, palette, 0, 0, last, last, 6)
		for _, spot in ipairs({{centre - 2, 2}, {centre + 2, last - 2}}) do
			dressing.path_light(buf, palette, spot[1], spot[2], lights)
		end

		local id = spec.id or "grove"
		socket(sockets, id .. "_idle", "idle", centre, 1, centre, 0,
			{tags = {"bench"}})

		return finish(buf, size, size, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {},
			room_corner = {},
		}, {trees = trees})
	end

	-- The troll edge: a basalt-pier platform carrying a railed deck, with a
	-- walkway spur running off it and a flight down to the ground.
	--
	-- Extent: size x size in x, size plus the spur and the flight in z (26 at
	-- the defaults), y 0..(deck + 1).
	function M.stilt_platform(palette, spec)
		local size = spec.size or 15
		local deck = spec.deck or 6
		local spur = spec.spur or 6
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if size < 9 then error("wp13 capitals: stilt platform too small", 0) end
		local last = size - 1
		local centre = math.floor(last / 2)

		buf:clear(0, 1, 0, last, deck + 4, last)
		buf:fill(0, 0, 0, last, 0, last, palette.node("ground_patch"))

		-- Legs on a four-node grid, plus every corner, on masonry pad stones.
		-- The first version stood them three apart in the race's `foundation`
		-- masonry and only two courses clear of the mud: from any camera
		-- angle that is a plinth with a deck on it, not a platform on stilts.
		-- Timber posts on a wider grid under a six-course deck are legs.
		local piers = 0
		local function leg(x, z)
			buf:put(x, 1, z, palette.node("foundation"))
			for y = 2, deck - 1 do
				buf:put(x, y, z, palette.node("post"))
			end
			piers = piers + 1
		end
		for z = 0, last, 4 do
			for x = 0, last, 4 do leg(x, z) end
		end
		for _, corner in ipairs({{last, 0}, {0, last}, {last, last}}) do
			leg(corner[1], corner[2])
		end
		buf:fill(0, deck, 0, last, deck, last, palette.node("path"))

		-- The rail, opened at the head of the spur and at the head of the
		-- flight, because those are the two places a walk has to cross it.
		local mouth = {}
		for offset = -1, 1 do
			mouth[(centre + offset) .. ":" .. last] = true
			mouth[(centre + offset) .. ":0"] = true
		end
		for z = 0, last do
			for x = 0, last do
				if (x == 0 or x == last or z == 0 or z == last) and
						not mouth[x .. ":" .. z] then
					buf:put(x, deck + 1, z, palette.node("railing"))
				end
			end
		end

		dressing.walkway(buf, palette, centre, last + 1, spur, "z", deck)
		-- `stair_up` puts its treads on the far side of the deck edge it is
		-- given and clears four courses over each of them, so the sign that
		-- lands the flight OUTSIDE the platform is the positive one: the
		-- other sign walks the flight back across the deck and cuts three
		-- holes in it.
		dressing.stair_up(buf, palette, centre, 0, deck, "z", 1)
		-- ...and the tread `stair_up` does not write. It runs `1, top - 1`,
		-- so its highest tread leaves a climber's feet one whole node below
		-- the deck: a jump, not a step. The last tread stands IN the deck
		-- edge, which is where a flight meets the floor it serves. The
		-- shared routine is left alone because Kapok Cradle's identity is
		-- frozen on its current output.
		parts.stair(buf, centre, deck, 0, palette.node("roof_stair"), 0)

		-- Lanterns under the deck and a lamp on it.
		local lanterns = 0
		for _, spot in ipairs({{3, 3}, {last - 3, last - 3}}) do
			if dressing.lantern(buf, palette, spot[1], deck - 1, spot[2]) then
				lanterns = lanterns + 1
				lights[#lights + 1] = {x = spot[1], y = deck - 1, z = spot[2]}
			end
		end
		parts.floor_torch(buf, palette, 2, deck + 1, centre)
		lights[#lights + 1] = {x = 2, y = deck + 1, z = centre}

		local id = spec.id or "stilt"
		patrol(sockets, id .. "_deck_a", spec.patrol_group or "boardwalk",
			spec.order or 1, centre, deck + 1, 2, 0)
		patrol(sockets, id .. "_deck_b", spec.patrol_group or "boardwalk",
			(spec.order or 1) + 1, centre, deck + 1, last - 2, 2)
		socket(sockets, id .. "_idle", "idle", centre + 3, deck + 1, centre, 1,
			{tags = {"work"}})

		return finish(buf, size, size, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {},
			room_corner = {},
		}, {piers = piers, lanterns = lanterns})
	end

	-- A lined water channel: the elf and troll edge, and the drain of every
	-- terraced capital. A masonry invert two courses down, lined cheeks, a
	-- paved bank either side with a kerb rail, and a plank crossing.
	--
	-- The channel is authored DRY. Pipeline contract section 5 invariant 1
	-- forbids a liquid in a blueprint -- a VoxelManip write places no liquid
	-- update, so authored water is either static or a flood nobody asked for
	-- -- so what this part builds is the cut, the lining and the crossing.
	-- Filling it is the composition lane's decision and the engine's job.
	--
	-- Extent: len x 7, y -3..3 -- the lamp standards are the top course, not
	-- the kerb rail. The -3 is inside the plot envelope's y -6.
	function M.water_channel(palette, spec)
		local len = spec.len or 21
		local d = 7
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if len < 11 then error("wp13 capitals: water channel too short", 0) end
		local bridge = spec.bridge or (math.floor(len / 2) - 2)
		local bridge_end = bridge + 4
		if bridge < 1 or bridge_end > len - 2 then
			error("wp13 capitals: the crossing falls outside the channel", 0)
		end

		buf:clear(0, 1, 0, len - 1, 4, d - 1)
		buf:fill(0, -3, 0, len - 1, -3, d - 1, palette.node("foundation"))
		for x = 0, len - 1 do
			-- Banks.
			for _, z in ipairs({0, d - 1}) do
				for y = -2, 0 do
					buf:put(x, y, z, palette.node("subsoil"))
				end
				buf:put(x, 0, z, paving(palette))
			end
			-- Cheeks.
			for _, z in ipairs({1, d - 2}) do
				for y = -2, 0 do
					buf:put(x, y, z, stone(palette))
				end
			end
			-- Invert and void.
			for z = 2, d - 3 do
				buf:put(x, -2, z, spoil(palette))
				buf:clear(x, -1, z, x, 0, z)
			end
		end
		-- The kerb rail, opened where the crossing lands.
		local kerb = 0
		for x = 0, len - 1 do
			if x < bridge or x > bridge_end then
				buf:put(x, 1, 1, palette.node("low_wall"))
				buf:put(x, 1, d - 2, palette.node("low_wall"))
				kerb = kerb + 2
			end
		end
		-- The crossing: a five-wide deck level with the banks, railed on the
		-- two cells that overhang the water.
		for x = bridge, bridge_end do
			for z = 1, d - 2 do
				buf:put(x, 0, z, palette.node("path"))
			end
		end
		for z = 2, d - 3 do
			buf:put(bridge, 1, z, palette.node("railing"))
			buf:put(bridge_end, 1, z, palette.node("railing"))
		end

		for x = 3, len - 4, 7 do
			dressing.path_light(buf, palette, x, 0, lights)
		end

		local id = spec.id or "channel"
		socket(sockets, id .. "_cross", "idle", bridge + 2, 1,
			math.floor(d / 2), 0, {tags = {"bench"}})
		patrol(sockets, id .. "_bank_a", spec.patrol_group or "ring",
			spec.order or 1, 2, 1, 0, 1)
		patrol(sockets, id .. "_bank_b", spec.patrol_group or "ring",
			(spec.order or 1) + 1, len - 3, 1, d - 1, 3)

		return finish(buf, len, d, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {},
			room_corner = {},
		}, {kerb = kerb})
	end

	return M
end

return loader
