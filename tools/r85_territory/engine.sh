#!/usr/bin/env bash
# Round 85 lane TERRITORY engine probe: the arena as a place of the game on a real
# world (grug_probe_r85_territory, staged into a throwaway game copy, never
# shipped). Boots one isolated headless server through tools/luanti_headless.sh,
# copies the server log to OUT_DIR, removes the run directory and exits 0
# only on a clean boot plus "RESULT PASS".
#
# Usage: tools/r85_territory/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded to the launcher (default the
#   production seed 3684797457838814663).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r85-territory-XXXXXX)"
set +e
SEED="${SEED:-3684797457838814663}" PROBE="$here/grug_probe_r85_territory" ROOT="$root" \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h 'r85_territory_probe\|arena Breach Road\|world protection:' "$out/server.log" 2>/dev/null | head -n 40 |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r85 territory probe: PASS"
	exit 0
fi
echo "r85 territory probe: FAIL (boot status $boot)"
exit 1
