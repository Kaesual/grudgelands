# Round 15 HUD implementation evidence

Status: implementation ready for independent review, 2026-09-21. Native Astra
implemented this bounded lane because the marker attachment transform required
engine inspection. Living rules are `docs/design/quests.md`, `docs/design/parties.md` and
`docs/design/progression.md`; the approved Round 15 execution record owns the
package scope and handoffs.

## Shipped changes in this candidate

- Both quest marker meshes use visual size 5 on all three axes. Their attachment
  y is 24.84 instead of 27. Original OBJ vertices remain unchanged.
- Quest tracking is vertically centred on the right and each line is actually
  right-aligned. Titles wrap instead of losing everything after the first line.
  At most two title lines and two objective lines per quest keep three tracked
  quests bounded; visible ellipses direct longer content to the journal.
- Parties are centred on the left using their actual 1–10 row count. Removing,
  joining or toggling recomputes all offsets. Offline rows retain their labels
  and empty life bars. Long names shorten more in narrow windows.
- The XP HUD is a gold 360×6 progress bar closest to the hotbar, with a small
  adjacent level label and a full bar at level 60. Exact XP remains in `/xp`.
  XP change callbacks write only changed width/level. Other bar dimensions and
  the order of life/resource/breath/skill/money remain intact.
- Shared `hud_layout.lua` owns all row, edge, centring and wrapping geometry.
  Side-column wrapping uses current render-target width divided by real HUD
  scaling, preserving room for the combat column. Existing half-second HUD
  passes detect resize/state changes without unchanged HUD packets.

## Engine geometry evidence

Both authored OBJ files have vertical bounds -0.30…0.54. The engine applies
`visual_size` to the mesh scene node in
`reference_projects/luanti/src/client/content_cao.cpp:702–705`; empty-bone
attachments are parented to the parent's visual scene node and their translation
is used directly at `:1457–1470`. Mesh and attachment coordinates are engine
units, ten per world node. The old upper extent is `(27 + 0.54)/10 = 2.754`
world nodes above a unit-scale parent. The new one is
`(24.84 + 5×0.54)/10 = 2.754`, and its lower extent becomes 2.334. Both
coordinates inherit the same parent scale, so this equality remains true if
the parent changes stature; the bounded fixture checks six representative
scales from 0.90 to 1.12 and both actual OBJ files.

Current quest villagers register visual size 1 in
`mods/ENTITIES/grug_mobs/start_villagers.lua:938`; the entity visual applicator
(`mods/PLAYER/grug_visuals/apply.lua:418–435`) changes textures and wielding,
not race stature. Their normal 1.7-node selection/collision height gives a
2.0-node name anchor via `content_cao.cpp:950–951`. The enlarged marker's
bottom thus retains 0.334 nodes of geometric clearance above that anchor.
Screen-space text at distance and extreme viewing angles still needs GUI
inspection; the geometric result does not claim universal pixel separation.
The existing per-viewer visibility callback, state precedence, 25/30 distance
hysteresis owner and observer partitions are unchanged.

Text alignment is verified in `reference_projects/luanti/src/client/hud.cpp:
419–437`: vertical offset uses the full multiline text height, while each
line's x offset uses its own measured width. Thus `alignment={x=-1,y=0}`
right-aligns every line and centres the actual block without guessed widths.

## Bounded validation and artifacts

`tools/r15_hud/hud_micro.lua` loads all five changed production files in isolated
engine stubs and drives their real callbacks. It covers empty/half/boundary/cap
XP, no-op writes, 1–10 party row recentering, saved-toggle consumers, empty
quests, long wrapped titles, current-window changes, both marker meshes,
observer state replacement and marker cleanup. It returns one canonical line:

```
r15_hud PASS xp=360x6 party=1..10 quest=right-centre markers=5x,top-fixed idle-writes=0
```

Development checks used LuaJIT only. The coordinator must include this fixture
in the one final bounded PUC/LuaJIT pair; no PUC runtime was run by this lane.
Plain Lua 5.1 parsing, SETGLOBAL inspection and all five source sweeps include
the tool fixture explicitly; evidence is in `tools/r15_hud/evidence/static.txt`.
The only global write is the existing `grug_xp` mod table.

The three gallery layout images are **schematics drawn from the actual fixture
HUD definitions, not engine screenshots**. Their TSV inputs are committed;
`render_layout.py` regenerates them. Cases: 1280×720 scale 1, 1000×750 scale
1.25, and 640×480 scale 1. All have three long tracked quests and ten party
members. Neighbouring combat rows/hotbar are labelled schematic context.
`marker-bounds.png` projects the actual OBJ faces before/after using the
engine transform arithmetic; `render_markers.py` regenerates it.

The old `tools/ui/hud_bars_kat.lua` hard-codes XP as text and resource as the
bottom row. Those expectations are superseded by the approved XP change; it
was not run or rewritten as unrelated ownership. The new bounded fixture checks
all shared rows remain disjoint and the existing combat widths remain 180.

## Remaining user runtime check

View both marker types at all six racial quest givers near and far, including
one player with a different quest state. Check three tracked quests and a full
party at normal and small windows/HUD scaling, resizing while connected. Check
XP gain, next-level reset and cap; toggle both side HUDs and rejoin. Exact font
metrics are client-owned: very small effective viewports (e.g. 400×300 HUD
units) cannot fit ten readable rows plus the normal HUD and require a larger
window or smaller HUD scaling. No claim of fitting arbitrarily small windows.
