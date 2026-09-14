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

	-- 7a. the pane set agrees with the registry -----------------------------
	-- `parts.lua` is pure arithmetic with no registry, so it carries the pane
	-- names as a written-out set instead of asking `group:pane` the way this
	-- file and `xpanes` itself do. Two sources for one fact need a test that
	-- they still say the same thing, so every node the loaded mods register
	-- is asked both ways. The first version of `parts` tested the `xpanes:`
	-- prefix, which is a third answer again: true of every node that mod
	-- registers, pane or not.
	local pane_checked, pane_members = 0, 0
	for _, name in ipairs(world.order) do
		local def = world.nodes[name]
		local grouped = type(def.groups) == "table" and
			(def.groups.pane or 0) > 0
		assert(parts.is_pane(name) == grouped,
			"parts and the registry disagree about whether " .. name ..
				" is a pane")
		pane_checked = pane_checked + 1
		if grouped then pane_members = pane_members + 1 end
	end
	say("pane_set", "parts+registry", pane_checked, "panes", pane_members)

	-- 7b. the two byte-order comparators agree ------------------------------
	-- `parts.less_bytes` sorts every composition's palette; the identical
	-- comparator in `wp40/r7_settlement.lua` serves the consumers that never
	-- load this library. Two copies of one rule need a test that they are
	-- still one rule, so both are run over a corpus that exercises the cases
	-- `<` gets wrong under a non-C locale: case, the colon and the
	-- underscore, a prefix against its extension, and the empty string.
	local settlement = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
	local ORDER_CORPUS = {"", "a", "A", "_", ":", "aa", "a_", "a:", "ab",
		"default:dirt", "default:dirt_with_grass", "default:dirtY",
		"grug_decor:xdecor_candle", "grug_decor:xdecor_cauldron",
		"Grug_decor:xdecor_candle", "stairs:slab_wood", "stairs:stair_wood",
		"walls:cobble", "walls:mossycobble", "xpanes:pane", "xpanes:pane_flat"}
	local order_pairs = 0
	for i = 1, #ORDER_CORPUS do
		for j = 1, #ORDER_CORPUS do
			local left, right = ORDER_CORPUS[i], ORDER_CORPUS[j]
			assert(parts.less_bytes(left, right) ==
				settlement.less_bytes(left, right),
				"the two byte-order comparators disagree on " ..
					left .. " / " .. right)
			order_pairs = order_pairs + 1
		end
	end
	assert(not pcall(parts.less_bytes, "a", 1))
	assert(not pcall(settlement.less_bytes, "a", 1))
	say("byte_order", "parts+r7_settlement", order_pairs, "pass")

	-- 7c. the frozen Vale ground cover has exactly one caller ---------------
	-- `dressing.vale_undergrowth` is the degenerate selector, kept only
	-- because Hearthpine Vale's blueprint identity is part of the frozen R7
	-- manifest. A second caller would be a new settlement inheriting a known
	-- defect, so the source is read and the callers counted. `M.undergrowth`
	-- is the routine every other start uses.
	local vale_callers = {}
	for _, source in ipairs({"hearthpine", "dawnmere", "silverleaf",
			"stillgrave", "sunscar", "kapok", "dressing", "layout",
			"buildings", "capitals", "interiors", "parts", "roofs",
			"palette"}) do
		local handle = assert(io.open(wp13 .. "/" .. source .. ".lua", "rb"))
		local text = handle:read("*a")
		handle:close()
		for _ in text:gmatch("dressing%.vale_undergrowth") do
			vale_callers[#vale_callers + 1] = source
		end
	end
	assert(#vale_callers == 1 and vale_callers[1] == "hearthpine",
		"dressing.vale_undergrowth must be called by hearthpine and nothing " ..
			"else; found " .. (#vale_callers == 0 and "no caller" or
				table.concat(vale_callers, ",")))
	say("frozen_flora", "vale_undergrowth", "callers", 1)

	-- 7d. a plant seeds itself in generated ground, never authored ground --
	-- Six places in this library ask whether a cell may carry a wild plant,
	-- and all six used to ask it as `name:find("dirt")` -- a substring of a
	-- node name, which is a spelling and not a property. It answered false
	-- for `grug_nodes:tilled_soil` the moment Dawnmere's furrows stopped
	-- being `default:dirt`, and 425 tufts and bushes left the fields without
	-- anyone deciding that they should. `parts.WILD_SOIL` is the roster now,
	-- and the rule it is supposed to encode is checked against the source of
	-- truth for "ground the mapgen generates": every member must be in
	-- `grug_materials.NATURAL_GROUND_NODES`, which is read out of the
	-- registry source the way the retirement roster above is.
	--
	-- The converse is deliberately NOT asserted. `grug_nodes:mud` is
	-- generated ground and still carries no wild plants, because the Cradle's
	-- mud flats are bare by authored intent; the roster may be a subset.
	-- What must hold is the one direction that keeps authored ground out of
	-- it -- and `grug_nodes:tilled_soil` is outside both rosters, which is
	-- asserted here so that adding it to either cannot pass unnoticed.
	local ground_source = io.open(repo ..
		"/mods/ITEMS/grug_materials/registry.lua", "r")
	assert(ground_source, "the grug_materials registry source is missing")
	local ground_text = ground_source:read("*a")
	ground_source:close()
	local roster = ground_text:match(
		"grug_materials%.NATURAL_GROUND_NODES = {(.-)\n}")
	assert(roster, "NATURAL_GROUND_NODES is no longer a readable roster")
	local natural_ground, natural_count = {}, 0
	for name in roster:gmatch('"([%w_]+:[%w_]+)"') do
		natural_ground[name] = true
		natural_count = natural_count + 1
	end
	assert(natural_count >= 20, "the natural ground roster shrank to " ..
		natural_count)
	local wild_names, wild_count = {}, 0
	for name in pairs(parts.WILD_SOIL) do
		wild_names[#wild_names + 1] = name
		wild_count = wild_count + 1
	end
	table.sort(wild_names)
	for _, name in ipairs(wild_names) do
		assert(world.nodes[name], "wild soil " .. name .. " is not registered")
		assert(natural_ground[name],
			"wild soil " .. name .. " is not generated ground")
		assert(registry.is_opaque_full(world, name),
			"wild soil " .. name .. " is not an opaque full cube")
	end
	assert(not parts.wild_soil("grug_nodes:tilled_soil"),
		"an authored furrow may not carry wild plants")
	assert(not natural_ground["grug_nodes:tilled_soil"],
		"an authored furrow may not be generated ground")
	say("wild_soil", wild_count, "of", natural_count, "natural_ground",
		"authored_excluded", "pass")

	-- 8. every finished settlement against the real registry ---------------
	-- Sections 1-7 test the library in isolation. What actually reaches the
	-- engine is each start's cell list, so the last three sections check
	-- THOSE, name by name and cell by cell, against the registrations loaded
	-- in section 3. The roster is the R7 settlement roster, so a start added
	-- to the game is checked here without a second line.
	local roster = settlement.roster
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
		elseif kind == parts.MESHOPTIONS then
			assert(def.paramtype2 == "meshoptions",
				name .. " is kept through rotation as a mesh style but is " ..
					tostring(def.paramtype2))
		end
		-- And the two authored tables in parts.lua must equal the registry,
		-- in both directions, for every name that actually occurs.
		assert(parts.pane_connects(name) == registry.pane_connects(world, name),
			"parts.pane_connects disagrees with the registry for " .. name)
		assert(parts.full_solid(name) == registry.is_opaque_full(world, name),
			"parts.full_solid disagrees with the registry for " .. name)
		-- And the third authored table: the stair/slab family `parts.shaped`
		-- answers without a registry, which is what decides whether a cell
		-- may be turned upside down at all. `stairs` puts `stair = 1` in a
		-- stair's groups and `slab = 1` in a slab's; `grug_decor/shapes.lua`
		-- is a byte-for-byte copy of those registrations, so the same two
		-- groups are the whole answer.
		local shape_groups = (type(def.groups) == "table") and def.groups or {}
		assert(parts.shaped(name) ==
				((shape_groups.slab or 0) > 0 or (shape_groups.stair or 0) > 0),
			"parts.shaped disagrees with the registry for " .. name)
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
	-- Whether this start's `window` node carries `group:pane` in the real
	-- registry decides which of the two rules in section 9 applies. The
	-- question is asked of the start's OWN race palette, named by the roster
	-- row: the first version matched the emitted names against every race's
	-- `window` role at once, and `doors:door_wood` aside, nothing stops two
	-- races binding the same window node -- the dwarf and human palettes
	-- already both use `xpanes:pane_flat`, so a start could be told it
	-- emitted "two window vocabularies" for building with one.
	local race = assert(profile.race, "roster row names no race")
	local handle = assert(handles[race], "roster names an unknown race " .. race)
	local window = handle.node("window")
	local window_def = world.nodes[window]
	assert(window_def, "the " .. race .. " window is not registered")
	local glazed = type(window_def.groups) == "table" and
		(window_def.groups.pane or 0) > 0
	local openings = 0
	for _, name in ipairs(emitted_names) do
		if name == window then openings = openings + 1 end
	end
	assert(openings > 0, "the start emits no window at all")

	-- 8c. both ground-cover roles reach the pad ----------------------------
	-- `dressing.undergrowth` picks a cell with one hash and chooses between
	-- the palette's `undergrowth` and its `grass_tuft` with another. When the
	-- two are not independent -- and the first pair were not, `7x + 11z`
	-- being `3(x + z)` modulo 4 -- every picked cell takes one branch and the
	-- other node never appears. Dawnmere's green was carpeted in bushes for
	-- exactly that reason and nothing failed. This is the assertion that
	-- would have: where a race binds the two roles to different nodes, a
	-- finished settlement has to show both.
	local bush = handle.node("undergrowth")
	local tuft = handle.node("grass_tuft")
	if bush ~= tuft then
		local bush_cells, tuft_cells = 0, 0
		for _, cell in ipairs(blueprint.cells) do
			if cell.name == bush then bush_cells = bush_cells + 1
			elseif cell.name == tuft then tuft_cells = tuft_cells + 1 end
		end
		assert(bush_cells > 0 and tuft_cells > 0,
			"one ground-cover role never reached the pad: " .. bush .. "=" ..
				bush_cells .. " " .. tuft .. "=" .. tuft_cells)
		say("ground_cover", profile.key, bush, bush_cells, tuft, tuft_cells)
	end

	-- 8d. nothing stands on half a node of air -----------------------------
	-- A bottom slab fills the LOWER half of its cell, so its surface lies at
	-- the middle of the cell and anything written in the cell above it begins
	-- half a node higher, hanging. That is what the user's first walk through
	-- Sunscar Camp found: `roofs.flat_deck` capped every deck with
	-- `roof_slab`, and the breastwork, the braziers and the warlord's
	-- fighting top all stood clear of the boards they were meant to rest on,
	-- 296 cells of it. No fixture saw it, because every one of those cells is
	-- correctly placed, correctly oriented and correctly supported -- the
	-- defect is in the SHAPE of the node under them, which nothing was
	-- asking about.
	--
	-- The family is read from the real registry, not from a name: `stairs`
	-- puts `slab = 1` in a slab's groups and `stair = 1` in a stair's
	-- (mods/BASE/stairs/init.lua), and `grug_decor/shapes.lua` is a
	-- byte-for-byte copy of those four registrations. A STAIR is not in the
	-- rule: its raised half reaches the top of its own cell, so something
	-- standing on that half stands on wood. Every other short node -- a mat,
	-- an anvil, a bed, a stone path -- is a prop, not a course, and a wall or
	-- a deck passing over one is a building, not a gap.
	--
	-- There is deliberately NO exemption for a table top. The review that
	-- asked for one is right that `table_top` is a slab in every palette and
	-- that no composition can currently stand a tankard on a table; it is
	-- wrong that it should be able to. A prop on a bottom-slab table floats
	-- half a node exactly as a breastwork on a bottom-slab deck does -- same
	-- defect, same picture, and an exemption would be a licence to author it.
	-- A table meant to CARRY something is a table top written upside down or
	-- as a full node, and section 8e below then requires that flip to meet
	-- what is above it, so the two rules compose into one: a shaped node's
	-- surface must be at the top of its cell whenever anything rests on it.
	-- No start exercises this today; all six tables are bare.
	--
	-- One shape the stair exemption does let through, measured and left:
	-- Sunscar's armoury-wing ring at (34, 6, -4) and (34, 6, 2) stands on the
	-- stair that steps the main deck down to the wing deck, so a quarter of
	-- each `walls:desertcobble` post oversails the stair's low half. It
	-- predates this round, it is half a nodebox post over the step it runs
	-- along, and every way of moving it rebuilds the armoury roof.
	local shape_index = {}
	for _, cell in ipairs(blueprint.cells) do
		shape_index[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell.name
	end
	local carried_slabs, flipped_cells = 0, 0
	for _, cell in ipairs(blueprint.cells) do
		local def = world.nodes[cell.name]
		local groups = (def and type(def.groups) == "table") and def.groups or {}
		local axis = cell.param2 - (cell.param2 % 4)
		local above = shape_index[cell.x .. ":" .. (cell.y + 1) .. ":" .. cell.z]
		if (groups.slab or 0) > 0 and axis == 0 then
			assert(above == nil or above == "air",
				"a bottom slab carries " .. tostring(above) .. " at " ..
					cell.x .. "," .. cell.y .. "," .. cell.z ..
					" in " .. profile.key)
			carried_slabs = carried_slabs + 1
		end
		-- 8e. and the upside-down family is only ever a stair or a slab.
		-- `stairs`' `rotate_and_place` is this game's one placement that
		-- writes param2 20..23, and it writes it for nothing else, so a
		-- flipped cell outside that family is a node the engine could never
		-- have produced. A settlement flips a slab for exactly one reason --
		-- to meet what is above it -- so a flipped cell with air over it is a
		-- flip that bought nothing and is refused here too.
		--
		-- The gate is the node's `paramtype2`, not the raw param2 value: 20
		-- is an axis only for `facedir`, and the same number means a rotation
		-- step on a `degrotate` node and a palette index on a `color` one.
		-- Neither occurs in a settlement today, and this rule must not be the
		-- reason the first one cannot.
		if def and def.paramtype2 == "facedir" and axis ~= 0 then
			assert(axis == 20, cell.name ..
				" carries the unsupported facedir axis " .. axis)
			assert((groups.slab or 0) > 0 or (groups.stair or 0) > 0,
				cell.name .. " is turned upside down but is neither a slab " ..
					"nor a stair")
			assert(above ~= nil and above ~= "air",
				"a top slab meets nothing at " .. cell.x .. "," .. cell.y ..
					"," .. cell.z .. " in " .. profile.key)
			flipped_cells = flipped_cells + 1
		end
	end
	say("shapes", profile.key, "free_slabs", carried_slabs,
		"upside_down", flipped_cells)

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

	-- 11. no piece of architecture stands detached ------------------------
	-- Every cell of a BUILDING must touch another non-air cell across a face
	-- or across a vertical diagonal. The vertical diagonal is in the rule
	-- because a free-standing flight of stairs is a real thing the library
	-- builds: Hearthpine's cellar steps climb one node out and one node up
	-- per tread, so two of its treads touch nothing across a face at all.
	--
	-- Three families are outside the rule, and each exemption is a property
	-- of the NODE read out of the real registrations, never a list of starts
	-- or of cells:
	--
	--   * `group:tree` and `group:leaves`. A tree's silhouette is the
	--     vendored schematic's, and the vendored acacia hangs its branch
	--     logs on HORIZONTAL diagonals off the trunk -- 94 of Sunscar's do.
	--     Vegetation has its own, sharper invariant in `blueprint_kat`: the
	--     trunk height, the crown reach and the leaf-to-trunk path.
	--   * a node whose `paramtype2` is `wallmounted`, which names its own
	--     support with its param2. Section 10 and `blueprint_kat`'s prop
	--     check test that exactly; leaving it out keeps one cell from being
	--     reported twice under two rules.
	--   * `plantlike`, `torchlike`, `signlike` and `airlike` nodes, which are
	--     crosses and sprites rather than blocks, held up by the engine's own
	--     attachment rules where each is sown.
	--
	-- What this rule does NOT catch is worth writing down, because the
	-- review expected it to: Silverleaf's terrace podium was built one node
	-- shallower than the apron and railing standing on it, and those 18
	-- apron cells each touched the podium beside them across a face, so a
	-- neighbour rule of any kind passes them. The invariant that catches a
	-- floor with nothing under it is in `blueprint_kat`, where each start's
	-- own `paved` family is known.
	local LOOSE_DRAWTYPE = {plantlike = true, torchlike = true,
		signlike = true, airlike = true}
	local NEIGHBOURS = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0},
		{0, 0, 1}, {0, 0, -1},
		{1, 1, 0}, {-1, 1, 0}, {0, 1, 1}, {0, 1, -1},
		{1, -1, 0}, {-1, -1, 0}, {0, -1, 1}, {0, -1, -1}}
	local floating, checked = 0, 0
	local first_floating
	for _, cell in ipairs(blueprint.cells) do
		local def = world.nodes[cell.name]
		local groups = def and type(def.groups) == "table" and def.groups or {}
		local loose = cell.name == "air" or def == nil or
			LOOSE_DRAWTYPE[def.drawtype] or def.paramtype2 == "wallmounted" or
			(groups.tree or 0) > 0 or (groups.leaves or 0) > 0 or
			(groups.leafdecay or 0) > 0
		if not loose then
			checked = checked + 1
			local touched = false
			for _, step in ipairs(NEIGHBOURS) do
				local other = cell_at[(cell.x + step[1]) .. ":" ..
					(cell.y + step[2]) .. ":" .. (cell.z + step[3])]
				-- Outside the cell list is the settlement's own ground: at
				-- y <= 0 the pad is solid terrain the writer never clears, so
				-- a cell resting on it is held. Above y = 0 an absent cell is
				-- air.
				if (other ~= nil and other.name ~= "air") or
						cell.y + step[2] <= 0 then
					touched = true
				end
			end
			if not touched then
				floating = floating + 1
				first_floating = first_floating or (cell.name .. " at " ..
					cell.x .. "," .. cell.y .. "," .. cell.z)
			end
		end
	end
	assert(floating == 0, floating .. " detached cells in " .. profile.key ..
		", first " .. tostring(first_floating))
	say("grounded", profile.key, checked, "no_detached_cell", "pass")
	end

	assert(corpus_connected_panes > 0,
		"no start writes a pane with a third neighbour; the connected branch " ..
			"of update_pane is untested")
	say("panes_connected_corpus", corpus_connected_panes)

	-- 12. the capital parts, every race, every rotation --------------------
	-- Sections 8-11 check the six finished START blueprints. The capital
	-- parts have no composition yet -- that is a later lane -- so this
	-- section is their equivalent: every generator of
	-- `mods/MAPGEN/grug_mapgen/wp13/capitals.lua` is built for every race
	-- palette, stamped at all four rotations, and put through the same rules
	-- the starts are held to, plus the three the capital contracts add:
	-- the bounds envelope of `wp13-capitals-pois-contract.md` section 2.1,
	-- the socket rules of `wp13-npc-sockets-contract.md` section 2, and the
	-- walkability of every doorway the part publishes.
	local capitals = dofile(wp13 .. "/capitals.lua")(wp13)

	-- The two envelopes of the capitals contract. A district plot lives in
	-- 32 x 32 and y -6..24, the king's hall in 48 x 48 and y -2..40. The
	-- span counts EVERY cell the part writes, aprons, eaves, buttresses and
	-- flights included, because the plot the composition reserves has to hold
	-- all of them.
	local ENVELOPE = {
		core = {span = 48, ymin = -2, ymax = 40},
		plot = {span = 32, ymin = -6, ymax = 24},
	}

	-- One row per generator: how it is called, which envelope it has to fit,
	-- the exact socket roles it must publish, and the authored populations it
	-- must produce. The socket multiset is exact on purpose: a placement test
	-- that only counts "at least one" is how twenty-two of Dawnmere's props
	-- went missing without a fixture noticing.
	local CAPITAL_PARTS = {
		{key = "king_hall", class = "core", spec = {id = "kat_hall"},
			roles = {king = 1, guard_post = 4, waypoint = 1, idle = 3},
			doors = 3, rooms = 1,
			counts = {arcade_bays = true, arrowslits = true}},
		{key = "wall_segment", class = "plot",
			spec = {id = "kat_wall", len = 8, phase = 0},
			roles = {guard_patrol = 2}, doors = 0, rooms = 0,
			chain = {w = 8, d = 5},
			counts = {merlons = true, arrowslits = true}},
		{key = "wall_segment", class = "plot", label = "wall_segment_stair",
			spec = {id = "kat_wall_stair", len = 12, phase = 2, stair = true},
			roles = {guard_patrol = 2}, doors = 1, rooms = 0,
			chain = {w = 12, d = 5},
			counts = {merlons = true, arrowslits = true}},
		{key = "wall_tower", class = "plot", spec = {id = "kat_tower"},
			roles = {guard_post = 1, guard_patrol = 1, idle = 1},
			doors = 1, rooms = 1,
			counts = {merlons = true, arrowslits = true}},
		{key = "gatehouse", class = "plot", spec = {id = "kat_gate"},
			roles = {guard_post = 2, guard_patrol = 2, idle = 2},
			doors = 2, rooms = 1,
			-- The five-wide street of the capitals contract, clear from the
			-- paving to head height on every node of the passage. The arch
			-- springs at y = 5 and narrows the top of the opening to three,
			-- which is a vault and not an obstruction.
			clear = {x0 = 4, x1 = 8, y0 = 1, y1 = 4},
			counts = {merlons = true, arrowslits = true}},
		{key = "colonnade", class = "plot",
			spec = {id = "kat_colonnade", len = 15},
			roles = {idle = 2, guard_patrol = 1}, doors = 0, rooms = 0,
			counts = {piers = true, columns = true, benches = true}},
		{key = "market_square", class = "plot",
			spec = {id = "kat_market", size = 25},
			roles = {vendor = 4, idle = 2, waypoint = 1}, doors = 0, rooms = 0,
			counts = {stalls = true, benches = true}},
		{key = "well_court", class = "plot",
			spec = {id = "kat_well", size = 11},
			roles = {idle = 2}, doors = 0, rooms = 0,
			counts = {benches = true}},
		{key = "statue_plinth", class = "plot", spec = {id = "kat_statue"},
			roles = {idle = 1}, doors = 0, rooms = 0, counts = {}},
		{key = "barracks", class = "plot", spec = {id = "kat_barracks"},
			roles = {guard_post = 1, idle = 1, guard_patrol = 1},
			doors = 2, rooms = 1, counts = {}},
		{key = "temple", class = "plot", spec = {id = "kat_temple"},
			roles = {idle = 1, quest = 1}, doors = 2, rooms = 1, counts = {}},
		{key = "scriptorium", class = "plot", spec = {id = "kat_scriptorium"},
			roles = {idle = 2}, doors = 1, rooms = 1, counts = {}},
		{key = "granary", class = "plot", spec = {id = "kat_granary"},
			roles = {idle = 1}, doors = 2, rooms = 1, counts = {}},
		{key = "stable", class = "plot", spec = {id = "kat_stable"},
			roles = {idle = 2}, doors = 2, rooms = 1, counts = {}},
		{key = "orchard_edge", class = "plot",
			spec = {id = "kat_orchard", len = 21},
			roles = {idle = 1, guard_patrol = 2}, doors = 0, rooms = 0,
			counts = {trees = true}},
		{key = "grove", class = "plot", spec = {id = "kat_grove", size = 17},
			roles = {idle = 1}, doors = 0, rooms = 0, counts = {trees = true}},
		{key = "stilt_platform", class = "plot", spec = {id = "kat_stilt"},
			roles = {guard_patrol = 2, idle = 1}, doors = 0, rooms = 0,
			counts = {piers = true}},
		{key = "water_channel", class = "plot",
			spec = {id = "kat_channel", len = 21},
			roles = {idle = 1, guard_patrol = 2}, doors = 0, rooms = 0,
			counts = {kerb = true}},
	}

	-- Walkable, as the engine reads it: the absence of `walkable = false`.
	-- Every socket, doorstep and attached node below is decided with this and
	-- not with `parts.full_solid`, which is the stricter "opaque cube a torch
	-- may hang on" and would refuse a perfectly good paving slab underfoot.
	local function walkable(name)
		local def = world.nodes[name]
		return def ~= nil and def.walkable ~= false
	end

	-- The support direction of an attached node, transcribed from
	-- `builtin_shared.check_attached_node`
	-- (reference_projects/luanti/builtin/game/falling.lua:391-434): rating 3
	-- is the floor, rating 4 the ceiling, rating 2 the facedir the node is
	-- mounted to, and every other rating follows the node's own paramtype2 --
	-- wallmounted to what its param2 points at, anything else to the floor.
	-- Kapok bound a floor lantern to a role that hangs under a deck and the
	-- engine would have dropped all sixteen; the ratings are not
	-- interchangeable, so the rule is read off the registry per cell.
	local function attach_step(def, param2)
		local rating = (type(def.groups) == "table") and
			(def.groups.attached_node or 0) or 0
		if rating == 0 then return nil end
		if rating == 3 then return 0, -1, 0 end
		if rating == 4 then return 0, 1, 0 end
		if rating == 2 then
			if def.paramtype2 == "facedir" then
				local dir = FACEDIR_DIR[param2 % 4]
				return dir[1], 0, dir[2]
			end
			return 0, 0, 1
		end
		if def.paramtype2 == "wallmounted" then
			local dir = WALL_DIR[param2]
			if not dir then return 0, 1, 0 end
			return dir[1], dir[2], dir[3]
		end
		return 0, -1, 0
	end

	local LOOSE_CAPITAL = {plantlike = true, torchlike = true,
		signlike = true, airlike = true}
	local NEIGHBOUR_STEPS = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0},
		{0, 0, 1}, {0, 0, -1},
		{1, 1, 0}, {-1, 1, 0}, {0, 1, 1}, {0, 1, -1},
		{1, -1, 0}, {-1, -1, 0}, {0, -1, 1}, {0, -1, -1}}

	-- Every check one stamped part has to pass. `label` names the case in a
	-- failure, because the same generator appears twice with two specs.
	local function check_capital_part(label, race, case, part, turns)
		local target = parts.buffer()
		local moved = parts.stamp(target, part, 0, 0, 0, turns)
		-- A pane's shape depends on neighbours the part that wrote it cannot
		-- see, so a composition settles them once over the whole pad
		-- (`parts.resolve_panes`). Run the same pass over the part alone and
		-- then hold it to `update_pane`'s own rule: a part whose windows are
		-- wrong in isolation is wrong in a district too.
		parts.resolve_panes(target)
		local order, count = target:cells()
		local index, solids = {}, 0
		local minx, maxx, miny, maxy, minz, maxz
		for step = 1, count do
			local cell = order[step]
			index[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell
			if cell.name ~= "air" then
				solids = solids + 1
				if minx == nil or cell.x < minx then minx = cell.x end
				if maxx == nil or cell.x > maxx then maxx = cell.x end
				if miny == nil or cell.y < miny then miny = cell.y end
				if maxy == nil or cell.y > maxy then maxy = cell.y end
				if minz == nil or cell.z < minz then minz = cell.z end
				if maxz == nil or cell.z > maxz then maxz = cell.z end
			end
		end
		local where = label .. "/" .. race .. "/turn" .. turns
		assert(solids > 0, where .. " wrote nothing")
		local function at(x, y, z) return index[x .. ":" .. y .. ":" .. z] end
		-- Outside the cell list, a column at or below the ground course is
		-- the settlement's own terrain and holds what rests on it; above it
		-- an absent cell is air. Same convention as section 11.
		local function held(x, y, z)
			local cell = at(x, y, z)
			if cell ~= nil then return cell.name ~= "air" end
			return y <= 0
		end
		local function free(x, y, z)
			local cell = at(x, y, z)
			return cell == nil or cell.name == "air"
		end
		local function standable(x, y, z)
			local cell = at(x, y, z)
			if cell == nil then return y <= 0 end
			return cell.name ~= "air" and walkable(cell.name)
		end

		-- (a) the bounds envelope.
		local envelope = ENVELOPE[case.class]
		assert(envelope, where .. " names no envelope")
		assert(maxx - minx + 1 <= envelope.span and
				maxz - minz + 1 <= envelope.span,
			where .. " spans " .. (maxx - minx + 1) .. " x " ..
				(maxz - minz + 1) .. ", over the " .. case.class ..
				" envelope of " .. envelope.span)
		assert(miny >= envelope.ymin and maxy <= envelope.ymax,
			where .. " reaches y " .. miny .. ".." .. maxy ..
				", outside the " .. case.class .. " envelope y " ..
				envelope.ymin .. ".." .. envelope.ymax)
		assert(maxy <= part.peak, where .. " writes y " .. maxy ..
			" above its own declared peak " .. part.peak)

		-- (b) every emitted name against the real registry, and the three
		-- authored tables of parts.lua in both directions.
		for _, cell in ipairs(order) do
			if cell.name ~= "air" then
				local def = world.nodes[cell.name]
				assert(def, where .. " writes the unregistered " .. cell.name)
				assert(not removed[cell.name],
					where .. " writes the retired " .. cell.name)
				local kind = parts.param2_kind(cell.name)
				if kind == parts.FACEDIR then
					assert(def.paramtype2 == "facedir", where .. ": " ..
						cell.name .. " is rotated as facedir but is " ..
						tostring(def.paramtype2))
				elseif kind == parts.WALLMOUNTED then
					assert(def.paramtype2 == "wallmounted", where .. ": " ..
						cell.name .. " is rotated as wallmounted but is " ..
						tostring(def.paramtype2))
				elseif kind == parts.MESHOPTIONS then
					assert(def.paramtype2 == "meshoptions", where .. ": " ..
						cell.name .. " is kept as a mesh style but is " ..
						tostring(def.paramtype2))
				else
					assert(cell.param2 == 0, where .. ": unoriented " ..
						cell.name .. " carries param2 " .. cell.param2)
				end
				assert(parts.pane_connects(cell.name) ==
						registry.pane_connects(world, cell.name),
					where .. ": parts.pane_connects disagrees with the " ..
						"registry for " .. cell.name)
				assert(parts.full_solid(cell.name) ==
						registry.is_opaque_full(world, cell.name),
					where .. ": parts.full_solid disagrees with the " ..
						"registry for " .. cell.name)
				local groups = (type(def.groups) == "table") and def.groups or {}
				assert(parts.shaped(cell.name) ==
						((groups.slab or 0) > 0 or (groups.stair or 0) > 0),
					where .. ": parts.shaped disagrees with the registry " ..
						"for " .. cell.name)
				if def.place_param2 ~= nil then
					assert(cell.param2 == def.place_param2, where .. ": " ..
						cell.name .. " pins place_param2 " ..
						def.place_param2 .. " but a cell carries " ..
						cell.param2)
				end
				-- (c) the two shape rules of round A: a bottom slab carries
				-- nothing, and the upside-down family is a stair or a slab
				-- that meets what is above it.
				local axis = cell.param2 - (cell.param2 % 4)
				local above = at(cell.x, cell.y + 1, cell.z)
				if (groups.slab or 0) > 0 and axis == 0 then
					assert(above == nil or above.name == "air",
						where .. ": a bottom slab carries " ..
							tostring(above and above.name) .. " at " ..
							cell.x .. "," .. cell.y .. "," .. cell.z)
				end
				if def.paramtype2 == "facedir" and axis ~= 0 then
					assert(axis == 20, where .. ": " .. cell.name ..
						" carries the unsupported facedir axis " .. axis)
					assert((groups.slab or 0) > 0 or (groups.stair or 0) > 0,
						where .. ": " .. cell.name .. " is turned upside " ..
							"down but is neither a slab nor a stair")
					assert(above ~= nil and above.name ~= "air",
						where .. ": a top slab meets nothing at " .. cell.x ..
							"," .. cell.y .. "," .. cell.z)
				end
				-- (d) every pane is what update_pane would have settled on,
				-- re-derived from the mod's own connection groups.
				if (groups.pane or 0) > 0 then
					local pane_base = cell.name
					if pane_base:sub(-5) == "_flat" then
						pane_base = pane_base:sub(1, -6)
					end
					local any, total, hit = cell.param2, 0, {}
					for dir = 0, 3 do
						local step = FACEDIR_DIR[dir]
						local other = at(cell.x + step[1], cell.y,
							cell.z + step[2])
						hit[dir] = other ~= nil and
							registry.pane_connects(world, other.name)
						if hit[dir] then
							any = dir
							total = total + 1
						end
					end
					local want, want_param2
					if total == 0 then
						want, want_param2 = pane_base .. "_flat", cell.param2
					elseif total == 1 or (total == 2 and
							((hit[0] and hit[2]) or (hit[1] and hit[3]))) then
						want, want_param2 = pane_base .. "_flat", (any + 1) % 4
					else
						want, want_param2 = pane_base, 0
					end
					assert(cell.name == want and cell.param2 == want_param2,
						where .. ": pane at " .. cell.x .. "," .. cell.y ..
							"," .. cell.z .. " is " .. cell.name .. "/" ..
							cell.param2 .. " but update_pane would leave " ..
							want .. "/" .. want_param2)
				end
				-- (e) an attached node keeps the support its own rating
				-- names, and that support is walkable.
				local ax, ay, az = attach_step(def, cell.param2)
				if ax then
					local sx, sy, sz = cell.x + ax, cell.y + ay, cell.z + az
					assert(standable(sx, sy, sz), where .. ": " .. cell.name ..
						" at " .. cell.x .. "," .. cell.y .. "," .. cell.z ..
						" is attached to " ..
						tostring(at(sx, sy, sz) and at(sx, sy, sz).name or
							"nothing") .. " at " .. sx .. "," .. sy .. "," ..
						sz .. ", which the engine would drop it off")
				end
				-- (f) nothing stands detached. Same three exemptions as
				-- section 11, each a property of the node.
				local loose = LOOSE_CAPITAL[def.drawtype] or
					def.paramtype2 == "wallmounted" or
					(groups.tree or 0) > 0 or (groups.leaves or 0) > 0 or
					(groups.leafdecay or 0) > 0
				if not loose then
					local touched = false
					for _, step in ipairs(NEIGHBOUR_STEPS) do
						if held(cell.x + step[1], cell.y + step[2],
								cell.z + step[3]) then
							touched = true
						end
					end
					assert(touched, where .. ": " .. cell.name ..
						" stands detached at " .. cell.x .. "," .. cell.y ..
						"," .. cell.z)
				end
			end
		end

		-- (f2) and nothing floats as an ISLAND. The neighbour rule above is
		-- local: two cells that touch each other and nothing else pass it,
		-- which is how a bell hung under a cross-beam in the middle of a
		-- lantern went unnoticed -- both cells had a neighbour, and the
		-- neighbour was the other one. This is the same adjacency (face or
		-- vertical diagonal) flooded from the GROUND up, so a piece of
		-- architecture has to be connected to the terrain through other
		-- cells, not merely to itself.
		--
		-- The same three families are outside the rule, for the same
		-- reasons, and they conduct without being required: a torch is held
		-- by its own param2 and a leaf by its trunk.
		local grounded, island_checked = {}, 0
		local frontier, frontier_count = {}, 0
		local function solid_cell(cell)
			if cell == nil or cell.name == "air" then return false end
			return true
		end
		for _, cell in ipairs(order) do
			if cell.name ~= "air" and held(cell.x, cell.y - 1, cell.z) and
					not solid_cell(at(cell.x, cell.y - 1, cell.z)) then
				-- resting straight on the settlement's own terrain
				local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
				if not grounded[key] then
					grounded[key] = true
					frontier_count = frontier_count + 1
					frontier[frontier_count] = cell
				end
			end
		end
		local head = 1
		while head <= frontier_count do
			local cell = frontier[head]
			head = head + 1
			for _, step in ipairs(NEIGHBOUR_STEPS) do
				local other = at(cell.x + step[1], cell.y + step[2],
					cell.z + step[3])
				if other ~= nil and other.name ~= "air" then
					local key = other.x .. ":" .. other.y .. ":" .. other.z
					if not grounded[key] then
						grounded[key] = true
						frontier_count = frontier_count + 1
						frontier[frontier_count] = other
					end
				end
			end
		end
		for _, cell in ipairs(order) do
			if cell.name ~= "air" then
				local def = world.nodes[cell.name]
				local groups = def and type(def.groups) == "table" and
					def.groups or {}
				local loose = def == nil or LOOSE_CAPITAL[def.drawtype] or
					def.paramtype2 == "wallmounted" or
					(groups.tree or 0) > 0 or (groups.leaves or 0) > 0 or
					(groups.leafdecay or 0) > 0
				if not loose then
					island_checked = island_checked + 1
					assert(grounded[cell.x .. ":" .. cell.y .. ":" .. cell.z],
						where .. ": " .. cell.name .. " at " .. cell.x .. "," ..
							cell.y .. "," .. cell.z ..
							" is an island -- nothing connects it to the ground")
				end
			end
		end

		-- (g) every torch hangs on an opaque full node.
		local torch_names = {}
		for _, other in ipairs(races) do
			for _, role in ipairs({"light_wall", "light_post",
					"light_indoor"}) do
				torch_names[handles[other].node(role)] = true
			end
		end
		local torches = 0
		for _, cell in ipairs(order) do
			if torch_names[cell.name] then
				local dir = WALL_DIR[cell.param2]
				assert(dir, where .. ": a torch has no wallmounted direction")
				local support = at(cell.x + dir[1], cell.y + dir[2],
					cell.z + dir[3])
				assert(support and
						registry.is_opaque_full(world, support.name),
					where .. ": torch at " .. cell.x .. "," .. cell.y .. "," ..
						cell.z .. " hangs on " ..
						tostring(support and support.name or "air"))
				torches = torches + 1
			end
		end

		-- (h) the socket contract, against the registry this time.
		local seen, roles = {}, {}
		for _, entry in ipairs(moved.sockets or {}) do
			assert(type(entry.id) == "string" and entry.id ~= "",
				where .. " publishes a socket with no id")
			assert(not seen[entry.id],
				where .. " publishes the socket id " .. entry.id .. " twice")
			seen[entry.id] = true
			roles[entry.role] = (roles[entry.role] or 0) + 1
			assert(entry.face ~= nil and entry.face >= 0 and entry.face <= 3,
				where .. ": socket " .. entry.id .. " has no facedir")
			assert(free(entry.x, entry.y, entry.z) and
					free(entry.x, entry.y + 1, entry.z),
				where .. ": socket " .. entry.id .. " has no headroom at " ..
					entry.x .. "," .. entry.y .. "," .. entry.z)
			assert(standable(entry.x, entry.y - 1, entry.z),
				where .. ": socket " .. entry.id .. " stands on " ..
					tostring(at(entry.x, entry.y - 1, entry.z) and
						at(entry.x, entry.y - 1, entry.z).name or "air"))
			if entry.role == "guard_patrol" then
				assert(type(entry.group) == "string" and
						type(entry.order) == "number",
					where .. ": patrol waypoint " .. entry.id ..
						" carries no loop or no order")
			end
			if entry.role == "vendor" then
				assert(entry.kind == "race" or entry.kind == "general",
					where .. ": vendor " .. entry.id ..
						" names no vendor family")
			end
		end
		for role, wanted in pairs(case.roles) do
			assert((roles[role] or 0) == wanted, where .. " publishes " ..
				(roles[role] or 0) .. " " .. role .. " sockets, not " ..
				wanted)
		end
		for role in pairs(roles) do
			assert(case.roles[role], where .. " publishes an unexpected " ..
				role .. " socket")
		end

		-- (i) every doorway is a real door and passable from both sides.
		local leaves = {}
		for _, other in ipairs(races) do
			for _, name in ipairs(handles[other].names("door")) do
				leaves[name] = true
			end
		end
		assert(#(moved.doors or {}) == case.doors, where .. " publishes " ..
			#(moved.doors or {}) .. " doors, not " .. case.doors)
		for _, door in ipairs(moved.doors or {}) do
			local leaf = at(door.x, door.y, door.z)
			assert(leaf and leaves[leaf.name], where .. ": the door at " ..
				door.x .. "," .. door.y .. "," .. door.z .. " is " ..
				tostring(leaf and leaf.name or "air"))
			local top = at(door.x, door.y + 1, door.z)
			assert(top and top.name == handles[race].node("door_hidden"),
				where .. ": the door at " .. door.x .. "," .. door.y .. "," ..
					door.z .. " has no hidden upper node")
			local step = FACEDIR_DIR[door.face % 4]
			for _, sign in ipairs({1, -1}) do
				local sx = door.x + step[1] * sign
				local sz = door.z + step[2] * sign
				assert(free(sx, door.y, sz) and free(sx, door.y + 1, sz),
					where .. ": the doorway at " .. door.x .. "," .. door.y ..
						"," .. door.z .. " is blocked on the " ..
						(sign == 1 and "inside" or "outside"))
				assert(standable(sx, door.y - 1, sz), where ..
					": the doorstep at " .. sx .. "," .. (door.y - 1) .. "," ..
					sz .. " is not walkable")
			end
		end

		-- (j) roof and wall closure, plus a light, for every room the part
		-- declares closed. Room corners come in pairs, the first carrying
		-- the flags; rotation keeps the pairing.
		local rooms = 0
		local corners = moved.room_corner or {}
		for step = 1, #corners, 2 do
			local first, second = corners[step], corners[step + 1]
			assert(second, where .. " publishes an odd room corner")
			rooms = rooms + 1
			if first.closed then
				local x0 = math.min(first.x, second.x)
				local x1 = math.max(first.x, second.x)
				local z0 = math.min(first.z, second.z)
				local z1 = math.max(first.z, second.z)
				local lit = 0
				for _, light in ipairs(moved.lights or {}) do
					if light.x >= x0 and light.x <= x1 and
							light.z >= z0 and light.z <= z1 then
						lit = lit + 1
					end
				end
				assert(lit > 0, where .. ": the room " ..
					tostring(first.id) .. " is unlit")
				for z = z0, z1 do
					for x = x0, x1 do
						local covered = false
						for y = first.top + 1, ENVELOPE[case.class].ymax do
							local cell = at(x, y, z)
							if cell and cell.name ~= "air" then
								covered = true
							end
						end
						assert(covered, where .. ": interior column " .. x ..
							"," .. z .. " of room " .. tostring(first.id) ..
							" is open to the sky")
					end
				end
			end
		end
		assert(rooms == case.rooms, where .. " declares " .. rooms ..
			" rooms, not " .. case.rooms)
		return solids, torches
	end

	-- Build, stamp and check. Determinism first: these generators are pure,
	-- so two builds of one spec must produce the identical cell list, in the
	-- identical order.
	local capital_cells, capital_sockets = 0, 0
	for _, case in ipairs(CAPITAL_PARTS) do
		local label = case.label or case.key
		local generator = capitals[case.key]
		assert(type(generator) == "function",
			"capitals.lua has no generator " .. case.key)
		local rows = {}
		for _, race in ipairs(races) do
			local handle = handles[race]
			local part = generator(handle, case.spec)
			local twin = generator(handle, case.spec)
			local a_order, a_count = part.buffer:cells()
			local b_order, b_count = twin.buffer:cells()
			assert(a_count == b_count, label .. "/" .. race ..
				" is not deterministic: " .. a_count .. " then " .. b_count)
			for step = 1, a_count do
				assert(a_order[step].x == b_order[step].x and
						a_order[step].y == b_order[step].y and
						a_order[step].z == b_order[step].z and
						a_order[step].name == b_order[step].name and
						a_order[step].param2 == b_order[step].param2,
					label .. "/" .. race .. " differs between two builds at " ..
						"cell " .. step)
			end
			-- A linear piece has to CHAIN: every cell inside the footprint
			-- the composition will place the next copy next to, or two
			-- segments in a row overwrite each other's parapets.
			if case.chain then
				local order, count = part.buffer:cells()
				for step = 1, count do
					local cell = order[step]
					assert(cell.x >= 0 and cell.x < case.chain.w and
							cell.z >= 0 and cell.z < case.chain.d,
						label .. "/" .. race .. " writes " .. cell.name ..
							" at " .. cell.x .. "," .. cell.z ..
							", outside the footprint it chains on")
				end
			end
			-- A passage the contract gives a width has to have it.
			if case.clear then
				local order, count = part.buffer:cells()
				for step = 1, count do
					local cell = order[step]
					-- WALKABLE is the test, not "any cell": the gate jambs
					-- carry a wallmounted torch inside the opening, and a
					-- torch is not something a cart runs into.
					if cell.name ~= "air" and walkable(cell.name) and
							cell.x >= case.clear.x0 and cell.x <= case.clear.x1 and
							cell.y >= case.clear.y0 and cell.y <= case.clear.y1 then
						error(label .. "/" .. race .. ": " .. cell.name ..
							" at " .. cell.x .. "," .. cell.y .. "," ..
							cell.z .. " stands in the passage", 0)
					end
				end
			end
			for key in pairs(case.counts) do
				assert(type(part[key]) == "number" and part[key] > 0,
					label .. "/" .. race .. " authored " ..
						tostring(part[key]) .. " " .. key)
			end
			-- `hedge` is the degradation probe of the orchard edge: only the
			-- human palette binds a hedge, so exactly that race must plant
			-- one and every other race must plant none and still build.
			if case.key == "orchard_edge" then
				local wanted = (handle.maybe("hedge") ~= nil)
				assert((part.hedge > 0) == wanted, label .. "/" .. race ..
					" planted " .. part.hedge .. " hedge cells but binds " ..
					tostring(handle.maybe("hedge")))
			end
			local solids
			for turns = 0, 3 do
				solids = check_capital_part(label, race, case, part, turns)
			end
			capital_cells = capital_cells + solids
			capital_sockets = capital_sockets + #(part.points.sockets or {})
			rows[#rows + 1] = race .. "=" .. solids
		end
		say("capital", label, case.class, table.concat(rows, ","))
	end
	assert(capital_sockets > 0, "the capital parts publish no socket at all")
	say("capital_total", #CAPITAL_PARTS, "parts", capital_cells, "cells",
		capital_sockets, "sockets")

	-- 12b. the capital vocabulary really is optional ------------------------
	-- Every role of the capital vocabulary is declared optional, and a
	-- generator is supposed to degrade into the start vocabulary without it.
	-- That claim is worth nothing unless something builds without them, so a
	-- throwaway race is registered with the whole capital vocabulary stripped
	-- out and every generator is built for it. A missing fallback fails here
	-- and nowhere else -- the six shipped palettes all carry the bindings.
	local bare = {}
	for role, name in pairs(palettes.races.dwarf) do bare[role] = name end
	local stripped = 0
	for _, role in ipairs({"castle_paving", "castle_rubble", "castle_slit",
			"castle_wall", "castle_wall_slab", "castle_wall_stair", "pillar",
			"signature", "signature_slab", "signature_stair", "throne"}) do
		assert(bare[role] ~= nil,
			"the dwarf palette no longer binds the capital role " .. role)
		bare[role] = nil
		stripped = stripped + 1
	end
	palettes.races.kat_bare = bare
	local bare_handle = palettes.new("kat_bare")
	for _, role in ipairs({"castle_wall", "signature", "throne"}) do
		assert(bare_handle.maybe(role) == nil,
			"the stripped palette still binds " .. role)
	end
	local bare_built = 0
	for _, case in ipairs(CAPITAL_PARTS) do
		local part = capitals[case.key](bare_handle, case.spec)
		local _, count = part.buffer:cells()
		assert(count > 0, (case.label or case.key) ..
			" built nothing without the capital vocabulary")
		bare_built = bare_built + 1
	end
	palettes.races.kat_bare = nil
	assert(palettes.races.kat_bare == nil, "the probe race was left behind")
	say("capital_degrade", stripped, "roles_stripped", bare_built, "parts")

	return table.concat(report)
end
