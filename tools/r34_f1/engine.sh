#!/usr/bin/env bash
# Round 34 F1 engine probe (grug_probe_r34_f1, staged into a throwaway game
# copy, never shipped): a Wolf at a real water crossing of the generated
# world (ambient roam, chase across, return home, stranded in water) and the
# per-call cost of the cliff probe and the leash tick. One measuring run
# through the Round 34 semaphore; copies the probe lines to OUT_DIR.
#
# Usage (worktree root): tools/r34_f1/engine.sh OUT_DIR LABEL
#   SEED defaults to 12345 (the Round 30 probe seed).
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR LABEL}"; label="${2:?label}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r34_f1" "$probe/"
KEEP=1 SEED="${SEED:-12345}" PROBE="$probe/grug_probe_r34_f1" \
	~/projects/grudgelands-orchestration/r34/engine_run.sh "f1_$label" 300 \
	>"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r34f1\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
grep -q 'RESULT DONE' "$out/probe.txt" && exit "$rc"
exit 1
