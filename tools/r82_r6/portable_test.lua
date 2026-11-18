-- Round 82 lane R6 portable test (LuaJIT): the new seams of the faster R6
-- writer and planner give exactly what the code before them gave.
--   A. the shared surface selector (r6_content.lua `surface_selector`): one
--      per world and planner source, and its memoised rows equal a fresh
--      selector's on a stepped, watery, coastal sample, also when one
--      column is asked with other arguments or a slot is taken by another
--      column;
--   B. the strata pass (r6_settlement.lua `r8_apply_strata`): stacked
--      chunks write what one tall box writes, and a chunk wholly above or
--      below a column's top 40 nodes asks nothing about that column;
--   C. the template probability trials of one root (r6_templates.lua
--      `probability_trials`) equal `probability_include` draw for draw.
-- The per-chunk writer and planner as a whole are proven by the round's
-- fleet digests (tools/r82_gen/compare.sh); tools/r82_r6/measure.lua times
-- them.
--
-- Usage (repo root): luajit tools/r82_r6/portable_test.lua [REPO]
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

local B = dofile(repo .. "/tools/r23_tree_line/harness.lua").new(repo)
local content = B.content()
local SEED, ZONE = "8282", "fixture_zone"

-- A. The shared surface selector ---------------------------------------------
-- A planner source over a stepped height field with a lake, a sand coast and
-- a start town's ground patch, so the selector meets steep rock, lips,
-- scree, beds, shores, patches and town rows.
local function height_at(x, z)
	return 20 + math.floor(x / 7) * 2 + (z % 23 == 0 and 9 or 0) + math.floor(z / 31)
end
local function source(biome)
	local s = {schema = "grug_wp40_r5_planner_source_v1"}
	function s.column_values_at(x, z)
		local h = height_at(x, z)
		local water_y = (x > 60 and z > 60 and x < 90 and z < 90) and h + 3 or nil
		return "land", 1, ZONE, biome, "dwarf", h, water_y
	end
	function s.coast_material_at(x, z) return (x < 6 and z % 3 == 0) and "sand" or nil end
	function s.start_ground_at(x, z)
		return (x > 100 and x < 110 and z < 10) and "default:dirt_with_grass" or nil
	end
	function s.start_ground_names() return {"default:dirt_with_grass"} end
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
local FIELDS = {"top", "top_ref", "filler", "filler_ref", "filler_depth", "dust",
	"dust_ref", "shore", "shore_ref", "bed", "bed_ref", "steep", "band_depth"}
local function same_row(a, b)
	if a == nil or b == nil then return a == b end
	for _, field in ipairs(FIELDS) do
		if a[field] ~= b[field] then return false end
	end
	return (a.bands == nil) == (b.bands == nil)
end
do
	local biomes = {"grug_meadows", "grug_badlands", "grug_crags_snowy", "grug_swamp",
		"grug_beach"}
	local compared, differing = 0, 0
	for _, biome in ipairs(biomes) do
		local shared_source, fresh_source = source(biome), source(biome)
		local shared = content.surface_selector(SEED, shared_source)
		check(content.surface_selector(SEED, shared_source) == shared,
			"A one shared selector per world and source (" .. biome .. ")")
		check(content.surface_selector(SEED, fresh_source) ~= shared,
			"A another source gets its own selector (" .. biome .. ")")
		check(content.surface_selector("8283", shared_source) ~= shared,
			"A another world gets its own selector (" .. biome .. ")")
		local fresh = content.new_surface_selector(SEED, source(biome))
		-- Each column twice with its own arguments (the second a memo hit),
		-- once with other arguments in between (a guard miss), and columns
		-- 65,536 slots apart (x + 1 and z - 40503 share a slot) in between.
		for pass = 1, 2 do
			for z = 0, 127 do
				for x = 0, 127 do
					local _, _, zone, _, _, h, water_y = shared_source.column_values_at(x, z)
					local want = fresh(biome, x, z, water_y, h, zone)
					local got = shared(biome, x, z, water_y, h, zone)
					compared = compared + 1
					if not same_row(want, got) then differing = differing + 1 end
					if pass == 2 and (x + z) % 5 == 0 then
						local other_y = h + 40
						if not same_row(fresh(biome, x, z, nil, other_y, zone),
								shared(biome, x, z, nil, other_y, zone)) then
							differing = differing + 1
						end
						if not same_row(fresh(biome, x + 1, z - 40503, nil, h, zone),
								shared(biome, x + 1, z - 40503, nil, h, zone)) then
							differing = differing + 1
						end
						if not same_row(fresh(biome, x, z, water_y, h, nil),
								shared(biome, x, z, water_y, h, nil)) then
							differing = differing + 1
						end
						compared = compared + 3
					end
				end
			end
		end
		check(shared("no_such_biome", 3, 4, nil, 10, ZONE) == nil and
			shared("no_such_biome", 3, 4, nil, 10, ZONE) == nil,
			"A an unknown biome has no row, memoised or not")
	end
	print(("A: %d selections compared, %d differ"):format(compared, differing))
	check(differing == 0, "A the shared selector's rows equal a fresh selector's")
end

-- B. The strata pass ---------------------------------------------------------
do
	local S = dofile(wp40 .. "/r6_settlement.lua")
	local strata = S.r8_strata_new(SEED, {zones = {{id = ZONE, primary_relief_id = "mountain"}}})
	local STONE, AIR = 1, 2
	local REFS = {}
	local function content_ref(name)
		if not REFS[name] then
			REFS[#REFS + 1] = name
			REFS[name] = 100 + #REFS
		end
		return REFS[name]
	end
	-- Columns 0..15 x 0..3, terrain from -30 to about 300: some columns' top
	-- 40 nodes lie wholly in one chunk, some cross a chunk border, some lie
	-- under the floor.
	local function terrain(x, z) return -30 + x * 21 + z * 3 end
	local function run(min_y, max_y, writes, calls)
		local function index_at(x, y, z) return ((z * 16 + x) * 1000) + (y + 100) end
		local original = setmetatable({}, {__index = function(_, i)
			local y = i % 1000 - 100
			local column = math.floor(i / 1000)
			return y <= terrain(column % 16, math.floor(column / 16)) and STONE or AIR
		end})
		return S.r8_apply_strata({min_x = 0, min_y = min_y, min_z = 0, max_x = 15,
			max_y = max_y, max_z = 3, floor_y = -37, original_data = original,
			final_data = original, content_cids = {}, stone_cid = STONE,
			index_at = index_at, column_info = {}, column_cap = {},
			column_values_at = function(x, z)
				return "land", 1, ZONE, "grug_meadows", "dwarf", terrain(x, z)
			end,
			static_exclusion_values_at = function()
				calls.n = calls.n + 1
				return nil
			end,
			select_surface = function(_, x)
				calls.n = calls.n + 1
				return {filler_depth = 1 + x % 4, steep = x == 5}
			end,
			strata = strata, content_ref = content_ref,
			fill_stone_at = function() return false end,
			write = function(x, y, z, ref) writes[x .. "," .. y .. "," .. z] = ref end})
	end
	local tall, tall_calls = {}, {n = 0}
	run(-37, 420, tall, tall_calls)
	local stacked = {}
	for min_y = -112, 400, 80 do run(min_y, min_y + 79, stacked, {n = 0}) end
	local count, missing = 0, 0
	for key, ref in pairs(tall) do
		count = count + 1
		if stacked[key] ~= ref then missing = missing + 1 end
	end
	for key in pairs(stacked) do
		if tall[key] == nil then missing = missing + 1 end
	end
	print(("B: %d stratum writes in the tall box, %d differ in stacked chunks"):format(
		count, missing))
	check(count > 300 and missing == 0, "B stacked chunks write what one tall box writes")
	local above = {n = 0}
	run(400, 479, {}, above)
	check(above.n == 0, "B a chunk above every column's top 40 asks nothing")
	local below = {n = 0}
	run(-112, -33, {}, below)
	local reached = 0
	for x = 0, 15 do
		for z = 0, 3 do
			if terrain(x, z) - 40 <= -33 and terrain(x, z) - 1 >= -37 then reached = reached + 1 end
		end
	end
	check(below.n <= 2 * reached, "B the fill-floor chunk asks only the columns it can touch")
end

-- C. The probability trials of one root -------------------------------------
do
	-- r6_templates.lua with no rows: the trials need only the world's
	-- placement hash.
	local stub = {
		content_contract = function()
			return {content_kind_masks = {}, resolve_r6 = function() return 1, 1 end,
				ignore_cid = 0}
		end,
		decorations = function() return {} end,
		param2_kind = function() return "none" end,
		content_ref = function() return nil end,
	}
	local templates = dofile(wp40 .. "/r6_templates.lua")(dofile(wp40 .. "/r6_hash.lua")(B.sha),
		stub, {read = function() error("no schematic expected") end}, nil)
	local differing, compared = 0, 0
	for root = 1, 200 do
		local rx, ry, rz = root * 37 - 900, root % 61 - 20, root * 13 - 1300
		for _, id in ipairs({"meadows_bush", "deep_forest_apple_log"}) do
			local trial = templates.probability_trials(SEED, id, rx, ry, rz)
			for step = 1, 40 do
				local probability = (step * 37 + root) % 255
				local kind = step % 3 == 0 and "slice" or "node"
				local x, y, z = step % 16, (step * 7) % 64, (step * 3) % 16
				local want = templates.probability_include(SEED, id, rx, ry, rz, 0, kind,
					x, y, z, probability)
				compared = compared + 1
				if trial(kind, x, y, z, probability) ~= want then differing = differing + 1 end
			end
		end
	end
	print(("C: %d trials compared, %d differ"):format(compared, differing))
	check(differing == 0, "C the trials of one root equal probability_include")
end

print(("r82_r6: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error(("%d failures of %d checks"):format(failures, checks)) end
