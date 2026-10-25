#!/usr/bin/env bash
# Isolated real-client fidelity captures; based on tools/r491_view/capture.sh.
# CAPTURE_REPO can point at a frozen baseline. WIDTH, HEIGHT, GUI_SCALE, XVFB
# select the client. Run through the shared Lua slot queue; no personal paths.
set -euo pipefail
export LC_ALL=C LANG=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="${CAPTURE_REPO:-$(cd "$here/../.." && pwd -P)}"
out="${1:?usage: capture.sh OUT_DIR}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
width="${WIDTH:-1600}"; height="${HEIGHT:-900}"
settle="${SETTLE:-3}"
suffix="${SUFFIX:-}"; gui_scale="${GUI_SCALE:-1}"
server_timeout=360; client_timeout=350
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"

root="$(mktemp -d /tmp/grudgelands-headless.uifidelity-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.uifidelity-XXXXXX)"
patchdir="$(mktemp -d /tmp/grudgelands-capture.uifidelity-patch-XXXXXX)"
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
	cp "$cap/client.console.log" "$out/client-console$suffix.log" 2>/dev/null || true
	cp "$cap/xvfb.log" "$out/xvfb$suffix.log" 2>/dev/null || true
	cp "$cap/headless.txt" "$out/headless$suffix.txt" 2>/dev/null || true
	grep -ah '\[uifidelity\]' "$root/server.log" >"$out/probe$suffix.txt" 2>/dev/null || true
	rm -rf "$root" "$cap" "$patchdir"
}
trap cleanup EXIT

# The probe's settings, as a patch to the staged game's minetest.conf: no
# mob spawns in the pictures and the settle time.
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
cat >>"$patchdir/b/minetest.conf" <<CONF

# 0.49.1 VIEW capture probe
mobs_spawn = false
uifidelity_settle = $settle
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

env ROOT="$root" PORT="$port" PROBE="$here/grug_probe_ui_fidelity" \
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
hud_scaling = $gui_scale
gui_scaling = $gui_scale
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
		--env=LANG=C \
		org.luanti.luanti --go --address 127.0.0.1 --port "$port" \
		--name grugcap --config "$cap/client.conf" \
		--logfile "$cap/client.log" >"$cap/client.console.log" 2>&1 &
client_pid=$!

# Take every shot the probe announces, in order, until it shuts down.
taken=0
while kill -0 "$server_pid" 2>/dev/null; do
	if ! kill -0 "$client_pid" 2>/dev/null; then
		echo "capture client exited before completing all views" >&2
		break
	fi
	mapfile -t shots < <(grep -ao '\[uifidelity\] SHOT [A-Za-z0-9_]*' "$root/server.log" 2>/dev/null |
		awk '{print $3}')
	if [[ ${#shots[@]} -gt $taken ]]; then
		name="${shots[$taken]}"
		sleep 1
		import -display ":$display_no" -window root "$out/$name$suffix.png"
		echo "capture: $out/$name$suffix.png"
		echo "$name" >"$root/world/uifidelity_ack"
		taken=$((taken + 1))
	fi
	grep -q '\[uifidelity\] shutdown' "$root/server.log" 2>/dev/null && break
	sleep 0.5
done
echo "capture: $taken shots"
grep -ah '\[uifidelity\] \(stations\|ran\|READY\)' "$root/server.log" || true
[[ $taken -eq 16 ]]
python3 "$here/check_capture.py" "$out"
