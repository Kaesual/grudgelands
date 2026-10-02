#!/usr/bin/env bash
# Round 29 Lane W engine probe: boots the game headless with the disposable
# probe mod (tools/r29_w/grug_probe_r29_w), which reads the waystone and
# shipwright sockets and emerges small boxes round the Dawnmere and Highcourt
# waystones (pad, node, arrival) and the Highcourt shipwright spot.
#
# Usage: tools/r29_w/probe.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED (default 42) pins the world seed. Writes the server log and the
#   probe's lines (OUT_DIR/probe.txt).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: probe.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
set +e
SEED="${SEED:-42}" PROBE="$here/grug_probe_r29_w" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r29w_probe\]' "$out"/server*.log 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r29 w probe: PASS (boot status $boot)"
	exit 0
fi
echo "r29 w probe: FAIL (boot status $boot)"
exit 1
