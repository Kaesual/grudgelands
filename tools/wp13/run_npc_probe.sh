#!/usr/bin/env bash
# The settlement-NPC engine pass of WP13 playtest rounds 1 and 2 (2026-09-15):
# THREE boots on ONE world through `tools/luanti_headless.sh`, with the
# disposable probe of `tools/wp13/npc_probe` staged into the throwaway game
# copy. Round 2 added four claims to the same three boots (spare sockets never
# spawn, villagers visit more than one spot, the elder faces the street, and a
# hostile engages the watch while no mob ever acquires a non-combatant); the
# programme and its timings are unchanged.
#
# WAVE 2 (2026-09-15) ADDED A SECOND MODE, `capital`: ONE boot that forceloads a
# capital by key, holds every socket's own mapblock and inventories what the
# placement engine put there (role, activity, vendor kind, walker share) plus,
# for every socket that carries nobody, the state of the map under it. It is the
# open item of `docs/research/wp13-highcourt-fill.md` section 9.4 -- pointed at
# Highcourt it answers whether the baker that round saw unplaced is a socket, a
# placement or a harness problem.
#
# PORT: pass one in the band your lane owns (`PORT=31141 run_npc_probe.sh ...`);
# the launcher's own default is 32800+RANDOM%200.
#
#   boot 1  fresh world, the full programme: the amble trace, the wandering-NPC
#           census over more than twenty heartbeats, the HP tuple and the
#           HP injection.
#   boot 2  the same world again -- the reload the roster has to survive.
#   boot 3  and once more, because the lost `hp_max` of the pre-fix code needed
#           TWO reload cycles to reach the nametag.
#
# Isolation is the launcher's (user rule, 2026-09-14): a fresh scratch directory
# as LUANTI_USER_PATH and as every XDG directory, the log inside it, a
# `timeout --kill-after`, only this run's own server killed and nothing under the
# personal Flatpak folder touched. The kept root is deleted here at the end,
# because a supplied ROOT is never deleted by the launcher itself.
#
# Usage: run_npc_probe.sh OUTPUT_DIR [SEED] [start|capital] [CAPITAL_KEY]
#   OUTPUT_DIR   absolute, must not exist; receives the logs and the extracted
#                probe lines.
#   MODE         `start` (default, the three-boot behavioural programme) or
#                `capital` (one boot, the inventory).
#   CAPITAL_KEY  the settlement key of the capital, default `highcourt`. Only
#                meaningful in capital mode.
#
# HOW THE MODE REACHES THE PROBE: `tools/luanti_headless.sh` passes no
# environment into the Flatpak, so the runner stages its OWN COPY of the probe
# directory under OUTPUT_DIR with a one-table `mode.lua` in it and points PROBE
# at that. The copy is what the harness digest below covers as well, so a run's
# record says which programme it was.
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: run_npc_probe.sh OUTPUT_DIR [SEED] [start|capital] [KEY]}"
seed="${2:-531802985935182545}"
mode="${3:-start}"
capital_key="${4:-highcourt}"
[[ "$output" = /* && ! -e "$output" ]] || {
	echo "run_npc_probe: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
[[ "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "run_npc_probe: SEED must be canonical unsigned decimal" >&2
	exit 2
}
[[ "$mode" == "start" || "$mode" == "capital" ]] || {
	echo "run_npc_probe: MODE must be start or capital" >&2
	exit 2
}
[[ "$capital_key" =~ ^[a-z0-9_]+$ ]] || {
	echo "run_npc_probe: CAPITAL_KEY must be a settlement key" >&2
	exit 2
}
mkdir -p "$output"

# The staged probe: the repository's own directory plus the mode file. Never
# written back into the repository -- `tools/wp13/npc_probe` stays the shipped
# bytes and this copy dies with the output directory.
probe="$output/npc_probe"
cp -a "$repo/tools/wp13/npc_probe" "$probe"
printf 'return {programme = "%s", key = "%s"}\n' "$mode" "$capital_key" \
	>"$probe/mode.lua"
export PROBE="$probe"
( cd "$repo" && find tools/wp13/npc_probe tools/wp13/run_npc_probe.sh \
	-type f -print0 | sort -z | xargs -0 sha256sum ) >"$output/harness.sha256"
sha256sum "$probe/mode.lua" >>"$output/harness.sha256"

root=""
cleanup() {
	[[ -n "$root" && -d "$root" ]] && rm -rf -- "$root"
}
trap cleanup EXIT

if [[ "$mode" == "capital" ]]; then
	#
	# ONE BOOT, and a longer one. The budget, written down rather than guessed:
	# the Highcourt engine pass of round 3 measured 94 capital mapchunks at a
	# 0.53 s steady mean plus a 23 s one-time emerge-environment warm-up, i.e.
	# about 75 s of emerge for the capital itself; the six starts' own preload
	# runs before that, the probe then waits up to 300 s for the socket blocks
	# and 45 s for the heartbeat. 1200 s is therefore roughly three times the
	# expected wall time and still well inside the 30-minute lane ceiling.
	#
	# KEEP=1 even though there is only one boot: without it the launcher's own
	# cleanup deletes the run directory -- and the log inside it -- before this
	# script can copy it out, so a failing run would report nothing but the
	# launcher's ten-line grep. The `cleanup` trap above deletes the kept root
	# once the log has been copied.
	KEEP=1 SEED="$seed" "$repo/tools/luanti_headless.sh" 1200 \
		>"$output/boot1.txt" 2>&1 || true
	root="$(awk '/^kept: /{print $2}' "$output/boot1.txt" | tail -1)"
	[[ -n "$root" && -d "$root" && -f "$root/server.log" ]] || {
		echo "run_npc_probe: the capital boot kept no run directory" >&2
		cat "$output/boot1.txt" >&2
		exit 1
	}
	cp "$root/server.log" "$output/server-boot1.log"
	expect_complete=1
else
	# Boot 1: fresh world, kept so the two reboots see the same map, the same
	# mod storage and the same static objects.
	KEEP=1 SEED="$seed" "$repo/tools/luanti_headless.sh" 900 \
		>"$output/boot1.txt" 2>&1 || true
	root="$(awk '/^kept: /{print $2}' "$output/boot1.txt" | tail -1)"
	[[ -n "$root" && -d "$root" ]] || {
		echo "run_npc_probe: boot 1 kept no run directory" >&2
		cat "$output/boot1.txt" >&2
		exit 1
	}

	for boot in 2 3; do
		ROOT="$root" SEED="$seed" "$repo/tools/luanti_headless.sh" 300 \
			>"$output/boot$boot.txt" 2>&1 || true
	done

	index=1
	for log in "$root/server.log" "$root/server.2.log" "$root/server.3.log"; do
		[[ -f "$log" ]] || { echo "run_npc_probe: missing $log" >&2; exit 1; }
		cp "$log" "$output/server-boot$index.log"
		index=$((index + 1))
	done
	expect_complete=3
fi

grep -h 'GRUG_WP13_NPC' "$output"/server-boot*.log >"$output/probe.txt" || true
grep -h 'start npcs' "$output"/server-boot*.log >"$output/npcs.txt" || true
grep -hc 'ERROR' "$output"/server-boot*.log >"$output/error-count.txt" || true
grep -h 'ERROR\|ModError' "$output"/server-boot*.log \
	>"$output/errors.txt" || true

errors="$(wc -l <"$output/errors.txt")"
complete="$(grep -c 'event=complete' "$output/probe.txt" || true)"
printf 'mode=%s errors=%s complete=%s probe=%s\n' "$mode" "$errors" \
	"$complete" "$output/probe.txt"
[[ "$errors" -eq 0 && "$complete" -eq "$expect_complete" ]] || {
	echo "WP13 NPC probe FAILED; inspect $output" >&2
	exit 1
}
echo "WP13 NPC probe PASS ($mode): $output"
