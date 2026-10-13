-- Round 47 lane TC: the memory the capitals' city trees hold, and that their
-- output does not depend on chunk order or on a release in between, through
-- the seed fleet's runtime and the real writer.
--
--   luajit tools/r47_tc/city_memory.lua REPO SEED
--
-- Per capital: what one city-trees object holds once its whole city is
-- decided (built as the successor builds it, `tools/r47_tc/city_trees.lua`;
-- its memos sized, the planner's own caches left out); then, through the
-- real writer, the 3 x 3 mapchunks round its anchor in order, 70 plans far
-- away (the idle release, `r7_settlement.lua` M.IDLE_RELEASE: the successor's
-- release count must rise), and the same chunks in reverse order: every
-- chunk's written bytes must equal the first pass's.
local repo, seed = arg[1], arg[2]
assert(repo and seed, "usage: city_memory.lua REPO SEED")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local zones = R.built.zones_session
local roster = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua").roster
local function heap()
	collectgarbage("collect")
	collectgarbage("collect")
	return collectgarbage("count") / 1024
end
local far = {x = R.origin(3600), y = R.origin(1), z = R.origin(3200)}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local native = dofile(wp40 .. "/r7_native.lua")
local ps = R.main.build_authority(native.identities()).planner_source
local function upvalue(fn, wanted)
	for index = 1, 255 do
		local name, value = debug.getupvalue(fn, index)
		if name == nil then break end
		if name == wanted then return value end
	end
	error("upvalue " .. wanted .. " not found")
end
local prepared_of = {}
for _, row in ipairs(upvalue(R.main.settlement_sockets, "settlements")) do
	prepared_of[row.profile.key] = row.prepared
end
local function column(x, z)
	local _, _, _, _, _, terrain_y, water_y = ps.column_values_at(x, z)
	local road = ps.road_column_at and ps.road_column_at(x, z) == "surface" or false
	if type(water_y) ~= "number" or water_y <= terrain_y then water_y = nil end
	return terrain_y, water_y, road
end
local function green_heap(key, anchor)
	local rects, city = {}, nil
	for _, b in ipairs(prepared_of[key].blueprints) do
		if b.descriptor.kind == "reference" then
			local rect = settlement.plot_rect(b, anchor.x, anchor.z)
			rect.turns = b.descriptor.turns or 0
			rects[#rects + 1] = rect
		elseif b.descriptor.kind == "overlay" then city = b.city end
	end
	local box = {min_x = anchor.x - 270, max_x = anchor.x + 270,
		min_z = anchor.z - 270, max_z = anchor.z + 270}
	-- the columns come from a table filled by a first pass, so the planner's
	-- own column cache (which is not the city trees' memory) stays out
	local answers = {}
	local function recorded(x, z)
		local key = z * 131072 + x
		local a = answers[key]
		if not a then
			local g, w, r = column(x, z)
			a = {g, w, r}
			answers[key] = a
		end
		return a[1], a[2], a[3]
	end
	city.green({x = anchor.x, z = anchor.z}, rects, recorded).cells(box)
	local green = city.green({x = anchor.x, z = anchor.z}, rects, recorded)
	green.cells(box)
	-- the memos the object keeps (its slots' writes and cell maps, the clear
	-- and column answers), sized at LuaJIT's 64-bit object sizes: a table of
	-- up to six array slots ~ 80 bytes, a hash entry ~ 40
	local slots_in = upvalue(green.cells, "slots_in")
	local viable = upvalue(slots_in, "viable")
	local fit = upvalue(viable, "fit")
	local clear = upvalue(fit, "clear")
	local bytes = 0
	for _, v in pairs(upvalue(viable, "viable_memo")) do
		bytes = bytes + 40
		if v then
			bytes = bytes + 120 + #v.writes * (80 + 8)
			for _ in pairs(v.cells) do bytes = bytes + 40 end
		end
	end
	for _ in pairs(upvalue(clear, "clear_memo")) do bytes = bytes + 40 end
	for _ in pairs(upvalue(upvalue(clear, "leaf_clear"), "leaf_memo")) do bytes = bytes + 40 end
	for _ in pairs(upvalue(upvalue(fit, "col"), "column_memo")) do bytes = bytes + 40 + 72 end
	return bytes / 1048576
end
local function releases(key)
	local m = R.built.session.metrics().settlements or {}
	local row = m[key] or {}
	return row.release_calls or 0
end
local all_equal = true
for _, profile in ipairs(roster) do
	if profile.slot == "capital" then
		local anchor = zones.anchor(profile.zone_id, profile.slot)
		local chunks = {}
		for dz = -1, 1 do
			for dx = -1, 1 do
				local x, z = anchor.x + dx * 80, anchor.z + dz * 80
				chunks[#chunks + 1] = {x = R.origin(x), y = R.origin(math.max(R.ground_at(x, z), 1)),
					z = R.origin(z)}
			end
		end
		local held = green_heap(profile.key, anchor)
		local first = {}
		for i, minp in ipairs(chunks) do first[i] = R.chunk(minp).data_hash end
		local r0 = releases(profile.key)
		for k = 0, 69 do
			local minp = {x = far.x - (k % 10) * 80, y = far.y, z = far.z - math.floor(k / 10) * 80}
			R.built.session.plan_slice(minp, {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79})
		end
		local r1 = releases(profile.key)
		local equal = true
		for i = #chunks, 1, -1 do
			if R.chunk(chunks[i]).data_hash ~= first[i] then equal = false end
		end
		all_equal = all_equal and equal
		print(("%-12s city trees hold ~%.1f MB once the whole city is decided; releases " ..
			"%d -> %d over 70 far plans; reverse order after it: %s"):format(profile.key,
			held, r0, r1, equal and "byte-identical" or "DIFFERS"))
	end
end
print(all_equal and "all capitals byte-identical" or "OUTPUT DIFFERS")
if not all_equal then error("city trees differ by chunk order", 0) end
