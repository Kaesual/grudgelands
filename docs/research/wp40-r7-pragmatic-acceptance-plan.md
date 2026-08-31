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

The target composition per seed is:

1. up to 104 representative coverage owners, preferably one for every known
   occurring zone/logical-biome stratum;
2. 24 fixed risk owners covering map corners and clipped edges, ocean/coast and
   channels, protection and routes, apex/cultural locations, housing-adjacent
   ground, and surfaces spanning multiple vertical owners.

The roster constructor must be cheap. It may use already authenticated fixed
geometry, durable R6 witnesses and bounded production-owned queries. It must
not perform a hidden full-world scan merely to choose the sample. If exact
per-seed discovery of all 104 strata would require such a scan, use a frozen
stratified spatial lattice plus the 24 risk owners instead. Record the actual
strata reached as measured coverage; do not fabricate missing labels.

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
- a missing eligible/budgeted/accepted population for any of the twelve P9G
  sources across the complete 32-seed sample;
- loss of the already accepted six Cultural access identities;
- absence of representative paired-faction access for the resource grades
  that require it;
- a gap, duplicate or unexpected case in the exact 4,096-case roster.

Any hard failure is fixed and the affected frozen evidence chain is rerun. It
is not deferred as a post-release balancing issue.

### 3.3 Advisory, non-blocking results

Record these values but do not require exhaustive equality:

- exact global resource density and exact world-wide opportunity counts;
- the previous global 10% faction-parity inequality;
- proof that every one of the 49,980,561 query columns was visited for every
  seed;
- absence of every possible local sparse patch, visual oddity or inconvenient
  resource cluster.

Material sample imbalance, such as a source absent from one faction or a whole
resource grade absent from the sample, remains a blocker under section 3.2.
Smaller density and distribution deviations become explicit balancing notes
or bug reports for later tuning.

## 4. Implementation constraints

- Prefer adapting only the offline adapter, roster, runner and finalizer.
  Production mapgen semantics must not change to make the sample pass.
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
3. Adapt worker/finalizer aggregation without weakening Stage A/B, tuple,
   transaction, access or source-population checks.
4. Run unit/static gates and the real integration gate. Replace the final
   micro pair only if its exact input roster changed.
5. Run a short sampled pilot to measure actual wall time/RSS/output, stop at
   its approval boundary and review the projection.
6. Present the measured projection and its exact SHA-256 to the user at the
   unconditional stop boundary. Launch the seven-worker sampled fleet only
   after explicit approval of that projection and budget.
7. Run an independent fresh GPT Sol 5.6 hard-lens review over code, immutable
   receipts, hard-gate results and the explicitly bounded evidence claim.
8. Commit the R7 completion record, update BACKLOG/ROADMAP/README as required,
   and delete this temporary plan in the same completion series.

Target execution budget after implementation: approximately 30--60 minutes
for the sampled fleet, with a few hours total for implementation, gates,
review and documentation. Stop and reconsider the sample design if its
measured pilot projects more than two hours of fleet wall time.

## 6. R8 handoff

After pragmatic R7 acceptance, proceed directly to R8. R8 generates the first
fresh v7 world in the pinned real Luanti engine and owns the visual, runtime
and production-performance gates. Inspect representative starts, capitals,
routes, coasts, water separation, gathering/resource distribution, protection,
lighting and mapchunk seams. Release-visible anomalies become concrete bug
reports with positions and seeds; crashes, corruption, non-determinism,
writer conflicts and protection failures remain release blockers.
