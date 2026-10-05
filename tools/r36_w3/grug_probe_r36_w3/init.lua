-- Round 36 Lane W3 engine probe (disposable, never shipped): ground cover in
-- the bare band round two start towns of different biomes (Dawnmere Fields,
-- meadows; Sunscar Flats, savanna) and in four diagonal stretches of
-- Highcourt's band, on a fresh world.
--
-- Per place it emerges only the surroundings, reads them through a
-- VoxelManip and counts, by distance class, the ground-cover plants (by
-- species), the woody plants (trunks, stems, saplings, bush leaves) and the
-- support node under every plant:
--   start: pad (d = 0), band (0 < d <= 12, in bins 1-4 / 5-8 / 9-12),
--          ring (12 < d <= 36), d the true distance from the 128-node pad;
--   capital: edge (0 < d <= 9 beyond the wall line), band (9 < d <= 21),
--          ring (21 < d <= 45), d the distance from the planned wall line.
-- The pad's nodes are also summed into one digest (the town composition).
-- Checks (both before and after the change): no woody plant in a start's
-- band or in a capital's edge or band (the town's own trees stand on its
-- pad), and no plant in a band on a
-- support that hosts no natural plant (roads, paths, the town's paving).
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r36_w3_probe] "
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

local wp40 = grug_mapgen.wp40
local density = wp40.vegetation
local planner = wp40.planner_source
local modpath = core.get_modpath("grug_mapgen") .. "/wp40"
local capital_planner = dofile(modpath .. "/capital_planner.lua")
local capital_protection = dofile(modpath .. "/capital_protection.lua")

local function set_of(list)
	local result = {}
	for _, name in ipairs(list) do result[name] = true end
	return result
end
local COVER = set_of(density.cover_names())
COVER["grug_nodes:bone_pile"] = true
local WOODY = set_of(density.markers("tree"))
for _, name in ipairs(density.markers("shrub")) do WOODY[name] = true end
local HOST = set_of(density.support_names())

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r36 w3 probe done", false, 0)
end

local function terrain_y(x, z)
	return select(6, planner.column_values_at(x, z))
end

local name_of = {}
local function node_name(id)
	local name = name_of[id]
	if not name then
		name = core.get_name_from_content_id(id)
		name_of[id] = name
	end
	return name
end
local name_hash = {}
local function hash_name(name)
	local h = name_hash[name]
	if not h then
		h = 0
		for i = 1, #name do h = (h * 31 + name:byte(i)) % 1000003 end
		name_hash[name] = h
	end
	return h
end

local function bump(t, key, n)
	t[key] = (t[key] or 0) + (n or 1)
end

-- One place: `classify(x, z)` -> class name or nil; `classes` the class
-- order to report; `bin(x, z)` an optional sub-class for the band.
local function survey(place, minp, maxp, classify, classes, bin, done)
	local started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		local seconds = (core.get_us_time() - started) / 1000000
		local ok, err = pcall(function()
			local vm = core.get_voxel_manip()
			local emin, emax = vm:read_from_map(minp, maxp)
			local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
			local data = vm:get_data()
			local stats = {}
			for _, class in ipairs(classes) do
				stats[class] = {columns = 0, cover = 0, woody = 0, species = {},
					supports = {}, woody_species = {}, nonhost = 0}
			end
			local bins = {}
			local pad_digest, pad_names = 0, {}
			for z = minp.z, maxp.z do
				for x = minp.x, maxp.x do
					local class = classify(x, z)
					local s = class and stats[class]
					if s then
						s.columns = s.columns + 1
						local b = bin and bin(x, z)
						if b then
							bins[b] = bins[b] or {columns = 0, cover = 0}
							bins[b].columns = bins[b].columns + 1
						end
						local ty = terrain_y(x, z)
						local y0 = math.max(minp.y, ty - 4)
						local y1 = math.min(maxp.y, ty + 8)
						for y = y0, y1 do
							local name = node_name(data[area:index(x, y, z)])
							if COVER[name] then
								s.cover = s.cover + 1
								bump(s.species, name)
								local below = node_name(data[area:index(x, y - 1, z)])
								bump(s.supports, below)
								if not HOST[below] then s.nonhost = s.nonhost + 1 end
								if b then bins[b].cover = bins[b].cover + 1 end
							elseif WOODY[name] then
								s.woody = s.woody + 1
								bump(s.woody_species, name)
							end
						end
						if class == "pad" then
							for y = math.max(minp.y, ty - 4), math.min(maxp.y, ty + 26) do
								local name = node_name(data[area:index(x, y, z)])
								pad_digest = (pad_digest * 33 + hash_name(name)) % 4294967291
								bump(pad_names, name)
							end
						end
					end
				end
			end
			log(("PLACE %s emerged %s..%s in %.1f s"):format(place,
				core.pos_to_string(minp), core.pos_to_string(maxp), seconds))
			for _, class in ipairs(classes) do
				local s = stats[class]
				log(("CLASS %s %s columns=%d cover=%d per100=%.2f woody=%d nonhost=%d")
					:format(place, class, s.columns, s.cover,
						s.columns > 0 and 100 * s.cover / s.columns or 0, s.woody, s.nonhost))
				local names = {}
				for name in pairs(s.species) do names[#names + 1] = name end
				table.sort(names)
				for _, name in ipairs(names) do
					log(("SPECIES %s %s %s %d"):format(place, class, name, s.species[name]))
				end
				names = {}
				for name in pairs(s.supports) do names[#names + 1] = name end
				table.sort(names)
				for _, name in ipairs(names) do
					log(("SUPPORT %s %s %s %d"):format(place, class, name, s.supports[name]))
				end
				names = {}
				for name in pairs(s.woody_species) do names[#names + 1] = name end
				table.sort(names)
				for _, name in ipairs(names) do
					log(("WOODY %s %s %s %d"):format(place, class, name, s.woody_species[name]))
				end
			end
			local keys = {}
			for key in pairs(bins) do keys[#keys + 1] = key end
			table.sort(keys)
			for _, key in ipairs(keys) do
				local b = bins[key]
				log(("BIN %s %s columns=%d cover=%d per100=%.2f"):format(place, key,
					b.columns, b.cover, b.columns > 0 and 100 * b.cover / b.columns or 0))
			end
			if stats.pad then
				log(("PAD %s digest=%d"):format(place, pad_digest))
				local names = {}
				for name in pairs(pad_names) do names[#names + 1] = name end
				table.sort(names)
				for _, name in ipairs(names) do
					log(("PADNODE %s %s %d"):format(place, name, pad_names[name]))
				end
			end
			for _, class in ipairs({"band", "edge"}) do
				if stats[class] then
					check(stats[class].woody == 0, place .. " " .. class .. ": no woody plant")
				end
			end
			if stats.band then
				check(stats.band.nonhost == 0, place .. " band: every plant on a natural host")
			end
		end)
		check(ok, place .. " survey ran (" .. tostring(err) .. ")")
		done()
	end)
end

local STARTS = {
	{name = "dawnmere", x = 0, z = -2550},
	{name = "sunscar", x = 0, z = 2550},
}
local PAD_HALF, BAND, START_RING = 64, 12, 36

local function survey_start(row, done)
	local cx, cz = row.x, row.z
	local function distance2(x, z)
		local ex = math.max(cx - PAD_HALF - x, x - (cx + PAD_HALF - 1), 0)
		local ez = math.max(cz - PAD_HALF - z, z - (cz + PAD_HALF - 1), 0)
		return ex * ex + ez * ez
	end
	local function classify(x, z)
		local d2 = distance2(x, z)
		if d2 == 0 then return "pad" end
		if d2 <= BAND * BAND then return "band" end
		if d2 <= START_RING * START_RING then return "ring" end
		return nil
	end
	local function bin(x, z)
		local d2 = distance2(x, z)
		if d2 == 0 or d2 > BAND * BAND then return nil end
		local d = math.sqrt(d2)
		return d <= 4 and "d01-04" or (d <= 8 and "d05-08" or "d09-12")
	end
	local ty = terrain_y(cx, cz)
	local reach = PAD_HALF + START_RING
	survey(row.name, {x = cx - reach, y = ty - 24, z = cz - reach},
		{x = cx + reach - 1, y = ty + 40, z = cz + reach - 1}, classify,
		{"pad", "band", "ring"}, bin, done)
end

-- Highcourt: the distance of a column outside the wall line to the planned
-- wall polyline (the city's own lake is not part of Highcourt).
local function survey_capital(done)
	local texts = capital_planner.split(wp40.capital_layout_text)
	local id = "anchor_008"
	local layout = capital_planner.deserialize(texts[id])
	local shape = capital_protection.build(layout)
	local ax, az = layout.anchor.x, layout.anchor.z
	local pts = layout.wall.pts
	local E, B, RING = capital_protection.EDGE_REACH, capital_protection.BAND, 45
	local function distance(x, z)
		local lx, lz = x - ax, z - az
		local best = math.huge
		for i = 1, #pts do
			local a, b = pts[i], pts[i % #pts + 1]
			local vx, vz = b[1] - a[1], b[2] - a[2]
			local wx, wz = lx - a[1], lz - a[2]
			local t = (wx * vx + wz * vz) / (vx * vx + vz * vz)
			if t < 0 then t = 0 elseif t > 1 then t = 1 end
			local dx, dz = wx - t * vx, wz - t * vz
			local d = dx * dx + dz * dz
			if d < best then best = d end
		end
		return math.sqrt(best)
	end
	local function classify(x, z)
		if shape.inside(x, z) then return nil end
		local d = distance(x, z)
		if d <= E then return "edge" end
		if d <= E + B then return "band" end
		if d <= RING then return "ring" end
		return nil
	end
	local function bin(x, z)
		if shape.inside(x, z) then return nil end
		local d = distance(x, z)
		if d <= E or d > E + B then return nil end
		return d <= E + 4 and "d09-13" or (d <= E + 8 and "d13-17" or "d17-21")
	end
	local boxes = {}
	for _, dir in ipairs({{1, 1}, {-1, 1}, {1, -1}, {-1, -1}}) do
		local step = 0
		while shape.inside(ax + dir[1] * step, az + dir[2] * step) do step = step + 1 end
		local x = ax + dir[1] * (step + 15)
		local z = az + dir[2] * (step + 15)
		boxes[#boxes + 1] = {x = x, z = z, tag = (dir[1] > 0 and "e" or "w") ..
			(dir[2] > 0 and "n" or "s")}
	end
	local index = 0
	local function nxt()
		index = index + 1
		local box = boxes[index]
		if not box then return done() end
		local ty = terrain_y(box.x, box.z)
		survey("highcourt_" .. box.tag, {x = box.x - 40, y = ty - 24, z = box.z - 40},
			{x = box.x + 39, y = ty + 40, z = box.z + 39}, classify,
			{"edge", "band", "ring"}, bin, nxt)
	end
	nxt()
end

local clock = 0
local function wait_ready(then_do)
	local status = grug_core.world_preparation_status()
	if status.ready then
		log(("world preparation ready at t=%.1fs"):format(clock))
		return then_do()
	end
	if clock > 280 then
		check(false, "world preparation ready within 280 s")
		return finish()
	end
	clock = clock + 1
	core.after(1, function() wait_ready(then_do) end)
end

core.after(1, function()
	wait_ready(function()
		local started = core.get_us_time()
		survey_start(STARTS[1], function()
			survey_start(STARTS[2], function()
				survey_capital(function()
					log(("SURVEYS done in %.1f s"):format((core.get_us_time() - started) / 1000000))
					finish()
				end)
			end)
		end)
	end)
end)
