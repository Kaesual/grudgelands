-- Compact architectural acceptance, usable in the final interpreter pair.
--
-- Checks the generator invariants of
-- docs/research/wp13-settlement-pipeline.md section 5 against every finished
-- WP13 start blueprint, without loading the engine.
--
-- The invariants are the same for every settlement; the node vocabulary is
-- not, so each start carries a spec naming the nodes an ordinary walk passes
-- through, the nodes a doorstep may stand on, the roof family, the tree
-- species and the ground mix its identity depends on. Adding a start means
-- adding a spec, not a second copy of the checks.
return function(repo)
	local SETTLEMENTS = {
		{
			key = "hearthpine",
			file = "r7_hearthpine_blueprint.lua",
			schema = "grug_wp13_hearthpine_blueprint_v1",
			light = {"default:torch", "default:torch_wall"},
			passable = {"air", "default:torch", "default:torch_wall",
				"default:grass_1", "default:fern_1", "default:fern_2",
				"doors:door_wood_a", "doors:door_wood_b", "doors:hidden"},
			paved = {"default:cobble", "default:stone_block",
				"default:stonebrick"},
			-- Both roof materials: the forge hall and the community hall carry
			-- the stone-brick stair family, the rest pine.
			roof = {"stairs:stair_pine_wood", "stairs:stair_outer_pine_wood",
				"stairs:stair_inner_pine_wood", "stairs:slab_pine_wood",
				"stairs:stair_stonebrick", "stairs:stair_outer_stonebrick",
				"stairs:stair_inner_stonebrick", "stairs:slab_stonebrick"},
			door_leaves = {"doors:door_wood_a", "doors:door_wood_b"},
			tree = {log = "default:pine_tree", leaves = "default:pine_needles",
				min_trunk = 5, reach = 2, low = 4, high = 1, min_stems = 40},
			ground = {{"default:dirt_with_coniferous_litter", 8000},
				{"default:dirt_with_grass", 100}, {"default:dirt", 50}},
			min_destinations = 9, min_doors = 8, min_rooms = 9,
			min_lights = 8, min_oriented = 8,
		},
		{
			key = "dawnmere",
			file = "r7_dawnmere_blueprint.lua",
			schema = "grug_wp13_dawnmere_blueprint_v1",
			light = {"default:torch", "default:torch_wall"},
			passable = {"air", "default:torch", "default:torch_wall",
				"default:grass_3", "default:grass_4", "default:junglegrass",
				"default:fern_1", "grug_decor:cottages_straw_mat",
				"doors:door_wood_a", "doors:door_wood_b", "doors:hidden"},
			paved = {"default:cobble", "default:brick"},
			roof = {"stairs:stair_wood", "stairs:stair_outer_wood",
				"stairs:stair_inner_wood", "stairs:slab_wood",
				"stairs:stair_brick", "stairs:stair_outer_brick",
				"stairs:stair_inner_brick", "stairs:slab_brick"},
			door_leaves = {"doors:door_wood_a", "doors:door_wood_b"},
			tree = {log = "default:tree", leaves = "default:leaves",
				min_trunk = 4, reach = 3, low = 1, high = 4, min_stems = 8},
			ground = {{"default:dirt_with_grass", 6000},
				{"default:dirt", 400}, {"default:gravel", 20}},
			min_destinations = 9, min_doors = 8, min_rooms = 9,
			min_lights = 8, min_oriented = 8,
		},
		{
			key = "kapok",
			file = "r7_kapok_blueprint.lua",
			schema = "grug_wp13_kapok_blueprint_v1",
			light = {"default:torch", "default:torch_wall"},
			-- The rope and the lantern really are `walkable = false`, so a
			-- route may pass through them; the window bars are not, so they
			-- stay solid and keep counting as wall.
			passable = {"air", "default:torch", "default:torch_wall",
				"default:grass_1", "default:fern_1", "default:junglegrass",
				"grug_decor:cottages_straw_mat", "grug_decor:xdecor_lantern",
				"grug_decor:xdecor_rope",
				"doors:door_wood_a", "doors:door_wood_b", "doors:hidden"},
			-- A stilt village's doorsteps stand on plank verandas and the
			-- lodge's on its basalt platform, so both count as paving.
			paved = {"default:junglewood", "default:mossycobble",
				"grug_decor:darkage_basalt_brick",
				"grug_decor:darkage_serpentine"},
			roof = {"stairs:stair_junglewood", "stairs:stair_outer_junglewood",
				"stairs:stair_inner_junglewood", "stairs:slab_junglewood"},
			door_leaves = {"doors:door_wood_a", "doors:door_wood_b"},
			-- A jungle tree carries its crown in the top three courses over a
			-- long bare trunk and hangs leaf spurs far below it, and an
			-- emergent's crown stands four courses above its last log, so the
			-- rooting window is deeper and taller than an orchard's.
			tree = {log = "default:jungletree", leaves = "default:jungleleaves",
				min_trunk = 8, reach = 3, low = 10, high = 8, min_stems = 20},
			ground = {{"default:dirt_with_rainforest_litter", 6000},
				{"grug_nodes:mud", 1000}, {"default:dirt", 100}},
			min_destinations = 8, min_doors = 8, min_rooms = 8,
			min_lights = 8, min_oriented = 8,
		},
	}

	local function set(list)
		local out = {}
		for _, name in ipairs(list) do out[name] = true end
		return out
	end

	local report = {}
	for _, spec in ipairs(SETTLEMENTS) do
		local build = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/" .. spec.file)
		local blueprint = build()
		assert(blueprint.schema == spec.schema)
		local LIGHT = set(spec.light)
		local PASSABLE = set(spec.passable)
		local PAVED = set(spec.paved)
		local ROOF = set(spec.roof)
		local LEAF = set(spec.door_leaves)
		local cells, names, count, lights, oriented = {}, {}, 0, 0, 0
		local function key(x, y, z) return x .. ":" .. y .. ":" .. z end
		local previous
		for _, cell in ipairs(blueprint.cells) do
			assert(cell.x % 1 == 0 and cell.y % 1 == 0 and cell.z % 1 == 0)
			assert(cell.x >= -63 and cell.x <= 63 and cell.z >= -63 and cell.z <= 63)
			assert(cell.y >= -2 and cell.y <= 24)
			assert(cell.param2 % 1 == 0 and cell.param2 >= 0 and cell.param2 <= 255)
			assert(type(cell.name) == "string" and cell.name ~= "ignore")
			assert(cell.name ~= "grug_nodes:guard_banner" and
				cell.name ~= "grug_nodes:camp_fire", "decorative spawner")
			assert(not cell.name:find("water") and not cell.name:find("lava"))
			local address = key(cell.x, cell.y, cell.z)
			assert(not cells[address], "duplicate blueprint cell")
			if previous then
				assert(previous.z < cell.z or previous.z == cell.z and
					(previous.y < cell.y or previous.y == cell.y and previous.x < cell.x),
					"blueprint order differs")
			end
			previous = cell
			cells[address] = cell.name
			names[cell.name] = true
			if cell.name ~= "air" then count = count + 1 end
			if LIGHT[cell.name] then lights = lights + 1 end
			if cell.param2 ~= 0 then oriented = oriented + 1 end
		end
		assert(#blueprint.cells < 125000 and count > 1000,
			"bounded inhabited architecture")
		assert(lights >= spec.min_lights and oriented >= spec.min_oriented,
			"lighting and shaped architecture missing")
		local palette_count = 0
		for name in pairs(names) do palette_count = palette_count + 1 end
		assert(palette_count == #blueprint.palette)
		for i, name in ipairs(blueprint.palette) do
			assert(names[name] and (i == 1 or blueprint.palette[i - 1] < name))
		end
		local function node(x, y, z)
			return cells[key(x, y, z)] or (y <= 0 and "default:stone" or "air")
		end
		-- Nodes an ordinary walk can pass through. Stairs and slabs count as
		-- whole nodes, which keeps the route check conservative; doors count
		-- as passable, because a player opens them (section 5 invariant 3).
		local function solid(x, y, z)
			return not PASSABLE[node(x, y, z)]
		end
		local function stand(x, y, z)
			return solid(x, y - 1, z) and not solid(x, y, z) and
				not solid(x, y + 1, z)
		end
		-- Luanti's wallmounted direction points from the torch to its support.
		local support_dir = {[0] = {0, 1, 0}, {0, -1, 0}, {1, 0, 0},
			{-1, 0, 0}, {0, 0, 1}, {0, 0, -1}}
		for _, cell in ipairs(blueprint.cells) do
			if LIGHT[cell.name] then
				local dir = assert(support_dir[cell.param2],
					"unsupported torch rotation")
				assert(solid(cell.x + dir[1], cell.y + dir[2], cell.z + dir[3]),
					"floating torch at " .. key(cell.x, cell.y, cell.z))
			end
		end
		local declared_lights = {}
		for _, pos in ipairs(blueprint.landmarks.lights) do
			local address = key(pos.x, pos.y, pos.z)
			assert(not declared_lights[address], "duplicate light landmark")
			declared_lights[address] = true
			assert(LIGHT[node(pos.x, pos.y, pos.z)], "light landmark has no torch")
		end
		assert(#blueprint.landmarks.lights == lights,
			"light landmark population differs")
		assert(solid(0, 0, 0) and stand(0, 1, 0) and not solid(0, 3, 0))
		-- The road is a five-wide clear route, not a cosmetic line. Which way
		-- it runs is the start's own business: an Elandor start exits north
		-- and a Kragmar one south, so the route is read off the settlement's
		-- `main_street` landmark instead of being assumed to lie on +z.
		local street = assert(blueprint.landmarks.main_street,
			"no main street landmark")
		assert(street.max.x - street.min.x == 4 and
			(street.max.z - street.min.z) >= 63, "main street is not the route")
		for z = street.min.z, street.max.z do
			for x = street.min.x, street.max.x do
				assert(stand(x, 1, z), "blocked main road")
			end
		end

		-- Section 5 invariant 2: every door is a real, usable doorway.
		local facedir = {[0] = {0, 1}, {1, 0}, {0, -1}, {-1, 0}}
		local doorways = assert(blueprint.landmarks.doors, "no door landmarks")
		assert(#doorways >= spec.min_doors, "every building needs a door")
		for _, door in ipairs(doorways) do
			assert(LEAF[node(door.x, door.y, door.z)],
				"door landmark is not a door")
			assert(node(door.x, door.y + 1, door.z) == "doors:hidden",
				"door has no hidden upper node")
			local step = facedir[door.face]
			assert(step, "door landmark has no orientation")
			local ix, iz = door.x + step[1], door.z + step[2]
			local ox, oz = door.x - step[1], door.z - step[2]
			assert(stand(ix, door.y, iz), "door's inside foot is not standable")
			assert(stand(ox, door.y, oz), "door's outside foot is not standable")
			assert(PAVED[node(ox, door.y - 1, oz)],
				"door's outside foot is not on a path or plaza")
			local function jamb(jx, jz)
				return solid(jx, door.y, jz) or LEAF[node(jx, door.y, jz)]
			end
			assert(jamb(door.x + step[2], door.z - step[1]) and
				jamb(door.x - step[2], door.z + step[1]),
				"door orientation does not match its wall")
		end

		-- Section 5 invariant 4 plus the lit-interior rule, per authored room.
		local rooms = assert(blueprint.landmarks.rooms, "no room landmarks")
		assert(#rooms >= spec.min_rooms, "every building needs a room")
		-- A cell inside SOME room is never an eave: a building whose wing
		-- shares a wall with its main block has ring cells that fall inside
		-- the main room, and the roof above those is a roof over a room, not
		-- an unsupported eave.
		local function indoors(x, z)
			for _, room in ipairs(rooms) do
				if x >= room.min.x and x <= room.max.x and
						z >= room.min.z and z <= room.max.z then
					return true
				end
			end
			return false
		end
		for _, room in ipairs(rooms) do
			local lit = 0
			for z = room.min.z, room.max.z do
				for x = room.min.x, room.max.x do
					local covered = false
					for y = room.top + 1, 24 do
						if node(x, y, z) ~= "air" then covered = true end
						if declared_lights[key(x, y, z)] then lit = lit + 1 end
					end
					for y = 1, room.top do
						if declared_lights[key(x, y, z)] then lit = lit + 1 end
					end
					assert(covered, "interior column open to the sky in " .. room.id)
				end
			end
			assert(lit > 0, "unlit interior in " .. room.id)
			-- The eaves land on a full node: no half-node gap over any wall
			-- that actually exists (an open-sided workyard has none to check).
			if room.closed then
				for z = room.min.z - 1, room.max.z + 1 do
					for x = room.min.x - 1, room.max.x + 1 do
						if x == room.min.x - 1 or x == room.max.x + 1 or
								z == room.min.z - 1 or z == room.max.z + 1 then
							if node(x, 1, z) ~= "air" and not indoors(x, z) then
								local eave
								for y = room.top, 24 do
									if ROOF[node(x, y, z)] then eave = y break end
								end
								if eave then
									assert(node(x, eave - 1, z) ~= "air",
										"roof lacks a bearing at " .. key(x, eave, z))
								end
							end
						end
					end
				end
			end
		end

		-- Every authored tree stands on an unbroken stem that starts on the
		-- ground, and no leaf floats away from one.
		local tree = spec.tree
		local trunks, stems = {}, 0
		for _, cell in ipairs(blueprint.cells) do
			if cell.name == tree.log and cell.y == 1 then
				local top = 1
				while node(cell.x, top + 1, cell.z) == tree.log do top = top + 1 end
				if node(cell.x, top + 1, cell.z) == tree.leaves then
					assert(top >= tree.min_trunk,
						"authored tree has a short or broken trunk")
					trunks[cell.x .. ":" .. cell.z] = top
					stems = stems + 1
				end
			end
		end
		assert(stems >= tree.min_stems, "the settlement lost its trees")
		for _, cell in ipairs(blueprint.cells) do
			if cell.name == tree.leaves then
				local rooted = false
				for dz = -tree.reach, tree.reach do
					for dx = -tree.reach, tree.reach do
						local top = trunks[(cell.x + dx) .. ":" .. (cell.z + dz)]
						if top and cell.y >= top - tree.low and
								cell.y <= top + tree.high then
							rooted = true
						end
					end
				end
				assert(rooted, "floating leaves at " .. key(cell.x, cell.y, cell.z))
			end
		end

		local ground = {}
		for _, row in ipairs(spec.ground) do ground[row[1]] = 0 end
		for z = -63, 63 do
			for x = -63, 63 do
				local name = node(x, 0, z)
				if ground[name] then ground[name] = ground[name] + 1 end
			end
		end
		for _, row in ipairs(spec.ground) do
			assert(ground[row[1]] > row[2], "natural ground must dominate the " ..
				"spaces between plots: " .. row[1] .. " is " .. ground[row[1]])
		end

		local queue, visited = {{x = 0, y = 1, z = 0}}, {[key(0, 1, 0)] = true}
		local cursor = 1
		local directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		while cursor <= #queue do
			local pos = queue[cursor]
			cursor = cursor + 1
			for _, offset in ipairs(directions) do
				local x, z = pos.x + offset[1], pos.z + offset[2]
				if x >= -63 and x <= 63 and z >= -63 and z <= 63 then
					for dy = -1, 1 do
						local y = pos.y + dy
						local address = key(x, y, z)
						if y >= 1 and y <= 24 and not visited[address] and
								stand(x, y, z) and
								(dy <= 0 or not solid(pos.x, pos.y + 2, pos.z)) and
								(dy >= 0 or not solid(x, pos.y + 1, z)) then
							visited[address] = true
							queue[#queue + 1] = {x = x, y = y, z = z}
						end
					end
				end
			end
		end
		local destinations = assert(blueprint.landmarks.destinations)
		assert(#destinations >= spec.min_destinations,
			"every building needs a reachable interior")
		for _, pos in ipairs(destinations) do
			assert(visited[key(pos.x, pos.y, pos.z)],
				"unreachable interior: " .. pos.id)
		end
		-- A second construction cannot depend on table iteration order or RNG.
		local again = build()
		assert(#again.cells == #blueprint.cells)
		for i, cell in ipairs(blueprint.cells) do
			local other = again.cells[i]
			for _, field in ipairs({"x", "y", "z", "name", "param2"}) do
				assert(cell[field] == other[field], "non-deterministic architecture")
			end
		end
		report[#report + 1] = table.concat({"wp13_blueprint", spec.key,
			#blueprint.cells, count, palette_count, lights, oriented,
			#destinations, #doorways, #rooms, stems, #queue}, "\t") .. "\n"
	end
	return table.concat(report)
end
