-- Round 51 TERRAIN T1: the "no land moves" comparison. Builds the real mapgen
-- runtime of one seed (tools/seed_fleet/runtime.lua, as main builds it on a
-- world's first start) and writes what the world is inside the OLD world
-- bounds (+-3740 x +-3340, before T1), so the dumps of two checkouts can be
-- compared line by line:
--
--   luajit tools/r51_terrain/compare.lua REPO SEED OUT
--   diff OUT_before OUT_after
--
-- REPO is the checkout to measure (the tool itself may live elsewhere): run
-- it once on an export of the base commit and once on the branch.
--
-- OUT holds, in this order:
--   * the layout texts' SHA-256 (placement, inland water, roads, capitals),
--     the anchor roster's digest and every settlement's key, slot, anchor and
--     prepared bounds (placement of settlements, roads and POIs);
--   * one line per sampled column: water class, zone id, biome, terrain
--     height, surface level, territory and PvP rule and mob level at the
--     surface, and the mob level at y -600. The sample is a lattice every 32
--     nodes over the old bounds and every 8 nodes within 512 nodes of an old
--     edge (where grid origins, clamps and edge effects matter), plus every
--     column of the four old edge lines at a 4-node step;
--   * the terrain field's own floats near the old edges (surface height,
--     coast distance, zone character channels) at 17 significant digits;
--   * one line per chunk: the hash of the fake VoxelManip after the real
--     plan_slice and writer, and the digest of its decoration candidates.
--     Per side of the old bounds: the three chunks whose sampled land lies
--     nearest to that edge, one sea chunk of the outermost chunk row whose
--     16-node shell lies inside the old bounds, and the chunk holding the old
--     edge (labelled "straddle": its ring columns are expected to change).
-- It also prints the terrain field's construction (CPU seconds and the Lua
-- heap it keeps, after a full collection) and a digest per section.
local repo, seed, out_path = arg[1], arg[2], arg[3]
assert(repo and seed and seed:match("^%d+$") and out_path,
	"usage: compare.lua REPO SEED OUT")

-- The old bounds this comparison is about (fixed, not read from REPO).
local OLD = {min_x = -3740, max_x = 3740, min_z = -3340, max_z = 3340}

-- Time and weigh the terrain field's construction: wrap terrain_field.lua's
-- `new` the first time any module loads it.
local field_builds = {}
do
	local real_dofile = dofile
	_G.dofile = function(path)
		local result = real_dofile(path)
		if type(path) == "string" and path:match("/terrain_field%.lua$") and
				type(result) == "function" then
			return function(data)
				local module = result(data)
				local new = module.new
				module.new = function(...)
					collectgarbage("collect") collectgarbage("collect")
					local kib0, t0 = collectgarbage("count"), os.clock()
					local field = new(...)
					local t1 = os.clock()
					collectgarbage("collect") collectgarbage("collect")
					field_builds[#field_builds + 1] = {seconds = t1 - t0,
						kib = collectgarbage("count") - kib0, field = field}
					return field
				end
				return module
			end
		end
		return result
	end
end

local t_start = os.clock()
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local build_seconds = os.clock() - t_start
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local function hex(bytes) return common.hex(R.sha(bytes)) end
local S = R.built.zones_session

local file = assert(io.open(out_path, "w"))
local section_parts = {}
local section
local function emit(line)
	file:write(line, "\n")
	local parts = section_parts[section]
	parts[#parts + 1] = line
end
local function begin(name)
	section = name
	section_parts[name] = {}
	file:write("# ", name, "\n")
end

-- 1. Layout and placement.
begin("layout")
emit("roster " .. tostring(R.built.anchor_roster.sha256))
emit("placement " .. hex(R.main.placement_layout_text()))
emit("water " .. hex(R.main.water_layout_text()))
emit("roads " .. hex(R.main.road_layout_text()))
emit("capitals " .. hex(R.main.capital_layout_text()))
emit("trees " .. tostring(R.built.manifest.values.r6_generated_templates_sha256))
do
	local prepared = R.main.prepared_handover()
	local rows = R.main.settlement_sockets(R.built)
	local lines = {}
	for _, row in ipairs(rows) do
		local b = prepared[row.key] and prepared[row.key].bounds
		lines[#lines + 1] = ("settlement %s %s %d %d %s"):format(row.key, row.slot,
			row.anchor.x, row.anchor.z, b and ("%d,%d,%d..%d,%d,%d"):format(b.min.x,
				b.min.y, b.min.z, b.max.x, b.max.y, b.max.z) or "-")
	end
	table.sort(lines)
	for _, line in ipairs(lines) do emit(line) end
end

-- 2. Columns.
local function text(value) return value == nil and "-" or tostring(value) end
local land_columns = {}
local function column(x, z)
	local class = S.water_class_at(x, z)
	local h = S.terrain_height_at(x, z)
	local surface = {x = x, y = math.max(h, 1) + 1, z = z}
	emit(("%d %d %s %s %s %d %s %s %s %s %s"):format(x, z, class, text(S.id_at(x, z)),
		text(S.biome_at(x, z)), h, text(S.surface_mob_level_at(x, z)),
		text(S.territory_rule_at(surface)), text(S.pvp_rule_at(surface)),
		text(S.mob_level_at(surface)), text(S.mob_level_at({x = x, y = -600, z = z}))))
	if class == "land" then land_columns[#land_columns + 1] = {x, z, h} end
end
local BAND = 512
local function in_band(x, z)
	return x - OLD.min_x < BAND or OLD.max_x - x < BAND or
		z - OLD.min_z < BAND or OLD.max_z - z < BAND
end
begin("columns")
local sampled = 0
for z = OLD.min_z + 3, OLD.max_z, 8 do
	for x = OLD.min_x + 3, OLD.max_x, 8 do
		if in_band(x, z) or ((x - OLD.min_x - 3) % 32 == 0 and
				(z - OLD.min_z - 3) % 32 == 0) then
			column(x, z)
			sampled = sampled + 1
		end
	end
end
for x = OLD.min_x, OLD.max_x, 4 do
	column(x, OLD.min_z) column(x, OLD.max_z)
	sampled = sampled + 2
end
for z = OLD.min_z + 4, OLD.max_z - 4, 4 do
	column(OLD.min_x, z) column(OLD.max_x, z)
	sampled = sampled + 2
end

-- 3. The terrain field itself, exactly (17 significant digits): its surface
-- (land as the zones session classifies the column), the coast distance and
-- the zone character channels, every 8 nodes within 512 nodes of an old edge.
-- Its grids are where a larger extent could move a value (the grid lattice,
-- the box blur's edge, the coast chamfer).
begin("field")
do
	local field = assert(field_builds[1], "terrain field was not built").field
	for z = OLD.min_z + 3, OLD.max_z, 8 do
		for x = OLD.min_x + 3, OLD.max_x, 8 do
			if in_band(x, z) then
				local land = S.water_class_at(x, z) == "land"
				local p = field.params_at(x, z)
				local parts = {}
				for c = 1, #p do parts[c] = ("%.17g"):format(p[c]) end
				emit(("%d %d %.17g %.17g %s"):format(x, z, field.height_at(x, z, land),
					field.coast_signed(x, z), table.concat(parts, " ")))
			end
		end
	end
end

-- 4. Chunks near the old edges.
begin("chunks")
local function origins(lo, hi)
	-- the chunk origins whose chunk and 16-node shell lie inside [lo, hi]
	local inside = {}
	for k = math.floor((lo + 16 + 32) / 80), math.floor((hi + 32) / 80) do
		local o = -32 + 80 * k
		if o - 16 >= lo and o + 79 + 16 <= hi then inside[#inside + 1] = o end
	end
	return inside
end
local ox, oz = origins(OLD.min_x, OLD.max_x), origins(OLD.min_z, OLD.max_z)
-- {label, axis, the outermost row with its shell inside, the origin holding
-- the old edge}
local sides = {
	{"west", "x", ox[1], R.origin(OLD.min_x)},
	{"east", "x", ox[#ox], R.origin(OLD.max_x)},
	{"south", "z", oz[1], R.origin(OLD.min_z)},
	{"north", "z", oz[#oz], R.origin(OLD.max_z)},
}
-- Highest land per chunk column, from the sampled land columns.
local land_top = {}
for _, c in ipairs(land_columns) do
	local key = R.origin(c[1]) .. "," .. R.origin(c[2])
	if not land_top[key] or c[3] > land_top[key] then land_top[key] = c[3] end
end
local function chunk(label, x0, z0, ground)
	local minp = {x = x0, y = R.origin(math.max(ground, 1)), z = z0}
	local result = R.chunk(minp)
	emit(("%s %d %d %d %s %s"):format(label, minp.x, minp.y, minp.z, result.data_hash,
		hex(result.candidates)))
end
-- The chunk columns holding land, each with its outermost land column per side.
local land_chunks = {}
for key, top in pairs(land_top) do
	local x0, z0 = key:match("^(%-?%d+),(%-?%d+)$")
	land_chunks[#land_chunks + 1] = {x = tonumber(x0), z = tonumber(z0), top = top}
end
local function edge_gap(c, label)
	if label == "west" then return c.x - OLD.min_x end
	if label == "east" then return OLD.max_x - (c.x + 79) end
	if label == "south" then return c.z - OLD.min_z end
	return OLD.max_z - (c.z + 79)
end
local chunk_count = 0
for _, side in ipairs(sides) do
	local label, axis, row, straddle = side[1], side[2], side[3], side[4]
	local along = axis == "x" and oz or ox
	-- the three land chunks nearest to this edge (ties by x, then z)
	table.sort(land_chunks, function(a, b)
		local ga, gb = edge_gap(a, label), edge_gap(b, label)
		if ga ~= gb then return ga < gb end
		if a.x ~= b.x then return a.x < b.x end
		return a.z < b.z
	end)
	for index = 1, math.min(3, #land_chunks) do
		local c = land_chunks[index]
		chunk(label .. " land", c.x, c.z, c.top)
		chunk_count = chunk_count + 1
	end
	local mid = along[math.floor(#along / 2) + 1]
	local x0, z0 = row, mid
	if axis == "z" then x0, z0 = mid, row end
	chunk(label .. " sea", x0, z0, 1)
	x0, z0 = straddle, mid
	if axis == "z" then x0, z0 = mid, straddle end
	chunk(label .. " straddle", x0, z0, 1)
	chunk_count = chunk_count + 2
end
file:close()

print(("seed %s: runtime built in %.1f s CPU; %d columns (%d land), %d chunks; %.1f s total")
	:format(seed, build_seconds, sampled, #land_columns, chunk_count, os.clock() - t_start))
for index, b in ipairs(field_builds) do
	print(("terrain field build %d: %.2f s CPU, %.0f KiB kept"):format(index, b.seconds, b.kib))
end
for _, name in ipairs({"layout", "columns", "field", "chunks"}) do
	print(("%-8s %s (%d lines)"):format(name, hex(table.concat(section_parts[name], "\n")):sub(1, 16),
		#section_parts[name]))
end
