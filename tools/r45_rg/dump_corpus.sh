#!/usr/bin/env bash
# Round 45 lane RG: boots the game headless once with the disposable probe
# mod grug_probe_r45_rg and copies the recipe corpus it writes into the world
# directory to OUT (default: tools/r45_rg/corpus_<git short hash>.lua).
#
# Usage: tools/r45_rg/dump_corpus.sh [OUT] [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
target="${1:-$here/corpus_$(git -C "$repo" rev-parse --short HEAD).lua}"
timeout_s="${2:-240}"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
set +e
PROBE="$here/grug_probe_r45_rg" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
status=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
corpus=""
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	grep -h "\[r45rg_probe\]\|ERROR\|GRUG-SEVERE" "$root/server.log" || true
	[[ -f "$root/world/r45_rg_corpus.lua" ]] &&
		cp "$root/world/r45_rg_corpus.lua" "$out/corpus.lua" && corpus="$out/corpus.lua"
	rm -rf "$root"
fi
cat "$out/headless.txt" | tail -n 5
if [[ -z "$corpus" ]]; then
	echo "r45 rg corpus dump: FAIL"
	exit 1
fi
cp "$corpus" "$target"
echo "r45 rg corpus dump: wrote $target (launcher status $status)"
