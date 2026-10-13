-- Round 46 lane TREE portable test: the tree prototype mod
-- (mods/ITEMS/grug_treeproto). Loads the REAL init.lua, shapes.lua,
-- generator.lua and metrics.lua under a minimal `core`/`default` stub.
--
--   R. registration: every wood row gets the four shapes; each drops the
--      wood type's trunk, keeps the trunk's groups (tree, choppy), stays out
--      of the creative inventory and refuses to be placed; the connected
--      shapes join the whole family; leaf decay of the row's leaves lists
--      the trunk and all four shapes with default's radius; a tinted stand-in
--      of the leaves gets paramtype2 "color" and the palette, default's
--      leaves stay untouched (the world generator's content digest);
--   C. the corner piece: for each inward direction its facedir param2 turns
--      the boxes so the inner corner is filled and the outer corner is cut;
--   G. the generator, 300 seeds per species: the same seed builds the same
--      tree; nothing leaves the species' bounding box, which fits the world
--      generator's template limits (16 x 64 x 16); the tree stands on y = 1;
--      all wood is one face-connected piece; every leaf and fruit has wood
--      within its decay radius; param2 values are corner rotations 0..3 and
--      leaf tints 0, 32, 64, 96; seeds give many different trees;
--   S. to_schematic: size, node count and the root offset;
--   F. the face counter on two hand-built cases.
--
-- Usage (repo root): luajit tools/r46_tree/portable_test.lua [repo]
-- Prints "R46 TREE PORTABLE PASS checks=<n>" or the failures.
local repo = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

local modpath = repo .. "/mods/ITEMS/grug_treeproto"

-- The stub: the two trunks and three leaf nodes the rows name, a registry,
-- override_item and default.register_leafdecay recording their calls.
local registered = {}
local overrides = {}
local decay = {}
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for k, v in pairs(value) do result[k] = copy(v) end
	return result
end
table.copy = copy
local TRUNK_GROUPS = {tree = 1, choppy = 2, oddly_breakable_by_hand = 1,
	flammable = 2}
for _, name in ipairs({"default:jungletree", "default:tree"}) do
	registered[name] = {name = name, description = name, groups = copy(TRUNK_GROUPS),
		sounds = {}}
end
local LEAF_DROP = {max_items = 1, items = {{items = {"sapling"}, rarity = 20}}}
for _, name in ipairs({"default:jungleleaves", "default:leaves", "default:apple"}) do
	registered[name] = {name = name, type = "node", mod_origin = "default",
		groups = {leaves = 1}, tiles = {name .. ".png"}, drop = LEAF_DROP}
end
core = {
	registered_nodes = registered,
	get_modpath = function() return modpath end,
	get_current_modname = function() return "grug_treeproto" end,
	register_node = function(name, def)
		assert(not registered[name], "registered twice: " .. name)
		def.name = name
		registered[name] = def
	end,
	override_item = function(name, fields)
		overrides[name] = fields
		for k, v in pairs(fields) do registered[name][k] = v end
	end,
}
default = {
	register_leafdecay = function(def)
		for _, leaf in ipairs(def.leaves) do decay[leaf] = def end
	end,
}
dofile(modpath .. "/init.lua")
local T = grug_treeproto
local shapes = T.shapes
local generator = T.generator

-- R. registration
for _, row in ipairs(T.WOODS) do
	local family = {[row.trunk] = true}
	for _, shape in ipairs(shapes.ORDER) do family[T.shape_name(row.key, shape)] = true end
	for _, shape in ipairs(shapes.ORDER) do
		local name = T.shape_name(row.key, shape)
		local def = registered[name]
		if check(def ~= nil, "R " .. name .. " registered") then
			eq(def.drop, row.trunk, "R " .. name .. " drops the trunk")
			eq(def.groups.tree, 1, "R " .. name .. " is in group tree")
			eq(def.groups.choppy, 2, "R " .. name .. " digs like the trunk")
			eq(def.groups.not_in_creative_inventory, 1,
				"R " .. name .. " hidden from the creative inventory")
			eq(def.node_placement_prediction, "", "R " .. name .. " no placement prediction")
			local stack = {}
			check(def.on_place(stack, nil, {}) == stack,
				"R " .. name .. " refuses placement (stack unchanged)")
			eq(def.drawtype, "nodebox", "R " .. name .. " drawtype")
			eq(def.paramtype, "light", "R " .. name .. " paramtype")
			if shapes.SHAPES[shape].kind == "connected" then
				eq(def.node_box.type, "connected", "R " .. name .. " connected box")
				local joins = {}
				for _, other in ipairs(def.connects_to) do joins[other] = true end
				for other in pairs(family) do
					check(joins[other], "R " .. name .. " joins " .. other)
				end
				check(def.paramtype2 == nil, "R " .. name .. " needs no param2")
			else
				eq(def.paramtype2, "facedir", "R " .. name ..
					" turns by facedir (templates rotate facedir, never 4dir)")
			end
			-- trunk groups were copied, not shared
			check(def.groups ~= registered[row.trunk].groups, "R " .. name .. " own groups table")
		end
	end
	for _, leaf in ipairs(row.leaves) do
		local def = decay[leaf]
		if check(def ~= nil, "R leaf decay for " .. leaf) then
			eq(def.radius, row.decay_radius, "R decay radius of " .. leaf)
			local listed = {}
			for _, trunk in ipairs(def.trunks) do listed[trunk] = true end
			for name in pairs(family) do
				check(listed[name], "R " .. name .. " holds " .. leaf)
			end
		end
	end
end
eq(registered["default:jungletree"].groups.not_in_creative_inventory, nil,
	"R the trunk's own groups untouched")
for _, row in ipairs(T.WOODS) do
	local leaf = T.tinted_leaves_name(row.key)
	local source = registered[row.leaves[#row.leaves]]
	local def = registered[leaf]
	if check(def ~= nil, "R tinted stand-in " .. leaf) then
		eq(def.paramtype2, "color", "R " .. leaf .. " is colourable")
		eq(def.palette, T.LEAF_PALETTE, "R " .. leaf .. " palette")
		eq(def.tiles[1], source.tiles[1], "R " .. leaf .. " keeps the texture")
		eq(def.drop.items[1].items[1], source.drop.items[1].items[1],
			"R " .. leaf .. " drops what the leaves drop")
		eq(def.groups.leaves, 1, "R " .. leaf .. " is leaves")
		eq(def.groups.not_in_creative_inventory, 1, "R " .. leaf .. " hidden")
		check(decay[leaf] ~= nil, "R " .. leaf .. " decays")
	end
	-- the world generator's frozen content digest covers default's leaves
	eq(source.paramtype2, nil, "R " .. row.leaves[#row.leaves] .. " untouched")
	eq(T.names(row.key).leaves, leaf, "R the drafts use the tinted stand-in")
end
check(not T.LEAF_PALETTE:find("%.png"), "R the palette is generated, no texture file")

-- C. corner rotation
local function covered(boxes, x, z)
	for _, b in ipairs(boxes) do
		if x > b[1] and x < b[4] and z > b[3] and z < b[6] then return true end
	end
	return false
end
for _, sx in ipairs({-1, 1}) do
	for _, sz in ipairs({-1, 1}) do
		local p2 = shapes.corner_param2(sx, sz)
		check(p2 >= 0 and p2 <= 3, "C param2 range")
		local boxes = shapes.boxes("corner", p2, {})
		local label = "C corner toward " .. sx .. "," .. sz .. " (param2 " .. p2 .. ")"
		check(covered(boxes, sx * 7, sz * 7), label .. " fills its inner corner")
		check(not covered(boxes, -sx * 7, -sz * 7), label .. " cuts its outer corner")
		check(covered(boxes, sx * 7, -sz * 7) and covered(boxes, -sx * 7, sz * 7),
			label .. " full along both inner sides")
		for _, b in ipairs(boxes) do
			check(b[2] == -8 and b[5] == 8, label .. " boxes span the node height")
		end
	end
end

-- G. the generator
local SEEDS = 300
local function key(c) return c.x .. "," .. c.y .. "," .. c.z end
local function signature(tree)
	local parts = {}
	for i, c in ipairs(tree.list) do
		parts[i] = key(c) .. ":" .. c.kind .. ":" .. c.param2
	end
	return table.concat(parts, ";")
end
local TINTS = {[0] = true, [32] = true, [64] = true, [96] = true}
for _, species in ipairs(generator.SPECIES_ORDER) do
	local spec = generator.SPECIES[species]
	local b = spec.bounds
	check(b.x2 - b.x1 + 1 <= 16 and b.z2 - b.z1 + 1 <= 16 and b.y2 - b.y1 + 1 <= 64,
		"G " .. species .. " box fits the template limits")
	local distinct, seen = 0, {}
	local bad = {}
	local function fail_once(label)
		if not bad[label] then
			bad[label] = true
			check(false, label)
		end
	end
	for seed = 0, SEEDS - 1 do
		local tree = generator.build(species, seed)
		local again = generator.build(species, seed)
		local sig = signature(tree)
		if sig ~= signature(again) then fail_once("G " .. species .. " deterministic") end
		if not seen[sig] then seen[sig] = true distinct = distinct + 1 end
		if tree.outside ~= 0 then
			fail_once("G " .. species .. " seed " .. seed .. " stays in its box (" ..
				tree.outside .. " outside)")
		end
		local at, wood, base = {}, {}, nil
		for _, c in ipairs(tree.list) do
			at[key(c)] = c
			if c.x < b.x1 or c.x > b.x2 or c.y < b.y1 or c.y > b.y2 or
					c.z < b.z1 or c.z > b.z2 then
				fail_once("G " .. species .. " seed " .. seed .. " cell outside")
			end
			if generator.WOOD[c.kind] then
				wood[#wood + 1] = c
				if c.y == 1 and (c.kind == "trunk" or c.kind == "corner") then base = c end
			end
			if c.kind == "corner" and (c.param2 < 0 or c.param2 > 3) then
				fail_once("G " .. species .. " corner param2")
			elseif c.kind == "leaves" and not TINTS[c.param2] then
				fail_once("G " .. species .. " leaf tint param2")
			elseif (c.kind ~= "corner" and c.kind ~= "leaves") and c.param2 ~= 0 then
				fail_once("G " .. species .. " param2 of " .. c.kind)
			end
		end
		if not base then fail_once("G " .. species .. " seed " .. seed .. " stands on y = 1") end
		-- one piece of wood
		if base then
			local reached, queue, count = {[key(base)] = true}, {base}, 1
			while #queue > 0 do
				local c = table.remove(queue)
				for _, d in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0},
						{0, 0, 1}, {0, 0, -1}}) do
					local n = at[(c.x + d[1]) .. "," .. (c.y + d[2]) .. "," .. (c.z + d[3])]
					if n and generator.WOOD[n.kind] and not reached[key(n)] then
						reached[key(n)] = true
						count = count + 1
						queue[#queue + 1] = n
					end
				end
			end
			if count ~= #wood then
				fail_once("G " .. species .. " seed " .. seed .. " wood is one piece (" ..
					count .. " of " .. #wood .. ")")
			end
		end
		-- leaves near wood
		local r = spec.decay_radius
		for _, c in ipairs(tree.list) do
			if not generator.WOOD[c.kind] then
				local found = false
				for dy = -r, r do
					for dz = -r, r do
						for dx = -r, r do
							local n = at[(c.x + dx) .. "," .. (c.y + dy) .. "," .. (c.z + dz)]
							if n and generator.WOOD[n.kind] then found = true end
						end
					end
				end
				if not found then
					fail_once("G " .. species .. " seed " .. seed .. " leaf without wood")
				end
			end
		end
		if (tree.counts.leaves or 0) < 20 then
			fail_once("G " .. species .. " seed " .. seed .. " has a crown")
		end
	end
	check(distinct >= SEEDS * 0.95, "G " .. species .. " seeds give different trees (" ..
		distinct .. " of " .. SEEDS .. ")")
end
-- a bad seed is refused
check(not pcall(generator.build, "jungle", -1), "G a negative seed is refused")
check(not pcall(generator.build, "jungle", 1.5), "G a fractional seed is refused")
check(not pcall(generator.build, "oak_tree", 1), "G an unknown species is refused")

-- S. schematic
do
	local tree = generator.build("kapok", 7)
	local schematic, offset = generator.to_schematic(tree, T.names("jungle"))
	local b = tree.bounds
	eq(schematic.size.x, b.x2 - b.x1 + 1, "S size x")
	eq(schematic.size.y, b.y2 - b.y1 + 1, "S size y")
	eq(#schematic.data, schematic.size.x * schematic.size.y * schematic.size.z, "S data")
	local placed = 0
	for _, entry in ipairs(schematic.data) do
		if entry.prob > 0 then placed = placed + 1 end
	end
	eq(placed, #tree.list, "S every cell placed, air kept")
	eq(offset.x, b.x1, "S root offset x")
	eq(offset.y, b.y1, "S root offset y")
	local c = tree.list[1]
	local index = ((c.z - b.z1) * schematic.size.y + (c.y - b.y1)) * schematic.size.x +
		(c.x - b.x1) + 1
	eq(schematic.data[index].name, T.names("jungle")[c.kind], "S z-y-x order")
end

-- F. face counts
do
	local names = T.names("jungle")
	local function describe(name)
		if name == names.trunk then return {draw = "normal", wood = true} end
		if name == names.leaves then return {draw = "allfaces"} end
		for _, shape in ipairs(shapes.ORDER) do
			if name == names[shape] then
				local connects = nil
				if shapes.SHAPES[shape].kind == "connected" then
					connects = {}
					for _, other in ipairs(registered[name].connects_to) do
						connects[other] = true
					end
				end
				return {draw = "nodebox", shape = shape, connects = connects, wood = true}
			end
		end
		error("unknown " .. name)
	end
	local counted = T.metrics.count({{x = 0, y = 1, z = 0, name = names.trunk}}, describe)
	eq(counted.faces, 5, "F a log on the ground shows five faces")
	counted = T.metrics.count({{x = 0, y = 1, z = 0, name = names.corner, param2 = 0}},
		describe)
	eq(counted.faces, 15, "F a corner on the ground: three boxes, bottoms culled")
	counted = T.metrics.count({
		{x = 0, y = 1, z = 0, name = names.corner, param2 = 0},
		{x = 0, y = 2, z = 0, name = names.corner, param2 = 0},
	}, describe)
	-- lower: bottoms on the ground and tops against its twin culled (12);
	-- upper: bottoms against its twin culled (15)
	eq(counted.faces, 12 + 15, "F stacked corners cull top and bottom between them")
	counted = T.metrics.count({
		{x = 0, y = 1, z = 0, name = names.trunk},
		{x = 1, y = 1, z = 0, name = names.branch},
	}, describe)
	-- the log loses its bottom only; the branch: core 6 + arm (5, its end on
	-- the log culled) and its bottom stays (the core is not on the boundary)
	eq(counted.faces, 5 + 6 + 5, "F a branch joined to a log")
end

if failures > 0 then
	error("R46 TREE PORTABLE FAIL failures=" .. failures .. " checks=" .. checks, 0)
end
print("R46 TREE PORTABLE PASS checks=" .. checks)
