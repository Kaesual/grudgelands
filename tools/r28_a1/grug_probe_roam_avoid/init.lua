-- Round 28 Lane A1 engine probe (disposable, never shipped): the road and
-- town push (ruling 2) on the real zone authority of a real boot.
--
-- 1. The census: aggressive registered mobs and their view ranges (the
--    probe radius).
-- 2. Beside real roads: a mob position 8 nodes outside the corridor's
--    protection reach, at the road surface height, probes with radius 14;
--    the ring must hit and the away direction must point away from the road.
-- 3. Beside every start town and two capital cities: a position 4 nodes
--    outside the town along +x; the push must point away (+x).
-- 4. The cost of one probe (eight points: world_feature_at and
--    hard_protection_kind_at each) over 4000 positions, half beside roads,
--    half anywhere (comparison only).
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r28_roam_avoid_probe] "
local checks, failures = 0, 0
local function log(message) core.log("action", PREFIX .. message) end
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", PREFIX .. "FAIL " .. label)
	end
	return ok
end

local modpath = core.get_modpath("grug_mapgen") .. "/wp40"
local roads = dofile(modpath .. "/road_layout.lua")
local wp = dofile(modpath .. "/world_protection.lua")

local function census()
	local count, low, high, missing = 0, math.huge, 0, 0
	for _, def in pairs(core.registered_entities) do
		if def._grug_disposition == "aggressive" then
			count = count + 1
			if type(def.view_range) == "number" then
				low, high = math.min(low, def.view_range), math.max(high, def.view_range)
			else
				missing = missing + 1
			end
		end
	end
	log(("CENSUS %d aggressive mob definitions, view range %s..%s, %d without one"):format(
		count, tostring(low), tostring(high), missing))
	check(count > 0, "aggressive mobs registered")
	check(type(grug_mobs.roam_avoid_tick) == "function", "roam_avoid loaded")
end

local function road_case(layout)
	local tested = 0
	local ids = {}
	for id in pairs(layout.roads) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local r = layout.roads[id]
		if (r.kind == "primary" or r.kind == "secondary" or r.kind == "trail") and
				#r.X > 40 and tested < 6 then
			local i = math.floor(#r.X / 2)
			local tx, tz = r.X[i + 1] - r.X[i], r.Z[i + 1] - r.Z[i]
			local l = math.sqrt(tx * tx + tz * tz)
			if l > 0 then
				local nx, nz = -tz / l, tx / l
				local offset = r.hw + wp.ROAD_SIDE + 8
				local s = wp.surface_node(r.R[i], r.R[i], 0)
				local pos = {x = r.X[i] + nx * offset, y = s + 1, z = r.Z[i] + nz * offset}
				local hits = grug_mobs.roam_avoid_probe(pos, 14)
				local n = 0
				for k = 1, 8 do if hits[k] then n = n + 1 end end
				local ax, az = grug_mobs.roam_avoid_away(hits)
				local here = grug_core.world_feature_at(pos)
				log(("ROAD %d %s at %s: own feature %s, %d ring hits, away %s"):format(r.id,
					r.kind, core.pos_to_string(pos, 1), tostring(here), n,
					ax and ("%.2f,%.2f"):format(ax, az) or "none"))
				-- a position inside another feature is no clean case
				if here == nil then
					check(n > 0, "road " .. r.id .. " seen")
					check(ax ~= nil and ax * nx + az * nz > 0.5, "road " .. r.id ..
						" pushes away")
					tested = tested + 1
				end
			end
		end
	end
	check(tested >= 3, "roads tested")
end

local function town_case()
	local towns = {}
	for _, identity in ipairs(grug_core.start_identities()) do
		towns[#towns + 1] = {label = "start " .. identity.race_id, anchor = identity.anchor}
	end
	towns[#towns + 1] = {label = "capital human",
		anchor = grug_core.capital_anchor("accord", "human")}
	towns[#towns + 1] = {label = "capital orc",
		anchor = grug_core.capital_anchor("throng", "orc")}
	check(#towns == 8, "six starts and two capitals")
	for _, town in ipairs(towns) do
		local a = town.anchor
		local edge
		for d = 0, 400 do
			if grug_zones.hard_protection_kind_at({x = a.x + d, y = a.y + 2, z = a.z}) ~=
					"town" then
				edge = d
				break
			end
		end
		if check(edge ~= nil and edge > 0, town.label .. " has a town footprint") then
			local pos = {x = a.x + edge + 4, y = a.y + 2, z = a.z}
			local hits = grug_mobs.roam_avoid_probe(pos, 14)
			local toward = hits[5]
			local ax, az = grug_mobs.roam_avoid_away(hits)
			log(("TOWN %s: edge +%d, probe at %s, away %s"):format(town.label, edge,
				core.pos_to_string(pos), ax and ("%.2f,%.2f"):format(ax, az) or "none"))
			check(toward == true, town.label .. " seen toward the town")
			check(ax ~= nil and ax > 0.3, town.label .. " pushes away")
		end
	end
end

local function timing(layout)
	local list = {}
	for _, r in pairs(layout.roads) do list[#list + 1] = r end
	table.sort(list, function(a, b) return a.id < b.id end)
	local random = PcgRandom(28)
	local samples = {}
	for k = 1, 2000 do
		local r = list[random:next(1, #list)]
		local i = random:next(1, #r.X)
		samples[k] = {x = r.X[i] + random:next(-20, 20),
			y = wp.surface_node(r.R[i], r.R[i], 0) + 1, z = r.Z[i] + random:next(-20, 20)}
	end
	for k = 2001, 4000 do
		local x, z = random:next(-3600, 3600), random:next(-3200, 3200)
		samples[k] = {x = x, y = (grug_zones.terrain_height_at(x, z) or 0) + 1, z = z}
	end
	local pushes = 0
	for _, p in ipairs(samples) do
		if grug_mobs.roam_avoid_away(grug_mobs.roam_avoid_probe(p, 14)) then
			pushes = pushes + 1
		end
	end
	local rounds = 5
	local t0 = core.get_us_time()
	for _ = 1, rounds do
		for _, p in ipairs(samples) do grug_mobs.roam_avoid_probe(p, 14) end
	end
	local us = (core.get_us_time() - t0) / (rounds * #samples)
	log(("TIMING %.2f us per probe of eight points (%.2f us per point), %d of %d " ..
		"positions push"):format(us, us / 8, pushes, #samples))
end

core.after(2, function()
	local ok, err = pcall(function()
		census()
		local layout = roads.deserialize(grug_mapgen.wp40.road_layout_text)
		road_case(layout)
		town_case()
		timing(layout)
	end)
	check(ok, "probe ran: " .. tostring(err))
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r28 roam avoid probe done", false, 0)
end)
