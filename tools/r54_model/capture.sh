#!/usr/bin/env bash
# Round 54 lane MODEL: screenshots of the character models in a real client.
# The probe grug_probe_r54_model (a copy staged per run) shows mesh figures
# frozen on one frame in a studio; the default scene (scene.lua) shows the
# player and NPC models with metal T6 test art baked naively into the armor
# atlas (naive_atlas.py, written into the staged copy's textures), standing
# and mid-walk from several sides, the weapon card beside the world's wield
# entity, and the capture player's own model as the game composes it.
#
# The method and isolation of tools/r531_race/capture.sh (copied, names
# changed): the server boots through tools/luanti_headless.sh with the probe
# staged, and ONE real Flatpak client connects on a private Xvfb display with
# its own fresh temp dir as LUANTI_USER_PATH and every XDG dir, under
# `timeout --kill-after`. The personal ~/.var/app/org.luanti.luanti is never
# touched and nothing is drawn on the user's desktop. The probe logs
# "SHOT <name>" when a view is ready; this script takes the screenshot and
# writes the name into <world>/r54model_ack, which moves the probe on.
#
# Usage: XVFB=/path/to/Xvfb tools/r54_model/capture.sh OUT_DIR
#   SCENE=<file> replaces the probe's scene.lua (another lane's shots; the
#   format is in grug_probe_r54_model/init.lua), ART=<art dir> (default
#   tools/r54_armor/test_art), LINE/TIER (default metal T6) for the
#   r54model_T6_* and r54model_steel_* textures,
#   WIDTH/HEIGHT (default 1600 x 900), GUI=<gui_scaling> (default 1),
#   SEED (default 42), SUFFIX=<text> appended to every file name,
#   SETTLE=<seconds> before each shot (default 6), XVFB_DRIVERS=<Mesa DRI
#   dir for Xvfb's GLX> (default /usr/lib64/dri), MODELS=<dir> whose files
#   are copied into the staged probe's models/ (extra meshes a scene names,
#   e.g. the web export's .glb; tools/r54_web). Run it through the shared
#   Lua queue (one boot).
# Writes OUT_DIR/<shot><suffix>.png, OUT_DIR/probe<suffix>.txt and the logs.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: capture.sh OUT_DIR}"
xvfb="${XVFB:?set XVFB to an Xvfb binary}"
width="${WIDTH:-1600}"; height="${HEIGHT:-900}"; gui="${GUI:-1}"
settle="${SETTLE:-6}"; suffix="${SUFFIX:-}"; seed="${SEED:-42}"
server_timeout=300; client_timeout=290
art="${ART:-$repo/tools/r54_armor/test_art}"; line="${LINE:-metal}"; tier="${TIER:-T6}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"

root="$(mktemp -d /tmp/grudgelands-headless.r54model-XXXXXX)"
cap="$(mktemp -d /tmp/grudgelands-capture.r54model-XXXXXX)"
patchdir="$(mktemp -d /tmp/grudgelands-capture.r54model-patch-XXXXXX)"
probedir="$(mktemp -d /tmp/grudgelands-capture.r54model-probe-XXXXXX)"
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
	grep -ah '\[r54model\]' "$root/server.log" >"$out/probe$suffix.txt" 2>/dev/null || true
	rm -rf "$root" "$cap" "$patchdir" "$probedir"
}
trap cleanup EXIT

# The staged probe: a copy with the stand-in textures and the scene.
probe="$probedir/grug_probe_r54_model"
cp -a "$here/grug_probe_r54_model" "$probe"
mkdir -p "$probe/textures"
[[ -n "${SCENE:-}" ]] && cp "$SCENE" "$probe/scene.lua"
if [[ -n "${MODELS:-}" ]]; then
	mkdir -p "$probe/models"
	cp "$MODELS"/* "$probe/models/"
fi
python3 "$here/naive_atlas.py" --art "$art" --line "$line" --tier "$tier" \
	--name r54model_T6 --out "$probe/textures"
python3 "$here/naive_atlas.py" --art "$art" --line "$line" --tier "$tier" --palette steel \
	--name r54model_steel --out "$probe/textures"

# The probe's settings, as a patch to the staged game's minetest.conf: no
# mob spawns and the settle time.
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
cat >>"$patchdir/b/minetest.conf" <<CONF

# Round 54 MODEL capture probe
mobs_spawn = false
r54model_settle = $settle
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

env ROOT="$root" PORT="$port" SEED="$seed" PROBE="$probe" \
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
	mapfile -t shots < <(grep -ao '\[r54model\] SHOT [A-Za-z0-9_]*' "$root/server.log" 2>/dev/null |
		awk '{print $3}')
	if [[ ${#shots[@]} -gt $taken ]]; then
		name="${shots[$taken]}"
		sleep 1
		import -display ":$display_no" -window root "$out/$name$suffix.png"
		echo "capture: $out/$name$suffix.png"
		echo "$name" >"$root/world/r54model_ack"
		taken=$((taken + 1))
	fi
	grep -q '\[r54model\] shutdown' "$root/server.log" 2>/dev/null && break
	sleep 0.5
done
echo "capture: $taken shots"
grep -ah '\[r54model\] \(character\|player\|studio\|READY\|figure\)' "$root/server.log" || true
[[ $taken -gt 0 ]]
