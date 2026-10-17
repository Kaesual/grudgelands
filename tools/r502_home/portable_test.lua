-- Fix 0.50.2 lane HOME portable test (LuaJIT): claims named in the location
-- line and banner, and framed on the minimap (docs/planning/
-- fix-0.50.2-plan.md "Addendum: lane HOME", rulings H1-H4).
--
--   luajit tools/r502_home/portable_test.lua [repo]
--
-- Loads the REAL grug_housing registry.lua, grug_core hud_layout.lua and
-- grug_map location_view.lua, location.lua, atlas.lua, base.lua,
-- minimap_view.lua and minimap.lua on a fake engine. Checks:
--   N  names (H1, H2) through the real location.lua: "Your Home" for the
--      owner, "<owner>'s Home" for everybody else (a permission holder too,
--      a name ending in s too); every claim state (draft, active,
--      expired); y -100 in and -101 out, no top; the edge node in and the
--      next one out, to the node; elsewhere the zone's name; the territory
--      line and colour unchanged; the zone handed to the discovery is the
--      column's; text_at stays the column's name;
--   B  the banner rule (H3): pure, a change replaces a running display at
--      once and restarts its time, the last one runs the full DISPLAY; at
--      runtime, a zigzag across a claim edge shows every crossing at the
--      next sample and the last banner for the full time;
--   F  frames (H4): geometry, the frame is the outward-rounded box's
--      border one pixel wide, every pixel once, clipped exactly at every
--      edge of the cell texture, every `[fill` valid by the engine's checks
--      (imagesource.cpp `[fill`, CHECK_DIM); at runtime, no claim near
--      gives the plain map's string, the own claim green (drawn last) and
--      others yellow, every claim state, the same claims give the same
--      string, a claim elsewhere changes nothing and sends nothing, a
--      claim's removal takes its frame, the frames sit before the mask,
--      and claim mode stays CMAP's (red fills only).
-- Prints "R502 HOME PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

-- ---------------------------------------------------------------------------
-- fake engine (shared; the hook lists are replaced per section)
-- ---------------------------------------------------------------------------
local joins, leaves, steps = {}, {}, {}
local players, windows = {}, {}
local now_us, sent = 0, 0
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(mod)
		local roots = {grug_map = "/mods/PLAYER/grug_map", grug_housing = "/mods/PLAYER/grug_housing"}
		return roots[mod] and repo .. roots[mod] or nil
	end,
	get_modnames = function() return {"grug_map"} end,
	get_worldpath = function() return "/nonexistent-world" end,
	get_us_time = function() return now_us end,
	log = function() end,
	settings = {get = function() return nil end},
	encode_png = function(_, _, data) return data end,
	safe_file_write = function() return true end,
	dynamic_add_media = function() return true end,
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
	get_player_window_information = function(name) return windows[name] end,
	get_timeofday = function() return 0.5 end,
})

local function new_player(name, pos)
	local meta = {}
	local p = {name = name, pos = pos, yaw = 0, wield = "", huds = {}, next_id = 0}
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_look_horizontal() return self.yaw end
	function p:get_wielded_item()
		local item = self.wield
		return {get_name = function() return item end}
	end
	function p:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, value) meta[k] = value end}
	end
	function p:hud_add(def)
		self.next_id = self.next_id + 1
		local copy = {}
		for k, value in pairs(def) do copy[k] = value end
		self.huds[self.next_id] = copy
		return self.next_id
	end
	function p:hud_change(id, stat, value)
		sent = sent + 1
		self.huds[id][stat] = value
	end
	function p:hud_remove(id) self.huds[id] = nil end
	function p:hud_set_flags() end
	function p:set_minimap_modes() end
	return p
end
local function join(p)
	players[p.name] = p
	for _, fn in ipairs(joins) do fn(p) end
	return p
end
-- Server steps of 0.05 s for `seconds`.
local function step(seconds)
	local target = now_us + seconds * 1e6
	while now_us < target - 1 do
		now_us = now_us + 50000
		for _, fn in ipairs(steps) do fn(0.05) end
	end
end

-- the engine's `[fill` checks (imagesource.cpp, 5.17) on every top-level
-- part of a texture string, as tools/r502_cmap's
local function fills_valid(texture, width, height)
	local ok, count = true, 0
	for part in (texture .. "^"):gmatch("([^%^]*)%^") do
		if part:find("^%[fill") then
			count = count + 1
			local w, h, x, y = part:match("^%[fill:(%d+)x(%d+):(%d+),(%d+):#%x+$")
			w, h, x, y = tonumber(w), tonumber(h), tonumber(x), tonumber(y)
			if not (w and h and w >= 1 and h >= 1 and x >= 0 and y >= 0 and
					x < width and y < height) then
				ok = false
			end
		end
	end
	return ok, count
end

-- the real claim registry
local clock = 1800000000
local function new_storage()
	local data = {}
	return {get_string = function(key) return data[key] or "" end,
		set_string = function(key, value) data[key] = value ~= "" and value or nil end,
		keys = function()
			local keys = {}
			for key in pairs(data) do keys[#keys + 1] = key end
			return keys
		end}
end
local registry = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")

-- ---------------------------------------------------------------------------
-- B  the banner rule, pure
-- ---------------------------------------------------------------------------
local L = dofile(repo .. "/mods/PLAYER/grug_map/location_view.lua")
do
	local D = L.DISPLAY
	local s = L.new_state()
	eq(L.sample(s, "Green Vale", 0, "friendly"), "Green Vale", "B the first sample shows")
	eq(L.sample(s, "Green Vale", 1, "friendly"), nil, "B unchanged: nothing")
	eq(L.sample(s, "Your Home", 2, "friendly"), "Your Home", "B a change replaces the display at once")
	eq(s.busy_until, 2 + D, "B ...and restarts its time")
	eq(L.expire(s, "Your Home", D, "friendly"), nil, "B the first display's end: nothing")
	eq(L.sample(s, "Green Vale", 3, "friendly"), "Green Vale", "B back out: at once again")
	eq(L.sample(s, "Green Vale", 3 + D - 1, "friendly"), nil, "B the last display runs on")
	eq(L.expire(s, "Green Vale", 3 + D - 0.5, "friendly"), nil, "B ...until its full time")
	eq(L.expire(s, "Green Vale", 3 + D, "friendly"), false, "B ...then hides")
	eq(L.sample(s, "Green Vale", 3 + D, "contested"), "Green Vale", "B a status change shows too")
	eq(L.sample(s, "Green Vale", 4 + D, "friendly"), "Green Vale", "B ...and its undoing at once")
	eq(L.home_text("ann", "ann"), "Your Home", "B the owner's text")
	eq(L.home_text("ann", "bob"), "ann's Home", "B another player's text")
	eq(L.home_text("Jens", "bob"), "Jens's Home", "B a name ending in s: always 's")
end

-- ---------------------------------------------------------------------------
-- N, B  names and the banner through the real location.lua
-- ---------------------------------------------------------------------------
local model = registry({storage = new_storage(), now = function() return clock end})
model.load()
do
	rawset(_G, "grug_core", {FEED_COLOR = {notice = 0xf0e6c8},
		zone_authority_installed = function() return true end,
		settlement_socket_settlements = function() return {} end})
	dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
	local queries = 0
	rawset(_G, "grug_zones", {
		id_at = function(x) queries = queries + 1 return x < 2000 and "vale" or "moor" end,
		get = function(id)
			return {id = id, display_name = id == "vale" and "Green Vale" or "Grey Moor"}
		end,
		hard_footprint_in = function() return nil end,
	})
	rawset(_G, "grug_factions", {get_faction = function() return "accord" end})
	rawset(_G, "grug_pvp", {territory_at = function(pos, own)
		if not own then return nil end
		return pos.y <= -501 and "contested" or "friendly"
	end})
	rawset(_G, "grug_housing", {claim_at = model.claim_at})
	rawset(_G, "grug_map", {})
	dofile(repo .. "/mods/PLAYER/grug_map/location.lua")
	local M = grug_map.location
	local entered, started = {}, {}
	-- ann's calls only
	M.discovery = {start = function(player, zone)
		if player:get_player_name() == "ann" then started[#started + 1] = zone end
	end, enter = function(player, zone)
		if player:get_player_name() == "ann" then entered[#entered + 1] = zone or "-" end
	end}

	-- ann's draft at 0/0, bob's active claim at 300/0 (ann may build there),
	-- Jens's expired claim at 600/0
	local jens = model.create("Jens", {x = 600, y = 5, z = 0})
	model.activate(jens, 5)
	clock = clock + 6 * model.LUMP_SECONDS
	model.expiry_scan()
	local own = model.create("ann", {x = 0, y = 5, z = 0})
	local bobs = model.create("bob", {x = 300, y = 5, z = 0})
	model.activate(bobs, 5)
	model.set_permission(bobs, "ann", "interact")
	check(model.is_draft(own) and model.is_active(bobs) and not model.is_draft(jens) and
		not model.is_active(jens), "N the three states: draft, active, expired")

	local ann = join(new_player("ann", {x = 0.3, y = 10, z = 0.2}))
	local banner, line
	for id, def in pairs(ann.huds) do
		if def.type == "text" and def.position and def.position.y == 0 then
			if def.size then banner = ann.huds[id] else line = ann.huds[id] end
		end
	end
	local function at(x, y, z)
		ann.pos = {x = x, y = y, z = z}
		step(1.0)
		return (M.text_of(ann))
	end
	eq(at(0.3, 10, 0.2), "Your Home", "N the owner in her draft: Your Home")
	eq(banner.text, "Your Home", "N ...as banner")
	eq(line.text, "Friendly Territory", "N the territory line stays")
	eq(select(2, M.text_of(ann)), 0x55ff55, "N ...and its colour")
	eq(started[1], "vale", "N the discovery starts with the column's zone")
	eq(entered[1], "vale", "N ...and enters the column's zone, not the claim")
	eq(M.text_at({x = 0, y = 10, z = 0}), "Green Vale", "N text_at stays the column's name")
	-- the edge, to the node: the claim covers the columns -50 .. 50, each
	-- node its column +- 0.5 (grug_housing claim_at rounds)
	eq(at(50, 10, 0), "Your Home", "N the east edge node in")
	eq(at(50.49, 10, 0), "Your Home", "N ...to its last part")
	eq(at(50.5, 10, 0), "Green Vale", "N the next node out (no hysteresis)")
	eq(at(51, 10, 0), "Green Vale", "N ...beyond")
	eq(at(-50.5, 10, 0), "Your Home", "N the west edge node in")
	eq(at(-50.51, 10, 0), "Green Vale", "N the next node out")
	eq(at(0, 10, 50.4), "Your Home", "N the north edge node in")
	eq(at(0, 10, -51), "Green Vale", "N past the south edge out")
	-- down and up
	eq(at(0, -100, 0), "Your Home", "N y -100 in")
	eq(at(0, -100.4, 0), "Your Home", "N ...its whole node")
	eq(at(0, -101, 0), "Green Vale", "N y -101 out")
	eq(at(0, -100.6, 0), "Green Vale", "N ...the node below -100")
	eq(at(0, 3000, 0), "Your Home", "N no top")
	-- other claims: the permission holder, a name ending in s
	eq(at(300, 10, 0), "bob's Home", "N bob's active claim, ann holds a permission: bob's Home")
	eq(at(600, 10, 10), "Jens's Home", "N an expired claim, a name ending in s: Jens's Home")
	eq(at(700, 10, 0), "Green Vale", "N between claims: the zone")
	local bob = join(new_player("bob", {x = 310, y = 10, z = 5}))
	step(1.0)
	eq((M.text_of(bob)), "Your Home", "N bob in his own claim: Your Home")
	for _, fn in ipairs(leaves) do fn(bob) end
	players.bob = nil
	-- the claim's zone never reaches the discovery: one zone all along
	local others = 0
	for _, zone in ipairs(entered) do if zone ~= "vale" then others = others + 1 end end
	eq(others, 0, "N the discovery never got anything but the column's zone")
	eq(#entered, 1, "N ...and only at the first sample (the zone never changed)")

	-- B at runtime: a zigzag across the claim's east edge, then standing
	at(70, 10, 0)
	step(L.DISPLAY + 1)
	eq(banner.text, "", "B idle before the zigzag")
	at(45, 10, 0)
	eq(banner.text, "Your Home", "B in: the banner")
	at(55, 10, 0)
	eq(banner.text, "Green Vale", "B out within the display: replaced at the next sample")
	at(45, 10, 0)
	eq(banner.text, "Your Home", "B in again: replaced again")
	step(L.DISPLAY - 1.1)
	eq(banner.text, "Your Home", "B the last banner still shows after DISPLAY - 0.1 s")
	step(1.3)
	eq(banner.text, "", "B ...and hides after its full time")
	-- cost: the claim lookup adds no zone query
	local before, samples = queries, M.stats.samples
	step(5)
	check(M.stats.samples > samples and queries - before <= M.stats.samples - samples,
		"N one zone query per sample, the claim lookup none")
	for _, fn in ipairs(leaves) do fn(ann) end
	players.ann = nil
	rawset(_G, "grug_pvp", nil)
	rawset(_G, "grug_housing", nil)
end

-- ---------------------------------------------------------------------------
-- F  frames, geometry
-- ---------------------------------------------------------------------------
local V = dofile(repo .. "/mods/PLAYER/grug_map/minimap_view.lua")
local BOUNDS = {min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200}
local R = model.RADIUS
do
	local v = V.new({quality = "normal", width = 1080, height = 960, tiles = {}}, BOUNDS)
	local ox, oy = V.origin(v, 300, 250)
	local size = v.combined
	local function world(px, py) return v.min_x + px * v.npp, v.max_z - py * v.npp end
	-- the unclipped outward-rounded box, as claim_rect rounds
	local function box(cx, cz)
		local l = math.floor((cx - R - 0.5 - v.min_x) / v.npp) - ox
		local t = math.floor((v.max_z - (cz + R + 0.5)) / v.npp) - oy
		local r = math.ceil((cx + R + 0.5 - v.min_x) / v.npp) - ox
		local b = math.ceil((v.max_z - (cz - R - 0.5)) / v.npp) - oy
		return l, t, r, b
	end
	local mid_x, mid_z = world(ox + size / 2, oy + size / 2)
	mid_x, mid_z = math.floor(mid_x), math.floor(mid_z)
	-- inside: four edges, the box's border one pixel wide, each pixel once
	local list = V.claim_frame(v, ox, oy, mid_x, mid_z, R, "#00ff00cc", {})
	eq(#list, 4, "F a claim inside the texture: four edges")
	local whole = V.claim_rect(v, ox, oy, mid_x, mid_z, R)
	local covered, twice = {}, false
	for _, rect in ipairs(list) do
		for y = rect.y, rect.y + rect.h - 1 do
			for x = rect.x, rect.x + rect.w - 1 do
				local key = y * 100000 + x
				twice = twice or covered[key] ~= nil
				covered[key] = true
			end
		end
	end
	local border = true
	for y = whole.y, whole.y + whole.h - 1 do
		for x = whole.x, whole.x + whole.w - 1 do
			local edge = x == whole.x or x == whole.x + whole.w - 1 or y == whole.y or
				y == whole.y + whole.h - 1
			border = border and (covered[y * 100000 + x] == true) == edge
		end
	end
	check(border and not twice, "F the frame is claim_rect's border, one pixel wide, each pixel once")
	check(list[1].color == "#00ff00cc" and list[4].color == "#00ff00cc", "F the edges carry the colour")
	check(whole.w >= 15 and whole.w <= 17, "F a claim is about 15-17 base pixels across (" ..
		whole.w .. ")")

	-- a sweep over claims all around and across the texture's edges: the
	-- pixels drawn are exactly the box border's pixels on the texture, each
	-- once, and every fill is valid
	local exact, once, valid_all, edges, rects = true, true, true, {0, 0, 0, 0, 0}, {}
	local half = size * v.npp / 2
	for dz = -half - 2 * R, half + 2 * R, 5 do
		for dx = -half - 2 * R, half + 2 * R, 5 do
			local cx, cz = math.floor(mid_x + dx), math.floor(mid_z + dz)
			local got = V.claim_frame(v, ox, oy, cx, cz, R, "#ffd040cc", {})
			edges[#got + 1] = edges[#got + 1] + 1
			local seen = {}
			for _, rect in ipairs(got) do
				rects[#rects + 1] = rect
				for y = rect.y, rect.y + rect.h - 1 do
					for x = rect.x, rect.x + rect.w - 1 do
						local key = y * 100000 + x
						once = once and not seen[key]
						seen[key] = true
					end
				end
			end
			local l, t, r, b = box(cx, cz)
			for y = math.max(0, t), math.min(size, b) - 1 do
				for x = math.max(0, l), math.min(size, r) - 1 do
					local edge = x == l or x == r - 1 or y == t or y == b - 1
					exact = exact and (seen[y * 100000 + x] == true) == edge
					seen[y * 100000 + x] = nil
				end
			end
			exact = exact and next(seen) == nil
		end
	end
	check(exact, "F clipped exactly: the border's pixels on the texture, no other")
	check(once, "F every pixel once")
	check(edges[1] > 0 and edges[2] > 0 and edges[3] > 0 and edges[4] > 0 and edges[5] > 0,
		("F the sweep meets 0-4 edges on the texture (%d/%d/%d/%d/%d)"):format(unpack(edges)))
	local texture = V.texture(v, ox, oy, "m.png", {rects = rects})
	local valid, count = fills_valid(texture, size, size)
	check(valid and count == #rects and count > 400, "F every fill of the sweep is valid (" ..
		count .. " fills)")
	valid_all = valid_all and valid
	check(texture:find("#ffd040cc", 1, true) and select(2, texture:find("%^%[mask:m%.png$")),
		"F the frames' colour in the recipe, the mask last")
	-- each edge of the texture on its own: a claim straddling it loses the
	-- edge outside and keeps three, clipped
	local cases = {
		west = {math.floor(mid_x - half), mid_z}, east = {math.floor(mid_x + half), mid_z},
		north = {mid_x, math.floor(mid_z + half)}, south = {mid_x, math.floor(mid_z - half)},
	}
	for name, at in pairs(cases) do
		local got = V.claim_frame(v, ox, oy, at[1], at[2], R, "#fff", {})
		local inside = true
		for _, rect in ipairs(got) do
			inside = inside and rect.x >= 0 and rect.y >= 0 and rect.x + rect.w <= size and
				rect.y + rect.h <= size
		end
		check(#got == 3 and inside, "F straddling the " .. name .. " edge: three edges, clipped")
	end
	check(#V.claim_frame(v, ox, oy, math.floor(mid_x + half + 2 * R), mid_z, R, "#fff", {}) == 0,
		"F fully outside: nothing")
	-- exactly on the west edge: a box ending at the texture's first column
	-- leaves nothing; one column further in leaves one pixel column
	local ending, one = false, false
	for cx = math.floor(mid_x - half - R - 20), math.floor(mid_x - half - R + 20) do
		local _, _, r = box(cx, mid_z)
		local got = V.claim_frame(v, ox, oy, cx, mid_z, R, "#fff", {})
		if r == 0 then
			ending = true
			check(#got == 0, "F a box ending on the west edge: nothing")
		elseif r == 1 then
			one = true
			local column = #got == 3
			for _, rect in ipairs(got) do column = column and rect.x == 0 and rect.w == 1 end
			check(column, "F one column on the texture: three one-pixel edges in it")
		end
	end
	check(ending and one, "F both edge cases met")
	-- the frame stays inside claim_rect's rectangle wherever it is clipped
	local ok = true
	for dx = -half - R, half + R, 11 do
		local cx = math.floor(mid_x + dx)
		local rect = V.claim_rect(v, ox, oy, cx, mid_z, R)
		for _, edge in ipairs(V.claim_frame(v, ox, oy, cx, mid_z, R, "#fff", {})) do
			ok = ok and rect and edge.x >= rect.x and edge.x + edge.w <= rect.x + rect.w
		end
	end
	check(ok, "F the frame inside the claim's red rectangle of claim mode")
end

-- ---------------------------------------------------------------------------
-- F  frames, the minimap at runtime
-- ---------------------------------------------------------------------------
joins, leaves, steps = {}, {}, {}
local text = assert(io.open(repo .. "/mods/PLAYER/grug_map/base.lua", "rb")):read("*a")
local B = assert(loadstring(text, "@base.lua"))()
local factions = {}
model = registry({storage = new_storage(), now = function() return clock end})
model.load()
rawset(_G, "grug_core", {DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125,
	faction_ids = {"accord", "throng"},
	settlement_socket_settlements = function() return {} end,
	settlement_sockets_at = function() return {} end,
	start_identities = function() return {} end})
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
rawset(_G, "grug_factions", {get_faction = function(p) return factions[p:get_player_name()] end,
	register_on_faction_chosen = function() end})
rawset(_G, "grug_quests", {marker_states = function() return {}, 1 end,
	register_on_markers_changed = function() end})
rawset(_G, "grug_parties", {view = function() return nil end, register_on_change = function() end})
rawset(_G, "grug_home", {get = function() return nil end, known_waypoints = function() return {} end,
	claim_waypoint = function() return nil end})
rawset(_G, "grug_housing", {STONE_ITEM = "grug_housing:claim_stone", RADIUS = model.RADIUS,
	claims_in = model.claims_in, claim_set_version = model.claim_set_version})
rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua"),
	location = {text_of = function() return "Somewhere" end}})
grug_map.base = B
dofile(repo .. "/mods/PLAYER/grug_map/minimap.lua")
local minimap = grug_map.minimap
minimap.install({minimap = {quality = "normal", width = 1080, height = 960,
	tiles = B.tiles(1080, 960, B.MINI_PREFIX),
	claim = {accord = B.tiles(1080, 960, B.CLAIM_PREFIX .. "_accord"),
		throng = B.tiles(1080, 960, B.CLAIM_PREFIX .. "_throng")}}})
check(minimap.available(), "F the minimap is available")
do
	local OWN, OTHER = "#40d04acc", "#f0d040cc"
	local RED = ("#%02x%02x%02x%02x"):format(unpack(B.CLAIM_RED))
	local view = minimap.geometry()
	local size = view.combined
	local me = join(new_player("me", {x = 100.3, y = 10, z = -200.6}))
	windows.me = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	factions.me = "accord"
	local function count(str, pattern)
		local n = 0
		for _ in str:gmatch(pattern) do n = n + 1 end
		return n
	end
	local function map_text()
		for _, def in pairs(me.huds) do
			if def.z_index == 11 then return def.text end
		end
	end
	step(1)
	local plain = minimap.texture_of(me)
	local cx, cy = V.cell(view, me.pos.x, me.pos.z)
	local ox, oy = V.origin(view, cx, cy)
	eq(plain, V.texture(view, ox, oy, minimap.mask, nil), "F no claim near: the plain map's string")
	-- another player's draft near: its frame in yellow
	local other = model.create("other", {x = 160, y = 10, z = -230})
	step(0.1)
	local with_other = minimap.texture_of(me)
	eq(count(with_other, "%[fill"), 4, "F another's draft: four edges")
	eq(count(with_other, OTHER), 4, "F ...in yellow")
	eq(map_text(), with_other, "F ...shown at once")
	check(fills_valid(with_other, size, size), "F ...valid fills")
	check(with_other:find("^[fill", 1, true) < with_other:find("^[mask", 1, true),
		"F the frames before the mask (cut at the bezel)")
	sent = 0
	step(1)
	eq(sent, 0, "F a still player with frames sends nothing")
	-- the own claim: green, drawn last
	local mine = model.create("me", {x = -10, y = 10, z = -200})
	step(0.1)
	local with_own = minimap.texture_of(me)
	eq(count(with_own, OWN), 4, "F the own claim in green")
	eq(count(with_own, OTHER), 4, "F the other still yellow")
	check(with_own:find(OTHER, 1, true) < with_own:find(OWN, 1, true) and
		not with_own:sub(with_own:find(OWN, 1, true)):find(OTHER, 1, true),
		"F the own frame drawn after the others'")
	-- all states: activation and expiry change nothing
	model.activate(mine, 5)
	model.activate(other, 5)
	step(0.1)
	eq(minimap.texture_of(me), with_own, "F active claims: the same frames")
	clock = clock + 6 * model.LUMP_SECONDS
	model.expiry_scan()
	step(0.1)
	eq(minimap.texture_of(me), with_own, "F expired claims: the same frames")
	-- a claim elsewhere: the same string, nothing sent
	sent = 0
	local far = model.create("far", {x = 2500, y = 10, z = 2500})
	step(0.1)
	eq(minimap.texture_of(me), with_own, "F a claim elsewhere: the same string")
	eq(sent, 0, "F a claim elsewhere: nothing sent")
	model.remove(far, "picked_up")
	step(0.1)
	eq(minimap.texture_of(me), with_own, "F the same claims: the same string")
	-- another player sees the colours the other way round
	local them = join(new_player("other", {x = 100.3, y = 10, z = -200.6}))
	windows.other = windows.me
	factions.other = "accord"
	step(0.1)
	local theirs = minimap.texture_of(them)
	check(count(theirs, OWN) == 4 and count(theirs, OTHER) == 4 and theirs ~= with_own,
		"F the other player: their own green, mine yellow")
	for _, fn in ipairs(leaves) do fn(them) end
	players.other = nil
	-- claim mode stays CMAP's: all claims red, no frame
	me.wield = "grug_housing:claim_stone"
	step(0.1)
	local held = minimap.texture_of(me)
	check(held:find("grug_map_claim_accord_", 1, true) and count(held, "%[fill") == 2 and
		count(held, RED) == 2 and not held:find(OWN, 1, true) and not held:find(OTHER, 1, true),
		"F claim mode: the overlay and one red fill per claim, no frame")
	me.wield = ""
	step(0.1)
	eq(minimap.texture_of(me), with_own, "F the stone put away: the frames again")
	-- a claim's removal takes its frame
	model.remove(other, "picked_up")
	step(0.1)
	local only_own = minimap.texture_of(me)
	check(count(only_own, OTHER) == 0 and count(only_own, OWN) == 4,
		"F the other claim removed: its frame gone")
	model.remove(mine, "picked_up")
	step(0.1)
	eq(minimap.texture_of(me), plain, "F no claim left: the plain map again")
end

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R502 HOME PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print("R502 HOME PORTABLE PASS checks=" .. checks)
