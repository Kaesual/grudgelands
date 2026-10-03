#!/usr/bin/env bash
# Round 31 lane Q engine probe: the PvP fortress quests on a real boot (the
# boot is the load-time check of the shipped quest files; the probe checks
# givers, garrison areas and the filled directions). The portable proof is
# portable_test.lua next to this file (LuaJIT).
#
# Usage: tools/r31_q/run.sh OUT_DIR [TIMEOUT_SECONDS]   (SEED= pins the seed)
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_r31_q" KEEP=1 "$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r31_q_probe\]' "$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r31 q probe: PASS"
	exit 0
fi
echo "r31 q probe: FAIL (boot status $boot)"
exit 1
