#!/usr/bin/env bash
# Build time of the Highcourt capital under both interpreters, three runs each,
# against the contract's section 2.3 budget. Timings are not part of any
# digest; they are the measurement the contract asks the first capital package
# to record.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-highcourt/timing.txt"
cd "$repo"
{
	echo "# nproc $(nproc), $(uname -sr)"
	for _ in 1 2 3; do
		luajit tools/wp13/highcourt_timing.lua "$repo" luajit
	done
	for _ in 1 2 3; do
		tools/bin/lua51 tools/wp13/highcourt_timing.lua "$repo" puc51
	done
} >"$out"
cat "$out"
