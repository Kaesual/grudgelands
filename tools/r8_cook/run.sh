#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
lua_bin="${R8_COOK_LUA_BIN:-luajit}"
R8_COOK_ROOT="$root" "$lua_bin" -e '
	local root = assert(os.getenv("R8_COOK_ROOT"))
	io.write(dofile(root .. "/tools/r8_cook/kat.lua")(root))
'
