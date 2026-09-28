# Round 23 — full-column preparation, living vegetation, capital walls

Decided with the user on 2026-09-28. Coordinator: Claude (Opus 5.5); implementation
and independent review run as native Opus subagents. Rulings below are the
contract for the Phase 1 lanes; implementation agents do not invent design
beyond them.

## Why

On a fully prepared world, the visible surface still loads slower than it
should. Engine facts (reference pin `reference_projects/luanti`, 5.17-dev):

- `RemoteClient::GetNextBlocks` walks Chebyshev shells in **mapblocks** around
  the player, y included (`src/server/clientiface.cpp:258`). Generation is
  allowed up to `max_block_generate_distance` (default 10 = 160 nodes, plus one
  block for the predicted position), inside the view cone, the send sphere and
  server-side occlusion (`:283-297`, `:357`). One requested block generates
  its whole 80³ mapchunk.
- Unloaded nodes never occlude (`src/map.cpp:680`): sky air is always
  requested, underground mostly occluded once the surface is loaded.
- Air blocks at `d >= 4` are never sent (`clientiface.cpp:339`); they are
  generated only to learn that they are air.
- While any in-view block at distance `d` waits for an emerge, the next step
  restarts at `d` and scans only `d..d+2` (`:232`, `:367`, `:391`). With
  `num_emerge_threads = 1` there is one FIFO queue for **all** players
  (`src/emerge.cpp:489`, `:536`), and every generation also holds the env lock
  while main-environment `on_generated` callbacks run (`emerge.cpp:590`). One
  player triggering generation (for example flying) delays disk loads and
  block delivery for everybody.
- Lowering `max_block_generate_distance` is not a lever: a non-generating
  request for a missing block is cancelled without creating it
  (`emerge.cpp:584`) and re-queued every step, which freezes the send front.

Rejected alternatives (researched 2026-09-28): an external parallel generator
project (feasible, but adds a stack import path and a canonical order; the
user prefers the in-game option and accepts a many-hour preparation) and an
own engine patch for Luanti #9357 (needs a custom server build; the
production host has 4 CPUs/8 GiB; a fully prepared column already removes
live generation).

## Phase 1 — three parallel lanes, disjoint files

### Lane A — full-column world preparation (WP48)

- Full mode prepares, per horizontal tile, the whole column players can see
  or trigger:
  - **Top:** above the flight ceiling (`FLIGHT_CEILING` 600 + eye height +
    the generate reach of `max_block_generate_distance` + 1 predicted
    block), rounded out to mapchunks. Where terrain within the tile
    neighbourhood is higher, neighbourhood maximum surface + generate reach.
  - **Bottom:** neighbourhood minimum surface − generate reach, rounded out.
  - **Neighbourhood:** tiles within the generate reach horizontally (±3 tiles
    for chunksize 5 and distance 10).
  - Horizontal bounds unchanged.
- Fresh worlds only. Engine settings unchanged.
- Performance lever: chunks the Lua writer cannot change (entirely above
  everything v7 or the writer can place, or underground chunks without
  writer work) must be nearly free on the Lua side. The v7 ceiling is derived
  analytically from the pinned noise parameters, never by scanning the
  world. Fast-path output must equal the full path's output.
- Lane A does not touch `grug_farming/ecology.lua` (Lane B removes its
  generation callback).

### Lane B — habitat-driven vegetation renewal (WP32/WP33 area)

The Round 11 "exact-baseline" ecology (a world-sized registry of every
generated natural plant in one mod-storage string, re-serialized after each
observation) is replaced. Rulings:

1. Plants re-appear **from habitat**, not from neighbours: suitable ground,
   zone, biome, light, free space, altitude. Nothing can go extinct.
2. **Density cap = the natural density** the mapgen would place there. The
   chance to place rises with the local deficit; a full area gets nothing.
   Resource plants count per species; decorative vegetation counts as a
   total and the zone palette picks the species.
3. Plants may also grow on player-made ground (VoxeLibre behaviour). Farm soil
   and protected areas (settlements, POIs, roads, functional surfaces,
   claims) are excluded.
4. Renewal only near players (loaded area), with a minimum distance of about
   20 nodes so nothing pops up in view, a fixed budget per player, no
   catch-up for unvisited areas. Caves are included (cave plants).
5. Rate: first version by feel, tuned by the user in playtest.
6. Decorative vegetation (grass tufts, flowers, ferns and similar) also
   renews.
7. Trees renew as **saplings** that grow through the existing sapling timers,
   behind a `minetest.conf` setting (default on). Target density = the
   natural tree density, measured by counting trunks around the spot. **No
   sapling within about 10 m of any non-natural node or of farm soil.**
8. Apples and blueberries leave the ecology system; the vendored `default`
   node timers already regrow them.
9. Initial mapgen density stays unchanged in this round.
10. All habitat and density rules come from the shared habitat authority used
    by the mapgen, so the Phase 2 tree line and forest density apply to
    renewal automatically.

### Lane C — capital walls (WP13)

Capitals only; start towns, villages and POIs keep their current edges.

- **Humans (Highcourt):** outer wall unchanged. The core hedge becomes a stone
  wall in the outer wall's style, one node thick on the same footprint, one
  node taller than the hedge, with crenellations.
- **Dwarves (Dur Brannoc):** core wall one node taller; nothing else.
- **Elves (Lethariel):** outer edge becomes the shared stone curtain model
  with gatehouses, restyled light with finer ornament. Core: a one-node wall
  in the same style.
- **Trolls (Kezamba):** core wall unchanged. Outer edge becomes the orc
  palisade model, restyled with the troll core wall's wood and crenellations,
  with the palisade's own gate passages.
- **Orcs (Gor Drazhak):** core wall one node taller.
- **Undead (Nhal Veyr):** close the gaps between the iron bars and the stone
  in the core wall's bar course.
- Styles: first version by feel; the user reviews visually.

### Coordination

- Lanes work in their own worktrees and branches, do not edit
  `BACKLOG.md`, `README.md`, `ROADMAP.md`, `AGENTS.md` or `docs/STATUS.md`
  (the coordinator updates those at integration) and do not run
  `tools/sync_to_luanti.sh`.
- B and C merge before Lane A's final measurement run.
- Every lane gets an independent review before merge.

### Engine run budget (user ruling 2026-09-28)

Portable fixtures as the main correctness proof. A few engine runs during
development, each at most about 5 minutes. One final run of about 15 minutes
over a chosen small region (ocean, coast, mountain, a start), bounded by
region, ended by a normal shutdown. No full-world runs, no repeated long
runs, reviewers read receipts instead of re-running. Analytic bounds instead
of world scans. Needing more means asking the user first. Engine runs use
`tools/luanti_headless.sh` (isolated user path, `LC_ALL=C`), and
`pgrep -f '^luanti.bin'` is empty afterwards. Mapgen work runs no PUC.

## Phase 1 status

Delivered 2026-09-28: [completion](../research/round23-completion.md). Later
user rulings: the seabed is part of the prepared bottom envelope; Lethariel
and Kezamba walls end at the civic lake shores. After the playtest (same day)
the walls are continuous on land and run 2–3 nodes into the lake to a closed
head (no dry margin, no lone pieces), and Lethariel's crown is lower
([receipt](../research/round23-capital-walls.md#playtest-fix-continuous-walls-at-the-civic-lakes-low-elf-crown)).

## Phase 2 — vegetation and altitude (rulings 2026-09-28)

Facts (portable probes over four seeds, 1 node = 1 m):
- The land median is y ≈ 73, p90 ≈ 185, p99 ≈ 315, and the highest peaks
  reach y ≈ 520–547. Nothing caps terrain height.
- Capitals sit at y 37–71, with ground within 300 nodes ≤ 122, so no capital
  rule is needed.
- Today no upper altitude limit exists for any vegetation.

Rulings:

1. **Lines:** trees thin linearly from y **160** to zero at y **220**; snow
   from y **280**. About 5 % of land becomes treeless and about 2 % snowy.
2. **Jitter:** a smooth noise field shifts the lines by about ±15 nodes, so
   they form tongues and bays instead of contour lines.
3. **Warm biomes:** jungle biomes, savanna, badlands and the Skyglass cloud
   forest get tree and snow lines **+40**. Cold biomes (crags, pine hills)
   keep the base.
4. **Transition band:** as trees thin, the biome's own shrubs increase:
   - pine hills and crags: pine bush;
   - forest, elf forest and meadows: bush;
   - savanna: acacia bush;
   - blight and bone forest: dry shrub.

   Shrubs reach about 40 nodes above the tree line. Above them, alpine
   meadow (ground cover) continues to the snow line.
5. **Snow:**
   - Above the snow line, a snowblock top with snow dust (existing
     `default:snowblock` and `default:snow`, as in the crags snowy biome).
   - Below it, a patchy snow-dust band about 20 nodes wide.
   - Steep rock faces (D77) stay bare rock.
   - No ice this round, and no slope-aspect rule (it would need neighbour
     columns, which is the hot path).
6. **Forests and clearings:** a noise field inside zones makes groves of
   roughly 150–300 nodes and clearings of 40–100 nodes, with each zone's mean
   density unchanged. Deep forest and deep jungle become about 1.5× denser.
7. **Crags snowy pine:** it obeys the tree line too, and is the typical last
   tree in the band.
8. **Renewal:** it follows through the shared rule
   (`habitat_registry.vegetation_factor`), with trees and bushes counted as
   separate classes.

Implementation: one mapgen lane with independent review, and the same engine
run budget as Phase 1. Before/after renders of a high mountain and a forest
for the user's visual check. Afterwards: a fresh world, then the full
preparation on the production server.

## Phase 3

The user runs the full-world preparation on the production server with a
fresh world, then playtests.
