-- Round 27 Lane M: render the world map base of one seed with the REAL
-- grug_map/base.lua renderer, without the engine (LuaJIT).
--
--   luajit tools/r27_minimap/render_base.lua <repo> <seed> <out_dir> JOB [JOB ...]
--
-- JOB is  name=<path to a base.lua>:<quality>[:min_x,min_z,max_x,max_z,w,h]
-- e.g.    after=mods/PLAYER/grug_map/base.lua:high
--         before=/tmp/x/base_main.lua:normal:-600,-400,600,400,180,120
-- The world (tools/r27_minimap/world.lua) is built once and every job renders
-- on it. The renderer's `render` is local to base.lua, so the file's own
-- source is loaded with one line appended that exposes it; `core` is a stub
-- whose encode_png hands the RGBA bytes back, which this script writes as
-- <out_dir>/<name>.rgba plus <name>.txt (width height seconds). encode_png.py
-- turns them into the PNG Luanti's encode_png would write (filter 0, zlib 9).
-- The optional view renders only that world rectangle at w x h pixels (fast
-- tuning crops); without it the whole atlas at the quality's size.
local repo, seed, out_dir = arg[1], arg[2], arg[3]
assert(repo and seed and out_dir and arg[4],
	"usage: render_base.lua <repo> <seed> <out_dir> JOB [JOB ...]")

-- Wall-clock microseconds (LuaJIT ffi); CPU time where ffi is missing.
local has_ffi, ffi = pcall(require, "ffi")
local function now_us() return os.clock() * 1e6 end
if has_ffi then
	ffi.cdef("typedef struct { long tv_sec; long tv_usec; } r27_timeval;" ..
		"int gettimeofday(r27_timeval *tv, void *tz);")
	now_us = function()
		local tv = ffi.new("r27_timeval")
		ffi.C.gettimeofday(tv, nil)
		return tonumber(tv.tv_sec) * 1e6 + tonumber(tv.tv_usec)
	end
end

local captured
_G.core = _G.core or {}
local stub = {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function() return repo .. "/mods/PLAYER/grug_map" end,
	get_worldpath = function() return out_dir end,
	get_us_time = now_us,
	log = function(level, text) io.stderr:write(level, ": ", text, "\n") end,
	encode_png = function(width, height, data)
		captured = {width = width, height = height, data = data}
		return ""
	end,
	settings = {get = function() return nil end},
}
for k, v in pairs(stub) do core[k] = v end

local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local t0 = now_us()
local W = dofile(here .. "/world.lua")(repo, seed)
io.stderr:write(("world: capitals %.1f s, zones %.1f s (CPU), %.1f s wall\n"):format(
	W.seconds.capitals, W.seconds.world, (now_us() - t0) / 1e6))
-- The authored anchors (id, slot, x, z) for placing mockup markers.
do
	local out = assert(io.open(out_dir .. "/anchors.txt", "w"))
	for _, anchor in ipairs(W.source.anchors) do
		out:write(("%s %s %d %d\n"):format(tostring(anchor.id), tostring(anchor.slot_id),
			anchor.position.x, anchor.position.z))
	end
	out:close()
end
rawset(_G, "grug_mapgen", {wp40 = W.wp40})
rawset(_G, "grug_zones", W.zones)

local ATLAS = {min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200}

for index = 4, #arg do
	local name, path, quality, rest = arg[index]:match("^([%w_%-]+)=([^:]+):(%w+):?(.*)$")
	assert(name, "bad job " .. arg[index])
	local rect, tweaks = rest:match("^([^:]*):?(.*)$")
	if path:sub(1, 1) ~= "/" then path = repo .. "/" .. path end
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	text = text:gsub("\nreturn M%s*$", "\nM._render = render\nreturn M\n")
	local M = assert(loadstring(text, "@" .. path))()
	assert(M._render, "render not exposed in " .. path)
	local view, spec = ATLAS, nil
	if rect ~= "" and rect ~= "-" then
		local a, b, c, d, w, h = rect:match("^(-?%d+),(-?%d+),(-?%d+),(-?%d+),(%d+),(%d+)$")
		assert(a, "bad view " .. rect)
		view = {min_x = tonumber(a), min_z = tonumber(b), max_x = tonumber(c),
			max_z = tonumber(d)}
		spec = {width = tonumber(w), height = tonumber(h)}
	end
	if M.spec then
		spec = M.spec(quality, spec)
		-- RELIEF overrides for tuning: key=value,key=value (numbers).
		if tweaks ~= "" then
			local relief = {}
			for k, v in pairs(spec.relief) do relief[k] = v end
			for k, v in tweaks:gmatch("([%w_]+)=(-?[%d%.]+)") do relief[k] = tonumber(v) end
			spec.relief_step = relief.step or spec.relief_step
			spec.relief = relief
		end
	end
	captured = nil
	collectgarbage()
	local started = now_us()
	M._render(W.zones, view, spec)
	local seconds = (now_us() - started) / 1e6
	assert(captured, "render did not encode")
	local raw = assert(io.open(out_dir .. "/" .. name .. ".rgba", "wb"))
	raw:write(captured.data)
	raw:close()
	local meta = assert(io.open(out_dir .. "/" .. name .. ".txt", "w"))
	meta:write(("%d %d %.2f\n"):format(captured.width, captured.height, seconds))
	meta:close()
	io.stderr:write(("%s: %dx%d in %.2f s (memory %.0f MB)\n"):format(name,
		captured.width, captured.height, seconds, collectgarbage("count") / 1024))
	captured = nil
end
