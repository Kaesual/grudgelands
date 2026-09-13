#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
lua_bin=${WP40_LUA_BIN:-luajit}
mode=${1:-}
production_repo=${2:-$repo}
if test -n "$mode" && test "$mode" != expanded; then
	echo "usage: tools/wp40/resource_sampling/run.sh [expanded] [production_repo]" >&2
	exit 2
fi
if test "$mode" = expanded; then
	case "$lua_bin" in
		*luajit*) ;;
		*) echo "expanded mode requires LuaJIT" >&2; exit 2 ;;
	esac
fi
exec chrt --idle 0 ionice -c3 "$lua_bin" \
	"$repo/tools/wp40/resource_sampling/run.lua" "$repo" "$production_repo" ${mode:+"$mode"}
