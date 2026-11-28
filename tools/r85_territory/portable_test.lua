-- Round 85 lane TERRITORY portable test (LuaJIT): the arena "Breach Road" as
-- a place of the game, on its real layout (`wp40/breach_layout.lua`) at a
-- constructed site, with the shipped pure files.
--
--   luajit tools/r85_territory/portable_test.lua [REPO]
--
-- T  territory (grug_pvp/rules.lua R.hall_at, R.zone_answers, on every
--    friendly box of the halls as grug_pvp lists them): every node of
--    each hall's interior box answers the hall's faction, also from a
--    player's float position (feet on the floor, jumping, touching a wall);
--    the node beyond each face of the box (the sills and doorways, the roof,
--    the floor, the side walls) and the courts, the field and the road
--    answer the zone (contested); in the own hall the location flag clears
--    (R.location), in the enemy hall it is "enemy"; after a fight the contact
--    keeps the player flagged for 60 s inside the own hall, a press of the
--    button too, and a player without either is safe (R.flagged); a player
--    without a faction has no territory.
-- P  protection (world_protection.lua arena_box in the index): every corner
--    and the centre of the protected box answer "arena", the node beyond
--    each face nil; the box's bounds are the footprint's from 10 under the
--    datum to 35 over it; the claim scan meets it.
-- S  spawns (spawn_regions_core.lua reserved_of, cell_reserved): the
--    reserved rectangle is the layout's fringe; a cell is reserved
--    exactly when it meets the fringe rectangle (the edges' cells on both
--    sides), never without a rectangle; the fringe holds the footprint.
-- Prints "R85 TERRITORY PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local L = dofile(wp40 .. "/breach_layout.lua")
local R = dofile(repo .. "/mods/PLAYER/grug_pvp/rules.lua")
local site = {x = -72, z = 8, y = 23, reach = 29}
local W = L.world(site)

-- ---------------------------------------------------------------------------
-- T: territory
-- ---------------------------------------------------------------------------
-- The territory list as grug_pvp builds it (Round 89: every friendly box of
-- a hall, its interior, upper stair and balcony, tools/r89_halls checks the
-- two new ones); the checks below are the interiors'.
local halls, interiors = {}, {}
for _, faction in ipairs({"accord", "throng"}) do
	local box = W.halls[faction].interior
	interiors[#interiors + 1] = {faction = faction, min = box.min, max = box.max}
	for _, b in ipairs(W.halls[faction].friendly) do
		halls[#halls + 1] = {faction = faction, min = b.min, max = b.max}
	end
end
-- The Battlegrounds: contested everywhere (no faction owns the column).
local zones = {
	pvp_rule_at = function() return "contested" end,
	faction_at = function() return nil end,
}
local function answer(pos, own)
	local rule, here = R.zone_answers(zones, halls, pos)
	return R.territory(rule, here, own)
end
for _, hall in ipairs(interiors) do
	local other = hall.faction == "accord" and "throng" or "accord"
	local lo, hi, inside = hall.min, hall.max, 0
	for x = lo.x, hi.x do
		for y = lo.y, hi.y do
			for z = lo.z, hi.z do
				local pos = {x = x, y = y, z = z}
				if R.hall_at(halls, pos) == hall.faction and answer(pos, hall.faction) == "friendly" and
						answer(pos, other) == "enemy" then
					inside = inside + 1
				end
			end
		end
	end
	check(inside == (hi.x - lo.x + 1) * (hi.y - lo.y + 1) * (hi.z - lo.z + 1),
		"T every node of the " .. hall.faction .. " hall's interior is its ground (" .. inside .. ")")
	-- the box: 11 wide (u 1..11), 29 deep (v -14..14), 7 high above the +6 floor
	check(hi.x - lo.x == 10 and hi.z - lo.z == 28 and lo.y == site.y + 7 and hi.y == site.y + 13,
		"T the " .. hall.faction .. " interior's size")
	local floor_y = W.halls[hall.faction].floor_y
	local cx, cz = (lo.x + hi.x) / 2, (lo.z + hi.z) / 2
	-- a player's feet on the floor's top (floor + 0.5), jumping, at a wall
	check(R.hall_at(halls, {x = cx, y = floor_y + 0.5, z = cz}) == hall.faction,
		"T feet on the " .. hall.faction .. " floor")
	check(R.hall_at(halls, {x = cx + 0.3, y = floor_y + 1.7, z = cz - 0.4}) == hall.faction,
		"T jumping in the " .. hall.faction .. " hall")
	check(R.hall_at(halls, {x = lo.x - 0.3, y = floor_y + 0.5, z = hi.z + 0.45}) == hall.faction,
		"T against the " .. hall.faction .. " hall's corner")
	-- beyond each face: the sills and doorways (x), the side walls (z), the
	-- roof (y above) and the floor (y below)
	local beyond = {
		{lo.x - 1, cz, floor_y + 1, "the outer sill"}, {hi.x + 1, cz, floor_y + 1, "the inner sill"},
		{cx, lo.z - 1, floor_y + 1, "the south wall"}, {cx, hi.z + 1, floor_y + 1, "the north wall"},
		{cx, cz, hi.y + 1, "the roof's underside node"}, {cx, cz, hi.y + 2.5, "standing on the roof"},
		{cx, cz, floor_y, "the floor node"},
	}
	for _, b in ipairs(beyond) do
		local pos = {x = b[1], y = b[3], z = b[2]}
		check(R.hall_at(halls, pos) == nil and answer(pos, hall.faction) == "contested" and
			answer(pos, other) == "contested", "T " .. b[4] .. " of the " .. hall.faction ..
			" hall is contested")
	end
	-- the location flag: a player coming in from the courts
	check(R.location("contested", "contested", nil, hall.faction) == "contested",
		"T the court flags")
	local rule, here = R.zone_answers(zones, halls, {x = cx, y = floor_y + 0.5, z = cz})
	check(rule == "peaceful" and here == hall.faction, "T the zone answer inside")
	check(R.location("contested", rule, here, hall.faction) == false,
		"T entering the own hall clears the location flag")
	check(R.location("contested", rule, here, other) == "enemy",
		"T the enemy hall flags (enemy territory)")
	check(R.location(false, rule, here, nil) == false, "T no faction keeps its value")
	-- ruling 11: exactly today's flag rules with the hall as own peaceful ground
	local now = 100000
	local calm = {loc = R.location("contested", rule, here, hall.faction), button_until = 0,
		contact_at = now - 61}
	check(not R.flagged(calm, now) and R.state(calm, now).flagged == false,
		"T no contact for 60 s: safe in the own hall at once")
	local fought = {loc = R.location("contested", rule, here, hall.faction), button_until = 0,
		contact_at = now - 20}
	local state = R.state(fought, now)
	check(R.flagged(fought, now) and state.reason == "contact" and state.seconds_left == 40,
		"T a fight 20 s ago: flagged 40 s more inside the own hall")
	local enemy = {loc = R.location("contested", rule, here, other), button_until = 0,
		contact_at = 0}
	check(R.can_harm(enemy, fought, now) and not R.can_harm(enemy, calm, now),
		"T an enemy inside can hit the fighter, not the calm defender")
	local pressed = {loc = false, button_until = now + 30, contact_at = 0}
	check(R.flagged(pressed, now) and R.state(pressed, now).reason == "button",
		"T the button keeps its 60 s inside the hall")
end
-- the courts, the galleries, the field and the road: contested for both
local open = 0
for lx = -L.HALF_X, L.HALF_X, 3 do
	for lz = -L.HALF_Z, L.HALF_Z, 3 do
		for _, ly in ipairs({1, 4, 7, 10, 14, 20}) do
			local pos = {x = site.x + lx, y = site.y + ly, z = site.z + lz}
			if not R.hall_at(halls, pos) then
				check(answer(pos, "accord") == "contested" and answer(pos, "throng") == "contested",
					"T contested at " .. lx .. "," .. ly .. "," .. lz)
				open = open + 1
			end
		end
	end
end
check(open > 4000, "T the open ground sampled (" .. open .. ")")
check(R.hall_at(nil, {x = 0, y = 0, z = 0}) == nil and R.hall_at(halls, nil) == nil,
	"T no halls, no position")
check(answer({x = W.halls.accord.muster.x, y = W.halls.accord.muster.y, z = W.halls.accord.muster.z},
	"accord") == "friendly" and answer({x = W.halls.throng.waystone.x, y = W.halls.throng.waystone.y,
	z = W.halls.throng.waystone.z}, "throng") == "friendly", "T the muster point and the waystone inside")
-- a peaceful zone round the arena would still answer by its owner outside
local peaceful = {pvp_rule_at = function() return "peaceful" end,
	faction_at = function() return "throng" end}
local rule, here = R.zone_answers(peaceful, halls, {x = site.x, y = site.y + 1, z = site.z})
check(rule == "peaceful" and here == "throng", "T outside the halls the zone answers")
rule, here = R.zone_answers(peaceful, halls, {x = W.halls.accord.muster.x,
	y = W.halls.accord.muster.y, z = W.halls.accord.muster.z})
check(here == "accord", "T inside a hall the hall answers before the zone")
check(R.territory(rule, here, nil) == nil, "T a player without a faction has no territory")

-- ---------------------------------------------------------------------------
-- P: protection
-- ---------------------------------------------------------------------------
local wp = dofile(wp40 .. "/world_protection.lua")
local box = wp.arena_box(W)
check(box.kind == "arena" and box.id == "breach_road", "P kind and id")
check(box.min_x == site.x - 49 and box.max_x == site.x + 49 and box.min_z == site.z - 45 and
	box.max_z == site.z + 45 and box.min_y == site.y - 10 and box.max_y == site.y + 35,
	"P the footprint's bounds, 10 under the datum to 35 over it")
local index = wp.new(dofile(wp40 .. "/index128.lua"), {boxes = {box}})
for _, x in ipairs({box.min_x, box.max_x, site.x}) do
	for _, y in ipairs({box.min_y, box.max_y, site.y}) do
		for _, z in ipairs({box.min_z, box.max_z, site.z}) do
			check(index.kind_at(x, y, z) == "arena", ("P arena at %d,%d,%d"):format(x, y, z))
		end
	end
end
for _, p in ipairs({{box.min_x - 1, site.y, site.z}, {box.max_x + 1, site.y, site.z},
		{site.x, box.min_y - 1, site.z}, {site.x, box.max_y + 1, site.z},
		{site.x, site.y, box.min_z - 1}, {site.x, site.y, box.max_z + 1}}) do
	check(index.kind_at(p[1], p[2], p[3]) == nil, ("P nothing at %d,%d,%d"):format(p[1], p[2], p[3]))
end
check(index.boxes_in(box.max_x + 1, site.z, box.max_x + 80, site.z, 0) == nil and
	index.boxes_in(box.max_x + 1, site.z, box.max_x + 80, site.z, 1) == "arena",
	"P the claim scan meets the box (with a margin)")
check(not pcall(wp.arena_box, {}), "P a broken layout fails")

-- ---------------------------------------------------------------------------
-- S: spawns
-- ---------------------------------------------------------------------------
local core_regions = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
local f = W.fringe
local rect = {min_x = f.min.x, max_x = f.max.x, min_z = f.min.z, max_z = f.max.z}
check(rect.min_x == site.x - 49 - site.reach and rect.max_z == site.z + 45 + site.reach,
	"S the fringe: the hull's bounds grown by the reach")
check(rect.min_x <= box.min_x and rect.max_x >= box.max_x and rect.min_z <= box.min_z and
	rect.max_z >= box.max_z, "S the fringe holds the footprint")
-- the one derivation the game and the tools share (fix round 1)
local shared = core_regions.reserved_of(W)
check(#shared == 1 and shared[1].min_x == rect.min_x and shared[1].max_x == rect.max_x and
	shared[1].min_z == rect.min_z and shared[1].max_z == rect.max_z and
	#core_regions.reserved_of(nil) == 0, "S reserved_of: the fringe, none without an arena")
local CELL = core_regions.CELL
local wrong = 0
for i = math.floor(rect.min_x / CELL) - 2, math.floor(rect.max_x / CELL) + 2 do
	for j = math.floor(rect.min_z / CELL) - 2, math.floor(rect.max_z / CELL) + 2 do
		local x0, z0 = i * CELL, j * CELL
		local meets = x0 + CELL - 1 >= rect.min_x and x0 <= rect.max_x and
			z0 + CELL - 1 >= rect.min_z and z0 <= rect.max_z
		if core_regions.cell_reserved(i, j, {rect}) ~= meets then wrong = wrong + 1 end
		if core_regions.cell_reserved(i, j, {}) or core_regions.cell_reserved(i, j, nil) then
			wrong = wrong + 1
		end
	end
end
check(wrong == 0, "S a cell is reserved exactly when it meets the fringe")
local edge_i, row_j = math.floor(rect.max_x / CELL), math.floor(site.z / CELL)
check(core_regions.cell_reserved(edge_i, row_j, {rect}) and
	not core_regions.cell_reserved(edge_i + 1, row_j, {rect}),
	"S the east edge: its own cell reserved, the next one not")

print(("R85 TERRITORY PORTABLE PASS checks=%d"):format(checks))
