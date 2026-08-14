#!/usr/bin/env bash
set -euo pipefail

if (( $# != 0 )); then
	echo "usage: tools/wp40/run_t2_extreme_conformance.sh" >&2
	exit 2
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
lua="$repo/tools/bin/lua51"
luac="$repo/tools/bin/luac51"
retained="$script_dir/fixtures/t2_extreme_e0"
scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-conformance.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

if [[ ! -x "$lua" || ! -x "$luac" ]]; then
	echo "WP40 T2 C1 requires the vendored PUC Lua 5.1 tools" >&2
	exit 2
fi
commit="$(git -C "$repo" rev-parse --verify HEAD)"
tree="$(git -C "$repo" rev-parse --verify "${commit}^{tree}")"
preflight="$script_dir/t2_extreme_conformance_preflight.lua"
preflight_line="$($lua "$preflight" "$repo" "$scratch" "$commit" "$tree")"
if [[ ! "$preflight_line" =~ ^WP40_T2_C1_PREFLIGHT$'\t'([0-9a-f]{40})$'\t'([0-9a-f]{40})$'\t'([0-9a-f]{64})$ ]] ||
	[[ "${BASH_REMATCH[1]}" != "$commit" || "${BASH_REMATCH[2]}" != "$tree" ]]; then
	echo "WP40 T2 C1 preflight evidence changed: $preflight_line" >&2
	exit 2
fi
dag="${BASH_REMATCH[3]}"
echo "WP40 T2 C1 authority commit=$commit tree=$tree dag=$dag interpreter=$lua"

export_repo="$scratch/export"
mkdir -p "$export_repo"
git -C "$repo" archive "$commit" | tar -x -C "$export_repo"
export_script="$export_repo/tools/wp40"
export_retained="$export_script/fixtures/t2_extreme_e0"

owned_lua=(
	"t2_extreme_authority.lua"
	"t2_extreme_conformance_authority.lua"
	"t2_extreme_conformance.lua"
	"t2_extreme_conformance_test.lua"
	"t2_extreme_rescore_worker.lua"
	"t2_extreme_selected_worker.lua"
	"t2_extreme_conformance_verify.lua"
	"t2_extreme_conformance_preflight.lua"
	"t2_extreme_conformance_finalize.lua"
	"t2_partition_oracle.lua"
	"t2_partition_test.lua"
	"fixtures/t2_extreme_e0/conformance_gate.lua"
)
for file in "${owned_lua[@]}"; do
	"$luac" -p "$export_script/$file"
done
bash -n "$export_script/run_t2_extreme_conformance.sh"

final_output="$retained/conformance-puc.tsv"
if [[ -e "$final_output" ]]; then
	final_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance-final.XXXXXXXX)"
	"$lua" "$export_script/t2_extreme_conformance_finalize.lua" "$repo" \
		"$final_scratch" "$final_output" "$commit" "$tree" "$dag" verify
	rm -rf -- "$final_scratch"
	"$lua" "$preflight" "$repo" "$scratch" "$commit" "$tree" >/dev/null
	echo "WP40 T2 C1 conformance resumed complete rescore=20/20 selected=4/4"
	exit 0
fi

required=(0 511 512 1023 1024 1047 1535 1536 1713 2047 2048 2192
	2559 2560 3071 3072 3438 3583 3584 4095)
slots=(28 29 30 31)

verify_result() {
	local kind="$1" identity="$2" path="$3"
	local verify_scratch
	verify_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance-verify.XXXXXXXX)"
	if ! "$lua" "$export_script/t2_extreme_conformance_verify.lua" "$repo" \
		"$verify_scratch" "$kind" "$identity" "$path" "$commit" "$tree" "$dag"; then
		rm -rf -- "$verify_scratch"
		return 1
	fi
	rm -rf -- "$verify_scratch"
}

publish_result() {
	local exported="$1" target="$2"
	local temporary="$target.tmp"
	if [[ -e "$target" || -e "$temporary" ]]; then
		echo "WP40 T2 C1 result target already exists: $target" >&2
		return 1
	fi
	cp -- "$exported" "$temporary"
	if ! cmp -s -- "$exported" "$temporary"; then
		rm -f -- "$temporary"
		echo "WP40 T2 C1 result copy verification failed: $target" >&2
		return 1
	fi
	mv -T -- "$temporary" "$target"
}

rescore_complete=0
rescore_pending=()
for candidate in "${required[@]}"; do
	path="$retained/rescore-puc-$(printf '%04d' "$candidate").tsv"
	if [[ -e "$path" ]]; then
		verify_result rescore "$candidate" "$path"
		rescore_complete=$((rescore_complete + 1))
		echo "WP40 T2 C1 rescore resumed candidate=$(printf '%04d' "$candidate") completed=$rescore_complete/20"
	else
		rescore_pending+=("$candidate")
	fi
done

rescore_start=$SECONDS
for ((wave_start=0; wave_start<${#rescore_pending[@]}; wave_start+=8)); do
	declare -a wave_candidates=() wave_pids=() wave_logs=() wave_scratches=()
	for ((offset=0; offset<8 && wave_start+offset<${#rescore_pending[@]}; offset++)); do
		candidate="${rescore_pending[$((wave_start + offset))]}"
		worker_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance-worker.XXXXXXXX)"
		export_output="$export_retained/rescore-puc-$(printf '%04d' "$candidate").tsv"
		log="$scratch/rescore-$(printf '%04d' "$candidate").log"
		"$lua" "$export_script/t2_extreme_rescore_worker.lua" "$export_repo" \
			"$worker_scratch" "$candidate" "$export_output" "$commit" "$tree" \
			"$dag" "$lua" >"$log" 2>&1 &
		wave_candidates+=("$candidate")
		wave_pids+=("$!")
		wave_logs+=("$log")
		wave_scratches+=("$worker_scratch")
	done
	echo "WP40 T2 C1 rescore wave active=${#wave_pids[@]} completed=$rescore_complete/20 candidates=${wave_candidates[*]}"
	while :; do
		wave_active=0
		wave_current=""
		for ((index=0; index<${#wave_pids[@]}; index++)); do
			if kill -0 "${wave_pids[$index]}" 2>/dev/null; then
				wave_active=$((wave_active + 1))
				wave_current+=" $(printf '%04d' "${wave_candidates[$index]}")"
			fi
		done
		if (( wave_active == 0 )); then break; fi
		echo "WP40 T2 C1 rescore live active=$wave_active completed=$rescore_complete/20 wall_seconds=$((SECONDS - rescore_start)) candidates=$wave_current"
		sleep 15
	done
	wave_failed=0
	for ((index=0; index<${#wave_pids[@]}; index++)); do
		candidate="${wave_candidates[$index]}"
		if wait "${wave_pids[$index]}"; then
			cat "${wave_logs[$index]}"
			exported="$export_retained/rescore-puc-$(printf '%04d' "$candidate").tsv"
			target="$retained/rescore-puc-$(printf '%04d' "$candidate").tsv"
			publish_result "$exported" "$target"
			verify_result rescore "$candidate" "$target"
			rescore_complete=$((rescore_complete + 1))
			elapsed=$((SECONDS - rescore_start))
			eta=0
			if (( rescore_complete > 0 && rescore_complete < 20 )); then
				eta=$((elapsed * (20 - rescore_complete) / rescore_complete))
			fi
			echo "WP40 T2 C1 rescore progress candidate=$(printf '%04d' "$candidate") completed=$rescore_complete/20 wall_seconds=$elapsed eta_seconds=$eta"
		else
			status=$?
			cat "${wave_logs[$index]}" >&2
			echo "WP40 T2 C1 rescore failed candidate=$(printf '%04d' "$candidate") status=$status" >&2
			wave_failed=1
		fi
		rm -rf -- "${wave_scratches[$index]}"
	done
	if (( wave_failed != 0 )); then exit 1; fi
done

if (( rescore_complete != 20 )); then
	echo "WP40 T2 C1 hard rescore barrier is incomplete: $rescore_complete/20" >&2
	exit 1
fi
for candidate in "${required[@]}"; do
	verify_result rescore "$candidate" \
		"$retained/rescore-puc-$(printf '%04d' "$candidate").tsv"
done
echo "WP40 T2 C1 hard rescore barrier passed completed=20/20"

selected_complete=0
selected_pending=()
for slot in "${slots[@]}"; do
	path="$retained/selected-puc-slot$(printf '%02d' "$slot").tsv"
	if [[ -e "$path" ]]; then
		verify_result selected "$slot" "$path"
		selected_complete=$((selected_complete + 1))
		echo "WP40 T2 C1 selected resumed slot=$slot completed=$selected_complete/4"
	else
		selected_pending+=("$slot")
	fi
done

declare -a selected_pids=() selected_logs=() selected_scratches=() partition_scratches=()
for slot in "${selected_pending[@]}"; do
	worker_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance-worker.XXXXXXXX)"
	partition_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-partition.XXXXXXXX)"
	export_output="$export_retained/selected-puc-slot$(printf '%02d' "$slot").tsv"
	log="$scratch/selected-slot$(printf '%02d' "$slot").log"
	"$lua" "$export_script/t2_extreme_selected_worker.lua" "$export_repo" \
		"$worker_scratch" "$partition_scratch" "$slot" "$export_output" \
		"$commit" "$tree" "$dag" "$lua" >"$log" 2>&1 &
	selected_pids+=("$!")
	selected_logs+=("$log")
	selected_scratches+=("$worker_scratch")
	partition_scratches+=("$partition_scratch")
done
echo "WP40 T2 C1 selected phase active=${#selected_pids[@]} completed=$selected_complete/4 slots=${selected_pending[*]:-none}"
selected_failed=0
selected_start=$SECONDS
while :; do
	selected_active=0
	selected_current=""
	for ((index=0; index<${#selected_pids[@]}; index++)); do
		if kill -0 "${selected_pids[$index]}" 2>/dev/null; then
			selected_active=$((selected_active + 1))
			selected_current+=" ${selected_pending[$index]}"
		fi
	done
	if (( selected_active == 0 )); then break; fi
	echo "WP40 T2 C1 selected live active=$selected_active completed=$selected_complete/4 wall_seconds=$((SECONDS - selected_start)) slots=$selected_current"
	sleep 30
done
for ((index=0; index<${#selected_pids[@]}; index++)); do
	slot="${selected_pending[$index]}"
	if wait "${selected_pids[$index]}"; then
		cat "${selected_logs[$index]}"
		exported="$export_retained/selected-puc-slot$(printf '%02d' "$slot").tsv"
		target="$retained/selected-puc-slot$(printf '%02d' "$slot").tsv"
		publish_result "$exported" "$target"
		verify_result selected "$slot" "$target"
		selected_complete=$((selected_complete + 1))
		echo "WP40 T2 C1 selected progress slot=$slot completed=$selected_complete/4 wall_seconds=$((SECONDS - selected_start))"
	else
		status=$?
		cat "${selected_logs[$index]}" >&2
		echo "WP40 T2 C1 selected failed slot=$slot status=$status" >&2
		selected_failed=1
	fi
	rm -rf -- "${selected_scratches[$index]}" "${partition_scratches[$index]}"
done
if (( selected_failed != 0 || selected_complete != 4 )); then
	echo "WP40 T2 C1 selected barrier failed completed=$selected_complete/4" >&2
	exit 1
fi
for slot in "${slots[@]}"; do
	verify_result selected "$slot" \
		"$retained/selected-puc-slot$(printf '%02d' "$slot").tsv"
done
echo "WP40 T2 C1 hard selected barrier passed completed=4/4"

"$lua" "$preflight" "$repo" "$scratch" "$commit" "$tree" >/dev/null
final_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance-final.XXXXXXXX)"
"$lua" "$export_script/t2_extreme_conformance_finalize.lua" "$repo" \
	"$final_scratch" "$final_output" "$commit" "$tree" "$dag"
rm -rf -- "$final_scratch"
"$lua" "$preflight" "$repo" "$scratch" "$commit" "$tree" >/dev/null
echo "WP40 T2 C1 conformance complete rescore=20/20 selected=4/4 stage2=pending_seed_corpus_promotion"
