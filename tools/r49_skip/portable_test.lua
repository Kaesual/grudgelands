-- Round 49 lane SKIP portable fixture (LuaJIT): the untouched-chunk tests of
-- wp40/air_chunks.lua.
--
--   luajit tools/r49_skip/portable_test.lua REPO [SEED]
--
-- 1. The authored floor the rock-below test uses is the R5 manifest's.
-- 2. Rock below on a synthetic envelope: every bound just above and just
--    below (the authored floor with its margin, the chunk grid, a fitted box
--    bottom, a box one column beside the owner and one on its edge); the test
--    never reads a column.
-- 3. Air above: the owner-first order decides exactly as the Round 23 code
--    (a verbatim reference copy below) over random envelopes, boxes,
--    heightmaps and call orders, and an owner column that reaches the chunk
--    decides without reading the reach ring.
-- 4. The real runtime of one seed (tools/seed_fleet/runtime.lua, default
--    12345, the mgprof seed): the test on chunks under every settlement
--    anchor, under the lowest fitted box, the highest mountain, a dragon
--    channel and a deep ocean column, and the two mgprof corpus columns at
--    their underground heights. Every chunk it skips is also planned and
--    written by the real writer against the fake VoxelManip, which must
--    answer "noop_equal_content" (no setter called: the bytes stay v7's);
--    the fill-floor chunk -112..-33 is never skipped.
-- Prints "R49 SKIP PORTABLE PASS checks=<n> skipped=<n>" or raises.
local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO [SEED]")
local seed = arg[2] or "12345"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local air_factory = dofile(wp40 .. "/air_chunks.lua")
local function chunk(x, y, z)
	return {x = x, y = y, z = z}, {x = x + 79, y = y + 79, z = z + 79}
end

-- 1. The authored floor.
do
	local values = dofile(wp40 .. "/r7_r6_manifest.lua")().r5_manifest_values
	local copy = {}
	for key, value in pairs(values) do copy[key] = value end
	local validated = dofile(wp40 .. "/mapgen_manifest.lua").validate(copy)
	local probe = air_factory({tile_bounds = function() return 1, math.huge, -math.huge end,
		column_bounds = function() return 0, 0 end}, 1)
	check(validated.authored_floor == probe.AUTHORED_FLOOR and probe.AUTHORED_FLOOR == -37,
		"the rock-below floor is the R5 manifest's authored floor")
	check(probe.MARGIN == 16, "one mapblock of margin")
end

-- A synthetic envelope: fitted boxes as preparation_source.lua answers them
-- (bottom and top of every box over the footprint) and one column height.
local function synthetic(boxes, column_high, reach)
	local source = {calls = 0, ring_calls = 0, owner = nil}
	function source.tile_bounds(lo, hi)
		local bottom, top = math.huge, -math.huge
		for _, b in ipairs(boxes) do
			if lo.x <= b.x_max and hi.x >= b.x_min and lo.z <= b.z_max and hi.z >= b.z_min then
				bottom, top = math.min(bottom, b.y_min), math.max(top, b.y_max)
			end
		end
		return reach or 4, bottom, top
	end
	function source.column_bounds(x, z)
		source.calls = source.calls + 1
		local o = source.owner
		if o and (x < o.x0 or x > o.x1 or z < o.z0 or z > o.z1) then
			source.ring_calls = source.ring_calls + 1
		end
		local high = column_high(x, z)
		return high - 5, high
	end
	return source
end

-- 2. Rock below.
do
	local function no_columns() error("rock below read a column") end
	local function below(boxes, x, y, z)
		local source = synthetic(boxes, no_columns)
		local test = air_factory(source, 1)
		return test.below(chunk(x, y, z))
	end
	check(not below({}, 48, -112, 48), "the fill-floor chunk -112..-33 runs")
	check(below({}, 48, -192, 48), "the chunk -192..-113 is skipped")
	check(below({}, 48, -1072, 48), "a deep chunk is skipped")
	check(not below({}, 48, -32, 48) and not below({}, 48, 48, 48), "surface chunks run")
	-- the floor with its margin: top + 16 < -37
	check(below({}, 48, -54 - 79, 48), "top -54: skipped")
	check(not below({}, 48, -53 - 79, 48), "top -53: within the margin, runs")
	-- a fitted box over the owner: its bottom more than 16 above the top
	local function box(y_min, x_min, x_max)
		return {x_min = x_min or 60, x_max = x_max or 70, z_min = 60, z_max = 70,
			y_min = y_min, y_max = y_min + 30}
	end
	check(below({box(-96)}, 48, -192, 48), "a box bottom 17 above the top: skipped")
	check(not below({box(-97)}, 48, -192, 48), "a box bottom 16 above the top: runs")
	check(not below({box(-500)}, 48, -192, 48),
		"a chunk above a deep box runs (the test reads its bottom only)")
	check(not below({box(-500)}, 48, -512, 48), "a deep box inside the chunk: runs")
	check(not below({box(-500)}, 48, -592, 48), "the box bottom 3 above the top: runs")
	check(below({box(-500)}, 48, -672, 48), "a chunk wholly below the box: skipped")
	check(below({box(-500, 128, 140)}, 48, -192, 48), "a box one column beside the owner")
	check(not below({box(-500, 127, 140)}, 48, -192, 48), "a box on the owner's edge")
	check(below({box(40), box(-90)}, 48, -192, 48), "boxes above the floor do not matter")
end

-- 3. Air above: the Round 23 classifier, verbatim, as the reference.
local function round23(bounds_source, water_level)
	local MARGIN = 16
	local MEMO = 64
	local memo, keys, slot = {}, {}, 0
	local function writer_top(minp, maxp)
		local key = minp.x .. ":" .. minp.z .. ":" .. maxp.x .. ":" .. maxp.z
		local top = memo[key]
		if top then return top end
		local radius, _, box_top = bounds_source.tile_bounds(minp, maxp)
		top = box_top
		for z = minp.z - radius, maxp.z + radius do
			for x = minp.x - radius, maxp.x + radius do
				local _, high = bounds_source.column_bounds(x, z)
				if high > top then top = high end
			end
		end
		slot = slot % MEMO + 1
		if keys[slot] then memo[keys[slot]] = nil end
		keys[slot], memo[key] = key, top
		return top
	end
	local M = {}
	function M.untouched(minp, maxp, get_heightmap)
		if minp.y <= water_level then return false end
		local heightmap = get_heightmap()
		local columns = (maxp.x - minp.x + 1) * (maxp.z - minp.z + 1)
		if type(heightmap) ~= "table" or #heightmap ~= columns then return false end
		local low = minp.y
		for index = 1, columns do
			if heightmap[index] >= low then return false end
		end
		return low > writer_top(minp, maxp) + MARGIN
	end
	return M
end
do
	local state = 20261015
	local function random(n)
		state = (state * 1103515245 + 12345) % 2147483648
		return state % n
	end
	local air_map, ground_map = {}, {}
	for index = 1, 6400 do air_map[index], ground_map[index] = -31007, -31007 end
	ground_map[3210] = 250
	local function air() return air_map end
	local function ground() return ground_map end
	local agree = 0
	for world = 1, 12 do
		-- a rolling surface with a few peaks and boxes
		local base = random(120)
		local peaks = {}
		for _ = 1, random(4) do
			peaks[#peaks + 1] = {random(400) - 200, random(400) - 200, base + random(300)}
		end
		local function high(x, z)
			for _, p in ipairs(peaks) do
				if p[1] == x and p[2] == z then return p[3] end
			end
			return base + (x + z) % 7
		end
		local boxes = {}
		for _ = 1, random(3) do
			local x, z = random(400) - 200, random(400) - 200
			boxes[#boxes + 1] = {x_min = x, x_max = x + random(40), z_min = z,
				z_max = z + random(40), y_min = random(60), y_max = 60 + random(400)}
		end
		local reach = 1 + random(9)
		local new = air_factory(synthetic(boxes, high, reach), 1)
		local old = round23(synthetic(boxes, high, reach), 1)
		for _ = 1, 60 do
			local x = (random(5) - 2) * 80 - 32
			local z = (random(5) - 2) * 80 - 32
			local y = random(8) * 80 - 32
			local hm = random(5) == 0 and ground or air
			local minp, maxp = chunk(x, y, z)
			check(new.untouched(minp, maxp, hm) == old.untouched(minp, maxp, hm),
				("air decision as Round 23, world %d chunk %d,%d,%d"):format(world, x, y, z))
			agree = agree + 1
		end
	end
	check(agree == 720, "720 decisions compared")
	-- An owner column reaching the chunk decides before the ring is read; a
	-- chunk above it then reads the ring once and is memoized.
	local source = synthetic({}, function(x, z) return (x == 60 and z == 60) and 40 or 10 end, 8)
	source.owner = {x0 = 48, x1 = 127, z0 = 48, z1 = 127}
	local test = air_factory(source, 1)
	check(not test.untouched({x = 48, y = 48, z = 48}, {x = 127, y = 127, z = 127}, air),
		"an owner column 8 under the chunk keeps it on the full path")
	check(source.ring_calls == 0 and source.calls <= 80 * 13,
		"the reaching owner column decides without the ring")
	check(test.untouched({x = 48, y = 128, z = 48}, {x = 127, y = 207, z = 127}, air),
		"the chunk above is native air above the envelope")
	local after = source.calls
	check(source.ring_calls == 96 * 96 - 80 * 80, "the ring read once")
	check(test.untouched({x = 48, y = 208, z = 48}, {x = 127, y = 287, z = 127}, air) and
		source.calls == after, "and memoized")
	check(not test.untouched({x = 48, y = 208, z = 48}, {x = 127, y = 287, z = 127}, ground),
		"native ground keeps the full path")
end

-- 4. The real runtime.
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local zones = R.built.zones_session
local test = air_factory(R.built.writer_bounds, 1)
local function upvalue(fn, wanted)
	for index = 1, 255 do
		local name, value = debug.getupvalue(fn, index)
		if name == nil then break end
		if name == wanted then return value end
	end
	error("upvalue " .. wanted .. " not found")
end
local boxes = upvalue(R.built.writer_bounds.tile_bounds, "boxes")
check(#boxes > 100, "the fitted settlement and anchor boxes are read")
local columns = {}
local function add(label, x, z) columns[#columns + 1] = {label, x, z} end
for _, row in ipairs(R.main.settlement_sockets(R.built)) do
	add("under " .. row.key, row.anchor.x, row.anchor.z)
end
local lowest = boxes[1]
for _, b in ipairs(boxes) do if b.y_min < lowest.y_min then lowest = b end end
add(("under the lowest box (bottom %d)"):format(lowest.y_min), lowest.x_min, lowest.z_min)
local peak, channel, ocean = {-math.huge}, nil, nil
for x = -3712, 3712, 32 do
	for z = -3328, 3328, 32 do
		local h = zones.terrain_height_at(x, z)
		if h > peak[1] then peak = {h, x, z} end
		local class = zones.water_class_at(x, z)
		if not channel and class == "immutable_dragon_channel" then channel = {x, z} end
		if not ocean and class == "deep_ocean" and h < -20 then ocean = {x, z} end
	end
end
add(("under the highest mountain (y %d)"):format(peak[1]), peak[2], peak[3])
if channel then add("under a dragon channel", channel[1], channel[2]) end
if ocean then add("under deep ocean", ocean[1], ocean[2]) end
add("mgprof column A", 368 + 40, -2352 + 40)
add("mgprof column B", 528 + 40, -2192 + 40)
local skipped, writes = 0, 0
for index, column in ipairs(columns) do
	local x, z = R.origin(column[2]), R.origin(column[3])
	-- the highest chunk wholly more than 16 below the authored floor and the
	-- fitted boxes over this footprint, and the chunk above it, which runs
	local _, bottom = R.built.writer_bounds.tile_bounds(chunk(x, 0, z))
	local limit = math.min(-37, bottom) - 17
	local first = R.origin(limit)
	if first + 79 > limit then first = first - 80 end
	local minp, maxp = chunk(x, first + 80, z)
	check(not test.below(minp, maxp), ("%s: chunk %d,%d,%d runs"):format(column[1], x,
		first + 80, z))
	check(first + 80 >= -112, column[1] .. ": the fill-floor chunk -112..-33 runs")
	local depths = {first}
	if index > #columns - 2 then depths = {first, -512, -1072} end
	for _, y in ipairs(depths) do
		minp, maxp = chunk(x, y, z)
		local skip = test.below(minp, maxp)
		check(skip, ("%s: chunk %d,%d,%d is skipped"):format(column[1], x, y, z))
		local written = R.chunk(minp)
		writes = writes + 1
		check(written.result == "noop_equal_content",
			("%s: the writer changes nothing in %d,%d,%d (%s)"):format(column[1], x, y, z,
				tostring(written.result)))
		skipped = skipped + 1
	end
end
check(writes == skipped and skipped >= #columns, "every skipped chunk written once")
print(("R49 SKIP PORTABLE PASS checks=%d skipped=%d seed=%s columns=%d lowest_box=%d " ..
	"peak=%d channel=%s ocean=%s"):format(checks, skipped, seed, #columns, lowest.y_min,
	peak[1], channel and "yes" or "no", ocean and "yes" or "no"))
