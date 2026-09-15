#!/usr/bin/env bash
# The settlement-NPC engine pass of WP13 playtest round 1 (2026-09-15): THREE
# boots on ONE world through `tools/luanti_headless.sh`, with the disposable
# probe of `tools/wp13/npc_probe` staged into the throwaway game copy.
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
# Usage: run_npc_probe.sh OUTPUT_DIR [SEED]
#   OUTPUT_DIR  absolute, must not exist; receives the three logs and the
#               extracted probe lines.
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: run_npc_probe.sh OUTPUT_DIR [SEED]}"
seed="${2:-531802985935182545}"
[[ "$output" = /* && ! -e "$output" ]] || {
	echo "run_npc_probe: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
[[ "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "run_npc_probe: SEED must be canonical unsigned decimal" >&2
	exit 2
}
mkdir -p "$output"

export PROBE="$repo/tools/wp13/npc_probe"
( cd "$repo" && find tools/wp13/npc_probe tools/wp13/run_npc_probe.sh \
	-type f -print0 | sort -z | xargs -0 sha256sum ) >"$output/harness.sha256"

root=""
cleanup() {
	[[ -n "$root" && -d "$root" ]] && rm -rf -- "$root"
}
trap cleanup EXIT

# Boot 1: fresh world, kept so the two reboots see the same map, the same mod
# storage and the same static objects.
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

grep -h 'GRUG_WP13_NPC' "$output"/server-boot*.log >"$output/probe.txt" || true
grep -h 'start npcs' "$output"/server-boot*.log >"$output/npcs.txt" || true
grep -hc 'ERROR' "$output"/server-boot*.log >"$output/error-count.txt" || true
grep -h 'ERROR\|ModError' "$output"/server-boot*.log \
	>"$output/errors.txt" || true

errors="$(wc -l <"$output/errors.txt")"
complete="$(grep -c 'event=complete' "$output/probe.txt" || true)"
printf 'errors=%s complete=%s probe=%s\n' "$errors" "$complete" \
	"$output/probe.txt"
[[ "$errors" -eq 0 && "$complete" -eq 3 ]] || {
	echo "WP13 NPC probe FAILED; inspect $output" >&2
	exit 1
}
echo "WP13 NPC probe PASS: $output"
