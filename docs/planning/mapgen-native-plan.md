# Mapgen performance: native first

Coordinator: Claude (Opus 5.5), drafted 2026-10-15 from the user's
decisions in this session and two measurement lanes (MGPROF).
Status: **accepted by the user (2026-10-15) as Round 49** (release 0.49.0,
a map reset); built in Round 49 (2026-10-16,
[completion](round49-plan.md#completion-2026-10-16)).

Evidence:
- [mapgen-chunk-profile-2026-10.md](../research/mapgen-chunk-profile-2026-10.md)
  and `tools/mgprof/` (lane MGPROF, commits `26a57231` and `93974588`, merged
  to main), the per-stage chunk profiler this plan measures against.
- The user's live session of 2026-10-15 (builtin mod profiler and engine
  profiler, one player): the main thread spends about 1 % of a core in Lua;
  the single emerge thread spends about 87 % of its time in our mapgen Lua.
- Past v7 terrain experiments: [round9-decisions.md](../research/round9-decisions.md)
  rulings 30–35, [mapgen-performance-exploration.md](../research/mapgen-performance-exploration.md),
  [round23-full-column-preparation.md](../research/round23-full-column-preparation.md),
  BACKLOG "WP48".

## 1. Goal and starting point

Make world generation clearly cheaper, so that many players exploring,
above all underground, do not saturate the one emerge thread
(`num_emerge_threads = 1` stays pinned for Luanti #9357). Native v7 does
everything it can; our own Lua runs only where it is required: the
authored surface and the terrain fill where our surface lies above v7's.

Measured Lua per mapchunk (MGPROF, 6 boots, seed 12345, two ordinary land
columns; the engine's own `makeChunk` is 20–32 ms):

| chunk | Lua total | largest stages |
|---|---:|---|
| surface −32…47, first chunk of a column (cold) | 620–710 ms | P8 ores 35 %, cold planner (R6 decoration candidates 94–200 ms), R5 adapter 85 ms, P9G 57 ms |
| surface 48…127 (warm) | 210–270 ms | P9G 57 ms (24 %), P8 scanning air, R5 adapter 25 ms |
| −112…−33 (fill floor + T1/T2) | 330–490 ms | P8 85 % |
| wholly underground −192…−113 to −1072…−993 | 330–520 ms | P8 84–90 %; everything else 44–58 ms |

Further findings that shape the plan:
- **P8** (ores and gems, `r6_settlement.lua` ~3018–3222) checks every voxel
  once per active resource (3.5–6.3 M `host_eligible` calls per chunk), then
  grows veins with a frontier rebuilt per node and SHA-256 rank digests.
- **Slow-process regime:** in about 1 of 3 server starts the P8 host scan
  runs 2.3x slower for the whole process (a five-deep loop nest that LuaJIT
  sometimes leaves interpreted). Removing or flattening the scan removes it.
- **SHA-256** costs about 0.95 µs per framed digest against about 0.01 µs for
  an integer mix: 115 k calls in a cold surface chunk, 12 k in a warm one.
- **R5 adapter:** its resolve-and-validate pass (67 ms in S1) never compiles
  (`resolve_voxel`; the 10-value return of `classify`, `r7_content.lua:370`);
  a second replay pass costs 13 ms.
- **P9G:** a 2-D scan (52 ms) that is identical for every chunk of a column
  but is recomputed for each surface chunk.
- **Column cache:** the zones column cache (65,536 entries) is probably too
  small for one player's generate reach (about 180 k entries), so later
  chunks of a column may pay the 50–60 ms column cost again at runtime
  (inferred from code, not measured).

## 2. Rulings (the user, 2026-10-15)

1. **Native first.** Use native v7 (`core.register_ore`,
   `core.register_decoration`) wherever possible; own Lua only where it is
   required.
2. **Densities are rough targets.** The ore, gem, coal and anthracite
   frequencies in `world_zones.md` (the Round 21/46/47 density table) are
   rough targets, not exact budgets. Ore positions may change freely; the
   frequency stays roughly the same.
3. **Veins:** gems in veins of 1–2 nodes; coal and ores as larger clumps.
4. **Distribution:** uniform scatter; no noise-based ore regions.
5. **No ore exclusion under towns.** The rule "no resources above a
   hard-protected floor" is dropped.
6. **Protection depth under towns:** much smaller than today's placement
   height − 100, with a safety margin. The requirements are only: the town
   surface cannot be broken through, and no name tag under the town is
   visible from inside the town. Name tags show within 25 nodes and hide
   beyond 30 (3-D, `grug_core/tag_carrier.lua`). The depth need not be as
   small as possible; a generous margin is fine.
7. **Map reset accepted** whenever it buys clearly faster generation; no
   improvement is left out to avoid a reset. This round is a **map reset**.
8. **Preparation extents stay** (per tile from the window's lowest surface
   minus the generate reach up to the flight ceiling plus the reach): players
   at the surface, flying, and on their first mining near the top load
   everything from the world database and trigger no generation. This only
   concerns worlds with preparation. One addition: wherever our Lua still
   works below that bottom (high massifs, where the fill reaches down to
   y −37), preparation reaches down far enough that everything not prepared
   is plain v7 work (§4.4).
9. **No repeat of the Round 9 plateau.** v7 terrain changes are measured
   flag by flag (§4.8) and adopted only on the user's word.

## 3. Target picture

| what | who generates it |
|---|---|
| Ores, coal, anthracite, gems in native v7 rock, every depth | **v7**, `register_ore` scatter rows (§4.1) |
| Cave plants (`cave_cap` −100…−500, `ember_moss` ≤ −701) | **v7**, `register_decoration` with `all_floors` (§4.1) |
| Tier rock strata, gravel, decorative nests, caves, dungeons | **v7**, as today |
| Authored surface, settlements, roads, water, decorations, trees | own Lua, as today, made cheaper (§4.2, §4.5, §4.6) |
| Terrain fill (y −37 up to our surface where it lies above v7) and its ores | own Lua; fill ores by a flat single pass with an integer hash (§4.1) |
| Chunks with no Lua work | **skipped entirely** before planning (§4.3), like today's air chunks |

## 4. Work packages

Each package states the goal and the constraints; the briefs add the file
facts. Gains are MGPROF estimates, not targets.

### 4.1 ORE: ores, gems and cave plants native; simple fill ores

- Register one native `scatter` ore row per resource and tier band from the
  existing resource table (`RESOURCE_ROWS`, `r7_r6_manifest.lua:62-82`;
  tiers from `grug_materials.TIERS`):
  - `wherein`: the band's tier rock (`default:stone` in T1, `t2_stone` …
    `t6_stone` below). The native stratum rows that make the tier rock must
    be registered first (ore rows run in registration order).
  - `y_min`/`y_max`: the band; a "lower half" row (the table's fifth field)
    uses the band's lower half; the deep multipliers (5/4 from −1500, 3/2
    from −2000) become their own rows.
  - Rate: native scatter places, per host node, `clust_num_ores /
    clust_scarcity` ore nodes on average (`mg_ore.cpp` OreScatter), so
    `clust_scarcity = denominator × clust_num_ores` keeps today's frequency.
  - Cluster shapes (ruling 3): vein cap 8 (coal, copper, iron, quartz,
    anthracite): `clust_size 3, clust_num_ores 8` (T1 coal then equals the
    familiar default-game coal, 8³ scarcity); cap 4 (gold, emberglass):
    `clust_size 2, clust_num_ores 4`; cap 2 (gems, abyssal crystal):
    `clust_size 2, clust_num_ores 1` (about 60 % single nodes, 30 % pairs).
  - No noise, no biome filter (ruling 4).
  - Expected differences, accepted under ruling 2: a native cluster is a
    random sprinkle inside its cube (not necessarily face-connected, its size
    varies around the mean); a band that cuts a chunk in a slice no thicker
    than `clust_size` is skipped there (`mg_ore.cpp:89`); ores are placed
    after caves (never into cave air) and before dungeons.
- Cave plants become native simple decorations: `flags = "all_floors"`,
  `place_on` the row's host rocks, the row's y range, `fill_ratio =
  1 / density` (`all_floors` picks a column and decorates every floor in it,
  so the rate per floor node matches). The exclusions under towns and planned
  water are dropped for generation; runtime renewal
  (`vegetation_density.lua`) keeps working on the same density.
- P8 shrinks to the **terrain fill only**: one flat pass over the fill
  voxels the writer already knows (R5 opcode 27, plus the grading and
  foundation stone the user ruled a host on 2026-10-07), an integer hash per
  voxel against the same rates, the same cluster caps. No whole-chunk scan,
  no per-cell budget, no SHA. This also removes the slow-process regime.
- Drop the resource exclusion under hard-protected volumes (ruling 5) and,
  as a coordinator choice, the water-class exclusion (ores under deep ocean
  and the dragon channels are harmless: those columns are immutable).
- Refresh the native allowlist pins (`r7_native.lua` NATIVE_DIGEST and its
  validation in both environments) and the manifests the change touches.
- Estimate: underground Lua 330–520 ms → 44–58 ms before §4.3, about 0 after
  it; surface P8 (57–218 ms) → a few ms to a few tens of ms in fill chunks.

### 4.2 JIT: hot code the JIT can compile (output identical)

- R5 adapter: make `resolve_voxel`/`classify` compilable (no wide
  multi-value returns in the hot path) and fold the replay pass into the
  validate pass (MGPROF: −30..−50 ms and −12..−14 ms per surface chunk).
- `zones.lua` column lookup without `unpack(row, 1, 20)` (the most
  blacklisted location in both diagnostic boots).
- Proof: byte-identical seed fleet digests; the mgprof stage numbers before
  and after.

### 4.3 SKIP: no Lua for chunks without Lua work

- Before planning, a cheap test decides that a chunk has no Lua work: it lies
  wholly below the authored floor (y −37) and no authored volume (anchor,
  settlement, arena, underground reservation, tunnel or other exact owned
  volume) intersects it. Such a chunk returns immediately, like an air chunk.
  The test must be exact; a chunk that has work is never skipped.
- The above-water air check uses the planner's own surface envelope instead
  of reading the engine heightmap (12 ms per check today), if that is exact.
- Depends on ORE (native ores and cave plants are what make deep chunks free
  of Lua work).

### 4.4 PROT and PREP: protection depth and preparation bottom

- **PROT:** one constant drives all hard-protection floors
  (`source.protection_depth_below_placement = 100`,
  `wp40/source/simple_map.lua:530`): territory and PvP rule, start-town and
  capital spawn refusal, capital guard and mob level, cave-plant rule, and
  (dropped with ORE) the ore floor. New value: 30 (name-tag hide distance) +
  the deepest place a player can stand in a town below its placement height
  (cellars, graded plots, ponds, measured from the templates) + a safety
  margin of at least 10, rounded up; about 50 expected.
- **PREP:** a tile's prepared bottom becomes `min(today's bottom, y −37)`
  before chunk alignment (`grug_core/preparation_plan.lua:212`), so the chunk
  holding the fill floor (−112…−33) is always prepared. Only tiles whose
  whole ±3-tile window lies above about y 143 (high massifs) change; count
  them analytically from the height field, without generating, and report.
  New worlds (and map resets) only; an existing world's plan is immutable.

### 4.5 HASH: integer hash for the remaining digests (changes the world)

- Replace the SHA-256 digests in the stages that remain after ORE: R6
  decoration candidates (37–44 k per new column, −35..−40 ms), P9G (12 k per
  surface chunk, −11 ms), P9 decorations, and the fill ores (already part of
  ORE).
- The integer hash must give the same result under LuaJIT and plain Lua 5.1
  (no `bit` library; exact double arithmetic below 2^53) and must keep the
  independence of the streams it replaces (no visible patterns, rotations and
  variants still spread).
- Changes decoration, tree and gathering-source placement; terrain, water,
  roads, zones and settlements do not use these hashes.

### 4.6 CACHE: per-column reuse

Background (MGPROF follow-up, code reading): the cold planner cost lands on
the first chunk of a column that has Lua work. Full-world preparation walks
each column bottom-up, so only that chunk pays (after §4.3 and §4.4 the
chunk −112…−33 or the lowest surface chunk). At runtime the chunk nearest
the player pays, and later chunks of the same column may pay the column
cost again if the cache has evicted it. Building the R6 decoration
candidates lazily would only move their cost to the surface chunk and is not
planned.

- Cache P9G's 2-D result per 80×80 column so the second surface chunk of a
  column reuses it (−57 ms there; output identical).
- Column cache: first measure the runtime pattern with one engine run that
  requests chunks in player-shell order (one walking player, then two apart);
  only if later chunks of a column really re-pay the column cost, enlarge the
  cache or key it per chunk column. Report the memory it costs (about
  +50–60 MB estimated for 4x) before choosing.

### 4.7 MEAS: before and after

- The mgprof corpus (same seed and columns) on main before the round and after
  the last merge; one table, stages and totals, and chunks per second of one
  emerge thread.
- One engine run counts native ore and gem nodes per tier band in a few
  underground chunks and compares them with the density table (rough targets,
  so a report, not a gate).
- The first start of a fresh world in starts-only mode, before and after.

### 4.8 V7: flags one at a time (measurement, then the user decides)

- Never measured on their own: `nomountains` and `noridges` (the Round 9
  plateau dropped both together with a flattened terrain and is not
  repeated). v7 mountains can reach y ≈ 872 regardless of our relief, which
  the writer then clears voxel by voxel; ridges carve river channels though
  our water is fully authored.
- What is already known (do not re-measure): the Round 9 plateau
  (terrain_base/alt constant, together with `nomountains,noridges`) cost
  +29..+70 % emerge time because the writer pays per modified voxel; it was
  withdrawn (ruling 35) and never re-measured after R9-PERF (writer −35 %).
  The fill has no caves (Round 24 ruling 13) and native caves are rare above
  y ≈ 160 anyway (Round 22).
- The trade-off to report: less v7 rock above our surface means less
  clearing but more fill where our surface is higher, and fill ores stay in
  Lua (§4.1).
- After ORE and JIT are on main: the mgprof corpus plus one mountain-heavy and
  one ridge-heavy column, baseline vs `nomountains` vs `noridges`, reporting
  the R5 adapter split (clearing vs fill), the air fast-path share and the
  near-surface native cave air share.
- Adopting a flag changes v7 input (pins: NOISE_DIGEST/flags validation in
  `r7_runtime.lua`, `map_adapter.lua`, `planner.lua`, `mapgen_manifest.lua`,
  `r7_r6_manifest.lua`); it is a map reset, which this round is anyway.

### 4.9 D: documentation

- `world_zones.md`: the resource section and density table become rough
  targets with the native mapping (§4.1), the cave-plant rows, the protection
  floor; `world_preparation.md`: the bottom rule and the skipped chunks;
  `world.md`, `combat_stats.md`, `farming.md`: the new protection depth.
- BACKLOG WP48 updated (what is done, what remains: multiple emerge threads
  after Luanti #9357); the stale `tools/wp40/profile` stage patch pointed to
  `tools/mgprof/`; CHANGELOG, STATUS.

## 5. Lanes and waves

| Lane | Packages | Wave | Merge waits for |
|---|---|---|---|
| ORE | §4.1 | 1 | — |
| JIT | §4.2 | 1 | — |
| PROT | §4.4 (both parts) | 1 | — |
| SKIP | §4.3 | 2 | ORE |
| HASH | §4.5 | 2 | ORE, JIT |
| CACHE | §4.6 | 2 | JIT |
| V7 | §4.8 measurement | 2 | ORE, JIT; adoption (wave 3) only on the user's word |
| MEAS | §4.7 | before wave 1 and after the last merge | — |
| D | §4.9 | 3 | the last merge |

File overlaps to watch: `r6_settlement.lua` (ORE: P8; HASH: P9; JIT: the R5
adapter call site), `r7_p9g.lua` (HASH, CACHE), `zones.lua` (JIT, CACHE),
`map_adapter.lua` and `r7_content.lua` (JIT only). Wave 2 starts from main
after its predecessors merged.

## 6. Rules

- Routing as in Round 48 (§9): Claude coordinates, Opus implements and
  reviews.
- Every code lane gets an independent review; fix deltas with logic are
  reviewed again.
- **Fixtures:** own fixture plus the fixtures that test the changed
  behaviour during development; the full run once before the report.
  Fixtures and seed-fleet checks that pin exact ore or gem counts become
  rough ranges (ruling 2); no new exact pins.
- **Seed fleet:** `quick` before merging each world-generation lane (ORE,
  JIT, SKIP, HASH, CACHE); `full` once at the round end. JIT and CACHE must be
  byte-identical; ORE, SKIP and HASH change output by design. Note that the
  fleet's fake VoxelManip has no native ores or decorations: native placement
  is checked by the engine count in §4.7.
- **Engine runs:** only `tools/luanti_headless.sh` through the shared queue,
  `LC_ALL=C`, never the user's Luanti folder; few runs of at most about
  5 minutes, only chosen chunks or a small region, never the whole world;
  more goes to the user first.
- **Numbers are comparisons, never targets.** A lane that gets noticeably
  slower or more complex reports to the coordinator.
- **Release:** map reset; version and upgrade declaration by the coordinator.
  Push only on the user's word.

## 7. Verification at the round end

- MEAS before/after table (§4.7) and the native ore count.
- Seed fleet `full`, full fixtures, smoke boot, `check_upgrade.py`,
  `check_fresh_server.py`.
- **GUI checklist** (a new world after the map reset):
  1. Mining at several depths finds ores and gems roughly as often as before;
     gems mostly single nodes or pairs, coal and ores in clumps.
  2. Mountains built by the fill still hold ores.
  3. Cave plants grow on cave floors in their depth bands.
  4. A town's surface cannot be broken through; digging down beside a town and
     under it works below the new floor; no name tag under the town shows from
     inside it.
  5. Walking, riding and flying over prepared land trigger no visible
     generation; going deep underground generates quickly.

## 8. Not in this round

- **The game thread:** about 1 % of a core in Lua with one player; mobs'
  `on_step` is its largest share (61 %) and grows with active objects. To be
  watched in a multi-player playtest, no change now.
- **Several emerge threads:** blocked by Luanti #9357 (native ores and caves
  lost in chunk edge slices); check for PR #16224 at every engine update.
- **Process-wide JIT knobs** (`jit.flush`, `hotexit`, `jit.opt`) against the
  slow-process regime: they do not target the cause; removing the scan does.
- **Lazy R6 decoration candidates:** they only move the cost (§4.6).
- **Native surface decorations or trees:** v7 places them on its own surface
  before our writer reshapes the terrain, so they would float or be buried.

## 9. Answers of the user (2026-10-15)

1. Round 49, release 0.49.0, a map reset.
2. Routing as in Round 48: Claude coordinates, Opus implements and reviews.
3. Cave plants native: accepted that they may also grow in caves under
   planned water and inside town protection.
4. About +50–60 MB of server memory for a larger column cache is acceptable
   if the runtime probe shows it pays off.
5. The V7 flag measurement runs in wave 2 as planned.
