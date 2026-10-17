-- Fix 0.50.2 lane CMAP: the minimap's cost with and without the Claim Stone
-- held (LuaJIT, no engine; a measurement, not a fixture).
--
--   luajit tools/r502_cmap/bench_claim.lua <repo>
--
-- The REAL grug_core hud_layout.lua, grug_map atlas.lua, base.lua,
-- minimap_view.lua, minimap.lua and providers.lua and the REAL grug_housing
-- registry.lua on the fake engine of tools/r27_minimap/bench_glide.lua: one
-- player with 2 party members, static markers on a 250-node grid, and 70
-- claims on a 500-node grid around the route (so the claim fills appear).
--   1. As bench_glide.lua: 60 s of server steps (0.09 s) walking (4 n/s),
--      sprinting (6), riding (8) and flying (12) on a slant, without and
--      with the stone held: hud_change packets and bytes per second and
--      microseconds of minimap work per server step (both modes run once
--      unprinted first, so the JIT has warmed up for both).
--   2. As tools/r37_po/texture_growth.lua's tour (straight legs of 150-600
--      nodes with random turns, reflected at the world's edge): the
--      distinct cell textures the client builds in 1 h of walking without
--      the stone, with it held all the time, and held on every other leg,
--      and their MB as RGBA8; plus the overlay tiles a client decodes in
--      claim mode (at most the faction's six).
local repo = assert(arg[1], "usage: bench_claim.lua <repo>")

local has_ffi, ffi = pcall(require, "ffi")
local function now_us() return os.clock() * 1e6 end
if has_ffi then
	ffi.cdef("typedef struct { long s; long u; } r502b; int gettimeofday(r502b*, void*);")
	now_us = function()
		local tv = ffi.new("r502b")
		ffi.C.gettimeofday(tv, nil)
		return tonumber(tv.s) * 1e6 + tonumber(tv.u)
	end
end

local steps, joins = {}, {}
local players, windows = {}, {}
local clock = 0
local traffic = {packets = 0, bytes = 0}
local seen_textures, map_id = nil, nil
local function new_player(name, pos)
	local meta, huds, next_id = {}, {}, 0
	local p = {name = name, pos = pos, yaw = 0.7, wield = ""}
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_look_horizontal() return self.yaw end
	function p:get_wielded_item()
		local item = self.wield
		return {get_name = function() return item end}
	end
	function p:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end}
	end
	function p:hud_add(def)
		next_id = next_id + 1
		huds[next_id] = def
		if def.z_index == 11 then map_id = next_id end
		return next_id
	end
	function p:hud_change(id, stat, value)
		if self.name ~= "me" then return end
		traffic.packets = traffic.packets + 1
		local size = type(value) == "string" and 2 + #value or type(value) == "table" and 8 or 4
		traffic.bytes = traffic.bytes + 18 + size
		if seen_textures and id == map_id and stat == "text" and not seen_textures[value] then
			seen_textures[value] = true
			seen_textures.n = seen_textures.n + 1
		end
	end
	function p:hud_remove(id) huds[id] = nil end
	function p:hud_set_flags() end
	function p:set_minimap_modes() end
	return p
end
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(mod)
		local roots = {grug_map = "/mods/PLAYER/grug_map", grug_jobs = "/mods/PLAYER/grug_jobs",
			grug_mounts = "/mods/PLAYER/grug_mounts", grug_housing = "/mods/PLAYER/grug_housing"}
		return roots[mod] and repo .. roots[mod] or nil
	end,
	get_modnames = function() return {"grug_jobs", "grug_map", "grug_mounts"} end,
	get_worldpath = function() return "/nonexistent-world" end,
	get_us_time = now_us,
	log = function() end,
	settings = {get = function() return nil end},
	encode_png = function(_, _, data) return data end,
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
	get_timeofday = function() return 0.1875 + clock * 60 / 86400 end,
	formspec_escape = function(text) return text end,
	registered_entities = {},
})
local sockets = {}
local ROLES = {"trainer", "quest", "trainer", "housing_manager", "quest"}
for gx = -2400, 2400, 250 do
	for gz = -3000, 1500, 250 do
		local i = #sockets + 1
		sockets[i] = {id = "s" .. i, role = ROLES[i % #ROLES + 1], profession = "tailor",
			pos = {x = gx + (i * 37) % 90, y = 30, z = gz + (i * 53) % 90}}
	end
end
rawset(_G, "grug_core", {DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125,
	settlement_socket_settlements = function()
		return {{key = "town", race_id = "human", anchor = {x = 0, z = -1500}}}
	end,
	settlement_sockets_at = function() return sockets end,
	faction_ids = {"accord", "throng"},
	start_identities = function() return {{race_id = "human", faction_id = "accord"}} end})
rawset(_G, "grug_factions", {get_faction = function() return "accord" end,
	register_on_faction_chosen = function() end})
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
local npcs, marker_states = {}, {}
for i, socket in ipairs(sockets) do
	if socket.role == "quest" then
		npcs["q" .. i] = {settlement = "town", socket = socket.id, title = "Q"}
		marker_states["q" .. i] = "available"
	end
end
rawset(_G, "grug_quests", {registered_npcs = npcs, marker_state = function() return "available" end,
	marker_states = function() return marker_states, 1 end,
	register_on_change = function() end, register_on_markers_changed = function() end})
rawset(_G, "grug_parties", {view = function()
	return {members = {{name = "me"}, {name = "p1"}, {name = "p2"}}}
end, register_on_change = function() end})
rawset(_G, "grug_home", {get = function() return nil end, locations = function()
	return {{id = "inn", label = "Inn", pos = {x = -80, y = 20, z = -1450}}}
end, known_waypoints = function() return {} end, claim_waypoint = function() return nil end})
rawset(_G, "grug_jobs", {PROFESSIONS = {tailor = {name = "Tailor"}},
	trainer_teaches = function() return true end})
rawset(_G, "grug_mobs", {dragon_map_markers = function() return {} end})
-- the claims: 70 on a 500-node grid (drafts and active alike)
local model = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({
	storage = {get_string = function() return "" end, set_string = function() end,
		keys = function() return {} end},
	now = function() return 1800000000 end})
model.load()
local placed = 0
for gx = -2250, 2250, 500 do
	for gz = -3050, -50, 500 do
		placed = placed + 1
		model.create("c" .. placed, {x = gx, y = 10, z = gz})
	end
end
rawset(_G, "grug_housing", {STONE_ITEM = "grug_housing:claim_stone", RADIUS = model.RADIUS,
	claims_in = model.claims_in, claim_set_version = model.claim_set_version})
rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua"),
	location = {text_of = function() return "Dawnmere Fields" end}})
local base = dofile(repo .. "/mods/PLAYER/grug_map/base.lua")
grug_map.base = base
local installed = {quality = "normal", width = 1080, height = 960,
	tiles = base.tiles(1080, 960)}
installed.texture = base.combined_texture(1080, 960, installed.tiles)
installed.minimap = {quality = "normal", width = 1080, height = 960,
	tiles = base.tiles(1080, 960, base.MINI_PREFIX),
	claim = {accord = base.tiles(1080, 960, base.CLAIM_PREFIX .. "_accord"),
		throng = base.tiles(1080, 960, base.CLAIM_PREFIX .. "_throng")}}
grug_map.atlas.set_base_texture(installed.texture)
dofile(repo .. "/mods/PLAYER/grug_map/minimap.lua")
grug_map.minimap.install(installed)
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
steps.loaded()

local me = new_player("me", {x = -300, y = 20, z = -1700})
local p1 = new_player("p1", {x = -280, y = 20, z = -1690})
local p2 = new_player("p2", {x = -330, y = 20, z = -1720})
players.me, players.p1, players.p2 = me, p1, p2
windows.me = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
for _, fn in ipairs(joins) do fn(me) end
local DT = 0.09
local function run_steps()
	for i = 1, #steps do steps[i](DT) end
end

-- 1. packets and cost
local SECONDS = 60
print(("== %d claims; 60 s per speed, server step %.2f s"):format(placed, DT))
for round, held in ipairs({false, true, false, true}) do
	me.wield = held and "grug_housing:claim_stone" or ""
	for _, p in ipairs({me, p1, p2}) do p.pos.x, p.pos.z = -300 + (p == p1 and 20 or p == p2 and -30 or 0), -1700 end
	for _, speed in ipairs({{"walk", 4}, {"sprint", 6}, {"ride", 8}, {"fly", 12}}) do
		for _, p in ipairs({me, p1, p2}) do p.pos.x = p.pos.x - 200 end
		for _ = 1, 40 do clock = clock + DT; run_steps() end
		traffic.packets, traffic.bytes = 0, 0
		local spent, count = 0, math.floor(SECONDS / DT)
		for _ = 1, count do
			for _, p in ipairs({me, p1, p2}) do
				p.pos.x = p.pos.x + speed[2] * DT * 0.8
				p.pos.z = p.pos.z + speed[2] * DT * 0.6
			end
			clock = clock + DT
			local t0 = now_us()
			run_steps()
			spent = spent + (now_us() - t0)
		end
		if round > 2 then
			print(("%-6s %-6s %5.1f packets/s  %6.0f bytes/s  %6.1f us/step"):format(
				held and "stone" or "none", speed[1], traffic.packets / SECONDS,
				traffic.bytes / SECONDS, spent / count))
		end
		for _, p in ipairs({me, p1, p2}) do
			p.pos.x, p.pos.z = p.pos.x - speed[2] * SECONDS * 0.8, p.pos.z - speed[2] * SECONDS * 0.6
		end
	end
end

-- 2. texture growth on the tour (as texture_growth.lua)
local BOUNDS = {min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200}
local view = grug_map.minimap.geometry()
local bytes = view.pixels * view.pixels * 4
local function tour(mode, hours, speed)
	local seed = 12345
	local function rand()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	players.p1, players.p2 = nil, nil
	seen_textures = {n = 0}
	local x, z = 0, -1500
	local angle = rand() * 2 * math.pi
	local leg = 150 + rand() * 450
	local legs, margin = 0, 50
	local per_step = speed * DT
	me.wield = mode == "none" and "" or "grug_housing:claim_stone"
	for _ = 1, math.floor(hours * 3600 / DT) do
		x, z = x + math.cos(angle) * per_step, z + math.sin(angle) * per_step
		if x < BOUNDS.min_x + margin or x > BOUNDS.max_x - margin then
			angle = math.pi - angle
			x = math.max(BOUNDS.min_x + margin, math.min(BOUNDS.max_x - margin, x))
		end
		if z < BOUNDS.min_z + margin or z > BOUNDS.max_z - margin then
			angle = -angle
			z = math.max(BOUNDS.min_z + margin, math.min(BOUNDS.max_z - margin, z))
		end
		leg = leg - per_step
		if leg <= 0 then
			angle = angle + (rand() - 0.5) * math.pi
			leg = 150 + rand() * 450
			legs = legs + 1
			if mode == "alternate" then
				me.wield = legs % 2 == 1 and "grug_housing:claim_stone" or ""
			end
		end
		me.pos.x, me.pos.z = x, z
		clock = clock + DT
		run_steps()
	end
	local n = seen_textures.n
	seen_textures = nil
	return n
end
print(("== texture growth, 1 h walking (4 n/s), cell texture %dx%d px = %.1f KB RGBA8"):format(
	view.pixels, view.pixels, bytes / 1024))
for _, mode in ipairs({"none", "held", "alternate"}) do
	local n = tour(mode, 1, 4)
	print(("%-10s %5d textures  %5.1f MB"):format(mode, n, n * bytes / 1048576))
end
local overlay = 0
for _, tile in ipairs(installed.minimap.claim.accord) do overlay = overlay + tile.w * tile.h * 4 end
print(("overlay tiles a client decodes in claim mode: at most 6 (one faction), %.1f MB RGBA8"):format(
	overlay / 1048576))
