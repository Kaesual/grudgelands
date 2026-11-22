-- Round 85 lane TERRITORY engine probe (disposable, never shipped): the arena
-- "Breach Road" as a place of the game on a real world, without a client.
--
-- The layout comes from grug_mapgen (grug_mapgen.breach, the placement text's
-- site); every check asks the game's own public functions:
-- 1. LAYOUT: grug_mapgen.breach is the placement text's site.
-- 2. TERRITORY: grug_pvp.territory_at at each hall's floor (feet on it),
--    centre and muster point answers "friendly" for its faction and "enemy"
--    for the other; the doorway sills, the roof, the court and the road
--    answer "contested" for both.
-- 3. WAYSTONES: grug_home.waystone_pos of both hall stones is the layout's
--    cell; a stand-in player of the hall's faction right-clicking it
--    (grug_home.use_waystone) discovers it (the stored list), one of the
--    other faction does not. Proximity discovery needs a connected player:
--    tools/r29_w runs the shipped pass on the real rows.
-- 4. PROTECTION: grug_core.world_feature_at "arena" and
--    world_protected_for_faction for both factions inside the protected
--    box, grug_core.world_alterable false there; beyond the box's east face
--    neither.
-- 5. SPAWNS: grug_mobs.protected_spawn_surface on the fringe's corners and
--    centre; no camp, leader or quest place of the game's region maps and no
--    rare route point on the fringe.
-- 6. NAMES: grug_map.location.text_at on the footprint is "Breach Road"; the
--    map's PvP layer holds the arena's marker.
-- Ends the server itself; "RESULT PASS" is the verdict line.
local PREFIX = "[r85_territory_probe] "
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
local L = dofile(core.get_modpath("grug_mapgen") .. "/wp40/breach_layout.lua")

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r85 territory probe done", false, 0)
end

-- A stand-in player: name, faction and position, a meta table.
local function stand_in(name, faction, pos)
	local data = {["grug_factions:faction"] = faction}
	local meta = {
		get_string = function(_, key) return data[key] or "" end,
		set_string = function(_, key, value) data[key] = value end,
		get_int = function(_, key) return tonumber(data[key]) or 0 end,
		set_int = function(_, key, value) data[key] = tostring(value) end,
	}
	return {
		get_player_name = function() return name end,
		is_player = function() return true end,
		get_meta = function() return meta end,
		get_hp = function() return 20 end,
		get_pos = function() return vector.new(pos) end,
	}, data
end

local function run()
	local B = grug_mapgen.breach
	local site = L.from_placement(grug_mapgen.wp40.placement_layout_text)
	check(B and B.centre.x == site.x and B.centre.z == site.z and B.datum == site.y and
		B.reach == site.reach, "1 the layout is the placement text's site")
	log(("site %d,%d datum %d reach %d"):format(site.x, site.z, site.y, site.reach))

	-- 2. territory
	for _, faction in ipairs({"accord", "throng"}) do
		local other = faction == "accord" and "throng" or "accord"
		local hall = B.halls[faction]
		local lo, hi = hall.interior.min, hall.interior.max
		local cx, cz = math.floor((lo.x + hi.x) / 2), math.floor((lo.z + hi.z) / 2)
		for _, p in ipairs({{cx, hall.floor_y + 0.5, cz, "feet on the floor"},
				{cx, (lo.y + hi.y) / 2, cz, "centre"},
				{hall.muster.x, hall.muster.y, hall.muster.z, "muster point"}}) do
			local pos = {x = p[1], y = p[2], z = p[3]}
			local own, theirs = grug_pvp.territory_at(pos, faction), grug_pvp.territory_at(pos, other)
			check(own == "friendly" and theirs == "enemy", ("2 %s hall %s: %s / %s"):format(faction,
				p[4], tostring(own), tostring(theirs)))
		end
		for _, p in ipairs({{lo.x - 1, hall.floor_y + 1, cz, "sill west"},
				{hi.x + 1, hall.floor_y + 1, cz, "sill east"},
				{cx, hi.y + 2.5, cz, "on the roof"}}) do
			local pos = {x = p[1], y = p[2], z = p[3]}
			local a, b = grug_pvp.territory_at(pos, "accord"), grug_pvp.territory_at(pos, "throng")
			check(a == "contested" and b == "contested", ("2 %s hall %s: %s / %s"):format(faction,
				p[4], tostring(a), tostring(b)))
		end
	end
	for _, p in ipairs({{B.centre.x, B.datum + 1, B.centre.z, "the road"},
			{B.centre.x + 20, B.datum + 4, B.centre.z - 30, "a court"}}) do
		local pos = {x = p[1], y = p[2], z = p[3]}
		local a, b = grug_pvp.territory_at(pos, "accord"), grug_pvp.territory_at(pos, "throng")
		check(a == "contested" and b == "contested", ("2 %s: %s / %s"):format(p[4], tostring(a),
			tostring(b)))
	end

	-- 3. waystones
	for _, faction in ipairs({"accord", "throng"}) do
		local other = faction == "accord" and "throng" or "accord"
		local id = "breach_road_" .. faction
		local cell = B.halls[faction].waystone
		local stone = grug_home.waystone_pos(id)
		check(stone and vector.equals(stone, cell), "3 " .. id .. " at the layout's cell")
		local near = {x = cell.x, y = cell.y, z = cell.z + 2}
		local own, own_data = stand_in("r85probe_" .. faction, faction, near)
		local enemy, enemy_data = stand_in("r85probe_x" .. faction, other, near)
		local ok_own, err_own = pcall(grug_home.use_waystone, own, cell)
		local ok_enemy, err_enemy = pcall(grug_home.use_waystone, enemy, cell)
		log(("%s: right-click by %s %s, by %s %s"):format(id, faction,
			ok_own and "ok" or tostring(err_own), other, ok_enemy and "ok" or tostring(err_enemy)))
		check((own_data["grug_home:waypoints"] or ""):find(id, 1, true) ~= nil,
			"3 " .. id .. " discovered by its faction (" .. tostring(own_data["grug_home:waypoints"]) .. ")")
		check(not (enemy_data["grug_home:waypoints"] or ""):find("breach_road", 1, true),
			"3 " .. id .. " not discovered by the other faction")
		local arrival = grug_home.waystone_arrival(id)
		log(id .. " arrival " .. (arrival and core.pos_to_string(arrival, 2) or
			"none (no hall blocks yet: lane BUILD writes them)"))
	end

	-- 4. protection (the box's east face and beyond, the hull's centre)
	local box = B.protected
	local inside = {{B.centre.x, B.datum, B.centre.z}, {B.centre.x, B.datum + 20, B.centre.z},
		{box.min.x, box.min.y, box.min.z}, {box.max.x, box.max.y, box.max.z},
		{box.max.x, B.datum + 1, B.centre.z}}
	for _, p in ipairs(inside) do
		local pos = {x = p[1], y = p[2], z = p[3]}
		check(grug_core.world_feature_at(pos) == "arena" and
			grug_core.world_protected_for_faction(pos, "accord") and
			grug_core.world_protected_for_faction(pos, "throng") and
			not grug_core.world_alterable(pos), ("4 protected at %d,%d,%d"):format(p[1], p[2], p[3]))
	end
	local east = {x = box.max.x + 1, y = B.datum + 1, z = B.centre.z}
	log(("east of the box: feature %s, protected %s/%s, alterable %s, territory %s"):format(
		tostring(grug_core.world_feature_at(east)),
		tostring(grug_core.world_protected_for_faction(east, "accord")),
		tostring(grug_core.world_protected_for_faction(east, "throng")),
		tostring(grug_core.world_alterable(east)), tostring(grug_zones.territory_rule_at(east))))
	check(grug_core.world_feature_at(east) == nil and grug_core.world_alterable(east),
		"4 beyond the box's east face neither protected nor guarded")

	-- 5. spawns
	local f = B.fringe
	for _, p in ipairs({{f.min.x, f.min.z}, {f.max.x, f.max.z}, {f.min.x, f.max.z},
			{B.centre.x, B.centre.z}}) do
		local y = grug_zones.terrain_height_at(p[1], p[2]) + 1
		check(grug_mobs.protected_spawn_surface({x = p[1], y = y, z = p[2]}),
			("5 no spawn on the fringe at %d,%d"):format(p[1], p[2]))
	end
	local function on_fringe(x, z)
		return x >= f.min.x and x <= f.max.x and z >= f.min.z and z <= f.max.z
	end
	local SR = grug_mobs.spawn_regions
	local seen, spots = {}, 0
	for x = f.min.x, f.max.x, 8 do
		for z = f.min.z, f.max.z, 8 do
			local id = grug_zones.id_at(x, z)
			if id and not seen[id] then
				seen[id] = true
				local map = SR.map(id)
				for _, list in ipairs(map and {map.camps, map.leaders, map.places or {}} or {}) do
					for _, s in ipairs(list) do
						spots = spots + 1
						check(not on_fringe(s.x, s.z), ("5 %s %s at %d,%d off the fringe"):format(id,
							tostring(s.id or s.role), s.x, s.z))
					end
				end
			end
		end
	end
	log(("region spots checked: %d"):format(spots))
	for _, id in ipairs({"bonerattle_north", "bonerattle_south"}) do
		for _, pt in ipairs(grug_core.rare_route(id) or {}) do
			check(not on_fringe(pt.x, pt.z), ("5 rare %s point %d,%d off the fringe"):format(id,
				pt.x, pt.z))
		end
	end

	-- 6. names
	check(grug_map.location.text_at({x = B.centre.x, y = B.datum + 1, z = B.centre.z}) == "Breach Road",
		"6 the location line on the footprint")
	check(grug_map.location.text_at({x = f.max.x + 2, y = B.datum, z = B.centre.z}) ~= "Breach Road",
		"6 not beyond the fringe")
	local marker
	for _, row in ipairs(grug_map.layers.rows.pvp) do
		if row.id == "breach_road" then marker = row end
	end
	check(marker and marker.label == "Breach Road" and marker.position.x == B.centre.x,
		"6 the map's PvP layer marker")
end

core.after(2, function()
	local ok, err = pcall(run)
	check(ok, "the probe ran: " .. tostring(err))
	finish()
end)
