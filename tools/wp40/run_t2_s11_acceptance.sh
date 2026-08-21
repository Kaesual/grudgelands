#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 section-11 acceptance ledger runner (contracts 11.11): runs
# t2_s11_acceptance_check.lua under LuaJIT and the vendored PUC 5.1 and
# byte-compares the two outputs -- the checker's own output is the pinned
# artifact, so an interpreter split is itself a failure.
#
#   run_t2_s11_acceptance.sh [ARTIFACTS_DIR]

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
artifacts_dir="${1:-$repo/tools/wp40/results/bay-transition-package-final-artifacts}"

checker="$repo/tools/wp40/t2_s11_acceptance_check.lua"
"$repo/tools/bin/luac51" -p "$checker"
if "$repo/tools/bin/luac51" -l -p "$checker" | grep -q 'SETGLOBAL'; then
	echo "WP40 T2 s11 acceptance: global write in $checker" >&2
	exit 1
fi

luajit_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
puc_bin="$repo/tools/bin/lua51"

scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-s11-acceptance.XXXXXXXX)"
trap 'rm -rf "$scratch"' EXIT

luajit_status=0
puc_status=0
"$luajit_bin" "$checker" "$repo" "$artifacts_dir" \
	>"$scratch/luajit.txt" 2>&1 || luajit_status=$?
"$puc_bin" "$checker" "$repo" "$artifacts_dir" \
	>"$scratch/puc.txt" 2>&1 || puc_status=$?

if ! cmp -s "$scratch/luajit.txt" "$scratch/puc.txt"; then
	echo "WP40 T2 s11 acceptance: LuaJIT and PUC outputs differ" >&2
	diff "$scratch/luajit.txt" "$scratch/puc.txt" >&2 || true
	exit 1
fi
if (( luajit_status != puc_status )); then
	echo "WP40 T2 s11 acceptance: exit codes differ" \
		"(luajit $luajit_status, puc $puc_status)" >&2
	exit 1
fi

cat "$scratch/luajit.txt"
exit "$luajit_status"
