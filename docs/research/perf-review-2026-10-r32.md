# Grudgelands performance review — Round 32 (read-only)

Code measured: main `c8951467` (detached worktree `.claude/worktrees/r32-r1`), 2026-10-03. Lanes F1 and F2
change the minimap zoom and the LMB input during this round; every number here is for `c8951467` before them.
Nothing in the repository was changed. Probes, patches, logs and scripts are listed in the Evidence appendix.

Each claim says how it is known: **[M]** measured in this round, **[C]** read in the code (file:line, paths
relative to `mods/`), **[S]** taken from a source (URL or an earlier report). Numbers are comparisons, not
targets.

## 0. Summary

**Where the server hurts first.** With 50 player stand-ins, the game's Lua takes 40–74 ms per second of the
main server thread (4–7 %); with 100 it takes 65–121 ms/s (7–12 %) **[M]**. No server step went over the 90 ms
step period with 50 stand-ins in three of four runs; with 100, 0–5 steps per 40 s did **[M]**. So steady Lua
load is not where a 50-player playtest breaks first. In order, the risks are:

1. **Step spikes from passes over all players in one step.** At 100 stand-ins the Lua time per step has a median
   of 3.9–7.6 ms but a p99 of 28–71 ms and a maximum of 66–105 ms **[M]**. The largest single callbacks are the
   Map tab (up to 31–69 ms when several viewers' forms are due in the same step), the party HUD (12–28 ms),
   ability input (14–28 ms), the minimap (13–20 ms), the 5-second leader and camp tick (13–24 ms) and vegetation
   renewal (8–23 ms) **[M]**. Garbage-collection steps land inside these maxima.
2. **Memory.** The server process holds **2.9–3.3 GB** after its first map generation, because the emerge
   thread's mapgen Lua environment keeps **630–745 MiB live** (800–1,080 MiB before a collection) and grows with
   the chunks it generates **[M]**. The main Lua heap is only 67–137 MiB after a full collection **[M]**.
3. **First join of many clients at once.** Every new client downloads about **13.8 MB** of media (12.9 MB of
   models, textures and sounds plus the 0.9 MB world-map base) **[M]**; 50 first joins are about 690 MB through
   the game server's own connection unless `remote_media` serves them **[C, S]**.
4. **Per-player passes that run every server step:** ability input and the crosshair (20–34 ms/s at 100) and the
   minimap glide (13–25 ms/s) are the two largest steady costs and grow linearly **[M]**.
5. **Not measurable with stand-ins:** the engine's per-client sending of map blocks and objects, player physics,
   real punches and casts, and client-side work (§5.4). A short test with a handful of real clients is the only
   way to see those.

Compared with October, the re-measured baselines improved where Round 30 aimed: the 40-stand-in probe dropped
from 111 to 36 ms/s, blocked chasers from 7–8 ms to 0.8 ms per step, and a later start from 15.6–16.0 s to
8.0–9.1 s (§2). Round 31's new systems (PvP tick and gate, garrisons and respawn slots, looks and enchant
colours, per-faction map lists) are cheap (§3).

**Fix before a 50-player playtest** (all small): stagger Map-tab rebuilds (R1), spread the party HUD over slots
(R2), spread the 5 s leader and camp tick (R3), serve media through `remote_media` (R4, configuration), and give
the server at least 4 GB of RAM (R5, operations). Everything else is "later" (§6).

## 1. Method

- **Engine:** headless Luanti 5.17.0 (Flathub build of 2026-10-02), LuaJIT, seed 12345, through
  `tools/luanti_headless.sh` and the shared two-slot semaphore, under `chrt --idle 0`. Seven runs of 2–4 minutes
  (Appendix B). The host is the user's workstation, shared with other lanes' servers; repeated runs of the same
  scenario differed by up to about 40 % (§5), so read every number as a range.
- **October probes, re-run unchanged** (copies of the Round 29 helpers, paths fixed): **B** (40 stand-ins at the
  Accord human start, combat and UI; one guard added because `grug_quests.marker_state` no longer exists),
  **A** (mob AI and pathing in a stone arena, 150 idle mobs, 40 chasers at an enclosed target), **C** (idle
  server, 336 forceloaded blocks around Dawnmere, scheduled-code inventory, micro benchmarks).
- **New scale probe** (`grug_probe_r1s`): stand-ins join through the real join chain with faction, race, class,
  a rolled look, a quest log (start areas: 3 active, 15 completed; capital and fortress: 10 active, all others
  completed) and a level. Phases: idle (0 stand-ins), 50, 100 (40 s each). It wraps every globalstep, entity
  `on_step`/`on_activate`/`get_staticdata`, ABM, LBM and node timer, and in later runs a dozen hot functions,
  with `core.get_us_time`; a marker globalstep closes each server step (Lua time per step, wall time between
  steps). The run wrapper samples the per-thread CPU time of the server process at phase marks and its memory
  every second. A mapgen script logs the emerge thread's Lua heap.
- **Scenarios:**
  - *spread* (runs `scale1`, `scale2`): 30 % at the Accord human start, 30 % at the Throng orc start, 25 % in
    Highcourt (the Accord human capital), 15 % at the Accord fortress (half of them Throng attackers). They
    walk at 4 nodes/s; a third of the start-area stand-ins and all fortress attackers "fight" (below); one in ten
    keeps the Map tab open; parties of five. `scale1` placed the start areas at the town edge, `scale2` (a later
    start of the same world) 140 nodes out in the wild and opened the maps one by one.
  - *crowd* (runs `crowd`, `crowd2`): all stand-ins in the wild beside the Accord human start (radius 70), half
    of them fighting; `crowd2` also lets the region spawner place mobs (below).
- **What "fighting" is:** a stand-in cannot punch through the engine (`ObjectRef:punch` needs a real object), so
  a nearby mob is told to attack it (`do_attack`), the stand-in faces it, is marked in combat and the mob dies
  after 12 s (`check_for_death`). The mob side (chasing, line-of-sight, its hits) is real; the player side of a
  hit or cast is not. mobs_redo's `add_mob` spawns only with a player object in range (`mobs/api.lua:4505-4510`
  **[C]**), which a stand-in never is, so in `crowd2` the probe replaced it with a version without that test.

## 2. October baselines, re-measured

| What (probe) | Oct (R29 code) | After Round 30 lane | Now `c8951467` | Why it moved |
|---|---|---|---|---|
| All globalsteps, 40 stand-ins walking (B) | 111.0 ms/s | 42.2 | **36.4** | R30 P1/P4 |
| — minimap | 55.8 | 9.3 | **8.4** | P1 hoisting, cached markers |
| — ability input + crosshair | 9.9 | 12.5 | **9.6** | P4 crosshair every 0.15 s |
| — quest tracker HUD | 17.1 | 6.5 | **4.8** | P1 key check, five slots |
| — Map tab (1 viewer) | 17.2 | 0.93 | **0.91** | P1 signature every 2 s |
| — party HUD | 2.0 | 2.4 | **2.1** | unchanged |
| — tag carriers | 1.35 | 0.91 | **1.03** | P4 eight slots |
| — PvP location tick (new) | — | — | **0.23** | R31 |
| Map tab form size / traffic of 1 walking viewer (B) | 75–89 KB, 150–179 KB/s | 82.6 KB, 33 KB/s | **65.7 KB, 26 KB/s** | R31 per-faction lists |
| Map tab build (B micro) | 5.6 ms | 1.55 ms | **0.93 ms** | |
| 40 blocked chasers, Lua per step (A) | mean 7.0–8.0, p99 18–19, max 23–38 ms | mean 0.68 | **mean 0.82, p99 3.9, max 8.8 ms** | P2 A* budget, back-off, give-up |
| `find_path` calls in 20 s (A) | 2 per step, every step | — | **7 in total** | P2 |
| Lua garbage, 150 idle mobs (A) | 7.75 MiB/s | 4.49 | **4.41 MiB/s** | P2 collision-box field |
| Idle server, 336 blocks, 30 objects (C) | 2.996 ms/s, max step 6.5 ms | — | **2.145 ms/s, max 3.6 ms** | 88 → 3 spawn ABMs (10 ABMs in all) |
| Grid craft recipe lookup (C) | 83–296 µs | 5 µs | **2.3–3.5 µs** | P4 index |
| Cold boot to "listening" | 40.9–41.8 s | — | **38.2–38.6 s** (C with info logging: 50.7 s) | |
| Later boot to "listening" | 15.6–16.0 s | 7.2 s | **8.0 s, 9.1 s** | P3 caches |
| Main Lua heap after a full GC | ~170 MiB | 70.5 (later start) | **67–69 MiB later start, 111–114 MiB first start** | P3, R31 C |
| Full GC of the main heap | 59–128 ms | — | **21–24 ms (A, 112 MiB) … 68–294 ms in scale runs** | depends on garbage present |

All "Now" values **[M]**; October and Round 30 values **[S]** ([perf-review-2026-10.md](perf-review-2026-10.md),
[round30-plan.md Completion](../planning/round30-plan.md#completion-2026-10-02), Round 30 P1 evidence). The B micro benchmark of
`core.deserialize` on the late quest log read 499 µs because a collection cycle landed in it; measured after a
full collection it is 56–62 µs for 13.7 KB (515 quests), as in October (51–54 µs for 12.8 KB) **[M]**.

## 3. What is new since October

| System | Measured | Verdict |
|---|---|---|
| PvP location tick (`PLAYER/grug_pvp/init.lua:249-273`) | 82–88 µs per tick for 100 stand-ins, once a second; 1.9–6.9 µs per sample; globalstep 0.23–0.38 ms/s at 40–100 **[M]** (R31: 74.5 µs **[S]**) | fine |
| PvP combat gate | `can_harm` 0.19–0.28 µs, `state` 0.18–0.21 µs, `pvp_rule_at` 0.07–0.10 µs, `faction_at` 0.07 µs; `combat_ray(40)` 11.6–12.6 µs with the gate inside **[M]** | fine |
| PvP tab | 1.1–2.2 µs per step at 0–100 (only open tabs are compared) **[M]** | fine |
| Garrisons and respawn slots | Accord fortress loaded: General 15–61 µs, bodyguards 21–24 µs, royal guards 19–31 µs per `on_step`, against 4–9 µs for a villager **[M]**. Killed fortress guards booked their slots (owed 14–15 of 19) **[M]**. Settlement heartbeat (`ENTITIES/grug_mobs/start_npcs.lua:1587`, every 5 s, all 78 rows) 0.24–0.36 ms/s, max 1.4–1.9 ms **[M]**; census 63–96 µs **[M]** | fine; NPC cost per entity is the knob if a capital is crowded |
| Dragon arena | Not loaded in any run. The hazard pass (`boss_dragons.lua:285`, 4 Hz, one or two node reads per player) costs 0.45–0.49 ms/s at 50–100 stand-ins **[M]**; `dragon_arena.inside` 0.03 µs **[M]**; the leash and wrath tick runs once a second per engaged dragon with one `get_objects_inside_radius(r 64)` **[C]** `boss_dragons.lua:903-920` | fine by reading; not engine-measured with a fight |
| Looks and enchant composition | `compose` hit 1.3–1.9 µs, miss 4.7–7.6 µs; enchanted 4-piece metal set: 1,258-byte texture string; `armor_layers` 1.8 µs; `apply` without change 4.2–5.2 µs; `enchant_image` 0.26–0.29 µs **[M]**. The compose cache is unbounded (`PLAYER/grug_visuals/compose.lua` `cache`) **[C]**: 187–345 entries, 60–113 KB after about 100 NPCs and 100 stand-ins **[M]** | fine; grows only with distinct looks × gear |
| Per-viewer map lists and settlement icons | Lists are split per faction once at load (`PLAYER/grug_map/providers.lua:100`, `page.lua:87-107`) **[C]**: `collect_markers` all 115–169 µs for 211 (Accord) / 216 (Throng) markers, minimap providers 41–45 µs for 75 **[M]** | fine |
| Quest markers (`PLAYER/grug_quests/state.lua:228-259`) | memo hit 0.16 µs, recompute 106–187 µs (late log). In the runs the memo was recomputed 16–66 times per second (2.4–6.5 ms/s at 50–100) because it expires after 1 s while the minimap refreshes each player every 5 s **[M, C]** | later (R8) |
| Round 30 caches | region-map file 110 KB, zone-grid file 46 KB, later start 8.0–9.1 s; crafting index 3–4 µs; quest tracker key (`journal_key`) 7–9 µs alone, 10–17 µs in the runs **[M]** | working |
| Minimap and base map per player | Base map: 7 PNG tiles, 896 KB, sent to every client at join as dynamic media (`PLAYER/grug_map/base.lua:547-553`) **[M, C]**. A cell texture string is 110 bytes and changes every 40 nodes walked **[M]**. A walking player gets 15–19 HUD changes per second, 420–530 B/s, 90 % of it the minimap's map position (`minimap.lua:133`) **[M]**. 11.5–21.6 µs per player-step **[M]** | traffic fine; CPU later (R7) |

## 4. Scale with 50 and 100 stand-ins

### 4.1 Server step and thread load

| Run (scenario) | Stand-ins | Lua ms/s | Lua per step p50 / p95 / p99 / max (ms) | Steps over 100 ms in 40 s | Server-thread CPU |
|---|---|---|---|---|---|
| `scale1` (spread, town edge) | 0 | 10.9 | 0.9 / 1.9 / 2.7 / 3.4 | 1 | 3.1 % |
| | 50 | 73.9 | 5.2 / 15.4 / 35.5 / 45.6 | 0 | 9.5 % |
| | 100 | 83.2 | 5.6 / 20.5 / 38.7 / 79.0 | 0 | 9.8 % |
| `scale2` (spread, wild, later start) | 0 | 4.7 | 0.4 / 0.8 / 1.1 / 1.8 | 0 | 1.9 % |
| | 50 | 49.9 | 3.2 / 12.1 / 26.6 / 37.1 | 0 | 6.0 % |
| | 100 | 121.1 | 7.6 / 26.0 / 59.3 / 104.5 | 3 | 14.0 % |
| `crowd` (one start wild) | 50 | 40.5 | 2.7 / 8.8 / 18.9 / 40.3 | 0 | 4.9 % |
| | 100 | 65.0 | 3.9 / 15.4 / 28.1 / 66.0 | 1 | 7.3 % |
| `crowd2` (same, with mobs) | 50 | 51.6 | 3.5 / 10.8 / 18.8 / 42.6 | 2 | 6.2 % |
| | 100 | 117.1 | 7.6 / 24.0 / 71.0 / 104.2 | 5 | 13.2 % |

All **[M]**. The server step period is 90 ms (wall time between steps: median 90.2–90.7 ms in every phase). The
server thread's CPU includes the probe's own stand-in movement, so it reads slightly above the Lua column. The
idle rows differ by what was loaded (`scale1`: Highcourt's 90 NPCs and the fortress garrison; `crowd`: 2 NPCs).

### 4.2 Per-system share at 100 stand-ins

ms/s, `scale2` / `crowd2`; maxima in one step in brackets **[M]**:

| Callback (file:line) | ms/s | What scales |
|---|---|---|
| Ability input + crosshair, `PLAYER/grug_abilities/init.lua:2367` | 34.5 / 33.4 (17–28) | every step × players: `input.step` 18 µs × ~11/s, `crosshair.update` 19–20 µs × 6.7/s per player |
| Minimap glide, `PLAYER/grug_map/minimap.lua:487` | 22.9 / 24.7 (15–16) | every step × players; includes the 5 s static refresh |
| Map tab, `PLAYER/grug_map/page.lua:369` (10 viewers) | 10.0 / 11.1 (50–69) | 0.9–1.1 ms per build, 65–67 KB per send |
| `atlas.collect_markers` (inside the two above) | 10.9 / 11.9 | 452–489 µs per call under load (41–169 µs alone) |
| Party HUD, `PLAYER/grug_parties/hud.lua:104` | 6.6 / 7.2 (21–28) | all players every 0.5 s; `grug_parties.view` 30–33 µs × 230/s |
| Vegetation renewal, `ITEMS/grug_farming/init.lua:555` | 6.4 / 4.2 (8–23) | 10 services per 0.5 s tick at 100 players |
| `Q.marker_states` recomputes | 6.5 / 6.2 | see §3 |
| Quest tracker HUD, `PLAYER/grug_quests/hud.lua:162` | 3.6 / 4.4 (2–19) | `journal_key` scans every bag slot each 0.5 s |
| Region spawner, `ENTITIES/grug_mobs/spawn_regions.lua:1061` | 3.3 / 3.0 (5–48) | attempts 22–32 µs; leader tick 4.2 ms avg, max 24 ms and camp tick 2.5 ms avg, max 12 ms every 5 s (`crowd`) |
| player_api, equipment, target frame, regen, status, environment damage, tag carriers | 1–4 each | linear, mostly slotted |
| Mobs and NPCs (`on_step`) | 10.9 / 7.6 | NPCs 4–60 µs per step; start-zone mobs 15–20 µs |

In `crowd2` the region spawner kept 36–41 mobs around 50–100 stand-ins: the region density limit stopped it
(401–512 "density" refusals, 1,142–2,680 "player too near") **[M]**, so in one crowded zone the mob count does not
grow with the player count. 183 fights and 31 kills ran in 40 s **[M]**.

### 4.3 Memory

- **Main Lua heap after a full collection:** idle 67–114 MiB (by what is loaded), with 100 stand-ins 89–137 MiB,
  after they left 83–130 MiB **[M]**: about 0.2–0.3 MiB per stand-in. Between collections it swings over
  100–150 MiB within 40 s at 50–100 stand-ins (e.g. 135 → 260 MiB) **[M]**.
- **Process:** the main thread's boot peaks at about 1.34 GB (VmHWM before the first emerge) **[M]**. The first
  map generation then raises the resident size to **2.9–3.3 GB** (B 3.05, A 2.96, C 2.94, `scale1` 3.33,
  `crowd2` 3.19 GB VmHWM); later starts 1.96–2.31 GB **[M]**. The emerge thread's mapgen environment logged
  799–824 MiB before and 630–648 MiB after a full collection at its first chunk, 731–745 MiB live after 10–40
  chunks; one collection there took 407–694 ms (on the emerge thread, not the server thread) **[M]**. October's
  "1.8–2.0 GB" boot peak did not include this environment **[S]**.

### 4.4 Data sent per player (what the stand-ins saw)

- HUD changes: 15–19 per second, 420–530 B/s per walking player (minimap position 90 %) **[M]**.
- Map tab open while walking: one 65–67 KB form every 2 s, 26–28 KB/s per viewer **[M]**.
- First join: about 13.8 MB of media (models 9.7 MB, sounds 1.3 MB, textures 1.8 MB, base-map tiles 0.9 MB);
  the largest files are `grug_mobs_ice_dragon.b3d` (1.46 MB), `grug_mobs_jungle_wyvern.b3d` (0.85 MB) and one
  405 KB PNG (`grug_inventory_quiver.png`) **[M]**. The client caches media by hash, so a rejoin is cheap
  **[S]** (Luanti `remote_media` setting, `builtin/settingtypes.txt`).
- Not counted: map blocks, active objects, sounds and particles the engine sends (§5.4).

### 4.5 What a stand-in does not cover

- **Network:** no packet leaves the server for a stand-in. Map-block and object sending, the per-client send
  queues and the `ConnectionSend` thread (0.0–0.1 % here) are untested.
- **Engine work for real players:** physics and collision, active-block activation around each player (the probe
  forceloaded 876–980 blocks instead), punches, `on_dig`, inventory actions, chat.
- **Player side of combat:** casts, swings, damage to mobs through `ObjectRef:punch`; October measured the hit
  pipeline at 65 µs per punch, event-driven **[S]**.
- **Client side:** minimap texture composition, formspec rendering, the client's frame rate.

## 5. Noise

Two runs of the same "spread" scenario (`scale1`, `scale2`) differ by 32 % at 50 and 45 % at 100 stand-ins,
partly by design (town edge vs wild, maps opened at once vs one by one, more function wrappers in `scale2`),
partly from the shared host: other lanes' measuring runs and the user's client ran at the same time (ledger,
Appendix B) **[M]**. Single maxima include incremental collection steps. Treat the tables as ranges.

## 6. Findings, ranked by gain per effort

Each: measured number, cause, fix, rough effort (S ≤ half a day, M ≤ two days).

### Fix before a 50-player playtest

**R1 Map-tab rebuilds coincide (spike).** 0.9–1.1 ms per build and 65–67 KB per send; with 10 viewers single
steps reached 31–69 ms **[M]**. Cause: each open tab is re-checked every 2 s from the moment it opened, and every
viewer that is due is rebuilt in the same pass (`PLAYER/grug_map/page.lua:369-399`, `REBUILD_US` at `:64`)
**[C]**. Fix: build at most one or two forms per pass (queue the rest), and give each viewer its own phase. Also
consider not resending for an arrow-only change more often than every 4 s (look & feel: the user decides).
**S.**

**R2 Party HUD for all players in one step (spike).** 4.3–7.2 ms/s at 100, single steps 12–28 ms; 
`grug_parties.view` 17–33 µs, called about 230 times a second **[M]**. Cause: every player every 0.5 s in one
pass, with the layout recomputed for every member (`PLAYER/grug_parties/hud.lua:61-109`) **[C]**. Fix: the
quest HUD's five slots (`PLAYER/grug_quests/hud.lua:143-175`) and skip players without a party before calling
`view`; recompute layout only on a window change. **S.**

**R3 Leader and camp tick every 5 s with all players (spike).** At 100 stand-ins in one zone the leader tick
averaged 4.2 ms and reached 24 ms, the camp tick 2.5 ms and 12 ms, in one step every 5 s **[M]**. Cause:
`SR.leader_tick` and `grug_mobs.region_camp_tick` walk every leader spot and camp against every player in one
step (`ENTITIES/grug_mobs/spawn_regions.lua:1082-1087`, `:994`; `camps.lua:965`) **[C]**. Fix: run them in
slices (zones or camps per tick) like the ambient attempts. **S.**

**R4 First-join media (network, operations).** About 13.8 MB per new client; 50 first joins ≈ 690 MB from the
game server **[M]**. Fix: set `remote_media` to an HTTP server holding the media for the playtest (configuration
only) **[S]**; later, check the two dragon models (2.3 MB together) and the 405 KB quiver texture. **S.**

**R5 Server memory (operations, investigation later).** 2.9–3.3 GB resident after the first emerge, of which the
mapgen environment holds 630–745 MiB live and grows with generated chunks **[M]**. Fix now: run the playtest
server with at least 4 GB of RAM (and swap). Later: find out what the mapgen environment keeps (a heap walk in
that environment, as helper C did for the main one) and whether its world-query caches are bounded. **S now,
M later.**

### Later

**R6 Ability input and crosshair every step (steady, largest).** 20–34 ms/s at 100 stand-ins standing or walking
without a key pressed; `input.step` 11–18 µs per call about 11 times a second per player, `crosshair.update`
12–20 µs 6.7 times **[M]**. Cause: `SWING_STEP = 0.05` (`PLAYER/grug_abilities/init.lua:2342`) makes the pass
run every server step; `input.step` reads the wielded item and skill even with no button down
(`input.lua:376-415`), and the crosshair casts the hand ray every 0.15 s (`crosshair.lua:128-166`) **[C]**. Fix:
an early out when no control bit is set and no hold is pending; skip the crosshair while eye and look are
unchanged and the last answer was "nothing". F2 changes `input.lua` in this round; measure after it. **S–M.**

**R7 Minimap glide (steady).** 13–25 ms/s at 100 (11.5–21.6 µs per player-step) **[M]**; cause: every step per
player (`PLAYER/grug_map/minimap.lua:487-505`) **[C]**. Fix: update only players who moved or turned since the
last step; F1 changes this file now. **S–M.**

**R8 Quest-marker memo expires after 1 s.** 16–66 recomputes per second, 106–187 µs each, 2.4–6.5 ms/s at
50–100 **[M]**; cause: `MARKER_MEMO_US = 1000000` exists only for a repeatable's cooldown ending
(`PLAYER/grug_quests/state.lua:217-233`, constant at `:227`) **[C]**. Fix: keep the memo until the raw state changes,
`markers_changed` fires, or the earliest cooldown of that player ends. **S.**

**R9 Quest tracker scans bags every 0.5 s.** 2.1–3.5 ms/s at 100, `journal_key` 10–17 µs per player poll **[M]**;
cause: `holdings` reads every bag list (`state.lua:67-88`, `:336-366`) **[C]**. Fix: recount only after an
inventory change or pickup (the engine has no pickup callback; a cheap list-size and stack-count digest could
replace the full read). **M.**

**R10 Vegetation renewal bursts.** 2.0–6.4 ms/s at 100, single ticks up to 23 ms **[M]**; 10 services per 0.5 s
tick, a wild service 377 µs **[M]** (`ITEMS/grug_farming/renewal.lua:337-354`) **[C]**. Fix: cap the work per
tick by time (about 2 ms) and carry the rest. **S.**

**R11 Discovery scan of every player every 2 s in one step.** 0.47–0.57 ms/s, max 3.8–4.5 ms at 50–100 **[M]**
(`PLAYER/grug_jobs/discovery.lua:73-77`) **[C]**. Fix: slots. **S.**

**R12 Tag carriers in crowded places.** 1.1–3.6 ms/s at 100 with 41–129 carriers, max 2.6 ms per slot **[M]**;
O(carriers × players) per second (`CORE/grug_core/tag_carrier.lua:368`) **[C]**. At the 600-mob cap and 100
players about 12–15 ms/s, spread over eight slots (projection from the measured per-pair cost). Fix if a capital
gets crowded: a coarse spatial bucket of players. **M.**

**R13 Royal and garrison NPC steps.** General 15–61 µs, royal guards and bodyguards 19–31 µs per step, about
3–6 times a villager **[M]**. Only matters with many loaded fortresses or capitals; check what their `do_custom`
does per step when one gets crowded. **M.**

## 7. Checked and fine

PvP tick, gate and tab; the settlement heartbeat; looks, enchant composition and the compose cache; per-faction
map lists and settlement icons; the dragon hazard pass; the crafting index; the region-map and zone-grid caches;
target frame (1.1–3.2 ms/s at 100); status, regen, environment damage, location sampling (2–8 µs per sample),
waypoints, vendors, housing passes (each under 2 ms/s at 100); A* (7 searches in 20 s with 40 blocked chasers);
joins (0.7–1.6 ms per stand-in; equipment, sfinv and the quest HUD the largest parts); leaves (6.4 ms for 100);
no `GSERR`/`ENTERR`/`JOINERR` line in any run **[M]**. (Probe B's leak scan did not run: `debug.getupvalue` is not
available under mod security **[M]**; the heap after the stand-ins left fell back to near idle, §4.3.)

## Appendix A: Evidence

All under `/home/jan/projects/grudgelands-orchestration/r32/r1-evidence/`:
- `probes/grug_perf_probe_b` (B, Round 30 copy plus the `marker_state` guard), `probes/grug_probe_perf_a` (A),
  `probes/zz_perf_c` (C), `probes/grug_probe_r1s` (scale probe; `init_scale1.lua` and `init_scale2.lua` are the
  versions those runs used, `init.lua` the crowd version; `mapgen_heap.lua` the mapgen-environment heap log).
- `patches/` (minetest.conf patches per run), `scripts/run.sh` (semaphore run with boot time, memory timeline and
  per-thread CPU at marks), `scripts/summarize.py` (phase tables).
- `runs/<label>/`: `server*.log`, `run.txt` (boot time, peak memory), `mem.txt` (memory timeline), `cpu.txt`
  (thread CPU at marks), `probe.txt` where extracted. `runs/scale2` and `runs/crowd` hold the logs of the
  earlier boots of the same world as `server.log`/`server.2.log`; their own logs are `server.2.log` and
  `server.3.log`.
- October evidence: `/home/jan/projects/grudgelands-orchestration/r29/perf-evidence/`, Round 30 P1:
  `/home/jan/projects/grudgelands-orchestration/r30/p1-evidence/`.

## Appendix B: Engine runs

Seven measuring runs, all through `r32/engine_run.sh`, seed 12345, each ended by its probe (no timeout kill):

| Label | Start–end | Boot to listening | Peak memory |
|---|---|---|---|
| `b40` (probe B, 40 stand-ins, cold) | 18:25:30–18:27:28 | 38.2 s | 3.05 GB |
| `mobsA` (probe A, cold) | 18:30:47–18:32:44 | 38.3 s | 2.96 GB |
| `scale1` (spread, cold, world kept) | 18:32:09–18:36:10 | 38.6 s | 3.33 GB |
| `schedC` (probe C, cold, info logging) | 18:33:30–18:36:33 | 50.7 s | 2.94 GB |
| `scale2` (spread, later start of `scale1`'s world) | 18:37:12–18:40:03 | 8.0 s | 2.31 GB |
| `crowd` (one start, third start of that world, no mob spawns) | 18:40:49–18:43:33 | 9.1 s | 1.96 GB |
| `crowd2` (one start with mob spawns, cold) | 18:44:11–18:48:02 | 38.5 s | 3.19 GB |

Every run directory was deleted afterwards; no server of this review is running.
