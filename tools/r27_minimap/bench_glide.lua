-- Round 27 minimap glide: traffic and cost comparison (LuaJIT, no engine).
--
--   luajit tools/r27_minimap/bench_glide.lua <code_tree> <repo> [label]
--
-- Loads grug_core/hud_layout.lua and grug_map (atlas, base, minimap_view,
-- minimap, providers) from <code_tree> -- this branch, or an export of main
-- (`git archive a19b829d mods | tar -x -C DIR`) -- on a fake engine with
-- textures from <repo>, and simulates one player for 60 s of server steps
-- (0.09 s, the dedicated_server_step default) walking (4 n/s), sprinting
-- (6), riding (8) and flying (12) on a slant, with static markers on a
-- 250-node grid (about 10 in the window at any time, capped by the 24
-- slots) and 2 party members walking along. Prints per speed: hud_change packets per second, bytes per
-- second (value plus ~18 bytes of reliable-packet headers per hud_change)
-- and microseconds of minimap work per server step.
local tree, repo, label = arg[1], arg[2], arg[3] or arg[1]
assert(tree and repo, "usage: bench_glide.lua <code_tree> <repo> [label]")

local steps, joins = {}, {}
-- Wall-clock microseconds (LuaJIT ffi); CPU time where ffi is missing.
local has_ffi, ffi = pcall(require, "ffi")
local function now_us() return os.clock() * 1e6 end
if has_ffi then
	ffi.cdef("typedef struct { long s; long u; } r27b; int gettimeofday(r27b*, void*);")
	now_us = function()
		local tv = ffi.new("r27b")
		ffi.C.gettimeofday(tv, nil)
		return tonumber(tv.s) * 1e6 + tonumber(tv.u)
	end
end
local players, windows = {}, {}
local traffic = {packets = 0, bytes = 0}
local function new_player(name, pos)
	local meta, huds, next_id = {}, {}, 0
	local p = {name = name, pos = pos, yaw = 0.7}
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_look_horizontal() return self.yaw end
	function p:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end}
	end
	function p:hud_add(def) next_id = next_id + 1 huds[next_id] = def return next_id end
	function p:hud_change(id, _, value)
		if self.name ~= "me" then return end
		traffic.packets = traffic.packets + 1
		local size = type(value) == "string" and 2 + #value or type(value) == "table" and 8 or 4
		traffic.bytes = traffic.bytes + 18 + size
	end
	function p:hud_remove(id) huds[id] = nil end
	function p:hud_set_flags() end
	function p:set_minimap_modes() end
	return p
end
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(mod)
		local roots = {grug_map = tree .. "/mods/PLAYER/grug_map",
			grug_jobs = repo .. "/mods/PLAYER/grug_jobs",
			grug_mounts = repo .. "/mods/PLAYER/grug_mounts"}
		return roots[mod]
	end,
	get_modnames = function() return {"grug_jobs", "grug_map", "grug_mounts"} end,
	get_worldpath = function() return "/nonexistent-world" end,
	get_us_time = now_us,
	log = function() end,
	settings = {get = function() return nil end},
	encode_png = function(w, h, data) return data end,
	safe_file_write = function() return true end,
	dynamic_add_media = function() return true end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	register_on_mods_loaded = function(fn) steps.loaded = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	get_connected_players = function()
		local list = {}
		for _, p in pairs(players) do list[#list + 1] = p end
		return list
	end,
	get_player_by_name = function(name) return players[name] end,
	get_player_window_information = function(name) return windows[name] end,
	formspec_escape = function(text) return text end,
	registered_entities = {},
})
-- Markers on a 250-node grid over the whole route, so about 10 are in the
-- 900-node window wherever the player is (a town's worth).
local sockets = {}
local ROLES = {"trainer", "quest", "trainer", "housing_manager", "quest"}
for gx = -2400, 2400, 250 do
	for gz = -3000, 1500, 250 do
		local i = #sockets + 1
		sockets[i] = {id = "s" .. i, role = ROLES[i % #ROLES + 1], profession = "tailor",
			pos = {x = gx + (i * 37) % 90, y = 30, z = gz + (i * 53) % 90}}
	end
end
rawset(_G, "grug_core", {settlement_socket_settlements = function()
		return {{key = "town", race_id = "human", anchor = {x = 0, z = -1500}}}
	end,
	settlement_sockets_at = function() return sockets end})
dofile(tree .. "/mods/CORE/grug_core/hud_layout.lua")
local npcs = {}
for i, socket in ipairs(sockets) do
	if socket.role == "quest" then npcs["q" .. i] = {settlement = "town", socket = socket.id, title = "Q"} end
end
rawset(_G, "grug_quests", {registered_npcs = npcs, marker_state = function() return "available" end,
	register_on_change = function() end})
rawset(_G, "grug_parties", {view = function()
	return {members = {{name = "me"}, {name = "p1"}, {name = "p2"}}}
end})
rawset(_G, "grug_home", {get = function() return nil end, locations = function()
	return {{id = "inn", label = "Inn", pos = {x = -80, y = 20, z = -1450}}}
end})
rawset(_G, "grug_jobs", {PROFESSIONS = {tailor = {name = "Tailor"}}})
rawset(_G, "grug_mobs", {dragon_map_markers = function() return {} end})
rawset(_G, "grug_map", {atlas = dofile(tree .. "/mods/PLAYER/grug_map/atlas.lua")})
local base = dofile(tree .. "/mods/PLAYER/grug_map/base.lua")
grug_map.base = base
local installed = {quality = "normal", width = 1080, height = 960, minimap_grid = 16,
	tiles = base.tiles(1080, 960)}
installed.texture = base.combined_texture(1080, 960, installed.tiles)
grug_map.atlas.set_base_texture(installed.texture)
dofile(tree .. "/mods/PLAYER/grug_map/minimap.lua")
grug_map.minimap.install(installed)
dofile(tree .. "/mods/PLAYER/grug_map/providers.lua")
steps.loaded()

local me = new_player("me", {x = -300, y = 20, z = -1700})
local p1 = new_player("p1", {x = -280, y = 20, z = -1690})
local p2 = new_player("p2", {x = -330, y = 20, z = -1720})
players.me, players.p1, players.p2 = me, p1, p2
windows.me = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
for _, fn in ipairs(joins) do fn(me) end

local DT, SECONDS = 0.09, 60
local rows = {}
for _, speed in ipairs({{"walk", 4}, {"sprint", 6}, {"ride", 8}, {"fly", 12}}) do
	for _, p in ipairs({me, p1, p2}) do p.pos.x, p.pos.z = p.pos.x - 200, p.pos.z end
	-- settle at the start, then measure
	for _ = 1, 40 do for i = 1, #steps do steps[i](DT) end end
	traffic.packets, traffic.bytes = 0, 0
	local spent, count = 0, math.floor(SECONDS / DT)
	for _ = 1, count do
		for _, p in ipairs({me, p1, p2}) do
			p.pos.x = p.pos.x + speed[2] * DT * 0.8
			p.pos.z = p.pos.z + speed[2] * DT * 0.6
		end
		local t0 = now_us()
		for i = 1, #steps do steps[i](DT) end
		spent = spent + (now_us() - t0)
	end
	rows[#rows + 1] = ("%-8s %5.1f packets/s  %6.0f bytes/s  %6.1f us/step"):format(speed[1],
		traffic.packets / SECONDS, traffic.bytes / SECONDS, spent / count)
	for _, p in ipairs({me, p1, p2}) do p.pos.x, p.pos.z = p.pos.x - speed[2] * SECONDS * 0.8,
		p.pos.z - speed[2] * SECONDS * 0.6 end
end
print("== " .. label)
for _, row in ipairs(rows) do print(row) end
