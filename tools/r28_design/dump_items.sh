#!/usr/bin/env bash
# Round 28 design tools: dump the REAL item registry through a disposable
# headless engine probe and rebuild the designers' catalogue of existing items
# (docs/planning/round28/items/existing.{json,md}).
#
# Usage: tools/r28_design/dump_items.sh [OUT_DIR] [TIMEOUT_SECONDS]
#   OUT_DIR keeps the raw dump and the server log (default: a temp dir that is
#   removed afterwards). Runs one short boot (no map generation needed).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:-}"
timeout_s="${2:-180}"
cleanup_out=0
if [[ -z "$out" ]]; then out="$(mktemp -d)"; cleanup_out=1; fi
mkdir -p "$out"
set +e
PROBE="$here/items_probe/grug_probe_r28_items" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	cp "$root/world/r28_items_probe.json" "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r28_items_probe\]' "$out/server.log" 2>/dev/null || true
status=1
if [[ $boot -eq 0 && -s "$out/r28_items_probe.json" ]]; then
	python3 "$here/items_catalog.py" "$out/r28_items_probe.json" \
		"$repo/docs/planning/round28/items" && status=0
fi
[[ $cleanup_out -eq 1 ]] && rm -rf "$out"
if [[ $status -eq 0 ]]; then echo "r28 items dump: PASS"; else echo "r28 items dump: FAIL (boot status $boot)"; fi
exit $status
