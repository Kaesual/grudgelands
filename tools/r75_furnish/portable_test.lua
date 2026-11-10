-- Round 75 FURNISH portable fixture.
-- Usage (repo root): luajit tools/r75_furnish/portable_test.lua [REPO]

local repo = arg[1] or "."
local checks = 0

local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local function eq(actual, expected, label)
	check(actual == expected,
		label .. " (" .. tostring(actual) .. " vs " .. tostring(expected) .. ")")
end

local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local expected = {
	{"plate_wood","N06","table"}, {"plate_ceramic","N06","table"},
	{"bowl_wood","N06","table"}, {"bowl_ceramic","N06","table"},
	{"jug","N07","table"}, {"mug","N07","table"},
	{"bread_board","N08","table"}, {"meal_platter","N08","table"},
	{"fruit_basket","N09","table"}, {"vegetable_basket","N09","table"},
	{"sack_closed","N10","floor"}, {"sack_grain","N10","floor"},
	{"crate_vegetables","N11","floor"}, {"crate_fish","N11","floor"},
	{"crate_meat","N11","floor"}, {"crate_ore","N11","floor"},
	{"wicker_basket","N12","floor"}, {"wicker_tray","N12","table"},
	{"book_stack","N13","table"}, {"book_open","N14","table"},
	{"lectern","N14","floor"}, {"writing_set","N15","table"},
	{"scroll","N16","table"}, {"scroll_bundle","N16","table"},
	{"map_sheet","N16","table"}, {"alchemy_set","N17","table"},
	{"herb_bundle","N18","wall"}, {"tool_board","N19","wall"},
	{"material_ore","N20","table"}, {"material_metal","N20","table"},
	{"material_gems","N20","table"}, {"cloth_rolls","N21","table"},
	{"yarn","N21","table"}, {"leather_bundle","N22","table"},
	{"fur_bundle","N22","table"}, {"rope_coil","N23","floor"},
	{"oar","N23","wall"}, {"candle_bundle","N24","table"},
	{"wax_bowl","N24","table"}, {"candle_group","N25","table"},
	{"sconce_iron","N26","wall"}, {"sconce_wood","N26","wall"},
	{"chandelier","N27","ceiling"}, {"fire_basket","N28","floor"},
	{"hearth","N28","floor"}, {"rug_red","N29","floor"},
	{"rug_green","N29","floor"}, {"rug_blue","N29","floor"},
	{"runner_red","N29","floor"}, {"runner_blue","N29","floor"},
	{"wall_shelf","N30","wall"}, {"wall_shelf_filled","N30","wall"},
	{"planter","N31","floor"}, {"hanging_plant","N31","ceiling"},
	{"tapestry_accord","N32","wall"}, {"tapestry_throng","N32","wall"},
}

local registered = {}
local placed
local nodes = {}
local function position_key(pos)
	return pos.x .. ":" .. pos.y .. ":" .. pos.z
end
core = {
	registered_nodes = registered,
	register_node = function(name, def)
		check(registered[name] == nil, "unique registration " .. name)
		registered[name] = def
	end,
	get_node_or_nil = function(pos) return nodes[position_key(pos)] end,
	dir_to_facedir = function(direction)
		if math.abs(direction.x) > math.abs(direction.z) then
			return direction.x > 0 and 1 or 3
		end
		return direction.z < 0 and 2 or 0
	end,
	item_place = function(itemstack, placer, pointed_thing, param2)
		placed = {itemstack = itemstack, placer = placer, pointed = pointed_thing, param2 = param2}
		return "placed"
	end,
}
default = {
	node_sound_wood_defaults = function() return {kind = "wood"} end,
	node_sound_stone_defaults = function() return {kind = "stone"} end,
	node_sound_metal_defaults = function() return {kind = "metal"} end,
	node_sound_defaults = function() return {kind = "soft"} end,
}
grug_decor = {}
grug_core = {}

local globals_before = {}
for key in pairs(_G) do globals_before[key] = true end

local catalog = assert(loadfile(repo ..
	"/mods/ITEMS/grug_decor/furnishings_catalog.lua"))()
dofile(repo .. "/mods/CORE/grug_core/node_rightclick.lua")
dofile(repo .. "/mods/ITEMS/grug_decor/furnishings.lua")

for key in pairs(_G) do
	check(globals_before[key] or key == "core" or key == "default" or key == "grug_decor"
		or key == "grug_core",
		"no global leak: " .. tostring(key))
end

eq(#catalog, #expected, "catalog row count")

local family_counts = {}
for index, want in ipairs(expected) do
	local row = catalog[index]
	local item = "grug_decor:" .. want[1]
	eq(row.item, item, "stable catalog item " .. index)
	eq(row.family, want[2], "catalog family " .. item)
	eq(row.mount, want[3], "catalog mount " .. item)
	check(type(row.price) == "number" and row.price >= 5 and row.price <= 2500,
		"catalog price range " .. item)
	check(not row.item:find("capital_", 1, true), "no capital service item " .. item)
	local def = registered[item]
	check(def ~= nil, "catalog item registered " .. item)
	eq(def._grug_decor_family, row.family, "registered family " .. item)
	eq(def._grug_decor_mount, row.mount, "registered mount " .. item)
	family_counts[row.family] = (family_counts[row.family] or 0) + 1
end

for number = 6, 32 do
	local family = string.format("N%02d", number)
	check(family_counts[family] ~= nil, "complete family " .. family)
end

eq(catalog[43].price, 1500, "chandelier fixed guide price")
eq(catalog[55].price, 2500, "Accord tapestry fixed guide price")
eq(catalog[56].price, 2500, "Throng tapestry fixed guide price")
check(registered["grug_decor:display_armor"] ~= nil, "static armor display registered")
check(registered["grug_decor:display_weapon"] ~= nil, "static weapon display registered")
check(registered["grug_decor:display_armor"]._grug_decor_family == "N02",
	"armor display family")
check(registered["grug_decor:display_weapon"]._grug_decor_family == "N05",
	"weapon display family")

local registration_count = 0
for _ in pairs(registered) do registration_count = registration_count + 1 end
eq(registration_count, #expected + 2, "only frozen registrations")

local function visit_boxes(def, name)
	check(def.drawtype == "nodebox" or def.drawtype == "mesh", "authored drawtype " .. name)
	check(def.node_box and def.node_box.type == "fixed", "fixed geometry " .. name)
	check(def.paramtype2 == "facedir", "facedir orientation " .. name)
	eq(def.on_place, grug_decor.place_furnishing, "mount-aware placement " .. name)
	check(def.is_ground_content == false, "not ground content " .. name)
	check(def._grug_decor_family ~= nil, "family field " .. name)
	check(def._grug_decor_mount ~= nil, "mount field " .. name)
	local fixed = def.node_box.fixed
	local boxes = type(fixed[1]) == "number" and {fixed} or fixed
	check(#boxes > 0, "non-empty geometry " .. name)
	local bottom = 1
	for box_index, one in ipairs(boxes) do
		eq(#one, 6, "six box coordinates " .. name .. ":" .. box_index)
		for coordinate = 1, 6 do
			check(type(one[coordinate]) == "number", "numeric geometry " .. name)
			check(one[coordinate] >= -0.5 and one[coordinate] <= 0.5,
				"geometry within cell " .. name)
		end
		check(one[1] < one[4] and one[2] < one[5] and one[3] < one[6],
			"positive box volume " .. name .. ":" .. box_index)
		if one[2] < bottom then bottom = one[2] end
	end
	if def._grug_decor_mount == "table" or def._grug_decor_mount == "floor" then
		eq(bottom, -0.5, "supported from node bottom " .. name)
	end
	if def._grug_decor_mount == "table" or def._grug_decor_mount == "wall"
			or def._grug_decor_mount == "ceiling" then
		check(def.walkable == false, "detail nonwalkable " .. name)
	end
end

for name, def in pairs(registered) do visit_boxes(def, name) end

local mesh_ids = {
	"bread_board", "meal_platter", "fruit_basket", "vegetable_basket", "sack_grain",
	"crate_vegetables", "crate_fish", "crate_meat", "crate_ore", "tool_board",
	"material_ore", "material_metal", "material_gems", "candle_group", "sconce_iron",
	"sconce_wood", "chandelier", "fire_basket", "hearth", "rug_red", "rug_green",
	"rug_blue", "runner_red", "runner_blue", "wall_shelf_filled", "planter",
	"hanging_plant", "tapestry_accord", "tapestry_throng", "display_armor",
	"display_weapon",
}
local expected_mesh = {}
for _, suffix in ipairs(mesh_ids) do expected_mesh["grug_decor:" .. suffix] = true end

local mesh_bounds = {}
for name, def in pairs(registered) do
	eq(def.drawtype == "mesh", expected_mesh[name] == true, "exact mesh set " .. name)
	if def.drawtype == "mesh" then
		local path = "mods/ITEMS/grug_decor/models/" .. def.mesh
		local source_mesh = read(path)
		check(source_mesh:find("Precompensated for Luanti OBJ loader X reflection", 1, true),
			"engine X reflection documented " .. name)
		local current_slot
		local groups = {}
		local uvs = {}
		for line in source_mesh:gmatch("[^\n]+") do
			local slot = line:match("^g texture_slot_(%d+)$")
			if slot then
				current_slot = tonumber(slot)
				groups[current_slot] = groups[current_slot] or {
					faces = 0, min_x = 1, min_y = 1, min_z = 1,
					max_x = -1, max_y = -1, max_z = -1,
				}
			end
			local x, y, z = line:match("^v ([^ ]+) ([^ ]+) ([^ ]+)$")
			if x then
				check(current_slot ~= nil, "mesh group before vertices " .. name)
				-- Irrlicht's OBJ loader negates X. Validate the runtime coordinates,
				-- which must reproduce the Lua-authored component positions.
				x, y, z = -tonumber(x), tonumber(y), tonumber(z)
				check(x >= -0.5 and x <= 0.5 and y >= -0.5 and y <= 0.5
					and z >= -0.5 and z <= 0.5, "mesh within cell " .. name)
				local bounds = groups[current_slot]
				bounds.min_x, bounds.max_x = math.min(bounds.min_x, x), math.max(bounds.max_x, x)
				bounds.min_y, bounds.max_y = math.min(bounds.min_y, y), math.max(bounds.max_y, y)
				bounds.min_z, bounds.max_z = math.min(bounds.min_z, z), math.max(bounds.max_z, z)
			end
			local u, v = line:match("^vt ([^ ]+) ([^ ]+)$")
			if u then uvs[tonumber(u) .. ":" .. tonumber(v)] = true end
			if line:find("^f ") then groups[current_slot].faces = groups[current_slot].faces + 1 end
		end
		for slot = 0, #def.tiles - 1 do
			check(groups[slot] and groups[slot].faces > 0, "non-empty texture slot " .. name .. ":" .. slot)
		end
		local group_count = 0
		for _ in pairs(groups) do group_count = group_count + 1 end
		eq(group_count, #def.tiles, "one mesh group per tile " .. name)
		check(uvs["0:0"] and uvs["1:0"] and uvs["1:1"] and uvs["0:1"],
			"explicit full-face UVs " .. name)
		mesh_bounds[name] = groups
	end
end

for _, suffix in ipairs({"rug_red", "rug_green", "rug_blue", "runner_red", "runner_blue"}) do
	eq(#registered["grug_decor:" .. suffix].tiles, 2, "rug patterned with border " .. suffix)
end
for _, suffix in ipairs({"tapestry_accord", "tapestry_throng"}) do
	local banner = mesh_bounds["grug_decor:" .. suffix][1]
	local width = banner.max_x - banner.min_x
	local height = banner.max_y - banner.min_y
	check(math.abs(width * 2 - height) < 0.000001, "heraldry preserves 1:2 aspect " .. suffix)
end
local tools = mesh_bounds["grug_decor:tool_board"][1]
eq(tools.min_x, -0.28, "asymmetric tool geometry keeps runtime left edge")
eq(tools.max_x, 0.34, "asymmetric tool geometry keeps runtime right edge")

local fire_shapes = {
	fire_basket = {top = 0.08, ember_top = -0.34,
		bounds = {-0.31, -0.5, -0.31, 0.31, 0.08, 0.31}},
	hearth = {top = 0.10, ember_top = -0.32,
		bounds = {-0.48, -0.5, -0.42, 0.48, 0.48, 0.48}},
}
for suffix, expected in pairs(fire_shapes) do
	local def = registered["grug_decor:" .. suffix]
	eq(#def.tiles, 4, "fire has fixture, ember, orange and pale materials " .. suffix)
	check(def.tiles[2]:find("^default_coal_block.png"), "dark ember texture " .. suffix)
	check(def.tiles[3]:find("^default_clay.png"), "orange flame texture " .. suffix)
	check(def.tiles[4]:find("^default_clay.png"), "pale flame texture " .. suffix)
	local groups = mesh_bounds["grug_decor:" .. suffix]
	eq(groups[1].faces, 12, "one low ember cuboid " .. suffix)
	eq(groups[1].max_y, expected.ember_top, "ember stays below flames " .. suffix)
	eq(groups[2].faces, 36, "three stepped orange flame cuboids " .. suffix)
	eq(groups[3].faces, 24, "two stepped pale flame cuboids " .. suffix)
	eq(math.max(groups[2].max_y, groups[3].max_y), expected.top,
		"flame silhouette preserves authored top " .. suffix)
	check(groups[2].max_x - groups[2].min_x < 0.3,
		"orange flames remain narrow " .. suffix)
	check(groups[3].max_x - groups[3].min_x < 0.2,
		"pale flames remain narrow " .. suffix)
	local bounds = {1, 1, 1, -1, -1, -1}
	for _, box in ipairs(def.node_box.fixed) do
		bounds[1], bounds[4] = math.min(bounds[1], box[1]), math.max(bounds[4], box[4])
		bounds[2], bounds[5] = math.min(bounds[2], box[2]), math.max(bounds[5], box[5])
		bounds[3], bounds[6] = math.min(bounds[3], box[3]), math.max(bounds[6], box[6])
	end
	for coordinate = 1, 6 do
		eq(bounds[coordinate], expected.bounds[coordinate],
			"fire furnishing preserves bound " .. suffix .. ":" .. coordinate)
	end
end

local substantial = {
	"sack_closed", "sack_grain", "crate_vegetables", "crate_fish", "crate_meat",
	"crate_ore", "wicker_basket", "lectern", "fire_basket", "hearth", "planter",
	"display_armor", "display_weapon",
}
for _, suffix in ipairs(substantial) do
	local def = registered["grug_decor:" .. suffix]
	check(def.walkable == true, "substantial prop collision " .. suffix)
	check(def.collision_box == def.node_box, "bounded collision " .. suffix)
end

local light_minimum = {
	candle_group = 1, sconce_iron = 1, sconce_wood = 1, chandelier = 1,
	fire_basket = 1, hearth = 1,
}
for suffix, minimum in pairs(light_minimum) do
	check((registered["grug_decor:" .. suffix].light_source or 0) >= minimum,
		"static light source " .. suffix)
end

-- Every texture referenced by the real definitions exists at its owning mod path.
local function texture_path(filename)
	if filename:find("^default_") then
		return "mods/BASE/default/textures/" .. filename
	elseif filename:find("^grug_decor_") then
		return "mods/ITEMS/grug_decor/textures/" .. filename
	elseif filename:find("^grug_cooking_") then
		return "mods/ITEMS/grug_cooking/textures/" .. filename
	elseif filename:find("^grug_gathering_") then
		return "mods/ITEMS/grug_gathering/textures/" .. filename
	elseif filename:find("^grug_mapgen_") then
		return "mods/MAPGEN/grug_mapgen/textures/" .. filename
	elseif filename:find("^mobs_") then
		return "mods/ENTITIES/mobs/textures/" .. filename
	end
end
for name, def in pairs(registered) do
	for _, tile in ipairs(def.tiles) do
		local texture = type(tile) == "table" and tile.name or tile
		local filename = texture:match("^([^%^:]+)")
		local path = texture_path(filename)
		check(path ~= nil, "known texture owner " .. name .. " -> " .. tostring(filename))
		local handle = path and io.open(repo .. "/" .. path, "rb") or nil
		check(handle ~= nil, "referenced texture exists " .. name .. " -> " .. tostring(filename))
		if handle then handle:close() end
	end
end

local source = read("mods/ITEMS/grug_decor/furnishings.lua")
local forbidden = {
	"register_entity", "register_abm", "register_lbm", "register_globalstep",
	"get_meta", "get_inventory", "set_inventory", "on_timer", "formspec =",
	"on_rightclick =", "after_place_node", "on_construct", "core.after",
}
for _, token in ipairs(forbidden) do
	check(not source:find(token, 1, true), "no behavior token " .. token)
end
check(source:find("Facedir 0 presents", 1, true) ~= nil,
	"orientation contract documented")
check(source:find("grug_mapgen_faction_banner_accord.png", 1, true) ~= nil,
	"actual Accord hart media")
check(source:find("grug_mapgen_faction_banner_throng.png", 1, true) ~= nil,
	"actual Throng boar media")
check(not source:find("tiles = {iron, flame}", 1, true),
	"fire basket does not use one bright flame block")
check(not source:find("tiles = {stone, flame}", 1, true),
	"hearth does not use one bright flame block")
check(not source:find("core.rotate_node", 1, true), "no unrestricted 6d placement")

-- Pointed-surface placement stays upright, aligns wall backs, and requires a
-- complete support face instead of accepting panes, plants, air, or edges.
registered["fixture:full"] = {walkable = true, drawtype = "normal"}
registered["fixture:table"] = {
	walkable = true,
	drawtype = "nodebox",
	-- Exact shipped cottages_table top: reversed y coordinates and y max 0.48.
	node_box = {type = "fixed", fixed = {
		{-0.1, -0.5, -0.1, 0.1, 0.3, 0.1},
		{-0.5, 0.48, -0.5, 0.5, 0.4, 0.5},
	}},
}
registered["fixture:partial"] = {
	walkable = true,
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-0.1, -0.5, -0.1, 0.1, 0.5, 0.1}},
}
registered["fixture:replaceable"] = {walkable = false, buildable_to = true}
local interactive_clicks = 0
registered["fixture:interactive"] = {
	-- A non-walkable interactive target proves routing happens before support
	-- rejection, as required for doors and stations while this item is held.
	walkable = false,
	drawtype = "normal",
	on_rightclick = function(pos, node, player, stack, pointed)
		interactive_clicks = interactive_clicks + 1
		eq(node.name, "fixture:interactive", "real rightclick receives node")
		eq(pointed.under, pos, "real rightclick receives pointed position")
		return "opened"
	end,
}

local function itemstack(suffix)
	return {get_name = function() return "grug_decor:" .. suffix end}
end
local placer = {
	get_look_dir = function() return {x = 1, y = 0, z = 0} end,
	get_player_control = function() return {sneak = false} end,
}
local function point(under, above, support)
	nodes = {}
	nodes[position_key(under)] = support and {name = support} or nil
	return {type = "node", under = under, above = above}
end
local function try_place(suffix, pointed)
	placed = nil
	local stack = itemstack(suffix)
	local result = registered["grug_decor:" .. suffix].on_place(stack, placer, pointed)
	return result, stack
end

local result = try_place("plate_wood",
	point({x = 0, y = 0, z = 0}, {x = 0, y = 1, z = 0}, "fixture:table"))
eq(result, "placed", "table item placed on exact shipped cottages table top")
eq(placed.param2, 1, "table item horizontal facedir")
result = try_place("plate_wood",
	point({x = 0, y = 0, z = 0}, {x = 0, y = 1, z = 0}, "fixture:interactive"))
eq(result, "opened", "interactive node receives rightclick before placement checks")
eq(interactive_clicks, 1, "interactive node clicked exactly once")
check(placed == nil, "interactive rightclick did not place furnishing")
result = try_place("hearth",
	point({x = 0, y = 0, z = 0}, {x = 0, y = 1, z = 0}, "fixture:full"))
eq(result, "placed", "floor item placed on top face")
eq(placed.param2, 1, "floor item horizontal facedir")
result = try_place("tool_board",
	point({x = 0, y = 0, z = 1}, {x = 0, y = 0, z = 0}, "fixture:full"))
eq(result, "placed", "wall item placed against wall")
eq(placed.param2, 0, "wall back +Z aligned to support")
result = try_place("tool_board",
	point({x = 1, y = 0, z = 0}, {x = 0, y = 0, z = 0}, "fixture:full"))
eq(result, "placed", "wall item placed on side wall")
eq(placed.param2, 1, "wall back +X aligned to support")
result = try_place("chandelier",
	point({x = 0, y = 1, z = 0}, {x = 0, y = 0, z = 0}, "fixture:full"))
eq(result, "placed", "ceiling item placed under ceiling")
eq(placed.param2, 1, "ceiling item remains upright")

local rejected, same = try_place("tool_board",
	point({x = 0, y = 0, z = 0}, {x = 0, y = 1, z = 0}, "fixture:full"))
eq(rejected, same, "wall item rejects horizontal surface")
check(placed == nil, "wrong surface did not place")
rejected, same = try_place("plate_wood",
	point({x = 0, y = 0, z = 0}, {x = 0, y = 1, z = 0}, "fixture:partial"))
eq(rejected, same, "partial support rejected")
check(placed == nil, "partial support did not place")
rejected, same = try_place("plate_wood",
	point({x = 0, y = 0, z = 0}, {x = 0, y = 1, z = 0}, "fixture:replaceable"))
eq(rejected, same, "replaceable support rejected")
check(placed == nil, "replaceable support did not place")
rejected, same = try_place("plate_wood",
	point({x = 0, y = 0, z = 0}, {x = 0, y = 1, z = 0}, nil))
eq(rejected, same, "air support rejected")
check(placed == nil, "air support did not place")

print("R75 FURNISH PORTABLE PASS checks=" .. checks ..
	" catalog=" .. #catalog .. " nodes=" .. registration_count)
