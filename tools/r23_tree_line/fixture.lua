-- Round 23 Phase 2 portable fixture (LuaJIT): tree line, shrub band, snow,
-- forests and clearings. Loads the shipped rule (habitat_registry.lua), the
-- real R6 content module (surface selector), the real R6 planner, the real
-- renewal density authority and the real zones.lua planner source.
--
-- Usage (repo root): luajit tools/r23_tree_line/fixture.lua "$PWD" [quick]
local repo = arg[1] or "."
local quick = arg[2] == "quick"
local lines, failures = {}, 0
local function out(text) lines[#lines + 1] = text print(text) end
local function check(ok, label)
	out((ok and "ok   " or "FAIL ") .. label)
	if not ok then failures = failures + 1 end
end
local floor, abs = math.floor, math.abs
local B = dofile(repo .. "/tools/r23_tree_line/harness.lua").new(repo)
local habitat = B.habitat
local V = habitat.VEGETATION
local ONE = V.ONE
local SEEDS = {"4242", "10536739806879207652"}

-- 1. The rule alone -------------------------------------------------------
out("-- rule")
local ZONE = "fixture_zone"
local function one_zone() return ZONE end
local rule = habitat.vegetation_rule(SEEDS[1], one_zone)
local twin = habitat.vegetation_rule(SEEDS[1], one_zone)
local other = habitat.vegetation_rule(SEEDS[2], one_zone)
local jmin, jmax, jsum, jn, jstep, differs = 99, -99, 0, 0, 0, 0
local same = true
for z = -3000, 3000, 37 do
	for x = -3500, 3500, 41 do
		local j = rule.jitter(x, z)
		jmin, jmax, jsum, jn = math.min(jmin, j), math.max(jmax, j), jsum + j, jn + 1
		jstep = math.max(jstep, abs(rule.jitter(x + 1, z) - j), abs(rule.jitter(x, z + 1) - j))
		for _, y in ipairs({50, 170, 200, 230, 250, 275, 300}) do
			local a = {rule.factors(x, z, y, "grug_deep_forest", ZONE)}
			local b = {twin.factors(x, z, y, "grug_deep_forest", ZONE)}
			for i = 1, 5 do if a[i] ~= b[i] then same = false end end
			if rule.snow_class(x, z, y, "grug_crags", ZONE) ~=
					twin.snow_class(x, z, y, "grug_crags", ZONE) then same = false end
		end
		if other.jitter(x, z) ~= rule.jitter(x, z) then differs = differs + 1 end
	end
end
out(("jitter min %d max %d mean %.2f max step %d"):format(jmin, jmax, jsum / jn, jstep))
check(jmin == -V.JITTER and jmax == V.JITTER, "jitter reaches exactly +-15")
check(abs(jsum / jn) < 1, "jitter mean near zero")
check(jstep <= 3, "jitter is smooth (a neighbour differs by at most 3 nodes)")
check(same, "two rules of one seed agree on every factor and snow class")
check(differs > jn / 2, "another seed moves the lines")

-- Biome and zone offsets.
local COLD = {"grug_crags", "grug_crags_snowy", "grug_pine_hills", "grug_meadows",
	"grug_deep_forest", "grug_elf_forest", "grug_blight", "grug_bone_forest",
	"grug_swamp", "grug_beach"}
local WARM = {"grug_deep_jungle", "grug_jungle_edge", "grug_jungle_fringe",
	"grug_savanna", "grug_badlands", "grug_badlands_east"}
local offsets_ok = true
for _, biome in ipairs(COLD) do
	local s, l, n = rule.lines(100, 200, biome, "elandor_stormvault_heights")
	local j = rule.jitter(100, 200)
	if s ~= 160 + j or l ~= 220 + j or n ~= 280 + j then offsets_ok = false end
end
for _, biome in ipairs(WARM) do
	local s, l, n = rule.lines(100, 200, biome, "kragmar_thunderroot_wilds")
	local j = rule.jitter(100, 200)
	if s ~= 200 + j or l ~= 260 + j or n ~= 320 + j then offsets_ok = false end
end
for _, biome in ipairs({"grug_deep_forest", "grug_elf_forest", "grug_jungle_fringe"}) do
	local s, l, n = rule.lines(100, 200, biome, "front_skyglass_canopy")
	local j = rule.jitter(100, 200)
	if s ~= 200 + j or l ~= 260 + j or n ~= 320 + j then offsets_ok = false end
end
check(offsets_ok, "lines 160/220/280 (+jitter); warm biomes and the Skyglass zone +40")

-- Class curves against an independent reference (float), every class.
local function reference(x, z, y, biome, zone)
	local start, line, snow = rule.lines(x, z, biome, zone)
	local forest = rule.forest(x, z)
	local dense = (biome == "grug_deep_forest" or biome == "grug_deep_jungle") and 1.5 or 1
	local tree = math.min(forest * dense, 5 * ONE)
	local last = math.min(forest, 5 * ONE)
	if y >= line then tree, last = 0, 0
	elseif y >= start then
		tree = tree * (line - y) / (line - start)
		if y >= start + 30 then last = last * (line - y) / (line - start - 30) end
	end
	local shrub, band
	if y < start then shrub, band = 1, 0
	elseif y < line then
		shrub = 1 + 2 * (y - start) / (line - start)
		band = 3 * (y - start) / (line - start)
	elseif y < line + 20 then shrub, band = 3, 3
	elseif y < line + 40 then shrub = 3 * (line + 40 - y) / 20 band = shrub
	else shrub, band = 0, 0 end
	return tree, last, shrub * ONE, band * ONE, y >= snow and 0 or ONE
end
local curve_ok, worst = true, 0
for z = -2000, 2000, 211 do
	for x = -2000, 2000, 197 do
		for _, biome in ipairs({"grug_deep_forest", "grug_crags", "grug_savanna"}) do
			for y = 100, 340, 3 do
				local got = {rule.factors(x, z, y, biome, ZONE)}
				local want = {reference(x, z, y, biome, ZONE)}
				for i = 1, 5 do
					local d = abs(got[i] - want[i])
					worst = math.max(worst, d)
					if d > 2 then curve_ok = false end
				end
			end
		end
	end
end
check(curve_ok, "class curves match the reference within 2/4096 (worst " .. worst .. ")")
-- Explicit points on one column (cold biome).
do
	local x, z = 333, -777
	local start, line, snow = rule.lines(x, z, "grug_crags", ZONE)
	local function f(y, class) return rule.factor(class, x, z, y, "grug_crags", ZONE) end
	check(f(start - 1, "tree") == rule.forest(x, z) and f(line, "tree") == 0 and
		f(line - 1, "tree") > 0, "trees full below the tree start, zero at the tree line")
	check(f(start + 29, "last_tree") == f(start - 1, "last_tree") and
		f(start + 45, "last_tree") > f(start + 45, "tree"),
		"the crags snowy pine keeps full density 30 nodes longer than other trees")
	check(f(start - 1, "shrub") == ONE and f(line, "shrub") == 3 * ONE and
		f(line + 19, "shrub") == 3 * ONE and f(line + 40, "shrub") == 0 and
		f(line + 30, "shrub") > 0, "shrubs x1 -> x3 at the tree line, gone 40 above it")
	check(f(start - 1, "shrub_band") == 0 and f(line, "shrub_band") == 3 * ONE,
		"band-only shrubs appear only in the band")
	check(f(snow - 1, "cover") == ONE and f(snow, "cover") == 0,
		"ground cover up to the snow line")
	check(rule.snow_class(x, z, snow, "grug_crags", ZONE) == 2 and
		rule.snow_class(x, z, snow + 80, "grug_crags", ZONE) == 2 and
		rule.snow_class(x, z, snow - 21, "grug_crags", ZONE) == 0,
		"snow cap from the snow line; nothing below the 20-node band")
end
-- Patchy band: the covered share rises towards the line.
do
	local shares = {}
	for depth = 1, 20 do
		local covered, n = 0, 0
		for z = -3000, 3000, 23 do
			for x = -3000, 3000, 29 do
				local _, _, snow = rule.lines(x, z, "grug_crags", ZONE)
				if rule.snow_class(x, z, snow - depth, "grug_crags", ZONE) == 1 then
					covered = covered + 1
				end
				n = n + 1
			end
		end
		shares[depth] = covered / n
	end
	out(("dust band share at 1/5/10/15/20 below the line: %.2f %.2f %.2f %.2f %.2f"):
		format(shares[1], shares[5], shares[10], shares[15], shares[20]))
	check(shares[1] > 0.8 and shares[10] > 0.2 and shares[10] < 0.8 and shares[20] < 0.05,
		"dust band is patchy and thins out over 20 nodes")
end
-- Dense forests.
do
	local ok = true
	for z = -1000, 1000, 97 do
		for x = -1000, 1000, 89 do
			local forest = rule.forest(x, z)
			if rule.factor("tree", x, z, 50, "grug_deep_forest", ZONE) ~=
					math.min(floor(forest * 3 / 2), 5 * ONE) or
					rule.factor("tree", x, z, 50, "grug_deep_jungle", ZONE) ~=
					math.min(floor(forest * 3 / 2), 5 * ONE) or
					rule.factor("tree", x, z, 50, "grug_elf_forest", ZONE) ~= forest then
				ok = false
			end
		end
	end
	check(ok, "deep forest and deep jungle trees x1.5, other forests x1")
end
-- Row classes.
do
	local classes = {}
	for _, row in ipairs(B.manifest.decorations) do
		classes[row.id] = habitat.decoration_class(row)
	end
	check(classes.crags_snowy_pine == "last_tree" and classes.pine_hills_pine_tree == "tree" and
		classes.jungle_tree == "tree" and classes.meadows_bush == "shrub" and
		classes.pine_hills_pine_bush == "shrub" and classes.savanna_acacia_bush == "shrub" and
		classes.blight_dry_shrub == "shrub" and classes.crags_pine_bush == "shrub_band" and
		classes.deep_forest_bush == "shrub_band" and classes.elf_forest_bush == "shrub_band" and
		classes.bone_forest_dry_shrub == "shrub_band" and
		classes.meadows_grass_1 == "cover" and classes.swamp_papyrus == "cover" and
		classes.badlands_dry_shrub == "cover", "decoration rows map to their classes")
end

-- 2. Forest field: each zone's mean is one (real zones) --------------------
out("-- forest field per zone")
local worlds = {}
for index, seed in ipairs(SEEDS) do
	if quick and index > 1 then break end
	local W = dofile(repo .. "/tools/r23_tree_line/world_source.lua")(repo, seed)
	worlds[index] = W
	local r = habitat.vegetation_rule(seed, W.planner_source.land_zone_at)
	local sum, n, total, count, step_max = {}, {}, 0, 0, 0
	for z = -3331, 3336, 12 do
		for x = -3729, 3736, 12 do
			local water, _, zone = W.planner_source.column_values_at(x, z)
			if water == "land" and zone then
				local f = r.forest(x, z)
				sum[zone], n[zone] = (sum[zone] or 0) + f, (n[zone] or 0) + 1
				total, count = total + f, count + 1
			end
			local scale = r.forest_scale(x, z)
			step_max = math.max(step_max, abs(r.forest_scale(x + 1, z) - scale),
				abs(r.forest_scale(x, z + 1) - scale))
		end
	end
	out(("seed %s: largest zone-scale change between neighbour columns %.4f"):format(
		seed, step_max))
	check(step_max < 0.02, "seed " .. seed .. ": the zone scale changes by under 2 % " ..
		"per node (no step at zone borders)")
	local lo, hi, zones = math.huge, -math.huge, 0
	for zone, s in pairs(sum) do
		local mean = s / n[zone] / ONE
		lo, hi, zones = math.min(lo, mean), math.max(hi, mean), zones + 1
	end
	out(("seed %s: %d zones, zone means %.3f .. %.3f, world %.3f"):format(seed, zones,
		lo, hi, total / count / ONE))
	check(lo > 0.96 and hi < 1.04 and abs(total / count / ONE - 1) < 0.01,
		"seed " .. seed .. ": every zone's forest mean within 4 %, the world's within 1 %")
end

-- 3. Surface selector: snow caps, dust band, bare rock ---------------------
out("-- surface selector")
local function synthetic_source(height_at, biome_at, zone_at)
	local source = {schema = "grug_wp40_r5_planner_source_v1"}
	function source.column_values_at(x, z)
		return "land", 1, zone_at(x, z), biome_at(x, z), "dwarf", height_at(x, z)
	end
	function source.coast_material_at() return nil end
	function source.start_ground_at() return nil end
	function source.start_ground_names() return {} end
	function source.overlay_exclusion_at() return nil end
	function source.static_exclusion_values_at() return nil end
	function source.land_zone_at(x, z) return zone_at(x, z) end
	function source.river_water_in() return false end
	function source.surface_cave_run_at() return nil end
	function source.surface_cave_candidate_at_cell() return nil end
	-- Round 24 ruling 30 addendum seam (no protected column here).
	function source.protected_only_floor_at() return nil end
	function source.metrics() return {} end
	return source
end
do
	local content = B.content()
	-- A gentle ramp (z/4 per node) from y 150 to 350: never steep.
	local ramp = synthetic_source(function(_, z) return 150 + floor(z / 4) end,
		function() return "grug_pine_hills" end, function() return ZONE end)
	local select = content.new_surface_selector(SEEDS[1], ramp)
	local r = content.vegetation_rule(SEEDS[1], ramp)
	local cap, cap_bad, band, band_dust, low_dust = 0, 0, 0, 0, 0
	for z = 0, 800, 3 do
		for x = 0, 600, 7 do
			local y = 150 + floor(z / 4)
			local row = select("grug_pine_hills", x, z, nil, y, ZONE)
			local _, _, snow = r.lines(x, z, "grug_pine_hills", ZONE)
			if y >= snow then
				cap = cap + 1
				if row.top ~= "default:snowblock" or row.dust ~= "default:snow" or
						row.top_ref ~= content.content_ref("default:snowblock") then
					cap_bad = cap_bad + 1
				end
			elseif y >= snow - V.SNOW_BAND then
				band = band + 1
				if row.dust == "default:snow" then
					band_dust = band_dust + 1
					if row.top == "default:snowblock" then cap_bad = cap_bad + 1 end
				end
			elseif row.dust ~= "-" then
				low_dust = low_dust + 1
			end
		end
	end
	out(("ramp: %d cap columns (%d wrong), band %d with dust %d, dust below band %d"):
		format(cap, cap_bad, band, band_dust, low_dust))
	check(cap > 0 and cap_bad == 0, "above the snow line: snowblock top with snow dust")
	check(band_dust > band * 0.25 and band_dust < band * 0.8,
		"the band below the snow line: patchy snow dust on the biome's own top")
	check(low_dust == 0, "no snow below the band")
	-- A cliff above the snow line: steep rock faces stay bare stone.
	local cliff = synthetic_source(function(x) return 330 + 4 * x end,
		function() return "grug_crags" end, function() return ZONE end)
	local cliff_select = content.new_surface_selector(SEEDS[1], cliff)
	local bare = true
	for z = 0, 60 do
		local row = cliff_select("grug_crags", 5, z, nil, 350, ZONE)
		if row.top ~= "default:stone" or row.dust ~= "-" then bare = false end
	end
	check(bare, "steep rock faces above the snow line stay bare rock")
	-- A warm biome keeps its top 40 nodes higher.
	local warm = synthetic_source(function() return 284 end,
		function() return "grug_savanna" end, function() return ZONE end)
	local warm_select = content.new_surface_selector(SEEDS[1], warm)
	local cold_select = content.new_surface_selector(SEEDS[1], synthetic_source(
		function() return 284 end, function() return "grug_crags" end,
		function() return ZONE end))
	local warm_snow, cold_snow = 0, 0
	for z = 0, 200, 5 do
		for x = 0, 200, 5 do
			if warm_select("grug_savanna", x, z, nil, 284, ZONE).dust ~= "-" then
				warm_snow = warm_snow + 1
			end
			if cold_select("grug_crags", x, z, nil, 284, ZONE).top == "default:snowblock" then
				cold_snow = cold_snow + 1
			end
		end
	end
	check(warm_snow == 0 and cold_snow > 0,
		"y 284: crags snowy in places, savanna (snow band from 285) bare")
end

-- 4. Planner: tree line, shrub band, snow, seams, density ------------------
out("-- planner")
local function cell_rows(planner_fixture, cx, cz)
	local _, decorations = planner_fixture.build_cell(cx, cz)
	return decorations
end
do
	local content = B.content()
	local ids = {}
	for index, row in ipairs(content.decorations()) do ids[index] = row.id end
	-- A long ramp over pine hills, crags and deep forest bands (x), rising
	-- with z from y 100 to y 356.
	local function height_at(x, z) return 100 + floor(z / 4) end
	local function biome_at(x)
		local band = floor(x / 256) % 3
		return band == 0 and "grug_crags" or (band == 1 and "grug_pine_hills" or
			"grug_deep_forest")
	end
	local ramp = synthetic_source(height_at, biome_at, function() return ZONE end)
	local planner, fixture = B.planner(SEEDS[1], ramp, content)
	local r = content.vegetation_rule(SEEDS[1], ramp)
	local select = content.new_surface_selector(SEEDS[1], ramp)
	local counts = {}
	local above_line, above_shrub, on_snow, total = 0, 0, 0, 0
	local band_shrubs, low_shrubs = 0, 0
	for cz = 0, 63, quick and 4 or 1 do
		for cx = 0, 47, quick and 2 or 1 do
			for _, row in ipairs(cell_rows(fixture, cx, cz)) do
				local x, z, y = row.x, row.z, row.y - 1
				if x >= cx * 16 and x < cx * 16 + 16 and z >= cz * 16 and z < cz * 16 + 16 then
					total = total + 1
					local id = ids[row.catalog]
					local class = habitat.decoration_class(content.decorations()[row.catalog])
					local biome = biome_at(x)
					local start, line, snow = r.lines(x, z, biome, ZONE)
					if (class == "tree" or class == "last_tree") and y >= line then
						above_line = above_line + 1
					end
					if (class == "shrub" or class == "shrub_band") then
						if y >= line + V.SHRUB_REACH then above_shrub = above_shrub + 1 end
						if y >= start and y < line + V.SHRUB_REACH then
							band_shrubs = band_shrubs + 1
						elseif y < start then
							low_shrubs = low_shrubs + 1
						end
					end
					if select(biome, x, z, nil, y, ZONE).dust ~= "-" or y >= snow then
						on_snow = on_snow + 1
					end
					counts[id] = (counts[id] or 0) + 1
				end
			end
		end
	end
	out(("ramp planner: %d decorations, %d trees above the tree line, %d shrubs above " ..
		"the shrub band, %d on snow, shrubs %d in the band / %d below"):format(total,
		above_line, above_shrub, on_snow, band_shrubs, low_shrubs))
	check(total > 0 and above_line == 0, "no tree at or above its tree line")
	check(above_shrub == 0, "no shrub 40 or more above the tree line")
	check(on_snow == 0, "no decoration on a snow cap or a dust column")
	check((counts.crags_pine_bush or 0) > 0 and (counts.deep_forest_bush or 0) > 0,
		"band-only shrubs grow in the crags and the deep forest band")
	check((counts.crags_snowy_pine or 0) > 0, "the crags snowy pine still grows")
	-- Seams: a cell is the same whichever planner built it first, and two
	-- plan slices sharing halo cells publish identical rows for them.
	local _, fixture_b = B.planner(SEEDS[1], ramp, B.content())
	local seam_ok = true
	for _, cell in ipairs({{5, 40}, {4, 40}, {5, 39}, {16, 44}, {15, 44}}) do
		local a = cell_rows(fixture, cell[1], cell[2])
		local b = cell_rows(fixture_b, cell[1], cell[2])
		if #a ~= #b then seam_ok = false end
		for i = 1, math.min(#a, #b) do
			if a[i].digest ~= b[i].digest or a[i].x ~= b[i].x or a[i].z ~= b[i].z then
				seam_ok = false
			end
		end
	end
	local function slice_rows(p, x0, z0)
		local plan = p:plan_slice({x = x0, y = 208, z = z0},
			{x = x0 + 79, y = 287, z = z0 + 79})
		local by_cell = {}
		for cell = 1, plan.candidate_cell_count do
			local base = (cell - 1) * 4
			local cx, cz = plan.candidate_cell_values[base + 1],
				plan.candidate_cell_values[base + 2]
			local first, stop = plan.candidate_cell_values[base + 3],
				plan.candidate_cell_values[base + 4]
			local parts = {}
			for c = first, stop - 1 do
				local cb = (c - 1) * 14
				for k = 1, 14 do parts[#parts + 1] = plan.candidate_values[cb + k] end
			end
			by_cell[cx .. "," .. cz] = table.concat(parts, ",")
		end
		return by_cell
	end
	local west = slice_rows(planner, 0, 560)
	local planner_c = B.planner(SEEDS[1], ramp, B.content())
	local east = slice_rows(planner_c, 80, 560)
	local shared = 0
	for key, value in pairs(west) do
		if east[key] ~= nil then
			shared = shared + 1
			if east[key] ~= value then seam_ok = false end
		end
	end
	check(seam_ok and shared > 0, "chunk seams: shared cells identical across planners and " ..
		"slices (" .. shared .. " shared cells)")
end

-- Density: flat worlds below the lines. Realized trees against the catalog
-- density times the mean factor, and the forest field's effect.
do
	local function flat_run(biome, dense_on, forest_on, cells)
		local saved_dense = V.DENSE
		if not dense_on then V.DENSE = {} end
		local wrapped = setmetatable({}, {__index = habitat})
		function wrapped.vegetation_rule(seed, zone_at)
			local base_rule = habitat.vegetation_rule(seed, zone_at)
			if not forest_on then base_rule.forest = function() return ONE end end
			return base_rule
		end
		local content = B.content(nil, wrapped)
		local flat = synthetic_source(function() return 50 end,
			function() return biome end, function() return ZONE end)
		local _, fixture = B.planner(SEEDS[1], flat, content)
		local trees, expected = 0, 0
		local rows = content.decorations()
		local r = content.vegetation_rule(SEEDS[1], flat)
		for cz = 0, cells - 1 do
			for cx = 0, cells - 1 do
				for _, row in ipairs(cell_rows(fixture, cx * 3, cz * 3)) do
					local x, z = row.x, row.z
					if floor(x / 16) == cx * 3 and floor(z / 16) == cz * 3 and
							habitat.decoration_class(rows[row.catalog]) == "tree" then
						trees = trees + 1
					end
				end
			end
		end
		-- expected: catalog density / support cover x factor over the same
		-- columns (outcrop patches of gravel or stone host no tree)
		local select = content.new_surface_selector(SEEDS[1], flat)
		for cz = 0, cells - 1 do
			for cx = 0, cells - 1 do
				for z = cz * 48, cz * 48 + 15 do
					for x = cx * 48, cx * 48 + 15 do
						local ref = content.content_ref(select(biome, x, z, nil, 50, ZONE).top)
						local f = r.factor("tree", x, z, 50, biome, ZONE) / ONE
						for _, row in ipairs(rows) do
							if habitat.decoration_class(row) == "tree" then
								local cover = content.decoration_cover(row.id, biome, ref)
								if cover > 0 then
									expected = expected + row.numerator / row.denominator / cover * f
								end
							end
						end
					end
				end
			end
		end
		V.DENSE = saved_dense
		return trees, expected
	end
	local n = quick and 12 or 30
	for _, case in ipairs({{"grug_deep_forest", 1.5}, {"grug_deep_jungle", 1.5},
			{"grug_pine_hills", 1}, {"grug_elf_forest", 1}}) do
		local biome = case[1]
		local trees, expected = flat_run(biome, true, true, n)
		local plain = flat_run(biome, false, false, n)
		out(("%s: %d trees, expected %.1f (ratio %.3f); catalog-only %d, ratio %.3f"):
			format(biome, trees, expected, trees / expected, plain, trees / plain))
		check(abs(trees / expected - 1) < (quick and 0.08 or 0.05),
			biome .. ": planner places catalog density x factor")
		check(abs(trees / plain - case[2]) < 0.15 * case[2],
			biome .. ": forest field and dense factor give x" .. case[2] .. " overall")
	end
end

-- 5. Renewal reads the same factors ----------------------------------------
out("-- renewal")
do
	local content = B.content()
	local function height_at(_, z) return 100 + floor(z / 4) end
	local function biome_at(x)
		return floor(x / 256) % 2 == 0 and "grug_pine_hills" or "grug_deep_forest"
	end
	local source = synthetic_source(height_at, biome_at, function() return ZONE end)
	local r = content.vegetation_rule(SEEDS[1], source)
	local density = B.density(r, content, source.column_values_at)
	local rows = content.decorations()
	local support = {grug_pine_hills = "default:dirt_with_coniferous_litter",
		grug_deep_forest = "grug_nodes:dirt_with_forest_litter"}
	local same, snow_ok, sites, tree_gone, shrub_band = true, true, 0, true, 0
	for z = 0, 1000, 13 do
		for x = 0, 511, 17 do
			local y = height_at(x, z)
			local biome = biome_at(x)
			local factors = {r.factors(x, z, y, biome, ZONE)}
			local list = density.categories(x, y + 1, z, support[biome], 15)
			local got = {}
			for _, category in ipairs(list or {}) do got[category.class] = category.p end
			local snow = r.snow_class(x, z, y, biome, ZONE)
			if snow ~= 0 then
				if got.cover or got.tree or got.shrub then snow_ok = false end
			else
				sites = sites + 1
				-- independent expectation: every row of the biome on this support
				local want = {cover = 0, tree = 0, shrub = 0}
				local ref = content.content_ref(support[biome])
				for _, row in ipairs(rows) do
					local cover = content.decoration_cover(row.id, biome, ref)
					local rule_class = habitat.decoration_class(row)
					if cover > 0 and row.id ~= "crags_snowy_pine" and
							row.id ~= "deep_forest_apple_log" then
						local class = row.kind == "simple" and "cover" or
							((rule_class == "shrub" or rule_class == "shrub_band" or
								row.id == "pine_hills_blueberry_bush") and "shrub" or "tree")
						want[class] = want[class] + row.numerator / row.denominator / cover *
							factors[r.class_index(rule_class)] / ONE
					end
				end
				for _, class in ipairs({"cover", "tree", "shrub"}) do
					if abs((got[class] or 0) - want[class]) > 1e-12 then same = false end
				end
				local _, line = r.lines(x, z, biome, ZONE)
				if y >= line and got.tree then tree_gone = false end
				if y >= line and got.shrub then shrub_band = shrub_band + 1 end
			end
		end
	end
	check(same and sites > 100, "renewal densities = catalog x the planner's factors (" ..
		sites .. " sites, per class)")
	check(snow_ok, "renewal grows no decoration on snow")
	check(tree_gone and shrub_band > 0, "renewal: no tree above the tree line, shrubs in the band")
end

-- 6. The real world: planner at the Stormvault heights --------------------
out("-- real world planner")
do
	local W = worlds[1]
	local ps = W.planner_source
	local content = B.content(ps.start_ground_names())
	local planner, fixture = B.planner(SEEDS[1], ps, content, W.source)
	local r = content.vegetation_rule(SEEDS[1], ps)
	-- the highest column of a coarse scan of the heights
	local best, bx, bz = -math.huge, 0, 0
	for z = -1300, -100, 16 do
		for x = -1800, -400, 16 do
			local water, _, zone, _, _, y = ps.column_values_at(x, z)
			if water == "land" and zone == "elandor_stormvault_heights" and y > best then
				best, bx, bz = y, x, z
			end
		end
	end
	out(("stormvault peak near %d,%d y %d"):format(bx, bz, best))
	local ids = {}
	for index, row in ipairs(content.decorations()) do ids[index] = row.id end
	local total, bad, trees, band_trees = 0, 0, 0, 0
	local ccx, ccz = floor(bx / 16), floor(bz / 16)
	local stride = quick and 4 or 2
	for cz = ccz - 24, ccz + 24, stride do
		for cx = ccx - 24, ccx + 24, stride do
			for _, row in ipairs(cell_rows(fixture, cx, cz)) do
				local x, z, y = row.x, row.z, row.y - 1
				if floor(x / 16) == cx and floor(z / 16) == cz then
					total = total + 1
					local _, _, zone, biome = ps.column_values_at(x, z)
					local class = habitat.decoration_class(content.decorations()[row.catalog])
					local start, line, snow = r.lines(x, z, biome, zone)
					if (class == "tree" or class == "last_tree") then
						trees = trees + 1
						if y >= line then bad = bad + 1 end
						if y >= start then band_trees = band_trees + 1 end
					end
					if y >= snow then bad = bad + 1 end
				end
			end
		end
	end
	out(("peak area: %d decorations, %d trees (%d in the thinning band), %d violations"):
		format(total, trees, band_trees, bad))
	check(bad == 0 and band_trees > 0,
		"real terrain: trees thin in the band, none above the line, nothing on snow")
end

local digest = 0
local text = table.concat(lines, "\n")
for index = 1, #text do digest = (digest * 131 + text:byte(index)) % 2147483629 end
print("DIGEST " .. digest)
print(failures == 0 and "RESULT PASS" or ("RESULT FAIL " .. failures))
