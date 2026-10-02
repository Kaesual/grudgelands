#!/usr/bin/env bash
# Round 28 Lane M1 engine probe: boots the game headless with the disposable
# probe mod (tools/r28_m1/grug_probe_r28_m1), which walks the real location
# lookup across town edges and zone borders, logs the zone marker placement
# and King labels and measures the lookup cost. No world is emerged.
#
# Usage: tools/r28_m1/probe.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED (default 42) pins the world seed. Writes the server log and the
#   probe's lines (OUT_DIR/probe.txt).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: probe.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
set +e
SEED="${SEED:-42}" PROBE="$here/grug_probe_r28_m1" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r28m1_probe\]\|\[grug_map\]' "$out"/server*.log 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r28 m1 probe: PASS (boot status $boot)"
	exit 0
fi
echo "r28 m1 probe: FAIL (boot status $boot)"
exit 1
