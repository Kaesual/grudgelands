#!/usr/bin/env bash
# Round 37 lane IX engine probe (CORE-02): counts the water guard's reverts at
# one capital edge and one coast (grug_probe_r37_ix, staged into a throwaway
# game copy, never shipped). Copies the server log to OUT_DIR, removes the run
# directory and exits 0 only on a clean boot whose probe finished
# ("RESULT DONE"). The same script in a copy of an older tree gives the
# "before" numbers.
#
# Usage: tools/r37_ix/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded (default 12345).
#   LAUNCHER="<command> [args]" replaces tools/luanti_headless.sh, e.g. the
#   round's measuring-run semaphore with its label.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r37-ix-XXXXXX)"
read -r -a launcher <<<"${LAUNCHER:-$repo/tools/luanti_headless.sh}"
set +e
(cd "$repo" && SEED="${SEED:-12345}" PROBE="$here/grug_probe_r37_ix" \
	ROOT="$root" "${launcher[@]}" "$timeout_s") >"$out/headless.txt" 2>&1
code=$?
set -e
cat "$out/headless.txt"
if [[ "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
grep -h 'r37ix_probe' "$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if [[ $code -eq 0 ]] && grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "r37 ix probe: PASS"
	exit 0
fi
echo "r37 ix probe: FAIL (boot status $code)"
exit 1
