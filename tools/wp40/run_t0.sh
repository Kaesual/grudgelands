#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
tmp_dir="$(mktemp -d -p /tmp grudgelands-wp40-t0-audit.XXXXXXXX)"
cleanup() {
	if [[ "$tmp_dir" == /tmp/grudgelands-wp40-t0-audit.* ]]; then
		rm -rf -- "$tmp_dir"
	fi
}
trap cleanup EXIT

"$repo/tools/wp43/run.sh"
"$repo/tools/bin/lua51" "$script_dir/wp43_projection_test.lua" "$repo" \
	"$tmp_dir/wp43-projection-audit.tsv"
"$script_dir/source_audit.sh" "$repo"

"$repo/tools/bin/luac51" -p \
	"$repo/mods/MAPGEN/grug_mapgen/wp43_handoff.lua" \
	"$script_dir/wp43_projection_test.lua" \
	"$script_dir/runtime_probe/init.lua"

bash -n "$script_dir/collect_host.sh" \
	"$script_dir/capture_t0_baseline.sh" \
	"$script_dir/source_audit.sh" \
	"$script_dir/run_t0.sh"

echo "WP40 T0 projection audit SHA-256: $(sha256sum \
	"$tmp_dir/wp43-projection-audit.tsv" | awk '{print $1}')"

if [[ "${WP40_CAPTURE_BASELINE:-0}" == "1" ]]; then
	"$script_dir/capture_t0_baseline.sh"
else
	echo "WP40 T0 headless capture skipped; set WP40_CAPTURE_BASELINE=1 to run it"
fi

echo "WP40 T0 local gates passed"
