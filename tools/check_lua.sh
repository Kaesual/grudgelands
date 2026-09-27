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
