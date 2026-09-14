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
		-- The turrets carry their merlons just clear of the ridge.
		local turret_top = nave_eave + 6
		local merlons = 0
		for _, corner in ipairs({{0, 0}, {w - 3, 0}, {0, d - 3},
				{w - 3, d - 3}}) do
			for z = corner[2], corner[2] + 2 do
				for x = corner[1], corner[1] + 2 do
					for y = 1, turret_top do
						local name = stone(palette)
						if y == base + 1 or y == lintel or y == turret_top then
							name = mark(palette)
						end
						buf:put(x, y, z, name)
					end
					if (x + z) % 2 == 0 then
						buf:put(x, turret_top + 1, z, stone(palette))
						buf:put(x, turret_top + 2, z, mark_slab(palette))
						merlons = merlons + 1
					end
				end
			end
		end
		-- Loopholes in the outward faces of every turret, two storeys up.
		for _, face in ipairs({{0, 1, -1, 0}, {1, 0, 0, -1},
				{w - 1, 1, 1, 0}, {w - 2, 0, 0, -1},
				{0, d - 2, -1, 0}, {1, d - 1, 0, 1},
				{w - 1, d - 2, 1, 0}, {w - 2, d - 1, 0, 1}}) do
			for _, y in ipairs({base + 4, base + 9}) do
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
			buttresses = buttresses, benches = benches})
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
		-- doorway in the inner face. Six treads take a walker from the pad at
		-- y = 1 to the walkway at y = 7, one course per cell, which is what
		-- the conservative walk of the blueprint fixtures climbs.
		if spec.stair then
			if len < 10 then
				error("wp13 capitals: a wall stair needs ten nodes", 0)
			end
			-- A LANDING behind the door, then five treads, then the walkway.
			-- The first version started the flight in the doorway itself, so
			-- a walker stepping out of the door put his foot on the raised
			-- half of a stair rather than on a floor; the base course of the
			-- wall is the landing, and the treads begin one node further in.
			buf:clear(1, 1, thick - 2, 6, walk + 1, thick - 2)
			for run = 1, 5 do
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

		-- The two floors. Each carries the stairwell of the flight that
		-- lands on it, so a climber is never stopped by his own ceiling.
		buf:fill(1, walk, 1, last - 1, walk, last - 1, paving(palette))
		buf:clear(1, walk, 1, 1, walk, 5)
		buf:fill(1, head, 1, last - 1, head, last - 1, paving(palette))
		buf:clear(last - 1, head, 1, last - 1, head, 5)
		for run = 1, 5 do
			parts.stair(buf, 1, run, run, stone_stair(palette), 0)
			buf:clear(1, run + 1, run, 1, run + 2, run)
			parts.stair(buf, last - 1, walk + run, run, stone_stair(palette), 0)
			buf:clear(last - 1, walk + run + 1, run, last - 1, walk + run + 2, run)
		end

		-- Rampart openings, three wide and two high, in the two faces a
		-- chained wall arrives at. They line up with the three-wide walkway
		-- of `wall_segment`.
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
	-- pier holds a guard chamber with its own door, the left one also the
	-- flight to the chamber above, and the roof is a crenellated deck level
	-- with the curtain wall's own crown.
	--
	-- Extent: 13 x 7, y -2..13.
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

		-- The chamber floor, with the stairwell of the left flight cut out
		-- of it, and the flight itself.
		buf:fill(0, 6, 0, w - 1, 6, d - 1, palette.node("floor"))
		buf:clear(2, 6, 1, 2, 6, 5)
		for run = 1, 5 do
			parts.stair(buf, 2, run, run, stone_stair(palette), 0)
			buf:clear(2, run + 1, run, 2, run + 2, run)
		end

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

		-- The deck and its crenellation.
		buf:fill(0, 11, 0, w - 1, 11, d - 1, paving(palette))
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
		patrol(sockets, id .. "_deck", spec.patrol_group or "rampart",
			spec.order or 1, 6, 12, 3, 2)
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

	return M
end

return loader
