#!/usr/bin/env bash
# Round 37 lane MG engine probe: one region round the Hearthpine start on a
# fresh world (grug_probe_r37_mg, staged into a throwaway game copy, never
# shipped), with the WP40 profiler's mapgen patch (per-chunk planner and
# writer times). Boots one isolated headless server through the shared Round
# 37 measuring semaphore (engine_run.sh) when it exists, else
# tools/luanti_headless.sh; copies the server log to OUT_DIR, removes the run
# directory and prints the probe's lines plus the summed callback times.
# Run it once on the tree before a mapgen change and once after: the RESULT
# digests must be equal.
#
# Usage: tools/r37_mg/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded to the launcher (default 1).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r37-mg-XXXXXX)"
semaphore="$HOME/projects/grudgelands-orchestration/r37/engine_run.sh"
patch_file="$repo/tools/wp40/profile/instrument-mapgen.patch"
set +e
cd "$repo"
if [[ -x "$semaphore" ]]; then
	SEED="${SEED:-1}" PROBE="$here/grug_probe_r37_mg" GAME_PATCH="$patch_file" ROOT="$root" \
		"$semaphore" r37-mg "$timeout_s" >"$out/headless.txt" 2>&1
else
	SEED="${SEED:-1}" PROBE="$here/grug_probe_r37_mg" GAME_PATCH="$patch_file" ROOT="$root" \
		chrt --idle 0 "$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
fi
boot=$?
set -e
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h 'r37_mg_probe' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
grep -h 'GRUG_WP40_PROFILE_CALLBACK' "$out/server.log" 2>/dev/null >"$out/callbacks.txt" || true
grep -v ' owner ' "$out/probe.txt" || true
awk '{for (i = 1; i <= NF; i++) { split($i, kv, "=");
		if (kv[1] == "plan_us") p += kv[2]; if (kv[1] == "writer_us") w += kv[2] } n++ }
	END { printf "callbacks %d, plan_slice %.3f s, writer %.3f s\n", n, p / 1e6, w / 1e6 }' \
	"$out/callbacks.txt"
if [[ $boot -eq 0 ]] && grep -q 'RESULT owners=' "$out/probe.txt"; then
	echo "r37 mg probe: done"
	exit 0
fi
echo "r37 mg probe: FAIL (boot status $boot)"
exit 1
