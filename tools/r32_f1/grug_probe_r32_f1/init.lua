-- Disposable engine probe (Round 32 lane F1): minimap traffic and the
-- location sample's cost on the real world of a seed. Never shipped:
-- tools/r32_f1/engine.sh stages it through tools/luanti_headless.sh.
--
-- One player stand-in (a table answering the ObjectRef methods the two mods
-- call) joins ONLY grug_map's minimap and location hooks, and only their two
-- globalsteps see it (each is wrapped to answer get_connected_players with
-- the stand-in). It starts at Dawnmere's innkeeper as an Accord player and
-- moves on a slant at walking, sprinting, riding and flying speed, 30 s
-- each. Logged per speed: hud_change packets and estimated bytes per second
-- (value plus ~18 bytes of reliable-packet headers, as bench_glide.lua),
-- new cell textures per second, minimap microseconds per step; then the
-- minimap geometry (window, grid, texture size) and the location samples'
-- cost. Then the server shuts down.

local P = "[r32f1_probe] "
local NAME = "r32f1stub"
local SPEEDS = {{"walk", 4}, {"sprint", 6}, {"ride", 8}, {"fly", 12}}
local PHASE = 30
local SETTLE = 3

local function log(msg) core.log("action", P .. msg) end

local meta_store = {["grug_factions:faction"] = "accord"}
local meta = {}
function meta:get_string(k) return meta_store[k] or "" end
function meta:set_string(k, v) meta_store[k] = v ~= "" and v or nil end
function meta:get_int(k) return math.floor(tonumber(meta_store[k]) or 0) end
function meta:set_int(k, v) meta_store[k] = tostring(v) end
function meta:get_float(k) return tonumber(meta_store[k]) or 0 end
function meta:set_float(k, v) meta_store[k] = tostring(v) end
function meta:contains(k) return meta_store[k] ~= nil end

local traffic = {packets = 0, bytes = 0}
local stub = {pos = {x = 0, y = 20, z = 0}, huds = {}, next_id = 0}
function stub:get_player_name() return NAME end
function stub:is_player() return true end
function stub:get_hp() return 20 end
function stub:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
function stub:get_look_horizontal() return 0.7 end
function stub:get_meta() return meta end
function stub:hud_add(def)
	self.next_id = self.next_id + 1
	self.huds[self.next_id] = def
	return self.next_id
end
function stub:hud_change(_, _, value)
	traffic.packets = traffic.packets + 1
	local size = type(value) == "string" and 2 + #value or type(value) == "table" and 8 or 4
	traffic.bytes = traffic.bytes + 18 + size
end
function stub:hud_remove(id) self.huds[id] = nil end
function stub:hud_set_flags() end
function stub:set_minimap_modes() end

local function from(fn, file)
	local info = debug.getinfo(fn, "S")
	return info and info.source and info.source:find(file, 1, true) ~= nil
end

-- The two globalsteps, wrapped: they see only the stand-in.
local minimap_us = 0
local function wrap(fn, timed)
	return function(dtime)
		local gcp, gpbn, gpwi = core.get_connected_players, core.get_player_by_name,
			core.get_player_window_information
		core.get_connected_players = function() return {stub} end
		core.get_player_by_name = function(name) return name == NAME and stub or nil end
		core.get_player_window_information = function(name)
			if name ~= NAME then return gpwi(name) end
			return {size = {x = 1920, y = 1080}, real_gui_scaling = 1, real_hud_scaling = 1}
		end
		local started = core.get_us_time()
		local ok, err = pcall(fn, dtime)
		if timed then minimap_us = minimap_us + (core.get_us_time() - started) end
		core.get_connected_players, core.get_player_by_name = gcp, gpbn
		core.get_player_window_information = gpwi
		if not ok then error(err) end
	end
end

local state = {phase = "wait", clock = 0}
local rows = {}

local function start()
	local home = grug_home.location("dawnmere")
	local pos = home and home.pos or {x = 0, y = 20, z = 0}
	stub.pos = {x = pos.x, y = pos.y, z = pos.z}
	for _, fn in ipairs(core.registered_on_joinplayers) do
		if from(fn, "grug_map/minimap.lua") or from(fn, "grug_map/location.lua") then
			fn(stub)
		end
	end
	for index, fn in ipairs(core.registered_globalsteps) do
		if from(fn, "grug_map/minimap.lua") then
			core.registered_globalsteps[index] = wrap(fn, true)
		elseif from(fn, "grug_map/location.lua") then
			core.registered_globalsteps[index] = wrap(fn, false)
		end
	end
	log(("start at %d %d %d"):format(stub.pos.x, stub.pos.y, stub.pos.z))
end

local speed_index, phase_clock, steps, textures0
local function begin_speed()
	traffic.packets, traffic.bytes, minimap_us, steps, phase_clock = 0, 0, 0, 0, 0
	textures0 = grug_map.minimap.stats.textures
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.phase == "wait" then
		if state.clock < SETTLE or not grug_map.minimap.available() then return end
		start()
		state.phase, speed_index = "run", 1
		begin_speed()
		return
	end
	if state.phase ~= "run" then return end
	local speed = SPEEDS[speed_index]
	stub.pos.x = stub.pos.x + speed[2] * dtime * 0.8
	stub.pos.z = stub.pos.z + speed[2] * dtime * 0.6
	steps = steps + 1
	phase_clock = phase_clock + dtime
	if phase_clock >= PHASE then
		rows[#rows + 1] = ("%-7s %5.1f packets/s %6.0f bytes/s %5.2f textures/s %6.1f us/step"):format(
			speed[1], traffic.packets / phase_clock, traffic.bytes / phase_clock,
			(grug_map.minimap.stats.textures - textures0) / phase_clock, minimap_us / steps)
		log(rows[#rows])
		speed_index = speed_index + 1
		if speed_index > #SPEEDS then
			state.phase = "done"
			local v = grug_map.minimap.geometry()
			log(("geometry window %d px (%.0f nodes) grid %d px (%.1f nodes) " ..
				"texture %d base px, %dx%d texels (%.1f KB RGBA)"):format(v.crop,
				v.crop * v.npp, v.grid, v.grid * v.npp, v.texture, v.pixels, v.pixels,
				v.pixels * v.pixels * 4 / 1024))
			local s = grug_map.location.stats
			log(("location samples %d, %.1f us each"):format(s.samples,
				s.samples > 0 and s.us / s.samples or 0))
			log("RESULT DONE")
			core.request_shutdown("r32 f1 probe done", false, 0)
			return
		end
		begin_speed()
	end
end)
