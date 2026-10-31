# Round 68 follow-up ICONS — pass 3 final gem delivery

**User picks (2026-10-31): metal bars A and metal blocks A; jewellery
settings B; cut gems D and gem blocks D, with the Abyssal Crystal block
as it is. Every group is decided.** The installation set combines these
picks with the eight larger raw specimens requested in pass 3.

[Offline preview](preview/index.html) · [Picked family](preview/picked_family.png)
· [Gem comparison](preview/gems_comparison.png) · [Block walls](preview/gem_block_walls.png)
· [Installation mapping and licence rows](INSTALL.md)

**Upgrade classification: compatible, art delivery only.** Nothing is
installed under `mods/`; no Lua, server, fixtures, recipes, ids, tiers,
saved state, version or upgrade declaration changes. Nothing was merged
or pushed. Desktop/web client acceptance belongs to the installation lane.

## Delivery and preservation

`candidates/gems_final/` contains **21 PNGs**, ready to copy as one group:

- Six larger rough gems, plus larger Quartz and Abyssal Crystal.
- Six picked D cuts, copied byte for byte.
- Seven picked D blocks, copied byte for byte. The Abyssal Crystal block
  remains byte-identical to its original A face.

All 120 existing A/B/C/D candidate files are byte-identical to pass-2 tip
`d16035eb`. The full art record now contains **141 candidate PNGs**: 86
transparent item icons and 55 opaque node faces, all 16 × 16 RGBA. The
picked installation set has **47 files**: bars/metal blocks A (20), settings
B (6), and final gems/blocks (21). `INSTALL.md` maps each candidate to its
exact item/node id, proposed prefixed destination filename, expanded
current image expression and source/use citations in `ores.lua` or
`goldsmith.lua`. It includes the CC0 rows needed by both owning mods.

## Larger natural specimens

The eight raw specimens are redrawn directly on the final 16 px grid in
`art.py`; no bitmap scaling, interpolation or antialiasing enters a
candidate. Their colour sets are **exactly A’s original palettes**.
The irregular outer skins, broad left-lit exposures and dark right-hand
fractures follow A; Jade keeps its low, broad nugget, Ruby its tilted
elongated natural crystal, Quartz its two prisms and Abyssal Crystal its
three-pronged cluster. One-pixel glints and fracture lines stay crisp.

The specimens gain approximately **35–55% opaque area**, about 1.16–1.25
in equivalent linear size. These are pixel-grid redraws, not a uniform
resampling factor. The six rough gems now occupy 80–107% of their D cut
counterparts’ opaque area, retaining each natural silhouette’s proportions.
The cuts keep their ordered outlines, broad tables and regular facets;
the rough forms keep their broken surfaces and asymmetric contours.

| Specimen | A / pass-2 rough pixels | Final rough pixels | Gain | Unchanged D cut pixels |
|---|---:|---:|---:|---:|
| Citrine | 95 | 145 | 53% | 156 |
| Jade | 103 | 147 | 43% | 184 |
| Garnet | 107 | 161 | 50% | 156 |
| Sapphire | 97 | 144 | 48% | 168 |
| Ruby | 88 | 129 | 47% | 146 |
| Diamond | 102 | 145 | 42% | 136 |
| Quartz | 110 | 171 | 55% | — |
| Abyssal Crystal | 113 | 153 | 35% | — |

## Preview and colour evidence

At the top, the shared inventory strip shows **bars A + settings B +
final gems** at 16 and 32 px. The main gem comparison places **Current /
Pass 2 D with small rough / Final** side by side at 16, 32 and 64 px,
with each rough/cut pair together. Both minerals receive the same sizes.
Whole-group strips, the Garnet/Ruby callout, final block faces, 4 × 3
walls and mixed block rows remain available. Earlier A/B/C gem studies
are preserved in collapsed sections; D remains the direct comparison.

Final closest gem-group pairs are **Rough/Cut Garnet 9.47**, **Rough/Cut
Jade 12.93**, and **Rough/Cut Ruby 16.06**. The lower rough/cut colour
distances follow the enlarged overlapping faces; shape and surface
structure, deliberately absent from the metric, remain the state cues.
Garnet rough/cut is the closest pair to inspect at native size: the raw
stone’s diagonal exposed face and fracture contrast with D’s ordered
crown and broad table. This is evidence for visual review, not a threshold.

The distinct material pairs remain separated: **Rough Garnet/Rough Ruby
32.01** (pass 2: 31.31), **Cut Garnet/Cut Ruby 33.11** (unchanged D),
**Quartz/Cut Diamond 33.77** (pass 2: 34.77). All final gem and block
pairwise values and all six rough/cut measurements appear on the page,
in `measurements.json`, and in the generated summary copied below.

The HTML contains **1,155 embedded PNG instances**, eight local navigation
anchors and no external resources, scripts or active content. It is
751,582 UTF-8 bytes. Keep `preview/comparison-license.txt` with the page
when publishing the directory. The sheets/page are software studies;
no browser or game-client capture is claimed.

## Reproduce and verify

From the repository root:

```sh
python3 tools/r68_icons/generate.py
python3 tools/r68_icons/generate.py --check
```

The same generator now writes/compares **199 reproducible outputs**:
141 candidates, 47 current comparisons, HTML, five contact/wall sheets,
source manifest, JSON and Markdown measurements, comparison-media notice,
and `INSTALL.md`. It rejects unexpected files in the generated directories.
The old image reconstruction and colour conversion are unchanged.

Verification completed:

- `generate.py --check`: **PASS**, all 199 outputs reproduce byte for byte.
- All 120 prior candidate blobs match `d16035eb`; all 13 D cut/block files
  match their final copies, including the A-origin Abyssal Crystal block.
- Each raw redraw uses exactly A’s opaque colour set and occupies more
  pixels. Candidate checks cover 16 × 16 RGBA, binary item alpha, full
  block opacity and matching opposite block edges.
- Offline HTML audit: all 1,155 inlined PNGs decode, all eight anchors
  resolve; no network resources or active content.
- Measurements: **987 pairwise values and 36 rough/cut entries**.
- Installation table: 47 distinct candidate/id rows; candidate paths and
  source line links resolve. Source expressions were read without Lua.
- Shared 16/32 px family and native/enlarged gem comparisons visually
  inspected. The D blocks are unchanged.
- `git diff --check`: **PASS**; `git diff d16035eb -- mods`: **empty**.

**Independent review: PASS, no findings**, native Sol reviewer
`icons_pass3_review`, fresh context under the project’s art review policy.
Reviewed delta: `d16035eb..e63cf458da5dd768075f3cb01b4b010b40c6ec7c`.
The reviewer reproduced all 199 outputs, confirmed preservation and exact
D copies, checked all 47 installation mappings against the Lua sources,
audited the offline HTML and visually inspected the shared family, gem
comparisons and final block walls. Independent recalculation of all
**91 final gem pairwise values and six final rough/cut entries** from the
committed PNGs agreed, including overlap counts. The reviewer confirmed
the clean worktree and compatible classification. This review does not
replace the user’s client GUI acceptance.

## GUI checklist and decisions

**No group-selection question remains.** On both desktop and web target
screens, inspect the final family at native size, distinguish each raw/cut
pair (especially Garnet and Jade), compare Garnet/Ruby and Quartz/Diamond,
and inspect the picked metal/gem block walls after installation. The raw
size redraw can be assessed in this page before that client check.

## Commit receipt

- Pass-2 baseline: `d16035eb`; branch `r68-icons`.
- Larger raw art and assembled final gem folder: `7617b909`.
- Generator, preview, installation handoff and report: `7dffe611`.
- Final independently reviewed content, including the tool index update:
  **`e63cf458da5dd768075f3cb01b4b010b40c6ec7c`**.
- At that reviewed commit, **`git status --porcelain` returned empty**,
  independently confirmed by the reviewer.
- This review receipt is a documentation-only commit after the reviewed
  content. The final response and runner’s `last.md` carry the final
  branch-tip hash and clean-tree check after committing this receipt;
  a committed file cannot contain its own containing commit’s hash.
- Every pass-3 commit ends with
  `Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.

The tables below are copied from the generated measurement summary. The
full pairwise tables are in [measurements.json](measurements.json).

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
| Gems and minerals | FINAL | Rough Garnet / Cut Garnet | 9.47 | 147 |
| Gems and minerals | FINAL | Rough Jade / Cut Jade | 12.93 | 142 |
| Gems and minerals | FINAL | Rough Ruby / Cut Ruby | 16.06 | 116 |
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
| Gem and crystal storage blocks | FINAL | Sapphire Block / Abyssal Crystal Block | 27.35 | 256 |
| Gem and crystal storage blocks | FINAL | Garnet Block / Ruby Block | 30.50 | 256 |
| Gem and crystal storage blocks | FINAL | Jade Block / Diamond Block | 44.83 | 256 |

## Rough versus cut

| Gem | Old ΔE | A ΔE | B ΔE | C ΔE | D ΔE | Final ΔE |
|---|---:|---:|---:|---:|---:|---:|
| Citrine | 31.73 | 20.46 | 34.10 | 27.40 | 20.39 | 17.39 |
| Jade | 28.85 | 13.76 | 17.13 | 17.24 | 14.73 | 12.93 |
| Garnet | 41.32 | 13.39 | 19.46 | 20.11 | 18.76 | 9.47 |
| Sapphire | 38.10 | 17.72 | 22.42 | 24.15 | 24.17 | 17.14 |
| Ruby | 38.96 | 17.79 | 31.28 | 18.44 | 17.03 | 16.06 |
| Diamond | 22.89 | 24.29 | 31.12 | 31.96 | 24.01 | 24.88 |

## Known weak pairs, before and after

| Pair | Old ΔE | A ΔE | B ΔE | C ΔE | D ΔE | Final ΔE |
|---|---:|---:|---:|---:|---:|---:|
| Tin Bar / Steel Bar | 2.96 | 8.36 | 9.27 | — | — | — |
| Silver Bar / Silversteel Bar | 6.19 | 17.76 | 16.98 | — | — | — |
| Iron Bar / Silversteel Bar | 10.20 | 31.55 | 32.33 | — | — | — |
| Copper Bar / Bronze Bar | 17.84 | 16.01 | 16.63 | — | — | — |
| Rough Garnet / Rough Ruby | 8.04 | 31.31 | 19.66 | 31.31 | 31.31 | 32.01 |
| Cut Garnet / Cut Ruby | 3.85 | 32.63 | 31.85 | 32.73 | 33.11 | 33.11 |
| Quartz / Cut Diamond | 6.20 | 31.76 | 28.12 | 29.66 | 34.77 | 33.77 |
