#!/usr/bin/env bash
# Release 0.45.1 lane NQ engine probe: the capital NPC socket audit
# (grug_probe_r451_nq/init.lua says what it reads). Boots one isolated
# headless server through tools/luanti_headless.sh with the disposable probe
# mod staged (never shipped), copies the server log and the probe lines to
# OUT_DIR and removes the run directory.
#
# Usage: SEED=<seed> tools/r451_nq/engine.sh OUT_DIR "capital ..." [TIMEOUT_SECONDS]
#   capitals: settlement keys (nhal_veyr, highcourt, dur_brannoc, lethariel,
#   gor_drazhak, kezamba). Run it through the round's queue (one slot).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR \"capital ...\" [TIMEOUT_SECONDS]}"
capitals="${2:?capitals}"
timeout_s="${3:-420}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r451nq-XXXXXX)"
# The staged probe carries this run's targets.
probe="$root/probe/grug_probe_r451_nq"
mkdir -p "$probe"
cp -a "$here/grug_probe_r451_nq/." "$probe/"
{
	printf 'return {capitals = {'
	for c in $capitals; do printf '"%s", ' "$c"; done
	printf '}, settle = %s}\n' "${SETTLE:-45}"
} >"$probe/targets.lua"
set +e
PROBE="$probe" ROOT="$root" "$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.r451nq-?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	cp "$root/world/map_meta.txt" "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r451nq\]\|ERROR' "$out"/server*.log 2>/dev/null >"$out/probe.txt" || true
grep -h 'SUMMARY\|RESULT\|SUNK\|FINAL-' "$out/probe.txt" || true
grep -q 'RESULT done' "$out/probe.txt" && exit 0
echo "r451 nq probe: no RESULT line (boot status $boot)"
exit 1
