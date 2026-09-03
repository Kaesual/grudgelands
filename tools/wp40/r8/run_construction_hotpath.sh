#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
lua_bin="${WP40_LUA_BIN:-luajit}"
mode="${1:-}"

if [[ "$mode" != "full" && "$mode" != "authority" ]]; then
	echo "usage: $0 full|authority" >&2
	exit 2
fi
if ! command -v "$lua_bin" >/dev/null 2>&1; then
	echo "WP40 Lua interpreter is unavailable: $lua_bin" >&2
	exit 2
fi

exec chrt --idle 0 ionice -c3 /usr/bin/time -q \
	-f $'resource\telapsed_seconds\t%e\tmax_rss_kib\t%M' \
	"$lua_bin" "$repo/tools/wp40/r8/construction_hotpath.lua" "$repo" "$mode"
