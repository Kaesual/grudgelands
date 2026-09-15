#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
cd "$1"
index=1
for pattern in \
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' \
	'\\u\{|\\x[0-9A-Fa-f]|\\z' \
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' \
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' \
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'; do
	echo "SWEEP $index"
	grep -rnE "$pattern" mods/*/grug_* tools --include=*.lua | sed 's/:[0-9]*:/:L:/'
	index=$((index + 1))
done
