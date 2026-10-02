-- Disposable engine probe (Round 28 Lane S1). Never shipped:
-- tools/r28_s1/run.sh stages it through tools/luanti_headless.sh together
-- with tools/r24_density_xp/probe_player_shim.patch (mobs_redo's add_mob and
-- ABM count accept the stationary probe points as players in range).
--
-- With the SHIPPED Dawnmere recipe:
--   * the region map is built in the real game (build time logged) and the
--     probe points are chosen from it: the largest region of a few kinds and
--     the bandit camp, so the points are right on every seed;
--   * the points are force-loaded and stand in as players for the spawner
--     (spawn_regions.players) and for mobs_redo;
--   * a day window and a night window; every region spawn is checked as it
--     happens (the clock's roster, the level in the role's range, the region
--     under the spot of the tag's kind), and every grug_mobs entity within 72
--     nodes of a point is listed in a census: tag, role, level;
--   * the level overlay at the points (grug_core vs the analytic field), the
--     camp's members and levels, the leader's level and HP, the outcome counts
--     (drift refusals among them).
-- RESULT PASS / FAIL.

local P = "[r28_s1_probe] "
local ZONE = "elandor_dawnmere_fields"
local WINDOW = 70
local RADIUS = 72
local SR = grug_mobs.spawn_regions

local function log(msg) core.log("action", P .. msg) end

local POINTS = {}
local fakes, failures = {}, {}
local function fail(msg)
	failures[#failures + 1] = msg
	log("CHECK FAIL " .. msg)
end

local function census(label)
	for _, point in ipairs(POINTS) do
		local center = {x = point.x, y = point.y, z = point.z}
		local by, rows = {}, {}
		for _, object in ipairs(core.get_objects_inside_radius(center, RADIUS + 40)) do
			local ent = object:get_luaentity()
			local pos = object:get_pos()
			if ent and ent.name and ent.name:sub(1, 10) == "grug_mobs:" and pos then
				local dx, dz = pos.x - point.x, pos.z - point.z
				if dx * dx + dz * dz <= RADIUS * RADIUS and grug_zones.id_at(pos.x, pos.z) == ZONE then
					local role = ent.name:sub(11)
					local def = core.registered_entities[ent.name]
					local key
					if ent._grug_leader then
						key = role .. "@leader L" .. tostring(ent._grug_level)
					elseif ent._grug_area then
						local unit = SR.area_by_tag(ent._grug_area)
						local level = ent._grug_level or ent._grug_spawn_level
						key = ("%s@%s L%s"):format(role, ent._grug_area:sub(#ZONE + 2), tostring(level))
						if not unit then
							fail("unknown tag " .. ent._grug_area)
						elseif not unit.roles[role] then
							fail(role .. " is not a role of " .. ent._grug_area)
						else
							local range = unit.levels_by_role[role]
							if level < range[1] or level > range[2] then
								fail(("%s level %d outside %d-%d"):format(role, level, range[1], range[2]))
							end
						end
					elseif def and def._grug_disposition == "critter" then
						key = role .. "@critter"
					elseif ent.type == "npc" then
						key = role .. "@npc"
					elseif ent._grug_home and
							grug_zones.id_at(ent._grug_home.x, ent._grug_home.z) ~= ZONE then
						key = role .. "@walked_in" -- spawned in a neighbouring zone
					else
						key = role .. "@UNTAGGED"
						fail("untagged ordinary mob " .. role .. " near " .. point.id)
					end
					by[key] = (by[key] or 0) + 1
				end
			end
		end
		for key, count in pairs(by) do rows[#rows + 1] = key .. "=" .. count end
		table.sort(rows)
		log(("census %s %s [%s]"):format(label, point.id, table.concat(rows, " ")))
	end
end

-- Every region spawn as it happens: roster of the clock, level, region.
local spawned_by = {}
local original_spawn = SR.spawn_mob
SR.spawn_mob = function(unit, role, g, clock)
	local ent = original_spawn(unit, role, g, clock)
	if ent then
		local level = ent._grug_spawn_level
		local range = unit.levels_by_role[role]
		if level < range[1] or level > range[2] then
			fail(role .. " rolled level " .. level .. " outside " .. unit.tag)
		end
		if clock ~= SR.clock_now() then fail(role .. " spawned for " .. clock .. " at the other clock") end
		local roster = unit.rosters[clock]
		local listed = false
		for _, row in ipairs(roster.list) do listed = listed or row.role == role end
		if not listed then fail(role .. " is not in " .. unit.tag .. "'s " .. clock .. " roster") end
		if not unit.is_camp then
			local region = SR.region_at(g.x, g.z)
			if not region or region.kind ~= unit then
				fail(role .. " of " .. unit.tag .. " spawned outside a region of its kind")
			end
		end
		local key = ("%s %s %s L%d"):format(clock, unit.tag:sub(#ZONE + 2), role, level)
		spawned_by[key] = (spawned_by[key] or 0) + 1
	end
	return ent
end

local function stats_line(label)
	local rows = {}
	for k, v in pairs(SR.stats) do rows[#rows + 1] = k .. "=" .. v end
	table.sort(rows)
	log(("attempt outcomes %s: %s"):format(label, table.concat(rows, " ")))
end

local function run_window(clock, done)
	local value = clock == "day" and 0.5 or 0.0
	core.set_timeofday(value)
	log("window " .. clock .. " start")
	for s = 10, WINDOW, 10 do
		core.after(s, function() core.set_timeofday(value) end)
	end
	core.after(WINDOW, function()
		census(clock .. "@" .. WINDOW)
		stats_line(clock)
		done()
	end)
end

local function finish()
	local rows = {}
	for k, v in pairs(spawned_by) do rows[#rows + 1] = k .. "=" .. v end
	table.sort(rows)
	for _, row in ipairs(rows) do log("spawned " .. row) end
	local map = SR.map(ZONE)
	local camp = map.camps[1]
	local members, leader = 0, nil
	for _, object in ipairs(core.get_objects_inside_radius({x = camp.x, y = camp.y, z = camp.z}, 120)) do
		local ent = object:get_luaentity()
		if ent and ent._grug_area == camp.camp.tag then
			members = members + 1
			if ent._grug_level < 9 or ent._grug_level > 10 then
				fail("camp member at level " .. tostring(ent._grug_level))
			end
		end
		if ent and ent._grug_leader then leader = ent end
	end
	log("camp members " .. members)
	for _, spot in ipairs(map.leaders) do
		log(("leader spot %s (%d, %d), leaders spawned %d"):format(spot.role, spot.x, spot.z,
			SR.stats.leader_spawned or 0))
	end
	if members < 1 or members > camp.camp.slots then fail("camp holds " .. members) end
	if not leader then
		fail("leader not standing at its spot")
	else
		local hp = grug_mobs.stats_for(leader._grug_level, leader._grug_tier)
		local props = leader.object:get_properties()
		log(("leader %s level %d hp_max %d (plain %d) visual_size %.3f"):format(leader.name,
			leader._grug_level, leader.hp_max, hp, props.visual_size.x))
		if leader._grug_level ~= 10 then fail("leader level " .. leader._grug_level) end
		if leader.hp_max ~= 2 * hp then fail("leader hp " .. leader.hp_max) end
	end
	if (SR.stats.spawned or 0) < 1 then fail("no ambient region spawn") end
	log((#failures == 0 and "RESULT PASS" or "RESULT FAIL") .. " failures=" .. #failures)
	core.request_shutdown("r28 s1 probe done", false, 0)
end

local function start()
	for _, point in ipairs(POINTS) do
		local fake = {pos = {x = point.x, y = point.y + 1, z = point.z}}
		function fake:get_pos() return self.pos end
		fakes[#fakes + 1] = fake
	end
	local positions = {}
	for i, f in ipairs(fakes) do positions[i] = f.pos end
	mobs._grug_probe_players = positions
	SR.players = function() return fakes end
	-- One level truth: the gameplay level at the points against the field.
	for _, point in ipairs(POINTS) do
		local pos = {x = point.x, y = point.y + 1, z = point.z}
		local region = SR.region_at(point.x, point.z)
		local level = grug_core.mob_level_at(pos)
		log(("level at %s: gameplay %s (region %s), analytic field %s"):format(point.id,
			tostring(level), tostring(region and region.level), tostring(grug_zones.mob_level_at(pos))))
		if region and level ~= region.level then fail("level overlay at " .. point.id) end
	end
	run_window("day", function()
		run_window("night", finish)
	end)
end

core.after(2, function()
	local t0 = core.get_us_time()
	local map = SR.map(ZONE)
	if not map then
		fail("no region map")
		log("RESULT FAIL")
		core.request_shutdown("r28 s1 probe failed", false, 0)
		return
	end
	log(("region map: %d cells, %d regions in %.0f ms (ready at start)"):format(map.cell_count,
		#map.regions, (core.get_us_time() - t0) / 1000))
	for _, kind in ipairs({"home_fields", "strand", "pastures", "borderlands"}) do
		local t = SR.core.target_of(map, kind)
		if t then POINTS[#POINTS + 1] = {id = kind, x = math.floor(t.x), z = math.floor(t.z)} end
	end
	local camp = map.camps[1]
	if camp then
		camp.y = grug_zones.terrain_height_at(camp.x, camp.z)
		-- Beside the camp, not on it: a leader keeps 24 nodes from players.
		POINTS[#POINTS + 1] = {id = "camp", x = math.floor(camp.x) + 32, z = math.floor(camp.z)}
	else
		fail("no camp")
	end
	local pending = 0
	for _, point in ipairs(POINTS) do
		point.y = grug_zones.terrain_height_at(point.x, point.z)
		log(("point %s (%d, %d, %d)"):format(point.id, point.x, point.y, point.z))
		local minp = {x = point.x - RADIUS, y = point.y - 32, z = point.z - RADIUS}
		local maxp = {x = point.x + RADIUS - 1, y = point.y + 47, z = point.z + RADIUS - 1}
		for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
			for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
				for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
					core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
				end
			end
		end
		pending = pending + 1
		core.emerge_area(minp, maxp, function(_, _, remaining)
			if remaining == 0 then
				pending = pending - 1
				if pending == 0 then
					log(("emerged %d areas in %.1f s"):format(#POINTS,
						(core.get_us_time() - t0) / 1e6))
					core.after(1, start)
				end
			end
		end)
	end
end)
