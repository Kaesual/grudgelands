#!/usr/bin/env bash
# What this package did NOT move: the six start blueprint identities and the
# Highcourt CORE digest. Both are the claim the research note's section 2.1
# makes, and both are printed here rather than asserted from memory.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"

echo "== the six start blueprint identities, which this package must not move =="
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua .

echo
echo "== the same six, as the districts package recorded them on main 9e22b0d =="
sed -n '50,55p' tools/wp13/evidence/20260915-highcourt-districts/timing.txt

echo
echo "== every blueprint identity Highcourt publishes (core first) =="
luajit tools/wp13/highcourt_identities.lua . | head -3
echo "..."
luajit tools/wp13/highcourt_identities.lua . | tail -2
echo
echo "core digest, expected 187f79e0ba52103818eba53f7ed9c3beadc631682648918301287fa4a7200499:"
luajit tools/wp13/highcourt_identities.lua . | grep -m1 core
