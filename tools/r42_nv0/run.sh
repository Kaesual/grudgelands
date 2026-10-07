#!/usr/bin/env bash
# Round 42 lane NV0 navigation probe (grug_probe_r42_nv0, staged into a
# throwaway game copy, never shipped): the test scenes driven by real mobs on
# the real code, the find_path calibration and the 40-blocked-chasers stress.
# One engine boot; copies the result file and the probe's log lines to OUT_DIR,
# removes the run directory and exits 0 only when the probe finished
# ("RESULT DONE").
#
# Usage (any directory): tools/r42_nv0/run.sh OUT_DIR LABEL [PHASES] [TIMEOUT]
#   PHASES   comma separated: scenes, calib, chasers40, settle (default
#            "scenes"); scenes take about 4 min, calib about 1.5, settle
#            about 2: run one phase per boot, or raise TIMEOUT
#   TIMEOUT  seconds for the boot (default 360)
#   SEED=<unsigned decimal> the world seed (default 12345, Round 30's probe seed)
#   NV0_MOVERS=boar,wolf / NV0_SCENES=trunk,row  restrict a debug run
#   LAUNCHER="<command> [args]" replaces the default launcher, which is the
#     Round 42 measuring queue (engine_run.sh) when it exists, else
#     tools/luanti_headless.sh directly.
# Then: python3 tools/r42_nv0/summarize.py OUT_DIR/nv0_results.json [AFTER.json]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR LABEL [PHASES] [TIMEOUT]}"
label="${2:?label}"
phases="${3:-scenes}"
timeout_s="${4:-360}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
queue="$HOME/projects/grudgelands-orchestration/r42/engine_run.sh"
if [[ -n "${LAUNCHER:-}" ]]; then
	read -r -a launcher <<<"$LAUNCHER"
elif [[ -x "$queue" ]]; then
	launcher=("$queue" "nv0_$label")
else
	launcher=("$repo/tools/luanti_headless.sh")
fi
root="$(mktemp -d /tmp/grudgelands-headless.nv0-XXXXXX)"
# The probe's settings, as a disposable patch to the staged game's
# minetest.conf: the forceloaded arena and the phase list.
patchdir="$(mktemp -d)"
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
{
	echo ""
	echo "# Round 42 NV0 probe"
	echo "max_forceloaded_blocks = 2000"
	echo "grug_nv0_phases = $phases"
	[[ -n "${NV0_MOVERS:-}" ]] && echo "grug_nv0_movers = $NV0_MOVERS"
	[[ -n "${NV0_SCENES:-}" ]] && echo "grug_nv0_scenes = $NV0_SCENES"
} >>"$patchdir/b/minetest.conf"
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true
set +e
(cd "$repo" && SEED="${SEED:-12345}" PROBE="$here/grug_probe_r42_nv0" \
	GAME_PATCH="$patchdir/probe.patch" ROOT="$root" "${launcher[@]}" "$timeout_s") \
	>"$out/headless.txt" 2>&1
code=$?
set -e
rm -rf "$patchdir"
cat "$out/headless.txt"
if [[ "$root" == /tmp/grudgelands-headless.nv0-* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	cp "$root/world/nv0_results.json" "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
grep -ah '\[nv0\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
if [[ $code -eq 0 ]] && grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "nv0 probe: PASS ($out)"
	exit 0
fi
echo "nv0 probe: FAIL (boot status $code)"
exit 1
