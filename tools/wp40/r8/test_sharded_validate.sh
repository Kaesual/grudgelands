#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
filter="$script_dir/sharded_validate.jq"
checkout_sha=1111111111111111111111111111111111111111
seed=0
engine_digest=2222222222222222222222222222222222222222222222222222222222222222
feature_corpus_digest=3333333333333333333333333333333333333333333333333333333333333333
empty_corpus_digest=4444444444444444444444444444444444444444444444444444444444444444
native_corpus_digest=5555555555555555555555555555555555555555555555555555555555555555
expected_request_ids="$(jq -n '[range(0; 10) | "feature-\(.)"] +
	[range(0; 32) | "native-\(.)"] | sort')"

feature_manifest="$(jq -n --arg sha "$checkout_sha" \
	--arg engine "$engine_digest" --arg feature_digest "$feature_corpus_digest" '[{
	schema: "grug_wp40_r8_headless_smoke_v3", mode: "final",
	status: "final_feature_smoke_complete",
	shard: "feature", parallel_orders: true, capture_id: "feature-capture",
	corpus: {rows: 10, digest: $feature_digest},
	native_corpus: {rows: 0, digest: ""},
	snapshot: {checkout_sha: $sha},
	settings: {seed_decimal_string: "0", seed_string_sha256: "seed-hash",
		probe_timeout_seconds: 10770, host_timeout_seconds: 10800,
		liquid_update_seconds: 10801, port_base: 32001},
	input_identity: {engine_sha256_before: $engine,
		engine_sha256_after: $engine,
		offline_r7_manifest_sha256: "offline-r7-manifest"},
	measured: {forward_probe_elapsed_us: 100,
		reverse_probe_elapsed_us: 101,
		forward_engine_peak_rss_bytes: 1000,
		reverse_engine_peak_rss_bytes: 1001},
	startup: {
		forward: {engine: {project: "Luanti", string: "5.16.0"},
			lua_runtime: "LuaJIT 2.1",
			request_order: [range(0; 10) | "feature-\(.)"],
			production: {manifest_sha256:
				"6666666666666666666666666666666666666666666666666666666666666666"}},
		reverse: {engine: {project: "Luanti", string: "5.16.0"},
			lua_runtime: "LuaJIT 2.1",
			request_order: ([range(0; 10) | "feature-\(.)"] | reverse),
			production: {manifest_sha256:
				"6666666666666666666666666666666666666666666666666666666666666666"}}
	}
}]')"
native_manifest="$(jq -n --arg sha "$checkout_sha" \
	--arg engine "$engine_digest" --arg empty_digest "$empty_corpus_digest" \
	--arg native_digest "$native_corpus_digest" '[{
	schema: "grug_wp40_r8_headless_smoke_v3", mode: "final",
	status: "final_native_smoke_complete",
	shard: "native", parallel_orders: true, capture_id: "native-capture",
	corpus: {rows: 0, digest: $empty_digest},
	native_corpus: {rows: 32, digest: $native_digest},
	snapshot: {checkout_sha: $sha},
	settings: {seed_decimal_string: "0", seed_string_sha256: "seed-hash",
		probe_timeout_seconds: 10770, host_timeout_seconds: 10800,
		liquid_update_seconds: 10801, port_base: 32003},
	input_identity: {engine_sha256_before: $engine,
		engine_sha256_after: $engine,
		offline_r7_manifest_sha256: "offline-r7-manifest"},
	measured: {forward_probe_elapsed_us: 200,
		reverse_probe_elapsed_us: 201,
		forward_engine_peak_rss_bytes: 2000,
		reverse_engine_peak_rss_bytes: 2001},
	startup: {
		forward: {engine: {project: "Luanti", string: "5.16.0"},
			lua_runtime: "LuaJIT 2.1",
			request_order: [range(0; 32) | "native-\(.)"],
			production: {manifest_sha256:
				"6666666666666666666666666666666666666666666666666666666666666666"}},
		reverse: {engine: {project: "Luanti", string: "5.16.0"},
			lua_runtime: "LuaJIT 2.1",
			request_order: ([range(0; 32) | "native-\(.)"] | reverse),
			production: {manifest_sha256:
				"6666666666666666666666666666666666666666666666666666666666666666"}}
	}
}]')"
feature_comparison="$(jq -n '[{
	schema: "grug_wp40_r8_order_comparison_v2",
	shard: "feature", equal: true, semantic_ok: true,
	native_census_equal: true, native_gate_equal: true,
	start_seed_equal: true, forward_native_gate: true,
	reverse_native_gate: true, forward_native_required: true,
	reverse_native_required: true, start_engine_equal: true,
	request_orders_reversed: true, forward_start: true,
	reverse_start: true, forward_complete: true, reverse_complete: true,
	forward_clean_shutdown: true, reverse_clean_shutdown: true,
	forward_emerge_errors: 0, reverse_emerge_errors: 0
}]')"
native_comparison="$(jq -n --argjson source "$feature_comparison" \
	'$source | .[0].shard = "native"')"

validate() {
	local feature_value="$1"
	local native_value="$2"
	local feature_comparison_value="$3"
	local native_comparison_value="$4"
	jq -n --arg checkout_sha "$checkout_sha" --arg seed "$seed" \
		--arg engine_digest "$engine_digest" \
		--arg final_engine_digest "$engine_digest" \
		--arg feature_corpus_digest "$feature_corpus_digest" \
		--arg empty_corpus_digest "$empty_corpus_digest" \
		--arg native_corpus_digest "$native_corpus_digest" \
		--argjson expected_request_ids "$expected_request_ids" \
		--argjson feature_manifest "$feature_value" \
		--argjson native_manifest "$native_value" \
		--argjson feature_comparison "$feature_comparison_value" \
		--argjson native_comparison "$native_comparison_value" \
		-f "$filter"
}

validate "$feature_manifest" "$native_manifest" "$feature_comparison" \
	"$native_comparison" | jq -e '.all_ok == true' >/dev/null

duplicate_native="$(jq '.[0].startup.forward.request_order[0] = "feature-0"' \
	<<<"$native_manifest")"
validate "$feature_manifest" "$duplicate_native" "$feature_comparison" \
	"$native_comparison" | jq -e '.all_ok == false and
	.checks.complete_union == false' >/dev/null

failed_pair="$(jq '.[0].equal = false' <<<"$native_comparison")"
validate "$feature_manifest" "$native_manifest" "$feature_comparison" \
	"$failed_pair" | jq -e '.all_ok == false and
	.checks.native_pair == false' >/dev/null

changed_engine="$(jq '.[0].input_identity.engine_sha256_after = "changed"' \
	<<<"$native_manifest")"
validate "$feature_manifest" "$changed_engine" "$feature_comparison" \
	"$native_comparison" | jq -e '.all_ok == false and
	.checks.engine_identity == false' >/dev/null

changed_timeout="$(jq '.[0].settings.host_timeout_seconds = 7200' \
	<<<"$native_manifest")"
validate "$feature_manifest" "$changed_timeout" "$feature_comparison" \
	"$native_comparison" | jq -e '.all_ok == false and
	.checks.time_boundaries == false' >/dev/null

changed_corpus="$(jq '.[0].native_corpus.digest = "changed"' \
	<<<"$native_manifest")"
validate "$feature_manifest" "$changed_corpus" "$feature_comparison" \
	"$native_comparison" | jq -e '.all_ok == false and
	.checks.corpus_identity == false' >/dev/null

serial_feature="$(jq '.[0].parallel_orders = false' <<<"$feature_manifest")"
validate "$serial_feature" "$native_manifest" "$feature_comparison" \
	"$native_comparison" | jq -e '.all_ok == false and
	.checks.shard_identity == false' >/dev/null

changed_offline_r7="$(jq \
	'.[0].input_identity.offline_r7_manifest_sha256 = "changed"' \
	<<<"$native_manifest")"
validate "$feature_manifest" "$changed_offline_r7" "$feature_comparison" \
	"$native_comparison" | jq -e '.all_ok == false and
	.checks.offline_r7_identity == false' >/dev/null

changed_runtime="$(jq \
	'.[0].startup.reverse.lua_runtime = "PUC Lua 5.1"' <<<"$native_manifest")"
validate "$feature_manifest" "$changed_runtime" "$feature_comparison" \
	"$native_comparison" | jq -e '.all_ok == false and
	.checks.in_process_runtime_identity == false' >/dev/null

changed_in_process_engine="$(jq \
	'.[0].startup.forward.engine.string = "5.99.0"' <<<"$native_manifest")"
validate "$feature_manifest" "$changed_in_process_engine" \
	"$feature_comparison" "$native_comparison" | jq -e '.all_ok == false and
	.checks.in_process_runtime_identity == false' >/dev/null

missing_runtime_manifest="$(jq \
	'.[0].startup.forward.production.manifest_sha256 = null' \
	<<<"$native_manifest")"
validate "$feature_manifest" "$missing_runtime_manifest" \
	"$feature_comparison" "$native_comparison" | jq -e '.all_ok == false and
	.checks.runtime_manifest_identity == false' >/dev/null

substituted_ids="$(jq '
	.[0].startup.forward.request_order =
		[range(0; 10) | "substitute-\(.)"] |
	.[0].startup.reverse.request_order =
		([range(0; 10) | "substitute-\(.)"] | reverse)' \
	<<<"$feature_manifest")"
validate "$substituted_ids" "$native_manifest" "$feature_comparison" \
	"$native_comparison" | jq -e '.all_ok == false and
	.checks.complete_union == true and .checks.exact_corpus_ids == false' \
	>/dev/null

missing_telemetry="$(jq '.[0].measured.forward_probe_elapsed_us = null' \
	<<<"$native_manifest")"
validate "$feature_manifest" "$missing_telemetry" "$feature_comparison" \
	"$native_comparison" | jq -e '.all_ok == false and
	.checks.telemetry == false' >/dev/null

echo "WP40 R8 sharded aggregate fixture: PASS"
