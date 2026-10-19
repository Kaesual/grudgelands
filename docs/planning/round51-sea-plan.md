# Partial plan — Round 51, sea

Draft, 2026-10-19. One of the two partial plans of Round 51; the other one
covers the land ([round51-land-plan.md](round51-land-plan.md)). A round
coordinator merges both into the round plan. Land and sea share one map
reset. **No lane starts from this file.**

## 1. Goal

The sea should read and play like natural water: a light coast, a living
coastal belt and bays, a dark and dangerous open sea. Today the map shows the
dragon channels as dark rectangles and the bays in lake colour, the bays hold
specks of open sea, the seabed is mostly bare and no mob lives at the coasts.

Preview page (offline renders with the real map renderer, the user's
production seed `3464175725660475642`, before / colour only / simulated
belt and channels, the tortoise model):
<https://claude.ai/artifact/EEJxLmxsb4QsfcgvoR1bvW>

## 2. Findings (measured 2026-10-18 on the production seed)

1. **The map colours water by its logical class**, not by depth
   (`grug_map/base.lua` `WATER`). The two dragon channels are rectangles
   (`channel_wyrmglass` x −2850..−2500, `channel_stormscale` x 2500..2860,
   z ±350) and are drawn darker than the deep ocean. Their seabed is already
   organic (`height.lua` boat water: a smooth minimum plus noise, at least
   nine nodes of water), but the middle drops to about −30.
2. **Bays are `planned_water`**, the class of lakes, hence the lake colour.
   `simple_map.lua` `classification_values_at` tests a column against the
   bay's warped body, then the 80-node shelf ring (`shelf_width`); a column
   in neither falls through to `deep_ocean`. That leaves open-sea specks at
   bay rims (west rim of `bay_kragmar_west` on the production seed; the
   user's world "test" at −1082, 1858). Such a speck has no mob level, is
   immutable ground and lets the Kraken spawn next to a start area. The bay
   mouth is cut on a straight line (`deep_ocean_cut_z`).
3. **Depths.** The shelf reaches about −13 at 80–100 nodes off the coast,
   then falls to the deep sea (`terrain_field.lua` `with_coast`,
   `SHELF_EDGE = 70`). Bay middles are −30 to −33, channel middles down to
   −30.
4. **Seabed growth.** Reef patches and kelp grow only on the coastal shelf
   and in bays at water depth 2–10 (`world_content.lua`). Channels are a
   claim exclusion (`exclude_coast_v1` on the channel polygon) and stay bare;
   most of a bay floor is too deep.
5. **World bounds.** The land reaches z −3180 (the elf land tongue in the
   south-east) against the atlas edge −3200 and the zone bounds −3340. A
   wider belt would be cut there. The bounds are hard-coded in about ten
   places (`zones.lua`, `height.lua`, `simple_map.lua` query bounds,
   `world_protection.lua`, `r6_planner.lua`, `r6_settlement.lua`,
   `r7_p9g.lua`, `terrain_data.lua` grids, `grug_core/preparation_plan.lua`,
   `grug_map/atlas.lua`, `base.lua` qualities). Land shapes use absolute
   coordinates, so enlarging the bounds adds sea and moves no land.
6. **Cold coasts are rare.** `grug_crags_snowy` (the alpine biome) is 2.2 %
   of the coastal land columns, almost all on The Wyrmglass Crown and a few
   on Stormvault Heights. Frostbarrow Shelf, the frost-themed dwarf zone, has
   crags and pine hills at its coast, no snow.
7. **The Kraken spawns** (the user met it in game, 2026-10-18). Its spawn
   needs the water surface inside the active blocks around a player, so a
   player flying high above the sea never meets one.
8. **Map render cost** stays the same with depth colouring (the relief pass
   already samples the terrain height): about 10–12 s for the whole map at
   normal quality offline.

## 3. Rulings (the user, 2026-10-18 and 2026-10-19)

**Map**

1. **Sea colour by depth**, in three steps: light at the coast, a middle blue
   for bays, the coastal belt and the channels, a clearly darker blue only in
   the open sea, with a soft edge. Lakes and rivers keep their colour.
2. **The map grows by a few hundred nodes in every direction** (room for the
   belt): atlas ±4050 × ±3600 (9:8 like today), zone bounds and grids
   widened by the same amount.
3. **Map qualities** (the user, 2026-10-19): normal goes up to 1215 × 1080
   (today's 6.67 nodes per pixel); high stays at 3600 × 3200 px (today's
   pixel count, 2.25 instead of 2 nodes per pixel).

**Sea and world**

4. **Fix the classification**: no open-sea columns inside or at the rim of a
   bay; the bay-to-open-sea edge is organic, not a straight cut. Needed for
   clean mob spawns too.
5. **A wider coastal belt**: the open sea begins about 250–350 nodes off the
   coast (rough target). The belt belongs to the zone on land (level,
   faction, PvP rule) as the shelf does today.
6. **Dragon channels**: organic shallow water 9–11 nodes deep (boats need
   nine). A channel takes the **mob level of its island**.
7. **Seabed growth** in the shelf, the bay rims, the belt and the channels:
   coral patches to about 10 nodes deep, kelp meadows deeper (about 20), and
   a new low **seagrass** node. The deep sea stays bare.
8. **Deeper water is protected**: bay and belt water **24 nodes or more from
   the coast** is immutable like the open sea (no building, no mining, the
   seabed included, no Claim Stones). The shore stays alterable. The border
   uses the coast distance, not the water depth.
9. **No new islets** (the user, 2026-10-19). **Shipwrecks as decoration come
   in this round** (ruling 20).

**Water mobs**

10. **Near land only mobs that can follow a player ashore** (frogs, otters,
    crabs, tortoises and the like). Pure swimmers spawn only in deeper water
    away from land, so nobody fights a swimmer from the bank that cannot
    answer. Critter fish may swim anywhere, for atmosphere. Rough values:
    "near land" is up to about 16 nodes from dry land or about 6–8 nodes of
    water depth.
11. **A pure swimmer whose target is out of the water** (not in water, not on
    a boat) resets: it forgets the fight, heals to full and swims off toward
    deeper water (the existing leash reset and evade, `grug_mobs/aggro.lua`).
12. **Start-zone coasts match the zone level**; the deep middle of a bay may
    be deadly for new players. **Bay Shark**: a fixed level 30, normal tier.
13. **Elites in water only in the open sea and as rares.** The Kraken stays
    the open-sea guard; an **Abyssal Shark** (a shark scaled two to three
    times) joins it there.
14. **Water mobs give normal XP and fish loot**, critter fish included.
15. **Tortoise: a neutral beast** (bites back when attacked, normal XP and
    loot, zone level) on shores **and at lakes**. A sea turtle with flippers
    is a later art job; no reference project has one.
16. **No seals and no cold coasts** for now (2026-10-19: not worth it yet;
    snowy coasts are 2.2 % of the coast, §2.6).
17. **Quest-ready from the start** (2026-10-19): the water mobs are built so
    that a later quest round can make them kill targets without a rework
    round. The contract is §5.
18. **Water is a complement, not a second land** (2026-10-19): fewer families
    and less depth than on land; what matters is that each mob's level fits
    its zone. The NAMES lane drafts the families and their level ladders and
    shows them to the user as an artifact.
19. **Underwater POIs** that quests can use come later, with the planned
    quest and POI rework.
20. **Shipwrecks** (2026-10-19): decoration only, this round, a simple
    design of our own from full blocks only, masts and small details by the
    rooted-plant drawtype (§5a); the user picks on a preview page.

## 4. Mob candidates (input for the NAMES lane)

The candidates found in the reference projects, by habitat. Ruling 18 asks
for fewer families than on land: the NAMES lane picks from this list and
drafts the families and their ladders for the user. Sources: animalworld (mobs_redo API like ours, MIT media, already vendored for
the crab and the crocodile) unless marked VL (VoxeLibre: GPLv3 models, CC
BY-SA textures). Sounds stay silent until the user picks them on a listening
page.

| Habitat | Mobs | Level |
|---|---|---|
| Start-zone shore and bay rim | hermit crab, crab ladder (exists), tortoise, frog, otter; critter fish: goby, seahorse | zone level |
| Other shores | crab ladder (exists), tortoise | zone level |
| Shelf and belt, away from land | stingray, lobster, manatee in kelp, tropical fish (VL) at reefs, salmon (VL) at river mouths, dolphin groups (VL), cod schools (VL), squid (Kraken mesh, small) | zone level |
| Deep bay middle | Bay Shark | fixed 30, normal |
| Channels | reef fish, manatee, stingray | island level |
| Open sea | Kraken (exists), Abyssal Shark (seldom spawn) | fixed, elite |
| Open sea, night or deep | glow squid (VL) | critter |
| Lakes and rivers | Reed Angelfish (exists), carp, trout (rivers), frog, otter, tortoise, beaver; nymph, diving beetle as critters; hippo in jungle and swamp lakes; Crocodile (exists) in the swamp | zone level |
| Cave water | olm | critter |

## 5. Quest-ready contract (ruling 17)

The Round 38 name guarantee ([quests.md](../design/quests.md#the-quest-name-guarantee-round-38),
[biomes_mobs.md](../design/biomes_mobs.md) "Names") already makes a mob's
shown name the exact kill target. The crabs show the pattern the water mobs
follow: one family (`crab`, base `grug_mobs:shore_crab`) split into authored
sub-types by level band (`subtypes.json`: quiet shore crab L3–6, giant crab
L7–10, tidepool L11–14, reefclaw L15–17, bank L21–24, armored L25–30,
breakwater L34–40, salt reef lurker L51–59), spawned as a `shore` kind of
each zone's spawn recipe (`data/zones/<zone>.spawns.json`), and named per
slot `<zone>/<role>/L<lo>-<hi>` in `names.json`. Every new water mob meets
the same contract:

1. **A family with a level ladder.** A water mob that lives in zone water
   (shore, bay, belt, channel, lake, river) is a family of sub-types, one per
   level stretch inside one drop tier, so no name crosses a tier (naming rule
   4). Its slots are zone slots.
2. **Zone recipes, not independent rows.** It spawns from a kind of its
   zone's spawn recipe, so a quest may name it with or without an area
   (`zone/kind`) and the load-time recipe check (W-recipe-target) stays
   quiet. The spawn regions need water kinds for that (hosts by water band:
   distance to dry land and depth, §3 rulings 10–12); a design question for
   the MOBS lane.
3. **Fixed-level mobs are world slots** with one level (Bay Shark L30, the
   Abyssal Shark, the Kraken), so one name means one level everywhere.
4. **Critters are never kill targets** (quests.md Ruling 29); their fish
   loot still counts for item objectives, which name items, not mobs.
5. **The gates pass:** `tools/r38_names/check_rules.py --shipped`,
   `tools/r38_names/guarantee.py --check`, `tools/r38_b1/gen_names.py --check`.
6. **Names are accepted by the user** on a preview page before they ship,
   as in Round 38.

## 5a. Shipwrecks

**Why full blocks only.** Water draws its side and top faces against every
neighbour that is not a full opaque cube (`content_mapblock.cpp`
`drawLiquidSides`: a face is skipped only for the same liquid or a neighbour
of solidness 2, which only the `normal` and `plantlike_rooted` drawtypes
have, `node_visuals.cpp`). A stair, slab, fence, trapdoor or door under water
therefore shows a "wall" of water around it and an air pocket above it, as
VoxeLibre's wrecks do. A full block with painted-on water would avoid the
wall but must be opaque (a see-through part shows the void, the engine culls
what lies behind a full block); the user rejected it (2026-10-19).

**Rulings (the user, 2026-10-19):**

1. Wrecks are built **from full blocks only** and kept simple: planks, logs
   for keel and ribs, and wreck nodes of their own (for example
   "Waterlogged Planks", with an algae variant) that **drop the ordinary
   wood** when dug.
2. **Masts and small details use the rooted-plant drawtype**
   (`plantlike_rooted`, the kelp and coral mechanism, "underwater plantlike
   without air bubbles"): a full base cube on the deck with a plantlike
   extension in the real water above. With `paramtype2 = "leveled"` a mast's
   height is `param2 / 16` nodes (up to almost 16), its texture repeats
   upward like kelp; a mast reaching above the surface shows in the air too.
   Details the same way: rope ends, algae, sail tatters on single planks.
3. **Our own design**, not a port of the VoxeLibre wrecks: their hull shape
   relies on stairs and slabs and would not survive the full-block rule.
   They may serve as a shape reference (`reference_projects/VoxeLibre/mods/
   MAPGEN/mcl_structures/schematics/mcl_structures_shipwreck_*.mts`, five
   wrecks 16–28 nodes long).

**Limits of the rooted extension**, accepted for decoration: it is two
crossed quads (an X seen from above); a tall one stands only upright (a
sideways extension is one node long, so a fallen mast on the seabed is made
of full logs); no yard or crow's nest (the texture repeats over the whole
height); no collision (players and boats pass through) and it is not dug on
its own (it belongs to its base).

**Shapes and placement:**

- two to four shapes: a whole hull, a bow part, a stern part, a debris field;
  turned and partly sunk into the sand;
- on the seabed of the coastal belt and the bays, in the protected water
  (ruling 8), so nobody takes them apart for wood; a few per coast;
- the textures (mast, rope, sail tatters, waterlogged planks) are a small
  ART job with a pick page;
- the WRECK lane shows the designs on a preview page before they ship; its
  first in-game test is a mast on a test wreck;
- the placement is part of the one map reset.

## 6. Checks for the build lanes

1. **Amphibian navigation**: our navigation targets land mobs; whether frogs
   and otters chase cleanly through water onto the shore is to be tested by
   the mob lane.
2. **Gathering in protected water**: check whether sea-floor gathering nodes
   (Stormkelp) stay harvestable inside the new protected water.

## 7. Lane sketch (for the coordinator)

- **MAP** (no reset of its own): depth colouring, the larger atlas, the
  qualities. Bays and lakes need a proper query to tell them apart (both are
  `planned_water`; the preview used the floor height as a stand-in).
- **SEA** (map reset): world bounds, classification fix, coastal belt,
  shallow organic channels and their level, seabed growth with the seagrass
  node, protected deep water.
- **MOBS**: ports and spawn rules by water band (distance to land, depth),
  water kinds in the zone spawn recipes, the swimmer reset, Bay Shark and
  Abyssal Shark, fish loot; the quest-ready contract (§5).
- **NAMES** (design, before MOBS fills `names.json`): the families' level
  ladders per zone and their names, on a preview page for the user.
- **WRECK**: the shipwreck design and wreck nodes (§5a), its preview page
  and its placement in the SEA lane's water.
- **ART**: seagrass texture; wreck textures (mast, rope, sail tatters,
  waterlogged planks); later the sea turtle.
- **Later**: underwater POIs for quests (with the quest and POI rework).
