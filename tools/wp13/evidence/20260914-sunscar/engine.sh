#!/usr/bin/env bash
# One WP13 engine round for the Sunscar increment: two fresh worlds with
# opposite owner orders, each followed by a disk-only reload, on one seed.
#
# The runner's output directory must live OUTSIDE the repository, because the
# launcher mounts the repository read-only into the Flatpak sandbox; the
# result is copied into the evidence directory afterwards. The PID set of
# every luanti process is taken before and after, so a server left behind is
# visible instead of merely unlikely.
#
# Usage: engine.sh SEED PORT_BASE ABSENT_OUTPUT_DIR
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
seed="${1:?usage: engine.sh SEED PORT_BASE OUTPUT}"
port="${2:?usage: engine.sh SEED PORT_BASE OUTPUT}"
output="${3:?usage: engine.sh SEED PORT_BASE OUTPUT}"

before="$(pgrep -f luanti | sort | tr '\n' ' ')"
echo "luanti pids before: [$before]"

WP13_SEED="$seed" WP13_PORT_BASE="$port" WP40_PROFILE_TIMEOUT=540 \
	timeout --kill-after=30 600 \
	bash tools/wp13/run_engine.sh "$output" \
	tools/wp13/evidence/20260914-sunscar/luanti-flatpak-launcher.sh
status=$?
echo "ENGINE_EXIT=$status"

after="$(pgrep -f luanti | sort | tr '\n' ' ')"
echo "luanti pids after:  [$after]"
# The invariant is one-sided: this run must leave NOTHING behind. Three other
# lanes share the workstation, so a pid that was running before and is gone
# now is somebody else's run finishing, which is not this round's business.
stray=""
for pid in $after; do
	case " $before " in
		*" $pid "*) ;;
		*) stray="$stray $pid" ;;
	esac
done
if [ -z "$stray" ]; then
	echo "NO STRAY SERVER (no luanti pid survives this run that did not precede it)"
else
	echo "STRAY LUANTI PROCESS:$stray"
fi
exit "$status"
