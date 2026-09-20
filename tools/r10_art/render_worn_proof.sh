#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd); scratch=${TMPDIR:-/tmp}/grudgelands-r10-worn
rm -rf "$scratch"; mkdir -p "$scratch" "$root/docs/research/r10-visuals/worn"; trap 'rm -rf "$scratch"' EXIT HUP INT TERM
timeout 20s assimp export "$root/mods/BASE/player_api/models/character.b3d" "$scratch/character.glb" -fglb2 >/dev/null
ROOT="$root" SCRATCH="$scratch" python3 - <<'PY'
import os
from PIL import Image
from pathlib import Path
root=Path(os.environ['ROOT']);out=Path(os.environ['SCRATCH']); vis=root/'mods/PLAYER/grug_visuals/textures'
grades={'metal':['bronze','iron','steel','silversteel','embersteel','abyssal_steel'],'cloth':['patch','woven','heavy','silkweave','silk','stormweave'],'leather':['light','cured','heavy','scaled','sleek','nightscale']}
for line,keys in grades.items():
 for n,key in enumerate(keys,1):
  im=Image.open(vis/'grug_visuals_skin_human.png').convert('RGBA')
  for slot in ('head','chest','legs','feet'): im=Image.alpha_composite(im,Image.open(vis/f'grug_visuals_{line}_{slot}_{key}.png').convert('RGBA'))
  im.save(out/f'human_{line}_{n}.png')
PY
export GRUG_ROOT="$root" GRUG_WORN_RENDER="$scratch"
timeout --kill-after=5s 150s blender --background --python "$root/tools/r10_art/render_worn_proof.py"
