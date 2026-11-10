# Live table builders

2026-11-10 · `gates_roof_study` · **map reset**: these deterministic builders
change generated settlement furniture. All writes are in `character-creation`.
No palettes, shipped templates, node definitions or saved-state migration changed
in this lane.

`wp13/parts.lua` now builds one existing `grug_decor:xdecor_table` at the supplied
feet course. `wp13/dressing.lua` uses this helper for market stalls and exterior
counters. The existing node has a 0.125-node top, an attached support, and total
height 1.0 node. No new node, texture or supporting runtime mechanism is needed.

The helper deliberately does not write or clear the cell above the table:
existing goods or other explicitly placed props must survive. Fresh builder
output therefore has no elevated slab; this is generation, not a conversion of
already placed furniture. The palette argument remains for the existing API.

Audited callers: the live `decor_kit.P.craft` inherits the smaller supported table
in all four rotations and all six cultures. `P.stall` reaches the updated counter.
Direct stall/counter users throughout capital cores, district and start builders
inherit it as well. Other `table_leg` uses in `decor_kit` are intentional weapon
racks and lean-to supports; `P.stores` uses `table_top` as a board on a barrel.
These remain unchanged. In particular, there is no global replacement of the
`table_top` palette role.

## Verification

- `runtime_test.lua`: **342 PASS**, covering six cultures, both counter axes,
  four stall/craft rotations, repeated deterministic ordered writes, untouched
  upper props, preserved canopy/storage, and unchanged barrel-board assemblies.
- Existing `tools/r36_w/portable_test.lua` decor-kit section D: **857 PASS**, all
  pieces/cultures/rotations and house-dressing blocked/path/door rules. Executed
  directly from that existing section by `runtime_decor_test.lua`; no copied or
  weakened assertions and no source fixture modification.
- Lua 5.1 parser, global-write audit and six sweeps pass for both changed production
  files and the two added tool fixtures. Logs are `runtime*-lua-check.log`.
- Independently read actual registry box coordinates: top thickness 0.125, support
  reaches underside exactly, bounds [-0.5,0.5] (height 1.0).
- The complete existing r36_w fixture: **8,985 PASS** after the narrowly scoped
  expected-socket update in `tools/r36_w/portable_test.lua`. Independently generated
  current records differed from the historical baseline only by one outdoor
  `expedition_registrar` socket in each of six cores; no bounds or old socket
  differed (`runtime-baseline-diff.log`). The fixture now inserts exactly those six
  literal expected socket records, including coordinates and facings, and still
  compares every other field exactly. The historical TSV is unchanged.
  `runtime-r36-w.log` preserves the initial baseline failure;
  `runtime-r36-w-final.log` records the passing full suite. The updated fixture
  also passes Lua 5.1 parsing and all sweeps.


No broad global gates, client screenshots or runtime-pathfinding claims. At most
one LuaJIT process ran at a time, under idle CPU/I/O scheduling. Production edits:
`mods/MAPGEN/grug_mapgen/wp13/parts.lua` and `dressing.lua` only; the additional
fixture edit is `tools/r36_w/portable_test.lua`.
