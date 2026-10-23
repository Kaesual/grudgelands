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
- `src/icons-drop-01/paint.py`, `src/icons-drop-02/paint.py`: the painters of the two **icon drops** of
  Round 55 (lane ICONS), the 72 armor icons redrawn simpler, same author and licence (GPT-6 Astra, CC0 1.0).
  `icons-drop-01` paints all 72 icons in two proposals (p1 "Cut-paper heraldry", p2 "Equipment in the hand");
  `icons-drop-02`, drawn after the user's feedback on drop 01 (helmets must read as helmets, boots as boots,
  trousers need a trouser shape), paints the 54 icons of the nine rows not kept, in two proposals (p1
  "Everyday silhouettes", p2 "Profile heads and robe dress"). Unchanged as delivered but for one adaptation
  each: they read the picked `tiers.json` from a hard-coded path in the user's home checkout, so they take an
  optional `--art <dir>` (three added lines and `import sys`, marked in the file).
- `src/hood-drop-02/`: the **hood drop** of Round 56 (HOODART drop 02), same author and licence (GPT-6 Astra,
  CC0 1.0), as delivered: `build.py`, its inputs `source.zip` (the snapshot of `art/` it painted on, the hood's
  schema, blank and reference palette, and the hashes of `tools/r56_hood/views.py` and
  `tools/r54_armor/data/catalog.json`: a change to either stops the build) and `source-sha256.json`, and
  `views/p2/<line>/T<n>/side.png`, `back.png`, `top.png`, the picked proposal's painted views. It paints each hood
  in the three views and projects them with `tools/r56_hood/views.py` (`--game` = this checkout), and writes both
  proposals (p1 "Quiet crown", p2 "Turned edge") as complete art directories: the snapshot plus the 12 hood
  sheets, `hood` in the cloth and leather `on` lists, and one zone B pixel (sheet 14, 11) on the leather
  `helm_a` and `helm_c`. A hood drop carries a snapshot of the art: a later repaint of a cloth or leather tier
  needs a new hood drop (or a hood overlay in `assemble.py`).
- `picks.json`: the user's picks of 2026-10-20, whole tiers: metal T1–T5 from `drop-02` p1 and T6 from
  `drop-02` p2, leather all from `drop-03-leather` p1, cloth all from `drop-03-cloth` p1; since 0.56.1
  (2026-10-22) cloth and leather T1–T6 from `hood-drop-02` p2 (the same tiers with the hood). Its `icons`
  section holds the icon picks of 2026-10-21 per line, slot and tier, whole rows: metal chest, metal legs and
  leather chest from `icons-drop-01` p1 (kept from drop 01); from `icons-drop-02` metal head p1, metal feet
  p2, leather head p1, leather legs p1, leather feet p2, cloth head p2, cloth chest p1, cloth legs p1, cloth
  feet p2.
- `assemble.py`: runs the art painters on copies in a temporary directory and copies, per line and tier, every
  file the picked proposal's `tiers.json` entry names into `art/`; `art/tiers.json` gets the picked tier
  entries (the art picks under `_source`; the icon picks stay out), `art/palettes.json` their palettes. Then
  it runs the icon painters (`--art` = the picked `tiers.json`) and lays each picked icon over its tier's icon
  file, under the same name, so the icons keep their file names and their tier palettes. The hood drop runs
  like the art painters (its `build.py`); `--check` also compares the kept views of a picked hood proposal with
  the painter's.
- **The chin strip** (Round 56 ruling 17): `assemble.py` clears the helm front face's bottom row on the helm sheet
  of every cloth tier and of leather T1–T5 after the tier copy (leather T6, the veil, and metal keep theirs), so
  the painters stay as delivered. A future painter that leaves the strip open itself is unaffected. With the strip
  open, leather T1 and T3 showed 2 zone B pixels from the front instead of 3 (a `check.py` warning) until the
  hood drop added one on each helm: the shipped art has no warning. Since Round 57 (ruling 24) it also clears
  the strip's continuation under the chin, the helm bottom face's rows in front of the neck
  (`armorlib.chin_under`), on the same sheets.
- `ghosts.py`: the Character page's four empty-slot ghosts `grug_gear_item_<slot>_metal.png`
  (`grug_inventory/pages.lua` darkens them), copies of the baked metal T3 (steel) icons; `--check`. Since
  the icon drops: head from `icons-drop-02` p1, chest and legs from `icons-drop-01` p1, feet from
  `icons-drop-02` p2.
- `scene.lua`: the capture scene of this lane for `tools/r54_model/capture.sh` (`SCENE=`): the three lines at
  T1, T3 and T6 on two races standing and walking, an enchanted and a broken piece, armored NPCs and the
  inventory icons in a grid, all composed by the game itself.
- `icons_scene.lua`: Round 55 lane ICONS's capture scene for `tools/r55_game/capture.sh` (`SCENE=tools/r54_art/icons_scene.lua
  ART=tools/r55_art/art`): the 72 armor icons as the game draws them (large, about 32 and 16 px), each line's T3
  pieces enchanted and broken, the four slot ghosts, and the Character tab of an unarmored Warrior and Mage.

```sh
python3 tools/r54_art/assemble.py --check   # art/ equals painters + picks (pixels, JSON content); exit 1 if not
python3 tools/r54_art/assemble.py           # rewrite art/
python3 tools/r54_armor/check.py --art tools/r54_art/art      # the contract's rule check (0 violations)
python3 tools/r54_armor/bake.py --icons-out mods/ITEMS/grug_gear/textures --check   # the shipped game files
python3 tools/r54_art/ghosts.py --check     # the four slot ghosts
```

To change a piece: change its painter (or the picks), run `assemble.py`, `check.py`, then `bake.py` with
`--icons-out` as above (without `--check`) and `ghosts.py`, and commit the art and the baked files together.
