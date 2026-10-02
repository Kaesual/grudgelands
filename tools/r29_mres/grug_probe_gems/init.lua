-- Round 29 lane M-res engine probe (disposable, never shipped): gem depth
-- tiers (economy plan §6.1) in the real mapgen.
--
-- Emerges one 64 x 64 column (X0..X0+63, Z0..Z0+63) from y +50 down to
-- y -1300 in open ground and counts, per tier band, the band's tier rock,
-- every ore and every gem. Each gem must occur only in the band of its own
-- tier, at roughly one per 512 host nodes there (host = the band's tier rock
-- plus every resource node in it, i.e. the rock before P8 placed its veins).
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r29_gem_probe] "
local X0 = tonumber(core.settings:get("r29_gem_probe_x")) or 400
local Z0 = tonumber(core.settings:get("r29_gem_probe_z")) or -2300
local Y_TOP, Y_BOTTOM = 50, -1300
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
	core.request_shutdown("r29 gem probe done", false, 0)
end

local function survey()
	local tiers = grug_materials.TIERS
	local resource_nodes = {}
	for _, resource in ipairs(grug_materials.RESOURCES) do
		resource_nodes[#resource_nodes + 1] = resource.natural_node
	end
	log(("column x %d..%d z %d..%d y %d..%d"):format(X0, X0 + 63, Z0, Z0 + 63,
		Y_BOTTOM, Y_TOP))
	log("band | y range | host | " ..
		"citrine jade garnet sapphire ruby diamond | own gem: host/gem")
	for band = 1, #tiers do
		local tier = tiers[band]
		local y_max = math.min(Y_TOP, tier.y_max)
		local y_min = math.max(Y_BOTTOM, tier.y_min)
		local minp = {x = X0, y = y_min, z = Z0}
		local maxp = {x = X0 + 63, y = y_max, z = Z0 + 63}
		local names = {tier.node}
		for i = 1, #resource_nodes do names[#names + 1] = resource_nodes[i] end
		local _, counts = core.find_nodes_in_area(minp, maxp, names)
		local host = 0
		for _, name in ipairs(names) do host = host + (counts[name] or 0) end
		local parts, own = {}, 0
		for _, resource in ipairs(grug_materials.RESOURCES) do
			if resource.gem then
				local count = counts[resource.natural_node] or 0
				parts[#parts + 1] = tostring(count)
				if resource.harvest_tier == band then
					own = count
				else
					check(count == 0, resource.key .. " outside its band in band " .. band)
				end
			end
		end
		local ratio = own > 0 and ("%.0f"):format(host / own) or "-"
		log(("T%d | %d..%d | %d | %s | %s"):format(band, y_min, y_max, host,
			table.concat(parts, " "), ratio))
		check(host > 0, "band " .. band .. " has host rock")
		if host >= 512 * 20 then
			-- Rough target only: within a factor of two of 1 per 512.
			check(own > 0 and host / own > 256 and host / own < 1024,
				"band " .. band .. " gem rate near 1 per 512")
		end
	end
	finish()
end

core.after(2, function()
	local t0 = core.get_us_time()
	core.emerge_area({x = X0, y = Y_BOTTOM, z = Z0},
		{x = X0 + 63, y = Y_TOP, z = Z0 + 63}, function(_, _, remaining)
		if remaining == 0 then
			log(("emerged in %.1f s"):format((core.get_us_time() - t0) / 1e6))
			survey()
		end
	end)
end)
