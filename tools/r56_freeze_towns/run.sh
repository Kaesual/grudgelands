#!/usr/bin/env bash
# Round 56 FREEZE-TOWNS: the engine proof. One boot of a fresh world (seed 42)
# through tools/luanti_headless.sh with the disposable probe
# grug_probe_r56_freeze staged: the server builds every start town from its
# templates at load (main and the mapgen environment), the probe emerges the
# Dawnmere and Sunscar pads (a region, never the world) and logs the node
# counts inside them, then shuts the server down. compare.lua then checks every
# building node of the two blueprints (doors, beds, the moved props, decor)
# against the world's counts.
#
# Usage: tools/r56_freeze_towns/run.sh OUT_DIR   (through the shared Lua queue,
# one boot). Writes OUT_DIR/probe.txt, server.log, headless.txt, compare.txt.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r56freeze-XXXXXX)"
cleanup() {
	cp "$root/server.log" "$out/server.log" 2>/dev/null || true
	grep -a '\[r56freeze\]' "$root/server.log" >"$out/probe.txt" 2>/dev/null || true
	rm -rf "$root"
}
trap cleanup EXIT
status=0
ROOT="$root" SEED=42 PROBE="$here/grug_probe_r56_freeze" \
	bash "$repo/tools/luanti_headless.sh" 290 >"$out/headless.txt" 2>&1 || status=$?
cat "$out/headless.txt"
cleanup
trap - EXIT
luajit "$here/compare.lua" "$repo" "$out/probe.txt" | tee "$out/compare.txt"
exit $status
