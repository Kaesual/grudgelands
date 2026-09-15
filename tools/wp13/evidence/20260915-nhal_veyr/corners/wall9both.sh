#!/usr/bin/env bash
# `capital_wall.lua` over the nine seeds, in BOTH trees, against the SAME
# terrain dumps: the corner distribution before and after the reconciliation.
#
#     wall9both.sh <after-tree> <terrain-root> <before-tree> [<out-dir>]
#
# `<before-tree>` is an export of the commit immediately before the corner
# commit -- this package's own docs commit, NOT `main`, because Nhal Veyr does
# not exist on `main` and `capital_wall.lua` reads the capital's own run table.
# The terrain root is one `terrain-<seed>/` per seed from `terrain_all.sh`; both
# trees read the SAME dumps, so the only thing that differs between the two
# columns is `wall.lua` section 1b.
set -uo pipefail
export LC_ALL=C
after="${1:?after repo}"
root="${2:?terrain root}"
before="${3:?before tree}"
out="${4:-$(mktemp -d /tmp/wall9both.XXXXXX)}"
mkdir -p "$out"
for tree in "$before" "$after"; do
	name=$([ "$tree" = "$before" ] && echo before || echo after)
	( cd "$tree" && bash "$tree/tools/wp13/evidence/20260915-nhal_veyr/wall_all.sh" \
		"$root" nhal_veyr ) >"$out/wall9-$name.txt" 2>&1
	printf '== %s: FAIL lines %s\n' "$name" \
		"$(grep -c '^FAIL' "$out/wall9-$name.txt" || true)"
	awk -F'\t' 'NF==5 && $5 ~ /^[0-9]+$/ {print $5}' "$out/wall9-$name.txt" |
		sort -n | uniq -c | awk '{printf "   step %s: %s corners\n", $2, $1}'
done
printf 'the two runs are in %s\n' "$out"
