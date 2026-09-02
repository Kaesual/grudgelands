# WP40 simple-map R8 release and runtime contract

**Status:** The corrected one-row G2 pilot passes both schedules with exact
order equality, direct surface sunlight, stable liquid bytes and clean
shutdown. The owner-top correction has green static/fixture evidence and
focused independent acceptance. The one final frozen-byte PUC/LuaJIT pair also
passes byte-identically. The complete G3 corpus is the next engine gate.

**Baseline:** `ac3ff3f17c0119b80c90f73db944a937d9159a2b` (the reviewed R7
production cutover merged to `main`).

## 1. Purpose and release boundary

R8 is the final WP40 milestone. It does not redesign the accepted map or repeat
R6/R7's seed fleets. It supplies the smallest real-engine and user-visible
evidence needed to decide whether the already-active R7 writer is suitable for
the first persistent fresh v7 world.

R8 answers five release questions:

1. Does the exact game start a fresh production-settings v7 world without a
   manifest, loader, callback or content-registration failure?
2. Does a bounded high-risk mapchunk corpus remain byte-stable when requested
   in two materially different orders with one emerge thread?
3. Do representative native caves, dungeons, strata, ores, liquids and light
   coexist with authored terrain and content?
4. Are measured generation time and peak RSS operationally usable on the
   designated workstation?
5. Does the selected seed look and play acceptably in the user's GUI at the
   important world features?

The acceptance model is deliberately pragmatic. It is not an exhaustive proof
over the world, all seeds, all mapchunk orders or all sparse decorations. A
rare cosmetic defect that does not make a route, start, capital, channel,
resource family or major region unusable may be recorded as post-release work.

## 2. Frozen inputs and authority

R8 consumes, without rewriting:

- the accepted R7 implementation and evidence recorded in
  `wp40-simple-map-r7-review.md`;
- the R7 promotion manifest SHA-256
  `1ec84c2b361f166eae4a6d836cf7c93bf4218e429c39e1532bf67ab2311ed9e4`;
- the accepted R7 artifact SHA-256
  `73221f55ce9541180cf40909ac6dea5466ac530725f4c70d9c172a24f2e71c4f`;
- the accepted R6 content, supply and access evidence;
- the V1e fixed horizontal layout, R3 vertical model, R4 geography/policy,
  R5 planner/adapter and R6 surface/resource contracts; and
- the production defaults in `game.conf` and `minetest.conf`, including v7,
  `chunksize = 5`, `water_level = 1` and `num_emerge_threads = 1`.

The frozen R7 implementation contract and historically byte-bound WP40
engineering brief are evidence inputs. R8 must not edit their status headers
or other bytes merely to report current status. Current status belongs in this
contract, the R8 completion review, BACKLOG, ROADMAP and README.

No R6 or R7 population is rerun unless a production change invalidates its
specific input identity. A tools-only R8 harness change does not invalidate
accepted production evidence.

R2's once-per-layout housing capacity and R6's 32-seed content, supply and
access evidence remain the capacity/supply authorities. R8 samples their real
engine realization and does not create another population merely to repeat
those accepted claims.

## 3. Seed decision

Lane C derives three visual candidates exclusively from the accepted 32-seed
corpus and records the limits of the ranking. The fixed horizontal geometry is
identical; the choice concerns seed-dependent height detail, logical biome and
content/resource realization.

The candidates are not silently promoted. The first candidate is the default
GUI release candidate. It becomes the production seed only after:

- the final automated smoke uses that exact full seed string; and
- the user accepts its fresh GUI world.

If the first candidate is visually rejected, R8 may try the second and then
the third without changing geometry or acceptance criteria. Rejection is not
permission to search an unbounded seed population. The final selected full
seed string and its checksum are durable R8 evidence.

## 4. Minimal isolated engine smoke

R8 implements a small release harness, not a general mapgen framework. It must:

- export an exact committed candidate using `git archive` into a disposable
  game tree;
- use a new disposable `LUANTI_USER_PATH` and fresh world for every schedule;
- never run against or write the shared installed Grudgelands game or any
  persistent user world;
- bind the exact game commit, engine identity, full seed string, mapgen
  settings, corpus bytes and probe bytes before generation, then require the
  two fresh worlds to report one identical actual runtime manifest (the R7
  mocked-engine manifest remains provenance, not a false content-ID equality);
- resolve every caller-supplied Git revision once to one full 40-hex commit ID,
  archive only that immutable ID, and verify the Flatpak deployment identity
  immediately before and after the pair as well as both engines' in-process
  version records;
- use production v7 settings and exactly one emerge thread;
- defer the disposable server's periodic liquid-update interval beyond its
  fixed host timeout while retaining the immediate `finishBlockMake` liquid
  transform, so the byte comparison observes deterministic post-mapgen state
  rather than unequal minutes of later world simulation;
- request one corpus mapchunk at a time, wait for its complete emerge callback,
  and then request the next row, using the same externally declared corpus in a
  risk-prioritized order and exact reverse order;
- retain central-mapblock content, `param2` and both-light-bank canonical
  digests, excluding database timestamps and unrelated metadata;
- capture startup and shutdown events, errors, mapgen callback/writer counts,
  wall time and process peak RSS;
- use separate immutable output paths and refuse to overwrite a completed
  capture; and
- retain live partial logs and probe events directly in the capture directory,
  and terminate each isolated engine process group on interruption; and
- shut down through a test-only probe after all requested regions settle or
  fail through a bounded timeout.

The probe is test-only and is added only to the exported disposable game. It
must not add a production callback, command, persistent field or debug path.
The harness may reuse the isolation and receipt patterns from
`capture_t0_baseline.sh`, but historical T0/T2 labels and acceptance claims do
not carry forward.

### 4.1 Bounded corpus

The final corpus contains approximately 10--15 mapchunks and is frozen in a
reviewed TSV before the engine pilot. Its exact rows come from Lane C and must
cover the following risk classes without pretending to sample every zone:

- deep native-only/no-op;
- ordinary inland surface;
- a zone or faction boundary;
- a coast/shelf/deep-ocean transition;
- the north or south Battlegrounds boundary;
- a capital/start blend envelope;
- a road plus river/lake or crossing;
- a representative authored structure or functional-anchor slice;
- a dragon island/channel approach;
- a dense surface-content/resource case; and
- a vertical/deep stratum, cave, dungeon or resource witness.

The executable four-column corpus stays deliberately parser-small; its
companion `smoke-corpus-provenance.tsv` records stable provenance, purpose and
expected observation, while `visual-itinerary.tsv` records the GUI route and
depth. Coordinates are derived from accepted map sources or artifacts, never
discovered by changing production geometry after seeing a runtime result. A
deep automated case need not become a user teleport destination.

Native preservation has a second, fixed four-column input rather than spending
most of the 15 user-feature rows on probabilistic underground placement. Its
small rectangular deep grid is frozen before the first engine run. Every final
schedule emerges the union of the feature corpus and this native-witness grid,
in declared order or the exact reverse. It hashes the feature corpus's
canonical central mapchunks plus content-only hashes for the seven declared
stratum/ore census slices; the event-only grid is not snapshotted. A
main-environment generated callback requests
`cave_begin`, `cave_end`, `large_cave_begin`, `large_cave_end` and `dungeon`
notifications and records their sorted positions. The final gate requires a
real dungeon notification and a complete random-walk-cave notification pair;
v7 noise-intersection caves and caverns are deliberately not inferred from
the absence of such notifications. The fixed deep feature slices separately
require all production stratum families and the retained registered native
gravel-blob node in their aggregate census. This is bounded release evidence, not a search
whose radius grows until it passes.

Feature witnesses are position-bound. The capital uses its exact accepted
anchor root; each channel uses a fixed 8 by 8 water-level envelope wholly
inside its immutable polygon and requires at least 56 water-source nodes. The Seed-0 resource
check reads the exact accepted root voxel, not merely another same-named node
somewhere in its mapchunk. Seed `0` is therefore the only initially automated
release candidate. Seeds `1` and `42` remain bounded GUI alternatives, but
promoting either requires a candidate-specific accepted resource witness and
a reviewed corpus update before its automated smoke. This prevents a Seed-0
witness from accidentally accepting or rejecting another seed.

### 4.2 Order comparison

The required schedules are one risk-prioritized order and its exact reverse.
This is sufficient for R8's release approximation because R7 already accepted
owner-slice, forward/reverse finalizer and offline operation-order evidence.
Additional random, vertical or sparse-fill schedules are diagnostic only and
need a concrete discrepancy before becoming blocking work.

Content and `param2` differences are blocking. The comparison snapshots all
cases only after the complete schedule, so a later request can still expose an
earlier-chunk mutation. Flowing-liquid `param2` is compared byte-for-byte, but
the test-owned server defers its periodic wall-clock liquid tick until after
the host timeout; the immediate mapgen liquid transform remains active. A
light-bank difference is blocking unless the harness first demonstrates
convergence under one fixed, reviewed settling procedure and the post-settle
digests then match. A failure is not waived by taking the more attractive
schedule.

### 4.3 Fresh-engine read-only halo

The first real mapgen callback established an engine boundary that the R5--R7
offline VoxelManip fixtures did not model. Luanti materializes the central
80-node mapchunk but a newly allocated 16-node border may remain
`CONTENT_IGNORE`. That border is read-only context for native lighting; it is
not evidence that the central owner is incomplete.

R8 therefore narrowly supersedes the inherited R5/R6 non-seed lighting-context
rule for production execution:

- `CONTENT_IGNORE` inside the central owner remains a fail-closed error;
- `CONTENT_IGNORE` outside the owner in the read-only emerge halo is admitted;
- existing non-ignore neighbor content remains valid light context;
- neither adapter converts halo `ignore` to air or another content ID; and
- content, `param2` and light bytes outside the owner are restored unchanged
  after the transaction.

The pure R5 adapter and consolidated R6/R7 writer apply the same rule. Their
fixtures must cover an all-ignore fresh halo, retain the central-ignore
rejection and keep the already-accepted materialized-neighbor order cases.
This is an engine-shape compatibility correction, not a geometry, placement,
seed, content-policy or ownership change. The historical byte-bound R5 and R6
contracts remain unchanged as records of their original acceptance.

### 4.4 Post-v7 surface sunlight authority

The completed pilot showed that v7's light pass precedes the WP40 rewrite.
Consequently, a non-ignore overtop cell can retain a dark decision made for
temporary v7 geometry that the single R7 writer subsequently replaced. An
explicit seed derived from that stale light cannot establish sunlight in the
new authored surface.

R8 narrowly supersedes the inherited lighting call rule in both the pure R5
adapter and the consolidated R6/R7 writer:

- when the bounded light box ends above the authenticated `water_level = 1`,
  call `calc_lighting` with `propagate_shadow = false`;
- on that false path only, cap the `calc_lighting` maximum y at the fully
  authored owner maximum so a fresh vertical `CONTENT_IGNORE` halo cannot stop
  the sunlight scan before it reaches owner content;
- at or below water level, retain `propagate_shadow = true`;
- keep the existing enlarged zero/spread/restore light box, explicit seed
  derivation, owner-only light commit and complete halo restoration unchanged;
  only the calculation-call maximum is narrower; and
- require a surface witness to contain authored air with packed light exactly
  `15` (`day = 15`, `night = 0`), rather than accepting arbitrary emitted
  light such as the capital's day/night-6 guard banner.

This delegates the surface sky boundary to Luanti without inventing an
analytic sky predicate. Opaque nodes inside the light box still stop sunlight;
deep sealed regions retain shadow propagation. No content, `param2`, feature
placement, seed or persistent halo byte changes ownership under this rule.

The production-shaped integration oracle preserves two distinct comparisons.
Stage A still requires exact current successor/direct equality for content,
`param2` and light. Stage B compares the current normalized Direct-83 result
with the frozen accepted-R6 result exactly for content and `param2`, but not
for the historical light bytes that this R8 rule deliberately supersedes.
Dedicated current lighting fixtures cover the capped surface scan, retained
deep scan, in-owner opaque blocker and byte-exact ignored-halo restoration.

## 5. Gate sequence and run budget

### G0 -- contract and source preflight

- freeze the exact contract, seed-candidate roster, corpus and GUI itinerary;
- freeze the bounded native-witness grid and its smaller pilot prefix;
- independently review their scope, source provenance and non-overclaim;
- verify the baseline, R7 manifest and production-settings identities; and
- prove the harness cannot address the shared installed game or a non-scratch
  world.

### G1 -- static and fixture checks

Every changed Lua file passes `tools/bin/luac51 -p`. Changed mod Lua, if any,
also passes `SETGLOBAL` inspection and the five repository sweeps. Lua under
`tools/` receives the do-not-write searches explicitly because the repository
sweeps do not cover it. Intermediate executable fixture checks use LuaJIT.

If R8 changes no production Lua, R7's accepted final production micro-KAT pair
remains the evidence for those unchanged bytes and is not rerun ceremonially.
The new test-only Lua still receives the parser/source gates and executes in
the real engine smoke. If R8 changes production Lua, the corrected frozen
production bytes receive exactly one replacement compact PUC 5.1/LuaJIT pair
with byte-identical canonical output, as required by the repository strategy.

### G2 -- resource pilot

Run the same two-order machinery sequentially over the frozen three-case pilot
prefix containing capital, channel-water and deep-resource cases plus the
frozen native-pilot prefix. The pilot validates the notification plumbing and
records any witnessed events, but does not require a random placement to occur
inside that smaller prefix. Record elapsed time and peak RSS before authorizing
the complete pair and deciding whether its two worlds may run concurrently.

The first post-halo-correction attempt completed every feature case and two of
five adjacent native-prefix cells without an engine or mapgen error, then hit
the fixed per-order timeout. Those adjacent native cells exercise the same
notification plumbing and carry no pilot event requirement. The reviewed
runtime correction therefore keeps only the first native cell in G2. The
complete 32-row G3 native corpus, its event gate and its census slices remain
unchanged.

The complete two-schedule smoke proceeds only when the pilot projects:

- no more than two hours total wall time on the designated workstation;
- no memory pressure, OOM, uncontrolled swap growth or host instability; and
- enough headroom for at most two concurrent engine processes.

The first attempt on 2026-09-02 stopped before generation because real Luanti
returns a builtin-vector metatable on NoiseParams `spread`, while the R7
readback validator admitted only a metatable-free table. That failed attempt
is diagnostic evidence only. Its narrow compatibility correction does not
change any NoiseParams value or world-writing semantics; a fresh reviewed
commit must receive the complete pilot.

The next reviewed attempt also stopped before generation: the effective
`num_emerge_threads` value was the required string `1`, but the validator
mistook Luanti's userdata Settings object for a bad value because its fixture
had been table-shaped. The corrected type boundary remains value-strict and is
covered by a userdata proxy in the final micro-KAT.

If the projection misses a bound, reduce redundant cases or serialize the two
schedules and re-review that exact reduction. Do not weaken risk-class
coverage or silently raise the wall-time bound.

The accepted G2 pair took 12:29.78 and 12:24.78 for four requests per order,
with peak in-process RSS below 3.87 GB on a 16-core, 58-GiB workstation. A
linear projection of the original 15 feature plus 32 native requests slightly
exceeds the two-hour wall bound. The final feature corpus is therefore reduced
to the contract's lower bound of 10 risk-distinct rows while retaining all 32
native rows and the unchanged 15-point GUI itinerary. Capital/start, inland,
zone/front, Battlegrounds, road/water, coast/shelf, dragon channel/island and
both deep risk classes remain represented. The two complete schedules may run
concurrently: their observed combined peak-RSS projection stays well below
physical memory and each engine retains one emerge thread and idle priority.
This exact data-only reduction requires focused review before G3; it does not
invalidate the accepted G2 pilot or frozen production-byte interpreter pair.

### G3 -- final automated smoke

Run the complete corpus in both frozen orders on separate fresh worlds. The
gate requires:

- clean startup and controlled shutdown;
- one identical actual production manifest across both worlds and the selected
  seed;
- no Lua error, assertion, manifest refusal, unknown-node failure or engine
  crash;
- one active WP40 generated callback/writer path;
- byte-identical post-mapgen content, `param2` and light digests before the
  first periodic wall-clock liquid update;
- a complete readable node census with no `ignore`, direct sunlight in
  authored surface air,
  the source-bound capital marker envelope, usable channel-water envelope and
  exact accepted Seed-0 ruby root present;
- all five registered native strata and at least one retained native
  gravel-blob node in the aggregate deep-slice census;
- at least one native dungeon event and a matched native random-walk-cave event
  pair from the fixed native-witness grid, with the canonical native evidence
  identical across request orders; and
- durable wall-time and peak-RSS output.

Generation timing and RSS are release outputs. Within the two-hour/no-host-
pressure envelope they are advisory unless the user observes release-blocking
stalls in G4; R8 records them instead of inventing an unmeasured historical
regression threshold between incompatible map products.

### G4 -- user GUI acceptance

The user opens a fresh world with the same selected seed and production
settings and follows the reviewed 10--15-point itinerary. Blocking results are:

- an unsafe or missing start/capital;
- a missing or unusable major route, coast, Battlegrounds connection, dragon
  channel or island;
- widespread voids, floating terrain, liquid walls, black lighting, unknown
  nodes or repeated generation errors;
- visibly unusable generation stalls or memory behavior; or
- runtime classification/protection behavior contradicting the inspected
  point's decided zone.

Minor dressing gaps, sparse patches, isolated ugly transitions and comparable
cosmetic defects are recorded as non-blocking follow-up unless they obstruct a
listed feature. The user's observation and `debug.txt` excerpt/result are
retained in the R8 completion record; screenshots are optional unless needed
to diagnose a finding.

### G5 -- real fallback engine

The real bundled/fallback Lua 5.1 Luanti run remains a separate user runtime
gate. Standalone PUC/LuaJIT equality does not replace engine `builtin/`,
sandbox or `core.*` behavior. The fallback run reuses the selected seed and a
small start/capital smoke, not the complete two-order performance corpus.

## 6. Parallelism and sequencing

Before contract freeze, three lanes may proceed with non-overlapping ownership:

- Lane A owns this contract, integration and acceptance judgment;
- Lane B owns the minimal runner/probe scaffold and runner preflight; and
- Lane C owns the seed candidates, corpus coordinates and GUI itinerary.

After integration, correctness is sequential: freeze, independent contract
review, pilot, final smoke, fix-or-freeze, independent final review and GUI
handoff. The two final disposable engine schedules may run concurrently only
after the pilot proves memory headroom. They count against the workstation-wide
seven-Lua-process cap; R8 intentionally plans at most two.

The independent final reviewer does not rerun the engine or PUC evidence. The
reviewer inspects immutable receipts, logs, hashes, exact candidate bytes and
the full checklist in `docs/process/wp-workflow.md`.

## 7. Change and rerun rules

- A tools/docs-only correction reruns only affected harness fixtures or
  receipts; it does not regenerate R6/R7 production evidence.
- A corpus or native-grid correction after a runtime observation retains the
  failed record and receives review; the grid may not expand automatically
  until a random event appears.
- A production Lua correction runs the mandatory static gates and replaces
  R8's one final compact PUC 5.1/LuaJIT micro-KAT pair on frozen bytes.
- A change to writer order, ownership, planner/content semantics, seed hashing
  or accepted map inputs invalidates the affected R6/R7 evidence and stops R8
  for an explicit scope ruling.
- A runtime-only fixture/probe must never be copied into the production game.
- No finding is repaired by changing the selected corpus after observing the
  failure. A justified corpus correction keeps the failed record and receives
  independent review before rerun.

## 8. Durable outputs and completion

R8 retains in `docs/research/` at least:

- the frozen R8 contract and reviewed preflight;
- selected-seed and corpus/itinerary records;
- one pilot receipt;
- the final run manifest, order-comparison receipt, runtime/RSS summary and
  concise engine log evidence;
- the user's GUI and fallback-runtime result; and
- the independent R8 completion review with model calibration fields.

Bulk disposable worlds, engine databases and redundant raw scratch files stay
outside Git. Every retained result is hash-bound to the exact candidate and
its generating inputs. Before shutdown or cleanup, the coordinator verifies
that no unique acceptance evidence remains only in `/tmp`.

R8 completion updates BACKLOG, ROADMAP and README in the same commit, marks
WP40 shipped without rewriting earlier milestone records, receives an
independent clean review, merges through a merge commit and synchronizes the
accepted `main` game. The completion message includes the concise ongoing
runtime checklist and states that future geometry/seed/mapgen-setting changes
are fresh-world format changes.

## 9. Stop conditions

Stop and escalate rather than expanding the suite when:

- the selected production seed or a player-visible release rule requires a
  new design decision;
- the minimal runner cannot obtain stable central content/param2/light data
  without modifying the engine or production writer;
- the two-order result differs;
- native preservation or one-writer evidence contradicts R7's accepted model;
- the pilot projects beyond the fixed wall/memory envelope after removing only
  redundant cases; or
- a fix would alter frozen geometry, planner/content semantics or a previous
  accepted artifact identity.

The default response to a non-blocking cosmetic observation is a concise bug
record, not a new exhaustive evidence chain.
