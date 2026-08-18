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

**Status, 2026-08-17.** Step 1 is done: the census ran over the full `W`,
its five artifacts are committed, and section 6.8 records what it found.
Step 2, the collected correction, is next — and it now opens with seven
occupied REJECTED classes to close rather than with an open-ended search,
which is the whole return on this ordering.

**Status, 2026-08-18.** The correction round is open. Section 7 holds the
gate-1 decision memo for its two open semantic questions — the R19
completion-multiplicity order and the aperture second-run closure — with
the measurements that ground them. Implementation starts only on the
gate-1 sign-off recorded there.

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
| census Scan-1 worker pass, one seed, LuaJIT | **22.7 s** seed 0 / 24–25 s max-u64 (measured 2026-08-16, M1) |
| the same pass, host variance across runs | **22–37 s** (measured 2026-08-16, M2) |
| the same pass, fork hasher vs persistent responder | **33–35 s / 26 s** wall, four processes in parallel (measured 2026-08-16, M2) |
| eight census workers, per-seed at first records | **28–36 s** (measured 2026-08-16, M2) |
| census Scan-1+2 pass, one seed, LuaJIT | **30–43 s** across seeds 0 / Slot 29 / max-u64 and repeat runs, host-load dependent (measured 2026-08-16, M3) |
| the Scan-2 share, unflagged seed | **~8 s** of a 30-s pass: ~5.4 s the eight lazy Wing tails, ~2.4 s the four per-Bay trace-bound envelopes, ~0.15 s the sixteen completion traces, ~0.13 s counting + probes (measured 2026-08-16, M3) |
| the flagged Slot-29 second tuple (probe + dead trace) | below run-to-run noise: 30.6 s total pass (measured 2026-08-16, M3) |
| census Scan-1+3a+2 pass, one seed, LuaJIT | **29–33 s**, median 31 s over nine interleaved seed-0 samples; the same host spikes to ~45 s under concurrent load (measured 2026-08-16, M4) |
| the Scan-3a surcharge per seed, interleaved M3-vs-M4 A/B | **~0.4 s**, about 1.4 % — inside run-to-run noise (measured 2026-08-16, M4) |
| the per-tier split after M4, one seed | stage build ~20–27 s, Scan-1 ~2.0 s, **Scan-3a ~8.3 s**, **Scan-2 ~0.6 s** (measured 2026-08-16, M4) |
| eight census workers, first completions, quiet host | **34–39 s** per seed (measured 2026-08-16, M4) |
| eight census workers, steady state, four seeds each | **36–69 s** per seed; per-worker means 37.5–54.0 s (measured 2026-08-16, M4) |
| the three slow first seeds of the aborted full-`W` start, re-measured solo | **29 / 31 / 32 s** per seed, against 51 / 53 / 70 s in the contended start minute; the control seed took the same 29–32 s (measured 2026-08-16, full-`W` abort) |
| eight census workers, first completions, idle host, re-run the same day | seven seeds **35–37 s**, one **53 s** — on a shard that was none of the three above (measured 2026-08-16, full-`W` abort) |
| seed 0 across the two full-`W` starts, same host, same bytes | **36 s** then **51 s**; the second start's shard 1 read 51/52/65 s on seeds 0–2 while seven shards held 34–39 s, and two of those seven then took 51 s on their *fourth* seed (measured 2026-08-16, second full-`W` abort) |
| the same runs' CPU time against their wall time | `cpu ≈ wall` throughout, 51.2 s CPU for 51 s wall on the slowest seed — the loss is per-cycle throughput on an SMT sibling, not the process waiting to be scheduled (measured 2026-08-16) |
| the four-seed census KAT, worker pass | **30–50 s** per seed, ~2.5 min total (measured 2026-08-16, M5) |
| the census merge over that four-seed record set, LuaJIT / PUC | **0.06 s / 0.06 s**, artifacts byte-identical (measured 2026-08-16, M5) |

The M1 census figure is the Scan-1-only floor for the section 6.5 cost gate:
4,123 seeds at ~25 s across 8 workers projects to roughly 3.6 h wall before
Scan-2 and Scan-3a are added in M3/M4 — inside the cap, but the gate must be
re-projected from the fanned completions once those tiers exist, not
extrapolated from this row.

With M3 measured, the projection from the same-day single-process band
(30–43 s) scaled by the M2-observed eight-worker inflation lands at roughly
**5.4–7.9 h wall at 8 workers** — inside the cap, tight at the slow end; the
first-completions cost gate remains the binding check and aborts if the slow
end materializes. Two structural notes for M4: the Scan-2 uplift is
dominated by the eight Wing tails and four trace-bound envelopes, which
Scan-3a needs anyway and consumes from the same per-seed tracer, so M4's
marginal cost should be far below M3's; and the flagged case costs no
measurable extra — the expensive term is the per-seed S5 substrate, not the
tuples.

**M4 measured both notes and did not move the projection.** The interleaved
single-seed A/B puts the whole Scan-3a surcharge at ~0.4 s, about 1.4 % and
inside noise, because the work did not grow — it moved: the eight Wing tails
and four trace-bound envelopes are now paid by Scan-3a, which runs first and
shares one tracer, and Scan-2's own share fell from ~8 s to ~0.6 s reusing
those caches. Genuinely new per-seed work is the four head-Bank traces, the
eight aperture resolutions and the four bank-width sweeps, and it disappears
into that 0.4 s. Eight-worker wall at M4: **5.7 h** projected from first
completions on a quiet host, **5.4–7.7 h** from four-seed steady state, so
the cap holds with the same margin M3 had.

The one operational caveat, measured rather than inferred: the same
first-completion probe read 71 s per seed and projected **10.2 h** while the
host was also running the steady-state measurement, and the cost gate
correctly aborted. The gate is not wrong there — the host really was
delivering that — but it means the full-`W` run must be launched on an
otherwise quiet host, which is the operational form of the M2 rows' warning
that this host's per-seed cost is a wide band rather than a number.

The first full-`W` start hit the same band from the inside and aborted on it,
2026-08-16, on a quiet host: eight cold first seeds, three of them 51/53/70 s,
projected 71 s per seed and 10.2 h. Re-measured solo those three seeds took
29/31/32 s — the control's own figure — so what the gate had measured was the
start minute's own contention, eight workers plus eight SHA responders across
eight physical cores. Two rows above are that measurement; section 6.6.3 is
the estimator decision that followed. The steady-state anchor is unchanged.

The second start, with that estimator, aborted honestly at 28,896 s against the
28,800 s cap — 0.33 % — from a shard whose seeds 0–2 took 51/52/65 s while the
other seven held 34–39 s and the corpus ETA read 22,728 s. Seed 0 had cost 36 s
in the first start, and the victims moved: two shards that ran 34–37 s for
three seeds took 51 s on their fourth. `cpu ≈ wall` throughout, so nothing is
waiting — this is SMT pairing churn, whichever worker happens to share a
physical core with another compile-heavy one. That is a property of the host,
not of a seed, and no ordering of `W` makes it go away. It is why section 6.5
re-decided the cap: eight hours could not tell this run apart from the 71 s
degradation case, which is the one distinction the threshold exists to make.

The M2 rows say why that re-projection is not a formality. The same seed-0
pass measured anywhere from 22 s to 37 s on this host depending on concurrent
load, so the 22.7 s anchor is the fast end of a wide band rather than a
central estimate; at eight workers the observed 28–36 s projects Scan-1 alone
to roughly 4.7 h. M2 also removed the per-call `sha256sum` fork, which was
worth about a quarter of the pass — measured as an A/B under equal load, not
inferred.

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
- **The F5 wedge-check reading** — found 2026-08-16 by the M1 read of
  `partition.lua` against the completeness analysis's section 3-F5 table,
  **decided 2026-08-16: the pair-level reading is authoritative.** A
  non-simple or zero-area wedge polygon and a wedge radius above five are
  per-pair exclusions: the pair is not wedge-valid, enumeration continues,
  and the seed rejects only through `no_wedge_valid_joint_tail_pair` — the
  compiler's current behavior. The analysis table reads both as seed-level
  rejects; that reading is unstable under the no-fallback-seed axiom for
  exactly the U1 reason — the first wanted seed realizing a non-simple wedge
  on an early pair while a later pair is valid would force this amendment —
  so every degenerate wedge shape is an ordinary per-pair failure, uniform
  with U1 and U2. Nothing observable is lost on the radius bound: `R`
  depends only on the selected `K-`, `K+` and `J`, which are fixed before
  pair enumeration, so `R` is constant per wing and seed and `R > 5` still
  forces the `no_wedge_valid_joint_tail_pair` reject. Scan-3a counts R>5
  and non-simple-wedge pair exclusions as their own decision classes; the
  collected correction scopes the `bay_bank_reject` string so
  `wedge_radius_above_five` and the non-simple clause name pair-level
  exclusions rather than seed rejects.
- **The R19 census substrate** — found 2026-08-16 by the same M1 read:
  `partition.lua` resolves transition endpoints at the R18 level (one `E`
  probe at the interval endpoint); the R19 joint-tuple machinery of
  [wp40-source-authority.md](wp40-source-authority.md) section 4 — eligible-
  incidence enumeration, per-incidence R16, checked Cartesian product,
  per-tuple probe reraster, Bank completion, exactly-one-complete — exists
  only as catalog policy strings that no code reads. **Decided 2026-08-16:
  the census projection layer implements the R19 enumeration itself in M3
  and the compiler stays unchanged.** Grounds: the census classifies by
  decided policy, not by compiler behavior (section 6.6.6, the R15 stance);
  changing the transition resolver now would be a boundary-topology edit
  under the heavy regime ahead of its occupancy evidence; and the plan's
  ordering puts the collected correction — where the compiler-side R19
  implementation belongs — after Scans 1–2. Consequence: M3 is larger than
  the milestone list assumed; it builds the tuple enumeration against the
  stage predicates rather than projecting an existing compiler path.
- **The Scan-2 flagging predicate** — the completeness analysis section 5
  gates the full tuple+trace tier on "≥ 2 R16 successes or any non-direct
  resolution", and section 6.6.1 restated that gate as a skip. **Decided
  2026-08-16 (M3): the tuple tier evaluates on every seed wherever at least
  one tuple exists; the predicate survives as the per-row `flagged` marker —
  a cost and reporting distinction, never a skip.** Grounds: section 6.2's
  artifact 5 requires the joint (eligible, R16-success, complete)
  distribution per transition endpoint from *this* contract's scans, and the
  complete component is not computable on the predicate's skipped side; the
  U2 decision names Scan-2 as the measurement that decides the degenerate
  tuple's occupancy, and U2's canonical witness shape (coincident
  single-success direct incidences) is unflagged under the predicate; and a
  1-success direct endpoint whose only tuple dies at completion is an
  occupied 0-complete REJECTED class — the R19-genesis shape — that would
  otherwise surface only after the collected correction, when Scan-3b's own
  precondition (resolved tuples) fails on exactly that seed. The keying
  paragraph in section 6 already said the tuple tier "is evaluated on every
  seed"; this entry closes the contradiction with 6.6.1 in that sentence's
  favour. Measured consequence (section 4): the always-on tier costs ~8 s
  per seed, dominated by the S5 substrate (Wing tails, trace bounds) that
  Scan-3a consumes anyway; the extra tuples themselves are noise-level.
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
   (Scan-2 counting tier); the 8 aperture incidences use, per D, W and
   A station, the `scalar_q` of the Chebyshev-nearest scalar sample of the
   owning perimeter, ties to the lower sample index (Scan-1; redefined
   2026-08-16 — the original "the perimeter `local_scalar_q` at their D, W
   and A stations" was not computable as written, because scalar samples
   carry pre-displacement base-station identities while D, W and A are
   displaced final-perimeter stations with no per-station scalar); the 8 wings use
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
in this list: under the pair-level F5 reading decided 2026-08-16 (section
5), its exceedance forces the `no_wedge_valid_joint_tail_pair` reject —
`R` is constant per wing and seed — so it surfaces as an ordinary occupied
REJECTED row in output 1, alongside its own pair-exclusion count in the
Scan-3a histograms. This is mechanism (c), the failure mode
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
fanned completions and the projected total, **in wall time at a stated worker
count** — section 4's anchors are worker-seconds and mixing the two silently
changes any threshold by roughly 8x. A projection that already exceeds the
stop threshold aborts the run within its first minutes instead of before them;
measuring as you go means the projection is re-taken as the run proceeds
rather than fixed at the first completions (section 6.6.3). The prefilter is expected to discharge most ordinary edges
permanently, so the real figure should fall well below a naive
multiplication.

The stop threshold is a judgement call, recorded here as one rather than
presented as derived: **nine hours wall at eight workers**, re-decided
2026-08-16 (eight hours as first decided the same day) — roughly six times the
91-minute pool, the largest routine measured run. The comparison that justifies
the order of magnitude: the census replaces a loop that cost roughly a day per
finding across a thirteen-correction series, so a single finding pays for the
full cap; a cap tight enough to forbid several hours would be worse than the
process it replaces, and a multi-day run would mean the re-scoping this section
mandates should have fired earlier. Exceeding the cap is a reason to report and
re-scope rather than to abandon.

**Why it moved, dated 2026-08-16.** Eight hours was chosen before any full-`W`
start had been observed, and two of them then bracketed it from both sides. The
second start aborted at a projected **28,896 s** — 0.33 % over — from a driver
shard whose seeds 0–2 took 51/52/65 s while the other seven ran 34–39 s and the
corpus ETA read **22,728 s**; the estimator was honest there, the run was
simply noisy. Before it, the borderline fleet pinned in the gate test (a 53 s
cold first seed and a 60 s second, 56.5 s per seed, **29,154 s**) sat on the
same side. Against those stands the one measured *degradation* case, the same
probe reading 71 s per seed under a competing eight-worker measurement:
**36,636 s**. Eight hours fell inside the honest band — it was 0.33 % *below*
the noisiest honest projection — so it could not separate the two populations
at all, which is the only thing a stop threshold has to do.

Nine hours (32,400 s) is the round hour at the geometric middle of the two
bands (√(28,896 × 36,636) = 32,537 s). It clears the noisiest honest projection
by 12.1 % and stops the degradation case 13.1 % below it, so both bands keep
better than a tenth of the cap as margin. The per-seed budget it implies is
62.79 s at 516 seeds, against a 34–39 s steady state. What did **not** move: the
estimator, the worker count, `W`, the fan-out at full width, and the rule that
a verdict needs two completions. A cap re-decided upwards to fit an estimator
would be the wrong repair; this one is re-decided to fit two measured
populations, and the numbers above are what makes it re-decidable again.

### 6.6 The census runner

Decisions recorded 2026-08-16; the mechanics belong in `tools/wp40/README.md`
once the runner is built. The pattern throughout is the proven
`run_t2_extreme_shards.sh` launcher.

1. **Structure.** Eight range-sharded LuaJIT workers over `W` (measured
   2026-08-16 at exactly **4,123** seeds — the 27 corpus slots and the 4,096
   pool candidates turn out to be disjoint, so the shards are three of 516
   and five of 515, not the pool's clean 512s),
   a launcher plus a per-shard worker script, canonical TSV shards under a
   census-specific naming scheme that can never collide with pool shards,
   and a deterministic merge into the five section-6.2 artifacts plus the
   manifest. One worker pass per seed computes Scan-1, Scan-2's counting
   tier, its tuple tier wherever at least one tuple exists (decided
   2026-08-16, section 5 — the flagging predicate marks rows, it never
   skips), and Scan-3a. The
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
3. **Cost gate.** A per-shard projection is checked against section 6.5's
   nine-hour cap; exceeding it aborts within the run's first minutes. The
   estimate is rolling and is re-taken at every completion: a shard's rate is
   its own elapsed seconds over its own completions, the projection is the
   slowest shard extended to full length, and a shard has to have completed at
   least two seeds before its rate may cast a verdict. The slowest *observed*
   shard is reported alongside the decisive one, so a single over-cap
   observation is visible in the log without being able to stop the run.

   Corrected 2026-08-16 after the first full-`W` start aborted — correctly by
   its own design, on a measurement basis that was wrong. The gate projected
   71 s per seed by taking the slowest of eight *first* completions and
   multiplying by 516: 36,636 s against the 28,800 s cap of the day (section
   6.5 re-decided it to 32,400 s later the same day, over a *second* abort —
   the fix below is the estimator's, not the threshold's). Three of those eight
   first seeds came in at 51, 53 and 70 s where five came in at 36–37 s, and
   all eight were sampled in the most contended minute the run has — eight
   workers plus eight SHA responders on eight physical cores, i.e. sixteen
   runnable threads where the run steadily needs eight. Re-measured solo
   afterwards, those same three seeds took **29, 31 and 32 s**, matching the
   control seed exactly. The heterogeneity was the host, not the seeds, and the
   steady state remains M4's 34–39 s per seed. A second flaw compounded it: the
   launcher divided by its own wall clock rather than the shard's, so every
   shard that had completed one seed was credited with the age of the fleet —
   the shard that finished a seed in 36 s was projected at 71 s per seed
   because a slower sibling had not finished yet.

   The cold first seed is systematic, not an artefact of that one contended
   start: re-run on an idle host the same day, seven of eight first seeds took
   35–37 s and one took 53 s — on a *different* shard than any of the three
   outliers above, which is what tells cold-start cost apart from an expensive
   seed. So one completion is an observation and two are a rate. Nothing else
   moved with this fix: the cap stayed at eight hours here — it was re-decided
   separately, in section 6.5, over the *next* start's honest 0.33 % overrun,
   because an estimator repair that also loosens its own threshold proves
   nothing — fan-out stays at full width (section 5), and no worker is pinned
   or staggered: a launcher that spreads its own start to flatter its own
   estimator measures a run nobody will ever have.

   Two is a floor and a thin one, recorded here as such: at the nine-hour cap
   32,400 s over 516 seeds is 62.79 s per seed, so a shard averaging above that
   across its first two seeds aborts a fleet whose other seven are on a 5.2 h
   pace — a 53 s cold first seed and a 73 s second one suffice, and neither is
   outside this host's measured range. At the retired eight-hour cap the same
   trigger sat at 55.81 s per seed, where a 53/60 pair reached it; that fleet
   passes now, which is the intended effect of the re-decision and is pinned in
   both directions. Raising the completion count is the only thing that widens
   the margin, at the price of a later abort on a genuinely slow fleet, and the
   replay tests pin where the trigger sits today so the trade is re-decidable on
   numbers. The
   deferral itself is deliberately unbounded: eight shards each holding one
   completion are deferred however far over the cap that observation lands,
   because the thing that ends a deferral is the next completion, not a clock.
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
9. **A dead worker aborts the fleet** (decided 2026-08-17, after the third
   full-`W` start). Run 3 lost three of eight shards to the same
   deterministic stage failure and the fleet ran on for over an hour,
   because worker errors reach the main log only at run end and nothing
   polled for liveness — the watch counted progress lines that kept
   arriving from the five survivors. The monitor loop now reaps every
   exited worker at its two-second poll, and an exit short of a complete
   range — whatever the exit status — kills the remaining workers, tails
   every shard log into the main log and exits nonzero. The partial shards
   are deliberately left on disk rather than reaped: the workers are
   deterministic, so a blind resume dies at the same seed, and the next
   start is expected to follow a fix that moves the module digest and
   invalidates them anyway — they are triage evidence, removed by the
   operator once triage is done. This narrows section 6.6.4's reaper to
   the aborts it was built for, the resumable ones.

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
tiers, including the R19 tuple enumeration itself, which the compiler does
not carry (decided 2026-08-16, section 5); **M4** Scan-3a; **M5** merge with the LuaJIT/PUC digest comparison
and KATs pinned on the known witness occupancies (seed 0 fills `0/0/0/0`,
max-u64 `1/1/1/0`, Slot 29 tail mode with two R16 candidates, Slot 30
fragment case). M1–M5 are done as of 2026-08-16; the stage-reject package
below followed on 2026-08-17, and the full-`W` run ran and merged the same
day — its results are section 6.8.

**Two M4 findings that belong on paper, not only in the census output.**

First, the `w = 0` margin is far smaller than section 6.4 implies. The
minimum jittered bank half-width over the sampled stations was **80 nodes** in
every Bay at every M4 KAT seed, and section 7.2's "half-widths of 320–370
against jitter bounded by 48 nodes" describes the *mouth* station only: the
four authored centrelines run 360/330/320/370 at the mouth and taper to **80**
at the Bay head. The collapse the universal forbids is therefore at most 80
nodes away, not 272. M4 added that the narrowest *station* is the segment
endpoint, where the 96-station smootherstep forces `delta_nodes = 0` by
construction, so jitter could not move it. **M5 refutes that clause**
(measured 2026-08-16): Slot 30, the fourth KAT seed, moves the station minimum
off the zero-jitter endpoint in two of the four Bays — Elandor-west from
station 301 to station 231 at `delta = −30` and 75 nodes, Kragmar-east from
341 to 263 at `delta = −26` and 74 nodes. The taper decides which *segment*
holds the minimum, not which station, and a three-seed sample was simply too
small to see it. Nothing load-bearing moves with it, because the station
minimum was never what ruled the collapse out: the station set is not the set
the compiler evaluates. `exact.bay_segment` computes the same numerator at
every *column*, pairing it with the *nearest* station's delta, so the station
minimum alone cannot decide the universal. The census therefore also carries
an exact per-column lower bound, `min(h_a, h_b) + min(deltas)` per segment,
which is a true bound because every column's effective half-width is either
the clamped interpolation of the two endpoint half-widths or an endpoint cap
radius, and its delta is always an element of that segment's own array.
Measured across the four KAT seeds that bound runs **46–80 nodes** — Slot 30's
46 is the tightest and is 29 below that Bay's own station reading of 75 —
against a structural floor of `80 − 48 = 32`. A run where every station is positive but
the bound is not gets its own class, `bay_bank_width_unbounded_event`:
"measured positive" and "could not be excluded" are different claims and
collapsing them is how an unasserted universal survives. The KAT now pins the
station minimum, its jitter and the column bound per seed and per Bay rather
than asserting a constant, which is the shape that would have caught the M4
over-generalisation on its first new seed.

Second, **two declared reject classes are dominated rather than merely
unoccupied**, found by the M4 cold classification review. `R > 5` cannot
arise at all: `wedge_valid` derives the radius from the selected `K-`, `K+`
and `J`, and the `Chebyshev(K,J) <= 4` guard has already hard-failed the Wing
before any pair is enumerated, so `R = 1 + max Chebyshev(K,J) <= 5`
identically. The section 5 sentence "`R > 5` still forces the
`no_wedge_valid_joint_tail_pair` reject" is therefore true only vacuously —
a seed with `Chebyshev(K,J) = 5` dies at the guard under
`wing_k_chebyshev_above_four_reject`, and the wedge reject is never reached.
The pair-exclusion reading itself is unaffected; only its stated mechanism
was wrong. Likewise `aperture_w_foreign_water_reject` is unreachable from
compiler-built evidence: `w_final_owned_by_bay` implies `not w_foreign_water`
and is tested first, so an aperture whose `W` is owned by another Bay is
classified `aperture_w_not_bay_water_reject`. Both classes stay declared —
that is what the vacuous-branch report is for — but they are dominated, not
unoccupied, and the difference matters to whoever reads a permanent zero.
The `intra_tail_x_cross` exclusion cause is vacuous for a third reason: a
distance-layer tail visits exactly one column per Chebyshev level, so two of
its diagonal steps can never share a 2x2 cell.

Third, the F3 step-predicate list in the completeness analysis is not the
predicate space the tracer realizes, in three separable ways: "unseen" is
two distinct bits (directed state and column); the diagonal X-cross
compatibility the analysis lists only among the rejects is a *successor
admission* predicate; and terminal reachability is not a successor predicate
at all — `trace_bank` evaluates it only at branch width two or more, so a
lone admitted successor is taken with no reachability test and a dead one
surfaces later as `cannot reach its target` rather than as a reject at that
step. The census declares six predicates and gives the untested-single case
its own selection class. This is logged, not judged: it is exactly the
"first-passing equals design-intended shore" remainder the analysis marks as
mechanism (b), and the four head Banks realize **zero** branching steps at
every KAT seed, so nothing turns on it yet.

**Four M5 findings, and what the artifact contract had to decide.**

First, **the Slot-30 fragment case reproduces exactly as section 3-F8 and
3-F1 describe it** (measured 2026-08-16, the first census measurement of that
seed). `land_007` carries two maximal dry intervals of which one is a
singleton; exactly one qualifies for both obligations, so F1 selects and the
nonselected interval is the excluded dry fragment, and the attachment on that
edge sees the same interval count. It is simultaneously 3-F1's "singleton
interval — it is `E` for both obligations and does not qualify" witness. The
seed is now the fourth KAT seed; the worker KAT digest moved with it,
legitimately, and is re-pinned. Nothing downstream moved: every endpoint
resolves once and directly and every edge completes exactly one joint tuple,
so the fragment lives entirely at the F1 interval tier.

Second, **one section-3 branch is not measurable from a v3 record at all**.
3-F8's "distance tie → DECIDED (canonical perimeter station index)" needs a
tie *indicator*; the attachment row retains the chosen canonical index but
nothing that says a tie occurred. Reporting it vacuous would be a false claim
about coverage, so the vacuous-branch artifact carries an `unmeasured` line
kind and this branch is its first entry. Adding the indicator is a record
schema change (v4) and a worker re-pin, and is deliberately not done here.
Two further entries have the same shape for stated reasons: F5's side clause
has no counted cause because `collect_paths` emits strict-side stations only,
and 3-F7's Stage-1 roster and departure-record rows are seed-independent
validations that abort loudly by design.

Third, **three section-3 rows have no class column but are derivable**, and
the merge reports them as `derived` rather than dropping them: the singleton
interval above (`edge.singleton_count > 0`), F2's "eligible incidence without
adjacent-away station" (the counting tier encodes eligibility in its loop
bounds, so its occupancy is the selected interval length minus the eligible
count) and F7's passing pair (only failing pairs emit a row, so the passing
class is read off `junction.pass_count`). All three are occupied at every KAT
seed.

Fourth, **the targeted `pairs()`-order divergence test earned its keep on its
first run**, which is worth recording because the alternative was to declare
it satisfied by the canonical encoder's sorting. It found a real order
dependence in the merge: a site can realize the same branch through more than
one row of a single seed — a Wing counts seven pair-exclusion causes on one
row — and "the first such row" is an arrival-order choice. The witness rule is
now the least row of the least seed. The test runs in two halves, because
either alone proves nothing: a probe half that shows this runtime's `pairs()`
really does hand out a non-sorted order (otherwise the invariance half passes
vacuously, which is the failure this branch has shipped twice) and an
invariance half that folds a synthetic record set covering every declared
class, and the measured records where they fit in memory twice, through the
whole artifact construction in two orders and requires byte-identical output.
A merge whose probe comes back sorted aborts rather than recording the fact
and continuing, since the invariance half would then pass for exactly the
reason that makes it worthless.

**What section 6.2 left open and M5 decided**, recorded here because the
artifacts state it and a later reader should not have to re-derive it:

- **Keying.** Section 6.1's configuration key survives in the v3 record only
  for F2's tuple tier, as `scan2_tuple.key` — the read-set envelope digest.
  No other family emits a read-set digest, so the occupied-class table is
  keyed by `(site, decision class)` exactly as section 6.2.1 words it, with
  the seed realization count and the least witness seed. Nothing is lost:
  the keying paragraph's dedup permission was a *cost* rule about skipping
  seeds, and the worker skips none.
- **The joint distribution of artifact 5.** Section 6.2.5 asks for
  `(eligible, R16-success, complete)` per transition endpoint, but completion
  is a property of the joint tuple and therefore of the *edge*: eight
  endpoints sit on six edges. The histogram attributes its edge's complete
  count to each of its endpoints and says so, and the exactly-measured
  per-edge `(tuples, complete, duplicate)` distribution is emitted beside it.
- **The 153-site extremal roster fills to 137 from Scans 1–3a.** 61 edges and
  2 perimeters (the fixed Holy band is excluded, and the merge *verifies* its
  zero displacement rather than assuming it — that is why section 6.2.3 says
  63 and not 64), 8 transition endpoints, 8 aperture incidences, 8 Wings, 38
  junctions, 8 attachments, and 4 of the 20 Banks. The sixteen
  transition-incident Banks are Scan-3b; the artifact names all sixteen, so
  the open remainder is a work list rather than a shortfall. Section 6.2.3
  names one scalar the record does not carry directly — the Wing's
  `Chebyshev(K,J)`, whose guard is per side — and the merge takes the larger
  of the two sides, which is the value the `<= 4` universal is asserted
  against.
- **The no-branch-matched sink is the merge's own check**, not a re-read of
  the verifier's. The worker refuses to emit an undeclared class and
  re-raises an unmatched reject message as a loud abort, so an uncovered
  configuration reaches the operator as a dead shard rather than as a row; a
  sink reachable only when the verifier is bypassed would not be one. The
  merge therefore re-checks every classed row against the declared vocabulary
  itself, writes all six outputs, reports the count in the manifest and exits
  non-zero — it completes and reports, it does not swallow.
- **The merge's own cost at full-`W` scale is not measured**, and is
  deliberately not projected from the four-record KAT, whose 0.06 s is almost
  entirely fixed startup. What is bounded by construction is the *output*:
  every artifact store is keyed by site, branch or a small-domain bucket, so
  the artifacts do not grow with |`W`| except in the flagged seed list and the
  per-endpoint joint distribution, and no per-seed record is retained. The
  run manifest states section 6.5's cost figures for the *scan*, persisted by
  the launcher beside the shards as its gate measured them — the last of the
  rolling evaluations, which by the end of the run is the slowest shard's
  measured cost rather than a projection.
- **First occupancy worth naming.** Over the four KAT seeds 19 of 83 declared
  branches are realized and 64 are vacuous, none of them a REJECTED class, so
  there is no finding yet — as expected from four seeds chosen for their
  witnesses rather than for breadth. The one unforced observation:
  `wedge_nonwing_water` is occupied at all eight Wings on every seed, so the
  F5 pair-exclusion population is dominated by the wedge water scan rather
  than by the structural causes.

File cut: `tools/wp40/run_t2_census.sh` (launcher),
`tools/wp40/t2_census_worker.lua`, `tools/wp40/t2_census_merge.lua`;
committed artifacts and KAT fixtures under `tools/wp40/fixtures/t2_census/`.
Census shard names must never match a pool shard pattern (section 6.6.1).
M2 added `tools/wp40/t2_census_authority.lua` outside this cut, deliberately:
the `W` derivation, the shard-range and shard-name rules, the decision-class
vocabulary and the two numeric gates are each needed by the launcher, the
worker and the M5 merge, and a second copy of such a rule is what aborted a
fresh pool launch before any seed was measured. `t2_census_gate.lua`,
`t2_census_hasher.lua`, `t2_census_sha_server.py` and the two gate-proof
harnesses came with it; the mechanics are in `tools/wp40/README.md`. Shards
are per-seed intermediates and therefore live under the gitignored
`tools/wp40/results/t2_census/`, not in fixtures — section 6.3 governs there,
and only the merged artifacts of section 6.2 are committed.

Division of labour: the projection entry points, worker classification,
merge semantics and KATs are done in-session; the mechanical launcher and
merge plumbing may go to a capable subagent after M1 fixes the row schema,
briefed by goals with a cost cap. An Opus-class cold review of the finished
classification layer against the analysis's §3 tables is part of the package
(confirmed 2026-08-16); it reviews, it does not rewrite. M1 is the heavy
lift and the cost anchor for everything after it: measure M1 before
scheduling M3–M5.

**The stage-reject package (2026-08-17), cut after full-`W` start 3.** That
start stopped at 885 of 4,123 seeds: three of eight shards died
deterministically on `bay_mouth_aperture:elandor_east has a wrapping or
second aperture run` (`build_scan_stage`), at roughly one seed in 285.
Verified witnesses, index-checked against the run's own `W`: W-112 =
343674299183575008 (solo-reproduced, deterministic), W-605 =
2466379686918096853, W-1642 = 7403557699456021182. The framing decision:
this is **not** a bug in aperture construction but an occupied 3-F9 REJECT
class — the analysis has always declared aperture interval malformation
("wrap, overlap, second run, dry station, boundary") REJECTED — that the
census could not record, because the deciding predicates run during stage
construction, which M1's design could only abort. The M5 "dead shard rather
than a row" stance was decided for a *bypassed verifier*; here it cost 21 %
of a full-`W` run per occurrence while producing the finding three times and
recording it zero times. The aperture construction itself is untouched —
same predicates, same order, no tolerance for second runs, no mouth-run
selection; whether the policy changes is decided in the collected
correction, after the census is complete (section 2).

The census therefore records the failure instead of dying of it, under
schema v4 (`grug_wp40_census_scan_v4`, shard pattern `census-scan-v4-*`):

- **Six classified stage-reject classes**, all REJECTED, drawn per fail
  site in the aperture block: canonical wrap, dry station (realizable only
  by the mouth itself), overlap, second run (the witnessed class), authored
  wrap and authored second run — the two index orders fail independently,
  and the census follows the procedure's granularity. Three aperture-block
  sites stay loud aborts and are declared as such in the coverage report:
  the two mouth-absent lookups (seed-independent — Bay centrelines are
  no-jitter displacement sources — so a miss is a catalog defect; the
  authored lookup is dominated by the canonical one) and the maximality
  check (3-F9's "boundary stations passing it", unreachable by construction
  because the expansion loops terminate exactly where the Bay predicate
  fails). Everything outside the aperture block — S1 validity, notch
  ownership, roster shapes — keeps aborting hard; the classifier requires
  an aperture row id at the message head and re-raises anything unmatched,
  so an unknown failure can never quietly become a row (the M3 lesson).
- **A second record shape.** A stage-rejected seed emits exactly one
  `stage_reject` row — site, class, and the verbatim fail message as its
  section-6.3 configuration bytes — and nothing else; the record grammar
  makes the two shapes mutually exclusive, and the merge re-checks that
  independently of the verifier. Since such a seed builds no stage, it has
  no prefilter: stage_reject records may precede the prefilter block, the
  block sits before the first full record, and an input with no full record
  at all is refused rather than guessed at — the refusal keys on the
  missing full record, not on the block, so a prefilter block copied into
  an all-reject body attests nothing. The worker still *completes* an
  all-reject run with its digest line, because the solo reproduction of a
  stage-reject witness is exactly that run and the record is the evidence;
  such a file can be read but never resumed or merged. One row per seed:
  the block aborts at its first failing aperture in source order, so
  per-(site, class) counts are lower bounds conditioned on that order.
- **Contributions, declared not implied.** The occupied-class table gains
  the REJECTED row and witness (the finding); the vacuous-branch report
  gains the six-class vocabulary plus the two abort-by-design declarations;
  the Scan-4 seed set gains stage-rejected seeds through a new
  `stage_reject` flag rule (decided 2026-08-17 — post-correction they are
  exactly the stressed geometry Scan-4 exists to look at); extremal roster
  and histograms gain nothing, which the merge asserts rather than assumes,
  and the manifest findings line counts `stage_reject_seeds` explicitly.
- **KAT.** W-112 is the fifth KAT seed, inserted in sorted place; the
  fixture pins its site and class and the worker asserts the seed still
  stage-rejects — a witness that quietly built a full stage would mean the
  finding vanished, and the digest alone would report that as an opaque
  drift. Record digest and `merge_artifacts_digest` moved legitimately (v4
  plus the fifth seed) and are re-pinned; `--merge-kat` remains the merge
  gate. The deferred F8 distance-tie indicator stays out — one finding, one
  package (decided 2026-08-17).

Not in this package, by explicit scope: the launcher's reaction to a worker
death mid-fleet, deletion of the eight v3 shards under
`results/t2_census/`, and full-`W` start 4 — the coordinator owns those
after acceptance. One measured interaction is recorded here for that
package rather than half-decided in this one: a stage-rejected seed
completes in ~8 s against a 34–39 s steady state, and the section-6.6.3
rolling rate counts it as an ordinary completion, so a shard whose early
completions include rejects projects optimistically until later full
completions dilute the effect — at ~1/285 occupancy the expected error
over a shard is well under the cap's 12 % margin, but the cold-start
window where two completions decide the verdict is exactly where an 8 s
sample distorts most. Whether the estimator should discount stage-reject
completions (it would need the progress line to carry a full-completion
count) is the coordinator's call, beside the worker-death watch it
already owns. Decided 2026-08-17, with that watch built (section 6.6.9):
it does not discount them. The dilution errs only toward optimism — a
cheap completion can lower a projection, never abort an honest fleet — so
the one failure it can cause is a missed early abort, which section 6.5
already tolerates by design ("report and re-scope", the operator's watch);
at ~1/285 occupancy the expected drift stays well under the cap's 12 %
margin, and a discount would add a second completion-counting rule to the
progress line against a risk the cap's own margins absorb. Re-decidable
on run 4's measured projections if the drift reads otherwise.

### 6.8 What the census measured (full-`W`, 2026-08-17)

Start 4 completed all 4,123 seeds across eight shards in 7 h 50 min with no
abort, and the merge published the five section-6.2 artifacts plus the
manifest byte-identically under LuaJIT and the vendored PUC 5.1
(`artifacts_digest c754ad2c…`, commit `4b83f8f`). Three numbers close open
items of this section rather than opening new ones. The rolling estimator's
last evaluation read **28,166 s against a measured 28,178 s** of wall clock,
so the section-6.6.3 repair is accurate to twelve seconds at full length and
the re-decided cap kept 13 % margin over what the host actually delivered —
the estimator question is settled on measurement now, not on the two aborts
that produced it. The merge's own cost, which section 6.7 deliberately
refused to project from the KAT's 0.06 s, is **about seven minutes**, the
LuaJIT half under one. And the section-6.6.9 worker-death watch was
exercised against the real fleet before the start rather than trusted.

**The finding list is seven occupied REJECTED classes, and the class that
stopped run 3 is the smallest of them.**

First, **all six transition edges realize `scan2_multi_complete_reject`** —
land_007 at 321 seeds, land_004 at 248, land_013 at 119, land_010 at 52,
land_016 at 13 and land_001 at 4, against 4,116 scanned seeds per edge.
More than one joint tuple completes, and the R19 decision rejects. This is
the census earning its ordering: R19 was found once, on one seed, by an
expensive reproduction, and its residual failure mode turns out to occupy
up to 7.8 % of the wanted universe on a single edge and to touch every edge
there is. No amount of C1 conformance would have said that; it would have
produced one witness and one more day.

The measured `(tuples, complete, duplicate)` distribution bounds the
correction that has to follow, which is why section 6.2.5 asked for it.
**Completions never exceed four** — four occurs at two seeds on land_013,
three at 23 seeds across land_007 and land_013, and every remaining
rejection is exactly two. Tuple counts reach six (land_007, two seeds), so
the enumeration is wider than its completions. **`duplicate` is zero in
every one of the 34 measured buckets on every edge**, which is why
`scan2_duplicate_authority_reject` is vacuous rather than merely unoccupied.
And multiplicity of *tuples* is ordinary and benign: land_013 holds 1,175
seeds with two tuples of which exactly one completes, land_010 holds 515.
The policy gap is therefore narrow and stated exactly: a total order over at
most four completing joint tuples, on six named edges, with the duplicate
authority provably out of scope. The witness seeds are in the artifact —
land_007's is 2147483648.

Second, **`aperture_second_run_reject` at `bay_mouth_aperture:elandor_east`
occupies 7 seeds**, or 1 in 589. The three witnesses that killed shards in
run 3 are all among them, so nothing was lost in the v4 conversion, but the
rate is half what run 3's evidence suggested: three events in an 885-seed
prefix were extrapolated to ~1/285 and ~14 seeds over `W`. The
extrapolation was a projection from three events and was not marked as one
when it was passed on. It cost nothing here, and it is recorded because the
same reflex applied to a cost or a cap would not be free.

Third, **nothing else fired, and that is the more valuable half of the
result.** The section-6.4 no-branch-matched sink is empty over the whole
wanted universe, so no configuration escaped the section-3 tables — the
completeness analysis has now survived the strongest test available to it
short of Scans 3b and 4. All three frozen universals read zero:
`Chebyshev(K,J) > 4` never occurred, the Bay bank half-width never
collapsed, and `R > 5` remains dominated. Of 89 declared branches 22 are
realized and 67 vacuous, with three derived and five unmeasured lines
distinguishing "dominated" from "untested" as section 6.2.2 requires. The
accounting check that no seed went missing: on every edge the DECIDED and
REJECTED seed counts sum to 4,116, which is 4,123 minus the seven
stage-rejected seeds that build no stage and therefore emit no rows.

Fourth, **the `pairs()`-order divergence test ran its probe and its
synthetic half only.** Its measured half is skipped at full-`W` scale under
the contract's own "where they fit in memory twice" clause — 96 MB of
records do not — and the manifest states it rather than leaving a reader to
assume the stronger check ran. The probe came back unsorted, so the
synthetic half is not passing vacuously, which is the failure this branch
has shipped twice.

**What this hands the collected correction.** Seven classes, each with its
site, its realization count, its witness seed and that witness's verbatim
record row, and therefore actionable without re-running the census as
section 6.3 demands. Six of them are one policy question on six edges; the
seventh is an aperture construction that admits a second run at seven seeds.
Scan-4's input set is a union of 3,061 seeds covering 137 of the 153
structural sites, with the sixteen Scan-3b banks named as the open
remainder, and the prefilter's 14 of 61 discharges verified at every seed
rather than assumed.

## 7. The collected-correction round (opened 2026-08-18)

This section is the decision memo for the two open semantic questions of
the step-2 collected correction (section 2): D1, the R19
completion-multiplicity order, and D2, the aperture second-run closure.
Everything else the correction implements is already decided in section 5
(U1, U2, O1, F5, the R19 substrate) and is not re-litigated here. This is a
decision record in the section-5 style, not a package specification; the
6.7-style implementation contract is written only after the gate-1
sign-off, and writing it is the countable event of the preamble's
contract-relocation rule — at that moment section 6 and the new contract
both move to `wp40-t2-contracts.md` and this file keeps the pointers.

Provenance of the gate-1 measurements. Every number below derives from the
committed census artifacts and shard records (`artifacts_digest c754ad2c…`,
commit `4b83f8f`) except the D2 shape diagnostic, which ran the census
worker's free seeds-mode over the seven witness seeds in a scratch worktree
at `2060d44` with the canonical second-run sweep patched to report the run
structure inside its existing failure message. Measured cost: 7 s wall per
seed, 48 s total — stage rejects abort before the expensive tiers, so the
section-4 30-s anchor was the ceiling, not the estimate. Its record is
committed as `tools/wp40/results/correction-round-d2-diagnostic.tsv`. The
census was not re-run (section 6.3).

### 7.1 D1 — the R19 completion-multiplicity order

**Decision (2026-08-18, awaiting gate-1 sign-off).** Amend
`bay_edge_transition_terminal_selection`: multiple complete joint tuples
cease to reject the seed; the compiler selects the least complete tuple
under the declared total order below. Zero complete tuples remain a seed
reject. Duplicate authority remains a seed reject and stays outside the
order's scope — measured `duplicate = 0` in all 34 buckets over `W`, so
that clause is provably not what the order decides.

**The order.** For each declared transition endpoint of the fixed R18
interval, a tuple's *retreat* at that endpoint is the station distance
along the selected interval from the declared endpoint to the tuple's
incidence station (0 = the endpoint itself). Complete tuples compare
lexicographically by:

1. total retreat, summed over the edge's declared transition endpoints,
   ascending;
2. maximum per-endpoint retreat, ascending;
3. elbow-terminal count, ascending;
4. the sorted set of resolved terminal world coordinates, lexicographic
   by `(x, z)`;
5. the sorted set of `previous` world coordinates, likewise;
6. the probe byte sequence under canonical orientation (the
   lexicographically lesser of the bytes and their exact reverse).

Totality is guaranteed, not asserted: two tuples equal under keys 4–6
share resolved terminal, `previous` and probe-edge byte identity, which is
duplicate authority and already rejected before the order applies.
Reversal stability: every key is invariant under authored edge reversal —
each endpoint's retreat is measured from its own declared end, the sets in
keys 4–5 forget endpoint labels, and key 6 is orientation-canonical — so
`bay_edge_transition_terminal_reversal` holds unchanged.

**Grounds.**

- *R18 continuity as the selection principle.* The zero-retreat tuple is
  the R18-level resolution (one `E` probe at the interval endpoint, elbow
  included where R16's own per-incidence resolution produced one). R19's
  enumeration exists to salvage a completable terminal, not to reopen
  terminal placement; among completable tuples the order deviates least
  from the declared endpoints.
- *Retained authored geometry.* Retreat counts exactly the authored R7
  controls discarded from the combined clip; minimizing it retains the
  most authored geometry. Measured confirmation: at all-direct witnesses
  the probe station count equals interval length minus total retreat
  exactly (seed 1013 land_004: 1601 at retreat 0 vs 1598 at 3; witness
  2147483648 land_007: 1586 at 0 vs 1583 at 3), and elbows add exactly
  their one inserted `T`.
- *House precedent.* The attachment tie (`Chebyshev(E,A)`, then canonical
  station index), F5's least wedge-valid pair, and the coast-source
  zone → component → segment order are all declared lexicographic
  minimization over canonical quantities with a total formal tail.
- *Measured selectivity.* At all 757 multi-complete `(seed, edge)` records
  over `W` (land_007: 321, land_004: 248, land_013: 119, land_010: 52,
  land_016: 13, land_001: 4), key 1 alone selects uniquely — the winner's
  retreat is 0 at 730 records, 1 at 25, 2 at 2. Keys 2–6 are exercised by
  no measured configuration; they exist for totality on paper. At the 16
  records carrying an elbow completer (all land_010:to), the elbow stands
  at retreat 0 and wins over a direct completer at retreat 1–2 — the
  R18-continuous outcome, since R16 owns mode resolution at the incidence.

The order is total for **any** multiplicity. The measured completion bound
(never above four) is designed against, not baked in — deliberately,
because the seven D2 seeds return to the scanned universe with unmeasured
tuple distributions (7.3.2).

**The forbidden-list scoping.** The
`iteration_order_first_longest_nearest_scan_backstep_side_flip_and_private_tie`
ban stays fully in force for candidate enumeration — nothing is pruned,
the complete Cartesian product is still evaluated — and for *undeclared*
orders. The amendment adds one declared order over the already-enumerated
complete set, the F5/attachment/coast shape. It is not the banned
"nearest": no candidate is skipped and the metric is anchored to the
declared endpoints, not to a scan. It is not byte-length selection: probe
length is a derived affine consequence of retreat at direct tuples and
diverges from it exactly at elbows, where the inserted `T` must not
outvote an endpoint terminal — live at the 16 elbow records above.

**Stability under the no-fallback-seed axiom** (completeness analysis 6.3,
axiom B). The standing reject occupies up to 7.8 % of `W` on land_007 and
touches every transition edge; witness seed 2147483648 realizes it with
two complete tuples at retreat 0 and 3. Axiom B makes a wanted-seed reject
with a decidable local alternative unstable — the first selected seed
realizing it forces exactly this amendment. The decision extends the
U1/U2/F5 uniformity from per-tuple and per-pair continuation to selection
among completion survivors.

**Unchanged outcomes.** Exactly-one-complete keeps its selection by
construction — a one-element set has one minimum — including the 1,175
land_013 and 515 land_010 two-tuple single-completion records; zero-
complete and duplicate-authority rejects are unchanged; every census
DECIDED row keeps a byte-identical outcome.

**Rejected alternatives, and what each loses.**

- *Keep the reject.* Loses 757 wanted `(seed, edge)` records, is unstable
  under axiom B, and re-enters the R19-genesis reproduce-diagnose loop at
  C1 — the cycle the census ordering exists to avoid.
- *Enumeration order / first-complete.* A private order, explicitly
  banned, and not reversal-stable.
- *Shortest probe.* Anti-aligned with retained authored geometry (equal to
  maximal retreat at direct tuples), and its elbow `+1` flips the 16
  measured elbow-at-endpoint records to interior directs.
- *Direct-before-elbow as the primary key.* Re-litigates R16's
  per-incidence mode resolution inside R19 and moves the same 16 records
  off the declared endpoint.
- *Collapse duplicate authority, then select.* Out of scope by measurement
  (zero in all 34 buckets) and would weaken the reject that guarantees the
  order's totality backstop.

**Implementation split (post-sign-off).** The catalog amendment scopes the
selection string; the compiler-side joint-tuple machinery lands in
`geometry/partition.lua` per the section-5 substrate decision; the M3
census projection implements the same order independently; the two sides
cross-check by digest — the plan's standing oracle stance.

### 7.2 D2 — the aperture detached-shoulder admission

**Decision (2026-08-18, awaiting gate-1 sign-off).** Scope
`aperture_second_run_reject` and `aperture_authored_second_run_reject` so
that each sweep admits, per aperture end and per station order (canonical
and authored), at most one detached Base-Bay-passing station separated
from the aperture run by exactly one non-passing station. The admitted
station is a **detached shoulder station**: it stays outside aperture
membership, payload and ownership — all keyed on the compiled included
set, which is unchanged — it is recorded on the compiled aperture row, and
the Bank shoulder resolution takes source-authority 3.1 at its word: `A`
is *the next dry station away* from `D`, resolved by a search that skips
the detached station, with every existing F4 validity check on `D`, `W`
and `T` unchanged. Every other Base-Bay-passing station outside the mouth
run keeps the reject.

**The measured shape — the entire occupied class over `W`.** Seven seeds,
all at `bay_mouth_aperture:elandor_east`, all three run-3 shard-killers
among them. At every one: exactly one extra run, exactly one station long,
exactly two stations before the canonical mouth run — a gap of one
non-passing station — at world point `1227:-2928` (five seeds) or
`1270:-2929` (two). The authored-order sweep realizes the same
one-station, gap-one shape at all seven. Record:
`tools/wp40/results/correction-round-d2-diagnostic.tsv`. Two artifact
caveats follow from the diagnostic: `aperture_authored_second_run_reject`
is **co-occupied at the same seven seeds**, not unoccupied — the census's
one stage-reject row per seed is a first-fail lower bound (stated in the
classifier comment in `partition.lua`), and the vacuous-branch table
inherits that condition for every aperture-block class. And the
before-side-only occupancy is a fact about `W`, while the admission is
side-symmetric because 3.1 gives both shoulders one resolution authority;
deciding per side would be a private distinction. That symmetry is a
design-uniformity choice, not an occupancy extrapolation, and is marked as
such.

**What the sweep was actually protecting.** Not topology at large — the
shoulder's neighborhood assumption. `partition.lua` compiles
`bank_before_previous` positionally as `stations[first − 2]`, and 3.1's
`A` ("the next dry station away") is that station only when no detached
run exists. The witnesses realize exactly the configuration where
`first − 2` passes the Bay predicate. The admission moves the assumption
into the construction: the search reading of 3.1. Ownership, equality and
membership authorities already key on the included set
(`partition.lua` — the perimeter-equality and owner branches read
`aperture.included`, never the raw predicate), so the detached station
classifies under the existing F9 span rules; no new station class exists.

**Stability under axiom B.** The seven are pool members at 1 in 589;
rejecting them permanently is unstable the U1 way. Bounding the admission
to the measured shape is stable the census way: `W` is finite and closed,
the census measured every other second-run shape at zero occupancy, and
completeness analysis section 4's rule — a REJECTED class with zero
occupancy over `W` can never fire — is the license to keep the wider
reject. Admitting more without occupancy evidence would be the pre-emptive
promotion the R-series never did (the section-2 R20/R21 stance).

**Rejected alternatives, and what each loses.**

- *Keep the reject.* Seven wanted seeds permanently non-compilable,
  including all three seeds that killed run-3 shards; unstable under
  axiom B.
- *Absorb the detached station and gap into the aperture.* Breaks the
  all-water membership invariant (its own reject class), changes canonical
  membership indices that 3.1 forbids the Bank resolution to change, and
  moves the mouth payload and equality authority on seven seeds.
- *Extend notch fill to heal the gap into water.* A mask edit: it
  invalidates every mask-consuming authority and Scan-3a's survival claim
  — the maximal blast radius available for the smallest finding.
- *Unbounded admission of second runs.* Admits topology classes with
  measured zero occupancy over a closed `W`; nothing can ever realize
  them, and each admission would need its own shoulder re-derivation.

**KAT obligation, named now.** Post-sign-off, mutation KATs pin the seven
witnesses through the full aperture and shoulder resolution, including the
`D`/`W`/`T` checks at the detached shoulder. Any F4 check that fails there
surfaces as its own declared reject class — a new recorded finding, never
a silent path.

### 7.3 What these measurements change about step 2's stated expectations

1. **The reproduction will touch masks and terminals, and the touched set
   is named in advance** (a projection, marked as one). Measured over the
   committed shard records: on every one of the 2,042 DECIDED
   `(seed, edge)` records with two or more tuples and one completion, the
   completer is interior — retreat 1 at 1,809 records, 2 at 226, 3 at 7
   (land_013: 1,230, land_010: 609, land_004: 152, land_007: 51) — and at
   all 27 multi-complete records whose order-winner is interior, R16
   succeeded at the declared endpoint itself, so the R18-level stage build
   used the endpoint terminal in every one of these cases. The correction
   therefore moves the resolved terminal at about 2,069 `(seed, edge)`
   sites by one to three stations; the exact byte diff is what the
   reproduction measures. Step 2's "untouched (the R16–R19 expectation) →
   proceed" branch will not be taken; the Scan-3a repeat is the planned
   path, and stays cheap by section 2's own pricing. Section 2 step 1's
   claim that Scan-3a results "survive the collected correction" holds
   only where terminals do not move; the repeat supersedes it.
   **Winner dependency, measured:** v3 winner seed 16178445837170081103
   is one of the 2,042 (land_010, completer at retreat 1) — one of the
   four winners compiles only through the R19 machinery, the Slot-29 shape
   now with a winner witness over `W`. No winner realizes multi-complete
   or the aperture class.
2. **The seven D2 seeds return to the scanned universe.** Post-correction
   they build stages for the first time; every per-edge family universe
   grows from 4,116 to 4,123, and their Scan-1/2/3a rows do not exist in
   the census artifacts. The correction round completes the census over
   exactly these seven seeds as part of its verification — worker
   seeds-mode, measured 7 s per stage-rejected seed and bounded by the
   ~30-s full-pass anchor once they compile — an artifact addendum, not a
   census re-run. Their transition-tuple distributions are unmeasured,
   which is why D1's order is total for any multiplicity rather than for
   the measured bound.
3. **Artifact caveats surfaced at gate 1:** the authored-sweep
   co-occupancy of 7.2, and the general condition that aperture-block
   occupancy counts are per-seed first-fail lower bounds — stated where
   the classifier lives, restated here where the correction consumes them.

**GATE 1: implementation starts only on coordinator and user sign-off of
7.1 and 7.2.**
