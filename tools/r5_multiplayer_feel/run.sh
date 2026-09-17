#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
lua_bin="${R5_LUA_BIN:-/usr/bin/luajit}"
"$lua_bin" "$repo/tools/r5_multiplayer_feel/kat.lua" "$repo"
