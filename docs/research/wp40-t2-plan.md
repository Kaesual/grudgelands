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

1. **Census scans 1 and 2** — interval/attachment/junction and R19 tuple
   occupancy. Scan-1 has a seed-independent prefilter that permanently
   discharges most ordinary edges.
2. **One collected correction** closing every occupied reject class plus U1,
   U2 and O1, followed by **one** compiler reproduction.
3. **Census scans 3 and 4** — terminal/wing/trace, then Face/Whole on the
   flagged, extremal and winner seeds only.
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
| `run_t1.sh` | 0.18 s |
| `luac51 -p` plus the five grep sweeps, whole owned set | 0.007 s |

PUC-to-LuaJIT ratio is **not** a single number: measured 2.8x on
validation-heavy paths, 16.2x on an exhaustive numeric sweep, and 26.5x on a
full seed-0 compile (868/32.7). Any plan resting on one extrapolated ratio has
been wrong before.

## 5. Open items not owned by a package

- **U1, U2, O1** — the complete undecided set from the completeness analysis
  (its sections 3-F2 and 3-F9). Characterised, because "U1" alone tells a
  reader nothing:
  - **U1** is a live contradiction between two policy strings.
    `bay_edge_transition_terminal_complete` requires a nonempty combined
    contiguous control subsequence per tuple; the R18-level
    `shared_boundary_incidence_reject` lists an empty subsequence as
    reject-without-fallback. On a seed where one tuple has an empty combined
    clip and another completes, the first reading accepts — the empty-clip
    tuple merely fails while the seed survives via the completing tuple —
    and the second rejects the whole seed. Which is authoritative is not stated. This is a
    decision, not a documentation fix, and it should be made before the
    collected correction is written rather than inside it.
  - **U2** asks whether a one-station raster can satisfy "unique,
    8-connected", which arises when a two-ended tuple's candidate incidences
    coincide or cross, yielding in the limit a single-station probe. Practically
    vacuous, since Stage 2 hard-rejects final edges under 192 station steps
    (completeness analysis section 7.4) — but *which stage* rejects is the same
    kind of ambiguity R16 was made of, so it wants an answer rather than a
    shrug.
  - **O1** is a proof obligation rather than a gap. Aperture-versus-attachment
    collision is decided by evaluation order, aperture precedence first, and the
    interesting claim — that the collision is unreachable, because *every*
    attachment sits hundreds of nodes from *every* aperture while displacement
    is bounded by 96/64 with tapers — is
    asserted nowhere. Either a Stage-2 margin assertion or one sentence
    declaring the order-based outcome intended closes it. Until then it is
    formally decided and semantically unreviewed. (Scheduling note, mine and
    not the analysis's: U1 should be decided before the collected correction
    is written, not inside it.)
- **A targeted `pairs()`-order divergence test**, as the cheap substitute for a
  full PUC gate at every stage freeze. The canonical encoder sorts before
  emission, so serialisation is provably runtime-independent; control flow that
  depends on iteration order is the residual risk and can be tested directly.
- **The invariant review** named in the completeness analysis section 7 — the
  only bound against silent wrongness, the mechanism behind seven of the
  thirteen corrections so far, and behind three defects found on 2026-08-15
  alone: the vacuous ripgrep gate, the payload-cache regression, and a
  verification run that reported success with zero workers started.

## 6. The census artifact contract

The census is not a search for bugs. It is the step that converts an
open-ended discovery process into a finite work list, and everything about its
output shape follows from that. R11 through R19 each cost roughly a day
because each was found alone, by an expensive reproduction, and closed before
the next one could surface. The census exists to produce all of them at once.

If its output does not support that, the run is wasted even when it completes.

**Scope.** This contract governs Scans 1 and 2. Scans 3 and 4 produce further
quantities named in the completeness analysis section 5 and need their own
clauses before they run; the plan's ordering puts a collected correction
between them, which partly invalidates anything produced earlier, so one
contract cannot span both sides of it.

**Unresolved, and it must be resolved before the scans are built.** Section 6.1
keys rows by local configuration, on the strength of the analysis's dedup
paragraph. But its section 1 states that R19 tuple selection (scope: selected
interval plus bay envelope) and bank tracing (scope: trace history plus bay
envelope) are *not* bounded-local. So for F2 and F3 — the two expensive
families — the key is either the full envelope, in which case no seed
multiplier collapses there, or a truncated neighbourhood, in which case two
seeds sharing a key can reach different decisions and the occupied-class table
is unsound. The dedup paragraph does not carry section 1's caveat and neither
did the first draft of this contract. Decide it, per family, before writing a
scanner.

### 6.1 The unit is a configuration, not a seed

Key every row by **(site, local-configuration bytes)**, never by (site, seed).
Sites realize identical local neighbourhoods across many seeds, so
configuration keying collapses the seed multiplier and matches the hypothesis
under test — which is about configurations the policy does or does not decide,
not about seeds. Retain, per distinct configuration, the count of seeds that
realized it and the lexicographically least realizing seed as its witness.

A scan that emits one report per seed has produced 4,130 reports and no list.

### 6.2 Required outputs

Four artifacts. Scan-2's own design is a cheap counting pass followed by
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
   the minimum and maximum of that site's local scalar; note that `local_scalar_q`
   is defined per edge station and has no meaning yet for junctions, wings,
   apertures or banks, so the extremal criterion needs a per-site-kind
   definition before it can be computed. Every R-series trigger so far was an
   extremal seed.
4. **The prefilter discharge list** — every site the seed-independent
   prefilter discharged, with the reason. Cheap to regenerate, but without it
   the occupied-class table cannot distinguish "this class was never occupied"
   from "this site was never scanned", which is the table's entire claim.
5. **Distribution histograms** named in the completeness analysis section 5 —
   interval counts per edge, attachment Chebyshev distances, junction-pair pass
   rate, fill counts per bay, and the joint (eligible, R16-success, complete)
   distribution per transition endpoint.

### 6.3 What must be reproducible, and what must not be retained

Commit the four artifacts above and the manifest that pins what produced them:
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

The fourth is the one an occupancy table hides. `Chebyshev(K,J) > 4`, `R > 5`
and `w = 0` are current source bounds asserted over all seeds; a seed
exceeding one is neither a rejected class nor a vacuous branch, so it must be
recorded as its own class. This is mechanism (c), the failure mode R16 itself
was, and the census is where it is cheapest to catch.

Occupancy of an ordinary DECIDED class is not a finding, however unusual it
looks.

### 6.5 Cost

Do not anchor on the 10.7 s in section 4: that figure is S1 *selector scalars*
only, while Scan-1 additionally performs the per-record R7 compile — up to 97
reraster probes across 63 records — plus roughly 10^5 station predicates. The
nearer anchor is the 32.7 s LuaJIT seed-0 compile, and even that is a floor.
Anchoring low is exactly what section 4 exists to prevent.

Measure one seed before launching the set, and state in the run manifest both
the measured single-seed cost and the projected total, **in wall time at a
stated worker count** — section 4's anchors are worker-seconds and mixing the
two silently changes any threshold by roughly 8x. The prefilter is expected to
discharge most ordinary edges permanently, so the real figure should fall well
below a naive multiplication.

A stop threshold is a judgement call and should be recorded as one rather than
presented as derived. Two things bound it from either side: the largest routine
measured run here is the 91-minute pool, and what the census replaces is
roughly a day per finding through the reproduce-diagnose loop. A cap tight
enough to forbid several hours would be worse than the process it replaces.
Propose the number with that comparison written down, and treat exceeding it as
a reason to report and re-scope rather than to abandon.
