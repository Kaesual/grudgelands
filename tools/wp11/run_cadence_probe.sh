#!/usr/bin/env bash
# The runtime test combat_stats.md §4 demands for the cadence patch
# ("because it changes every mob's feel, the WP that ships it owes a runtime
# test"), taken BEFORE and AFTER on the same engine, the same seed and the
# same built arena.
#
#   before  the vendored mods/ENTITIES/mobs/api.lua WITHOUT the cadence patch
#   after   the file as it stands in the tree
#
# Both numbers come out of tools/wp11/cadence_probe, which builds a flat
# platform in forceloaded blocks, puts one melee mob and one disposable target
# entity on it and counts landed punches per 10 s -- once with the target
# receding at the engine's own walk speed 4.0, once with it standing still as
# the control the decided text says may not move.
#
# HOW THE "BEFORE" BOOT IS TAKEN, WITHOUT TOUCHING THE REPO:
# tools/luanti_headless.sh stages the game from the directory ABOVE its own,
# so this script builds two throwaway MIRRORS of the game under /tmp -- each a
# `game.conf`, a `mods/` copy and a copy of the launcher -- and swaps only
# `mods/ENTITIES/mobs/api.lua` in the "before" mirror. The repository is read
# and never written, and both boots run the same launcher with the same
# isolation guarantees.
#
# Isolation is the launcher's (user rule, 2026-09-14): a fresh scratch
# directory as LUANTI_USER_PATH and as every XDG directory, the log inside it,
# a `timeout --kill-after`, only this run's own server killed, nothing under
# the personal Flatpak folder touched.
#
# Usage: run_cadence_probe.sh OUTPUT_DIR BEFORE_API [SEED]
#   OUTPUT_DIR  absent absolute path; receives both mirrors' logs
#   BEFORE_API  path to the pre-patch mods/ENTITIES/mobs/api.lua
#               (`git show <base>:mods/ENTITIES/mobs/api.lua > /tmp/...`)
#   SEED        default 15912857179583385436 (the user's world seed)
#   PORT        must be set, to a port in this lane's block
#   TIMEOUT     seconds per boot, default 240
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: run_cadence_probe.sh OUTPUT_DIR BEFORE_API [SEED]}"
before_api="${2:?usage: run_cadence_probe.sh OUTPUT_DIR BEFORE_API [SEED]}"
seed="${3:-15912857179583385436}"
port="${PORT:?PORT must be set to a port in the lane port block}"
timeout_s="${TIMEOUT:-240}"

[[ "$output" = /* && ! -e "$output" ]] || {
	echo "run_cadence_probe: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
[[ -f "$before_api" ]] || {
	echo "run_cadence_probe: BEFORE_API is not a file: $before_api" >&2
	exit 2
}
mkdir -p "$output"

mirror_root="$(mktemp -d /tmp/grug-w4-M-mirror.XXXXXX)"
cleanup() { rm -rf "$mirror_root"; }
trap cleanup EXIT

build_mirror() {
	local name="$1"
	local dir="$mirror_root/$name"
	mkdir -p "$dir/tools"
	cp -a "$repo/game.conf" "$dir/"
	cp -a "$repo/mods" "$dir/"
	for f in minetest.conf settingtypes.txt menu textures; do
		if [[ -e "$repo/$f" ]]; then cp -a "$repo/$f" "$dir/"; fi
	done
	cp -a "$repo/tools/luanti_headless.sh" "$dir/tools/"
	echo "$dir"
}

boot() {
	local label="$1" mirror="$2" run_out="$3"
	mkdir -p "$run_out"
	echo "== boot $label (port $port, seed $seed)"
	echo "   api.lua sha256 $(sha256sum "$mirror/mods/ENTITIES/mobs/api.lua" | cut -d' ' -f1)"
	local start
	start="$(date +%s)"
	PORT="$port" SEED="$seed" KEEP=1 \
		PROBE="$repo/tools/wp11/cadence_probe" \
		"$mirror/tools/luanti_headless.sh" "$timeout_s" \
		>"$run_out/boot.log" 2>&1 ||
		echo "   (launcher exit $? -- the probe shuts the server down itself)"
	echo "   wall $(( $(date +%s) - start )) s"
	local kept
	kept="$(grep -o 'kept: .*' "$run_out/boot.log" | tail -1 | cut -d' ' -f2)"
	if [[ -n "$kept" && -d "$kept" ]]; then
		cp -a "$kept"/server*.log "$run_out/" 2>/dev/null || true
		rm -rf "$kept"
	fi
	grep -h "\[probe\]" "$run_out"/server.log 2>/dev/null |
		sed 's/.*\[probe\] //' >"$run_out/probe.txt" || true
	grep -h 'ERROR\|ModError' "$run_out"/server*.log 2>/dev/null |
		head -20 >"$run_out/errors.txt" || true
	echo "-- $label --"
	cat "$run_out/probe.txt"
}

after_mirror="$(build_mirror after)"
before_mirror="$(build_mirror before)"
cp -a "$before_api" "$before_mirror/mods/ENTITIES/mobs/api.lua"

boot before "$before_mirror" "$output/before"
boot after "$after_mirror" "$output/after"

echo
echo "== punches per 10 s =="
for phase in before after; do
	while read -r line; do
		printf '%-7s %s\n' "$phase" "$line"
	done < <(grep '^cadence scenario=' "$output/$phase/probe.txt" 2>/dev/null || true)
done
echo
pgrep -af 'luanti.bin --server' || echo "no luanti server process left"
