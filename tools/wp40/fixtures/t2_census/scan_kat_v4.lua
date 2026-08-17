-- WP40 T2 census scan KAT fixture (plan section 6.7, milestones M1+M3+M4+M5
-- plus the 2026-08-17 stage-reject package).
-- Fill counts are the known F6 witness occupancies from
-- wp40-t2-degeneracy-completeness.md section 3-F6, in source.bays order
-- (bay_elandor_west, bay_elandor_east, bay_kragmar_west, bay_kragmar_east).
-- The scan2 blocks pin the M3 counting tier and R19 joint decision, all
-- measured 2026-08-16 -- notably the Slot-29 witness (analysis section
-- 3-F2): land_010:to carries two direct R16 candidates, the endpoint's own
-- tuple dies bank-incomplete (the R19-genesis dead direct terminal) and the
-- retreat tuple completes, leaving exactly one complete tuple.  At max-u64
-- the same endpoint resolves via the diagonal elbow, matching the pinned
-- R16/R17 prerequisite fixture's 7-direct/1-elbow split.
-- The scan3 blocks pin the M4 Scan-3a projections, measured 2026-08-16.
-- M5 added the fourth seed, Slot 30, for the analysis section 3-F8
-- fragment-bearing case, which no earlier KAT covered; the stage-reject
-- package added the fifth, W-112, the first measured 3-F9 aperture
-- occupancy -- a seed that emits a stage_reject record instead of a roster.
-- The digest moved with each addition, legitimately.  The digest pins the
-- complete canonical worker TSV over seeds 0, W-112, Slot 30, Slot 29 and
-- max-u64 in ascending canonical decimal order and is the determinism gate:
-- any interpreter- or order-dependent drift in the census projection changes
-- it.  `merge_artifacts_digest` is the M5 gate's pinned half over the five
-- section-6.2 artifacts the merge builds from exactly these records.
local function endpoint(eligible, success, direct, elbow)
	return {eligible = eligible, success = success, direct = direct,
		elbow = elbow}
end
local function edge(class, tuples, complete)
	return {class = class, tuples = tuples, complete = complete}
end
local select_one = "scan2_exactly_one_complete_select"
-- The retained R15 Stage-1 Wing tail-pair corpus of
-- wp40-source-authority.md section 6.1, restated here in source Wing order
-- as five independent per-Wing quantities.  It is a *comparison* target, not
-- an input: M4 measured every row from the census projection at all three
-- KAT seeds and they agreed, which is what makes the corpus an acceptance
-- oracle for the Scan-3a Wing analysis rather than a number copied forward.
-- The `structural` and `rank` columns also carry the analysis section 3-F5
-- Slot-29 witness (Kragmar-west-left: 2 structural pairs, 1 wedge-valid at
-- rank 2), which turns out to hold at all three seeds and not only at
-- Slot 29.
local function wing(id, raw, structural, wedge_valid, rank, radius,
		negative_length, positive_length)
	return {id = id, raw = raw, structural = structural,
		wedge_valid = wedge_valid, rank = rank, radius = radius,
		negative_length = negative_length, positive_length = positive_length}
end
return {
	schema = "grug_wp40_census_scan_v4",
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
	-- The analysis named Slot 30 as the first fragment-bearing seed; this is
	-- the measurement that confirms it rather than assuming it.
	fragment_witness = {seed = "15219119262482319357", edge = "land_007",
		attachment = "perimeter_attachment:elandor:land_007", intervals = 2,
		singletons = 1, qualifying = 1, class = "transition_interval_select"},
	-- The load-bearing stage-reject witness (2026-08-17): W-112, the seed the
	-- first full-W starts died on -- solo-reproduced, deterministic, the first
	-- measured occupancy of an analysis section 3-F9 aperture malformation
	-- class.  The worker asserts that this seed still stage-rejects with
	-- exactly this site and class: a KAT run in which it quietly builds a
	-- full stage means the finding this package records has vanished, and the
	-- digest alone would report that only as an opaque drift.
	stage_reject_witness = {seed = "343674299183575008",
		site = "bay_mouth_aperture:elandor_east",
		class = "aperture_second_run_reject"},
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
	-- Every head Bank completes at all three seeds with no branching step at
	-- all, so the reachability DFS never runs and both trace stress scalars
	-- are zero.  The observed 453-794 step and <= 24 frame figures in the
	-- analysis came from transition-incident Banks, which are Scan-3b.
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
	-- with the nearest station's delta.  That bound reads 46 at Slot 30, the
	-- tightest of the four seeds and still 14 above the structural floor of
	-- 80 - 48.
	--
	-- Pinned per seed in `source.bays` order as
	-- {min_width_nodes, min_delta_nodes, column_bound_nodes}, so a drift in
	-- either the station minimum or the exact bound is legible by name and not
	-- only through the record digest.
	bank_width = {min_segment = 3, delta_bound = 48, column_bound_floor = 32,
		taper_floor_nodes = 80,
		per_seed = {
			["0"] = {{80, 0, 69}, {80, 0, 76}, {80, 0, 66}, {80, 0, 80}},
			["15219119262482319357"] =
				{{75, -30, 46}, {80, 0, 63}, {80, 0, 80}, {74, -26, 51}},
			["16178445837170081103"] = {{80, 0, 80}, {80, 0, 74}, {80, 0, 60},
				{80, 0, 60}},
			["18446744073709551615"] = {{80, 0, 80}, {80, 0, 80}, {80, 0, 67},
				{80, 0, 60}},
		}},
	fills = {
		["0"] = {0, 0, 0, 0},
		["15219119262482319357"] = {0, 0, 0, 0},
		["16178445837170081103"] = {0, 0, 0, 0},
		["18446744073709551615"] = {1, 1, 1, 0},
	},
	-- Aperture resolution modes per seed (analysis section 3-F4): eight direct
	-- incidences everywhere except Slot 29, whose Elandor-east `before`
	-- incidence is the tail-mode witness above.
	aperture_modes = {
		["0"] = {direct = 8, diagonal_shoulder = 0},
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
		-- Slot 30.  Every endpoint resolves once and directly and every edge
		-- completes exactly one joint tuple: the fragment this seed witnesses
		-- lives entirely at the F1 interval tier and leaves R19 untouched,
		-- which is itself the measurement.
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
	digest = "a9c3ecfceb47f591e1d28a943ca45503458250f8a12bdabd8463a353ea2e499d",
	-- The M5 gate's pinned half (plan section 6.6.5), over the five section-6.2
	-- artifacts the merge builds from exactly the records above -- not over the
	-- manifest, which names the merge interpreter and therefore differs between
	-- the LuaJIT and PUC runs by construction.  The LuaJIT/PUC comparison shows
	-- the two runtimes agree; this shows they agree on the value a reviewed run
	-- measured, so a semantic change in the merge cannot pass merely because
	-- both interpreters changed with it.
	merge_artifacts_digest =
		"2a22bfd9ee3b7bacfc7b3d323e23f636afcccb630752c01b4f8dd4afac8c0c2f",
}
