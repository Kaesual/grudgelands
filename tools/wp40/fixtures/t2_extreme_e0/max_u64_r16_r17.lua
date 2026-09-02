-- Positive retained prerequisite evidence for the former fixed-slot-19 fatal.
-- This closes that one R16/R17 geometry case; selected-four Stage-2 proof and
-- fixed-corpus promotion remain pending.
--
-- Unlike the E0 pool gate, this is compiled-geometry evidence: it records a
-- full max-u64 partition compile, so it does depend on the Source and
-- partition bytes and must be re-pinned whenever they change.
--
-- Re-pinned at R19 (was R16/R17: source 154cbc31..., boundary a32f35c4...,
-- partition de53e1b5...) and again at census M5 for a comment-only correction
-- in the Scan-3a bank-width projection (partition was 52a5db73...); the
-- compiled digest did not move either time, which is the point of the check.
-- The re-pin asserts only that the byte values below
-- are the reviewed inputs that reproduce this compiled result; it does not
-- assert anything about the earlier values. It invalidates nothing measured
-- here, because every recorded geometry fact -- the eight transitions, both
-- bank ids, the 453-station Mournfen run and its tail, all three notch fills --
-- and the compiled digest 852d0a32... are bit-identical to the R16/R17 record.
-- Only the input identifiers moved.
return {
	status = "R16_R17_PREREQUISITE_PASSED",
	scope = "R16_R17_FULL_PARTITION_PREREQUISITE_ONLY",
	stage2_status = "pending_selected_four",
	seed = "18446744073709551615",
	fixed_slot = 19,
	transitions = {
		{source_id = "bay_edge_transition:land_001:to", edge_id = "land_001",
			endpoint = "to", bay_id = "bay_elandor_west", direct_candidate = true,
			e = {x = -1217, z = -2230}, selected = {x = -1217, z = -2230}},
		{source_id = "bay_edge_transition:land_004:from", edge_id = "land_004",
			endpoint = "from", bay_id = "bay_elandor_west", direct_candidate = true,
			e = {x = -845, z = -2243}, selected = {x = -845, z = -2243}},
		{source_id = "bay_edge_transition:land_004:to", edge_id = "land_004",
			endpoint = "to", bay_id = "bay_elandor_east", direct_candidate = true,
			e = {x = 743, z = -2243}, selected = {x = 743, z = -2243}},
		{source_id = "bay_edge_transition:land_007:from", edge_id = "land_007",
			endpoint = "from", bay_id = "bay_elandor_east", direct_candidate = true,
			e = {x = 1118, z = -2233}, selected = {x = 1118, z = -2233}},
		{source_id = "bay_edge_transition:land_010:to", edge_id = "land_010",
			endpoint = "to", bay_id = "bay_kragmar_west", direct_candidate = false,
			e = {x = -1140, z = 2241}, w = {x = -1139, z = 2242},
			elbows = {{x = -1140, z = 2242}, {x = -1139, z = 2241}},
			selected = {x = -1140, z = 2242}},
		{source_id = "bay_edge_transition:land_013:from", edge_id = "land_013",
			endpoint = "from", bay_id = "bay_kragmar_west", direct_candidate = true,
			e = {x = -757, z = 2246}, selected = {x = -757, z = 2246}},
		{source_id = "bay_edge_transition:land_013:to", edge_id = "land_013",
			endpoint = "to", bay_id = "bay_kragmar_east", direct_candidate = true,
			e = {x = 882, z = 2239}, selected = {x = 882, z = 2239}},
		{source_id = "bay_edge_transition:land_016:from", edge_id = "land_016",
			endpoint = "from", bay_id = "bay_kragmar_east", direct_candidate = true,
			e = {x = 1192, z = 2226}, selected = {x = 1192, z = 2226}},
	},
	stillgrave_bank_id = "bay_bank:kragmar_west:stillgrave",
	stillgrave_first_xz = {-1140, 2242, -1141, 2242},
	mournfen_bank_id = "bay_bank:kragmar_west:mournfen",
	mournfen_station_count = 453,
	mournfen_tail_xz = {-1135, 2237, -1136, 2238, -1137, 2239,
		-1138, 2240, -1139, 2241, -1140, 2242},
	notch_fill_policy_id = "single_pass_same_bay_raw_mask_degree_one_notch_v1",
	notch_fill = {
		{bay_id = "bay_elandor_west", x = -775, z = -2349},
		{bay_id = "bay_elandor_east", x = 887, z = -2036},
		{bay_id = "bay_kragmar_west", x = -1121, z = 2220},
	},
	source_checksum = "e244c25fdfec1736a905c9fd55115fbad1fb1bc070e3978336d7cf089b465963",
	boundary_policy_checksum = "ed1cd5440d713e69d7dc913626490ae8c0af43e30a825ad9a81fcb6e13a60d2d",
	partition_sha256 = "e12f4f1b48a0cda79c9ac61b2de6299d9491fd185491f95b4d9c644ed2a599a3",
	compiled_sha256 = "df08c6983a30dc344b1707c35e64c9728d4a2c5bfaca4bf37bdb04c8c6f3b3ac",
	reproduce = "WP40_LUA_BIN=/usr/bin/luajit tools/wp40/run_t2_extreme.sh",
}
