#!/bin/sh
set -eu
repo=${1:-.}
lua_bin=${R18_UX_LUA_BIN:-luajit}
exec "$lua_bin" "$repo/tools/r18_ux/fixture.lua" "$repo"
