# WP40 acceleration and delivery plan

Status: **discussion draft, revised after the 2026-08-21 Section 11 acceptance
closeout and independently reviewed by Fable and Sol. Fable's findings are
incorporated; the subsequent Sol closure review found no technical blocker.
Not an implementation contract and not authoritative game design.**

This document consolidates the current review and planning discussion into one
place. Its purpose is to make WP40 faster to finish without weakening the
correctness properties that protect a fresh world from seams, overlaps,
order-dependent generation, or silent fallback behavior.

Until this draft is reviewed and accepted, the existing authorities remain
unchanged:

- [world_zones.md](../design/world_zones.md) owns decided player-visible world
  design;
- [wp40-engineering-brief.md](wp40-engineering-brief.md) owns the technical
  contract and T0--T9 decomposition;
- [wp40-t2-plan.md](wp40-t2-plan.md) owns current T2 state and ordering;
- [wp40-t2-contracts.md](wp40-t2-contracts.md) owns the detailed T2 package
  contracts; and
- [luanti-lua.md](luanti-lua.md) owns the Lua 5.1/LuaJIT compatibility and
  test rules.

Approval of this draft would therefore be followed by the coordinated authority
fold-in described in Section 15. It must not silently override those
authorities.

## 1. Agreed operating direction

WP40 is technically well structured but too large to manage as one delivery
unit. Keep it as one roadmap epic because its final interfaces and rollout are
coherent, but run T0--T9 as real child work packages with their own narrow
scope, owner, branch or worktree, definition of done, review, and evidence.

The main priority from now on is **fast, bounded feedback**:

1. use LuaJIT for nearly all executable development and high-volume checks;
2. keep ordinary samples targeted and at no more than a few hundred;
3. use plain PUC Lua 5.1 only for static compatibility gates, small
   representative differential KATs, and explicitly approved final evidence;
4. parallelize independent implementation and review lanes, but do not run
   competing CPU-heavy benchmarks on the designated host; and
5. simplify a player-invisible geometric detail when that removes a large
   amount of implementation complexity, provided the correctness floor below
   remains intact.

T2 remains the largest *individual* task and the largest algorithmic risk.
T3--T9 together are still more work than the remainder of T2. Most of that
later work should be more predictable, but T5 engine integration and T8 legacy
migration can still expose expensive surprises.

## 2. State after the Section 11 closeout

Commit `931e857` landed the fifth Section 11 bay-transition attempt as one
atomic change. The commit contains the closing, residue adoption,
window-guarded appendix acceptance, seam inheritance, `W = 12`, and the
production Whole gate. Commit `e6eff4b` then independently audited and closed
its acceptance ledger without changing production code. The final raw evidence
remains in the ignored
`tools/wp40/results/bay-transition-package-final-artifacts/` directory; six
canonical pin fixtures and their two-layer checker are now committed under
`tools/wp40/fixtures/t2_census/` and `tools/wp40/`.

The evidence supports the semantic result:

- 1,166 witnesses were evaluated with zero rejected rows;
- all Whole gap/overlap/ring/multiplicity counters are zero;
- the three measured face families are green;
- all 28 chunks exited successfully;
- winner invariance remained byte-identical for all four winners;
- the LuaJIT and PUC acceptance outputs are byte-identical; and
- no repeated station lies beyond the newly pinned `W = 12` in the measured
  478-seed probe population.

This is strong evidence that the Section 11 algorithmic correction landed.
There is no new failure class and no reason to start a sixth topology redesign.

The closeout records two measurement corrections inside already ruled
mechanics:

- the adoption ledger moves from 117 seeds / 118 chains to 118 / 119. The
  additional chain is on re-accepted `d = 12` seed
  `18171940200422843206`, is cardinal, touches exactly one face, has zero ring
  stations, and follows the existing Section 11.7-B shore-attached adoption;
  and
- the complete deduplicated family-B join evidence contains 105 stations, not
  the previously captured 93. All twelve additions have `d <= 4`; the complete
  histogram still has maximum `d = 12`, so `W = 12` is confirmed rather than
  moved.

The committed checker now reports `ACCEPTANCE GREEN` and exit 0 under LuaJIT
and PUC 5.1 with byte-identical output. The added adoption was reproduced in a
targeted 41-second LuaJIT check; the focused scan-classifier and census-gate
suites, negative checker mutations, syntax, global, and all five sweep gates
were green. No new 1,166-witness sweep, full-`W` census, PUC full path, or
production change was needed.

### 2.1 Closed decisions and remaining provenance note

The two observations are accepted as recorded measurement corrections, not
new semantics. Boundary topology is now **semantically frozen**; a future
semantic change requires a new measured memo. Section 11.7-C, the optional
authored-margin cleanup, stays deferred unless a visible defect justifies it.
The full-`W` re-census remains at T2-final and re-verifies the pins over the
whole universe.

The provenance comments beside `W` in `geometry/partition.lua` and
`tools/wp40/t2_census_authority.lua` deliberately retain the superseded
93-station histogram because neither closed file was changed for documentation
alone. Section 11.11 of the T2 contracts is the corrected authority. Update
those comments when either file next opens for a substantive reason; the stale
histogram text is known documentation debt, not an open semantic question.

## 3. Correctness floor and simplification policy

Fast progress does not mean accepting corrupt or unstable worlds. These
properties are non-negotiable:

- every authored column and volume has exactly one deterministic owner;
- no gaps, overlaps, invalid polygons, chunk-order dependence, or seed-width
  truncation are accepted silently;
- stable identifiers, public API meanings, and canonical encodings do not
  drift accidentally;
- production fails closed on invalid manifests or unsupported settings;
- one authority owns each selector, terrain operation, and VoxelManip
  transaction; and
- native deep content outside WP40's owned volumes remains intact.

The following are candidates for simplification when they have little
player-visible value relative to their implementation cost:

- exact small-scale bay, shoulder, collar, and coast irregularities;
- jitter in a problematic local transition;
- tiny appendices or notches that require a new topological special case;
- exact coordinates of non-critical decorative geometry; and
- ornamental route or shoreline shapes that can be broader, straighter, or
  more regular without changing access, ownership, or gameplay.

### 3.1 Complexity stop

Boundary topology is now feature-frozen. If a later package discovers a new
global topology family, the team gets one short diagnostic cycle to identify
the cause and player-visible consequence. Before adding a new algorithmic
exception, it must compare at least these options:

1. simplify or remove the source shape that creates the family;
2. disable jitter or use a fixed simple polygon in that local area;
3. widen or straighten the transition while preserving gameplay access; or
4. add a general rule only if the first three materially harm the intended
   world.

The default is the smallest solution that is quick to implement and preserves
the correctness floor. A new topology mechanism requires an explicit ruling;
it must never grow out of a test fix by accident.

The short diagnostic cycle selects a proposal; it does not waive the topology
freeze. Any simplification that changes frozen boundary semantics or their
source geometry still requires a new Section 11 memo, a fully measured firing
population, and the complete affected corpus before an implementation package
is authorized or begins.

Any player-visible simplification is first decided in `docs/design/`. Code
comments may explain implementation but do not own game-design decisions.

## 4. World ownership and native dungeons

WP40 is a layered overlay on v7, not a horizontal switch where v7 owns every
column outside one rectangle and WP40 owns every voxel inside it. v7 creates
the native substrate first. WP40 then owns and deterministically rewrites its
declared surface shells, feature volumes, routes, water, and later exact typed
resource positions. At the same `x/z`, deep natural underground can therefore
remain v7-owned.

The current vertical contract keeps broad WP40 content at or above
`broad_content_y_min = -37`. Native dungeon generation is capped at
`mgv7_dungeon_ymax = -193`; the intervening separation prevents the authored
surface overlay from intersecting native dungeons. Exact deep resource
replacement is separately typed and host-restricted.

This deliberately changes visible world distribution: the pre-WP40 baseline
allowed native dungeon attempts up to `mgv7_dungeon_ymax = 31000`, while WP40
sets the maximum to `-193`. The result is fewer native dungeons and no
near-surface native dungeon attempts. “Preservation” here means that the deep
dungeons still generated below the boundary remain untouched; it does not mean
preserving every baseline dungeon opportunity or detecting dungeons after the
fact.

This matches the clarified design intent: WP40 owns everything in the volumes
for which it is responsible, while native terrain and dungeons may remain
below those volumes. Native-dungeon preservation is therefore not an open
design error under the current vertical ownership model. Reopen it only if
WP40's authored underground responsibility is deliberately extended below the
present boundary.

The technical decision is accepted in the engineering brief, but
`docs/design/world_zones.md` does not yet state the visible `31000 -> -193`
reduction. The authority fold-in must add that fact to its Section 13; until
then this draft records the missing documentation but does not replace the
design authority.

## 5. Fast validation strategy

The default feedback loop should complete in seconds or a few minutes. Sample
counts are ceilings, not targets; wall time is the binding budget. Select cases
by changed behavior and boundary conditions instead of filling a quota with
random seeds. Measure or conservatively project the cost of one sample before
choosing the set: an expensive full compile may fit only a handful of seeds,
while a branch-specific probe can fit hundreds in the same budget.

| layer | default scope | target wall time | interpreter |
| --- | --- | ---: | --- |
| static compatibility | `luac51 -p`, changed-mod `SETGLOBAL`, all five sweeps including `tools/` | seconds | PUC parser/static tools |
| focused smoke | 5--30 cheap KATs covering the changed branches | under 1 minute where practical | LuaJIT |
| targeted sweep | the selected/adversarial samples that fit the time budget, never more than 200 | 1--5 minutes | LuaJIT |
| subsystem checkpoint | a cost-projected property/digest set, never more than 300 samples | normally under 10 minutes | LuaJIT |
| interpreter differential | 5--20 representative KATs, canonical bytes or digests compared | as short as practical | LuaJIT and PUC 5.1 |
| real-engine micro test | 4--12 chunks or four synthetic cells | a few minutes | normal Luanti runtime |
| exceptional exhaustive evidence | only a named global invariant or final gate | separately estimated and approved | LuaJIT by default |

Properties and adversarial fixtures are more valuable than merely shrinking a
random corpus. Each targeted set should include the changed branch, both sides
of its boundary, one negative guard, a seed-width extreme where relevant, and
one chunk-order permutation. Parallel execution may reduce wall time but does
not excuse an excessive CPU budget or contention with another measurement.

### 5.1 Rules for expensive runs

An expensive run is allowed only when at least one of these is true:

- a global topology or ownership invariant changed and cannot be discharged
  locally;
- a final release contract explicitly requires exhaustive evidence;
- a statistical requirement genuinely needs a larger population; or
- a small sweep found evidence that cannot be classified safely without a
  wider measurement.

Before launch, record the question, sample universe, interpreter, time and CPU
projection, abort threshold, resumability, output directory, and the decision
that each possible result will drive. Long runs use private, uniquely named
scratch/results directories and fail early on malformed output. They are not
run concurrently with another CPU-heavy benchmark on the designated host.

The previous 4,123-seed topology censuses and the 1,166-witness Section 11
sweep were justified exceptions for global topology. They are not the model
for local fields, catalogs, selectors, or ordinary integration work.

### 5.2 PUC direction accepted conditionally; current contract unchanged

Plain Lua 5.1 syntax compatibility remains a hard product requirement.
Therefore the static gates run on every Lua change and representative PUC
execution remains mandatory at milestones. High-volume iteration belongs to
LuaJIT.

The current binding rule reserves comprehensive PUC suites for T2-final and
T9-final. One T2 contract sentence can also be read as attaching the full-`W`
re-census to that PUC round. A 4,123-seed census that already costs about ten
hours under LuaJIT would be impractical under the measured PUC/LuaJIT ratios;
the ambiguity must be removed before T2-final.

**Directional decision, after Fable review:** accept a bounded semantic
micro-corpus as the final standalone-PUC execution gate, while complete seed
populations run under LuaJIT. This is not yet the final contract ruling. The
inventory and replacement matrix below must first prove that the bounded gate
retains the current risk coverage.

The replacement gate must be specified before that proposal can be accepted.
It needs:

- an inventory of every current T2-final and T9-final PUC suite and the risk
  each one covers;
- a canonical checksum-covered micro-corpus/branch matrix covering arithmetic,
  formatting, control flow, boundary conditions, and seed-width extremes;
- at least one full-path PUC witness for each main pipeline: compiler, worker,
  merge, and selector;
- an explicit `pairs()`-order divergence gate for the remaining
  interpreter-dependent control-flow risk;
- byte-identical canonical artifacts or digests against the corresponding
  complete LuaJIT evidence;
- the unchanged separate real fallback-engine runtime gate;
- unchanged dual-runtime engine benchmarks; and
- one atomic authority update covering every inventory hit, at minimum
  `AGENTS.md`, `docs/process/wp-workflow.md`, `luanti-lua.md`,
  `tools/wp40/README.md`, the engineering brief, the affected WP40 contracts,
  and the full-`W`/PUC wording in T2 contracts Section 11.4 acceptance point 5.

The intended wording separates the gates: the re-census is a LuaJIT population
run with PUC parity at merge plus the pinned PUC micro-corpus/full-path
witnesses. “Representative” can never be selected ad hoc; fixture checksums,
the deterministic selection rule, and a contracts memo own any later change.

Until the inventory is reviewed, the final user ruling is recorded, and the
authorities change atomically, the existing comprehensive T2-final/T9-final PUC
rule continues to apply. If the replacement fails review, retain that rule and
attach explicit wall-time and CPU budgets instead.

## 6. Delivery structure and parallel work

Treat WP40 as one epic with T0--T9 child delivery packages. Do not renumber the
roadmap into ten unrelated WPs now; that would create documentation churn and
hide the integration dependency. Each child package should still look like a
normal WP:

- a short brief with owned files and interfaces;
- one branch/worktree and one Opus implementer;
- a bounded test budget and explicit artifact directory;
- a definition of done;
- a non-implementing Opus orchestrator by default;
- a narrowly scoped and recorded Fable pass only when cross-package
  architecture, exceptional risk, or a genuinely contested ruling warrants
  it;
- a full independent review by a different Opus agent; and
- merge into the WP40 integration branch only after the gate is green.

### 6.1 Worktree rules

Parallel work is useful only after interface and file ownership are explicit.
Use separate worktrees for independent lanes and integrate small commits in
dependency order. Never parallel-edit the same authority-heavy file.

Two kinds of sensitive surface must not be confused:

- **frozen/locked:** the stage-S1 authority files
  `tools/wp40/t2_s1_authority.lua`,
  `mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua`,
  `mods/MAPGEN/grug_mapgen/wp40/canonical.lua`,
  `mods/MAPGEN/grug_mapgen/wp40/deterministic.lua`,
  `mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua`, and
  `mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua` have no ordinary lane
  owner; changing one invalidates the pinned pool and is an escalation.
  Boundary semantics in
  `mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua` and its topology
  oracle/fixtures are likewise frozen by Section 11.11; a semantic change
  requires the new memo and measurement discipline in Section 3.1.
- **serialized shared ownership:**
  `mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua`, shared corpus selectors,
  immutable artifact manifests, and the sole production VoxelManip transaction
  each have exactly one active owner. `source/catalog.lua` may grow because S1
  pins its projection rather than its bytes, but parallel lanes still do not
  edit it concurrently. Other lanes consume a frozen interface or send changes
  back to the active owner.

The production rosters in
`mods/MAPGEN/grug_mapgen/wp40/compiler.lua` and
`mods/MAPGEN/grug_mapgen/wp40/compiled_schema.lua` already name all 20 geometry
buckets and use a generic relational record schema. Remaining bucket packages
therefore treat both files as **consume-only**. A genuine schema change is a
separate serialized package, never a helpful side edit by a bucket lane.

Each lane gets unique result directories and, for engine work, a unique
disposable world. Parallelize implementation, focused tests, documentation,
and independent review. Serialize full benchmarks and any test that saturates
the designated host.

### 6.2 Test-harness ownership

The C1 conformance authority byte-pins four shared files:

- `mods/MAPGEN/grug_mapgen/wp40/compiled_schema.lua`;
- `mods/MAPGEN/grug_mapgen/wp40/schemas.lua`;
- `tools/wp40/t2_partition_test.lua`; and
- `tools/wp40/t2_partition_oracle.lua`.

Lane B lands its v3 conformance fixture before any C/D package may change one
of them. Later Light-Regime packages do not extend the 5,890-line
`t2_partition_test.lua` by default. Each package owns a small test file, runner,
and fixture directory; a thin umbrella runner composes the green package gates
for T2-final. This is the default route to genuinely disjoint worktrees. An
exception requires the ownership table to name the shared-file owner and to
serialize the edit after Lane B.

### 6.3 Integration discipline

Freeze an interface before two lanes consume it. The provider merges first;
consumers then rebase or merge that exact commit. Cross-lane edits are sent
back to the owning lane instead of being patched opportunistically. Integration
tests run after each merge, so T9 collects evidence rather than discovering
months of accumulated incompatibility.

## 7. Immediate execution plan after Section 11

### Gate A — Section 11 closeout (**completed**)

Commit `e6eff4b` closed the acceptance ledger, committed the complete family-B
measurement and corrected adoption pin, added a non-vacuous checker, and
declared the topology semantics frozen. It changed no production behavior and
used only focused verification. This gate has no remaining work.

Lane B is the first code-bearing C/D task. The doc-only PUC inventory and the
tools-only T5-0 specification have disjoint scopes and may proceed beside it;
no C/D implementation lane may make the C1 authority digest a moving target.

### Lane B — finish the T2 topology handoff

Migrate C1 selected-four conformance to the v3 artifacts, confirm the four
winners, freeze the perimeter/face outputs, and publish the exact interface
that downstream geometry consumes. It owns the v3 gate fixture and lands before
C/D packages may extend any C1-pinned test surface. Escalate only on a real
semantic mismatch.

Expected size: **small to medium** if no new finding appears.

### Lane C-a — implement the independent T2 local fields

Build `H`, the template catalog, and the blend operator. The current T2 plan
explicitly establishes these as depending on T1 arithmetic rather than the
boundary correction. They use the light verification regime: purity argument,
properties, focused KATs, and a determinism digest. Do not copy the topology
census machinery, extend the C1-pinned partition harness, or modify the locked
T1 arithmetic files. Use the per-lane test-harness rule in Section 6.2.

Expected size: **medium to large**, divisible by module after shared return
types are frozen.

### Lane C-b — route profiles and hydrology after their input freeze

Route profiles require `H` from Lane C-a plus complete X/Z centrelines, route
classes, cross sections, and the compiled land/boat route records from Lane-D
package 1. Hydrology additionally requires its reach masks, profiles, and
transitions. Before either package starts, publish a short input matrix naming
every provider, return type, and freeze commit. Only then implement them under
the same light purity/property/digest regime.

Expected size: **medium to large**, but not safely parallel until that matrix
shows non-overlapping ownership.

### Lane D cluster — compile the remaining derived geometry

After Lane B publishes the exact consuming interface, build coast/shelf,
islands, channels, zones, routes, anchors, protection/exclusion masks, housing
masks, logical-biome IDs, nearest-feature layers, and the housing-centre
selector. This is a cluster, not one executable worktree. Cut at least these
packages before implementation:

1. source-record compilation for zones and the land/boat route records
   (**D-1**, a required provider of Lane C-b);
2. perimeter-derived physical geometry for coast/shelf, islands, and channels;
3. anchors, hard-protection, claim-exclusion, and housing masks; and
4. logical-biome, nearest-feature, and housing-centre selectors with their slow
   oracles.

Every package brief names providers, owned files, return types, shared-schema
owner, fixture owner, and definition of done. Packages may overlap in time only
when that table proves their write sets and interfaces independent.

Expected size: **large to extra-large**. This is the main remaining T2 volume,
but it should not carry the R-series topology verification regime.

### Lane E — wire the production compiler

Create the missing production compiler implementation only after the compiled
geometry shape is stable. It assembles and validates the one payload and uses
the existing IPC/canonical infrastructure; it must not invent a second
geometry evaluator.

Expected size: **medium**, with high integration leverage.

### T2-final — freeze evidence, not new behavior

Run the final schema/corpus/micro-corpus/requester-trace gates, the full-`W`
re-census, the agreed PUC conformance gate, and independent review. T2-final
must not be the first time ordinary fields or selectors receive performance
measurement. If it finds a local defect, return to the owning small package;
do not patch the finalizer.

The finalizer also freezes the deferred operation-coverage namespaces, final
entries 1--31 plus the explicit staging entry, geometry-only micro-corpus
classes 1--9, corpus slots 28--31, the staging-only slot-32 run, and the
complete 100-requester JSON trace required by the engineering contract.

Expected size: **medium execution cost** and potentially high machine time.
Its scope is controlled by the PUC decision in Section 5.2.

## 8. Early T5-0 engine probe — run with conditions

Do not move full T5 ahead of T3 and T4: the production adapter needs the public
geography API and the typed content planner. The reviewed direction is to run a
small **T5-0 engine-seam probe** without displacing Lane B. Its specification
may proceed beside Lane B; the probe is a separate small package and may run
beside Lane C-a after its own contract is accepted.

T5-0 is a tools-only, disposable engine-seam probe. It uses v7 as the substrate
and a synthetic test payload; it changes no production file or runtime
registration, freezes no payload schema or operation type, and does not wait
for all final geometry.

The primary substrate is the current production-like Grudgelands baseline:
v7 with the game's six `override_meta` noise overrides and existing Ocean Mask,
not stock v7. The harness captures the same chunks once without and once with
the injected probe and attributes only the deterministic delta to T5-0. It may
not silently disable an existing writer; any unavoidable overlap is either
excluded by the test coordinates or named in the expected baseline. A stock-v7
variant is optional and makes no production claim.

A single flat plane one block above sea level is a useful first visual, but
four micro-cases give much better evidence for little additional cost:

1. no-op owner slice: no upload or lighting/liquid work;
2. one bounded cut/fill surface cell;
3. one water cell exercising liquid and lighting completion; and
4. one feature crossing a chunk boundary, generated in two orders.

The probe should establish that the real engine can load the mapgen environment
and exercise the IPC mechanism and an owner slice; perform at most one content
and optional `param2` upload; call liquid/lighting work only when dirty;
generate the same bytes in different chunk orders; and report callback time
and peak working memory. It should prepare a disposable world and a five-minute
runtime test plan for the user.

Reuse the existing archive injection, disposable-world, JSON-log, emerge,
timing, and memory patterns from the dungeon/runtime probes. The package must
measure rather than assume mapgen-environment availability of timing APIs,
mapgen-to-main IPC, and any insecure-environment facility. New evidence is
limited to the missing directions and operations, including mapgen-to-main IPC,
`set_param2_data`, and reordered chunk generation with a byte comparison.

The probe does **not** prove the final payload schema, T3 API, T4 resolver,
production T5 integration, or representative production performance. Those
remain behind their binding T2/T3/T4 gates.

All probe code lives under `tools/wp40/t5_probe/`, never under `mods/`. The
durable result is a committed package-contract memo and canonical evidence, not
a second adapter. When the real T5 package is cut, the probe code is deleted or
archived under ignored results; the T5 review explicitly verifies that no probe
code appears in the production diff.

Expected size: **small, roughly one compact tools-only package plus review**.
If an engine assumption is wrong, learning that now is substantially cheaper
than learning it after T4. Its observations may inform later T5 tests, but its
code is discarded; it never becomes a parallel production path or production
adapter foundation.

## 9. Remaining T0--T9 map

The size labels are relative planning bands, not calendar promises. They assume
the simplification and test rules in this document and exclude a genuinely new
global-topology finding.

- **small:** one compact implementation/review package, usually hours to one
  focused day;
- **medium:** a few compact packages, usually several focused days;
- **large:** several modules or integration surfaces, roughly one to two weeks
  in a single lane; and
- **extra-large:** multiple dependent packages or multiple weeks in a single
  lane, with elapsed time reduced only where ownership permits parallel work.

These bands include implementation, focused verification, review, and
integration corrections, but not user runtime-test scheduling or an approved
multi-hour evidence run.

| task | plain-language result | current state | remaining size and main risk |
| --- | --- | --- | --- |
| T0 — baseline | Pins the existing world, materials handoff, host, and measurements so later comparisons mean something. | complete | done |
| T1 — deterministic foundation | Provides full-seed arithmetic, canonical serialization, validation, IPC, schemas, and the spatial index used by every later task. | complete | done |
| T2 — compiled geometry | Turns the authored 38-zone world into one immutable deterministic payload: boundaries, terrain fields, routes, water, anchors, masks, selectors, fixtures, and traces. | boundary topology frozen; C1-v3 handoff, most non-topology buckets, and production compiler unstarted | **extra-large**; still the largest single task; derived geometry volume and final integration are the remaining risk |
| T3 — public geography API | Gives gameplay code stable fast answers such as zone, level, territory, PvP state, water/mount class, nearest feature, housing eligibility, and protection. | not started; scaffolding/oracles may start while T2 finishes, but authoritative answers wait for T2 | **medium**; API semantics and hot-path performance |
| T4 — pure content planner | Decides, without touching the map, the exact final operation for each relevant voxel and resolves conflicts between terrain, water, routes, resources, and preservation rules. | not started | **large**; resolver completeness and typed ownership, but readily property-tested |
| T5 — engine adapter | Applies the T4 plan to real v7 output in one bounded VoxelManip transaction with correct light and liquids. | not started; the tools-only T5-0 probe direction is accepted, specification pending | **large**; real-engine behavior, memory, chunk order, and no-op cost |
| T6 — surface catalog | Maps logical biomes to actual top/filler nodes, decorations, trees, and surface-water settlement without adding a second selector. | not started | **medium to large**; catalog breadth and visual/runtime iteration |
| T7 — resources | Places universal and cultural resources only in valid final hosts and proves supply/access expectations. | not started | **medium to large**; density tuning and deep typed replacement |
| T8 — migration | Moves every existing consumer to the new APIs and removes old map/height/ocean/dungeon authority only after replacements are green. | not started | **large to extra-large**; broad repository coupling and regressions |
| T9 — release | Replays and freezes final evidence, performance, order independence, coverage, a disposable visual world, rollout checks, and the runtime test plan. | not started | **large**, mostly integration/evidence; must not become a late feature phase |

The statement “T2 is the largest part” is credible only for individual tasks.
T2's topology has uniquely high discovery risk and has already paid for the
heavy machinery. The combined T3--T9 effort is larger, and T8 may rival a
substantial T2 phase if legacy consumers are more coupled than expected.

## 10. Dependency and parallelization sequence

Gate A is complete. Use the following order from commit `e6eff4b`:

```text
e6eff4b: topology semantics frozen
               |
               +-> C1-v3 conformance / topology interface handoff
               |          |
               |          +-> Lane-C-a H/templates/blend
               |          +-> Lane-D-1 source-record compilation
               |          +-> Lane-D-2/D-3/D-4 as provider tables permit
               |
               +-----------> PUC final-gate inventory (doc-only)
               |
               +-----------> T3 API scaffolding + slow oracles
               |
               +-----------> T5-0 specification -> tools-only probe

Lane-C-a H freeze + Lane-D-1 route records + all other providers named by matrix
        +-> route profiles and hydrology as separately cut Lane-C-b packages

T2 final payload -------> T3 authoritative API completion
          |              |
          +------------> T4 pure planner
                           |
                    T3 + T4 complete
                           |
                        full T5
                         /   \
                       T6   T7
                         \   /
                           T8
                            |
                           T9
```

T3 signatures, adapters, and slow-oracle scaffolding may run in parallel with
T2, but no authoritative T3 answer freezes before T2. T6 and T7 production
work and their completion gates begin only after T4 and T5 are complete, as the
engineering contract requires. Catalog data, fixtures, and harness scaffolding
may be prepared earlier after their interfaces freeze, but cannot claim
production integration or completion. T8 migrates one consumer family at a
time and deletes old authority only after the replacement is green.

## 11. Performance checkpoints

Performance is measured while interfaces are still cheap to change:

- T2: payload compile time, cache-hit time, payload size, and selector/query
  microbenchmarks on a tiny fixed corpus;
- T3: scalar hot-path latency and maximum candidate counts;
- T4: no-op, ordinary surface, water/light, route, and exact deep-resource
  planner costs;
- T5-0/T5: callback wall time, peak working memory, upload count, no-op cost,
  liquid/lighting calls, and chunk-order identity;
- T6/T7: incremental operation counts and costs, not only final settled hashes;
  and
- T8: representative gameplay consumer costs after migration.

Every performance result records interpreter, host state, corpus, warm/cold
status, and raw samples. Prefer several narrow sweeps that answer a specific
question over one large mixed benchmark. T9 repeats the agreed final cases; it
does not introduce the first performance gate.

## 12. Player-visible impact and decision gate

Each child brief that changes the world rather than only its implementation
contains a short linked impact summary, not a new standalone documentation
layer. It states:

- what a player would visibly notice;
- what remains deliberately native v7 behavior;
- what, if anything, is simplified or omitted compared with decided design;
- whether fresh-world regeneration is required; and
- which existing `docs/design/` rules authorize the result.

If the package implements existing design without deviation, the links and a
“no design change” statement are sufficient; no redundant user approval is
required. A new or deviating player-visible rule uses the repository's normal
flow: open or update `TODO-<topic>.md`, obtain an explicit user decision, then
fold the result into `docs/design/` and delete the resolved TODO. Code comments
only explain implementation. This keeps consequential choices such as vertical
dungeon ownership visible without creating a fourth documentation layer or a
gate on routine implementation.

Working briefs may live under ignored `tools/wp40/results/`, so they are not a
durable home for project state. The committed package-contract section must
contain the impact summary itself or a precise link to the authoritative
`docs/design/` passage before implementation merges.

## 13. Recorded decisions after architecture review

The planning discussion and the Section 11 closeout have already settled these
directions:

- accept the 118/119 adoption population and complete 105-row family-B table
  as non-semantic measurement corrections, and freeze boundary topology;
- defer Section 11.7-C unless a visible defect appears;
- keep WP40 as the roadmap epic while delivering T0--T9 as reviewed child
  packages with worktrees where ownership permits;
- prefer a small explicit design simplification over another topology
  mechanism when the gameplay result remains equivalent;
- measure performance incrementally rather than discovering it at T9; and
- summarize player-visible impact in each child brief and use the existing
  TODO-to-`docs/design/` flow only for new or deviating decisions.

The Fable architecture review prepared two additional directional decisions:

1. **PUC final gates — ACCEPT WITH CONDITIONS.** Proceed toward the bounded
   micro-corpus/full-path model in Section 5.2. The next task is the inventory
   and branch matrix; the current PUC contract stays binding until that evidence
   receives a final user ruling and all authorities change atomically.
2. **Early engine work — RUN T5-0 WITH CONDITIONS.** Proceed with the
   production-like, tools-only, disposable probe specified in Section 8. It
   does not move full T5 ahead of T3/T4 and cannot be reused as production code.

## 14. Adopted speed-up measures

### 14.1 Per-lane Light-Regime harnesses

New C/D packages own small test files, runners, and fixtures instead of growing
the C1-pinned `t2_partition_test.lua`. A thin umbrella runner composes them at
T2-final. This is the default ownership rule in Section 6.2 and removes the
largest known shared write from the parallel lanes.

### 14.2 Immediate PUC final-gate inventory

Cut the Section 5.2 inventory as a small doc/evidence package now, in parallel
with Lane B. Its output is:

- every current final PUC suite/command and the risk it covers;
- measured or conservatively projected PUC wall and CPU cost;
- the deterministic micro-corpus/branch matrix and full-path witnesses;
- explicit treatment of the full-`W` re-census, `pairs()`-order divergence,
  fallback-engine runtime gate, and dual-runtime engine benchmarks;
- the complete authority-hit list; and
- a decision memo recommending the final accept/reject wording.

The inventory changes no authority. It is useful in both outcomes: acceptance
uses it to define the replacement; rejection uses its costs to budget the
existing comprehensive gates.

## 15. Authority fold-in

After the PUC inventory's final ruling and the accepted T5-0 specification,
fold the acceleration rules into their owners in one coordinated documentation
package. Its checked scope includes:

- `AGENTS.md`, `docs/process/wp-workflow.md`, `docs/research/luanti-lua.md`,
  `tools/wp40/README.md`, the engineering brief, T2 plan, and affected T2
  contracts for interpreter, package, and execution rules, including the
  Opus-default/Fable-exception model-priority rule;
- T2 contracts Section 11.4 acceptance point 5 for the full-`W`/PUC
  separation;
- `docs/design/world_zones.md` Section 13 for the accepted visible dungeon
  reduction from `mgv7_dungeon_ymax = 31000` to `-193`; and
- the `BACKLOG.md` WP40 detail so it reflects the Section 11 landing, topology
  freeze, and actual next step while keeping WP40 `in progress`.

This draft remains a planning record; it does not become a competing authority.

## 16. Definition of planning-ready

This draft is ready to become an implementation plan when:

- the disposition of an optional post-fix re-review is recorded and any new
  findings are resolved;
- the PUC inventory/branch matrix is reviewed and the final PUC ruling is
  recorded;
- the T5-0 substrate, tools-only payload, four cases, measurements, non-claims,
  and disposal rule are frozen in its package contract;
- each immediate lane has non-overlapping file ownership and frozen interfaces;
- sample and wall-time budgets are attached to every non-trivial planned test
  command; trivially short static gates need no individual budget;
- the PUC outcome is folded in as specified in Section 5.2, or the retained
  comprehensive gates receive explicit time and CPU budgets;
- every child package has a definition of done and independent Opus reviewer;
- no unresolved player-visible design choice is left for an implementation
  agent to invent;
- every durable player-impact summary lives in its committed package contract
  or authoritative design link; and
- the Section 15 authority fold-in is complete.

Only then should implementation that depends on this acceleration draft begin.
The already-authorized C1-v3 conformance/topology handoff may proceed under the
existing T2 plan without waiting for this draft to become authoritative. The
doc-only PUC inventory and T5-0 specification may likewise proceed as planning
packages; the T5-0 probe itself waits for its accepted package contract.
