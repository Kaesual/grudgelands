#!/usr/bin/env bash
# Recipe-book ingredient navigation probe (playtest fix lane D).
#
# Boots two isolated headless servers, one after the other, through
# tools/luanti_headless.sh with the disposable probe mod staged (never shipped):
#   1. baseline: this checkout with mods/PLAYER/grug_jobs/ui.lua reverted to
#      BASE_REV via GAME_PATCH (default 0172a15b, the Round 41 base; the
#      navigation lane compared against 752cca97, before its own change);
#   2. current: this checkout as is.
# Both emit a digest per rendered recipe route of the book formspec with the
# navigation lane's elements and every multi-item slot (Round 41) removed;
# the DUMP lines must be identical (grid, boxes, single-item cells, tooltips
# and every other element unchanged). The current run also has to print
# "RESULT PASS" for the behaviour checks.
#
# Usage: tools/pt_fixes/lane_d/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
base_rev="${BASE_REV:-0172a15b}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"

git -C "$repo" diff -R "$base_rev" -- mods/PLAYER/grug_jobs/ui.lua >"$out/baseline.patch"

boot() { # label [GAME_PATCH]
	local label="$1" patch="${2:-}" status root
	set +e
	GAME_PATCH="$patch" PROBE="$here/grug_probe_recipe_book" KEEP=1 \
		"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/$label.headless.txt" 2>&1
	status=$?
	set -e
	root="$(sed -n 's/^kept: //p' "$out/$label.headless.txt" | tail -n 1)"
	if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
		cp "$root/server.log" "$out/$label.server.log" 2>/dev/null || true
		rm -rf "$root"
	fi
	grep -h '\[recipe_book_probe\]' "$out/$label.server.log" 2>/dev/null \
		>"$out/$label.probe.txt" || true
	grep -h ' DUMP ' "$out/$label.probe.txt" | sed 's/^.*\] DUMP /DUMP /' \
		>"$out/$label.dump.txt" || true
	echo "$label boot status $status"
	return 0
}

if [[ -s "$out/baseline.patch" ]]; then
	boot baseline "$out/baseline.patch"
else
	echo "baseline patch is empty (BASE_REV=$base_rev equals the checkout)"
	: >"$out/baseline.dump.txt"
fi
boot current

fail=0
grep -v ' DUMP ' "$out/current.probe.txt" || true
if [[ ! -s "$out/baseline.dump.txt" ]] || ! grep -q 'RESULT BASELINE' "$out/baseline.probe.txt" 2>/dev/null; then
	echo "baseline run missing or not a baseline build"; fail=1
elif diff -u "$out/baseline.dump.txt" "$out/current.dump.txt" >"$out/dump.diff"; then
	echo "formspec digests identical: $(grep -c '^DUMP' "$out/current.dump.txt") lines ($(tail -n 1 "$out/current.dump.txt"))"
else
	echo "formspec digests DIFFER: see $out/dump.diff"; fail=1
fi
grep -q 'RESULT PASS' "$out/current.probe.txt" || fail=1
if [[ $fail -eq 0 ]]; then echo "recipe book probe: PASS"; exit 0; fi
echo "recipe book probe: FAIL"
exit 1
