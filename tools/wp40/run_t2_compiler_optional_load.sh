#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 optional fixed-geometry load runner.
#
# It gates mods/MAPGEN/grug_mapgen/wp40/compiler.lua, whose optional
# geometry/compiler_impl.lua load must decide PRESENCE by evidence that exists
# in production -- an open probe, and a core.get_dir_list listing where the
# sandbox withholds the probe's errno -- and never by matching the error prose
# of a failed load. Three engine measurements make prose matching unusable and
# an errno test insufficient:
#   * Luanti localizes strerror (src/main.cpp -> init_gettext, 5.16.1 and
#     submodule HEAD :792, 5.17.0 :794 -> src/gettext.cpp:192/:223,
#     setlocale(LC_ALL, "")); on engine 5.16.1 the secured loader pushes
#     path .. ": " .. strerror(errno) (5.16.1 s_security.cpp:677), which under
#     de_DE.UTF-8 reads "Datei oder Verzeichnis nicht gefunden".
#   * Luanti 5.17.0 dropped strerror from that path and pushes the fixed text
#     path .. ": Failed reading file." (5.17.0 s_security.cpp:731-732).
#   * Mod security truncates io.open to two results (sl_io_open ends in
#     lua_call(L, with_mode ? 2 : 1, 2) and "return 2"; 5.16.1
#     s_security.cpp:1039, 5.17.0 :1089, submodule HEAD :1031), so the errno is
#     ALWAYS nil in production and cannot decide anything there.
#
# The suite runs under LuaJIT and vendored PUC 5.1, each once under LC_ALL=C and
# once under a non-C locale, and every output must be byte-identical. NOTE what
# the locale arms can and cannot prove: neither standalone interpreter calls
# setlocale, so their strerror text stays English whatever LC_ALL says. The arms
# prove the harness and the loader are locale-invariant on this host; the
# executable proof that a LOCALIZED message cannot steer the decision is the
# injected-message cases inside the test (case5a/5b/5c offline, case7a/7b/7c in
# the production shape, where 7b and 7c differ ONLY in the directory listing),
# plus the static case5d assertion that the executable text of compiler.lua
# searches no string at all.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"

command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}

owned_lua=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/compiler.lua"
	"$repo/tools/wp40/t2_compiler_optional_load_test.lua"
)

"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T2 compiler optional-load global write in $file" >&2
		exit 1
	fi
done

# The five plain-5.1 sweeps of docs/research/luanti-lua.md. Sweeps 1-4 are pure
# language rules and apply to every file here; tools/ Lua is outside the
# mods/*/grug_* scope the doc defines, so it gets them explicitly.
language_sweeps=(
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
	'\\u\{|\\x[0-9A-Fa-f]|\\z'
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
)
for pattern in "${language_sweeps[@]}"; do
	if rg -n --no-heading -e "$pattern" "${owned_lua[@]}"; then
		echo "WP40 T2 compiler optional-load: plain-5.1 sweep hit above" >&2
		exit 1
	fi
done

# Sweep 5 is the sandbox/namespace rule. In full it applies to the shipped mod
# file. The offline harness deliberately shells out to sha256sum through
# os.execute -- the established tools/wp40 idiom, see t2_schema_core_test.lua --
# and never runs inside the sandbox, so it is held to the rest of the rule.
if rg -n --no-heading -e '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.' \
		"$repo/mods/MAPGEN/grug_mapgen/wp40/compiler.lua"; then
	echo "WP40 T2 compiler optional-load: sandbox sweep hit above" >&2
	exit 1
fi
if rg -n --no-heading -e '\brequire[[:space:]]*\(|io\.popen|os\.exit|\bminetest\.' \
		"$repo/tools/wp40/t2_compiler_optional_load_test.lua"; then
	echo "WP40 T2 compiler optional-load: harness sandbox sweep hit above" >&2
	exit 1
fi

bash -n "$script_dir/run_t2_compiler_optional_load.sh"

luajit_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
puc_bin="$repo/tools/bin/lua51"

scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-compiler-optional.XXXXXXXX)"
trap 'rm -rf "$scratch"' EXIT

# A real non-C locale, or none. A gate that silently pretends to have run the
# locale arm would be worse than one that says it could not.
non_c_locale=""
for candidate in de_DE.UTF-8 de_DE.utf8 fr_FR.UTF-8 fr_FR.utf8; do
	if locale -a 2>/dev/null | rg -q -F "$candidate"; then
		non_c_locale="$candidate"
		break
	fi
done

arms=("C:$luajit_bin:luajit-C" "C:$puc_bin:puc-C")
if [[ -n "$non_c_locale" ]]; then
	arms+=("$non_c_locale:$luajit_bin:luajit-nonc")
	arms+=("$non_c_locale:$puc_bin:puc-nonc")
else
	echo "WP40 T2 compiler optional-load: no non-C locale on this host;" \
		"the non-C arms did not run" >&2
fi

reference=""
for arm in "${arms[@]}"; do
	locale_name="${arm%%:*}"
	rest="${arm#*:}"
	binary="${rest%%:*}"
	label="${rest#*:}"
	out="$scratch/out-$label.txt"
	LC_ALL="$locale_name" LANG="$locale_name" "$binary" \
		"$repo/tools/wp40/t2_compiler_optional_load_test.lua" \
		"$repo" "$scratch" > "$out"
	if [[ -z "$reference" ]]; then
		reference="$out"
	elif ! cmp -s "$reference" "$out"; then
		echo "WP40 T2 compiler optional-load: $label differs from" \
			"the reference" >&2
		diff "$reference" "$out" >&2 || true
		exit 1
	fi
done

cat "$reference"
if [[ -n "$non_c_locale" ]]; then
	echo "WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical under" \
		"LC_ALL=C and LC_ALL=$non_c_locale"
else
	echo "WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical" \
		"under LC_ALL=C"
fi
