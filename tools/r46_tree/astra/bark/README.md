# Jungle bark candidates — ASTREE, round 4

Six original alternatives for jungle and giant kapok wood, all deep,
saturated red-brown with visible raised grain and matching end grain.
Each pair is **16 × 16 RGBA, fully opaque**, with matching opposite edges
in both directions. Upgrade classification: **compatible**; these are
review assets under `tools/`, with no runtime or saved-state change.

Rounds 2–3 (A–L) were tried and removed at the user's request; Git history preserves them.

| ID | Idea | Bark / end grain |
| --- | --- | --- |
| M — Deep russet ridges | Broad overlapping ridges in deep red-brown, with warm raised edges and a rich russet cut. | [side](jungle_bark_m.png) / [top](jungle_bark_m_top.png) |
| N — Mahogany plates | The darkest base: near-mahogany plates with wine-brown shadows, small copper highlights and a dark warm cut. | [side](jungle_bark_n.png) / [top](jungle_bark_n_top.png) |
| O — Fine red grain | Three fine, uneven strands in saturated red-brown with close-toned growth rings. | [side](jungle_bark_o.png) / [top](jungle_bark_o_top.png) |
| P — Split russet | Strong russet ribs with branching deep furrows, broken warm crests and a split red-brown cut. | [side](jungle_bark_p.png) / [top](jungle_bark_p_top.png) |
| Q — Moss in red folds | M's deep russet with two tiny fresh-green moss pockets in the hollows; the cut stays clean. | [side](jungle_bark_q.png) / [top](jungle_bark_q_top.png) |
| R — Liana over red folds | Quiet dark red-brown folds crossed by one thin fresh-green liana, meeting the bark rim of the cut. | [side](jungle_bark_r.png) / [top](jungle_bark_r_top.png) |

M–P are plain bark. Green covers **6 of 256 side pixels (2.34%)** in Q
and **16 (6.25%)** in R. Q shares M's palette and grain to isolate the
moss choice. The new brown pixels average 47–55 on the weighted sRGB
luma scale (0–255), with 65–75% mean HSV saturation; these are descriptive
palette measurements, not lighting or acceptance gates.

[preview-r4.png](preview-r4.png) keeps the original two-column,
three-row card layout. Each card compares the new candidate with today's
bark in 4 × 4 repeats and identical 2 × 2 stepped-column-and-limb
mock-ups. Enlarged side/end-grain/leaf swatches and a native-pixel repeat
show the close and distant texture read. All mock-ups use the same
geometry, fixed face lighting and existing `default_jungleleaves.png`;
bark grain follows the limb. They are software material studies, not
engine screenshots. Sampling and scaling use nearest-neighbour only.

Reproduce with installed Python 3, Pillow and NumPy; nothing is downloaded:

```sh
python3 tools/r46_tree/astra/bark/generate.py
python3 tools/r46_tree/astra/bark/generate.py --check
```

The generator contains the original pixel maps, palettes and end-grain
painting and produces only M–R and `preview-r4.png`. `--check` writes
nothing: it compares every saved output pixel and checks each pair's size,
RGBA mode, opacity and both opposite edges.

Validation on 2026-10-13: `--check` passed for all twelve textures and
the preview; the exact PNG file list, per-file licence rows, local links
and green coverage passed inspection. Side and end-grain repeats,
native-pixel swatches and software mock-ups were visually inspected.
`python3 tools/check_fresh_server.py` passed, and the full
`tools/run_fixtures.sh` run passed **172/172** fixtures (LuaJIT,
`JOBS=4`, idle CPU/I/O scheduling). No engine run or seed fleet applies
to this material-only proposal.

The twelve candidate PNGs and their authored pixel maps/palettes are
dedicated to **CC0 1.0 Universal**. No existing texture pixels enter a
candidate. The comparison sheet contains existing media and retains
**CC BY-SA 3.0 Unported**; per-file provenance is in
[LICENSE-media.md](LICENSE-media.md). Generator/rendering code follows
the repository's GPL-3.0-or-later licence.

Visual acceptance on the 3D trees remains with the user; the coordinator's
independent review is open. No agent was launched for this task.
