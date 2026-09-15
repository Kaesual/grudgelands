#!/usr/bin/env bash
# What this package did NOT move.
#
# Digests every shipped WP13 fixture output in ONE tree, so two trees can be
# compared byte for byte. Run it against this worktree and against a
# `git archive` of `main` at c8050057 and the two columns must be identical:
# the six start blueprint identities, the shared library, the six starts'
# acceptance, the pilot capital's and the dwarf capital's.
#
#     bash tools/wp13/evidence/20260915-nhal_veyr/identity.sh .
#     git archive c8050057 | tar -x -C /tmp/main-ref
#     cp -a tools/bin /tmp/main-ref/tools/
#     bash tools/wp13/evidence/20260915-nhal_veyr/identity.sh /tmp/main-ref
set -euo pipefail
export LC_ALL=C
repo="${1:?usage: identity.sh REPO}"
cd "$repo"
printf 'start_identity  %s\n' \
	"$(luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua . |
		sha256sum | cut -d' ' -f1)"
for kat in library_kat blueprint_kat highcourt_kat dur_brannoc_kat; do
	printf '%-15s %s\n' "$kat" \
		"$(luajit -e "io.write(dofile('tools/wp13/$kat.lua')('.'))" |
			sha256sum | cut -d' ' -f1)"
done
