-- Closed input gate for T2c-E0-C1 PUC conformance.  This records the
-- immutable LuaJIT measurement and PUC merge result; it does not claim that
-- the selected four have passed their full partition gates.
return {
	schema = "grug_wp40_extreme_conformance_gate_v1",
	status = "pending_selected_four_conformance",
	measurement_commit = "53be77ee3dab615be39c2e66b6d24a4adccc3d26",
	measurement_tree = "c9ac6639048804f15d76bd02101cf9e3a062e9de",
	authority_dag_sha256 =
		"d059686fb3668627b1ed153e5f54aa5572fd96624e43487b2c157dbc4c505949",
	source_checksum =
		"154cbc31dea35e0aed06f9525ecb3f2d1ac6fa90f0a71e127da591ed16ed067d",
	boundary_policy_checksum =
		"a32f35c4621d84b50f93253fa7e046fe79553796d6b2752f6344ebf4cea1380f",
	partition_sha256 =
		"de53e1b5cc0cc3fcaee2d58ce3cc391c637b123d430f234c74e4960ad4bee967",
	artifact_sha256 =
		"1096139ae2f98e5105fd9f19a09954f22c0ac63f7d6a0be95b44de259c034017",
	manifest_sha256 =
		"23b909d2b4d30ccffce3c09b9a1a987ffe1123136583fe409377a27fd0649a52",
	candidate_rows_sha256 =
		"b08e142a16da23f5b7f07c3ec2e6f894705130d1d72fe409998fb5f028deada3",
	shards = {
		{first = 0, last = 511, sha256 =
			"d0f686d397ee2ee89e45aa9647f066c8045af4fd53c65ee9abe9d50bd62718e7"},
		{first = 512, last = 1023, sha256 =
			"c5a4187980efdba062324af72fd656f862c7b64c127cf2bf2de1839982193d6d"},
		{first = 1024, last = 1535, sha256 =
			"e324ff26c9780177ec40411ca9a662bdf21bca6d0fdb2f560afc3e3616324a29"},
		{first = 1536, last = 2047, sha256 =
			"cbb60f92e3601bf139249e8b5072dc9c79f9da7ae54e0940e0d6e3fc4283f13d"},
		{first = 2048, last = 2559, sha256 =
			"b8a43393eb577ca3abce364dda2c9ccd22a0a72ffd71d318e884a021e21610dd"},
		{first = 2560, last = 3071, sha256 =
			"4d6e419212f8e0f508529470015fd8bfda2b6ca28f15a5a2e5fd54865e280ab5"},
		{first = 3072, last = 3583, sha256 =
			"7fb4620ef2783fcc8d9766d7a281cbd9d69ef0f160e34596cb699f51ef62bf61"},
		{first = 3584, last = 4095, sha256 =
			"9022c8d43fae43d0ac9060531055f8e0e1097b585b5b7cc4b7edbfd8fb7ed93a"},
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
