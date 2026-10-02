-- Round 27 (WP50) own minimap and map quality, portable test (LuaJIT).
--
--   luajit tools/r27_minimap/portable_test.lua [repo]
--
-- Loads the REAL grug_core hud_layout.lua, grug_map atlas.lua, base.lua
-- (tiling, mask, quality setting; not the render, which needs a world: see
-- render_base.lua), minimap_view.lua, minimap.lua and page.lua on a fake
-- engine. Checks:
--   L  layout: the minimap box is the native minimap's box (25 % of the
--      window height, 10 HUD px from the top and right edges), so the quest
--      list clearance holds; it follows window size and HUD scaling;
--   B  base: quality setting and fallback, tiles (<= 512 px, cover the image
--      exactly), the Map tab's combined texture, the round mask;
--   G  geometry (glide): window ~880 nodes per quality; the cell texture
--      covers the hole wherever the player is in the cell and the bezel
--      covers its overhang; the bezel fits the native box at usual window
--      sizes; walks along every axis keep the player's pixel on the centre
--      and every cell swap lines the new texture up with the old one to the
--      pixel (seam-free); every texture needs at most 4 tiles; distinct
--      textures per walk (the bounded client texture cache); rim arrows;
--   R  runtime: native minimap off on join; elements created; only changes
--      are sent (a still player sends nothing); the arrow stays centred and
--      the map and markers move together; a new texture only on a new cell;
--      markers of the ruling-8 kinds inside the hole only, quest states as
--      icons; party members inside as heading arrows, outside as rim arrows
--      on the bezel; window resize relayouts; the Map tab switch hides and
--      shows the minimap and persists in meta; every texture exists;
--   P  page: region label boxes tall enough for no scrollbar (ruling 12).
-- Prints "R27 MINIMAP PORTABLE PASS checks=<n>" or the failures, plus the
-- measured per-update cost as a comparison.
local repo = arg[1] or "."
-- `debug` as the second argument prints the first uncovered pixel
local DEBUG = arg[2] == "debug"
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- ---------------------------------------------------------------------------
-- fake engine
-- ---------------------------------------------------------------------------
local settings, media, written, joins, steps, quest_changes = {}, {}, {}, {}, {}, {}
local windows = {}
local now = 0
local function new_player(name, pos, yaw)
	local meta = {}
	local p = {name = name, pos = pos, yaw = yaw or 0, huds = {}, next_id = 0,
		sent = 0, flags = {}}
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_look_horizontal() return self.yaw end
	function p:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end}
	end
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
	function p:hud_remove(id) self.huds[id] = nil end
	function p:hud_set_flags(flags) for k, v in pairs(flags) do self.flags[k] = v end end
	function p:set_minimap_modes(modes, selected) self.modes, self.selected = modes, selected end
	return p
end
local players = {}
local function connected()
	local list = {}
	for _, p in pairs(players) do list[#list + 1] = p end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

local us = 0
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(mod)
		local roots = {grug_map = "/mods/PLAYER/grug_map", grug_jobs = "/mods/PLAYER/grug_jobs",
			grug_mounts = "/mods/PLAYER/grug_mounts", grug_core = "/mods/CORE/grug_core"}
		return roots[mod] and repo .. roots[mod] or nil
	end,
	get_modnames = function() return {"grug_core", "grug_jobs", "grug_map", "grug_mounts"} end,
	get_worldpath = function() return "/nonexistent-world" end,
	get_us_time = function()
		local ok, ffi = pcall(require, "ffi")
		if ok then
			if not rawget(_G, "__r27_tv") then
				ffi.cdef("typedef struct { long s; long u; } r27t; int gettimeofday(r27t*, void*);")
				rawset(_G, "__r27_tv", true)
			end
			local tv = ffi.new("r27t")
			ffi.C.gettimeofday(tv, nil)
			return tonumber(tv.s) * 1e6 + tonumber(tv.u)
		end
		us = us + 1
		return us
	end,
	log = function() end,
	settings = {get = function(_, key) return settings[key] end},
	encode_png = function(w, h, data)
		return {w = w, h = h, data = data}
	end,
	safe_file_write = function(path, data) written[path] = data return true end,
	dynamic_add_media = function(def) media[#media + 1] = def.filename return true end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	register_on_mods_loaded = function() end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	get_connected_players = connected,
	get_player_by_name = function(name) return players[name] end,
	get_player_window_information = function(name) return windows[name] end,
	formspec_escape = function(text)
		return (text:gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
			:gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	registered_entities = {},
})
rawset(_G, "grug_core", {
	zone_authority_installed = function() return false end,
	settlement_socket_settlements = function() return {} end,
})
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
local layout = grug_core.hud_layout

local QUESTS = {}
rawset(_G, "grug_quests", {registered_npcs = {},
	marker_state = function(_, id) return QUESTS[id] end,
	register_on_change = function(fn) quest_changes[#quest_changes + 1] = fn end})
local PARTY = {}
local party_views, party_changes = 0, {}
rawset(_G, "grug_parties", {view = function(player)
	party_views = party_views + 1
	if #PARTY == 0 then return nil end
	local members = {{name = player:get_player_name()}}
	for _, name in ipairs(PARTY) do members[#members + 1] = {name = name} end
	return {members = members}
end, register_on_change = function(fn) party_changes[#party_changes + 1] = fn end})
local HOME
rawset(_G, "grug_home", {get = function() return HOME end,
	locations = function()
		return {{id = "highcourt", label = "Highcourt", pos = {x = -120, y = 20, z = -1515}},
			{id = "far", label = "Far Inn", pos = {x = 3000, y = 20, z = 3000}}}
	end, remaining = function() return 0 end, is_pending = function() return false end,
	known_waypoints = function() return {} end})
rawset(_G, "grug_zones", {at = function() return nil end})
rawset(_G, "grug_inventory", {UI = {width = 10.4, height = 11.1}})
local page
rawset(_G, "sfinv", {register_page = function(_, p) page = p end,
	make_formspec = function(_, _, fs) return fs end, contexts = {},
	set_page = function() end, set_player_inventory_formspec = function() end,
	inventory_suspended = function() return false end})

-- ---------------------------------------------------------------------------
-- L: layout
-- ---------------------------------------------------------------------------
do
	local box = layout.minimap_box({size = {x = 1920, y = 1080}, real_hud_scaling = 1,
		real_gui_scaling = 1})
	check(box.size == 270 and near(box.center_x, 1920 - 10 - 135) and
		near(box.center_y, 10 + 135), "L 1080p box 270 px at the native place")
	-- Native: bottom = 0.25 H + 10 hud (builtin/game/hud.lua offset 10, size -25).
	local big = layout.minimap_box({size = {x = 2560, y = 1440}, real_hud_scaling = 2})
	check(big.size == 360 and near(big.center_y + big.size / 2, 0.25 * 1440 + 20) and
		near(big.center_x + big.size / 2, 2560 - 20), "L bottom and right edge as native at HUD 2")
	local none = layout.minimap_box(nil)
	check(none.size == 180 and none.hud == 1, "L no window information: 1280x720")
	check(layout.anchors.quest_list.position.y == 0.5, "L quest list anchor unchanged")
end

-- ---------------------------------------------------------------------------
-- B: base
-- ---------------------------------------------------------------------------
rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")})
local atlas = grug_map.atlas
local base = dofile(repo .. "/mods/PLAYER/grug_map/base.lua")
grug_map.base = base
check(base.quality() == "normal", "B default quality normal")
settings.grug_map_quality = "high"
check(base.quality() == "high", "B quality high from the setting")
settings.grug_map_quality = "ultra"
check(base.quality() == "normal", "B unknown quality falls back to normal")
settings.grug_map_quality = nil
for quality, spec in pairs(base.QUALITY) do
	check(spec.width <= 4096 and spec.height <= 4096, "B " .. quality .. " edges <= 4096")
	local tiles = base.tiles(spec.width, spec.height)
	local area, ok = 0, true
	for _, t in ipairs(tiles) do
		area = area + t.w * t.h
		ok = ok and t.w <= base.TILE and t.h <= base.TILE and t.w > 0 and t.h > 0 and
			t.x + t.w <= spec.width and t.y + t.h <= spec.height
	end
	check(ok and area == spec.width * spec.height, "B " .. quality .. " tiles cover the base")
	local texture = base.combined_texture(spec.width, spec.height, tiles)
	check(texture:sub(1, 9) == "[combine:" and select(2, texture:gsub("=grug_map_base_", "")) ==
		#tiles, "B " .. quality .. " Map tab texture combines every tile")
end
check(#base.tiles(1080, 960) == 6 and #base.tiles(3600, 3200) == 56, "B tile counts 6 / 56")
check(base.spec("high").width == 3600 and base.spec("normal").relief_step == 8 and
	base.spec("nonsense").quality == "normal", "B spec")
do
	local png = base.mask_png(135, 2)
	local function alpha(i, j) return png.data:byte((j * 135 + i) * 4 + 4) end
	check(png.w == 135 and png.h == 135 and #png.data == 135 * 135 * 4, "B mask size")
	check(alpha(67, 67) == 255 and alpha(0, 0) == 0 and alpha(134, 67) == 0 and
		alpha(67, 3) == 255, "B mask is a disc")
	check(png.data:byte(1) == 255 and png.data:byte(2) == 255, "B mask is white")
end

-- ---------------------------------------------------------------------------
-- G: geometry
-- ---------------------------------------------------------------------------
local V = dofile(repo .. "/mods/PLAYER/grug_map/minimap_view.lua")
local bounds = atlas.view()

-- What the client shows, emulated: `[resize` is CImage::copyToScaling
-- (irr/src/CImage.cpp:185: an exact multiple steps src/dst from 0, any
-- other size keeps the border pixels, stepping (src-1)/(dst-1) from 0.5),
-- and the HUD draws the texture with nearest sampling (gui_scaling_filter
-- off). `index[u]` is the combined pixel texel u holds.
local function resize_index(src, dst)
	local index, step, start = {}, nil, 0
	if src == dst then
		for u = 0, dst - 1 do index[u] = u end
		return index
	end
	if dst % src == 0 then step = src / dst else step, start = (src - 1) / (dst - 1), 0.5 end
	local at = start
	for u = 0, dst - 1 do index[u] = math.floor(at) at = at + step end
	return index
end
-- The base pixel (x, y) the screen pixel sx/sy shows, the texel, and
-- whether the texel is fully opaque in the mask; nil outside the texture.
local function shown(v, frame, index, mask, cx, cy, mx, my, sx, sy)
	local u = math.floor((sx + 0.5 - mx) * v.pixels / frame.drawn)
	local w = math.floor((sy + 0.5 - my) * v.pixels / frame.drawn)
	if u < 0 or w < 0 or u >= v.pixels or w >= v.pixels then return nil end
	local ox, oy = V.origin(v, cx, cy)
	local opaque = mask:byte((w * v.pixels + u) * 4 + 4) == 255
	return ox + index[u], oy + index[w], opaque
end
local views = {}
local WINDOWS = {{x = 1280, y = 720, hud = 1}, {x = 1920, y = 1080, hud = 1},
	{x = 1920, y = 1080, hud = 0.75}, {x = 1280, y = 720, hud = 2},
	{x = 2560, y = 1440, hud = 1}, {x = 2560, y = 1440, hud = 2}, {x = 3840, y = 2160, hud = 2},
	{x = 1024, y = 600, hud = 1}}
for quality, spec in pairs(base.QUALITY) do
	local info = {quality = quality, width = spec.width, height = spec.height,
		tiles = base.tiles(spec.width, spec.height)}
	local v = V.new(info, bounds)
	views[quality] = v
	local expected = quality == "normal" and 132 or 440
	check(v.crop == expected, "G " .. quality .. " window " .. v.crop .. " px")
	check(near(v.crop * v.npp, 880, 5), "G " .. quality .. " window ~880 nodes")
	check(v.texture % v.grid == 0 and v.texture <= base.TILE,
		"G " .. quality .. " texture " .. v.texture .. " px, whole cells, fits a tile")
	-- the disc covers the hole at the worst offset; the bezel covers the disc
	check(v.texture / 2 - v.d >= v.crop / 2 and v.texture / 2 + v.d <= V.BEZEL_OPAQUE * v.outer,
		("G %s hole %.1f <= cover %.1f, disc reach %.1f <= opaque bezel %.1f"):format(quality,
		v.crop / 2, v.texture / 2 - v.d, v.texture / 2 + v.d, V.BEZEL_OPAQUE * v.outer))
	-- the player is never further than d from the texture centre
	local worst = 0
	for x = -3600, 3600, 37 do
		for z = -3200, 3200, 41 do
			local cx, cy = V.cell(v, x, z)
			local ox, oy = V.origin(v, cx, cy)
			local px, py = V.base_pixel(v, x, z)
			local dx, dy = px - ox - v.texture / 2, py - oy - v.texture / 2
			worst = math.max(worst, math.sqrt(dx * dx + dy * dy))
		end
	end
	check(worst <= v.d + 1e-9, ("G %s player at most %.2f px from the texture centre (d %.2f)"):
		format(quality, worst, v.d))
	-- frames: bezel inside the native box, whole-pixel sizes, f a multiple of 1/grid
	local frames_ok, smallest = true, 1
	for _, w in ipairs(WINDOWS) do
		local box = layout.minimap_box({size = {x = w.x, y = w.y}, real_hud_scaling = w.hud})
		local frame = V.frame(v, box)
		smallest = math.min(smallest, frame.diameter / box.size)
		frames_ok = frames_ok and frame.diameter <= box.size and
			frame.drawn % 1 == 0 and near(frame.f * v.grid, frame.k) and
			near(frame.center_x + frame.diameter / 2, box.center_x + box.size / 2) and
			near(frame.center_y - frame.diameter / 2, box.center_y - box.size / 2) and
			-- cover margin: a texel (the mask's soft edge) plus half a screen pixel
			v.texture / 2 - v.d - v.crop / 2 >= v.reduce + 0.5 / frame.f and
			-- the disc at its furthest, plus a pixel of rounding, stays under
			-- the opaque part of the drawn bezel
			(v.texture / 2 + v.d) * frame.f + 1 <= V.BEZEL_OPAQUE * frame.diameter / 2
	end
	check(frames_ok, "G " .. quality .. " frames fit the box top-right, whole pixels")
	check(smallest >= 0.85, ("G %s bezel at least 85 %% of the box (%.2f)"):format(quality, smallest))
	-- walks: the player's pixel on the centre; at every cell swap each
	-- screen pixel of the hole shows the same base pixel in the old and the
	-- new texture (emulated sampling, so a resize that shifts texels fails)
	local index = resize_index(v.combined, v.pixels)
	local mask = base.mask_png(v.pixels, 0).data
	local centred, seams, swaps = true, true, 0
	for _, w in ipairs(WINDOWS) do
		local box = layout.minimap_box({size = {x = w.x, y = w.y}, real_hud_scaling = w.hud})
		local frame = V.frame(v, box)
		local samples = {}
		for sy = math.floor(frame.center_y - frame.hole), math.ceil(frame.center_y + frame.hole), 3 do
			for sx = math.floor(frame.center_x - frame.hole), math.ceil(frame.center_x + frame.hole), 3 do
				local dx, dy = sx + 0.5 - frame.center_x, sy + 0.5 - frame.center_y
				if dx * dx + dy * dy <= frame.hole * frame.hole then
					samples[#samples + 1] = {sx, sy}
				end
			end
		end
		for _, dir in ipairs({{1, 0}, {0, 1}, {1, 1}, {-1, 0.37}, {0.21, -1}}) do
			local x, z = -1234.5, 876.25
			local last
			for _ = 1, 3000 do
				x, z = x + dir[1] * 0.17, z + dir[2] * 0.17
				local px, py = V.base_pixel(v, x, z)
				local cx, cy = V.cell(v, x, z)
				local ox, oy = V.origin(v, cx, cy)
				local mx, my = V.map_corner(v, frame, cx, cy, px, py)
				local sx, sy = mx + (px - ox) * frame.f, my + (py - oy) * frame.f
				centred = centred and math.abs(sx - frame.arrow_x) <= 0.5 + 1e-9 and
					math.abs(sy - frame.arrow_y) <= 0.5 + 1e-9
				if last and (last.cx ~= cx or last.cy ~= cy) then
					-- the old texture at THIS position, as drawn one step later
					local lx, ly = V.map_corner(v, frame, last.cx, last.cy, px, py)
					swaps = swaps + 1
					for _, sample in ipairs(samples) do
						local ax, ay = shown(v, frame, index, mask, last.cx, last.cy, lx, ly,
							sample[1], sample[2])
						local bx, by = shown(v, frame, index, mask, cx, cy, mx, my,
							sample[1], sample[2])
						if ax ~= bx or ay ~= by then seams = false break end
					end
				end
				last = {cx = cx, cy = cy, ox = ox, oy = oy}
			end
		end
	end
	check(centred, "G " .. quality .. " player's pixel on the centre along every walk")
	-- cover: with the player at any corner of a cell, every screen pixel of
	-- the hole (plus half a pixel for the bezel's soft inner edge) shows a
	-- fully opaque texel of the masked texture
	local covered, worst = true, nil
	for _, w in ipairs(WINDOWS) do
		local box = layout.minimap_box({size = {x = w.x, y = w.y}, real_hud_scaling = w.hud})
		local frame = V.frame(v, box)
		local reach = frame.hole + 0.5
		for _, corner in ipairs({{0.001, 0.001}, {v.grid - 0.001, 0.001},
				{0.001, v.grid - 0.001}, {v.grid - 0.001, v.grid - 0.001}, {v.grid / 2, 0.001}}) do
			local cx, cy = 40, 30
			local px, py = cx * v.grid + corner[1], cy * v.grid + corner[2]
			local mx, my = V.map_corner(v, frame, cx, cy, px, py)
			for sy = math.floor(frame.center_y - reach), math.ceil(frame.center_y + reach) do
				for sx = math.floor(frame.center_x - reach), math.ceil(frame.center_x + reach) do
					local dx, dy = sx + 0.5 - frame.center_x, sy + 0.5 - frame.center_y
					if dx * dx + dy * dy <= reach * reach then
						local bx, _, opaque = shown(v, frame, index, mask, cx, cy, mx, my, sx, sy)
						if not bx or not opaque then
							if DEBUG and not worst then
								io.stderr:write(table.concat({quality, w.x, w.y, w.hud, corner[1], corner[2], sx, sy,
									math.sqrt(dx * dx + dy * dy), frame.hole, tostring(bx), tostring(opaque), frame.f, mx, my}, " ") .. "\n")
							end
							covered = false
							worst = worst or ("%dx%d hud %s"):format(w.x, w.y, w.hud)
						end
					end
				end
			end
		end
	end
	check(covered, "G " .. quality .. " hole fully covered at every cell corner" ..
		(worst and (" (not at " .. worst .. ")") or ""))
	check(seams and swaps > 100, ("G %s %d cell swaps seam-free"):format(quality, swaps))
	-- every cell's texture needs at most four tiles
	local most = 0
	for cx = -1, math.ceil(spec.width / v.grid) do
		for cy = -1, math.ceil(spec.height / v.grid) do
			local ox, oy = V.origin(v, cx, cy)
			local _, count = V.texture(v, ox, oy, "m.png"):gsub("=grug_map_base_", "")
			most = math.max(most, count)
		end
	end
	check(most <= 4, "G " .. quality .. " at most 4 tiles per texture (" .. most .. ")")
	-- half resolution at high: a whole number of texture pixels per cell and
	-- per origin, so texels line up across swaps too
	do
		local ox, oy = V.origin(v, 10, 10)
		local text = V.texture(v, ox, oy, "m.png")
		local resized = text:find(("^[resize:%dx%d^[mask:m.png"):format(v.pixels, v.pixels), 1, true)
		check(v.reduce == (quality == "high" and 2 or 1) and v.pixels * v.reduce == v.texture and
			v.grid % v.reduce == 0 and ox % v.reduce == 0 and
			(v.reduce > 1) == (resized ~= nil), ("G %s texture %d px (%d base px)%s"):format(
			quality, v.pixels, v.texture, v.reduce > 1 and ", halved on the client" or ""))
	end
	-- a 3000-node walk: distinct textures = client textures created
	local seen, count = {}, 0
	for x = -1500, 1500 do
		local cx, cy = V.cell(v, x, -1500)
		local key = cx .. "," .. cy
		if not seen[key] then seen[key], count = true, count + 1 end
	end
	v.walk = count
	v.walk_bytes = count * v.pixels * v.pixels * 4
	check(count <= 3000 / (v.grid * v.npp) + 2, ("G %s 3000-node walk makes %d textures (%.1f MB)"):
		format(quality, count, v.walk_bytes / 1048576))
end
do
	local frame = V.frame(views.normal, layout.minimap_box({size = {x = 1920, y = 1080},
		real_hud_scaling = 1}))
	local function index(dx, dy) return select(3, V.rim(frame, dx, dy)) end
	check(index(0, -100) == 0 and index(100, 0) == 4 and index(0, 100) == 8 and
		index(-100, 0) == 12 and index(70, -70) == 2, "G rim frames clockwise from north")
	local rx, ry = V.rim(frame, 500, 0)
	check(near(rx - frame.center_x, (frame.hole + frame.diameter / 2) / 2) and
		near(ry, frame.center_y), "G rim arrow on the middle of the bezel")
end

-- ---------------------------------------------------------------------------
-- R: runtime
-- ---------------------------------------------------------------------------
-- Markers: Highcourt services, a quest giver, homes, a king (not shown).
local settlements = {{key = "highcourt", race_id = "human", anchor = {x = 0, z = -1500}}}
local sockets = {highcourt = {
	{id = "t1", role = "trainer", profession = "tailor", pos = {x = 75, y = 30, z = -1530}},
	{id = "steward", role = "housing_manager", pos = {x = -25, y = 30, z = -1435}},
	{id = "riding", role = "riding_trainer", pos = {x = 60, y = 30, z = -1420}},
	{id = "throne", role = "king", pos = {x = 10, y = 30, z = -1480}},
	{id = "giver", role = "quest", pos = {x = 30, y = 30, z = -1470}},
	{id = "far_giver", role = "quest", pos = {x = 2000, y = 30, z = 2000}},
}}
-- A crowded town far away: 30 trainers, a Steward and a quest giver, more
-- markers than the minimap has slots.
settlements[2] = {key = "crowd", race_id = "human", anchor = {x = -2000, z = -2000}}
sockets.crowd = {{id = "steward", role = "housing_manager", pos = {x = -2010, y = 30, z = -2010}},
	{id = "giver", role = "quest", pos = {x = -1990, y = 30, z = -1995}}}
for i = 1, 30 do
	sockets.crowd[#sockets.crowd + 1] = {id = "t" .. i, role = "trainer", profession = "tailor",
		pos = {x = -2000 + (i % 6) * 20 - 50, y = 30, z = -2000 + math.floor(i / 6) * 20 - 50}}
end
grug_core.settlement_socket_settlements = function() return settlements end
grug_core.settlement_sockets_at = function(key) return sockets[key] or {} end
core.registered_entities["grug_mobs:king_human"] = {description = "King"}
rawset(_G, "grug_jobs", {PROFESSIONS = {tailor = {name = "Tailor"}}})
rawset(_G, "grug_mobs", {dragon_map_markers = function() return {} end})
grug_quests.registered_npcs = {
	giver = {settlement = "highcourt", socket = "giver", title = "Giver"},
	far = {settlement = "highcourt", socket = "far_giver", title = "Far"},
	crowd = {settlement = "crowd", socket = "giver", title = "Crowd"},
}
QUESTS.giver, QUESTS.far, QUESTS.crowd = "available", "available", "available"

local loaded = {}
core.register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end
local installed = {quality = "normal", width = 1080, height = 960,
	tiles = base.tiles(1080, 960)}
installed.texture = base.combined_texture(1080, 960, installed.tiles)
atlas.set_base_texture(installed.texture)
dofile(repo .. "/mods/PLAYER/grug_map/minimap.lua")
local minimap = grug_map.minimap
minimap.install(installed)
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
dofile(repo .. "/mods/PLAYER/grug_map/page.lua")
for _, fn in ipairs(loaded) do fn() end
check(media[#media] == "grug_map_minimap_mask.png", "R mask announced as media")

local function step(dt)
	now = now + dt
	for _, fn in ipairs(steps) do fn(dt) end
end
local function join(p)
	players[p.name] = p
	for _, fn in ipairs(joins) do fn(p) end
end

local me = new_player("me", {x = -60, y = 20, z = -1560}, 0)
windows.me = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
join(me)
check(me.flags.minimap == false and me.flags.minimap_radar == false,
	"R native minimap and radar flags off")
check(me.modes and #me.modes == 1 and me.modes[1].type == "off", "R only the off mode")
step(0.25)

local function elements(p)
	local list = {}
	for id, def in pairs(p.huds) do list[#list + 1] = {id = id, def = def} end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end
local function by_text(p, pattern)
	local out = {}
	for _, e in ipairs(elements(p)) do
		if type(e.def.text) == "string" and e.def.text:find(pattern) then out[#out + 1] = e.def end
	end
	return out
end
local function screen(def, p)
	local w = windows[p.name]
	return def.position.x * w.size.x, def.position.y * w.size.y
end

local v = views.normal
local function frame_of(p)
	return V.frame(v, layout.minimap_box(windows[p.name]))
end
local maps = by_text(me, "^%[combine:" .. views.normal.pixels .. "x" .. views.normal.pixels .. ":")
check(#maps == 1 and maps[1].text:find("%^%[mask:grug_map_minimap_mask%.png$"),
	"R one map element, a cell texture cut to a disc")
local map = maps[1]
local frame = frame_of(me)
check(map and map.alignment.x == 1 and
	math.floor(views.normal.pixels * map.scale.x * 1) == frame.drawn, "R map drawn " .. frame.drawn .. " px")
local compass
for _, e in ipairs(elements(me)) do if e.def.type == "compass" then compass = e.def end end
check(compass and compass.text == "grug_map_heading_gold_00.png" and compass.size.x == 24,
	"R player arrow is a 24 px compass element")
local function centre_of_player()
	local mx, my = screen(map, me)
	local px, py = V.base_pixel(v, me.pos.x, me.pos.z)
	local cx, cy = V.cell(v, me.pos.x, me.pos.z)
	local ox, oy = V.origin(v, cx, cy)
	return mx + (px - ox) * frame.f, my + (py - oy) * frame.f
end
do
	local ax, ay = screen(compass, me)
	local sx, sy = centre_of_player()
	check(near(ax, math.floor(frame.center_x + 0.5), 1e-6) and
		math.abs(sx - ax) <= 0.5 + 1e-6 and math.abs(sy - ay) <= 0.5 + 1e-6,
		"R arrow centred on the player's own map pixel")
end
local bezels = by_text(me, "^grug_map_minimap_bezel%.png$")
check(#bezels == 1 and near(screen(bezels[1], me) + frame.diameter, 1920 - 10, 1e-6) and
	math.floor(256 * bezels[1].scale.x) == frame.diameter, "R bezel at the box's top right")
check(#by_text(me, "^grug_map_minimap_mask%.png%^%[multiply:") == 1, "R sea background disc")
local function has(texture) return #by_text(me, "^" .. texture:gsub("%.", "%%.") .. "$") end
check(has("grug_map_quest_available.png") == 1, "R near quest giver shown, far one not")
check(has("grug_map_housing_steward.png") == 1, "R Housing Steward shown")
check(has("grug_jobs_book.png") == 1 and has("grug_mounts_icon_human.png") == 1,
	"R trainers shown (profession and riding)")
check(has("grug_map_innkeeper.png") == 1, "R innkeeper shown (the far inn is not)")
check(has("grug_mobs_item_fallen_crown.png") == 0, "R kings stay on the Map tab")
do
	local riding = by_text(me, "^grug_mounts_icon_human%.png$")[1]
	local book = by_text(me, "^grug_jobs_book%.png$")[1]
	check(riding and book and near(riding.scale.x * 64, 16) and near(book.scale.x * 16, 16),
		"R icons drawn 16 px whatever their texture size")
end

-- Still player: nothing is sent.
local before = me.sent
step(0.25) step(0.25) step(1.0)
check(me.sent == before, "R a still player sends nothing (" .. (me.sent - before) .. ")")

-- Moving: the arrow stays, the map and the markers move by the same pixels;
-- a new cell changes the texture.
local map_text = map.text
local compass_x = compass.position.x
local book = by_text(me, "^grug_jobs_book%.png$")[1]
local bx0, by0 = screen(book, me)
local mx0, my0 = screen(map, me)
me.pos.x = me.pos.x + 5
step(0.09)
local bx1, by1 = screen(book, me)
local mx1, my1 = screen(map, me)
check(map.text == map_text and compass.position.x == compass_x and mx1 < mx0 and
	math.abs((bx1 - bx0) - (mx1 - mx0)) <= 1 + 1e-6 and near(by1 - by0, my1 - my0, 1 + 1e-6),
	"R walking east: arrow stays, map and markers glide west together")
me.pos.x = me.pos.x + 200
step(0.09)
check(map.text ~= map_text, "R new cell: new texture")
do
	local ax, ay = screen(compass, me)
	local sx, sy = centre_of_player()
	check(math.abs(sx - ax) <= 0.5 + 1e-6 and math.abs(sy - ay) <= 0.5 + 1e-6,
		("R after the swap the arrow is still on the player's pixel (%.2f,%.2f vs %.2f,%.2f)"):format(sx, sy, ax, ay))
end

-- Quest state: ready shows "?", a quest change refreshes at once.
QUESTS.giver = "ready"
for _, fn in ipairs(quest_changes) do fn(me) end
step(0.25)
check(has("grug_map_quest_ready.png") == 1 and has("grug_map_quest_available.png") == 0,
	"R quest change shows the ready icon")
QUESTS.giver = "active"
for _, fn in ipairs(quest_changes) do fn(me) end
step(0.25)
check(has("grug_map_quest_active.png") == 1, "R active quest icon")
QUESTS.giver = "locked"
for _, fn in ipairs(quest_changes) do fn(me) end
step(0.25)
check(has("grug_map_quest_locked.png") == 1, "R locked quest icon")

-- Home: the chosen inn is home.
HOME = {id = "highcourt", label = "Highcourt"}
step(5.0) -- the SLOW refresh picks up a new home
check(has("grug_map_home.png") == 1 and has("grug_map_innkeeper.png") == 0, "R home marker")

-- Party: one inside, one outside as a rim arrow east.
local near_friend = new_player("near", {x = 100, y = 20, z = -1450}, 0)
local far_friend = new_player("far", {x = 1300, y = 20, z = -1450}, 0)
players.near, players.far = near_friend, far_friend
PARTY = {"near", "far"}
step(0.25)
check(#by_text(me, "^grug_map_heading_cyan_%d%d%.png$") == 0,
	"R party names are cached until the party changes")
for _, fn in ipairs(party_changes) do fn("me", "join") end
do
	local views = party_views
	step(0.09) step(0.09) step(0.09)
	check(party_views == views + 1, "R one party lookup after a change, not one per step (" ..
		(party_views - views) .. ")")
end
check(#by_text(me, "^grug_map_heading_cyan_%d%d%.png$") == 1, "R party member inside: arrow")
local rim = by_text(me, "^grug_map_rim_cyan_%d%d%.png$")
check(#rim == 1, "R party member outside: rim arrow")
if rim[1] then
	local rx, ry = screen(rim[1], me)
	local index = tonumber(rim[1].text:match("(%d%d)%.png"))
	check(near(math.sqrt((rx - frame.center_x) ^ 2 + (ry - frame.center_y) ^ 2),
		(frame.hole + frame.diameter / 2) / 2, 1.5) and index >= 3 and index <= 5,
		"R rim arrow on the bezel pointing east (frame " .. tostring(index) .. ")")
end
-- At HUD scaling 2 in a small window the rim arrow is clamped to the ring.
do
	windows.me = {size = {x = 1280, y = 720}, real_hud_scaling = 2, real_gui_scaling = 1}
	step(0.09)
	local small = frame_of(me)
	local arrow = by_text(me, "^grug_map_rim_cyan_%d%d%.png$")[1]
	-- the chevron spans 21 of the texture's 32 px from tip to back
	local drawn = arrow and arrow.scale.x * 32 * 2 * 21 / 32 or 99
	local ring = small.diameter / 2 - small.hole
	check(drawn <= 0.9 * ring and drawn >= 0.8 * ring,
		("R rim arrow %.1f px fills 80-90 %% of the %.1f px ring"):format(drawn, ring))
	windows.me = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	step(0.09)
end
-- every marker and party arrow shown lies inside the hole; one walked out
-- of it is hidden
do
	local function all_inside()
		local inside, count = true, 0
		for _, e in ipairs(elements(me)) do
			local t = e.def.text
			if e.def.type == "image" and t ~= "" and not t:find("combine") and
					not t:find("bezel") and not t:find("mask") and not t:find("rim_") then
				local x, y = screen(e.def, me)
				count = count + 1
				inside = inside and math.sqrt((x - frame.center_x) ^ 2 +
					(y - frame.center_y) ^ 2) <= frame.hole
			end
		end
		return inside, count
	end
	local inside, count = all_inside()
	check(inside and count >= 5, "R markers inside the hole (" .. count .. ")")
	local saved = me.pos.x
	me.pos.x = me.pos.x - 600
	step(0.09)
	local inside2, count2 = all_inside()
	check(inside2 and count2 < count, ("R markers leaving the hole are hidden (%d -> %d)"):
		format(count, count2))
	me.pos.x = saved
	step(0.09)
end

-- A height-only resize that keeps every pixel (1080 -> 1100: same scale,
-- same bezel place) must still resend the positions: they are fractions
-- of the window.
do
	local f1 = frame_of(me)
	windows.me = {size = {x = 1920, y = 1100}, real_hud_scaling = 1, real_gui_scaling = 1}
	step(0.09)
	local f2 = frame_of(me)
	local ax, ay = screen(compass, me)
	local mx, my = screen(map, me)
	local px, py = V.base_pixel(v, me.pos.x, me.pos.z)
	local cx, cy = V.cell(v, me.pos.x, me.pos.z)
	local ox, oy = V.origin(v, cx, cy)
	local ex, ey = V.map_corner(v, f2, cx, cy, px, py)
	check(f1.f == f2.f and f1.center_y == f2.center_y and
		near(ay, math.floor(f2.center_y + 0.5), 1e-6) and near(ax, math.floor(f2.center_x + 0.5), 1e-6) and
		near(mx, ex, 1e-6) and near(my, ey, 1e-6), "R height-only resize resends the positions")
	windows.me = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	step(0.09)
end

-- Window resize: the box follows (25 % of the new height).
windows.me = {size = {x = 1280, y = 720}, real_hud_scaling = 1, real_gui_scaling = 1}
step(0.25)
do
	local small = frame_of(me)
	local bezel = by_text(me, "^grug_map_minimap_bezel%.png$")[1]
	check(math.floor(views.normal.pixels * map.scale.x) == small.drawn and small.diameter <= 180 and
		near(screen(bezel, me) + small.diameter, 1280 - 10, 1e-6), "R resize: 720p frame")
	frame = small
end

-- The Map tab switch.
local context = {}
page.on_enter(page, me, context)
local fs = page.get(page, me, context)
check(fs:find("checkbox%[[%d.]+,0%.26;grug_map_minimap;Show minimap;true%]"),
	"R Map tab switch shown, on by default")
page.on_player_receive_fields(page, me, context, {grug_map_minimap = "false"})
check(not minimap.enabled(me) and #elements(me) == 0, "R switch off removes every element")
step(0.25)
check(#elements(me) == 0, "R stays off")
fs = page.get(page, me, context)
check(fs:find("Show minimap;false%]"), "R switch shows off")
page.on_player_receive_fields(page, me, context, {grug_map_minimap = "true"})
check(minimap.enabled(me) and #by_text(me, "^%[combine:") == 1, "R switch on restores it")

-- Every texture the minimap draws exists.
do
	local missing = {}
	local function exists(name)
		for _, dir in ipairs({"/mods/PLAYER/grug_map/textures/", "/mods/PLAYER/grug_jobs/textures/",
				"/mods/PLAYER/grug_mounts/textures/"}) do
			local f = io.open(repo .. dir .. name, "rb")
			if f then f:close() return true end
		end
		return false
	end
	local names = {"grug_map_minimap_bezel.png", "grug_map_quest_available.png",
		"grug_map_quest_locked.png", "grug_map_quest_ready.png", "grug_map_quest_active.png",
		"grug_map_innkeeper.png", "grug_map_home.png", "grug_map_heading_gold_00.png"}
	for f = 0, 15 do
		names[#names + 1] = ("grug_map_rim_cyan_%02d.png"):format(f)
		names[#names + 1] = ("grug_map_heading_cyan_%02d.png"):format(f)
	end
	for _, name in ipairs(names) do
		if not exists(name) then missing[#missing + 1] = name end
	end
	check(#missing == 0, "R textures exist: " .. table.concat(missing, " "))
	local file = io.open(repo .. "/mods/PLAYER/grug_map/LICENSE-media.md", "rb")
	local text = file and file:read("*a") or ""
	if file then file:close() end
	check(text:find("render_icons.py", 1, true) and text:find("grug_map_minimap_bezel.png", 1, true),
		"R LICENSE-media rows")
end

-- ---------------------------------------------------------------------------
-- P: page
-- ---------------------------------------------------------------------------
do
	local fs1 = page.get(page, me, context)
	local low = 99
	for h in fs1:gmatch("hypertext%[[%d.%-]+,[%d.%-]+;[%d.]+,([%d.]+);grug_map_region_%d+;") do
		low = math.min(low, tonumber(h))
	end
	check(low >= 1.3, "P region label boxes >= 1.3 tall (" .. low .. ")")
end

-- ---------------------------------------------------------------------------
-- S: slots, staggering, a missing mask
-- ---------------------------------------------------------------------------
do
	-- More markers than slots: the quest giver and the Steward keep theirs,
	-- drawn in the usual order (trainers below the Steward below quests).
	local saved = {x = me.pos.x, z = me.pos.z}
	me.pos.x, me.pos.z = -2000, -2000
	step(0.25)
	local shown, order = 0, {}
	for _, e in ipairs(elements(me)) do
		local t = e.def.text
		if e.def.type == "image" and e.def.z_index and e.def.z_index > 20 and
				e.def.z_index <= 44 and t ~= "" then
			shown = shown + 1
			order[#order + 1] = {z = e.def.z_index, t = t}
		end
	end
	table.sort(order, function(a, b) return a.z < b.z end)
	check(shown == 24, "S all 24 marker slots used (" .. shown .. ")")
	check(order[#order] and order[#order].t == "grug_map_quest_available.png" and
		order[#order - 1] and order[#order - 1].t == "grug_map_housing_steward.png",
		"S the quest giver and the Steward keep a slot and draw on top")
	me.pos.x, me.pos.z = saved.x, saved.z
	step(0.25)

	-- Staggered SLOW refresh: two players ask the quest provider in
	-- different steps.
	local asked = {}
	local original = grug_quests.marker_state
	grug_quests.marker_state = function(player, id)
		asked[player:get_player_name()] = true
		return original(player, id)
	end
	local other = new_player("other", {x = 0, y = 20, z = -1500}, 0)
	windows.other = windows.me
	join(other)
	step(0.25)
	local together, steps_seen = 0, 0
	for _ = 1, 50 do
		asked = {}
		step(0.2)
		if asked.me or asked.other then steps_seen = steps_seen + 1 end
		if asked.me and asked.other then together = together + 1 end
	end
	grug_quests.marker_state = original
	check(together == 0 and steps_seen >= 4, ("S SLOW refresh staggered (%d steps with a " ..
		"refresh, %d with both)"):format(steps_seen, together))
	players.other = nil
end

-- ---------------------------------------------------------------------------
-- cost: per-player update with 2 party members and 7 markers nearby
-- ---------------------------------------------------------------------------
minimap.stats.updates, minimap.stats.us, minimap.stats.changes = 0, 0, 0
for i = 1, 200 do
	me.pos.x = me.pos.x + 0.9
	step(0.25)
	if i % 25 == 0 then step(5.0) end
end
local cost = minimap.stats.us / math.max(1, minimap.stats.updates)
print(("R27 cost: %.1f us per player update (%d updates, %.2f packets per update); " ..
	"textures per 3000 nodes: normal %d (%.1f MB), high %d (%.1f MB)"):format(cost,
	minimap.stats.updates, minimap.stats.changes / math.max(1, minimap.stats.updates),
	views.normal.walk, views.normal.walk_bytes / 1048576, views.high.walk,
	views.high.walk_bytes / 1048576))

-- A world folder that cannot be written: no mask, no minimap, the load goes
-- on and the Map tab says so. (A second copy of minimap.lua, last.)
do
	core.safe_file_write = function() return false end
	local first = grug_map.minimap
	local ok = pcall(dofile, repo .. "/mods/PLAYER/grug_map/minimap.lua")
	local second = grug_map.minimap
	local installed_ok = ok and pcall(second.install, installed)
	check(ok and installed_ok and not second.available(),
		"S unwritable mask: the load goes on, no minimap")
	local fs = page.get(page, me, context)
	check(fs:find("No minimap available", 1, true) and not fs:find("grug_map_minimap;", 1, true),
		"S Map tab says no minimap instead of the switch")
	check(first.available(), "S the working copy stays available")
	grug_map.minimap = first
end

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R27 MINIMAP PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print(("R27 MINIMAP PORTABLE PASS checks=%d"):format(checks))
