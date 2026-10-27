-- Fix 0.53.1 lane FLIGHT portable test (LuaJIT): the 40-node flight warning
-- band and the minimap's no-fly overlay (docs/planning/round53-fix-plan.md
-- ruling 2).
--
--   luajit tools/r531_flight/portable_test.lua [repo]
--
-- Loads the REAL grug_mounts flight.lua and entity.lua, grug_core
-- hud_layout.lua and grug_map atlas.lua, base.lua (its render exposed as
-- the r502_cmap fixture does), minimap_view.lua and minimap.lua on a fake
-- engine. Checks:
--   W  warning band: catalog.lua's WARNING_WIDTH is 40 and is the sweep's
--      farthest probe and the HUD text's number; approaching a straight
--      border from 16 headings in half-node steps, the warning is shown at
--      every position within 39 nodes of it (it stays while inside the band)
--      and never beyond 40;
--   O  overlay (the real render on a small synthetic world with ocean,
--      planned water, both homes, contested land and a dragon island; normal
--      size and a 10:3 "high" render reduced to it): per faction, a minimap
--      pixel is red exactly when the dismount rule (column_flight_state, the
--      rule the rider's step asks) refuses its centre column (normal), or
--      the centre column of any render pixel in it (high); sample points in
--      every rule outcome agree; no faction-less overlay;
--   I  install on that world at the game's size: both factions' no-fly
--      tiles announced and handed to the minimap beside the Claim Stone
--      overlays; a failing flight rule keeps the base, the minimap's copy and
--      the claim overlays, without flight tiles and with another key; without
--      grug_mounts the key is the 0.53.0 one;
--   M  minimap runtime: the faction's no-fly tiles in the cell texture only
--      while the player sits on a flying mount (grug_mounts.is_flying over
--      the real active table): not on foot, a ground mount or a boat, not
--      without a faction; after the map's tiles and before the Claim Stone
--      layer; dismounting restores the plain texture string; a still flyer
--      sends nothing; a switched-off minimap stays off.
-- Prints "R531 FLIGHT PORTABLE PASS checks=<n>" or the failures.
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
local function read(path)
	local file = assert(io.open(repo .. path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end
local noop = function() end

-- ---------------------------------------------------------------------------
-- fake engine
-- ---------------------------------------------------------------------------
local joins, steps, sent = {}, {}, 0
local players, windows = {}, {}
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(mod)
		local roots = {grug_map = "/mods/PLAYER/grug_map", grug_housing = "/mods/PLAYER/grug_housing",
			grug_mounts = "/mods/PLAYER/grug_mounts"}
		return roots[mod] and repo .. roots[mod] or nil
	end,
	get_modnames = function() return {"grug_map"} end,
	get_worldpath = function() return "/nonexistent-world" end,
	get_us_time = function() return 0 end,
	log = noop,
	settings = {get = function() return nil end},
	-- the tile's raw RGBA stands in for its PNG
	encode_png = function(_, _, data) return data end,
	safe_file_write = function() return true end,
	dynamic_add_media = function() return true end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = noop,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_entity = noop, register_on_player_hpchange = noop,
	register_on_dieplayer = noop, register_on_shutdown = noop,
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
-- the synthetic world: 400 x 400 nodes
-- ---------------------------------------------------------------------------
local VIEW = {min_x = -200, max_x = 200, min_z = -200, max_z = 200}
local RECORDS = {
	home_a = {id = "home_a", numeric_id = 1, faction = "accord", territory_rule = "accord_home",
		level_min = 1, level_max = 10, race_region = "human"},
	home_t = {id = "home_t", numeric_id = 2, faction = "throng", territory_rule = "throng_home",
		level_min = 1, level_max = 10, race_region = "orc"},
	front = {id = "front", numeric_id = 3, territory_rule = "contested_land", level_min = 20, level_max = 30},
	front_wyrmglass_crown = {id = "front_wyrmglass_crown", numeric_id = 4, territory_rule = "contested_land",
		level_min = 50, level_max = 60},
}
local function owner(x, z)
	x, z = math.floor(x + 0.5), math.floor(z + 0.5)
	if (x + 120) * (x + 120) + (z - 120) * (z - 120) <= 35 * 35 then
		return "front_wyrmglass_crown"
	end
	if z >= 40 then return "front" end
	return x < 0 and "home_a" or "home_t"
end
local function water(x, z)
	x, z = math.floor(x + 0.5), math.floor(z + 0.5)
	if z < -170 then return "deep_ocean" end
	if z < -150 then return "coastal_shelf" end
	if x > -60 and x < -20 and z > -60 and z < 0 then return "planned_water" end
	return "land"
end
local copy = function(t)
	local r = {}
	for k, v in pairs(t) do r[k] = v end
	return r
end
local zones = {
	water_class_at = water,
	id_at = function(x, z) return water(x, z) ~= "deep_ocean" and owner(x, z) or nil end,
	get = function(id) return RECORDS[id] and copy(RECORDS[id]) end,
	terrain_height_at = function() return 20 end,
	water_query_at = function() return "lake" end,
}
rawset(_G, "grug_zones", zones)

-- ---------------------------------------------------------------------------
-- grug_mounts: the real flight.lua and entity.lua
-- ---------------------------------------------------------------------------
local factions = {}
rawset(_G, "grug_factions", {get_faction = function(p) return factions[p:get_player_name()] end,
	register_on_faction_chosen = noop})
rawset(_G, "grug_classes", {register_on_race_chosen = noop})
local catalog = read("/mods/PLAYER/grug_mounts/catalog.lua")
local width = tonumber(catalog:match("\ngrug_mounts%.WARNING_WIDTH = (%d+)\n"))
eq(width, 40, "W catalog.lua: the band is 40 nodes")
rawset(_G, "grug_mounts", {WARNING_WIDTH = width})
dofile(repo .. "/mods/PLAYER/grug_mounts/flight.lua")
dofile(repo .. "/mods/PLAYER/grug_mounts/entity.lua")
local mounts = grug_mounts

-- ---------------------------------------------------------------------------
-- W  warning band
-- ---------------------------------------------------------------------------
do
	local entity = read("/mods/PLAYER/grug_mounts/entity.lua")
	check(entity:find("local WARNING_DISTANCES = {1, 2, 4, 8, 16, 32, grug_mounts.WARNING_WIDTH}",
		1, true) ~= nil, "W the sweep's farthest probe is WARNING_WIDTH")
	check(not entity:find("48", 1, true), "W entity.lua names no 48")
	local texts = 0
	for _ in entity:gmatch('within %%d nodes"%):format%(') do texts = texts + 1 end
	eq(texts, 2, "W both HUD texts take WARNING_WIDTH")
	-- A straight border: the throng home starts at x = 0 (x >= -0.5 after
	-- rounding). An Accord rider approaching from the west along 16 headings.
	local function rider(name, faction)
		local p = {name = name}
		function p:get_player_name() return self.name end
		factions[name] = faction
		return p
	end
	local accord = rider("w_accord", "accord")
	local shown_inside, hidden_outside, inside, outside = 0, 0, 0, 0
	for heading = 0, 15 do
		local angle = (heading - 7.5) * math.pi / 16 -- -84 .. +84 degrees off east
		local dx, dz = math.cos(angle), math.sin(angle)
		local start = 70 / dx
		for t = start, 0, -0.5 do
			local x, z = -0.5 - t * dx, -60 + t * dz
			-- 44 nodes and more from the shelf (z < -149.5) and the
			-- contested land (z >= 39.5): only the border to the east is near
			if x < -1 and z > -105 and z < -5 then
				local distance = -0.5 - x
				local kind = mounts.warning_state(accord, {x = x, y = 80, z = z})
				if distance <= 39 then
					inside = inside + 1
					if kind == "enemy" then shown_inside = shown_inside + 1 end
				elseif distance > 40 then
					outside = outside + 1
					if kind == nil then hidden_outside = hidden_outside + 1 end
				end
			end
		end
	end
	check(inside > 500 and outside > 500, ("W the walk covers both sides (%d inside, %d " ..
		"outside)"):format(inside, outside))
	eq(shown_inside, inside, "W within 39 nodes the warning is shown at every position")
	eq(hidden_outside, outside, "W beyond 40 nodes no warning")
	-- the rule itself: the dismount check is per column, no band
	eq(mounts.flight_state(accord, {x = -0.6, y = 80, z = -60}), true, "W the last home column")
	eq(mounts.flight_state(accord, {x = -0.4, y = 80, z = -60}), false, "W the first enemy column")
end

-- ---------------------------------------------------------------------------
-- O  overlay on the synthetic world
-- ---------------------------------------------------------------------------
local text = read("/mods/PLAYER/grug_map/base.lua")
text = text:gsub("\nreturn M%s*$", "\nM._render = render\nreturn M\n")
local B = assert(loadstring(text, "@base.lua"))()
local FACTIONS = {"accord", "throng"}
do
	local W, H = 60, 60
	local flight = {factions = FACTIONS, rule = mounts.flight_rule}
	local kinds = {}
	for _, render_size in ipairs({60, 200}) do
		local label = render_size == 60 and "O normal" or "O high"
		local spec = {quality = "normal", width = render_size, height = render_size,
			relief_step = 8, relief = B.RELIEF, minimap = {quality = "normal", width = W, height = H}}
		local _, _, claims, flights = B._render(zones, VIEW, spec, nil, nil, flight)
		eq(claims, nil, label .. ": no claim overlays without the claim rules")
		local scale = 400 / render_size
		for _, faction in ipairs(FACTIONS) do
			local tiles = flights and flights[faction]
			check(tiles and #tiles == 1 and tiles[1].name == "grug_map_flight_" .. faction .. "_0_0.png"
				and #tiles[1].png == W * H * 4, label .. " " .. faction .. ": one tile at the minimap's size")
			local data = tiles and tiles[1].png or ""
			-- the dismount rule over every render pixel centre column, folded
			-- into the minimap pixel it lies in
			local want = {}
			for j = 0, render_size - 1 do
				local z = math.floor(VIEW.max_z - (j + 0.5) * scale)
				for i = 0, render_size - 1 do
					local x = math.floor(VIEW.min_x + (i + 0.5) * scale)
					local legal, kind = mounts.column_flight_state(faction, x, z)
					kinds[tostring(kind)] = true
					local index = math.floor((j + 0.5) * H / render_size) * W +
						math.floor((i + 0.5) * W / render_size)
					want[index] = want[index] or not legal
				end
			end
			local agree, red, alpha_ok = 0, 0, true
			for index = 0, W * H - 1 do
				local a = data:byte(index * 4 + 4)
				local is_red = a ~= nil and a ~= 0
				if is_red then
					red = red + 1
					alpha_ok = alpha_ok and data:sub(index * 4 + 1, index * 4 + 4) ==
						string.char(unpack(B.FLIGHT_RED))
				end
				if is_red == (want[index] == true) then agree = agree + 1 end
			end
			eq(agree, W * H, label .. " " .. faction .. ": red exactly where the dismount rule refuses")
			check(red > 0 and red < W * H, label .. " " .. faction .. ": red and clear pixels")
			check(alpha_ok, label .. " " .. faction .. ": the red is FLIGHT_RED")
		end
	end
	check(kinds["nil"] and kinds.ocean and kinds.enemy and kinds.island,
		"O the world exercises legal, ocean, enemy and island columns")
	-- sample points (normal size): a pixel centre column in each outcome
	local spec = {quality = "normal", width = W, height = H, relief_step = 8, relief = B.RELIEF,
		minimap = {quality = "normal", width = W, height = H}}
	local _, _, _, flights = B._render(zones, VIEW, spec, nil, nil, flight)
	local function red_at(faction, x, z)
		local i = math.floor((x - VIEW.min_x) * W / 400)
		local j = math.floor((VIEW.max_z - z) * H / 400)
		return flights[faction][1].png:byte((j * W + i) * 4 + 4) ~= 0
	end
	local npp = 400 / W
	local samples = {
		{"accord home", -100, -100}, {"throng home", 100, -100}, {"contested", 60, 120},
		{"island", -120, 120}, {"lake", -40, -30}, {"shelf", 0, -160}, {"deep", 50, -190},
	}
	for _, sample in ipairs(samples) do
		-- the centre column of the pixel holding the sample
		local i = math.floor((sample[2] - VIEW.min_x) / npp)
		local j = math.floor((VIEW.max_z - sample[3]) / npp)
		local x = math.floor(VIEW.min_x + (i + 0.5) * npp)
		local z = math.floor(VIEW.max_z - (j + 0.5) * npp)
		for _, faction in ipairs(FACTIONS) do
			local legal = mounts.column_flight_state(faction, x, z)
			eq(red_at(faction, x, z), not legal, ("O sample %s (%d,%d) %s"):format(sample[1], x, z,
				faction))
		end
	end
	eq(red_at("accord", -100, -100), false, "O the Accord flies over its home")
	eq(red_at("throng", -100, -100), true, "O the Throng does not fly over the Accord home")
	eq(red_at("accord", -40, -30), false, "O the lake in the Accord home is flyable")
	eq(red_at("accord", 0, -160) and red_at("throng", 0, -160), true, "O the shelf is red for both")
	eq(red_at("accord", -120, 120) and red_at("throng", -120, 120), true, "O the island is red for both")
end

-- ---------------------------------------------------------------------------
-- I  install (base.lua prepare) at the game's size
-- ---------------------------------------------------------------------------
do
	local announced, written = {}, {}
	core.sha256 = function(s) return "#" .. #s .. ":" .. s:sub(1, 64) end
	core.get_mapgen_setting = function() return "42" end
	core.safe_file_write = function(path, data) written[path] = data; return true end
	core.dynamic_add_media = function(def) announced[#announced + 1] = def.filename; return true end
	rawset(_G, "grug_core", {faction_ids = FACTIONS,
		zone_authority_installed = function() return true end,
		settlement_socket_settlements = function() return {} end,
		start_identities = function() return {} end})
	rawset(_G, "grug_mobs", {dragon_map_markers = function() return {} end})
	local registry = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")
	local storage = {get_string = function() return "" end, set_string = noop,
		keys = function() return {} end}
	local model = registry({storage = storage, now = function() return 0 end})
	rawset(_G, "grug_housing", {column_problem = model.column_problem,
		SETTLEMENT_MARGIN = model.SETTLEMENT_MARGIN,
		placement_world = {territory_at = function(x, z)
			return RECORDS[owner(x, z)].territory_rule
		end, feature_in = function() return nil end}})
	local real_rule = mounts.flight_rule
	local function install(mode)
		announced, written = {}, {}
		if mode == "fail" then
			mounts.flight_rule = function() error("forced flight failure") end
		elseif mode == "none" then
			rawset(_G, "grug_mounts", nil)
		end
		local result = B.install({min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200})
		mounts.flight_rule = real_rule
		rawset(_G, "grug_mounts", mounts)
		local count = {claim = 0, flight = 0}
		for _, name in ipairs(announced) do
			if name:find("^grug_map_claim_") then count.claim = count.claim + 1 end
			if name:find("^grug_map_flight_") then count.flight = count.flight + 1 end
		end
		return result, count, written["/nonexistent-world/grug_map_base.key"]
	end
	local good, good_count, good_key = install("good")
	check(good.minimap and good.minimap.flight and good.minimap.flight.accord and
		good.minimap.flight.throng and good_count.flight == 18,
		"I install: both factions' no-fly tiles announced and handed to the minimap")
	check(good.minimap.claim and good_count.claim == 18, "I install: the claim overlays stay")
	eq(good.minimap.flight.accord[1].name, "grug_map_flight_accord_0_0.png", "I the tile names")
	local bad, bad_count, bad_key = install("fail")
	check(bad.tiles and #bad.tiles == 9 and bad.minimap and bad.minimap.tiles and
		#bad.minimap.tiles == 9 and bad.minimap.claim and bad_count.claim == 18,
		"I a failing flight rule: the base, the minimap's copy and the claim overlays stay")
	check(bad.minimap.flight == nil and bad_count.flight == 0,
		"I a failing flight rule: no flight tiles")
	check(bad_key and good_key and bad_key ~= good_key, "I a failing flight rule: another key")
	local _, none_count, none_key = install("none")
	eq(none_count.flight, 0, "I without grug_mounts: no flight tiles")
	eq(none_key, bad_key, "I without grug_mounts: the key without the flight part")
	rawset(_G, "grug_housing", nil)
end

-- ---------------------------------------------------------------------------
-- M  minimap runtime
-- ---------------------------------------------------------------------------
local function new_player(name, pos)
	local meta = {}
	local p = {name = name, pos = pos, yaw = 0, wield = "", huds = {}, next_id = 0}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
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
		local c = {}
		for k, value in pairs(def) do c[k] = value end
		self.huds[self.next_id] = c
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
rawset(_G, "grug_core", {DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125,
	faction_ids = FACTIONS,
	settlement_socket_settlements = function() return {} end,
	settlement_sockets_at = function() return {} end,
	start_identities = function() return {} end})
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
rawset(_G, "grug_quests", {marker_states = function() return {}, 1 end,
	register_on_markers_changed = noop})
rawset(_G, "grug_parties", {view = function() return nil end, register_on_change = noop})
rawset(_G, "grug_home", {get = function() return nil end, known_waypoints = function() return {} end,
	claim_waypoint = function() return nil end})
local registry = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")
local data = {}
local model = registry({storage = {get_string = function(k) return data[k] or "" end,
	set_string = function(k, v) data[k] = v ~= "" and v or nil end,
	keys = function() return {} end}, now = function() return 1800000000 end})
model.load()
rawset(_G, "grug_housing", {STONE_ITEM = "grug_housing:claim_stone", RADIUS = model.RADIUS,
	claims_in = model.claims_in, claim_set_version = model.claim_set_version})
rawset(_G, "grug_map", {quest_slots = function() return {} end, atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua"),
	location = {text_of = function() return "Somewhere" end}})
grug_map.base = B
local mini = {quality = "normal", width = 1080, height = 960,
	tiles = B.tiles(1080, 960, B.MINI_PREFIX),
	claim = {accord = B.tiles(1080, 960, B.CLAIM_PREFIX .. "_accord"),
		throng = B.tiles(1080, 960, B.CLAIM_PREFIX .. "_throng")},
	flight = {accord = B.tiles(1080, 960, B.FLIGHT_PREFIX .. "_accord"),
		throng = B.tiles(1080, 960, B.FLIGHT_PREFIX .. "_throng")}}
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
local function map_text()
	for _, def in pairs(me.huds) do
		if def.z_index == 11 then return def.text end
	end
end
local function ride(mode)
	mounts.active.me = mode and {flying = mode == "flight", mode = mode} or nil
end
step(6)
local plain = minimap.texture_of(me)
check(plain and not plain:find("grug_map_flight"), "M on foot: the plain texture")
eq(minimap.flight_of(me), nil, "M on foot: no flight mode")
ride("land")
step()
eq(minimap.texture_of(me), plain, "M a ground mount: the plain texture")
ride("water")
step()
eq(minimap.texture_of(me), plain, "M a boat: the plain texture")
ride("flight")
step()
local flying = minimap.texture_of(me)
eq(minimap.flight_of(me), "accord", "M a flyer: flight mode for the faction")
check(flying:find("grug_map_flight_accord_", 1, true) and not flying:find("throng", 1, true),
	"M a flyer: the faction's no-fly tiles in the cell texture")
check(flying:find("grug_map_mini_", 1, true) < flying:find("grug_map_flight_accord_", 1, true),
	"M the no-fly tiles after the map's")
eq(map_text(), flying, "M the map shows the flight texture")
sent = 0
step(3)
eq(sent, 0, "M a still flyer sends nothing")
-- the Claim Stone on a flyer: both, the claim layer on top
me.wield = "grug_housing:claim_stone"
step()
local both = minimap.texture_of(me)
check(both:find("grug_map_flight_accord_", 1, true) and both:find("grug_map_claim_accord_", 1, true)
	and both:find("grug_map_flight_accord_", 1, true) < both:find("grug_map_claim_accord_", 1, true),
	"M stone on a flyer: the no-fly tiles under the claim overlay")
me.wield = ""
step()
eq(minimap.texture_of(me), flying, "M the stone put away: the flight texture again")
factions.me = "throng"
step()
check(minimap.texture_of(me):find("grug_map_flight_throng_", 1, true) ~= nil,
	"M the other faction's no-fly tiles")
factions.me = nil
step()
eq(minimap.flight_of(me), nil, "M no faction: no flight mode")
factions.me = "accord"
ride(nil)
step()
eq(minimap.texture_of(me), plain, "M dismounted: the plain texture string")
eq(map_text(), plain, "M dismounted: the map shows it")
-- a switched-off minimap stays off on a flyer
minimap.set_enabled(me, false)
ride("flight")
step(6)
eq(map_text(), nil, "M switched off: no map on a flyer")
eq(minimap.flight_of(me), nil, "M switched off: no flight mode")
minimap.set_enabled(me, true)
step()
eq(minimap.texture_of(me), flying, "M switched on again on a flyer: the flight texture")
ride(nil)

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R531 FLIGHT PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print("R531 FLIGHT PORTABLE PASS checks=" .. checks)
