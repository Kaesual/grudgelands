#!/usr/bin/env bash
# 0.53.1 SKILLS engine probe (grug_probe_r531_skills, staged into a throwaway
# game copy, never shipped): who area.query, area.cone and area.group reach on
# a built scene (walls, a ledge, a pillar) and their cost per call. One
# measuring run through the shared queue (engine_run.sh); copies the probe
# lines to OUT_DIR and exits 0 only on "RESULT PASS".
#
# Usage (worktree root): tools/r531_skills/probe.sh OUT_DIR [LABEL]
#   SEED defaults to 12345; QUEUE=0 boots directly through luanti_headless.sh.
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: probe.sh OUT_DIR [LABEL]}"; label="${2:-r531skills}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r531_skills" "$probe/"
cd "$repo"
if [[ "${QUEUE:-1}" == "1" ]]; then
	KEEP=1 SEED="${SEED:-12345}" PROBE="$probe/grug_probe_r531_skills" \
		~/projects/grudgelands-orchestration/r45/engine_run.sh "$label" 300 \
		>"$out/launcher.txt" 2>&1
else
	KEEP=1 SEED="${SEED:-12345}" PROBE="$probe/grug_probe_r531_skills" \
		"$repo/tools/luanti_headless.sh" 300 >"$out/launcher.txt" 2>&1
fi
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r531skills\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/probe.txt"
grep -q 'RESULT PASS' "$out/probe.txt" && exit 0
exit 1
