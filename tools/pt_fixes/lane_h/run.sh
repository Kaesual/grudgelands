#!/usr/bin/env bash
# Lane H playtest-fix probe: combat state ends with the last engaged mob
# (kill, two mobs, group fight after the tank dies, leash reset, stop_attack,
# lost target, stranded fish, removal, leave, taunt/heal threat, mob-first
# and projectile hits), on death and after respawn, after 5 s for PvP and
# untracked sources, poison ticks; eating right after the last kill. Also
# logs the relative event cost.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
#
# Usage: tools/pt_fixes/lane_h/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   GAME_PATCH=<file> is forwarded (e.g. a reverse patch to show the failure
#   on an unfixed build).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_combat_exit" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[combat_exit_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "combat exit probe: PASS"
	exit 0
fi
echo "combat exit probe: FAIL (boot status $boot)"
exit 1
