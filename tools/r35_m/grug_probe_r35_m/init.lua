-- Disposable engine probe (Round 35 lane M): the per-player passes of
-- grug_core/atmosphere_zones.lua (the mood the beds follow),
-- grug_map/location.lua and grug_ambience with player stand-ins on the real
-- world of a seed, first round the human start town (Dawnmere), then round
-- the human capital (Highcourt). Never shipped: tools/r35_m/engine.sh stages
-- it through tools/luanti_headless.sh. Pattern of tools/r34_s2's probe.
--
-- NFAKE stand-ins (tables answering the ObjectRef methods the passes call)
-- join only those three passes; each pass's globalstep is wrapped to see only
-- the stand-ins and timed. Per phase (RUN seconds, half of it at night): in
-- the start town every stand-in walks a circle of 8-68 nodes; in the capital
-- three in four do the same, every fourth walks to and fro across the city
-- border (24 nodes either side, on its own ray; the border is where the
-- city's hard footprint ends), so entering and leaving run.
-- Inside the ambience pass the sound calls and pushes are counted, not sent
-- (no client exists); a push is "delivered" at once so the play path runs.
-- Every name of grug_ambience's data is marked shipped. Logged per phase:
-- microseconds per second of each pass, ambience evaluations, location
-- samples, music pushes, music and bed plays, fades.

local P = "[r35m_probe] "
local NFAKE = tonumber(core.settings:get("r35m_fakes") or "") or 40
local RUN = 60
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
	{key = "atmosphere", file = "grug_core/atmosphere_zones.lua"},
	{key = "location", file = "grug_map/location.lua"},
	{key = "ambience", file = "grug_ambience/init.lua"},
}
local timing = {}
local counts = {}
local function reset_counts()
	counts.music_plays, counts.bed_plays, counts.other_plays = 0, 0, 0
	counts.fades, counts.pushes = 0, 0
end
reset_counts()

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
		core.sound_play = function(spec, params)
			local n = type(spec) == "table" and spec.name or tostring(spec)
			if n:find("^grug_music_") then
				counts.music_plays = counts.music_plays + 1
			elseif params and params.loop and not params.pos then
				counts.bed_plays = counts.bed_plays + 1
			else
				counts.other_plays = counts.other_plays + 1
			end
			return counts.music_plays + counts.bed_plays + counts.other_plays
		end
		core.sound_fade = function() counts.fades = counts.fades + 1 end
		core.dynamic_add_media = function(options, callback)
			counts.pushes = counts.pushes + 1
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

-- Every data name shipped, so the run plays what the shipped game would.
local function mark_shipped()
	local ambience = rawget(_G, "grug_ambience")
	if not ambience then return end
	local D = ambience.data
	for _, names in pairs(D.beds) do
		for _, n in ipairs(names) do ambience.available[n] = true end
	end
	for _, call in pairs(D.calls) do ambience.available[call.sound] = true end
	for _, e in pairs(D.emitters) do ambience.available[e.sound] = true end
	-- Round 34: pools by group; Round 35: one rotation per capital.
	for _, field in ipairs({"pools", "rotations"}) do
		local source, shipped = D[field], ambience[field]
		if type(source) == "table" and type(shipped) == "table" then
			for key, list in pairs(source) do
				local row = shipped[key] or {}
				shipped[key] = row
				for i = #row, 1, -1 do row[i] = nil end
				for i, id in ipairs(list) do row[i] = id end
			end
		end
	end
end

local function join_fakes(center)
	mark_shipped()
	local joins = {}
	for _, fn in ipairs(core.registered_on_joinplayers) do
		for _, pass in ipairs(PASSES) do
			if from(fn, pass.file) then joins[#joins + 1] = fn end
		end
	end
	for i = 1, NFAKE do
		local name = ("r35mstub%02d"):format(i)
		local p = make_fake(name, center)
		fakes[name] = p
		fake_list[#fake_list + 1] = p
		for _, fn in ipairs(joins) do fn(p) end
	end
	log(("joined %d stand-ins to %d join hooks"):format(NFAKE, #joins))
end

-- ---------------------------------------------------------------- driver
local state = {phase = "wait", t = 0, phase_t = 0}
local center, emerge_done, border

-- The city border along eight rays from the capital anchor: the first
-- distance (2-node steps) whose column is outside the city's hard footprint
-- (the capital's zone carries the city's name too, so the text cannot tell).
local function find_border(anchor)
	local name = grug_map.location.text_at(anchor)
	local id = grug_zones.hard_footprint_in(anchor.x, anchor.z, anchor.x, anchor.z)
	local rays = {}
	for k = 0, 7 do
		local a = k * math.pi / 4 + 0.3
		local dx, dz = math.cos(a), math.sin(a)
		local r = 0
		while r < 400 do
			local x, z = math.floor(anchor.x + dx * r + 0.5), math.floor(anchor.z + dz * r + 0.5)
			if grug_zones.hard_footprint_in(x, z, x, z) ~= id then break end
			r = r + 2
		end
		rays[#rays + 1] = {dx = dx, dz = dz, r = r}
	end
	local text = {}
	for _, ray in ipairs(rays) do text[#text + 1] = tostring(ray.r) end
	log(("capital %s border radii %s"):format(name, table.concat(text, " ")))
	return rays
end

local function move_fakes()
	for i, p in ipairs(fake_list) do
		if border and i % 4 == 0 then
			local ray = border[(i / 4) % #border + 1]
			local r = ray.r + 24 * math.sin(state.t * 0.12 + i)
			p._pos = {x = center.x + ray.dx * r, y = center.y + 1, z = center.z + ray.dz * r}
		else
			local r = 8 + (i % 20) * 3
			local angle = i * 0.7 + state.t * 1.5 / r
			p._pos = {x = center.x + r * math.cos(angle), y = center.y + (i % 3),
				z = center.z + r * math.sin(angle)}
		end
	end
end

local function report(label)
	local seconds = state.phase_t
	local total = 0
	for _, pass in ipairs(PASSES) do
		local t = timing[pass.key]
		if t then
			total = total + t.us
			log(("%s PASS %-9s %8.1f us/s  steps=%5d  max step %6d us"):format(label,
				pass.key, t.us / seconds, t.calls, t.max))
		else
			log(("%s PASS %-9s absent"):format(label, pass.key))
		end
	end
	log(("%s PASSES total %.1f us/s for %d stand-ins (%.2f us/s per player)"):format(
		label, total / seconds, NFAKE, total / seconds / NFAKE))
	local loc = grug_map.location.stats
	log(("%s location samples %d, %.1f us each"):format(label, loc.samples,
		loc.samples > 0 and loc.us / loc.samples or 0))
	local ambience = rawget(_G, "grug_ambience")
	if ambience then
		local s = ambience.stats
		log(("%s ambience evaluations %d, %.1f us each; node searches %d, %.1f us each"):format(
			label, s.passes, s.passes > 0 and s.us / s.passes or 0, s.finds,
			s.finds > 0 and s.find_us / s.finds or 0))
		log(("%s sounds: music plays %d, music pushes %d, bed plays %d, other plays %d, fades %d"):format(
			label, counts.music_plays, counts.pushes, counts.bed_plays, counts.other_plays,
			counts.fades))
	end
end

local function reset_measure()
	for _, t in pairs(timing) do t.us, t.calls, t.max = 0, 0, 0 end
	local ambience = rawget(_G, "grug_ambience")
	if ambience then
		for k in pairs(ambience.stats) do ambience.stats[k] = 0 end
	end
	grug_map.location.stats.samples, grug_map.location.stats.us = 0, 0
	reset_counts()
end

local function emerge(pos)
	emerge_done = false
	core.emerge_area(vector.subtract(pos, {x = 48, y = 16, z = 48}),
		vector.add(pos, {x = 48, y = 16, z = 48}), function(_, _, remaining)
			if remaining == 0 then emerge_done = true end
		end)
end

core.register_globalstep(function(dtime)
	state.t = state.t + dtime
	state.phase_t = state.phase_t + dtime
	if state.phase == "wait" then
		if state.t > 3 and grug_core.zone_authority_installed() then
			center = grug_core.start_position("accord", "human")
			if not center then return end
			log("start center " .. core.pos_to_string(center))
			emerge(center)
			state.phase, state.phase_t = "emerge", 0
		end
	elseif state.phase == "emerge" or state.phase == "emerge2" then
		if emerge_done or state.phase_t > 60 then
			log(("emerge done=%s after %.1f s"):format(tostring(emerge_done), state.phase_t))
			if state.phase == "emerge" then
				wrap_passes()
				join_fakes(center)
			end
			move_fakes()
			state.phase, state.phase_t = state.phase == "emerge" and "settle" or "settle2", 0
		end
	elseif state.phase == "settle" or state.phase == "settle2" then
		move_fakes()
		if state.phase_t >= SETTLE then
			reset_measure()
			core.set_timeofday(0.5)
			state.night = false
			state.phase, state.phase_t = state.phase == "settle" and "run" or "run2", 0
		end
	elseif state.phase == "run" or state.phase == "run2" then
		move_fakes()
		if state.phase_t >= RUN / 2 and not state.night then
			state.night = true
			core.set_timeofday(0.9)
		end
		if state.phase_t >= RUN then
			if state.phase == "run" then
				report("START")
				center = grug_core.capital_anchor("accord", "human")
				log("capital center " .. core.pos_to_string(center))
				border = find_border(center)
				emerge(center)
				move_fakes()
				state.phase, state.phase_t = "emerge2", 0
			else
				report("CAPITAL")
				log("RESULT DONE")
				state.phase = "done"
				core.request_shutdown("r35 m probe done", false, 0)
			end
		end
	end
end)
