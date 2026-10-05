#!/usr/bin/env bash
# Round 36 Lane W3 engine probe: ground cover in the bare band round Dawnmere
# Fields, Sunscar Flats and four diagonal stretches of Highcourt on a fresh
# world (grug_probe_r36_w3, staged into a throwaway game copy, never
# shipped). Boots one isolated headless server through the shared Round 36
# measuring semaphore (engine_run.sh) when it exists, else
# tools/luanti_headless.sh, copies the server log to OUT_DIR, removes the run
# directory and exits 0 only on a clean boot plus "RESULT PASS".
#
# Usage: tools/r36_w3/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded to the launcher (default 42).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r36-w3-XXXXXX)"
semaphore="$HOME/projects/grudgelands-orchestration/r36/engine_run.sh"
set +e
cd "$repo"
if [[ -x "$semaphore" ]]; then
	SEED="${SEED:-42}" PROBE="$here/grug_probe_r36_w3" ROOT="$root" \
		"$semaphore" r36-w3 "$timeout_s" >"$out/headless.txt" 2>&1
else
	SEED="${SEED:-42}" PROBE="$here/grug_probe_r36_w3" ROOT="$root" \
		chrt --idle 0 "$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
fi
boot=$?
set -e
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h 'r36_w3_probe' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r36 w3 probe: PASS"
	exit 0
fi
echo "r36 w3 probe: FAIL (boot status $boot)"
exit 1
