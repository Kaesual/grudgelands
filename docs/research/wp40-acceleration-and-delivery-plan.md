# WP40 acceleration and delivery plan

Status: **planning record, revised after the accepted 2026-08-23 PUC-1 and
D1-1 rulings and final GO. The execution graph mirrors the authoritative
[T2 plan](wp40-t2-plan.md) Section 0 and the durable
[handoff memo](wp40-t2-contracts.md) Section 14. Fable and Sol independently
reviewed the preceding planning revision on 2026-08-22; Fable's findings were
incorporated and Sol's closure review found no technical blocker. That is
historical provenance, not a model-routing rule. Not an implementation
contract and not authoritative game design.**

This document consolidates the current review and planning discussion into one
place. Its purpose is to make WP40 faster to finish without weakening the
correctness properties that protect a fresh world from seams, overlaps,
order-dependent generation, or silent fallback behavior.

The existing authorities remain layered as follows:

- [world_zones.md](../design/world_zones.md) owns decided player-visible world
  design;
- [wp40-engineering-brief.md](wp40-engineering-brief.md) owns the technical
  contract and T0--T9 decomposition;
- [wp40-t2-plan.md](wp40-t2-plan.md) owns current T2 state and ordering;
- [wp40-t2-contracts.md](wp40-t2-contracts.md) owns the detailed T2 package
  contracts; and
- [luanti-lua.md](luanti-lua.md) owns the Lua 5.1/LuaJIT compatibility and
  test rules; while
- [agent-model-policy.md](../process/agent-model-policy.md) independently owns
  project-wide model routing and supersedes historical WP40 model assignments
  for every newly started context.

The accepted PUC-1 wording is still folded only by the atomic Phase-0B package
described in Section 15. This planning record does not silently or partially
override those authorities.

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

### 2.2 C1-v3 acceptance handoff closed

The separately authorized vendored-PUC run completed green from commit
`5d770365`: 20/20 rescore rows, four of four selected slots, and final artifact
SHA-256 `7ac6b7f9…`. All four selected slots report `g = o = r = m = 0` and
the structural pins in T2 contracts section 12.4. The four payload digests in
that section are the historical 2026-08-22 identity; Section 14.10 supersedes
only those values after the authorized ownership/schema handoff while retaining
the topology interface. A separate same-HEAD invocation re-verified all 24
retained rows and exited by the resume path without recomputation.

Measured wall time was 215 seconds for the rescore phase and 5,507 seconds for
the four parallel selected workers, approximately 99 minutes end to end after
preflight, repeated verification, and finalization. This is final evidence for
C1, not a new development-loop norm. Recorded-evidence reuse prevents
closure-neutral future commits from buying the same run again. Seed-corpus
promotion, T2-final, and all remaining light-regime geometry stay open.

### 2.3 Integrated Wave-1 C1-v3 reacceptance closed

After C-a1, D-1, the ownership provider and the landmark Source cleanup were
integrated, the coordinator observed the bounded LuaJIT selected-four
preflight and the retained ownership-handoff evidence covered both non-vacuous
witnesses. The single scheduled PUC reacceptance then retained 20/20 rescores
and all four selected slots. All selected slots retained zero Whole gap,
overlap, ring and multiplicity counters. Raw runner stdout and elapsed counters
were not retained and are not used as a calibrated cost anchor. The final
artifact SHA-256 is `fe52c0bc...639d32` and the 25 result files are bound by
commit `89e4ba1`.

Both the same-HEAD resume and the descendant-HEAD 66-path recorded-evidence
reuse paths are green, so subsequent closure-neutral commits do not buy this
run again. This closes the integration gate for C-a2 only. Seed-corpus
promotion, F1, full-`W`, T2-final and C-b remain open.

### 2.4 WARCOAST C1-v3 reacceptance retained

The reviewed WARCOAST Source correction changed two members of the 66-path
closure, so recorded reuse refused the older evidence as designed. The single
authorized fresh PUC run retained 20/20 rescores and 4/4 selected slots from
commit `86e5071`; all four compiled-payload digests and zero Whole counters
remain unchanged. Final artifact SHA-256 is `1edbb12a...93aedc8`, bound with
the other 24 rows by commit `17efc8d`. Same-HEAD resume and descendant recorded
reuse are green. Independent Opus/xhigh acceptance review is pending; C-a2
remains the next executable package.

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
then this planning record notes the missing documentation but does not replace
the design authority.

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

### 5.2 PUC-1 accepted; Phase 0B owns the atomic closeout

The user accepted PUC-1 on 2026-08-23 after review of the pinned final-gate
inventory. That ruling is final. Its mechanical witnesses, evidence and
project-wide wording are not folded piecemeal by Phase 0A or by an
implementation lane: Phase 0B first merges the reviewed inventory commit,
closes every ruling-owned mechanical obligation, re-derives the complete
authority-hit list, and applies the policy/evidence change atomically.
The ownership handoff intentionally changed partition/schema and therefore the
compiler/worker PCC digests. Phase 0B produced its final fixtures and retained
evidence on integrated provider commit `62afc64`: compiler, worker and
seven-seed merge carriers are green; the complete project-wide wording is in
the same review package. F1, F2, full-`W` and C1 reacceptance were not run.

The package passed independent Opus/xhigh review and was integrated by merge
`95e3261`. D-1 can now cite the final interpreter and evidence authority. No
C1 run was bought for Phase 0B alone; the one later integrated Wave-1 C1-v3
reacceptance covers the planned ownership/schema event.

## 6. Delivery structure and parallel work

Treat WP40 as one epic with T0--T9 child delivery packages. Do not renumber the
roadmap into ten unrelated WPs now; that would create documentation churn and
hide the integration dependency. Each child package should still look like a
normal WP:

- a short brief with owned files and interfaces;
- one branch/worktree and an implementer selected under the project-wide
  [agent model policy](../process/agent-model-policy.md);
- a bounded test budget and explicit artifact directory;
- a definition of done;
- coordination, escalation, and role separation under that same policy, with
  no WP40-local model priority;
- a full independent strong-agent review under that policy; and
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
The T5-0 half has since done so and is finished as a tools-only observation
(Section 8); it no longer occupies this lane.

### Lane B — finish the T2 topology handoff (**completed**)

The C1 selected-four conformance is migrated to the v3 artifacts, all four
winners are confirmed under vendored PUC 5.1, and T2 contracts section 12.4
publishes the frozen perimeter/face interface. Its retained evidence and
same-HEAD resume proof are closed in section 2.2 above. Later work consumes the
topology interface and may not change its family roster or structural pins as
a side effect. Section 14.10 is the explicit later-memo rebind of the four
payload digests after the authorized ownership/schema handoff; it is not a
topology change.

Result: **completed without a new semantic finding**.

### Phase 0A — durable handoff freeze (**first current gate**)

Record the accepted C-a semantics, D1-1 scope and ordered dependency graph in
their durable owners, then obtain the required independent review. Phase 0A is
documentation-only and precedes every new implementation package.

### Phase 0B — PUC policy closeout

After integrated Phase 0A, merge the pinned inventory and close PUC-1's
mechanical/evidence obligations as one reviewed atomic authority fold. Code and
policy preparation may overlap payload-free C-a1 and Wave 1C's ownership
handoff, but the handoff integrates first and Phase 0B's final fixtures,
evidence, green status and integration bind to that provider. D-1 waits until
Phase 0B is integrated.

### Lane C-a — split C-a1 from ownership-dependent C-a2

The former claim around this section's pre-freeze lines 426--433 that all of
Lane C-a is independent of partition and D-1 is explicitly superseded.
Payload-free C-a1 implements the relief/profile primitives, ordered landmark
composition, the six payload-free template primitives and the shared blend
operator. It may overlap Phase 0B and the ownership handoff after Phase 0A is
integrated, with Phase 0B limited to preparation until the ownership provider
lands. It does not evaluate route-dependent `causeway` or
`cross_section`, or ownership-dependent `housing_smoothing`.

For C-a1, contracts Section 14.1 explicitly supersedes the three consume-only
source-policy literals that still describe a highest-priority one-winner
interpretation. C-a1 neither edits the catalog/validator nor treats those
literals as semantic authority. A dedicated later landmark source-policy
cleanup must close before the production compiler or T2-final. Aim to batch it
before the single scheduled C1 only if it requires no source edit and its audit
proves no S1/pool movement; any violation is STOP for a new reviewed ruling.
The source-edit condition is independent because `geometry_policies` is absent
from the S1 projection, so an unchanged S1/pool does not prove source stayed
untouched.

C-a2 is a separate serial package. It assembles zone-owned `H` only after
D-1 supplies the 38 zone records, Wave 1C exports Bay-owned connectivity fill
and dry-face/zone-owned adopted residue, and the integrated C1-v3
reacceptance is green. Its first fail-closed gate retains the seed-independent
proof that every exact landmark mask plus the maximum legal incident-edge
displacement envelope lies inside its final owner. The package-local
`surface_owner_at(x, z)` projection over the accepted compiled-world-v2 records
combines dry-face polygon and adopted-residue ownership, every compiled Planned-
Water class, closure-wing ownership, mouth-aperture/perimeter ownership and the
canonical half-open seam tie. “Not polygons alone” forbids dropping those other
inputs; polygon membership remains the ordinary-dry input. Missing input or
reconstructed ownership is a STOP before `H` assembly.

Both packages use the light verification regime: purity argument, properties,
focused KATs and a determinism digest. They do not copy the topology census
machinery, extend the C1-pinned partition harness or modify the locked T1
arithmetic files. Use the per-lane test-harness rule in Section 6.2.

Expected combined size: **medium to large**, delivered in the two dependency-
separated packages above.

### Lane C-b — route profiles and hydrology after their input freeze

Route profiles require the assembled `H` from C-a2 plus complete X/Z
centrelines, route classes, cross sections, and the compiled land/boat route
records from Lane-D package 1. Hydrology additionally requires its reach masks,
profiles, and transitions. Before either package starts, publish a short input
matrix naming every provider, return type, and freeze commit. Only then
implement them under the same light purity/property/digest regime.

Expected size: **medium to large**, but not safely parallel until that matrix
shows non-overlapping ownership.

### Lane D cluster — compile the remaining derived geometry

After Lane B publishes the exact consuming interface, build coast/shelf,
islands, channels, zones, routes, anchors, protection/exclusion masks, housing
masks, logical-biome IDs, nearest-feature layers, and the housing-centre
selector. This is a cluster, not one executable worktree. Cut at least these
packages before implementation:

1. source-record compilation for exactly 38 zones, 57 land routes (30 primary,
   24 secondary and three trails), and four public boat routes (**D-1**, a
   required provider of C-a2 and Lane C-b); D-1 starts only after integrated
   Phase 0B, keeps `land_058`--`land_061` boundary-only, and leaves the 10
   island route stations, eight island routes, 16 interfaces and four landings
   source-only until the Lane-C-b input-matrix ruling; D-1 validates its
   complete result through public `compiled_schema.canonicalize_compiled`,
   keeps analytic-record helpers local, and adds no validator export;
2. perimeter-derived physical geometry for coast/shelf, islands, and channels;
3. anchors, hard-protection, claim-exclusion, and housing masks; and
4. logical-biome, nearest-feature, and housing-centre selectors with their slow
   oracles.

Every package brief names providers, owned files, return types, shared-schema
owner, fixture owner, and definition of done. Packages may overlap in time only
when that table proves their write sets and interfaces independent.

Wave 1C is the serialized ownership-handoff/schema package. Beside exporting
the two Section-11 ownership results consumed by C-a2, it reserves the accepted
dedicated empty `island_routes` family. That reservation is limited to
`schemas.lua`'s `compiled` binding, `compiled_schema.lua`'s
`EXPECTED_COMPILED_SCHEMA`, the `compiled_schema.lua` family list, the compiler
trust skeleton's `geometry_names` list, and the exact family lists plus schema-
mismatch negative literal in the two C1-pinned tests. It authorizes no
implementation wiring, population or other schema-identity change.

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

**Outcome, recorded 2026-08-22:** the probe has run. T5-0 is complete **as a
tools-only observation only**. It is not production T5, and the rule at the top
of this section is unchanged: full T5 still sits behind T3 and T4, and nothing
below moves it forward.

**Accepted engine cost:** about **12 seconds** for the four engine invocations
that generate twelve mapchunks. The four `complete` records of the accepted
capture sum to **11.82 s** of in-server wall time (3.018 + 2.931 + 2.932 +
2.935), against the package's own projection of **12.07 s**; both figures are
read from `tools/wp40/t5_probe/README.md` and from the evidence under
`tools/wp40/evidence/t5-probe-9ac056ffa4433c80364cc6535dfe6b4ff6ce8b30693248fcad4f834b430699c2/`.
Every one of those numbers is a single sample: the package writes
`timing_replicates: 1` and `timings_are_golden: false`, and it computes no
variance, median or spread. The 180 s outer timeout is a ceiling and must never
be quoted as the cost.

**What the experiment found, both halves:** the paired control is itself
order-dependent over SEAM — verdict `V-06` records native engine order
dependence — so there is **no stable `V-05` baseline**. The content outcome is
`no_stable_baseline`, and no SEAM difference is attributable to the payload.
In the same capture, CORE containment and the transaction bounds stayed green:
`V-01`, `V-02`, `V-03`, `V-04` and `V-07` all pass. A summary that reported
only the green half would be the dishonest one.

**User GUI corroboration, recorded 2026-08-22:** the complete six-step visual
pass is **6/6 green**. The cross-boundary gold bar was complete and aligned,
there was no visible surface light seam, the water/stair and cut/fill cases were
correct, terrain outside the declared write boxes looked ordinary, and no
unknown node appeared. This opened-world observation is corroboration only: it
adds no digest, timing, operation-count or generation-order evidence and moves
none of the headless verdicts or non-claims.

**Delivered size, against the band above:** that band underestimated the
package. At the implementation commit `a82ab17` the eleven shipped files under
`tools/wp40/t5_probe/` total **6,736 lines**, or **6,144** excluding the
592-line README, plus the committed evidence tree. That commit is what this
paragraph certifies, because the band was drawn against the *implementation*
package. Re-running `find tools/wp40/t5_probe -type f | xargs wc -l` on the
current tree yields **6,886** instead: the 2026-08-22 closeout hardened the
gates after `a82ab17`, adding lines to `compare_runs.sh`, `selftest.sh`,
`verify_log.sh` and the README, and that hardening is not part of the package
being measured. A reader who re-runs the command and finds 6,886 reconciles it
here rather than finding the certified number wrong. The overrun sits in
harness, schema prose and implementation surface, not in machine time — the
runtime was excellent, as the twelve-second figure above shows. **This size is
explicitly not a template.** A future early probe should preserve the small
runtime and cut harness, schema prose and implementation surface far more
aggressively.

**Next:** no additional T5-0 run is scheduled. The recorded risks — the package
contract's `R1`, `R2` and `R3`, plus the order dependence recorded above — are
consumed by full T5, after T3 and T4. The probe's full non-claim register is
not restated here; it lives in section 3.2 of
[wp40-t5-0-engine-probe-contract.md](wp40-t5-0-engine-probe-contract.md), which
owns it.

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
| T2 — compiled geometry | Turns the authored 38-zone world into one immutable deterministic payload: boundaries, terrain fields, routes, water, anchors, masks, selectors, fixtures, and traces. | boundary topology and C1-v3 downstream interface frozen; most non-topology buckets and production compiler unstarted | **extra-large**; still the largest single task; derived geometry volume and final integration are the remaining risk |
| T3 — public geography API | Gives gameplay code stable fast answers such as zone, level, territory, PvP state, water/mount class, nearest feature, housing eligibility, and protection. | not started; scaffolding/oracles may start while T2 finishes, but authoritative answers wait for T2 | **medium**; API semantics and hot-path performance |
| T4 — pure content planner | Decides, without touching the map, the exact final operation for each relevant voxel and resolves conflicts between terrain, water, routes, resources, and preservation rules. | not started | **large**; resolver completeness and typed ownership, but readily property-tested |
| T5 — engine adapter | Applies the T4 plan to real v7 output in one bounded VoxelManip transaction with correct light and liquids. | not started; the tools-only T5-0 probe specification is no longer pending and the probe has run as a tools-only observation (Section 8), but T5 itself is untouched | **large**; real-engine behavior, memory, chunk order, and no-op cost |
| T6 — surface catalog | Maps logical biomes to actual top/filler nodes, decorations, trees, and surface-water settlement without adding a second selector. | not started | **medium to large**; catalog breadth and visual/runtime iteration |
| T7 — resources | Places universal and cultural resources only in valid final hosts and proves supply/access expectations. | not started | **medium to large**; density tuning and deep typed replacement |
| T8 — migration | Moves every existing consumer to the new APIs and removes old map/height/ocean/dungeon authority only after replacements are green. | not started | **large to extra-large**; broad repository coupling and regressions |
| T9 — release | Replays and freezes final evidence, performance, order independence, coverage, a disposable visual world, rollout checks, and the runtime test plan. | not started | **large**, mostly integration/evidence; must not become a late feature phase |

The statement “T2 is the largest part” is credible only for individual tasks.
T2's topology has uniquely high discovery risk and has already paid for the
heavy machinery. The combined T3--T9 effort is larger, and T8 may rival a
substantial T2 phase if legacy consumers are more coupled than expected.

## 10. Dependency and parallelization sequence

Gate A and the first C1-v3 handoff are complete. The current authoritative
order is:

```text
accepted C1-v3 handoff + accepted PUC-1/D1-1 + GO
                           |
                     Phase 0A freeze
                           |
 parallel: payload-free C-a1 | Wave 1C ownership | Phase 0B preparation
                           |
               integrate ownership provider
                           |
               finalize/integrate Phase 0B
                           |
                          D-1
                           |
                 integrate green C-a1 + D-1
                           |
 landmark source-policy cleanup audit (batch only if no source edit and
       no S1/pool movement; either violation = STOP)
                           |
 selected-four LuaJIT + connectivity/adoption witness preflight
                           |
          exactly one C1-v3 PUC reacceptance
                           |
        C-a2 containment gate against final ownership
                           |
                         C-a2 H
                           |
                STOP before Lane C-b

C-a2 H freeze + D-1 route records + all other providers named by matrix
        +-> later route profiles and hydrology as separately cut Lane-C-b packages

Lane C-b + remaining Lane-D-2/D-3/D-4 provider packages
        +-> Lane E production compiler -> T2 final payload

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

The architecture review prepared two additional directional decisions:

1. **PUC final gates — PUC-1 ACCEPTED 2026-08-23.** The reviewed inventory and
   branch matrix received the final user ruling. Phase 0B's complete
   mechanical closeout and atomic authority fold are implemented for review;
   no lane may apply a partial wording update.
2. **Early engine work — RUN T5-0 WITH CONDITIONS.** Proceed with the
   production-like, tools-only, disposable probe specified in Section 8. It
   does not move full T5 ahead of T3/T4 and cannot be reused as production code.
   **Disposition: executed** — the probe ran under its package contract and its
   four-capture evidence is accepted and closed, with CORE containment and the
   transaction bounds green but no stable `V-05` baseline (Section 8).

## 14. Adopted speed-up measures

### 14.1 Per-lane Light-Regime harnesses

New C/D packages own small test files, runners, and fixtures instead of growing
the C1-pinned `t2_partition_test.lua`. A thin umbrella runner composes them at
T2-final. This is the default ownership rule in Section 6.2 and removes the
largest known shared write from the parallel lanes.

### 14.2 Reviewed PUC inventory; Phase-0B handoff

The Section 5.2 inventory was reviewed at commit
`2d443ffe8e9f0b3425fa446fd5f1608defc8bb20` and cherry-picked onto the
ownership provider as `62afc64`. It records:

- every current final PUC suite/command and the risk it covers;
- measured or conservatively projected PUC wall and CPU cost;
- the deterministic micro-corpus/branch matrix and full-path witnesses;
- explicit treatment of the full-`W` re-census, `pairs()`-order divergence,
  fallback-engine runtime gate, and dual-runtime engine benchmarks;
- the complete authority-hit list; and
- the decision memo that supported the accepted PUC-1 wording.

The historical inventory proposal changed no authority by itself. Phase 0B
corrects its stale pre-closeout rows, completes the ruling-owned witnesses,
re-derives the authority-hit list and performs the one atomic fold. Its final
compiler/worker evidence is bound to the integrated ownership provider as
Sections 5.2 and 10 require.

## 15. Authority fold-in

Phase 0B performs the accepted PUC-1 policy/evidence fold into every actual
interpreter-policy owner as one reviewed package after Phase 0A and the
ownership-handoff provider are integrated. Its mechanically re-derived checked
scope includes:

- `AGENTS.md`, `docs/process/wp-workflow.md`, `docs/research/luanti-lua.md`,
  `tools/wp40/README.md`, T2 plan, T5-0 contract, historical handover, PUC
  inventory and affected T2 contracts for interpreter, package, and execution
  rules; the engineering brief's engine-runtime gates remain unchanged; model
  routing is not folded into those WP40-local owners and instead follows the sole
  project-wide `docs/process/agent-model-policy.md` authority;
- the later T2 contracts Section 14.7 memo, which supersedes Section 11.4
  acceptance point 5 for the full-`W`/PUC separation; and
- the PCC scripts, immutable fixtures and retained calibration evidence.

The Phase-0A dungeon-policy/design update and BACKLOG status are already
integrated and contain no interpreter authority, so Phase 0B confirms them
unchanged rather than editing them again.

This file remains a planning record; it does not become a competing authority.

## 16. Definition of planning-ready

This planning record is ready to become an implementation plan when:

- the 2026-08-22 Fable/Sol reviews and completed fix disposition are recorded
  — **satisfied; no optional post-fix re-review remains pending**;
- the PUC inventory/branch matrix is reviewed and the final PUC ruling is
  recorded — **satisfied by PUC-1 on 2026-08-23**;
- the T5-0 substrate, tools-only payload, four cases, measurements, non-claims,
  and disposal rule are frozen in its package contract — **satisfied**; the
  probe then ran under it and its outcome is recorded in Section 8;
- each immediate lane has non-overlapping file ownership and frozen interfaces;
- sample and wall-time budgets are attached to every non-trivial planned test
  command; trivially short static gates need no individual budget;
- Phase 0A's durable freeze is integrated after its independent review;
- the accepted PUC outcome is folded atomically by Phase 0B as specified in
  Section 5.2 — **reviewed and integrated by merge `95e3261`**;
- every child package has a definition of done and an independent reviewer
  selected under the project-wide agent model policy;
- no unresolved player-visible design choice is left for an implementation
  agent to invent;
- every durable player-impact summary lives in its committed package contract
  or authoritative design link; and
- the Section 15 authority fold-in is complete.

The current execution order is narrower than this whole-document readiness
list: Phase 0A first; after it, C-a1, the ownership handoff and Phase-0B
preparation may overlap; the ownership provider integrates before Phase 0B is
finalized and integrated; D-1 then waits for that green fold; the single
integrated C1 reacceptance gates C-a2; and the current mandate stops before
C-b. The T5-0 specification is already frozen and its tools-only probe has run
(Section 8).
Full T5 still waits for T3 and T4.

**Execution status, 2026-08-24:** C-a1, D-1 and the reviewed landmark Source-
policy cleanup are integrated by merges `a494319`, `f72dc69` and `ee52c9d`.
Their post-merge package gates, the bounded LuaJIT selected-four/ownership
preflight and the single integrated PUC C1-v3 reacceptance are green. Commit
`89e4ba1` binds the 25 retained C1 files; same-HEAD resume and descendant-HEAD
recorded reuse are also green. Independent Opus/xhigh C1 acceptance review is
green; C-a2 is next, and the mandate still stops before C-b.

**Later status, 2026-08-24:** WARCOAST-SOURCE-1 is reviewed and integrated.
Its required fresh C1-v3 run, same-HEAD resume and descendant recorded-reuse
checks are green, with commit `17efc8d` binding the 25 current rows. The fresh
Opus/xhigh acceptance review is pending. After that review C-a2 resumes; the
user-authorized C-b0 rulings and parallel C-b/D-2 execution supersede the
earlier stop-before-C-b mandate once C-a2 itself is accepted.
