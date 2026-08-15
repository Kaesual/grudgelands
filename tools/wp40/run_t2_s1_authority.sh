#!/usr/bin/env bash
set -euo pipefail

# A missing rg would make every check below pass vacuously: exit status 127 in
# an `if` condition reads exactly like "no match found". Fail loudly instead.
command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}

# Stage-S1 scope gate.  It proves that the E0 pool authority reads exactly the
# Source surface stage S1 reads, so a later-stage geometry correction inside
# source/catalog.lua can no longer invalidate a measured scalar pool.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
scratch="$(mktemp -d -p /tmp grudgelands-wp40-s1-authority.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-s1-authority.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

owned_lua=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua"
	"$repo/tools/wp40/t2_s1_authority.lua"
	"$repo/tools/wp40/t2_s1_authority_test.lua"
)
"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T2 S1 authority global write in $file" >&2
		exit 1
	fi
done

"$repo/tools/bin/lua51" "$script_dir/t2_s1_authority_test.lua" "$repo" "$scratch"
bash -n "$script_dir/run_t2_s1_authority.sh"
echo "WP40 T2 S1 authority gates passed"
