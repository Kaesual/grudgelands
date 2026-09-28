#!/usr/bin/env bash
# One bounded engine run that dumps the render boxes of
# probe/r23_dump/boxes.txt from a fresh, isolated world (the guarantees of
# tools/luanti_headless.sh: own user path, LC_ALL=C, idle scheduling, normal
# shutdown requested by the probe).
#
# Usage: tools/r23_tree_line/run_dump.sh OUT_DIR [TIMEOUT_S]
#   GAME_REPO=<tree>  the checkout whose game is staged (default: this one);
#                     a "before" run points it at an exported main tree
#   SEED=<n>          world seed (default 4242)
#   VERIFY_REGION=X_MIN,X_MAX,Z_MIN,Z_MAX  also prepare that region's full
#                     tile columns with the Round 23 fast-path verify patch
#                     (tools/r23_full_column/make_patch.py --verify: the full
#                     writer runs on every chunk and every chunk the fast path
#                     would skip is compared before/after); the probe dumps
#                     once the region is prepared
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="${GAME_REPO:-$(cd "$here/../.." && pwd -P)}"
out="${1:?output directory}"
timeout_s="${2:-330}"
mkdir -p "$out"
patch_args=()
if [[ -n "${VERIFY_REGION:-}" ]]; then
	python3 "$repo/tools/r23_full_column/make_patch.py" --region "$VERIFY_REGION" \
		--stop-after "$timeout_s" --verify >"$out/game.patch"
	patch_args=(GAME_PATCH="$out/game.patch")
fi
root="$(mktemp -d /tmp/grudgelands-headless.XXXXXX)"
cleanup() { rm -rf "$root"; }
trap cleanup EXIT
set +e
env ROOT="$root" SEED="${SEED:-4242}" PROBE="$here/probe/r23_dump" "${patch_args[@]}" \
	chrt --idle 0 ionice -c3 "$repo/tools/luanti_headless.sh" "$timeout_s" \
	| tee "$out/launcher.txt"
status=${PIPESTATUS[0]}
set -e
cp "$root"/world/r23_dump_*.tsv "$out/" 2>/dev/null || true
cp "$root"/server*.log "$out/" 2>/dev/null || true
grep -h '\[r23d\]\|ERROR' "$root"/server*.log >"$out/probe.log" 2>/dev/null || true
cat "$out/probe.log"
exit "$status"
