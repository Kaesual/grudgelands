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
# The four expected values were taken on an ARCHIVE OF MAIN extracted into a
# scratch tree, with the same KAT run there -- so this is a comparison against
# the tree before this lane and not a number somebody wrote down from this one.
# Re-verified against main at f5583e13 (the second rebase): all four, the
# start-identity fixture (0bbf87a7...) and Highcourt's own identity listing
# (66e2ed00...) are byte-identical on both trees. `dur_brannoc_kat`'s value
# MOVED between c8050057 and f5583e13 (bfffe682... -> 36b36628...) and that is
# Lane D's own upgrade of Dur Brannoc to the Highcourt standard, not this lane:
# the new value is what main itself produces, and this tree reproduces it.
declare -A expect=(
	[library_kat]=bd4b51ab87f33ebc719c7833f1ff560d6a8d6332d2f8e5691acf7b5af0bcddee
	[blueprint_kat]=13f7fd7da93cf3a0fb67a8f83c3eb757d83eee36625ebbc82ae8bd535489a30f
	[highcourt_kat]=ac3877565002bfdb3ce9f1975ceb76a878ee6be14c89d33f394edc62892ed183
	[dur_brannoc_kat]=36b366288f7017832e790be4cf9bec54c388861b3a0ee727dc9f6b214fa52ee9
)
status=0
for kat in library_kat blueprint_kat highcourt_kat dur_brannoc_kat; do
	got="$(luajit -e "io.write(dofile('tools/wp13/$kat.lua')('.'))" |
		sha256sum | cut -d" " -f1)"
	if [[ "$got" == "${expect[$kat]}" ]]; then
		printf '%-18s %s  unchanged\n' "$kat" "$got"
	else
		printf '%-18s %s  MOVED (main: %s)\n' "$kat" "$got" "${expect[$kat]}"
		status=1
	fi
done
exit "$status"
