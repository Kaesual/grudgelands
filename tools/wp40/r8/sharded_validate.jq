def pair_ok:
	.equal and .semantic_ok and .native_census_equal and
	.native_gate_equal and .start_seed_equal and
	.forward_native_gate and .reverse_native_gate and
	.forward_native_required and .reverse_native_required and
	.start_engine_equal and .request_orders_reversed and
	.forward_start and .reverse_start and
	.forward_complete and .reverse_complete and
	.forward_clean_shutdown and .reverse_clean_shutdown and
	.forward_emerge_errors == 0 and .reverse_emerge_errors == 0;

($feature_manifest[0]) as $fm |
($native_manifest[0]) as $nm |
($feature_comparison[0]) as $fc |
($native_comparison[0]) as $nc |
($fm.startup.forward.request_order +
	$nm.startup.forward.request_order) as $forward_union |
($fm.startup.reverse.request_order +
	$nm.startup.reverse.request_order) as $reverse_union |
{
	schema: "grug_wp40_r8_sharded_order_comparison_v1",
	checks: {
		feature_pair: ($fc | pair_ok),
		native_pair: ($nc | pair_ok),
		worker_schema: ($fm.schema == "grug_wp40_r8_headless_smoke_v3" and
			$nm.schema == "grug_wp40_r8_headless_smoke_v3" and
			$fc.schema == "grug_wp40_r8_order_comparison_v2" and
			$nc.schema == "grug_wp40_r8_order_comparison_v2"),
		shard_identity: ($fm.mode == "final" and $nm.mode == "final" and
			$fm.status == "final_feature_smoke_complete" and
			$nm.status == "final_native_smoke_complete" and
			$fm.parallel_orders == true and $nm.parallel_orders == true and
			$fm.shard == "feature" and $fc.shard == "feature" and
			$nm.shard == "native" and $nc.shard == "native"),
		frozen_counts: ($fm.corpus.rows == 10 and $fm.native_corpus.rows == 0 and
			$nm.corpus.rows == 0 and $nm.native_corpus.rows == 32 and
			($fm.startup.forward.request_order | length) == 10 and
			($fm.startup.reverse.request_order | length) == 10 and
			($nm.startup.forward.request_order | length) == 32 and
			($nm.startup.reverse.request_order | length) == 32),
		corpus_identity: ($fm.corpus.digest == $feature_corpus_digest and
			$fm.native_corpus.digest == "" and
			$nm.corpus.digest == $empty_corpus_digest and
			$nm.native_corpus.digest == $native_corpus_digest),
		complete_union: (($forward_union | length) == 42 and
			($forward_union | unique | length) == 42 and
			($reverse_union | length) == 42 and
			($reverse_union | unique | length) == 42 and
			($forward_union | sort) == ($reverse_union | sort)),
		snapshot_identity: ($fm.snapshot.checkout_sha == $checkout_sha and
			$nm.snapshot.checkout_sha == $checkout_sha),
		seed_identity: ($fm.settings.seed_decimal_string == $seed and
			$nm.settings.seed_decimal_string == $seed and
			$fm.settings.seed_string_sha256 == $nm.settings.seed_string_sha256),
		engine_identity: ($engine_digest == $final_engine_digest and
			([$fm.input_identity.engine_sha256_before,
			  $fm.input_identity.engine_sha256_after,
			  $nm.input_identity.engine_sha256_before,
			  $nm.input_identity.engine_sha256_after,
			  $engine_digest] | unique | length) == 1),
		runtime_manifest_identity: ([
			$fm.startup.forward.production.manifest_sha256,
			$fm.startup.reverse.production.manifest_sha256,
			$nm.startup.forward.production.manifest_sha256,
			$nm.startup.reverse.production.manifest_sha256
		] | unique | length) == 1,
		offline_r7_identity: ($fm.input_identity.offline_r7_manifest_sha256 ==
			$nm.input_identity.offline_r7_manifest_sha256),
		time_boundaries: ($fm.settings.probe_timeout_seconds == 10770 and
			$nm.settings.probe_timeout_seconds == 10770 and
			$fm.settings.host_timeout_seconds == 10800 and
			$nm.settings.host_timeout_seconds == 10800 and
			$fm.settings.liquid_update_seconds == 10801 and
			$nm.settings.liquid_update_seconds == 10801),
		port_partition: ($fm.settings.port_base == 32001 and
			$nm.settings.port_base == 32003)
	},
	feature_capture_id: $fm.capture_id,
	native_capture_id: $nm.capture_id,
	forward_request_ids: ($forward_union | sort),
	reverse_request_ids: ($reverse_union | sort),
	limitation: "No real-engine comparison covers mutation between the feature and native shards; R7 offline order evidence and owner-bounded writes cover that residual risk."
} |
.all_ok = all(.checks[]; . == true)
