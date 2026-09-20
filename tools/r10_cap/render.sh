#!/usr/bin/env bash
# Native reproducible diagnostics, never generated production media.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
out="${1:?absolute fresh output directory required}"
[[ "$out" == /* && ! -e "$out" ]] || exit 2
mkdir -p "$out"
export LC_ALL=C GRUG_ROOT="$repo" GRUG_CAP_RENDER="$out"
export XDG_CONFIG_HOME="$out/config" XDG_CACHE_HOME="$out/cache"
run=(nice -n 19 chrt --idle 0 ionice -c3)
"${run[@]}" luajit "$repo/tools/r10_cap/mount_catalog.lua" "$repo" >"$out/catalog.tsv"
"${run[@]}" luajit "$repo/tools/r10_cap/stable_geometry.lua" "$repo" >"$out/stables.tsv"
"${run[@]}" luajit "$repo/tools/r10_cap/stable_geometry.lua" "$repo" all >"$out/all-services.tsv"
"${run[@]}" luajit "$repo/tools/r10_cap/decor_geometry.lua" "$repo" >"$out/decor.tsv"
"${run[@]}" luajit "$repo/tools/r10_cap/gear_visuals.lua" "$repo" >"$out/gear.tsv"
"${run[@]}" python3 "$repo/tools/r10_cap/clearance.py" "$repo" "$out" >"$out/clearance.log"
"${run[@]}" python3 "$repo/tools/r10_cap/prepare_views.py" "$repo" "$out" >"$out/prepare.log"
"${run[@]}" python3 "$repo/tools/r10_cap/render_gear_bindings.py" "$out"
"${run[@]}" timeout 180 blender -b -t 2 --python "$repo/tools/r10_cap/render_poses.py" >"$out/poses.log" 2>&1
"${run[@]}" timeout 180 blender -b -t 2 --python "$repo/tools/r10_cap/render_rooms.py" >"$out/rooms.log" 2>&1
