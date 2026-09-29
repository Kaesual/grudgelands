#!/usr/bin/env bash
# Round 26 Lane R portable check (LuaJIT, no engine). See check.lua.
# Usage: tools/r26_registration/check.sh
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
list="$(mktemp)"
trap 'rm -f "$list"' EXIT
(cd "$repo" && find mods -name '*.lua' | sort) >"$list"
luajit "$here/check.lua" "$repo" "$list"
