#!/usr/bin/env bash
# What this package did NOT move: the six start blueprint identities, Highcourt's
# 54 blueprint identities, and the three fixtures that own the shared building
# library and the pilot capital.
#
# Set WP13_MAIN_TREE to a `git archive` of main extracted into a scratch tree to
# compare against the bytes of main rather than against this tree's git state.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
base="${WP13_MAIN_TREE:-}"

echo "== the six start blueprint identities, this tree =="
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua .
echo
printf 'start_identity digest '
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua . |
	sha256sum

echo
echo "== every blueprint identity Highcourt publishes, this tree =="
luajit tools/wp13/highcourt_identities.lua .

echo
echo "== library_kat / blueprint_kat / highcourt_kat, this tree =="
for kat in library_kat blueprint_kat highcourt_kat; do
	printf '%-16s ' "$kat"
	luajit -e "io.write(dofile('tools/wp13/$kat.lua')('.'))" | sha256sum
done

echo
echo "== the Dur Brannoc KAT under both interpreters =="
for bin in luajit tools/bin/lua51; do
	printf '%-16s ' "$bin"
	"$bin" -e "io.write(dofile('tools/wp13/dur_brannoc_kat.lua')('.'))" |
		sha256sum
done

if [[ -n "$base" && -d "$base" ]]; then
	echo
	echo "== the same three fixtures, on main at $base =="
	for kat in library_kat blueprint_kat highcourt_kat; do
		printf '%-16s ' "$kat"
		luajit -e "local r='$base' io.write(dofile(r..'/tools/wp13/$kat.lua')(r))" |
			sha256sum
	done
	echo
	echo "== the six starts and Highcourt's identities, on main =="
	luajit "$base/tools/wp13/evidence/20260914-capital-parts/start_identity.lua" \
		"$base" | sha256sum
	luajit "$base/tools/wp13/highcourt_identities.lua" "$base" | sha256sum
else
	echo
	echo "(set WP13_MAIN_TREE to a git archive of main to compare)"
fi
