#!/usr/bin/env bash
# Round 31 Lane M engine probe: one PvP fortress and two camps of one
# Battlegrounds zone on a real world (grug_probe_r31_m, staged into a
# throwaway game copy, never shipped). Boots one isolated headless server
# through tools/luanti_headless.sh, copies the server log and the probe's
# r31m_* dumps to OUT_DIR, removes the run directory and exits 0 only on a
# clean boot plus "RESULT PASS".
#
# Usage: tools/r31_m/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded to the launcher (default 42; seed 42
#   probes the Accord set, any other seed the Throng set).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r31-m-XXXXXX)"
set +e
SEED="${SEED:-42}" PROBE="$here/grug_probe_r31_m" ROOT="$root" \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	cp "$root"/world/r31m_* "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h 'r31_m_probe' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r31 m probe: PASS"
	exit 0
fi
echo "r31 m probe: FAIL (boot status $boot)"
exit 1
