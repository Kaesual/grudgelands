-- Round 51 TERRAIN T4 portable test (LuaJIT): the land surfaces after the
-- picks, on the real R6 content module (tools/r23_tree_line/harness.lua: the
-- shipped manifest over a synthetic content contract) and the real strata
-- pass of r6_settlement.lua:
--   A. the swamp's moss: every mapgen place that named the moss soil for the
--      swamp names the swamp moss (the swamp hosts of r6_content.lua, the
--      fern rows, the world content soil, the swamp pass's grounds), the
--      swamp's ground mix tops are its own grounds with swamp moss patches,
--      and the moss soil stays the elf forest's (palette, decoration cover,
--      world content soil);
--   B. the clay bands: on a stepped badlands slope a column 2 or more above a
--      neighbour is banded (its band run max(drop, 3), its top the cycle's
--      band at its height or its own top where the cycle gives mesa clay),
--      every other column is not; the strata pass lays the cycle by height
--      down the face over stone and the filler, never over an ore or air,
--      and the ordinary strata below the run;
--   C. the ice: about a tenth of the snowy crags' snowblock tops are ice in
--      patches, with no snow on it, and no other biome gets ice;
--   D. the pebbles: about a tenth of the dry coast sand is gravel (top and
--      shore) in patches, and no column under water changes;
--   E. the roster holds default:ice as a surface row (129 rows) and the
--      spawn-region ground lists the four bands.
--
-- Usage (repo root): luajit tools/r51_t4/portable_test.lua [REPO]
local repo = arg and arg[1] or "."
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function read(path)
	local handle = assert(io.open(path, "rb"))
	local data = handle:read("*a")
	handle:close()
	return data
end
local floor = math.floor

local B = dofile(repo .. "/tools/r23_tree_line/harness.lua").new(repo)
local content = B.content()
local ref = content.content_ref
local SEED, ZONE = "4242", "fixture_zone"
local function source(height_at, biome, coast)
	local s = {schema = "grug_wp40_r5_planner_source_v1"}
	function s.column_values_at(x, z) return "land", 1, ZONE, biome, "dwarf", height_at(x, z) end
	function s.coast_material_at() return coast end
	function s.start_ground_at() return nil end
	function s.start_ground_names() return {} end
	function s.overlay_exclusion_at() return nil end
	function s.static_exclusion_values_at() return nil end
	function s.land_zone_at() return ZONE end
	function s.river_water_in() return false end
	function s.surface_cave_run_at() return nil end
	function s.surface_cave_candidate_at_cell() return nil end
	function s.protected_only_floor_at() return nil end
	function s.metrics() return {} end
	return s
end
-- Over a square of columns: the share of `hit` among `of` and whether the
-- hits lie in patches (most hit columns touch another one).
local function share(select, biome, size, y_at, water_y, of, hit)
	local seen, hits, touching, mark = 0, 0, 0, {}
	for z = 0, size - 1 do
		for x = 0, size - 1 do
			local row = select(biome, x, z, water_y, y_at(x, z), ZONE)
			if of(row) then
				seen = seen + 1
				if hit(row) then hits = hits + 1 mark[x * 4096 + z] = true end
			end
		end
	end
	for k in pairs(mark) do
		local x, z = floor(k / 4096), k % 4096
		if mark[(x + 1) * 4096 + z] or mark[(x - 1) * 4096 + z] or mark[x * 4096 + z + 1] or
				mark[x * 4096 + z - 1] then touching = touching + 1 end
	end
	return seen, hits, touching
end

-- A. The swamp's moss -------------------------------------------------------
local SWAMP_MOSS, MOSS_SOIL = "grug_nodes:swamp_moss", "grug_nodes:dirt_with_moss"
for _, id in ipairs({"swamp_fern_1", "swamp_fern_2", "swamp_fern_3", "swamp_tree"}) do
	check(content.decoration_cover(id, "grug_swamp", ref(SWAMP_MOSS)) > 0 and
		content.decoration_cover(id, "grug_swamp", ref(MOSS_SOIL)) == 0,
		id .. " stands on the swamp moss, not the moss soil")
end
for _, row in ipairs(content.decorations()) do
	if row.id:match("^swamp_fern") then
		check(row.host == SWAMP_MOSS, row.id .. "'s manifest host is the swamp moss")
	end
	if row.id == "elf_forest_grass_1" then
		check(content.decoration_cover(row.id, "grug_elf_forest", ref(MOSS_SOIL)) > 0,
			"the elf forest's grass still grows on the moss soil")
	end
end
do
	local W = dofile(wp40 .. "/world_content_catalog.lua")
	local swamp, elf
	for _, p in ipairs(W.plants) do
		if p.key == "pumpkin" then swamp = p.hosts.grug_swamp end
		if p.key == "carrot" then elf = p.hosts.grug_elf_forest end
	end
	local function has(list, name)
		for _, n in ipairs(list or {}) do if n == name then return true end end
		return false
	end
	check(has(swamp, SWAMP_MOSS) and not has(swamp, MOSS_SOIL),
		"the world content's swamp soil lists the swamp moss, not the moss soil")
	check(has(elf, MOSS_SOIL), "the world content's elf forest soil keeps the moss soil")
	local writer = read(wp40 .. "/swamp_writer.lua")
	local grounds = writer:match("local GROUND = {}%s*for _, name in ipairs%((%b{})")
	check(grounds and grounds:find(SWAMP_MOSS, 1, true) and not grounds:find(MOSS_SOIL, 1, true),
		"the swamp pass writes over the swamp moss, not the moss soil")
end
do
	local flat = function() return 10 end
	local select = content.new_surface_selector(SEED, source(flat, "grug_swamp"))
	local tops, bad = {}, 0
	for z = 0, 299 do
		for x = 0, 299 do
			local top = select("grug_swamp", x, z, nil, 10, ZONE).top
			tops[top] = (tops[top] or 0) + 1
		end
	end
	for name in pairs(tops) do
		if not ({["grug_nodes:mud"] = true, ["grug_nodes:mud_dry"] = true,
				["grug_nodes:mud_mottled"] = true, ["grug_nodes:mud_with_wet_grass"] = true,
				[SWAMP_MOSS] = true})[name] then bad = bad + 1 end
	end
	local moss = (tops[SWAMP_MOSS] or 0) / 90000
	print(("swamp: swamp moss tops %.3f, moss soil tops %d"):format(moss, tops[MOSS_SOIL] or 0))
	check(bad == 0 and moss > 0.02 and moss < 0.3, "the swamp's tops are its own grounds with swamp moss patches")
	local elf_select = content.new_surface_selector(SEED, source(flat, "grug_elf_forest"))
	local soil = 0
	for z = 0, 199 do
		for x = 0, 199 do
			if elf_select("grug_elf_forest", x, z, nil, 10, ZONE).top == MOSS_SOIL then soil = soil + 1 end
		end
	end
	check(soil > 0, "the elf forest's ground mix keeps the moss soil")
end

-- B. The clay bands ----------------------------------------------------------
local BANDS = {"grug_nodes:clay_band_ochre", "grug_nodes:mesa_clay", "grug_nodes:clay_band_sienna",
	"grug_nodes:clay_band_chalk", "grug_nodes:mesa_clay", "grug_nodes:clay_band_umber",
	"grug_nodes:clay_band_sienna"}
local PALETTE = {["grug_nodes:mesa_clay"] = true, ["default:dry_dirt"] = true,
	["default:gravel"] = true, ["default:stone"] = true}
for _, step in ipairs({3, 8}) do
	-- steps of `step` nodes every 4 columns along x (from y 20, under the
	-- snow): the first column of a step stands `step` above its west
	-- neighbour; the other three are flat or, by the grade, a rock face
	local h = function(x) return 20 + step * floor(x / 4) end
	local select = content.new_surface_selector(SEED, source(h, "grug_badlands"))
	local lips, banded_ok, flat, flat_ok = 0, 0, 0, 0
	for z = 0, 40 do
		for x = 1, 48 do
			local y = h(x)
			local row = select("grug_badlands", x, z, nil, y, ZONE)
			if x % 4 == 0 then
				lips = lips + 1
				local cycle = BANDS[y % 7 + 1]
				local top_ok = cycle == "grug_nodes:mesa_clay" and PALETTE[row.top] or row.top == cycle
				if row.bands and row.band_depth == math.max(step, 3) and top_ok and
						row.top_ref == ref(row.top) then banded_ok = banded_ok + 1 end
			elseif step == 3 then
				-- 3 over 6 nodes is no rock face: only the lips are banded
				flat = flat + 1
				if not row.bands and PALETTE[row.top] then flat_ok = flat_ok + 1 end
			end
		end
	end
	check(lips > 0 and banded_ok == lips, ("steps of %d: every lip column is banded (%d of %d)")
		:format(step, banded_ok, lips))
	if step == 3 then
		check(flat > 0 and flat_ok == flat, ("steps of 3: no other column is (%d of %d)")
			:format(flat_ok, flat))
	end
end
do
	-- other biomes keep their rock faces and lips
	local h = function(x) return 100 + 8 * floor(x / 4) end
	local select = content.new_surface_selector(SEED, source(h, "grug_savanna"))
	local row = select("grug_savanna", 4, 0, nil, h(4), ZONE)
	check(row.bands == nil and row.steep == true, "a savanna cliff keeps its rock face")
end
do
	-- The strata pass on one banded column: terrain 60, a face of 9 down to
	-- 51; native stone below 58, the filler (mesa clay) above, an ore at 55
	-- and a cave voxel at 53.
	local S = dofile(wp40 .. "/r6_settlement.lua")
	local cids, names = {}, {}
	local function cid_of(name)
		if not cids[name] then names[#names + 1] = name cids[name] = #names end
		return cids[name]
	end
	local AIR, STONE, MESA = cid_of("air"), cid_of("default:stone"), cid_of("grug_nodes:mesa_clay")
	local ORE = cid_of("default:stone_with_coal")
	local band_refs = {}
	for i, name in ipairs(BANDS) do band_refs[i] = cid_of(name) end
	local MIN_Y, MAX_Y, TERRAIN = 0, 79, 60
	local original, final = {}, {}
	for y = MIN_Y, MAX_Y do
		local n = y > TERRAIN and AIR or (y >= TERRAIN - 2 and MESA or STONE)
		if y == 55 then n = ORE elseif y == 53 then n = AIR end
		original[y + 1], final[y + 1] = n, n
	end
	local writes = {}
	local row = {filler_depth = 2, filler_ref = MESA, bands = band_refs, band_depth = 9}
	S.r8_apply_strata({min_x = 0, min_y = MIN_Y, min_z = 0, max_x = 0, max_y = MAX_Y, max_z = 0,
		floor_y = -37, original_data = original, final_data = final,
		content_cids = setmetatable({}, {__index = function(_, k) return k end}),
		stone_cid = STONE, index_at = function(_, y) return y - MIN_Y + 1 end,
		column_values_at = function()
			return "land", nil, "sunscar", "grug_badlands", nil, TERRAIN,
				nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
		end,
		static_exclusion_values_at = function() return nil end,
		select_surface = function() return row end,
		strata = S.r8_strata_new("10536739806879207652",
			{zones = {{id = "sunscar", primary_relief_id = "badlands"}}}),
		content_ref = cid_of, fill_stone_at = function() return false end,
		write = function(_, y, _, r) writes[y] = names[r] final[y - MIN_Y + 1] = r end})
	local face_ok = true
	for y = TERRAIN - 8, TERRAIN - 1 do
		local want = BANDS[y % 7 + 1]
		if y == 55 or y == 53 then want = nil end
		if writes[y] ~= want then face_ok = false print("face", y, writes[y], want) end
	end
	check(face_ok, "the strata pass bands the face by height over stone and filler, not the ore or the cave")
	check(writes[TERRAIN] == nil, "the strata pass leaves the top to the row")
	local below = 0
	for y in pairs(writes) do if y < TERRAIN - 8 then below = below + 1 end end
	check(below > 0, "the ordinary strata continue below the band run")
	local deep_ok = true
	for y, name in pairs(writes) do
		if y < TERRAIN - 8 and (name:match("clay_band") or name == "grug_nodes:mesa_clay") then deep_ok = false end
	end
	check(deep_ok, "no band below the run")
end

-- C. The ice ----------------------------------------------------------------
do
	local high = function() return 250 end
	local select = content.new_surface_selector(SEED, source(high, "grug_crags_snowy"))
	local seen, hits, touching = share(select, "grug_crags_snowy", 300, high, nil,
		function(row) return row.top == "default:snowblock" or row.top == "default:ice" end,
		function(row) return row.top == "default:ice" end)
	local dust_ok = true
	for z = 0, 99 do
		for x = 0, 99 do
			local row = select("grug_crags_snowy", x, z, nil, 250, ZONE)
			if row.top == "default:ice" and (row.dust ~= "-" or row.dust_ref ~= 0 or
					row.top_ref ~= ref("default:ice")) then dust_ok = false end
		end
	end
	print(("ice: %d of %d snowblock tops (%.3f), %.2f touch another"):format(hits, seen,
		hits / seen, touching / hits))
	check(seen > 10000 and hits / seen > 0.07 and hits / seen < 0.13,
		"about a tenth of the snowy crags' snowblock tops are ice")
	check(touching / hits > 0.8, "the ice lies in patches")
	check(dust_ok, "no snow on the ice")
	local plain = content.new_surface_selector(SEED, source(high, "grug_crags"))
	local _, crag_ice = share(plain, "grug_crags", 120, high, nil, function() return true end,
		function(row) return row.top == "default:ice" end)
	check(crag_ice == 0, "the plain crags get no ice")
end

-- D. The pebbles ------------------------------------------------------------
for _, biome in ipairs({"grug_beach", "grug_jungle_edge"}) do
	local low = function() return 3 end
	local select = content.new_surface_selector(SEED, source(low, biome, "sand"))
	local seen, hits, touching = share(select, biome, 300, low, nil,
		function() return true end,
		function(row) return row.top == "default:gravel" end)
	local rows_ok = true
	for z = 0, 99 do
		for x = 0, 99 do
			local row = select(biome, x, z, nil, 3, ZONE)
			if row.top == "default:gravel" then
				rows_ok = rows_ok and row.shore == "default:gravel" and
					row.shore_ref == ref("default:gravel") and row.filler == "default:sandstone"
			else
				rows_ok = rows_ok and row.top == "default:sand"
			end
		end
	end
	print(("pebbles (%s): %d of %d dry sand columns (%.3f), %.2f touch another"):format(biome,
		hits, seen, hits / seen, touching / hits))
	check(hits / seen > 0.07 and hits / seen < 0.13, biome .. ": about a tenth of the dry sand is gravel")
	check(touching / hits > 0.8, biome .. ": the pebbles lie in patches")
	check(rows_ok, biome .. ": a pebble row is gravel over the sand's sandstone, top and shore")
	local _, wet_gravel = share(select, biome, 100, low, 6,
		function() return true end, function(row) return row.top == "default:gravel" end)
	check(wet_gravel == 0, biome .. ": no pebble row under water")
end

-- E. Roster and spawn hosts --------------------------------------------------
do
	local roster = read(wp40 .. "/r7_content.lua")
	check(roster:find('{"default:ice", 1},', 1, true) and
		roster:find("#ACCEPTED_R6_ROWS ~= 129", 1, true) and
		read(wp40 .. "/r7_p9g.lua"):find("#production.content_names ~= 129", 1, true),
		"the roster holds default:ice as a surface row and checks 129 rows")
	local spawn = read(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions.lua")
	local ground = spawn:match("local GROUND = (%b{})")
	local all = ground ~= nil
	for _, name in ipairs({"grug_nodes:clay_band_ochre", "grug_nodes:clay_band_sienna",
			"grug_nodes:clay_band_chalk", "grug_nodes:clay_band_umber", "grug_nodes:mesa_clay"}) do
		all = all and ground:find('"' .. name .. '"', 1, true) ~= nil
	end
	check(all, "the spawn-region ground (every surface spawn) lists the four bands")
end

print(("r51_t4: %d checks, %d failed"):format(checks, failures))
if failures > 0 then error(("%d FAILURES of %d checks"):format(failures, checks)) end
