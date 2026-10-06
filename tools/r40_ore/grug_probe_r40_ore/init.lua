-- Round 40 fix lane ORE engine probe (disposable, never shipped): ore, coal,
-- gems and gatherables wherever digging is allowed (user ruling 2026-10-07).
--
-- 1. The human start town: no P8 resource inside its pad above the
--    protected floor (anchor y - 100); P8 resources in the graded ring just
--    beyond the town (x +80..+127 of the anchor) from y = -37 to the
--    surface, where the former host rule kept none; the same box 400 nodes
--    further east for comparison.
-- 2. The nearest human village: P8 resources and gatherable sources in its
--    blend envelope beyond its building core (x +30..+75), where the former
--    envelope rule kept both out.
-- Counts are reported; the checks are only "none inside the town" and
-- "some in the ring / the envelope". Ends the server; "RESULT PASS" is the
-- verdict line.

local PREFIX = "[r40_ore_probe] "
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
	core.request_shutdown("r40 ore probe done", false, 0)
end

local resource_names = {}
for _, resource in ipairs(grug_materials.RESOURCES) do
	resource_names[#resource_names + 1] = resource.natural_node
end
local gather_names = {}
for name in pairs(core.registered_nodes) do
	if name:match("^grug_gathering:.*_source$") or name:match("^grug_mapgen:.*_source$") then
		gather_names[#gather_names + 1] = name
	end
end
table.sort(gather_names)

local function count(minp, maxp, names)
	local _, counts = core.find_nodes_in_area(minp, maxp, names)
	local total, parts = 0, {}
	for _, name in ipairs(names) do
		local n = counts[name] or 0
		total = total + n
		if n > 0 then parts[#parts + 1] = name:gsub("^.*:", "") .. "=" .. n end
	end
	return total, table.concat(parts, " ")
end

local function stone(minp, maxp)
	local _, counts = core.find_nodes_in_area(minp, maxp, {"default:stone"})
	return counts["default:stone"] or 0
end

local function box_report(label, minp, maxp)
	local ores, parts = count(minp, maxp, resource_names)
	local s = stone(minp, maxp)
	log(("%s %s..%s: resources %d, stone %d (%.4f per stone) [%s]"):format(label,
		core.pos_to_string(minp), core.pos_to_string(maxp), ores, s,
		s > 0 and ores / s or 0, parts))
	local plants, plant_parts = count(minp, maxp, gather_names)
	log(("%s gatherables %d [%s]"):format(label, plants, plant_parts))
	return ores, plants
end

local function emerge(minp, maxp, done)
	local started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		log(("EMERGED %s..%s in %.1f s"):format(core.pos_to_string(minp),
			core.pos_to_string(maxp), (core.get_us_time() - started) / 1000000))
		done()
	end)
end

local function human_start()
	for _, start in ipairs(grug_core.start_identities()) do
		if start.race_id == "human" then return start end
	end
end

local function nearest_village(anchor)
	local best, best_d
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		if row.race_id == "human" and type(row.slot) == "string" and
				row.slot:find("village", 1, true) then
			local dx, dz = row.anchor.x - anchor.x, row.anchor.z - anchor.z
			local d = dx * dx + dz * dz
			if not best_d or d < best_d then best, best_d = row, d end
		end
	end
	return best
end

local function village_part(start)
	local village = nearest_village(start.anchor)
	if not check(village ~= nil, "a human village exists") then return finish() end
	local a = village.anchor
	log(("VILLAGE %s (%s) anchor %s"):format(village.key, village.slot,
		core.pos_to_string(a)))
	-- the envelope east of the core (x +30..+75, z -75..+75), and the same
	-- box 250 nodes further east for comparison
	local minp = {x = a.x + 30, y = -37, z = a.z - 75}
	local maxp = {x = a.x + 75, y = a.y + 40, z = a.z + 75}
	local rmin = {x = minp.x + 250, y = minp.y, z = minp.z}
	local rmax = {x = maxp.x + 250, y = maxp.y, z = maxp.z}
	emerge(minp, maxp, function()
		local ores = box_report("VILLAGE envelope ring", minp, maxp)
		check(ores > 0, "resources in the village envelope beyond the core")
		emerge(rmin, rmax, function()
			box_report("VILLAGE reference box", rmin, rmax)
			finish()
		end)
	end)
end

core.after(2, function()
	local start = human_start()
	if not check(start ~= nil, "human start identity") then return finish() end
	local a = start.anchor
	local floor = a.y - 100
	log(("HUMAN start anchor %s, protected floor y=%d"):format(core.pos_to_string(a), floor))
	-- the town's pad (-64..+63) above its floor, the graded ring east of the
	-- band, and the reference box 400 nodes further east
	local pad_min = {x = a.x - 48, y = floor, z = a.z - 48}
	local pad_max = {x = a.x + 47, y = a.y - 1, z = a.z + 47}
	local ring_min = {x = a.x + 80, y = -37, z = a.z - 48}
	local ring_max = {x = a.x + 127, y = a.y + 40, z = a.z + 47}
	local ref_min = {x = ring_min.x + 400, y = -37, z = ring_min.z}
	local ref_max = {x = ring_max.x + 400, y = ring_max.y, z = ring_max.z}
	emerge(pad_min, ring_max, function()
		local inside = box_report("TOWN pad above the floor", pad_min, pad_max)
		check(inside == 0, "no resource inside the town above its floor")
		local ring = box_report("START graded ring", ring_min, ring_max)
		check(ring > 0, "resources in the graded ring beyond the town")
		emerge(ref_min, ref_max, function()
			box_report("REFERENCE box", ref_min, ref_max)
			village_part(start)
		end)
	end)
end)
