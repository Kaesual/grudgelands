#!/usr/bin/env bash
# Round 47 lane TD: render cost of test forests (or a capital) in ONE real
# desktop client, for comparisons between scenes and checkouts (never
# targets).
#
# The method and isolation of tools/r47_tc/capture.sh: the server boots
# through tools/luanti_headless.sh with the disposable probe grug_probe_r47_td
# staged; ONE real Flatpak client connects on a private Xvfb display with its
# own fresh temp dir as LUANTI_USER_PATH and every XDG dir, under `timeout
# --kill-after`. The personal ~/.var/app/org.luanti.luanti is never touched
# and nothing is drawn on the user's desktop. The probe builds a scene and
# logs BUILT; tools/r47_td/drive.py waits until the client has meshed it,
# acks, and records the windows the probe announces (BEGIN/END W and I).
#
# What is measured, per window:
#   * frame times: Mesa's Gallium HUD dump (GALLIUM_HUD=frametime, one value
#     per frame, GALLIUM_HUD_PERIOD=0, the overlay hidden). The client
#     renders through llvmpipe (software GL on the CPU): times compare
#     scenes, they are no GPU's frame times;
#   * the client's own profiler (profiler_print_interval = 1, written to the
#     client log): draw calls, vertices drawn, mesh buffers, MapBlocks drawn,
#     and "Client: Mesh making (sum)" while the scene is meshed;
#   * the client process's resident memory (VmRSS, every 0.5 s).
#
# Usage: XVFB=/path/to/Xvfb [SEED=<u64>] MODE=forest|capital [SPECIES=<key>]
#        [SCENES=<list>] tools/r47_td/measure.sh OUT_DIR
#   WIDTH/HEIGHT (default 1280 x 720, the web build's window), VIEW (viewing
#   range, default 190, the desktop default), W/I (window seconds, default
#   6/8), N_TODAY/N_FIRST/N_NEW (override the probe's tree counts), LP_THREADS
#   (llvmpipe threads, default 8), XVFB_DRIVERS (default /usr/lib64/dri).
#   Run it as a measuring engine run (one boot; the shared queue).
# Writes OUT_DIR/run.json (tools/r47_td/report.py reads it), the
# screenshots OUT_DIR/<species>_<scene>.png, the probe lines and the logs.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: measure.sh OUT_DIR}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
width="${WIDTH:-1280}"; height="${HEIGHT:-720}"
mode="${MODE:-forest}"; species="${SPECIES:-apple}"
scenes="${SCENES:-}"
server_timeout=330; client_timeout=320
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"

root="$(mktemp -d /tmp/grudgelands-headless.r47td-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r47td-XXXXXX)"
patchdir="$(mktemp -d /tmp/grudgelands-capture.r47td-patch-XXXXXX)"
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
	cp "$cap/client.log" "$out/client.log" 2>/dev/null || true
	cp "$cap/headless.txt" "$out/headless.txt" 2>/dev/null || true
	cp "$cap/hud/frametime_(ms)" "$out/frametime.txt" 2>/dev/null || true
	grep -ah '\[r47td\]' "$root/server.log" >"$out/probe.txt" 2>/dev/null || true
	rm -rf "$root" "$cap" "$patchdir"
}
trap cleanup EXIT

mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
{
	printf '\n# Round 47 TD measuring probe\n'
	printf 'grug_atmosphere_zones = false\nmobs_spawn = false\n'
	printf 'r47td_mode = %s\nr47td_species = %s\nr47td_w = %s\nr47td_i = %s\n' \
		"$mode" "$species" "${W:-6}" "${I:-8}"
	[[ -n "$scenes" ]] && printf 'r47td_scenes = %s\n' "$scenes"
	[[ -n "${N_TODAY:-}" ]] && printf 'r47td_n_today = %s\n' "$N_TODAY"
	[[ -n "${N_FIRST:-}" ]] && printf 'r47td_n_first = %s\n' "$N_FIRST"
	[[ -n "${N_NEW:-}" ]] && printf 'r47td_n_new = %s\n' "$N_NEW"
	[[ -n "${CAPITAL:-}" ]] && printf 'r47td_capital = %s\n' "$CAPITAL"
	true
} >>"$patchdir/b/minetest.conf"
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true

# Debian's Xvfb needs the host's Mesa drivers for GLX (tools/r47_tc/capture.sh).
LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
	"$xvfb" ":$display_no" -screen 0 "${width}x${height}x24" -nolisten tcp \
	>"$cap/xvfb.log" 2>&1 &
xvfb_pid=$!
sleep 1

env ROOT="$root" PORT="$port" PROBE="$here/grug_probe_r47_td" ${SEED:+SEED="$SEED"} \
	GAME_PATCH="$patchdir/probe.patch" \
	"$repo/tools/luanti_headless.sh" "$server_timeout" >"$cap/headless.txt" 2>&1 &
server_pid=$!

for _ in $(seq 1 120); do
	grep -q 'listening on' "$root/server.log" 2>/dev/null && break
	sleep 1
done

mkdir -p "$cap/user" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config" "$cap/hud"
cat >"$cap/client.conf" <<CONF
screen_w = $width
screen_h = $height
fullscreen = false
enable_sound = false
viewing_range = ${VIEW:-190}
fps_max = 1000
fps_max_unfocused = 1000
vsync = false
pause_on_lost_focus = false
hud_scaling = 1
gui_scaling = 1
enable_dynamic_shadows = false
enable_bloom = false
leaves_style = fancy
smooth_lighting = true
enable_fog = true
profiler_print_interval = 1
debug_log_level = info
CONF
timeout --kill-after=5 "$client_timeout" \
	env -u WAYLAND_DISPLAY DISPLAY=":$display_no" \
	flatpak run --command=luanti --socket=x11 --nosocket=wayland \
		--filesystem="$cap" \
		--env=DISPLAY=":$display_no" \
		--env=SDL_VIDEODRIVER=x11 \
		--env=__GLX_VENDOR_LIBRARY_NAME=mesa \
		--env=LIBGL_ALWAYS_SOFTWARE=1 \
		--env=LP_NUM_THREADS="${LP_THREADS:-8}" \
		--env=GALLIUM_HUD=frametime \
		--env=GALLIUM_HUD_PERIOD=0 \
		--env=GALLIUM_HUD_VISIBLE=false \
		--env=GALLIUM_HUD_DUMP_DIR="$cap/hud" \
		--env=LUANTI_USER_PATH="$cap/user" \
		--env=XDG_CACHE_HOME="$cap/xdg/cache" \
		--env=XDG_DATA_HOME="$cap/xdg/data" \
		--env=XDG_CONFIG_HOME="$cap/xdg/config" \
		--env=LC_ALL=C \
		org.luanti.luanti --go --address 127.0.0.1 --port "$port" \
		--name grugcap --config "$cap/client.conf" \
		--logfile "$cap/client.log" >"$cap/client.console.log" 2>&1 &
client_pid=$!

python3 -I "$here/drive.py" --server-log "$root/server.log" --client-log "$cap/client.log" \
	--hud "$cap/hud/frametime_(ms)" --ack "$root/world/r47td_ack" --client-tag "$cap/client.log" \
	--display ":$display_no" --out "$out" --server-pid "$server_pid" \
	--label "$([[ "$mode" == capital ]] && echo "capital:${CAPITAL:-highcourt}" || echo "forest:$species")" --prefix "$([[ "$mode" == capital ]] && echo "capital_${CAPITAL:-highcourt}" || echo "$species")"
