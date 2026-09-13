# WP13: Hearthpine settlement polish

Status: implementation and integration checks in progress, 2026-09-14.
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
- Real successor clipping/replay and dry-start surface precedence fixtures.
- Two independent fresh headless Luanti worlds with opposite owner orders,
  each followed by disk-only reload. Bound structure coverage to at most
  twelve owners plus a second-start control; compare all authored names and
  param2 values, night lights, clear routes and an intentional edit canary.
- Plain-5.1 parser, SETGLOBAL and all five source sweeps, including changed
  Lua under tools; final compact PUC/LuaJIT canonical parity on frozen bytes.
- Independent review of code and immutable evidence, then merge/sync and a
  focused user GUI playtest in a fresh dwarf world.

Stop and report any need for broad map authority redesign, unrelated geometry
changes or new player-visible mechanics. Keep the existing approval in force
for routine fixes within this contract.

## Evidence and calibration

Pending final checks and independent review. Implementing models: GPT-5.6 Sol
(delegated terrain and blueprint), root coordinator (acceptance/integration).
Reviewer, severity counts, fix rounds and elapsed wall time will be recorded
before integration. Historical first-increment evidence retains its identity.
