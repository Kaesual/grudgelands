def selected($events; $name):
	[$events[] | select(.event == $name)];

def canonical_cases($events):
	selected($events; "case") | sort_by(.id) |
	map({id, mapchunk, central_min, central_max, content_sha256,
		param2_sha256, light_sha256, central_voxels, node_counts,
		light_stats, semantic_checks, semantic_evidence, semantic_ok});

def canonical_census($events):
	selected($events; "native_census") | sort_by(.id) |
	map({id, mapchunk, central_min, central_max, content_sha256,
		central_voxels, node_counts, native_census, semantic_checks,
		semantic_ok});

def event_errors($events):
	[selected($events; "emerge")[] | .actions |
		((.cancelled // 0) + (.errored // 0))] | add // 0;

def event_peak_rss($events):
	[$events[] | .process.rss_peak_bytes // empty] | max // null;

def start_ok($events; $order; $ids; $feature_count; $native_count;
		$runtime_manifest_sha256):
	(selected($events; "start")) as $starts |
	($starts | length) == 1 and
	$starts[0].order == $order and
	$starts[0].request_count == ($ids | length) and
	$starts[0].feature_case_count == $feature_count and
	$starts[0].native_corpus_count == $native_count and
	$starts[0].request_order == $ids and
	$starts[0].mapgen == "v7" and
	$starts[0].chunksize == "5" and
	$starts[0].water_level == "1" and
	$starts[0].num_emerge_threads == "1" and
	$starts[0].liquid_update == "10801" and
	$starts[0].mapgen_flags ==
		"caves, dungeons, light, decorations, biomes, ores" and
	$starts[0].seed == "0" and
	$starts[0].seed_sha256 ==
		"5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9" and
	$starts[0].production.enabled == true and
	$starts[0].production.production_enabled == true and
	$starts[0].production.writer_count == 1 and
	$starts[0].production.full_seed == "0" and
	$starts[0].production.schema == "grug_wp40_r7_loader_status_v1" and
	$starts[0].production.manifest_sha256 == $runtime_manifest_sha256;

def emerge_ok($events; $ids):
	(selected($events; "emerge")) as $emerges |
	($emerges | length) == ($ids | length) and
	([$emerges[].id] | sort) == ($ids | sort) and
	all($emerges[];
		(.emerge_us | type) == "number" and .emerge_us > 0 and
		(.actions.generated // 0) == 1 and
		(.actions.cancelled // 0) == 0 and
		(.actions.errored // 0) == 0 and
		(.process.rss_peak_bytes | type) == "number" and
		.process.rss_peak_bytes > 0);

def complete_ok($events; $request_count; $feature_count; $census_count):
	(selected($events; "complete")) as $complete |
	($complete | length) == 1 and
	$complete[0].request_count == $request_count and
	$complete[0].emerged_case_count == $request_count and
	$complete[0].generated_callback_count == $request_count and
	$complete[0].feature_case_count == $feature_count and
	$complete[0].native_census_case_count == $census_count and
	$complete[0].snapshot_count == ($feature_count + $census_count) and
	($complete[0].elapsed_us | type) == "number" and
	$complete[0].elapsed_us > 0 and
	$complete[0].elapsed_us < 10770000000 and
	($complete[0].process.rss_peak_bytes | type) == "number" and
	$complete[0].process.rss_peak_bytes > 0;

def shutdown_ok($events; $request_count; $snapshot_count):
	(selected($events; "shutdown")) as $shutdown |
	($shutdown | length) == 1 and
	$shutdown[0].clean == true and
	$shutdown[0].emerged_cases == $request_count and
	$shutdown[0].snapshotted_cases == $snapshot_count and
	($shutdown[0].process.rss_peak_bytes | type) == "number" and
	$shutdown[0].process.rss_peak_bytes > 0;

def feature_native_gate_ok($events):
	(selected($events; "complete")) as $complete |
	($complete | length) == 1 and
	$complete[0].native_gate.required == false and
	$complete[0].native_gate.ok == true and
	$complete[0].native_gate.dungeon_witness == true and
	$complete[0].native_gate.cave_witness == true and
	$complete[0].native_gate.cave_pairs == true and
	$complete[0].native_gate.stratum_census == true and
	$complete[0].native_gate.native_ore_census == true;

def count_kind($events; $kind):
	[$events[] | select(.kind == $kind)] | length;

def recomputed_event_counts($gate):
	{
		cave_begin: count_kind($gate.events; "cave_begin"),
		cave_end: count_kind($gate.events; "cave_end"),
		large_cave_begin: count_kind($gate.events; "large_cave_begin"),
		large_cave_end: count_kind($gate.events; "large_cave_end"),
		dungeon: count_kind($gate.events; "dungeon")
	};

def recomputed_cave_witnesses($gate):
	[$gate.events[] |
		select(.kind == "cave_begin" or .kind == "large_cave_begin") |
		select(.inside_source == true and
			(.nearby_air_count | type) == "number" and
			.nearby_air_count > 0 and .preserved_cave_air == true)] | length;

def recomputed_dungeon_witnesses($gate):
	[$gate.events[] | select(.kind == "dungeon") |
		select(.inside_source == true and .node == "air" and
			(.below == "default:cobble" or .below == "default:mossycobble") and
			.preserved_room == true)] | length;

def native_gate_internal_ok($gate):
	($gate.events | type) == "array" and
	all($gate.events[];
		.kind == "cave_begin" or .kind == "cave_end" or
		.kind == "large_cave_begin" or .kind == "large_cave_end" or
		.kind == "dungeon") and
	all($gate.events[];
		(.position | type) == "object" and
		(.position.x | type) == "number" and
		(.position.y | type) == "number" and
		(.position.z | type) == "number" and
		(.source_mapchunk | type) == "string" and
		(.source_mapchunk | test("^-?[0-9]+,-?[0-9]+,-?[0-9]+$")) and
		(.inside_source | type) == "boolean") and
	all($gate.events[] |
		select(.kind == "cave_begin" or .kind == "large_cave_begin");
		(.inside_source | type) == "boolean" and
		(.nearby_air_count | type) == "number" and .nearby_air_count >= 0 and
		.preserved_cave_air ==
			(.inside_source == true and .nearby_air_count > 0)) and
	all($gate.events[] | select(.kind == "dungeon");
		(.inside_source | type) == "boolean" and
		.preserved_room == (.inside_source == true and .node == "air" and
			(.below == "default:cobble" or .below == "default:mossycobble"))) and
	$gate.event_counts == recomputed_event_counts($gate) and
	$gate.cave_air_witness_count == recomputed_cave_witnesses($gate) and
	$gate.dungeon_preserved_room_count ==
		recomputed_dungeon_witnesses($gate) and
	$gate.cave_pairs == true and
	$gate.cave_witness == true and
	$gate.event_counts.cave_begin == $gate.event_counts.cave_end and
	$gate.event_counts.large_cave_begin ==
		$gate.event_counts.large_cave_end and
	($gate.event_counts.cave_begin + $gate.event_counts.large_cave_begin) > 0 and
	$gate.cave_air_witness_count > 0 and
	$gate.stratum_census == true and
	($gate.strata | keys | sort) == ([
		"grug_materials:abyssal_rock", "grug_materials:basalt",
		"grug_materials:emberrock", "grug_materials:granite",
		"grug_materials:slate"] | sort) and
	all($gate.strata[]; (type == "number") and . > 0) and
	$gate.native_ore_census == true and
	($gate.native_ore_count | type) == "number" and
	$gate.native_ore_count > 0;

def native_gate_summary($gate):
	{
		event_counts: $gate.event_counts,
		cave_air_witness_count: $gate.cave_air_witness_count,
		dungeon_preserved_room_count: $gate.dungeon_preserved_room_count,
		cave_pairs: $gate.cave_pairs,
		cave_witness: $gate.cave_witness,
		stratum_census: $gate.stratum_census,
		strata: $gate.strata,
		native_ore_census: $gate.native_ore_census,
		native_ore_count: $gate.native_ore_count
	};

def dungeon_status($forward_gate; $reverse_gate):
	if $forward_gate.event_counts.dungeon == 0 and
			$reverse_gate.event_counts.dungeon == 0 then
		"not_observed"
	elif $forward_gate.event_counts.dungeon > 0 and
			$reverse_gate.event_counts.dungeon > 0 and
			$forward_gate.dungeon_preserved_room_count > 0 and
			$reverse_gate.dungeon_preserved_room_count > 0 then
		"observed_and_preserved"
	else
		"blocking_mismatch_or_unpreserved"
	end;

def original_pair_ok($comparison):
	$comparison.equal and $comparison.semantic_ok and
	$comparison.native_census_equal and $comparison.native_gate_equal and
	$comparison.start_seed_equal and $comparison.forward_native_gate and
	$comparison.reverse_native_gate and
	$comparison.forward_native_required and
	$comparison.reverse_native_required and
	$comparison.start_engine_equal and
	$comparison.request_orders_reversed and
	$comparison.forward_start and $comparison.reverse_start and
	$comparison.forward_complete and $comparison.reverse_complete and
	$comparison.forward_clean_shutdown and
	$comparison.reverse_clean_shutdown and
	$comparison.forward_emerge_errors == 0 and
	$comparison.reverse_emerge_errors == 0;

($feature_manifest[0]) as $fm |
($feature_comparison[0]) as $old_feature |
($native_comparison[0]) as $old_native |
(selected($feature_forward; "start")[0]) as $ffs |
(selected($feature_reverse; "start")[0]) as $frs |
(selected($native_forward; "start")[0]) as $nfs |
(selected($native_reverse; "start")[0]) as $nrs |
(selected($native_forward; "complete")[0].native_gate) as $nfg |
(selected($native_reverse; "complete")[0].native_gate) as $nrg |
(canonical_cases($feature_forward)) as $ffc |
(canonical_cases($feature_reverse)) as $frc |
(canonical_census($native_forward)) as $nfn |
(canonical_census($native_reverse)) as $nrn |
(dungeon_status($nfg; $nrg)) as $dungeon_status |
{
	schema: "grug_wp40_r8_sharded_g3_recovery_comparison_v1",
	source: {
		capture_id: $source_capture_id,
		tree_sha256: $source_tree_sha256,
		checkout_sha: $checkout_sha,
		feature_capture_id: $feature_capture_id,
		native_capture_id: $native_capture_id,
		original_status: "failed_closed_before_aggregate",
		original_failure:
			"The native child rejected the former exact native-gate equality and required dungeon witness."
	},
	policy: {
		cave_event_positions_and_local_air_counts: "diagnostic",
		cave_hard_gate:
			"Each order has complete begin/end pairs and at least one preserved air witness; normalized summaries remain equal.",
		dungeon_states: ["not_observed", "observed_and_preserved",
			"blocking_mismatch_or_unpreserved"],
		dungeon_status: $dungeon_status,
		dungeon_claim: (if $dungeon_status == "not_observed" then
			"Dungeon generation was enabled; no dungeon was observed in the bounded grid."
		elif $dungeon_status == "observed_and_preserved" then
			"Dungeon notifications and at least one preserved room were observed in each order."
		else
			"Dungeon evidence is blocking because observation was asymmetric or unpreserved."
		end)
	},
	checks: {
		file_identity: all($file_checks[]; . == true),
		exact_source_identity: ($source_capture_id ==
			"47be3ce009a333423b161b17e53bd4e24645f07ca0910314b1f249aa63b9b9ae" and
			$source_tree_sha256 ==
			"a6e401b3e5987653e738f8ddb1c89b8a4cfd23c10ef15b8d05ade0946085141e" and
			$checkout_sha ==
			"d20bcf58b751be256e3b96fe14df4b5dc901e6eb" and
			$input_set_sha256 ==
			"709db8acaac4f743a53faaa3b724bc2c5d8ce6e878ceebf26d5578a2d4ea5c9d" and
			$engine_sha256 ==
			"0af19653d76b10921d1ed9bfa8de7e9c821a2caf403f768d72d0ca39fd47f05b"),
		capture_partition: ($feature_capture_id ==
			"b3e0f10ecb7744691ab4575a5ed20611aaa4463f0f50f0ab50a494c31323f6d5" and
			$native_capture_id ==
			"7650bf849dffa490fba252c7f30fd5eccad999e11e6b68f22318fe8626a123e6"),
		corpus_identity: ($feature_corpus_sha256 ==
			"ac0809fe2cb527df8c74ac26b0dbc0eef0910bb81fb4a6125fbd23df922b490a" and
			$empty_corpus_sha256 ==
			"fafa998fddca581e4499a4dbd70d9fccda30b5a1fa5637a7126d1149e321e377" and
			$native_corpus_sha256 ==
			"7d53372219823f61db86e4cc5c8922522e5cd2f98c04ddc092246784b5ad3731" and
			($feature_ids | length) == 10 and
			($native_ids | length) == 32 and
			(($feature_ids + $native_ids) | length) == 42 and
			(($feature_ids + $native_ids) | unique | length) == 42),
		request_orders: ($ffs.request_order == $feature_ids and
			$frs.request_order == ($feature_ids | reverse) and
			$nfs.request_order == $native_ids and
			$nrs.request_order == ($native_ids | reverse)),
		start_settings: (
			start_ok($feature_forward; "forward"; $feature_ids; 10; 0;
				$runtime_manifest_sha256) and
			start_ok($feature_reverse; "reverse"; ($feature_ids | reverse); 10; 0;
				$runtime_manifest_sha256) and
			start_ok($native_forward; "forward"; $native_ids; 0; 32;
				$runtime_manifest_sha256) and
			start_ok($native_reverse; "reverse"; ($native_ids | reverse); 0; 32;
				$runtime_manifest_sha256)),
		in_process_identity: ([
			$ffs | {engine, lua_runtime}, $frs | {engine, lua_runtime},
			$nfs | {engine, lua_runtime}, $nrs | {engine, lua_runtime}]
			| all(.[]; (.engine | type) == "object" and
				(.engine.project | type) == "string" and .engine.project != "" and
				(.engine.string | type) == "string" and .engine.string != "" and
				(.lua_runtime | type) == "string" and .lua_runtime != "") and
			(unique | length) == 1),
		emerge_actions: (emerge_ok($feature_forward; $feature_ids) and
			emerge_ok($feature_reverse; ($feature_ids | reverse)) and
			emerge_ok($native_forward; $native_ids) and
			emerge_ok($native_reverse; ($native_ids | reverse)) and
			event_errors($feature_forward) == 0 and
			event_errors($feature_reverse) == 0 and
			event_errors($native_forward) == 0 and
			event_errors($native_reverse) == 0),
		complete_events: (complete_ok($feature_forward; 10; 10; 0) and
			complete_ok($feature_reverse; 10; 10; 0) and
			complete_ok($native_forward; 32; 0; 7) and
			complete_ok($native_reverse; 32; 0; 7)),
		clean_shutdown: (shutdown_ok($feature_forward; 10; 10) and
			shutdown_ok($feature_reverse; 10; 10) and
			shutdown_ok($native_forward; 32; 7) and
			shutdown_ok($native_reverse; 32; 7)),
		feature_event_population: (($feature_forward | length) == 23 and
			($feature_reverse | length) == 23 and
			(selected($feature_forward; "case") | length) == 10 and
			(selected($feature_reverse; "case") | length) == 10 and
			(selected($feature_forward; "native_census") | length) == 0 and
			(selected($feature_reverse; "native_census") | length) == 0),
		native_event_population: (($native_forward | length) == 42 and
			($native_reverse | length) == 42 and
			(selected($native_forward; "case") | length) == 0 and
			(selected($native_reverse; "case") | length) == 0 and
			(selected($native_forward; "native_census") | length) == 7 and
			(selected($native_reverse; "native_census") | length) == 7),
		feature_snapshots_equal: ($ffc == $frc and ($ffc | length) == 10 and
			([$ffc[].id] | sort) == ($feature_ids | sort) and
			([$frc[].id] | sort) == ($feature_ids | sort) and
			all($ffc[]; .semantic_ok == true) and
			all($frc[]; .semantic_ok == true)),
		native_census_equal: ($nfn == $nrn and ($nfn | length) == 7 and
			([$nfn[].id] | sort) == (($native_ids[25:32]) | sort) and
			([$nrn[].id] | sort) == (($native_ids[25:32]) | sort) and
			all($nfn[]; .semantic_ok == true) and
			all($nrn[]; .semantic_ok == true)),
		feature_native_gate: (feature_native_gate_ok($feature_forward) and
			feature_native_gate_ok($feature_reverse)),
		native_gate_internal: (native_gate_internal_ok($nfg) and
			native_gate_internal_ok($nrg) and
			$nfg.required == true and $nrg.required == true),
		native_summary_equal: (native_gate_summary($nfg) ==
			native_gate_summary($nrg)),
		native_detail_variance_disclosed: ($nfg != $nrg and
			$old_native.native_gate_equal == false),
		dungeon_policy: ($dungeon_status == "not_observed" or
			$dungeon_status == "observed_and_preserved"),
		original_failure_preserved: (original_pair_ok($old_feature) and
			$old_native.equal == true and $old_native.semantic_ok == true and
			$old_native.native_census_equal == true and
			$old_native.native_gate_equal == false and
			$old_native.forward_native_gate == false and
			$old_native.reverse_native_gate == false and
			$old_native.start_seed_equal == true and
			$old_native.start_engine_equal == true and
			$old_native.request_orders_reversed == true and
			$old_native.forward_start == true and
			$old_native.reverse_start == true and
			$old_native.forward_complete == true and
			$old_native.reverse_complete == true and
			$old_native.forward_clean_shutdown == true and
			$old_native.reverse_clean_shutdown == true and
			$old_native.forward_emerge_errors == 0 and
			$old_native.reverse_emerge_errors == 0),
		feature_manifest: ($fm.schema == "grug_wp40_r8_headless_smoke_v3" and
			$fm.status == "final_feature_smoke_complete" and
			$fm.capture_id == $feature_capture_id and
			$fm.snapshot.checkout_sha == $checkout_sha and
			$fm.mode == "final" and $fm.shard == "feature" and
			$fm.parallel_orders == true and
			$fm.settings.mg_name == "v7" and $fm.settings.chunksize == 5 and
			$fm.settings.water_level == 1 and
			$fm.settings.num_emerge_threads == 1 and
			$fm.settings.liquid_update_seconds == 10801 and
			$fm.settings.probe_timeout_seconds == 10770 and
			$fm.settings.host_timeout_seconds == 10800 and
			$fm.settings.port_base == 32001 and
			$fm.settings.seed_decimal_string == "0" and
			$fm.settings.seed_string_sha256 ==
				"5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9" and
			$fm.corpus.digest == $feature_corpus_sha256 and
			$fm.corpus.rows == 10 and $fm.native_corpus.rows == 0 and
			$fm.native_corpus.digest == "" and
			$fm.input_identity.engine_sha256_before == $engine_sha256 and
			$fm.input_identity.engine_sha256_after == $engine_sha256 and
			$fm.input_identity.offline_r7_manifest_sha256 ==
				$offline_r7_manifest_sha256 and
			$fm.measured.forward_probe_elapsed_us ==
				(selected($feature_forward; "complete")[0].elapsed_us) and
			$fm.measured.reverse_probe_elapsed_us ==
				(selected($feature_reverse; "complete")[0].elapsed_us) and
			$fm.measured.forward_engine_peak_rss_bytes ==
				event_peak_rss($feature_forward) and
			$fm.measured.reverse_engine_peak_rss_bytes ==
				event_peak_rss($feature_reverse)),
		host_telemetry: (($host_telemetry | length) == 4 and
			all($host_telemetry[];
				(.elapsed_seconds | type) == "number" and
				.elapsed_seconds > 0 and .elapsed_seconds < 10800 and
				(.maximum_rss_kib | type) == "number" and
				.maximum_rss_kib > 0 and .exit_status == 0 and
				.command_envelope == true) and
			([$host_telemetry[] | (.shard + "/" + .order)] | sort) ==
				(["feature/forward", "feature/reverse", "native/forward",
					"native/reverse"] | sort))
	},
	evidence: {
		feature_snapshot_count: ($ffc | length),
		native_census_count: ($nfn | length),
		request_count: (($feature_ids + $native_ids) | length),
		native_summary_forward: native_gate_summary($nfg),
		native_summary_reverse: native_gate_summary($nrg),
		forward_only_native_diagnostics: ($nfg.events - $nrg.events),
		reverse_only_native_diagnostics: ($nrg.events - $nfg.events),
		host_telemetry: $host_telemetry
	},
	limitations: [
		"The original capture remains a formal fail under its former policy and is not modified.",
		(if $dungeon_status == "not_observed" then
			"No dungeon notification occurred in the bounded grid, so dungeon preservation is not proven."
		else
			"Dungeon claims are limited to the bounded observed notifications and inspected rooms."
		end),
		"Native cave notification positions and nearby-air counts contain accepted diagnostic order variance.",
		"No real-engine comparison covers mutation between the feature and native shards.",
		"The GUI itinerary and fallback-engine runtime remain separate user gates."
	]
} |
.all_ok = all(.checks[]; . == true)
