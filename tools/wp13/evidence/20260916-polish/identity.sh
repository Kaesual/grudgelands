#!/usr/bin/env bash
# The digests this lane moved and the ones it did not.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"

echo "== the six start identities (must be byte-identical to main) =="
echo "main f37a0c5b: 0bbf87a7253deadca55951752adde73e82c31cd10878dc64ef6d44af91ad1f5f"
printf 'this tree:  '
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua . | sha256sum

echo
echo "== every settlement identity the integration fixture prints =="
luajit -e "io.write(dofile('tools/wp13/integration_fixture.lua')('.'))" |
	tr ' ' '\n'

echo
echo "== Highcourt's blueprint identities (must be byte-identical to main:"
echo "   the lot POSITIONS moved, and a plot's identity is its own cells) =="
luajit tools/wp13/highcourt_identities.lua .
