# MOB1 — grug_mobs runtime and AI (verified)

- Finder model: claude-opus-5-5
- Verifier model: claude-opus-5-5
- Files read in full: 28 of 28; skimmed: zero_asset_variants.lua (definition data, read through), names_core.lua (pure index, read through); not reached: none
- Summary: The runtime is in good shape: the per-mob step is a chain of cheap field tests, A* only runs behind `nav.claim_search`/`nav.search`, `get_properties()` survives only in non-step fallbacks, the only `core.after` (poison) re-fetches the player by name with a generation guard, and the do_punch wrapper honours the mobs_redo "truthy cancels" contract. The most valuable items are (1) the do_custom wrapper's per-STEP truce and faction sweeps, which read player meta every server step for every attacking zombie and faction mob, (2) the elite/rare wind-up that roots the mob for 2 s against a MOB target although the cone only ever hits players, and (3) config-derived fields (speeds after a root/slow/evade, the aggro fields) written onto the instance and therefore frozen into staticdata of never-despawning NPCs. The rest is small dead code and stale comments/docs (about 70 `api.lua:<line>` citations that no longer match the vendored file). Engine behaviour: not checked by the finder; the verifier checked the default server step and the object spatial index in `reference_projects/luanti` (MOB1-01, MOB1-06).

## Findings

### MOB1-01 | Medium | perf | Truce and faction sweeps read player meta on every server step of every attacking mob

- **Verdict:** CONFIRMED — `init.lua:966-988` runs in `do_custom` outside any accumulator; `do_custom` is called from every `on_step` (`mobs/api.lua:4072`, after the stun/pause returns). `truce_active` → `grug_classes.get_race_perk` → `get_race` reads race meta and `grug_factions.get_faction` faction meta (`grug_classes/init.lua:86-93`, `grug_factions/init.lua:53-59`); `get_object_faction` reads faction meta (`grug_factions/init.lua:192-201`). Engine default `dedicated_server_step` is 0.09 (`reference_projects/luanti/src/defaultsettings.cpp:495`) and `minetest.conf` does not set it. One correction to the evidence: AGENTS.md does not list `get_meta` in hot paths (its only `get_meta` lines, AGENTS.md:281-283, are about persistence); the cost argument stands on the per-step frequency and AGENTS.md:312-314 alone.
- **Where:** `mods/ENTITIES/grug_mobs/init.lua:966-988` (callees `init.lua:826-831` truce_active, `mods/PLAYER/grug_classes/perks.lua:25-32` + `mods/PLAYER/grug_classes/init.lua:86-93`, `mods/PLAYER/grug_factions/init.lua:53-59,192-201`)
- **What:** The registration wrapper's `do_custom` runs every server step. For a mob with `_grug_truce_perk` (the whole zombie/husk family and every sub-type) in state "attack" on a player it calls `truce_active` -> `grug_core.get_race_perk` -> `grug_classes.get_race` = two `player:get_meta():get_string()` calls (race + faction) per step. For every faction mob (guards, captains, commanders, kings, royal guards, bodyguards) attacking a player it calls `grug_factions.get_object_faction(self.attack)` = one `get_meta():get_string()` per step. The comments call both "belt and braces" for acquisition paths that bypass `general_attack`; nothing about them needs step resolution.
- **Evidence:** `init.lua:966-975` (`if truce_perk then if self.state == "attack" ... truce_active(self, self.attack) ...`) and `:981-988` (`grug_factions.get_object_faction(self.attack) == self._grug_faction`), both outside any accumulator; `do_custom` is called from `mobs/api.lua:4072` on every `on_step`. At the default server step (~11 Hz; `dedicated_server_step` is not set in minetest.conf, engine default 0.09 s) and the 100-player target, a night with 200 zombies engaged on players is ~4,400 meta reads/s from this one line, plus one per step per guard in a PvP camp fight.
- **Proposal:** Evaluate both sweeps only when the target changed or once a second: remember the last swept target in `self.temp` (`grug_sweep_target`) and re-test on a change, or move both tests into the 1 Hz `leash_tick` slot (aggro.lua:1112) which already hosts the evade sweep with the same "at most one second of chase" tolerance (aggro.lua:610-627). The veto result for a given (mob, player) pair can only flip through provocation (removes the truce) or a faction change (rare), so behaviour stays identical except for at most one second's delay on a target handed over by `group_attack`/`do_attack` — note that `holds_target` (init.lua:1038-1046) already keeps such a target out of the engagement, so the visible effect is unchanged.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Measure:** unmeasured. Before/after on the same seed: a night start-zone area with 20 stand-in players each engaged by 5-10 zombies and one PvP camp fight with 10 guards; count `get_meta` calls per second (wrap `ObjectRef:get_meta` in a probe) and the mob step time (`mobs_redo` on_step profiler).
- **Confidence:** high

### MOB1-02 | Medium | bug | Elite/rare wind-up roots the mob for 2 s against a mob target, but the cone only damages players

- **Verdict:** CONFIRMED — the start gate (`telegraph.lua:178-200`) tests only state, `self.attack` and distance; `start_windup` roots the mob (`grug_mobs.root(self, WINDUP)`); `resolve` (`:85-141`) loops `core.get_connected_players()` only; `grug_winding_up` (`mobs/api.lua:553-556`) pauses swings for any target. Guards have `attack_monsters = true` (`guard.lua:211`) and level-60+ guards turn elite (`guard.lua:93-101`).
- **Where:** `mods/ENTITIES/grug_mobs/telegraph.lua:85-141` (resolve), `:178-200` (start condition); `mods/ENTITIES/mobs/api.lua:553-556` (`grug_winding_up`)
- **What:** `telegraph_tick` starts a wind-up for any melee target (`self.attack` of any kind within 2x reach). During it the mob is rooted (`grug_mobs.root`) and `grug_winding_up` freezes its facing and pauses its ordinary swings and shots. `resolve` then loops `core.get_connected_players()` only, so a mob target (a wolf in front of an elite city guard, which has `attack_monsters = true`; an elite or rare hostile fighting a guard NPC) takes nothing. Every 10 s of such a fight the elite stands still for 2 s and deals no damage: about 20 % less damage against mobs, and a visible "!! wind-up into nothing".
- **Evidence:** start gate `telegraph.lua:180-200` tests only `self.state == "attack"`, `self.attack`, distance; `resolve` `:100-139` iterates `core.get_connected_players()`; pause `mobs/api.lua:553-556` keys on `temp.grug_tg_left` and `state == "attack"` whatever the target. guard.lua:211 `attack_monsters = true` and guard.lua:93-101 promote every level-60+ guard to elite. combat_stats.md:773-790 describes the cone against players and is silent on mob targets.
- **Proposal:** Either (a) start a wind-up only while `core.is_player(self.attack)` (smallest change; elites fight mobs with plain swings), or (b) let `resolve` also punch the mob target itself when it stands in the cone with line of sight (`self.attack:punch(self.object, 1.4, ...)`), keeping the player loop identical. Ask the design owner which; (a) keeps the player-facing behaviour byte-identical.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** high

### MOB1-03 | Medium | persist | Config-derived fields are written onto the instance and frozen into staticdata

- **Verdict:** CONFIRMED — `clean_staticdata` (`mobs/api.lua:3662-3679`) iterates `pairs(self)`, i.e. instance fields only, and `mob_activate` (`:3797-3818`) copies every saved field back onto `self`; nothing re-applies the definition speeds on activation. The speed writes (`init.lua:424-425, 440, 462-463, 500-501, 532-543`) and the set-only `apply_aggro_fields` (`aggro.lua:140-181`) are as described; no writer of `walk_velocity`/`run_velocity` exists in `mobs/api.lua` except the registration default (`:4177-4178`).
- **Where:** `mods/ENTITIES/grug_mobs/init.lua:416-420,541-547` (speed restore), `mods/ENTITIES/grug_mobs/aggro.lua:140-181` (`apply_aggro_fields`, called every step from `init.lua:889` and every punch from `init.lua:815`)
- **What:** mobs_redo serializes every non-function instance field (`mobs/api.lua:3662-3679` clean_staticdata) and layers it back on activation. (1) A root, slow, stun or evade writes `walk_velocity`/`run_velocity` onto the instance, and the restore tail writes the base values back as instance fields instead of removing them, so every mob that was ever rooted/slowed/evaded carries its speeds in staticdata from then on and ignores a later definition retune. (2) `apply_aggro_fields` writes `_grug_damage_pursuit_candidate`, `_grug_drop_rule`, `_grug_chase_range`, and when configured `_grug_no_leash`, `_grug_soft_deaggro`, `_grug_leash_range` on the instance; they persist, and because the function only ever SETS (never clears) a value, a definition that later drops `_grug_leash_range`/`_grug_no_leash`/`_grug_soft_deaggro = false` leaves saved mobs on the old value. Ordinary wildlife despawns, so the realistic victims are the never-despawning `type = "npc"` actors (guards, captains, commanders: `_grug_leash_range = 30`, evades on every leash reset).
- **Evidence:** `init.lua:542-543` `self.walk_velocity = self._grug_speed_base.walk` (instance write); no writer of these fields exists in mobs/api.lua (`rg "self\.(walk_velocity|run_velocity)\s*=" mods/ENTITIES/mobs/api.lua` is empty), so the def value lives on the prototype until our code shadows it. `aggro.lua:151-164` only set; the comment at `aggro.lua:213-214` ("apply_aggro_fields re-writes _grug_leash_range from the def on every tick") is only true while the def keeps a value. init.lua:1067-1082 already publishes other config (`_grug_damage_pursuit_candidate`, `_grug_authored`, `_grug_reach_reset`) on the prototype, so `_grug_damage_pursuit_candidate` exists twice.
- **Proposal:** (1) In `save_speed_base` record the raw instance values (`rawget(ent, "walk_velocity")`, may be nil) and restore those, so an unaffected mob goes back to reading the prototype; keep `_grug_speed_base` semantics otherwise. (2) Publish the `aggro_cfg` fields once on `core.registered_entities[name]` after `mobs:register_mob` (as init.lua:1067 does) including `general_attack = no_target_acquisition` for `no_acquire`, and drop the per-step/per-punch `apply_aggro_fields` calls; instance overrides by spawners (`_grug_no_leash` on bosses, a pack's `_grug_chase_range`) keep working because an instance field shadows the prototype. Stays identical: every reader reads `self.<field>` as today. Old saves keep their stale instance values until a one-line activation cleanup (`self._grug_leash_range = nil` etc. when equal to the prototype) is added; that is the migration.
- **Effort:** M · **Risk:** medium · **Upgrade class (guess):** compatible (with the activation cleanup) 
- **Confidence:** high

### MOB1-04 | Low | dead | Stun branch in the do_custom wrapper is unreachable

- **Verdict:** CONFIRMED — `mobs/api.lua:3995-4006` decides `grug_stunned` at the top of `on_step` and `:4055` returns before `do_custom` (`:4072`); the only stun setter is `grug_mobs.stun` (`init.lua:435-450`), called only from Charge (`grug_abilities/charge.lua:178`), which cannot run inside another mob's step. The subtypes wrapper (`subtypes.lua:589-600`) sets no stun either.
- **Where:** `mods/ENTITIES/grug_mobs/init.lua:902-907`
- **What:** `mobs/api.lua` on_step computes `grug_stunned = (self._grug_stun_left or 0) > 0` at the top of the step and returns at `if grug_stunned then return end` before `self:do_custom` is called (`mobs/api.lua:3995-4006,4055,4072`). Nothing between that test and the wrapper's line 902 sets `_grug_stun_left`, so the wrapper's own stun handling (velocity zeroing, timer reset, `return false`) never runs.
- **Evidence:** api.lua:3995 `local grug_stunned = ...`, :4055 `if grug_stunned then return end -- GRUG PATCH: no pending/custom attack`, :4072 do_custom call. In init.lua the only callees before 902 are ensure_init, apply_aggro_fields, tick_speed_effects, leash_tick, dawn_tick, stuck_tick, none of which stun.
- **Proposal:** Delete init.lua:902-907 (the on_step patch is the single owner of the stun step); keep the `grug_mobs.stun` setter.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** high

### MOB1-05 | Low | dead | Unused exports and test-only bookkeeping

- **Verdict:** CONFIRMED — `rg` over `mods` and `tools` finds only the definitions of `grug_mobs.is_poisoned`, `grug_mobs.box_radius` (the other `box_radius` hits are grug_obstacle's own local), `grug_mobs.ROOM_FOOTING` and `grug_mobs.STUCK_WATCH`; no string-built access. The stats part was not re-checked.
- **Where:** `mods/ENTITIES/grug_mobs/verbs.lua:187-190` (`grug_mobs.is_poisoned`), `mods/ENTITIES/grug_mobs/separation.lua:50` (`grug_mobs.box_radius`), `mods/ENTITIES/grug_mobs/room.lua:32` (`grug_mobs.ROOM_FOOTING`), `room.lua:159` (`grug_mobs.STUCK_WATCH`), `room.lua:160,184,199` (`grug_mobs.stuck_stats`), `mods/ENTITIES/grug_mobs/routes.lua:91-92,687-694,725,953-972` (route stats and `route_cache_stats`)
- **What:** Four exports have no reader anywhere; `stuck_stats` and the route-cache stats (two `core.get_us_time()` per search and smoothing, counters per leg) are read only by fixtures/probes under `tools/`.
- **Evidence:** `rg -nF "is_poisoned" mods tools` -> only the definition; same for `grug_mobs.box_radius`, `ROOM_FOOTING`, `grug_mobs.STUCK_WATCH` (0 users in mods and tools). `stuck_stats`: users `tools/r67_world/portable_test.lua:329`, `tools/r67_world/grug_probe_r67_world/init.lua:318` only. `route_cache_stats`: 34 references, all under `tools/` (r42_nv3, r42_dr, hf_0431, r70_cap).
- **Proposal:** Remove the four dead exports. Keep the stats (they are cheap and the probes use them) but say in the routes.lua header that they exist for the probes, so a later lane does not treat them as gameplay state.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** high

### MOB1-06 | Low | perf | `grug_mobs.unwatched` scans every object in a 48-node radius to find a player

- **Verdict:** CORRECTED — engine checked: `get_objects_inside_radius` is a spatial-index range query (`reference_projects/luanti/src/server/activeobjectmgr.cpp:128-143`), not a scan of all objects. `straight_victim` queries a radius of about half a step's travel plus 2.5 nodes (`verbs.lua:693-694`, about 3 nodes at the 14 m/s default velocity, `verbs.lua:863`), which returns a handful of objects; replacing it with `core.get_connected_players()` would build and test a 100-entry list per side shot per step at the 100-player target, likely slower. That half of the proposal is dropped. `unwatched` (radius `SNAP_PLAYER_RANGE = 48`, `patrol.lua:441, 494-503`) does collect every mob and item in a 48-node sphere and only needs players; it runs at most every 10 s per stuck patroller, so the gain is small but real.
- **Where:** `mods/ENTITIES/grug_mobs/patrol.lua:494-503` (`grug_mobs.unwatched`)
- **What:** `unwatched` only looks for players but takes every object within 48 nodes (mobs, items, tag carriers) into a fresh ObjectRef table. It runs at most every 10 s per stuck patroller (SNAP_RETRY).
- **Evidence:** patrol.lua:494-499 `core.get_objects_inside_radius(pos, range or SNAP_PLAYER_RANGE)` then `is_player()` filter; room.lua:176-179 already uses the shared tag snapshot `grug_core.nearest_tag_player_d2`.
- **Proposal:** `unwatched`: `grug_core.nearest_tag_player_d2(pos)` against `range * range` like room.lua `watched` (the snapshot is up to 1 s old; acceptable for a "nobody watches" teleport gate, which already retries every 10 s). Leave `straight_victim` as it is.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** medium

### MOB1-07 | Low | perf | Target frame reads `player:get_properties()` on every fallback cast

- **Verdict:** CONFIRMED — `target_frame.lua:159-160` reads `player:get_properties().eye_height` whenever `crosshair_target` does not settle; whether villagers really fall to this path (the `_grug_level` claim) was not re-checked.
- **Where:** `mods/ENTITIES/grug_mobs/target_frame.lua:150-161`
- **What:** When the crosshair cache does not settle the frame (no recent aim, a ray that stopped at an NPC, arrow or dead mob), the frame builds the full property table of the player just to read `eye_height`, twice a second per player.
- **Evidence:** target_frame.lua:159-160 `player:get_properties().eye_height`; called from the 0.5 s globalstep for every connected player (`:223-236`). Settlement NPCs registered through plain `mobs:register_mob` carry no `_grug_level`, so `framable` rejects them and every look at a villager falls back here.
- **Proposal:** Cache the eye height per player in the frame record and refresh it only where it changes (grug_mounts entity.lua:825 mount/dismount and the grug_visuals sit/stand writes, apply.lua:366/397), or have the frame skip its own cast while the crosshair has no recent aim at all; result identical. (`grug_core.combat_eye_pos` is no help: combat_ray.lua:356 reads `get_properties()` too, so a shared cache there would serve both.)
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Measure:** unmeasured. 100 stand-in players in a capital looking at villagers; count `get_properties` calls/s before/after.
- **Confidence:** medium

### MOB1-08 | Low | docs | About 70 stale `api.lua:<line>` citations and several stale comments in the package

- **Verdict:** CONFIRMED — spot-checked: `general_attack` is at `mobs/api.lua:1800`, `do_states` 2258, `on_punch` 3076, `check_for_death` 998, `item_drop` 870; `init.lua:784` still cites `api.lua:3204-3208`; `touch_boss_activity` and the stunned-hitter cancel run before the "first statement" evade comment (`init.lua:773-780`). Per-file counts not re-tallied (more files than listed carry citations, e.g. `start_villagers.lua` 11).
- **Where:** `mods/ENTITIES/grug_mobs/verbs.lua` (29 citations), `init.lua` (13), `aggro.lua` (10), `levels.lua` (9), `patrol.lua` (4), `telegraph.lua` (3), `guard.lua` (2); `init.lua:776-780`; `guard.lua:28-31,266`
- **What:** The vendored file grew (5,459 lines); the cited line ranges point elsewhere: e.g. init.lua:784 cites the do_punch test at `api.lua:3204-3208` (it is at 3309-3312), init.lua:742 cites general_attack at `1853-2017` (it starts at 1800), aggro.lua:111 cites clean_staticdata at `3546-3627` (it is at 3662). The do_punch comment says the evade cancel "is the first statement in the wrapper so nothing below it ... ever sees the hit" (init.lua:777-780), but `touch_boss_activity` and the stunned-hitter cancel now run before it (init.lua:773-775). guard.lua:30-31 still speaks of "the 15-node roam cap" (aggro.lua:986 `ROAM_RADIUS = 20`; guard.lua:142 itself says 20) and of a leash "around the banner" (the leash measures drag from the chase anchor, aggro.lua:815-842); guard.lua:266 cites `aggro.lua:529-538` for the loot gate (it is at 1242-1261).
- **Evidence:** `rg -c "api\.lua:[0-9]"` per file as listed; `rg -n "function mob_class:(general_attack|do_states|on_punch|check_for_death|item_drop)" mods/ENTITIES/mobs/api.lua` -> 1800, 2258, 3076, 998, 870.
- **Proposal:** Replace line numbers with function names (`api.lua on_punch, the do_punch test`), which survive edits; fix the three stale statements. Code is right in every case.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### MOB1-09 | Low | docs | mobs.md describes faction targeting, fixed levels and runtime fields differently from the code

- **Verdict:** CONFIRMED — mobs.md:22-26 still names a `race` field and `api.lua:1853-2017`; `rg -c "GRUG PATCH" mods/ENTITIES/mobs/api.lua` is 154 against the documented 122 (mobs.md:232). Points (2) and (3) not re-checked.
- **Where:** `docs/technical/modules/mobs.md:23-29,61-69,133-138,232-233`
- **What:** (1) :23-26 "Faction targeting: condition in general_attack() following the LotT pattern (`race` field in the mob def + ally check) ... Dynamic loot: `drops` can be a function" — the code uses the `_grug_ignore_player` veto with `_grug_faction` (init.lua:840-847,949-965) and the `_item_drop_filter` gate (aggro.lua:1309-1321); there is no `race` field. (2) :65-69 lists the `_grug_fixed_level` uses as Kraken, sharks, dragons, kings and royal guards; the code also fixes the rift boss (rift.lua:348, L60), the Generals (bosses.lua:930), the General's bodyguards (bosses.lua:956) and the whelps (boss_dragons.lua:1136). (3) :133-138 says every `_grug_*` field an api.lua patch reads "must be (re-)installed from the do_custom/do_punch wrappers on each activation, not written in the def" — the code also publishes such fields on the registered prototype (init.lua:1067-1082, swimmer.lua:256-262), which is the cheaper route (see MOB1-03). (4) :232-233 "122 counted 2026-10-04" GRUG PATCH sites; `rg -c "GRUG PATCH" mods/ENTITIES/mobs/api.lua` is 154 today.
- **Evidence:** as cited.
- **Proposal:** Update the four passages; for (3) name prototype publication as the preferred way for definition-constant fields and the wrappers only for per-instance runtime state. Docs are the side that is wrong in all four.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### MOB1-10 | Low | dup | Three local copies of the "loaded box" and "standable cell" probes

- **Verdict:** UNVERIFIED — Low, not checked.
- **Where:** `mods/ENTITIES/grug_mobs/routes.lua:465-471,518-539` (`column_loaded`, `box_loaded`), `mods/ENTITIES/grug_mobs/npc_doors.lua:143-160` (`box_loaded`), `mods/ENTITIES/grug_mobs/patrol.lua:208-227` (`stands_at`/`standing_y`), `npc_doors.lua:79-96` (`open_cell`/`stands`/`side_y`), `mods/ENTITIES/mobs/grug_nav.lua:516-522` (`nav.stand_y`); plus `hdist` in aggro.lua:467, routes.lua:120, npc_doors.lua:137
- **What:** routes.lua and npc_doors.lua each carry a mapblock-sampled `box_loaded` with the same loop (one takes from/to plus padding, the other minp/maxp); patrol.lua and npc_doors.lua each implement "feet and head free, walkable ground below" next to the body-aware `nav.stand_y`. They agree today but can drift (patrol's searches 4 up/8 down, npc_doors one down, nav a symmetric band).
- **Evidence:** the cited bodies.
- **Proposal:** Give npc_doors.lua the one `box_loaded(minp, maxp)` (it is loaded first) and let routes.lua call it with its padded box; leave the standable-cell variants alone unless one is touched (different search orders are deliberate), but cross-reference them in comments.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** medium

## Backlog notes

- `aggro.lua:781-783,793`: the damage-pursuit grace allocates a fresh `{x, z}` table per chasing mob per second; could reuse `self.temp.grug_pursuit_target_pos` in place. 1 Hz, negligible.
- `aggro.lua:140-141` / `init.lua:889`: `_grug_damage_pursuit_candidate` is written on the instance every step although the prototype already carries it (init.lua:1067); folded into MOB1-03.
- `init.lua:902-905,446-447`, `patrol.lua:65`: `vector.new` per stun/nudge call; harmless.
- `flight.lua:31-35`: `probe_clearance` allocates one position table per probed node (up to 12 every 0.75 s per free flier); could reuse one table like npc_doors.lua `P`.
- `verbs.lua:637-643`: `damage_aura` punches victims with `hp <= 0` too (only `hurt` checks it); engine behaviour for punching a dead player not checked.
- `init.lua:438-441,494`: `_grug_stun_left` is left at 0 (not nil) after a stun and persists in staticdata; cosmetic.
- `density.lua:101-126`: `region_density_allows` scans a 128-node sphere (`2 x active_block_range x 16`) per spawn attempt; it is the last filter of `SR.attempt` (spawn_regions.lua:933, 1078) so its frequency belongs to the spawn package's budget.
- `zero_asset_variants.lua:271`: comment "hostile cave-bat tint and swarm dive"; there is no dive behaviour, only `group_attack`.
- `levels.lua:8-13`: the header formula omits the `grug_mob_damage_scale` multiplier (default 1.5) that `stats_for` applies (levels.lua:127-141).
- `routes.lua:850`: `route_walk` keys the cached leg by table identity of `from`/`to`; correct for both callers (they pass persisted point tables), but a future caller building fresh tables per tick would rebuild the leg every second.
- `npc_doors.lua:104-110`: any unowned door near a walker's ends is opened; only settlement walkers/post guards use it (DOOR_WALKS, patrol.lua:182), and player building is protected there, so no player door is reachable in practice.
- (verifier) `verbs.lua:80-84` justifies `players_near` with "on a small server"; at the 100-player target the spatial-index query (`activeobjectmgr.cpp:128-143`) may be the cheaper choice for small radii. Worth a measurement before more code copies either pattern.

## Good to know

- The mobs_redo `do_punch` contract is used correctly: the wrapper returns `true` only for the deliberate cancels (stunned hitter, evade) and otherwise passes the old do_punch's result through (init.lua:768-819); all irreversible hit work sits behind `accepted_player_punch` after both cancel gates (`mobs/api.lua:3309-3337`).
- `self.temp` is the only non-serialized store and the package respects it: all countdowns that must not survive (wind-up, evade, trail, walks, door holds, swim scan) live there; the root/slow/stun countdowns are deliberately persisted and self-heal (init.lua:403-414).
- ObjectRefs held across steps are re-validated: `liveness.lua:62-67` (get_pos), the participation weak sets (init.lua:183-191, get_luaentity), the poison chain re-fetches by name with a generation (verbs.lua:224-293). There is no other `core.after` in the package.
- Terrain-damage guard: no file in the package writes or removes nodes; the only node changes are the door toggles of `npc_doors.lua` (the recorded exception, restricted to the `amble`/`post` walks and the settlement route cache) and `door_click.lua`, which hands a player's own click to the door's `on_rightclick` (protection applies).
- `get_properties()` remains only in non-step paths: `place_on_ground` (placements, the evade teleport, snaps), `levels.lua` fallbacks when `hp_max` is unset, `env_damage.lua pool()` fallback, `room.lua mob_stuck` fallback when `_grug_cbox` is missing, and the target frame (MOB1-07).
- Every path search in routes.lua goes through `nav.claim_search` + `nav.search` and waits (never "no route") while its box is unloaded; failed legs are remembered until restart by design (routes.lua:38-44).
- Prototype-level installs (`do_attack` wrapper, `set_animation` wrappers for fliers/swimmers, swimmer `on_step`, `_grug_target_veto`) are the cheap pattern here; MOB1-03 proposes moving the remaining per-step field installs to it.

## Refuted

(none)
