-- Disposable engine probe (Round 28 Lane M1). Never shipped:
-- tools/r28_m1/probe.sh stages it through tools/luanti_headless.sh.
--
-- A headless server has no player, so the probe drives the real location
-- lookup (grug_map.location.text_at) with positions instead:
--   WALK   from every start town's and capital city's anchor east and north
--          in 4-node steps, logging each change of the shown name (town
--          edge, zone border);
--   (ZONES and KINGS, the zone and King markers, went in Round 44);
--   COST   microseconds per lookup over a world grid and inside town boxes
--          (a comparison, not a target).
-- Then it shuts the server down.

local P = "[r28m1_probe] "
local function log(msg) core.log("action", P .. msg) end

local function walk(label, x0, z0, dx, dz, steps)
	local M = grug_map.location
	local last
	local changes = {}
	for i = 0, steps do
		local x, z = x0 + dx * i, z0 + dz * i
		local text = M.text_at({x = x, y = 0, z = z})
		if text ~= last then
			changes[#changes + 1] = ("%s@%d,%d"):format(text, x, z)
			last = text
		end
	end
	log(("WALK %s: %s"):format(label, table.concat(changes, " -> ")))
	return changes
end

local function run()
	local ok = true
	local M = grug_map.location
	local atlas = grug_map.atlas
	-- WALK: from each town anchor east and north.
	local towns_seen, zones_seen = 0, 0
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		local a = row.anchor
		local _, kind = grug_zones.hard_footprint_in(a.x, a.z, a.x, a.z)
		if kind == "town" then
			local east = walk(row.key .. " east", a.x, a.z, 4, 0, 200)
			local north = walk(row.key .. " north", a.x, a.z, 0, 4, 200)
			local name = row.display_name or row.key
			if east[1]:find("^" .. name .. "@") and #east >= 2 then towns_seen = towns_seen + 1 end
			if #north >= 2 then zones_seen = zones_seen + 1 end
		elseif row.key:find("_village$") then
			local text = M.text_at(a)
			local zone = grug_zones.get(grug_zones.id_at(a.x, a.z))
			log(("VILLAGE %s shows %s (zone %s)"):format(row.key, text, zone.display_name))
			ok = ok and text == zone.display_name
		end
	end
	log(("WALK towns starting with their own name and leaving it: %d of 12; " ..
		"north walks with a change: %d"):format(towns_seen, zones_seen))
	ok = ok and towns_seen == 12

	-- ZONES and KINGS went with the zone and King markers in Round 44 (the
	-- map window draws neither; the kings are baked into the map image).
	local view = atlas.view()

	-- COST: a world grid (mostly outside towns) and the town boxes.
	local function cost(label, points)
		local started = core.get_us_time()
		for i = 1, #points do M.text_at(points[i]) end
		local us = (core.get_us_time() - started) / #points
		log(("COST %s: %.2f us per lookup over %d points"):format(label, us, #points))
	end
	local grid, town = {}, {}
	for z = view.min_z, view.max_z, 50 do
		for x = view.min_x, view.max_x, 50 do grid[#grid + 1] = {x = x + 0.3, y = 0, z = z + 0.7} end
	end
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		local a = row.anchor
		local _, kind = grug_zones.hard_footprint_in(a.x, a.z, a.x, a.z)
		if kind == "town" then
			for dz = -250, 250, 25 do
				for dx = -250, 250, 25 do town[#town + 1] = {x = a.x + dx, y = 0, z = a.z + dz} end
			end
		end
	end
	cost("world grid", grid)
	cost("town boxes", town)
	local id_started = core.get_us_time()
	for i = 1, #grid do grug_zones.id_at(grid[i].x, grid[i].z) end
	log(("COST grug_zones.id_at alone: %.2f us per call"):format(
		(core.get_us_time() - id_started) / #grid))
	log(ok and "RESULT PASS" or "RESULT FAIL")
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		local ok, err = pcall(run)
		if not ok then
			log("RESULT FAIL " .. tostring(err))
			core.request_shutdown("probe failed", false, 0)
		end
	end)
end)
