-- Round 72 lane MINT portable test (LuaJIT): The Last Mint (levels 60-69, four players,
-- the lava lake; docs/planning/round72-last-mint.md with the round's rulings,
-- round72-plan.md section 2.9). Proved over the written template's cells, not by eye,
-- as tools/r71_l20 does for The Stilled Seam, and the Expedition's code on small fakes.
-- The engine half is tools/r72_mint/run.sh, the numbers tools/r72_mint/balance.py.
-- Prints "R72 MINT PORTABLE PASS checks=<n>".
--
--   luajit tools/r72_mint/portable_test.lua [REPO]
--
-- A. The catalogue row; who may create and enter at 60 and at 69 (the real runs.lua).
-- B. The chest's table.
-- C. The template: palette, places.
-- D. The grid: the footprint, pinned (final through lane STYLE).
-- E. Ore and gem: eight places at reach, hull behind; T6 writes Abyssal Crystal and Diamond.
-- F. Floors flat, no step; the free height over every floor cell.
-- G. The routes for a player and a mob, the door, the hull.
-- H. The lake: basin, lava, five pillars, six level jumps, no way out.
-- I. The shot lines: open, through the gaps only, every top clear.
-- J. The roster and its places.
-- K. No pack can be walked round; no two packs linked; the arrival out of sight.
-- L. The light.
-- M. The traps on this template (the real traps.lua): chosen per creation, firing at a
--    player, never at a mob; nobody waiting on a top is hit, a jumper is.
-- N. Lava: five ticks kill; Return Home refused in lava inside an Expedition only.
-- O. The lava guard (grug_core/lava_guard.lua).
-- P. Duewarden, the names through 69, the quest and its rows.
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
local ID = "last_mint"

-- ---- C. The template, read as the game reads it ------------------------------------
local _, ffi = pcall(require, "ffi")
ffi.cdef[[int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *src, unsigned long srcLen);]]
local zlib = ffi.load("z")
local function inflate(bytes)
	local out, size = ffi.new("uint8_t[?]", 4194304), ffi.new("unsigned long[1]", 4194304)
	assert(zlib.uncompress(out, size, bytes, #bytes) == 0)
	return ffi.string(out, size[0])
end
local file = assert(io.open(repo .. "/mods/PLAYER/grug_expeditions/templates/" .. ID .. ".exp", "rb"))
local tpl = T.parse(file:read("*a"), inflate, ID)
file:close()
T.check_fits(tpl, C.BOX, {"arrival", "start_waystone", "end_waystone"}, ID)
local sx, sy, sz = tpl.size.x, tpl.size.y, tpl.size.z
eq(sx .. "x" .. sy .. "x" .. sz, "128x64x128", "C the whole box")

-- Every palette node by what it does to a walker, to light and to a fall. A node missing
-- here stops the fixture: it has to be thought about.
local LIGHT = {air = 0, ["default:torch_wall"] = 12, ["grug_decor:xdecor_lantern_hanging"] = 13,
	["grug_decor:xdecor_rope"] = 0}
local LAVA = "default:lava_source"
local SOLID = {["default:stone"] = true, ["default:stonebrick"] = true, ["default:stone_block"] = true,
	["default:cobble"] = true, ["default:wood"] = true, ["default:steelblock"] = true,
	["grug_decor:darkage_basalt_brick"] = true, ["grug_decor:darkage_slate_tile"] = true,
	["grug_materials:iron_block"] = true,
	["grug_materials:stone_with_anthracite"] = true, ["grug_materials:stone_with_jade"] = true,
	["grug_expeditions:waystone"] = true, ["grug_expeditions:reward_chest"] = true,
	["grug_expeditions:reward_door"] = true}
local kinds = {}
for index, name in ipairs(tpl.nodes) do
	check(LIGHT[name] or SOLID[name] or name == LAVA, "C palette: " .. name)
	kinds[index - 1] = LIGHT[name] and "open" or name == LAVA and "lava" or "solid"
end
local rows = sx * sy
local function at(x, y, z) return z * rows + y * sx + x + 1 end
local function inside(x, y, z)
	return x >= 0 and y >= 0 and z >= 0 and x < sx and y < sy and z < sz
end
local function name_at(x, y, z) return tpl.nodes[tpl.cells:byte(at(x, y, z)) + 1] end
local function kind(x, y, z) return kinds[tpl.cells:byte(at(x, y, z))] end
local DOOR, ORE, GEM = "grug_expeditions:reward_door", C.TEMPLATE_ORE, C.TEMPLATE_GEM
-- `changed`: node names read as air (the door, the dug ore).
local function solid(x, y, z, changed)
	if not inside(x, y, z) then return true end
	if changed and changed[name_at(x, y, z)] then return false end
	return kind(x, y, z) == "solid"
end
local function open(x, y, z, changed)
	return inside(x, y, z) and not solid(x, y, z, changed) and kind(x, y, z) ~= "lava"
end

local FLOOR, F, EYE = 31, 32, 33
local places = tpl.places
for name, node in pairs({start_waystone = "grug_expeditions:waystone",
	end_waystone = "grug_expeditions:waystone", chest = "grug_expeditions:reward_chest", door = DOOR}) do
	local p = assert(places[name], name)
	eq(name_at(p.x, p.y, p.z), node, "C place " .. name)
end
eq(places.arrival.y, F, "C the arrival stands on the floor")
local function within(p, r) return p.x >= r[1] and p.x < r[3] and p.z >= r[2] and p.z < r[4] end
-- The rooms' envelopes (the plan's, mirrored on z) and the pack rooms as built.
local ENVELOPE = {arrival = {8, 96, 32, 120}, bins = {48, 88, 80, 120}, furnace = {96, 88, 120, 120},
	lake = {96, 40, 120, 80}, cooling = {96, 8, 120, 32}, vestibule = {48, 48, 80, 72},
	press = {48, 8, 80, 40}, store = {8, 8, 32, 40}}
local PACK_ROOM = {pack_a = {52, 94, 76, 114}, pack_b = {97, 91, 119, 114}, pack_c = {96, 8, 120, 27},
	pack_d = {50, 49, 78, 71}, boss = {50, 12, 78, 38}}
check(within(places.start_waystone, ENVELOPE.arrival) and within(places.arrival, ENVELOPE.arrival),
	"C the start waystone and the arrival in room 0")
check(within(places.end_waystone, ENVELOPE.store) and within(places.chest, ENVELOPE.store),
	"C chest and end waystone in the store")
-- The boss's range: the hall's envelope (BOSSRESET's places).
local bmin, bmax = assert(places.boss_room_min), assert(places.boss_room_max)
eq(bmin.x .. "," .. bmin.z .. "," .. bmax.x .. "," .. bmax.z, "48,8,79,39", "C the boss's envelope")

-- A cell a walker stands in: a floor below, two open cells (lava is none).
local function standable(x, y, z, changed)
	return solid(x, y - 1, z, changed) and open(x, y, z, changed) and open(x, y + 1, z, changed)
end

-- ---- D. The grid ---------------------------------------------------------------------
-- One cell for 4 x 4 nodes, as the plan's grid: '#' holds no floor cell, '~' the lake's
-- open basin, '.' floor. Pinned: the footprint is final through lane STYLE.
local GRID = {
	"################################",
	"################################",
	"##......################......##",
	"##......####........####......##",
	"##..................#.........##",
	"##..................#.........##",
	"##......####........#..##....###",
	"##......####........#..###..####",
	"##......####........#..###..####",
	"####...#####........#..###..####",
	"###############..####..#......##",
	"###############..####..#~~~~~~##",
	"############........#..#~~~~~~##",
	"############........#..#~~..~~##",
	"############...........#~~~~~~##",
	"############...........#~~~~~~##",
	"############........####~~..~~##",
	"############........####~~~~~~##",
	"########################~~~~~~##",
	"########################......##",
	"##########################..####",
	"##########################..####",
	"#########################....###",
	"#############......#####......##",
	"###.....#####......#####......##",
	"##......#####......#####......##",
	"##............................##",
	"##............................##",
	"####...######......#####......##",
	"####...#########################",
	"################################",
	"################################",
}
local grid_out = {}
for row = 0, 31 do
	local line = {}
	for col = 0, 31 do
		local floor, lake = 0, 0
		for dz = 0, 3 do
			for dx = 0, 3 do
				local x, z = 4 * col + dx, 4 * row + dz
				if standable(x, F, z) then floor = floor + 1 end
				if kind(x, 7, z) == "lava" then lake = lake + 1 end
			end
		end
		line[#line + 1] = floor > 0 and (lake > floor and "~" or ".") or (lake > 0 and "~" or "#")
	end
	grid_out[#grid_out + 1] = table.concat(line)
end
if os.getenv("PRINT_GRID") then print(table.concat(grid_out, "\n")) end
for row = 1, 32 do eq(grid_out[row], GRID[row], "D the grid's row " .. row) end

-- ---- E. Ore and gem ------------------------------------------------------------------
-- Eight shared places on rock plinths at the wall: one ore after pack a, one gem after
-- pack c, four ore and two gems in the store (plan "Ore and rewards"). None on a pillar
-- or a lake wall.
local WANT = {
	{ORE, 75, 98, "bins"}, {GEM, 119, 11, "cooling"},
	{ORE, 8, 31, "store"}, {ORE, 31, 33, "store"}, {ORE, 31, 27, "store"}, {ORE, 8, 11, "store"},
	{GEM, 8, 19, "store"}, {GEM, 31, 11, "store"},
}
check(tpl.dig[ORE] and tpl.dig[GEM], "E both marked")
local marks = 0
for name in pairs(tpl.dig) do
	marks = marks + 1
	check(name == ORE or name == GEM, "E only ore and gem are marked")
end
eq(marks, 2, "E two marks")
local found = 0
for z = 0, sz - 1 do
	for y = 0, sy - 1 do
		for x = 0, sx - 1 do
			local name = name_at(x, y, z)
			if name == ORE or name == GEM then found = found + 1 end
		end
	end
end
eq(found, #WANT, "E exactly eight cells")
local PLINTH = {}
for _, spot in ipairs(WANT) do
	local node, x, z = spot[1], spot[2], spot[3]
	local label = ("E %s at %d,%d"):format(node, x, z)
	eq(name_at(x, EYE, z), node, label)
	eq(name_at(x, F, z), "default:stone", label .. ": on a rock plinth")
	PLINTH[at(x, F, z)] = true
	check(within({x = x, z = z}, ENVELOPE[spot[4]]), label .. " in the " .. spot[4])
	check(not within({x = x, z = z}, ENVELOPE.lake), label .. ": away from the lake")
	local reach, behind = 0, 0
	for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		local nx, nz = x + d[1], z + d[2]
		if standable(nx, F, nz) then
			reach = reach + 1
		elseif solid(nx, EYE, nz) and solid(nx + d[1], EYE, nz + d[2]) and
				name_at(nx, EYE, nz) == "default:stone" then
			behind = behind + 1
		end
	end
	check(reach >= 1 and behind >= 1, label .. ": at reach with hull behind")
end

-- The T6 run writes Abyssal Crystal and Diamond in these places (catalogue.swaps), and
-- only those are marked.
local ids_by_name, next_cid = {}, 0
_G.core = {registered_nodes = setmetatable({}, {__index = function() return {} end}),
	get_content_id = function(name)
		if not ids_by_name[name] then next_cid = next_cid + 1; ids_by_name[name] = next_cid end
		return ids_by_name[name]
	end}
T.resolve(tpl, C.swaps())
_G.core = nil
for level = 60, 69 do eq(C.tier_of(level).tier, 6, "E T6 at " .. level) end
local t6 = C.tier_of(60)
eq(t6.ore, "grug_materials:abyssal_crystal_ore", "E T6's ore")
eq(t6.gem, "grug_materials:stone_with_diamond", "E T6's gem")
local variant = tpl.variants[6]
for name in pairs(variant.dig) do
	check(name == t6.ore or name == t6.gem, "E T6 marks only its ore and gem: " .. name)
end
for _, spot in ipairs(WANT) do
	eq(variant.ids[tpl.cells:byte(at(spot[2], EYE, spot[3]))], ids_by_name[spot[1] == ORE and t6.ore or t6.gem],
		("E T6 writes its own at %d,%d"):format(spot[2], spot[3]))
end

-- ---- F. Floors flat, no step, the free height ------------------------------------------
-- Every cell anyone can reach (a 3D flood through all that is not solid, the door open
-- and the ore dug) that stands on something stands on the floor at y 31, or on the
-- chest, a waystone or an ore plinth: no step, no dais, no ledge.
local ALL_OPEN = {[DOOR] = true, [ORE] = true, [GEM] = true}
local PERCH = {["grug_expeditions:reward_chest"] = true, ["grug_expeditions:waystone"] = true,
	[ORE] = true, [GEM] = true}
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
local open_all = flood(ALL_OPEN)
local off_floor = 0
for z = 0, sz - 1 do
	for y = 1, sy - 1 do
		for x = 0, sx - 1 do
			if open_all[at(x, y, z)] and kind(x, y, z) ~= "lava" and solid(x, y - 1, z, ALL_OPEN) and y ~= F then
				local below = name_at(x, y - 1, z)
				if not (PERCH[below] or PLINTH[at(x, y - 1, z)]) then
					off_floor = off_floor + 1
					print(("F off the floor: %d,%d,%d on %s"):format(x, y, z, below))
				end
			end
		end
	end
end
eq(off_floor, 0, "F every floor at y 31")
-- No one-node block on the floor but the chest and the waystones.
for z = 0, sz - 1 do
	for x = 0, sx - 1 do
		if solid(x, F, z) and open(x, EYE, z) and open(x, EYE + 1, z) then
			local beside = false
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				if standable(x + d[1], F, z + d[2]) then beside = true end
			end
			if beside then
				check(PERCH[name_at(x, F, z)] and not PLINTH[at(x, F, z)],
					("F a step at %d,%d: %s"):format(x, z, name_at(x, F, z)))
			end
		end
	end
end
-- The free height over every floor cell: a mob fits everywhere (the tallest physics
-- box is 1.95, obstacle.physics_box), and a wisp in rooms 2, 3 and 4 stays within
-- seven nodes of the floor.
local WISP_ROOMS = {pack_b = true, pack_c = true, pack_d = true}
local lowest, floor_cells = 99, {}
for z = 0, sz - 1 do
	for x = 0, sx - 1 do
		if standable(x, F, z) then
			local h = 0
			while open(x, F + h, z) do h = h + 1 end
			lowest = math.min(lowest, h)
			floor_cells[#floor_cells + 1] = {x = x, z = z, h = h}
			for key, r in pairs(PACK_ROOM) do
				if WISP_ROOMS[key] and within({x = x, z = z}, r) then
					check(h <= 7, ("F at most seven nodes of air in %s at %d,%d: %d"):format(key, x, z, h))
				end
			end
		end
	end
end
check(lowest >= 3, "F three nodes of air over every floor cell: " .. lowest)
print(("floor cells: %d, the lowest free height %d"):format(#floor_cells, lowest))

-- ---- G. The routes ---------------------------------------------------------------------
local function walk(changed, wide, tall, from, to)
	local function free(x, z)
		for dz = -wide, wide do
			for dx = -wide, wide do
				if not solid(x + dx, FLOOR, z + dz, changed) then return false end
				for y = F, F + tall - 1 do
					if not open(x + dx, y, z + dz, changed) then return false end
				end
			end
		end
		return true
	end
	if not free(from[1], from[2]) then return nil end
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
local approach, exit = {108, 78}, {108, 41}
local chest_side = {places.chest.x + 2, places.chest.z}
local to_lake = walk(nil, 0, 2, start, approach)
check(to_lake, "G a player walks from the arrival to the lake")
local from_lake = walk(OPEN_DOOR, 0, 2, exit, chest_side)
check(from_lake, "G and from the lake to the chest, the door open")
check(walk(ALL_OPEN, 0, 2, start, exit) == nil, "G nobody walks round the lake")
check(walk(ALL_OPEN, 0, 2, exit, start) == nil, "G nor back round it")
check(walk(nil, 0, 2, exit, chest_side) == nil, "G nobody walks through the shut door")
-- A mob: a Seep three cells wide, an elite three tall.
check(walk(nil, 1, 3, {places.arrival.x, places.arrival.z}, approach), "G a mob walks to the lake")
check(walk(OPEN_DOOR, 1, 3, exit, chest_side), "G and from it to the store")
local boss_row
for _, row in ipairs(tpl.encounters) do
	if row.tier == "boss" then boss_row = row end
end
check(walk(nil, 1, 3, exit, {boss_row.pos.x, boss_row.pos.z}), "G the way to Duewarden")
-- The store: sealed with the door shut, the ore dug or not; the hull holds.
local function reaches(seen, r)
	for z = r[2], r[4] - 1 do
		for x = r[1], r[3] - 1 do
			for y = F, F + 3 do
				if seen[at(x, y, z)] then return true end
			end
		end
	end
	return false
end
local store = ENVELOPE.store
check(not reaches(flood(), store), "G the store is sealed with the door shut")
check(not reaches(flood({[ORE] = true, [GEM] = true}), store), "G digging opens no way in")
check(reaches(open_all, store), "G the door opens the way")
for z = 0, sz - 1 do
	for y = 0, sy - 1 do
		for x = 0, sx - 1 do
			if x == 0 or y == 0 or z == 0 or x == sx - 1 or y == sy - 1 or z == sz - 1 then
				check(not open_all[at(x, y, z)], "G the hull holds")
			end
		end
	end
end
print(("route: %d steps to the lake, %d from it to the chest"):format(to_lake, from_lake))

-- ---- H. The lake ----------------------------------------------------------------------
-- The plan's section: a basin of 24 x 32, lava at y 2-7 (its surface 7.5), five 4 x 4
-- pillars solid from the bed through y 31, landings at y 31 on both ends, air to y 59.
local BASIN = {96, 44, 120, 76}
local PILLARS = {{106, 70, 110, 74}, {106, 64, 110, 68}, {106, 58, 110, 62}, {106, 52, 110, 56},
	{106, 46, 110, 50}}
local TOPS = {{96, 76, 120, 80}}
for _, p in ipairs(PILLARS) do TOPS[#TOPS + 1] = p end
TOPS[#TOPS + 1] = {96, 40, 120, 44}
local LAVA_LO, LAVA_HI, AIR_HI = 2, 7, 59
local function in_pillar(x, z)
	for _, p in ipairs(PILLARS) do
		if within({x = x, z = z}, p) then return true end
	end
	return false
end
local lava_cells = 0
for z = 0, sz - 1 do
	for y = 0, sy - 1 do
		for x = 0, sx - 1 do
			local in_basin = within({x = x, z = z}, BASIN)
			local k = kind(x, y, z)
			if k == "lava" then
				lava_cells = lava_cells + 1
				check(in_basin and y >= LAVA_LO and y <= LAVA_HI and not in_pillar(x, z),
					("H lava only in the basin's bed: %d,%d,%d"):format(x, y, z))
				-- Nothing beside or below it to flow into: the guard's ground rule.
				for _, d in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}) do
					local k2 = kind(x + d[1], y + d[2], z + d[3])
					check(k2 == "lava" or k2 == "solid", ("H the lava at %d,%d,%d can flow"):format(x, y, z))
				end
			elseif in_basin then
				if in_pillar(x, z) then
					check((y <= FLOOR or y > AIR_HI) == (k == "solid"), ("H a pillar at %d,%d,%d"):format(x, y, z))
				elseif y < LAVA_LO then
					check(k == "solid", "H the bed")
				elseif y <= LAVA_HI then
					check(false, ("H no lava at %d,%d,%d"):format(x, y, z))
				elseif y <= AIR_HI then
					-- torches on the gaps' faces at the tops' height are open too
					check(k == "open", ("H the lake's air at %d,%d,%d"):format(x, y, z))
				else
					check(k == "solid", "H the roof")
				end
			end
		end
	end
end
eq(lava_cells, (24 * 32 - 5 * 16) * (LAVA_HI - LAVA_LO + 1), "H the lava's cells")
-- The basin's sides are walls to y 59 (x) or the landings' bodies to y 31 (z): no rim.
for z = BASIN[2], BASIN[4] - 1 do
	for y = 0, AIR_HI do
		check(solid(BASIN[1] - 1, y, z) and solid(BASIN[3], y, z), "H the side walls stand")
	end
end
for x = BASIN[1], BASIN[3] - 1 do
	for y = 0, FLOOR do
		check(solid(x, y, BASIN[2] - 1) and solid(x, y, BASIN[4]), "H the landings' faces stand")
	end
end
-- No ledge, shelf or climb anywhere below the tops: nothing in the basin to stand on.
for z = BASIN[2], BASIN[4] - 1 do
	for x = BASIN[1], BASIN[3] - 1 do
		for y = LAVA_LO, FLOOR do
			check(not standable(x, y, z, ALL_OPEN), ("H a ledge at %d,%d,%d"):format(x, y, z))
		end
	end
end
-- The tops: every cell a floor at y 31, the same height on all seven; four deep, and
-- the six gaps between them two node rows, open from the lava to the roof over the
-- basin's whole width.
local GAP = 2
for i, top in ipairs(TOPS) do
	eq(top[4] - top[2], 4, "H a top four deep, its runway: " .. i)
	for z = top[2], top[4] - 1 do
		for x = math.max(top[1], 106), math.min(top[3], 110) - 1 do
			check(standable(x, F, z), ("H the top %d stands at %d,%d"):format(i, x, z))
		end
	end
	if i > 1 then
		local higher = TOPS[i - 1]
		eq(higher[2] - top[4], GAP, "H the gap before top " .. i)
		for z = top[4], higher[2] - 1 do
			for x = BASIN[1], BASIN[3] - 1 do
				for y = LAVA_HI + 1, AIR_HI do
					check(open(x, y, z), ("H the gap at %d,%d,%d"):format(x, y, z))
				end
			end
		end
	end
end
-- The jump (the pinned engine: src/defaultsettings.cpp walk 4, jump 6.5; gravity 9.81
-- doubled by src/client/clientenvironment.cpp): a level jump from walking speed, and the
-- distance the body's centre must cover from one top's edge to the next (its box,
-- 0.6 wide, stands while it overlaps a top).
local WALK, JUMP, GRAVITY, HALF = 4, 6.5, 2 * 9.81, 0.3
local flight = 2 * JUMP / GRAVITY
local travel = WALK * flight
local need = GAP - 2 * HALF
check(travel > GAP and travel - need > 1, ("H a walking jump carries %.2f nodes, the gap needs %.2f"):format(
	travel, need))
print(("lake: rise %.2f, flight %.3f s, travel %.2f nodes; a gap of %d needs %.1f"):format(
	JUMP * JUMP / (2 * GRAVITY), flight, travel, GAP, need))
-- A miss falls 24 nodes into the lava; one Blink (10 m) from its surface reaches no top.
local DROP = (FLOOR + 0.5) - (LAVA_HI + 0.5)
eq(DROP, 24, "H the drop")
check(read_file("mods/PLAYER/grug_abilities/kits_mage.lua"):find("Teleport up to 10 m", 1, true), "H Blink is 10 m")
check(LAVA_HI + 0.5 + 1.47 + 10 < FLOOR + 0.5, "H no single Blink out of the lava")

-- ---- I. The shot lines ------------------------------------------------------------------
-- Two of four, one per group (W1/W2, W3/W4), each along x through a gap's middle a node
-- and a half over the tops, every 6 s, the second group 3 s after the first.
local traps_text = read_file("mods/PLAYER/grug_expeditions/traps.lua")
local BALL = tonumber(traps_text:match("\nlocal BALL = ([%d%.]+)\n"))
check(BALL and traps_text:find("\nlocal REACH = BALL %+ 0%.3\n"), "I traps.lua's ball and reach")
local REACH = BALL + 0.3
local SNEAK_EDGE = 0.6 * 0.49 -- localplayer.cpp: the box's extent x 0.49 over a sneak node's edge
local walls, floors = {}, {}
for _, row in ipairs(tpl.traps) do
	if row.kind == "wall" then walls[#walls + 1] = row else floors[#floors + 1] = row end
end
eq(#walls, 4, "I four wall candidates")
local GAP_MIDDLES = {}
for i = 2, #TOPS do GAP_MIDDLES[(TOPS[i][4] + TOPS[i - 1][2] - 1) / 2] = true end
local per_group = {}
for _, w in ipairs(walls) do
	per_group[w.group] = (per_group[w.group] or 0) + 1
	eq(w.pick, 1, "I one of each group")
	eq(w.period, 6, "I every 6 s")
	check((w.group == "w1" and w.offset == 0) or (w.group == "w2" and w.offset == 3), "I the offsets")
	check(w.axis == "+x" or w.axis == "-x", "I along x")
	eq(w.pos.y, F + 0.5, "I a node and a half over the tops")
	check(GAP_MIDDLES[w.pos.z], "I through a gap's middle: " .. w.pos.z)
	local sign = w.axis == "+x" and 1 or -1
	check((sign == 1 and math.abs(w.pos.x - (BASIN[1] - 0.4)) < 1e-9) or
		(sign == -1 and math.abs(w.pos.x - (BASIN[3] - 0.6)) < 1e-9), "I the muzzle just inside the wall")
	-- Every cell the ball's cross-section touches is open from the muzzle to the far wall.
	local y0, y1 = math.floor(w.pos.y - BALL + 0.5), math.floor(w.pos.y + BALL + 0.5)
	local z0, z1 = math.floor(w.pos.z - BALL + 0.5), math.floor(w.pos.z + BALL + 0.5)
	for x = BASIN[1], BASIN[3] - 1 do
		for y = y0, y1 do
			for z = z0, z1 do check(open(x, y, z), ("I the flight at %d,%d,%d"):format(x, y, z)) end
		end
	end
	check(solid(sign == 1 and BASIN[3] or BASIN[1] - 1, y0, z0), "I stone stops it at the far wall")
end
eq(per_group.w1, 2, "I W1 and W2")
eq(per_group.w2, 2, "I W3 and W4")
-- Every top is clear: the closest a standing body comes to any line, its centre over the
-- top (no overhang), and at the sneak edge, stays beyond the ball's reach.
local closest_flat, closest_edge = math.huge, math.huge
for _, top in ipairs(TOPS) do
	for _, w in ipairs(walls) do
		local nearest = math.min(math.abs(top[2] - 0.5 - w.pos.z), math.abs(top[4] - 0.5 - w.pos.z))
		closest_flat = math.min(closest_flat, nearest)
		closest_edge = math.min(closest_edge, nearest - SNEAK_EDGE)
	end
end
check(closest_flat - REACH >= 0.3 - 1e-9, "I a body standing on a top is clear: " .. closest_flat)
check(closest_edge > REACH, "I even at the sneak edge: " .. closest_edge)
print(("shots: the closest line %.2f from a top's edge (reach %.1f), %.3f at the sneak edge"):format(
	closest_flat, REACH, closest_edge))

-- ---- J. The roster ----------------------------------------------------------------------
-- The plan's starting roster with one normal more in every pack (balance.py: at four
-- players a run at 60 was short of ten minutes), the families' own view ranges.
local function view_of(file)
	return tonumber(read_file("mods/ENTITIES/grug_mobs/" .. file):match("view_range = (%d+)"))
end
local VIEW = {["grug_mobs:lava_flan"] = view_of("lava_flan.lua"), ["grug_mobs:ember_wisp"] = view_of("ember_wisp.lua"),
	["grug_mobs:land_guard"] = view_of("land_guard.lua")}
VIEW["grug_mobs:duewarden"] = VIEW["grug_mobs:land_guard"] -- the Sentinel's body
eq(VIEW["grug_mobs:lava_flan"], 10, "J a Seep sees 10")
eq(VIEW["grug_mobs:ember_wisp"], 16, "J a Wisp 16")
eq(VIEW["grug_mobs:land_guard"], 14, "J a Sentinel 14")
local ROSTER = {
	pack_a = {["grug_mobs:lava_flan/normal"] = 5},
	pack_b = {["grug_mobs:lava_flan/normal"] = 3, ["grug_mobs:lava_flan/elite"] = 1, ["grug_mobs:ember_wisp/normal"] = 1},
	pack_c = {["grug_mobs:lava_flan/normal"] = 3, ["grug_mobs:lava_flan/elite"] = 1, ["grug_mobs:ember_wisp/normal"] = 1},
	pack_d = {["grug_mobs:land_guard/elite"] = 1, ["grug_mobs:ember_wisp/normal"] = 3},
	boss = {["grug_mobs:duewarden/boss"] = 1},
}
local SPREAD = {{0, 0}, {3, 0}, {-3, 0}, {0, 3}, {0, -3}, {3, 3}, {-3, 3}, {3, -3}, {-3, -3}} -- encounters.lua
local got, packs, spots = {}, {}, {}
for _, row in ipairs(tpl.encounters) do
	check(VIEW[row.mob], "J a known family: " .. row.mob)
	eq(row.pos.y, F, "J on the floor")
	local k = row.mob .. "/" .. row.tier
	got[row.room] = got[row.room] or {}
	got[row.room][k] = (got[row.room][k] or 0) + row.count
	packs[row.room] = packs[row.room] or {}
	for index = 1, row.count do
		local offset = SPREAD[(index - 1) % #SPREAD + 1]
		local spot = {x = row.pos.x + offset[1], z = row.pos.z + offset[2], view = VIEW[row.mob],
			room = row.room, mob = row.mob}
		check(standable(spot.x, F, spot.z), ("J room for a mob at %d,%d"):format(spot.x, spot.z))
		check(within(spot, PACK_ROOM[row.room]), "J " .. row.room .. " in its room")
		table.insert(packs[row.room], spot)
		spots[#spots + 1] = spot
	end
end
for room, want in pairs(ROSTER) do
	for k, n in pairs(want) do eq(got[room] and got[room][k], n, "J " .. room .. " " .. k) end
	for k in pairs(got[room] or {}) do check(want[k], "J nothing else in " .. room .. ": " .. k) end
end
for room in pairs(got) do check(ROSTER[room], "J a known room: " .. room) end
eq(boss_row.pos.x .. "," .. boss_row.pos.z, "64,23", "J Duewarden's place")
-- The floor traps: two of four in rooms 2, 4 and 5, never on a pillar.
local FLOOR_ROOMS = {f1 = "pack_b", f2 = "pack_d", f3 = "boss"}
local per_floor = {}
for _, row in ipairs(floors) do
	per_floor[row.group] = (per_floor[row.group] or 0) + 1
	eq(row.pick, 2, "J two of each floor group")
	check(within(row.pos, PACK_ROOM[FLOOR_ROOMS[row.group]]), "J the floor trap in its room")
	check(standable(row.pos.x, row.pos.y, row.pos.z), "J a floor trap on the floor")
end
eq(per_floor.f1, 4, "J F1-F4")
eq(per_floor.f2, 4, "J F5-F8")
eq(per_floor.f3, 4, "J F9-F12")

-- ---- K. No walking round, no link, the arrival --------------------------------------------
-- A straight look from eye to eye at y 33: walls stop it, lanterns, ropes and torches not.
local function sees(x0, z0, x1, z1)
	local dx, dz = x1 - x0, z1 - z0
	local steps = math.ceil(math.sqrt(dx * dx + dz * dz) * 4)
	for i = 1, steps - 1 do
		local x = math.floor(x0 + dx * i / steps + 0.5)
		local z = math.floor(z0 + dz * i / steps + 0.5)
		if solid(x, EYE, z) then return false end
	end
	return true
end
local function noticed(list, x, z)
	local best
	for _, spot in ipairs(list) do
		local d = math.sqrt((spot.x - x) ^ 2 + (spot.z - z) ^ 2)
		if d <= spot.view and sees(spot.x, spot.z, x, z) then
			local margin = spot.view - d
			if not best or margin > best then best = margin end
		end
	end
	return best
end
-- The user's rule (2026-11-08): from every floor cell of a pack's room at least one mob
-- of that pack would notice the player, in its view range and in sight.
for _, key in ipairs({"pack_a", "pack_b", "pack_c", "pack_d"}) do
	local r, cells, worst = PACK_ROOM[key], 0, math.huge
	for _, cell in ipairs(floor_cells) do
		if within(cell, r) then
			cells = cells + 1
			local margin = noticed(packs[key], cell.x, cell.z)
			check(margin ~= nil, ("K %s can be walked round at %d,%d"):format(key, cell.x, cell.z))
			worst = math.min(worst, margin)
		end
	end
	print(("%s: %d floor cells, every one noticed; the thinnest margin %.1f nodes"):format(key, cells, worst))
end
-- The boss is not walked round: the door holds until he dies. For the record, his share.
do
	local cells, seen = 0, 0
	for _, cell in ipairs(floor_cells) do
		if within(cell, PACK_ROOM.boss) then
			cells = cells + 1
			if noticed(packs.boss, cell.x, cell.z) then seen = seen + 1 end
		end
	end
	print(("boss: %d of %d floor cells in Duewarden's view"):format(seen, cells))
end
-- No pack links to the next: nobody of one pack sees anybody of another, and no floor
-- cell lies in the sight of two packs, so a player anywhere wakes one pack at most.
local nearest = math.huge
for i, a in ipairs(spots) do
	for j = i + 1, #spots do
		local b = spots[j]
		if a.room ~= b.room then
			local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			nearest = math.min(nearest, d)
			if d <= math.max(a.view, b.view) then
				check(not sees(a.x, a.z, b.x, b.z), ("K %s and %s are linked"):format(a.room, b.room))
			end
		end
	end
end
local shared = 0
for _, cell in ipairs(floor_cells) do
	local first
	for _, spot in ipairs(spots) do
		local d2 = (spot.x - cell.x) ^ 2 + (spot.z - cell.z) ^ 2
		if spot.room ~= first and d2 <= spot.view * spot.view and sees(spot.x, spot.z, cell.x, cell.z) then
			if first then
				shared = shared + 1
				print(("two packs see %d,%d: %s, %s"):format(cell.x, cell.z, first, spot.room))
				break
			end
			first = spot.room
		end
	end
end
eq(shared, 0, "K no floor cell in two packs' sight")
print(("nearest mobs of two packs: %.1f nodes"):format(nearest))
-- Sight counts as a pull: the arrival and the start waystone lie beyond every pack's
-- view range + 8, and nobody waits on the lake.
for _, spot in ipairs(spots) do
	for _, p in ipairs({places.arrival, places.start_waystone}) do
		local d = math.sqrt((spot.x - p.x) ^ 2 + (spot.z - p.z) ^ 2)
		check(d > spot.view + 8, ("K the arrival is out of %s's sight"):format(spot.room))
	end
	check(not within(spot, ENVELOPE.lake), "K no mob on the lake")
end

-- ---- L. The light ----------------------------------------------------------------------
-- The engine's rule: minus one per node from each source (torches, lanterns, the lava),
-- stopped by what is solid. Everywhere one stands, at eye height: most of it bright
-- enough to read a ring or a slam, and no black corner; the tops lit for the jumps.
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
			local name = name_at(x, y, z)
			local level = name == LAVA and 13 or LIGHT[name]
			if level and level > 0 then raise(at(x, y, z), x, y, z, level) end
		end
	end
end
for value = 14, 2, -1 do
	for _, c in ipairs(buckets[value] or {}) do
		for _, d in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}) do
			local x, y, z = c[1] + d[1], c[2] + d[2], c[3] + d[3]
			if inside(x, y, z) and not solid(x, y, z) then raise(at(x, y, z), x, y, z, value - 1) end
		end
	end
end
local darkest, total, usual, dark_at = 99, 0, 0, nil
local tops_darkest = 99
for _, cell in ipairs(floor_cells) do
	local value = light[at(cell.x, EYE, cell.z)] or 0
	total = total + value
	if value >= LIGHT_USUAL then usual = usual + 1 end
	if value < darkest then darkest, dark_at = value, cell.x .. "," .. cell.z end
	if within(cell, ENVELOPE.lake) then tops_darkest = math.min(tops_darkest, value) end
end
print(("light at eye height: %d cells, mean %.1f, %.0f %% at %d or more, darkest %d at %s, on the lake %d"):format(
	#floor_cells, total / #floor_cells, 100 * usual / #floor_cells, LIGHT_USUAL, darkest, dark_at, tops_darkest))
check(darkest >= LIGHT_MIN, "L no dark corner: " .. darkest .. " at " .. dark_at)
check(usual / #floor_cells >= USUAL_SHARE, "L the rooms read: " .. usual / #floor_cells)
check(tops_darkest >= LIGHT_USUAL, "L every top lit for the jump: " .. tops_darkest)

-- ---- A. The catalogue row; who may create and enter (the real runs.lua) -----------------
local row = C.definition(ID)
check(row ~= nil, "A the row")
eq(row.name, "The Last Mint", "A its name")
eq(row.level, 60, "A from 60")
eq(row.max_level, 69, "A to 69")
eq(row.max_players, 4, "A four players")
eq(row.template, ID, "A its template")
check(not row.hidden, "A offered")
local offered = false
for _, r in ipairs(C.list()) do offered = offered or r.id == ID end
check(offered, "A a dialog offers it")
eq(C.entry_level(60), 58, "A 60 needs 58")
eq(C.entry_level(61), 59, "A 61 needs 59")
eq(C.entry_level(69), 60, "A 69 needs 60")
do
	local levels, parties, combat = {}, {}, {}
	local function person(name, level)
		levels[name] = level
		return {get_player_name = function() return name end, get_hp = function() return 100 end}
	end
	_G.core = {after = function() end, register_on_leaveplayer = function() end,
		register_on_joinplayer = function() end, log = function() end}
	_G.grug_home = {register_on_teleport = function() end}
	_G.grug_parties = {view = function(name) return parties[name] end,
		register_on_member_left = function() end, register_on_change = function() end}
	_G.grug_xp = {get_level = function(p) return levels[p:get_player_name()] end}
	_G.grug_core = {feed = function() end, in_combat = function(p) return combat[p:get_player_name()] end}
	_G.grug_expeditions = {templates = {[ID] = tpl}}
	local E = grug_expeditions
	local queue = {}
	local preparation = {init = function() end, cancel = function() end, status = function() end,
		enqueue = function(run, _, finish) queue[#queue + 1] = finish end}
	assert(loadfile(repo .. "/mods/PLAYER/grug_expeditions/runs.lua"))(C, preparation)
	local lead, mid, low, cap = person("lead", 60), person("mid", 58), person("low", 57), person("cap", 59)
	local function bonuses(p)
		local out = {}
		for _, r in ipairs(E.offered_levels(p, ID)) do out[#out + 1] = r.level end
		return table.concat(out, ",")
	end
	eq(bonuses(low), "", "A nothing at 57")
	eq(bonuses(mid), "60", "A only 60 at 58")
	eq(bonuses(cap), "60,61", "A 60 and 61 at 59")
	eq(bonuses(lead), "60,61,62,63,64,65,66,67,68,69", "A every level at 60")
	local ok, why = E.can_create(low, ID, 0)
	check(not ok and why == "This level of the Expedition needs level 58.", "A 57 cannot create: " .. tostring(why))
	check(E.can_create(lead, ID, 9), "A 60 creates at 69")
	-- A party of five at 60: two at 60, one at 58, one at 57, one at 59.
	local fifth, sixth = person("fifth", 60), person("sixth", 60)
	local party = {id = 1, leader = "lead", members = {}}
	for _, name in ipairs({"lead", "mid", "low", "cap", "fifth", "sixth"}) do
		party.members[#party.members + 1] = {name = name, level = levels[name], online = true}
		parties[name] = party
	end
	local run = assert(E.create(lead, ID, 0))
	eq(run.level, 60, "A a run at 60")
	eq(run.max_players, 4, "A four places")
	check(not E.may_enter(mid, run), "A nobody enters while it is prepared")
	queue[1](true)
	eq(run.state, "ready", "A ready")
	check(E.can_enter(lead, run) and E.can_enter(mid, run) and E.can_enter(cap, run), "A 60, 58 and 59 enter at 60")
	ok, why = E.can_enter(low, run)
	check(not ok and why == "This Expedition needs level 58.", "A 57 is refused at 60: " .. tostring(why))
	combat.lead = true
	ok, why = E.can_enter(lead, run)
	check(not ok and why == "Cannot travel in combat.", "A not in combat")
	combat.lead = nil
	for _, name in ipairs({"lead", "mid", "cap", "fifth"}) do run.entered[name] = true end
	ok, why = E.may_enter(sixth, run)
	check(not ok and why == "This Expedition is full.", "A a fifth player finds it full")
	check(E.may_enter(fifth, run), "A one who entered goes back in")
	-- At 69: a solo player of 60 creates it; 59 is refused.
	local solo, near = person("solo", 60), person("near", 59)
	local high = assert(E.create(solo, ID, 9))
	queue[2](true)
	eq(high.level, 69, "A a run at 69")
	check(E.can_enter(solo, high), "A 60 enters at 69")
	parties.solo = {id = 2, leader = "solo", members = {{name = "solo", level = 60, online = true},
		{name = "near", level = 59, online = true}}}
	parties.near = parties.solo
	high.owner = {kind = "party", id = 2}
	ok, why = E.can_enter(near, high)
	check(not ok and why == "This Expedition needs level 60.", "A 59 is refused at 69: " .. tostring(why))
	_G.core, _G.grug_home, _G.grug_parties, _G.grug_xp, _G.grug_core, _G.grug_expeditions = nil
end

-- ---- B. The chest's table ----------------------------------------------------------------
local registry = read_file("mods/ITEMS/grug_materials/registry.lua")
local ORE_ITEMS = {["grug_materials:emberglass_shard"] = true}
for item in registry:gmatch('raw_item = "([^"]+)"') do ORE_ITEMS[item] = true end
for item in registry:gmatch('cut_item = "([^"]+)"') do ORE_ITEMS[item] = true end
check(ORE_ITEMS["grug_materials:rough_diamond"] and ORE_ITEMS["grug_materials:emberglass"], "B the ore items")
L.check(ORE_ITEMS)
local tbl = assert(L.TABLES[ID], "B the table")
local known = {}
for name in read_file("mods/ENTITIES/grug_mobs/items.lua"):gmatch('material%("([%w_]+)"') do
	known["grug_mobs:" .. name] = true
end
for _, level in ipairs({60, 65, 69}) do
	local plan = L.plan(tbl, level, function(lo) return lo end, {80, 240})
	local gear, coins, items = {}, 0, {}
	for _, entry in ipairs(plan) do
		if entry.quality then gear[#gear + 1] = entry.quality end
		if entry.copper then coins = coins + entry.copper end
		if entry.item then
			check(known[entry.item] and not ORE_ITEMS[entry.item], "B a material, no ore: " .. entry.item)
			items[entry.item] = entry.count
		end
	end
	eq(table.concat(gear, ","), "2,3", "B an Uncommon and, at 25 %, a Rare at " .. level)
	eq(coins, 800, "B ten kill bags at " .. level)
	eq(items["grug_mobs:stone_core"], 3, "B Stone Core at " .. level)
	eq(items["grug_mobs:slime_gel"], 1, "B Slime Gel at " .. level)
	check(#plan <= L.slots(plan), "B the plan fits")
end
eq(tbl.gear[2].chance, 25, "B the Rare's chance")
-- What the families drop, through the Expedition's filter (encounters.lua): every mineral
-- goes, Slime Gel and Heavy Leather stay; Duewarden drops nothing.
for _, file in ipairs({"lava_flan.lua", "ember_wisp.lua", "land_guard.lua"}) do
	local text = read_file("mods/ENTITIES/grug_mobs/" .. file)
	local drops = text:match("drops = (%b{})")
	for item in drops:gmatch('name = "([^"]+)"') do
		if item:find("^grug_materials:") then
			check(ORE_ITEMS[item], "B the filter takes " .. item .. " from " .. file)
		else
			check(item == "grug_mobs:slime_gel" or item == "grug_mobs:heavy_leather", "B kept: " .. item)
		end
	end
end

-- ---- M. The traps on this template (the real traps.lua) ----------------------------------
do
	local clock, timers, objects, entity_defs, players, hooks = 0, {}, {}, {}, {}, {ready = {}, enter = {}, ended = {}}
	local MINP = {x = 8064, y = -112, z = -1616}
	local marks = {}
	local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
	vector = {}
	function vector.new(x, y, z) return {x = x, y = y, z = z} end
	function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
	function vector.add(a, b)
		if type(b) == "number" then return {x = a.x + b, y = a.y + b, z = a.z + b} end
		return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
	end
	function vector.multiply(a, s) return {x = a.x * s, y = a.y * s, z = a.z * s} end
	function vector.distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
	local function node_name(pos)
		if marks[key(pos)] then return marks[key(pos)] end
		local x, y, z = pos.x - MINP.x, pos.y - MINP.y, pos.z - MINP.z
		if not inside(x, y, z) then return "default:stone" end
		return name_at(x, y, z)
	end
	local registered = setmetatable({}, {__index = function(_, name)
		return {walkable = SOLID[name] == true}
	end})
	_G.core = {
		registered_nodes = registered,
		get_modpath = function() return repo .. "/mods/PLAYER/grug_expeditions" end,
		get_current_modname = function() return "grug_expeditions" end,
		log = function(_, text) error("unexpected log: " .. tostring(text)) end,
		after = function(seconds, fn, ...) timers[#timers + 1] = {at = clock + seconds, fn = fn, args = {...}} end,
		register_node = function(name, def) rawset(registered, name, def) end,
		register_entity = function(name, def) entity_defs[name] = def end,
		get_node_or_nil = function(pos) return {name = node_name(pos)} end,
		get_node = function(pos) return {name = node_name(pos)} end,
		set_node = function(pos, node) marks[key(pos)] = node.name end,
		add_particle = function() end,
		get_player_by_name = function(name) return players[name] end,
		-- Traps never look at objects: a mob is never asked about.
		get_objects_inside_radius = function() error("a trap looked for objects") end,
		objects_inside_radius = function() error("a trap looked for objects") end,
	}
	core.add_entity = function(pos, name)
		local def = assert(entity_defs[name], "no entity " .. name)
		local object = {pos = vector.copy(pos), velocity = {x = 0, y = 0, z = 0}}
		local ent = setmetatable({object = object}, {__index = def})
		function object.get_luaentity() return not object.removed and ent or nil end
		function object.set_velocity(_, v) object.velocity = vector.copy(v) end
		function object.get_pos() return not object.removed and vector.copy(object.pos) or nil end
		function object.remove() object.removed = true end
		objects[#objects + 1] = object
		return object
	end
	_G.grug_core = {ARMOR_APPLIED_CUSTOM_TYPE = "grug_core:player_armor_applied",
		particles = {register = function() end, play = function() end},
		mono_time = function() return clock end,
		base_pool = function(level)
			level = math.max(1, math.min(60, level))
			return math.floor(20 + 5 * level + 0.66 * level * level + 0.5)
		end,
		apply_player_armor = function(_, damage) return damage end}
	_G.grug_expeditions = {templates = {[ID] = tpl}, definition = function() return {template = ID} end,
		register_on_ready = function(fn) table.insert(hooks.ready, fn) end,
		register_on_enter = function(fn) table.insert(hooks.enter, fn) end,
		register_on_end = function(fn) table.insert(hooks.ended, fn) end}
	dofile(repo .. "/mods/PLAYER/grug_expeditions/traps.lua")
	local TR = grug_expeditions.traps
	local function step()
		clock = clock + 0.05
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
				object.pos = vector.add(object.pos, vector.multiply(object.velocity, 0.05))
				object:get_luaentity():on_step(0.05)
			end
		end
	end
	local function run_for(seconds)
		local stop = clock + seconds
		while clock < stop - 1e-9 do step() end
	end
	local function new_player(name, x, y, z)
		local p = {name = name, hp = 10000, hits = 0}
		p.pos = {x = MINP.x + x, y = MINP.y + y, z = MINP.z + z}
		function p.get_player_name() return name end
		function p.get_pos() return vector.copy(p.pos) end
		function p.get_hp() return p.hp end
		function p.set_hp(_, hp) p.hits, p.hp = p.hits + 1, hp end
		players[name] = p
		return p
	end
	local next_id = 0
	local function new_run(level)
		next_id = next_id + 1
		local run = {id = next_id, expedition = ID, level = level, minp = MINP, inside = {}, state = "ready"}
		for _, fn in ipairs(hooks.ready) do fn(run) end
		return run
	end
	local function end_run(run)
		run.state = "ended"
		for name in pairs(run.inside) do run.inside[name] = nil end
		for _, fn in ipairs(hooks.ended) do fn(run, "empty") end
		players = {}
	end
	-- The choice: per creation, two of each floor group's four, one of each wall group's two;
	-- over many creations every candidate is armed sometimes.
	math.randomseed(72)
	local seen, cells = {}, {}
	for _ = 1, 100 do
		local run = new_run(60)
		local chosen = TR.chosen(run)
		local per = {}
		for _, t in ipairs(chosen.floor) do
			per[t.group] = (per[t.group] or 0) + 1
			seen[t.group .. key(t.cell)] = true
			check(not cells[key(t.cell)] or cells[key(t.cell)] == t.group, "M a cell in one group")
			cells[key(t.cell)] = t.group
		end
		for _, w in ipairs(chosen.wall) do
			per[w.group] = (per[w.group] or 0) + 1
			seen[w.group .. key(w.muzzle)] = true
		end
		check(per.f1 == 2 and per.f2 == 2 and per.f3 == 2 and per.w1 == 1 and per.w2 == 1, "M the picks")
		end_run(run)
	end
	local armed = 0
	for _ in pairs(seen) do armed = armed + 1 end
	eq(armed, 16, "M every candidate is armed in some creation")
	-- A floor trap fires at a player: the ring, the hit 1.5 s later, the mark; nobody else.
	local run = new_run(60)
	local chosen = TR.chosen(run)
	local trap = chosen.floor[1]
	local rel = {x = trap.cell.x - MINP.x, y = trap.cell.y - MINP.y, z = trap.cell.z - MINP.z}
	local victim = new_player("victim", rel.x, rel.y - 0.5, rel.z)
	local far = new_player("far", places.arrival.x, F - 0.5, places.arrival.z)
	run.inside.victim, run.inside.far = true, true
	for _, fn in ipairs(hooks.enter) do fn(run, "victim") end
	run_for(1.0)
	eq(victim.hits, 0, "M nothing before the ring has run")
	run_for(1.0)
	eq(victim.hits, 1, "M the hit after 1.5 s")
	eq(10000 - victim.hp, math.floor(0.45 * 2696 + 0.5), "M 45 % of the level 60 pool")
	eq(far.hits, 0, "M nobody far away")
	eq(marks[key(trap.cell)], "grug_expeditions:trap_mark", "M its mark")
	end_run(run)
	-- The lake: nobody waiting on a top or a landing is hit, at its middle or at its edge
	-- (0.29 over it, the sneak's limit), over two periods of both groups; a player in a
	-- gap's middle, on the line, is. A hit bursts on its player and reaches whoever stands
	-- within 2 of it (traps.lua): so the plan's "cross separately".
	local lines_hit = {}
	for attempt = 1, 40 do
		run = new_run(60)
		chosen = TR.chosen(run)
		local waiting = {}
		for i, top in ipairs(TOPS) do
			for _, z in ipairs({(top[2] + top[4] - 1) / 2, top[2] - 0.5 + 0.29, top[4] - 0.5 - 0.29}) do
				for _, x in ipairs({106, 109.5}) do
					local p = new_player(("w%d_%g_%g"):format(i, x, z), x, F - 0.5, z)
					run.inside[p.name] = true
					waiting[#waiting + 1] = p
				end
			end
		end
		for _, fn in ipairs(hooks.enter) do fn(run, waiting[1].name) end
		local launched = #objects
		run_for(12.5)
		check(#objects - launched >= 4, "M both groups fired twice over the waiting")
		for _, p in ipairs(waiting) do eq(p.hits, 0, "M nobody waiting on a top is hit: " .. p.name) end
		for name in pairs(run.inside) do run.inside[name], players[name] = nil, nil end
		local line = chosen.wall[1 + attempt % 2]
		local jumper = new_player("jumper", 107.5, F - 0.5 + 0.6, line.muzzle.z - MINP.z)
		run.inside.jumper = true
		run_for(6.5)
		check(jumper.hits >= 1, "M a player on the line is hit")
		lines_hit[key(line.muzzle)] = true
		end_run(run)
	end
	local covered = 0
	for _ in pairs(lines_hit) do covered = covered + 1 end
	eq(covered, 4, "M every shot line was tried")
	_G.core, _G.grug_core, _G.grug_expeditions, _G.vector = nil
end

-- ---- N. Lava: five ticks kill; Return Home refused in it inside an Expedition only -----
do
	_G.core = {register_globalstep = function() end,
		get_item_group = function(name, group)
			return group == "lava" and (name == LAVA or name == "default:lava_flowing") and 3 or 0
		end}
	_G.grug_core = {}
	dofile(repo .. "/mods/CORE/grug_core/environment_damage.lua")
	local reason = {type = "node_damage", from = "engine", node = LAVA}
	check(grug_core.is_engine_lava_damage(reason), "N the engine's lava tick")
	check(grug_core.bypasses_absorb(reason), "N no shield soaks it")
	for _, hp in ipairs({2696, 3000, 4100, 5300}) do
		local tick = grug_core.lava_damage(hp)
		check(5 * tick >= hp and 4 * tick < hp, ("N five ticks kill a full %d"):format(hp))
	end
	-- The central modifier replaces the flat damage with that share (combat.lua).
	local combat = read_file("mods/CORE/grug_core/combat.lua")
	check(combat:find("if grug_core.is_engine_lava_damage(reason) then", 1, true) and
		combat:find("hp_change = -grug_core.lava_damage(max_hp)", 1, true), "N combat.lua takes the share")
	check(read_file("mods/BASE/default/nodes.lua"):match('"default:lava_source".-damage_per_second = 4 %* 2'),
		"N the template's lava ticks")
end
do
	local minp = C.slot_box(1)
	local chat, combat, cooling = {}, false, true
	local function node_name(pos)
		local slot = C.slot_at(pos)
		if slot then
			local x, y, z = pos.x - minp.x, pos.y - minp.y, pos.z - minp.z
			return slot == 1 and inside(x, y, z) and name_at(x, y, z) or "default:stone"
		end
		-- the map: a lava pool below y 1
		return pos.y <= 0 and LAVA or "air"
	end
	local hold
	_G.core = {get_node_or_nil = function(pos) return {name = node_name(pos)} end,
		registered_nodes = setmetatable({}, {__index = function(_, name) return {walkable = SOLID[name] == true} end}),
		get_item_group = function(name, group) return group == "lava" and name == LAVA and 3 or 0 end,
		chat_send_player = function(_, text) chat[#chat + 1] = text end,
		register_on_joinplayer = function() end, register_on_leaveplayer = function() end,
		register_on_dieplayer = function() end}
	_G.grug_home = {get = function() return {id = "inn", pos = {x = 0, y = 10, z = 0}} end}
	_G.grug_core = {in_combat = function() return combat end, release_movement = function() end,
		register_world_exception = function() end, register_lava_hold = function(fn) hold = fn end}
	_G.grug_mounts = {register_summon_guard = function() end}
	_G.grug_mobs = {set_spawn_free_field = function() end}
	dofile(repo .. "/mods/PLAYER/grug_home/travel.lua")
	_G.grug_expeditions = {slot_box = C.slot_box, slot_at = C.slot_at, catalogue = C}
	dofile(repo .. "/mods/PLAYER/grug_expeditions/guard.lua")
	-- The lava hold covers every box and nothing of the map.
	check(hold and hold({x = minp.x + 100, y = minp.y + 5, z = minp.z + 60}), "N the box's lava is held")
	local _, last = C.slot_box(C.SLOTS)
	check(hold({x = last.x, y = last.y, z = last.z}), "N the last box's too")
	check(not hold({x = 0, y = 0, z = 0}), "N the map's lava is not")
	local function at_pos(x, y, z, on_map)
		local pos = on_map and {x = x, y = y, z = z} or {x = minp.x + x, y = minp.y + y, z = minp.z + z}
		return {get_player_name = function() return "ann" end, get_hp = function() return 100 end,
			get_pos = function() return pos end,
			get_meta = function()
				return {get_string = function() return cooling and tostring(os.time() + 600) or "" end}
			end}
	end
	local REFUSED, PASSED = "Cannot return home from the lava.", "Return home is cooling down."
	local function asks(label, want, ...)
		chat = {}
		check(grug_home.return_home(at_pos(...)) == false, label .. ": no trip in this test")
		eq(chat[1], want, label)
	end
	asks("N in the lake's lava", REFUSED, 100.5, 5.2, 60)
	asks("N falling into it", REFUSED, 107.5, 20, 68.5)
	asks("N jumping over a gap", REFUSED, 107.5, 32.2, 62.5)
	asks("N standing on a pillar", PASSED, 107.5, 31.5, 72)
	asks("N at a pillar's edge, the centre over the gap", PASSED, 107.5, 31.5, 69.25)
	asks("N on a landing", PASSED, 100, 31.5, 78)
	asks("N in a room", PASSED, places.arrival.x, F - 0.5, places.arrival.z)
	asks("N lava outside an Expedition", PASSED, 0.5, -2, 0.5, true)
	combat = true
	asks("N combat first", "Cannot return home in combat.", 100.5, 5.2, 60)
	combat = false
	_G.core, _G.grug_home, _G.grug_core, _G.grug_mounts, _G.grug_mobs, _G.grug_expeditions = nil
end

-- ---- O. The lava guard (grug_core/lava_guard.lua) -----------------------------------------
do
	local minp = C.slot_box(1)
	local box = {x = minp.x + 100, y = minp.y + 8, z = minp.z + 60}
	local outside = {x = 0, y = -10, z = 0}
	local loaded, transformed, swaps, nodes = {}, {}, {}, {}
	local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
	local torch_flooded = 0
	_G.core = {
		registered_nodes = {
			air = {},
			[LAVA] = {groups = {lava = 3, liquid = 2}, liquidtype = "source"},
			["default:lava_flowing"] = {groups = {lava = 3, liquid = 2}, liquidtype = "flowing"},
			["default:water_flowing"] = {groups = {water = 3}, liquidtype = "flowing"},
			["grug_core:water_barrier"] = {floodable = true},
			["default:torch_wall"] = {floodable = true,
				on_flood = function() torch_flooded = torch_flooded + 1 return false end},
		},
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		register_on_liquid_transformed = function(fn) transformed[#transformed + 1] = fn end,
		override_item = function(name, fields)
			for k, v in pairs(fields) do core.registered_nodes[name][k] = v end
		end,
		get_node_or_nil = function(pos) return {name = nodes[key(pos)] or "air"} end,
		swap_node = function(pos, node) swaps[#swaps + 1] = {pos = pos, name = node.name}; nodes[key(pos)] = node.name end,
	}
	_G.grug_core = {WATER_BARRIER = "grug_core:water_barrier"}
	dofile(repo .. "/mods/CORE/grug_core/lava_guard.lua")
	grug_core.register_lava_hold(function(pos) return C.slot_at(pos) ~= nil end)
	for _, fn in ipairs(loaded) do fn() end
	local flood = core.registered_nodes["default:torch_wall"].on_flood
	check(flood(box, {name = "default:torch_wall"}, {name = "default:lava_flowing"}) == true and torch_flooded == 0,
		"O no lava floods a torch in a box")
	check(flood(outside, {name = "default:torch_wall"}, {name = "default:lava_flowing"}) == false and torch_flooded == 1,
		"O the map's lava floods as before")
	check(flood(box, {name = "default:torch_wall"}, {name = "default:water_flowing"}) == false and torch_flooded == 2,
		"O water is the water guard's")
	check(core.registered_nodes["grug_core:water_barrier"].on_flood(box, {name = "grug_core:water_barrier"},
		{name = LAVA}) == true, "O the barrier refuses lava in a box")
	local function transform(pos, now, old)
		nodes[key(pos)] = now
		swaps = {}
		for _, fn in ipairs(transformed) do fn({pos}, {{name = old}}) end
		return nodes[key(pos)], #swaps
	end
	local now, n = transform(box, "default:lava_flowing", "air")
	check(now == "grug_core:water_barrier" and n == 1, "O lava flowing into air in a box: set back, a barrier")
	now, n = transform(box, "air", LAVA)
	check(now == LAVA and n == 1, "O lava leaving its place in a box: put back")
	now, n = transform(outside, "default:lava_flowing", "air")
	check(now == "default:lava_flowing" and n == 0, "O the map's lava flows")
	now, n = transform(box, "default:water_flowing", "air")
	check(now == "default:water_flowing" and n == 0, "O water is the water guard's")
	_G.core, _G.grug_core = nil
end

-- ---- P. Duewarden, the names, the quest ----------------------------------------------------
local land_guard = read_file("mods/ENTITIES/grug_mobs/land_guard.lua")
check(land_guard:find('register_mob("grug_mobs:duewarden", duewarden)', 1, true), "P Duewarden is registered")
check(land_guard:find("local duewarden = table.copy(guard)", 1, true), "P on the Sentinel's body")
check(land_guard:find("duewarden.drops = {}", 1, true) and land_guard:find("duewarden.walk_chance = 0", 1, true),
	"P he drops nothing and stands")
local HP_SCALE = tonumber(land_guard:match("duewarden%._grug_hp_scale = (%d+)"))
eq(HP_SCALE, 14, "P his HP: fourteen elites' (balance.py)")
check(read_file("mods/ENTITIES/grug_mobs/disposition.lua"):find('classify("aggressive", {"duewarden"})', 1, true),
	"P aggressive")
check(read_file("mods/PLAYER/grug_achievements/creatures.lua"):find('"duewarden",', 1, true), "P one of the others")
local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")
local names_text = read_file("mods/ENTITIES/grug_mobs/data/names.json")
check(names_text:find('"world/duewarden/L60-69": "Duewarden"', 1, true), "P his name's slot")
local NC = dofile(repo .. "/mods/ENTITIES/grug_mobs/names_core.lua")
local index = NC.build(json.decode(names_text).names)
for level = row.level, row.max_level do
	eq(NC.lookup(index, "duewarden", nil, level), "Duewarden", "P Duewarden at " .. level)
	eq(NC.lookup(index, "lava_flan", nil, level), "Lava Seep", "P a Seep at " .. level)
	eq(NC.lookup(index, "ember_wisp", nil, level), "Ember Wisp", "P a Wisp at " .. level)
	eq(NC.lookup(index, "land_guard", nil, level), "Bedrock Sentinel", "P a Sentinel at " .. level)
end
eq(NC.lookup(index, "duewarden", nil, nil), "Duewarden", "P the kill objective's one name")
-- The quest: the Seam's shape at 60, the four approved texts.
local home = json.decode(read_file("mods/PLAYER/grug_quests/data/zones/elandor_highcourt.quests.json"))
local quest
for _, q in ipairs(home.quests) do
	if q.id == "capital_last_mint" then quest = q end
end
check(quest ~= nil, "P the quest lives in its first variant's file")
eq(quest.title, "Party: The Last Mint", "P the title")
eq(quest.level, 60, "P level 60, open from 58")
eq(quest.line, "guild", "P the guild leaders' line")
check(quest.optional == true and quest.group == true, "P optional, a group quest")
eq(quest.story, nil, "P no story flag")
eq(#quest.requires, 0, "P it requires nothing")
eq(quest.rewards.weight, 4, "P weight 4")
eq(quest.rewards.items, nil, "P no item")
eq(quest.rewards.reputation, nil, "P no reputation")
eq(#quest.objectives, 1, "P one objective")
eq(quest.objectives[1].type, "kill", "P a kill")
eq(quest.objectives[1].roles[1], "duewarden", "P Duewarden")
eq(quest.objectives[1].count, 1, "P once")
eq(quest.objectives[1].area, nil, "P at any level, in no area")
local doc = read_file("docs/planning/round72-last-mint.md")
local function approved(head)
	local at_head = assert(doc:find("**" .. head .. "**", 1, true), head)
	return doc:match("\n> ([^\n]+)\n", at_head)
end
local TEXTS = {accord = {approved("The Accord \226\128\148 offer"), approved("The Accord \226\128\148 completion")},
	throng = {approved("The Throng \226\128\148 offer"), approved("The Throng \226\128\148 completion")}}
local VARIANTS = {
	{"elandor_highcourt", "highcourt", "accord"}, {"elandor_dur_brannoc", "dur_brannoc", "accord"},
	{"elandor_lethariel", "lethariel", "accord"}, {"kragmar_gor_drazhak", "gor_drazhak", "throng"},
	{"kragmar_kezamba", "kezamba", "throng"}, {"kragmar_nhal_veyr", "nhal_veyr", "throng"},
}
eq(#quest.variants, #VARIANTS, "P six variants")
for i, want in ipairs(VARIANTS) do
	local v = quest.variants[i]
	eq(v.zone, want[1], "P variant " .. i)
	eq(v.givers[1], "r58_guild_leader_" .. want[2], "P the leader of " .. want[2])
	eq(v.turnins, nil, "P turned in at the giver")
	eq(v.text, TEXTS[want[3]][1], "P the offer in " .. want[2])
	eq(v.completion, TEXTS[want[3]][2], "P the completion in " .. want[2])
end
-- The giver names the plan gives are the guild leaders'.
local npcs = read_file("mods/PLAYER/grug_quests/npcs.lua")
for _, title in ipairs({"Alis Cartwright", "Hadrin Beamset", "Caelir Veinward", "Drava Flintshoulder",
		"Iven Lastshift", "Ombali Ropekeeper"}) do
	check(npcs:find('title = "' .. title .. '"', 1, true), "P a guild leader: " .. title)
end
eq(tonumber(read_file("mods/PLAYER/grug_quests/validate.lua"):match("V%.EXPEDITION_TARGETS%.duewarden = (%d+)")),
	row.level, "P the game's validator")
eq(tonumber(read_file("tools/r28_design/validate.py"):match('EXPEDITION_TARGETS%["duewarden"%] = (%d+)')),
	row.level, "P the design validator")
check(read_file("tools/r60_capitals/build_structure.py"):find('"id": "capital_last_mint"', 1, true), "P the builder's row")

print(("R72 MINT PORTABLE PASS checks=%d"):format(checks))
