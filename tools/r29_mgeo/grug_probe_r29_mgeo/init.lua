-- Round 29 Lane M-geo engine probe (disposable, never shipped): the band
-- data, the wider Battlegrounds and the middle road on a real world, over
-- x -200..200, z -700..700 at the surface.
--
-- 1. BANDS: grug_zones serves Gravesalt Escarpment and The Skyglass Canopy
--    51-60, the Causeway and the Shattered Line 41-50.
-- 2. BORDER: along x = 0 (every 4 nodes, z -700..700) the zones run
--    Ashenward March -> Battlegrounds -> Bannerbreak Mesa; the two border z
--    and the analytic level on both sides are logged; each border lies at
--    250 <= |z| <= 500 and every land column's level lies in its zone's band.
-- 3. ROAD: the middle road (Highcourt -> Gor Drazhak) is in the layout the
--    world was generated with; at every 64th point with |z| <= 700 the
--    column is emerged and the generated node at the corridor surface is a
--    road surface (90 % of the points; a ford may differ).
-- 4. CAMPS and CLASH SITES: Coalbrand Yard and Sunderstrap Camp at |x| =
--    96, the four moved clash sites, each in its zone and protected as
--    their kind; the camps are emerged and their core node logged.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r29_mgeo_probe] "
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
local SURFACES = {}
for _, name in ipairs({"default:cobble", "default:stone_block",
		"default:silver_sandstone_block", "default:stonebrick", "default:desert_cobble",
		"default:mossycobble", "default:wood", "default:pine_wood", "default:aspen_wood",
		"default:acacia_wood", "default:junglewood"}) do
	SURFACES[name] = true
end

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r29 mgeo probe done", false, 0)
end

-- Emerges the boxes one after the other, calling fn(index) after each.
local function emerge_all(boxes, fn, done)
	local index = 0
	local started = core.get_us_time()
	local function step()
		index = index + 1
		if index > #boxes then
			log(("EMERGED %d boxes in %.1f s"):format(#boxes, (core.get_us_time() - started) / 1000000))
			return done()
		end
		local box = boxes[index]
		core.emerge_area(box[1], box[2], function(_, _, remaining)
			if remaining > 0 then return end
			local ok, err = pcall(fn, index)
			check(ok, "scenario ran (" .. tostring(err) .. ")")
			step()
		end)
	end
	step()
end

local function bands()
	local want = {front_gravesalt_escarpment = {51, 60}, front_skyglass_canopy = {51, 60},
		front_broken_causeway = {41, 50}, front_shattered_line = {41, 50}}
	for id, band in pairs(want) do
		local record = grug_zones.get(id)
		log(("BAND %s %d-%d"):format(id, record.level_min, record.level_max))
		check(record.level_min == band[1] and record.level_max == band[2], "band " .. id)
	end
end

local function border()
	local previous, crossings = nil, {}
	local out_of_band = 0
	for z = -700, 700, 4 do
		if grug_zones.water_class_at(0, z) == "land" then
			local id = grug_zones.id_at(0, z)
			local record = grug_zones.get(id)
			local level = grug_zones.surface_mob_level_at(0, z)
			if level < record.level_min or level > record.level_max then out_of_band = out_of_band + 1 end
			if previous and previous.id ~= id then
				crossings[#crossings + 1] = {z = z, from = previous.id, to = id,
					levels = previous.level .. " -> " .. level}
			end
			previous = {id = id, level = level}
		end
	end
	for _, c in ipairs(crossings) do
		log(("BORDER x=0 z=%d: %s -> %s (L%s)"):format(c.z, c.from, c.to, c.levels))
	end
	local south, north
	for _, c in ipairs(crossings) do
		if c.from == "elandor_ashenward_march" then south = c.z end
		if c.to == "kragmar_bannerbreak_mesa" then north = c.z end
	end
	check(south and south <= -250 and south >= -500, "Ashenward border at 250 <= -z <= 500")
	check(north and north >= 250 and north <= 500, "Bannerbreak border at 250 <= z <= 500")
	check(out_of_band == 0, "every land level in its zone's band (" .. out_of_band .. " off)")
end

local function road(done)
	local layout = roads.deserialize(grug_mapgen.wp40.road_layout_text)
	local hc = grug_zones.anchor("elandor_highcourt", "capital")
	local gd = grug_zones.anchor("kragmar_gor_drazhak", "capital")
	local r
	for _, o in pairs(layout.roads) do
		if o.a == hc.id and o.b == gd.id then r = o end
	end
	if not check(r ~= nil, "the middle road is in the generated layout") then return done() end
	log(("ROAD %d (%s), %d points"):format(r.id, r.kind, #r.X))
	local points = {}
	for i = 1, #r.X, 64 do
		if math.abs(r.Z[i]) <= 700 then points[#points + 1] = i end
	end
	local boxes = {}
	for k, i in ipairs(points) do
		local x, z = math.floor(r.X[i] + 0.5), math.floor(r.Z[i] + 0.5)
		local s = wp.surface_node(r.R[i], r.R[i], 0)
		boxes[k] = {{x = x - 2, y = s - 4, z = z - 2}, {x = x + 2, y = s + 4, z = z + 2}}
	end
	local hits, max_x = 0, 0
	emerge_all(boxes, function(k)
		local i = points[k]
		local x, z = math.floor(r.X[i] + 0.5), math.floor(r.Z[i] + 0.5)
		local s = wp.surface_node(r.R[i], r.R[i], 0)
		local node = core.get_node({x = x, y = s, z = z}).name
		if SURFACES[node] then hits = hits + 1 end
		max_x = math.max(max_x, math.abs(x))
		log(("ROAD point %d at %d,%d,%d class %s zone %s: %s"):format(i, x, s, z,
			tostring(r.cls[i]), tostring(grug_zones.id_at(x, z)), node))
	end, function()
		log(("ROAD %d of %d points on a road surface, max |x| %d"):format(hits, #points, max_x))
		check(#points >= 15, "the middle road spans z -700..700")
		check(hits >= 0.9 * #points, "the generated road lies at the corridor surface")
		check(max_x < 300, "the middle road stays near x = 0")
		done()
	end)
end

local function sites(done)
	local rows = {
		{"elandor_ashenward_march", "bandit_1", "camp", 96},
		{"kragmar_bannerbreak_mesa", "bandit_1", "camp", 96},
		{"elandor_ashenward_march", "clash_1", "poi"}, {"elandor_ashenward_march", "clash_2", "poi"},
		{"kragmar_bannerbreak_mesa", "clash_1", "poi"}, {"kragmar_bannerbreak_mesa", "clash_2", "poi"},
	}
	local boxes = {}
	for k, row in ipairs(rows) do
		local a = grug_zones.anchor(row[1], row[2])
		row.anchor = a
		boxes[k] = {{x = a.x - 8, y = a.y - 4, z = a.z - 8}, {x = a.x + 8, y = a.y + 8, z = a.z + 8}}
	end
	emerge_all(boxes, function(k)
		local row = rows[k]
		local a = row.anchor
		local above = {x = a.x, y = a.y + 1, z = a.z}
		local kind = grug_core.world_feature_at(above)
		log(("SITE %s %s at %s: zone %s, kind %s, node %s / above %s"):format(row[1], row[2],
			core.pos_to_string(a), tostring(grug_zones.id_at(a.x, a.z)), tostring(kind),
			core.get_node(a).name, core.get_node(above).name))
		check(grug_zones.id_at(a.x, a.z) == row[1], row[1] .. " " .. row[2] .. " in its zone")
		check(kind == row[3], row[1] .. " " .. row[2] .. " protected as " .. row[3])
		if row[4] then check(math.abs(a.x) == row[4], row[1] .. " camp at |x| = " .. row[4]) end
	end, done)
end

core.after(2, function()
	local ok, err = pcall(function()
		bands()
		border()
	end)
	check(ok, "zone checks ran (" .. tostring(err) .. ")")
	road(function()
		sites(finish)
	end)
end)
