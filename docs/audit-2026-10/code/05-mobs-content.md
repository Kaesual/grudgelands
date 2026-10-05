# C5 — Mob content, bosses, traders, projectiles

**Scope.** `mods/ENTITIES/grug_mobs/` content side (about 25.6k lines in 80
files; the per-family definitions, `bosses.lua` 785, `boss_dragons.lua` 1287,
`dragon_arena.lua` 157, `rift.lua` 506, `rift_core.lua` 176,
`rift_spawn.lua` 120, `rares.lua` 652, `camps.lua` 1011, `kraken.lua` 174,
`telegraph.lua` 200, `verbs.lua` 831, `levels.lua` 579, `subtypes.lua` 573,
`items.lua` 126, `guard.lua` 338, the royal parts of `start_npcs.lua` and
`capital_displays.lua`, `data/*.json`), `mods/ENTITIES/grug_traders/`
(2959 lines in 8 files) and `mods/ENTITIES/grug_projectiles/init.lua` (423
lines). Shared helpers read where the content depends on them:
`grug_core/homing.lua`, `grug_core/protection.lua`, the explosion and arrow
paths of `mobs/api.lua`.

**Baseline.** `0f169898` (main). The working tree did not change under this
review (only `docs/audit-2026-10/` is untracked).

**Method.** Read fully: `bosses.lua`, `boss_dragons.lua`, `dragon_arena.lua`,
`rift.lua`, `rift_spawn.lua`, `rares.lua` (code), `telegraph.lua`,
`verbs.lua`, `levels.lua` (code), `kraken.lua`, `init.lua` (grug_mobs), all of
`grug_traders` except the comment blocks of `price_rules.lua`, and
`grug_projectiles/init.lua`. Read in part: `camps.lua`, `start_npcs.lua`
(royal slots, heartbeat, scan), `subtypes.lua` (drops, validation),
`guard.lua` (tick), `night_families.lua`, `oerkki.lua`, `wolf.lua`,
`skeleton_raider.lua`, `capital_displays.lua`, `start_villagers.lua` (ticks).
Skimmed the remaining family files for custom hooks (grep for `do_custom`,
verbs, `set_node`, `core.after`, `core.sound_play`, `drops`). A script
cross-checked every literal item name in the drop lists and shelves against
the registrations (literal, registry-built and JSON-declared names). No engine
runs. No micro-benchmarks: every hot cost found here is an engine call
(`get_properties`, `set_properties`, radius scans), which an isolated LuaJIT
run cannot measure; the cost classes are reasoned.

**Out of scope** (lane C4): the generic mob runtime (the `do_custom` wrapper
chain in `init.lua`, `aggro.lua` leash and evade, spawning, `spawn_regions*`,
pathfinding, staticdata). Where a content finding depends on it, the overlap
is named.

## Summary

- **Bosses are three different lifecycles.** Dragons persist through a
  mod-storage `alive` flag plus a persistent entity (`bosses.lua:707-785`,
  `boss_dragons.lua:1205-1221`); Kings and Generals are settlement sockets of
  `start_npcs.lua` with a persisted per-slot `due`; the rift boss is a
  `static_save = false` entity tracked by one Lua ref (`rift.lua:221-228`).
  The reward ledger (`bosses.lua:14-130`) is in memory only, which is fine
  because a restart also ends every fight.
- **Self-healing differs by lifecycle, and that is the fragile part.** The
  start-NPC sockets free a lost holder after strikes; the rares have a
  watchdog; the dragon flag has no liveness check at all (MOC-03), and the
  rare watchdog over-fires (MOC-01).
- **Every mob projectile homes.** `grug_mobs.register_homing_arrow`
  (`verbs.lua:594-627`) replaces mobs_redo's arrow `on_step` with
  `grug_core.homing_step`: an arrow never misses once launched, and the
  mobs_redo arrow fields `hit_node`, `lifetime`, `drop` and `rotate` are
  dead. Spread volleys converge (MOC-04).
- **Terrain safety of explosions is implicit.** Mob explosions never touch
  nodes only because `core.is_protected(pos, "")` is always true
  (`grug_core/protection.lua:69-71`), which sends `mobs:boom` to
  `safe_boom`. The dragon ground effects are the one runtime node writer in
  this area besides the rift crack, and they erase what they replace
  (MOC-05).
- **The trade path is solid.** Every trader action re-validates the session,
  distance and faction, recomputes prices server-side, checks the index
  against the rendered snapshot, takes money atomically and refunds on a full
  inventory (`trade.lua:342-477`); the Crownbinder pays through
  `grug_money.take_with_inventory` with expected stacks (`crown.lua:108-141`).
  I found no duplication, negative-count or field-trust exploit.
- **Drops: two sources of truth.** `data/drops.json` band tables replace a
  family's Lua `drops` when they have rows for the mob's band
  (`subtypes.lua:354-372`, `aggro.lua:826`); unknown items in drops.json fail
  the load (`subtypes.lua:560-572`). Every literal item named in the Lua drop
  lists and shelves resolves to a registered item (script cross-check).
- **Per-step content hooks are cheap.** All verbs are 1 Hz throttled. The
  per-step work sits in the dragon tick, the King cast tick, the telegraph
  counter and projectile homing. See the hot-path inventory.
- **Agent traps:** mobs_redo copies only whitelisted def fields; `_grug_*`
  def fields reach the entity only through the wrappers (documented at length
  in the files). Two clocks share one `due` field in `start_npcs.lua:1459`,
  told apart by magnitude. Raw `core.sound_play` and explicit mob `sounds`
  bypass the approval gate (MOC-07).

## Findings table

| ID | Sev | Category | Title | Location |
|---|---|---|---|---|
| MOC-01 | High | Bug | Rare watchdog spawns duplicate named rares after a few hours without visitors | `grug_mobs/rares.lua:290-305` |
| MOC-02 | Medium | Bug | Undead King's Bone Call: unbounded, factionless summons that survive the encounter reset | `grug_mobs/bosses.lua:402-409` |
| MOC-03 | Medium | Bug | Dragon `alive` flag has no liveness check: a dragon removed without `on_die` never returns | `grug_mobs/bosses.lua:764-785` |
| MOC-04 | Medium | Bug | Breath fan and King volley: all three projectiles home onto one target; breath `hit_node` is dead | `grug_mobs/boss_dragons.lua:569-602` |
| MOC-05 | Medium | Bug | Dragon rime/scorch replace buildable_to nodes (snow, grass, water) and turn them into air | `grug_mobs/boss_dragons.lua:173-276` |
| MOC-06 | Medium | Bug | Royal guards killed without a King reset stay down until the King resets or dies | `grug_mobs/start_npcs.lua:1701-1722` |
| MOC-07 | Medium | Bug | Unapproved sounds outside `grug_sounds`: dragon return warning, Rift Spawn fuse and burst | `grug_mobs/bosses.lua:750`, `rift_spawn.lua:69-86` |
| MOC-08 | Low | Perf | Enraged dragon re-sends its full object properties every server step | `grug_mobs/boss_dragons.lua:1013` |
| MOC-09 | Low | Perf | Royal guards find their King with a radius-80 object scan every second | `grug_mobs/bosses.lua:365-372, 568` |
| MOC-10 | Low | Perf | Projectile homing calls `get_properties()` per projectile per step | `grug_core/homing.lua:24-30, 66` |
| MOC-11 | Low | Perf | start-NPC heartbeat scans every settlement row in one step | `grug_mobs/start_npcs.lua:1600-1617` |
| MOC-12 | Low | Bug / Duplication | Oerkki and Wisp blink through walls and into claims; the blink is copy-pasted | `grug_mobs/oerkki.lua:34-58` |
| MOC-13 | Low | Agent-trap | Explosion terrain safety rests on `is_protected(pos, "")`; mobs_redo promotes radius 0 to 1 | `mobs/api.lua:2705-2714, 5039-5065` |
| MOC-14 | Low | Agent-trap | Homing mob arrows silently ignore `hit_node`, `lifetime`, `drop` | `grug_mobs/verbs.lua:594-627` |
| MOC-15 | Low | Agent-trap | Lua `drops` shadowed by drops.json in 7 families; `FUNCTION_DROPS` lists 1 of 3 drop functions | `grug_traders/init.lua:44-50` |
| MOC-16 | Low | Legacy | Vendor capital-offset fallback and its globalstep; stale "serves everybody" comment | `grug_traders/vendors.lua:414, 528-703` |
| MOC-17 | Low | Legacy | Inert camp fires in recipe zones keep their 30 s timer; `place_camp` is unused | `grug_mobs/camps.lua` camp_tick, `:758` |
| MOC-18 | Low | Bug | Queued boss loot only arrives at the next join | `grug_mobs/bosses.lua:145-195` |
| MOC-19 | Low | Legacy | `grug_projectiles` dead fields: `_grug_travelled` stays 0, `_grug_max_distance` unread | `grug_projectiles/init.lua:334-381` |
| MOC-20 | Low | Bug | Potion refusals go to chat, not the message feed | `grug_traders/potion.lua:93-103` |

## Findings

### MOC-01 Rare watchdog spawns duplicate named rares after a few hours without visitors
- **Severity** High / **Category** Bug / **Confidence** Verified (logic); the
  frequency is Plausible
- **Location:** `mods/ENTITIES/grug_mobs/rares.lua:290-305` (watch),
  `:132-143` (`find_existing`), `:53-57` (`save`), `:180-200` (`try_spawn`)
- **What:** `rare_watch` releases a respawn when
  `now - max(spawned_at, seen_at) > respawn_max` (2–4 h) and the scan finds
  nothing. The comment above it promises the respawn waits "a full
  respawn_max ... WITHOUT a sighting despite players being around", but the
  code counts all elapsed time, including the hours nobody was near. `seen_at`
  is also runtime-only, so after a restart the age is measured from
  `spawned_at`, which can be days old. `find_existing` is
  `get_objects_inside_radius(route point, 100)`, which only sees **active**
  objects. A player counts as near at 120 nodes horizontally (`PLAYER_RANGE`)
  from any of the three route points, which can be up to 80 nodes from the
  anchor. Activation reaches only about 64–80 nodes (`active_block_range` 4).
  The rare itself is never culled (`lifetimer = 30000`, `static_save = true`).
  On the first 10 s pass in which a player is inside the 120-node band but
  the rare's block is still inactive, the rare is declared lost. On the next
  pass, `try_spawn` adds a second one near the player if the first is still
  out of range.
- **Impact:** On any server where a route goes unvisited for more than 4 h
  (or after any restart once 4 h have passed since the spawn), the next
  visitor can meet two "Grimtusk"s. The broadcast fires again, loot doubles,
  and each repeat adds one more, because a kill only flips `alive` while the
  survivor keeps standing.
- **Better:** Persist the rare's last known position (a plain field mirrored
  in storage on unload, or `seen_at` plus position written at most once a
  minute). Release the respawn only when `core.compare_block_status(last_pos,
  "active")` is true and the scan still misses, or count "absent" time only
  in passes where that block is active. Effort S. Overlaps C4 (spawning); no
  dependencies.
- **Verification (phase 2):** Confirmed — `rares.lua:290-305` ages the rare by game time (`core.get_gametime()`, which runs with nobody near), `seen_at` is runtime-only (`:48-50`), and `find_existing` (`:132-143`) sees only active objects while `PLAYER_RANGE` 120 (`:28`) far exceeds the default active_block_range (no override in `minetest.conf`); the rare even patrols between route points up to about 160 nodes apart (`zone_authority.lua:282`, `rares.lua:346-351`), so a visitor at one point routinely leaves it unseen at another. Nothing dedupes on activation (no other `_grug_rare_id` consumer does), and `try_spawn` (`:191`) only adopts what the same blind scan finds; High stands.

### MOC-02 Undead King's Bone Call: unbounded, factionless summons that survive the encounter reset
- **Severity** High / **Category** Bug / **Confidence** Verified
- **Location:** `mods/ENTITIES/grug_mobs/bosses.lua:402-409` (summon),
  `:437-456` (cast every 2 s + 8 s cooldown), `:505-515` (removal only in
  `on_die`, radius 80); `start_npcs.lua:1724-1742` (`royal_encounter_reset`
  never touches summons); `skeleton_raider.lua:14-33` (no `_grug_faction`,
  `attack_players = true`)
- **What:** While the Undead King has a target, every signature cast
  (about every 10 s) `core.add_entity`s two `grug_mobs:skeleton_raider` with
  `_grug_royal_summon` set. There is no cap and no count check (compare
  `spawn_whelps`, `boss_dragons.lua:678-695`, which tops up to 2). The
  summons are exempt from leash, wander radius and dawn (`aggro.lua:19, 592`,
  `dawn.lua:43`), carry no faction, so they target **any** player, including
  the King's own Throng in Nhal Veyr, and their level comes from the
  capital's field (`levels.lua` `resolve_level`), not from the encounter. The
  encounter reset (evade start, `bosses.lua:429-433`) restores the guards but
  leaves every summon standing; only the King's death removes them, and only
  within 80 nodes.
- **Impact:** A 3-minute fight leaves about 36 raiders in the throne hall.
  After a failed attempt they stay hostile to every player in the undead
  capital until killed, or until the far-cull clears them once players leave.
  Throng players in their own capital get shot by their own King's adds.
- **Better:** Cap live summons per encounter (count them like
  `spawn_whelps`, at most 2–4), give them the King's `_grug_faction` (or a
  target veto against the King's faction), fix their level
  (`_grug_spawn_level` near the King's), and remove them in
  `royal_encounter_reset` with the same scan the King's `on_die` uses.
  Effort S. Risk: none beyond the encounter tuning.
- **Verification (phase 2):** Confirmed, severity changed to Medium — uncapped two-per-cast summons (`bosses.lua:402-409`, cast every ~10 s via `:437-456`), no `_grug_faction` on the raider (`skeleton_raider.lua:14-33`), and `royal_encounter_reset` (`start_npcs.lua:1724-1742`) never touches `_grug_royal_summon` (only the King's `on_die`, `bosses.lua:505-515`, removes them). The impact is overstated: royal and city guards are `attack_monsters = true` (`guard.lua:193`, reused for royal guards at `bosses.lua:615`), so the restored retinue engages leftover raiders after a reset, and the "36 raiders" figure assumes nobody kills any.

### MOC-03 Dragon `alive` flag has no liveness check: a dragon removed without `on_die` never returns
- **Severity** Medium / **Category** Bug / **Confidence** Verified (code
  paths); triggers are uncommon
- **Location:** `mods/ENTITIES/grug_mobs/bosses.lua:707-723, 764-785`;
  `boss_dragons.lua:1205-1221`; `mobs/api.lua:4003-4006` (activation at the
  active-mob limit), `:5508-5541` (`/clear_mobs`), `minetest.conf:45`
  (`mob_active_limit = 600`)
- **What:** The respawn loop runs only while
  `storage "boss:dragon:<id>:alive" ~= "1"`; `after_activate` sets it to `1`
  and only `on_die` clears it. Every removal that skips `on_die` leaves `1`
  forever:
  - `mob_activate` removes any untamed mob when `at_limit()`. The game ships
    `mob_active_limit = 600`, and the counter includes every active NPC.
  - `/clear_mobs` (`remove_mob` is a plain `object:remove()`).
  - A crash after mod storage flushed `alive = 1` but before the map block
    with the new dragon was saved.

  The `_grug_no_far_despawn` patch (`api.lua:3950-3956`) closed one such
  path; the others remain. Rares (`rares.lua:290`) and settlement NPCs
  (`start_npcs.lua` strikes) have a liveness fallback; dragons do not.
- **Impact:** A world boss permanently gone, fixable only by editing mod
  storage. It is rare in normal play, but the limit path gets likelier with
  many players online.
- **Better:** Add the rare-style watchdog: when the lair block is **active**
  (`core.compare_block_status(pos, "active")`), the flag says alive, and
  no `ent._grug_boss_id == "dragon:<id>"` stands within the arena radius for
  N passes, clear the flag and schedule the normal warned respawn. Also
  consider exempting `_grug_no_far_despawn` / `_grug_boss_id` mobs from the
  `at_limit` activation removal (a GRUG PATCH in C4's area). Effort S.
- **Verification (phase 2):** Confirmed — the flag is set in `after_activate` (`boss_dragons.lua:1205-1208`) and cleared only in `on_die` (`:1216-1220`); the 10 s loop (`bosses.lua:764-785`) never checks for a live entity, and `mob_activate` (`mobs/api.lua:4003-4006`) removes any untamed mob at the 600 limit through a plain `object:remove()` (`:885-889`) with no `on_die`. A fresh `spawn_dragon` hitting the limit fails safely (no entity, so the flag is not written, `bosses.lua:711-713`); only reactivation of the stored dragon and the admin-only `/clear_mobs` (radius 28) strand it. Medium fits.

### MOC-04 Breath fan and King volley: all three projectiles home onto one target; breath `hit_node` is dead
- **Severity** Medium / **Category** Bug / **Confidence** Verified
  (mechanics); intent is an open question
- **Location:** `mods/ENTITIES/grug_mobs/boss_dragons.lua:569-602`
  (`shoot_breath`, angles −15°/0°/+15°), `:384-395` (`projectile_hit`,
  `projectile_node`), `:418-435`; `bosses.lua:286-310, 398-401` (volley at
  −0.16/0/+0.16 rad); `verbs.lua:594-627`; `grug_core/homing.lua:32-67`
- **What:** Each projectile gets `grug_mobs.stamp_arrow_damage`, which locks
  the shooter's current target (`actor_projectile_lock`). The homing
  `on_step` overwrites the initial fan velocity on the first step with
  `(target_center − pos) / remaining`. All three share the same `duration`
  (distance/speed, at most 2 s), so all three arrive together and each calls
  `hit_player`. One dragon breath therefore deals 3 × 1.5 × damage to the
  locked player (4.5×) and can never hit a bystander. A King's volley is 3
  guaranteed hits. `projectile_node` (the breath's ground patch on impact) is
  never called, because the homing `on_step` replaces mobs_redo's, which held
  the node test. Patches appear only at the locked player's feet, three
  times on the same cell.
- **Impact:** Breath and volley damage may be about triple what the
  numbers assumed, the visible fan is a lie, and "step out of the breath
  line" (`world.md` "ranged breath line") is not possible.
- **Better:** Decide the intent. If the fan is meant to spread, fire the
  side projectiles as non-homing straight shots (keep `hit_node`), or as
  homing projectiles locked only when a different hostile is in that
  direction. If one hit is meant, spawn one projectile with a cosmetic fan of
  particles. Re-run the boss numbers (`tools/r36_r/numbers.py`) after.
  Effort S–M.
- **Verification (phase 2):** Partly confirmed — the mechanics hold: all three shots lock `mob.attack` via `stamp_arrow_damage` (`verbs.lua:629-638`), share one launch-time duration (`homing.lua:39`), each calls `hit_player`, and `hit_node`/`projectile_node` is dead because `def.on_step` replaces mobs_redo's step (`mobs/api.lua:4931`). But the non-dodgeable fan follows the deliberate homing rule (`combat_stats.md:395-398`, "cover protects before launch only"), and `tools/r36_r/numbers.py:19` does not model breath at all, so "triple what the numbers assumed" is unsupported; what remains is an intent question on the 3x damage plus a dead field. Medium kept.

### MOC-05 Dragon rime/scorch replace buildable_to nodes (snow, grass, water) and turn them into air
- **Severity** Medium / **Category** Bug / **Confidence** Verified
- **Location:** `mods/ENTITIES/grug_mobs/boss_dragons.lua:230-243`
  (`find_effect_pos` accepts `air` **or** any `buildable_to`), `:262-276`
  (`set_node`), `:173-179` (`effect_timeout` sets `air`);
  `grug_core/protection.lua:147-155` (the guard used)
- **What:** A breath patch may land on any `buildable_to` node over a
  walkable one: `default:snow`, the grass and dry-shrub nodes, flowers,
  `grug_nodes:bone_pile`, water lilies, and `default:water_source` /
  `water_flowing` over a shallow bottom. When the timer expires the patch
  becomes **air**, not the node it replaced. The guard is
  `ground_effect_protected(pos, <target player>)`, the zone/claim rule for the
  target's faction, deliberately without the POI layer. The memory note for
  the terrain guard says these effects were meant to be "only in air, with a
  timer".
- **Impact:** Every breath permanently strips snow cover or ground plants
  from the arena floor (a protected POI core) and can punch holes into
  shallow water. The damage is cosmetic, but it is permanent world damage
  that accumulates over every fight.
- **Better:** Either place only into `air`, or store the replaced node
  (name and param2) in the effect node's meta and restore it in
  `effect_timeout`. The first is one condition. Effort S. A later fire or
  explosion lane should reuse whichever rule is chosen
  (`grug_core.world_alterable` is the documented guard for terrain changes).
- **Verification (phase 2):** Confirmed — `find_effect_pos` accepts any `buildable_to` node (`boss_dragons.lua:230-243`) and `effect_timeout` writes `air` (`:173-179`), so snow (`default/nodes.lua:633`), plants and water sources over a walkable floor are erased; the arena writer only clears snow on hazard columns (`arena_writer.lua:12`), leaving the rest of the floor exposed. The reach is limited to the two dragon arenas: the only live call site is `projectile_hit` at the target's feet (`:390`), targets must stand inside the arena (`dragon_arena.lua`), and `ground_effect_protected` returns protected for an empty actor (`protection.lua:148`), so towns, starts and other POIs cannot be touched; water holes between two or more sources refill (default water is renewable). It still breaks the terrain-guard premise of "ground effects only in air" inside a protected POI core, so Medium stays.

### MOC-06 Royal guards killed without a King reset stay down until the King resets or dies
- **Severity** Medium / **Category** Bug / **Confidence** Plausible (the
  reset triggers were traced; the exact player sequence was not run)
- **Location:** `mods/ENTITIES/grug_mobs/start_npcs.lua:1701`
  (`ROYAL_HOLD = 2147483647`), `:1718-1722` (`royal_guard_died`), `:1459`
  (a `due` above 1e9 compares against wall time), `:826-839` (`due` restored
  from storage); `bosses.lua:429-436`; `aggro.lua:435-475` (the contact and
  distance leash only runs while the King attacks a player);
  `idle_health.lua:93-96` (the idle heal needs `health < hp_max`)
- **What:** A dead royal guard's slot is booked at `ROYAL_HOLD`, a wall-clock
  time in January 2038, and persisted. It is cleared only by
  `royal_encounter_reset` (King evade, or `boss_leash_reset` on the King) or
  by `royal_king_died`. If players kill guards while the King never acquires
  them, or the King's target dies before the leash fires and the King took no
  damage, nothing triggers a reset, and the guards stay missing across
  restarts.
- **Impact:** A throne room permanently short of its retinue until somebody
  pulls the King into a real reset. Less likely in a full raid, more likely
  with ranged picks from outside the King's view range of 18.
- **Better:** Add a fallback: in `serve`, when a royal slot has been held for
  more than N minutes and its leader stands calm and unengaged, free it with
  the ordinary respawn interval. Or let `royal_guard_died` book
  `os.time() + 15 min` and let `royal_encounter_reset` pull it forward.
  Effort S.
- **Verification (phase 2):** Confirmed — `royal_guard_died` books `ROYAL_HOLD` (`start_npcs.lua:1701, 1718-1722`), the wall-clock branch (`:1459`) never reaches 2^31-1, the due is restored from storage across restarts (`:838-842`), and the only clears are `royal_encounter_reset` (from King evade `bosses.lua:429-433` or `boss_leash_reset` `:261-268`, reached only through `leash_reset` on a King chasing a player, `aggro.lua:435-476`) and `royal_king_died`. Guards do not pull the King (different mob names, so no `group_attack` link), so ranged picks outside his view range of 18 leave the slots held indefinitely.

### MOC-07 Unapproved sounds outside `grug_sounds`: dragon return warning, Rift Spawn fuse and burst
- **Severity** Medium (user ruling) / **Category** Bug / **Confidence**
  Verified
- **Location:** `mods/ENTITIES/grug_mobs/bosses.lua:750-751`
  (`core.sound_play("mobs_spell", ...)`); `rift_spawn.lua:86`
  (`sounds = {fuse = "default_cool_lava", explode = "default_item_smoke"}`),
  `:69-72` (raw `core.sound_play` of the explode sound); the raw fallback in
  `mobs/api.lua` `mob_sound` for names that are not `grug_sounds` events
- **What:** `docs/design/sound.md` §1 says that only approved files ship and
  that game events go through `grug_sounds.play`. None of the three files
  (`mobs_spell.ogg`, `default_cool_lava.*.ogg`, `default_item_smoke.ogg`) is in
  any `approved.txt`. They are vendored files, so the per-lane `.ogg`
  fixtures do not see them.
- **Impact:** The players hear sounds the user never picked, at the dragon's
  60 s return warning and at every Rift Spawn fuse and burst.
- **Better:** Drop them (silent is the rule) or route them as `grug_sounds`
  events with a pick. Add a sweep that fails on `core.sound_play` outside
  `grug_sounds`/`grug_ambience` and on literal names in mob `sounds` tables.
  Effort S.
- **Verification (phase 2):** Confirmed — `bosses.lua:750-751` plays `mobs_spell` raw; `rift_spawn.lua:86` keeps explicit `sounds` that `apply_voice` lets win (`voices.lua:104`), the fuse goes through `mob_sound` (`mobs/api.lua:2651`), whose `GRUG PATCH` routes only `grug_sounds.EVENTS` names and plays everything else raw (`:288-301`), and the burst is a raw `core.sound_play` (`rift_spawn.lua:69-72`). None of the three names appears in any `tools/*/approved.txt`, which violates `docs/design/sound.md` §1 ("An event without an approved file stays silent").

### MOC-08 Enraged dragon re-sends its full object properties every server step
- **Severity** Low / **Category** Perf / **Confidence** Verified (call);
  the cost class is reasoned
- **Location:** `mods/ENTITIES/grug_mobs/boss_dragons.lua:1013`
- **What:** `if self._grug_enraged then self.object:set_properties({glow =
  8}) end` runs every step. `set_properties` marks the properties dirty, so
  the engine sends the whole property set (mesh, textures, boxes, visual
  size) to every observer on the next step.
- **Impact:** At most two dragons, only in the enraged half of a fight, but
  it means 10–20 full property packets per second per observer for nothing.
- **Better:** Set the glow once in `enrage()` (already done at `:705`) and
  once on activation if `_grug_enraged` persisted; delete line 1013.
  Effort S.

### MOC-09 Royal guards find their King with a radius-80 object scan every second
- **Severity** Low / **Category** Perf / **Confidence** Verified (code);
  the cost is reasoned
- **Location:** `mods/ENTITIES/grug_mobs/bosses.lua:365-372`
  (`royal_objects`), `:568` (1 Hz per royal guard), `:384` (rally, radius
  50), `:509` (King's `on_die`, radius 80)
- **What:** 4 guards × 6 Kings plus 2 × 2 bodyguards each scan every object
  within 80 nodes once a second while active. In a capital that means every
  NPC, its tag-carrier child, item entities and players, with a
  `get_luaentity` per object.
- **Impact:** A few hundred `get_luaentity` calls per second per capital
  with a player present. Small, but it scales with NPC density and runs even
  when no fight happens.
- **Better:** Keep a weak table `boss_id → King ObjectRef`, filled in
  `king_tick` and cleared on deactivate, and read it in
  `royal_guard_tick`. Effort S.

### MOC-10 Projectile homing calls `get_properties()` per projectile per step
- **Severity** Low / **Category** Perf / **Confidence** Verified (call);
  the cost is reasoned
- **Location:** `mods/CORE/grug_core/homing.lua:24-30` (`target_center`),
  called from `homing_step:66` for every player projectile
  (`grug_projectiles/init.lua:399`) and every mob arrow (`verbs.lua:599`)
- **What:** AGENTS.md forbids `get_properties()` in per-step code (use the
  cached `self._grug_cbox`). `target_center` builds the full property table of
  the target every step. `identity()` adds `get_player_by_name` /
  `get_luaentity` per step for owner and target.
- **Impact:** Flight times are short (≤ 2 s, about 1 s for the player kits
  at speed 20), so in practice it costs tens of property tables per second
  per active shooter. It is negligible today, but it scales with players ×
  archers.
- **Better:** Compute the centre offset once in `homing_lock` (from
  `_grug_cbox` or one `get_properties`) and add it to `get_pos()` per step;
  refresh only on a tier change. Effort S (grug_core owner).

### MOC-11 start-NPC heartbeat scans every settlement row in one step
- **Severity** Low / **Category** Perf / **Confidence** Verified (code);
  overlaps C4
- **Location:** `mods/ENTITIES/grug_mobs/start_npcs.lua:1600-1617`, `:880-883`
- **What:** Every 5 s, one step serves every row (6 capitals, 6 starts, PvP
  fortresses and war camps), each with
  `get_objects_inside_radius(row.anchor, row.scan_radius)` over the
  settlement envelope. AGENTS.md (Round 32): "No pass handles every player or
  zone in one step."
- **Impact:** A periodic spike proportional to the objects in active
  settlements. Rows without players return quickly.
- **Better:** Serve a slice of rows per step (round-robin), as the spawner's
  zone slices do. Effort S.

### MOC-12 Oerkki and Wisp blink through walls and into claims; the blink is copy-pasted
- **Severity** Low / **Category** Bug / Duplication / **Confidence**
  Verified
- **Location:** `mods/ENTITIES/grug_mobs/oerkki.lua:3-8, 34-58`;
  `night_families.lua:160-178`
- **What:** The blink moves the mob 2.5–3 nodes toward its target when only
  the destination and the node above are non-walkable (`open_node` also
  accepts unknown nodes). It checks neither line of sight nor protection, so
  an Oerkki teleports through a 1–2 node wall into a mine shelter or a
  claimed house. The two functions are the same code with different
  constants.
- **Impact:** A player hiding behind a wall underground gets an Oerkki next
  to him; claims do not stop it.
- **Better:** One shared `grug_mobs.blink_toward(self, max_step, opts)` with
  `core.line_of_sight` from eye to destination and a claim check
  (`grug_mobs.claim_refuses_spawn`-style). Effort S.

### MOC-13 Explosion terrain safety rests on `is_protected(pos, "")`; mobs_redo promotes radius 0 to 1
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified
- **Location:** `mods/ENTITIES/mobs/api.lua:2705-2714` (near water or
  protection, `node_break_radius = 1`), `:5039-5065` (`mobs:boom` uses
  `tnt.boom` / `mcl_explosions` when `mobs_griefing` and not
  `is_protected(pos, "")`); `grug_core/protection.lua:69-71` (an empty name
  is always protected); `rift_spawn.lua:84`; `minetest.conf` (no
  `mobs_griefing` line)
- **What:** No mob explosion damages terrain today, but only because the
  empty actor name is always protected and no `tnt` mod is loaded. A future
  `tnt` dependency, or a change to the empty-name rule, would turn every
  `explode` mob into terrain damage with radius ≥ 1, in towns too. The same
  flag gates `pathfinding = 2` digging and building and `replace_what`.
- **Impact:** None today. It is a trap for the next explosion or fire lane.
- **Better:** Set `mobs_griefing = false` in `minetest.conf` (belt and
  braces) and note in AGENTS.md that terrain-changing effects use
  `grug_core.world_alterable`. Effort S.
- **Verification (phase 2):** Confirmed (Low kept, not Medium) — the protection is triple, not single: no `tnt`, `mcl_explosions` or `fire` mod exists in `mods/`, so `mobs:boom` always falls through to `safe_boom` (`mobs/api.lua:5046-5064`) whatever `is_protected` says; the only `explode` mob, the Rift Spawn, removes itself in `burst_due` (`rift_spawn.lua:42-73`) before mobs_redo's explode branch (`api.lua:2703-2714`) runs; and the empty actor is protected (`protection.lua:69-71`). No grug mob uses `pathfinding = 2` or `replace_what`. Breaking it needs a new tnt-style mod plus a new plain `explode` mob, and the terrain-guard rule already obliges such a lane to use `grug_core.world_alterable`.

### MOC-14 Homing mob arrows silently ignore `hit_node`, `lifetime`, `drop`
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified
- **Location:** `mods/ENTITIES/grug_mobs/verbs.lua:594-627`;
  `mobs/api.lua:4896-4945` (`on_step = def.on_step or ...`)
- **What:** `register_homing_arrow` sets `def.on_step`, which replaces
  mobs_redo's arrow step completely. `hit_node`, `hit_object`, `lifetime`,
  `drop`/`drop_item` and `rotate` are accepted and never used (see MOC-04's
  dead `projectile_node`). An arrow without a lock is removed in its first
  step, so arrows cannot leak.
- **Impact:** A new arrow author writes a `hit_node` and nothing happens.
- **Better:** Assert in `register_homing_arrow` that those fields are nil,
  or call `hit_node` from the homing step when a ray to the next position
  hits a walkable node. Effort S.

### MOC-15 Lua `drops` shadowed by drops.json in 7 families; `FUNCTION_DROPS` lists 1 of 3 drop functions
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified
  (script)
- **Location:** `grug_mobs/{bear,boar,crocodile,start_zone_families (fox),
  mirefolk,night_families (wisp),zombie}.lua` `drops`;
  `subtypes.lua:354-372`; `grug_traders/init.lua:44-50`;
  `bandit_archer.lua:84-89`; `zero_asset_variants.lua:48-55`
- **What:** For those seven base mobs, `drops.json` has a family table, so
  their Lua `drops` only apply in a band without rows. Editing them usually
  has no effect. The trader audit's hand list of drop functions names only
  `grug_mobs:bandit` ("One entry today"), while `bandit_archer` and `poacher`
  also use functions. Their extra item (`grug_mobs:arrow`) is audited only
  because the skeleton archer drops it statically.
- **Impact:** Edits that silently do nothing, and an audit gap if those
  functions gain an item.
- **Better:** Remove or comment the shadowed Lua `drops` (or assert at load
  that a family with a full band table has no static drops). Derive
  `FUNCTION_DROPS` by calling each drop function at load with a few probe
  positions. Effort S.

### MOC-16 Vendor capital-offset fallback and its globalstep; stale "serves everybody" comment
- **Severity** Low / **Category** Legacy / **Confidence** Plausible (all six
  capital compositions declare `vendor` sockets; not proven at runtime)
- **Location:** `mods/ENTITIES/grug_traders/vendors.lua:528-703`, `:414`
- **What:** The pre-WP13 path for "a capital whose core has not landed"
  still builds offset slots and runs a 5 s globalstep. Every capital file
  (`dur_brannoc.lua:556`, `highcourt.lua:702`, `lethariel.lua:623`, …)
  declares vendor sockets, so `slots` should be empty and the globalstep a
  no-op. The comment at `:414` says profession vendors serve everybody,
  which contradicts Round 31 ruling 13 as implemented in `vendor_faction`.
- **Impact:** Dead code that an agent may keep "in sync", and a comment that
  states the wrong rule.
- **Better:** Make a capital without vendor sockets a load error and delete
  the offsets, `vendor_present` and the globalstep; fix the comment.
  Effort S.

### MOC-17 Inert camp fires in recipe zones keep their 30 s timer; `place_camp` is unused
- **Severity** Low / **Category** Legacy / **Confidence** Verified
- **Location:** `mods/ENTITIES/grug_mobs/camps.lua` `camp_tick` (early
  return for `CAMP_FIRE_NODE` in a zone with a recipe), `:738-745` (LBM
  re-arms on every load), `:758-799` (`grug_mobs.place_camp`, no caller in
  `mods/` or `tools/`)
- **What:** A camp fire in a recipe zone never spawns, yet it keeps a
  node timer firing every 30 s for as long as its block is active. The
  placement API is documented for "WP13's settlement pass" but nothing calls
  it.
- **Impact:** Minor timer churn and dead API surface.
- **Better:** Do not re-arm the timer for fires in recipe zones (or swap
  them for a decorative node at write time); remove `place_camp` or move it
  to a test helper. Effort S.

### MOC-18 Queued boss loot only arrives at the next join
- **Severity** Low / **Category** Bug / **Confidence** Verified
- **Location:** `mods/ENTITIES/grug_mobs/bosses.lua:145-161, 181-195`
- **What:** With a full main inventory, the leftover goes to a meta queue
  that is delivered only in `register_on_joinplayer`; the feed tells the
  player to free space and rejoin.
- **Impact:** A player must relog to get a boss reward. Nothing is lost.
- **Better:** Retry the queue on a slow per-player pass (or on inventory
  change) besides join. Effort S.

### MOC-19 `grug_projectiles` dead fields: `_grug_travelled` stays 0, `_grug_max_distance` unread
- **Severity** Low / **Category** Legacy / **Confidence** Verified
- **Location:** `mods/ENTITIES/grug_projectiles/init.lua:334-335, 377-381`
- **What:** Since the move to homing locks, range is checked once by the
  spawn ray; `_grug_travelled` is never advanced and `_grug_max_distance` is
  never read after activation, so the debug "hit distance" is wrong.
- **Impact:** Misleading debug output and fields that suggest a range check
  that does not exist.
- **Better:** Remove both fields and log the lock's age instead. Effort S.

### MOC-20 Potion refusals go to chat, not the message feed
- **Severity** Low / **Category** Bug / **Confidence** Verified
- **Location:** `mods/ENTITIES/grug_traders/potion.lua:93-103`
- **What:** "You cannot drink another potion for N s." and "You are
  already at full health." use `core.chat_send_player`. AGENTS.md (Round 32):
  personal notices go to `grug_core.feed`.
- **Impact:** Chat spam when a player mashes a potion during a fight.
- **Better:** `grug_core.feed(player, "notice", text, "potion")`. Effort S.

## Hot-path inventory

| Path | Frequency | Cost class | Notes |
|---|---|---|---|
| Verbs: `pack_hunter`, `stalker`, `ambusher`, `camp_swarm`, `damage_aura` (`verbs.lua`) | per mob, 1 Hz gate (`due`) | O(1) mostly; radius scan only on the event (flee, first swarm call) or aura radius 2 | Fine. The stalker LOS ray runs only in the pounce window. |
| Telegraph (`telegraph.lua:148-200`) | per elite/rare step | O(1) counters; `resolve` O(players) + LOS ray once per 10 s | Fine. |
| Dragon tick (`boss_dragons.lua:985-1102`) | per step, 2 dragons | O(1) + LOS ray per ground step while engaged; radius-8 scan while the gust is ready; 1 Hz arena prune and wrath | Fine except MOC-08. |
| Arena hazard pass (`boss_dragons.lua:322-382`) | 4 Hz global | O(players) × (1–2 `get_node_or_nil` + 27 for the thin-ice cube inside the ice arena) | Fine. |
| Dragon hp hook (`boss_dragons.lua:97-106`) | every player HP change | O(1) | Fine. |
| Boss respawn loop (`bosses.lua:764-785`) | 0.1 Hz | O(2) storage reads + `terrain_height_at` | Fine. |
| King tick (`bosses.lua:420-457`) | per step per King/General | O(1); a signature every 10 s (radius-6 punch, 3 arrows, 2 summons or a heal) | Bone Call unbounded (MOC-02). |
| Royal guard tick (`bosses.lua:548-609`) | 1 Hz per guard (28) | radius-80 scan | MOC-09. |
| Rift pass (`rift.lua:471-506`) | 1 Hz global | O(players); per-player particle spawner every period; crack write once per world | Fine. |
| Rift boss tick (`rift.lua:306-358`) | per step | O(1); A* only inside the shared per-step budget | Fine. |
| Rare spawner (`rares.lua` globalstep) | 0.1 Hz | O(rares × route points) radius-100 scans, only with a player near | Logic bug MOC-01; cost fine. |
| Camp fire timer (`camps.lua` `camp_tick`) | 30 s per active fire | O(players) + one radius scan when a player is within 80 | Fine (MOC-17 inert fires). |
| Night families: wisp/oerkki blink, treant aura | per step counter; work every 1–5 s | O(1) / radius 3 | Fine. |
| Kraken tick (`kraken.lua:138-155`) | 1 Hz | O(1) water-class lookup | Fine. |
| Player projectiles (`grug_projectiles/init.lua:388-415`) | per projectile per step (≤ about 1 s flight, limit 8 per player) | 2–3 C lookups + `get_properties` | MOC-10. |
| Mob arrows (`verbs.lua:597-621`) | per arrow per step (≤ 2 s) | same as above | MOC-10. |
| Trader form (`trade.lua`) | per click | O(main list) for the sell rows; O(shelf) for the offer | Fine. |
| Crownbinder rows (`crown.lua:84-103`) | per open/click | O(owned gear) × crown preview (and a crowned copy for worn items) | Fine (cold). |
| Vendor offset globalstep (`vendors.lua:655-703`) | 0.2 Hz | O(players) + O(slots = 0) | Dead (MOC-16). |
| start-NPC heartbeat (`start_npcs.lua:1600-1617`) | 0.2 Hz | all rows × radius scan in one step | MOC-11. |
| Startup audits (`grug_traders/init.lua:81-186`, `subtypes.lua:560-572`) | once at load | O(items × recipes) | Fine. |

## Bug-prone areas

- **Boss lifecycles** (`bosses.lua`, `boss_dragons.lua`, `start_npcs.lua`
  royal slots, `rift.lua`): three persistence models, each with its own
  "is it still there" answer; the gaps are MOC-01, MOC-03 and MOC-06. Any new
  boss should reuse one model with a liveness fallback.
- **Encounter adds** (`_grug_royal_summon`, `_grug_boss_summon`): exempt from
  leash, wander, dawn and loot; their cleanup is ad hoc (radius scans in
  `on_die`, `remove_whelps`) and missing on the King's reset (MOC-02).
- **The homing projectile seam** (`verbs.lua:594`, `grug_core/homing.lua`):
  it silently changes mobs_redo arrow semantics (no miss, no node hit, no
  lifetime). Anything authored as a "spread" or a "ground hit" is affected
  (MOC-04, MOC-14).
- **mobs_redo field whitelist and `do_punch` truthiness:** custom def fields
  never reach the entity unless a wrapper installs them; any truthy
  `do_punch` return cancels the punch. Both are documented in the files, but
  every new content author trips over them.
- **Runtime node writes** (dragon effects, rift crack): the only places
  content changes the world at runtime; MOC-05.
- **`start_npcs.lua` `due`**: one field holds game time or wall time, chosen
  by magnitude (`> 1e9`), plus the `ROYAL_HOLD` sentinel.

## Noted (no action)

- Boss loot lockout uses `set_int` with an absolute `os.time()`
  (`bosses.lua:235-242`), which wraps in January 2038; `potion.lua:17-24`
  documents and avoids exactly this.
- `slam_hit` (`boss_dragons.lua:653-660, 797-800`) is a global flag around
  `player:punch`; if a punch callback errored between set and clear, engine
  knockback would stay off server-wide until the next slam.
- A crash in the window between `on_die` (storage `alive = ""`) and the map
  save could bring the old dragon back next to a fresh respawn. Exotic.
- The telegraph cone (`telegraph.lua:91-144`) hits players only; an elite
  that fights an NPC guard winds up and hits nothing. A King's telegraph and
  its signature cast can overlap; the rift boss coordinates them, the King
  does not.
- Camp member counts (`camps.lua` `count_camp_mobs`) see only active
  objects; a fire at the edge of the active area can over-fill its camp
  (C4 overlap, bounded by the far-cull).
- Kraken (`kraken.lua:146-154`) only stops and stands when outside deep
  ocean; a stranded Kraken can re-acquire for up to 1 s per pass near the
  coast.
- The Weak Healing Potion heals a flat 35 HP (`potion.lua:7`); against
  high-level pools that is negligible, but it is a design number.
- `subtypes.lua:11-12` and `vendors.lua:519-522` still describe "as before"
  fallbacks for missing data or sockets; harmless, but in the spirit of
  fresh-server mode they could fail loudly instead.

## Open questions for Jan

1. Dragon breath and the King's volley fire three projectiles, but all three
   home onto one player and hit together (MOC-04). Is a guaranteed triple hit
   intended, or should the side projectiles fly straight and be dodgeable?
2. The Undead King's summoned skeletons (MOC-02): should they have a cap,
   belong to the King's faction (never attack Throng players) and disappear
   when the fight resets?
3. Dragon breath patches (MOC-05): place them only into air, or restore the
   snow, grass or water they replaced?
4. Royal guards killed outside a real King fight (MOC-06): should they come
   back after a timeout (for example 15 minutes, like after a King kill)?
