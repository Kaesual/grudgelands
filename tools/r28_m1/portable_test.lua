-- Round 28 Lane M1 (zone and town names for players), portable test (LuaJIT).
--
--   luajit tools/r28_m1/portable_test.lua [repo]
--
-- Loads the REAL grug_map location_view.lua (pure) and location.lua plus
-- grug_core hud_layout.lua and grug_map atlas.lua on a fake engine. Checks:
--   N  names: the zone's display name; the town's name inside a start town's
--      or capital city's footprint only (not in the rest of its box); a
--      village keeps the zone's name; open sea; the exact footprint query is
--      asked only inside a town's box;
--   D  debounce: the brief's city example (leave and re-enter within the
--      display: nothing new), A->B->A, A->B->C, no start while a display
--      runs, an unchanged sample shows nothing;
--   T  texts: zone tooltips ("Dawnmere Fields (levels 1–10)", one level),
--      King labels;
--   P  placement: chamfer depths, the pole of inaccessibility, determinism,
--      the minimum distance to obstacles and between zone markers, the
--      fallback when no cell is clear, islands, region-name obstacles;
--   R  runtime: banner element on join, the join banner, 1.5 s display then
--      hidden, the debounce through the real globalstep, text_of for the
--      minimap line, zone markers through the atlas provider, HUD traffic
--      only on changes, nothing during character creation; L layout: the
--      flight-boundary warning between the zone and level-up banners. The
--      per-sample cost is measured by the engine probe
--      (tools/r28_m1/probe.sh), not on this fake world.
-- Prints "R28 M1 PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end

local L = dofile(repo .. "/mods/PLAYER/grug_map/location_view.lua")

-- ---------------------------------------------------------------------------
-- N: which name a position shows
-- ---------------------------------------------------------------------------
-- A small world: Dawnmere Fields (start zone, z < -2300) with the start town
-- Dawnmere at (0, -2550) (a 152 square), Goldmead Vale (-2300 <= z < -1800)
-- with a village at (-120, -2020), Highcourt zone (z >= -1800) with the
-- capital city Highcourt at (0, -1500) (a round city of radius 200 inside its
-- 532 square), open sea beyond |x| > 1000.
local ZONE_NAMES = {elandor_dawnmere_fields = "Dawnmere Fields",
	elandor_goldmead_vale = "Goldmead Vale", elandor_highcourt = "Highcourt"}
local function zone_at(x, z)
	if math.abs(x) > 1000 then return nil end
	if z < -2300 then return "elandor_dawnmere_fields" end
	if z < -1800 then return "elandor_goldmead_vale" end
	return "elandor_highcourt"
end
local footprint_calls = 0
local function footprint_at(x, z)
	footprint_calls = footprint_calls + 1
	if math.abs(x) <= 76 and math.abs(z + 2550) <= 76 then return "hard:anchor_002" end
	if x * x + (z + 1500) * (z + 1500) <= 200 * 200 then return "hard:anchor_008" end
	if x == -120 and z == -2020 then return "functional:village" end
	return nil
end
local TOWNS = {{name = "Dawnmere", x = 0, z = -2550, footprint = "hard:anchor_002"},
	{name = "Highcourt", x = 0, z = -1500, footprint = "hard:anchor_008"}}
local resolve = L.resolver({zone_at = zone_at, names = ZONE_NAMES, towns = TOWNS,
	reach = 266, footprint_at = footprint_at})
do
	check(resolve(0, -2550) == "Dawnmere", "N start town centre shows the town")
	check(resolve(75, -2480) == "Dawnmere", "N start town edge (inside) shows the town")
	check(resolve(90, -2550) == "Dawnmere Fields", "N just outside the start town: zone")
	check(resolve(-120, -2020) == "Goldmead Vale", "N village keeps the zone name")
	check(resolve(0, -1500) == "Highcourt" and resolve(150, -1400) == "Highcourt",
		"N capital city shows the city")
	footprint_calls = 0
	check(resolve(250, -1500) == "Highcourt", "N outside the city, in its zone: zone name")
	check(footprint_calls == 1, "N one exact query inside a town box")
	footprint_calls = 0
	check(resolve(400, -2100) == "Goldmead Vale" and resolve(500, -2600) == "Dawnmere Fields",
		"N plain zone names")
	check(footprint_calls == 0, "N no exact query outside every town box")
	check(resolve(2000, -2000) == L.OPEN_SEA, "N open sea")
	local unnamed = L.resolver({zone_at = function() return "front_x" end, names = {},
		towns = {}, reach = 266, footprint_at = footprint_at})
	check(unnamed(0, 0) == "front_x", "N a zone without a name shows its id")
end

-- ---------------------------------------------------------------------------
-- D: debounce
-- ---------------------------------------------------------------------------
do
	local s = L.new_state()
	check(L.sample(s, "Dawnmere Fields", 0) == "Dawnmere Fields", "D join shows the location")
	check(L.sample(s, "Dawnmere Fields", 0.5) == nil, "D busy: nothing")
	check(L.expire(s, "Dawnmere Fields", 1.4) == nil, "D before the end: nothing")
	check(L.expire(s, "Dawnmere Fields", 1.5) == false, "D end, same place: hide")
	check(s.busy_until == nil, "D idle after hiding")
	check(L.sample(s, "Dawnmere Fields", 2) == nil, "D unchanged sample: nothing")
	-- The brief's example: enter the city, leave and re-enter within 1.5 s.
	check(L.sample(s, "Highcourt City", 10) == "Highcourt City", "D enter city: shows")
	check(L.sample(s, "Highcourt", 11) == nil, "D left the city while busy: nothing")
	check(L.expire(s, "Highcourt City", 11.5) == false, "D back in the city at the end: hide")
	check(s.shown == "Highcourt City", "D shown stays the city")
	-- A -> B -> A
	local a = L.new_state()
	L.sample(a, "A", 0)
	L.expire(a, "A", 1.5)
	check(L.sample(a, "B", 3) == "B", "D A->B shows B")
	check(L.sample(a, "A", 4) == nil, "D A->B->A: A waits")
	check(L.expire(a, "A", 4.5) == "A", "D A->B->A: A shows when B ends")
	check(a.busy_until == 6, "D the follow-up display runs 1.5 s")
	check(L.expire(a, "A", 6) == false, "D then hides")
	-- A -> B -> C
	local c = L.new_state()
	L.sample(c, "A", 0)
	L.expire(c, "A", 1.5)
	L.sample(c, "B", 2)
	check(L.sample(c, "C", 3) == nil, "D A->B->C: C waits")
	check(L.expire(c, "C", 3.5) == "C", "D A->B->C: C shows when B ends")
	check(L.sample(L.new_state(), nil, 0) == nil, "D no location: nothing")
end

-- ---------------------------------------------------------------------------
-- T: texts
-- ---------------------------------------------------------------------------
do
	check(L.zone_tooltip({display_name = "Dawnmere Fields", level_min = 1, level_max = 10}) ==
		"Dawnmere Fields (levels 1–10)", "T zone tooltip with a band")
	check(L.zone_tooltip({display_name = "Stormscale Summit", level_min = 60, level_max = 60}) ==
		"Stormscale Summit (level 60)", "T single-level zone")
	check(L.zone_tooltip({id = "x", display_name = "X"}) == "X", "T no band: name only")
	check(L.king_label("King of Highcourt", "Highcourt") == "King of Highcourt",
		"T King of <city>")
	check(L.king_label("King of Old Name", "Kezamba") == "King of Kezamba",
		"T the settlement's name wins")
	check(L.king_label("Aldric the Bold", "Highcourt") == "Aldric the Bold, King of Highcourt",
		"T a named king keeps his name")
end

-- ---------------------------------------------------------------------------
-- P: placement
-- ---------------------------------------------------------------------------
-- A grid from rows of characters: '.' water, letters zone ids.
local function grid_of(rows, step, min_x, max_z)
	local nx, nz = #rows[1], #rows
	local cells = {}
	for gz = 0, nz - 1 do
		local row = rows[gz + 1]
		for gx = 0, nx - 1 do
			local ch = row:sub(gx + 1, gx + 1)
			cells[gz * nx + gx + 1] = ch ~= "." and ch or false
		end
	end
	return {nx = nx, nz = nz, step = step or 10, min_x = min_x or 0, max_z = max_z or 0,
		cells = cells}
end
local function cell_of(grid, point)
	local gx = math.floor((point.x - grid.min_x) / grid.step)
	local gz = math.floor((grid.max_z - point.z) / grid.step)
	return gx, gz
end
local function cheb(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.z - b.z)) end
do
	local square = grid_of({
		".........",
		".AAAAAAA.",
		".AAAAAAA.",
		".AAAAAAA.",
		".AAAAAAA.",
		".AAAAAAA.",
		".AAAAAAA.",
		".AAAAAAA.",
		"........."})
	local depth = L.depths(square)
	check(depth[4 * 9 + 4 + 1] == 12 and depth[1 * 9 + 1 + 1] == 3 and depth[1] == 0,
		"P chamfer depths: border 3, centre 12, water 0")
	local points = L.place_labels(square, {"A"}, {}, 20)
	local gx, gz = cell_of(square, points.A)
	check(gx == 4 and gz == 4 and points.A.x == 45 and points.A.z == -45,
		"P pole of a square is its centre cell")

	-- Two zones side by side, an island zone, and a lake in B.
	local rows = {
		"....................",
		".AAAAAAAABBBBBBBBB..",
		".AAAAAAAABBBBBBBBB..",
		".AAAAAAAABBBB..BBB..",
		".AAAAAAAABBBB..BBB..",
		".AAAAAAAABBBBBBBBB..",
		".AAAAAAAABBBBBBBBB..",
		"....................",
		"...........CCC......",
		"...........CCC......",
		"...........CCC......",
		"....................",
	}
	local world = grid_of(rows, 10, 0, 0)
	local order = {"A", "B", "C"}
	local first = L.place_labels(world, order, {}, 25)
	local again = L.place_labels(world, order, {}, 25)
	check(first.A and first.B and first.C, "P every zone gets a marker, the island too")
	check(first.A.x == again.A.x and first.B.z == again.B.z and first.C.x == again.C.x,
		"P deterministic")
	check(zone_at and world.cells[select(2, cell_of(world, first.B)) * world.nx +
		cell_of(world, first.B) + 1] == "B", "P B's marker on B's land")
	local cx, cz = cell_of(world, first.C)
	check(cx == 12 and cz == 9, "P island marker at the island's deepest cell")
	-- An obstacle on A's pole: the marker moves to the deepest clear cell.
	local obstacle = {x = first.A.x, z = first.A.z, rx = 25, rz = 25}
	local nudged = L.place_labels(world, order, {obstacle}, 25)
	check(cheb(nudged.A, obstacle) >= 25, "P nudged clear of an obstacle")
	check(world.cells[select(2, cell_of(world, nudged.A)) * world.nx +
		cell_of(world, nudged.A) + 1] == "A", "P the nudged marker stays in its zone")
	-- Zone markers keep the gap from each other.
	local spaced = L.place_labels(world, order, {}, 60)
	check(cheb(spaced.A, spaced.B) >= 60, "P zone markers keep the gap between each other")
	-- Obstacle order does not matter.
	local o1 = {x = 30, z = -30, rx = 25, rz = 25}
	local o2 = {x = 120, z = -40, rx = 25, rz = 25}
	local p1 = L.place_labels(world, order, {o1, o2}, 25)
	local p2 = L.place_labels(world, order, {o2, o1}, 25)
	check(p1.A.x == p2.A.x and p1.A.z == p2.A.z and p1.B.x == p2.B.x and p1.B.z == p2.B.z,
		"P obstacle order does not change the placement")
	-- No clear cell: the clearest one wins, still on the zone's land.
	local wall = {x = 50, z = -40, rx = 1000, rz = 1000}
	local fallback = L.place_labels(world, {"A"}, {wall}, 25)
	check(fallback.A and world.cells[select(2, cell_of(world, fallback.A)) * world.nx +
		cell_of(world, fallback.A) + 1] == "A", "P no clear cell: still placed on the zone")
	local near_wall = {x = 45, z = -35, rx = 40, rz = 40}
	local clearest = L.place_labels(world, {"A"}, {near_wall}, 25)
	check(cheb(clearest.A, near_wall) >= 40, "P a clear cell found beside a big obstacle")
	-- A name covering the whole zone and a marker on part of it: the marker
	-- stays clear of the icon and accepts the text.
	local name = {x = 45, z = -35, rx = 1000, rz = 1000, soft = true}
	local icon = {x = 45, z = -35, rx = 30, rz = 30}
	local icon_first = L.place_labels(world, {"A"}, {name, icon}, 25)
	check(cheb(icon_first.A, icon) >= 30, "P fallback keeps clear of icons before names")
	-- A region name's obstacle: wrapped text, half a marker round it.
	local text = L.text_obstacle("Human Lands", 0, 0, 4.6, 0.45, 100)
	check(text.soft and math.abs(text.rx - (11 * 0.2 / 2 + 0.225) * 100) < 1e-9 and
		math.abs(text.rz - (0.45 / 2 + 0.225) * 100) < 1e-9, "P one-line region name box")
	local island = L.text_obstacle("Wyrmglass Crown", 0, 0, 2.4, 0.45, 100)
	check(math.abs(island.rz - (2 * 0.45 / 2 + 0.225) * 100) < 1e-9 and
		math.abs(island.rx - (9 * 0.2 / 2 + 0.225) * 100) < 1e-9,
		"P island name wraps onto two lines")
end

-- ---------------------------------------------------------------------------
-- R: runtime (location.lua on a fake engine)
-- ---------------------------------------------------------------------------
local now_us = 0
local joins, leaves, steps, loaded, logs = {}, {}, {}, {}, {}
local players = {}
local function new_player(name, pos)
	local p = {name = name, pos = pos, huds = {}, next_id = 0, sent = 0}
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:hud_add(def)
		self.next_id = self.next_id + 1
		local copy = {}
		for k, v in pairs(def) do copy[k] = v end
		self.huds[self.next_id] = copy
		self.sent = self.sent + 1
		return self.next_id
	end
	function p:hud_change(id, stat, value)
		assert(self.huds[id], "hud_change on a removed element")
		self.huds[id][stat] = value
		self.sent = self.sent + 1
	end
	return p
end
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function() return repo .. "/mods/PLAYER/grug_map" end,
	get_us_time = function() return now_us end,
	-- Round 30 P3 caches the zone-marker grid in the world directory; a path
	-- that never exists makes every run sample afresh and the write a no-op.
	get_worldpath = function() return "/nonexistent/grug_r28_m1_world" end,
	safe_file_write = function() return false end,
	log = function(_, text) logs[#logs + 1] = text end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	get_connected_players = function()
		local list = {}
		for _, p in pairs(players) do list[#list + 1] = p end
		table.sort(list, function(a, b) return a.name < b.name end)
		return list
	end,
	get_player_by_name = function(name) return players[name] end,
	get_player_window_information = function() return nil end,
})
local STASIS = {}
rawset(_G, "grug_core", {
	player_in_creation_stasis = function(name) return STASIS[name] == true end,
	FEED_COLOR = {notice = 0xf0e6c8},
	zone_authority_installed = function() return true end,
	settlement_socket_settlements = function()
		return {{key = "dawnmere", display_name = "Dawnmere", anchor = {x = 0, y = 10, z = -2550}},
			{key = "highcourt", display_name = "Highcourt", anchor = {x = 0, y = 10, z = -1500}},
			{key = "goldmead_village", display_name = "Goldmead Village",
				anchor = {x = -120, y = 10, z = -2020}}}
	end,
})
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
local RECORDS = {
	elandor_dawnmere_fields = {id = "elandor_dawnmere_fields", numeric_id = 6,
		display_name = "Dawnmere Fields", level_min = 1, level_max = 10},
	elandor_goldmead_vale = {id = "elandor_goldmead_vale", numeric_id = 7,
		display_name = "Goldmead Vale", level_min = 11, level_max = 20},
	elandor_highcourt = {id = "elandor_highcourt", numeric_id = 8,
		display_name = "Highcourt", level_min = 20, level_max = 30},
}
local zone_queries = 0
rawset(_G, "grug_zones", {
	id_at = function(x, z) zone_queries = zone_queries + 1 return zone_at(x, z) end,
	get = function(id) return RECORDS[id] end,
	water_class_at = function(x) return math.abs(x) > 1000 and "deep_ocean" or "land" end,
	hard_footprint_in = function(min_x, min_z)
		local id = footprint_at(min_x, min_z)
		if id and id:find("^hard:") then return id, "town" end
		if id then return id, "landmark" end
		return nil
	end,
})
rawset(_G, "grug_home", {locations = function()
	return {{id = "highcourt", label = "Highcourt", pos = {x = -60, y = 10, z = -1520}}}
end})
rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")})
grug_map.atlas.set_base_texture("base.png")
grug_map.page_layout = {map_w = 12.37, region_labels = {{"Human Lands", 0, -2350, 4.6, 1.3}}}
grug_map.static_marker_positions = function()
	return {{x = 0, z = -1500}, {x = 40, z = -1480}, {x = 0, z = -2550}}
end
dofile(repo .. "/mods/PLAYER/grug_map/location.lua")
local M = grug_map.location
check(type(M) == "table" and M.text_at({x = 0, y = 0, z = -2550}) == "Dawnmere",
	"R location.lua publishes text_at")
for _, fn in ipairs(loaded) do fn() end

-- Zone markers through the atlas.
do
	local markers = grug_map.atlas.collect_markers(nil, {zone = true})
	check(#markers == 3, "R one marker per zone (" .. #markers .. ")")
	local by_id, ok = {}, true
	for _, m in ipairs(markers) do
		by_id[m.id] = m
		ok = ok and m.kind == "zone" and m.texture == "grug_map_zone.png"
	end
	check(ok, "R zone markers have their kind and icon")
	local dawn = by_id["zone:elandor_dawnmere_fields"]
	check(dawn and dawn.detail == "Dawnmere Fields (levels 1–10)" and
		dawn.label == "Dawnmere Fields", "R tooltip text through the provider")
	check(dawn and zone_at(dawn.position.x, dawn.position.z) == "elandor_dawnmere_fields",
		"R the marker lies in its zone")
	local gap = 0.45 * 7200 / 12.37
	local fixed = {{x = 0, z = -1500}, {x = 40, z = -1480}, {x = 0, z = -2550},
		{x = -120, z = -2020}, {x = -60, z = -1520}}
	local clear = true
	for _, m in ipairs(markers) do
		for _, f in ipairs(fixed) do clear = clear and cheb(m.position, f) >= gap end
		for _, o in ipairs(markers) do
			if o ~= m then clear = clear and cheb(m.position, o.position) >= gap end
		end
	end
	check(clear, "R zone markers keep the minimum distance from every marker")
	local logged = false
	for _, text in ipairs(logs) do logged = logged or text:find("placed 3 zone markers", 1, true) end
	check(logged, "R placement is logged")
end

local function step(seconds)
	local target = now_us + seconds * 1e6
	while now_us < target do
		now_us = now_us + 50000
		for _, fn in ipairs(steps) do fn(0.05) end
	end
end
do
	local p = new_player("p1", {x = 300, y = 10, z = -2600})
	players.p1 = p
	for _, fn in ipairs(joins) do fn(p) end
	local banner
	for id, def in pairs(p.huds) do
		if def.type == "text" and def.position and def.position.y == 0 then banner = id end
	end
	check(banner and p.huds[banner].size.x == 2.5 and p.huds[banner].style == 1,
		"R banner element added on join at 2.5x, bold, top centre")
	check(banner and p.huds[banner].offset.y == grug_core.hud_layout.zone_banner_offset(nil).y,
		"R banner at its layout anchor")
	step(1.0)
	check(p.huds[banner].text == "Dawnmere Fields", "R join shows the location")
	check(M.text_of(p) == "Dawnmere Fields" and M.text_of("p1") == "Dawnmere Fields",
		"R text_of feeds the minimap line")
	step(1.6)
	check(p.huds[banner].text == "", "R hidden after 1.5 s")
	local sent = p.sent
	step(5)
	check(p.sent == sent, "R a player standing still sends nothing")
	-- Walk into the start town.
	p.pos = {x = 10, y = 10, z = -2540}
	step(1.1)
	check(p.huds[banner].text == "Dawnmere", "R entering the start town shows its name")
	-- Leave and come back within the display: nothing new afterwards.
	p.pos = {x = 300, y = 10, z = -2600}
	step(0.5)
	check(M.text_of(p) == "Dawnmere Fields", "R the minimap line follows at once")
	p.pos = {x = 10, y = 10, z = -2540}
	step(1.5)
	check(p.huds[banner].text == "", "R back in town at the end: no new banner")
	-- A -> B -> C: start zone, Goldmead (village), Highcourt city.
	p.pos = {x = -120, y = 10, z = -2020}
	step(1.1)
	check(p.huds[banner].text == "Goldmead Vale", "R the village shows its zone")
	p.pos = {x = 0, y = 10, z = -1500}
	step(0.3)
	check(p.huds[banner].text == "Goldmead Vale", "R the city waits for the display to end")
	step(1.3)
	check(p.huds[banner].text == "Highcourt", "R then the city shows")
	step(2)
	check(p.huds[banner].text == "", "R and hides")
	for _, fn in ipairs(leaves) do fn(p) end
	players.p1 = nil
	check(M.text_of("p1") == "", "R leave clears the player")
end

-- Character creation: the player waits at the engine's spawn spot in
-- stasis; nothing names it, and release shows the start town.
do
	STASIS.p2 = true
	local p = new_player("p2", {x = 300, y = 10, z = -2600})
	players.p2 = p
	for _, fn in ipairs(joins) do fn(p) end
	local banner
	for id, def in pairs(p.huds) do
		if def.type == "text" and def.position and def.position.y == 0 then banner = id end
	end
	step(3)
	check(p.huds[banner].text == "" and M.text_of(p) == "",
		"R creation stasis: no banner and no minimap line")
	STASIS.p2 = nil
	p.pos = {x = 10, y = 10, z = -2540}
	step(1.1)
	check(p.huds[banner].text == "Dawnmere" and M.text_of(p) == "Dawnmere",
		"R after release the first sample shows the start town")
	for _, fn in ipairs(leaves) do fn(p) end
	players.p2 = nil
end

-- Layout: the flight-boundary warning sits below the zone banner and above
-- the level-up banner (0.25 H, size 2) at 720p and the usual scalings.
do
	local layout = grug_core.hud_layout
	for _, w in ipairs({{720, 1, 1}, {1080, 1, 1}, {1080, 1.5, 1.5}, {1440, 2, 2}}) do
		local window = {size = {x = w[1] * 16 / 9, y = w[1]}, real_hud_scaling = w[2],
			real_gui_scaling = w[3]}
		local hud, gui = w[2], w[3]
		local banner = layout.zone_banner_offset(window)
		local banner_bottom = (banner.y + math.ceil(20 * 2.5 * gui / hud) / 2) * hud
		local warning = layout.flight_warning_offset(window)
		local line = math.ceil(20 * gui / hud) * hud
		local top, bottom = warning.y * hud - line / 2, warning.y * hud + line / 2
		local target_bottom = (layout.TARGET_FRAME_Y + math.ceil(20 * gui / hud) / 2) * hud
		local banner_top = (banner.y - math.ceil(20 * 2.5 * gui / hud) / 2) * hud
		check(banner_top > target_bottom, "L zone banner below the target frame at " .. w[1])
		check(top > banner_bottom, "L flight warning below the zone banner at " .. w[1])
		check(bottom < 0.25 * w[1] - 20 * gui, "L flight warning above the level-up banner at " ..
			w[1] .. "p scale " .. w[2])
	end
	check(layout.anchors.flight_warning.position.y == 0 and
		layout.anchors.flight_warning.offset.y == layout.flight_warning_offset(nil).y,
		"L flight warning anchor")
end

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R28 M1 PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print("R28 M1 PORTABLE PASS checks=" .. checks)
