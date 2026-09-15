#!/usr/bin/env bash
# The Highcourt engine pass: one headless boot that emerges the capital's own
# mapchunks, times them, inventories its NPC sockets and dumps what it built as
# TSVs the renderer can draw.
#
# It is a separate runner from `tools/wp13/run_engine.sh` because that one is the
# six-start digest gate and must not change, and from the WP40 profiler because
# the profiler deletes its world on exit while this pass has to KEEP the world:
# the dumps are written into it by the probe (writing inside the world directory
# is what the engine's own security sandbox allows a mod to do).
#
# Isolation, the same guarantees `tools/luanti_headless.sh` gives (user rule,
# 2026-09-14): a fresh scratch directory as LUANTI_USER_PATH and as every XDG
# directory, the log inside it, a `timeout --kill-after`, only this run's own
# server killed, and nothing under the personal Flatpak folder touched.
#
# Usage: run_highcourt.sh OUTPUT_DIR [surface|field|full] [SEED]
#   OUTPUT_DIR  absolute, must not exist; receives the log, the dumps and the
#               per-mapchunk timings.
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: run_highcourt.sh OUTPUT_DIR [surface|field|full] [SEED]}"
mode="${2:-full}"
seed="${3:-531802985935182545}"
[[ "$output" = /* && ! -e "$output" ]] || {
	echo "run_highcourt: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
[[ "$mode" == "surface" || "$mode" == "field" || "$mode" == "full" ]] || {
	echo "run_highcourt: mode must be surface, field or full" >&2
	exit 2
}
[[ "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "run_highcourt: SEED must be canonical unsigned decimal" >&2
	exit 2
}
timeout_s="${WP13_HIGHCOURT_TIMEOUT:-1500}"
[[ "$timeout_s" =~ ^[1-9][0-9]*$ && "$timeout_s" -le 3600 ]] || {
	echo "run_highcourt: WP13_HIGHCOURT_TIMEOUT must be 1..3600" >&2
	exit 2
}
port="${WP13_HIGHCOURT_PORT:-32910}"
[[ "$port" =~ ^[1-9][0-9]{3,4}$ && "$port" -le 65000 ]] || exit 2
# An extra region for the probe to read back out of the finished map, as
# anchor-relative `min_x,max_x,min_z,max_z`. Empty by default: the probe's own
# regions are the ones a capital always has, and where a WP40 route bridges a
# river inside the envelope is a fact about the seed that
# `tools/wp13/lane_routes.lua` measures.
crossing="${WP13_HIGHCOURT_CROSSING:-}"
[[ -z "$crossing" ||
	"$crossing" =~ ^(-?[0-9]+,-?[0-9]+,-?[0-9]+,-?[0-9]+)(\;-?[0-9]+,-?[0-9]+,-?[0-9]+,-?[0-9]+)*$ ]] || {
	echo "run_highcourt: WP13_HIGHCOURT_CROSSING must be one to four" \
		"min_x,max_x,min_z,max_z boxes separated by ';'" >&2
	exit 2
}

mkdir -p "$output"
root="$(mktemp -d /tmp/grudgelands-wp13-highcourt.XXXXXX)"
case "$root" in
	/tmp/grudgelands-wp13-highcourt.*) ;;
	*) echo "run_highcourt: scratch path differs" >&2; exit 2 ;;
esac
cleanup() {
	pkill -TERM -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	rm -rf -- "$root"
}
trap cleanup EXIT

user_path="$root/user"
game="$user_path/games/grudgelands"
world="$root/world"
mkdir -p "$game" "$world" "$root/xdg/cache" "$root/xdg/data" "$root/xdg/config"
cp -a "$repo/game.conf" "$repo/mods" "$game/"
for optional in minetest.conf settingtypes.txt menu textures; do
	[[ -e "$repo/$optional" ]] && cp -a "$repo/$optional" "$game/"
done
# The disposable probe, staged only here.
cp -a "$repo/tools/wp13/highcourt_probe" "$game/mods/grug_wp13_highcourt_probe"
( cd "$repo" && find tools/wp13/highcourt_probe tools/wp13/run_highcourt.sh \
	-type f -print0 | sort -z | xargs -0 sha256sum ) >"$output/harness.sha256"

printf 'gameid = grudgelands\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\n' \
	>"$world/world.mt"
cat >"$root/server.conf" <<CONF
port = $port
bind_address = 127.0.0.1
server_announce = false
secure.enable_security = true
fixed_map_seed = $seed
num_emerge_threads = 1
grug_wp13_probe_mode = $mode
grug_wp13_probe_timeout = $((timeout_s - 120))
grug_wp13_probe_crossing = $crossing
CONF

# The log lives inside the scratch tree the sandbox is given, and is copied out
# afterwards: the output directory is deliberately NOT exposed to the engine.
engine_log="$root/server.log"
log="$output/server.log"
status=0
set +e
timeout --foreground --kill-after=30 "$timeout_s" \
	flatpak run --command=luanti \
		--filesystem="$root" \
		--env=LUANTI_USER_PATH="$user_path" \
		--env=XDG_CACHE_HOME="$root/xdg/cache" \
		--env=XDG_DATA_HOME="$root/xdg/data" \
		--env=XDG_CONFIG_HOME="$root/xdg/config" \
		--env=LC_ALL=C \
		org.luanti.luanti --server --gameid grudgelands --world "$world" \
		--config "$root/server.conf" --logfile "$engine_log" \
		--log-timestamp none --color never >"$output/console.log" 2>&1
status=$?
set -e
[[ -f "$engine_log" ]] && cp "$engine_log" "$log"
[[ -f "$log" ]] || { echo "run_highcourt: no server log" >&2; exit 1; }

# The probe dumps one region per district, four more named regions -- the pond,
# the orchard belt, the chapel yard and a profession house -- the core, the
# avenue, the four lane/route crossings, and since the wall ring landed a
# stretch of curtain with a turret and the east gatehouse. The plot dumps are
# numbered rather than named, so the eight of them run 1..8 in the probe's own
# order.
for dump in highcourt-core.tsv highcourt-avenue.tsv highcourt-surface.tsv \
		highcourt-field.tsv highcourt-crossing-1.tsv highcourt-crossing-2.tsv \
		highcourt-crossing-3.tsv highcourt-crossing-4.tsv \
		highcourt-wall.tsv highcourt-gate.tsv \
		highcourt-plot-1.tsv highcourt-plot-2.tsv highcourt-plot-3.tsv \
		highcourt-plot-4.tsv highcourt-plot-5.tsv highcourt-plot-6.tsv \
		highcourt-plot-7.tsv highcourt-plot-8.tsv; do
	[[ -f "$world/$dump" ]] && cp "$world/$dump" "$output/$dump"
done
grep 'GRUG_WP13_HIGHCOURT' "$log" >"$output/probe.txt" || true
grep 'start npcs' "$log" >"$output/npcs.txt" || true
grep -c 'ERROR' "$log" >"$output/error-count.txt" || echo 0 >"$output/error-count.txt"
grep -c 'ModError' "$log" >"$output/moderror-count.txt" || echo 0 >"$output/moderror-count.txt"

errors="$(grep -c 'ERROR\|ModError' "$log" || true)"
complete="$(grep -c 'GRUG_WP13_HIGHCOURT event=complete' "$log" || true)"
printf 'exit=%s errors=%s complete=%s log=%s\n' "$status" "$errors" "$complete" "$log"
[[ "$errors" -eq 0 && "$complete" -ge 1 ]] || {
	echo "WP13 Highcourt pass FAILED; inspect $log" >&2
	exit 1
}

# THE ROAD'S BUILT GEOMETRY, checked against a frozen value.
#
# Nothing else in the tree hashes it: the overlay's manifest identity is its
# SPECIFICATION (it has no cells until a surface arrives) and the six-start
# engine gate excludes capitals by construction, so a change to `avenue.run`
# could move every node of every capital road in silence. The probe digests the
# avenue it read back out of the finished map; this compares that digest with
# the one the evidence carries for this seed.
#
# WP40 terrain changes move the ground the road follows and therefore this
# value: it is a "look at what moved" gate, not a frozen-forever constant, and
# the expectation file says which seed and which main commit it was taken on.
if [[ "$mode" == "full" ]]; then
	digest="$(grep -o 'avenue_road_digest=[0-9a-f]*' "$log" | tail -1 |
		cut -d= -f2)"
	road_cells="$(grep -o 'avenue_road_cells=[0-9]*' "$log" | tail -1 |
		cut -d= -f2)"
	printf '%s  seed=%s avenue_road_cells=%s\n' "$digest" "$seed" "$road_cells" \
		>"$output/avenue-digest.txt"
	# The expectation lives with the lane that last CHANGED the road, so a
	# package that moves it says so by moving this path and recording why.
	# Three of round 3's lanes moved it and this is the last of them: the
	# terrace lane gave every capital riser a band of one-block ground steps,
	# which moves the ground the avenue is laid on; the route lane made a run
	# ramp to route grade under a low bridge deck; and this lane ran the four
	# avenues out to 261 so the road rides through the curtain's gate tunnel,
	# and put the curtain's own vocabulary into the overlay's palette, so the
	# gatehouse masonry inside the avenue's dump region is digested with the
	# road it lets through.
	expected_file="$repo/tools/wp13/evidence/20260915-highcourt-fill/highcourt/avenue-digest-$seed.txt"
	if [[ -f "$expected_file" ]]; then
		expected="$(awk 'NR==1 {print $1}' "$expected_file")"
		if [[ "$digest" != "$expected" ]]; then
			printf 'WP13 Highcourt: the built avenue moved.\n  now      %s\n  expected %s (%s)\n' \
				"$digest" "$expected" "$expected_file" >&2
			exit 1
		fi
		echo "avenue road digest matches the committed value"
	else
		echo "avenue road digest recorded (no committed value for seed $seed yet)"
	fi
fi
echo "WP13 Highcourt pass PASS: $output"
