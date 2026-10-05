# Upstream workarounds

Workarounds in our code for engine (Luanti) problems that upstream is
expected to fix one day. Each entry says what is wrong upstream, what we do
instead and where, how to tell that upstream fixed it, and what to remove
then. Rule (Round 35 plan §2.10): check this list at every engine version
change and at the start of each round; a workaround goes once its fix is in
the engine version we require.

Engine reference for the line citations: `reference_projects/luanti` at
`df0487906` (5.17.0-dev); the user plays on Luanti 5.17.0 (Flatpak).

## 1. Server raycast misreads rotated selection boxes

- **Upstream problem:** the server's raycast (`core.raycast(..., objects =
  true)`) turns a `rotate = true` selection box by its rotation in
  **degrees read as radians**. `ServerEnvironment::getSelectedActiveObjects`
  (`src/serverenvironment.cpp`) passes `UnitSAO::getTotalRotation()`
  (`src/server/unit_sao.h`, returns degrees) to `boxLineCollision(box,
  rotation_radians, ...)` (`src/raycast.cpp`). Every yaw but 0 turns the box
  wrongly; beyond ±90° it is tipped over, so the server misses the upper body
  of tall, narrow mobs (zombies, skeletons, felines, hyenas) and the side of
  long ones (the crocodile) while the client points at them. The client is
  right (it passes radians).
- **Issue:** filed by the user and **fixed on upstream master** (user,
  2026-10-05); not yet in a release. The fix is expected in the next Luanti
  version after 5.17.0. Remove the workaround once we require that version
  and `upstream_check.sh` reports `FIXED` on it.
- **Affected versions:** 5.12.0 and later, up to at least 5.17.0 and `master`
  at `df0487906`. Introduced by upstream commit `d74af2f1a` ("Use
  matrix4::getRotationRadians", 2025-01-30), which moved the degree
  conversion out of `boxLineCollision` into its callers and updated only the
  client's.
- **Our workaround:** `grug_core.aim_raycast` in
  `mods/CORE/grug_core/combat_ray.lua` (Round 35 Lane T). It runs the
  engine's raycast for nodes and every other object, drops the engine's hits
  on objects with a rotated box, and tests those boxes in Lua, turned exactly
  as the client turns them (`setPitchYawRoll(-rotation)` from
  `GenericCAO::updateNodePos`), merged by distance in the engine's order
  (a `"blocking"` one ends the ray, as in the engine). Its candidate area is
  the ray's box widened by the engine's 5 nodes or by the largest registered
  rotated reach when that is larger (a dragon's, about 6.2 nodes: with 5
  nodes a ray at its wing tip or tail would be missed; the client has no
  such limit).
  Every server-side aiming ray uses it: `grug_core.combat_ray` (held swings,
  skill targets through `grug_abilities.aimed_target`, the crosshair colour,
  projectiles' aim), the hold ray in `grug_abilities/input.lua` (`ray()`),
  the right-click interaction ray in `grug_abilities/init.lua`
  (`ability_on_secondary_use`) and the Target Frame's look ray
  (`grug_mobs/target_frame.lua`). Fixture: `tools/r35_t/portable_test.lua`.
- **Cost** (`tools/r35_t/engine.sh`: 20 frozen zombies in a 6 × 6 cluster,
  six fake players 2.5 m from their own zombie; µs per ray, median / best,
  each round alternating with the plain engine ray):

  | Ray | Engine ray only | With the workaround |
  |---|---|---|
  | `combat_ray` 4 m (melee hold) | 13.9 / 13.6 | 35 / 33 |
  | `combat_ray` 20 m | 21.3 / 20.8 | 59 / 52 |
  | `aimed_target` (Fireball) 20 m | 21.9 / 21.6 | 67 / 53 |

  Medians vary between runs because of garbage collection (the property
  tables): the independent review measured the `aimed_target` 20 m median
  at 137 µs against 22 µs before (best 56 µs). Parts: the candidate query
  with one luaentity per object about 4 µs (40 objects), one
  `get_properties()` about 1.6 µs per rotated hit, and a 20 m ray through
  the cluster now hits 7.7 objects instead of 4.8 (correct hits are also
  classified). Per server step the review estimates about 1–2.5 ms of
  server time per second per fighting player in the worst case of 20
  rotated mobs around every ray (crosshair refresh plus held-attack rays).
- **How to tell upstream fixed it:** `tools/r35_t/upstream_check.sh` boots
  the installed engine headless with a disposable probe (the issue's repro:
  a tall rotated box turned through 0–345°, one ray per yaw through the
  engine alone) and prints `FIXED` (exit 0) or `BUG PRESENT` (exit 3). On
  5.17.0 it reports 8 of 24 yaws missing (105, 120, 150, 180, 195, 225, 240,
  255). `tools/r35_t/engine.sh` additionally shows `engine_misses=0` in its
  SWEEP lines on a fixed engine.
- **What to remove then:** in `combat_ray.lua` everything from the
  "Rotated selection boxes" comment down to `grug_core.aim_raycast`
  (`ENGINE_MARGIN`, `aim_margin`, `rotated_hint`, `box_reach`, `margin`,
  `is_rotated_object`, `pointable`, `slab`, `enter_box`, `box_matrix`,
  `box_hit`, `same_box`, `rotated_hits`); keep `grug_core.aim_raycast` as
  a thin `core.raycast(origin, destination, true, liquids, pointabilities)`
  or put `core.raycast` back at its call sites; drop the fixture's rotated
  cases (`tools/r35_t/portable_test.lua`) and the `aim_raycast` stubs in
  `tools/r28_a4`, `tools/r30_p4`, `tools/r31_pvp` and `tools/r32_f2`.

## 2. More than one emerge thread loses ores and caves at chunk edges

- **Upstream problem:** with `num_emerge_threads > 1`, mapgen v7 (also
  valleys, carpathian) leaves "unfinished" y-slices at mapblock borders,
  usually a mapchunk's top or bottom slice: biome nodes, ores and caves are
  missing, decorations are cut off. The engine itself enables several
  threads by default only for singlenode (`src/emerge.cpp`
  `EmergeManager::initMapgens`, comment citing the issue).
- **Issue:** <https://github.com/luanti-org/luanti/issues/9357> (open as of
  2026-10-05; proposed fix PR #16224, open).
- **Affected versions:** since at least 0.4.17, all current versions.
- **Our workaround:** the pin `num_emerge_threads = 1` in `minetest.conf`
  (WP40 R7 production defaults). The R7 mapgen manifest requires it and
  fails closed on any other value
  (`mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua` `emerge_threads = 1`,
  `planner.lua` check, `r7_r6_manifest.lua`; `r6_settlement.lua` relies on a
  whole-or-nothing placement under one thread). WP48's parallel-emerge
  lever (BACKLOG) waits for the fix.
- **How to tell upstream fixed it:** the issue is closed by a merged fix in
  an engine version we require, and `src/emerge.cpp` no longer restricts
  multithreading to singlenode. Then a mapgen round runs the seed fleet
  (`tools/seed_fleet/run.sh full`) and an ore/cave census across chunk
  borders with two or more threads against the one-thread world.
- **What to remove then:** not a plain deletion: raising the thread count is
  a mapgen decision (determinism of the R7 writer and settlement placement
  under parallel emerge must be shown first). The pin, the manifest's
  `emerge_threads` field and its planner check change together.

## Checked and not listed

- `mods/BASE/default/nodes.lua` (sign `on_receive_fields`: ignore fields
  without `quit`, "workaround for luanti#16187"): vendored upstream
  minetest_game code, not ours. The engine bug (fields sent twice on the
  exit button, 5.12) was fixed upstream in 5.13 (PR #16198); the line goes
  with a minetest_game vendor update (VENDOR.md), not through this list.
- `hud_change` sends a packet on every call (engine "FIXME: only send when
  actually changed", `src/script/lua_api/l_object.cpp`), so
  `grug_core/hud_layout.lua` and the HUD bars in `grug_abilities/init.lua`
  write only changed, pixel-quantized values. Skipping a no-op call stays
  right after an upstream fix; nothing to remove.
- `grug_ambience` drops loop emitters beyond their hearing distance itself
  because `max_hear_distance` does not apply to a `to_player` sound: engine
  semantics, not a bug.
- Comments that describe engine behaviour our code follows (attached-node
  lamps in `grug_mapgen/wp13/parts.lua`, craft replacements in
  `grug_traders/prices.lua`, the client camera offset FIXME `#16221` in the
  engine itself): no workaround on our side.
