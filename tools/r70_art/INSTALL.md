# Round 70 ART — installation handoff

**User picks (2026-11-07): Thread A, Grinder B, Smelting furnace A, Iron A,
Steel A, Silversteel A, Embersteel A, Abyssal Steel A.** Furnace A always burns.
All other proposals remain in their original candidate directories.

**This lane is compatible, tools/media only.** Installation of the machines
in the six guild houses joins Round 70's map reset; lane GUILD owns that change.

## Copy one folder

[`candidates/final/`](candidates/final/) contains only the selected icon, five
stone faces, the two selected machines' prepared cell tiles and their JSON
construction records. Copy its PNGs, unchanged and with their unique names,
to the owning mods' `textures/` directories. Keep the two JSON files as build
inputs, not engine media. No context, alternate proposal, preview or sound
file belongs in the game. All files are enumerated below.

Thread keeps **`grug_professions:thread`**. Replace the inventory-image string
`default_paper.png^[colorize:#d8d1bd:115` in
`mods/ITEMS/grug_professions/init.lua` with `grug_professions_thread.png`.
The five ornamented stones are full cubes, using their one image on all six
faces; their proposed ids are in the file table. There is no emission or
animation on these stones, including Embersteel. Machine names are proposals
under `grug_guild`, whose mod directory is `mods/PLAYER/grug_guild`.

## Cell construction

Coordinates are in node units, origin at the lower front left: +x right,
+y up, +z rear; the front faces −z. The grinder's 29 authored boxes are
unchanged. The furnace keeps its 17 boxes, shaft, flue and footprint; only
the opening, jambs, lintel and three grate bars align to the 1/16-node grid
so each bar occupies one dark texel and leaves the adjacent fire visible.
The largest bound adjustment is 0.0525 node; all exact bounds are in the JSON.
No mesh is needed.

`grinder.json` and `furnace.json` contain every occupied cell, its proposed
node name, its exact clipped `node_box` bounds in [−0.5, 0.5], and **all six
tiles in Luanti order: top, bottom, right (+x), left (−x), back (+z), front
(−z)**. For an origin node at P, place each cell at P + `offset`. The art
origin is half a node below/left/front of P. Use `drawtype = nodebox`, a
fixed node-box list from that cell, `paramtype = light`, `paramtype2 = facedir`,
`use_texture_alpha = opaque`, `sunlight_propagates = true`,
`is_ground_content = false` and the listed `light_source`. Start with the
same fixed boxes for collision and selection. These are placed decoration;
no crafting inventory, fuel state, node timer, ABM or particle system is needed.

Use the ordered tile objects as provided, with `align_style = node`; do not
world-align them. Face orientation is already baked for facedir 0. If the
work bay is rotated, rotate **both the cell offsets and every cell's facedir
together** around the same pivot. No extra texture transform is required.

The engine has six tiles per node, not one material per box. The final files
therefore contain a separate 16px projection for each cell face, compositing
the visible materials at native resolution. Subpixel bars conservatively
occupy a texel; their physical box width is unchanged. Unused texels are
opaque dark fill. Internal and occluded surfaces share that projection,
as ordinary node boxes do. The face-labelled filenames and JSON are the
authoritative installation mapping, not the proposal's per-material names.

Engine basis: `reference_projects/luanti/src/client/content_mapblock.cpp`,
`generateCuboidTextureCoords` and `drawNodeboxNode`; tile order and UV flips
follow those functions. The read-only checkout was read at its documented
location in the main repository; no reference checkout or pin was modified.

## Furnace fire and light

**8 frames, nominally 0.1875 seconds per frame, 1.5 seconds per loop.** Each animated
sheet is **16 × 128**, eight vertical 16 × 16 frames. Tile animation fields:
`type = vertical_frames`, `aspect_w = 16`, `aspect_h = 16`, **`length = 1.5`**.
Here `length` is the full loop, not the frame duration (engine Lua API,
"Tile animation definition"). This matches the shipped active normal and
dual furnaces' eight frames and 1.5-second loop. Their pixels were inspected
for scale and pacing; no shipped pixels enter the new fire.
The engine stores frame duration in integer milliseconds (187 ms here),
as it does for those shipped furnaces; the authored loop setting stays 1.5.

Animate only tile 6 (front) of cells **(0,0,0), (1,0,0), (0,1,0), (1,1,0)**.
All four sheets have the same count and timing; their stationary grate,
masonry and warm edges repeat unchanged in every frame. The client uses its
common animation clock (`AnimationInfo::getTexture` in `src/client/tile.cpp`);
the installation GUI checklist should still inspect cell/mapblock seams.

Proposed **`light_source = 8` on those same four front hearth cells**, zero
on all other machine cells. This is the shipped active furnaces' light level.
There is no flashing light value. The bright yellow/orange tongues and dull
red coals move behind the grate; the surrounding jambs, lintel and nearby
foundation carry restrained painted warmth. The pouring lip has a narrow,
static dull-orange hot channel; the mould and casting stay dark and solid.
No stream of molten metal is implied. The shaft, flue and footprint are unchanged.

Luanti's propagated light is neutral, not coloured. Warmth is in the original
textures. The page's dim corner is an illustrative lighting study, not a
simulation of the engine light curve. **Sound belongs to lane GUILD:** reuse
the game's existing furnace ambient loop once for the complete assembly,
not once per cell. This package adds no sound asset or sound code.

## Space that make_halls.py must reserve

In `tools/r58_halls/make_halls.py`, reserve a **2 wide × 2 deep × 2 high**
box for Grinder B (8 occupied cells) and a **2 × 2 × 3** box for Furnace A
(12 occupied cells). Both stand on an unbroken floor. Leave their full
fronts visible, at least a one-node-deep clear approach, and a separate NPC
standing cell with two nodes of headroom. Do not put the Stonewright in
front of the glowing aperture. Place the machines behind or beside the NPC,
with the furnace visible across the hall. A one-node aisle between machines
is useful; reserve **5 wide × 3 deep × 3 high** for such a side-by-side bay,
plus the NPC standing space if it falls outside that box.

The current sorter socket is **(1,1,10), facing east**; its table is at x=2,
and storage is at (1,1,11). The west wall is x=0, so the unchanged socket
cannot have either 2-deep machine inserted directly behind it. Revise that
work bay and its furniture/socket or reserve space in the ore yard. Do not
overwrite the west wall, headframe, rail, stairs/door approaches or another
service socket. All six houses share geometry and sockets; check the same
reservation in all six race palettes. The generic page corner is not a claim
that a particular template position is free. GUILD owns the final placement.

## Cells and animation

The six face names on each file are literal; the JSON arrays resolve every
face to its PNG without inferred paths or material conversion.

| Machine | Cell (x,y,z) | Node suffix | Boxes | Animated face | light_source |
|---|---|---|---:|---|---:|
| Grinder | (0, 0, 0) | `stonewright_grinder_0_0_0` | 8 | None | 0 |
| Grinder | (0, 0, 1) | `stonewright_grinder_0_0_1` | 5 | None | 0 |
| Grinder | (0, 1, 0) | `stonewright_grinder_0_1_0` | 8 | None | 0 |
| Grinder | (0, 1, 1) | `stonewright_grinder_0_1_1` | 9 | None | 0 |
| Grinder | (1, 0, 0) | `stonewright_grinder_1_0_0` | 10 | None | 0 |
| Grinder | (1, 0, 1) | `stonewright_grinder_1_0_1` | 5 | None | 0 |
| Grinder | (1, 1, 0) | `stonewright_grinder_1_1_0` | 9 | None | 0 |
| Grinder | (1, 1, 1) | `stonewright_grinder_1_1_1` | 9 | None | 0 |
| Furnace | (0, 0, 0) | `stonewright_furnace_0_0_0` | 9 | front | 8 |
| Furnace | (0, 0, 1) | `stonewright_furnace_0_0_1` | 3 | None | 0 |
| Furnace | (0, 1, 0) | `stonewright_furnace_0_1_0` | 6 | front | 8 |
| Furnace | (0, 1, 1) | `stonewright_furnace_0_1_1` | 2 | None | 0 |
| Furnace | (0, 2, 0) | `stonewright_furnace_0_2_0` | 3 | None | 0 |
| Furnace | (0, 2, 1) | `stonewright_furnace_0_2_1` | 4 | None | 0 |
| Furnace | (1, 0, 0) | `stonewright_furnace_1_0_0` | 10 | front | 8 |
| Furnace | (1, 0, 1) | `stonewright_furnace_1_0_1` | 3 | None | 0 |
| Furnace | (1, 1, 0) | `stonewright_furnace_1_1_0` | 7 | front | 8 |
| Furnace | (1, 1, 1) | `stonewright_furnace_1_1_1` | 2 | None | 0 |
| Furnace | (1, 2, 0) | `stonewright_furnace_1_2_0` | 3 | None | 0 |
| Furnace | (1, 2, 1) | `stonewright_furnace_1_2_1` | 4 | None | 0 |

## Every picked file and shipping licence row

Each PNG row below is also the row to add to the owning mod's
`LICENSE-media.md`: **author GPT-6 Astra; licence CC0-1.0; source
`tools/r70_art/build.py` and `installation.py`, original Round 70 pixel art;
modification: none (copy unchanged)**. The two JSON records are original
geometry, also CC0-1.0, but are not texture media. No attribution from the
comparison/hall images belongs on these final assets: none contains imported
pixels. The repository's art inventory lists the previews separately.

| File | What it is | Proposed node/item | Author | Licence |
|---|---|---|---|---|
| [grug_professions_thread.png](candidates/final/grug_professions_thread.png) | Item icon, 16 × 16 | `grug_professions:thread (existing id)` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_ornamented_iron.png](candidates/final/grug_guild_ornamented_iron.png) | Block face, 16 × 16; all six faces | `grug_guild:ornamented_iron` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_ornamented_steel.png](candidates/final/grug_guild_ornamented_steel.png) | Block face, 16 × 16; all six faces | `grug_guild:ornamented_steel` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_ornamented_silversteel.png](candidates/final/grug_guild_ornamented_silversteel.png) | Block face, 16 × 16; all six faces | `grug_guild:ornamented_silversteel` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_ornamented_embersteel.png](candidates/final/grug_guild_ornamented_embersteel.png) | Block face, 16 × 16; all six faces | `grug_guild:ornamented_embersteel` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_ornamented_abyssal_steel.png](candidates/final/grug_guild_ornamented_abyssal_steel.png) | Block face, 16 × 16; all six faces | `grug_guild:ornamented_abyssal_steel` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_0_top.png](candidates/final/grug_guild_grinder_0_0_0_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_grinder_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_0_bottom.png](candidates/final/grug_guild_grinder_0_0_0_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_grinder_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_0_right.png](candidates/final/grug_guild_grinder_0_0_0_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_grinder_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_0_left.png](candidates/final/grug_guild_grinder_0_0_0_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_grinder_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_0_back.png](candidates/final/grug_guild_grinder_0_0_0_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_grinder_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_0_front.png](candidates/final/grug_guild_grinder_0_0_0_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_grinder_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_1_top.png](candidates/final/grug_guild_grinder_0_0_1_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_grinder_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_1_bottom.png](candidates/final/grug_guild_grinder_0_0_1_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_grinder_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_1_right.png](candidates/final/grug_guild_grinder_0_0_1_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_grinder_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_1_left.png](candidates/final/grug_guild_grinder_0_0_1_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_grinder_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_1_back.png](candidates/final/grug_guild_grinder_0_0_1_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_grinder_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_0_1_front.png](candidates/final/grug_guild_grinder_0_0_1_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_grinder_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_0_top.png](candidates/final/grug_guild_grinder_0_1_0_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_grinder_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_0_bottom.png](candidates/final/grug_guild_grinder_0_1_0_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_grinder_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_0_right.png](candidates/final/grug_guild_grinder_0_1_0_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_grinder_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_0_left.png](candidates/final/grug_guild_grinder_0_1_0_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_grinder_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_0_back.png](candidates/final/grug_guild_grinder_0_1_0_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_grinder_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_0_front.png](candidates/final/grug_guild_grinder_0_1_0_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_grinder_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_1_top.png](candidates/final/grug_guild_grinder_0_1_1_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_grinder_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_1_bottom.png](candidates/final/grug_guild_grinder_0_1_1_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_grinder_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_1_right.png](candidates/final/grug_guild_grinder_0_1_1_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_grinder_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_1_left.png](candidates/final/grug_guild_grinder_0_1_1_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_grinder_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_1_back.png](candidates/final/grug_guild_grinder_0_1_1_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_grinder_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_0_1_1_front.png](candidates/final/grug_guild_grinder_0_1_1_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_grinder_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_0_top.png](candidates/final/grug_guild_grinder_1_0_0_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_grinder_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_0_bottom.png](candidates/final/grug_guild_grinder_1_0_0_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_grinder_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_0_right.png](candidates/final/grug_guild_grinder_1_0_0_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_grinder_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_0_left.png](candidates/final/grug_guild_grinder_1_0_0_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_grinder_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_0_back.png](candidates/final/grug_guild_grinder_1_0_0_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_grinder_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_0_front.png](candidates/final/grug_guild_grinder_1_0_0_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_grinder_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_1_top.png](candidates/final/grug_guild_grinder_1_0_1_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_grinder_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_1_bottom.png](candidates/final/grug_guild_grinder_1_0_1_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_grinder_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_1_right.png](candidates/final/grug_guild_grinder_1_0_1_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_grinder_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_1_left.png](candidates/final/grug_guild_grinder_1_0_1_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_grinder_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_1_back.png](candidates/final/grug_guild_grinder_1_0_1_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_grinder_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_0_1_front.png](candidates/final/grug_guild_grinder_1_0_1_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_grinder_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_0_top.png](candidates/final/grug_guild_grinder_1_1_0_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_grinder_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_0_bottom.png](candidates/final/grug_guild_grinder_1_1_0_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_grinder_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_0_right.png](candidates/final/grug_guild_grinder_1_1_0_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_grinder_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_0_left.png](candidates/final/grug_guild_grinder_1_1_0_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_grinder_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_0_back.png](candidates/final/grug_guild_grinder_1_1_0_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_grinder_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_0_front.png](candidates/final/grug_guild_grinder_1_1_0_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_grinder_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_1_top.png](candidates/final/grug_guild_grinder_1_1_1_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_grinder_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_1_bottom.png](candidates/final/grug_guild_grinder_1_1_1_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_grinder_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_1_right.png](candidates/final/grug_guild_grinder_1_1_1_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_grinder_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_1_left.png](candidates/final/grug_guild_grinder_1_1_1_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_grinder_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_1_back.png](candidates/final/grug_guild_grinder_1_1_1_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_grinder_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_grinder_1_1_1_front.png](candidates/final/grug_guild_grinder_1_1_1_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_grinder_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grinder.json](candidates/final/grinder.json) | Cell geometry and ordered tile definitions | `grug_guild:stonewright_grinder_x_y_z` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_0_top.png](candidates/final/grug_guild_furnace_0_0_0_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_0_bottom.png](candidates/final/grug_guild_furnace_0_0_0_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_0_right.png](candidates/final/grug_guild_furnace_0_0_0_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_0_left.png](candidates/final/grug_guild_furnace_0_0_0_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_0_back.png](candidates/final/grug_guild_furnace_0_0_0_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_0_front.png](candidates/final/grug_guild_furnace_0_0_0_front.png) | Animated sheet, 16 × 128; front | `grug_guild:stonewright_furnace_0_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_1_top.png](candidates/final/grug_guild_furnace_0_0_1_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_1_bottom.png](candidates/final/grug_guild_furnace_0_0_1_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_1_right.png](candidates/final/grug_guild_furnace_0_0_1_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_1_left.png](candidates/final/grug_guild_furnace_0_0_1_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_1_back.png](candidates/final/grug_guild_furnace_0_0_1_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_0_1_front.png](candidates/final/grug_guild_furnace_0_0_1_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_furnace_0_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_0_top.png](candidates/final/grug_guild_furnace_0_1_0_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_0_bottom.png](candidates/final/grug_guild_furnace_0_1_0_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_0_right.png](candidates/final/grug_guild_furnace_0_1_0_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_0_left.png](candidates/final/grug_guild_furnace_0_1_0_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_0_back.png](candidates/final/grug_guild_furnace_0_1_0_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_0_front.png](candidates/final/grug_guild_furnace_0_1_0_front.png) | Animated sheet, 16 × 128; front | `grug_guild:stonewright_furnace_0_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_1_top.png](candidates/final/grug_guild_furnace_0_1_1_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_1_bottom.png](candidates/final/grug_guild_furnace_0_1_1_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_1_right.png](candidates/final/grug_guild_furnace_0_1_1_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_1_left.png](candidates/final/grug_guild_furnace_0_1_1_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_1_back.png](candidates/final/grug_guild_furnace_0_1_1_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_1_1_front.png](candidates/final/grug_guild_furnace_0_1_1_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_furnace_0_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_0_top.png](candidates/final/grug_guild_furnace_0_2_0_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_0_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_0_bottom.png](candidates/final/grug_guild_furnace_0_2_0_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_0_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_0_right.png](candidates/final/grug_guild_furnace_0_2_0_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_0_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_0_left.png](candidates/final/grug_guild_furnace_0_2_0_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_0_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_0_back.png](candidates/final/grug_guild_furnace_0_2_0_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_0_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_0_front.png](candidates/final/grug_guild_furnace_0_2_0_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_furnace_0_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_1_top.png](candidates/final/grug_guild_furnace_0_2_1_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_0_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_1_bottom.png](candidates/final/grug_guild_furnace_0_2_1_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_0_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_1_right.png](candidates/final/grug_guild_furnace_0_2_1_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_0_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_1_left.png](candidates/final/grug_guild_furnace_0_2_1_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_0_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_1_back.png](candidates/final/grug_guild_furnace_0_2_1_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_0_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_0_2_1_front.png](candidates/final/grug_guild_furnace_0_2_1_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_furnace_0_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_0_top.png](candidates/final/grug_guild_furnace_1_0_0_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_0_bottom.png](candidates/final/grug_guild_furnace_1_0_0_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_0_right.png](candidates/final/grug_guild_furnace_1_0_0_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_0_left.png](candidates/final/grug_guild_furnace_1_0_0_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_0_back.png](candidates/final/grug_guild_furnace_1_0_0_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_0_front.png](candidates/final/grug_guild_furnace_1_0_0_front.png) | Animated sheet, 16 × 128; front | `grug_guild:stonewright_furnace_1_0_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_1_top.png](candidates/final/grug_guild_furnace_1_0_1_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_1_bottom.png](candidates/final/grug_guild_furnace_1_0_1_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_1_right.png](candidates/final/grug_guild_furnace_1_0_1_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_1_left.png](candidates/final/grug_guild_furnace_1_0_1_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_1_back.png](candidates/final/grug_guild_furnace_1_0_1_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_0_1_front.png](candidates/final/grug_guild_furnace_1_0_1_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_furnace_1_0_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_0_top.png](candidates/final/grug_guild_furnace_1_1_0_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_0_bottom.png](candidates/final/grug_guild_furnace_1_1_0_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_0_right.png](candidates/final/grug_guild_furnace_1_1_0_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_0_left.png](candidates/final/grug_guild_furnace_1_1_0_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_0_back.png](candidates/final/grug_guild_furnace_1_1_0_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_0_front.png](candidates/final/grug_guild_furnace_1_1_0_front.png) | Animated sheet, 16 × 128; front | `grug_guild:stonewright_furnace_1_1_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_1_top.png](candidates/final/grug_guild_furnace_1_1_1_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_1_bottom.png](candidates/final/grug_guild_furnace_1_1_1_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_1_right.png](candidates/final/grug_guild_furnace_1_1_1_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_1_left.png](candidates/final/grug_guild_furnace_1_1_1_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_1_back.png](candidates/final/grug_guild_furnace_1_1_1_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_1_1_front.png](candidates/final/grug_guild_furnace_1_1_1_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_furnace_1_1_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_0_top.png](candidates/final/grug_guild_furnace_1_2_0_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_1_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_0_bottom.png](candidates/final/grug_guild_furnace_1_2_0_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_1_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_0_right.png](candidates/final/grug_guild_furnace_1_2_0_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_1_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_0_left.png](candidates/final/grug_guild_furnace_1_2_0_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_1_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_0_back.png](candidates/final/grug_guild_furnace_1_2_0_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_1_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_0_front.png](candidates/final/grug_guild_furnace_1_2_0_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_furnace_1_2_0` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_1_top.png](candidates/final/grug_guild_furnace_1_2_1_top.png) | Machine face, 16 × 16; top | `grug_guild:stonewright_furnace_1_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_1_bottom.png](candidates/final/grug_guild_furnace_1_2_1_bottom.png) | Machine face, 16 × 16; bottom | `grug_guild:stonewright_furnace_1_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_1_right.png](candidates/final/grug_guild_furnace_1_2_1_right.png) | Machine face, 16 × 16; right | `grug_guild:stonewright_furnace_1_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_1_left.png](candidates/final/grug_guild_furnace_1_2_1_left.png) | Machine face, 16 × 16; left | `grug_guild:stonewright_furnace_1_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_1_back.png](candidates/final/grug_guild_furnace_1_2_1_back.png) | Machine face, 16 × 16; back | `grug_guild:stonewright_furnace_1_2_1` | GPT-6 Astra | CC0-1.0 |
| [grug_guild_furnace_1_2_1_front.png](candidates/final/grug_guild_furnace_1_2_1_front.png) | Machine face, 16 × 16; front | `grug_guild:stonewright_furnace_1_2_1` | GPT-6 Astra | CC0-1.0 |
| [furnace.json](candidates/final/furnace.json) | Cell geometry and ordered tile definitions | `grug_guild:stonewright_furnace_x_y_z` | GPT-6 Astra | CC0-1.0 |

## Installation GUI checklist (desktop and web)

- Inspect all six houses: intact approaches, NPC access, full machine
  footprints and headroom, no overlap with furniture or another service.
- Check every machine side and the cell seams, especially rotated placements
  and a furnace that crosses a mapblock boundary. The grate must stay dark,
  the flames behind it, and the shafts and frames retain their materials.
- In a dim hall, recognise the burning furnace from across the room; inspect
  the steady light and the still, warm pouring lip close up. No particles.
- Hear only one copy of the reused furnace loop per complete furnace.
- Check Thread at 16/32 px in inventory and all five stones alone and in walls.

No engine boot or client acceptance was performed in this art lane.
