# The picked offhand art (Round 55)

The shield, spellbook and Supporter Cloak art the game ships, in the format of
[offhand-format.md §6](../../docs/technical/offhand-format.md#6-painted-art), and where it comes from. Lane
FINISH of Round 55 ([plan](../../docs/planning/round55-plan.md)).

- `art/`: the art directory `tools/r55_offhand/bake.py` bakes by default (`tiers.json`, `palettes.json`,
  `shield/`, `book/`, `icons/` in the reference palette, `cloak_supporter.png`, `wings_supporter.png`; 56 PNG
  files).
- `src/drop-01/paint.py` and `src/drop-01/inputs.json`: the painter of the art drop the user picked from and the
  contract snapshot it reads (the sheet sizes, the shield's opaque texels, the Round 54 metal palettes), unchanged
  as delivered. **Licence:** own work, AI-assisted, by **GPT-6 Astra**, **CC0 1.0**
  (<https://creativecommons.org/publicdomain/zero/1.0/>): deterministic Python/Pillow pixel authorship, no
  image-generation service, downloads or third-party source pixels; the icons are drawn freely, not adapted. The
  painter writes two proposals, `p1` "Standard & Ledger" and `p2` "Brace & Seal"; variants `a` … `f` are tiers
  T1 … T6.
- `picks.json`: the user's picks of 2026-10-21, paint and icon chosen separately per item and tier: shields T1–T3
  from p2 and T4–T6 from p1 (paint and icon alike); spellbook paint T1, T2, T4–T6 from p1 and T3 from p2, every
  spellbook icon from p2; the Supporter Cloak (with its wings) from p1.
- `assemble.py`: runs the painter on a copy in a temporary directory and assembles the picks into `art/`. Both
  proposals use the same palette names with different colours, so the assembled palettes carry the proposal as a
  prefix (`p1_bronze`, `p2_book_iron`, …). Per item and tier: the paint proposal's sheets and palette, the icon
  proposal's icon, and, when the two differ, `icon_palette` = the icon proposal's palette for that tier, so every
  icon shows exactly as on the pick page. The drop's `notes.md` is not art and stays out; `art/tiers.json` records
  the picks under `_source`.
- `scene.lua`: the capture scene of this lane for `tools/r55_game/capture.sh` (`SCENE=tools/r55_art/scene.lua
  ART=tools/r55_art/art OFFHAND=true|false`): shields and books at T1, T3 and T6, the Scout's back card, the
  Supporter Cloak with its wings granted through the real `/achievement grant`, the Character tab, and the twelve
  icons plain, enchanted and broken, all composed by the game itself.

```sh
python3 tools/r55_art/assemble.py --check   # art/ equals painter + picks (pixels, JSON content); exit 1 if not
python3 tools/r55_art/assemble.py           # rewrite art/
python3 tools/r55_offhand/bake.py --icons-out mods/ITEMS/grug_gear/textures --check   # the shipped game files
python3 tools/r55_offhand/render.py --art tools/r55_art/art --out OUT   # the look on the game's model
```

The game files: `bake.py` writes the offhand atlas layers `grug_offhand_{shield,book}_<grade>.png` (and masks)
into `mods/PLAYER/grug_visuals/textures` and the item icons `grug_gear_shield_<grade>.png`,
`grug_gear_spellbook_<grade>.png` (and masks) into `mods/ITEMS/grug_gear/textures`. The cloak and its wings are
not baked: they are copied as `grug_achievements_cloak_supporter.png` and
`grug_achievements_cloak_supporter_wings.png` into `mods/PLAYER/grug_achievements/textures` by `assemble.py`
itself (its `--check` compares them too).

To change a piece: change the painter (or the picks), run `assemble.py`, then `bake.py` with `--icons-out` as
above (without `--check`), and commit the art and the game files together.
