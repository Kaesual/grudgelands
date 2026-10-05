#!/usr/bin/env bash
# Round 35 Lane C engine probe: character creation in one window. Probe
# players drive the window with the fields a client sends (dialog and
# inventory "" submissions through the real receive-fields chain): Esc and
# I, the draft rules on the real look panel, nothing stored before Create,
# Create stores everything, a second Create does nothing, a disconnect during
# the arrival wait and the reconnect that resumes it, the arrival teleport,
# the sfinv hand-back, and a draft that a disconnect starts over.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
# The probe shuts the server down itself when it is done.
#
# Usage: tools/r35_c/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded to the launcher (default 42).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-290}"
mkdir -p "$out"
set +e
SEED="${SEED:-42}" PROBE="$here/grug_probe_r35_c" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r35_c_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r35 c probe: PASS"
	exit 0
fi
echo "r35 c probe: FAIL (boot status $boot)"
exit 1
