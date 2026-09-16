#!/usr/bin/env bash
# What this package did NOT move.
#
# Digests every shipped WP13 fixture output in ONE tree, so two trees can be
# compared byte for byte. Run it against this worktree and against a
# `git archive` of `main` at 1c9e0f39 and the two columns must be identical:
# the six start blueprint identities, the shared library, the six starts'
# acceptance, and every capital already on `main`: Highcourt, Dur Brannoc,
# Gor Drazhak, Lethariel and Kezamba. The last three joined the list when
# they merged; `wall.lua` is shared by three of them and `capital_probe` by
# all five, so all five are what this package must not move.
#
# The corner reconciliation of `wall.lua` section 1b does NOT move
# `highcourt_kat` or `dur_brannoc_kat`: their synthetic wall profiles are one
# dimensional per run, so their corners already agreed and the clamp finds
# nothing to do there -- which also means those two fixtures could not have
# caught the defect, and `nhal_veyr_kat.lua`'s shouldered ground is the first
# that can.
#
#     bash tools/wp13/evidence/20260915-nhal_veyr/identity.sh .
#     git archive 1c9e0f39 | tar -x -C /tmp/main-ref
#     cp -a tools/bin /tmp/main-ref/tools/
#     bash tools/wp13/evidence/20260915-nhal_veyr/identity.sh /tmp/main-ref
set -euo pipefail
export LC_ALL=C
repo="${1:?usage: identity.sh REPO}"
cd "$repo"
printf 'start_identity  %s\n' \
	"$(luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua . |
		sha256sum | cut -d' ' -f1)"
for kat in library_kat blueprint_kat highcourt_kat dur_brannoc_kat \
		gor_drazhak_kat lethariel_kat kezamba_kat; do
	printf '%-15s %s\n' "$kat" \
		"$(luajit -e "io.write(dofile('tools/wp13/$kat.lua')('.'))" |
			sha256sum | cut -d' ' -f1)"
done
