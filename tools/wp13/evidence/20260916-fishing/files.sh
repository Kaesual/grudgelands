#!/usr/bin/env bash
# Re-create `files.sha256`: every file of this evidence directory plus every
# source this increment changed or added.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here=tools/wp13/evidence/20260916-fishing

{
	find "$here" -type f ! -name files.sha256 -print0 | sort -z |
		xargs -0 sha256sum
	sha256sum \
		mods/PLAYER/grug_visuals/wield_geometry.lua \
		mods/PLAYER/grug_visuals/apply.lua \
		mods/ITEMS/grug_fishing/init.lua \
		mods/ITEMS/grug_fishing/catch.lua \
		mods/ITEMS/grug_fishing/mod.conf \
		mods/ITEMS/grug_fishing/LICENSE-media.md \
		mods/ITEMS/grug_fishing/textures/grug_fishing_rod.png \
		mods/ENTITIES/grug_mobs/start_villagers.lua \
		tools/wp13/wield_transform_kat.lua \
		tools/wp13/fishing_kat.lua \
		tools/wp13/start_npcs_kat.lua \
		docs/research/wp13-fishing.md \
		docs/design/items_crafting.md
} > "$here/files.sha256"
wc -l < "$here/files.sha256"
