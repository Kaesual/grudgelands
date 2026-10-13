#!/usr/bin/env bash
# Round 47 lane FS engine probe: the furnace loop on the real engine paths
# (grug_probe_r47_fs, staged into a throwaway game copy, never shipped).
# Copies the server log to OUT_DIR, removes the run directory and exits 0
# only on a clean boot whose probe passed ("RESULT PASS").
#
# Usage: tools/r47_fs/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded (default 12345).
#   LAUNCHER="<command> [args]" replaces tools/luanti_headless.sh, e.g. the
#   round's queue with its label.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-120}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r47-fs-XXXXXX)"
read -r -a launcher <<<"${LAUNCHER:-$repo/tools/luanti_headless.sh}"
set +e
(cd "$repo" && SEED="${SEED:-12345}" PROBE="$here/grug_probe_r47_fs" \
	ROOT="$root" "${launcher[@]}" "$timeout_s") >"$out/headless.txt" 2>&1
code=$?
set -e
cat "$out/headless.txt"
if [[ "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
grep -h 'r47fs_probe' "$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if [[ $code -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r47 fs probe: PASS"
	exit 0
fi
echo "r47 fs probe: FAIL (boot status $code)"
exit 1
