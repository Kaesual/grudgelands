#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 collected-correction synthetic KAT runner (contracts 8.3, 8.6.2):
# runs t2_correction_kat_test.lua under LuaJIT and vendored PUC 5.1 and
# byte-compares the two outputs -- the interpreter-split digest gate for the
# D1 order keys no measured seed reaches.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
mode=kat
if (( $# > 0 )); then
	if [[ $# -eq 1 && "$1" == --pair-self-test ]]; then
		mode=pair-self-test
	else
		echo "usage: tools/wp40/run_t2_correction_kat.sh [--pair-self-test]" >&2
		exit 2
	fi
fi

command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}

# The KAT script and the independent C2 order comparator it drives beside the
# two production comparators (contracts 13.4).
owned_lua=(
	"$repo/tools/wp40/t2_correction_kat_test.lua"
	"$repo/tools/wp40/t2_r19_order_oracle.lua"
)
"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T2 correction KAT global write in $file" >&2
		exit 1
	fi
done

# The five plain-5.1 conformance sweeps of docs/research/luanti-lua.md.
patterns=(
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
	'\\u\{|\\x[0-9A-Fa-f]|\\z'
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for pattern in "${patterns[@]}"; do
	if grep -nE "$pattern" "${owned_lua[@]}"; then
		echo "WP40 T2 correction KAT uses a forbidden Lua construct" >&2
		exit 1
	fi
done
bash -n "$script_dir/run_t2_correction_kat.sh"

luajit_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
puc_bin="$repo/tools/bin/lua51"

scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-census.XXXXXXXX)"
trap 'rm -rf "$scratch"' EXIT

luajit_out="$scratch/correction-kat-luajit.txt"
puc_out="$scratch/correction-kat-puc.txt"
luajit_status=0
puc_status=0

compare_pair() {
	local left="$1" left_status="$2" right="$3" right_status="$4"
	if ! cmp -s "$left" "$right"; then
		echo "WP40 T2 correction KAT: LuaJIT and PUC outputs differ" >&2
		diff "$left" "$right" >&2 || true
		return 1
	fi
	if (( left_status != right_status )); then
		echo "WP40 T2 correction KAT: LuaJIT and PUC exit codes differ" \
			"(luajit $left_status, puc $right_status)" >&2
		return 1
	fi
	if (( left_status != 0 )); then
		echo "WP40 T2 correction KAT: both interpreters failed" \
			"with status $left_status" >&2
		return 1
	fi
	return 0
}

# Executable negative proof for the PCC's stronger pair discipline. It is a
# named mode rather than an environment-variable bypass, and the PCC runs it
# in its cheap preflight before any expensive leg. Equal nonzero exits and
# unequal exits must both be rejected; a byte difference remains rejected.
if [[ "$mode" == pair-self-test ]]; then
	printf 'same\n' >"$luajit_out"
	printf 'same\n' >"$puc_out"
	if compare_pair "$luajit_out" 7 "$puc_out" 7 2>/dev/null; then
		echo "WP40 correction pair negative: equal nonzero exits passed" >&2
		exit 1
	fi
	if compare_pair "$luajit_out" 0 "$puc_out" 9 2>/dev/null; then
		echo "WP40 correction pair negative: unequal exits passed" >&2
		exit 1
	fi
	printf 'different\n' >"$puc_out"
	if compare_pair "$luajit_out" 0 "$puc_out" 0 2>/dev/null; then
		echo "WP40 correction pair negative: unequal output passed" >&2
		exit 1
	fi
	echo "WP40 T2 correction KAT pair negative passed"
	exit 0
fi

"$luajit_bin" "$repo/tools/wp40/t2_correction_kat_test.lua" "$repo" \
	"$scratch" > "$luajit_out" 2>&1 || luajit_status=$?
"$puc_bin" "$repo/tools/wp40/t2_correction_kat_test.lua" "$repo" \
	"$scratch" > "$puc_out" 2>&1 || puc_status=$?

if ! compare_pair "$luajit_out" "$luajit_status" "$puc_out" "$puc_status"; then
	cat "$luajit_out" >&2
	exit 1
fi

cat "$luajit_out"
echo "WP40 T2 correction KAT: LuaJIT/PUC byte-identical"
