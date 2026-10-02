#!/usr/bin/env bash
# Round 30 Lane P4: refresh tools/r30_p4/recipe_corpus.lua, the profession
# recipe corpus that tools/r30_p4/portable_test.lua (section C) replays. Boots
# the game headless once with the disposable probe mod grug_probe_r30_p4,
# which writes the corpus into the world directory after every mod loaded.
#
# Usage: tools/r30_p4/dump_corpus.sh [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
timeout_s="${1:-180}"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
set +e
PROBE="$here/grug_probe_r30_p4" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
corpus=""
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	grep -h "\[r30p4_probe\]" "$root/server.log" || true
	[[ -f "$root/world/r30_p4_recipe_corpus.lua" ]] &&
		cp "$root/world/r30_p4_recipe_corpus.lua" "$out/corpus.lua" && corpus="$out/corpus.lua"
	rm -rf "$root"
fi
if [[ -z "$corpus" ]]; then
	cat "$out/headless.txt"
	echo "r30 p4 corpus dump: FAIL"
	exit 1
fi
cp "$corpus" "$here/recipe_corpus.lua"
echo "r30 p4 corpus dump: wrote $here/recipe_corpus.lua"
