# WP40 T2 execution plan and state

Status: **living plan. Supersedes any ordering stated elsewhere.**

The other WP40 documents each own one thing and none owns this:
[wp40-engineering-brief.md](wp40-engineering-brief.md) is the contract,
[wp40-source-authority.md](wp40-source-authority.md) the compiler algorithm,
[wp40-reality-corrections.md](wp40-reality-corrections.md) the evidence
history, [wp40-t2-degeneracy-completeness.md](wp40-t2-degeneracy-completeness.md)
the bound on what remains open, and
[wp40-t2-handover.md](wp40-t2-handover.md) a superseded snapshot, useful for
its reasoning and not for its facts. This file holds
what is being done next, in what order, and why — the part that was living only
in a chat session until 2026-08-16.

One rule about this file itself, because the engineering brief grew from 134 KB
to 314 KB by accretion and nobody ever decided that *now* was the moment to
split it. Section 6 is a specification, not a plan. While there is exactly one
such contract it stays here. **The moment a second package needs one, both move
to `wp40-t2-contracts.md` and this file keeps only the pointer.** The trigger is
deliberately a countable event rather than a judgement about length.

## 1. Where T2 actually stands

`compiler.lua` builds 20 named geometry buckets. Their status:

| group | buckets | state |
|---|---|---|
| boundary topology | `land_boundaries`, `perimeters`, `bays`, `mouth_apertures`, `closure_wings`, `dry_faces` | computed and verified **offline only** |
| local pure fields | `relief_fields`, `templates`, `route_profiles`, `hydrology` | not started |
| downstream of a frozen perimeter | `coast_shelf`, `islands`, `channels`, `hard_protection`, `claim_exclusions`, `housing_masks` | not started |
| downstream of zone faces | `anchors` | not started |
| other | `zones`, `land_routes`, `boat_routes` | source records exist; not compiled |

Plus three selectors — logical biomes, nearest-feature, housing-centre — all
unstarted.

### 1.1 Two verification regimes, decided 2026-08-15

The groups above are not just a dependency ordering; they carry different
verification regimes, and that was a deliberate decision rather than an
accident of how the work happened to go.

**Boundary topology gets the heavy regime**: an independently implemented
oracle, mutation KATs, byte-identical digests, and a recorded Reality
correction whenever a configuration turns out to be undecided. Correctness
there is a *global* property — closed, counterclockwise, simple polygons;
8-connected traces; exactly one owner per column — so nothing local can
establish it. This is the regime that produced thirteen corrections and
roughly half its test volume in independent oracles, and it earned that cost.

**Everything else gets the light regime**: an argument that the function is
pure in `(x, z, seed)`, property tests, and a determinism digest. No second
independent oracle, no case-by-case policy prose. Order-independence — the
actual requirement, since chunks generate in arbitrary order — follows from
purity directly and does not need a topology oracle to establish it. The
template blend is `target_y = round(natural + weight(q) * (shaped - natural))`
evaluated per column; there is no trace to get wrong.

The reason to write this down is that the temptation runs one way. Whoever
picks up the remaining fourteen buckets will have just read thirteen Reality
corrections and will reach for the machinery that found them. Applying the
heavy regime to local pure functions would cost weeks against risk that is not
there. Escalating a bucket from light to heavy is a decision to argue for, not
a default to fall back on.

**The production path is not wired.** `compiler.lua:77` loads
`geometry/compiler_impl.lua`; that file does not exist, so the production entry
fails closed with `compiled_geometry_unavailable`. Everything achieved so far
runs through the offline harness driving `geometry/partition.lua` directly.
Creating `compiler_impl.lua` is a required step that appears in no task list;
it belongs immediately after the boundary geometry is final, not before, since
until then it would track a moving target.

T0 and T1 are complete. T3 through T9 have not started.

## 2. Ordering, and why census comes before conformance

**Run the census scans before the C1 selected-four conformance.** Not the other
way round.

C1 conformance is historically the generator of Reality corrections. Per
[wp40-t2-handover.md](wp40-t2-handover.md) section 3, R18 was found by the
first selected-four C1 PUC attempt, in slots 29 and 30; R19 by the subsequent
targeted Slot-29 compiler diagnostic against the frozen R18 Source. Running C1
first means re-entering the reproduce-diagnose-refreeze loop that costs roughly
a day per finding.

The census answers the same question structurally: which reject classes does
any wanted seed occupy, across the whole finite trigger universe of about 4,130
seeds, on paper rather than one failure at a time. Any occupied class it finds
must be closed before C1 could pass anyway, because the four winners are
members of that same universe.

Resulting order:

1. **Census scans 1, 2 and 3a** — interval/attachment/junction occupancy,
   R19 tuple occupancy, and Scan-3's S1–S5 share: the F4 aperture resolution
   classes, the F5 wing analyses and the four head-bank traces (split
   decided 2026-08-16). Scan-3a consumes neither selected intervals nor
   tuples, so it rides in the same per-seed worker pass at small marginal
   cost — Scan-1 already builds the final mask and the perimeters — and its
   results survive the collected correction. Scan-1 has a seed-independent
   prefilter; its discharges are verified at every seed rather than skipped
   (decided 2026-08-16) — the R7 compile dominates the per-seed cost, so
   evaluating all 61 edges is nearly free and turns the discharge claim into
   an exhaustively checked fact.
2. **One collected correction** closing every occupied reject class plus the
   decided U1, U2 and O1 closures, followed by **one** compiler
   reproduction. If the correction unexpectedly touches masks or terminals —
   R16 through R19 never did — Scan-3a is repeated; at ~10⁵–10⁶ local
   operations per seed that is cheap insurance, not a risk.
3. **Census scans 3b and 4** — the sixteen transition-incident bank traces,
   which need resolved transitions and therefore corrected tuples, then
   Face/Whole on the flagged, extremal and winner seeds only. The two
   predicted R20/R21 classes (aperture-anchor-dead with candidate `D`;
   wing-pair-dead with a live wedge-valid alternative) are measurable only
   here, so **a second, small correction round after Scan-3b is possible and
   accepted**: promoting them pre-emptively without occupancy evidence is
   what the R-series never did. The honest expectation is one large round
   after Scans 1–2 and at most one small round, its candidate classes
   already named, after Scan-3b.
4. **C1 conformance migrated to v3** against the artifacts the pool run
   produced.
5. **The downstream-of-perimeter group** — `coast_shelf`, `islands`,
   `channels`, `anchors`, `hard_protection`, `claim_exclusions`,
   `housing_masks`, and the logical-biome, nearest-feature and housing-centre
   selectors. All are pure functions of geometry that is frozen by then, so
   they carry no R-series risk, but nothing currently schedules them and the
   brief makes several of them T2 completion gates — "all six capital anchors
   are centered/contained" among them.
6. **`geometry/compiler_impl.lua`** — wire the verified geometry into the
   production compiler.

**Class B runs in parallel throughout.** The relief field `H`, the template
catalog and the one blend operator depend on nothing above; they sit on T1's
green arithmetic primitives.

## 3. Locked surfaces

These six files are covered by the stage-S1 authority digest that pins the
measured 4,096-candidate pool:

```
tools/wp40/t2_s1_authority.lua
mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua
mods/MAPGEN/grug_mapgen/wp40/canonical.lua
mods/MAPGEN/grug_mapgen/wp40/deterministic.lua
mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua
mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua
```

Editing any of them invalidates the pool and its four winner seeds, costing a
fresh ~91-minute measurement and a new winner determination. **No work package
may touch them as a side effect.** "I need a new arithmetic primitive" is an
escalation, not a local decision — which matters because Class B builds
directly on `deterministic.lua` and will be tempted.

The v3 winners are candidates 2192, 1713, 1047 and 3438 — the same four the
pre-R16 pool ranked, which is the measured evidence that R16 through R19 really
did change no scalar. They are printed by the merge and recorded in commit
`527b3a5`, but they are not yet a committed artifact row: that row is written
by the C1 conformance step, which is still on v2.

The pool's Source side is pinned by projection, not by file bytes, so
`source/catalog.lua` and `geometry/partition.lua` may change freely; that is
the whole point of the S1 scoping and it is verified by control experiment.

## 4. Measured cost anchors

Use these instead of extrapolating. Every figure below was measured on the
target host; where a ratio is inferred from two of them, it says so.

| operation | cost |
|---|---|
| S1 scalars, one seed | **10.7 s** (4,096 candidates / 91 min / 8 LuaJIT workers) |
| seed-0 compile, LuaJIT, uncached | **32.7 s** |
| seed-0 compile, PUC 5.1, uncached | **868 s** |
| seed-0 + max-u64 + traversal, PUC, uncached | **3,091 s** |
| payload cache hit | **0.37 s** LuaJIT / **1.03 s** PUC |
| full partition gate, PUC, 8-way sharded | **~62 min** wall |
| 4,096-candidate pool, 8 LuaJIT workers | **91 min** wall |
| `run_t2_s1_authority.sh` test, PUC / LuaJIT | **111 s / 21 s** (LuaJIT default since 2026-08-16) |
| `run_t2_extreme.sh` foundation, LuaJIT / PUC | **181 s / aborted unfinished at 1,975 s** (LuaJIT default since 2026-08-16) |
| `run_t1.sh` | 0.18 s |
| `luac51 -p` plus the five grep sweeps, whole owned set | 0.007 s |

PUC-to-LuaJIT ratio is **not** a single number: measured 2.8x on
validation-heavy paths, 16.2x on an exhaustive numeric sweep, and 26.5x on a
full seed-0 compile (868/32.7). Any plan resting on one extrapolated ratio has
been wrong before.

## 5. Open items not owned by a package

- **U1, U2, O1** — the complete undecided set from the completeness analysis
  (its sections 3-F2 and 3-F9). All three are decided below as of 2026-08-16
  and await the collected correction; the undecided set is empty.
  Characterised, because "U1" alone tells a reader nothing:
  - **U1** was a live contradiction between two policy strings.
    `bay_edge_transition_terminal_complete` requires a nonempty combined
    contiguous control subsequence per tuple; the R18-level
    `shared_boundary_incidence_reject` lists an empty subsequence as
    reject-without-fallback. On a seed where one tuple has an empty combined
    clip and another completes, the first reading accepts — the empty-clip
    tuple merely fails while the seed survives via the completing tuple —
    and the second rejects the whole seed. **Decided 2026-08-16: the
    tuple-level reading is authoritative.** An empty combined clip fails that
    tuple and enumeration continues; R19-level seed rejects arise only from
    the complete-tuple count (zero or multiple complete). The reject string
    is scoped to the levels that have no enumeration — the ordinary-edge
    interval subsequence and the selected result — where empty remains a
    seed reject. Grounds: every other per-tuple precondition failure is
    already decided-with-continuation; under the no-fallback-seed axiom the
    seed-reject reading is unstable, since the first wanted seed realizing
    the configuration would force exactly this amendment; and the scoping
    makes the two strings non-contradictory, leaving the empty-clip branch
    of the reject string unreachable at R19 level — the census will report
    it as a vacuous branch, which is intended. The collected correction
    implements this scoping in the catalog; until then the strings stand.
  - **U2** asks whether a one-station raster can satisfy "unique,
    8-connected", which arises when a two-ended tuple's candidate incidences
    coincide or cross, yielding in the limit a single-station probe.
    **Decided 2026-08-16: the tuple dies at tuple level, at the previous
    binding.** `bay_edge_transition_terminal_complete` binds each resolved
    terminal's `previous` to the immediately adjacent probe station away
    from it, and a one-station probe has no adjacent station, so the binding
    is unsatisfiable: the tuple fails, enumeration continues, and the seed
    survives via other tuples — uniform with the U1 decision, so every
    degenerate-clip shape is an ordinary per-tuple failure. The Stage-2
    192-station gate ([wp40-source-authority.md](wp40-source-authority.md)
    section 7.4) stays an independent backstop on the selected result and
    never sees this case. Whether any seed in `W` realizes a degenerate
    tuple is unknown and is exactly what Scan-2 measures: the scanner gives
    the case its own decision-class label — occupied means a DECIDED class
    and no finding; never occupied means a vacuous-branch row.
  - **O1** is a proof obligation rather than a gap. Aperture-versus-attachment
    collision is decided by evaluation order, aperture precedence first, and the
    interesting claim — that the collision is unreachable, because *every*
    attachment sits hundreds of nodes from *every* aperture while displacement
    is bounded by 96/64 with tapers — is
    asserted nowhere. **Decided 2026-08-16: close it with a Stage-1 margin
    assertion** — the authored distance from every attachment station to
    every mouth-aperture station, minus both records' displacement bounds,
    must stay strictly positive. Seed-independent, one-time, in the style of
    the F1 prefilter; it verifies the "hundreds of nodes" claim instead of
    restating it, and it converts exactly the kind of unasserted all-seed
    universal that R16 and H55 were made of into a checked fact. The
    declaring-sentence alternative was considered and rejected because it
    leaves the quantifier unchecked. Implementation rides in the collected
    correction; until then O1 stays formally decided and semantically
    unreviewed.
- **A targeted `pairs()`-order divergence test**, as the cheap substitute for a
  full PUC gate at every stage freeze. The canonical encoder sorts before
  emission, so serialisation is provably runtime-independent; control flow that
  depends on iteration order is the residual risk and can be tested directly.
- **The invariant review** named in the completeness analysis section 7 — the
  only bound against silent wrongness, the mechanism behind seven of the
  thirteen corrections so far, and behind three defects found on 2026-08-15
  alone: the vacuous ripgrep gate, the payload-cache regression, and a
  verification run that reported success with zero workers started.
- **Early-failure visibility for long runs**, raised 2026-08-16 and owned by
  the census runner design when that is written: a multi-hour scan must let
  the coordinating agent see broken or unusable output early and abort
  cheaply. Fan out at full width immediately — no serial pre-validation pass
  that only adds wall time (decided 2026-08-16). The early check runs against
  the fanned workers' first completed output: validate it against the
  artifact contract while the remaining seeds continue, flush per-seed
  progress lines, and keep partial results verified-resumable so an abort
  loses minutes rather than the run — the shard launcher's verified-resume
  pattern is the model.
  Deliberately not specified further yet; this bullet exists so the
  requirement is not lost.

## 6. The census artifact contract

The census is not a search for bugs. It is the step that converts an
open-ended discovery process into a finite work list, and everything about its
output shape follows from that. R11 through R19 each cost roughly a day
because each was found alone, by an expensive reproduction, and closed before
the next one could surface. The census exists to produce all of them at once.

If its output does not support that, the run is wasted even when it completes.

**Scope.** This contract governs Scans 1, 2 and 3a — the Scan-3 split is
recorded in section 2. Scans 3b and 4 produce further quantities named in the
completeness analysis section 5 and need their own clauses before they run;
the plan's ordering puts a collected correction between this contract's scans
and those, which partly invalidates anything produced earlier, so one
contract cannot span both sides of it.

**The keying question, decided 2026-08-16 per family.** The first draft keyed
every row by local configuration on the strength of the analysis's dedup
paragraph, while its section 1 states that R19 tuple selection (selected
interval plus bay envelope) and bank tracing (trace history plus bay envelope)
are *not* bounded-local — a truncated key there would let two seeds sharing a
key reach different decisions. The resolution: a row's key is the byte image
of exactly what the decision procedure reads — its read-set — and skipping a
seed because its key was already seen is permitted only where that read-set is
bounded-local. Per family: F2's counting tier (per-incidence eligibility and
R16 resolution) is bounded-local and may dedup-skip; F2's tuple tier (product,
probe, completion traces) reads the bay envelope and is evaluated on every
seed, its key an envelope digest kept for duplicate detection only. F3 step
classes are bounded-local and dedup into the vacuous-branch coverage; F3
whole-trace outcomes are evaluated on every seed. F1, F7 and F8 evaluate per
seed — cheap linear passes — with their bounded-local station and window
classes deduped for reporting. This costs nothing the contract was counting
on: per-seed jitter makes whole-object configurations effectively unique
anyway, so the seed multiplier was never going to collapse there — it is
collapsed by the seed-independent prefilter and Scan-2's counting-tier filter,
which is where the census cost model already put it.

### 6.1 The unit is a configuration, not a seed

Key every row by **(site, configuration bytes)**, where the configuration is
the read-set of that decision as resolved above — never (site, seed) as an
output shape. At the bounded-local tiers, sites realize identical bytes across
many seeds, so keying collapses the seed multiplier and matches the hypothesis
under test — which is about configurations the policy does or does not decide,
not about seeds. At the whole-object tiers the scan still evaluates every seed
and the key is witness metadata. Retain, per distinct configuration, the count
of seeds that realized it and the lexicographically least realizing seed as
its witness.

A scan that emits one report per seed has produced 4,130 reports and no list;
per-seed evaluation inside the non-local tiers is required, and the
aggregation into the tables below is still the only deliverable.

### 6.2 Required outputs

Five artifacts. Scan-2's own design is a cheap counting pass followed by
selective tracing of the interesting minority, so "one pass" is the analysis's
structure and not a requirement imposed here:

1. **Occupied-class table.** One row per (site class, decision class) actually
   realized, with its realization count and witness seed. A row whose decision
   class is REJECTED is a finding: it is a future correction, located on paper.
   This table is the deliverable; the rest supports it.
2. **Vacuous-branch list.** Every decision branch the §3 tables declare that no
   configuration realized. Freeze review becomes a coverage report rather than
   an assertion — a branch nothing exercises is either dead policy or an
   untested path, and both need saying out loud.
3. **Scan-4's input seed set**, which the analysis defines as a union and not
   as the extremal term alone: census-flagged seeds (fills > 0, tail mode,
   multi-interval, two or more candidates, any branch > 0, and the
   fragment-bearing case from section 3-F8) union per-site extremal seeds union
   winners union corpus. The flagged term is a per-seed derived list, so
   section 6.3's ban on per-seed intermediates must not delete it — it is an
   artifact, not an intermediate. Per-site extremal means the seeds realizing
   the minimum and maximum of that site's stress scalars, decided 2026-08-16
   per site kind so that every input is a quantity Scans 1–3 already compute:
   the 63 edge and perimeter records use the selected topology ceiling `C`
   and the maximum `abs(local_scalar_q)` over their stations (Scan-1); the 8
   transition endpoints use eligible-incidence and R16-success counts
   (Scan-2 counting tier); the 8 aperture incidences use the perimeter
   `local_scalar_q` at their D, W and A stations (Scan-1 — the perimeter is
   an R7 record, so the scalar exists there); the 8 wings use
   `Chebyshev(K,J)` and the selected pair's rank (Scan-3a); the 20 banks use
   trace step count and maximum DFS frame count (Scan-3a for the four head
   banks, Scan-3b for the sixteen transition-incident ones); the 38 junctions
   use the minimum Chebyshev clearance between incident-pair rasters
   excluding `J` (Scan-1); the 8 attachments use `Chebyshev(E,A)` (Scan-1).
   That is 153 structural sites; ties resolve to the lexicographically least
   seed, consistent with the witness rule. Every R-series trigger so far was
   an extremal seed.
4. **The prefilter discharge list** — every site the seed-independent
   prefilter discharged, with the reason. Cheap to regenerate, but without it
   the occupied-class table cannot distinguish "this class was never occupied"
   from "this site was never scanned", which is the table's entire claim.
   Decided 2026-08-16: discharged sites are still evaluated on every seed,
   and a discharged edge realizing any interval count other than one aborts
   the run — the list records verified predictions, not skipped work.
5. **Distribution histograms** named in the completeness analysis section 5 —
   interval counts per edge, attachment Chebyshev distances, junction-pair pass
   rate, fill counts per bay, and the joint (eligible, R16-success, complete)
   distribution per transition endpoint. Scan-3a adds its own: tail-mode
   occupancy per aperture incidence, wedge-valid multiplicity and selected
   rank per wing, `R > 5` / `w = 0` / `Chebyshev(K,J) > 4` events, and
   realized step-class coverage for the four head banks.

### 6.3 What must be reproducible, and what must not be retained

Commit the five artifacts above and the manifest that pins what produced them:
commit, tree, interpreter, scan version, and the seed set with its derivation.
Do not commit per-seed intermediates. Not because they are cheap to regenerate
— they are not, which is this whole section's premise — but because they bury
the list they exist to support. The named artifacts above, including the
flagged seed set, are outputs and are exempt from this.

Every finding must carry enough to write and test its correction without
re-running the census: the site, the configuration bytes, the witness seed, and
the decision the policy currently reaches. A finding that requires a rerun to
act on has not been recorded properly.

### 6.4 What counts as a finding

An occupied REJECTED class, a vacuous branch, a configuration the decision
table does not cover at all, or **a refuted frozen universal**. The third is
the rarest and most valuable: the completeness analysis argues the tables are
total, so an uncovered configuration falsifies that argument and is worth
stopping for. It also needs somewhere to land — an explicit no-branch-matched
sink, since outputs 1 and 2 are both keyed on declared classes.

The fourth is the one an occupancy table hides. `Chebyshev(K,J) > 4` and
`w = 0` are current source bounds asserted over all seeds; a seed exceeding
one is neither a rejected class nor a vacuous branch, so it must be recorded
as its own class. (`w` is the jittered Bay bank half-width `r + delta_nodes`
of [wp40-source-authority.md](wp40-source-authority.md) section 7.2 —
equivalently `E = base_width_num + delta_nodes*L` in the exact body predicate
— and `w = 0` is that width collapsing to zero at any station. Current
sources hold half-widths of 320–370 against jitter bounded by 48 nodes, and
nothing asserts that margin. The definition was reconstructed and confirmed
2026-08-16; the analysis introduced the symbol undefined, and its Scan-3
specification now carries the same definition.) `R > 5` is deliberately not
in this list: its exceedance is the explicit `wedge_radius_above_five`
reject, so it surfaces as an ordinary occupied REJECTED row in output 1. This is mechanism (c), the failure mode
R16 itself was, and the census is where it is cheapest to catch.

Occupancy of an ordinary DECIDED class is not a finding, however unusual it
looks.

### 6.5 Cost

Do not anchor on the 10.7 s in section 4: that figure is S1 *selector scalars*
only, while Scan-1 additionally performs the per-record R7 compile — up to 97
reraster probes across 63 records — plus roughly 10^5 station predicates. The
nearer anchor is the 32.7 s LuaJIT seed-0 compile, and even that is a floor.
Anchoring low is exactly what section 4 exists to prevent.

Launch at full width and measure as you go — no serial single-seed
pre-measurement; that decision is recorded with the early-failure bullet in
section 5. The run manifest states the single-seed cost measured from the
first fanned completions and the projected total, **in wall time at a stated
worker count** — section 4's anchors are worker-seconds and mixing the two
silently changes any threshold by roughly 8x. A projection that already
exceeds the stop threshold aborts the run within its first minutes instead of
before them. The prefilter is expected to discharge most ordinary edges
permanently, so the real figure should fall well below a naive
multiplication.

The stop threshold is a judgement call, recorded here as one rather than
presented as derived: **eight hours wall at eight workers**, decided
2026-08-16 — roughly five times the 91-minute pool, the largest routine
measured run. The comparison that justifies it: the census replaces a loop
that cost roughly a day per finding across a thirteen-correction series, so a
single finding pays for the full cap; a cap tight enough to forbid several
hours would be worse than the process it replaces, and a multi-day run would
mean the re-scoping this section mandates should have fired earlier.
Exceeding the cap is a reason to report and re-scope rather than to abandon.

### 6.6 The census runner

Decisions recorded 2026-08-16; the mechanics belong in `tools/wp40/README.md`
once the runner is built. The pattern throughout is the proven
`run_t2_extreme_shards.sh` launcher.

1. **Structure.** Eight range-sharded LuaJIT workers over `W` (~4,130 seeds),
   a launcher plus a per-shard worker script, canonical TSV shards under a
   census-specific naming scheme that can never collide with pool shards,
   and a deterministic merge into the five section-6.2 artifacts plus the
   manifest. One worker pass per seed computes Scan-1, Scan-2's counting
   tier, its tuple tier where the counting tier flags it, and Scan-3a. The
   geometry modules are imported read-only; the six locked surfaces are not
   touched. The runner honours `WP40_LUA_BIN` in the established pattern and
   defaults to LuaJIT ([luanti-lua.md](luanti-lua.md), interpreter
   principle).
2. **Early visibility.** Fan out at full width immediately; there is no
   serial pre-validation pass (section 5). The launcher validates each
   worker's first completed seed record structurally against this contract —
   every site present, classes drawn from the declared vocabulary — while
   the workers keep running; a structural failure aborts the run hard.
   Progress is flushed per-seed lines with range and ETA.
3. **Cost gate.** The projection from the first completions is checked
   against section 6.5's eight-hour cap; exceeding it aborts within the
   run's first minutes.
4. **Resume.** Verified per-shard resume; anything unparseable at a census
   shard path aborts the launcher loudly instead of being skipped.
5. **The PUC merge carries the `pairs()`-order divergence test.** The merge
   runs under vendored PUC Lua 5.1 and is the first carrier of the targeted
   divergence test from section 5: census aggregation is exactly the kind of
   iteration-order-dependent control flow that test exists to catch.
6. **Classification stance.** The scanners classify by the decided U1 and U2
   readings even though the catalog strings follow only with the collected
   correction — the census is R15-style structural search, not a policy
   edit; the manifest records this stance.
7. **Explicit GO.** The full-`W` run starts only on the user's explicit GO,
   matching the pool rule for expensive measurements. KATs and small
   explicit ranges run freely.
8. **The prefilter is verified, not trusted.** Every seed evaluates all 61
   edges; a discharged edge realizing any interval count other than one
   aborts hard. The R7 compile dominates the per-seed cost, so this
   verification costs under a second per seed.

### 6.7 Implementation work package (cut 2026-08-16)

Grounding: `geometry/partition.lua` (3,380 lines, freely changeable) exposes
only `compile`, the scalar session and validators — fail-closed,
all-or-nothing. The census therefore needs new projection entry points that
record decision classes and continue scanning, which is the critical core of
the package. The launcher and merge adapt from existing references
(`run_t2_extreme_shards.sh` / `run_t2_extreme_shard.sh` /
`t2_extreme_merge.lua` — 152/121/273 lines).

Milestones: **M1** worker pass for one seed — Scan-1 projections, artifact
row schema, prefilter verification; **M2** launcher with GO gate, resume,
first-record validation and cost gate; **M3** Scan-2 counting and tuple
tiers; **M4** Scan-3a; **M5** merge with the LuaJIT/PUC digest comparison
and KATs pinned on the known witness occupancies (seed 0 fills `0/0/0/0`,
max-u64 `1/1/1/0`, Slot 29 tail mode with two R16 candidates, Slot 30
fragment case).

Division of labour: the projection entry points, worker classification,
merge semantics and KATs are done in-session; the mechanical launcher and
merge plumbing may go to a capable subagent after M1 fixes the row schema,
briefed by goals with a cost cap. M1 is the heavy lift and the cost anchor
for everything after it: measure M1 before scheduling M3–M5.
