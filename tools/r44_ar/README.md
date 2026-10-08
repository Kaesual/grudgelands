# Round 44 AR — UI art proposals

Original, AI-assisted pixel art by GPT-6 Astra, 2026-10-08. Python/Pillow,
authored at native pixel coordinates; no downloads, external fonts, source
art or image-generation service. Licence: **CC0 1.0**; the grouped rows and
tool disclosure live in
[grug_map/LICENSE-media.md](../../mods/PLAYER/grug_map/LICENSE-media.md).

**Upgrade classification: compatible.** This lane adds art, its provenance
generator and documentation. It changes no game code, gameplay data, saved
state, world generation or upgrade declaration. No Lua or engine run is
needed for this art package. Independent lane review, the coordinator's pick
page, the user's picks and the desktop/web GUI checks remain pending.

## Choices and handover

| Variant | Trainers | Baked symbols | Font | Target marks |
|---------|----------|---------------|------|--------------|
| [A](variants/A/sheet.png) | Bronze octagonal plates; sword, cuirass, scissors, hide, drawknife, cut gem, flask, cooking pot | Warm roofs and pale stone; pictorial settlements, cave entrance, crossed blades, crown, dragon head | Open atlas capitals with light serifs | Round reticle; thin hard white ring |
| [B](variants/B/sheet.png) | Slate medallions; axe, helmet, spool and needle, boot, chisel, ring, retort, bowl and ladle | Cool stone; stepped citadel, shield fort, mine cart, broken shield, paw, spread dragon wings | Compact square sans | Square brackets and centre cross; thick hard white ring |
| [C](variants/C/sheet.png) | Pale parchment tags; forging hammer, shield, shirt, purse, hand plane, pendant, mortar, steaming bowl | Ochre cartographic emblems; banner camp, pick and gem, ruined columns, crowned sceptre, curled dragon | Broad incised capitals | Four inward chevrons and centre point; soft white rim |

All three choices exist for **every** family. Both factions use the same
settlement art. Hostile camps have red warning details. Cooking is included
as explicitly requested by the lane brief. The progress bar remains Round
45's work. There are no deviations from the lane brief.

Each variant directory is flat, with the final basenames. **A is provisionally
copied to the final paths** so MB/MQ can wire them. This is not an art pick.
The coordinator may choose families independently using the user's picks;
copy a font's `font.png` and `font.txt` together, and a baked kind's full and
miniature images together. The final licence already covers A, B and C.

## Complete file inventory

All PNGs are **RGBA**. Every new game image has a transparent background.
Every miniature is a separate native **6 × 6** drawing, not a reduction.

The following ten files live in `mods/PLAYER/grug_map/textures/`, and also
in each `tools/r44_ar/variants/{A,B,C}/`:

| Filename | Size |
|----------|------|
| `grug_map_trainer_weaponsmith.png` | 16 × 16 |
| `grug_map_trainer_armorsmith.png` | 16 × 16 |
| `grug_map_trainer_tailor.png` | 16 × 16 |
| `grug_map_trainer_leatherworker.png` | 16 × 16 |
| `grug_map_trainer_woodcarver.png` | 16 × 16 |
| `grug_map_trainer_goldsmith.png` | 16 × 16 |
| `grug_map_trainer_alchemist.png` | 16 × 16 |
| `grug_map_trainer_cooking.png` | 16 × 16 |
| `grug_map_crosshair.png` | 16 × 16 |
| `grug_map_ring.png` | 32 × 32 |

The following files live in `mods/PLAYER/grug_map/art/`, and also in each
`tools/r44_ar/variants/{A,B,C}/`:

| World-map filename (16 × 16) | Minimap filename (6 × 6) |
|----------------------------|--------------------------|
| `baked_start.png` | `baked_start_mini.png` |
| `baked_capital.png` | `baked_capital_mini.png` |
| `baked_village.png` | `baked_village_mini.png` |
| `baked_outpost.png` | `baked_outpost_mini.png` |
| `baked_fortress.png` | `baked_fortress_mini.png` |
| `baked_war_camp.png` | `baked_war_camp_mini.png` |
| `baked_bandit.png` | `baked_bandit_mini.png` |
| `baked_mirefolk.png` | `baked_mirefolk_mini.png` |
| `baked_mine.png` | `baked_mine_mini.png` |
| `baked_clash.png` | `baked_clash_mini.png` |
| `baked_rare_den.png` | `baked_rare_den_mini.png` |
| `baked_king.png` | `baked_king_mini.png` |
| `baked_dragon.png` | `baked_dragon_mini.png` |

| Additional file | Size / format |
|-----------------|---------------|
| `art/font.png`, `variants/A/font.png` | 232 × 8 RGBA |
| `variants/B/font.png` | 194 × 8 RGBA |
| `variants/C/font.png` | 238 × 8 RGBA |
| `art/font.txt`, each `variants/{A,B,C}/font.txt` | 42 ASCII bytes: 41 characters + LF |
| Each `variants/{A,B,C}/sheet.png` | 1440 × 1860 RGBA, opaque review sheet |
| `tools/r44_ar/paint_art.py` | Reproducible generator and format checks |
| `tools/r44_ar/README.md` | This inventory and handover |
| `mods/PLAYER/grug_map/LICENSE-media.md` | Grouped licence rows, including variants |

Total: **151 PNGs** (111 proposals, 37 provisional final images, 3 sheets)
and **4 font.txt files**, plus generator, handover and licence update.

## Font sheet contract

`font.txt` is one ASCII line, followed by exactly one LF:

```text
ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 '-.,
```

There are **41 characters**, including the space between `9` and `'`.
Do not strip internal whitespace. All variants use this identical order.

- The atlas is one horizontal row of proportional-width glyphs.
- Coordinates are zero-based. **Row 0 is metadata**: one opaque pure-red
  `(255, 0, 0, 255)` pixel at the first column of every glyph, **including
  space**; every other pixel in that row is transparent.
- **Rows 1–7 are glyph pixels**, pure opaque white `(255, 255, 255, 255)`
  or transparent `(0, 0, 0, 0)`. Letter/digit cap height is exactly 7 px.
  All glyphs share the same baseline; the comma stays inside these seven rows.
- Each glyph is followed by **exactly one fully transparent separator
  column**, also after the last comma. There is no extra outer padding.
- Read the red columns in order as `start[i]`. The glyph width is
  `start[i+1] - start[i] - 1`; for the last glyph use
  `image_width - start[last] - 1`. Read its bitmap from rows 1 through 7;
  advance by `width + 1`. Never draw row 0.
- Space is a blank glyph: width 3 in A/C, width 2 in B, plus its separator.
  Every other glyph uses its full stored width. White allows arbitrary
  renderer tinting; the dark halo is a renderer concern, not in the atlas.

The nine current `REGION_LABELS` in `mods/PLAYER/grug_map/page.lua` use only
uppercase English letters and spaces after conversion, all covered here.
Digits and the four punctuation marks cover the brief's extended contract.

## Contact sheets and verification

Each sheet includes every PNG at **4× nearest-neighbour**, exact basenames
rendered in the original small-cap caption font, plus:

- Trainers at **43 × 43** (16 × 2.67 rounded to whole pixels), beside the
  existing waypoint and Housing Steward icons at that same scale.
- Baked world icons at **2×** on green, sand, snow and sea patches, with
  native miniatures at **3×** below, matching the approximate minimap scale.
- The font atlas including its metadata row, its `font.txt` line, and
  `THE CONTESTED FRONT` at **3×** in white with a one-native-pixel dark halo.
- Both target marks at **4×**; extra terrain samples show the crosshair at
  2× and the ring at 3×, tinted red at 67% opacity for demonstration.
- A separate labelled comparison strip of existing map icons. Those pixels
  are not part of any new game texture; their existing CC0 provenance stays
  in the mod's media licence. Sheet captions use our own glyph grids.

```sh
python3 tools/r44_ar/paint_art.py --check --install-a
```

This checks all **155** art/text files against fresh in-memory drawings,
including sizes, modes, alpha, font markers/separators, seven-pixel capitals,
all three distinct proposals per basename, and identical provisional A copies.
The actual saved PNGs are reopened and their complete pixel bytes compared.
All three contact sheets were visually inspected for label placement,
silhouettes, terrain contrast, reduced trainer scale and font examples.

To repaint just proposals and sheets, run the script without arguments.
`--install-a` explicitly also replaces final images with A; do not use it
after the coordinator has installed different user picks. After picks,
`--check` alone still checks the untouched proposal sets and sheets.
