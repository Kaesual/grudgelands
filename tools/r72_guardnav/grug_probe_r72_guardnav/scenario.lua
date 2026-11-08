-- The probe (round72-plan.md §3.3, §2.5): a level 40 guard and a captain (the
-- Stakeguards' chassis, pvp.md §6.3) against a player 17-20 nodes away who hits
-- them like a Mage (one ability hit a second, through grug_core.deal_ability_damage,
-- HIT_SHARE of the mob's maximum health each). Scenes, one lane each on a stone
-- floor high above deep ocean (the Round 42 NV0 arena):
--   open         the player on the floor at 18 nodes: reachable (the control)
--   pillar       on a 1x1 pillar 4 high at 18 nodes
--   ladder_top   on a 3x3 tower 4 high at 19 nodes, a ladder on its near face
--   ladder_hang  in the top node of a ladder on a tower 5 high, at 17 nodes
-- Recorded per trial: every hit and the health it took, the navigation's events
-- and searches (padding, length, found, cost), the give-ups, the resets and the
-- evade, the mob's strikes on the player, when the mob took the player as its
-- target (a pull) and whether a hit after a reset starts a new chase at once.
-- Then the cost of one engine search to a target out of reach at 17, 20 and 24
-- nodes at padding 6, 12 and 16 (median of 5), and of a found one.
local floor = math.floor
local us = core.get_us_time
local nav = mobs.grug_nav

local FLOOR_Y = 300 -- the floor's top node
local HOME_X = 6 -- the mob's home, lane-relative
local LANE_PITCH = 24
local HIT_EVERY = 1.0 -- s between the player's hits
local HIT_SHARE = 0.03 -- of the mob's hp_max per hit
local TRIAL = 20 -- s per trial
local LEVEL = 40

local SCENES = {
	{name = "open", dist = 18},
	{name = "pillar", dist = 18},
	{name = "ladder_top", dist = 19},
	{name = "ladder_hang", dist = 17},
	{name = "cost"},
}
local TRIALS = {
	{scene = "open", mob = "grug_mobs:guard_throng"},
	{scene = "pillar", mob = "grug_mobs:guard_throng"},
	{scene = "ladder_top", mob = "grug_mobs:guard_throng"},
	{scene = "ladder_hang", mob = "grug_mobs:guard_throng"},
	{scene = "pillar", mob = "grug_mobs:captain_throng"},
	{scene = "ladder_top", mob = "grug_mobs:captain_throng"},
}

local origin
local function lane_z(index) return origin.z + 10 + (index - 1) * LANE_PITCH end
local function scene_index(name)
	for i, s in ipairs(SCENES) do if s.name == name then return i end end
end

local function find_origin(w, d)
	for r = 0, 40 do
		for i = -r, r do
			for _, c in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = c[1] * 256, c[2] * 256
				local ok = true
				for _, o in ipairs({{0, 0}, {w, 0}, {0, d}, {w, d}, {w / 2, d / 2}}) do
					if grug_zones.water_class_at(x + o[1], z + o[2]) ~= "deep_ocean" then
						ok = false
						break
					end
				end
				if ok then return {x = x, y = 0, z = z} end
			end
		end
	end
end

local W = 44
local function arena_box()
	return {x = origin.x, y = FLOOR_Y - 1, z = origin.z},
		{x = origin.x + W, y = FLOOR_Y + 10, z = origin.z + 20 + #SCENES * LANE_PITCH}
end

local LADDER = "default:ladder_wood"
local function build()
	local minp, maxp = arena_box()
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data, p2 = vm:get_data(), vm:get_param2_data()
	local stone, air = core.get_content_id("default:stone"), core.get_content_id("air")
	local ladder = core.get_content_id(LADDER)
	local wall = core.dir_to_wallmounted({x = 1, y = 0, z = 0})
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				data[area:index(x, y, z)] = y <= FLOOR_Y and stone or air
			end
		end
	end
	local function put(x, y, z, id, param2)
		local i = area:index(origin.x + x, y, z)
		data[i] = id
		if param2 then p2[i] = param2 end
	end
	for index, s in ipairs(SCENES) do
		local zc = lane_z(index)
		local tx = HOME_X + (s.dist or 0)
		if s.name == "pillar" then
			for y = FLOOR_Y + 1, FLOOR_Y + 4 do put(tx, y, zc, stone) end
		elseif s.name == "ladder_top" or s.name == "ladder_hang" then
			local h = s.name == "ladder_top" and 4 or 5
			local x0 = s.name == "ladder_top" and tx or tx + 1
			for y = FLOOR_Y + 1, FLOOR_Y + h do
				for x = x0, x0 + 2 do
					for z = zc - 1, zc + 1 do put(x, y, z, stone) end
				end
				put(x0 - 1, y, zc, ladder, wall)
			end
		elseif s.name == "cost" then
			for _, d in ipairs({17, 20, 24}) do
				for y = FLOOR_Y + 1, FLOOR_Y + 4 do put(HOME_X + d, y, zc, stone) end
			end
		end
	end
	vm:set_data(data)
	vm:set_param2_data(p2)
	vm:write_to_map(true)
end

-- Where the player stands (feet) in a scene.
local function player_spot(index)
	local s, zc = SCENES[index], lane_z(index)
	local tx = origin.x + HOME_X + s.dist
	if s.name == "open" then return {x = tx, y = FLOOR_Y + 0.5, z = zc} end
	if s.name == "pillar" then return {x = tx, y = FLOOR_Y + 4.5, z = zc} end
	if s.name == "ladder_top" then return {x = tx + 1, y = FLOOR_Y + 4.5, z = zc} end
	-- ladder_hang: in the top ladder node (the tower starts one further)
	return {x = tx, y = FLOOR_Y + 4.5, z = zc}
end

---------------------------------------------------------------------------
-- The recording hooks (one trial at a time).
---------------------------------------------------------------------------
local rec -- the current trial's record
local t_start
local function now_s() return (us() - t_start) / 1e6 end
local function note(kind, extra)
	if not rec then return end
	rec.events[#rec.events + 1] = ("%.2f %s%s"):format(now_s(), kind, extra and (" " .. extra) or "")
end

nav.on_event = function(self, kind)
	if not rec or self ~= rec.ent then return end
	rec.nav[kind] = (rec.nav[kind] or 0) + 1
	if kind ~= "found" and kind ~= "repaired" then note("nav:" .. kind) end
end
local search = nav.search
nav.search = function(from, goal, padding, jump, drop)
	local t0 = us()
	local path = search(from, goal, padding, jump, drop)
	local cost = us() - t0
	if rec then
		local dx, dz = goal.x - from.x, goal.z - from.z
		rec.searches[#rec.searches + 1] = cost
		note("search", ("pad %d dist %.1f dy %d %s %d us len %d end_dy %s"):format(
			padding or -1, math.sqrt(dx * dx + dz * dz), goal.y - from.y,
			path and "found" or "none", cost, path and #path or 0,
			path and tostring(path[#path].y - goal.y) or "-"))
	end
	return path
end
for _, fn in ipairs({"give_up_target", "leash_reset", "reset_home", "evade_home"}) do
	local real = grug_mobs[fn]
	if real then
		grug_mobs[fn] = function(self, ...)
			if rec and self == rec.ent then
				local nst = self.temp and self.temp.grug_nav
				note(fn, ("hp %d/%d fails %s"):format(self.health or -1, self.hp_max or -1,
					tostring(nst and nst.fails)))
				if fn ~= "evade_home" then rec.resets[#rec.resets + 1] = {fn = fn, t = now_s()} end
			end
			return real(self, ...)
		end
	end
end
local mark_player_hit = grug_core.mark_player_hit
grug_core.mark_player_hit = function(player, source)
	if rec and source and source == rec.obj then
		rec.strikes = rec.strikes + 1
		if not rec.first_strike then rec.first_strike = now_s() end
		note("strike")
	end
	return mark_player_hit(player, source)
end

local function median(list)
	local t = {}
	for i, v in ipairs(list) do t[i] = v end
	table.sort(t)
	return t[math.ceil(#t / 2)] or 0
end

---------------------------------------------------------------------------
-- One trial.
---------------------------------------------------------------------------
local function trial(lib, player, spec)
	local index = scene_index(spec.scene)
	local zc = lane_z(index)
	local spot = player_spot(index)
	player:set_pos(spot)
	lib.wait(1.0)
	local home = {x = origin.x + HOME_X, y = FLOOR_Y + 0.5, z = zc}
	local obj = core.add_entity(home, spec.mob)
	assert(obj, "no mob")
	local ent = obj:get_luaentity()
	ent._grug_elite_checked = true
	lib.wait(0.5)
	grug_mobs.relevel(ent, LEVEL)
	ent._grug_home = {x = home.x, y = home.y, z = home.z}
	ent.health = ent.hp_max
	ent.old_health = ent.health
	if ent.update_tag then ent:update_tag() end
	lib.wait(0.5)
	local scale = grug_core.scale_player_damage(player, obj, 100000) / 100000
	local amount = math.max(1, floor(ent.hp_max * HIT_SHARE / scale + 0.5))
	rec = {ent = ent, obj = obj, events = {}, nav = {}, searches = {}, resets = {},
		strikes = 0, hits = {}, pulls = 0}
	local c0 = {searches = nav.counters.searches, found = nav.counters.found}
	nav.counters.largest_us = 0
	t_start = us()
	lib.logf("TRIAL %s %s level %d hp %d amount %d (x%.3f) home %s target %s", spec.scene,
		spec.mob, ent._grug_level or -1, ent.hp_max or -1, amount, scale,
		core.pos_to_string(home), core.pos_to_string(spot))
	local next_hit, had_target, died = 0, false, false
	local lost_total, lost_before_reset = 0, nil
	local pending -- a hit after a reset: did it start a chase at once?
	while now_s() < TRIAL do
		coroutine.yield()
		local t = now_s()
		player:set_hp(player:get_properties().hp_max)
		local pp = player:get_pos()
		if pp and vector.distance(pp, spot) > 0.3 then player:set_pos(spot) end
		if not obj:get_pos() or (ent.health or 0) <= 0 then
			died = true
			note("died")
			break
		end
		local targets = ent.attack == player
		if targets and not had_target then
			rec.pulls = rec.pulls + 1
			note("pull", ("dist %.1f"):format(vector.distance(obj:get_pos(), spot)))
		elseif had_target and not targets then
			note("dropped", ("state %s"):format(tostring(ent.state)))
		end
		had_target = targets
		if pending and t - pending.t >= 0.3 then
			rec.rechase[#rec.rechase + 1] = ("hit at %.2f after a reset: lost %d, %s"):format(
				pending.t, pending.lost, pending.chased and "new chase at once" or "no chase")
			pending = nil
		elseif pending and targets then
			pending.chased = true
		end
		if t >= next_hit then
			next_hit = next_hit + HIT_EVERY
			local before = ent.health
			local evading = ent.temp and ent.temp.grug_evading ~= nil
			grug_core.deal_ability_damage(player, obj, amount)
			local lost = before - (ent.health or 0)
			lost_total = lost_total + lost
			rec.hits[#rec.hits + 1] = lost
			note("hit", ("lost %d hp %d%s"):format(lost, ent.health or 0, evading and " (evading)" or ""))
			if #rec.resets > 0 and not rec.rechase_done then
				rec.rechase = rec.rechase or {}
				pending = {t = t, lost = lost, chased = ent.attack == player}
				rec.rechase_done = true
			end
		end
		if not lost_before_reset and #rec.resets > 0 then lost_before_reset = lost_total end
	end
	rec.rechase = rec.rechase or {}
	local first_reset = rec.resets[1]
	local ev = {}
	for k, v in pairs(rec.nav) do ev[#ev + 1] = k .. "=" .. v end
	table.sort(ev)
	local largest = 0
	for _, c in ipairs(rec.searches) do if c > largest then largest = c end end
	lib.logf("RESULT %s %s first_reset %s by %s, resets %d, lost_before_first_reset %s (%.1f %% of %d), "
		.. "lost_total %d, died %s, pulls %d, searches %d found %d, largest_search_us %d, "
		.. "first_strike %s strikes %d, nav {%s}",
		spec.scene, spec.mob, first_reset and ("%.2f s"):format(first_reset.t) or "none",
		first_reset and first_reset.fn or "-", #rec.resets,
		tostring(lost_before_reset or lost_total),
		100 * (lost_before_reset or lost_total) / (ent.hp_max or 1), ent.hp_max or 0,
		lost_total, tostring(died), rec.pulls, nav.counters.searches - c0.searches,
		nav.counters.found - c0.found, largest,
		rec.first_strike and ("%.2f s"):format(rec.first_strike) or "none", rec.strikes,
		table.concat(ev, " "))
	for _, line in ipairs(rec.rechase) do lib.logf("RECHASE %s %s %s", spec.scene, spec.mob, line) end
	for _, line in ipairs(rec.events) do lib.logf("EV %s %s %s", spec.scene, spec.mob, line) end
	rec = nil
	if obj:get_pos() then obj:remove() end
	lib.wait(0.5)
end

---------------------------------------------------------------------------
-- The cost of one search (engine, this map), median of 5.
---------------------------------------------------------------------------
local function cost_phase(lib)
	local index = scene_index("cost")
	local zc = lane_z(index)
	local from = {x = origin.x + HOME_X, y = FLOOR_Y + 1, z = zc}
	local algo = core.settings:get("mob_pathfinding_algorithm") or "A*_noprefetch"
	if algo == "AStar_noprefetch" then algo = "A*_noprefetch" elseif algo == "AStar" then algo = "A*" end
	for _, d in ipairs({17, 20, 24}) do
		local top = {x = origin.x + HOME_X + d, y = FLOOR_Y + 5, z = zc}
		local open = {x = origin.x + HOME_X + d, y = FLOOR_Y + 1, z = zc + 3}
		local parts = {}
		for _, pad in ipairs({6, 12, 16}) do
			local times, found = {}, false
			for _ = 1, 5 do
				local t0 = us()
				local path = core.find_path(from, top, pad, 1, 4, algo)
				times[#times + 1] = us() - t0
				found = found or path ~= nil
			end
			parts[#parts + 1] = ("pad %d none %d us%s"):format(pad, median(times), found and " (FOUND?)" or "")
			coroutine.yield()
		end
		local times = {}
		for _ = 1, 5 do
			local t0 = us()
			core.find_path(from, open, 16, 1, 4, algo)
			times[#times + 1] = us() - t0
		end
		parts[#parts + 1] = ("pad 16 found %d us"):format(median(times))
		lib.logf("COST dist %d (%s): %s", d, algo, table.concat(parts, ", "))
	end
end

return function(lib, player)
	grug_xp.set_xp(player, grug_xp.xp_for_level(LEVEL))
	core.set_timeofday(0.5)
	player:set_physics_override({speed = 0, jump = 0, gravity = 0})
	local w, d = W, 20 + #SCENES * LANE_PITCH
	origin = find_origin(w, d)
	assert(origin, "no deep-ocean origin")
	local minp, maxp = arena_box()
	for bx = floor(minp.x / 16), floor(maxp.x / 16) do
		for bz = floor(minp.z / 16), floor(maxp.z / 16) do
			for by = floor(minp.y / 16), floor(maxp.y / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	local emerged = false
	local t0 = us()
	core.emerge_area(vector.offset(minp, -16, -16, -16), vector.offset(maxp, 16, 16, 16),
		function(_, _, remaining) if remaining == 0 then emerged = true end end)
	lib.wait_for(function() return emerged end, 120)
	lib.logf("arena %s - %s emerged in %.1f s", core.pos_to_string(minp),
		core.pos_to_string(maxp), (us() - t0) / 1e6)
	build()
	player:set_pos(player_spot(1))
	lib.wait(2)
	lib.logf("player level %d", grug_xp.get_level(player))
	cost_phase(lib)
	for _, spec in ipairs(TRIALS) do trial(lib, player, spec) end
	lib.log("RESULT DONE")
end
