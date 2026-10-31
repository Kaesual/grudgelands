# Round 68 follow-up ICONS — pass 2 proposal report

**User picks (2026-10-31): metal bars A, with metal blocks A; jewellery
settings B (prong crowns on ring shanks). Gems A are preferred but not
final.** Their cut gems were put **in rework** because the outlines and
facets did not read clearly as regular cuts. Pass 2 replaces that pending
comparison with **C and D, ready for selection**. A stays as reference;
B stays in the earlier-variants sections. Recommendation: **gems D and
blocks D, with A’s unchanged rough gems and minerals**.

[Offline preview](preview/index.html) · [Shared family](preview/picked_family.png)
· [Block walls](preview/gem_block_walls.png)

**Upgrade classification: compatible, proposal assets only.** No candidate
is installed. No Lua, game assets, recipes, ids, tiers, saved state, version
or upgrade declaration changes. No server or fixtures were run. Nothing
was merged or pushed.

## Delivery and preservation

- **26 added PNG files:** six cut gems and seven block faces each in
  `candidates/gems_c/` and `candidates/gems_d/`.
- **120 candidate PNGs total**, all 16 × 16 RGBA: 72 transparent item
  icons, 48 fully opaque node-face textures. The 94 pass-1 candidate files
  are byte-identical to `00713f9e`.
- All six rough gems, Quartz and Abyssal Crystal are reused from
  `candidates/gems_a/`, **without scaling or any pixel change**. They are
  not duplicated into C/D. Every C/D preview and measurement uses these
  exact A images alongside the new cuts.
- `abyssal_crystal_block.png` in C and D is byte-identical to A. It remains
  a raw mineral block; there is no invented cut crystal item.
- All blocks have exactly matching opposite edges. Each is continuous
  polished material across the face, with restrained bevel contrast for
  a wall; no transparent icon is tiled onto the face.

The self-contained HTML marks bars/metal blocks A and settings B as
**Picked**. Its gem comparison is **Current / A reference / C / D**, with
rough/cut side by side at 16, 32 and 64 px, both minerals at those sizes,
whole gem groups at 16 and 32 px, and a Garnet/Ruby callout. C/D each have
one uninterrupted shared strip of the ten picked bars A, six picked
settings B, and fourteen gem/mineral icons, at 16 and 32 px. Seven block
faces per variant have 4 × 3 walls and mixed rows. B’s items, blocks and
measurements remain in collapsed sections. The full pairwise and rough/cut
ΔE tables include C/D. There are 1,138 inlined PNG instances and eight local
navigation anchors; no remote resources, external URLs or scripts. Retain
`preview/comparison-license.txt` when publishing the directory.

## Cut ideas and recommendation

**C — ordered steps:** one consistent family of clipped rectangular and
octagonal step cuts, broad saturated tables, and parallel lit/shaded rims.
Regularity and a common family are its strengths. The large frontal faces
are deliberately restrained, with fewer visual cues between the stones.
Blocks C repeat the parallel step bevels around a broad square table.

**D — classic silhouettes:** a different familiar cut per gem, a small
number of broad crown planes around a visible table, fixed upper-left
light, and a broad brilliant diamond. Blocks D have four low-contrast
crown planes around a large table. **Recommended:** the varied proportions
separate the six jewels and their rough states at native inventory size;
the diamond has the clearest top-gem silhouette.

| Gem | C | D |
|---|---|---|
| Citrine | Tall clipped rectangle | Horizontal oval crown |
| Jade | Wide rectangular steps | Square step cut with small clipped corners |
| Garnet | Square steps | Round/octagonal crown, dark warm red |
| Sapphire | Tall octagonal steps | Wide cushion crown |
| Ruby | Narrow, tall octagonal steps | Symmetric upright pear, vivid crimson |
| Diamond | Broad octagonal table | Broad brilliant profile, bright crown and distinct pavilion planes |

All twelve new cut silhouettes are **exactly left/right symmetric at the
pixel level**. C’s six and D’s oval, square, round and cushion cuts are
also exactly top/bottom symmetric; the pear and brilliant profile are
naturally only left/right symmetric. Illumination is intentionally not
mirror-symmetric. Tables and perimeter vertices are authored directly on
the 16 px grid instead of rounding an irregular inset outline.

The new cuts use more of the icon: A had **91–117 opaque pixels** per cut,
C has **168–216**, D **136–184**. Diamond grows from 100 pixels to 216 (C)
or 136 (D). D’s relative sizes remain close to the bars and A’s natural
specimens in the shared strips; no scaling of the liked rough art was
needed. Enlargements use nearest-neighbour sampling.

## Colour evidence and limits

Cut Garnet/Ruby: **3.85 OLD → 32.63 A → 32.73 C / 33.11 D**. The new
variants keep the strong colour separation while adding regular square
versus elongated cuts (C), or round versus pear (D). Their rough pair
stays **31.31**, since A is unchanged. Quartz/Cut Diamond:
**6.20 OLD → 31.76 A → 29.66 C / 34.77 D**.

The complete closest-pair, before/after and rough/cut tables are below.
C/D use A’s original saturated colour ramps. The objective is readable
geometry, not a higher distance score for every pair: D’s rough/cut Ruby
is **17.03 vs A 17.79**, and Citrine **20.39 vs A 20.46**. Their upright
pear/horizontal oval geometry and clear tables separate the states in
ways this overlap-only colour metric deliberately does not measure.
Jade rough/cut remains the closest pair (C 17.24, D 14.73); compare the
irregular rough mound and the straight-edged cut in the native strips.
These numbers are guides, not gates or a substitute for the user’s eye.

## Reproduce and verify

From the repository root:

```sh
python3 tools/r68_icons/generate.py
python3 tools/r68_icons/generate.py --check
```

The same generator now writes/compares **177 reproducible outputs**:
120 candidates, 47 current comparisons, HTML, five contact/wall sheets,
source manifest, JSON and Markdown measurements, and the comparison-media
notice. It rejects unexpected files in generated directories and checks
size, RGBA mode, binary item alpha, full block opacity and matching edges.

Checks completed before independent review:

- `generate.py --check`: **PASS**, all 177 outputs reproduce byte for byte.
- All 94 original candidates verified against pass-1 git blob hashes.
- C/D each contain exactly six cuts and seven blocks; symmetry and the
  unchanged Abyssal Crystal blocks verified from their PNGs.
- Offline HTML parsed: 1,138 valid embedded PNGs, eight valid local anchors,
  no external/active resources; 727,968 UTF-8 bytes.
- Measurements contain **875 pair values and 30 rough/cut entries**.
- Native/enlarged gem comparisons, the shared 16/32 px family and C/D block
  walls visually inspected. The page is a software preview, not a client
  capture; browser and actual client acceptance remain the user’s.

Independent review and final commit receipt follow after the content commit.

The current-image reconstruction and engine colour conversion are unchanged
from pass 1. [current_sources.json](current_sources.json) records each
source expression, filename and SHA-256; [LICENSE-media.md](LICENSE-media.md)
records the original CC0 candidate art, GPL-3.0-or-later generator, and
unchanged CC BY-SA 3.0 comparison attribution. Existing armour/trinket
context retains its own CC0 provenance.

## Open question and GUI checklist

| Remaining user decision | Recommended option |
|---|---|
| C or D cut gems with their matching six gem blocks? | **D**, combined with A’s six rough gems, Quartz, Abyssal Crystal and its unchanged block. Bars/metal blocks A and settings B are already decided. |

On both desktop and web target screens, browser at 100%: read the complete
shared 16 px strip, then 32 px; compare Garnet/Ruby; compare each rough/cut
pair (especially Jade, Sapphire and Ruby); identify Diamond separately
from Quartz; inspect the repeated and mixed C/D block walls. Client GUI
verification follows in the later installation lane. The existing Abyssal
Crystal registry tier remains untouched (the pass-1 brief called it T6;
the shipped harvest tier is 5).

## Commit receipt

Pass-1 tip: `00713f9e`; branch `r68-icons`. This pass uses small commits
ending with `Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.
The reviewed content hash and clean-tree receipt will be recorded after
committing it. The final branch-tip hash belongs in the runner’s `last.md`
and final response: a committed file cannot contain its own commit hash.

The following tables are copied from the generated measurement summary.
All pairwise values are in [measurements.json](measurements.json).

## Distinctness measurements

CIE76 ΔE: sRGB → linear RGB → CIE XYZ D65 → Lab; compute the Euclidean distance at each matching pixel and average only where BOTH alpha values are 255. No alignment, resizing, compositing, or background pixels enter the metric. N is the number of shared opaque pixels. Shape differences are deliberately not scored. These numbers are a guide, never a threshold; judge the 16 px strips first.

Three closest pairs per scope and version. The gem scope contains all 14 items,
including minerals and both gem states; blocks have their own scopes.
Every pair is in `measurements.json` and the expandable preview tables.

| Scope | Version | Pair | ΔE | N |
|---|---|---|---:|---:|
| Metal bars | OLD | Tin Bar / Steel Bar | 2.96 | 107 |
| Metal bars | OLD | Silver Bar / Silversteel Bar | 6.19 | 107 |
| Metal bars | OLD | Iron Bar / Silversteel Bar | 10.20 | 107 |
| Metal bars | A | Tin Bar / Steel Bar | 8.36 | 115 |
| Metal bars | A | Tin Bar / Silversteel Bar | 10.91 | 115 |
| Metal bars | A | Tin Bar / Silver Bar | 14.27 | 115 |
| Metal bars | B | Tin Bar / Steel Bar | 9.27 | 137 |
| Metal bars | B | Tin Bar / Silversteel Bar | 10.58 | 137 |
| Metal bars | B | Tin Bar / Silver Bar | 14.16 | 137 |
| Jewellery settings | OLD | Setting Iron / Setting Copper-inlaid Steel | 4.55 | 107 |
| Jewellery settings | OLD | Setting Tin / Setting Iron | 6.35 | 107 |
| Jewellery settings | OLD | Setting Copper-inlaid Steel / Setting Gold-filigreed Abyssal Steel | 10.26 | 107 |
| Jewellery settings | A | Setting Tin / Setting Copper-inlaid Steel | 12.83 | 95 |
| Jewellery settings | A | Setting Tin / Setting Iron | 16.01 | 95 |
| Jewellery settings | A | Setting Iron / Setting Copper-inlaid Steel | 18.25 | 104 |
| Jewellery settings | B | Setting Tin / Setting Copper-inlaid Steel | 11.50 | 105 |
| Jewellery settings | B | Setting Tin / Setting Iron | 18.61 | 97 |
| Jewellery settings | B | Setting Iron / Setting Copper-inlaid Steel | 21.44 | 97 |
| Gems and minerals | OLD | Cut Garnet / Cut Ruby | 3.85 | 88 |
| Gems and minerals | OLD | Cut Diamond / Quartz | 6.20 | 88 |
| Gems and minerals | OLD | Rough Garnet / Rough Ruby | 8.04 | 88 |
| Gems and minerals | A | Rough Garnet / Cut Garnet | 13.39 | 104 |
| Gems and minerals | A | Rough Jade / Cut Jade | 13.76 | 95 |
| Gems and minerals | A | Rough Sapphire / Cut Sapphire | 17.72 | 92 |
| Gems and minerals | B | Rough Jade / Cut Jade | 17.13 | 91 |
| Gems and minerals | B | Rough Garnet / Cut Garnet | 19.46 | 110 |
| Gems and minerals | B | Rough Garnet / Rough Ruby | 19.66 | 124 |
| Gems and minerals | C | Rough Jade / Cut Jade | 17.24 | 103 |
| Gems and minerals | C | Rough Ruby / Cut Ruby | 18.44 | 88 |
| Gems and minerals | C | Rough Garnet / Cut Garnet | 20.11 | 107 |
| Gems and minerals | D | Rough Jade / Cut Jade | 14.73 | 103 |
| Gems and minerals | D | Rough Ruby / Cut Ruby | 17.03 | 86 |
| Gems and minerals | D | Rough Garnet / Cut Garnet | 18.76 | 107 |
| Metal storage blocks | OLD | Tin Block / Steel Block | 3.02 | 256 |
| Metal storage blocks | OLD | Iron Block / Silver Block | 5.12 | 256 |
| Metal storage blocks | OLD | Iron Block / Silversteel Block | 5.53 | 256 |
| Metal storage blocks | A | Tin Block / Steel Block | 10.91 | 256 |
| Metal storage blocks | A | Tin Block / Silversteel Block | 11.87 | 256 |
| Metal storage blocks | A | Silver Block / Silversteel Block | 17.13 | 256 |
| Metal storage blocks | B | Tin Block / Steel Block | 10.96 | 256 |
| Metal storage blocks | B | Tin Block / Silversteel Block | 11.61 | 256 |
| Metal storage blocks | B | Silver Block / Silversteel Block | 17.28 | 256 |
| Gem and crystal storage blocks | OLD | Garnet Block / Ruby Block | 8.04 | 88 |
| Gem and crystal storage blocks | OLD | Sapphire Block / Abyssal Crystal Block | 25.74 | 88 |
| Gem and crystal storage blocks | OLD | Jade Block / Diamond Block | 26.46 | 88 |
| Gem and crystal storage blocks | A | Sapphire Block / Abyssal Crystal Block | 27.11 | 256 |
| Gem and crystal storage blocks | A | Garnet Block / Ruby Block | 30.65 | 256 |
| Gem and crystal storage blocks | A | Jade Block / Diamond Block | 44.24 | 256 |
| Gem and crystal storage blocks | B | Sapphire Block / Abyssal Crystal Block | 26.99 | 256 |
| Gem and crystal storage blocks | B | Garnet Block / Ruby Block | 30.55 | 256 |
| Gem and crystal storage blocks | B | Jade Block / Diamond Block | 44.60 | 256 |
| Gem and crystal storage blocks | C | Sapphire Block / Abyssal Crystal Block | 27.59 | 256 |
| Gem and crystal storage blocks | C | Garnet Block / Ruby Block | 30.59 | 256 |
| Gem and crystal storage blocks | C | Jade Block / Diamond Block | 45.32 | 256 |
| Gem and crystal storage blocks | D | Sapphire Block / Abyssal Crystal Block | 27.35 | 256 |
| Gem and crystal storage blocks | D | Garnet Block / Ruby Block | 30.50 | 256 |
| Gem and crystal storage blocks | D | Jade Block / Diamond Block | 44.83 | 256 |

## Rough versus cut

| Gem | Old ΔE | A ΔE | B ΔE | C ΔE | D ΔE |
|---|---:|---:|---:|---:|---:|
| Citrine | 31.73 | 20.46 | 34.10 | 27.40 | 20.39 |
| Jade | 28.85 | 13.76 | 17.13 | 17.24 | 14.73 |
| Garnet | 41.32 | 13.39 | 19.46 | 20.11 | 18.76 |
| Sapphire | 38.10 | 17.72 | 22.42 | 24.15 | 24.17 |
| Ruby | 38.96 | 17.79 | 31.28 | 18.44 | 17.03 |
| Diamond | 22.89 | 24.29 | 31.12 | 31.96 | 24.01 |

## Known weak pairs, before and after

| Pair | Old ΔE | A ΔE | B ΔE | C ΔE | D ΔE |
|---|---:|---:|---:|---:|---:|
| Tin Bar / Steel Bar | 2.96 | 8.36 | 9.27 | — | — |
| Silver Bar / Silversteel Bar | 6.19 | 17.76 | 16.98 | — | — |
| Iron Bar / Silversteel Bar | 10.20 | 31.55 | 32.33 | — | — |
| Copper Bar / Bronze Bar | 17.84 | 16.01 | 16.63 | — | — |
| Rough Garnet / Rough Ruby | 8.04 | 31.31 | 19.66 | 31.31 | 31.31 |
| Cut Garnet / Cut Ruby | 3.85 | 32.63 | 31.85 | 32.73 | 33.11 |
| Quartz / Cut Diamond | 6.20 | 31.76 | 28.12 | 29.66 | 34.77 |
