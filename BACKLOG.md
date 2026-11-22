# Backlog

The single list of open work: one short entry per item, saying what is open and where its
context lives. [Design](docs/design/README.md) owns the game rules, the
[ROADMAP](ROADMAP.md) the goals and the [project status](docs/STATUS.md) the delivery
state. An entry here authorizes no behaviour change by itself; a round plan does.

Each round's residual notes from its lane reports and reviews (mostly theoretical or
accepted) are in that round's plan, section "Carry-overs" (the list is at the
[end](#round-carry-overs)); only the ones that still matter are repeated here. Delivered
receipts, the work package table and other history are in the
[archive](docs/archive/backlog-through-round-79.md). Keep this file a list: add an entry when
work is found, delete it when it is done; no per-round sections, no acceptance state.

## Index

- [Release](#release): the first public release, accounts and the website.
- [Performance and engine](#performance-and-engine): WP48, the audit's fix packages.
- [World and mapgen](#world-and-mapgen): WP46, capitals, shores, weather.
- [Mobs and NPCs](#mobs-and-npcs)
- [Classes and combat](#classes-and-combat)
- [Items, crafting and economy](#items-crafting-and-economy)
- [Quests and story](#quests-and-story)
- [Expeditions](#expeditions)
- [UI, map and HUD](#ui-map-and-hud): the UI review follow-ups, first-look defaults.
- [Sound, art and looks](#sound-art-and-looks)
- [Code and tool hygiene](#code-and-tool-hygiene)
- [Player experience follow-up (2026-10-11)](#player-experience-follow-up-2026-10-11): the
  review of classes, atmosphere, crafting and quest onboarding.
- [Open questions for the user](#open-questions-for-the-user), with the
  [audit's open questions](#audit-2026-10-open-questions).
- [After V1](#after-v1): WP42, the Nether.
- [Round carry-overs](#round-carry-overs)

## Release

### First-public-release gates

**Open; owner: the coordinator preparing the first public release.** Trigger: freeze the
intended release candidate, before asking the user to approve that release. Kept visible by
the user's decision of 2026-09-13; not passed or waived. Rewritten 2026-09-29 after the WP
audit (E9, E10).

Gates:

- Freeze the game, engine and settings identity and choose the intended public seed (since
  Round 22 D24 the coast and borders vary per seed, so the seed is a free choice).
- Complete the AI-generated media gate for `menu/icon.png`: set ContentDB's
  **AI-generated media flag**, credit OpenAI's built-in image generation, retain Jan
  Hangebrauck as art director and rights holder, keep the source render and derivatives
  under CC0 1.0, and retain the source/prompt/export record linked from
  `menu/LICENSE-media.md` (updated 2026-11-10).

Release checks with judgement, not gates (E10: sometimes thorough, never a rigid rule that
forces hour-long tests):

- Start, generate and restart the candidate on the native engine, as deep as the changes
  since the last playtest warrant; no mandatory native smoke with runtime/RSS evidence.
- The PUC Lua 5.1 (fallback-engine) run is **optional** (E9): at most one crash smoke test
  once the mapgen is finished (Round 22 D1). Plain Lua 5.1 compatibility of the code stays
  a hard rule; only PUC runtime testing is optional.
- One spot check of resource supply and regional access on a few seeds (rough ~5 % parity
  target, `world_zones.md` §11; Round 22 D21).

[R8](docs/research/wp40-simple-map-r8-contract.md) and
[WP40 completion](docs/research/wp40-completion.md) are historical owner texts, superseded
for these checks by Round 22 D1/D5 and the decisions above.

### Accounts and the website

- **The account Claim Stone, home names and the Account page** with the website's
  `default_rewards` (Round 86; the web-accounts contract amendment first;
  [housing concept](docs/planning/housing-rework-concept.md) Part B,
  [Round 85](docs/planning/round85-plan.md#carry-overs)).
- **The end-to-end test on the rehearsal realm** once the platform side is ready
  ([web-accounts.md](docs/technical/web-accounts.md) §9).
- **Account tombstones:** a tombstone in the id index is overwritten by the next new id at
  a join; fix it with the deletion amendment, before anything writes tombstones (contract
  §10, `grug_accounts/model.lua`;
  [Round 79](docs/planning/round79-plan.md#carry-overs)).
- **The bridge token in the main menu:** `grug_bridge.token` is declared in
  `settingtypes.txt`, so a local main menu's settings show the secret in plain text
  ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **The realm website's model has no emotes:** `build_glb.py` exports stand and walk; a
  further clip is one `CLIPS` entry plus the export's animation list
  ([Round 78](docs/planning/round78-plan.md#carry-overs),
  [Round 39](docs/planning/round39-web-data-plan.md#carry-overs)).

## Performance and engine

Performance numbers are comparisons, never targets.

### WP48 — Mapgen writer performance and parallel emerge

**Partial:** Round 49 did the single-thread part
([completion](docs/planning/round49-plan.md#completion-2026-10-16),
[before/after](docs/research/mapgen-chunk-profile-2026-10.md#round-49-beforeafter-lane-meas2)).
What remains:

1. **Several emerge threads** after Luanti #9357 (PR #16224 pending;
   [upstream workarounds §2](docs/technical/upstream-workarounds.md#2-more-than-one-emerge-thread-loses-ores-and-caves-at-chunk-edges)):
   with native ores the lost edge slices would cost ores as well as caves, so
   `num_emerge_threads = 1` stays pinned until the engine fix.
2. **The cold planner** (R5, R6 columns and candidates): about 95 ms (93–102) on the first
   chunk with Lua work of every new column, now the largest surface cost.
3. **The first-start pre-step:** before the first server step the world layouts take about
   24 s, the world map base render 9.5 s and the mob spawn regions 8 s (single-threaded, a
   new world or a map reset only), about two thirds of the time to ready.

The record since Round 9 is in the
[archive](docs/archive/backlog-through-round-79.md#wp48--mapgen-writer-performance-and-parallel-emerge).

### Audit 2026-10 later fix packages

Not in Round 37; details in the
[code audit summary](docs/audit-2026-10/code/00-summary.md#proposed-fix-packages).

- **MGT-03 trees at chunk borders** (the user, 2026-10-05: later): owner-only writes drop
  every tree that crosses a chunk border, so treeless bands run along chunk borders and at
  y ≡ 15..50 mod 80 (kapoks still lost there, Round 47); accepted by the R6 contract, the
  fix is size L ([terrain code](docs/audit-2026-10/code/01-mapgen-terrain.md)).
- **P6 beyond MGT-02** (mapgen performance and memory): MGS-01/W13-01 emerge memory (about
  7–10 % of the emerge high-water mark; a concern, or wait for WP48?), MGS-03's collar
  palette declared in two places.
- **P8 structure and legacy:** the wp13/wp40 merge (W13-05; is a directory rename worth the
  churn?), mobs_redo as an owned fork (X-06, MOB-08; may it be declared one?), the
  `mod.conf` coupling (X-07), the tooltip writers (ITM-04) and the other duplications.
- **CORE-06, status reads with side effects:** a status read (`status_modifier_sum`,
  `each_status`) removes expired records and fires their callbacks; a status with an unknown
  modifier key is refused without a log line (`grug_core/status.lua`)
  ([core audit](docs/audit-2026-10/code/06-core-hud-ambience.md)).
- **PLY-08, global API replacements in load order:** `core.show_formspec` (twice),
  `core.is_protected` (twice), `core.create_detached_inventory`, `core.item_place_node`,
  `core.handle_node_drops`, `core.show_death_screen` and `core.calculate_knockback` (three)
  are replaced by wrappers whose order is the mods' load order
  ([player systems audit](docs/audit-2026-10/code/08-player-systems.md)).
- **ITM-05, tool lifetimes in several places:** `grug_materials/tool_lifetimes.lua`,
  `mining.lua`'s pick profiles and `grug_farming/hoes.lua` each hold the use budgets, and the
  axes' and shovels' `uses` in `grug_materials/tools.lua` are overwritten
  ([items audit](docs/audit-2026-10/code/09-items.md)).
- **ITM-06, ITEMS mods run grug_jobs files:** `grug_professions` and `grug_brewing`
  `dofile` grug_jobs' station files ([items audit](docs/audit-2026-10/code/09-items.md)).
- **MOB-09, mob instance fields persist by default:** mobs_redo's `clean_staticdata` saves
  every top-level field that is not a function (userdata filtered only at the top level),
  and property-named fields load around `self` ([mobs runtime audit](docs/audit-2026-10/code/04-mobs-runtime.md)).
- **MOB-11, mob behaviour on four override levels:** class, prototype, instance and API
  wrappers (`grug_mobs/init.lua` wraps `mobs.mob_class.on_deactivate` and `stop_attack`)
  ([mobs runtime audit](docs/audit-2026-10/code/04-mobs-runtime.md)).

### Other performance work

- **Mapgen-environment memory:** the emerge thread's Lua environment holds 630–745 MiB live
  after a collection and grows with generated chunks; find what it keeps and whether its
  world-query caches are bounded ([Round 32](docs/planning/round32-plan.md#carry-overs);
  the heap swings 1–2 GB between collections,
  [Round 49](docs/planning/round49-plan.md#carry-overs)).
- **The performance review's later list:** R6 ability input and crosshair every step, R10
  vegetation renewal bursts, R12 tag carriers in crowded places, R13 royal and garrison NPC
  steps; re-measure first ([Round 32](docs/planning/round32-plan.md#carry-overs)).
- **CORE-05, minimap client textures never freed:** Round 37 cut the growth (an hour's walk
  61.2 → 26.4 MB, three hours 185.0 → 79.9 MB) but did not bound it
  ([Round 37](docs/planning/round37-plan.md), [core audit](docs/audit-2026-10/code/06-core-hud-ambience.md)).
- **World generation, small speed leftovers** (byte-identical): M3-04 (b) the adapter's own
  buffers (about 1 ms a chunk), M1-09 (b) the heightmap fetched twice a chunk, M2-01's
  regional river lists (−8 %, changes an unread return), M2-02's road `extra` as plain values
  (changes the sampler's return), M2-03's zone-scale cache, W1-09's per-chunk allocations in
  `plot_approach` and `city_edge`, M5-07's `hotexit` for the whole main state
  ([M1](docs/audit-2026-11/findings/M1.md), [M2](docs/audit-2026-11/findings/M2.md), [M3](docs/audit-2026-11/findings/M3.md), [M5](docs/audit-2026-11/findings/M5.md), [W1](docs/audit-2026-11/findings/W1.md), [Round 82](docs/planning/round82-plan.md#carry-overs)).
- **A per-environment wp13 loader context** (the user, 2026-11-18: backlog): 338 → 283
  template parses and 440 → about 200 tree generations, about 0.2 s CPU per environment;
  needs `world_assembly.lua`, `r7_runtime.lua`, the start wrappers and five POI blueprints
  ([Round 82](docs/planning/round82-plan.md#carry-overs)).
- **The minimap's party names** still build `grug_parties.view` every 5 s per party player;
  switch to `grug_parties.member_names` (about 15 map fixtures need a stub line) ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **Invitation switches in the Social roster rows** are read per build (P5-05's rest,
  [Round 81](docs/planning/round81-plan.md#carry-overs)).
- **Completed quests in their own player-meta key** (P3-04's full fix) needs a migration
  step ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **Environment damage on a lagging server:** above 0.25 s per step the per-visit rounding is
  off by up to a third; a carry reset at the join and after a stall would fix it ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **Mail body trim** is still quadratic up to the 10,000-character draft (about 0.1 s for a
  crafted blank body) ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **Tag carriers:** the faction could come from the identity cache, and
  `nearest_tag_player_d2` still walks the whole snapshot ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **DT2-04:** whether 5.18.0's default send distance 13 with generate distance 10 stalls
  loading is unmeasured; a short engine probe would settle it ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **A real-client performance test** with a handful of clients (stand-ins cover no block or
  object sending, physics or client work); optional
  ([Round 32](docs/planning/round32-plan.md#carry-overs)).

## World and mapgen

### WP46 — Terrain-damage guard: explosions, fire and lava never damage settlements or POIs

**Partial; the remainder waits for the first fire or explosion source** (E6, the user
2026-09-29), expected with V2's Nether. Delivered: the actor-neutral
`grug_core.world_alterable` authority and the protected ordinary and river-water flow for
buckets (Round 11). Nothing damages terrain today (no `fire` or `tnt` mod, natural lava
only, the Rift Spawn explodes with terrain radius 0, the dragons' rime and scorch write only
into air and restore it).

Requirement (the user 2026-09-19, extended 2026-09-29): explosions (mobs and players) never
damage capitals, starts, landmarks and POIs, and fire never spreads into them; the guard
also spares **roads and the building cores of POIs, villages and camps** (E7, `world.md` §2
R1b). `world_alterable` does not consult that Round 25 layer
(`grug_core.world_feature_at`) today; a future consumer must. When scheduled:

1. **One guard predicate in `grug_core`**, actor-neutral, asked per node by every effect
   that changes nodes on its own (mob explosions, fire spread, lava flow into non-natural
   nodes, boss ground effects): the hard-protected capitals and start towns, landmark and
   functional footprints, road corridors and POI boxes; Claim Stone claims guard only their
   arrival cube (no claim protection against explosions or fire in V1, Round 25).
2. **mobs_redo `explode` GRUG PATCH:** terrain damage stays radius 0, or `mobs:boom` skips
   every node the guard refuses (`mobs/api.lua` defaults `explosion_radius or 1`, so a new
   explode mob needs an explicit radius).
3. **Fire:** spread is an ABM that asks the guard per target node, has a burn budget per
   flame and never ignites settlement palettes; "eternal flame" nodes do not spread.
4. **Lava:** mapgen keeps natural lava outside settlement and POI exclusions; a lava bucket
   would be placement, already covered by `core.is_protected`.
5. **Optional repair net:** an admin command that re-projects an authored settlement
   blueprint at its anchor.

Checks follow the Round 22 minimal policy: a small fixture of the guard and a short
headless probe. The water guard asks the layer since Round 81 (ruling 3); cactus and papyrus
growth still ignore it and may grow into POI cores ([Round 81](docs/planning/round81-plan.md#carry-overs)).

### Weather (optional; user, 2026-10-04)

Not V1 (round34-plan.md §2.1 ruling 7): no weather system exists; distant thunder plays as
a rare ambience call on the dragon islands. An optional later package: a small weather
system with its own sky, particles within the web budget (hundreds, never thousands) and a
rain bed (also the place for the rain recordings the user turned down as bed backgrounds).
Not planned yet.

### Other world work

- **Road cut walls:** a road's cut slope ends 24 nodes from the road, so on steep hills the
  cut ends in a wall of 10–31 nodes; no check sees it
  ([Round 85](docs/planning/round85-plan.md#carry-overs)).
- **Capital wall follow-ups** (deferred by the user 2026-09-30): river V-dips where a whole
  run of rays sits on the far bank; streets on the wall line in 6 of 1,200 capital plans
  (let the wall win over avenue columns beside a gatehouse, or make the wall leave the box
  sideways) ([details](docs/planning/round26-capitals-housing-cleanup-plan.md#capital-wall-follow-ups)).
  The optional planner hardening (clamp to `rmax`, assert `POLY` ≥ 4, a plaza without an
  avenue) is in the same plan's carry-overs.
- **The template checker's walker** could also start at the standing cells on a
  template's box edge at y = 1: 11 warnings → 1 (Sunscar's platform); it changes the §6.2
  entrance rule ([Round 62](docs/planning/round62-plan.md#carry-overs),
  [Round 56](docs/planning/round56-plan.md#carry-overs)).
- **Shore sources and wayposts after the playtest:** Rock Salt and Stormkelp stay under the
  plan's counts (option B: each biome's main ground from some distance inland, lower
  density, a new digest); secondary roads give only about nine waypost stacks a world
  (trails would add about 60); Nhal Veyr's graves 114 → 529 trim in one line
  ([Round 70](docs/planning/round70-plan.md#carry-overs), rulings in
  [round70-plan.md §2.1](docs/planning/round70-plan.md)).
- **The outpost seed** (a future package, Round 28 item 46, user G8): a player-placed seed in
  contested land spawns workers who build a small fort; killing them and destroying the
  seed stops it; specified after a playtest of the front quests
  ([Round 28](docs/planning/round28-questing-leveling-plan.md#carry-overs)).
- **City variety** and the broader **ore, gem and coal distribution** revision: see the
  [player experience follow-up](#atmosphere-world-variety-and-resource-distribution).
- **The soft map reset** that keeps homes (housing concept Part C), when the first one is
  needed; the stored claim mask is its input
  ([concept](docs/planning/housing-rework-concept.md) §4,
  [Round 85](docs/planning/round85-plan.md#carry-overs)).
- **M3-01, with a later map reset** (not the 0.85.0 one, Round 85 ruling 17): the
  surface-skin opening reads the VoxelManip shell, so a border column's result depends on emerge order; hygiene with no player-visible gain
  ([M3](docs/audit-2026-11/findings/M3.md), Round 82 ruling 2, [Round 82](docs/planning/round82-plan.md#carry-overs)).
- **M4-07, the −0 protection miss:** a protection query at x or z in (−0.5, 0) misses the
  column at 0 (its string key reads "-0"); only float positions at the 36 functional anchor
  columns on x = 0 or z = 0, digging and placing are unaffected; a numeric key fixes it and
  changes protection there (the user, 2026-11-18: backlog; [M4](docs/audit-2026-11/findings/M4.md), [Round 82](docs/planning/round82-plan.md#carry-overs)).

## Mobs and NPCs

- **The kings' volley fires without a line-of-sight check** (`grug_mobs/bosses.lua`, kit
  `volley`; the user 2026-10-15: backlog, a balance question)
  ([Round 49](docs/planning/round49-plan.md#carry-overs)).
- **Elite ideas never shipped:** Rat King, Old/Giant Boar, Silver Fox, Rotting Brute, an
  elite Giant Scorpion ([Round 28](docs/planning/round28-questing-leveling-plan.md#carry-overs)).
  The War Constructs are DW-04 [below](#audit-2026-10-open-questions).
- **Per-player NPC visibility** (the engine's `set_observers`, as the quest objects use) is a
  possible later feature, not planned ([Round 59](docs/planning/round59-plan.md#carry-overs)).
- **Elder Bear and Silverback stay dormant:** their 1-in-10 roll lives in the base
  definitions, but every ambient bear and ape is an authored-tier sub-type; a follow-up may
  let the normal-tier sub-types roll ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **`mob_nospawn_range` defaults disagree:** 12 in `spawn_policy.lua` and `mobs/api.lua`, 24
  in `spawn_regions.lua`; `minetest.conf` sets 24 ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **Watch in play:** reach-2 mobs against a target 1.1–2 nodes up
  ([Round 78](docs/planning/round78-plan.md#carry-overs)); night mobs kept all day by an
  idle player ([Round 45](docs/planning/round45-plan.md#carry-overs)); guards looping on
  unreachable targets, L1–L4 of the GUARDNAV review
  ([Round 72](docs/planning/round72-plan.md#carry-overs)).

## Classes and combat

- **The balance fix round** after the user's first playtest of the new kits, in the user's
  iteration style (a first version by feel, the user names the fixes; delivery plan §5).
  Known numbers: Rebuke and Final Word 1.3 % and 0.9 % under the calculator at level 60;
  the Warrior's absorbs and Recover carry the support factor; Charge's 0.75 s is an
  estimate ([Round 53](docs/planning/round53-plan.md#carry-overs)). The wider class review
  is in the [player experience follow-up](#classes-talents-and-progression).
- **Unscheduled ideas from the class handoff:**
  [food on the belt](docs/planning/class-redesign-handoff.md#72-consumables-belt-and-eating)
  and [tools](docs/planning/class-redesign-handoff.md#73-tools-and-everyday-layouts)
  (remove shovels, combine axe and hoe)
  ([Round 53](docs/planning/round53-plan.md#carry-overs)).
- **Faster mobs against kiting:** the Mage's root, the bound actors' soft de-aggro distance
  and the mob speeds are one system; a rule is needed before ordinary mobs get faster
  ([scout.md §6.3](docs/design/scout.md#63-faster-mobs-versus-the-mages-kiting-fantasy--coupled)).
- **Scout stealth v2** (deferred): the detection roll, the blocking conflicts with
  `grug_visuals` and the weapon entity, and the rules for nametags, the target veto, PvP and
  the telegraph ([scout.md §8](docs/design/scout.md#8-deferred-stealth-v2)).
- **Heal out of range says "full health":** Heal aimed at a hurt ally beyond its 15 m
  falls back to the caster and, at full health, answers "Target is at full health."
  (Hearten beyond 6 m alike); a range message would be clearer
  ([Round 80](docs/planning/round80-plan.md#carry-overs)).

## Items, crafting and economy

- **Mob loot for Alchemy T2** (the user: a later loot lane): `venom_gland` (Antivenom)
  drops only in the spider bands 3–6; `tough_sinew` (Vigor II) is out of reach for
  humans, elves and undead, `fang` (Swiftness Draught) for undead and trolls
  ([Round 60](docs/planning/round60-plan.md#carry-overs)).
- **Items without a quest:** Salt Chitin and Siege Cat Claw lost their last quest but
  `grug_mobs/data/items.json` still lists their uses as `["quest"]`
  ([Round 62](docs/planning/round62-plan.md#carry-overs)).
- **Leftover crafting-grid recipes:** `grug_trees`, `grug_materials` and the mobs still
  register grid recipes although the grid has size 0; remove each where nothing reads it
  ([Round 66](docs/planning/round66-plan.md#carry-overs)).
- **`tools/r29_e4/income.py` has no Expedition term and no death term:** the economy check
  ignores the Expedition chest's coins (factor 10) and the death penalty
  ([Round 71](docs/planning/round71-plan.md#carry-overs),
  [Round 70](docs/planning/round70-plan.md#carry-overs)).
- **`item_tiers.md`'s generated tables** (the crown options, two income tables at repair
  factor 1.00) are dated: one crown row and the factor 0.50 in `tools/r33_ds/money.py`, then
  regenerate (DD3-09, [Round 81](docs/planning/round81-plan.md#carry-overs)).
- Crafting and Cooking variety: see the
  [player experience follow-up](#crafting-and-cooking-variety). The open fuel and
  fishing-rod questions are [below](#audit-2026-10-open-questions).

## Quests and story

- **The quest description still reads "Minimum level: N"** (`grug_quests/registry.lua`)
  while acceptance is at quest level − 2 since Round 65
  ([Round 65](docs/planning/round65-plan.md#carry-overs)).
- Quest onboarding and immersion: see the
  [player experience follow-up](#quest-onboarding-and-immersion).

## Expeditions

Rules: [expeditions.md](docs/design/expeditions.md).

- **Icon picks:** the Deserter's Mark's drawn icon (`grug_status_deserter_mark.png`, a pick
  page; today a texture modifier over the contested emblem;
  [0.72.1](docs/planning/round72-plan.md#0721-and-0722)); the Registrar has no map marker
  ([Round 71](docs/planning/round71-plan.md#carry-overs)).
- **Feed, not chat:** the waystone window's refusals and `grug_home.travel`'s failure texts
  (`notify` in `grug_home/travel.lua`, with `runs.lua`'s "could not be prepared") go to
  chat; one line each to `grug_core.feed`, checking the pins `r29_w` and `r45_pt9`
  ([Round 72](docs/planning/round72-plan.md#carry-overs)).
- **Trap deaths** show the fallback death line; a "trap" category belongs in
  `grug_core/death_messages.lua` ([Round 72](docs/planning/round72-plan.md#carry-overs)).
- **The Second Shift's wall torches look ceiling-mounted** (param2 0):
  `sources/second_shift.py` `thin()` and `place_light`'s undo put cells back without their
  param2; fix the source, rebuild, then `build.py --check`, `r74_nav` and `r72_shift`
  ([Round 78](docs/planning/round78-plan.md#carry-overs)).
- **The Registrar's Confirm** (`session.confirm`) is not tied to a run id: a stale Confirm
  after the leader switches runs would cancel the new run (contrived; store `run.id`)
  ([0.72.1](docs/planning/round72-plan.md#0721-and-0722)).
- **A free wipe:** leaving the party and re-entering is a free wipe (noted, not closed;
  [Round 71](docs/planning/round71-plan.md#carry-overs)).
- **Tuning from real runs:** run lengths (modelled under the concept's 10–20 minutes), an
  HP factor per pack, the bosses' HP factors, the chest's coins, the mining share, the
  pack's shove on a still player ([Round 71](docs/planning/round71-plan.md#carry-overs),
  [Round 72](docs/planning/round72-plan.md#carry-overs)).
- **For later templates:** `on_spawn` families skip the Expedition setup through
  `add_entity` (bear, ape, zombie, weevil); a future boss summon outside `packs.lua`'s spawn
  carries no `_grug_expedition`; the authoring helpers' alcove depth and candle param2
  ([Round 71](docs/planning/round71-plan.md#carry-overs),
  [Round 72](docs/planning/round72-plan.md#carry-overs),
  [Round 73](docs/planning/round73-plan.md#carry-overs)).

## UI, map and HUD

- **The Claim Stone's placement preview by map chunks** (CLAIMUI, Round 85 ruling 23; Round
  86): today's minimap preview is the old per-column one with a square centred on the
  player; also the stone's texts and Help
  ([Round 85](docs/planning/round85-plan.md#carry-overs)).
- **Quickbar hint at GUI scale 2:** "Click to use; the window closes." reaches the
  window's right edge ([Round 80](docs/planning/round80-plan.md#carry-overs)).

### UI review follow-ups (2026-10-26)

From the [UI polish review](docs/planning/ui-polish-review.md); separate future work.

- **Shipwright venue:** evaluate a small dedicated building or an annex beside the stable
  showing the actual boats, optionally in a shallow display pond, keeping the trainer's
  access and purchase rules. Check footprint, navigation, water and boat presentation and
  generation first; nothing is committed as design.
- **Claim recovery scale:** audit very large claims (the user's example: 10,000 chests).
  The recovery UI enumerates stored entries and grows its list (a packed container is one
  entry); no cap was found, which is no guarantee for storage, migration, metadata,
  detached inventories, transfer validation, payload and client rendering. Measure the whole
  path and its failure behaviour before proposing bounds or paging; do not add a cap,
  truncate contents or build virtualization as part of layout work. Owners:
  `grug_housing/recovered.lua`, `grug_housing/stone_form.lua`, the map-reset container
  migration tools; [housing.md](docs/design/housing.md).

### First-look defaults to tune

Values shipped as a first version, to tune from play:
[Round 66](docs/planning/round66-plan.md#carry-overs) (the equip notice's 6 s, the blocked
offhand's dim level, the creation buttons' shades, Smite's size, the falling symbols),
[Round 67](docs/planning/round67-plan.md#carry-overs) (underground Giant Spider and Giant Rat
density, 15 px markers at 1280×720, the 1 s party check on the map, text above 1620 px),
[Round 68](docs/planning/round68-plan.md#carry-overs) (floor and ceiling wall signs upright
only facing +z, the waypost's arrow, the notice board's four steps, the glyph files on the
web join), [Round 73](docs/planning/round73-plan.md#carry-overs) (the ambush's dust, The Last
Mint's emberglass, The Second Shift's lanterns),
[Round 74](docs/planning/round74-plan.md#carry-overs) (the 50 % clock cover, the wall traps at
2 s, Blink firing late along the look).

## Sound, art and looks

Every new sound goes through a listening page ([sound.md](docs/design/sound.md) §1).

- **Parked sounds:** more crow calls from long recordings, n_236954 (birds, "keep, no place
  yet"), c_bg3 crackling fire (large fires, an idea for Fire Rain), c_bg1 soft tonal wind
  (badlands night?); each needs its own cut and pick
  ([Round 52](docs/planning/round52-plan.md#carry-overs)).
- **Particle art for later:** a snowflake sprite, animated fire for Fireball's splash, ice
  and fire motes for the dragon breath, a holy spark for Smite, a slash streak; the user has
  flagged none yet ([Round 40](docs/planning/round40-plan.md#carry-overs)).
- **The main-menu background:** the user's own in-game screenshot follows
  (`menu/background.png` with a `LICENSE-media.md` row; none ships yet)
  ([Round 36](docs/planning/round36-plan.md#carry-overs)).
- **Not built:** a back weapon for classes other than the Scout, the offhand and body card
  on NPCs, an off-hand weapon card ([Round 55](docs/planning/round55-plan.md#carry-overs)).

## Code and tool hygiene

- **Dead mob function:** upstream `dogswitch` (`mods/ENTITIES/mobs/api.lua`) is no longer
  called and could go ([Round 78](docs/planning/round78-plan.md#carry-overs)).
- **`tools/wp13/node_tiles.json`** (generated) still lists `mobs:mob_repellent`; regenerate
  ([Round 26](docs/planning/round26-capitals-housing-cleanup-plan.md#carry-overs)).
- **Tool checks that fail on main:** `tools/r52_pfx/build_page.py --check` (the page is
  stale since 0.54.1), `tools/r52_art/artb/build_drop.py --check`,
  `tools/r33_ds/allocation.py --check` (the T5 enchants take `ash_feather`),
  `tools/r38_names/inventory.py --check` (stale files), `tools/r70_design/build.py` and
  `verify.py` (the stale `CORE = 48` citation, `build.py:219`;
  [Round 70](docs/planning/round70-plan.md#carry-overs)) (measured 2026-11-16;
  [Round 66](docs/planning/round66-plan.md#carry-overs),
  [0.53.1](docs/planning/round53-fix-plan.md#carry-overs),
  [Round 45](docs/planning/round45-plan.md#carry-overs),
  [Round 46](docs/planning/round46-plan.md#carry-overs)).
- **Engine probes to fix when next used:** the `min_level` stand-ins of `r36_e`,
  `r59_qsys3` and `r57_qsys` ([Round 65](docs/planning/round65-plan.md#carry-overs)); three
  probes expecting the old hover text ([Round 68](docs/planning/round68-plan.md#carry-overs));
  the Expedition probes fixed by reading only
  ([Round 73](docs/planning/round73-plan.md#carry-overs)); `r71_l20`'s `range.lua`
  ([Round 72](docs/planning/round72-plan.md#carry-overs)); `r25_claim_core`'s probe, stale
  since Round 26's drafts, and about 20 `grug_probe_*` that write identity meta directly
  ([Round 81](docs/planning/round81-plan.md#carry-overs)); eleven claim probe mods still on
  the 101 × 101 claim ([Round 85](docs/planning/round85-plan.md#carry-overs)).
- **Two small text bugs:** the mail count reads "1 sent letters" (`grug_mail/window.lua:396`;
  [Round 66](docs/planning/round66-plan.md#carry-overs)); the mapgen waypost labels Last
  Hedge Redoubt "Last" (`wayposts.lua` `short_label`, the first word;
  [Round 70](docs/planning/round70-plan.md#carry-overs)).
- **Smaller hygiene** (the `grug_gear` global in `talent_graph_ui.lua`, stale docstrings
  and comments): [Round 78](docs/planning/round78-plan.md#carry-overs).
- **The start towns on `wp13/composition.lua`** (W2-04's rest, with the towns' W2-03 prop
  guards); the capital plot engine no longer checks a district's building-row count against
  its lots (the old Kezamba guard) ([W2](docs/audit-2026-11/findings/W2.md), [Round 82](docs/planning/round82-plan.md#carry-overs)).
- **Mapgen duplicates:** M3-09 (the writer's copy of the planner's surface rule; needs a load
  path into `r6_settlement.lua`), M2-05 (`chaikin`, `resample`, the heap twice), M2-08
  (renewal's hardcoded trunk names) and the helper copies M2-04, M3-16, M4-15, M5-09
  ([M2](docs/audit-2026-11/findings/M2.md), [M3](docs/audit-2026-11/findings/M3.md), [M4](docs/audit-2026-11/findings/M4.md), [M5](docs/audit-2026-11/findings/M5.md), [Round 82](docs/planning/round82-plan.md#carry-overs)).
- **Mapgen dead code left by Round 82:** the always-nil `surface_cave_run_at` and `run_at`
  (readers in `vegetation_density.lua`, `swamp_pools.lua`, `r7_runtime.lua` and fixtures);
  R7's `replay_fixture` branches (`r7_settlement.lua`, `r7_p9g.lua`,
  `r7_anchor_activation.lua`) and `r6.lua`'s slot-4 comment; M4-14;
  M4-16's rest; M4-17's empty `city_decor` catalogue rows; the `grug_nodes/init.lua:311`
  comment naming `grug_core.territory_at` ([M4](docs/audit-2026-11/findings/M4.md), [Round 82](docs/planning/round82-plan.md#carry-overs)).
- **Mapgen tools after Round 82:** three tool hooks drop the loader context
  (`freeze_build.lua`, `r70_design/export.lua`, `r36_w/portable_test.lua`; sharing only);
  `tools/r36_w/baseline.tsv` is stale for the six capital cores; `tools/mgprof/stages.patch`
  and `tools/wp40/profile/instrument-settlement-stages.patch` are stale ([Round 82](docs/planning/round82-plan.md#carry-overs)).
- **The mob species boilerplate** (audit 2026-11 MOB3-05), an optional refactor
  ([audit](docs/audit-2026-11/README.md), [Round 81](docs/planning/round81-plan.md#carry-overs)).
- **The skills bound-item re-walk** at mods-loaded holds only while grug_skills runs after
  grug_jobs; `core.after(0)` would be order-proof ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **Fixture-only seams** kept under X3-03 (move immunity, `get_target` and its store,
  `clear_cooldown`, `test_vault`): delete them together with their fixtures? ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **I1-05:** the two `drop_hover_text` LBMs (grug_text, grug_signs) convert 0.68.0 data at
  load, an accepted exception the upgrade contract does not name yet ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **The mod map's coupling list** omits the vendored `vessels` calling
  `grug_inventory.station_formspec` ([Round 81](docs/planning/round81-plan.md#carry-overs)).

## Player experience follow-up (2026-10-11)

Open follow-up work from the user's playtest assessment of 2026-10-11; priority and
direction in the [ROADMAP](ROADMAP.md#next-priorities--deepening-the-playable-game). These
refine delivered systems; current design rules stay in force until a design pass settles
their replacements. No round is assigned yet.

### Classes, talents and progression

- Review all four classes over the levelling journey: starting kits, talent unlocks, the
  feel of progression and customization, ability interactions and rotations, in group play
  and PvP. The user's assessment: the trees are not yet cohesive and the skills basic; the
  Scout feels worst and needs particular attention. A working implementation does not
  settle class feel or balance.
- The class rework is built (Rounds 52 and 53, the fix round 0.53.1;
  [delivery plan](docs/planning/class-redesign/delivery-plan.md)); next are the playtest and
  the [balance fix round](#classes-and-combat).
- Owners: [classes](docs/design/classes.md), [talents](docs/design/skill_trees.md),
  [Scout](docs/design/scout.md), [combat](docs/design/combat_stats.md), [PvP](docs/design/pvp.md).

### Atmosphere, world variety and resource distribution

- Review music, sound effects, regional ambience and icons for quality and consistency.
  Keep what works (the human areas' daytime birds and nighttime crickets); wind-dominated
  areas lack that richness. Keep the exact-file sound approval process. Round 52 moved the
  beds to biome groups.
- Surface variety and tree shapes had Round 47 (trees, the swamp) and Round 51 (land
  zones); **city variety stays open**.
- Reassess ore, gem and coal availability through the depth tiers, then revise the
  distribution design and data, checked against gathering and crafting progression first
  (first passes in Rounds 46 and 47;
  [items_crafting.md §3.0.1](docs/design/items_crafting.md#301-universal-materials-and-resource-taxonomy)).
- Owners: [sound](docs/design/sound.md), [world](docs/design/world.md),
  [settlements](docs/design/settlements.md), [materials and crafting](docs/design/items_crafting.md).

### Crafting and Cooking variety

- Review the crafting experience as well as the recipe roster: a good foundation that
  needs variety, wit and versatility, especially Cooking.
- Explore more distinct and useful buff foods in the Cooking design pass, then review their
  ingredients and usefulness through progression (a direction, not an approved list).
- Owners: [professions](docs/design/professions.md),
  [recipes and food](docs/design/items_crafting.md), [economy](docs/design/economy.md).

### Quest onboarding and immersion

- Walk the early quest experience as a new player, find where the game leaves its
  mechanics unexplained, and revise the flow to teach them more naturally.
- Review how tasks, dialogue and surroundings support immersion; improve on the existing
  framework. (The 2026-10-12 feedback on mob names, loot items and quest variety was taken
  up by Round 46 and the quest rework of Rounds 59–62;
  [quests.md](docs/design/quests.md).)
- Owners: [quests](docs/design/quests.md), [story](docs/design/story.md); coordinate
  teaching steps with the class and crafting revisions above.

## Open questions for the user

- **Clan and account defaults:** the coordinator defaults of Round 76 (clans) and Rounds
  79–80 (accounts) are built as written but were never confirmed by the user: confirm or
  change ([clans.md](docs/design/clans.md), [accounts.md](docs/design/accounts.md)).
- **Desktop HUD scaling above 1** only caps the map markers (1920×1080 at HUD 2: 52 → 26 px);
  the server cannot tell it from a phone's density (MAP Q1,
  [Round 66](docs/planning/round66-plan.md#carry-overs)).
- **Fruit picking in towns:** a right-click pick is protected exactly like a dig, so town
  orchards cannot be picked. Recommended: keep; the alternative is a fruit-only exception in
  `grug_gathering/pick.lua` ([0.53.1](docs/planning/round53-fix-plan.md#carry-overs)).
- **The capital drifts** kept as per-capital options: aligning the plot airspace (W2-05)
  changes 13 plots (all to `top`) or 4 (all to `peak + 2`), planting Kezamba's four gardens (W2-02) 4 plots (each a map reset);
  dropping the garden flags or copying the socket fields everywhere (W2-06) changes no
  blueprint ([W2](docs/audit-2026-11/findings/W2.md), [Round 82](docs/planning/round82-plan.md#carry-overs)).
- **A music tab** (a personal playlist; the user leans towards "not now"): about 450 lines;
  open where it plays ([Round 35](docs/planning/round35-plan.md#carry-overs)).
- **Start zones:** the cave mobs below them (no recipe roles) still call each other; the
  start-zone camps fighting alone is lane F's reading of the ruling, to confirm
  ([Round 37](docs/planning/round37-plan.md#carry-overs)).
- **The rift crack's particles:** one 1 s spawner per stretch every second (built) or every
  2 s (half the packets, still continuous with a 2–3 s mote life)? ([Round 81](docs/planning/round81-plan.md#carry-overs)).
- **A systematic mapgen failure** would send one red chat line per chunk to every player; a
  cap needs the user's call ([Round 41](docs/planning/round41-plan.md#carry-overs)).

### Audit 2026-10 open questions

From the [October 2026 audit](docs/audit-2026-10/README.md) (collected 2026-10-05); none
blocks a fix, and until a ruling the docs describe the code as it is. Answered and dropped:
DI-14 and D3 (Round 45), CTX-14, RDM-08 and the README's PvP NPCs (Round 37), DP-12 (the
Scout's HP factor is an explicit 1.00 since Round 53, `grug_classes/stats.lua`), CTX-26 (the
Nether's decided rules are in [world.md §10](docs/design/world.md#10-the-nether-v2-a-future-system-not-built)
since 2026-11-16), CMB-10 and MGS-08 (Round 81 rulings 2 and 3,
[round81-plan.md §2](docs/planning/round81-plan.md#2-user-rulings)). Sources:
[world docs](docs/audit-2026-10/docs/03-design-world.md),
[item docs](docs/audit-2026-10/docs/05-design-items.md),
[player docs](docs/audit-2026-10/docs/04-design-player.md), code audits in
[docs/audit-2026-10/code/](docs/audit-2026-10/code/00-summary.md).

- **DW-04:** the ambient War Constructs (`causeway_construct`, `siege_war_construct`) are in
  no recipe: add them to their zones' recipes, or drop them and their docs?
- **DW-08:** V1's "scorched breaches, twisted vegetation" and "Nether corruption" do not
  exist (V1 has the rift): keep as a V1 wish, move to V2 or drop?
- **DW-26:** the placeholder "Rift-Touched" state for the Nether collides with V1's rift and
  Rift Spawn ([TODO-design-nether.md](TODO-design-nether.md)).
- **DW-40:** "never overlaid": `grug_core.surface_mob_level_at` returns the region overlay,
  only `grug_zones.*` is the pure field; which does the rule mean?
- **DI-17:** station recipes belong to one profession, so only the Weaponsmith crafts a
  Forge: may the Armorsmith too?
- **DI-27:** cultivated Ember Moss is not Alchemy-gated, only the wild source: intended?
- **DI-10:** is a "found gear versus crafted demand" audit still wanted after WP5?
- **DP-06:** the Priest's "Word" names (Sharpened Word, Swift Word, Word of Ruin, Last
  Word): keep or rename?
- **DP-08:** `/xp` can no longer lower a level: keep the level-drop talent reset for API
  callers, or remove it?
- **DP-10:** Warrior shield abilities (deferred "after WP14", which is delivered): post-V1
  or a backlog entry? (`classes.md`: none exists and none is scheduled.)
- **DP-18:** "Last Word" is both an achievement and the Priest capstone: keep the shared
  name?
- **Blink into claims:** Blink and Charge ignore housing claims and protected POI interiors
  (only walls stop them): refuse them there?
- **Rift void and shields:** absorb shields soak the rift void's damage, unlike lava and
  drowning: intended?
- **CORE-03:** switching off the atmosphere (a graphics fallback) also mutes the ambience
  beds: keep the beds then?
- **ITM-16, furnace fuels:** furnaces burn coal, charcoal, Anthracite, logs, cactus (15 s)
  and leaves (2 s): intended? (The brewing stand takes no fuel since Round 45.)
- **Fishing rod:** all other gear breaks and is repaired; the rod breaks and disappears:
  intended?
- **W13-04:** should the Round 14, 20 and 31 POIs use the race palette (a visible change)?
- **W13-09:** delete the dead pre-planner generators (`wall_tower`, `stilt_platform`,
  `water_channel`, `fish_landing` …) or keep them as a parts shelf?
- **W13-03:** one small fixture for the `parts.lua` registry mirror tables against
  `tools/wp13/stub_registry.lua`?
- **X-08:** may the fixed SHA-256 and population pins in `grug_gathering` and
  `grug_farming` go, now that fixtures guard the content?
- **D18, swimmer exhaustion** (deferred ocean survival): what, if anything, does
  "Exhausted" do to an unmounted swimmer? Today the deterrents are the Kraken, immutable
  deep-ocean terrain and the boat-threat rules ([boats.md](docs/design/boats.md)); no
  swimmer mechanic is authorized.

## After V1

- **WP42, bounded war-front encounters** (scripted battles): the PvP-POI part shipped in
  Round 31 (two fortresses, 16 Battlegrounds war camps with garrisons and quests,
  [pvp.md](docs/design/pvp.md) §6); clash anchors and art are delivered; no war-unit runtime
  ([scope](docs/planning/work-package-scopes.md#wp42)).
- **The Nether (V2):** the decided rules are
  [world.md §10](docs/design/world.md#10-the-nether-v2-a-future-system-not-built), the open
  questions [TODO-design-nether.md](TODO-design-nether.md); the
  [WP46 remainder](#wp46--terrain-damage-guard-explosions-fire-and-lava-never-damage-settlements-or-pois)
  comes with its first fire or explosion source.

## Round carry-overs

The residual notes of each round live in its plan, in a section "Carry-overs" after
"Completion": `docs/planning/round<NN>-plan.md#carry-overs` for Rounds 29–37, 40–49, 51–62,
65–74, 76 and 78–85 (0.45.1 and 0.72.1/0.72.2 as subsections of Rounds 45 and 72), and in
the plans with longer names for
[24](docs/planning/round24-mining-underground-mobs-plan.md#carry-overs),
[25](docs/planning/round25-housing-plan.md#carry-overs),
[26](docs/planning/round26-capitals-housing-cleanup-plan.md#carry-overs),
[27](docs/planning/round27-minimap-plan.md#carry-overs),
[28](docs/planning/round28-questing-leveling-plan.md#carry-overs),
[38](docs/planning/round38-mob-names-plan.md#carry-overs),
[39](docs/planning/round39-web-data-plan.md#carry-overs) and
[0.53.1](docs/planning/round53-fix-plan.md#carry-overs), and
[80.1](docs/planning/round80.1-plan.md#carry-overs). Rounds 50, 63, 64, 75, 75.2 and 75.5
left none. Releases without a plan (0.66.1, the UI modernization 0.60.1 and the UI dialogs
0.61.1) keep theirs in the
[archive](docs/archive/backlog-through-round-79.md#0661--performance-log-lines-carry-overs).
