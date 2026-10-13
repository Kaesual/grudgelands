# Jungle bark candidates — ASTREE, round 2

Six original alternatives for jungle and giant kapok wood; none is selected
or installed. Each pair is **16 × 16 RGBA, fully opaque**, with matching
opposite edges in both directions. Upgrade classification: **compatible**;
these are review assets under `tools/`, with no runtime or saved-state change.

| ID | Idea | Bark / end grain |
| --- | --- | --- |
| A — Kapok ash | Warm pale-grey bark with broad smooth areas and sparse sage lichen. | [side](jungle_bark_a.png) / [top](jungle_bark_a_top.png) |
| B — Russet ridges | Dark red-brown bark with broad overlapping ridges and a warm cut. | [side](jungle_bark_b.png) / [top](jungle_bark_b_top.png) |
| C — Moss islands | Cool weathered bark with clustered olive moss in the hollows. | [side](jungle_bark_c.png) / [top](jungle_bark_c_top.png) |
| D — Broad flutes | Deep narrow furrows between wide, gently turning umber buttress ribs. | [side](jungle_bark_d.png) / [top](jungle_bark_d_top.png) |
| E — Climbing vines | Quiet cocoa bark crossed by one slender winding green vine. | [side](jungle_bark_e.png) / [top](jungle_bark_e_top.png) |
| F — Quiet olive | A restrained olive-brown alternative with fewer, softer vertical folds. | [side](jungle_bark_f.png) / [top](jungle_bark_f_top.png) |

[preview.png](preview.png) places every candidate's 4 × 4 repeat beside
today's bark, plus enlarged side/end-grain/leaf swatches, a native-pixel
repeat and paired 2 × 2 stepped-column-and-limb mock-ups. All mock-ups use
the same geometry, lighting and existing jungle leaves; bark grain follows
the limb. They are software material studies, not engine screenshots.
Texture sampling and scaling use nearest-neighbour only.

Reproduce with installed Python 3, Pillow and NumPy; nothing is downloaded:

```sh
python3 tools/r46_tree/astra/bark/generate.py
python3 tools/r46_tree/astra/bark/generate.py --check
```

The generator contains the original pixel maps, palettes and end-grain
painting. `--check` writes nothing: it compares all saved output pixels and
checks each pair's size, RGBA mode, opacity and both opposite edges.
Validation on 2026-10-13: `--check` passed; the full
`tools/run_fixtures.sh` run passed **172/172** fixtures.

The twelve new PNGs and their authored pixel maps/palettes are dedicated
to **CC0 1.0 Universal**. No existing texture pixels enter a candidate.
Only the comparison sheet contains existing media and retains **CC BY-SA
3.0 Unported**; per-file provenance is in [LICENSE-media.md](LICENSE-media.md).
Generator/rendering code follows the repository's GPL-3.0-or-later licence.

Visual basis: the local bark/leaf textures, the read-only TREE concept
viewer (`tools/r46_tree/concept/` on `r46-tree`) and the shared tree concept
specification. This folder does not depend on that other worktree to build.
