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
							for y = 2, top do
								buf:put(x, y, z, palette.node("wall"))
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

	-- The identity building: a cross gabled forge hall whose smithy wing
	-- meets the main roof in two valleys.
	function M.workshop(palette, spec)
		local w, d = spec.w or 11, spec.d or 15
		local wing = spec.wing or 7
		local wall_h = spec.wall_h or 5
		local wz = math.floor((d - wing) / 2)
		return M.build(palette, {
			id = spec.id, overhang = 1, roof_palette = spec.roof_palette,
			blocks = {
				{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1, wall_h = wall_h,
					roof = "gable", ridge_axis = "z", rise = 4,
					kit = "workshop"},
				{x0 = w - 2, z0 = wz, x1 = w - 2 + wing - 1, z1 = wz + wing - 1,
					wall_h = wall_h, roof = "gable", ridge_axis = "x", rise = 3,
					kit = "smithy"},
			},
			chimneys = {{x = math.floor(w / 2), z = 0},
				{x = w - 2 + wing - 1, z = wz + 1}},
			doors = {{side = spec.door_side or "z+", index = math.floor(w / 2),
				double = true}},
			inside = spec.inside or {x = 2, y = 1, z = d - 4},
		})
	end

	-- The community hall: the largest ordinary building, hip roofed.
	function M.hall(palette, spec)
		local w, d = spec.w or 13, spec.d or 15
		local wall_h = spec.wall_h or 5
		return M.build(palette, {
			id = spec.id, overhang = 1, roof_palette = spec.roof_palette,
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
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1, wall_h = wall_h,
				roof = "saltbox", ridge_axis = "z", lift = 2, rise = 3,
				kit = "store"}},
			doors = {{side = spec.door_side or "z-", index = math.floor(w / 2)}},
			inside = spec.inside or {x = math.floor(w / 2), y = 1, z = 2},
		})
	end

	-- The timber workyard: open on two sides, roof carried on log posts.
	function M.shed(palette, spec)
		local w, d = spec.w or 13, spec.d or 9
		local wall_h = spec.wall_h or 4
		return M.build(palette, {
			id = spec.id, overhang = 1, roof_palette = spec.roof_palette,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1, wall_h = wall_h,
				roof = "gable", ridge_axis = "x", rise = 3, kit = "yard",
				open_sides = spec.open_sides or {"z-", "x+"}}},
			doors = {},
			inside = spec.inside or {x = 2, y = 1, z = math.floor(d / 2)},
		})
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

		local roof_top = roofs.raster(buf, palette, field)

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
