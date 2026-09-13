-- Compact architectural acceptance, usable in the final interpreter pair.
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
	local function solid(x, y, z)
		local name = node(x, y, z)
		-- Treat stairs/slabs as whole nodes: this conservatively checks routes
		-- that can be traversed by ordinary one-node stepping/jumping.
		return name ~= "air" and name ~= "default:torch" and
			name ~= "default:torch_wall" and name ~= "default:fern_1" and
			name ~= "default:grass_1"
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
	-- Exterior wall bearings must occupy the entire vertical node interval.
	-- A lower slab is walkable but leaves the reported half-node roof gap.
	for _, x1 in ipairs({-9, 4}) do
		for x = x1, x1 + 5 do
			for _, z in ipairs({51, 59}) do
				assert(node(x, 8, z) == "default:pine_wood" and
					node(x, 7, z) == "default:stonebrick",
					"guardpost roof lacks a continuous masonry bearing")
			end
		end
	end
	-- Pine clusters need a continuous stem, including crown layers.
	for _, pos in ipairs({{-60, -31}, {-34, -39}, {43, -34}, {58, 20}}) do
		for y = 1, 6 do
			assert(node(pos[1], y, pos[2]) == "default:pine_tree",
				"authored pine has a broken trunk")
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
		palette_count, lights, oriented, #destinations, #queue}, "\t") .. "\n"
end
