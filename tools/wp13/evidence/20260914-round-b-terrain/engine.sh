#!/usr/bin/env bash
# The ONE combined engine gate for all six WP13 starts, run against the frozen
# bytes of the round-B terrain round. Two seeds, one after the other, each a
# full `run_engine.sh` pass: forward and reverse owner order, each with its own
# cold world and its own disk-only reload, four digests that must all agree.
#
# Round B changes the WP40 terrain layer only (the gate-axis road approach, the
# blend-ring vegetation and the soft pad edge), so the per-start blueprint
# digests must come out exactly as round A recorded them while the terrain
# around the starts moves.
#
# Isolation: the launcher refuses to start without an absolute scratch
# `LUANTI_USER_PATH` and pins every XDG directory inside it, so no headless
# server can touch the personal Flatpak folder the user's GUI client uses;
# output goes to /tmp because the launcher mounts the repository read-only; each
# seed is bounded by `timeout --kill-after`; and after each seed the process
# table is checked for a server still naming THIS run's output path. Never
# compare the whole `luanti.bin` PID set -- that would also catch the user's own
# client and another lane's servers.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260914-round-b-terrain"
launcher="$here/luanti-flatpak-launcher.sh"

run_seed() {
	local label="$1" seed="$2" port="$3"
	local out="/tmp/grug-wp13-round-b-$label"
	rm -rf -- "$out"
	echo "== $label: seed $seed, ports $port =="
	WP13_SEED="$seed" WP13_PORT_BASE="$port" WP40_PROFILE_TIMEOUT=600 \
		timeout --kill-after=30 900 bash tools/wp13/run_engine.sh \
		"$out" "$launcher"
	local stragglers
	stragglers="$(pgrep -af 'luanti.bin --server' | grep -F -- "$out" || true)"
	[[ -z "$stragglers" ]] || {
		printf 'a headless server was left behind:\n%s\n' "$stragglers" >&2
		exit 4
	}
	echo "no $label server remains"
	rm -rf -- "$repo/$here/$label"
	mkdir -p "$repo/$here/$label"
	cp -a "$out/." "$repo/$here/$label/"
	rm -rf -- "$out"
}

run_seed user-seed 531802985935182545 32900
run_seed boundary-seed 8675309 32940
echo "WP13 six-start engine gate: both seeds PASS"
