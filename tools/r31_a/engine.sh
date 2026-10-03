#!/usr/bin/env bash
# Round 31 Lane A engine probe: character looks over two boots of one world
# (grug_probe_r31_a, staged into a throwaway game copy, never shipped). Boot 1
# creates a look through the creation step on a player stand-in and reads the
# dwarf start's NPCs; boot 2 reuses the same world (ROOT=) and checks that both
# come back unchanged. Copies the logs to OUT_DIR, removes the run directory
# and exits 0 only on two clean boots with "RESULT PASS" each.
#
# Usage: tools/r31_a/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded to the launcher (default 42).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r31-a-XXXXXX)"
status=0
for boot in 1 2; do
	set +e
	SEED="${SEED:-42}" PROBE="$here/grug_probe_r31_a" ROOT="$root" \
		"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.$boot.txt" 2>&1
	code=$?
	set -e
	cat "$out/headless.$boot.txt"
	[[ $code -eq 0 ]] || status=1
done
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
grep -h 'r31_a_probe' "$out/server.log" "$out/server.2.log" 2>/dev/null |
	tee "$out/probe.txt" || true
passes="$(grep -c 'RESULT PASS' "$out/probe.txt" || true)"
if [[ $status -eq 0 && "$passes" == 2 ]]; then
	echo "r31 a probe: PASS"
	exit 0
fi
echo "r31 a probe: FAIL (boot status $status, $passes passing boots)"
exit 1
