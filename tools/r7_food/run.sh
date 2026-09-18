#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
lua_bin="${R7_FOOD_LUA_BIN:-luajit}"
R7_ROOT="$root" "$lua_bin" -e \
	'io.write(dofile(os.getenv("R7_ROOT") .. "/tools/r7_food/kat.lua")(os.getenv("R7_ROOT")))'
