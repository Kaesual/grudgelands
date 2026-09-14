#!/usr/bin/env bash
# Build time of the Highcourt capital and of the seam that carries it, under
# both interpreters, against the contract's section 2.3 budget. Three runs each,
# because `os.clock` on a loaded workstation is noisy and a single number is not
# a measurement.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
for run in 1 2 3; do
	luajit tools/wp13/highcourt_timing.lua "$repo" luajit
done
for run in 1 2 3; do
	tools/bin/lua51 tools/wp13/highcourt_timing.lua "$repo" puc51
done
