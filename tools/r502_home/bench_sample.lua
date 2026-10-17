-- Fix 0.50.2 lane HOME: the location sample's cost with and without the
-- claim lookup (LuaJIT, no engine; a measurement, not a fixture).
--
--   luajit tools/r502_home/bench_sample.lua <repo>
--
-- The REAL grug_map location_view.lua and location.lua and the REAL
-- grug_housing registry.lua on a fake engine: 20 players walking on a slant
-- through a field of 400 claims on a 250-node grid (so about one sample in
-- six lands in a claim), samples once a second each. Prints the
-- location globalstep's microseconds per sample (the zone, town and
-- territory lookups, the banner rule and, with grug_housing, the claim
-- lookup; the ticks between samples included) without and with
-- grug_housing, each after an unprinted warm-up. The zone and
-- territory are cheap fakes here, so the difference is the claim lookup's
-- own cost; the engine's zone queries are dearer.
local repo = assert(arg[1], "usage: bench_sample.lua <repo>")

local has_ffi, ffi = pcall(require, "ffi")
local function clock_us() return os.clock() * 1e6 end
if has_ffi then
	ffi.cdef("typedef struct { long s; long u; } r502h; int gettimeofday(r502h*, void*);")
	clock_us = function()
		local tv = ffi.new("r502h")
		ffi.C.gettimeofday(tv, nil)
		return tonumber(tv.s) * 1e6 + tonumber(tv.u)
	end
end

local model = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({
	storage = {get_string = function() return "" end, set_string = function() end,
		keys = function() return {} end},
	now = function() return 1800000000 end})
model.load()
local placed = 0
for gx = -2500, 2500, 250 do
	for gz = -2500, 2250, 250 do
		placed = placed + 1
		model.create("c" .. placed, {x = gx, y = 10, z = gz})
	end
end

local function run(with_housing, seconds)
	local steps, joins, players = {}, {}, {}
	local fake_us = 0
	rawset(_G, "core", {
		get_current_modname = function() return "grug_map" end,
		get_modpath = function() return repo .. "/mods/PLAYER/grug_map" end,
		-- the fake time: location.lua's 1 s phases follow the steps
		get_us_time = function() return fake_us end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function() end,
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		get_connected_players = function() return players end,
		get_player_by_name = function() return nil end,
		get_player_window_information = function() return nil end,
		log = function() end,
	})
	rawset(_G, "grug_core", {FEED_COLOR = {notice = 0xf0e6c8},
		zone_authority_installed = function() return true end,
		settlement_socket_settlements = function() return {} end})
	dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
	rawset(_G, "grug_zones", {id_at = function(x) return x < 0 and "west" or "east" end,
		get = function(id) return {id = id, display_name = id} end,
		hard_footprint_in = function() return nil end})
	rawset(_G, "grug_factions", {get_faction = function() return "accord" end})
	rawset(_G, "grug_pvp", {territory_at = function() return "friendly" end})
	rawset(_G, "grug_housing", with_housing and {claim_at = model.claim_at} or nil)
	rawset(_G, "grug_map", {})
	dofile(repo .. "/mods/PLAYER/grug_map/location.lua")
	local M = grug_map.location
	for i = 1, 20 do
		local p = {name = "p" .. i, pos = {x = -2400 + i * 37, y = 10, z = -2400 + i * 53}}
		function p:get_player_name() return self.name end
		function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
		function p:hud_add() return 1 end
		function p:hud_change() end
		players[i] = p
		for _, fn in ipairs(joins) do fn(p) end
	end
	-- the whole steps are timed (the 1 s phases follow the fake time): the
	-- steps between samples cost the same with and without, so the
	-- difference is the claim lookup's
	local DT = 0.1
	local measured, before_n = 0, M.stats.samples
	for _ = 1, math.floor(seconds / DT) do
		for _, p in ipairs(players) do
			p.pos.x, p.pos.z = p.pos.x + 4 * DT * 0.8, p.pos.z + 4 * DT * 0.6
		end
		fake_us = fake_us + DT * 1e6
		local t0 = clock_us()
		for _, fn in ipairs(steps) do fn(DT) end
		measured = measured + (clock_us() - t0)
	end
	local samples = M.stats.samples - before_n
	return measured / samples, samples
end

print(("== %d claims, 20 players walking, samples once a second"):format(placed))
for round, with in ipairs({false, true, false, true}) do
	local us, n = run(with, 6000)
	if round > 2 then
		print(("%-22s %6.2f us per sample (%d samples)"):format(
			with and "with the claim lookup" or "without", us, n))
	end
end
