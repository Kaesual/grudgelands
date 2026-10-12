#!/usr/bin/env bash
# Round 46 lane PL engine probe: placed POIs on a real world
# (grug_probe_r46_pl, staged into a throwaway game copy, never shipped).
# Boots one isolated headless server through tools/luanti_headless.sh, or two
# on the same world (BOOTS=2: the second a layout-cache hit), copies the
# server logs and the probe lines to OUT_DIR, removes the run directory and
# exits 0 only on clean boots that each end in "RESULT PASS".
#
# Usage: tools/r46_pl/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> (default 8507030740356938342: the Accord fortress
#   and Copperfell Village; any other seed: a war camp, a mine and a clash
#   site's quest place). BOOTS=1|2 (default 1).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
boots="${BOOTS:-1}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r46-pl-XXXXXX)"
status=0
for boot in $(seq 1 "$boots"); do
	set +e
	SEED="${SEED:-8507030740356938342}" PROBE="$here/grug_probe_r46_pl" ROOT="$root" \
		"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.$boot.txt" 2>&1
	rc=$?
	set -e
	# the launcher writes one log per boot: server.log, then server.2.log
	log="$root/server.log"; [[ $boot -gt 1 ]] && log="$root/server.$boot.log"
	cp "$log" "$out/server.$boot.log" 2>/dev/null || true
	grep -h 'r46_pl_probe\|world layouts:\|POI placement:' "$out/server.$boot.log" \
		>"$out/probe.$boot.txt" 2>/dev/null || true
	cat "$out/probe.$boot.txt"
	if [[ $rc -ne 0 ]] || ! grep -q 'RESULT PASS' "$out/probe.$boot.txt"; then status=1; fi
done
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.r46-pl-?* && -d "$root" ]]; then
	rm -rf "$root"
fi
if [[ $status -eq 0 ]]; then echo "r46 pl probe: PASS"; else echo "r46 pl probe: FAIL"; fi
exit $status
