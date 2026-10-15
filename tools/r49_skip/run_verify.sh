#!/usr/bin/env bash
# Round 49 lane SKIP: one verification boot. Boots tools/luanti_headless.sh
# on seed 12345 with the disposable patch of verify_patch.py (the full writer
# on every chunk, the VoxelManip compared on every chunk an untouched-chunk
# test would skip) and the probe grug_probe_r49skip (a fixed chunk list),
# then copies the server log and the extracted lines to OUT.
#
# Usage: tools/r49_skip/run_verify.sh OUT
# Environment: TIMEOUT (default 300 s); QUEUE=<script> runs the boot through
#   a queue wrapper that takes a label and then the launcher's arguments (the
#   lane used ~/projects/grudgelands-orchestration/r45/engine_run.sh).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run_verify.sh OUT}"
mkdir -p "$out"
work="$(mktemp -d /tmp/r49skip-verify.XXXXXX)"
trap 'rm -rf "$work"' EXIT
python3 "$here/verify_patch.py" >"$work/verify.patch"
cd "$repo"
launcher=("$repo/tools/luanti_headless.sh")
if [[ -n "${QUEUE:-}" ]]; then launcher=("$QUEUE" "r49-skip-verify"); fi
set +e
env GAME_PATCH="$work/verify.patch" PROBE="$here/probe/grug_probe_r49skip" SEED=12345 KEEP=1 \
	"${launcher[@]}" "${TIMEOUT:-300}" >"$out/headless.txt" 2>&1
boot=$?
set -e
cat "$out/headless.txt"
log="$(sed -n 's/^log: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$log" && -f "$log" ]]; then cp "$log" "$out/server.log"; fi
# The kept run directory (the log is copied): removed, never a glob.
kept="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$kept" && "$kept" == /tmp/grudgelands-headless.?* && -d "$kept" ]]; then
	rm -rf "$kept"
fi
grep -h '\[r49skip' "$out/server.log" >"$out/chunks.txt" 2>/dev/null || true
cat "$out/chunks.txt"
# A skipped chunk passes only when the full writer changed nothing in it.
bad="$(grep -E 'skip=(deep|air) ' "$out/chunks.txt" | grep -vE ' dd=0 dp=0 dl=0 ' || true)"
if [[ -n "$bad" ]]; then echo "skipped chunks that differ:"; echo "$bad"; fi
if [[ $boot -eq 0 && -z "$bad" ]] && grep -q 'RESULT PASS' "$out/chunks.txt"; then
	echo "r49 skip verify: PASS"
	exit 0
fi
echo "r49 skip verify: FAIL (boot status $boot)"
exit 1
