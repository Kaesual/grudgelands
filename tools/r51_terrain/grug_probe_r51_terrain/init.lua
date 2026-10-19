-- Round 51 TERRAIN T1 engine probe (disposable, never shipped; staged by
-- `PROBE=` of tools/luanti_headless.sh). After the world preparation it reads
-- columns of the new ring (between the old bounds +-3740 x +-3340 and the new
-- +-4190 x +-3740), just inside and just outside the new bounds, through the
-- game's own seams (grug_zones, grug_core, core.is_protected), generates the
-- chunk holding each column's sea floor and checks what the engine wrote
-- there (water at y 1, ground at the planned floor); then (Round 51 T2) reads
-- the water query and the protection at 23 and 25 nodes off a coast; then
-- shuts down. Boot it with SEED=12345 (the windows are that seed's).
-- Logs "[r51_terrain_probe] RESULT PASS|FAIL ...".
local PREFIX = "[r51_terrain_probe] "
local function log(message) core.log("action", PREFIX .. message) end
local failures = {}
local function expect(ok, label)
	if not ok then failures[#failures + 1] = label end
end

local COLUMNS = {
	{4100, 0, true}, {-4100, 0, true}, {0, 3700, true}, {0, -3700, true},
	{4190, 3740, true}, {-4190, -3740, true}, {4191, 0, false}, {0, -3741, false},
}

local function read_column(c)
	local x, z, inside = c[1], c[2], c[3]
	local h = grug_zones.terrain_height_at(x, z)
	local surface = {x = x, y = 2, z = z}
	local deep = {x = x, y = -600, z = z}
	local class = grug_zones.water_class_at(x, z)
	local zone = grug_zones.id_at(x, z)
	local rule = grug_zones.territory_rule_at(surface)
	local level, deep_level = grug_core.mob_level_at(surface), grug_core.mob_level_at(deep)
	local alterable = grug_core.world_alterable({x = x, y = h, z = z})
	local protected = core.is_protected({x = x, y = h, z = z}, "r51probe")
	log(("column %d %d: class %s zone %s floor %d territory %s open_sea %s mob_level %s/%s " ..
		"surface_level %s alterable %s protected %s"):format(x, z, class, tostring(zone), h,
		tostring(rule), tostring(grug_core.open_sea_at(surface)), tostring(level),
		tostring(deep_level), tostring(grug_core.surface_mob_level_at(x, z)),
		tostring(alterable), tostring(protected)))
	local label = ("%d,%d"):format(x, z)
	expect(class == "deep_ocean", label .. " deep ocean")
	expect(zone == nil, label .. " no zone")
	expect(rule == "immutable", label .. " immutable")
	expect(grug_core.open_sea_at(surface) == true, label .. " open sea")
	expect(level == nil and deep_level == nil, label .. " no mob level")
	expect(grug_core.surface_mob_level_at(x, z) == nil, label .. " no surface level")
	expect(alterable == false, label .. " not alterable")
	expect(protected == true, label .. " protected")
	if inside then
		expect(h < -2 and h >= -40, label .. " the field's sea floor")
	else
		expect(h == -23, label .. " the flat floor outside")
	end
	return h
end

local function finish()
	log(("RESULT %s %s"):format(#failures == 0 and "PASS" or "FAIL",
		#failures == 0 and (#COLUMNS .. " columns") or table.concat(failures, "; ")))
	core.request_shutdown("r51 terrain probe done", false, 0)
end

-- Round 51 T2: the water query at one column of each class, and the
-- protection 23 and 25 nodes off a coast for bay, belt and channel water
-- (what core.is_protected asks for a player of either faction, and the
-- system rule water and plants follow), at the surface and the seabed.
-- The classes are found every 16 nodes over the world, the 23/25 columns
-- every 3 nodes in a few windows (seed 12345: a bay, the Wyrmglass channel
-- and its island's belt).
local WINDOWS = {{-1500, -3000, -400, -2000}, {-3400, -800, -2300, 800},
	{-400, -2700, 900, -1800}}
local function t2_checks()
	local Q = grug_zones.water_query_at
	if type(Q) ~= "function" then
		failures[#failures + 1] = "no water query"
		return
	end
	local classes, probes = {}, {}
	for z = -3740, 3740, 16 do
		for x = -4190, 4190, 16 do
			local class, zone, level, distance, depth, protected = Q(x, z)
			if class and not classes[class] then
				classes[class] = true
				log(("query %d %d: %s zone %s level %s distance %s depth %d protected %s")
					:format(x, z, class, tostring(zone), tostring(level), tostring(distance),
					depth, tostring(protected)))
			end
		end
	end
	for _, w in ipairs(WINDOWS) do
		for z = w[2], w[4], 3 do
			for x = w[1], w[3], 3 do
				local class, _, _, distance, _, protected = Q(x, z)
				if class == "bay" or class == "belt" or class == "channel" then
					local band = math.floor(distance)
					local key = class .. band
					if (band == 23 or band == 25) and not probes[key] then
						probes[key] = {class, band, x, z, protected}
					end
				end
			end
		end
	end
	for _, class in ipairs({"lake", "river", "bay", "belt", "channel", "open_sea"}) do
		expect(classes[class], "a " .. class .. " column")
	end
	for _, class in ipairs({"bay", "belt", "channel"}) do
		for _, band in ipairs({23, 25}) do
			local probe = probes[class .. band]
			expect(probe ~= nil, ("a %s column %d off the coast"):format(class, band))
			if probe then
				local x, z = probe[3], probe[4]
				local floor_y = grug_zones.terrain_height_at(x, z)
				for _, y in ipairs({1, floor_y}) do
					local pos = {x = x, y = y, z = z}
					local accord = grug_core.world_protected_for_faction(pos, "accord")
					local throng = grug_core.world_protected_for_faction(pos, "throng")
					local system = grug_core.natural_ground_alterable(pos)
					log(("protect %s %d off at %d %d y %d: territory %s, accord %s, throng %s, " ..
						"system alterable %s"):format(class, band, x, z, y,
						tostring(grug_zones.territory_rule_at(pos)), tostring(accord),
						tostring(throng), tostring(system)))
					local label = ("%s %d off y %d"):format(class, band, y)
					if band >= 24 then
						expect(accord and throng and not system, label .. " protected")
					else
						expect(not (accord and throng) and system, label .. " open")
					end
				end
				expect(probe[5] == (band >= 24), class .. " " .. band .. " query flag")
			end
		end
	end
end

-- Round 51 T3: a seagrass and a kelp column of the runtime's seabed rule
-- (the vegetation authority) near the Wyrmglass channel, generated, read back.
local function t3_checks(done)
	local vegetation = grug_mapgen.wp40.vegetation
	if type(vegetation.seabed) ~= "function" then
		failures[#failures + 1] = "no seabed rule"
		return done()
	end
	-- up to six candidates of each kind (a bed of gravel or stone, which the
	-- writer keeps bare of seagrass and kelp, may refuse one)
	local wanted, list, matched = {seagrass = 6, kelp = 6}, {}, {}
	for z = -400, 400, 7 do
		for x = -2800, -2300, 7 do
			local node, param2, ground = vegetation.seabed(x, z)
			local kind = node and (node:find("seagrass") and "seagrass" or "kelp")
			if kind and wanted[kind] > 0 then
				wanted[kind] = wanted[kind] - 1
				list[#list + 1] = {x, ground, z, node, param2, kind}
			end
		end
	end
	local index = 0
	local function step()
		index = index + 1
		local c = list[index]
		if not c then
			expect(matched.seagrass and matched.kelp, "seagrass and kelp where the rule says")
			return done()
		end
		local pos = {x = c[1], y = c[2], z = c[3]}
		core.emerge_area(pos, pos, function(_, _, remaining)
			if remaining ~= 0 then return end
			local node = core.get_node(pos)
			log(("seabed %d %d %d: %s param2 %d (rule %s %d)"):format(pos.x, pos.y, pos.z,
				node.name, node.param2, c[4], c[5]))
			if node.name == c[4] and node.param2 == c[5] then matched[c[6]] = true end
			core.after(0.5, step)
		end)
	end
	step()
end

local function check_nodes(index)
	local c = COLUMNS[index]
	if not c then
		t2_checks()
		return t3_checks(finish)
	end
	local x, z = c[1], c[2]
	local h = read_column(c)
	local lo, hi = {x = x, y = h - 2, z = z}, {x = x, y = 2, z = z}
	core.emerge_area(lo, hi, function(_, _, remaining)
		if remaining ~= 0 then return end
		local top = core.get_node({x = x, y = 1, z = z}).name
		local floor_node = core.get_node({x = x, y = h, z = z}).name
		local above = core.get_node({x = x, y = h + 1, z = z}).name
		log(("nodes %d %d: y 1 %s, floor y %d %s, above %s"):format(x, z, top, h,
			floor_node, above))
		local label = ("%d,%d"):format(x, z)
		local def = core.registered_nodes[floor_node]
		expect(core.get_item_group(top, "water") > 0, label .. " water at y 1")
		expect(def ~= nil and def.walkable == true, label .. " ground at the floor")
		expect(core.get_item_group(above, "water") > 0, label .. " water above the floor")
		core.after(0.5, function() check_nodes(index + 1) end)
	end)
end

local waited = 0
local function wait_ready()
	local status = grug_core.world_preparation_status()
	if status.failed then
		failures[#failures + 1] = "world preparation failed"
		return finish()
	end
	if status.ready then
		log(("preparation ready after %d s"):format(waited))
		return check_nodes(1)
	end
	waited = waited + 1
	core.after(1, wait_ready)
end
core.after(1, wait_ready)
