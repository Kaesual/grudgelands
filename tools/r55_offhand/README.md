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

## For the painter: what to paint, the check, the look

Everything here runs in a plain Python 3 with Pillow and numpy: no browser, no game, no network. Run the commands
from the repository root (the tools find their own data). The full rules are
[offhand-format.md §6](../../docs/technical/offhand-format.md); this is the short version.

**What you paint**, all in one art directory (here `art/`):

| File | What | Size now |
|---|---|---|
| `art/shield/<variant>.png` | the shield: FRONT in the left half, BACK in the right half | 22 × 13 |
| `art/book/<box>_<variant>.png` | one sheet per book box: `cover_f`, `cover_b`, `pages_f`, `pages_b`, `spine`, `ribbon` | 12 × 7, 12 × 7, 10 × 6, 10 × 6, 4 × 7, 4 × 4 |
| `art/icons/shield_<variant>.png`, `art/icons/book_<variant>.png` | inventory icons | 16 × 16 |
| `art/tiers.json` | per item and tier T1–T6: `palette`, `variant` (one id, or for the book a map box → id), `icon`, optionally `icon_palette` (the icon in another palette) | |
| `art/palettes.json` (optional) | proposed tier palettes, laid over `tools/r54_armor/data/palettes.json` by name | |
| `art/cloak_<id>.png`, `art/wings_<id>.png` (optional) | a cloak (outer face left, lining right) and its wings | 32 × 32, 16 × 32 |

The sizes follow `params.json`; `templates/blank/` always has every sheet at its exact size, transparent, to paint
into. `<variant>` and `<id>` are lower-case letters and digits (`a`, `b`, `supporter`).

- **Colours:** only the 13 reference colours of `templates/palette.png` plus full transparency (alpha 0 or 255).
  The bake and the render swap them for each tier's palette. Cloak and wings are not swapped: paint them in their
  final colours.
- **Zones:** per item and tier at least 6 zone A (A_LIGHT/A_DARK) and 3 zone B (B_LIGHT/B_DARK) texels on the
  outward faces: the shield's front; the book's outer covers and the two readable pages (gold in the templates).
- **Opaque:** every shield texel the outline contains or crosses (tinted in `templates/shield.png`) and every
  texel of a book face. Texels outside (light checker) are never shown; leave them transparent.
- **Orientation:** `templates/shield.png` and `templates/book_<box>.png` label every face: what it is on the open
  book, which way it is seen, where column 0 and row 0 are. The shield's front is seen from the front, its back
  from behind; the rim takes the front's border texels (darker tint). Hatched texels were never seen in a
  visibility pass of the game's model (hidden by the hand, the arm or the item itself): paint them, but plainly.
- **Wings and cloak:** `templates/wings.png` (the sampled triangles, hinge, outer corner) and
  `templates/cloak.png` (outer face, lining, the edges, where the wings hinge, where a Scout's weapon card hangs).

**The check** (the bake is the gate; it lists every problem and writes nothing on a failure; always give `--out`):

```sh
python3 tools/r55_offhand/bake.py --art art --out out/bake --icons-out out/bake --sheet out/bake.png
```

**The look** on the game's own character model, every pose as in the game:

```sh
python3 tools/r55_offhand/render.py --art art --out out              # all sheets: shield, book, cloak (about 2 s)
python3 tools/r55_offhand/render.py --art art --item shield --tiers T5 --detail --out out   # one tier large
python3 tools/r55_offhand/render.py --art art --item book --race troll --armor cloth:T4 --out out
python3 tools/r55_offhand/render.py --art art --item shield --cloak supporter --back mods/ITEMS/grug_gear/textures/grug_gear_bow_wood.png --out out
```

Options: `--item shield|book|cloak|all`, `--tiers T1,T3`, `--race human,dwarf,elf,orc,troll,undead` (the
camera is the same for all, so stature shows), `--armor LINE:TIER` (the game's armor, e.g. `metal:T3`; default
none), `--cloak ID` (wear `cloak_<ID>.png` and its wings on the item sheets), `--back PNG` (a 16 × 16 weapon image
on the back card: on the cloak with `--cloak`, else on the back).

**Reading the sheets:**

- `shield_<race>.png`, `book_<race>.png`: one row per tier with its palette; columns front, back, the left side
  (the shield side), front 3/4 left and back 3/4 left in Stand, then the item's pose (Block for the shield, Cast 1
  for the book) from the front and front 3/4 left; on the right the icon at 32 px and at 16 px (on the background
  and on a dark slot). The row label names the palette, the variants and the shield's size step.
- `<item>_<tier>_<race>.png` (`--detail`): the item alone in its own frame, front and back **flat lit** (every
  texel shows its exact tier colour, texels can be counted) and two lit 3/4 views; then eight close views on the
  character (Stand, the pose, mid-walk) and the icon at 64, 32 and 16 px.
- `cloak_<race>.png`: per cloak id the back, the left side and back 3/4 left in Stand and mid-walk, and the back
  with a weapon on the cloak card. A `wings_<id>.png` without `cloak_<id>.png` is shown on the plain grey cloak.
- Missing or broken art (a missing file, a wrong size, a colour off the palette) shows as a **magenta/black
  checker** and is listed in magenta in the row label and on the console. The header says whether `bake.py`
  accepts the art directory (its problems are printed on the console); the render shows what it can either way.

**For the coordinator:** `render.py` reads `mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d` with
`tools/r33_c3/gen_cloak_model.py`'s parser and rig and rasterises with `tools/r54_armor/softrender.py`; the layers
come from `bake.py`'s own functions (`test_render.py` proves them equal to the bake). `templates.py` writes
`templates/` from `params.json`, `data/atlas.json` and the model (`--check` exits 1 when stale; rerun it after a
retune or a model change). `python3 tools/r55_offhand/test_render.py` is the tool's test.

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

`params.json` is retuned (and replaced at the finish), so the test pins no position: its samples follow
`make_test_art.py`'s rules on the live atlas, and `make_broken_art.py` places its errors and derives the
expected messages (`expected()`) from the live parameters. After a retune, rerun `make_test_art.py`, then
`make_broken_art.py`.

The default `--art` is the picked art, `tools/r55_art/art` ([its README](../r55_art/README.md), since the finish
step); the test art is baked only into temp directories or a test-only probe mod (never into `mods/`).

- Per bracket grade (`offhand.grades()`, T1 the first): `grug_offhand_shield_<grade>.png` (the atlas size; the
  tier's shield sheet palette-swapped into the sheet `shield_<step>` of its size step, `params.json` `tier_step`;
  the other two copies, the book and the card transparent), `grug_offhand_book_<grade>.png` (the six book box
  sheets in their rectangles), and an `_ench.png` mask next to each in the armor's format (two frames stacked:
  frame 0 zone A, frame 1 zone B; 255 for A_LIGHT/B_LIGHT, 153 for A_DARK/B_DARK). With `--icons-out`:
  `grug_gear_shield_<grade>.png` and `grug_gear_spellbook_<grade>.png`, 16 × 16, with their 16 × 32 masks. 24 game
  files, 24 icon files. Only the face rectangles of `data/atlas.json` are copied; palettes are the armor's
  `tools/r54_armor/data/palettes.json` with the art's optional `palettes.json` laid over by name.
- **Validation** before anything is written; every violation is listed and the exit code is 1: `tiers.json` (both
  items, T1–T6, a known palette, variants, the icon for an icon bake, an optional `icon_palette` that is a known
  palette and colours the icon only), unknown or missing files, sizes (an
  optional `cloak_<id>.png`, 32 × 32, and `wings_<id>.png`, 16 × 32, are checked for their size only and not baked), the reference palette, alpha 0
  or 255, transparent shield texels the outline contains or crosses (`offhand.shield_texels`: the rim and the
  slanted edges sample them) or book face texels, and per item and tier at least 6 zone A and 3 zone B texels
  (the shield's front; the book's `cover_f` front, `cover_b` back, `pages_f` back and `pages_b` front). Warnings
  do not fail: an art file no tier uses, paint outside a book sheet's faces (dropped).
- `--check` rebuilds in memory and compares mode, size and pixels; an extra file is a `grug_offhand_*.png` in
  `--out` the bake would not write (write mode removes such files). In `--icons-out` only the bake's own icon files
  count.
