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
      # The exponent is either an RK constant (`POW a b -k ; - 2`) or, in a
      # function with more than 256 constants (or `local k = 2`), a
      # register loaded by `LOADK r k ; 2`. The pass remembers per function
      # which registers a LOADK set to 2 or "pow" and forgets a register on
      # any later write to it (straight-line approximation, no jumps).
      pow_checked=1
      hits=$("$parser" -l -p "$file" | awk -v f="$file" '
        function forget_from(r,  k) {
          for (k in two) if (k + 0 >= r) delete two[k]
          for (k in pw) if (k + 0 >= r) delete pw[k]
        }
        function hit(msg,  line) {
          line = $2; gsub(/[][]/, "", line); print f ":" line ": " msg
        }
        /^(main|function) </ { split("", two); split("", pw); next }
        $1 !~ /^[0-9]+$/ || $2 !~ /^\[/ { next }
        {
          op = $3; a = $4 + 0
          if (op == "POW") {
            c = $6
            if ((c ~ /^-/ && $(NF - 2) == ";" && $NF == "2") || (c !~ /^-/ && (c in two)))
              hit("x ^ 2 (write x * x)")
          }
          if (op == "GETTABLE") {
            c = $6
            if ((c ~ /^-/ && $NF == "\"pow\"") || (c !~ /^-/ && (c in pw)))
              hit("math.pow (write x * x or x ^ k)")
          }
          # register writes: forget what the register held
          if (op ~ /^(SETGLOBAL|SETUPVAL|SETTABLE|SETLIST|JMP|EQ|LT|LE|TEST|RETURN|TAILCALL|CLOSE)$/) next
          if (op ~ /^(CALL|VARARG|LOADNIL|SELF|TFORLOOP|FORLOOP|FORPREP)$/) forget_from(a)
          else { delete two[a]; delete pw[a] }
          if (op == "LOADK" && $(NF - 1) == ";") {
            if ($NF == "2") two[a] = 1
            else if ($NF == "\"pow\"") pw[a] = 1
          }
        }')
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
# Sweeps 1-5 read stripped copies with the source's line numbers
# (tools/check_lua_strip.awk): comments and long-bracket strings are removed
# for every sweep; short strings become "" for sweeps 1, 3, 4 and 5, which
# look for code, while sweep 2 keeps them to find escapes inside. Prose such
# as a `|` table row or `Class::method` in a comment cannot match. (Sweep 4's
# `//`, `&`, `|`, `<<`, `>>` in code are also parse errors for luac51 above.)
strip=$(dirname "$0")/check_lua_strip.awk
tmp=$(mktemp -d "${TMPDIR:-/tmp}/check_lua.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/code" "$tmp/text"
count=0
for file in "$@"; do
  count=$((count + 1))
  copy=$(printf '%06d.lua' "$count")
  awk -v mode=code -f "$strip" "$file" > "$tmp/code/$copy"
  awk -v mode=text -f "$strip" "$file" > "$tmp/text/$copy"
  printf '%s\n' "$file" >> "$tmp/names"
done
findings=0
for index in "${!patterns[@]}"; do
  mode=code
  if [ "$index" -eq 1 ]; then mode=text; fi
  # rg prints <tmp>/<mode>/000042.lua:<line>:<stripped text>; name the source
  if rg -uu -n --with-filename --sort path "${patterns[$index]}" "$tmp/$mode" |
    awk -v pre="$tmp/$mode/" 'NR == FNR { name[FNR] = $0; next }
      { s = substr($0, length(pre) + 1); print name[substr(s, 1, 6) + 0] substr(s, 11) }' \
      "$tmp/names" -; then
    printf 'sweep %s FAIL: code hits above (comments stripped%s)\n' "$((index+1))" \
      "$([ "$mode" = code ] && printf ', string literals shown as ""')" >&2
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
