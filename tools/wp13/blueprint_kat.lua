-- Compact architectural acceptance, usable in the final interpreter pair.
--
-- Checks the generator invariants of
-- docs/research/wp13-settlement-pipeline.md section 5 against the finished
-- Hearthpine blueprint, without loading the engine.
return function(repo)
	local build = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua")
	local blueprint = build()
	assert(blueprint.schema == "grug_wp13_hearthpine_blueprint_v1")
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
		if (cell.name == "default:torch" or cell.name == "default:torch_wall") then lights = lights + 1 end
		if cell.param2 ~= 0 then oriented = oriented + 1 end
	end
	assert(#blueprint.cells < 125000 and count > 1000, "bounded inhabited architecture")
	assert(lights >= 8 and oriented >= 8, "lighting and shaped architecture missing")
	local palette_count = 0
	for name in pairs(names) do palette_count = palette_count + 1 end
	assert(palette_count == #blueprint.palette)
	for i, name in ipairs(blueprint.palette) do
		assert(names[name] and (i == 1 or blueprint.palette[i - 1] < name))
	end
	local function node(x, y, z)
		return cells[key(x, y, z)] or (y <= 0 and "default:stone" or "air")
	end
	-- Nodes an ordinary walk can pass through. Stairs and slabs count as whole
	-- nodes, which keeps the route check conservative; doors count as
	-- passable, because a player opens them (section 5 invariant 3).
	local PASSABLE = {["air"] = true, ["default:torch"] = true,
		["default:torch_wall"] = true, ["default:grass_1"] = true,
		["default:fern_1"] = true, ["default:fern_2"] = true,
		["doors:door_wood_a"] = true, ["doors:door_wood_b"] = true,
		["doors:hidden"] = true}
	local PAVED = {["default:cobble"] = true, ["default:stone_block"] = true,
		["default:stonebrick"] = true}
	-- Both roof materials: the forge hall and the community hall carry the
	-- stone-brick stair family, the rest pine.
	local ROOF = {["stairs:stair_pine_wood"] = true,
		["stairs:stair_outer_pine_wood"] = true,
		["stairs:stair_inner_pine_wood"] = true,
		["stairs:slab_pine_wood"] = true,
		["stairs:stair_stonebrick"] = true,
		["stairs:stair_outer_stonebrick"] = true,
		["stairs:stair_inner_stonebrick"] = true,
		["stairs:slab_stonebrick"] = true}
	local function solid(x, y, z)
		return not PASSABLE[node(x, y, z)]
	end
	local function stand(x, y, z)
		return solid(x, y - 1, z) and not solid(x, y, z) and not solid(x, y + 1, z)
	end
	-- Luanti's wallmounted direction points from the torch to its support.
	local support_dir = {[0] = {0, 1, 0}, {0, -1, 0}, {1, 0, 0},
		{-1, 0, 0}, {0, 0, 1}, {0, 0, -1}}
	for _, cell in ipairs(blueprint.cells) do
		if cell.name == "default:torch" or cell.name == "default:torch_wall" then
			local dir = assert(support_dir[cell.param2], "unsupported torch rotation")
			assert(solid(cell.x + dir[1], cell.y + dir[2], cell.z + dir[3]),
				"floating torch at " .. key(cell.x, cell.y, cell.z))
		end
	end
	local declared_lights = {}
	for _, pos in ipairs(blueprint.landmarks.lights) do
		local address = key(pos.x, pos.y, pos.z)
		assert(not declared_lights[address], "duplicate light landmark")
		declared_lights[address] = true
		local name = node(pos.x, pos.y, pos.z)
		assert(name == "default:torch" or name == "default:torch_wall",
			"light landmark has no torch")
	end
	assert(#blueprint.landmarks.lights == lights, "light landmark population differs")
	assert(solid(0, 0, 0) and stand(0, 1, 0) and not solid(0, 3, 0))
	-- The road is a five-wide clear route rather than a one-cell cosmetic line.
	for z = 0, 63 do
		for x = -2, 2 do assert(stand(x, 1, z), "blocked north road") end
	end

	-- Section 5 invariant 2: every door is a real, usable doorway.
	local facedir = {[0] = {0, 1}, {1, 0}, {0, -1}, {-1, 0}}
	local doorways = assert(blueprint.landmarks.doors, "no door landmarks")
	assert(#doorways >= 8, "every ordinary building needs a door")
	for _, door in ipairs(doorways) do
		local name = node(door.x, door.y, door.z)
		assert(name == "doors:door_wood_a" or name == "doors:door_wood_b",
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
		-- The leaf sits in the wall: the jambs to either side are wall or the
		-- second leaf of a double door, and the way through is open.
		local function jamb(jx, jz)
			local jamb_name = node(jx, door.y, jz)
			return solid(jx, door.y, jz) or jamb_name == "doors:door_wood_a" or
				jamb_name == "doors:door_wood_b"
		end
		assert(jamb(door.x + step[2], door.z - step[1]) and
			jamb(door.x - step[2], door.z + step[1]),
			"door orientation does not match its wall")
	end

	-- Section 5 invariant 4 plus the lit-interior rule, per authored room.
	local rooms = assert(blueprint.landmarks.rooms, "no room landmarks")
	assert(#rooms >= 9, "every building needs a room")
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
		-- The eaves land on a full node: no half-node gap over any wall that
		-- actually exists (an open-sided workyard has none to check).
		if room.closed then
			for z = room.min.z - 1, room.max.z + 1 do
				for x = room.min.x - 1, room.max.x + 1 do
					if x == room.min.x - 1 or x == room.max.x + 1 or
							z == room.min.z - 1 or z == room.max.z + 1 then
						if node(x, 1, z) ~= "air" then
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

	-- Every authored pine stands on an unbroken stem that starts on the
	-- ground, and no needle floats away from one.
	local trunks, stems = {}, 0
	for _, cell in ipairs(blueprint.cells) do
		if cell.name == "default:pine_tree" and cell.y == 1 then
			local top = 1
			while node(cell.x, top + 1, cell.z) == "default:pine_tree" do
				top = top + 1
			end
			if node(cell.x, top + 1, cell.z) == "default:pine_needles" then
				assert(top >= 5, "authored pine has a short or broken trunk")
				trunks[cell.x .. ":" .. cell.z] = top
				stems = stems + 1
			end
		end
	end
	assert(stems > 40, "the pine vale lost its wood")
	for _, cell in ipairs(blueprint.cells) do
		if cell.name == "default:pine_needles" then
			local rooted = false
			for dz = -2, 2 do
				for dx = -2, 2 do
					local top = trunks[(cell.x + dx) .. ":" .. (cell.z + dz)]
					if top and cell.y >= top - 4 and cell.y <= top + 1 then
						rooted = true
					end
				end
			end
			assert(rooted, "floating pine needles at " .. key(cell.x, cell.y, cell.z))
		end
	end

	local ground = { ["default:dirt"] = 0,
		["default:dirt_with_coniferous_litter"] = 0,
		["default:dirt_with_grass"] = 0 }
	for z = -63, 63 do
		for x = -63, 63 do
			local name = node(x, 0, z)
			if ground[name] then ground[name] = ground[name] + 1 end
		end
	end
	assert(ground["default:dirt_with_coniferous_litter"] > 8000 and
		ground["default:dirt_with_grass"] > 100 and ground["default:dirt"] > 50,
		"natural ground must dominate the spaces between plots")
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
					if y >= 1 and y <= 24 and not visited[address] and stand(x, y, z) and
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
	assert(#destinations >= 9, "all nine buildings need reachable interiors")
	for _, pos in ipairs(destinations) do
		assert(visited[key(pos.x, pos.y, pos.z)], "unreachable interior: " .. pos.id)
	end
	-- A second construction cannot depend on table iteration order or RNG state.
	local again = build()
	assert(#again.cells == #blueprint.cells)
	for i, cell in ipairs(blueprint.cells) do
		local other = again.cells[i]
		for _, field in ipairs({"x", "y", "z", "name", "param2"}) do
			assert(cell[field] == other[field], "non-deterministic architecture")
		end
	end
	return table.concat({"wp13_blueprint", #blueprint.cells, count,
		palette_count, lights, oriented, #destinations, #doorways, #rooms,
		stems, #queue}, "\t") .. "\n"
end
