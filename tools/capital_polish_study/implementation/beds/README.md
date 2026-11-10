# Dawnmere inn beds — 2026-11-10

**Implemented; map reset**, included in the coordinator's 0.72.3 declaration.
Only `dawnmere_harvest_inn.tpl` is changed by this lane. The Human start town is
Dawnmere; Hearthpine is the Dwarf town and was included in the comparison audit.

## Exact cause and repair

The inn's two bed feet were at (1,1,13) and (3,1,13), facing +z. Their heads at
(1,1,14) and (3,1,14) occupied the outer rear-wall row z=14, replacing wall cells.
Both bed halves were correctly paired and correctly oriented. This was placement
through the wall, not an oversized model or rotation bug.

The actual bed definitions in `mods/BASE/beds/beds.lua` keep each drawn nodebox
within its own cell. `mods/BASE/beds/api.lua:get_other_bed_pos` and
`wp13/parts.lua:bed` require the top half one facedir step from the bottom half.
The two-node selection box is not the rendered mesh.

Move both complete beds one node inward: feet at z=12, heads at z=13, unchanged
x/y and facedir0. Restore (1,1,14) as `window_frame`, continuing the original
frame directly above it (as the same wall's x=4/5/8 frame columns do). Restore
(3,1,14) as `wall_accent`, continuing the low wall course beneath the glazing,
as at x=2/6/7. Exactly six cells change. All other content, points, bounds and
orientations stay unchanged.

## Checks and saved evidence

- `install.py` uses the real template editor's validated, stale-hash-protected,
  atomic `Editor.save`. Its result and source/output hashes are in
  `save-report.json`; `before/` and `after/` preserve the exact two files.
- `verify_render.py` checks the six semantic changes and unchanged points/bounds,
  resolves the actual Human roster palette, verifies both complete bed pairs,
  nodebox containment and the restored solid wall.
- Conservative two-high occupancy traversal from inside the front door reaches
  both foot-side approaches. This is a static access check, not a native NPC
  pathfinding or runtime acceptance claim.
- The comparison audit covers **230 complete beds across 96 templates**, including
  all start towns and capitals. No invalid directed pair was found. The only
  heads on the outer rectangular building boundary were these two; none remain.
  This boundary scan is a focused comparison, not proof about every possible
  interior partition or irregular building shape.
- `renders/` contains four actual saved-cell web-renderer captures, 1280 × 900:
  before/after outside and inside. Both pairs share their camera. Upper walls
  and surrounding geometry are cropped only for visibility. All four were
  visually inspected, with no missing media. `gallery.py` checks their input
  and output hashes before embedding `index.html`.

The bed fix was saved before the coordinator's general furniture edit. The
coordinator was notified to reload the new inn template before applying tables.
Render snapshots intentionally preserve that handoff state; the later table
change is independent of these six cells. Do not overwrite later furniture edits
with the saved template snapshots. The installer refuses an unexpected source.

```sh
python3 tools/capital_polish_study/implementation/beds/verify_render.py
node tools/character_creation_preview/render-scenes.mjs \
  --directory tools/capital_polish_study/implementation/beds --width 1280 --height 900
python3 tools/capital_polish_study/implementation/beds/gallery.py
```

No Lua source, old building generator, other mod, main checkout, world or personal
installation was modified. The coordinator runs the combined global gates once;
native desktop/web acceptance remains the user's.
