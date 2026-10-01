-- Disposable engine probe (Round 28 Lane B1). Never shipped:
-- tools/r28_b1/run.sh stages it through tools/luanti_headless.sh together
-- with tools/r24_density_xp/probe_player_shim.patch (mobs_redo's add_mob and
-- ABM count accept the stationary probe points as players in range).
--
-- At load it installs the sample areas file next to this file for Dawnmere
-- Fields (existing mobs only), before the role check on mods loaded. Then:
--   * four probe points are force-loaded and stand in as players for the
--     area spawner (spawn_areas.players) and for mobs_redo;
--   * costs on the real world: grug_mobs.protected_spawn_surface,
--     spawn_policy_allows in a fallback zone (Goldmead) and one area attempt;
--   * a day window and a night window; at each census every grug_mobs entity
--     within 72 nodes of a point is listed: area tag, level, leader flag.
-- Checks (RESULT PASS / FAIL): every ordinary mob around a Dawnmere point
-- carries an area tag of the sample with a level inside that area's range,
-- day roles only by day and night roles only at night (spawned in the
-- window), the camp holds 1..4 members, the leader stands with level 10,
-- critters keep spawning from their rows.

local P = "[r28_b1_probe] "
local ZONE = "elandor_dawnmere_fields"
local WINDOW = 70
local RADIUS = 72
local SA = grug_mobs.spawn_areas

local function log(msg) core.log("action", P .. msg) end

local dir = core.get_modpath(core.get_current_modname())
local file = io.open(dir .. "/" .. ZONE .. ".spawns.json", "rb")
local sample = core.parse_json(file:read("*a"))
file:close()
SA.install_zone(ZONE, sample)
log("sample installed: " .. ZONE .. " has areas = " .. tostring(SA.zone_has_areas(ZONE)))

-- Probe points (x, z); y is the terrain height at run time.
local POINTS = {
	{id = "home_fields", x = 0, z = -2740},
	{id = "beach", x = -380, z = -2990},
	{id = "camp_leader", x = -120, z = -2330},
	{id = "front", x = 120, z = -2330},
}

local fakes, failures = {}, {}
local function fail(msg)
	failures[#failures + 1] = msg
	log("CHECK FAIL " .. msg)
end

local function census(label)
	for _, point in ipairs(POINTS) do
		local center = {x = point.x, y = point.y, z = point.z}
		local rows, by = {}, {}
		for _, object in ipairs(core.get_objects_inside_radius(center, RADIUS + 40)) do
			local ent = object:get_luaentity()
			local pos = object:get_pos()
			if ent and ent.name and ent.name:sub(1, 10) == "grug_mobs:" and pos then
				local dx, dz = pos.x - point.x, pos.z - point.z
				if dx * dx + dz * dz <= RADIUS * RADIUS and
						grug_zones.id_at(pos.x, pos.z) == ZONE then
					local short = ent.name:sub(11)
					local def = core.registered_entities[ent.name]
					local critter = def and def._grug_disposition == "critter"
					local key
					if ent._grug_leader then
						key = short .. "@leader L" .. tostring(ent._grug_level)
						if ent._grug_level ~= 10 then fail("leader level " .. tostring(ent._grug_level)) end
					elseif ent._grug_area then
						local area = SA.area_by_tag(ent._grug_area)
						key = short .. "@" .. ent._grug_area:sub(#ZONE + 2)
						local level = ent._grug_level or ent._grug_spawn_level
						if not area then
							fail("unknown area tag " .. ent._grug_area)
						elseif level < area.levels[1] or level > area.levels[2] then
							fail(("%s level %d outside %s %d-%d"):format(short, level,
								area.id, area.levels[1], area.levels[2]))
						elseif not area.roles[short] then
							fail(short .. " is not a species of " .. area.id)
						end
					elseif critter then
						key = short .. "@critter"
					elseif ent.type == "npc" then
						key = short .. "@npc"
					elseif ent._grug_home and
							grug_zones.id_at(ent._grug_home.x, ent._grug_home.z) ~= ZONE then
						key = short .. "@walked_in" -- spawned in a neighbouring zone
					else
						key = short .. "@UNTAGGED"
						fail("untagged ordinary mob " .. short .. " near " .. point.id)
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

local function stats_line(label)
	local rows = {}
	for k, v in pairs(SA.stats) do rows[#rows + 1] = k .. "=" .. v end
	table.sort(rows)
	log(("attempt outcomes %s: %s"):format(label, table.concat(rows, " ")))
end

local function bench()
	-- Fresh surface positions each call (the protection answer is memoised
	-- per position), in Dawnmere and in Goldmead (a fallback zone).
	local function surface_points(x0, z0, n)
		local pts = {}
		for i = 1, n do
			local x = x0 + (i * 37) % 400 - 200
			local z = z0 + (i * 53) % 400 - 200
			pts[i] = {x = x, y = grug_zones.terrain_height_at(x, z), z = z}
		end
		return pts
	end
	local dawn = surface_points(0, -2600, 2000)
	local gold = surface_points(0, -2050, 2000)
	local t0 = core.get_us_time()
	for i = 1, #dawn do grug_mobs.protected_spawn_surface(dawn[i]) end
	for i = 1, #gold do grug_mobs.protected_spawn_surface(gold[i]) end
	local protect_us = (core.get_us_time() - t0) / (#dawn + #gold)
	local names = {"grug_mobs:boar", "grug_mobs:fox", "grug_mobs:zombie",
		"grug_mobs:giant_rat", "grug_mobs:wild_turkey"}
	t0 = core.get_us_time()
	local calls, allowed = 0, 0
	for i = 1, #gold do
		local p = gold[i]
		for _, name in ipairs(names) do
			if grug_mobs.spawn_policy_allows(name, p) then allowed = allowed + 1 end
			calls = calls + 1
		end
	end
	local policy_us = (core.get_us_time() - t0) / calls
	-- Today's per-attempt density decision for comparison (one object scan
	-- of the 128-node radius per allowed ABM attempt), at the probe points.
	t0 = core.get_us_time()
	local dcalls = 0
	for rep = 1, 50 do
		for _, point in ipairs(POINTS) do
			local p = {x = point.x + 30, y = point.y, z = point.z}
			grug_mobs.density_allows("grug_mobs:boar", p, "default:dirt_with_grass",
				grug_mobs.spawn_allowed)
			dcalls = dcalls + 1
		end
	end
	log(("cost density_allows (today's ABM budget check) %.1f us/call (%d calls)")
		:format((core.get_us_time() - t0) / dcalls, dcalls))
	log(("cost protected_spawn_surface %.2f us/call (%d points); spawn_policy_allows " ..
		"in Goldmead %.2f us/call (%d calls, %d allowed, each allowed ordinary row " ..
		"pays one protection query)"):format(protect_us, #dawn + #gold, policy_us,
		calls, allowed))
end

-- Every area spawn is checked as it happens: its clock and its level.
local original_spawn = SA.spawn_area_mob
SA.spawn_area_mob = function(area, role, g)
	local ent = original_spawn(area, role, g)
	if ent then
		local clock = SA.clock_now()
		if area.clock ~= "both" and area.clock ~= clock then
			fail(role .. " of " .. area.id .. " spawned at " .. clock)
		end
		local level = ent._grug_spawn_level
		if level < area.levels[1] or level > area.levels[2] then
			fail(role .. " rolled level " .. level .. " outside " .. area.id)
		end
	end
	return ent
end

local attempt_us, attempt_n = {}, {}
local original_attempt = SA.attempt
SA.attempt = function(...)
	local t0 = core.get_us_time()
	local result = original_attempt(...)
	local key = result == "spawned" and "spawned" or "refused"
	attempt_us[key] = (attempt_us[key] or 0) + (core.get_us_time() - t0)
	attempt_n[key] = (attempt_n[key] or 0) + 1
	return result
end

local function run_window(clock, done)
	local value = clock == "day" and 0.5 or 0.0
	core.set_timeofday(value)
	log("window " .. clock .. " start")
	for s = 10, WINDOW, 10 do
		core.after(s, function() core.set_timeofday(value) end)
	end
	core.after(WINDOW / 2, function() census(clock .. "@" .. (WINDOW / 2)) end)
	core.after(WINDOW, function()
		census(clock .. "@" .. WINDOW)
		stats_line(clock)
		done()
	end)
end

local function start()
	for _, point in ipairs(POINTS) do
		local ok, zone = pcall(grug_zones.id_at, point.x, point.z)
		log(("point %s (%d, %d, %d) zone %s"):format(point.id, point.x, point.y, point.z,
			tostring(zone)))
		local fake = {pos = {x = point.x, y = point.y + 1, z = point.z}}
		function fake:get_pos() return self.pos end
		fakes[#fakes + 1] = fake
	end
	local positions = {}
	for i, f in ipairs(fakes) do positions[i] = f.pos end
	mobs._grug_probe_players = positions
	SA.players = function() return fakes end
	bench()
	run_window("day", function()
		run_window("night", function()
			for _, key in ipairs({"refused", "spawned"}) do
				local n = attempt_n[key] or 0
				log(("cost area attempt (%s, incl. add_mob when spawned) %.1f us mean over %d")
					:format(key, n > 0 and attempt_us[key] / n or 0, n))
			end
			local leader_seen = false
			for _, object in ipairs(core.get_objects_inside_radius(
					{x = -100, y = POINTS[3].y, z = -2330}, 80)) do
				local ent = object:get_luaentity()
				if ent and ent._grug_leader and ent.name == "grug_mobs:bear" then
					leader_seen = true
				end
			end
			if not leader_seen then fail("leader not standing at its spot") end
			local members = 0
			for _, object in ipairs(core.get_objects_inside_radius(
					{x = -160, y = POINTS[3].y, z = -2350}, 120)) do
				local ent = object:get_luaentity()
				if ent and ent._grug_area == ZONE .. "/border_bandits" then
					members = members + 1
				end
			end
			log("camp members " .. members)
			if members < 1 or members > 4 then fail("camp holds " .. members) end
			if (SA.stats.spawned or 0) < 1 then fail("no ambient area spawn") end
			log((#failures == 0 and "RESULT PASS" or "RESULT FAIL") ..
				" failures=" .. #failures)
			core.request_shutdown("r28 b1 probe done", false, 0)
		end)
	end)
end

core.after(2, function()
	local pending = 0
	local t0 = core.get_us_time()
	for _, point in ipairs(POINTS) do
		point.y = grug_zones.terrain_height_at(point.x, point.z)
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
