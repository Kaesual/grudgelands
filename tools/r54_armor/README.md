# Armor render and check tool (Round 54)

The armor contract of Round 54 ([plan](../../docs/planning/round54-plan.md)): the box catalog, the atlas
layout, and the tool that renders armor art on the character and checks it against the texture contract
([docs/technical/armor-format.md](../../docs/technical/armor-format.md), the source of truth).
`catalog.py`, `data/catalog.json` and `data/atlas.json` change only through the round's coordinator.

Run every command from this directory, or with this directory's path; the tools write only to the `--out`
directory you give (never into this folder).

Python 3 + Pillow + numpy only: the default renderer (`--engine soft`, `softrender.py`) is pure Python and **works inside your sandbox** (about 1 s per line, no
network, no browser). `--engine chromium` renders the same scene with headless chromium and the vendored
three.js (`vendor/`); it is for the coordinator's pick pages and does not run in the sandbox. Both give
practically the same picture (same camera, lights, pose and textures; soft is slightly smoother at edges).

## What you paint

Put everything under one art directory, e.g. `art/`. **You choose which boxes each tier wears:** all 17
catalog boxes (28 with the mirrored copies) may be used on every tier of every line. The design goals are in
the style bible your brief names; the user's own selection (`tiers_example.json`, copied into
`test_art/tiers.json`) is only an orientation. Write your choice to `art/tiers.json` (spec §7):

```json
{"metal": {"T1": {"palette": "bronze", "on": ["helm", "chest", "pauldron", "thigh", "boot"],
                  "variant": {"helm": "a", "chest": "a"}, "inner": {"chest": "a", "legs": "a", "feet": "a"},
                  "icon": {"head": "a", "chest": "a", "legs": "a", "feet": "a"}}}}
```

A missing `variant` entry means `a`; a tier entry must name its `palette`, and one without `inner` or `icon` has none. Tier palettes may be proposed in `art/palettes.json` (same shape as
`data/palettes.json`: `{"palettes": {"<name>": {"colors": {"M_HI": "#RRGGBB", ...all 13}}}}`); they are laid
over `data/palettes.json` by name, and a tier names its palette in `tiers.json`. `--palettes FILE` uses
another file instead. A line or tier missing from `tiers.json` (or a missing file) falls back to
the example selection, and both tools say so.


| File | What | Size |
|---|---|---|
| `art/<line>/<box>_<variant>.png` | one box sheet: the six faces of a catalog box | per box, see `templates/boxes/<box>.png` |
| `art/<line>/inner/<slot>_<variant>.png` | inner paint on the skin, `slot` = chest, legs or feet | 64×32 |
| `art/<line>/icons/<slot>_<variant>.png` | inventory icon, `slot` = head, chest, legs or feet | 16×16 |

`<line>` is `metal`, `leather` or `cloth`; `<variant>` is `a`, `b`, ... as named in your `tiers.json`.
`check.py` lists every file your selection needs but is missing.

- **Colours:** only the 13 reference colours (`templates/palette.png`) plus full transparency. Alpha is 0 or
  255, nothing in between. The render swaps them for each tier's palette.
- **Zones:** zone A (A_LIGHT/A_DARK) is the cloth, zone B (B_LIGHT/B_DARK) the fittings. Every slot of every
  tier needs at least 6 zone A and 3 zone B pixels visible from the front, counting only what the body and
  the same slot's own boxes hide (a robe may cover the boots; each piece must show its colour on its own).
- **Box sheets:** start from `templates/blank/<box>.png` (exact size, transparent). `templates/boxes/<box>.png`
  shows the same sheet at 8× with every face labelled, its orientation spelled out, and hatched texels that
  another catalog box covers when both are worn (the legend names them). Paint only inside the six face
  rectangles.
- **Orientation:** front column 0 is the character's right; back column 0 is the character's left; side faces
  are seen from outside; top row 0 is the back edge, bottom row 0 the front edge.
- **Mirrored boxes** (sleeve, bracer, shoulder parts, tasset, thigh, knee, boot, toe) have one sheet. Paint
  it for the character's right side; the left copy shows it mirrored.
- **Armor is opaque** (the user, 2026-10-20): every texel inside a box sheet's faces must be opaque;
  transparency showed holes in the game (one looks into the hollow box). The only exception is the helm's **face
  window** (white in `templates/boxes/helm.png`: columns 1–8, rows 1–8 of its front face), which may stay open so
  the face shows. Shape comes from the boxes you choose and the paint.
- **Inner paint:** start from `templates/blank/inner_<slot>.png`; `templates/inner/<slot>.png` shows the
  slot's region in green (chest: torso and arm; legs: leg rows 20–27; feet: leg rows 28–31). Head has no
  inner paint.
- **Icons:** 16×16, one clear silhouette, few details; it need not copy the 3D piece.

## Commands

From this directory (or prefix the path to it):

```sh
python3 check.py  --art art                       # rule check, exit code 1 on violations
python3 check.py  --art art --line metal          # one line only
python3 render.py --art art --out out             # contact sheets, all lines: out/<line>_human.png
python3 render.py --art art --line metal --tiers T5,T6 --race human,troll --out out
python3 render.py --art art --line metal --tiers T5 --detail --out out    # out/metal_T5_human.png
python3 render.py --art art --engine chromium --out out    # coordinator only (needs a working chromium)
```

The sheet header names the renderer and where the tier selection came from.

Races: human, dwarf, elf, orc, troll, undead (the camera is the same for all, so stature shows).

## Reading the output

**Contact sheet** (`<line>_<race>.png`): one row per tier, each with the tier's palette applied. Columns: front,
back, right side, front three-quarter from the character's left, back three-quarter from the character's
right, walking (legs at ±0.6 rad, seen from the front right). On the right, the four icons at 32 px and
16 px (16 px again on a dark slot). The row label lists the worn boxes and, in magenta, any missing files;
missing art renders as a **magenta/black checker** on the model.

**Detail sheet** (`--detail`): one tier, twelve large views (four sides, four three-quarters at rest, four
walking) and the icons at 64, 32 and 16 px.

**check.py** prints these sections; only VIOLATION lines fail the check (exit code 1), WARNING and INFO
lines do not:

1. `tier selection`: where the selection comes from (`art/tiers.json` or the example fallback) and any
   problems in `tiers.json` (unknown line, tier, box, palette or slot: violations).
2. `files`: wrong names, sizes, off-palette colours, partial alpha, paint outside the faces or the slot
   region, each with pixel coordinates.
3. `files the tiers need`: missing files and which tiers need them; a WARNING for a file no tier uses.
4. `zones seen from the front`: zone A/B pixel counts per line, tier and slot. An approximation: an
   orthographic front view of the rest pose; a zone pixel counts unless the body or a box of the same slot
   hides it; both mirrored copies count; side faces and perspective are ignored.
5. `overlap report`: first the catalog-wide table (every pair of boxes, whatever the tiers wear): `A covers
   B` with the covered texels of B's sheet per face, as a count and a rectangle in B's sheet pixels. Paint
   there is hidden under A. `[moves]` marks boxes on
   different bones (e.g. a hip panel over a knee): true in the rest pose only. Then per line and tier the
   pairs your selection wears together (`A>B`; later tiers list the change). A `GEOMETRY NOTE` would be a
   catalog issue (coplanar faces that flicker); report it, do not paint around it.

## For the coordinator

- `catalog.py` is the frozen geometry (the contract); `zfight.py` checks it for coplanar faces over all
  bones (exit 1 on a problem); `skins.py` composes the race default looks from the game's textures.
- `export.py` rewrites `data/catalog.json` from `catalog.py` and `tiers_example.json` (its `tiers`
  are the example selection, used only where `art/tiers.json` is missing; keeps the
  tier fields `palette`, `variant`, `inner`, `icon` of an existing file; `--force` resets them) and writes
  `data/palettes.json` once (placeholders, edit freely; `--force` regenerates) and `data/skins/`;
  `--check` fails when `data/catalog.json` or `data/skins/` is stale.
- `atlas.py` packs every box sheet into the 128×64 armor atlas (`data/atlas.json`, read by the model
  generator, the bake and the game); `--check` fails when it is stale or invalid, `--png OUT` draws it.
- `templates.py` rewrites `templates/`.
- `softrender.py` is the software renderer behind `--engine soft` (the default).
- `make_test_art.py` writes `test_art/` with a `tiers.json` (passes check.py without warnings; letters
  F/R/L/B or corner flags in OUTLINE mark each face's top-left for orientation; an eye band open in the
  helm's face window) and `test_art_broken/` (twelve deliberate errors).
- Two proposals for a pick page: two art directories, rendered separately.
