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
**The trigger fired 2026-08-18**: the collected-correction implementation
contract is the second package specification, so it and section 6 both live
in [wp40-t2-contracts.md](wp40-t2-contracts.md) — section 6 below is the
pointer, and the section numbering is shared across the two files (the
contracts file holds 6 and 8, this file the rest).

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
there is a *global* property — closed, counterclockwise polygons, simple or
window-guarded touch-accepted (the 2026-08-20 contracts-§11.5-C
correction as completed by §11.9); 8-connected traces; exactly one owner
per column — so nothing
local can establish it. This is the regime that produced thirteen corrections and
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
the measurements that ground them. Gate 1 was resolved the same day with
three binding conditions; the implementation contract is section 8 of
[wp40-t2-contracts.md](wp40-t2-contracts.md) (whose cutting moved section
6 there too), and implementation waits at gate 1.5 on the coordinator's
review of the contract and the relocation.

**Status, 2026-08-18, late — step 2 is implemented and verified.** The
collected correction landed (commits 482a134, dd09917) and the section-8.5
verification fleet ran the full `W` under the CPU-domain gates: 4,123 of
4,123 seeds in 8 h 22 min wall, zero stage rejects, zero
compile↔projection disagreements, no gate events. The v2 artifact set is
published beside the untouched v4 census of record
(`artifacts_digest 37fcdc5e…`): **zero occupied REJECTED classes over
`W`** — the census's irreducible feedback edge (completeness 6.3) now
measures dead — with the seven returning seeds listed by name in the
manifest as detached-shoulder admissions, all at elandor_east:after,
matching the gate-1 diagnostic exactly. **Gate 2 was accepted the same
day (contracts 8.6, acceptance recorded there): step 2 of this section's
ordering is complete.** Named open items handed to the next phase's cut,
beside the three pre-existing findings recorded at the acceptance: the
launcher's CPU-accounting loop keeps polling `/proc` for already-exited
workers (harmless stderr noise, run 5 measured 956 lines); the
cpu/cost projection lines were emitted only in the run's first minutes
rather than refreshed over its length; and the Scan-4 seed-set union
moved 3,061 → 3,058 between v4 and v5 — its composition must be answered
from the row grammar, not assumed, when the Scan-3b/4 package is cut.

**Status, 2026-08-18, step 3 opened.** The Scan-3b/4 package is cut as
section 9 of [wp40-t2-contracts.md](wp40-t2-contracts.md) (the relocation
rule); implementation proceeds under it. Its one escalated semantic
question — whether the detached-shoulder admission joins the Scan-4 flag
vocabulary, which decides the input union 3,058 versus 3,061 — waits on
the coordinator's ruling (contracts 9.2); the fleet does not launch
before it.

**Status, 2026-08-20, step 3 measured and closed.** The 9.2 ruling
landed as branch A (590ce99); the v6 scanners, KATs and gates are
ba37b96; run 6 measured all 4,123 seeds in 10 h 15 min under the
CPU-domain gates (68.16 CPU-s/seed against the 115.24 budget, zero
worker deaths, zero dead-worker `/proc` lines) and the merge ran the
9.2 top-up protocol (15 seeds) and published the v3 artifacts under
`artifacts_digest 2433d6f6…` (060614b), LuaJIT/PUC byte-identical, the
153-site roster closed 153/153. **R20/R21 both measured zero over `W`**
— the step-3 small-correction trigger did not fire. The measured
findings — `face_non_simple_reject` on 796 of 3,076 members at ten
bay-chain faces, `whole_gap_reject` on 370, one
`fragment_unowned_reject` — are ruled in the contracts **section-10
post-run decision memo**: the census closes as a measurement and the
findings open the named bay-transition-simplicity correction package.
All four winners are clean on every Scan-4 tier.

**Status, 2026-08-21, the §11 bay-transition package landed.** The
package is `931e857` — one atomic commit on the fifth attempt (four
honoured STOPs before it), carrying the closing, residue adoption, the
appendix acceptance with `W := 12`, the ring and seam completions and
the live production Whole gate. The acceptance sweep measured 1,166
witnesses green — zero REJECTED rows of any class, winner invariance
4/4 byte-identical — against one outdated ledger pin, and the
contracts **section-11.11 closeout** records the two measurement
corrections behind it (adoption 117/118 → 118/119, family-B evidence
93 → 105 stations; `W`, semantics and code unchanged), pins them as
committed fixtures plus a committed checker, and closes the §11
acceptance green. **Boundary topology is semantically frozen**: a
change to it needs a new memo. Next are the C1-v3 conformance /
topology handoff and the parallelizable light-regime T2 fields —
explicitly *not* another §11 round.

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
    implements this scoping in the catalog (implemented 2026-08-18,
    contracts section 8).
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
    correction (implemented 2026-08-18 as the authored segment-box versus
    bay-envelope margin assertion, contracts 8.1).
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
  and the compiler stays unchanged.** (The compiler side landed with the
  collected correction, 2026-08-18, contracts 8.1.) Grounds: the census classifies by
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

## 6. The census artifact contract (moved 2026-08-18)

Sections 6.1–6.8 live verbatim and under their original numbering in
[wp40-t2-contracts.md](wp40-t2-contracts.md), moved when the
collected-correction implementation contract became the second package
specification — the countable event the preamble names. Every
"section 6.x" reference in this file and elsewhere resolves there
unchanged.

## 7. The collected-correction round (opened 2026-08-18)

This section is the decision memo for the two open semantic questions of
the step-2 collected correction (section 2): D1, the R19
completion-multiplicity order, and D2, the aperture second-run closure.
Everything else the correction implements is already decided in section 5
(U1, U2, O1, F5, the R19 substrate) and is not re-litigated here. This is a
decision record in the section-5 style, not a package specification. The
gate-1 sign-off was given 2026-08-18 with three binding conditions
(recorded in the phase brief's "Gate 1: RESOLVED" section); the
implementation contract folding them in is section 8 of
[wp40-t2-contracts.md](wp40-t2-contracts.md), and its cutting fired the
preamble's contract-relocation rule — section 6 moved there with it.

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

**Decision (2026-08-18; gate-1 sign-off given the same day).** Amend
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

**Decision (2026-08-18; gate-1 sign-off given the same day).** Scope
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

**GATE 1: resolved 2026-08-18.** Coordinator and user sign-off of 7.1 and
7.2 is given; the coordinator independently recounted the load-bearing
numbers from the shard records and verified the D2 diagnostic against 7.2.
The three binding conditions — synthetic KATs for D1 order keys 2–6, the
gate-2 locked-surface control experiment, and marked provenance with its
own digest for the seven-seed artifact addendum — are folded into the
implementation contract ([wp40-t2-contracts.md](wp40-t2-contracts.md)
section 8). **GATE 1.5 follows it: implementation starts only on the
coordinator's review of that contract and of the section-6 relocation.**
