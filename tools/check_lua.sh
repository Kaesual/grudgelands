#!/usr/bin/env bash
set -euo pipefail
command -v rg >/dev/null
parser=${GRUG_LUA51_PARSER:-tools/bin/luac51}
if [ "$#" -eq 0 ]; then
  echo 'Usage: check_lua.sh changed.lua ...' >&2
  exit 2
fi
pow_findings=0
pow_checked=0
for file in "$@"; do
  "$parser" -p "$file"
  printf 'parser PASS %s\n' "$file"
  "$parser" -l -p "$file" | rg SETGLOBAL || test "$?" -eq 1
  case "$file" in
    *mods/MAPGEN/*)
      # Sweep 6 (mapgen only), on the bytecode listing so comments and
      # strings cannot match: POW with the constant exponent 2 (also 2.0,
      # (2), 1 + 1) and any math.pow. LuaJIT's JIT folds x ^ 2 into x * x,
      # its interpreter calls pow(): the last bit then depends on JIT
      # history. See docs/research/luanti-lua.md "Floating point: LuaJIT
      # interpreter vs compiled code".
      pow_checked=1
      hits=$("$parser" -l -p "$file" | awk -v f="$file" '
        $3 == "POW" && $6 ~ /^-/ && $(NF - 2) == ";" && $NF == "2" {
          gsub(/[][]/, "", $2); print f ":" $2 ": x ^ 2 (write x * x)" }
        $3 == "GETTABLE" && $NF == "\"pow\"" {
          gsub(/[][]/, "", $2); print f ":" $2 ": math.pow (write x * x or x ^ k)" }')
      if [ -n "$hits" ]; then
        printf '%s\n' "$hits"
        pow_findings=1
      fi
      ;;
  esac
done
patterns=(
  '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
  '\\u\{|\\x[0-9A-Fa-f]|\\z'
  'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
  '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
  '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
findings=0
for index in "${!patterns[@]}"; do
  if rg -n "${patterns[$index]}" "$@"; then
    printf 'sweep %s: inspect hits (comments may match)\n' "$((index+1))" >&2
    findings=1
  else
    test "$?" -eq 1
    printf 'sweep %s PASS\n' "$((index+1))"
  fi
done
if [ "$pow_findings" -ne 0 ]; then
  printf 'sweep 6 FAIL: x ^ 2 / math.pow in mapgen code differs between the LuaJIT interpreter and compiled code; write x * x (docs/research/luanti-lua.md, "Floating point: LuaJIT interpreter vs compiled code")\n' >&2
  findings=1
elif [ "$pow_checked" -ne 0 ]; then
  printf 'sweep 6 PASS\n'
fi
exit "$findings"
