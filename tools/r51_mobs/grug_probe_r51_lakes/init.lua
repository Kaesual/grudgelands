-- Disposable engine probe (Round 51 follow-up lane FM). Never shipped:
-- tools/r51_mobs/lakes.sh stages it through tools/luanti_headless.sh.
--
-- Fish in land lakes and no combat mob in a capital's lake, on one seed:
--   1. Every capital (a zone with a `capital` anchor): its lake and river
--      columns within CAPITAL_REACH of the anchor, how many lie in the
--      capital's protected city (hard_protection_kind_at "town"), and how
--      many would let a tortoise or a frog spawn at the surface through the
--      water attempt's own gates (SR.spawn_refused, the drift band for the
--      aggressive frog). The deepest lake column of each capital that has
--      one becomes a point.
--   2. WILD wild lakes from a coarse grid search (the water query's "lake",
--      at least 3 deep, outside every capital zone and town) become points.
--   3. The areas round the points are generated and force-loaded, the bed
--      under every lake column within BED_REACH is counted by node, and an
--      invisible probe player (it answers is_player and a name) floats over
--      each point. Over one day window every spawn near a point is counted
--      by mob and path (SR.spawn_mob for the zone kinds, SR.lake_fish when it
--      exists, the Reed Angelfish's ABM row through mobs_redo's custom
--      check), and a census lists the mobs in the water round each point.
-- Checks: no tortoise or frog spawns in a capital's lake, and (when
-- SR.lake_fish exists) every point has at least one fish by the end. Lines
-- "[r51lakes] ...", "RESULT PASS" / "RESULT FAIL".

local P = "[r51lakes] "
local WINDOW = tonumber(core.settings:get("r51lakes_window") or "") or 100
local CAPITAL_REACH = 240
local RADIUS = 56
local BED_REACH = 40
local WILD = 3
local SR = grug_mobs.spawn_regions
local failures = {}
local function log(msg) core.log("action", P .. msg) end
local function fail(msg)
	failures[#failures + 1] = msg
	log("CHECK FAIL " .. msg)
end

local WATER = {["default:water_source"] = true, ["default:river_water_source"] = true,
	["default:water_flowing"] = true, ["default:river_water_flowing"] = true}

core.register_entity("grug_probe_r51_lakes:hero", {
	initial_properties = {physical = false, pointable = false, static_save = false,
		visual = "sprite", textures = {"blank.png"}, is_visible = false,
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}},
	on_punch = function() return true end,
})
local fakes, methods = {}, nil
local function make_player(name, pos)
	local ref = core.add_entity(pos, "grug_probe_r51_lakes:hero")
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
-- 1. The capitals' water.
--
local POINTS = {}
local capital_zone = {}
local function surface_y(x, z, depth)
	return grug_zones.terrain_height_at(x, z) + (depth or 0)
end
local function scan_capitals()
	for _, zone_id in ipairs(SR.zone_ids()) do
		local a = grug_zones.anchor(zone_id, "capital")
		if a then
			capital_zone[zone_id] = true
			local n = {lake = 0, river = 0, town = 0, tortoise = 0, frog = 0}
			local deepest
			for z = a.z - CAPITAL_REACH, a.z + CAPITAL_REACH, 2 do
				for x = a.x - CAPITAL_REACH, a.x + CAPITAL_REACH, 2 do
					local class, zone, _, _, depth = grug_zones.water_query_at(x, z)
					if (class == "lake" or class == "river") and zone == zone_id then
						n[class] = n[class] + 1
						local stand = {x = x, y = surface_y(x, z, depth), z = z}
						if grug_zones.hard_protection_kind_at(stand) == "town" then
							n.town = n.town + 1
						end
						if not SR.spawn_refused("grug_mobs:tortoise_t3", stand) then
							n.tortoise = n.tortoise + 1
						end
						if not SR.spawn_refused("grug_mobs:frog_t3", stand)
								and not SR.in_drift(stand) then
							n.frog = n.frog + 1
						end
						if class == "lake" and (not deepest or depth > deepest.depth) then
							deepest = {x = x, z = z, depth = depth}
						end
					end
				end
			end
			log(("capital %s at (%d, %d): lake %d, river %d columns (every 2nd), in the town %d; open to a tortoise %d, to a frog %d"):format(
				zone_id, a.x, a.z, n.lake, n.river, n.town, n.tortoise, n.frog))
			-- The capital's own lakes: every lake column joined (4-neighbour,
			-- the same zone) to a lake column in the protected city.
			local seen, queue, head = {}, {}, 1
			for z = a.z - CAPITAL_REACH, a.z + CAPITAL_REACH, 2 do
				for x = a.x - CAPITAL_REACH, a.x + CAPITAL_REACH, 2 do
					local class, zone, _, _, depth = grug_zones.water_query_at(x, z)
					if class == "lake" and zone == zone_id and grug_zones.hard_protection_kind_at(
							{x = x, y = surface_y(x, z, depth), z = z}) == "town" then
						local key = x .. "," .. z
						if not seen[key] then seen[key] = true; queue[#queue + 1] = {x, z} end
					end
				end
			end
			local c = {n = 0, town = 0, tortoise = 0, frog = 0}
			local box
			while head <= #queue and c.n < 80000 do
				local x, z = queue[head][1], queue[head][2]
				head = head + 1
				local class, zone, _, _, depth = grug_zones.water_query_at(x, z)
				if class == "lake" and zone == zone_id then
					c.n = c.n + 1
					local stand = {x = x, y = surface_y(x, z, depth), z = z}
					if grug_zones.hard_protection_kind_at(stand) == "town" then c.town = c.town + 1 end
					local open_t = not SR.spawn_refused("grug_mobs:tortoise_t3", stand)
					local open_f = not SR.spawn_refused("grug_mobs:frog_t3", stand) and not SR.in_drift(stand)
					if open_t then c.tortoise = c.tortoise + 1 end
					if open_f then c.frog = c.frog + 1 end
					if open_t or open_f then
						box = box or {x0 = x, x1 = x, z0 = z, z1 = z}
						box.x0, box.x1 = math.min(box.x0, x), math.max(box.x1, x)
						box.z0, box.z1 = math.min(box.z0, z), math.max(box.z1, z)
					end
					for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
						local key = (x + d[1]) .. "," .. (z + d[2])
						if not seen[key] then seen[key] = true; queue[#queue + 1] = {x + d[1], z + d[2]} end
					end
				end
			end
			log(("capital %s: its own lakes %d columns, in the town %d; open to a tortoise %d, to a frog %d%s"):format(
				zone_id, c.n, c.town, c.tortoise, c.frog, box and (" in x %d..%d z %d..%d"):format(
				box.x0, box.x1, box.z0, box.z1) or ""))
			if c.tortoise + c.frog > 0 then
				fail(("%s: %d columns of its own lakes are open to a tortoise or a frog"):format(zone_id,
					math.max(c.tortoise, c.frog)))
			end
			if deepest then
				POINTS[#POINTS + 1] = {id = "capital_" .. zone_id, x = deepest.x, z = deepest.z,
					depth = deepest.depth, zone = zone_id, capital = true}
			end
		end
	end
end

--
-- 2. Wild lakes.
--
local function find_wild()
	local seen_zone = {}
	for z = -3600, 3600, 48 do
		for x = -4000, 4000, 48 do
			if #POINTS >= WILD + 6 then return end
			local class, zone, _, _, depth = grug_zones.water_query_at(x, z)
			if class == "lake" and zone and not capital_zone[zone] and not seen_zone[zone]
					and (depth or 0) >= 3 then
				local stand = {x = x, y = surface_y(x, z, depth), z = z}
				if grug_zones.hard_protection_kind_at(stand) == nil then
					seen_zone[zone] = true
					local wild = 0
					for _, p in ipairs(POINTS) do if not p.capital then wild = wild + 1 end end
					if wild < WILD then
						POINTS[#POINTS + 1] = {id = "wild_" .. zone, x = x, z = z, depth = depth,
							zone = zone, biome = grug_zones.biome_at(x, z)}
					end
				end
			end
		end
	end
end

--
-- 3. Spawns and census.
--
local spawned = {} -- point id -> {key -> n}
local function nearest_point(pos)
	local best, bd
	for _, p in ipairs(POINTS) do
		local dx, dz = pos.x - p.x, pos.z - p.z
		local d = dx * dx + dz * dz
		if not bd or d < bd then best, bd = p, d end
	end
	return best, bd and math.sqrt(bd)
end
local function count_spawn(path, name, pos)
	local p, d = nearest_point(pos)
	if not p or d > RADIUS + 64 then return end
	local key = path .. " " .. name:gsub("^grug_mobs:", "")
	spawned[p.id] = spawned[p.id] or {}
	spawned[p.id][key] = (spawned[p.id][key] or 0) + 1
	if p.capital and path == "kind" and (name:find("tortoise") or name:find("frog")) then
		local class = grug_zones.water_query_at(pos.x, pos.z)
		if class == "lake" then
			fail(("%s spawned in the capital lake of %s at %s"):format(name, p.zone,
				core.pos_to_string(vector.round(pos))))
		end
	end
end
local original_spawn = SR.spawn_mob
SR.spawn_mob = function(unit, role, g, clock)
	local ent = original_spawn(unit, role, g, clock)
	if ent then count_spawn("kind", "grug_mobs:" .. role, {x = g.x, y = g.y + 1, z = g.z}) end
	return ent
end
if SR.lake_fish then
	local original_fish = SR.lake_fish
	SR.lake_fish = function(w, ...)
		local ent = original_fish(w, ...)
		if ent then count_spawn("lake_fish", ent.name, w) end
		return ent
	end
end
local row_tries = {tried = 0, refused = 0}
core.register_on_mods_loaded(function()
	local check = mobs.spawn_abm_check
	mobs.spawn_abm_check = function(self, pos, node, name)
		local refused = check(self, pos, node, name)
		if name == "grug_mobs:reed_angelfish" then
			row_tries.tried = row_tries.tried + 1
			if refused then row_tries.refused = row_tries.refused + 1 end
		end
		return refused
	end
end)
-- mobs_redo's row spawns through core.add_entity: count new Reed Angelfish.
local known = {}
local function sweep_new(final)
	for _, point in ipairs(POINTS) do
		for _, object in ipairs(core.get_objects_inside_radius({x = point.x, y = point.y, z = point.z},
				RADIUS + 16)) do
			local ent = object:get_luaentity()
			if ent and ent.name == "grug_mobs:reed_angelfish" and not known[ent] then
				known[ent] = true
				if not final then count_spawn("seen", ent.name, object:get_pos()) end
			end
		end
	end
end

local function bed_census(point)
	local by, columns = {}, 0
	for z = point.z - BED_REACH, point.z + BED_REACH do
		for x = point.x - BED_REACH, point.x + BED_REACH do
			local class, zone, _, _, depth = grug_zones.water_query_at(x, z)
			if class == "lake" and zone == point.zone then
				local top = surface_y(x, z, depth)
				for y = top, top - 24, -1 do
					local name = core.get_node({x = x, y = y, z = z}).name
					if not WATER[name] and name ~= "air" then
						by[name] = (by[name] or 0) + 1
						columns = columns + 1
						break
					end
				end
			end
		end
	end
	local rows = {}
	for k, n in pairs(by) do rows[#rows + 1] = ("%s=%d"):format(k, n) end
	table.sort(rows)
	log(("bed %s: %d lake columns within %d: %s"):format(point.id, columns, BED_REACH,
		table.concat(rows, " ")))
end

local function census(point)
	local by, rows = {}, {}
	for _, object in ipairs(core.get_objects_inside_radius({x = point.x, y = point.y, z = point.z},
			RADIUS + 16)) do
		local ent = object:get_luaentity()
		if ent and ent.name and ent.name:sub(1, 10) == "grug_mobs:" then
			local pos = object:get_pos()
			local key = ("%s %s"):format(ent.name:sub(11),
				WATER[core.get_node(vector.round(pos)).name] and "in_water" or "out")
			by[key] = (by[key] or 0) + 1
		end
	end
	local fish = 0
	for k, n in pairs(by) do
		rows[#rows + 1] = k .. "=" .. n
		if k == "reed_angelfish in_water" then fish = n end
	end
	table.sort(rows)
	log(("census %s [%s]"):format(point.id, table.concat(rows, " ")))
	return fish
end

local function finish()
	sweep_new(false)
	local outcomes = {}
	for k, v in pairs(SR.stats) do outcomes[#outcomes + 1] = k .. "=" .. v end
	table.sort(outcomes)
	log("attempt outcomes: " .. table.concat(outcomes, " "))
	log(("Reed Angelfish ABM row: tried %d, refused by its check %d"):format(row_tries.tried,
		row_tries.refused))
	for _, point in ipairs(POINTS) do
		local fish = census(point)
		local keys = {}
		for k, n in pairs(spawned[point.id] or {}) do keys[#keys + 1] = k .. " x" .. n end
		table.sort(keys)
		log(("spawned near %s: %s"):format(point.id, #keys > 0 and table.concat(keys, "; ") or "none"))
		if SR.lake_fish and fish < 1 then fail("no fish in the lake at " .. point.id) end
	end
	log((#failures == 0 and "RESULT PASS" or "RESULT FAIL") .. " failures=" .. #failures)
	core.request_shutdown("r51 lakes probe done", false, 0)
end

local function start()
	local players = {}
	for _, point in ipairs(POINTS) do
		bed_census(point)
		players[#players + 1] = make_player("probe_" .. point.id,
			{x = point.x, y = point.y + 1, z = point.z})
	end
	sweep_new(true) -- whatever the generation already holds is not a spawn
	SR.players = function() return players end
	core.set_timeofday(0.5)
	for s = 10, WINDOW, 10 do
		core.after(s, function()
			core.set_timeofday(0.5)
			sweep_new(false)
		end)
	end
	log(("window: %d s by day"):format(WINDOW))
	core.after(WINDOW, finish)
end

core.after(2, function()
	local t0 = core.get_us_time()
	scan_capitals()
	find_wild()
	log(("points found in %.1f s"):format((core.get_us_time() - t0) / 1e6))
	if #POINTS == 0 then
		log("RESULT FAIL no point")
		core.request_shutdown("r51 lakes probe failed", false, 0)
		return
	end
	local pending = 0
	for _, point in ipairs(POINTS) do
		point.y = surface_y(point.x, point.z, point.depth)
		log(("point %s (%d, %d): lake %d deep, surface y %d%s"):format(point.id, point.x, point.z,
			point.depth, point.y, point.biome and (", biome " .. point.biome) or ""))
		local minp = {x = point.x - RADIUS, y = point.y - 40, z = point.z - RADIUS}
		local maxp = {x = point.x + RADIUS - 1, y = point.y + 31, z = point.z + RADIUS - 1}
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
