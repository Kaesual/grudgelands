#!/usr/bin/env bash
# Round 35 T engine probe (grug_probe_r35_t, staged into a throwaway game
# copy, never shipped): a held cast on a zombie and a crocodile turning
# through every yaw, and the cost of one aiming ray in a busy fight with fake
# players. One measuring run through the Round 35 semaphore; copies the probe
# lines to OUT_DIR.
#
# Usage (worktree root): tools/r35_t/engine.sh OUT_DIR LABEL
#   SEED defaults to 12345 (the Round 30 probe seed).
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR LABEL}"; label="${2:?label}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r35_t" "$probe/"
KEEP=1 SEED="${SEED:-12345}" PROBE="$probe/grug_probe_r35_t" \
	~/projects/grudgelands-orchestration/r35/engine_run.sh "t_$label" 300 \
	>"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r35t\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
grep -q 'RESULT DONE' "$out/probe.txt" && exit "$rc"
exit 1
