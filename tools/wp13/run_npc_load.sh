#!/usr/bin/env bash
# The settlement-NPC LOAD pass of WP13 playtest round 3 (2026-09-15): ONE boot
# through `tools/luanti_headless.sh` with the disposable probe of
# `tools/wp13/npc_load_probe` staged into the throwaway game copy.
#
# The probe walks the six starts one at a time -- forceload the arrival, let the
# engine settle, measure for thirty seconds, release -- and logs, per start: how
# many active mobs stand there, how many `core.find_path` calls a minute they
# make, the mean and worst server step of the window, and how the residents
# split into static workers, static idlers and walkers.
#
# WHY A SECOND RUNNER next to run_npc_probe.sh: that programme is a
# seven-minute correctness run whose own teleports, entity removals and wolf
# fight would fall inside any window measured through it, and
# `tools/luanti_headless.sh` passes no environment into the Flatpak, so a mode
# switch can only be a different staged probe directory.
#
# The before/after comparison the round asks for is this script run twice, once
# on the tree before the change and once after; the probe file is identical in
# both, which is why it landed in its own first commit.
#
# WAVE 3 (2026-09-16) ADDS AN OPTIONAL CAPITAL SUBJECT. With a third argument
# the probe measures that capital LAST, after the six starts and by the same
# clock, so its numbers read against the wave-1 start numbers of
# docs/research/wp13-npc-work.md section 7.1 directly. Without it the run is
# byte-for-byte the programme every earlier record was taken with.
#
# HOW THE KEY REACHES THE PROBE: `tools/luanti_headless.sh` passes no
# environment into the Flatpak, so the argument is a STAGED FILE. This script
# copies the probe directory into OUTPUT_DIR, writes a one-table `subject.lua`
# beside its `init.lua` and points PROBE at the copy -- the same mechanism
# `run_npc_probe.sh` uses for its `mode.lua`. The repository's own
# `tools/wp13/npc_load_probe` is never written and carries no `subject.lua`.
#
# PORT: pass one in the band your lane owns (`PORT=31410 run_npc_load.sh ...`);
# the launcher's own default is 32800+RANDOM%200.
#
# Isolation is the launcher's (user rule, 2026-09-14): a fresh scratch directory
# as LUANTI_USER_PATH and as every XDG directory, the log inside it, a
# `timeout --kill-after`, only this run's own server killed and nothing under the
# personal Flatpak folder touched.
#
# Usage: run_npc_load.sh OUTPUT_DIR [SEED] [CAPITAL_KEY]
#   OUTPUT_DIR   absolute, must not exist; receives the log and the probe lines.
#   CAPITAL_KEY  a settlement key ("highcourt", ...); omitted or empty means
#                the six starts only.
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: run_npc_load.sh OUTPUT_DIR [SEED] [CAPITAL_KEY]}"
seed="${2:-531802985935182545}"
capital_key="${3:-}"
[[ "$output" = /* && ! -e "$output" ]] || {
	echo "run_npc_load: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
[[ "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "run_npc_load: SEED must be canonical unsigned decimal" >&2
	exit 2
}
[[ -z "$capital_key" || "$capital_key" =~ ^[a-z][a-z0-9_]*$ ]] || {
	echo "run_npc_load: CAPITAL_KEY must be a settlement key" >&2
	exit 2
}
mkdir -p "$output"

# The staged probe: the repository's own directory plus, when a capital is
# named, the subject file. Never written back into the repository.
probe="$output/npc_load_probe"
cp -a "$repo/tools/wp13/npc_load_probe" "$probe"
if [[ -n "$capital_key" ]]; then
	printf 'return {capital = "%s"}\n' "$capital_key" >"$probe/subject.lua"
fi
export PROBE="$probe"
( cd "$repo" && find tools/wp13/npc_load_probe tools/wp13/run_npc_load.sh \
	-type f -print0 | sort -z | xargs -0 sha256sum ) >"$output/harness.sha256"
if [[ -f "$probe/subject.lua" ]]; then
	sha256sum "$probe/subject.lua" >>"$output/harness.sha256"
fi

root=""
cleanup() {
	[[ -n "$root" && -d "$root" ]] && rm -rf -- "$root"
}
trap cleanup EXIT

# 600 s: six windows of 8 s settle + 30 s measure is 228 s of programme, and the
# rest is the six starts' own preload before the first window opens.
#
# A CAPITAL SUBJECT COSTS ANOTHER 400 s of budget, written down rather than
# guessed: its own window is the same 38 s, and in front of it sit the block
# plan (a capital's sockets share about 130 mapblocks, fed to `forceload_block`
# 24 a second, so about 6 s of asking) and the placement wait, which the probe
# caps at 300 s and cuts short on a 60 s stall. 1000 s is therefore roughly
# twice the expected wall time and well inside the 30-minute lane ceiling.
budget=600
if [[ -n "$capital_key" ]]; then budget=1000; fi
KEEP=1 SEED="$seed" "$repo/tools/luanti_headless.sh" "$budget" \
	>"$output/boot.txt" 2>&1 || true
root="$(awk '/^kept: /{print $2}' "$output/boot.txt" | tail -1)"
[[ -n "$root" && -d "$root" ]] || {
	echo "run_npc_load: the boot kept no run directory" >&2
	cat "$output/boot.txt" >&2
	exit 1
}
cp "$root/server.log" "$output/server.log"

grep -h 'GRUG_WP13_LOAD' "$output/server.log" >"$output/load.txt" || true
grep -h 'ERROR\|ModError' "$output/server.log" >"$output/errors.txt" || true

errors="$(wc -l <"$output/errors.txt")"
complete="$(grep -c 'event=complete' "$output/load.txt" || true)"
windows="$(grep -c 'event=window ' "$output/load.txt" || true)"
want_windows=6
if [[ -n "$capital_key" ]]; then want_windows=7; fi
printf 'errors=%s complete=%s windows=%s/%s load=%s\n' "$errors" "$complete" \
	"$windows" "$want_windows" "$output/load.txt"
[[ "$errors" -eq 0 && "$complete" -eq 1 && "$windows" -eq "$want_windows" ]] || {
	echo "WP13 NPC load probe FAILED; inspect $output" >&2
	exit 1
}
echo "WP13 NPC load probe PASS: $output"
