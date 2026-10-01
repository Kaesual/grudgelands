#!/usr/bin/env bash
# Round 28 Lane A2 engine probe: percent environmental damage (lava, sun,
# fall), elite half and king immunity, and engaged-mob separation, on the real
# mobs_redo AI with the vendored GRUG PATCHes.
#
# The portable proof is portable_test.lua next to this file (LuaJIT).
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
#
# Usage: tools/r28_a2_mobphys/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-180}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_r28_mobphys" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r28_mobphys_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r28 mobphys probe: PASS"
	exit 0
fi
echo "r28 mobphys probe: FAIL (boot status $boot)"
exit 1
