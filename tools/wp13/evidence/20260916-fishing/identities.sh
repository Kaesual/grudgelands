#!/usr/bin/env bash
# The digests this lane must NOT move, on this branch and on `main`, side by
# side. `main` is read out of the shared checkout read-only; nothing is written
# there.
#
#   tools/wp13/evidence/20260916-fishing/identities.sh [MAIN_CHECKOUT]
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
main="${1:-/home/jan/projects/grudgelands}"

echo "== six start identities -- this branch =="
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua .
echo -n "sha256: "
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua . | sha256sum

echo
echo "== six start identities -- main ($main) =="
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua "$main"
echo -n "sha256: "
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua "$main" |
	sha256sum

echo
echo "== Highcourt blueprint digests -- this branch =="
echo -n "sha256: "
luajit tools/wp13/highcourt_identities.lua . | sha256sum
luajit tools/wp13/highcourt_identities.lua .

echo
echo "== Highcourt blueprint digests -- main =="
echo -n "sha256: "
luajit tools/wp13/highcourt_identities.lua "$main" | sha256sum

echo
echo "== the frozen capital digests under tools/wp13/evidence/20260915-* =="
echo "(they are asserted by the capital KATs inside final_micro.lua; the"
echo " one-line diff of that run is in final-micro.txt)"
