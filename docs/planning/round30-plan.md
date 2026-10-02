# Round 30 — Performance and clean-up: round plan

Coordinator: Claude (Opus 5.5), 2026-10-02. Status: **approved by the user
2026-10-02** (wave 1 go; §7 defaults accepted).

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
