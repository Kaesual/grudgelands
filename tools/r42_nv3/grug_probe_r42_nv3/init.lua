-- Disposable Round 42 NV3 probe (tools/r42_nv3/run.sh). Never shipped.
--
-- Loads one settlement at a time (forceloaded, no player) and watches the
-- REAL placement and the REAL movement code for OBS seconds:
--   * every core.find_path call (count, cost, the largest), in 30 s buckets;
--   * the navigation's counters (searches, found, cap waits);
--   * the walkers (residents with a spot ring): ring sizes (one-spot walkers),
--     arrivals at a spot and spots given up without arriving;
--   * the patrols: waypoints advanced, snaps;
--   * the route cache's own statistics when the code has one
--     (grug_mobs.route_cache_stats, Round 42 NV3).
-- Targets (setting grug_nv3_targets, comma separated): start (the first start
-- identity's start town), village (the Round 14 village nearest to it),
-- capital (the first identity's capital), streets (pure data: the capital's
-- streets against its patrol points and walker spots, no terrain).
-- Results go to <world>/nv3_results.json; every log line carries "[nv3]".

local P = "[nv3] "
local now = core.get_us_time
local floor, sqrt, max, min = math.floor, math.sqrt, math.max, math.min
local function log(s) core.log("action", P .. s) end

local TARGETS = {}
for word in (core.settings:get("grug_nv3_targets") or "start"):gmatch("[%w_]+") do
	TARGETS[#TARGETS + 1] = word
end
local OBS = tonumber(core.settings:get("grug_nv3_obs") or "") or 90
-- After the first window: the census of every leg, then a second window of
-- this many seconds on the full cache (0: neither).
local STEADY = tonumber(core.settings:get("grug_nv3_steady") or "") or 0
local BUCKET = 30

local results = {meta = {targets = TARGETS, obs = OBS,
	seed = core.get_mapgen_setting("seed")}, settlements = {}}

local function sanitize(value)
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then return nil end
		return value
	elseif kind == "table" then
		local out = {}
		for k, v in pairs(value) do out[k] = sanitize(v) end
		return out
	elseif kind == "string" or kind == "boolean" then
		return value
	end
	return nil
end

local function write_results()
	local path = core.get_worldpath() .. "/nv3_results.json"
	local text = core.write_json(sanitize(results))
	if not text or not core.safe_file_write(path, text) then
		core.log("error", P .. "could not write " .. path)
		return
	end
	log("wrote " .. path .. " (" .. #text .. " bytes)")
end

local function r2(v) return floor(v * 100 + 0.5) / 100 end

---------------------------------------------------------------------------
-- Instrumentation: every engine search, wherever it comes from.
---------------------------------------------------------------------------
local fp = nil -- the record being filled, or nil
local real_find_path = core.find_path
core.find_path = function(a, b, ...)
	local t0 = now()
	local path = real_find_path(a, b, ...)
	local us = now() - t0
	if fp then
		local bucket = floor((now() - fp.t0) / 1e6 / BUCKET) + 1
		fp.n = fp.n + 1
		fp.us = fp.us + us
		if path then fp.found = fp.found + 1 end
		if us > fp.max_us then
			fp.max_us = us
			local dx, dz = b.x - a.x, b.z - a.z
			fp.max_d = r2(sqrt(dx * dx + dz * dz))
		end
		fp.buckets[bucket] = (fp.buckets[bucket] or 0) + 1
		local box = fp.box
		if box and (a.x < box[1].x or a.x > box[2].x or a.z < box[1].z or a.z > box[2].z) then
			fp.outside = fp.outside + 1
		end
	end
	return path
end

local snaps = 0
local real_snap_to = grug_mobs.snap_to
grug_mobs.snap_to = function(...)
	local ok = real_snap_to(...)
	if ok and fp then snaps = snaps + 1 end
	return ok
end

---------------------------------------------------------------------------
-- Settlements
---------------------------------------------------------------------------
local function same(a, b)
	return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function record_at(anchor)
	for _, record in ipairs(grug_core.settlement_socket_settlements()) do
		if same(record.anchor, anchor) then return record end
	end
end

local function nearest_village(from)
	local best, best_d2
	for _, record in ipairs(grug_core.settlement_socket_settlements()) do
		for _, socket in ipairs(grug_core.settlement_sockets_at(record.key)) do
			if socket.role == "quest" and socket.id == "quest_steward" then
				local dx, dz = record.anchor.x - from.x, record.anchor.z - from.z
				local d2 = dx * dx + dz * dz
				if not best_d2 or d2 < best_d2 then best, best_d2 = record, d2 end
				break
			end
		end
	end
	return best
end

local function bounds(record)
	local minp, maxp = vector.copy(record.anchor), vector.copy(record.anchor)
	for _, socket in ipairs(grug_core.settlement_sockets_at(record.key)) do
		local p = socket.pos
		minp = {x = min(minp.x, p.x), y = min(minp.y, p.y), z = min(minp.z, p.z)}
		maxp = {x = max(maxp.x, p.x), y = max(maxp.y, p.y), z = max(maxp.z, p.z)}
	end
	return vector.offset(minp, -8, -8, -8), vector.offset(maxp, 8, 16, 8)
end

local function target_record(name)
	local identity = grug_core.start_identities()[1]
	local start = grug_core.start_anchor(identity.faction_id, identity.race_id)
	if name == "start" then return record_at(start) end
	if name == "capital" or name == "streets" then
		return record_at(grug_core.capital_anchor(identity.faction_id, identity.race_id))
	end
	if name == "village" then return nearest_village(start) end
end

local function blocks_of(minp, maxp, fn)
	local n = 0
	for bx = floor(minp.x / 16), floor(maxp.x / 16) do
		for bz = floor(minp.z / 16), floor(maxp.z / 16) do
			for by = floor(minp.y / 16), floor(maxp.y / 16) do
				if fn(vector.new(bx * 16, by * 16, bz * 16)) then n = n + 1 end
			end
		end
	end
	return n
end

-- The movers of the settlement, by entity.
local function movers(minp, maxp, key)
	local walkers, patrols = {}, {}
	for _, obj in ipairs(core.get_objects_in_area(minp, maxp)) do
		local ent = obj:get_luaentity()
		if ent and ent._grug_start == key then
			if type(ent._grug_idle_spots) == "table" and not ent._grug_work_activity then
				walkers[#walkers + 1] = ent
			elseif type(ent._grug_patrol_route) == "table" then
				patrols[#patrols + 1] = ent
			end
		end
	end
	return walkers, patrols
end

local function nav_counters()
	local c = mobs.grug_nav and mobs.grug_nav.counters or {}
	return {searches = c.searches or 0, found = c.found or 0,
		cap_waits = c.cap_waits or 0}
end

local function observe(name, record, minp, maxp, done, obs)
	obs = obs or OBS
	local walkers, patrols = movers(minp, maxp, record.key)
	local wrec, prec = {}, {}
	local one_spot, rings = 0, {}
	for i, ent in ipairs(walkers) do
		local n = #ent._grug_idle_spots
		rings[#rings + 1] = n
		if ent._grug_walker and n < 2 then one_spot = one_spot + 1 end
		wrec[i] = {ent = ent, walker = ent._grug_walker == true, ring = n,
			spot = ent._grug_idle_spot, dwell = ent._grug_idle_dwell ~= nil,
			arrivals = 0, give_ups = 0, travel = 0}
	end
	for i, ent in ipairs(patrols) do
		prec[i] = {ent = ent, wp = ent._grug_patrol_route.wp, advances = 0}
	end
	snaps = 0
	local c0 = nav_counters()
	collectgarbage("collect")
	local mem0 = collectgarbage("count")
	fp = {t0 = now(), n = 0, us = 0, found = 0, max_us = 0, max_d = 0, buckets = {},
		outside = 0, box = {minp, maxp}}
	local elapsed = 0
	local function poll()
		elapsed = elapsed + 0.5
		for _, w in ipairs(wrec) do
			local ent = w.ent
			if ent.object and ent.object:get_pos() then
				local dwell = ent._grug_idle_dwell ~= nil
				local spot = ent._grug_idle_spot
				if dwell and not w.dwell then w.arrivals = w.arrivals + 1 end
				if not dwell and not w.dwell and spot ~= w.spot then
					w.give_ups = w.give_ups + 1
				end
				if not dwell then w.travel = w.travel + 0.5 end
				w.dwell, w.spot = dwell, spot
			end
		end
		for _, p in ipairs(prec) do
			local route = p.ent._grug_patrol_route
			if route and route.wp ~= p.wp then
				p.advances = p.advances + 1
				p.wp = route.wp
			end
		end
		if elapsed < obs then return core.after(0.5, poll) end
		local f = fp
		fp = nil
		local c1 = nav_counters()
		local out = {key = record.key, kind = name, obs = obs,
			find_path = {n = f.n, per_min = r2(f.n * 60 / obs), found = f.found,
				total_ms = r2(f.us / 1000), max_us = f.max_us, max_d = f.max_d,
				buckets = f.buckets, outside = f.outside},
			nav = {searches = c1.searches - c0.searches, found = c1.found - c0.found,
				cap_waits = c1.cap_waits - c0.cap_waits},
			walkers = {}, patrols = {}, one_spot_walkers = one_spot,
			snaps = snaps}
		local arr, gu, walking = 0, 0, 0
		for _, w in ipairs(wrec) do
			out.walkers[#out.walkers + 1] = {walker = w.walker, ring = w.ring,
				arrivals = w.arrivals, give_ups = w.give_ups, travel_s = w.travel}
			arr, gu = arr + w.arrivals, gu + w.give_ups
			if w.walker then walking = walking + 1 end
		end
		local adv = 0
		for _, p in ipairs(prec) do
			out.patrols[#out.patrols + 1] = {advances = p.advances,
				points = #p.ent._grug_patrol_route.points}
			adv = adv + p.advances
		end
		if grug_mobs.route_cache_stats then
			out.cache = grug_mobs.route_cache_stats(record.key)
		end
		collectgarbage("collect")
		out.lua_kib_delta = r2(collectgarbage("count") - mem0)
		results.settlements[#results.settlements + 1] = out
		log(("LIVE %s %s: %d ambling residents (%d walkers, %d one-spot), %d patrols; " ..
			"%d s: find_path %d (%.1f/min, found %d, max %d us at d %.1f, %.1f ms), " ..
			"nav searches %d, cap waits %d; arrivals %d, spots given up %d, " ..
			"patrol advances %d, snaps %d"):format(name, record.key, #wrec, walking,
			one_spot, #prec, obs, f.n, f.n * 60 / obs, f.found, f.max_us, f.max_d,
			f.us / 1000, out.nav.searches, out.nav.cap_waits, arr, gu, adv, snaps))
		if out.cache then
			log("LIVE cache " .. core.write_json(out.cache))
		end
		write_results()
		done()
	end
	core.after(0.5, poll)
end

-- Every leg of the settlement's walkers (their rings, forward) and patrols
-- (their loops) through the route cache, the way the walkers ask for them,
-- until none is pending: the whole cache's first-use cost and its no-route
-- legs. Only with a route cache (Round 42 NV3).
local function census(name, record, minp, maxp, done)
	if not grug_mobs.route_walk or not grug_mobs.route_cache_stats(record.key) then
		return done()
	end
	local walkers, patrols = movers(minp, maxp, record.key)
	local legs, seen = {}, {}
	local function add(ent, a, b, patrol)
		if not a or not b or a.y == nil or b.y == nil then return end
		local k = ("%s %d,%d,%d>%d,%d,%d"):format(patrol and "p" or "w", a.x, a.y, a.z,
			b.x, b.y, b.z)
		if seen[k] then return end
		seen[k] = true
		local dx, dz = b.x - a.x, b.z - a.z
		legs[#legs + 1] = {ent = ent, a = a, b = b, patrol = patrol,
			d = r2(sqrt(dx * dx + dz * dz))}
	end
	for _, ent in ipairs(walkers) do
		local spots = ent._grug_idle_spots
		if #spots >= 2 then
			for i = 1, #spots do add(ent, spots[i], spots[i % #spots + 1], false) end
		end
	end
	for _, ent in ipairs(patrols) do
		local pts = ent._grug_patrol_route.points
		for i = 1, #pts do add(ent, pts[i], pts[i % #pts + 1], true) end
	end
	local s0 = grug_mobs.route_cache_stats(record.key)
	collectgarbage("collect")
	local mem0 = collectgarbage("count")
	local t0 = now()
	local i, steps = 1, 0
	local out = {legs = {}, walker = {legs = 0, ok = 0, none = 0},
		patrol = {legs = 0, ok = 0, none = 0, street = 0}}
	local function tick()
		steps = steps + 1
		for _ = 1, 8 do
			local leg = legs[i]
			if not leg then break end
			local ent = leg.ent
			local pos = ent.object and ent.object:get_pos()
			if not pos then
				i = i + 1
			else
				ent.temp = ent.temp or {}
				ent.temp.grug_leg = nil
				grug_mobs.route_walk(ent, 0, pos, record.key, leg.a, leg.b, "nv3_census",
					leg.patrol)
				local entry = ent.temp.grug_leg and ent.temp.grug_leg.entry
				local state = entry and entry.state or "?"
				if state == "pending" then break end
				grug_mobs.route_clear(ent, "nv3_census")
				local kind = leg.patrol and out.patrol or out.walker
				kind.legs = kind.legs + 1
				if state == "ok" then kind.ok = kind.ok + 1 else kind.none = kind.none + 1 end
				if leg.patrol and entry and entry.street then kind.street = kind.street + 1 end
				out.legs[#out.legs + 1] = {who = leg.patrol and "patrol" or "walker",
					d = leg.d, state = state, street = entry and entry.street or nil,
					corners = entry and entry.points and #entry.points or 0,
					a = state ~= "ok" and core.pos_to_string(leg.a) or nil,
					b = state ~= "ok" and core.pos_to_string(leg.b) or nil}
				i = i + 1
			end
		end
		if legs[i] and steps < 3000 then return core.after(0, tick) end
		local s1 = grug_mobs.route_cache_stats(record.key)
		collectgarbage("collect")
		out.lua_kib_delta = r2(collectgarbage("count") - mem0)
		out.seconds = r2((now() - t0) / 1e6)
		out.steps = steps
		out.searches = s1.searches - s0.searches
		out.search_ms = r2((s1.search_us - s0.search_us) / 1000)
		out.cache = s1
		results.census = results.census or {}
		results.census[#results.census + 1] = out
		log(("CENSUS %s %s: %d distinct legs in %.1f s (%d steps): walkers %d (ok %d, " ..
			"none %d), patrols %d (ok %d, none %d, street %d); %d more searches, %.1f ms; " ..
			"cache %s"):format(name, record.key, #out.legs, out.seconds, steps,
			out.walker.legs, out.walker.ok, out.walker.none, out.patrol.legs, out.patrol.ok,
			out.patrol.none, out.patrol.street, out.searches, out.search_ms,
			core.write_json(s1)))
		write_results()
		done()
	end
	core.after(0, tick)
end

local function phase_live(name, done)
	local record = target_record(name)
	if not record then
		log("no settlement for " .. name)
		return done()
	end
	local minp, maxp = bounds(record)
	local blocks = blocks_of(minp, maxp, function(p)
		return core.forceload_block(p, true, -1)
	end)
	log(("LIVE %s %s box %s - %s, %d blocks forceloaded"):format(name, record.key,
		core.pos_to_string(minp), core.pos_to_string(maxp), blocks))
	local t0 = now()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining ~= 0 then return end
		log(("LIVE %s emerged in %.1f s"):format(name, (now() - t0) / 1e6))
		local last, stable, waited = -1, 0, 0
		local function poll()
			local n = #core.get_objects_in_area(minp, maxp)
			if n == last and n > 0 then stable = stable + 1 else stable = 0 end
			last, waited = n, waited + 3
			if stable >= 3 or waited >= 60 then
				log(("LIVE %s %d objects after %d s"):format(name, n, waited))
				local function free()
					blocks_of(minp, maxp, function(p)
						core.forceload_free_block(p, true)
						return true
					end)
					-- Let the area deactivate before the next target.
					core.after(5, done)
				end
				return observe(name, record, minp, maxp, function()
					if STEADY <= 0 then return free() end
					-- The whole cache, then the steady state on a full cache.
					census(name, record, minp, maxp, function()
						observe(name .. "_steady", record, minp, maxp, free, STEADY)
					end)
				end)
			end
			core.after(3, poll)
		end
		core.after(3, poll)
	end)
end

---------------------------------------------------------------------------
-- Streets (pure data): the capital's streets against its patrol points and
-- spots, read the way the runtime can (the road layout text in memory).
---------------------------------------------------------------------------
local function phase_streets(done)
	local record = target_record("streets")
	local text = grug_mapgen.wp40.road_layout_text
	collectgarbage("collect")
	local m0 = collectgarbage("count")
	local t0 = now()
	local roads_mod = dofile(core.get_modpath("grug_mapgen") .. "/wp40/road_layout.lua")
	local t1 = now()
	local layout = roads_mod.deserialize(text)
	local t2 = now()
	local streets, points = {}, 0
	local a = record.anchor
	for _, road in pairs(layout.roads) do
		if (road.kind == "avenue" or road.kind == "lane") then
			local dx, dz = road.X[1] - a.x, road.Z[1] - a.z
			if dx * dx + dz * dz < 320 * 320 then
				streets[#streets + 1] = road
				points = points + #road.X
			end
		end
	end
	local kinds = {}
	for _, road in pairs(layout.roads) do kinds[road.kind] = (kinds[road.kind] or 0) + 1 end
	collectgarbage("collect")
	local out = {key = record.key, text_bytes = #text, load_us = t1 - t0,
		deserialize_us = t2 - t1, kinds = kinds, streets = #streets,
		street_points = points, lua_kib_with_layout = r2(collectgarbage("count") - m0)}
	local function nearest(p)
		local best, bd2, by = nil, nil, nil
		for _, road in ipairs(streets) do
			for i = 1, #road.X do
				local dx, dz = road.X[i] - p.x, road.Z[i] - p.z
				local d2 = dx * dx + dz * dz
				if not bd2 or d2 < bd2 then bd2, best, by = d2, road.id, floor(road.R[i] + 0.5) + 1 end
			end
		end
		return best, bd2 and r2(sqrt(bd2)), by and (by - p.y)
	end
	local loops = {}
	for _, socket in ipairs(grug_core.settlement_sockets_at(record.key)) do
		if socket.role == "guard_patrol" then
			loops[socket.group] = loops[socket.group] or {}
			local id, d, dy = nearest(socket.pos)
			loops[socket.group][socket.order] = {id = socket.id, x = socket.pos.x,
				y = socket.pos.y, z = socket.pos.z, street = id, d = d, dy = dy}
		end
	end
	out.loops = loops
	for group, loop in pairs(loops) do
		local parts = {}
		for i = 1, #loop do
			local p, q = loop[i], loop[i % #loop + 1]
			local lx, lz = q and q.x - p.x or 0, q and q.z - p.z or 0
			local leg = sqrt(lx * lx + lz * lz)
			parts[#parts + 1] = ("%s(st %s d %.1f dy %s, leg %.0f)"):format(p.id,
				tostring(p.street), p.d or -1, tostring(p.dy), leg)
		end
		log("STREETS loop " .. group .. ": " .. table.concat(parts, " "))
	end
	layout = nil
	collectgarbage("collect")
	out.lua_kib_after_drop = r2(collectgarbage("count") - m0)
	results.streets = out
	log(("STREETS %s: text %d bytes, load %d us, deserialize %d us, %d streets " ..
		"(%d points) within 320, kinds %s, +%.0f KiB with the layout"):format(record.key,
		#text, out.load_us, out.deserialize_us, #streets, points,
		core.write_json(kinds), out.lua_kib_with_layout))
	write_results()
	done()
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
core.after(2, function()
	local i = 0
	local function next_target()
		i = i + 1
		local name = TARGETS[i]
		if not name then
			write_results()
			log("RESULT DONE")
			core.request_shutdown("nv3 done", false, 0)
			return
		end
		log("target " .. name)
		local ok, err = pcall(function()
			if name == "streets" then
				phase_streets(next_target)
			else
				phase_live(name, next_target)
			end
		end)
		if not ok then
			core.log("error", P .. name .. ": " .. tostring(err))
			next_target()
		end
	end
	next_target()
end)
