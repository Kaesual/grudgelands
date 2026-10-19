# Round 51 ARTS — Sea textures

Eleven original **16 × 16 RGBA** textures, drawn by GPT-6 Astra on
2026-10-19 for the [sea plan](../../docs/planning/round51-sea-plan.md),
§3 ruling 7 and §5a. The pixel grids, palettes, timber grain and lettering
are authored in [sea_art.py](sea_art.py); the new textures contain no
source pixels from existing artwork. Original assets are **CC0-1.0**.

[preview.png](preview.png) shows every new texture at **1× and 4×** on light
and dark backgrounds, three depth comparisons of a meadow beside default
kelp and coral on default sand, tiled walls and decks, six- and twelve-node
masts fully submerged and crossing the surface, and the details on planks.
All scaling is nearest-neighbour. These are front and top views for art
review; the WRECK lane supplies the actual crossed-quad and wreck preview.

## Generate and check

From the repository root, with installed Pillow (created with 12.3.0):

```sh
python3 -I tools/r51_sea/sea_art.py
python3 -I tools/r51_sea/sea_art.py --check
```

The first command writes only the eleven PNG textures and `preview.png`
beside the generator. The second writes nothing: it regenerates in memory
and compares each checked-in image's dimensions, mode and complete pixel
content. Both check 16 × 16 RGBA, four fully opaque blocks, binary alpha
on every extension, zero RGB in transparent texels, identical first and
last mast rows, and four continuous centred mast columns. There is no
random seed, network access, external font or engine dependency.

The preview alone reads `default_sand.png`, `default_kelp.png`,
`default_coral_green.png`, `default_tree.png`, `default_tree_top.png` and
`default_water.png` from `mods/BASE/default/textures/`. It is **CC BY-SA 3.0**
because it includes those references; the separate new textures remain CC0.
Full attribution, pinned source links and modifications are in
[LICENSE-media.md](LICENSE-media.md).

## Art and integration notes

- Use all three seagrass variants together: a fine upright bunch, a lower
  swept bunch and an open fan. They occupy the bottom 12, 10 and 11 pixels
  respectively, with separate fine blades and no central kelp stalk. They
  are intended as one-node rooted extensions above a full sand base.
- The planks have four horizontal boards, staggered joints and subdued
  long grain. The algae variant keeps the same boards underneath irregular
  olive films, including a patch wrapped across the texture edges. Both
  images are opaque on every pixel and can cover every face of a full cube.
- **Recommend both optional log textures for keel and ribs.** The side is
  hewn, weathered timber in the planks' palette; the end has dull growth
  rings and splits. The default bark is dark enough, but its pale cut end
  looks newly sawn next to the wreck wood (comparison in the preview).
- The mast occupies columns 6–9 (zero-based), four pixels wide, continuously
  from top to bottom. It has no cap, crossbar, fittings or rope band that
  would repeat at every node. Its top and bottom RGBA rows match exactly.
  WRECK can use the rooted extension with vertical texture repetition;
  six and twelve nodes correspond to leveled values 96 and 192. The
  comparison gives each surface-crossing mast three nodes in air.
- Rope, sail and wood algae are one-node rooted extensions on full plank
  bases. The rope is a small upright coil with a frayed loose end; the
  sail hangs in torn strips from a short broken peg anchored at the base;
  the algae forms a branching tuft. Their silhouettes touch the bottom
  edge, so they sit on the base rather than floating. Two crossed quads
  will duplicate each silhouette; there are no sideways mast attachments.

The depth comparison samples the mean RGB of `default_water.png`
(26, 128, 222). At illustrative depths 4 / 10 / 20, RGB is blended with
that colour at 15 / 30 / 46 percent, then multiplied by 0.92 / 0.76 / 0.57.
Alpha is preserved. These are explicit art-preview tints, not a simulation
of engine lighting or a proposed depth-colour rule. The new PNGs contain
their untinted palettes; nothing bakes water into the block faces.

**Upgrade classification: compatible, art tooling only.** This lane changes
no runtime file, Lua, node registration or upgrade declaration. SEA owns
seagrass placement; WRECK owns wreck nodes, drops and integration after the
user's pick. The round's placement/reset decisions remain in the sea plan.
No fixtures or engine runs are required by this lane's brief. Runtime
appearance on desktop and web remains for the integrating lanes and user.

## FA — swaying seagrass and kelp

Follow-up art by GPT-6 Astra, 2026-10-19, for
[the follow-up plan, §3 option B](../../docs/planning/round51-followup-plan.md#3-decision-for-the-user-how-seagrass-and-kelp-move).
The four candidate strips await the user's pick; lane FW owns integration.
The existing art and shipped textures are unchanged.

| Strip | Frames | PNG size | Proposed loop | Motion |
| --- | --- | --- | --- | --- |
| [seagrass_1_anim.png](anim/seagrass_1_anim.png) | 8 | 16 × 128 | 3.2 s | Fine upright blades; the original palette and three bottom rows stay fixed. |
| [seagrass_2_anim.png](anim/seagrass_2_anim.png) | 8 | 16 × 128 | 3.2 s | The shorter swept bunch, with its own phase on the shared clock. |
| [seagrass_3_anim.png](anim/seagrass_3_anim.png) | 8 | 16 × 128 | 3.2 s | The open fan, with delayed bends along its blades. |
| [kelp_anim.png](anim/kelp_anim.png) | 8 | 16 × 128 | 3.2 s | Original olive/yellow-green stalk, sparse alternating leaves and a travelling bend. |

Frames run top to bottom, each **16 × 16**, for `vertical_frames` with
`aspect_w = 16`, `aspect_h = 16` and `length = 3.2` (400 ms per frame).
Each strip has eight distinct frames. Source texels move by at most one
pixel per step, including frame 8 → 1, and stay within one pixel either
side of their original positions. Diagonal connections are repaired with
whole pixels; alpha stays 0/255 and transparent RGB stays zero. The three
seagrass variants retain their exact four-colour palette and stationary
bottom three rows, with different phases to break up a mixed meadow.

Kelp has equal top and bottom RGBA rows in **every** frame and a continuous
two-pixel stem across all joins, checked through 15 repeats. Its wave repeats
once per node; every segment and both preview stalks use the same frame.
There is no per-segment phase offset or repeated end cap.

[preview.png](anim/preview.png) labels all 32 frames side by side at 4×.
The three seagrass GIFs are 64 × 64, and [kelp_anim.gif](anim/kelp_anim.gif)
is a six-node stalk at 4× (64 × 384).
[meadow.gif](anim/meadow.gif) mixes ten grass tufts and two kelp stalks,
six and five nodes high, on original sand under an illustrative water tint
(640 × 496, 4×). These are flat art previews, not engine screenshots.
All five GIFs loop every 3.2 s with nearest-neighbour pixels and a shared,
exact palette per GIF, without dithering. All new previews are CC0: they
use only our own art, sand, water colours and original pixel lettering.

```sh
python3 -I tools/r51_sea/anim_art.py
python3 -I tools/r51_sea/anim_art.py --check
```

The generator writes only the ten files in `anim/`. The check writes
nothing and verifies the checked-in files against regeneration, dimensions,
alpha, palette, connected blades/leaves, fixed grass roots, temporal wrap,
kelp joins, and decoded GIF frames, duration and infinite-loop metadata.
Every loop's final step changes no more texels than its largest interior
step. **Compatible, art tooling only**; no fixtures or engine runs for FA.
The user's selection and the desktop/web runtime checks remain with FW.

## Media

The project dedicates any rights it holds in the eleven original textures
and the original generator/lettering to
[CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).
Each texture's author is GPT-6 Astra; source: [sea_art.py](sea_art.py).

| File | Idea | License |
| --- | --- | --- |
| [seagrass_1.png](seagrass_1.png) | Fine upright olive blades, with open water between them. | CC0-1.0 |
| [seagrass_2.png](seagrass_2.png) | A shorter, swept bunch for uneven meadow height. | CC0-1.0 |
| [seagrass_3.png](seagrass_3.png) | An open fan of slender green-olive blades. | CC0-1.0 |
| [wreck_planks.png](wreck_planks.png) | Soaked grey-brown ship boards with long grain and staggered joints. | CC0-1.0 |
| [wreck_planks_algae.png](wreck_planks_algae.png) | The same boards with irregular olive algae films. | CC0-1.0 |
| [wreck_log.png](wreck_log.png) | Dull hewn timber with lengthwise grain for keel and ribs. | CC0-1.0 |
| [wreck_log_top.png](wreck_log_top.png) | A dark cut end with growth rings and radial splits. | CC0-1.0 |
| [wreck_mast.png](wreck_mast.png) | A narrow weathered pole with seamless vertical repetition. | CC0-1.0 |
| [wreck_rope.png](wreck_rope.png) | A faded rope coil and frayed loose end. | CC0-1.0 |
| [wreck_sail.png](wreck_sail.png) | Perforated old canvas in hanging strips on a broken peg. | CC0-1.0 |
| [wreck_algae.png](wreck_algae.png) | A low branching green tuft attached to wreck wood. | CC0-1.0 |
| [preview.png](preview.png) | Scales, backgrounds, depth tints and placement comparisons; original contributions CC0, referenced default textures retain their licence. | CC BY-SA 3.0 for the composite |

### FA animation media

The project dedicates any rights it holds in every file below to
[CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).
Author: **GPT-6 Astra**, 2026-10-19. Source for all generated files:
[anim_art.py](anim_art.py). The grass strips animate our CC0 originals
listed above; kelp, sand and water are newly authored. The labels reuse
our CC0 lettering from [sea_art.py](sea_art.py). No third-party artwork
is included in these files.

| File | Original work / modifications | Exact license |
| --- | --- | --- |
| [anim_art.py](anim_art.py) | Authored kelp, deterministic pixel motion, sand, water, preview layout and validation. | CC0-1.0 |
| [anim/seagrass_1_anim.png](anim/seagrass_1_anim.png) | Eight swaying poses of our fine upright bunch; original colours and roots preserved. | CC0-1.0 |
| [anim/seagrass_2_anim.png](anim/seagrass_2_anim.png) | Eight swaying poses of our low swept bunch; original colours and roots preserved. | CC0-1.0 |
| [anim/seagrass_3_anim.png](anim/seagrass_3_anim.png) | Eight swaying poses of our open fan; original colours and roots preserved. | CC0-1.0 |
| [anim/kelp_anim.png](anim/kelp_anim.png) | New olive stalk and leaves, eight vertically seamless rippling poses. | CC0-1.0 |
| [anim/preview.png](anim/preview.png) | All animation frames, nearest-neighbour enlargement, checkerboard and original lettering. | CC0-1.0 |
| [anim/seagrass_1_anim.gif](anim/seagrass_1_anim.gif) | Upright bunch on checkerboard, enlarged 4×, timed loop. | CC0-1.0 |
| [anim/seagrass_2_anim.gif](anim/seagrass_2_anim.gif) | Swept bunch on checkerboard, enlarged 4×, timed loop. | CC0-1.0 |
| [anim/seagrass_3_anim.gif](anim/seagrass_3_anim.gif) | Open fan on checkerboard, enlarged 4×, timed loop. | CC0-1.0 |
| [anim/kelp_anim.gif](anim/kelp_anim.gif) | Six synchronous stalk segments on checkerboard, enlarged 4×, timed loop. | CC0-1.0 |
| [anim/meadow.gif](anim/meadow.gif) | Mixed grass and two synchronous kelp stalks, original sand/water, tint and labels, enlarged 4×. | CC0-1.0 |
