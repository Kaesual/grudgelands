#!/usr/bin/env bash
# Round 37 lane DC engine probe (grug_probe_r37_dc, staged into a throwaway
# game copy, never shipped) and the lane's smoke boot: a fresh world boots
# with the new game.conf, the probe logs the version Help -> About shows and
# the disallowed_mapgen_settings line, waits until the six start areas are
# prepared and ends the server. Prints the wait from the server's launch to
# "starts ready" in whole seconds (the README's first-start wait).
#
# Usage (worktree root): tools/r37_dc/engine.sh OUT_DIR
#   SEED defaults to 12345 (the Round 30 probe seed).
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r37_dc" "$probe/"
launched=$(date +%s)
KEEP=1 SEED="${SEED:-12345}" PROBE="$probe/grug_probe_r37_dc" \
	"$repo/tools/luanti_headless.sh" 400 >"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r37dc\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
ready=$(grep -o 'starts_ready_at=[0-9]*' "$out/probe.txt" | cut -d= -f2)
[[ -n "$ready" ]] && echo "first-start wait: $((ready - launched)) s from launch" >>"$out/probe.txt"
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
cat "$out/probe.txt"
grep -q 'RESULT PASS' "$out/probe.txt" && exit "$rc"
exit 1
