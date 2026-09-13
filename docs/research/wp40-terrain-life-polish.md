# WP40 R8 terrain-life polish

Status: implementation and independent review in progress, 2026-09-13.
Fresh worlds only; Rehearsal remains reserved for the kaesual-stack agent.
The reference seed is the exact string `4655649881628627392`.
Reported camera positions are (189.5, 200.9, 643), (343.9, 110, 56.9),
(102.1, 102, 58.4), (−207.6, 50.3, 104.6), and (−632, 50.1, −1346.3).
These are camera positions, not asserted POI centers.

## Accepted scope

- Predominantly bare, bent and forked Gravewood with only scattered grey dead
  leaves. Two original schematics feed both mapgen and sapling growth; wood
  remains connected when every optional leaf is omitted. Keep existing biome
  densities, wood recipes, and harvesting rules.
- Fit ordinary POIs to natural terrain, flatten only a necessary building core,
  and grade a natural collar. Full multi-height city structures remain WP13.
- Balance existing broad/detail relief fields without adding a noise pass;
  retain regional elevation identity. Vary inland/coastal beds and material,
  preserve crossings, containment, deep ocean and dragon channels.
- Give air fliers a bounded gentle near-ground tendency; purposeful native
  movement owns combat and escape. Unknown terrain never commands blind descent.

The exact geometry contract is in
[terrain-life geometry](wp40-terrain-life-geometry.md), and the controller
contract is in [flight nudge](wp40-flight-nudge.md). Decided user-facing rules
are folded into `docs/design/world_zones.md` and `docs/design/biomes_mobs.md`.
There is no old-world reader, migration, compatibility alias or cleanup pass.

## Ownership and gates

The coordinator implements Gravewood/catalog integration and final evidence.
A separate GPT-5.6 Sol context implements terrain/POI/water; another implements
flight. Independent strong-agent reviews cover each production scope and the
integrated fixtures. Every High/Critical correction receives focused review.

LuaJIT owns development and geometry measurement. Inputs stay immutable during
runs, outputs are separate, and local interpreter concurrency never exceeds
seven (idle scheduling). Plain 5.1 owns parser/SETGLOBAL/five static sweeps and
one final compact runtime process, paired once with LuaJIT on identical frozen
bytes and compared by canonical digest. No intermediate PUC runtime or VM use.
Actual GUI appearance, mob combat feel and fallback-engine runtime remain the
user's local runtime gate; offline geometry timings are not a real-engine FPS
or complete chunk-generation benchmark.

## Review record

Flight: implementer and reviewer GPT-5.6 Sol; initial 0 Critical / 1 High;
first fix exposed 1 Medium, second fix clean. Two fix rounds; elapsed unknown.
The final independent verdict covers `c9990a4`; integration cherry-picks are
`bc655bf`, `0be8e6b`, `6c181d9`.

Terrain and Gravewood review/calibration and final evidence are pending.
