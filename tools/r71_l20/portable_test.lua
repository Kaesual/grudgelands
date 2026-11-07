-- Round 71 lane L20 portable test (LuaJIT): The Stilled Seam's catalogue row, its
-- loot table and the written template, proved over the cells, not by eye: the route
-- for a player and for a mob, the door, the ore, the packs and the light. The engine
-- half is tools/r71_l20/run.sh, the numbers tools/r71_l20/balance.py.
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
eq(row.max_players, 3, "A at most three")
eq(row.template, "stilled_seam", "A its template")
local listed = C.list()
eq(#listed, 1, "A one row a dialog may offer")
eq(listed[1].id, "stilled_seam", "A The Stilled Seam is it")
check(not listed[1].hidden, "A not hidden")

-- B. The loot table: at the run's level, no ore, no gem, what the brief asks.
local tbl = L.TABLES.stilled_seam
check(tbl and tbl.gear and tbl.coin_bags and tbl.materials, "B equipment, coins and materials")
local ores = {["default:gold_lump"] = true, ["grug_materials:rough_jade"] = true,
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
-- stops the fixture: it has to be thought about.
local OPEN = {air = 0, ["default:torch_wall"] = 12, ["grug_decor:xdecor_lantern_hanging"] = 13,
	["grug_decor:xdecor_rope"] = 0}
local LOW = {["grug_mapgen:mine_rail"] = true} -- under a step, light passes
local SOLID = {["default:stone"] = true, ["default:cobble"] = true, ["default:gravel"] = true,
	["default:tree"] = true, ["default:wood"] = true, ["default:pine_wood"] = true,
	["default:stone_with_gold"] = true, ["grug_materials:stone_with_jade"] = true,
	["grug_decor:darkage_reinforced_wood"] = true, ["grug_decor:cottages_table"] = true,
	["grug_decor:cottages_bench"] = true, ["grug_decor:cottages_barrel"] = true,
	["grug_mapgen:mine_cart"] = true, ["grug_expeditions:waystone"] = true,
	["grug_expeditions:reward_chest"] = true, ["grug_expeditions:reward_door"] = true}
local kinds = {}
for index, name in ipairs(tpl.nodes) do
	check(OPEN[name] or LOW[name] or SOLID[name], "C palette: " .. name)
	kinds[index - 1] = OPEN[name] and "open" or LOW[name] and "low" or "solid"
end

local rows = sx * sy
local function at(x, y, z) return z * rows + y * sx + x + 1 end
local function inside(x, y, z)
	return x >= 0 and y >= 0 and z >= 0 and x < sx and y < sy and z < sz
end
local function name_at(x, y, z) return tpl.nodes[tpl.cells:byte(at(x, y, z)) + 1] end

local DOOR, GOLD = "grug_expeditions:reward_door", "default:stone_with_gold"
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

-- The plan's grid, one cell for 8 nodes (round71-l20-description.md).
local GRID = {
	"################", "#0..##1...##2..#", "#..............#", "#.S.##.a..##.b.#",
	"######...g##..j#", "#############.##", "#############.##", "#############.##",
	"############3..#", "############.c.#", "############...#", "#5.g##4...##.###",
	"#g.g##....##...#", "#jC..D..B....d.#", "#gEj##....##...#", "################",
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
local function walk(changed, wide, tall, from, to)
	local function free(x, z)
		for dz = -wide, wide do
			for dx = -wide, wide do
				if not inside(x + dx, F, z + dz) or not solid(x + dx, F - 1, z + dz, changed) then
					return false
				end
				for y = F, F + tall - 1 do
					if solid(x + dx, y, z + dz, changed) then return false end
				end
			end
		end
		return true
	end
	local seen, queue, head = {[at(from[1], F, from[2])] = 0}, {from}, 1
	while queue[head] do
		local c = queue[head]
		head = head + 1
		local steps = seen[at(c[1], F, c[2])]
		if c[1] == to[1] and c[2] == to[2] then return steps end
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local x, z = c[1] + d[1], c[2] + d[2]
			if seen[at(x, F, z)] == nil and free(x, z) then
				seen[at(x, F, z)] = steps + 1
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

-- The other place: the walk back to the working face from the start waystone.
local face
for _, row in ipairs(tpl.encounters) do
	if row.tier == "boss" then face = row end
end
check(walk(nil, 0, 2, start, {face.pos.x, face.pos.z}), "E the cleared walk reaches the face")

-- F. The roster and where it stands.
local SPREAD = {{0, 0}, {3, 0}, {-3, 0}, {0, 3}, {0, -3}, {3, 3}, {-3, 3}, {3, -3}, {-3, -3}} -- encounters.lua
local VIEW = {["grug_mobs:giant_spider"] = 12, ["grug_mobs:stone_golem"] = 16, ["grug_mobs:flintback"] = 16}
local count = {normal = 0, elite = 0, boss = 0}
local by_family = {}
local packs, spots = {}, {}
for _, row in ipairs(tpl.encounters) do
	check(VIEW[row.mob], "F a known family: " .. row.mob)
	count[row.tier] = count[row.tier] + row.count
	by_family[row.mob .. "/" .. row.tier] = (by_family[row.mob .. "/" .. row.tier] or 0) + row.count
	packs[row.room] = packs[row.room] or {}
	for index = 1, row.count do
		local offset = SPREAD[(index - 1) % #SPREAD + 1]
		local spot = {x = row.pos.x + offset[1], z = row.pos.z + offset[2], view = VIEW[row.mob],
			room = row.room, mob = row.mob}
		for y = F, F + 2 do
			check(not solid(spot.x, y, spot.z), ("F room for a mob at %d,%d"):format(spot.x, spot.z))
		end
		table.insert(packs[row.room], spot)
		spots[#spots + 1] = spot
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
local PACK_ROOM = {pack_a = {48, 8, 80, 40}, pack_b = {96, 8, 120, 40}, pack_c = {96, 64, 120, 88},
	pack_d = {96, 96, 120, 120}, boss = {48, 88, 80, 120}}
for key, list in pairs(packs) do
	for _, spot in ipairs(list) do
		check(within(spot, unpack(PACK_ROOM[key])), "F " .. key .. " in its room")
	end
end
-- No mob, no ore on the way before pack a: rooms 0 and 5 hold no marker.
for _, spot in ipairs(spots) do
	check(not within(spot, unpack(ARRIVAL)) and not within(spot, unpack(STORE)), "F rooms 0 and 5 are empty")
end

-- A straight look from eye to eye: walls stop it, lanterns and ropes do not.
local function sees(x0, z0, x1, z1)
	local dx, dz = x1 - x0, z1 - z0
	local steps = math.ceil(math.sqrt(dx * dx + dz * dz) * 4)
	for i = 1, steps - 1 do
		local x = math.floor(x0 + dx * i / steps + 0.5)
		local z = math.floor(z0 + dz * i / steps + 0.5)
		if solid(x, F + 1, z) then return false end
	end
	return true
end

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

-- H. The light, by the engine's rule: minus one per node from each source, stopped
-- by what is solid. A torch-lit mine at eye height: most of it bright enough to read
-- a telegraph, and no black corner.
local LIGHT_MIN, LIGHT_USUAL, USUAL_SHARE = 4, 6, 0.9
local light = {}
local buckets = {}
local function raise(index, x, y, z, value)
	if value > (light[index] or 0) then
		light[index] = value
		buckets[value] = buckets[value] or {}
		table.insert(buckets[value], {x, y, z})
	end
end
for z = 0, sz - 1 do
	for y = 0, sy - 1 do
		for x = 0, sx - 1 do
			local level = OPEN[name_at(x, y, z)]
			if level and level > 0 then raise(at(x, y, z), x, y, z, level) end
		end
	end
end
for value = 14, 2, -1 do
	local list = buckets[value] or {}
	for _, c in ipairs(list) do
		for _, d in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}) do
			local x, y, z = c[1] + d[1], c[2] + d[2], c[3] + d[3]
			if inside(x, y, z) and not solid(x, y, z) then raise(at(x, y, z), x, y, z, value - 1) end
		end
	end
end
local darkest, total, cells, usual = 99, 0, 0, 0
local dark_at
for z = 0, sz - 1 do
	for x = 0, sx - 1 do
		if open_all[at(x, F + 1, z)] and not solid(x, F + 1, z) then
			local value = light[at(x, F + 1, z)] or 0
			cells, total = cells + 1, total + value
			if value >= LIGHT_USUAL then usual = usual + 1 end
			if value < darkest then darkest, dark_at = value, x .. "," .. z end
		end
	end
end
print(("light at eye height: %d cells, mean %.1f, %.0f %% at %d or more, darkest %d at %s"):format(cells,
	total / cells, 100 * usual / cells, LIGHT_USUAL, darkest, dark_at))
check(darkest >= LIGHT_MIN, "H no dark corner: " .. darkest .. " at " .. dark_at)
check(usual / cells >= USUAL_SHARE, "H the rooms read: " .. usual / cells)

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
-- The boss: a golem's body, its name fixed over 20-29.
local golem = read_file("mods/ENTITIES/grug_mobs/golem.lua")
check(golem:find('register_mob("grug_mobs:flintback", flintback)', 1, true), "I Flintback is registered")
check(read_file("mods/ENTITIES/grug_mobs/data/names.json"):find('"world/flintback/L20-29": "Flintback"', 1, true),
	"I the name's slot")

print(("R71 L20 PORTABLE PASS checks=%d"):format(checks))
