#!/usr/bin/env bash
# The five WP13 fixtures this increment touches or must keep green, run in one
# interpreter and concatenated in a fixed order. The same bytes are run once
# under LuaJIT and once under the engine's bundled PUC 5.1 build; the two
# outputs must be byte-identical (docs/research/luanti-lua.md).
#
#   tools/wp13/evidence/20260915-weapon-ladder/kats.sh luajit
#   tools/wp13/evidence/20260915-weapon-ladder/kats.sh tools/bin/lua51
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
interpreter="${1:?interpreter required}"

for kat in gear_catalogue_kat wield_transform_kat character_visuals_kat \
		visuals_order_kat ability_rightclick_kat; do
	"$interpreter" -e "io.write(dofile('tools/wp13/${kat}.lua')('.'))"
done
