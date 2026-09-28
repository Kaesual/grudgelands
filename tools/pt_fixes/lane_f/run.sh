#!/usr/bin/env bash
# Node-formspec probe (playtest fixes, Lane F): no node keeps its UI in node
# metadata; converted nodes open it from on_rightclick via core.show_formspec,
# submissions are validated and routed, open forms refresh, furnaces smelt.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
#
# Usage: tools/pt_fixes/lane_f/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   GAME_PATCH=<file> is forwarded (e.g. a reverse patch to show the failure
#   on an unfixed build).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-180}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_node_formspec" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[node_formspec_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "node formspec probe: PASS"
	exit 0
fi
echo "node formspec probe: FAIL (boot status $boot)"
exit 1
