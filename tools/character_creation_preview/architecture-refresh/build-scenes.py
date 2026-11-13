#!/usr/bin/env python3
"""Prepare architecture-current backdrops without touching installed game art."""
import hashlib
import json
from pathlib import Path
import sys
HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent
ROOT = HERE.parents[2]
sys.path.insert(0,str(SOURCE))
import scenery
import native

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

protected = sorted((ROOT/'mods/PLAYER/grug_classes').glob('creation*.lua'))
protected += sorted((ROOT/'mods/PLAYER/grug_classes/textures').glob('grug_creation_*.png'))
before = {str(p.relative_to(ROOT)):sha(p) for p in protected}
scenery.main(HERE/'browser')
native.build(source=HERE/'browser',output=HERE/'native',write_camera=False)
assert before == {str(p.relative_to(ROOT)):sha(p) for p in protected}
for race in ('human','dwarf','elf','orc','troll','undead'):
    old = json.loads((SOURCE/'native/scenes'/f'{race}.json').read_text())
    new = json.loads((HERE/'native/scenes'/f'{race}.json').read_text())
    assert old == new, (race,'composition/camera changed')
report = dict(classification='compatible, tools-only proposal',protected_game_files=before,
              camera_and_composition='all six native scene recipes unchanged',
              source_scene_hashes={p.stem:sha(p) for p in sorted((SOURCE/'scenes').glob('*.json'))})
(HERE/'preparation.json').write_text(json.dumps(report,indent=2)+'\n')
print('Six current-building scenes prepared; native cameras, compositions and game files unchanged.')
