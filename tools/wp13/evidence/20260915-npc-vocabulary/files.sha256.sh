#!/usr/bin/env bash
# The frozen-byte manifest of every source this increment changed and every
# product in this directory.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-npc-vocabulary"

{
	echo "# sources this increment changed"
	sha256sum \
		mods/ENTITIES/grug_mobs/start_villagers.lua \
		mods/ENTITIES/grug_mobs/start_npcs.lua \
		mods/ENTITIES/grug_traders/vendors.lua \
		mods/ENTITIES/grug_traders/stock.lua \
		mods/ENTITIES/grug_traders/init.lua \
		tools/wp13/start_npcs_kat.lua \
		tools/wp13/run_npc_probe.sh \
		tools/wp13/npc_probe/init.lua \
		tools/wp13/npc_probe/mod.conf \
		tools/wp40/quality/vendor_fixture.lua \
		tools/wp40/r7/micro_kat_fixture.lua \
		docs/design/settlements.md \
		docs/research/wp13-npc-vocabulary.md
	echo "# products of this directory"
	find "$here" -type f ! -name 'files.sha256' -print0 | sort -z |
		xargs -0 sha256sum
} >"$here/files.sha256"
wc -l <"$here/files.sha256"
