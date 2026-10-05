#!/usr/bin/env bash
# Template (docs/process/round-workflow.md "Templates"): copy beside lua_run.sh
# into ~/projects/grudgelands-orchestration/r<NN>/.
#
# Measuring engine runs (before/after timings): at most TWO at once across all
# lanes, each also holding one Lua slot of lua_run.sh. Run from your worktree
# root with the same env vars and arguments as tools/luanti_headless.sh:
#   ~/projects/grudgelands-orchestration/r<NN>/engine_run.sh <label> [luanti_headless args...]
# Plain smoke boots use lua_run.sh <label> 1 ./tools/luanti_headless.sh instead.
set -uo pipefail
O="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
L=$O/locks
mkdir -p "$L"
label="${1:?label}"; shift
WT="$(pwd)"
[[ -x "$WT/tools/luanti_headless.sh" ]] || { echo "run from your worktree root" >&2; exit 2; }
while :; do
	for s in 1 2; do
		exec 9>"$L/measure$s"
		if flock -n 9; then
			echo "$(date +%T) measure$s $label start ($WT)" >>"$L/ledger.txt"
			"$O/lua_run.sh" "measure:$label" 1 "$WT/tools/luanti_headless.sh" "$@"
			rc=$?
			echo "$(date +%T) measure$s $label end rc=$rc" >>"$L/ledger.txt"
			exit $rc
		fi
		exec 9>&-
	done
	sleep 5
done
