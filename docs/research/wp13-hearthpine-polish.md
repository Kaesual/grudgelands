# WP13: Hearthpine settlement polish

Status: independently reviewed; native engine and interpreter checks green,
ready for the focused user GUI playtest, 2026-09-14.
Classification: non-trivial (terrain semantics, architecture and test gates).
WP13 remains in progress; this is one settlement's second increment.

## Authority and frozen scope

The first [increment](wp13-hearthpine-brief.md) passed the user's appearance
and leave/reload test. The user reported sparse occupation of the large pad,
a deeply sunken platform and a half-node watchpost roof gap, and authorized
this follow-up. [Settlements](../design/settlements.md) records the decided
appearance. World envelopes, protection and road authority remain unchanged.
No open design TODO blocks this bounded increment.

Add two homes, storage and a community hall; restore pine ground, modest
planting, exterior props and warm route lighting. Fix the watchpost bearing.
Fit all six start pads to sampled natural terrain, keeping the existing shared
spawn/road height authority. Restore existing biome surfaces only on dry
start-fitting ground. Preserve road, water and other functional precedence.
No new assets, dependencies, NPCs, services, quests, professions, terraces,
world migrations or extra generation callbacks.

## Ownership, interfaces and routing

Two isolated GPT-5.6 Sol worktrees implement the frozen terrain and blueprint
lanes. The terrain lane owns height fitting, a dedicated terrain fixture and
the narrow R6 start-surface seam. The blueprint lane owns only the authored
blueprint. The coordinator owns docs, independent acceptance fixtures, visual
inspection, integration and final review handoff. A fresh strong reviewer
must cover the entire resulting diff under the process checklist; no author
self-approves.

Retain the blueprint's existing constructor, palette identity, canonical
unique z/y/x cells, bounds x/z [-63,63], y [-2,24], all-axis owner clipping,
shared VM transaction and edit-preserving reload behavior. The expanded
blueprint budget is fewer than 125,000 cells, including explicit air and
terrain layers, with at least nine reachable interior/lookout destinations.
The five-wide north route and spawn clearance remain mandatory. The first
increment's 60,000-cell test ceiling is superseded for this larger content.

## Verification budget

Read and follow `luanti-lua.md` interpreter strategy. LuaJIT owns development
and seed checks; PUC owns parsing, static gates and one final bounded parity
process matched to the same LuaJIT fixture. No intermediate PUC runtime or
PUC world construction. At most seven interpreter processes workstation-wide,
with idle scheduling for independent runs and isolated output paths.

- Five fixed seeds (0, 1, 42, 8675309 and 531802985935182545), all six starts:
  sampled earthwork cost, feasible limits, spawn flatness and road-pin agreement.
- Compact independent blueprint acceptance: unique cells, palette/bounds,
  ground coverage, actual full-height roof bearing, every torch's support,
  conservative route reachability and all nine destinations.
- Real successor clipping/replay and compact dry-start eligibility controls.
- For each of two seeds (531802985935182545 and 8675309), two independent
  fresh headless Luanti worlds with opposite owner orders,
  each followed by disk-only reload. Bound structure coverage to at most
  twelve owners plus a second-start control and one filler-only boundary
  owner; compare all authored names and
  param2 values, night lights, clear routes, outside-blueprint soil and an
  intentional edit canary. Seed 8675309 checks Stillgrave at y=48 while only
  its lower y<=47 owner is generated, requiring dirt at y=47.
  The isolated full-R6 capture was stopped after about three minutes without
  a completed pass; it is not acceptance evidence. Use the live R7 engine
  boundary witness instead of retaining an unverified expensive fixture.
- Plain-5.1 parser, SETGLOBAL and all five source sweeps, including changed
  Lua under tools; final compact PUC/LuaJIT canonical parity on frozen bytes.
- Independent review of code and immutable evidence, then merge/sync and a
  focused user GUI playtest in a fresh dwarf world.

Stop and report any need for broad map authority redesign, unrelated geometry
changes or new player-visible mechanics. Keep the existing approval in force
for routine fixes within this contract.

## Evidence and calibration

Final implementation candidate: `fa39a23`. Preserved evidence:
[`tools/wp13/evidence/20260914-hearthpine-polish`](../../tools/wp13/evidence/20260914-hearthpine-polish/).
The package is ready for GUI testing; it does not close WP13.

- 88,167 authored cells, 20 materials, 41 lights and nine reachable interior/
  lookout destinations. All first-increment writer and clipping contracts remain.
- Five-seed height receipt: all 30 starts pass. On user seed
  `531802985935182545`, Hearthpine rises from y=9 to y=25; sampled absolute
  earthwork falls from 1,288 to 104. One other start has no common eight-node
  cut/fill interval and truthfully reports an excess of three. The road remains
  y=25 through the gate and the checked continuation to local z=80.
- Native Luanti: both seeds pass forward/reverse generation and cold/disk reload,
  eight passes in total. All authored node names/param2, 41 lights, nine lit
  destinations, every main-road foot position, soil outside the blueprint and
  the deliberate edit canary pass. Stillgrave's surface at y=48 leaves the
  required dirt at y=47 in the separately generated lower owner. All eight
  architecture digests equal
  `bf4c0d5aa132bb972516f8f98c95ba556411501f41ada6cbeb2f01f2c43d76d0`.
- Final parser/SETGLOBAL/five sweeps and fresh-server source audit pass.
  One final PUC-5.1/LuaJIT pair is byte-identical at
  `f443cbb1971b857e9ff296f5802e6fcad1cf3f9414f0bc82e0869df52212806c`;
  the real manifest constructor and immutable input checks pass. This parity
  is not a claim of a new browser-engine playtest.
- Independent review closed one Medium finding: excluded start grades no longer
  create decoration candidates destined for rejection. Natural P7 painting is
  retained; ordinary candidate populations remain unchanged. Final review has
  zero remaining findings. The full report is preserved with the evidence.

Calibration: implementing models GPT-5.6 Sol (two delegated lanes) and
GPT-6/Codex (coordinator, acceptance and integration); reviewing model GPT-5.6
Sol in a fresh independent context. Same-model review followed observed Opus
unavailability, documented in the first increment's evidence. Initial review
findings: 0 Critical / 0 High / 1 Medium; one review fix round; final findings:
0. Observed elapsed wall time: `unknown`.

## User runtime test

Create a fresh world and choose dwarf. Walk through the nine buildings, inspect
the watchpost roof and climb its lookout, follow the gate road into the vale,
and look at the pad edge. Set night and inspect the illuminated route and
interiors. Leave and reload. Seeds `531802985935182545` (Hearthpine y=25) and
`8675309` (Hearthpine y=16) are the native regression examples. Broader civic
terracing and the remaining starts/capitals remain later work.
