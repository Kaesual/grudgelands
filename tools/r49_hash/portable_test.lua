-- Round 49 lane HASH portable fixture (LuaJIT; mapgen-native-plan.md §4.5):
--
--   luajit tools/r49_hash/portable_test.lua REPO
--
--   A. The same draws under LuaJIT and plain Lua 5.1 over a large sample
--      (tools/r49_hash/sample.lua, tools/bin/lua51).
--   B. Uniformity: bucket chi-square of the residues the writers take
--      (% 4, % 3, % 32, % 256, % 64 and the top 64 buckets).
--   C. Neighbouring coordinates do not correlate (x, z, both diagonals, y).
--   D. Streams are independent: a row's rank and thinning draw, two rows'
--      ranks, rotation and variant, two seeds, two adjacent integer salts
--      (the fill ores' cluster and voxel streams); correlation and the joint
--      chi-square of their residues.
--   E. No grid or diagonal artefacts: the top 8 of every 16 x 16 cell spread
--      evenly over the cell's positions, its diagonals and anti-diagonals.
--   F. The real rows' salts differ (no two streams of a world coincide).
--   G. Rates stay: the cell budget's expected value and the thinning test's
--      acceptance rate are those of the catalog numbers.
--   H. The SHA-256 vocabulary keeps only the seeded trees' domain;
--      `prepare_root_draw` is gone; an unlisted placement domain fails.
--   I. No lattice period and no point mirror (review of 54a0177d, whose
--      mix fed a, b, c through one linear form): the review's steps
--      (905, 462) and (179, -16, 287) and every step within +-2048 (x, z)
--      or +-320 / +-32 / +-320 (x, y, z) leave the stream changed; the
--      review's mirror centre and every centre of a 4096 x 4096 box are
--      no point mirrors.
-- An optional second argument names another r6_hash.lua to test (e.g. the
-- 54a0177d one, which fails I).
-- The chi-square bounds are the 0.1 % critical values; the sample is fixed,
-- so the results do not vary between runs.
-- Prints "R49 HASH PORTABLE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local floor = math.floor

local hash = dofile(arg[2] or (wp40 .. "/r6_hash.lua"))()
local PRIME = hash.PLACEMENT_PRIME
local decorations = dofile(wp40 .. "/r7_r6_manifest.lua")().decorations
local gathering = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua").p9g_sources()
local SEED = "10536739806879207652"
local mix, salt = hash.placement(SEED)

-- A. LuaJIT == Lua 5.1 ------------------------------------------------------------
local function run(interpreter)
	local pipe = io.popen(interpreter .. " " .. repo .. "/tools/r49_hash/sample.lua " ..
		repo .. " 2>&1")
	local text = pipe:read("*a")
	pipe:close()
	return text
end
local jit_line = run("luajit")
check(jit_line:match("^placement sample: %d+ values, checksum %d+"),
	"sample under LuaJIT: " .. jit_line)
local lua51 = repo .. "/tools/bin/lua51"
local probe = io.open(lua51, "rb")
if probe then
	probe:close()
	local plain_line = run(lua51)
	check(plain_line == jit_line, "sample LuaJIT " .. jit_line .. " vs Lua 5.1 " .. plain_line)
	io.write("A LuaJIT = Lua 5.1: " .. jit_line)
else
	print("note: tools/bin/lua51 absent (tools/build_lua51.sh), Lua 5.1 comparison skipped")
end

-- The test field: 500 x 500 columns of one region, the y a synthetic terrain.
local W = 500
local N = W * W
local function column(i)
	local k = i - 1
	local x, z = k % W - 1250, floor(k / W) + 2200
	return x, floor(20 + 9 * math.sin(x / 41) + 7 * math.cos(z / 29)), z
end
local id_a, id_b = decorations[1].id, decorations[2].id
local rank_a = salt("decoration_candidate_rank", id_a)
local thin_a = salt("decoration_candidate_thin", id_a)
local rank_b = salt("decoration_candidate_rank", id_b)
local rotation_a = salt("decoration_rotation", id_a)
local variant_a = salt("decoration_variant", id_a)
local p9g_a = salt("gathering_candidate_rank", gathering[1].id)
local p9g_b = salt("gathering_candidate_rank", gathering[2].id)
local other_mix = hash.placement("12345")

-- B. Uniformity ------------------------------------------------------------------------
local function chi_square(buckets, value)
	local counts = {}
	for b = 0, buckets - 1 do counts[b] = 0 end
	for i = 1, N do
		local v = value(i)
		counts[v] = counts[v] + 1
	end
	local expected, sum = N / buckets, 0
	for b = 0, buckets - 1 do sum = sum + (counts[b] - expected) * (counts[b] - expected) / expected end
	return sum
end
-- 0.1 % critical values of the chi-square distribution by degrees of freedom
local CRITICAL = {[2] = 13.82, [3] = 16.27, [15] = 37.70, [31] = 61.10, [63] = 103.4,
	[255] = 330.5}
local function uniform(label, buckets, value)
	local sum = chi_square(buckets, value)
	print(("B %-38s chi2 %7.1f (df %d, bound %.1f)"):format(label, sum, buckets - 1,
		CRITICAL[buckets - 1]))
	check(sum < CRITICAL[buckets - 1], label .. " uniform")
end
local function rank2(i) local x, _, z = column(i) return mix(x, 0, z, rank_a) end
local function p9g3(i) local x, y, z = column(i) return mix(x, y, z, p9g_a) end
uniform("R6 rank % 64", 64, function(i) return rank2(i) % 64 end)
uniform("R6 rank top 64 buckets", 64, function(i) return floor(rank2(i) * 64 / PRIME) end)
uniform("R6 thinning low byte % 4", 4, function(i)
	local x, _, z = column(i) return mix(x, 0, z, thin_a) % 4 end)
uniform("R6 thinning bits 8-23, top 64 buckets", 64, function(i)
	local x, _, z = column(i) return floor(floor(mix(x, 0, z, thin_a) / 256) / 1024) end)
uniform("P9 rotation % 4", 4, function(i)
	local x, y, z = column(i) return mix(x, y, z, rotation_a) % 4 end)
uniform("P9 simple height % 3", 3, function(i)
	local x, y, z = column(i) return mix(x, y, z, salt("decoration_simple_height", id_a)) % 3
end)
uniform("P9 variant % 32", 32, function(i)
	local x, y, z = column(i) return mix(x, y, z, variant_a) % 32 end)
uniform("P9 template node trial % 256", 256, function(i)
	local x, y, z = column(i)
	local root = mix(x, y, z, salt("template_probability", id_a))
	return mix(i % 16, i % 64, floor(i / 16) % 16, root) % 256
end)
uniform("P9G rank % 64", 64, function(i) return p9g3(i) % 64 end)

-- C. Neighbours ----------------------------------------------------------------------------
local function correlation(f, g)
	local sx, sy, sxx, syy, sxy = 0, 0, 0, 0, 0
	for i = 1, N do
		local a, b = f(i), g(i)
		sx, sy = sx + a, sy + b
		sxx, syy, sxy = sxx + a * a, syy + b * b, sxy + a * b
	end
	local mx, my = sx / N, sy / N
	return (sxy / N - mx * my) / math.sqrt((sxx / N - mx * mx) * (syy / N - my * my))
end
-- the standard error of a correlation over N independent pairs is 1/sqrt(N),
-- 0.002 here: the bound is five of them
local BOUND = 0.01
local function uncorrelated(label, f, g)
	local r = correlation(f, g)
	print(("%-48s r % .4f"):format(label, r))
	check(math.abs(r) < BOUND, label .. " uncorrelated")
end
local function at2(salt_value, dx, dz)
	return function(i)
		local x, _, z = column(i)
		return mix(x + dx, 0, z + dz, salt_value) / PRIME
	end
end
uncorrelated("C R6 rank: x and x+1", at2(rank_a, 0, 0), at2(rank_a, 1, 0))
uncorrelated("C R6 rank: z and z+1", at2(rank_a, 0, 0), at2(rank_a, 0, 1))
uncorrelated("C R6 rank: diagonal", at2(rank_a, 0, 0), at2(rank_a, 1, 1))
uncorrelated("C R6 rank: anti-diagonal", at2(rank_a, 0, 0), at2(rank_a, 1, -1))
uncorrelated("C R6 rank: x and x+16 (next cell)", at2(rank_a, 0, 0), at2(rank_a, 16, 0))
uncorrelated("C P9 rotation: y and y+1", function(i)
	local x, y, z = column(i) return mix(x, y, z, rotation_a) % 4 end, function(i)
	local x, y, z = column(i) return mix(x, y + 1, z, rotation_a) % 4 end)
uncorrelated("C R6 thinning parity: x and x+1", function(i)
	local x, _, z = column(i) return mix(x, 0, z, thin_a) % 2 end, function(i)
	local x, _, z = column(i) return mix(x + 1, 0, z, thin_a) % 2 end)

-- D. Independent streams -----------------------------------------------------------
local function joint(label, f, g)
	uncorrelated("D " .. label, function(i) return f(i) / PRIME end,
		function(i) return g(i) / PRIME end)
	local sum = chi_square(16, function(i) return f(i) % 4 * 4 + g(i) % 4 end)
	print(("D %-46s joint chi2 %6.1f (df 15, bound %.1f)"):format(label, sum, CRITICAL[15]))
	check(sum < CRITICAL[15], label .. " joint residues independent")
end
local function stream2(salt_value)
	return function(i) local x, _, z = column(i) return mix(x, 0, z, salt_value) end
end
local function stream3(salt_value, m)
	m = m or mix
	return function(i) local x, y, z = column(i) return m(x, y, z, salt_value) end
end
joint("R6 rank and thinning of one row", stream2(rank_a), stream2(thin_a))
joint("R6 ranks of two rows", stream2(rank_a), stream2(rank_b))
joint("P9 rotation and variant", stream3(rotation_a), stream3(variant_a))
joint("P9G ranks of two rows", stream3(p9g_a), stream3(p9g_b))
joint("one stream in two seeds", stream3(p9g_a), stream3(p9g_a, other_mix))
joint("adjacent integer salts (fill ores)", stream3(7919), stream3(7920))
joint("template trials of neighbouring nodes", function(i)
	local x, y, z = column(i)
	return mix(i % 16, i % 64, 3, mix(x, y, z, 99991)) end, function(i)
	local x, y, z = column(i)
	return mix(i % 16 + 1, i % 64, 3, mix(x, y, z, 99991)) end)

-- E. Grid and diagonal artefacts ---------------------------------------------------
do
	local CELLS, K = 64, 8
	local position, diagonal, anti = {}, {}, {}
	for b = 0, 255 do position[b] = 0 end
	for b = 0, 15 do diagonal[b], anti[b] = 0, 0 end
	local list = {}
	for b = 1, 256 do list[b] = {0, 0, 0} end
	local function before(left, right) return left[1] < right[1] end
	for cell_z = 0, CELLS - 1 do
		for cell_x = 0, CELLS - 1 do
			local n = 0
			for dz = 0, 15 do
				for dx = 0, 15 do
					n = n + 1
					local entry = list[n]
					entry[1] = mix(cell_x * 16 + dx - 512, 0, cell_z * 16 + dz + 700, rank_a)
					entry[2], entry[3] = dx, dz
				end
			end
			table.sort(list, before)
			for k = 1, K do
				local dx, dz = list[k][2], list[k][3]
				position[dz * 16 + dx] = position[dz * 16 + dx] + 1
				diagonal[(dx + dz) % 16] = diagonal[(dx + dz) % 16] + 1
				anti[(dx - dz) % 16] = anti[(dx - dz) % 16] + 1
			end
		end
	end
	local total = CELLS * CELLS * K
	local function chi(counts, buckets)
		local expected, sum = total / buckets, 0
		for b = 0, buckets - 1 do
			sum = sum + (counts[b] - expected) * (counts[b] - expected) / expected
		end
		return sum
	end
	local p, d, a = chi(position, 256), chi(diagonal, 16), chi(anti, 16)
	print(("E top %d of %d cells: position chi2 %.1f (bound %.1f), diagonal %.1f, " ..
		"anti-diagonal %.1f (bound %.1f)"):format(K, CELLS * CELLS, p, CRITICAL[255], d, a,
		CRITICAL[15]))
	check(p < CRITICAL[255], "chosen roots spread over the cell's positions")
	check(d < CRITICAL[15] and a < CRITICAL[15], "chosen roots show no diagonal")
end

-- F. Distinct salts ---------------------------------------------------------------------
for _, seed in ipairs({"1", "12345", SEED}) do
	local _, seed_salt = hash.placement(seed)
	local seen, total = {}, 0
	local function add(domain, id)
		local value = seed_salt(domain, id) % PRIME
		check(not seen[value], ("seed %s: %s %s has its own salt"):format(seed, domain, id))
		seen[value] = true
		total = total + 1
	end
	for _, row in ipairs(decorations) do
		for _, domain in ipairs({"decoration_candidate_rank", "decoration_candidate_thin",
				"decoration_budget_remainder", "decoration_rotation", "decoration_simple_height",
				"decoration_variant", "template_probability"}) do
			add(domain, row.id)
		end
	end
	for _, row in ipairs(gathering) do
		add("gathering_candidate_rank", row.id)
		add("gathering_budget_remainder", row.id)
	end
	print(("F seed %s: %d distinct stream salts"):format(seed, total))
end

-- G. Rates -------------------------------------------------------------------------------
do
	-- cell budgets: 37 eligible roots at 1/40, 200 at 3/1000 x 5/4
	for _, case in ipairs({{37, 1, 40, 1, 1}, {200, 3, 1000, 5, 4}, {96, 1, 384, 1, 1}}) do
		local remainder_salt = salt("decoration_budget_remainder", id_a)
		local sum, cells = 0, 0
		for cell_z = -60, 59 do
			for cell_x = -60, 59 do
				sum = sum + hash.budget(case[1], case[2], case[3], case[4], case[5],
					mix(cell_x, 0, cell_z, remainder_salt))
				cells = cells + 1
			end
		end
		local expected = case[1] * case[2] * case[4] / (case[3] * case[5])
		local mean = sum / cells
		print(("G budget %d x %d/%d x %d/%d: mean %.4f, expected %.4f"):format(case[1],
			case[2], case[3], case[4], case[5], mean, expected))
		check(math.abs(mean - expected) < 0.03 * math.max(expected, 1),
			"cell budget keeps its expected value")
	end
	-- thinning: one root in `cover`, then factor / (fmax x ONE)
	local ONE = 1024
	for _, case in ipairs({{1, 1, ONE}, {2, 3, 2 * ONE}, {4, 2, ONE}}) do
		local cover, fmax, factor = case[1], case[2], case[3]
		local accepted = 0
		for i = 1, N do
			local x, _, z = column(i)
			local thin = mix(x, 0, z, thin_a)
			if thin % cover == 0 and (fmax == 1 or floor(thin / 256) * fmax * ONE <
					factor * 65536) then
				accepted = accepted + 1
			end
		end
		local expected = (1 / cover) * (fmax == 1 and 1 or factor / (fmax * ONE))
		print(("G thinning cover %d, factor %d/%d: rate %.4f, expected %.4f"):format(cover,
			factor, fmax * ONE, accepted / N, expected))
		check(math.abs(accepted / N - expected) < 0.01, "thinning keeps its rate")
	end
end

-- H. Vocabulary -----------------------------------------------------------------------
local domains = hash.domains()
check(#domains == 1 and domains[1] == "tree_template_seed_v1",
	"SHA-256 is left only for the seeded trees' template seeds")
check(hash.prepare_root_draw == nil and hash.words == nil and hash.reduce_digest == nil,
	"the SHA draw helpers are gone")
check(not pcall(salt, "decoration_candidate_rank_v1", id_a),
	"an unlisted placement domain fails")
check(#hash.placement_domains() == 9, "nine placement domains")

-- I. No period, no point mirror ------------------------------------------------------
do
	-- A step d is a period of a stream when f(p + d) = f(p) for every p; a
	-- sum s is a point mirror (centre s / 2) when f(p) = f(s - p). Each test
	-- compares at one point and confirms a hit at two more, so a chance
	-- equality (about 1 in 2^24 per point) never counts.
	local P1, P2, P3 = {100, 0, -200}, {-1733, 0, 2411}, {2950, 0, -3011}
	local function shift(f, d, p) return f(p[1] + d[1], p[2] + d[2], p[3] + d[3]) end
	local function is_period(f, d)
		for _, p in ipairs({P1, P2, P3}) do
			if shift(f, d, p) ~= f(p[1], p[2], p[3]) then return false end
		end
		return true
	end
	local function is_mirror(f, s)
		for _, p in ipairs({P1, P2, P3}) do
			if f(s[1] - p[1], s[2] - p[2], s[3] - p[3]) ~= f(p[1], p[2], p[3]) then
				return false
			end
		end
		return true
	end
	local found = {}
	local function stream_xz(salt_value)
		return function(x, _, z) return mix(x, 0, z, salt_value) end
	end
	local function stream_xyz(salt_value)
		return function(x, y, z) return mix(x, y, z, salt_value) end
	end
	local xz = stream_xz(rank_a)
	local xyz = stream_xyz(p9g_a)
	for _, d in ipairs({{905, 0, 462}, {-905, 0, -462}, {1810, 0, 924}}) do
		if is_period(xz, d) then found[#found + 1] = ("x/z period (%d, %d)"):format(d[1], d[3]) end
	end
	for _, d in ipairs({{179, -16, 287}, {-179, 16, -287}, {358, -32, 574}}) do
		if is_period(xyz, d) then
			found[#found + 1] = ("x/y/z period (%d, %d, %d)"):format(d[1], d[2], d[3])
		end
	end
	-- brute search, x/z: every step within +-2048
	local base = xz(P1[1], 0, P1[3])
	local periods_xz = 0
	for dz = -2048, 2048 do
		for dx = -2048, 2048 do
			if (dx ~= 0 or dz ~= 0) and xz(P1[1] + dx, 0, P1[3] + dz) == base and
					is_period(xz, {dx, 0, dz}) then
				periods_xz = periods_xz + 1
			end
		end
	end
	if periods_xz > 0 then found[#found + 1] = periods_xz .. " x/z periods within +-2048" end
	-- brute search, x/y/z: +-320 in x and z, +-32 in y
	base = xyz(P1[1], P1[2], P1[3])
	local periods_xyz = 0
	for dy = -32, 32 do
		for dz = -320, 320 do
			for dx = -320, 320 do
				if (dx ~= 0 or dy ~= 0 or dz ~= 0) and
						xyz(P1[1] + dx, P1[2] + dy, P1[3] + dz) == base and
						is_period(xyz, {dx, dy, dz}) then
					periods_xyz = periods_xyz + 1
				end
			end
		end
	end
	if periods_xyz > 0 then
		found[#found + 1] = periods_xyz .. " x/y/z periods within +-320/32/320"
	end
	-- the review's mirror: the thinning stream of badlands_dry_shrub in seed
	-- 10536739806879207652 round (2339, -2899), and a brute search of the
	-- 4096 x 4096 sums round it
	local thin = stream_xz(salt("decoration_candidate_thin", "badlands_dry_shrub"))
	if is_mirror(thin, {4678, 0, -5798}) then
		found[#found + 1] = "point mirror round (2339, -2899)"
	end
	local mirrors = 0
	base = thin(P1[1], 0, P1[3])
	for sz = -5798 - 2048, -5798 + 2047 do
		for sx = 4678 - 2048, 4678 + 2047 do
			if thin(sx - P1[1], 0, sz - P1[3]) == base and is_mirror(thin, {sx, 0, sz}) then
				mirrors = mirrors + 1
			end
		end
	end
	if mirrors > 0 then found[#found + 1] = mirrors .. " point mirrors in the 4096 x 4096 box" end
	print("I periods x/z " .. periods_xz .. ", x/y/z " .. periods_xyz .. ", mirrors " ..
		mirrors .. (#found > 0 and (": " .. table.concat(found, "; ")) or ""))
	check(#found == 0, "no lattice period and no point mirror: " .. table.concat(found, "; "))
end

print("R49 HASH PORTABLE PASS checks=" .. checks)
