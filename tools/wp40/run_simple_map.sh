#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
lua_requested="${WP40_LUA_BIN:-/usr/bin/luajit}"
lua_bin="$(command -v "$lua_requested" 2>/dev/null || true)"
puc_bin="$repo/tools/bin/lua51"
luac_bin="$repo/tools/bin/luac51"
output="${1:-$repo/docs/research/wp40-simple-map-v1e-preview.svg}"

command -v rg >/dev/null 2>&1 || {
	echo "run_simple_map.sh: ripgrep (rg) is required" >&2
	exit 1
}
command -v xmllint >/dev/null 2>&1 || {
	echo "run_simple_map.sh: xmllint is required" >&2
	exit 1
}
command -v chrt >/dev/null 2>&1 || {
	echo "run_simple_map.sh: chrt is required" >&2
	exit 1
}
command -v ionice >/dev/null 2>&1 || {
	echo "run_simple_map.sh: ionice is required" >&2
	exit 1
}
[[ -n "$lua_bin" && -x "$lua_bin" && -x "$puc_bin" && -x "$luac_bin" ]] || {
	echo "run_simple_map.sh: LuaJIT and vendored PUC tools must be executable" >&2
	exit 1
}
[[ "$(readlink -f -- "$lua_bin")" != "$(readlink -f -- "$puc_bin")" ]] || {
	echo "run_simple_map.sh: development and PUC interpreters must differ" >&2
	exit 1
}
"$lua_bin" -e 'assert(type(rawget(_G,"jit"))=="table")'

canonical_output="$repo/docs/research/wp40-simple-map-v1e-preview.svg"
[[ "$output" == "$canonical_output" ]] || {
	echo "run_simple_map.sh: output must be $canonical_output" >&2
	exit 1
}

declare -a scratch_dirs=()
declare -a worker_pids=()
declare -a worker_labels=()
declare -a worker_stdout=()
declare -a worker_stderr=()
coordinator_scratch=""
full_scratch=""
render_a_scratch=""
render_b_scratch=""
worker_scratch=""
full_job=""
render_a_job=""
render_b_job=""
job_index=""

allocate_scratch() {
	local variable="$1"
	local directory
	directory="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
	[[ "$directory" =~ ^/tmp/grudgelands-wp40-simple-map\.[A-Za-z0-9]+$ ]] || {
		echo "run_simple_map.sh: mktemp returned unsafe scratch path" >&2
		exit 1
	}
	scratch_dirs+=("$directory")
	printf -v "$variable" '%s' "$directory"
}

cleanup() {
	local status=$?
	local index pid directory
	trap - EXIT INT TERM
	for index in "${!worker_pids[@]}"; do
		pid="${worker_pids[$index]-}"
		[[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true
	done
	for index in "${!worker_pids[@]}"; do
		pid="${worker_pids[$index]-}"
		[[ -z "$pid" ]] || wait "$pid" 2>/dev/null || true
	done
	for directory in "${scratch_dirs[@]}"; do
		if [[ "$directory" =~ ^/tmp/grudgelands-wp40-simple-map\.[A-Za-z0-9]+$ &&
				-d "$directory" ]]; then
			rm -rf -- "$directory"
		fi
	done
	exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

launch_job() {
	local result_variable="$1"
	local label="$2"
	local stdout_path="$3"
	local stderr_path="$4"
	local index pid
	shift 4
	chrt --idle 0 ionice -c3 "$@" >"$stdout_path" 2>"$stderr_path" &
	pid=$!
	index=${#worker_pids[@]}
	worker_pids+=("$pid")
	worker_labels+=("$label")
	worker_stdout+=("$stdout_path")
	worker_stderr+=("$stderr_path")
	printf -v "$result_variable" '%s' "$index"
}

wait_job() {
	local index="$1"
	local pid="${worker_pids[$index]-}"
	local status
	[[ -n "$pid" ]] || return 0
	if wait "$pid"; then
		worker_pids[index]=""
		return 0
	else
		status=$?
		worker_pids[index]=""
		echo "run_simple_map.sh: ${worker_labels[$index]} failed (status $status)" >&2
		if [[ -s "${worker_stderr[$index]}" ]]; then
			sed 's/^/  /' "${worker_stderr[$index]}" >&2
		fi
		return "$status"
	fi
}

lua_files=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/schemas.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/canonical.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/deterministic.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/simple_map.lua"
	"$repo/tools/wp40/simple_map_offline.lua"
	"$repo/tools/wp40/simple_map_test.lua"
	"$repo/tools/wp40/render_simple_map_svg.lua"
	"$repo/tools/wp40/simple_map_v1e_anchor_migration.lua"
	"$repo/tools/wp40/simple_map_v1e_baseline_diagnosis.lua"
)
allocate_scratch coordinator_scratch
immutable_inputs=(
	"$script_dir/run_simple_map.sh"
	"${lua_files[@]}"
	"$(readlink -f -- "$lua_bin")"
	"$(readlink -f -- "$puc_bin")"
	"$(readlink -f -- "$luac_bin")"
)
input_manifest="$coordinator_scratch/input.sha256"
sha256sum -- "${immutable_inputs[@]}" >"$input_manifest"

"$luac_bin" -p "${lua_files[@]}"
for file in "${lua_files[@]}"; do
	if "$luac_bin" -l -p "$file" | rg -n 'SETGLOBAL'; then
		echo "run_simple_map.sh: unexpected global write in $file" >&2
		exit 1
	fi
done

if rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${lua_files[@]}" ||
	rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${lua_files[@]}" ||
	rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${lua_files[@]}" ||
	rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' "${lua_files[@]}" ||
	rg -n '\brequire[[:space:]]*\(|io\.popen|os\.exit|\bminetest\.' "${lua_files[@]}"; then
	echo "run_simple_map.sh: Lua 5.1 do-not-write sweep failed" >&2
	exit 1
fi
[[ "$(rg -c 'os\.execute' "$repo/tools/wp40/simple_map_offline.lua")" -eq 1 ]] || {
	echo "run_simple_map.sh: offline SHA seam changed" >&2
	exit 1
}
if rg -n 'os\.execute' "$repo/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua" \
		"$repo/mods/MAPGEN/grug_mapgen/wp40/simple_map.lua"; then
	echo "run_simple_map.sh: production simple map invokes os.execute" >&2
	exit 1
fi

# The full test and the two repeat renders are independent.  Each gets a
# top-level scratch because the offline loader deliberately rejects nested
# scratch paths.  The canonical SVG is not written until every gate passes.
allocate_scratch full_scratch
allocate_scratch render_a_scratch
allocate_scratch render_b_scratch
launch_job full_job "full LuaJIT test" "$full_scratch/full.txt" \
	"$full_scratch/full.stderr" "$lua_bin" \
	"$repo/tools/wp40/simple_map_test.lua" "$repo" "$full_scratch" --full
launch_job render_a_job "first SVG render" "$render_a_scratch/render.txt" \
	"$render_a_scratch/render.stderr" "$lua_bin" \
	"$repo/tools/wp40/render_simple_map_svg.lua" "$repo" "$render_a_scratch" \
	"$render_a_scratch/preview.svg" 0
launch_job render_b_job "second SVG render" "$render_b_scratch/render.txt" \
	"$render_b_scratch/render.stderr" "$lua_bin" \
	"$repo/tools/wp40/render_simple_map_svg.lua" "$repo" "$render_b_scratch" \
	"$render_b_scratch/preview.svg" 0
wait_job "$full_job"
wait_job "$render_a_job"
wait_job "$render_b_job"
cmp "$render_a_scratch/preview.svg" "$render_b_scratch/preview.svg"
xmllint --noout "$render_a_scratch/preview.svg"

# Start all four PUC workers and three LuaJIT workers: exactly seven Lua
# processes.  Waiting for one LuaJIT worker releases a slot for the fourth.
# The final comparisons happen only after all workers finish, in canonical
# seed order, so completion order cannot affect the result.
kat_seeds=(0 1 9223372036854775808 18446744073709551615)
declare -a puc_jobs=()
declare -a luajit_jobs=()
declare -a puc_outputs=()
declare -a luajit_outputs=()
for seed_index in "${!kat_seeds[@]}"; do
	seed="${kat_seeds[$seed_index]}"
	allocate_scratch worker_scratch
	puc_outputs[seed_index]="$worker_scratch/kat.txt"
	launch_job job_index "PUC KAT seed $seed" "${puc_outputs[$seed_index]}" \
		"$worker_scratch/kat.stderr" "$puc_bin" \
		"$repo/tools/wp40/simple_map_test.lua" "$repo" "$worker_scratch" \
		--kat "$seed"
	puc_jobs[seed_index]="$job_index"
done
for seed_index in 0 1 2; do
	seed="${kat_seeds[$seed_index]}"
	allocate_scratch worker_scratch
	luajit_outputs[seed_index]="$worker_scratch/kat.txt"
	launch_job job_index "LuaJIT KAT seed $seed" \
		"${luajit_outputs[$seed_index]}" "$worker_scratch/kat.stderr" \
		"$lua_bin" "$repo/tools/wp40/simple_map_test.lua" "$repo" \
		"$worker_scratch" --kat "$seed"
	luajit_jobs[seed_index]="$job_index"
done
wait_job "${luajit_jobs[0]}"
seed_index=3
seed="${kat_seeds[$seed_index]}"
allocate_scratch worker_scratch
luajit_outputs[seed_index]="$worker_scratch/kat.txt"
launch_job job_index "LuaJIT KAT seed $seed" \
	"${luajit_outputs[$seed_index]}" "$worker_scratch/kat.stderr" \
	"$lua_bin" "$repo/tools/wp40/simple_map_test.lua" "$repo" \
	"$worker_scratch" --kat "$seed"
luajit_jobs[seed_index]="$job_index"

for job_index in "${puc_jobs[@]}"; do wait_job "$job_index"; done
for job_index in "${luajit_jobs[@]}"; do wait_job "$job_index"; done
for seed_index in "${!kat_seeds[@]}"; do
	seed="${kat_seeds[$seed_index]}"
	cmp "${luajit_outputs[$seed_index]}" "${puc_outputs[$seed_index]}" || {
		echo "run_simple_map.sh: interpreter KAT differs for seed $seed" >&2
		exit 1
	}
done

if ! sha256sum --check --status "$input_manifest"; then
	echo "run_simple_map.sh: an immutable runner input changed during execution" >&2
	exit 1
fi
cp "$render_a_scratch/preview.svg" "$output"
xmllint --noout "$output"

cat "$full_scratch/full.txt"
for seed_index in "${!kat_seeds[@]}"; do
	seed="${kat_seeds[$seed_index]}"
	printf 'seed\t%s\t' "$seed"
	cat "${luajit_outputs[$seed_index]}"
done
sha256sum "$output"
echo "svg\t$output"
