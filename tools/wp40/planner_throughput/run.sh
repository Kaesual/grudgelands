#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
planner_repo="${1:-$repo}"
interpreter="${WP40_LUA_BIN:-luajit}"
exec chrt --idle 0 ionice -c3 "$interpreter" -e \
	'for _, name in ipairs({"fixture.lua", "r5_fixture.lua"}) do
		io.write(dofile(arg[1] .. "/tools/wp40/planner_throughput/" .. name)(arg[1], arg[2]))
	end' "$repo/tools/wp40/planner_throughput/fixture.lua" "$repo" "$planner_repo"
