# Grudgelands performance review — Round 29 (read-only)

Code reviewed: main `a429db63` (detached worktree `.claude/worktrees/perf-review`). Date: 2026-10-02.
Nothing in any repository or worktree was modified. All evidence lives under
`/tmp/claude-1000/-home-jan-projects-grudgelands/3c280449-55da-4eae-a775-90e471579a86/scratchpad/r29/perf/`
(written `perf/` below): `orch/` (orchestrator baseline boots), `helpers/A` (mobs, pathfinding, spawning),
`helpers/B` (combat, UI), `helpers/C` (globalstep/ABM/LBM inventory, memory, other mods), `helpers/D` (regions,
quests, travel, boot, cache design). `perf/locks/ledger.txt` lists all 18 engine runs; each one ran through a
shared two-slot semaphore (`perf/engine_run.sh`) under `chrt --idle 0`.

**How things were measured**
- **Engine:** headless Luanti 5.17 server, LuaJIT, seeds 12345 and 42, forceloaded small areas only. Probe mods
  wrapped every globalstep, ABM/LBM, node timer and entity `on_step` with `core.get_us_time`.
- **Players:** headless servers have none. Player-scaled code was driven by fake player ObjectRef stand-ins (20
  and 40 in helper B's runs, up to 100 stubs in helper A's tag-pass benchmark), and was otherwise argued from
  complexity.
- **Offline:** LuaJIT benchmarks of the pure modules, using `tools/r28_zone_atlas/world.lua` for the region
  builder.
- **Host:** the user's workstation, shared with other agents' servers. Timings are comparisons, not targets.

**Baseline**
- **Idle server, no players** (336 forceloaded blocks, 30 objects): all Lua callbacks together cost 2.8–3.0 ms/s.
  The engine `AsyncRunStep` takes 0.5–0.8 ms per step. No step went over 20 ms.
- **Boot:** a cold boot of a fresh world takes 40.9–41.8 s to "listening". A warm boot (a later start of the
  same world) takes 15.6–16.0 s.
- **Live Lua heap after a full GC:** about 170 MiB.

---

## 1. Top 10 findings by player impact

| # | Finding | Class | Severity | Fix size |
|---|---|---|---|---|
| 1 | Quest state is deserialized once per quest giver (78 givers) for the minimap, the Map tab and NPC tags. At 40 players: 872 deserializations/s; minimap globalstep 42 ms/s with steps up to 72 ms | per-tick + spikes | high | S/M |
| 2 | Region maps are rebuilt on every boot: 9.1–9.6 s, about 58 % of a warm boot. A persistent cache loads them in about 2 ms (§3) | boot | high (user request) | M |
| 3 | The Map tab rebuilds a 75 KB formspec every 0.5 s and resends it whenever the player arrow moves: about 150 KB/s and 10–12 ms/s of CPU per viewer | per-tick, network | high with several viewers | M |
| 4 | Mobs chasing an unreachable target repeat a full no-path A* (2–3 ms each) forever. 40 such chasers pin about 7–8 ms per step, max 23–38 ms | per-tick + bursts | medium-high | M |
| 5 | The quest tracker HUD polls every player in the same step every 0.5 s: 16 ms/s at 40 players, single steps up to 53 ms | per-tick spike | medium-high | S |
| 6 | Per-step `get_properties()` calls in mob code drive about 7.8 MiB/s of garbage. A per-step box cache cut p99 from 18.9 to 10.5 ms and max from 37.8 to 11.9 ms | per-tick, GC | medium | M |
| 7 | Grid crafting finds its recipe by a linear scan of all 147 recipes, twice per crafted item: 83–296 µs per call, so a shift-click craft of 25–99 items stalls a step for 5–60 ms | stall | medium | S |
| 8 | The crosshair pass runs every server step with 1–2 raycasts per player: 12 ms/s at 40 players, about 25–35 ms/s if mages hold a targeted skill | per-tick | medium | M |
| 9 | Memory: the region maps keep 22 MiB of full tables resident, plus about 28 MiB of warmed query caches. Peak memory (VmHWM) during boot is 1.8–2.0 GB, against a live heap of 124–170 MiB | memory | medium | S–M |
| 10 | The tag-carrier pass is O(carriers × players) and runs in one step each second. Measured 1.0 ms at 150 carriers and 100 players; about 4–5 ms projected at the 600-mob cap | per-second spike | low-medium | S |

Next in line, detailed in §2: 88 mob spawn ABMs triple the engine's ABM block scans (#11), minimap glide
(#12), and smaller items #13–#22.

---

## 2. Findings in detail

Paths are relative to the worktree root. "Offline" means the fix can be verified without the engine.

### #1 Quest state deserialized per quest giver (minimap, Map tab, NPC tags)

**Where**
- `mods/PLAYER/grug_quests/state.lua:13-18`: `load()` runs `core.deserialize(meta)` on every call.
- `state.lua:145`: `Q.npc_quests` calls `load()`.
- `npc.lua:16-22`: `Q.marker_state` calls `npc_quests`.
- Callers that invoke `marker_state` once per giver:
  - `mods/PLAYER/grug_map/providers.lua:88-98`: the "quest" marker provider. It runs on every minimap
    static refresh (every 5 s per player, and after every quest change) and on every Map tab build.
  - `grug_quests/npc.lua:107-131`: the tag-visibility callback, once per quest NPC per observer per second.

**What happens:** one minimap or Map refresh deserializes the whole quest state 78 times (once per giver), and
also runs `offerable` and `progress` for each giver. Every quest-mob kill fires `changed()`, which resets the
minimap's static set and triggers another full rebuild. The orchestrator confirmed the call chain in the code.

**Measured** (helper B; stand-ins with a late-game log of 10 active and 230 completed quests, 7 KB):
- `core.deserialize`: 26–28 µs per call.
- `marker_state`: 27–44 µs per giver.
- All 78 givers: 2.1–3.0 ms per player.
- 40 stand-ins over 30 s: 26,246 deserializations, 1.10 s of Lua, about 3.7 % of the main thread from this
  alone.
  - Minimap globalstep: 42 ms/s, worst single step 72 ms.
- NPC tag visibility: 27–44 µs per NPC per observer. About 10 quest NPCs × 30 players in a capital comes to
  about 13 ms in one step.
- Fresh characters are about 10× cheaper. The cost grows as players progress, because `completed` is never
  pruned.

**Impact:** per-tick load plus spikes. **Severity: high.**

**Fix (S/M, low-medium risk, offline-checkable)**
1. Cache the decoded state per player, keyed by the raw meta string.
   - Read-only callers get the cached table: `npc_quests`, `status`, `journal`, `marker_state`.
   - Mutating paths copy it, and `save()` refreshes the cache.
   - Clear the cache on leave.
2. Add `Q.marker_states(player)`: one load and one `holdings()` call for all givers. Use it from
   `providers.lua` and the tag callback, memoized per player per second.

### #2 Region maps rebuilt on every boot

**Where**
- `mods/ENTITIES/grug_mobs/spawn_regions.lua:1045-1084`: the `on_mods_loaded` hook builds every recipe zone.
- `:289-321`: `SR.map`.
- `spawn_regions_core.lua:772-1787`: `M.build`.

**What happens:** 38 zones are built from the analytic world on every boot. That takes about 624k zone-owner
and water samples and 398k height, biome and protection samples.

**Measured**
- Hook time on the engine: 9.35 s cold and 9.13 s warm (seed 12345); 9.61 s cold and 9.42 s warm (seed 42).
  The orchestrator's own boots logged 9.5 s cold and 8.5 s warm (`perf/orch/baseline_*_seed12345.log`).
- Warm boot to "listening" is 15.6–16.0 s, so the region maps are about 58 % of it.
- Single zones take 73–532 ms.
- Where the time goes (`helpers/D/instr_12345.txt`, `profF0_12345.txt`):

  | Part | Share of build | Calls / cost |
  |---|---|---|
  | `terrain_height_at` | 53 % | 398k calls, 23.5 µs each |
  | `water_class_at` | 14 % | — |
  | `id_at` | 9 % | — |
  | `column_values_at` | 7 % | — |
  | builder's own code | about 17 % | `road_dist` alone is 6 % |

  About 83 % of the time is world sampling, so tuning the algorithm can win at most 10–15 %.
- A single build pass allocates about 1 GiB of garbage.

**Impact:** boot time; also peak memory, see #9. **Severity: high**, because the user asked for this.

**Fix:** the persistent cache in §3 (M, low-medium risk, offline-checkable). Loading takes 1.9–2.3 ms instead
of about 9.4 s, so a warm boot drops to about 6.7 s.

### #3 Map tab rebuilds and resends a 75 KB formspec

**Where:** `mods/PLAYER/grug_map/page.lua:285-310`.
- The globalstep runs every 0.5 s for each player with the Map tab open.
- `make_form` builds the whole form, including about 230 markers, each with `style[]`, `image_button` and a
  tooltip, plus region labels.
- The signature is computed from the finished form string.

**Measured** (helper B, one viewer walking for 30 s):
- Formspec size: 75,453 bytes.
- `sfinv.get_formspec` on this page: 3.7–4.6 ms.
- Sends: 60 in 30 s, 4.53 MB in total, about 150 KB/s for that one player.
  - The player arrow, party arrows and the home countdown change the signature on almost every tick.
- CPU: the map globalstep costs 10–11.7 ms/s for that one viewer; max step 29–39 ms.
- While the player stands still, only 1 send goes out, but CPU stays at 10.7 ms/s, because the form is rebuilt
  just to compute the signature.

**Impact:** per-tick CPU and network. **Severity: high** if several players keep the map open while travelling:
5 viewers cost about 50 ms/s and 750 KB/s.

**Fix (M, low-medium risk, partly offline)**
- Build the form only when a cheap signature changes. The signature covers quantized arrow and party pixel
  positions, heading frames, a quest/marker version (from #1), zoom, scroll, selection and the home status.
- Throttle arrow-only updates to about 1 s, or to moves of at least half a marker width. This is a look &
  feel call; check it with Jan.
- Share one `style[]` across markers instead of one per marker.

### #4 Endless no-path A* for unreachable targets

**Where**
- `mods/ENTITIES/mobs/api.lua:1756-1898`: `smart_mobs`; `core.find_path` at `:1840` with searchdistance 24
  (`minetest.conf:99`).
- `api.lua:2466-2481`: the close-obstacle branch in `do_states`.
- `mods/ENTITIES/mobs/grug_obstacle.lua:7`: the budget is a count, `path_budget_per_step = 2`, not a time.
- `mods/ENTITIES/grug_mobs/aggro.lua:143` and `:355-420`: a pursuit never ends against a stationary target.

**What happens:** a ground-melee chaser whose target sits in a closed house, on a pillar, in a boat or behind a
fence retries a full A* about every 1.7 s, forever. A no-path search explores the whole search box (start and
end grown by 24).

**Measured** (helper A, arena plus natural land, seed 12345):
- No-path `find_path`: 1.95 ms (distance 8), 2.31 ms (16), 3.01 ms (30); 2.6–2.9 ms on natural land.
- `find_path` when a path exists: 14–211 µs.

| Blocked mobs | Lua per step | Notes |
|---|---|---|
| 10 zombies | p99 4.8 ms, max 5.1 ms | — |
| 40 chasers | mean 7.0–8.0 ms (idle mobs: about 1 ms), p99 18–19 ms, max 23–38 ms | budget saturated at 2 A* per step, every step; maxima include GC |

**Impact:** per-tick load with bursts. Ordinary player behaviour can cause it. **Severity: medium-high.**

**Fix (M, low-medium risk)**
- (a) Negative path cache per mob: after a no-path result, back off 1, 2, 4, 8 s (cap about 10 s) while the
  mob's and the target's nodes are unchanged.
- (b) Use searchdistance 6–8 in the close-obstacle branch, which makes the search box about 10× smaller.
- (c) Make the budget time-based, about 3 ms of A* per step.
- (d) Whether to give up pursuit after N failed searches against a static target is a gameplay rule. **Escalate
  to Jan.**

**Offline:** the back-off logic, in pure Lua. The cost gain needs an engine A/B run; the helper A probe already
supports it.

### #5 Quest tracker HUD polls all players in one step

**Where:** `mods/PLAYER/grug_quests/hud.lua:116-124` and `:139-144` (the 0.5 s poll); `:138` (also on every
inventory action). `refresh` calls `Q.journal`, which deserializes the state, scans every inventory list and
runs `progress` with `table.copy` per quest.

**Measured**
- `journal`: 57–100 µs in micro-benchmarks, 172–213 µs inside the poll under GC.
- 40 stand-ins: 16.3 ms/s, single steps up to 53 ms.
- 20 stand-ins: 10 ms/s, max 35 ms.
- Inventory-action callback: 0.11–1.26 ms per action.

**Impact:** per-tick plus spikes, linear in players. **Severity: medium-high.**

**Fix (S, low risk, offline-checkable)**
- Use #1's cache.
- Spread players over slots, as `grug_core/atmosphere_zones.lua:537` does.
- Skip the journal when a cheap fingerprint is unchanged: the state's raw string plus the counts of objective
  items only.

### #6 `get_properties()` in per-step mob code: allocation and GC pressure

**Where**
- `mods/ENTITIES/mobs/grug_obstacle.lua:185,187`: `target_visible`, on the mob and on the target, every step.
- `api.lua`: `:1050` (`is_at_cliff`, 4×/s), `:3962` (`get_nodes`, 4×/s), `:1121` (`do_env_damage`),
  `:1815/:1827`, `:2829`, `:2984`, `:326`.
- `grug_mobs/separation.lua:265-287`, `flight.lua:26`, `grug_core/tag_carrier.lua:171`.

**What happens:** each `get_properties()` call builds the whole property table.

**Measured** (helper A)
- One call: 4.2 µs and 2.8 KB allocated.
- Allocation: 7.75 MiB/s with 150 idle mobs, 7.85 MiB/s with 40 chasers. Projected to the 600-mob cap: about
  30 MiB/s.
- GC: there is no runtime `collectgarbage("collect")` anywhere in mods/, so collection is incremental. The
  incremental cycles showed up as runs of about 7 consecutive steps with 10–30 ms extra each. A forced full
  collection of the 170 MiB heap takes 59–128 ms, depending on load (helpers A and C).
- A/B test with a per-step property cache (40 chasers):

  | | Without cache | With cache |
  |---|---|---|
  | Allocation | 7.85 MiB/s | 4.83 MiB/s |
  | Step mean | 8.0 ms | 6.6 ms |
  | p99 | 18.9 ms | 10.5 ms |
  | Max | 37.8 ms | 11.9 ms |

**Impact:** per-tick load plus GC bursts. **Severity: medium.**

**Fix (M, low-medium risk, partly offline)**
- Keep the collision box in a field (`self._grug_cbox`), updated wherever `collisionbox` is set
  (`mob_activate`, `scale_mob`, `set_tier`/`apply_tier_visuals`).
- Read that field at all of the call sites above.
- For a player target, cache its box per step.

Related, idle cost per mob (A4): about 8.5–11 µs per mob per step, roughly 100 µs/s per mob. That is 1.34 ms
per step at 142 mobs, about 5.5 ms at the 600-mob cap. Two fixes:
- The box cache roughly halves `get_nodes` and `is_at_cliff`.
- Skip `reassert_max` in the `grug_mobs` `do_custom` wrapper (`init.lua:805-898`) after the first tick of each
  activation.

### #7 Grid crafting: linear recipe scan, twice per crafted item

**Where:** `mods/PLAYER/grug_jobs/registry.lua:746` (`recipe_for_craft`) and `:229` (`shaped_inputs_match`),
called from `stations.lua:76-114` (craft predict and on_craft).

**What happens**
- Each call scans all 147 jobs recipes.
- For each candidate it re-trims the 3×3 grid: 9 `get_name` calls plus new tables.
- The engine calls predict and on_craft once per crafted item, so a shift-click "craft all" of N items makes
  2N calls.

**Measured** (helper C, in-engine, 500 calls each): 83–296 µs per call on the grid station; 0.6 µs on other
stations. One shift-click of 25–99 items therefore stalls a step for 5–60 ms.

**Impact:** a stall that any player can repeat at will. **Severity: medium.**

**Fix (S, low risk, offline with a LuaJIT fixture)**
- Normalise and trim the grid once per call.
- Precompute the trimmed recipe matrices at registration.
- Index recipes by trimmed shape plus the first non-empty item or group.

### #8 Crosshair raycasts every server step

**Where**
- `mods/PLAYER/grug_abilities/init.lua:2350-2362`: the 0.05 s threshold means it runs every step. It calls
  `input.step` (an `xpcall` with a new closure each time), the ready reticle and `crosshair.update` (the hand
  ray from `input.lua:57`, plus `combat_ray` up to range 40 while a targeted skill is selected).
- `mods/ENTITIES/grug_mobs/target_frame.lua:65-98`: its own 20-node ray every 0.5 s.

**Measured** (helper B)
- Hand ray only: 33 µs per player per step. That is 7.2 ms/s at 20 players and 11.9 ms/s at 40 (441 raycasts/s
  plus 73/s from the target frame).
- `combat_ray`: 20–47 µs. A player holding a targeted skill costs about 55–80 µs per step, about 25–35 ms/s at
  40 players.
- Steady load, no spikes; max step 5.6 ms.

**Impact:** per-tick. **Severity: medium.**

**Fix (M, low risk, verify in engine)**
- Throttle the crosshair state to 0.1–0.15 s.
- Skip the skill ray when the eye position and look direction are unchanged and the last result had no object.
- Let the target frame reuse the crosshair's combat ray.

### #9 Region-map memory and boot peak memory

**Where:** `spawn_regions_core.lua:857-1032` (per-cell tables of about 25 fields), `:1418-1650` (regions keep
their `cells` lists), `:1771` (`region_at` closure); built maps are kept at `spawn_regions.lua:309`.

**Measured** (helper D)
- Region maps: 22.3 MiB resident, about 926 B per land cell.
- The build also leaves about 28 MiB of bounded world-query caches warm.
- A compact form (a byte-string grid per zone plus regions, camps and leaders) takes 215–257 KiB for all 38
  zones, with 0 mismatches against the full maps (§3).

  | | Live heap |
  |---|---|
  | Total after full GC | about 170 MiB |
  | `grug_mapgen` (main environment) | about 75 MiB |
  | `grug_mobs` | about 27 MiB |
  | Bytecode and C-held data | about 58 MiB |

- Peak memory during boot: VmHWM 1.83–2.02 GB, against VmRSS 1.06–1.24 GB at "listening". The Lua heap was
  seen uncollected at 1180 MiB halfway through loading; live data after a full GC is 124–170 MiB. The region
  build churns about 1 GiB. Emerge-thread states are included in VmHWM and were not separated.

**Impact:** memory, a 2 GB host could fail at start. A larger live heap also costs more per GC cycle (#6).
**Severity: medium.**

**Fix**
- Keep only the compact form after a build, even on a cache miss (S–M, low risk, offline). Tools that read
  `#map.order` or `#r.cells` must use a separate full-build call:
  - `tools/r28_s1/grug_probe_r28_s1/init.lua:207`
  - `tools/r28_zone_atlas/grug_probe_r28_zone_atlas/init.lua:134`
  - `tools/r28_s1/portable_test.lua:649`
- Try `collectgarbage("collect")` after each heavy load phase (mapgen construction, map render, region build)
  and re-measure VmHWM (S, needs an engine run).
- Log the heap after a full GC at boot as a regression guard.

### #10 Tag-carrier pass is O(carriers × players) in one step per second

**Where:** `mods/CORE/grug_core/tag_carrier.lua:298-347` (`manage_carriers`, globalstep at `:341`).
`grug_mobs/init.lua:3-14` gives every mob a carrier, so the object count doubles. The per-carrier visibility
callback in `grug_quests/npc.lua:107` allocates a `{}` for every non-NPC carrier.

**Measured**
- Helper A: 60 carriers 0.07–0.30 ms per pass (0–50 players); 150 carriers 0.13–1.01 ms (0–100 players). The
  first pass after players move takes up to 1.8 ms.
- Helper C: 69 µs per pass for 13 carriers with no players.
- Projection: about 4–5 ms in a single step every second at 600 carriers and 100 players.

**Impact:** a spike once per second. **Severity: low-medium.**

**Fix (S, low risk, offline via `grug_core.refresh_tag_player_snapshot` / `manage_tag_carriers`)**
- Spread the pass over 4–8 slots.
- Call visibility callbacks only when the observer set changes.
- Skip the quest callback for non-NPC parents.

### #11 88 mob spawn ABMs triple the engine's ABM block scanning

**Where:** `mods/ENTITIES/mobs/api.lua:4658`, one ABM per spawn row; the full list is in
`helpers/C/run1_inventory.txt`. Most target `default:stone|group:grug_stratum` or common surface nodes with an
air neighbour, interval 20–60 s. About 25 of them sit on stone alone.

**Measured** (helper C, A/B test over 336 forceloaded blocks):

| | Spawn ABMs kept | Spawn ABMs removed |
|---|---|---|
| Blocks scanned per cycle | 148–194 | 2–54 |
| Engine "modify in blocks" time per cycle | 1.6–2.8 ms/s | 0.2–0.67 ms/s |

The Lua side of these ABMs is negligible (≤ 0.04 ms/s in total). The cost is about 1.2–1.7 ms/s of engine time
per spread-out player.

**Impact:** per-tick. **Severity: low-medium.**

**Fix (M)**
- Either retire the ABM spawns where the region spawner is authoritative, or merge them into a few ABMs (one
  per node set) with a Lua dispatcher.
- This changes spawn semantics. **Ruling needed from Jan.** It can only be checked with an engine A/B run.

### #12 Minimap glide cost per player-step

**Where:** `mods/PLAYER/grug_map/minimap.lua:240-370` and `:449-464`.

**Measured:** about 45 µs per player-step without slow refreshes (the r27 benchmark said 5–7 µs); about
20 ms/s at 40 players. Traffic is about 14 `hud_change`/s per player, about 470 B/s, with no redundant sends.

**Fix (S, low risk, offline with `tools/r27_minimap/bench_glide.lua`):** hoist per-step work to slow ticks or to
window changes:
- `layout.minimap_box` and `get_player_window_information`
- `location.text_of`
- the `visible` and `party` tables

**Severity:** low-medium.

### #13–#22 Smaller items

| # | Where | What / measured | Fix (size) | Severity |
|---|---|---|---|---|
| 13 | `grug_mobs/patrol.lua:222-238` (`path_nudge`), from `:369-374` | A stuck guard patroller runs a searchdistance-24 A* every second, outside the path budget, and can repeat forever while a player is within 48 nodes. 2–3 ms per search (same figures as #4) | Route it through `claim_path_budget` with #4's back-off (S) | low |
| 14 | `mods/PLAYER/grug_mounts/entity.lua:234` (`warning_state`), from `:486` | The flight-boundary sweep makes 112 `flight_state` calls, each with a `get_meta` faction read: 0.43–0.49 ms per flying player per second | Read the faction once per sweep; cache legality per 16×16 column; or use 8 directions (S) | low |
| 15 | `mods/ITEMS/grug_farming/init.lua:68` (`soil_timer`), `:91` (LBM) | Every field soil node fires a timer every 15 s with `find_node_near` r=3, even without a crop. 1977 nodes in Dawnmere: 0.38–0.44 ms/s per village in range | Arm the timer only when planting, or use 60 s (S) | low |
| 16 | `grug_farming/init.lua:439` LBM (`run_at_every_load`), calling `:180-206` | Tall crops (cane, bamboo, corn) are rewritten on every block load, which marks the block modified (re-save, relight). Not measured; no crops were in the test area | Write only when the geometry differs (S) | low |
| 17 | `api.lua:1918-1925`, `:3371`, `boss_dragons.lua:840` | `check_player_privs` is called per candidate and per hit: 2.7–6 µs isolated, 35 µs average under combat load | Cache per player and invalidate on priv grant/revoke; skip `is_creative` for non-player hitters (S) | low |
| 18 | `api.lua:5344-5435` (mobs_redo "mobs can hear") | Every positional `sound_play` runs `get_objects_inside_radius` (radius 32–160): 13–28 µs. No mob defines `on_sound` | Add `mobs_can_hear = false` to `minetest.conf` (S, no risk) | low |
| 19 | `grug_core/combat.lua:33,53` (`mounted_refusal_notice`, holds an ObjectRef), `grug_mobs/verbs.lua:135` (`poison_gen`), `grug_jobs/stations.lua:1` (`denial_times`) | Per-player tables never cleared on leave. Bounded by the number of unique players. About 50 other player-keyed tables were checked and are cleared correctly | Clear them in `on_leaveplayer` (S) | low |
| 20 | `grug_map/location.lua:103` | Zone-marker placement is recomputed on every boot: 126–210 ms and about 28 MiB of churn | Add it to the §3 cache or the grug_map base key (S) | low |
| 21 | `spawn_regions_core.lua:916-927` (`road_dist`) | Scans every sample against every nearby road segment: 6 % of a build (about 0.6 s, cache miss only) | Bucket the segments spatially (S) | low |
| 22 | `grug_mapgen` load on a layout-cache hit | Building the runtime from the cached D71 texts still takes 4.2–4.4 s of every warm boot, about 6.7 s of the remaining boot once #2 is fixed. Not investigated further; prior perf work covered the writer and planner, not this step | Investigate next (M?) | info |

Also seen:
- `grug_core/starts_preload.lua:164` produced single-step spikes of 5.4–7.5 ms while the "starts" preparation
  was running (boot only, with its 100 ms budget). Fine as designed.

Correctness side observations (not performance; pass them to the next round):
- **Possible NPC duplication.** In helper C's run 3, the Dawnmere box held 53 objects (14 villagers, 4 elders,
  4 guards, 2 vendors) after only 13 logged placements; runs 1, 2 and 4 held 30. Evidence:
  `helpers/C/run3_server.log`, "MEASURE start" line. Not reproduced.
- **`general_attack` eye height.** In `api.lua:2007-2016`, `sp = s` aliases the mob's position and then
  `sp.y = sp.y + 1` runs inside the loop, so the mob's eye height rises with each candidate.
- **JSON round-trip.** `core.write_json` loses empty lists (they come back nil), so it is unfit as a cache
  format.

---

## 3. Persistent region-map cache: design (scope item 8)

### Measurements

Helper D measured these in the engine after boot, over all 38 zones, seeds 12345 and 42, on cold and warm
boots. Payload extraction from the built maps takes 3–4 ms.

| Format | File size | Store | Load (read, sha, decode, rebuild) | Runtime memory | Mismatches |
|---|---|---|---|---|---|
| custom text + binary grid, raw | 111,898 B (seed 42: 114,061 B) | about 1.4 ms | **1.9–2.3 ms** | 247–257 KiB | 0 |
| custom + zstd (`core.compress`) | 34,409 B | about 1.7 ms | 2.4–2.5 ms | about 248 KiB | — |
| custom + deflate | 32,069 B | about 2.5 ms | 1.9–2.2 ms | about 248 KiB | — |
| `core.serialize`, string grid | about 163 KB | about 2.4 ms | 1.8–2.1 ms | about 215 KiB | 0; output not byte-stable across boots (163,236 vs 163,037 B) |
| `core.write_json` | — | — | fails to round-trip (empty lists come back nil) | — | — |
| **fresh build (today)** | — | — | **9,126–9,606 ms** | 22.3 MiB plus about 28 MiB of caches | — |

Notes:
- **How mismatches were checked:** `region_at` (id, level, kind) at 7 points per land cell plus a one-cell ring
  around each zone, and `describe` for every leader, camp and kind in all three modes.
- **Determinism:** the encoding seed 42 stored on its cold boot had the same sha256 as a fresh encoding on the
  warm boot. Maps are deterministic across boots and across D71 layout-cache hits and misses.
- **Hashing cost:** hashing the grug_mobs inputs (41 files) takes 0.6 ms; the full mapgen source digest takes
  3.0–4.6 ms.
- **Expected effect:** a warm boot drops from about 15.8–16.0 s to about 6.7 s. The first start of a world
  still builds once, next to the 20.5 s layout build and the 10.1–10.5 s map-base render that already happen
  then.
- **Recommended format:** the custom text format with a binary grid, uncompressed. It is the fastest, it is
  byte-stable so digests work, and 112 KB is negligible. Deflate is an option if the file size matters.

### Model to follow

The D71 layout cache:
- `mods/MAPGEN/grug_mapgen/wp40/layout_cache.lua`:
  - Key parts format / seed / source / settings / interpreter at `:70-81`.
  - Sections framed by length and sha256, plus a trailer hash, at `:136-155`.
  - `decode` returns nil, a reason and a damaged flag (`:160-212`).
  - `store` writes through `core.safe_file_write` (`:229-232`).
- `r7_loader.lua:45-85` builds the key: `get_mapgen_setting("seed")`, a digest of the whole mapgen tree via
  `preparation_identity.lua`, six mapgen settings, and `jit.version` or `_VERSION`.
- `r7_loader.lua:376-408`: a damaged file gives a warning and a rebuild; a miss stores the file; a failed write
  only warns.

The grug_map base cache (`mods/PLAYER/grug_map/base.lua:555-578`, a key file plus content files) is a second,
simpler precedent.

### Implementation sketch (not implemented)

**1. New file `mods/ENTITIES/grug_mobs/spawn_regions_cache.lua`.** Plain Lua 5.1 with injected `sha256`,
`read` and `write`, like `layout_cache.lua`, so offline tools run the same code.
- `FORMAT = "grug_region_maps_v1"`, file `<worldpath>/grug_region_maps.txt`.
- `M.compact(full_map) -> payload`, holding:
  - the grid origin and size (i0, j0, w, h);
  - a u8 region-id grid as a byte string, with a u16 fallback flag beyond 255 regions (today's maximum is 61);
  - regions as {kind or camp id, is_camp, belt, x, z, size, level};
  - camps as {id, x, z, region id, score, slope, poi_belt index};
  - leaders as {role, x, z, level, respawn, region id, fallback};
  - problems, warnings and summary counts.
- `M.rehydrate(payload, recipe) -> map`:
  - resolves ids against the freshly parsed recipe (`kind_by_id`, `camp_by_id`, belts);
  - rebuilds `by_kind` and `map.frame`;
  - provides `region_at` from the byte grid, keeping the 8-neighbour fringe fallback via cell centres
    i·32+16;
  - sets levels from the kind or camp.
- `M.encode(key, payloads) -> bytes`: a D71-style header with key lines, then one block per zone (a recipe
  digest line; `r`/`c`/`l`/`p`/`w` lines with floats as `%.17g`; a length-framed binary `g` section), ending
  in `end <sha256 of everything before>`.
- `M.decode(bytes, key) -> payloads_by_zone`, or `nil, reason, damaged`.

**2. Key** (ordered, single-line parts):
- `format`, `seed`, the mapgen tree digest, mapgen settings, interpreter (all as in D71);
- a `builder` digest: sha256 over `spawn_regions_core.lua`, `spawn_regions.lua`, `data/subtypes.json` and
  `grug_core/zone_authority.lua`;
- a per-zone digest: sha256 of `data/zones/<zone>.spawns.json`, stored in each zone block. A zone's map
  depends only on its own recipe, the world and the code, so editing one recipe rebuilds only that zone
  (0.1–0.5 s).
- Optional: have `r7_loader.lua` publish its D71 key parts via `grug_mapgen.wp40`, so the 3–4.6 ms mapgen digest
  is not computed twice.
- The input-coverage test below ensures that no file the builder reads is missing from the key.

**3. Changes in `spawn_regions.lua`**
- In the hook (`:1077-1083`):
  - Compute the key, then `pcall(load)`.
  - For each recipe zone whose digest matches, rehydrate inside a `pcall`; otherwise call `SR.map` (build).
  - Log one summary line: hits, builds, bytes, ms.
  - On a hit, re-log the stored problems and warnings, so the log looks the same as after a build.
  - If anything was built, `pcall(store)` the complete file atomically; a write failure is only a warning.
- `SR.map` keeps only the compact form (this also fixes #9). Offer `SR.full_map(zone)` / `CORE.build` for tools.

**4. Failure handling.** Each of these leads to a rebuild of the affected zones and an atomic replace of the
file, never a crash:
- a missing file;
- a different format or key;
- a hash or length mismatch, or a truncated file;
- a parse error;
- an unknown kind or camp id;
- a region id out of range;
- a wrong grid length.

Logging and writing:
- A damaged file logs a warning; a differing key logs an action line.
- A zone whose build fails stays `maps[zone] = false`, as today.
- Only the main thread writes, through `core.safe_file_write` (temp file then rename), into the world
  directory, which mod security allows.

**5. Tests**
- **Offline portable test** (LuaJIT with `tools/r28_zone_atlas/world.lua`, seeds 12345 and 42):
  - build, compact, encode, decode and rehydrate, then check equality on every cell plus the ring, and for all
    describe targets, leaders and camps;
  - two builds encode byte-identically;
  - every corruption case returns `nil, reason, damaged` and never throws;
  - a changed per-zone digest rebuilds only that zone.
- **Input-coverage test:** wrap `io.open`, `dofile` and `get_dir_list` during a build and assert that every file
  read is covered by the key.
- **Engine probe:**
  - a cold boot stores the file;
  - a warm boot hits, with the hook under 10 ms;
  - a corrupted or deleted file gives a warning, a rebuild and a normal boot.

**6. Similar candidates**
- Zone-marker placement (#20) can join this file or the grug_map base key.
- The D71 layouts and the grug_map base are already cached and work (a layout hit drops 20.5 s to a 4.1–4.4 s
  construction; a map-base hit drops 10.1–10.5 s to 0 s).
- The next boot item is building the grug_mapgen runtime from the cached texts (#22).

---

## 4. Checked and found fine

Do not re-check these.

**Spawning and region queries**
- `SR.region_at` 0.10–0.13 µs, `SR.level_at` 0.11–0.16 µs, `grug_zones.id_at` 0.06–0.25 µs,
  `mob_level_at` 0.15–0.18 µs.
- `SR.describe` 1–2.3 µs; quest text fills: all 240 quests take 0.2 ms the first time, then come from a cache.
- `SR.attempt` 34–37 µs, once per player per second in 4 slices, about 3–4 ms/s at 100 players.
  `region_camp_tick`, `leader_tick` (31 µs with 50 stub players) and `camp_units` (6.5–40 µs every 5 s) are
  fine.
- Spawn decision parts (`in_drift` 10 µs, `protected_spawn_surface` 2.4 µs, `spawn_allowed` 0.5 µs) and
  density checks (`region_density_allows` 15–33 µs, `density_allows` 1.4 µs) are fine.
- Spawn ABMs on the Lua side: ≤ 0.04 ms/s in total. Their engine-side cost is #11.
- Leader respawn ground search: about 1 ms, only when a respawn is due and a player is within 48 nodes.

**Mobs**
- Combat (20 guards vs 40 hostiles): Lua per step 0.56–0.70 ms, p99 2.0–2.6 ms. `do_states` 25–36 µs including
  the LOS raycast; `general_attack` 6–14 µs per mob per second.
- `raycast` over 16 nodes 4.5 µs; `core.line_of_sight` 0.25 µs; A* when a path exists 14–211 µs. The per-step
  budget held at ≤ 2 `find_path` calls per step in every run.
- `separation_step`, telegraphs, `verbs` `players_near`, `boss_dragons` foot checks, the 10 s `rares` scans and
  the `start_npcs` heartbeat (≤ 1.1 ms every 5 s) are fine.
- `get_objects_inside_radius` costs about 0.05 µs per object; `get_staticdata` 2.8–27 µs per block crossing.
- No mob leak: 4 spawn/kill/remove cycles left the heap at 171.56 → 171.63 MiB, and the weak tables clean up
  after themselves.

**Combat and UI**
- HUD diffing: 0 identical `hud_change` re-sends across all HUD owners. The one exception is a one-time set of 5
  offset changes at party-row creation (`grug_parties/hud.lua:25`).
- Status effects and DoTs (0.5 s, 5–8 µs per player), mana/rage regen (1.7 µs per player per tick), renew HoT,
  bow draw, food crumbs and the feed, combat_hud, location, `environment_damage` and `atmosphere_zones`
  globalsteps (each ≤ 30 µs per step at 40 players, or slot-spread) are fine.
- Projectiles: homing, no per-step raycast, an active limit. AoE `get_objects_inside_radius` only on cast,
  radius 2–8.
- Particles: 3–20 per event, well inside the "hundreds" budget.
- Character page: 2.7 KB, 70 µs, rebuilt on events only. Inventory callbacks ≤ 8 µs (apart from the quest
  HUD, #5). Join costs 0.9–2.3 ms per player. Hit pipeline: 65 µs per punch, event-driven.
- Discovery scan (`grug_jobs/discovery.lua:73`): 28–39 µs per player every 2 s.

**Globalsteps, timers and protection**
- All 42 globalsteps are throttled, except 4 that do trivial work every step (player_api, the default flag
  reset, the mobs step reset, the builtin `after` queue). With no players they cost about 0.45 ms/s together.
  The full inventory is in Appendix A.
- `core.is_protected` 3.0 µs; the housing claim scan is O(claims), capped at one claim per player.
- Water guard (`liquid_transformed`) 3.5–9.5 µs per batch. Zone queries (`territory_rule_at`, `water_class_at`,
  `grug_zones.at`, `world_alterable`) are 0.5–3 µs each.
- Vegetation renewal: 53–440 µs per player every 5 s, round-robin.
- Default ABMs (grass spread and cover, lava cooling, cactus, papyrus, moss): negligible.
- LBMs other than #16 are cheap and idempotent. Mapgen registers no runtime ABMs or LBMs.
- Furnace and station node timers (1 s, only while running) are fine.

**Bounded caches**
- Trader shelves are lazy and their cache is bounded; `prices.lua` caches are bounded by the item count;
  `grug_jobs` station lookups for non-grid stations take 0.6 µs.

**Travel**
- Home travel, faction respawn: `emerge_area` is asynchronous with a 30 s timeout; there is no synchronous
  wait.
- Waystone discovery: 1 s per player, 12 rows. Boat water check: 1 s; `water_step` 1–2 `get_node` per step.

**Boot and memory**
- Every `on_mods_loaded` hook other than the region maps takes ≤ 8 ms; together about 0.23 s.
- Every mod load except grug_mapgen and grug_map takes < 50 ms, JSON included.
- The D71 layout cache and the grug_map base cache work as designed.
- No heap growth beyond garbage over 75–100 s idle windows: about 170 MiB after a full GC, both at boot and at
  the end of every run.
- Per-player state is cleared on leave in about 50 tables (the exceptions are #19).

---

## 5. Suggested lane split for fixing

| Lane | Contents | Files | Notes |
|---|---|---|---|
| **P1 Quest state & map UI** | #1, #5, #3, #12; NPC tag callback part of #10 | `grug_quests/state.lua`, `npc.lua`, `hud.lua`; `grug_map/providers.lua`, `page.lua`, `minimap.lua` | Highest player impact. #1's cache comes first; #5 and #3 build on it. #3's arrow throttle is a look & feel call for Jan. Offline fixtures plus one engine run with the helper B stand-in probe (`helpers/B/grug_perf_probe_b`) |
| **P2 Mob pathing & allocation** | #4, #13, #6 (with A4 idle cost), #17, #18 | `mobs/api.lua` (GRUG PATCH markers, VENDOR.md patch list), `mobs/grug_obstacle.lua`, `grug_mobs/patrol.lua`, `aggro.lua`, `separation.lua`, `flight.lua`, `init.lua`; `minetest.conf` | #4(d), giving up pursuit, is a gameplay ruling for Jan. A/B with the helper A probe (`helpers/A/grug_probe_perf_a`) |
| **P3 Region-map cache & boot memory** | #2 (§3), #9, #20, #21; investigate #22 | new `grug_mobs/spawn_regions_cache.lua`, `spawn_regions.lua`, `spawn_regions_core.lua`, `grug_map/location.lua`; the three tools listed in #9 | Needs the user's explicit "go" for a cache (the user asked for the design). Offline portable test plus 2–3 engine boots (cold, warm, corrupt file) |
| **P4 Per-player ticks & misc** | #7, #8, #10 (carrier slotting), #14, #15, #16, #19 | `grug_jobs/registry.lua`, `stations.lua`; `grug_abilities/init.lua`, `input.lua`; `grug_mobs/target_frame.lua`; `grug_core/tag_carrier.lua`, `combat.lua`; `grug_mounts/entity.lua`; `grug_farming/init.lua`; `grug_mobs/verbs.lua` | All S-sized, independent. Only `tag_carrier.lua` is shared with P1, which changes just the `npc.lua` callback |
| *(ruling first)* | #11 spawn ABMs | `mobs/api.lua` spawn registration, `grug_mobs` spawn rows | Changes spawn semantics; Jan decides. If yes, it belongs in P2 |

Suggested order: P1 and P3 in parallel, then P2 and P4. Every lane should re-run its own probe as a before/after
comparison; the numbers are comparisons, not gates.

## Engine-run record

18 runs, at most 2 at once through the semaphore: orchestrator 2, A 4, B 3, C 5, D 4. All have ended; their
run directories are deleted; no server of this review is running.

## Appendix A: inventory of scheduled code (helper C, seed 12345, 0 players)

"Idle" is the measured mean per firing with no players.

**Globalsteps**

| file:line | period | work | scales with | idle |
|---|---|---|---|---|
| builtin after.lua:117 | every step | after-queue | jobs | 1.4 µs |
| BASE/player_api/api.lua:246 | every step | control + animation | players | 2.9 µs |
| BASE/default/functions.lua:318 | every step | resets a flag | — | 0.8 µs |
| ENTITIES/mobs/api.lua:133 | every step | `grug_obstacle.begin_server_step` | — | 1.5 µs |
| CORE/grug_core/feed.lua:239 | 0.1 s | feed expiry | feeds | 1 µs |
| CORE/grug_core/tag_carrier.lua:341 | 1 s | carriers, observers, HP bars, callbacks | carriers × players | 69 µs (13 carriers), #10 |
| CORE/grug_core/status.lua:463 | 0.5 s | statuses + HUD | players | 1 µs |
| CORE/grug_core/atmosphere.lua:256 | 1 s | clock, day-night ratio | players | 1 µs |
| CORE/grug_core/atmosphere_zones.lua:537 | 0.25 s, 8 slots | zone mood | players | 1 µs |
| CORE/grug_core/starts_preload.lua:164 | every step | boot preparation, 100 ms budget | boot only | 1.2 µs after ready |
| CORE/grug_core/combat_hud.lua:9 | 0.2 s | combat icon | players | 0.9 µs |
| CORE/grug_core/environment_damage.lua:111 | 1 s | drowning / suffocation | players | 0.8 µs |
| CORE/grug_core/movement.lua:677 | 0.1 s | movement states | affected players | 1.2 µs |
| PLAYER/grug_classes/selection.lua:538 | 0.1 s | creation lock | creating players | 1 µs |
| PLAYER/grug_visuals/apply.lua:350 | 1 s | wield sync | players | 0.8 µs |
| ENTITIES/grug_mobs/spawn_regions.lua:1014 | 0.25 s, 4 slices | region spawn attempts | players | 4.8 µs |
| ENTITIES/grug_mobs/target_frame.lua:138 | 0.5 s | target frame | players | 0.8 µs, #8 |
| ENTITIES/grug_mobs/boss_dragons.lua:158 | 0.25 s / 1 s | rime/scorch under feet | players | 0.9 µs |
| ENTITIES/grug_mobs/bosses.lua:631 | 10 s | dragon respawn | dragons | 1.1 µs |
| ENTITIES/grug_mobs/start_npcs.lua:1454 | 5 s | settlement NPC rows | settlements | 8.9 µs avg, max 615 µs |
| ENTITIES/grug_mobs/rares.lua:316 | 10 s | rare spawn/watch | rares | 1.1 µs |
| PLAYER/grug_housing/stone.lua:227 | 5 s | claim draft/expiry scan | claims | 0.8 µs |
| PLAYER/grug_housing/interface.lua:140 | 10 s | character page refresh | players | 0.7 µs |
| PLAYER/grug_housing/stone_form.lua:496 | 1 s | open draft forms | open forms | 0.9 µs |
| PLAYER/grug_inventory/equipment.lua:1075 | 0.1 s | dig control, wield group | players | 1.4 µs; about 5 µs per player |
| PLAYER/grug_inventory/pages.lua:387 | 1 s | effects tab | viewers | 0.6 µs |
| ENTITIES/grug_traders/vendors.lua:609 | 5 s | 12 capital slots × players | players | 0.8 µs |
| PLAYER/grug_quests/hud.lua:139 | 0.5 s | quest HUD | players | 0.9 µs, #5 |
| PLAYER/grug_parties/init.lua:341 | 1 s | invite pruning | invites | 0.9 µs |
| PLAYER/grug_parties/hud.lua:104 | 0.5 s | party HUD, change-detected | players | 0.8 µs |
| PLAYER/grug_jobs/discovery.lua:73 | 2 s | inventory scan | players | 0.6 µs |
| PLAYER/grug_jobs/workspaces.lua:375 | 1 s | open stations; furnace viewers get `show_formspec` each second | viewers | 0.8 µs |
| PLAYER/grug_home/waypoints.lua:161 | 1 s | waypoint discovery | players | 0.6 µs |
| PLAYER/grug_map/minimap.lua:449 | every step, 5 s slow path | minimap | players | 1 µs, #1, #12 |
| PLAYER/grug_map/page.lua:288 | 0.5 s | Map tab | viewers | 0.9 µs, #3 |
| PLAYER/grug_map/location.lua:215 | 0.1 s | location sample | players | 1.4 µs |
| PLAYER/grug_abilities/init.lua:2350 | 0.05 s (every step) | input, crosshair rays | players | 1.2 µs, #8 |
| PLAYER/grug_abilities/init.lua:2375 | 0.5 s | mana/rage regen | players | 1.1 µs |
| PLAYER/grug_abilities/kits.lua:937 | 3 s | renew HoT | active renews | 0.8 µs |
| PLAYER/grug_abilities/scout.lua:429 | 0.05 s | bow draws | drawing players | 1.3 µs |
| ITEMS/grug_fishing/init.lua:237 | 0.1 s | bobbers | casts | 1 µs |
| ITEMS/grug_farming/init.lua:528 | 0.5 s tick, each player once per 5 s | vegetation renewal | players | 1.4 µs idle; 53–440 µs per service |

**ABMs** (95 in total)
- 7 from default and mobs: lava cooling (2 s / 2), cactus (12 s / 83), papyrus (14 s / 71), grass spread
  (6 s / 50), grass covered (8 s / 50), moss (16 s / 200), mob spawner node (10 s / 4). All have negligible Lua
  cost.
- 88 mobs_redo spawn ABMs: 20–60 s, chance 231–9231, mostly stone, strata or surface nodes with an air
  neighbour. Their engine scan cost is #11.

**LBMs** (all `run_at_every_load`)
- `default:close_chest*_open`, `grug_jobs:activate_stations`, `grug_mobs:guard_banner_init`,
  `grug_mobs:camp_fire_init`, `grug_jobs:activate_public_hearths`, `grug_farming:start_soil_timer` (#15),
  `grug_farming:activate_crop_geometry` (#16), `grug_jobs:workspace_activation`.

**Node timers** (95 node types)

| Timer | Period | Note |
|---|---|---|
| `grug_farming:soil` | 15 s | #15 |
| crops | 200 s per stage, only when wet | |
| saplings | 300–1500 s | |
| leafdecay | after a trunk is dug | |
| furnace, dual furnace, brewing stand, jobs workspace | 1 s while running | |
| camp fire and banner | 30 s | |
| dragon rime/scorch nodes | 6–8 s | |
| `mobs:hearing_vines` | 1 s | |

**Recurring `core.after` loops:** `grug_mobs/verbs.lua:267` (a finite poison chain), `grug_home/travel.lua:111`
(30 s travel timeout), `default/furnace.lua:339` (sound cleanup). Every other `core.after` call is one-shot.
