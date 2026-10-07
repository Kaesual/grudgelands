return function(repo)
-- Portable Round 24 Lane B fixture (underground fill); LuaJIT only.
-- Loads the production seams of wp40/r6_settlement.lua (fill predicate,
-- resource-host base rule, shallow strata, mountain-interior layers) and
-- wp40/r7_native.lua (native allowlist with the decorative nests) and checks
-- them on synthetic columns. Returns a report; any failed check raises.
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local function hex_sha(bytes) return common.hex(sha(bytes)) end
local S = dofile(wp40 .. "/r6_settlement.lua")
local out = {}
local function say(fmt, ...) out[#out + 1] = string.format(fmt, ...) end
local function check(value, message)
	if not value then error("r24 fixture: " .. message, 2) end
end
local floor = math.floor

-- Content ids of the synthetic chunk.
local AIR, STONE, DIRT, GRASS, COAL, WATER = 0, 1, 2, 3, 4, 5
local names = {[AIR] = "air", [STONE] = "default:stone", [DIRT] = "default:dirt",
	[GRASS] = "default:dirt_with_grass", [COAL] = "default:stone_with_coal",
	[WATER] = "default:water_source"}
local cid_by_name = {}
for cid, name in pairs(names) do cid_by_name[name] = cid end
local function cid_of(name)
	local cid = cid_by_name[name]
	if not cid then
		cid = 100 + #names + 1
		while names[cid] do cid = cid + 1 end
		names[cid], cid_by_name[name] = name, cid
	end
	return cid
end

-------------------------------------------------------------------------------
-- 1. Fill predicate (ruling 10/11/12 provenance).
local fill = S.r24_fill_stone
check(fill(AIR, STONE, 0, 27, STONE), "R5 fill over native air is fill")
check(fill(WATER, STONE, 0, 27, STONE), "R5 fill over native water is fill")
check(not fill(STONE, STONE, 0, 27, STONE), "native stone inside the fill run is native")
check(not fill(AIR, STONE, 2, 27, STONE), "surface skin / P7 write is not fill")
check(not fill(AIR, STONE, 0, 21, STONE), "anchor-grade fill (opcode 21) is not terrain fill")
check(not fill(AIR, STONE, 0, 15, STONE), "foundation fill is not terrain fill")
check(not fill(AIR, AIR, 0, 27, STONE), "preserved native cave air is not fill")
check(not fill(COAL, COAL, 0, 27, STONE), "native ore stays native ore")
check(not fill(AIR, STONE, 0, nil, STONE), "no R5 run, no fill")
say("fill predicate: 9/9 cases")

-------------------------------------------------------------------------------
-- 2. Resource-host base rule (ruling 10).
local host = S.r24_resource_host_base
local T2 = 50 -- a deeper tier host
-- native host, unchanged by the old rule
check(host(STONE, STONE, 0, 0, nil, nil, STONE, STONE), "native stone, no run")
check(host(STONE, STONE, 0, 0, 5, 27, STONE, STONE), "native stone in terrain fill run")
for _, priority in ipairs({3, 6}) do
	check(not host(STONE, STONE, 0, 0, priority, 17, STONE, STONE),
		"predecessor priority " .. priority .. " excludes native stone")
end
-- user ruling 2026-10-07: an anchor's grading or platform and a hard
-- foundation are ordinary rock (the protected volume is the column
-- predicate's business)
check(host(STONE, STONE, 0, 0, 4, 21, STONE, STONE), "native stone under a grading")
check(host(STONE, STONE, 0, 0, 2, 15, STONE, STONE), "native stone under a foundation")
check(not host(STONE, STONE, 0, 0, 4, 22, STONE, STONE), "a path's walking surface is no host")
check(not host(STONE, STONE, 0, 0, 2, 16, STONE, STONE),
	"a foundation's walking surface is no host")
check(not host(STONE, DIRT, 2, 0, 5, 27, STONE, STONE), "filler over native stone")
check(host(STONE, COAL, 24, 3, 5, 27, STONE, STONE), "claimed native host keeps its base")
check(not host(STONE, STONE, 0, 1, 5, 27, STONE, STONE), "occupied cell")
check(host(T2, T2, 0, 0, nil, nil, T2, STONE), "native tier rock stays a host")
-- fill host
check(host(AIR, STONE, 0, 0, 5, 27, STONE, STONE), "fill stone is a default:stone host")
check(host(AIR, COAL, 24, 3, 5, 27, STONE, STONE), "claimed fill keeps its base")
check(not host(AIR, STONE, 0, 0, 5, 27, T2, STONE), "fill never hosts a deeper tier")
check(not host(AIR, STONE, 2, 0, 5, 27, STONE, STONE), "skin stone (opcode 2) is no host")
check(host(AIR, STONE, 0, 0, 4, 21, STONE, STONE), "anchor-grade fill is a host")
check(host(AIR, STONE, 0, 0, 2, 15, STONE, STONE), "foundation fill is a host")
check(not host(AIR, STONE, 0, 0, 4, 21, T2, STONE), "grading fill never hosts a deeper tier")
check(not host(AIR, STONE, 0, 0, 3, 17, STONE, STONE), "seal stone is no host")
check(not host(AIR, cid_of("grug_materials:slate"), 2, 0, 5, 27, STONE, STONE),
	"layer rock is no host")
check(not host(AIR, AIR, 0, 0, 5, 27, STONE, STONE), "air is no host")
check(not host(AIR, STONE, 0, 1, 5, 27, STONE, STONE), "reserved fill is no host")
say("resource-host base rule: 23/23 cases")

-------------------------------------------------------------------------------
-- Synthetic owner: columns with a native top and a planned surface.  R5 has
-- filled [max(-37, native+1), terrain-1] with stone; P7 wrote the filler
-- (dirt, opcode 2) and the top (grass, opcode 1).
local FULL_SEED = "10536739806879207652"
local zones_source = {zones = {
	{id = "sunscar", primary_relief_id = "badlands"},
	{id = "stormvault", primary_relief_id = "mountain"},
	{id = "reedmarsh", primary_relief_id = "wetland_delta"},
}}
local function new_world(box, column)
	local ex, ey = box.max_x - box.min_x + 1, box.max_y - box.min_y + 1
	local w = {box = box, column = column, original = {}, final = {}, intent = {}}
	local function index_at(x, y, z)
		return (z - box.min_z) * ex * ey + (y - box.min_y) * ex + (x - box.min_x) + 1
	end
	w.index_at = index_at
	for z = box.min_z, box.max_z do
		for x = box.min_x, box.max_x do
			local c = column(x, z)
			for y = box.min_y, box.max_y do
				local i = index_at(x, y, z)
				local native = y <= c.native_y and STONE or AIR
				local final, intent = native, 0
				if y <= c.terrain_y - 1 and y >= -37 and native == AIR then final = STONE end
				if y == c.terrain_y then final, intent = GRASS, 1
				elseif y < c.terrain_y and y >= c.terrain_y - 4 then final, intent = DIRT, 2
				elseif y > c.terrain_y then final = AIR end
				w.original[i], w.final[i], w.intent[i] = native, final, intent
			end
		end
	end
	function w.opcode_at(x, y, z)
		local c = column(x, z)
		if y >= -37 and y <= c.terrain_y - 1 then return 27 end
		if y == c.terrain_y then return 28 end
		if y > c.terrain_y then return 26 end
		return nil
	end
	function w.column_values_at(x, z)
		local c = column(x, z)
		-- water_class, _, zone, biome, _, terrain_y, water_y, _, _, functional,
		-- _, _, _, transition, _, _, _, _, _, hard
		return c.water_class or "land", nil, c.zone, c.biome, nil, c.terrain_y,
			nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
	end
	function w.fill_stone_at(i, x, y, z)
		return fill(w.original[i], w.final[i], w.intent[i], w.opcode_at(x, y, z), STONE)
	end
	w.writes = {}
	function w.write(x, y, z, ref)
		local i = index_at(x, y, z)
		w.final[i], w.intent[i] = ref, 2
		w.writes[#w.writes + 1] = x .. "," .. y .. "," .. z .. "=" .. names[ref]
	end
	return w
end
local function content_ref(name) return cid_of(name) end

local strata = S.r8_strata_new(FULL_SEED, zones_source)
local function run_strata(w, steep_x, excluded_x, info, steep_fn)
	return S.r8_apply_strata({min_x = w.box.min_x, min_y = w.box.min_y,
		min_z = w.box.min_z, max_x = w.box.max_x, max_y = w.box.max_y,
		max_z = w.box.max_z, floor_y = -37, original_data = w.original,
		stone_cid = STONE, index_at = w.index_at, column_info = info,
		column_values_at = w.column_values_at,
		static_exclusion_values_at = function(x) if x == excluded_x then return "poi" end end,
		select_surface = function(_, x)
			return {filler_depth = 4, steep = steep_fn and steep_fn(x) or x == steep_x}
		end,
		strata = strata, content_ref = content_ref, fill_stone_at = w.fill_stone_at,
		write = w.write})
end

-------------------------------------------------------------------------------
-- 3. Strata in fill (ruling 11): a column whose first 40 nodes are fill gets
-- exactly the bands the same column gets over native stone.
do
	local box = {min_x = 0, max_x = 11, min_y = -60, max_y = 80, min_z = 0, max_z = 3}
	local function native_column(x, z)
		return {terrain_y = 60 + (x % 3), native_y = 60 + (x % 3) - 1, zone = "stormvault",
			biome = x < 6 and "grug_crags" or "grug_savanna"}
	end
	local function fill_column(x, z)
		local c = native_column(x, z)
		c.native_y = c.terrain_y - 45
		return c
	end
	local a, b = new_world(box, native_column), new_world(box, fill_column)
	local wa = run_strata(a)
	local wb = run_strata(b)
	check(wa > 0 and wa == wb, "band count differs between native and fill columns")
	for index = 1, #a.writes do
		check(a.writes[index] == b.writes[index], "band differs: " .. a.writes[index])
	end
	-- nothing below the first 40 nodes, nothing in the filler
	for index = 1, #b.writes do
		local x, y = b.writes[index]:match("^(%-?%d+),(%-?%d+),")
		local c = fill_column(tonumber(x), 0)
		local depth = c.terrain_y - tonumber(y)
		check(depth >= 5 and depth <= 40, "band outside depth 5..40")
	end
	-- steep columns and excluded columns get no bands in the fill either
	local s = new_world(box, fill_column)
	run_strata(s, 2, 7)
	for index = 1, #s.writes do
		local x = tonumber(s.writes[index]:match("^(%-?%d+),"))
		check(x ~= 2 and x ~= 7, "steep or excluded column got a band")
	end
	-- the pre-Round-24 rule (native stone only) leaves the fill column bare
	local legacy = new_world(box, fill_column)
	legacy.fill_stone_at = function() return false end
	check(run_strata(legacy) == 0, "legacy rule should leave fill without bands")
	say("strata in fill: %d band voxels, identical to native columns; steep/excluded skip", wb)
end

-------------------------------------------------------------------------------
-- 4. Mountain-interior layers (ruling 12).
local layers = S.r24_fill_layers_new(FULL_SEED)
local FIRST = S.r24_layer_first_depth
check(FIRST == 41, "layers start below the 40-node band depth")
local function run_layers(w, lay, info)
	return S.r24_apply_fill_layers({min_x = w.box.min_x, min_y = w.box.min_y,
		min_z = w.box.min_z, max_x = w.box.max_x, max_y = w.box.max_y,
		max_z = w.box.max_z, floor_y = -37, index_at = w.index_at, column_info = info,
		column_values_at = w.column_values_at, layers = lay or layers,
		original_data = w.original, final_data = w.final, intent_opcode = w.intent,
		stone_cid = STONE,
		fill_stone_at = w.fill_stone_at, content_ref = content_ref, write = w.write})
end

-- Smooth offset: neighbouring columns differ by at most one node.
do
	local worst, lo, hi = 0, 99, -99
	for z = -300, 300, 7 do
		for x = -300, 300 do
			local o = layers.column_offset(x, z)
			local dx = math.abs(layers.column_offset(x + 1, z) - o)
			local dz = math.abs(layers.column_offset(x, z + 1) - o)
			worst = math.max(worst, dx, dz)
			lo, hi = math.min(lo, o), math.max(hi, o)
		end
	end
	check(worst <= 1, "column offset is not smooth")
	check(lo >= -5 and hi <= 5, "column offset outside +-5")
	say("column offset: range %d..%d, max neighbour step %d", lo, hi, worst)
end

-- A mountain: surface at 150..170, native v7 at y 0 in the west half and at
-- y 60 in the east half (a raised native shoulder), so fill, native stone
-- and the band depth all meet inside one owner.
local mountain_box = {min_x = -80, max_x = 79, min_y = -40, max_y = 175,
	min_z = 400, max_z = 559}
local function mountain_column(x, z)
	return {terrain_y = 150 + (x * 7 + z * 3) % 21, native_y = x < 0 and 0 or 60,
		zone = z < 480 and "stormvault" or "sunscar",
		biome = z < 480 and "grug_crags" or "grug_badlands"}
end
local shares, share_total = {}, 0
local layer_digest
do
	local w = new_world(mountain_box, mountain_column)
	run_strata(w)
	local band_writes = #w.writes
	w.writes = {}
	local before, before_intent = {}, {}
	for i = 1, #w.final do before[i], before_intent[i] = w.final[i], w.intent[i] end
	local t0 = os.clock()
	local written = run_layers(w)
	local seconds = os.clock() - t0
	check(written == #w.writes and written > 0, "layer writes")
	layer_digest = hex_sha(table.concat(w.writes, "\n"))
	-- Only fill voxels at depth >= 41 changed, and only to palette rock or
	-- pocket material.
	local allowed = {["default:gravel"] = true, ["default:dirt"] = true,
		["grug_materials:slate"] = true, ["grug_materials:granite"] = true,
		["grug_materials:basalt"] = true, ["default:desert_stone"] = true,
		["default:sandstone"] = true}
	local fill_interior = 0
	for z = mountain_box.min_z, mountain_box.max_z do
		for x = mountain_box.min_x, mountain_box.max_x do
			local c = mountain_column(x, z)
			for y = mountain_box.min_y, mountain_box.max_y do
				local i = w.index_at(x, y, z)
				local was_fill = fill(w.original[i], before[i], before_intent[i],
					w.opcode_at(x, y, z), STONE)
				if before[i] ~= w.final[i] then
					check(was_fill, "layer wrote outside the fill")
					check(c.terrain_y - y >= FIRST, "layer wrote above depth 41")
					check(allowed[names[w.final[i]]], "unexpected layer rock " .. names[w.final[i]])
				end
				if was_fill and c.terrain_y - y >= FIRST then
					fill_interior = fill_interior + 1
					local name = names[w.final[i]]
					shares[name] = (shares[name] or 0) + 1
				end
			end
		end
	end
	share_total = fill_interior
	local stone_share = shares["default:stone"] / fill_interior
	check(stone_share >= 0.85 and stone_share <= 0.95, "stone share " .. stone_share)
	say("mountain owner 160x216x160: %d band voxels, %d layer voxels in %d interior fill voxels",
		band_writes, written, fill_interior)
	local parts = {}
	local sorted = {}
	for name in pairs(shares) do sorted[#sorted + 1] = name end
	table.sort(sorted)
	for _, name in ipairs(sorted) do
		parts[#parts + 1] = string.format("%s %.2f%%", name, 100 * shares[name] / fill_interior)
	end
	say("interior fill shares: %s", table.concat(parts, ", "))
	say("layer pass: %.3f s for %d interior fill voxels (%.0f ns per voxel, LuaJIT)",
		seconds, fill_interior, 1e9 * seconds / fill_interior)
end

-- Chunk invariance: four 80x80 owners give the same writes as one 160x160.
do
	local merged = {}
	for _, qx in ipairs({-80, 0}) do
		for _, qz in ipairs({400, 480}) do
			local box = {min_x = qx, max_x = qx + 79, min_y = -40, max_y = 175,
				min_z = qz, max_z = qz + 79}
			local w = new_world(box, mountain_column)
			run_strata(w)
			w.writes = {}
			run_layers(w)
			for _, row in ipairs(w.writes) do merged[#merged + 1] = row end
		end
	end
	local whole = new_world(mountain_box, mountain_column)
	run_strata(whole)
	whole.writes = {}
	run_layers(whole)
	local function sorted(list)
		local copy = {}
		for i = 1, #list do copy[i] = list[i] end
		table.sort(copy)
		return table.concat(copy, "\n")
	end
	check(sorted(merged) == sorted(whole.writes), "owner split changes the layers")
	-- y split too: the owner [-40,39] + [40,175] equals the whole column
	local lower = new_world({min_x = -80, max_x = 79, min_y = -40, max_y = 39,
		min_z = 400, max_z = 559}, mountain_column)
	local upper = new_world({min_x = -80, max_x = 79, min_y = 40, max_y = 175,
		min_z = 400, max_z = 559}, mountain_column)
	run_layers(lower) run_layers(upper)
	local both = {}
	for _, row in ipairs(lower.writes) do both[#both + 1] = row end
	for _, row in ipairs(upper.writes) do both[#both + 1] = row end
	check(sorted(both) == sorted(whole.writes), "vertical owner split changes the layers")
	say("owner invariance: 4 horizontal and 2 vertical owners reproduce the whole")
end

-- Horizontal layers: within one zone, a layer voxel's neighbour one column
-- over carries the same rock at y +-1 (the offset step) unless a pocket or
-- the layer edge intervenes; measure the continuation rate.
do
	local same, total = 0, 0
	local z = 430
	for x = -300, 300 do
		local o0, o1 = layers.column_offset(x, z), layers.column_offset(x + 1, z)
		for y = 0, 120 do
			local r = layers.layer_at("stormvault", "grug_crags", y, o0)
			if r then
				total = total + 1
				if layers.layer_at("stormvault", "grug_crags", y - 1, o1) == r or
						layers.layer_at("stormvault", "grug_crags", y, o1) == r or
						layers.layer_at("stormvault", "grug_crags", y + 1, o1) == r then
					same = same + 1
				end
			end
		end
	end
	check(same == total, "a layer voxel lost its neighbour")
	say("horizontal continuity: %d/%d layer voxels continue in the next column", same, total)
end

-- Pockets stay inside their 16^3 lattice cell: gravel or dirt, or (B2) a
-- rock nest of the biome's decorative rocks.
do
	local cells, pocket_voxels, gravel, nests = {}, 0, 0, 0
	local nest_names = {}
	for z = 0, 63 do
		for y = 0, 63 do
			for x = 0, 63 do
				local p, loose = layers.pocket_at(x, y, z, "grug_badlands")
				if p then
					pocket_voxels = pocket_voxels + 1
					if p == "default:gravel" then gravel = gravel + 1 end
					if not loose then
						nests = nests + 1
						nest_names[p] = true
						check(p == "grug_materials:basalt", "badlands nests use the palette's rock")
					else
						check(p == "default:gravel" or p == "default:dirt", "loose pocket material")
					end
					cells[floor(x / 16) .. "," .. floor(y / 16) .. "," .. floor(z / 16)] = true
				end
			end
		end
	end
	local count = 0
	for _ in pairs(cells) do count = count + 1 end
	-- recompute each voxel's cell from its own lattice: a pocket voxel is always
	-- within radius 3 of a centre in [3,12], hence inside [0,15]
	check(count > 0 and count <= 64, "pocket cell count")
	check(nests > 0, "rock nests occur")
	say("pockets: %d of 64 lattice cells, %.2f%% of voxels (rock nests %.2f%%), %.0f%% of loose ones gravel",
		count, 100 * pocket_voxels / 262144, 100 * nests / 262144,
		100 * gravel / math.max(1, pocket_voxels - nests))
end

-- Seed and zone matter; the rule is deterministic.
do
	local again = S.r24_fill_layers_new(FULL_SEED)
	local other = S.r24_fill_layers_new("4242424242")
	local same_seed, other_seed = 0, 0
	for y = -37, 400 do
		local a = layers.layer_at("stormvault", "grug_crags", y, 0)
		if a == again.layer_at("stormvault", "grug_crags", y, 0) then same_seed = same_seed + 1 end
		if a == other.layer_at("stormvault", "grug_crags", y, 0) then other_seed = other_seed + 1 end
	end
	check(same_seed == 438, "same seed must repeat")
	check(other_seed < 438, "another seed must differ")
	local zone_diff = 0
	for y = -37, 400 do
		if (layers.layer_at("stormvault", "grug_crags", y, 0) ~= nil) ~=
				(layers.layer_at("sunscar", "grug_crags", y, 0) ~= nil) then
			zone_diff = zone_diff + 1
		end
	end
	check(zone_diff > 0, "zones must have their own slabs")
	say("determinism: same seed identical, other seed %d/438 equal, zones differ on %d y",
		other_seed, zone_diff)
end

-- Known answer: the layer writes of the mountain owner (seed 10536739806879207652).
-- Round 24 B2 added the rock nests to the lattice (was 1e00214d...c512d0c).
local LAYER_KAT = "6a513d83211763410076f109aef4c22337989c10ccc8693e236817f172739219"
say("layer KAT digest: %s", layer_digest)
if os.getenv("R24_PRINT_KAT") == nil then
	check(layer_digest == LAYER_KAT, "layer known answer differs")
end

-------------------------------------------------------------------------------
-- 4b. Cliffs (Round 24 B2). A 70-node cliff: plateau at y 110 for x < 32,
-- ground at y 40 beyond. Columns 28..31 are steep, column 29 is excluded
-- (protected), the rest are ordinary. Two variants: native stone up to the
-- surface (a native cliff) and native v7 at y 20 (a fill cliff). Coal sits
-- in the face of column 31.
local cliff_digests = {}
do
	local box = {min_x = 0, max_x = 63, min_y = -40, max_y = 120, min_z = 0, max_z = 15}
	local nests_only = {["grug_materials:slate"] = true, ["grug_materials:granite"] = true,
		["grug_materials:basalt"] = true}
	for _, variant in ipairs({"native", "fill"}) do
		local function column(x, z)
			local t = x < 32 and 110 or 40
			return {terrain_y = t, native_y = variant == "native" and t - 1 or 20,
				zone = "stormvault", biome = "grug_crags"}
		end
		local w = new_world(box, column)
		for z = 0, 15 do
			local i = w.index_at(31, 90, z)
			w.original[i], w.final[i] = COAL, COAL
		end
		local function steep(x) return x >= 28 and x <= 31 end
		local function face_stone()
			local stone, total = 0, 0
			for z = 0, 15 do
				for y = 41, 105 do
					total = total + 1
					if w.final[w.index_at(31, y, z)] == STONE then stone = stone + 1 end
				end
			end
			return stone / total
		end
		local info = {}
		run_strata(w, nil, 29, info, steep)
		local before = face_stone()
		local band_writes = #w.writes
		w.writes = {}
		local before_final, before_intent = {}, {}
		for i = 1, #w.final do before_final[i], before_intent[i] = w.final[i], w.intent[i] end
		run_layers(w, nil, info)
		local after = face_stone()
		local shallow = {steep = 0, ordinary = 0, excluded = 0}
		for _, row in ipairs(w.writes) do
			local x, y, z, name = row:match("^(%-?%d+),(%-?%d+),(%-?%d+)=(.+)$")
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			local c = column(x, z)
			local depth = c.terrain_y - y
			local i = w.index_at(x, y, z)
			check(before_final[i] == STONE and before_intent[i] == 0,
				"layer pass replaced something other than untouched stone")
			if depth <= 40 then
				check(depth >= 5, "layer pass wrote into the filler")
				check(name ~= "default:gravel" and name ~= "default:dirt",
					"loose pocket in the top 40 nodes")
				if x == 29 then shallow.excluded = shallow.excluded + 1
				elseif steep(x) then shallow.steep = shallow.steep + 1
				else
					shallow.ordinary = shallow.ordinary + 1
					check(nests_only[name], "ordinary column got a layer near the surface")
				end
			else
				check(before_final[i] ~= nil and w.original[i] ~= STONE,
					"deep layer in native stone")
			end
		end
		for z = 0, 15 do
			check(w.final[w.index_at(31, 90, z)] == COAL, "ore replaced")
		end
		check(shallow.excluded == 0, "excluded column changed near the surface")
		check(shallow.steep > 0, "steep face got no layers")
		cliff_digests[#cliff_digests + 1] = hex_sha(table.concat(w.writes, "\n"))
		say("%s cliff: face stone %.1f%% -> %.1f%%; top-40 writes steep %d, ordinary (nests) %d, excluded %d; bands %d",
			variant, 100 * before, 100 * after, shallow.steep, shallow.ordinary,
			shallow.excluded, band_writes)
	end
end
-- Known answer of both cliff variants' layer-pass writes (Round 24 B2).
local CLIFF_KAT = "bfc03cb9b55572b0e0d0baa1d51d93bd5f40ce9900f8306b7d72a0b5b4cc7e74"
local cliff_digest = hex_sha(table.concat(cliff_digests, "\n"))
say("cliff KAT digest: %s", cliff_digest)
if os.getenv("R24_PRINT_KAT") == nil then
	check(cliff_digest == CLIFF_KAT, "cliff known answer differs")
end

-------------------------------------------------------------------------------
-- 6. P8 vein growth (B2 speedups a and b): the per-vein rank memo and the
-- linear minimum give the placements of the former per-step digest and heap
-- sort. The production frontier helpers (sort_prefix, frontier_min) run on a
-- replica of the P8 loop shape (enumeration, budget, root draw, vein growth)
-- with the real r6_hash digests and budget; each owner is settled twice.
do
	local hash = dofile(wp40 .. "/r6_hash.lua")(sha)
	local fields = {}
	local seed = FULL_SEED
	local function digest7(domain, a, b, c, d, e, f, g)
		fields[1], fields[2], fields[3], fields[4], fields[5], fields[6], fields[7] =
			a, b, c, d, e, f, g
		return hash.digest_count(domain, seed, fields, 7)
	end
	local function digest11(domain, a, b, c, d, e, f, g, h, i, j, k)
		fields[1], fields[2], fields[3], fields[4], fields[5], fields[6], fields[7] =
			a, b, c, d, e, f, g
		fields[8], fields[9], fields[10], fields[11] = h, i, j, k
		return hash.digest_count(domain, seed, fields, 11)
	end
	local function root_draw_new(a, b, c, d, e, f, g)
		fields[1], fields[2], fields[3], fields[4], fields[5], fields[6], fields[7] =
			a, b, c, d, e, f, g
		return hash.prepare_root_draw(seed, fields, 7)
	end
	local function coordinate_less(left, right)
		if left.digest ~= right.digest then return hash.less_bytes(left.digest, right.digest) end
		if left.z ~= right.z then return left.z < right.z end
		if left.x ~= right.x then return left.x < right.x end
		return left.y < right.y
	end
	-- frontier_min against sort_prefix on random frontiers
	local rng = 12345
	local function rand(n) rng = (rng * 1103515245 + 12345) % 2147483648 return rng % n end
	local scratch = {}
	for i = 1, 64 do scratch[i] = {} end
	for trial = 1, 3000 do
		local count = 1 + rand(40)
		for i = 1, count do
			local e = scratch[i]
			e.x, e.y, e.z = rand(16), rand(16), trial * 100 + i
			-- a few equal digests exercise the coordinate tie-break
			e.digest = digest11("resource_frontier_rank_v1", "k", 0, 0, 0, "h", 1, "b", 1,
				e.x % 3, 0, rand(4) == 0 and 0 or e.z)
		end
		local best = S.r24_frontier_min(scratch, count, coordinate_less)
		local bx, by, bz = best.x, best.y, best.z
		S.r24_sort_prefix(scratch, count, coordinate_less)
		check(scratch[1].x == bx and scratch[1].y == by and scratch[1].z == bz,
			"frontier_min differs from the heap sort")
	end
	local resources = {{key = "coal", d = 64, v = 8}, {key = "copper", d = 96, v = 8},
		{key = "iron", d = 128, v = 8}, {key = "quartz", d = 128, v = 8},
		{key = "tin", d = 96, v = 8}}
	local FX, FY, FZ = {1, -1, 0, 0, 0, 0}, {0, 0, 1, -1, 0, 0}, {0, 0, 0, 0, 1, -1}
	local function settle(host_share, fast)
		local E = 48
		local function index_at(x, y, z) return z * E * E + y * E + x + 1 end
		local occupancy, host = {}, {}
		local s = 777
		for i = 1, E * E * E do
			s = (s * 1103515245 + 12345) % 2147483648
			occupancy[i], host[i] = 0, (s % 100) < host_share
		end
		local coords, frontier = {}, {}
		for i = 1, 4096 do coords[i] = {} end
		for i = 1, 256 do frontier[i] = {} end
		local rows, digests = {}, 0
		local t0 = os.clock()
		for ri, resource in ipairs(resources) do
			for cz = 0, 2 do for cx = 0, 2 do for cy = 0, 2 do
				local eligible = 0
				for z = cz * 16, cz * 16 + 15 do for y = cy * 16, cy * 16 + 15 do
					for x = cx * 16, cx * 16 + 15 do
						if host[index_at(x, y, z)] then
							eligible = eligible + 1
							local c = coords[eligible]
							c.x, c.y, c.z = x, y, z
						end
					end
				end end
				if eligible > 0 then
					local rd = digest7("resource_budget_remainder_v1", resource.key, cx, cy, cz,
						"default:stone", 1, "ordinary")
					local budget = hash.budget(eligible, 1, resource.d, 1, 1, rd)
					local draw = budget > 0 and root_draw_new(resource.key, cx, cy, cz,
						"default:stone", 1, "ordinary")
					local planned = budget == 0 and 0 or floor((budget + resource.v - 1) / resource.v)
					local small = planned == 0 and 0 or floor(budget / planned)
					local large = budget - small * planned
					local rank = 1
					for vein = 1, planned do
						local target = small + (vein <= large and 1 or 0)
						local root
						while rank <= eligible do
							local remaining = eligible - rank + 1
							local sel = draw(remaining)
							local c = coords[sel]
							coords[sel], coords[remaining] = coords[remaining], c
							rank = rank + 1
							if occupancy[index_at(c.x, c.y, c.z)] == 0 then root = c break end
						end
						if root then
							local nodes = {{x = root.x, y = root.y, z = root.z}}
							occupancy[index_at(root.x, root.y, root.z)] = ri + 1
							rows[#rows + 1] = ri .. ":" .. root.x .. "," .. root.y .. "," .. root.z
							local memo = {}
							while #nodes < target do
								local count = 0
								for n = 1, #nodes do
									local node = nodes[n]
									for f = 1, 6 do
										local x, y, z = node.x + FX[f], node.y + FY[f], node.z + FZ[f]
										if x >= cx * 16 and x <= cx * 16 + 15 and y >= cy * 16 and
												y <= cy * 16 + 15 and z >= cz * 16 and z <= cz * 16 + 15 and
												host[index_at(x, y, z)] and occupancy[index_at(x, y, z)] == 0 then
											local dup = false
											for k = 1, count do
												local o = frontier[k]
												if o.x == x and o.y == y and o.z == z then dup = true break end
											end
											if not dup then
												count = count + 1
												local e = frontier[count]
												e.x, e.y, e.z = x, y, z
												local key = index_at(x, y, z)
												local d = fast and memo[key]
												if not d then
													d = digest11("resource_frontier_rank_v1", resource.key, cx, cy,
														cz, "default:stone", 1, "ordinary", vein, x, y, z)
													digests = digests + 1
													if fast then memo[key] = d end
												end
												e.digest = d
											end
										end
									end
								end
								if count == 0 then break end
								local nxt
								if fast then
									nxt = S.r24_frontier_min(frontier, count, coordinate_less)
								else
									S.r24_sort_prefix(frontier, count, coordinate_less)
									nxt = frontier[1]
								end
								nodes[#nodes + 1] = {x = nxt.x, y = nxt.y, z = nxt.z}
								occupancy[index_at(nxt.x, nxt.y, nxt.z)] = ri + 1
								rows[#rows + 1] = ri .. ":" .. nxt.x .. "," .. nxt.y .. "," .. nxt.z
							end
						end
					end
				end
			end end end
		end
		return hex_sha(table.concat(rows, "\n")), #rows, digests, os.clock() - t0
	end
	for _, share in ipairs({100, 60}) do
		local old_digest, old_rows, old_calls, old_s = settle(share, false)
		local new_digest, new_rows, new_calls, new_s = settle(share, true)
		check(old_digest == new_digest and old_rows == new_rows,
			"P8 placements differ between the old and the new vein growth")
		say("P8 identity, %d%% host 48^3 owner: %d placements, digest %s both; rank digests %d -> %d, %.3f s -> %.3f s",
			share, new_rows, new_digest:sub(1, 16), old_calls, new_calls, old_s, new_s)
	end
end

-------------------------------------------------------------------------------
-- 5. Native allowlist: gravel blob, five strata and three decorative nests.
do
	local captured = {}
	local specs = {
		mgv7_np_terrain_base = {14, 70, 600, 82341, 5, 0.60000002384185791015625, "defaults"},
		mgv7_np_terrain_alt = {10, 25, 600, 5934, 5, 0.60000002384185791015625, "defaults"},
		mg_biome_np_heat = {50, 35, 1000, 5349, 3, 0.5, "eased"},
		mg_biome_np_humidity = {50, 35, 1000, 842, 3, 0.5, "eased"},
		mg_biome_np_heat_blend = {0, 4, 32, 13, 2, 1, "eased"},
		mg_biome_np_humidity_blend = {0, 4, 32, 90003, 2, 1, "eased"},
	}
	local registered_nodes = {}
	local registered_ores = {}
	local fake = {
		sha256 = function(bytes)
			captured[#captured + 1] = bytes
			return hex_sha(bytes)
		end,
		set_mapgen_setting_noiseparams = function() end,
		get_mapgen_setting_noiseparams = function(name)
			local s = specs[name]
			return {offset = s[1], scale = s[2], spread = {x = s[3], y = s[3], z = s[3]},
				seed = s[4], octaves = s[5], persist = s[6], persistence = s[6],
				lacunarity = 2, flags = s[7]}
		end,
		registered_nodes = registered_nodes,
		registered_ores = registered_ores,
	}
	local order = {}
	function fake.register_ore(definition)
		registered_ores[definition.name] = definition
		order[#order + 1] = definition
		return #order
	end
	local saved = rawget(_G, "core")
	rawset(_G, "core", fake)
	local native = dofile(wp40 .. "/r7_native.lua")
	local token = native.apply_and_validate_main()
	-- every ore and wherein node must be registered
	local function register(name) registered_nodes[name] = {} end
	register("default:stone")
	register("default:gravel")
	local definitions_seen = {}
	local ok, err = pcall(native.register_ores, token)
	check(not ok and err:find("not registered", 1, true), "unregistered ore node is refused")
	for _, name in ipairs({"grug_materials:slate", "grug_materials:basalt",
			"grug_materials:granite", "grug_materials:t2_stone",
			"grug_materials:t3_stone", "grug_materials:t4_stone",
			"grug_materials:t5_stone", "grug_materials:t6_stone"}) do
		register(name)
	end
	local handles = native.register_ores(token)
	rawset(_G, "core", saved)
	check(#handles == 9 and #order == 9, "nine native ores")
	for i = 1, 6 do definitions_seen[i] = order[i] end
	check(order[1].ore == "default:gravel", "gravel blob first")
	for i = 2, 6 do check(order[i].ore_type == "stratum", "strata before the nests") end
	local expected = {
		{"grug_materials:slate", -400, -40},
		{"grug_materials:granite", -900, -200},
		{"grug_materials:basalt", -31000, -600},
	}
	for i = 1, 3 do
		local d = order[6 + i]
		check(d.ore_type == "blob" and d.ore == expected[i][1] and
			d.y_min == expected[i][2] and d.y_max == expected[i][3],
			"decorative nest " .. i)
		check(#d.wherein == 6 and d.wherein[1] == "default:stone", "nest hosts")
		for host_index = 2, 6 do
			check(d.wherein[host_index] == order[host_index].ore,
				"nest host follows the tier stratum rows")
		end
	end
	-- canonical bytes: the first seven rows are the pre-Round-24 allowlist
	local bytes
	for _, b in ipairs(captured) do
		if b:sub(1, 32) == "grug_wp40_r7_native_allowlist_v1" then bytes = b end
	end
	check(bytes, "native canonical bytes captured")
	local prefix = {}
	local n = 0
	for line in bytes:gmatch("[^\n]*\n") do
		n = n + 1
		if n <= 7 then prefix[#prefix + 1] = line end
	end
	check(n == 10, "ten canonical lines")
	local old = hex_sha(table.concat(prefix))
	check(old == "c29c9c6c5eadb0f3ba22cb10a5cd717e5ddec4041aad19df166c025d97b5e2ab",
		"gravel and stratum rows unchanged")
	say("native allowlist: 9 ores (gravel, 5 strata, 3 nests), digest %s; old rows %s",
		native.identities().native_digest, old:sub(1, 8))
end

return table.concat(out, "\n") .. "\nR24 FILL FIXTURE PASS\n"
end
