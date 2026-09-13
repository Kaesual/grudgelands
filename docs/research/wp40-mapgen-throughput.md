# Mapgen throughput follow-up — 2026-09-13

This non-trivial performance package follows the user's successful exploration
of the hydrology repair. Baseline is `a87b58c`; all measurements use the local
Flatpak Luanti 5.17.0 release with its LuaJIT runtime. Rehearsal and GUI playtests
are not used. The contract is unchanged generated content, param2 and light,
with unchanged resource ranking, budgets, resource precedence and claims.

**Disposition:** this output-preserving candidate is retained as an investigation
checkpoint, not merged or synced. Its mixed timing results led to the user's
explicit authorization of a separate root-sampling prototype on
`wp40-resource-sampling-prototype` in `/tmp/grug-resource-sampling`.
That prototype's distribution trade-off requires a joint adoption decision.

## Implementation

P8 tests the original content ID before looking up predecessor runs. It skips
resource cell traversal when no owner height has an applicable denominator or
no column permits that resource. The traversal order of participating resources,
cells, segments and candidates is unchanged.

For runtime owners with predecessor runs, a retained numeric array caches only
the resource-independent eligibility predicate. The index is compact within the
80³ owner, excluding the emerged halo. Every active entry is reset before P8.
Original host CID, water/race permission, shallow exclusion and root/frontier
claims remain live. Cached predecessor priority, original/final identity and
cultural reservations cannot become invalid during P8: its only writes install
opcode 24 and resource occupancy >= 2, both explicitly accepted by the original
predicate. It never adds a cultural occupancy-1 reservation. No-R5-run owners
bypass the cache, since their original predicate is already cheap. The ordinary
evidence writer retains uncached eligibility as a differential oracle.

The array is allocator-accounted and bounded to 512,000 numeric slots per
runtime writer: approximately 4 MiB of LuaJIT value storage (8 MiB with PUC
TValue slots), excluding allocator overhead. Main and emerge environments each
construct a runtime writer. There is no retained world-coordinate map or
unbounded cache, no persistence change and no compatibility/migration code.

## Measurement and acceptance

The real-engine harness generates the same ten fixed owners, then restarts the
same disposable world and loads all 1,250 mapblocks from disk. Full checks bind
5,120,000 node content values, param2 and light values plus the content vocabulary.
Cold and disk digests must agree and the disk phase must invoke no mapgen
callback. Timing excludes the diagnostic full digest. Seed is the string `0`.

Baseline, cache prototype, early-exit-only prototype and final conditional-cache
runs are separate immutable game snapshots. The prototype comparison justified
retaining the cache for complex surface owners; the early-exit-only variant did
not reproduce those improvements. Stage instrumentation is attribution only:
its wrapper changes LuaJIT tracing and is excluded from performance comparisons.
The repaired stage patch applies with zero fuzz to baseline and final source.

The baseline diagnostic attributes 7.296 of 7.327 writer seconds in the deep
owner to P8, with 5,217,700 root digests and 0.489 seconds of heap construction.
This package preserves those root hashes. A substantial further reduction in
deep generation likely requires changing how roots are chosen; that is a
separate distribution/algorithm decision, not an outcome of this package.

The matching-harness comparison uses baseline-3, baseline-memory and baseline-4
against final-1/2/3. Whitebridge writer medians improve from 1.651 to 1.518 s,
but the deep writer median is 6.290 versus 6.890 s and the island writer also
regresses in this sample. The ten-owner callback sums show no convincing
aggregate improvement. These mixed results do not justify claiming a general
speedup or shipping this candidate alone. Raw exploratory and comparison data
are retained in `wp40-throughput-evidence/`.

The separate bounded-x-prefix hash experiment remains in scratch results
`/tmp/grug-throughput-hash-probe` and `hash-repeat-2`: two full engine checks
and primitive/expanded LuaJIT parity pass, but it was not promoted to this
candidate after the user authorized root-sampling exploration.

## Validation

The resource fixture compares runtime and ordinary writer content, param2,
light, VM operation traces and exact hash inputs. It covers empty, single-host,
4,096-host, zero-budget, tied ranks, own claims, foreign collisions, exhausted
roots, short frontiers, inactive tiers and disallowed regions. Reusing a writer
with a predecessor-cleared one-host/budget-1 cell must preserve air and match
the uncached hash trace. A separate no-R5 runtime run must match both calls.
A negative-control scratch copy omitting the cache reset fails that reuse test.
The expanded development fixture uses LuaJIT only.

Plain-5.1 parsing, SETGLOBAL, five sweeps and the fresh-server audit pass.
The real manifest constructor and one final compact PUC/LuaJIT quality pair
pass on frozen inputs: 222 byte-identical lines, SHA-256
`5b35a4a45ba3d9a9e594edba6b9a6d40ac717a4991431d2b043a80ded9f5d02b`.
The input manifest remains checked. Independent configured GPT-5.6 Sol review
found no Critical/High/Medium issues; one Low on reuse-test strength was
resolved by raw-framing comparison and an explicit no-R5 branch fixture.
The checkpoint is not integration approval for the later sampler. Coordinator
implementation is the session's GPT-6 agent; elapsed time unknown.

## Runtime test plan

After syncing from main, continue exploring new terrain, including a road or
settlement and a deep underground area. Confirm terrain, vegetation and ore
placement stay correct, and revisiting generated terrain loads normally. Existing
chunks may be retained because this package preserves generation output. Visual
acceptance and the real fallback-engine gate remain user-run R8 work.
