#!/usr/bin/env bash
# One bounded Round 23 full-column preparation run on a fresh, isolated world
# (tools/luanti_headless.sh guarantees). See README.md for the region and the
# numbers it records.
#
# Usage: tools/r23_full_column/run_region.sh X_MIN,X_MAX,Z_MIN,Z_MAX STOP_AFTER_S \
#            [--verify] [--geo]
#   OUT=<dir>   where the log, samples, patch and summary go
#               (default /tmp/r23-full-column-<epoch>)
#   SEED=<n>    world seed (forwarded to the launcher)
#   KEEP=1      keep the world directory afterwards
#   ROOT=<dir>  boot again on a kept world (resume); it is kept as well
# The probe requests a normal shutdown from a server step after STOP_AFTER_S
# seconds (or when the region is complete); the launcher's timeout is only a
# safety net 150 s later.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
region="${1:?region X_MIN,X_MAX,Z_MIN,Z_MAX}"
stop_after="${2:?stop-after seconds}"
shift 2
out="${OUT:-/tmp/r23-full-column-$(date +%s)}"
mkdir -p "$out"
python3 "$here/make_patch.py" --region "$region" --stop-after "$stop_after" "$@" \
	>"$out/game.patch"
# ROOT=<a kept run directory> takes a second boot on the same world (resume).
root="${ROOT:-$(mktemp -d /tmp/grudgelands-headless.XXXXXX)}"
echo "root: $root  out: $out"
sampler() {
	set +e +o pipefail # a missing file or process is a zero sample, not an exit
	local pid rss db
	printf 'epoch_s\trss_kb\tdb_bytes\n' >"$out/samples.tsv"
	while :; do
		pid="$(pgrep -f "^luanti.bin --server --gameid grudgelands --world $root/world" | head -1 || true)"
		rss=0
		if [[ -n "$pid" && -r "/proc/$pid/status" ]]; then
			rss="$(awk '/^VmRSS:/ {print $2}' "/proc/$pid/status")"
		fi
		db="$(du -cb "$root"/world/map.sqlite* 2>/dev/null | awk 'END {print $1+0}')"
		printf '%s\t%s\t%s\n' "$(date +%s.%N)" "${rss:-0}" \
			"${db:-0}" >>"$out/samples.tsv"
		sleep 5
	done
}
sampler &
sampler_pid=$!
cleanup() {
	kill "$sampler_pid" 2>/dev/null || true
	find "$root" -maxdepth 1 -name "server*.log" -newer "$out/game.patch" -exec cp -t "$out/" {} + 2>/dev/null || true
	du -cb "$root"/world/map.sqlite* 2>/dev/null | awk 'END {print $1+0}' >"$out/final_db_bytes"
	if [[ "${KEEP:-0}" != "1" && -z "${ROOT:-}" ]]; then rm -rf "$root"; else echo "kept: $root"; fi
}
trap cleanup EXIT
set +e
ROOT="$root" PROBE="$here/probe/r23_region" GAME_PATCH="$out/game.patch" \
	chrt --idle 0 ionice -c3 "$repo/tools/luanti_headless.sh" "$((stop_after + 150))" \
	| tee "$out/launcher.txt"
set -e
kill "$sampler_pid" 2>/dev/null || true
find "$root" -maxdepth 1 -name "server*.log" -newer "$out/game.patch" -exec cp -t "$out/" {} + 2>/dev/null || true
du -cb "$root"/world/map.sqlite* 2>/dev/null | awk 'END {print $1+0}' >"$out/final_db_bytes"
python3 "$here/analyze.py" "$out" | tee "$out/summary.txt"
