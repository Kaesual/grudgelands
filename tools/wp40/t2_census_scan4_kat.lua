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
