#!/usr/bin/env bash
# THE CONTROLLED EXPERIMENT behind §6a of docs/research/wp13-fishing.md.
#
# Observation: on a FRESH headless world the three Kezamba anglers stand
# empty-handed for as long as you watch them, while the same world REBOOTED
# gives all three the rod. The first write-up of this lane blamed a failed
# `add_entity` inside `sync_wield` plus the one-shot `grug_work_dressed` flag.
# The independent review (2026-09-16) said the cause is one gate earlier --
# `watched(self, pos)` in `start_villagers.lua`, which asks
# `grug_mobs.nearest_player_d2` and gets nil when nobody is connected, which is
# every headless boot.
#
# Two boots, each on its OWN fresh world, differing in exactly one thing: the
# second stages an `unwatch.lua` next to the probe that replaces
# `grug_mobs.nearest_player_d2` with a function answering 0. Nothing else moves
# -- same probe, same seed, same game tree, no shipped file patched. If the
# review is right, boot B dresses the anglers and boot A does not.
#
# Usage, from the repository root:
#   PORT=31210 tools/wp13/evidence/20260916-fishing/watch_gate.sh OUTPUT_DIR
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
out="${1:?usage: watch_gate.sh OUTPUT_DIR}"
[[ "$out" = /* && ! -e "$out" ]] || {
	echo "watch_gate: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
mkdir -p "$out"
seed=531802985935182545
port="${PORT:-31210}"
budget="${BUDGET:-300}"

probe_a="$out/probe-watched"
probe_b="$out/probe-unwatched"
cp -a tools/wp13/evidence/20260916-fishing/probe "$probe_a"
cp -a tools/wp13/evidence/20260916-fishing/probe "$probe_b"

# THE ONE DIFFERENCE. Written here rather than shipped in the probe directory so
# that the evidence directory cannot accidentally carry an override into a
# normal run.
cat >"$probe_b/unwatch.lua" <<'LUA'
-- The whole of the experiment: make `watched()` true by making the nearest
-- player zero nodes away. `start_villagers.lua`'s `watched` reads
-- `grug_mobs.nearest_player_d2` off the global table on every call, so this
-- replacement takes effect without a single shipped byte changing.
grug_mobs.nearest_player_d2 = function()
	return 0
end
LUA

run() {
	local label="$1" probe="$2"
	local root
	KEEP=1 SEED="$seed" PORT="$port" PROBE="$probe" \
		nice -n 19 "$repo/tools/luanti_headless.sh" "$budget" \
		>"$out/$label.txt" 2>&1 || true
	root="$(awk '/^kept: /{print $2}' "$out/$label.txt" | tail -1)"
	if [[ -z "$root" || ! -f "$root/server.log" ]]; then
		echo "$label: no run directory kept" >&2
		cat "$out/$label.txt" >&2
		return 1
	fi
	cp "$root/server.log" "$out/$label.log"
	rm -rf -- "$root"
	echo "== $label"
	# The LAST reading per socket, not every ten-second sample: the full
	# sequence is in the .log next to this summary.
	grep -h 'fishprobe\] watch_override' "$out/$label.log"
	grep -h 'fishprobe\] angler kezamba' "$out/$label.log" |
		sed 's/.*\[fishprobe\] //' |
		awk '{ last[$3] = $0 } END { for (k in last) print last[k] }' |
		sort || echo "(no angler line at all)"
	grep -h 'fishprobe\] wait' "$out/$label.log" | tail -1
	grep -c 'ERROR\|ModError' "$out/$label.log" |
		sed 's/^/ERROR+ModError lines: /'
}

run A-watched "$probe_a"
run B-unwatched "$probe_b"
