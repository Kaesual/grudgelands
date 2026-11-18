#!/usr/bin/env bash
# Round 82 lane BASE: one engine measurement of the fixed region on a fresh
# world (seed 12345). Boots tools/luanti_headless.sh with the disposable
# probe grug_probe_r82_region (staged only, with region.txt beside it; no
# game patch), which waits for the world preparation, generates the
# region's chunks one at a time, hashes them read back from the map and
# shuts the server down. Writes to OUT: headless.txt (the launcher's
# output), region.log (the probe's lines) and summary.txt (the time to a
# ready world, the generation totals, the region hashes).
#
#   tools/r82_gen/region.sh OUT [LIMIT]
#     LIMIT  only the first LIMIT chunks of region.txt (development boots)
# Environment: QUEUE=<script> the launcher wrapper (default the measuring
#   queue ~/projects/grudgelands-orchestration/r45/engine_run.sh with the
#   label r82-region; the plain launcher when it is missing), TIMEOUT
#   (default 330 s). Run from the repository root of the tree to measure.
# Compare two runs: diff <(grep '^hash' A/summary.txt) <(grep '^hash' B/summary.txt)
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: region.sh OUT [LIMIT]}"
limit="${2:-}"
[[ -z "$limit" || "$limit" =~ ^[1-9][0-9]*$ ]] || { echo "LIMIT must be a count" >&2; exit 2; }
mkdir -p "$out"
probe_dir="$(mktemp -d /tmp/r82-region-probe.XXXXXX)"
trap 'rm -rf "$probe_dir"' EXIT
cp -a "$here/grug_probe_r82_region" "$probe_dir/"
grep -v '^#' "$here/region.txt" | head -n "${limit:-100000}" \
	>"$probe_dir/grug_probe_r82_region/region.txt"
cd "$repo"
queue="${QUEUE:-$HOME/projects/grudgelands-orchestration/r45/engine_run.sh}"
launcher=("$repo/tools/luanti_headless.sh")
[[ -x "$queue" ]] && launcher=("$queue" r82-region)
set +e
env PROBE="$probe_dir/grug_probe_r82_region" KEEP=1 SEED=12345 \
	"${launcher[@]}" "${TIMEOUT:-330}" >"$out/headless.txt" 2>&1
boot=$?
set -e
kept="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
log="$(sed -n 's/^log: //p' "$out/headless.txt" | tail -n 1)"
launch=""
[[ -n "$kept" && -f "$kept/server.conf" ]] && launch="$(stat -c %Y "$kept/server.conf")"
if [[ -n "$log" && -f "$log" ]]; then
	grep -h '\[r82_region\] ' "$log" | sed 's/^.*\[r82_region\] //' >"$out/region.log" || true
fi
if [[ -n "$kept" && "$kept" == /tmp/grudgelands-headless.?* && -d "$kept" ]]; then
	rm -rf "$kept"
fi
{
	echo "boot status $boot; $(grep -c '^chunk ' "$out/region.log" 2>/dev/null || echo 0) chunks requested"
	prep="$(grep '^prep ready' "$out/region.log" || true)"
	if [[ -n "$prep" && -n "$launch" ]]; then
		epoch="$(sed -n 's/.*epoch=\([0-9]*\).*/\1/p' <<<"$prep")"
		echo "ready world: $((epoch - launch)) s from launch (+-1 s); $prep"
	fi
	grep -h '^gen \|^region \|^RESULT' "$out/region.log" || true
	grep -h ' NOT_FRESH' "$out/region.log" || true
	grep -h '^hash ' "$out/region.log" || true
} >"$out/summary.txt"
grep -v '^hash ' "$out/summary.txt"
if [[ $boot -eq 0 ]] && grep -q '^RESULT PASS' "$out/region.log"; then
	echo "region run: PASS"
	exit 0
fi
echo "region run: FAIL (boot status $boot)"
exit 1
