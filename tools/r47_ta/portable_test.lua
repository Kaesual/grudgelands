-- Round 47 lane TA portable test (LuaJIT): the tree shape nodes
-- (round47-plan.md §4.1, docs/planning/tree-rework-handoff.md §3).
--
-- Loads the REAL default, grug_trees (with shapes.lua), grug_materials and
-- grug_nodes through the Round 24 mining harness (tools/r24_mining/fixture.lua,
-- which also runs every on_mods_loaded callback and the materials audit), then:
--   A. the 28 nodes: names, drawtype, mesh, tiles, facedir, groups (the
--      trunk's plus not_in_creative_inventory), drop (the trunk), sounds,
--      the quarter's full collision/selection box, the connected boxes and
--      connects_to against tools/r46_tree/concept/shapes.js, placement
--      refusal;
--   B. the overrides: the seven leaves connect_sides {"bottom"}, the ground
--      (group soil / sand, default:gravel) connect_sides {"top"}, and a
--      recorded second run of shapes.lua shows they change nothing else;
--   C. leaf decay: each wood's leaves search their trunk and four shapes in
--      radius 3, and every piece's after_destruct starts its leaves' decay;
--      gravewood's one registration covers lane SW's swamp leaves and hanging
--      moss too, its twig joins the swamp leaves, and shapes.lua fails at load
--      when either swamp node is missing;
--   D. jungle bark M on default:jungletree and the jungle shapes, the PNGs
--      and the quarter .obj byte-equal to their Round 46 sources;
--   E. template rotation: the real wp40/r6_templates.lua turns a small cell
--      set (a 2 x 2 quarter trunk with a limb along x and one along z) so that
--      for all four turns every quarter's corner faces the trunk axis and
--      every limb's grain (facedir 4 / 12) runs along the limb.
--
-- Usage (repo root): luajit tools/r47_ta/portable_test.lua "$PWD"

local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
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
local function read(path)
	local file = assert(io.open(repo .. "/" .. path, "rb"), "missing " .. path)
	local data = file:read("*a")
	file:close()
	return data
end
local function set_of(list)
	local set = {}
	for _, value in ipairs(list or {}) do set[value] = true end
	return set
end
local function same_set(list, expected)
	local a, b = set_of(list), set_of(expected)
	for key in pairs(a) do if not b[key] then return false end end
	for key in pairs(b) do if not a[key] then return false end end
	return #list == #expected
end
local function deep_equal(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in pairs(a) do if not deep_equal(value, b[key]) then return false end end
	for key in pairs(b) do if a[key] == nil then return false end end
	return true
end

-- The real registrations.
_G.R24_MINING_HARNESS = true
local H = dofile(repo .. "/tools/r24_mining/fixture.lua")
_G.R24_MINING_HARNESS = nil
local nodes = H.nodes

-- {wood, trunk, leaves a twig joins (from below), every node decaying to it};
-- the swamp tree (lane SW) grows from gravewood wood.
local WOODS = {
	{"apple", "default:tree", {"default:leaves"}, {"default:leaves", "default:apple"}},
	{"jungle", "default:jungletree", {"default:jungleleaves"}, {"default:jungleleaves"}},
	{"acacia", "default:acacia_tree", {"default:acacia_leaves"}, {"default:acacia_leaves"}},
	{"pine", "default:pine_tree", {"default:pine_needles"}, {"default:pine_needles"}},
	{"aspen", "default:aspen_tree", {"default:aspen_leaves"}, {"default:aspen_leaves"}},
	{"silverwood", "grug_trees:silverwood_tree", {"grug_trees:silverwood_leaves"},
		{"grug_trees:silverwood_leaves"}},
	{"gravewood", "grug_trees:gravewood_tree",
		{"grug_trees:gravewood_leaves", "grug_trees:swamp_leaves"},
		{"grug_trees:gravewood_leaves", "grug_trees:swamp_leaves",
			"grug_trees:swamp_hanging_moss"}},
}
local JOINED = {}
for _, wood in ipairs(WOODS) do
	for _, leaf in ipairs(wood[3]) do JOINED[leaf] = true end
end
local SHAPES = {"quarter", "base", "branch", "twig"}
local GROUND = {"group:soil", "group:sand", "default:gravel"}

-- ---------------------------------------------------------------------------
-- The concept's data (shapes.js), read from its source
-- ---------------------------------------------------------------------------
local js = read("tools/r46_tree/concept/shapes.js")
local base_half, base_reach = js:match("var BASE_HALF = (%d+), BASE_REACH = (%d+);")
local params = {
	branch = {js:match("branch: connected%((%d+), (%d+)%)")},
	twig = {js:match("twig: connected%((%d+), (%d+)%)")},
	base = {tonumber(base_half), tonumber(base_reach)},
}
check(js:find("base: connected(BASE_HALF, BASE_REACH)", 1, true) ~= nil,
	"shapes.js builds the base from BASE_HALF / BASE_REACH")
for shape, pair in pairs(params) do
	pair[1], pair[2] = tonumber(pair[1]), tonumber(pair[2])
	check(pair[1] and pair[2], "shapes.js gives the " .. shape .. " box")
end
local function js_set(label)
	local body = assert(js:match(label .. ": {([^}]*)}"), "shapes.js " .. label)
	local set = {}
	for key in body:gmatch("(%w+): true") do set[key] = true end
	return set
end
local JS_CONNECTS = {base = js_set("base"), branch = js_set("branch"), twig = js_set("twig")}
local JS_GROUND = assert(js:match("GROUND_KINDS = {([^}]*)}"))
local ground_kinds = {}
for key in JS_GROUND:gmatch("(%w+): true") do ground_kinds[key] = true end
check(js:find("LEAF_SIDES = {top: true}", 1, true) and
	js:find("GROUND_SIDES = {bottom: true}", 1, true),
	"shapes.js: twigs join a leaf above, roots the ground below")

local S = 1 / 16
local function connected(h, reach)
	local function box(...)
		local values = {...}
		for i = 1, 6 do values[i] = values[i] * S end
		return values
	end
	return {type = "connected", fixed = box(-h, -h, -h, h, h, h),
		connect_top = box(-h, h, -h, h, 8, h), connect_bottom = box(-h, -8, -h, h, -h, h),
		connect_front = box(-h, -h, -reach, h, h, -h), connect_back = box(-h, -h, h, h, h, reach),
		connect_left = box(-reach, -h, -h, -h, h, h), connect_right = box(h, -h, -h, reach, h, h)}
end

-- ---------------------------------------------------------------------------
-- A. The 28 nodes
-- ---------------------------------------------------------------------------
local count = 0
for name in pairs(nodes) do
	if name:match("^grug_trees:[a-z]+_quarter$") or name:match("^grug_trees:[a-z]+_base$") or
			name:match("^grug_trees:[a-z]+_branch$") or name:match("^grug_trees:[a-z]+_twig$") then
		count = count + 1
	end
end
eq(count, 28, "shape node count")

for _, wood in ipairs(WOODS) do
	local key, trunk_name, joins, decay_leaves = wood[1], wood[2], wood[3], wood[4]
	local trunk = nodes[trunk_name]
	local pieces = {trunk_name}
	for _, shape in ipairs(SHAPES) do pieces[#pieces + 1] = "grug_trees:" .. key .. "_" .. shape end
	check(H.core.registered_nodes and grug_trees.shape_nodes[key] ~= nil,
		key .. ": published in grug_trees.shape_nodes")
	for _, shape in ipairs(SHAPES) do
		local name = "grug_trees:" .. key .. "_" .. shape
		local def = nodes[name]
		if check(def ~= nil, name .. " registered") then
			eq(grug_trees.shape_nodes[key][shape], name, name .. " published")
			eq(def.drop, trunk_name, name .. " drops the trunk")
			eq(def.paramtype2, "facedir", name .. " facedir")
			eq(def.paramtype, "light", name .. " paramtype light")
			local groups = {}
			for k, v in pairs(trunk.groups) do groups[k] = v end
			groups.not_in_creative_inventory = 1
			check(deep_equal(def.groups, groups), name .. " groups are the trunk's, not in creative")
			check(deep_equal(def.sounds, trunk.sounds), name .. " keeps the trunk's sounds")
			eq(def.is_ground_content, trunk.is_ground_content, name .. " is_ground_content")
			eq(def.description, trunk.description, name .. " description")
			-- placement refusal
			eq(def.node_placement_prediction, "", name .. " no client placement prediction")
			local stack = ItemStack(name)
			local before = H.core.get_node({x = 0, y = 1, z = 0}).name
			local returned = def.on_place(stack, {get_player_name = function() return "p" end,
				is_player = function() return true end},
				{type = "node", under = {x = 0, y = 0, z = 0}, above = {x = 0, y = 1, z = 0}})
			check(returned == stack, name .. " on_place hands the stack back")
			eq(H.core.get_node({x = 0, y = 1, z = 0}).name, before, name .. " places nothing")
			if shape == "quarter" then
				eq(def.drawtype, "mesh", name .. " drawtype")
				eq(def.mesh, "grug_tree_quarter_oct.obj", name .. " mesh")
				check(deep_equal(def.tiles, {{name = trunk.tiles[1], backface_culling = true},
					{name = trunk.tiles[#trunk.tiles], backface_culling = true}}),
					name .. " tiles: caps the trunk top, sides its bark, front faces only")
				local full = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
				check(deep_equal(def.selection_box, full), name .. " selection box full")
				check(deep_equal(def.collision_box, full), name .. " collision box full")
				check(def.connects_to == nil, name .. " connects to nothing itself")
			else
				eq(def.drawtype, "nodebox", name .. " drawtype")
				check(deep_equal(def.tiles, {trunk.tiles[#trunk.tiles]}), name .. " tiles: bark")
				check(deep_equal(def.node_box, connected(params[shape][1], params[shape][2])),
					name .. " node box is shapes.js connected(" .. params[shape][1] .. ", " ..
					params[shape][2] .. ")")
				local expected = {}
				local js_kinds = JS_CONNECTS[shape]
				check(js_kinds.trunk and js_kinds.quarter and js_kinds.base and js_kinds.branch and
					js_kinds.twig, "shapes.js: " .. shape .. " joins every wood piece")
				for _, piece in ipairs(pieces) do expected[#expected + 1] = piece end
				if js_kinds.leaves then
					for _, leaf in ipairs(joins) do expected[#expected + 1] = leaf end
				end
				if ground_kinds[shape] then
					for _, ground in ipairs(GROUND) do expected[#expected + 1] = ground end
				end
				check(same_set(def.connects_to, expected), name .. " connects_to " ..
					table.concat(expected, ","))
			end
		end
	end
	-- B. leaves
	for _, leaf in ipairs(joins) do
		check(deep_equal(nodes[leaf].connect_sides, {"bottom"}), leaf .. " connect_sides bottom")
	end
	for _, decay_leaf in ipairs(decay_leaves) do
		if not JOINED[decay_leaf] then
			check(nodes[decay_leaf].connect_sides == nil, decay_leaf .. " has no connect_sides")
		end
	end
	-- C. leaf decay (default/functions.lua leafdecay_on_timer / _after_destruct)
	local seen
	H.core.find_node_near = function(_, radius, names)
		seen = {radius = radius, names = names}
		return {x = 1, y = 0, z = 0}
	end
	for _, decay_leaf in ipairs(decay_leaves) do
		seen = nil
		nodes[decay_leaf].on_timer({x = 0, y = 0, z = 0})
		check(seen and seen.radius == 3 and same_set(seen.names, pieces),
			decay_leaf .. " decays without " .. table.concat(pieces, ",") .. " in radius 3")
	end
	local saved_sub, saved_add = vector.subtract, vector.add
	vector.subtract = function(a, b) return {x = a.x - b, y = a.y - b, z = a.z - b} end
	vector.add = function(a, b) return {x = a.x + b, y = a.y + b, z = a.z + b} end
	for _, piece in ipairs(pieces) do
		local searched
		H.core.find_nodes_in_area = function(p1, p2, names)
			searched = {span = p2.x - p1.x, names = names}
			return {}
		end
		nodes[piece].after_destruct({x = 0, y = 0, z = 0}, {name = piece})
		check(searched and searched.span == 6 and same_set(searched.names, decay_leaves),
			piece .. " starts its leaves' decay in radius 3")
	end
	vector.subtract, vector.add = saved_sub, saved_add
end

-- B. the ground
local ground_names = {}
for name, def in pairs(nodes) do
	local groups = def.groups or {}
	if (groups.soil or 0) > 0 or (groups.sand or 0) > 0 or name == "default:gravel" then
		ground_names[#ground_names + 1] = name
		check(deep_equal(def.connect_sides, {"top"}), name .. " connect_sides top")
	elseif def.connect_sides ~= nil then
		check(not deep_equal(def.connect_sides, {"top"}) and
			not deep_equal(def.connect_sides, {"bottom"}) or
			JOINED[name],
			name .. " has no tree connect_sides")
	end
end
table.sort(ground_names)
check(set_of(ground_names)["grug_nodes:mud"], "swamp mud is ground")
check(set_of(ground_names)["grug_nodes:blight_dirt"], "blight dirt is ground")
check(set_of(ground_names)["default:dirt_with_grass"], "grass is ground")
print("ground nodes (" .. #ground_names .. "): " .. table.concat(ground_names, " "))

-- B. nothing else changes: shapes.lua once more under a recording core
do
	local overrides, registered, loaded = {}, {}, {}
	local rec = {registered_nodes = {}}
	for name, def in pairs(nodes) do
		if not name:match("^grug_trees:[a-z]+_[a-z]+$") or not (name:match("_quarter$") or
				name:match("_base$") or name:match("_branch$") or name:match("_twig$")) then
			local copy = {}
			for k, v in pairs(def) do copy[k] = v end
			rec.registered_nodes[name] = copy
		end
	end
	function rec.override_item(name, redef)
		overrides[name] = overrides[name] or {}
		for k, v in pairs(redef) do
			overrides[name][k] = true
			if rec.registered_nodes[name] then rec.registered_nodes[name][k] = v end
		end
	end
	function rec.register_node(name, def) registered[#registered + 1] = name end
	function rec.register_on_mods_loaded(fn) loaded[#loaded + 1] = fn end
	function rec.log() end
	local saved_core, saved_mt, saved_gt = core, minetest, grug_trees
	_G.core, _G.minetest, _G.grug_trees = rec, rec, {}
	dofile(repo .. "/mods/ITEMS/grug_trees/shapes.lua")
	for _, fn in ipairs(loaded) do fn() end
	_G.core, _G.minetest, _G.grug_trees = saved_core, saved_mt, saved_gt
	eq(#registered, 28, "recorded run registers 28 nodes")
	local trunks, leaves, ground = {}, {}, set_of(ground_names)
	for _, wood in ipairs(WOODS) do
		trunks[wood[2]] = true
		for _, l in ipairs(wood[4]) do leaves[l] = true end
	end
	for name, keys in pairs(overrides) do
		local allowed
		if name == "default:jungletree" then
			allowed = {tiles = true, after_destruct = true}
		elseif trunks[name] then
			allowed = {after_destruct = true}
		elseif name:match("^grug_trees:[a-z]+_[a-z]+$") and nodes[name] and nodes[name].drop and
				trunks[nodes[name].drop] then
			allowed = {after_destruct = true}
		elseif leaves[name] then
			allowed = {on_timer = true, connect_sides = JOINED[name]}
		elseif ground[name] then
			allowed = {connect_sides = true}
		end
		if check(allowed ~= nil, "override of " .. name .. " is expected") then
			for k in pairs(keys) do
				check(allowed[k], "override of " .. name .. " changes only its own field (" .. k .. ")")
			end
		end
	end
	for name in pairs(ground) do check(overrides[name], name .. " overridden by the recorded run") end
end

-- B2. the swamp foliage is required: shapes.lua fails at load, naming the
-- node, when one is not registered before it.
for _, missing in ipairs({"grug_trees:swamp_leaves", "grug_trees:swamp_hanging_moss"}) do
	local rec = {registered_nodes = {}}
	for name, def in pairs(nodes) do
		if name ~= missing and not (name:match("^grug_trees:[a-z]+_quarter$") or
				name:match("^grug_trees:[a-z]+_base$") or name:match("^grug_trees:[a-z]+_branch$") or
				name:match("^grug_trees:[a-z]+_twig$")) then
			rec.registered_nodes[name] = def
		end
	end
	rec.override_item, rec.register_node, rec.register_on_mods_loaded, rec.log =
		function() end, function() end, function() end, function() end
	local saved_core, saved_mt, saved_gt = core, minetest, grug_trees
	_G.core, _G.minetest, _G.grug_trees = rec, rec, {}
	local ok, err = pcall(dofile, repo .. "/mods/ITEMS/grug_trees/shapes.lua")
	_G.core, _G.minetest, _G.grug_trees = saved_core, saved_mt, saved_gt
	check(not ok and tostring(err):find(missing, 1, true) ~= nil,
		"shapes.lua fails loudly without " .. missing .. " (" .. tostring(err) .. ")")
end

-- ---------------------------------------------------------------------------
-- D. jungle bark M and the mesh
-- ---------------------------------------------------------------------------
local BARK = {"grug_trees_jungle_bark_top.png", "grug_trees_jungle_bark_top.png",
	"grug_trees_jungle_bark.png"}
check(deep_equal(nodes["default:jungletree"].tiles, BARK), "default:jungletree wears bark M")
check(deep_equal(nodes["grug_trees:jungle_quarter"].tiles,
	{{name = "grug_trees_jungle_bark_top.png", backface_culling = true},
		{name = "grug_trees_jungle_bark.png", backface_culling = true}}),
	"jungle quarter wears bark M")
for _, shape in ipairs({"base", "branch", "twig"}) do
	check(deep_equal(nodes["grug_trees:jungle_" .. shape].tiles, {"grug_trees_jungle_bark.png"}),
		"jungle " .. shape .. " wears bark M")
end
check(read("mods/ITEMS/grug_trees/textures/grug_trees_jungle_bark.png") ==
	read("tools/r46_tree/astra/bark/jungle_bark_m.png"), "bark M side texture is the pick")
check(read("mods/ITEMS/grug_trees/textures/grug_trees_jungle_bark_top.png") ==
	read("tools/r46_tree/astra/bark/jungle_bark_m_top.png"), "bark M top texture is the pick")
check(read("mods/ITEMS/grug_trees/models/grug_tree_quarter_oct.obj") ==
	read("tools/r46_tree/concept/models/grug_tree_quarter_oct.obj"),
	"the quarter mesh is shapes.js's output")

-- ---------------------------------------------------------------------------
-- E. template rotation through the real r6_templates.lua
-- ---------------------------------------------------------------------------
do
	-- 5 x 1 x 4 (x, z 0-based): a 2 x 2 quarter trunk on x 1..2, z 1..2 (axis
	-- at x = z = 2.0 in node-edge coordinates), a base and a branch running
	-- east (+x, facedir 12), a twig north (+z, facedir 4) and a base south.
	local SX, SZ = 5, 4
	local layout = {
		{1, 1, "q"}, {2, 1, "q"}, {1, 2, "q"}, {2, 2, "q"},
		{3, 1, "grug_trees:apple_base", 12}, {4, 1, "grug_trees:apple_branch", 12},
		{1, 3, "grug_trees:apple_twig", 4}, {2, 0, "grug_trees:apple_base", 4},
	}
	-- facedir 0..3 -> the quarter's axis corner (x, z): +x+z turned by
	-- (x, z) -> (z, -x) per step, as rotateMeshBy6dFacedir turns the mesh.
	local CORNER = {[0] = {1, 1}, {1, -1}, {-1, -1}, {-1, 1}}
	local data = {}
	for i = 1, SX * SZ do data[i] = {name = "air", prob = 254, param2 = 0} end
	for _, cell in ipairs(layout) do
		local x, z, name, param2 = cell[1], cell[2], cell[3], cell[4]
		if name == "q" then
			name = "grug_trees:apple_quarter"
			local dx, dz = x < 2 and 1 or -1, z < 2 and 1 or -1
			for f = 0, 3 do
				if CORNER[f][1] == dx and CORNER[f][2] == dz then param2 = f end
			end
		end
		data[z * SX + x + 1] = {name = name, prob = 254, param2 = param2}
	end
	local hash = {digest = function() return "" end, digest_count = function() return "" end,
		sha256_bytes = function(s) return s end, frame = tostring, hex = function() return "h" end}
	local content = {
		content_contract = function()
			return {content_kind_masks = setmetatable({}, {__index = function() return 8 end}),
				resolve_r6 = function() return 1, 1 end, ignore_cid = 0}
		end,
		decorations = function()
			return {{id = "r47ta_probe", kind = "template", asset_or_node = "probe.mts",
				rule = "", settlement_class = 2}}
		end,
		param2_kind = function() return "facedir" end,
		content_ref = function() return 1 end,
	}
	local source = {read = function()
		return {size = {x = SX, y = 1, z = SZ}, yslice_prob = {{ypos = 0, prob = 254}}, data = data}
	end}
	local templates = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua")(
		hash, content, source)
	local function axis(param2)
		local d = math.floor(param2 / 4)
		if d == 0 or d == 5 then return "y" end
		if d == 1 or d == 2 then return "z" end
		return "x"
	end
	for rotation = 0, 3 do
		local record = templates.rotation("r47ta_probe", rotation)
		local rx = record.size_x
		local quarters, limbs = {}, {}
		for index, cell in ipairs(record.cells) do
			local x, z = (index - 1) % rx, math.floor((index - 1) / rx)
			if cell.name == "grug_trees:apple_quarter" then
				quarters[#quarters + 1] = {x = x, z = z, param2 = cell.param2}
			elseif cell.name ~= "air" then
				limbs[#limbs + 1] = {x = x, z = z, param2 = cell.param2}
			end
		end
		eq(#quarters, 4, "rotation " .. rotation .. " keeps four quarters")
		local cx, cz = 0, 0
		for _, q in ipairs(quarters) do cx, cz = cx + q.x / 4, cz + q.z / 4 end
		for _, q in ipairs(quarters) do
			local corner = CORNER[q.param2]
			check(corner and corner[1] == (q.x < cx and 1 or -1) and
				corner[2] == (q.z < cz and 1 or -1),
				"rotation " .. rotation .. ": quarter at " .. q.x .. "," .. q.z ..
				" (facedir " .. q.param2 .. ") faces the trunk axis")
		end
		for _, limb in ipairs(limbs) do
			local along = math.abs(limb.x - cx) > math.abs(limb.z - cz) and "x" or "z"
			eq(axis(limb.param2), along, "rotation " .. rotation .. ": limb at " .. limb.x .. "," ..
				limb.z .. " grain")
		end
	end
end

if failures > 0 then
	error("R47 TA FIXTURE FAIL failures=" .. failures .. " checks=" .. checks, 0)
end
print("R47 TA FIXTURE PASS checks=" .. checks)
