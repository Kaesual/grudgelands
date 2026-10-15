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

## Addendum: follow-up 2 (slow processes, surface split, hashes, caches)

Two more boots of the same corpus, both on fresh worlds with the starts
preload, like boots 1 and 3. Both ran with `INSECURE=1`
(`tools/mgprof/insecure.patch`): only this run's throwaway server config sets
`secure.enable_security = false`, so the stage timer can use `jit.attach` and
`jit.util`. The game-defaults layer logs one expected ERROR line for that
setting, which `run.sh` accepts.

The patch version used here (the committed `stages.patch`) adds four things:
- R5 adapter sub-stages (`r5a_*`);
- P9G sub-timers;
- per-stage SHA-256 accounting (a wrapper on `core.sha256`, which every
  mapgen digest goes through);
- LuaJIT trace diagnosis: starts, stops, aborts by reason and source line,
  flushes, and machine-code size and range, plus one-time benchmarks.

| boot | wall | server CPU | regime |
|---|---|---|---|
| 5 | 116 s | 83.7 s | fast (A_U1 339 ms) |
| 6 | 127 s | 95.1 s | **slow** (A_U1 510 ms, B_B 677 ms) |

Reproduce the tables with
`summarize.py [--pct|--hash] tools/mgprof/evidence/boot5 tools/mgprof/evidence/boot6`.
The JIT lines are the `GRUG_MGPROF_JIT*` and `GRUG_MGPROF_BENCH` lines in
the same extracts.

### The slow-process regime

What the slow boot shows:
- **It is the P8 host scan.** Over the 10 measured chunks, boot 6 needed
  5.97 s against 4.01 s in boot 5. The host scan accounts for +1.78 s of
  that (2.3×: 3.16 s against 1.38 s), and the R6 candidates for +0.07 s.
  Every other stage is within ±10 %, including the vein growth (1.08×).
- **It holds for the whole process.** The slow/fast ratio is 1.28–1.56 in
  every block of 12 callbacks, from the first preload chunk to the last
  measured one.
- **It is not machine-code exhaustion and not a disabled JIT.** Both
  processes had 0 trace flushes, about 10 MB of machine code (within about
  330 MB of `libluajit`), `jit.status()` on throughout, and the same
  benchmark loop speed (0.83 against 0.85 ns per iteration).
- **The abort pattern matches.** Total aborts and their reasons were the same
  in both boots: about 10 k, mostly "NYI: register coalescing too complex",
  "blacklisted" and "leaving loop in root trace". The difference is at the
  host scan's segment loop (patched `r6_settlement.lua` 3086 and 3098):
  "inner loop / leaving loop in root trace" aborts appeared in 13 callbacks
  in the slow boot and in 5 in the fast one.

The likely mechanism (not proven trace by trace) is the following. The scan
is a five-deep loop nest whose innermost loop runs only 16 iterations around
a function call. Which loop LuaJIT records first, and when a failing start
point is blacklisted, depends on hot counters keyed by bytecode addresses
and on randomized penalties. Both vary per process. In about a third of the
processes, the nest ends up with traces that leave to the interpreter on
every short inner loop.

Frequency: 2 of 6 boots (2 of 4 fresh worlds, 0 of 2 re-used worlds). That
is about 1 in 3 per server start, a rough figure because the sample is
small. A restart draws again.

Cheapest fixes, as estimates:
1. **Flatten or share the host scan.** One loop over a segment's voxel
   range instead of the z/y/x nest, or one scan per segment shared by all
   resources (lever 1). This removes the fragile nest; the slow-regime
   penalty was +170..+280 ms per underground chunk and about +160 ms in S1.
2. **Move ores to native v7.** This removes the scan underground. Fill ores
   stay in Lua, so S1 and B keep the exposure unless the scan is fixed as
   in fix 1.
3. Process-level controls (`jit.flush`, `hotexit`, `jit.opt`) are not
   targeted at this loop and are not recommended.

### R5 adapter and P9G split

Means of boots 5 and 6 (these stages are equal in both regimes):

| ms | A_S1 | A_S2 | A_B |
|---|---|---|---|
| R5 adapter: setup + heightmap check | 4.3 | 3.9 | 0.4 |
| R5 adapter: shadow get_data/param2 | 0.9 | 0.9 | 1.0 |
| R5 adapter: resolve + validate pass | 66.9 | 14.5 | 0.8 |
| R5 adapter: replay pass | 12.6 | 13.6 | 0.7 |
| R5 adapter: shadow set_data/param2 + liquids | 0.4 | 0.4 | 0.5 |
| (r6_settlement shadow copies, inside the above) | 1.3 | 1.3 | 1.4 |
| P9G total | 57.0 | 57.3 | 0 |
| P9G scan + rank digests | 52.0 | 52.4 | – |
| P9G budget + sort | 4.8 | 4.8 | – |
| P9G placement (rest) | 0.2 | 0.1 | – |

R5 adapter:
- The resolve pass costs about 150 ns per run voxel in S1 (17 k runs,
  184 k modified voxels).
- `resolve_voxel` and `preserved_native_cave` are among the top abort
  sites: "NYI: register coalescing too complex" at `map_adapter.lua`
  938/947/102, together about 2,100 aborts per boot. The likely reason is
  `classify`'s 10-value return (`r7_content.lua:370`, the same abort), so
  the resolve pass most likely runs interpreted.
- The replay pass calls `resolve_voxel` a second time for every run voxel.

P9G:
- It scans 12 rows × 25 cells × 256 columns (76,800 row-column checks per
  surface chunk). It finds 11,628 eligible columns, each with a SHA rank
  digest.
- **The scan is two-dimensional and identical for every vertical chunk that
  holds surface.** S1 and S2 of the same column both pay it in full; the
  code itself notes that the 2-D budget prefix is shared by every vertical
  callback.
- The scan's `column_values_at` path is affected: the column cache hit path
  `unpack(row, 1, 20)` (`zones.lua:1429`) is the most often blacklisted
  location (about 1,000 per boot).

### SHA-256 per stage

| SHA-256 calls per chunk | A_S1 | A_S2 | A_B | A_U1 | A_U6 | B_U6 (cold) |
|---|---|---|---|---|---|---|
| P8 resources | 59,151 | 271 | 82,214 | 64,030 | 59,232 | 59,467 |
| planner R6 candidates (cold column only) | 43,734 | 0 | 0 | 0 | 0 | 37,383 |
| P9G | 11,928 | 11,928 | 0 | 0 | 0 | 0 |
| P9 decorations | 349 | 39 | 0 | 0 | 0 | 0 |
| **all stages** | **115,162** | **12,238** | **82,214** | **64,030** | **59,232** | **96,850** |

No other stage hashed in these chunks. That covers the planner R5 and R6
columns, the R5 adapter, strata, roads, world content and settlements.

Costs, all inside the same process:
- **Raw `core.sha256`:** 0.28–0.58 µs per call (benchmark).
- **Measured inside the callback:** a median of about 0.45 µs per call. That
  figure includes the GC steps the result strings trigger, and outliers
  reach 1.4 µs.
- **A full framed digest** (`r6_hash`, 4–11 fields): 0.70–1.20 µs. Mean
  about 0.95 µs.
- **An integer mix over 11 fields:** 0.009 µs.

**Estimate.** Replacing every digest with an integer hash saves about
0.9 µs × calls:

| chunk | saving | share |
|---|---|---|
| S1, cold column | −105 ms | about 15–18 % |
| S1, warm column | −65 ms | – |
| S2 | −11 ms | about 5 % |
| B | −75 ms | – |
| U chunks | −55..−60 ms | – |
| B_U6, cold | −90 ms | – |

After the native-ore move, only these Lua hash users remain:
- fill ores (S1: 59 k digests, about −55 ms);
- R6 candidates (37–44 k per new column, about −35..−40 ms, once per
  column);
- P9G (12 k per surface chunk, about −11 ms);
- P9 decorations (under 1 ms).

**Output that would change:** every ore and gem position (P8), every
decoration placement (R6 candidate ranks, rotations, variants, budget
remainders, and P9 template choices) and every gathering source (P9G).
Terrain, water, roads, zones, settlements and strata use no runtime
digests in these chunks, so they would stay as they are.

### Planner caches: preparation against runtime (code reading)

What a chunk needs:
- **Every chunk with Lua work** needs the zones runtime column cache.
  - It is a FIFO of 65,536 column tuples.
  - It serves the R5 planner, the R6 column loop, P7, strata, P8, P9G and
    the successors.
  - A new 80×80 column costs 7.2–7.5 k misses, including the halo, and
    about 50–60 ms (planner R5 about 30 ms and R6 columns 24–35 ms, against
    about 2 + 6–8 ms warm).
- **The first chunk of a column** also builds the R6 decoration candidates
  of its 25 cells.
  - These go into a 4,096-cell FIFO, which holds about 164 columns.
  - The cost is 48–200 ms (350 ms once), of which 37–44 k digests are about
    35–42 ms.
  - The candidates are built even when no decoration can be rooted in the
    chunk (B_U6).
- **The first above-water chunk** pays the air-check envelope (12 ms; memo
  of 64 owner columns).
- **Every chunk holding surface** pays P9G's 2-D scan (57 ms), which has no
  cache.

Order of generation:
- **Full-world preparation** runs in tile order, bottom-up within a column
  (`preparation_plan.lua`). The column's lowest prepared chunk pays the cold
  cost; everything above it is warm, because the column cache comfortably
  holds the current column and its neighbours.
  - **With the planned early-out** for chunks without Lua work (ores, gems
    and cave plants native), the deep chunks are skipped. The first chunk
    with Lua work then pays: B (-112..-33, the fill floor) or S1 where the
    surface is low.
  - Building the candidates lazily (only for chunks whose y range can hold
    a root) would move the candidate part to the surface chunk without
    removing it. Every column's surface chunk is generated anyway.
- **Runtime generation** follows the engine's distance shells around each
  player (`clientiface.cpp` GetNextBlocks). The chunk nearest the player,
  normally S1 or S2 when walking, pays the cold cost.
  - The generate reach is (10 + 1) × 16 = 176 nodes, about 5 × 5 chunk
    columns around one player. That is about 180 k column tuples against a
    cache of 65,536.
  - So a column's later chunks (S2, the air checks, the chunks below) are
    likely evicted again before they are generated, and pay the about
    50–60 ms column cost repeatedly. Several players multiply this.
  - The decoration cell cache (164 columns) holds a player's surroundings.

Would the candidates remedies remove most of the cold cost?
- **Lazy candidates:** they help only chunks without surface that come
  first in a column, such as tunnels into ungenerated columns, or B in
  bottom-up preparation. There they save 48–200 ms. The total per column is
  unchanged.
- **A larger or chunk-column-keyed column cache:** about 4×, an estimated
  +50–60 MB of heap. This removes the repeated about 50–60 ms per later
  chunk of a column at runtime.
- **A per-column P9G cache** (the same 2-D result for S1 and S2): −57 ms on
  every second surface chunk.
- **Integer digests:** take about 35–40 ms out of the candidate build.
- **Order changes** (top-down or surface-first preparation) only move the
  cost.

The largest remaining cold item at the surface is the candidate build
itself (48–200 ms). Its non-hash part (`build_cell`/`load_cell` over 25
cells) is not split yet.

## First start baseline (Round 49, lane MEAS)

One boot of a fresh world on main `f8f2d134` (0.49.0, nothing under `mods/`
changed since `1ef11b5e`), seed 12345, the default starts-only preparation,
`totals` mode (callback totals only, no stage marks), through the shared
measuring queue under `chrt --idle` (load average 1.1–2.2 on 16 cores). The
probe now also logs its load, the first server step and the moment the
preparation listener reports ready (within one 0.2 s notification), and
`run.sh` records the launch (the launcher's `server.conf` mtime, which leaves
the queue wait out) and the log end. Start-up before the first server step
is single-threaded Lua (CPU ≈ wall): the world layouts are built once for a
new world (cache miss, 23.1 s), the world map base is rendered (9.2 s) and
the mob spawn regions are built (8.1 s over 38 zones). The 84 prepared
chunks are all surface chunks with writer work (42 at y −32..47, 42 at
48..127); none was an air skip, a −112..−33 chunk or wholly underground. The
emerge thread is busy 88 % of the preparation wall with the Lua callback
and `makeChunk`, so the preparation rate follows the per-chunk Lua time.
Evidence: `tools/mgprof/evidence/meas-first-start/` (the console is trimmed
to the profiler and probe lines). The same boot's ten corpus chunks are the
first `totals` numbers of the corpus (warm-up 415, A_S1 642, A_S2 213, A_B
314, A_U1 342, A_U3 388, A_U6 419, B_U6 557, B_U1 373, B_B 545 ms); one boot
cannot separate the stage timer's overhead from the boot-to-boot spread
(finding 6). The older fresh-world boots carry the same preparation split
(stage-timer boots, ready after 31–42 s of probe waiting, 26.9–39.3 s of
preparation Lua): `summarize.py --first-start tools/mgprof/evidence/bootN`.

| first start | wall s from launch (±1) | wall s from first server step | server CPU s |
|---|---|---|---|
| mods loaded (probe init) | 24 | – | 24.2 |
| first server step | 42 | 0 | 42.5 |
| preparation complete | 79 | 36.7 | 79.3 |
| end (after the 10-chunk corpus) | 114 (log end) | 71.3 | 84.1 |

| preparation chunks | chunks | Lua callback total, sum ms | mean ms (min–max) |
|---|---|---|---|
| surface, minp y = −32 | 42 | 22,457 | 535 (365–1036) |
| surface, minp y = 48 | 42 | 7,410 | 176 (123–262) |
| **all** | **84** | **29,866** | 356 (123–1036) |
| engine: `Mapgen::makeChunk` | 84 | 2,510 | 30 |

One emerge thread: **2.29 chunks/s** over the preparation (84 chunks in
36.7 s from the first server step).

MEAS2 repeats it after the last world-generation merge with the same
command, from the worktree root:

```sh
LC_ALL=C MGPROF_QUEUE=~/projects/grudgelands-orchestration/r45/engine_run.sh CLEAN=1 \
    tools/mgprof/run.sh totals tools/mgprof/evidence/meas2-first-start
python3 -I tools/mgprof/summarize.py --first-start tools/mgprof/evidence/meas2-first-start
```

## Addendum: v7 flags, Round 49 (lane V7)

The v7 flags `nomountains` and `noridges`, each on its own, against main
`e43c886b` (ORE, PROT, SKIP and JIT merged). Measurement only: the flags were
set in the staged throwaway game copy, nothing under `mods/` changed. The
Round 9 plateau (terrain constant plus both flags) is not repeated.

### Method

- **Variants** (`mgv7_spflags`; `caverns, nofloatlands` in all three):
  baseline `mountains, ridges` (today), `nomountains`, `noridges`.
  `tools/r49_v7/run.sh` stages `tools/mgprof/stages.patch`, the R5 voxel
  tally (`tally.patch`) and, for a variant, `flags-<variant>.patch`: the
  staged `minetest.conf` and the live flag check of `r7_runtime.lua`, which
  refuses any other flag set at load and was patched in the staged copy only.
- **Boots:** one fresh world per boot (the flags are world-bound), seed
  12345, the starts preload, then the 19 chunks one at a time through the
  measuring queue (`chrt --idle`): baseline twice, `nomountains` twice,
  `noridges` once; 122–128 s wall and 68–73 s server CPU each. One more boot
  without generation ran the column picker.
- **Columns:** the corpus (A, B) and three columns picked by
  `grug_probe_v7pick` from v7's own noise (engine `ValueNoise`, the mapgen's
  seed and formulas): it ranked all 2,901 land chunk columns of the world
  rectangle on a 3 × 3 sample, refined the best on 8 × 8, and took the best
  ordinary one (the mgprof rule) per metric (`evidence/pick/probe.txt`):
  - **M** = x −1872, z 2288 (`kragmar_stillgrave_hollow`): the most v7
    mountain stone above our surface; our terrain 21..35, v7 base 13..21,
    mountain stone up to about y 153. Chunks y −32, 48, 128.
  - **H** = x 1088, z −1792 (`elandor_lorindor`): mountain stone above our
    surface **and** between v7's base and our higher terrain; our terrain
    50..124, v7 base −6..38, mountain stone up to about y 220. Chunks y −32,
    48, 128, 208.
  - **R** = x 528, z −1552 (`elandor_lorindor`): the most v7 river channel
    (ridges) under our land; our terrain 52..111, v7 base 26..75. Chunks
    y −32, 48.
  The corpus columns have no v7 mountain stone (base 10..28 under our
  34..84); B has a little ridge channel.
- **Tally** (`tally.patch`, a pre-pass over v7's input with its own stage
  mark, left out of every total below): per chunk the planned voxels of the
  R5 clear runs (`cut_natural`) holding v7 rock (**cleared**), and of the
  fill runs (`fill_void`) holding air, liquid or vegetation, split into the
  native cave content the run keeps under v7's heightmap
  (`preserved_native_cave`, **kept cave**) and the rest (**filled**).
- **Normalized wall:** the cold planner (R6 candidates) and the
  slow-process spread vary by 100–270 ms between boots for identical work.
  The stages that read only our plan (planner, VM read, P9/P9G, other
  successors) are therefore replaced by their mean over all five boots;
  the flag-dependent Lua (R5 adapter, strata/skin/fill layers, P8 fill ores,
  diff + write-back + relight + liquids, air check) and `makeChunk` are
  each boot's own.

Reproduce with
`summarize.py [--compact] baseline=tools/r49_v7/evidence/baseline baseline2=… nomountains=… nomountains2=… noridges=…`
(`tools/r49_v7/summarize.py`).

### Results per chunk

Means over the boots of a variant, ms: `makeChunk` / flag-dependent Lua /
normalized request-to-done wall. Results other than `applied_*` are named.

| chunk | baseline | nomountains | noridges |
|---|---|---|---|
| A_S1 (−32) | 30 / 144 / 478 | 23 / 176¹ / 504 | 24 / 141 / 469 |
| A_S2 (48) | 24 / 57 / 181 | 17 / 65 / 181 | 19 / 60 / 178 |
| A_B (−112) | 22 / 28 / 87 | 16 / 27 / 79 | 22 / 27 / 88 |
| U1 (−192), 2 chunks | 21–22 / deep skip / 25–26 | 14 / deep skip / 17–18 | 21–22 / deep skip / 25 |
| U3, U6 (−512, −1072), 3 chunks | 30 / deep skip / 33–35 | 22–23 / deep skip / 25–28 | 30 / deep skip / 33–35 |
| B_B (−112, cold) | 21 / 21 / 384 | 14 / 19 / 375 | 21 / 18 / 381 |
| M_y−32 | 27 / 142 / 481 | 22 / 114 / 447 | 21 / 120 / 453 |
| M_y48 | 32 / 74 / 145 | 18 / 29 / 84 (noop) | 28 / 70 / 136 |
| M_y128 | 34 / 56 / 113 | 18 / 13 / 50 (**air skip**) | 28 / 58 / 111 |
| H_y−32 | 28 / 79 / 278 | 22 / 130 / 323 | 22 / 77 / 271 |
| H_y48 | 30 / 117 / 243 | 16 / 122 / 236 | 23 / 139² / 259 |
| H_y128 | 33 / 61 / 142 | 18 / 30 / 95 (noop) | 27 / 70² / 145 |
| H_y208 | 34 / 55 / 121 | 17 / 12 / 58 (**air skip**) | 27 / 64² / 125 |
| R_y−32 | 34 / 103 / 335 | 26 / 103 / 328 | 20 / 56 / 273 |
| R_y48 | 34 / 131 / 255 | 26 / 116 / 232 | 26 / 214² / 330 |

¹ Identical work in all variants (no v7 mountain in A); one `nomountains`
boot's R8 strata took 97 ms against 43–50 elsewhere: the noise level of the
flag-dependent sum is about ±30 ms. ² The single `noridges` boot ran R8
strata, P9G and the other successors 1.5–3× slower than every other boot from
H_y48 on, also where its work was identical to the baseline's (the whole H
column); its Lua numbers from there on are not attributable to the flag.

R5 voxel tally (k voxels, identical in repeated boots; fill-run share of kept
cave in brackets):

| chunk | variant | cleared | filled (air + liquid) | kept cave | modified | P8 fill hosts / ores |
|---|---|---|---|---|---|---|
| A_S1 | all three | 0 | 146 | 12 (2.6 %) | 169 | 96 / 4.4 |
| M_y−32 | baseline, noridges | 117 | 0 | 17 (4.6 %) | 187 | 0 / 0 |
| M_y−32 | nomountains | 0 | 52 | 13 (3.5 %) | 102 | 31 / 1.7 |
| M_y48 | baseline, noridges | 229 | 0 | – | 229 | 0 |
| M_y48 | nomountains | 0 | 0 | – | 0 | 0 |
| H_y−32 | baseline, noridges | 0 | 73 | 54 (10.5 %) | 74 | 63 / 2.7 |
| H_y−32 | nomountains | 0 | 198 | 7 (1.4 %) | 198 | 173 / 8.0 |
| H_y48 | baseline, noridges | 103 | 20 | 49 (15 %) | 173 | 14 / 0.7 |
| H_y48 | nomountains | 0 | 325 | 0 | 334 | 265 / 12 |
| H_y128 | baseline, noridges | 148 | 0 | – | 148 | 0 |
| H_y128 | nomountains | 0 | 0 | – | 0 | 0 |
| R_y−32 | baseline, nomountains | 0 | 240 + 33 | 32 + 11 liquid (8.4 %) | 273 | 246 / 11 |
| R_y−32 | noridges | 0 | 4 | 14 (2.7 %) | 9 | 4 / 0.2 |
| R_y48 | baseline, nomountains | 0 | 209 | 11 (4.6 %) | 230 | 158 / 7.2 |
| R_y48 | noridges | 1.5 | 163 | 1.2 (0.5 %) | 193 | 119 / 5.5 |

The ore census of these chunks keeps 4.4–5.2 % ore in the T1 host rock in
every variant (fill ores and native ores use the same rates); a variant with
less cave has more host rock and so more ore nodes.

Per chunk column, sums of the means, and chunks per second of one emerge
thread (chunks / summed normalized wall):

| column | chunks | baseline makeChunk / flag Lua / chunks/s | nomountains | noridges |
|---|---|---|---|---|
| A (S1, S2, B) | 3 | 76 / 228 / 4.0 | 56 / 268¹ / 3.9 | 65 / 228 / 4.1 |
| deep (U1, U3, U6) | 5 | 134 / 0 / **32.9** | 97 / 0 / **43.8** | 133 / 0 / 33.2 |
| M | 3 | 94 / 272 / 4.1 | 57 / 157 / **5.2** | 77 / 248 / 4.3 |
| H | 4 | 124 / 312 / 5.1 | 73 / 293 / **5.6** | 99 / 350² / 5.0 |
| R | 2 | 68 / 233 / 3.4 | 52 / 219 / 3.6 | 46 / 270² / 3.3 |

Whole boots: 84 preparation chunks (all surface chunks with writer work, no
air or deep skip in any variant) ready 22.9–24.1 s after the first server
step in every variant; no difference shows at that size. Over the 19
measured chunks: deep skips 5 in every variant, air skips 0 (baseline,
`noridges`) and 2 (`nomountains`: M_y128, H_y208), plus 2 chunks
(M_y48, H_y128) that run the writer for a no-op because our content reach
comes within 16 nodes. An air skip still costs 11–14 ms (the reach ring of
the air test).

### Findings

1. **`makeChunk` pays v7's 3-D mountain noise at every depth.** v7 computes
   `noise_mountain` (5 octaves, 80 × 82 × 80) for every chunk when
   `mountains` is set (`mapgen_v7.cpp` `generateTerrain`), also 1000 nodes
   down where it cannot matter. `nomountains` takes 5–8 ms off every chunk
   (deep chunks 21–30 → 14–23 ms) and 14–17 ms off chunks above the surface.
   Deep chunks run no Lua since lane SKIP, so this is now their main cost:
   one emerge thread generates **about 44 instead of 33 deep chunks per
   second (+33 %)**. `noridges` takes 4–8 ms off chunks from y −32 up only,
   14 ms in the ridge column's S1 (`noise_ridge` is computed where
   `node_max.y >= water_level − 16`).
2. **Clearing v7 rock above our surface goes away with `nomountains`.** Where
   mountain stone rises over low authored land (M), the chunks above the
   surface become no-ops or air skips (M_y48 145 → 84 ms, M_y128 113 → 50
   ms); the column's flag-dependent Lua drops 272 → 157 ms and its rate rises
   4.1 → 5.2 chunks/s.
3. **The trade-off: more fill where our surface is higher than v7's base.**
   Under H the mountain stone was the rock under our terrain; without it the
   writer fills: H_y−32 filled voxels 73k → 198k, fill-ore hosts 63k → 173k,
   flag-dependent Lua 79 → 130 ms (R5 adapter +30, P8 fill ores +9,
   write-back +9). H_y48 trades 103k cleared for 305k more filled at about
   the same cost (117 → 122 ms). A filled voxel costs about 0.4 µs (adapter,
   fill ores, write) against about 0.2 µs for a cleared one (mostly
   write-back and relight); the adapter cost is not linear in the write
   count. The fill ores stay in Lua (H: 3.4k → 20k ore nodes placed by the
   fill pass instead of native rows). Over the H column the gain still
   wins: chunks above become no-op or air (−31, −43 ms), so 312 → 293 ms
   flag-dependent Lua and 124 → 73 ms `makeChunk`.
4. **`noridges` matters only along v7's ridge lines.** In R, the channels
   under our land were 273k voxels the writer filled in R_y−32; without
   ridges 9k: flag-dependent Lua 103 → 56 ms (adapter −11..−16, P8 −18,
   write −8, strata −7) and `makeChunk` 34 → 20 ms. Elsewhere it changes
   only `makeChunk` above y −32.
5. **Near-surface native caves.** The adapter keeps native cave air and
   liquid below v7's heightmap inside our fill runs; fill itself has no
   caves (Round 24 ruling 13). `nomountains` removes most of them where our
   land lies above v7's base (H: 10.5–15 % of the fill-run voxels → 0–1.4
   %); `noridges` removes the channel remnants under overhangs, including
   pockets of v7 river water (R_y−32: 32k air + 11k water → 14k air).
   Caves below v7's base terrain and all deep caves are unchanged.

### What an adoption would change

- **For players:** neither flag changes the visible relief or water: our
  surface, rivers and lakes are authored and the writer clears everything v7
  puts above them. `nomountains`: fewer caves in the top tens of nodes under
  hills and highlands that lie above v7's base (in seed 12345's land v7's
  base is about 10–75), the same ore rate there (from the fill pass).
  `noridges`: fewer near-surface caves and no underground pockets of still
  water along v7's ridge lines.
- **Pins** (lane V7A): `minetest.conf:30` (`mgv7_spflags`);
  `r7_runtime.lua:100-102` (the live check, engine form e.g.
  `nomountains, ridges, nofloatlands, caverns`, both environments);
  `mapgen_manifest.lua:45`, `planner.lua:493`, `map_adapter.lua:385` and
  `r7_r6_manifest.lua:230` (the R5 manifest string, today
  `caverns,mountains,ridges`; its digest is computed at load, no pinned
  hex); `tools/seed_fleet/runtime.lua:101` (the fake engine's flag string;
  the fleet's fake v7 is stone up to our ground, so its digests stay);
  `tools/wp40/profile/run.sh:190` (stale). `NOISE_DIGEST`
  (`r7_native.lua:21`) covers only the six noiseparams the game sets, not
  the flags, so it does not change. The layout cache key reads the flags
  itself (`r7_loader.lua:63`). The comment in `air_chunks.lua` that cites
  v7's mountains stays true for any surviving mountain setting. A map reset,
  which 0.49.0 is anyway.

### Limits

- One seed, three extra columns, a sample of 19 chunks; two boots for
  baseline and `nomountains`, one for `noridges` (its later Lua stages ran
  in a slow process, footnote 2). The two flags together were not measured.
- How much of the world has mountain stone above our surface (the M case)
  or above v7's base under our land (the H case) was not counted; the
  picker ranks columns but logs only the best ones.
