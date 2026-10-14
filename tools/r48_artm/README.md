# Round 48 ARTM — Picked mail and daytime art

Step 2, **2026-10-14**, by **GPT-6 Astra**. The user picked **mailbox A
(Wayside chest), icon B (Sealed envelope), band A (Brass channel)** with
no change requests. All new artwork is original pixel art, dedicated to
**CC0-1.0**. The original nine proposals remain for provenance.

## Shipped files and adaptations

Paths below are repository-relative. The complete per-file list, sizes,
mode, source draft, generator and SHA-256 are in the `shipped` array of
[drafts/manifest.json](drafts/manifest.json); its paths start at the
repository root, while the historical `drafts` paths start here.

### 1. Mailbox A — Wayside chest

`mods/MAPGEN/grug_mapgen/textures/grug_mapgen_mailbox_` plus `top.png`,
`side.png`, `front.png`, `back.png`: the four **16 × 16 RGBA** draft A
files, copied **byte-identically**. `world_nodes.lua` uses the manifest's
four A boxes (foot, post, wide box, flat lid), in node units, and tiles
**top, top, side, side, back, front**. Only those fields and the placeholder
comment changed. WORLD's obsolete placeholder generator was removed.

Every box shares the six tiles with node-aligned UVs; the default front
is negative Z. The preview renderer samples these UVs following
`reference_projects/luanti/src/client/content_mapblock.cpp`,
`generateCuboidTextureCoords` and `nodebox_tile_dirs` (read from the main
checkout's pinned reference during step 1). It uses an orthographic camera
at 24 pixels per node; each straight-view canvas is 38 × 38 pixels.
Lighting is illustrative; perspective and distance filtering are not simulated.

### 2. Icon B — Sealed envelope; band A — Brass channel

**Mail HUD part:** `tools/r48_hud/parts/mail_icon.png`, **48 × 40 RGBA**.
B redrawn at the larger allowed size with the same wide folded paper,
small wax closure, colours, pale outer edge and dark inner contour.
The larger envelope meets the final compositor's half-size cooldown
digits; the 32 × 32 proposal would leave them detached. `badge: null`
keeps the preview's digits without a pill. Ten finished **60 × 52 RGBA**
images (since the follow-up lane HUD2 **87 × 28**: the compositor crops the
envelope to its 46 × 28 opaque pixels and draws the count beside it at
3 px per glyph cell, with room for "9+", so it stays readable at the band's
height): `mods/PLAYER/grug_map/textures/grug_map_mail_1.png` through
`_9.png`, plus `_9p.png`.

**Band parts:** `tools/r48_hud/parts/{sun,moon,frame,marker}.png` and
`palette.json`. Sun and moon are byte-identical **16 × 16 RGBA** A
sprites. The frame is **160 × 40 RGBA**, with its three-pixel brass rim
inside the image and a transparent **154 × 34** interior. The HUD
compositor fills its entire 160 × 40 canvas, so the rim encloses that
full height instead of the draft's 24-pixel viewport and transparent
exterior. The original 10 × 40 marker is placed at (75, 0) on a
transparent **160 × 40** overlay, putting its pointer tip at **x = 80**.
Day `#bda778`, night `#273d50`, blend **8 px**; the contract's direct
day/night interpolation replaces the draft's third twilight colour.
The unused `badge_rim` is `#d8caa6`, the envelope's pale outer contour.
Forty finished **160 × 40 RGBA** files:
`mods/PLAYER/grug_map/textures/grug_map_daytime_00.png` through `_39.png`.
HUD's compositor and cooldown glyphs are unchanged.

### 3. Mail window — Admin shield and NPC wax seal

`mods/PLAYER/grug_mail/textures/grug_mail_admin_badge.png` and
`grug_mail_npc_seal.png`, both **32 × 32 RGBA**. Original derived marks:
a brass shield with a pale check and a wax seal with a folded envelope
impression. Both use B's pale/dark contours, paper/wax colours and A's
brass. Painted by `generate.py` through `final_art.py`. MAIL's obsolete
placeholder generator was removed; no mail Lua comment named it.

### 4. Records and final sheet

This README, the manifest and the media ledgers here and in `grug_mapgen`,
`grug_map`, `grug_mail` record the picks and shipped files. The tools index
records the final generators. One row per PNG and palette appears in the
local [LICENSE-media.md](LICENSE-media.md), including the generated parts;
each mod's ledger records every final PNG in that mod.

[previews/final.png](previews/final.png), **1200 × 1376 RGBA**, shows:

- mailbox front and side nodebox studies at **4×**, the four texture
  swatches and existing waystone side/top textures at **4×**;
- actual HUD compositions **1, 3, 9+** at **1× and 2×**, on light sand
  and dark forest ground;
- actual bands **15 (noon), 30 (dusk), 35 (midnight)** at **1× and 3×**;
- shield and seal at **1× and 2×** on the window dialog's dark grey
  `#24272c`, plus **1×** samples on its list `#0d0e10` and admin banner
  `#3a3018` backgrounds (`grug_mail/window.lua`).

All enlargement uses nearest-neighbour pixels. The final sheet calls the
real HUD compositor; it does not approximate its symbols, phase positions
or digits. The mailbox views are offline nodebox renders, not screenshots.

## Original proposal catalogue (step 1)

| Thing | A | B | C |
| --- | --- | --- | --- |
| Mailbox | **Wayside chest:** broad oak box, flat metal lid, pale envelope plaque. | **Letter pillar:** upright iron cassette, brass slot, envelope plate. | **Sheltered post:** wooden box beneath a stepped copper roof. |
| Mail icon | **Open letter:** written page above an unfolded envelope. | **Sealed envelope:** wide folded envelope with a small wax closure. | **Ribbon seal:** scalloped seal with envelope impression and two paper tails. |
| Daytime band | **Brass channel:** eight-ray sun, crescent, single downward pointer. | **Carved timber:** diamond sun, half moon, opposing pointers, notched frame. | **Slate rails:** round sun, cut moon, fine vertical marker beneath a bead. |

The mailbox designs share a pale letter symbol, warm wood and subdued metal
to fit both The Accord and The Throng. The manifest preserves all draft
geometry, files and composition rules. No original draft pixels changed.

The original sheets are [mailbox.png](previews/mailbox.png) (1200 × 748),
[icon.png](previews/icon.png) (1200 × 840), and
[band.png](previews/band.png) (1200 × 1664). Read native samples at 100%.
Their band frame is 168 × 40, viewport `(4, 8, 160, 24)`, marker 10 × 40
at (79, 0), now axis x=84; each icon is 32 × 32 with a reserved lower-right
badge rectangle. These are historical proposal dimensions, superseded
only in the shipped adaptations above.

Step 1 preceded HUD's final `+` glyph: its preview-only plus reuses digit
4's crossbar pixels. Its badges reduce existing cooldown glyphs to 7 × 9
cells. The final sheet instead uses HUD's actual half-size glyphs and `+`.
The draft preview phases (60, 120, 140) are exact cycle centres; final
images 15, 30, 35 use HUD's existing half-step offsets (62, 122, 142).

## Regeneration and verification

Python **3 standard library only**:

```sh
python3 tools/r48_artm/generate.py
python3 tools/r48_hud/gen_hud_textures.py
python3 tools/r48_artm/generate.py --check
python3 tools/r48_hud/gen_hud_textures.py --check
```

`generate.py` and its `final_art.py` helper write the original proposals,
the final sheet, the picked HUD parts and the named final PNGs under
`mods/`; HUD composition uses `tools/r48_hud/gen_hud_textures.py` itself.
The explicit HUD invocation above is also the standalone recomposition
path. Do not use its `--placeholders` option: it overwrites picked parts.

`--check` rebuilds expected output in memory and compares every generated
file byte for byte. It decodes **every PNG**, checks CRCs, dimensions,
8-bit RGBA mode and pixels, rejects unexpected PNGs here, and checks binary
alpha, zero transparent RGB and the original icon badge reserves.
The result is **92 PNGs**: the original 30, four shipped mailbox textures,
five HUD parts, 50 composed HUD images, two window marks and the final
sheet. Four palettes, the manifest and the local ledger bring the generated
total to **98 files**. The mod ledgers are maintained as documentation.

All source images are original or existing project **CC0** artwork.
Reference hashes are recorded in the manifest. No media, fonts or other
material was downloaded. Captions and ground swatches are original. Pillow
is used only for independent inspection, not as a generator dependency.

Delivery checks (2026-10-14): both generators' `--check` **PASS**;
independent Pillow decode of all **92 PNGs** confirms manifest sizes,
RGBA and binary alpha. Hashes and every final media-ledger row match;
the four mailbox copies, sun and moon are byte-identical to their drafts.
The Lua delta is limited to the specified mailbox fields and comment,
with its boxes and tile order checked against the manifest.
`bash tools/check_lua.sh mods/MAPGEN/grug_mapgen/world_nodes.lua` **PASS**
(plain-5.1 parser and all six sweeps); `luajit tools/web_data/export.lua .
--check` **PASS** (web data unchanged); documentation links and
`git diff --check` **PASS**. The final sheet was visually inspected.
No fixtures were run, as required by this art brief.

## Scope and remaining validation

Upgrade classification: **compatible**, art and the existing mailbox
node's in-bounds shape only; no stored-state format, node ID or placement
changes. WORLD owns the placement and its round-level map reset.

The brief's file facts are confirmed: WORLD registers the named node;
HUD composes the fixed names from parts; MAIL uses the two 32 × 32 marks.
The open root TODOs do not block this art work. No fixtures, gameplay logic
or sounds are changed. No agents, engine, push or merge are used. The review
basis is the user's art pick; the coordinator checks the adaptation at
integration. Ten-node mailbox recognition and actual desktop/web HUD
readability remain GUI checks for the user.
