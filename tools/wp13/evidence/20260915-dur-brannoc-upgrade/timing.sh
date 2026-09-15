#!/usr/bin/env bash
# Build time of the upgraded Dur Brannoc against the capitals contract's section
# 2.3 budget, three runs under each interpreter. A timing is the one thing the
# two interpreters must NOT agree on, so this writes to stdout and is never part
# of the final micro pair.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
for run in 1 2 3; do
	luajit tools/wp13/capital_timing.lua . dur_brannoc luajit
done
for run in 1 2 3; do
	tools/bin/lua51 tools/wp13/capital_timing.lua . dur_brannoc puc51
done
# And the pilot capital's own numbers on the same tree, so the two are
# comparable: this package changed no shared module, and Highcourt's row is what
# says so in milliseconds as well as in digests.
luajit tools/wp13/highcourt_timing.lua . luajit
tools/bin/lua51 tools/wp13/highcourt_timing.lua . puc51
