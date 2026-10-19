-- Disposable engine probe (Round 52 lane AMB): never shipped;
-- tools/r52_amb/engine.sh stages it through tools/luanti_headless.sh with a
-- mode.lua beside this file that returns the mode:
--
--   "walk"   the per-player passes of grug_core/atmosphere_zones.lua and
--            grug_ambience on NFAKE player stand-ins (tables answering the
--            ObjectRef methods the passes call; each wrapped globalstep sees
--            only them and is timed; sounds are counted, not sent) through
--            four phases of PHASE seconds near the human start town:
--            surface (circles on the ground), mine (a dug shaft, a 1 x 2
--            tunnel with furnaces, torches and flowing water, a 3 x 3
--            corridor and a hall, at least 30 below the ground and below
--            y -30), tower (hovering 15-150 above the ground) and flight
--            (straight lines at 20 nodes/s at y 150). Logged per phase: the
--            ambience's figures (grug_ambience.stats), the passes'
--            microseconds, the depth helper's memo figures
--            (grug_core.depth_stats, absent before Round 52), sounds and
--            fades per player-minute. Works on the tree before Round 52 too
--            (the "before" numbers).
--   "calib"  the cave probe's calibration: standable spots in natural v7
--            caves in three boxes round the start town (y -110 to -12),
--            their open-air shares on four grid variants (the shipped one
--            first, also through grug_ambience.cave_share), a dug 1 x 2
--            tunnel, a 3 x 3 corridor and a hall on the same grids, the
--            probe's cost against a 9 x 5 x 9 find_nodes_in_area counting
--            air; then the peak heights: terrain and biome on a 32-node grid
--            over the world, per biome and per 256-node cell.
--   "shots"  for tools/r52_amb/capture.sh with one real client ("grugcap"):
--            the debug line on, the player frozen at each calibration case
--            (the ground, 60 up, the dug 1 x 2 tunnel, 3 x 3 corridor and
--            hall, a wide and a narrow natural cave of seed 12345) for
--            SHOT_WAIT seconds, then "SHOT <name>" and a wait for the
--            capture's ack in <world>/r52amb_ack.
-- Each mode ends with "RESULT DONE" and a shutdown.

local P = "[r52amb] "
local modpath = core.get_modpath(core.get_current_modname())
local MODE = dofile(modpath .. "/mode.lua")
local NFAKE = 16
local PHASE = 45
local SETTLE = 4

local function log(msg) core.log("action", P .. msg) end

-- ---------------------------------------------------------------- stand-ins
local fakes, fake_list = {}, {}
local function new_meta()
	local store = {["grug_factions:faction"] = "accord"}
	local m = {}
	function m:get(k) return store[k] end
	function m:get_string(k) return store[k] or "" end
	function m:set_string(k, v) store[k] = v ~= "" and v or nil end
	function m:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function m:set_int(k, v) store[k] = tostring(v) end
	function m:contains(k) return store[k] ~= nil end
	return m
end
local function make_fake(name, pos)
	local p = {_name = name, _pos = vector.copy(pos), _meta = new_meta(), _huds = 0}
	local M = {}
	function M:is_player() return true end
	function M:get_player_name() return self._name end
	function M:get_pos() return vector.copy(self._pos) end
	function M:get_meta() return self._meta end
	function M:get_hp() return 20 end
	function M:hud_add() self._huds = self._huds + 1 return self._huds end
	function M:hud_change() end
	function M:hud_remove() end
	function M:set_lighting() end
	function M:set_sky() end
	function M:set_clouds() end
	setmetatable(p, {__index = M})
	return p
end

local function from(fn, file)
	local info = debug.getinfo(fn, "S")
	return info and info.source and info.source:find(file, 1, true) ~= nil
end

local PASSES = {
	{key = "atmosphere_zones", file = "grug_core/atmosphere_zones.lua"},
	{key = "ambience", file = "grug_ambience/init.lua"},
}
local timing = {}
local sounds = {plays = 0, fades = 0, by_name = {}}

local function wrap(fn, key)
	timing[key] = {us = 0, calls = 0, max = 0}
	local t = timing[key]
	return function(dtime)
		local gcp, gpbn = core.get_connected_players, core.get_player_by_name
		local sp, sf, dam = core.sound_play, core.sound_fade, core.dynamic_add_media
		core.get_connected_players = function() return fake_list end
		core.get_player_by_name = function(name) return fakes[name] end
		core.sound_play = function(spec)
			sounds.plays = sounds.plays + 1
			local n = type(spec) == "table" and spec.name or tostring(spec)
			sounds.by_name[n] = (sounds.by_name[n] or 0) + 1
			return sounds.plays
		end
		core.sound_fade = function() sounds.fades = sounds.fades + 1 end
		core.dynamic_add_media = function(options, callback)
			callback(options.to_player)
			return true
		end
		local started = core.get_us_time()
		local ok, err = pcall(fn, dtime)
		local spent = core.get_us_time() - started
		t.us, t.calls = t.us + spent, t.calls + 1
		if spent > t.max then t.max = spent end
		core.get_connected_players, core.get_player_by_name = gcp, gpbn
		core.sound_play, core.sound_fade, core.dynamic_add_media = sp, sf, dam
		if not ok then error(err) end
	end
end

local function wrap_passes()
	for index, fn in ipairs(core.registered_globalsteps) do
		for _, pass in ipairs(PASSES) do
			if from(fn, pass.file) then core.registered_globalsteps[index] = wrap(fn, pass.key) end
		end
	end
end

local function join_fakes(center)
	local joins = {}
	for _, fn in ipairs(core.registered_on_joinplayers) do
		for _, pass in ipairs(PASSES) do
			if from(fn, pass.file) then joins[#joins + 1] = fn end
		end
	end
	for i = 1, NFAKE do
		local name = ("r52ambstub%02d"):format(i)
		local p = make_fake(name, center)
		fakes[name] = p
		fake_list[#fake_list + 1] = p
		for _, fn in ipairs(joins) do fn(p) end
	end
	log(("joined %d stand-ins to %d join hooks"):format(NFAKE, #joins))
end

local function reset_figures()
	for _, t in pairs(timing) do t.us, t.calls, t.max = 0, 0, 0 end
	local ambience = rawget(_G, "grug_ambience")
	if ambience then for k in pairs(ambience.stats) do ambience.stats[k] = 0 end end
	if grug_core.depth_stats then for k in pairs(grug_core.depth_stats) do grug_core.depth_stats[k] = 0 end end
	sounds.plays, sounds.fades, sounds.by_name = 0, 0, {}
end

local function report(phase, seconds)
	local total = 0
	for _, pass in ipairs(PASSES) do
		local t = timing[pass.key]
		if t then
			total = total + t.us
			log(("%s PASS %-17s %8.1f us/s  max step %6d us"):format(phase, pass.key, t.us / seconds, t.max))
		end
	end
	log(("%s PASSES total %.1f us/s for %d stand-ins (%.2f us/s per player)"):format(phase,
		total / seconds, NFAKE, total / seconds / NFAKE))
	local s = grug_ambience.stats
	local function per(a, b) return b > 0 and a / b or 0 end
	log(("%s ambience passes %d, %.1f us each; node searches %d, %.1f us each, %.1f positions; " ..
		"cave probes %s, %s us each"):format(phase, s.passes, per(s.us, s.passes), s.finds,
		per(s.find_us, s.finds), per(s.found, s.finds), tostring(s.probes or "-"),
		s.probes and ("%.1f"):format(per(s.probe_us, s.probes)) or "-"))
	local d = grug_core.depth_stats
	if d then
		log(("%s depth calls %d, memo hits %d (%.1f %%), column computations %d, %.1f us each"):format(
			phase, d.calls, d.hits, 100 * per(d.hits, d.calls), d.columns, per(d.us, d.columns)))
	else
		log(phase .. " depth helper absent (before Round 52)")
	end
	local names = {}
	for n, c in pairs(sounds.by_name) do names[#names + 1] = n .. "=" .. c end
	table.sort(names)
	local pm = seconds / 60 * NFAKE
	log(("%s sounds started %d (%.2f per player-minute), fades %d (%.2f): %s"):format(phase,
		sounds.plays, sounds.plays / pm, sounds.fades, sounds.fades / pm, table.concat(names, " ")))
end

-- ---------------------------------------------------------------- digging
local c_air
local function dig_box(vm_data, area, x0, y0, z0, x1, y1, z1)
	for z = z0, z1 do for y = y0, y1 do for x = x0, x1 do
		vm_data[area:index(x, y, z)] = c_air
	end end end
end

-- The mine: a 1 x 2 shaft from the ground down to `my`, a 1 x 2 tunnel 40
-- along +x, a 3 x 3 corridor 40 along +z, a 17 x 6 x 16 hall at its end.
local function dig_mine(site, ground, my, busy)
	c_air = core.get_content_id("air")
	local minp = {x = site.x - 10, y = my - 2, z = site.z - 4}
	local maxp = {x = site.x + 44, y = ground + 4, z = site.z + 60}
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(minp, maxp)
	local area = VoxelArea:new({MinEdge = e1, MaxEdge = e2})
	local data = vm:get_data()
	dig_box(data, area, site.x, my, site.z, site.x, ground + 2, site.z + 1)
	dig_box(data, area, site.x + 1, my, site.z, site.x + 40, my + 1, site.z)
	dig_box(data, area, site.x - 1, my, site.z + 2, site.x + 1, my + 2, site.z + 40)
	dig_box(data, area, site.x - 8, my, site.z + 41, site.x + 8, my + 5, site.z + 56)
	if busy then
		for _, dx in ipairs({10, 20, 30}) do
			dig_box(data, area, site.x + dx, my, site.z - 1, site.x + dx, my, site.z - 1)
		end
		dig_box(data, area, site.x + 15, my, site.z + 1, site.x + 15, my, site.z + 1)
	end
	vm:set_data(data)
	vm:write_to_map(true)
	if busy then
		for _, dx in ipairs({10, 20, 30}) do
			core.set_node({x = site.x + dx, y = my, z = site.z - 1}, {name = "default:furnace_active"})
		end
		for dx = 3, 39, 6 do core.set_node({x = site.x + dx, y = my + 1, z = site.z}, {name = "default:torch", param2 = 1}) end
		core.set_node({x = site.x + 15, y = my, z = site.z + 1}, {name = "default:water_source"})
		core.set_node({x = site.x, y = my, z = site.z + 48}, {name = "grug_nodes:camp_fire"})
	end
end

-- ---------------------------------------------------------------- shares
local open_air = {}
local function fill_open_air()
	for node, def in pairs(core.registered_nodes) do
		if node ~= "ignore" and def.walkable == false and (def.liquidtype or "none") == "none" then
			open_air[core.get_content_id(node)] = true
		end
	end
end
local VARIANTS = {
	{name = "V1 xz -4..4/2 y -1,1,3 (shipped)", xz = {-4, -2, 0, 2, 4}, y = {-1, 1, 3}},
	{name = "V2 xz -4..4/2 y 0,2,4", xz = {-4, -2, 0, 2, 4}, y = {0, 2, 4}},
	{name = "V3 xz -6..6/3 y -1,1,3", xz = {-6, -3, 0, 3, 6}, y = {-1, 1, 3}},
	{name = "V4 xz -6..6/3 y 0,2,4", xz = {-6, -3, 0, 3, 6}, y = {0, 2, 4}},
}
local get_node_raw = core.get_node_raw
local function share(v, pos)
	local x0, y0, z0 = math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5)
	local open, n = 0, 0
	for _, dy in ipairs(v.y) do
		for _, dx in ipairs(v.xz) do
			for _, dz in ipairs(v.xz) do
				n = n + 1
				if open_air[get_node_raw(x0 + dx, y0 + dy, z0 + dz)] then open = open + 1 end
			end
		end
	end
	return open / n
end

local function pct(sorted, q)
	if #sorted == 0 then return 0 end
	return sorted[math.max(1, math.min(#sorted, math.floor(q * #sorted + 0.5)))]
end

-- ---------------------------------------------------------------- driver
local state = {phase = "wait", t = 0, phase_t = 0}
local center, site, ground, my
local ring = {}
local emerge_left = 0

local WALK_PHASES = {"surface", "mine", "tower", "flight"}

local function place_walk(phase, t)
	for i, p in ipairs(fake_list) do
		if phase == "surface" then
			local r = ring[i]
			local k = math.floor(t * 4 / (2 * math.pi * r.radius) * #r.points) % #r.points + 1
			p._pos = r.points[k]
		elseif phase == "mine" then
			local along = (t * 4 + i * 5) % 80
			if along > 40 then along = 80 - along end
			if i % 2 == 0 then
				p._pos = {x = site.x + 1 + along * 39 / 40, y = my - 0.5, z = site.z}
			else
				p._pos = {x = site.x, y = my - 0.5, z = site.z + 2 + along * 54 / 40}
			end
		elseif phase == "tower" then
			local heights = {15, 25, 35, 50, 70, 90, 110, 150}
			local h = heights[(i - 1) % #heights + 1]
			local a = t * 0.3 + i
			p._pos = {x = site.x - 30 + 2 * math.cos(a), y = ground + h, z = site.z - 30 + 2 * math.sin(a)}
		else
			p._pos = {x = site.x - 600 + t * 20, y = 150, z = site.z - 800 + i * 100}
		end
	end
end

local function walk_step(dtime)
	if state.phase == "wait" then
		if state.t > 3 and grug_core.zone_authority_installed() then
			center = grug_core.start_position("accord", "human")
			if not center then return end
			site = {x = math.floor(center.x + 150), z = math.floor(center.z)}
			ground = grug_zones.terrain_height_at(site.x, site.z)
			my = math.min(ground - 30, -30)
			log(("center %s, mine site %d,%d ground %d, mine level %d"):format(core.pos_to_string(center),
				site.x, site.z, ground, my))
			for i = 1, NFAKE do
				local radius = 10 + i * 2
				local points = {}
				for k = 1, 64 do
					local a = k / 64 * 2 * math.pi
					local x, z = site.x - 60 + radius * math.cos(a), site.z - 60 + radius * math.sin(a)
					points[k] = {x = x, y = grug_zones.terrain_height_at(math.floor(x + 0.5),
						math.floor(z + 0.5)) + 0.5, z = z}
				end
				ring[i] = {radius = radius, points = points}
			end
			emerge_left = 1
			core.emerge_area({x = site.x - 120, y = my - 8, z = site.z - 120},
				{x = site.x + 60, y = ground + 8, z = site.z + 64}, function(_, _, remaining)
					if remaining == 0 then emerge_left = 0 end
				end)
			state.phase, state.phase_t = "emerge", 0
		end
	elseif state.phase == "emerge" then
		if emerge_left == 0 or state.phase_t > 150 then
			log(("emerge done=%s after %.1f s"):format(tostring(emerge_left == 0), state.phase_t))
			dig_mine(site, ground, my, true)
			wrap_passes()
			join_fakes({x = site.x, y = ground + 0.5, z = site.z})
			state.index = 1
			state.phase, state.phase_t = "settle", 0
		end
	elseif state.phase == "settle" then
		place_walk(WALK_PHASES[state.index], state.phase_t)
		if state.phase_t >= SETTLE then
			reset_figures()
			core.set_timeofday(0.5)
			state.phase, state.phase_t = "run", 0
		end
	elseif state.phase == "run" then
		local name = WALK_PHASES[state.index]
		place_walk(name, SETTLE + state.phase_t)
		if state.phase_t >= PHASE then
			report(name, state.phase_t)
			state.index = state.index + 1
			if WALK_PHASES[state.index] then
				state.phase, state.phase_t = "settle", 0
			else
				log("RESULT DONE")
				state.phase = "done"
				core.request_shutdown("r52 amb probe done", false, 0)
			end
		end
	end
end

-- ---------------------------------------------------------------- calibration
local boxes = {}
local spots = {}
local peaks = {}

local function survey(box)
	local found = core.find_nodes_in_area_under_air(box.minp, box.maxp,
		{"group:stone", "group:cracky", "group:crumbly"})
	local kept = 0
	for _, p in ipairs(found) do
		local feet = {x = p.x, y = p.y + 1, z = p.z}
		if open_air[get_node_raw(feet.x, feet.y + 1, feet.z)] then
			local pos = {x = p.x, y = p.y + 0.5, z = p.z}
			local depth = grug_core.depth_below_surface(pos)
			if depth and depth > 6 then
				spots[#spots + 1] = pos
				kept = kept + 1
			end
		end
	end
	log(("box %s..%s: %d floors under air, %d standable cave spots deeper than 6"):format(
		core.pos_to_string(box.minp), core.pos_to_string(box.maxp), #found, kept))
end

local function calib_report()
	-- every spot's share on every variant (at most 4000 spots, spread)
	local step = math.max(1, math.floor(#spots / 4000))
	local list = {}
	for i = 1, #spots, step do list[#list + 1] = spots[i] end
	log(("natural cave spots: %d (using %d)"):format(#spots, #list))
	local same = true
	for i = 1, math.min(#list, 300) do
		if math.abs(grug_ambience.cave_share(list[i]) - share(VARIANTS[1], list[i])) > 1e-9 then same = false end
	end
	log("shipped cave_share equals V1 on 300 spots: " .. tostring(same))
	-- dug structures in rock at the first box's centre, y -60
	local b = boxes[1]
	local ds = {x = math.floor((b.minp.x + b.maxp.x) / 2), z = math.floor((b.minp.z + b.maxp.z) / 2)}
	local dy = -60
	local before = {}
	for _, v in ipairs(VARIANTS) do before[#before + 1] = ("%.2f"):format(share(v, {x = ds.x + 20, y = dy - 0.5, z = ds.z})) end
	log("dig site " .. core.pos_to_string({x = ds.x, y = dy, z = ds.z}) .. " shares before digging (tunnel middle): " ..
		table.concat(before, " "))
	dig_mine(ds, dy + 2, dy, false)
	local cases = {
		{"tunnel 1x2 middle", {x = ds.x + 20, z = ds.z}},
		{"tunnel 1x2 near end", {x = ds.x + 38, z = ds.z}},
		{"tunnel 1x2 at shaft", {x = ds.x + 1, z = ds.z}},
		{"corridor 3x3 middle", {x = ds.x, z = ds.z + 20}},
		{"corridor 3x3 near start", {x = ds.x, z = ds.z + 4}},
		{"corridor 3x3 near hall", {x = ds.x, z = ds.z + 38}},
		{"hall centre", {x = ds.x, z = ds.z + 48}},
		{"hall near wall", {x = ds.x + 7, z = ds.z + 48}},
		{"hall corner", {x = ds.x + 7, z = ds.z + 55}},
	}
	for vi, v in ipairs(VARIANTS) do
		local row = {}
		local tunnel_max = 0
		for _, c in ipairs(cases) do
			local s = share(v, {x = c[2].x, y = dy - 0.5, z = c[2].z})
			row[#row + 1] = ("%s=%.2f"):format(c[1], s)
			if not c[1]:find("hall", 1, true) and s > tunnel_max then tunnel_max = s end
		end
		log(v.name .. " DUG " .. table.concat(row, ", "))
		local values = {}
		for _, pos in ipairs(list) do values[#values + 1] = share(v, pos) end
		table.sort(values)
		local function above(th)
			local n = 0
			for _, s in ipairs(values) do if s >= th then n = n + 1 end end
			return #values > 0 and 100 * n / #values or 0
		end
		log(("%s NATURAL p05 %.2f p10 %.2f p25 %.2f p50 %.2f p75 %.2f p90 %.2f; spots >= 0.15 %.0f %%, " ..
			">= 0.20 %.0f %%, >= 0.25 %.0f %%, >= 0.30 %.0f %%, > dug tunnel/corridor max %.2f: %.0f %%"):format(
			v.name, pct(values, 0.05), pct(values, 0.10), pct(values, 0.25), pct(values, 0.5),
			pct(values, 0.75), pct(values, 0.9), above(0.15), above(0.2), above(0.25), above(0.3),
			tunnel_max, above(tunnel_max + 1e-6)))
		if vi == 1 then
			-- a histogram of the shipped grid, tenths
			local hist = {}
			for k = 0, 10 do hist[k] = 0 end
			for _, s in ipairs(values) do local k = math.floor(s * 10) hist[k] = hist[k] + 1 end
			local h = {}
			for k = 0, 10 do h[#h + 1] = ("%d0%%:%d"):format(k, hist[k]) end
			log("V1 histogram " .. table.concat(h, " "))
		end
	end
	-- spots for the screenshots: a wide natural cave and a narrow one
	local best, narrow
	for _, pos in ipairs(list) do
		local s = share(VARIANTS[1], pos)
		if not best or s > best.s then best = {pos = pos, s = s} end
		if s > 0.08 and s < 0.16 and not narrow then narrow = {pos = pos, s = s} end
	end
	if best then log(("SPOT wide cave %s share %.2f"):format(core.pos_to_string(best.pos), best.s)) end
	if narrow then log(("SPOT narrow cave %s share %.2f"):format(core.pos_to_string(narrow.pos), narrow.s)) end
	log(("SPOT dug site %s level %d"):format(core.pos_to_string({x = ds.x, y = dy, z = ds.z}), dy))
	-- cost: the sampled probe against a 9 x 5 x 9 search counting air
	local n = math.min(#list, 1000)
	local t0 = core.get_us_time()
	local sink = 0
	for i = 1, n do sink = sink + grug_ambience.cave_share(list[i]) end
	local t1 = core.get_us_time()
	for i = 1, n do
		local p = list[i]
		local _, counts = core.find_nodes_in_area({x = p.x - 4, y = p.y - 1.5, z = p.z - 4},
			{x = p.x + 4, y = p.y + 3.5, z = p.z + 4}, {"air"})
		sink = sink + (counts.air or 0)
	end
	local t2 = core.get_us_time()
	log(("COST on %d spots: sampled probe (75 get_node_raw) %.2f us each; find_nodes_in_area 9x5x9 air " ..
		"%.2f us each (sink %d)"):format(n, (t1 - t0) / math.max(1, n), (t2 - t1) / math.max(1, n), sink))
end

local PEAK_STEP, CELL = 32, 256
local MINX, MAXX, MINZ, MAXZ = -4190, 4190, -3740, 3740
local function peaks_step()
	local budget = 1500
	while budget > 0 and peaks.x <= MAXX do
		local x, z = peaks.x, peaks.z
		local h = grug_zones.terrain_height_at(x, z)
		local b = grug_zones.biome_at(x, z)
		if b then
			local list = peaks.by_biome[b] or {}
			peaks.by_biome[b] = list
			list[#list + 1] = h
			local key = math.floor((x - MINX) / CELL) .. ":" .. math.floor((z - MINZ) / CELL)
			local cell = peaks.cells[key]
			if not cell or h > cell.h then peaks.cells[key] = {h = h, b = b} end
		end
		peaks.n = peaks.n + 1
		peaks.z = peaks.z + PEAK_STEP
		if peaks.z > MAXZ then peaks.z, peaks.x = MINZ, peaks.x + PEAK_STEP end
		budget = budget - 1
	end
	return peaks.x > MAXX
end

local function peaks_report()
	log(("PEAKS %d samples in %.1f s"):format(peaks.n, peaks.seconds))
	local ids = {}
	for b in pairs(peaks.by_biome) do ids[#ids + 1] = b end
	table.sort(ids)
	for _, b in ipairs(ids) do
		local l = peaks.by_biome[b]
		table.sort(l)
		log(("PEAKS biome %-20s n %6d p50 %4d p90 %4d p99 %4d max %4d"):format(b, #l, pct(l, 0.5),
			pct(l, 0.9), pct(l, 0.99), l[#l]))
	end
	local tops = {}
	for _, cell in pairs(peaks.cells) do
		if cell.b == "grug_crags_snowy" or cell.b == "grug_crags" or cell.b == "grug_pine_hills" then
			tops[#tops + 1] = cell.h
		end
	end
	table.sort(tops)
	log(("PEAKS 256-node cells whose highest sample is crags, snowy crags or pine hills: %d; their tops " ..
		"p25 %d p50 %d p75 %d p90 %d max %d"):format(#tops, pct(tops, 0.25), pct(tops, 0.5), pct(tops, 0.75),
		pct(tops, 0.9), tops[#tops] or 0))
	for _, id in ipairs({"grug_crags_snowy", "grug_crags", "grug_pine_hills"}) do
		local t = {}
		for _, cell in pairs(peaks.cells) do if cell.b == id then t[#t + 1] = cell.h end end
		table.sort(t)
		log(("PEAKS cell tops %-18s cells %3d p50 %d p75 %d p90 %d max %d"):format(id, #t, pct(t, 0.5),
			pct(t, 0.75), pct(t, 0.9), t[#t] or 0))
	end
end

local function calib_step()
	if state.phase == "wait" then
		if state.t > 3 and grug_core.zone_authority_installed() then
			fill_open_air()
			center = grug_core.start_position("accord", "human")
			if not center then return end
			log("center " .. core.pos_to_string(center))
			for _, off in ipairs({{300, 0}, {-300, 0}, {0, 300}}) do
				local cx, cz = math.floor(center.x + off[1]), math.floor(center.z + off[2])
				boxes[#boxes + 1] = {minp = {x = cx - 64, y = -110, z = cz - 64},
					maxp = {x = cx + 64, y = -12, z = cz + 64}}
			end
			emerge_left = #boxes
			for _, b in ipairs(boxes) do
				core.emerge_area(b.minp, b.maxp, function(_, _, remaining)
					if remaining == 0 then emerge_left = emerge_left - 1 end
				end)
			end
			state.phase, state.phase_t = "emerge", 0
		end
	elseif state.phase == "emerge" then
		if emerge_left == 0 or state.phase_t > 180 then
			log(("emerge done=%s after %.1f s"):format(tostring(emerge_left == 0), state.phase_t))
			for _, b in ipairs(boxes) do survey(b) end
			calib_report()
			peaks.x, peaks.z, peaks.n, peaks.by_biome, peaks.cells = MINX, MINZ, 0, {}, {}
			peaks.started = core.get_us_time()
			state.phase, state.phase_t = "peaks", 0
		end
	elseif state.phase == "peaks" then
		if peaks_step() then
			peaks.seconds = (core.get_us_time() - peaks.started) / 1e6
			peaks_report()
			log("RESULT DONE")
			state.phase = "done"
			core.request_shutdown("r52 amb probe done", false, 0)
		end
	end
end

-- ---------------------------------------------------------------- shots
local NAME = "grugcap"
local SHOT_WAIT = 12
-- The calibration's dig site and natural spots (engine.sh calib, seed 12345).
local DIG = {x = 300, z = -2550}
local DIG_Y = -60
local function cases()
	local start = grug_core.start_position("accord", "human")
	local g = grug_zones.terrain_height_at(math.floor(start.x + 0.5), math.floor(start.z + 0.5))
	return {
		{name = "A_surface", pos = {x = start.x, y = g + 0.5, z = start.z}, yaw = 0},
		{name = "B_up_60", pos = {x = start.x, y = g + 60.5, z = start.z}, yaw = 0},
		{name = "C_dug_tunnel_1x2", pos = {x = DIG.x + 20, y = DIG_Y - 0.5, z = DIG.z}, yaw = -math.pi / 2},
		{name = "D_dug_corridor_3x3", pos = {x = DIG.x, y = DIG_Y - 0.5, z = DIG.z + 20}, yaw = 0},
		{name = "E_dug_hall", pos = {x = DIG.x, y = DIG_Y - 0.5, z = DIG.z + 48}, yaw = 0},
		{name = "F_cave_wide", pos = {x = -24, y = -77.5, z = -2288}, yaw = 0},
		{name = "G_cave_narrow", pos = {x = 244, y = -85.5, z = -2565}, yaw = 0},
	}
end

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r52amb_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local shot_list
local function shots_step(dtime)
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, {faction_accord = "Accord"})
			submit(player, {race_human = "Human"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		shot_list = cases()
		emerge_left = #shot_list
		for _, c in ipairs(shot_list) do
			core.emerge_area(vector.subtract(c.pos, 16), vector.add(c.pos, 16), function(_, _, remaining)
				if remaining == 0 then emerge_left = emerge_left - 1 end
			end)
		end
		core.emerge_area({x = DIG.x - 12, y = DIG_Y - 4, z = DIG.z - 6}, {x = DIG.x + 46, y = DIG_Y + 8,
			z = DIG.z + 62}, function(_, _, remaining)
				if remaining == 0 then state.dig_ready = true end
			end)
		state.phase, state.phase_t = "emerge", 0
	elseif state.phase == "emerge" then
		if (emerge_left == 0 and state.dig_ready) or state.phase_t > 120 then
			dig_mine(DIG, DIG_Y + 2, DIG_Y, false)
			core.registered_chatcommands.ambience.func(NAME, "debug")
			core.set_timeofday(0.5)
			state.shot, state.phase, state.phase_t, state.logged = 1, "shoot", 0, false
			log("READY")
		end
	elseif state.phase == "shoot" then
		local c = shot_list[state.shot]
		if not c then
			log("RESULT DONE")
			log("shutdown")
			state.phase = "done"
			core.request_shutdown("r52 amb probe done", false, 0)
			return
		end
		if state.phase_t < 0.5 or not state.placed then
			player:set_pos(c.pos)
			player:set_look_horizontal(c.yaw)
			player:set_look_vertical(0)
			state.placed = true
		end
		if not state.logged and state.phase_t >= SHOT_WAIT then
			state.logged = true
			log(("SHOT %s at %s"):format(c.name, core.pos_to_string(c.pos)))
		elseif state.logged and read_ack() == c.name then
			state.shot, state.phase_t, state.logged, state.placed = state.shot + 1, 0, false, false
		end
	end
end

core.register_globalstep(function(dtime)
	state.t = state.t + dtime
	state.phase_t = state.phase_t + dtime
	if MODE == "walk" then walk_step(dtime)
	elseif MODE == "shots" then shots_step(dtime)
	else calib_step() end
end)
