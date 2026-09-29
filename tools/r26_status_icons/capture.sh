#!/usr/bin/env bash
# Round 26 Lane I: an engine screenshot of the status-icon HUD.
#
# A headless server cannot draw, so this boots the isolated server through
# tools/luanti_headless.sh (with the disposable probe grug_probe_status_icons
# staged) and connects ONE real Flatpak client to it on a private Xvfb
# display. The probe completes character creation, starts the statuses and
# logs READY; the frame is then grabbed from the Xvfb root window.
#
# Isolation (AGENTS.md "Testing & development"): the server uses the
# launcher's guarantees; the client gets its own fresh temp dir as
# LUANTI_USER_PATH and every XDG dir, logs inside it, runs under
# `timeout --kill-after`, is killed by a pattern naming that dir, and the dir
# is removed. The personal ~/.var/app/org.luanti.luanti is never touched and
# nothing is drawn on the user's desktop.
#
# Xvfb is not installed on the workstation; pass the path of an unpacked
# binary (dnf download xorg-x11-server-Xvfb; rpm2cpio ... | cpio -idm):
#
# Usage: XVFB=/path/to/Xvfb tools/r26_status_icons/capture.sh OUT.png [GAME_PATCH]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: capture.sh OUT.png [GAME_PATCH]}"
patch_file="${2:-}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
width="${WIDTH:-1280}"; height="${HEIGHT:-720}"
server_timeout=280; client_timeout=270

root="$(mktemp -d /tmp/grudgelands-headless.r26i-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r26i-XXXXXX)"
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

env ROOT="$root" PORT="$port" PROBE="$here/grug_probe_status_icons" \
	${patch_file:+GAME_PATCH="$patch_file"} \
	"$repo/tools/luanti_headless.sh" "$server_timeout" >"$cap/headless.txt" 2>&1 &
server_pid=$!

# Wait until the server listens before the client connects.
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
show_nametag_backgrounds = true
EOF
# flatpak maps the X socket named by ITS OWN $DISPLAY into the sandbox.
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

ready=0
for _ in $(seq 1 240); do
	if grep -q '\[status_icons_probe\] READY' "$root/server.log" 2>/dev/null; then
		ready=1; break
	fi
	kill -0 "$server_pid" 2>/dev/null || break
	sleep 1
done
if [[ $ready -ne 1 ]]; then
	echo "capture: probe never became READY" >&2
	grep -h 'status_icons_probe\|ERROR' "$root/server.log" 2>/dev/null | tail -20 >&2 || true
	tail -20 "$cap/client.log" >&2 2>/dev/null || true
	exit 1
fi
# Two HUD refreshes and a few rendered frames after the statuses start.
sleep 6
mkdir -p "$(dirname "$out")"
import -display ":$display_no" -window root "$out"
grep -h '\[status_icons_probe\]' "$root/server.log" || true
echo "capture: $out"
