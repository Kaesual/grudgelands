#!/usr/bin/env bash
# Round 80 lane FIXES: the water-brake measurement (round80-plan.md §4 FIXES 1).
# One boot of a headless server with the probe tools/r80_fixes/grug_probe_r80_water,
# one real client on a private Xvfb display (the client runs the liquid physics),
# drops of 30 and 60 nodes into deep water (water_drop.py). The isolation of
# tools/r79_page/capture.sh: temp dirs as user path and XDG dirs, timeouts,
# nothing under the user's Luanti folder, nothing drawn on the desktop. The
# server gets NO copy of minetest.conf in its own config: the game's file
# reaches it only as the game layer, as on a hosted server. One queue slot:
#   ~/projects/grudgelands-orchestration/r45/lua_run.sh r80-water 1 \
#     env XVFB=/path/to/Xvfb tools/r80_fixes/water_drop.sh OUT_DIR
#   XVFB_DRIVERS=<Mesa DRI dir for Xvfb's GLX> (default /usr/lib64/dri).
# Writes OUT_DIR/water_drop.json (every sample), the summary on stdout, the logs.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
out="${1:?usage: water_drop.sh OUT_DIR}"
: "${XVFB:?set XVFB to an Xvfb binary}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r80water-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r80water-XXXXXX)"
display_no=$((90 + RANDOM % 900))
while [[ -e "/tmp/.X11-unix/X$display_no" || -e "/tmp/.X$display_no-lock" ]]; do
	display_no=$((display_no + 1))
done
xvfb_pid=""
cleanup() {
	pkill -TERM -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	pkill -TERM -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	pkill -KILL -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	[[ -n "$xvfb_pid" ]] && kill "$xvfb_pid" 2>/dev/null || true
	[[ -n "$xvfb_pid" ]] && wait "$xvfb_pid" 2>/dev/null || true
	rm -rf "$root" "$cap"
}
trap cleanup EXIT
mkdir -p "$cap/user" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config"
LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
	"$XVFB" ":$display_no" -screen 0 1280x720x24 -nolisten tcp >"$cap/xvfb.log" 2>&1 &
xvfb_pid=$!
sleep 1
python3 "$here/water_drop.py" "$out" "$root" "$cap" ":$display_no"
