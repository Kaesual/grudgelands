#!/usr/bin/env bash
# Refresh tools/building_templates/nodes.json from the real node registry: one
# isolated headless boot (tools/luanti_headless.sh) with the disposable probe
# grug_template_node_dump staged, then normalize.py, then the run directory is
# removed. One engine boot: run it through the shared Lua queue when one is in
# use. Usage: tools/building_templates/node_dump/refresh.sh [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../../.." && pwd -P)"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
set +e
KEEP=1 PROBE="$here/grug_template_node_dump" \
	"$repo/tools/luanti_headless.sh" "${1:-240}" | tee "$log"
set -e
root="$(sed -n 's/^kept: //p' "$log" | tail -n 1)"
[[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* ]] || {
	echo "no kept run directory in the boot output" >&2; exit 1; }
raw="$root/world/template_nodes.json"
if [[ ! -s "$raw" ]]; then
	echo "the probe wrote no dump: $raw (run kept for inspection)" >&2
	exit 1
fi
python3 "$here/normalize.py" "$raw" "$repo/tools/building_templates/nodes.json"
rm -rf -- "$root"
