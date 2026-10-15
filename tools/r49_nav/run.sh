#!/usr/bin/env bash
# Round 49 NAV short-range chase probe (grug_probe_r49_nav, staged into a
# throwaway game copy, never shipped): the bush, terrace and trunk scenes
# driven by real mobs on the real navigation code. One engine boot through
# the shared Lua-process queue; copies the result file and the probe's log
# lines to OUT_DIR, removes the run directory and exits 0 only when the probe
# finished ("RESULT DONE").
#
# Usage (any directory): tools/r49_nav/run.sh OUT_DIR LABEL [TIMEOUT]
#   TIMEOUT  seconds for the boot (default 300; the three movers take about
#            1.5 min after the arena is built)
#   SEED=<unsigned decimal> the world seed (default 12345, the Round 42 probe's)
#   R49NAV_PHASES=scenes,extra,real  the phases (default "scenes"; see the
#     probe's init.lua: "real" generates three small natural sites)
#   R49NAV_MOVERS=zombie,rat,archer / R49NAV_SCENES=trunk_d5,t1_bush_d5
#     restrict a run
#   LAUNCHER="<command> [args]" replaces the default launcher, which is the
#     shared queue (~/projects/grudgelands-orchestration/r45/lua_run.sh, one
#     slot) when it exists, else tools/luanti_headless.sh directly.
# Then: python3 tools/r49_nav/summarize.py OUT_DIR/r49nav_results.json
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR LABEL [TIMEOUT]}"
label="${2:?label}"
timeout_s="${3:-300}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
queue="$HOME/projects/grudgelands-orchestration/r45/lua_run.sh"
if [[ -n "${LAUNCHER:-}" ]]; then
	read -r -a launcher <<<"$LAUNCHER"
elif [[ -x "$queue" ]]; then
	launcher=("$queue" "r49nav_$label" 1 env LC_ALL=C "$repo/tools/luanti_headless.sh")
else
	launcher=("$repo/tools/luanti_headless.sh")
fi
root="$(mktemp -d /tmp/grudgelands-headless.r49nav-XXXXXX)"
# The probe's settings, as a disposable patch to the staged game's
# minetest.conf: the forceloaded arena and the filters.
patchdir="$(mktemp -d)"
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
{
	echo ""
	echo "# Round 49 NAV probe"
	echo "max_forceloaded_blocks = 2000"
	[[ -n "${R49NAV_MOVERS:-}" ]] && echo "grug_r49nav_movers = $R49NAV_MOVERS"
	[[ -n "${R49NAV_SCENES:-}" ]] && echo "grug_r49nav_scenes = $R49NAV_SCENES"
	[[ -n "${R49NAV_PHASES:-}" ]] && echo "grug_r49nav_phases = $R49NAV_PHASES"
	true
} >>"$patchdir/b/minetest.conf"
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true
set +e
(cd "$repo" && SEED="${SEED:-12345}" PROBE="$here/grug_probe_r49_nav" \
	GAME_PATCH="$patchdir/probe.patch" ROOT="$root" "${launcher[@]}" "$timeout_s") \
	>"$out/headless.txt" 2>&1
code=$?
set -e
rm -rf "$patchdir"
cat "$out/headless.txt"
if [[ "$root" == /tmp/grudgelands-headless.r49nav-* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	cp "$root/world/r49nav_results.json" "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
grep -ah '\[r49nav\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
if grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "r49nav probe: DONE (boot status $code; $out)"
	exit 0
fi
echo "r49nav probe: FAIL (boot status $code)"
exit 1
