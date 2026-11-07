#!/usr/bin/env bash
# The 0.69.1 engine scenario of grug_bridge (scenario.py): three boots of one
# world, one real client on a private Xvfb display, the fake bridge on
# localhost. Same isolation as tools/r62_bags/capture.sh: temp dirs as user
# path and XDG dirs, timeouts, nothing under the user's Luanti folder, nothing
# drawn on the desktop. One queue slot:
#   ~/projects/grudgelands-orchestration/r45/lua_run.sh r691-bridge 1 \
#     env XVFB=/path/to/Xvfb tools/r691_bridge/run.sh OUT_DIR
# Writes OUT_DIR/results.json (one row per check), requests.json, the server
# and client logs. Exits 0 only when every check passed.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
out="${1:?usage: run.sh OUT_DIR}"
: "${XVFB:?set XVFB to an Xvfb binary}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r691-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r691-XXXXXX)"
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
	cp "$cap"/client*.log "$out/" 2>/dev/null || true
	rm -rf "$root" "$cap"
}
trap cleanup EXIT
mkdir -p "$cap/user" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config"
cat >"$cap/client.conf" <<CONF
screen_w = 640
screen_h = 480
fullscreen = false
enable_sound = false
viewing_range = 40
fps_max = 10
enable_dynamic_shadows = false
enable_bloom = false
CONF
LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
	"$XVFB" ":$display_no" -screen 0 640x480x24 -nolisten tcp >"$cap/xvfb.log" 2>&1 &
xvfb_pid=$!
sleep 1
export XVFB
python3 "$here/scenario.py" "$out" "$root" "$cap" ":$display_no"
