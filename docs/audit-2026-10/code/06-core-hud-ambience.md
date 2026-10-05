# C6 — Core, per-player globalsteps, HUD, ambience, visuals, map

**Scope.** `mods/CORE/grug_core/` (26 files, 8,640 lines), `mods/CORE/grug_ambience/`
(3 files, 1,169), `mods/CORE/grug_sounds/` (309), `mods/PLAYER/grug_visuals/` (7 files,
2,071), `mods/PLAYER/grug_map/` (10 files, 2,826). About 15,000 lines of Lua.

**Baseline.** `0f169898` (main). No file in scope changed in the working tree while I
read it (`git diff --stat 0f169898` was empty for these paths).

**Method.**
- **Read in full:** every globalstep owner in scope (feed, combat_hud, flash, status,
  status_icons, hud_layout, tag_carrier, atmosphere, atmosphere_zones, movement,
  environment_damage, water_guard, protection, starts_preload, preparation_plan,
  zone_authority, combat_ray, homing, death_messages, item_names, combat_debug), all of
  grug_sounds and grug_ambience, grug_visuals `apply`, `compose`, `creation` and
  `enchant`, and grug_map `minimap`, `minimap_view`, `location`, `location_view`,
  `page`, `providers` and `atlas`.
- **Read in part:** `combat.lua`: the stat stubs, the equipment seam, the combat state,
  threat, the hp-change pipeline and absorbs. Its damage maths was out of scope.
  `base.lua`: its cache key and install path; the renderer was skimmed.
  `settlement_sockets.lua`: its queries.
- **Engine claims** were checked in `reference_projects/luanti`: hud_change, set_properties,
  set_inventory_formspec, sound fade and cleanup, dynamic media, swap_node and the liquid
  queue, and entity on_step and on_detach.
- **Followed outside scope** only where a seam of this lane leads: grug_repair durability,
  grug_inventory page refresh, grug_pvp sampling, and the grug_abilities crosshair cadence.
- **Measured** with LuaJIT in the scratch directory, no engine:
  - `tools/r27_minimap/bench_glide.lua` on HEAD gives 4.9–7.8 µs of minimap work per
    player-step;
  - the `grug_zones` wrapper overhead is 1.1 vs 1.2 ns compiled and 29 vs 46 ns
    interpreted, so negligible.

**Out of scope.**
- Combat damage maths and ability balance.
- Mapgen and zone classification internals: the `grug_zones` implementation costs are
  the mapgen lanes'.
- The repo-wide globalstep census (C10).
- Inventory page internals beyond the one seam in CORE-01.

## Summary

- **14 globalsteps plus one per-entity `on_step` in this scope.** The minimap and the wield
  entity run on every server step; every other one is throttled. Only the minimap,
  location, status, combat_hud, wield poll, atmosphere clock and environment damage
  visit every player each tick. Atmosphere zones, ambience and the tag carriers use slot
  spreading. The full table is in the hot-path inventory.
- **Every HUD writer keeps its own "last sent" cache.** This matters because
  `hud_change` sends a packet on every call (`l_object.cpp:2026`, verified). There is
  no shared helper: feed, status, location and minimap each have their own diff code,
  and a new HUD writer must copy the pattern.
- **`grug_core` is a stub-override hub.** `get_player_faction`, `get_crit_chance`,
  `get_melee_bonus`, `get_talent_bonus` and others return neutral defaults until a
  PLAYER mod overrides them. Seams such as the equipment change, status sources,
  modifier callbacks and tag visibility run every registered consumer unwrapped and in
  registration order, and that order is load-bearing (`apply.lua:482-489`).
- **The equipment-change seam is a hot path in practice, not a rare event.** Every
  settled swing or cast wears the weapon and notifies it (CORE-01).
- **Statuses are read-with-side-effects.** Any read may expire a status, fire its
  `on_expire` and run the modifier callbacks, which call `set_properties`, `set_hp` and
  a page refresh (CORE-06).
- **Atmosphere and ambience are coupled through the applied preset name.**
  - The ambience bed is chosen from `grug_core.get_atmosphere(name)`, so the two
    atmosphere settings also switch most ambience off (CORE-03).
  - Lighting, sky and cloud presets merge on the engine side: every preset must state
    every field (documented well in `atmosphere.lua:20-31` and
    `atmosphere_zones.lua:12-48`).
- **`movement.lua` is the one physics writer.** It is the only `set_physics_override`
  call site (grep-verified), and must stay so.
- **Sound handles are clean.**
  - Every looped bed, emitter and music handle is faded out (gain 0 removes the
    server's entry, `server.cpp:2424-2441`).
  - The engine drops a leaving peer's sounds (`server.cpp:3127-3134`).
  - All per-player tables in scope are cleared on leave.
  - Particle use is small: 4 to 8 particles per burst.
- **The minimap has two documented trade-offs worth a second look.** It does a full
  update per player per server step (CORE-04). And the client never frees the per-cell
  textures it builds (CORE-05).

## Findings table

| ID | Sev | Category | Title | Location |
|---|---|---|---|---|
| CORE-01 | High | Perf | Every settled swing/cast fires the equipment seam; consumers rebuild the Character formspec, recompose the look, re-apply stats | `mods/ITEMS/grug_repair/runtime.lua:50`, `mods/CORE/grug_core/combat.lua:288`, `mods/PLAYER/grug_inventory/pages.lua:596` |
| CORE-02 | Medium | Bug/Perf | Guarded water boundary can loop forever: flow → Lua revert → engine re-queues → flow, every liquid tick, with block resends | `mods/CORE/grug_core/water_guard.lua:235` |
| CORE-03 | Low | Bug | Turning off `grug_atmosphere_enabled` or `grug_atmosphere_zones` silently mutes all region, night and underground beds and the dragon-island thunder | `mods/CORE/grug_ambience/init.lua:377`, `rules.lua:67` |
| CORE-04 | Medium | Perf | Minimap does a full update for every player every server step, also when nothing moved | `mods/PLAYER/grug_map/minimap.lua:493` |
| CORE-05 | Medium | Perf (client) | Minimap builds a never-freed client texture every 13 nodes (normal) / 16 nodes (high); tens to hundreds of MB per long session | `mods/PLAYER/grug_map/minimap_view.lua:47`, `minimap.lua:313` |
| CORE-06 | Medium | Agent-trap | Status reads expire records and fire `on_expire` + modifier callbacks; unknown modifier keys silently refuse the whole status; `dodge_percent` status term is dead | `mods/CORE/grug_core/status.lua:88`, `:141`, `:216` |
| CORE-07 | Low | Perf/Legacy | Wield entity polls for orphaning in a per-step `on_step`; `on_detach` exists. The 1 Hz wield poll allocates an ItemStack per player even when nothing changed | `mods/PLAYER/grug_visuals/apply.lua:63`, `:87`, `:140` |
| CORE-08 | Low | Perf | `get_properties()` on recurring paths (eye position per crosshair refresh, HP bar per injured mob per second, homing per projectile step, environment damage per player per second) | `mods/CORE/grug_core/combat_ray.lua:356`, `tag_carrier.lua:191`, `homing.lua:25`, `environment_damage.lua:140` |
| CORE-09 | Low | Agent-trap | Seven protection predicates with subtly different meaning | `mods/CORE/grug_core/protection.lua`, `zone_authority.lua:518-537` |
| CORE-10 | Low | Agent-trap | World clock is driven by writing `time_speed` into the global settings every second | `mods/CORE/grug_core/atmosphere.lua:238` |
| CORE-11 | Low | Bug | Positional sounds share one server-wide rate-limit key per event | `mods/CORE/grug_sounds/init.lua:264` |
| CORE-12 | Low | Bug | Dying in the rift's void (any `grug_pool_damage` node) prints a fire death message | `mods/CORE/grug_core/death_messages.lua:209` |
| CORE-13 | Low | Duplication | Three independent per-player zone/territory samplers (location, atmosphere, grug_pvp) | `mods/PLAYER/grug_map/location.lua:292`, `atmosphere_zones.lua:478`, `grug_pvp/init.lua:255` |
| CORE-14 | Low | Duplication | Per-module HUD diff caches and copy-pasted slot schedulers | `feed.lua:81`, `status.lua:376`, `location.lua:330`, `minimap.lua:123`; `atmosphere_zones.lua:515`, `grug_ambience/init.lua:412` |
| CORE-15 | Low | Legacy | Unused exports and compatibility adapters | `mods/CORE/grug_core/zone_authority.lua:413-471`, `status.lua:419`, `movement.lua:647`, `tag_carrier.lua:467`, `atmosphere.lua:128` |
| CORE-16 | Low | Bug | Atmosphere mood and ambience bed run for players in character creation (at the engine spawn), which location deliberately skips | `atmosphere_zones.lua:550`, `grug_ambience/init.lua:420` |

## Findings

### CORE-01 Every settled swing or cast fires the equipment seam, and its consumers do full work

- **Severity:** High. **Category:** Perf, and a contract mismatch.
- **Confidence:** the call chain is Verified. The cost is Plausible: no engine probe was
  run.
- **Location:**
  - `mods/ITEMS/grug_repair/runtime.lua:142-145` and `:33-54`;
  - `mods/PLAYER/grug_inventory/equipment.lua:207-214`;
  - `mods/CORE/grug_core/combat.lua:288-289` and `:347-386`;
  - consumers at `mods/PLAYER/grug_inventory/pages.lua:596-601`,
    `mods/PLAYER/grug_visuals/apply.lua:490-495`,
    `mods/PLAYER/grug_classes/stats.lua:210-212`,
    `mods/PLAYER/grug_abilities/init.lua:1923`, `scout.lua:475` and
    `grug_trinkets/init.lua:155`.
- **What:**
  - **The chain.** `register_on_settled_outgoing_action` → `grug_repair.wear_outgoing`
    → `wear_stack`. That writes the weapon stack and calls
    `grug_inventory.equipment_changed(player, list, "durability_metadata")` on every
    accepted damage, heal or absorb action of a non-creative player. The call reaches
    `grug_core.notify_equipment_change`, which runs all seven consumers.
  - **The seam's contract.** It says consumers "must be idempotent and cheap"
    (`combat.lua:288`). The Character-page consumer says "Rare event"
    (`pages.lua:598`), but it is now per action.
  - **The Character page.** `grug_inventory.refresh` calls `sfinv.set_page` whenever
    `context.page` is the Character or Bags page. That is the normal state: closing the
    Map tab even forces Character (`page.lua:331`). `set_page` runs
    `on_leave`/`on_enter` and rebuilds the whole Character formspec:
    - `preview_model`, which reads live properties;
    - pool breakdowns, armor breakdown, crit, dodge, money, housing status and the home
      text (`pages.lua:172-232`).

    The engine only sends it when the string differs (`l_object.cpp:1748`), so network
    stays small, but the Lua build runs per swing.
  - **grug_visuals.apply.** It ignores the `reason` and does `player_spec`:
    - 4 inventory reads, the affixes, the enchant layers and the cosmetic weapon;
    - the compose key string, the cloak source and an unconditional `set_properties`;
    - `sync_wield`, which builds an ItemStack and serialises it.
  - **grug_classes.apply_stats.** It does a `get_properties()`.
  - **Who already filters.** Only `grug_gear` (`init.lua:809`) and the abilities skin
    clock (`init.lua:1944`, `scout.lua:480`) look at the reason.
- **Impact:**
  - Server CPU scales with players × attack and cast rate (about 1 action/s in a fight).
  - Not measured. A rough guess is a few hundred µs per action for the Character build
    plus the other consumers, which would be several ms/s at 20–50 fighting players.
  - It also runs `on_leave`/`on_enter` of the open page per hit.
- **Better:**
  - **Option (a).** grug_repair notifies the equipment seam only when the broken state
    flips or an item id is first stamped (`runtime.lua:125`). It could publish a
    separate light hook for pure wear.
  - **Option (b).** Each costly consumer returns early on `reason ==
    "durability_metadata"` unless the broken state changed, as `grug_gear` already does.
  - **Option (a) is cleaner.** One place, and the seam keeps its "rare" meaning.
  - **Effort:** S–M.
  - **Risk:** the broken look (Round 35) and broken-weapon damage must still update on
    the flip. Re-run the r35_f broken-look fixture and measure one engine probe (swing
    loop) before and after.
  - **Overlap:** the inventory and items lanes should confirm the consumer list.
- **Verification (phase 2):** Partly confirmed — the CPU chain is real (`grug_repair/runtime.lua:49-52` → grug_quality wrapper `init.lua:1019-1024` → `equipment.lua:207-214` → seven consumers; only grug_gear `init.lua:809`, the abilities swing-clock branch `init.lua:1944` and Scout `scout.lua:475` read the reason, trinkets and visuals filter by list only), but the network amplification is wrong: the engine's `set_properties` only marks properties unsent when the struct actually changed (`reference_projects/luanti/src/script/lua_api/l_object.cpp:1027-1032`, since c524c52ba), so the unchanged `visual_size` write sends nothing, and the Character formspec is deduplicated (`l_object.cpp:1748`); the only per-event packet is the inventory resend any wear write needs. Estimate (engine calls counted, ~0.5 µs per `get_stack`, 1.6 µs per `get_properties` from upstream-workarounds.md, ~6–12 µs LuaJIT `-joff` for the ~3 KB Character string): about 0.25–0.5 ms per weapon-wear event (two 96–128-slot walks dominate) and 0.15–0.3 ms per armour-wear event, i.e. O(players × hits) CPU only, still High at the 100-player target. Also, absorb actions do not wear (`runtime.lua:143`). Same verdict as PLY-01, CMB-02, ITM-01.

### CORE-02 A guarded water boundary can flow and revert forever

- **Severity:** Medium. **Category:** Bug/Perf.
- **Confidence:** Plausible. The mechanism is traced in the engine; how often it occurs
  in a real world is unmeasured.
- **Location:** `mods/CORE/grug_core/water_guard.lua:235-251`. Engine:
  `src/serverenvironment.cpp:654-663` (`swapNode`), `src/map.cpp:223-243`,
  `src/servermap.cpp:459-477` (`ServerMap::addNodeAndUpdate` pushes every liquid or air
  neighbour back onto `m_transforming_liquid`) and `src/server.cpp:782-799` (each
  liquid tick dispatches `MEET_OTHER` → `SetBlocksNotSent` for every modified block).
- **What:**
  1. Water may not flow into protected air (towns, capitals, the immutable sea, a claim's
     arrival cube). Air bypasses `on_flood`, so the engine first transforms the node.
  2. `on_liquid_transformed` then reverts it with `core.swap_node(pos, oldnode)`.
  3. `swap_node` goes through `ServerMap::addNodeAndUpdate`, which re-queues the source
     beside it.
  4. On the next liquid tick (`liquid_update`, about 1 s) the source flows again,
     the transform is reported and reverted, and so on.

  Each round trip:
  - runs the Lua callback (`guarded` → `world_alterable` → `territory_rule_at` +
    claim guards);
  - marks the block modified (saved to disk);
  - resends the whole mapblock to nearby clients, and the flowing node may flash
    visibly.
- **Impact:**
  - Wherever mapgen left a water source beside air on guarded ground that the
    `planned_flow` predicate does not exempt, this runs for as long as the block stays
    loaded, i.e. while a player is near.
  - Typical spots would be a river reaching a capital wall, a town well, or a sea
    cavern under immutable ocean.
  - The Round 11 probe (`docs/research/round11-plan/review/engine-probe-static.md:14`)
    checked that the air is restored, not that the loop stops.
- **Better:**
  - **First, measure.** One engine probe in a capital and on a coast: count the reverts
    per second over a few minutes.
  - **If it loops:**
    - revert flowing water to air only once and remember the position for a short
      time;
    - or stop the source side (`on_flood` cannot be used for air);
    - or turn the guarded air into a non-walkable, floodable `on_flood = true` barrier
      node at generation, so the engine refuses the flow before it mutates anything.
  - **Effort:** M. **Risk:** mapgen water layout.
- **Verification (phase 2):** Confirmed — air takes the floodable branch but skips `on_flood` (`servermap.cpp:1172-1175`, `floodable_node != CONTENT_AIR`), and the callback's `swap_node` runs `addNodeWithEvent` → `ServerMap::addNodeAndUpdate`, which re-queues the node and its six neighbours (`servermap.cpp:457-477`, `g_7dirs`), so the source re-floods the air on the next liquid tick (`liquid_update` 1.0 s, `server.cpp:782-799`, MEET_OTHER block resend). In addition `ReflowScan` on every block loaded from disk (`servermap.cpp:764-767`) re-arms the loop, so it is not limited to fresh terrain; real-world frequency stays unmeasured. The location line is off: the callback is `water_guard.lua:66-81` (the file has 81 lines).

### CORE-03 Turning off the atmosphere silently mutes the ambience

- **Severity:** Medium. **Category:** Bug. **Confidence:** Verified.
- **Location:**
  - `mods/CORE/grug_ambience/init.lua:377-378`;
  - `rules.lua:67-84`, `:88-89`, `:119-121`, `:177`;
  - `mods/CORE/grug_core/atmosphere.lua:278-281`;
  - `atmosphere_zones.lua:497-502`;
  - `settingtypes.txt:15-32`.
- **What:**
  - The bed is chosen from `mood = grug_core.get_atmosphere(name)`, which is the
    **applied lighting preset name**, and only kept if it is a mood.
  - **With `grug_atmosphere_enabled = false`,** `set_atmosphere` returns false and
    `applied` stays nil.
  - **With `grug_atmosphere_zones = false`,** players stay on `default`, which is not a
    mood.
  - In both cases `bed_keys` returns nil ("keep the bed you have"). Because no bed was
    ever started, nothing plays:
    - no region bed and no night bed;
    - no underground bed: "underground" is a mood decided only in `atmosphere_zones`;
    - no dragon-island thunder (`eligible_calls` needs a mood).

    Only the forge, fire and water loops and capital music remain.
  - The setting is documented as a graphics switch ("if a client's post-processing
    pipeline misbehaves", `settingtypes.txt:17-18`).
- **Impact:** an operator who turns off a visual post-effect loses almost all ambience
  with no message. That is uncommon but confusing, and hard to diagnose.
- **Better:**
  - Make the ambience resolve its own "mood key" from the same pure rule (region, ocean,
    battlegrounds, dragon island, underground) without depending on the lighting preset.
  - Or split `atmosphere_zones` into "mood resolution" (always on) and "send lighting"
    (setting-gated), and let ambience read the resolved mood.
  - **Effort:** S. **Risk:** the `/atmosphere <mood>` A/B behaviour that drives the bed
    (`init.lua:38-41`) should keep working.
- **Verification (phase 2):** Confirmed, severity changed to Low — the chain holds (`grug_ambience/init.lua:377-378`; `rules.lua:67-84` returns nil with neither mood nor water; `set_atmosphere` returns false when disabled, `grug_core/atmosphere.lua:278-281`; the zone driver returns at `grug_core/atmosphere_zones.lua:497`, leaving players on the `default` preset). But both settings default to true and only a deliberate operator switch triggers it, and sea, stream and underwater beds still play near water (`bed_keys` adds them without a mood), so the impact is narrower than stated.

### CORE-04 The minimap does a full update for every player on every server step

- **Severity:** Medium. **Category:** Perf.
- **Confidence:** Verified (code). The cost is measured: 4.9–7.8 µs per player-step with
  the LuaJIT stand-in (`tools/r27_minimap/bench_glide.lua`, run on HEAD), and 11–25 µs
  per player-step in the engine according to the Round 32 study
  (`docs/research/perf-review-2026-10-r32.md:117`, `:147`).
- **Location:** `mods/PLAYER/grug_map/minimap.lua:493-511` and `:299-406`.
- **What:** the globalstep calls `update(player, state, slow, window)` for every
  connected player every step. Every call does:
  - `get_pos`;
  - the cell and base pixel;
  - a `V.place` for each static marker near the cell;
  - a `get_player_by_name`, `get_pos` and `get_look_horizontal` per party member;
  - a `show()` per marker slot (24) and party slot (9).

  Nothing is skipped when the player and all party members stood still. The Round 32
  study recommended "update only players who moved or turned"; it is still open.
- **Impact:**
  - Linear in players times steps (about 11 steps/s on a dedicated server): about 10–25
    ms/s at 40–100 players.
  - Per the Round 32 study this is one of the two largest steady per-player costs. It
    is not a stall, just steady load.
- **Better:**
  - Cache the last own position (whole base pixel) and the party members' last
    positions and heading frames.
  - When nothing changed and neither `slow` nor `window` is due, return early.
  - **Effort:** S. **Risk:** low. The bench and `tools/r27_minimap/portable_test.lua`
    cover it.
- **Verification (phase 2):** Confirmed — the globalstep (`minimap.lua:493-511`) calls `update()` for every connected player every step and `update()` (`:299-406`) has no early return for an unchanged position or heading; `show()` (`:123-146`) only suppresses HUD packets, not the Lua work (`V.place` per near marker, `get_player_by_name`/`get_pos` per party member). The R32 study measured 22.9–24.7 ms/s at 100 stand-ins (`docs/research/perf-review-2026-10-r32.md:147`); an early-out helps only players who stand still.

### CORE-05 The minimap's client textures are never freed and accumulate per cell

- **Severity:** Medium. **Category:** Perf, on the client.
- **Confidence:** Plausible. The engine behaviour is documented in
  `docs/design/world_map.md:220-224`; the sizes below are my arithmetic from
  `minimap_view.lua`, not measured.
- **Location:** `mods/PLAYER/grug_map/minimap_view.lua:47` (`V.GRID`), `:65-82`,
  `:101-112`; `minimap.lua:313-319`.
- **What:**
  - Each grid cell has its own `[combine…^[mask:…` texture string, and the Luanti
    client keeps every generated texture until disconnect.
  - **Round 32 effect.** The zoom took the normal grid from 6 to 2 base pixels
    (`minimap_view.lua:40-46`). That gives a new texture every 13.3 nodes walked, three
    times as often as before.
  - **Normal.** About 72×72 RGBA, about 21 KB each: about 1.6 MB per 1,000 nodes
    travelled.
  - **High.** 120×120 after `[resize`, about 58 KB, every 16 nodes: about 3.6 MB per
    1,000 nodes.
  - **An hour of riding or flying** (8–12 nodes/s, so 30–40 k nodes) is on the order of
    50–60 MB of textures at normal and 110–145 MB at high, minus revisited cells.
- **Impact:** desktop clients may cope. The web build (WebGL memory) and low-end GPUs
  are the risk on long sessions. It is not visible as an error.
- **Better:**
  - A user decision: this is an accepted trade-off that Round 32 made larger. Options:
    - a coarser grid at high quality;
    - a larger bezel overlap;
    - snap the texture origin to a coarser grid (fewer distinct strings) while keeping
      the glide inside a bigger texture.
  - Measure client memory once on the web build after a long ride.
  - **Effort:** M.
- **Verification (phase 2):** Confirmed — the client's `TextureSource` keeps every generated texture in `m_textureinfo_cache` with no eviction until it is destroyed (`client/texturesource.cpp:162`, `:215-219`), and `minimap_view.lua` builds one `[combine…^[mask` string per grid cell (`V.GRID` `:47`, `V.texture` `:101-112`). Recomputing `V.new` gives the stated sizes (72×72 ≈ 21 KB normal, 120×120 ≈ 58 KB high); it is a documented trade-off (`docs/design/world_map.md:220-224`) whose real memory cost is unmeasured.

### CORE-06 Status reads have side effects

Status reads expire records and fire callbacks, and a wrong modifier key refuses the
whole status silently.

- **Severity:** Medium. **Category:** Agent-trap. **Confidence:** Verified.
- **Location:**
  - `mods/CORE/grug_core/status.lua:62-78` (`remove_status`), `:88-98`, `:189-197`,
    `:216-241`, `:137-150`;
  - `mods/PLAYER/grug_inventory/equipment.lua:676`;
  - `mods/PLAYER/grug_classes/stats.lua:150-154`.
- **What:**
  - **Expiry happens on read.** `get_status`, `each_status`, `status_effects` and
    `status_modifier_sum` all expire due records. Expiring calls `on_expire` and,
    when modifiers are involved, every `register_on_status_modifiers_changed`
    callback: `grug_classes.apply_stats` (`get_properties`, `set_properties`,
    `set_hp`), `grug_inventory.refresh` (a formspec build) and `grug_abilities`.
  - **The damage pipeline reads statuses.** `status_modifier_sum("armor")` is called
    from `get_armor_rating`, and therefore from inside the `register_on_player_hpchange`
    modifier (`combat.lua:1843` → `apply_player_armor`). A read on the damage path can
    therefore run `set_hp` re-entrantly.
  - **Silent refusals.** `set_status` returns nil without a log for:
    - an unknown modifier key;
    - `duration` together with `untimed`;
    - only one of `on_tick`/`interval`.
  - **A dead term.** `dodge_percent` is not in `MODIFIER_KEYS`. So
    `grug_classes.get_dodge_chance_raw`'s `status_modifier_sum(player,
    "dodge_percent")` always returns 0: dodge comes only through absorb modifiers.
  - **Death skips `on_expire`.** `clear_runtime_statuses` on death does not call it.
    Each owner needs its own dieplayer cleanup; grug_alchemy does
    (`effects.lua:173-177`).
- **Impact:** no live bug found. An agent adding a status with an "obvious" key, or a
  status read in a new hot path, gets silent misbehaviour or re-entrant HP writes.
- **Better:**
  - Log once per unknown key in `set_status`.
  - Remove the dead `dodge_percent` term, or add the key deliberately.
  - Add a header note listing which calls may fire callbacks.
  - Optionally move expiry to the 2 Hz pass only, and let reads filter expired records
    without removing them.
  - **Effort:** S.
- **Verification (phase 2):** Confirmed — `get_status`/`each_status` (and so `status_modifier_sum`) expire records and run `notify_modifier_change` + `on_expire` (`status.lua:62-78`, `:189-197`, `:216-241`); `set_status` returns nil without a log for an unknown modifier key, untimed + duration, or half an `on_tick`/`interval` pair (`:110-150`); `MODIFIER_KEYS` (`:21-27`) lacks `dodge_percent`, so `grug_classes/stats.lua:153` always adds 0 and no `set_status` caller in `mods/` passes it. The re-entrant `set_hp` needs an armour-status expiry to coincide with a damage read and only clamps HP (`stats.lua:175-183`), so "no live bug" stands.

### CORE-07 The wield entity checks for orphaning in a per-step on_step

The wield entity runs a Lua `on_step` every server step only to notice it was orphaned,
and the 1 Hz wield poll allocates on every call.

- **Severity:** Low. **Category:** Perf/Legacy. **Confidence:** Verified.
- **Location:** `mods/PLAYER/grug_visuals/apply.lua:43`, `:63-72`, `:87-103`,
  `:140-143`, `:433-447`. Engine: `doc/lua_api.md:5860-5863` (`on_detach`, "also
  called before removal"), `src/server/unit_sao.cpp:300-313`.
- **What:**
  - **The orphan poll.** Every wield entity (each player and each armed guard, bandit,
    king or vendor) has an `on_step` that adds `dtime` and checks `get_attach()` once a
    second. Any registered `on_step` costs a `lua_pcall` per entity per step
    (`s_entity.cpp:215-244`). A killed guard's sword floats for up to 1 s.
  - **The 1 Hz poll.** It calls `sync_wield`, which always calls
    `grug_visuals.wield_appearance(stack)`: a new ItemStack, 6 meta writes and
    `to_string`. That happens before the "unchanged" compare, while the comment at
    `:426-429` promises "one string compare".
- **Impact:** small, but it scales with armed NPCs near players × steps, plus one
  allocation per player per second.
- **Better:**
  - Replace the poll with `on_detach = function(self) self.object:remove() end`. The
    entity is never legitimately re-attached: `sync_wield` removes it and spawns a new
    one.
  - In `sync_wield`, compare the wielded item string first and build the appearance
    only on a change.
  - **Effort:** S.

### CORE-08 get_properties() on recurring paths

- **Severity:** Low. **Category:** Perf. **Confidence:** Verified.
- **Location:**
  - `combat_ray.lua:356` (`combat_eye_pos`, only for `eye_height`; called on every
    crosshair refresh at 0.15 s per player, `grug_abilities/init.lua:2442`, and on every
    aim);
  - `tag_carrier.lua:191`/`:246` (`bar_height_and_scale` per injured, observed mob per
    carrier pass, i.e. 1 Hz) and `:225`;
  - `homing.lua:25` (`target_center` per homing projectile per step);
  - `environment_damage.lua:140` (1 Hz per player).
- **What:** AGENTS.md says "no `get_properties()` in per-step code". These are not
  per-step mob code, but they recur and each allocates the full property table.
- **Impact:** low. It is GC pressure that grows with players and fights.
- **Better:** cache `eye_height` per player (it changes only on model or mount changes);
  cache the bar geometry until `sync_tag_carrier_box`; read the target box once per
  homing lock. **Effort:** S.

### CORE-09 Seven protection predicates with subtly different meanings

- **Severity:** Low. **Category:** Agent-trap. **Confidence:** Verified.
- **Location:** `mods/CORE/grug_core/protection.lua:39-155` and
  `zone_authority.lua:490-537`.
- **What:**
  - **The predicates:**
    - `core.is_protected` (dig and place; bypass privilege first);
    - `world_protected_for_faction` (zone rule plus roads and POIs);
    - `zone_protected_for_faction` (zone rule only);
    - `interaction_protected` (world rule plus claim guards, no dig/place handlers);
    - `ground_effect_protected` (creature effects: zone rule, then the wrapped
      handlers);
    - `world_alterable` and `natural_renewal_allowed` (system mutations, territory
      only).
  - **The traps:**
    - some fail closed before installation and some do not;
    - `world_feature_boxes_in` returns true before installation (`zone_authority.lua:508`);
    - the bypass privilege is honoured by some and not others.

  The memory rule "towns and POIs never damaged" depends on picking the right one.
- **Impact:** a new fire, explosion or terrain lane can pick a predicate that lets it
  damage a road or POI, or refuse inside a claim.
- **Better:** a table in the module guide: who asks, what it covers, and how it behaves
  before installation. Also a single `grug_core.may_alter(pos, actor, kind)` facade
  for new code. **Effort:** S (docs) / M (facade).

### CORE-10 The world clock writes the global time_speed setting every second

- **Severity:** Low. **Category:** Agent-trap. **Confidence:** Verified.
- **Location:** `mods/CORE/grug_core/atmosphere.lua:234-268`.
- **What:**
  - Day and night speeds are applied by `core.settings:set("time_speed", …)`. It is
    re-asserted every second whenever the live value differs.
  - An admin `/set time_speed` or a test that changes it is overwritten within a second.
  - The shutdown hook restores the operator's value, but only on a clean shutdown.
  - No other mod reads `time_speed` (grep).
- **Impact:** surprising for testing and administration. The comment explains it.
- **Better:** document it in the module guide. Optionally add a
  `grug_core.set_clock_override` seam for tests. **Effort:** S.

### CORE-11 Positional sounds share one rate-limit key per event, server-wide

- **Severity:** Low. **Category:** Bug. **Confidence:** Verified.
- **Location:** `mods/CORE/grug_sounds/init.lua:262-273`.
- **What:**
  - A position target uses `key = "pos"`, so the `interval` limit is global per event.
  - `ice_break` (interval 1 s) plays at most once per second across both dragon arenas.
  - Two players' `fishing_cast`/`fishing_catch`, or two `dragon_lightning` strikes
    within 0.1 s anywhere, drop the second.
- **Impact:** rare missing sounds.
- **Better:** key positions by a coarse cell, e.g. `floor(pos/8)` hashed. **Effort:** S.

### CORE-12 The rift void's death message talks about fire

- **Severity:** Low. **Category:** Bug. **Confidence:** Verified.
- **Location:** `mods/CORE/grug_core/death_messages.lua:94-97` and `:209-210`;
  `mods/ENTITIES/grug_mobs/rift.lua:66-69`.
- **What:** the rift void is an engine `node_damage` node (`damage_per_second`, group
  `grug_pool_damage`). Every `node_damage` death prints "got far too familiar with
  fire" or "found the hot side of the world".
- **Impact:** wrong flavour text in chat for Round 36's rift.
- **Better:** a `void` category for `grug_pool_damage` nodes, i.e.
  `core.get_item_group(reason.node, "grug_pool_damage") > 0`. **Effort:** S.

### CORE-13 Three independent per-player zone and territory samplers

- **Severity:** Low. **Category:** Duplication. **Confidence:** Verified.
- **Location:**
  - `mods/PLAYER/grug_map/location.lua:292-295` and `:313-326` (1 Hz: `id_at`, town box
    plus `hard_footprint_in`, and the territory via `grug_pvp.territory_at` →
    `pvp_rule_at` + `faction_at`);
  - `mods/CORE/grug_core/atmosphere_zones.lua:466-491` (`id_at` every 2 s);
  - `mods/PLAYER/grug_pvp/init.lua:255-267` (the same `pvp_rule_at` + `faction_at` at
    1 Hz, own phase).
- **What:** the same "where is this player" question is asked three times, at different
  phases.
- **Cost.** It is negligible: the perf review measured `id_at` at 0.06–0.25 µs.
- **Consistency.**
  - The banner and minimap territory colour can disagree with the PvP flag state for
    up to 1 s.
  - The sky mood changes up to 2 s after the zone banner.
- **Impact:** cosmetic lag. It adds three places to edit when the zone rule changes.
- **Better:** one per-player location record in grug_map (zone id, town, capital,
  territory, underground), refreshed once per second. grug_pvp and the atmosphere read
  it, and grug_pvp keeps its own depth rule input. **Effort:** M. **Risk:** PvP's
  "never on the combat path" rule is unaffected.

### CORE-14 Duplicated HUD diff caches and slot schedulers

- **Severity:** Low. **Category:** Duplication. **Confidence:** Verified.
- **Location:**
  - **HUD diff caches:** `feed.lua:81-108`, `status.lua:376-388`,
    `location.lua:330-346` and `minimap.lua:123-175` each keep their own "last sent"
    cache.
  - **Slot schedulers:** `atmosphere_zones.lua:504-555` and `grug_ambience/init.lua:409-429`
    carry the same 8-slot join-counter code ("As atmosphere_zones.lua").
    `location.lua:361-368` and `minimap.lua:464-473` use the same JOIN_PHASE scheme.
- **Impact:** an agent writing a new HUD element or a per-player pass must copy one of
  these patterns. A forgotten diff costs a packet per call.
- **Better:** a tiny `grug_core.hud_element(player, def)` with `set(field, value)` that
  diffs, and a `grug_core.player_slots(n, period)` helper. **Effort:** S–M. Not urgent.

### CORE-15 Unused exports and compatibility adapters

- **Severity:** Low. **Category:** Legacy. **Confidence:** Verified (grep over `mods/`
  and `tools/`).
- **Location:**
  - **Unused compatibility adapters:** `zone_authority.lua:413-415`, `:457-471`. These
    are `grug_core.surface_level_at`, `guard_level_at`, `open_sea_at`, `territory_at`
    and `zone_at`, with zero callers; grug_mobs uses `grug_zones.guard_level_at`
    directly. `validate_session` still demands the compatibility payload with all seven
    functions (`:165-174`).
  - **Other unused exports:**
    - `grug_core.refresh_status_hud` (`status.lua:419`);
    - `grug_core.reassert_movement` (`movement.lua:647`);
    - `grug_core.is_tag_carrier` (`tag_carrier.lua:467`).
  - **A dead preset key:** the `hearthpine` preset's `zone` key, "nothing reads this
    key yet" (`atmosphere.lua:128-132`).
- **Impact:**
  - **Name clashes.** `grug_core.territory_at`, `grug_pvp.territory_at` and
    `grug_zones.territory_rule_at` are three different things with similar names.
  - **Dead code.** It invites a new caller onto the wrong one.
- **Better:** remove the unused adapters, and the matching payload checks if mapgen does
  not need them. Remove the unused exports and the dead key. **Effort:** S.

### CORE-16 Atmosphere and ambience run during character creation

- **Severity:** Low. **Category:** Bug. **Confidence:** Verified.
- **Location:** `atmosphere_zones.lua:520-535` and `:550-553`;
  `grug_ambience/init.lua:372-407`. Compare `location.lua:390-394`, which skips players
  in `player_in_creation_stasis`.
- **What:** while a character is being created, the player stands at the engine spawn.
  The mood and the bed of that spot are applied (sky, fog, clouds and loops), although
  the location line deliberately names nothing.
- **Impact:**
  - The creation window's background shows the spawn spot's mood, e.g. the
    battlegrounds near 0,0.
  - It also triggers a second set of lighting, sky and cloud packets on release.
- **Better:** skip `evaluate` for players in creation stasis in both drivers. **Effort:**
  S.

## Hot-path inventory

The cadence is per globalstep. "All players" means a loop over
`core.get_connected_players()`.

**Cost classes:**
- **trivial:** under 1 µs per player-tick;
- **small:** a few µs;
- **moderate:** tens of µs, or allocation-heavy;
- **event:** runs only on events.

| Path | Cadence | Per tick | Cost class | Notes |
|---|---|---|---|---|
| `grug_map/minimap.lua:493` | every step, all players | full update (CORE-04) | moderate: 5–8 µs stand-in, 11–25 µs engine | the largest steady cost in scope |
| `grug_visuals/apply.lua:63` wield `on_step` | every step, per wield entity | dtime add | trivial each, many entities | CORE-07 |
| `grug_core/movement.lua:682` | 0.1 s, players with state only | prune + combine + write if changed | trivial | idle server: one `next()` |
| `grug_core/feed.lua:241` | 0.1 s, players with lines only | expiry + diff render | trivial | |
| `grug_map/location.lua:382` | 0.1 s loop; sample 1 Hz per player (phased) | `id_at`, town box, footprint, pvp territory; banner diff | small (2–8 µs per sample per the R32 study) | CORE-13 |
| `grug_map/page.lua:388` | 0.1 s, Map-tab viewers only | ≤8 signatures, ≤2 builds per pass | moderate per build (large formspec, ~200 markers) | by design, Round 30/32 |
| `grug_core/tag_carrier.lua:370` | 8 slots/s; each carrier 1 Hz | observers (carriers × players) + HP bar | small per carrier; `get_properties` per injured, observed mob | known R30 #10; CORE-08 |
| `grug_core/combat_hud.lua:9` | 0.2 s, all players | `in_combat` (O(1)) + add/remove | trivial | |
| `grug_core/status.lua:463` | 0.5 s, all players | `each_status` ×3 + sources + 2 sorts + diff | small, with allocations | CORE-06 |
| `grug_core/atmosphere_zones.lua:537` | 0.25 s slot; each player per 2 s | `id_at` + cached mood; packets on change | trivial | CORE-16 |
| `grug_ambience/init.lua:412` | 0.25 s slot; each player per 2 s | mood, town, music step, `get_node_raw` ×1, `find_nodes_in_area` 25×11×25 above ground | small to moderate near rivers (hundreds of positions) | sound packets only on change |
| `grug_core/atmosphere.lua:256` | 1 s, all players | clock and day-night ratio, sent on change | trivial | CORE-10 |
| `grug_core/environment_damage.lua:131` | 1 s, all players | `get_properties`, `get_node`, privileges, breath, armor groups | small | CORE-08 |
| `grug_visuals/apply.lua:433` | 1 s, all players | wielded item + `sync_wield` (allocates) | small | CORE-07 |
| `grug_core/starts_preload.lua:164` | every step | after "ready": two compares | trivial (100 ms budget while preparing, boot only) | |
| `grug_core/combat.lua:1783` hp modifier | per HP loss | dodge, pressure, armor (status sum), fall/lava pool, absorb sort | small, event | |
| Equipment seam `combat.lua:347` | per settled swing or cast (durability) | 7 consumers incl. a Character formspec build | moderate to high, event × players | CORE-01 |
| `grug_core/water_guard.lua:235` | per liquid tick batch | per water position: territory rule + guards | small per position; possible loop | CORE-02 |
| `grug_core/combat_ray.lua` | per aim (crosshair 6.7 Hz/player, swings, casts, target frame) | engine raycast + `get_objects_in_area` (margin ≥5) for rotated boxes | moderate | the R35 upstream workaround |
| `grug_sounds.play` | per game event | limiter + one `sound_play` | trivial | CORE-11 |
| Music push (`grug_ambience/init.lua:332`) | per track per player in a capital (2–7 min) | engine re-reads, SHA-1s and copies the 0.7–3.9 MB file on the main thread (`server.cpp:3836`, `:3874`) | small spike (a few ms, estimated) | Noted |

## Bug-prone areas

- **The equipment-change seam** (`combat.lua:275-386`). It has two-pass re-entrancy
  handling, an order-dependent consumer list, a `reason` argument that most consumers
  ignore, and a call frequency that changed under it when durability arrived (CORE-01).
- **`status.lua` expiry.** Reads mutate. The pending-tick rule (`should_expire`) keeps a
  record alive past expiry until its last tick. `on_expire` is skipped on death and on
  `clear_status`.
- **Engine merge semantics in `atmosphere*.lua`.** Lighting, sky and clouds merge into
  the previous values. Every new preset field must be stated in every preset, or
  switching inherits it. The header documents the traps, but they are easy to forget.
- **Minimap pixel geometry** (`minimap_view.lua`). Whole-pixel snapping, grid and scale
  coupling, the bezel overhang and the `[resize` one-pixel-short trick. Tested by
  `tools/r27_minimap`, but any change to GRID, WINDOW_NODES or the bezel art ripples
  through all of it.
- **`grug_ambience` music scheduler** (`rules.lua:244-312`). It is a state machine
  across async push callbacks, holds and timeouts, and is correct as read. It is the
  place most likely to stall if a phase is added.
- **Water guard** (`water_guard.lua`). The two engine boundaries (`on_flood` for
  non-air, liquid-transformed for air) plus the `planned_flow` exemptions, and the
  revert loop of CORE-02.
- **Tag carriers** (`tag_carrier.lua`). These are attached helper entities whose
  lifetime follows a parent the engine detaches but does not remove. Their observer
  sets are shared by reference between the carrier and the HP bar.

## Noted (no action)

- **Token restart on rejoin.** `feed.lua:203` and `flash.lua:38` restart their tokens at
  0 on join. A rejoin within 1.5 or 3 s can let the old session's `core.after` blank a
  new banner or flash with the same token number.
- **Compose cache.** `grug_visuals.compose`'s cache (`compose.lua:211`) has no size
  bound. Keys grow with gear × enchant-colour combinations, bounded in practice.
- **Settlement lookup misses.** `grug_visuals.settlement_race` (`apply.lua:510-520`)
  rebuilds its index, copying every settlement, on each miss for an unknown key. That is
  per NPC activation only.
- **Wrapper overhead.** The `grug_zones` public wrapper (`zone_authority.lua:332-347`,
  a vararg closure behind `__index`) adds 0.1 ns compiled and 17 ns interpreted per
  call. Measured; irrelevant.
- **Suffocation and noclip.** Suffocation exempts any player holding the `noclip`
  privilege, even when not noclipping (`environment_damage.lua:145-147`).
- **Re-entrant HP write.** A status with `hp_pool_percent` expiring during a hit can call
  `set_hp` inside the hp-change modifier. The engine's outer write then clamps to the
  new maximum, so the result is correct; it is recorded under CORE-06.
- **Doubled object count.** Tag carriers double the active-object count (known, Round 30
  #10). HP bars add a third object only while a mob is injured and observed.
- **Music push cost.** Per player, the engine reads, hashes and copies the whole music
  file again on each push (engine behaviour; Lua cannot avoid it short of announcing
  music at join, which the design rejects).

## Open questions for Jan

1. **CORE-01.** Should a weapon wearing down count as an "equipment change" (with the
   Character page rebuilt on every hit), or only when it breaks? The recommendation is
   the latter. A one-time engine probe would quantify it.
2. **CORE-02.** Have you ever seen water flicker at a town or capital edge, or a sea
   cave? May a lane run a short headless probe that counts water-guard reverts in one
   capital and on one coast?
3. **CORE-03.** Should switching off the atmosphere (a graphics fallback) keep the
   ambience beds? I assume yes.
4. **CORE-05.** Is the minimap's client texture growth acceptable for long sessions,
   especially for the web build and `grug_map_quality = high`? Or should the cell size
   go up again?
5. **Rift void damage.** It is soaked by absorb shields, unlike lava and drowning
   (`environment_damage.lua:87-94` lists only fall, drown, engine lava and wrath).
   Intended?
