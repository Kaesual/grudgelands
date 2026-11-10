#!/usr/bin/env bash
# Round 74 lane HUD: screenshots of the hotbar with the action clock's cover
# (two moments of its clearing), a real cooldown beside it and the waiting
# cast's marker, at desktop and web scaling, in ONE server boot.
#
# Method of tools/r48_hud/capture.sh (the SHOT / ack handshake) and
# tools/r74_mount/run.sh (the client stopped and started again): the server
# boots through tools/luanti_headless.sh with the disposable probe
# grug_probe_r74_hud staged, and one real Flatpak client connects on a
# private Xvfb display with its own fresh temp dir as LUANTI_USER_PATH and
# every XDG dir, under `timeout --kill-after`. Session 1 is the desktop
# (1920 x 1080, HUD and GUI scaling 1), session 2 a web-build browser window
# (1024 x 600, HUD and GUI scaling 2). The probe logs "SHOT <name>" when a
# view is ready; this script takes the screenshot (the whole screen into
# OUT_DIR/root/, cropped to the client's centred window) and writes the name into <world>/r74hud_ack; "LEAVE <n>" stops the
# client, "JOIN <n>" starts the next session. The personal
# ~/.var/app/org.luanti.luanti is never touched.
#
# Usage: XVFB=/path/to/Xvfb tools/r74_hud/capture.sh OUT_DIR
#   SEED (default 42), SETTLE=<seconds> before each shot (default 4),
#   XVFB_DRIVERS (default /usr/lib64/dri). Run it through the shared Lua
#   queue (one boot, 2 slots). Writes OUT_DIR/<shot>_<session>.png,
#   probe.txt and the logs.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: capture.sh OUT_DIR}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
settle="${SETTLE:-4}"; seed="${SEED:-42}"
server_timeout=300
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"

root="$(mktemp -d /tmp/grudgelands-headless.r74hud-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r74hud-XXXXXX)"
patchdir="$(mktemp -d /tmp/grudgelands-capture.r74hud-patch-XXXXXX)"
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
	cp "$root/server.log" "$out/server.log" 2>/dev/null || true
	cp "$cap"/client*.log "$out/" 2>/dev/null || true
	cp "$cap/headless.txt" "$out/headless.txt" 2>/dev/null || true
	grep -ah '\[r74hud\]\|GRUG-SEVERE' "$root/server.log" >"$out/probe.txt" 2>/dev/null || true
	rm -rf "$root" "$cap" "$patchdir"
}
trap cleanup EXIT

# The probe's settings: no mob spawns and the settle time.
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
cat >>"$patchdir/b/minetest.conf" <<CONF

# Round 74 HUD capture probe
mobs_spawn = false
r74hud_settle = $settle
CONF
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true

LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
	"$xvfb" ":$display_no" -screen 0 "1920x1080x24" -nolisten tcp \
	>"$cap/xvfb.log" 2>&1 &
xvfb_pid=$!
sleep 1

env ROOT="$root" PORT="$port" SEED="$seed" PROBE="$here/grug_probe_r74_hud" \
	GAME_PATCH="$patchdir/probe.patch" \
	"$repo/tools/luanti_headless.sh" "$server_timeout" >"$cap/headless.txt" 2>&1 &
server_pid=$!

for _ in $(seq 1 120); do
	grep -q 'listening on' "$root/server.log" 2>/dev/null && break
	sleep 1
done

mkdir -p "$cap/user" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config"
started=$(date +%s)
geometry=""
# Session <n>: 1 desktop, 2 web; its log is client<n>.log.
start_client() {
	local n="$1" w h scale
	if [[ "$n" == 1 ]]; then w=1920; h=1080; scale=1; else w=1024; h=600; scale=2; fi
	# Without a window manager the client window opens centred on the
	# 1920 x 1080 screen (seen in the first run: 1024 x 600 at +448+240).
	geometry="${w}x${h}+$(((1920 - w) / 2))+$(((1080 - h) / 2))"
	cat >"$cap/client$n.conf" <<CONF
screen_w = $w
screen_h = $h
fullscreen = false
enable_sound = false
viewing_range = 60
fps_max = 20
hud_scaling = $scale
gui_scaling = $scale
enable_dynamic_shadows = false
enable_bloom = false
CONF
	local remaining=$((server_timeout - 10 - ($(date +%s) - started)))
	timeout --kill-after=5 "$remaining" \
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
			--name grugcap --config "$cap/client$n.conf" \
			--logfile "$cap/client$n.log" >"$cap/client$n.console.log" 2>&1 &
	client_pid=$!
}
start_client 1

# Take every shot the probe announces, in order; stop and start the client
# on LEAVE / JOIN; until the probe shuts the server down.
taken=0; handled=" "
while kill -0 "$server_pid" 2>/dev/null; do
	mapfile -t shots < <(grep -ao '\[r74hud\] SHOT [A-Za-z0-9_]*' "$root/server.log" 2>/dev/null |
		awk '{print $3}')
	if [[ ${#shots[@]} -gt $taken ]]; then
		name="${shots[$taken]}"
		sleep 1
		mkdir -p "$out/root"
		import -display ":$display_no" -window root "$out/root/$name.png"
		convert "$out/root/$name.png" -crop "$geometry" +repage "$out/$name.png"
		echo "capture: $out/$name.png"
		echo "$name" >"$root/world/r74hud_ack"
		taken=$((taken + 1))
	fi
	for line in $(grep -ao '\[r74hud\] \(LEAVE\|JOIN\) [0-9]*' "$root/server.log" 2>/dev/null |
			awk '{print $2 "_" $3}'); do
		if [[ "$handled" != *" $line "* ]]; then
			handled="$handled$line "
			if [[ "$line" == LEAVE_* ]]; then
				pkill -TERM -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
				for _ in $(seq 1 75); do
					pgrep -f "luanti.bin --go .*--logfile $cap/" >/dev/null || break
					sleep 0.2
				done
				pkill -KILL -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
				wait "$client_pid" 2>/dev/null || true
				client_pid=""
			else
				start_client "${line#JOIN_}"
			fi
		fi
	done
	grep -q '\[r74hud\] shutdown' "$root/server.log" 2>/dev/null && break
	sleep 0.5
done
echo "capture: $taken shots"
grep -ah '\[r74hud\] \(session\|READY\|CHECK\|LEAVE\|JOIN\)' "$root/server.log" || true
[[ $taken -gt 0 ]]
