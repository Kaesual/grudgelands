-- WP40 T2 census scan KAT fixture (plan section 6.7, milestones M1+M3+M4).
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
-- The digest pins the complete canonical worker TSV over seeds 0, Slot 29
-- and max-u64 and is the determinism gate: any interpreter- or
-- order-dependent drift in the census projection changes it.
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
	schema = "grug_wp40_census_scan_v3",
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
	-- Section 6.4 / source authority section 7.2.  The minimum jittered bank
	-- half-width is 80 nodes in every Bay at every KAT seed, and it sits at
	-- the segment-3 terminal station, where the 96-station taper forces
	-- delta_nodes to zero -- so the narrowest station is exactly the one the
	-- jitter cannot move.  Section 7.2's "half-widths of 320-370" describes
	-- the mouth station only; the authored centrelines taper to 80 at the Bay
	-- head, against a jitter bound of 48.
	bank_width = {min_width_nodes = 80, min_segment = 3, delta_bound = 48},
	fills = {
		["0"] = {0, 0, 0, 0},
		["16178445837170081103"] = {0, 0, 0, 0},
		["18446744073709551615"] = {1, 1, 1, 0},
	},
	-- Aperture resolution modes per seed (analysis section 3-F4): eight direct
	-- incidences everywhere except Slot 29, whose Elandor-east `before`
	-- incidence is the tail-mode witness above.
	aperture_modes = {
		["0"] = {direct = 8, diagonal_shoulder = 0},
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
	digest = "902eef21101629efe95ccb460cc3dd7af86db9d3153f8295ee8c1e0d5d8b6217",
}
