# Mapgen chunk profile, October 2026 (lane MGPROF)

Where the Lua time of the R7 generated callback goes, stage by stage, for a
few representative mapchunks. Measurement only: nothing under `mods/`
changed. Input to BACKLOG "WP48 — Mapgen writer performance and parallel
emerge", lever 1. Numbers are comparisons on one machine, not targets.

## Method

- **Instrumentation** (`tools/mgprof/stages.patch`, applied only to the
  staged game copy through `GAME_PATCH`): a flat stage timer
  (`wp40/mgprof.lua`). Each mark books the time since the previous mark, so
  the stages of a callback sum exactly to its total. Sub-timers (P8 host
  scan, the P8 vein split, R5 shadow copies) lie inside a stage and are
  reported separately. Counters record the work done. One `GRUG_MGPROF` log
  line is written per callback. The R6 planner cell cache and the zones
  column cache report their hits and misses. The patch also has a
  totals-only mode (setting `grug_mgprof_totals_only`), which this lane did
  not use (see "Instrumentation overhead").
- **Probe** (`tools/mgprof/grug_probe_mgprof`, staged through `PROBE`): it
  waits until the starts preload has finished, so the single emerge thread
  is idle. It then checks both columns in full: all 6400 columns are land,
  with no river, functional ground, hard foundation, road or hard
  protection. It generates the warm-up chunk and the nine measured chunks
  one at a time with `emerge_area`, 2.5 s apart, and requires every chunk to
  come back `EMERGE_GENERATED`. At the end it benchmarks the frontier rank
  digest and shuts the server down.
- **Engine timings**: `profiler_print_interval = 1`, logged at info level
  on the console (`--info`). With one chunk per profiler window,
  `Mapgen::makeChunk` and `Lua on_generated` are per-chunk values in whole
  ms.
- **Seed 12345, `chunksize = 5`, `num_emerge_threads = 1`.** Two chunk
  columns were picked by the probe and are now pinned in it:
  - **A** = x 368..447, z -2352..-2273: `elandor_goldmead_vale`,
    `grug_meadows`, terrain y 34..65, 1001 columns at y ≥ 48.
  - **B** = x 528..607, z -2192..-2113: the same zone, mostly
    `grug_deep_forest`, terrain y 48..84.

  The warm-up chunk is x 608, y -112, z -2352. No measured chunk wrote a
  road, anchor or settlement node.
- **Chunks and order:** warm-up, then A: S1 (-32..47), S2 (48..127), B
  (-112..-33), U1 (-192..-113), U3 (-512..-433), U6 (-1072..-993), then B:
  U6, U1, B.
- **Boots** (`tools/mgprof/run.sh`, through the shared measuring queue,
  `chrt --idle`):

  | boot | world | instrumentation | wall | server CPU |
  |---|---|---|---|---|
  | 1 | fresh: first start, 84-chunk starts preload | stages | 124 s | not captured (~85 s, by boot 3) |
  | 2 | boot 1's world, measured columns deleted (`reset_columns.py`) | stages | 46 s | 17.7 s |
  | 3 | fresh (same protocol as boot 1) | stages + heap | 112 s | 79.8 s |
  | 4 | boot 3's world, columns deleted; layout cache rebuilt once (patch changed) | stages + finer P8 split + digest benchmark | 69 s | 40.0 s |

- **Cache state per chunk.** Counters are identical in all four boots, so
  the work was identical.
  - Cold zones column cache and cold planner cell cache: the warm-up chunk,
    A_S1 and B_U6. Each had about 7,200–7,500 column misses and 25 cell
    misses.
  - Mostly warm: A_S2, with 1,768 column misses and a warm cell cache.
  - Fully warm: every other chunk.
  - JIT: the warm-up chunk was the first chunk of the process in boots 2
    and 4. In boots 1 and 3 it followed the 84 preload chunks.
- **Remainder:** the stage sum equals the callback total, because the
  timeline is flat. The engine's `Lua on_generated` differs from the
  callback total by −0.5 to +0.6 ms. That difference is the engine's
  whole-ms rounding plus the builtin callback dispatch outside the timer.

Reproduce the tables from the committed extracts with:

```sh
python3 -I tools/mgprof/summarize.py tools/mgprof/evidence/boot{1,2,3,4}         # ms, mean (min-max)
python3 -I tools/mgprof/summarize.py --pct tools/mgprof/evidence/boot{1,2,3,4}   # ms (% of total)
```

## Results

The table shows the mean of the four boots in ms, with the share of the
callback total in brackets. The four P8 sub-rows other than the host scan
come from boot 4 only. Stages below 0.5 % in every chunk are summed in one
row.

| stage: ms (% of total) | warmup | A_S1 | A_S2 | A_B | A_U1 | A_U3 | A_U6 | B_U6 | B_U1 | B_B |
|---|---|---|---|---|---|---|---|---|---|---|
| planner R5 | 33 (8%) | 29 (5%) | 2 (1%) | 1 (0%) | 1 (0%) | 1 (0%) | 1 (0%) | 30 (4%) | 1 (0%) | 1 (0%) |
| planner R6 columns | 26 (6%) | 24 (4%) | 6 (3%) | 6 (2%) | 6 (1%) | 6 (1%) | 6 (1%) | 35 (5%) | 8 (2%) | 8 (2%) |
| planner R6 candidates | 48 (11%) | 94 (15%) | 0 | 0 | 0 | 0 | 0 | 200 (27%) | 0 | 0 |
| VM get_data/param2 | 8 (2%) | 8 (1%) | 8 (4%) | 8 (2%) | 8 (2%) | 8 (2%) | 8 (2%) | 8 (1%) | 8 (2%) | 8 (2%) |
| input copy+zero | 3 (1%) | 3 (1%) | 3 (2%) | 3 (1%) | 3 (1%) | 3 (1%) | 3 (1%) | 3 (0%) | 3 (1%) | 3 (1%) |
| R5 adapter | 4 (1%) | 90 (15%) | 25 (12%) | 5 (1%) | 0 | 0 | 0 | 0 | 0 | 4 (1%) |
| surface column passes (skin, P7, R9) | 2 (0%) | 19 (3%) | 4 (2%) | 2 (0%) | 1 (0%) | 2 (0%) | 2 (0%) | 2 (0%) | 2 (0%) | 2 (0%) |
| R8 strata | 11 (3%) | 20 (3%) | 6 (3%) | 6 (2%) | 6 (1%) | 6 (1%) | 6 (1%) | 14 (2%) | 7 (2%) | 7 (2%) |
| R24 fill layers | 2 (0%) | 6 (1%) | 1 (0%) | 1 (0%) | 0 | 0 | 0 | 0 | 0 | 1 (0%) |
| **P8 resources** | 251 (59%) | 218 (35%) | 57 (27%) | 318 (85%) | 334 (88%) | 356 (89%) | 391 (90%) | 414 (57%) | 307 (86%) | 281 (84%) |
| of which host scan (4 boots) | 104 | 103 | 55 | 123 | 187 | 232 | 275 | 277 | 186 | 124 |
| of which budget + root-draw setup (boot 4) | 3 | 2 | 0 | 3 | 4 | 5 | 7 | 9 | 3 | 3 |
| of which veins: root draws + growth (boot 4) | 138 | 112 | 1 | 191 | 131 | 124 | 115 | 178 | 112 | 144 |
| of which vein growth (frontier + rank digests, boot 4) | 137 | 111 | 1 | 189 | 130 | 122 | 113 | 173 | 111 | 143 |
| P9 decorations | 0 | 11 (2%) | 2 (1%) | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| successor swamp | 1 (0%) | 1 (0%) | 1 (0%) | 1 (0%) | 1 (0%) | 1 (0%) | 1 (0%) | 3 (0%) | 2 (1%) | 2 (1%) |
| successor P9G | 0 | 51 (8%) | 51 (24%) | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| successor world content | 7 (2%) | 7 (1%) | 5 (2%) | 5 (1%) | 6 (2%) | 6 (1%) | 6 (1%) | 7 (1%) | 6 (2%) | 5 (1%) |
| successor settlements | 18 (4%) | 1 (0%) | 1 (1%) | 1 (0%) | 1 (0%) | 1 (0%) | 1 (0%) | 1 (0%) | 1 (0%) | 1 (0%) |
| final diff scan | 2 (1%) | 12 (2%) | 2 (1%) | 3 (1%) | 2 (1%) | 2 (1%) | 2 (0%) | 2 (0%) | 2 (1%) | 2 (1%) |
| VM write-back (set_data/param2) | 7 (2%) | 18 (3%) | 11 (5%) | 11 (3%) | 7 (2%) | 7 (2%) | 7 (2%) | 7 (1%) | 7 (2%) | 7 (2%) |
| relight | 0 | 4 (1%) | 12 (6%) | 1 (0%) | 0 | 0 | 0 | 0 | 0 | 0 |
| air check + tail | 0 | 0 | 12 (6%) | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| other stages (each < 0.5 %) | 1.5 | 2.2 | 1.8 | 2.1 | 0.6 | 0.6 | 0.6 | 1.9 | 0.6 | 0.7 |
| **callback total, mean** | **424** | **617** | **209** | **376** | **378** | **400** | **435** | **731** | **356** | **333** |
| callback total, min–max of 4 boots | 363–586 | 530–831 | 149–339 | 322–490 | 288–576 | 316–571 | 345–636 | 549–811 | 277–504 | 265–502 |
| engine `Mapgen::makeChunk`, mean | 20 | 29 | 24 | 20 | 21 | 29 | 30 | 30 | 21 | 20 |
| request-to-done wall, mean | 590 | 650 | 236 | 406 | 402 | 431 | 470 | 764 | 380 | 357 |

"Other stages" are the planner successor, writer entry and checks, R8 cave
mouth, P8 setup, successor roads, anchors and arena, and update_liquids
(at most 1.4 ms).

Counters (identical in every boot):

| count | warmup | A_S1 | A_S2 | A_B | A_U1 | A_U3 | A_U6 | B_U6 | B_U1 | B_B |
|---|---|---|---|---|---|---|---|---|---|---|
| writer result | applied_c | applied_cplq | applied_clq | applied_clq | applied_c | applied_c | applied_c | applied_cq | applied_c | applied_c |
| R5 runs | 6400 | 16971 | 8230 | 6400 | 0 | 0 | 0 | 0 | 0 | 6400 |
| P8 active resources | 9 | 6 | 6 | 9 | 9 | 12 | 13 | 13 | 9 | 9 |
| `host_eligible` calls | 3.53 M | 2.87 M | 2.56 M | 3.52 M | 4.39 M | 5.36 M | 6.32 M | 6.32 M | 4.39 M | 3.54 M |
| of which from the vein frontier | 418 k | 310 k | 1 k | 408 k | 290 k | 241 k | 179 k | 181 k | 295 k | 428 k |
| eligible hosts found | 2.95 M | 1.94 M | 8.8 k | 2.85 M | 3.88 M | 4.92 M | 5.81 M | 5.84 M | 3.91 M | 3.00 M |
| ore/gem nodes placed | 24049 | 17894 | 86 | 23536 | 18185 | 17996 | 16958 | 17047 | 18315 | 24549 |
| veins | 3699 | 2750 | 20 | 3628 | 3186 | 3836 | 4533 | 4543 | 3193 | 3756 |
| frontier rank digests | 81891 | 57908 | 237 | 80370 | 62030 | 60742 | 55636 | 55870 | 62886 | 83760 |
| modified voxels | 24123 | 183697 | 5628 | 23775 | 18186 | 17997 | 16958 | 17048 | 18316 | 24549 |
| set_data / relight / update_liquids | y/n/n | y/y/y | y/y/y | y/y/y | y/n/n | y/n/n | y/n/n | y/n/y | y/n/n | y/n/n |
| column cache misses | 7223 | 7448 | 1768 | 0 | 0 | 0 | 0 | 7481 | 0 | 0 |
| planner cell cache misses | 25 | 25 | 0 | 0 | 0 | 0 | 0 | 25 | 0 | 0 |

## Findings

1. **Underground chunks are almost all P8.**
   - Share of the callback: 84–90 % in every warm underground chunk, from
     B (-112) down to U6 (-1072).
   - What remains (planner, VM transfers, strata, world content, write-back)
     is 44–58 ms.
   - Depth matters mainly through the number of active resources: 9 at B
     and U1, 12 at U3, 13 at U6.
2. **P8 has two halves of similar size.**
   - **The host scan.** Every voxel of every 16³ cell segment goes through
     `host_eligible` once per active resource. That is 3.5–6.3 M calls per
     chunk, 123–277 ms on average.
   - **Vein growth.** It takes 111–189 ms in boot 4. Each step rebuilds the
     whole frontier: 180–430 k extra `host_eligible` calls and 127–272 k
     frontier candidates with a linear duplicate check. It also computes
     55–84 k SHA-256 frontier rank digests.
   - The digest benchmark measured 1.0 µs per digest. The digests are
     therefore roughly 55–85 ms of the growth, and the frontier work is the
     rest.
   - Budget and root-draw setup is small: 2–9 ms.
3. **The first chunk of a column pays the planner's cold caches.**
   - Cost: R5 planner about 30 ms, R6 columns 24–35 ms, and R6 decoration
     candidates 48–200 ms (up to 350 ms in one boot).
   - Total: about 100–270 ms extra.
   - B_U6 shows that this happens to an underground chunk as well. It builds
     the 25 cells' decoration candidates although no decoration can root at
     y -1072.
   - This, plus the boot-to-boot spread below, plausibly explains the
     live session's 778 ms for the chunk at -112..-33.
4. **Surface chunks spread their cost more.**
   - S1, the first chunk of its column: P8 35 %, planner 24 % (mostly the
     candidates), R5 adapter 15 % (17 k runs), P9G 8 %.
   - S2: P8 27 % (55 ms scanning 2.56 M voxels to find 8.8 k hosts above
     the surface), P9G 24 % (51 ms for 11 writes), R5 adapter 12 %,
     relight 6 %, and the air-chunk check itself 6 % (12 ms).
5. **Fixed per-chunk costs are small.** VM read about 8 ms, copy and zero
   about 3 ms, diff scan 2–12 ms, write-back 7–18 ms, relight up to 12 ms.
   Every measured chunk changed content, because ores occur at every depth,
   so the write-back always ran.
6. **The same work can run 1.4–1.7× slower for a whole process.**
   - Boot 1 and boot 3 ran the same code, world protocol and chunk order,
     and their counters were identical.
   - Boot 1 was slower over all 94 callbacks: a median ratio of 1.53 for
     the 84 identical preload chunks, already 1.43 for the first 12. Its P8
     host scan was 5× slower.
   - Native `makeChunk` and the VM transfers took the same time in both
     boots. The slowdown is therefore Lua-side, not machine load.
   - The emerge environment's `jit` table is the sandbox whitelist, which
     has no `jit.attach`. Trace aborts and flushes could therefore not be
     counted, so the cause remains open; a LuaJIT trace or machine-code
     state per process is suspected.
7. **The emerge Lua heap is large.** Boot 3 measured 1.13–1.46 GB. A chunk
   allocates 8–82 MB (S2 8, U-chunks about 19, S1 82). GC time was not
   separated; it falls into the allocating stages.

## Throughput of one emerge thread

The rate is 1000 / (mean request-to-done wall per chunk). That wall
includes `makeChunk`, the Lua callback and the engine's finishing work.
Ranges come from the fastest and slowest boot.

| chunk type | chunks/s, mean (range) |
|---|---|
| S1, first chunk of a column (cold planner) | 1.5 (1.2–1.8) |
| S2, warm | 4.2 (2.7–5.7) |
| B (-112..-33), warm | 2.5–2.8 (1.9–3.5) |
| U1 / U3 / U6, warm | 2.5 / 2.3 / 2.1 (1.5–3.3) |
| U6, first chunk of a column | 1.3 (1.2–1.7) |
| air chunk (live session, not measured here) | about 17–70 |

## Levers

These are ranked by expected gain. Every gain is an **estimate** derived
from the tables above, not a measurement of a change.

1. **One host scan per cell segment and host rock, shared by all
   resources (P8 host scan).**
   - `host_eligible` does not depend on the resource. Claims are checked
     separately at draw time, and the existing per-voxel cache already
     relies on this.
   - Keying the eligible list on (cell, segment, host) and undoing each
     resource's Fisher–Yates swaps after its draws should keep the output
     identical.
   - Estimated gain: host scan × (1 − 1/k) with k = 6–13 active resources.
     That is about −100 to −250 ms per underground chunk (−30..−55 %),
     −85 ms in S1 and −45 ms in S2.
2. **Incremental vein frontier (P8 growth, output-identical).**
   - Add the new node's six neighbours instead of rebuilding the frontier
     from all vein nodes every step.
   - It keeps the rank memo, and with it every digest.
   - Estimated gain: −30 to −70 ms per underground chunk.
3. **Skip the R6 decoration candidates (and P8 above the surface) where
   nothing can be placed.**
   - Candidates: for a chunk wholly below the lowest possible decoration
     root, −50 to −350 ms, only for the first chunk of a column (players
     tunnelling into new columns).
   - P8 host scan above the cells' highest host rock: up to −55 ms on
     S2-type chunks. This is output-identical only if no host voxel can
     exist above that bound, which must be proven.
4. **A cheaper rank hash for vein frontiers, root draws and budget
   remainders (P8 digests).**
   - Replacing about 1 µs SHA-256 digests with an integer hash saves
     about −45 to −75 ms per underground chunk.
   - **It changes the world (map reset)** and the deterministic contract of
     the P8 digests.
5. **Ores and gems from native v7 instead of P8 (the "P8 costs nothing"
   case).**
   - The warm underground Lua total would drop from 333–435 ms to 44–58 ms,
     the measured non-P8 rest.
   - Emerge throughput for underground chunks would rise from about 2–3/s
     to about 11–15/s before the native ore pass's own C++ cost. That cost
     was not measured; at an estimated +5–20 ms per chunk, the rate would
     be about 9–13/s.
   - **It changes the world (map reset) and the resource rules.** Native
     ores cannot express the protected-floor exclusion, fill-stone hosts,
     water-class columns, per-cell budgets or the lower-half rows.
6. **Surface-only stages:** R5 adapter (25–90 ms) and P9G (51 ms in S1 and
   in S2) were not split further, because neither dominates. A finer split
   needs one more boot.
7. **The slow-process regime (finding 6).**
   - If a live server sits in it, removing the cause would be worth an
     estimated −30..−40 % on every stage.
   - The cause is unknown. Diagnosing it needs an unsandboxed test boot,
     with `jit.attach`/`jit.util` or `-jv`.

## Re-check of the survey facts

The original survey listed these facts; each was checked at `1ef11b5e`.

- **Only early-out is `air_chunks.untouched`, never below water level:
  confirmed.** `r7_mapgen.lua` `refine`; `air_chunks.lua` `M.untouched`
  returns false for `minp.y <= water_level`. On an above-water chunk it does
  not skip, the check itself costs 12 ms (S2).
- **Every other chunk runs `plan_slice` and `writer.apply`, which is
  `r6_settlement.lua` `apply_impl`: confirmed** (`r6.lua` writer →
  `settlement:apply` → `apply_impl`).
- **`AUTHORED_FLOOR = -37`: confirmed** (`planner.lua:219`). B has one R5
  run per column; U1 and deeper have none, and the R5 adapter returns
  `noop_empty_plan` in 0.1 ms.
- **Native v7 keeps caves, dungeons, tier-rock strata, gravel and
  decorative blobs: confirmed.** `r7_native.lua` has the gravel blob, the
  t2–t6 strata and three decorative blob rows; `minetest.conf` sets
  `mg_flags`. `makeChunk` costs 20–32 ms.
- **All ores and gems are placed in P8 (`r6_settlement.lua` 3018–3222),
  with a `host_eligible` call per voxel per active resource and SHA
  budget/vein digests: confirmed.** Calls ≈ active resources × scanned
  segment volume, plus 0.2–0.4 M from the frontier. Digests: `digest7` and
  `prepare_root_draw` per segment, `digest11` per new frontier voxel per
  vein.
- **Fixed per-chunk costs: confirmed.**
  - `get_data`/`get_param2_data` of the 112³ VM: 8 ms.
  - Copy and zeroing of the five intent arrays over 1.4 M voxels: `:2577`,
    3 ms.
  - The 512 k-voxel diff scan: about `:3913–3970`, 2–12 ms.
  - Setters only when anything changed: correct, but every measured chunk
    changed.
  - Relight and `update_liquids` only when flagged: correct.
- **Per-column passes without a depth early-out: confirmed, but small.**
  - R5/R6 planner columns: 1–8 ms warm, 24–35 ms cold.
  - R8 strata: 6–7 ms even at U6.
  - Roads 0.3 ms, swamp 1–3 ms.
  - World content: 5–7 ms everywhere. Its rows `cave_cap` -500..-100 and
    `ember_moss` ≤ -701 are in `world_content_catalog.lua:38-39`.
  - Missing from the survey: the planner's R6 decoration candidates. With
    cold caches they cost 48–200 ms, in deep chunks too.
- **Hypothesis "underground is dominated by P8": confirmed** (84–90 %).
  **"Surface is dominated by planner + R5/writer": changed.** P8 is still
  the largest single stage at the surface (27–35 %), followed by the
  planner (cold), the R5 adapter and P9G.

## Limits

- One seed, two columns, one machine, `chrt --idle`; the machine was
  otherwise idle (load average 0.3–0.8).
- Instrumentation overhead was not measured separately. It adds a few dozen
  timer calls, about 2 × 1800 timer calls per chunk in P8 and integer
  counters. A totals-only boot was skipped because the boot-to-boot spread
  (finding 6) would have hidden a few-percent overhead. Clock calls can
  change LuaJIT traces, so treat the stage split as attribution, not exact
  cost.
- The vein split and the digest count come from boot 4 alone. The digest
  cost is a main-environment benchmark, not timed inside the callback.
- Air chunks were not measured.

## Files

- `tools/mgprof/stages.patch`: the stage timer. It is anchored on
  `1ef11b5e` and replaces the stale
  `tools/wp40/profile/instrument-settlement-stages.patch`.
- `tools/mgprof/grug_probe_mgprof/`: the probe.
- `tools/mgprof/run.sh`: one boot.
- `tools/mgprof/reset_columns.py`: makes a kept world's measured columns
  generate fresh again.
- `tools/mgprof/summarize.py`: the tables.
- `tools/mgprof/evidence/boot1..4/`: the extracted log lines of the four
  boots.
