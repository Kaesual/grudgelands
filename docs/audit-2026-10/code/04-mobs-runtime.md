# C4 — Mob runtime

**Scope.** `mods/ENTITIES/mobs/` (7,169 lines: `api.lua` 5,640, `grug_obstacle.lua` 408, `mount.lua` 390,
`crafts.lua` 371, `spawner.lua` 252, the rest small) and the runtime parts of `mods/ENTITIES/grug_mobs/`
(85 files, 25,631 lines in total).

**Baseline.** `main` at `0f169898`. The working tree was clean apart from `docs/audit-2026-10/` for the whole
review.

**Method.**
- **Read in full:** `mobs/api.lua` lines 1–4880 (the class, the movement and environment helpers, `do_states`,
  `smart_mobs`, `on_punch`, staticdata, activation, `on_step` and spawning), `grug_obstacle.lua`, and these
  `grug_mobs` files: `init.lua`, `aggro.lua`, `separation.lua`, `telegraph.lua`, `spawn_abms.lua`,
  `density.lua`, `dawn.lua`, `env_damage.lua`, `idle_health.lua`, `flight.lua`, `swimmer.lua` and
  `roam_avoid.lua`.
- **Read in part:**
  - the runtime half of `spawn_regions.lua` (`:588-1165`) and the region-camp part of `camps.lua`;
  - `levels.lua` (`ensure_init`, stats, tag text) and the code of `patrol.lua`;
  - the runtime verbs in `verbs.lua`, the spawner and watchdog in `rares.lua`, and the dragon alive flag in
    `bosses.lua` and `boss_dragons.lua`;
  - the boss spawn and pass in `rift.lua`, and `rift_spawn.lua`;
  - the `mob_active_limit` notes in `start_npcs.lua`;
  - `mount.lua`'s callbacks.
- **Skimmed:** the rest of `api.lua` (arrows, boom, eggs, capture, protect, taming).
- **Engine claims** were checked against `reference_projects/luanti/src`: `serverenvironment.cpp`, `server.cpp`,
  `l_env.cpp`, `luaentity_sao.cpp`, `unit_sao.cpp` and `builtin/common/serialize.lua`.
- **Upstream** was compared with `reference_projects/mobs_redo/api.lua` (version 20260629, 4,486 lines).
- **One micro-benchmark** (LuaJIT, the builtin `serialize.lua`) measured staticdata size and serialization time.
- No engine runs.

**Out of scope.** Mob content definitions, bosses' and dragons' own AI, traders and projectiles or arrows
(lane C5); the tag-carrier and HP-bar module (`grug_core/tag_carrier.lua`, a CORE lane); the target frame and
crosshair (UI); and the region-map build in `spawn_regions_core.lua`, which runs at boot and is mapgen-like.

## Summary

- **`mobs/` is a hard fork of mobs_redo now, not a vendored copy.**
  - `api.lua` carries 122 `GRUG PATCH` markers.
  - A whitespace-normalized diff against upstream `20260629` is about 1,670 changed lines.
  - The "copy upstream over and re-apply the patches" procedure in VENDOR.md is no longer realistic.
  - Read `api.lua` as our own code. Its long comments are the only record of why each branch exists.
- **A mob's behaviour is spread over four override levels.** An agent has to know all four (MOB-11):
  - **class:** `mob_class.on_deactivate` and `stop_attack` are wrapped in `init.lua`, and `on_deactivate`
    again in `start_npcs.lua`;
  - **prototype:** `do_attack` (`init.lua:963`), and `on_step` plus `flight_check` for swimmers;
  - **instance:** `general_attack`, `update_tag` and `_grug_ignore_player` are installed on every activation;
  - **API functions:** `mobs:spawn`, `mobs.register_spawn_abm`, `mobs:spawn_abm_check` and
    `grug_mobs.settle_mob_death`, which `spawn_regions.lua` wraps again.
- **Per-step cost is concentrated in the attack state.**
  - `do_states` runs every server step for a fighting mob: one target raycast, about 10 small tables and
    2 closures, and a velocity and rotation write.
  - An idle mob does its real work at 4 Hz (node probes) and 1 Hz (environment, acquisition,
    `follow_flop`, leash).
  - A* is bounded globally by `grug_obstacle`, at about 3 ms per server step.
- **Everything on `self` except `self.temp` is serialized into staticdata.**
  - A nested ObjectRef or ItemStack in any instance table crashes the save (`builtin/common/serialize.lua:32`).
  - Only `self.temp` is runtime state.
  - mobs_redo's `mob_staticdata` also **mutates the live mob**. The engine calls it at add time and on
    mid-life re-saves, not only at unload (MOB-05).
- **The most important findings:**
  - Every hit makes the mob retarget the hitter, which bypasses the threat system (MOB-01).
  - `follow_flop` scans all connected players once a second for every idle mob (MOB-02).
  - The `mob_active_limit` removal deletes authored entities on reactivation, and a dragon deleted this way
    never returns (MOB-03).
  - The 2026-09-16 contact-run patch cuts every melee swing animation after one server step (MOB-04).
- **Spawning has three layers.**
  - The region spawner (1 attempt per player per second, density inside 128 nodes) is authoritative on the
    surface.
  - Three merged ABMs serve underground and water rows; `mobs:spawn` rewrites the row numbers before they
    are merged.
  - Camps, leaders and rares have their own timers.
  - Nothing here showed a stall or overspawn risk in normal play beyond what the Round 32 study already
    measured.

## Findings table

| ID | Sev | Category | Title | Location |
|---|---|---|---|---|
| MOB-01 | High | Bug | Every accepted hit retargets the mob to the hitter, overriding threat, hysteresis and the taunt lock | `mods/ENTITIES/mobs/api.lua:3845-3854` |
| MOB-02 | Medium | Perf | `follow_flop` runs for every mob because `follow` is nil, not `""`: O(mobs × players) `get_pos` per second | `mods/ENTITIES/mobs/api.lua:2274-2307` |
| MOB-03 | Medium | Bug | At `mob_active_limit` (600), `mob_activate` permanently deletes reactivating authored mobs; a dragon deleted this way never respawns | `mods/ENTITIES/mobs/api.lua:4003-4006` |
| MOB-04 | High | Bug | Melee swing animation is overwritten one server step after the punch (contact-run patch) | `mods/ENTITIES/mobs/api.lua:2917-2968`, `:3040-3041` |
| MOB-05 | Medium | Bug | `mob_staticdata` mutates the live mob (`attack = nil`, `state = "stand"`) on engine mid-life re-saves: a chasing mob drops its target | `mods/ENTITIES/mobs/api.lua:3947-3978` |
| MOB-06 | Medium | Bug | Server shutdown runs the despawn-distance decision with players already gone: wild mobs activated after the player join are culled on the next start | `mods/ENTITIES/mobs/api.lua:3925-3966` |
| MOB-07 | Medium | Bug | The elite/rare telegraph cone always points at the current target (the mob turns every step during the wind-up), so stepping aside never dodges | `mods/ENTITIES/grug_mobs/telegraph.lua:62-130`, `mobs/api.lua:2853` |
| MOB-08 | Medium | Legacy | The vendored mobs_redo is a hard fork with about 1,000 lines of dead API and live leftover callbacks; the VENDOR.md update procedure no longer applies | `mods/ENTITIES/mobs/`, `VENDOR.md:531` |
| MOB-09 | Medium | Agent-trap | Instance fields persist by default; nested userdata crashes the save; property-named fields bypass `self` on reload | `mods/ENTITIES/mobs/api.lua:3890-3907`, `:3981-4029` |
| MOB-10 | Low | Perf | Each underground or water spawn attempt scans 33³ nodes for a repellent node that does not exist | `mods/ENTITIES/mobs/api.lua:4754-4760` |
| MOB-11 | Medium | Agent-trap | Mob behaviour is layered over class, prototype, instance and API wrappers; the spawn row numbers are rewritten before the merge | `grug_mobs/init.lua:23-44,682-986`, `spawn_policy.lua:459-524`, `spawn_regions.lua:1063` |
| MOB-12 | Low | Perf | Per-step allocations in the attack branch and the node-read wrapper | `mods/ENTITIES/mobs/api.lua:597-603`, `:3032-3052`, `grug_obstacle.lua:345-361` |
| MOB-13 | Low | Perf | O(players²) per second in the region spawner and the camp and leader ticks; two 128-node scans per region spawn | `grug_mobs/spawn_regions.lua:678-691,872`, `mobs/api.lua:4492-4509`, `grug_mobs/density.lua:213` |
| MOB-14 | Low | Agent-trap | Misleading or stale comments: `do_punch` "if false returned", rares' `static_save` note, the explode fuse timer counted twice | `mobs/api.lua:3480`, `grug_mobs/rares.lua:230-245`, `mobs/api.lua:4278`+`:2684` |
| MOB-15 | Low | Perf | Staticdata carries transient runtime state (`path.way`, timers, looked-at nodes): 1.3–2.1 KB per mob | `mods/ENTITIES/mobs/api.lua:3890-3907` |
| MOB-16 | Low | Bug | `mob_pathfinding_enable` cannot be turned off (`get_bool(...) or true`) | `mods/ENTITIES/mobs/api.lua:135` |

## Findings

### MOB-01 Every accepted hit retargets the mob to the hitter, overriding threat
- **Severity** High / **Category** Bug / **Confidence** Verified (traced in code; not run in the engine)
- **Location:** `mods/ENTITIES/mobs/api.lua:3845-3854`; the threat side is `mods/CORE/grug_core/combat.lua:724-797`
  (`check_switch`) and `:933-948` (taunt).
- **What:** the hit is processed in this order:
  1. `on_punch` first runs the accepted-hit hook (`api.lua:3522`), then `run_player_hit_mob`, then
     `add_threat`, then `check_switch`. That correctly keeps the tank as the target behind the 120 %
     hysteresis or the taunt lock.
  2. Further down, upstream's retaliation block runs on every hit that is not cancelled:

     ```lua
     self.state = ""
     self:do_attack(hitter) -- attack whoever punched mob
     ```

  3. Because the state is reset to `""`, `do_attack`'s guard (`state == "attack"` without force,
     `api.lua:308`) does not stop it, so `self.attack` becomes the hitter.
  4. Nothing parks a trailing re-check (`grug_switch_pending` is not set), so the mob stays on the
     DPS player until the tank lands its next unthrottled hit.

  `grug_forced_until` (the taunt lock) is consulted only in `check_switch`, so a DPS hit also breaks a
  taunt.
- **Impact:** every party fight. Combat_stats §4 states "mobs choose targets by **threat**, not proximity".
  In practice the mob faces whoever hit last and flips back on the tank's next hit. Its cadence lands on
  whoever holds the target at that moment, and taunt holds only until the next DPS hit.
- **Better:** in the retaliation block, for a grug mob that already has a live target, do not retarget.
  Two ways:
  - retarget only when `not self.attack`, or when the hitter is not a player;
  - or route the decision through `grug_core`'s `check_switch`, for example `grug_core.recheck_switch`
    with the pending flag set.

  Group alert and the first-hit acquisition stay as they are. Effort S (one `GRUG PATCH` site). Risk: a
  mob-vs-mob or NPC hitter must keep retaliating; add a portable test that hits a tank-held mob with a
  second player and asserts the target holds.
- **Verification (phase 2):** Confirmed — `accepted_player_punch` → `run_player_hit_mob` → `add_threat` → `check_switch` (`grug_mobs/init.lua:315-336`, `grug_core/combat.lua:868-882`) runs before the unpatched upstream tail at `mobs/api.lua:3845-3854`, whose `state = ""` defeats `do_attack`'s guard (`:308`); the grug prototype `do_attack` wrapper (`init.lua:963-968`) only touches boss activity, and nothing on that path sets `grug_switch_pending` or reads `grug_forced_until`. The target is therefore the last accepted hitter (abilities and arrows included), and a taunt lasts only until another player's next hit; High stands.

### MOB-02 `follow_flop` scans every connected player once a second for every mob
- **Severity** High (scaling) / **Category** Perf / **Confidence** Verified
- **Location:** `mods/ENTITIES/mobs/api.lua:2274-2307`, called from `:4297`. `mob_class` (`:191-248`) has no
  `follow` default, and `register_mob` copies `follow = def.follow` (`:4404`). No grug definition sets
  `follow`; a grep of `mods/` finds only `bosses.lua`'s unrelated `temp.grug_royal_follow`.
- **What:** `if (self.follow ~= "" or self.order == "follow") and not self.following ...`. With `follow == nil`
  the condition is true. Every non-attacking mob therefore runs, once a second:
  - `core.get_connected_players()`, which builds a table of all players;
  - `get_pos()` plus a distance test for each player;
  - for a player within `view_range`, a `get_wielded_item()` to learn that `follow_holding` is false;
    `following` is then cleared again in the same call.

  Work residents skip this (their `do_custom` returns `false`, `start_villagers.lua:704-710`). Every combat
  mob, guard and vendor pays it.
- **Impact:** O(idle mobs × players) per second. At the design target (600-mob cap, 100 players) that is
  about 60,000 `get_pos` calls (each allocating a vector table) plus 600 player-list tables per second.
  Estimated at roughly 20–30 ms/s of main thread, and growing quadratically, because mob count follows
  player count. At 20 players and 200 mobs it is about 4,000 calls per second, which is negligible.
- **Better:** treat a nil `follow` like `""`, either with `follow = ""` in `mob_class` or with a guard in
  `follow_flop`. Keep the swimmer flop half, which is needed. Effort S; risk nil for current definitions,
  since none follow. If following is ever wanted, use `grug_core.nearest_tag_player_d2` (the 1 Hz shared
  snapshot) as a pre-filter.
- **Verification (phase 2):** Confirmed, severity changed to Medium — `mob_class` has no `follow` default and no grug def sets one (only `api.lua:4404` copies `def.follow`), so `nil ~= ""` opens the player scan for every non-attacking mob in the 1 s block (`:4297`). The loop stops at the first player inside `view_range` (`:2283-2289`), and by the lane's own estimate the cost is a few percent of one core only at 600 mobs × 100 players and negligible at 20 players: a scaling cost with an S fix, not a High.

### MOB-03 The `mob_active_limit` removal deletes authored mobs on reactivation; a lost dragon never respawns
- **Severity** High (Critical at the 100-player design target) / **Category** Bug / **Confidence** Verified
  for the code path; whether the limit is reached depends on load.
- **Location:**
  - `mods/ENTITIES/mobs/api.lua:4003-4006` (`if at_limit() and not self.tamed then remove_mob(self)`;
    `self.tamed` is read before the staticdata is applied);
  - `minetest.conf` `mob_active_limit = 600`;
  - the dragon alive flag: `grug_mobs/bosses.lua:711-721` and `:768-784`, `boss_dragons.lua:1205-1221`.
- **What:** when 600 mobs_redo entities are active, any reactivating entity is deleted with its static data:
  - `object:remove()` without `static_save = false`;
  - before `after_activate`, so authored data is not re-registered either;
  - NPCs, bosses and `_grug_no_far_despawn` actors are not exempt.

  Every other authored kind recovers:
  - start NPCs, guards and kings through the socket heartbeat (`start_npcs.lua:151`, which itself names
    this removal);
  - rares through the watchdog;
  - leaders and the rift boss, which have `static_save = false` and a live `ObjectRef`;
  - vendors through the presence poll.

  A dragon sets `boss:dragon:<id>:alive = "1"`, and the flag is cleared only in `on_die`. A dragon removed
  this way (or by `/clearobjects`) leaves `alive = "1"`, and the 10 s pass at `bosses.lua:771` never
  spawns it again. Settlement sockets also churn at the cap: `core.add_entity` is followed by an
  immediate removal every 5 s.
- **Impact:** the per-player density budget is 15 to 23 mobs inside 128 nodes, plus camps, NPCs and
  underground rows, so 600 is reachable once players spread out. The Round 30 performance review already
  projected the 600 cap. At that point every wild or camp mob that reactivates vanishes, which is
  upstream's intent. Settlements and capitals near players flicker. A dragon whose island activates while
  the server is at the cap is gone for the life of the world.
- **Better:** exempt authored actors from the activation-time cull, and keep the cull only for spawns
  (`add_mob` already refuses at the limit). The exempt set is `type == "npc"`, `_grug_no_far_despawn`,
  `lifetimer >= 20000` and the boss tier. Also give the dragon pass a self-healing check like the rare
  watchdog: when the lair is loaded and no entity carries the boss id, clear `alive`. Effort S–M; risk low.
- **Verification (phase 2):** Confirmed, severity changed to Medium — `at_limit()` runs before the staticdata is applied (`api.lua:4003-4006`), `remove_mob` is a bare `object:remove()` (`:885-889`), and the engine deletes the static copy of a pending-removal object (`serverenvironment.cpp:1499-1500`), so the loss is permanent. But it needs 600 active mobs, every authored kind except the dragon recovers, a fresh `spawn_dragon` at the cap fails safely (`add_entity` returns nil for an object removed in on_activate, `l_env.cpp:588-589`; `bosses.lua:711-713`), and the dragon's permanent loss is the missing liveness check that MOC-03 rates Medium, so this is kept consistent with it.

### MOB-04 The melee swing animation is cut one server step after the punch
- **Severity** High (visual, every melee fight) / **Category** Bug / **Confidence** Verified (code); not
  observed in the GUI
- **Location:** `mods/ENTITIES/mobs/api.lua:2917-2968` (the in-reach contact run) and `:3040-3041` (the punch);
  `set_animation` is at `:557-589`.
- **What:** upstream's in-reach branch sets no animation except `"punch"`, so the swing loops while the mob
  stands in reach. The 2026-09-16 cadence patch made the in-reach branch call `set_animation("stand")` or
  `"run"` on every step:
  - on a punch step the punch closure sets `"punch"` afterwards, so the engine sends `"punch"` (the last
    write in a step wins, `unit_sao.cpp:40-46`);
  - on the very next step the branch sets `"stand"` again, and `set_animation` lets it through because
    `"punch"` does not contain `"stand"`.

  The swing (for example 15 frames at 30 fps, 0.5 s) is replaced after one dedicated-server step, about
  0.09 s.
- **Impact:** melee mobs deal damage without a readable swing; the attack reads as an invisible hit. It
  also causes extra animation packets around the 0.6 × reach contact line (run and stand toggle).
- **Better:** keep the punch animation for its clip length. For example, store `temp.grug_punch_until`
  when punching and skip the stand or run animation write while it is in the future. Effort S. Check it in
  the GUI on one melee family.
- **Verification (phase 2):** Confirmed — upstream's in-reach branch (`reference_projects/mobs_redo/api.lua:2327-2359`) writes no stand or run animation, while ours writes `"stand"`/`"run"` on every attack step (`api.lua:2938-2967`, and the sidestep at `:2994-3006`); `set_animation` (`:563-565`) skips only when the current name contains the new one, so the `"punch"` written by the punch closure (`:3040`) is replaced on the next step. Nothing in `mods/` overrides `set_animation` or holds a punch lock. High kept as an every-fight readability defect; one GUI look is still advised.

### MOB-05 `mob_staticdata` mutates the live mob on mid-life re-saves
- **Severity** Medium / **Category** Bug / **Confidence** Verified (engine code traced)
- **Location:** `mods/ENTITIES/mobs/api.lua:3968-3971` (upstream lines, unchanged). Engine:
  `serverenvironment.cpp:1676-1688` (re-save while still active) and `:1455` (re-save at add).
  `grug_core/combat.lua:812` already names the symptom.
- **What:** the engine calls `get_staticdata` while the object stays active in two cases:
  - right after `add_entity`;
  - when the object has moved 3 or more mapblocks from its static block, or its static block was
    deactivated while the object is in an active block.

  `mob_staticdata` then writes `self.attack = nil`, `self.following = nil` and `self.state = "stand"` on
  the live entity. It does not call `stop_attack`, so the path state and the grug engagement are not
  reset. For a non-attacking wild mob it can even return the terminal despawn marker while the mob keeps
  living. That marker is overwritten at the real unload, so it is harmless.
- **Impact:** a mob chased or kited about 40 or more nodes, which damage pursuit allows without a distance
  limit, suddenly stops and stands:
  - it re-acquires within a second only if a player is inside its `view_range` with line of sight, and that
    may be a different player;
  - otherwise the chase is lost, and the 15 s damage clock later heals it through `leash_reset`.

  Patrollers and evaders also lose `following` and state.
- **Better:** build the saved table from a copy instead of mutating `self`. Use `clean_staticdata(self)`,
  then set `state = "stand"` in the copy; `attack` and `following` are already excluded as userdata, or
  set them to nil in the copy. Keep `remove_ok = true` as the only write to `self`. Effort S.
- **Verification (phase 2):** Confirmed — `StaticObject`'s constructor calls `getStaticData` (`staticobject.cpp:9-15`), which happens at add (`serverenvironment.cpp:1452-1456`) and on the active re-save (`:1675-1685`: block distance ≥ 3 or the origin block no longer active), and `mob_staticdata` writes `attack = nil`, `following = nil` and `state = "stand"` on the live `self` (`api.lua:3968-3971`) without `stop_attack`. A long chase or kite therefore drops its target; `grug_core/combat.lua:812-813` already names this path, and only the engagement backstop covers it. Medium stands.

### MOB-06 Shutdown culls wild mobs activated after the player joined
- **Severity** Medium / **Category** Bug / **Confidence** Plausible (engine order traced, not run)
- **Location:** `mods/ENTITIES/mobs/api.lua:3925-3966` (`despawn_distance_decision`, `nearest == nil`
  means despawn).
- **What:** at shutdown, `Server::~Server` runs the on_shutdown hooks, kicks the players, then calls
  `deactivateBlocksAndObjects()` (`server.cpp:390-416`). That deactivates every object in ascending id order
  (`activeobjectmgr.cpp:22-31`):
  - the PlayerSAO is deactivated with the rest;
  - after that, `get_connected_players()` no longer returns it (`l_env.cpp:633-638`, `!sao->isGone()`);
  - mobs with a higher id run the despawn decision with no players, so every untamed, non-NPC,
    non-attacking mob with `lifetimer < 20000` gets `_grug_despawn_terminal`.

  Object ids are allocated incrementally (`activeobjectmgr.h:52-63`), so these are typically all mobs
  activated or spawned after the player joined.
- **Impact:** after every restart (single player: every quit), the wild mobs and camp members around the
  player are gone. They refill at the region spawner's rate; camps refill immediately. A mob the player
  was about to fight disappears.
- **Better:** set a flag in `core.register_on_shutdown`, which runs before deactivation, and skip the
  distance cull while it is set. Effort S. Confirm with one headless run: spawn, stop, restart, count.
- **Verification (phase 2):** Confirmed — `Server::~Server` runs on_shutdown, kicks, then `deactivateBlocksAndObjects` (`server.cpp:388-416`), which clears the active-block set and force-deactivates in ascending id order (`serverenvironment.cpp:277-288`; ordered map, `activeobjectmgr.h:70-71`). force_delete bypasses the PlayerSAO's `shouldUnload() == false`, so it is marked gone and `get_connected_players` skips it (`l_env.cpp:636`); later-id eligible mobs then get `nearest == nil` → terminal (`api.lua:3934-3936`). `remove_ok` is already set by the add-time staticdata call, so fresh spawns qualify too, and no mobs-side shutdown flag exists. Medium stands; confidence can be raised to Verified (code).

### MOB-07 The telegraph cone tracks the target, so stepping aside never dodges
- **Severity** Medium / **Category** Bug / **Confidence** Verified (code)
- **Location:** `mods/ENTITIES/grug_mobs/telegraph.lua:62-77` (wind-up = `grug_mobs.root`) and `:84-130`
  (`resolve` uses the facing at resolve time). The turning is at `mods/ENTITIES/mobs/api.lua:2853`.
- **What:**
  - The root only zeroes the walk and run speed (`init.lua:400-410`).
  - The dogfight branch still calls `self:yaw_to_pos(movement_pos)` on every step with no delay, so the
    mob faces its target exactly when the cone resolves.
  - The cone test (`CONE_COS` 45°) therefore always includes the main target if it is within
    `reach + 1.5` and has line of sight.
  - The normal melee cadence also keeps firing during the 2 s wind-up.
- **Impact:** combat_stats §3 advertises "stepping aside is a real dodge". Only backing out of range or
  breaking line of sight works for the targeted player; the cone dodge works only for bystanders.
- **Better:** freeze the facing at wind-up start and skip `yaw_to_pos` while `temp.grug_tg_left` is set.
  Optionally suppress the ordinary punch during the wind-up (open question 2). Effort S.
- **Verification (phase 2):** Confirmed — during the wind-up `grug_mobs.root` (`init.lua:400-410`) only zeroes the speeds and `do_custom` does not return false, so the dogfight branch still calls `yaw_to_pos(movement_pos)` every step (`api.lua:2853`) with no delay, an instant `set_rotation` (`:518-529`), and `resolve` reads that facing (`telegraph.lua:42-45, 96`). The punch closure is not gated on `grug_tg_left` either. The targeted player escapes only by leaving `reach + 1.5` or line of sight; Medium stands.

### MOB-08 The vendored mobs_redo is a hard fork with dead code and live leftover callbacks
- **Severity** Medium / **Category** Legacy / **Confidence** Verified
- **Location:** `mods/ENTITIES/mobs/` and the VENDOR.md row at `VENDOR.md:531`, a single table cell of
  roughly 10,000 characters.
- **What:**
  - 122 `GRUG PATCH` markers in `api.lua` and about 1,670 changed lines against upstream.
  - Dead API: `register_egg`, `capture_mob`, `force_capture`, `feed_tame`, `protect` (its items are curated
    away in `grug_materials/content_curation.lua:106-107`), `breed`, `mobs:boom` and griefing (no
    `pathfinding = 2` mob, no `tnt`), `spawner.lua`, `lucky_block.lua` and the whole `mount.lua` API.
  - `mount.lua` still registers live global callbacks (`:86-105`) on leave, die and shutdown. They detach
    *any* attached player and reset `player_api` state, in parallel with `grug_mounts`' own dismount
    (`grug_mounts/entity.lua:697-718`). On death the mobs callback runs first: it calls `set_detach`,
    `player_api.set_animation("stand")` and resets the eye offset before `grug_mounts.dismount`.
- **Impact:** every agent that edits mob AI wades through upstream code that never runs. Two dismount paths
  exist for one event; it works today by ordering luck. Upstream security or bug fixes can no longer be
  merged mechanically.
- **Better:**
  - Record in VENDOR.md that `mobs/` is a fork with upstream as a reference only, not an update source.
  - Delete the dead features in one clean-up round: eggs, capture, taming, protection, breeding,
    `mount.lua`, `spawner.lua`, `lucky_block.lua`, `boom` and `can_dig_drop`.
  - Replace the VENDOR.md mega-cell with a short list of behavioural deviations.

  Effort M. Risk: removing `mount.lua` changes die and leave ordering. Verify `grug_mounts` alone restores
  the player (eye offset, `player_attached`).
- **Verification (phase 2):** Partly confirmed — the fork status (122 markers; `VENDOR.md:531` is an 11,636-character cell while `:29` and `:567` still describe re-applying patches) and the unused API hold; `mobs:boom` is also unreached in practice, because the Rift Spawn bursts in `burst_due` first. The mount.lua hazard is overstated: only `grug_mounts` attaches players, and its logging `on_player_hpchange` dismount (`grug_mounts/entity.lua:699-704`) runs before any death (`player_sao.cpp:519`; `builtin/game/register.lua:560`), so mobs' `on_dieplayer` finds no attachment. On leave or shutdown, the `grug_mounts` teardown works from its own `active` record (`:162-187`), not the attach state, so the double detach is idempotent rather than "ordering luck". Medium kept for maintainability.

### MOB-09 Instance fields persist by default; nested userdata crashes the save
- **Severity** Medium / **Category** Agent-trap / **Confidence** Verified
- **Location:** `mods/ENTITIES/mobs/api.lua:3890-3907` (`clean_staticdata`) and `:3981-4029` (activation);
  the serializer is `reference_projects/luanti/builtin/common/serialize.lua:17-36`.
- **What:**
  - **What is saved:** `clean_staticdata` saves every top-level `self` field that is not a function or
    userdata, except `temp`, `object`, `_cmi_components` and `_grug_cbox`.
  - **Nested values:** a table field that contains an ObjectRef or ItemStack makes `core.serialize` raise
    "unsupported type: userdata", which crashes on unload, on re-save or at shutdown. A nested function is
    dumped as bytecode, with a deprecation log.
  - **A trap that exists today:** `self.cause_of_death = {puncher = ObjectRef}` (`:963`). It is only safe
    because every `on_die` returns nil, so the mob is removed (`guard.lua:264` documents "MUST return nil").
    A future truthy `on_die` keeps the entity alive with that field, and the server crashes at its next
    unload.
  - **Property-named keys:** a staticdata key named like an object property (`hp_max`, `textures`,
    `collisionbox` and so on, `:3981-3985`) is applied with `set_properties` and **not** restored to
    `self`. That is why `levels.lua` must re-derive `self.hp_max` on the first tick. Code running before
    that tick sees `self.hp_max == nil`; `env_damage.lua:64-70` and `levels.lua:146-150` work around it
    with `get_properties`.
- **Impact:** a future change that stores a reference ("last attacker", "summoner") on `self` instead of in
  `self.temp` crashes the server at the first unload. Fields meant to be runtime-only silently persist
  across restarts.
- **Better:** document the rule in `module-guide.md` ("runtime state lives in `self.temp`; `self` fields
  persist; never nest userdata"). Make `clean_staticdata` drop or `pcall`-guard non-serializable nested
  values and log once instead of crashing. Clear `cause_of_death` after `item_drop`. Effort S.
- **Verification (phase 2):** Confirmed — `clean_staticdata` (`api.lua:3890-3907`) keeps every top-level field that is not a function or userdata, nested userdata makes `count_objects` raise (`builtin/common/serialize.lua:30-31`), and `cause_of_death` holds the puncher's ObjectRef (`:963`). The only keep-alive branches are a truthy `on_die` (`:988`, none today) and `death_anim`, which is safe because it sets `static_save = false` (`:907-910`), so the engine never asks it for staticdata. The property-key drop (`:3981-4022`) is real and documented in `levels.lua:424-433`; Medium stands.

### MOB-10 A 33³ repellent scan per underground or water spawn attempt
- **Severity** Low / **Category** Perf / **Confidence** Verified (code); cost estimated
- **Location:** `mods/ENTITIES/mobs/api.lua:4754-4760`.
- **What:**
  - `spawn_action` calls `core.find_nodes_in_area` over ±16 nodes (35,937 nodes) for
    `mobs:mob_repellent`.
  - That node is never registered: `crafts.lua` has no registration and it is listed for curation.
  - The engine has no early exit for an empty filter; `forEachNodeInArea` visits every node
    (`l_env.cpp:893-921`).
  - The scan runs on every merged-ABM row action that passes the player-presence check.
- **Impact:** tens of µs of wasted C++ per spawn attempt near players (estimate). The Round 29 probe could
  not see it: without players `count_mobs` returns earlier.
- **Better:** delete the check. Effort S.

### MOB-11 Behaviour is layered over class, prototype, instance and API wrappers
- **Severity** Medium / **Category** Agent-trap / **Confidence** Verified
- **Location:**
  - `grug_mobs/init.lua:23-44` (class wrappers), `:682-986` (the per-registration wrappers: `do_punch`,
    `after_activate` twice, flight nudge, `do_custom`, prototype `do_attack`);
  - `aggro.lua:93-98` (instance `general_attack`), `levels.lua:503-511` (instance `update_tag`);
  - `swimmer.lua:207-221` (prototype `on_step` and `flight_check`);
  - `spawn_policy.lua:459-524` (`mobs:spawn` rewrites `chance` ÷1.3, the cap ×1.3 and the night cap ×1.25),
    `spawn_abms.lua` (retires or merges rows), `init.lua:366` (`spawn_abm_check`);
  - `spawn_regions.lua:1063` (re-wraps `settle_mob_death`); `start_npcs.lua:1018` (re-wraps
    `on_deactivate`).
- **What:**
  - A mob's effective behaviour is the composition of these layers.
  - Load order decides who wraps whom (`init.lua:988-1105`).
  - Some layers depend on `do_custom` running before `general_attack` or `do_states` in the same step.
  - The numbers in a `mobs:spawn{...}` call are not the effective spawn rate.
  - `do_custom` returning exactly `false` skips the rest of the step, including do_states and the 1 Hz
    block.
- **Impact:** edits such as adding a `do_custom`, changing a spawn row or replacing `update_tag` behave
  unexpectedly. This is the main source of "it worked in the fixture, not in the game".
- **Better:** a one-page "mob call graph" in `module-guide.md`: one `on_step` in order, each wrapper layer
  with its file and line, the `do_custom`, `do_punch` and `custom_attack` return-value contracts, and the
  effective spawn-rate pipeline. Effort S.
- **Verification (phase 2):** Confirmed — spot-checked: the class wrappers at `init.lua:23-44`, the `on_deactivate` re-wrap at `start_npcs.lua:1016-1022` and the `settle_mob_death` re-wrap at `spawn_regions.lua:1062-1063`; `spawn_policy.lua:476-481` divides chance by 1.3 and multiplies the cap by 1.3, inside the `mobs:spawn` wrapper at `:512-513`; the prototype `do_attack` is at `init.lua:963-968`; and `do_custom == false` returns before `do_states` and the 1 s block (`api.lua:4276`). The Medium agent-trap stands.

### MOB-12 Per-step allocations in the attack branch and the node reads
- **Severity** Low / **Category** Perf / **Confidence** Verified (code); cost not measured
- **Location:**
  - `mods/ENTITIES/mobs/api.lua:597-603`: the `get_node` wrapper builds a table per read, which is about
    7 tables every 0.25 s per mob for `get_nodes` and `is_at_cliff`;
  - `:3032-3052`: `try_melee_attack` gets an args table and 2 closures on every attack step;
  - `:1858`: `path.lastpos` is a new table every chase step;
  - `grug_obstacle.lua:345-361`: `target_visible` copies 2 positions every step.
- **What:** about 10 to 15 small tables or closures per fighting mob per step, and about 28 tables per
  second per idle mob.
- **Impact:** GC pressure. The Round 30 change to `get_properties` showed that garbage of this kind shows
  up in p99. At the 600 cap this is about 1–2 MB/s, much less than the 7.8 MB/s fixed in Round 30.
- **Better:** read content ids with `core.get_node_raw` plus a cached id-to-def table; pass booleans
  instead of the args table and closures in the punch gate; reuse `lastpos` in place. Effort S each. Only
  worth it together with a probe before and after (AGENTS.md "Performance").

### MOB-13 O(players²) in the region spawner; two 128-node scans per spawn
- **Severity** Low / **Category** Perf / **Confidence** Verified
- **Location:**
  - `grug_mobs/spawn_regions.lua:678-691` (`players_clear`, `get_pos` per player) is called per attempt
    (`:872`), and each player makes one attempt per second;
  - `player_near_xz` per camp and leader per player every 5 s (`:1017-1029`, `camps.lua:972`);
  - `mobs/api.lua:4492-4509` (`count_mobs`, radius 128, inside `add_mob`) plus `density.lua:213` (radius
    128) on the same spawn.
- **What:** 100 players make about 10,000 `get_pos` calls per second for the spawner alone. Each successful
  spawn makes two full 128-node radius scans over all objects, tag carriers included.
- **Impact:** a few ms per second at 100 players; small today.
- **Better:** use the 1 Hz snapshot `grug_core.nearest_tag_player_d2` (it already exists, at
  `tag_carrier.lua:453`) for the "player near" and "player clear" tests, and pass the density scan's
  player-presence result to `add_mob` (or call `core.add_entity` plus the ground lift directly). Effort S.

### MOB-14 Misleading or stale comments that steer agents wrong
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified
- **Location:**
  - **`do_punch` comment.** `mods/ENTITIES/mobs/api.lua:3480` says "if false returned, do not continue".
    The code `not self:do_punch(...) == false` cancels on a **truthy** return. `module-guide.md:239`
    documents this, but the comment at the site says the opposite.
  - **Rares' `static_save` note.** `grug_mobs/rares.lua:230-245` describes `mob_activate` clearing
    `static_save` for untamed monsters. That code no longer exists, and the
    `set_properties({static_save = true})` it justifies is redundant.
  - **Explode fuse timer.** In the explode state `self.timer` advances twice per step: once in `on_step`
    (`api.lua:4278`) and once in `do_states` (`:2684`). `explosion_timer` is therefore about half real
    time. `rift_spawn.lua:44-46` compensates; any new exploder would not.
- **Better:** fix the comments, and note the fuse timer in the module guide. Effort S.

### MOB-15 Staticdata carries transient runtime state
- **Severity** Low / **Category** Perf / **Confidence** Verified
- **Location:** `mods/ENTITIES/mobs/api.lua:3890-3907`.
- **What:** the saved data includes `path.way` (up to 60 positions), `path.lastpos`, every timer,
  `looking_at`, `standing_on`, `animation_current`, `target_yaw`, and three copies of the texture list
  (`textures`, `base_texture`, `_grug_base_texture`). Measured with the builtin serializer under LuaJIT on
  a representative 18-slot atlas mob: **1,335 bytes and 13 µs**, or **2,141 bytes and 31 µs** with a
  40-waypoint path.
- **Impact:** map-database size and per-unload or re-save cost; small.
- **Better:** drop `path`, the timers and the probe results in `clean_staticdata` (an exclusion set).
  Effort S.

### MOB-16 `mob_pathfinding_enable` cannot be disabled
- **Severity** Low / **Category** Bug (upstream) / **Confidence** Verified
- **Location:** `mods/ENTITIES/mobs/api.lua:135` — `settings:get_bool("mob_pathfinding_enable") or true`.
- **Impact:** a debugging or performance switch that silently does nothing.
- **Better:** `~= false`. Effort S.

## Hot-path inventory

Cost classes: **N** negligible (field tests), **S** small (a few engine calls), **M** medium (a radius scan
or raycast), **L** large (A* or volume scans).

| Path | Frequency | Cost class | Notes |
|---|---|---|---|
| `on_step` core (`api.lua:4189-4307`) | per mob per step | S | `get_pos`; `falling()`: `get_velocity`, 2× `get_pos` when `v.y == 0`, `set_acceleration` **every step**; smooth-turn `get_rotation`/`set_rotation` while `delay > 0`. Round 32 measured 15–20 µs per start-zone mob step and 4–60 µs per NPC (perf-review-r32). |
| `get_nodes` + `is_at_cliff` + `do_jump` | per mob, 4 Hz | S | about 7 node reads, each allocating a table (MOB-12); cliff probe up to 3 nodes. Fine. |
| grug `do_custom` chain (`init.lua:846-949`) | per mob per step | N | `ensure_init`, `apply_aggro_fields`, `tick_speed_effects`, `leash_tick` (accumulator), `dawn_tick`, flight nudge, verb accumulators; telegraph for elite and rare. Faction mobs in combat: `get_object_faction` reads player meta every step (S). |
| `do_env_damage` → `update_tag` | per mob, 1 Hz | S | `tag_text` string build; writes only on change. A light query for sun-sensitive mobs. Fine. |
| `general_attack` | per non-attacking, non-passive mob, 1 Hz | M | `get_objects_inside_radius(view_range)`, which includes tag carriers, plus one LOS raycast per viable candidate. Fine. |
| **`follow_flop`** | per non-attacking mob, 1 Hz | **M × players** | MOB-02: O(players) `get_pos` for every mob. |
| `do_states` stand or walk | per idle mob, 1 Hz | N–S | 25 % chance of a radius-3 scan in stand. |
| `leash_tick` 1 Hz body (`aggro.lua:689-733`) | per mob, 1 Hz | N–S | roam cap, evade nudge, idle health, `prune_engagement`; `roam_avoid_tick` every 4–5 s for aggressive free roamers (8 probes). |
| `do_states` attack (`api.lua:2541-3106`) | per fighting mob per step | M | 3× target `get_pos`, `get_hp`, one target raycast (`grug_obstacle.target_visible`), `yaw_to_pos` + `set_rotation`, `set_velocity`, animation, about 10 tables and 2 closures. |
| `smart_mobs` / `core.find_path` | per chasing mob; A* gated | L, bounded | Global budget about 3 ms per step (`grug_obstacle.lua:11`); negative cache 1/2/4/8 s; give-up after 3 failures. Fine since Round 30. |
| `separation_step` | per ground-melee fighting mob, 1 Hz | S | radius ≈ 2 scan plus `box_fits_at`. Fine. |
| `on_punch` | per accepted hit | M | 2× `get_properties` (feedback, `check_for_death`), a blood spawner of 5–10 particles, a group-alert radius scan around the hitter, `check_switch`. Fine; see MOB-01 for the logic. |
| Region spawner attempt (`spawn_regions.lua:836-895`) | per player, 1 Hz (4 slices) | M | `find_nodes_in_area_under_air` (97 nodes × 21 names), O(players) clear test (MOB-13), 17 drift probes, a 128-radius density scan, `can_spawn`, a 128-radius scan in `add_mob`. Measured at 22–32 µs per attempt in Round 32. |
| Camp and leader tick | every 5 s in 20 zone slices | M | Radius scans per camp near a player; the first fill can place a whole camp in one step (max 12 ms measured in Round 32). |
| Merged spawn ABMs (`spawn_abms.lua`) | engine ABM cadence | M (+L) | 3 ABMs; the row action does a 128-radius `count_mobs` plus a **33³ repellent scan** (MOB-10). |
| `grug_obstacle.begin_server_step` | per server step | N | Path queue grants. |
| Rares pass | every 10 s | M | radius-100 scan per route point, only when a player is near the route. |
| Dragon and rift passes | every 10 s / 1 s | N–S | Fine. |
| `mob_staticdata` | per unload, re-save and add | S | O(players) despawn decision, 13–31 µs serialization (MOB-15). |
| `mob_activate` | per activation | S–M | about 5–8 `set_properties`, deserialization, carrier creation (`add_entity` + attach), visuals. |
| Particles | per hit and per event | — | blood 5–10 per hit, environment 3–15 per second per affected mob, telegraph 24, dawn 15. Within the "hundreds" budget. |
| Network | per fighting mob | — | `set_velocity` and `set_rotation` every step; the engine sends position only past its thresholds (`luaentity_sao.cpp:226-240`). Animation churn at the contact line (MOB-04). |

Cross-lane note: every mob has a tag-carrier child (and an HP-bar child while it is damaged). Every
`get_objects_inside_radius` in this lane therefore returns about 2× the objects and calls `get_luaentity` on
them.

## Bug-prone areas

- **`api.lua` `do_states` attack branch (`:2541-3106`)** — about 560 lines with about 25 patch sites. Three
  movement owners (path follow, contact run, sidestep), the cadence and the LOS gates interleave. The
  punch animation regression (MOB-04) came from here.
- **`api.lua` `on_punch` (`:3197-3886`)** — about 690 lines interleaving the WP38 native-swing transaction,
  the accumulator, wear, feedback, retaliation and group alert. Its order is load-bearing: preview, then
  `do_punch`, then CMI, then commit, then the accepted hook, then subtract, then retaliate (MOB-01).
- **Staticdata and the lifecycle** — the engine calls `get_staticdata` at add, on mid-life re-saves and at
  shutdown, not only at unload (MOB-05, MOB-06). Instance fields persist by default (MOB-09).
- **Authored-entity persistence** — each authored kind has its own "is it alive" bookkeeping: socket
  markers, the rare watchdog, leader and rift `ObjectRef`s, vendor presence, the dragon storage flag.
  Every removal path that bypasses `on_die` (the active limit, `/clearobjects`, a shutdown race) needs its
  own recovery. The dragon has none (MOB-03).
- **Speed ownership** — `walk_velocity` and `run_velocity` are written by root, slow, stun, evade and
  restore in `tick_speed_effects`, and are persisted. Any new writer breaks the single-owner rule
  documented in `init.lua:445-468`.
- **The `do_custom` return contract** — `false` skips the whole remaining step, including acquisition and
  1 Hz states; `nil` continues. Chained verbs (`verbs.lua:49-64`) depend on it.

## Noted (no action)

- `damage_aura` (Bog Ooze) punches nearby players with no evade or PvP gate (`verbs.lua:559-588`); the
  punch path itself applies PvP and dodge.
- The evade's 40 s teleport fallback (`aggro.lua:358-369`) moves the mob even in sight of players, unlike
  the patrol snap, which checks `unwatched`.
- `mobs_griefing` is on by default, but no shipped mob uses `replace` or `pathfinding = 2`. Turning it off
  in `minetest.conf` would be defence in depth for the terrain guard.
- `smart_mobs`, then `apply_path`, then `do_attack` re-enters on every path search (`state = ""`) and
  re-rolls the war cry. The `grug_sounds` per-mob interval (8–10 s) hides it.
- A pending A* request holds the mob's `temp` in the FIFO until it is granted or invalidated; cancellation
  covers death and unload (`grug_obstacle.lua:80-124`).

## Open questions for Jan

1. MOB-01: should a hit by a second player ever pull a mob away from the threat leader, for example when
   the mob has no threat entry yet, or only through threat (§4 as written)?
2. MOB-07: during an elite's 2 s wind-up, should its normal melee swings continue, or should it only wind
   up ("stop", as combat_stats §3 says)?
3. MOB-03: is `mob_active_limit = 600` still the wanted cap, given that the per-player density budget
   makes it reachable with about 25–40 spread-out players? Should authored actors simply not count?
4. MOB-06: is "wild mobs near you are gone after a restart" acceptable, or should a restart keep the
   world's mobs?
