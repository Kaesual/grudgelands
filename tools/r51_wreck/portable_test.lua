-- Round 51 lane WRECK portable test (LuaJIT or plain Lua 5.1): the shipwreck
-- nodes, their data and their placement (tools/r51_wreck/DESIGN.md, the
-- build step), through the Round 24 mining harness (tools/r24_mining/
-- fixture.lua: the real default, grug_materials and grug_nodes sources on a
-- stub engine with Luanti's getDigParams):
--   A. the seven wreck nodes: drawtype, paramtype2 (the mast leveled, the
--      log facedir), the rooted ones' special tile, every texture present,
--      not in the creative inventory, no `wood` / `tree` group (no recipe
--      takes them);
--   B. drops and digging: the planks and the rooted nodes drop default:wood,
--      the log default:tree; an axe digs them as it digs wood and a log;
--   C. the schematic data (wp40/wreck_shapes.lua) is the shape files':
--      per shape the size, the seabed and every occupied cell with its node
--      and param2 (tools/r51_wreck/to_lua.py does the conversion);
--   D. the placement (wreck_writer.lua `layout`) on a synthetic sea: a coast,
--      a belt deepening off it, a bay, a channel, a lake, a town claim on
--      the shore and one at sea. Every wreck: one per cell at most, its
--      footprint inside the cell; every footprint column bay or belt water,
--      protected, outside the claims; never a channel, a lake or the open
--      sea; the seabed under it within one node; the water over its lowest
--      column from the shape's height + 1 to 14; the ring 16 round it water
--      (bay, belt, open sea) outside the claims. The four quarter turns
--      hold the same cells (logs along x and z swapped on an odd turn); the
--      layout is the same for the same seed and differs for another;
--   E. the writer on a fake successor context: two neighbouring owners
--      write a wreck's cells exactly once between them, only inside their
--      owner, only over water or the natural seabed (a foreign node in the
--      way keeps), and "." cells (the water in a hull) are never written.
--
-- Usage (repo root): luajit tools/r51_wreck/portable_test.lua [REPO]
local repo = arg and arg[1] or "."
_G.R24_MINING_HARNESS = true
local H = dofile(repo .. "/tools/r24_mining/fixture.lua")
_G.R24_MINING_HARNESS = nil
local nodes = H.nodes
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end
local function exists(path)
	local f = io.open(path, "rb")
	if f then f:close() end
	return f ~= nil
end

-- A. registration
local NODES = {
	["grug_nodes:wreck_planks"] = {"normal", nil, "default:wood"},
	["grug_nodes:wreck_planks_algae"] = {"normal", nil, "default:wood"},
	["grug_nodes:wreck_log"] = {"normal", "facedir", "default:tree"},
	["grug_nodes:wreck_mast"] = {"plantlike_rooted", "leveled", "default:wood"},
	["grug_nodes:wreck_rope"] = {"plantlike_rooted", nil, "default:wood"},
	["grug_nodes:wreck_sail"] = {"plantlike_rooted", nil, "default:wood"},
	["grug_nodes:wreck_algae"] = {"plantlike_rooted", nil, "default:wood"},
}
local textures = repo .. "/mods/ITEMS/grug_nodes/textures/"
for name, want in pairs(NODES) do
	local def = nodes[name]
	check(def ~= nil, name .. " is registered")
	if def then
		check((def.drawtype or "normal") == want[1], name .. " drawtype " .. want[1])
		check(def.paramtype2 == want[2], name .. " paramtype2 " .. tostring(want[2]))
		check(def.drop == want[3], name .. " drops " .. want[3])
		check(def.groups.not_in_creative_inventory == 1, name .. " not in creative")
		check(def.groups.wood == nil and def.groups.tree == nil, name .. " has no wood/tree group")
		check(def.groups.choppy ~= nil, name .. " is chopped")
		check(def.is_ground_content == false, name .. " is no ground content")
		for _, tile in ipairs(def.tiles) do
			check(exists(textures .. tile), name .. " tile " .. tile)
		end
		if want[1] == "plantlike_rooted" then
			local special = def.special_tiles and def.special_tiles[1]
			check(special and exists(textures .. special.name) and special.tileable_vertical == true,
				name .. " special tile")
			check(def.waving == (want[2] == "leveled" and 0 or 1), name .. " waving")
		end
	end
end

-- B. digging: an axe takes the planks as wood and the log as a log
for name, like in pairs({["grug_nodes:wreck_planks"] = "default:wood",
		["grug_nodes:wreck_mast"] = "default:wood", ["grug_nodes:wreck_log"] = "default:tree"}) do
	local axe
	for _, item in pairs(H.items) do
		if item.groups and item.groups.grug_axe_tier == 3 then axe = item end
	end
	check(axe ~= nil, "a tier 3 axe is in the harness")
	if axe then
		local caps = axe.tool_capabilities
		local a = H.get_dig_params(nodes[name].groups, caps, 0)
		local b = H.get_dig_params(nodes[like].groups, caps, 0)
		check(a.diggable and a.diggable == b.diggable and math.abs(a.time - b.time) < 1e-9,
			name .. " digs like " .. like)
	end
	for key, value in pairs(nodes[like].groups) do
		if key ~= "wood" and key ~= "tree" and key ~= "flammable" then
			check(nodes[name].groups[key] == value, name .. " keeps " .. like .. "'s group " .. key)
		end
	end
end

-- C. the schematic data is the shape files'
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local shapes = dofile(wp40 .. "/wreck_shapes.lua")
local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end
for index, file in ipairs({"hull", "bow", "stern", "debris"}) do
	local json = read(repo .. "/tools/r51_wreck/shapes/" .. file .. ".json")
	local shape = shapes.shapes[index]
	check(shape.key == "wreck." .. file, file .. " key")
	local sx = tonumber(json:match('"x": (%d+)'))
	local sy = tonumber(json:match('"y": (%d+)'))
	local sz = tonumber(json:match('"z": (%d+)'))
	check(shape.size.x == sx and shape.size.y == sy and shape.size.z == sz, file .. " size")
	check(shape.seabed == tonumber(json:match('"seabed": (%d+)')), file .. " seabed")
	local palette = {}
	for letter, body in json:match('"palette": (%b{})'):gmatch('"(%a)": (%b{})') do
		palette[letter] = {body:match('"name": "([^"]+)"'), tonumber(body:match('"param2": (%d+)'))}
	end
	local rows = {}
	for row in json:match('"layers": (%b[])'):gmatch('"([%.%a]+)"') do rows[#rows + 1] = row end
	check(#rows == sy * sz, file .. " layer rows")
	local want = {}
	for r, row in ipairs(rows) do
		local y, z = math.floor((r - 1) / sz), (r - 1) % sz
		for x = 0, #row - 1 do
			local letter = row:sub(x + 1, x + 1)
			if letter ~= "." then
				want[x .. "," .. y .. "," .. z] = palette[letter][1] .. "|" .. palette[letter][2]
			end
		end
	end
	local got, n = {}, 0
	for i = 1, #shape.cells, 5 do
		local c = shape.cells
		got[c[i] .. "," .. c[i + 1] .. "," .. c[i + 2]] = shapes.names[c[i + 3]] .. "|" .. c[i + 4]
		n = n + 1
	end
	local same = true
	for key, value in pairs(want) do if got[key] ~= value then same = false end end
	for key in pairs(got) do if not want[key] then same = false end end
	check(same, file .. " cells match the shape file (" .. n .. ")")
end
for _, name in ipairs(shapes.names) do
	check(nodes[name] ~= nil, "shape node " .. name .. " is registered")
end

-- D. the placement on a synthetic sea
local W = dofile(wp40 .. "/wreck_writer.lua")
-- land z < 0; a belt off it whose floor falls 1 node per 10; a bay
-- 1500..2300 x 600..1200 at 11 deep; a channel x 3000..3100; a lake at
-- 600..700 x -300..-200; claims: a town on the shore 1000..1300 x -200..100
-- and one at sea 4000..4200 x 300..500; the open sea from z 400.
local function ground_at(x, z)
	if z < 0 then return 5 end
	if x >= 1500 and x <= 2300 and z >= 600 and z <= 1200 then return -10 end
	return 1 - math.min(30, math.floor(z / 10)) + ((x + z) % 7 == 0 and 1 or 0)
end
local function query(x, z)
	if x >= 600 and x <= 700 and z >= -300 and z <= -200 then return "lake", "z", 5, nil, 3, false end
	if z < 0 then return nil end
	local depth = 1 - ground_at(x, z)
	if x >= 3000 and x <= 3100 then return "channel", "z", 60, z, 10, z >= 24 end
	if x >= 1500 and x <= 2300 and z >= 600 and z <= 1200 then return "bay", "z", 5, z, depth, true end
	if z >= 400 then return "open_sea", nil, nil, z, depth, true end
	return "belt", "z", 5, z, depth, z >= 24
end
local function excluded(x, z)
	return (x >= 1000 and x <= 1300 and z >= -200 and z <= 100) or
		(x >= 4000 and x <= 4200 and z >= 300 and z <= 500)
end
local function new_layout(seed)
	return W.layout(shapes, {seed = seed, water_query = query, ground_at = ground_at,
		excluded = excluded, water_level = 1})
end
local layout = new_layout("12345")
local sites, by_cell = {}, {}
for cz = -2, 6 do
	for cx = -4, 20 do
		local site = layout.site(cx, cz)
		if site then
			sites[#sites + 1] = site
			site.cx, site.cz = cx, cz
		end
	end
end
check(#sites > 0, "the synthetic sea holds wrecks (" .. #sites .. ")")
local bad = {}
local function fail_site(label) bad[label] = (bad[label] or 0) + 1 end
local RING_OK = {bay = true, belt = true, open_sea = true}
for _, site in ipairs(sites) do
	local shape = layout.shapes[site.shape]
	local key = site.cx .. "," .. site.cz
	if by_cell[key] then fail_site("two wrecks in a cell") end
	by_cell[key] = true
	local x0, z0 = site.cx * W.CELL, site.cz * W.CELL
	if site.x < x0 + W.INSET or site.x + site.w - 1 > x0 + W.CELL - 1 - W.INSET or
			site.z < z0 + W.INSET or site.z + site.d - 1 > z0 + W.CELL - 1 - W.INSET then
		fail_site("footprint outside its cell")
	end
	local low, high = math.huge, -math.huge
	for _, col in ipairs(shape.turns[site.turn].columns) do
		local x, z = site.x + col[1], site.z + col[2]
		local class, _, _, _, _, protected = query(x, z)
		if class ~= "bay" and class ~= "belt" then fail_site("footprint not bay or belt: " .. tostring(class)) end
		if not protected then fail_site("footprint not protected") end
		if excluded(x, z) then fail_site("footprint in a claim") end
		low, high = math.min(low, ground_at(x, z)), math.max(high, ground_at(x, z))
	end
	if high - low > 1 then fail_site("seabed varies by more than one") end
	if low ~= site.y then fail_site("the wreck does not sit on the lowest column") end
	local depth = 1 - low
	if depth < shape.height + 1 or depth > W.MAX_DEPTH then fail_site("depth out of band") end
	for x = site.x - W.MARGIN, site.x + site.w - 1 + W.MARGIN, 2 do
		for _, z in ipairs({site.z - W.MARGIN, site.z + site.d - 1 + W.MARGIN}) do
			if not RING_OK[(query(x, z))] or excluded(x, z) then fail_site("ring not clear") end
		end
	end
	-- the top cell stays under water
	local top = -math.huge
	layout.cells(site, function(_, y) top = math.max(top, y) end)
	if top > 0 then fail_site("a cell above the surface") end
end
for label, count in pairs(bad) do check(false, label .. " (" .. count .. ")") end
local kinds = {}
for _, site in ipairs(sites) do kinds[site.key] = true end
check(kinds["wreck.hull"] and kinds["wreck.debris"], "hulls and debris fields are placed")
-- the quarter turns
local LOG = nil
for i, name in ipairs(shapes.names) do if name == "grug_nodes:wreck_log" then LOG = i end end
for s, shape in ipairs(layout.shapes) do
	local zero = shape.turns[0].cells
	for t = 1, 3 do
		local turn = shape.turns[t].cells
		local ok = #turn == #zero
		for i = 1, #zero do
			local a, b = zero[i], turn[i]
			if a[2] ~= b[2] or a[4] ~= b[4] then ok = false end
			if a[4] == LOG and t % 2 == 1 and a[5] ~= 0 and a[5] == b[5] then ok = false end
			if a[4] ~= LOG and a[5] ~= b[5] then ok = false end
		end
		check(ok, shapes.shapes[s].key .. " turn " .. t .. " keeps its cells")
	end
end
-- determinism
local again, other = new_layout("12345"), new_layout("777")
local same, differs = true, false
for cz = -2, 6 do
	for cx = -4, 20 do
		local a, b, c = layout.site(cx, cz), again.site(cx, cz), other.site(cx, cz)
		if (a and a.x) ~= (b and b.x) or (a and a.z) ~= (b and b.z) or (a and a.turn) ~= (b and b.turn) then
			same = false
		end
		if (a and a.x) ~= (c and c.x) then differs = true end
	end
end
check(same, "the same seed gives the same wrecks")
check(differs, "another seed gives other wrecks")

-- E. the writer on a fake successor context
local fake = {registered_nodes = H.nodes, CONTENT_AIR = 1}
local cids, names = {air = 1}, {"air"}
function fake.get_content_id(name)
	if not cids[name] then
		names[#names + 1] = name
		cids[name] = #names
	end
	return cids[name]
end
function fake.get_name_from_content_id(c) return names[c] end
local site = sites[1]
for _, s in ipairs(sites) do
	if s.key == "wreck.hull" then site = s break end
end
local split_x = site.x + math.floor(site.w / 2)
local planner = {column_values_at = function(x, z) return nil, nil, nil, nil, nil, ground_at(x, z) end}
local horizontal = {lowest_exclusion_value_at = function(x, z) return excluded(x, z) and 1 or nil end}
local pass = W.config(fake, shapes).new({full_seed_string = "12345",
	zones_session = {water_query_at = query}, planner_source = planner,
	horizontal = horizontal, source = {}})
local WATER, SAND = fake.get_content_id("default:water_source"), fake.get_content_id("default:sand")
local FOREIGN = fake.get_content_id("default:cobble")
local world, written, outside = {}, {}, 0
local function wkey(x, y, z) return x .. "," .. y .. "," .. z end
-- one foreign node in the wreck's way (an authored block another pass left)
local blocked
layout.cells(site, function(x, y, z) blocked = blocked or wkey(x, y, z) end)
world[blocked] = FOREIGN
local function owner(min_x, max_x)
	local context = {min_x = min_x, max_x = max_x, min_z = site.z - 40, max_z = site.z + 39,
		min_y = -32, max_y = 47}
	function context.inside_owner(x, y, z)
		return x >= context.min_x and x <= context.max_x and z >= context.min_z and
			z <= context.max_z and y >= context.min_y and y <= context.max_y
	end
	function context.settled_at(x, y, z)
		local c = world[wkey(x, y, z)]
		if c then return c, 0 end
		return y <= ground_at(x, z) and SAND or (y <= 1 and WATER or 1), 0
	end
	function context.write_road(x, y, z, c, param2)
		if not context.inside_owner(x, y, z) then outside = outside + 1 end
		local key = wkey(x, y, z)
		written[key] = (written[key] or 0) + 1
		world[key] = c
	end
	return context
end
pass.dress(owner(split_x - 79, split_x - 1))
pass.dress(owner(split_x, split_x + 79))
local expected, once, foreign_kept = 0, true, world[blocked] == FOREIGN
layout.cells(site, function(x, y, z)
	local key = wkey(x, y, z)
	if key ~= blocked then
		expected = expected + 1
		if written[key] ~= 1 then once = false end
	end
end)
local total = 0
for _ in pairs(written) do total = total + 1 end
check(outside == 0, "nothing is written outside an owner")
check(once and total == expected, "two owners write the wreck's cells once (" .. total .. "/" ..
	expected .. ")")
check(foreign_kept and not written[blocked], "a foreign node in the way keeps")
-- a cell the shape leaves "." (the water in a hull) is never written
local inside_water = 0
for key in pairs(written) do
	local x, y, z = key:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
	if world[key] == WATER then inside_water = inside_water + 1 end
	local _ = x, y, z
end
check(inside_water == 0, "no write puts water")

if failures > 0 then error(failures .. " FAILURES of " .. checks .. " checks", 0) end
print(("PASS r51_wreck: %d checks; %d wrecks on the synthetic sea"):format(checks, #sites))
