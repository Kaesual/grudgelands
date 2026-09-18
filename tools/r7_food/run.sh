#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
lua_bin="${R7_FOOD_LUA_BIN:-luajit}"
R7_ROOT="$root" "$lua_bin" -e \
	'local root = os.getenv("R7_ROOT")
	io.write(dofile(root .. "/tools/r7_food/kat.lua")(root))
	io.write(dofile(root .. "/tools/r6_food_buffs/kat.lua")(root))'
