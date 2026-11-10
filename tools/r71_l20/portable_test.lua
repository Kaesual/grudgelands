-- Round 71 lane L20 portable test (LuaJIT): The Stilled Seam's catalogue row, its
-- loot table and the written template, proved over the cells, not by eye: the route
-- for a player and for a mob, the door, the ore, the packs and the light. Lane RANGE
-- (J): levels 20-69, the tier's ore and gem in the template's places, the chest's
-- materials by band. The engine half is tools/r71_l20/run.sh, the numbers
-- tools/r71_l20/balance.py.
-- Prints "R71 L20 PORTABLE PASS checks=<n>".
--
--   luajit tools/r71_l20/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function eq(a, b, label)
	check(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

local C = dofile(repo .. "/mods/PLAYER/grug_expeditions/catalogue.lua")
local L = dofile(repo .. "/mods/PLAYER/grug_expeditions/loot.lua")
local T = dofile(repo .. "/mods/PLAYER/grug_expeditions/template.lua")

-- A. The catalogue row.
local row = C.definition("stilled_seam")
check(row ~= nil, "A the row")
eq(row.name, "The Stilled Seam", "A its name")
eq(row.level, 20, "A its level")
eq(row.max_level, 69, "A up to 69")
eq(row.max_players, 3, "A at most three")
eq(row.template, "stilled_seam", "A its template")
local listed = C.list()
-- Round 72: The Second Shift and The Last Mint join the list; the Seam stays first.
check(#listed >= 1, "A rows a dialog may offer")
eq(listed[1].id, "stilled_seam", "A The Stilled Seam is the first")
check(not listed[1].hidden, "A not hidden")

-- B. The loot table: at the run's level, no ore, no gem, what the brief asks.
local tbl = L.TABLES.stilled_seam
check(tbl and tbl.gear and tbl.coin_bags and tbl.materials, "B equipment, coins and materials")
local ores = {["default:gold_lump"] = true, ["grug_materials:anthracite"] = true, ["grug_materials:rough_jade"] = true,
	["grug_materials:cut_jade"] = true, ["default:iron_lump"] = true,
	["grug_materials:rough_citrine"] = true, ["grug_materials:emberglass_shard"] = true}
L.check(ores)
for _, level in ipairs({20, 21, 29}) do
	local plan = L.plan(tbl, level, function(lo) return lo end, {5, 15})
	local gear, coins, items = 0, 0, 0
	for _, entry in ipairs(plan) do
		if entry.quality then gear = gear + 1 end
		if entry.copper then coins = coins + 1 end
		if entry.item then items = items + 1 end
		check(not entry.item or not entry.item:find("ore"), "B no ore row")
	end
	check(gear >= 1 and coins >= 1 and items >= 1, "B every kind at level " .. level)
	check(#plan <= L.slots(plan), "B the plan fits")
end

-- C. The template, read as the game reads it.
local _, ffi = pcall(require, "ffi")
ffi.cdef[[int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *src, unsigned long srcLen);]]
local zlib = ffi.load("z")
local function inflate(bytes)
	local out, size = ffi.new("uint8_t[?]", 8388608), ffi.new("unsigned long[1]", 8388608)
	assert(zlib.uncompress(out, size, bytes, #bytes) == 0)
	return ffi.string(out, size[0])
end
local file = assert(io.open(repo .. "/mods/PLAYER/grug_expeditions/templates/stilled_seam.exp", "rb"))
local tpl = T.parse(file:read("*a"), inflate, "stilled_seam")
file:close()
T.check_fits(tpl, C.BOX, {"arrival", "start_waystone", "end_waystone"}, "stilled_seam")
local sx, sy, sz = tpl.size.x, tpl.size.y, tpl.size.z
check(sx <= 128 and sz <= 128 and sy <= C.BOX.y, "C inside the box")

-- Every palette node, by what it does to a walker and to light. A node missing here
-- stops the fixture: it has to be thought about. Round 73 SEAM: the miners' anthracite
-- lamps, candles, the lava falls, moss, bones and cobwebs (none walkable), and the
-- stairs of the relief (walkable, so solid here; the shared proof reads their shapes).
local OPEN = {air = 0, ["default:torch_wall"] = 12, ["grug_decor:xdecor_lantern_hanging"] = 13,
	["grug_decor:xdecor_rope"] = 0, ["grug_materials:anthracite_torch_wall"] = 14,
	["grug_decor:xdecor_candle"] = 12, ["default:lava_source"] = 13, ["default:lava_flowing"] = 13,
	["grug_nodes:moss_carpet"] = 0, ["grug_nodes:lichen_carpet"] = 0, ["grug_nodes:lichen_carpet_b"] = 0,
	["grug_nodes:bone_pile"] = 0, ["grug_nodes:bones_fragments"] = 0, ["grug_nodes:skull_human"] = 0,
	["grug_decor:xdecor_cobweb"] = 0, ["grug_trees:swamp_hanging_moss_strand"] = 0}
local LOW = {["grug_mapgen:mine_rail"] = true} -- under a step, light passes
local SOLID = {["default:stone"] = true, ["default:cobble"] = true, ["default:gravel"] = true,
	["default:mossycobble"] = true,
	["default:tree"] = true, ["default:wood"] = true, ["default:pine_wood"] = true,
	["grug_materials:stone_with_anthracite"] = true, ["grug_materials:stone_with_jade"] = true,
	["grug_decor:darkage_reinforced_wood"] = true, ["grug_decor:cottages_table"] = true,
	["grug_decor:cottages_bench"] = true, ["grug_decor:cottages_barrel"] = true,
	["grug_mapgen:mine_cart"] = true, ["grug_expeditions:waystone"] = true,
	["grug_expeditions:reward_chest"] = true, ["grug_expeditions:reward_door"] = true}
local kinds = {}
for index, name in ipairs(tpl.nodes) do
	local stair = name:match("^stairs:stair_") ~= nil
	check(OPEN[name] or LOW[name] or SOLID[name] or stair, "C palette: " .. name)
	if stair then SOLID[name] = true end
	kinds[index - 1] = OPEN[name] and "open" or LOW[name] and "low" or "solid"
end

local rows = sx * sy
local function at(x, y, z) return z * rows + y * sx + x + 1 end
local function inside(x, y, z)
	return x >= 0 and y >= 0 and z >= 0 and x < sx and y < sy and z < sz
end
local function name_at(x, y, z) return tpl.nodes[tpl.cells:byte(at(x, y, z)) + 1] end

local DOOR, GOLD = "grug_expeditions:reward_door", "grug_materials:stone_with_anthracite" -- the T2 ore
local JADE = "grug_materials:stone_with_jade"
-- `changed`: cells read as air, the door and the ore gone.
local function solid(x, y, z, changed)
	if changed and changed[name_at(x, y, z)] then return false end
	return kinds[tpl.cells:byte(at(x, y, z))] == "solid"
end

local F = 5 -- the walking cells' lowest y
local places = tpl.places
eq(places.arrival.y, F, "C the arrival stands on the floor")
for name, node in pairs({start_waystone = "grug_expeditions:waystone",
	end_waystone = "grug_expeditions:waystone", chest = "grug_expeditions:reward_chest", door = DOOR}) do
	local p = assert(places[name], name)
	eq(name_at(p.x, p.y, p.z), node, "C place " .. name)
end
local function within(p, x0, z0, x1, z1) return p.x >= x0 and p.x < x1 and p.z >= z0 and p.z < z1 end
local STORE = {8, 88, 32, 120}
local ARRIVAL = {8, 8, 32, 32}
check(within(places.start_waystone, unpack(ARRIVAL)), "C the start waystone in room 0")
check(within(places.end_waystone, unpack(STORE)) and within(places.chest, unpack(STORE)),
	"C chest and end waystone in the store")
-- Flintback's range (BOSSRESET): the court's envelope; Round 72 STYLE's smaller hall
-- moved its first corner from 48,5,88 to 54,5,94. Section K holds it to the hall's floor.
local bmin, bmax = assert(places.boss_room_min), assert(places.boss_room_max)
eq(("%d,%d,%d %d,%d,%d"):format(bmin.x, bmin.y, bmin.z, bmax.x, bmax.y, bmax.z), "54,5,94 79,5,119",
	"C Flintback's range")

-- The plan's grid, one cell for 8 nodes (round71-l20-description.md). Round 72 STYLE
-- made the rooms smaller: nine cells by the rooms' old walls hold no floor now
-- (52,12 60,12 68,12 76,12 100,12 52,92 76,92 52,100 52,116), and the room labels 1,
-- 2 and 4 moved to an open cell of their room. Round 73 SEAM: the bent passages, the
-- drift re-routed west of its old line, the ambush alcoves, bay d as one square room and
-- the store's bent way open sixteen more (36,12 84,12 36,28 44,28 84,28 100,44 92,52
-- 100,52 92,60 100,60 92,68 92,92 108,92 36,100 92,100 92,116) and close three: the old
-- drift's line (108,52 108,60) and the eye row of the prop room's rubble ramp (116,12).
local GRID = {
	"################", "#0...#####.##.##", "#.....1.....2..#", "#.S....a...#.b.#", "######...g##..j#",
	"############..##", "###########..###", "###########..###", "###########.3..#", "############.c.#",
	"############...#", "#5.g###..##...##", "#g.g.##...#....#", "#jC..D4.B....d.#", "#gEj###...#....#",
	"################",
}
for row_index, line in ipairs(GRID) do
	for col = 1, #line do
		local x, z = 4 + 8 * (col - 1), 4 + 8 * (row_index - 1)
		local rock = line:sub(col, col) == "#"
		-- the drawn point of a marked cell may hold what it marks: any walking cell
		-- of the 8 x 8 counts as open
		local open = 0
		for dz = -4, 3 do
			for dx = -4, 3 do
				if not solid(x + dx, F + 1, z + dz) then open = open + 1 end
			end
		end
		check(rock == (open == 0), ("C the grid at %d,%d: %s, %d open"):format(x, z, line:sub(col, col), open))
	end
end

-- Eight marked nodes, in the grid's cells, each at reach, hull behind it.
local WANT = {
	{GOLD, 79, 36}, {JADE, 119, 36},
	{GOLD, 8, 100}, {GOLD, 31, 92}, {GOLD, 31, 100}, {GOLD, 8, 116},
	{JADE, 8, 108}, {JADE, 31, 116},
}
check(tpl.dig[GOLD] and tpl.dig[JADE], "D both ores are marked")
local marked = 0
for name in pairs(tpl.dig) do marked = marked + 1; check(name == GOLD or name == JADE, "D only ore") end
eq(marked, 2, "D two marks")
local found = 0
for z = 0, sz - 1 do
	for y = 0, sy - 1 do
		for x = 0, sx - 1 do
			local name = name_at(x, y, z)
			if name == GOLD or name == JADE then found = found + 1 end
		end
	end
end
eq(found, #WANT, "D exactly eight cells")
for _, spot in ipairs(WANT) do
	local node, x, z = spot[1], spot[2], spot[3]
	local label = ("D %s at %d,%d"):format(node, x, z)
	eq(name_at(x, F + 1, z), node, label)
	local open, behind = 0, 0
	for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		local nx, nz = x + d[1], z + d[2]
		if solid(nx, F + 1, nz) then
			-- two nodes of hull, none of it marked
			if solid(nx + d[1], F + 1, nz + d[2]) and name_at(nx, F + 1, nz) == "default:stone" then
				behind = behind + 1
			end
		elseif not solid(nx, F, nz) then
			open = open + 1
		end
	end
	check(open >= 1 and behind >= 1, label .. ": at reach with hull behind")
end
local grid_cell = {[GOLD] = "g", [JADE] = "j"}
for _, spot in ipairs(WANT) do
	local line = GRID[math.floor(spot[3] / 8) + 1]
	local col = math.floor(spot[2] / 8) + 1
	eq(line:sub(col, col), grid_cell[spot[1]], "D the grid's cell for " .. spot[2] .. "," .. spot[3])
end

-- E. The route. A 3D flood through everything not solid: nothing reaches the store
-- with the door shut, whatever a player climbs, and the hull holds with the ore dug.
local function flood(changed)
	local seen, queue, head = {}, {}, 1
	local p = places.arrival
	queue[1] = {p.x, p.y, p.z}
	seen[at(p.x, p.y, p.z)] = true
	while queue[head] do
		local c = queue[head]
		head = head + 1
		for _, d in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}) do
			local x, y, z = c[1] + d[1], c[2] + d[2], c[3] + d[3]
			if inside(x, y, z) and not seen[at(x, y, z)] and not solid(x, y, z, changed) then
				seen[at(x, y, z)] = true
				queue[#queue + 1] = {x, y, z}
			end
		end
	end
	return seen, head - 1
end
local function reaches_store(seen)
	for z = STORE[2], STORE[4] - 1 do
		for x = STORE[1], STORE[3] - 1 do
			for y = F, 13 do
				if seen[at(x, y, z)] then return true end
			end
		end
	end
	return false
end
local shut, shut_count = flood()
check(not reaches_store(shut), "E the store is sealed with the door shut")
local dug, dug_count = flood({[GOLD] = true, [JADE] = true})
check(not reaches_store(dug), "E digging the ore opens no way in")
check(dug_count - shut_count <= 2, "E the two nodes on the way add only their own cells")
local all = {[GOLD] = true, [JADE] = true, [DOOR] = true}
local open_all = flood(all)
check(reaches_store(open_all), "E the door opens the way")
for z = 0, sz - 1 do
	for y = 0, sy - 1 do
		for x = 0, sx - 1 do
			if x == 0 or y == 0 or z == 0 or x == sx - 1 or y == sy - 1 or z == sz - 1 then
				check(not open_all[at(x, y, z)], "E the hull holds")
			end
		end
	end
end

-- A walk on the one floor. `wide` and `tall`: cells a walker needs round its middle.
-- Round 73 SEAM: the floor is a height map, relief by stairs only. A column's floor is
-- its lowest row with something solid under it and `tall` rows free over it; a walk
-- steps to a neighbour whose floor is within one node (the shared proof's relief rule
-- holds every such step to a stair), and a wide walker's columns all lie within one
-- node of its middle's.
local function floor_of(x, z, changed, tall)
	if not inside(x, 1, z) then return nil end
	for y = 1, sy - tall do
		if solid(x, y - 1, z, changed) then
			local free = true
			for k = 0, tall - 1 do free = free and not solid(x, y + k, z, changed) end
			if free then return y end
		end
	end
	return nil
end
local function walk(changed, wide, tall, from, to)
	local heights = {}
	local function h_at(x, z)
		local key = z * sx + x
		if heights[key] == nil then heights[key] = floor_of(x, z, changed, tall) or false end
		return heights[key]
	end
	local function free(x, z, h)
		for dz = -wide, wide do
			for dx = -wide, wide do
				local nh = h_at(x + dx, z + dz)
				if not nh or math.abs(nh - h) > 1 then return false end
			end
		end
		return true
	end
	local seen, queue, head = {[from[2] * sx + from[1]] = 0}, {from}, 1
	while queue[head] do
		local c = queue[head]
		head = head + 1
		local steps = seen[c[2] * sx + c[1]]
		if c[1] == to[1] and c[2] == to[2] then return steps end
		local h = h_at(c[1], c[2])
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local x, z = c[1] + d[1], c[2] + d[2]
			local nh = h and h_at(x, z)
			if seen[z * sx + x] == nil and nh and math.abs(nh - h) <= 1 and free(x, z, nh) then
				seen[z * sx + x] = steps + 1
				queue[#queue + 1] = {x, z}
			end
		end
	end
	return nil
end
local OPEN_DOOR = {[DOOR] = true}
local start = {places.arrival.x, places.arrival.z}
local goal = {places.chest.x + 2, places.chest.z}
local player_steps = walk(OPEN_DOOR, 0, 2, start, goal)
check(player_steps ~= nil, "E a player walks from the start to the chest")
-- A spider is three nodes wide, an elite golem three tall (its 1.7 x 1.4).
local mob_steps = walk(OPEN_DOOR, 1, 3, {places.arrival.x, places.arrival.z - 2}, goal)
check(mob_steps ~= nil, "E a mob walks from the start to the store")
check(walk(nil, 0, 2, start, goal) == nil, "E nobody walks there through the door")
print(("route: %d steps for a player, %d for a mob"):format(player_steps, mob_steps))
check(player_steps <= 320, "E the walk stays short: " .. player_steps)
-- The balance model walks the same steps (Round 72 PROOF: STYLE's smaller rooms, 258 -> 254;
-- Round 73 SEAM: the bent passages and the stair runs, 254 -> 260).
local function read_text(path)
	local handle = assert(io.open(repo .. "/" .. path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end
eq(tonumber(read_text("tools/r71_l20/balance.py"):match("WALK_STEPS = (%d+)")), player_steps, "E the balance model's walk")

-- The other place: the walk back to the working face from the start waystone.
local face
for _, row in ipairs(tpl.encounters) do
	if row.tier == "boss" then face = row end
end
check(walk(nil, 0, 2, start, {face.pos.x, face.pos.z}), "E the cleared walk reaches the face")

-- F. The roster and where it stands.
local SPREAD = {{0, 0}, {3, 0}, {-3, 0}, {0, 3}, {0, -3}, {3, 3}, {-3, 3}, {3, -3}, {-3, -3}} -- encounters.lua
-- The view ranges from the mob files; Flintback is a golem's body (golem_def).
local golem_text = read_text("mods/ENTITIES/grug_mobs/golem.lua")
check(golem_text:find('local flintback = golem_def(', 1, true), "F Flintback is a golem")
local VIEW = {["grug_mobs:giant_spider"] = tonumber(read_text("mods/ENTITIES/grug_mobs/spider.lua"):match("view_range = (%d+)")),
	["grug_mobs:stone_golem"] = tonumber(golem_text:match("view_range = (%d+)"))}
VIEW["grug_mobs:flintback"] = VIEW["grug_mobs:stone_golem"]
check(VIEW["grug_mobs:giant_spider"] == 12 and VIEW["grug_mobs:stone_golem"] == 16, "F view ranges read")
-- A mob's look starts at its object's place + 1: its feet less the collision box's floor
-- (spider.lua -0.75; golem.lua -1, times 1.4 for an elite and the boss: levels.lua).
local EYE = {["grug_mobs:giant_spider"] = 1.75, ["grug_mobs:stone_golem"] = 2.4, ["grug_mobs:flintback"] = 2.4}
local count = {normal = 0, elite = 0, boss = 0}
local by_family = {}
local packs, spots = {}, {}
-- Round 73 SEAM: an ambush's markers wait for its zone (section L) and critters are no
-- pack (concept section 4.8); both are counted apart. Ambush spiders stand with the
-- packs in G: no floor cell in sight of an ambush and a room pack.
local ambush_room, ambush_spots, critters = {}, {}, {}
for _, row in ipairs(tpl.ambushes) do ambush_room[row.room] = true end
for _, row in ipairs(tpl.encounters) do
	if row.tier == "critter" then
		critters[#critters + 1] = row
	else
		check(VIEW[row.mob], "F a known family: " .. row.mob)
		if not ambush_room[row.room] then
			count[row.tier] = count[row.tier] + row.count
			by_family[row.mob .. "/" .. row.tier] = (by_family[row.mob .. "/" .. row.tier] or 0) + row.count
			packs[row.room] = packs[row.room] or {}
		else
			ambush_spots[row.room] = ambush_spots[row.room] or {}
		end
		for index = 1, row.count do
			local offset = SPREAD[(index - 1) % #SPREAD + 1]
			local spot = {x = row.pos.x + offset[1], z = row.pos.z + offset[2], view = VIEW[row.mob],
				room = row.room, mob = row.mob, eye = EYE[row.mob]}
			-- Room for a mob from its column's floor, within a stair of its marker's.
			local h = floor_of(spot.x, spot.z, nil, 3)
			check(h and math.abs(h - row.pos.y) <= 1, ("F room for a mob at %d,%d"):format(spot.x, spot.z))
			table.insert(packs[row.room] or ambush_spots[row.room], spot)
			spots[#spots + 1] = spot
		end
	end
end
eq(count.normal, 12, "F twelve spiders")
eq(count.elite, 3, "F three elites")
eq(count.boss, 1, "F one boss")
eq(by_family["grug_mobs:giant_spider/normal"], 12, "F the spiders are spiders")
eq(by_family["grug_mobs:stone_golem/elite"], 3, "F the elites are golems")
eq(by_family["grug_mobs:flintback/boss"], 1, "F the boss is Flintback")
eq(#packs.pack_a, 4, "F pack a")
eq(#packs.pack_b, 3, "F pack b")
eq(#packs.pack_c, 4, "F pack c")
eq(#packs.pack_d, 4, "F pack d")
eq(#packs.boss, 1, "F the boss alone")
-- The fighting chambers (Round 72 STYLE, stilled_seam.py ROOMS): every mob stands in its
-- pack's, and section K proves them. Round 73 SEAM: the prop room's north-east corner
-- is the rubble ramp's top, out of pack b's sight, and left out (116 -> 114); bay c's
-- northern bay is rock (the drift comes in from the west, out of the pack's sight up
-- it); bay d is one square work room.
local CHAMBERS = {
	pack_a = {{55, 18, 66, 21}, {51, 21, 70, 24}, {49, 24, 73, 33}, {52, 33, 71, 36}, {56, 36, 66, 39}},
	pack_b = {{104, 14, 114, 18}, {99, 18, 120, 23}, {99, 23, 119, 33}, {103, 33, 119, 38}, {104, 38, 114, 39}},
	pack_c = {{99, 67, 117, 78}, {100, 78, 117, 83}, {102, 83, 114, 85}},
	pack_d = {{99, 101, 118, 119}},
	boss = {{63, 94, 72, 97}, {59, 97, 76, 100}, {57, 100, 79, 104}, {54, 104, 80, 112}, {56, 112, 79, 115},
		{60, 115, 76, 118}, {63, 118, 72, 120}},
}
local function in_rects(rects, x, z)
	for _, r in ipairs(rects) do
		if x >= r[1] and x < r[3] and z >= r[2] and z < r[4] then return true end
	end
	return false
end
for key, list in pairs(packs) do
	for _, spot in ipairs(list) do
		check(in_rects(CHAMBERS[key], spot.x, spot.z), "F " .. key .. " in its chamber")
	end
end
-- No mob, no ore on the way before pack a: rooms 0 and 5 hold no marker.
for _, spot in ipairs(spots) do
	check(not within(spot, unpack(ARRIVAL)) and not within(spot, unpack(STORE)), "F rooms 0 and 5 are empty")
end

-- The shared proof (tools/expedition_templates/proofs.lua, Round 73 TOOLS): the floor as
-- a height map from the written file (door open, ore dug), sight over its relief and the
-- light. A straight look from feet + 1 to feet + 1 (mobs_redo): walkable nodes stop it by
-- their boxes, lanterns and ropes do not.
local PR = dofile(repo .. "/tools/expedition_templates/proofs.lua")
local map = PR.map(tpl, PR.registry(repo), {open = all})
local function sees(x0, z0, x1, z1) return PR.sees(map, x0, z0, x1, z1) end

-- G. No pack links to the next: nobody in one pack sees anybody in another, and no
-- cell of the floor lies in the sight of two packs, so a player standing anywhere
-- wakes one pack at most.
local nearest = math.huge
for i, a in ipairs(spots) do
	for j = i + 1, #spots do
		local b = spots[j]
		if a.room ~= b.room then
			local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			nearest = math.min(nearest, d)
			if d <= math.max(a.view, b.view) then
				check(not sees(a.x, a.z, b.x, b.z), ("G %s and %s are linked"):format(a.room, b.room))
			end
		end
	end
end
print(("nearest mobs of two packs: %.1f nodes"):format(nearest))
local shared = 0
for z = 0, sz - 1 do
	for x = 0, sx - 1 do
		if not solid(x, F, z) and not solid(x, F + 1, z) then
			local first
			for _, spot in ipairs(spots) do
				local d2 = (spot.x - x) ^ 2 + (spot.z - z) ^ 2
				if d2 <= spot.view * spot.view and spot.room ~= first and sees(spot.x, spot.z, x, z) then
					if first then
						shared = shared + 1
						print(("two packs see %d,%d: %s, %s"):format(x, z, first, spot.room))
						break
					end
					first = spot.room
				end
			end
		end
	end
end
eq(shared, 0, "G no floor cell lies in two packs' sight")
for _, a in ipairs(packs.pack_c) do
	for _, b in ipairs(packs.pack_d) do
		check(not sees(a.x, a.z, b.x, b.z), "G the screen stands between c and d")
	end
end

-- H. The light: the shared proof's zones and line of sight (section K).

-- I. The quest: the document's shape and its four approved texts.
local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")
local function read_file(path)
	local handle = assert(io.open(repo .. "/" .. path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local home = json.decode(read_file("mods/PLAYER/grug_quests/data/zones/elandor_highcourt.quests.json"))
local quest
for _, q in ipairs(home.quests) do
	if q.id == "capital_stilled_seam" then quest = q end
end
check(quest ~= nil, "I the quest lives in its first variant's file")
eq(quest.title, "Party: The Stilled Seam", "I the title")
eq(quest.level, 20, "I level 20")
eq(quest.line, "guild", "I the guild leaders' line")
check(quest.optional == true and quest.group == true, "I optional, a group quest")
eq(quest.story, nil, "I no story flag")
eq(#quest.requires, 0, "I it requires nothing")
eq(quest.rewards.weight, 4, "I weight 4")
eq(quest.rewards.copper, nil, "I copper from the weight")
eq(quest.rewards.items, nil, "I no item")
eq(quest.rewards.choices, nil, "I no choice")
eq(#quest.objectives, 1, "I one objective")
eq(quest.objectives[1].type, "kill", "I a kill")
eq(quest.objectives[1].roles[1], "flintback", "I Flintback")
eq(quest.objectives[1].count, 1, "I once")
eq(quest.objectives[1].area, nil, "I at any level, in no area")
-- The approved block quotes, whole.
local doc = read_file("docs/planning/round71-l20-description.md")
local function approved(head)
	local at = assert(doc:find("**" .. head .. "**", 1, true), head)
	return doc:match("\n> ([^\n]+)\n", at)
end
local TEXTS = {accord = {approved("The Accord \226\128\148 offer"), approved("The Accord \226\128\148 completion")},
	throng = {approved("The Throng \226\128\148 offer"), approved("The Throng \226\128\148 completion")}}
local VARIANTS = {
	{"elandor_highcourt", "highcourt", "accord"}, {"elandor_dur_brannoc", "dur_brannoc", "accord"},
	{"elandor_lethariel", "lethariel", "accord"}, {"kragmar_gor_drazhak", "gor_drazhak", "throng"},
	{"kragmar_kezamba", "kezamba", "throng"}, {"kragmar_nhal_veyr", "nhal_veyr", "throng"},
}
eq(#quest.variants, #VARIANTS, "I six variants")
for index, want in ipairs(VARIANTS) do
	local v = quest.variants[index]
	eq(v.zone, want[1], "I variant " .. index)
	eq(#v.givers, 1, "I one giver in " .. want[2])
	eq(v.givers[1], "r58_guild_leader_" .. want[2], "I the leader of " .. want[2])
	eq(v.turnins, nil, "I turned in at the giver")
	eq(v.text, TEXTS[want[3]][1], "I the offer in " .. want[2])
	eq(v.completion, TEXTS[want[3]][2], "I the completion in " .. want[2])
end
-- The target's rule, in both validators, the same as the catalogue's level.
local lua_rule = read_file("mods/PLAYER/grug_quests/validate.lua"):match("V%.EXPEDITION_TARGETS = {flintback = (%d+)}")
local py_rule = read_file("tools/r28_design/validate.py"):match('EXPEDITION_TARGETS = {"flintback": (%d+)}')
eq(tonumber(lua_rule), row.level, "I the game's validator")
eq(tonumber(py_rule), row.level, "I the design validator")
-- The boss: a golem's body, its name fixed over 20-69.
local golem = read_file("mods/ENTITIES/grug_mobs/golem.lua")
check(golem:find('register_mob("grug_mobs:flintback", flintback)', 1, true), "I Flintback is registered")
local names_text = read_file("mods/ENTITIES/grug_mobs/data/names.json")
check(names_text:find('"world/flintback/L20-69": "Flintback"', 1, true), "I the name's slot")
-- Every mob of the Seam is named at every level, the boss by its one name (names_core).
local NC = dofile(repo .. "/mods/ENTITIES/grug_mobs/names_core.lua")
local index = NC.build(json.decode(names_text).names)
for level = row.level, row.max_level do
	eq(NC.lookup(index, "flintback", nil, level), "Flintback", "I Flintback at " .. level)
	check(NC.lookup(index, "giant_spider", nil, level), "I a spider's name at " .. level)
	check(NC.lookup(index, "stone_golem", nil, level), "I a golem's name at " .. level)
end
-- The quest's target is read at the Expedition's first level, whatever the run's.
eq(NC.lookup(index, "flintback", nil, nil), "Flintback", "I the kill objective's one name")

-- J. The range (Round 71 RANGE): five tiers over 20-69, each writing its ore and gem
-- in the template's places with the dig marks following, and the chest by band.
local registry = read_file("mods/ITEMS/grug_materials/registry.lua")
local harvest = {}
for node, tier in registry:gmatch('natural_node = "([^"]+)",.-harvest_tier = (%d+)') do
	harvest[node] = tonumber(tier)
end
eq(C.TIERS[1].min_level, row.level, "J the first tier at the Seam's first level")
eq(C.TIERS[#C.TIERS].max_level, row.max_level, "J the last at its last")
for i, tier in ipairs(C.TIERS) do
	eq(tier.tier, i + 1, "J T" .. tier.tier)
	eq(tier.max_level - tier.min_level, 9, "J ten levels in T" .. tier.tier)
	if i > 1 then eq(tier.min_level, C.TIERS[i - 1].max_level + 1, "J no gap before T" .. tier.tier) end
	eq(C.tier_of(tier.min_level), tier, "J tier_of " .. tier.min_level)
	eq(C.tier_of(tier.max_level), tier, "J tier_of " .. tier.max_level)
	-- The gem is the tier's own; the ore needs the tier's pick, T6's Abyssal Crystal T5's (user).
	eq(harvest[tier.gem], tier.tier, "J T" .. tier.tier .. "'s gem " .. tier.gem)
	eq(harvest[tier.ore], math.min(tier.tier, 5), "J T" .. tier.tier .. "'s ore " .. tier.ore)
end
eq(C.TEMPLATE_ORE, GOLD, "J the template's ore")
eq(C.TEMPLATE_GEM, JADE, "J the template's gem")
check(next(C.swaps()[2]) == nil, "J T2 writes the file as it is")

-- The variants as the game resolves them, content ids by name.
local ids_by_name, next_cid = {}, 0
_G.core = {registered_nodes = setmetatable({}, {__index = function() return {} end}),
	get_content_id = function(name)
		if not ids_by_name[name] then next_cid = next_cid + 1; ids_by_name[name] = next_cid end
		return ids_by_name[name]
	end}
T.resolve(tpl, C.swaps())
_G.core = nil
for _, tier in ipairs(C.TIERS) do
	local variant = tpl.variants[tier.tier]
	local label = "J T" .. tier.tier
	local marks = 0
	for name in pairs(variant.dig) do
		marks = marks + 1
		check(name == tier.ore or name == tier.gem, label .. " marks only its ore and gem: " .. name)
	end
	eq(marks, tier.ore == tier.gem and 1 or 2, label .. "'s marks")
	for _, spot in ipairs(WANT) do
		local want = spot[1] == GOLD and tier.ore or tier.gem
		eq(variant.ids[tpl.cells:byte(at(spot[2], F + 1, spot[3]))], ids_by_name[want],
			("%s writes %s at %d,%d"):format(label, want, spot[2], spot[3]))
	end
	-- Nothing else changes, and no T2 node is left at another tier.
	local changed = 0
	for index, name in ipairs(tpl.nodes) do
		local id = variant.ids[index - 1]
		if id ~= tpl.ids[index - 1] then
			changed = changed + 1
			check(name == GOLD or name == JADE, label .. " swaps only ore and gem")
		end
		if tier.tier > 2 then
			check(id ~= ids_by_name[GOLD] and id ~= ids_by_name[JADE], label .. " leaves no T2 node")
		end
	end
	eq(changed, tier.tier == 2 and 0 or 2, label .. "'s swaps")
end

-- The chest by band: the spiders' own materials, nothing of the 20s' signature later.
local items_json = json.decode(read_file("mods/ENTITIES/grug_mobs/data/items.json"))
local known = {}
for _, item in ipairs(items_json) do known[item.id] = true end
for name in read_file("mods/ENTITIES/grug_mobs/items.lua"):gmatch('material%("([%w_]+)"') do
	known["grug_mobs:" .. name] = true
end
local BAND_ONLY = {["grug_mobs:coarse_spider_silk"] = {21, 30},
	["grug_mobs:layered_spider_web"] = {31, 40}, ["grug_mobs:glass_spider_silk"] = {51, 69}}
for level = row.level, row.max_level do
	local got = {}
	for _, entry in ipairs(L.plan(tbl, level, function(lo) return lo end, {5, 15})) do
		if entry.item then
			check(known[entry.item], "J a registered material: " .. entry.item)
			got[entry.item] = true
		end
	end
	check(got["grug_mobs:spider_silk"] and got["grug_mobs:venom_gland"], "J silk and glands at " .. level)
	for item, band in pairs(BAND_ONLY) do
		eq(got[item] == true, level >= band[1] and level <= band[2], ("J %s at %d"):format(item, level))
	end
	eq(got["grug_mobs:venom_sac"] == true, level >= 31 and level <= 50, "J venom sacs at " .. level)
end

-- K. The user's room rules (Round 72, round72-plan.md section 2.9; Round 73, the concept
-- section 7) by the shared proof: compact fighting chambers and the bent passages
-- between them (stilled_seam.py ROOMS and passage_plan, each passage's box with its
-- niches and ambush alcoves).
local pfloor = map.list
local ROOM0 = {{12, 12, 27, 16}, {10, 16, 32, 24}, {12, 24, 29, 29}, {16, 29, 24, 31}}
local ROOM5 = {{12, 88, 28, 92}, {8, 92, 32, 120}}
local QUIET = {ROOM0[1], ROOM0[2], ROOM0[3], ROOM0[4], ROOM5[1], ROOM5[2],
	{32, 15, 50, 30}, {71, 31, 80, 39}, {68, 15, 102, 25}, {94, 38, 108, 74}, -- p1, siding, haulage, drift
	{95, 80, 105, 105}, {80, 102, 99, 114}, {32, 102, 54, 112}} -- the side way, to the face, past the door
for _, cell in ipairs(pfloor) do
	local known = in_rects(QUIET, cell.x, cell.z)
	for _, rects in pairs(CHAMBERS) do known = known or in_rects(rects, cell.x, cell.z) end
	check(known, ("K floor only in the chambers, rooms 0 and 5, cuts and passages: %d,%d"):format(cell.x, cell.z))
end
-- Flintback's range holds exactly the hall's floor.
local hall, ranged = 0, 0
for _, cell in ipairs(pfloor) do
	local inside_range = cell.x >= bmin.x and cell.x <= bmax.x and cell.z >= bmin.z and cell.z <= bmax.z
	if inside_range then ranged = ranged + 1 end
	if in_rects(CHAMBERS.boss, cell.x, cell.z) then
		hall = hall + 1
		check(inside_range, ("K the hall's floor in Flintback's range: %d,%d"):format(cell.x, cell.z))
	end
end
eq(ranged, hall, "K Flintback's range holds the hall and nothing else")
-- Every rule of the shared proof. No pack can be walked round (user, 2026-11-08): every
-- floor cell of a chamber noticed by a mob of its pack with a node to spare, and no walk
-- from the chamber's way in (a passage or cut cell no pack notices) to its way on, or to
-- the ore after it (a hand's reach), keeps out of every cell the pack notices. The
-- boss's way on is the door's front, shut until he dies.
-- Round 73 SEAM: every rule on (no report switch). The ways run through the new
-- passages; the mouths are the passage cells beside a room (no lava basin at one), and
-- an ambush alcove fits a spider (spider.lua collisionbox, 2.1 x 0.75).
local REPORT = {}
local WAYS = {pack_a = {{40, 20}, {80, 20}, {79, 36}}, pack_b = {{80, 20}, {100, 44}, {119, 36}},
	pack_c = {{100, 44}, {98, 90}}, pack_d = {{98, 90}, {88, 107}}, boss = {{88, 107}, {46, 108}}}
local function in_a_room(x, z)
	if in_rects(ROOM0, x, z) or in_rects(ROOM5, x, z) then return true end
	for _, rects in pairs(CHAMBERS) do if in_rects(rects, x, z) then return true end end
	return false
end
local mouths = {}
for _, cell in ipairs(pfloor) do
	if not in_a_room(cell.x, cell.z) then
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			if map.height(cell.x + d[1], cell.z + d[2]) and in_a_room(cell.x + d[1], cell.z + d[2]) then
				mouths[#mouths + 1] = {cell.x, cell.z}
				break
			end
		end
	end
end
check(#mouths >= 14, "K the passages' mouths: " .. #mouths)
local spec = {name = "stilled_seam", tallest = 1.7 * 1.4, ambushes = 2, packs = {}, report = REPORT,
	mouths = mouths, sizes = {["grug_mobs:giant_spider"] = {2.1, 0.75}}}
for _, key in ipairs({"pack_a", "pack_b", "pack_c", "pack_d", "boss"}) do
	spec.packs[key] = {spots = packs[key], ways = WAYS[key],
		room = function(x, z) return in_rects(CHAMBERS[key], x, z) end}
end
PR.enforce(PR.prove(map, spec), check, REPORT)

-- L. Round 73 SEAM: what the Seam adds beyond the shared proof (its ambush rule judges
-- the zones' darkness, the cut, the alcoves, the first fight and the respawn's sight).
-- Two ambush candidates in one group, one armed per run (concept section 4.5), each of
-- two normal spiders: about half a room pack by the balance model.
eq(#tpl.ambushes, 2, "L two ambush candidates")
local ambush_spiders = tonumber(read_text("tools/r71_l20/balance.py"):match("AMBUSH_SPIDERS = (%d+)"))
for _, row in ipairs(tpl.ambushes) do
	eq(row.group, "seam", "L one group")
	eq(row.pick, 1, "L one armed per run")
	local list = ambush_spots[row.room] or {}
	eq(#list, ambush_spiders, "L the balance model's spiders in " .. row.room)
	for _, spot in ipairs(list) do eq(spot.mob, "grug_mobs:giant_spider", "L " .. row.room .. "'s spiders") end
end
for _, row in ipairs(tpl.encounters) do
	if ambush_room[row.room] then eq(row.tier, "normal", "L an ambush marker's tier") end
end
-- Three to six critters of the roster, on the floor, never in a pack's chamber.
local ROSTER = {["grug_mobs:cave_bat"] = true, ["grug_mobs:cave_crawler"] = true, ["grug_mobs:bone_weevil"] = true}
check(#critters >= 3 and #critters <= 6, "L three to six critters: " .. #critters)
for _, row in ipairs(critters) do
	check(ROSTER[row.mob], "L a critter of the roster: " .. row.mob)
	eq(map.height(row.pos.x, row.pos.z), row.pos.y, "L a critter on the floor")
	for key, rects in pairs(CHAMBERS) do
		check(not in_rects(rects, row.pos.x, row.pos.z), "L a critter outside " .. key)
	end
end
-- One or two lava falls (the brief: fewer than The Last Mint), each a falling column.
local falls = {}
for z = 0, sz - 1 do
	for y = 0, sy - 1 do
		for x = 0, sx - 1 do
			if name_at(x, y, z) == "default:lava_flowing" and math.floor(map.param2(x, y, z) / 8) % 2 == 1 then
				falls[z * sx + x] = true
			end
		end
	end
end
local fall_count = 0
for _ in pairs(falls) do fall_count = fall_count + 1 end
eq(fall_count, 2, "L two lava falls")
-- The setting's particles: dripping water and dust.
for _, row in ipairs(tpl.particles) do
	check(row.style == "drip" or row.style == "dust", "L the Seam's particles: " .. row.style)
end

print(("R71 L20 PORTABLE PASS checks=%d"):format(checks))
