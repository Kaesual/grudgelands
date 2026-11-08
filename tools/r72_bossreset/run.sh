#!/usr/bin/env bash
# Round 72 BOSSRESET engine probe (grug_probe_r72_bossreset, staged into a
# throwaway game copy, never shipped): the boss floor of every King's and
# General's seat on real ground (cells, steps, fill time, the floor test's
# cost). One engine boot through the shared Lua-process queue
# (one slot) when it exists, else tools/luanti_headless.sh directly; copies
# the probe's log lines to OUT_DIR/probe.txt and exits 0 only when the boot
# passed and the probe finished ("RESULT DONE").
#
# Usage (any directory): tools/r72_bossreset/run.sh OUT_DIR [TIMEOUT]
#   TIMEOUT seconds for the boot (default 300). SEED as luanti_headless.sh.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT]}"
timeout_s="${2:-300}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
queue="$HOME/projects/grudgelands-orchestration/r45/lua_run.sh"
if [[ -x "$queue" ]]; then
	launcher=("$queue" "r72bossreset" 1 env LC_ALL=C "$repo/tools/luanti_headless.sh")
else
	launcher=("$repo/tools/luanti_headless.sh")
fi
root="$(mktemp -d /tmp/grudgelands-headless.r72bossreset-XXXXXX)"
set +e
(cd "$repo" && PROBE="$here/grug_probe_r72_bossreset" ROOT="$root" "${launcher[@]}" "$timeout_s") \
	>"$out/headless.txt" 2>&1
code=$?
set -e
cat "$out/headless.txt"
if [[ "$root" == /tmp/grudgelands-headless.r72bossreset-* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
grep -ah '\[r72bossreset\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
cat "$out/probe.txt"
if [[ $code -eq 0 ]] && grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "r72bossreset probe: DONE ($out)"
	exit 0
fi
echo "r72bossreset probe: FAIL (boot status $code)"
exit 1
