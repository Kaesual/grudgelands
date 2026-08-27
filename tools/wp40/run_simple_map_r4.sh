#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
mode="${WP40_R4_MODE:-selftest}"
lua_bin="${WP40_LUA_BIN:-$(command -v /usr/bin/luajit 2>/dev/null || true)}"
puc_bin="$repo/tools/bin/lua51"
luac_bin="$repo/tools/bin/luac51"

case "$mode" in
	selftest|kat|quick|full) ;;
	*) echo "run_simple_map_r4.sh: mode must be selftest, kat, quick or full" >&2; exit 1 ;;
esac

for command_name in rg chrt ionice sha256sum sort awk; do
	command -v "$command_name" >/dev/null 2>&1 || {
		echo "run_simple_map_r4.sh: $command_name is required" >&2
		exit 1
	}
done
[[ -n "$lua_bin" && -x "$lua_bin" && -x "$puc_bin" && -x "$luac_bin" ]] || {
	echo "run_simple_map_r4.sh: selected Lua, lua51 and luac51 must be executable" >&2
	exit 1
}

scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
declare -A active_pids=()
child_scratches=()
promotion_tmp=""
cleanup() {
	for pid in "${!active_pids[@]}"; do
		kill "$pid" >/dev/null 2>&1 || true
		wait "$pid" >/dev/null 2>&1 || true
		unset "active_pids[$pid]"
	done
	for directory in "${child_scratches[@]}"; do
		case "$directory" in
			/tmp/grudgelands-wp40-simple-map.*|/tmp/grudgelands-wp40-t1.*|/tmp/grudgelands-wp40-t2-schema.*)
				rm -rf -- "$directory" ;;
		esac
	done
	if [[ "$scratch" == /tmp/grudgelands-wp40-simple-map.* ]]; then
		rm -rf -- "$scratch"
	fi
	if [[ -n "$promotion_tmp" ]]; then
		rm -f -- "$promotion_tmp"
	fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

track_pid() {
	active_pids["$1"]=1
}

wait_tracked() {
	local pid="$1"
	local status=0
	wait "$pid" || status=$?
	unset "active_pids[$pid]"
	return "$status"
}

lua_files=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/index128.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/zones.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/init.lua"
	"$repo/tools/wp40/simple_map_r4_common.lua"
	"$repo/tools/wp40/simple_map_r4_offline.lua"
	"$repo/tools/wp40/simple_map_r4_validate.lua"
	"$repo/tools/wp40/simple_map_r4_artifact.lua"
	"$repo/tools/wp40/simple_map_r4_kat.lua"
	"$repo/tools/wp40/simple_map_r4_selftest.lua"
	"$repo/tools/wp40/t1_foundation_test.lua"
	"$repo/tools/wp40/t2_schema_core_test.lua"
)
for file in "${lua_files[@]}"; do
	[[ -f "$file" ]] || {
		echo "run_simple_map_r4.sh: required Lua file missing: $file" >&2
		exit 1
	}
done

"$luac_bin" -p "${lua_files[@]}"
for file in "${lua_files[@]}"; do
	if "$luac_bin" -l -p -o /dev/null "$file" | rg -n 'SETGLOBAL'; then
		echo "run_simple_map_r4.sh: unexpected global write in $file" >&2
		exit 1
	fi
done
if rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${lua_files[@]}" ||
	rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${lua_files[@]}" ||
	rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${lua_files[@]}" ||
	rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' "${lua_files[@]}" ||
	rg -n '\brequire[[:space:]]*\(|io\.popen|os\.exit|\bminetest\.' "${lua_files[@]}"; then
	echo "run_simple_map_r4.sh: Lua 5.1 do-not-write sweep failed" >&2
	exit 1
fi
for file in "${lua_files[@]}"; do
	case "$file" in
		"$repo/tools/wp40/simple_map_r4_offline.lua"|"$repo/tools/wp40/t1_foundation_test.lua"|"$repo/tools/wp40/t2_schema_core_test.lua")
			continue ;;
	esac
	if rg -n 'os\.execute' "$file"; then
		echo "run_simple_map_r4.sh: os.execute escaped the offline SHA seam" >&2
		exit 1
	fi
done
for offline_helper in \
	"$repo/tools/wp40/simple_map_r4_offline.lua" \
	"$repo/tools/wp40/t1_foundation_test.lua" \
	"$repo/tools/wp40/t2_schema_core_test.lua"; do
	[[ "$(rg -c 'os\.execute' "$offline_helper")" -eq 1 ]] || {
		echo "run_simple_map_r4.sh: offline SHA seam changed: $offline_helper" >&2
		exit 1
	}
done
if rg -n '(^|[^[:alnum:]_])grug_zones([^[:alnum:]_]|$)' \
		"$repo/mods/MAPGEN/grug_mapgen/wp40" --glob '*.lua'; then
	echo "run_simple_map_r4.sh: forbidden live registry token found" >&2
	exit 1
fi
bash -n "$repo/tools/wp40/run_simple_map_r4.sh"

mapfile -t accepted_relative_inputs < <(
	awk -F '\t' '$1 == "input_sha256" {print $2}' \
		"$repo/docs/research/wp40-simple-map-r2-artifact.tsv" \
		"$repo/docs/research/wp40-simple-map-r3-artifact.tsv" | LC_ALL=C sort -u
)
[[ "${#accepted_relative_inputs[@]}" -eq 23 ]] || {
	echo "run_simple_map_r4.sh: accepted authority input union is not 23 files" >&2
	exit 1
}
accepted_absolute_inputs=()
for relative in "${accepted_relative_inputs[@]}"; do
	[[ -n "$relative" && "$relative" != /* && "$relative" != .. &&
		"$relative" != ../* && "$relative" != */../* && "$relative" != */.. &&
		-f "$repo/$relative" ]] || {
		echo "run_simple_map_r4.sh: unsafe/missing accepted input: $relative" >&2
		exit 1
	}
	accepted_absolute_inputs+=("$repo/$relative")
done
immutable_candidates=(
	"$repo/docs/research/wp40-simple-map-r2-artifact.tsv"
	"$repo/docs/research/wp40-simple-map-r3-artifact.tsv"
	"$repo/docs/research/wp40-simple-map-r4-contract.md"
	"${accepted_absolute_inputs[@]}"
	"${lua_files[@]}"
	"$repo/tools/wp40/run_simple_map_r4.sh"
)
mapfile -t immutable_inputs < <(
	printf '%s\n' "${immutable_candidates[@]}" | LC_ALL=C sort -u
)
input_state_sha256() {
	sha256sum "${immutable_inputs[@]}" | sha256sum | awk '{print $1}'
}
input_state_before="$(input_state_sha256)"

run_lua() {
	local interpreter="$1"
	shift
	if "$interpreter" -e 'assert(type(rawget(_G,"jit"))=="table")' \
			>/dev/null 2>&1; then
		chrt --idle 0 ionice -c3 "$interpreter" \
			-e '_G.wp40_ffi=require("ffi")' "$@"
	else
		chrt --idle 0 ionice -c3 "$interpreter" "$@"
	fi
}

run_initial_tests() {
	local lj_scratch puc_scratch t1_scratch schema_scratch
	local lj_pid puc_pid t1_pid schema_pid failed
	lj_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	puc_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	t1_scratch="$(mktemp -d /tmp/grudgelands-wp40-t1.XXXXXXXX)"
	schema_scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-schema.XXXXXXXX)"
	child_scratches+=("$lj_scratch" "$puc_scratch" "$t1_scratch" "$schema_scratch")
	run_lua "$lua_bin" "$repo/tools/wp40/simple_map_r4_selftest.lua" \
		"$repo" "$lj_scratch" >"$scratch/selftest-luajit.log" 2>&1 &
	lj_pid=$!
	track_pid "$lj_pid"
	run_lua "$puc_bin" "$repo/tools/wp40/simple_map_r4_selftest.lua" \
		"$repo" "$puc_scratch" >"$scratch/selftest-puc51.log" 2>&1 &
	puc_pid=$!
	track_pid "$puc_pid"
	run_lua "$puc_bin" "$repo/tools/wp40/t1_foundation_test.lua" \
		"$repo" "$t1_scratch" >"$scratch/foundation-t1.log" 2>&1 &
	t1_pid=$!
	track_pid "$t1_pid"
	run_lua "$puc_bin" "$repo/tools/wp40/t2_schema_core_test.lua" \
		"$repo" "$schema_scratch" >"$scratch/schema-core-t2.log" 2>&1 &
	schema_pid=$!
	track_pid "$schema_pid"
	failed=0
	if ! wait_tracked "$lj_pid"; then failed=1; fi
	if ! wait_tracked "$puc_pid"; then failed=1; fi
	if ! wait_tracked "$t1_pid"; then failed=1; fi
	if ! wait_tracked "$schema_pid"; then failed=1; fi
	cat "$scratch/selftest-luajit.log" "$scratch/selftest-puc51.log" \
		"$scratch/foundation-t1.log" "$scratch/schema-core-t2.log"
	[[ "$failed" -eq 0 ]]
}

run_parallel_kats() {
	local lj_output="$1"
	local puc_output="$2"
	local -a lj_pids=() puc_pids=() lj_shards=() puc_shards=()
	local -a lj_logs=() puc_logs=()
	local index worker_scratch shard log failed
	local lj_merge_pid puc_merge_pid
	# Four PUC and three LuaJIT workers are the initial seven-process fleet.
	for index in 1 2 3 4; do
		worker_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
		child_scratches+=("$worker_scratch")
		shard="$scratch/kat-puc51-seed-$index.tsv"
		log="$scratch/kat-puc51-seed-$index.log"
		run_lua "$puc_bin" "$repo/tools/wp40/simple_map_r4_kat.lua" \
			"$repo" "$worker_scratch" "$shard" shard "$index" >"$log" 2>&1 &
		puc_pids+=("$!")
		track_pid "$!"
		puc_shards+=("$shard")
		puc_logs+=("$log")
	done
	for index in 1 2 3; do
		worker_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
		child_scratches+=("$worker_scratch")
		shard="$scratch/kat-luajit-seed-$index.tsv"
		log="$scratch/kat-luajit-seed-$index.log"
		run_lua "$lua_bin" "$repo/tools/wp40/simple_map_r4_kat.lua" \
			"$repo" "$worker_scratch" "$shard" shard "$index" >"$log" 2>&1 &
		lj_pids+=("$!")
		track_pid "$!"
		lj_shards+=("$shard")
		lj_logs+=("$log")
	done
	failed=0
	if ! wait_tracked "${lj_pids[0]}"; then failed=1; fi
	if [[ "$failed" -ne 0 ]]; then
		cat "${lj_logs[0]}"
		return 1
	fi
	worker_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	child_scratches+=("$worker_scratch")
	shard="$scratch/kat-luajit-seed-4.tsv"
	log="$scratch/kat-luajit-seed-4.log"
	run_lua "$lua_bin" "$repo/tools/wp40/simple_map_r4_kat.lua" \
		"$repo" "$worker_scratch" "$shard" shard 4 >"$log" 2>&1 &
	lj_pids+=("$!")
	track_pid "$!"
	lj_shards+=("$shard")
	lj_logs+=("$log")
	cat "${lj_logs[0]}"
	for index in 1 2; do
		if ! wait_tracked "${lj_pids[$index]}"; then failed=1; fi
		cat "${lj_logs[$index]}"
	done
	[[ "$failed" -eq 0 ]] || return 1
	for index in 0 1 2 3; do
		if ! wait_tracked "${puc_pids[$index]}"; then failed=1; fi
		cat "${puc_logs[$index]}"
	done
	if ! wait_tracked "${lj_pids[3]}"; then failed=1; fi
	cat "${lj_logs[3]}"
	[[ "$failed" -eq 0 ]] || return 1
	local lj_merge_scratch puc_merge_scratch
	lj_merge_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	puc_merge_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	child_scratches+=("$lj_merge_scratch" "$puc_merge_scratch")
	run_lua "$lua_bin" "$repo/tools/wp40/simple_map_r4_kat.lua" \
		"$repo" "$lj_merge_scratch" "$lj_output" merge "${lj_shards[@]}" \
		>"$scratch/kat-luajit-merge.log" 2>&1 &
	lj_merge_pid=$!
	track_pid "$lj_merge_pid"
	run_lua "$puc_bin" "$repo/tools/wp40/simple_map_r4_kat.lua" \
		"$repo" "$puc_merge_scratch" "$puc_output" merge "${puc_shards[@]}" \
		>"$scratch/kat-puc51-merge.log" 2>&1 &
	puc_merge_pid=$!
	track_pid "$puc_merge_pid"
	failed=0
	if ! wait_tracked "$lj_merge_pid"; then failed=1; fi
	if ! wait_tracked "$puc_merge_pid"; then failed=1; fi
	cat "$scratch/kat-luajit-merge.log" "$scratch/kat-puc51-merge.log"
	[[ "$failed" -eq 0 ]]
}

fleet_shards=()
run_extent_fleet() {
	local label="$1"
	local -a pids=() logs=()
	local total_rows base_rows remainder next_z index rows max_z
	local worker_scratch shard log failed
	total_rows=$((3340 - (-3340) + 1))
	base_rows=$((total_rows / 7))
	remainder=$((total_rows % 7))
	next_z=-3340
	fleet_shards=()
	for index in 1 2 3 4 5 6 7; do
		rows=$base_rows
		if (( index <= remainder )); then rows=$((rows + 1)); fi
		max_z=$((next_z + rows - 1))
		worker_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
		child_scratches+=("$worker_scratch")
		shard="$scratch/$label-extent-$index.tsv"
		log="$scratch/$label-extent-$index.log"
		run_lua "$lua_bin" "$repo/tools/wp40/simple_map_r4_artifact.lua" \
			"$repo" "$worker_scratch" "$shard" shard "$next_z" "$max_z" \
			>"$log" 2>&1 &
		pids+=("$!")
		track_pid "$!"
		logs+=("$log")
		fleet_shards+=("$shard")
		next_z=$((max_z + 1))
	done
	[[ "$next_z" -eq 3341 ]] || return 1
	failed=0
	for index in 0 1 2 3 4 5 6; do
		if ! wait_tracked "${pids[$index]}"; then failed=1; fi
		cat "${logs[$index]}"
	done
	[[ "$failed" -eq 0 ]]
}

start_epoch="$(date +%s)"
run_initial_tests
if [[ "$mode" == selftest ]]; then
	input_state_after="$(input_state_sha256)"
	[[ "$input_state_after" == "$input_state_before" ]] || {
		echo "run_simple_map_r4.sh: immutable inputs changed during selftest" >&2
		exit 1
	}
	printf 'r4_input_state_unbound\tbefore\t%s\n' "$input_state_before"
	printf 'r4_input_state_unbound\tafter\t%s\n' "$input_state_after"
	echo "WP40 simple-map R4 tooling selftests passed"
	exit 0
fi

if ! "$lua_bin" -e 'assert(type(rawget(_G,"jit"))=="table")' \
		>/dev/null 2>&1; then
	echo "run_simple_map_r4.sh: selected authority interpreter must be LuaJIT" >&2
	exit 1
fi

staged_artifact=""
if [[ "$mode" == quick ]]; then
	quick_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	child_scratches+=("$quick_scratch")
	run_lua "$lua_bin" "$repo/tools/wp40/simple_map_r4_artifact.lua" \
		"$repo" "$quick_scratch" "$scratch/quick-extent.tsv" shard 0 0
elif [[ "$mode" == full ]]; then
	output="${1:-}"
	[[ -n "$output" ]] || {
		echo "usage: WP40_R4_MODE=full tools/wp40/run_simple_map_r4.sh OUTPUT.tsv" >&2
		exit 1
	}
	output_dir="$(cd "$(dirname -- "$output")" && pwd -P)"
	output_base="$(basename -- "$output")"
	output="$output_dir/$output_base"
	[[ -d "$output_dir" && -n "$output_base" && "$output_base" != . &&
		"$output_base" != .. ]] || {
		echo "run_simple_map_r4.sh: output directory/path is invalid" >&2
		exit 1
	}
	[[ "$output" == "$repo/docs/research/wp40-simple-map-r4-artifact.tsv" ]] || {
		echo "run_simple_map_r4.sh: full mode promotes only the canonical R4 artifact" >&2
		exit 1
	}
	artifact_a="$scratch/simple-map-r4-a.tsv"
	artifact_b="$scratch/simple-map-r4-b.tsv"
	run_extent_fleet artifact-a
	merge_a_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	child_scratches+=("$merge_a_scratch")
	run_lua "$lua_bin" "$repo/tools/wp40/simple_map_r4_artifact.lua" \
		"$repo" "$merge_a_scratch" "$artifact_a" merge "${fleet_shards[@]}"
	run_extent_fleet artifact-b
	merge_b_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	child_scratches+=("$merge_b_scratch")
	run_lua "$lua_bin" "$repo/tools/wp40/simple_map_r4_artifact.lua" \
		"$repo" "$merge_b_scratch" "$artifact_b" merge "${fleet_shards[@]}"
	cmp -s "$artifact_a" "$artifact_b" || {
		echo "run_simple_map_r4.sh: repeated exhaustive artifacts differ" >&2
		exit 1
	}
	staged_artifact="$artifact_a"
fi

luajit_kat="$scratch/r4-kat-luajit.tsv"
puc_kat="$scratch/r4-kat-puc51.tsv"
run_parallel_kats "$luajit_kat" "$puc_kat"
cmp -s "$luajit_kat" "$puc_kat" || {
	echo "run_simple_map_r4.sh: LuaJIT and targeted PUC KAT bytes differ" >&2
	exit 1
}
input_state_after="$(input_state_sha256)"
[[ "$input_state_after" == "$input_state_before" ]] || {
	echo "run_simple_map_r4.sh: immutable inputs changed during run" >&2
	exit 1
}

if [[ "$mode" == full ]]; then
	promotion_tmp="$(mktemp "$output_dir/.${output_base}.wp40-r4.XXXXXXXX")"
	cp "$staged_artifact" "$promotion_tmp"
	cmp -s "$staged_artifact" "$promotion_tmp" || {
		echo "run_simple_map_r4.sh: staged promotion bytes differ" >&2
		exit 1
	}
	chmod 0644 "$promotion_tmp"
	mv -f -- "$promotion_tmp" "$output"
	promotion_tmp=""
	printf 'r4_artifact_file_sha256\t%s\n' \
		"$(sha256sum "$output" | awk '{print $1}')"
fi
end_epoch="$(date +%s)"
printf 'r4_timing_unbound\twall_seconds\t%s\n' "$((end_epoch - start_epoch))"
printf 'r4_runtime_unbound\tauthority\t%s\n' "$("$lua_bin" -v 2>&1)"
printf 'r4_runtime_unbound\tpuc\t%s\n' "$("$puc_bin" -v 2>&1)"
printf 'r4_input_state_unbound\tbefore\t%s\n' "$input_state_before"
printf 'r4_input_state_unbound\tafter\t%s\n' "$input_state_after"
printf 'r4_targeted_kat_file_sha256\t%s\n' \
	"$(sha256sum "$luajit_kat" | awk '{print $1}')"
if [[ "$mode" == full ]]; then
	echo "WP40 simple-map R4 exhaustive artifact and targeted PUC parity passed"
elif [[ "$mode" == quick ]]; then
	echo "WP40 simple-map R4 quick extent and targeted PUC parity passed"
else
	echo "WP40 simple-map R4 targeted PUC parity passed"
fi
