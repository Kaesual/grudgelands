-- Fix 0.50.2 lane CMAP portable test (LuaJIT): the Claim Stone preview on
-- the minimap (docs/planning/fix-0.50.2-plan.md §4).
--
--   luajit tools/r502_cmap/portable_test.lua [repo]
--
-- Loads the REAL grug_housing registry.lua and preview.lua, grug_core
-- hud_layout.lua and grug_map atlas.lua, base.lua (its render exposed as
-- render_base.lua does), minimap_view.lua and minimap.lua on a fake engine.
-- Round 86 (lane PREVIEW) replaced the per-column overlay baked into the
-- base by a preview per map chunk drawn by the minimap
-- (tools/r86_preview checks it against placement); the checks of the old
-- overlay (its render, its install, the claims' red rectangles, the
-- player's square on the arrow) went with it. Checks:
--   G  geometry: the chunk grid of a cell texture (V.chunk_cells) tiles it
--      without gap or overlap, each chunk 80 nodes at the base's scale with
--      its edges rounded to the nearest pixel, clipped at every edge of the
--      texture; every `[fill` a recipe holds passes the engine's checks (x
--      and y inside the image, width and height at least 1: imagesource.cpp
--      `[fill`, CHECK_DIM); the claims' area covers the texture;
--   V  registry: the claim-set version changes on create, remove (not on a
--      second remove), load and map reset and nowhere else (activation,
--      fuel, permissions); claims_in equals a scan of every claim's chunk;
--      the column rule (claim_mask.lua's since Round 85) with territory
--      false judges the zone alone;
--   I  install: the base announces no Claim Stone overlay and hands the
--      minimap none; the overlay tiles an older version left in the world
--      folder are removed as stale tiles;
--   M  minimap runtime: claim mode only with the stone held and a faction;
--      the cell texture draws the chunk preview; the same claims give the
--      same string, a claim elsewhere changes nothing and sends nothing; a
--      draft placed by another player shows without re-selecting the stone
--      and goes with its removal; another item restores the normal
--      texture; the line beside the bezel shows in claim mode only; a
--      switched-off minimap appears for claim mode and goes after it, its
--      side row moving beside the bezel and back.
-- Prints "R502 CMAP PORTABLE PASS checks=<n>" or the failures.
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
-- fake engine
-- ---------------------------------------------------------------------------
local joins, steps, sent = {}, {}, 0
local players, windows = {}, {}
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(mod)
		local roots = {grug_map = "/mods/PLAYER/grug_map", grug_housing = "/mods/PLAYER/grug_housing"}
		return roots[mod] and repo .. roots[mod] or nil
	end,
	get_modnames = function() return {"grug_map"} end,
	get_worldpath = function() return "/nonexistent-world" end,
	get_us_time = function() return 0 end,
	log = function() end,
	settings = {get = function() return nil end},
	-- the tile's raw RGBA stands in for its PNG
	encode_png = function(_, _, data) return data end,
	safe_file_write = function() return true end,
	dynamic_add_media = function() return true end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function() end,
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

-- ---------------------------------------------------------------------------
-- the engine's `[fill` checks (imagesource.cpp, 5.17): parse every
-- top-level part of a texture string
-- ---------------------------------------------------------------------------
local function fills_valid(texture, width, height)
	local ok, count = true, 0
	for part in (texture .. "^"):gmatch("([^%^]*)%^") do
		local w, h, x, y = part:match("^%[fill:(%d+)x(%d+):(%d+),(%d+):#%x+$")
		if part:find("^%[fill") then
			count = count + 1
			if not w then
				w, h = part:match("^%[fill:(%d+)x(%d+):#%x+$")
				x, y = 0, 0
			end
			w, h, x, y = tonumber(w), tonumber(h), tonumber(x), tonumber(y)
			if not (w and h and w >= 1 and h >= 1 and x >= 0 and y >= 0 and
					x < width and y < height) then
				ok = false
			end
		end
	end
	return ok, count
end

-- ---------------------------------------------------------------------------
-- G  geometry
-- ---------------------------------------------------------------------------
local V = dofile(repo .. "/mods/PLAYER/grug_map/minimap_view.lua")
-- Round 85: the claim mask's pure rules (api.lua publishes its column rule
-- and margin for the overlay); a claim is a map chunk, half side 39.5.
local CM = dofile(repo .. "/mods/PLAYER/grug_housing/claim_mask.lua")
local BOUNDS = {min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200}
local base = {quality = "normal", width = 1080, height = 960, tiles = {}}
local v = V.new(base, BOUNDS)
do
	local size = v.combined
	local tiled, scale, nearest, clipped, cells = true, true, true, true, 0
	local rects = {}
	for _, cell in ipairs({{300, 250}, {0, 0}, {-3, 7}, {511, 440}, {17, 1}}) do
		local ox, oy = V.origin(v, cell[1], cell[2])
		local cols, rows = V.chunk_cells(v, ox, oy, CM.CHUNK, CM.ORIGIN)
		for index, list in ipairs({cols, rows}) do
			local dir = index == 1 and 1 or -1
			tiled = tiled and list[1][2] == 0 and list[#list][3] == size
			for i = 2, #list do
				tiled = tiled and list[i][2] == list[i - 1][3] and list[i][4] == list[i - 1][5] and
					list[i][1] == list[i - 1][1] + dir
			end
			for _, c in ipairs(list) do
				scale = scale and math.abs((c[5] - c[4]) - CM.CHUNK / v.npp) <= 1
				clipped = clipped and c[2] == math.max(0, c[4]) and c[3] == math.min(size, c[5]) and
					c[3] > c[2]
			end
		end
		-- a chunk's west (north) edge is half a node outside its first
		-- (last) column, rounded to the nearest pixel
		for _, c in ipairs(cols) do
			local x0 = CM.chunk_bounds(c[1], 0)
			nearest = nearest and c[4] == math.floor(V.base_pixel(v, x0 - 0.5, 0) + 0.5) - ox
		end
		for _, r in ipairs(rows) do
			local _, _, _, z1 = CM.chunk_bounds(0, r[1])
			local _, py = V.base_pixel(v, 0, z1 + 0.5)
			nearest = nearest and r[4] == math.floor(py + 0.5) - oy
		end
		cells = cells + #cols * #rows
		if cell[1] == 300 then
			for _, col in ipairs(cols) do
				for _, row in ipairs(rows) do V.cell_frame(v, col, row, "#ffffffcc", rects) end
			end
		end
	end
	check(tiled, "G the chunk grid tiles the texture without gap or overlap")
	check(scale, "G every chunk is 80 nodes at the base's scale (within a pixel)")
	check(nearest, "G every chunk edge rounded to the nearest pixel")
	check(clipped and cells > 100, "G every chunk clipped to the texture (" .. cells .. " chunks)")
	-- every fill of a recipe is valid: the frames of every chunk, clipped
	-- at the texture's edges, and the claims' frames all around and across
	-- them (outside claim mode)
	local ox, oy = V.origin(v, 300, 250)
	local function world(px, py) return v.min_x + px * v.npp, v.max_z - py * v.npp end
	local mid_x, mid_z = world(ox + size / 2, oy + size / 2)
	local half = size * v.npp / 2
	for dz = -half - 80, half + 80, 7 do
		for dx = -half - 80, half + 80, 7 do
			V.claim_frame(v, ox, oy, math.floor(mid_x + dx), math.floor(mid_z + dz), 39.5,
				"#f0d040cc", rects)
		end
	end
	local texture = V.texture(v, ox, oy, "m.png", {rects = rects})
	local valid, count = fills_valid(texture, size, size)
	check(valid and count == #rects and count > 100, "G every fill of a recipe is valid (" ..
		count .. " fills)")
	-- the area the claims are asked for covers the texture
	local min_x, min_z, max_x, max_z = V.texture_area(v, ox, oy)
	local wx0, wz1 = world(ox, oy)
	local wx1, wz0 = world(ox + size, oy + size)
	check(min_x <= wx0 and max_x >= wx1 and min_z <= wz0 and max_z >= wz1,
		"G the claims' area covers the texture")
end

-- ---------------------------------------------------------------------------
-- V  registry
-- ---------------------------------------------------------------------------
local clock = 1800000000
local function new_storage()
	local data = {}
	return {data = data,
		get_string = function(key) return data[key] or "" end,
		set_string = function(key, value) data[key] = value ~= "" and value or nil end,
		keys = function()
			local keys = {}
			for key in pairs(data) do keys[#keys + 1] = key end
			return keys
		end}
end
local registry = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")
local storage = new_storage()
local model = registry({storage = storage, now = function() return clock end})
model.load()
do
	local v0 = model.claim_set_version()
	local a = model.create("ann", {x = 0, y = 5, z = 0})
	local v1 = model.claim_set_version()
	check(v1 ~= v0, "V create changes the version")
	model.activate(a, 5)
	model.add_fuel(a, 3)
	model.set_permission(a, "bob", "interact")
	eq(model.claim_set_version(), v1, "V activation, fuel and permissions keep the version")
	local b = model.create("bob", {x = 300, y = 5, z = 40})
	local v2 = model.claim_set_version()
	check(v2 ~= v1, "V a second claim changes the version")
	model.remove(b, "picked_up")
	local v3 = model.claim_set_version()
	check(v3 ~= v2, "V remove changes the version")
	model.remove(b, "picked_up")
	eq(model.claim_set_version(), v3, "V a second remove keeps the version")
	model.load()
	check(model.claim_set_version() ~= v3, "V load changes the version")
	local v4 = model.claim_set_version()
	model.map_reset()
	check(model.claim_set_version() ~= v4, "V map reset changes the version")
	-- claims_in against a scan of every claim's chunk (one claim per chunk)
	math.randomseed(5022)
	local taken = {}
	for i = 1, 60 do
		local x, z = math.random(-2000, 2000), math.random(-2000, 2000)
		local key = model.chunk_of(x) .. "," .. model.chunk_of(z)
		if not taken[key] then
			taken[key] = true
			model.create("p" .. i, {x = x, y = 0, z = z})
		end
	end
	local same = true
	for _ = 1, 300 do
		local x0, z0 = math.random(-2200, 2200), math.random(-2200, 2200)
		local x1, z1 = x0 + math.random(0, 600), z0 + math.random(0, 600)
		local want = {}
		for _, claim in ipairs(model.all_claims()) do
			local a0, b0, a1, b1 = model.claim_bounds(claim)
			if a0 <= x1 and a1 >= x0 and b0 <= z1 and b1 >= z0 then
				want[#want + 1] = claim.id
			end
		end
		local got = model.claims_in(x0, z0, x1, z1)
		same = same and #got == #want
		for index = 1, #want do same = same and got[index] and got[index].id == want[index] end
	end
	check(same, "V claims_in equals a scan of every claim (ordered by id)")
	model.map_reset()
	-- Round 85: validate has no zone rule any more (the claim mask judges
	-- whole chunks, tools/r85_mask); the overlay's column rule is the mask's.
	local zone_rows = {
		{faction = "accord", territory_rule = "accord_home", level_min = 11, level_max = 20},
		{faction = "throng", territory_rule = "throng_home", level_min = 11, level_max = 20},
		{faction = "accord", territory_rule = "accord_home", level_min = 1, level_max = 10},
		{faction = "accord", territory_rule = "accord_home", level_min = 21, level_max = 40},
		{faction = "accord", territory_rule = "accord_home", level_min = 20, level_max = 30,
			civic_no_hostiles = true},
		{territory_rule = "contested", level_min = 11, level_max = 30},
	}
	local zone_alone = true
	for _, water in ipairs({"land", "planned_water", "coastal_shelf", "deep_ocean"}) do
		for _, zone in ipairs(zone_rows) do
			for _, territory in ipairs({"accord_home", "throng_home", "hard_protected",
					"immutable", "contested"}) do
				for _, faction in ipairs({"accord", "throng"}) do
					local want = CM.column_problem(faction, water, zone, territory)
					-- the territory taken as the faction's home: the zone alone
					local alone = CM.column_problem(faction, water, zone, faction .. "_home")
					zone_alone = zone_alone and (alone == nil or alone == want) and
						(want == nil or alone ~= nil or territory ~= faction .. "_home")
				end
			end
		end
	end
	check(zone_alone, "V column_problem with territory false judges the zone alone")
end

-- ---------------------------------------------------------------------------
-- I  install (base.lua prepare) on a small synthetic world at the game's
-- size: no Claim Stone overlay announced or handed to the minimap (Round 86
-- removed the bake, which this section checked before), and the overlay
-- tiles an older version wrote are removed as stale tiles.
-- ---------------------------------------------------------------------------
local B = dofile(repo .. "/mods/PLAYER/grug_map/base.lua")
do
	local Z = {home = {id = "home", numeric_id = 1, faction = "accord",
		territory_rule = "accord_home", level_min = 11, level_max = 20, race_region = "human"}}
	local zones = {
		water_class_at = function(_, z) return z < -150 and "coastal_shelf" or "land" end,
		id_at = function() return "home" end,
		get = function(id) return Z[id] end,
		terrain_height_at = function() return 20 end,
		water_query_at = function() return "lake" end,
	}
	local announced, removed = {}, {}
	core.sha256 = function(text) return "#" .. #text .. ":" .. text:sub(1, 64) end
	core.get_mapgen_setting = function() return "42" end
	core.safe_file_write = function() return true end
	core.dynamic_add_media = function(def) announced[#announced + 1] = def.filename; return true end
	core.get_dir_list = function()
		return {"grug_map_claim_accord_0_0.png", "grug_map_claim_throng_2_1.png",
			"grug_map_mini_0_0.png", "notes.txt"}
	end
	local real_remove = os.remove
	os.remove = function(path) removed[#removed + 1] = path:match("[^/]+$"); return true end
	rawset(_G, "grug_core", {faction_ids = {"accord", "throng"},
		zone_authority_installed = function() return true end,
		settlement_socket_settlements = function() return {} end,
		start_identities = function() return {} end})
	rawset(_G, "grug_mobs", {dragon_map_markers = function() return {} end})
	rawset(_G, "grug_zones", zones)
	local result = B.install({min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200})
	os.remove = real_remove
	local claims = 0
	for _, name in ipairs(announced) do
		if name:find("^grug_map_claim_") then claims = claims + 1 end
	end
	check(result.tiles and #result.tiles == 9 and result.minimap and result.minimap.tiles and
		#result.minimap.tiles == 9, "I install: the base and the minimap's copy")
	check(result.minimap.claim == nil and claims == 0,
		"I install: no Claim Stone overlay announced or handed to the minimap")
	table.sort(removed)
	eq(table.concat(removed, " "), "grug_map_claim_accord_0_0.png grug_map_claim_throng_2_1.png",
		"I the old overlay tiles go as stale tiles, nothing else")
	core.get_dir_list = nil
end

-- ---------------------------------------------------------------------------
-- M  minimap runtime
-- ---------------------------------------------------------------------------
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
	-- Each test item sits in its own hotbar slot, so a new held item is a
	-- slot switch (Round 81: the minimap reads the held name again on a new
	-- wield index, else every 0.5 s).
	function p:get_wield_index()
		return self.slot or self.wield == "" and 1 or self.wield == "grug_housing:claim_stone" and 2 or 3
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
local factions = {}
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
-- Round 86: the chunk preview through the real preview.lua on a striped
-- mask (every other chunk claim ground, the Throng's the others; no quota)
local preview = dofile(repo .. "/mods/PLAYER/grug_housing/preview.lua")
local stripes = {
	ground = function(faction, cx, cz)
		if (cx + cz) % 2 == (faction == "accord" and 0 or 1) then return true end
		return false, "sea"
	end,
	quota_refusal = function() return nil end,
	add_taken = function(taken) return taken end,
}
rawset(_G, "grug_housing", {STONE_ITEM = "grug_housing:claim_stone", CHUNK = model.CHUNK,
	CHUNK_ORIGIN = model.CHUNK_ORIGIN,
	claim_bounds = model.claim_bounds, claims_in = model.claims_in,
	claim_set_version = model.claim_set_version,
	-- Round 86: the owner question and the stone item set (grug_housing api.lua)
	is_owner = model.is_owner,
	is_stone_item = function(name) return name == "grug_housing:claim_stone" end,
	chunk_refusal = function(faction, cx, cz)
		return preview.chunk_refusal(model, stripes, faction, cx, cz)
	end,
	claim_hint = function(code) return preview.hint(code) end})
rawset(_G, "grug_map", {quest_slots = function() return {} end, atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua"),
	location = {text_of = function() return "Somewhere" end}})
grug_map.base = B
local mini = {quality = "normal", width = 1080, height = 960,
	tiles = B.tiles(1080, 960, B.MINI_PREFIX)}
dofile(repo .. "/mods/PLAYER/grug_map/minimap.lua")
local minimap = grug_map.minimap
minimap.install({minimap = mini})
check(minimap.available(), "M the minimap is available")
local me = new_player("me", {x = 100.3, y = 10, z = -200.6})
players.me = me
windows.me = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
factions.me = "accord"
for _, fn in ipairs(joins) do fn(me) end
local function step(n)
	for _ = 1, n or 1 do
		for _, fn in ipairs(steps) do fn(0.1) end
	end
end
local function hud_of(z)
	for _, def in pairs(me.huds) do
		if def.z_index == z then return def end
	end
end
-- claim mode's line beside the bezel (right-aligned text)
local function hint_of()
	for _, def in pairs(me.huds) do
		if def.type == "text" and def.alignment and def.alignment.x == -1 then return def end
	end
end
local RED = ("#%02x%02x%02x%02x"):format(unpack(B.CLAIM_RED))
local function count(textstr, pattern)
	local n = 0
	for _ in textstr:gmatch(pattern) do n = n + 1 end
	return n
end
step(6)
local normal = minimap.texture_of(me)
check(normal and not normal:find("grug_map_claim") and not normal:find("%[fill"),
	"M no stone: the normal texture")
eq(hint_of() and hint_of().text or "?", "", "M no stone: no line")
-- with the stone
me.wield = "grug_housing:claim_stone"
step()
local held = minimap.texture_of(me)
eq(minimap.claim_of(me), "accord", "M the stone held: claim mode for the faction")
check(held:find(RED, 1, true) and not held:find("grug_map_claim_", 1, true),
	"M the cell texture draws the refused chunks red, no overlay tiles")
check(held:find("grug_map_mini_", 1, true) < held:find("^[fill", 1, true),
	"M the preview after the map's tiles")
check(hint_of() and hint_of().text:find("^This square: ") ~= nil, "M the line is shown")
eq(hud_of(11).text, held, "M the map shows the claim texture")
-- a draft placed by another player near the cell shows at once
sent = 0
step()
eq(sent, 0, "M a still player in claim mode sends nothing")
local draft = model.create("other", {x = 150, y = 10, z = -230})
step()
local with_draft = minimap.texture_of(me)
check(with_draft ~= held and count(with_draft, "#f0d040cc") == 4,
	"M a draft nearby: its chunk framed")
local valid = fills_valid(with_draft, minimap.geometry().combined, minimap.geometry().combined)
check(valid, "M the fills are valid")
eq(hud_of(11).text, with_draft, "M the draft shows without re-selecting the stone")
-- a claim elsewhere changes nothing and sends nothing
sent = 0
local far = model.create("far", {x = 2500, y = 10, z = 2500})
step()
eq(minimap.texture_of(me), with_draft, "M a claim elsewhere: the same string")
eq(sent, 0, "M a claim elsewhere: nothing sent")
model.remove(far, "picked_up")
step()
-- the same claims give the same string
eq(minimap.texture_of(me), with_draft, "M the same claims: the same string")
-- the draft's removal (pick-up or crumbling) takes it away
model.remove(draft, "draft_expired")
step()
eq(minimap.texture_of(me), held, "M the draft gone: its frame gone")
-- no faction: no claim mode
factions.me = nil
step()
eq(minimap.claim_of(me), nil, "M no faction: no claim mode")
eq(minimap.texture_of(me), normal, "M no faction: the normal texture")
factions.me = "throng"
step()
check(minimap.claim_of(me) == "throng" and minimap.texture_of(me) ~= held,
	"M the other faction's preview")
-- another item: back to normal
me.wield = "default:dirt"
step()
eq(minimap.texture_of(me), normal, "M another item: the normal texture")
eq(hint_of().text, "", "M another item: no line")
-- Round 81: a stone put into the held slot itself (no slot switch) shows
-- within the minimap's 0.5 s window check
me.slot, me.wield = 3, "grug_housing:claim_stone"
step(5)
eq(minimap.claim_of(me), "throng", "M a stone put into the held slot: claim mode within 0.5 s")
me.wield = "default:dirt"
step(5)
eq(minimap.texture_of(me), normal, "M the dirt back in the held slot: the normal texture")
me.slot = nil
-- a switched-off minimap appears for claim mode and goes after it
minimap.set_enabled(me, false)
step(6)
check(hud_of(11) == nil, "M switched off: no map")
local function band_x()
	for _, def in pairs(me.huds) do
		if type(def.text) == "string" and def.text:find("^grug_map_daytime_") then
			return def.position.x
		end
	end
end
local corner = band_x()
me.wield = "grug_housing:claim_stone"
step(6)
check(hud_of(11) ~= nil and hud_of(11).text:find(RED, 1, true),
	"M switched off: the minimap appears in claim mode")
check(hint_of() and hint_of().text ~= "", "M switched off: the line appears")
local beside = band_x()
check(corner and beside and beside < corner, "M the side row moves beside the bezel")
me.wield = ""
step(6)
check(hud_of(11) == nil and hint_of() == nil, "M switched off: the minimap goes after claim mode")
eq(band_x(), corner, "M the side row back in the corner")

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R502 CMAP PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print("R502 CMAP PORTABLE PASS checks=" .. checks)
