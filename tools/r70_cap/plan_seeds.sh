#!/usr/bin/env bash
# The real planner on the first fleet seeds, per capital (the study's
# comparison, tools/r70_design/export.lua `today` on the current tree), then
# tools/r70_cap/plan_summary.py. COUNT=<seeds>, default 6: a lane's check; the
# study's 40 run once on main after the batch. Through the queue, four at a time:
#   ~/projects/grudgelands-orchestration/r45/lua_run.sh <label> 4 tools/r70_cap/plan_seeds.sh OUT_DIR
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo"
out="${1:?usage: plan_seeds.sh OUT_DIR}"
mkdir -p "$out"
grep -v '^#' tools/seed_fleet/seeds.txt | grep . | head -n "${COUNT:-6}" | xargs -P 4 -I{} sh -c \
	'luajit tools/r70_design/export.lua planner "$1/{}.json" {} today >"$1/{}.log" 2>&1 || echo "FAIL {}"' _ "$out"
python3 tools/r70_cap/plan_summary.py "$out"
