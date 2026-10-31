# Round 68 follow-up ICONS — proposal report

**Delivered for selection, 2026-10-31.** Recommendation: **bars A, settings A,
gems A**, with metal blocks A and gem/crystal blocks A following those groups.
The [offline preview](preview/index.html) contains the complete before/A/B
comparison. No candidate has been installed in the game.

**Upgrade classification: compatible, proposal assets only.** There are no
Lua, game assets, recipes, item ids, tiers, saved-state, version or upgrade
contract changes. No fixture or game server was run. Only Python, git and
image inspection were used; nothing was merged or pushed.

## Delivery

94 candidate PNGs, all 16 × 16 RGBA:

| Group | Per variant | Both variants |
|---|---:|---:|
| Metal bars | 10 | 20 |
| Metal storage block faces | 10 | 20 |
| Empty jewellery settings | 6 | 12 |
| Rough and cut gems | 12 | 24 |
| Quartz and Abyssal Crystal | 2 | 4 |
| Gem and Abyssal Crystal block faces | 7 | 14 |
| Total | 47 | 94 |

The 60 item icons have binary transparency. The 34 block textures are fully
opaque, as required for solid node faces. Opposite tile edges match exactly.
Every filename is the last component of the existing item/node id.

Candidates live in `candidates/{bars,settings,gems}_{a,b}/`. The preview
contains every item and block face at 16, 32 and 64 px, whole-group strips
at 16 and 32 px, rough/cut pairs, a Garnet/Ruby comparison, 4 × 3 single
material walls and contiguous mixed block rows. Shipped armour and trinkets
are included unchanged as palette context. All 798 PNG instances are inlined;
the HTML has no external URLs, remote fonts or scripts. Retain
`preview/comparison-license.txt` when publishing the directory.

## Ideas and recommendations

| Group | A | B | Recommendation |
|---|---|---|---|
| Bars and metal blocks | Long tapered cast ingots with individual surface cues; blocks are calm solid cast faces. | Broad horizontal forged billets with clipped corners and working marks; blocks show two offset courses. | **A**: its diagonal light and silhouette sit well with the shipped tools. B exposes the material marks more directly. |
| Settings | Loose open bezels, with a transparent central socket and copper/gold trim. | Empty prong crowns over hollow ring shanks. | **A**: a loose mount plausibly becomes a ring, amulet or seal, and the empty centre is larger at 16 px. |
| Gems, minerals and blocks | Individual natural specimens and distinct radial cuts; the diamond has a broad brilliant crown. Blocks use one large polished facet. | Mineral exposures in broken host rock and broad step cuts; the diamond is tall. Blocks use paired stepped slabs. | **A**: cleaner rough silhouettes and a more obvious top-tier diamond; B gives the rough/cut states the strongest structural contrast. |

Material decisions:

- Tin is pale, softly cast and slightly cool; Iron is dark, warm grey and
  hammered; Steel is neutral grey with a ground face; Silver is polished
  warm white; Silversteel has a cool double ridge. Their similarity remains
  intentional, but tone and surface cues improve the inventory comparison.
- Copper is reddish and Bronze ochre, taking Bronze from the armour palette.
  Embersteel uses the weapon/trinket fire edge over a dark body; Abyssal
  Steel is deep violet-grey with a narrow pale reflection. Higher-tier
  metals keep their existing gear relationships.
- Settings follow the shipped Round 45 B trinket metal ramps, including
  copper inlay at T3 and gold over Embersteel/Abyssal Steel at T5/T6. The
  centre and the prong opening contain no stone.
- Garnet is dark warm red and Ruby vivid crimson. A pairs a square garnet
  with a pear-shaped ruby; B uses a hexagonal garnet and a round ruby. The
  cut stones retain saturated bodies with small highlights.
- Quartz is a milky crystal cluster in A and a broken prismatic piece in B.
  Abyssal Crystal is a dark cluster of blades in A and a split shard in B.
  Neither receives an invented cut form. Its block uses the crystal palette.

## Reproduce and verify

From the repository root:

```sh
python3 tools/r68_icons/generate.py
python3 tools/r68_icons/generate.py --check
```

Environment used: Python **3.14.8**, Pillow **12.3.0**, numpy **2.4.6**.
The generator writes/compares 149 reproducible outputs, including the 94
candidates, 47 current comparisons, HTML, three contact sheets, source
manifest, measurements and applicable comparison-media notice. `--check`
also rejects unexpected files in the generated directories and checks
candidate size, mode, binary alpha, full block opacity and matching tile
edges. It does not install anything.

The current images are rebuilt directly from the shipped Lua texture
expressions, without executing Lua. `colorize` uses float32 interpolation
with the engine's rounded result; `brighten` truncates `(255 + channel)/2`.
The implementation was checked against the pinned engine reference's
`src/client/imagesource.cpp:486–519,830–846` and
`irr/include/SColor.h:343–351`. [current_sources.json](current_sources.json)
records every source filename, texture expression and SHA-256.

Verification completed:

- `generate.py --check`: **PASS**, all 149 outputs reproduce byte for byte.
- All candidate counts, paths, image modes, dimensions and alpha verified.
- Offline HTML audit: 798 valid inlined PNGs, seven valid local anchors,
  no scripts, active resource tags or external URLs.
- All 651 pair measurements and 18 rough/cut entries present. The independent
  reviewer recalculated the 651 pair values from the committed PNGs with a
  separately formulated Lab conversion; all values and overlap counts agree.
- Native and enlarged contact sheets and block-wall studies inspected.
- `git diff --check`: **PASS**. `git diff 23620af3 -- mods`: **empty**.

**Independent review:** native Sol reviewer `icons_review`, under the
project's art review policy. Two confirmed preview issues were fixed:
(1) the mixed wall's right side now samples its last material, and
(2) the licence sidecar now includes the full 1856-byte media notice, not
only its heading. The focused follow-up and final reproducibility check
passed; no findings remain. This is technical review of proposals, not
user acceptance or permission to install them.

## Open selection and practical limits

| Question for the user's later pick | Recommended option |
|---|---|
| Bars and their blocks: A or B? | **A**, tapered cast ingots and calm solid faces. |
| Settings: A or B? | **A**, loose open bezels usable for every trinket form. |
| Gems, minerals and their blocks: A or B? | **A**, individual specimens and radial cuts. |

The closest white-metal pair remains Tin/Steel: ΔE 8.36 in A and 9.27 in B
versus 2.96 today. This is a modest material distinction, not a promise of
instant recognition. Copper/Bronze's colour distance is slightly lower
than today's 17.84 (A 16.01, B 16.63); visual separation comes from red copper
versus ochre bronze, and the result still needs the user's eye at 16 px.
Within the full gem scope, same-material rough/cut pairs are now the nearest
neighbours, rather than Garnet/Ruby or Quartz/Diamond.

The brief calls Abyssal Crystal T6; the shipped `registry.lua` entry has
`harvest_tier = 5`. These proposals preserve the item and change no tier.
No design decision is needed in this art lane.

User checklist on both desktop and web target screens, browser at 100%:
read the native inventory strips; compare Tin/Iron/Steel/Silver/Silversteel;
check empty settings, T3 copper and T5/T6 gold trim; identify Garnet versus
Ruby, rough versus cut, Quartz versus Diamond, and Abyssal Crystal; inspect
the repeated and mixed block walls. The page is a software art preview,
not a Luanti capture. Actual client rendering remains for the later
installation lane and the user's GUI test.

## Licence

Original candidate media: **CC0-1.0**, to the extent rights exist.
Python generators: **GPL-3.0-or-later**. Existing comparison art retains
**CC BY-SA 3.0**; shipped armour/trinket context retains its existing CC0
provenance. Full paths and attribution: [LICENSE-media.md](LICENSE-media.md).

## Commit receipt

- Base: `23620af384a33b97183552df76062cbfb2fd9aff`, branch `r68-icons`.
- Original art: `bb3c5128`.
- Final reviewed art/generator/preview content:
  **`3d38607a23b82c370e5ad136ef8f1f0291b9af32`**.
- At that content commit, `git status --porcelain` returned **empty**.
- This report is a documentation-only receipt after that content commit.
  The final branch-tip hash and final clean-tree check are emitted in the
  runner's `last.md`/final response after committing this report; a committed
  file cannot contain its own containing commit's hash.
- Every lane commit ends with
  `Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.

The following tables are copied verbatim from the generated measurement
summary for review alongside this report. All pairwise values are in
[measurements.json](measurements.json) and the preview's expandable tables.

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

## Rough versus cut

| Gem | Old ΔE | A ΔE | B ΔE |
|---|---:|---:|---:|
| Citrine | 31.73 | 20.46 | 34.10 |
| Jade | 28.85 | 13.76 | 17.13 |
| Garnet | 41.32 | 13.39 | 19.46 |
| Sapphire | 38.10 | 17.72 | 22.42 |
| Ruby | 38.96 | 17.79 | 31.28 |
| Diamond | 22.89 | 24.29 | 31.12 |

## Known weak pairs, before and after

| Pair | Old ΔE | A ΔE | B ΔE |
|---|---:|---:|---:|
| Tin Bar / Steel Bar | 2.96 | 8.36 | 9.27 |
| Silver Bar / Silversteel Bar | 6.19 | 17.76 | 16.98 |
| Iron Bar / Silversteel Bar | 10.20 | 31.55 | 32.33 |
| Copper Bar / Bronze Bar | 17.84 | 16.01 | 16.63 |
| Rough Garnet / Rough Ruby | 8.04 | 31.31 | 19.66 |
| Cut Garnet / Cut Ruby | 3.85 | 32.63 | 31.85 |
| Quartz / Cut Diamond | 6.20 | 31.76 | 28.12 |
