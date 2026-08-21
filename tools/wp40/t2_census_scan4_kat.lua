-- WP40 T2 census Scan-3b/4 synthetic classifier KATs (contracts 9.4).
-- Synthetic cases exist exactly where no measured configuration reaches the
-- branch: the R20/R21 event classifiers (v5 measured every dead condition
-- empty over `W`), the face not-closed / wrong-orientation / composition
-- classes (non-simple has real witnesses and is pinned by the worker KAT),
-- and the Whole tier's gap, undeclared-multiplicity and declared-seam
-- interval classes.  Every case drives the same exported functions the scan
-- runs -- partition.census_scan3b_classify_events,
-- partition.census_face_classify, partition.census_whole_classify -- and the
-- output is deterministic bytes: the runner executes this file under LuaJIT
-- and under the vendored PUC 5.1 and requires identical output (the 9.4
-- interpreter split).
--
--   t2_census_scan4_kat.lua REPO SCRATCH
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

local checks = 0
local function check(condition, label)
	checks = checks + 1
	if not condition then
		error("WP40 T2 census scan3b/4 classifier KAT failed: " .. label, 0)
	end
	print("classifier KAT " .. checks .. ": " .. label)
end

local function expect_error(fragment, label, callable, ...)
	local ok, failure = pcall(callable, ...)
	check(not ok and tostring(failure):find(fragment, 1, true) ~= nil,
		label .. " (" .. tostring(failure) .. ")")
end

-- ------------------------------------------------------------------
-- R20/R21 (contracts 9.4): descriptor-driven classifier cases.
-- ------------------------------------------------------------------
local classify = partition.census_scan3b_classify_events
local function dead(bank_id, far_kind, far_mode, far_site, wing_id)
	return {class = "scan2_tuple_bank_incomplete", bank_id = bank_id,
		far_kind = far_kind, far_mode = far_mode, far_site = far_site,
		wing_id = wing_id}
end

-- An all-tuples-dead-direct-anchor descriptor must classify
-- aperture_anchor_dead_event.
local events = classify({edge_id = "land_099", tuples = {
	dead("bank_a", "aperture", "direct", "bay_mouth_aperture:test:before"),
	dead("bank_a", "aperture", "direct", "bay_mouth_aperture:test:before"),
}}, nil)
check(#events == 1 and events[1].class == "aperture_anchor_dead_event" and
	events[1].site == "bay_mouth_aperture:test:before",
	"R20: all tuples dead with the same direct-anchor aperture Bank fires " ..
	"aperture_anchor_dead_event at the incidence")

-- The tail-mode variant is R18's own recovered class and is not this event.
events = classify({edge_id = "land_099", tuples = {
	dead("bank_a", "aperture", "diagonal_shoulder",
		"bay_mouth_aperture:test:before"),
}}, nil)
check(#events == 0,
	"R20 negative: a dead shoulder-tail aperture Bank is R18's recovered " ..
	"class, never aperture_anchor_dead_event")

-- A dead selected pair with a completing alternative must classify
-- wing_pair_dead_alternative_event.
events = classify({edge_id = "land_099", tuples = {
	dead("bank_w", "wing", "negative", "bay_wing:test:left:negative",
		"bay_wing:test:left"),
}}, function(bank_id, wing_id)
	check(bank_id == "bank_w" and wing_id == "bay_wing:test:left",
		"R21: the probe is consulted with the dead Bank and its Wing")
	return "complete"
end)
check(#events == 1 and events[1].class == "wing_pair_dead_alternative_event" and
	events[1].site == "bay_wing:test:left:negative",
	"R21: a dead pair with a completing alternative fires " ..
	"wing_pair_dead_alternative_event at the Wing")

-- A dead pair with no alternative must stay a plain attribution row.
events = classify({edge_id = "land_099", tuples = {
	dead("bank_w", "wing", "negative", "bay_wing:test:left:negative",
		"bay_wing:test:left"),
}}, function() return "no_alternative" end)
check(#events == 0,
	"R21 negative: a dead pair with no alternative stays a plain " ..
	"attribution row")

-- A dead pair whose alternative also dies stays a plain attribution row.
events = classify({edge_id = "land_099", tuples = {
	dead("bank_w", "wing", "negative", "bay_wing:test:left:negative",
		"bay_wing:test:left"),
}}, function() return "dead" end)
check(#events == 0,
	"R21 negative: a dead pair whose alternative also dies stays a plain " ..
	"attribution row")

-- Mixed tuple outcomes never classify: the dead condition is
-- every-tuple-dead, and a completing tuple means the edge selected.
events = classify({edge_id = "land_099", tuples = {
	dead("bank_a", "aperture", "direct", "bay_mouth_aperture:test:before"),
	{class = "scan2_tuple_complete"},
}}, nil)
check(#events == 0, "R20/R21 negative: a completing tuple disarms the edge")

-- Two different dead Banks never classify: the event names one Bank.
events = classify({edge_id = "land_099", tuples = {
	dead("bank_a", "aperture", "direct", "bay_mouth_aperture:test:before"),
	dead("bank_b", "aperture", "direct", "bay_mouth_aperture:test:after"),
}}, nil)
check(#events == 0,
	"R20/R21 negative: tuples dead with different Banks never classify")

-- An unknown probe answer is a defect, never a class.
expect_error("alternative-pair probe answered",
	"R21: an unknown probe answer re-raises", classify,
	{edge_id = "land_099", tuples = {
		dead("bank_w", "wing", "positive", "bay_wing:test:right:positive",
			"bay_wing:test:right")}},
	function() return "maybe" end)

-- ------------------------------------------------------------------
-- Face tier (contracts 9.4): synthetic not-closed and wrong-orientation
-- polygons through the classification map; the composition class through
-- the eight-connectivity predicate.  Non-simple has real witnesses (the two
-- F10 seeds) and is pinned by the worker KAT instead.
-- ------------------------------------------------------------------
local function ring(points)
	local polygon = {}
	for index = 1, #points do
		polygon[index] = {x = points[index][1], z = points[index][2]}
	end
	return polygon
end

local class, detail = partition.census_face_classify("zone_face:kat",
	ring({{0, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 0}}))
check(class == "face_simple_select" and detail == nil,
	"face: a simple CCW unit ring classifies face_simple_select")

class, detail = partition.census_face_classify("zone_face:kat",
	ring({{0, 0}, {1, 0}, {2, 0}, {3, 0}}))
check(class == "face_not_closed_reject" and
	detail:find(" is not closed", 1, true) ~= nil,
	"face: an open walk classifies face_not_closed_reject")

class, detail = partition.census_face_classify("zone_face:kat",
	ring({{0, 0}, {0, 1}, {1, 1}, {1, 0}, {0, 0}}))
check(class == "face_wrong_orientation_reject" and
	detail:find(" is not CCW", 1, true) ~= nil,
	"face: a clockwise ring classifies face_wrong_orientation_reject")

class, detail = partition.census_face_classify("zone_face:kat",
	ring({{0, 0}, {2, 0}, {2, 2}, {0, 2}, {0, 0}}))
check(class == "face_composition_reject" and
	detail:find(" is not eight-connected", 1, true) ~= nil,
	"face: a broken lattice walk classifies face_composition_reject")

-- ------------------------------------------------------------------
-- The section-11.5-C window-guarded acceptance as completed by 11.9 and
-- its negative guards (contracts 11.5-C/11.7/11.9 acceptance: a synthetic
-- non-join-local repeat, a crossing self-touch and an opposing cell
-- diagonal each fail by their own name; the accepted family -- filament
-- appendixes and pinches alike -- classifies face_appendix_select with
-- both touch-form counts).
-- ------------------------------------------------------------------
check(partition.face_appendix_window == 12,
	"appendix: the ruled W = 12 window (the 11.10 complete-distribution " ..
	"pin, lineage 8 -> 11 -> 12) is pinned in partition.lua")

-- An 8x8 CCW square whose bottom-left corner extends into a zero-width
-- two-station corridor below the region and retraces it -- the measured
-- family in miniature, W-112's dawnmere mouth included: the ring descends
-- the left edge past the corner to the join terminal (0,-2), retraces, and
-- turns east.  Stations (0,0) and (0,-1) repeat; (0,0) is the L-turn mouth
-- whose neighbours are boundary on both axes (zero-width because nothing
-- beside it is interior), (0,-1) is a straight filament station with both
-- laterals strictly outside.
local appendix_ring = ring({{0, 4}, {0, 3}, {0, 2}, {0, 1}, {0, 0},
	{0, -1}, {0, -2}, {0, -1}, {0, 0},
	{1, 0}, {2, 0}, {3, 0}, {4, 0}, {5, 0}, {6, 0}, {7, 0}, {8, 0},
	{8, 1}, {8, 2}, {8, 3}, {8, 4}, {8, 5}, {8, 6}, {8, 7}, {8, 8},
	{7, 8}, {6, 8}, {5, 8}, {4, 8}, {3, 8}, {2, 8}, {1, 8}, {0, 8},
	{0, 7}, {0, 6}, {0, 5}, {0, 4}})

class, detail = partition.census_face_classify("zone_face:kat",
	appendix_ring, {["0:-2"] = true})
check(class == "face_appendix_select" and
	detail == "appendix_stations=2 pinch_stations=0",
	"appendix: a zero-width join-local retraced corridor -- straight " ..
	"filament and L-turn mouth -- classifies face_appendix_select " ..
	"carrying both touch-form counts")

class, detail = partition.census_face_classify("zone_face:kat",
	appendix_ring, {["8:8"] = true})
check(class == "face_non_simple_reject" and
	detail:find(" has a non-join-local repeat", 1, true) ~= nil,
	"appendix guard: the same repeat outside the W = 12 window of every " ..
	"join fails by name as a non-join-local repeat")

-- The same square with the spur folded INTO the region: the repeated
-- station has strict interior beside it (its east neighbour).  Under the
-- 11.5-C ruling this failed as non-zero-width; the 11.9 completion
-- accepts it as the measured PINCH form -- the two passes share the spur
-- edge and do not interleave -- and records it in the pinch count.
class, detail = partition.census_face_classify("zone_face:kat",
	ring({{0, 0}, {1, 0}, {2, 1}, {2, 2}, {2, 1},
		{3, 0}, {4, 0}, {5, 0}, {6, 0}, {7, 0}, {8, 0},
		{8, 1}, {8, 2}, {8, 3}, {8, 4}, {8, 5}, {8, 6}, {8, 7}, {8, 8},
		{7, 8}, {6, 8}, {5, 8}, {4, 8}, {3, 8}, {2, 8}, {1, 8}, {0, 8},
		{0, 7}, {0, 6}, {0, 5}, {0, 4}, {0, 3}, {0, 2}, {0, 1}, {0, 0}}),
	{["2:2"] = true})
check(class == "face_appendix_select" and
	detail == "appendix_stations=0 pinch_stations=1",
	"appendix: a join-local non-crossing self-touch beside strict " ..
	"interior classifies face_appendix_select as a pinch (contracts 11.9)")

-- A crossing self-touch: at (0,0) loop alpha's edge-ends (out N, in S)
-- interleave loop beta's (out E, in W) in the cyclic edge order -- the
-- configuration that cannot close in the plane without a further
-- self-intersection (here the second repeat at (1,0), which the
-- validator never reaches: the crossing fails first, by name, even
-- join-local).  A pass-transversal touch whose loops occupy disjoint
-- sectors -- the measured family-C dip -- is NOT this and stays
-- accepted; the pinch positive above pins that side.
class, detail = partition.census_face_classify("zone_face:kat",
	ring({{-1, 0}, {0, 0}, {0, 1}, {1, 1}, {1, 0}, {1, -1}, {0, -1},
		{0, 0}, {1, 0}, {2, 0}, {2, -1}, {1, -2}, {0, -2}, {-1, -1},
		{-1, 0}}),
	{["1:-1"] = true})
check(class == "face_non_simple_reject" and
	detail:find(" has a crossing repeat at 0:0", 1, true) ~= nil,
	"appendix guard: a loop-interleaving crossing self-touch fails by " ..
	"name (contracts 11.9)")

-- An opposing cell diagonal stays an abort in either tier, by name.
class, detail = partition.census_face_classify("zone_face:kat",
	ring({{0, 0}, {1, 1}, {1, 0}, {0, 1}, {0, 0}}))
check(class == "face_non_simple_reject" and
	detail:find(" has an opposing cell diagonal", 1, true) ~= nil,
	"appendix guard: an opposing cell diagonal fails by name")

-- A station visited three times is outside the measured family and stays
-- loud, even join-local and zero-width.
class, detail = partition.census_face_classify("zone_face:kat",
	ring({{0, 4}, {0, 3}, {0, 2}, {0, 1}, {0, 0},
		{0, -1}, {0, -2}, {0, -1}, {0, -2}, {0, -1}, {0, 0},
		{1, 0}, {2, 0}, {3, 0}, {4, 0}, {5, 0}, {6, 0}, {7, 0}, {8, 0},
		{8, 1}, {8, 2}, {8, 3}, {8, 4}, {8, 5}, {8, 6}, {8, 7}, {8, 8},
		{7, 8}, {6, 8}, {5, 8}, {4, 8}, {3, 8}, {2, 8}, {1, 8}, {0, 8},
		{0, 7}, {0, 6}, {0, 5}, {0, 4}}),
	{["0:-2"] = true})
check(class == "face_non_simple_reject" and
	detail:find(" appendix station repeated more than twice", 1, true) ~= nil,
	"appendix guard: a station repeated more than twice fails by name")

-- The winding row derivation (contracts 11.5-C): an appendix-accepted face
-- retains its filament columns as boundary runs -- no orphan columns --
-- while the same ring without the acceptance flag keeps the loud
-- repeated-column failure.
local face_row_runs = partition.census_whole_face_row_runs
local appendix_rows = face_row_runs({{id = "zone_face:kat",
	zone_id = "zone_kat", polygon = appendix_ring, appendix_stations = 2}})
local filament = appendix_rows[-1]
check(filament and #filament == 1 and filament[1].first == 0 and
	filament[1].finish == 0 and appendix_rows[-2] and
	#appendix_rows[-2] == 1 and appendix_rows[-2][1].first == 0,
	"appendix: the winding row derivation retains the zero-width filament " ..
	"columns as face region rows")
expect_error(" repeats a row boundary column",
	"appendix: the same ring without the acceptance flag keeps the loud " ..
	"repeated-column failure", face_row_runs,
	{{id = "zone_face:kat", zone_id = "zone_kat", polygon = appendix_ring}})

-- ------------------------------------------------------------------
-- Residue adoption (contracts 11.7-B): the ownership-layer rule the census
-- Whole tier and the production Whole gate share, driven directly.
-- ------------------------------------------------------------------
local adopt = partition.census_whole_adopt_residue
local classify_whole = partition.census_whole_classify

-- An unowned dry column cardinally touching exactly one face is adopted
-- into that face's region, and the footprint proof then holds.
local prepared = {
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {{first = 0, finish = 4, id = "zone_face:a",
		zone_id = "zone_a"}}},
	water_rows = {[0] = {{first = 6, finish = 10, owner = "bay_a"}}},
	declared = {}}
local adoption = adopt(prepared)
check(#adoption.adopted == 1 and #adoption.rejected == 0 and
	adoption.adopted[1].face_id == "zone_face:a" and
	adoption.adopted[1].columns == 1,
	"adoption: a single-face-attached chain is adopted into that face")
local totals = classify_whole(prepared)
check(totals.g == 0 and totals.o == 0 and totals.r == 0 and
	totals.dry == 6 and totals.planned_water == 5,
	"adoption: the adopted chain satisfies the footprint proof as face " ..
	"region membership")

-- A chain touching two faces is returned rejected -- the loud
-- residual_multi_face_reject family -- and stays uncovered for the proof.
prepared = {
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {
		{first = 0, finish = 4, id = "zone_face:a", zone_id = "zone_a"},
		{first = 6, finish = 10, id = "zone_face:b", zone_id = "zone_b"}}},
	water_rows = {}, declared = {}}
adoption = adopt(prepared)
check(#adoption.adopted == 0 and #adoption.rejected == 1 and
	#adoption.rejected[1].face_ids == 2 and
	adoption.rejected[1].face_ids[1] == "zone_face:a" and
	adoption.rejected[1].face_ids[2] == "zone_face:b" and
	adoption.rejected[1].witness == "z=0:x=5..5",
	"adoption: a chain touching two faces is rejected " ..
	"(residual_multi_face_reject), never absorbed")
totals = classify_whole(prepared)
check(totals.g == 1,
	"adoption: the rejected chain stays uncovered and the proof keeps " ..
	"rejecting it")

-- A multi-row 4-connected chain adopts as one chain through its single
-- attached face.
prepared = {
	footprint_rows = {[0] = {{first = 0, finish = 10}},
		[1] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {{first = 0, finish = 4, id = "zone_face:a",
			zone_id = "zone_a"}},
		[1] = {{first = 0, finish = 3, id = "zone_face:a",
			zone_id = "zone_a"}}},
	water_rows = {[0] = {{first = 6, finish = 10, owner = "bay_a"}},
		[1] = {{first = 7, finish = 10, owner = "bay_a"}}},
	declared = {}}
adoption = adopt(prepared)
check(#adoption.adopted == 1 and adoption.adopted[1].columns == 4 and
	#adoption.adopted[1].members == 2,
	"adoption: a multi-row 4-connected chain adopts as one chain")
totals = classify_whole(prepared)
check(totals.g == 0,
	"adoption: the multi-row adoption satisfies the footprint proof")

-- A chain touching no face cardinally is the closing's business: left
-- unowned here, and the proof rejects it loudly.
prepared = {
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {},
	water_rows = {[0] = {{first = 0, finish = 4, owner = "bay_a"}}},
	declared = {}}
adoption = adopt(prepared)
totals = classify_whole(prepared)
check(#adoption.adopted == 0 and #adoption.rejected == 0 and totals.g == 6,
	"adoption: an unattached chain is left to the closing and the proof " ..
	"keeps rejecting it")

-- ------------------------------------------------------------------
-- Ring adoption (contracts 11.9, family A): a chain column that is a
-- footprint-ring station adopts along the ring's own connectivity into
-- the face owning its ring-neighbour station -- the measured pinched
-- fragment shape: no cardinal face contact, water beside it, one
-- diagonal ring step to owned mainland.
-- ------------------------------------------------------------------
prepared = {
	footprint_rows = {[0] = {{first = 0, finish = 10}},
		[1] = {{first = 0, finish = 10}}},
	face_rows = {[1] = {{first = 0, finish = 4, id = "zone_face:a",
		zone_id = "zone_a"}}},
	water_rows = {[0] = {{first = 0, finish = 4, owner = "bay_a"},
			{first = 6, finish = 10, owner = "bay_a"}},
		[1] = {{first = 5, finish = 10, owner = "bay_a"}}},
	declared = {},
	ring_links = {["5:0"] = {{x = 4, z = 1}, {x = 6, z = 0}}}}
adoption = adopt(prepared)
check(#adoption.adopted == 1 and #adoption.rejected == 0 and
	adoption.adopted[1].face_id == "zone_face:a" and
	adoption.adopted[1].columns == 1 and
	adoption.adopted[1].via == "ring" and
	adoption.adopted[1].ring_stations == 1,
	"ring adoption: a pinched ring-station chain adopts along the ring's " ..
	"own connectivity into the ring-neighbour's face")
totals = classify_whole(prepared)
check(totals.g == 0,
	"ring adoption: the ring-adopted chain satisfies the footprint proof")

-- A ring chain whose ring neighbours own nothing stays unowned and MUST
-- surface as a gap, never silence -- the Whole gate is the loud backstop.
prepared = {
	footprint_rows = {[0] = {{first = 0, finish = 10}},
		[1] = {{first = 0, finish = 10}}},
	face_rows = {[1] = {{first = 0, finish = 4, id = "zone_face:a",
		zone_id = "zone_a"}}},
	water_rows = {[0] = {{first = 0, finish = 4, owner = "bay_a"},
			{first = 6, finish = 10, owner = "bay_a"}},
		[1] = {{first = 5, finish = 10, owner = "bay_a"}}},
	declared = {},
	ring_links = {["5:0"] = {{x = 6, z = -1}, {x = 6, z = 0}}}}
adoption = adopt(prepared)
totals = classify_whole(prepared)
check(#adoption.adopted == 0 and #adoption.rejected == 0 and
	totals.g == 1 and totals.classes.whole_gap_reject and
	totals.classes.whole_gap_reject.witness == "z=0:x=5..5",
	"ring adoption guard: an unowned ring chain surfaces as " ..
	"whole_gap_reject, not silence")

-- ------------------------------------------------------------------
-- Whole tier (contracts 9.4): synthetic gap, undeclared-multiplicity and
-- declared-seam interval sets through the row-run classifier.
-- ------------------------------------------------------------------
local whole = partition.census_whole_classify

-- One footprint row 0..10, one face covering it all: single owner.
local totals = whole({
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {{first = 0, finish = 10, id = "zone_face:a",
		zone_id = "zone_a"}}},
	water_rows = {}, declared = {}})
check(totals.g == 0 and totals.o == 0 and totals.r == 0 and totals.m == 0 and
	totals.columns == 11 and totals.dry == 11 and
	totals.classes.whole_single_owner_select and
	totals.classes.whole_single_owner_select.columns == 11,
	"whole: a fully covered footprint row is whole_single_owner_select " ..
	"with g=o=r=m=0")

-- A face covering only 0..4 leaves 5..10 a gap.
totals = whole({
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {{first = 0, finish = 4, id = "zone_face:a",
		zone_id = "zone_a"}}},
	water_rows = {}, declared = {}})
check(totals.g == 6 and totals.classes.whole_gap_reject and
	totals.classes.whole_gap_reject.columns == 6 and
	totals.classes.whole_gap_reject.witness == "z=0:x=5..10",
	"whole: an uncovered dry interval is whole_gap_reject and counts g")

-- Two faces sharing column 5 with the seam declared: whole_declared_seam_select.
totals = whole({
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {
		{first = 0, finish = 5, id = "zone_face:a", zone_id = "zone_a"},
		{first = 5, finish = 10, id = "zone_face:b", zone_id = "zone_b"}}},
	water_rows = {},
	declared = {["5:0"] = {zone_a = true, zone_b = true}}})
check(totals.r == 0 and totals.classes.whole_declared_seam_select and
	totals.classes.whole_declared_seam_select.columns == 1 and
	totals.classes.whole_single_owner_select.columns == 10,
	"whole: a declared two-zone seam column is whole_declared_seam_select")

-- The same overlap without the declaration: undeclared multiplicity, r counts.
totals = whole({
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {
		{first = 0, finish = 5, id = "zone_face:a", zone_id = "zone_a"},
		{first = 5, finish = 10, id = "zone_face:b", zone_id = "zone_b"}}},
	water_rows = {}, declared = {}})
check(totals.r == 1 and
	totals.classes.whole_undeclared_multiplicity_reject and
	totals.classes.whole_undeclared_multiplicity_reject.columns == 1,
	"whole: an undeclared two-face column is " ..
	"whole_undeclared_multiplicity_reject and counts r")

-- Seam inheritance (contracts 11.9, family C): a column claimed by
-- exactly two faces, BOTH as boundary stations (class 0), cardinally
-- adjacent to a declared-seam column of the identical pair, inherits
-- the declaration and classifies whole_declared_seam_select.
totals = whole({
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {
		{first = 0, finish = 4, id = "zone_face:a", zone_id = "zone_a",
			class = 1},
		{first = 5, finish = 5, id = "zone_face:a", zone_id = "zone_a",
			class = 0},
		{first = 5, finish = 5, id = "zone_face:b", zone_id = "zone_b",
			class = 0},
		{first = 6, finish = 10, id = "zone_face:b", zone_id = "zone_b",
			class = 1}}},
	water_rows = {},
	declared = {["5:1"] = {zone_a = true, zone_b = true}}})
check(totals.r == 0 and totals.classes.whole_declared_seam_select and
	totals.classes.whole_declared_seam_select.columns == 1 and
	totals.classes.whole_single_owner_select.columns == 10,
	"whole: a boundary-boundary two-face column beside a same-pair " ..
	"declared seam inherits the declaration (contracts 11.9)")

-- A two-INTERIOR-claimants column must stay the loud multiplicity
-- reject even beside a same-pair declaration: inheritance is for
-- boundary-boundary claims only.
totals = whole({
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {
		{first = 0, finish = 5, id = "zone_face:a", zone_id = "zone_a",
			class = 1},
		{first = 5, finish = 10, id = "zone_face:b", zone_id = "zone_b",
			class = 1}}},
	water_rows = {},
	declared = {["5:1"] = {zone_a = true, zone_b = true}}})
check(totals.r == 1 and
	totals.classes.whole_undeclared_multiplicity_reject and
	totals.classes.whole_undeclared_multiplicity_reject.columns == 1,
	"whole guard: a two-interior-claimants column stays " ..
	"whole_undeclared_multiplicity_reject (contracts 11.9)")

-- A declared seam whose column holds only one of the declared owners is
-- still undeclared multiplicity: the declared set must match exactly.
totals = whole({
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {
		{first = 0, finish = 5, id = "zone_face:a", zone_id = "zone_a"},
		{first = 5, finish = 10, id = "zone_face:b", zone_id = "zone_b"}}},
	water_rows = {},
	declared = {["5:0"] = {zone_a = true, zone_b = true, zone_c = true}}})
check(totals.r == 1 and totals.classes.whole_undeclared_multiplicity_reject,
	"whole: a seam column missing a declared owner stays undeclared " ..
	"multiplicity")

-- Water: a single owner is a select, two owners are an overlap and count o.
totals = whole({
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {},
	water_rows = {[0] = {
		{first = 0, finish = 10, owner = "bay_a"},
		{first = 8, finish = 10, owner = "bay_b"}}},
	declared = {}})
check(totals.o == 3 and totals.planned_water == 11 and
	totals.classes.whole_undeclared_multiplicity_reject.columns == 3 and
	totals.classes.whole_single_owner_select.columns == 8,
	"whole: overlapping Bay water is whole_undeclared_multiplicity_reject " ..
	"and counts o")

-- The m cross-check: an interval whose check disagrees counts its length.
totals = whole({
	footprint_rows = {[0] = {{first = 0, finish = 10}}},
	face_rows = {[0] = {{first = 0, finish = 10, id = "zone_face:a",
		zone_id = "zone_a"}}},
	water_rows = {}, declared = {},
	check = function(z, x) return x ~= 0 end})
check(totals.m == 11,
	"whole: a failing representation cross-check counts the interval into m")

hasher.close()
print(("census scan3b/4 classifier KAT passed: %d checks"):format(checks))
