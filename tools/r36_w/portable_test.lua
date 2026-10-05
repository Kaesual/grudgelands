-- Round 36 lane W portable test (the decor pass, round36-plan.md §2.11):
--   A. benches: in every start and capital (core and every plot) no stair
--      seat looks along its own bench -- a seat with a same-facing neighbour
--      along its facing axis must belong to a bench running across it;
--   B. every Round 14 and Round 20 POI builds and passes
--      `r7_settlement.prepare`; every POI, start, capital core and plot
--      keeps the bounds, cleared airspace and sockets main had before the
--      decor pass (tools/r36_w/baseline.tsv, from baseline.lua);
--   C. the four rift candidates keep their cracks (every crack cell is the
--      composition's own ground with air above it), Tombroad Ambush its four
--      prop rows, and every clash site the quest object's open square;
--   D. the decor kit: every piece builds in every race on open ground, and a
--      house's touches never take a blocked cell, a path or the cells in
--      front of its door;
--   E. over every POI, start, capital core and plot: no solid cell the kit
--      writes stands before or behind a window at the window's height, and
--      every closed room keeps two nodes of air over its walkable floor;
--   F. over the same: every place a player can walk to from the arrival
--      without the decor stays reachable with it, within a 6-step detour.
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

-- B. every POI builds and keeps its footprint and sockets ------------------
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local sha = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local options = {raw_sha256 = sha, full_seed = "42"}
local built = {}
for _, profile in ipairs(settlement.roster) do
	local file = profile.blueprint_file
	if file == "r20_poi_blueprint.lua" or (file:match("^r7_.*_blueprint%.lua$") and
			profile.slot ~= "capital" and profile.slot ~= "start") then
		local bp = dofile(wp40 .. "/" .. file)(options, profile)
		if type(bp) == "function" then bp = bp(options) end
		local ok, err = pcall(settlement.prepare, profile, bp, sha)
		check(ok, profile.key .. ": prepare: " .. tostring(err))
		built[profile.key] = {bp = bp, art = profile.art}
	end
end
check(built.r20_anchor_016 and built.r20_anchor_089 and built.goldmead_village, "POIs found")
-- Nothing the pass adds replaces a Round 14 house's frame: each house keeps
-- its four corner posts to its eaves (Round 36 review: a timber stack's cap
-- took Goldmead's granary corner).
for _, profile in ipairs(settlement.roster) do
	local file = profile.blueprint_file
	if file:match("^r7_.*_blueprint%.lua$") and profile.slot ~= "capital" and profile.slot ~= "start" then
		local bp = built[profile.key].bp
		local by = {}
		for _, c in ipairs(bp.cells) do by[c.x .. "," .. c.y .. "," .. c.z] = c.name end
		local post = palettes.new(profile.race).node("post")
		local raised = profile.race == "troll" and 1 or 0
		for _, s in ipairs(bp.landmarks.structures) do
			if s.interior and s.kind ~= "canopy" then
				local w, d = s.w, s.d
				if by[(s.x + w) .. "," .. (raised + 1) .. "," .. (s.z + d)] ~= post then w, d = d, w end
				for _, c in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
					for y = raised + 1, raised + s.h do
						local k = (s.x + c[1] * w) .. "," .. y .. "," .. (s.z + c[2] * d)
						check(by[k] == post, profile.key .. " " .. s.label .. ": corner post at " .. k ..
							" is " .. tostring(by[k]))
					end
				end
			end
		end
	end
end
do
	local now = dofile(repo .. "/tools/r36_w/baseline.lua")(repo)
	local f = assert(io.open(repo .. "/tools/r36_w/baseline.tsv", "rb"))
	local was = {}
	for l in f:lines() do was[#was + 1] = l end
	f:close()
	check(#now == #was, "baseline: " .. #now .. " compositions, " .. #was .. " recorded")
	for i = 1, #was do
		check(now[i] == was[i], "footprint and sockets unchanged: " .. tostring(was[i]):match("^[^\t]*"))
	end
end

-- C. the rift candidates' cracks and every clash site's quest spot --------
local rift = dofile(repo .. "/mods/ENTITIES/grug_mobs/rift_core.lua")
local function grid(bp)
	local by = {}
	for _, c in ipairs(bp.cells) do by[c.x .. "," .. c.y .. "," .. c.z] = c.name end
	return by
end
for key, waypoints in pairs(rift.CANDIDATES) do
	local site = built[key]
	check(site ~= nil, key .. " built")
	local by = grid(site.bp)
	local lo = -site.art.width / 2
	local ground = by[lo .. ",0," .. lo]
	local cells = rift.crack_cells(site.art, waypoints)
	check(#cells >= 20, key .. ": crack has its cells")
	for _, cell in ipairs(cells) do
		check(by[cell[1] .. ",0," .. cell[2]] == ground, key .. ": crack floor at " .. cell[1] .. "," .. cell[2])
		for y = 1, 3 do
			check(by[cell[1] .. "," .. y .. "," .. cell[2]] == "air",
				key .. ": nothing stands on the crack at " .. cell[1] .. "," .. cell[2])
		end
	end
end
-- Tombroad Ambush keeps its four prop rows where the crack plan has them.
do
	local props = built[rift.SITE].art.props
	local at = {}
	for _, q in ipairs(props) do at[#at + 1] = q[2] .. "," .. q[3] end
	check(table.concat(at, " ") == "4,-5 -5,5 -5,-2 4,4", "the rift site's four prop rows stay")
end
-- The quest object stands on the clash site's own ground within two nodes
-- of the anchor (grug_quests/use.lua RING): that square stays open floor.
for key, site in pairs(built) do
	if site.art and site.art.kind == "clash" then
		local by = grid(site.bp)
		local lo = -site.art.width / 2
		local ground = by[lo .. ",0," .. lo]
		for z = -2, 2 do for x = -2, 2 do
			check(by[x .. ",0," .. z] == ground, key .. ": quest spot floor at " .. x .. "," .. z)
			for y = 1, 3 do
				check(by[x .. "," .. y .. "," .. z] == "air", key .. ": quest spot open at " .. x .. "," .. z)
			end
		end end
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
			brush.display = "grug_mapgen:poi_display_" .. race
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

-- E. windows and headroom over every composition -------------------------
-- Every cell the decor kit writes (an authored piece or a house touch) is
-- recorded through its brush; no such cell that is not `decor.soft` may
-- stand directly before or behind a window at the window's height. And
-- every closed room keeps two nodes of air over its walkable floor.
do
	local real_dofile = dofile
	local written, bare
	local function recording(buf)
		local rec = {}
		function rec:put(x, y, z, name, param2)
			if written then written[#written + 1] = {x = x, y = y, z = z, name = name} end
			return buf:put(x, y, z, name, param2)
		end
		function rec:at(x, y, z) return buf:at(x, y, z) end
		function rec:fill(x1, y1, z1, x2, y2, z2, name, param2)
			for z = z1, z2 do for y = y1, y2 do for x = x1, x2 do self:put(x, y, z, name, param2) end end end
		end
		function rec:clear(x1, y1, z1, x2, y2, z2) self:fill(x1, y1, z1, x2, y2, z2, "air", 0) end
		return rec
	end
	dofile = function(path, ...)
		local result = real_dofile(path, ...)
		if type(path) == "string" and path:match("/decor_kit%.lua$") then
			local loader = result
			return function(dir)
				local M = loader(dir)
				local brush, place, dress_house = M.brush, M.place, M.dress_house
				M.brush = function(buf, race, palette, lights)
					return brush(recording(buf), race, palette, lights)
				end
				-- a bare build: the composition without any decor
				M.place = function(...) if not bare then return place(...) end end
				M.dress_house = function(...)
					if bare then return 0 end
					return dress_house(...)
				end
				return M
			end
		end
		return result
	end
	local comps = {}
	local function add(label, build)
		bare = true
		local before = build()
		bare = false
		written = {}
		local bp = build()
		comps[#comps + 1] = {label = label, bp = bp, before = before, written = written}
		written = nil
	end
	for _, profile in ipairs(settlement.roster) do
		local file = profile.blueprint_file
		if (file == "r20_poi_blueprint.lua" and profile.art.kind ~= "dragon") or
				(file:match("^r7_.*_blueprint%.lua$") and profile.slot ~= "capital" and
					profile.slot ~= "start") then
			add(profile.key, function()
				local bp = dofile(wp40 .. "/" .. file)(options, profile)
				if type(bp) == "function" then bp = bp(options) end
				return bp
			end)
		end
	end
	for _, name in ipairs({"dawnmere", "hearthpine", "kapok", "silverleaf", "stillgrave", "sunscar"}) do
		add(name, function()
			local bp = dofile(wp40 .. "/r7_" .. name .. "_blueprint.lua")
			if type(bp) == "function" then bp = bp() end
			return bp
		end)
	end
	local capital2 = dofile(wp40 .. "/r7_capital_blueprint.lua")
	for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak", "kezamba"}) do
		local kit = capital2.kit(key)
		add(key .. " core", kit.core.build)
		for _, plot in ipairs(kit.plots) do add(key .. " " .. plot.id, plot.build) end
	end
	dofile = real_dofile
	local decor_mod = decor
	local recorded = 0
	for _, c in ipairs(comps) do
		local by = {}
		for _, cell in ipairs(c.bp.cells) do by[cell.x .. "," .. cell.y .. "," .. cell.z] = cell.name end
		local view = {at = function(_, x, y, z)
			local n = by[x .. "," .. y .. "," .. z]
			return n and {name = n} or nil
		end}
		for _, w in ipairs(c.written) do
			recorded = recorded + 1
			if w.y >= 1 and by[w.x .. "," .. w.y .. "," .. w.z] == w.name and not decor_mod.soft(w.name) then
				check(not decor_mod.faces_window(view, w.x, w.y, w.z),
					c.label .. ": " .. w.name .. " blocks a window at " .. w.x .. "," .. w.y .. "," .. w.z)
			end
		end
		-- headroom: the room's standing course, flooded inside its box
		local function air(x, y, z) local n = by[x .. "," .. y .. "," .. z]; return n == nil or n == "air" end
		local rooms = {}
		for _, s in ipairs(c.bp.landmarks.structures or {}) do
			if s.interior and s.kind ~= "canopy" and s.w and s.d then
				local w, d = s.w, s.d
				if air(s.x + w, s.interior.y + 1, s.z) and not air(s.x + d, s.interior.y + 1, s.z) then w, d = d, w end
				rooms[#rooms + 1] = {s.label, s.interior.y, s.x - w + 1, s.z - d + 1, s.x + w - 1, s.z + d - 1}
			end
		end
		for _, r in ipairs(c.bp.landmarks.rooms or {}) do
			if r.closed then
				rooms[#rooms + 1] = {r.id or "room", r.min.y + 1, r.min.x, r.min.z, r.max.x, r.max.z}
			end
		end
		for _, r in ipairs(rooms) do
			local y, floor, low = r[2], 0, 0
			for z = r[4], r[6] do for x = r[3], r[5] do
				if air(x, y, z) and not air(x, y - 1, z) then
					floor = floor + 1
					if not air(x, y + 1, z) then low = low + 1 end
				end
			end end
			check(floor > 0 and low * 4 <= floor, c.label .. " " .. tostring(r[1]) ..
				": two nodes of headroom over the floor (" .. low .. " of " .. floor .. " cells lower)")
		end
	end
	check(recorded > 1000, "decor cells recorded (" .. recorded .. ")")

	-- F. reachability: every place a player could walk to inside a
	-- composition without its decor stays reachable with it, from the
	-- composition's arrival, within a small detour (DETOUR steps).
	local DETOUR = 6
	local function walk_grid(bp)
		local by = {}
		for _, cell in ipairs(bp.cells) do by[cell.x .. "," .. cell.y .. "," .. cell.z] = cell.name end
		return by
	end
	local function passable(n)
		return n == nil or decor_mod.soft(n) or n:sub(1, 6) == "doors:" or
			n:find("stonepath", 1, true) ~= nil or n:find("wagon_wheel", 1, true) ~= nil or
			n:find("cobweb", 1, true) ~= nil
	end
	local function distances(bp)
		local by = walk_grid(bp)
		local b = bp.bounds
		local function pass(x, y, z) return passable(by[x .. "," .. y .. "," .. z]) end
		-- A POI's core sits in a collar of open ground (world_zones.md): one
		-- ring of it round the core is walkable at the core's level.
		local collar = bp.landmarks.structures ~= nil
		local function stand(x, y, z)
			local inside = x >= b.min.x and x <= b.max.x and z >= b.min.z and z <= b.max.z
			if not inside then
				return collar and y == 1 and x >= b.min.x - 1 and x <= b.max.x + 1 and
					z >= b.min.z - 1 and z <= b.max.z + 1
			end
			return y > b.min.y and y <= b.max.y and pass(x, y, z) and pass(x, y + 1, z) and
				not pass(x, y - 1, z)
		end
		local a = bp.landmarks.arrival or {x = 0, y = 1, z = 0}
		local start
		for r = 0, 3 do
			for dz = -r, r do for dx = -r, r do for dy = 0, 2 do
				if not start and stand(a.x + dx, a.y + dy, a.z + dz) then
					start = {a.x + dx, a.y + dy, a.z + dz}
				end
			end end end
		end
		local dist = {}
		if not start then return dist, stand end
		local queue, head = {start}, 1
		dist[start[1] .. "," .. start[2] .. "," .. start[3]] = 0
		while head <= #queue do
			local q = queue[head]
			head = head + 1
			local d = dist[q[1] .. "," .. q[2] .. "," .. q[3]]
			for _, m in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				for _, dy in ipairs({0, 1, -1}) do
					local x, y, z = q[1] + m[1], q[2] + dy, q[3] + m[2]
					local k = x .. "," .. y .. "," .. z
					if dist[k] == nil and stand(x, y, z) and
							(dy ~= 1 or pass(q[1], q[2] + 2, q[3])) then
						dist[k] = d + 1
						queue[#queue + 1] = {x, y, z}
						break
					end
				end
			end
		end
		return dist, stand
	end
	for _, c in ipairs(comps) do
		local before = distances(c.before)
		local after, stand = distances(c.bp)
		local worst, lost = 0, 0
		for k, d in pairs(before) do
			local x, y, z = k:match("^(-?%d+),(-?%d+),(-?%d+)$")
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			if stand(x, y, z) then
				local d2 = after[k]
				if d2 == nil then lost = lost + 1
				elseif d2 - d > worst then worst = d2 - d end
			end
		end
		check(lost == 0 and worst <= DETOUR, c.label .. ": decor keeps every walkable place reachable (" ..
			lost .. " cut off, worst detour " .. worst .. " steps)")
	end
end

print(("r36_w portable test: %d checks passed"):format(checks))
