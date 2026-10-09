# Round 45 A1 — Jewellery icons

Three complete proposal sets by GPT-6 Astra, 2026-10-09. Original,
AI-assisted pixel art authored in [paint_art.py](paint_art.py) with
Python/Pillow; no downloads, image-generation service, external fonts or
third-party source pixels in the jewellery. Artwork: CC0 1.0. The generator
uses the repository's GPL-3.0-or-later code licence.

## The user's pick (2026-10-09) and what ships

| Identity | Variant |
|---|---|
| `manawell` | A |
| `last_light` | A |
| `battlebeat` | B |
| `apothecary_loop` | B |
| `mercy_seal` | A |
| `reclaimers_mark` | C |

Every tier of an identity uses its picked variant (`PICKS` in the
generator). The 36 shipped icons are
`mods/ITEMS/grug_gear/textures/grug_gear_trinket_<key>_t<tier>.png`, set per
tier by `mods/ITEMS/grug_gear/trinkets.lua`; their licence rows are in
[grug_gear/LICENSE-media.md](../../mods/ITEMS/grug_gear/LICENSE-media.md#round-45-jewellery-icons--cc0-10).
[final_sheet.png](final_sheet.png) shows the shipped set (6 identities × 6
tiers at 4×, plus native 1× on dark and light). The capital's Goldsmith
product display shows `grug_gear_trinket_manawell_t4.png`.

The three proposal sheets below stay as the record of the choice. The
unpicked icons are not kept as files; the generator reproduces all 108.

## Review images and files

- [A — Heirloom](variants/A/sheet.png): open chains, rounded settings and
  restrained warm metal around deep cabochons.
- [B — Cut and Seal](variants/B/sheet.png): angular pendants, broad signets
  and geometric seals, with cool metal and brighter gem facets.
- [C — Living Filigree](variants/C/sheet.png): curled bands, a sunburst
  locket and scalloped medallions, with warm highlights and lighter gems.

Each folder keeps only its `sheet.png`. Icons are **16 × 16 RGBA**, with
fully transparent or fully opaque pixels and no smoothing. Each sheet is **1000 × 1056 RGBA**: six
identity rows and six tier columns, every large icon enlarged exactly 4×
with nearest-neighbour sampling. The comparison row places three proposals
beside the existing gold bar, cut diamond, steel sword and apple, also at
4×. The final sample row shows all six T4 identities at native size on dark
and light backgrounds. There is no scale adjustment to make proposals
larger than the existing icons.

| Key | Existing form | Authored distinguishing motif |
|---|---|---|
| `manawell` | amulet | Hanging water drop; pointed in B, crescent cradle in C |
| `last_light` | amulet | Sun locket; round in A, window in B, rays in C |
| `battlebeat` | ring | Broad beat-marked bezel; double crest in C |
| `apothecary_loop` | ring | Diagonal leaf; split shank in B, second leaf in C |
| `mercy_seal` | medallion | Paired wings around a small central gem |
| `reclaimers_mark` | medallion | Returning curl and inward arrow; openwork in C |

The tier materials follow [item_tiers.md §3](../../docs/design/item_tiers.md#3-profession-upgrades),
[goldsmith.lua](../../mods/ITEMS/grug_artisans/goldsmith.lua) and the gem
tiers in [registry.lua](../../mods/ITEMS/grug_materials/registry.lua):

| Tier | Body and trim | Main gem |
|---|---|---|
| T1 | Tin | Citrine |
| T2 | Iron, darker than tin and steel | Jade |
| T3 | Steel with copper inlay | Garnet |
| T4 | Gold | Sapphire |
| T5 | Embersteel with gold filigree | Ruby |
| T6 | Abyssal Steel with gold filigree | Diamond |

Small medallion studs additionally show sapphire at T5 and sapphire/ruby
at T6. The six main gem colours stay tied to the tier, so the silhouette
and motif distinguish identities. The metal and gem ramps are authored
separately for each variant, following the existing material colour families.

## Reproduce and check

From the repository root, with Python 3 and Pillow (generated with 12.3.0):

```sh
python3 tools/r45_a1/paint_art.py
python3 tools/r45_a1/paint_art.py --check
```

The generator writes the 36 picked icons into `grug_gear/textures/`, the
three proposal sheets and `final_sheet.png`. `--check` writes nothing: it
verifies the six keys against `trinkets.lua`, a pick for every identity, the
exact trinket texture roster, all 108 proposal icons unique, sizes, RGBA mode,
binary alpha and byte-for-byte regeneration of all 40 PNGs. Caption glyphs
are included in the generator. Existing art is loaded only by the
contact-sheet comparison function; the cut diamond sample applies its
registered white tint. `tools/r45_art/portable_test.lua` checks in the game
that every trinket item names its own existing icon.

## Comparison-sheet reference samples

The labelled Gold Bar and Apple on the three proposal sheets are
nearest-neighbour enlargements of `default_gold_ingot.png` and
`default_apple.png`; Cut Diamond is `default_diamond.png` with its registered
`^[colorize:#ffffff:20` tint, then enlarged; Steel Sword is
`grug_gear_item_sword_steel.png`, enlarged. These existing assets are
**CC BY-SA 3.0 Unported**
(<https://creativecommons.org/licenses/by-sa/3.0/>), © 2010–2023 the
minetest_game contributors listed in
[`mods/BASE/default/license.txt`](../../mods/BASE/default/license.txt) and
[CREDITS.md](../../CREDITS.md#textures-and-models); the sword's derivation is
recorded in [grug_gear/LICENSE-media.md](../../mods/ITEMS/grug_gear/LICENSE-media.md).
The four reference tiles keep that licence within each sheet; they are not
sources for the jewellery pixels and are not relicensed. The sheets' own
layout, captions and jewellery are CC0 1.0. The final sheet carries no
reference samples.

**Upgrade classification: compatible.** Only item images change; item ids,
saved state and mechanics are unchanged.
