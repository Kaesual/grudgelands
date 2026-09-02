-- Closed input gate for the T2c-E0-C1 PUC conformance over the v3 scalar pool.
-- It records the immutable LuaJIT measurement and its PUC merge result; it does
-- not claim that the selected four have passed their full partition gates.
--
-- This is a SEPARATE record from the frozen pre-v3 conformance_gate.lua, which
-- stays exactly as it is as the recorded conclusion of the 53be77e measurement.
-- The two can never be confused: this schema is _v3, and it names the pool
-- provenance with pool_-prefixed fields that the pre-v3 gate does not have.
--
-- What it binds, and what it deliberately does not: the pool is a stage-S1
-- product, so the provenance is the stage-S1 authority digest and the S1 Source
-- projection.  source_checksum, boundary_policy_checksum and partition_sha256
-- are gone on purpose -- the selector cannot read those stages, so they must
-- not be able to invalidate a measured pool.
return {
	schema = "grug_wp40_extreme_conformance_gate_v3",
	status = "pending_selected_four_conformance",
	-- (R3a) HISTORICAL pool origin.  These describe where the scalars came
	-- from; they are NOT a claim about the tree the conformance runs on.
	pool_measurement_commit = "19fc28d1e1ecb2a18c7bb208d21c448cce12bc7d",
	pool_measurement_tree = "bca04056315412b9f19f20bbe554b0693f658c17",
	pool_authority_dag_sha256 =
		"069cce2d637d30538131defbbba0a64bb9cc65f22c71a00fd287183d2518e20a",
	-- (R3b) Stage-S1 CURRENCY.  Recomputed from the conformance tree on every
	-- run and required to equal these two values.
	s1_authority_sha256 =
		"10a790a6436a740efc83e98afe3c374ac4b3520bb425de3d2bd0ac76622db37c",
	s1_source_projection_sha256 =
		"83b1b16a8afd11af654b5dd3e1d9921006848a0903e7b0c01ab39b27edddd652",
	artifact_sha256 =
		"5b5241b35ea036ea08c7128b4900fa578dbe134b28b5cf8a99767290e155e027",
	manifest_sha256 =
		"c8f6185287e4471b0aac2d71c2cceb62114ece566bdbb2ad9e69c5a1c79e0f77",
	-- Row bytes are identical in the pre-v3 and v3 generations -- only the
	-- provenance header differs -- so this digest matches the pre-v3 gate.
	candidate_rows_sha256 =
		"b08e142a16da23f5b7f07c3ec2e6f894705130d1d72fe409998fb5f028deada3",
	shards = {
		{first = 0, last = 511, sha256 =
			"cd71ecd83db7448eaf2108093682db5b73578102a612e61872e47a0ed574181b"},
		{first = 512, last = 1023, sha256 =
			"5f902365a8ae112d88ae8dd4e97247ea96d75f2ac3529a58bba5234c77617c1d"},
		{first = 1024, last = 1535, sha256 =
			"82728869c999ceb0ff7a891e3002ccdf68347e75a84aae37fdb7b4d5ed90465c"},
		{first = 1536, last = 2047, sha256 =
			"fcc4e3b9bcafbd9b8306f26b25c8bca73478025362e91cbb6159f9258ee27749"},
		{first = 2048, last = 2559, sha256 =
			"72fe4813113d06f7cc105e3033c2a7abb7f131d290d0f6abc9c34969f1a57cf6"},
		{first = 2560, last = 3071, sha256 =
			"795b852e39a76468f6a04c5cf9804196bc4586501489f026e3d842e9bd23c3bc"},
		{first = 3072, last = 3583, sha256 =
			"e967aa3663f1a5569b84806026cee8ca4b7d5817686fe0a667672b701efa269f"},
		{first = 3584, last = 4095, sha256 =
			"7a50a4cdb1f3ec5a169ec872ae5aaec0704b908f6b038476e8bf58473fa492db"},
	},
	winners = {
		{slot = 28, id = "greatest_coast", candidate_index = 2192,
			decimal = "5270046902118333881", score_n = 436724351,
			score_d = 74088185856},
		{slot = 29, id = "least_coast", candidate_index = 1713,
			decimal = "16178445837170081103", score_n = -73823911,
			score_d = 12348030976},
		{slot = 30, id = "greatest_noncoast", candidate_index = 1047,
			decimal = "15219119262482319357", score_n = 93907541,
			score_d = 4463263744},
		{slot = 31, id = "least_noncoast", candidate_index = 3438,
			decimal = "17842018860885445630", score_n = -2348099029,
			score_d = 89265274880},
	},
	staging = {label = "grudgelands-wp40-seed-08",
		decimal = "7821741934987559905"},
}
