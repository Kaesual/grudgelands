#!/usr/bin/env bash
# Round 49 lane V7: one measuring boot of a v7 flag variant on a fresh world
# (seed 12345): the mgprof stage profile of the mgprof corpus plus the extra
# columns of columns.lua, with the R5 voxel tally (tally.patch) and, for a
# variant, the flag patch (flags-<variant>.patch: the staged minetest.conf and
# the live flag check in r7_runtime.lua). Everything is patched into the
# staged throwaway game copy only (tools/mgprof/run.sh, GAME_PATCH).
#
# Usage: tools/r49_v7/run.sh baseline|nomountains|noridges OUT
# `baseline` stages no flag patch: the game's own flags, `mountains, ridges`
# when V7 measured and `nomountains, ridges` since lane V7A adopted it. The
# flag patches were made against the V7 tree and no longer apply after that.
# Runs through the shared measuring queue (MGPROF_QUEUE, default
# ~/projects/grudgelands-orchestration/r45/engine_run.sh); CLEAN=0 keeps the
# run directory.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
variant="${1:?usage: run.sh baseline|nomountains|noridges OUT}"
out="${2:?usage: run.sh baseline|nomountains|noridges OUT}"
patches="$here/tally.patch"
case "$variant" in
	baseline) ;;
	nomountains|noridges) patches="$patches $here/flags-$variant.patch" ;;
	*) echo "unknown variant $variant" >&2; exit 2 ;;
esac
cd "$repo"
EXTRA_PATCHES="$patches" PROBE_EXTRA="$here/columns.lua" \
	MGPROF_QUEUE="${MGPROF_QUEUE:-$HOME/projects/grudgelands-orchestration/r45/engine_run.sh}" \
	CLEAN="${CLEAN:-1}" "$repo/tools/mgprof/run.sh" stages "$out"
