#!/usr/bin/env bash
# Round 24 Lane D engine probe: start-zone spawn levels on the installed zone
# authority, calm roaming versus 4.0 combat speed of the ranged families, and
# the idle wander leash, on the real mobs_redo AI.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
#
# Usage: tools/r24_mobs/run.sh OUT_DIR [TIMEOUT_SECONDS] [PROBE]
#   PROBE: grug_probe_r24_mobs (default; Lane D levels, speeds, wander leash)
#   or grug_probe_r24_startzone (Lane D2 band x clock species table and the
#   start-zone quest audit).
#   SEED=<unsigned decimal> is forwarded (4242424242 matches the portable
#   levels fixture's first seed).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
probe_name="${3:-grug_probe_r24_mobs}"
case "$probe_name" in
	grug_probe_r24_mobs) tag='\[r24_mobs_probe\]' ;;
	grug_probe_r24_startzone) tag='\[r24_startzone_probe\]' ;;
	*) echo "unknown probe $probe_name" >&2; exit 2 ;;
esac
mkdir -p "$out"
set +e
PROBE="$here/$probe_name" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h "$tag" "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "$probe_name: PASS"
	exit 0
fi
echo "$probe_name: FAIL (boot status $boot)"
exit 1
