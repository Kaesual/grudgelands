#!/usr/bin/env bash
# Round 89 lane BUBBLE: engine screenshots of the shield bubble (capture.py;
# the probe tools/r89_bubble/grug_probe_r89_bubble, staged into a temp copy
# with every look's textures written by gen_bubble.py --look --out-textures).
# SET=round2 / SET=round3 shoot the look rounds' comparisons instead of the
# first set. One
# boot, which is also the smoke boot; two real Flatpak clients at once, each
# on its own private Xvfb display. The isolation of tools/r80_emote/capture.sh:
# temp dirs as user path and XDG dirs (one set per client), timeouts, nothing
# under the user's Luanti folder, nothing drawn on the desktop. Three queue
# slots (the server and two clients):
#   ~/projects/grudgelands-orchestration/r45/lua_run.sh r89-bubble 3 \
#     env XVFB=/path/to/Xvfb tools/r89_bubble/capture.sh OUT_DIR
#   SETTLE=<seconds> before each shot (default 3), XVFB_DRIVERS=<Mesa DRI dir
#   for Xvfb's GLX> (default /usr/lib64/dri).
# Writes OUT_DIR/<shot>.png, capture.json, the logs.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
out="${1:?usage: capture.sh OUT_DIR}"
: "${XVFB:?set XVFB to an Xvfb binary}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r89bubble-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r89bubble-XXXXXX)"
free_display() {
	local n=$((90 + RANDOM % 900))
	while [[ -e "/tmp/.X11-unix/X$n" || -e "/tmp/.X$n-lock" ]]; do n=$((n + 1)); done
	echo "$n"
}
xvfb_pids=()
cleanup() {
	pkill -TERM -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	pkill -TERM -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	pkill -KILL -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	for pid in "${xvfb_pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done
	rm -rf "$root" "$cap"
}
trap cleanup EXIT
probe="$cap/grug_probe_r89_bubble"
cp -r "$here/grug_probe_r89_bubble" "$probe"
mkdir -p "$probe/textures"
for look in classic hex panels lattice lightning marble web; do
	python3 "$here/gen_bubble.py" --look "$look" --out-textures "$probe/textures/grug_probe_r89_bubble_$look"
done
displays=()
for _ in 1 2; do
	n="$(free_display)"
	LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
		"$XVFB" ":$n" -screen 0 1920x1080x24 -nolisten tcp >"$cap/xvfb-$n.log" 2>&1 &
	xvfb_pids+=($!)
	displays+=(":$n")
	sleep 1
done
python3 "$here/capture.py" "$out" "$root" "$cap" "$probe" "${displays[0]}" "${displays[1]}"
