# Jungle bark candidates — ASTREE, rounds 2 and 3

Twelve original alternatives for jungle and giant kapok wood; none is
installed. The user chose **B — Russet ridges** as the colour direction
after seeing A–F on the 3D trees. Round 3 offers G–L for the next pick,
all on a brown or red-brown base. Each pair is **16 × 16 RGBA, fully
opaque**, with matching opposite edges in both directions.
Upgrade classification: **compatible**;
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

Round 3 (2026-10-13):

| ID | Idea | Bark / end grain |
| --- | --- | --- |
| G — Quiet russet | B refined into calmer red-brown ridges with soft shoulders and a warm, lower-contrast cut. | [side](jungle_bark_g.png) / [top](jungle_bark_g_top.png) |
| H — Deep chestnut | Darker, warmer chestnut with broad copper-brown plates and a deeper toasted cut. | [side](jungle_bark_h.png) / [top](jungle_bark_h_top.png) |
| I — Moss in the folds | Quiet russet with two tiny, fresh-green moss pockets in the furrows; the cut stays clean. | [side](jungle_bark_i.png) / [top](jungle_bark_i_top.png) |
| J — Single green thread | Warm brown ridges with one bright, single-pixel liana, ending at the bark rim of the cut. | [side](jungle_bark_j.png) / [top](jungle_bark_j_top.png) |
| K — Fine red grain | Cinnamon-red bark with finer, softly broken grain and close-toned growth rings. | [side](jungle_bark_k.png) / [top](jungle_bark_k_top.png) |
| L — Lichen freckles | Soft terracotta-brown ridges with a few small green lichen flecks and a warm amber cut. | [side](jungle_bark_l.png) / [top](jungle_bark_l_top.png) |

Green coverage on the 256-pixel side tiles is **8 pixels (3.1%)** for I,
**16 pixels (6.25%)** for J and **5 pixels (2.0%)** for L; G, H and K have
none. I and J use G's brown palette to isolate the accent choice.

[preview-r3.png](preview-r3.png) keeps the two-column, three-row card
layout of round 2. Each card adds **B as a third comparison** beside the
new candidate and today's bark, both in 4 × 4 repeats and in the identical
column-and-limb mock-up. The swatches also show B's end grain. A–F and
`preview.png` remain byte-for-byte unchanged from `3be91d85`.

Reproduce with installed Python 3, Pillow and NumPy; nothing is downloaded:

```sh
python3 tools/r46_tree/astra/bark/generate.py
python3 tools/r46_tree/astra/bark/generate.py --check
```

The generator contains the original pixel maps, palettes and end-grain
painting. `--check` writes nothing: it compares all saved output pixels and
checks each pair's size, RGBA mode, opacity and both opposite edges.
Round-2 validation on 2026-10-13: `--check` passed; the full
`tools/run_fixtures.sh` run passed **172/172** fixtures.
Round-3 validation on 2026-10-13: `--check` passed for all 24 textures
and both previews; A–F and the original preview passed the byte comparison
against `3be91d85`; every PNG has a licence row and local documentation
links resolve. The full `tools/run_fixtures.sh` run passed **172/172**
fixtures (LuaJIT, `JOBS=4`, idle CPU/I/O scheduling). The tiled repeats,
native-pixel swatches and software mock-ups were visually inspected.

The twenty-four candidate PNGs and their authored pixel maps/palettes are
dedicated to **CC0 1.0 Universal**. No existing texture pixels enter a candidate.
Only the comparison sheets contain existing media and retain **CC BY-SA
3.0 Unported**; per-file provenance is in [LICENSE-media.md](LICENSE-media.md).
Generator/rendering code follows the repository's GPL-3.0-or-later licence.

Visual basis: the local bark/leaf textures, the read-only TREE concept
viewer (`tools/r46_tree/concept/` on `r46-tree`) and the shared tree concept
specification. This folder does not depend on that other worktree to build.
