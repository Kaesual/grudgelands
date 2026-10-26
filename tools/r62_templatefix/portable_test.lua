-- Round 62 lane TEMPLATEFIX portable test (LuaJIT; round62-plan.md §2
-- point 10). The building-template defects fixed before the deploy's map
-- reset, and the unreachable points `check.py` still warns about, walked in
-- the towns the game's own loader and compositions build:
--
--   K  Kezamba's moot house: the right-hinged leaf of its double door has
--      its upper cell (it had a window, wood bars), and the moot house's inside
--      point (the city's `moot_house` destination) is reached from the porch;
--   M  both Lethariel mere shrines: the inside point is a standing point on
--      the shrine's floor (it was the floor block), reached from the box edge
--      in the template and from the street in the core;
--   P  Sunscar's warlord platform: `check.py` cannot reach it inside the
--      template, the town's outer stair (sunscar.lua step 5, written after
--      the stamp) reaches it from the street;
--   G  the five core gatehouses' passage posts: `check.py` starts only at
--      the chamber doors, the passage is open from the template's box edge
--      and from the city side, and no core keeps the posts as sockets
--      (gate_watch.lua drops them).
--
-- The player model and its walker are tools/r58_townfix's, loaded from that
-- fixture's own text (everything before its section B), so both fixtures
-- walk with one model.
--
-- Usage (repo root): luajit tools/r62_templatefix/portable_test.lua [REPO]
-- Prints "R62 TEMPLATEFIX PORTABLE PASS checks=<n>" or the failures.

local repo = arg and arg[1] or "."
local EPS = 1e-6

local file = assert(io.open(repo .. "/tools/r58_townfix/portable_test.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = source:find("\n%-%-+\n%-%- B%. Lethariel's bough platforms%.")
assert(cut, "tools/r58_townfix/portable_test.lua: its section B marker moved")
local chunk = assert(loadstring(source:sub(1, cut) .. [[
return {check = check, map_of = map_of, walker = walker, stand = stand,
	part_cells = part_cells, library = library, wp40 = wp40,
	counts = function() return checks, failures end}
]], "r58_townfix player model"))
-- the chunk reads the repository path from this fixture's own `arg`
local T = chunk()
local check = T.check

local function at_feet(x, y, z)
	return function(st)
		return st.x == x and st.z == z and math.abs(st.s - (y - 0.5)) < EPS
	end
end
local function sockets_of(bp)
	local by = {}
	for _, socket in ipairs(bp.landmarks.sockets) do by[socket.id] = socket end
	return by
end
local function destination(bp, id)
	for _, spot in ipairs(bp.landmarks.destinations or {}) do
		if spot.id == id then return spot end
	end
end
local function cell_at(at, x, y, z)
	return at[x .. ":" .. y .. ":" .. z] or {name = "air", param2 = 0}
end

------------------------------------------------------------------------------
-- K. Kezamba's moot house.
------------------------------------------------------------------------------
do
	local at = T.part_cells("kezamba", "kezamba_moot_house", "moot_house", "basalt")
	local leaf, top = cell_at(at, 4, 5, 6), cell_at(at, 4, 6, 6)
	check(leaf.name:match("^doors:.*_b$") ~= nil and (leaf.param2 or 0) == 2,
		"K the moot house's right-hinged leaf at (4,5,6), facedir 2 (" .. leaf.name .. ")")
	check(top.name == "doors:hidden" and (top.param2 or 0) == 1,
		"K its upper cell is the door's hidden node at facedir 1 (parts.door), not a window (" ..
			top.name .. ")")
	local bp = T.library.composition("kezamba").core()
	local porch, spot = sockets_of(bp).moot_house_porch, destination(bp, "moot_house")
	if check(porch ~= nil and spot ~= nil, "K the core has the moot house's porch and destination") then
		local walk = T.walker(T.map_of(bp.cells))
		check(walk.search(T.stand(porch.x, porch.y, porch.z), at_feet(spot.x, spot.y, spot.z),
			false) ~= nil, "K from the porch through the door to the moot house's inside point")
	end
end

------------------------------------------------------------------------------
-- M. The Lethariel mere shrines.
------------------------------------------------------------------------------
for _, case in ipairs({{"lethariel_mere_shrine", "pale"}, {"lethariel_plot_mere_shrine", "elf"}}) do
	local name = case[1]
	local at, part = T.part_cells("lethariel", name, "mere_shrine", case[2])
	local spot = part.points.inside[1]
	check(spot.x == 4 and spot.y == 2 and spot.z == 3, "M " .. name .. ": the inside point at (4,2,3)")
	check(T.walker(at).search(T.stand(0, 1, 0), at_feet(spot.x, spot.y, spot.z), false) ~= nil,
		"M " .. name .. ": from the box edge up the treads to the inside point")
end
do
	-- the core's shrine at x 16, z 12, turns 0 (lethariel.lua), walked from
	-- the street south of it
	local _, part = T.part_cells("lethariel", "lethariel_mere_shrine", "mere_shrine", "pale")
	local spot = part.points.inside[1]
	local bp = T.library.composition("lethariel").core()
	check(T.walker(T.map_of(bp.cells)).search(T.stand(20, 1, 10),
		at_feet(16 + spot.x, spot.y, 12 + spot.z), false) ~= nil,
		"M the core's mere shrine: from the street to the inside point")
end

------------------------------------------------------------------------------
-- P. Sunscar's warlord platform.
------------------------------------------------------------------------------
do
	local settlement = dofile(T.wp40 .. "/r7_settlement.lua")
	local bp
	for _, profile in ipairs(settlement.roster) do
		if profile.key == "sunscar" then bp = dofile(T.wp40 .. "/" .. profile.blueprint_file)() end
	end
	local spot = bp and destination(bp, "warlord_platform")
	if check(spot ~= nil, "P Sunscar has the warlord_platform destination") then
		-- the hall's door at template (7,1,0), placed at x -7, z 14: the
		-- street in front of it is (0,1,12)
		local path = T.walker(T.map_of(bp.cells)).search(T.stand(0, 1, 12),
			at_feet(spot.x, spot.y, spot.z), false)
		local by_stair = false
		for _, st in ipairs(path or {}) do
			if st.x == 8 and st.z >= 16 and st.z <= 23 and st.s > 1 then by_stair = true end
		end
		check(path ~= nil and by_stair,
			"P from the street up the town's outer stair (x 8, z 16..23) to the platform")
	end
end

------------------------------------------------------------------------------
-- G. The core gatehouses' passage posts.
------------------------------------------------------------------------------
local GATES = {
	{"highcourt", "white", "white_slate"}, {"lethariel", "pale", "pale"},
	{"dur_brannoc", nil, "slate"}, {"nhal_veyr", "crypt", "crypt_vault"},
	{"gor_drazhak", "ors", nil},
}
local POSTS = {{4, 1, 1, "post_west"}, {8, 1, 1, "post_east"}}
for _, gate in ipairs(GATES) do
	local capital = gate[1]
	local label = "G " .. capital .. "_gate_south"
	local at = T.part_cells(capital, capital .. "_gate_south", "gate_south", gate[2], gate[3])
	local walk = T.walker(at)
	for _, post in ipairs(POSTS) do
		-- the passage's field mouth (z 0) and its city mouth (z 6) on the box edge
		for _, mouth in ipairs({0, 6}) do
			check(walk.search(T.stand(post[1], 1, mouth), at_feet(post[1], post[2], post[3]),
				false) ~= nil, label .. ": " .. post[4] .. " reached from the passage mouth at z " .. mouth)
		end
	end
	local bp = T.library.composition(capital).core()
	local by = sockets_of(bp)
	check(not by.gate_south_post_west and not by.gate_south_post_east,
		label .. ": the core keeps no passage post as a socket")
	local corner, deck = by.gate_south_watch_west_1, by.gate_south_deck
	if check(corner ~= nil and deck ~= nil, label .. ": the watch corner and the deck post") then
		-- the template's deck at (6,12,3) and the gate at turns 0 give the
		-- placement's origin
		local ox, oz = deck.x - 6, deck.z - 3
		local core_walk = T.walker(T.map_of(bp.cells))
		for _, post in ipairs(POSTS) do
			check(core_walk.search(T.stand(corner.x, corner.y, corner.z),
				at_feet(ox + post[1], post[2], oz + post[3]), false) ~= nil,
				label .. ": the " .. post[4] .. " cell reached from the city side in the core")
		end
	end
end

local checks, failures = T.counts()
print(("R62 TEMPLATEFIX portable test: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R62 TEMPLATEFIX PORTABLE FAIL", 0) end
print("R62 TEMPLATEFIX PORTABLE PASS checks=" .. checks)
