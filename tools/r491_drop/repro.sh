#!/usr/bin/env bash
# 0.49.1 DROP: reproduce "mob drops slide slowly and cannot be picked up" with
# a real client over a lossy link. Disposable; nothing here ships.
#
# The server (tools/luanti_headless.sh with grug_probe_r491_drop staged) and
# ONE real Flatpak client run inside a private, unprivileged network
# namespace (`unshare -rn`) whose loopback drops LOSS percent of all packets
# (netem): the internet's packet loss, on 127.0.0.1 only, without root and
# without touching the host's network. The client draws on a private Xvfb
# display, uses its own fresh temp dir as LUANTI_USER_PATH and every XDG dir,
# and loads one client mod (r491scan) that logs where the CLIENT draws every
# object under it. The probe throws mob-style drops below the hovering
# client at Bannerbreak Warhold and logs where the SERVER has them;
# analyze.py compares the two. The personal ~/.var/app/org.luanti.luanti is
# never touched and nothing is drawn on the user's desktop.
#
# Usage: XVFB=/path/to/Xvfb [LOSS=15] [WAVES=20] [SEED=<u64>] \
#        tools/r491_drop/repro.sh OUT_DIR
#   Run it through the shared Lua queue with 2 slots (server and client).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: repro.sh OUT_DIR}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
loss="${LOSS:-15}"; waves="${WAVES:-20}"

if [[ "${R491_INNER:-0}" != "1" ]]; then
	xvfb="${XVFB:?set XVFB to an Xvfb binary}"
	display_no=$((90 + RANDOM % 900))
	while [[ -e "/tmp/.X11-unix/X$display_no" || -e "/tmp/.X$display_no-lock" ]]; do
		display_no=$((display_no + 1))
	done
	xlog="$(mktemp /tmp/grudgelands-capture.r491drop-xvfb-XXXXXX)"
	LIBGL_DRIVERS_PATH="${XVFB_DRIVERS:-/usr/lib64/dri}" \
		"$xvfb" ":$display_no" -screen 0 960x540x24 -nolisten tcp >"$xlog" 2>&1 &
	xvfb_pid=$!
	sleep 1
	set +e
	R491_INNER=1 R491_DISPLAY="$display_no" LOSS="$loss" WAVES="$waves" \
		unshare -rn bash "$here/repro.sh" "$out"
	rc=$?
	set -e
	kill "$xvfb_pid" 2>/dev/null || true
	wait "$xvfb_pid" 2>/dev/null || true
	rm -f "$xlog"
	python3 "$here/analyze.py" "$out" | tee "$out/analysis.txt"
	exit $rc
fi

# ---- inside the private network namespace ---------------------------------
ip link set lo up
tc qdisc add dev lo root netem loss "${loss}%"
tc qdisc show dev lo >"$out/netem.txt"
display_no="$R491_DISPLAY"
root="$(mktemp -d /tmp/grudgelands-headless.r491drop-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r491drop-XXXXXX)"
patchdir="$(mktemp -d /tmp/grudgelands-capture.r491drop-patch-XXXXXX)"
port=$((30000 + (RANDOM * 32768 + RANDOM) % 10000))
server_pid=""; client_pid=""
cleanup() {
	pkill -TERM -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	pkill -TERM -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "luanti.bin --go .*--logfile $cap/" 2>/dev/null || true
	pkill -KILL -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	[[ -n "$client_pid" ]] && wait "$client_pid" 2>/dev/null || true
	[[ -n "$server_pid" ]] && wait "$server_pid" 2>/dev/null || true
	cp "$root/server.log" "$out/server.log" 2>/dev/null || true
	cp "$cap/client.log" "$out/client.log" 2>/dev/null || true
	cp "$cap/headless.txt" "$out/headless.txt" 2>/dev/null || true
	grep -ah '\[r491drop\]' "$root/server.log" >"$out/probe.txt" 2>/dev/null || true
	grep -ah '\[r491c\]' "$cap/client.log" >"$out/client_scan.txt" 2>/dev/null || true
	rm -rf "$root" "$cap" "$patchdir"
}
trap cleanup EXIT

# The probe's server settings, as a patch to the staged game's minetest.conf:
# the client mod may read objects and nodes (csm_restriction_flags = 0).
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
cat >>"$patchdir/b/minetest.conf" <<CONF

# 0.49.1 DROP reproduction probe
csm_restriction_flags = 0
csm_restriction_noderange = 0
r491drop_waves = $waves
CONF
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true

env ROOT="$root" PORT="$port" PROBE="$here/grug_probe_r491_drop" ${SEED:+SEED="$SEED"} \
	GAME_PATCH="$patchdir/probe.patch" \
	"$repo/tools/luanti_headless.sh" 290 >"$cap/headless.txt" 2>&1 &
server_pid=$!
for _ in $(seq 1 120); do
	grep -q 'listening on' "$root/server.log" 2>/dev/null && break
	sleep 1
done

mkdir -p "$cap/user/clientmods" "$cap/xdg/cache" "$cap/xdg/data" "$cap/xdg/config"
cp -a "$here/r491scan" "$cap/user/clientmods/r491scan"
printf 'name = r491scan\n' >"$cap/user/clientmods/r491scan/mod.conf"
printf 'load_mod_r491scan = true\n' >"$cap/user/clientmods/mods.conf"
cat >"$cap/client.conf" <<CONF
screen_w = 960
screen_h = 540
fullscreen = false
enable_sound = false
enable_client_modding = true
viewing_range = 80
fps_max = 20
enable_dynamic_shadows = false
enable_bloom = false
CONF
timeout --kill-after=5 280 \
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
		--name grugdrop --config "$cap/client.conf" \
		--logfile "$cap/client.log" >"$cap/client.console.log" 2>&1 &
client_pid=$!

while kill -0 "$server_pid" 2>/dev/null; do
	grep -q '\[r491drop\] shutdown' "$root/server.log" 2>/dev/null && break
	sleep 1
done
sleep 3
