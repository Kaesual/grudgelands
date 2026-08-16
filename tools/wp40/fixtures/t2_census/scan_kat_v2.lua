-- WP40 T2 census scan KAT fixture (plan section 6.7, milestones M1+M3).
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
return {
	schema = "grug_wp40_census_scan_v2",
	fills = {
		["0"] = {0, 0, 0, 0},
		["16178445837170081103"] = {0, 0, 0, 0},
		["18446744073709551615"] = {1, 1, 1, 0},
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
	digest = "347f30f636b438d0f62bb2010668a0bc13ffed973433e0bb746e002ee99f3028",
}
