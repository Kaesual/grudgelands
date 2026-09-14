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

	-- 3. palette binding, for EVERY race the library ships -----------------
	-- Every name any palette can emit, role by role. A family role ("door",
	-- "bed", "bed_fancy") is a base, not a node name: `node` must refuse it
	-- and `variant`/`names` are the only way to reach its members, which is
	-- what keeps `parts.door` and `parts.bed` the sole emitters.
	--
	-- The roster is read out of `palettes.races`, so a race added without a
	-- line here is still checked: a palette that names an unregistered, a
	-- retired or a metadata-bearing node fails below.
	local races = {}
	for race in pairs(palettes.races) do races[#races + 1] = race end
	table.sort(races)
	assert(#races >= 2, "the library ships only one race")
	local palette_names, palette_race = {}, {}
	local function collect(handle, race, role)
		if palettes.prefix_roles[role] then
			assert(not pcall(handle.node, role),
				"family role " .. role .. " answered node()")
			assert(not pcall(handle.maybe, role),
				"family role " .. role .. " answered maybe()")
			assert(not pcall(handle.variant, role, "_nonsense"),
				"family role " .. role .. " accepted an undeclared variant")
			for _, name in ipairs(handle.names(role)) do
				assert(type(name) == "string" and name ~= "")
				palette_names[name] = role
				palette_race[name] = race
			end
			return
		end
		assert(not pcall(handle.variant, role, "_a"),
			"plain role " .. role .. " answered variant()")
		local name = handle.maybe(role)
		if name ~= nil then
			assert(type(name) == "string" and name ~= "")
			assert(handle.node(role) == name)
			palette_names[name] = role
			palette_race[name] = race
		end
	end
	local handles = {}
	for _, race in ipairs(races) do
		local handle = palettes.new(race)
		handles[race] = handle
		for _, role in ipairs(palettes.required) do
			if not palettes.prefix_roles[role] then
				assert(type(handle.node(role)) == "string" and
					handle.node(role) ~= "",
					race .. " leaves the required role " .. role .. " unbound")
			end
			collect(handle, race, role)
		end
		for _, role in ipairs(palettes.optional) do collect(handle, race, role) end
	end
	local palette = handles.dwarf
	assert(palette_names[palette.variant("door", "_a")] == "door")
	assert(palette_names[palette.variant("bed", "_top")] == "bed")
	assert(not pcall(palettes.new, "no_such_race"))
	assert(not pcall(palette.node, "no_such_role"))
	assert(not pcall(palette.names, "wall"), "a plain role answered names()")
	palettes.races.broken_race = {wall = "default:pine_wood"}
	assert(not pcall(palettes.new, "broken_race"), "unbound role accepted")
	palettes.races.broken_race = nil
	-- An override rebinds a declared role and nothing else.
	local overridden = palettes.new("dwarf",
		{roof_ridge = "default:stonebrick"})
	assert(overridden.node("roof_ridge") == "default:stonebrick" and
		palette.node("roof_ridge") ~= "default:stonebrick",
		"palette override leaked into the race")
	assert(not pcall(palettes.new, "dwarf", {no_such_role = "x"}),
		"undeclared override role accepted")

	-- A palette may only name nodes the game still registers. `grug_materials`
	-- retires part of the vendored vocabulary with `core.unregister_item`, and
	-- R7 hard-fails on an unregistered Hearthpine target, so the retired names
	-- are read out of the sources instead of being discovered by a headless
	-- engine run. There are TWO sources and both must be read: the
	-- `REMOVED_*` blocks of `content_curation.lua`, and the `source` side of
	-- `grug_materials.STORAGE_DERIVATIVES` (registry.lua), every entry of
	-- which content_curation.lua appends to the same removal roster a few
	-- lines further down. Reading only the first source is how
	-- `default:ladder_steel` stayed on a WP13 whitelist after it had been
	-- unregistered.
	local removed, retirement_sources = {}, 0
	local function retire(name)
		removed[name] = true
		-- The stairs shapes of a removed material go with it.
		local material = name:match("^default:([%w_]+)$")
		if material then
			for _, shape in ipairs({"stair_", "stair_inner_", "stair_outer_",
					"slab_"}) do
				removed["stairs:" .. shape .. material] = true
			end
		end
	end
	local curation = io.open(repo ..
		"/mods/ITEMS/grug_materials/content_curation.lua", "r")
	assert(curation, "content curation source is missing")
	local text = curation:read("*a")
	curation:close()
	local blocks = 0
	for block in text:gmatch("local REMOVED_[A-Z_]+ = {(.-)}") do
		blocks = blocks + 1
		for name in block:gmatch('"([%w_]+:[%w_]+)"') do retire(name) end
	end
	assert(blocks >= 3, "curation source no longer lists its removals")
	retirement_sources = retirement_sources + 1
	assert(text:find("grug_materials.STORAGE_DERIVATIVES", 1, true),
		"content curation no longer folds the storage derivatives in")
	local registry = dofile(repo .. "/tools/wp13/stub_registry.lua")
	local world = registry.load(repo)
	local derivatives = 0
	for _, derivative in ipairs(world.storage_derivatives) do
		retire(derivative.source)
		derivatives = derivatives + 1
	end
	assert(derivatives >= 22, "the storage derivative roster shrank")
	retirement_sources = retirement_sources + 1
	assert(removed["default:ladder_steel"] and removed["default:steel_ingot"],
		"both retirement sources must be in the roster")

	-- Every name the palette can emit, required AND optional, families
	-- expanded. Section 8 widens this to every name the finished blueprint
	-- actually writes, which is the set that reaches the engine.
	local checked = 0
	for name, role in pairs(palette_names) do
		assert(not removed[name], palette_race[name] .. " role " .. role ..
			" names the retired " .. name)
		assert(world.nodes[name], palette_race[name] .. " role " .. role ..
			" names the unregistered " .. name)
		checked = checked + 1
	end
	say("palette", #races, #palettes.required + #palettes.optional,
		"retirement_sources", retirement_sources, "names", checked)

	-- 3b. no palette role may need a callback VoxelManip never runs --------
	-- `on_construct` is "Not called for bulk node placement" (lua_api.md), and
	-- WP13 writes every cell through VoxelManip, so a node whose inventory,
	-- formspec or timer is created there arrives empty and stays empty: 39
	-- chests, 21 bookshelves, 15 vessel shelves and 9 furnaces were exactly
	-- that. The test is made against the REAL registrations, loaded under a
	-- stub `core` by `tools/wp13/stub_registry.lua`, not against a list kept
	-- by hand here, so an upstream mod that grows a callback is caught.
	--
	-- `on_rightclick` is checked with one documented exception: the `doors`
	-- family, whose rightclick IS the door and whose `doors.door_toggle`
	-- repairs the `state` meta an lvm-placed leaf never got. Nothing else may
	-- carry one. `on_destruct`, `on_blast` and `after_place_node` are not in
	-- the set: they run on dig or on player placement, never on construction,
	-- so a node carrying only those behaves identically however it was
	-- written.
	local meta_checked = 0
	for name, role in pairs(palette_names) do
		local def = world.nodes[name]
		local hits = registry.meta_fields(def)
		assert(#hits == 0, palette_race[name] .. " role " .. role ..
			" is bound to " .. name .. ", which needs " ..
			table.concat(hits, "/") .. " that bulk placement never runs")
		if def.on_rightclick ~= nil then
			assert(name:sub(1, 6) == "doors:", palette_race[name] .. " role " ..
				role .. " is bound to " .. name .. ", which has an on_rightclick")
		end
		meta_checked = meta_checked + 1
	end
	-- The guard proves itself: the nodes the palette used to name do fail it.
	for _, dead in ipairs({"default:chest", "default:bookshelf",
			"default:furnace", "vessels:shelf"}) do
		assert(#registry.meta_fields(world.nodes[dead]) > 0,
			dead .. " no longer demonstrates the metadata trap")
	end
	say("palette_static", meta_checked, "registry_nodes", #world.order)

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
	local door_leaves = palette.names("door")
	local door_a, door_b = door_leaves[1], door_leaves[2]
	local hidden = palette.node("door_hidden")
	local bed_halves = palette.names("bed")
	local bed_foot, bed_head = bed_halves[1], bed_halves[2]
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
			if cell.name == door_a or cell.name == door_b then
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
			elseif cell.name == bed_foot then
				local step = FACEDIR_DIR[cell.param2]
				local head = map[(cell.x + step[1]) .. ":" .. cell.y .. ":" ..
					(cell.z + step[2])]
				assert(head and head.name == bed_head and
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

	-- 8. every finished settlement against the real registry ---------------
	-- Sections 1-7 test the library in isolation. What actually reaches the
	-- engine is each start's cell list, so the last three sections check
	-- THOSE, name by name and cell by cell, against the registrations loaded
	-- in section 3. The roster is the R7 settlement roster, so a start added
	-- to the game is checked here without a second line.
	local roster = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua").roster
	assert(#roster >= 2, "the settlement roster lost a start")
	-- Coverage of `update_pane`'s connected branch is a property of the
	-- CORPUS, not of every start. A pane turns into the connected node only
	-- when a third horizontal neighbour connects, and the neighbour that
	-- does it in the two timber settlements is the chimney breast behind the
	-- window, which is `group:stone`. A race whose chimney is not in that
	-- group -- Stillgrave's is `grug_decor:castle_dungeon_stone`, a dungeon
	-- block with no stone group -- legitimately writes none, and bending its
	-- palette to keep a per-start assertion alive would be the test wagging
	-- the settlement. Every pane that IS written is still checked, cell by
	-- cell, against the transcribed branch table below, in every start.
	local corpus_connected_panes = 0
	for roster_index = 1, #roster do
	local profile = roster[roster_index]
	local blueprint = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/" ..
		profile.blueprint_file)()
	local emitted, emitted_names = {}, {}
	for _, cell in ipairs(blueprint.cells) do
		if cell.name ~= "air" and not emitted[cell.name] then
			emitted[cell.name] = true
			emitted_names[#emitted_names + 1] = cell.name
		end
	end
	table.sort(emitted_names)

	local pinned, kinds_checked = 0, 0
	for _, name in ipairs(emitted_names) do
		local def = world.nodes[name]
		assert(def, "the blueprint writes the unregistered " .. name)
		assert(not removed[name], "the blueprint writes the retired " .. name)
		-- `parts.param2_kind` must agree with the mod's own paramtype2.
		local kind = parts.param2_kind(name)
		if kind == parts.FACEDIR then
			assert(def.paramtype2 == "facedir",
				name .. " is rotated as facedir but is " ..
					tostring(def.paramtype2))
		elseif kind == parts.WALLMOUNTED then
			assert(def.paramtype2 == "wallmounted",
				name .. " is rotated as wallmounted but is " ..
					tostring(def.paramtype2))
		end
		-- And the two authored tables in parts.lua must equal the registry,
		-- in both directions, for every name that actually occurs.
		assert(parts.pane_connects(name) == registry.pane_connects(world, name),
			"parts.pane_connects disagrees with the registry for " .. name)
		assert(parts.full_solid(name) == registry.is_opaque_full(world, name),
			"parts.full_solid disagrees with the registry for " .. name)
		kinds_checked = kinds_checked + 1
	end

	-- A node whose definition pins `place_param2` is one the engine itself
	-- only ever writes at that value, however its paramtype2 reads. Rotating
	-- it produces a param2 no placement could have made: that is what put a
	-- meaningless facedir on 440 `default:pine_wood` and 144
	-- `default:stonebrick` cells.
	-- The plain-cube sample: every emitted name the registry says can only
	-- ever be written at param2 0, either because it declares no paramtype2
	-- at all or because it pins `place_param2 = 0`. Deriving the set from the
	-- registry instead of listing it by hand keeps it growing with the
	-- palette rather than going stale.
	local plain = {}
	for _, name in ipairs(emitted_names) do
		local def = world.nodes[name]
		if def and (def.paramtype2 == nil or def.place_param2 == 0) then
			plain[name] = 0
		end
	end
	local plain_cells = 0
	for _, cell in ipairs(blueprint.cells) do
		local def = world.nodes[cell.name]
		if def and def.place_param2 ~= nil then
			assert(cell.param2 == def.place_param2,
				cell.name .. " pins place_param2 " .. def.place_param2 ..
					" but a cell carries " .. cell.param2)
			pinned = pinned + 1
		end
		if plain[cell.name] then
			assert(cell.param2 == 0,
				"plain cube " .. cell.name .. " carries param2 " .. cell.param2)
			plain_cells = plain_cells + 1
		end
		if parts.param2_kind(cell.name) == parts.NONE then
			assert(cell.param2 == 0,
				"unoriented " .. cell.name .. " carries param2 " .. cell.param2)
		end
	end
	assert(plain_cells > 2000, "the plain-cube sample disappeared")
	say("registry", profile.key, #emitted_names, "kinds", kinds_checked,
		"place_param2", pinned, "plain_cubes", plain_cells)

	-- 8b. which window vocabulary this start builds with -------------------
	-- Which race a blueprint was composed from is not recorded anywhere the
	-- blueprint can be asked, but its windows are: exactly one of the names it
	-- emits is some race's `window` role. Whether THAT node carries
	-- `group:pane` in the real registry decides which of the two rules in
	-- section 9 applies -- derived from the palettes and the registrations,
	-- never from a roster kept here.
	local window_names = {}
	for _, race in ipairs(races) do
		window_names[handles[race].node("window")] = true
	end
	local glazed, openings = nil, 0
	for _, name in ipairs(emitted_names) do
		if window_names[name] then
			openings = openings + 1
			local def = world.nodes[name]
			local is_pane = type(def.groups) == "table" and
				(def.groups.pane or 0) > 0
			if glazed == nil then
				glazed = is_pane
			else
				assert(glazed == is_pane,
					"one start emits two window vocabularies")
			end
		end
	end
	assert(openings > 0, "the start emits no window at all")

	-- 9. every pane is the node update_pane would have settled on ----------
	-- Re-derived here from the mod source, not from `parts.resolve_panes`:
	-- the connection test is `group:pane`, `group:stone`, `group:glass`,
	-- `group:wood` or `group:tree` read off the real registrations, and the
	-- branch table is transcribed straight from mods/BASE/xpanes/init.lua.
	local cell_at = {}
	for _, cell in ipairs(blueprint.cells) do
		cell_at[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell
	end
	local pane_cells, connected_panes = 0, 0
	for _, cell in ipairs(blueprint.cells) do
		local def = world.nodes[cell.name]
		if def and type(def.groups) == "table" and (def.groups.pane or 0) > 0 then
			pane_cells = pane_cells + 1
			local base = cell.name
			if base:sub(-5) == "_flat" then base = base:sub(1, -6) end
			local any, count, c = cell.param2, 0, {}
			for dir = 0, 3 do
				local step = FACEDIR_DIR[dir]
				local other = cell_at[(cell.x + step[1]) .. ":" .. cell.y .. ":" ..
					(cell.z + step[2])]
				c[dir] = other ~= nil and registry.pane_connects(world, other.name)
				if c[dir] then
					any = dir
					count = count + 1
				end
			end
			local want_name, want_param2
			if count == 0 then
				want_name, want_param2 = base .. "_flat", cell.param2
			elseif count == 1 then
				want_name, want_param2 = base .. "_flat", (any + 1) % 4
			elseif count == 2 then
				if (c[0] and c[2]) or (c[1] and c[3]) then
					want_name, want_param2 = base .. "_flat", (any + 1) % 4
				else
					want_name, want_param2 = base, 0
				end
			else
				want_name, want_param2 = base, 0
			end
			assert(cell.name == want_name and cell.param2 == want_param2,
				"pane at " .. cell.x .. "," .. cell.y .. "," .. cell.z ..
					" is " .. cell.name .. "/" .. cell.param2 ..
					" but update_pane would leave " .. want_name .. "/" ..
					want_param2)
			if want_name == base then connected_panes = connected_panes + 1 end
		end
	end
	-- A race whose windows are open bars or a lattice writes no `group:pane`
	-- node at all: the troll palette's `darkage_wood_bars` is `glasslike` and
	-- carries no pane group, so `update_pane` has nothing to say about it and
	-- demanding a hundred panes here would only force a material that race
	-- does not build with. A start that DOES glaze still has to satisfy the
	-- whole rule.
	--
	-- The connected branch of `update_pane` is required of the CORPUS, not of
	-- every glazed start: the Hollow bars every opening with a single flat
	-- face and writes 140 panes and no junction, which is the architecture and
	-- not an untested branch. The corpus assertion below is what keeps that
	-- branch covered, and the per-start count is reported either way.
	if glazed then
		assert(pane_cells > 100, "the village lost its windows")
	else
		assert(pane_cells == 0,
			"a start with open windows still wrote " .. pane_cells .. " panes")
	end
	corpus_connected_panes = corpus_connected_panes + connected_panes
	say("panes", profile.key, glazed and "glazed" or "open", pane_cells,
		"connected", connected_panes)

	-- 10. every torch hangs on an opaque full node -------------------------
	-- A wallmounted torch takes its support from the direction its param2
	-- names. `xpanes:pane_flat` is a nodebox: a torch pointing at one hangs
	-- in a window, which is where fifteen of them were.
	local torch_names = {}
	for _, race in ipairs(races) do
		for _, role in ipairs({"light_wall", "light_post", "light_indoor"}) do
			torch_names[handles[race].node(role)] = true
		end
	end
	local torches = 0
	for _, cell in ipairs(blueprint.cells) do
		if torch_names[cell.name] then
			local dir = WALL_DIR[cell.param2]
			assert(dir, "torch has no wallmounted direction")
			local support = cell_at[(cell.x + dir[1]) .. ":" .. (cell.y + dir[2]) ..
				":" .. (cell.z + dir[3])]
			assert(support, "torch at " .. cell.x .. "," .. cell.y .. "," ..
				cell.z .. " has no support cell at all")
			assert(registry.is_opaque_full(world, support.name),
				"torch at " .. cell.x .. "," .. cell.y .. "," .. cell.z ..
					" hangs on " .. support.name .. ", which is not a full node")
			torches = torches + 1
		end
	end
	assert(torches >= 40, "the village went dark")
	say("torch_support", profile.key, torches, "opaque_full", "pass")
	end

	assert(corpus_connected_panes > 0,
		"no start writes a pane with a third neighbour; the connected branch " ..
			"of update_pane is untested")
	say("panes_connected_corpus", corpus_connected_panes)

	return table.concat(report)
end
