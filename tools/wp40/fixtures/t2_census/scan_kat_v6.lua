-- WP40 T2 census scan KAT fixture (contracts section 9.4, the Scan-3b/4
-- census package of 2026-08-19).  v6 supersedes scan_kat_v5.lua, which is
-- retired with this file: the schema string moved to
-- `grug_wp40_census_scan_v6`, the roster grew from five seeds to seven, and
-- every record now carries the Scan-3b bank/step/selection/attribution tiers
-- and the Scan-4 membership/face/whole/fragment tiers on top of the M1+M3+M4
-- +M5 rows v5 already pinned.  Every v5 pin below was re-measured over the
-- seven-seed record on 2026-08-19 and re-derived from that record rather than
-- copied forward, so the four seeds v5 shared with v6 are a cross-check and
-- not an inheritance -- they all agreed.
--
-- The two new seeds are the contracts 9.4 F10 face-simplicity witnesses,
-- 2147483648 and 1959553668008863006, inserted in their sorted places in the
-- roster (sixth and seventh by value, second and fourth in ascending
-- canonical decimal).  Every per-seed table in this file is written in that
-- roster order -- the order `W` itself uses and the order the worker emits --
-- so a table here reads directly against the measured TSV block.
--
-- Membership (contracts 9.2, ruled branch A): the worker consumes the
-- authority's `read_scan4_membership`, which enforces the pinned seed-set and
-- manifest digests, and every record carries one `scan4_membership` row.  All
-- seven roster seeds are members with source `seed_set`; none of them is one
-- of the three detached-shoulder admission newcomers, so the KAT pins the
-- branch-A consumption path without pinning the admission arm -- that arm is
-- the gate suite's negative, not this fixture's.
--
-- **The W-112 F10 deviation — MOVED by the section-11 bay-transition
-- package, 2026-08-20 (the recorded correction the previous header
-- promised).**  Until that package, W-112 realized `face_non_simple_reject`
-- at BOTH `zone_face:elandor_dawnmere_fields` and
-- `zone_face:elandor_silverleaf_glades`, its whole tier blocked and its
-- fragment row classified `fragment_not_evaluated` (measured 2026-08-19,
-- census and compiler agreeing).  The contracts-11.5-C window-guarded
-- appendix acceptance, ruled 2026-08-20, accepts exactly the measured
-- corridor family: W-112 now classifies `face_appendix_select` at both
-- faces (dawnmere 4 appendix stations -- including the L-turn corridor
-- mouth at -634:-2918 that fixed the zero-width predicate's
-- operationalization as "no cardinal neighbour strictly interior" --
-- silverleaf 2), its whole tier EVALUATES g=o=r=m=0 through the winding
-- row derivation, and its fragment row classifies
-- `fragment_owned_once_select`.  Every moved pin below was re-measured
-- from the 2026-08-20 seven-seed record, not projected; the four seeds
-- without appendix faces reproduced their previous pins byte-identically
-- in the same run (the fast path untouched, closing and adoption measured
-- no-ops on clean geometry).
--
-- **Re-pinned by the section-11.9 completion, 2026-08-20 (a recorded
-- correction, named in its commit).**  The acceptance predicate is now
-- the join-local, LOCALLY NON-CROSSING self-touch with the ruled window
-- W (11 at this re-pin; W := 12 since the section-11.10
-- complete-distribution re-ruling of 2026-08-21, which moved no pin in
-- this roster -- provenance in t2_census_authority.lua), and
-- every `face_appendix_select` detail carries both touch-form counts --
-- `appendix_stations=A pinch_stations=P`.  All roster repeats are
-- zero-width filaments, so every appendix count below kept its value and
-- gained `pinch_stations = 0`; the record digest moved with the detail
-- bytes, and the four seeds without appendix faces again reproduced
-- their pins byte-identically (the ring-adoption and seam-inheritance
-- completions are measured no-ops on the roster).
--
-- Fill counts are the known F6 witness occupancies from
-- wp40-t2-degeneracy-completeness.md section 3-F6, in source.bays order
-- (bay_elandor_west, bay_elandor_east, bay_kragmar_west, bay_kragmar_east).
-- The scan2 blocks pin the M3 counting tier and R19 joint decision -- notably
-- the Slot-29 witness (analysis section 3-F2): land_010:to carries two direct
-- R16 candidates, the endpoint's own tuple dies bank-incomplete (the
-- R19-genesis dead direct terminal) and the retreat tuple completes, leaving
-- exactly one complete tuple.  At max-u64 the same endpoint resolves via the
-- diagonal elbow, matching the pinned R16/R17 prerequisite fixture's
-- 7-direct/1-elbow split.  The two new seeds add two more multi-complete
-- edges to the corpus (2147483648's land_007 and 1959553668008863006's
-- land_010, the latter selecting its *second* tuple), so the D1 selection
-- rule is now pinned at three independent seeds instead of one.
-- The scan3 blocks pin the M4 Scan-3a projections.
-- M5 added Slot 30 for the analysis section 3-F8 fragment-bearing case; the
-- stage-reject package added W-112, the first measured 3-F9 aperture
-- occupancy, as a seed that then still emitted a stage_reject record.
-- The digest moved with each addition, legitimately.  The digest pins the
-- complete canonical worker TSV over the seven roster seeds in ascending
-- canonical decimal order and is the determinism gate: any interpreter- or
-- order-dependent drift in the census projection changes it.
-- `merge_artifacts_digest` is the gate's pinned half over the section-6.2
-- artifacts the merge builds from exactly these records.
local function endpoint(eligible, success, direct, elbow)
	return {eligible = eligible, success = success, direct = direct,
		elbow = elbow}
end
local function edge(class, tuples, complete)
	return {class = class, tuples = tuples, complete = complete}
end
local select_one = "scan2_exactly_one_complete_select"
-- One Scan-3b bank row: the identity plus the five trace scalars contracts
-- 9.4 asks the KAT to hold.  `multi_reachable_step_count` is deliberately not
-- among them and is carried by the record digest instead: it equals
-- `branch_step_count` in 111 of the 112 measured bank rows, the exception
-- being 1959553668008863006's Kragmar-west stillgrave Bank (2 branching steps,
-- 1 of them multi-reachable).  That single divergence is the only evidence in
-- the roster that the two scalars are distinct measurements rather than one
-- measurement written twice, and it is stated here so a later reader does not
-- re-derive the false identity from the other 111 rows.
local function bank(id, steps, stations, frames, stack, branch)
	return {id = id, steps = steps, stations = stations, frames = frames,
		stack = stack, branch = branch}
end
-- One Scan-3b attribution row: which bank's death a `land_XXX` endpoint's
-- incomplete tuples are charged to, and how many of them (first-fail, so the
-- count is a lower bound conditioned on evaluation order).
local function attributed(edge_id, endpoint_side, bank_id, far_kind, far_mode,
		count)
	return {edge = edge_id, endpoint = endpoint_side, bank = bank_id,
		far_kind = far_kind, far_mode = far_mode, count = count}
end
-- The retained R15 Stage-1 Wing tail-pair corpus of
-- wp40-source-authority.md section 6.1, restated here in source Wing order
-- as five independent per-Wing quantities.  It is a *comparison* target, not
-- an input: M4 measured every row from the census projection at all three
-- KAT seeds and they agreed, which is what makes the corpus an acceptance
-- oracle for the Scan-3a Wing analysis rather than a number copied forward.
-- The `structural` and `rank` columns also carry the analysis section 3-F5
-- Slot-29 witness (Kragmar-west-left: 2 structural pairs, 1 wedge-valid at
-- rank 2), which turns out to hold at all seven seeds and not only at
-- Slot 29.
local function wing(id, raw, structural, wedge_valid, rank, radius,
		negative_length, positive_length)
	return {id = id, raw = raw, structural = structural,
		wedge_valid = wedge_valid, rank = rank, radius = radius,
		negative_length = negative_length, positive_length = positive_length}
end
return {
	schema = "grug_wp40_census_scan_v6",
	-- The load-bearing M3 witness: this endpoint must hold at least two R16
	-- candidates while its edge completes exactly one joint tuple.  The
	-- worker's --kat roster must cover this seed.
	r19_witness = {seed = "16178445837170081103",
		endpoint = "bay_edge_transition:land_010:to", edge = "land_010"},
	-- The load-bearing M4 witness: the first ever aperture tail-mode
	-- occurrence (analysis section 3-F4 residual), measured at Slot 29 on the
	-- Elandor-east `before` incidence.  Its emitted tail must keep W on the
	-- declared strict water side, which is the F4 table row that lives in
	-- trace_bank rather than in the resolution seam.
	tail_mode_witness = {seed = "16178445837170081103",
		aperture = "bay_mouth_aperture:elandor_east", side = "before"},
	-- The load-bearing M5 witness, measured 2026-08-16 and reproducing the
	-- analysis section 3-F8 residual exactly as written: Slot 30's `land_007`
	-- carries two maximal dry intervals of which one is a singleton, exactly
	-- one qualifies for both obligations, and the nonselected interval is the
	-- excluded dry fragment.  The same row is the section 3-F1 "singleton
	-- interval" witness -- "it is E for both obligations and does not qualify"
	-- -- so both derived branches an edge row can witness are witnessed here.
	-- v6 closes the loop the M5 measurement opened: that excluded interval is
	-- exactly the `scan4_fragment` row this seed now emits, and it classifies
	-- `fragment_owned_once_select` (see `scan4` below).
	fragment_witness = {seed = "15219119262482319357", edge = "land_007",
		attachment = "perimeter_attachment:elandor:land_007", intervals = 2,
		singletons = 1, qualifying = 1, class = "transition_interval_select"},
	-- The D2 detached-shoulder witness (contracts 8.2): W-112, the seed the
	-- run-3 shards died on, now compiles -- the admitted station is the
	-- authored-order after-side detached shoulder of Elandor-east, world
	-- point 1227:-2928, exactly the shape the gate-1 diagnostic measured at
	-- all seven occupied seeds.  The worker asserts the admission fired
	-- here and nowhere else, so a construction drift that silently widens
	-- or loses the admission is legible by name, not only by digest.
	detached_shoulder_witness = {seed = "343674299183575008",
		aperture = "bay_mouth_aperture:elandor_east", side = "after",
		station = "1227:-2928"},
	-- The D1 multi-complete selection witness (contracts 8.2): W-112's
	-- land_004 enumerates four tuples of which two complete, at retreat 0
	-- and 4, and the declared order selects the zero-retreat tuple -- the
	-- R18-continuous outcome the plan-7.1 measurements found at 730 of the
	-- 757 multi-complete records over `W`.
	multi_complete_witness = {seed = "343674299183575008",
		edge = "land_004", tuples = 4, complete = 2, selected_tuple = 1,
		selected_station_count = 1599},
	-- The contracts 9.4 F10 witnesses, and the reason the roster grew to
	-- seven.  Re-pinned 2026-08-20 by the section-11 package (a recorded
	-- correction, named in its commit): these two seeds are now the measured
	-- occupancy of the contracts-11.5-C `face_appendix_select` acceptance --
	-- the only real-witness coverage the window-guarded appendix arm has.
	-- A quietly-simple result here is a silent loss of that coverage, and
	-- the consequent must travel with it: each seed must accept the named
	-- face with exactly the pinned appendix station count AND evaluate its
	-- whole tier through the winding region truth.  Re-pinned again by the
	-- 11.9 completion (a recorded correction, named in its commit): the
	-- detail now carries both touch-form counts, and both witnesses'
	-- repeats are zero-width filaments -- pinch count 0.
	f10_witnesses = {
		{seed = "2147483648",
			face = "zone_face:elandor_silverleaf_glades",
			class = "face_appendix_select", appendix_stations = 1,
			pinch_stations = 0},
		{seed = "1959553668008863006",
			face = "zone_face:kragmar_stillgrave_hollow",
			class = "face_appendix_select", appendix_stations = 1,
			pinch_stations = 0},
	},
	-- The R19-genesis attribution pin (contracts 9.4).  Slot 29's land_010:to
	-- is where the R19 rule came from -- the direct terminal dies
	-- bank-incomplete and the retreat tuple carries the edge -- and this is
	-- that death seen from the Scan-3b side: exactly one tuple, charged to
	-- the Kragmar-west stillgrave bank, far terminal an aperture resolved
	-- direct.  It gets its own named field beside the per-seed `attribution`
	-- list so it can never silently vanish into a list that merely happens to
	-- stay the right length.
	attribution_witness = {seed = "16178445837170081103", edge = "land_010",
		endpoint = "to", bank = "bay_bank:kragmar_west:stillgrave",
		far_kind = "aperture", far_mode = "direct", count = 1},
	r15_corpus = {
		wing("bay_wing:elandor_west:left", 4, 4, 1, 1, 4, 4, 3),
		wing("bay_wing:elandor_west:right", 18, 18, 1, 10, 5, 4, 5),
		wing("bay_wing:elandor_east:left", 18, 18, 1, 2, 5, 5, 4),
		wing("bay_wing:elandor_east:right", 4, 4, 1, 1, 4, 3, 4),
		wing("bay_wing:kragmar_west:left", 2, 2, 1, 2, 3, 2, 3),
		wing("bay_wing:kragmar_west:right", 18, 18, 1, 17, 5, 5, 4),
		wing("bay_wing:kragmar_east:left", 18, 18, 1, 9, 5, 4, 5),
		wing("bay_wing:kragmar_east:right", 18, 18, 1, 17, 5, 5, 4),
	},
	-- Every head Bank completes at all seven seeds with no branching step at
	-- all, so the reachability DFS never runs and both trace stress scalars
	-- are zero.  The observed 453-794 step and <= 24 frame figures in the
	-- analysis came from transition-incident Banks, which are Scan-3b -- and
	-- `scan3b` below is where that reading finally becomes a pin: those Banks
	-- do branch, and they do carry frames.
	head_banks = {
		{id = "bay_bank:elandor_west:whitebridge", steps = 993, stations = 1001},
		{id = "bay_bank:elandor_east:lorindor", steps = 993, stations = 1001},
		{id = "bay_bank:kragmar_west:speargrass", steps = 994, stations = 1001},
		{id = "bay_bank:kragmar_east:whispering", steps = 992, stations = 1001},
	},
	-- Section 6.4 / source authority section 7.2.  Section 7.2's "half-widths of
	-- 320-370" describes the mouth station only; the authored centrelines taper
	-- to 80 nodes at the Bay head, against a jitter bound of 48, and the
	-- minimum always falls on the taper segment (3).
	--
	-- M4 read three seeds and concluded that the minimum sits where the
	-- 96-station taper forces `delta_nodes` to zero, so jitter could not move
	-- it.  **Slot 30 refutes that**: in Elandor-west the station minimum moves
	-- from station 301 (delta 0, 80 nodes) to station 231 with delta -30 and 75
	-- nodes, and in Kragmar-east from station 341 to station 263 with delta -26
	-- and 74 nodes.  The taper still decides which *segment* holds the minimum;
	-- it does not pin the station, and the three-seed sample was simply too
	-- small.  What that costs is only the false comfort -- the exact per-column
	-- lower bound was already the thing ruling a collapse out, because the
	-- compiler evaluates the same numerator at every column while pairing it
	-- with the nearest station's delta.  That bound reads 46 at Slot 30, still
	-- the tightest of the seven seeds v6 measures (2147483648's Kragmar-west
	-- is second at 52) and still 14 above the structural floor of 80 - 48.
	--
	-- Pinned per seed in `source.bays` order as
	-- {min_width_nodes, min_delta_nodes, column_bound_nodes}, so a drift in
	-- either the station minimum or the exact bound is legible by name and not
	-- only through the record digest.
	bank_width = {min_segment = 3, delta_bound = 48, column_bound_floor = 32,
		taper_floor_nodes = 80,
		per_seed = {
			["0"] = {{80, 0, 69}, {80, 0, 76}, {80, 0, 66}, {80, 0, 80}},
			["2147483648"] =
				{{80, 0, 80}, {80, 0, 69}, {80, 0, 52}, {80, 0, 80}},
			["343674299183575008"] =
				{{80, 0, 72}, {80, 0, 75}, {80, 0, 80}, {80, 0, 80}},
			["1959553668008863006"] =
				{{80, 0, 70}, {80, 0, 80}, {80, 0, 69}, {80, 0, 64}},
			["15219119262482319357"] =
				{{75, -30, 46}, {80, 0, 63}, {80, 0, 80}, {74, -26, 51}},
			["16178445837170081103"] =
				{{80, 0, 80}, {80, 0, 74}, {80, 0, 60}, {80, 0, 60}},
			["18446744073709551615"] =
				{{80, 0, 80}, {80, 0, 80}, {80, 0, 67}, {80, 0, 60}},
		}},
	fills = {
		["0"] = {0, 0, 0, 0},
		["2147483648"] = {1, 0, 0, 0},
		["343674299183575008"] = {0, 0, 0, 0},
		["1959553668008863006"] = {0, 0, 0, 0},
		["15219119262482319357"] = {0, 0, 0, 0},
		["16178445837170081103"] = {0, 0, 0, 0},
		["18446744073709551615"] = {1, 1, 1, 0},
	},
	-- Aperture resolution modes per seed (analysis section 3-F4): eight direct
	-- incidences everywhere except Slot 29, whose Elandor-east `before`
	-- incidence is the tail-mode witness above.  Six of the seven seeds -- the
	-- two v6 added included -- resolve all eight incidences direct, so 3-F4
	-- stays a one-seed residual over a roster that has since grown twice.
	aperture_modes = {
		["0"] = {direct = 8, diagonal_shoulder = 0},
		["2147483648"] = {direct = 8, diagonal_shoulder = 0},
		["343674299183575008"] = {direct = 8, diagonal_shoulder = 0},
		["1959553668008863006"] = {direct = 8, diagonal_shoulder = 0},
		["15219119262482319357"] = {direct = 8, diagonal_shoulder = 0},
		["16178445837170081103"] = {direct = 7, diagonal_shoulder = 1},
		["18446744073709551615"] = {direct = 8, diagonal_shoulder = 0},
	},
	scan2 = {
		["0"] = {
			endpoints = {
				["bay_edge_transition:land_001:to"] = endpoint(1503, 1, 1, 0),
				["bay_edge_transition:land_004:from"] = endpoint(1601, 1, 1, 0),
				["bay_edge_transition:land_004:to"] = endpoint(1601, 1, 1, 0),
				["bay_edge_transition:land_007:from"] = endpoint(1598, 1, 1, 0),
				["bay_edge_transition:land_010:to"] = endpoint(1603, 1, 1, 0),
				["bay_edge_transition:land_013:from"] = endpoint(1597, 1, 1, 0),
				["bay_edge_transition:land_013:to"] = endpoint(1597, 1, 1, 0),
				["bay_edge_transition:land_016:from"] = endpoint(1547, 1, 1, 0),
			},
			edges = {
				land_001 = edge(select_one, 1, 1),
				land_004 = edge(select_one, 1, 1),
				land_007 = edge(select_one, 1, 1),
				land_010 = edge(select_one, 1, 1),
				land_013 = edge(select_one, 1, 1),
				land_016 = edge(select_one, 1, 1),
			},
		},
		["2147483648"] = {
			endpoints = {
				["bay_edge_transition:land_001:to"] = endpoint(1505, 1, 1, 0),
				["bay_edge_transition:land_004:from"] = endpoint(1594, 1, 1, 0),
				["bay_edge_transition:land_004:to"] = endpoint(1594, 1, 1, 0),
				["bay_edge_transition:land_007:from"] = endpoint(1585, 2, 2, 0),
				["bay_edge_transition:land_010:to"] = endpoint(1613, 1, 1, 0),
				["bay_edge_transition:land_013:from"] = endpoint(1600, 1, 1, 0),
				["bay_edge_transition:land_013:to"] = endpoint(1600, 1, 1, 0),
				["bay_edge_transition:land_016:from"] = endpoint(1546, 1, 0, 1),
			},
			edges = {
				land_001 = edge(select_one, 1, 1),
				land_004 = edge(select_one, 1, 1),
				land_007 = edge("scan2_multi_complete_select", 2, 2),
				land_010 = edge(select_one, 1, 1),
				land_013 = edge(select_one, 1, 1),
				land_016 = edge(select_one, 1, 1),
			},
		},
		["343674299183575008"] = {
			endpoints = {
				["bay_edge_transition:land_001:to"] = endpoint(1502, 1, 1, 0),
				["bay_edge_transition:land_004:from"] = endpoint(1598, 4, 4, 0),
				["bay_edge_transition:land_004:to"] = endpoint(1598, 1, 1, 0),
				["bay_edge_transition:land_007:from"] = endpoint(1598, 1, 1, 0),
				["bay_edge_transition:land_010:to"] = endpoint(1577, 1, 1, 0),
				["bay_edge_transition:land_013:from"] = endpoint(1586, 1, 1, 0),
				["bay_edge_transition:land_013:to"] = endpoint(1586, 2, 2, 0),
				["bay_edge_transition:land_016:from"] = endpoint(1548, 1, 1, 0),
			},
			edges = {
				land_001 = edge(select_one, 1, 1),
				land_004 = edge("scan2_multi_complete_select", 4, 2),
				land_007 = edge(select_one, 1, 1),
				land_010 = edge(select_one, 1, 1),
				land_013 = edge(select_one, 2, 1),
				land_016 = edge(select_one, 1, 1),
			},
		},
		["1959553668008863006"] = {
			endpoints = {
				["bay_edge_transition:land_001:to"] = endpoint(1505, 1, 1, 0),
				["bay_edge_transition:land_004:from"] = endpoint(1592, 1, 1, 0),
				["bay_edge_transition:land_004:to"] = endpoint(1592, 1, 1, 0),
				["bay_edge_transition:land_007:from"] = endpoint(1592, 1, 1, 0),
				["bay_edge_transition:land_010:to"] = endpoint(1581, 2, 1, 1),
				["bay_edge_transition:land_013:from"] = endpoint(1617, 1, 1, 0),
				["bay_edge_transition:land_013:to"] = endpoint(1617, 1, 1, 0),
				["bay_edge_transition:land_016:from"] = endpoint(1548, 1, 1, 0),
			},
			edges = {
				land_001 = edge(select_one, 1, 1),
				land_004 = edge(select_one, 1, 1),
				land_007 = edge(select_one, 1, 1),
				land_010 = edge("scan2_multi_complete_select", 2, 2),
				land_013 = edge(select_one, 1, 1),
				land_016 = edge(select_one, 1, 1),
			},
		},
		["15219119262482319357"] = {
			endpoints = {
				["bay_edge_transition:land_001:to"] = endpoint(1505, 1, 1, 0),
				["bay_edge_transition:land_004:from"] = endpoint(1599, 1, 1, 0),
				["bay_edge_transition:land_004:to"] = endpoint(1599, 1, 1, 0),
				["bay_edge_transition:land_007:from"] = endpoint(1576, 1, 1, 0),
				["bay_edge_transition:land_010:to"] = endpoint(1581, 1, 1, 0),
				["bay_edge_transition:land_013:from"] = endpoint(1640, 1, 1, 0),
				["bay_edge_transition:land_013:to"] = endpoint(1640, 1, 1, 0),
				["bay_edge_transition:land_016:from"] = endpoint(1551, 1, 1, 0),
			},
			edges = {
				land_001 = edge(select_one, 1, 1),
				land_004 = edge(select_one, 1, 1),
				land_007 = edge(select_one, 1, 1),
				land_010 = edge(select_one, 1, 1),
				land_013 = edge(select_one, 1, 1),
				land_016 = edge(select_one, 1, 1),
			},
		},
		["16178445837170081103"] = {
			endpoints = {
				["bay_edge_transition:land_001:to"] = endpoint(1505, 1, 1, 0),
				["bay_edge_transition:land_004:from"] = endpoint(1600, 1, 1, 0),
				["bay_edge_transition:land_004:to"] = endpoint(1600, 1, 1, 0),
				["bay_edge_transition:land_007:from"] = endpoint(1608, 1, 1, 0),
				["bay_edge_transition:land_010:to"] = endpoint(1601, 2, 2, 0),
				["bay_edge_transition:land_013:from"] = endpoint(1626, 1, 1, 0),
				["bay_edge_transition:land_013:to"] = endpoint(1626, 1, 1, 0),
				["bay_edge_transition:land_016:from"] = endpoint(1546, 1, 1, 0),
			},
			edges = {
				land_001 = edge(select_one, 1, 1),
				land_004 = edge(select_one, 1, 1),
				land_007 = edge(select_one, 1, 1),
				land_010 = edge(select_one, 2, 1),
				land_013 = edge(select_one, 1, 1),
				land_016 = edge(select_one, 1, 1),
			},
		},
		["18446744073709551615"] = {
			endpoints = {
				["bay_edge_transition:land_001:to"] = endpoint(1503, 1, 1, 0),
				["bay_edge_transition:land_004:from"] = endpoint(1592, 1, 1, 0),
				["bay_edge_transition:land_004:to"] = endpoint(1592, 1, 1, 0),
				["bay_edge_transition:land_007:from"] = endpoint(1587, 1, 1, 0),
				["bay_edge_transition:land_010:to"] = endpoint(1598, 1, 0, 1),
				["bay_edge_transition:land_013:from"] = endpoint(1641, 1, 1, 0),
				["bay_edge_transition:land_013:to"] = endpoint(1641, 1, 1, 0),
				["bay_edge_transition:land_016:from"] = endpoint(1549, 1, 1, 0),
			},
			edges = {
				land_001 = edge(select_one, 1, 1),
				land_004 = edge(select_one, 1, 1),
				land_007 = edge(select_one, 1, 1),
				land_010 = edge(select_one, 1, 1),
				land_013 = edge(select_one, 1, 1),
				land_016 = edge(select_one, 1, 1),
			},
		},
	},
	-- Scan-4 membership (contracts 9.2, branch A).  `member` is the emitted
	-- token, `source` the emitted provenance: every roster seed is in the
	-- pinned seed-set fixture, so none of them exercises the `admission` or
	-- `forced` arms here.  Pinning the token rather than a boolean means the
	-- fixture states what the record says, not what the worker believed.
	membership = {
		["0"] = {member = "member", source = "seed_set"},
		["2147483648"] = {member = "member", source = "seed_set"},
		["343674299183575008"] = {member = "member", source = "seed_set"},
		["1959553668008863006"] = {member = "member", source = "seed_set"},
		["15219119262482319357"] = {member = "member", source = "seed_set"},
		["16178445837170081103"] = {member = "member", source = "seed_set"},
		["18446744073709551615"] = {member = "member", source = "seed_set"},
	},
	-- Scan-3b (contracts 9.1/9.4): the 16 transition-incident Banks, in
	-- emission order, with the five trace scalars per Bank.  Every one of the
	-- 112 rows classifies `bank_trace_complete_select` -- there is no
	-- `scan3b_bank_not_evaluated` occupancy anywhere in the roster, which is
	-- the measurement behind the "expected vacuous" note in 9.1, now held at
	-- seven seeds instead of asserted.  Unlike the head Banks these do branch
	-- (0 to 18 branching steps; eight of the 112 rows still reach zero) and do
	-- carry frames, so the trace stress the analysis measured lives here.
	scan3b = {
		["0"] = {
			bank("bay_bank:elandor_west:hearthpine", 727, 728, 638, 638, 16),
			bank("bay_bank:elandor_west:copperfell", 506, 509, 414, 414, 2),
			bank("bay_bank:elandor_west:goldmead", 673, 677, 181, 181, 1),
			bank("bay_bank:elandor_west:dawnmere", 718, 719, 701, 701, 8),
			bank("bay_bank:elandor_east:dawnmere", 705, 706, 520, 520, 4),
			bank("bay_bank:elandor_east:goldmead", 678, 682, 0, 0, 0),
			bank("bay_bank:elandor_east:starbough", 501, 504, 203, 203, 7),
			bank("bay_bank:elandor_east:silverleaf", 712, 713, 699, 699, 5),
			bank("bay_bank:kragmar_west:stillgrave", 775, 776, 754, 754, 4),
			bank("bay_bank:kragmar_west:mournfen", 452, 454, 188, 188, 4),
			bank("bay_bank:kragmar_west:redtusk", 722, 726, 570, 570, 2),
			bank("bay_bank:kragmar_west:sunscar", 739, 740, 585, 585, 8),
			bank("bay_bank:kragmar_east:sunscar", 812, 813, 597, 597, 9),
			bank("bay_bank:kragmar_east:redtusk", 629, 633, 204, 204, 5),
			bank("bay_bank:kragmar_east:raincall", 571, 575, 554, 554, 3),
			bank("bay_bank:kragmar_east:kapok", 714, 715, 592, 592, 3),
		},
		["2147483648"] = {
			bank("bay_bank:elandor_west:hearthpine", 737, 738, 648, 648, 16),
			bank("bay_bank:elandor_west:copperfell", 503, 506, 479, 479, 6),
			bank("bay_bank:elandor_west:goldmead", 676, 680, 187, 187, 6),
			bank("bay_bank:elandor_west:dawnmere", 710, 711, 616, 616, 6),
			bank("bay_bank:elandor_east:dawnmere", 704, 705, 518, 518, 5),
			bank("bay_bank:elandor_east:goldmead", 715, 719, 538, 538, 3),
			bank("bay_bank:elandor_east:starbough", 507, 510, 205, 205, 2),
			bank("bay_bank:elandor_east:silverleaf", 709, 710, 212, 212, 2),
			bank("bay_bank:kragmar_west:stillgrave", 782, 783, 770, 770, 3),
			bank("bay_bank:kragmar_west:mournfen", 466, 468, 192, 192, 9),
			bank("bay_bank:kragmar_west:redtusk", 766, 770, 0, 0, 0),
			bank("bay_bank:kragmar_west:sunscar", 744, 745, 522, 522, 10),
			bank("bay_bank:kragmar_east:sunscar", 856, 857, 852, 852, 13),
			bank("bay_bank:kragmar_east:redtusk", 640, 644, 218, 218, 8),
			bank("bay_bank:kragmar_east:raincall", 554, 558, 543, 543, 5),
			bank("bay_bank:kragmar_east:kapok", 788, 789, 646, 646, 6),
		},
		["343674299183575008"] = {
			bank("bay_bank:elandor_west:hearthpine", 709, 710, 589, 589, 6),
			bank("bay_bank:elandor_west:copperfell", 510, 513, 435, 435, 5),
			bank("bay_bank:elandor_west:goldmead", 675, 679, 31, 31, 1),
			bank("bay_bank:elandor_west:dawnmere", 723, 724, 654, 654, 8),
			bank("bay_bank:elandor_east:dawnmere", 725, 726, 427, 427, 7),
			bank("bay_bank:elandor_east:goldmead", 682, 686, 467, 467, 1),
			bank("bay_bank:elandor_east:starbough", 499, 502, 161, 161, 4),
			bank("bay_bank:elandor_east:silverleaf", 813, 814, 758, 758, 9),
			bank("bay_bank:kragmar_west:stillgrave", 748, 749, 162, 162, 5),
			bank("bay_bank:kragmar_west:mournfen", 447, 449, 0, 0, 0),
			bank("bay_bank:kragmar_west:redtusk", 719, 723, 517, 517, 1),
			bank("bay_bank:kragmar_west:sunscar", 717, 718, 578, 578, 10),
			bank("bay_bank:kragmar_east:sunscar", 823, 824, 778, 778, 9),
			bank("bay_bank:kragmar_east:redtusk", 629, 633, 176, 176, 4),
			bank("bay_bank:kragmar_east:raincall", 592, 596, 589, 589, 9),
			bank("bay_bank:kragmar_east:kapok", 724, 725, 538, 538, 3),
		},
		["1959553668008863006"] = {
			bank("bay_bank:elandor_west:hearthpine", 724, 725, 620, 620, 12),
			bank("bay_bank:elandor_west:copperfell", 546, 549, 546, 546, 18),
			bank("bay_bank:elandor_west:goldmead", 688, 692, 120, 120, 10),
			bank("bay_bank:elandor_west:dawnmere", 740, 741, 730, 730, 9),
			bank("bay_bank:elandor_east:dawnmere", 748, 749, 326, 326, 6),
			bank("bay_bank:elandor_east:goldmead", 682, 686, 471, 471, 1),
			bank("bay_bank:elandor_east:starbough", 495, 498, 165, 165, 1),
			bank("bay_bank:elandor_east:silverleaf", 749, 750, 680, 680, 6),
			bank("bay_bank:kragmar_west:stillgrave", 747, 748, 747, 747, 2),
			bank("bay_bank:kragmar_west:mournfen", 455, 457, 149, 149, 1),
			bank("bay_bank:kragmar_west:redtusk", 741, 745, 0, 0, 0),
			bank("bay_bank:kragmar_west:sunscar", 693, 694, 552, 552, 2),
			bank("bay_bank:kragmar_east:sunscar", 838, 839, 189, 189, 8),
			bank("bay_bank:kragmar_east:redtusk", 652, 656, 222, 222, 9),
			bank("bay_bank:kragmar_east:raincall", 602, 606, 537, 537, 2),
			bank("bay_bank:kragmar_east:kapok", 745, 746, 630, 630, 2),
		},
		["15219119262482319357"] = {
			bank("bay_bank:elandor_west:hearthpine", 734, 735, 610, 610, 15),
			bank("bay_bank:elandor_west:copperfell", 545, 548, 342, 342, 3),
			bank("bay_bank:elandor_west:goldmead", 691, 695, 186, 186, 6),
			bank("bay_bank:elandor_west:dawnmere", 737, 738, 718, 718, 7),
			bank("bay_bank:elandor_east:dawnmere", 732, 733, 333, 333, 5),
			bank("bay_bank:elandor_east:goldmead", 731, 735, 571, 571, 4),
			bank("bay_bank:elandor_east:starbough", 514, 517, 210, 210, 2),
			bank("bay_bank:elandor_east:silverleaf", 730, 731, 656, 656, 6),
			bank("bay_bank:kragmar_west:stillgrave", 747, 748, 139, 139, 1),
			bank("bay_bank:kragmar_west:mournfen", 451, 453, 187, 187, 6),
			bank("bay_bank:kragmar_west:redtusk", 699, 703, 496, 496, 1),
			bank("bay_bank:kragmar_west:sunscar", 696, 697, 384, 384, 2),
			bank("bay_bank:kragmar_east:sunscar", 839, 840, 822, 822, 5),
			bank("bay_bank:kragmar_east:redtusk", 666, 670, 235, 235, 11),
			bank("bay_bank:kragmar_east:raincall", 622, 626, 508, 508, 2),
			bank("bay_bank:kragmar_east:kapok", 746, 747, 635, 635, 6),
		},
		["16178445837170081103"] = {
			bank("bay_bank:elandor_west:hearthpine", 700, 701, 529, 529, 7),
			bank("bay_bank:elandor_west:copperfell", 503, 506, 326, 326, 5),
			bank("bay_bank:elandor_west:goldmead", 678, 682, 195, 195, 8),
			bank("bay_bank:elandor_west:dawnmere", 699, 700, 699, 699, 3),
			bank("bay_bank:elandor_east:dawnmere", 759, 761, 563, 563, 11),
			bank("bay_bank:elandor_east:goldmead", 684, 688, 509, 509, 2),
			bank("bay_bank:elandor_east:starbough", 500, 503, 67, 67, 2),
			bank("bay_bank:elandor_east:silverleaf", 762, 763, 745, 745, 6),
			bank("bay_bank:kragmar_west:stillgrave", 793, 794, 142, 142, 4),
			bank("bay_bank:kragmar_west:mournfen", 454, 456, 78, 78, 3),
			bank("bay_bank:kragmar_west:redtusk", 728, 732, 0, 0, 0),
			bank("bay_bank:kragmar_west:sunscar", 722, 723, 583, 583, 4),
			bank("bay_bank:kragmar_east:sunscar", 870, 871, 861, 861, 13),
			bank("bay_bank:kragmar_east:redtusk", 653, 657, 228, 228, 12),
			bank("bay_bank:kragmar_east:raincall", 585, 589, 503, 503, 11),
			bank("bay_bank:kragmar_east:kapok", 762, 763, 576, 576, 3),
		},
		["18446744073709551615"] = {
			bank("bay_bank:elandor_west:hearthpine", 711, 712, 541, 541, 7),
			bank("bay_bank:elandor_west:copperfell", 500, 503, 318, 318, 3),
			bank("bay_bank:elandor_west:goldmead", 685, 689, 197, 197, 5),
			bank("bay_bank:elandor_west:dawnmere", 704, 705, 608, 608, 3),
			bank("bay_bank:elandor_east:dawnmere", 707, 708, 457, 457, 8),
			bank("bay_bank:elandor_east:goldmead", 698, 702, 591, 591, 3),
			bank("bay_bank:elandor_east:starbough", 497, 500, 0, 0, 0),
			bank("bay_bank:elandor_east:silverleaf", 726, 727, 722, 722, 4),
			bank("bay_bank:kragmar_west:stillgrave", 776, 777, 560, 560, 1),
			bank("bay_bank:kragmar_west:mournfen", 451, 453, 0, 0, 0),
			bank("bay_bank:kragmar_west:redtusk", 725, 729, 513, 513, 1),
			bank("bay_bank:kragmar_west:sunscar", 711, 712, 558, 558, 7),
			bank("bay_bank:kragmar_east:sunscar", 883, 884, 881, 881, 13),
			bank("bay_bank:kragmar_east:redtusk", 629, 633, 195, 195, 3),
			bank("bay_bank:kragmar_east:raincall", 592, 596, 0, 0, 0),
			bank("bay_bank:kragmar_east:kapok", 757, 758, 642, 642, 3),
		},
	},
	-- The Scan-3b occupancy row counts per seed: how many `scan3b_step` and
	-- `scan3b_selection` rows the record carries.  These are the tiers the
	-- merge histograms fold, so a projection that silently stops emitting a
	-- direction or a selection class is caught here and not only in the
	-- digest.
	scan3b_rows = {
		["0"] = {steps = 363, selections = 31},
		["2147483648"] = {steps = 393, selections = 31},
		["343674299183575008"] = {steps = 377, selections = 31},
		["1959553668008863006"] = {steps = 375, selections = 32},
		["15219119262482319357"] = {steps = 379, selections = 32},
		["16178445837170081103"] = {steps = 398, selections = 31},
		["18446744073709551615"] = {steps = 362, selections = 29},
	},
	-- Scan-3b attribution rows in emission order.  Five of the seven seeds
	-- attribute nothing at all: no transition edge loses a tuple to a dying
	-- bank.  W-112 charges three incomplete tuples across two edges, and
	-- Slot 29 carries the single R19-genesis row named in
	-- `attribution_witness` above.  All four occupied far terminals are
	-- apertures resolved direct -- the wing arm of `scan3b_far_kind` is
	-- unoccupied over this roster, which is why the R21 wing probe has no
	-- KAT witness here and gets its coverage from the synthetic classifier
	-- KAT instead.
	attribution = {
		["0"] = {},
		["2147483648"] = {},
		["343674299183575008"] = {
			attributed("land_004", "from",
				"bay_bank:elandor_west:dawnmere", "aperture", "direct", 2),
			attributed("land_013", "to",
				"bay_bank:kragmar_east:sunscar", "aperture", "direct", 1),
		},
		["1959553668008863006"] = {},
		["15219119262482319357"] = {},
		["16178445837170081103"] = {
			attributed("land_010", "to",
				"bay_bank:kragmar_west:stillgrave", "aperture", "direct", 1),
		},
		["18446744073709551615"] = {},
	},
	-- Scan-4 (contracts 9.1/9.4), per seed and all verbatim from the measured
	-- record (re-measured 2026-08-20 at the section-11 package -- the
	-- recorded correction of its commit).
	--
	-- `face_rejects` is the ordered list of the faces that do NOT classify
	-- `face_simple_select`; every one of the other 38 - #face_rejects faces
	-- does.  Since the 11.5-C acceptance the list carries the
	-- `face_appendix_select` acceptances with their pinned appendix station
	-- counts (the worker asserts the count through the row's detail); a
	-- `face_non_simple_reject` here would be occupancy of the loud guard.
	-- `whole` is either the evaluated summary (columns / planned water
	-- columns / dry columns and the four H38 counters) or the consequent row
	-- naming the first blocking face in source order.  g = o = r = m = 0 on
	-- all seven evaluated seeds is the H38 per-seed pin: no gap column, no
	-- undeclared water multiplicity, no undeclared dry multiplicity, and the
	-- representation cross-check `m` finds zero disagreement between the
	-- run-derived water decision and the stage's own predicates.  Those
	-- zeros are the whole reason the H38 normalization is allowed to stand
	-- in for a per-column sweep -- and on the three appendix seeds they now
	-- also pin the winding row derivation against the point predicates.
	--
	-- `whole_intervals`: the footprint partitions into two realized classes
	-- and only two on every seed: a declared seam (about 51.6k intervals,
	-- one column each -- these are the zone boundaries) and single ownership
	-- (about 70k intervals covering the remaining ~30.3M columns).
	--
	-- `fragments` is the section 6.2.3 excluded-fragment tier.  Only three
	-- roster seeds carry a fragment at all, one row each.  Slot 30's is the
	-- M5 fragment witness, Slot 29's is its land_010 counterpart, and all
	-- three -- W-112's included, since its faces now compose and accept --
	-- classify `fragment_owned_once_select`: a Bank owns them, which is the
	-- validate_excluded_fragment_evidence rule.
	scan4 = {
		["0"] = {
			face_rejects = {},
			whole = {class = "whole_evaluated", columns = 30312952,
				planned = 2153330, dry = 28159622, g = 0, o = 0, r = 0, m = 0},
			whole_intervals = {
				{class = "whole_declared_seam_select",
					intervals = 51556, columns = 51556},
				{class = "whole_single_owner_select",
					intervals = 70466, columns = 30261396},
			},
			fragments = {},
		},
		["2147483648"] = {
			face_rejects = {
				{face = "zone_face:elandor_silverleaf_glades",
					class = "face_appendix_select", appendix_stations = 1,
					pinch_stations = 0},
			},
			whole = {class = "whole_evaluated", columns = 30314339,
				planned = 2146228, dry = 28168111, g = 0, o = 0, r = 0, m = 0},
			whole_intervals = {
				{class = "whole_declared_seam_select",
					intervals = 51546, columns = 51546},
				{class = "whole_single_owner_select",
					intervals = 70753, columns = 30262793},
			},
			fragments = {},
		},
		["343674299183575008"] = {
			face_rejects = {
				{face = "zone_face:elandor_dawnmere_fields",
					class = "face_appendix_select", appendix_stations = 4,
					pinch_stations = 0},
				{face = "zone_face:elandor_silverleaf_glades",
					class = "face_appendix_select", appendix_stations = 2,
					pinch_stations = 0},
			},
			whole = {class = "whole_evaluated", columns = 30310911,
				planned = 2169899, dry = 28141012, g = 0, o = 0, r = 0, m = 0},
			whole_intervals = {
				{class = "whole_declared_seam_select",
					intervals = 51515, columns = 51515},
				{class = "whole_single_owner_select",
					intervals = 70826, columns = 30259396},
			},
			fragments = {
				{edge = "land_013", station = 1801,
					class = "fragment_owned_once_select"},
			},
		},
		["1959553668008863006"] = {
			face_rejects = {
				{face = "zone_face:kragmar_stillgrave_hollow",
					class = "face_appendix_select", appendix_stations = 1,
					pinch_stations = 0},
			},
			whole = {class = "whole_evaluated", columns = 30318048,
				planned = 2143371, dry = 28174677, g = 0, o = 0, r = 0, m = 0},
			whole_intervals = {
				{class = "whole_declared_seam_select",
					intervals = 51538, columns = 51538},
				{class = "whole_single_owner_select",
					intervals = 70971, columns = 30266510},
			},
			fragments = {},
		},
		["15219119262482319357"] = {
			face_rejects = {},
			whole = {class = "whole_evaluated", columns = 30316314,
				planned = 2112499, dry = 28203815, g = 0, o = 0, r = 0, m = 0},
			whole_intervals = {
				{class = "whole_declared_seam_select",
					intervals = 51560, columns = 51560},
				{class = "whole_single_owner_select",
					intervals = 70899, columns = 30264754},
			},
			fragments = {
				{edge = "land_007", station = 177,
					class = "fragment_owned_once_select"},
			},
		},
		["16178445837170081103"] = {
			face_rejects = {},
			whole = {class = "whole_evaluated", columns = 30303110,
				planned = 2135396, dry = 28167714, g = 0, o = 0, r = 0, m = 0},
			whole_intervals = {
				{class = "whole_declared_seam_select",
					intervals = 51591, columns = 51591},
				{class = "whole_single_owner_select",
					intervals = 70927, columns = 30251519},
			},
			fragments = {
				{edge = "land_010", station = 1781,
					class = "fragment_owned_once_select"},
			},
		},
		["18446744073709551615"] = {
			face_rejects = {},
			whole = {class = "whole_evaluated", columns = 30315586,
				planned = 2144056, dry = 28171530, g = 0, o = 0, r = 0, m = 0},
			whole_intervals = {
				{class = "whole_declared_seam_select",
					intervals = 51579, columns = 51579},
				{class = "whole_single_owner_select",
					intervals = 71066, columns = 30264007},
			},
			fragments = {},
		},
	},
	-- Re-measured 2026-08-20 at the section-11.9 completion: the appendix
	-- seeds' face detail bytes gained their pinch counts (values unchanged,
	-- all filaments), everything else byte-identical.
	digest = "e6170d6117b4d1632535c4e1a1a3d6ec83598c68ca0888ccb04e9bc570d9cdda",
	-- The gate's pinned half (plan section 6.6.5), over the section-6.2
	-- artifacts the merge builds from exactly the records above -- not over the
	-- manifest, which names the merge interpreter and therefore differs between
	-- the LuaJIT and PUC runs by construction.  The LuaJIT/PUC comparison shows
	-- the two runtimes agree; this shows they agree on the value a reviewed run
	-- measured, so a semantic change in the merge cannot pass merely because
	-- both interpreters changed with it.  Re-measured 2026-08-20 over the
	-- seven-seed record at the section-11 package (the three appendix seeds'
	-- rows and the two new declared classes move the artifacts legitimately),
	-- and again at the section-11.9 completion (the pinch counts in the
	-- appendix details move the artifacts legitimately); LuaJIT and PUC
	-- returned the same bytes.
	merge_artifacts_digest =
		"fcc5ad01d4366af1269bbbe98415aad2bd596fb82f33625a15b5b4957236b795",
}
