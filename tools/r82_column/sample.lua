-- Round 82 lane COLUMN: the per-column sampler sample. Builds one seed's
-- real mapgen runtime from REPO (tools/seed_fleet/runtime.lua, main's build)
-- and asks the column samplers on a fixed, seed-chosen set of columns:
--
--   * the planner source (zones.lua `planner_source`): the 20-value column
--     tuple, the overlay exclusion, the road record, the coast material, the
--     start ground, the functional surface, the relief and land zone, both
--     static exclusions, the hard row at the ground and 40 below, the
--     protected floors;
--   * the public zones session (the R7 overlay over zones.lua): id, biome,
--     race region, faction, territory, hard protection kind, PvP rule, mob
--     and guard levels (at the ground, y 0, -200 and -600), terrain height,
--     water class and the water query;
--   * the water sampler (water_layout.lua `sampler`, built from main's text as
--     height.lua builds it): `column(x, z, h0)` with the natural float field
--     h0 at the column, `maybe_wet`, and `water_in` per 16 x 16 cell;
--   * the road sampler (road_layout.lua `sampler`, from main's final text):
--     `column(x, z, t, wy)` at the column's ground t (and t - 6, t + 6, with
--     and without its water), `near` at pads 2 and 30.
--
-- Columns, per seed: a coarse grid over the world (every 61 nodes), and
-- 49 x 49 patches round the river confluences and the sharpest river bends,
-- the road junctions, the closest crossings of two roads and the first
-- bridge points, each capital and start (a sparse grid over +-600, where the
-- zone field's bulges reach) and zone borders found on the coarse grid.
--
--   luajit tools/r82_column/sample.lua REPO SEED OUT [small]
--
-- REPO is the tree whose mapgen is sampled (the base or the branch); this
-- tool's own helpers come from its own tree. OUT gets one line per
-- (entry point, column set): "<entry> <set> <columns> <sha256 of every
-- returned field>", numbers as %.17g (so equal lines mean equal bits), and
-- "info" lines with the timings (not compared). "small" samples a reduced
-- set (the fixture). Entry points the tree lacks are skipped and named.
local repo, seed, out_path, small = arg[1], arg[2], arg[3], arg[4] == "small"
assert(repo and seed and out_path, "usage: sample.lua REPO SEED OUT [small]")
local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local own_repo = here .. "/../.."

local floor, sqrt, abs = math.floor, math.sqrt, math.abs
local t_start = os.clock()
local R = dofile(own_repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local t_built = os.clock()
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local SOURCE = dofile(wp40 .. "/source/simple_map.lua")
local W = SOURCE.world_bounds
local terrain_data = dofile(wp40 .. "/terrain_data.lua")
local terrain_field = dofile(wp40 .. "/terrain_field.lua")(terrain_data)
local water_module = dofile(wp40 .. "/water_layout.lua")(terrain_data.water)
local road_module = dofile(wp40 .. "/road_layout.lua")
local full_seed = R.built.full_seed
local ps = R.planner_source
local zones = R.built.zones_session
-- The runtime's height session (an upvalue of the planner source's road
-- query): its natural float field (the h0 height.lua hands water.column)
-- and its own water sampler.
local function upvalue(fn, wanted)
	for index = 1, 255 do
		local name, value = debug.getupvalue(fn, index)
		if name == nil then break end
		if name == wanted then return value end
	end
	error("upvalue " .. wanted .. " not found")
end
local height = upvalue(ps.road_column_at, "height")
local field = height.field
local water = height.water_sampler()
local road = upvalue(height.road_column_at, "road_sampler")
local water_text, road_text = height.water_layout_text(), height.road_layout_text()
local water_layout = water_module.deserialize(water_text)
local road_layout = road_module.deserialize(road_text)
-- Fresh samplers from the texts (as emerge builds them) for the build times;
-- the road sampler is the one sampled (the session's is upvalue-only).
local t0 = os.clock()
local _w = water_module.sampler(water_module.deserialize(water_text), full_seed,
	terrain_field.simplex)
local water_build = os.clock() - t0
t0 = os.clock()
local _r = road_module.sampler(road_module.deserialize(road_text))
local road_build = os.clock() - t0

-------------------------------------------------------------------------------
-- Formatting and hashing
-------------------------------------------------------------------------------
local sha = R.sha
local function hex(s)
	return (s:gsub(".", function(c) return ("%02x"):format(c:byte()) end))
end
local function fmt(v)
	local t = type(v)
	if t == "number" then return ("%.17g"):format(v) end
	if t == "string" then return ("%q"):format(v) end
	if t == "nil" then return "nil" end
	if t == "boolean" then return tostring(v) end
	if t == "table" then
		if v.id ~= nil then return "{id=" .. fmt(v.id) .. "}" end
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = tostring(k) end
		table.sort(keys)
		local parts = {}
		for _, k in ipairs(keys) do
			local value = v[k]
			if value == nil then value = v[tonumber(k)] end
			parts[#parts + 1] = k .. "=" .. fmt(value)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return t
end
local function pack(ok, ...)
	if not ok then return "ERR " .. tostring((...)) end
	local n = select("#", ...)
	local parts = {}
	for index = 1, n do parts[index] = fmt((select(index, ...))) end
	return table.concat(parts, " ")
end

-------------------------------------------------------------------------------
-- Column sets
-------------------------------------------------------------------------------
local sets, set_names = {}, {}
local function add_set(name, columns)
	if #columns == 0 then return end
	sets[name] = columns
	set_names[#set_names + 1] = name
end
local function clampx(x) return math.max(W.min_x, math.min(W.max_x, x)) end
local function clampz(z) return math.max(W.min_z, math.min(W.max_z, z)) end
local HALF = small and 12 or 24
local function patch(x, z, half, step)
	half, step = half or HALF, step or 1
	local columns = {}
	x, z = floor(x + 0.5), floor(z + 0.5)
	for dz = -half, half, step do
		for dx = -half, half, step do
			columns[#columns + 1] = {clampx(x + dx), clampz(z + dz)}
		end
	end
	return columns
end

-- the coarse grid
do
	local step = small and 211 or 61
	local columns = {}
	for z = W.min_z, W.max_z, step do
		for x = W.min_x, W.max_x, step do columns[#columns + 1] = {x, z} end
	end
	add_set("coarse", columns)
end

-- rivers: confluences (a tributary's last vertex) and the sharpest bends
do
	local confluences, bends = {}, {}
	for _, r in ipairs(water_layout.rivers) do
		local n = #r.x
		if r.parent and n > 1 then confluences[#confluences + 1] = {r.x[n], r.z[n], r.id} end
		for i = 2, n - 1 do
			if r.w[i] and r.w[i] > 0 then
				local ax, az = r.x[i] - r.x[i - 1], r.z[i] - r.z[i - 1]
				local bx, bz = r.x[i + 1] - r.x[i], r.z[i + 1] - r.z[i]
				local la, lb = sqrt(ax * ax + az * az), sqrt(bx * bx + bz * bz)
				if la > 0 and lb > 0 then
					local c = (ax * bx + az * bz) / (la * lb)
					bends[#bends + 1] = {r.x[i], r.z[i], c, r.id * 100000 + i}
				end
			end
		end
	end
	table.sort(confluences, function(a, b) return a[3] < b[3] end)
	table.sort(bends, function(a, b)
		if a[3] ~= b[3] then return a[3] < b[3] end
		return a[4] < b[4]
	end)
	local count = small and 1 or 5
	for index = 1, math.min(count, #confluences) do
		local c = confluences[floor((index - 1) * #confluences / count) + 1]
		add_set("confluence" .. index, patch(c[1], c[2]))
	end
	local taken = {}
	local picked = 0
	for _, b in ipairs(bends) do
		if picked >= count then break end
		local key = floor(b[1] / 200) .. ":" .. floor(b[2] / 200)
		if not taken[key] then
			taken[key] = true
			picked = picked + 1
			add_set("bend" .. picked, patch(b[1], b[2]))
		end
	end
end

-- roads: junctions (a branch road's ends), crossings, bridges, a street
do
	local roads = {}
	for _, r in ipairs(road_layout.roads) do roads[#roads + 1] = r end
	local count = small and 1 or 4
	local junctions = {}
	for _, r in ipairs(roads) do
		if r.parent then
			local n = #r.X
			junctions[#junctions + 1] = {r.X[n], r.Z[n]}
			junctions[#junctions + 1] = {r.X[1], r.Z[1]}
		end
	end
	for index = 1, math.min(count, #junctions) do
		local j = junctions[floor((index - 1) * #junctions / count) + 1]
		add_set("junction" .. index, patch(j[1], j[2]))
	end
	-- crossings: points of two different roads within 3 nodes (a 16-node hash)
	local cells, crossings, seen = {}, {}, {}
	for _, r in ipairs(roads) do
		for i = 1, #r.X, 2 do
			local key = floor(r.X[i] / 16) * 65536 + floor(r.Z[i] / 16)
			local list = cells[key]
			if not list then list = {} cells[key] = list end
			list[#list + 1] = {r.X[i], r.Z[i], r.id}
		end
	end
	for _, r in ipairs(roads) do
		for i = 1, #r.X, 8 do
			local x, z = r.X[i], r.Z[i]
			local key = floor(x / 16) * 65536 + floor(z / 16)
			for _, p in ipairs(cells[key] or {}) do
				if p[3] ~= r.id and (p[1] - x) * (p[1] - x) + (p[2] - z) * (p[2] - z) <= 9 then
					local spot = floor(x / 100) .. ":" .. floor(z / 100)
					if not seen[spot] then
						seen[spot] = true
						crossings[#crossings + 1] = {x, z}
					end
				end
			end
		end
	end
	for index = 1, math.min(count, #crossings) do
		local c = crossings[floor((index - 1) * #crossings / count) + 1]
		add_set("crossing" .. index, patch(c[1], c[2]))
	end
	local bridges = {}
	for _, r in ipairs(roads) do
		for i = 1, #r.cls do
			if r.cls[i] == "B" then bridges[#bridges + 1] = {r.X[i], r.Z[i]} break end
		end
	end
	for index = 1, math.min(small and 1 or 3, #bridges) do
		local b = bridges[floor((index - 1) * #bridges / 3) + 1]
		add_set("bridge" .. index, patch(b[1], b[2]))
	end
	for _, r in ipairs(roads) do
		if r.kind == "avenue" then
			local m = floor(#r.X / 2) + 1
			add_set("street", patch(r.X[m], r.Z[m]))
			break
		end
	end
end

-- capitals and starts: a sparse grid over +-600 (the bulges' reach)
do
	local anchors = SOURCE.fixed_anchors or SOURCE.anchors
	local caps, starts = {}, {}
	for _, a in ipairs(anchors) do
		if a.slot_id == "capital" then caps[#caps + 1] = a end
		if a.slot_id == "start" then starts[#starts + 1] = a end
	end
	local half, step = small and 300 or 600, small and 23 or 9
	for index = 1, math.min(small and 1 or 2, #caps) do
		local a = caps[floor((index - 1) * #caps / 2) + 1]
		add_set("capital" .. index, patch(a.position.x, a.position.z, half, step))
	end
	for index = 1, math.min(small and 0 or 2, #starts) do
		local a = starts[floor((index - 1) * #starts / 2) + 1]
		add_set("start" .. index, patch(a.position.x, a.position.z, half, step))
	end
end

-- zone borders on the coarse grid
do
	local step = 61
	local borders = {}
	for z = W.min_z, W.max_z - step, step * 7 do
		for x = W.min_x, W.max_x - step, step * 5 do
			local a = zones.id_at(x, z)
			local b = zones.id_at(x + step, z)
			if a and b and a ~= b then borders[#borders + 1] = {x + floor(step / 2), z} end
		end
	end
	local count = small and 1 or 5
	for index = 1, math.min(count, #borders) do
		local b = borders[floor((index - 1) * #borders / count) + 1]
		add_set("border" .. index, patch(b[1], b[2]))
	end
end

-------------------------------------------------------------------------------
-- The entry points
-------------------------------------------------------------------------------
local skipped = {}
local function has(t, name)
	if t and type(t[name]) == "function" then return true end
	skipped[name] = true
	return false
end
local function position(x, y, z) return {x = x, y = y, z = z} end
local entries = {}
local function entry(name, fn) entries[#entries + 1] = {name = name, fn = fn} end

entry("ps.column_values_at", function(x, z)
	return pack(pcall(ps.column_values_at, x, z))
end)
for _, name in ipairs({"overlay_exclusion_at", "road_column_at", "coast_material_at",
		"start_ground_at", "functional_surface_values_at", "primary_relief_at",
		"land_zone_at", "protected_floor_at"}) do
	if has(ps, name) then
		local fn = ps[name]
		entry("ps." .. name, function(x, z) return pack(pcall(fn, x, z)) end)
	end
end
entry("ps.static_exclusion_values_at", function(x, z)
	return pack(pcall(ps.static_exclusion_values_at, x, z)) .. " | " ..
		pack(pcall(ps.static_exclusion_values_at, x, z, "vegetation"))
end)
entry("ps.protected_only_floor_at", function(x, z)
	return pack(pcall(ps.protected_only_floor_at, x, z, false)) .. " | " ..
		pack(pcall(ps.protected_only_floor_at, x, z, true))
end)
entry("ps.hard_row_at", function(x, z)
	local y = select(6, ps.column_values_at(x, z)) or 0
	return pack(pcall(ps.hard_row_at, x, y, z)) .. " | " ..
		pack(pcall(ps.hard_row_at, x, y - 40, z)) .. " | " ..
		pack(pcall(ps.hard_row_at, x, y + 30, z))
end)
for _, name in ipairs({"id_at", "biome_at", "race_region_at", "surface_mob_level_at",
		"terrain_height_at", "water_class_at"}) do
	if has(zones, name) then
		local fn = zones[name]
		entry("zones." .. name, function(x, z) return pack(pcall(fn, x, z)) end)
	end
end
entry("zones.water_query_at", function(x, z)
	return pack(pcall(zones.water_query_at, x, z, true)) .. " | " ..
		pack(pcall(zones.water_query_at, x, z, false))
end)
for _, name in ipairs({"faction_at", "territory_rule_at", "hard_protection_kind_at",
		"pvp_rule_at", "mob_level_at", "guard_level_at"}) do
	if has(zones, name) then
		local fn = zones[name]
		entry("zones." .. name, function(x, z)
			local y = select(6, ps.column_values_at(x, z)) or 0
			local parts = {}
			for _, yy in ipairs({y, y + 1, 0, -200, -501, -600}) do
				parts[#parts + 1] = pack(pcall(fn, position(x, yy, z)))
			end
			return table.concat(parts, " | ")
		end)
	end
end
entry("water.column", function(x, z)
	local h0 = field.height_at(x, z, true)
	return fmt(h0) .. " " .. pack(pcall(water.column, x, z, h0))
end)
for _, name in ipairs({"natural_height_at", "fitted_values_at", "inland_water_at",
		"inland_exclusion_at", "road_exclusion_at", "water_surface_at"}) do
	if has(height, name) then
		local fn = height[name]
		entry("height." .. name, function(x, z) return pack(pcall(fn, x, z)) end)
	end
end
entry("water.maybe_wet", function(x, z) return pack(pcall(water.maybe_wet, x, z)) end)
entry("water.water_in", function(x, z)
	return pack(pcall(water.water_in, x - 8, z - 8, x + 7, z + 7))
end)
entry("road.column", function(x, z)
	local _, _, _, _, _, t, wy = ps.column_values_at(x, z)
	t = t or 0
	local parts = {}
	for _, dt in ipairs({0, -6, 6}) do
		for _, w in ipairs({false, true}) do
			local ok, kind, ry, nt, rid, idx, extra = pcall(road.column, x, z, t + dt,
				w and (wy or t + dt + 2) or nil)
			parts[#parts + 1] = pack(ok, kind, ry, nt, rid, idx, extra)
		end
	end
	return table.concat(parts, " | ")
end)
entry("road.near", function(x, z)
	return pack(pcall(road.near, x, z, 2)) .. " " .. pack(pcall(road.near, x, z, 30))
end)

-------------------------------------------------------------------------------
-- Run
-------------------------------------------------------------------------------
local lines = {}
local total_columns = 0
for _, set in ipairs(set_names) do
	local columns = sets[set]
	total_columns = total_columns + #columns
	for _, e in ipairs(entries) do
		local parts = {}
		for index = 1, #columns do
			local c = columns[index]
			parts[index] = e.fn(c[1], c[2])
		end
		local text = table.concat(parts, "\n")
		lines[#lines + 1] = ("%s %s %d %s"):format(e.name, set, #columns, hex(sha(text)))
		if os.getenv("R82_COLUMN_DUMP") then
			local f = assert(io.open(os.getenv("R82_COLUMN_DUMP") .. "/" .. e.name .. "." ..
				set .. ".txt", "wb"))
			f:write(text, "\n")
			f:close()
		end
	end
end
local names = {}
for name in pairs(skipped) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do lines[#lines + 1] = "skipped " .. name end

-------------------------------------------------------------------------------
-- Timing (info): the cold planner tuple over three 80 x 80 chunk columns
-- (a river bend, a road junction, a capital's edge), and water.column and
-- road.column over the same columns, best of three each.
-------------------------------------------------------------------------------
local timing = {}
do
	local spots = {}
	for _, name in ipairs({"bend1", "junction1", "crossing1", "confluence1"}) do
		local s = sets[name]
		if s then
			local c = s[floor(#s / 2) + 1]
			spots[#spots + 1] = {R.origin(c[1]), R.origin(c[2])}
		end
	end
	local columns = {}
	for _, s in ipairs(spots) do
		for z = s[2], s[2] + 79 do
			for x = s[1], s[1] + 79 do columns[#columns + 1] = {x, z} end
		end
	end
	local function best_of(fn)
		local best = math.huge
		for _ = 1, 3 do
			local c0 = os.clock()
			fn()
			local dt = os.clock() - c0
			if dt < best then best = dt end
		end
		return best
	end
	local h0s, ts, wys = {}, {}, {}
	for index, c in ipairs(columns) do
		h0s[index] = field.height_at(c[1], c[2], true)
		local _, _, _, _, _, t, wy = ps.column_values_at(c[1], c[2])
		ts[index], wys[index] = t or 0, wy
	end
	timing.planner = best_of(function()
		ps.drop_caches()
		for index = 1, #columns do ps.column_values_at(columns[index][1], columns[index][2]) end
	end)
	timing.water = best_of(function()
		for index = 1, #columns do water.column(columns[index][1], columns[index][2], h0s[index]) end
	end)
	timing.road = best_of(function()
		for index = 1, #columns do
			road.column(columns[index][1], columns[index][2], ts[index], wys[index])
		end
	end)
	timing.columns = #columns
end

local f = assert(io.open(out_path, "wb"))
for _, line in ipairs(lines) do f:write(line, "\n") end
f:write(("info seed %s sets %d columns %d build %.1f s sample %.1f s\n"):format(seed,
	#set_names, total_columns, t_built - t_start, os.clock() - t_built))
f:write(("info sampler build: water %.3f s road %.3f s\n"):format(water_build, road_build))
f:write(("info timing over %d columns (best of 3): planner cold %.3f s, water.column %.3f s, road.column %.3f s\n")
	:format(timing.columns, timing.planner, timing.water, timing.road))
f:close()
print(("OK %s %d sets %d columns %.1f s"):format(seed, #set_names, total_columns,
	os.clock() - t_start))
