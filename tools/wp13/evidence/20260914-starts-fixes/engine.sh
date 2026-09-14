#!/usr/bin/env bash
# The ONE combined engine gate for all six WP13 starts, run once against the
# frozen bytes of the 2026-09-14 fix round. Two seeds, one after the other,
# each a full `run_engine.sh` pass: forward and reverse owner order, each with
# its own cold world and its own disk-only reload, four digests that must all
# agree.
#
# `tools/wp13/engine_cases.lua` reads the R7 settlement roster, so all six
# starts are emerged, compared cell by cell and digested by one run; there is
# no per-start engine script and there must not be one.
#
# The seeds are the two the lanes used: the user's own world seed, and the
# boundary seed that puts Stillgrave's fitted surface just above an owner's
# ceiling so filler restoration across an owner floor is exercised.
#
# Isolation, in order of how badly each would hurt: the launcher refuses to
# start without an absolute scratch `LUANTI_USER_PATH` and pins every XDG
# directory inside it, so no headless server can touch the personal Flatpak
# folder the user's GUI client uses; output goes to /tmp because the launcher
# mounts the repository read-only; each seed is bounded by `timeout
# --kill-after`; and after each seed the process table is checked for a server
# still naming this run's output path.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260914-starts-fixes"
launcher="$here/luanti-flatpak-launcher.sh"

run_seed() {
	local label="$1" seed="$2" port="$3"
	local out="/tmp/grug-wp13-starts-fixes-$label"
	rm -rf -- "$out"
	echo "== $label: seed $seed, ports $port =="
	WP13_SEED="$seed" WP13_PORT_BASE="$port" WP40_PROFILE_TIMEOUT=600 \
		timeout --kill-after=30 900 bash tools/wp13/run_engine.sh \
		"$out" "$launcher"
	# Leftover check, scoped by output path: every headless server this run
	# starts names its own run directory on its command line, so a server of
	# ours is exactly one whose command line contains "$out". Comparing the
	# whole `luanti.bin` PID set would also catch the user's GUI client.
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

run_seed user-seed 531802985935182545 32800
run_seed boundary-seed 8675309 32840
echo "WP13 six-start engine gate: both seeds PASS"
