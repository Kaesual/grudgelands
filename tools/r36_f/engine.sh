#!/usr/bin/env bash
# Round 36 lane F engine probe (grug_probe_r36_f, staged into a throwaway game
# copy, never shipped): a Wolf reset inside and outside its wander radius
# (round36-plan.md §2.14.2); logs grug_evading and the distance to home once a
# second. A behaviour run, not a timing run, so it boots directly (idle
# priority) instead of through the measuring semaphore. Copies the probe lines
# to OUT_DIR.
#
# Usage (worktree root): tools/r36_f/engine.sh OUT_DIR
#   SEED defaults to 12345 (the Round 30 probe seed).
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r36_f" "$probe/"
KEEP=1 SEED="${SEED:-12345}" PROBE="$probe/grug_probe_r36_f" \
	chrt --idle 0 ionice -c3 "$repo/tools/luanti_headless.sh" 300 \
	>"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r36f\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
grep -q 'RESULT PASS' "$out/probe.txt" && exit "$rc"
exit 1
