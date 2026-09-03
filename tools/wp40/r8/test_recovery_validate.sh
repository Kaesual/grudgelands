#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
filter="$script_dir/recovery_validate.jq"
scratch="$(mktemp -d -p /tmp grudgelands-wp40-r8-recovery-fixture.XXXXXXXX)"
trap 'rm -rf -- "$scratch"' EXIT HUP INT TERM

feature_ids="$(jq -n '[range(0; 10) | "feature-\(.)"]')"
native_ids="$(jq -n '[range(0; 32) | "native-\(.)"]')"

make_feature_events() {
	local order="$1"
	local ids="$feature_ids"
	if [[ "$order" == "reverse" ]]; then ids="$(jq 'reverse' <<<"$ids")"; fi
	jq -cn --arg order "$order" --argjson ids "$ids" '
		def process: {rss_peak_bytes: 1000};
		def native_gate: {
			required: false, ok: true, dungeon_witness: true,
			cave_witness: true, cave_pairs: true, stratum_census: true,
			native_ore_census: true, events: null,
			event_counts: {cave_begin: 0, cave_end: 0, dungeon: 0,
				large_cave_begin: 0, large_cave_end: 0},
			cave_air_witness_count: 0, dungeon_preserved_room_count: 0,
			native_ore_count: 0,
			strata: {"grug_materials:abyssal_rock": 0,
				"grug_materials:basalt": 0,
				"grug_materials:emberrock": 0,
				"grug_materials:granite": 0,
				"grug_materials:slate": 0}
		};
		([{
			event: "start", order: $order, request_count: 10,
			feature_case_count: 10, native_corpus_count: 0,
			request_order: $ids, mapgen: "v7", chunksize: "5",
			water_level: "1", num_emerge_threads: "1", liquid_update: "10801",
			mapgen_flags: "caves, dungeons, light, decorations, biomes, ores",
			seed: "0", seed_sha256:
				"5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9",
			engine: {project: "Luanti", string: "5.17.0"},
			lua_runtime: "LuaJIT 2.1",
			production: {enabled: true, production_enabled: true, writer_count: 1,
				full_seed: "0", schema: "grug_wp40_r7_loader_status_v1",
				manifest_sha256:
				"dd201f3693954be7807cc52ea5840486a357ae57ba62b565ff11e0bab5d58989"},
			process: process
		}] +
		[$ids[] | {event: "emerge", id: ., emerge_us: 1,
			actions: {generated: 1, memory: 124}, process: process}] +
		[$ids[] | {event: "case", id: ., mapchunk: ., central_min: {},
			central_max: {}, content_sha256: ("content-" + .),
			param2_sha256: ("param2-" + .), light_sha256: ("light-" + .),
			central_voxels: 1, node_counts: [], light_stats: {},
			semantic_checks: {}, semantic_evidence: {}, semantic_ok: true,
			process: process}] +
		[{event: "complete", request_count: 10, emerged_case_count: 10,
			generated_callback_count: 10, feature_case_count: 10,
			native_census_case_count: 0, snapshot_count: 10,
			elapsed_us: 100, process: process, native_gate: native_gate},
		 {event: "shutdown", clean: true, emerged_cases: 10,
			snapshotted_cases: 10, process: process}])[]'
}

make_native_events() {
	local order="$1"
	local air_count="$2"
	local ids="$native_ids"
	if [[ "$order" == "reverse" ]]; then ids="$(jq 'reverse' <<<"$ids")"; fi
	jq -cn --arg order "$order" --argjson ids "$ids" \
		--argjson air_count "$air_count" '
		def process: {rss_peak_bytes: 2000};
		def strata: {"grug_materials:abyssal_rock": 1,
			"grug_materials:basalt": 2, "grug_materials:emberrock": 3,
			"grug_materials:granite": 4, "grug_materials:slate": 5};
		def events: [
			{kind: "large_cave_begin", position: {x: 1, y: -200, z: 1},
				source_mapchunk: "0,-272,0", inside_source: true,
				nearby_air_count: $air_count, preserved_cave_air: true},
			{kind: "large_cave_end", position: {x: $air_count, y: -200, z: 2},
				source_mapchunk: "0,-272,0", inside_source: true}
		];
		def native_gate: {
			required: true, ok: false, dungeon_witness: false,
			cave_witness: true, cave_pairs: true, stratum_census: true,
			native_ore_census: true, events: events,
			event_counts: {cave_begin: 0, cave_end: 0, dungeon: 0,
				large_cave_begin: 1, large_cave_end: 1},
			cave_air_witness_count: 1, dungeon_preserved_room_count: 0,
			native_ore_count: 9, strata: strata
		};
		([{
			event: "start", order: $order, request_count: 32,
			feature_case_count: 0, native_corpus_count: 32,
			request_order: $ids, mapgen: "v7", chunksize: "5",
			water_level: "1", num_emerge_threads: "1", liquid_update: "10801",
			mapgen_flags: "caves, dungeons, light, decorations, biomes, ores",
			seed: "0", seed_sha256:
				"5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9",
			engine: {project: "Luanti", string: "5.17.0"},
			lua_runtime: "LuaJIT 2.1",
			production: {enabled: true, production_enabled: true, writer_count: 1,
				full_seed: "0", schema: "grug_wp40_r7_loader_status_v1",
				manifest_sha256:
				"dd201f3693954be7807cc52ea5840486a357ae57ba62b565ff11e0bab5d58989"},
			process: process
		}] +
		[$ids[] | {event: "emerge", id: ., emerge_us: 1,
			actions: {generated: 1, memory: 124}, process: process}] +
		[range(25; 32) as $i | {event: "native_census",
			id: ("native-" + ($i | tostring)), mapchunk: ($i | tostring),
			central_min: {}, central_max: {}, content_sha256: ("census-" +
				($i | tostring)), central_voxels: 1, node_counts: [],
			native_census: {}, semantic_checks: {}, semantic_ok: true,
			process: process}] +
		[{event: "complete", request_count: 32, emerged_case_count: 32,
			generated_callback_count: 32, feature_case_count: 0,
			native_census_case_count: 7, snapshot_count: 7,
			elapsed_us: 200, process: process, native_gate: native_gate},
		 {event: "shutdown", clean: true, emerged_cases: 32,
			snapshotted_cases: 7, process: process}])[]'
}

make_feature_events forward >"$scratch/feature-forward.jsonl"
make_feature_events reverse >"$scratch/feature-reverse.jsonl"
make_native_events forward 4 >"$scratch/native-forward.jsonl"
make_native_events reverse 5 >"$scratch/native-reverse.jsonl"

jq -n '{
	schema: "grug_wp40_r8_order_comparison_v2", shard: "feature",
	equal: true, semantic_ok: true, native_census_equal: true,
	native_gate_equal: true, start_seed_equal: true,
	forward_native_gate: true, reverse_native_gate: true,
	forward_native_required: true, reverse_native_required: true,
	start_engine_equal: true, request_orders_reversed: true,
	forward_start: true, reverse_start: true,
	forward_complete: true, reverse_complete: true,
	forward_clean_shutdown: true, reverse_clean_shutdown: true,
	forward_emerge_errors: 0, reverse_emerge_errors: 0
}' >"$scratch/feature-comparison.json"
jq '.shard = "native" | .native_gate_equal = false |
	.forward_native_gate = false | .reverse_native_gate = false
' "$scratch/feature-comparison.json" >"$scratch/native-comparison.json"

jq -n --argjson feature_ids "$feature_ids" '{
	schema: "grug_wp40_r8_headless_smoke_v3",
	status: "final_feature_smoke_complete",
	capture_id:
		"b3e0f10ecb7744691ab4575a5ed20611aaa4463f0f50f0ab50a494c31323f6d5",
	mode: "final", shard: "feature", parallel_orders: true,
	snapshot: {checkout_sha:
		"d20bcf58b751be256e3b96fe14df4b5dc901e6eb"},
	settings: {mg_name: "v7", chunksize: 5, water_level: 1,
		num_emerge_threads: 1, liquid_update_seconds: 10801,
		probe_timeout_seconds: 10770, host_timeout_seconds: 10800,
		port_base: 32001, seed_decimal_string: "0"},
	corpus: {digest:
		"ac0809fe2cb527df8c74ac26b0dbc0eef0910bb81fb4a6125fbd23df922b490a",
		rows: 10},
	native_corpus: {rows: 0},
	input_identity: {engine_sha256_before:
		"0af19653d76b10921d1ed9bfa8de7e9c821a2caf403f768d72d0ca39fd47f05b",
		engine_sha256_after:
		"0af19653d76b10921d1ed9bfa8de7e9c821a2caf403f768d72d0ca39fd47f05b",
		offline_r7_manifest_sha256:
		"72511fd4b73f824856d41ab921a83a19a82ea9867d2ea203d4c6d6b1eafea6a1"},
	measured: {forward_probe_elapsed_us: 100, reverse_probe_elapsed_us: 100,
		forward_engine_peak_rss_bytes: 1000,
		reverse_engine_peak_rss_bytes: 1000}
}' >"$scratch/feature-manifest.json"

host_telemetry='[
	{"shard":"feature","order":"forward","elapsed_seconds":1,
	 "maximum_rss_kib":1,"exit_status":0,"command_envelope":true},
	{"shard":"feature","order":"reverse","elapsed_seconds":1,
	 "maximum_rss_kib":1,"exit_status":0,"command_envelope":true},
	{"shard":"native","order":"forward","elapsed_seconds":2,
	 "maximum_rss_kib":2,"exit_status":0,"command_envelope":true},
	{"shard":"native","order":"reverse","elapsed_seconds":2,
	 "maximum_rss_kib":2,"exit_status":0,"command_envelope":true}
]'
file_checks='{"source_tree":true,"raw_hashes":true}'

validate() {
	local feature_forward="$1"
	local feature_reverse="$2"
	local native_forward="$3"
	local native_reverse="$4"
	local telemetry="$5"
	local checks="$6"
	jq -n \
		--arg source_capture_id \
			47be3ce009a333423b161b17e53bd4e24645f07ca0910314b1f249aa63b9b9ae \
		--arg source_tree_sha256 \
			a6e401b3e5987653e738f8ddb1c89b8a4cfd23c10ef15b8d05ade0946085141e \
		--arg checkout_sha d20bcf58b751be256e3b96fe14df4b5dc901e6eb \
		--arg feature_capture_id \
			b3e0f10ecb7744691ab4575a5ed20611aaa4463f0f50f0ab50a494c31323f6d5 \
		--arg native_capture_id \
			7650bf849dffa490fba252c7f30fd5eccad999e11e6b68f22318fe8626a123e6 \
		--arg engine_sha256 \
			0af19653d76b10921d1ed9bfa8de7e9c821a2caf403f768d72d0ca39fd47f05b \
		--arg input_set_sha256 \
			709db8acaac4f743a53faaa3b724bc2c5d8ce6e878ceebf26d5578a2d4ea5c9d \
		--arg runtime_manifest_sha256 \
			dd201f3693954be7807cc52ea5840486a357ae57ba62b565ff11e0bab5d58989 \
		--arg offline_r7_manifest_sha256 \
			72511fd4b73f824856d41ab921a83a19a82ea9867d2ea203d4c6d6b1eafea6a1 \
		--arg feature_corpus_sha256 \
			ac0809fe2cb527df8c74ac26b0dbc0eef0910bb81fb4a6125fbd23df922b490a \
		--arg empty_corpus_sha256 \
			fafa998fddca581e4499a4dbd70d9fccda30b5a1fa5637a7126d1149e321e377 \
		--arg native_corpus_sha256 \
			7d53372219823f61db86e4cc5c8922522e5cd2f98c04ddc092246784b5ad3731 \
		--argjson feature_ids "$feature_ids" --argjson native_ids "$native_ids" \
		--argjson file_checks "$checks" --argjson host_telemetry "$telemetry" \
		--slurpfile feature_manifest "$scratch/feature-manifest.json" \
		--slurpfile feature_comparison "$scratch/feature-comparison.json" \
		--slurpfile native_comparison "$scratch/native-comparison.json" \
		--slurpfile feature_forward "$feature_forward" \
		--slurpfile feature_reverse "$feature_reverse" \
		--slurpfile native_forward "$native_forward" \
		--slurpfile native_reverse "$native_reverse" \
		-f "$filter"
}

baseline="$(validate "$scratch/feature-forward.jsonl" \
	"$scratch/feature-reverse.jsonl" "$scratch/native-forward.jsonl" \
	"$scratch/native-reverse.jsonl" "$host_telemetry" "$file_checks")"
jq -e '.all_ok == true and .policy.dungeon_status == "not_observed" and
	.checks.native_detail_variance_disclosed == true and
	.checks.native_summary_equal == true' <<<"$baseline" >/dev/null

jq 'if .event == "complete" then
	.native_gate.events += [{kind:"dungeon", position:{x:0,y:-200,z:0},
		source_mapchunk:"0,-272,0", inside_source:true, node:"air",
		below:"default:cobble", preserved_room:true}] |
	.native_gate.event_counts.dungeon = 1 |
	.native_gate.dungeon_preserved_room_count = 1 |
	.native_gate.dungeon_witness = true | .native_gate.ok = true
	else . end' "$scratch/native-reverse.jsonl" \
	>"$scratch/native-reverse-one-sided.jsonl"
one_sided="$(validate "$scratch/feature-forward.jsonl" \
	"$scratch/feature-reverse.jsonl" "$scratch/native-forward.jsonl" \
	"$scratch/native-reverse-one-sided.jsonl" "$host_telemetry" "$file_checks")"
jq -e '.all_ok == false and .checks.dungeon_policy == false and
	.policy.dungeon_status == "blocking_mismatch_or_unpreserved"' \
	<<<"$one_sided" >/dev/null

for direction in forward reverse; do
	jq 'if .event == "complete" then
		.native_gate.events += [{kind:"dungeon", position:{x:0,y:-200,z:0},
			source_mapchunk:"0,-272,0", inside_source:true, node:"air",
			below:"default:cobble", preserved_room:true}] |
		.native_gate.event_counts.dungeon = 1 |
		.native_gate.dungeon_preserved_room_count = 1 |
		.native_gate.dungeon_witness = true | .native_gate.ok = true
		else . end' "$scratch/native-$direction.jsonl" \
		>"$scratch/native-$direction-observed.jsonl"
done
observed="$(validate "$scratch/feature-forward.jsonl" \
	"$scratch/feature-reverse.jsonl" "$scratch/native-forward-observed.jsonl" \
	"$scratch/native-reverse-observed.jsonl" "$host_telemetry" "$file_checks")"
jq -e '.all_ok == true and
	.policy.dungeon_status == "observed_and_preserved"' \
	<<<"$observed" >/dev/null

jq 'if .event == "complete" then
	.native_gate.events[-1].below = "default:stone" |
	.native_gate.events[-1].preserved_room = false |
	.native_gate.dungeon_preserved_room_count = 0 |
	.native_gate.dungeon_witness = false | .native_gate.ok = false
	else . end' "$scratch/native-reverse-observed.jsonl" \
	>"$scratch/native-reverse-unpreserved.jsonl"
unpreserved="$(validate "$scratch/feature-forward.jsonl" \
	"$scratch/feature-reverse.jsonl" "$scratch/native-forward-observed.jsonl" \
	"$scratch/native-reverse-unpreserved.jsonl" "$host_telemetry" "$file_checks")"
jq -e '.all_ok == false and .checks.dungeon_policy == false and
	.policy.dungeon_status == "blocking_mismatch_or_unpreserved"' \
	<<<"$unpreserved" >/dev/null

jq 'if .event == "complete" then
	.native_gate.events[0].nearby_air_count = 0 |
	.native_gate.events[0].preserved_cave_air = false |
	.native_gate.cave_air_witness_count = 0
	else . end' "$scratch/native-forward.jsonl" \
	>"$scratch/native-forward-no-cave.jsonl"
no_cave="$(validate "$scratch/feature-forward.jsonl" \
	"$scratch/feature-reverse.jsonl" "$scratch/native-forward-no-cave.jsonl" \
	"$scratch/native-reverse.jsonl" "$host_telemetry" "$file_checks")"
jq -e '.all_ok == false and .checks.native_gate_internal == false' \
	<<<"$no_cave" >/dev/null

jq 'if .event == "case" and .id == "feature-0" then
	.content_sha256 = "changed" else . end' "$scratch/feature-reverse.jsonl" \
	>"$scratch/feature-reverse-changed.jsonl"
changed_snapshot="$(validate "$scratch/feature-forward.jsonl" \
	"$scratch/feature-reverse-changed.jsonl" "$scratch/native-forward.jsonl" \
	"$scratch/native-reverse.jsonl" "$host_telemetry" "$file_checks")"
jq -e '.all_ok == false and .checks.feature_snapshots_equal == false' \
	<<<"$changed_snapshot" >/dev/null

jq 'if .event == "start" then .lua_runtime = "PUC Lua 5.1" else . end' \
	"$scratch/native-reverse.jsonl" >"$scratch/native-reverse-runtime.jsonl"
changed_runtime="$(validate "$scratch/feature-forward.jsonl" \
	"$scratch/feature-reverse.jsonl" "$scratch/native-forward.jsonl" \
	"$scratch/native-reverse-runtime.jsonl" "$host_telemetry" "$file_checks")"
jq -e '.all_ok == false and .checks.in_process_identity == false' \
	<<<"$changed_runtime" >/dev/null

bad_telemetry="$(jq '.[0].elapsed_seconds = 10800' <<<"$host_telemetry")"
telemetry_result="$(validate "$scratch/feature-forward.jsonl" \
	"$scratch/feature-reverse.jsonl" "$scratch/native-forward.jsonl" \
	"$scratch/native-reverse.jsonl" "$bad_telemetry" "$file_checks")"
jq -e '.all_ok == false and .checks.host_telemetry == false' \
	<<<"$telemetry_result" >/dev/null

bad_files="$(jq '.raw_hashes = false' <<<"$file_checks")"
file_result="$(validate "$scratch/feature-forward.jsonl" \
	"$scratch/feature-reverse.jsonl" "$scratch/native-forward.jsonl" \
	"$scratch/native-reverse.jsonl" "$host_telemetry" "$bad_files")"
jq -e '.all_ok == false and .checks.file_identity == false' \
	<<<"$file_result" >/dev/null

echo "WP40 R8 recovery validator fixture: PASS"
