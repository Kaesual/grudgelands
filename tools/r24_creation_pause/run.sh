#!/usr/bin/env bash
# Round 24 Lane H engine probe: pausable character creation (ruling 32).
# Esc on the waiting screen and on every creation dialog re-opens nothing,
# the hint per state, readiness while dismissed vs open, the inventory
# formspec ("" submissions through the real receive-fields chain, sfinv
# suspended), a disconnect with a pending class and the reconnect that applies
# it at the arrival teleport, the sfinv hand-back, and an existing character
# released at readiness.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
# The probe shuts the server down itself when it is done.
#
# Usage: tools/r24_creation_pause/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-290}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_creation_pause" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[creation_pause_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "creation pause probe: PASS"
	exit 0
fi
echo "creation pause probe: FAIL (boot status $boot)"
exit 1
