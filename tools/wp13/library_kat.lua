-- WP13 building library KAT: palette binding, roof rasterising and, above
-- all, rotation.
--
-- Rotation is the semantic core of `wp13/parts.lua`: a part authored once
-- must place correctly at all four rotations, and WP13 writes raw nodes
-- through VoxelManip, so every param2 has to be exactly what the engine's own
-- `on_place` would have written. This KAT therefore re-derives orientation
-- from direction vectors rather than from the index arithmetic under test:
--
--   a stair's raised half must point the rotated way,
--   a wall torch must still point at a solid node,
--   a door's hidden upper node must keep the pairing `doors` places,
--   a bed's head must stay one step along its own facedir,
--   a pane must stay in the plane of the wall it sits in.
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.

return function(repo)
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local parts = dofile(wp13 .. "/parts.lua")
	local palettes = dofile(wp13 .. "/palette.lua")
	local roofs = dofile(wp13 .. "/roofs.lua")
	local buildings = dofile(wp13 .. "/buildings.lua")(wp13)

	local report = {}
	local function say(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end

	-- Independent direction model -------------------------------------------
	-- core.facedir_to_dir for the upright family, and the wallmounted table
	-- that points from a node to its support.
	local FACEDIR_DIR = {[0] = {0, 1}, [1] = {1, 0}, [2] = {0, -1}, [3] = {-1, 0}}
	local WALL_DIR = {[0] = {0, 1, 0}, [1] = {0, -1, 0}, [2] = {1, 0, 0},
		[3] = {-1, 0, 0}, [4] = {0, 0, 1}, [5] = {0, 0, -1}}

	-- One quarter turn about +Y: local +Z becomes world +X.
	local function turn(dx, dz)
		return dz, -dx
	end
	local function turn_n(dx, dz, times)
		for _ = 1, times % 4 do dx, dz = turn(dx, dz) end
		return dx, dz
	end

	-- 1. param2 arithmetic against the direction model ----------------------
	for param2 = 0, 3 do
		for turns = 0, 3 do
			local rotated = parts.rotate_param2(param2, parts.FACEDIR, turns)
			local base = FACEDIR_DIR[param2]
			local ex, ez = turn_n(base[1], base[2], turns)
			local got = FACEDIR_DIR[rotated]
			assert(got[1] == ex and got[2] == ez,
				"facedir rotation differs at " .. param2 .. "/" .. turns)
		end
		assert(parts.rotate_param2(param2, parts.FACEDIR, 4) == param2)
	end
	-- The upside-down family turns the other way, because flipping about a
	-- horizontal axis reverses the sense of Y.
	for rot = 0, 3 do
		local value = 20 + rot
		local once = parts.rotate_param2(value, parts.FACEDIR, 1)
		assert(once >= 20 and once <= 23, "upside-down family escaped")
		assert(parts.rotate_param2(value, parts.FACEDIR, 4) == value)
		assert(parts.rotate_param2(once, parts.FACEDIR, 3) == value)
	end
	for param2 = 0, 5 do
		for turns = 0, 3 do
			local rotated = parts.rotate_param2(param2, parts.WALLMOUNTED, turns)
			local base = WALL_DIR[param2]
			local ex, ez = turn_n(base[1], base[3], turns)
			local got = WALL_DIR[rotated]
			assert(got[1] == ex and got[2] == base[2] and got[3] == ez,
				"wallmounted rotation differs at " .. param2 .. "/" .. turns)
		end
	end
	say("rotate_param2", "facedir+upsidedown+wallmounted", "pass")

	-- 2. footprint rotation is a bijection onto the rotated rectangle -------
	for _, size in ipairs({{9, 7}, {13, 15}, {4, 4}}) do
		local w, d = size[1], size[2]
		for turns = 0, 3 do
			local seen, count = {}, 0
			local rw = (turns % 2 == 1) and d or w
			local rd = (turns % 2 == 1) and w or d
			for z = 0, d - 1 do
				for x = 0, w - 1 do
					local rx, rz = parts.rotate_footprint(x, z, w, d, turns)
					assert(rx >= 0 and rx < rw and rz >= 0 and rz < rd,
						"rotated footprint escaped its rectangle")
					local key = rx .. ":" .. rz
					assert(not seen[key], "rotated footprint is not injective")
					seen[key] = true
					count = count + 1
				end
			end
			assert(count == w * d)
		end
	end
	say("rotate_footprint", "bijective", "pass")

	-- 3. palette binding ----------------------------------------------------
	local palette = palettes.new("dwarf")
	for _, role in ipairs(palettes.required) do
		assert(type(palette.node(role)) == "string" and palette.node(role) ~= "")
	end
	assert(not pcall(palettes.new, "no_such_race"))
	assert(not pcall(palette.node, "no_such_role"))
	palettes.races.broken_race = {wall = "default:pine_wood"}
	assert(not pcall(palettes.new, "broken_race"), "unbound role accepted")
	palettes.races.broken_race = nil
	say("palette", "dwarf", #palettes.required)

	-- 4. the roof rasteriser produces the corner shapes it claims -----------
	local function raster_names(field)
		local buf = parts.buffer()
		roofs.raster(buf, palette, field)
		local map = {}
		local order, count = buf:cells()
		for index = 1, count do
			local cell = order[index]
			map[cell.x .. ":" .. cell.z] = cell
		end
		return map
	end
	local hip = raster_names(roofs.hip({x0 = 0, x1 = 8, z0 = 0, z1 = 8,
		base = 4}))
	local outer_name = palette.node("roof_stair_outer")
	local corner_param2 = {["0:0"] = 1, ["8:0"] = 0, ["8:8"] = 3, ["0:8"] = 2}
	for key, expect in pairs(corner_param2) do
		local cell = hip[key]
		assert(cell.name == outer_name and cell.param2 == expect,
			"hip corner differs at " .. key)
	end
	assert(hip["4:0"].name == palette.node("roof_stair") and hip["4:0"].param2 == 0)
	assert(hip["0:4"].name == palette.node("roof_stair") and hip["0:4"].param2 == 1)
	assert(hip["4:8"].param2 == 2 and hip["8:4"].param2 == 3)
	assert(hip["4:4"].name == palette.node("roof_slab"), "hip peak is not a ridge")
	-- A cross gable: the union of two roofs has valleys, and a valley cell is
	-- an inner corner stair.
	local cross = raster_names(roofs.combine({
		roofs.gable({x0 = 0, x1 = 12, z0 = 0, z1 = 8, base = 4, axis = "x"}),
		roofs.gable({x0 = 4, x1 = 12, z0 = 0, z1 = 16, base = 4, axis = "z"}),
	}))
	local inner_name = palette.node("roof_stair_inner")
	local inner_count = 0
	for _, cell in pairs(cross) do
		if cell.name == inner_name then inner_count = inner_count + 1 end
	end
	assert(inner_count > 0, "a cross gable produced no inner corner stairs")
	say("roofs", "hip_corners+cross_gable_valleys", inner_count)

	-- 5. a whole building at all four rotations ----------------------------
	local reference = buildings.cottage(palette, {id = "kat", w = 9, d = 9,
		roof = "gable", ridge_axis = "x", door_side = "z-"})
	local door_base = palette.node("door")
	local hidden = palette.node("door_hidden")
	local bed_base = palette.node("bed")
	local torch_wall = palette.node("light_wall")
	local torch_post = palette.node("light_post")
	local stair_names = {[palette.node("roof_stair")] = true,
		[palette.node("roof_stair_outer")] = true,
		[palette.node("roof_stair_inner")] = true}
	local pane = palette.node("window")

	local signature, kinds
	local total_doors, total_torches, total_stairs = 0, 0, 0
	for turns = 0, 3 do
		local target = parts.buffer()
		local points = parts.stamp(target, reference, 100, 0, 200, turns)
		local order, count = target:cells()
		local map, census = {}, {}
		for index = 1, count do
			local cell = order[index]
			map[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell
			census[cell.name] = (census[cell.name] or 0) + 1
		end
		local function node(x, y, z)
			local cell = map[x .. ":" .. y .. ":" .. z]
			return cell and cell.name or "air"
		end
		local function solid(x, y, z)
			local name = node(x, y, z)
			return name ~= "air" and name:sub(1, 13) ~= "default:torch" and
				name:sub(1, 13) ~= "default:grass" and
				name:sub(1, 12) ~= "default:fern"
		end

		local doors_here, torches_here, stairs_here = 0, 0, 0
		for index = 1, count do
			local cell = order[index]
			if cell.name == door_base .. "_a" or cell.name == door_base .. "_b" then
				doors_here = doors_here + 1
				-- The hidden upper node is exactly what `doors` places.
				local above = map[cell.x .. ":" .. (cell.y + 1) .. ":" .. cell.z]
				assert(above and above.name == hidden, "door lost its hidden node")
				local expect = cell.param2
				if cell.name:sub(-2) == "_b" then expect = (cell.param2 + 3) % 4 end
				assert(above.param2 == expect, "hidden node param2 differs")
				-- The leaf faces out of the wall: the two cells along the
				-- door's own axis are open, the two beside it are wall.
				local step = FACEDIR_DIR[cell.param2]
				assert(not solid(cell.x + step[1], cell.y, cell.z + step[2]),
					"door has no inside")
				assert(not solid(cell.x - step[1], cell.y, cell.z - step[2]),
					"door has no outside")
				assert(solid(cell.x + step[2], cell.y, cell.z - step[1]) and
					solid(cell.x - step[2], cell.y, cell.z + step[1]),
					"door does not sit in a wall")
			elseif cell.name == torch_wall or cell.name == torch_post then
				torches_here = torches_here + 1
				local dir = WALL_DIR[cell.param2]
				assert(dir, "torch has no wallmounted direction")
				assert(solid(cell.x + dir[1], cell.y + dir[2], cell.z + dir[3]),
					"rotated torch lost its support")
			elseif stair_names[cell.name] then
				stairs_here = stairs_here + 1
				assert(cell.param2 >= 0 and cell.param2 <= 3,
					"roof stair left the upright facedir family")
			elseif cell.name == bed_base .. "_bottom" then
				local step = FACEDIR_DIR[cell.param2]
				local head = map[(cell.x + step[1]) .. ":" .. cell.y .. ":" ..
					(cell.z + step[2])]
				assert(head and head.name == bed_base .. "_top" and
					head.param2 == cell.param2, "bed halves came apart")
			elseif cell.name == pane then
				-- A flat pane spans the wall it sits in: param2 0 across x,
				-- param2 3 across z, matching `xpanes` update_pane.
				assert(cell.param2 == 0 or cell.param2 == 3, "pane param2 differs")
				if cell.param2 == 0 then
					assert(solid(cell.x - 1, cell.y, cell.z) and
						solid(cell.x + 1, cell.y, cell.z), "pane is not in an x wall")
				else
					assert(solid(cell.x, cell.y, cell.z - 1) and
						solid(cell.x, cell.y, cell.z + 1), "pane is not in a z wall")
				end
			end
		end
		assert(doors_here > 0 and torches_here > 0 and stairs_here > 0)

		-- The same building, so the same census of node kinds every time.
		local lines = {}
		for name, amount in pairs(census) do
			lines[#lines + 1] = name .. "=" .. amount
		end
		table.sort(lines)
		local text = table.concat(lines, ",")
		if signature == nil then
			signature, kinds = text, #lines
			total_doors, total_torches, total_stairs =
				doors_here, torches_here, stairs_here
		else
			assert(text == signature, "rotation changed the node census")
			assert(doors_here == total_doors and torches_here == total_torches and
				stairs_here == total_stairs, "rotation changed the part population")
		end

		-- Landmarks travel with the part.
		assert(#points.doors > 0, "door landmarks were lost in rotation")
		for _, door in ipairs(points.doors) do
			assert(map[door.x .. ":" .. door.y .. ":" .. door.z],
				"door landmark is not a cell")
		end
		local spot = points.inside[1]
		assert(node(spot.x, spot.y, spot.z) == "air", "destination is blocked")
	end
	say("rotation", "cottage", kinds, total_doors, total_torches, total_stairs)

	-- 6. two constructions of the same generator are identical --------------
	local again = buildings.cottage(palette, {id = "kat", w = 9, d = 9,
		roof = "gable", ridge_axis = "x", door_side = "z-"})
	local first, first_count = reference.buffer:cells()
	local second, second_count = again.buffer:cells()
	assert(first_count == second_count, "generator is not deterministic")
	for index = 1, first_count do
		local a, b = first[index], second[index]
		assert(a.x == b.x and a.y == b.y and a.z == b.z and a.name == b.name and
			a.param2 == b.param2, "generator is not deterministic")
	end
	say("determinism", "cottage", first_count)

	-- 7. the buffer refuses param2 on an unoriented node --------------------
	local guard = parts.buffer()
	assert(not pcall(guard.put, guard, 0, 0, 0, "default:cobble", 2))
	assert(not pcall(parts.rotate_param2, 2, parts.NONE, 1))
	assert(parts.rotate_param2(0, parts.NONE, 3) == 0)
	say("guards", "param2_kind", "pass")

	return table.concat(report)
end
