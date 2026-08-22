#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 collected-correction synthetic KAT runner (contracts 8.3, 8.6.2):
# runs t2_correction_kat_test.lua under LuaJIT and vendored PUC 5.1 and
# byte-compares the two outputs -- the interpreter-split digest gate for the
# D1 order keys no measured seed reaches.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"

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

"$luajit_bin" "$repo/tools/wp40/t2_correction_kat_test.lua" "$repo" \
	"$scratch" > "$luajit_out"
"$puc_bin" "$repo/tools/wp40/t2_correction_kat_test.lua" "$repo" \
	"$scratch" > "$puc_out"

if ! cmp -s "$luajit_out" "$puc_out"; then
	echo "WP40 T2 correction KAT: LuaJIT and PUC outputs differ" >&2
	diff "$luajit_out" "$puc_out" >&2 || true
	exit 1
fi

cat "$luajit_out"
echo "WP40 T2 correction KAT: LuaJIT/PUC byte-identical"
