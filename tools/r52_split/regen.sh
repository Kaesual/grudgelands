#!/usr/bin/env bash
# Rewrites tools/r52_split/expected.txt: the registration dump of the class
# files at COMMIT (default 7813165e, main before the Round 52 split), read with
# `git show` into a scratch folder, never by a checkout. Only for a deliberate
# registration change; the fixture then compares the working tree against it.
#   bash tools/r52_split/regen.sh [COMMIT]
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
commit="${1:-7813165e}"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
cd "$repo"
for path in $(git ls-tree -r --name-only "$commit" mods/PLAYER/grug_abilities mods/PLAYER/grug_classes |
		grep -E '/(kits[^/]*|scout|talents[^/]*|talent_windows|scout_talents)\.lua$'); do
	mkdir -p "$scratch/$(dirname "$path")"
	git show "$commit:$path" >"$scratch/$path"
done
luajit tools/r52_split/portable_test.lua "$repo" --dump "$scratch" >tools/r52_split/expected.txt
echo "wrote tools/r52_split/expected.txt from $commit"
