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
# Usage: run_capital.sh OUTPUT_DIR KEY [terrain|field|surface|scan|edge|full] [SEED]
#   OUTPUT_DIR  absolute, must not exist; receives the log, the dumps and the
#               per-mapchunk timings.
#   KEY         the settlement key in `wp40/r7_settlement.lua`'s roster
#               ("dur_brannoc", "highcourt", ...). In `terrain`, `field` and
#               `edge` mode the roster need not carry it yet, and
#               WP13_CAPITAL_RACE names the race whose capital anchor is
#               measured.
#
# `field` and `edge` were added on 2026-09-15 by the Dur Brannoc upgrade lane,
# generalised from `tools/wp13/run_highcourt.sh` so that every capital lane has
# them without the pilot capital's runner:
#   field       the pure final height and the land/water class of every column
#               within +-250 of the capital anchor -- the 512 envelope less the
#               three outermost columns on each side, which is where the
#               curtain wall stands and where no lot may be -- dumped ONCE per
#               seed. It is what the offline lot predicate
#               `tools/wp13/capital_lots.lua` reads, and it replaces the
#               per-plot candidate sweep of `scan` for any capital with more
#               than one district. A lot placed beyond 250 would have no field
#               under it; the predicate refuses one at 236 already.
#   edge        emerges every capital anchor's ROOT chunk before its SUPPORT
#               chunk, which is the emerge order a player teleporting in from
#               above produces and the one the ordinary corpus can never see.
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
	"$mode" == "full" || "$mode" == "field" || "$mode" == "edge" ]] || {
	echo "run_capital: mode must be terrain, field, surface, scan, edge or full" >&2
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
# The WP13 lanes share one host with the user's own GUI client, and each lane's
# brief pins it a hundred-port block of its own inside 31000-31999. The runner
# holds the thousand and the brief holds the block: a runner that named one
# lane's block refused every other lane's (round 2 owned 31300-31399, round 3
# lane 3 owns 31200-31299).
port="${WP13_CAPITAL_PORT:-31300}"
[[ "$port" =~ ^31[0-9][0-9][0-9]$ ]] || {
	echo "run_capital: WP13_CAPITAL_PORT must be in 31000-31999" >&2
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

for dump in core plot district fill avenue approach rampart corner gate wall \
		surface scan grid field; do
	[[ -f "$world/$key-$dump.tsv" ]] && cp "$world/$key-$dump.tsv" "$output/"
done
grep 'GRUG_WP13_CAPITAL' "$log" >"$output/probe.txt" || true
grep 'start npcs' "$log" >"$output/npcs.txt" || true
grep -c 'ERROR' "$log" >"$output/error-count.txt" || echo 0 >"$output/error-count.txt"
grep -c 'ModError' "$log" >"$output/moderror-count.txt" || echo 0 >"$output/moderror-count.txt"

# EVERY ERROR LINE IS AN ERROR AGAIN. Between 2026-09-15 and the wave-2 NPC
# vocabulary landing, this gate subtracted the placement engine's "resolves to
# no registered entity (grug_traders:vendor_*)" line and reported it as
# `pending_vendor_kinds`: the capital lanes were placing the seven wave-2 vendor
# kinds before the lane that registers their entities had merged, and the
# sockets contract's section 8.4 calls that "an error line at placement and an
# empty socket, never a load failure". All seven kinds are registered now
# (`grug_traders/vendors.lua`), so the exemption has nothing left to excuse and
# would only ever swallow a genuinely mistyped kind in a future capital. It is
# gone; a vendor kind with no entity fails this gate again.
errors="$(grep -c 'ERROR\|ModError' "$log" || true)"
complete="$(grep -c 'GRUG_WP13_CAPITAL event=complete' "$log" || true)"
printf 'exit=%s errors=%s complete=%s log=%s\n' \
	"$status" "$errors" "$complete" "$log"
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
# AN OPEN CAPITAL PUBLISHES NO RAMPART AND NO GATE, and that is not a failure.
# The probe adds those two dump regions only when the composition authors a
# curtain wall (Highcourt, Dur Brannoc, Nhal Veyr and Gor Drazhak do; Lethariel
# and Kezamba do not), so on an open capital the two `grep -o` calls below match
# nothing. Under `set -euo pipefail` a command substitution whose pipeline ends
# in a failed `grep` takes the whole script down -- which is what Lanes E and T
# hit: a clean boot aborted here before ever printing PASS. Each lookup is
# therefore explicitly allowed to find nothing, and a label with no digest is
# skipped with a line saying so.
if [[ "$mode" == "full" ]]; then
	: >"$output/overlay-digests.txt"
	status_digest=0
	# `corner` is the region the wave-2 review asked for: the four places two
	# wall runs meet, which `wall.lua` section 1b reconciles and which NO OTHER
	# REGION CONTAINS -- the rampart region is the east curtain either side of
	# the anchor and the gate region is the gate, so a regression in the corner
	# seam used to leave every committed digest green. A walled capital publishes
	# it; an open one does not, and the loop below says so rather than failing.
	for label in avenue rampart corner gate; do
		digest="$( { grep -o "${label}_road_digest=[0-9a-f]*" "$log" || true; } |
			tail -1 | cut -d= -f2)"
		cells="$( { grep -o "${label}_road_cells=[0-9]*" "$log" || true; } |
			tail -1 | cut -d= -f2)"
		if [[ -z "$digest" ]]; then
			echo "$label: this capital publishes no such overlay region"
			continue
		fi
		printf '%s  %s seed=%s overlay_cells=%s\n' "$digest" "$label" "$seed" \
			"$cells" >>"$output/overlay-digests.txt"
		# WP13 round 3 moved the ground under both: the capital terrace risers
		# became bands of one-block ground steps, so the road and the rampart
		# that follow the surface moved with it.
		expected_file="$repo/tools/wp13/evidence/20260915-capital-terrain/$key/${label}-digest-$seed.txt"
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
