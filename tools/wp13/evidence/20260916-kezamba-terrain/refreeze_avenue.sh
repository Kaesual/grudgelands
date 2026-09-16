#!/usr/bin/env bash
# RE-FREEZE KEZAMBA'S AVENUE DIGEST FROM A REAL ENGINE PASS, in one command.
#
#     bash tools/wp13/evidence/20260916-kezamba-terrain/refreeze_avenue.sh [SEED]
#
# WHY IT EXISTS. `run_capital.sh <out> kezamba full <seed>` compares the avenue
# the engine BUILT with the digest committed at
# `tools/wp13/evidence/20260915-capital-terrain/kezamba/avenue-digest-<seed>.txt`,
# and that digest moves whenever the GROUND under the road moves. The
# `cenote_terrace` apron of 2026-09-16 moved it (the road walks the surface the
# seam hands it), and Lane S's piers and rails for the water crossings will move
# it again on the rebase the coordinator does before the merge. Re-taking it by
# hand out of a log is how a wrong value gets committed, so this is the one
# command: boot, read the probe's own digest, refuse anything but a clean pass,
# write the file.
#
# It KEEPS the world directory the runner makes, like every WP13 capital pass,
# and it uses this lane's own port block.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
seed="${1:-531802985935182545}"
out="${WP13_REFREEZE_OUT:-/tmp/grug-w3-K-refreeze-$seed}"
export WP13_CAPITAL_PORT="${WP13_CAPITAL_PORT:-31100}"

rm -rf "$out"
# `|| true`: the runner exits non-zero exactly when the digest differs, which is
# the case this script exists for. Everything else is checked below, from the
# probe's own completion line and error counts.
nice -n 19 bash "$repo/tools/wp13/run_capital.sh" "$out" kezamba full "$seed" || true

grep -q 'event=complete mode=full' "$out/server.log" ||
	{ echo "refreeze: the boot did not complete" >&2; exit 1; }
[[ "$(cat "$out/error-count.txt")" == 0 ]] ||
	{ echo "refreeze: the boot logged ERROR lines" >&2; exit 1; }
[[ "$(cat "$out/moderror-count.txt")" == 0 ]] ||
	{ echo "refreeze: the boot logged ModError lines" >&2; exit 1; }
grep -q 'does not stand on this world' "$out/server.log" &&
	{ echo "refreeze: the load-time terrain audit found a plot" >&2; exit 1; }

line="$(grep '^[0-9a-f]\{64\}  avenue ' "$out/overlay-digests.txt")"
[[ -n "$line" ]] || { echo "refreeze: the pass recorded no avenue digest" >&2; exit 1; }
main="$(git -C "$repo" rev-parse --short HEAD)"
target="$repo/tools/wp13/evidence/20260915-capital-terrain/kezamba/avenue-digest-$seed.txt"
printf '%s main=%s package=%s\n' "$line" "$main" \
	"$(git -C "$repo" rev-parse --abbrev-ref HEAD)" >"$target"
echo "refreeze: wrote $target"
cat "$target"
