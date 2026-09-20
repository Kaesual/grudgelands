# Round 10 world corrections

Status: implementation and bounded correctness evidence ready for independent
review. **Independent review, root integration and the global final PUC/LuaJIT
micro pair remain pending.** This record does not mark WP40 complete.

## Authority and scope

The accepted Round 10 execution decisions govern this package; the decided
rules live in `docs/design/world_zones.md` (native surface skin/openings,
near-water materials and Rock Salt) and `docs/design/biomes_mobs.md` (gathering).
The server/world is fresh; no migration or compatibility path was added.
CAP, MAP-B, farming expansion and housing construction are separate work.

| Requirement | Implementation | Evidence |
| --- | --- | --- |
| Cave processing outside actual functional footprints | `simple_map.lua` cave-purpose query uses source profile building cores; separate build/apron, route and water claims still overlap. `r6_settlement.lua` admits generic land grades and natural landmark envelopes while retaining actual operations, foundations and housing masks. | 300 actual core/apron samples and 438 route points; real R5 `plan_slice`; real writer foundation countercase; requested engine seed/point. |
| Preserve valid native openings and repair thin skin | Opening proof accepts original air retained by R5 terrain-fill 27 or anchor-grade-fill 21; no new R5 cave-carving/preservation rule. Existing four-air, cardinal/3x3 and owner-slice algorithm remains. | Writer composes `land_grade`, natural-landmark membership and opcode 21; authored foundation stays intact. Actual neighborhood: 16 openings, 26 repaired skin nodes. |
| Mountain shores and high freshwater rims use rock | Material fallback reads the existing shore classification independently of geometry exclusion; P7 selects stone/gravel top, filler and shore. Eligible columns do not repeat the shore scan through the fallback. | Real planner/selector island tests; 25 Wyrmglass, 27 Stormscale and 25 high-freshwater dry engine columns use rock. |
| Rock Salt retains three named endpoints | Catalog v2 canonically binds zone-scoped host alternatives. Gravesalt keeps sand; Stormscale/Wyrmglass accept stone/gravel. The analytic support chosen by P9G must equal actual settled/lower-owner support. | 18 endpoint/support/owner-boundary cases, wrong-zone/shore/actual-support negatives, actual endpoint surface output. This is not a regional resource census or a guarantee of a source in every sampled owner. |

Global claims, hard protection, source positions, noise, terrain/coast geometry,
demand-driven resource roots and the PERF caches/liquid/lighting behavior remain
unchanged. The frozen source audit roster remains **157**; gathering populations
remain **12/8/6**. Salt Crust remains a distinct source.

## Engine and interpreter evidence

Evidence: `tools/r10_world/evidence/20260920/`. The independent checker is
`tools/r10_world/check_engine.py`; run it with `native.tsv`,
`guarded-superseded.tsv`, `candidate-generated.tsv` and
`--reload candidate-reloaded.tsv` from that directory.

All engine calls used `tools/luanti_headless.sh`, fresh scratch storage, seed
`4151598227737528026`, `LC_ALL=C`, nice priority 19, `chrt --idle 0`, `ionice -c3`, assigned
ports and bounded cleanup. No personal world was accessed. The candidate runs
exercise actual `r7_manifest.new`, `planner.plan_slice` and the VM writer.
Pinned engine documentation for the observer is
`reference_projects/luanti/doc/lua_api.md:7163` (emerge completion callbacks) and
`:6580` (post-generation map availability). The native baseline uses the existing
writer-disabled hook in `r7_mapgen.lua`, not a replacement terrain generator.

- Port 32730: expected stale projection failure; after review, only the gathering
  limb changed. Catalog SHA is
  `85382465797196dbeb20e407ef482c367f9e6c547127722cf2b0f634d6c98929`;
  source projection is
  `674ddc3f6a9b9bfd1a1e50c88db6908f5022960200e88128665292047ade9c51`.
- Port 32731: superseded failure, new material methods missing from the closed
  planner-source contract. Required fields and synthetic source fixtures fixed.
- Port 32733: superseded four-region run. The broad natural-landmark veto still
  retained the reported grass roof. Its unchanged R5 output is retained solely
  as a direct witness of original air preserved before the cave-purpose pass.
- Port 32732: native-v7 baseline, five regions, complete.
- Port 32734: corrected fresh-world run, five regions, complete. All nine changed
  production modules were byte-checked against the staged engine copy.
- Port 32735: same-version reload of that isolated candidate world, complete;
  224 six-node columns retain byte-identical node names/param2. Early recorder
  output omitted the trailing node/biome fields of 21 unowned channel columns;
  the fixed recorder reports all 245 on reload. Native comparison for those 21
  columns is explicitly metadata-only. Every dry/cave sample was complete.

The exact reported column `(-71,21,-2458)` changes from a grass roof above four
retained native-air cells to air at T−4 through T+1. Across245 witness positions,
terrain height/water ownership/available logical biome remain identical.
Nearby closed cases receive the three-node skin. The checked high freshwater
rim is `(-2008,101,-80)`; Gravesalt's sea-channel beach at `(-2500,1,164)` remains
sand. Island centers `(-3160,1,-310)` and `(3235,1,-310)` are stone and gravel.

Focused LuaJIT checks passed: both new portable fixtures, real R5 source/planner
integration, R8 rule/writer KAT, R7 micro (157/157 modules), gathering registration/
harvest, catalog contract, native inputs, planner cache, resource writer,
tree slices and PERF writer equivalence. Changed Lua passes plain Lua 5.1 parsing,
SETGLOBAL inspection and all five sweeps; the only sweep hit is existing comment
prose. Fresh-server audit and `git diff --check` pass. No PUC runtime was run.
The global final runner now binds and calls both new portable fixtures; root
will run the sole final pair after serial CAP/MAP-B integration freezes bytes.

## Superseded findings and limits

The first sandboxed Flatpak attempt could not allocate an instance; the approved
isolated escalation resolved it. Failed and superseded engine logs are retained;
none is represented as passing final acceptance.

An optional old R6 micro fixture fails `surface skin host rock is absent` because
its private synthetic content catalog lacks `default:stone`. The same failure
was reproduced with **both** settlement and fixture source taken from baseline
`38ae136d`; hashes/log are retained. It does not load the new rocky-shore selector,
and it is not part of the current global final micro. Its incidental stub edits
were reverted. Current R7 and actual writer fixtures pass.

Known uncorrected design discrepancy for CLOSE/CAP: V1e prose says both bandit
profiles have a 24-node building core, while source `bandit_frontier` uses 16
(`bandit_home` uses 24). This package protects the evidenced current functional
footprint without widening terrain geometry. Do not rewrite the decided design
to 16 merely to match that older implementation. Unbuilt POI expansion is outside
this package.

Implementation model: native GPT-6 Astra. Independent reviewer and review outcome:
pending root assignment. No external AI, push, merge or sync was performed.

## Next GUI check after root integration

Create a fresh world with the reported seed. Inspect the opening near
`(-71,21,-2458)`, nearby intact thin-roof skin and settlement foundations. Inspect
both mountain island shores, the high freshwater rim and Gravesalt's sandy salt
shore; test Rock Salt gathering without confusing Salt Crust. Existing worlds
are only the controlled current-version persistence test above.
