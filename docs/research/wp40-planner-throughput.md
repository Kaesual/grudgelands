# Planner throughput follow-up — 2026-09-13

The user authorized another measured optimization after adoption of the resource
sampler. Branch `wp40-planner-throughput` starts at `4403f01`. This package is
non-trivial: it changes performance-sensitive planner logic and regression gates.
It preserves the current terrain, decorations and resource selection rules.

## Change and attribution

The R6 candidate planner now reuses the wet surface/bed values already read for
its central 16×16 cell when building the surrounding 20×20 wet-neighbor area.
It still queries the perimeter and any central coordinates outside the authored
map. All 400 scratch slots reset per cell. Interior source queries fall from
656 to 400 per cell; the clipped southwest-edge fixture falls from 544 to 400.
Waterfall precedence and the positive-depth guard are preserved.

The R5 planner retains four validated wet-neighbor scalars per coordinate in a
bounded 84×84 array (28,224 scalar slots). A validity marker resets before every
plan, including the first plan after an error. Dry results are cached too. The
maximum 80×80 synthetic owner reduces source queries from 83,200 to 13,444,
with identical canonical runs and column offsets. This cache has no persistence
and does not grow as players explore. No migrations or old-world paths exist.

Optional diagnostic clocks identified repeated candidate cell loading at about
1.31 seconds across ten owners, compared with about 0.052 seconds for cultural
selection and 0.243 seconds for decorations. A separate coarse diagnostic put
nested R5 planning at 1.62 seconds. These instrumented runs affect JIT behavior;
they identify targets and are not primary speed evidence. The optional profiler
now reports planner phases as well as writer phases; its patch was rebased only
after the primary timing population finished.

## Real-engine comparison

Three serial runs per variant alternated baseline and optimized, using the same
Flatpak Luanti 5.17.0 Release engine, engine LuaJIT, seed `0`, ten requested
80×80×80 owners and identical timing harness bytes. The local workstation has
16 logical CPUs. Both variants use the already adopted resource sampler.
No Rehearsal VM or GUI was used. Scheduling was idle; no primary engine timing
runs overlapped. Medians below are medians of aggregate callback times per run,
not wall-clock startup, network transfer or rendering time.

| Population / measurement | Baseline | Optimized | Reduction |
| --- | ---: | ---: | ---: |
| All ten callbacks | 6.681 s | 6.096 s | 8.8% |
| Nine surface callbacks | 5.900 s | 5.412 s | 8.3% |
| One deep callback | 0.772 s | 0.709 s | 8.2% |
| Planning, all ten | 3.364 s | 3.041 s | 9.6% |

Total ranges are 6.412–6.835 seconds baseline and 6.004–6.207 seconds optimized.
The unchanged writer also measured lower, 3.317→3.019 seconds median. This may
reflect changed allocation/JIT/GC behavior or ordinary timing effects; the
measurement does not attribute that portion to a writer optimization. The
observed end-to-end callback improvement is therefore reported separately from
the directly reduced planner work. Three local repeats do not establish a
universal speedup or predict how large multiplayer workloads behave.

All six runs retain identical full node/param2/light digests over 5,120,000 owner
voxels each, identical samples and vocabulary. The full digest is
`e0dc278549dfa58661a5127f2ec0b3e336839f573a1927696a4779a249136792`.
Each disk restart loads 1,250 stored mapblocks with zero mapgen callbacks.
`compare.py` binds the baseline snapshot to the instrumented `4403f01` manifest,
requires the optimized snapshot to differ only in the two production planners,
and binds those hashes to the reviewed checkout. It rejects six copies of the
baseline as a negative regression. The exact timing harness is archived because
the optional diagnostic patch was subsequently rebased.

Exploratory runs preceded the declared final alternating population: one
baseline and one halo-only candidate. The halo-only run improved planning but
had a slower total, so it was not accepted as evidence for an overall gain.
Final baseline directories originally numbered 2/3/4 and combined directories
1/2/3 are archived as baseline-1/2/3 and optimized-1/2/3 respectively.

## Validation and limits

Both bounded actual-planner fixtures are in the standard whole-quality micro.
They cover wet/dry reuse, waterfall precedence, invalid depths, clipped map
edges, source-error recovery and the maximum halo bounds. LuaJIT baseline and
optimized fixtures preserve canonical output; query counts intentionally change.
Plain-5.1 parsing covers all 137 own production Lua files and all five changed
Lua files. SETGLOBAL finds no writes in changed files; all five source sweeps
have only existing comment/string matches. The fresh-server audit and pinned
reference-submodule status pass.

An additional historical cave-witness test failed already on the unchanged
baseline: at `(1647,72,-1985)` it expected air but found coniferous litter.
That fixed witness is not certified by this package. Its failure is archived;
we did not weaken it or change production to satisfy it. A separate ten-owner
terrain parity corpus uses the same owner coordinates without asserting the
historical tube shape, to compare current full generated bytes before/after.
Both variants pass with identical full node/param2/light output over another
5,120,000 owner voxels and zero disk-reload callbacks. The source for that
parity population accompanies its evidence. This additional
population is correctness evidence only, excluded from primary timings.

The final whole-quality pair passes with 259 byte-identical lines under PUC
5.1 and LuaJIT, SHA-256
`3810e1d8ee545281a8eb7a5ed4a92be0aa614fdec5db76aea199e4fec1d7fb11`.
The preceding actual manifest-constructor KAT passes; the input manifest was
rechecked after execution. Final parity and independent-review receipts are recorded in the
[evidence directory](wp40-planner-throughput-evidence/). Remaining R8 supply,
visual acceptance and real fallback-engine gates stay open. A complete 32-seed
resource/access recertification is outside this output-preserving follow-up.

## Review and calibration

Coordinator implementation: GPT-6 session identity; bounded R6 implementation and
fixtures: previously configured GPT-5.6 Sol agent. Independent review uses a
separate context with no implementation ownership. Initial review found no
Critical/High production issue and two Medium test-evidence issues across two
passes: fixture integration was unfinished, and the comparator did not bind
source snapshots. Both were fixed in two integration/evidence rounds. Final independent review:
**0 Critical / 0 High / 0 Medium / 0 Low**, clean for commit, merge and authorized
local sync. Reviewer: prior configured GPT-5.6 Sol route, reporting GPT-6 session
identity; these are recorded separately rather than inferred from one another.
The [review receipt](wp40-planner-throughput-evidence/review.md) is retained.
Observed elapsed wall time: unknown.

## User runtime test

After syncing main, create a fresh disposable world and fly through unexplored
surface terrain, shores and water transitions. Visit underground terrain, then
restart and revisit the generated area. Check generation responsiveness and
report any error from debug.txt. Terrain and ore layout should match the prior
sampler version for the same seed; this package makes no distribution trade-off.
