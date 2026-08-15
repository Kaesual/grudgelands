#!/usr/bin/env bash
set -euo pipefail

# A missing rg would make every check below pass vacuously: exit status 127 in
# an `if` condition reads exactly like "no match found". Fail loudly instead.
command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
scratch="$(mktemp -d -p /tmp grudgelands-wp40-t1.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t1.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

"$script_dir/verify_t1_sha.sh"
"$script_dir/t1_source_audit.sh" "$repo"
"$repo/tools/bin/lua51" "$script_dir/t1_foundation_test.lua" "$repo" "$scratch"

mapfile -t changed_lua < <(find "$repo/mods/MAPGEN/grug_mapgen/wp40" \
	-type f -name '*.lua' -print | sort)
changed_lua+=("$repo/tools/wp40/t1_foundation_test.lua")
"$repo/tools/bin/luac51" -p "$repo/mods/MAPGEN/grug_mapgen/init.lua" \
	"${changed_lua[@]}"

for file in "${changed_lua[@]}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T1 global write in $file" >&2
		exit 1
	fi
done

bash -n "$script_dir/run_t1.sh" "$script_dir/verify_t1_sha.sh" \
	"$script_dir/t1_source_audit.sh"
echo "WP40 T1 local gates passed"
