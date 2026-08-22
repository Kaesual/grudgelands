#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 D1 keys-4/5 firing-set projection runner (plan 7.1, contracts 11.6,
# 12.5).  Static-gates t2_r19_order_projection.lua, globs the committed census
# shards, runs the projection under LuaJIT and the vendored PUC 5.1 and
# byte-compares the two outputs -- the projection's output is the evidence, so
# an interpreter split is itself a failure.
#
#   run_t2_r19_order_projection.sh [ARTIFACTS_DIR] [VERSION...]
#
# ARTIFACTS_DIR defaults to the census shard directory of this checkout.
# VERSION defaults to "4 5 6": v5 and v6 carry the D1 selection and get the
# deep analysis, v4 predates the amendment and is consumed for the plan-7.1
# reconciliation head count only.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"

artifacts_dir="${1:-$repo/tools/wp40/results/t2_census}"
shift || true
versions=("$@")
if (( ${#versions[@]} == 0 )); then versions=(4 5 6); fi

projection="$script_dir/t2_r19_order_projection.lua"
"$repo/tools/bin/luac51" -p "$projection"
if "$repo/tools/bin/luac51" -l -p "$projection" | grep -q 'SETGLOBAL'; then
	echo "WP40 T2 R19 order projection: global write in $projection" >&2
	exit 1
fi

# The five plain-5.1 conformance sweeps of docs/research/luanti-lua.md.
patterns=(
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
	'\\u\{|\\x[0-9A-Fa-f]|\\z'
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for pattern in "${patterns[@]}"; do
	if grep -nE "$pattern" "$projection"; then
		echo "WP40 T2 R19 order projection uses a forbidden Lua construct" >&2
		exit 1
	fi
done
bash -n "$script_dir/run_t2_r19_order_projection.sh"

if [[ ! -d "$artifacts_dir" ]]; then
	echo "WP40 T2 R19 order projection: no such artifacts directory:" \
		"$artifacts_dir" >&2
	exit 2
fi

shards=()
for version in "${versions[@]}"; do
	if [[ ! "$version" =~ ^[0-9]+$ ]]; then
		echo "WP40 T2 R19 order projection: version must be a number:" \
			"$version" >&2
		exit 2
	fi
	found=0
	for path in "$artifacts_dir"/census-scan-v"$version"-*.tsv; do
		[[ -f "$path" ]] || continue
		shards+=("$(basename "$path")")
		found=$((found + 1))
	done
	if (( found == 0 )); then
		echo "WP40 T2 R19 order projection: no v$version census shards in" \
			"$artifacts_dir" >&2
		exit 2
	fi
done

luajit_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
puc_bin="$repo/tools/bin/lua51"

scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-r19-order.XXXXXXXX)"
trap 'rm -rf "$scratch"' EXIT

luajit_status=0
puc_status=0
"$luajit_bin" "$projection" "$artifacts_dir" "${shards[@]}" \
	>"$scratch/luajit.txt" 2>&1 || luajit_status=$?
"$puc_bin" "$projection" "$artifacts_dir" "${shards[@]}" \
	>"$scratch/puc.txt" 2>&1 || puc_status=$?

if ! cmp -s "$scratch/luajit.txt" "$scratch/puc.txt"; then
	echo "WP40 T2 R19 order projection: LuaJIT and PUC outputs differ" >&2
	diff "$scratch/luajit.txt" "$scratch/puc.txt" >&2 || true
	exit 1
fi
if (( luajit_status != puc_status )); then
	echo "WP40 T2 R19 order projection: exit codes differ" \
		"(luajit $luajit_status, puc $puc_status)" >&2
	exit 1
fi

cat "$scratch/luajit.txt"
if (( luajit_status == 0 )); then
	echo "WP40 T2 R19 order projection: LuaJIT/PUC byte-identical"
fi
exit "$luajit_status"
