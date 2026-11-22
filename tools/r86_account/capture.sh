#!/usr/bin/env bash
# Round 86 lane ACCOUNT: engine screenshots of the Account page "The Charter"
# (capture.py; the probe of tools/r79_page) at 1366 x 768 and 1920 x 1080,
# one private Xvfb display per size. One boot, which is also the smoke boot.
# The isolation of tools/r79_page/capture.sh: temp dirs as user path and XDG
# dirs, timeouts, nothing under the user's Luanti folder, nothing drawn on
# the desktop. One queue slot:
#   ~/projects/grudgelands-orchestration/r45/lua_run.sh r86-account 1 \
#     env XVFB=/path/to/Xvfb tools/r86_account/capture.sh OUT_DIR
#   SETTLE=<seconds> before each shot (default 2.5), XVFB_DRIVERS=<Mesa DRI
#   dir for Xvfb's GLX> (default /usr/lib64/dri).
# Writes OUT_DIR/A<n>_<state>_<w>x<h>.png, capture.json, the logs.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
out="${1:?usage: capture.sh OUT_DIR}"
: "${XVFB:?set XVFB to an Xvfb binary}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r86account-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r86account-XXXXXX)"
pids=()
displays=()
cleanup() {
	pkill -TERM -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	pkill -TERM -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	pkill -KILL -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done
	rm -rf "$root" "$cap"
}
trap cleanup EXIT
mkdir -p "$cap/user" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config"
display_no=$((90 + RANDOM % 900))
for size in 1366x768 1920x1080; do
	while [[ -e "/tmp/.X11-unix/X$display_no" || -e "/tmp/.X$display_no-lock" ]]; do
		display_no=$((display_no + 1))
	done
	LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
		"$XVFB" ":$display_no" -screen 0 "${size}x24" -nolisten tcp >"$cap/xvfb-$size.log" 2>&1 &
	pids+=($!)
	displays+=(":$display_no=$size")
	display_no=$((display_no + 1))
done
sleep 1
python3 "$here/capture.py" "$out" "$root" "$cap" "${displays[@]}"
