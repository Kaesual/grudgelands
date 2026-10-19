#!/usr/bin/env bash
# Round 52 CORE-A PvE bench: boots one isolated headless server on a game tree
# with the disposable probe grug_probe_r52_bench staged (never shipped), copies
# the server log to OUT_DIR, removes the run directory and keeps the probe's
# action log as OUT_DIR/probe.txt. Exits 0 when the probe finished.
#
# Usage: tools/r52_bench/run.sh OUT_DIR [TREE] [TIMEOUT_SECONDS]
#   TREE is the game checkout to boot (default: this repository). For a
#   "before" run export the base commit, never check it out:
#     mkdir DIR && git archive <commit> | tar -x -C DIR
#   LAUNCHER is the command that boots TREE's headless launcher from TREE's
#   root with the timeout as its argument (default ./tools/luanti_headless.sh),
#   e.g. a shared measuring queue.
# Then: python3 tools/r52_bench/compare.py BEFORE/probe.txt AFTER/probe.txt
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TREE] [TIMEOUT_SECONDS]}"
tree="$(cd "${2:-$repo}" && pwd -P)"
timeout_s="${3:-300}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
cd "$tree"
set +e
# shellcheck disable=SC2086 # LAUNCHER may carry its own arguments
PROBE="$here/grug_probe_r52_bench" KEEP=1 ${LAUNCHER:-./tools/luanti_headless.sh} \
	"$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r52_bench\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "r52 bench: DONE ($(grep -c '\] R ' "$out/probe.txt") records)"
	exit 0
fi
echo "r52 bench: FAIL (boot status $boot)"
exit 1
