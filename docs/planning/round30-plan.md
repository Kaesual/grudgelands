# Round 30 — Performance and clean-up: round plan

Coordinator: Claude (Opus 5.5), 2026-10-02. Status: **approved by the user
2026-10-02** (wave 1 go; §7 defaults accepted); **complete locally**
([Completion](#completion-2026-10-02)).

This plan schedules agreed inputs; it does not repeat their findings:

| Input | What it decides |
|---|---|
| [perf-review-2026-10.md](../research/perf-review-2026-10.md) | 22 findings with evidence, the region-map cache design (§3), the lane split P1–P4 (§5) |
| BACKLOG [Round 30 — performance](../../BACKLOG.md#round-30--performance) | the user's rulings of 2026-10-02 (#4, #3, #11, cache) and the additions beside the performance lanes |
| BACKLOG [Round 29 carry-overs](../../BACKLOG.md#round-29-carry-overs) | details of the island landings, legacy quest fields, stale fixtures, possible bugs, band-5 smoothing |

Routing (user, per session): Claude orchestrates; **Opus implements and
reviews** (independent Opus review per lane, never the implementer);
**GPT-6 Astra** only art and quest texts (none planned this round).

Out of scope: PvP (WP41, Round 31, planned in its own session), the WP9
storyline (Round 32). The PvP session is told that this round owns mobs,
quest state, map UI, spawn regions, crafting lookup and the crosshair.

## 1. Rulings already made (user, 2026-10-02)

| Finding | Ruling |
|---|---|
| #4 unreachable targets | Mobs **give up** a static target they cannot reach instead of repeating a full no-path A* forever. |
| #2 region maps | **File cache yes**, design of report §3. |
| #3 Map tab | Arrow and rebuild **at most every 2 s**; rebuild only when the marker signature changes; one shared marker style. |
| #11 spawn ABMs | **Retire the surface spawn ABMs** where the region spawner is authoritative; **merge the rest** (underground, ocean, rift) into a few ABMs. |
| other findings | as the report recommends |
| island landings | each of the four dragon-island boat landings gets a **simple wooden pier and a little beach** |
| band 5 | smooth the loot medians, then recompute the E4 prices |

## 2. Lanes

| Lane | Content | Main files | Depends on |
|---|---|---|---|
| **P1** Quest state & map UI | #1 per-player decoded-state cache + `Q.marker_states`; #5 tracker HUD slot-spread + fingerprint skip; #3 Map tab (ruling above); #12 minimap glide hoisting; the quest NPC tag callback part of #10 | `grug_quests/state.lua`, `npc.lua`, `hud.lua`; `grug_map/providers.lua`, `page.lua`, `minimap.lua` | — |
| **P3** Region-map cache & boot memory | #2 cache (report §3: `spawn_regions_cache.lua`, key, per-zone digest, failure handling, input-coverage test); #9 compact form after every build + full-build call for the three tools; heap log after full GC at boot; #20 zone-marker placement into a cache; #21 road-segment buckets; **investigate #22** (grug_mapgen runtime load on a cache hit) and report only | `grug_mobs/spawn_regions*.lua`, `grug_map/location.lua`, `tools/r28_s1`, `tools/r28_zone_atlas` | — |
| **L** Island landings | a wooden pier and a beach at each landing in `source.island_landings` (§3) | `grug_mapgen/wp40` (height/terrain near landings, a small pier writer), mapgen self-check | — |
| **C** Clean-up | legacy quest fields out of `grug_quests` (`registry.lua`, `validate.lua` `LEGACY_GUARDS`) and `tools/r28_design/validate.py --legacy` + README; repair `tools/r24_density_xp` and `tools/r25_spawn_guard` (or delete them if what they guard no longer exists — report which); riding-tier purchase fixture (tiers 1–4 at shipped prices, next to `tools/r29_e4`); the 18 "No craft recipe known for output" boot warnings (fix the `clear_craft` calls or explain each); **investigate** the Dawnmere NPC duplication (fix only with a found cause) | `grug_quests` loader/validator, `tools/r28_design`, the fixtures, `clear_craft` call sites, `grug_mobs/start_npcs.lua` | — |
| **E** Band-5 smoothing | move the band-4 and band-5 loot medians toward the target axis, then `tools/r29_e4/income.py --check` and update mount/boat/respec prices from it; the band-3 outliers if a T3 replacement now exists | loot tables / `subtypes.lua` drops, `grug_mounts`, `grug_classes`, `economy-vendor-plan.md` numbers | — |
| **P2** Mob pathing & allocation | #4 (back-off 1-2-4-8 s, small searchdistance in the close-obstacle branch, time budget, give-up rule); #13 patrol nudge through the budget; #6 collision-box field + idle `reassert_max` skip; #17 privilege cache; #18 `mobs_can_hear = false`; #11 spawn ABMs (ruling above); the `general_attack` eye-height bug | `mobs/api.lua` (GRUG PATCH markers, VENDOR.md), `grug_obstacle.lua`, `grug_mobs/patrol.lua`, `aggro.lua`, `separation.lua`, `flight.lua`, `init.lua`, spawn rows; `minetest.conf` | E merged (both edit `grug_mobs` data) |
| **P4** Per-player ticks & misc | #7 crafting index; #8 crosshair throttle + ray reuse; #10 carrier slotting; #14 flight sweep; #15/#16 farming timers and crop LBM; #19 per-player tables cleared on leave | `grug_jobs/registry.lua`, `stations.lua`; `grug_abilities/init.lua`, `input.lua`; `grug_mobs/target_frame.lua`; `grug_core/tag_carrier.lua`, `combat.lua`; `grug_mounts/entity.lua`; `grug_farming/init.lua`; `grug_mobs/verbs.lua` | P1 merged (`tag_carrier.lua` / NPC callback) |
| **D** Documentation | STATUS, README, ROADMAP, BACKLOG, AGENTS/module guide, `spawn_regions.md` (cache, ABM change), `travel-boats-waypoints-plan.md` (piers), `progression.md` / economy numbers if E moved them | docs | end of round; lanes update their own design docs in-lane |

Changes against the report's split, with reasons:

- **#11 goes into P2** (the report parked it pending a ruling; the ruling is
  made). *Why:* it is the same `mobs/api.lua` spawn code and the same probe.
- **The eye-height bug goes into P2**, **the Dawnmere duplication into C.**
  *Why:* the first sits in `general_attack`, which P2 edits anyway; the
  second needs a reproduction attempt in the start-NPC code, which no
  performance lane touches.
- **#4 give-up rule, concrete default:** after **3 failed searches** in a
  row against a target whose node has not changed, the mob drops the target
  and returns home (leash path); a target that moves resets the count. *Why:*
  three back-off steps cover about 7 s of trying, long enough for a player
  stepping round a corner; the user can tune the number in the GUI test.

## 3. Island landings (lane L)

Four landings, all in `simple_map.lua:226-231`: Wyrmglass south/north
(−2890, ∓125), Stormscale south (2890, −125) and north (2920, 125). Today
they are mostly a one-node shore at y 1 with cliffs 40–130 nodes high about
five nodes inland (final check 2026-10-02).

Default shape (first version by feel; the user adjusts after looking):

- **Beach:** a sand crescent about 24 nodes wide along the shore and 10–12
  nodes deep, rising from y 1 to about y 3, blended into the terrain behind
  it; where a cliff stands behind it, a walkable ramp or a cut path of at
  least 2 nodes width leads up to the island surface.
- **Pier:** plain wood planks, 2 nodes wide, about 10 nodes out from the
  beach over water, deck at y 2 (one node above the water), fence posts
  every 3 nodes on the sides, standing on posts down to the floor. The
  island's own wood type if the zone has one, else default planks.
- Boat water of nine nodes depth stays around the pier head (boats.md);
  the channel self-check and the boat-path parity check must still pass.
- No waystone, no shipwright, no NPC at the landings (travel plan unchanged
  otherwise).

Verification: offline zone-field and terrain checks on five seeds, then one
engine run (≤ ~5 min) over the four landings on two seeds: a player can
walk from the pier head to the island surface without jumping more than one
node.

## 4. Waves

**Wave 1 — five lanes, now:** P1, P3, L, C, E.
*Why:* they share no files (C touches the quest loader and validator, P1
the quest state, NPC tags and HUD); the two lanes that need clean before/after
engine comparisons (P1, P3) run first while the host is otherwise quiet.

**Wave 2 — after P1 and E are merged:** P2, P4.
*Why:* P4 shares `tag_carrier.lua` with P1's NPC callback; P2 edits
`grug_mobs` next to E's loot data; and spreading the engine A/B runs over
two waves keeps the timing comparisons readable.

**Wave 3 — integration:** one fresh-world engine check, D, sync, the
user's GUI test.

Engine A/B runs (P1–P4) go through a shared two-slot semaphore like the
review's `engine_run.sh`; each lane re-runs **its own** probe from the
review (`perf/helpers/A–D`, archived in
`~/projects/grudgelands-orchestration/r29/perf-evidence/`) before and after
its change, on the same seed and area.

## 5. Rules for every lane

- AGENTS.md; `tools/check_lua.sh` on every changed Lua file; LuaJIT only.
- Headless only through `LC_ALL=C tools/luanti_headless.sh` under
  `chrt --idle 0`, own run root, kill only your own run, `pgrep` clean
  afterwards; never the user's Luanti folder.
- Mapgen budget (L, P3): a few engine runs of at most about 5 minutes over a
  chosen region; the final check about 15 minutes; never a full world.
- Fresh-server mode: no migrations, no compatibility code (legacy quest
  fields go completely; no fallback for an old cache format beyond
  "rebuild").
- **Numbers are comparisons, never targets.** A lane reports before/after
  for its own probe. A change that makes the code much more complex for a
  small gain, or any behaviour the player would notice beyond the rulings,
  goes back to the coordinator.
- Behaviour must stay the same except where a ruling changes it (#3 arrow
  rate, #4 give-up, #11 spawn ABMs, piers, prices). P2 compares spawn
  counts per zone before/after #11 on one seed.
- `mobs/api.lua` changes carry GRUG PATCH markers and a VENDOR.md entry.
- Agents never push; the coordinator merges after review, the user pushes.

## 6. Verification

Offline per lane: the report's offline checks (P1 cache fixtures, P3
portable round-trip test on seeds 12345 and 42 incl. corruption cases and
the input-coverage test, P4 crafting fixture with the full recipe set and
equal results to the linear scan), quest validators and `quest_targets.py`
on six seeds (C), `income.py --check` (E).

Final integration (~15 min, fresh world): cold boot stores the region-map
cache, warm boot hits it (boot time and heap logged as a comparison with
the review's 15.6–16.0 s / ~170 MiB); the four landings; spawn counts in
one start zone and one underground area against the review's run; clean
log (no craft warnings).

User (GUI, fresh world) — checklist written at the end of the round,
expected items: Map tab arrow every 2 s feels fine; quest markers and NPC
tags still right after accepting/finishing quests; mobs give up a player in
a closed house or on a pillar and walk home; surface mobs still appear as
before, cave/ocean/rift mobs too; shift-click crafting of a stack; island
landing by boat, pier and beach; new mount prices; second start is faster.

## 7. User decisions (2026-10-02)

1. **Wave 1 go** with P1, P3, L, C, E.
2. **#4 give-up after 3 failed searches** against an unmoved target, as
   proposed.
3. **Pier and beach as in §3** as the first version.

## Completion (2026-10-02)

Every lane below is merged on local main (last lane P2, `b64709d7`); each
was independently reviewed by Opus, and the coordinator ran the
`tools/r2*_*` and `tools/r30_*` fixtures (LuaJIT),
`tools/check_fresh_server.py` and a headless boot after every merge. Not
pushed. The final fresh-world engine check (§6) runs at integration
(worktree `r30-final`); its result goes into [STATUS](../STATUS.md).
Next: synchronization, then the user's GUI test on a fresh world (checklist
below).

### Shipped, by lane

Numbers are each lane's own probe before and after, same seed and area
(comparisons, never targets; 40 fake-player stand-ins where players count).

- **E** (`17a6c398`): band-4 and band-5 loot medians moved toward the target
  axis by loot rows only (four tier-matched T4 drops in band 4, Stone Core out
  of band 5): band 4 39.0 → 43.6c (target 48c), band 5 147.6 → 119.5c
  (target 120c). Prices recomputed by `income.py`: Expert Riding 1g63s →
  1g37s, respec 31–40 1s90c → 2s, 41–50 7s → 6s; every other mount, boat
  and respec price unchanged
  ([economy plan, band smoothing](economy-vendor-plan.md#band-smoothing-round-30-2026-10-02)).
- **P1** (`b03e839e`): a decoded quest-state cache per player and
  `Q.marker_states` (one decode for all 78 givers, memoized for a second);
  the quest tracker HUD skips unchanged journals and polls in five slots;
  the Map tab compares a cheap signature at most every 2 s and sends only on
  a change, with shared marker styles; the minimap hoists its window and
  frame work to 0.5 s. Minimap 55.8 → 9.3 ms/s, quest HUD 17.1 → 6.5 ms/s,
  Map tab 17.2 → 0.93 ms/s and 179 → 33 KB/s, quest-state
  deserializations 874 → 0 per second.
- **P1 follow-up** (`dc614162`): **Return home** moved from the Map tab to
  the Character page's Stats tab (live m:ss countdown, re-sent once a second
  only while the text changes); the dead faction/race gates and the kill
  zone filter left `state.lua`.
- **P1b** (`e92f4c27`): quest markers and NPC tags follow held objective
  items (the tracker's 0.5 s poll) and level changes at once through
  `grug_quests.markers_changed`: after an item pickup the NPC tag changes
  within 1.5 s (0.75 s on average), after a level-up within 1 s.
- **C** (`182dbb71`): the legacy quest fields are gone (fixed `xp`,
  `faction`/`race` gates, `mobs`, `zone`; any unknown field stops the load,
  `E-unknown-key`; `validate.py --legacy` removed); the stale fixtures
  repaired (`tools/r24_density_xp/fixture.lua` deleted, its palette budget
  applies to no zone); the riding-tier purchase fixture (`tools/r29_b`
  section H); the 18 "No craft recipe known for output" boot warnings were
  no-op `clear_craft` calls and are removed. **Dawnmere duplication found and
  fixed:** `core.add_entity` stores the staticdata of that moment, so a start
  NPC whose block was saved and unloaded before its next deactivation came
  back twice; `start_npcs.lua` now passes `_grug_unplaced` in the staticdata
  (module guide). Review fix: `bw_front_ashveil_05` points only at the Bog
  Witch (0 missing targets on six seeds).
- **L** (`8d1105cf`): a sand beach (crescent 24 × 11, y 1 → 3) and a
  2-wide wooden pier (10 out, deck y 2, the island zone's wood) at all four
  dragon-island landings ([boats.md §7.1](../design/boats.md#71-island-landings-pier-and-beach));
  five seeds offline and the engine probe on seeds 42 and 20261002 pass. No
  path up the island (ruling below).
- **P3** (`e979c8ce`): the region maps' compact form and world-folder file
  cache `grug_region_maps.txt` (`spawn_regions_cache.lua`), the Map tab's
  zone grid in `grug_map_zone_grid.txt`, road-segment buckets in the region
  builder, full collections after the heavy boot phases and a boot heap
  log ([spawn_regions.md, Cache and memory](../design/spawn_regions.md#cache-and-memory)).
  Warm boot 15.3 → 7.2 s, the region hook 8.78 s → 3.2 ms on a hit, Lua heap
  127.6 → 70.5 MiB, peak memory of a first start 2.12 → 1.76 GB.
- **P4** (`fd0f0338`): a crafting lookup index (200 → 5 µs per lookup in the
  engine; 212k grids equal to the former scan), the crosshair state every
  0.15 s with unchanged skill rays repeated for up to 0.25 s (20 → 14 ms/s
  moving, 14 → 7.7 ms/s standing), the Target Frame reusing the crosshair's
  aim (1.3 → 0.44 ms/s), the tag-carrier pass spread over eight slots with
  callbacks only for observed carriers, the flight-border sweep 268 → 43 µs,
  idle crop-soil checks once a minute (4× fewer timers) and a crop LBM that
  skips standing plants, per-player tables cleared on leave.
- **P2** (`b64709d7`): A* gets about 3 ms per server step, a no-path result
  waits 1, 2, 4 s before the same search, the close-cover search looks within
  8 nodes, and a mob gives up an unreachable target after three failed
  searches ([combat_stats.md](../design/combat_stats.md)); the patrol nudge
  shares the budget; a collision-box field replaces per-step
  `get_properties()`; cached privilege checks; `mobs_can_hear = false`; the
  `general_attack` eye-height bug fixed (a copy at position + 1); 56 of 88
  spawn rows retired and the rest merged into three ABMs
  (`spawn_abms.lua`, [biomes_mobs.md §4](../design/biomes_mobs.md#4-spawn-parameter-table)).
  40 blocked chasers 6.83 → 0.68 ms per step (A* 4.69 → 0.007 ms per
  step), garbage 7.75 → 4.93 MiB/s (150 idle mobs 7.82 → 4.49), ABMs 95 →
  10, blocks scanned for ABMs 404 → 104 per second.
- **D**: this section, the status files, the module guide and AGENTS.

### Rulings made during the round

- **Map tab every 2 s** (plan §1) stays. A home countdown made it resend
  every 2 s, so **Return home moved to the Character page** (user,
  2026-10-02: the live countdown is cheap in that small form); the Map tab
  keeps the home marker.
- **Quest markers** follow objective-item counts and level changes at once
  (coordinator, P1b option (a)); a repeatable's cooldown ending still shows
  with the next memo or 5 s refresh.
- **Give-up (P2):** after 3 failed searches in a row against an unmoved
  target, as approved. In the review round: **dragons and whelps never give
  up** and only wait (a reset would restart the boss attempt with a full
  heal); **kings only drop the target** (no heal, no royal reset;
  coordinator); a **visible player** (across a fence or water) is never
  searched for and never given up; a target in a **walkable node** (slab,
  lower stair, snow) is searched for from the node above, and a search with
  walkable ends never counts.
- **One spawn row per merged trigger:** the merged ABMs pick at most one row
  per node and trigger, so species do not clump and every row keeps its own
  rate (review fix).
- **Island landings:** pier and beach as §3, the pier head in the 2–4 nodes
  of shore water the terrain gives (accepted). The trail attempt (road
  router from the beach to the nearest island POI) was stopped: the router
  cannot climb the 145–415 node island flanks. **Pier and beach only; the
  dragon islands stay untamed, no mapgen paths or roads by design** (user,
  2026-10-02, `boats.md` §7.1).
- **Band-5 smoothing:** as above; the band-3 outliers (Crocodile Tooth,
  Shiny Scale) stay, no T3 replacement exists.
- **Boot collections kept:** the full GCs cost about 0.25–0.5 s of boot for
  the lower peak memory.
- **Tag carriers:** eight slots with a position snapshot per slot
  (coordinator: keep).

### Open items

In the [BACKLOG](../../BACKLOG.md#round-30-carry-overs): the grug_mapgen
warm-load proposal (#22: store `prepared_handover()` in the world-layout
cache, warm load 4.6 → about 1.2 s, size M, risk medium), the cold-build
heap (about 150 MiB from kept query caches), the cache keys that omit the
mapgen data files and the engine version, the zone-grid encode assert, held
objective counts uncapped, a turn-in reward error that skips `changed()`,
band 6 at 0.80 of its target (Master Riding), the band-3 outliers, the
empty strip on the Map tab where the button was, the dragon arena design
iteration. Not reproduced and left to the GUI test: a player who keeps
re-aggroing a mob from a closed house or other hidden spot gives it a full
heal at each give-up (about every 7 s); P2's one-seed count run showed +55 % spawn attempts in a shallow
cave, judged run noise (the merged dispatcher keeps every row's rate by
construction).

**King give-up behaviour (open question to the user):** kings now only drop
an unreachable target (no heal, no encounter reset); the coordinator
proposed heal-only without the encounter reset, to stop step-wise ranged
kills from a hidden spot.

### Playtest checklist

On a fresh world (Round 30 changes the island landings and the caches):

1. **Map tab:** the own arrow moves about every 2 s while the tab is open;
   zoom, marker and minimap-switch clicks answer at once; note the empty
   strip where the Return home button was.
2. **Quest markers and NPC tags:** right after accepting a quest, after a
   kill that completes an objective, after picking up the last objective
   item (within about 1.5 s) and after a level-up, the givers' symbols on
   the NPCs, the minimap and the Map tab change.
3. **Return home** on the Character page (Stats tab), with a home set at
   an innkeeper: destination and an
   m:ss countdown that ticks each second, "Preparing arrival" during the
   return, "Ready" afterwards; also in a 1280 × 720 window.
4. **Giving up:**
   - Hide from a chasing mob in a closed house or a walled-in hole: after
     about 7 s the mob stops, walks home and is healed.
   - Stand where the mob can see you but cannot reach you (across a fence or
     water): it keeps you as its target and does not walk home.
   - Stand on a slab, a stair or snow: the mob reaches you and attacks.
   - Re-aggro a mob from a hidden spot: it gives up again and heals each
     time (P2 note).
   - The island dragons never give up.
5. **Spawns:** surface, cave, ocean (Kraken, Reed Angelfish) and rift mobs
   still appear as before; no clumps of one species on one spot.
6. **Crafting:** a shift-click craft of a full stack works and does not
   stall the server.
7. **Crosshair:** the red tint appears about 0.3 s after a mob walks into a
   still crosshair; the Target Frame follows the aim.
8. **Flight warnings** near the ocean and the borders as before; **crops**
   still grow, dry out and recover.
9. **Island landings:** reach each dragon island by boat at both landings,
   step onto the pier and the beach; the island itself is untamed (a climb).
10. **Prices:** Expert Riding 1g37s; respec 31–40 2s, 41–50 6s.
11. **Starts:** the second start of the same world is faster (about 7 s
    instead of about 16 s); the log names the region maps read from the
    world folder.
12. **Dawnmere:** each start-town NPC stands there once, also after a
    restart.
