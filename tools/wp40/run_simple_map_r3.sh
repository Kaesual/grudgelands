#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
mode="${WP40_R3_MODE:-full}"
lua_bin="${WP40_LUA_BIN:-$(command -v /usr/bin/luajit 2>/dev/null || true)}"
puc_bin="$repo/tools/bin/lua51"
luac_bin="$repo/tools/bin/luac51"
r2_artifact="$repo/docs/research/wp40-simple-map-r2-artifact.tsv"
r2_full_sha256="ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b"

case "$mode" in
	full|quick|preflight|selftest) ;;
	*) echo "run_simple_map_r3.sh: WP40_R3_MODE must be full, quick, preflight or selftest" >&2; exit 1 ;;
esac

command -v rg >/dev/null 2>&1 || {
	echo "run_simple_map_r3.sh: ripgrep (rg) is required" >&2
	exit 1
}
command -v chrt >/dev/null 2>&1 || {
	echo "run_simple_map_r3.sh: chrt is required" >&2
	exit 1
}
command -v ionice >/dev/null 2>&1 || {
	echo "run_simple_map_r3.sh: ionice is required" >&2
	exit 1
}
[[ -n "$lua_bin" && -x "$lua_bin" && -x "$puc_bin" && -x "$luac_bin" ]] || {
	echo "run_simple_map_r3.sh: selected Lua, lua51 and luac51 must be executable" >&2
	exit 1
}

# This cheap complete-file guard runs before either interpreter can load the
# vertical module. Lua then verifies the R2 body and all fifteen input rows.
[[ "$(sha256sum "$r2_artifact" | awk '{print $1}')" == "$r2_full_sha256" ]] || {
	echo "run_simple_map_r3.sh: accepted R2 artifact complete-file hash differs" >&2
	exit 1
}

height_file="$repo/mods/MAPGEN/grug_mapgen/wp40/height.lua"
if [[ "$mode" != selftest && ! -f "$height_file" ]]; then
	echo "run_simple_map_r3.sh: expected production height.lua is not integrated" >&2
	exit 1
fi

scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
child_pids=()
child_scratches=()
cleanup() {
	for pid in "${child_pids[@]}"; do
		kill "$pid" >/dev/null 2>&1 || true
		wait "$pid" >/dev/null 2>&1 || true
	done
	for directory in "${child_scratches[@]}"; do
		if [[ "$directory" == /tmp/grudgelands-wp40-simple-map.* ]]; then
			rm -rf -- "$directory"
		fi
	done
	if [[ "$scratch" == /tmp/grudgelands-wp40-simple-map.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT INT TERM

lua_files=(
	"$repo/tools/wp40/simple_map_r3_common.lua"
	"$repo/tools/wp40/simple_map_r3_offline.lua"
	"$repo/tools/wp40/simple_map_r3_validate.lua"
	"$repo/tools/wp40/simple_map_r3_artifact.lua"
	"$repo/tools/wp40/simple_map_r3_kat.lua"
	"$repo/tools/wp40/simple_map_r3_selftest.lua"
	"$repo/tools/wp40/simple_map_v1e_r3_preflight.lua"
)
if [[ "$mode" != selftest && -f "$height_file" ]]; then
	lua_files+=("$height_file")
fi
sandbox_no_execute_files=()
for file in "${lua_files[@]}"; do
	if [[ "$file" != "$repo/tools/wp40/simple_map_r3_offline.lua" ]]; then
		sandbox_no_execute_files+=("$file")
	fi
done

"$luac_bin" -p "${lua_files[@]}"
for file in "${lua_files[@]}"; do
	if "$luac_bin" -l -p -o /dev/null "$file" | rg -n 'SETGLOBAL'; then
		echo "run_simple_map_r3.sh: unexpected global write in $file" >&2
		exit 1
	fi
done
if rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${lua_files[@]}" ||
	rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${lua_files[@]}" ||
	rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${lua_files[@]}" ||
	rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' "${lua_files[@]}" ||
	rg -n '\brequire[[:space:]]*\(|io\.popen|os\.exit|\bminetest\.' "${lua_files[@]}" ||
	rg -n 'os\.execute' "${sandbox_no_execute_files[@]}"; then
	echo "run_simple_map_r3.sh: Lua 5.1 do-not-write sweep failed" >&2
	exit 1
fi
[[ "$(rg -c 'os\.execute' "$repo/tools/wp40/simple_map_r3_offline.lua")" -eq 1 ]] || {
	echo "run_simple_map_r3.sh: offline SHA seam changed" >&2
	exit 1
}
if [[ "$mode" != selftest && -f "$height_file" ]] &&
		rg -n 'os\.execute' "$height_file"; then
	echo "run_simple_map_r3.sh: production height invokes os.execute" >&2
	exit 1
fi

immutable_inputs=(
	"$r2_artifact"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/canonical.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/deterministic.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/schemas.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/simple_map.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"
	"${lua_files[@]}"
	"$repo/tools/wp40/run_simple_map_r3.sh"
)
if [[ -f "$height_file" ]]; then immutable_inputs+=("$height_file"); fi
input_state_sha256() {
	sha256sum "${immutable_inputs[@]}" | sha256sum | awk '{print $1}'
}
input_state_before="$(input_state_sha256)"

run_lua() {
	local interpreter="$1"
	shift
	if "$interpreter" -e 'assert(type(rawget(_G,"jit"))=="table")' >/dev/null 2>&1; then
		chrt --idle 0 ionice -c3 "$interpreter" \
			-e '_G.wp40_ffi=require("ffi")' "$@"
	else
		chrt --idle 0 ionice -c3 "$interpreter" "$@"
	fi
}

run_selftests() {
	local luajit_scratch puc_scratch
	luajit_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	puc_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	child_scratches+=("$luajit_scratch" "$puc_scratch")
	run_lua "$lua_bin" "$repo/tools/wp40/simple_map_r3_selftest.lua" \
		"$repo" "$luajit_scratch" >"$scratch/selftest-luajit.log" 2>&1 &
	local luajit_pid=$!
	child_pids+=("$luajit_pid")
	run_lua "$puc_bin" "$repo/tools/wp40/simple_map_r3_selftest.lua" \
		"$repo" "$puc_scratch" >"$scratch/selftest-puc51.log" 2>&1 &
	local puc_pid=$!
	child_pids+=("$puc_pid")
	local failed=0
	if ! wait "$luajit_pid"; then failed=1; fi
	if ! wait "$puc_pid"; then failed=1; fi
	cat "$scratch/selftest-luajit.log" "$scratch/selftest-puc51.log"
	[[ "$failed" -eq 0 ]] || return 1
}

run_preflight_batch() {
	local label="$1"
	local merged="$2"
	local pids=() shards=() logs=()
	local index
	for index in 1 2 3 4; do
		local worker_scratch
		worker_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
		child_scratches+=("$worker_scratch")
		local shard="$scratch/$label-seed-$index.tsv"
		local log="$scratch/$label-seed-$index.log"
		echo "r3_parallel_start preflight $label seed_index=$index"
		run_lua "$luajit_bin" \
			"$repo/tools/wp40/simple_map_v1e_r3_preflight.lua" \
			"$repo" "$worker_scratch" "$shard" shard "$index" \
			>"$log" 2>&1 &
		pids+=("$!")
		child_pids+=("$!")
		shards+=("$shard")
		logs+=("$log")
	done
	local failed=0
	for index in 0 1 2 3; do
		if ! wait "${pids[$index]}"; then failed=1; fi
		cat "${logs[$index]}"
	done
	[[ "$failed" -eq 0 ]] || return 1
	local merge_scratch
	merge_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	child_scratches+=("$merge_scratch")
	run_lua "$luajit_bin" "$repo/tools/wp40/simple_map_v1e_r3_preflight.lua" \
		"$repo" "$merge_scratch" "$merged" merge "${shards[@]}"
}

run_parallel_kats() {
	local luajit_output="$1"
	local puc_output="$2"
	local lj_pids=() puc_pids=() lj_shards=() puc_shards=() lj_logs=() puc_logs=()
	local index
	# Four PUC workers and three LuaJIT workers start together: seven total.
	for index in 1 2 3 4; do
		local worker_scratch
		worker_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
		child_scratches+=("$worker_scratch")
		local shard="$scratch/kat-puc51-seed-$index.tsv"
		local log="$scratch/kat-puc51-seed-$index.log"
		echo "r3_parallel_start kat puc51 seed_index=$index"
		run_lua "$puc_bin" "$repo/tools/wp40/simple_map_r3_kat.lua" \
			"$repo" "$worker_scratch" "$shard" shard "$index" \
			>"$log" 2>&1 &
		puc_pids+=("$!")
		child_pids+=("$!")
		puc_shards+=("$shard")
		puc_logs+=("$log")
	done
	for index in 1 2 3; do
		local worker_scratch
		worker_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
		child_scratches+=("$worker_scratch")
		local shard="$scratch/kat-luajit-seed-$index.tsv"
		local log="$scratch/kat-luajit-seed-$index.log"
		echo "r3_parallel_start kat luajit seed_index=$index"
		run_lua "$luajit_bin" "$repo/tools/wp40/simple_map_r3_kat.lua" \
			"$repo" "$worker_scratch" "$shard" shard "$index" \
			>"$log" 2>&1 &
		lj_pids+=("$!")
		child_pids+=("$!")
		lj_shards+=("$shard")
		lj_logs+=("$log")
	done
	local failed=0
	for index in 0 1 2; do
		if ! wait "${lj_pids[$index]}"; then failed=1; fi
		cat "${lj_logs[$index]}"
	done
	[[ "$failed" -eq 0 ]] || return 1
	local worker_scratch
	worker_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	child_scratches+=("$worker_scratch")
	local shard="$scratch/kat-luajit-seed-4.tsv"
	local log="$scratch/kat-luajit-seed-4.log"
	echo "r3_parallel_start kat luajit seed_index=4"
	run_lua "$luajit_bin" "$repo/tools/wp40/simple_map_r3_kat.lua" \
		"$repo" "$worker_scratch" "$shard" shard 4 >"$log" 2>&1 &
	lj_pids[3]=$!
	child_pids+=("$!")
	lj_shards[3]="$shard"
	lj_logs[3]="$log"
	for index in 0 1 2 3; do
		if ! wait "${puc_pids[$index]}"; then failed=1; fi
		cat "${puc_logs[$index]}"
	done
	if ! wait "${lj_pids[3]}"; then failed=1; fi
	cat "${lj_logs[3]}"
	[[ "$failed" -eq 0 ]] || return 1
	local lj_merge_scratch puc_merge_scratch
	lj_merge_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	puc_merge_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	child_scratches+=("$lj_merge_scratch" "$puc_merge_scratch")
	run_lua "$luajit_bin" "$repo/tools/wp40/simple_map_r3_kat.lua" \
		"$repo" "$lj_merge_scratch" "$luajit_output" merge \
		"${lj_shards[@]}"
	run_lua "$puc_bin" "$repo/tools/wp40/simple_map_r3_kat.lua" \
		"$repo" "$puc_merge_scratch" "$puc_output" merge \
		"${puc_shards[@]}"
}

start_epoch="$(date +%s)"
run_selftests
if [[ "$mode" == selftest ]]; then
	[[ "$(input_state_sha256)" == "$input_state_before" ]] || {
		echo "run_simple_map_r3.sh: immutable inputs changed during selftest" >&2
		exit 1
	}
	echo "WP40 simple-map R3 selftests passed"
	exit 0
fi

luajit_bin="$lua_bin"
if ! "$luajit_bin" -e 'assert(type(rawget(_G,"jit"))=="table")' >/dev/null 2>&1; then
	echo "run_simple_map_r3.sh: full/quick authority interpreter must be LuaJIT" >&2
	exit 1
fi

artifact_a="$scratch/simple-map-r3-a.tsv"
artifact_b="$scratch/simple-map-r3-b.tsv"
preflight_a="$scratch/simple-map-v1e-r3-preflight-a.tsv"
preflight_b="$scratch/simple-map-v1e-r3-preflight-b.tsv"
if [[ "$mode" == preflight ]]; then
	output="${1:-}"
	[[ -n "$output" ]] || {
		echo "usage: WP40_R3_MODE=preflight tools/wp40/run_simple_map_r3.sh OUTPUT.tsv" >&2
		exit 1
	}
	run_preflight_batch preflight-a "$preflight_a"
	if [[ -f "$output" ]]; then
		cmp -s "$preflight_a" "$output" || {
			echo "run_simple_map_r3.sh: fresh four-seed preflight differs from existing evidence" >&2
			exit 1
		}
	else
		run_preflight_batch preflight-b "$preflight_b"
		cmp -s "$preflight_a" "$preflight_b" || {
			echo "run_simple_map_r3.sh: repeated four-seed preflights differ" >&2
			exit 1
		}
		cp "$preflight_a" "$output"
	fi
elif [[ "$mode" == full ]]; then
	output="${1:-}"
	[[ -n "$output" ]] || {
		echo "usage: WP40_R3_MODE=full tools/wp40/run_simple_map_r3.sh OUTPUT.tsv" >&2
		exit 1
	}
	artifact_a_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	artifact_b_scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	child_scratches+=("$artifact_a_scratch" "$artifact_b_scratch")
	run_lua "$luajit_bin" "$repo/tools/wp40/simple_map_r3_artifact.lua" \
		"$repo" "$artifact_a_scratch" "$artifact_a" full >"$scratch/artifact-a.log" 2>&1 &
	artifact_a_pid=$!
	child_pids+=("$artifact_a_pid")
	run_lua "$luajit_bin" "$repo/tools/wp40/simple_map_r3_artifact.lua" \
		"$repo" "$artifact_b_scratch" "$artifact_b" full >"$scratch/artifact-b.log" 2>&1 &
	artifact_b_pid=$!
	child_pids+=("$artifact_b_pid")
	artifact_failed=0
	if ! wait "$artifact_a_pid"; then artifact_failed=1; fi
	if ! wait "$artifact_b_pid"; then artifact_failed=1; fi
	cat "$scratch/artifact-a.log" "$scratch/artifact-b.log"
	[[ "$artifact_failed" -eq 0 ]] || exit 1
	cmp -s "$artifact_a" "$artifact_b" || {
		echo "run_simple_map_r3.sh: repeated exhaustive artifacts differ" >&2
		exit 1
	}
	cp "$artifact_a" "$output"
else
	run_lua "$luajit_bin" "$repo/tools/wp40/simple_map_r3_artifact.lua" \
		"$repo" "$scratch" "$artifact_a" quick
fi

luajit_kat="$scratch/r3-kat-luajit.tsv"
puc_kat="$scratch/r3-kat-puc51.tsv"
run_parallel_kats "$luajit_kat" "$puc_kat"
cmp -s "$luajit_kat" "$puc_kat" || {
	echo "run_simple_map_r3.sh: LuaJIT and targeted PUC KAT bytes differ" >&2
	exit 1
}
[[ "$(input_state_sha256)" == "$input_state_before" ]] || {
	echo "run_simple_map_r3.sh: immutable inputs changed during parallel run" >&2
	exit 1
}

end_epoch="$(date +%s)"
echo -e "r3_timing_unbound\twall_seconds\t$((end_epoch-start_epoch))"
echo -e "r3_runtime_unbound\tauthority\t$($luajit_bin -v 2>&1 | head -n 1)"
echo -e "r3_runtime_unbound\tpuc\t$($puc_bin -v 2>&1 | head -n 1)"
printf 'r3_targeted_kat_file_sha256\t%s\n' \
	"$(sha256sum "$luajit_kat" | awk '{print $1}')"
if [[ "$mode" == preflight ]]; then
	printf 'v1e_r3_preflight_file_sha256\t%s\n' \
		"$(sha256sum "$output" | awk '{print $1}')"
	echo "WP40 simple-map V1e four-seed R3 preflight and targeted PUC parity passed"
elif [[ "$mode" == full ]]; then
	printf 'r3_artifact_file_sha256\t%s\n' \
		"$(sha256sum "$output" | awk '{print $1}')"
	echo "WP40 simple-map R3 exhaustive artifact and targeted PUC parity passed"
else
	echo "WP40 simple-map R3 quick integration and targeted PUC parity passed"
fi
