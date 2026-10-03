#!/usr/bin/env bash
# Round 31 Lane B engine probe: enchant colours on a dropped item, a wielded
# weapon (a king's and an NPC's) and a body (grug_probe_r31_b, staged into a
# throwaway game copy, never shipped). One boot; copies the log to OUT_DIR and
# exits 0 only on a clean boot with "RESULT PASS".
#
# Usage: tools/r31_b/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded to the launcher (default 42).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r31-b-XXXXXX)"
set +e
SEED="${SEED:-42}" PROBE="$here/grug_probe_r31_b" ROOT="$root" \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
status=$?
set -e
cat "$out/headless.txt"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
grep -h 'r31_b_probe' "$out"/server*.log 2>/dev/null | tee "$out/probe.txt" || true
if [[ $status -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r31 b probe: PASS"
	exit 0
fi
echo "r31 b probe: FAIL (boot status $status)"
exit 1
