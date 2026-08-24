# WP40 T2 package contracts

Status: **contract file. Created 2026-08-18 by the plan's own relocation
rule.**

**Model-routing note (2026-08-22):** model names and division-of-labour
statements in this file record how the named historical T2 packages were run.
They are not instructions for future agent selection. All contexts started
after this policy was adopted on 2026-08-22 follow the sole project-wide
[agent model policy](../process/agent-model-policy.md); no T2 section overrides
it. Contexts already running when that policy was adopted finish under their
accepted briefs.

[wp40-t2-plan.md](wp40-t2-plan.md) holds ordering and decisions; this file
holds package specifications — the census artifact contract (section 6),
the collected-correction implementation contract (section 8), the
Scan-3b/4 census completion contract (section 9), and the later handoff
freezes through section 14. The numbering
is shared with the plan and preserved from where each contract was cut:
every existing "section 6.x" reference resolves here unchanged, and new
sections continue the plan's numbering space so a bare section number stays
unambiguous across the two files. Section 6 is moved verbatim from the plan
(2026-08-18); its internal cross-references to sections 1–5 and 7 point
back into the plan.

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

**Why the wall cap retired, dated 2026-08-18** (user decision,
coordinator-reviewed; phase brief, "Run-cost gate redesign"; binds 8.5 and
every later long run). The cap above calibrated itself to kill the one
measured *contention* case, which presumes a dedicated runner. The host is
a workstation: concurrent user load is normal operation, not degradation,
so wall time separates nothing and ceases to be a kill criterion entirely —
no automatic wall-kill, no backstop hour count, no notifications. The
rolling wall projection survives as an advisory figure in the progress
output and the manifest, checked manually. The hard abort moves to the CPU
domain, where intrinsic pathology and contention actually separate:

- Workers report per-seed CPU seconds (`os.clock` delta) beside wall in
  the progress lines — telemetry only, never in canonical artifacts or
  their digests (the v4 manifest-cost pattern).
- **Intrinsic gate:** the section-6.6.3 rolling per-shard projection,
  re-based from per-seed CPU seconds, aborts on a CPU budget of the
  measured anchor times a **measured** contention margin.
- **Liveness gate:** zero completions fleet-wide while the fleet has
  consumed at least `X` CPU-seconds since the last completion aborts —
  the busy-loop hang, without false-firing when idle-priority workers are
  merely starved (a starved fleet accumulates no CPU). `X` is generous,
  from the measured worst per-seed CPU.
- The margin and `X` are **measured, not estimated**: a short probe in
  this section's degradation-measurement style — a few seeds under
  synthetic full host load, measuring the SMT CPU-time inflation — sets
  the multiplier before the fleet launches.
- Workers launch under idle scheduling (`chrt --idle 0` plus `ionice -c3`,
  `nice -n19` fallback): user work preempts the fleet and the run
  stretches instead of the user yielding the machine — accepted
  consequence, decided by the user.
- Honest residual, stated: a worker blocked forever while consuming no
  CPU triggers no automatic exit; only the manual checks catch it
  (accepted — pure-computation workers make the state exotic, and the
  6.6.9 worker-death watch still covers process death).

The 6.7 cost-verdict boundaries stay coherent with this: every wall figure
recorded there remains a measurement of its day; the gates that consumed
wall figures are re-based, not re-litigated.

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
3. **Cost gate.** *(Amended 2026-08-18, with the section-6.5 wall-cap
   retirement: the rolling projection below is re-based from per-seed CPU
   seconds against the measured CPU budget, wall becomes advisory-only,
   and the liveness gate rides beside it. The estimator mechanics — a
   shard's own elapsed over its own completions, two completions before a
   verdict, slowest shard extended to full length — carry over unchanged
   to the CPU domain.)* A per-shard projection is checked against section 6.5's
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

Historical division of labour: the projection entry points, worker
classification, merge semantics and KATs were done in-session; the mechanical
launcher and merge plumbing were eligible for a capable subagent after M1
fixed the row schema, briefed by goals with a cost cap. An Opus-class cold
review of the finished classification layer against the analysis's §3 tables
was part of the package (confirmed 2026-08-16); it reviewed, it did not
rewrite. M1 was the heavy lift and the cost anchor for everything after it, and
M3–M5 were scheduled only after M1 was measured.

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

## 8. The collected-correction implementation contract (cut 2026-08-18)

This contract implements plan section 7 — the D1 completion-multiplicity
order (7.1) and the D2 detached-shoulder admission (7.2), signed off at
gate 1 on 2026-08-18 — together with the already-decided section-5
closures (U1, U2, O1, F5) and the R19 compiler substrate
([wp40-source-authority.md](wp40-source-authority.md) section 4), followed
by the one compiler reproduction the plan's step 2 requires. The three
gate-1 sign-off conditions (phase brief, "Gate 1: RESOLVED") are folded in
below as 8.3 (synthetic key KATs), 8.5 (the marked v5 artifact set) and
8.6 (the locked-surface control experiment). Heavy regime throughout
(section 1.1): this is boundary topology.

**GATE 1.5 stands between this contract and its implementation.** The
coordinator reviews the contract and the section-6 relocation; nothing
below runs before that go.

### 8.1 Scope and surfaces

Changed files: `source/catalog.lua` and `geometry/partition.lua` (both
free, S1 pinned by projection — section 3), plus KAT fixtures and gate
plumbing under `tools/wp40/`. The six locked files are not touched, not
even as a side effect; a needed arithmetic primitive is an escalation, and
8.6 verifies the pin rather than trusting it. Scans 3b and 4 are out of
scope (next phase, on the corrected tuples). Anything that turns out
undecided during implementation gets a recorded Reality correction, not an
inline fix.

Catalog amendments, all semantic and in-session:

1. `bay_edge_transition_terminal_selection` gains the D1 order exactly as
   plan 7.1 states it — total retreat, max per-endpoint retreat, elbow
   count, sorted terminal set, sorted previous set, canonical probe bytes
   — selecting the least complete tuple; zero-complete and
   duplicate-authority rejects unchanged; the enumeration ban list stays
   in force and the string says the order is declared selection, not
   pruning.
2. U1: `shared_boundary_incidence_reject` scoped to the levels without
   enumeration (ordinary-edge interval subsequence, selected result); an
   empty combined clip at R19 level is a per-tuple failure and the string's
   R19 branch is declared vacuous.
3. F5: `bay_bank_reject` scoped so `wedge_radius_above_five` and the
   non-simple clause name pair-level exclusions — textual truthfulness
   only, since the M4 finding (section 6.7) proved `R > 5` dominated by
   the Chebyshev guard.
4. D2: the two second-run reject strings scoped to the plan-7.2 admission
   — at most one detached Base-Bay-passing station per aperture end and
   station order, separated by exactly one non-passing station; everything
   else keeps the reject.

Partition changes:

1. The R19 joint-tuple machinery of source-authority section 4 in the
   compile path: eligible-incidence enumeration, per-incidence R16, the
   checked Cartesian product, per-tuple unretained probe reraster, Bank
   completion under unchanged R11 rules, duplicate-authority reject, then
   selection — one complete selects, several select the least under the
   7.1 order, zero rejects. Only the selected tuple's probe bytes
   materialize. The U2 `previous` binding failure and the U1 empty-clip
   failure are per-tuple continuations, matching the census vocabulary
   (`scan2_tuple_previous_binding_unsatisfiable`,
   `scan2_tuple_empty_combined_clip`).
2. The D1 comparator is implemented **twice** — once in the compile path,
   once in the M3 projection — per the plan's oracle stance
   ("implement the decided order on both sides and cross-check by
   digest"). Both are pure functions over tuple descriptors so the 8.3
   synthetic KATs can drive them directly.
3. D2: the aperture block admits the plan-7.2 class; the compiled aperture
   row records the detached station; `bank_before_previous` /
   `bank_after_previous` become source-authority 3.1's literal
   next-dry-station search; every existing F4 check on `D`, `W`, `T` is
   unchanged and any failure there surfaces as its own declared class.
4. O1: the seed-independent Stage-1 margin assertion — authored distance
   from every attachment station to every mouth-aperture station, minus
   both records' displacement bounds, strictly positive; F1-prefilter
   style, evaluated once, loud abort (a structural defect, not a seed
   class).

Doc obligations in the same package: source-authority section 4 gains the
D1 selection order and section 3.1 the search reading with the detached
shoulder, both pointing at plan 7 for grounds; plan section 5's items are
marked implemented at gate 2.

### 8.2 KATs — witnesses first

Mutation KATs pin every closure on real witnesses before any synthetic
case:

- D1 edge witnesses, one per occupied edge (5774294428586859171 land_001,
  1013 land_004, 2147483648 land_007, 172991200114431608 land_010,
  97665215198973151 land_013, 1914891444072834567 land_016): formerly
  multi-complete-rejecting, now compile, and the selected tuple equals the
  projection's winner with its retreat pinned. Plus one elbow-completer
  witness (1959553668008863006, land_010 — the retreat-0 elbow must beat
  the interior direct) and one interior-winner witness
  (12149685678221140862, land_007 — retreat 1 beats retreat 5).
- The benign class does not move: a pinned exactly-one-complete multi-tuple
  witness (seed 1, land_013) keeps its census-recorded selection
  byte-identically.
- D2: all seven witnesses (343674299183575008, 2466379686918096853,
  6071911433535184866, 6692092492332211284, 7403557699456021182,
  7851242355115945264, 15976616440543533625) through the full aperture and
  shoulder resolution: formerly stage-rejecting, now compile; detached
  station recorded; both orders' sweeps green. Mutation side: a synthetic
  two-station detached run and a gap-two configuration must still reject —
  the admission's boundary pinned from both sides.
- O1 computes a positive margin on the authored source; a test-local
  source mutation that moves an attachment into range must fail it loudly.
- W-112 leaves the stage-reject KAT: the census fixture asserting it
  stage-rejects is retired to the v4 record's provenance and the seed
  reappears as a D2 compile witness; the census KAT digest moves
  legitimately and is re-pinned.

### 8.3 Synthetic KATs for D1 order keys 2–6 (gate-1 condition 1)

No measured configuration reaches keys 2–6 — key 1 selects uniquely at all
757 records — and the full-`W` cross-check therefore never exercises them;
only synthetic KATs can pin them. Both comparator implementations run each
case and must agree with each other and with the specified winner:

1. sum tie broken by max component: retreats (1,3) versus (2,2) — (2,2)
   wins;
2. sum and max tie broken by the sorted terminal set: (1,3) versus (3,1);
3. elbow count: identical retreats, differing elbow insertions — fewer
   wins;
4. terminal-set tie broken by the sorted previous set;
5. previous tie broken by canonical probe-byte orientation;
6. equality under keys 4–6 asserts the duplicate-authority reject fires
   first — the order is never consulted on duplicates.

Every case also runs under reversed authored orientation and must select
the same world tuple — the reversal invariance of plan 7.1 as an executed
check, not a stated property.

### 8.4 The compiler reproduction, and its predicted diff

One reproduction, solo compiles through the full compile path (not the
projection): the five census KAT seeds, the six D1 edge witnesses, winner
16178445837170081103 and the seven D2 seeds. Masks and terminals diff
against the committed v4 artifacts. The expectation is **not** untouched
and is stated in advance (plan 7.3, a projection marked as one): terminals
move by one to three stations exactly at the moved-terminal sites the
measurements name — witness seeds among the 2,042 DECIDED interior
completions and the 27 interior multi-complete winners, the winner seed
included — and nowhere else; the seven D2 seeds compile for the first time
and have no v4 rows to diff. A deviation from the predicted set in either
direction stops the package for a recorded Reality correction. The
"touched" outcome discharges into 8.5.

### 8.5 The full-`W` verification fleet and the v5 artifact set (gate-1 condition 3)

One post-correction full-`W` fleet run — the plan-step-2 Scan-3a repeat,
the full-`W` M3↔compiler cross-check and the seven-seed census completion
in a single pass, under the section-6.6 launcher discipline (fan-out at
full width, first-record validation, verified resume, worker-death watch)
and the 2026-08-18 run-cost gates of section 6.5: the CPU-domain intrinsic
and liveness gates with their probe-measured margin and `X`, wall
projection advisory-only, workers under idle scheduling. **The contention
probe runs before this fleet launches** and its measured multiplier is
recorded in the manifest. All under **LuaJIT** per the interpreter split. It starts only after 8.2–8.4 are
green, is announced to the coordinator with its projection marked as such
(the v4 band, 7 h 50 min measured, is the anchor; the R19 selection work
is already in the projection tier, so the marginal cost is expected inside
noise — a projection), and waits for the user's explicit GO (section
6.6.7).

- Schema v5 (`grug_wp40_census_scan_v5`, shards `census-scan-v5-*`): the
  scan2 edge row carries the compile path's selected tuple identity beside
  the projection's, and the worker aborts loudly on any disagreement — a
  mismatch is a finding, never a column.
- The merge publishes the v5 artifacts and manifest under their own
  digest, with provenance naming the post-correction commit, tree and this
  contract. **The committed v4 artifacts are not touched** — they remain
  the census of record for the pre-correction policy; v5 supersedes them
  for every downstream consumer (Scan-3b/4 input sets, the extremal
  roster) and says so in its manifest. The seven returning seeds are
  listed by name in the manifest as first-scanned-post-correction: the
  addendum is a marked table, never a silent merge.
- Their transition-tuple distributions are unmeasured until this run; the
  D1 order is total for any multiplicity, so whatever they realize is
  decided, and any occupancy beyond the measured bounds (completions
  above four, a fresh REJECTED class) is reported as a finding at gate 2,
  not absorbed.
- The PUC merge divergence test rides as in v4; the census stage-reject
  vocabulary stays declared, with the aperture second-run classes expected
  vacuous post-admission and the authored co-occupancy caveat of plan 7.2
  recorded in the manifest.

### 8.6 Gate 2 acceptance (gate-1 condition 2)

Gate 2 is the coordinator's acceptance of, in one list:

1. Static gates green on every Lua change (`luac51 -p`, SETGLOBAL, the
   five grep sweeps).
2. The 8.2/8.3 KAT suite green under LuaJIT, and the targeted PUC set —
   the D1 synthetic key KATs, the seven D2 witnesses, the five census
   KAT seeds, **and at least one full-compile-path D1 witness pair
   (elbow witness 1959553668008863006 plus one multi-complete edge
   witness) compiled solo under PUC and digest-compared against
   LuaJIT** — byte-compared by digest between interpreters. The
   addition is the gate-1.5 condition (2026-08-18): the synthetic KATs
   drive only the comparator under PUC, and the new R19 enumeration
   path needs at least one end-to-end PUC exercise against its
   `pairs()`-order risk. No comprehensive PUC round (reserved for
   T2-final, per the interpreter split in the brief and
   [luanti-lua.md](luanti-lua.md)).
3. The 8.4 reproduction diff matching its predicted set exactly.
4. The 8.5 fleet complete: zero cross-check mismatches, v5 published and
   digested, v4 byte-untouched in git.
5. **The locked-surface control experiment, named:** the six section-3
   files' git blob hashes unchanged, and `run_t2_s1_authority.sh` run
   before and after the correction with the S1 source-projection checksum
   byte-identical — the section-3 projection pin verified, not asserted,
   despite the winner byte diff (winner 16178445837170081103 recompiles
   through R19 with a moved terminal; its scalars must not move).
6. Docs: the 8.1 doc obligations landed; plan section 2 status advanced;
   the section-7 memo markers point at the implemented state.

**Accepted 2026-08-18 (gate 2, coordinator).** `artifacts_digest
37fcdc5e…`. Evidence: `rejected = 0` independently recounted in the v2
artifacts; per-edge accounting closes at 4,123; the seven addendum seeds
verified by name in the manifest; the v4 artifact blobs untouched at
HEAD; the locked-surface diff empty and the S1 control experiment re-run
independently with a byte-identical projection; the static gates re-run
clean. The three pre-existing findings on record — the R18-level C2
conformance oracle at slot 29, the Slot-30 Starbough pin drift, and the
F10 face-simplicity occupancy on wanted seeds 2147483648 and
1959553668008863006 — pass to the next phase's ledger.

### 8.7 Cost, launch discipline, and historical division of labour

Section-4 anchors govern every launch; any run projected over ~30 minutes
wall, and any fleet run, is announced first with the projection marked as
a projection. The semantic core — catalog strings, both comparators, the
shoulder construction, and the source-authority edits — stayed in-session
(Fable). Mechanical parts — KAT plumbing, gate-suite reruns, fleet
babysitting, and the v5 merge — were eligible for Opus subagents (user
authorization 2026-08-18), briefed by goals with a cost cap and a stated
verification tier. Parallel Lua processes stay within the host's measured
eight-worker band.

## 9. The Scan-3b/4 census completion contract (cut 2026-08-18)

This contract implements plan section 2 step 3: **Scan-3b**, the sixteen
transition-incident Bank traces, and **Scan-4**, Face/Whole on the
flagged, extremal and winner seeds — both on the corrected tuples the
collected correction produced. Its baseline is the v5-schema/v2-name
artifact set of section 8.5 (`artifacts_digest 37fcdc5e…`, gate 2
accepted 2026-08-18), which supersedes v4 for every downstream consumer.
This is a **measurement phase, not a correction phase**: the scanners
classify by decided policy (section 6.6.6, the R15 stance), findings are
measured occupancies, and nothing is promoted without occupancy evidence.
Plan section 2 accepts **at most one small correction round after
Scan-3b**, its candidate classes already named (R20/R21, section 9.1);
if any is warranted it opens as a section-7-style decision memo after the
run, never as an inline fix. Heavy regime wherever boundary topology is
touched (section 1.1); the six locked files of section 3 are untouchable,
and a needed arithmetic primitive is an escalation. A genuinely undecided
semantic question found during implementation is a recorded escalation,
not an inline decision — section 9.2 carries this contract's one open
instance.

### 9.1 Scope and measurands

**Scan-3b** evaluates, per seed over the full `W`, the sixteen
transition-incident Banks the v2 seed-set artifact names as its open
roster rows — per Bay four of the five chain components: elandor_east
{dawnmere, goldmead, silverleaf, starbough}, elandor_west {copperfell,
dawnmere, goldmead, hearthpine}, kragmar_east {kapok, raincall, redtusk,
sunscar}, kragmar_west {mournfen, redtusk, stillgrave, sunscar}. Each is
traced once, materialization-style, from the terminals of the **selected**
joint tuple (the v5 cross-check proved compile and projection agree on
that selection over all of `W`) with the head-Bank observer
instrumentation of census_scan3a: outcome class from the existing
`scan3_bank_class` vocabulary, per-step and per-selection class coverage
rows, step count, branch count, and the reachability frame and stack
maxima. The two per-Bank scalars fill the sixteen open extremal-roster
sites, closing the 153-site roster of section 6.2.3. Consistency
discipline, the 8.5 pattern: Scan-2's completion tier already proved
these Banks complete at the selected tuple, so an instrumented trace that
dies is a **loud worker abort — a finding, never a column**.

Beside the traces, Scan-3b adds the **bank-incomplete attribution
histogram**: for every `scan2_tuple_bank_incomplete` tuple failure, which
incident Bank died and the kind and mode of its far terminal (direct
aperture, tail aperture, wing side). That attribution is the direct
measurement substrate for the two predicted classes, declared here so
occupancy has a place to land:

- **R20 candidate — `aperture_anchor_dead_event`** (site: aperture
  incidence). Fires when every tuple of an edge fails with the same
  aperture-far Bank dead while that incidence resolved **direct** —
  candidate `D`, the completeness analysis 3-F3 residual. The tail-mode
  variant is R18's own recovered class and is not this event.
- **R21 candidate — `wing_pair_dead_alternative_event`** (site: Wing).
  Evaluated wherever a Bank with a Wing far terminal dies at the selected
  wedge-valid pair — the sixteen via all-tuples-dead, the four head Banks
  via their Scan-3a trace — and fires only if re-tracing under the next
  wedge-valid pair completes. The alternative-pair probe runs **only** on
  the dead condition, so its cost is occupancy-driven.

Expected occupancy of both: **zero** — a projection, marked as one,
grounded in the v5 measurement that `scan2_zero_complete_reject` and
every head-Bank reject class read zero over `W`, which is the edge-level
manifestation both events would force. Nonzero occupancy of either is
exactly the named small-correction-round trigger of plan section 2.

**Scan-4** evaluates, per seed of the input set (9.2), two tiers on the
same stage build:

- **The face tier** composes all 38 zone-face polygons from the
  materialized Banks, arcs and final edges and classifies each face —
  the stage-reject precedent: classification per fail site through a
  message map beside the projection, anything unmatched re-raised —
  under `scan4_face_class`: `face_simple_select`,
  `face_not_closed_reject`, `face_wrong_orientation_reject`,
  `face_non_simple_reject`, `face_composition_reject` (a component or
  join failure at composition, before the polygon predicates run; a face
  whose upstream arc failed is its own declared skip kind, not a silent
  absence). The known F10 occupancy is this tier's first customer and its
  sites are now measured, not seed-level: solo full-path compiles
  (2026-08-18, this cut) place seed 2147483648 at
  `zone_face:elandor_silverleaf_glades is not simple` and seed
  1959553668008863006 at `zone_face:kragmar_stillgrave_hollow is not
  simple`. Both must land as occupied `face_non_simple_reject` rows with
  those witnesses — a crash on either is an implementation defect by
  definition.
- **The Whole tier** runs only when every face of the seed classifies
  `face_simple_select`; otherwise it emits one `whole_not_evaluated` row
  naming the blocking face — "measured" and "could not be evaluated" stay
  different claims (the 6.7 lesson). When it runs: the exhaustive
  row-run partition of the H38 method — normalize the closed final
  polygons into integer row runs, partition every footprint row at all
  run boundaries, classify each interval — under `scan4_whole_class`:
  `whole_single_owner_select`, `whole_declared_seam_select`,
  `whole_gap_reject`, `whole_undeclared_multiplicity_reject`, with the
  per-seed g/o/r/m summary counts recorded beside the class rows. The
  excluded-fragment obligations classify under `scan4_fragment_class`:
  `fragment_owned_once_select`, `fragment_unowned_reject`,
  `fragment_multi_owner_reject`, `fragment_identity_conflict_reject`.

F10/F11 are verification families: they decide nothing, so every
occupied REJECTED row here is a finding for the ledger — the two known
F10 seeds are the expected occupancy, anything else is new — and what to
do about any of them is a post-run decision memo, never an inline fix.
Everything the v5 pass aborts on still aborts; the new tiers' internal
invariants (an exact-validation failure inside a face polygon, a row-run
normalization that loses columns) abort loudly rather than classify.

### 9.2 The Scan-4 input set: the 3,061 → 3,058 answer, and one escalation

Answered from the artifact rows, not assumed. Between
`census-scan4-seed-set-v1.tsv` and `-v2.tsv`: **three seeds left, none
entered.** The departed are 2466379686918096853, 6071911433535184866 and
15976616440543533625 — three of the seven D2 seeds — whose v1 membership
was solely `flagged: stage_reject:bay_mouth_aperture:elandor_east`; the
v5 census measures that class empty (`stage_reject_seeds=0`), and their
post-correction records realize no other flag, no extremal bound, no
winner and no corpus slot. The flagged term moved 3,013 → 3,010; the
extremal (127), winners (4) and corpus (27) terms are unchanged. The
other four D2 seeds stay on their own post-correction evidence:
343674299183575008 via two `two_or_more_candidates` flags **and** an
extremal witness slot (`land_004:from success_count maximum 4`, taken
from 785869122509563282 by the least-seed tie at an equal bound — the
one extremal row that moved, 471 of 472 identical), 6692092492332211284
and 7403557699456021182 via `multi_interval` plus candidate flags, and
7851242355115945264 via `fills` plus three candidate flags. The `open`
(sixteen Banks) and `excluded` (Holy band) rows are unchanged.

**The one undecided semantic question of this cut — escalated
2026-08-18, ruled 2026-08-19 (below).** All three departed seeds carry the
detached-shoulder admission (the v2 manifest lists all seven by name;
histogram `scan3_aperture_detached`, 5 + 2 across two stations) — at
7 of 4,123 the **rarest occupied configuration over `W`** — yet it
confers no flag, because the flag vocabulary predates the class the
correction created. Two decided authorities pull apart: section 8.5 makes
the v2 artifacts authoritative for the Scan-4 input set (3,058), while
the 2026-08-17 stage-reject decision's recorded rationale ("post-
correction they are exactly the stressed geometry Scan-4 exists to look
at") and the flag rule's own principle ("any rare class occupied") both
argue the seven belong in it. Recommendation: admit
`detached_shoulder_admission` into the flag vocabulary (branch A) — the
union returns to 3,061, the v3 artifact records the amended term, and the
vocabulary hole closes for good; the alternative (branch B) keeps the v2
union at 3,058 and records the three seeds' absence as a named
consequence. Implementation is not blocked — membership is an input list
either way, read from the committed v2 artifact by digest (`a7f4ab91…`)
plus, under branch A, the manifest's admission seeds — but **the fleet
does not launch before the ruling**, which the announcement pre-flight
consumes and this section records when it lands.

**RULED 2026-08-19: branch A** (coordinator, user-confirmed).
`detached_shoulder_admission` enters the flag vocabulary as an
occupied-rare-class flag; the Scan-4 union returns to **3,061** and the
flagged term to 3,013. The consumed membership is the committed v2
seed-set artifact by digest (`a7f4ab91…`) plus the v2 manifest's seven
admission seeds — re-admitting exactly the three departed D2 seeds; the
other four are already members on their own flags, so no other term
moves. The v3 artifacts record the amended flagged term and this ruling
(section 9.3), and the vocabulary hole closes for good. The 6.6.7 fleet
gate is no longer blocked on this section.

**The roster top-up protocol.** Scan-3b's sixteen sites produce up to 64
new extremal bounds whose witnesses may sit outside the consumed
membership. The merge computes that pending list from its own
aggregation and **refuses to publish while it is nonempty**: a marked
top-up run (worker seeds-mode, Scan-4 tiers forced on, its own
provenance) supplies the missing records, and the second merge invocation
consumes shards plus top-up records and publishes once. One publication,
complete coverage, no addendum artifacts.

### 9.3 Schema and artifact naming

Record schema **v6** (`grug_wp40_census_scan_v6`), the v5 rows an exact
prefix as every version before it; new row kinds for the Scan-3b Bank,
step-coverage and attribution rows and the Scan-4 face, whole, fragment
and membership rows, each with declared columns and site rosters in the
authority. The full pass recomputes the v5 tiers — the stage build they
need is paid anyway — so the merge rebuilds **all** artifacts from its
own shards under one provenance, and asserts that every inherited-tier
occupied-class row equals its v2 counterpart outside the header block: a
drift there is a finding, not a refresh. Shards are
`census-scan-v6-%04d-%04d.tsv` under the gitignored results directory,
collision-checked in code against every earlier census and pool pattern;
the v4 and v5 shards stay untouched on disk as the prior records.
Artifacts publish as `census-*-v3.tsv` plus
`grug_wp40_census_manifest_v3` beside the untouched v1 and v2 sets —
**new artifact files carry the next free version suffix and a committed
artifact name is never reused** (the dd09917 lesson, one commit old, now
a stated rule). v3 supersedes v2 for every downstream consumer and its
manifest says so, names the consumed v2 baseline by digest, the ruling
of 9.2, and the top-up seeds (if any) as a marked table.

### 9.4 KATs — witnesses first

The worker KAT grows from five seeds to seven: the census five (0,
343674299183575008, Slot 30, Slot 29, max-u64) plus the two F10 seeds
2147483648 and 1959553668008863006, inserted in sorted place; record and
merge digests move legitimately and are re-pinned.

- **Scan-3b witnesses.** Per KAT seed the sixteen Bank rows pin outcome
  class, step count, frame/stack maxima and step-class coverage — the
  analysis's 453–794-step / ≤ 24-frame band came from these Banks and
  now gets per-seed pins instead of a prose range. Slot 29's
  R19-genesis tuple (dead direct terminal, bank-incomplete) pins the
  attribution histogram: which Bank, which far kind and mode.
- **Scan-4 witnesses.** The two F10 seeds pin `face_non_simple_reject`
  at their named faces and `whole_not_evaluated` naming those faces; a
  quietly-simple result on either means the finding vanished and fails
  the KAT (the W-112 precedent) until a recorded correction moves it.
  Seed 0 and max-u64 pin all-38-`face_simple_select` and the Whole
  summary `g=o=r=m=0`, the H38 feasibility result now pinned per seed;
  W-112 pins its admission row, multi-complete selection and green
  Scan-4 tiers in one record. **Amended 2026-08-19, measured:** the
  W-112 green-tier projection is refuted — seed 343674299183575008
  realizes `face_non_simple_reject` at both
  `zone_face:elandor_dawnmere_fields` and
  `zone_face:elandor_silverleaf_glades`, with the consequent
  `whole_not_evaluated`/`fragment_not_evaluated` rows,
  compile-confirmed solo (ba37b96); the KAT pins that measured truth,
  and the admission-row and multi-complete-selection pins stand. The
  finding is new F10 occupancy for the ledger under 9.1; whether
  anything follows from it is the post-run decision memo's question,
  decided on the fleet's full-membership F10 measurement, never inline
  (coordinator ruling 2026-08-19).
- **Synthetic cases only where no measured configuration reaches the
  branch.** R20/R21: descriptor-driven classifier cases — an
  all-tuples-dead-direct-anchor descriptor must classify
  `aperture_anchor_dead_event`, a dead selected pair with a completing
  alternative must classify `wing_pair_dead_alternative_event`, a dead
  pair with no alternative must stay a plain attribution row. Face tier:
  synthetic not-closed and wrong-orientation polygons (non-simple has
  real witnesses). Whole tier: synthetic gap, undeclared-multiplicity
  and declared-seam interval sets through the row-run classifier.
- **Interpreter split (the standing rule).** The fleet runs LuaJIT
  (`WP40_LUA_BIN`, idle scheduling). PUC 5.1 is targeted KATs
  byte-compared by digest, with **at least one full-path witness per new
  tier**: one full v6 worker record for 2147483648 (Scan-3b plus the
  face tier through a real non-simple classification) and one for winner
  16178445837170081103 (Scan-3b plus green face and Whole tiers),
  LuaJIT/PUC digest-identical; the synthetic classifier KATs run under
  both interpreters; the merge keeps its LuaJIT/PUC artifact-identity
  gate. No comprehensive PUC round — that is T2-final's.

### 9.5 Cost plan — measured probes, then the conf, then the split decision

Anchors on record: the v5 full pass measured **58.33 CPU-s/seed** at its
last rolling evaluation (8 h 22 min wall observed at eight workers); the
winner's v5 solo pass is the current conf's **45.10 CPU-s** anchor; the
sixteen uninstrumented completion traces cost ~0.15 s inside M3's tuple
tier; the observer's branch-probe budget is 64 per Bank. None of these
covers the new tiers, so nothing launches on them alone.

**Probe protocol, before any fleet.** Solo v6 passes on: seed 0
(member, control), both F10 seeds (member, face tier fails, Whole
skipped), winner 16178445837170081103 (member, R19-heavy, green Whole —
the expensive shape), and one non-member seed (Scan-3b marginal without
Scan-4). Reported per seed: total CPU against the v5 anchor, and the
per-tier split (3b marginal; face marginal; Whole marginal). **Then**
`run_t2_census_probe.sh`, extended to the v6 tiers with members among
its probe seeds, regenerates `census-cpu-gate.conf` under one busy loop
per logical CPU — anchor (worst solo v6), margin (worst ratio, rounded
up), liveness `X` (ten times the worst loaded seed) — all re-measured,
never carried over: the launcher refuses a conf older than its own
commit, and the per-seed cost changes with the new tiers.

**One fleet pass or two — the criterion, decided from the probes.**
Default is **one pass** (v5 tiers + Scan-3b on every seed, Scan-4 on
members): the stage build (~20–27 s) dominates the per-seed cost, and a
separate Scan-4 fleet would pay it a second time on ~3,060 seeds —
roughly three hours of wall at eight workers for nothing. The split is
re-decided at the pre-flight only if the probes show the Scan-4 marginal
exceeding the whole v5 per-seed band — the point where one mixed pass
more than doubles the per-seed cost and the CPU budget's
pathology-versus-expensive-tier separation thins. The announcement
states the decision with the probe table, the regenerated conf values,
and the wall projection **marked as a projection** (advisory; the v5
band 8 h 22 min plus the probed marginals is the anchor). Merge memory
clause: the divergence test's measured-invariance half runs where the
records fit in memory twice; v6 records are larger than v5's 96 MB, the
probe states the factor, and the manifest records what ran.

### 9.6 Runner obligations

The section-6.6 launcher discipline is inherited whole: full-width
fan-out, first-record validation, verified resume, worker-death watch,
GO token (section 6.6.7 — the fleet starts only on the user's explicit
GO after the announcement pre-flight), and the 2026-08-18 CPU-domain
gates with wall advisory-only and idle scheduling.

**Two launcher-hygiene fixes landed before the fleet** (run-5 observations,
gate-2 handover; both were Opus-delegable and neither changed gate semantics):

1. `fleet_cpu_seconds` stops reading `/proc/<pid>/stat` for reaped
   workers — run 5 measured 956 harmless stderr lines from exited-worker
   polls (the redirection order lets the shell's own error through). The
   sum's under-report-only semantics are unchanged.
2. The cost/CPU projection log throttle gains a periodic re-emission
   (every 30 minutes of silence) — run 5 emitted its last projection
   lines in the run's first minutes and the babysitter flew 8 hours on
   the cost-note file alone. The note file's behavior is unchanged.

The merge re-verifies Scan-4 coverage against the consumed membership —
every member seed carries the Scan-4 block, no non-member does — and the
manifest pins the membership source by digest beside the 9.2 ruling.
**Amended 2026-08-19 (ruled at the gate-3 review):** the 9.2 top-up
seeds carry the Scan-4 block by construction while sitting outside the
consumed membership, so the re-verification's universe is the recomputed
v3 union — consumed membership plus top-up seeds — and the manifest
records both terms (run 6: `scan4_coverage members=3076 of
consumed_union=3061`, 15 top-up seeds, all pure extremal-term winners).
Item 5 of 9.7 ("Scan-4 coverage equal to the ruled membership") reads
accordingly; the merge behaved as 9.2 requires and no equality between
the two terms is asserted.

### 9.7 Acceptance checklist (gate 3)

Gate 3 is the coordinator's acceptance of, in one list:

1. Static gates green on every Lua change (`luac51 -p`, SETGLOBAL, the
   five sweeps — run explicitly for `tools/`).
2. The 9.4 KAT suite green under LuaJIT; the targeted PUC set — both
   full-path v6 witnesses digest-identical to LuaJIT, the synthetic
   classifier KATs — green; no comprehensive PUC round ran.
3. The 9.2 ruling recorded and implemented as ruled; the seed-set
   answer's numbers re-checkable from the committed artifacts.
4. The probe table and regenerated conf on the committed-measurement
   standard, the one-/two-pass decision stated from them at the
   announcement, and the launcher-hygiene pair verified on the fleet log
   (zero dead-worker `/proc` lines; periodic advisory lines present).
5. The fleet complete under the CPU-domain gates: Scan-3b coverage
   4,123/4,123, Scan-4 coverage equal to the ruled membership, zero
   Scan-2↔3b trace disagreements, the top-up (if any) consumed before
   publication.
6. The v3 artifacts and manifest published under their own digest,
   LuaJIT/PUC byte-identical; the v1/v2 artifacts and v4/v5 shards
   byte-untouched; the inherited-tier regression assertion green; the
   153-site roster covered 153/153.
7. Findings reported as findings, each with site, class, witness seed
   and verbatim row: the R20/R21 occupancies (zero or named), the F10
   measurements over the full input set including the two expected
   witnesses, and anything new. Any warranted correction round is opened
   as a section-7-style decision memo — its candidate classes were named
   in advance — never applied inline.
8. Docs: the vacuous-branch `out_of_scope_scan3b` status retired by
   measurement, plan section 2 step-3 status advanced, the README census
   section carrying the v6 mechanics.

**Gate 3 accepted 2026-08-20** (coordinator review, user-signed): all
eight items verified. Evidence trail: ba37b96 (implementation and
suites), 4d21477 (probe and conf), `run6.log` (fleet and the hygiene
pair at scale), 060614b (v3 publication, `artifacts_digest 2433d6f6…`),
590ce99 and 7e0c05e (the 9.2 and 9.6 rulings), c9b6f79 (the section-10
memo), 6670e66 (the item-8 docs). The Scan-3b/4 census completion is
closed; what follows from its findings is section 10's
bay-transition-simplicity package.

### 9.8 Cost, launch discipline, and historical division of labour

The semantic core stayed in-session (Fable): this contract, the Scan-3b
attribution and R20/R21 classifiers, the face and Whole classification
semantics, the class vocabularies and their verdicts, and the
consistency rules. Mechanical parts went to Opus subagents under the
standing split (user authorization 2026-08-18), briefed by goals with a
cost cap and a stated verification tier: the launcher-hygiene pair, KAT
and gate-suite plumbing, the probe-script extension, fleet babysitting,
and the v3 merge run. Section-4 anchors plus the 9.5 probes govern every
launch; any run projected over ~30 minutes wall, and any fleet run, is
announced first; runs over ~8 minutes run detached; parallel Lua stays
within the measured eight-worker band.

## 10. The Scan-3b/4 post-run decision memo (cut 2026-08-20)

Section 9.1 reserves the disposition of the run's findings for a
post-run decision memo in the section-7 style; this is it. Ruled
2026-08-20 (coordinator, user-confirmed 2026-08-19/20). Baseline: the
v3 artifact set of run 6 (`artifacts_digest 2433d6f6…`, 060614b).

### 10.1 What run 6 measured

- **R20/R21: zero over `W`.** The plan-section-2 small-correction
  trigger did not fire; **no census-side correction round opens.** The
  attribution histogram (2,338 rows) never realizes a `wing` far
  terminal — 2,301 `aperture/direct` plus 37 `aperture/diagonal_shoulder`
  — so R21's dead condition never arose and R20's all-tuples-dead edge
  never occurred.
- **`face_non_simple_reject`: 796 of 3,076 Scan-4 members (25.9%)**,
  858 face rows at 10 of the 38 zone faces. **`whole_gap_reject`: 370**
  of the 2,280 evaluated Whole tiers. **`fragment_unowned_reject`: one
  seed** (7334446403956696166, land_013). Every other REJECTED class of
  the new tiers is vacuous over `W`.
- **All four winners are clean on every Scan-4 tier**
  (5270046902118333881, 15219119262482319357, 16178445837170081103,
  17842018860885445630): the world-foundation deliverable is not
  blocked by any finding.

### 10.2 Localization evidence (2026-08-20, from the published rows)

- Every non-simple seed carries at least one transition flag; unflagged
  members (extremal/winner/corpus-only) never fail — 0 of them.
- The 10 occupied faces are all bay-chain zones (10 of the 12
  bay-component zone names; the 26 non-bay faces are clean over all
  3,076 members). The plain jittered land boundaries compose to simple
  polygons everywhere measured; the defect lives in the bay-transition
  machinery composed into the face rings.
- Conditional failure rates against the 25.9% base:
  `detached_shoulder_admission` **7/7 = 100%** — a deterministic
  reproducer class: seeds 343674299183575008, 2466379686918096853,
  6071911433535184866, 6692092492332211284, 7403557699456021182,
  7851242355115945264, 15976616440543533625, all at
  `bay_mouth_aperture:elandor_east:after` on only two distinct stations
  (1227:-2928 and 1270:-2929). `two_or_more_candidates` carriers 34.6%;
  tail_mode 17.5%, fills 19.8%, multi_interval 21.9%, fragment 12.4%.
- The `whole_gap_reject` intervals cluster in two z-bands
  (≈ −2030…−2090 and ≈ −2540; peaks of 40 seeds each at z=−2033 and
  z=−2054) — a small number of concrete seam geometries, unattributed.

### 10.3 Ruling

1. **The census closes as a measurement.** Nothing in the census
   machinery is corrected; the v3 artifacts stand; gate 3 proceeds
   against 9.7.
2. **Design intent recorded** (user, 2026-08-19): the boundary
   machinery is meant to guarantee a valid world for every seed of `W`
   — long-term, for arbitrary seeds. The measured occupancy is a
   **broken guarantee**, not an accepted property.
3. The findings open **one named follow-up correction package —
   bay-transition simplicity** — outside the census's scope, with this
   plan: (0) verify whether the production compile refuses ownership
   gaps the way it demonstrably refuses non-simple faces — the safety
   net until correct-by-construction; (1) an instrumented ring probe on
   the detached-shoulder reproducers: dump the composed face stations,
   report the self-intersecting segment pair and each segment's
   contributor (authored edge, Bank trace, arc); (2) extend the probe
   over a sample of the `two_or_more_candidates` failures and classify
   the defect kinds; (3) attribute the `whole_gap` z-clusters to their
   seam geometries, the fragment singleton alongside; (4) fix design
   toward the recorded intent, with the census KATs and the published
   witness lists as the regression harness. Every step is solo-scale:
   a witness compiles in ~35–60 s and the 796/370/1 witness lists are
   on disk — **no fleet run is needed for any debugging step.**
4. The analysis-era step/frame prose band (453–794 steps, ≤ 24 frames)
   is retired in favour of the published per-site pins (steps 443…931,
   frames 0…927; no cap class fired).

## 11. The bay-transition fix design memo (step 4, cut 2026-08-20)

The 10.3 diagnosis plan is complete — steps 0–3 plus the 2b coverage
closure, five reports on disk
(`tools/wp40/results/bay-transition-step{1,2,2b,3}-report.md`, probe
commits 64eb3ec/36c9536/1ad5868). This memo is the step-4 design
decision in the section-7 style: the measured ground, the branches,
one recommendation per question, and the acceptance plan. The ruling
lands at the end of this section when it lands. The recorded design
intent it serves (10.3 item 2): the boundary machinery guarantees a
valid world for every seed of `W` — long-term, for arbitrary seeds.

### 11.1 The measured ground, compressed

Two defect families, both living **between** locally-correct
authorities at jittered margins; no third mechanism appeared in 95
recomposed violations (faces) and 34 attributed intervals (gaps):

- **Corridor doubling** (face_non_simple_reject, 796 seeds, 10 faces):
  a Bank trace and its ring neighbour retrace the same stations in
  opposite directions at the **bay-transition terminal** — Bank ×
  retained transition edge (84 measured) or Bank × perimeter span at a
  direct aperture (11 measured), in either ring orientation, interior
  and wrap-around joins alike. Never at an ordinary junction terminal
  (49 of 49 Bank↔ordinary joins clean), never involving an ordinary
  edge, arc or island, never an X-cross. Each colliding part obeys its
  own authority; no rule assigns the shared corridor.
- **Margin pockets** (whole_gap_reject 370 seeds, fragment_unowned 1):
  1–15-column raw-dry pockets at the capsule/jitter knife-edge,
  seaward of the Bank, owned by **nobody** (0 of 55 probed columns
  carry any contributor station). Water says raw-dry correctly, the
  §7.1 notch fill cannot reach them by construction, the Bank cannot
  (simple dry path), the face is Bank-bounded. The authored geometry
  fixes which columns are marginal; the seed only decides dryness. The
  fragment singleton is the same mechanism on a fragment station and
  is the one family member production refuses today.

Production today: non-simple faces and the fragment singleton abort a
compile; the 370 pure gap seeds **compile to completion** (no footprint
coverage check in compile_impl — the step-0 hole). All four winners are
clean in both families.

### 11.2 Question 1 — who owns the doubled corridor (faces)

- **Branch 1a — restrict the trace.** Forbid the Moore candidate rule
  from span/edge-owned stations near terminals. Rejected on the
  measured evidence: at a detached-shoulder admission the corridor is
  the **only** dry approach (that is what 7/7 = 100% measured), so the
  restriction converts composable geometry into trace failures — it
  widens the invalid-seed set the intent says must shrink. Blast
  radius: every Bank trace over `W`, all trace KATs, the census's
  measured extremal roster.
- **Branch 1b — trim the neighbour.** Trim the retained edge / span at
  composition input to where the Bank leaves the corridor. Sound
  outcome, but the trim rule needs per-orientation, per-join-kind
  cases (2b measured both orientations and the wrap-around join), and
  it edits the *inputs* of composition while leaving the actual
  invariant ("the ring passes once") implicit.
- **Branch 1c — deduplicate at the join (RECOMMENDED).** One narrow
  composition rule at every part join, interior and wrap-around: when
  the tail of one part and the head of the next retrace the **identical
  station sequence in reverse**, collapse the retraced sub-path to a
  single traversal. The ring then walks the corridor once; the corridor
  stations stay on the face boundary; trace, edge and span authorities
  keep their measured geometry untouched. **Guard, non-negotiable:** the
  rule fires only on exact reverse-retrace at a join; any repeated
  station that survives it still fails `validate_face_polygon` loudly —
  the fix must not become a blanket simplifier that hides future
  defects. Rationale: it is the smallest rule that states the broken
  invariant where it lives (between parts, at the join), it covers both
  measured pairings and both orientations by construction, and the
  R19-selection alternative is rejected as a fix (per-case luck; does
  not cover Shape A; changes selection semantics measured over `W`).

### 11.3 Question 2 — who owns the margin pockets (gaps + fragment)

- **Branch 2a — extend faces to the water contour.** Faces stop being
  Bank-bounded; the largest authority change, touches every face and
  the Bank's meaning. Rejected as disproportionate.
- **Branch 2b — strengthen the notch fill.** Generalize §7.1 until it
  reaches interior holes and multi-column pockets; grows a special-case
  rule into a shape grammar, still per-shape, still falsifiable by the
  next pocket shape. Not recommended.
- **Branch 2c — connectivity closing in the mask (RECOMMENDED).** One
  constructive rule at raw-mask build: a raw-dry column that is not
  dry-4-connected to the Bank-side mainland becomes planned water.
  Isolated holes and diagonal chains close identically; the fragment
  singleton is fixed by the same stroke (its column becomes water, the
  fragment ends on the shore as designed); the §7.1 notch rule is
  subsumed or stays as a fast path. This states the actual intent —
  bay water is the connected wet region, dry noise at its margin is
  water — instead of enumerating pocket shapes.
- **Plus, regardless of branch: the production Whole gate.** compile_impl
  gains the footprint-coverage check the census already performs
  (step-0 hole closed) — defense in depth so any *future* between-
  authority residue aborts loudly instead of shipping unowned columns.

### 11.4 Acceptance plan for the bay-transition fix

Section 11.5 supersedes this plan in part; item 5's T2-final deferral remains
live.

1. Heavy regime, Fable, in-session semantic core; the six locked files
   stayed untouchable (the mask build and composition live in
   partition.lua, which is not locked; exact.lua's stadium test is not
   edited).
2. KAT re-pins are expected and legitimate **as a recorded
   correction**: the F10 witnesses become `face_simple_select`, the
   gap/fragment pins move — each move named in the commit, the
   W-112-precedent discipline (a quietly-changed pin is a defect).
3. Targeted witness re-run as the acceptance measurement: the 1,166
   witness seeds (796 ∪ 370 ∪ 1, the published lists) solo-compiled at
   the fix — projected ≈ 2.5–3 h wall at eight workers on the measured
   60–70 CPU-s/seed band, marked as a projection. Expected: zero
   `face_non_simple_reject`, zero `whole_gap_reject`, zero
   `fragment_unowned_reject`, zero new reject classes.
4. **Winner invariance, byte-level:** all four winners were clean in
   both families, both rules are no-ops on clean geometry, so their v6
   worker records must reproduce **digest-identical** at the fix. A
   moved winner digest is a stop, not a re-pin.
5. The full-`W` re-census (schema v7 / artifacts v4) is **deferred to
   T2-final** and rides its comprehensive PUC round; the targeted
   re-run plus the winner invariance is this fix's acceptance evidence.
6. Findings discipline unchanged: anything the fix surfaces beyond the
   two families is a finding for a new memo, never an inline decision.

**RULED 2026-08-20** (coordinator, user-confirmed): **branch 1c**
(join deduplication with the loud-guard clause) and **branch 2c**
(connectivity closing at raw-mask build), plus the production Whole
gate of 11.3, in one fix package under the 11.4 acceptance plan. The
published v3 census artifacts stay untouched as run 6's historical
record — the KAT fixture is the only pinned-truth file that moves, as
a recorded correction; the new measured truth over `W` lands at
T2-final's re-census. The implementation was assigned as a heavy-regime
semantic core in a Fable session; the witness re-run of 11.4 item 3 was its
own task.

**Branch 1c REFUTED BY MEASUREMENT 2026-08-20 — implementation STOP,
honoured** (the stop report is
`tools/wp40/results/bay-transition-fix-stop-report.md`; no commit was
made, the pre-fix winner digests are banked there). Measured over the
95 preserved violations: only 43 are anchored exact reverse-retraces
at a join; **52 are offset, wiggle-interleaved or single-station
touches** — including both F10 witnesses, whose pins the acceptance
requires to turn green — so 1c as worded cannot meet 11.4.
Independently, the collapse semantics is underdetermined: unique-
station eight-connectivity forces the join terminal (and, at Shape A,
the admitted station) **off** the ring in every collapse, contradicting
11.2's "corridor stations stay on the face boundary" and creating
candidate unowned columns the new Whole gate would abort on. The 1c
half of the ruling is suspended; a re-design memo (11.5) decides the
corridor question. **The 2c half and the production Whole gate are
untouched by this refutation** — and **ruled 2026-08-20
(user-confirmed): they proceed decoupled** as their own package (the
gap family only: closing, gate, the gap-side KAT re-pins, the
371-witness re-run and the winner-invariance check against the banked
digests), accepting two re-pin rounds as the price of pace. The
corridor family waits on 11.5.

### 11.5 The corridor re-design memo (cut 2026-08-20)

Evidence base: the read-only investigation of 2026-08-20
(`tools/wp40/results/bay-transition-11-5-investigation.md` — the
consumer map, the validator semantics, and the candidate measurements
over the 95 preserved violations; its dump union reproduces the
published counts exactly). The ruling lands at the end of this section
when it lands.

**The decisive measurements.**

1. Outside `validate_face_polygon` itself and the payload no live
   consumer reads (the engine entry is unwired), **every downstream
   consumer needs only the enclosed column region** — the Whole
   classifier core, both fragment seams and the seam table already
   consume regions or part lists, never the ring; the authored oracle
   policy is itself column-phrased.
2. **Every measured violation is join-local (≤ 6 stations, W=8
   provable) and every probed corridor is a zero-width appendix** — a
   1-column filament of the face region that a unique-station
   eight-connected ring cannot carry, which is the whole defect.
3. **Any collapse orphans columns as its steady state**: even the
   strongest complete collapse rule (valid 74/74 with unique minimal
   repair) drops all 74 join terminals plus 254 dry columns strictly
   outside every collapsed face; 71 of 91 dropped clusters stay dry
   under the 2c closing — Candidate A manufactures the gap-family
   defect the same package's Whole gate enforces against, and its
   complete form needs an ownership companion that is Candidate B in
   disguise. Collapse-variant choice is additionally underdetermined
   on 36 of 74 joins (different valid collapses drop different
   columns). Trim-at-input (1b) inherits the same case analysis with
   less information; per-station dedup keeping J is valid nowhere
   (0/73).

**Branches.**

- **11.5-A — complete collapse hybrid (V1 + copy-retention).** Kills
  all 95, join-local, unique repair — and orphans every join terminal
  by construction. Requires an ownership companion for the dropped
  columns; refuted as a standalone by measurement 3.
- **11.5-B — region as the canonical form everywhere.** Row-runs
  become the face's representation, the ring demoted everywhere.
  Correct by measurement 1, but the widest blast radius (payload
  schema bump, byte-pinned fixture, every path consumer) for no
  additional correctness over 11.5-C on the measured family.
- **11.5-C — window-guarded appendix acceptance (RECOMMENDED).** The
  composition and the stitched ring stay byte-identical. The validator
  becomes two-tier: the existing linear simplicity proof is the
  **fast path** — clean geometry, including all four winners, is
  untouched byte-for-byte; on repeated stations the ring is accepted
  **only** if every repeat is a zero-width, join-local (W=8) appendix
  — each condition checked and failed **by name** (the loud guard: a
  non-join-local or non-zero-width repeat, or any opposing diagonal,
  still aborts — nothing outside the measured family is absorbed).
  The face's region truth is then derived by winding (the primitives
  require closure, not simplicity; measured well-defined on all 73
  raw rings, retaining all 343 corridor columns — **no orphan
  columns, no ownership companion, the footprint proof stays
  satisfiable**). The Whole-tier preparation gains the repeat-tolerant
  winding row derivation (classifier core untouched); the fragment
  seams are unchanged; the oracle gains the same two-tier acceptance
  and winding normalization; `exact.lua` is not edited.
  Vocabulary: an accepted-with-appendix face classifies as a **new
  DECIDED select class `face_appendix_select`** carrying the appendix
  station count — measured different things stay different claims —
  and 11.4 item 2 is amended accordingly (the F10 pins move to
  `face_appendix_select`, not `face_simple_select`). W=8 and the
  zero-width condition are pinned in the authority with their
  measurement provenance. Known honest costs: two validation regimes
  to keep honest; the oracle rewrite; the docs statements "the face
  polygon is simple" amended under the recorded-correction
  discipline.

**Acceptance plan for the corridor package (supersedes the face half
of 11.4):** static gates; census gate suite; KAT suite with the
re-pins named old → new (F10 pins → `face_appendix_select` with
appendix counts); PUC full-path witnesses re-pinned digest-identical;
**negative tests for the guard** (a synthetic non-join-local repeat, a
non-zero-width repeat and an opposing diagonal each fail by their own
name); winner invariance byte-level against the banked digests (STOP
condition — winners ride the fast path); the 796-witness re-run with
zero face rejects, zero `whole_gap_reject` from appendix columns and
zero new classes; oracle suite green. The full-`W` re-census stays at
T2-final.

**RULED 2026-08-20** (coordinator, user-confirmed): **branch 11.5-C**,
window-guarded appendix acceptance, exactly as cut — the stitched ring
stays byte-identical, the two-tier validator with by-name loud
failures, region truth by winding, the new DECIDED class
`face_appendix_select`, W=8 and the zero-width condition pinned with
their measurement provenance, the oracle rewrite and the docs
corrections in scope. Sequencing: the corridor package lands **after**
the decoupled 2c gap-family package, on its commit as base; its
796-witness re-run is the acceptance measurement, and the
winner-invariance STOP condition carries over unchanged (the banked
digests remain the baseline — 2c is a measured no-op on the winners).

### 11.6 The 2c refutation, and the residue question (recorded 2026-08-20)

**Branch 2c as ruled is refuted by its own acceptance measurement —
implementation STOP, honoured** (the second of the package; the stop
report and the full banked patch are under
`tools/wp40/results/bay-transition-2c-stop-artifacts/`; tree clean at
002e605, no commit, no pin moved anywhere — the winner invariance held
4/4 byte-identical, the KAT and merge digests are unchanged, and the
production Whole gate's bite was demonstrated against the published
census row before the refutation). Measured: the closing kills the 259
enclosed pockets, the artifact witness and the fragment singleton
(which then passes a production compile) — but **111 of 370 witness
seeds keep `whole_gap_reject` (176 intervals / 242 columns), because
their pockets are shore-attached**: cardinally dry-adjacent to a Bank
station column, hence dry-4-connected to the mainland, so the ruled
criterion correctly does not fire. Step-3's shape taxonomy
under-described the family — its own nine measured abuts-a-Bank-station
cases are cardinal attachments. 90 of the 111 sit on the two authored
head-flank margins of bay_elandor_west. Consequences: the production
Whole gate is **not yet live**; the 11.5-C corridor package's ruled
base (the 2c commit) does not exist — its sequencing is suspended
pending the re-ruling; the banked winner digests remain the baseline.
The residue question — who owns a dry margin pocket that is
mainland-connected through the Bank's own station column but excluded
by the Bank-bounded face — goes to a re-design memo (11.7) that is cut
**only after** the survivors' attachment anatomy is measured (which
faces each surviving pocket touches, how many, cardinal or diagonal —
the committed step-3 probe measures this on the current tree, since
the closing does not alter these pockets). The measured-first
discipline is now explicit: after two refuted rulings, no rule in this
package is ruled again ahead of a measurement of its own firing set.

### 11.7 The residue-adoption memo (cut 2026-08-20, on the measured anatomy)

Evidence base: the attachment-anatomy sweep of 2026-08-20
(`tools/wp40/results/bay-transition-anatomy-report.md`, artifacts
beside it; probe unmodified at 36c9536; parity 111/111, reconciliation
against the stop report exact — 176 intervals / 242 columns seed by
seed, and the attachment predicate validated out of sample on the 8
step-3 non-survivors). **The firing set of the rule proposed here is
fully measured before the ruling — the 11.6 discipline is satisfied.**

**The measured anatomy, compressed.** 112 surviving pockets on 111
seeds. **Every pocket touches exactly one face cardinally (112/112);
zero multi-face, zero diagonal-only.** Every pocket hangs on exactly
one attachment throat exactly one column wide; 109 of 112 throats are
a single mid-trace Bank boundary station (the 3 vertical-throat seam
cases at z=2219:x=868 are unmeasured for provenance — irrelevant to
the rule below, which consumes only the touched-face count). 90 of 112
sit on the two authored head-flank columns of bay_elandor_west; 47
share one byte-identical anatomy (`goldmead#486`). Sizes: 101 of 112
pockets are 1 or 3 columns; maximum 14. New finding: the closing
splits six 8-connected diagonal chains — the attached 4-connected
piece survives, the diagonal piece fills; all three seam-adjacent
pockets are of this kind.

**Branches.**

- **11.7-A — extend the closing to wet shore-attached pockets.**
  Rejected: a mainland-connected dry column is land by the recorded
  design intent, and wetting a column that cardinally touches a Bank
  station changes the water the Moore trace bounds — an unmeasured
  cascade into every Bank KAT for a rule that fights the geometry
  instead of naming it.
- **11.7-B — residue adoption at the ownership layer (RECOMMENDED).**
  After face composition, before the footprint proof (census and
  production Whole gate identically): every unowned dry footprint
  column joins its 4-connected unowned-dry chain; a chain that
  cardinally touches **exactly one** composed face is **adopted** into
  that face's region (region membership only — no ring, no mask, no
  trace, no Bank is touched); a chain touching **two or more** faces
  classifies as the new loud class **`residual_multi_face_reject`**
  (measured zero over the family; expected vacuous, occupancy
  measured, never absorbed); a chain touching zero faces cardinally is
  exactly what the banked closing waters — the two rules partition the
  measured family by construction (attached → adopted, unattached →
  water), and the six split chains resolve deterministically (diagonal
  piece watered, attached piece adopted; the measured list is the
  regression set). Winners carry no pockets: both rules are no-ops
  there and the banked digests remain the STOP baseline.
- **11.7-C — authored-margin correction at the two head columns.**
  Kills 90 of 112 but not the family; available later as an authored
  cleanup, rejected as the rule.

**Packaging.** One coordinated implementation package: the banked 2c
closing patch (verified green on every pinned-truth tier) + the 11.7-B
adoption + the production Whole gate + the ruled 11.5-C appendix
acceptance — one atomic commit, one acceptance measurement. Grounds:
adoption and 11.5-C are the same region-semantics change in the same
code region (the Whole preparation and ownership layer); the corridor
package's ruled base (a standalone 2c commit) no longer exists; and a
third re-pin round is avoided. Acceptance: the union of the two ruled
plans — static gates; census gate suite; KAT suite with every moved
pin named (the F10 pins → `face_appendix_select`); the negative guard
tests of 11.5-C **plus** a synthetic multi-face chain failing
`residual_multi_face_reject` by name; PUC pair re-pinned
digest-identical; winner invariance byte-level against the banked
digests (STOP); the 370-witness re-run with zero gap/fragment rejects
(259 by closing, 111 by adoption, the six split chains individually
verified) and the 796-witness re-run with zero face rejects and green
Whole tiers; oracle suite green. The full-`W` re-census stays at
T2-final.

**RULED 2026-08-20** (coordinator, user-confirmed): **branch 11.7-B,
residue adoption, and the one-package packaging** — exactly as cut.
The prior 2c and corridor briefs are superseded by the unified package
brief; the 11.5-C ruling stands unchanged inside the package; the
banked closing patch and the banked winner digests carry forward. The
implementation is the one remaining step before the §11 acceptance.

### 11.8 The three residual families (recorded 2026-08-20; memo pending measurement)

**The unified package stopped a third time, honoured** (the stop
report and the full `package.patch` — applying cleanly on 2b165d4 —
are under `tools/wp40/results/bay-transition-package-stop-artifacts/`).
The union acceptance did its designed job: it measured the 796 face
witnesses' raw masks and Whole tiers **for the first time** (pre-fix
their Whole was `whole_not_evaluated`) and found three disjoint
residual families, 108 seeds, every one reported by a named guard,
none absorbed:

- **Family A, 24 seeds:** the closing's own loud guard — "closing
  pocket holds a footprint boundary column" — dry coast-ring fragments
  pinched off by one Bay's raw water at transition neighbourhoods;
  eight fixed single-column witnesses on four authored rows.
- **Family B, 60 seeds:** the 11.5-C guard conditions, biting as
  designed on a population its sample bounds under-measured: 41
  non-join-local zero-width single-station touches at measured join
  distance 11 > W=8 (all silverleaf), and 19 interior-hugging
  one-station dips to the join terminal (a vertex self-touch with a
  strictly interior cardinal neighbour — not a filament; these are
  the 11.5 investigation's own anchored single-touch joins). Firing
  sets fully measured in the sweep records.
- **Family C, 24 seeds:** `whole_undeclared_multiplicity_reject` with
  r=1 — exactly one dry column inside two accepted faces' winding
  regions, kragmar seam regions z≈2232–2244. The neighbouring-face
  coverage question 11.5 flagged statically unanswerable is now
  measured occupied.

**Measured green at the same patch:** the gap family is dead 370/370
(259 closing / 111 adoption, per-seed parity with the 11.7 anatomy,
all six split chains exact, `residual_multi_face_reject` vacuous);
688/796 face seeds fully green with 719 carrying
`face_appendix_select`; winner invariance 4/4 byte-identical; every
pinned-truth tier green with the full moved-pin table banked. One
operationalization awaits ratification: "zero-width appendix"
implemented as *no cardinal 4-neighbour strictly interior by winding*
(the investigation's lateral-pair phrasing wrongly rejected W-112's
measured L-turn corridor mouth; the corrected predicate accepts the
measured family and the 19 dips prove the interior guard still bites;
provenance beside the W pin in the patch).

Per the 11.6 discipline the re-design memo (11.9) is cut only on
fully measured firing sets: family B's are complete; **families A and
C get a micro-measurement first** (A: each pinched fragment's full
8-neighbourhood — diagonal coast-ring continuity and the adjacent
face; C: the two claiming faces per column and the distance to the
nearest declared-seam declaration). The production Whole gate stays
not-live; the banked winner digests remain the baseline; the full-`W`
re-census stays at T2-final.

### 11.9 The three-family completion memo (cut 2026-08-20, all firing sets measured)

Evidence: the sweep records of the package stop (family B, complete
over the 796) and the A/C micro-anatomy
(`tools/wp40/results/bay-transition-ac-anatomy-report.md` — worktree
measurement on the applied patch; parity proofs green). The ruling
lands at the end of this section when it lands.

**Ratification.** The package's operationalization of "zero-width
appendix" — *no cardinal 4-neighbour strictly interior by winding* —
is put up for ratification: the investigation's lateral-pair phrasing
wrongly rejected W-112's measured L-turn corridor mouth; the corrected
predicate accepts the measured family and the 19 interior dips prove
the guard still bites. Provenance is pinned beside W in the patch.

**Family B — measured completion of 11.5-C.** (i) **W := 11**, the
measured population maximum over all 796 (was 8, from the 8.5% dump
sample); no margin — anything farther stays a named loud failure.
(ii) The 19 interior-hugging dips are the 11.5 investigation's own
anchored single-touch joins — measured family members. The acceptance
predicate generalizes from "zero-width filament" to **join-local,
locally non-crossing self-touch**: at a repeated station the two
passes must not interleave in the cyclic order of the four incident
ring edges (integer-only, decidable); filament and pinch are both
touch forms and classify under `face_appendix_select` with the
appendix/pinch counts recorded; a crossing, an opposing diagonal or a
non-join-local repeat still fails by name.

**Family A — the ring is the connectivity authority.** Measured 8/8:
every pinched fragment is a single coast-ring station, cardinally
surrounded by bay water and off-footprint ocean, and **ring-continuous
with the mainland through exactly one diagonal step** — the coast ring
is built with eight-connected steps, while the closing flood walks
4-connected row runs; the "pinch" is an artefact of the flood's
criterion, not of the geometry. Rule: **a footprint-ring station is
mainland by definition — never a closing candidate** (the loud guard's
condition becomes this rule's trigger), and an unowned dry chain
containing ring stations **adopts along the ring's own connectivity**:
into the face that owns its ring-neighbour station (the measured
mainland link; deterministic, one link per fragment measured 8/8).
Global 8-connectivity for the flood is rejected — it would un-water
the six measured split chains and re-open the gap family. The Whole
gate remains the loud backstop if a ring chain ends up unowned.

**Family C — seam inheritance.** Measured 7/7: the doubled column is
the tip of the appendix face's accepted one-station dip, **boundary
for both faces** (never interior, never a third claimant), and the
declared seam carrying exactly this face pair sits at cardinal
distance 1 (same x, one row up) on every witness — `whole_declared`
simply never declared the dip tip, because it derives only from final
shared-edge stations and span vertices. Rule: a column claimed by
**exactly two faces, both as boundary**, cardinally adjacent to a
declared-seam column of the **identical pair**, inherits the
declaration and classifies `whole_declared_seam_select` (DECIDED).
Anything else — an interior claimant, a third face, no adjacent
same-pair declaration — stays `whole_undeclared_multiplicity_reject`,
loud.

**Packaging and acceptance.** The one-package ruling of 11.7 stands:
the fourth attempt starts from the banked `package.patch` plus these
three completions and the ratified predicate; acceptance is the 11.7
union plan verbatim (1,166 witnesses, zero REJECTED rows of any
class, winner invariance against the banked digests as the STOP, all
negative guards by name — extended by: a synthetic crossing self-touch
failing by name, a synthetic ring-chain-unowned case failing as a gap,
and a synthetic two-interior-claimants case staying the multiplicity
reject). The 108 family seeds are individually verified in the
acceptance sweep. The full-`W` re-census stays at T2-final.

**RULED 2026-08-20** (coordinator, user-confirmed): **all four points
as cut** — the ratified zero-width predicate, W := 11 with the
non-crossing touch generalization, the ring-connectivity authority
with ring adoption, and seam inheritance. The fourth implementation
attempt proceeds from the banked patch under the amended brief.

### 11.10 The W re-ruling memo (cut 2026-08-21, on the complete distribution)

**The unified package stopped a fifth time, honoured** (the stop
report, the complete fourth-attempt `package.patch` — applying cleanly
on af40704, verified in a throwaway worktree — and the full evidence
set are under
`tools/wp40/results/bay-transition-package-w11-stop-artifacts/`; tree
clean, no commit, no pin moved in the tree). The acceptance measured
everything green — winner invariance 4/4 byte-identical to the banked
digests, the gap family dead 370/370 with the 11.7 anatomy reproduced
byte-exactly per seed, families A and C complete, every pinned-truth
tier — except **one ruled constant**: five of the 60 family-B seeds
keep `face_non_simple_reject` at measured nearest join distance
12 > W=11. 1,161 of 1,166 witnesses green. This memo cuts the W
re-ruling, puts the loop-pairing operationalization up for
ratification, and records the population findings. The ruling lands
at the end of this section when it lands.

**The measured refutation.** 11.9's "W := 11, the measured population
maximum over all 796" was in fact a one-witness generalization: the
11.8 probe measured seed 10050140447867716291 (join at 1127:-2233,
distance exactly 11) and the memo took that number for the
population. The complete measurement now exists
(`b-join-distances.tsv`, all 60 B seeds, 93 repeated stations; the
sweep covered all 796): the silverleaf touch family sits at authored
stations 1138–1140:-2232 while its anchoring join jitters per seed
over 1126/1127/1128:-2233 — measured ±1 around the probe witness.
Distance distribution: d=1 ×14, 2 ×10, 8 ×7, 9 ×9, 10 ×25, 11 ×23,
**12 ×5** — nothing beyond 12; the combinatorially conceivable
extreme (touch 1140 against join 1126) measures absent. The five
d=12 seeds: 18171940200422843206, 501535562992590246,
4154650258832672681, 4733240883161403671, 7921513688806375529. What
is refuted is the completeness of the 11.9 measurement, not the
no-margin philosophy.

**Branches.**

- **11.10-A — W := 12, the complete-population maximum, no margin
  (RECOMMENDED).** The first W pin whose provenance is a complete
  population instead of a sample or a single witness — the 11.6
  discipline is satisfied for the first time on this constant. It
  accepts exactly the measured universe; anything farther keeps
  failing by its own name; T2-final's full-`W` re-census re-verifies
  the pin over the whole universe. Pin lineage recorded 8 → 11 → 12
  (no committed tree ever carried 8 or 11 — both exist only in banked
  patches; the commit introduces W = 12 with the
  complete-distribution provenance).
- **11.10-B — W := 12+k with an explicit jitter margin.** Rejected:
  the marginal firing set (distances 13…12+k) is measured empty, so
  ruling it in accepts configurations no measurement has seen —
  precisely what 11.6 forbids and five honoured STOPs enforced; the
  measured anchor jitter (±1) is already contained in 12; and an
  authored-geometry change that could move the family re-measures at
  census time anyway, with the loud guard as the designed response.

**Ratification — the non-crossing predicate reads the loop pairing**
(the 11.8 zero-width precedent: an operationalization corrected on
measured evidence, put up for ratification). The 11.9 text "the two
passes must not interleave in the cyclic order of the four incident
ring edges" is implemented over the **loop pairing**: the repeated
station splits the ring into two loops — α from the first
occurrence's outgoing edge to the second's incoming, β from the
second's outgoing back to the first's incoming — and the touch
crosses exactly when (out₁,in₂) and (out₂,in₁) interleave, the
configuration that cannot close in the plane without a further
self-intersection. Measured necessity: the family-C dip
(kragmar_stillgrave_hollow at -1204:2233, ring read in place: pass 1
arrives W and leaves E, pass 2 arrives S and leaves NW) has
interleaving **passes** but loops in disjoint sectors — the
pass-pairing reading would reject the very dip faces the ruled
family-C acceptance builds on. The loud guard is unchanged: the
synthetic loop-interleaving crossing fails by name in the KAT, and a
coincident loop-end direction is a shared edge — overlap, not a
crossing, still loud. Recommendation: ratify as the binding reading
of the 11.9 predicate; the provenance stays pinned beside W in the
authority.

**The four findings — population corrections inside ruled classes, no
new family.** The 108 family seeds' Whole tiers were measurable for
the first time at this patch; all four findings are the known
mechanisms with measured anatomy inside the ruled classes. One count
in the stop report's prose is corrected here against its own banked
evidence (the evidence file is authoritative): the family-seed
adoptions number **six**, not five — 3 C, 2 A, 1 B, four of them
byte-identical to the known copperfell chain (the report's prose
missed A seed 8232565312062675998, whose adoption the evidence file
carries).

1. **Seam-inheritance population 25** (was 24): B seed
   8003871659703994060, accepted under the appendix tier, carries
   the identical dip-tip doubling at the measured column 884:2238
   and inherits over the identical face pair. Firing columns
   unchanged — exactly the seven measured witnesses
   (`inherit-firings.tsv`).
2. **Six additional adopted chains on family seeds**
   (`adoption-verification.txt`, beyond the 111): the copperfell
   -1103 chain byte-identical on 10958005904297776829 (C),
   7851242355115945264 (B), 6058341980007287606 (A) and
   8232565312062675998 (A); redtusk 890:2235–2236 on
   1026383728877078735 (C); sunscar -895:2627–2628 on
   1290646225298478909 (C). All cardinal, all exactly-one-face, zero
   ring stations, zero `residual_multi_face_reject`. The adoption
   ledger totals **117 seeds / 118 chains** (the banked 111-seed /
   112-pocket anatomy, two-pocket seed included, plus these six).
3. **Pinch population 21** (was 19): B seed 6716966456885196819
   reclassifies from "non-join-local" to pinch once join-local under
   the widened window (11.8's 41/19 split over the 60 becomes
   40/20), and family-A seed 3253762158045475787 carries a pinch
   never measurable pre-fix.
4. **Appendix carriers 792** (was 719): +49 B and +24 A seeds (the A
   seeds aborted before Scan-4 pre-fix); no banked carrier lost a
   row.

Disposition: no rule changes; the four populations become pinned
expectations of the fifth attempt's acceptance ledger, and any drift
beyond them (beyond the five re-accepted d=12 seeds, whose counts the
run measures) is a finding for a new memo.

**Packaging and acceptance.** The 11.7 one-package ruling stands. The
fifth attempt: apply the banked `package.patch` on af40704, move the
single constant **W 11 → 12** in `partition.lua` and
`t2_census_authority.lua` (the worker bridges them; the provenance
text beside the pin updates to the complete-distribution
measurement), then the five named seeds solo (projected
`face_appendix_select` on the silverleaf face — the touches are the
measured zero-width single-station kind, now join-local; the run
measures the counts) and the 1,166-witness union sweep. Acceptance
is the 11.9 plan verbatim with the ledger updated to this memo: zero
REJECTED rows of any class; inherit firings 25 at the seven columns;
adoption 117 seeds / 118 chains, the six family-seed chains and the
six split chains individually verified; pinch 21 plus whatever the
five re-accepted seeds measure; appendix carriers ≥ 792 with no
banked carrier lost (exact count measured); winner invariance
byte-level against the banked digests (STOP — the winners ride the
fast path, W never evaluates on them); PUC pair re-pinned
digest-identical across interpreters, any record-digest move named
old → new against this stop's banked values. Cost anchors re-base on
the fourth attempt's actuals — no-abort mean 67.9 CPU-s/seed, 22.0
CPU-h records + 9.4 CPU-h probes, 4.8 h wall at width ≤ 8 (the 3.5 h
pre-approval was overrun by ~1.3 h because the projection used the
banked run's abort-lowered mean; reported, not absorbed) — and the
v3 brief carries the new pre-approvals. The production Whole gate
goes live with the package commit; the full-`W` re-census stays at
T2-final.

**RULED 2026-08-21** (coordinator, user-confirmed): **all three
points as cut** — **W := 12** (pin lineage 8 → 11 → 12,
complete-distribution provenance), the **loop pairing ratified** as
the binding reading of the 11.9 non-crossing predicate, and the
**four findings pinned as population corrections** (inherit 25 at the
seven columns; adoption 117 seeds / 118 chains; pinch 21; appendix
carriers ≥ 792) into the fifth attempt's acceptance ledger. The
acceptance sweep is pre-approved to **6 h wall** (the user's buffer
choice over the measured 4.8 h no-abort actuals); the PUC
pre-approval is unchanged. The fifth implementation attempt proceeds
from the banked patch under the v3 brief.

### 11.11 The acceptance closeout (cut 2026-08-21, recorded measurement corrections)

**The fifth attempt landed as `931e857`** — one atomic commit carrying
the banked closing, the 11.7-B residue adoption, the ruled 11.5-C
appendix acceptance, the three 11.9 completions, the ratified loop
pairing and **W := 12**, with the production Whole gate live. The
acceptance evidence is untracked beside it, under
`tools/wp40/results/bay-transition-package-final-artifacts/`: the
1,166-witness union sweep with **zero REJECTED rows of any class**,
whole tier evaluated 1,166/1,166 with g/o/r/m zero, zero non-owned
once-fragment rows, winner invariance 4/4 byte-identical to the banked
digests, probe parity 478/478, families A/B/C green by records
(24/60/24 seeds, zero rejects), the six split chains and the six
family-seed chains individually verified. The scratch ledger verifier
nevertheless ended `FAILURES PRESENT` on **exactly one line**:
`FAIL adoption-117-118 seeds=118/117 chains=119/118 diff-bytes=126`.
This memo audits that line, records the two measurement corrections it
exposes, and closes the §11 acceptance.

**The audit** (coordinator, independent of the implementing agent; the
adoption anatomy re-derived under LuaJIT in 41 s). The banked
117-seed / 118-chain anatomy is reproduced **byte-identically** inside
`adoption-actual.txt` — the diff is additive, not a drift. Exactly one
line is new:
`ADOPTION seed=18171940200422843206 chains=1 columns=1 rejected=0 zone_face:kragmar_sunscar_flats/1[z=2252:x=877..877]`.
Cardinal, single-face, zero ring stations — the ruled 11.7-B
shore-attached mechanic exactly as cut, on a seed whose whole tier was
measurable **for the first time** in this run, because it is one of the
five d=12 seeds that W = 12 re-accepted. 11.10 named this case in
advance: "any drift beyond them (**beyond the five re-accepted d=12
seeds, whose counts the run measures**) is a finding for a new memo."
The measurement fell inside the clause; the pin was written without it.

**Correction 1 — the adoption ledger: 117 seeds / 118 chains → 118
seeds / 119 chains.** Cause: 11.10 pinned the adoption count as a fixed
number (111 gap-family chains + the six family-seed chains) while its
own disposition left the five re-accepted seeds' tiers to be measured.
The additional chain is the 118th seed's single adopted chain above;
no banked chain moved, no chain was lost, `residual_multi_face_reject`
stays vacuous (zero multi-face chains, zero ring-adoption chains).

**Correction 2 — the family-B evidence: 93 → 105 stations.**
`bjoin-actual.tsv` is the **complete deduplicated** family-B
repeat-station capture: 105 rows, zero duplicate rows, all 60 family-B
seeds represented, every row `class=face_appendix_select`. The banked
93-row table (`b-join-distances.tsv` of the w11 stop artifacts) was an
incomplete diagnostics capture, not the complete population 11.10 took
it for. The delta is 12 additional stations — d=1 ×1, 2 ×5, 3 ×3,
4 ×3, **all d ≤ 4**, behaviour identical under W = 11 and W = 12 —
plus 12 class flips `reject` → `select` confined to the five d=12
seeds (18171940200422843206 ×1, 501535562992590246 ×1,
4154650258832672681 ×5, 4733240883161403671 ×3,
7921513688806375529 ×2). Distance histogram old → new: d=1 ×14, 2 ×10,
8 ×7, 9 ×9, 10 ×25, 11 ×23, 12 ×5 (93) → d=1 ×15, 2 ×15, 3 ×3, 4 ×3,
8 ×7, 9 ×9, 10 ×25, 11 ×23, 12 ×5 (105). **The maximum is unchanged:
12.** The W := 12 ruling's substance — the pin sits at the
complete-population maximum, no margin, anything farther stays a named
loud failure — is therefore unaffected; what moves is the histogram
detail and the word "complete" attached to the 93-row capture. The
11.6 discipline holds for the constant: the ruling was cut on the
population maximum, and the larger population confirms that maximum.

**Everything else in the ledger is byte-exact or better.**
`inherit-actual.tsv` (25 rows at the seven declared columns) and
`pinch-actual.tsv` (21 rows) are byte-identical to the banked pins;
`ringcol-actual.tsv` (8 rows, the family-A ring evidence) is
content-identical to the banked evidence in a different row order —
probe emission order is not canonical, so only the content is pinned;
`carriers.txt` holds 796 distinct appendix carriers (≥ 792) with no
banked carrier lost.

**The corrected pins are now the authoritative §11 acceptance
ledger**, and they are no longer prose. Byte-exact copies of the six
tables are committed as canonical fixtures under
`tools/wp40/fixtures/t2_census/` —
`s11-adoption-ledger-v1.txt` (118), `s11-bjoin-complete-v1.tsv` (105),
`s11-inherit-v1.tsv` (25), `s11-pinch-v1.tsv` (21),
`s11-ringcol-v1.tsv` (8), `s11-carriers-v1.txt` (796) — and the
committed checker `tools/wp40/t2_s11_acceptance_check.lua` (runner
`tools/wp40/run_t2_s11_acceptance.sh`) verifies an artifact set against
them in two independent layers: byte equality against the fixtures
(sorted-content equality for ringcol, for the reason above) **and**
structural pins recomputed from the artifact bytes rather than from the
fixtures, so a fixture and an artifact that drifted together still
fail. It prints canonical PASS/FAIL lines and ends `ACCEPTANCE GREEN`
(exit 0) or `FAILURES PRESENT` (exit 1); it is byte-identical under
LuaJIT and the vendored PUC 5.1. **Against the landed artifacts it is
green.**

**What this closeout is, stated flatly.** A new measured finding:
**yes** — the 118th adopted chain and the 12 previously uncaptured
family-B stations. A new failure class or new semantics: **no** —
every row falls inside a mechanic already ruled by 11.7-B, 11.5-C and
11.9, and every named loud guard stayed loud and vacuous where it was
predicted vacuous. An algorithm change: **no** — W = 12, the loop
pairing, the closing, the adoption, the appendix acceptance, the seam
inheritance and the Whole gate are exactly as committed in `931e857`;
not one line of production code moves for this entry. A formal
acceptance closure: **yes** — with the two pins corrected, the §11
acceptance is green in full, and this section is the record of it.

**The in-code `W` provenance is deliberately left untouched.** The
provenance comments beside the pin in
`mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua` and
`tools/wp40/t2_census_authority.lua` still cite the superseded 93-row
capture and its histogram. Both files are closed: the production
geometry and the census authority carry the ruled constant, and the
value they pin (12) is correct under both histograms. Editing a
provenance comment in a closed production file to restate a
measurement that changed nothing about the constant would move a
committed surface for documentation's sake; this contracts entry is
the authoritative corrected provenance, and a reader who follows the
in-code comment to §11.10 arrives here. Should either file be opened
for a substantive reason, the comment updates with it.

**11.7-C — the authored-margin correction at the two head columns —
remains optional later cleanup**, exactly as ruled: it kills 90 of the
112 measured pockets but not the family, and adoption owns the family.

**Boundary topology is semantically FROZEN.** With this closeout the
§11 boundary machinery — corridor ownership, the closing, residue
adoption, the appendix acceptance predicate with `W`, the loop
pairing, ring connectivity, seam inheritance and the Whole gate — is
closed for T2. A semantic change to any of it henceforth requires a
new memo in this document under the 11.6 discipline (fully measured
firing set before the ruling), not an in-package amendment. The freeze
is on the semantics, not on measurement: the full-`W` re-census stays
at T2-final and **re-verifies these pins** over the whole universe,
and a drift it finds is a finding for that new memo. T2 as a whole
remains in progress.

## 12. The C1 v3 conformance handoff (cut 2026-08-21)

**Status: the immutable acceptance conformance completed green on
2026-08-22.** It ran from commit `5d770365`, tree `52ec4f38`, and C1-v3
DAG `52e2d459…`; the final artifact hashes `7ac6b7f9…`. This freezes the
downstream boundary-topology interface in section 12.4. It does **not**
claim T2-final, T9-final, production publication, or any 32-seed corpus
promotion; the final artifact records
`stage2_status = pending_seed_corpus_promotion`.

### 12.1 What moved

The T2c-E0-C1 selected-four conformance chain read the frozen pre-v3
(v2) measurement from `53be77e`, so the final conformance could not be
executed from a closed code/input DAG. The chain now reads the
committed **v3 scalar pool**: commit `19fc28d1`, tree `bca04056`,
Authority-DAG `069cce2d`, stage-S1 pins `10a790a6…` /
`83b1b16a…`, merged artifact `5b5241b3…`, manifest `c8f61852…`.

No measured scalar moved. The candidate row bytes are **identical**
across the two generations — `candidate_rows_sha256` is `b08e142a…`
in both — and only the provenance header differs. The four ranked
winners are unchanged and were re-derived from the v3 artifact:
slot 28 / candidate 2192 / `5270046902118333881`, slot 29 / 1713 /
`16178445837170081103`, slot 30 / 1047 / `15219119262482319357`,
slot 31 / 3438 / `17842018860885445630`. The staging seed
(`grudgelands-wp40-seed-08`, `7821741934987559905`) is likewise
reproduced rather than copied.

Nothing about boundary semantics, partition semantics or production
world behaviour changes with this migration.

### 12.2 Why the provenance model had to change

The pre-v3 chain asserted that the **live** measurement Authority-DAG
equals the gate's. That assertion is now unsatisfiable and was not
faked: `geometry/partition.lua`, `source/catalog.lua` and
`validation/t2_source.lua` all differ between the pool commit and
HEAD, because the §11 correction landed *after* the pool was measured.
Measured: pool Authority-DAG `069cce2d…`, live HEAD measurement
Authority-DAG `fbb81ec1…`.

Three separately named claims replace it. No two share a field name,
so a reader of a result row can always tell which digest describes the
pool's origin and which describes the code that re-derived it:

1. **Pool origin, historical** — `pool_measurement_commit`,
   `pool_measurement_tree`, `pool_authority_dag_sha256`. The verifier
   re-materializes the pinned pool commit through
   `validate_pinned_authority`, **without** a `partition_sha256`;
   demanding one would resurrect exactly the coupling the stage-S1
   migration removed.
2. **Stage-S1 currency** — `s1_authority_sha256`,
   `s1_source_projection_sha256`, recomputed from the tree the
   conformance actually runs on (following `t2_extreme_gate_check.lua`)
   and required to equal the gate. This is what lets one measured pool
   survive a later-stage geometry correction.
3. **Executing code** — `execution_authority_dag_sha256`, the
   measurement Authority-DAG of the conformance tree. Recorded in a
   gate-independent position and established against the executing
   tree, never against the pool; the verifier recomputes it live per
   row and the finalizer requires all twenty-four rows to agree.

The pre-v3 conformance authority module, gate and artifacts are frozen
and byte-identical. `t2_partition_test.lua`'s
`selected_stage2_historical` mode still re-materializes the pre-v3
conformance DAG `086855378e…` from `5a2fc0d`; that was re-derived
with the whole migration in place and is unchanged. Naming, roster and
guard detail: `tools/wp40/README.md`, "The v3 conformance generation".

### 12.3 What is measured, and what is not

Established and reproducible:

- All **20 roster candidates** (the sixteen deterministic shard
  endpoints plus the four winners) reproduce **byte-for-byte at HEAD**
  under LuaJIT and were independently rescored under the vendored PUC
  5.1.
- **All four slots 28--31 pass the full selected partition gate** under
  LuaJIT and the vendored PUC 5.1 with `g`/`o`/`r`/`m` all zero.
- Cost anchors, measured: one selected slot ≈ **335 s** LuaJIT wall;
  one PUC rescore row ≈ **38–44 s**; the retained PUC run completed its
  rescore phase in **215 s** and its four-worker selected phase in
  **5,507 s**.
- The migrated conformance KAT is green under LuaJIT and the vendored
  PUC 5.1 with byte-identical output, and the v3 preflight re-derives
  the C1 v3 DAG from the pinned commit.
- The final artifact was re-derived from all 24 retained rows. A second
  invocation at unchanged HEAD independently verified them and exited
  through the same-HEAD resume path without recomputation.

Not established, and not claimed anywhere: seed-corpus promotion;
T2-final or T9-final; production or publication authority.

**The retained interpreter pin is deliberately kept.** The merged
artifact records `merge_interpreter_path`
`/home/jan/projects/grudgelands/tools/bin/lua51` and the workers, the
verifier and the finalizer compare it against their own `argv[0]`.
An end-to-end run therefore succeeds only when the repository root is
exactly that path — **the acceptance conformance cannot be run from a
git worktree.**

### 12.4 The downstream interface — FROZEN by the acceptance run

The green selected-four conformance freezes exactly this interface. It
does not freeze a future bucket, selector, seed corpus, or production
adapter:

- **Compiled families covered.** The selected result's
  `compiled_sha256` digests the entire compiled payload, i.e. all nine
  families in `geometry/partition.lua`: `bays`, `channels`,
  `closure_wings`, `coast_shelf`, `dry_faces`, `islands`,
  `land_boundaries`, `mouth_apertures`, `perimeters`.
- **Whole report fields**, recorded per slot in the result row:
  `columns`, `base_total`, `planned_water`, `dry`, `g`, `o`, `r`, `m`,
  `schedule_intervals`, `perimeter_aperture`, `perimeter_attachment`,
  `perimeter_dry`.
- **Per-slot counts**: `transition_count`, `bank_count`, `wing_count`
  (`#families.closure_wings`), `coast_count` (`#families.coast_shelf`),
  `face_count` (`#families.dry_faces`). The v3 result validator pins
  `transition_count = 8`, `bank_count = 20`, `wing_count = 8`,
  `coast_count = 22`, `face_count = 38`, `perimeter_attachment = 8`
  and `g = o = r = m = 0`.
- **`compiled_sha256`** — recorded in the result row.
- **`edge_inventory_sha256`** — produced by `t2_partition_test.lua`
  (`selected_request.result.edge_inventory_sha256`) but **not** carried
  into the v3 selected result row. Whether it belongs in the frozen
  interface was an open item here; **§12.5 settles it in the negative** —
  it stays diagnostic-only and is not added to the frozen C1 interface.

The four frozen payload digests are:

| slot | selector class | candidate | `compiled_sha256` |
|---:|---|---:|---|
| 28 | greatest coast | 2192 | `06cfb4a027ff21fdca53165b15307e55769316210222cdb9579efc209165bd6a` |
| 29 | least coast | 1713 | `3358adf655f454e6d8641f146af6fa0c509a4e2f61d1d41195622048c0909f52` |
| 30 | greatest non-coast | 1047 | `e1f813c7b3e991aaea196ad314dd71723b7215e0efb32d546e5df70afef01f7b` |
| 31 | least non-coast | 3438 | `83e260255daa26d1c7928e891a406015c4438f3e292d37e22f4452421f4e5261` |

### 12.5 The two slot findings, and what they actually were

**Both are §8.6 ledger items, closed here — not new topology.** §8.6
handed **three** pre-existing findings to the next phase's ledger; these
are two of them, named there verbatim:
"the R18-level C2 conformance oracle at slot 29" and "the Slot-30
Starbough pin drift". The first cut of this section read them as two
fresh defects of the WIP commit `44c2739` and asked for a new §11.6
ruling on `land_010`. That framing was wrong and is corrected here.
**Neither finding is a new topology failure, and neither needs a new
§11.6 ruling.** The §11.11 boundary-topology freeze is untouched: not
one line of production geometry moved for either. The third §8.6 ledger
item — the F10 face-simplicity occupancy on wanted seeds 2147483648 and
1959553668008863006 — is **not** touched by this package and stays on
the ledger.

1. **Slot 29 — the oracle, not the compiler.** The independent C2
   edge/transition oracle in `tools/wp40/t2_partition_test.lua` was
   still resolving transition terminals at R18 level: its
   `transition_probe` fixed the R16 `E` at the declared interval
   endpoint and never enumerated interior incidences. Production
   implements accepted R19 joint-terminal selection, so on slot 29 the
   two disagreed and the oracle aborted — payload **1601** stations
   against **1602** independent. **Production was right.** The oracle
   is now an independent reproduction of accepted R19: it enumerates
   every eligible incidence of the fixed R18 interval, evaluates R16 at
   each, forms the complete Cartesian product across the edge's
   transition endpoints, validates each tuple through the sole final
   raster as an unretained probe, completes both incident Banks through
   its own tracer, rejects duplicate authority and the zero-complete
   case, and selects the least tuple under all six §7.1 keys.
   Measured: `land_010:to` resolves `direct` at retreat 1 with terminal
   `(-1135, 2242)`, `previous` `(-1136, 2242)`, a 1,601-station edge
   hashing `f823d2ab…` (reverse `d914e97c…`), Stillgrave 794
   `f50970d8…` and Mournfen 456 `457ec6b1…`, with the old R18 `E`
   `(-1134, 2242)` off the land edge and owned exactly once, by
   `bay_bank:kragmar_west:mournfen`. Those are byte-for-byte the R19
   witness that
   [wp40-reality-corrections.md](wp40-reality-corrections.md) derives
   from the Source/T1-only oracle, so two independent derivations and
   the compiler now agree, and all of it is pinned rather than printed.
   Over seed 0, max-u64 and all four winners — 36 transition-edge
   resolutions — every edge had **exactly one** complete tuple and
   **no ordering key was ever exercised**; `land_010` at slot 29 is the
   only nonzero retreat anywhere. Keys 1–6 remain totality machinery,
   exactly as §7.1 measured.
2. **Slot 30 — measured pin drift, and nothing else.** The 63-character
   Starbough literal was a truncated transcription. Measured under
   LuaJIT, the digest is
   `694aa00661b735fc98ab756616c7da96f66d9a2fc2c53ca99ce0a8ca74e3dc1d`
   — the superseded literal with its **final character deleted**. The
   Bank itself never moved: 517 stations and both incidence witnesses
   beside it are unchanged, and the sibling Silverleaf pin
   `4786ad54…` never failed. The replacement was read off the run,
   never appended or guessed; both Bank assertions now carry their
   measured digest in the failure message so a future drift is read
   rather than reconstructed.

One further defect surfaced only because slot 29 now gets past the old
abort, and it is recorded rather than folded into either finding: the
H15 simulated-notch harness in `tools/wp40/t2_partition_oracle.lua`
built its patched world without carrying `raw_bay_water`, so a
shoulder-mode Aperture terminal called a nil field. It is pre-existing,
independent of R19, and latent because no winner previously both
resolved a shoulder Aperture and reached that simulation. A simulated
notch is R17 fill on the *final* mask, so the raw Bay mask passes
through unpatched; that one field is now carried explicitly.

**`edge_inventory_sha256` stays diagnostic-only.** It is produced by
`t2_partition_test.lua` and deliberately **not** carried into the v3
selected result row, and this package does not add it to the frozen C1
interface. The §12.4 open item is therefore settled in the negative for
now: it is a printed diagnostic, not interface. Verified from the code
rather than asserted — it is absent from `selected_fields` in
`t2_extreme_conformance.lua`, which is enforced by `exact_fields`, so it
could not be present without failing.

**One divergence found while re-deriving the order, recorded and NOT
fixed here.** Bringing the C2 oracle to R19 required implementing the
§7.1 total order twice over, and the two implementations of keys 4–6 do
not agree on their *metric*:

- **plan §7.1 keys 4 and 5** say "the sorted set of resolved terminal
  world coordinates, **lexicographic by `(x, z)`**" — by the coordinate
  tuple. The C2 oracle implements exactly that. Production
  (`geometry/partition.lua`, `joint_tuple_less_compile` and
  `joint_tuple_rank_census`) sorts and compares those two keys as the
  **rendered text** `x .. ":" .. z`. The two orders invert on negative
  `x` of equal digit width — `"-1134:2242" < "-1135:2242"` as text,
  `-1135 < -1134` as a coordinate — and those are precisely the two
  `land_010` stations in the R19 witness.
- **plan §7.1 key 6** says "the probe **byte sequence** … the
  lexicographically lesser of the bytes and their exact reverse".
  Production implements that; the C2 oracle's first cut compared station
  tuples and has been corrected to bytes — including the separator, which
  §7.1 does not specify and which is therefore taken from the compiler's
  rendering (`;`, not `,`; the two sort differently whenever one station
  token is a strict prefix of another). **Key 6 is aligned end to end**;
  only keys 4 and 5 remain divergent.

So production deviates from its own declared order on keys 4 and 5. The
C2 oracle deliberately does **not** mirror that deviation: an
independent oracle exists to notice one, and mirroring it would retire
the cross-check. **Nothing is exercised by it.** Measured over seed 0,
max-u64 and all four winners — 36 transition-edge resolutions — every
edge had exactly one complete tuple and no ordering key fired at all,
which is the same state §7.1 itself recorded ("keys 2–6 are exercised by
no measured configuration; they exist for totality on paper"). Should a
future seed ever produce a tie through key 3, the two sides would select
different tuples and the run would fail loudly on the final-edge byte
comparison — never silently. **Aligning them is a ruling this package
does not take**: it would move frozen production geometry, which is a
STOP under the §11.11 topology freeze.

**Closed 2026-08-22 by §13.** The ruling was taken: plan §7.1's
coordinate-tuple order is the authority, the rendered-text comparison was an
implementation defect, and production is aligned. Under the §11.6
discipline the keys-4/5 firing set was measured **before** the alignment
landed and is empty over the whole retained population — 759 multi-complete
records, key 1 selecting uniquely at every one of them under both metrics —
so no measured geometry moved and the §11.11 freeze was never in tension.
The paragraphs above are the historical record of the divergence, unchanged;
the tripwire described below is retired in that same package and replaced by
a live three-way cross-check, keeping its `decided_by` and divergent-key
diagnostics.

So that the divergence announces itself rather than being diagnosed
after the fact, the C2 oracle **asserts on it directly**: a selection
that was separated from **any** competing complete tuple only at key 4
or key 5 trips a named assert pointing back at this section. The test is
that per-competitor fact, not the summary's `decided_by` figure — that
one reports how deep the order had to go, and neither its minimum nor
its maximum over the competitors can answer whether a divergent key was
load-bearing. A winner separated from one competitor at key 1 and from
another at key 4 has minimum 1; one separated at key 4 and at key 6 has
maximum 6. Both would stay silent on a real key-4 decision. Without it the first live occurrence would surface
as `land_0NN independent final station bytes changed`, which reads as a
geometry regression and sends the reader into R7 displacement instead of
the comparator. Key 6 does not trip it — after the separator alignment
above, a key-6 selection is legitimate on both sides.

**Two obligations the C2 oracle deliberately does not independently
check**, recorded so the "two independent derivations meet here" claim
is not read wider than it is:

1. `authority.excluded` still means only the stations of *non-selected*
   intervals. Production's excluded-fragment set now also carries the
   R19-clipped stations of the *selected* interval and enforces the
   once-owned obligation on them. On the C2 side that obligation is
   checked by the slot-29 witness alone.
2. The `exact_six_reversal` KAT reconstructs the R18 clip over the whole
   selected interval, so it coincides with the R19 probe only while
   `land_001` sits at retreat 0. R19 reversal *re-enumeration* is
   therefore not exercised anywhere in C2.

### 12.6 Recorded-commit reuse of a finished conformance artifact

A completed `conformance-puc-v3.tsv` is evidence of the commit it
**records**, not of whatever `HEAD` happens to be. The launcher used to
take its pins from `git rev-parse HEAD`, so any later commit — a
documentation-only one included — declared 24 rows of immutable
evidence stale and bought a full rerun.

The rule now: immutable C1-v3 evidence may be reused while its
explicitly pinned input/code closure is unchanged. **The closure is the
`paths` roster of `t2_extreme_conformance_v3_authority.lua`** — the
existing authority roster, not a second informal list; because that
module is itself a roster member, a proven closure is also proof that
the roster applied is the recorded commit's roster. Reuse is granted
only after, in order and all fail-closed: the three pins are read from
the artifact's own bytes and shape-checked; the recorded commit is a
real commit object **and** an ancestor of `HEAD`; its tree is the
recorded tree; every closure member is byte-identical between that
commit and the current working tree; the roster's DAG at that commit
equals the recorded DAG; and only then the finalizer re-derives the
entire final blob from all 24 retained result files. **Byte equality of
the final TSV alone is never accepted** as proof of closure equality —
the pins parse identically out of an artifact whose rows were tampered
with. Any refusal falls through to the existing recompute path.

Two properties carry that argument, and the weaker one is the one a
reader reaches for first. Self-membership — the authority module is
itself a roster member — is true but insufficient on its own, because
the driver loads the authority from the *live* tree. What actually
closes it is the **DAG pin**: the recorded `conformance_dag_sha256` is
taken over the ordered `path`/blob-digest manifest, so a roster with a
member added, removed or reordered cannot reproduce it. That pins the
roster *list*, not merely the bytes of its members.

**One input is deliberately outside the roster**: the vendored
interpreter `tools/bin/lua51` is gitignored and built per checkout, so
it can never be a roster member — `capture_git` would refuse it. It is
pinned by a different mechanism, per row rather than by the closure:
`t2_extreme_conformance_verify.lua` re-hashes the live `argv[0]` against
every result row's `interpreter_sha256`, and the finalizer drives that
verifier for all twenty-four rows. A reader auditing "every closure
member is byte-identical" must not conclude either that the interpreter
is a hole or that the roster is exhaustive.

**Generation is not relaxed anywhere.** A first run still has to produce
all 24 rows from one clean, immutable commit/tree/DAG. Reuse is
announced with a token no other path prints, so reused evidence can
never be read as a fresh measurement.

The acceptance artifact now exists and records commit `5d770365`, tree
`52ec4f38`, C1-v3 DAG `52e2d459…`, and final SHA-256 `7ac6b7f9…`.
The acceptance closeout exercised the first, same-HEAD resume branch and
re-verified all 24 retained rows. The recorded-commit branch remains the
path for a later HEAD whose pinned closure is byte-identical; it was not
needed or falsely claimed by the same-HEAD resume.

### 12.7 Acceptance closeout (measured 2026-08-22)

The separately authorized run used the vendored PUC Lua 5.1.5 at
`/home/jan/projects/grudgelands/tools/bin/lua51`, SHA-256
`a1a427f38260513b64158630bc2b7d2fccfa31b48129efbfbcc60e02e4960a4f`.
Every row records conformance commit
`5d770365ed884b02c822b7183b4a7ad64ba611ff`, tree
`52ec4f388d39775d5dc68c1e5a244cdf310d4524`, C1-v3 DAG
`52e2d45938ef42ced13849f3c30662ef02491c96be8170f1258ecdc20aefcc3e`,
and execution Authority-DAG `f8f995d6…`.

The retained set is exactly 20 rescore rows, four selected-slot rows, and
`conformance-puc-v3.tsv`. The final artifact SHA-256 is
`7ac6b7f9678b53ffa64b6614b7a2926625e1cce53775101a2fd1ae37704fac20`.
Exact filenames, byte sizes, and hashes are committed in
`tools/wp40/evidence/t2-c1-v3-5d770365/artifact-manifest.tsv`; `run.log`
is the write-once fresh-run capture and `resume.log` is the separate
same-HEAD verification capture. `run-metadata.tsv` durably records the
commands, observed exit statuses, interpreter/compiler hashes, log hashes,
phase timings, and terminal tokens. The latter log ends exactly with
`WP40 T2 C1 v3 conformance resumed complete rescore=20/20 selected=4/4`
and contains no recorded-evidence-reuse token.

The selected phase completed in 5,507 seconds after the 215-second rescore
phase; including the mandatory preflight, repeated row verifications, and
finalization, the observed end-to-end wall time was approximately 99 minutes.
This replaces the former 95-minute projection for this host and chain. No
production code, topology rule, pool scalar, winner, or submodule pin moved.
The final status remains `stage2=pending_seed_corpus_promotion`; seed-corpus
promotion, T2-final, and T3+ are separate open work.

**Model-calibration record.** Coordinating/implementing model: GPT-5.6 Sol.
Independent pre-run reviewer: Claude Opus. Across the initial orchestration
review and its focused re-reviews: 0 Critical / 7 High findings, two fix
rounds, then `GO SAFE` / `APPROVE`. Observed acceptance wall time:
approximately 99 minutes (exact instrumented phases: 215 s rescore and
5,507 s selected). The independent post-run evidence review is recorded in
the closeout commit history and any resulting follow-up memo rather than
being anticipated here.

## 13. The R19 ordering-key metric alignment (cut 2026-08-22)

**The ruling.** [wp40-t2-plan.md](wp40-t2-plan.md) section 7.1's keys 4 and
5 — "the sorted set of resolved terminal world coordinates, lexicographic
by `(x, z)`", and the same for `previous` — are the authority. Production's
comparison of those two keys as the *rendered text* `x .. ":" .. z`
(`geometry/partition.lua`, `joint_tuple_less_compile` and
`joint_tuple_rank_census`) is an implementation defect, not a second
authority and not an alternate reading: 7.1 names the coordinate tuple, and
a renderer is not a metric. Production is aligned to the declared order.
Section 12.5 recorded the divergence and deliberately declined to close it;
this memo closes it.

**This is not a topology change, and the section 11.11 freeze is
untouched.** 11.11 froze the boundary machinery — corridor ownership, the
closing, residue adoption, the appendix predicate with `W`, the loop
pairing, ring connectivity, seam inheritance and the Whole gate — and
requires a new memo under the 11.6 discipline for a semantic change to any
of it. The comparator metric is none of those. What makes the distinction
real rather than asserted is the measurement below: no configuration in the
retained population is decided by keys 4 or 5, so not one measured station
moves. A memo is cut anyway, under the same discipline, because the surface
is frozen production geometry and the 11.6 rule is that the firing set is
measured *before* the ruling is implemented, never after.

### 13.1 Before and after, stated exactly

**Before.** The joint tuple descriptor carried `terminal_keys` and
`previous_keys` as canonical point *text*. Both comparators sorted those
strings, joined them, and compared the results as strings.

**After.** The descriptor carries signed integer coordinate pairs. Both
implementations sort by `(x, z)` and compare the sorted sequences
element-wise by `(x, z)`, and neither ever renders a coordinate to decide a
key. Key 6 is unchanged in every respect, including its `;` separator and
its canonical-orientation rule — 12.5 already aligned it end to end, and
this memo does not reopen it.

**Where the two orders actually differ**, so that the correction is read as
a real change and not a cosmetic one. Text and coordinate order invert
whenever the rendered tokens sort differently from the numbers:

- negative `x` of equal digit width — `"-1134:2242" < "-1135:2242"` as
  text, `-1135 < -1134` as a coordinate. These are precisely the two
  `land_010` stations of the R19 witness, which is how 12.5 found it — as
  coordinates, not as a measured competition: slot 29 resolves with exactly
  one complete tuple, so those two stations have never met under key 4;
- mixed digit width — `"10:z" < "9:z"` as text, `9 < 10` as a coordinate;
- a strict token prefix — `"12:3" < "1:5"` as text, because `"2"` sorts
  below `":"`, while `1 < 12` as a coordinate.

The sign boundary `(-1, z)` against `(0, z)` does *not* invert: `"-"` sorts
below `"0"`. A correction whose cases all inverted would be easier to
believe and would be wrong; the order agrees with the defect exactly as
often as it disagrees, which is why only a measurement settles the firing
set.

### 13.2 The fully measured firing set (the 11.6 obligation)

Measured before the alignment was implemented, on the committed census
shards, by `tools/wp40/t2_r19_order_projection.lua` (runner
`run_t2_r19_order_projection.sh`). The tool reconstructs every complete
joint tuple's D1 descriptor from the recorded `scan2_endpoint`,
`scan2_edge` and `scan2_tuple` rows — interval bounds, retreats, elbow
count, terminal set, `previous` set — then computes, for the recorded
winner against every competitor, the first differing key under **both**
metrics. It is fail-closed on every parse and consistency obligation
(field counts, coordinate and seed grammar, duplicate rows, tuple-index
range, `#tuples` against `tuple_count`, `#complete` against
`complete_count`, `duplicate_count = 0`, non-negative retreats, endpoint
agreement between the endpoint and tuple rows, each tuple's `index:mode`
present in its endpoint row's own success list, and
`compile_agreement = agrees` at every record).

It is also fail-closed on the *population*, which is a separate obligation
from per-record integrity and was added after review found it missing: the
first cut verified only that the shard filename ranges were contiguous, so
removing the leading or trailing shard, or truncating one mid-line, produced
a narrower measurement that still printed every PASS line and exited 0. It now
reads each shard's header, requires every shard of a version to agree on
`w_total` and `w_digest`, requires the sorted ranges to tile `0..w_total-1`
with neither gap nor overlap, counts the `seed_begin`/`seed_end` blocks in the
body against the declared `shard_seeds` and against `w_total`, requires the
`digest` trailer to be the last row, and is told which versions it must
measure so that a version with no shard is an abort rather than a silently
smaller population. Each version's report carries its own completeness line —
`v6 population w_total 4123 w_digest fc6c2c19… declared shard seeds 4123 seed
blocks 4123 coverage 0..4122 COMPLETE` — because a completeness proof that is
not printed is not evidence. The runner exits non-zero on a refusal and on any
`FAIL` verdict line.

A second review round then broke it again one level deeper, and that fault is
closed too. Every structural check counts *blocks*, so deleting whole records
from inside an otherwise intact seed block passed all of them: the tool
reported `coverage 0..4122 COMPLETE`, all four `PASS` lines and the verdict
sentence over 758 of 759 records, at exit 0. The material to catch it was
already in the artifact and unread — each shard's last row is
`digest<TAB>sha256=<hex>` over its own body
(`tools/wp40/t2_census_worker.lua`), so `head -n -1` of a shard reproduces its
trailer exactly. The runner now verifies all 24 before either interpreter
starts and refuses on a mismatch with its own exit status; measured cost
0.7–1.3 s. It also now requires every analysed version to describe the same
`W` — the per-version check could not see that, so the 757 → 759
reconciliation could have subtracted record sets cut from two different
universes — and requires the shards of one version to agree on
`census_commit`, `census_tree` and `module_digest`. Those three deliberately
must *not* agree across versions: three different commits produced v4, v5 and
v6, which is what makes them different censuses.

**The bound on that gate, stated rather than left implied.** The trailer is an
unkeyed self-hash, not a signature. It proves a shard is internally consistent,
never that it is the shard the worker wrote, so it catches truncation,
accidental corruption and naive editing but not someone who edits a body and
re-hashes the trailer. Measured: a re-hash forgery passes the digest gate,
though it still cannot hide structural damage, a header lie, or the arithmetic
— the record counts and the reconciliation deltas printed in 13.2 move visibly.
Closing it properly needs an authority outside the artifact, and there is none
today: the census shards are untracked, so nothing in the repository records
what their digests should be. That is an open item for whoever pins the
post-R19 evidence set, not something this package can settle.

It is byte-identical under LuaJIT and the vendored PUC 5.1; measured wall
3.6 s.

| measurand | v4 | v5 | v6 |
| --- | --- | --- | --- |
| seeds in shards | 4,116 | 4,123 | 4,123 |
| multi-complete records | 757 (reject) | 759 (select) | 759 (select) |
| per-edge 001/004/007/010/013/016 | 4/248/321/52/119/13 | 4/249/322/52/119/13 | 4/249/322/52/119/13 |
| `decided_by`, metric TEXT | — | key 1 at 759 | key 1 at 759 |
| `decided_by`, metric TUPLE | — | key 1 at 759 | key 1 at 759 |
| keys 4/5 load-bearing against any competitor | — | **0** | **0** |
| keys 1–5 tie against any competitor | — | **0** | **0** |
| TEXT and TUPLE winners disagree | — | **0** | **0** |
| reconstructed winner ≠ recorded `selected_tuple_index` | — | **0** | **0** |
| winner total retreat 0 / 1 / 2 | 730/25/2 † | 732/25/2 | 732/25/2 |
| completions per record 2 / 3 / 4 | — | 734/23/2 | 734/23/2 |

† The v4 column is head-count only — the tool deep-analyses v5 and v6. That
one cell is quoted from plan 7.1, not measured here, and is marked so that the
rest of the column's em-dashes are not read as an exception.

**The 757 → 759 reconciliation, measured rather than assumed.** v4's 757
and its per-edge breakdown reproduce plan 7.1 digit for digit, which is the
control. The record sets nest exactly: `v4 \ v5`, `v4 \ v6`, `v5 \ v6` and
`v6 \ v5` are all empty, and `v5 \ v4 = v6 \ v4` is exactly two records —
`343674299183575008 land_004` and `7851242355115945264 land_007`. Both are
section 8.5 D2 re-admitted seeds, first scanned post-correction; v4 carries
4,116 seeds against 4,123, the difference being exactly those seven
re-admitted seeds, of which these two carry a multi-complete record. Both
winners sit at retreat 0, which is why 7.1's 730/25/2 becomes 732/25/2. The
retained population is therefore **759**, and 7.1's 757 is a correct
pre-correction count, not an error.

**The 36 transition-edge resolutions.** Over seed 0, max-u64 and the four
winners, every one of the six transition edges resolves with exactly one
complete tuple and `decided_by = 0`. The oracle's summary print is gated on
`complete > 1 or total_retreat > 0` and therefore fires only at slot 29
(`land_010 = 1/0/1/1/0`); the suppressed content was measured rather than
inferred, by making that one print unconditional in a scratch copy whose
`edge_inventory_sha256` values reproduce the committed run's byte for byte.
12.5's "no ordering key was ever exercised" is confirmed by measurement.

**Two observations recorded, neither a finding.** The largest Cartesian
candidate product over the population is **6** tuples (seeds
`8191846033050687995` and `10940304306549215570`, both `land_007`), above
anything 7.1 quotes — but 7.1's bound is on *completions*, not candidates,
and the completion maximum is **4** (`3088496925377320678` and
`12067265980740904565`, both `land_013`), exactly as 7.1 measured. The
order is total for any multiplicity either way.

### 13.3 The expected real firing set is empty, and that is the point

Key 1 alone selects uniquely at all 759 records under both metrics. Keys
2–6 are exercised by no measured configuration — the same state 7.1
recorded for itself, now re-measured over the larger post-correction
population and over both metrics rather than one. Consequently the aligned
order **cannot** move a measured selection: the two orders can only differ
where key 1 ties, and key 1 never ties. The correction is a totality-tail
repair, and its real firing set is expected to stay empty until a seed
outside the retained population produces a key-3 tie.

### 13.4 The byte-preservation obligation

The alignment is accepted only against all of:

1. all 759 retained multi-complete records re-projected over `W`: every
   winner identical and the `decided_by` histogram key 1 only. Identity here
   is the recorded `selected_tuple_index` and `selected_station_count`, not a
   byte comparison — the census rows carry no probe raster, so the tool cannot
   compare bytes and does not claim to. Same tuple implies same bytes, and the
   bytes themselves are compared by obligation 2;
2. the 36 transition-edge resolutions over seed 0, max-u64 and slots
   28–31: every accepted output and all four winner digests byte-identical;
3. `tools/wp40/run_t2_s11_acceptance.sh` green with the accepted section
   11.11 pins byte-identical;
4. the synthetic comparator KATs isolating keys 4 and 5 after keys 1–3 are
   equal, driving **all three** implementations — both production
   comparators and the independent C2 oracle — in both authored
   orientations.

**What obligations 1–3 do and do not prove, stated so the digests are not
over-read.** They prove that nothing moved. They do **not** exercise the
aligned comparator, and that is not an inference: instrumenting both
production comparators to `error()` on entry and re-running obligation 2
produces a stdout digest byte-identical to the untouched run. With exactly one
complete tuple per edge, `if not selected or joint_tuple_less_compile(...)`
short-circuits and neither comparator — nor the descriptor construction, the
validators, the arity guards or the point orders — is ever entered. A
deliberately broken keys-4/5 comparison would pass obligations 1–3 unnoticed.
Obligation 4 is what exercises the change, and it is the reason the tripwire
may retire. Anyone reading the two preservation digests as verification of the
new comparator has read them backwards.

**The C2 tripwire retires only against a live cross-check.** 12.5 added a
named assert that fires when a selection was separated from any competitor
only at key 4 or key 5, because the two sides then used different metrics
and would otherwise have surfaced the disagreement as "independent final
station bytes changed" — a geometry message for a comparator cause. That
assert is removed only once all three implementations agree on
metric-separating KATs, and the `decided_by` and divergent-key diagnostics
survive the removal: what retires is the abort, not the observability.

### 13.5 STOP rules

Stop and report; do not re-pin, broaden the population, or edit a topology
rule to absorb the result:

- any retained record fires key 4 or key 5;
- any of the 759 winners, the 36 transition resolutions, the four winner
  digests or the section 11 acceptance fixtures moves a byte;
- the alignment appears to require a topology rule beyond the comparator
  metric;
- the two production comparators can only be made to agree by one calling
  or copying the other, or either by mirroring the oracle.

**What this memo does not do.** It does not re-rule 7.1's six keys, does
not touch the enumeration ban, does not change `W` or any topology rule,
and does not promote any pool. It must land before a full-`W` re-census or
any one-time post-R19 pool generation, because both would otherwise bake
the defective metric into evidence that is expensive to re-derive.

### 13.6 Integration audit-pin correction

The collected correction in commit `482a134` moved the authoritative
`bay_edge_transition_terminal_selection` wording from rejection on multiple
complete tuples to selection of the least complete tuple under the declared
total order. It also re-pinned the boundary-displacement and world-partition
policy checksums in the validator and independent Source KAT. The same commit
updated only the Source checksum presence pin in
`tools/wp40/t2_source_audit.sh`; the selection-literal presence pin and both
policy-checksum presence pins, all introduced together by `9a6ad8f`, remained
on their superseded values.

The static Source audit had therefore already been red since 2026-08-18, before
either package merged by this integration, and the schema-core runner that
invokes it could not be green. The integration verification surfaced this
pre-existing gate failure; neither the R19 ordering-alignment package nor the
T5-0 closeout caused it. After the first fail-fast literal check was repaired,
the same audit exposed the other two stale pins.

The audit now searches for the accepted prefix
`the_least_complete_joint_edge_tuple_across_the_full_finite_cartesian_set...`.
Its two policy-checksum presence checks now match the accepted validator/KAT
pins `ed1cd544...` and `528c03e3...` respectively.
This is a gate-pin repair only: it changes no catalog byte, validator rule,
compiler behavior, topology, evidence artifact or acceptance pin. The source
audit remains a presence check in the established style; exact full-literal
equality and exact policy checksums continue to be enforced by the production
validator and independent Source KAT.

The integration schema-core gate then exposed one independent, pre-existing
lexical false positive. The T0/T1 audits forbid a `tonumber(...)` argument that
contains `seed`, because a canonical unsigned-64 seed must never pass through a
Lua double. The rule matched the argument text `header.shard_seeds`, although
that field is the bounded shard row **count**, not seed identity; the result
local to the left of `tonumber` was irrelevant to the match. The conversion
remains valid and unchanged, but its argument now flows through `count_text`
and the result is named `shard_count`, with an explicit comment that it is not
seed identity. This preserves the broad uint64 safety audit without adding an
exception or weakening its pattern.

**Integration-closeout calibration record (2026-08-22):** implementing and
integrating model GPT-5.6 Sol; independent reviewing model Claude Opus; initial
review findings 0 Critical / 0 High / 2 Medium / 4 Low; one fix round; observed
elapsed wall time `unknown`. The fix round corrected the three historical
statements above and clarified the T5-0 package boundary. The two remaining Low
observations — stricter count-text grammar and a dedicated negative count test
— are pre-existing, behaviorally unchanged and outside this gate-pin closeout.

## 14. The T2 field handoff and Wave-1 execution freeze (cut 2026-08-23)

**Decision status.** The user recorded `ACCEPT PUC-1`, `ACCEPT D1-1`, and the
final `GO` on 2026-08-23. This later memo is the forward authority wherever an
older T2 contract memo describes a different C-a dependency, island-route
placement, or execution order. Older memos remain the historical record of the
packages they governed; their bodies are not rewritten.

### 14.1 C-a relief-field semantics

1. **Landmark composition.** Evaluate every landmark with positive Q16 collar
   weight in ascending `base_h_priority`, with the higher priority applied
   last. Each contribution qlerps from the previously composed `H` to that
   landmark's replacement height. Zero-weight collars are excluded. Exact
   authored mask membership remains the source integer predicate and stays
   separate from Q16 signed distance. The measured 264 ellipse incidences on
   which exact membership and signed-distance equality differ are evidence,
   not authority. C-a1 Stage 1 must prove that every exact mask, including its
   per-edge displacement margin, is contained in its owning final zone.
   **[Superseded by Section 14.5: this proof is C-a2's first gate.]** The
   current source validator checks only `zone_id` referential integrity at
   `validation/t2_source.lua:3964`; no current check enforces geometric
   containment. Composition never deletes mask identity. Required-route non-
   blocking is checked against final composed `H` and later route products,
   not a one-winner mask.
2. **Clipped junction support.** An authored relief junction `J` applies to an
   edge only when the chosen final raster terminal equals the authored
   junction coordinate exactly and the edge is an authored incidence there.
   Otherwise that endpoint supplies `native_G` and creates no substitute
   relief-`J` candidate. R14's categories remain intact: 34 surviving relief
   junctions contribute 98 ordinary incidences, the four dissolved degree-two
   junctions contribute eight Bay-transition incidences, and the eight
   perimeter attachments plus eight perimeter-vertex endpoints remain outside
   the 106-incidence relief-junction roster. Here, 98 counts ordinary
   incidences; its equality with Source Authority Section 2.2's 98 unordered
   incident-edge pairs is coincidental.
3. **Domain of `H`.** `H` is defined exactly on zone-owned authored surface
   columns: ordinary dry land, zone-owned Planned Water, and Section-11.7-B
   dry residue adopted into a zone face. It is undefined on exterior coastal
   shelf, deep ocean and immutable dragon channels, which use their separate
   `W`/d exterior profile. Internal relief evaluation fails closed there.
   Declared raw-dry overlaps on a shared edge or junction are resolved to one
   owner by the canonical half-open dry-face classifier before `H` is
   evaluated.
4. **Package boundary.** Within C-a, payload-free C-a1 lands before C-a2.
   C-a2 waits for D-1's zone records, the Section-11 ownership export, and a
   green C1 reacceptance. C-a2 consumes compiled Bay authority for Planned
   Water and adopted-residue authority for dry ownership; a
   `dry_faces`-polygon-only owner is forbidden.
5. **Residue ownership.** Section-11.7-B single-face residue adoption is
   zone-owned dry `H`, exactly like polygon-interior dry land. The ownership-
   handoff package exports sorted adopted intervals under their owning dry
   face. C-a2 consumes those bytes and never reconstructs the Whole gate or
   silently treats an adopted column as exterior.

The following existing arithmetic and boundary conventions are now explicit
C-a1 inputs. An authored capsule uses the longer-radius axis (x on a tie), an
axis-segment half-length of `long_radius - short_radius`, and a cap radius of
`short_radius`; the authored x/z radii are therefore its total half-extents.
Its exact boundary is inside. A centred total-width footprint uses
`[-floor(W/2), ceil(W/2))` on both axes, including the negative boundary and
excluding the positive boundary. Template radial distance is the lower-root
Q16 Euclidean distance from the anchor centre. Terrace rings use that outward-
from-centre radius:
`min(rings - 1, floor(radius_q16 / (step_run*Q))) * step_height*Q`.

Section 14.1's ordered positive-collar composition explicitly supersedes, for
C-a1 semantic interpretation, the consume-only legacy literals
`geometry_policies.relief_composition.landmark_overlap_rule`, its second
`evaluation_order` entry, and
`geometry_policies.landmark_masks.replacement_rule` in `source/catalog.lua`.
The current source validator's checks of those literals do not restore one-
winner semantic authority. C-a1 must neither edit the catalog or validator nor
treat those three values as implementation authority.

**Forward disposition:** Section 14.8 closes that cleanup and supersedes this
historical literal mismatch. The Source and fail-closed validator now carry
the ordered positive-collar vocabulary stated above.

The adjacent retained
`geometry_policies.relief_composition.landmark_priority_order` literal, whose
value is `greater_integer_priority_wins`, means only that greater priority
occupies the later composition position and therefore applies last. Its word
`wins` never selects one landmark or suppresses another positive collar. The
validator's literal check does not change that later-memo interpretation.

This `greater_integer_priority_wins` spelling is likewise superseded by the
Section 14.8 Source literal
`ascending_base_h_priority_higher_applied_last`.

A dedicated later **landmark source-policy cleanup** package must audit and
reconcile those policy literals before the production compiler or T2-final.
It should be batched before the already scheduled single C1 reacceptance only
if it requires no source edit and its audit proves that neither S1 nor the pool
moves. The no-source-edit STOP is independently operative because
`geometry_policies` is absent from the S1 projection: unchanged S1/pool results
cannot prove that the catalog or validator stayed untouched. Any required
source change or S1/pool movement therefore stops for a new reviewed ruling
rather than becoming an implicit C-a1 side effect.

**Cleanup closed:** the user-authorized result and its retained evidence are
recorded in Section 14.8. This paragraph remains the historical STOP rule that
caused the cleanup to be split out; it is no longer pending work.

The exhaustive landmark census, the focused junction measurement and their
representative derivations are evidence for this contract. Scratch paths are
not authority; retained package evidence must carry the reproducible cases it
claims.

### 14.2 D1-1 compiled slice and island-family reservation

D-1 compiles exactly 38 zone records, 57 land-route records — 30 primary, 24
secondary and three trails — and four public boat-route records.
`land_058` through `land_061` remain boundary-only and never become route
products. The 10 island route stations, eight island routes, 16 route
interfaces and four landings remain source-only until the Lane-C-b input-
matrix ruling assigns them. Their placement is an explicit open T2 obligation
that must close before Lane C-b starts.

Wave 1C reserves a dedicated, empty `island_routes` compiled geometry family.
This is a bounded world-format reservation, not a payload-only addition. It
authorizes only:

- `schemas.lua`'s `compiled` binding;
- `compiled_schema.lua`'s `EXPECTED_COMPILED_SCHEMA`;
- the `compiled_schema.lua` family list;
- the production compiler trust skeleton's `geometry_names` list; and
- the exact family lists in `t2_partition_test.lua` and
  `t2_schema_core_test.lua`, including the latter's schema-mismatch negative
  literal.

The user subsequently recorded `ACCEPT OWN-SCHEMA-1`. The same Wave-1C schema
event changes exactly these identities:

- `grug_wp40_compiled_world_v1` becomes
  `grug_wp40_compiled_world_v2` at `schemas.lua`'s `compiled` binding and
  `compiled_schema.lua`'s `EXPECTED_COMPILED_SCHEMA`; the mismatch negative
  becomes `grug_wp40_compiled_world_v3`;
- `grug_wp40_bay_v2` becomes `grug_wp40_bay_v3` at its emitter, closed payload
  validator and exact partition-oracle expectation because the record gains
  `connectivity_fill_count` and `connectivity_fill_xz`; and
- `grug_wp40_dry_face_v1` becomes `grug_wp40_dry_face_v2` at its emitter and
  exact partition-test expectation because the record gains
  `adopted_residue_interval_count` and `adopted_residue_z_first_finish`.

`grug_wp40_compiled_geometry_v1` and its existing v2 mismatch negative remain
unchanged. No other schema identity may move in Wave 1C.

It authorizes no compiler-implementation wiring, no population of
`island_routes`, and no schema-identity change beyond the exact list above. The
reservation does not place an island road and does not enlarge the frozen
57-record `land_routes` family.

D-1 keeps its analytic-record helpers local and validates the complete result
through the public `compiled_schema.canonicalize_compiled` path. It does not
add or depend on an exported `compiled_schema.validate_analytic_records`;
helper validation remains internal to `compiled_schema.lua`.

### 14.3 Authoritative execution order through C-a2

1. Phase 0A is first: durably freeze Sections 14.1 and 14.2 plus this ordered
   dependency plan, then obtain its independent review before implementation
   begins.
2. After Phase 0A is integrated, payload-free C-a1 and the **Section-11
   ownership-handoff schema package (Wave 1C)** may run in parallel. Phase 0B
   owns the complete PUC-1 mechanical closeout and one atomic policy/evidence
   fold; it may prepare code and policy in parallel with those packages, but
   Phase 0A does not partially rewrite the project-wide wording.
3. Integrate the ownership handoff first. It intentionally changes partition
   and schema and therefore the compiler/worker PCC digests. Phase 0B's final
   compiler/worker fixtures, retained evidence, green status and integration
   must be produced on that integrated provider, or be identically regenerated
   and rebound after it. Only then integrate the reviewed Phase-0B fold.
4. D-1 starts only after that Phase-0B fold is green and integrated. C-a1 may
   already be implemented and reviewed, but it and D-1 integrate only after
   D-1 is green.
5. Integrate C-a1 and D-1 in dependency order. Before long PUC work, run the
   landmark source-policy cleanup audit; batch that cleanup into this gate only
   if it requires no source edit and neither S1 nor the pool moves, otherwise
   obey Section 14.1's STOP. This separate source-edit condition is necessary
   because `geometry_policies` is absent from the S1 projection. Then run the
   selected four under LuaJIT plus the nonzero connectivity-fill and adopted-
   residue witnesses. If that preflight is green, run exactly one fresh C1-v3
   PUC reacceptance for the integrated Wave-1 state.
6. C-a2 runs serially only after D-1, the ownership export and the C1
   reacceptance are green. The authorized mandate ends after C-a2 integration
   and stops before Lane C-b.

The ownership handoff exports both hidden Section-11 results: connectivity-
closing water under its Bay owner and adopted dry-residue intervals under
their dry-face/zone owner. No extra C1 run is bought solely for the Phase-0B
PUC policy package; the one integration reacceptance above covers the planned
ownership/schema event.

### 14.4 Phase-0A review closeout and calibration

**Review-closeout calibration record (2026-08-23):** non-trivial
documentation/process-authority package; implementing model GPT-5.6 Sol;
independent reviewer Claude Opus/xhigh; initial findings 0 Critical / 1 High /
0 Medium / 9 Low; one fix round; observed elapsed wall time `unknown`. The fix
round closes the false present containment claim (H1) and L1--L8: priority-
order interpretation, source-edit/S1/pool STOP, Wave-1C label, both compiled-
world identifier sites, historical review provenance, planning-record wording,
the engineering-brief wrap, and the two distinct 98-count measures. Any
subsequent re-review outcome is appended only by the coordinator if needed.

### 14.5 CA1-DAG-1 containment-gate correction (decided 2026-08-23)

The user recorded `ACCEPT CA1-DAG-1` after the first C-a1 implementer correctly
stopped without edits: no final-zone ownership provider exists in C-a1's
allowed payload-free dependency set. Loading `geometry/partition.lua` was
forbidden, while recreating its Bay, Wing, aperture, half-open and residue
classification would have introduced a second final-zone authority.

This later memo supersedes Section 14.1's former assignment of geometric
containment to “C-a1 Stage 1.” C-a1 still proves exact mask predicates, Q16
collars and ordered landmark composition, but makes no final-zone containment
claim. After D-1, the ownership handoff and the single C1 reacceptance are
green, C-a2's first fail-closed integration gate proves that every exact mask,
including its per-edge displacement margin, lies in its owning final zone. It
must consume the package-local `surface_owner_at(x, z)` projection over the
accepted integrated `grug_wp40_compiled_world_v2` records. That projection is
not a new serialized family: it applies the canonical per-column precedence to
compiled Bay-v3 Base/notch/connectivity data and owner spans, closure-wing and
mouth-aperture/perimeter ownership, dry-face-v2 polygon and adopted-residue
ownership, and the half-open seam tie. “Not polygons alone” forbids omitting
those water, residue and seam inputs; it does not forbid polygon membership as
the ordinary-dry input. A missing or insufficient compiled input is a STOP
before `H` assembly, not permission to widen C-a1, rebuild partition
connectivity or invent a second classifier.

The containment proof is a retained, seed-independent C-a2 acceptance KAT over
every authored exact mask plus the maximum legal displacement envelope of each
incident edge. It proves the authoring invariant for every legal seed; it is
not an exhaustive per-seed runtime scan. The seed-specific
`surface_owner_at(x, z)` projection still fails closed on zero or multiple
owners inside the defined `H` domain.

C-a1's executable dependency envelope is limited to its new payload-free
modules, `canonical.lua`, `deterministic.lua`, `exact.lua`, the validated
Source relief/template/landmark records and the injected raw-SHA seam. It may
inspect the S1/C1 files for parity but may neither load `partition.lua` or a
compiled ownership payload nor consume D-1 records. Those paths and all source
authority remain consume-only.

The user recorded `ALLOW CA1-DAG FIX-2` together with `ACCEPT OWN-SCHEMA-1` so
the final focused review round could close the previously missing schema
authorization without weakening the containment gate.

**Review-closeout calibration record (2026-08-23):** non-trivial
documentation/process-authority correction; implementing model GPT-5.6 Sol;
independent reviewer Claude Opus/xhigh; initial findings 0 Critical / 1 High /
1 Medium / 4 Low; first focused re-review 0 Critical / 0 High / 1 Medium /
3 Low; two fix rounds; final focused re-review 0 Critical / 0 High / 0 Medium /
0 Low (`APPROVE`); observed elapsed wall time `unknown`.

### 14.6 Wave-1C ownership-handoff closeout (2026-08-23)

The accepted ownership provider is the reviewed
`grug_wp40_compiled_world_v2` / Bay-v3 / dry-face-v2 package merged after
commit `972b339`. It exports connectivity-closing water and adopted dry
residue without reconstructing either authority, reserves the empty
`island_routes` family, and leaves compiled-geometry v1, Source, S1, the
candidate pool, winners and the prior C1 evidence byte-unchanged. The three
package geometry-compile attempts and the retained 128.58-second capture ran
on implementation commit `66f2a11` (tree `e75046c4`); the later fail-closed
dry-face roster, empty-ID refusal and shared-comparator validation were tested
only by focused dual-interpreter KATs and by no geometry compile in this
package. The coordinator therefore ran one bounded LuaJIT smoke compile on the
integrated provider at `04139a2`: seed 0 completed green in 78.96 seconds with
4 Bays, 38 dry faces, zero connectivity-fill columns, zero adopted-residue
intervals, 639,512 SHA calls and 1,004 misses. This was an integration
preflight, not a fourth ownership-package evidence run. Phase-0B may now
regenerate its fixtures on this provider.

Two final-review Lows are accepted without another package fix round. The
authority-side exact-duplicate class has no dedicated committed KAT, but the
same bytes necessarily reach and fail the retained overlap guard; this cannot
admit invalid bytes. Compile attempt 1 lost its payload and its historical
“provider bytes / pre-change” label cannot be reconciled from retained
artifacts with the later commit attribution. It supplies no accepted value,
digest or backward-invariance claim, so no downstream decision may cite it as
measurement.

**Review-closeout calibration record:** implementing model GPT-5.6 Sol;
independent reviewer Claude Opus/xhigh; initial findings 0 Critical / 0 High /
1 Medium / 7 Low; first focused re-review 0 Critical / 0 High / 1 Medium /
1 Low; two user-authorized fix rounds; final focused re-review 0 Critical /
0 High / 0 Medium / 2 non-blocking Low (`APPROVE`); observed elapsed wall time
`unknown`.

### 14.7 PUC-1 atomic policy/PCC closeout (2026-08-23)

The user accepted `PUC-1`; this later memo is the final interpreter authority
where older wording conflicts. In particular it supersedes Section 11.4 item
5's phrase “rides its comprehensive PUC round” and every historical reading
that would execute a complete seed population under standalone PUC.

The project-wide split is exact:

1. **LuaJIT owns exhaustive populations and development loops.** The final
   full-`W` re-census (schema v7 / artifacts v4) runs its complete 4,123-seed
   population under LuaJIT at T2-final. The same rule applies to any T9-final
   exhaustive population. Its publication merge still runs both interpreters
   through `run_merge_pair`; the five canonical artifacts must be
   byte-identical, and the PUC half retains the fail-closed `pairs()` probe.
2. **Intermediate PUC coverage is targeted.** Representative PUC KATs compare
   canonical stdout, complete artifact bytes or explicit digests with their
   LuaJIT equivalents. Static plain-5.1 syntax and do-not-write gates remain
   mandatory on every Lua change. Complete LuaJIT artifacts remain the
   population authority.
3. **The final standalone-PUC gate at both T2-final and T9-final is bounded.**
   It is exactly `tools/wp40/run_t2_puc_core.sh --all` plus the two retained
   rounds F1 and F2:

   ```sh
   WP40_FINAL=1 tools/wp40/run_t2_partition.sh --no-cache --historical
   tools/wp40/run_t2_extreme_conformance.sh
   ```

   No full-`W` population, separate six-candidate selector leg, or ad-hoc
   witness may be added under standalone PUC without a later user ruling and
   owning contracts memo.
4. **Engine evidence stays separate.** Neither the PCC nor F1/F2 satisfies the
   real bundled-Lua fallback-engine runtime test or the engineering brief's
   dual-runtime engine benchmarks.

The checksum-pinned PCC comprises five semantic micro-groups (seed-width and
arithmetic boundaries; canonical serialization; `pairs()` control flow;
boundary/negative guards; silent-escape plus exit discipline), targeted Source
parity, the K7/K8/K9 unit/comparator layer, and these production full paths:

- compiler witnesses `1959553668008863006` and `2147483648` through
  `partition.compile`;
- worker witnesses `2147483648` and `16178445837170081103` through
  `partition.census_scan`;
- the fixed seven-seed merge carrier `0`, `2147483648`,
  `343674299183575008`, `1959553668008863006`, `15219119262482319357`,
  `16178445837170081103`, `18446744073709551615`, including fail-closed
  unsorted-order probing plus synthetic and measured invariance; and
- the already-completed C1-v3 F2 carrier for selector breadth. F2 parses and
  ranks the complete retained pool, independently rescores its fixed 20 rows
  including candidates 0 and 4095, and compiles selected slots 28--31. It
  replaces the inventory proposal's separate widened six-candidate leg.

`tools/wp40/fixtures/t2_puc_core/manifest-v1.tsv` owns the selection and
fixture digests. Any corpus, witness, fixture-byte or digest change requires a
later memo in this file; “representative” never permits an ad-hoc re-pin.
`tools/wp40/evidence/t2-puc-core-v1/` retains the run calibration and raw
runtime telemetry. Worker and other semantic stdout is never normalized. The
merge report alone replaces its exactly one leading, host-specific interpreter
identity with `WP40 T2 census interpreter: <LuaJIT>` after an early preflight
has proved that the configured LuaJIT is genuine and distinct from PUC; every
remaining byte is exact. The standalone optional-load runner keeps its honest,
adaptive locale report. At the PCC boundary, exactly one trailing success line
must prove that both `LC_ALL=C` and one real non-C locale arm ran; zero,
multiple, malformed or non-trailing success lines fail. Only the discovered
locale token is replaced with `<non-C>` before fixture comparison. For the
worker pair,
both exits must be equal and zero; stdout and the complete two-seed TSV must be
byte-identical; the external SHA and internal trailing digest must agree. Raw
stderr is retained separately and must contain exactly these two anchored
seed/index lines, in order and with no extras. Only the terminal
` wall=[0-9]+s cpu=[0-9]+\.[0-9]s` values are removed for the cross-runtime
telemetry comparison. Focused self-tests prove that malformed, extra or
reordered telemetry, stdout drift, record drift and equal/non-equal nonzero
exits all fail.

**Phase-0B measurement on the integrated ownership provider.** The input was
commit `62afc64e598129e6e069d26a7746073a96673ccd`, tree
`6366c5e1457886d7c32f53e08f6c10e9669d9b86`. The compiler pair completed in
69 s LuaJIT + 1,734 s PUC = 1,803 s; its compiled digests are
`6dcd5da40ac730f6ae5973cfc8b8845c03eaac8481dfe15b597aafd30d86c402`
and `36c5ce5a6a67f8f2559eea47751579fe3791e5f9c075cfe1d18076bae4032b77`.
The worker pair completed in 132 s LuaJIT + 2,325 s PUC = 2,457 s; its
complete-record SHA-256 is
`2eac453bb1f7f0f4fd23693a3bd717b5d4f8ba6f5c0a84342d0b1b01fc86be90`
and internal digest is
`047d6fefbe937512efda38fd5b8d245e7ac2399e546e215387d3eac54d4666c8`.
The seven retained per-seed worker wall counters for the merge carrier sum to
346 s. The exact whole-leg wall was not retained and is strictly larger because
the dual-runtime merge and final gate follow the worker phase; the complete run
passed its 420 s cap and recorded all three invariance halves green, with
artifact digest
`fcc5ad01d4366af1269bbbe98415aad2bd596fb82f33625a15b5b4957236b795`.
The full Source harness ran under LuaJIT and its targeted PUC projection KAT
was byte-identical. Optional-load behavior was byte-identical across both
interpreters and both available locales. Its normalized canonical fixture has
SHA-256
`c87444bfa7810a1d2fa42f99b724c378395201c20586197efbda9352f48e2959`;
the retained raw evidence continues to name the host's actual non-C locale.

F1, F2, full-`W`, C1 reacceptance and any population under PUC did **not** run
in Phase 0B. F1 remains deferred to the final gate. The existing F2 evidence is
already green: 20 PUC rescores took 215 s, four parallel selected slots took
5,507 s, and the chain took approximately 99 minutes end to end. The next C1
reacceptance remains the single integrated Wave-1 gate from Section 14.3, not a
Phase-0B rerun.

**Completion calibration record:** non-trivial policy/executable-evidence
package; implementing model GPT-5.6 Sol; independent reviewer Claude
Opus/xhigh. The initial review found 0 Critical / 0 High / 2 Medium / 6 Low;
the first mechanical fix round is implementation commit
`ee4478bc4210b0be75661152a9c1f240f53a36ce` (tree
`b91ba958bf7643c6a9c39eea3581a1b56aa7690d`). The first focused re-review
found 0 Critical / 0 High / 1 new Medium / 2 Low-or-Informational; the second
narrow fix round is implementation commit
`c0dcbae512d4dd579281d1321922b5fdade8a74a` (tree
`9ddcf633529ebbe670311ca541f0ba96ead6eccd`). The second focused re-review
found 0 Critical / 0 High / 0 Medium / 0 Low and returned `APPROVE`.
The observed capture interval was approximately 6 h 43 min, including two
user-authority pauses and the heavy runs.

### 14.8 LM-SOURCE-1 landmark source-policy cleanup (2026-08-24)

The user recorded `ACCEPT LM-SOURCE-1; GO` after Section 14.3's required
landmark audit found that the four old one-winner literals needed a real Source
edit. The bounded package changes exactly these checksum-covered values:

- `landmark_overlap_rule` is
  `compose_all_strictly_positive_Q16_collars`;
- `landmark_priority_order` is
  `ascending_base_h_priority_higher_applied_last`;
- relief composition's second `evaluation_order` entry is
  `all_positive_landmark_collars_qlerp_previous_H_to_replacement_H`; and
- `landmark_masks.replacement_rule` is
  `qlerp_previous_H_to_replacement_profile_height_by_own_positive_collar_weight`.

These are vocabulary corrections to the already accepted Section 14.1
semantics. They do not change landmark rows, geometry, arithmetic, the C-a1
evaluator, partition, schemas, compiler rosters, C1 inputs or winners. Stage 1
continues to reject any different literal, duplicate priority or malformed
order. The existing C-a1 executable KATs remain the arithmetic proof: all
positive collars compose in ascending priority from the preceding `H`, higher
priority applies last, zero weight performs no replacement evaluation, and
duplicate source or selected priorities reject.

The exact Source checksum moves from
`f4a7e41605b3defe068095424a4b99e78e657ae508d1ef07e5b3c6bb36884558`
to
`87540c49d629eb81164c18e906c23cabbe03eddb429f7ba647c60b650951cd6e`;
the landmark-mask policy checksum moves from
`99535a1033607d7f0b327bbce859d2e578d8b42ddc76cc2cb8a80dbdaa385f1e`
to
`1a34cefb67cefdb25886eb3ebfa6977b63c3e543cddfa793c4a4e27c890334b9`.
The corresponding targeted PCC Source fixture and its one manifest digest move
with those accepted bytes; no PCC selection, other fixture or execution leg
changes.
The S1 projection remains `83b1b16a...ddd652`, the S1 authority remains
`10a790a6...db37c`, and all six lock blobs are byte-identical. The authored
D-1 fixture rebinds only its Source checksum. The max-u64 R16/R17 prerequisite
fixture rebinds its Source checksum and, at integration closeout, its stale
partition/full-compiled pins. The accepted ownership/schema handoff is the
only compiled-family movement: removing its Bay-v3 connectivity fields and
dry-Face-v2 adoption fields plus the two record-schema bumps reproduces the
old Seed-0 and max-u64 R17 digests exactly. All 71 other extreme-fixture files,
including every pool, candidate, rescore and selected-winner artifact, remain
byte-identical to the pre-cleanup tree. Candidate artifact, candidate-row
digest, four winners and selected evidence therefore remain byte-identical.
The retained reproduction record is
`tools/wp40/evidence/t2-landmark-source-v1/`.

This package is **non-trivial** under the project model policy: it changes
checksum-covered Source contract vocabulary and its fail-closed validator,
despite leaving arithmetic and topology untouched. Independent Opus review
found one package Critical, two package Highs, two Mediums and three package
Lows, plus one inherited High and one inherited cosmetic Low; the single
authorized fix round closes the fixture/provenance gaps here, while the
coordinator owns the independent re-review and final calibration result.

The C-a1 `t2-fields-v1` evidence manifest remains an immutable historical
record of its tested tree; its old Source/validator hashes are inputs of that
past run, not current authority. Current C-a1 reproduction is recorded by the
LM-SOURCE evidence and `tools/wp40/run_t2_fields.sh`, so rewriting the old
manifest would falsely move its provenance. Likewise the engineering brief's
explicitly historical pre-R7 paragraph retains its stale use of “live pin” as
an inherited cosmetic wording defect; Section 14.8 is the current authority.

This package does not itself authorize the deferred C1 reacceptance; Section
14.3's ordered integration gate still does.
