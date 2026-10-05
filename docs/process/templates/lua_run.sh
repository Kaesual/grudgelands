#!/usr/bin/env bash
# Template (docs/process/round-workflow.md "Templates"): copy into the round's
# private folder, ~/projects/grudgelands-orchestration/r<NN>/; the locks live
# beside the copy.
#
# Lua-process budget: at most 8 Lua processes workstation-wide (AGENTS.md).
# Every Lua run longer than about 30 s and every engine boot goes through here:
#   ~/projects/grudgelands-orchestration/r<NN>/lua_run.sh <label> <slots> <command> [args...]
# <slots> = how many Lua processes the command starts (run_fixtures.sh: its JOBS,
# default 4; seed_fleet: its JOBS; one headless boot: 1). Requesters queue in
# order (one gathers slots at a time, keeping the ones it has), so a large
# request is not starved. The command runs under idle scheduling.
set -uo pipefail
L="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/locks"
mkdir -p "$L"
label="${1:?label}"; slots="${2:?slots}"; shift 2
[[ $# -gt 0 ]] || { echo "usage: lua_run.sh <label> <slots> <command> [args...]" >&2; exit 2; }
[[ "$slots" =~ ^[1-8]$ ]] || { echo "slots must be 1..8" >&2; exit 2; }
exec 8>"$L/queue"
flock 8
held=()
while [[ ${#held[@]} -lt $slots ]]; do
	for s in 1 2 3 4 5 6 7 8; do
		[[ ${#held[@]} -ge $slots ]] && break
		[[ " ${held[*]} " == *" $s "* ]] && continue
		exec {fd}>"$L/lua$s"
		if flock -n "$fd"; then held+=("$s"); else exec {fd}>&-; fi
	done
	[[ ${#held[@]} -lt $slots ]] && sleep 3
done
flock -u 8; exec 8>&-
echo "$(date +%T) lua[${held[*]}] $label start: $*" >>"$L/ledger.txt"
LC_ALL=C chrt --idle 0 ionice -c3 "$@"
rc=$?
echo "$(date +%T) lua[${held[*]}] $label end rc=$rc" >>"$L/ledger.txt"
exit $rc
