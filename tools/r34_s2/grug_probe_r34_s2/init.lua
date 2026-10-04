-- Disposable engine probe (Round 34 lane S2): the per-player passes with
-- player stand-ins on the real world of a seed. Never shipped:
-- tools/r34_s2/engine.sh stages it through tools/luanti_headless.sh.
--
-- NFAKE stand-ins (tables answering the ObjectRef methods the passes call)
-- join ONLY the per-player passes of grug_core/atmosphere_zones.lua,
-- grug_map/location.lua and, when present, grug_ambience; each of those
-- globalsteps is wrapped to see only the stand-ins and timed. The
-- stand-ins walk circles of 8-68 nodes round the Dawnmere start town for
-- RUN seconds (half of it at night). Inside the ambience pass the sound
-- calls and the music push are counted, not sent (no client exists); a push
-- is "delivered" at once so the play path runs. Every name of
-- grug_ambience's data is marked shipped, so the run plays what the shipped
-- game would. Logged: microseconds per second of each pass and per player
-- evaluation, the node searches, sounds started and pushes per player and
-- minute. With grug_ambience present it then counts flowing water (the
-- nodes the water loop hangs on) in eight sample regions (the six start
-- towns and six lowland and wetland zone hubs, y -10 to 60) after the
-- liquids had 20 s to settle: nodes, sources, and the share of 16 x 16
-- columns holding flowing water. Then the server shuts down. With the
-- setting r34s2_census_only = true only the census runs.

local P = "[r34s2_probe] "
local NFAKE = tonumber(core.settings:get("r34s2_fakes") or "") or 40
local RUN = 120
local SETTLE = 5

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

-- ---------------------------------------------------------------- wrapping
local PASSES = {
	{key = "atmosphere_zones", file = "grug_core/atmosphere_zones.lua"},
	{key = "location", file = "grug_map/location.lua"},
	{key = "ambience", file = "grug_ambience/init.lua"},
}
local timing = {}
local sound_counts = {plays = 0, fades = 0, pushes = 0, by_name = {}}

local function wrap(fn, key)
	timing[key] = {us = 0, calls = 0, max = 0}
	local t = timing[key]
	return function(dtime)
		local gcp, gpbn, gpwi = core.get_connected_players, core.get_player_by_name,
			core.get_player_window_information
		local sp, sf, dam = core.sound_play, core.sound_fade, core.dynamic_add_media
		core.get_connected_players = function() return fake_list end
		core.get_player_by_name = function(name) return fakes[name] end
		core.get_player_window_information = function()
			return {size = {x = 1920, y = 1080}, real_gui_scaling = 1, real_hud_scaling = 1}
		end
		core.sound_play = function(spec)
			sound_counts.plays = sound_counts.plays + 1
			local n = type(spec) == "table" and spec.name or tostring(spec)
			sound_counts.by_name[n] = (sound_counts.by_name[n] or 0) + 1
			return sound_counts.plays
		end
		core.sound_fade = function() sound_counts.fades = sound_counts.fades + 1 end
		core.dynamic_add_media = function(options, callback)
			sound_counts.pushes = sound_counts.pushes + 1
			callback(options.to_player)
			return true
		end
		local started = core.get_us_time()
		local ok, err = pcall(fn, dtime)
		local spent = core.get_us_time() - started
		t.us, t.calls = t.us + spent, t.calls + 1
		if spent > t.max then t.max = spent end
		core.get_connected_players, core.get_player_by_name = gcp, gpbn
		core.get_player_window_information = gpwi
		core.sound_play, core.sound_fade, core.dynamic_add_media = sp, sf, dam
		if not ok then error(err) end
	end
end

local function wrap_passes()
	for index, fn in ipairs(core.registered_globalsteps) do
		for _, pass in ipairs(PASSES) do
			if from(fn, pass.file) then
				core.registered_globalsteps[index] = wrap(fn, pass.key)
			end
		end
	end
end

local function join_fakes(center)
	local ambience = rawget(_G, "grug_ambience")
	if ambience then
		-- Every data name shipped: the run plays what the shipped game would.
		local D = ambience.data
		for _, names in pairs(D.beds) do
			for _, n in ipairs(names) do ambience.available[n] = true end
		end
		for _, call in pairs(D.calls) do ambience.available[call.sound] = true end
		for _, e in pairs(D.emitters) do ambience.available[e.sound] = true end
		for group, list in pairs(D.pools) do
			local pool = ambience.pools[group]
			for i = #pool, 1, -1 do pool[i] = nil end
			for i, id in ipairs(list) do pool[i] = id end
		end
	end
	local joins = {}
	for _, fn in ipairs(core.registered_on_joinplayers) do
		for _, pass in ipairs(PASSES) do
			if from(fn, pass.file) then joins[#joins + 1] = fn end
		end
	end
	for i = 1, NFAKE do
		local name = ("r34s2stub%02d"):format(i)
		local p = make_fake(name, center)
		fakes[name] = p
		fake_list[#fake_list + 1] = p
		for _, fn in ipairs(joins) do fn(p) end
	end
	log(("joined %d stand-ins to %d join hooks"):format(NFAKE, #joins))
end

-- ---------------------------------------------------------------- driver
local state = {phase = "wait", t = 0, phase_t = 0}
local center, emerge_done

local function move_fakes()
	for i, p in ipairs(fake_list) do
		local r = 8 + (i % 20) * 3
		local angle = i * 0.7 + state.t * 1.5 / r
		p._pos = {x = center.x + r * math.cos(angle), y = center.y + (i % 3),
			z = center.z + r * math.sin(angle)}
	end
end

-- ---------------------------------------------------------------- census
local CENSUS_HALF, CENSUS_Y0, CENSUS_Y1 = 64, -10, 60
local CENSUS_ONLY = core.settings:get_bool("r34s2_census_only", false)
-- Zone hubs (simple_map.lua) of lowland and wetland zones, where rivers and
-- lakes are likeliest, besides the six start towns.
local HUBS = {
	{"goldmead_vale", 0, -2050}, {"whitebridge_shire", -900, -1500},
	{"moonfall_wood", 2400, -1500}, {"mournfen", -1800, 2050},
	{"whispering_reedlands", 900, 1500}, {"totemwater_reach", 2400, 1500},
}
local census = {}

local function census_start()
	local list = {}
	for _, row in ipairs(grug_core.start_identities()) do
		local c = grug_core.start_position(row.faction_id, row.race_id)
		if c then list[#list + 1] = {row.race_id .. "_start", c.x, c.z} end
	end
	for _, h in ipairs(HUBS) do list[#list + 1] = h end
	for _, h in ipairs(list) do
		local r = {name = h[1], c = {x = h[2], y = 0, z = h[3]}, done = false}
		census[#census + 1] = r
		core.emerge_area({x = h[2] - CENSUS_HALF, y = CENSUS_Y0, z = h[3] - CENSUS_HALF},
			{x = h[2] + CENSUS_HALF - 1, y = CENSUS_Y1, z = h[3] + CENSUS_HALF - 1},
			function(_, _, remaining) if remaining == 0 then r.done = true end end)
	end
end

local function census_report()
	local flowing = {"default:water_flowing", "default:river_water_flowing"}
	local sources = {"default:water_source", "default:river_water_source"}
	local total_cells, wet_cells, total_flowing = 0, 0, 0
	for _, r in ipairs(census) do
		local c = r.c
		local minp = {x = c.x - CENSUS_HALF, y = CENSUS_Y0, z = c.z - CENSUS_HALF}
		local maxp = {x = c.x + CENSUS_HALF - 1, y = CENSUS_Y1, z = c.z + CENSUS_HALF - 1}
		local fpos, fcount = core.find_nodes_in_area(minp, maxp, flowing)
		local _, scount = core.find_nodes_in_area(minp, maxp, sources)
		local cells = {}
		for _, p in ipairs(fpos) do
			cells[math.floor((p.x - minp.x) / 16) .. ":" .. math.floor((p.z - minp.z) / 16)] = true
		end
		local wet = 0
		for _ in pairs(cells) do wet = wet + 1 end
		local n = (2 * CENSUS_HALF / 16) * (2 * CENSUS_HALF / 16)
		total_cells, wet_cells, total_flowing = total_cells + n, wet_cells + wet, total_flowing + #fpos
		-- The ambience node search where the water loop matters: at up to 20
		-- flowing nodes of the region, as a player standing there would run it.
		local ambience = rawget(_G, "grug_ambience")
		if ambience and #fpos > 0 then
			local D, R = ambience.data, ambience.rules
			local names, kinds = {}, {}
			for node, kind in pairs(D.emitter_nodes) do names[#names + 1] = node; kinds[node] = kind end
			local limits = {}
			for kind, spec in pairs(D.emitters) do limits[kind] = spec.limit end
			local reach = D.emitter_reach
			local us, got, n_at = 0, 0, 0
			for i = 1, #fpos, math.max(1, math.floor(#fpos / 20)) do
				local p = fpos[i]
				local t = core.get_us_time()
				local found = core.find_nodes_in_area(vector.subtract(p, reach), vector.add(p, reach), names, true)
				local rows = R.choose_emitters(found, kinds, p, limits, {}, core.hash_node_position)
				us = us + core.get_us_time() - t
				for _, list in pairs(found) do got = got + #list end
				n_at = n_at + 1
				r.chosen = #rows
			end
			log(("CENSUS %-22s node search + choice at %d flowing nodes: %.1f us each, %.1f positions returned each"):format(
				r.name, n_at, us / n_at, got / n_at))
		end
		log(("CENSUS %-22s %s emerged=%s flowing water %d, flowing river water %d, sources %d + %d; " ..
			"16x16 columns with flowing water %d of %d"):format(r.name, core.pos_to_string(c),
			tostring(r.done), fcount["default:water_flowing"] or 0,
			fcount["default:river_water_flowing"] or 0, scount["default:water_source"] or 0,
			scount["default:river_water_source"] or 0, wet, n))
	end
	log(("CENSUS total flowing %d in %d regions of %dx%dx%d; %d of %d 16x16 columns (%.1f %%)"):format(
		total_flowing, #census, 2 * CENSUS_HALF, CENSUS_Y1 - CENSUS_Y0 + 1, 2 * CENSUS_HALF,
		wet_cells, total_cells, total_cells > 0 and 100 * wet_cells / total_cells or 0))
end

local function report()
	local seconds = state.phase_t
	local total = 0
	for _, pass in ipairs(PASSES) do
		local t = timing[pass.key]
		if t then
			total = total + t.us
			log(("PASS %-17s %8.1f us/s  steps=%5d  max step %6d us"):format(pass.key,
				t.us / seconds, t.calls, t.max))
		else
			log(("PASS %-17s absent"):format(pass.key))
		end
	end
	log(("PASSES total %.1f us/s for %d stand-ins (%.2f us/s per player)"):format(
		total / seconds, NFAKE, total / seconds / NFAKE))
	local loc = grug_map.location.stats
	log(("location samples %d, %.1f us each"):format(loc.samples,
		loc.samples > 0 and loc.us / loc.samples or 0))
	local ambience = rawget(_G, "grug_ambience")
	if ambience then
		local s = ambience.stats
		log(("ambience evaluations %d, %.1f us each; node searches %d, %.1f us each, " ..
			"%.1f positions returned each"):format(
			s.passes, s.passes > 0 and s.us / s.passes or 0, s.finds,
			s.finds > 0 and s.find_us / s.finds or 0, s.finds > 0 and s.found / s.finds or 0))
		local names = {}
		for n, c in pairs(sound_counts.by_name) do names[#names + 1] = n .. "=" .. c end
		table.sort(names)
		log("ambience sounds by name: " .. table.concat(names, " "))
		local per = seconds / 60 * NFAKE
		log(("ambience sounds started %d (%.2f per player-minute), fades %d (%.2f), " ..
			"pushes %d (%.2f)"):format(sound_counts.plays, sound_counts.plays / per,
			sound_counts.fades, sound_counts.fades / per, sound_counts.pushes,
			sound_counts.pushes / per))
	end
end

core.register_globalstep(function(dtime)
	state.t = state.t + dtime
	state.phase_t = state.phase_t + dtime
	if state.phase == "wait" then
		if state.t > 3 and grug_core.zone_authority_installed() then
			center = grug_core.start_position("accord", "human")
			if not center then return end
			log("center " .. core.pos_to_string(center))
			core.emerge_area(vector.subtract(center, {x = 80, y = 24, z = 80}),
				vector.add(center, {x = 80, y = 24, z = 80}), function(_, _, remaining)
					if remaining == 0 then emerge_done = true end
				end)
			state.phase, state.phase_t = "emerge", 0
		end
	elseif state.phase == "emerge" then
		if CENSUS_ONLY then
			census_start()
			state.phase, state.phase_t = "census", 0
		elseif emerge_done or state.phase_t > 120 then
			log(("emerge done=%s after %.1f s"):format(tostring(emerge_done), state.phase_t))
			wrap_passes()
			join_fakes(center)
			move_fakes()
			state.phase, state.phase_t = "settle", 0
		end
	elseif state.phase == "settle" then
		move_fakes()
		if state.phase_t >= SETTLE then
			for _, t in pairs(timing) do t.us, t.calls, t.max = 0, 0, 0 end
			local ambience = rawget(_G, "grug_ambience")
			if ambience then
				for k in pairs(ambience.stats) do ambience.stats[k] = 0 end
			end
			grug_map.location.stats.samples, grug_map.location.stats.us = 0, 0
			sound_counts.plays, sound_counts.fades, sound_counts.pushes = 0, 0, 0
			core.set_timeofday(0.5)
			state.phase, state.phase_t = "run", 0
		end
	elseif state.phase == "run" then
		move_fakes()
		if state.phase_t >= RUN / 2 and not state.night then
			state.night = true
			core.set_timeofday(0.9)
		end
		if state.phase_t >= RUN then
			report()
			if rawget(_G, "grug_ambience") then
				census_start()
				state.phase, state.phase_t = "census", 0
			else
				log("RESULT DONE")
				state.phase = "done"
				core.request_shutdown("r34 s2 probe done", false, 0)
			end
		end
	elseif state.phase == "census" then
		local all = true
		for _, r in ipairs(census) do all = all and r.done end
		if (all and not state.settle_at) then state.settle_at = state.phase_t end
		if (state.settle_at and state.phase_t >= state.settle_at + 20) or state.phase_t > 200 then
			census_report()
			log("RESULT DONE")
			state.phase = "done"
			core.request_shutdown("r34 s2 probe done", false, 0)
		end
	end
end)
