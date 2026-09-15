#!/usr/bin/env bash
# The engine pass of ONE WP13 capital: a headless boot that emerges the
# capital's own mapchunks, times them, inventories its NPC sockets and dumps
# what it built as TSVs the renderer can draw.
#
# It is `tools/wp13/run_highcourt.sh` with the capital lifted out of it -- that
# script is the pilot capital's own gate and must not change -- plus the
# `terrain` mode, which measures the ground BEFORE a composition exists and is
# therefore the one mode that runs against a capital the roster does not carry
# yet.
#
# It is a separate runner from `tools/wp13/run_engine.sh` because that one is
# the six-start digest gate, and from the WP40 profiler because the profiler
# deletes its world on exit while this pass has to KEEP the world: the dumps are
# written into it by the probe (writing inside the world directory is what the
# engine's own security sandbox allows a mod to do).
#
# Isolation, the same guarantees `tools/luanti_headless.sh` gives (user rule,
# 2026-09-14): a fresh scratch directory as LUANTI_USER_PATH and as every XDG
# directory, the log inside it, a `timeout --kill-after`, only this run's own
# server killed, and nothing under the personal Flatpak folder touched.
#
# Usage: run_capital.sh OUTPUT_DIR KEY [terrain|surface|scan|full] [SEED]
#   OUTPUT_DIR  absolute, must not exist; receives the log, the dumps and the
#               per-mapchunk timings.
#   KEY         the settlement key in `wp40/r7_settlement.lua`'s roster
#               ("dur_brannoc", "highcourt", ...). In `terrain` mode the roster
#               need not carry it yet, and WP13_CAPITAL_RACE names the race
#               whose capital anchor is measured.
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: run_capital.sh OUTPUT_DIR KEY [terrain|surface|scan|full] [SEED]}"
key="${2:?usage: run_capital.sh OUTPUT_DIR KEY [terrain|surface|scan|full] [SEED]}"
mode="${3:-full}"
seed="${4:-531802985935182545}"
[[ "$output" = /* && ! -e "$output" ]] || {
	echo "run_capital: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
[[ "$key" =~ ^[a-z][a-z0-9_]*$ ]] || {
	echo "run_capital: KEY must be a roster key" >&2
	exit 2
}
[[ "$mode" == "terrain" || "$mode" == "surface" || "$mode" == "scan" ||
	"$mode" == "full" ]] || {
	echo "run_capital: mode must be terrain, surface, scan or full" >&2
	exit 2
}
[[ "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "run_capital: SEED must be canonical unsigned decimal" >&2
	exit 2
}
race="${WP13_CAPITAL_RACE:-}"
[[ -z "$race" || "$race" =~ ^[a-z]+$ ]] || exit 2
timeout_s="${WP13_CAPITAL_TIMEOUT:-1500}"
[[ "$timeout_s" =~ ^[1-9][0-9]*$ && "$timeout_s" -le 3600 ]] || {
	echo "run_capital: WP13_CAPITAL_TIMEOUT must be 1..3600" >&2
	exit 2
}
# The WP13 round-2 lanes share one host with the user's own GUI client; this
# lane's ports are 31300-31399 and nothing else.
port="${WP13_CAPITAL_PORT:-31300}"
[[ "$port" =~ ^313[0-9][0-9]$ ]] || {
	echo "run_capital: WP13_CAPITAL_PORT must be in 31300-31399" >&2
	exit 2
}

mkdir -p "$output"
root="$(mktemp -d /tmp/grudgelands-wp13-capital.XXXXXX)"
case "$root" in
	/tmp/grudgelands-wp13-capital.*) ;;
	*) echo "run_capital: scratch path differs" >&2; exit 2 ;;
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
cp -a "$repo/tools/wp13/capital_probe" "$game/mods/grug_wp13_capital_probe"
( cd "$repo" && find tools/wp13/capital_probe tools/wp13/run_capital.sh \
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
grug_wp13_probe_key = $key
grug_wp13_probe_mode = $mode
grug_wp13_probe_timeout = $((timeout_s - 120))
CONF
[[ -n "$race" ]] && printf 'grug_wp13_probe_race = %s\n' "$race" >>"$root/server.conf"

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
[[ -f "$log" ]] || { echo "run_capital: no server log" >&2; exit 1; }

for dump in core plot avenue rampart gate wall surface scan grid; do
	[[ -f "$world/$key-$dump.tsv" ]] && cp "$world/$key-$dump.tsv" "$output/"
done
grep 'GRUG_WP13_CAPITAL' "$log" >"$output/probe.txt" || true
grep 'start npcs' "$log" >"$output/npcs.txt" || true
grep -c 'ERROR' "$log" >"$output/error-count.txt" || echo 0 >"$output/error-count.txt"
grep -c 'ModError' "$log" >"$output/moderror-count.txt" || echo 0 >"$output/moderror-count.txt"

errors="$(grep -c 'ERROR\|ModError' "$log" || true)"
complete="$(grep -c 'GRUG_WP13_CAPITAL event=complete' "$log" || true)"
printf 'exit=%s errors=%s complete=%s log=%s\n' "$status" "$errors" "$complete" "$log"
[[ "$errors" -eq 0 && "$complete" -ge 1 ]] || {
	echo "WP13 capital pass FAILED; inspect $log" >&2
	exit 1
}

# THE ROAD'S AND THE WALL'S BUILT GEOMETRY, checked against a frozen value.
#
# Nothing else in the tree hashes them: an overlay's manifest identity is its
# SPECIFICATION (it has no cells until a surface arrives) and the six-start
# engine gate excludes capitals by construction, so a change to `avenue.run` or
# `wall.run` could move every node of every capital road and rampart in silence.
# The probe digests what it read back out of the finished map; this compares
# that digest with the one the evidence carries for this capital and seed.
#
# WP40 terrain changes move the ground the road and the wall follow and
# therefore these values: it is a "look at what moved" gate, not a
# frozen-forever constant, and the expectation file says which seed and which
# main commit it was taken on.
if [[ "$mode" == "full" ]]; then
	: >"$output/overlay-digests.txt"
	status_digest=0
	for label in avenue rampart gate; do
		digest="$(grep -o "${label}_road_digest=[0-9a-f]*" "$log" | tail -1 |
			cut -d= -f2)"
		cells="$(grep -o "${label}_road_cells=[0-9]*" "$log" | tail -1 |
			cut -d= -f2)"
		[[ -n "$digest" ]] || continue
		printf '%s  %s seed=%s overlay_cells=%s\n' "$digest" "$label" "$seed" \
			"$cells" >>"$output/overlay-digests.txt"
		expected_file="$repo/tools/wp13/evidence/20260915-dur-brannoc/$key/${label}-digest-$seed.txt"
		if [[ -f "$expected_file" ]]; then
			expected="$(awk 'NR==1 {print $1}' "$expected_file")"
			if [[ "$digest" != "$expected" ]]; then
				printf 'WP13 %s: the built %s moved.\n  now      %s\n  expected %s (%s)\n' \
					"$key" "$label" "$digest" "$expected" "$expected_file" >&2
				status_digest=1
			else
				echo "$label overlay digest matches the committed value"
			fi
		else
			echo "$label overlay digest recorded (no committed value for seed $seed yet)"
		fi
	done
	[[ "$status_digest" -eq 0 ]] || exit 1
fi
echo "WP13 capital pass PASS: $key $mode $output"
