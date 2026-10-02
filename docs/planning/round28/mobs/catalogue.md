# Round 28 mob catalogue (design input)

Facts about every mob registration that exists today, for the designers
of the Round 28 design round (C1 sub-types, C2/C3 zone files). It covers
all 97 `grug_mobs:` registrations made through `grug_mobs.register_mob`.
Peaceful NPCs (villagers, elders, vendors) are listed at the end; they
are never combat targets. There are no other `mobs:` creature
registrations in the game.

- Machine-readable data: [catalogue.json](catalogue.json), one record per
  entity (model, boxes, speeds, senses, attack, behaviours, environment
  damage, drops, level settings, spawn rows, zones by day and night, kill
  quests and item requests, design notes), plus `meta` with the zone list,
  stat formulas, bandit camps and rares.
- Plan and frame: [round28-questing-leveling-plan.md](../../round28-questing-leveling-plan.md)
  (Goals, Section C) and the C0 design frame.

**State measured:** `main` at `3af1fa54` (2026-10-01). Registration fields,
spawn rows, per-zone casts, density weights and the 240 quests were dumped
from a headless server boot with a disposable capture probe (nothing
committed to the mods); behaviours were read from the source. Section A of
the Round 28 plan changes some numbers while this design round runs:
environmental damage becomes a percentage of max HP (Ruling 6), melee
knockback returns (Ruling 7), hits stop pausing the mob's attack clock
(Ruling 8), the elite scale becomes 1.4 (Ruling 9), HP bars and some
selection boxes are fixed (Ruling 10), and idle aggressive mobs drift away
from roads and towns (Ruling 2). Where this catalogue quotes a value those
rulings replace, it says so.

## 1. Shared mechanics (read once)

### 1.1 Levels, stats and XP

- A mob gets its level once, on its first active step, from the level field
  at its position (`grug_zones.mob_level_at`), clamped to its natural
  minimum (`_grug_min_level`, default 1) and the cap 60. Guards use the
  inverse guard field (20-70). A few actors have a fixed level (Kraken 100,
  dragons 70, kings 65, royal guards 60, whelps 20).
- Below ground the level is `max(surface level, 1 + floor(-y / 20))`:
  y -100 gives L6, -300 L16, -700 L36, -1000 L51.
- Stats are derived, never hand-set (`levels.lua stats_for`):
  HP = 20 + 5L + 0.66L², damage = (2 + 0.3L + 0.005L²) × 1.5
  (`grug_mob_damage_scale`), XP = 10L. Tiers multiply them:

| Tier | HP | Damage | XP | Other |
|---|---|---|---|---|
| normal | ×1 | ×1 | ×1 | armor 100 |
| critter | 1 HP flat | ×1 | 0 | always level 1, no fall damage, never promoted |
| elite | ×3 | ×1.8 | ×4 | armor 80, scale ×1.6 (Ruling 9: ×1.4), gold tint `#ffa800:80`, name prefix "Elite ", telegraph |
| rare | ×5 | ×2.2 | ×6 | armor 70, scale ×2, violet tint `#a64dff:90`, prefix "★ ", telegraph |
| boss | 18000 flat | ×1 | ×1 | dragons only |

| Level | Normal HP / dmg (after ×1.5) / XP | Elite | Rare |
|---|---|---|---|
| 1 | 26 / 3.45 / 10 | 77 / 6.15 / 40 | 128 / 7.65 / 60 |
| 3 | 41 / 4.35 / 30 | 123 / 7.95 / 120 | 205 / 9.75 / 180 |
| 5 | 62 / 5.40 / 50 | 185 / 9.75 / 200 | 308 / 12.00 / 300 |
| 10 | 136 / 8.25 / 100 | 408 / 14.85 / 400 | 680 / 18.15 / 600 |
| 15 | 244 / 11.40 / 150 | 731 / 20.55 / 600 | 1218 / 25.20 / 900 |
| 20 | 384 / 15.00 / 200 | 1152 / 27.00 / 800 | 1920 / 33.00 / 1200 |
| 25 | 558 / 18.90 / 250 | 1673 / 34.05 / 1000 | 2788 / 41.70 / 1500 |
| 30 | 764 / 23.25 / 300 | 2292 / 41.85 / 1200 | 3820 / 51.15 / 1800 |
| 35 | 1004 / 27.90 / 350 | 3011 / 50.25 / 1400 | 5018 / 61.50 / 2100 |
| 40 | 1276 / 33.00 / 400 | 3828 / 59.40 / 1600 | 6380 / 72.60 / 2400 |
| 45 | 1582 / 38.40 / 450 | 4745 / 69.15 / 1800 | 7908 / 84.60 / 2700 |
| 50 | 1920 / 44.25 / 500 | 5760 / 79.65 / 2000 | 9600 / 97.35 / 3000 |
| 55 | 2292 / 50.40 / 550 | 6875 / 90.75 / 2200 | 11458 / 111.00 / 3300 |
| 60 | 2696 / 57.00 / 600 | 8088 / 102.60 / 2400 | 13480 / 125.40 / 3600 |

- Kill XP today: `floor(10·L·tier_xp × 1.5)` with L = min(mob level,
  player level + 5), split between eligible participants within 40 m; zero
  when the mob is 10+ levels below the player. Track B3 replaces this with
  `M(L) = 25 + 5L` (design frame §2.2).
- **Telegraph** (elite and rare only): after 4 s of melee the mob stops for
  a 2 s wind-up ("!!" in its name tag, particles), then hits a 90° frontal
  cone with ×3 damage and 1.5 m extra reach; next wind-up 10 s later.
  Stepping aside dodges it.

### 1.2 Dispositions (fixed per entity name, `grug_mobs/disposition.lua`)

| Disposition | Colour | What the code forces |
|---|---|---|
| critter | white | `passive`, `runaway`: flees when hit, never fights; must also be tier critter (L1, 1 HP, 0 XP) |
| neutral | yellow | never acquires a target on sight (`attack_players = false`), fights back in melee when hit, **group alert off**, no fleeing |
| aggressive | red | attacks players on sight within `view_range`; `group_attack` as the definition sets it |

Every new sub-type name must be added to `disposition.lua`; the registration
errors otherwise. A family keeps one temperament everywhere: a neutral and an
aggressive variant must be different entity names (Ruling 35).

### 1.3 Spawning today

- **Surface rows** are mobs_redo ABM rows: host nodes (the biome top node),
  height 0-600, a light/clock window, `interval`, `chance`, cap. The spawn
  policy adds three gates: the zone's **mob palette**
  (`spawn_policy.lua ZONE_MOB_PALETTES`; capital zones are empty), the
  mob's **clock** (day = time of day 0.1875-0.8125 and light ≥ 10, night =
  the rest and light ≤ 5) and its **natural minimum level**. Some mobs add a
  row check (start-band gates, faction territory, race region). The per-zone
  casts in Section 3 are the result.
- **Regional lookalikes**: one boar registration per zone
  (`BOAR_VARIANT_BY_ZONE`) and one member of the zombie/husk, spider,
  cat and skeleton-archer groups per zone where `ZONE_LOOKALIKE_SELECTION`
  names one.
- **Hostile spawns never happen inside a start town footprint** (128-node
  pad + 12 band, down to the town floor) or an active housing claim.
  `mob_nospawn_range = 24`: nothing spawns within 24 nodes of a player.
- **Density budget** (`density.lua`): ordinary palette species share a
  budget of 15 mobs by day and 23 by night within 128 nodes of a spawn
  point; each species gets a share by its row cap ("weight") and always refills below
  its own old cap. Critters, shore crabs, underground rows, camps, rares,
  water mobs, guards and bosses are outside the budget.
- **Wander leash**: a free-roaming mob idles within 32 nodes of its spawn
  point (`_grug_home`). Camp members idle within 20 of their fire.
- **Underground rows** (y below -40) ignore zone palettes; they are gated by
  depth band and light ≤ 5, and their level comes from depth (see 1.1).
- **Camps**: bandit camp fires spawn 3-5 members (1 in 3 is a Bandit
  Archer), refilling one slot every 120-300 s while a player is within 80 m.
  Twelve bandit camps exist (six in the 11-20 home zones, six in the 31-40
  contested zones). The Mirefolk camp type exists but no Mirefolk camp fire
  is placed, so Mirefolk never appear today.
- **Named rares** (10 routes, `rares.lua`): a normal entity promoted to the
  rare tier, walking a fixed route, respawn 2-4 h after the kill, announced
  to the faction whose land it appears on (no announcement on contested
  land). Rares are not quest targets (Ruling 38).
- **Elite rolls**: 1 in 10 bears spawns as "Elder Bear" and 1 in 10 jungle
  apes as "Silverback" (random, so not usable as a fixed quest climax).
  Golems, the War Construct, the Land Guard and the Reef Lurker are elite by
  definition.

### 1.4 Combat behaviour shared by all

- **Run speed** 4.6 for melee hostiles and retaliating prey (players run
  4.0), 4.0 for bow users (skeleton archers, raiders, frost strays, bandit
  archers, poachers, bog witch), 3.4 for critters, crabs and the lava
  flan, 2.6 for the bog ooze, 6 for the glowwing; idle walk at most 2.5.
- **Chase end**: a free-roaming hostile chases without a distance limit
  and gives up 15 s after the last effective damage it took (while its
  target keeps moving), then **evades**: runs home at 1.5× speed, takes no
  damage and heals. Camp members, rares and patrols use a drag leash
  instead (default 40 m from where the chase began, bandits and Mirefolk
  25, rares at least 300); such bound melee chasers more than 25 m behind
  their target drop to walk speed (ranged families opt out). Free roamers
  keep running.
- **Group alert** (`group_attack`): when one is hit, every mob **of the same
  entity name** within its view range that has `group_attack` joins. The
  pack (`pack_hunter`) and swarm (`camp_swarm`) verbs also match the same
  entity name only.
- **Attack types**: `dogfight` (melee), `dogshoot` (shoots at range, melee up
  close), `explode` (Rift Spawn). Projectiles: arrow (speed 16), rock (12),
  crystal fragment (8), fireball (7), ember (10), hex bottle (8, homing).
- **Loot**: static drop lists (same everywhere, not tier dependent), rolled
  only if a player damaged the mob within the last 60 s. In addition every
  non-critter rolls quality gear of its level's tier: 3 % uncommon (normal),
  20 % uncommon + 3 % rare (elite), 100 % uncommon + 25 % rare (rare).
  The drop-hook registry `grug_mobs.register_drop_hook` exists and is empty
  (Ruling 36/41 use it).

## 2. Constraints for sub-types and quests

These follow from the code and decide what a sub-type or quest can do
without new mechanics.

1. **Entity name is the key for everything.** Quest kill matching, density
   weights, the disposition table, group alert, pack calls and swarms all
   use the exact entity name. A "Small Boar" registration does not answer a
   "Boar"'s alert, does not count toward a "kill Boars" quest, and gets its
   own density weight. Design quests per sub-type role (that is what the
   frame's `role` is for), and expect packs to form per role.
2. **Neutral means no group alert.** The neutral disposition switches
   `group_attack` off, so neutral sub-types are always single pulls.
3. **Critters are never kill targets**, are always level 1 with 1 HP and
   cannot be promoted. Today one quest targets the Wild Turkey
   (`r14_human_05_the_missing_flock`); it must change.
4. **Fliers** (Crag Eagle, Vulture, Carrion Crow, Wisp, Blood Bat,
   Glowwing, Ember Wisp, and the critter birds and bats) need open air;
   melee players wait for them to come down. Wisp, Glowwing and Ember Wisp
   are non-physical and drift through walls and trees. Do not place flier
   kill targets in caves or dense canopy without air space.
5. **Swimmers stay in water**: the Kraken (deep ocean only) and the Reed
   Angelfish (inland lakes only). Neither is a quest target (Kraken 0 XP,
   angelfish critter). The Crocodile and Bog Fowl only float; they walk on
   land.
6. **Only the zombie burns in the sun** (light_damage 2 at light 14-15;
   Ruling 6 makes it 5 %/s). The Sun-Dried Husk, all skeletons and every
   other night family do **not** burn, they only *spawn* at night. Zombies
   spawned on blight dirt never burn (they spawn there around the clock).
   Day kill quests on zombies therefore only work on blight ground or
   underground.
7. **Night truce**: players of the Undead race (perk `zombie_night_truce`)
   are ignored by zombies at night unless they hit that zombie. Only the
   zombie has it.
8. **Self-destructing Rift Spawn**: its burst removes it without a death,
   so a burst gives no XP, loot or quest credit.
9. **Elite-by-definition families** (Stone/Mesa Golem, War Construct, Land
   Guard, Reef Lurker) spawn rarely (cap 1; golems, construct and land
   guard at chance 7000-12000 every 30 s) and always telegraph; they suit
   climaxes and area leaders, not 10-kill quests.
10. **Level gates already in code**: natural minimum level 10 for Wolf,
    Blightfang Wolf and Hyena, 4 for Jungle Lynx, 3 for Zombie and Husk;
    start-band gate L4+ for Fox, Ibex, Tapir, Scorpion and Viper inside the
    six start zones; Poacher L7+ in Silverleaf; Husk L4+ in Sunscar;
    Speargrass Tiger L21-50; Shore Crab below L45, Reef Lurker L45-60.
    In zones with spawn areas (Ruling 34) the area's fixed level range
    replaces the field; the frame decides whether these gates move to the
    areas.
11. **Boxes below the origin**: Giant/Pale/Jungle Spider (-0.75), golems,
    treants, Oerkki, Dungeon Master and Land Guard (-1). Scaling a sub-type
    scales the box with it; small spider sub-types stay wide.
12. **Size quirks** (Ruling 10 fixes the bars): HP bars are divided by
    `visual_size` today, so meshes registered at large `visual_size`
    (fox 10, turkey 10, stag 8, bog ooze 12.5, crystal shard 10, crow 14)
    have tiny bars, small ones (serpent 0.3, viper 0.6) huge bars. Sub-type
    size factors multiply the registered `visual_size`.
13. **Camp-only and empty families**: Bandit and Bandit Archer exist only at
    camp fires; Mirefolk never spawn today. Ruling 37 gives all three free
    areas.
14. **Drops are per entity, not per level band** (zombies drop iron bars at
    1/10 everywhere, the War Construct 2-4 iron bars per kill). Ruling 36
    replaces this with band tables; the Wisp has no drop at all.
15. **Regional selection**: a zone may currently allow only one boar tint
    and one member of each lookalike group. Sub-types that should appear
    next to their base in the same zone need their own palette entries
    (Track B1).

## 3. Where mobs live today (zone casts)

Effective day and night casts per zone. The palette, regional selection
and clock part comes from the running server (`zone_density_cast`,
`zone_clock_cast`); on top of that the faction check of rabbit/hare, the
golem race regions, the skeleton archer's host rule and a host-node test
were applied: a mob whose spawn nodes are not among the surface nodes of
the zone's biomes (`wp40/r6_content.lua` fertile palettes) is dropped from
the zone (the record lists it under `palette_zones_without_host`), and one
that only finds incidental gravel, sand or stone is marked `°` (thin).
This host test is derived from the biome lists, not counted in a world.
Not shown: level gates inside a zone (Section 2.10), shore crabs and gulls
(every coast), underground mobs, Kraken (deep ocean everywhere) and Reed
Angelfish (inland lakes everywhere). Zone levels and factions from
`wp40/source/simple_map.lua`.

Palette entries without any host surface today: Bear, Wolf, Stag and Giant
Spider in Ossuary Reach, Blackwind Rise and Gravesalt Escarpment;
Blightfang Wolf, Gaunt Stag, Plaguehide Bear, Bone Weevil (and Pale Spider
outside Glassroot) in Whitebridge Shire, Ashenward March, Moonfall Wood and
Glassroot Wilds; Skeleton Archer in Whitebridge Shire, Moonfall Wood and
Glassroot Wilds; Hyena and Vulture in Frostbarrow Shelf, Stormvault
Heights and The Wyrmglass Crown. The "forest" palette names both
continents' forest families, the host nodes split them.

| # | Zone | Levels | Faction / PvP | Day cast | Night cast | Also |
|---|---|---|---|---|---|---|
| 1 | Hearthpine Vale | 1-10 | accord / peaceful | boar, fox, ibex, rabbit | giant_rat, zombie |  |
| 2 | Copperfell Foothills | 11-20 | accord / peaceful | boar, fox, ibex, rabbit | goblin_hound, goblin_raider, goblin_slinger, zombie | bandit camp (home) |
| 3 | Dur Brannoc | 20-30 | accord / peaceful | (capital zone: empty palette) | (capital zone: empty palette) |  |
| 4 | Frostbarrow Shelf | 21-30 | accord / peaceful | crag_eagle, ibex, mountain_ram, stone_golem | goblin_hound, goblin_raider, goblin_slinger, snow_leopard, stone_golem |  |
| 5 | Stormvault Heights | 31-40 | none / contested | crag_eagle, ibex, mountain_ram, stone_golem | frost_stray, goblin_hound, goblin_raider, goblin_slinger, snow_leopard, stone_golem | bandit camp (frontier); rare Korgan's Bane |
| 6 | Dawnmere Fields | 1-10 | accord / peaceful | boar, fox, rabbit, wild_turkey | giant_rat, zombie |  |
| 7 | Goldmead Vale | 11-20 | accord / peaceful | boar, fox, rabbit, wild_turkey | poacher, zombie | bandit camp (home); rare Grimtusk |
| 8 | Highcourt | 20-30 | accord / peaceful | (capital zone: empty palette) | (capital zone: empty palette) |  |
| 9 | Whitebridge Shire | 21-30 | accord / peaceful | bear, boar, rabbit, stag, wolf | giant_spider, poacher, wisp, wolf, zombie | Mirefolk POI (empty) |
| 10 | Ashenward March | 31-40 | none / contested | bear, carrion_crow, stag, wolf | ashen_treant, carrion_crow, giant_spider, poacher, skeleton_raider, wisp, wolf, zombie | bandit camp (frontier); rare Old Whitefang |
| 11 | Silverleaf Glades | 1-10 | accord / peaceful | boar, fox, rabbit, song_bird | giant_rat, poacher, zombie |  |
| 12 | Starbough Vale | 11-20 | accord / peaceful | boar, fox, rabbit | poacher, zombie | bandit camp (home) |
| 13 | Lethariel | 20-30 | accord / peaceful | (capital zone: empty palette) | (capital zone: empty palette) |  |
| 14 | Lorindor | 21-30 | accord / peaceful | stag | poacher, wisp | Mirefolk POI (empty) |
| 15 | Moonfall Wood | 21-30 | accord / peaceful | bear, stag, wolf | giant_spider, poacher, wisp, wolf |  |
| 16 | Glassroot Wilds | 31-40 | none / contested | bear, jungle_ape, serpent, stag, wolf | jungle_spider, panther, wisp, wolf | bandit camp (frontier) |
| 17 | Stillgrave Hollow | 1-10 | throng / peaceful | hare, plague_boar | giant_rat, zombie |  |
| 18 | Mournfen | 11-20 | throng / peaceful | bog_fowl, bog_ooze, crocodile, hare, plague_boar | bog_ooze, crocodile, wisp, zombie | bandit camp (home); Mirefolk POI (empty) |
| 19 | Nhal Veyr | 20-30 | throng / peaceful | (capital zone: empty palette) | (capital zone: empty palette) |  |
| 20 | Ossuary Reach | 21-30 | throng / peaceful | blightfang_wolf, bone_weevil, gaunt_stag, plaguehide_bear | blightfang_wolf, gravewood_treant, pale_spider, skeleton_archer |  |
| 21 | Blackwind Rise | 31-40 | none / contested | blightfang_wolf, bone_weevil, gaunt_stag, plaguehide_bear | blightfang_wolf, gravewood_treant, pale_spider, skeleton_archer | bandit camp (frontier); rare Marrowclaw |
| 22 | Sunscar Flats | 1-10 | throng / peaceful | boar, hare, plains_runner, scorpion | giant_rat, scorpion, sun_dried_husk |  |
| 23 | Redtusk Savanna | 11-20 | throng / peaceful | boar, hare, hyena, zebra | hyena, scorpion, sun_dried_husk | bandit camp (home); rare Ashmaw |
| 24 | Gor Drazhak | 20-30 | throng / peaceful | (capital zone: empty palette) | (capital zone: empty palette) |  |
| 25 | Speargrass Reach | 21-30 | throng / peaceful | crag_eagle°, hyena, mesa_golem, mountain_ram°, speargrass_tiger, vulture, zebra | goblin_hound, goblin_raider, goblin_slinger, hyena, mesa_golem, scorpion |  |
| 26 | Bannerbreak Mesa | 31-40 | none / contested | carrion_crow, crag_eagle°, hyena, mesa_golem, mountain_ram°, vulture | carrion_crow, goblin_hound, goblin_raider, goblin_slinger, hyena, mesa_golem, scorpion, skeleton_raider, zombie | bandit camp (frontier); rare Dustwing |
| 27 | Kapok Cradle | 1-10 | throng / peaceful | hare, jungle_boar, jungle_lynx, parrot, tapir, viper | giant_rat, viper, zombie |  |
| 28 | Raincall Basin | 11-20 | throng / peaceful | hare, jungle_boar, jungle_lynx, parrot, tapir | viper, zombie | bandit camp (home) |
| 29 | Kezamba | 20-30 | throng / peaceful | (capital zone: empty palette) | (capital zone: empty palette) |  |
| 30 | Whispering Reedlands | 21-30 | throng / peaceful | bog_fowl, bog_ooze, crocodile, jungle_lynx, parrot, tapir | bog_ooze, crocodile, wisp | Mirefolk POI (empty) |
| 31 | Totemwater Reach | 21-30 | throng / peaceful | bog_fowl, bog_ooze, crocodile, jungle_lynx, parrot, tapir | bog_ooze, crocodile, wisp |  |
| 32 | Thunderroot Wilds | 31-40 | none / contested | jungle_ape, serpent | bog_witch, jungle_spider, panther | bandit camp (frontier) |
| 33 | The Wyrmglass Crown | 60 | none / contested | carrion_crow, crag_eagle, mountain_ram, stone_golem | carrion_crow, frost_stray, rift_spawn, snow_leopard, stone_golem, zombie | dragon: Ice Dragon |
| 34 | Gravesalt Escarpment | 51-59 | none / contested | blightfang_wolf, bone_weevil, carrion_crow, gaunt_stag, plaguehide_bear | blightfang_wolf, bog_witch, carrion_crow, pale_spider, rift_spawn, skeleton_raider, zombie |  |
| 35 | The Broken Causeway | 31-40 | none / contested | carrion_crow, war_construct | bog_witch, carrion_crow, skeleton_raider, war_construct, wisp, zombie | rare Captain Bonerattle |
| 36 | The Shattered Line | 41-50 | none / contested | carrion_crow, crag_eagle°, hyena, mesa_golem, mountain_ram°, speargrass_tiger, vulture, war_construct | carrion_crow, hyena, mesa_golem, scorpion, skeleton_raider, sun_dried_husk, war_construct | rare Captain Bonerattle |
| 37 | The Skyglass Canopy | 51-59 | none / contested | carrion_crow, jungle_ape, serpent | carrion_crow, jungle_spider, panther, rift_spawn, skeleton_raider, zombie | rare Silkfang |
| 38 | Stormscale Summit | 60 | none / contested | carrion_crow, jungle_ape, serpent | bog_witch, carrion_crow, jungle_spider, panther, rift_spawn, skeleton_raider, zombie | rare Emerald Coil; dragon: Jungle Wyvern |

### Underground by depth (all zones; surface footprint of start towns excluded down to the town floor)

| Depth (y) | Hostile | Critter |
|---|---|---|
| -40 … -100 | Zombie, Giant Spider, Giant Rat, Spiderling; Stone Golem (Accord region) / Mesa Golem (Throng region) rare | Cave Bat, Cave Crawler |
| -100 … -300 | Zombie, Giant Spider, Giant Rat, Blood Bat (from -101), Goblin Miner, Goblin Miner Slinger; golems | Cave Bat, Cave Crawler |
| -300 … -700 | Zombie, Giant Spider, Oerkki, Glowwing (to -500), Crystal Shard, Dungeon Master (from -500); golems | Cave Bat, Cave Crawler |
| -700 … -1000 | Zombie, Giant Spider, Dungeon Master, Lava Flan, Ember Wisp, Stone Mite; golems | Cave Bat, Cave Crawler |
| below -1000 | Zombie, Giant Spider, Lava Flan, Ember Wisp, Stone Mite, Land Guard (elite), Rift Spawn; golems | Cave Bat, Cave Crawler |

## 4. Families and models

| Family | Registrations (entity → display name) | Model | Disposition |
|---|---|---|---|
| Boar | `boar` → Boar; `jungle_boar` → Jungle Boar; `plague_boar` → Plague Boar | grug_mobs_boar.b3d (2 slots: body + blank saddle) | neutral |
| Zombie / Husk | `sun_dried_husk` → Sun-Dried Husk; `zombie` → Zombie | grug_mobs_zombie.b3d (2 slots: armour overlay + skin) | aggressive |
| Rabbit / Hare (critter) | `hare` → Hare; `rabbit` → Rabbit | grug_mobs_rabbit.b3d | critter |
| Wolf | `blightfang_wolf` → Blightfang Wolf; `wolf` → Wolf | grug_mobs_wolf.b3d | aggressive |
| Bear | `bear` → Bear; `plaguehide_bear` → Plaguehide Bear | grug_mobs_bear.b3d | aggressive |
| Stag | `gaunt_stag` → Gaunt Stag; `stag` → Stag | grug_mobs_stag.b3d | neutral |
| Spider | `giant_spider` → Giant Spider; `jungle_spider` → Jungle Spider; `pale_spider` → Bonelurker Spider; `spiderling` → Spiderling | grug_mobs_spider.b3d | aggressive |
| Skeleton (archer, raider, stray, witch) | `bog_witch` → Bog Witch; `frost_stray` → Frost Stray; `skeleton_archer` → Skeleton Archer; `skeleton_raider` → Skeleton Raider | grug_mobs_skeleton.b3d (3 slots: blank, body, held item) | aggressive |
| Bird of prey | `crag_eagle` → Crag Eagle; `vulture` → Vulture | grug_mobs_eagle.b3d (18-slot atlas) | aggressive |
| Golem | `mesa_golem` → Mesa Golem; `stone_golem` → Stone Golem | grug_mobs_stone_golem.b3d | aggressive |
| Mountain Ram | `mountain_ram` → Mountain Ram | grug_mobs_ram.b3d (2 slots: fleece + body) | neutral |
| Hyena | `hyena` → Hyena | grug_mobs_hyena.b3d (16-slot atlas) | aggressive |
| Zebra | `zebra` → Zebra | grug_mobs_zebra.b3d (12-slot atlas) | neutral |
| Big cat (lynx, panther, snow leopard) | `jungle_lynx` → Jungle Lynx; `panther` → Panther; `snow_leopard` → Snow Leopard | grug_mobs_panther.b3d (17-slot atlas) | aggressive |
| Speargrass Tiger | `speargrass_tiger` → Speargrass Tiger | grug_mobs_speargrass_tiger.b3d | aggressive |
| Serpent | `serpent` → Serpent | grug_mobs_serpent.b3d (15-slot atlas) | aggressive |
| Scorpion / Viper (poison family) | `scorpion` → Scorpion; `viper` → Viper | grug_mobs_scorpion.b3d, grug_mobs_viper.b3d | aggressive |
| Jungle Ape | `jungle_ape` → Jungle Ape | grug_mobs_jungle_ape.b3d (20-slot atlas) | aggressive |
| Small birds (gull mesh) | `carrion_crow` → Carrion Crow; `gull` → Gull; `song_bird` → Song Bird | grug_mobs_gull.b3d | critter, neutral |
| Parrot (critter) | `parrot` → Parrot | grug_mobs_parrot.b3d | critter |
| Kraken | `kraken` → Kraken Guard | grug_mobs_kraken.b3d | aggressive |
| Reed Angelfish (critter) | `reed_angelfish` → Reed Angelfish | grug_mobs_reed_angelfish.b3d | critter |
| Crocodile | `crocodile` → Crocodile | grug_mobs_crocodile.b3d (15-slot atlas) | aggressive |
| Bog Ooze | `bog_ooze` → Bog Ooze | grug_mobs_bog_ooze.b3d (2 slots) | aggressive |
| Outlaws (bandit, archer, poacher) | `bandit` → Bandit; `bandit_archer` → Bandit Archer; `poacher` → Poacher | character.b3d (player model, race skin via grug_visuals) | aggressive |
| Mirefolk | `mirefolk` → Mirefolk | character.b3d at 0.85 | aggressive |
| Fox | `fox` → Fox | grug_mobs_fox.b3d | aggressive |
| Ibex | `ibex` → Ibex | grug_mobs_ibex.b3d | neutral |
| Wild Turkey (critter) | `wild_turkey` → Wild Turkey | grug_mobs_wild_turkey.b3d | critter |
| Plains Runner | `plains_runner` → Plains Runner | grug_mobs_plains_runner.b3d | neutral |
| Tapir | `tapir` → Tapir | grug_mobs_tapir.b3d | neutral |
| Giant Rat | `giant_rat` → Giant Rat | grug_mobs_giant_rat.b3d | aggressive |
| Goblin (raider, slinger, miners) | `goblin_miner` → Goblin Miner; `goblin_miner_slinger` → Goblin Miner Slinger; `goblin_raider` → Goblin Raider; `goblin_slinger` → Goblin Slinger | grug_mobs_goblin.b3d | aggressive |
| Goblin Raider Hound | `goblin_hound` → Goblin Raider Hound | grug_mobs_goblin_hound.b3d | aggressive |
| Wisp | `ember_wisp` → Ember Wisp; `wisp` → Wisp | grug_mobs_wisp.b3d (2 slots: held sword + body) | aggressive |
| Treant | `ashen_treant` → Ashen Treant; `gravewood_treant` → Gravewood Treant | grug_mobs_treant.b3d | aggressive |
| Bat | `blood_bat` → Blood Bat; `cave_bat` → Cave Bat | grug_mobs_cave_bat.b3d | aggressive, critter |
| Crawler (cave crawler, bone weevil, stone mite) | `bone_weevil` → Bone Weevil; `cave_crawler` → Cave Crawler; `stone_mite` → Stone Mite | grug_mobs_cave_crawler.b3d | aggressive, critter |
| Oerkki | `oerkki` → Oerkki | grug_mobs_oerkki.b3d | aggressive |
| Glowwing | `glowwing` → Glowwing | grug_mobs_glowwing.b3d | aggressive |
| Crystal Shard | `crystal_shard` → Crystal Shard | grug_mobs_crystal_shard.b3d | aggressive |
| Dungeon Master / Land Guard | `dungeon_master` → Dungeon Master; `land_guard` → Land Guard | grug_mobs_dungeon_master.b3d | aggressive, guard |
| Lava Flan | `lava_flan` → Lava Flan | grug_mobs_lava_flan.b3d | aggressive |
| Rift Spawn | `rift_spawn` → Rift Spawn | grug_mobs_rift_spawn.b3d | aggressive |
| War Construct | `war_construct` → War Construct | grug_mobs_war_construct.b3d | aggressive |
| Crab (shore crab, reef lurker) | `reef_lurker` → Reef Lurker; `shore_crab` → Shore Crab | grug_mobs_shore_crab.b3d | neutral |
| Bog Fowl (critter) | `bog_fowl` → Bog Fowl | grug_mobs_bog_fowl.b3d | critter |
| Dragons and whelps | `ice_dragon` → Wyrmglass Ice Dragon; `ice_whelp` → Wyrmglass Ice Dragon Whelp; `jungle_wyvern` → Stormscale Jungle Wyvern; `storm_whelp` → Stormscale Jungle Wyvern Whelp | grug_mobs_ice_dragon.b3d, grug_mobs_jungle_wyvern.b3d | aggressive |
| Faction guards | `guard_accord` → Accord Guard; `guard_throng` → Throng Guard | character.b3d | guard |
| Kings and royal guards | `king_dwarf` → King of Dur Brannoc; `king_elf` → King of Lethariel; `king_human` → King of Highcourt; `king_orc` → King of Gor Drazhak; `king_troll` → King of Kezamba; `king_undead` → King of Nhal Veyr; `royal_guard_dwarf` → King of Dur Brannoc Royal Guard; `royal_guard_elf` → King of Lethariel Royal Guard; `royal_guard_human` → King of Highcourt Royal Guard; `royal_guard_orc` → King of Gor Drazhak Royal Guard; `royal_guard_troll` → King of Kezamba Royal Guard; `royal_guard_undead` → King of Nhal Veyr Royal Guard | character.b3d | aggressive, guard |

### 4.1 Models and textures available for tint variants

New sub-types reuse a mesh and change size, name and tint (no new skins,
plan C4). Tints in use today are either a baked texture or a runtime
texture modifier on the base texture; both work for new sub-types.

| Mesh | Base texture(s) | Existing tints / alternates |
|---|---|---|
| `grug_mobs_boar.b3d` | `grug_mobs_boar.png` (+ blank saddle slot) | runtime `^[multiply:#9a7a5a` (base boar); baked `grug_mobs_boar_plague.png`, `grug_mobs_boar_jungle.png` |
| `grug_mobs_zombie.b3d` | blank armour slot + `grug_mobs_zombie.png` | runtime `^[multiply:#c99b55` (Sun-Dried Husk) |
| `grug_mobs_skeleton.b3d` | blank + `grug_mobs_skeleton.png` + held-item slot | baked `grug_mobs_skeleton_raider.png`; runtime `^[multiply:#a8d8ef` (Frost Stray), `^[colorize:#5f8b4c:110` (Bog Witch, bottle in the item slot) |
| `grug_mobs_spider.b3d` | `grug_mobs_spider.png` | baked `grug_mobs_spider_pale.png`, `grug_mobs_spider_jungle.png`; runtime `^[multiply:#786b63` at 0.75 (Spiderling) |
| `grug_mobs_panther.b3d` | `grug_mobs_panther.png` (17-slot atlas) | baked `grug_mobs_jungle_lynx.png`, `grug_mobs_snow_leopard.png` |
| `grug_mobs_wolf.b3d` | `grug_mobs_wolf.png` | baked `grug_mobs_wolf_blightfang.png` |
| `grug_mobs_bear.b3d` | `grug_mobs_bear.png` | baked `grug_mobs_bear_plaguehide.png` |
| `grug_mobs_stag.b3d` | `grug_mobs_stag.png` | baked `grug_mobs_stag_gaunt.png` |
| `grug_mobs_eagle.b3d` | `grug_mobs_eagle.png` (18-slot atlas) | baked `grug_mobs_vulture.png` |
| `grug_mobs_stone_golem.b3d` | `grug_mobs_stone_golem.png` | baked `grug_mobs_mesa_golem.png` |
| `grug_mobs_gull.b3d` | `grug_mobs_gull.png` | runtime `^[multiply:#78aee8` (Song Bird); baked `grug_mobs_crow.png` |
| `grug_mobs_goblin.b3d` | `grug_mobs_goblin_raider.png` | baked `grug_mobs_goblin_slinger.png` (miners reuse both) |
| `grug_mobs_treant.b3d` | `grug_mobs_treant.png` | runtime `^[multiply:#6d5140` (Ashen), `^[multiply:#c2bba8` (Gravewood) |
| `grug_mobs_cave_bat.b3d` | `grug_mobs_cave_bat.png` | runtime `^[multiply:#8f2635` at 1.25 (Blood Bat) |
| `grug_mobs_cave_crawler.b3d` | `grug_mobs_cave_crawler.png` | baked `grug_mobs_bone_weevil.png`, `grug_mobs_bone_weevil_blight.png`; runtime `^[multiply:#77736b` at 4 (Stone Mite) |
| `grug_mobs_wisp.b3d` | held sword + `grug_mobs_wisp.png` | runtime `^[colorize:#ff5a1e:140` (Ember Wisp) |
| `grug_mobs_dungeon_master.b3d` | `grug_mobs_dungeon_master.png`, `…2`, `…4` (random) | baked `grug_mobs_land_guard.png`, `…2`, `…3` |
| `grug_mobs_lava_flan.b3d` | `grug_mobs_lava_flan.png`, `…2`, `…3` (random) | - |
| `grug_mobs_oerkki.b3d` | `grug_mobs_oerkki.png`, `grug_mobs_oerkki4.png` (random) | - |
| `character.b3d` (player model) | `grug_mobs_bandit_1/2.png`, `grug_mobs_mirefolk.png`, guard and royal skins | runtime `^[multiply:#6b5948` (Poacher); bandits and guards get race skins and armour from `grug_visuals` |
| single-texture meshes | `fox`, `giant_rat`, `ibex`, `tapir`, `plains_runner`, `wild_turkey`, `scorpion`, `viper`, `serpent` (atlas), `hyena` (atlas), `zebra` (atlas), `jungle_ape` (atlas), `crocodile` (atlas), `ram` (fleece + body), `rabbit` / `hare_dust`, `parrot`, `bog_fowl`, `bog_ooze`, `shore_crab`, `goblin_hound`, `speargrass_tiger`, `war_construct`, `rift_spawn`, `crystal_shard`, `glowwing`, `reed_angelfish`, `kraken` | no tint yet; any of them can take a runtime `^[multiply:`/`^[colorize:` modifier |
| dragons | `grug_mobs_ice_dragon.b3d`, `grug_mobs_jungle_wyvern.b3d` | boss-only |

Elite and rare tints are layered on top of whatever base texture a sub-type
uses (`^[colorize:#ffa800:80` / `#a64dff:90`), so a sub-type tint should stay
readable under gold and violet.

## 5. All registrations at a glance

Speeds in nodes/s, view and reach in nodes. "Collision box" gives width and
the vertical extent relative to the entity origin. The design note is the
short "what makes it distinct"; sub-type ideas and constraints per entity
are in Section 6 and in `catalogue.json` (`design_notes`).

| Entity | Display | Disposition, tier | Clock | Walk/run | View/reach | Attack | Visual size | Collision box (y min..max) | Sun | Design note |
|---|---|---|---|---|---|---|---|---|---|---|
| `ashen_treant` | Ashen Treant | aggressive | night | 1.5/4.6 | 12/3 | dogfight | 1 | 0.60 wide, -1..0.75 | - | Night tree-creature: slows everyone near it; drops sticks and apples. |
| `bandit` | Bandit | aggressive | any | 1/4.6 | 14/3 | dogfight | 1 | 0.60 wide, 0..1.7 | - | Humanoid group fight at a fixed place. |
| `bandit_archer` | Bandit Archer | aggressive | any | 1/4 | 16/3 | dogshoot (arrow_entity, 2.5s) | 1 | 0.60 wide, 0..1.7 | - | Ranged camp member. |
| `bear` | Bear | aggressive | day | 1/4.6 | 12/3 | dogfight | 3 | 1.40 wide, -0.01..1.39 | - | Big (visual 3, box 1.4 high), notices late (view 12), hits like every melee mob but has the elite roll built in. |
| `blightfang_wolf` | Blightfang Wolf | aggressive | any | 1.5/4.6 | 14/3 | dogfight | 1 | 0.60 wide, -0.01..0.84 | - | Undead-forest wolf, same pack fight. |
| `blood_bat` | Blood Bat | aggressive | any | 1.5/4.6 fly | 12/2 | dogfight | 1.25 | 0.62 wide, -0.01..1.11 | - | Hostile bat swarm in mid caves. |
| `boar` | Boar | neutral | day | 1/4.6 | 10/3 | dogfight | 1 | 0.90 wide, -0.01..0.86 | - | The starter target: never starts a fight, only fights back; the charge makes the last metres sudden. |
| `bog_fowl` | Bog Fowl | critter | day | 1.5/3.4 | 8/- | - | 1 | 0.40 wide, -0.01..0.69 | - | Swamp scenery. |
| `bog_ooze` | Bog Ooze | aggressive | any | 1/2.6 | 10/3 | dogfight | 12.5 | 2.04 wide, -0.01..2.03 | - | Slow blob you can outrun but must not stand next to; big box (2 x 2 nodes). |
| `bog_witch` | Bog Witch | aggressive | night | 1.5/4 | 16/3 | dogshoot (hex_bottle, 2.5s) | 1 | 0.60 wide, -0.01..1.98 | - | Caster enemy: punishes standing still at range; the bottle homes in. |
| `bone_weevil` | Bone Weevil | critter | day | 1.5/3.4 | 8/- | - | 3 | 0.80 wide, -0.01..0.44 | - | Bone-forest and blight scenery; the row stamps one of two textures. |
| `carrion_crow` | Carrion Crow | neutral | any | 1.5/4.6 fly | 8/- | dogfight | 14 | 0.60 wide, 0..0.6 | - | Neutral war-front scavenger: feathers only. |
| `cave_bat` | Cave Bat | critter | any | 1.5/3.4 fly | 8/- | - | 1 | 0.50 wide, -0.01..0.89 | - | Cave scenery. |
| `cave_crawler` | Cave Crawler | critter | any | 1.5/3.4 | 8/- | - | 3 | 0.80 wide, -0.01..0.44 | - | Cave scenery. |
| `crag_eagle` | Crag Eagle | aggressive | day | 2/4.6 fly | 16/3 | dogfight | 1 | 0.60 wide, -0.01..0.5 | - | Aggressive day flier with view 16: spots players early and attacks from above. |
| `crocodile` | Crocodile | aggressive | any | 1/4.6 | 6/3 | dogfight | 1 | 1.20 wide, -0.01..0.95 | - | Invisible until you are close: view range 6, lurks still in swamp mud. |
| `crystal_shard` | Crystal Shard | aggressive | any | 1.5/4.6 | 16/3 | dogshoot (crystal_shard_entity, 1.6s) | 10 | 1.20 wide, -0.5..1.8 | - | Deep turret-like shooter; emberglass source. |
| `dungeon_master` | Dungeon Master | aggressive | any | 1.5/4.6 | 16/3 | dogshoot (dungeon_fireball, 2.2s) | 1 | 1.00 wide, -1..1.6 | - | Deep caster; emberglass and rough diamond. |
| `ember_wisp` | Ember Wisp | aggressive | any | 2.5/4.6 fly | 16/2 | dogshoot (ember_entity, 2s) | 1.25 | 0.40 wide, 0.2..1 | - | Deep fire wisp. |
| `fox` | Fox | aggressive | day | 1.5/4.6 | 12/3 | dogfight | 10 | 0.70 wide, -0.01..0.5 | - | Small aggressive day hunter that bites and darts away - annoying to melee. |
| `frost_stray` | Frost Stray | aggressive | night | 1/4 | 16/3 | dogshoot (arrow_entity, 2.5s) | 1 | 0.60 wide, -0.01..1.98 | - | Ice-blue skeleton archer of the dwarf mountains and Wyrmglass. |
| `gaunt_stag` | Gaunt Stag | neutral | day | 1.5/4.6 | 12/- | dogfight | 8 | 1.00 wide, -0.01..1.8 | - | Undead-forest grazer. |
| `giant_rat` | Giant Rat | aggressive | night | 1.5/4.6 | 10/3 | dogfight | 1.6 | 1.28 wide, -0.01..0.96 | - | Night swarm animal of start towns; one pull brings the nest. |
| `giant_spider` | Giant Spider | aggressive | night | 1/4.6 | 12/3 | dogfight | 1.5 | 2.10 wide, -0.75..0 | - | Wide (box 2.1 x 2.1, origin at the top of the box) night hunter whose bite makes you slow - running away gets hard. |
| `glowwing` | Glowwing | aggressive | any | 2/6 fly | 12/2 | dogfight | 1.5 | 0.30 wide, -0.01..0.3 | - | Glowing cave flier swarm. |
| `goblin_hound` | Goblin Raider Hound | aggressive | night | 1.5/4.6 | 15/3 | dogfight | 1 | 0.90 wide, -0.01..0.85 | - | Display name 'Goblin Raider Hound'; the dog of the raid (view 15). |
| `goblin_miner` | Goblin Miner | aggressive | any | 1.5/4.6 | 12/3 | dogfight | 1 | 0.50 wide, -0.01..0.9 | - | Cave goblin melee. |
| `goblin_miner_slinger` | Goblin Miner Slinger | aggressive | any | 1.5/4.6 | 16/3 | dogshoot (rock_entity, 2.5s) | 1 | 0.50 wide, -0.01..0.9 | - | Cave goblin slinger. |
| `goblin_raider` | Goblin Raider | aggressive | night | 1.5/4.6 | 12/3 | dogfight | 1 | 0.50 wide, -0.01..0.9 | - | Night raiding party melee. |
| `goblin_slinger` | Goblin Slinger | aggressive | night | 1.5/4.6 | 16/3 | dogshoot (rock_entity, 2.5s) | 1 | 0.50 wide, -0.01..0.9 | - | Ranged member of the raiding party. |
| `gravewood_treant` | Gravewood Treant | aggressive | night | 1.5/4.6 | 12/3 | dogfight | 1 | 0.60 wide, -1..0.75 | - | Undead-forest treant. |
| `guard_accord` | Accord Guard | guard role (no fixed disposition) | any | 1.2/4.6 | 14/3 | dogfight | 1 | 0.60 wide, 0..1.7 | - | Faction defender; kill target for enemy-faction PvP quests (three L40 quests per faction today). |
| `guard_throng` | Throng Guard | guard role (no fixed disposition) | any | 1.2/4.6 | 14/3 | dogfight | 1 | 0.60 wide, 0..1.7 | - | Faction defender; kill target for enemy-faction PvP quests (three L40 quests per faction today). |
| `gull` | Gull | critter | day | 1.5/3.4 fly | 8/- | - | 10 | 0.40 wide, 0..0.4 | - | Beach scenery. |
| `hare` | Hare | critter | day | 1.5/3.4 | 8/- | - | 1 | 0.40 wide, -0.01..0.49 | - | Throng-side rabbit with a dusty texture. |
| `hyena` | Hyena | aggressive | any | 1.5/4.6 | 14/3 | dogfight | 1 | 1.00 wide, -0.01..0.95 | - | Savanna/mountain pack hunter. |
| `ibex` | Ibex | neutral | day | 1.5/4.6 | 14/3 | dogfight | 1 | 0.80 wide, -0.01..0.5 | - | Neutral dwarf-zone climber; tall selection box (1.8) over a low 0.5 collision box. |
| `ice_dragon` | Wyrmglass Ice Dragon | aggressive, boss | any | 5.2/6.5 | 48/6 | dogfight | 8 | 6.00 wide, 0..8 | - | Island apex encounter on The Wyrmglass Crown. |
| `ice_whelp` | Wyrmglass Ice Dragon Whelp | aggressive | any | 5.2/6.5 | 48/3 | dogfight | 2.66 | 2.00 wide, 0..2.66 | - | Boss add. |
| `jungle_ape` | Jungle Ape | aggressive | day | 1/4.6 | 12/3 | dogfight | 1.5 | 1.50 wide, -0.01..1.43 | - | Troop animal that climbs terrain other mobs cannot. |
| `jungle_boar` | Jungle Boar | neutral | day | 1/4.6 | 10/3 | dogfight | 1 | 0.90 wide, -0.01..0.86 | - | Troll-region boar: identical behaviour and drops, jungle texture. |
| `jungle_lynx` | Jungle Lynx | aggressive | day | 1.5/4.6 | 14/3 | dogfight | 1 | 1.00 wide, -0.01..0.95 | - | Day jungle cat that hunts in packs. |
| `jungle_spider` | Jungle Spider | aggressive | night | 1/4.6 | 12/3 | dogfight | 1.5 | 2.10 wide, -0.75..0 | - | Jungle spider; regional replacement in Glassroot, Thunderroot, Skyglass, Stormscale. Silkfang is the existing rare. |
| `jungle_wyvern` | Stormscale Jungle Wyvern | aggressive, boss | any | 5.2/6.5 | 48/6 | dogfight | 8 | 4.80 wide, 0..6.4 | - | Island apex encounter on Stormscale Summit. |
| `king_dwarf` | King of Dur Brannoc | aggressive (king role), elite | any | 1.2/4.6 | 18/3 | dogfight | 0.71875 | 0.60 wide, 0..1.7 | - | Faction king on the capital throne, attacked by enemy-faction players. |
| `king_elf` | King of Lethariel | aggressive (king role), elite | any | 1.2/4.6 | 18/3 | dogshoot (arrow_entity, 3s) | 0.71875 | 0.60 wide, 0..1.7 | - | Faction king on the capital throne, attacked by enemy-faction players. |
| `king_human` | King of Highcourt | aggressive (king role), elite | any | 1.2/4.6 | 18/3 | dogfight | 0.71875 | 0.60 wide, 0..1.7 | - | Faction king on the capital throne, attacked by enemy-faction players. |
| `king_orc` | King of Gor Drazhak | aggressive (king role), elite | any | 1.2/4.6 | 18/3 | dogfight | 0.71875 | 0.60 wide, 0..1.7 | - | Faction king on the capital throne, attacked by enemy-faction players. |
| `king_troll` | King of Kezamba | aggressive (king role), elite | any | 1.2/4.6 | 18/3 | dogshoot (rock_entity, 3s) | 0.71875 | 0.60 wide, 0..1.7 | - | Faction king on the capital throne, attacked by enemy-faction players. |
| `king_undead` | King of Nhal Veyr | aggressive (king role), elite | any | 1.2/4.6 | 18/3 | dogshoot (rock_entity, 3s) | 0.71875 | 0.60 wide, 0..1.7 | - | Faction king on the capital throne, attacked by enemy-faction players. |
| `kraken` | Kraken Guard | aggressive | any | 3/5 fly swim | 20/4 | dogfight | 6 | 1.60 wide, 0..1.8 | - | Ocean gatekeeper ('Kraken Guard'): punishes swimming the deep sea. 0 XP, no drops. |
| `land_guard` | Land Guard | guard role (no fixed disposition), elite | any | 1.5/4.6 | 14/3 | dogfight | 1 | 1.00 wide, -1.01..1.6 | - | Deepest elite melee. |
| `lava_flan` | Lava Flan | aggressive | any | 1/3.4 | 10/3 | dogfight | 1 | 1.00 wide, -0.5..1.2 | - | Deepest melee blob. |
| `mesa_golem` | Mesa Golem | aggressive, elite | any | 1/4.6 | 16/3 | dogshoot (rock_entity, 3s) | 1 | 0.60 wide, -1..0.7 | - | Throng-region golem. |
| `mirefolk` | Mirefolk | aggressive | any | 1/4.6 | 12/3 | dogfight | 0.85 | 0.51 wide, 0..1.445 | - | Small (0.85) swamp humanoids that rush together. |
| `mountain_ram` | Mountain Ram | neutral | day | 1.5/4.6 | 10/- | dogfight | 1 | 0.90 wide, -0.01..1.29 | - | Neutral mountain grazer, heavy leather source. |
| `oerkki` | Oerkki | aggressive | any | 1.5/4.6 | 12/3 | dogfight | 1 | 0.70 wide, -1..0.85 | - | Deep cave blinker; drops quartz and silver lump. |
| `pale_spider` | Bonelurker Spider | aggressive | night | 1/4.6 | 12/3 | dogfight | 1.5 | 2.10 wide, -0.75..0 | - | Display name is 'Bonelurker Spider' (entity pale_spider). Undead-region spider. |
| `panther` | Panther | aggressive | night | 1.5/4.6 | 12/3 | dogfight | 1 | 1.00 wide, -0.01..0.95 | - | Solitary night pouncer. |
| `parrot` | Parrot | critter | day | 1.5/3.4 fly | 8/- | - | 3 | 0.50 wide, -0.01..0.89 | - | Jungle-edge scenery. |
| `plague_boar` | Plague Boar | neutral | day | 1/4.6 | 10/3 | dogfight | 1 | 0.90 wide, -0.01..0.86 | - | Undead-region boar: identical behaviour and drops, sickly texture. |
| `plaguehide_bear` | Plaguehide Bear | aggressive | day | 1/4.6 | 12/3 | dogfight | 3 | 1.40 wide, -0.01..1.39 | - | Undead-region bear. |
| `plains_runner` | Plains Runner | neutral | day | 1.5/4.6 | 12/3 | dogfight | 1 | 0.80 wide, -0.01..0.8 | - | Neutral Sunscar ground bird. |
| `poacher` | Poacher | aggressive | night | 1/4 | 16/3 | dogshoot (arrow_entity, 2.5s) | 1 | 0.60 wide, 0..1.7 | - | Free-roaming night archer of the Elf and Human forests; brown runtime skin, no race composer. |
| `rabbit` | Rabbit | critter | day | 1.5/3.4 | 8/- | - | 1 | 0.40 wide, -0.01..0.49 | - | Scenery and a raw-meat source on Accord land. |
| `reed_angelfish` | Reed Angelfish | critter | any | 1.1/1.5 fly swim | 5/- | - | 10 | 0.30 wide, -0.15..0.15 | - | Freshwater lake life; one Raw Fish per kill, no XP, no quality loot. |
| `reef_lurker` | Reef Lurker | neutral, elite | any | 1.5/3.4 | 8/3 | dogfight | 1 | 0.80 wide, -0.01..0.4 | - | Elite crab of the level 45-60 coasts; triple drops. |
| `rift_spawn` | Rift Spawn | aggressive | night | 1.5/4.6 | 14/3 | explode | 2 | 0.60 wide, -0.01..1.69 | - | Suicide bomber: kill it fast or step out of reach. |
| `royal_guard_dwarf` | King of Dur Brannoc Royal Guard | guard role (no fixed disposition), elite | any | 1.2/4.6 | 14/3 | dogfight | 1 | 0.60 wide, 0..1.7 | - | Throne-room guard. |
| `royal_guard_elf` | King of Lethariel Royal Guard | guard role (no fixed disposition), elite | any | 1.2/4.6 | 14/3 | dogfight | 1 | 0.60 wide, 0..1.7 | - | Throne-room guard. |
| `royal_guard_human` | King of Highcourt Royal Guard | guard role (no fixed disposition), elite | any | 1.2/4.6 | 14/3 | dogfight | 1 | 0.60 wide, 0..1.7 | - | Throne-room guard. |
| `royal_guard_orc` | King of Gor Drazhak Royal Guard | guard role (no fixed disposition), elite | any | 1.2/4.6 | 14/3 | dogfight | 1 | 0.60 wide, 0..1.7 | - | Throne-room guard. |
| `royal_guard_troll` | King of Kezamba Royal Guard | guard role (no fixed disposition), elite | any | 1.2/4.6 | 14/3 | dogfight | 1 | 0.60 wide, 0..1.7 | - | Throne-room guard. |
| `royal_guard_undead` | King of Nhal Veyr Royal Guard | guard role (no fixed disposition), elite | any | 1.2/4.6 | 14/3 | dogfight | 1 | 0.60 wide, 0..1.7 | - | Throne-room guard. |
| `scorpion` | Scorpion | aggressive | scorpion=night, sunscar_day=day, zone:kragmar_sunscar_flats=any | 1.5/4.6 | 10/3 | dogfight | 1 | 0.80 wide, -0.01..0.5 | - | Orc-zone poison melee; night elsewhere, day and night in Sunscar. |
| `serpent` | Serpent | aggressive | day | 1.5/4.6 | 10/3 | dogfight | 0.3 | 1.00 wide, -0.01..0.95 | - | Day jungle snake with poison bite, notices late (view 10). Emerald Coil is the existing rare. |
| `shore_crab` | Shore Crab | neutral | any | 1.5/3.4 | 8/3 | dogfight | 1 | 0.80 wide, -0.01..0.4 | - | Neutral beach animal on every coast below level 45. |
| `skeleton_archer` | Skeleton Archer | aggressive | night | 1/4 | 16/3 | dogshoot (arrow_entity, 2.5s) | 1 | 0.60 wide, -0.01..1.98 | - | The ranged undead: forces players to close in or break line of sight. View 16. |
| `skeleton_raider` | Skeleton Raider | aggressive | night | 1/4 | 16/3 | dogshoot (arrow_entity, 2.5s) | 1 | 0.60 wide, -0.01..1.98 | - | War-front skeleton archer with an extra Heavy Cloth drop; regional archer replacement in war zones. Captain Bonerattle is the existing rare. |
| `snow_leopard` | Snow Leopard | aggressive | night | 1.5/4.6 | 12/3 | dogfight | 1 | 1.00 wide, -0.01..0.95 | - | Mountain night pouncer. |
| `song_bird` | Song Bird | critter | day | 1.5/3.4 fly | 8/- | - | 8 | 0.32 wide, 0..0.32 | - | Silverleaf scenery bird. |
| `speargrass_tiger` | Speargrass Tiger | aggressive | day | 2/4.6 | 14/3 | dogfight | 1 | 1.00 wide, -0.01..0.95 | - | Day savanna apex pouncer. |
| `spiderling` | Spiderling | aggressive | any | 1/4.6 | 10/2 | dogfight | 0.75 | 1.05 wide, -0.375..0 | - | Small cave spider (visual 0.75). |
| `stag` | Stag | neutral | day | 1.5/4.6 | 12/- | dogfight | 8 | 1.00 wide, -0.01..1.8 | - | Large neutral grazer (visual 8, box 1.8 high) - leather and double meat. |
| `stone_golem` | Stone Golem | aggressive, elite | any | 1/4.6 | 16/3 | dogshoot (rock_entity, 3s) | 1 | 0.60 wide, -1..0.7 | - | A rare elite rock thrower on mountain slopes; a natural area leader. |
| `stone_mite` | Stone Mite | aggressive | any | 1.5/4.6 | 10/2 | dogfight | 4 | 1.06 wide, -0.01..0.59 | - | Deep hostile crawler; drops Stone Core 1/8. |
| `storm_whelp` | Stormscale Jungle Wyvern Whelp | aggressive | any | 5.2/6.5 | 48/3 | dogfight | 2.66 | 1.60 wide, 0..2.13 | - | Boss add. |
| `sun_dried_husk` | Sun-Dried Husk | aggressive | night | 1/4.6 | 14/3 | dogfight | 1 | 0.60 wide, -0.01..1.89 | - | Desert zombie of the Orc lands: same fight as a zombie but stays around after sunrise. |
| `tapir` | Tapir | neutral | day | 1.5/4.6 | 12/3 | dogfight | 1 | 1.00 wide, -0.01..0.95 | - | Neutral troll-zone grazer, double meat. |
| `viper` | Viper | aggressive | kapok_day=day, viper=night, zone:kragmar_kapok_cradle=any | 1.5/4.6 | 10/3 | dogfight | 0.6 | 0.60 wide, -0.01..0.8 | - | Troll-zone poison melee; night elsewhere, day and night in Kapok Cradle. |
| `vulture` | Vulture | aggressive | day | 2/4.6 fly | 16/3 | dogfight | 1 | 0.60 wide, -0.01..0.5 | - | Badlands bird of prey; Dustwing is the existing rare. |
| `war_construct` | War Construct | aggressive, elite | any | 1.5/4.6 | 14/3 | dogfight | 3 | 1.40 wide, -0.01..2.69 | - | Huge elite machine (visual 3, box 2.7 high) of the two central fronts; drops a Stone Core and 2-4 iron bars every kill. |
| `wild_turkey` | Wild Turkey | critter | day | 1.5/3.4 | 9/3 | dogfight | 10 | 0.60 wide, -0.01..0.6 | - | Dawnmere/Goldmead meadow critter. |
| `wisp` | Wisp | aggressive | night | 2.5/4.6 fly | 14/2 | dogfight | 1.25 | 0.40 wide, 0.2..1 | - | Night spirit that closes distance by blinking; drops nothing today. |
| `wolf` | Wolf | aggressive | any | 1.5/4.6 | 14/3 | dogfight | 1 | 0.60 wide, -0.01..0.84 | - | Packs: one pull becomes three; a wounded wolf runs and comes back with friends. |
| `zebra` | Zebra | neutral | day | 1.5/4.6 | 14/- | dogfight | 1 | 1.00 wide, -0.01..1.4 | - | Neutral savanna grazer (Redtusk, Speargrass). |
| `zombie` | Zombie | aggressive | blight=any, settled=night, war=night | 1/4.6 | 14/3 | dogfight | 1 | 0.60 wide, -0.01..1.89 | burns | Slow-feeling classic night brawler (run 4.6 like every melee hostile); the only family that burns in the sun, so daylight is a mechanic players can learn. |

## 6. Per-family details and design notes

Each entry: where it lives today, gates, movement and senses, behaviour,
drops, current kill quests, and design notes (what makes it distinct,
natural sub-types, technical constraints). Drop chance `1/N` is one in N.

### Boar

Model: grug_mobs_boar.b3d (2 slots: body + blank saddle).

**`grug_mobs:boar`** — Boar (neutral; mods/ENTITIES/grug_mobs/boar.lua:95)  
- Where today: day: Hearthpine Vale, Copperfell Foothills, Dawnmere Fields, Goldmead Vale, Whitebridge Shire, Silverleaf Glades, Starbough Vale, Sunscar Flats, Redtusk Savanna.
- Movement and senses: walk/run 1/4.6, view 10, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: charges: in combat at 4-10 m with line of sight a horizontal rush (stalker impulse speed 8, up 1, cooldown 8 s).
- Tiers: default tier normal; named rares on this entity: Grimtusk (elandor_goldmead_vale), Ashmaw (kragmar_redtusk_savanna).
- Drops: raw meat 1/1 x1-2, light leather 1/2, boar tusk 1/3.
- Kill quests today: r14_dwarf_01_tusks_at_the_timberline x3 L1 (r14_dwarf_elder); r14_elf_01_roots_laid_bare x3 L1 (r14_elf_elder); r14_human_01_boars_beyond_the_fence x3 L1 (r14_human_elder); r14_orc_01_tusks_at_the_water_skins x3 L1 (r14_orc_elder).
- Design notes: The starter target: never starts a fight, only fights back; the charge makes the last metres sudden. **Sub-types:** Shipped sub-types (Round 28 catalogue, names per frame §5): Small Boar (neutral, L1-3) and Aggressive Boar (L5-7) in the starts; Rooting Boar and Ridgeback Tusker (L11-20); Furrow Boar and Razorback (L21-30); plague and jungle forms by zone. Grimtusk is the existing rare on this entity. **Constraints:** Neutral disposition forces group_attack off: hitting one boar never pulls its neighbours. One boar registration per zone (spawn_policy BOAR_VARIANT_BY_ZONE). Small, low box (0.86) with a padded rotated selection box.
- Look: Base texture grug_mobs_boar.png^[multiply:#9a7a5a; sister tints plague (grug_mobs_boar_plague.png) and jungle (grug_mobs_boar_jungle.png) exist as own registrations.

**`grug_mobs:jungle_boar`** — Jungle Boar (neutral; mods/ENTITIES/grug_mobs/boar_variants.lua:114)  
- Where today: day: Kapok Cradle, Raincall Basin.
- Movement and senses: walk/run 1/4.6, view 10, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: charges: in combat at 4-10 m with line of sight a horizontal rush (stalker impulse speed 8, up 1, cooldown 8 s).
- Tiers: default tier normal.
- Drops: raw meat 1/1 x1-2, light leather 1/2, boar tusk 1/3.
- Kill quests today: r14_troll_01_boars_in_the_yam_beds x3 L1 (r14_troll_elder).
- Design notes: Troll-region boar: identical behaviour and drops, jungle texture. **Sub-types:** Same ladder with the jungle tint (Small Jungle Boar ...). **Constraints:** Neutral disposition forces group_attack off: hitting one boar never pulls its neighbours. One boar registration per zone (spawn_policy BOAR_VARIANT_BY_ZONE). Small, low box (0.86) with a padded rotated selection box.
- Look: grug_mobs_boar_jungle.png (baked texture).

**`grug_mobs:plague_boar`** — Plague Boar (neutral; mods/ENTITIES/grug_mobs/boar_variants.lua:80)  
- Where today: day: Stillgrave Hollow, Mournfen.
- Movement and senses: walk/run 1/4.6, view 10, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: charges: in combat at 4-10 m with line of sight a horizontal rush (stalker impulse speed 8, up 1, cooldown 8 s).
- Tiers: default tier normal.
- Drops: raw meat 1/1 x1-2, light leather 1/2, boar tusk 1/3.
- Kill quests today: r14_undead_01_boars_in_the_dead_furrows x3 L1 (r14_undead_elder); r15_undead_local_02 x5 L10 (r15_undead_local, zone kragmar_mournfen).
- Design notes: Undead-region boar: identical behaviour and drops, sickly texture. **Sub-types:** Same ladder as the base boar with the plague tint (Small Plague Boar, Rabid Plague Boar). The Ashmaw rare reuses this texture on a base-boar entity. **Constraints:** Neutral disposition forces group_attack off: hitting one boar never pulls its neighbours. One boar registration per zone (spawn_policy BOAR_VARIANT_BY_ZONE). Small, low box (0.86) with a padded rotated selection box.
- Look: grug_mobs_boar_plague.png (baked texture, not a runtime modifier).

### Zombie / Husk

Model: grug_mobs_zombie.b3d (2 slots: armour overlay + skin).

**`grug_mobs:sun_dried_husk`** — Sun-Dried Husk (aggressive; mods/ENTITIES/grug_mobs/zero_asset_variants.lua:165)  
- Where today: night: Sunscar Flats, Redtusk Savanna, The Shattered Line.
- Gates: natural min level 3 (no surface spawn where the level field is lower); Sunscar Flats: only where the level field >= 4.
- Movement and senses: walk/run 1/4.6, view 14, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: does NOT burn in the sun (light_damage 0) - a night spawn that survives into the day.
- Tiers: default tier normal.
- Drops: zombie flesh 1/1, linen scrap 1/2, iron bar 1/10.
- Kill quests today: r14_orc_04_the_thirsting_dead x3 L5 (r14_orc_elder).
- Design notes: Desert zombie of the Orc lands: same fight as a zombie but stays around after sunrise. **Sub-types:** Dusty/Brittle Husk (low), Sand-Choked Husk (beach/dry wash), Husk Brute (elite). **Constraints:** Night clock; regional zombie replacement in Sunscar, Redtusk and Shattered Line (spawn_policy ZONE_LOOKALIKE_SELECTION). Min level 3; in Sunscar only where the level field is >= 4. No night truce perk (unlike the zombie).
- Look: grug_mobs_zombie.png^[multiply:#c99b55 (runtime modifier).

**`grug_mobs:zombie`** — Zombie (aggressive; mods/ENTITIES/grug_mobs/zombie.lua:4)  
- Where today: night: Hearthpine Vale, Copperfell Foothills, Dawnmere Fields, Goldmead Vale, Whitebridge Shire, Ashenward March, Silverleaf Glades, Starbough Vale, Stillgrave Hollow, Mournfen, Bannerbreak Mesa, Kapok Cradle, Raincall Basin, The Wyrmglass Crown, Gravesalt Escarpment, The Broken Causeway, The Skyglass Canopy, Stormscale Summit; underground y -40 and below.
- Gates: natural min level 3 (no surface spawn where the level field is lower).
- Movement and senses: walk/run 1/4.6, view 14, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: undead night truce: players with the Undead race perk zombie_night_truce are ignored at night unless they hit this zombie; burns in daylight: light_damage 2 per step at light 14-15 (Ruling 6 changes this to 5 %/s of hp_max); blight row: on grug_nodes:blight_dirt it spawns around the clock and its on_spawn sets light_damage 0 (blight zombies never burn); damage-sustained pursuit like every normal/elite hostile.
- Tiers: default tier normal.
- Drops: zombie flesh 1/1, linen scrap 1/2, iron bar 1/10.
- Kill quests today: r14_dwarf_04_lanterns_after_sundown x3 L4 (r14_dwarf_elder); r14_elf_04_footfalls_without_breath x3 L4 (r14_elf_elder); r14_human_04_shapes_by_lanternlight x3 L4 (r14_human_elder); r14_troll_04_dead_in_the_rootways x3 L4 (r14_troll_elder); r14_undead_04_the_uncalled_dead x3 L4 (r14_undead_elder).
- Design notes: Slow-feeling classic night brawler (run 4.6 like every melee hostile); the only family that burns in the sun, so daylight is a mechanic players can learn. **Sub-types:** Shipped sub-types (Round 28 catalogue, names per frame §5): Braindead, Sluggish and Monstrous Drowned Zombie in the starts (the Drowned one walks the beaches); Cairn Zombie and Pauper Shambler (L11-20); Debtbound Zombie and Tithe Revenant (L20-30); Marching Zombie and Trench Shambler (L31-40); Saltbound Zombie and Last Watchman (L51-60). Names describe character, not a speed change. **Constraints:** Night-only on the surface outside blight dirt; burns on the surface at day, so day kill quests need caves or blight ground. Natural min level 3. Underground row from y -40 down with the depth level. Undead players are not attacked at night (quest texts for undead should note it).
- Look: Skin grug_mobs_zombie.png in slot 2; the Sun-Dried Husk is the same mesh with ^[multiply:#c99b55.

### Rabbit / Hare (critter)

Model: grug_mobs_rabbit.b3d.

**`grug_mobs:hare`** — Hare (critter; mods/ENTITIES/grug_mobs/rabbit.lua:121)  
- Where today: day: Stillgrave Hollow, Mournfen, Sunscar Flats, Redtusk Savanna, Kapok Cradle, Raincall Basin.
- Gates: Throng territory only.
- Movement and senses: walk/run 1.5/3.4, view 8, reach -, attack -, chase end: - (never fights).
- Behaviour: flees when hit.
- Tiers: default tier critter.
- Drops: raw meat 1/1.
- Design notes: Throng-side rabbit with a dusty texture. **Sub-types:** None needed (critter). **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway. Spawn check: only on Throng territory.
- Look: grug_mobs_hare_dust.png.

**`grug_mobs:rabbit`** — Rabbit (critter; mods/ENTITIES/grug_mobs/rabbit.lua:87)  
- Where today: day: Hearthpine Vale, Copperfell Foothills, Dawnmere Fields, Goldmead Vale, Whitebridge Shire, Silverleaf Glades, Starbough Vale.
- Gates: Accord territory only (grug_zones.faction_at).
- Movement and senses: walk/run 1.5/3.4, view 8, reach -, attack -, chase end: - (never fights).
- Behaviour: flees when hit.
- Tiers: default tier critter.
- Drops: raw meat 1/1.
- Design notes: Scenery and a raw-meat source on Accord land. **Sub-types:** None needed (critter). **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway. Spawn check: only on Accord territory (grug_zones.faction_at == accord), so never in contested zones.
- Look: grug_mobs_rabbit.png.

### Wolf

Model: grug_mobs_wolf.b3d.

**`grug_mobs:blightfang_wolf`** — Blightfang Wolf (aggressive; mods/ENTITIES/grug_mobs/wolf.lua:99)  
- Where today: day+night: Ossuary Reach, Blackwind Rise, Gravesalt Escarpment; in the palette but no host surface in Whitebridge Shire, Ashenward March, Moonfall Wood, Glassroot Wilds.
- Gates: natural min level 10 (no surface spawn where the level field is lower).
- Movement and senses: walk/run 1.5/4.6, view 14, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: pack hunter: below 20 % HP it flees for 4 s and pulls every mob of the same entity name in view range that is not fighting (cooldown 15 s); group_attack.
- Tiers: default tier normal.
- Drops: raw meat 1/1, leather 1/2, fang 1/3.
- Kill quests today: r20_anchor_020_02 x4 L21 (r20_anchor_020_host, zone kragmar_ossuary_reach); r20_anchor_038_03 x4 L23 (r20_anchor_038_host, zone kragmar_ossuary_reach).
- Design notes: Undead-forest wolf, same pack fight. **Sub-types:** Same ladder with the blightfang texture. **Constraints:** Min level 10, any clock, host only grug_nodes:dirt_with_bone_litter.
- Look: grug_mobs_wolf_blightfang.png.

**`grug_mobs:wolf`** — Wolf (aggressive; mods/ENTITIES/grug_mobs/wolf.lua:72)  
- Where today: day+night: Whitebridge Shire, Ashenward March, Moonfall Wood, Glassroot Wilds; in the palette but no host surface in Ossuary Reach, Blackwind Rise, Gravesalt Escarpment.
- Gates: natural min level 10 (no surface spawn where the level field is lower).
- Movement and senses: walk/run 1.5/4.6, view 14, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: pack hunter: below 20 % HP it flees for 4 s and pulls every mob of the same entity name in view range that is not fighting (cooldown 15 s); group_attack: a hit alerts same-name wolves in view range.
- Tiers: default tier normal; named rares on this entity: Old Whitefang (elandor_ashenward_march).
- Drops: raw meat 1/1, leather 1/2, fang 1/3.
- Kill quests today: r20_anchor_035_02 x4 L21 (r20_anchor_035_host, zone elandor_moonfall_wood).
- Design notes: Packs: one pull becomes three; a wounded wolf runs and comes back with friends. **Sub-types:** Wolf Pup / Young Wolf (neutral, size 0.75, below L10 would need a lower min level), Grey Wolf (normal), Dire Wolf / Pack Leader (size 1.2-1.3, elite area leader). Old Whitefang is the existing rare. **Constraints:** Natural min level 10. Any clock (day and night). Pack call, group alert and density weight are keyed by entity name: a sub-type does not answer the base wolf's call.
- Look: grug_mobs_wolf.png; Blightfang is a baked texture variant.

### Bear

Model: grug_mobs_bear.b3d.

**`grug_mobs:bear`** — Bear (aggressive; mods/ENTITIES/grug_mobs/bear.lua:98)  
- Where today: day: Whitebridge Shire, Ashenward March, Moonfall Wood, Glassroot Wilds; in the palette but no host surface in Ossuary Reach, Blackwind Rise, Gravesalt Escarpment.
- Movement and senses: walk/run 1/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: _grug_leash_range 20 ('territorial'), but a free-roaming bear uses damage-sustained pursuit, so the 20 m drag leash only applies to bound bears (the rare uses the 300 m rare floor); on_spawn: 1 in 10 spawns becomes an elite named 'Elder Bear' / 'Elder Plaguehide Bear' (tier elite: x3 HP, x1.8 dmg, gold tint, telegraph); group_attack.
- Tiers: default tier normal; elite appears (see behaviour).
- Drops: raw meat 1/1 x2, heavy leather 1/2, bear claw 1/4.
- Design notes: Big (visual 3, box 1.4 high), notices late (view 12), hits like every melee mob but has the elite roll built in. **Sub-types:** Bear Cub (neutral, size 0.75), Brown Bear (normal), Elder Bear already exists as the 1-in-10 elite roll. **Constraints:** Day clock. The Elder roll is random per spawn, so it cannot be a fixed quest climax as is.
- Look: grug_mobs_bear.png; plaguehide is a baked variant.

**`grug_mobs:plaguehide_bear`** — Plaguehide Bear (aggressive; mods/ENTITIES/grug_mobs/bear.lua:141)  
- Where today: day: Ossuary Reach, Blackwind Rise, Gravesalt Escarpment; in the palette but no host surface in Whitebridge Shire, Ashenward March, Moonfall Wood, Glassroot Wilds.
- Movement and senses: walk/run 1/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: _grug_leash_range 20 (inactive for free roamers, see bear); on_spawn: 1 in 10 spawns becomes an elite named 'Elder Bear' / 'Elder Plaguehide Bear' (tier elite: x3 HP, x1.8 dmg, gold tint, telegraph); group_attack.
- Tiers: default tier normal; elite appears (see behaviour); named rares on this entity: Marrowclaw (kragmar_blackwind_rise).
- Drops: raw meat 1/1 x2, heavy leather 1/2, bear claw 1/4.
- Kill quests today: r20_anchor_040_02 x3 L31 (r20_anchor_040_host, zone kragmar_blackwind_rise).
- Design notes: Undead-region bear. **Sub-types:** As bear. Marrowclaw is the existing rare. **Constraints:** Day clock.
- Look: grug_mobs_bear_plaguehide.png.

### Stag

Model: grug_mobs_stag.b3d.

**`grug_mobs:gaunt_stag`** — Gaunt Stag (neutral; mods/ENTITIES/grug_mobs/stag.lua:114)  
- Where today: day: Ossuary Reach, Blackwind Rise, Gravesalt Escarpment; in the palette but no host surface in Whitebridge Shire, Ashenward March, Moonfall Wood, Glassroot Wilds.
- Movement and senses: walk/run 1.5/4.6, view 12, reach -, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: passive prey (grazes): never attacks on sight, fights back in melee when hit (dogfight), no group alert.
- Tiers: default tier normal.
- Drops: raw meat 1/1 x2, leather 1/2.
- Design notes: Undead-forest grazer. **Sub-types:** As stag. **Constraints:** Day clock, bone-litter host only.
- Look: grug_mobs_stag_gaunt.png.

**`grug_mobs:stag`** — Stag (neutral; mods/ENTITIES/grug_mobs/stag.lua:84)  
- Where today: day: Whitebridge Shire, Ashenward March, Lorindor, Moonfall Wood, Glassroot Wilds; in the palette but no host surface in Ossuary Reach, Blackwind Rise, Gravesalt Escarpment.
- Movement and senses: walk/run 1.5/4.6, view 12, reach -, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: passive prey (grazes): never attacks on sight, fights back in melee when hit (dogfight), no group alert.
- Tiers: default tier normal.
- Drops: raw meat 1/1 x2, leather 1/2.
- Design notes: Large neutral grazer (visual 8, box 1.8 high) - leather and double meat. **Sub-types:** Doe / Young Stag (neutral, 0.8), Great Stag / Antlered Stag (1.2-1.3, elite). **Constraints:** Day clock. Lorindor lists only grug_mobs:stag (exact palette).
- Look: grug_mobs_stag.png; gaunt is a baked variant.

### Spider

Model: grug_mobs_spider.b3d.

**`grug_mobs:giant_spider`** — Giant Spider (aggressive; mods/ENTITIES/grug_mobs/spider.lua:79)  
- Where today: night: Whitebridge Shire, Ashenward March, Moonfall Wood; underground y -40 and below; in the palette but no host surface in Ossuary Reach, Blackwind Rise, Gravesalt Escarpment.
- Movement and senses: walk/run 1/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: webs: every landed melee hit slows the player to 60 % speed for 3 s; group_attack.
- Tiers: default tier normal.
- Drops: spider silk 1/1 x1-2, venom gland 1/6.
- Design notes: Wide (box 2.1 x 2.1, origin at the top of the box) night hunter whose bite makes you slow - running away gets hard. **Sub-types:** Spiderling-sized young (0.6-0.75, aggressive, low level), Broodmother (1.3, elite). A Spiderling registration already exists (underground). **Constraints:** Night clock on the surface; underground row from y -40 down at any time. Box extends 0.75 below the origin.
- Look: grug_mobs_spider.png; pale and jungle are baked variants.

**`grug_mobs:jungle_spider`** — Jungle Spider (aggressive; mods/ENTITIES/grug_mobs/spider.lua:158)  
- Where today: night: Glassroot Wilds, Thunderroot Wilds, The Skyglass Canopy, Stormscale Summit.
- Movement and senses: walk/run 1/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: webs: every landed melee hit slows the player to 60 % speed for 3 s; group_attack.
- Tiers: default tier normal; named rares on this entity: Silkfang (front_skyglass_canopy).
- Drops: spider silk 1/1 x1-2, venom gland 1/6.
- Design notes: Jungle spider; regional replacement in Glassroot, Thunderroot, Skyglass, Stormscale. Silkfang is the existing rare. **Sub-types:** As giant spider. **Constraints:** Night clock.
- Look: grug_mobs_spider_jungle.png.

**`grug_mobs:pale_spider`** — Bonelurker Spider (aggressive; mods/ENTITIES/grug_mobs/spider.lua:117)  
- Where today: night: Ossuary Reach, Blackwind Rise, Gravesalt Escarpment; in the palette but no host surface in Whitebridge Shire, Ashenward March, Moonfall Wood.
- Movement and senses: walk/run 1/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: webs: every landed melee hit slows the player to 60 % speed for 3 s; group_attack.
- Tiers: default tier normal.
- Drops: spider silk 1/1 x1-2, venom gland 1/6.
- Design notes: Display name is 'Bonelurker Spider' (entity pale_spider). Undead-region spider. **Sub-types:** As giant spider. **Constraints:** Night clock.
- Look: grug_mobs_spider_pale.png.

**`grug_mobs:spiderling`** — Spiderling (aggressive; mods/ENTITIES/grug_mobs/zero_asset_variants.lua:249)  
- Where today: underground y -40 to -100.
- Movement and senses: walk/run 1/4.6, view 10, reach 2, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: webs (weaker): every landed hit slows the player to 80 % for 2 s; group_attack; reach 2.
- Tiers: default tier normal.
- Drops: spider silk 1/2.
- Design notes: Small cave spider (visual 0.75). **Sub-types:** Could serve as the 'young spider' template on the surface (needs its own surface rows). **Constraints:** Underground domain only, y -40 to -100.
- Look: grug_mobs_spider.png^[multiply:#786b63.

### Skeleton (archer, raider, stray, witch)

Model: grug_mobs_skeleton.b3d (3 slots: blank, body, held item).

**`grug_mobs:bog_witch`** — Bog Witch (aggressive; mods/ENTITIES/grug_mobs/bog_witch.lua:69)  
- Where today: night: Thunderroot Wilds, Gravesalt Escarpment, The Broken Causeway, Stormscale Summit.
- Movement and senses: walk/run 1.5/4, view 16, reach 3, attack dogshoot (hex_bottle, 2.5s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: dogshoot with a homing hex bottle (speed 8, every 2.5 s): hit damage plus 50 % chance poison (2 ticks x 1 dmg every 2 s) or 50 % chance 30 % slow for 4 s.
- Tiers: default tier normal.
- Drops: venom sac 1/3, linen scrap 1/2 x1-2.
- Design notes: Caster enemy: punishes standing still at range; the bottle homes in. **Sub-types:** Hedge Witch (low), Bog Witch, Coven Mother (elite, 1.2). **Constraints:** Night clock; palette bog_witch (Thunderroot and three front zones).
- Look: grug_mobs_skeleton.png^[colorize:#5f8b4c:110, bottle in the held-item slot.

**`grug_mobs:frost_stray`** — Frost Stray (aggressive; mods/ENTITIES/grug_mobs/zero_asset_variants.lua:113)  
- Where today: night: Stormvault Heights, The Wyrmglass Crown.
- Movement and senses: walk/run 1/4, view 16, reach 3, attack dogshoot (arrow_entity, 2.5s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took), no soft de-aggro.
- Behaviour: dogshoot: shoots arrows (grug_mobs:arrow_entity, speed 16) every 2.5 s at range and switches to melee up close; ranged mobs ignore the 25 m soft de-aggro; group_attack.
- Tiers: default tier normal.
- Drops: bone 1/1, linen scrap 1/2, arrow 1/3.
- Kill quests today: r20_anchor_027_02 x4 L31 (r20_anchor_027_host, zone elandor_stormvault_heights).
- Design notes: Ice-blue skeleton archer of the dwarf mountains and Wyrmglass. **Sub-types:** As skeleton archer. **Constraints:** Night clock; hosts gravel and snow.
- Look: grug_mobs_skeleton.png^[multiply:#a8d8ef.

**`grug_mobs:skeleton_archer`** — Skeleton Archer (aggressive; mods/ENTITIES/grug_mobs/skeleton_archer.lua:135)  
- Where today: night: Ossuary Reach, Blackwind Rise; in the palette but no host surface in Whitebridge Shire, Moonfall Wood, Glassroot Wilds.
- Gates: zone has an explicit war or mountain palette, otherwise only on bone litter / blight dirt.
- Movement and senses: walk/run 1/4, view 16, reach 3, attack dogshoot (arrow_entity, 2.5s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took), no soft de-aggro.
- Behaviour: dogshoot: shoots arrows (grug_mobs:arrow_entity, speed 16) every 2.5 s at range and switches to melee up close; ranged mobs ignore the 25 m soft de-aggro; group_attack.
- Tiers: default tier normal.
- Drops: bone 1/1, linen scrap 1/2, arrow 1/3.
- Design notes: The ranged undead: forces players to close in or break line of sight. View 16. **Sub-types:** Skeleton Recruit (low), Bone Marksman (higher), Skeleton Captain (elite). Tinted siblings exist (raider, frost stray). **Constraints:** Night clock. Row check: explicit war or mountain palette, otherwise only on bone litter or blight dirt. Run 4.0 (slower than melee 4.6). Does not burn in the sun.
- Look: grug_mobs_skeleton.png in slot 2; raider/frost/witch are texture or modifier variants.

**`grug_mobs:skeleton_raider`** — Skeleton Raider (aggressive; mods/ENTITIES/grug_mobs/skeleton_raider.lua:104)  
- Where today: night: Ashenward March, Bannerbreak Mesa, Gravesalt Escarpment, The Broken Causeway, The Shattered Line, The Skyglass Canopy, Stormscale Summit.
- Movement and senses: walk/run 1/4, view 16, reach 3, attack dogshoot (arrow_entity, 2.5s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took), no soft de-aggro.
- Behaviour: dogshoot: shoots arrows (grug_mobs:arrow_entity, speed 16) every 2.5 s at range and switches to melee up close; ranged mobs ignore the 25 m soft de-aggro; group_attack; summoned in pairs by the Undead king's bone_call.
- Tiers: default tier normal; named rares on this entity: Captain Bonerattle (front_broken_causeway), Captain Bonerattle (front_shattered_line).
- Drops: bone 1/1, linen scrap 1/2, arrow 1/3, heavy cloth 1/3.
- Kill quests today: r20_anchor_032_02 x4 L31 (r20_anchor_032_host, zone elandor_ashenward_march); r20_anchor_044_02 x4 L31 (r20_anchor_044_host, zone kragmar_bannerbreak_mesa).
- Design notes: War-front skeleton archer with an extra Heavy Cloth drop; regional archer replacement in war zones. Captain Bonerattle is the existing rare. **Sub-types:** As skeleton archer (War Recruit, Raider Sergeant ...). **Constraints:** Night clock, contested domain only (never on faction land).
- Look: grug_mobs_skeleton_raider.png.

### Bird of prey

Model: grug_mobs_eagle.b3d (18-slot atlas).

**`grug_mobs:crag_eagle`** — Crag Eagle (aggressive; mods/ENTITIES/grug_mobs/eagle.lua:116)  
- Where today: day: Frostbarrow Shelf, Stormvault Heights, Speargrass Reach, Bannerbreak Mesa, The Wyrmglass Crown, The Shattered Line; thin: The Shattered Line (only on incidental gravel (shores, river beds, exposed slopes)), Bannerbreak Mesa (only on incidental gravel (shores, river beds, exposed slopes)), Speargrass Reach (only on incidental gravel (shores, river beds, exposed slopes)).
- Movement and senses: walk/run 2/4.6 fly, view 16, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: flier (fly_in air): idle flight is nudged to 2-4 nodes above ground (flight.lua); dives in to melee (dogfight).
- Tiers: default tier normal.
- Drops: sharp feather 1/1 x1-2, feather 1/2 x1-2, raw meat 1/2.
- Kill quests today: r20_anchor_028_02 x3 L31 (r20_anchor_028_host, zone elandor_stormvault_heights).
- Design notes: Aggressive day flier with view 16: spots players early and attacks from above. **Sub-types:** Young Eagle (smaller, low), Great Crag Eagle (elite). **Constraints:** Flier: kill targets need open sky; melee players must wait for it to come down. Day clock. fall_damage 0 is a no-op in mobs_redo (0 is truthy).
- Look: grug_mobs_eagle.png atlas; vulture is a baked variant.

**`grug_mobs:vulture`** — Vulture (aggressive; mods/ENTITIES/grug_mobs/eagle.lua:148)  
- Where today: day: Speargrass Reach, Bannerbreak Mesa, The Shattered Line; in the palette but no host surface in Frostbarrow Shelf, Stormvault Heights, The Wyrmglass Crown.
- Movement and senses: walk/run 2/4.6 fly, view 16, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: flier (fly_in air): idle flight is nudged to 2-4 nodes above ground (flight.lua); dives in to melee.
- Tiers: default tier normal; named rares on this entity: Dustwing (kragmar_bannerbreak_mesa).
- Drops: sharp feather 1/1 x1-2, feather 1/2 x1-2, raw meat 1/2.
- Design notes: Badlands bird of prey; Dustwing is the existing rare. **Sub-types:** As eagle. **Constraints:** Flier, day clock, host mesa clay.
- Look: grug_mobs_vulture.png.

### Golem

Model: grug_mobs_stone_golem.b3d.

**`grug_mobs:mesa_golem`** — Mesa Golem (aggressive, elite; mods/ENTITIES/grug_mobs/golem.lua:240)  
- Where today: day+night: Speargrass Reach, Bannerbreak Mesa, The Shattered Line; underground y -40 and below.
- Gates: Throng race region only.
- Movement and senses: walk/run 1/4.6, view 16, reach 3, attack dogshoot (rock_entity, 3s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: always ELITE (def tier): x3 HP, x1.8 dmg, x4 XP, armor 80, scale 1.6, gold tint, 2 s telegraph + x3 cone hit; dogshoot rocks every 3 s.
- Tiers: default tier elite.
- Drops: stone core 1/1, iron lump 1/2, rough diamond 1/8.
- Design notes: Throng-region golem. **Sub-types:** As stone golem. **Constraints:** Throng race region only; sparse.
- Look: grug_mobs_mesa_golem.png.

**`grug_mobs:stone_golem`** — Stone Golem (aggressive, elite; mods/ENTITIES/grug_mobs/golem.lua:170)  
- Where today: day+night: Frostbarrow Shelf, Stormvault Heights, The Wyrmglass Crown; underground y -40 and below.
- Gates: Accord race region only (grug_zones.race_region_at).
- Movement and senses: walk/run 1/4.6, view 16, reach 3, attack dogshoot (rock_entity, 3s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: always ELITE (def tier): x3 HP, x1.8 dmg, x4 XP, armor 80, scale 1.6, gold tint, 2 s telegraph + x3 cone hit; dogshoot: throws rocks (grug_mobs:rock_entity, speed 12) every 3 s, melee up close; cannot jump.
- Tiers: default tier elite; named rares on this entity: Korgan's Bane (elandor_stormvault_heights).
- Drops: stone core 1/1, iron lump 1/2, rough diamond 1/8.
- Design notes: A rare elite rock thrower on mountain slopes; a natural area leader. **Sub-types:** Pebble Golem / Rubble Golem as a normal-tier small (size 0.8) sub-type would need tier normal; Korgan's Bane is the existing rare. **Constraints:** Very sparse rows (interval 30, chance 9000-12000, cap 1). Only on Accord race region (stone) - mesa golem on Throng. Box extends 1 node below origin. Any clock.
- Look: grug_mobs_stone_golem.png; mesa is a baked variant.

### Mountain Ram

Model: grug_mobs_ram.b3d (2 slots: fleece + body).

**`grug_mobs:mountain_ram`** — Mountain Ram (neutral; mods/ENTITIES/grug_mobs/ram.lua:70)  
- Where today: day: Frostbarrow Shelf, Stormvault Heights, Speargrass Reach, Bannerbreak Mesa, The Wyrmglass Crown, The Shattered Line; thin: The Shattered Line (only on incidental gravel (shores, river beds, exposed slopes)), Bannerbreak Mesa (only on incidental gravel (shores, river beds, exposed slopes)), Speargrass Reach (only on incidental gravel (shores, river beds, exposed slopes)).
- Movement and senses: walk/run 1.5/4.6, view 10, reach -, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: passive prey (grazes): never attacks on sight, fights back in melee when hit (dogfight), no group alert.
- Tiers: default tier normal.
- Drops: raw meat 1/1, heavy leather 1/4.
- Kill quests today: r20_anchor_061_02 x4 L21 (r20_anchor_061_host, zone elandor_frostbarrow_shelf).
- Design notes: Neutral mountain grazer, heavy leather source. **Sub-types:** Lamb / Young Ram (0.8), Old Ram (1.2, elite). **Constraints:** Day clock; gravel and snow.
- Look: grug_mobs_ram_fur.png + grug_mobs_ram.png (2 slots).

### Hyena

Model: grug_mobs_hyena.b3d (16-slot atlas).

**`grug_mobs:hyena`** — Hyena (aggressive; mods/ENTITIES/grug_mobs/hyena.lua:71)  
- Where today: day+night: Redtusk Savanna, Speargrass Reach, Bannerbreak Mesa, The Shattered Line; in the palette but no host surface in Frostbarrow Shelf, Stormvault Heights, The Wyrmglass Crown.
- Gates: natural min level 10 (no surface spawn where the level field is lower).
- Movement and senses: walk/run 1.5/4.6, view 14, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: pack hunter: below 20 % HP it flees for 4 s and pulls every mob of the same entity name in view range that is not fighting (cooldown 15 s); group_attack.
- Tiers: default tier normal.
- Drops: raw meat 1/1, leather 1/2, fang 1/3.
- Kill quests today: r14_orc_07_teeth_around_the_herd x6 L10 (r14_orc_steward, zone kragmar_redtusk_savanna); r15_orc_local_03 x4 L11 (r14_orc_scout, zone kragmar_redtusk_savanna); r20_anchor_065_02 x4 L21 (r20_anchor_065_host, zone kragmar_speargrass_reach).
- Design notes: Savanna/mountain pack hunter. **Sub-types:** Pup (neutral, lower min level), Spotted Hyena, Pack Matriarch (elite). **Constraints:** Min level 10. Any clock.
- Look: grug_mobs_hyena.png atlas.

### Zebra

Model: grug_mobs_zebra.b3d (12-slot atlas).

**`grug_mobs:zebra`** — Zebra (neutral; mods/ENTITIES/grug_mobs/zebra.lua:67)  
- Where today: day: Redtusk Savanna, Speargrass Reach.
- Movement and senses: walk/run 1.5/4.6, view 14, reach -, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: passive prey (grazes): never attacks on sight, fights back in melee when hit (dogfight), no group alert.
- Tiers: default tier normal.
- Drops: raw meat 1/1 x2, leather 1/2.
- Design notes: Neutral savanna grazer (Redtusk, Speargrass). **Sub-types:** Foal (0.75), Stallion (1.2). **Constraints:** Day clock, savanna grass only. Cannot jump (stepheight 2).
- Look: grug_mobs_zebra.png atlas.

### Big cat (lynx, panther, snow leopard)

Model: grug_mobs_panther.b3d (17-slot atlas).

**`grug_mobs:jungle_lynx`** — Jungle Lynx (aggressive; mods/ENTITIES/grug_mobs/jungle_lynx.lua:81)  
- Where today: day: Kapok Cradle, Raincall Basin, Whispering Reedlands, Totemwater Reach.
- Gates: natural min level 4 (no surface spawn where the level field is lower).
- Movement and senses: walk/run 1.5/4.6, view 14, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: pack hunter: below 20 % HP it flees for 4 s and pulls every mob of the same entity name in view range that is not fighting (cooldown 15 s); group_attack.
- Tiers: default tier normal.
- Drops: raw meat 1/1, leather 1/2, raptor claw 1/3.
- Kill quests today: r14_troll_08_cats_at_the_reed_line x6 L11 (r14_troll_scout, zone kragmar_raincall_basin); r20_anchor_046_02 x4 L21 (r20_anchor_046_host, zone kragmar_whispering_reedlands).
- Design notes: Day jungle cat that hunts in packs. **Sub-types:** Cub (0.75), Lynx, Lynx Matriarch. **Constraints:** Day clock, min level 4. Regional cat: replaced by the panther in four mixed jungle zones.
- Look: grug_mobs_jungle_lynx.png atlas on the panther mesh.

**`grug_mobs:panther`** — Panther (aggressive; mods/ENTITIES/grug_mobs/panther.lua:76)  
- Where today: night: Glassroot Wilds, Thunderroot Wilds, The Skyglass Canopy, Stormscale Summit.
- Movement and senses: walk/run 1.5/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: stalks: in combat at 4-8 m with line of sight it pounces (impulse speed 8, up 4, cooldown 6 s); silent (no footstep sound).
- Tiers: default tier normal.
- Drops: raw meat 1/1, leather 1/2, sleek pelt 1/4.
- Design notes: Solitary night pouncer. **Sub-types:** Young Panther, Shadow Panther (elite). **Constraints:** Night clock.
- Look: grug_mobs_panther.png atlas.

**`grug_mobs:snow_leopard`** — Snow Leopard (aggressive; mods/ENTITIES/grug_mobs/night_families.lua:117)  
- Where today: night: Frostbarrow Shelf, Stormvault Heights, The Wyrmglass Crown.
- Movement and senses: walk/run 1.5/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: stalks: in combat at 4-8 m with line of sight it pounces (impulse speed 8, up 4, cooldown 6 s); silent.
- Tiers: default tier normal.
- Drops: raw meat 1/1, leather 1/2, sleek pelt 1/4.
- Kill quests today: r20_anchor_026_02 x3 L21 (r20_anchor_026_host, zone elandor_frostbarrow_shelf); r20_anchor_061_03 x3 L23 (r20_anchor_061_host, zone elandor_frostbarrow_shelf).
- Design notes: Mountain night pouncer. **Sub-types:** As panther. **Constraints:** Night clock; gravel and snow.
- Look: grug_mobs_snow_leopard.png atlas on the panther mesh.

### Speargrass Tiger

Model: grug_mobs_speargrass_tiger.b3d.

**`grug_mobs:speargrass_tiger`** — Speargrass Tiger (aggressive; mods/ENTITIES/grug_mobs/speargrass_tiger.lua:36)  
- Where today: day: Speargrass Reach, The Shattered Line.
- Gates: only where the level field is 21-50.
- Movement and senses: walk/run 2/4.6, view 14, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: stalks: in combat at 4-8 m with line of sight it pounces (impulse speed 8, up 4, cooldown 6 s); walks 2.0 when idle, jump 6.
- Tiers: default tier normal.
- Drops: raw meat 1/1 x1-2, heavy leather 1/2, sleek pelt 1/4.
- Kill quests today: r20_anchor_022_02 x3 L21 (r20_anchor_022_host, zone kragmar_speargrass_reach); r20_anchor_042_02 x3 L21 (r20_anchor_042_host, zone kragmar_speargrass_reach).
- Design notes: Day savanna apex pouncer. **Sub-types:** Young Tiger, Speargrass Tiger, Old Stripe (elite). **Constraints:** Day clock; spawn check level 21-50 only.
- Look: grug_mobs_speargrass_tiger.png.

### Serpent

Model: grug_mobs_serpent.b3d (15-slot atlas).

**`grug_mobs:serpent`** — Serpent (aggressive; mods/ENTITIES/grug_mobs/serpent.lua:73)  
- Where today: day: Glassroot Wilds, Thunderroot Wilds, The Skyglass Canopy, Stormscale Summit.
- Movement and senses: walk/run 1.5/4.6, view 10, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: poisons: every landed hit starts an independent poison chain of 3 ticks x 1 damage every 2 s (stacks per bite; antivenom clears).
- Tiers: default tier normal; named rares on this entity: Emerald Coil (front_stormscale_summit).
- Drops: scaled hide 1/2, venom sac 1/3.
- Design notes: Day jungle snake with poison bite, notices late (view 10). Emerald Coil is the existing rare. **Sub-types:** Grass Snake (small, low), Serpent, Great Serpent (elite). **Constraints:** Day clock. Mesh rendered at 0.3 on a 1x1 box (box larger than the mesh).
- Look: grug_mobs_serpent.png atlas.

### Scorpion / Viper (poison family)

Model: grug_mobs_scorpion.b3d, grug_mobs_viper.b3d.

**`grug_mobs:scorpion`** — Scorpion (aggressive; mods/ENTITIES/grug_mobs/start_zone_families.lua:249)  
- Where today: day: Sunscar Flats; night: Sunscar Flats, Redtusk Savanna, Speargrass Reach, Bannerbreak Mesa, The Shattered Line.
- Gates: start_band(4) in the six start zones.
- Movement and senses: walk/run 1.5/4.6, view 10, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: poisons: every landed hit starts an independent poison chain of 3 ticks x 1 damage every 2 s (stacks per bite; antivenom clears).
- Tiers: default tier normal.
- Drops: scaled hide 1/2, venom sac 1/3.
- Kill quests today: r14_orc_05_shells_by_the_bedrolls x5 L5 (r14_orc_elder); r14_orc_08_scour_the_dry_wash x6 L11 (r14_orc_scout, zone kragmar_redtusk_savanna); r20_anchor_022_03 x4 L23 (r20_anchor_022_host, zone kragmar_speargrass_reach); r20_anchor_043_02 x4 L31 (r20_anchor_043_host, zone kragmar_bannerbreak_mesa); r20_anchor_065_03 x4 L23 (r20_anchor_065_host, zone kragmar_speargrass_reach).
- Design notes: Orc-zone poison melee; night elsewhere, day and night in Sunscar. **Sub-types:** Shipped sub-types (Round 28 catalogue, names per frame §5): Aggressive Scorpion (L5-7) and Monstrous Scorpion (L7-9) in Sunscar; Dust-Stinger Scorpion (L11-30); War-Stinger Scorpion (L31-50). **Constraints:** Clock: night by palette, 'any' in Sunscar Flats (zone key). start_band(4) in start zones.
- Look: grug_mobs_scorpion.png.

**`grug_mobs:viper`** — Viper (aggressive; mods/ENTITIES/grug_mobs/start_zone_families.lua:275)  
- Where today: day: Kapok Cradle; night: Kapok Cradle, Raincall Basin.
- Gates: start_band(4) in the six start zones.
- Movement and senses: walk/run 1.5/4.6, view 10, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: poisons: every landed hit starts an independent poison chain of 3 ticks x 1 damage every 2 s (stacks per bite; antivenom clears).
- Tiers: default tier normal.
- Drops: scaled hide 1/2, venom sac 1/3.
- Kill quests today: r14_troll_05_vipers_under_broad_leaves x5 L5 (r14_troll_elder); r14_troll_07_the_coiled_footpath x6 L10 (r14_troll_steward, zone kragmar_raincall_basin); r15_troll_local_03 x4 L11 (r14_troll_scout, zone kragmar_raincall_basin).
- Design notes: Troll-zone poison melee; night elsewhere, day and night in Kapok Cradle. **Sub-types:** Grass Viper (low), Viper, Pit Viper (elite). **Constraints:** Clock: night by palette, 'any' in Kapok Cradle. start_band(4).
- Look: grug_mobs_viper.png.

### Jungle Ape

Model: grug_mobs_jungle_ape.b3d (20-slot atlas).

**`grug_mobs:jungle_ape`** — Jungle Ape (aggressive; mods/ENTITIES/grug_mobs/jungle_ape.lua:83)  
- Where today: day: Glassroot Wilds, Thunderroot Wilds, The Skyglass Canopy, Stormscale Summit.
- Movement and senses: walk/run 1/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: _grug_leash_range 20 (inactive for free roamers, see bear); on_spawn: 1 in 10 spawns becomes an elite named 'Silverback'; group_attack; climbs: jump 8, stepheight 3.
- Tiers: default tier normal; elite appears (see behaviour).
- Drops: raw meat 1/1 x2, heavy leather 1/2, ape hair 1/4.
- Design notes: Troop animal that climbs terrain other mobs cannot. **Sub-types:** Young Ape (neutral 0.8), Jungle Ape, Silverback (exists as random elite roll). **Constraints:** Day clock.
- Look: grug_mobs_jungle_ape.png atlas.

### Small birds (gull mesh)

Model: grug_mobs_gull.b3d.

**`grug_mobs:carrion_crow`** — Carrion Crow (neutral; mods/ENTITIES/grug_mobs/carrion_crow.lua:103)  
- Where today: day+night: Ashenward March, Bannerbreak Mesa, The Wyrmglass Crown, Gravesalt Escarpment, The Broken Causeway, The Shattered Line, The Skyglass Canopy, Stormscale Summit.
- Movement and senses: walk/run 1.5/4.6 fly, view 8, reach -, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: flier (fly_in air): idle flight is nudged to 2-4 nodes above ground (flight.lua); passive prey (grazes): never attacks on sight, fights back in melee when hit (dogfight), no group alert.
- Tiers: default tier normal.
- Drops: feather 1/1.
- Design notes: Neutral war-front scavenger: feathers only. **Sub-types:** Few; an aggressive 'Bloodcrow' would be a new disposition. **Constraints:** Flier, contested domain only, any clock. Melee prey retaliation in the air.
- Look: gull mesh at 14 with grug_mobs_crow.png.

**`grug_mobs:gull`** — Gull (critter; mods/ENTITIES/grug_mobs/gull.lua:83)  
- Where today: every grug_beach surface by day (zone palettes ignored).
- Gates: grug_beach biome only (zone palettes ignored).
- Movement and senses: walk/run 1.5/3.4 fly, view 8, reach -, attack -, chase end: - (never fights).
- Behaviour: flies (air), flees.
- Tiers: default tier critter.
- Drops: raw meat 1/1.
- Design notes: Beach scenery. **Sub-types:** None (critter). **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway. Spawns on default:sand only where the biome is grug_beach (palettes ignored).
- Look: grug_mobs_gull.png.

**`grug_mobs:song_bird`** — Song Bird (critter; mods/ENTITIES/grug_mobs/zero_asset_variants.lua:207)  
- Where today: day: Silverleaf Glades.
- Movement and senses: walk/run 1.5/3.4 fly, view 8, reach -, attack -, chase end: - (never fights).
- Behaviour: flies (air), flees.
- Tiers: default tier critter.
- Drops: raw meat 1/1.
- Design notes: Silverleaf scenery bird. **Sub-types:** None (critter). **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway. Flier.
- Look: gull mesh at 8 with grug_mobs_gull.png^[multiply:#78aee8.

### Parrot (critter)

Model: grug_mobs_parrot.b3d.

**`grug_mobs:parrot`** — Parrot (critter; mods/ENTITIES/grug_mobs/parrot.lua:79)  
- Where today: day: Kapok Cradle, Raincall Basin, Whispering Reedlands, Totemwater Reach.
- Movement and senses: walk/run 1.5/3.4 fly, view 8, reach -, attack -, chase end: - (never fights).
- Behaviour: flies (air), flees.
- Tiers: default tier critter.
- Drops: raw meat 1/1.
- Design notes: Jungle-edge scenery. **Sub-types:** None (critter). **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway.
- Look: grug_mobs_parrot.png.

### Kraken

Model: grug_mobs_kraken.b3d.

**`grug_mobs:kraken`** — Kraken Guard (aggressive; mods/ENTITIES/grug_mobs/kraken.lua:11)  
- Where today: deep ocean water surface everywhere (independent authority).
- Gates: deep_ocean water class only.
- Movement and senses: walk/run 3/5 fly swim, view 20, reach 4, attack dogfight, chase end: no leash (own encounter rules), no soft de-aggro.
- Behaviour: swimmer: never leaves water; custom attack pulls the target (or the boat it sits in) down (velocity -8); no leash, no knockback; fixed level 100, armor 70.
- Tiers: default tier normal.
- Drops: none.
- Design notes: Ocean gatekeeper ('Kraken Guard'): punishes swimming the deep sea. 0 XP, no drops. **Sub-types:** None (not a progression mob). **Constraints:** Deep-ocean water class only; independent spawn authority. Never a quest target.
- Look: grug_mobs_kraken.png.

### Reed Angelfish (critter)

Model: grug_mobs_reed_angelfish.b3d.

**`grug_mobs:reed_angelfish`** — Reed Angelfish (critter; mods/ENTITIES/grug_mobs/reed_angelfish.lua:17)  
- Where today: planned inland lakes and bays everywhere, y -30 to 600.
- Gates: planned inland water, source water at and above the spawn, above the natural bed.
- Movement and senses: walk/run 1.1/1.5 fly swim, view 5, reach -, attack -, chase end: - (never fights).
- Behaviour: swimmer: never leaves water.
- Tiers: default tier critter.
- Drops: raw fish 1/1.
- Design notes: Freshwater lake life; one Raw Fish per kill, no XP, no quality loot. **Sub-types:** None (critter). **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway. Swimmer: stays in planned inland water (lakes/bays with sand bed, source water at and above the spawn), not rivers or caves.
- Look: grug_mobs_reed_angelfish.png.

### Crocodile

Model: grug_mobs_crocodile.b3d (15-slot atlas).

**`grug_mobs:crocodile`** — Crocodile (aggressive; mods/ENTITIES/grug_mobs/crocodile.lua:104)  
- Where today: day+night: Mournfen, Whispering Reedlands, Totemwater Reach.
- Movement and senses: walk/run 1/4.6, view 6, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: ambush: stands still (order stand) until a player is within 6 m, then bursts; floats (swims at the surface).
- Tiers: default tier normal.
- Drops: scaled hide 1/1, raw meat 1/1, croc tooth 1/3.
- Kill quests today: r14_undead_08_clear_the_sluice x6 L11 (r14_undead_scout, zone kragmar_mournfen); r20_anchor_047_02 x3 L21 (r20_anchor_047_host, zone kragmar_totemwater_reach); r20_anchor_066_03 x3 L23 (r20_anchor_066_host, zone kragmar_whispering_reedlands).
- Design notes: Invisible until you are close: view range 6, lurks still in swamp mud. **Sub-types:** Young Croc (0.8), Crocodile, Old Snapjaw (elite 1.3). **Constraints:** Any clock; swamp mud host.
- Look: grug_mobs_crocodile.png atlas.

### Bog Ooze

Model: grug_mobs_bog_ooze.b3d (2 slots).

**`grug_mobs:bog_ooze`** — Bog Ooze (aggressive; mods/ENTITIES/grug_mobs/bog_ooze.lua:85)  
- Where today: day+night: Mournfen, Whispering Reedlands, Totemwater Reach.
- Movement and senses: walk/run 1/2.6, view 10, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: engulfs: touch aura deals 2 x damage scale (3 HP) per second to every player within 2 m, independent of its punches; slow: run 2.6.
- Tiers: default tier normal.
- Drops: slime gel 1/1 x1-2, linen scrap 1/3.
- Kill quests today: r14_undead_07_mud_that_moves x6 L10 (r14_undead_steward, zone kragmar_mournfen); r15_undead_local_04 x5 L11 (r14_undead_scout, zone kragmar_mournfen); r20_anchor_047_03 x4 L23 (r20_anchor_047_host, zone kragmar_totemwater_reach); r20_anchor_066_02 x4 L21 (r20_anchor_066_host, zone kragmar_whispering_reedlands).
- Design notes: Slow blob you can outrun but must not stand next to; big box (2 x 2 nodes). **Sub-types:** Small Ooze (0.75, low), Bog Ooze, Great Ooze (1.3, elite). **Constraints:** Any clock; swamp mud. The aura damage is a flat 3, not level-scaled.
- Look: grug_mobs_bog_ooze.png.

### Outlaws (bandit, archer, poacher)

Model: character.b3d (player model, race skin via grug_visuals).

**`grug_mobs:bandit`** — Bandit (aggressive; mods/ENTITIES/grug_mobs/bandit.lua:169)  
- Where today: bandit camp fires only: Copperfell Foothills (home), Goldmead Vale (home), Starbough Vale (home), Mournfen (home), Redtusk Savanna (home), Raincall Basin (home), Stormvault Heights (frontier), Ashenward March (frontier), Glassroot Wilds (frontier), Blackwind Rise (frontier), Bannerbreak Mesa (frontier), Thunderroot Wilds (frontier).
- Movement and senses: walk/run 1/4.6, view 14, reach 3, attack dogfight, chase end: drag leash 25 m.
- Behaviour: camp member: spawned only by bandit camp fires (3-5 members, 1 in 3 is a Bandit Archer, refill one slot per 120-300 s while a player is within 80 m); leash 25, idle roam 20 around the fire; group_attack; random race look (human/dwarf/orc/undead) with cloth armour and a dagger via grug_visuals.
- Tiers: default tier normal.
- Drops: linen_cloth (zone level <= 30) or heavy_cloth (above) 1/1 x1-2, stolen purse 1/3.
- Kill quests today: r14_dwarf_09_ash_under_the_nails x4 L12 (r14_dwarf_scout, zone elandor_copperfell_foothills); r14_elf_09_cinders_in_green_cloth x4 L12 (r14_elf_scout, zone elandor_starbough_vale); r14_human_09_the_blackened_tally x4 L12 (r14_human_scout, zone elandor_goldmead_vale); r14_orc_09_no_forge_made_this_brand x4 L12 (r14_orc_scout, zone kragmar_redtusk_savanna); r14_troll_09_smoke_beneath_the_rain x4 L12 (r14_troll_scout, zone kragmar_raincall_basin); r14_undead_09_fire_that_the_fen_cannot_drown x4 L12 (r14_undead_scout, zone kragmar_mournfen); r20_anchor_036_02 x4 L31 (r20_anchor_036_host, zone elandor_glassroot_wilds); r20_anchor_048_02 x4 L31 (r20_anchor_048_host, zone kragmar_thunderroot_wilds).
- Design notes: Humanoid group fight at a fixed place. **Sub-types:** Confused Bandit (C2 input, low), Bandit Thug, Bandit Leader (elite camp boss). **Constraints:** No ABM row: exists only where a camp fire was placed (12 bandit anchors: six home camps in the 11-20 zones, six frontier camps in the 31-40 zones). Ruling 37 moves bandits to free areas.
- Look: character.b3d; textures grug_mobs_bandit_1/2.png replaced at activation by the grug_visuals race skin.

**`grug_mobs:bandit_archer`** — Bandit Archer (aggressive; mods/ENTITIES/grug_mobs/bandit_archer.lua:91)  
- Where today: bandit camp fires only: Copperfell Foothills (home), Goldmead Vale (home), Starbough Vale (home), Mournfen (home), Redtusk Savanna (home), Raincall Basin (home), Stormvault Heights (frontier), Ashenward March (frontier), Glassroot Wilds (frontier), Blackwind Rise (frontier), Bannerbreak Mesa (frontier), Thunderroot Wilds (frontier).
- Movement and senses: walk/run 1/4, view 16, reach 3, attack dogshoot (arrow_entity, 2.5s), chase end: drag leash 25 m, no soft de-aggro.
- Behaviour: dogshoot: shoots arrows (grug_mobs:arrow_entity, speed 16) every 2.5 s at range and switches to melee up close; ranged mobs ignore the 25 m soft de-aggro; camp member (1 in 3 camp spawns); leash 25.
- Tiers: default tier normal.
- Drops: linen_cloth (zone level <= 30) or heavy_cloth (above) 1/1 x1-2, stolen purse 1/3, arrow 1/3.
- Kill quests today: r14_dwarf_09_ash_under_the_nails x4 L12 (r14_dwarf_scout, zone elandor_copperfell_foothills); r14_elf_09_cinders_in_green_cloth x4 L12 (r14_elf_scout, zone elandor_starbough_vale); r14_human_09_the_blackened_tally x4 L12 (r14_human_scout, zone elandor_goldmead_vale); r14_orc_09_no_forge_made_this_brand x4 L12 (r14_orc_scout, zone kragmar_redtusk_savanna); r14_troll_09_smoke_beneath_the_rain x4 L12 (r14_troll_scout, zone kragmar_raincall_basin); r14_undead_09_fire_that_the_fen_cannot_drown x4 L12 (r14_undead_scout, zone kragmar_mournfen); r20_anchor_027_03 x4 L33 (r20_anchor_027_host, zone elandor_stormvault_heights); r20_anchor_031_03 x4 L33 (r20_anchor_031_host, zone elandor_ashenward_march); r20_anchor_039_03 x4 L33 (r20_anchor_039_host, zone kragmar_blackwind_rise); r20_anchor_043_03 x4 L33 (r20_anchor_043_host, zone kragmar_bannerbreak_mesa).
- Design notes: Ranged camp member. **Sub-types:** Bandit Lookout, Bandit Sharpshooter. **Constraints:** Camp only (variant roll of the bandit camp).
- Look: as bandit.

**`grug_mobs:poacher`** — Poacher (aggressive; mods/ENTITIES/grug_mobs/zero_asset_variants.lua:56)  
- Where today: night: Goldmead Vale, Whitebridge Shire, Ashenward March, Silverleaf Glades, Starbough Vale, Lorindor, Moonfall Wood.
- Gates: Silverleaf Glades: only where the level field >= 7.
- Movement and senses: walk/run 1/4, view 16, reach 3, attack dogshoot (arrow_entity, 2.5s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took), no soft de-aggro.
- Behaviour: dogshoot: shoots arrows (grug_mobs:arrow_entity, speed 16) every 2.5 s at range and switches to melee up close; ranged mobs ignore the 25 m soft de-aggro; roams freely (no camp fire); group_attack.
- Tiers: default tier normal.
- Drops: linen_cloth (zone level <= 30) or heavy_cloth (above) 1/1 x1-2, stolen purse 1/3, arrow 1/3.
- Kill quests today: r14_elf_07_quiet_the_lower_boughs x6 L10 (r14_elf_steward, zone elandor_starbough_vale); r14_human_08_empty_snares x6 L11 (r14_human_scout, zone elandor_goldmead_vale); r15_elf_local_03 x4 L11 (r14_elf_scout, zone elandor_starbough_vale); r20_anchor_016_02 x4 L21 (r20_anchor_016_host, zone elandor_whitebridge_shire); r20_anchor_018_02 x4 L21 (r20_anchor_018_host, zone elandor_lorindor); r20_anchor_030_02 x4 L21 (r20_anchor_030_host, zone elandor_whitebridge_shire); r20_anchor_034_02 x4 L21 (r20_anchor_034_host, zone elandor_lorindor); r20_anchor_035_03 x4 L23 (r20_anchor_035_host, zone elandor_moonfall_wood); r20_anchor_062_02 x4 L21 (r20_anchor_062_host, zone elandor_whitebridge_shire); r20_anchor_063_02 x4 L21 (r20_anchor_063_host, zone elandor_lorindor).
- Design notes: Free-roaming night archer of the Elf and Human forests; brown runtime skin, no race composer. **Sub-types:** Snare Setter (low), Poacher, Poacher Chief (elite). **Constraints:** Night clock. Silverleaf: only where the level is >= 7.
- Look: grug_mobs_bandit_2.png^[multiply:#6b5948.

### Mirefolk

Model: character.b3d at 0.85.

**`grug_mobs:mirefolk`** — Mirefolk (aggressive; mods/ENTITIES/grug_mobs/mirefolk.lua:91)  
- Where today: nowhere today (camp type registered, no camp fire placed at the four Mirefolk POIs).
- Movement and senses: walk/run 1/4.6, view 12, reach 3, attack dogfight, chase end: drag leash 25 m.
- Behaviour: swarm: when one engages, every same-name member of the same camp within 20 m joins; leash 25; group_attack.
- Tiers: default tier normal.
- Drops: linen cloth 1/2, raw fish 1/1, shiny scale 1/4.
- Design notes: Small (0.85) swamp humanoids that rush together. **Sub-types:** Mire Whelp (small), Mirefolk, Mire Shaman (elite). **Constraints:** Camp type exists but no camp fire is placed at the four Mirefolk POIs: the entity never appears today. Ruling 37 gives them areas.
- Look: grug_mobs_mirefolk.png skin.

### Fox

Model: grug_mobs_fox.b3d.

**`grug_mobs:fox`** — Fox (aggressive; mods/ENTITIES/grug_mobs/start_zone_families.lua:71)  
- Where today: day: Hearthpine Vale, Copperfell Foothills, Dawnmere Fields, Goldmead Vale, Silverleaf Glades, Starbough Vale.
- Gates: start_band(4): in the six start zones only where the level field >= 4.
- Movement and senses: walk/run 1.5/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: hit and run: after each landed bite it leaps 6 m/s away from the target (cooldown 4 s), then comes back.
- Tiers: default tier normal.
- Drops: raw meat 1/1, leather 1/2, fang 1/3.
- Kill quests today: r14_dwarf_07_a_ledger_in_the_scrub x6 L10 (r14_dwarf_steward, zone elandor_copperfell_foothills); r14_elf_05_keepers_of_the_saplings x5 L5 (r14_elf_elder); r14_elf_08_watch_the_green_road x6 L11 (r14_elf_scout, zone elandor_starbough_vale); r14_human_07_orchard_watch x6 L10 (r14_human_steward, zone elandor_goldmead_vale); r15_human_local_04 x5 L11 (r14_human_scout, zone elandor_goldmead_vale).
- Design notes: Small aggressive day hunter that bites and darts away - annoying to melee. **Sub-types:** Shipped sub-types (Round 28 catalogue, names per frame §5): a neutral Young Fox (L5-7) in the Accord starts (today the family is aggressive); Bracken Fox (neutral) and Thicket Vixen (L11-20); Orchard Fox (neutral) and Redfang Vixen (L21-30). Display names are free. **Constraints:** Day clock. start_band(4) in the start zones. visual_size 10 on a 0.5 box: HP bar drawn at 1/10 size today (Ruling 10).
- Look: grug_mobs_fox.png.

### Ibex

Model: grug_mobs_ibex.b3d.

**`grug_mobs:ibex`** — Ibex (neutral; mods/ENTITIES/grug_mobs/start_zone_families.lua:103)  
- Where today: day: Hearthpine Vale, Copperfell Foothills, Frostbarrow Shelf, Stormvault Heights.
- Gates: start_band(4) in the six start zones.
- Movement and senses: walk/run 1.5/4.6, view 14, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: passive prey (grazes): never attacks on sight, fights back in melee when hit (dogfight), no group alert.
- Tiers: default tier normal.
- Drops: raw meat 1/1 x2, leather 1/2.
- Kill quests today: r14_dwarf_05_the_high_path x5 L5 (r14_dwarf_elder); r15_dwarf_local_04 x5 L11 (r14_dwarf_scout, zone elandor_copperfell_foothills); r20_anchor_014_02 x4 L21 (r20_anchor_014_host, zone elandor_frostbarrow_shelf).
- Design notes: Neutral dwarf-zone climber; tall selection box (1.8) over a low 0.5 collision box. **Sub-types:** Kid (0.75, L1-3), Ibex, Old Ibex. **Constraints:** Day clock. In the six start zones only where the level field is >= 4 (start_band(4)).
- Look: grug_mobs_ibex.png.

### Wild Turkey (critter)

Model: grug_mobs_wild_turkey.b3d.

**`grug_mobs:wild_turkey`** — Wild Turkey (critter; mods/ENTITIES/grug_mobs/start_zone_families.lua:132)  
- Where today: day: Dawnmere Fields, Goldmead Vale.
- Movement and senses: walk/run 1.5/3.4, view 9, reach 3, attack dogfight, chase end: drag leash 40 m.
- Behaviour: flees when hit.
- Tiers: default tier critter.
- Drops: raw meat 1/1.
- Kill quests today: r14_human_05_the_missing_flock x5 L5 (r14_human_elder).
- Design notes: Dawnmere/Goldmead meadow critter. **Sub-types:** None (critter). Kill quests on it exist today (r14_human_05) and violate the planned rule. **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway.
- Look: grug_mobs_wild_turkey.png.

### Plains Runner

Model: grug_mobs_plains_runner.b3d.

**`grug_mobs:plains_runner`** — Plains Runner (neutral; mods/ENTITIES/grug_mobs/start_zone_families.lua:157)  
- Where today: day: Sunscar Flats.
- Movement and senses: walk/run 1.5/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: passive prey (grazes): never attacks on sight, fights back in melee when hit (dogfight), no group alert.
- Tiers: default tier normal.
- Drops: raw meat 1/1.
- Design notes: Neutral Sunscar ground bird. **Sub-types:** Chick (0.75), Runner, Big Runner. **Constraints:** Day clock; palette only in Sunscar Flats.
- Look: grug_mobs_plains_runner.png.

### Tapir

Model: grug_mobs_tapir.b3d.

**`grug_mobs:tapir`** — Tapir (neutral; mods/ENTITIES/grug_mobs/start_zone_families.lua:183)  
- Where today: day: Kapok Cradle, Raincall Basin, Whispering Reedlands, Totemwater Reach.
- Gates: start_band(4) in the six start zones.
- Movement and senses: walk/run 1.5/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: passive prey (grazes): never attacks on sight, fights back in melee when hit (dogfight), no group alert.
- Tiers: default tier normal.
- Drops: raw meat 1/1 x2, leather 1/2.
- Kill quests today: r15_troll_local_02 x5 L10 (r15_troll_local, zone kragmar_raincall_basin); r20_anchor_024_02 x4 L21 (r20_anchor_024_host, zone kragmar_whispering_reedlands).
- Design notes: Neutral troll-zone grazer, double meat. **Sub-types:** Calf (0.75), Tapir, Bull Tapir. **Constraints:** Day clock; start_band(4) in start zones.
- Look: grug_mobs_tapir.png.

### Giant Rat

Model: grug_mobs_giant_rat.b3d.

**`grug_mobs:giant_rat`** — Giant Rat (aggressive; mods/ENTITIES/grug_mobs/start_zone_families.lua:205)  
- Where today: night: Hearthpine Vale, Dawnmere Fields, Silverleaf Glades, Stillgrave Hollow, Sunscar Flats, Kapok Cradle; underground y -40 to -300.
- Movement and senses: walk/run 1.5/4.6, view 10, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: swarm: when one rat engages, every same-name rat within 12 m that is not fighting joins (camp_swarm verb); group_attack.
- Tiers: default tier normal.
- Drops: raw meat 1/1.
- Design notes: Night swarm animal of start towns; one pull brings the nest. **Sub-types:** Shipped sub-types (Round 28 catalogue, names per frame §5): Large Rat (L1-3), Aggressive Rat (L5-7) and Monstrous Rat (L7-9) in the starts; Granary Rat and Burrow Gnawer (L11-20); Grave, Kapok and Dust forms by zone. Raw meat is the only drop today. **Constraints:** Night clock; also underground y -40 to -300. Swarm and group alert are entity-name keyed.
- Look: grug_mobs_giant_rat.png.

### Goblin (raider, slinger, miners)

Model: grug_mobs_goblin.b3d.

**`grug_mobs:goblin_miner`** — Goblin Miner (aggressive; mods/ENTITIES/grug_mobs/goblin_miners.lua:46)  
- Where today: underground y -100 to -300.
- Movement and senses: walk/run 1.5/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: swarm: when one engages, every same-name goblin within 16 m joins; group_attack.
- Tiers: default tier normal.
- Drops: linen scrap 1/2, stolen purse 1/8.
- Design notes: Cave goblin melee. **Sub-types:** As raider. **Constraints:** Underground y -100 to -300.
- Look: grug_mobs_goblin_raider.png (same texture as the raider).

**`grug_mobs:goblin_miner_slinger`** — Goblin Miner Slinger (aggressive; mods/ENTITIES/grug_mobs/goblin_miners.lua:48)  
- Where today: underground y -100 to -300.
- Movement and senses: walk/run 1.5/4.6, view 16, reach 3, attack dogshoot (rock_entity, 2.5s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: dogshoot rocks every 2.5 s; swarm: when one engages, every same-name goblin within 16 m joins.
- Tiers: default tier normal.
- Drops: linen scrap 1/2, arrow 1/3.
- Design notes: Cave goblin slinger. **Sub-types:** As slinger. **Constraints:** Underground y -100 to -300.
- Look: grug_mobs_goblin_slinger.png.

**`grug_mobs:goblin_raider`** — Goblin Raider (aggressive; mods/ENTITIES/grug_mobs/night_families.lua:61)  
- Where today: night: Copperfell Foothills, Frostbarrow Shelf, Stormvault Heights, Speargrass Reach, Bannerbreak Mesa.
- Movement and senses: walk/run 1.5/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: swarm: when one engages, every same-name goblin within 16 m joins; group_attack.
- Tiers: default tier normal.
- Drops: linen scrap 1/2, stolen purse 1/8.
- Kill quests today: r14_dwarf_08_hold_the_marker_stones x6 L11 (r14_dwarf_scout, zone elandor_copperfell_foothills); r20_anchor_014_03 x4 L23 (r20_anchor_014_host, zone elandor_frostbarrow_shelf); r20_anchor_042_03 x4 L23 (r20_anchor_042_host, zone kragmar_speargrass_reach).
- Design notes: Night raiding party melee. **Sub-types:** Goblin Sneak, Goblin Raider, Goblin Warboss (elite). **Constraints:** Night clock; palette goblin_raid (dwarf and orc mountain zones).
- Look: grug_mobs_goblin_raider.png.

**`grug_mobs:goblin_slinger`** — Goblin Slinger (aggressive; mods/ENTITIES/grug_mobs/night_families.lua:63)  
- Where today: night: Copperfell Foothills, Frostbarrow Shelf, Stormvault Heights, Speargrass Reach, Bannerbreak Mesa.
- Movement and senses: walk/run 1.5/4.6, view 16, reach 3, attack dogshoot (rock_entity, 2.5s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: dogshoot: slings rocks (grug_mobs:rock_entity) every 2.5 s; swarm: when one engages, every same-name goblin within 16 m joins; group_attack.
- Tiers: default tier normal.
- Drops: linen scrap 1/2, arrow 1/3.
- Kill quests today: r14_dwarf_08_hold_the_marker_stones x6 L11 (r14_dwarf_scout, zone elandor_copperfell_foothills); r20_anchor_026_03 x4 L23 (r20_anchor_026_host, zone elandor_frostbarrow_shelf).
- Design notes: Ranged member of the raiding party. **Sub-types:** As raider. **Constraints:** Night clock.
- Look: grug_mobs_goblin_slinger.png.

### Goblin Raider Hound

Model: grug_mobs_goblin_hound.b3d.

**`grug_mobs:goblin_hound`** — Goblin Raider Hound (aggressive; mods/ENTITIES/grug_mobs/night_families.lua:82)  
- Where today: night: Copperfell Foothills, Frostbarrow Shelf, Stormvault Heights, Speargrass Reach, Bannerbreak Mesa.
- Movement and senses: walk/run 1.5/4.6, view 15, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: swarm: when one engages, every same-name goblin within 16 m joins; group_attack.
- Tiers: default tier normal.
- Drops: raw meat 1/1.
- Kill quests today: r14_dwarf_08_hold_the_marker_stones x6 L11 (r14_dwarf_scout, zone elandor_copperfell_foothills).
- Design notes: Display name 'Goblin Raider Hound'; the dog of the raid (view 15). **Sub-types:** Hound Pup, Hound, Warg (elite). **Constraints:** Night clock.
- Look: grug_mobs_goblin_hound.png.

### Wisp

Model: grug_mobs_wisp.b3d (2 slots: held sword + body).

**`grug_mobs:ember_wisp`** — Ember Wisp (aggressive; mods/ENTITIES/grug_mobs/ember_wisp.lua:38)  
- Where today: underground y -700 and below.
- Movement and senses: walk/run 2.5/4.6 fly, view 16, reach 2, attack dogshoot (ember_entity, 2s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: flier, physical = false; dogshoot embers every 2 s; immune to lava and fire; water hurts (6).
- Tiers: default tier normal.
- Drops: emberglass 1/4.
- Design notes: Deep fire wisp. **Sub-types:** - **Constraints:** Underground y <= -700.
- Look: grug_mobs_wisp.png^[colorize:#ff5a1e:140.

**`grug_mobs:wisp`** — Wisp (aggressive; mods/ENTITIES/grug_mobs/night_families.lua:167)  
- Where today: night: Whitebridge Shire, Ashenward March, Lorindor, Moonfall Wood, Glassroot Wilds, Mournfen, Whispering Reedlands, Totemwater Reach, The Broken Causeway.
- Movement and senses: walk/run 2.5/4.6 fly, view 14, reach 2, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: blink: in combat every 4 s it teleports up to 2.5 m toward its target; flier, physical = false (passes through walls and trees).
- Tiers: default tier normal.
- Drops: none.
- Kill quests today: r20_anchor_016_03 x3 L23 (r20_anchor_016_host, zone elandor_whitebridge_shire); r20_anchor_018_03 x3 L23 (r20_anchor_018_host, zone elandor_lorindor); r20_anchor_024_03 x3 L23 (r20_anchor_024_host, zone kragmar_whispering_reedlands); r20_anchor_030_03 x3 L23 (r20_anchor_030_host, zone elandor_whitebridge_shire); r20_anchor_034_03 x3 L23 (r20_anchor_034_host, zone elandor_lorindor); r20_anchor_046_03 x3 L23 (r20_anchor_046_host, zone kragmar_whispering_reedlands); r20_anchor_063_03 x3 L23 (r20_anchor_063_host, zone elandor_lorindor).
- Design notes: Night spirit that closes distance by blinking; drops nothing today. **Sub-types:** Faint Wisp (low), Wisp, Will-o'-the-Wisp (elite). Ember Wisp is the cave sibling. **Constraints:** Night clock. Empty drop list (quest drops via the drop hook would be the only loot).
- Look: grug_mobs_wisp.png body + held steel sword texture.

### Treant

Model: grug_mobs_treant.b3d.

**`grug_mobs:ashen_treant`** — Ashen Treant (aggressive; mods/ENTITIES/grug_mobs/night_families.lua:211)  
- Where today: night: Ashenward March.
- Movement and senses: walk/run 1.5/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: root aura: every second every player within 3 m is slowed to 70 % for 1.2 s.
- Tiers: default tier normal.
- Drops: stick 1/1 x1-2, apple 1/4.
- Kill quests today: r20_anchor_031_02 x3 L31 (r20_anchor_031_host, zone elandor_ashenward_march).
- Design notes: Night tree-creature: slows everyone near it; drops sticks and apples. **Sub-types:** Sapling (0.75), Treant, Elder Treant (elite). **Constraints:** Night clock; deep-forest litter; box extends 1 node below origin.
- Look: grug_mobs_treant.png^[multiply:#6d5140.

**`grug_mobs:gravewood_treant`** — Gravewood Treant (aggressive; mods/ENTITIES/grug_mobs/night_families.lua:217)  
- Where today: night: Ossuary Reach, Blackwind Rise.
- Movement and senses: walk/run 1.5/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: root aura: every second every player within 3 m is slowed to 70 % for 1.2 s.
- Tiers: default tier normal.
- Drops: stick 1/1 x1-2, apple 1/4.
- Kill quests today: r20_anchor_020_03 x3 L23 (r20_anchor_020_host, zone kragmar_ossuary_reach); r20_anchor_038_02 x3 L21 (r20_anchor_038_host, zone kragmar_ossuary_reach); r20_anchor_039_02 x3 L31 (r20_anchor_039_host, zone kragmar_blackwind_rise); r20_anchor_064_02 x3 L21 (r20_anchor_064_host, zone kragmar_ossuary_reach).
- Design notes: Undead-forest treant. **Sub-types:** As ashen treant. **Constraints:** Night clock; bone litter.
- Look: grug_mobs_treant.png^[multiply:#c2bba8.

### Bat

Model: grug_mobs_cave_bat.b3d.

**`grug_mobs:blood_bat`** — Blood Bat (aggressive; mods/ENTITIES/grug_mobs/zero_asset_variants.lua:295)  
- Where today: underground y -101 to -300.
- Movement and senses: walk/run 1.5/4.6 fly, view 12, reach 2, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: flier; group_attack; reach 2.
- Tiers: default tier normal.
- Drops: raw meat 1/1.
- Design notes: Hostile bat swarm in mid caves. **Sub-types:** As cave bat ladder. **Constraints:** Underground y -101 to -300.
- Look: grug_mobs_cave_bat.png^[multiply:#8f2635 at 1.25.

**`grug_mobs:cave_bat`** — Cave Bat (critter; mods/ENTITIES/grug_mobs/cave_bat.lua:83)  
- Where today: underground y -40 and below.
- Movement and senses: walk/run 1.5/3.4 fly, view 8, reach -, attack -, chase end: - (never fights).
- Behaviour: flies (air), flees.
- Tiers: default tier critter.
- Drops: raw meat 1/1.
- Design notes: Cave scenery. **Sub-types:** None (critter). The Blood Bat is the hostile bat. **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway. Underground domain only.
- Look: grug_mobs_cave_bat.png.

### Crawler (cave crawler, bone weevil, stone mite)

Model: grug_mobs_cave_crawler.b3d.

**`grug_mobs:bone_weevil`** — Bone Weevil (critter; mods/ENTITIES/grug_mobs/bone_weevil.lua:80)  
- Where today: day: Ossuary Reach, Blackwind Rise, Gravesalt Escarpment; in the palette but no host surface in Whitebridge Shire, Ashenward March, Moonfall Wood, Glassroot Wilds.
- Movement and senses: walk/run 1.5/3.4, view 8, reach -, attack -, chase end: - (never fights).
- Behaviour: flees.
- Tiers: default tier critter.
- Drops: raw meat 1/1.
- Design notes: Bone-forest and blight scenery; the row stamps one of two textures. **Sub-types:** None (critter). **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway.
- Look: grug_mobs_bone_weevil.png (bone litter) / grug_mobs_bone_weevil_blight.png (blight dirt), chosen by spawn row.

**`grug_mobs:cave_crawler`** — Cave Crawler (critter; mods/ENTITIES/grug_mobs/cave_crawler.lua:68)  
- Where today: underground y -40 and below.
- Movement and senses: walk/run 1.5/3.4, view 8, reach -, attack -, chase end: - (never fights).
- Behaviour: flees.
- Tiers: default tier critter.
- Drops: raw meat 1/1.
- Design notes: Cave scenery. **Sub-types:** None (critter). The Stone Mite is the hostile crawler. **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway. Underground domain only.
- Look: grug_mobs_cave_crawler.png.

**`grug_mobs:stone_mite`** — Stone Mite (aggressive; mods/ENTITIES/grug_mobs/zero_asset_variants.lua:332)  
- Where today: underground y -700 and below.
- Movement and senses: walk/run 1.5/4.6, view 10, reach 2, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: group_attack; reach 2.
- Tiers: default tier normal.
- Drops: stone core 1/8.
- Design notes: Deep hostile crawler; drops Stone Core 1/8. **Sub-types:** - **Constraints:** Underground y <= -700 on stratum rock.
- Look: grug_mobs_cave_crawler.png^[multiply:#77736b at 4.

### Oerkki

Model: grug_mobs_oerkki.b3d.

**`grug_mobs:oerkki`** — Oerkki (aggressive; mods/ENTITIES/grug_mobs/oerkki.lua:61)  
- Where today: underground y -300 to -700.
- Movement and senses: walk/run 1.5/4.6, view 12, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: blink: in combat every 5 s teleports up to 3 m toward its target (purple smoke); water hurts (2).
- Tiers: default tier normal.
- Drops: quartz 1/2, silver lump 1/5.
- Design notes: Deep cave blinker; drops quartz and silver lump. **Sub-types:** - **Constraints:** Underground y -300 to -700.
- Look: grug_mobs_oerkki.png / grug_mobs_oerkki4.png (random of two).

### Glowwing

Model: grug_mobs_glowwing.b3d.

**`grug_mobs:glowwing`** — Glowwing (aggressive; mods/ENTITIES/grug_mobs/glowwing.lua:29)  
- Where today: underground y -300 to -500.
- Movement and senses: walk/run 2/6 fly, view 12, reach 2, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: flier, physical = false; fastest run in the roster (6); group_attack; water hurts (4).
- Tiers: default tier normal.
- Drops: venom gland 1/5.
- Design notes: Glowing cave flier swarm. **Sub-types:** - **Constraints:** Underground y -300 to -500.
- Look: grug_mobs_glowwing.png^[colorize:#73e8ff:65.

### Crystal Shard

Model: grug_mobs_crystal_shard.b3d.

**`grug_mobs:crystal_shard`** — Crystal Shard (aggressive; mods/ENTITIES/grug_mobs/crystal_shard.lua:39)  
- Where today: underground y -300 to -700.
- Movement and senses: walk/run 1.5/4.6, view 16, reach 3, attack dogshoot (crystal_shard_entity, 1.6s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: dogshoot crystal fragments every 1.6 s (speed 8); jump 8.
- Tiers: default tier normal.
- Drops: emberglass shard 1/1 x1-2, emberglass 1/6.
- Design notes: Deep turret-like shooter; emberglass source. **Sub-types:** - **Constraints:** Underground y -300 to -700.
- Look: grug_mobs_crystal_shard.png.

### Dungeon Master / Land Guard

Model: grug_mobs_dungeon_master.b3d.

**`grug_mobs:dungeon_master`** — Dungeon Master (aggressive; mods/ENTITIES/grug_mobs/dungeon_master.lua:40)  
- Where today: underground y -500 to -1000.
- Movement and senses: walk/run 1.5/4.6, view 16, reach 3, attack dogshoot (dungeon_fireball, 2.2s), chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: dogshoot fireballs every 2.2 s (speed 7).
- Tiers: default tier normal.
- Drops: emberglass shard 1/2 x1-2, rough diamond 1/8.
- Design notes: Deep caster; emberglass and rough diamond. **Sub-types:** - **Constraints:** Underground y -500 to -1000.
- Look: three random textures grug_mobs_dungeon_master*.png.

**`grug_mobs:land_guard`** — Land Guard (guard role (no fixed disposition), elite; mods/ENTITIES/grug_mobs/land_guard.lua:29)  
- Where today: underground y -1000 and below.
- Movement and senses: walk/run 1.5/4.6, view 14, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: always ELITE (def tier); melee.
- Tiers: default tier elite.
- Drops: heavy leather 1/2 x1-2, rough diamond 1/4.
- Design notes: Deepest elite melee. **Sub-types:** - **Constraints:** Underground y <= -1000, sparse (chance 9000, cap 1). Display role guard: no fixed disposition entry.
- Look: three random textures grug_mobs_land_guard*.png.

### Lava Flan

Model: grug_mobs_lava_flan.b3d.

**`grug_mobs:lava_flan`** — Lava Flan (aggressive; mods/ENTITIES/grug_mobs/lava_flan.lua:29)  
- Where today: underground y -700 and below.
- Movement and senses: walk/run 1/3.4, view 10, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: immune to lava and fire; water hurts (8); floats; group_attack.
- Tiers: default tier normal.
- Drops: emberglass 1/5, slime gel 1/2.
- Design notes: Deepest melee blob. **Sub-types:** - **Constraints:** Underground y <= -700.
- Look: three random textures grug_mobs_lava_flan*.png.

### Rift Spawn

Model: grug_mobs_rift_spawn.b3d.

**`grug_mobs:rift_spawn`** — Rift Spawn (aggressive; mods/ENTITIES/grug_mobs/rift_spawn.lua:102)  
- Where today: night: The Wyrmglass Crown, Gravesalt Escarpment, The Skyglass Canopy, Stormscale Summit; underground y -1000 and below.
- Movement and senses: walk/run 1.5/4.6, view 14, reach 3, attack explode, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: explodes: 2 s fuse when a target is within reach 3 and in line of sight (fuse resets if it is not), then a 3.5 m burst that hits players AND mobs and REMOVES the rift spawn.
- Tiers: default tier normal.
- Drops: slime gel 1/2.
- Design notes: Suicide bomber: kill it fast or step out of reach. **Sub-types:** Rift Mote (small), Rift Spawn, Rift Horror (elite). **Constraints:** The burst removes the object without a death: no XP, loot or quest credit unless the player kills it before the burst. Night clock on the surface (palette rift_spawn), any depth below -1000.
- Look: grug_mobs_rift_spawn.png.

### War Construct

Model: grug_mobs_war_construct.b3d.

**`grug_mobs:war_construct`** — War Construct (aggressive, elite; mods/ENTITIES/grug_mobs/war_construct.lua:28)  
- Where today: day+night: The Broken Causeway, The Shattered Line.
- Movement and senses: walk/run 1.5/4.6, view 14, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: always ELITE (def tier); melee.
- Tiers: default tier elite.
- Drops: stone core 1/1, iron bar 1/1 x2-4.
- Design notes: Huge elite machine (visual 3, box 2.7 high) of the two central fronts; drops a Stone Core and 2-4 iron bars every kill. **Sub-types:** Broken Construct (normal tier, 0.8), War Construct (elite). **Constraints:** Any clock; palette war_construct (Broken Causeway, Shattered Line); sparse (interval 30, chance 7000, cap 1).
- Look: grug_mobs_war_construct.png.

### Crab (shore crab, reef lurker)

Model: grug_mobs_shore_crab.b3d.

**`grug_mobs:reef_lurker`** — Reef Lurker (neutral, elite; mods/ENTITIES/grug_mobs/shore_crab.lua:56)  
- Where today: the same coasts where the level field is 45-60 (front zones 41-60 and islands).
- Gates: only where the level field is 45-60.
- Movement and senses: walk/run 1.5/3.4, view 8, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: passive prey (fights back), no jump, fear height 2; def tier ELITE.
- Tiers: default tier elite.
- Drops: raw meat 1/1 x3-6, scaled hide 1/2 x3.
- Design notes: Elite crab of the level 45-60 coasts; triple drops. **Sub-types:** - **Constraints:** Same shore host as the crab, level 45-60 only; cap 1.
- Look: grug_mobs_shore_crab.png.

**`grug_mobs:shore_crab`** — Shore Crab (neutral; mods/ENTITIES/grug_mobs/shore_crab.lua:54)  
- Where today: every coast in every zone: default:sand at y 0-20 with water within 6 nodes, where the level field is below 45 (ignores zone palettes; any time of day).
- Gates: only where the level field < 45.
- Movement and senses: walk/run 1.5/3.4, view 8, reach 3, attack dogfight, chase end: damage-sustained pursuit (ends 15 s after the last damage it took).
- Behaviour: passive prey (fights back), no jump, fear height 2.
- Tiers: default tier normal.
- Drops: raw meat 1/1 x1-2, scaled hide 1/2.
- Design notes: Neutral beach animal on every coast below level 45. **Sub-types:** Shipped sub-types (Round 28 catalogue, names per frame §5): Small Crab (neutral, L3-5) and Monstrous Crab (L7-9) in the starts; Tidepool Crab and Reefclaw Snapper (L11-20); Bank Crab and Barnacle Pincher (L21-30); Breakwater Crab (L31-40). **Constraints:** Ignores zone palettes: any default:sand at y 0-20 with water within 6 nodes (at or below sea level 1), level field < 45. Any clock. Not density-budgeted; its own row is very frequent (chance 300, cap 3 -> 4).
- Look: grug_mobs_shore_crab.png.

### Bog Fowl (critter)

Model: grug_mobs_bog_fowl.b3d.

**`grug_mobs:bog_fowl`** — Bog Fowl (critter; mods/ENTITIES/grug_mobs/bog_fowl.lua:77)  
- Where today: day: Mournfen, Whispering Reedlands, Totemwater Reach.
- Movement and senses: walk/run 1.5/3.4, view 8, reach -, attack -, chase end: - (never fights).
- Behaviour: floats; flees.
- Tiers: default tier critter.
- Drops: raw meat 1/1.
- Design notes: Swamp scenery. **Sub-types:** None (critter). **Constraints:** Critter tier: always level 1, 1 HP, 0 XP, never elite/rare, never a kill target (Ruling 41 validation). Passive + runaway.
- Look: grug_mobs_bog_fowl.png.

### Dragons and whelps

Model: grug_mobs_ice_dragon.b3d, grug_mobs_jungle_wyvern.b3d.

**`grug_mobs:ice_dragon`** — Wyrmglass Ice Dragon (aggressive, boss; mods/ENTITIES/grug_mobs/boss_dragons.lua:883)  
- Where today: fixed lair on The Wyrmglass Crown (x -3260, z -40), respawn 30 min.
- Movement and senses: walk/run 5.2/6.5, view 48, reach 6, attack dogfight, chase end: drag leash 64 m.
- Behaviour: boss tier (18000 HP), fixed level 70; ground/flight switching, breath (rime ground effect), dive slam x3 damage, wing gust; enrage at 50 % HP spawns whelps; respawn 30 min; reward: 4 Scaled Hide plus boss gear to every participant within 60 m, 24 h lockout per player.
- Tiers: default tier boss.
- Drops: none.
- Design notes: Island apex encounter on The Wyrmglass Crown. **Sub-types:** None. **Constraints:** Fixed encounter; not a quest kill target in the current design.
- Look: grug_mobs_ice_dragon.png^grug_mobs_dragon_shading.png.

**`grug_mobs:ice_whelp`** — Wyrmglass Ice Dragon Whelp (aggressive; mods/ENTITIES/grug_mobs/boss_dragons.lua:881)  
- Where today: summoned by the Ice Dragon's enrage.
- Movement and senses: walk/run 5.2/6.5, view 48, reach 3, attack dogfight, chase end: drag leash 40 m.
- Behaviour: summoned by the ice dragon's enrage; fixed level 20, flies at 9.5.
- Tiers: default tier normal.
- Drops: none.
- Design notes: Boss add. **Sub-types:** None. **Constraints:** Exists only during the dragon fight.
- Look: ice dragon mesh at 2.66.

**`grug_mobs:jungle_wyvern`** — Stormscale Jungle Wyvern (aggressive, boss; mods/ENTITIES/grug_mobs/boss_dragons.lua:885)  
- Where today: fixed lair on Stormscale Summit (x 3260, z -40), respawn 30 min.
- Movement and senses: walk/run 5.2/6.5, view 48, reach 6, attack dogfight, chase end: drag leash 64 m.
- Behaviour: boss tier, fixed level 70; as ice dragon plus lightning ring (scorch ground effect); enrage whelps.
- Tiers: default tier boss.
- Drops: none.
- Design notes: Island apex encounter on Stormscale Summit. **Sub-types:** None. **Constraints:** Fixed encounter.
- Look: grug_mobs_jungle_wyvern.png.

**`grug_mobs:storm_whelp`** — Stormscale Jungle Wyvern Whelp (aggressive; mods/ENTITIES/grug_mobs/boss_dragons.lua:882)  
- Where today: summoned by the Jungle Wyvern's enrage.
- Movement and senses: walk/run 5.2/6.5, view 48, reach 3, attack dogfight, chase end: drag leash 40 m.
- Behaviour: summoned by the wyvern's enrage; fixed level 20.
- Tiers: default tier normal.
- Drops: none.
- Design notes: Boss add. **Sub-types:** None. **Constraints:** Exists only during the wyvern fight.
- Look: wyvern mesh at 2.66.

### Faction guards

Model: character.b3d.

**`grug_mobs:guard_accord`** — Accord Guard (guard role (no fixed disposition); mods/ENTITIES/grug_mobs/guard.lua:271)  
- Where today: outpost guard banners (2-3, refill 180-360 s), start-town posts and patrols, capital watch.
- Gates: level floor 20.
- Movement and senses: walk/run 1.2/4.6, view 14, reach 3, attack dogfight, chase end: drag leash 30 m.
- Behaviour: type npc with faction; level from the inverse guard field (20-70); promotes itself to elite at 60+; attacks enemy-faction players and monsters; leash 30, idle roam 20 around its banner; one guard per post walks a patrol route.
- Tiers: default tier normal; elite appears (see behaviour).
- Drops: war trophy 1/1 x1-2, heavy cloth 1/3.
- Kill quests today: r20_anchor_040_03 x3 L40 (r20_anchor_040_host, zone elandor_stormvault_heights); r20_anchor_044_03 x3 L40 (r20_anchor_044_host, zone elandor_ashenward_march); r20_anchor_048_03 x3 L40 (r20_anchor_048_host, zone elandor_glassroot_wilds).
- Design notes: Faction defender; kill target for enemy-faction PvP quests (three L40 quests per faction today). **Sub-types:** None (not a wildlife sub-type). **Constraints:** Loot only for enemy-faction killers. Display role guard: no fixed disposition entry.
- Look: character.b3d with grug_mobs_guard_accord.png plus grug_visuals armour.

**`grug_mobs:guard_throng`** — Throng Guard (guard role (no fixed disposition); mods/ENTITIES/grug_mobs/guard.lua:273)  
- Where today: outpost guard banners (2-3, refill 180-360 s), start-town posts and patrols, capital watch.
- Gates: level floor 20.
- Movement and senses: walk/run 1.2/4.6, view 14, reach 3, attack dogfight, chase end: drag leash 30 m.
- Behaviour: type npc with faction; level from the inverse guard field (20-70); promotes itself to elite at 60+; attacks enemy-faction players and monsters; leash 30, idle roam 20 around its banner; one guard per post walks a patrol route.
- Tiers: default tier normal; elite appears (see behaviour).
- Drops: war trophy 1/1 x1-2, heavy cloth 1/3.
- Kill quests today: r20_anchor_028_03 x3 L40 (r20_anchor_028_host, zone kragmar_blackwind_rise); r20_anchor_032_03 x3 L40 (r20_anchor_032_host, zone kragmar_bannerbreak_mesa); r20_anchor_036_03 x3 L40 (r20_anchor_036_host, zone kragmar_thunderroot_wilds).
- Design notes: Faction defender; kill target for enemy-faction PvP quests (three L40 quests per faction today). **Sub-types:** None (not a wildlife sub-type). **Constraints:** Loot only for enemy-faction killers. Display role guard: no fixed disposition entry.
- Look: character.b3d with grug_mobs_guard_throng.png plus grug_visuals armour.

### Kings and royal guards

Model: character.b3d.

**`grug_mobs:king_dwarf`** — King of Dur Brannoc (aggressive (king role), elite; mods/ENTITIES/grug_mobs/bosses.lua:518)  
- Where today: throne socket of the capital Dur Brannoc.
- Movement and senses: walk/run 1.2/4.6, view 18, reach 3, attack dogfight, chase end: drag leash 30 m.
- Behaviour: type npc with faction; elite tier at fixed level 65; signature every ~8 s after a 2 s cast: shatter: 6 m knockback slam x3; leash 30; resets the royal encounter on evade; reward: Fallen Crown plus boss gear to every enemy participant within 60 m, 24 h lockout per player.
- Tiers: default tier elite.
- Drops: none.
- Design notes: Faction king on the capital throne, attacked by enemy-faction players. **Sub-types:** None. **Constraints:** Faction NPC: only enemy-faction players get loot. Ruling 9 sets his final visual size to 1.6.
- Look: character.b3d with grug_mobs_royal_dwarf.png.

**`grug_mobs:king_elf`** — King of Lethariel (aggressive (king role), elite; mods/ENTITIES/grug_mobs/bosses.lua:518)  
- Where today: throne socket of the capital Lethariel.
- Movement and senses: walk/run 1.2/4.6, view 18, reach 3, attack dogshoot (arrow_entity, 3s), chase end: drag leash 30 m.
- Behaviour: type npc with faction; elite tier at fixed level 65; signature every ~8 s after a 2 s cast: volley: three arrows; leash 30; resets the royal encounter on evade; reward: Fallen Crown plus boss gear to every enemy participant within 60 m, 24 h lockout per player.
- Tiers: default tier elite.
- Drops: none.
- Design notes: Faction king on the capital throne, attacked by enemy-faction players. **Sub-types:** None. **Constraints:** Faction NPC: only enemy-faction players get loot. Ruling 9 sets his final visual size to 1.6.
- Look: character.b3d with grug_mobs_royal_elf.png.

**`grug_mobs:king_human`** — King of Highcourt (aggressive (king role), elite; mods/ENTITIES/grug_mobs/bosses.lua:518)  
- Where today: throne socket of the capital Highcourt.
- Movement and senses: walk/run 1.2/4.6, view 18, reach 3, attack dogfight, chase end: drag leash 30 m.
- Behaviour: type npc with faction; elite tier at fixed level 65; signature every ~8 s after a 2 s cast: rally: heals royal guards 20 % and pulls them in; leash 30; resets the royal encounter on evade; reward: Fallen Crown plus boss gear to every enemy participant within 60 m, 24 h lockout per player.
- Tiers: default tier elite.
- Drops: none.
- Design notes: Faction king on the capital throne, attacked by enemy-faction players. **Sub-types:** None. **Constraints:** Faction NPC: only enemy-faction players get loot. Ruling 9 sets his final visual size to 1.6.
- Look: character.b3d with grug_mobs_royal_human.png.

**`grug_mobs:king_orc`** — King of Gor Drazhak (aggressive (king role), elite; mods/ENTITIES/grug_mobs/bosses.lua:518)  
- Where today: throne socket of the capital Gor Drazhak.
- Movement and senses: walk/run 1.2/4.6, view 18, reach 3, attack dogfight, chase end: drag leash 30 m.
- Behaviour: type npc with faction; elite tier at fixed level 65; signature every ~8 s after a 2 s cast: cleave: 6 m frontal x3; leash 30; resets the royal encounter on evade; reward: Fallen Crown plus boss gear to every enemy participant within 60 m, 24 h lockout per player.
- Tiers: default tier elite.
- Drops: none.
- Design notes: Faction king on the capital throne, attacked by enemy-faction players. **Sub-types:** None. **Constraints:** Faction NPC: only enemy-faction players get loot. Ruling 9 sets his final visual size to 1.6.
- Look: character.b3d with grug_mobs_royal_orc.png.

**`grug_mobs:king_troll`** — King of Kezamba (aggressive (king role), elite; mods/ENTITIES/grug_mobs/bosses.lua:518)  
- Where today: throne socket of the capital Kezamba.
- Movement and senses: walk/run 1.2/4.6, view 18, reach 3, attack dogshoot (rock_entity, 3s), chase end: drag leash 30 m.
- Behaviour: type npc with faction; elite tier at fixed level 65; signature every ~8 s after a 2 s cast: regrowth: heals 20 % if not damaged during the wind-up; leash 30; resets the royal encounter on evade; reward: Fallen Crown plus boss gear to every enemy participant within 60 m, 24 h lockout per player.
- Tiers: default tier elite.
- Drops: none.
- Design notes: Faction king on the capital throne, attacked by enemy-faction players. **Sub-types:** None. **Constraints:** Faction NPC: only enemy-faction players get loot. Ruling 9 sets his final visual size to 1.6.
- Look: character.b3d with grug_mobs_royal_troll.png.

**`grug_mobs:king_undead`** — King of Nhal Veyr (aggressive (king role), elite; mods/ENTITIES/grug_mobs/bosses.lua:518)  
- Where today: throne socket of the capital Nhal Veyr.
- Movement and senses: walk/run 1.2/4.6, view 18, reach 3, attack dogshoot (rock_entity, 3s), chase end: drag leash 30 m.
- Behaviour: type npc with faction; elite tier at fixed level 65; signature every ~8 s after a 2 s cast: bone_call: summons two Skeleton Raiders; leash 30; resets the royal encounter on evade; reward: Fallen Crown plus boss gear to every enemy participant within 60 m, 24 h lockout per player.
- Tiers: default tier elite.
- Drops: none.
- Design notes: Faction king on the capital throne, attacked by enemy-faction players. **Sub-types:** None. **Constraints:** Faction NPC: only enemy-faction players get loot. Ruling 9 sets his final visual size to 1.6.
- Look: character.b3d with grug_mobs_royal_undead.png.

**`grug_mobs:royal_guard_dwarf`** — King of Dur Brannoc Royal Guard (guard role (no fixed disposition), elite; mods/ENTITIES/grug_mobs/bosses.lua:540)  
- Where today: the two throne guard sockets (west, east) of Dur Brannoc.
- Gates: level floor 20.
- Movement and senses: walk/run 1.2/4.6, view 14, reach 3, attack dogfight, chase end: no leash (own encounter rules).
- Behaviour: type npc, elite tier, fixed level 60; follows the king within 5 m, no leash.
- Tiers: default tier elite.
- Drops: war trophy 1/1 x1-2, heavy cloth 1/3.
- Design notes: Throne-room guard. **Sub-types:** None. **Constraints:** Faction NPC.
- Look: character.b3d with grug_mobs_royal_guard_dwarf.png.

**`grug_mobs:royal_guard_elf`** — King of Lethariel Royal Guard (guard role (no fixed disposition), elite; mods/ENTITIES/grug_mobs/bosses.lua:540)  
- Where today: the two throne guard sockets (west, east) of Lethariel.
- Gates: level floor 20.
- Movement and senses: walk/run 1.2/4.6, view 14, reach 3, attack dogfight, chase end: no leash (own encounter rules).
- Behaviour: type npc, elite tier, fixed level 60; follows the king within 5 m, no leash.
- Tiers: default tier elite.
- Drops: war trophy 1/1 x1-2, heavy cloth 1/3.
- Design notes: Throne-room guard. **Sub-types:** None. **Constraints:** Faction NPC.
- Look: character.b3d with grug_mobs_royal_guard_elf.png.

**`grug_mobs:royal_guard_human`** — King of Highcourt Royal Guard (guard role (no fixed disposition), elite; mods/ENTITIES/grug_mobs/bosses.lua:540)  
- Where today: the two throne guard sockets (west, east) of Highcourt.
- Gates: level floor 20.
- Movement and senses: walk/run 1.2/4.6, view 14, reach 3, attack dogfight, chase end: no leash (own encounter rules).
- Behaviour: type npc, elite tier, fixed level 60; follows the king within 5 m, no leash.
- Tiers: default tier elite.
- Drops: war trophy 1/1 x1-2, heavy cloth 1/3.
- Design notes: Throne-room guard. **Sub-types:** None. **Constraints:** Faction NPC.
- Look: character.b3d with grug_mobs_royal_guard_human.png.

**`grug_mobs:royal_guard_orc`** — King of Gor Drazhak Royal Guard (guard role (no fixed disposition), elite; mods/ENTITIES/grug_mobs/bosses.lua:540)  
- Where today: the two throne guard sockets (west, east) of Gor Drazhak.
- Gates: level floor 20.
- Movement and senses: walk/run 1.2/4.6, view 14, reach 3, attack dogfight, chase end: no leash (own encounter rules).
- Behaviour: type npc, elite tier, fixed level 60; follows the king within 5 m, no leash.
- Tiers: default tier elite.
- Drops: war trophy 1/1 x1-2, heavy cloth 1/3.
- Design notes: Throne-room guard. **Sub-types:** None. **Constraints:** Faction NPC.
- Look: character.b3d with grug_mobs_royal_guard_orc.png.

**`grug_mobs:royal_guard_troll`** — King of Kezamba Royal Guard (guard role (no fixed disposition), elite; mods/ENTITIES/grug_mobs/bosses.lua:540)  
- Where today: the two throne guard sockets (west, east) of Kezamba.
- Gates: level floor 20.
- Movement and senses: walk/run 1.2/4.6, view 14, reach 3, attack dogfight, chase end: no leash (own encounter rules).
- Behaviour: type npc, elite tier, fixed level 60; follows the king within 5 m, no leash.
- Tiers: default tier elite.
- Drops: war trophy 1/1 x1-2, heavy cloth 1/3.
- Design notes: Throne-room guard. **Sub-types:** None. **Constraints:** Faction NPC.
- Look: character.b3d with grug_mobs_royal_guard_troll.png.

**`grug_mobs:royal_guard_undead`** — King of Nhal Veyr Royal Guard (guard role (no fixed disposition), elite; mods/ENTITIES/grug_mobs/bosses.lua:540)  
- Where today: the two throne guard sockets (west, east) of Nhal Veyr.
- Gates: level floor 20.
- Movement and senses: walk/run 1.2/4.6, view 14, reach 3, attack dogfight, chase end: no leash (own encounter rules).
- Behaviour: type npc, elite tier, fixed level 60; follows the king within 5 m, no leash.
- Tiers: default tier elite.
- Drops: war trophy 1/1 x1-2, heavy cloth 1/3.
- Design notes: Throne-room guard. **Sub-types:** None. **Constraints:** Faction NPC.
- Look: character.b3d with grug_mobs_royal_guard_undead.png.


## 7. Quests that target mobs today

240 quests exist; kill objectives match the entity name and credit every
participant within 40 m. Start-zone kill quests have no zone filter ("any
zone"). Item objectives that ask for mob drops (raw meat, leather, fang,
stolen purse, linen cloth/scrap, venom sac, slime gel, croc tooth) are
listed per mob in `catalogue.json` (`quests.item_requests_for_its_drops`).

| Target | Kill quests | Levels | Givers / zone filter |
|---|---|---|---|
| `ashen_treant` | 1 | 31 | Ashenward March |
| `bandit` | 8 | 12, 12, 12, 12, 12, 12, 31, 31 | Copperfell Foothills; Glassroot Wilds; Goldmead Vale; Mournfen; Raincall Basin; Redtusk Savanna; Starbough Vale; Thunderroot Wilds |
| `bandit_archer` | 10 | 12, 12, 12, 12, 12, 12, 33, 33, 33, 33 | Ashenward March; Bannerbreak Mesa; Blackwind Rise; Copperfell Foothills; Goldmead Vale; Mournfen; Raincall Basin; Redtusk Savanna; Starbough Vale; Stormvault Heights |
| `blightfang_wolf` | 2 | 21, 23 | Ossuary Reach |
| `boar` | 4 | 1, 1, 1, 1 | r14_dwarf_elder (any zone); r14_elf_elder (any zone); r14_human_elder (any zone); r14_orc_elder (any zone) |
| `bog_ooze` | 4 | 10, 11, 23, 21 | Mournfen; Totemwater Reach; Whispering Reedlands |
| `crag_eagle` | 1 | 31 | Stormvault Heights |
| `crocodile` | 3 | 11, 21, 23 | Mournfen; Totemwater Reach; Whispering Reedlands |
| `fox` | 5 | 10, 5, 11, 10, 11 | Copperfell Foothills; Goldmead Vale; Starbough Vale; r14_elf_elder (any zone) |
| `frost_stray` | 1 | 31 | Stormvault Heights |
| `goblin_hound` | 1 | 11 | Copperfell Foothills |
| `goblin_raider` | 3 | 11, 23, 23 | Copperfell Foothills; Frostbarrow Shelf; Speargrass Reach |
| `goblin_slinger` | 2 | 11, 23 | Copperfell Foothills; Frostbarrow Shelf |
| `gravewood_treant` | 4 | 23, 21, 31, 21 | Blackwind Rise; Ossuary Reach |
| `guard_accord` | 3 | 40, 40, 40 | Ashenward March; Glassroot Wilds; Stormvault Heights |
| `guard_throng` | 3 | 40, 40, 40 | Bannerbreak Mesa; Blackwind Rise; Thunderroot Wilds |
| `hyena` | 3 | 10, 11, 21 | Redtusk Savanna; Speargrass Reach |
| `ibex` | 3 | 5, 11, 21 | Copperfell Foothills; Frostbarrow Shelf; r14_dwarf_elder (any zone) |
| `jungle_boar` | 1 | 1 | r14_troll_elder (any zone) |
| `jungle_lynx` | 2 | 11, 21 | Raincall Basin; Whispering Reedlands |
| `mountain_ram` | 1 | 21 | Frostbarrow Shelf |
| `plague_boar` | 2 | 1, 10 | Mournfen; r14_undead_elder (any zone) |
| `plaguehide_bear` | 1 | 31 | Blackwind Rise |
| `poacher` | 10 | 10, 11, 11, 21, 21, 21, 21, 23, 21, 21 | Goldmead Vale; Lorindor; Moonfall Wood; Starbough Vale; Whitebridge Shire |
| `scorpion` | 5 | 5, 11, 23, 31, 23 | Bannerbreak Mesa; Redtusk Savanna; Speargrass Reach; r14_orc_elder (any zone) |
| `skeleton_raider` | 2 | 31, 31 | Ashenward March; Bannerbreak Mesa |
| `snow_leopard` | 2 | 21, 23 | Frostbarrow Shelf |
| `speargrass_tiger` | 2 | 21, 21 | Speargrass Reach |
| `sun_dried_husk` | 1 | 5 | r14_orc_elder (any zone) |
| `tapir` | 2 | 10, 21 | Raincall Basin; Whispering Reedlands |
| `viper` | 3 | 5, 10, 11 | Raincall Basin; r14_troll_elder (any zone) |
| `wild_turkey` | 1 | 5 | r14_human_elder (any zone) |
| `wisp` | 7 | 23, 23, 23, 23, 23, 23, 23 | Lorindor; Whispering Reedlands; Whitebridge Shire |
| `wolf` | 1 | 21 | Moonfall Wood |
| `zombie` | 5 | 4, 4, 4, 4, 4 | r14_dwarf_elder (any zone); r14_elf_elder (any zone); r14_human_elder (any zone); r14_troll_elder (any zone); r14_undead_elder (any zone) |

Notes: one quest targets a critter (Wild Turkey); six quests ask enemy
players to kill faction guards (L40); no current quest targets Mirefolk,
cave mobs, golems, the War Construct, Rift Spawn, Bog Witch, Panther,
Serpent, Bear, Stag, Zebra or any 41-60 zone mob.

## 8. Bosses, guards and peaceful NPCs

- **Dragons** (`ice_dragon` on The Wyrmglass Crown, `jungle_wyvern` on
  Stormscale Summit): boss tier, level 70, ground/flight switching, breath
  with a temporary ground effect, dive slam, gust, lightning (wyvern),
  enrage at 50 % HP that summons whelps (`ice_whelp`, `storm_whelp`,
  level 20). Respawn 30 min, loot lockout 24 h.
- **Kings** (`king_<race>`) on the capital thrones, each with two
  **royal guards** (`royal_guard_<race>`, throne sockets west and east):
  faction NPCs, elite, level 65 / 60; each king has one signature
  (shatter, rally, volley, bone call, cleave, regrowth) after a 2 s cast.
  Only enemy-faction players fight them and get loot (Fallen Crown plus
  boss gear, 24 h lockout).
- **Faction guards** (`guard_accord`, `guard_throng`): outposts (2-3 per
  banner, refill 180-360 s), start-town posts and patrols; level from the
  guard field (20-70), elite from 60. Kill targets of six PvP quests.
- **Peaceful NPCs** (never attacked by anything, not combat targets):
  `grug_mobs:villager_<race>` and `grug_mobs:elder_<race>` for the six
  races, and the vendors `grug_traders:vendor_general_<faction>`,
  `grug_traders:vendor_race_<race>`, `grug_traders:vendor_<kind>`.

## 9. Not determined here

- **Exact spawn counts per area** depend on terrain (host nodes, light,
  player positions); the density numbers above are budgets, not measured
  populations. Lane E2 measures reachability.
- **Rare route waypoints** come from `grug_core.rare_route` at runtime; only
  the anchor zone is listed.
- **Effect of the Section A rulings** (knockback, separation, push away from
  roads) on each family's feel is not known until those lanes merge.
