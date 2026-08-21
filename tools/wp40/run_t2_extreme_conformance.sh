#!/usr/bin/env bash
set -euo pipefail

# T2c-E0-C1 PUC conformance over the v3 scalar pool.
#
# Every file this launcher writes is a v3 name.  The pre-v3 rescore-puc-%04d,
# selected-puc-slot%02d and conformance-puc.tsv files are retained evidence of
# the 53be77e pool -- conformance_gate.lua is content-pinned and asserted by
# selected_stage2_blocked.lua -- so overwriting one would leave
# "WP40_FINAL=1 run_t2_partition.sh --historical" permanently red.  That defect
# is why this runner was marked BLOCKED; v3_target below is the fix, and it
# refuses any target that is not a v3 name.
if (( $# != 0 )); then
	echo "usage: tools/wp40/run_t2_extreme_conformance.sh" >&2
	exit 2
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
export WP40_NO_CACHE=1
unset WP40_T2_ONLY
lua="$repo/tools/bin/lua51"
luac="$repo/tools/bin/luac51"
retained="$script_dir/fixtures/t2_extreme_e0"
scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance.XXXXXXXX)"
kat_scratch=""
cleanup() {
	if [[ -n "${stale_final_backup:-}" && ! -e "${final_output:-}" ]]; then
		cp -- "$stale_final_backup" "$final_output"
	fi
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-conformance.* ]]; then
		rm -rf -- "$scratch"
	fi
	if [[ -n "$kat_scratch" && "$kat_scratch" == /tmp/grudgelands-wp40-t2-conformance.* ]]; then
		rm -rf -- "$kat_scratch"
	fi
}
trap cleanup EXIT

if [[ ! -x "$lua" || ! -x "$luac" ]]; then
	echo "WP40 T2 C1 v3 requires the vendored PUC Lua 5.1 tools" >&2
	exit 2
fi
commit="$(git -C "$repo" rev-parse --verify HEAD)"
tree="$(git -C "$repo" rev-parse --verify "${commit}^{tree}")"
preflight="$script_dir/t2_extreme_conformance_preflight.lua"
preflight_line="$($lua "$preflight" "$repo" "$scratch" "$commit" "$tree")"
if [[ ! "$preflight_line" =~ ^WP40_T2_C1_V3_PREFLIGHT$'\t'([0-9a-f]{40})$'\t'([0-9a-f]{40})$'\t'([0-9a-f]{64})$ ]] ||
	[[ "${BASH_REMATCH[1]}" != "$commit" || "${BASH_REMATCH[2]}" != "$tree" ]]; then
	echo "WP40 T2 C1 v3 preflight evidence changed: $preflight_line" >&2
	exit 2
fi
dag="${BASH_REMATCH[3]}"
echo "WP40 T2 C1 v3 authority commit=$commit tree=$tree dag=$dag interpreter=$lua"

export_repo="$scratch/export"
mkdir -p "$export_repo"
git -C "$repo" archive "$commit" | tar -x -C "$export_repo"
export_script="$export_repo/tools/wp40"
export_retained="$export_script/fixtures/t2_extreme_e0"

owned_lua=(
	"t2_extreme_authority.lua"
	"t2_extreme_conformance_v3_authority.lua"
	"t2_extreme_conformance.lua"
	"t2_extreme_conformance_test.lua"
	"t2_extreme_rescore_worker.lua"
	"t2_extreme_selected_worker.lua"
	"t2_extreme_conformance_verify.lua"
	"t2_extreme_conformance_preflight.lua"
	"t2_extreme_conformance_finalize.lua"
	"t2_extreme_conformance_recorded.lua"
	"t2_partition_oracle.lua"
	"t2_partition_test.lua"
	"t2_s1_authority.lua"
	"fixtures/t2_extreme_e0/conformance_gate_v3.lua"
)
for file in "${owned_lua[@]}"; do
	"$luac" -p "$export_script/$file"
done
bash -n "$export_script/run_t2_extreme_conformance.sh"

# The conformance KAT is inside the C1 v3 DAG roster because its bytes can
# change what this run accepts -- but that is only true if it actually runs.
# It executes from the immutable export against the live repository (it needs
# git for the historical pool-provenance check) and costs a few seconds.
kat_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance.XXXXXXXX)"
"$lua" "$export_script/t2_extreme_conformance_test.lua" "$repo" "$kat_scratch"

# Single choke point for every path this launcher may write.  It checks the
# whole path, not just the basename: the directory must be one of the two
# retained directories (the working tree's and the immutable export's), and the
# file name must be a v3 name.  A basename-only guard would accept
# /etc/rescore-puc-v3-0000.tsv; this one does not.
v3_target() {
	local path="$1" directory name
	directory="${path%/*}"
	name="${path##*/}"
	if [[ "$directory" != "$retained" && "$directory" != "$export_retained" ]]; then
		echo "WP40 T2 C1 v3 refuses a target outside the retained directories: $path" >&2
		return 1
	fi
	case "$name" in
		rescore-puc-v3-[0-9][0-9][0-9][0-9].tsv) ;;
		selected-puc-v3-slot[0-9][0-9].tsv) ;;
		conformance-puc-v3.tsv) ;;
		*)
			echo "WP40 T2 C1 v3 refuses a non-v3 target: $path" >&2
			return 1
			;;
	esac
	printf '%s' "$path"
}

final_output="$(v3_target "$retained/conformance-puc-v3.tsv")"
stale_final_backup=""
if [[ -e "$final_output" ]]; then
	final_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance-final.XXXXXXXX)"
	if "$lua" "$export_script/t2_extreme_conformance_finalize.lua" "$repo" \
			"$final_scratch" "$final_output" "$commit" "$tree" "$dag" verify; then
		rm -rf -- "$final_scratch"
		"$lua" "$preflight" "$repo" "$scratch" "$commit" "$tree" >/dev/null
		echo "WP40 T2 C1 v3 conformance resumed complete rescore=20/20 selected=4/4"
		exit 0
	fi
	rm -rf -- "$final_scratch"
	# Second choice.  A finished artifact is immutable evidence of the commit it
	# RECORDS, not of whatever HEAD happens to be, so a documentation-only commit
	# must not be able to buy a 24-row rerun.  The driver reads the recorded
	# commit/tree/DAG out of the artifact's own bytes, requires that commit to be
	# an ancestor of HEAD with the recorded tree, requires every member of the
	# pinned closure -- the whole v3 authority roster -- to be byte-identical
	# between that commit and the working tree, and only then re-runs the
	# finalizer's verify mode with the RECORDED pins, which re-derives the final
	# blob from all 24 retained result files.  Any refusal falls through to the
	# recompute path below; generation itself is not relaxed anywhere.
	recorded_final_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance-final.XXXXXXXX)"
	if recorded_line="$("$lua" "$export_script/t2_extreme_conformance_recorded.lua" \
			"$repo" "$scratch" "$recorded_final_scratch" "$final_output")"; then
		rm -rf -- "$recorded_final_scratch"
		if [[ ! "$recorded_line" =~ ^WP40_T2_C1_V3_RECORDED_EVIDENCE_ACCEPTED$'\t'commit=([0-9a-f]{40})$'\t'tree=([0-9a-f]{40})$'\t'dag=([0-9a-f]{64})$'\t'closure=([0-9]+)$'\t'artifact_sha256=([0-9a-f]{64})$ ]]; then
			echo "WP40 T2 C1 v3 recorded evidence line changed: $recorded_line" >&2
			exit 2
		fi
		"$lua" "$preflight" "$repo" "$scratch" "$commit" "$tree" >/dev/null
		echo "WP40 T2 C1 v3 conformance REUSED RECORDED EVIDENCE rescore=20/20 selected=4/4 recorded_commit=${BASH_REMATCH[1]} recorded_tree=${BASH_REMATCH[2]} recorded_dag=${BASH_REMATCH[3]} closure=${BASH_REMATCH[4]} artifact=${BASH_REMATCH[5]} head_commit=$commit"
		exit 0
	fi
	rm -rf -- "$recorded_final_scratch"
	echo "WP40 T2 C1 v3 recorded evidence refused; the pinned closure or the retained rows no longer match the recorded commit"
	stale_final_backup="$scratch/stale-conformance-puc-v3.tsv"
	cp -- "$final_output" "$stale_final_backup"
	rm -- "$final_output"
	echo "WP40 T2 C1 v3 stale final evidence detected; recomputing for current commit=$commit"
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
	local exported="$1" target="$2" replace="${3:-0}"
	local temporary="$target.tmp"
	v3_target "$target" >/dev/null || return 1
	if [[ -e "$temporary" || -e "$target" && "$replace" != 1 ]]; then
		echo "WP40 T2 C1 v3 result target already exists: $target" >&2
		return 1
	fi
	cp -- "$exported" "$temporary"
	if ! cmp -s -- "$exported" "$temporary"; then
		rm -f -- "$temporary"
		echo "WP40 T2 C1 v3 result copy verification failed: $target" >&2
		return 1
	fi
	mv -T -- "$temporary" "$target"
}

rescore_complete=0
rescore_pending=()
declare -A stale_rescore=()
for candidate in "${required[@]}"; do
	path="$(v3_target "$retained/rescore-puc-v3-$(printf '%04d' "$candidate").tsv")"
	if [[ -e "$path" ]]; then
		if verify_result rescore "$candidate" "$path"; then
			rescore_complete=$((rescore_complete + 1))
			echo "WP40 T2 C1 v3 rescore resumed candidate=$(printf '%04d' "$candidate") completed=$rescore_complete/20"
		else
			stale_rescore[$candidate]=1
			rescore_pending+=("$candidate")
			echo "WP40 T2 C1 v3 stale rescore evidence candidate=$(printf '%04d' "$candidate"); recomputing for current commit=$commit"
		fi
	else
		rescore_pending+=("$candidate")
	fi
done

rescore_start=$SECONDS
# One real retained C1 PUC rescore worker peaked at 455084 KiB; sixteen stay
# below the 58 GiB host-memory limit even before allowing for shared pages.
for ((wave_start=0; wave_start<${#rescore_pending[@]}; wave_start+=16)); do
	declare -a wave_candidates=() wave_pids=() wave_logs=() wave_scratches=()
	for ((offset=0; offset<16 && wave_start+offset<${#rescore_pending[@]}; offset++)); do
		candidate="${rescore_pending[$((wave_start + offset))]}"
		worker_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance-worker.XXXXXXXX)"
		export_output="$(v3_target "$export_retained/rescore-puc-v3-$(printf '%04d' "$candidate").tsv")"
		if [[ "${stale_rescore[$candidate]:-0}" == 1 ]]; then rm -f -- "$export_output"; fi
		log="$scratch/rescore-$(printf '%04d' "$candidate").log"
		"$lua" "$export_script/t2_extreme_rescore_worker.lua" "$export_repo" \
			"$worker_scratch" "$candidate" "$export_output" "$commit" "$tree" \
			"$dag" "$lua" >"$log" 2>&1 &
		wave_candidates+=("$candidate")
		wave_pids+=("$!")
		wave_logs+=("$log")
		wave_scratches+=("$worker_scratch")
	done
	echo "WP40 T2 C1 v3 rescore wave active=${#wave_pids[@]} completed=$rescore_complete/20 candidates=${wave_candidates[*]}"
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
		echo "WP40 T2 C1 v3 rescore live active=$wave_active completed=$rescore_complete/20 wall_seconds=$((SECONDS - rescore_start)) candidates=$wave_current"
		sleep 15
	done
	wave_failed=0
	for ((index=0; index<${#wave_pids[@]}; index++)); do
		candidate="${wave_candidates[$index]}"
		if wait "${wave_pids[$index]}"; then
			cat "${wave_logs[$index]}"
			exported="$export_retained/rescore-puc-v3-$(printf '%04d' "$candidate").tsv"
			target="$retained/rescore-puc-v3-$(printf '%04d' "$candidate").tsv"
			publish_result "$exported" "$target" "${stale_rescore[$candidate]:-0}"
			verify_result rescore "$candidate" "$target"
			rescore_complete=$((rescore_complete + 1))
			elapsed=$((SECONDS - rescore_start))
			eta=0
			if (( rescore_complete > 0 && rescore_complete < 20 )); then
				eta=$((elapsed * (20 - rescore_complete) / rescore_complete))
			fi
			echo "WP40 T2 C1 v3 rescore progress candidate=$(printf '%04d' "$candidate") completed=$rescore_complete/20 wall_seconds=$elapsed eta_seconds=$eta"
		else
			status=$?
			cat "${wave_logs[$index]}" >&2
			echo "WP40 T2 C1 v3 rescore failed candidate=$(printf '%04d' "$candidate") status=$status" >&2
			wave_failed=1
		fi
		rm -rf -- "${wave_scratches[$index]}"
	done
	if (( wave_failed != 0 )); then exit 1; fi
done

if (( rescore_complete != 20 )); then
	echo "WP40 T2 C1 v3 hard rescore barrier is incomplete: $rescore_complete/20" >&2
	exit 1
fi
for candidate in "${required[@]}"; do
	verify_result rescore "$candidate" \
		"$retained/rescore-puc-v3-$(printf '%04d' "$candidate").tsv"
done
echo "WP40 T2 C1 v3 hard rescore barrier passed completed=20/20"

selected_complete=0
selected_pending=()
declare -A stale_selected=()
for slot in "${slots[@]}"; do
	path="$(v3_target "$retained/selected-puc-v3-slot$(printf '%02d' "$slot").tsv")"
	if [[ -e "$path" ]]; then
		if verify_result selected "$slot" "$path"; then
			selected_complete=$((selected_complete + 1))
			echo "WP40 T2 C1 v3 selected resumed slot=$slot completed=$selected_complete/4"
		else
			stale_selected[$slot]=1
			selected_pending+=("$slot")
			echo "WP40 T2 C1 v3 stale selected evidence slot=$slot; recomputing for current commit=$commit"
		fi
	else
		selected_pending+=("$slot")
	fi
done

declare -a selected_pids=() selected_logs=() selected_scratches=() partition_scratches=()
for slot in "${selected_pending[@]}"; do
	worker_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance-worker.XXXXXXXX)"
	partition_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-partition.XXXXXXXX)"
	export_output="$(v3_target "$export_retained/selected-puc-v3-slot$(printf '%02d' "$slot").tsv")"
	if [[ "${stale_selected[$slot]:-0}" == 1 ]]; then rm -f -- "$export_output"; fi
	log="$scratch/selected-slot$(printf '%02d' "$slot").log"
	"$lua" "$export_script/t2_extreme_selected_worker.lua" "$export_repo" \
		"$worker_scratch" "$partition_scratch" "$slot" "$export_output" \
		"$commit" "$tree" "$dag" "$lua" >"$log" 2>&1 &
	selected_pids+=("$!")
	selected_logs+=("$log")
	selected_scratches+=("$worker_scratch")
	partition_scratches+=("$partition_scratch")
done
echo "WP40 T2 C1 v3 selected phase active=${#selected_pids[@]} completed=$selected_complete/4 slots=${selected_pending[*]:-none}"
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
	echo "WP40 T2 C1 v3 selected live active=$selected_active completed=$selected_complete/4 wall_seconds=$((SECONDS - selected_start)) slots=$selected_current"
	sleep 30
done
for ((index=0; index<${#selected_pids[@]}; index++)); do
	slot="${selected_pending[$index]}"
	if wait "${selected_pids[$index]}"; then
		cat "${selected_logs[$index]}"
		exported="$export_retained/selected-puc-v3-slot$(printf '%02d' "$slot").tsv"
		target="$retained/selected-puc-v3-slot$(printf '%02d' "$slot").tsv"
		publish_result "$exported" "$target" "${stale_selected[$slot]:-0}"
		verify_result selected "$slot" "$target"
		selected_complete=$((selected_complete + 1))
		echo "WP40 T2 C1 v3 selected progress slot=$slot completed=$selected_complete/4 wall_seconds=$((SECONDS - selected_start))"
	else
		status=$?
		cat "${selected_logs[$index]}" >&2
		echo "WP40 T2 C1 v3 selected failed slot=$slot status=$status" >&2
		selected_failed=1
	fi
	rm -rf -- "${selected_scratches[$index]}" "${partition_scratches[$index]}"
done
if (( selected_failed != 0 || selected_complete != 4 )); then
	echo "WP40 T2 C1 v3 selected barrier failed completed=$selected_complete/4" >&2
	exit 1
fi
for slot in "${slots[@]}"; do
	verify_result selected "$slot" \
		"$retained/selected-puc-v3-slot$(printf '%02d' "$slot").tsv"
done
echo "WP40 T2 C1 v3 hard selected barrier passed completed=4/4"

"$lua" "$preflight" "$repo" "$scratch" "$commit" "$tree" >/dev/null
final_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-conformance-final.XXXXXXXX)"
"$lua" "$export_script/t2_extreme_conformance_finalize.lua" "$repo" \
	"$final_scratch" "$final_output" "$commit" "$tree" "$dag"
rm -rf -- "$final_scratch"
"$lua" "$preflight" "$repo" "$scratch" "$commit" "$tree" >/dev/null
echo "WP40 T2 C1 v3 conformance complete rescore=20/20 selected=4/4 stage2=pending_seed_corpus_promotion"
