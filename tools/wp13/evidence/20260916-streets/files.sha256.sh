#!/usr/bin/env bash
# The sources this package added or changed, hashed.
#   files.sha256.sh <repo>
set -euo pipefail
export LC_ALL=C
repo="${1:?usage: files.sha256.sh REPO}"
cd "$repo"
git diff --name-only --diff-filter=d f37a0c5b -- \
	mods/MAPGEN/grug_mapgen/wp13 mods/MAPGEN/grug_mapgen/wp40 \
	tools/wp13 docs/research |
	grep -v '^tools/wp13/evidence/20260916-streets/' |
	sort |
	xargs sha256sum
