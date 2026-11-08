-- Round 72 lane SHIFT portable test (LuaJIT): The Second Shift, levels 40-69, four
-- players (docs/planning/round72-second-shift.md, round72-plan.md §2.9). The catalogue
-- row and the entry rules at 40 and 69, the chest by band, and the written template
-- proved cell by cell as tools/r71_l20 proves The Stilled Seam's: the plan's places,
-- flat floors and head room, the ore, the route for a player and a mob, the packs and
-- the boss room, "no pack can be walked round" and the sight between packs, the light;
-- the traps and Auditor Nemm's marked spot on a fake engine whose map is this template;
-- Nemm's definition and clock; the quest and the names. The engine half is
-- tools/r72_shift/run.sh, the numbers tools/r72_shift/balance.py.
-- Prints "R72 SHIFT PORTABLE PASS checks=<n>".
--
--   luajit tools/r72_shift/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function eq(a, b, label)
	check(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local function read_file(path)
	local handle = assert(io.open(repo .. "/" .. path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local C = dofile(repo .. "/mods/PLAYER/grug_expeditions/catalogue.lua")
local L = dofile(repo .. "/mods/PLAYER/grug_expeditions/loot.lua")
local T = dofile(repo .. "/mods/PLAYER/grug_expeditions/template.lua")
local ID = "second_shift"

-- A. The catalogue row and the entry rules at its first and last level.
local row = C.definition(ID)
check(row ~= nil, "A the row")
eq(row.name, "The Second Shift", "A its name")
eq(row.level, 40, "A from 40")
eq(row.max_level, 69, "A up to 69")
eq(row.max_players, 4, "A four players")
eq(row.template, ID, "A its template")
check(not row.hidden, "A a dialog offers it")
local offered = false
for _, listed in ipairs(C.list()) do offered = offered or listed.id == ID end
check(offered, "A listed")
eq(row.signs and row.signs.shift_board, "SECOND SHIFT\nSAME NAMES\nSTILL DUE", "A the shift board's text")
eq(C.tier_of(40).tier, 4, "A T4 at 40")
eq(C.tier_of(49).tier, 4, "A T4 at 49")
eq(C.tier_of(50).tier, 5, "A T5 at 50")
eq(C.tier_of(60).tier, 6, "A T6 at 60")
eq(C.tier_of(69).ore, "grug_materials:abyssal_crystal_ore", "A T6's ore is Abyssal Crystal")
eq(C.tier_of(69).gem, "grug_materials:stone_with_diamond", "A T6's gem is Diamond")

-- runs.lua's entry rules on stubs: who is offered which level, who may enter a run.
do
	local levels, combat, parties = {}, {}, {}
	grug_expeditions = {}
	grug_xp = {get_level = function(p) return levels[type(p) == "string" and p or p:get_player_name()] end}
	grug_parties = setmetatable({view = function(name) return parties[name] end},
		{__index = function() return function() end end})
	grug_core = setmetatable({in_combat = function(p) return combat[p:get_player_name()] end,
		feed = function() end}, {__index = function() return function() end end})
	grug_home = setmetatable({}, {__index = function() return function() end end})
	core = setmetatable({}, {__index = function() return function() end end})
	assert(loadfile(repo .. "/mods/PLAYER/grug_expeditions/runs.lua"))(C, {init = function() end})
	local E = grug_expeditions
	local function player(name, level)
		levels[name] = level
		return {get_player_name = function() return name end, get_hp = function() return 20 end}
	end
	local function offered_at(level)
		local rows = E.offered_levels(player("p" .. level, level), ID)
		local first, last = rows[1], rows[#rows]
		return #rows, first and first.level, last and last.level
	end
	eq(select(1, offered_at(37)), 0, "A level 37 is offered nothing")
	local n, first, last = offered_at(38)
	check(n == 1 and first == 40 and last == 40, "A level 38 is offered 40 alone")
	n, first, last = offered_at(58)
	check(n == 21 and first == 40 and last == 60, "A level 58 up to 60")
	n, first, last = offered_at(60)
	check(n == 30 and first == 40 and last == 69, "A level 60: all thirty")
	for _, case in ipairs({{40, 37, 38}, {69, 59, 60}}) do
		local level, below, enough = case[1], case[2], case[3]
		local owner = "lead" .. level
		parties[owner] = {id = "p" .. level, leader = owner}
		local run = {state = "running", level = level, max_players = 4, owner = {kind = "party", id = "p" .. level},
			entered = {}}
		local members = {}
		for i = 1, 5 do
			local name = i == 1 and owner or ("m" .. level .. "_" .. i)
			parties[name] = parties[owner]
			members[i] = player(name, enough)
		end
		local weak = player("weak" .. level, below)
		parties["weak" .. level] = parties[owner]
		local ok, why = E.can_enter(weak, run)
		check(not ok and why == "This Expedition needs level " .. enough .. ".", "A level " .. below ..
			" refused at " .. level)
		for i = 1, 4 do
			check(E.can_enter(members[i], run), "A member " .. i .. " enters at " .. level)
			run.entered[members[i]:get_player_name()] = true
		end
		ok, why = E.can_enter(members[5], run)
		check(not ok and why == "This Expedition is full.", "A the fifth is refused at " .. level)
		check(E.can_enter(members[2], run), "A an entered member comes back at " .. level)
		combat[members[2]:get_player_name()] = true
		ok, why = E.can_enter(members[2], run)
		check(not ok and why == "Cannot travel in combat.", "A not in combat at " .. level)
		ok = E.can_enter(player("stranger" .. level, 60), run)
		check(not ok, "A a stranger is refused at " .. level)
	end
	grug_expeditions, grug_xp, grug_parties, grug_core, grug_home, core = nil, nil, nil, nil, nil, nil
end

-- B. The chest: Uncommon, a chance of Rare, coins, the band's bone and flesh; no ore.
local tbl = L.TABLES[ID]
check(tbl and tbl.gear and tbl.coin_bags and tbl.materials, "B equipment, coins and materials")
L.check({["grug_materials:emberglass_shard"] = true, ["grug_materials:rough_sapphire"] = true})
local BAND = {
	{40, 49, "grug_mobs:marching_bone", "grug_mobs:leathery_flesh"},
	{50, 59, "grug_mobs:siege_bone", "grug_mobs:scorched_flesh"},
	{60, 69, "grug_mobs:unquiet_bone", "grug_mobs:salt_cured_flesh"},
}
local items_json = read_file("mods/ENTITIES/grug_mobs/data/items.json")
for level = 40, 69 do
	local plan = L.plan(tbl, level, function(lo) return lo end, {5, 15})
	local got, gear, coins = {}, 0, 0
	for _, entry in ipairs(plan) do
		if entry.item then
			got[entry.item] = entry.count
			check(items_json:find('"id": "' .. entry.item .. '"', 1, true), "B a registered material " .. entry.item)
			check(not entry.item:find("ore") and not entry.item:find("crystal"), "B no ore")
		end
		if entry.quality then gear = gear + 1 end
		if entry.copper then coins = coins + 1 end
	end
	check(gear >= 1 and coins == 1, "B gear and coins at " .. level)
	for _, band in ipairs(BAND) do
		local inside = level >= band[1] and level <= band[2]
		eq(got[band[3]] ~= nil, inside, ("B %s at %d"):format(band[3], level))
		eq(got[band[4]] ~= nil, inside, ("B %s at %d"):format(band[4], level))
		if inside then check(got[band[3]] == 3 and got[band[4]] == 1, "B 3-5 bone and 1-2 flesh") end
	end
end
local highest = L.plan(tbl, 69, function(_, hi) return hi end, {5, 15})
local plan_items = {}
for _, entry in ipairs(highest) do if entry.item then plan_items[entry.item] = entry.count end end
check(plan_items["grug_mobs:unquiet_bone"] == 5 and plan_items["grug_mobs:salt_cured_flesh"] == 2, "B the most")
eq(#highest, 4, "B Uncommon, Rare, coins and two materials at most")

-- C. The template, read as the game reads it.
local _, ffi = pcall(require, "ffi")
ffi.cdef[[int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *src, unsigned long srcLen);]]
local zlib = ffi.load("z")
local function inflate(bytes)
	local out, size = ffi.new("uint8_t[?]", 8388608), ffi.new("unsigned long[1]", 8388608)
	assert(zlib.uncompress(out, size, bytes, #bytes) == 0)
	return ffi.string(out, size[0])
end
local file = assert(io.open(repo .. "/mods/PLAYER/grug_expeditions/templates/" .. ID .. ".exp", "rb"))
local tpl = T.parse(file:read("*a"), inflate, ID)
file:close()
T.check_fits(tpl, C.BOX, {"arrival", "start_waystone", "end_waystone"}, ID)
local sx, sy, sz = tpl.size.x, tpl.size.y, tpl.size.z
check(sx == 128 and sz == 128 and sy <= C.BOX.y, "C the slot's footprint")

-- Every palette node by what it does to a walker, to sight at eye height and to light.
-- A node missing here stops the fixture: it has to be thought about.
local OPEN = {air = 0, ["default:torch_wall"] = 12, ["grug_decor:xdecor_lantern_hanging"] = 13,
	["grug_decor:xdecor_rope"] = 0, ["default:sign_wall_wood"] = 0}
-- Walkable, but below a mob's eye (the sight ray runs half a node above the floor
-- cell's top): light passes.
local LOW = {["grug_mapgen:mine_rail"] = true, ["grug_mapgen:mine_cart"] = true,
	["grug_decor:cottages_bench"] = true, ["grug_decor:cottages_table"] = true}
local SOLID = {["default:stone"] = true, ["default:cobble"] = true, ["default:gravel"] = true,
	["default:tree"] = true, ["default:wood"] = true, ["default:pine_wood"] = true,
	["grug_materials:stone_with_anthracite"] = true, ["grug_materials:stone_with_jade"] = true,
	["grug_decor:darkage_reinforced_wood"] = true, ["grug_decor:cottages_barrel"] = true,
	["grug_expeditions:waystone"] = true, ["grug_expeditions:reward_chest"] = true,
	["grug_expeditions:reward_door"] = true}
local kinds = {}
for index, name in ipairs(tpl.nodes) do
	check(OPEN[name] or LOW[name] or SOLID[name], "C palette: " .. name)
	kinds[index - 1] = OPEN[name] and "open" or LOW[name] and "low" or "solid"
end
local rows = sx * sy
local function at(x, y, z) return z * rows + y * sx + x + 1 end
local function inside(x, y, z) return x >= 0 and y >= 0 and z >= 0 and x < sx and y < sy and z < sz end
local function name_at(x, y, z) return tpl.nodes[tpl.cells:byte(at(x, y, z)) + 1] end
local function kind_at(x, y, z) return kinds[tpl.cells:byte(at(x, y, z))] end
-- `changed`: node names read as air (the door open, the ore dug).
local function solid(x, y, z, changed)
	if changed and changed[name_at(x, y, z)] then return false end
	return kind_at(x, y, z) ~= "open"
end

local F = 8 -- the first air cell: every floor's walking cells
local DOOR, ORE, GEM = "grug_expeditions:reward_door", C.TEMPLATE_ORE, C.TEMPLATE_GEM
local places = tpl.places
eq(places.arrival.y, F, "C the arrival stands on the floor")
for name, node in pairs({start_waystone = "grug_expeditions:waystone", end_waystone = "grug_expeditions:waystone",
		chest = "grug_expeditions:reward_chest", door = DOOR, shift_board = "default:sign_wall_wood"}) do
	local p = assert(places[name], name)
	eq(name_at(p.x, p.y, p.z), node, "C place " .. name)
end
-- The plan's coordinates (round72-second-shift.md "Floor plan and build coordinates").
local function same(p, x, y, z) return p.x == x and p.y == y and p.z == z end
check(same(places.start_waystone, 107, F, 28) and same(places.arrival, 107, F, 24), "C start and arrival")
check(same(places.chest, 107, F, 104) and same(places.end_waystone, 107, F, 112), "C chest and end")
check(same(places.door, 83, 10, 108), "C the door's marker")
for z = 104, 111 do
	for y = F, 13 do eq(name_at(83, y, z), DOOR, ("C the door at 83,%d,%d"):format(y, z)) end
end
check(same(places.boss_room_min, 48, F, 88) and same(places.boss_room_max, 79, F, 119), "C Nemm's range")

-- The plan's envelopes and passages, [x0, z0, x1, z1): every open cell at walking
-- height lies in one of them, and each passage is open six nodes high.
local ENVELOPES = {arrival = {96, 8, 120, 32}, desk = {48, 8, 80, 40}, marking = {8, 8, 32, 40},
	wage = {8, 64, 32, 120}, court = {48, 88, 80, 120}, store = {96, 88, 120, 120}}
local PASSAGES = {{80, 16, 96, 24}, {32, 16, 48, 24}, {16, 40, 24, 64}, {32, 104, 48, 112}, {80, 104, 96, 112}}
local SCREEN = {8, 88, 24, 96}
local function within(x, z, r) return x >= r[1] and x < r[3] and z >= r[2] and z < r[4] end
local function room_of(x, z)
	for name, r in pairs(ENVELOPES) do
		if within(x, z, r) then return name end
	end
end
local function in_passage(x, z)
	for _, r in ipairs(PASSAGES) do
		if within(x, z, r) then return true end
	end
	return false
end
for z = 0, sz - 1 do
	for x = 0, sx - 1 do
		if not solid(x, F + 1, z) or not solid(x, F, z, {[DOOR] = true}) then
			check(room_of(x, z) or in_passage(x, z), ("C open only in the plan's rooms and passages: %d,%d"):format(x, z))
		end
	end
end
for _, r in ipairs(PASSAGES) do
	for z = r[2], r[4] - 1 do
		for x = r[1], r[3] - 1 do
			for y = F, F + 5 do
				local open = not solid(x, y, z, {[DOOR] = true}) or kind_at(x, y, z) == "low"
				check(open or x == r[1] or x == r[3] - 1 or z == r[2] or z == r[4] - 1,
					("C passage open six high at %d,%d,%d"):format(x, y, z))
			end
		end
	end
end
for z = SCREEN[2], SCREEN[4] - 1 do
	for x = SCREEN[1], SCREEN[3] - 1 do
		for y = F, 18 do check(solid(x, y, z), "C the screen stands full height") end
	end
end

-- Flat floors and head room (§2.9): no open cell below the walking height anywhere,
-- so no pit and no lower step, and over every floor cell at least three nodes free
-- (an elite's look reaches 2.8): a mob stands everywhere a player does.
local floor_cells = {} -- [at(x, F, z)] = true for every cell a player stands in
local floor_count = 0
for z = 0, sz - 1 do
	for x = 0, sx - 1 do
		for y = 0, F - 1 do check(solid(x, y, z), ("C no pit at %d,%d,%d"):format(x, y, z)) end
		if not solid(x, F, z) and not solid(x, F + 1, z) then
			floor_cells[at(x, F, z)] = true
			floor_count = floor_count + 1
			check(not solid(x, F + 2, z), ("C head room at %d,%d"):format(x, z))
		end
	end
end
print(("floor: %d cells"):format(floor_count))

-- D. Eight marked nodes at the plan's places, each at reach with hull behind, and
-- the T2 nodes nowhere else (a run of another tier swaps them by name).
local WANT = {{ORE, 48, 36}, {GEM, 8, 36},
	{ORE, 119, 96}, {ORE, 96, 92}, {ORE, 96, 100}, {ORE, 119, 116}, {GEM, 119, 108}, {GEM, 96, 116}}
check(tpl.dig[ORE] and tpl.dig[GEM], "D both are marked")
local marked = 0
for name in pairs(tpl.dig) do
	marked = marked + 1
	check(name == ORE or name == GEM, "D only ore and gem")
end
eq(marked, 2, "D two marks")
local found = 0
for z = 0, sz - 1 do
	for y = 0, sy - 1 do
		for x = 0, sx - 1 do
			local name = name_at(x, y, z)
			if name == ORE or name == GEM then found = found + 1 end
		end
	end
end
eq(found, #WANT, "D exactly eight cells")
for _, spot in ipairs(WANT) do
	local node, x, z = spot[1], spot[2], spot[3]
	local label = ("D %s at %d,%d"):format(node, x, z)
	eq(name_at(x, F + 1, z), node, label)
	eq(name_at(x, F, z), "default:stone", label .. ": its plinth")
	local open, behind = 0, 0
	for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		local nx, nz = x + d[1], z + d[2]
		if floor_cells[at(nx, F, nz)] then
			open = open + 1
		elseif solid(nx, F + 1, nz) and name_at(nx, F + 1, nz) == "default:stone" then
			behind = behind + 1
		end
	end
	check(open >= 1 and behind >= 1, label .. ": at reach from the floor, the hull behind")
end

-- E. The route. A 3D flood through everything not solid: nothing reaches the store
-- with the door shut, digging the ore opens no way, and the hull holds.
local STORE = ENVELOPES.store
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
			for y = F, 22 do
				if seen[at(x, y, z)] then return true end
			end
		end
	end
	return false
end
local shut, shut_count = flood()
check(not reaches_store(shut), "E the store is sealed with the door shut")
local dug, dug_count = flood({[ORE] = true, [GEM] = true})
check(not reaches_store(dug), "E digging the ore opens no way in")
check(dug_count - shut_count <= 2, "E the two places on the way add only their own cells")
local open_all = flood({[ORE] = true, [GEM] = true, [DOOR] = true})
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
-- Every floor cell is reachable: no closed pocket.
for index in pairs(floor_cells) do check(open_all[index], "E no pocket the route misses") end

-- A walk on the one floor. `wide` and `tall`: cells a walker needs round its middle.
local function walk(changed, wide, tall, from, to)
	local function free(x, z)
		for dz = -wide, wide do
			for dx = -wide, wide do
				if not inside(x + dx, F, z + dz) or not solid(x + dx, F - 1, z + dz, changed) then return false end
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
local goal = {places.chest.x - 2, places.chest.z}
local player_steps = walk(OPEN_DOOR, 0, 2, start, goal)
check(player_steps ~= nil, "E a player walks from the start to the chest")
-- An elite miner is about 0.84 wide and 2.65 tall to look at: three cells round its
-- middle, three high.
local mob_steps = walk(OPEN_DOOR, 1, 3, start, goal)
check(mob_steps ~= nil, "E a mob walks from the start to the store")
check(walk(nil, 0, 2, start, goal) == nil, "E nobody walks there through the shut door")
print(("route: %d steps for a player, %d for a mob"):format(player_steps, mob_steps))
local balance = read_file("tools/r72_shift/balance.py")
eq(tonumber(balance:match("WALK_STEPS = (%d+)")), player_steps, "E the balance model's walk")

-- F. The roster and where it stands: the balance model's counts.
local SPREAD = {{0, 0}, {3, 0}, {-3, 0}, {0, 3}, {0, -3}, {3, 3}, {-3, 3}, {3, -3}, {-3, -3}} -- encounters.lua
local RAIDER, MINER, BOSS = "grug_mobs:skeleton_raider", "grug_mobs:zombie", "grug_mobs:auditor_nemm"
local raider_text = read_file("mods/ENTITIES/grug_mobs/skeleton_raider.lua")
local VIEW = {[RAIDER] = tonumber(raider_text:match("view_range = (%d+), %-%- it shoots")),
	[MINER] = tonumber(read_file("mods/ENTITIES/grug_mobs/zombie.lua"):match("view_range = (%d+)")),
	[BOSS] = tonumber(raider_text:match("nemm%.view_range = (%d+)"))}
check(VIEW[RAIDER] == 16 and VIEW[MINER] == 14 and VIEW[BOSS] == 20, "F view ranges read")
local count = {normal = 0, elite = 0, boss = 0}
local by_family = {}
local packs, spots = {}, {}
local PACK_ROOM = {pack_a = "desk", pack_b = "marking", pack_c = "wage", pack_d = "wage", boss = "court"}
for _, enc in ipairs(tpl.encounters) do
	check(VIEW[enc.mob], "F a known family: " .. enc.mob)
	count[enc.tier] = count[enc.tier] + enc.count
	local fam = enc.mob .. "/" .. enc.tier
	by_family[fam] = (by_family[fam] or 0) + enc.count
	packs[enc.room] = packs[enc.room] or {}
	for index = 1, enc.count do
		local offset = SPREAD[(index - 1) % #SPREAD + 1]
		local x, z = enc.pos.x + offset[1], enc.pos.z + offset[2]
		if not floor_cells[at(x, F, z)] then x, z = enc.pos.x, enc.pos.z end
		eq(enc.pos.y, F, "F on the floor")
		for y = F, F + 2 do
			check(not solid(x, y, z), ("F room for a mob at %d,%d"):format(x, z))
		end
		local spot = {x = x, z = z, view = VIEW[enc.mob], room = enc.room, mob = enc.mob, tier = enc.tier}
		table.insert(packs[enc.room], spot)
		spots[#spots + 1] = spot
		eq(room_of(x, z), PACK_ROOM[enc.room], "F " .. enc.room .. " in its room")
	end
end
eq(count.normal, 14, "F fourteen normals")
eq(count.elite, 3, "F three elites")
eq(count.boss, 1, "F one boss")
eq(by_family[RAIDER .. "/normal"], 12, "F twelve raiders")
eq(by_family[MINER .. "/normal"], 2, "F two miners")
eq(by_family[MINER .. "/elite"], 3, "F three elite miners")
eq(by_family[BOSS .. "/boss"], 1, "F the boss is Nemm")
eq(#packs.pack_a, 5, "F pack a: three raiders, two miners")
for _, key in ipairs({"pack_b", "pack_c", "pack_d"}) do eq(#packs[key], 4, "F " .. key .. ": three raiders, an elite") end
eq(#packs.boss, 1, "F Nemm alone")
local nemm = packs.boss[1]
check(nemm.x == 63 and nemm.z == 104, "F Nemm at the plan's place")
-- The pack places: each pack's middle within four nodes of the plan's anchor.
local ANCHOR = {pack_a = {67, 28}, pack_b = {19, 28}, pack_c = {19, 72}, pack_d = {19, 108}}
for key, anchor in pairs(ANCHOR) do
	local mx, mz = 0, 0
	for _, spot in ipairs(packs[key]) do mx, mz = mx + spot.x / #packs[key], mz + spot.z / #packs[key] end
	local off = math.sqrt((mx - anchor[1]) ^ 2 + (mz - anchor[2]) ^ 2)
	check(off <= 6.5, ("F %s's middle %.1f from the plan's anchor"):format(key, off))
end

-- G. Sight, by mobs_redo's general_attack: a player within the view range of a mob,
-- the ray from the mob's eye to the player's (both half a node above the floor
-- cell's top) free of walkable nodes. At that height a walkable node of the floor
-- row blocks only if it is a full one, so both rows are tested; a low node (a bench,
-- the rail) does not block. Sampled every eighth of a node.
local function sees(x0, z0, x1, z1)
	local dx, dz = x1 - x0, z1 - z0
	local steps = math.ceil(math.sqrt(dx * dx + dz * dz) * 8)
	for i = 1, steps - 1 do
		local x = math.floor(x0 + dx * i / steps + 0.5)
		local z = math.floor(z0 + dz * i / steps + 0.5)
		if solid(x, F + 1, z) or kind_at(x, F, z) == "solid" then return false end
	end
	return true
end
local function notices(spot, x, z, margin)
	local d2 = (spot.x - x) ^ 2 + (spot.z - z) ^ 2
	local reach = spot.view - margin
	return d2 <= reach * reach and sees(spot.x, spot.z, x, z)
end

-- No pack can be walked round (§2.9): from every floor cell of a pack room, at least
-- one mob of that room's packs notices a player, with a node to spare (a mob's place
-- and a player's within their cells). The court counts: Nemm sees all of it.
local ROOM_PACKS = {desk = {pack_a = true}, marking = {pack_b = true}, wage = {pack_c = true, pack_d = true},
	court = {boss = true}}
local covered_cells = {}
for room, owners in pairs(ROOM_PACKS) do
	local cells, missed = 0, 0
	for z = 0, sz - 1 do
		for x = 0, sx - 1 do
			if floor_cells[at(x, F, z)] and room_of(x, z) == room then
				cells = cells + 1
				local seen_by
				for _, spot in ipairs(spots) do
					if owners[spot.room] and notices(spot, x, z, 1) then
						seen_by = spot
						break
					end
				end
				if not seen_by then
					missed = missed + 1
					print(("unseen in %s: %d,%d"):format(room, x, z))
				end
			end
		end
	end
	covered_cells[room] = cells
	eq(missed, 0, "G nobody walks round the pack in " .. room)
end
print(("no walking round: desk %d, marking %d, wage %d, court %d floor cells, all noticed"):format(
	covered_cells.desk, covered_cells.marking, covered_cells.wage, covered_cells.court))

-- No pack links to the next: nobody in one pack sees anybody in another.
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
-- Two packs notice the same cell only in the wage room's bypass, east of the screen,
-- where the plan has the others leave the way clear: packs c and d. Cleared bay by bay,
-- c dies before anyone needs the bypass.
local BYPASS = {24, 86, 32, 96}
local shared = 0
for z = 0, sz - 1 do
	for x = 0, sx - 1 do
		if floor_cells[at(x, F, z)] then
			local who = {}
			local n = 0
			for _, spot in ipairs(spots) do
				if not who[spot.room] and notices(spot, x, z, 0) then
					who[spot.room] = true
					n = n + 1
				end
			end
			if n > 1 then
				shared = shared + 1
				check(who.pack_c and who.pack_d and n == 2 and within(x, z, BYPASS),
					("G two packs notice %d,%d outside the bypass"):format(x, z))
			end
		end
	end
end
print(("cells two packs notice: %d, all in the bypass"):format(shared))
-- The screen: a c and a d mob that see each other through the bypass stand more than
-- four nodes beyond the view range apart, so even a few steps of idling links nothing.
for _, a in ipairs(packs.pack_c) do
	for _, b in ipairs(packs.pack_d) do
		local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
		check(d > math.max(a.view, b.view) + 4 or not sees(a.x, a.z, b.x, b.z), "G the screen between c and d")
	end
end

-- H. The light, by the engine's rule: minus one per node from each source, stopped
-- by what is solid. Most of it bright enough to read a ring, and no black corner.
local LIGHT_MIN, LIGHT_USUAL, USUAL_SHARE = 4, 6, 0.9
local light, buckets = {}, {}
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
	for _, c in ipairs(buckets[value] or {}) do
		for _, d in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}) do
			local x, y, z = c[1] + d[1], c[2] + d[2], c[3] + d[3]
			if inside(x, y, z) and kind_at(x, y, z) ~= "solid" then raise(at(x, y, z), x, y, z, value - 1) end
		end
	end
end
local darkest, total, cells, usual, dark_at = 99, 0, 0, 0, nil
for z = 0, sz - 1 do
	for x = 0, sx - 1 do
		if floor_cells[at(x, F, z)] then
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
-- Nothing as bright as 14: a Buried Miner burns from 14 (zombie.lua light_damage_min).
for index, value in pairs(light) do check(value < 14, "H no burning light " .. index) end

-- I. The traps: the plan's candidates and groups, then traps.lua on this template.
local WANT_FLOOR = {f1 = {2, {{27, 20}, {11, 20}, {27, 32}, {11, 32}}}, f5 = {1, {{27, 76}, {11, 80}}},
	f7 = {1, {{27, 104}, {11, 112}}}, f9 = {2, {{71, 96}, {55, 96}, {71, 112}, {55, 112}}}}
local got_floor, walls = {}, {}
for _, trap in ipairs(tpl.traps) do
	if trap.kind == "floor" then
		got_floor[trap.group] = got_floor[trap.group] or {trap.pick, {}}
		table.insert(got_floor[trap.group][2], {trap.pos.x, trap.pos.z})
		eq(trap.pos.y, F, "I a floor trap on the floor")
		check(floor_cells[at(trap.pos.x, F, trap.pos.z)], "I a floor trap on a floor cell")
	else
		walls[#walls + 1] = trap
	end
end
for group, want in pairs(WANT_FLOOR) do
	local got = assert(got_floor[group], group)
	eq(got[1], want[1], "I " .. group .. "'s pick")
	eq(#got[2], #want[2], "I " .. group .. "'s candidates")
	for i, cell in ipairs(want[2]) do
		check(got[2][i][1] == cell[1] and got[2][i][2] == cell[2], "I " .. group .. " candidate " .. i)
	end
end
eq(#walls, 2, "I two wall candidates")
for i, x in ipairs({43, 35}) do
	local w = walls[i]
	check(w.group == "w1" and w.pick == 1 and w.pos.x == x and w.pos.y == 8.5 and w.pos.z == 15.6 and
		w.axis == "+z" and w.period == 8 and w.offset == 0, "I wall " .. i .. " as planned")
end

-- traps.lua on a fake engine whose map is this template.
local clock = 0
local timers, hooks, overrides, objects, entity_defs = {}, {ready = {}, enter = {}, ended = {}}, {}, {}, {}
local MINP = {x = 8064, y = -112, z = -1616}
local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
local function node_name(pos)
	local over = overrides[key(pos)]
	if over then return over end
	local x, y, z = pos.x - MINP.x, pos.y - MINP.y, pos.z - MINP.z
	if not inside(x, y, z) then return "default:stone" end
	return name_at(x, y, z)
end
vector = {}
function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
function vector.add(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end
function vector.multiply(a, s) return {x = a.x * s, y = a.y * s, z = a.z * s} end
function vector.distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local registered = {}
for name, kind in pairs(kinds) do registered[tpl.nodes[name + 1]] = {walkable = kind ~= "open"} end
local players = {}
local sent = {}
core = {
	registered_nodes = registered,
	get_modpath = function() return repo .. "/mods/PLAYER/grug_expeditions" end,
	get_current_modname = function() return "grug_expeditions" end,
	after = function(seconds, fn, ...) timers[#timers + 1] = {at = clock + seconds, fn = fn, args = {...}} end,
	register_node = function(name, def) registered[name] = def end,
	register_entity = function(name, def) entity_defs[name] = def end,
	get_node_or_nil = function(pos) return {name = node_name(pos)} end,
	get_node = function(pos) return {name = node_name(pos)} end,
	set_node = function(pos, node) overrides[key(pos)] = node.name end,
	get_player_by_name = function(name) return players[name] end,
	add_entity = function(pos, name)
		local def = assert(entity_defs[name], "no entity " .. name)
		local object = {pos = vector.copy(pos), velocity = {x = 0, y = 0, z = 0}}
		local ent = setmetatable({object = object}, {__index = def})
		function object.get_luaentity() return not object.removed and ent or nil end
		function object.set_velocity(_, v) object.velocity = vector.copy(v) end
		function object.get_pos() return not object.removed and vector.copy(object.pos) or nil end
		function object.remove() object.removed = true end
		objects[#objects + 1] = object
		return object
	end,
}
local attacked = {}
grug_mobs = {boss_attacked = function(ent) attacked[#attacked + 1] = ent end}
grug_core = {ARMOR_APPLIED_CUSTOM_TYPE = "armor", particles = {register = function() end,
	play = function(id, frame) sent[#sent + 1] = {id = id, at = clock, pos = frame.target} end},
	mono_time = function() return clock end,
	base_pool = function(level)
		level = math.max(1, math.min(60, math.floor(level)))
		return math.floor(20 + 5 * level + 0.66 * level * level + 0.5)
	end,
	apply_player_armor = function(_, damage) return damage end}
grug_expeditions = {templates = {[ID] = tpl}}
function grug_expeditions.definition() return {template = ID} end
function grug_expeditions.register_on_ready(fn) hooks.ready[#hooks.ready + 1] = fn end
function grug_expeditions.register_on_enter(fn) hooks.enter[#hooks.enter + 1] = fn end
function grug_expeditions.register_on_end(fn) hooks.ended[#hooks.ended + 1] = fn end
local runs = {}
function grug_expeditions.run_at() return runs[1] end
dofile(repo .. "/mods/PLAYER/grug_expeditions/traps.lua")
local TR = grug_expeditions.traps

local function step(dt)
	clock = clock + dt
	while true do
		local first
		for index, timer in ipairs(timers) do
			if timer.at <= clock + 1e-9 and (not first or timer.at < timers[first].at) then first = index end
		end
		if not first then break end
		local timer = table.remove(timers, first)
		timer.fn(unpack(timer.args))
	end
	for _, object in ipairs(objects) do
		if not object.removed then
			object.pos = vector.add(object.pos, vector.multiply(object.velocity, dt))
			object:get_luaentity():on_step(dt)
		end
	end
end
local function run_for(seconds)
	local stop = clock + seconds
	while clock < stop - 1e-9 do step(0.1) end
end
local function new_player(name, x, z)
	local p = {name = name, hp = 100000, hits = {}}
	p.pos = {x = MINP.x + x, y = MINP.y + F - 0.5, z = MINP.z + z}
	function p.get_player_name() return name end
	function p.get_pos() return vector.copy(p.pos) end
	function p.get_hp() return p.hp end
	function p.set_hp(_, hp, reason)
		p.hits[#p.hits + 1] = {amount = p.hp - hp, reason = reason, at = clock}
		p.hp = hp
	end
	players[name] = p
	return p
end
local function move(p, x, z) p.pos = {x = MINP.x + x, y = MINP.y + F - 0.5, z = MINP.z + z} end
local next_id = 0
local function new_run(level)
	next_id = next_id + 1
	local run = {id = next_id, expedition = ID, level = level, minp = MINP, inside = {}, state = "ready"}
	for _, fn in ipairs(hooks.ready) do fn(run) end
	runs[1] = run
	return run
end
local function enter(run, p)
	run.inside[p.name] = true
	run.state = "running"
	for _, fn in ipairs(hooks.enter) do fn(run, p.name) end
end
local function end_run(run)
	run.state = "ended"
	for name in pairs(run.inside) do run.inside[name] = nil end
	for _, fn in ipairs(hooks.ended) do fn(run, "empty") end
	runs[1] = nil
end

-- Per creation: the plan's picks of each group, every candidate chosen in some run.
math.randomseed(72)
local seen_cells = {}
for _ = 1, 200 do
	local run = new_run(40)
	local chosen = TR.chosen(run)
	local groups = {}
	for _, r in ipairs(chosen.floor) do
		groups[r.group] = (groups[r.group] or 0) + 1
		seen_cells[r.group .. key(r.cell)] = true
	end
	for _, r in ipairs(chosen.wall) do
		groups[r.group] = (groups[r.group] or 0) + 1
		seen_cells[r.group .. key(r.muzzle)] = true
	end
	check(groups.f1 == 2 and groups.f5 == 1 and groups.f7 == 1 and groups.f9 == 2 and groups.w1 == 1,
		"I the picks per creation")
	end_run(run)
end
local variety = 0
for _ in pairs(seen_cells) do variety = variety + 1 end
eq(variety, 14, "I every candidate armed in some creation")

-- Each armed floor trap fires at a player who steps on it, at the run's level, and a
-- mob standing on it is nobody: traps.lua looks at the run's players only.
for _, level in ipairs({40, 69}) do
	local run = new_run(level)
	local walker = new_player("walker" .. level, 107, 24)
	enter(run, walker)
	local damage = math.floor(0.45 * grug_core.base_pool(level) + 0.5)
	eq(TR.damage(level), damage, "I the hit at " .. level)
	for _, trap in ipairs(TR.chosen(run).floor) do
		local tx, tz = trap.cell.x - MINP.x, trap.cell.z - MINP.z
		move(walker, tx - 1.5, tz)
		run_for(0.3)
		local before = #walker.hits
		move(walker, tx, tz)
		run_for(0.3)
		move(walker, tx + 4, tz) -- stepping out of the ring in time
		run_for(2)
		eq(#walker.hits, before, "I out of the ring in time at " .. tx .. "," .. tz)
		run_for(10)
		move(walker, tx, tz)
		run_for(0.3)
		run_for(1.5)
		eq(#walker.hits, before + 1, "I the hit on who stays at " .. tx .. "," .. tz)
		eq(walker.hits[#walker.hits].amount, damage, "I the hit's amount")
		move(walker, 107, 24)
		run_for(12)
	end
	end_run(run)
end

-- The wall: one shot every 8 s from readiness, across the passage, stopped by the
-- far wall: 7.5 nodes of flight from z 15.6.
do
	local run = new_run(40)
	local watcher = new_player("watcher", 40, 28) -- in room 1's doorway? no: in the rock line; moved below
	move(watcher, 50, 20)
	enter(run, watcher)
	local fired, stopped = 0, nil
	local before = #objects
	run_for(0.3)
	for i = before + 1, #objects do
		fired = fired + 1
		local object = objects[i]
		for _ = 1, 30 do
			step(0.1)
			if object.removed then break end
			stopped = object.pos.z - MINP.z
		end
		check(object.removed, "I the ball stops")
	end
	eq(fired, 1, "I one shot on readiness")
	check(stopped and stopped >= 22.6 and stopped <= 23.2, "I stopped by the far wall: " .. tostring(stopped))
	end_run(run)
end

-- Nemm's marked spot (grug_mobs.expedition_mark): the ring now, the hit 1.5 s later at
-- the spot, an attack of the boss when it had a player in its area; taken back by
-- unmark (a reset) or when the boss is gone or dead.
do
	local run = new_run(40)
	local tank = new_player("tank", 63, 100)
	local healer = new_player("healer", 63, 110)
	enter(run, tank)
	enter(run, healer)
	local boss = {_grug_expedition = run.id, health = 1000, temp = {}}
	boss.object = {get_luaentity = function() return boss.removed == nil and boss or nil end}
	local damage = TR.damage(40)
	local spot = tank:get_pos()
	local mark = grug_mobs.expedition_mark(boss, spot)
	check(mark ~= nil, "I a mark in the boss's run")
	eq(sent[#sent].id, "expedition_trap_warning", "I the ring at once")
	check(grug_mobs.expedition_mark({_grug_expedition = run.id + 99, temp = {}}, spot) == nil,
		"I no mark for another run's boss")
	run_for(1.6)
	eq(#tank.hits, 1, "I the hit at the spot")
	eq(tank.hits[1].amount, damage, "I the floor trap's damage")
	eq(#healer.hits, 0, "I the healer ten nodes away is spared")
	eq(#attacked, 1, "I a mark that had a player is an attack")
	-- One position: the tank steps aside, the hit stays where it was marked.
	grug_mobs.expedition_mark(boss, tank:get_pos())
	move(tank, 66, 100)
	run_for(1.6)
	eq(#tank.hits, 1, "I the hit stays at the old spot")
	eq(#attacked, 1, "I a mark on empty floor is no attack")
	-- A reset takes it back.
	mark = grug_mobs.expedition_mark(boss, tank:get_pos())
	run_for(0.5)
	grug_mobs.expedition_unmark(mark)
	run_for(1.5)
	eq(#tank.hits, 1, "I a reset takes the hit back")
	-- Evading home or dead at the hit: none.
	grug_mobs.expedition_mark(boss, tank:get_pos())
	boss.temp.grug_evading = true
	run_for(1.6)
	eq(#tank.hits, 1, "I an evading boss hits nothing")
	boss.temp.grug_evading = nil
	grug_mobs.expedition_mark(boss, tank:get_pos())
	boss.health = 0
	run_for(1.6)
	eq(#tank.hits, 1, "I a dead boss hits nothing")
	boss.health = 1000
	grug_mobs.expedition_mark(boss, tank:get_pos())
	end_run(run)
	run_for(1.6)
	eq(#tank.hits, 1, "I the run's end takes it back")
end
core, grug_core, grug_expeditions, vector = nil, nil, nil, nil

-- K. Nemm's definition and clock, from skeleton_raider.lua on stubs.
do
	local defs = {}
	grug_mobs = {register_mob = function(name, def) defs[name] = def end, stamp_arrow_damage = function() end}
	mobs = {spawn = function() end}
	local marks, unmarks = {}, {}
	core = {is_player = function(o) return o and o.is_a_player end}
	dofile(repo .. "/mods/ENTITIES/grug_mobs/skeleton_raider.lua")
	local def = assert(defs[BOSS], "Nemm is registered")
	local base = defs[RAIDER]
	eq(def.mesh, base.mesh, "K the raider's body")
	eq(def.arrow, base.arrow, "K the raider's bow")
	eq(def.attack_type, base.attack_type, "K the raider's attacks")
	eq(def.view_range, 20, "K sees the whole court")
	eq(next(def.drops), nil, "K drops nothing")
	eq(def.walk_chance, 0, "K stands in its court")
	eq(def.clock, "any", "K no clock")
	eq(def._grug_spawn_domains, nil, "K no spawn row")
	check(base.do_custom == nil and base._grug_hp_scale == nil, "K the raider keeps its own")
	eq(def._grug_hp_scale, tonumber(balance:match("HP_SCALE") and raider_text:match("nemm%._grug_hp_scale = (%d+)")),
		"K the balance model reads the HP factor")
	grug_mobs.expedition_mark = function(self, pos)
		marks[#marks + 1] = {at = self._clock, pos = pos}
		return {n = #marks}
	end
	grug_mobs.expedition_unmark = function(handle) unmarks[#unmarks + 1] = handle end
	local target = {is_a_player = true, get_hp = function() return 10 end,
		get_pos = function() return {x = 1, y = 2, z = 3} end}
	local self = {temp = {}, state = "attack", attack = target, health = 100, _clock = 0}
	for i = 1, 300 do -- 30 s of a fight in 0.1 s steps
		self._clock = i / 10
		def.do_custom(self, 0.1)
	end
	eq(#marks, 2, "K a mark every 12 s of a fight")
	check(math.abs(marks[1].at - 12) < 0.25 and math.abs(marks[2].at - 24) < 0.25,
		("K at 12 and 24 s: %.2f, %.2f"):format(marks[1].at, marks[2].at))
	eq(marks[1].pos.x, 1, "K at the target's position")
	self.temp.grug_evading = true -- the reset: home, evading
	def.do_custom(self, 0.1)
	eq(#unmarks, 1, "K a reset takes the pending hit back")
	eq(self.temp.grug_nemm_clock, nil, "K and the clock starts over")
	self.temp.grug_evading = nil
	for _ = 1, 119 do def.do_custom(self, 0.1) end
	eq(#marks, 2, "K a fresh fight waits its 12 s")
	for _ = 1, 2 do def.do_custom(self, 0.1) end
	eq(#marks, 3, "K then marks")
	self.health = 0
	def.do_custom(self, 0.1)
	eq(#unmarks, 2, "K a death takes it back")
	self.health, self.state = 100, "stand"
	for _ = 1, 200 do def.do_custom(self, 0.1) end
	eq(#marks, 3, "K no fight, no mark")
	grug_mobs, mobs, core = nil, nil, nil
end

-- J. The quest: its shape and the four picked texts; the names.
local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")
local home = json.decode(read_file("mods/PLAYER/grug_quests/data/zones/elandor_highcourt.quests.json"))
local quest
for _, q in ipairs(home.quests) do
	if q.id == "capital_second_shift" then quest = q end
end
check(quest ~= nil, "J the quest lives in its first variant's file")
eq(quest.title, "Party: The Second Shift", "J the title")
eq(quest.level, 40, "J level 40, open from 38")
eq(quest.line, "guild", "J the guild leaders' line")
check(quest.optional == true and quest.group == true, "J optional, a group quest")
eq(quest.story, nil, "J no story flag")
eq(#quest.requires, 0, "J it requires nothing")
eq(quest.rewards.weight, 4, "J weight 4")
check(quest.rewards.items == nil and quest.rewards.choices == nil and quest.rewards.reputation == nil,
	"J no item, no reputation")
eq(#quest.objectives, 1, "J one objective")
check(quest.objectives[1].type == "kill" and quest.objectives[1].roles[1] == "auditor_nemm" and
	quest.objectives[1].count == 1 and quest.objectives[1].area == nil, "J kill Auditor Nemm once, at any level")
local doc = read_file("docs/planning/round72-second-shift.md")
local function picked(head)
	local where = assert(doc:find("**" .. head .. "**", 1, true), head)
	return doc:match("\n> ([^\n]+)\n", where)
end
local TEXTS = {accord = {picked("The Accord \226\128\148 offer"), picked("The Accord \226\128\148 completion")},
	throng = {picked("The Throng \226\128\148 offer"), picked("The Throng \226\128\148 completion")}}
local VARIANTS = {
	{"elandor_highcourt", "highcourt", "accord"}, {"elandor_dur_brannoc", "dur_brannoc", "accord"},
	{"elandor_lethariel", "lethariel", "accord"}, {"kragmar_gor_drazhak", "gor_drazhak", "throng"},
	{"kragmar_kezamba", "kezamba", "throng"}, {"kragmar_nhal_veyr", "nhal_veyr", "throng"},
}
-- The plan names the six givers; they are the guild houses' leaders (grug_quests npcs.lua).
local npcs = read_file("mods/PLAYER/grug_quests/npcs.lua")
local GIVERS = {highcourt = "Alis Cartwright", dur_brannoc = "Hadrin Beamset", lethariel = "Caelir Veinward",
	gor_drazhak = "Drava Flintshoulder", kezamba = "Ombali Ropekeeper", nhal_veyr = "Iven Lastshift"}
eq(#quest.variants, #VARIANTS, "J six variants")
for index, want in ipairs(VARIANTS) do
	local v = quest.variants[index]
	eq(v.zone, want[1], "J variant " .. index)
	eq(#v.givers, 1, "J one giver in " .. want[2])
	eq(v.givers[1], "r58_guild_leader_" .. want[2], "J the guild leader of " .. want[2])
	check(npcs:find(('{capital = "%s", title = "%s"}'):format(want[2], GIVERS[want[2]]), 1, true),
		"J " .. GIVERS[want[2]] .. " leads " .. want[2] .. "'s guild house")
	eq(v.turnins, nil, "J turned in at the giver")
	eq(v.text, TEXTS[want[3]][1], "J the offer in " .. want[2])
	eq(v.completion, TEXTS[want[3]][2], "J the completion in " .. want[2])
end
local lua_rule = read_file("mods/PLAYER/grug_quests/validate.lua"):match("V%.EXPEDITION_TARGETS%.auditor_nemm = (%d+)")
local py_rule = read_file("tools/r28_design/validate.py"):match('EXPEDITION_TARGETS%["auditor_nemm"%] = (%d+)')
eq(tonumber(lua_rule), row.level, "J the game's validator")
eq(tonumber(py_rule), row.level, "J the design validator")
local NC = dofile(repo .. "/mods/ENTITIES/grug_mobs/names_core.lua")
local index = NC.build(json.decode(read_file("mods/ENTITIES/grug_mobs/data/names.json")).names)
local RAIDER_NAMES = {{40, 49, "Shift Raider"}, {50, 59, "Tallied Raider"}, {60, 69, "Overdue Raider"}}
for level = row.level, row.max_level do
	eq(NC.lookup(index, "auditor_nemm", nil, level), "Auditor Nemm", "J Nemm at " .. level)
	eq(NC.lookup(index, "zombie", nil, level), "Buried Miner", "J a miner at " .. level)
	for _, band in ipairs(RAIDER_NAMES) do
		if level >= band[1] and level <= band[2] then
			eq(NC.lookup(index, "skeleton_raider", nil, level), band[3], "J a raider at " .. level)
		end
	end
end
eq(NC.lookup(index, "auditor_nemm", nil, nil), "Auditor Nemm", "J the kill objective's one name")
-- The Undead King's raiders keep their zone's name.
eq(NC.lookup(index, "skeleton_raider", "kragmar_nhal_veyr", 25), "Skeleton Raider", "J Nhal Veyr's raiders")

-- L. The user's room rules (Round 72 PROOF, round72-plan.md section 2.9), by the shared
-- proofs The Stilled Seam's and The Last Mint's fixtures run too
-- (tools/expedition_templates/proofs.lua): the free height, no perch, and no walk round
-- a pack (section G proves every floor cell of a pack room noticed).
do
	local PR = dofile(repo .. "/tools/expedition_templates/proofs.lua")
	local map = PR.map(tpl, F)
	local pfloor, pset = PR.floor(map)
	-- Three nodes of air over every floor cell, a player's floor counting the rails (the
	-- desk's rail siding lost STYLE's hood for this, Round 72 PROOF question 1).
	local KNOWN_LOW = ""
	local lowest, low_at, short = PR.free_height(map, pfloor, 3)
	eq(table.concat(short, " "), KNOWN_LOW, "L three nodes of air over every floor cell")
	print(("free height: %d floor cells, the lowest %d at %s, below three %d"):format(#pfloor,
		lowest, low_at, #short))
	-- No perch: walking, jumping and falling reach no place off the floor but a waystone
	-- or the chest, and no rope; with the door shut, and with it open and the ore dug.
	for _, changed in ipairs({false, {[DOOR] = true, [ORE] = true, [GEM] = true}}) do
		local found, ropes, searched = PR.perches(map, {places.arrival.x, F, places.arrival.z}, changed or nil)
		for _, line in ipairs(found) do print("perch: " .. line) end
		for _, line in ipairs(ropes) do print("rope in reach: " .. line) end
		check(#found == 0 and #ropes == 0, "L no perch and no rope in reach")
		print(("perches: none in %d places a player reaches%s"):format(searched,
			changed and ", door open, ore dug" or ""))
	end
	-- No walk from a pack room's way in to its way on, or to the ore after it (a hand's
	-- reach, 4 nodes), keeps out of every cell the pack notices with a node to spare. The
	-- ways are passage cells no pack notices; both wage packs between the wage room's.
	-- Nemm is left out: the reward door holds until he dies.
	local WAYS = {pack_a = {{88, 20}, {40, 20}, {48, 36}}, pack_b = {{40, 20}, {20, 52}, {8, 36}},
		pack_c = {{20, 52}, {40, 108}}, pack_d = {{20, 52}, {40, 108}}}
	for _, key in ipairs({"pack_a", "pack_b", "pack_c", "pack_d"}) do
		local way = WAYS[key]
		check(pset[way[2][2] * sx + way[2][1]] and not PR.noticed(packs[key], way[2][1], way[2][2], 1, sees),
			"L " .. key .. "'s way on is floor nobody notices")
		local targets = {way[2]}
		if way[3] then
			for _, t in ipairs(PR.within_reach(pset, sx, way[3][1], way[3][2], 4)) do targets[#targets + 1] = t end
		end
		local reached, kept, noticed = PR.walk_round(map, pset, way[1], targets, packs[key], 1, sees)
		check(reached == nil, ("L %s walked round to %s"):format(key, reached and reached[1] .. "," .. reached[2] or "-"))
		print(("%s: no way round its %d noticed cells to %d of %d targets"):format(key, noticed, kept, #targets))
	end
end

print(("R72 SHIFT PORTABLE PASS checks=%d"):format(checks))
