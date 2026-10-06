#!/usr/bin/env bash
# Round 40 AN2 engine probe (grug_probe_r40_an2, staged into a throwaway game
# copy, never shipped): the engine cost of the head look's look read and
# bone-override write on 100 player models. One measuring run through the
# Round 40 queue; copies the probe lines to OUT_DIR.
#
# Usage (worktree root): tools/r40_an2/engine.sh OUT_DIR LABEL
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR LABEL}"; label="${2:?label}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r40_an2" "$probe/"
KEEP=1 SEED="${SEED:-12345}" PROBE="$probe/grug_probe_r40_an2" \
	~/projects/grudgelands-orchestration/r40/engine_run.sh "an2_$label" 240 \
	>"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r40an2\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
cat "$out/probe.txt"
grep -q 'RESULT DONE' "$out/probe.txt" && exit "$rc"
exit 1
