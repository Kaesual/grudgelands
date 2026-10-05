#!/usr/bin/env bash
# Round 37 lane PO engine probe (grug_probe_r37_po, staged into a throwaway
# game copy, never shipped): the Round 32 study's "crowd" scale probe with 50
# and 100 player stand-ins beside the Accord human start, then the 100
# standing still, and micro benchmarks (Claim Stone placement, discovery
# scan, tracker key, marker memo). Copies the server log to OUT_DIR, removes
# the run directory and exits 0 only on a clean boot whose probe finished
# ("RESULT DONE").
#
# Usage: tools/r37_po/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded (default 12345, the study's seed).
#   LAUNCHER="<command> [args]" replaces tools/luanti_headless.sh, e.g. the
#   round's measuring-run queue with its label.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-360}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r37-po-XXXXXX)"
# The probe's settings, as a patch to the staged game's minetest.conf.
patchdir="$(mktemp -d)"
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
cat >>"$patchdir/b/minetest.conf" <<'EOF'

# Round 37 lane PO probe (crowd scenario of the Round 32 study)
max_forceloaded_blocks = 1500
r37po_fakes1 = 50
r37po_fakes2 = 100
r37po_scenario = crowd
r37po_still_s = 30
EOF
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true
read -r -a launcher <<<"${LAUNCHER:-$repo/tools/luanti_headless.sh}"
set +e
(cd "$repo" && SEED="${SEED:-12345}" PROBE="$here/grug_probe_r37_po" \
	GAME_PATCH="$patchdir/probe.patch" ROOT="$root" "${launcher[@]}" "$timeout_s") \
	>"$out/headless.txt" 2>&1
code=$?
set -e
rm -rf "$patchdir"
cat "$out/headless.txt"
if [[ "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
grep -ah '\[r37po\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
if [[ $code -eq 0 ]] && grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "r37 po probe: PASS"
	exit 0
fi
echo "r37 po probe: FAIL (boot status $code)"
exit 1
