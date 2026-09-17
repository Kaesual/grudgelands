#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
lua_bin="${R6_HOTFIX_LUA_BIN:-/usr/bin/luajit}"

H6_REPO="$repo" "$lua_bin" -e '
local repo = assert(os.getenv("H6_REPO"))
local kat = assert(loadfile(repo .. "/tools/r6_hotfix/kat.lua"))()
kat(repo)
'
