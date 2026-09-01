# WP40 R7 Pragmatic Acceptance Plan (Temporary)

Status: **temporary coordination plan for the next R7 session**  
Decision date: 2026-09-01  
Owner: WP40 R7 coordinator  
Lifecycle: delete this file after R7 acceptance; fold the final evidence boundary
into the R7 completion record and update the authoritative status documents.

## 1. Decision and reason

The user approved replacing the exhaustive R7 acceptance fleet with a bounded,
release-oriented sample. The exhaustive design would evaluate all 8,075
horizontal owners for each of 32 seeds through three production-owned
projections. The measured pilot rate projected approximately 35--40 hours of
fleet wall time with seven workers. That cost is disproportionate for an MVP
game world after the stronger corruption, determinism, transaction and
compatibility gates have already passed.

The full seed-17 pilot was stopped on 2026-09-01 at the user's direction. It
did not produce a canonical pilot projection. Its partial stream under `/tmp`
is diagnostic scratch only and is neither acceptance evidence nor an input to
the replacement sample.

R7 will now prove release safety and representative content behavior. It will
not claim exhaustive population, exact global density or exact global faction
parity over every coordinate of all 32 seeds.

## 2. Evidence that remains binding

The pragmatic sample does not replace or weaken these already required gates:

- exact source/configuration and dependency-graph audits;
- zero legacy geography writers and one atomic R7 writer/publication path;
- plain Lua 5.1 syntax, zero unintended globals and all five compatibility
  sweeps;
- the frozen LuaJIT/PUC 5.1 final micro-KAT parity over every changed
  production Lua module;
- the real LuaJIT integration proof, including one VM transaction, read-only
  replay, the full seven-field private owner buffers, exact Stage A removable
  P9G parity and exact Stage B accepted-R6 normalization;
- focused coverage of every P9G source and rejection reason, query and owner
  boundaries, protection, support, multi-y ownership, non-overwrite and
  no-refill behavior;
- the closed P9G-only dry-island rule: exactly the Wyrmglass and Stormscale
  coast-exclusion IDs may be nonblocking only when authenticated
  `column_values_at(x, z)` reports `water_class == "land"`, while every earlier
  exclusion and later settlement gate remains unchanged;
- fail-closed behavior on invalid settings, identities, content, manifests and
  authority installation.

Existing immutable evidence remains in `docs/research/`. It is replaced only
when an input covered by that evidence changes under the repository rules.

## 3. Replacement 32-seed sample

### 3.1 Target population

Run all 32 frozen seed slots, but evaluate a target of **128 horizontal owners
per seed**, or **4,096 `(seed, owner)` cases** in total. Split the canonical
case roster across at most seven independent LuaJIT workers. Each worker gets
private scratch output; a deterministic finalizer validates exact roster
coverage and produces identical bytes when worker descriptors are reversed.

The frozen composition per seed is:

1. 104 interior owners on a fixed 13-by-8 stratified spatial lattice;
2. 24 distinct fixed risk owners: twelve accepted Cultural-witness owners,
   four clipped map corners, the Stage-A/B and multi-y integration owners, two
   apex owners, two route/water-interface owners and two coastal housing
   owners. The broader connection channels remain covered by the already-
   binding focused/integration gates rather than this sampled-owner roster.

The roster constructor must be cheap. It may use already authenticated fixed
geometry, durable R6 witnesses and bounded production-owned queries. It must
not perform a hidden full-world scan merely to choose the sample. The fixed
lattice is therefore authoritative; record the zone/logical-biome strata it
actually reaches as measured coverage and do not fabricate missing labels.

Deduplicate owners canonically. If deduplication reduces a seed below 128,
fill it with deterministic seed-keyed owners from the frozen 8,075-owner
roster. The final roster, algorithm/version, SHA-256 and achieved coverage are
acceptance inputs.

### 3.2 Hard release blockers

The sampled run fails R7 if any case shows:

- a crash, invalid schema, invalid node/content identity or non-canonical
  output;
- nondeterminism between repeated/order-varied execution or forward/reverse
  combination;
- a Stage A or Stage B mismatch;
- an illegal overwrite, overlap, retry/refill, owner-routing error, protection
  violation or wrong final cell tuple;
- more than one VM transaction, a replay difference or a mutable-input drift;
- a missing eligible/budgeted/accepted population for any of the eight
  non-frontier P9G sources across the complete 32-seed main sample;
- loss of the already accepted six Cultural access identities;
- absence of representative paired-faction access owned by the main sample;
- a gap, duplicate or unexpected case in the exact 4,096-case roster.

Any hard failure is fixed and the affected frozen evidence chain is rerun. It
is not deferred as a post-release balancing issue.

### 3.3 Separate frontier-access lane

Crimson Lotus, Stormkelp, Wild Cocoa and Rock Salt are not repaired by swapping
owners into the 128-owner main sample. They have one separately scoped,
successor-only lane covering the fixed frozen seed slots
`1, 6, 11, 17, 22, 27, 32` over this literal static roster:

| Scope | Inclusive envelope | Aligned 80-by-80 owner origins | Owners/seed |
|---|---|---|---:|
| Gravesalt | `x=-2500..-1200`, `z=-250..250` | `x=-2512..-1232`, `z=-272..208`, step 80 | 119 |
| Skyglass | `x=1200..2500`, `z=-250..250` | `x=1168..2448`, `z=-272..208`, step 80 | 119 |
| Wyrmglass | `x=-3500..-2800`, `z=-390..380` | `x=-3552..-2832`, `z=-432..368`, step 80 | 110 |
| Stormscale | `x=2800..3500`, `z=-400..390` | `x=2768..3488`, `z=-432..368`, step 80 | 110 |

The disjoint roster has exactly 458 full owners and 2,931,200 columns per
selected seed, or 3,206 `(seed, owner)` cases and 20,518,400 columns across the
seven selected seeds. The two Holy
Grounds envelopes come from its fixed rectangle, the unbiased frontier hubs and
the closed 60-node warp bound. The two island envelopes are their authored
polygon bounding boxes expanded by that bound. This is deliberately
conservative geometry, not a query for favorable placements.

The roster is canonical in owner-z-then-owner-x order, identical for every
selected seed, and frozen with its SHA-256 before the first successor outcome.
The seed slots are frozen in the same assignment receipt. Its
construction and validation may not read a logical biome, candidate hash,
eligible/budgeted/accepted count, operation ledger or source-density result.
There is no early stop and every zero row remains in the artifact.

The lane hard-gates `eligible > 0`, `budgeted > 0` and `accepted > 0` for
exactly eight source-by-faction pairs: each of Crimson Lotus, Stormkelp, Wild
Cocoa and Rock Salt for Accord and Throng. The four accepted geographic zone
identities are exactly `front_gravesalt_escarpment`,
`front_skyglass_canopy`, `front_stormscale_summit` and
`front_wyrmglass_crown`. A failed pair reopens production policy or density; it
never authorizes post-outcome owner selection.

This lane does not execute or claim direct-83, accepted-77, Stage A, Stage B or
tuple parity. It does not contribute to main-sample source population, density
or faction-parity arithmetic. Those receipts remain owned by the unchanged
three-projection sample and integration gate, and the two ledgers are never
pooled.

### 3.4 Advisory, non-blocking results

Record these values but do not require exhaustive equality:

- exact global resource density and exact world-wide opportunity counts;
- the previous global 10% faction-parity inequality;
- proof that every one of the 49,980,561 query columns was visited for every
  seed;
- absence of every possible local sparse patch, visual oddity or inconvenient
  resource cluster.

Material main-sample imbalance within its owned population remains a blocker
under section 3.2; any zero E/B/A value in the eight frontier hard-gate pairs is
a blocker under section 3.3. Smaller density and distribution deviations become
explicit balancing notes or bug reports for later tuning.

## 4. Implementation constraints

- Apart from the ratified two-ID dry-island coast correction, prefer adapting
  only the offline adapter, rosters, runner and finalizer. Production mapgen
  semantics must not otherwise change to make either evidence lane pass.
- Retain the three authentic comparisons for every sampled owner: R7
  successor, independent direct-83 settlement, and independent accepted-77
  authority. Sampling reduces locations, not comparison strength.
- Do not promote the aborted pilot's partial bytes or reuse them as a cache.
- Preserve the current final micro-KAT quartet if none of its exact inputs
  changes. If a relevant frozen input changes, run exactly one replacement
  LuaJIT/PUC pair as required by `AGENTS.md`.
- Re-run the real integration gate and source bindings whenever the changed
  tool/source set requires it.
- The replacement artifact and completion record must call this a
  **32-seed stratified sample**, never a full or exhaustive fleet.

## 5. Planned next-session sequence

1. Amend the R7 acceptance wording and runner schemas to describe the bounded
   sample and the hard/advisory split.
2. Implement and freeze the deterministic 128-owner-per-seed roster; verify
   boundary classes, deduplication, fill behavior, exact 4,096 population and
   permutation invariance with small KATs.
3. Implement and freeze the static 458-owner frontier-access roster, the seven
   fixed seed slots and their successor-only ledger without reading placement
   outcomes.
4. Adapt worker/finalizer aggregation without weakening Stage A/B, tuple,
   transaction, access or source-population checks and without pooling the two
   lanes.
5. Run unit/static gates and the real integration gate. Replace the final
   micro pair only if its exact input roster changed.
6. Run the combined slot-17 and main-only slot-18 pilots concurrently to
   measure actual wall time/RSS/output, stop at the approval boundary and
   review the maximum-worker projection.
7. Present the measured projection and its exact SHA-256 to the user at the
   unconditional stop boundary. Launch the seven-worker fleets only after
   explicit approval of that projection and budget.
8. Run an independent fresh GPT Sol 5.6 hard-lens review over code, immutable
   receipts, hard-gate results and the explicitly bounded evidence claim.
9. Commit the R7 completion record, update BACKLOG/ROADMAP/README as required,
   and delete this temporary plan in the same completion series.

The earlier 30--60 minute target applies only to the 128-owner main sample and
is not silently reused for the added frontier lane. The combined pilot owns the
new execution estimate and approval boundary. Stop and reconsider the evidence
design if it projects more than the user-approved fleet budget.

That stop occurred on 2026-09-01: the complete 32-seed Access proposal measured
2,981.65 seconds for one combined seed and projected 14,908.25 seconds
(4 h 08 min), projection SHA-256
`30d6912f53983bf292081a2cb441fac81c1e4092dabe477263313be78db6d033`.
The user approved the fixed seven-slot reduction above. The over-budget pilot
is rationale only; it did not authorize or launch a fleet.

## 6. R8 handoff

After pragmatic R7 acceptance, proceed directly to R8. R8 generates the first
fresh v7 world in the pinned real Luanti engine and owns the visual, runtime
and production-performance gates. Inspect representative starts, capitals,
routes, coasts, water separation, gathering/resource distribution, protection,
lighting and mapchunk seams. Release-visible anomalies become concrete bug
reports with positions and seeds; crashes, corruption, non-determinism,
writer conflicts and protection failures remain release blockers.
