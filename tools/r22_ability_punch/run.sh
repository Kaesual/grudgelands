#!/usr/bin/env bash
# Ability-punch regression probe (Round 22): one LMB press with Smite, Frost
# Nova, Charge, Strike and Fireball at a fresh hostile grug mob must cast (or
# swing) exactly once, pay once, arm the cooldown and land its damage.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
#
# Usage: tools/r22_ability_punch/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   GAME_PATCH=<file> is forwarded (e.g. a reverse patch to show the failure
#   on an unfixed build).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-180}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_ability_punch" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[ability_punch_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "ability punch probe: PASS"
	exit 0
fi
echo "ability punch probe: FAIL (boot status $boot)"
exit 1
