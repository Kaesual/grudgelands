#!/usr/bin/env bash
# Round 56 FLOAT: one headless boot with the disposable probe
# grug_probe_r56_float (a pool, a land platform and a lava basin high in the
# sky; see its init.lua). Copies the probe's lines to OUT_DIR/probe.log and
# the full server log to OUT_DIR/server.log, then removes the run directory.
#   tools/r56_float/probe.sh OUT_DIR
#   GAME_PATCH=<file> (passed through to tools/luanti_headless.sh) runs the
#   probe on a patched copy of the game, e.g. the reverse of the FLOAT patch
#   for the "before" numbers.
# Run it through the shared Lua queue with 1 slot.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: probe.sh OUT_DIR}"
mkdir -p "$out"
set +e
KEEP=1 PROBE="$here/grug_probe_r56_float" bash "$repo/tools/luanti_headless.sh" 240 \
	>"$out/boot.txt" 2>&1
status=$?
set -e
cat "$out/boot.txt"
root="$(sed -n 's/^kept: //p' "$out/boot.txt")"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log"
	grep -h '\[r56float\]' "$root/server.log" >"$out/probe.log" || true
	rm -rf -- "$root"
fi
exit $status
