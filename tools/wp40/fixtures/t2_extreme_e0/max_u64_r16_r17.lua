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
	source_checksum = "5e8866d1490b508e54a4d503c087fa5265722ecd443dcfe098bc0e672b2d0000",
	boundary_policy_checksum = "3e6209c76325fa7fa7395c7f75f15181f21ca2e81e8e8c26848019221d96e8fe",
	partition_sha256 = "330807753b6e4bb534e7d19788743fa95d3e437d5b61c0d88a8282aeb1192b5c",
	compiled_sha256 = "852d0a32ee7730c32d17c23f231598a4f7a30e5035cd8a343e3a6bde0c447d95",
	reproduce = "WP40_LUA_BIN=/usr/bin/luajit tools/wp40/run_t2_extreme.sh",
}
