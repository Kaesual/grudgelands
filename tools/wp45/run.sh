#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
lua_bin="${WP45_LUA_BIN:-luajit}"

"$lua_bin" "$script_dir/character_creation_test.lua" "$repo"
