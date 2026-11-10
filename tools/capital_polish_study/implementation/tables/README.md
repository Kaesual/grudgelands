# Guild tables — implemented

Classification: **map reset** (authored world-generation templates change).
User approved the study's existing `grug_decor:xdecor_table` variant for all six
Miner's Guild houses. `tools/r58_halls/make_halls.py` now emits it at y=1:
one table for the clerk and three adjoining tables for each of the exchange,
Stonewright and leader desks. All NPC points and table floor footprints remain
unchanged. The Registrar's relocation is a separate coordinator-owned change;
the original clerk table remains useful for the ordinary resident.

The generator is the owner; its six declared `*_miners_guild.tpl` outputs were
regenerated. The large textual diff is sorted legend re-keying. The semantic
change is exactly **11 cells per template**: ten table cells replaced and the
old clerk's upper slab removed. No other cell, point or bounding dimension
changed.

## Evidence

- `python3 tools/r58_halls/make_halls.py --check`: PASS, six outputs match.
- `luajit tools/r58_halls/portable_test.lua . none`: **2195 checks passed**;
  `r58-halls.log`. This checks finished-plot service reachability and sockets;
  the unrelated seed planner was not repeated for furniture changes.
- `python3 tools/capital_polish_study/implementation/tables/verify_and_render.py`:
  all six shipped templates' visible cells match the accepted proposal exactly;
  all six only change the 11 recorded furniture cells, retaining points/bounds.
  `verification.json` records source hashes and exact changed coordinates.
- `scenes.html` reads the actual shipped template cells and supports all six
  cities. `renders/human_actual.png` is an actual-output shared-web-renderer
  capture, separately saved and visually inspected. Its receipt sits beside it.
  Grey figures remain 1.70-node scale references, not actual NPC captures.
- `grug_decor:xdecor_table` was already in the editor palette (line 745).
- No Lua was changed in this lane. No global validator or fixture fleet was
  repeated here; the coordinator runs the integration gates once.

The original proposal snapshots under `../../tables/` are preserved. Their old
build command is a study of the old source geometry and is not the implementation
builder; do not regenerate those snapshots from the now changed templates.

To repeat the actual-output capture after verification:

```sh
node tools/character_creation_preview/render-scenes.mjs \
  --directory "$PWD/tools/capital_polish_study/implementation/tables" \
  --width 1400 --height 900 --race human_actual
```

No merge, push or personal installation sync was performed. Interactive native
client acceptance remains the user's, alongside the coordinator's broader
capital polish checklist.
