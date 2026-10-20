#!/usr/bin/env bash
# Round 53 lane PRIEST engine probe (K13): boots one isolated headless server
# with the disposable probe grug_probe_r53_priest staged (never shipped),
# copies the server log to OUT_DIR, removes the run directory and keeps the
# probe's lines as OUT_DIR/probe.txt. Exits 0 when the probe finished.
#
# Usage (worktree root): tools/r53_priest/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   LAUNCHER replaces ./tools/luanti_headless.sh (e.g. the round's measuring
#   queue, which takes a label first).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
cd "$repo"
set +e
# shellcheck disable=SC2086 # LAUNCHER may carry its own arguments
PROBE="$here/grug_probe_r53_priest" KEEP=1 ${LAUNCHER:-./tools/luanti_headless.sh} \
	"$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r53_priest\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "r53 priest probe: DONE"
	exit 0
fi
echo "r53 priest probe: FAIL (boot status $boot)"
exit 1
