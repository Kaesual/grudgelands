# WP17 boats and waypoints — plan for Round 29

Design session with the user, 2026-10-02. Input for the Round 29 coordinator
("Economy and travel", `economy-vendor-plan.md` §10). Delivered in Round 29
([completion](#completion-2026-10-02) at the end). The rulings below **supersede** the contrary parts of `boats.md`,
`world.md` §2b/§6, `items_crafting.md` §3.0.5, `biomes_mobs.md` §3.1 and the
WP17 scope card; lane D folds them into those files.

## 1. Rulings (user, 2026-10-02)

| # | Ruling | Why |
|---|---|---|
| 1 | **Boats work exactly like mounts.** A boat is a water mount: an owner-bound skill item, recoverable from the Skills page, used to embark and used again to disembark. **An empty boat never exists in the world.** | One lifecycle instead of two; no litter, no decay timer, no theft or pickup rules, no item/entity persistence. The old placed-item design of `boats.md` §3 is retired. |
| 2 | **The dragon islands are reachable by boat only.** Flying mounts stay forbidden over every ocean column, including the dragon channels, and on both islands. | Matches `mounts.md` §4.1/§4.2 and the shipped flight code (`grug_mounts/entity.lua:126-146`). The Round 28 frame's "reachable with flying mounts from level 45" (`round28-design-frame.md` §2.1) is wrong and gets corrected. |
| 3 | **The shipwright sells the base boat (4 nodes/s) from level 15 and the improved boat (8 nodes/s) from level 30**, each for a copper price set by economy lane E4 (references: Riding Apprentice and Journeyman). No materials, no recipe, nothing at character creation. *(Revised the same day: an earlier draft gave every character the base boat at level 1.)* | Players should stay in their starting region at first and not be nudged into travelling by owning a boat. Level 15 is the first riding step too, so both travel unlocks arrive together on the same capital trip. Same shape as the Riding Trainer: one purchase each, permanent per-character state, gold sink. |
| 4 | **One shipwright in every capital** (six), standing at the capital stable next to the Riding Trainer. The old one-per-continent shipwright in a level-21–30 village (`boats.md` §2) is retired; the two existing display hulls (Whitebridge Market Close, Whisperreed Landing) stay as scenery. | Players come to the capital for riding at 15 anyway; one socket in the shared stable design (`wp13/capital_services.lua:80`) places all six at once. No race has to cross into another race's region for a boat. |
| 5 | **A boat can be summoned only in water**: the player stands or swims in water (feet in a water node). Normal water and river water, source and flowing, all count (`group:water`); every water body works — rivers, lakes, bays, shelf, deep ocean, channels. No docks. | Simplest rule; no mapgen for harbours. |
| 6 | **Waypoints are a waystone node placed by the mapgen** at the centre of each waypoint pad, in all six capitals and all six starts. Right-click opens travel; being near it unlocks it. | A node is the cheapest clickable, visible object; no entity activation or duplicate protection. The mapgen bundle runs anyway. |
| 7 | **The Kraken Guard swims 10 nodes/s inside deep-ocean columns and 5 everywhere else; `view_range` 40.** The current simple leash stays (drop the target and hold once the guard is outside deep ocean). The residual-allowance pursuit model of `world.md` §2b is dropped. | With rule 1 a single hit ejects the rider into the water, so a guard that can reach a boat makes the deep ocean deadly as designed. 10 > 8 closes the improved-boat escape. The simple leash already keeps channels and shelf safe; the elaborate model bought nothing visible. |
| 8 | **A boat that loses contact with water disappears.** Once per second each active boat checks its own node and the node below for `group:water`; if neither is water, the boat is removed and the rider disembarks. | One or two node reads per active boat per second; covers waterfalls, dug-out water and any other way off the water without special cases. |

### 1.1 Defaults proposed in this session (confirmed by the user, 2026-10-02)

Boats (all follow from ruling 1 and the mount contract, `mounts.md` §3):

- Boats live in `grug_mounts` as a third movement mode, **water**, next to
  land and flight: two tiers, base boat and improved boat. One active mount
  *or* boat per player; using a boat item while mounted replaces the mount the
  same way switching mount tiers does.
- Items: `stack_max = 1`, `grug_bound_skill`, owner meta, deleted on drop,
  never tradeable or stored externally; recovered from the Skills page.
  Each boat item is handed over at purchase, like a riding tier; afterwards
  the mount rule applies (no automatic re-insertion, manual recovery from
  Skills). Buying the improved boat keeps the base boat.
- Summoning is refused in combat (`grug_core.in_combat`), out of water
  (ruling 5), and while dead. A mounted/boated player cannot use
  abilities, casts or swings (existing mount block).
- The boat entity moves only on the water surface at entity velocity
  (never `physics_override.speed`), accelerates and brakes, A/D strafe as on
  mounts, no step-up onto land (step height 0). Ruling 8's once-per-second
  water-contact check removes it when it leaves the water.
- **Disembarking** removes the entity and places the player on a free land
  node within 2 nodes if one exists, otherwise in the water at the boat's
  position.
- **Any damage ejects** (both seams: the entity's `on_punch` forwards to the
  rider, and the player HP-change observer — the mount pattern,
  `grug_mounts/entity.lua:375-390, 510-514`). The boat vanishes; the player
  is in the water. Death, logout and shutdown disembark exactly as mounts do.
- Status icon row shows a boat icon while boating; Character Effects shows
  the tier and speed.

Shipwright:

- One per capital (ruling 4), at the shared stable beside the Riding
  Trainer. Passive, invulnerable service NPC; sells nothing else, buys
  nothing.
- Dialogue in the Riding Trainer format (Round 28 ruling 19): two rows,
  **Boat** (level 15) and **Improved Boat** (level 30, requires Boat), each
  Owned / **Buy <price>** / greyed **Requires level N** / greyed **Learn Boat
  first** / greyed **Price pending** (until E4 sets the price). Own faction
  only, the same `permitted` check as the Riding Trainer.

Waypoints:

- Network per faction: its three starts and three capitals (six
  waystones). Enemy waystones are inert for the player: no unlock, no use,
  a short message on right-click.
- **Unlock by visiting:** standing within 8 nodes (horizontal, ±8 vertical)
  of an own-faction waystone, checked once per second in a throttled
  globalstep against the twelve socket positions, or by right-clicking it.
  One flash/chat line "Waypoint discovered: <name>". The character's own
  start is unlocked at creation. Per-character list in player meta.
- **Right-click** opens a formspec listing the six own-faction waypoints:
  "You are here", **Travel** (discovered), greyed "Not yet visited".
- **Travel**: instant, free, no cooldown, only from a waystone to a waystone,
  alive and out of combat. It disembarks/dismounts first, emerges and
  validates the arrival exactly like innkeeper return (`grug_home/travel.lua`:
  `prepare`/`safe_arrival`/`finish`), and arrives on the destination pad next
  to the waystone. A failed preparation charges nothing (there is nothing to
  charge) and leaves the player in place with a message. It does not touch
  the 30-minute home cooldown.
- **Map:** discovered waypoints appear as a new marker kind `waypoint` on the
  atlas and the minimap (provider like "home", `grug_map/providers.lua:101-116`;
  minimap `SHOWN`/`KIND_TEXTURE`, `minimap.lua:45-52,193`). Undiscovered
  ones are not shown. Map markers never unlock travel (`world_map.md`).
- No `/unstuck` (WP audit B3).

## 2. Scope

**In:** boats as water mounts (two tiers), the shipwright and its purchase,
the Kraken retune of ruling 7, waystones with unlock/formspec/travel/map
markers, the mapgen items of §4, the documentation of §6.

**Out:** docks, harbours, piers, landing structures on the islands,
passengers, boat inventories, boat combat, currents, zone-hub waypoints,
Nether crossings (V2), any change to flight rules, island content (Round 28
writes island quests and bounties).

## 3. What already exists (verified 2026-10-02)

- Capitals: a kerbed waypoint plaza with a stone cross drawn into the floor,
  nothing above it, and one published `travel_waypoint` socket (role
  `waypoint`) each: `wp13/highcourt.lua:346,841`, `lethariel.lua:132,769`,
  `dur_brannoc.lua:85,737`, `gor_drazhak.lua:84,917`,
  `nhal_veyr.lua:96,932`, `kezamba.lua:81,763`. Sockets reach runtime through
  `r7_loader.lua:170-209` → `grug_core.register_settlement_sockets`
  (`settlement_sockets.lua:232`; role whitelist `:32`; lookups `:282-309`).
- Starts: **no pad, no socket** (`start_npcs.lua:22` reserves the role
  "waypoint — nothing").
- Shipwright: no NPC, no socket. Two display hulls exist as scenery
  ("Fixed display hull, no vehicle/entity", `r20_poi_blueprint.lua:124-127`,
  POIs `r20_poi_catalog.lua:7,11`). The six capital stables share one design
  (`wp13/capital_services.lua`, riding branch): Riding Trainer socket at
  (0, 1, −6), two idle residents at (±8, 1, −6), four mount displays.
- Boats: nothing in code.
- Dragon channels (`wp40/source/simple_map.lua:150-229`): islands at x
  ±2860..±3440, z ≈ ±340; channels x ±2500..±2860, z ±350, warning 48,
  minimum hard width 104; two boat paths per island at z ≈ ±125 with fixed
  landings kept as land (`zone_field.lua:321-330`) and ≥ 9 nodes of carved
  water (`height.lua:81,482-510`). Crossing ≈ 390–420 nodes: about 100 s by
  base boat, 50 s by improved boat. Runtime water classes via
  `grug_zones.water_class_at(x,z)`.
- Flight ban over ocean and islands: shipped (`grug_mounts/entity.lua:126-193,355-360,487-489`).
- Mount lifecycle to reuse: `grug_mounts` (`items.lua`, `state.lua`,
  `entity.lua`, `trainer.lua`), Skills page (`grug_skills/page.lua:24-33,144`,
  `bound_items.lua:26-27`), riding trainer socket role
  (`trainer.lua:138`, `grug_mobs.register_start_socket_role`).
- Kraken: `run_velocity` 5, `view_range` 20, global no-leash/no-soft-de-aggro
  plus its own deep-ocean leash in `do_custom` (`kraken.lua:25-26,60-62,122-137`).

## 4. Mapgen needs (for the Round 29 mapgen bundle)

The bundle runs after Round 28 and after the waystone node exists (lane W).
Exactly these WP17 items:

1. **Six capitals:** place the waystone node at the centre of the existing
   waypoint pad (the `travel_waypoint` socket position). No other change.
   Files: `mods/MAPGEN/grug_mapgen/wp13/{highcourt,lethariel,dur_brannoc,gor_drazhak,nhal_veyr,kezamba}.lua`.
2. **Six starts:** a small pad in the style of the capitals (stone cross
   about ±3 in the start palette's signature stone) on a free, central,
   road-reachable spot near the innkeeper, the waystone at its centre, and
   a `travel_waypoint` socket with role `waypoint` at the pad
   (arrival offset beside the stone). Inside the start's protected footprint.
   Files: `wp13/{dawnmere,hearthpine,silverleaf,stillgrave,sunscar,kapok}.lua`
   (and the start blueprints they use, e.g. `wp40/r7_dawnmere_blueprint.lua`).
   Rebase on whatever Round 28 changed in the starts.
3. **Six shipwright sockets in one edit:** a `shipwright` socket in the
   riding branch of the shared stable design
   (`wp13/capital_services.lua:59-81`), beside the Riding Trainer (e.g. one of
   the two idle-resident spots at x = ±8, keeping the movement lanes of the
   mount displays clear), plus the role in the socket whitelist
   (`grug_core/settlement_sockets.lua:32`). Optional: one small boat decor
   next to him, if it fits without touching the display regions.
4. **Battlegrounds widening (+50 % z) and the middle road** (already decided
   for the bundle): WP17 needs only that the dragon islands, channels, boat
   paths and landings stay unchanged and that the world self-check (channel
   hard width ≥ 104, both approaches starting at a Battlegrounds coast) still
   passes. The middle road gets no waypoint.

**Not needed:** docks, harbours, slipways for players, island landing
structures, buoys or channel markers.

Everything else in WP17 is runtime and can merge before the bundle; the
capital waystones only become clickable once the bundle's world exists
(unlock by proximity already works on the existing capital sockets).

## 5. Lanes

All Lua work follows AGENTS.md (`tools/check_lua.sh`, LuaJIT only during
development; independent review before merge; headless runs only through
`tools/luanti_headless.sh`).

### B — Boats and shipwright (runtime)

- `mods/PLAYER/grug_mounts/`: `catalog.lua` (water mode, two tiers, speeds
  4/8), `items.lua` (two boat items), `state.lua` (base boat owned from
  15 and improved boat at 30 as purchases, Skills recovery), `entity.lua`
  (water-surface controller, summon/disembark rules of §1.1, the
  once-per-second water-contact check of ruling 8, eject seams),
  new `shipwright.lua` (socket role `shipwright` via
  `grug_mobs.register_start_socket_role`, two-row dialogue in the trainer
  format, prices from the E4 table or "Price pending").
- Boat meshes and textures: one hull for the base boat, a visibly finer one
  (or retexture) for the improved boat; licence verified in the source repo
  and recorded in `grug_mounts/LICENSE-media.md`. A rigid hull needs no
  animation.
- Boat icons for items and the status row (`grug_core/hud_layout.lua` status
  icons if the mount icon is mode-based).
- Check consumers that assume land/flight only: `grug_skills/page.lua`,
  `grug_abilities/init.lua:2163`, `grug_core/combat.lua:35`,
  `grug_core/movement.lua`, `grug_home/travel.lua` (dismount before teleport).

### K — Kraken retune (runtime, small; may ride with lane B)

- `mods/ENTITIES/grug_mobs/kraken.lua`: `view_range` 40; `run_velocity` 10
  while the guard stands in a deep-ocean column, 5 otherwise (switched in the
  existing once-per-second `do_custom` tick); keep the existing leash.
- Acceptance (headless or GUI): an improved boat crossing deep ocean near a
  guard is caught and ejected; a boat in a dragon channel or on the shelf is
  never pursued beyond the deep-ocean edge.

### W — Waypoints (runtime)

- New mod `mods/PLAYER/grug_travel` (or an extension of `grug_home`; lane
  decides, one global table): waystone node definition (registered where the
  mapgen can resolve its content ID before generation — e.g. node def in
  `grug_mapgen/world_nodes.lua` with an `on_rightclick` that delegates to the
  travel mod), unlock globalstep, per-character meta, formspec, travel.
- Shared teleport: expose one helper from `grug_home/travel.lua` (emerge,
  safe arrival, deferred re-validation, dismount, combat-identity
  invalidation) and use it for both home return and waypoint travel; no
  second copy.
- `grug_mobs/start_npcs.lua:22`: the `waypoint` role resolves to the travel
  registry.
- Map markers: `grug_map/providers.lua`, `atlas.lua` kind list,
  `minimap.lua` `SHOWN`/`KIND_TEXTURE`, one waypoint marker texture.

### M — Mapgen part (inside the Round 29 mapgen bundle)

§4 items 1–3, plus the check of item 4. Runs after W is merged (needs the
node name). One fresh world for the user together with E2 and the
`apex_sockets` removal.

### D — Documentation

- `boats.md`: rewrite §1–§6 for rulings 1, 3–5 and 8 (boat = water mount, no
  recipe, no placement/pickup/decay/theft, shipwright in every capital
  selling both boats, summon and water-contact rules); drop the stale G2-gem rationale (gems are depth tiers now,
  economy plan §6) and the stale `api.lua` line citation (now `:2895`).
- `world.md` §2b: Kraken pursuit = ruling 7; §6: waystones, unlock, travel,
  boats as water mounts.
- `items_crafting.md` §3.0.5: remove both boat recipes and their price tests.
- `mounts.md`: boats as the water mode (§1/§3 cross-references).
- `biomes_mobs.md` §3.1: Kraken values of ruling 7.
- `world_map.md`: waypoint marker kind.
- `settlements.md`: shipwright at the capital stable, start pads; the two
  village display hulls become plain scenery.
- `work-package-scopes.md` WP17, `BACKLOG.md`, `ROADMAP.md` (V1 travel
  paragraph and checkbox), README "Current State".
- `economy-vendor-plan.md` E4: add both boat prices.
- `round28-design-frame.md` §2.1: islands are boat-only (tell the Round 28
  coordinator now; the island quest text must not promise flying).

## 6. Order in Round 29

1. **B (+K) and W in parallel**, parallel to E1. No shared files with E1;
   the only contact is the two boat prices, which B shows as "Price
   pending" until E4.
2. **M joins the mapgen bundle** after W is merged; one fresh world.
3. **E4** sets both boat prices alongside mount and respec prices.
4. **D** inside the lanes or at the end.

## 7. GUI test list (fresh world after the mapgen bundle)

Boats

1. New character: no boat anywhere. Level 14 at a capital shipwright (next
   to the Riding Trainer): Boat shows "Requires level 15".
2. Level 15: buy the Boat (or see "Price pending" before E4) → boat item.
   Drop it → gone; recover it from the Skills page.
3. Use it on a beach next to (not in) water → refused with a message. Wade
   into the water → boat appears, you sit in it.
4. Row on a river (river water) and a lake: speed about walking speed,
   smooth accelerate and brake, A/D strafe; you cannot drive onto land.
5. Row down a waterfall, or let someone dig the water out under you → the
   boat disappears within about a second, you are on foot.
6. Use the item again near a bank → you stand on land, no boat remains.
   Disembark in open water → you swim, no boat remains.
7. Get hit by a mob or player while boating → ejected, boat gone; try to
   re-summon within 5 s → refused (combat).
8. Log out while boating, log in → you are in the water, no boat.
9. Ride a horse into shallow water and use the boat → horse replaced by
   boat. Try an ability while boating → blocked.
10. Level 30 at a capital shipwright: Improved Boat shows Buy (or Price
    pending before E4); buy → improved boat item, the base boat stays; it is
    about twice as fast. A level-29 character sees "Requires level 30". An
    enemy capital's shipwright refuses you.
11. Row from a Battlegrounds coast through a dragon channel to the island
    beach: no Kraken; about 1–2 minutes; disembark on the beach. A flying
    mount over the channel still dismounts.
12. Venture into deep ocean with the improved boat: a Kraken that sees you
    catches up and ejects you.

Waypoints

13. New character: the own start's waystone is listed as discovered;
    the other five as "Not yet visited".
14. Walk up to a capital waystone → "Waypoint discovered" once; it appears
    on the map and the minimap.
15. Right-click a waystone → travel to another discovered one: instant,
    free, you arrive beside the destination waystone. Mounted or in a boat →
    you arrive on foot.
16. Try to travel in combat → refused. Home return cooldown unchanged
    afterwards.
17. Right-click an enemy faction's waystone (e.g. reached through the
    Battlegrounds) → refused, nothing unlocked.

## Completion (2026-10-02)

Delivered in Round 29
([round plan completion](round29-plan.md#completion-2026-10-02)): lane B with
K (`f6652818`: boats as water mounts, the Shipwright, the Kraken retune),
lane W with its mapgen part (`e3e10df5`: the waystone node, start pads,
capital waystones, the shipwright socket, waystone travel and the map
marker), the check of §4 item 4 in lane M-geo (`33ac05f9`: the wider
Battlegrounds and the middle road), the art in lane A (`7e696133`) and the
two boat prices in E4 (Boat 1s10c, Improved Boat 7s). Coordinator rulings:
a purchase is ownership only, the item is recovered from the Skills page;
another tier's item replaces the active mount or boat.

Lane D items, where they live:

- `boats.md`, `mounts.md` (water mode), `world.md` §2b and §6,
  `items_crafting.md` §3.0.5, `biomes_mobs.md` §3.1 (Kraken values),
  `settlements.md` (Shipwright socket, start pads, display hulls as
  scenery): lane B and lane W, in-lane.
- `world_map.md` (marker kind `waypoint`): lane W.
- `economy-vendor-plan.md` E4 (both boat prices): lane E4.
- `round28-design-frame.md` §2.1 (islands boat-only): corrected during
  Round 28 (`3f1405e5`).
- `work-package-scopes.md` WP17, BACKLOG, ROADMAP and README: Round 29
  lane D. WP17 is delivered.

The GUI test list (§7) is part of the
[Round 29 playtest checklist](round29-plan.md#playtest-checklist).
