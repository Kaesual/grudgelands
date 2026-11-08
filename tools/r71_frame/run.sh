#!/usr/bin/env bash
# Round 71 lane FRAME: one engine proof. The server boots through
# tools/luanti_headless.sh with the disposable probe grug_probe_r71_frame and
# ONE real Flatpak client connects on a private Xvfb display with its own temp
# dir (the method of tools/r502_home/capture.sh); the personal Luanti folder is
# never touched. Run it through the shared Lua queue (2 slots).
#
# Usage: XVFB=/path/to/Xvfb SCENARIO=<name> tools/r71_frame/run.sh OUT_DIR
#   TIMEOUT=<server seconds, default 290>, SEED (default 42), WORLD=<a kept run
#   root> re-uses its world, KEEP_WORLD=1 keeps the run root (its path goes to
#   OUT_DIR/root.txt), CONF=<file> extra lines for the staged minetest.conf,
#   CLIENT=0 runs without a client, XVFB_DRIVERS (default /usr/lib64/dri),
#   VIEWING_RANGE (default 190, the client default; lane SPIKE ran 60).
# The probe logs "[r71frame] BURST <name> <seconds>": this script then takes
# screenshots for that long, named <name>_<ms after the burst began>.png.
# Writes probe.txt (the probe's and [GRUG-PERF] lines), load.txt (epoch and
# /proc/loadavg every 2 s, to tell contended runs), the logs and db.txt.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR}"
scenario="${SCENARIO:?set SCENARIO}"
timeout_s="${TIMEOUT:-290}"; seed="${SEED:-42}"; client="${CLIENT:-1}"
mkdir -p "$out"; out="$(cd "$out" && pwd -P)"

if [[ -n "${WORLD:-}" ]]; then root="$WORLD"; else root="$(mktemp -d /tmp/grudgelands-headless.r71frame-XXXXXX)"; fi
cap="$(mktemp -d /tmp/grudgelands-capture.r71frame-XXXXXX)"
patchdir="$(mktemp -d /tmp/grudgelands-capture.r71frame-patch-XXXXXX)"
display_no=$((90 + RANDOM % 900))
while [[ -e "/tmp/.X11-unix/X$display_no" || -e "/tmp/.X$display_no-lock" ]]; do
	display_no=$((display_no + 1))
done
port=$((30000 + (RANDOM * 32768 + RANDOM) % 10000))
xvfb_pid=""; server_pid=""; client_pid=""; sampler_pid=""

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
	[[ -n "$sampler_pid" ]] && kill "$sampler_pid" 2>/dev/null || true
	log="$(ls -t "$root"/server*.log 2>/dev/null | grep -v console | head -1 || true)"
	if [[ -n "$log" ]]; then
		cp "$log" "$out/server.log" || true
		grep -a '\[r71frame\]\|\[GRUG-PERF\]\|GRUG-SEVERE' "$log" >"$out/probe.txt" || true
	fi
	cp "$cap/client.log" "$out/client.log" 2>/dev/null || true
	cp "$cap/headless.txt" "$out/headless.txt" 2>/dev/null || true
	if [[ "${KEEP_WORLD:-0}" == "1" || -n "${WORLD:-}" ]]; then
		echo "$root" >"$out/root.txt"
	else
		rm -rf "$root"
	fi
	rm -rf "$cap" "$patchdir"
}
trap cleanup EXIT

(while :; do echo "$(date +%s) $(cat /proc/loadavg)"; sleep 2; done) >"$out/load.txt" &
sampler_pid=$!

mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
{
	printf '\n# Round 71 FRAME probe\nr71frame_scenario = %s\n' "$scenario"
	[[ -n "${CONF:-}" ]] && cat "$CONF"
} >>"$patchdir/b/minetest.conf"
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true

if [[ "$client" == "1" ]]; then
	xvfb="${XVFB:?set XVFB to an Xvfb binary}"
	LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
		"$xvfb" ":$display_no" -screen 0 "960x540x24" -nolisten tcp >"$cap/xvfb.log" 2>&1 &
	xvfb_pid=$!
	sleep 1
fi

logs_before="$(ls "$root"/server*.log 2>/dev/null | grep -vc console || true)"
env ROOT="$root" PORT="$port" SEED="$seed" PROBE="$here/grug_probe_r71_frame" \
	GAME_PATCH="$patchdir/probe.patch" \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$cap/headless.txt" 2>&1 &
server_pid=$!

latest_log() { ls -t "$root"/server*.log 2>/dev/null | grep -v console | head -1; }
log=""
for _ in $(seq 1 200); do
	# a re-used root still holds the logs of its earlier boots
	if [[ "$(ls "$root"/server*.log 2>/dev/null | grep -vc console || true)" -gt "$logs_before" ]]; then
		log="$(latest_log || true)"
		grep -q 'listening on' "$log" 2>/dev/null && break
	fi
	sleep 1
done

if [[ "$client" == "1" ]]; then
	mkdir -p "$cap/user" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config"
	cat >"$cap/client.conf" <<CONF
screen_w = 960
screen_h = 540
fullscreen = false
enable_sound = false
viewing_range = ${VIEWING_RANGE:-190}
fps_max = 15
hud_scaling = 1
gui_scaling = 1
enable_dynamic_shadows = false
enable_bloom = false
CONF
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
fi

# Screenshot bursts the probe announces, until the server is gone.
taken=0
while kill -0 "$server_pid" 2>/dev/null; do
	mapfile -t bursts < <(grep -ao '\[r71frame\] BURST [A-Za-z0-9_]* [0-9.]*' "$log" 2>/dev/null |
		awk '{print $3 " " $4}')
	if [[ ${#bursts[@]} -gt $taken && "$client" == "1" ]]; then
		read -r name seconds <<<"${bursts[$taken]}"
		start=$(date +%s%3N)
		until_ms=$((start + ${seconds%.*} * 1000))
		while [[ $(date +%s%3N) -lt $until_ms ]]; do
			now=$(date +%s%3N)
			import -display ":$display_no" -window root -resize 480x270 \
				"$out/${name}_$(printf %06d $((now - start))).png" || true
		done
		taken=$((taken + 1))
		echo "burst $name done" >>"$out/bursts.txt"
	fi
	grep -q '\[r71frame\] shutdown' "$log" 2>/dev/null && break
	sleep 0.1
done
for _ in 1 2 3 4 5 6 7 8 9 10; do
	kill -0 "$server_pid" 2>/dev/null || break
	sleep 1
done
tail -20 "$out/headless.txt" 2>/dev/null || true
