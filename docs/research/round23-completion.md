# Round 23 completion — full-column preparation, habitat renewal, capital walls

Date: 2026-09-28. Contract: [Round 23 plan](../planning/round23-world-life-plan.md).
Coordinator: Claude Opus 5.5. Implementation and every independent review ran
as separate native Opus subagents; no reviewer reviewed its own work.

## Delivered

| Lane | Branch | Merge | Receipt |
|---|---|---|---|
| A — full-column world preparation (WP48) | `wp48-full-column-preparation` | `1fb3ec0b` | [receipt](round23-full-column-preparation.md) |
| B — habitat-driven vegetation renewal (WP32/WP33 area) | `wp33-habitat-renewal` | `f5a545bd` | [receipt](round23-habitat-renewal.md) |
| C — capital walls (WP13) | `wp13-capital-walls` | `7396339f` | [receipt](round23-capital-walls.md) |
| C follow-up — walls end at the civic lake shores | `wp13-capital-walls-shore` | `28a9a2a3` | [receipt](round23-capital-walls.md) |

**A.** In full-world mode each horizontal tile is prepared from the
neighbourhood's lowest surface or water bed minus the generate reach (176
nodes at the default `max_block_generate_distance` 10) up to above the mount
flight ceiling (600) plus reach: y −192 or −272 up to 847. Walking, diving,
flying and looking around therefore trigger no generation on a finished world.
The remaining on-demand cases are listed in
[world_preparation.md](../design/world_preparation.md). A writer fast path
skips chunks the Lua writer provably cannot change: Lua time for those falls
from ~125 ms to 0.08 ms, with byte-identical output (content, param2, light of
chunk and shell) on 1,210 compared chunks, including Lethariel. The final
region run covered 400 tiles, 5,422 chunks in 698 s. Extrapolated full world:
~119,400 chunks, ~4.2 h, ~2.9 GB map database, peak RSS 3.49 GB. These are
comparisons on this workstation, not targets.

**B.** The Round 11 exact-baseline ecology is gone: it kept a world-sized
registry in one mod-storage string, re-serialized after every observation,
with a main-environment `on_generated`. It is replaced by budgeted renewal
around players:
- Plants re-appear from habitat and never exceed the density the mapgen
  would place. Each plant class follows its writer's own exclusion rules.
- Renewal happens at least ~20 nodes from players and includes caves.
- Saplings are behind `grug_tree_regrowth` (default on), with a 10-node guard
  against non-natural nodes and farm soil.
- Apples and blueberries use the vendored `default` timers.
- Mapgen output is unchanged.
- Measured cost: 0.19 ms mean per player service.

**C.** Highcourt's core hedge becomes a crenellated stone wall on the same
footprint. Dur Brannoc and Gor Drazhak cores are one course taller. The Nhal
Veyr bar course is closed. Lethariel gets a light stone curtain with
gatehouses and a matching core wall. Kezamba gets a troll palisade. Walls end
at the Lethariel and Kezamba lake shores, closed by a gatehouse or an end
tower. Layouts, streets, gates, plots and the four unchanged outer edges stay
byte-identical.

## Reviews

- **A:** two lenses, fast path and plan/scheduler. Both PASS. One Medium
  documentation gap (diving) became a user ruling: the seabed is now
  included.
- **B:** FIX REQUIRED for one Medium issue (resource plants used the
  vegetation exclusion rule instead of the resource writers' territory
  rule), plus two Lows. All fixed and checked by the coordinator.
- **C:** PASS with two Lows, noted in the receipt.
- **C follow-up:** PASS with four Lows (receipt wording corrected; rare end-tower edge water, gates without a dry slide spot unchanged).

## Calibration

- **Engine runs:** A 6 (including the ~12 min final run), B 6, C 3 + 2. All
  isolated, all ended by a normal shutdown.
- No full-world runs. No PUC for mapgen work. B ran its final LuaJIT/PUC
  fixture pair and got byte-identical output.

## Runtime test plan (fresh world, `grug_prepare_full_world = true`)

1. Start a fresh world and let the preparation finish. Expect several hours:
   ~4 h on this workstation, longer on a smaller host. Then walk, fly with a
   mount up to the ceiling, and dive to a seabed. The world should load
   without the slow generation front, including for a second player
   elsewhere.
2. Mow grass and pick wild resource plants in a meadow, walk 25–45 nodes
   away and wait 2–3 minutes: grass returns, nothing pops up next to you.
3. Fell trees in open forest and move away: local saplings appear and grow
   within 5–25 minutes. Nothing appears near your own placed blocks or farm
   soil, and nothing appears with `grug_tree_regrowth = false`.
4. Visit the capitals:
   - Highcourt: the core wall and gates.
   - Dur Brannoc and Gor Drazhak: taller cores.
   - Nhal Veyr: closed bars.
   - Lethariel: light curtain, gatehouses and turret lamps; the wall ends at
     the lake.
   - Kezamba: palisade and gates; the wall ends at the cenote.

## Next

Phase 2 (tree line, forests and clearings, snow and ice) starts with a design
discussion. Then the user prepares the production world on a fresh server.
