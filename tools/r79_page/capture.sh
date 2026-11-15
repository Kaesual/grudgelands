#!/usr/bin/env bash
# Round 79 lane PAGE: engine screenshots of the Account page in every state
# and the Character page's cloak picker with the account cloak, at GUI scale 1
# and 2 (capture.py; the probe tools/r79_page/grug_probe_r79_page). One boot,
# which is also the smoke boot. The isolation of tools/r691_bridge/run.sh:
# temp dirs as user path and XDG dirs, timeouts, nothing under the user's
# Luanti folder, nothing drawn on the desktop. One queue slot:
#   ~/projects/grudgelands-orchestration/r45/lua_run.sh r79-page 1 \
#     env XVFB=/path/to/Xvfb tools/r79_page/capture.sh OUT_DIR
#   GUI_SCALES (default "1 2"), SETTLE=<seconds> before each shot (default
#   2.5), XVFB_DRIVERS=<Mesa DRI dir for Xvfb's GLX> (default /usr/lib64/dri).
# Writes OUT_DIR/P0n_<state>_s<scale>.png, capture.json, the logs.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
out="${1:?usage: capture.sh OUT_DIR}"
: "${XVFB:?set XVFB to an Xvfb binary}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r79page-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r79page-XXXXXX)"
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
	"$XVFB" ":$display_no" -screen 0 1920x1080x24 -nolisten tcp >"$cap/xvfb.log" 2>&1 &
xvfb_pid=$!
sleep 1
python3 "$here/capture.py" "$out" "$root" "$cap" ":$display_no"
