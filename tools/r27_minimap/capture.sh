#!/usr/bin/env bash
# Round 27 (WP50): engine screenshots of our own minimap in play, with the
# native minimap off, and of the Map tab (minimap switch, region labels).
#
# Same method and isolation as tools/r26_status_icons/capture.sh: the server
# boots through tools/luanti_headless.sh with the disposable probe
# grug_probe_r27_minimap staged, and ONE real Flatpak client connects on a private
# Xvfb display with its own fresh temp dir as LUANTI_USER_PATH and every XDG
# dir, under `timeout --kill-after`. The personal ~/.var/app/org.luanti.luanti
# is never touched and nothing is drawn on the user's desktop.
#
# Usage: XVFB=/path/to/Xvfb [GAME_PATCH=file] tools/r27_minimap/capture.sh OUT.png
# Writes OUT_before.png / OUT_after.png (walking across a grid-cell edge,
# the texture swapped between them), OUT_off.png (our minimap switched off:
# the corner must be empty, i.e. the native one is off too) and
# OUT_maptab.png (the Map tab). GAME_PATCH (e.g. grug_map_quality = high) is
# passed to tools/luanti_headless.sh.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: capture.sh OUT.png}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
width="${WIDTH:-1280}"; height="${HEIGHT:-720}"
server_timeout=280; client_timeout=270

root="$(mktemp -d /tmp/grudgelands-headless.r27mm-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r27mm-XXXXXX)"
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
	mkdir -p "$(dirname "$out")"
	cp "$root"/server*.log "$cap/client.log" "$(dirname "$out")/" 2>/dev/null || true
	rm -rf "$root" "$cap"
}
trap cleanup EXIT

"$xvfb" ":$display_no" -screen 0 "${width}x${height}x24" -nolisten tcp \
	>"$cap/xvfb.log" 2>&1 &
xvfb_pid=$!
sleep 1

env ROOT="$root" PORT="$port" PROBE="$here/grug_probe_r27_minimap" \
	"$repo/tools/luanti_headless.sh" "$server_timeout" >"$cap/headless.txt" 2>&1 &
server_pid=$!

for _ in $(seq 1 120); do
	grep -q 'listening on' "$root/server.log" 2>/dev/null && break
	sleep 1
done

mkdir -p "$cap/user" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config"
cat >"$cap/client.conf" <<EOF
screen_w = $width
screen_h = $height
fullscreen = false
enable_sound = false
viewing_range = 80
fps_max = 20
hud_scaling = 1
gui_scaling = 1
enable_dynamic_shadows = false
enable_bloom = false
EOF
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

grab() { # PROBE_TAG TARGET
	local ok=0
	for _ in $(seq 1 240); do
		if grep -q "\[r27mm_probe\] $1" "$root/server.log" 2>/dev/null; then
			ok=1; break
		fi
		kill -0 "$server_pid" 2>/dev/null || break
		sleep 1
	done
	if [[ $ok -ne 1 ]]; then
		echo "capture: probe never logged $1" >&2
		grep -h 'r27mm_probe\|ERROR' "$root/server.log" 2>/dev/null | tail -20 >&2 || true
		tail -20 "$cap/client.log" >&2 2>/dev/null || true
		exit 1
	fi
	sleep 4
	mkdir -p "$(dirname "$2")"
	import -display ":$display_no" -window root "$2"
	echo "capture: $2"
}
grab BEFORE "${out%.png}_before.png"
grab AFTER "${out%.png}_after.png"
grab OFF "${out%.png}_off.png"
grab MAPTAB "${out%.png}_maptab.png"
grep -h '\[r27mm_probe\]' "$root/server.log" || true
