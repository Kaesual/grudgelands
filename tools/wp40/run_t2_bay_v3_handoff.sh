#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
scratch=$(mktemp -d /tmp/grudgelands-wp40-bay-v3.XXXXXX)
cleanup() {
	case "$scratch" in
		/tmp/grudgelands-wp40-bay-v3.*) rm -rf -- "$scratch" ;;
	esac
}
trap cleanup EXIT HUP INT TERM

capture=${WP40_HANDOFF_CAPTURE_PATH:-}
lua_bin=${WP40_LUA_BIN:-/usr/bin/luajit}
if test -n "$capture"; then
	"$lua_bin" "$repo/tools/wp40/t2_bay_v3_handoff_test.lua" \
		"$repo" "$scratch" full "$capture"
else
	"$lua_bin" "$repo/tools/wp40/t2_bay_v3_handoff_test.lua" \
		"$repo" "$scratch" full
fi

"$repo/tools/bin/lua51" "$repo/tools/wp40/t2_bay_v3_handoff_test.lua" \
	"$repo" "$scratch" fixture

echo "WP40 T2 Bay-v3 handoff runner passed"
