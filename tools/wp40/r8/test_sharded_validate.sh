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
	startup: {
		forward: {request_order: [range(0; 10) | "feature-\(.)"],
			production: {manifest_sha256: "runtime-manifest"}},
		reverse: {request_order: ([range(0; 10) | "feature-\(.)"] | reverse),
			production: {manifest_sha256: "runtime-manifest"}}
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
	startup: {
		forward: {request_order: [range(0; 32) | "native-\(.)"],
			production: {manifest_sha256: "runtime-manifest"}},
		reverse: {request_order: ([range(0; 32) | "native-\(.)"] | reverse),
			production: {manifest_sha256: "runtime-manifest"}}
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

echo "WP40 R8 sharded aggregate fixture: PASS"
