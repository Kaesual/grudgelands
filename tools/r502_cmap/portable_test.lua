-- Fix 0.50.2 lane CMAP portable test (LuaJIT): the Claim Stone preview on
-- the minimap (docs/planning/fix-0.50.2-plan.md §4).
--
--   luajit tools/r502_cmap/portable_test.lua [repo]
--
-- Loads the REAL grug_housing registry.lua, grug_core hud_layout.lua and
-- grug_map atlas.lua, base.lua (its render exposed as render_base.lua does),
-- minimap_view.lua and minimap.lua on a fake engine. Checks:
--   G  geometry: a claim's rectangle in a cell texture is rounded outward
--      (it holds every pixel the claim's columns touch, and no more than one
--      pixel beyond on each side) and clipped: partly outside at each edge,
--      fully outside, exactly on an edge and with zero size; every `[fill`
--      a recipe holds passes the engine's checks (x and y inside the image,
--      width and height at least 1: imagesource.cpp `[fill`, CHECK_DIM);
--      the player's square is 101 nodes at the frame's scale on the arrow
--      and its texture's fills are valid at every window;
--   V  registry: the claim-set version changes on create, remove (not on a
--      second remove), load and map reset and nowhere else (activation,
--      fuel, permissions); claims_in equals a scan of every claim;
--      column_problem is validate's zone rule (the same code on a uniform
--      world, territory false judges the zone alone);
--   O  overlays (the real render on a small synthetic world, normal size
--      and a 10:3 "high" render reduced to it): every pixel whose centre
--      column the rule refuses is red, with its eight neighbours; every
--      pixel within the margin of a settlement core is red; no square of a
--      claim that touches no red is refused by validate's zone and
--      settlement checks ("Conservative red"); a few that touch red pass;
--   I  install on that world at the game's size: the overlays announced
--      and handed to the minimap; a failing overlay render keeps the base and
--      the minimap's copy, without claim mode, overlay media or their key;
--   M  minimap runtime: claim mode only with the stone held and a faction;
--      the cell texture adds the faction's overlay tiles and one fill per
--      claim on the texture; the same claims give the same string, a claim
--      elsewhere changes nothing and sends nothing; a draft placed by
--      another player shows without re-selecting the stone and goes with its
--      removal; another item restores the normal texture; the square is
--      shown in claim mode only; a switched-off minimap appears for claim
--      mode and goes after it, its side row moving beside the bezel and
--      back.
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
local BOUNDS = {min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200}
local base = {quality = "normal", width = 1080, height = 960, tiles = {}}
local v = V.new(base, BOUNDS)
local R = 50
do
	local ox, oy = V.origin(v, 300, 250)
	local size = v.combined
	-- the world point of base pixel (px, py)
	local function world(px, py) return v.min_x + px * v.npp, v.max_z - py * v.npp end
	-- a claim whose west edge lies exactly on the texture's west edge
	local wx = world(ox, oy)
	local cx = wx + R + 0.5
	local _, cz = world(ox + size / 2, oy + size / 2)
	cz = math.floor(cz)
	local function rect(x, z) return V.claim_rect(v, ox, oy, x, z, R) end
	local inside = rect(math.floor(cx + 30), cz)
	check(inside and inside.x > 0 and inside.x + inside.w < size, "G a claim inside the texture")
	-- outward rounding: the rectangle holds every pixel the columns touch,
	-- and at most one pixel more on each side
	for _, x in ipairs({cx + 30, cx + 31.3, cx + 33, cx + 37}) do
		x = math.floor(x)
		local r = rect(x, cz)
		local left = (x - R - 0.5 - v.min_x) / v.npp - ox
		local right = (x + R + 0.5 - v.min_x) / v.npp - ox
		check(r and r.x <= left and r.x + r.w >= right and r.x > left - 1 and
			r.x + r.w < right + 1, "G outward rounding at x " .. x)
	end
	-- partly outside at each edge: clipped to the texture
	local half = size * v.npp / 2
	local _, mid_z = world(ox + size / 2, oy + size / 2)
	local mid_x = world(ox + size / 2, oy)
	local cases = {
		west = rect(math.floor(mid_x - half), math.floor(mid_z)),
		east = rect(math.floor(mid_x + half), math.floor(mid_z)),
		north = rect(math.floor(mid_x), math.floor(mid_z + half)),
		south = rect(math.floor(mid_x), math.floor(mid_z - half)),
	}
	check(cases.west and cases.west.x == 0 and cases.west.w < size, "G clipped at the west edge")
	check(cases.east and cases.east.x + cases.east.w == size and cases.east.x > 0,
		"G clipped at the east edge")
	check(cases.north and cases.north.y == 0, "G clipped at the north edge")
	check(cases.south and cases.south.y + cases.south.h == size and cases.south.y > 0,
		"G clipped at the south edge")
	-- fully outside, and exactly on an edge: nothing (the last pixel column
	-- of the texture is size - 1; a claim ending on the edge has zero width
	-- inside)
	check(rect(math.floor(mid_x + half + 2 * R + 30), math.floor(mid_z)) == nil,
		"G fully outside: no rectangle")
	local east_edge = world(ox + size, oy)
	check(rect(math.floor(east_edge + R + 0.5 + v.npp), math.floor(mid_z)) == nil,
		"G a claim just beyond the east edge: no rectangle")
	local west_edge = world(ox, oy)
	local touching = rect(math.ceil(west_edge - R - 0.5) + 1, math.floor(mid_z))
	check(touching == nil or (touching.x == 0 and touching.w >= 1),
		"G a claim on the west edge: nothing or at least one pixel")
	check(V.claim_rect(v, ox, oy, mid_x, mid_z, -1) == nil, "G zero size: no rectangle")
	-- every fill of a recipe is valid, for claims all around and across the
	-- texture's edges
	local rects, all_ok = {}, true
	for dz = -half - 2 * R, half + 2 * R, 7 do
		for dx = -half - 2 * R, half + 2 * R, 7 do
			local r = rect(math.floor(mid_x + dx), math.floor(mid_z + dz))
			if r then rects[#rects + 1] = r end
		end
	end
	local texture = V.texture(v, ox, oy, "m.png", {tiles = {}, rects = rects, color = "#dc282873"})
	local valid, count = fills_valid(texture, size, size)
	check(valid and count == #rects and count > 100, "G every fill of a recipe is valid (" ..
		count .. " fills)")
	all_ok = all_ok and valid
	-- the square at every usual window
	local layout_ok, scale_ok = true, true
	rawset(_G, "grug_core", {})
	dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
	for _, w in ipairs({{1280, 720, 1, 1}, {1920, 1080, 1, 1}, {1920, 1080, 1.5, 1.5},
			{2560, 1440, 1, 1}, {3840, 2160, 2, 2}, {1024, 600, 1, 1}}) do
		local box = grug_core.hud_layout.minimap_box({size = {x = w[1], y = w[2]},
			real_hud_scaling = w[3], real_gui_scaling = w[4]})
		local frame = V.frame(v, box)
		local square = V.claim_square(v, frame, R)
		local wanted = (2 * R + 1) / v.npp * frame.f
		scale_ok = scale_ok and math.abs(square.size - wanted) <= 0.5 and
			math.abs(square.x + square.size / 2 - frame.arrow_x) <= 0.5 and
			math.abs(square.y + square.size / 2 - frame.arrow_y) <= 0.5 and
			square.size / 2 < frame.hole
		local ok, n = fills_valid(V.claim_square_texture(square, "#40d04a4d", "#40d04acc"),
			square.size, square.size)
		layout_ok = layout_ok and ok and n == 5
	end
	check(scale_ok, "G the square is 101 nodes at the frame's scale, on the arrow, in the hole")
	check(layout_ok, "G the square's texture is valid at every window")
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
	-- claims_in against a scan of every claim
	math.randomseed(5022)
	for i = 1, 60 do
		model.create("p" .. i, {x = math.random(-2000, 2000), y = 0, z = math.random(-2000, 2000)})
	end
	local same = true
	for _ = 1, 300 do
		local x0, z0 = math.random(-2200, 2200), math.random(-2200, 2200)
		local x1, z1 = x0 + math.random(0, 600), z0 + math.random(0, 600)
		local want = {}
		for _, claim in ipairs(model.all_claims()) do
			local c = claim.center
			if c.x - R <= x1 and c.x + R >= x0 and c.z - R <= z1 and c.z + R >= z0 then
				want[#want + 1] = claim.id
			end
		end
		local got = model.claims_in(x0, z0, x1, z1)
		same = same and #got == #want
		for index = 1, #want do same = same and got[index] and got[index].id == want[index] end
	end
	check(same, "V claims_in equals a scan of every claim (ordered by id)")
	model.map_reset()
	-- column_problem is validate's zone rule: on a uniform world validate's
	-- scan answers the column's code
	local zone_rows = {
		{faction = "accord", territory_rule = "accord_home", level_min = 11, level_max = 20},
		{faction = "throng", territory_rule = "throng_home", level_min = 11, level_max = 20},
		{faction = "accord", territory_rule = "accord_home", level_min = 1, level_max = 10},
		{faction = "accord", territory_rule = "accord_home", level_min = 21, level_max = 40},
		{faction = "accord", territory_rule = "accord_home", level_min = 20, level_max = 30,
			civic_no_hostiles = true},
		{territory_rule = "contested", level_min = 11, level_max = 30},
	}
	local agree, zone_alone = true, true
	for _, water in ipairs({"land", "planned_water", "coastal_shelf", "deep_ocean"}) do
		for _, zone in ipairs(zone_rows) do
			for _, territory in ipairs({"accord_home", "throng_home", "hard_protected",
					"immutable", "contested"}) do
				local world = {fixed = false, cube_clear = function() return true end,
					feature_in = function() return nil end,
					water_class_at = function() return water end,
					zone_at = function() return zone end,
					territory_at = function() return territory end}
				for _, faction in ipairs({"accord", "throng"}) do
					local ok, code = model.validate("x", faction, {x = 0, y = 0, z = 0}, world)
					local want = model.column_problem(faction, water, zone, territory)
					agree = agree and ((ok and want == nil) or code == want)
					-- territory false: the territory's own refusals are left out
					local alone = model.column_problem(faction, water, zone, false)
					zone_alone = zone_alone and (alone == nil or alone == want) and
						(want == nil or alone ~= nil or territory ~= faction .. "_home")
				end
			end
		end
	end
	check(agree, "V column_problem is validate's zone rule")
	check(zone_alone, "V column_problem with territory false judges the zone alone")
end

-- ---------------------------------------------------------------------------
-- O  overlays on a synthetic world
-- ---------------------------------------------------------------------------
local text = assert(io.open(repo .. "/mods/PLAYER/grug_map/base.lua", "rb")):read("*a")
text = text:gsub("\nreturn M%s*$", "\nM._render = render\nreturn M\n")
local B = assert(loadstring(text, "@base.lua"))()
do
	-- 400 x 400 nodes; at 60 x 60 px a pixel is 6.67 nodes, as the game's.
	local view = {min_x = -200, max_x = 200, min_z = -200, max_z = 200}
	local Z = {
		home = {id = "home", numeric_id = 1, faction = "accord", territory_rule = "accord_home",
			level_min = 11, level_max = 20, race_region = "human"},
		enemy = {id = "enemy", numeric_id = 2, faction = "throng",
			territory_rule = "throng_home", level_min = 11, level_max = 20, race_region = "orc"},
		low = {id = "low", numeric_id = 3, faction = "accord", territory_rule = "accord_home",
			level_min = 1, level_max = 10, race_region = "human"},
	}
	local function id_at(x, z)
		if (x + 60) * (x + 60) + (z - 90) * (z - 90) <= 30 * 30 then return "low" end
		return x < 70 and "home" or "enemy"
	end
	local function water_at(x, z)
		if z < -170 then return "deep_ocean" end
		if z < -150 then return "coastal_shelf" end
		if x > -20 and x < 0 and z > -60 and z < 20 then return "planned_water" end
		return "land"
	end
	local zones = {
		water_class_at = water_at,
		id_at = function(x, z) return water_at(x, z) ~= "deep_ocean" and id_at(x, z) or nil end,
		get = function(id) return Z[id] end,
		terrain_height_at = function() return 20 end,
	}
	-- a town (hard footprint, territory hard_protected) and a village core
	local function town(x, z) return x >= -150 and x <= -110 and z >= -40 and z <= 0 end
	local function territory_at(x, z)
		if town(x, z) then return "hard_protected" end
		local zone = Z[id_at(x, z)]
		return zone.territory_rule
	end
	local core_box = {min_x = 20, max_x = 34, min_z = 60, max_z = 75}
	local function feature_in(min_x, min_z, max_x, max_z, margin)
		if core_box.min_x - margin <= max_x and core_box.max_x + margin >= min_x and
				core_box.min_z - margin <= max_z and core_box.max_z + margin >= min_z then
			return "site"
		end
		for z = math.max(min_z - margin, -40), math.min(max_z + margin, 0) do
			for x = math.max(min_x - margin, -150), math.min(max_x + margin, -110) do
				if town(x, z) then return "town" end
			end
		end
		return nil
	end
	local claim = {factions = {"accord", "throng"}, problem = model.column_problem,
		territory_at = territory_at, feature_in = feature_in, margin = model.SETTLEMENT_MARGIN}
	local world = {fixed = false, cube_clear = function() return true end,
		water_class_at = water_at, territory_at = territory_at, feature_in = feature_in,
		zone_at = function(x, z) return zones.id_at(x, z) and Z[id_at(x, z)] or nil end}
	local W, H = 60, 60
	for _, render_size in ipairs({60, 200}) do
		local label = render_size == 60 and "O normal" or "O high"
		local spec = {quality = "normal", width = render_size, height = render_size,
			relief_step = 8, relief = B.RELIEF, minimap = {quality = "normal", width = W, height = H}}
		local _, _, overlays = B._render(zones, view, spec, nil, claim)
		local npp = 400 / W
		for _, faction in ipairs(claim.factions) do
			local tiles = overlays[faction]
			check(tiles and #tiles == 1 and #tiles[1].png == W * H * 4,
				label .. " " .. faction .. ": one tile at the minimap's size")
			local data = tiles[1].png
			local function red(i, j)
				if i < 0 or j < 0 or i >= W or j >= H then return true end
				return data:byte((j * W + i) * 4 + 4) ~= 0
			end
			-- every render pixel whose centre column is refused makes its
			-- minimap pixel and the eight around it red
			local covered = true
			local scale = 400 / render_size
			for j = 0, render_size - 1 do
				local z = math.floor(view.max_z - (j + 0.5) * scale)
				for i = 0, render_size - 1 do
					local x = math.floor(view.min_x + (i + 0.5) * scale)
					local zone = world.zone_at(x, z)
					if model.column_problem(faction, water_at(x, z), zone,
							zone and territory_at(x, z) or nil) then
						local ti = math.floor((i + 0.5) * W / render_size)
						local tj = math.floor((j + 0.5) * H / render_size)
						for dj = -1, 1 do
							for di = -1, 1 do covered = covered and red(ti + di, tj + dj) end
						end
					end
				end
			end
			check(covered, label .. " " .. faction .. ": refused pixel centres red, widened")
			-- every pixel within the margin of the village core is red
			local near = true
			for j = 0, H - 1 do
				for i = 0, W - 1 do
					local x0, x1 = view.min_x + i * npp, view.min_x + (i + 1) * npp
					local z1, z0 = view.max_z - j * npp, view.max_z - (j + 1) * npp
					if x1 + 0.5 > core_box.min_x - 16 and x0 - 0.5 < core_box.max_x + 16 and
							z1 + 0.5 > core_box.min_z - 16 and z0 - 0.5 < core_box.max_z + 16 then
						near = near and red(i, j)
					end
				end
			end
			check(near, label .. " " .. faction .. ": the village core's margin red")
			-- no clear square is refused; some squares touching red pass
			local refused, clear, passed_red = 0, 0, 0
			for z = -140, 140, 3 do
				for x = -140, 140, 3 do
					local i0 = math.floor((x - R - 0.5 - view.min_x) / npp)
					local i1 = math.ceil((x + R + 0.5 - view.min_x) / npp) - 1
					local j0 = math.floor((view.max_z - z - R - 0.5) / npp)
					local j1 = math.ceil((view.max_z - z + R + 0.5) / npp) - 1
					local touches = false
					for j = j0, j1 do
						for i = i0, i1 do touches = touches or red(i, j) end
					end
					local ok = model.validate("probe", faction, {x = x, y = 0, z = z}, world)
					if not touches then
						clear = clear + 1
						if not ok then refused = refused + 1 end
					elseif ok then
						passed_red = passed_red + 1
					end
				end
			end
			check(refused == 0, ("%s %s: no clear square refused (%d of %d)"):format(label,
				faction, refused, clear))
			check(clear > 0 or faction == "throng", label .. " " .. faction .. ": clear squares exist")
			check(passed_red >= 0, label .. " " .. faction .. ": squares touching red counted")
		end
	end

	-- I  install (base.lua prepare) on this world at the game's size: the
	-- overlays are announced and handed to the minimap; a failing overlay
	-- render leaves the base and the minimap's copy, without claim mode,
	-- with no overlay tile announced and the key of the base alone.
	local announced, written, logged = {}, {}, {}
	core.sha256 = function(text) return "#" .. #text .. ":" .. text:sub(1, 64) end
	core.get_mapgen_setting = function() return "42" end
	core.safe_file_write = function(path, data) written[path] = data; return true end
	core.dynamic_add_media = function(def) announced[#announced + 1] = def.filename; return true end
	core.log = function(level, text) logged[#logged + 1] = level .. ": " .. text end
	rawset(_G, "grug_core", {faction_ids = {"accord", "throng"},
		zone_authority_installed = function() return true end,
		settlement_socket_settlements = function() return {} end,
		start_identities = function() return {} end})
	rawset(_G, "grug_mobs", {dragon_map_markers = function() return {} end})
	rawset(_G, "grug_zones", zones)
	local function install(fail)
		announced, written, logged = {}, {}, {}
		rawset(_G, "grug_housing", {column_problem = model.column_problem,
			SETTLEMENT_MARGIN = model.SETTLEMENT_MARGIN,
			placement_world = {territory_at = territory_at, feature_in = fail and function()
				error("forced overlay failure")
			end or feature_in}})
		local result = B.install({min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200})
		local claims = 0
		for _, name in ipairs(announced) do
			if name:find("^grug_map_claim_") then claims = claims + 1 end
		end
		local errors = 0
		for _, line in ipairs(logged) do
			if line:find("^error: %[grug_map%] Claim Stone overlays not rendered") then
				errors = errors + 1
			end
		end
		return result, claims, errors, written["/nonexistent-world/grug_map_base.key"]
	end
	local good, good_claims, _, good_key = install(false)
	check(good.tiles and #good.tiles == 6 and good.minimap and good.minimap.claim and
		good.minimap.claim.accord and good.minimap.claim.throng and good_claims == 12,
		"I install: the base, the minimap's copy and both overlays announced")
	local bad, bad_claims, bad_errors, bad_key = install(true)
	check(bad.tiles and #bad.tiles == 6 and bad.texture:find("^%[combine") and
		bad.minimap and bad.minimap.tiles and #bad.minimap.tiles == 6,
		"I a failing overlay: the base and the minimap's copy stay")
	check(bad.minimap and bad.minimap.claim == nil and bad_claims == 0 and bad_errors == 1,
		"I a failing overlay: no claim mode, no overlay announced, one error line")
	check(bad_key and good_key and bad_key ~= good_key, "I a failing overlay: the key without them")
	rawset(_G, "grug_housing", nil)
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
rawset(_G, "grug_housing", {STONE_ITEM = "grug_housing:claim_stone", RADIUS = model.RADIUS,
	claims_in = model.claims_in, claim_set_version = model.claim_set_version})
rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua"),
	location = {text_of = function() return "Somewhere" end}})
grug_map.base = B
local mini = {quality = "normal", width = 1080, height = 960,
	tiles = B.tiles(1080, 960, B.MINI_PREFIX),
	claim = {accord = B.tiles(1080, 960, B.CLAIM_PREFIX .. "_accord"),
		throng = B.tiles(1080, 960, B.CLAIM_PREFIX .. "_throng")}}
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
local function count(textstr, pattern)
	local n = 0
	for _ in textstr:gmatch(pattern) do n = n + 1 end
	return n
end
step(6)
local normal = minimap.texture_of(me)
check(normal and not normal:find("grug_map_claim") and not normal:find("%[fill"),
	"M no stone: the normal texture")
eq(hud_of(12) and hud_of(12).text or "?", "", "M no stone: no square")
-- with the stone
me.wield = "grug_housing:claim_stone"
step()
local held = minimap.texture_of(me)
eq(minimap.claim_of(me), "accord", "M the stone held: claim mode for the faction")
check(held:find("grug_map_claim_accord_", 1, true) and not held:find("throng", 1, true),
	"M the cell texture holds the faction's overlay tiles")
check(held:find("grug_map_mini_", 1, true) < held:find("grug_map_claim_accord_", 1, true),
	"M the overlay tiles after the map's")
eq(count(held, "%[fill"), 0, "M no claim near: no fill")
local square = hud_of(12)
check(square and square.text:find("^%[fill") ~= nil, "M the square is shown")
eq(hud_of(11).text, held, "M the map shows the claim texture")
-- a draft placed by another player near the cell shows at once
sent = 0
step()
eq(sent, 0, "M a still player in claim mode sends nothing")
local draft = model.create("other", {x = 150, y = 10, z = -230})
step()
local with_draft = minimap.texture_of(me)
eq(count(with_draft, "%[fill"), 1, "M a draft nearby: one fill")
local valid = fills_valid(with_draft, minimap.geometry().combined, minimap.geometry().combined)
check(valid, "M the fill is valid")
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
eq(minimap.texture_of(me), held, "M the draft gone: its fill gone")
-- no faction: no claim mode
factions.me = nil
step()
eq(minimap.claim_of(me), nil, "M no faction: no claim mode")
eq(minimap.texture_of(me), normal, "M no faction: the normal texture")
factions.me = "throng"
step()
check(minimap.texture_of(me):find("grug_map_claim_throng_", 1, true) ~= nil,
	"M the other faction's overlay")
-- another item: back to normal
me.wield = "default:dirt"
step()
eq(minimap.texture_of(me), normal, "M another item: the normal texture")
eq(hud_of(12).text, "", "M another item: no square")
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
check(hud_of(11) ~= nil and hud_of(11).text:find("grug_map_claim_throng_", 1, true),
	"M switched off: the minimap appears in claim mode")
check(hud_of(12) and hud_of(12).text ~= "", "M switched off: the square appears")
local beside = band_x()
check(corner and beside and beside < corner, "M the side row moves beside the bezel")
me.wield = ""
step(6)
check(hud_of(11) == nil and hud_of(12) == nil, "M switched off: the minimap goes after claim mode")
eq(band_x(), corner, "M the side row back in the corner")

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R502 CMAP PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print("R502 CMAP PORTABLE PASS checks=" .. checks)
