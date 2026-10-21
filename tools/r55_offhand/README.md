# Offhand contract and tools (Round 55)

The offhand look's contract ([docs/technical/offhand-format.md](../../docs/technical/offhand-format.md), the
source of truth; [plan](../../docs/planning/round55-plan.md)). `params.json`, `offhand.py` and
`data/atlas.json` change only through the round's coordinator or the finish step.

| File | What |
|---|---|
| `params.json` | every number of the look (shapes, placements, bone pivots and per-clip keys), exported by the preview page |
| `offhand.py` | the contract in code: validation, the rotation convention, the shapes, the atlas packing, the file names; `--check` |
| `data/atlas.json` | the offhand atlas layout (generated) |
| `make_test_art.py`, `test_art/` | flat-colour test art with zones and orientation glyphs; baked only into a test-only mod, never shipped |

```sh
python3 tools/r55_offhand/offhand.py            # validate params.json, rewrite data/atlas.json
python3 tools/r55_offhand/offhand.py --check    # exit 1 if invalid or stale
python3 tools/r55_offhand/make_test_art.py      # rewrite test_art/
```

Python 3; Pillow for the test art and `--png`.

## Bake: art to game textures

`bake.py` (Round 55 lane BAKE) turns an art directory in the layout of
[offhand-format.md §6](../../docs/technical/offhand-format.md) (with a `tiers.json` that names both items and every
tier) into the game files of §7:

```sh
python3 tools/r55_offhand/bake.py                       # the picked art (tools/r55_art/art) -> grug_visuals/textures
python3 tools/r55_offhand/bake.py --icons-out mods/ITEMS/grug_gear/textures --check   # the gate: exit 1 on a
                                                        # missing, extra or different file
python3 tools/r55_offhand/bake.py --art DIR --out DIR   # another art directory or output directory
python3 tools/r55_offhand/bake.py --sheet OUT.png       # contact sheet: every tier's shield, book and icons, zones tinted
python3 tools/r55_offhand/test_bake.py                  # the tool's test on test_art/ and test_art_broken/
python3 tools/r55_offhand/make_broken_art.py [--check]  # rewrite (check) test_art_broken/ from test_art/
```

Until the finish step there is no picked art: the default `--art` fails with a clear message, and the test art is
baked only into temp directories or a test-only probe mod (never into `mods/`).

- Per bracket grade (`offhand.grades()`, T1 the first): `grug_offhand_shield_<grade>.png` (the atlas size; the
  tier's shield sheet palette-swapped into the sheet `shield_<step>` of its size step, `params.json` `tier_step`;
  the other two copies, the book and the card transparent), `grug_offhand_book_<grade>.png` (the six book box
  sheets in their rectangles), and an `_ench.png` mask next to each in the armor's format (two frames stacked:
  frame 0 zone A, frame 1 zone B; 255 for A_LIGHT/B_LIGHT, 153 for A_DARK/B_DARK). With `--icons-out`:
  `grug_gear_shield_<grade>.png` and `grug_gear_spellbook_<grade>.png`, 16 × 16, with their 16 × 32 masks. 24 game
  files, 24 icon files. Only the face rectangles of `data/atlas.json` are copied; palettes are the armor's
  `tools/r54_armor/data/palettes.json` with the art's optional `palettes.json` laid over by name.
- **Validation** before anything is written; every violation is listed and the exit code is 1: `tiers.json` (both
  items, T1–T6, a known palette, variants, the icon for an icon bake), unknown or missing files, sizes, the
  reference palette, alpha 0 or 255, transparent texels whose centre lies inside the shield outline or in a book
  face, and per item and tier at least 6 zone A and 3 zone B texels (the shield's front inside the outline; the
  book's outer covers and readable pages). Warnings do not fail: an art file no tier uses, paint outside a book
  sheet's faces (dropped), and transparent shield texels the outline crosses (their centre lies outside, but the
  rim and the slanted edges sample them, so they show as notches; paint them).
- `--check` rebuilds in memory and compares mode, size and pixels; an extra file is a `grug_offhand_*.png` in
  `--out` the bake would not write (write mode removes such files). In `--icons-out` only the bake's own icon files
  count.
