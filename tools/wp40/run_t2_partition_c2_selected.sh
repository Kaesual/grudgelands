#!/usr/bin/env bash
set -euo pipefail

# A missing rg would make every check below pass vacuously: exit status 127 in
# an `if` condition reads exactly like "no match found". Fail loudly instead.
command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}

no_cache="${WP40_NO_CACHE:-0}"
if (( $# == 1 )) && [[ "$1" == --no-cache ]]; then
	no_cache=1
elif (( $# != 0 )); then
	echo "usage: tools/wp40/run_t2_partition_c2_selected.sh [--no-cache]" >&2
	exit 2
fi
if [[ "$no_cache" != 0 && "$no_cache" != 1 ]]; then
	echo "WP40_NO_CACHE must be 0 or 1" >&2
	exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
lua_bin="${WP40_C2_LUA_BIN:-/usr/bin/luajit}"
if [[ "$lua_bin" != /usr/bin/luajit || ! -x "$lua_bin" ]]; then
	echo "WP40 T2 C2 selected diagnostics require exact /usr/bin/luajit" >&2
	exit 2
fi

"$repo/tools/bin/luac51" -p \
	"$script_dir/t2_partition_test.lua" \
	"$script_dir/t2_partition_oracle.lua" \
	"$script_dir/t2_partition_c2_selected.lua" \
	"$script_dir/t2_payload_cache.lua" \
	"$script_dir/t2_phase_selector.lua"
if "$repo/tools/bin/luac51" -l -p \
	"$script_dir/t2_partition_c2_selected.lua" | rg -q 'SETGLOBAL'; then
	echo "WP40 T2 C2 selected diagnostic wrapper writes a global" >&2
	exit 1
fi

patterns=(
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
	'\\u\{|\\x[0-9A-Fa-f]|\\z'
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for pattern in "${patterns[@]}"; do
	if grep -nE "$pattern" "$script_dir/t2_partition_c2_selected.lua"; then
		echo "WP40 T2 C2 selected diagnostic wrapper uses a forbidden Lua construct" >&2
		exit 1
	fi
done

run_root="$(mktemp -d -p /tmp grudgelands-wp40-t2-partition.XXXXXXXX)"
cache_dir="$repo/tools/wp40/results/payload-cache"
mkdir -p "$cache_dir"
cleanup() {
	if [[ "$run_root" == /tmp/grudgelands-wp40-t2-partition.* ]]; then
		rm -rf -- "$run_root"
	fi
	for worker_scratch in "${worker_scratches[@]:-}"; do
		if [[ "$worker_scratch" == /tmp/grudgelands-wp40-t2-partition.* ]]; then
			rm -rf -- "$worker_scratch"
		fi
	done
}
trap cleanup EXIT

pids=()
worker_scratches=()
for slot in 28 29 30 31; do
	scratch="$run_root/$slot"
	mkdir "$scratch"
	# The test accepts only the canonical scratch basename, so each worker gets
	# a sibling canonical directory rather than the orchestration parent.
	worker_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-partition.XXXXXXXX)"
	worker_scratches+=("$worker_scratch")
	WP40_NO_CACHE="$no_cache" WP40_PAYLOAD_CACHE_DIR="$cache_dir" \
	WP40_T2_ONLY=selected_diagnostic \
	"$lua_bin" "$script_dir/t2_partition_c2_selected.lua" \
		"$repo" "$worker_scratch" "$slot" > "$scratch/output.log" 2>&1 &
	pids+=("$!")
done

status=0
for index in 0 1 2 3; do
	slot=$((28 + index))
	if ! wait "${pids[$index]}"; then status=1; fi
	cat "$run_root/$slot/output.log"
done
if (( status != 0 )); then
	echo "WP40 T2 C2 selected diagnostics failed" >&2
	exit 1
fi
echo "WP40 T2 C2 historical pre-R18 provisional-winner diagnostics passed 4/4 no_fallback=true promotion=false"
