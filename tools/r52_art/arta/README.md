# Round 52 ARTA — drop 01

Delivered 2026-10-19 by GPT-6 Astra on `r52-arta`. **Compatible**: art
candidates and authoring tools only; no game behaviour, Lua, saved state or
`mods/` changes. No files are picked yet. The coordinator builds the selection
page; GRAPH and WFX take only the user's later picks. A later art revision
belongs in `drop-02/`, preserving this drop.

Inputs: [node list](../../../docs/planning/class-redesign/node-list.md)
§2 and §4; [class round plan](../../../docs/planning/round52-class-plan.md)
C6, C7, C11, D5 and D7. The brief's top accent overrides the older node-list
wording about light towards the ultimate: the ultimate is on the bottom row.

## Contents

- [Background contact sheet](drop-01/preview-bg.png): all 24 candidates, exactly
  520 × 220 per image, with a mock 7 × 5 grid, pale label proxies and a few
  orthogonal connections. The mock UI exists only on this sheet.
- [Overlay contact sheet](drop-01/preview-fx.png): all 12 candidates; a sample
  phase over an iron sword, an iron staff and a bow at 8×, plus the overlay
  alone and every phase at 4×. Each strip also has its own animated GIF,
  showing those three weapons side by side at 8×.
- [Manifest](drop-01/manifest.json): one record per media file, 50 total;
  paths are relative to the drop, `size` is `[width, height]`, and `bytes` is
  the exact file size. Primary files have role `background` or `overlay`;
  GIFs and contact sheets have role `preview`. A strip and its GIF share
  key/variant; select by role or extension as well.
- [Generation inputs](drop-01/sources.json): 24 independent prompts and
  their original generation output paths. No third-party image was sent
  to image generation. The manifest also records each source hash and size.
- [Check receipt](drop-01/checks.json): dimensions, alpha, hashes, per-frame
  coverage, loop seams, GIF duration checks and centre luminance observations.

## Backgrounds

All eight trees use restrained painterly surfaces, atmospheric depth and
edge silhouettes. Each variant is a separate image-generation call, not a
recolour of another draft. Each is an opaque 1040 × 440 palette PNG with
256 colours, no dithering and `optimize=True`. After centred Lanczos fitting,
a smooth horizontal mask softly blurs and darkens the central field; the
exact recipe and source image hash are recorded per file in the manifest.

| Tree | Idea |
|---|---|
| Ember | Cracked charcoal basalt, orange fissures and rising edge sparks carry the fire palette. |
| Rime | A frozen night lake lies between frost ferns under a pale upper-edge aurora. |
| Bulwark | Weathered ramparts, iron gate bands, rivets and a plain banner suggest a steady guard. |
| Ruin | Broken battlefield iron and scorched ground dissolve into deep crimson smoke. |
| Mercy | Warm stone arches and ivory lilies frame soft golden sanctuary light. |
| Reckoning | Stern tribunal columns and golden scales meet hard upper light and crimson cloth. |
| Quarry | A forest edge, grasses, shed antlers and feathers overlook a distant dawn ridge. |
| Veil | Moonlit alley walls and violet smoke surround a quiet indigo field below a silver crescent. |

## Overlays

All PNGs are **16 × 128 RGBA**, eight 16 × 16 frames from top to bottom.
Coordinates are authored directly; no pixels are copied from the weapon
sprites. Effects occupy x 7–15 and y 0–8 at most. The entire lower seven
rows stay transparent. Only 6–14 pixels are nontransparent in any phase.
Alpha is selected from **0, 96, 176, 255**: translucent trails and pulses
leave the weapon visible; a few frost/holy/rage highlights are opaque.
Every transparent pixel has zero RGB. There is no Strike strip.

| Key | Variant | Frames | Loop (s) | Frame duration (ms) | Alpha levels |
|---|---:|---:|---:|---:|---|
| `fx.fire` | 1 | 8 | 0.80 | 100 | 0, 96, 176 |
| `fx.fire` | 2 | 8 | 0.96 | 120 | 0, 96, 176 |
| `fx.frost` | 1 | 8 | 1.12 | 140 | 0, 96, 176, 255 |
| `fx.frost` | 2 | 8 | 0.96 | 120 | 0, 96, 176, 255 |
| `fx.holy` | 1 | 8 | 1.12 | 140 | 0, 96, 176, 255 |
| `fx.holy` | 2 | 8 | 0.96 | 120 | 0, 96, 176, 255 |
| `fx.rage` | 1 | 8 | 0.80 | 100 | 0, 96, 176 |
| `fx.rage` | 2 | 8 | 0.96 | 120 | 0, 96, 176, 255 |
| `fx.wild` | 1 | 8 | 0.96 | 120 | 0, 96, 176 |
| `fx.wild` | 2 | 8 | 1.12 | 140 | 0, 96, 176 |
| `fx.shadow` | 1 | 8 | 1.12 | 140 | 0, 96, 176 |
| `fx.shadow` | 2 | 8 | 0.96 | 120 | 0, 96, 176 |

The original phase sequence loops without a duplicated terminal frame;
phase 8 evaluates to phase 0. The transition from the last saved phase to
the first is no larger than the largest internal transition for every strip
(measured in premultiplied RGB, observations in `checks.json`). The end/start
phases were also visually inspected beside each other over the sword.
The GIFs loop forever at the exact proposed duration. `wild_v2.gif` has seven
encoded frames: two identical 140 ms phases become one 280 ms hold. Its PNG
still has eight phases; `gif_encoded_frames` records the distinction.

## Reproduction

From the repository root, with Python 3 and Pillow installed:

```sh
python3 -I tools/r52_art/arta/arta_bg.py --out /tmp/arta-rebuild
python3 -I tools/r52_art/arta/arta_fx.py --out /tmp/arta-rebuild
```

Both scripts locate repository inputs relative to themselves and work under
isolated Python. They accept identical existing media but refuse to replace
media with different bytes. Use a fresh output directory for revisions.
The background script needs the original generated files at the recorded
paths, or `--source-root <directory>` containing copies with those original
filenames. Originals remain in the local image-generation cache; the final
PNG assets are all committed in this drop. A new image-generation call is
not expected to reproduce the original pixels. The overlay script needs
only this repository's three preview weapon sprites and Pillow.

The manifest is assembled by the two scripts and includes their SHA-256
hashes. Each preserves the other script's entries. Code follows the
repository's GPL-3.0-or-later licence; original media is dedicated below.

## Checks and handoff

All 50 media records match their file sizes, dimensions and SHA-256 hashes;
all original generation files and generator hashes match. Dimensions, alpha,
lower-half clearance, the eight saved phases, the loop seam and GIF timings
were checked once for the completed drop. Both contact sheets and the seam
inspection were viewed. No fixtures or engine runs were performed, as the
brief requests. Desktop/web runtime acceptance and the art picks remain
with the user and coordinator.

Backgrounds total **4,553,267 bytes**, range **168,242–216,091 bytes** per PNG; the 12 overlay PNGs total **2,947 bytes**. Every background is below the approximate 300 KB guide.

## Media

The project dedicates rights it holds in the new background and overlay
art to **CC0 1.0 Universal**, to the extent such rights exist:
<https://creativecommons.org/publicdomain/zero/1.0/>.
All new art is by **GPT-6 Astra (Grudgelands)**, dated **2026-10-19**.
`BG` below means built-in `image_gen.imagegen`, followed by `arta_bg.py`;
`FX` means original pixel geometry and cyclic paths in `arta_fx.py`.

The **weapon composites cannot be wholly CC0**, because the required preview
weapons carry attribution/share-alike licences. Those GIFs and
`preview-fx.png` are distributed as CC BY-SA 4.0 adaptations; their newly
authored overlay layer remains separately available as CC0 PNGs. The
background contact sheet is wholly new art and CC0. No third-party pixels
occur in any deliverable background or overlay PNG.

Preview source credits (provenance only):

- Iron sword and iron staff: Grudgelands weapon ladder, derived from
  **minetest_game contributors**, © 2010–2023 (including celeron55, Cisoun,
  G4JC, VanessaE, RealBadAngel, Calinou, MirceaKitsune, Jordach, PilzAdam,
  jojoa1997, InfinityProject, Splizard, Zeg9, paramat, BlockMen, sofar,
  Neuromancer, Gambit, asl97, KevDoy, Mito551, GreenXenith, kaeza, kilbith,
  tobyplowy, CloudyProton, TumeniNodes, Mossmanikin, random-geek, Extex101,
  An0n3m0us and Lopano), **CC BY-SA 3.0 Unported**.
  [Source repository](https://github.com/luanti-org/minetest_game),
  [licence](https://creativecommons.org/licenses/by-sa/3.0/),
  [local attribution](../../../mods/BASE/default/license.txt),
  [weapon derivation](../../../mods/ITEMS/grug_gear/LICENSE-media.md).
- Bow: **XSSheep / Pixel Perfection and VoxeLibre contributors**,
  **CC BY-SA 4.0**, from `mcl_bows_bow_0.png` at commit
  `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`.
  [Source licence](https://git.minetest.land/VoxeLibre/VoxeLibre/src/commit/c2dbc520ff4e1637072d33b06c3a2404e0f08df7/LEGAL.md),
  [licence](https://creativecommons.org/licenses/by-sa/4.0/),
  [local provenance](../../../mods/PLAYER/grug_abilities/LICENSE-media.md).
- Preview modifications: alpha-composite our effect above each unchanged
  weapon, enlarge with nearest-neighbour scaling, add a checker background
  and labels, and encode animation with a common palette. Source file paths
  and SHA-256 hashes are in each composite's manifest entry. `Weapon authors`
  in the table refers to the credits above; existing repository attribution
  is also preserved in [CREDITS.md](../../../CREDITS.md).

| File (relative to drop-01) | Author | Date | Method | Licence | Bytes |
|---|---|---|---|---|---:|
| `bg/ember_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Basalt embers | CC0-1.0 | 189696 |
| `bg/ember_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Banked furnace | CC0-1.0 | 203933 |
| `bg/ember_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Ash and cinder | CC0-1.0 | 193236 |
| `bg/rime_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Aurora lake | CC0-1.0 | 178498 |
| `bg/rime_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Blue stillness | CC0-1.0 | 185459 |
| `bg/rime_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Winter breath | CC0-1.0 | 200685 |
| `bg/bulwark_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Watch gate | CC0-1.0 | 191343 |
| `bg/bulwark_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Iron threshold | CC0-1.0 | 190754 |
| `bg/bulwark_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Rampart dusk | CC0-1.0 | 180251 |
| `bg/ruin_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Broken iron | CC0-1.0 | 180673 |
| `bg/ruin_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Red aftermath | CC0-1.0 | 203658 |
| `bg/ruin_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Cinder steel | CC0-1.0 | 193378 |
| `bg/mercy_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Quiet sanctuary | CC0-1.0 | 180950 |
| `bg/mercy_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Lily alcove | CC0-1.0 | 182921 |
| `bg/mercy_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Gentle vigil | CC0-1.0 | 174308 |
| `bg/reckoning_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Severe tribunal | CC0-1.0 | 177017 |
| `bg/reckoning_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Scales at dawn | CC0-1.0 | 168242 |
| `bg/reckoning_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Judgment stone | CC0-1.0 | 195280 |
| `bg/quarry_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Dawn ridge | CC0-1.0 | 198429 |
| `bg/quarry_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Hunter's clearing | CC0-1.0 | 190381 |
| `bg/quarry_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Feathers in mist | CC0-1.0 | 182117 |
| `bg/veil_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Moonlit alley | CC0-1.0 | 216091 |
| `bg/veil_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Silver passage | CC0-1.0 | 188355 |
| `bg/veil_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Violet hush | CC0-1.0 | 207612 |
| `preview-bg.png` | GPT-6 Astra | 2026-10-19 | BG contact sheet with mock grid | CC0-1.0 | 2904336 |
| `fx/fire_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Twin tongues | CC0-1.0 | 258 |
| `fx/fire_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 61527 |
| `fx/fire_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Ember crown | CC0-1.0 | 300 |
| `fx/fire_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 62669 |
| `fx/frost_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Rime needles | CC0-1.0 | 228 |
| `fx/frost_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 61611 |
| `fx/frost_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Crystal breath | CC0-1.0 | 212 |
| `fx/frost_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 62601 |
| `fx/holy_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Golden motes | CC0-1.0 | 222 |
| `fx/holy_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 61046 |
| `fx/holy_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Quiet radiance | CC0-1.0 | 264 |
| `fx/holy_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 62337 |
| `fx/rage_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Crimson edge | CC0-1.0 | 169 |
| `fx/rage_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 60737 |
| `fx/rage_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Red heartbeat | CC0-1.0 | 234 |
| `fx/rage_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 62317 |
| `fx/wild_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Teal slipstream | CC0-1.0 | 194 |
| `fx/wild_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 61547 |
| `fx/wild_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Leaf drift | CC0-1.0 | 245 |
| `fx/wild_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 53967 |
| `fx/shadow_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Violet curl | CC0-1.0 | 305 |
| `fx/shadow_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 62178 |
| `fx/shadow_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Silver smoke | CC0-1.0 | 316 |
| `fx/shadow_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 63958 |
| `preview-fx.png` | GPT-6 Astra; weapon authors | 2026-10-19 | FX contact sheet; weapon composites | CC-BY-SA-4.0 | 60878 |
