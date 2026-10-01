#!/usr/bin/env bash
# Round 28 Lane C0 engine probe for the zone facts atlas: settlement sockets,
# quest givers, quests, mob casts and spawn levels, camp/rare registries and
# the settlement core boxes, dumped as one JSON file. No world is emerged.
#
# Usage: tools/r28_zone_atlas/probe.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED (default 42) pins the world seed. Writes OUT_DIR/probe.json, the
#   server log and the probe's log lines.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: probe.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
set +e
SEED="${SEED:-42}" PROBE="$here/grug_probe_r28_zone_atlas" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	find "$root" -name r28_zone_atlas_probe.json -exec cp {} "$out/probe.json" \;
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r28_zone_atlas_probe\]' "$out"/server*.log 2>/dev/null |
	tee "$out/probe.txt" || true
if grep -q 'RESULT PASS' "$out/probe.txt" && [[ -s "$out/probe.json" ]]; then
	echo "r28 zone atlas probe: PASS (boot status $boot)"
	exit 0
fi
echo "r28 zone atlas probe: FAIL (boot status $boot)"
exit 1
