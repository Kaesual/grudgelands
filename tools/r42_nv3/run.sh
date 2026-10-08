#!/usr/bin/env bash
# Round 42 lane NV3 settlement probe (grug_probe_r42_nv3, staged into a
# throwaway game copy, never shipped): live searches, walker and patrol
# progress and the route cache in a start town, a village and a capital
# (seed 42, the plan's settlement seed), and the capital's streets as data.
# One engine boot; copies the result file and the probe's log lines to
# OUT_DIR, removes the run directory and exits 0 only when the probe finished
# ("RESULT DONE").
#
# Usage (any directory): tools/r42_nv3/run.sh OUT_DIR LABEL [TARGETS] [TIMEOUT]
#   TARGETS  comma separated: start, village, capital, streets (default
#            "streets,start,village"); a capital takes about 2.5 min with
#            OBS 90, a start or a village about 1.5
#   TIMEOUT  seconds for the boot (default 330)
#   OBS=<s>  observation per settlement (default 90)
#   STEADY=<s> after it, the census (every leg of the settlement through the
#            route cache, when the code has one) and a second observation of
#            this many seconds on the full cache (default 0: neither)
#   SEED=<unsigned decimal> the world seed (default 42)
#   LAUNCHER="<command> [args]" replaces the default launcher, which is the
#     Round 42 measuring queue (engine_run.sh) when it exists, else
#     tools/luanti_headless.sh directly.
# Then: python3 tools/r42_nv3/summarize.py OUT_DIR/nv3_results.json [AFTER.json]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR LABEL [TARGETS] [TIMEOUT]}"
label="${2:?label}"
targets="${3:-streets,start,village}"
timeout_s="${4:-330}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
queue="$HOME/projects/grudgelands-orchestration/r42/engine_run.sh"
if [[ -n "${LAUNCHER:-}" ]]; then
	read -r -a launcher <<<"$LAUNCHER"
elif [[ -x "$queue" ]]; then
	launcher=("$queue" "nv3_$label")
else
	launcher=("$repo/tools/luanti_headless.sh")
fi
root="$(mktemp -d /tmp/grudgelands-headless.nv3-XXXXXX)"
patchdir="$(mktemp -d)"
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
{
	echo ""
	echo "# Round 42 NV3 probe"
	echo "max_forceloaded_blocks = 6000"
	echo "grug_nv3_targets = $targets"
	echo "grug_nv3_obs = ${OBS:-90}"
	echo "grug_nv3_steady = ${STEADY:-0}"
} >>"$patchdir/b/minetest.conf"
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true
set +e
(cd "$repo" && SEED="${SEED:-42}" PROBE="$here/grug_probe_r42_nv3" \
	GAME_PATCH="$patchdir/probe.patch" ROOT="$root" "${launcher[@]}" "$timeout_s") \
	>"$out/headless.txt" 2>&1
code=$?
set -e
rm -rf "$patchdir"
cat "$out/headless.txt"
if [[ "$root" == /tmp/grudgelands-headless.nv3-* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	cp "$root/world/nv3_results.json" "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
grep -ah '\[nv3\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
if [[ $code -eq 0 ]] && grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "nv3 probe: PASS ($out)"
	exit 0
fi
echo "nv3 probe: FAIL (boot status $code)"
exit 1
