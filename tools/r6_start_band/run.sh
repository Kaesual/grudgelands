#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
lua_bin="${R6_START_BAND_LUA_BIN:-/usr/bin/luajit}"

R6_START_BAND_KAT="$script_dir/kat.lua" R6_START_BAND_REPO="$repo" \
	"$lua_bin" -e 'io.write(dofile(assert(os.getenv("R6_START_BAND_KAT")))(assert(os.getenv("R6_START_BAND_REPO"))))'
