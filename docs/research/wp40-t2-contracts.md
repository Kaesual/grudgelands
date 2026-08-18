# WP40 T2 package contracts

Status: **contract file. Created 2026-08-18 by the plan's own relocation
rule.**

[wp40-t2-plan.md](wp40-t2-plan.md) holds ordering and decisions; this file
holds package specifications — the census artifact contract (section 6) and
the collected-correction implementation contract (section 8). The numbering
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
full width, first-record validation, rolling cost gate against the
section-6.5 nine-hour cap, verified resume, worker-death watch) and under
**LuaJIT** per the interpreter split. It starts only after 8.2–8.4 are
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
   the D1 synthetic key KATs, the seven D2 witnesses and the five census
   KAT seeds — byte-compared by digest between interpreters. No
   comprehensive PUC round (reserved for T2-final, per the interpreter
   split in the brief and [luanti-lua.md](luanti-lua.md)).
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

### 8.7 Cost and division of labour

Section-4 anchors govern every launch; any run projected over ~30 minutes
wall, and any fleet run, is announced first with the projection marked as
a projection. The semantic core — catalog strings, both comparators, the
shoulder construction, the source-authority edits — stays in-session
(Fable). Mechanical parts — KAT plumbing, gate-suite reruns, fleet
babysitting, the v5 merge — may go to Opus subagents (user authorization
2026-08-18), briefed by goals with a cost cap and a stated verification
tier. Parallel Lua processes stay within the host's measured eight-worker
band.
