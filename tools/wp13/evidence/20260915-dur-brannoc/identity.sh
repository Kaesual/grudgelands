#!/usr/bin/env bash
# What this package did NOT move: the six start blueprint identities, and the
# three fixtures that own the shared building library and the pilot capital.
#
# The comparison is against a `git archive` of `main` at 9e22b0d extracted into
# a scratch tree, so it is the bytes of main and not this tree's git state.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-dur-brannoc"
base="${WP13_MAIN_TREE:-}"

echo "== the six start blueprint identities, this tree =="
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua .

echo
echo "== library_kat / blueprint_kat / highcourt_kat, this tree =="
for kat in library_kat blueprint_kat highcourt_kat; do
	printf '%-16s ' "$kat"
	luajit -e "io.write(dofile('tools/wp13/$kat.lua')('.'))" | sha256sum
done

if [[ -n "$base" && -d "$base" ]]; then
	echo
	echo "== the same three, on main at $base =="
	for kat in library_kat blueprint_kat highcourt_kat; do
		printf '%-16s ' "$kat"
		luajit -e "local r='$base' io.write(dofile(r..'/tools/wp13/$kat.lua')(r))" |
			sha256sum
	done
else
	echo
	echo "(set WP13_MAIN_TREE to a git archive of main to compare)"
fi
