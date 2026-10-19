-- Round 51 TERRAIN T1 engine probe (disposable, never shipped; staged by
-- `PROBE=` of tools/luanti_headless.sh). After the world preparation it reads
-- columns of the new ring (between the old bounds +-3740 x +-3340 and the new
-- +-4190 x +-3740), just inside and just outside the new bounds, through the
-- game's own seams (grug_zones, grug_core, core.is_protected), generates the
-- chunk holding each column's sea floor and checks what the engine wrote
-- there (water at y 1, ground at the planned floor), then shuts down.
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

local function check_nodes(index)
	local c = COLUMNS[index]
	if not c then return finish() end
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
