#!/usr/bin/env bash
# Nothing this lane published moved: the six start blueprint identities, and
# the digests of the fixtures that carry the two capitals' published
# identities, compared against the same three on `main`.
#
# Usage: identity.sh [<a checkout of the base commit>]
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
base="${1:-}"
cd "$repo"

echo "== the six start blueprint identities, this tree =="
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua "$repo"

kats() {
	local tree="$1"
	local name
	for name in library_kat blueprint_kat highcourt_kat dur_brannoc_kat; do
		printf '%-18s %s\n' "$name" \
			"$(cd "$tree" && luajit -e "io.write(dofile('tools/wp13/$name.lua')('.'))" |
				sha256sum)"
	done
}

echo
echo "== the capital fixtures, this tree =="
kats "$repo"

if [[ -n "$base" && -d "$base" ]]; then
	echo
	echo "== the same four, on the base commit at $base =="
	kats "$base"
fi
