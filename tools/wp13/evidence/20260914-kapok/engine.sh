#!/usr/bin/env bash
# The two WP13 engine runs for the Kapok Cradle increment, one seed after the
# other, each bounded and each preceded by a wait until the workstation is
# below four headless servers: four settlement lanes share this machine and
# the user's own GUI client runs beside them.
#
# Output goes to /tmp, outside the repository, because the launcher mounts the
# repository read-only; it is copied into the evidence directory afterwards.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
launcher="tools/wp13/evidence/20260914-kapok/luanti-flatpak-launcher.sh"

wait_for_slot() {
	local waited=0
	while [[ "$(pgrep -c -f '^luanti.bin --server' || true)" -ge 4 ]]; do
		sleep 10
		waited=$((waited + 10))
		[[ "$waited" -lt 1800 ]] || { echo "workstation stayed busy" >&2; exit 3; }
	done
}

run_seed() {
	local label="$1" seed="$2" port="$3" out="/tmp/grug-wp13-kapok-$1"
	rm -rf -- "$out"
	wait_for_slot
	WP13_SEED="$seed" WP13_PORT_BASE="$port" WP40_PROFILE_TIMEOUT=540 \
		timeout --kill-after=30 600 bash tools/wp13/run_engine.sh \
		"$out" "$launcher"
	# Leftover check, scoped to THIS lane. Comparing the whole `luanti.bin`
	# PID set before and after is unsound while four settlement lanes share
	# the workstation: a sibling lane starting a server during this run reads
	# as a leak of ours. Every headless server writes its log under its own
	# run directory, so the lane's own servers are exactly the ones whose
	# command line names this run's output path.
	local stragglers
	stragglers="$(pgrep -af 'luanti.bin --server' | grep -F -- "$out" || true)"
	[[ -z "$stragglers" ]] || {
		printf 'a headless server was left behind:\n%s\n' "$stragglers" >&2
		exit 4
	}
	echo "no $label server remains"
}

run_seed user-seed 531802985935182545 32700
run_seed boundary-seed 8675309 32740
echo "WP13 kapok engine: both seeds PASS"
