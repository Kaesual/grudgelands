-- Exact negative C1 witnesses from the immutable 5a2fc0d PUC selected run.
-- They are evidence of two selected Stage-2 blockers, not successful geometry
-- and not authority for a fallback candidate or a repair policy.
return {
	schema = "grug_wp40_extreme_selected_stage2_blocked_v1",
	status = "selected_stage2_blocked",
	scope = "T2C_E0_SELECTED_STAGE2_NEGATIVE_WITNESS_ONLY",
	stage2_status = "blocked_without_fallback",
	measurement_commit = "53be77ee3dab615be39c2e66b6d24a4adccc3d26",
	measurement_tree = "c9ac6639048804f15d76bd02101cf9e3a062e9de",
	authority_dag_sha256 = "d059686fb3668627b1ed153e5f54aa5572fd96624e43487b2c157dbc4c505949",
	conformance_commit = "5a2fc0d49276b7cded481fb9758782af967e2b0a",
	conformance_tree = "0f81de16572753a5d1b34959b38168d47c592e41",
	conformance_dag_sha256 = "086855378ed15a5781d57335308f9ff62e6731e376c4cca8591bee4337478d6c",
	artifact_sha256 = "1096139ae2f98e5105fd9f19a09954f22c0ac63f7d6a0be95b44de259c034017",
	manifest_sha256 = "23b909d2b4d30ccffce3c09b9a1a987ffe1123136583fe409377a27fd0649a52",
	candidate_rows_sha256 = "b08e142a16da23f5b7f07c3ec2e6f894705130d1d72fe409998fb5f028deada3",
	interpreter_id = "puc_lua51",
	interpreter_path = "/home/jan/projects/grudgelands/tools/bin/lua51",
	interpreter_version = "Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
	interpreter_sha256 = "a1a427f38260513b64158630bc2b7d2fccfa31b48129efbfbcc60e02e4960a4f",
	source_checksum = "154cbc31dea35e0aed06f9525ecb3f2d1ac6fa90f0a71e127da591ed16ed067d",
	boundary_policy_checksum = "a32f35c4621d84b50f93253fa7e046fe79553796d6b2752f6344ebf4cea1380f",
	partition_sha256 = "de53e1b5cc0cc3fcaee2d58ce3cc391c637b123d430f234c74e4960ad4bee967",
	cases = {
		{
			slot = 29, candidate_index = 1713,
			seed = "16178445837170081103",
			kind = "invalid_aperture_bank_start",
			bank_id = "bay_bank:elandor_east:dawnmere",
			aperture_id = "bay_mouth_aperture:elandor_east",
			aperture_side = "before",
			transition_id = "bay_edge_transition:land_004:to",
			diagnostic = "WP40 geometry partition: bay_bank:elandor_east:dawnmere " ..
				"has an invalid start half-edge distance=1 candidate=false " ..
				"569:-2928->570:-2927 target=743:-2243 end=land_004:to " ..
				"authored=nil/nil own_ESWN=0000 foreign_ESWN=0000 envelope=true " ..
				"dry=true footprint=0 aperture=false",
		},
		{
			slot = 30, candidate_index = 1047,
			seed = "15219119262482319357",
			kind = "second_retained_land_run",
			edge_id = "land_007",
			transition_id = "bay_edge_transition:land_007:from",
			attachment_id = "perimeter_attachment:elandor:land_007",
			diagnostic = "WP40 geometry partition: land_007 has a second retained land run",
		},
	},
}
