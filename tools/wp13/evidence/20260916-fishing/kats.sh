#!/usr/bin/env bash
# The WP13 fixtures this increment touches or relies on, in one fixed order,
# in ONE interpreter process -- so the two interpreter runs can be compared byte
# for byte (docs/research/luanti-lua.md, "Interpreter and test strategy").
#
#   wield_transform   the three poses, the axe roll, the group -> pose mapping
#   fishing           the catch table, the bite, the driven mechanic
#   character_visuals the composition this lane shares a mod with
#   start_npcs        the activity table, whose `fish` row this lane moved
#
# `fishing_kat.lua` installs stub `core`/`vector`/`ItemStack`/`mobs` globals for
# its whole run and restores them at the end, which is why it is not last: the
# order below is the one the restoration was written for and the one both
# recorded runs used.
#
# Usage, from the repository root:
#   tools/wp13/evidence/20260916-fishing/kats.sh luajit
#   tools/wp13/evidence/20260916-fishing/kats.sh tools/bin/lua51
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
interp="${1:?usage: kats.sh luajit|tools/bin/lua51}"

"$interp" -e '
local r = "."
io.write(dofile(r .. "/tools/wp13/wield_transform_kat.lua")(r))
io.write(dofile(r .. "/tools/wp13/fishing_kat.lua")(r))
io.write(dofile(r .. "/tools/wp13/character_visuals_kat.lua")(r))
io.write(dofile(r .. "/tools/wp13/start_npcs_kat.lua")(r))
'
