-- WP40 T2 collected-correction synthetic KATs (contracts sections 8.3 and
-- 13.4).
--
-- The D1 order keys 2-6 are reachable by no measured configuration over the
-- full `W` -- key 1 selects uniquely at all 759 retained multi-complete
-- records, under both the declared coordinate metric and the superseded
-- rendered-text one (contracts 13.2) -- and the full-`W` M3<->compiler
-- cross-check therefore never exercises them.  These synthetic descriptor
-- pairs pin each key on ALL THREE implementations: the compile comparator and
-- the projection comparator of geometry/partition.lua (contracts 8.1) and the
-- independent C2 oracle of tools/wp40/t2_r19_order_oracle.lua.  All three must
-- agree case by case and with the pinned winner, and every case re-runs under
-- reversed authored orientation, which must select the same world tuple (plan
-- 7.1's reversal invariance as an executed check).  This three-way agreement
-- is what contracts 13.4 requires in place of the retired keys-4/5 tripwire.
--
-- Keys 4 and 5 are the declared "lexicographic by (x, z)" over signed integer
-- coordinate pairs.  Production used to compare the rendered text `x .. ":" ..
-- z` for those two keys; contracts section 13 ruled the coordinate tuple the
-- authority and aligned production to it.  So that the correction is tested
-- rather than asserted, this file also carries the SUPERSEDED metric as a
-- named function, computes its answer for every case, and rejects it wherever
-- the two orders invert -- these KATs fail against the pre-alignment code.
--
-- The runner byte-compares this script's stdout between LuaJIT and PUC 5.1
-- (contracts 8.6.2).
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
local order_oracle = dofile(repo .. "/tools/wp40/t2_r19_order_oracle.lua")

local less_compile = assert(partition.joint_tuple_less_compile,
	"partition does not export the compile comparator")
local less_census = assert(partition.joint_tuple_less_census,
	"partition does not export the census comparator")
local less_oracle = assert(order_oracle.less,
	"the C2 order oracle does not export its comparator")

local function point(x, z)
	return {x = x, z = z}
end

local function descriptor(values)
	return {from_retreat = values.from, to_retreat = values.to,
		elbow_count = values.elbows or 0,
		terminal_points = values.terminals or {point(100, 200), point(300, 400)},
		previous_points = values.previous or {point(101, 200), point(299, 400)},
		probe_forward = values.forward or "100:200;101:200;299:400;300:400",
		probe_reverse = values.reverse or "300:400;299:400;101:200;100:200"}
end

-- Authored reversal swaps the from/to endpoints and exactly reverses the
-- probe bytes; world coordinates -- the terminal and previous sets -- do
-- not move.  A single-transition edge's one endpoint changes sides.
--
-- The coordinate ARRAYS do move, though, which is why they are reversed here
-- rather than passed through.  `joint_descriptor` appends the from terminal
-- before the to terminal, so swapping the two slots reverses both arrays.
-- Keys 4 and 5 are declared over the SORTED sets, so a comparator that
-- really sorts is unaffected and one that leans on the authored array order
-- is not.  New arrays are built: the originals are the cases' own pinned
-- data and must not move under the caller.
local function reverse_points(points)
	local copy = {}
	for index = 1, #points do
		copy[index] = points[#points - index + 1]
	end
	return copy
end

local function reversed(d)
	return {from_retreat = d.to_retreat, to_retreat = d.from_retreat,
		elbow_count = d.elbow_count,
		terminal_points = reverse_points(d.terminal_points),
		previous_points = reverse_points(d.previous_points),
		probe_forward = d.probe_reverse, probe_reverse = d.probe_forward}
end

-- The C2 oracle compares already-derived tuples, so this adapter derives keys
-- 1, 2 and 6 from the descriptor and hands the oracle its own sorted (x, z)
-- sequences for keys 4 and 5.  The comparison itself is entirely the oracle's.
local function oracle_tuple(d)
	local terminals, previouses = {}, {}
	for index = 1, #d.terminal_points do
		terminals[index] = point(d.terminal_points[index].x,
			d.terminal_points[index].z)
	end
	for index = 1, #d.previous_points do
		previouses[index] = point(d.previous_points[index].x,
			d.previous_points[index].z)
	end
	table.sort(terminals, order_oracle.point_less)
	table.sort(previouses, order_oracle.point_less)
	local probe = d.probe_forward
	if d.probe_reverse < probe then probe = d.probe_reverse end
	return {total_retreat = (d.from_retreat or 0) + (d.to_retreat or 0),
		max_retreat = math.max(d.from_retreat or 0, d.to_retreat or 0),
		elbow_count = d.elbow_count, terminals = terminals,
		previouses = previouses, canonical = probe}
end

-- The SUPERSEDED metric, kept here as a value the test names and rejects: the
-- pre-alignment production comparator, byte for byte in behaviour, with keys 4
-- and 5 compared as the rendered "x:z" text (sorted, joined with ",").  Keys
-- 1-3 and 6 are identical to the aligned order, so this function's answer
-- differs from the declared one exactly where the two metrics invert.
local function superseded_text_less(left, right)
	local left_total = (left.from_retreat or 0) + (left.to_retreat or 0)
	local right_total = (right.from_retreat or 0) + (right.to_retreat or 0)
	if left_total ~= right_total then return left_total < right_total end
	local left_peak = math.max(left.from_retreat or 0, left.to_retreat or 0)
	local right_peak = math.max(right.from_retreat or 0, right.to_retreat or 0)
	if left_peak ~= right_peak then return left_peak < right_peak end
	if left.elbow_count ~= right.elbow_count then
		return left.elbow_count < right.elbow_count
	end
	local function sorted_text(points)
		local copy = {}
		for index = 1, #points do
			copy[index] = points[index].x .. ":" .. points[index].z
		end
		table.sort(copy)
		return table.concat(copy, ",")
	end
	local left_terminals = sorted_text(left.terminal_points)
	local right_terminals = sorted_text(right.terminal_points)
	if left_terminals ~= right_terminals then
		return left_terminals < right_terminals
	end
	local left_previous = sorted_text(left.previous_points)
	local right_previous = sorted_text(right.previous_points)
	if left_previous ~= right_previous then
		return left_previous < right_previous
	end
	local left_probe = left.probe_reverse < left.probe_forward and
		left.probe_reverse or left.probe_forward
	local right_probe = right.probe_reverse < right.probe_forward and
		right.probe_reverse or right.probe_forward
	return left_probe < right_probe
end

local function verdict(left_wins)
	if left_wins == nil then return "equal" end
	return left_wins and "left" or "right"
end

local lines = {}
local function run_case(name, left, right, expect_left_wins, expect_text_wins)
	local forward_compile = less_compile(left, right)
	local backward_compile = less_compile(right, left)
	local forward_census = less_census(left, right)
	local backward_census = less_census(right, left)
	local forward_oracle = less_oracle(oracle_tuple(left), oracle_tuple(right))
	local backward_oracle = less_oracle(oracle_tuple(right), oracle_tuple(left))
	assert(forward_compile == forward_census and
		backward_compile == backward_census,
		name .. ": the two production comparator implementations disagree")
	assert(forward_compile == forward_oracle and
		backward_compile == backward_oracle,
		name .. ": production and the independent C2 oracle disagree")
	if expect_left_wins == nil then
		assert(not forward_compile and not backward_compile,
			name .. ": expected order-equality, got a strict order")
	else
		assert(forward_compile == expect_left_wins and
			backward_compile == not expect_left_wins,
			name .. ": winner differs from the pinned expectation")
	end
	-- The superseded rendered-text metric's own answer, named by the case and
	-- checked here.  Where it differs from the declared coordinate order, the
	-- assert below rejects it explicitly: these cases fail against production
	-- as it stood before contracts section 13.
	local text_forward = superseded_text_less(left, right)
	local text_backward = superseded_text_less(right, left)
	local text_wins = nil
	if text_forward then text_wins = true elseif text_backward then
		text_wins = false
	end
	assert(text_wins == expect_text_wins,
		name .. ": the superseded text metric's winner is not the pinned one")
	if expect_text_wins ~= expect_left_wins then
		assert(forward_compile ~= text_forward and
			forward_census ~= text_forward and forward_oracle ~= text_forward,
			name .. ": an inverting case selected the text-order winner")
	end
	-- Reversal invariance: the same world tuple must win with both
	-- descriptors reversed, on all three implementations.
	local reversed_compile = less_compile(reversed(left), reversed(right))
	local reversed_census = less_census(reversed(left), reversed(right))
	local reversed_oracle = less_oracle(oracle_tuple(reversed(left)),
		oracle_tuple(reversed(right)))
	assert(reversed_compile == forward_compile and
		reversed_census == forward_census and
		reversed_oracle == forward_oracle,
		name .. ": authored reversal changed the selected tuple")
	lines[#lines + 1] = name .. " " .. verdict(expect_left_wins) ..
		" text " .. verdict(expect_text_wins)
	print(lines[#lines])
end

-- Key 1 on a single-transition edge (the common measured shape): total
-- retreat decides, and reversal moves the endpoint to the other side.
run_case("key1_single_endpoint",
	descriptor({from = 1, forward = "1:1;2:2;3:3", reverse = "3:3;2:2;1:1"}),
	descriptor({from = 2, forward = "2:1;3:2;4:3", reverse = "4:3;3:2;2:1"}),
	true, true)

-- Key 2: total retreat ties at 4, the smaller maximum per-endpoint retreat
-- wins -- (2,2) beats (1,3).
run_case("key2_sum_tie_max",
	descriptor({from = 1, to = 3}),
	descriptor({from = 2, to = 2}),
	false, false)

-- Key 3: retreats identical, the tuple with fewer elbow terminals wins.
run_case("key3_elbow_count",
	descriptor({from = 2, to = 2, elbows = 1}),
	descriptor({from = 2, to = 2, elbows = 0}),
	false, false)

-- Key 4: sum, max and elbows tie -- (1,3) against (3,1) -- and the sorted
-- resolved terminal set decides.  This is an INVERTING case and was pinned
-- the other way before contracts section 13: as coordinates the sorted
-- sequences are (5,20),(30,40) against (10,20),(30,40) and 5 < 10, so the
-- right tuple wins; as text "10:20,30:40" precedes "30:40,5:20" because "1"
-- sorts below "3", which used to select the left one.
run_case("key4_terminal_set",
	descriptor({from = 1, to = 3, terminals = {point(10, 20), point(30, 40)},
		forward = "10:20;20:30;30:40", reverse = "30:40;20:30;10:20"}),
	descriptor({from = 3, to = 1, terminals = {point(5, 20), point(30, 40)},
		forward = "5:20;20:30;30:40", reverse = "30:40;20:30;5:20"}),
	false, true)

-- Key 5: terminals tie too; the sorted previous set decides.  Text and
-- coordinates agree here (298 < 299 either way).
run_case("key5_previous_set",
	descriptor({from = 2, to = 2,
		previous = {point(101, 200), point(298, 400)}}),
	descriptor({from = 2, to = 2,
		previous = {point(101, 200), point(299, 400)}}),
	true, true)

-- Key 6: only the probe bytes differ, compared under canonical
-- orientation -- the lexicographically lesser of the byte text and its
-- exact reverse.  Left's canonical text "1:1;..." precedes right's
-- "1:2;...".  Key 6 is a byte sequence by declaration and section 13 did
-- not reopen it, so the two metrics cannot differ here.
run_case("key6_canonical_probe",
	descriptor({from = 2, to = 2, forward = "9:9;5:5;1:1",
		reverse = "1:1;5:5;9:9"}),
	descriptor({from = 2, to = 2, forward = "1:2;5:5;9:9",
		reverse = "9:9;5:5;1:2"}),
	true, true)

-- Keys 4-6 all equal is duplicate authority: the duplicate reject fires
-- before the order applies (contracts 8.1), so the order itself must
-- declare exact equality -- neither side less -- and never invent a
-- private tie.
run_case("key456_equality_is_duplicate_authority",
	descriptor({from = 2, to = 2}),
	descriptor({from = 2, to = 2}),
	nil, nil)

-- ----------------------------------------------------------------------
-- Keys 4 and 5 isolated (contracts 13.4 condition 4): keys 1-3 equal on
-- both sides -- one declared endpoint at retreat 0, no elbow -- and
-- identical probe bytes, so nothing but the coordinate sets can decide.
-- Each shape appears once deciding at key 4 (terminal sets differ) and the
-- three inverting shapes again at key 5 (terminal sets equal, previous
-- sets differ).  Both authored orientations run for every case.
-- ----------------------------------------------------------------------
local function keyed(terminals, previouses)
	return descriptor({from = 0, terminals = terminals,
		previous = previouses, forward = "0:0;1:1", reverse = "1:1;0:0"})
end

-- The R19 witness pair, negative x of equal digit width: the two land_010
-- stations of contracts 12.5.  Coordinates say -1135 < -1134; text says
-- "-1134:2242" < "-1135:2242".  The tuple carrying -1135 must win.
run_case("key4_witness_negative_x",
	keyed({point(-1135, 2242)}, {point(-1136, 2242)}),
	keyed({point(-1134, 2242)}, {point(-1136, 2242)}),
	true, false)

-- Mixed digit width: coordinates say 9 < 10, text says "10:7" < "9:7".
run_case("key4_mixed_digit_width",
	keyed({point(9, 7)}, {point(0, 7)}),
	keyed({point(10, 7)}, {point(0, 7)}),
	true, false)

-- The sign boundary does NOT invert: "-" sorts below "0", so text and
-- coordinates agree that -1 precedes 0.  Included precisely because a
-- correction whose cases all inverted would be easier to believe and wrong.
run_case("key4_sign_boundary_agrees",
	keyed({point(-1, 7)}, {point(0, 7)}),
	keyed({point(0, 7)}, {point(0, 7)}),
	true, true)

-- Equal x, z deciding; both metrics agree, and this is the only key-4 case
-- where the second coordinate is load-bearing at all.
run_case("key4_equal_x_z_decides",
	keyed({point(5, 3)}, {point(0, 7)}),
	keyed({point(5, 4)}, {point(0, 7)}),
	true, true)

-- The prefix/separator shape: text says "12:3" < "1:5" because "2" sorts
-- below ":", coordinates say 1 < 12.
run_case("key4_prefix_separator",
	keyed({point(1, 5)}, {point(0, 7)}),
	keyed({point(12, 3)}, {point(0, 7)}),
	true, false)

-- The same three inverting shapes one key deeper: terminal sets are equal,
-- so keys 1-4 all tie and the previous set decides.
run_case("key5_witness_negative_x",
	keyed({point(-1000, 2242)}, {point(-1135, 2242)}),
	keyed({point(-1000, 2242)}, {point(-1134, 2242)}),
	true, false)

run_case("key5_mixed_digit_width",
	keyed({point(0, 7)}, {point(9, 7)}),
	keyed({point(0, 7)}, {point(10, 7)}),
	true, false)

run_case("key5_prefix_separator",
	keyed({point(0, 7)}, {point(1, 5)}),
	keyed({point(0, 7)}, {point(12, 3)}),
	true, false)

-- ----------------------------------------------------------------------
-- The "sorted set" half of keys 4 and 5 (plan 7.1: "the SORTED set of
-- resolved terminal world coordinates").  Every case above hands the
-- comparators arrays that are already in (x, z) order, so deleting the
-- `table.sort` from both production comparators leaves all of them green --
-- measured, which is why these two exist.  Each of the two cases below gives
-- one array deliberately out of (x, z) order, arranged so that a comparator
-- which walked the authored order instead of the sorted one would pick the
-- OTHER tuple.  Two declared endpoints per side, so the arrays have two
-- elements and the permutation is real.
-- ----------------------------------------------------------------------

-- Key 4, terminal array out of order.  Sorted, the sequences are
-- (5,20),(30,40) against (10,20),(30,40) and 5 < 10, so the left tuple wins;
-- walked as authored, the first pair is (30,40) against (10,20) and the right
-- tuple would win instead.  The text metric sorts the rendered tokens and
-- lands on "10:20,30:40" before "30:40,5:20", so this case also inverts
-- against the superseded order and is rejected there.
run_case("key4_terminal_array_unsorted",
	descriptor({from = 2, to = 2,
		terminals = {point(30, 40), point(5, 20)}}),
	descriptor({from = 2, to = 2,
		terminals = {point(10, 20), point(30, 40)}}),
	true, false)

-- Key 5, previous array out of order.  The terminal sets are the shared
-- default and tie under either reading, so the previous sets decide: sorted,
-- (98,200),(299,400) against (101,200),(299,400) and 98 < 101, so the left
-- tuple wins; walked as authored, the first pair is (299,400) against
-- (101,200) and the right tuple would win.  Text sorts to "101:200,299:400"
-- before "299:400,98:200", so this one inverts as well.
run_case("key5_previous_array_unsorted",
	descriptor({from = 2, to = 2,
		previous = {point(299, 400), point(98, 200)}}),
	descriptor({from = 2, to = 2,
		previous = {point(101, 200), point(299, 400)}}),
	true, false)

local digest = canonical.hex(raw_sha256(table.concat(lines, "\n")))
print("correction synthetic KAT digest " .. digest)
print("correction synthetic KATs passed (D1 keys 1-6, both production " ..
	"comparators, the independent C2 oracle, reversal invariance, and the " ..
	"superseded text metric named and rejected)")
