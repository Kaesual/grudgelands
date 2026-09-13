-- Portable Gravewood asset and authentic production-growth regression.

return function(repo, verify_compressed, production_repo)
	production_repo = production_repo or repo
	local decoded = dofile(repo .. "/tools/wp40/quality/gravewood_decoded.lua")
	local function check(condition, message)
		if not condition then error("gravewood fixture: " .. message, 0) end
	end
	local function key(x, y, z) return x .. ":" .. y .. ":" .. z end
	local function cell_index(size, x, y, z)
		return (z + 3) * size.y * size.x + y * size.x + (x + 3) + 1
	end
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local function portable_schematic(definition)
		local data = {}
		for index = 1, definition.size.x * definition.size.y * definition.size.z do
			data[index] = {name = "air", prob = 0, param2 = 0,
				force_place = false}
		end
		for _, pos in ipairs(definition.wood) do
			data[cell_index(definition.size, pos[1], pos[2], pos[3])] = {
				name = "grug_trees:gravewood_tree", prob = 254, param2 = 0,
				force_place = false}
		end
		for _, pos in ipairs(definition.leaves) do
			data[cell_index(definition.size, pos[1], pos[2], pos[3])] = {
				name = "grug_trees:gravewood_leaves", prob = 96, param2 = 0,
				force_place = false}
		end
		local slices = {}
		for y = 0, definition.size.y - 1 do
			slices[y + 1] = {ypos = y, prob = 254}
		end
		return {size = definition.size, data = data, yslice_prob = slices}
	end

	local schematics = {}
	for _, definition in ipairs(decoded) do
		local schematic = portable_schematic(definition)
		schematics[definition.filename] = schematic
		local path = production_repo .. "/mods/ITEMS/grug_trees/schematics/" ..
			definition.filename
		check(common.hex(common.new_sha256()(common.read_file(path))) ==
			definition.sha256, "MTS SHA differs: " .. definition.filename)
		check(#definition.wood == (definition.size.y == 7 and 17 or 23),
			"wood count differs: " .. definition.filename)
		check(#definition.leaves == (definition.size.y == 7 and 5 or 8),
			"leaf count differs: " .. definition.filename)
		local occupied, reached = {}, {[key(0, 0, 0)] = true}
		for _, pos in ipairs(definition.wood) do
			occupied[key(pos[1], pos[2], pos[3])] = true
		end
		local changed = true
		while changed do
			changed = false
			for _, pos in ipairs(definition.wood) do
				local own = key(pos[1], pos[2], pos[3])
				if not reached[own] then
					local adjacent = reached[key(pos[1] + 1, pos[2], pos[3])]
						or reached[key(pos[1] - 1, pos[2], pos[3])]
						or reached[key(pos[1], pos[2] + 1, pos[3])]
						or reached[key(pos[1], pos[2] - 1, pos[3])]
						or reached[key(pos[1], pos[2], pos[3] + 1)]
						or reached[key(pos[1], pos[2], pos[3] - 1)]
					if adjacent then reached[own], changed = true, true end
				end
			end
		end
		for wood_key in pairs(occupied) do
			check(reached[wood_key], "disconnected wood: " .. definition.filename)
		end
		for rotation = 0, 3 do
			local rotated, positions = {}, {}
			for _, pos in ipairs(definition.wood) do
				local x, z = pos[1], pos[3]
				for _ = 1, rotation do x, z = -z, x end
				if x == 0 then x = 0 end -- canonicalize LuaJIT's numeric -0
				if z == 0 then z = 0 end
				rotated[key(x, pos[2], z)] = true
				positions[#positions + 1] = {x, pos[2], z}
			end
			check(rotated[key(0, 0, 0)], "rotation lost root")
			local count = 0
			for _ in pairs(rotated) do count = count + 1 end
			check(count == #definition.wood, "rotation merged wood cells")
			local connected = {[key(0, 0, 0)] = true}
			changed = true
			while changed do
				changed = false
				for _, pos in ipairs(positions) do
					local own = key(pos[1], pos[2], pos[3])
					if not connected[own] and (
						connected[key(pos[1] + 1, pos[2], pos[3])] or
						connected[key(pos[1] - 1, pos[2], pos[3])] or
						connected[key(pos[1], pos[2] + 1, pos[3])] or
						connected[key(pos[1], pos[2] - 1, pos[3])] or
						connected[key(pos[1], pos[2], pos[3] + 1)] or
						connected[key(pos[1], pos[2], pos[3] - 1)]) then
						connected[own], changed = true, true
					end
				end
			end
			for rotated_key in pairs(rotated) do
				check(connected[rotated_key], "rotation disconnected wood")
			end
		end
		if verify_compressed then
			local actual = common.read_mts(path)
			check(actual.size.x == schematic.size.x and
				actual.size.y == schematic.size.y and actual.size.z == schematic.size.z,
				"MTS size differs: " .. definition.filename)
			for index = 1, #schematic.data do
				local left, right = actual.data[index], schematic.data[index]
				check(left.name == right.name and left.prob == right.prob and
					left.param2 == right.param2 and
					left.force_place == right.force_place,
					"MTS cell differs: " .. definition.filename .. "/" .. index)
			end
			for y = 1, schematic.size.y do
				check(actual.yslice_prob[y].prob == 254,
					"MTS y-slice differs: " .. definition.filename .. "/" .. y)
			end
		end
	end

	-- Exercise the production mapgen template-source router independently of
	-- the node-growth loader below.
	local source_reads = {}
	local source_api = {read_schematic = function(path, options)
		source_reads[#source_reads + 1] = {path = path, options = options}
		local filename = path:match("([^/]+)$")
		return schematics[filename] or {size = {x = 1, y = 1, z = 1}, data = {}}
	end}
	local source_environment = {vector = {metatable = {}}}
	setmetatable(source_environment, {__index = _G})
	local source_chunk = assert(loadfile(production_repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_template_source.lua"))
	setfenv(source_chunk, source_environment)
	local source = source_chunk()(source_api, "/base-schematics", "/gravewood")
	for _, definition in ipairs(decoded) do
		local value = source.read(definition.filename)
		local call = source_reads[#source_reads]
		check(call.path == "/gravewood/" .. definition.filename and
			call.options.write_yslice_prob == "all" and
			value.size.y == definition.size.y,
			"production template route differs: " .. definition.filename)
	end
	source.read("apple_tree.mts")
	check(source_reads[#source_reads].path == "/base-schematics/apple_tree.mts",
		"production default template route differs")

	-- Load the actual node module without writing fixture globals.
	local registered, leafdecays, growth = {}, {}, {}
	local placed, removed, failed = {}, {}, {}
	local world, random_values = {}, {}
	local fake_math = {}
	for name, value in pairs(math) do fake_math[name] = value end
	function fake_math.random(lower, upper)
		local value = table.remove(random_values, 1)
		check(value ~= nil, "unexpected math.random call")
		if upper then
			check(value >= lower and value <= upper, "random value out of range")
		else
			check(value >= 1 and value <= lower, "random value out of range")
		end
		return value
	end
	local api = {registered_nodes = {
		air = {buildable_to = true}, stone = {buildable_to = false},
		ignore = {buildable_to = true},
	}}
	function api.get_modpath(name)
		if name == "default" then return production_repo .. "/mods/BASE/default" end
		if name == "grug_trees" then return production_repo .. "/mods/ITEMS/grug_trees" end
	end
	function api.read_schematic(path)
		local filename = path:match("([^/]+)$")
		return schematics[filename] or {size = {x = 5, y = 13, z = 5}, data = {}}
	end
	function api.register_schematic(value) return value end
	function api.register_node(name, definition)
		registered[name] = definition
		api.registered_nodes[name] = definition
	end
	function api.register_craft() end
	function api.get_node(pos)
		return {name = world[key(pos.x, pos.y, pos.z)] or "air"}
	end
	function api.remove_node(pos) removed[#removed + 1] = key(pos.x, pos.y, pos.z) end
	function api.place_schematic(pos, handle, rotation, replacements, force)
		placed[#placed + 1] = {pos = pos, handle = handle, rotation = rotation,
			replacements = replacements, force = force}
	end
	function api.get_node_timer() return {start = function() end} end
	function api.rotate_node() end
	local function noop() end
	local default_api = {
		after_place_leaves = noop, grow_sapling = noop,
		node_sound_wood_defaults = function() return {} end,
		node_sound_leaves_defaults = function() return {} end,
		register_sapling_growth = function(name, definition) growth[name] = definition end,
		register_leafdecay = function(definition) leafdecays[#leafdecays + 1] = definition end,
		sapling_on_place = function(stack) return stack end,
		on_grow_failed = function(pos) failed[#failed + 1] = key(pos.x, pos.y, pos.z) end,
	}
	local environment = {core = api, default = default_api, math = fake_math}
	setmetatable(environment, {__index = _G})
	local chunk = assert(loadfile(production_repo .. "/mods/ITEMS/grug_trees/init.lua"))
	setfenv(chunk, environment)
	chunk()
	local trees = environment.grug_trees
	check(trees and growth["grug_trees:gravewood_sapling"].grow ==
		trees.grow_gravewood, "production grow callback differs")
	local leaves = registered["grug_trees:gravewood_leaves"]
	check(leaves and leaves.drop == "" and
		leaves.tiles[1] == "default_leaves.png^[colorize:#858585:210",
		"registered leaf semantics differ")

	for variant = 1, 2 do
		for rotation = 0, 3 do
			world, random_values = {}, {variant, rotation}
			local p0, r0, f0 = #placed, #removed, #failed
			trees.grow_gravewood({x = 10, y = 20, z = 30})
			check(#placed == p0 + 1 and #removed == r0 + 1 and #failed == f0,
				"clear production growth failed")
			local call = placed[#placed]
			check(call.handle == schematics[decoded[variant].filename]
				and call.pos.x == 7 and call.pos.y == 20 and call.pos.z == 27
				and call.rotation == tostring(rotation * 90)
				and call.replacements == nil and call.force == false,
				"production placement differs")

			local ox, oz = 2, 1
			for _ = 1, rotation do ox, oz = -oz, ox end
			if ox == 0 then ox = 0 end
			if oz == 0 then oz = 0 end
			world, random_values = {[key(10 + ox, 21, 30 + oz)] = "stone"},
				{variant}
			p0, r0, f0 = #placed, #removed, #failed
			trees.grow_gravewood({x = 10, y = 20, z = 30})
			check(#placed == p0 and #removed == r0 and #failed == f0 + 1,
				"obstacle preflight was not atomic")
		end
	end

	local bytes = table.concat({
		"schema\tgrug_wp40_gravewood_fixture_v1",
		"small\t7x7x7\twood=17\tleaves=5\twood_prob=254\tleaf_prob=96\tsha256=" .. decoded[1].sha256,
		"tall\t7x9x7\twood=23\tleaves=8\twood_prob=254\tleaf_prob=96\tsha256=" .. decoded[2].sha256,
		"rotations\t4\tconnected=pass\tpreflight=pass",
		"growth\tshared_assets=pass\ttemplate_route=pass\tleaves_no_drop=pass",
	}, "\n") .. "\n"
	return bytes, schematics
end
