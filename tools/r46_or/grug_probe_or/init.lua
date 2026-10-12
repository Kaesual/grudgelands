-- Round 46 lane OR engine probe (disposable, never shipped): the resource
-- census per tier band against the live mapgen rows (plan §3).
--
-- Emerges one chunk column (80 x 80, X0..X0+79, Z0..Z0+79) from y +127 down
-- to y -1312 and counts, per tier band, the band's tier rock and every
-- resource node. Host = tier rock plus every resource node in the band (the
-- rock before the veins were placed). Reports per band the measured share of
-- all resources against the table's sum of 1/N, and per resource host/count
-- against its denominator N (wp40/r7_r6_manifest.lua). Checks:
--   * a resource with no denominator in a band has no node there (the gem
--     bands: own tier, one and two tiers deeper, nowhere else);
--   * the band share within 10 % of the table (budget rounding and veins
--     cut by caves or collisions; rough targets only).
-- The column must be open land: the probe logs the columns that answer a
-- hard-protection kind or a water class other than land, which would
-- explain a low share. No deep band (below -1500) is reached.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r46_or_probe] "
local X0 = tonumber(core.settings:get("r46_or_probe_x")) or 368
local Z0 = tonumber(core.settings:get("r46_or_probe_z")) or -2352
local Y_TOP, Y_BOTTOM = 127, -1312
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

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r46 or probe done", false, 0)
end

-- The live mapgen rows, read from the shipped constructor values.
local rows = dofile(core.get_modpath("grug_mapgen") ..
	"/wp40/r7_r6_manifest.lua")().resources
local denominator_of = {}
for _, row in ipairs(rows) do denominator_of[row.key] = row.denominators end

local function ground_report()
	local flagged, kinds, water = 0, {}, {}
	for x = X0, X0 + 79 do
		for z = Z0, Z0 + 79 do
			local kind = grug_zones.hard_protection_kind_at({x = x, y = -20, z = z})
			if kind then
				flagged = flagged + 1
				kinds[kind] = (kinds[kind] or 0) + 1
			end
			local class = grug_zones.water_class_at(x, z)
			water[class] = (water[class] or 0) + 1
		end
	end
	local parts = {}
	for class, n in pairs(water) do parts[#parts + 1] = class .. "=" .. n end
	table.sort(parts)
	local kind_parts = {}
	for kind, n in pairs(kinds) do kind_parts[#kind_parts + 1] = kind .. "=" .. n end
	table.sort(kind_parts)
	log(("zone %s; columns hard-protected at y -20: %d [%s]; water classes [%s]"):format(
		tostring(grug_zones.id_at(X0 + 40, Z0 + 40)), flagged,
		table.concat(kind_parts, " "), table.concat(parts, " ")))
end

local function survey()
	local tiers = grug_materials.TIERS
	local resources = grug_materials.RESOURCES
	log(("column x %d..%d z %d..%d y %d..%d"):format(X0, X0 + 79, Z0, Z0 + 79,
		Y_BOTTOM, Y_TOP))
	ground_report()
	for band = 1, #tiers do
		local tier = tiers[band]
		local y_max = math.min(Y_TOP, tier.y_max)
		local y_min = math.max(Y_BOTTOM, tier.y_min)
		local names = {tier.node}
		for i = 1, #resources do names[#names + 1] = resources[i].natural_node end
		local _, counts = core.find_nodes_in_area({x = X0, y = y_min, z = Z0},
			{x = X0 + 79, y = y_max, z = Z0 + 79}, names)
		local host, total, expected_share = 0, 0, 0
		for _, name in ipairs(names) do host = host + (counts[name] or 0) end
		local parts = {}
		for _, resource in ipairs(resources) do
			local count = counts[resource.natural_node] or 0
			local denominator = denominator_of[resource.key][band]
			total = total + count
			if denominator then
				expected_share = expected_share + 1 / denominator
				parts[#parts + 1] = ("%s=%d (1/%s vs %d)"):format(resource.key, count,
					count > 0 and ("%.0f"):format(host / count) or "-", denominator)
			else
				check(count == 0, resource.key .. " has no row in band " .. band ..
					" but " .. count .. " nodes")
				if count > 0 then parts[#parts + 1] = resource.key .. "=" .. count .. " (none planned)" end
			end
		end
		local share = host > 0 and total / host or 0
		log(("T%d | y %d..%d | host %d | resources %d | share %.2f %% (table %.2f %%, ratio %.3f)"):format(
			band, y_min, y_max, host, total, 100 * share, 100 * expected_share,
			expected_share > 0 and share / expected_share or 0))
		log(("T%d | %s"):format(band, table.concat(parts, "; ")))
		check(host > 100000, "band " .. band .. " has host rock")
		check(math.abs(share / expected_share - 1) <= 0.10,
			"band " .. band .. " share within 10 % of the table")
	end
	finish()
end

core.after(2, function()
	local t0 = core.get_us_time()
	core.emerge_area({x = X0, y = Y_BOTTOM, z = Z0},
		{x = X0 + 79, y = Y_TOP, z = Z0 + 79}, function(_, _, remaining)
		if remaining == 0 then
			log(("emerged in %.1f s"):format((core.get_us_time() - t0) / 1e6))
			survey()
		end
	end)
end)
