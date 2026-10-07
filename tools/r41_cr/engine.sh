#!/usr/bin/env bash
# Round 41 lane CR engine probe: stages tools/r41_cr/grug_probe_r41_cr with
# one plan file as its plan.txt and boots tools/luanti_headless.sh on the
# production report's seed (override with SEED=).
#   tools/r41_cr/engine.sh <plan file> [timeout seconds, default 300]
# Start it through the round's queue (one Lua slot). The probe's lines are
# "[r41cr_probe]" in the printed log; KEEP=1 keeps the run directory.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
plan="$(realpath -e -- "${1:?plan file}")"
timeout_s="${2:-300}"
stage="$(mktemp -d /tmp/r41cr_probe.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
cp -a "$repo/tools/r41_cr/grug_probe_r41_cr" "$stage/"
cp "$plan" "$stage/grug_probe_r41_cr/plan.txt"
export SEED="${SEED:-3684797457838814663}"
PROBE="$stage/grug_probe_r41_cr" "$repo/tools/luanti_headless.sh" "$timeout_s" || true
