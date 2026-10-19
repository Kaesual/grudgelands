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
