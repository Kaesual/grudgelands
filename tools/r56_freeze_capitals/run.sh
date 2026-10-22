#!/usr/bin/env bash
# Round 56 FREEZE-CAPITALS: the engine proof. One boot of a fresh world (seed
# 42) through tools/luanti_headless.sh with the disposable probe
# grug_probe_r56_freeze_capitals staged: the server builds every start town and
# capital from the templates at load, the probe emerges Highcourt's civic core
# and Dawnmere's pad (a region, never the world) and logs the node counts
# inside them, then shuts the server down. compare.lua then checks every
# building node of the two blueprints against the world's counts.
#
# Usage: tools/r56_freeze_capitals/run.sh OUT_DIR   (through the shared Lua queue,
# one boot). Writes OUT_DIR/probe.txt, server.log, headless.txt, compare.txt.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r56capitals-XXXXXX)"
cleanup() {
	cp "$root/server.log" "$out/server.log" 2>/dev/null || true
	grep -a '\[r56capitals\]' "$root/server.log" >"$out/probe.txt" 2>/dev/null || true
	rm -rf "$root"
}
trap cleanup EXIT
status=0
ROOT="$root" SEED=42 PROBE="$here/grug_probe_r56_freeze_capitals" \
	bash "$repo/tools/luanti_headless.sh" 290 >"$out/headless.txt" 2>&1 || status=$?
cat "$out/headless.txt"
cleanup
trap - EXIT
luajit "$here/compare.lua" "$repo" "$out/probe.txt" | tee "$out/compare.txt"
exit $status
