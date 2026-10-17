#!/usr/bin/env bash
# Fix 0.50.2 lane CMAP: screenshots of the Claim Stone preview on the
# minimap (claim mode near a border, near a settlement, with a claim in
# view, with the minimap switched off, and without the stone), plus the
# smoke boot's log lines: the world is fresh, so the base and both overlays
# render at its first start.
#
# The method and isolation of tools/r48_hud/capture.sh (copied, names
# changed): the server boots through tools/luanti_headless.sh with the
# disposable probe grug_probe_r502_cmap staged, and ONE real Flatpak client
# connects on a private Xvfb display with its own fresh temp dir as
# LUANTI_USER_PATH and every XDG dir, under `timeout --kill-after`. The
# personal ~/.var/app/org.luanti.luanti is never touched and nothing is
# drawn on the user's desktop. The probe logs "SHOT <name>" when a view is
# ready; this script takes the screenshot and writes the name into
# <world>/r502cmap_ack, which moves the probe on.
#
# Usage: XVFB=/path/to/Xvfb tools/r502_cmap/capture.sh OUT_DIR
#   WIDTH/HEIGHT (default 1920 x 1080), GUI=<gui_scaling> (default 1),
#   SEED (default 42), SUFFIX=<text> appended to every file name,
#   SETTLE=<seconds> before each shot (default 7), XVFB_DRIVERS=<Mesa DRI
#   dir for Xvfb's GLX> (default /usr/lib64/dri). Run it through the shared
#   Lua queue (one boot).
# Writes OUT_DIR/<shot><suffix>.png, OUT_DIR/probe<suffix>.txt (the probe's
# lines and the grug_map render lines) and the logs.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: capture.sh OUT_DIR}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
width="${WIDTH:-1920}"; height="${HEIGHT:-1080}"; gui="${GUI:-1}"
settle="${SETTLE:-7}"; suffix="${SUFFIX:-}"; seed="${SEED:-42}"
server_timeout=300; client_timeout=290
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"

root="$(mktemp -d /tmp/grudgelands-headless.r502cmap-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r502cmap-XXXXXX)"
patchdir="$(mktemp -d /tmp/grudgelands-capture.r502cmap-patch-XXXXXX)"
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
	grep -ah '\[r502cmap\]\|\[grug_map\]' "$root/server.log" >"$out/probe$suffix.txt" 2>/dev/null || true
	rm -rf "$root" "$cap" "$patchdir"
}
trap cleanup EXIT

# The probe's settings, as a patch to the staged game's minetest.conf: no
# mob spawns and the settle time.
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
cat >>"$patchdir/b/minetest.conf" <<CONF

# fix 0.50.2 CMAP capture probe
mobs_spawn = false
r502cmap_settle = $settle
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

env ROOT="$root" PORT="$port" SEED="$seed" PROBE="$here/grug_probe_r502_cmap" \
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
	mapfile -t shots < <(grep -ao '\[r502cmap\] SHOT [A-Za-z0-9_]*' "$root/server.log" 2>/dev/null |
		awk '{print $3}')
	if [[ ${#shots[@]} -gt $taken ]]; then
		name="${shots[$taken]}"
		sleep 1
		import -display ":$display_no" -window root "$out/$name$suffix.png"
		echo "capture: $out/$name$suffix.png"
		echo "$name" >"$root/world/r502cmap_ack"
		taken=$((taken + 1))
	fi
	grep -q '\[r502cmap\] shutdown' "$root/server.log" 2>/dev/null && break
	sleep 0.5
done
echo "capture: $taken shots"
grep -ah '\[r502cmap\] \(spots\|draft\|minimap\|character\|READY\|CHECK\)\|\[grug_map\] render' "$root/server.log" || true
[[ $taken -gt 0 ]]
