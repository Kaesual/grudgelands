#!/usr/bin/env bash
# Builds the PUC Lua 5.1.5 interpreter that Luanti itself falls back to when
# no LuaJIT is present, straight from the engine checkout we already vendor
# (reference_projects/luanti/lib/lua/src). No apt package, no network, no
# sudo — only a C compiler.
#
# Why not LuaJIT: LuaJIT is a *superset* and silently accepts syntax the
# fallback build rejects (`goto`), so it cannot verify our hard plain-5.1
# requirement. This binary is exactly that fallback build's parser.
# See docs/research/luanti-lua.md, "Verifying a change".
#
# Usage: tools/build_lua51.sh        # writes tools/bin/{lua51,luac51}
# Re-run after updating the luanti checkout; otherwise once per machine.
set -euo pipefail

# Repo root from THIS FILE's path, never hardcoded (WP36 lesson).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/reference_projects/luanti/lib/lua/src"
OUT="$ROOT/tools/bin"

if [ ! -f "$SRC/lua.h" ]; then
	echo "error: $SRC missing — is the luanti checkout there?" >&2
	echo "       (git submodule update --init reference_projects/luanti)" >&2
	exit 1
fi
if ! command -v cc >/dev/null && ! command -v gcc >/dev/null; then
	echo "error: no C compiler. Debian/Ubuntu: sudo apt install build-essential" >&2
	exit 1
fi
CC="${CC:-$(command -v cc || command -v gcc)}"

mkdir -p "$OUT"
# lua.c and luac.c each carry a main(), so build them into separate binaries.
# print.c belongs to luac only. LUA_USE_POSIX = the standard Linux config.
LIB="$(ls "$SRC"/*.c | grep -vE '/(lua|luac|print)\.c$')"
$CC -O2 -DLUA_USE_POSIX -o "$OUT/lua51"  $LIB "$SRC/lua.c"  -lm
$CC -O2 -DLUA_USE_POSIX -o "$OUT/luac51" $LIB "$SRC/luac.c" "$SRC/print.c" -lm

# Self-test: the whole point is that this parser is STRICTER than LuaJIT.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf 'do goto x ::x:: end\n' > "$tmp/goto.lua"
if "$OUT/luac51" -p "$tmp/goto.lua" 2>/dev/null; then
	echo "error: self-test failed — this binary accepts goto, it is not plain 5.1" >&2
	exit 1
fi

"$OUT/lua51" -v
echo "Built: $OUT/lua51, $OUT/luac51 (goto correctly rejected)"
