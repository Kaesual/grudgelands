#!/usr/bin/env bash
# The socket inventory of every capital part, for every race the renders
# cover: id, role, local x/y/z and facing, exactly as `points.sockets`
# publishes them (docs/research/wp13-npc-sockets-contract.md section 2).
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-capital-parts"
cd "$out/renders/tsv"
for file in *.sockets; do
	if [ -s "$file" ]; then
		echo "== ${file%.sockets}"
		cat "$file"
	fi
done >"$out/sockets.txt"
wc -l <"$out/sockets.txt"
