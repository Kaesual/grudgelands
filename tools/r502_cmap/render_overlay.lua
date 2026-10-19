-- Fix 0.50.2 lane CMAP: the Claim Stone overlays rendered offline with the
-- REAL grug_map/base.lua renderer and the REAL grug_housing column rule
-- (LuaJIT, no engine; a measurement, not a fixture).
--
--   luajit tools/r502_cmap/render_overlay.lua <repo> <seed> <out_dir> [quality]
--
-- Builds the portable world of tools/r25_road_poi/world.lua (zones, roads,
-- every POI, village and camp core, the world protection as main builds it;
-- the capitals' cities stood in by squares), renders the base at `quality`
-- (normal by default) once without and once with the overlays and prints
-- both times. `feature_in` is api.lua's placement query rebuilt on that
-- world (the settlement cores, then the hard footprints widened by the
-- margin). Writes <out_dir>/mini.rgba and claim_<faction>.rgba (the
-- minimap base and the overlays assembled from their tiles) with .txt
-- files (width height) for tools/r27_minimap/encode_png.py, and
-- tiles.txt: one line per overlay tile (name width height).
local repo, seed, out_dir, quality = arg[1], arg[2], arg[3], arg[4] or "normal"
assert(repo and seed and out_dir, "usage: render_overlay.lua <repo> <seed> <out_dir> [quality]")

local has_ffi, ffi = pcall(require, "ffi")
local function now_us() return os.clock() * 1e6 end
if has_ffi then
	ffi.cdef("typedef struct { long s; long u; } r502_tv; int gettimeofday(r502_tv*, void*);")
	now_us = function()
		local tv = ffi.new("r502_tv")
		ffi.C.gettimeofday(tv, nil)
		return tonumber(tv.s) * 1e6 + tonumber(tv.u)
	end
end

_G.core = _G.core or {}
local stub = {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function() return repo .. "/mods/PLAYER/grug_map" end,
	get_worldpath = function() return out_dir end,
	get_us_time = now_us,
	log = function(level, text) io.stderr:write(level, ": ", text, "\n") end,
	-- the tile's raw RGBA stands in for its PNG
	encode_png = function(_, _, data) return data end,
	settings = {get = function() return nil end},
}
for k, v in pairs(stub) do core[k] = v end

local t0 = now_us()
local W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, seed)
io.stderr:write(("world built in %.1f s\n"):format((now_us() - t0) / 1e6))
local session = W.session
local zones = {}
for _, name in ipairs({"get", "id_at", "water_class_at", "terrain_height_at"}) do
	zones[name] = function(...) return session[name](...) end
end
local model = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({
	storage = {get_string = function() return "" end, set_string = function() end,
		keys = function() return {} end},
	now = function() return 0 end})
local feature_queries = 0
local claim = {factions = {"accord", "throng"}, problem = model.column_problem,
	margin = model.SETTLEMENT_MARGIN,
	territory_at = function(x, z) return session.territory_rule_at({x = x, y = 30000, z = z}) end,
	feature_in = function(min_x, min_z, max_x, max_z, margin)
		feature_queries = feature_queries + 1
		if W.protection.boxes_in(min_x, min_z, max_x, max_z, margin) then return "site" end
		local _, kind = session.hard_footprint_in(min_x - margin, min_z - margin,
			max_x + margin, max_z + margin)
		return kind
	end}

local path = repo .. "/mods/PLAYER/grug_map/base.lua"
local text = assert(io.open(path, "rb")):read("*a")
text = text:gsub("\nreturn M%s*$", "\nM._render = render\nreturn M\n")
local M = assert(loadstring(text, "@" .. path))()
local view = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua").view()
local spec = M.spec(quality)

local function assemble(name, tiles, width, height)
	local rows = {}
	for j = 1, height do rows[j] = {} end
	for _, tile in ipairs(tiles) do
		for r = 0, tile.h - 1 do
			local list = rows[tile.y + r + 1]
			list[#list + 1] = tile.png:sub(r * tile.w * 4 + 1, (r + 1) * tile.w * 4)
		end
	end
	for j = 1, height do rows[j] = table.concat(rows[j]) end
	local out = assert(io.open(out_dir .. "/" .. name .. ".rgba", "wb"))
	out:write(table.concat(rows))
	out:close()
	out = assert(io.open(out_dir .. "/" .. name .. ".txt", "w"))
	out:write(("%d %d 0\n"):format(width, height))
	out:close()
end

collectgarbage()
local started = now_us()
M._render(zones, view, spec, nil, nil)
local plain = (now_us() - started) / 1e6
collectgarbage()
started = now_us()
local _, mini_tiles, overlays = M._render(zones, view, spec, nil, claim)
local with = (now_us() - started) / 1e6
local mini = spec.minimap
assemble("mini", mini_tiles, mini.width, mini.height)
local list = assert(io.open(out_dir .. "/tiles.txt", "w"))
for _, faction in ipairs(claim.factions) do
	assemble("claim_" .. faction, overlays[faction], mini.width, mini.height)
	for _, tile in ipairs(overlays[faction]) do
		local name = tile.name:gsub("%.png$", "")
		list:write(("%s %d %d\n"):format(name, tile.w, tile.h))
		local out = assert(io.open(out_dir .. "/" .. name .. ".rgba", "wb"))
		out:write(tile.png)
		out:close()
		out = assert(io.open(out_dir .. "/" .. name .. ".txt", "w"))
		out:write(("%d %d 0\n"):format(tile.w, tile.h))
		out:close()
	end
end
list:close()
print(("render %s %dx%d: %.2f s without the overlays, %.2f s with (+%.2f s); " ..
	"%d settlement queries"):format(quality, spec.width, spec.height, plain, with,
	with - plain, feature_queries))

-- "Green, yet refused" must not happen: random claim centres whose square
-- (rounded outward to minimap pixels, as minimap_view.lua claim_rect) holds
-- no red pixel of the faction's overlay must pass validate's settlement and
-- zone checks (the real validate on an empty registry, the cube taken as
-- clear). Squares touching red are counted by validate's answer.
local npp = (view.max_x - view.min_x) / mini.width
local world = {fixed = false, cube_clear = function() return true end,
	water_class_at = session.water_class_at, territory_at = claim.territory_at,
	feature_in = claim.feature_in,
	zone_at = function(x, z)
		local id = session.id_at(x, z)
		return id and session.get(id) or nil
	end}
-- LuaJIT's math.random is deterministic for one seed
math.randomseed(20261017)
local function random(n) return math.random(0, n - 1) end
for _, faction in ipairs(claim.factions) do
	local tiles = overlays[faction]
	local function red(i, j)
		for _, tile in ipairs(tiles) do
			if i >= tile.x and i < tile.x + tile.w and j >= tile.y and j < tile.y + tile.h then
				local at = ((j - tile.y) * tile.w + (i - tile.x)) * 4 + 4
				return tile.png:byte(at) ~= 0
			end
		end
		return true
	end
	local clear_tried, clear_refused, red_tried, red_passed = 0, 0, 0, 0
	local examples = {}
	for _ = 1, 400000 do
		if clear_tried >= 1500 and red_tried >= 300 then break end
		local x = view.min_x + 60 + random(view.max_x - view.min_x - 120)
		local z = view.min_z + 60 + random(view.max_z - view.min_z - 120)
		local i0 = math.floor((x - 50.5 - view.min_x) / npp)
		local i1 = math.ceil((x + 50.5 - view.min_x) / npp) - 1
		local j0 = math.floor((view.max_z - z - 50.5) / npp)
		local j1 = math.ceil((view.max_z - z + 50.5) / npp) - 1
		local touches = false
		for j = j0, j1 do
			for i = i0, i1 do touches = touches or red(i, j) end
		end
		-- squares that touch red only at their rim, so the check meets the edge
		local core_red = false
		for j = j0 + 2, j1 - 2 do
			for i = i0 + 2, i1 - 2 do core_red = core_red or red(i, j) end
		end
		if not touches and clear_tried < 1500 then
			clear_tried = clear_tried + 1
			local ok, code = model.validate("probe", faction, {x = x, y = 10, z = z}, world)
			if not ok then
				clear_refused = clear_refused + 1
				if #examples < 5 then
					-- the refused columns' extent and the nearest pixel centre
					-- column the overlay classified
					local count, x0, x1, z0, z1 = 0, math.huge, -math.huge, math.huge, -math.huge
					for dz = -50, 50 do
						for dx = -50, 50 do
							local sx, sz = x + dx, z + dz
							local zone = world.zone_at(sx, sz)
							if model.column_problem(faction, world.water_class_at(sx, sz), zone,
									zone and world.territory_at(sx, sz) or nil) then
								count = count + 1
								x0, x1 = math.min(x0, sx), math.max(x1, sx)
								z0, z1 = math.min(z0, sz), math.max(z1, sz)
							end
						end
					end
					examples[#examples + 1] = ("%d,%d %s (%d columns in x %d..%d, z %d..%d)"):format(
						x, z, code, count, x0, x1, z0, z1)
				end
			end
		elseif touches and not core_red and red_tried < 300 then
			red_tried = red_tried + 1
			if model.validate("probe", faction, {x = x, y = 10, z = z}, world) then
				red_passed = red_passed + 1
			end
		end
	end
	print(("%s: %d squares without red, %d of them refused%s; %d squares with red only " ..
		"at their rim, %d of them accepted"):format(faction, clear_tried, clear_refused,
		#examples > 0 and (" (" .. table.concat(examples, "; ") .. ")") or "",
		red_tried, red_passed))
end
