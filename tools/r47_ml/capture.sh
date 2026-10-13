#!/usr/bin/env bash
# Round 47 lane ML: screenshots of the map window's marker layers (the work
# package's §7 proof: the layout with one and two button rows, each layer
# once, the zone layer at 1x and 4x, quest mode).
#
# Same method and isolation as tools/r47_ta/capture.sh: the server boots
# through tools/luanti_headless.sh with the disposable probe
# grug_probe_r47_ml staged, and ONE real Flatpak client connects on a
# private Xvfb display with its own fresh temp dir as LUANTI_USER_PATH and
# every XDG dir, under `timeout --kill-after`. The personal
# ~/.var/app/org.luanti.luanti is never touched and nothing is drawn on the
# user's desktop. The probe shows the map window and logs
# "SHOT <name> <x> <y>" when a view is ready; this script puts the pointer
# at x/y (tools/r47_ml/warp.py, so the shot shows that marker's tooltip),
# takes the screenshot and writes the name into <world>/r47ml_ack, which
# moves the probe on.
#
# Usage: XVFB=/path/to/Xvfb tools/r47_ml/capture.sh OUT_DIR
#   WIDTH/HEIGHT (default 1920 x 1080), SEED (default 42), SUFFIX=<text>
#   appended to every file name, SETTLE=<seconds> before each shot (default
#   4), SHOTS=<prefixes> only the shots whose names start with one of the
#   comma-separated prefixes (e.g. SHOTS=L7), XVFB_DRIVERS=<Mesa DRI dir for Xvfb's GLX> (default /usr/lib64/dri).
#   Run it through the shared Lua queue (one boot).
# Writes OUT_DIR/<shot><suffix>.png, OUT_DIR/probe<suffix>.txt and the logs.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: capture.sh OUT_DIR}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
width="${WIDTH:-1920}"; height="${HEIGHT:-1080}"
settle="${SETTLE:-4}"; suffix="${SUFFIX:-}"; seed="${SEED:-42}"; shots="${SHOTS:-}"
server_timeout=330; client_timeout=320
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"

root="$(mktemp -d /tmp/grudgelands-headless.r47ml-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r47ml-XXXXXX)"
patchdir="$(mktemp -d /tmp/grudgelands-capture.r47ml-patch-XXXXXX)"
display_no=$((90 + RANDOM % 900))
while [[ -e "/tmp/.X11-unix/X$display_no" || -e "/tmp/.X$display_no-lock" ]]; do
	display_no=$((display_no + 1))
done
port=$((30000 + (RANDOM * 32768 + RANDOM) % 10000))
xvfb_pid=""; server_pid=""; client_pid=""

cleanup() {
	pkill -TERM -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	pkill -TERM -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	pkill -KILL -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	[[ -n "$client_pid" ]] && wait "$client_pid" 2>/dev/null || true
	[[ -n "$server_pid" ]] && wait "$server_pid" 2>/dev/null || true
	[[ -n "$xvfb_pid" ]] && kill "$xvfb_pid" 2>/dev/null || true
	[[ -n "$xvfb_pid" ]] && wait "$xvfb_pid" 2>/dev/null || true
	cp "$root/server.log" "$out/server$suffix.log" 2>/dev/null || true
	cp "$cap/client.log" "$out/client$suffix.log" 2>/dev/null || true
	cp "$cap/headless.txt" "$out/headless$suffix.txt" 2>/dev/null || true
	grep -ah '\[r47ml\]' "$root/server.log" >"$out/probe$suffix.txt" 2>/dev/null || true
	rm -rf "$root" "$cap" "$patchdir"
}
trap cleanup EXIT

# The probe's settings, as a patch to the staged game's minetest.conf: no
# mob spawns and the settle time.
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
cat >>"$patchdir/b/minetest.conf" <<CONF

# Round 47 ML capture probe
mobs_spawn = false
r47ml_settle = $settle
r47ml_shots = $shots
CONF
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true

# The Xvfb named in the brief is a Debian build: its GLX looks for the
# software DRI driver on Debian's multiarch path and silently runs without
# GLX on this Fedora host ("GLX is not supported" in the client). Pointing it
# at the host's Mesa drivers turns GLX (llvmpipe) on.
LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
	"$xvfb" ":$display_no" -screen 0 "${width}x${height}x24" -nolisten tcp \
	>"$cap/xvfb.log" 2>&1 &
xvfb_pid=$!
sleep 1

env ROOT="$root" PORT="$port" SEED="$seed" PROBE="$here/grug_probe_r47_ml" \
	GAME_PATCH="$patchdir/probe.patch" \
	"$repo/tools/luanti_headless.sh" "$server_timeout" >"$cap/headless.txt" 2>&1 &
server_pid=$!

for _ in $(seq 1 120); do
	grep -q 'listening on' "$root/server.log" 2>/dev/null && break
	sleep 1
done

mkdir -p "$cap/user" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config"
cat >"$cap/client.conf" <<CONF
screen_w = $width
screen_h = $height
fullscreen = false
enable_sound = false
viewing_range = 60
fps_max = 20
hud_scaling = 1
gui_scaling = 1
enable_dynamic_shadows = false
enable_bloom = false
CONF
timeout --kill-after=5 "$client_timeout" \
	env -u WAYLAND_DISPLAY DISPLAY=":$display_no" \
	flatpak run --command=luanti --socket=x11 --nosocket=wayland \
		--filesystem="$cap" \
		--env=DISPLAY=":$display_no" \
		--env=SDL_VIDEODRIVER=x11 \
		--env=__GLX_VENDOR_LIBRARY_NAME=mesa \
		--env=LIBGL_ALWAYS_SOFTWARE=1 \
		--env=LUANTI_USER_PATH="$cap/user" \
		--env=XDG_CACHE_HOME="$cap/xdg/cache" \
		--env=XDG_DATA_HOME="$cap/xdg/data" \
		--env=XDG_CONFIG_HOME="$cap/xdg/config" \
		--env=LC_ALL=C \
		org.luanti.luanti --go --address 127.0.0.1 --port "$port" \
		--name grugcap --config "$cap/client.conf" \
		--logfile "$cap/client.log" >"$cap/client.console.log" 2>&1 &
client_pid=$!

# Take every shot the probe announces, in order, until it shuts down.
taken=0
while kill -0 "$server_pid" 2>/dev/null; do
	mapfile -t shots < <(grep -ao '\[r47ml\] SHOT [A-Za-z0-9_]* [0-9-]* [0-9-]*' \
		"$root/server.log" 2>/dev/null | awk '{print $3, $4, $5}')
	if [[ ${#shots[@]} -gt $taken ]]; then
		read -r name px py <<<"${shots[$taken]}"
		if [[ "$px" != "-" ]]; then
			python3 -I "$here/warp.py" ":$display_no" "$px" "$py" || true
		else
			python3 -I "$here/warp.py" ":$display_no" 2 2 || true
		fi
		sleep 1.5
		import -display ":$display_no" -window root "$out/$name$suffix.png"
		echo "capture: $out/$name$suffix.png"
		echo "$name" >"$root/world/r47ml_ack"
		taken=$((taken + 1))
	fi
	grep -q '\[r47ml\] shutdown' "$root/server.log" 2>/dev/null && break
	sleep 0.5
done
echo "capture: $taken shots"
grep -ah '\[r47ml\] \(accept\|window\|character\|READY\|CHECK\)' "$root/server.log" || true
[[ $taken -gt 0 ]]
