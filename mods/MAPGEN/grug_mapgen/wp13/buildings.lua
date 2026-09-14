-- WP13 parametric building generators.
--
-- Every generator works in its own local frame: x runs 0..w-1, z runs
-- 0..d-1, y = 0 is the ground node the building stands on and y = 1 is the
-- first walkable course. The result is a "part" that `parts.stamp` places on
-- the pad at any of the four rotations.
--
-- A building is one or more rectangular blocks. Each block carries its own
-- roof; the roofs are combined by taking the highest surface at every
-- column, so a cross gable gets real valleys and the rasteriser turns them
-- into inner corner stairs. The combined roof height field also drives the
-- walls: every perimeter column is built up to one node below the roof above
-- it, so gable ends close themselves, a saltbox gets its taller rear wall for
-- free, and no wall ever leaves a gap under its eave.
--
-- Walls are a stone base course, plank infill and log posts; windows are
-- panes framed by logs; doors are real two-node doors.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local roofs = dofile(directory .. "/roofs.lua")
	local interiors = dofile(directory .. "/interiors.lua")
	-- `dressing` writes exterior props into a buffer and needs nothing from
	-- this module, so the dependency is one way: the ruin generator below
	-- reuses its rubble, ivy and cobweb.
	local dressing = dofile(directory .. "/dressing.lua")(directory)

	local M = {}

	local SIDES = {"z-", "z+", "x-", "x+"}
	local SIDE_STEP = {["z-"] = {0, -1}, ["z+"] = {0, 1},
		["x-"] = {-1, 0}, ["x+"] = {1, 0}}

	-- The facedir pointing from the named wall into the building.
	local function inward(side)
		local step = SIDE_STEP[side]
		if not step then
			error("wp13 buildings: unknown side " .. tostring(side), 0)
		end
		return parts.step_facedir(-step[1], -step[2])
	end

	-- The wall cell `index` steps along the named side of a block.
	local function wall_cell(block, side, index)
		if side == "z-" then return block.x0 + index, block.z0 end
		if side == "z+" then return block.x0 + index, block.z1 end
		if side == "x-" then return block.x0, block.z0 + index end
		if side == "x+" then return block.x1, block.z0 + index end
		error("wp13 buildings: unknown side " .. tostring(side), 0)
	end

	local function side_length(block, side)
		if side == "z-" or side == "z+" then return block.x1 - block.x0 + 1 end
		return block.z1 - block.z0 + 1
	end

	local function has(list, value)
		for i = 1, #list do
			if list[i] == value then return true end
		end
		return false
	end

	-- The two entry torches beside a doorway. Each one hangs on the outside
	-- face of a wall cell, so that cell has to BE a wall: the window rhythm
	-- puts panes two nodes from many doorways, and a wallmounted torch on a
	-- pane hangs in the window instead of on the house. The torch therefore
	-- walks outward along its own wall until it finds an opaque full node to
	-- hang on, and is dropped if the wall offers none.
	local function entry_torch(buf, palette, block, side, x, z, sign, y, lights)
		local step = SIDE_STEP[side]
		local along = (side == "z-" or side == "z+")
		for _, distance in ipairs({2, 3, 4}) do
			local offset = sign * distance
			local tx, tz = x, z
			if along then tx = x + offset else tz = z + offset end
			if tx >= block.x0 and tx <= block.x1 and
					tz >= block.z0 and tz <= block.z1 and
					parts.solid_at(buf, tx, y, tz) then
				local lx, lz = tx + step[1], tz + step[2]
				local here = buf:at(lx, y, lz)
				if here == nil or here.name == "air" then
					parts.wall_torch(buf, palette, lx, y, lz,
						-step[1], 0, -step[2])
					lights[#lights + 1] = {x = lx, y = y, z = lz}
					return true
				end
			end
		end
		return false
	end

	-- Window rhythm along an inner wall run of length `len` (positions
	-- 1..len): a two wide pane opening every four positions starting at 2,
	-- each flanked by a log frame, which reads as half timbering.
	local function window_slots(len)
		local slots = {}
		local p = 2
		while p + 1 <= len do
			slots[#slots + 1] = p
			p = p + 4
		end
		return slots
	end

	-- A building: footings, apron, walls, framed windows, doors, roof,
	-- chimney stacks and furnished rooms.
	function M.build(palette, spec)
		local overhang = spec.overhang or 1
		local blocks = spec.blocks
		if not blocks then
			blocks = {{x0 = 0, z0 = 0, x1 = spec.w - 1, z1 = spec.d - 1}}
		end
		local buf = parts.buffer()
		local lights, doors, room_corners = {}, {}, {}

		local bx0, bz0, bx1, bz1
		local fields = {}
		for index, block in ipairs(blocks) do
			block.wall_h = block.wall_h or spec.wall_h or 4
			fields[index] = roofs.field(block.roof or spec.roof or "gable", {
				x0 = block.x0 - overhang, x1 = block.x1 + overhang,
				z0 = block.z0 - overhang, z1 = block.z1 + overhang,
				base = block.wall_h, axis = block.ridge_axis or spec.ridge_axis or "x",
				lift = block.lift or spec.lift, rise = block.rise or spec.rise,
				up = block.up or spec.up,
			})
			if bx0 == nil or block.x0 < bx0 then bx0 = block.x0 end
			if bz0 == nil or block.z0 < bz0 then bz0 = block.z0 end
			if bx1 == nil or block.x1 > bx1 then bx1 = block.x1 end
			if bz1 == nil or block.z1 > bz1 then bz1 = block.z1 end
		end
		local field = roofs.combine(fields)
		local w, d = bx1 + 1, bz1 + 1

		local peak = 0
		for z = field.z0, field.z1 do
			for x = field.x0, field.x1 do
				local y = field.height(x, z)
				if y and y > peak then peak = y end
			end
		end
		-- One node below the roof that covers this column.
		local function wall_top(x, z)
			local y = field.height(x, z)
			return (y or 1) - 1
		end
		-- Is this cell strictly inside some other block?
		local function shared(self_index, x, z)
			for index, block in ipairs(blocks) do
				if index ~= self_index and x > block.x0 and x < block.x1 and
						z > block.z0 and z < block.z1 then
					return true
				end
			end
			return false
		end

		-- Clear each plot volume first so later courses never mix with
		-- whatever the pad ground left behind, then pave the apron the
		-- doorsteps and the eaves drip line stand on.
		for _, block in ipairs(blocks) do
			buf:clear(block.x0 - overhang, 1, block.z0 - overhang,
				block.x1 + overhang, peak + 2, block.z1 + overhang)
		end
		for _, block in ipairs(blocks) do
			buf:fill(block.x0 - overhang, 0, block.z0 - overhang,
				block.x1 + overhang, 0, block.z1 + overhang, palette.node("path"))
		end
		for _, block in ipairs(blocks) do
			buf:fill(block.x0, 0, block.z0, block.x1, 0, block.z1,
				palette.node("foundation"))
		end
		for _, block in ipairs(blocks) do
			buf:fill(block.x0 + 1, 0, block.z0 + 1, block.x1 - 1, 0, block.z1 - 1,
				palette.node("floor"))
		end

		-- Walls: stone base course, plank infill up to the eave. Perimeter
		-- cells that fall inside another block are left open, so the blocks
		-- of one building form a single room.
		local open_by_block = {}
		for index, block in ipairs(blocks) do
			open_by_block[index] = block.open_sides or spec.open_sides or {}
			for _, side in ipairs(SIDES) do
				for step = 0, side_length(block, side) - 1 do
					local x, z = wall_cell(block, side, step)
					if not shared(index, x, z) then
						local top = wall_top(x, z)
						if has(open_by_block[index], side) then
							-- An open side is a timber bay: a top plate on
							-- posts every fourth node, so nothing spans free.
							buf:put(x, top, z, palette.node("beam"))
							if step % 4 == 0 then
								for y = 1, top - 1 do
									buf:put(x, y, z, palette.node("post"))
								end
							end
						else
							buf:put(x, 1, z, palette.node("wall_accent"))
							-- Half timbering: loam panels between timber studs
							-- every third cell along the wall, which is the
							-- rhythm the window frames already stand in, so
							-- studs and frames read as one timber frame. A
							-- palette without `wall_infill` keeps plain planks.
							local infill = spec.infill and palette.maybe("wall_infill")
							local name = palette.node("wall")
							if infill then
								name = (step % 3 == 0) and palette.node("post")
									or infill
							end
							for y = 2, top do
								buf:put(x, y, z, name)
							end
						end
					end
				end
			end
			for _, corner in ipairs({{block.x0, block.z0}, {block.x1, block.z0},
					{block.x0, block.z1}, {block.x1, block.z1}}) do
				if not shared(index, corner[1], corner[2]) then
					for y = 1, math.max(block.wall_h,
							wall_top(corner[1], corner[2])) do
						buf:put(corner[1], y, corner[2], palette.node("post"))
					end
				end
			end
		end

		-- Framed pane windows, skipped around every doorway.
		local blocked = {}
		for _, door in ipairs(spec.doors or {}) do
			for offset = -1, 1 do
				blocked[(door.block or 1) .. door.side .. ":" ..
					(door.index + offset)] = true
			end
		end
		for index, block in ipairs(blocks) do
			for _, side in ipairs(SIDES) do
				if not has(open_by_block[index], side) then
					local axis = (side == "z-" or side == "z+") and "x" or "z"
					local len = side_length(block, side)
					local taken = {}
					for _, slot in ipairs(window_slots(len - 2)) do
						-- A doorway may sit where a window wanted to be; shift
						-- the opening along the wall rather than dropping it.
						local p
						for _, candidate in ipairs({slot, slot + 2, slot - 2}) do
							if p == nil and candidate >= 2 and
									candidate + 2 <= len - 1 then
								local free = true
								for step = candidate - 1, candidate + 2 do
									local fx, fz = wall_cell(block, side, step)
									if taken[step] or
											blocked[index .. side .. ":" .. step] or
											shared(index, fx, fz) then
										free = false
									end
								end
								if free then p = candidate end
							end
						end
						if p then
							for step = p - 1, p + 2 do taken[step] = true end
							for _, step in ipairs({p, p + 1}) do
								local x, z = wall_cell(block, side, step)
								local high = math.min(block.wall_h >= 4 and 3 or 2,
									wall_top(x, z))
								for y = 2, high do
									parts.pane(buf, palette, x, y, z, axis)
								end
							end
							for _, step in ipairs({p - 1, p + 2}) do
								local fx, fz = wall_cell(block, side, step)
								for y = 1, math.min(block.wall_h,
										wall_top(fx, fz)) do
									buf:put(fx, y, fz, palette.node("window_frame"))
								end
							end
							-- Shutters hang on the outside face of the opening.
							-- `cottages_window_shutter_closed` is two thin
							-- panels on the node's +Z face, so the leaf sits
							-- flush against the wall when its facedir points
							-- back at the wall, exactly like a wallmounted
							-- fitting but in the facedir family.
							local shutter = spec.shutters and palette.maybe("shutter")
							if shutter then
								local out = SIDE_STEP[side]
								for _, step in ipairs({p, p + 1}) do
									local wx, wz = wall_cell(block, side, step)
									local ox, oz = wx + out[1], wz + out[2]
									for y = 2, math.min(
											block.wall_h >= 4 and 3 or 2,
											wall_top(wx, wz)) do
										local here = buf:at(ox, y, oz)
										if here == nil or here.name == "air" then
											buf:put(ox, y, oz, shutter,
												inward(side))
										end
									end
								end
							end
						end
					end
				end
			end
		end

		-- Doors and the two entry torches beside each of them.
		for _, door in ipairs(spec.doors or {}) do
			local block = blocks[door.block or 1]
			local face = inward(door.side)
			local x, z = wall_cell(block, door.side, door.index)
			buf:clear(x, 1, z, x, 2, z)
			local partner_x, partner_z
			if door.double then
				partner_x, partner_z = parts.double_door(buf, palette, x, 1, z, face)
			else
				parts.door(buf, palette, x, 1, z, face, door.right_hinge)
			end
			doors[#doors + 1] = {x = x, y = 1, z = z, face = face}
			if partner_x then
				doors[#doors + 1] = {x = partner_x, y = 1, z = partner_z,
					face = face}
			end
			for _, sign in ipairs({-1, 1}) do
				entry_torch(buf, palette, block, door.side, x, z, sign, 3,
					lights)
			end
		end

		-- A building may carry a roof of a different material: the roof
		-- roles are read from `spec.roof_palette` when the composition
		-- passes one, so a stone roof needs no second generator.
		local roof_top = roofs.raster(buf, spec.roof_palette or palette, field)

		-- Chimneys: stone stacks rising through the roof from a wall cell.
		for _, stack in ipairs(spec.chimneys or {}) do
			local top = math.min(roof_top, (field.height(stack.x, stack.z) or
				roof_top) + 2) + 1
			for y = 1, top do
				buf:put(stack.x, y, stack.z, palette.node("chimney"))
			end
			buf:put(stack.x, top + 1, stack.z, palette.node("chimney_cap"))
		end

		-- Rooms.
		for _, block in ipairs(blocks) do
			if block.kit then
				local room = {x1 = block.x0 + 1, z1 = block.z0 + 1,
					x2 = block.x1 - 1, z2 = block.z1 - 1,
					y = 0, h = block.wall_h}
				local kit_lights = interiors.furnish(block.kit, buf, parts,
					palette, room, block.kit_spec)
				for _, light in ipairs(kit_lights) do
					lights[#lights + 1] = light
				end
			end
			room_corners[#room_corners + 1] = {x = block.x0 + 1, y = 0,
				z = block.z0 + 1, top = block.wall_h,
				closed = (#(block.open_sides or spec.open_sides or {}) == 0)
					and true or false, id = spec.id}
			room_corners[#room_corners + 1] = {x = block.x1 - 1, y = 0,
				z = block.z1 - 1}
		end

		local inside = spec.inside or {x = blocks[1].x0 + 2, y = 1,
			z = blocks[1].z1 - 2}
		buf:clear(inside.x, inside.y, inside.z, inside.x, inside.y + 1, inside.z)

		return {
			buffer = buf, w = w, d = d, peak = roof_top,
			points = {
				doors = doors,
				lights = lights,
				inside = {{x = inside.x, y = inside.y, z = inside.z, id = spec.id}},
				room_corner = room_corners,
			},
		}
	end

	-- ---------------------------------------------------------------------
	-- named generators
	-- ---------------------------------------------------------------------

	-- A small dense home. Footprint, roof form and door side give the four
	-- Hearthpine houses visibly different silhouettes.
	function M.cottage(palette, spec)
		local w, d = spec.w or 9, spec.d or 7
		local wall_h = spec.wall_h or 4
		return M.build(palette, {
			id = spec.id, overhang = 1, roof_palette = spec.roof_palette,
			infill = spec.infill, shutters = spec.shutters,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1,
				wall_h = wall_h, roof = spec.roof or "gable",
				ridge_axis = spec.ridge_axis or "x", lift = spec.lift,
				rise = spec.rise or ((spec.roof or "gable") == "hip" and 3 or 4),
				kit = "home",
				kit_spec = {fancy_bed = spec.fancy_bed,
					hearth_x = w - 2, hearth_z = 1, hearth_face = 3}}},
			chimneys = {{x = w - 1, z = 1}},
			doors = {{side = spec.door_side or "z-",
				index = spec.door_index or math.max(2, math.floor(w / 2) - 2)}},
			inside = spec.inside or {x = 2, y = 1, z = d - 3},
		})
	end

	-- The identity building: a cross gabled craft hall whose wing meets the
	-- main roof in two valleys. `kit` and `wing_kit` name the two interiors,
	-- so the same silhouette serves a forge and a bone-carver's shop without
	-- a second generator; the forge kits stay the default.
	function M.workshop(palette, spec)
		local w, d = spec.w or 11, spec.d or 15
		local wing = spec.wing or 7
		local wall_h = spec.wall_h or 5
		local wz = math.floor((d - wing) / 2)
		return M.build(palette, {
			id = spec.id, overhang = 1, roof_palette = spec.roof_palette,
			infill = spec.infill, shutters = spec.shutters,
			blocks = {
				{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1, wall_h = wall_h,
					roof = "gable", ridge_axis = "z", rise = 4,
					kit = spec.kit or "workshop"},
				{x0 = w - 2, z0 = wz, x1 = w - 2 + wing - 1, z1 = wz + wing - 1,
					wall_h = wall_h, roof = "gable", ridge_axis = "x", rise = 3,
					kit = spec.wing_kit or "smithy"},
			},
			chimneys = {{x = math.floor(w / 2), z = 0},
				{x = w - 2 + wing - 1, z = wz + 1}},
			doors = {{side = spec.door_side or "z+",
				index = spec.door_index or math.floor(w / 2), double = true}},
			inside = spec.inside or {x = 2, y = 1, z = d - 4},
		})
	end

	-- The community hall: the largest ordinary building, hip roofed.
	function M.hall(palette, spec)
		local w, d = spec.w or 13, spec.d or 15
		local wall_h = spec.wall_h or 5
		return M.build(palette, {
			id = spec.id, overhang = 1, roof_palette = spec.roof_palette,
			infill = spec.infill, shutters = spec.shutters,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1, wall_h = wall_h,
				roof = "hip", rise = 4, kit = "hall",
				kit_spec = {hearth_x = 1, hearth_z = 2, hearth_face = 1}}},
			chimneys = {{x = 0, z = 2}},
			doors = {{side = spec.door_side or "z-", index = math.floor(w / 2),
				double = true}},
			inside = spec.inside or {x = 2, y = 1, z = d - 3},
		})
	end

	-- The storage building: a long shed under a saltbox roof, so its rear
	-- wall stands two courses taller than its front.
	function M.longhouse(palette, spec)
		local w, d = spec.w or 9, spec.d or 13
		local wall_h = spec.wall_h or 4
		return M.build(palette, {
			id = spec.id, overhang = 1, roof_palette = spec.roof_palette,
			infill = spec.infill, shutters = spec.shutters,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1, wall_h = wall_h,
				roof = spec.roof or "saltbox", ridge_axis = "z", lift = 2,
				rise = 3, kit = spec.kit or "store"}},
			doors = {{side = spec.door_side or "z-",
				index = spec.door_index or math.floor(w / 2),
				double = spec.double_door}},
			inside = spec.inside or {x = math.floor(w / 2), y = 1, z = 2},
		})
	end

	-- The timber workyard: open on two sides, roof carried on log posts.
	function M.shed(palette, spec)
		local w, d = spec.w or 13, spec.d or 9
		local wall_h = spec.wall_h or 4
		return M.build(palette, {
			id = spec.id, overhang = 1, roof_palette = spec.roof_palette,
			infill = spec.infill, shutters = spec.shutters,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1, wall_h = wall_h,
				roof = "gable", ridge_axis = "x", rise = 3, kit = "yard",
				open_sides = spec.open_sides or {"z-", "x+"}}},
			doors = {},
			inside = spec.inside or {x = 2, y = 1, z = math.floor(d / 2)},
		})
	end

	-- The barn: the largest farm building. Closed walls of plank and loam, a
	-- cart-wide double door in the gable end, a straw floor and a saltbox
	-- roof, so it stands a head taller at the back than the cottages do.
	function M.barn(palette, spec)
		local w, d = spec.w or 13, spec.d or 11
		local wall_h = spec.wall_h or 5
		return M.build(palette, {
			id = spec.id, overhang = 1, roof_palette = spec.roof_palette,
			infill = spec.infill, shutters = spec.shutters,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1, wall_h = wall_h,
				roof = spec.roof or "saltbox", ridge_axis = "z", lift = 2,
				rise = 4, kit = "barn"}},
			doors = {{side = spec.door_side or "z-",
				index = spec.door_index or math.floor(w / 2), double = true}},
			inside = spec.inside or {x = 2, y = 1, z = d - 3},
		})
	end

	-- The meeting hall: the tallest ordinary building, hip roofed, with the
	-- long benches and lamps of a village chapel. The belfry is a separate
	-- part the composition stands on the ridge.
	function M.chapel(palette, spec)
		local w, d = spec.w or 11, spec.d or 15
		local wall_h = spec.wall_h or 6
		return M.build(palette, {
			id = spec.id, overhang = 1, roof_palette = spec.roof_palette,
			infill = spec.infill, shutters = spec.shutters,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1, wall_h = wall_h,
				roof = spec.roof or "hip", ridge_axis = spec.ridge_axis,
				rise = spec.rise or 4, kit = spec.kit or "chapel"}},
			chimneys = spec.chimneys or {},
			doors = {{side = spec.door_side or "z-",
				index = spec.door_index or math.floor(w / 2), double = true}},
			inside = spec.inside or {x = 2, y = 1, z = d - 3},
		})
	end

	-- A belfry: a five by five open lantern on four corner posts under a
	-- little hip roof, with a lamp under it. The composition stamps it on the
	-- ridge of the meeting hall, so its floor closes the hole it stands over.
	function M.belfry(palette, spec)
		local buf = parts.buffer()
		local lights = {}
		local w, d, height = 5, 5, spec.height or 3
		buf:fill(0, 0, 0, w - 1, 0, d - 1, palette.node("floor"))
		for _, corner in ipairs({{0, 0}, {w - 1, 0}, {0, d - 1}, {w - 1, d - 1}}) do
			for y = 1, height do
				buf:put(corner[1], y, corner[2], palette.node("post"))
			end
		end
		for _, side in ipairs({{1, 0}, {2, 0}, {3, 0}, {1, d - 1}, {2, d - 1},
				{3, d - 1}, {0, 1}, {0, 2}, {0, 3}, {w - 1, 1}, {w - 1, 2},
				{w - 1, 3}}) do
			buf:put(side[1], 1, side[2], palette.node("railing"))
			buf:put(side[1], height, side[2], palette.node("beam"))
		end
		-- The bell frame and the lamp that marks the hamlet's centre at night.
		buf:put(2, height - 1, 2, palette.node("chimney_cap"))
		parts.floor_torch(buf, palette, 2, 1, 2)
		lights[#lights + 1] = {x = 2, y = 1, z = 2}
		local field = roofs.hip({x0 = -1, x1 = w, z0 = -1, z1 = d,
			base = height + 1, rise = 3})
		local peak = roofs.raster(buf, spec.roof_palette or palette, field)
		return {
			buffer = buf, w = w, d = d, peak = peak,
			points = {lights = lights},
		}
	end

	-- A roofless ruin: the shell of a home nobody rebuilt.
	--
	-- Everything the other generators guarantee, this one deliberately does
	-- not. There is no roof, no door, no window, no light and no destination;
	-- the wall runs break off at four different heights and two of them are
	-- gone to the footing. What it does keep is the footprint, the footings
	-- and the floor, so the plot still reads as a house on the lane and not
	-- as a pile of stone in a field.
	--
	-- Its room corner is published with `ruin = true`. That flag is the whole
	-- contract with `tools/wp13/blueprint_kat.lua`: the roof-and-light
	-- invariant of the pipeline contract section 5 is relaxed for a room that
	-- carries it, and stays in full force for every inhabited room of every
	-- settlement -- including the two intact homes on the same lane.
	--
	-- `phase` shifts the wall-height hash, so two ruins of the same size on
	-- the same lane collapse differently.
	function M.ruin(palette, spec)
		local w, d = spec.w or 9, spec.d or 9
		local wall_h = spec.wall_h or 5
		local phase = spec.phase or 0
		local buf = parts.buffer()
		local block = {x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1}

		buf:clear(-1, 1, -1, w, wall_h + 2, d)
		-- The plot keeps the apron every other house on the lane has, so it
		-- still reads as a house plot and not as a heap in a field.
		buf:fill(-1, 0, -1, w, 0, d, palette.node("path"))
		buf:fill(0, 0, 0, w - 1, 0, d - 1, palette.node("foundation"))
		-- What is left of the boards: a floor with holes in it.
		for z = 1, d - 2 do
			for x = 1, w - 2 do
				local gone = (x * 5 + z * 3 + phase) % 5 == 0
				buf:put(x, 0, z, palette.node(gone and "rubble" or "floor"))
			end
		end

		-- The standing walls, in RUNS rather than cell by cell. A wall comes
		-- down in stretches; a height drawn per cell reads as crenellation,
		-- which is exactly what the first render showed. The hash is taken
		-- over a three-node lattice, so a run of about three courses shares
		-- one height, and it is a function of the cell's own position, so the
		-- two sides that meet at a corner agree about it.
		local standing, tops = 0, {}
		for _, side in ipairs(SIDES) do
			for index = 0, side_length(block, side) - 1 do
				local x, z = wall_cell(block, side, index)
				local hash = (math.floor(x / 3) * 7 + math.floor(z / 3) * 11 +
					phase * 3) % 9
				local top = 0
				if hash < 1 then top = 0
				elseif hash < 3 then top = 1
				elseif hash < 5 then top = wall_h - 3
				elseif hash < 7 then top = wall_h - 1
				else top = wall_h end
				tops[x .. ":" .. z] = top
				if top >= 1 then
					buf:put(x, 1, z, palette.node("wall_accent"))
					for y = 2, top do buf:put(x, y, z, palette.node("wall")) end
					standing = standing + 1
				end
			end
		end
		-- Corner posts: two still up, two snapped off at a course or three.
		local peak = 1
		for index, corner in ipairs({{0, 0}, {w - 1, 0}, {0, d - 1},
				{w - 1, d - 1}}) do
			local top = ((index + phase) % 2 == 0) and wall_h or
				(1 + (index + phase) % 3)
			for y = 1, top do
				buf:put(corner[1], y, corner[2], palette.node("post"))
			end
			tops[corner[1] .. ":" .. corner[2]] = top
		end
		for _, top in pairs(tops) do
			if top > peak then peak = top end
		end

		-- What came down: masonry heaps inside and against the walls, bones
		-- where the blight reached in, ivy on the faces that still carry it
		-- and cobwebs in the corners that are still corners.
		for z = 1, d - 2 do
			for x = 1, w - 2 do
				local hash = (x * 13 + z * 31 + phase * 3) % 17
				local here = buf:at(x, 1, z)
				if here == nil or here.name == "air" then
					if hash < 3 then
						dressing.rubble_heap(buf, palette, x, z, 1 + hash % 2)
					elseif hash == 5 then
						buf:put(x, 1, z, palette.node("undergrowth"))
					elseif hash == 9 then
						buf:put(x, 1, z, palette.node("grass_tuft"))
					end
				end
			end
		end
		local ivy, cobwebs = 0, 0
		for _, side in ipairs(SIDES) do
			local step = SIDE_STEP[side]
			for index = 1, side_length(block, side) - 2 do
				local x, z = wall_cell(block, side, index)
				local top = tops[x .. ":" .. z] or 0
				local ix, iz = x - step[1], z - step[2]
				if top >= 3 and (x * 7 + z * 11 + phase) % 3 == 0 and
						dressing.ivy(buf, palette, ix, top - 1, iz,
							step[1], step[2]) then
					ivy = ivy + 1
				end
				if top >= 2 and (x * 5 + z * 17 + phase) % 4 == 0 and
						dressing.cobweb(buf, palette, ix, top, iz) then
					cobwebs = cobwebs + 1
				end
			end
		end

		return {
			buffer = buf, w = w, d = d, peak = peak,
			standing = standing, ivy = ivy, cobwebs = cobwebs,
			points = {
				doors = {},
				lights = {},
				inside = {},
				room_corner = {
					{x = 1, y = 0, z = 1, top = peak, closed = false,
						ruin = true, id = spec.id},
					{x = w - 2, y = 0, z = d - 2},
				},
			},
		}
	end

	-- The gate watchpost: guard room below, railed lookout above, reached by
	-- an internal stair run. The lookout plate is a continuous timber ring,
	-- so the hip roof lands on a full node all the way round.
	function M.watchpost(palette, spec)
		local w, d = 9, 9
		local ground_h, deck, plate = 4, 5, 8
		local buf = parts.buffer()
		local lights, doors = {}, {}
		local block = {x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1}

		local field = roofs.hip({x0 = -1, x1 = w, z0 = -1, z1 = d,
			base = plate, rise = 4})
		local peak = plate
		for z = -1, d do
			for x = -1, w do
				local y = field.height(x, z)
				if y and y > peak then peak = y end
			end
		end
		buf:clear(-1, 1, -1, w, peak, d)
		buf:fill(-1, 0, -1, w, 0, d, palette.node("path"))
		buf:fill(0, 0, 0, w - 1, 0, d - 1, palette.node("foundation"))
		buf:fill(1, 0, 1, w - 2, 0, d - 2, palette.node("floor"))

		-- Guard room walls: masonry to shoulder height, planks above.
		for _, side in ipairs(SIDES) do
			for index = 0, side_length(block, side) - 1 do
				local x, z = wall_cell(block, side, index)
				for y = 1, 2 do buf:put(x, y, z, palette.node("wall_accent")) end
				for y = 3, ground_h do buf:put(x, y, z, palette.node("wall")) end
			end
		end
		for _, p in ipairs({2, 6}) do
			for _, side in ipairs(SIDES) do
				local x, z = wall_cell(block, side, p)
				for y = 3, ground_h do
					parts.pane(buf, palette, x, y, z,
						(side == "z-" or side == "z+") and "x" or "z")
				end
				for _, frame in ipairs({p - 1, p + 1}) do
					local fx, fz = wall_cell(block, side, frame)
					for y = 1, ground_h do
						buf:put(fx, y, fz, palette.node("window_frame"))
					end
				end
			end
		end
		for _, corner in ipairs({{0, 0}, {w - 1, 0}, {0, d - 1}, {w - 1, d - 1}}) do
			for y = 1, plate do
				buf:put(corner[1], y, corner[2], palette.node("post"))
			end
		end

		-- Door on the road side.
		local door_side = spec.door_side or "x-"
		local face = inward(door_side)
		local dx, dz = wall_cell(block, door_side, 4)
		buf:clear(dx, 1, dz, dx, 2, dz)
		parts.door(buf, palette, dx, 1, dz, face, false)
		doors[#doors + 1] = {x = dx, y = 1, z = dz, face = face}
		for _, sign in ipairs({-1, 1}) do
			entry_torch(buf, palette, block, door_side, dx, dz, sign, 3, lights)
		end

		-- Guard room furniture, then the lookout deck with an open stairwell.
		local room = {x1 = 1, z1 = 1, x2 = w - 2, z2 = d - 2, y = 0, h = ground_h}
		local kit_lights = interiors.furnish("watch", buf, parts, palette, room, {})
		for _, light in ipairs(kit_lights) do lights[#lights + 1] = light end

		buf:fill(0, deck, 0, w - 1, deck, d - 1, palette.node("floor"))
		buf:clear(2, deck, 1, 2, deck, 6)
		for step_index = 0, 4 do
			parts.stair(buf, 2, 1 + step_index, 2 + step_index,
				palette.node("roof_stair"), 0)
		end

		-- Parapet, open viewing course, continuous plate and corner lamps.
		for _, side in ipairs(SIDES) do
			for index = 0, side_length(block, side) - 1 do
				local x, z = wall_cell(block, side, index)
				buf:put(x, deck + 1, z, palette.node("wall_accent"))
				buf:put(x, plate, z, palette.node("beam"))
			end
		end
		for _, p in ipairs({2, 4, 6}) do
			for _, side in ipairs(SIDES) do
				local x, z = wall_cell(block, side, p)
				buf:put(x, plate - 1, z, palette.node("railing"))
			end
		end
		for _, corner in ipairs({{1, 1}, {w - 2, 1}, {1, d - 2}, {w - 2, d - 2}}) do
			parts.floor_torch(buf, palette, corner[1], deck + 1, corner[2])
			lights[#lights + 1] = {x = corner[1], y = deck + 1, z = corner[2]}
		end

		local roof_top = roofs.raster(buf, spec.roof_palette or palette, field)

		local inside = spec.inside or {x = 5, y = deck + 1, z = 4}
		buf:clear(inside.x, inside.y, inside.z, inside.x, inside.y + 1, inside.z)

		return {
			buffer = buf, w = w, d = d, peak = roof_top,
			points = {
				doors = doors,
				lights = lights,
				inside = {{x = inside.x, y = inside.y, z = inside.z, id = spec.id}},
				room_corner = {
					{x = 1, y = 0, z = 1, top = ground_h, closed = true,
						id = spec.id},
					{x = w - 2, y = 0, z = d - 2},
				},
			},
		}
	end

	return M
end

return loader
