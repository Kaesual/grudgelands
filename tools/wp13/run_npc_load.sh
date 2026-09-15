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
# PORT: pass one in the band your lane owns (`PORT=31410 run_npc_load.sh ...`);
# the launcher's own default is 32800+RANDOM%200.
#
# Isolation is the launcher's (user rule, 2026-09-14): a fresh scratch directory
# as LUANTI_USER_PATH and as every XDG directory, the log inside it, a
# `timeout --kill-after`, only this run's own server killed and nothing under the
# personal Flatpak folder touched.
#
# Usage: run_npc_load.sh OUTPUT_DIR [SEED]
#   OUTPUT_DIR  absolute, must not exist; receives the log and the probe lines.
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: run_npc_load.sh OUTPUT_DIR [SEED]}"
seed="${2:-531802985935182545}"
[[ "$output" = /* && ! -e "$output" ]] || {
	echo "run_npc_load: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
[[ "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "run_npc_load: SEED must be canonical unsigned decimal" >&2
	exit 2
}
mkdir -p "$output"

export PROBE="$repo/tools/wp13/npc_load_probe"
( cd "$repo" && find tools/wp13/npc_load_probe tools/wp13/run_npc_load.sh \
	-type f -print0 | sort -z | xargs -0 sha256sum ) >"$output/harness.sha256"

root=""
cleanup() {
	[[ -n "$root" && -d "$root" ]] && rm -rf -- "$root"
}
trap cleanup EXIT

# 600 s: six windows of 8 s settle + 30 s measure is 228 s of programme, and the
# rest is the six starts' own preload before the first window opens.
KEEP=1 SEED="$seed" "$repo/tools/luanti_headless.sh" 600 \
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
printf 'errors=%s complete=%s windows=%s load=%s\n' "$errors" "$complete" \
	"$windows" "$output/load.txt"
[[ "$errors" -eq 0 && "$complete" -eq 1 && "$windows" -eq 6 ]] || {
	echo "WP13 NPC load probe FAILED; inspect $output" >&2
	exit 1
}
echo "WP13 NPC load probe PASS: $output"
