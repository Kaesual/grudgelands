#!/usr/bin/env bash
set -euo pipefail

# Final G3 coordinator. It launches two independently comparable pairs:
# ten feature requests in two orders and the complete 32-row native corpus in
# two orders. The four isolated engines run concurrently; this script then
# validates and combines both pair receipts deterministically.

for command_name in awk cat flatpak git jq mktemp sha256sum sort tail tar xargs; do
	if ! command -v "$command_name" >/dev/null 2>&1; then
		echo "WP40 R8 sharded: missing command $command_name" >&2
		exit 2
	fi
done

invoked_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_input="${WP40_R8_SOURCE_REPO:-$(cd "$invoked_script_dir/../../.." && pwd)}"
repo="$(cd "$repo_input" && pwd)"
checkout_input="${WP40_CHECKOUT_SHA:-HEAD}"
checkout_sha="$(git -C "$repo" rev-parse --verify "${checkout_input}^{commit}")"
if [[ ! "$checkout_sha" =~ ^[0-9a-f]{40}$ ]]; then
	echo "WP40 R8 sharded: checkout is not a canonical commit" >&2
	exit 2
fi
timeout_seconds="${WP40_R8_TIMEOUT:-10770}"
if [[ "$timeout_seconds" != "10770" ]]; then
	echo "WP40 R8 sharded: final G3 requires WP40_R8_TIMEOUT=10770" >&2
	exit 2
fi
seed="${WP40_SEED:-0}"
if [[ "$seed" != "0" ]]; then
	echo "WP40 R8 sharded: final G3 requires the reviewed Seed-0 candidate" >&2
	exit 2
fi

required_paths=(
	tools/wp40/r8/run_sharded.sh
	tools/wp40/r8/run.sh
	tools/wp40/r8/probe/init.lua
	tools/wp40/r8/probe/mod.conf
	tools/wp40/r8/seed-candidates.tsv
	tools/wp40/r8/pilot-corpus.tsv
	tools/wp40/r8/smoke-corpus.tsv
	tools/wp40/r8/empty-feature-corpus.tsv
	tools/wp40/r8/native-pilot-corpus.tsv
	tools/wp40/r8/native-witness-corpus.tsv
	tools/wp40/r8/sharded_validate.jq
	tools/wp40/r8/test_sharded_validate.sh
)
for relative_path in "${required_paths[@]}"; do
	if ! git -C "$repo" cat-file -e "$checkout_sha:$relative_path"; then
		echo "WP40 R8 sharded: selected commit lacks $relative_path" >&2
		exit 2
	fi
	if ! git -C "$repo" diff --quiet "$checkout_sha" -- "$relative_path"; then
		echo "WP40 R8 sharded: $relative_path differs from selected commit" >&2
		exit 2
	fi
done

# Re-execute from an exact commit-derived tree before creating any evidence.
# This prevents an editor from changing a later-read shell/JQ/corpus byte while
# a multi-hour capture is in flight. The inner process copies the same tree
# into the immutable result before starting its workers.
frozen_root="${WP40_R8_FROZEN_ROOT:-}"
if [[ -z "$frozen_root" ]]; then
	frozen_root="$(mktemp -d -p /tmp grudgelands-wp40-r8-input.XXXXXXXX)"
	if ! git -C "$repo" archive "$checkout_sha" -- "${required_paths[@]}" |
			tar -x -C "$frozen_root"; then
		rm -rf -- "$frozen_root"
		exit 2
	fi
	exec env WP40_R8_FROZEN_ROOT="$frozen_root" \
		WP40_R8_SOURCE_REPO="$repo" WP40_CHECKOUT_SHA="$checkout_sha" \
		bash "$frozen_root/tools/wp40/r8/run_sharded.sh"
fi
frozen_root="$(cd "$frozen_root" && pwd)"
cleanup_frozen_root() {
	if [[ "$frozen_root" == /tmp/grudgelands-wp40-r8-input.* ]]; then
		rm -rf -- "$frozen_root"
	fi
}
trap cleanup_frozen_root EXIT
script_dir="$frozen_root/tools/wp40/r8"
for relative_path in "${required_paths[@]}"; do
	expected_blob="$(git -C "$repo" rev-parse "$checkout_sha:$relative_path")"
	actual_blob="$(git -C "$repo" hash-object "$frozen_root/$relative_path")"
	if [[ "$actual_blob" != "$expected_blob" ]]; then
		echo "WP40 R8 sharded: frozen $relative_path differs from selected commit" >&2
		exit 2
	fi
done
if [[ ! -x "$script_dir/run_sharded.sh" || ! -x "$script_dir/run.sh" ||
		! -x "$script_dir/test_sharded_validate.sh" ]]; then
	echo "WP40 R8 sharded: committed runner/test modes must be executable" >&2
	exit 2
fi

feature_rows="$(awk 'NF && $1 !~ /^#/ {count++} END {print count + 0}' \
	"$script_dir/smoke-corpus.tsv")"
empty_rows="$(awk 'NF && $1 !~ /^#/ {count++} END {print count + 0}' \
	"$script_dir/empty-feature-corpus.tsv")"
native_rows="$(awk 'NF && $1 !~ /^#/ {count++} END {print count + 0}' \
	"$script_dir/native-witness-corpus.tsv")"
if [[ "$feature_rows" != "10" || "$empty_rows" != "0" || "$native_rows" != "32" ]]; then
	echo "WP40 R8 sharded: frozen shard row counts differ from 10+0+32" >&2
	exit 2
fi
expected_request_ids="$({
	awk 'NF && $1 !~ /^#/ {print $1}' "$script_dir/smoke-corpus.tsv"
	awk 'NF && $1 !~ /^#/ {print $1}' "$script_dir/native-witness-corpus.tsv"
} | jq -Rsc 'split("\n") | map(select(length > 0)) | sort')"
if ! jq -en --argjson ids "$expected_request_ids" \
	'$ids | length == 42 and (unique | length) == 42' >/dev/null; then
	echo "WP40 R8 sharded: frozen corpora do not contain 42 unique IDs" >&2
	exit 2
fi
feature_corpus_digest="$(sha256sum "$script_dir/smoke-corpus.tsv" | awk '{print $1}')"
empty_corpus_digest="$(sha256sum "$script_dir/empty-feature-corpus.tsv" | awk '{print $1}')"
native_corpus_digest="$(sha256sum "$script_dir/native-witness-corpus.tsv" | awk '{print $1}')"

flatpak_info_text="$(flatpak info org.luanti.luanti)"
flatpak_version_text="$(flatpak run --command=luanti \
	org.luanti.luanti --version)"
engine_digest="$({
	printf '%s\n' "$flatpak_info_text"
	printf '%s\n' "$flatpak_version_text"
} | sha256sum | awk '{print $1}')"
input_digest="$({
	for relative_path in "${required_paths[@]}"; do
		sha256sum "$frozen_root/$relative_path" | awk '{print $1}'
	done
} | sha256sum | awk '{print $1}')"
capture_id="$({
	printf '%s\n' "grug_wp40_r8_sharded_g3_v1" "$checkout_sha" "$seed" \
		"$timeout_seconds" "$engine_digest" "$input_digest"
} | sha256sum | awk '{print $1}')"

results_root="${WP40_R8_RESULTS_ROOT:-$repo/tools/wp40/results/r8}"
if [[ "$results_root" != /* ]]; then results_root="$repo/$results_root"; fi
mkdir -p "$results_root"
result_dir="$results_root/$capture_id"
if [[ -e "$result_dir" ]]; then
	echo "WP40 R8 sharded: refusing to overwrite immutable result $result_dir" >&2
	exit 2
fi
mkdir "$result_dir" "$result_dir/inputs" "$result_dir/shards"
(
	cd "$frozen_root"
	tar -cf - "${required_paths[@]}"
) | (
	cd "$result_dir/inputs"
	tar -xf -
)
evidence_root="$result_dir/inputs"
printf '%s\n' "$flatpak_info_text" >"$result_dir/flatpak-before-deployment.txt"
printf '%s\n' "$flatpak_version_text" >"$result_dir/flatpak-before-version.txt"

feature_pid=""
native_pid=""
stop_child() {
	local pid="$1"
	if [[ "$pid" =~ ^[1-9][0-9]*$ ]]; then
		kill "$pid" 2>/dev/null || true
		wait "$pid" 2>/dev/null || true
	fi
}
cleanup() {
	stop_child "$feature_pid"
	stop_child "$native_pid"
	cleanup_frozen_root
}
trap 'exit 130' HUP INT TERM
trap cleanup EXIT

env WP40_R8_MODE=final WP40_R8_SHARD=feature \
	WP40_R8_TIMEOUT="$timeout_seconds" WP40_R8_PARALLEL=1 \
	WP40_R8_PORT_BASE=32001 WP40_CHECKOUT_SHA="$checkout_sha" \
	WP40_R8_FROZEN_ROOT="$evidence_root" WP40_R8_SOURCE_REPO="$repo" \
	WP40_SEED="$seed" WP40_R8_RESULTS_ROOT="$result_dir/shards" \
	WP40_R8_CORPUS="$evidence_root/tools/wp40/r8/smoke-corpus.tsv" \
	WP40_R8_NATIVE_CORPUS= \
	bash "$evidence_root/tools/wp40/r8/run.sh" \
	>"$result_dir/feature-runner.stdout.partial" \
	2>"$result_dir/feature-runner.stderr.partial" &
feature_pid=$!
env WP40_R8_MODE=final WP40_R8_SHARD=native \
	WP40_R8_TIMEOUT="$timeout_seconds" WP40_R8_PARALLEL=1 \
	WP40_R8_PORT_BASE=32003 WP40_CHECKOUT_SHA="$checkout_sha" \
	WP40_R8_FROZEN_ROOT="$evidence_root" WP40_R8_SOURCE_REPO="$repo" \
	WP40_SEED="$seed" WP40_R8_RESULTS_ROOT="$result_dir/shards" \
	WP40_R8_CORPUS="$evidence_root/tools/wp40/r8/empty-feature-corpus.tsv" \
	WP40_R8_NATIVE_CORPUS="$evidence_root/tools/wp40/r8/native-witness-corpus.tsv" \
	bash "$evidence_root/tools/wp40/r8/run.sh" \
	>"$result_dir/native-runner.stdout.partial" \
	2>"$result_dir/native-runner.stderr.partial" &
native_pid=$!

feature_status=0
native_status=0
wait "$feature_pid" || feature_status=$?
feature_pid=""
wait "$native_pid" || native_status=$?
native_pid=""
printf 'shard\texit_status\nfeature\t%s\nnative\t%s\n' \
	"$feature_status" "$native_status" >"$result_dir/worker-status.tsv"
for shard_name in feature native; do
	for stream in stdout stderr; do
		mv "$result_dir/$shard_name-runner.$stream.partial" \
			"$result_dir/$shard_name-runner.$stream"
	done
done
if [[ "$feature_status" != "0" || "$native_status" != "0" ]]; then
	echo "WP40 R8 sharded: one or both shard pairs failed" >&2
	exit 1
fi

feature_dir="$(tail -n 1 "$result_dir/feature-runner.stdout")"
native_dir="$(tail -n 1 "$result_dir/native-runner.stdout")"
case "$feature_dir" in "$result_dir"/shards/*) ;; *)
	echo "WP40 R8 sharded: feature worker returned an invalid path" >&2
	exit 1
esac
case "$native_dir" in "$result_dir"/shards/*) ;; *)
	echo "WP40 R8 sharded: native worker returned an invalid path" >&2
	exit 1
esac
for path in "$feature_dir/manifest.json" "$feature_dir/comparison.json" \
		"$native_dir/manifest.json" "$native_dir/comparison.json"; do
	[[ -s "$path" ]] || {
		echo "WP40 R8 sharded: missing child receipt $path" >&2
		exit 1
	}
done

flatpak info org.luanti.luanti >"$result_dir/flatpak-after-deployment.txt"
flatpak run --command=luanti org.luanti.luanti --version \
	>"$result_dir/flatpak-after-version.txt"
final_engine_digest="$({
	cat "$result_dir/flatpak-after-deployment.txt"
	cat "$result_dir/flatpak-after-version.txt"
} | sha256sum | awk '{print $1}')"

jq -n --arg checkout_sha "$checkout_sha" --arg seed "$seed" \
	--arg engine_digest "$engine_digest" \
	--arg final_engine_digest "$final_engine_digest" \
	--arg feature_corpus_digest "$feature_corpus_digest" \
	--arg empty_corpus_digest "$empty_corpus_digest" \
	--arg native_corpus_digest "$native_corpus_digest" \
	--argjson expected_request_ids "$expected_request_ids" \
	--slurpfile feature_manifest "$feature_dir/manifest.json" \
	--slurpfile feature_comparison "$feature_dir/comparison.json" \
	--slurpfile native_manifest "$native_dir/manifest.json" \
	--slurpfile native_comparison "$native_dir/comparison.json" \
	-f "$evidence_root/tools/wp40/r8/sharded_validate.jq" \
	>"$result_dir/comparison.json"

if ! jq -e '.all_ok == true' "$result_dir/comparison.json" >/dev/null; then
	echo "WP40 R8 sharded: deterministic aggregate comparison failed" >&2
	exit 1
fi

feature_manifest_json="$(cat "$feature_dir/manifest.json")"
native_manifest_json="$(cat "$native_dir/manifest.json")"
comparison_sha256="$(sha256sum "$result_dir/comparison.json" | awk '{print $1}')"
jq -n --arg capture_id "$capture_id" --arg checkout_sha "$checkout_sha" \
	--arg seed "$seed" --arg timeout "$timeout_seconds" \
	--arg engine_digest "$engine_digest" --arg input_digest "$input_digest" \
	--arg comparison_sha256 "$comparison_sha256" \
	--arg feature_corpus_digest "$feature_corpus_digest" \
	--arg empty_corpus_digest "$empty_corpus_digest" \
	--arg native_corpus_digest "$native_corpus_digest" \
	--argjson feature "$feature_manifest_json" \
	--argjson native "$native_manifest_json" '
	{
	 schema: "grug_wp40_r8_sharded_g3_v1",
	 status: "final_sharded_smoke_complete",
	 capture_id: $capture_id,
	 snapshot: {checkout_sha: $checkout_sha, source: "git archive"},
	 seed_decimal_string: $seed,
	 engine_sha256: $engine_digest,
	 input_set_sha256: $input_digest,
	 corpus_sha256: {feature: $feature_corpus_digest,
		empty_feature: $empty_corpus_digest, native: $native_corpus_digest},
	 host_timeout_seconds_per_engine: ($timeout | tonumber) + 30,
	 worker_width: 4,
	 shards: {feature: $feature, native: $native},
	 comparison_sha256: $comparison_sha256,
	 measured: {
		maximum_probe_elapsed_us: ([
			$feature.measured.forward_probe_elapsed_us,
			$feature.measured.reverse_probe_elapsed_us,
			$native.measured.forward_probe_elapsed_us,
			$native.measured.reverse_probe_elapsed_us] | max),
		conservative_summed_engine_peak_rss_bytes: (
			$feature.measured.forward_engine_peak_rss_bytes +
			$feature.measured.reverse_engine_peak_rss_bytes +
			$native.measured.forward_engine_peak_rss_bytes +
			$native.measured.reverse_engine_peak_rss_bytes)
	 },
	 limitations: [
		"This is bounded release evidence, not exhaustive world or seed coverage.",
		"Feature/native cross-shard mutation is not exercised by the real-engine pair; all within-shard later-request mutation remains covered.",
		"The 15-point GUI itinerary and fallback-engine runtime remain separate user gates."
	 ]
	}' >"$result_dir/manifest.json"

checksums_tmp="$result_dir/checksums.sha256.partial"
(
	cd "$result_dir"
	find . -type f ! -name checksums.sha256 \
		! -name checksums.sha256.partial -print0 | sort -z |
		xargs -0 sha256sum
) >"$checksums_tmp"
mv "$checksums_tmp" "$result_dir/checksums.sha256"

cleanup_frozen_root
trap - EXIT HUP INT TERM
echo "$result_dir"
