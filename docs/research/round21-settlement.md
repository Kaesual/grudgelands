# Round 21 constructed-ground candidate

2026-09-24. G1 implementation candidate; independent review, combined real
manifest/writer checks and GUI acceptance are still pending.

## Changes

- Dry fitted ground for every anchor receives the existing biome surface skin.
  Protection, vegetation exclusions, route opcodes and anchor identities stay
  unchanged. Authored building foundations and paving still replace that skin.
- Street intersections cover complete squares, including the outer corner of
  an L. One run owns each junction column; incident strips yield their cells.
  Existing shared height computation remains in use. Junction surfaces have
  no internal kerbs or endpoint stair treads.
- Kezamba's core approach has a fixed landing at the civic floor. Its gate ramp
  ends on a flat two-column landing; the separate gate marker no longer places
  blocks or air in the ramp's carriageway.
- District plots receive an eight-node natural collar, with cut uphill and fill
  downhill. Their public north-side entrance may connect to a street up to
  24 nodes away. The actual built street profile is sampled once per touched
  plot and cached, including a junction owner when necessary. Approaches slope
  toward that existing street height and use oriented stairs. Plot reference
  height and socket projection are unchanged. Collars and approaches are
  emitted before plots and streets, with owner clipping. Without a nearby
  street, a short entrance aisle meets natural terrain within the eight-node
  collar; a distant street is not a requirement for every building.

## Deliberate bounded failure reporting

The implementation does not invent a new route solver. A plot with more rise than its bounded straight
approach can accommodate, or an unsuitable natural endpoint, is reported in `approach_findings` on its settlement
ledger and metrics. It does not abort world generation. Such a report is **an
unresolved access case**, not acceptance evidence; inspect these findings in
combined real-owner checks and resolve or explicitly scope any actual case
before claiming all reported building access defects are fixed. A longer
approach with a bend would be the next bounded fallback if needed.

## Verification so far

Only small LuaJIT fixtures were executed, each under a 20-second timeout.
The final development pair took 0.02 seconds wall/user and 0.00 seconds system
on this workstation; earlier targeted iterations were 0.00–0.02 seconds each.
No PUC runtime, engine, seed fleet, whole roster build or full-world population
was run by G1. Plain-5.1 parsing, SETGLOBAL inspection and the five source sweeps
passed on changed/new Lua files, including fixture files.

- `tools/round21/settlement_micro.lua`: real street/avenue geometry for L/T/X,
  an inclined L, complete-square coverage, flat junction height, whole/split
  equality, fixed core landing, uphill/downhill collar and gate ownership.
- `tools/round21/settlement_seam_micro.lua`: real settlement prepare/config and
  writer on one tiny synthetic core/plot/street; split-owner equality, preserved
  anchor root, unchanged socket base, stair approach floor/headroom, and visible
  reporting of an impossible short approach.

Root owns the final PUC/LuaJIT pair and the combined real `r7_manifest.new` plus
planner/writer checks. Check final nodes around `(1800,66,1448)` and
`(2056,40,1499)` on seed `7354267267733045968`, including stair orientation,
walk surfaces and two nodes of headroom, and inspect at least one actual plot
approach plus its `approach_findings`. Scalar profiles alone do not prove the
final writer's composed walkability. Visual acceptance remains user-run.

The selected-owner replay confirmed a clear core, gate and canopy-muster
entrance. The gate helper retains half-node steps through the first exterior
connection, then permits ordinary one-node exterior terrain steps. The actual
totem-store layout has no nearby street; its bounded natural entrance is
covered by the real synthetic writer fixture and awaits combined owner evidence.
