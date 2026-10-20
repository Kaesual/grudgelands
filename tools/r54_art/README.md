# The picked armor art (Round 54)

The armor art the game ships, in the format of
[armor-format.md §6](../../docs/technical/armor-format.md#6-painted-art), and where it comes from. Lane INTEG
of Round 54 ([plan](../../docs/planning/round54-plan.md)).

- `art/`: the art directory `tools/r54_armor/bake.py` bakes by default (`tiers.json`, `palettes.json`,
  `metal/`, `leather/`, `cloth/`: box sheets, inner paint and icons in the reference palette; 264 PNG files).
- `src/<drop>/paint.py`: the painters of the three art drops the user picked from, unchanged as delivered.
  Own work, AI-assisted, by **GPT-6 Astra**, CC0 1.0: deterministic Python/Pillow pixel authorship that reads
  only the contract's catalog and blank templates (`tools/r54_armor/`). Each painter writes the two proposals
  `p1` and `p2` of its drop; variants `a` … `f` are tiers T1 … T6.
  - `drop-02`: metal (p1 "Bastion", p2 "Processional guard");
  - `drop-03-leather`: leather;
  - `drop-03-cloth`: cloth.
- `picks.json`: the user's picks of 2026-10-20, whole tiers: metal T1–T5 from `drop-02` p1 and T6 from
  `drop-02` p2, leather all from `drop-03-leather` p1, cloth all from `drop-03-cloth` p1.
- `assemble.py`: runs the painters on copies in a temporary directory and copies, per line and tier, every
  file the picked proposal's `tiers.json` entry names into `art/`; `art/tiers.json` gets the picked tier
  entries (the picks under `_source`), `art/palettes.json` their palettes.
- `ghosts.py`: the Character page's four empty-slot ghosts `grug_gear_item_<slot>_metal.png`
  (`grug_inventory/pages.lua` darkens them), copies of the baked metal T3 (steel) icons; `--check`.
- `scene.lua`: the capture scene of this lane for `tools/r54_model/capture.sh` (`SCENE=`): the three lines at
  T1, T3 and T6 on two races standing and walking, an enchanted and a broken piece, armored NPCs and the
  inventory icons in a grid, all composed by the game itself.

```sh
python3 tools/r54_art/assemble.py --check   # art/ equals painters + picks (pixels, JSON content); exit 1 if not
python3 tools/r54_art/assemble.py           # rewrite art/
python3 tools/r54_armor/check.py --art tools/r54_art/art      # the contract's rule check (0 violations)
python3 tools/r54_armor/bake.py --icons-out mods/ITEMS/grug_gear/textures --check   # the shipped game files
python3 tools/r54_art/ghosts.py --check     # the four slot ghosts
```

To change a piece: change its painter (or the picks), run `assemble.py`, `check.py`, then `bake.py` with
`--icons-out` as above (without `--check`) and `ghosts.py`, and commit the art and the baked files together.
