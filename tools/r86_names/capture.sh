#!/usr/bin/env bash
# Round 86 lane NAMES: screenshots of home names with the house icon: the
# entry banner and the line under the minimap (the default name and the
# longest, 24 W), the protection hint (both names), the Map tab and the
# Claim Stone form's rename row (and a refused name), each at two HUD and
# GUI scales: ONE server boot, two client connections in turn (the probe
# kicks the first after its round). The probe's CHECK lines go to
# OUT_DIR/probe.txt.
#
# The method and isolation of tools/r502_home/capture.sh (copied, names
# changed): the server boots through tools/luanti_headless.sh with the
# disposable probe grug_probe_r86_names staged, and real Flatpak clients
# connect one after the other on a private Xvfb display, each with its own
# fresh temp dir as LUANTI_USER_PATH and every XDG dir, under
# `timeout --kill-after`. The personal ~/.var/app/org.luanti.luanti is never
# touched and nothing is drawn on the user's desktop. The probe logs
# "SHOT <name>" when a view is ready; this script takes the screenshot and
# writes the name into <world>/r86names_ack, which moves the probe on.
#
# Usage: XVFB=/path/to/Xvfb tools/r86_names/capture.sh OUT_DIR
#   WIDTH/HEIGHT (default 1920 x 1080), SCALES="<gui>:<hud> <gui>:<hud>"
#   (the two clients' gui_scaling and hud_scaling, default "1:1 1.5:1.5"),
#   SEED (default 42), SETTLE=<seconds> before each shot (default 5),
#   SCENE=names (the lane's shots, default) or account (fix round 1: an
#   account claim as a visitor and as a member, the personal claim's form),
#   XVFB_DRIVERS=<Mesa DRI dir for Xvfb's GLX> (default /usr/lib64/dri).
#   Run it through the shared Lua queue (one boot).
# Writes OUT_DIR/<shot>_s<round>.png, OUT_DIR/probe.txt and the logs.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: capture.sh OUT_DIR}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
width="${WIDTH:-1920}"; height="${HEIGHT:-1080}"
read -r -a scales <<<"${SCALES:-1:1 1.5:1.5}"
settle="${SETTLE:-5}"; suffix=""; seed="${SEED:-42}"; scene="${SCENE:-names}"
server_timeout=330; client_timeout=200
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"

root="$(mktemp -d /tmp/grudgelands-headless.r86names-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r86names-XXXXXX)"
patchdir="$(mktemp -d /tmp/grudgelands-capture.r86names-patch-XXXXXX)"
display_no=$((90 + RANDOM % 900))
while [[ -e "/tmp/.X11-unix/X$display_no" || -e "/tmp/.X$display_no-lock" ]]; do
	display_no=$((display_no + 1))
done
port=$((30000 + (RANDOM * 32768 + RANDOM) % 10000))
xvfb_pid=""; server_pid=""; client_pid=""

cleanup() {
	pkill -TERM -f "luanti.bin --go .*--logfile $cap/c" 2>/dev/null || true
	pkill -TERM -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "luanti.bin --go .*--logfile $cap/c" 2>/dev/null || true
	pkill -KILL -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	[[ -n "$client_pid" ]] && wait "$client_pid" 2>/dev/null || true
	[[ -n "$server_pid" ]] && wait "$server_pid" 2>/dev/null || true
	[[ -n "$xvfb_pid" ]] && kill "$xvfb_pid" 2>/dev/null || true
	[[ -n "$xvfb_pid" ]] && wait "$xvfb_pid" 2>/dev/null || true
	cp "$root/server.log" "$out/server$suffix.log" 2>/dev/null || true
	for log in "$cap"/c*/client.log; do cp "$log" "$out/client_$(basename "$(dirname "$log")").log" 2>/dev/null || true; done
	cp "$cap/headless.txt" "$out/headless$suffix.txt" 2>/dev/null || true
	grep -ah '\[r86names\]\|\[grug_housing\]' "$root/server.log" >"$out/probe.txt" 2>/dev/null || true
	rm -rf "$root" "$cap" "$patchdir"
}
trap cleanup EXIT

# The probe's settings, as a patch to the staged game's minetest.conf: no
# mob spawns and the settle time.
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
cat >>"$patchdir/b/minetest.conf" <<CONF

# Round 86 NAMES capture probe
mobs_spawn = false
r86names_settle = $settle
r86names_scene = $scene
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

env ROOT="$root" PORT="$port" SEED="$seed" PROBE="$here/grug_probe_r86_names" \
	GAME_PATCH="$patchdir/probe.patch" \
	"$repo/tools/luanti_headless.sh" "$server_timeout" >"$cap/headless.txt" 2>&1 &
server_pid=$!

for _ in $(seq 1 120); do
	grep -q 'listening on' "$root/server.log" 2>/dev/null && break
	sleep 1
done

# One client with gui_scaling and hud_scaling, in its own temp dirs.
start_client() {
	local dir="$cap/c$1" gui="$2" hud="$3"
	mkdir -p "$dir/user" "$dir/xdg/cache" "$dir/xdg/data" "$dir/xdg/config"
	cat >"$dir/client.conf" <<CONF
screen_w = $width
screen_h = $height
fullscreen = false
enable_sound = false
viewing_range = 60
fps_max = 20
hud_scaling = $hud
gui_scaling = $gui
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
			--env=LUANTI_USER_PATH="$dir/user" \
			--env=XDG_CACHE_HOME="$dir/xdg/cache" \
			--env=XDG_DATA_HOME="$dir/xdg/data" \
			--env=XDG_CONFIG_HOME="$dir/xdg/config" \
			--env=LC_ALL=C \
			org.luanti.luanti --go --address 127.0.0.1 --port "$port" \
			--name grugcap --config "$dir/client.conf" \
			--logfile "$dir/client.log" >"$dir/client.console.log" 2>&1 &
	client_pid=$!
}

# Take every shot the probe announces, in order; a finished round ends its
# client and starts the next one, the probe's shutdown ends the run.
taken=0; round=1
start_client 1 "${scales[0]%%:*}" "${scales[0]##*:}"
while kill -0 "$server_pid" 2>/dev/null; do
	mapfile -t shots < <(grep -ao '\[r86names\] SHOT [A-Za-z0-9_]*' "$root/server.log" 2>/dev/null |
		awk '{print $3}')
	if [[ ${#shots[@]} -gt $taken ]]; then
		name="${shots[$taken]}"
		sleep 1
		import -display ":$display_no" -window root "$out/$name.png"
		echo "capture: $out/$name.png"
		echo "$name" >"$root/world/r86names_ack"
		taken=$((taken + 1))
	fi
	grep -q '\[r86names\] shutdown' "$root/server.log" 2>/dev/null && break
	if [[ $round -lt ${#scales[@]} ]] &&
			grep -q "\[r86names\] ROUND $round done" "$root/server.log" 2>/dev/null; then
		sleep 2
		pkill -TERM -f "luanti.bin --go .*--logfile $cap/c$round/" 2>/dev/null || true
		wait "$client_pid" 2>/dev/null || true
		round=$((round + 1))
		start_client "$round" "${scales[$((round - 1))]%%:*}" "${scales[$((round - 1))]##*:}"
	fi
	sleep 0.5
done
echo "capture: $taken shots"
grep -ah '\[r86names\] \(spots\|claim\|minimap\|character\|READY\|CHECK\|ROUND\)' "$root/server.log" || true
[[ $taken -gt 0 ]]
