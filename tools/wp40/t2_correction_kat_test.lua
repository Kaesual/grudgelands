-- WP40 T2 collected-correction synthetic KATs (contracts section 8.3).
-- The D1 order keys 2-6 are reachable by no measured configuration over the
-- full `W` -- key 1 selects uniquely at all 757 multi-complete records --
-- and the full-`W` M3<->compiler cross-check therefore never exercises
-- them.  These synthetic descriptor pairs pin each key on both comparator
-- implementations (compile and projection, contracts 8.1), require the two
-- to agree case by case, and re-run every case under reversed authored
-- orientation, which must select the same world tuple (plan 7.1's reversal
-- invariance as an executed check).  The runner byte-compares this
-- script's stdout between LuaJIT and PUC 5.1 (contracts 8.6.2).
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local raw_sha256 = hasher.raw_sha256

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local exact = dofile(wp40 .. "/geometry/exact.lua")({
	deterministic = deterministic})
local raster = dofile(wp40 .. "/geometry/raster.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256})
local source = dofile(wp40 .. "/source/catalog.lua")
local source_validator = dofile(wp40 .. "/validation/t2_source.lua")
local vocabulary = dofile(repo ..
	"/tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
local new_boundary = dofile(wp40 .. "/geometry/boundary.lua")
local partition = dofile(wp40 .. "/geometry/partition.lua")({
	canonical = canonical, deterministic = deterministic, exact = exact,
	new_boundary = new_boundary, raster = raster, raw_sha256 = raw_sha256,
	source = source, source_validator = source_validator,
	vocabulary = vocabulary})

local less_compile = assert(partition.joint_tuple_less_compile,
	"partition does not export the compile comparator")
local less_census = assert(partition.joint_tuple_less_census,
	"partition does not export the census comparator")

local function descriptor(values)
	return {from_retreat = values.from, to_retreat = values.to,
		elbow_count = values.elbows or 0,
		terminal_keys = values.terminals or {"100:200", "300:400"},
		previous_keys = values.previous or {"101:200", "299:400"},
		probe_forward = values.forward or "100:200;101:200;299:400;300:400",
		probe_reverse = values.reverse or "300:400;299:400;101:200;100:200"}
end

-- Authored reversal swaps the from/to endpoints and exactly reverses the
-- probe bytes; world coordinates -- the terminal and previous sets -- do
-- not move.  A single-transition edge's one endpoint changes sides.
local function reversed(d)
	return {from_retreat = d.to_retreat, to_retreat = d.from_retreat,
		elbow_count = d.elbow_count, terminal_keys = d.terminal_keys,
		previous_keys = d.previous_keys, probe_forward = d.probe_reverse,
		probe_reverse = d.probe_forward}
end

local lines = {}
local function run_case(name, left, right, expect_left_wins)
	local forward_compile = less_compile(left, right)
	local backward_compile = less_compile(right, left)
	local forward_census = less_census(left, right)
	local backward_census = less_census(right, left)
	assert(forward_compile == forward_census and
		backward_compile == backward_census,
		name .. ": the two comparator implementations disagree")
	if expect_left_wins == nil then
		assert(not forward_compile and not backward_compile,
			name .. ": expected order-equality, got a strict order")
	else
		assert(forward_compile == expect_left_wins and
			backward_compile == not expect_left_wins,
			name .. ": winner differs from the pinned expectation")
	end
	-- Reversal invariance: the same world tuple must win with both
	-- descriptors reversed.
	local reversed_forward = less_compile(reversed(left), reversed(right))
	local reversed_census = less_census(reversed(left), reversed(right))
	assert(reversed_forward == forward_compile and
		reversed_census == forward_census,
		name .. ": authored reversal changed the selected tuple")
	lines[#lines + 1] = name .. " " ..
		(expect_left_wins == nil and "equal" or
			(expect_left_wins and "left" or "right"))
	print(lines[#lines])
end

-- Key 1 on a single-transition edge (the common measured shape): total
-- retreat decides, and reversal moves the endpoint to the other side.
run_case("key1_single_endpoint",
	descriptor({from = 1, forward = "1:1;2:2;3:3", reverse = "3:3;2:2;1:1"}),
	descriptor({from = 2, forward = "2:1;3:2;4:3", reverse = "4:3;3:2;2:1"}),
	true)

-- Key 2: total retreat ties at 4, the smaller maximum per-endpoint retreat
-- wins -- (2,2) beats (1,3).
run_case("key2_sum_tie_max",
	descriptor({from = 1, to = 3}),
	descriptor({from = 2, to = 2}),
	false)

-- Key 3: retreats identical, the tuple with fewer elbow terminals wins.
run_case("key3_elbow_count",
	descriptor({from = 2, to = 2, elbows = 1}),
	descriptor({from = 2, to = 2, elbows = 0}),
	false)

-- Key 4: sum, max and elbows tie -- (1,3) against (3,1) -- and the sorted
-- resolved terminal set decides: "10:20,30:40" precedes "30:40,5:20".
run_case("key4_terminal_set",
	descriptor({from = 1, to = 3, terminals = {"10:20", "30:40"},
		forward = "10:20;20:30;30:40", reverse = "30:40;20:30;10:20"}),
	descriptor({from = 3, to = 1, terminals = {"5:20", "30:40"},
		forward = "5:20;20:30;30:40", reverse = "30:40;20:30;5:20"}),
	true)

-- Key 5: terminals tie too; the sorted previous set decides.
run_case("key5_previous_set",
	descriptor({from = 2, to = 2, previous = {"101:200", "298:400"}}),
	descriptor({from = 2, to = 2, previous = {"101:200", "299:400"}}),
	true)

-- Key 6: only the probe bytes differ, compared under canonical
-- orientation -- the lexicographically lesser of the byte text and its
-- exact reverse.  Left's canonical text "1:1;..." precedes right's
-- "1:2;...".
run_case("key6_canonical_probe",
	descriptor({from = 2, to = 2, forward = "9:9;5:5;1:1",
		reverse = "1:1;5:5;9:9"}),
	descriptor({from = 2, to = 2, forward = "1:2;5:5;9:9",
		reverse = "9:9;5:5;1:2"}),
	true)

-- Keys 4-6 all equal is duplicate authority: the duplicate reject fires
-- before the order applies (contracts 8.1), so the order itself must
-- declare exact equality -- neither side less -- and never invent a
-- private tie.
run_case("key456_equality_is_duplicate_authority",
	descriptor({from = 2, to = 2}),
	descriptor({from = 2, to = 2}),
	nil)

local digest = canonical.hex(raw_sha256(table.concat(lines, "\n")))
print("correction synthetic KAT digest " .. digest)
print("correction synthetic KATs passed (D1 keys 1-6, both comparators, " ..
	"reversal invariance)")
