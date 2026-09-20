#!/usr/bin/env bash
# Parser, SETGLOBAL and five sweeps only. No runtime interpreter is launched.
set -euo pipefail
command -v rg >/dev/null
(( $# > 0 )) || { echo 'usage: static.sh LUA_FILE ...' >&2; exit 2; }
for file in "$@"; do
    tools/bin/luac51 -p "$file"
    echo "parser PASS $file"
    tools/bin/luac51 -l -p "$file" | rg SETGLOBAL || test "$?" -eq 1
done
patterns=(
    '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
    '\\u\{|\\x[0-9A-Fa-f]|\\z'
    'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
    '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
    '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for index in "${!patterns[@]}"; do
    echo "SWEEP $((index + 1)) (review any comment/tool-only hits)"
    rg -n "${patterns[$index]}" "$@" || test "$?" -eq 1
done
