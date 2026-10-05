#!/usr/bin/env bash
# Round 36 lane F2 engine probe (grug_probe_r36_f2, staged into a throwaway
# game copy, never shipped): a stand-in player holds the dig on a dirt node,
# switches its wield index (empty hand -> Strike, Strike -> empty hand, empty
# hand -> Blink, Strike -> Fireball, and two cases without a switch) and keeps
# holding; then the node's on_dig runs as DIGGING_COMPLETED runs it, and the
# node is logged. A behaviour run, not a timing run, so it boots directly
# (idle priority). Copies the probe lines to OUT_DIR.
#
# Usage (worktree root): tools/r36_f2/engine.sh OUT_DIR
#   SEED defaults to 12345 (the Round 30 probe seed).
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r36_f2" "$probe/"
KEEP=1 SEED="${SEED:-12345}" PROBE="$probe/grug_probe_r36_f2" \
	chrt --idle 0 ionice -c3 "$repo/tools/luanti_headless.sh" 240 \
	>"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r36f2\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
cat "$out/probe.txt"
grep -q 'RESULT PASS' "$out/probe.txt" && exit "$rc"
exit 1
