# Round 68 ART — wood texture proposals

## Pass 3 — wood texture

**Recommendation: B, warm heartwood, for the complete set.** Its warmer
boards, stronger frame edges and roof grain sit closer to the wooden
chest. A is the quieter, more muted alternative. Both keep soft grain in
the writing fields. These texture A/B labels do not change the user's
model picks: **standing sign A, waypost B, notice board B**.

Worktree/branch: `r68-art3`, from main
`0a1ada42028138d5f41f703cd5b4f6f5f66b670a`.

Open the [offline preview, pass 3](preview/index.html#wood).
The recommendation and new section are first. Each sign, including the
wooden wall sign, has shipped/A/B columns with front and angled views,
the same sample text, and flat textures at exactly 8× (scrollable).
The waypost also has a reverse reading view. Matching model icons appear
at native 16 px and nearest-neighbour 32 px.

| Set | Character | Whole family at one scale |
|---|---|---|
| Shipped at pass-3 start | Existing pass-1 model textures and pass-2 wooden wall tile. | [Shipped](preview/wood_scale_shipped.png) |
| A — planed timber | Muted golden boards, restrained long grain, modest edge shading. | [Set A](preview/wood_scale_a.png) |
| **B — warm heartwood** | Honey-coloured boards, richer grain, deeper frame and roof seams. | [Set B](preview/wood_scale_b.png) |

All three strips show the wooden chest, a plank block, the wall sign and
all three picked signs at **169 pixels per node**. Chest/plank source
pixels are comparison assets only. Candidate grain is newly drawn, with
the reference palette and pixel treatment; no source pixels are copied.
The baseline previews use the unchanged prior candidates, verified
byte-identical to the shipped files at this branch's base. They remain a
stable comparison after a candidate is integrated.

### Candidate handoff

| Candidate stem, followed by `_a.png` or `_b.png` | Runtime texture to replace | Size |
|---|---|---|
| `sign_standing_wood` | `grug_signs_standing.png` | 64 × 64 RGBA |
| `waypost_wood` | `grug_signs_waypost.png` | 64 × 64 RGBA |
| `notice_board_wood` | `grug_signs_notice_board.png` | 64 × 64 RGBA |
| `sign_wall_wood` | `default_sign_wall_wood.png` | 16 × 16 RGBA |

All are in [candidates/](candidates/). The first three also have matching
`_a_inv.png` and `_b_inv.png` candidates, **16 × 16 RGBA**, rendered from
the unchanged unlettered model. For example,
`sign_standing_wood_b_inv.png` replaces `grug_signs_standing_inv.png`.
The wall inventory/wield icon remains suitable and is unchanged. The iron
wall texture and icon are outside this pass and unchanged.

**Four textures and three matching icons per set: 14 new candidate files.**
The [wood manifest](wood_manifest.json) records the replacements, sizes,
writing-field colour bounds, preview text metrics and frozen baseline
hashes. Each candidate has its own row in the [media ledger](LICENSE-media.md).
Original candidates are **CC0-1.0**, the generator **GPL-3.0-or-later**;
comparison strips retain the chest/plank **CC-BY-SA-3.0** licence.

### Wood and reading surfaces

The front boards have staggered, lengthwise grain and slight tone changes
between planks. Strong seams stay on frames, roof and backs. Small knots
occur only on backs and roof planks. Square posts and vertical stiles have
vertical grain; horizontal rails and roof boards follow their long axis.
The arrow keeps darker top/bottom edges. Its two reading faces share a
reversed UV patch: their protected rectangles together cover the entire
patch width, so no dark tip accent is painted into either writing area.

The protected writing texels span at most **14 RGB levels per channel in
A, 19 in B** across the set; the variation comes from broad, soft grain,
not isolated letter-like marks. B's darkest protected colour is
`#B58B51`, its lightest `#C89E64`. The wall sign's entire front interior
uses the same calm treatment. All glyphs retain **`#2B1E14`** ink.

Pass 3 uses the actual shipped text metrics from
`mods/CORE/grug_text/layout.lua`: **6 × 12 pixel cells**, **1/128 node per
pixel**, centred on the power-of-two canvas, with the runtime **1/64-node
surface offset**. The existing saved glyph snapshot was checked against
the shipped glyph pixels: all 94 printable non-space ASCII characters
match. The earlier previews retain their original provisional 7 × 14
metrics; only the new section represents the shipped text layout.
Lettering is always a separate preview plane, never painted into an asset.

### Round post and fixed models

The [three-waypost stack](preview/wood_stack_b.png) uses rotations
**−115.5°, −84°, +61.5°**, at one-node intervals. Both joins have separate
[lower](preview/wood_join_b_1.png) and [upper](preview/wood_join_b_2.png)
close-ups at **1100 pixels per node**, with the boundary at image centre.
The same views exist for A and the shipped baseline.

**Fixed-UV limitation:** all 24 round-post side faces share one atlas
column; each facet spans only about 0.26 of a texel horizontally. Distinct
painted vertical fibres cannot be encoded in this layout. Varying the
column down its height would create horizontal bands. Consequently its
sample remains uniform along the entire height and around the post, caps
and gutters included, in each set. The unchanged facets provide the
vertical shading. This preserves rotation-independent texture continuity;
there are no added rings, knots or colour jumps at joins. The original
sub-texel faceting remains (maximum radial difference **0.000535 node**).

No model, UV, text-area JSON, model dimension, material slot or texel
density changed. The picked meshes still have **16 / 110 / 56 vertices**
and **24 / 164 / 108 triangles**, respectively; all retain 16 texels per
node. The wall's crop, thin-edge row and alpha layout stay fixed. Original
one-pixel atlas gutters are repainted by extending the corresponding
patch edges.

### Verification and delivery

Run from the repository root:

```sh
python3 tools/r68_art/generate.py
python3 tools/r68_art/generate.py --check
git diff --check
```

The generator builds **147 outputs**, including all earlier outputs, the
14 new candidates, 60 pass-3 preview images and the wood manifest. Its
existing geometry/UV/text-backing checks remain active. Added checks cover
new dimensions/alpha, matching preview bytes, both arrow writing fields,
uniform round-post samples including gutters/caps, and full text capacity
at the runtime scale. Every HTML image/link is local and relative.
The final `--check` and `git diff --check` both passed.

All **71 previous generated files other than the HTML page** were compared
byte-for-byte with the branch base and are unchanged. The six model
packages, previous icons, both wall candidates and previous preview PNGs
are intact. The shipped models/textures match the frozen baseline.
Front, angle, reverse, family, stack and join images were inspected
directly; the notice-board view includes the complete roof and feet.
No browser or game-runtime acceptance is claimed.

**Upgrade classification: compatible.** Development candidates only;
all changes are under `tools/r68_art/`. No files under `mods/`, Lua,
world data, version or upgrade declaration changed. No server, fixture,
sync, merge or push was run. The existing uninitialized reference
submodules and their pins were left alone. The open design TODOs do not
block this art pass.

The final commit hash and post-commit empty `git status --porcelain`
receipt are in the final handoff, captured by the runner as `last.md`.
The report's commit can also be resolved with
`git log -1 --format=%H -- tools/r68_art/REPORT.md`.

**Remaining:** coordinator review and the user's texture pick before
integration. After copying the selected four textures and three icons,
the user checks desktop and web: front/back text nearby and at distance,
daylight/indoor light, square-post grain, two rotated waypost joins,
wall signs on walls/floors/ceilings, and 16/32 px icons. This is an art
proposal, not a record of GUI acceptance.

## Historical report — passes 1 and 2

The following sections record the previous deliveries and their original
preview metrics. Pass 3 above supersedes their wood recommendation only;
the accepted model choices and all previous assets remain intact.

**User's pick (2026-10-31): standing sign A, waypost B, notice board B.**
These three cards are marked **Picked** on the preview page and contact
sheet. The six model packages remain byte-identical to pass 1.

Delivered on `r68-art`, from
`b649e70783787f38ca384fdaea02e7a6e8c93fd3`.

Open the [offline preview](preview/index.html) or the
[six-candidate contact sheet](preview/contact.png).

## Pass 2 — wall signs

Two original **16 × 16 RGBA** candidates, generated by the same script:

| Candidate | Runtime texture to replace | Uniform writing surface | Required glyph ink |
|---|---|---|---|
| [Wood](candidates/sign_wall_wood.png) | `default_sign_wall_wood.png` | Warm wood, `#B68357` | **`#2B1E14`** |
| [Iron](candidates/sign_wall_iron.png) | `default_sign_wall_steel.png` | Light grey iron, `#AAAAAA` | **`#2B1E14`** |

Use the ink colour as the multiplier on the white glyphs. **Iron stays
light and requires dark ink**, replacing the round plan's provisional
light-ink default for that sign. The user explicitly allowed either
light-board/dark-ink or dark-board/light-ink for this pass. The manifest
records the colour for each texture. The original wood and steel
inventory/wield icons still match these material colours and are unchanged.

The entire writing field is one colour: no fake writing, grain, knots,
fasteners or glare. The wood retains its warm brown top/bottom rim;
the iron retains a narrow light top rim and darker bottom rim. Side
thickness uses the original tile layout and a matching darker colour.
Only one variant per material is needed.

### Nodebox UV layout

Indices below are **zero-based and inclusive**, measured from the PNG's
upper-left corner. The board is 0.875 × 0.625 × 0.0625 node. Its large
face uses a **14 × 10 texel crop**, not the whole 16 × 16 image.

| Surface | Texture columns | Texture rows |
|---|---|---|
| Front (also the hidden back) | 1–14 | 3–12 |
| Calm writing field | 1–14 | 4–11 |
| Top / bottom front rim | 1–14 | 3 / 12 |
| Two long thin edges | 1–14 | 15 |
| Two short thin edges | 3–12 | 15 |

The unused outer strips and gaps retain the familiar tile arrangement.
Front and edge samples are opaque; transparency outside the sampled
regions does not alter the node's `use_texture_alpha = "opaque"` behavior.
The calm field accommodates the existing 0.8125 × 0.5-node text rectangle,
including four full lines of fifteen characters at the preview scale.

Verified against `mods/BASE/default/nodes.lua:2642` and the pinned engine
reference `df04879066de6eb94ca43996822a6dfacc74feca`:
`src/client/content_mapblock.cpp:345` (node-aligned UVs), `:140` (UV
rotation), `src/client/mapblock_mesh.cpp:375` (tile rotation table),
`src/util/directiontables.cpp:98` (wallmounted-to-facedir mapping), and
`src/mapnode.cpp:219` (wallmounted boxes). The six normal wallmounted
orientations, including floor and ceiling, all use the crops above after
tile rotation. This corrects pass 1's simplified edge preview; the front
crop was already correct. The source was read from the main checkout's
initialized reference at the same pin, without modifying it.

### Comparison and handoff

The [wall comparison](preview/wall_comparison.png) shows wood old/new,
iron old/new, and picked standing sign A. Each wall sign is mounted on
an original preview masonry section. All five use the same four sample
lines, original game-font pixels, `#2B1E14` ink, and **169 pixels per node**,
exactly the family-strip scale. The old iron also uses that dark ink to
isolate the texture difference; this is not a runtime before/after capture.
The [offline page](preview/index.html) adds this comparison, the two flat
textures at 8×, ink colours and candidate download links.

Both family strips now show the new wooden wall texture. The old wall
textures appear only in the wall comparison. Their byte-identical
preview-only input snapshots keep this comparison stable after runtime
integration; their authors, licences and hashes are in the media ledger.
New candidates are drawn from scratch and dedicated to **CC0-1.0**.

The receiving lane copies the two candidate PNGs to the runtime texture
names above and uses the stated ink colours. No icon replacement, model
change or text-placement change is needed for the wall signs.

## Selected variants (pass-1 recommendations accepted)

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
Each model candidate has an OBJ, MTL, atlas PNG, `_inv.png` and JSON:
**30 files**, plus the two wall PNGs: **32 candidate files** in total.

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
angles for each variant; both families beside the refreshed wall sign and
wooden chest at one shared scale; inventory icons at 16 and 32 px; all
atlases at 8×; and the user's picks at the top. The new wall section adds
the old/new comparison and both 16px replacement tiles at 8×. All images are adjacent
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
`--check` regenerated **72 outputs** in memory and compared every byte:
32 candidate files, 14 exact preview copies, 18 individual model views,
two stacked views, three comparison strips, a contact sheet, an HTML page
and a manifest. It rejects missing, differing or unexpected generated files.

The same run checked exact 16-texel UV density on every face, finite
geometry/UVs, outward normals, serialized OBJ triangle indices/winding,
text-plane support and full character capacities, opaque atlases,
16px icons with binary alpha, identical preview copies and local HTML
links. The report and media-ledger links and Python syntax were also
checked. Front, angled and rear views, the stack, shared-scale comparison
and enlarged icons were visually inspected. These are art checks, not
runtime fixtures or browser/engine acceptance.

Pass 2 also checks the uniform wall writing fields, full 4 × 15 character
fit over those fields, the front/back and four edge UV footprints, and
opacity in all sampled wall pixels. The wall comparison and refreshed
family strips were visually inspected. All 30 pass-1 candidate files are
byte-identical; the saved wall inputs match the vendored originals. The
page has exactly three **Picked** marks, on the requested A/B/B cards.

## Scope and remaining review

**Upgrade classification: compatible.** This package adds development
assets only. No runtime code, saved state, world generation, game version
or upgrade declaration changes. No file under `mods/` was changed.
No Lua, fixtures, game server, engine boot, sync, merge or push was run.

The wall-sign board dimensions and the reference font's provenance were
confirmed against local files. The two open `TODO-*.md` files concern
other work; the upstream workaround list requires no change for this lane.
The reference submodules remain untouched.

## Pass-1 commit receipt

- `c421b445`: generator, six model packages, saved preview-font input,
  manifest and media provenance.
- **Complete art and preview commit:**
  `2f4d60faec3e4463bdd6e6f6ef4b20dacdaa25d5` — offline page, images,
  report and the single `tools/README.md` entry. At this checkpoint,
  **`git status --porcelain` was empty** and `git diff --check` passed.
- This receipt is a following documentation-only commit. Its final branch
  hash and the post-receipt clean-tree check are recorded in the final
  handoff saved by the runner as `last.md`; a tracked report cannot embed
  its own commit hash. Resolve it locally with
  `git log -1 --format=%H -- tools/r68_art/REPORT.md`.
- Pass-1 final receipt: `73c7a6ed`; pass 2 starts from that clean commit.

All lane commit messages end with the requested GPT-6 Astra co-author
trailer. Changes are confined to `tools/r68_art/` and one line in
`tools/README.md`.

## Pass-2 commit receipt

**Complete pass-2 art and preview commit:**
`52586b103f8b01282cccc7e91d77766466c51d4d`. At that checkpoint,
**`git status --porcelain` was empty** and `git diff --check` passed.
`python3 tools/r68_art/generate.py --check` verified all 72 outputs;
the input, pick-mark, scope and unchanged-model checks also passed.
This receipt is the following documentation-only commit.

The final commit hash and clean-tree check are included in the final
handoff saved by the runner as `last.md`. This report cannot embed its
own final commit hash; resolve it with
`git log -1 --format=%H -- tools/r68_art/REPORT.md`.

## Blockers / questions

The user's A/B picks are recorded above. The coordinator checked both
passes and published the preview; the user approved the new wall
textures on 2026-10-31, and lanes TEXT and SIGNS shipped the picks.

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
6. Write four full lines on both replacement wall signs with `#2B1E14`
   ink; check their calm surfaces, thin edges and contrast on walls,
   floors and ceilings. Confirm the existing inventory/wield icons still
   match both materials.
