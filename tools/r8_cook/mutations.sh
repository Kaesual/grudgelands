#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
lua_bin="${R8_COOK_LUA_BIN:-luajit}"

for mutation in 1 2 3 4 5 6; do
	if R8_COOK_ROOT="$root" R8_COOK_MUTATION="$mutation" "$lua_bin" -e '
		local root = assert(os.getenv("R8_COOK_ROOT"))
		io.write(dofile(root .. "/tools/r8_cook/kat.lua")(root))
	' >/dev/null 2>&1; then
		echo "mutation $mutation unexpectedly passed" >&2
		exit 1
	fi
	echo "mutation $mutation refused"
done
