# Round 23 Lane A — full-column world preparation (WP48)

Date: 2026-09-28. Contract: [Round 23 plan](../planning/round23-world-life-plan.md),
Lane A and "Engine run budget". Design: [world preparation](../design/world_preparation.md)
("Full-column extent", "Air-chunk fast path"). Implementation on branch
`wp48-full-column-preparation`; not merged.

## What changed

- `grug_core/preparation_plan.lua`: full mode prepares each horizontal tile's
  whole column. A scanner walks tiles in the plan's z/x order ahead of
  selection and keeps per-tile surface statistics only for the rows a pending
  window can still read; `select` resolves a tile once its window is scanned.
  New persisted order `z-x-column-v2` with `reach`, `air_top`, `window` and
  `counts` (fresh worlds only; no reader for the old format).
- `grug_core/starts_preload.lua`: reads the effective
  `max_block_generate_distance` once when the plan is created and persists it;
  a later edit is logged and ignored. The per-step budget (100 ms, 16-column
  batches, 8,192-column ceiling), the two-request pipeline, ordered prefix,
  retries and the shutdown path are unchanged.
- `grug_core.FLIGHT_CEILING = 600` is the single source; `grug_mounts` reads it
  (it already depends on `grug_core`).
- `wp40/air_chunks.lua` + `r7_mapgen.lua`: the emerge-side fast path.
  `r7_runtime.lua` also builds the preparation surface envelope in the emerge
  environment (`writer_bounds`).
- Portable fixture and bounded-run harness: `tools/r23_full_column/`.

## Bounds and their derivation

Engine (reference pin): `RemoteClient::GetNextBlocks`
(`src/server/clientiface.cpp`) centres its Chebyshev block shells on the block
of the player's base position predicted 16 nodes ahead along the velocity
(`playerpos_predicted`), and generates shells with `d <= d_max_gen`, where
`d_max_gen = min(adjustDist(max_block_generate_distance, zoom_fov), wanted_range)`.
`creative_mode` is a disabled setting, so `zoom_fov` is 0 and `adjustDist`
returns the distance unchanged (`util/numeric.cpp`). Blocks within
`distance + 1` of the player's own block can therefore be generated.

- **Reach** R = (distance + 1) × 16 = **176 nodes** at the default 10. Because
  176 is a whole number of blocks, block(y ± 176) = block(y) ± 11 exactly; the
  node offset rounded outward to chunks is exact.
- **Window** = ceil((distance + 1) / chunksize) = ceil(11 / 5) = **±3 tiles**.
  A tile of blocks [b, b+4] is touched by players whose block lies in
  [b − 11, b + 15], i.e. tile indices k − 3 … k + 3.
- **Top** = max(600 + 8, window max content + 3) + 176, rounded outward. The
  8-node flight headroom covers the rider seat (≤ 2.86 nodes above the mount,
  catalog `attach_y × visual_size.y / 10`), eye height 1.625 and one step of
  climb past the clamp; 3 nodes cover feet plus a 1.25-node jump on the highest
  node. 784 falls in the chunk 768..847, so the headroom is absorbed by
  rounding. A window with content above 668 raises the top.
- **Bottom** = window min surface envelope − 176, rounded outward (the existing
  envelope: visible water down to eight nodes, functional, waterfall, template
  root depth).

The fixture proves the window and block arithmetic against an independent
brute-force reference: for every column within 11 blocks of a tile, a player
standing (feet low+1 … high+3) or flying (≤ 608) there may generate blocks
block(y) ± 11; every such block over the tile lies in the prepared column, and
the column exceeds the reference by less than one chunk.

In every measured tile (189 tiles in two regions) the column is **y −192 … 847,
13 chunks**.

## Chunk-class costs

Engine = time between the previous `on_generated` exit and this entry
(finishGen of the previous chunk incl. main-environment callbacks, then
makeChunk). Lua = the writer in the emerge environment. All measured, one
emerge thread, this workstation; comparisons, not targets.

| Class | Run 1 baseline (main) engine / Lua | Run 3 full path on the same chunks | Run 4 after (fast path) engine / Lua |
|---|---|---|---|
| Air above (native air, fast path) | 30.5 / 136 ms mean (74 air chunks; 52 noop: 70–140 ms) | Lua 80.9 ms (658 chunks) | **35.0 / 0.12 ms** (610) |
| Air near content (full path) | — | 96.9 ms (65) | 37.6 / 134 ms (73) |
| Surface | 38.8 / 410 ms (45) | 282 ms (121) | 40.7 / 301 ms (121) |
| Underground | 40.2 / 399 ms (31) | 313 ms (135) | 32.6 / 343 ms (129) |

Run 1 emerged whole tile columns (−272…847) over a start, ocean, coast,
mountain and a second start with the unchanged writer. Before the lever, Lua
dominated air chunks (≈ 75–80% of their time); after it their cost is the
engine's ≈ 35 ms. Per tile (8.5 fast chunks per tile in run 4) the lever saves
≈ 0.7 s: 2.06 s/tile measured after versus ≈ 2.75 s/tile estimated before
(run 4 plus the run 3 full-path cost of the same class). The first fast-path
decision per owner column scans its envelope (max 3.2 ms observed); later ones
are memo hits.

The remaining Lua cost is surface and underground chunks (≈ 1.1 s per tile).
Underground chunks are not provably unchanged: resources sample every land depth
(world_zones.md §11), cave plants grow in native caves at −500…−100 and below
−701, strata reach 40 nodes down, and 30 of 129 happened to be no-ops.

## Fast-path boundary and equivalence

Boundary: owner above `water_level`, the engine heightmap of the chunk has no
walkable node inside the owner, and owner min y > the writer's envelope over the
owner columns and their decoded content reach (and fitted boxes) + 16 nodes.
Rationale: above water level v7's terrain pass writes only stone or air;
floatlands are off; caves, caverns and dungeons return early above the highest
stone and only carve; the native ores replace stone; no Lua biomes or
decorations are registered. With native air in the owner and nothing of ours
that high, the R6 transaction returns `noop_equal_content` before any setter,
light or liquid call (`r6_settlement.lua`), so skipping it is identical.

Why not a pure v7 ceiling: the game pins only `mgv7_np_terrain_base/alt`
(base terrain ≤ 14 + 70 × 3.34 ≈ 248 with the per-point persistence ≤ 0.796).
Mountains use engine defaults: np_mountain −0.6 + Σ0.63ⁱ (5 octaves) ≤ 1.834,
np_mount_height 256 + 112 × Σ0.6ⁱ (3 octaves) ≤ 475.5, mount_zero_level 0, so
mountain stone is possible up to y ≈ 872 — above the prepared top 847. An
analytic-only boundary would leave no prepared chunk eligible, and it would
depend on unpinned server settings. The per-chunk heightmap is exact, already
computed by the engine for this chunk (no world scan), and costs ≈ 0.05 ms.

Evidence (`--verify`: full writer on every chunk; whole VoxelManip compared
before/after on every chunk the fast path skips — content, param2 and light of
the chunk and its 16-node shell, 1,404,928 nodes each):

- Run 2, 42 tiles around the human start: **372 chunks, 0 differ**, all
  `noop_equal_content`.
- Run 3, first 75 tiles of the final region: **658 chunks, 0 differ**.
- Run 1 (unchanged writer) returned `noop_equal_content` for every native-air
  chunk above the surface over ocean, coast and mountain tiles as well.

Classified fast in run 3: y ≥ 128 on most land tiles (58 of 75 at 128), every
chunk from 208 up.

## Scheduler, persistence and stop/resume

Engine run 3 stopped normally at committed tile 75 with requests pending; run 4
booted the same world, logged `world preparation mode=full cursor=75/400`,
continued at tile 76, committed through 147 and stopped normally. Fixture: the
two-request pipeline, ordered prefix, retry/stop, inner-chunk resume, rebuilt
window after restart (same selection as an uninterrupted run), batch-size
independence, window-bounded scanner memory, immutable persisted reach.

The first dispatch waits for the first window (3 rows + 4 tiles ≈ 301 tiles on
the full world); a restart rescans up to 7 rows (≈ 690 tiles). At about one
8,192-column step per tile (content reach ≈ 5) that is ≈ 30 s and ≈ 60 s
(estimate, unmeasured on the full world). Steady state needs one tile scan per
≈ 2 s of generation.

## Extrapolation

- Full world: 8,811 tiles × 13 chunks ≈ **114,500 chunks** (every measured
  column was 13 chunks; windows lower than −16 or content above 668 add one).
- Run 4 region mix: 2.06 s/tile → **≈ 5.0 h**, 0.35 MB map DB per tile →
  **≈ 3.1 GB**, peak RSS 2.88–2.92 GB. These come from 147 tiles of the final
  region and are to be replaced by the final run.

## Engine runs used (budget: about 4 × ≤ 5 min)

All through `tools/luanti_headless.sh` (`LC_ALL=C`, isolated user path, idle
scheduling), each ended by a normal shutdown requested from a server step.

1. Baseline costs: starts-only world, five tile columns emerged, 150 chunks.
2. `--verify --geo`, 42-tile region (complete in 137 s).
3. `--verify`, final region, stopped at 200 s (75 tiles), world kept.
4. Resume boot of run 3's world, measurement mode, stopped at 150 s.

No PUC runs (mapgen exemption). The ~15-minute final run is prepared, not run:
see [the harness README](../../tools/r23_full_column/README.md).

## Open risks

- The fast path's correctness rests on the preparation envelope being an upper
  bound of everything the writer places above the surface. Lane C changes
  capital walls; their boxes come from the blueprints, so they follow
  automatically, but the verify run should be repeated once after merging if
  the coordinator wants fresh evidence near a capital.
- Region mix: the measured regions hold a start and 40% water; capitals and
  high mountains may cost more per tile.
