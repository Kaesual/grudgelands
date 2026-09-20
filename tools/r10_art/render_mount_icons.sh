#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
scratch=${TMPDIR:-/tmp}/grudgelands-r10-mount-render
rm -rf "$scratch"
mkdir -p "$scratch"
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
export GRUG_ROOT=$root GRUG_MOUNT_RENDER=$scratch
for spec in \
	"horse mods/PLAYER/grug_mounts/models/grug_mounts_horse.b3d" \
	"tiger mods/PLAYER/grug_mounts/models/grug_mounts_tiger.b3d" \
	"ibex mods/ENTITIES/grug_mobs/models/grug_mobs_ibex.b3d" \
	"stag mods/ENTITIES/grug_mobs/models/grug_mobs_stag.b3d" \
	"boar mods/ENTITIES/grug_mobs/models/grug_mobs_boar.b3d" \
	"wolf mods/ENTITIES/grug_mobs/models/grug_mobs_wolf.b3d" \
	"eagle mods/ENTITIES/grug_mobs/models/grug_mobs_eagle.b3d" \
	"bat mods/ENTITIES/grug_mobs/models/grug_mobs_cave_bat.b3d"
do
	set -- $spec
	timeout 20s assimp export "$root/$2" "$scratch/$1.glb" -fglb2 >/dev/null
done
timeout --kill-after=5s 90s blender --background --python \
	"$root/tools/r10_art/render_mount_icons.py"
