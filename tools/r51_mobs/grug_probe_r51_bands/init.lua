-- Disposable engine probe (Round 51 lane MOBS, step M2). Never shipped:
-- tools/r51_mobs/bands.sh stages it through tools/luanti_headless.sh.
--
-- The water spawns of the real game, counted per band on one seed. A coarse
-- grid search with the water query picks one stand-in player point over
-- each band (a lake, a river, coastal shallows, the coastal waters 40+
-- nodes out, a bay middle, a dragon channel, the open sea); the areas
-- around the points are generated and force-loaded, and invisible probe
-- entities that answer as players stand there (the ambient spawner's
-- players, SR.players, and mobs_redo's players in range). Over one day
-- window every water spawn is checked as it happens (its band's families,
-- the level inside its kind's range, a swimmer's spot in the water), the
-- attempt outcomes are logged, and a census lists every water mob near each
-- point. Lines "[r51bands] ...", "RESULT PASS" / "RESULT FAIL".

local P = "[r51bands] "
local WINDOW = tonumber(core.settings:get("r51bands_window") or "") or 100
local RADIUS = 72
local SR = grug_mobs.spawn_regions
local failures = {}
local function log(msg) core.log("action", P .. msg) end
local function fail(msg)
	failures[#failures + 1] = msg
	log("CHECK FAIL " .. msg)
end

local WATER = {["default:water_source"] = true, ["default:river_water_source"] = true}
local FAMILIES = {sea_shallows = {tortoise = true}, sea_deep = {stingray = true},
	lake = {frog = true, tortoise = true}, river = {frog = true}}
local function family(role)
	return role:match("^(%a+)_t%d$")
end

--
-- Probe players (tools/pt_fixes/lane_c): invisible entities that answer
-- is_player and a name.
--
core.register_entity("grug_probe_r51_bands:hero", {
	initial_properties = {physical = false, pointable = false, static_save = false,
		visual = "sprite", textures = {"blank.png"}, is_visible = false,
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}},
	on_punch = function() return true end,
})
local fakes, methods = {}, nil
local function make_player(name, pos)
	local ref = core.add_entity(pos, "grug_probe_r51_bands:hero")
	assert(ref, "probe player not added")
	if not methods then
		methods = getmetatable(ref)
		local function override(key, fn)
			local original = methods[key]
			methods[key] = function(self, ...)
				local fake = fakes[self]
				if fake then return fn(fake, ...) end
				return original(self, ...)
			end
		end
		override("is_player", function() return true end)
		override("get_player_name", function(f) return f.name end)
	end
	fakes[ref] = {name = name}
	return ref
end

--
-- The points: one column per band from a grid search.
--
local WANT = {
	{id = "lake", ok = function(c, _, _, d) return c == "lake" and (d or 0) >= 2 end},
	{id = "river", ok = function(c) return c == "river" end},
	{id = "shallows", ok = function(c, z, dist) return (c == "belt" or c == "bay") and z and dist and
		dist >= 6 and dist <= 12 end},
	{id = "coastal_waters", ok = function(c, z, dist, d) return c == "belt" and z and dist and
		dist >= 40 and dist <= 80 and d >= 10 end},
	{id = "bay_middle", ok = function(c, _, dist, d) return c == "bay" and dist and dist >= 70 and d >= 20 end},
	{id = "channel", ok = function(c, _, dist) return c == "channel" and dist and dist >= 40 end},
	{id = "open_sea", ok = function(c, _, dist) return c == "open_sea" and dist and dist >= 120 and dist <= 300 end},
}
local POINTS = {}
local function find_points()
	local found = {}
	for z = -3600, 3600, 48 do
		for x = -4000, 4000, 48 do
			local c, zone, level, dist, depth = grug_zones.water_query_at(x, z)
			if c then
				for _, want in ipairs(WANT) do
					if not found[want.id] and want.ok(c, zone, dist, depth) then
						found[want.id] = {id = want.id, x = x, z = z, class = c, zone = zone,
							level = level, dist = dist, depth = depth}
					end
				end
			end
		end
	end
	for _, want in ipairs(WANT) do
		local p = found[want.id]
		if p then
			POINTS[#POINTS + 1] = p
		else
			fail("no column for " .. want.id)
		end
	end
end

--
-- Every water spawn as it happens.
--
local spawned = {} -- point id -> {key -> n}
local function nearest_point(pos)
	local best, bd
	for _, p in ipairs(POINTS) do
		local dx, dz = pos.x - p.x, pos.z - p.z
		local d = dx * dx + dz * dz
		if not bd or d < bd then best, bd = p, d end
	end
	return best
end
local original_spawn = SR.spawn_mob
SR.spawn_mob = function(unit, role, g, clock)
	local ent = original_spawn(unit, role, g, clock)
	local band = unit.type
	if ent and FAMILIES[band] then
		local level = ent._grug_spawn_level or ent._grug_level
		local range = unit.levels_by_role[role]
		if not FAMILIES[band][family(role) or ""] then
			fail(role .. " spawned in " .. band)
		end
		if level < range[1] or level > range[2] then
			fail(("%s at L%d outside %s's L%d-%d"):format(role, level, unit.tag, range[1], range[2]))
		end
		local spot = {x = g.x, y = g.y + 1, z = g.z}
		if not WATER[core.get_node(spot).name] then
			fail(role .. " placed outside the water at " .. core.pos_to_string(spot))
		end
		local p = nearest_point(spot)
		local key = ("%s %s L%d %s"):format(band, role, level, unit.tag)
		spawned[p.id] = spawned[p.id] or {}
		spawned[p.id][key] = (spawned[p.id][key] or 0) + 1
	end
	return ent
end

-- The world rows' spawn attempts (mobs_redo's custom check, after the
-- merged water ABM picked the row): per mob, tried and refused.
local WORLD_ROWS = {["grug_mobs:bay_shark"] = true, ["grug_mobs:abyssal_shark"] = true,
	["grug_mobs:kraken"] = true, ["grug_mobs:goby"] = true}
local row_tries = {}
core.register_on_mods_loaded(function()
	local check = mobs.spawn_abm_check
	mobs.spawn_abm_check = function(self, pos, node, name)
		local refused = check(self, pos, node, name)
		if WORLD_ROWS[name] then
			local r = row_tries[name] or {tried = 0, refused = 0}
			row_tries[name] = r
			r.tried = r.tried + 1
			if refused then r.refused = r.refused + 1 end
		end
		return refused
	end
end)

local function census()
	for _, point in ipairs(POINTS) do
		local by, rows = {}, {}
		for _, object in ipairs(core.get_objects_inside_radius({x = point.x, y = point.y, z = point.z},
				RADIUS + 16)) do
			local ent = object:get_luaentity()
			if ent and ent.name and ent.name:sub(1, 10) == "grug_mobs:" then
				local pos = object:get_pos()
				local key = ("%s L%s %s"):format(ent.name:sub(11), tostring(ent._grug_level),
					WATER[core.get_node(vector.round(pos)).name] and "in_water" or "out")
				by[key] = (by[key] or 0) + 1
			end
		end
		for k, n in pairs(by) do rows[#rows + 1] = k .. "=" .. n end
		table.sort(rows)
		log(("census %s [%s]"):format(point.id, table.concat(rows, " ")))
	end
end

local function finish()
	census()
	local rows = {}
	for k, v in pairs(SR.stats) do rows[#rows + 1] = k .. "=" .. v end
	table.sort(rows)
	log("attempt outcomes: " .. table.concat(rows, " "))
	local per_band = {}
	for _, point in ipairs(POINTS) do
		local keys = {}
		for k, n in pairs(spawned[point.id] or {}) do
			keys[#keys + 1] = k .. " x" .. n
			local band = k:match("^(%S+)")
			per_band[band] = (per_band[band] or 0) + n
		end
		table.sort(keys)
		log(("spawned near %s: %s"):format(point.id, #keys > 0 and table.concat(keys, "; ") or "none"))
	end
	local bands = {}
	for band, n in pairs(per_band) do bands[#bands + 1] = band .. "=" .. n end
	table.sort(bands)
	log("water spawns per band: " .. table.concat(bands, " "))
	local tries = {}
	for name, r in pairs(row_tries) do
		tries[#tries + 1] = ("%s tried %d refused %d"):format(name:sub(11), r.tried, r.refused)
	end
	table.sort(tries)
	log("world rows: " .. (#tries > 0 and table.concat(tries, ", ") or "no attempt"))
	for _, band in ipairs({"lake", "river", "sea_shallows", "sea_deep"}) do
		if not per_band[band] then fail("no " .. band .. " spawn in the window") end
	end
	log((#failures == 0 and "RESULT PASS" or "RESULT FAIL") .. " failures=" .. #failures)
	core.request_shutdown("r51 bands probe done", false, 0)
end

local function start()
	local players = {}
	for _, point in ipairs(POINTS) do
		players[#players + 1] = make_player("probe_" .. point.id,
			{x = point.x, y = point.y + 1, z = point.z})
	end
	SR.players = function() return players end
	core.set_timeofday(0.5)
	for s = 10, WINDOW, 10 do core.after(s, function() core.set_timeofday(0.5) end) end
	log(("window: %d s by day"):format(WINDOW))
	core.after(WINDOW, finish)
end

core.after(2, function()
	local t0 = core.get_us_time()
	find_points()
	log(("points found in %.1f s"):format((core.get_us_time() - t0) / 1e6))
	if #POINTS == 0 then
		log("RESULT FAIL")
		core.request_shutdown("r51 bands probe failed", false, 0)
		return
	end
	local pending = 0
	for _, point in ipairs(POINTS) do
		point.y = 1 -- the sea's surface; a lake's or river's is read after the emerge
		log(("point %s (%d, %d): %s zone %s level %s, %s from land, %s deep; Bay Shark band %s, open sea %s"):format(
			point.id, point.x, point.z, point.class, tostring(point.zone), tostring(point.level),
			tostring(point.dist), tostring(point.depth),
			tostring(grug_mobs.shark_bands.bay_middle({x = point.x, y = 2, z = point.z})),
			tostring(grug_mobs.shark_bands.open_sea({x = point.x, y = 2, z = point.z}))))
		local top = math.max(1, grug_zones.terrain_height_at(point.x, point.z) + (point.depth or 0))
		point.y = top
		local minp = {x = point.x - RADIUS, y = top - 40, z = point.z - RADIUS}
		local maxp = {x = point.x + RADIUS - 1, y = top + 31, z = point.z + RADIUS - 1}
		for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
			for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
				for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
					core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
				end
			end
		end
		pending = pending + 1
		core.emerge_area(minp, maxp, function(_, _, remaining)
			if remaining == 0 then
				pending = pending - 1
				if pending == 0 then
					log(("emerged %d areas in %.1f s"):format(#POINTS, (core.get_us_time() - t0) / 1e6))
					core.after(2, start)
				end
			end
		end)
	end
end)
