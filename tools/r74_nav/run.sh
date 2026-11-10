#!/usr/bin/env bash
# Round 74 lane NAV: one engine run on one Expedition with the disposable probe
# grug_probe_r74_nav and ONE real client on a private Xvfb display with its own temp dir
# (tools/r72_mint/run.sh's method); the personal Luanti folder is never touched. Run it
# through the shared Lua queue (2 slots).
#
# Usage: XVFB=/path/to/Xvfb EXPEDITION=<id> [MODE=full|evade] [GAME=<checkout>] \
#            tools/r74_nav/run.sh OUT_DIR
#   EXPEDITION stilled_seam, second_shift or last_mint. MODE full (default): the evade
#   waves and the chase; evade: the waves only (the baseline). GAME: the checkout whose
#   game and tools/luanti_headless.sh run (default this one; the baseline passes an
#   extracted 0.73.1 tree). TIMEOUT=<server seconds, default 330>, SEED (default 42),
#   XVFB_DRIVERS (default /usr/lib64/dri). Writes probe.txt (the probe's lines),
#   server.log, client.log and plan.lua (tools/r74_nav/plan.py, written from this
#   checkout's templates).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
game="$(cd "${GAME:-$repo}" && pwd -P)"
out="${1:?usage: run.sh OUT_DIR}"
expedition="${EXPEDITION:?set EXPEDITION}"
mode="${MODE:-full}"
timeout_s="${TIMEOUT:-330}"; seed="${SEED:-42}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
mkdir -p "$out"; out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r74nav-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r74nav-XXXXXX)"
probe="$cap/grug_probe_r74_nav"
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
	log="$(ls -t "$root"/server*.log 2>/dev/null | grep -v console | head -1 || true)"
	if [[ -n "$log" ]]; then
		cp "$log" "$out/server.log" || true
		grep -a '\[r74nav\]\|GRUG-SEVERE\|ERROR' "$log" >"$out/probe.txt" || true
	fi
	cp "$cap/client.log" "$out/client.log" 2>/dev/null || true
	cp "$cap/headless.txt" "$out/headless.txt" 2>/dev/null || true
	rm -rf "$root" "$cap"
}
trap cleanup EXIT

cp -r "$here/grug_probe_r74_nav" "$probe"
python3 "$here/plan.py" "$probe/plan.lua" >"$cap/plan.txt"
cp "$probe/plan.lua" "$out/plan.lua"
printf 'return {expedition = "%s", mode = "%s"}\n' "$expedition" "$mode" >"$probe/config.lua"

LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
	"$xvfb" ":$display_no" -screen 0 "960x540x24" -nolisten tcp >"$cap/xvfb.log" 2>&1 &
xvfb_pid=$!
sleep 1

env ROOT="$root" PORT="$port" SEED="$seed" PROBE="$probe" \
	"$game/tools/luanti_headless.sh" "$timeout_s" >"$cap/headless.txt" 2>&1 &
server_pid=$!

log=""
for _ in $(seq 1 200); do
	log="$(ls -t "$root"/server*.log 2>/dev/null | grep -v console | head -1 || true)"
	[[ -n "$log" ]] && grep -q 'listening on' "$log" 2>/dev/null && break
	sleep 1
done

mkdir -p "$cap/user" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config"
cat >"$cap/client.conf" <<CONF
screen_w = 640
screen_h = 360
fullscreen = false
enable_sound = false
viewing_range = 60
fps_max = 10
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

while kill -0 "$server_pid" 2>/dev/null; do
	grep -q '\[r74nav\] shutdown' "$log" 2>/dev/null && break
	sleep 1
done
for _ in 1 2 3 4 5 6 7 8 9 10; do
	kill -0 "$server_pid" 2>/dev/null || break
	sleep 1
done
tail -5 "$cap/headless.txt" 2>/dev/null || true
