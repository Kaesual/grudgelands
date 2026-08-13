#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$script_dir/digest_lib.sh"

scratch="$(mktemp -d /tmp/grudgelands-wp40-dungeon-digest.XXXXXX)"
cleanup() {
	case "$scratch" in
		/tmp/grudgelands-wp40-dungeon-digest.*) rm -rf -- "$scratch" ;;
		*) echo "refusing unsafe cleanup path: $scratch" >&2 ;;
	esac
}
trap cleanup EXIT INT TERM

mkdir -p "$scratch/one" "$scratch/two"
printf '%s\n' \
	"fixed_map_seed = 40200517" \
	"mg_name = v7" \
	"chunksize = 5" \
	> "$scratch/one/minetest.conf"
cp "$scratch/one/minetest.conf" "$scratch/two/renamed.conf"

game_commit="1111111111111111111111111111111111111111"
probe_digest="2222222222222222222222222222222222222222222222222222222222222222"
engine_regex='^5[.]16[.][0-9]+$'
first="$(wp40_manifest_digest "$game_commit" "$probe_digest" \
	"$engine_regex" "$scratch/one/minetest.conf")"
second="$(wp40_manifest_digest "$game_commit" "$probe_digest" \
	"$engine_regex" "$scratch/two/renamed.conf")"
if [[ "$first" != "$second" ]]; then
	echo "error: identical config content produced path-dependent manifest digests" >&2
	exit 1
fi

printf '%s\n' "water_level = 2" >> "$scratch/two/renamed.conf"
changed="$(wp40_manifest_digest "$game_commit" "$probe_digest" \
	"$engine_regex" "$scratch/two/renamed.conf")"
if [[ "$first" == "$changed" ]]; then
	echo "error: changed config content did not change the manifest digest" >&2
	exit 1
fi

echo "WP40 dungeon manifest digest audit: PASS"
echo "- identical config bytes at different paths have identical digests"
echo "- changed config bytes change the digest"
