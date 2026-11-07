#!/usr/bin/env bash
# Round 71 lane PACK: one engine proof on test_vault with the disposable probe
# grug_probe_r71_pack and ONE real client on a private Xvfb display with its own
# temp dir (method of tools/r71_mobs/run.sh); the personal Luanti folder is never
# touched. The probe kicks the client to log out; each `RELOGIN` line starts it again.
# Run it through the shared Lua queue (2 slots).
#
# Usage: XVFB=/path/to/Xvfb tools/r71_pack/run.sh OUT_DIR
#   TIMEOUT=<server seconds, default 330>, SEED (default 42), XVFB_DRIVERS (default
#   /usr/lib64/dri). Writes probe.txt (the probe's lines), server.log and client.log.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR}"
timeout_s="${TIMEOUT:-330}"; seed="${SEED:-42}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
mkdir -p "$out"; out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r71pack-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r71pack-XXXXXX)"
display_no=$((90 + RANDOM % 900))
while [[ -e "/tmp/.X11-unix/X$display_no" || -e "/tmp/.X$display_no-lock" ]]; do
	display_no=$((display_no + 1))
done
port=$((30000 + (RANDOM * 32768 + RANDOM) % 10000))
xvfb_pid=""; server_pid=""; client_pid=""

stop_client() {
	pkill -TERM -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	[[ -n "$client_pid" ]] && wait "$client_pid" 2>/dev/null || true
	client_pid=""
}

cleanup() {
	stop_client
	pkill -TERM -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	[[ -n "$server_pid" ]] && wait "$server_pid" 2>/dev/null || true
	[[ -n "$xvfb_pid" ]] && kill "$xvfb_pid" 2>/dev/null || true
	[[ -n "$xvfb_pid" ]] && wait "$xvfb_pid" 2>/dev/null || true
	log="$(ls -t "$root"/server*.log 2>/dev/null | grep -v console | head -1 || true)"
	if [[ -n "$log" ]]; then
		cp "$log" "$out/server.log" || true
		grep -a '\[r71pack\]\|GRUG-SEVERE' "$log" >"$out/probe.txt" || true
	fi
	cp "$cap/client.log" "$out/client.log" 2>/dev/null || true
	cp "$cap/headless.txt" "$out/headless.txt" 2>/dev/null || true
	rm -rf "$root" "$cap"
}
trap cleanup EXIT

LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
	"$xvfb" ":$display_no" -screen 0 "960x540x24" -nolisten tcp >"$cap/xvfb.log" 2>&1 &
xvfb_pid=$!
sleep 1

env ROOT="$root" PORT="$port" SEED="$seed" PROBE="$here/grug_probe_r71_pack" \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$cap/headless.txt" 2>&1 &
server_pid=$!

log=""
for _ in $(seq 1 200); do
	log="$(ls -t "$root"/server*.log 2>/dev/null | grep -v console | head -1 || true)"
	[[ -n "$log" ]] && grep -q 'listening on' "$log" 2>/dev/null && break
	sleep 1
done

mkdir -p "$cap/user" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config"
cat >"$cap/client.conf" <<CONF
screen_w = 960
screen_h = 540
fullscreen = false
enable_sound = false
viewing_range = 60
fps_max = 15
hud_scaling = 1
gui_scaling = 1
enable_dynamic_shadows = false
enable_bloom = false
CONF

start_client() {
	timeout --kill-after=5 "$((timeout_s - 5))" \
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
}
start_client

# Every RELOGIN line, a new client, until the server is gone.
started=0
while kill -0 "$server_pid" 2>/dev/null; do
	wanted="$(grep -ac '\[r71pack\] RELOGIN' "$log" 2>/dev/null || true)"
	if [[ "${wanted:-0}" -gt "$started" ]]; then
		started=$wanted
		stop_client
		start_client
	fi
	grep -q '\[r71pack\] shutdown' "$log" 2>/dev/null && break
	sleep 0.5
done
for _ in 1 2 3 4 5 6 7 8 9 10; do
	kill -0 "$server_pid" 2>/dev/null || break
	sleep 1
done
tail -5 "$cap/headless.txt" 2>/dev/null || true
