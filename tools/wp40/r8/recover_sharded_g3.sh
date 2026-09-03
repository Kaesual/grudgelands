#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Deterministically re-evaluate the retained failed-closed G3 capture under the
# approved recovery_v1 Cave/Dungeon policy. This script never starts Luanti and
# never modifies the source capture.

for command_name in awk cat cp find git jq mkdir mktemp mv readlink rg rm sed \
	sha256sum sort stat tar wc xargs; do
	if ! command -v "$command_name" >/dev/null 2>&1; then
		echo "WP40 R8 recovery: missing command $command_name" >&2
		exit 2
	fi
done

source_capture_id=47be3ce009a333423b161b17e53bd4e24645f07ca0910314b1f249aa63b9b9ae
source_tree_sha256=a6e401b3e5987653e738f8ddb1c89b8a4cfd23c10ef15b8d05ade0946085141e
source_checkout_sha=d20bcf58b751be256e3b96fe14df4b5dc901e6eb
feature_capture_id=b3e0f10ecb7744691ab4575a5ed20611aaa4463f0f50f0ab50a494c31323f6d5
native_capture_id=7650bf849dffa490fba252c7f30fd5eccad999e11e6b68f22318fe8626a123e6
engine_sha256=0af19653d76b10921d1ed9bfa8de7e9c821a2caf403f768d72d0ca39fd47f05b
input_set_sha256=709db8acaac4f743a53faaa3b724bc2c5d8ce6e878ceebf26d5578a2d4ea5c9d
runtime_manifest_sha256=dd201f3693954be7807cc52ea5840486a357ae57ba62b565ff11e0bab5d58989
offline_r7_manifest_sha256=72511fd4b73f824856d41ab921a83a19a82ea9867d2ea203d4c6d6b1eafea6a1

invoked_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_input="${WP40_R8_SOURCE_REPO:-$(cd "$invoked_script_dir/../../.." && pwd)}"
repo="$(cd "$repo_input" && pwd)"
recovery_input="${WP40_R8_RECOVERY_SHA:-HEAD}"
recovery_sha="$(git -C "$repo" rev-parse --verify "${recovery_input}^{commit}")"
if [[ ! "$recovery_sha" =~ ^[0-9a-f]{40}$ ]]; then
	echo "WP40 R8 recovery: recovery checkout is not a canonical commit" >&2
	exit 2
fi

recovery_paths=(
	tools/wp40/r8/recover_sharded_g3.sh
	tools/wp40/r8/recovery_validate.jq
	tools/wp40/r8/test_recovery_validate.sh
)
for relative_path in "${recovery_paths[@]}"; do
	if ! git -C "$repo" cat-file -e "$recovery_sha:$relative_path"; then
		echo "WP40 R8 recovery: selected commit lacks $relative_path" >&2
		exit 2
	fi
	if ! git -C "$repo" diff --quiet "$recovery_sha" -- "$relative_path"; then
		echo "WP40 R8 recovery: $relative_path differs from selected commit" >&2
		exit 2
	fi
done

# Re-execute from the reviewed commit-derived bytes. The source capture is not
# read until this transition is complete.
frozen_root="${WP40_R8_RECOVERY_FROZEN_ROOT:-}"
owned_frozen_root=""
cleanup_outer_frozen_root() {
	if [[ -n "$owned_frozen_root" &&
			"$owned_frozen_root" == /tmp/grudgelands-wp40-r8-recovery-input.* ]]; then
		rm -rf -- "$owned_frozen_root"
	fi
}
if [[ -z "$frozen_root" ]]; then
	frozen_root="$(mktemp -d -p /tmp grudgelands-wp40-r8-recovery-input.XXXXXXXX)"
	owned_frozen_root="$frozen_root"
	trap 'exit 130' HUP INT TERM
	trap cleanup_outer_frozen_root EXIT
	if ! git -C "$repo" archive "$recovery_sha" -- "${recovery_paths[@]}" |
			tar -x -C "$frozen_root"; then
		exit 2
	fi
	inner_status=0
	env WP40_R8_RECOVERY_FROZEN_ROOT="$frozen_root" \
		WP40_R8_SOURCE_REPO="$repo" WP40_R8_RECOVERY_SHA="$recovery_sha" \
		bash "$frozen_root/tools/wp40/r8/recover_sharded_g3.sh" || inner_status=$?
	exit "$inner_status"
fi
frozen_root="$(cd "$frozen_root" && pwd)"
script_dir="$frozen_root/tools/wp40/r8"
for relative_path in "${recovery_paths[@]}"; do
	expected_blob="$(git -C "$repo" rev-parse "$recovery_sha:$relative_path")"
	actual_blob="$(git -C "$repo" hash-object "$frozen_root/$relative_path")"
	expected_mode="$(git -C "$repo" ls-tree "$recovery_sha" -- \
		"$relative_path" | awk '{print $1}')"
	actual_permissions="$(stat -c '%a' "$frozen_root/$relative_path")"
	actual_mode=100644
	if [[ "$actual_permissions" == "755" ]]; then actual_mode=100755; fi
	if [[ "$actual_blob" != "$expected_blob" ||
			"$actual_mode" != "$expected_mode" ||
			( "$actual_permissions" != "644" && "$actual_permissions" != "755" ) ]]; then
		echo "WP40 R8 recovery: frozen $relative_path blob/mode differs from selected commit" >&2
		exit 2
	fi
done
if [[ ! -x "$script_dir/recover_sharded_g3.sh" ||
		! -x "$script_dir/test_recovery_validate.sh" ]]; then
	echo "WP40 R8 recovery: committed shell entry points must be executable" >&2
	exit 2
fi

source_capture_live="$repo/tools/wp40/results/r8/$source_capture_id"
feature_dir_live="$source_capture_live/shards/$feature_capture_id"
native_dir_live="$source_capture_live/shards/$native_capture_id"
if [[ ! -d "$feature_dir_live" || ! -d "$native_dir_live" ]]; then
	echo "WP40 R8 recovery: exact source capture is unavailable" >&2
	exit 2
fi
canonical_source_capture="$repo/tools/wp40/results/r8/$source_capture_id"
if [[ "$(readlink -f "$source_capture_live")" != "$canonical_source_capture" ]]; then
	echo "WP40 R8 recovery: source capture path is not canonical" >&2
	exit 2
fi

scratch="$(mktemp -d -p /tmp grudgelands-wp40-r8-recovery.XXXXXXXX)"
result_tmp=""
cleanup() {
	if [[ -n "$result_tmp" &&
			"$result_tmp" == "$repo/tools/wp40/results/r8/.recovery."* ]]; then
		rm -rf -- "$result_tmp"
	fi
	if [[ "$scratch" == /tmp/grudgelands-wp40-r8-recovery.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap 'exit 130' HUP INT TERM
trap cleanup EXIT

# Take one private snapshot before validating or interpreting any evidence.
# Every later read uses this snapshot, and the complete snapshot is retained in
# the recovery result. A source mutation during the copy changes its tree hash
# and fails before evaluation.
source_capture="$scratch/source-capture"
mkdir "$source_capture"
(
	cd "$source_capture_live"
	tar -cf - .
) | (
	cd "$source_capture"
	tar -xf -
)
feature_dir="$source_capture/shards/$feature_capture_id"
native_dir="$source_capture/shards/$native_capture_id"

source_checksums="$scratch/source-checksums.sha256"
(
	cd "$source_capture"
	find . -type f -print0 | sort -z | xargs -0 sha256sum
) >"$source_checksums"
actual_source_tree_sha256="$(sha256sum "$source_checksums" | awk '{print $1}')"
if [[ "$actual_source_tree_sha256" != "$source_tree_sha256" ]]; then
	echo "WP40 R8 recovery: private source snapshot tree hash changed" >&2
	exit 1
fi
if [[ "$(find "$source_capture" -type f | wc -l)" != "83" ]] ||
		find "$source_capture" -type l -print -quit | rg -q . ||
		find "$source_capture" ! -type f ! -type d -print -quit | rg -q . ||
		find "$source_capture" -type f -name '*.partial' -print -quit | rg -q .; then
	echo "WP40 R8 recovery: source capture shape changed" >&2
	exit 1
fi

expected_worker_status=$'shard\texit_status\nfeature\t0\nnative\t1'
if [[ "$(cat "$source_capture/worker-status.tsv")" != "$expected_worker_status" ]]; then
	echo "WP40 R8 recovery: original failed-closed worker status changed" >&2
	exit 1
fi
if [[ -e "$source_capture/manifest.json" ||
		-e "$source_capture/comparison.json" ||
		-e "$source_capture/checksums.sha256" ||
		-e "$native_dir/manifest.json" || -e "$native_dir/checksums.sha256" ]]; then
	echo "WP40 R8 recovery: source no longer has the expected failed-closed shape" >&2
	exit 1
fi
for path in "$feature_dir/manifest.json" "$feature_dir/comparison.json" \
		"$feature_dir/checksums.sha256" "$native_dir/comparison.json"; do
	[[ -s "$path" ]] || {
		echo "WP40 R8 recovery: missing retained child evidence $path" >&2
		exit 1
	}
done
(
	cd "$feature_dir"
	sha256sum -c checksums.sha256 >/dev/null
)

require_sha256() {
	local path="$1"
	local expected="$2"
	local actual
	actual="$(sha256sum "$path" | awk '{print $1}')"
	if [[ "$actual" != "$expected" ]]; then
		echo "WP40 R8 recovery: unexpected SHA-256 for $path" >&2
		exit 1
	fi
}
require_sha256 "$feature_dir/forward/events.jsonl" \
	2afb6a8c4d55e73554c4c81159f934a105003d8c7df4db3b9a422e6a5f05c5d8
require_sha256 "$feature_dir/reverse/events.jsonl" \
	43b639bb31efc63a5edf7fde917f765db3baae4c4047542e6daba90dc32dad70
require_sha256 "$native_dir/forward/events.jsonl" \
	7786ccb94ce63ced6e369c4d88909f74f083885ce0996d2b7897406e13f41e94
require_sha256 "$native_dir/reverse/events.jsonl" \
	55397d11b0112551597c30f88ef361e07cdbc9ae688c36657cba2bbbc92a7363

source_input_paths=(
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
for relative_path in "${source_input_paths[@]}"; do
	captured="$source_capture/inputs/$relative_path"
	[[ -f "$captured" ]] || {
		echo "WP40 R8 recovery: missing source input $relative_path" >&2
		exit 1
	}
	expected_blob="$(git -C "$repo" rev-parse "$source_checkout_sha:$relative_path")"
	actual_blob="$(git -C "$repo" hash-object "$captured")"
	expected_mode="$(git -C "$repo" ls-tree "$source_checkout_sha" -- \
		"$relative_path" | awk '{print $1}')"
	actual_permissions="$(stat -c '%a' "$captured")"
	actual_mode=100644
	if [[ "$actual_permissions" == "755" ]]; then actual_mode=100755; fi
	if [[ "$actual_blob" != "$expected_blob" ||
			"$actual_mode" != "$expected_mode" ||
			( "$actual_permissions" != "644" && "$actual_permissions" != "755" ) ]]; then
		echo "WP40 R8 recovery: source input blob/mode mismatch: $relative_path" >&2
		exit 1
	fi
done
actual_input_set_sha256="$({
	for relative_path in "${source_input_paths[@]}"; do
		sha256sum "$source_capture/inputs/$relative_path" | awk '{print $1}'
	done
} | sha256sum | awk '{print $1}')"
if [[ "$actual_input_set_sha256" != "$input_set_sha256" ]]; then
	echo "WP40 R8 recovery: source input-set digest changed" >&2
	exit 1
fi

feature_corpus="$source_capture/inputs/tools/wp40/r8/smoke-corpus.tsv"
empty_corpus="$source_capture/inputs/tools/wp40/r8/empty-feature-corpus.tsv"
native_corpus="$source_capture/inputs/tools/wp40/r8/native-witness-corpus.tsv"
feature_corpus_sha256="$(sha256sum "$feature_corpus" | awk '{print $1}')"
empty_corpus_sha256="$(sha256sum "$empty_corpus" | awk '{print $1}')"
native_corpus_sha256="$(sha256sum "$native_corpus" | awk '{print $1}')"
expected_feature_corpus=ac0809fe2cb527df8c74ac26b0dbc0eef0910bb81fb4a6125fbd23df922b490a
expected_empty_corpus=fafa998fddca581e4499a4dbd70d9fccda30b5a1fa5637a7126d1149e321e377
expected_native_corpus=7d53372219823f61db86e4cc5c8922522e5cd2f98c04ddc092246784b5ad3731
if [[ "$feature_corpus_sha256" != "$expected_feature_corpus" ||
		"$empty_corpus_sha256" != "$expected_empty_corpus" ||
		"$native_corpus_sha256" != "$expected_native_corpus" ]]; then
	echo "WP40 R8 recovery: frozen corpus digest changed" >&2
	exit 1
fi
feature_ids="$(awk 'NF && $1 !~ /^#/ {print $1}' "$feature_corpus" |
	jq -Rsc 'split("\n") | map(select(length > 0))')"
native_ids="$(awk 'NF && $1 !~ /^#/ {print $1}' "$native_corpus" |
	jq -Rsc 'split("\n") | map(select(length > 0))')"
if ! jq -en --argjson feature "$feature_ids" --argjson native "$native_ids" '
	($feature | length) == 10 and ($native | length) == 32 and
	(($feature + $native) | length) == 42 and
	(($feature + $native) | unique | length) == 42' >/dev/null; then
	echo "WP40 R8 recovery: frozen corpus IDs changed" >&2
	exit 1
fi

identity_digest() {
	local prefix="$1"
	{
		cat "${prefix}-deployment.txt"
		cat "${prefix}-version.txt"
	} | sha256sum | awk '{print $1}'
}
identity_prefixes=(
	"$source_capture/flatpak-before"
	"$feature_dir/flatpak-before-pair"
	"$feature_dir/flatpak-after-pair"
	"$native_dir/flatpak-before-pair"
	"$native_dir/flatpak-after-pair"
)
for prefix in "${identity_prefixes[@]}"; do
	if [[ "$(identity_digest "$prefix")" != "$engine_sha256" ]]; then
		echo "WP40 R8 recovery: retained child engine identity mismatch" >&2
		exit 1
	fi
done

seed_sha256=5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9
runner_digest="$({
	sha256sum "$source_capture/inputs/tools/wp40/r8/run.sh" | awk '{print $1}'
	sha256sum "$source_capture/inputs/tools/wp40/r8/probe/init.lua" | awk '{print $1}'
	sha256sum "$source_capture/inputs/tools/wp40/r8/probe/mod.conf" | awk '{print $1}'
} | sha256sum | awk '{print $1}')"
candidate_table_digest="$(sha256sum \
	"$source_capture/inputs/tools/wp40/r8/seed-candidates.tsv" | awk '{print $1}')"
reproduce_child_id() {
	local shard="$1"
	local port="$2"
	local corpus_digest="$3"
	local native_digest="$4"
	{
		printf '%s\n' "grug_wp40_r8_headless_smoke_v3" "$source_checkout_sha" \
			final "$shard" 1 "$port" 0 "$offline_r7_manifest_sha256" 10770 \
			"$runner_digest" "$corpus_digest" "$native_digest" \
			"$candidate_table_digest" "$engine_sha256" "$seed_sha256"
	} | sha256sum | awk '{print $1}'
}
reproduced_feature_id="$(reproduce_child_id feature 32001 \
	"$feature_corpus_sha256" "")"
reproduced_native_id="$(reproduce_child_id native 32003 \
	"$empty_corpus_sha256" "$native_corpus_sha256")"
if [[ "$reproduced_feature_id" != "$feature_capture_id" ||
		"$reproduced_native_id" != "$native_capture_id" ]]; then
	echo "WP40 R8 recovery: child capture ID reproduction failed" >&2
	exit 1
fi
reproduced_source_id="$({
	printf '%s\n' grug_wp40_r8_sharded_g3_v1 "$source_checkout_sha" 0 10770 \
		"$engine_sha256" "$input_set_sha256"
} | sha256sum | awk '{print $1}')"
if [[ "$reproduced_source_id" != "$source_capture_id" ]]; then
	echo "WP40 R8 recovery: master capture ID reproduction failed" >&2
	exit 1
fi

telemetry_tsv="$scratch/host-telemetry.tsv"
: >"$telemetry_tsv"
for shard in feature native; do
	child_dir="$feature_dir"
	if [[ "$shard" == "native" ]]; then child_dir="$native_dir"; fi
	for order in forward reverse; do
		order_dir="$child_dir/$order"
		for name in console.log engine-pgid.finished errors.log events.jsonl \
			exit-status luanti.conf server.log time.txt world.mt; do
			[[ -f "$order_dir/$name" ]] || {
				echo "WP40 R8 recovery: missing $shard/$order/$name" >&2
				exit 1
			}
		done
		if [[ "$(cat "$order_dir/exit-status")" != "0" ||
				-s "$order_dir/errors.log" ||
				! "$(cat "$order_dir/engine-pgid.finished")" =~ ^[1-9][0-9]*$ ]]; then
			echo "WP40 R8 recovery: failed process/log evidence for $shard/$order" >&2
			exit 1
		fi
		setting_value() {
			awk -F ' = ' -v key="$2" '$1 == key {print $2}' "$1"
		}
		expected_port=32001
		expected_native_required=false
		expected_feature_cases=10
		if [[ "$shard" == "native" ]]; then
			expected_port=32003
			expected_native_required=true
			expected_feature_cases=0
		fi
		if [[ "$order" == "reverse" ]]; then expected_port=$((expected_port + 1)); fi
		config="$order_dir/luanti.conf"
		world="$order_dir/world.mt"
		if [[ "$(setting_value "$config" mg_name)" != "v7" ||
				"$(setting_value "$config" fixed_map_seed)" != "0" ||
				"$(setting_value "$config" mapgen_limit)" != "31007" ||
				"$(setting_value "$config" chunksize)" != "5" ||
				"$(setting_value "$config" water_level)" != "1" ||
				"$(setting_value "$config" mg_flags)" != "caves,dungeons,light,decorations,biomes,ores" ||
				"$(setting_value "$config" mgv7_spflags)" != "mountains,ridges,caverns,nofloatlands" ||
				"$(setting_value "$config" mgv7_dungeon_ymin)" != "-31000" ||
				"$(setting_value "$config" mgv7_dungeon_ymax)" != "-193" ||
				"$(setting_value "$config" num_emerge_threads)" != "1" ||
				"$(setting_value "$config" liquid_update)" != "10801" ||
				"$(setting_value "$config" port)" != "$expected_port" ||
				"$(setting_value "$config" grug_wp40_r8_native_required)" != "$expected_native_required" ||
				"$(setting_value "$config" grug_wp40_r8_order)" != "$order" ||
				"$(setting_value "$config" grug_wp40_r8_min_cases)" != "$expected_feature_cases" ||
				"$(setting_value "$config" grug_wp40_r8_max_cases)" != "$expected_feature_cases" ||
				"$(setting_value "$config" grug_wp40_r8_timeout)" != "10770" ||
				"$(setting_value "$config" secure.enable_security)" != "true" ||
				"$(setting_value "$config" secure.trusted_mods)" != "grug_wp40_r8_probe" ||
				"$(setting_value "$world" gameid)" != "grudgelands" ]]; then
			echo "WP40 R8 recovery: mapgen/world settings mismatch for $shard/$order" >&2
			exit 1
		fi
		time_file="$order_dir/time.txt"
		elapsed_text="$(sed -n 's/^.*Elapsed (wall clock) time (h:mm:ss or m:ss): //p' \
			"$time_file")"
		maximum_rss_kib="$(awk -F': ' '/Maximum resident set size \(kbytes\)/ {print $2}' \
			"$time_file")"
		time_exit_status="$(awk -F': ' '/^[[:space:]]*Exit status:/ {print $2}' \
			"$time_file")"
		elapsed_seconds="$(awk -v value="$elapsed_text" 'BEGIN {
			n = split(value, part, ":");
			if (n == 3) seconds = part[1] * 3600 + part[2] * 60 + part[3];
			else if (n == 2) seconds = part[1] * 60 + part[2];
			else exit 1;
			printf "%.2f", seconds;
		}')" || {
			echo "WP40 R8 recovery: invalid elapsed time for $shard/$order" >&2
			exit 1
		}
		command_envelope=false
		if rg -Fq 'timeout --foreground --kill-after=10 10800 chrt --idle 0 ionice -c3 flatpak run --die-with-parent' \
				"$time_file"; then
			command_envelope=true
		fi
		printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$shard" "$order" \
			"$elapsed_seconds" "$maximum_rss_kib" "$time_exit_status" \
			"$command_envelope" >>"$telemetry_tsv"
	done
done
host_telemetry="$(jq -Rn '[inputs | split("\t") | {
	shard: .[0], order: .[1], elapsed_seconds: (.[2] | tonumber),
	maximum_rss_kib: (.[3] | tonumber), exit_status: (.[4] | tonumber),
	command_envelope: (.[5] == "true")}]' <"$telemetry_tsv")"

file_checks="$(jq -n '{source_tree_sha256: true, source_file_count: true,
	no_partial_files: true, failed_closed_shape: true,
	feature_child_checksums: true, raw_event_sha256: true,
	source_input_blobs_and_modes: true, source_input_set_sha256: true,
	corpus_sha256_and_ids: true, master_capture_id: true,
	child_capture_ids: true, retained_engine_identity: true,
	per_order_files_exit_logs: true, mapgen_world_settings: true,
	host_time_envelope: true}')"

recovery_input_sha256="$({
	for relative_path in "${recovery_paths[@]}"; do
		git -C "$repo" cat-file blob "$recovery_sha:$relative_path" |
			sha256sum | awk '{print $1}'
	done
} | sha256sum | awk '{print $1}')"
recovery_id="$({
	printf '%s\n' grug_wp40_r8_sharded_g3_recovery_v1 "$recovery_sha" \
		"$source_capture_id" "$source_tree_sha256" "$recovery_input_sha256"
} | sha256sum | awk '{print $1}')"
results_root="$repo/tools/wp40/results/r8"
result_dir="$results_root/$recovery_id"
if [[ -e "$result_dir" ]]; then
	echo "WP40 R8 recovery: refusing to overwrite immutable result $result_dir" >&2
	exit 2
fi
result_tmp="$(mktemp -d "$results_root/.recovery.XXXXXXXX")"
mkdir "$result_tmp/inputs"
git -C "$repo" archive "$recovery_sha" -- "${recovery_paths[@]}" | (
	cd "$result_tmp/inputs"
	tar -xf -
)
for relative_path in "${recovery_paths[@]}"; do
	expected_blob="$(git -C "$repo" rev-parse "$recovery_sha:$relative_path")"
	actual_blob="$(git -C "$repo" hash-object \
		"$result_tmp/inputs/$relative_path")"
	expected_mode="$(git -C "$repo" ls-tree "$recovery_sha" -- \
		"$relative_path" | awk '{print $1}')"
	actual_permissions="$(stat -c '%a' "$result_tmp/inputs/$relative_path")"
	actual_mode=100644
	if [[ "$actual_permissions" == "755" ]]; then actual_mode=100755; fi
	if [[ "$actual_blob" != "$expected_blob" ||
			"$actual_mode" != "$expected_mode" ||
			( "$actual_permissions" != "644" &&
				"$actual_permissions" != "755" ) ]]; then
		echo "WP40 R8 recovery: retained $relative_path blob/mode differs from selected commit" >&2
		exit 2
	fi
done
mv "$source_capture" "$result_tmp/source-capture"
source_capture="$result_tmp/source-capture"
feature_dir="$source_capture/shards/$feature_capture_id"
native_dir="$source_capture/shards/$native_capture_id"
cp "$source_checksums" "$result_tmp/source-checksums.sha256"

git -C "$repo" cat-file blob \
	"$recovery_sha:tools/wp40/r8/recovery_validate.jq" | jq -n \
	--arg source_capture_id "$source_capture_id" \
	--arg source_tree_sha256 "$source_tree_sha256" \
	--arg checkout_sha "$source_checkout_sha" \
	--arg feature_capture_id "$feature_capture_id" \
	--arg native_capture_id "$native_capture_id" \
	--arg engine_sha256 "$engine_sha256" \
	--arg input_set_sha256 "$input_set_sha256" \
	--arg runtime_manifest_sha256 "$runtime_manifest_sha256" \
	--arg offline_r7_manifest_sha256 "$offline_r7_manifest_sha256" \
	--arg feature_corpus_sha256 "$feature_corpus_sha256" \
	--arg empty_corpus_sha256 "$empty_corpus_sha256" \
	--arg native_corpus_sha256 "$native_corpus_sha256" \
	--argjson feature_ids "$feature_ids" --argjson native_ids "$native_ids" \
	--argjson file_checks "$file_checks" \
	--argjson host_telemetry "$host_telemetry" \
	--slurpfile feature_manifest "$feature_dir/manifest.json" \
	--slurpfile feature_comparison "$feature_dir/comparison.json" \
	--slurpfile native_comparison "$native_dir/comparison.json" \
	--slurpfile feature_forward "$feature_dir/forward/events.jsonl" \
	--slurpfile feature_reverse "$feature_dir/reverse/events.jsonl" \
	--slurpfile native_forward "$native_dir/forward/events.jsonl" \
	--slurpfile native_reverse "$native_dir/reverse/events.jsonl" \
	-f /dev/stdin \
	>"$result_tmp/comparison.json"
if ! jq -e '.all_ok == true and .policy.dungeon_status == "not_observed"' \
		"$result_tmp/comparison.json" >/dev/null; then
	echo "WP40 R8 recovery: deterministic recovery comparison failed" >&2
	exit 1
fi

comparison_sha256="$(sha256sum "$result_tmp/comparison.json" | awk '{print $1}')"
source_checksums_sha256="$(sha256sum "$result_tmp/source-checksums.sha256" |
	awk '{print $1}')"
jq -n --arg recovery_id "$recovery_id" --arg recovery_sha "$recovery_sha" \
	--arg recovery_input_sha256 "$recovery_input_sha256" \
	--arg source_capture_id "$source_capture_id" \
	--arg source_tree_sha256 "$source_tree_sha256" \
	--arg source_checkout_sha "$source_checkout_sha" \
	--arg feature_capture_id "$feature_capture_id" \
	--arg native_capture_id "$native_capture_id" \
	--arg engine_sha256 "$engine_sha256" \
	--arg input_set_sha256 "$input_set_sha256" \
	--arg comparison_sha256 "$comparison_sha256" \
	--arg source_checksums_sha256 "$source_checksums_sha256" \
	--arg runtime_manifest_sha256 "$runtime_manifest_sha256" \
	--argjson host_telemetry "$host_telemetry" '
	{
		schema: "grug_wp40_r8_sharded_g3_recovery_v1",
		status: "final_sharded_smoke_recovered_complete",
		recovery_id: $recovery_id,
		recovery_snapshot: {checkout_sha: $recovery_sha,
			source: "validated frozen commit tree",
			input_set_sha256: $recovery_input_sha256},
		source: {capture_id: $source_capture_id,
			tree_sha256: $source_tree_sha256,
			checkout_sha: $source_checkout_sha,
			input_set_sha256: $input_set_sha256,
			feature_capture_id: $feature_capture_id,
			native_capture_id: $native_capture_id,
			original_status: "failed_closed_before_aggregate",
			modified_by_recovery: false,
			retained_snapshot: "source-capture/",
			source_file_count: 83},
		identity: {engine_sha256: $engine_sha256,
			runtime_manifest_sha256: $runtime_manifest_sha256,
			basis: "top-level before plus both child before/after pairs; no historical top-level after files exist"},
		policy: {version: "recovery_v1",
			approved: "2026-09-03",
			dungeon_status: "not_observed",
			dungeon_preservation_proven: false,
			cave_details: "diagnostic with equal hard summaries"},
		outputs: {comparison: "comparison.json",
			comparison_sha256: $comparison_sha256,
			source_checksums: "source-checksums.sha256",
			source_checksums_sha256: $source_checksums_sha256},
		measured: {host: $host_telemetry,
			maximum_host_elapsed_seconds: ([$host_telemetry[].elapsed_seconds] | max)},
		limitations: [
			"The source capture remains a formal failure under its original policy.",
			"No dungeon was observed; dungeon preservation is not proven.",
			"Native cave detail variance is accepted only at diagnostic level.",
			"The GUI itinerary and fallback-engine runtime remain separate user gates."
		]
	}' >"$result_tmp/manifest.json"

jq -nr --arg recovery_id "$recovery_id" \
	--arg recovery_sha "$recovery_sha" --arg source_capture_id "$source_capture_id" \
	--arg source_tree_sha256 "$source_tree_sha256" \
	--arg source_checkout_sha "$source_checkout_sha" \
	--arg comparison_sha256 "$comparison_sha256" '[
	["schema", "grug_wp40_r8_sharded_g3_recovery_receipt_v1"],
	["status", "PASS"],
	["recovery_id", $recovery_id],
	["recovery_sha", $recovery_sha],
	["source_capture_id", $source_capture_id],
	["source_tree_sha256", $source_tree_sha256],
	["source_checkout_sha", $source_checkout_sha],
	["comparison_sha256", $comparison_sha256],
	["dungeon_status", "not_observed"],
	["dungeon_preservation_proven", "false"]
	][] | @tsv' \
	>"$result_tmp/receipt.tsv"

(
	cd "$result_tmp"
	find . -type f ! -name checksums.sha256 -print0 | sort -z |
		xargs -0 sha256sum
) >"$result_tmp/checksums.sha256"

# Recheck the live source once after evaluation. The accepted bytes remain the
# private retained snapshot either way, but a concurrent source mutation is an
# explicit execution failure rather than an undisclosed divergence.
final_live_checksums="$scratch/final-live-source-checksums.sha256"
(
	cd "$source_capture_live"
	find . -type f -print0 | sort -z | xargs -0 sha256sum
) >"$final_live_checksums"
final_live_sha256="$(sha256sum "$final_live_checksums" | awk '{print $1}')"
if [[ "$final_live_sha256" != "$source_tree_sha256" ]]; then
	echo "WP40 R8 recovery: live source capture changed during recovery" >&2
	exit 1
fi

# GNU mv's no-clobber mode can report success while deliberately leaving the
# source in place. Test source disappearance as the exclusive-publish proof;
# never allow a second temp directory to be nested into an existing result.
if ! mv -T --no-clobber "$result_tmp" "$result_dir"; then
	echo "WP40 R8 recovery: exclusive result publication failed" >&2
	exit 2
fi
if [[ -e "$result_tmp" ]]; then
	echo "WP40 R8 recovery: immutable result already exists" >&2
	exit 2
fi
result_tmp=""

cleanup
trap - EXIT HUP INT TERM
echo "$result_dir"
