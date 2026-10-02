# Blackwind Rise (`kragmar_blackwind_rise`)

Zone 21 · contested 31-40 · contested · race region **undead** · levels **31-40** · contested · relief `highland` · seed 42

Map: [maps/kragmar_blackwind_rise.png](maps/kragmar_blackwind_rise.png). Machine-readable: [kragmar_blackwind_rise.json](kragmar_blackwind_rise.json). Coordinates are world nodes (x east, z north, y up).

Race track (undead): step 5 of the track Stillgrave Hollow → Mournfen → Nhal Veyr → Ossuary Reach → Blackwind Rise.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2440..-904, z 240..1156 (centroid -1678, 713) |
| Land area | 857488 nodes² (≈ 0.86 km²) |
| Hub point (authored) | -1800, 700 |
| Height above sea | min 0, p10 93, median 164, p90 265, max 372 |
| Slope | 58.0% steep (>1 node/node), 21.9% cliff (>2) |
| Biomes (measured) | bone_forest 74.9%, blight 24.3%, badlands 0.4%, meadows 0.2%, beach 0.1%, savanna 0.1%, deep_forest 0.1% |
| Neighbours (land border) | front_broken_causeway (420 nodes, mid -1073,485), front_gravesalt_escarpment (1328 nodes, mid -1850,336), kragmar_bannerbreak_mesa (488 nodes, mid -916,728), kragmar_nhal_veyr (892 nodes, mid -1691,1077), kragmar_ossuary_reach (504 nodes, mid -2212,1074), kragmar_speargrass_reach (476 nodes, mid -1149,1028) |
| Sea coast | 1436 nodes of coastline; sea-beach sand 3056 nodes²; lake/river-bank sand 7312 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 115504 nodes² |
| Protected / drift band | 1.0% of land protected (towns, villages, camps/POIs, road corridors); 4.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -2363, 1003 | x -2396..-2328, z 964..1040 | 2800 | L31-32 |
| B2 | -2432, 360 | x -2440..-2428, z 352..368 | 144 | L40 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 12.1%, L32 11.6%, L33 10.7%, L34 11.6%, L35 12.9%, L36 14.1%, L37 10.3%, L38 7.9%, L39 4.3%, L40 4.5%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_039 | outpost | Ashveil Watch | -2018 | 107 | 834 | 33 | poi x -2026..-2011, z 826..841 |
| anchor_040 | outpost | Hollowarch Station | -1468 | 99 | 554 | 37 | poi x -1476..-1461, z 546..561 |
| anchor_056 | bandit hideout | Pallcloth Den | -1800 | 300 | 550 | 37 | camp x -1808..-1793, z 542..557 |
| anchor_095 | rare route | Marrowclaw's Scrape | -1818 | 151 | 724 | 35 | poi x -1824..-1813, z 718..729 |

## Protected areas

- poi Ashveil Watch (anchor_039): x -2026..-2011, z 826..841
- poi Hollowarch Station (anchor_040): x -1476..-1461, z 546..561
- camp Pallcloth Den (anchor_056): x -1808..-1793, z 542..557
- poi Marrowclaw's Scrape (anchor_095): x -1824..-1813, z 718..729
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Ashveil Watch (`r20_anchor_039`, anchor_039) at -2018, 107, 834

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Vaska Ashlistener | -2016, 108, 834 | blackwind_ashes_01, blackwind_ashes_02, blackwind_ashes_03, blackwind_ashes_04, blackwind_ashes_bounty, bw_front_ashveil_01, bw_front_ashveil_02, bw_front_ashveil_03, bw_front_ashveil_04, bw_front_ashveil_05, bw_front_ashveil_bounty |

Distances: zone edge N 284 (kragmar_nhal_veyr), S 576 (front_gravesalt_escarpment), E 1096 (kragmar_bannerbreak_mesa), W 236 (coastal_shelf); nearest other-zone land 252 NE; sea 227 W; sea-beach sand 267 W; nearest road 11.
Nearest hubs (straight / by road): Red Ramp Post 1644 / 4043; Tornstandard Hold 2307 / 4476; Hollowarch Station 617 / 5434; Last Hedge Redoubt 2710 / 5708; Thunderstep Watch 3921 / 6312.

### Hollowarch Station (`r20_anchor_040`, anchor_040) at -1468, 99, 554

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Orrel Hollowstep | -1466, 100, 554 | blackwind_arch_01, blackwind_arch_02, blackwind_arch_03, blackwind_arch_bounty, blackwind_arch_group, bw_front_hollow_01, bw_front_hollow_02, bw_front_hollow_03, bw_front_hollow_04, bw_front_hollow_05, bw_front_hollow_06, bw_front_hollow_bounty |

Distances: zone edge N 548 (kragmar_nhal_veyr), S 136 (front_gravesalt_escarpment), E 544 (kragmar_bannerbreak_mesa), W 936 (coastal_shelf); nearest other-zone land 138 S; sea 817 W; sea-beach sand 835 W; nearest road 13.
Nearest hubs (straight / by road): Red Ramp Post 1140 / 1520; Tornstandard Hold 1744 / 3094; Last Hedge Redoubt 2095 / 4326; Thunderstep Watch 3370 / 5327; Ashveil Watch 617 / 5434.

### Current quests (23, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| blackwind_ashes_01 | Bad News Travels on Legs | Vaska Ashlistener (Ashveil Watch) | 29 | kill 4 territorial_bear [in kragmar_blackwind_rise/bonewood] | 630 | - |
| blackwind_ashes_02 | Trees Without Leave | Vaska Ashlistener (Ashveil Watch) | 31 | kill 4 mourning_treant [in kragmar_blackwind_rise/bonewood]; bring 2 grug_mobs:bitter_resin | 740 | blackwind_ashes_01 |
| blackwind_ashes_03 | Still Standing, Still Dead | Vaska Ashlistener (Ashveil Watch) | 32 | talk to Drek Rampbinder (r20_anchor_043) | 285 | blackwind_ashes_02 |
| blackwind_ashes_bounty | Bounty: A Recurring Appetite (repeatable) | Vaska Ashlistener (Ashveil Watch) | 32 | kill 6 territorial_bear [in kragmar_blackwind_rise/bonewood] | 380 | blackwind_ashes_02 |
| blackwind_arch_01 | Crates Before Glory | Orrel Hollowstep (Hollowarch Station) | 33 | kill 4 marrow_weevil [in kragmar_blackwind_rise/webwood] | 700 | - |
| blackwind_ashes_04 | Orrel Is Still Waiting | Vaska Ashlistener (Ashveil Watch) | 33 | talk to Orrel Hollowstep (r20_anchor_040) | 293 | blackwind_ashes_02 |
| blackwind_arch_02 | An End to the Brokerage | Orrel Hollowstep (Hollowarch Station) | 35 | kill 4 entrenched_bandit or entrenched_bandit_archer [in kragmar_blackwind_rise/bandit_hideout]; kill 1 grave_broker_mute | 1025 | blackwind_arch_01 |
| blackwind_arch_03 | An Answer for Pallcloth Den | Orrel Hollowstep (Hollowarch Station) | 37 | kill 4 entrenched_bandit_archer [in kragmar_blackwind_rise/pallcloth_den] | 753 | blackwind_arch_02 |
| blackwind_arch_bounty | Bounty: Threads Across the Supply Line (repeatable) | Orrel Hollowstep (Hollowarch Station) | 37 | kill 6 grave_web_spider [in kragmar_blackwind_rise/hollowwood] | 440 | blackwind_arch_03 |
| blackwind_arch_group | Group: Silence for Hollowbell | Orrel Hollowstep (Hollowarch Station) | 38 | kill 1 hollowbell_treant | 880 | blackwind_arch_03 |
| bw_front_hollow_01 | No Names Left to Call | Orrel Hollowstep (Hollowarch Station) | 47 | kill 5 causeway_mire_husk [in front_broken_causeway/toll_fields] | 945 | - |
| bw_front_hollow_02 | A Fare for Nobody | Orrel Hollowstep (Hollowarch Station) | 47 | kill 5 causeway_ford_zombie [in front_broken_causeway/last_ford] | 945 | - |
| bw_front_hollow_03 | Group: Close the Account | Orrel Hollowstep (Hollowarch Station) | 48 | kill 1 last_toll_construct | 1100 | bw_front_hollow_01 |
| bw_front_hollow_04 | The Dead Are Not Rations | Orrel Hollowstep (Hollowarch Station) | 50 | kill 5 saltpack_wolf [in front_gravesalt_escarpment/bonewood] | 1140 | - |
| bw_front_hollow_05 | The Owners Still Object | Orrel Hollowstep (Hollowarch Station) | 51 | kill 5 saltroad_deserter [in front_gravesalt_escarpment/tomb_galleries] | 1140 | bw_front_hollow_04 |
| bw_front_hollow_06 | Someone Who Listens | Orrel Hollowstep (Hollowarch Station) | 52 | talk to Vaska Ashlistener (r20_anchor_039) | 290 | bw_front_hollow_05 |
| bw_front_hollow_bounty | Bounty: Premature Shrouds (repeatable) | Orrel Hollowstep (Hollowarch Station) | 52 | kill 5 salt_web_spider [in front_gravesalt_escarpment/bonewood] | 725 | bw_front_hollow_05 |
| bw_front_ashveil_01 | What the Salt Holds | Vaska Ashlistener (Ashveil Watch) | 53 | kill 5 saltbound_husk [in front_gravesalt_escarpment/tomb_fen] | 1200 | - |
| bw_front_ashveil_02 | Let Me Have the Last Word | Vaska Ashlistener (Ashveil Watch) | 53 | kill 4 salt_hex_witch [in front_gravesalt_escarpment/tomb_fen]; bring 2 grug_mobs:last_hex_shard | 1500 | - |
| bw_front_ashveil_03 | Relief Long Overdue | Vaska Ashlistener (Ashveil Watch) | 57 | kill 5 last_watch_husk [in front_gravesalt_escarpment/whitewall] | 1260 | bw_front_ashveil_01 |
| bw_front_ashveil_04 | Dismissed, Captain | Vaska Ashlistener (Ashveil Watch) | 57 | kill 4 last_watch_skeleton_raider [in front_gravesalt_escarpment/ossuary_wood]; kill 1 watch_captain_huskell | 2080 | bw_front_ashveil_02, bw_front_ashveil_03 |
| bw_front_ashveil_bounty | Bounty: A Patient Listener (repeatable) | Vaska Ashlistener (Ashveil Watch) | 57 | kill 5 last_watch_skeleton_raider [in front_gravesalt_escarpment/ossuary_wood]; bring 2 grug_mobs:unquiet_bone | 945 | bw_front_ashveil_04 |
| bw_front_ashveil_05 | Group: Nobody's Number | Vaska Ashlistener (Ashveil Watch) | 58 | kill 1 salt_counter_witch | 1300 | bw_front_ashveil_04 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| breakwater_crab | Breakwater Crab | aggressive | 0.8% of land, L34-37 | - |  |
| briarpack_wolf | Briarpack Wolf | aggressive | 73.8% of land, L31-40 | 3.0% of land, L31-33 |  |
| entrenched_bandit | Entrenched Bandit | aggressive | 1.1% of land, L34-35 | 1.1% of land, L34-35 |  |
| entrenched_bandit_archer | Entrenched Bandit Archer | aggressive | 2.4% of land, L36-40 | 2.4% of land, L36-40 |  |
| grave_web_spider | Grave-Web Bonelurker Spider | aggressive | - | 75.3% of land, L31-40 |  |
| gull | Gull | critter | 1152 nodes² | - | sand |
| march_skeleton_raider | March Skeleton Raider | aggressive | - | 44.6% of land, L31-37 |  |
| marching_husk | Marching Sun-Dried Husk | aggressive | 3.0% of land, L31-33 | - |  |
| marching_zombie | Marching Zombie | aggressive | - | 5.1% of land, L31-35 |  |
| marrow_weevil | Marrow Weevil | aggressive | 75.3% of land, L31-40 | - |  |
| mourning_treant | Lichen Gravewood Treant | aggressive | - | 18.7% of land, L31-33 |  |
| shore_crab | Shore Crab | neutral | 3056 nodes², L31-40 | 3056 nodes², L31-40 | sand (dry, within 6 nodes of water) |
| territorial_bear | Bramble Bear | aggressive | 18.7% of land, L31-33 | - |  |
| unrelenting_zombie | Trench Shambler | aggressive | - | 2.1% of land, L36-37 |  |
| watchful_stag | Greatwood Stag | neutral | 4.3% of land, L31-37 | - |  |

**Camps and guard posts:**

- anchor_039 Ashveil Watch at -2018, 834: guard post, guard_throng × 2-3, respawn 180-360 s, level there L33.
- anchor_040 Hollowarch Station at -1468, 554: guard post, guard_throng × 2-3, respawn 180-360 s, level there L37.
- anchor_056 Pallcloth Den at -1800, 550: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L37.

**Rares (knowledge rewards, not quest targets):** Marrowclaw (plaguehide_bear, the bone forest, route -1866,700 → -1802,764 → -1762,708, L35, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 26 | secondary | anchor_039 (Ashveil Watch, kragmar_blackwind_rise) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 584 / 436 | -2007,823 → -2024,1117 |
| 43 | trail | anchor_040 (Hollowarch Station, kragmar_blackwind_rise) | joins road 27 | 1445 / 494 | -1458,562 → -1005,515 |
| 57 | trail | anchor_056 (Pallcloth Den, kragmar_blackwind_rise) | joins road 29 | 2074 / 436 | -1789,544 → -1427,416 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

