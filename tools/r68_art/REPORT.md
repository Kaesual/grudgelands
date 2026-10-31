# Round 68 ART — standing sign, waypost and notice board

Delivered on `r68-art`, from
`b649e70783787f38ca384fdaea02e7a6e8c93fd3`.

Open the [offline preview](preview/index.html) or the
[six-candidate contact sheet](preview/contact.png).

## Recommendations

| Sign | A | B | Recommendation |
|---|---|---|---|
| Standing sign | Plain plank on a slim post, matching the existing wall sign's board size. | Narrow timber frame and a thicker post, with the same clear writing area. | **A**, closest to the existing sign and clearest in a small inventory slot. |
| Waypost | Narrow pointed plank. | Broader carved arrow with clipped tail corners. | **B**, a stronger direction silhouette from either reading side. |
| Notice board | Open timber frame on two posts. | Same board with a small pitched wooden roof. | **B**, a public-board silhouette with an uncluttered writing surface. |

All six models use original warm timber textures. Grain inside writing
areas is deliberately low contrast, without knots, carvings or nails.
Sample text is a separate plane in the previews and never part of a
candidate model, texture or inventory icon.

## Model and texture sizes

All faces are explicitly triangulated; vertex counts are the unique OBJ
position records. Normals and UV coordinates are separate records. No
animation is needed for these static node meshes.

| Candidate | Vertices | Triangle faces | Model extent X × Y × Z, nodes | Atlas | Inventory |
|---|---:|---:|---|---|---|
| `sign_standing_a` | 16 | 24 | 0.875 × 1 × 0.1875 | 64 × 64 | 16 × 16 |
| `sign_standing_b` | 36 | 72 | 0.9375 × 1 × 0.25 | 64 × 64 | 16 × 16 |
| `waypost_a` | 106 | 156 | 0.125 × 1 × 1 | 64 × 64 | 16 × 16 |
| `waypost_b` | 110 | 164 | 0.125 × 1 × 1 | 64 × 64 | 16 × 16 |
| `notice_board_a` | 44 | 84 | 2 × 1.5 × 0.25 | 64 × 64 | 16 × 16 |
| `notice_board_b` | 56 | 108 | 2 × 1.6875 × 0.5 | 64 × 64 | 16 × 16 |

The [generated manifest](manifest.json) also records the full bounds.
Each candidate has an OBJ, MTL, atlas PNG, `_inv.png` and JSON: **30 files**.

## Integration contract

Every model uses **one texture slot**, group/material `wood`, referencing
the matching PNG. The matching MTL is included for ordinary OBJ viewers;
the receiving lane assigns that PNG as the node's first tile. Atlases are
64 × 64 RGBA, fully opaque. Their UVs maintain **16 texels per node**;
64 atlas pixels are not stretched over one node. Icons are **16 × 16 RGBA**
with binary alpha; the page enlarges those exact pixels to 32 × 32.

The OBJ coordinates are node units. The ground is `y = -0.5`. Standing
signs face `-Z`. Notice boards also face `-Z`, with their origin at the
centre of the **left base node as seen from the front**; the second node
is at `[1, 0, 0]`. Both notice variants are exactly two nodes wide.
Their heights from the ground are **A: 1.5 nodes**, **B: 1.6875 nodes**.
Their top portions require headroom above both base nodes.

The waypost's **arrow points along -Z**, so its reading faces necessarily
face **-X and +X**. This is the geometric exception to the general
front-faces--Z convention: a flat arrow cannot both point along its face
normal and carry a lengthwise town name. The question was raised during
the lane; absent an override, the direct arrow-to-node-facing convention
is used. Each JSON records `arrow_direction`, both outward normals and
both reading-right vectors, so the back reads correctly without mirroring.

The waypost has a centred 24-sided post of radius 1/16 node, running
exactly from `y = -0.5` to `+0.5`. Its colour is constant across the join,
with no caps or collars extending beyond the node. The arrow passes
through a mortise in the post, so neither text face is hidden by the pole.
Consecutive arrows have vertical clearance **A: 0.75**, **B: 0.625 nodes**.
Faceting changes the circular profile by at most **0.000535 node**, less
than **0.009 wood texel**, between arbitrary rotations. The end planes
meet exactly; this small radial faceting is disclosed rather than claiming
an analytically rotation-invariant low-polygon cylinder.

Each JSON includes suggested **model-local** selection/collision boxes.
The integration lane owns rotated boxes and two-node occupancy/headroom.
The small signs are proposed as non-walkable; their collision shapes are
available if the gameplay lane chooses otherwise. Notice boards are
proposed as walkable. These are suggestions, not runtime changes.

## Text-area specifications

Centres already include the **0.003-node outward offset** from the wooden
surface; do not add it a second time. Width and height describe the clear
rectangle, not a requirement to stretch a texture to that size. `up` is
`[0, 1, 0]` in every spec.

| Candidate / face | Centre (X, Y, Z) | Width × height | Outward normal | Reading right |
|---|---|---|---|---|
| [Standing A](candidates/sign_standing_a.json) | `(0, 0.1875, -0.09675)` | 0.8125 × 0.5 | `(0, 0, -1)` | `(1, 0, 0)` |
| [Standing B](candidates/sign_standing_b.json) | `(0, 0.1875, -0.128)` | 0.8125 × 0.5 | `(0, 0, -1)` | `(1, 0, 0)` |
| [Waypost A](candidates/waypost_a.json), [B](candidates/waypost_b.json), front | `(-0.0655, 0.25, 0.09375)` | 0.75 × 0.14 | `(-1, 0, 0)` | `(0, 0, -1)` |
| Waypost A/B, back | `(0.0655, 0.25, 0.09375)` | 0.75 × 0.14 | `(1, 0, 0)` | `(0, 0, 1)` |
| [Notice A](candidates/notice_board_a.json), [B](candidates/notice_board_b.json) | `(0.5, 0.5, -0.0655)` | 1.75 × 0.875 | `(0, 0, -1)` | `(1, 0, 0)` |

Standing signs have four lines of fifteen characters; wayposts one line of
fourteen on each side; notice boards seven lines of thirty. The generator
verifies these full capacities at the shared preview font scale, as well
as checking that the corners and centre of each text rectangle have a
wooden face directly behind them.

## Preview and reproducibility

The preview has front, angled and rear views of all six models; sample
lettering on every writing side; three wayposts stacked at different
angles for each variant; both families beside the existing wall sign and
wooden chest at one shared scale; inventory icons at 16 and 32 px; all
atlases at 8×; and the recommendations at the top. All images are adjacent
to the HTML and use relative paths. There are no scripts or external
resources. The two scale strips scroll on narrow screens.

The preview font keeps its original bitmap pixels at **0.0075 node per
pixel**, seven-pixel character advance and fourteen-pixel line advance
(**0.105 node**), identical across signs. Four lines use 0.42 node,
seven use 0.735 node. Lettering is neither stretched nor enlarged to fill
larger boards. The runtime TEXT lane owns wrapping and its final spacing.
These are software projections, not engine captures.

From the repository root:

```sh
python3 tools/r68_art/generate.py
python3 tools/r68_art/generate.py --check
```

Python 3, Pillow and numpy are the only dependencies. The generator also
works by absolute path from another directory. The saved font input is
preview-only; [the media ledger](LICENSE-media.md) records its exact source
and the existing comparison textures. Original art is **CC0-1.0**, the
generator **GPL-3.0-or-later**. No external generation service is needed.

## Verification

Verified with **Python 3.14.8, Pillow 12.3.0 and numpy 2.4.6**.
`--check` regenerated **67 outputs** in memory and compared every byte:
30 candidate files, 12 exact preview copies, 18 individual model views,
two stacked views, two comparison strips, a contact sheet, an HTML page
and a manifest. It rejects missing, differing or unexpected generated files.

The same run checked exact 16-texel UV density on every face, finite
geometry/UVs, outward normals, serialized OBJ triangle indices/winding,
text-plane support and full character capacities, opaque atlases,
16px icons with binary alpha, identical preview copies and local HTML
links. The report and media-ledger links and Python syntax were also
checked. Front, angled and rear views, the stack, shared-scale comparison
and enlarged icons were visually inspected. These are art checks, not
runtime fixtures or browser/engine acceptance.

## Scope and remaining review

**Upgrade classification: compatible.** This package adds development
assets only. No runtime code, saved state, world generation, game version
or upgrade declaration changes. No file under `mods/` was changed.
No Lua, fixtures, game server, engine boot, sync, merge or push was run.

The wall-sign board dimensions and the reference font's provenance were
confirmed against local files. The two open `TODO-*.md` files concern
other work; the upstream workaround list requires no change for this lane.
The reference submodules remain untouched.

## Blockers / questions

The user's A/B picks and independent coordinator review remain open.
This implementer did not launch a reviewer or claim review acceptance.

After integration, the user's **desktop and web** GUI check should cover:

1. Write four full lines on the standing sign and seven on the notice
   board; compare glyph scale with the existing wall sign.
2. Read both faces of the waypost; confirm the back is not mirrored.
3. Stack three wayposts at different rotations, including adjacent 1.5°
   settings; inspect the pole joins, arrow clearance and text attachment.
4. Place and rotate the notice board from its left node; check the second
   node, headroom, selection and collision.
5. Inspect the silhouettes, texture filtering and ink contrast nearby and
   from a few metres, in daylight and indoor light, and icons at 16/32 px.
