# Independent review — live tables and Registrar fixture baseline

2026-11-10 · reviewer `throne_study` · read-only production review.

**Verdict: MERGE / PASS. No blocking findings.** Classification **map reset** is
appropriate: live deterministic builders change the furniture generated in new
settlement compositions. The explicit Registrar fixture additions reflect the
already approved outdoor placement; they are not a relaxed comparison of sockets.

Reviewed production diffs in `wp13/parts.lua` and `dressing.lua`, unchanged related
callers in `decor_kit.lua`, `all_tables/runtime_test.lua`, the bounded existing
fixture extraction in `runtime_decor_test.lua`, the modification to
`tools/r36_w/portable_test.lua`, and the recorded check logs.

## Findings verified against source

- `parts.table_cell` writes one existing `grug_decor:xdecor_table` at precisely
  the caller's supplied x/y/z. It neither writes nor clears y+1. The node already
  contains its attached support and thin top within one node; there is no second
  slab course or newly registered asset. Keeping the palette parameter preserves
  the existing call signature.
- Both live counter paths use that helper: every market-stall counter cell and
  each exterior-counter segment. Their canopy posts, canopy, storage and rug
  operations remain intact. These functions build fresh geometry; they do not
  perform an unsafe conversion of existing world nodes.
- The live crafting piece inherits the helper at the same coordinates and
  rotation; barrel-board assemblies still use `table_top` unchanged. Weapon
  racks and lean-to supports still use their existing fence materials. There is
  no global palette rewrite or indiscriminate replacement of every fence/slab.
- The focused fixture tests arbitrary foot height, preservation of a pre-existing
  upper prop, exact counter writes for both axes, all six cultures, all four
  relevant rotations, deterministic ordered writes, preserved stall components
  and the intentional barrel-board exception. The existing decor section is
  extracted with its original prelude and unmodified assertions, not rewritten
  to make the new geometry pass.
- The r36 baseline adaptation adds six literal expected socket records, one for
  each named capital core. Their positions and directions agree with the actual
  six `expedition_registrar` declarations: facing2 maps to (0,-1), facing0 to
  (0,1). All historical fields and sockets are retained, sorted with that one
  addition, and then compared exactly. Duplicate or additional actual sockets,
  changed old sockets, bounds or cleared-airspace fields still fail. The explicit
  additions counter must equal six.

## Evidence and limits

Inspected successful records: focused live-table fixture **342 PASS**, existing
decor section **857 PASS**, final complete r36 fixture **8985 checks passed**, and
Lua 5.1/parser/sweep logs for changed production and fixture files. The final full
fixture result is `runtime-r36-w-final.log`; the earlier historical failure in
`runtime-r36-w.log` is correctly retained rather than presented as a success.

The reviewer did not repeat these executions, rerender, run global gates, or claim
native-client acceptance. No production file was changed by this review.
