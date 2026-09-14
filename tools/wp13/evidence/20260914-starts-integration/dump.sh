#!/usr/bin/env bash
# Per-start blueprint dump SHA-256. The dumper loads the blueprint wrapper,
# which loads the whole WP13 library, so the digest covers every file the
# composition reads -- it is the identity check for "this start's bytes did
# not move".
#
#     tools/wp13/evidence/20260914-starts-integration/dump.sh [tree-root]
set -uo pipefail
export LC_ALL=C
root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)}"
cd "$root" || exit 1
for key in hearthpine dawnmere silverleaf stillgrave sunscar kapok; do
	file="mods/MAPGEN/grug_mapgen/wp40/r7_${key}_blueprint.lua"
	if [ -f "$file" ]; then
		printf '%s %s\n' "$key" \
			"$(luajit tools/wp13/dump_blueprint.lua "$file" | sha256sum | cut -d' ' -f1)"
	fi
done
