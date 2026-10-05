-- Round 36 lane W portable test (the decor pass, round36-plan.md §2.11):
--   A. benches: in every start and capital (core and every plot) no stair
--      seat looks along its own bench -- a seat with a same-facing neighbour
--      along its facing axis must belong to a bench running across it;
--   B. every Round 20 POI builds and passes `r7_settlement.prepare` with its
--      catalogue footprint (width x height) and its sockets (the quest host
--      exactly where `host` says);
--   C. the rift site keeps its crack: every crack cell (rift_core) is the
--      composition's own ground at y = 0 with air above it;
--   D. the decor kit: every piece builds in every race on open ground, and a
--      house's touches never take a blocked cell, a path or the cells in
--      front of its door.
--
-- Usage (repo root): luajit tools/r36_w/portable_test.lua [REPO]
local repo = arg[1] or "."
_G.core = _G.core or {}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local palettes = dofile(wp13 .. "/palette.lua")
local parts = dofile(wp13 .. "/parts.lua")
local RACES = {"dwarf", "human", "elf", "undead", "orc", "troll"}

-- A. benches -------------------------------------------------------------
local seats = {}
for _, race in ipairs(RACES) do seats[palettes.new(race).node("seat")] = true end
local function benches(label, bp)
	local by = {}
	local function key(x, y, z) return x .. "," .. y .. "," .. z end
	for _, c in ipairs(bp.cells) do by[key(c.x, c.y, c.z)] = c end
	local function seat_at(x, y, z, face)
		local c = by[key(x, y, z)]
		return c ~= nil and seats[c.name] and (c.param2 or 0) < 4 and
			((c.param2 or 0) + 2) % 4 == face
	end
	local function across(c, face)
		local rx, rz = parts.facedir_step(face + 1)
		return seat_at(c.x + rx, c.y, c.z + rz, face) or seat_at(c.x - rx, c.y, c.z - rz, face)
	end
	for _, c in ipairs(bp.cells) do
		if seats[c.name] and (c.param2 or 0) < 4 then
			local face = ((c.param2 or 0) + 2) % 4
			local fx, fz = parts.facedir_step(face)
			for _, sgn in ipairs({1, -1}) do
				if seat_at(c.x + fx * sgn, c.y, c.z + fz * sgn, face) and not across(c, face) and
						not across({x = c.x + fx * sgn, y = c.y, z = c.z + fz * sgn}, face) then
					check(false, label .. ": seat at " .. c.x .. "," .. c.y .. "," .. c.z ..
						" looks along its bench")
				end
			end
		end
	end
	checks = checks + 1
end
for _, name in ipairs({"dawnmere", "hearthpine", "kapok", "silverleaf", "stillgrave", "sunscar"}) do
	local bp = dofile(wp40 .. "/r7_" .. name .. "_blueprint.lua")
	if type(bp) == "function" then bp = bp() end
	benches(name, bp)
end
local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak", "kezamba"}) do
	local kit = capital.kit(key)
	benches(key .. " core", kit.core.build())
	for _, plot in ipairs(kit.plots) do benches(key .. " " .. plot.id, plot.build()) end
end

-- B. every Round 20 POI ----------------------------------------------------
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local sha = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local options = {raw_sha256 = sha, full_seed = "42"}
local built = {}
for _, profile in ipairs(settlement.roster) do
	if profile.blueprint_file == "r20_poi_blueprint.lua" then
		local art = profile.art
		local bp = dofile(wp40 .. "/" .. profile.blueprint_file)(options, profile)
		local ok, err = pcall(settlement.prepare, profile, bp, sha)
		check(ok, profile.key .. ": prepare: " .. tostring(err))
		if art.kind ~= "dragon" then
			local lo, hi = -art.width / 2, art.width / 2 - 1
			check(bp.bounds.min.x == lo and bp.bounds.max.x == hi and bp.bounds.min.z == lo and
				bp.bounds.max.z == hi and bp.bounds.min.y == 0 and bp.bounds.max.y == art.height,
				profile.key .. ": footprint")
		end
		local sockets = bp.landmarks.sockets
		if art.host then
			check(#sockets == 1 and sockets[1].id == "quest_host" and sockets[1].x == 2 and
				sockets[1].y == 1 and sockets[1].z == 0, profile.key .. ": quest host socket")
		else
			check(#sockets == 0, profile.key .. ": no sockets")
		end
		built[profile.key] = {bp = bp, art = art}
	end
end
check(built.r20_anchor_016 and built.r20_anchor_089, "Round 20 POIs found")

-- C. the rift site's crack -------------------------------------------------
local rift = dofile(repo .. "/mods/ENTITIES/grug_mobs/rift_core.lua")
local site = built[rift.SITE]
check(site ~= nil, "rift site built")
do
	local by = {}
	for _, c in ipairs(site.bp.cells) do by[c.x .. "," .. c.y .. "," .. c.z] = c.name end
	local ground
	local cells = rift.crack_cells(site.art, rift.CANDIDATES[rift.SITE])
	check(#cells > 0, "crack has cells")
	for _, cell in ipairs(cells) do
		local floor = by[cell[1] .. ",0," .. cell[2]]
		ground = ground or floor
		check(floor ~= nil and floor == ground, "crack floor at " .. cell[1] .. "," .. cell[2])
		for y = 1, 3 do
			check(by[cell[1] .. "," .. y .. "," .. cell[2]] == "air",
				"nothing stands on the crack at " .. cell[1] .. "," .. cell[2])
		end
	end
end

-- D. the decor kit -------------------------------------------------------
local decor = dofile(wp13 .. "/decor_kit.lua")(wp13)
for _, race in ipairs(RACES) do
	local p = palettes.new(race)
	for kind in pairs(decor.PIECES) do
		for face = 0, 3 do
			-- the plain builders' view (a WP13 buffer refuses a lying log)
			local cells = {}
			local buf = decor.view(function(x, y, z, name, param2)
				cells[x .. "," .. y .. "," .. z] = {x = x, y = y, z = z, name = name, param2 = param2}
			end, function(x, y, z) return cells[x .. "," .. y .. "," .. z] end)
			buf:fill(-8, 0, -8, 8, 0, 8, p.node("ground"))
			local brush = decor.brush(buf, race, p)
			local ok, err = pcall(decor.piece, brush, kind, 0, 0, face)
			check(ok, race .. " " .. kind .. " face " .. face .. ": " .. tostring(err))
		end
	end
end
do
	-- A 5 x 3 room (walls x -3..3, z -2..2) with a door at (0, -2), a window
	-- in each long wall, a path along x = 4, a blocked cell at (-4, 0).
	local p = palettes.new("human")
	local buf = parts.buffer()
	buf:fill(-8, 0, -8, 8, 0, 8, p.node("ground"))
	buf:fill(4, 0, -8, 4, 0, 8, p.node("path"))
	buf:ring(-3, -2, 3, 2, 1, 3, p.node("wall"))
	buf:put(0, 1, -2, "air"); buf:put(0, 2, -2, "air")
	buf:put(-1, 2, 2, "xpanes:pane_flat"); buf:put(1, 2, -2, "xpanes:pane_flat")
	local brush = decor.brush(buf, "human", p)
	local house = {room = {min = {x = -2, z = -1}, max = {x = 2, z = 1}}, doors = {{x = 0, z = -2}},
		floor_y = 0, ground_y = 0, seed = 4}
	local n = decor.dress_house(brush, house, {ground = decor.open_ground(p),
		blocked = {["-4:0"] = true}})
	check(n >= 3, "a house gets its touches (" .. n .. ")")
	for _, cell in ipairs(buf.order) do
		if cell.y >= 1 and cell.name ~= "air" and (cell.x < -3 or cell.x > 3 or cell.z < -2 or cell.z > 2) then
			check(not (cell.x == -4 and cell.z == 0), "blocked cell stays free")
			check(cell.x ~= 4, "nothing on the path")
			check(not (cell.x == 0 and (cell.z == -3 or cell.z == -4)), "door approach stays free")
		end
	end
	check(#brush.lights == 1, "one door torch")
end

print(("r36_w portable test: %d checks passed"):format(checks))
