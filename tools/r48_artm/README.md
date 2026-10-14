# Round 48 ARTM — Mail and daytime proposals

Step 1, **2026-10-14**, by **GPT-6 Astra**. Nine proposals await the user's
three independent picks. All new artwork is original pixel art, dedicated
to **CC0-1.0**. The coordinator builds the pick page from this directory.

| Thing | A | B | C |
| --- | --- | --- | --- |
| Mailbox | **Wayside chest:** a broad oak box, flat metal lid and pale envelope plaque. | **Letter pillar:** an upright iron cassette, brass slot and envelope plate. | **Sheltered post:** a wooden box beneath a stepped copper roof. |
| Mail icon | **Open letter:** a written page above an unfolded envelope. | **Sealed envelope:** a wide folded envelope with a small wax closure. | **Ribbon seal:** a scalloped seal bearing an envelope impression over two paper tails. |
| Daytime band | **Brass channel:** an eight-ray sun, crescent and single downward pointer. | **Carved timber:** a diamond sun, half moon and opposing pointers in a notched frame. | **Slate rails:** a round sun, cut moon and fine vertical marker beneath a bead. |

The mailbox designs share a pale letter symbol, warm wood and subdued metal
to fit both The Accord and The Throng and their starting villages. Their
body proportions and lid silhouettes differ. Each HUD icon has a dark
outline and a pale outer edge for contrast on light and dark ground.

## Review images

Open the PNGs at **100%** to judge the native HUD samples. Every enlargement
uses nearest-neighbour scaling; there is no antialiasing.

- [Mailbox comparison](previews/mailbox.png), **1200 × 748**: all three
  nodeboxes rendered isometrically on original stone paving, followed by
  front and side views, all at **4×**. The four face textures and the
  existing waystone side/top textures are also shown at 4×. Native node
  renders use an orthographic camera at 24 pixels per node; the isometric
  canvas is 84 × 58 and each straight view is 38 × 38. These are offline
  material studies, not engine screenshots.
- [Icon comparison](previews/icon.png), **1200 × 840**: each **32 × 32**
  icon without a badge, with **3**, and with **9+**, at **1× and 2×** on
  four original ground swatches: light grass, sand, forest and night.
- [Band comparison](previews/band.png), **1200 × 1664**: every style at
  **noon, dusk and midnight**, each at **1× and 3×**. Sun and moon swatches
  on the right are 4×. The cyclic strip correctly splits the opposite
  phase's symbol across its two outer edges at noon and midnight.

## Files and handoff

[drafts/manifest.json](drafts/manifest.json) is the machine-readable index:
thing, draft, title, idea, file paths, dimensions, mode, geometry and
reference hashes. Paths inside the manifest are relative to this directory.

### Mailbox nodeboxes

Each `drafts/mailbox/<A|B|C>/` contains four **16 × 16 RGBA** files:

- `grug_mapgen_mailbox_top.png`
- `grug_mapgen_mailbox_side.png`
- `grug_mapgen_mailbox_front.png`
- `grug_mapgen_mailbox_back.png`

The manifest gives every box as
`[xmin, ymin, zmin, xmax, ymax, zmax]` in **node units**. Positive Y is up;
the default front is **negative Z**. All three candidates fit within one
node, from Y = −0.5 to +0.5, with a narrow post and a wider upper box.
A and B each use four boxes; C uses seven for its stepped roof.

Use the normal six-face order **top, top, side, side, back, front**.
Every box shares those same six tiles: lower texture rows draw the post,
upper rows draw the box and roof. There is no per-part material or mesh
requirement. The back has no letter emblem. Rotation is the WORLD lane's
placement concern.

The preview renderer samples **node-aligned UVs**, rather than stretching a
whole tile over each smaller box. This follows
`reference_projects/luanti/src/client/content_mapblock.cpp`,
`generateCuboidTextureCoords` and `nodebox_tile_dirs` (read from the main
checkout's pinned reference). Face shading is illustrative; engine lighting,
perspective and distance filtering are not simulated.

### Mail HUD icon

Each `drafts/icon/<A|B|C>/grug_map_mail.png` is **32 × 32 RGBA**. Its
lower-right rectangle **x = 18…31, y = 22…31** is transparent for the
badge. The examples put **3** at (24, 22), or **9** at (18, 22) and **+**
at (24, 22). These placements fit within the 32 × 32 image.

The preview reads the shipped cooldown digit PNGs from
`mods/PLAYER/grug_abilities/textures/` and reduces their four-pixel cells
to one pixel, giving **7 × 9** outlined glyphs. No numeral is redrawn.
This branch does not yet contain the HUD lane's final `+` glyph: the
preview-only plus reuses the existing digit 4's crossbar pixels horizontally
and vertically, with their original white and black. **No plus asset is
delivered or added to the cooldown generator.** The HUD lane owns the final
plus and badge image composition.

### Daytime band

Each `drafts/band/<A|B|C>/` contains:

| File | Size / purpose |
| --- | --- |
| `sun.png` | 16 × 16 RGBA, transparent sprite |
| `moon.png` | 16 × 16 RGBA, transparent sprite |
| `frame.png` | 168 × 40 RGBA, **exact-size overlay**, not a 9-slice |
| `marker.png` | 10 × 40 RGBA, fixed overlay |
| `palette.json` | Day, night and optional transition colour; full composition geometry |

The visible cycle is exactly **160 pixels** wide: **120 day + 40 night**.
The frame adds four pixels outside either end, making the complete HUD
image **168 × 40**. The content viewport is `(4, 8, 160, 24)` in
`(x, y, width, height)` notation; the symbols are placed at Y = 12.
The sun's cycle centre is 60; the moon's is 140. The marker's origin is
(79, 0), with the fixed now axis at X = 84.

Composition order is strip, symbols clipped to the viewport, frame, marker.
For each viewport X, sample `(X + now_phase - 80) modulo 160`.
Increasing `now_phase` moves the strip right to left. The preview phases
are 60 (noon), 120 (dusk/day-to-night boundary), and 140 (midnight).
The HUD lane supplies its existing time-to-phase function and 40 finished
images; this proposal generator does not implement runtime timekeeping.

A blends across an 8-pixel interval around each boundary, C across 12
pixels; B has a hard boundary. Blend colours are overlays within the
existing phases, not extra phases or extra width. Exact interpolation is
recorded in `palette.json`. The parts contain no numbers or text.

## Regeneration and verification

Python **3 standard library only**; no installed image library is needed:

```sh
python3 tools/r48_artm/generate.py
python3 tools/r48_artm/generate.py --check
```

The generator writes only inside this directory. `--check` rebuilds the
expected output in memory and compares every generated file byte for byte.
It decodes **every PNG**, checks CRCs, dimensions, 8-bit RGBA mode and pixels,
rejects unexpected PNGs, and checks binary alpha, zero transparent RGB and
the icon badge reserve. The result is **30 PNGs**: 12 mailbox face textures,
3 icons, 12 band parts and 3 preview sheets. The other generated files are
three palettes, the manifest and the media ledger.

All preview reference images are existing **CC0** project artwork. The
manifest records their exact SHA-256 values and
[LICENSE-media.md](LICENSE-media.md) records every image and palette.
All new textures, icons, symbols, frames, backgrounds and caption lettering
are drawn directly by the committed generator. No media was downloaded.

Delivery verification (2026-10-14): generation and `--check` **PASS**;
an independent decode with installed Pillow confirmed all 30 PNG modes and
dimensions against the manifest and all 30 image ledger rows. All three
comparison sheets were visually inspected. Pillow is only an independent
inspection tool here, not a generator dependency.

## Scope and remaining validation

Upgrade classification: **compatible**, proposal files only. The mailbox
placement change belongs to WORLD and its round-level map reset.

The cited plan facts are confirmed at this branch's base: the waystone
textures are 16 × 16, cooldown digits are in `mods/PLAYER/grug_abilities/`
(not `mods/ITEMS/`), and the band uses the 120:40 cycle. Round 48 §2.1
overrides the earlier mail plan's hidden-minimap placement rule. The open
root TODOs do not block this art work. The HTML mail wireframe was read as
non-binding context.

No `mods/` files, Lua, fixtures, runtime code, sounds or external worktree
files are changed. No agents, engine, push or merge are used. This step's
review is the user's art pick; the admin shield, NPC seal and final asset
installation belong to the separate step 2 brief. Ten-node mailbox
recognition and actual desktop/web HUD readability remain GUI checks for
the user after integration; the offline previews do not establish those.
