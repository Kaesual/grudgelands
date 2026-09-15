#!/usr/bin/env bash
# Nothing this lane touched may move a shipped identity.
#
#   * the six START blueprints, whose digests the wave-1 evidence froze and
#     whose whole fixture output hashes to 0bbf87a7... ;
#   * HIGHCOURT's core, its 52 plots and its overlay, which
#     `highcourt_identities.lua` prints in manifest order and whose cell total
#     is the 376 274 of the city-common standard;
#   * the three KATs of the settlements before this one.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"

echo "== the six start identities =="
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua .
echo -n "start_identity.lua output sha256: "
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua . | sha256sum

echo
echo "== Highcourt's blueprint identities, in manifest order =="
luajit tools/wp13/highcourt_identities.lua . | tail -3

echo
echo "== Gor Drazhak's own, in manifest order =="
luajit tools/wp13/gor_drazhak_identities.lua . | tail -3

echo
echo "== the KATs of the settlements before this one =="
for kat in library_kat blueprint_kat highcourt_kat dur_brannoc_kat; do
	printf '%-18s ' "$kat"
	luajit -e "io.write(dofile('tools/wp13/$kat.lua')('.'))" | sha256sum
done
