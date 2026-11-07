#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile picked boxes to cell-local node boxes and ordinary six-face tiles."""
import numpy as np
from PIL import Image

FACES = ('top', 'bottom', 'right', 'left', 'back', 'front')
# Luanti content_mapblock.cpp generateCuboidTextureCoords, facedir zero.
AXES = (1, 1, 0, 0, 2, 2)
SIGNS = (1, -1, 1, -1, 1, -1)


def face_points(face):
    u, v = np.meshgrid((np.arange(16)+.5)/16, (np.arange(16)+.5)/16)
    zero = np.zeros_like(u)
    return np.stack(((u, zero, 1-v), (u, zero, v), (zero, 1-v, u),
                     (zero, 1-v, 1-u), (1-u, 1-v, zero), (u, 1-v, zero))[face], axis=-1).reshape(-1, 3)


def build(api, specs, textures):
    """Return installation manifests; emit only picked, directly usable files."""
    emit, images, sample = api.emit, api.IMAGES, api.material_pixels
    prefix = 'candidates/final/'
    inventory = []

    def asset(name, im, kind, node):
        emit(prefix+name, im)
        inventory.append((name, kind, node))

    asset('grug_professions_thread.png', images['candidates/thread/a/thread.png'],
          'Item icon, 16 × 16', 'grug_professions:thread (existing id)')
    for key in api.TIERS:
        asset(f'grug_guild_ornamented_{key}.png', images[f'candidates/stone/a/{key}.png'],
              'Block face, 16 × 16; all six faces', f'grug_guild:ornamented_{key}')
    manifests = {}
    for key in ('grinder_b', 'furnace_a'):
        spec = specs[key]
        kind = spec['kind']
        heat = kind == 'furnace'
        manifest = dict(pick=key, dimensions_xyz=spec['dimensions_xyz'],
                        coordinates=spec['coordinates'], authored_boxes=spec['boxes'],
                        tile_order=FACES, cells=[])
        for cell in spec['occupied_cell_coordinates']:
            clipped = []
            for item in spec['boxes']:
                lo = [max(item['bounds'][a], cell[a]) for a in range(3)]
                hi = [min(item['bounds'][a+3], cell[a]+1) for a in range(3)]
                if all(lo[a] < hi[a] for a in range(3)):
                    clipped.append(dict(item, bounds=lo+hi))
            cell_id = '_'.join(map(str, cell))
            node = f'grug_guild:stonewright_{kind}_{cell_id}'
            entry = dict(offset=cell, name=node, light_source=8 if heat and cell[1]<2 and cell[2]==0 else 0,
                         node_box=[[round(v-cell[i%3]-.5, 6) for i,v in enumerate(b['bounds'])] for b in clipped], tiles=[])
            for face, label in enumerate(FACES):
                axis, sign = AXES[face], SIGNS[face]
                p = face_points(face)+cell
                depth = np.full(256, -np.inf)
                owners = np.full(256, -1)
                # Conservative native-pixel coverage preserves subpixel iron bars.
                for idx, item in enumerate(clipped):
                    bounds = item['bounds']
                    hit = np.ones(256, dtype=bool)
                    for a in range(3):
                        if a != axis:
                            hit &= (p[:,a]+1/32 > bounds[a]+1e-9) & (p[:,a]-1/32 < bounds[a+3]-1e-9)
                    near = bounds[axis+3] if sign == 1 else bounds[axis]
                    hit &= near*sign > depth
                    depth[hit] = near*sign
                    owners[hit] = idx
                frames = []
                for frame in range(api.FIRE_FRAMES if heat and face == 5 and cell[1]<2 and cell[2]==0 else 1):
                    rgba = np.full((256,4), [45,43,40,255], dtype=np.uint8)
                    for idx, item in enumerate(clipped):
                        hit = owners == idx
                        if not hit.any(): continue
                        q = p[hit].copy()
                        q[:,axis] = depth[hit]*sign
                        rgba[hit], _ = sample(item, q, np.full(hit.sum(),axis),
                                              np.full(hit.sum(),sign), textures, frame, heat)
                    frames.append(Image.fromarray(rgba.reshape(16,16,4)))
                animated = len({im.tobytes() for im in frames}) > 1
                if not animated: frames = frames[:1]
                sheet = Image.new('RGBA', (16,16*len(frames)))
                for f, im in enumerate(frames): sheet.paste(im,(0,f*16))
                filename = f'grug_guild_{kind}_{cell_id}_{label}.png'
                asset(filename, sheet, ('Animated sheet, 16 × 128; '+label if animated else 'Machine face, 16 × 16; '+label), node)
                tile = dict(name=filename, align_style='node')
                if animated: tile['animation'] = spec['animation']
                entry['tiles'].append(tile)
            manifest['cells'].append(entry)
        manifests[kind] = manifest
        name = f'{kind}.json'
        emit(prefix+name, api.json_text(manifest))
        inventory.append((name, 'Cell geometry and ordered tile definitions', f'grug_guild:stonewright_{kind}_x_y_z'))
    write_install(api, manifests, inventory)
    return manifests


def write_install(api, manifests, inventory):
    rows = ['''# Round 70 ART — installation handoff

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
''']
    for kind, data in manifests.items():
        for cell in data['cells']:
            animated = ', '.join(FACES[i] for i,tile in enumerate(cell['tiles']) if 'animation' in tile) or 'None'
            rows.append(f'| {kind.title()} | {tuple(cell["offset"])} | `{cell["name"].split(":")[1]}` | {len(cell["node_box"])} | {animated} | {cell["light_source"]} |\n')
    rows.append('''
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
''')
    for filename, kind, node in inventory:
        rows.append(f'| [{filename}](candidates/final/{filename}) | {kind} | `{node}` | GPT-6 Astra | CC0-1.0 |\n')
    rows.append('''
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
''')
    api.emit('INSTALL.md', ''.join(rows))
