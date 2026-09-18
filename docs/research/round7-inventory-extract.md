# Round 7 current-game inventory extract

Evidence snapshot for the R7-MOB and R7-COOK planning tasks, taken from this
branch on 2026-09-18. This document records registrations and decided text; it
does not choose candidates or add design rules. Line references are repository
paths on this branch.

## 1. Current mob roster

### 1.1 Reading keys

The wrapper records each ordinary definition for positional `mob_level_at`
unless a definition selects the guard source, a fixed level or the fixed L1
`critter` tier (`mods/ENTITIES/grug_mobs/levels.lua:497-539`; wrapper call at
`mods/ENTITIES/grug_mobs/init.lua:470-480`). In the tables below:

- `field` means `grug_zones.mob_level_at`, normally floor 1; `field ≥10` and
  `field ≥3` name explicit definition floors.
- `critter L1`, `elite field`, `guard ≥20`, and `fixed L100` are the other
  literal paths.
- Palette zone IDs are derived from the closed zone and mob tables at
  `mods/ENTITIES/grug_mobs/spawn_policy.lua:14-108`. Surface admission requires
  both that palette and the mob's node whitelist; caves are the closed six-name
  set below y=-40 (`spawn_policy.lua:116-126,264-306`).
- `day`, `night`, and `24 h` describe the registered light/time rows. Flying
  means `fly=true`; the Kraken flies in water. The crocodile remains a ground
  mover whose definition supplies swim animation and floating behavior, not
  mobs_redo's `fly` mode (`mods/ENTITIES/grug_mobs/crocodile.lua:14-44`).

Media keys quote `mods/ENTITIES/grug_mobs/LICENSE-media.md`:

| Key | Source and licence evidence |
|---|---|
| VL | VoxeLibre `mobs_mc`: models “licensed under GPLv3”; mob textures default to CC BY-SA 4.0 (`LICENSE-media.md:55-63,83-92`); exact imported files are listed at `:69-81,96-115`. |
| LotT | Lord of the Test humanoid skins: named authors and CC BY-SA 3.0 (`LICENSE-media.md:130-147`); `character.b3d` is the player_api mesh, identified as CC BY-SA 3.0 at `:315-317`. |
| AW | animalworld models/textures/animation: “under (MIT) License (c) 2022”; no sounds imported (`LICENSE-media.md:151-180`). |
| AN | animalia repo-wide MIT; no separate media licence was found (`LICENSE-media.md:184-202`). |
| MM | mobs_monster: spider mesh/textures CC BY-SA 3.0; golem mesh WTFPL; golem textures CC0 (`LICENSE-media.md:206-226`). |
| GRUG | Original Mirefolk texture CC0 and `character.b3d` as above (`LICENSE-media.md:230-236,315-317`). |

### 1.2 Registered combat, wildlife and guard definitions

All 43 literal `grug_mobs.register_mob` calls are included. `S` below denotes
the settled zones 1,2,6,7,9,11,12,17,18,22,23,27,28; `F` forest zones
9,10,15,16,20,21,34; `M` mountain zones 4,5,25,26,33,36; `J` jungle zones
16,32,37,38; `E` jungle-edge zones 27,28,30,31; `W` swamp zones 18,30,31;
`B` war zones 10,26,33-38. Zone 14 additionally admits only the Stag by exact
name (`spawn_policy.lua:14-60`).

| Registered name; definition | Role | Spawn authority / habitat | Level source | Movement; attack | Media |
|---|---|---|---|---|---|
| `bandit` — `bandit.lua:168` | 24 h camp enemy | authored bandit camps (`camps.lua:800-808`) | field | ground; melee | LotT |
| `bandit_archer` — `bandit_archer.lua:88` | 24 h camp enemy | authored bandit camps (`camps.lua:800-808`) | field | ground; ranged `arrow_entity` (`bandit_archer.lua:62-63`) | LotT |
| `bear` — `bear.lua:97` | day | F | field | ground; melee | VL |
| `plaguehide_bear` — `bear.lua:140` | day | F, Throng-side variant | field | ground; melee | VL |
| `boar` — `boar.lua:91` | day | S | field | ground; melee | VL |
| `plague_boar` — `boar_variants.lua:78` | day | S, Throng-side variant | field | ground; melee | VL |
| `jungle_boar` — `boar_variants.lua:109` | day | S, troll-region variant | field | ground; melee | VL |
| `bog_fowl` — `bog_fowl.lua:76` | day critter | W | critter L1 | ground; passive/runaway | VL |
| `bog_ooze` — `bog_ooze.lua:84` | 24 h | W | field | ground; melee | VL |
| `bone_weevil` — `bone_weevil.lua:79` | day critter | F | critter L1 | ground; passive/runaway | VL |
| `carrion_crow` — `carrion_crow.lua:102` | day | B | field | flying air; melee | AN |
| `cave_bat` — `cave_bat.lua:82` | dark cave critter | underground below -40 | critter L1 | flying air; passive/runaway | VL |
| `cave_crawler` — `cave_crawler.lua:67` | dark cave critter | underground below -40 | critter L1 | ground; passive/runaway | VL |
| `crocodile` — `crocodile.lua:103` | 24 h | W | field | ground/amphibious; melee | AW |
| `crag_eagle` — `eagle.lua:115` | day | M | field | flying air; melee | AW |
| `vulture` — `eagle.lua:148` | day | M | field | flying air; melee | AW |
| `stone_golem` — `golem.lua:169` | 24 h; cave | M and underground | elite field | ground; ranged rocks (`golem.lua:51-68`) | MM |
| `mesa_golem` — `golem.lua:219` | 24 h; cave | M and underground | elite field | ground; ranged rocks | MM |
| `guard_accord` — `guard.lua:264` | civic guard, 24 h | authored Accord guard sockets/patrols | guard ≥20 | ground; melee | LotT |
| `guard_throng` — `guard.lua:266` | civic guard, 24 h | authored Throng guard sockets/patrols | guard ≥20 | ground; melee | LotT |
| `gull` — `gull.lua:82` | day critter | any `grug_beach`, independent of palettes (`spawn_policy.lua:284-289`) | critter L1 | flying air; passive/runaway | AN |
| `hyena` — `hyena.lua:70` | 24 h | M or savanna zones 22,23,25 | field ≥10 | ground; melee | AW |
| `jungle_ape` — `jungle_ape.lua:82` | day | J | field | ground; melee | AW |
| `jungle_lynx` — `jungle_lynx.lua:79` | day | E or J | field ≥10 | ground; melee | AW |
| `kraken` — `kraken.lua:11` | boss, 24 h | deep-ocean water-class authority (`spawn_policy.lua:110-114`; `kraken.lua:133`) | fixed L100 | swimming (`fly_in=water`); melee | VL |
| `mirefolk` — `mirefolk.lua:90` | 24 h camp enemy | authored Mirefolk camps (`camps.lua:809-817`) | field | ground; melee | GRUG |
| `panther` — `panther.lua:75` | night | J | field | ground; melee | AW |
| `parrot` — `parrot.lua:78` | day critter | E | critter L1 | flying air; passive/runaway | VL |
| `rabbit` — `rabbit.lua:86` | day critter | S, Accord-side variant | critter L1 | ground; passive/runaway | VL |
| `hare` — `rabbit.lua:120` | day critter | S, Throng-side variant | critter L1 | ground; passive/runaway | VL |
| `mountain_ram` — `ram.lua:69` | day | M | field | ground; retaliating passive prey | VL |
| `serpent` — `serpent.lua:72` | day | J | field | ground; melee | AW |
| `skeleton_archer` — `skeleton_archer.lua:127` | night | F or B | field | ground; ranged `arrow_entity` (`skeleton_archer.lua:56-67`) | VL |
| `skeleton_raider` — `skeleton_raider.lua:103` | night | B | field | ground; ranged `arrow_entity` (`skeleton_raider.lua:28-38`) | VL |
| `giant_spider` — `spider.lua:78` | night; cave | F and underground | field | ground; melee | MM |
| `pale_spider` — `spider.lua:116` | night | F, Throng-side variant | field | ground; melee | MM |
| `jungle_spider` — `spider.lua:157` | night | J | field | ground; melee | MM |
| `stag` — `stag.lua:83` | day | F plus exact zone 14 | field | ground; retaliating passive prey | AN |
| `gaunt_stag` — `stag.lua:113` | day | F, Throng-side variant | field | ground; retaliating passive prey | AN |
| `wolf` — `wolf.lua:71` | 24 h | F, Accord-side variant | field ≥10 | ground; melee | VL |
| `blightfang_wolf` — `wolf.lua:98` | 24 h | F, Throng-side variant | field ≥10 | ground; melee | VL |
| `zebra` — `zebra.lua:66` | day | savanna zones 22,23,25 | field | ground; retaliating passive prey | AW |
| `zombie` — `zombie.lua:4` | night surface; 24 h blight; cave | S or B and underground | field ≥3 | ground; melee | VL |

The light gates supporting those role labels are collected in the per-mob spawn
rows: daytime uses `min_light=10`, nighttime uses `max_light=5` with
`day_toggle=false`, while explicit 24-hour rows omit both; the implementation
itself states the convention at `mods/ENTITIES/grug_mobs/golem.lua:177`,
`panther.lua:78-90`, and `zombie.lua:77-119`.

### 1.3 Civic noncombatants

The start-NPC loop registers a villager and elder for each authenticated race
(`start_villagers.lua:1005-1079`), yielding these 12 civic, ground,
non-ranged definitions: `villager_dwarf`, `elder_dwarf`, `villager_human`,
`elder_human`, `villager_elf`, `elder_elf`, `villager_undead`, `elder_undead`,
`villager_orc`, `elder_orc`, `villager_troll`, and `elder_troll`. They are
authored socket residents rather than wildlife; they bypass the level wrapper
by using plain `mobs:register_mob`. Their mesh is `character.b3d`; the licence
record identifies that mesh as CC BY-SA 3.0 (`LICENSE-media.md:315-317`). Their
activation applies race visuals (`start_villagers.lua:1039-1046,1063-1074`),
whose texture licence records live with the visual system, not in
`grug_mobs/LICENSE-media.md`.

The vendor helper likewise uses plain `mobs:register_mob` and marks the result
noncombatant (`mods/ENTITIES/grug_traders/vendors.lua:362-370`). It creates 20
civic, ground, non-ranged definitions:

- faction: `vendor_general_accord`, `vendor_general_throng`
  (`vendors.lua:378-387`);
- race: `vendor_race_dwarf`, `vendor_race_human`, `vendor_race_elf`,
  `vendor_race_undead`, `vendor_race_orc`, `vendor_race_troll`
  (`vendors.lua:389-399`);
- profession: `vendor_butcher`, `vendor_smith`, `vendor_fishmonger`,
  `vendor_baker`, `vendor_tailor`, `vendor_mason`, `vendor_brewer`,
  `vendor_bowyer`, `vendor_herbalist`, `vendor_armourer`, `vendor_tanner`, and
  `vendor_embalmer` (`vendors.lua:441-477`).

Vendor placeholders use the two LotT guard textures and the `character.b3d`
mesh (LotT licence key above); settlement activation may replace the placeholder
with a race visual (`vendors.lua:373-398,473-476`).

### 1.4 Named rare instances

These are rare-tier instances of registered base definitions, not additional
mob registrations. Their level is evaluated from the authored route position;
each carries a two-to-four-hour respawn interval.

| Rare id / displayed name | Base mob | Recorded habitat | Evidence |
|---|---|---|---|
| `grimtusk` / Grimtusk | boar | central meadows | `rares.lua:377-383` |
| `ashmaw` / Ashmaw | boar with plague texture | savanna | `rares.lua:385-397` |
| `old_whitefang` / Old Whitefang | wolf | deep forest | `rares.lua:418-436` |
| `marrowclaw` / Marrowclaw | plaguehide bear | bone forest | `rares.lua:438-455` |
| `korgans_bane` / Korgan's Bane | stone golem | high crags | `rares.lua:474-502` |
| `silkfang` / Silkfang | jungle spider | jungle fringe | `rares.lua:504-532` |
| `dustwing` / Dustwing | vulture | badlands | `rares.lua:534-551` |
| `emerald_coil` / Emerald Coil | serpent | deep jungle | `rares.lua:553-571` |
| `bonerattle_south` / Captain Bonerattle | skeleton raider | war coast, Accord instance | `rares.lua:574-633` |
| `bonerattle_north` / Captain Bonerattle | skeleton raider | war coast, Throng instance | `rares.lua:635-647` |

## 2. Zones and biome content

### 2.1 The 38 zones

These are the literal rows at
`mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:84-121`. `—` is the literal
`false` faction value. Civic is the row's final `true` flag.

| # | ID | Name | Race | Faction | Levels | Relief | Logical biomes | Civic |
|---:|---|---|---|---|---:|---|---|---|
| 1 | `elandor_hearthpine_vale` | Hearthpine Vale | dwarf | accord | 1–10 | `lowland` | `grug_pine_hills`, `grug_crags` | no |
| 2 | `elandor_copperfell_foothills` | Copperfell Foothills | dwarf | accord | 11–20 | `rolling_hills` | `grug_pine_hills`, `grug_crags` | no |
| 3 | `elandor_dur_brannoc` | Dur Brannoc | dwarf | accord | 20–30 | `plateau` | `grug_pine_hills`, `grug_crags` | yes |
| 4 | `elandor_frostbarrow_shelf` | Frostbarrow Shelf | dwarf | accord | 21–30 | `plateau` | `grug_pine_hills`, `grug_crags`, `grug_swamp` | no |
| 5 | `elandor_stormvault_heights` | Stormvault Heights | dwarf | — | 31–40 | `highland` | `grug_crags`, `grug_crags_snowy` | no |
| 6 | `elandor_dawnmere_fields` | Dawnmere Fields | human | accord | 1–10 | `lowland` | `grug_meadows`, `grug_deep_forest`, `grug_swamp` | no |
| 7 | `elandor_goldmead_vale` | Goldmead Vale | human | accord | 11–20 | `lowland` | `grug_meadows`, `grug_deep_forest`, `grug_swamp` | no |
| 8 | `elandor_highcourt` | Highcourt | human | accord | 20–30 | `rolling_hills` | `grug_meadows`, `grug_deep_forest` | yes |
| 9 | `elandor_whitebridge_shire` | Whitebridge Shire | human | accord | 21–30 | `lowland` | `grug_meadows`, `grug_deep_forest`, `grug_swamp` | no |
| 10 | `elandor_ashenward_march` | Ashenward March | human | — | 31–40 | `rolling_hills` | `grug_deep_forest`, `grug_meadows`, `grug_swamp` | no |
| 11 | `elandor_silverleaf_glades` | Silverleaf Glades | elf | accord | 1–10 | `lowland` | `grug_elf_forest`, `grug_deep_forest` | no |
| 12 | `elandor_starbough_vale` | Starbough Vale | elf | accord | 11–20 | `rolling_hills` | `grug_elf_forest`, `grug_deep_forest` | no |
| 13 | `elandor_lethariel` | Lethariel | elf | accord | 20–30 | `rolling_hills` | `grug_elf_forest`, `grug_deep_forest` | yes |
| 14 | `elandor_lorindor` | Lorindor | elf | accord | 21–30 | `rolling_hills` | `grug_elf_forest`, `grug_deep_forest`, `grug_swamp` | no |
| 15 | `elandor_moonfall_wood` | Moonfall Wood | elf | accord | 21–30 | `lowland` | `grug_elf_forest`, `grug_deep_forest`, `grug_swamp` | no |
| 16 | `elandor_glassroot_wilds` | Glassroot Wilds | elf | — | 31–40 | `highland` | `grug_deep_forest`, `grug_jungle_fringe`, `grug_elf_forest`, `grug_swamp` | no |
| 17 | `kragmar_stillgrave_hollow` | Stillgrave Hollow | undead | throng | 1–10 | `lowland` | `grug_blight`, `grug_bone_forest`, `grug_swamp` | no |
| 18 | `kragmar_mournfen` | Mournfen | undead | throng | 11–20 | `wetland_delta` | `grug_blight`, `grug_bone_forest`, `grug_swamp` | no |
| 19 | `kragmar_nhal_veyr` | Nhal Veyr | undead | throng | 20–30 | `plateau` | `grug_blight`, `grug_bone_forest` | yes |
| 20 | `kragmar_ossuary_reach` | Ossuary Reach | undead | throng | 21–30 | `rolling_hills` | `grug_blight`, `grug_bone_forest`, `grug_swamp` | no |
| 21 | `kragmar_blackwind_rise` | Blackwind Rise | undead | — | 31–40 | `highland` | `grug_bone_forest`, `grug_blight`, `grug_swamp` | no |
| 22 | `kragmar_sunscar_flats` | Sunscar Flats | orc | throng | 1–10 | `lowland` | `grug_savanna`, `grug_badlands` | no |
| 23 | `kragmar_redtusk_savanna` | Redtusk Savanna | orc | throng | 11–20 | `rolling_hills` | `grug_savanna`, `grug_badlands` | no |
| 24 | `kragmar_gor_drazhak` | Gor Drazhak | orc | throng | 20–30 | `plateau` | `grug_savanna`, `grug_badlands` | yes |
| 25 | `kragmar_speargrass_reach` | Speargrass Reach | orc | throng | 21–30 | `rolling_hills` | `grug_savanna`, `grug_badlands`, `grug_swamp` | no |
| 26 | `kragmar_bannerbreak_mesa` | Bannerbreak Mesa | orc | — | 31–40 | `plateau` | `grug_badlands`, `grug_savanna`, `grug_swamp` | no |
| 27 | `kragmar_kapok_cradle` | Kapok Cradle | troll | throng | 1–10 | `lowland` | `grug_jungle_edge`, `grug_swamp` | no |
| 28 | `kragmar_raincall_basin` | Raincall Basin | troll | throng | 11–20 | `rolling_hills` | `grug_jungle_edge`, `grug_deep_jungle`, `grug_swamp` | no |
| 29 | `kragmar_kezamba` | Kezamba | troll | throng | 20–30 | `plateau` | `grug_jungle_edge`, `grug_deep_jungle`, `grug_swamp` | yes |
| 30 | `kragmar_whispering_reedlands` | Whispering Reedlands | troll | throng | 21–30 | `wetland_delta` | `grug_jungle_edge`, `grug_deep_jungle`, `grug_swamp` | no |
| 31 | `kragmar_totemwater_reach` | Totemwater Reach | troll | throng | 21–30 | `wetland_delta` | `grug_jungle_edge`, `grug_deep_jungle`, `grug_swamp` | no |
| 32 | `kragmar_thunderroot_wilds` | Thunderroot Wilds | troll | — | 31–40 | `highland` | `grug_deep_jungle`, `grug_badlands_east`, `grug_swamp` | no |
| 33 | `front_wyrmglass_crown` | The Wyrmglass Crown | dwarf | — | 60 | `mountain` | `grug_crags`, `grug_crags_snowy`, `grug_beach` | no |
| 34 | `front_gravesalt_escarpment` | Gravesalt Escarpment | undead | — | 51–59 | `highland` | `grug_bone_forest`, `grug_blight`, `grug_swamp`, `grug_beach` | no |
| 35 | `front_broken_causeway` | The Broken Causeway | human | — | 31–40 | `wetland_delta` | `grug_meadows`, `grug_deep_forest`, `grug_swamp` | no |
| 36 | `front_shattered_line` | The Shattered Line | orc | — | 41–50 | `plateau` | `grug_badlands`, `grug_savanna`, `grug_swamp` | no |
| 37 | `front_skyglass_canopy` | The Skyglass Canopy | elf | — | 51–59 | `highland` | `grug_jungle_fringe`, `grug_deep_forest`, `grug_elf_forest` | no |
| 38 | `front_stormscale_summit` | Stormscale Summit | troll | — | 60 | `mountain` | `grug_deep_jungle`, `grug_badlands_east`, `grug_swamp`, `grug_beach` | no |

### 2.2 Logical biome content

R7 does not call `core.register_biome` for these IDs. They are logical labels
selected inside the authored zone plan; the current surface rows are the
authenticated R6 content projection (`r7_r6_manifest.lua:48-64`) and the
vegetation rows are `:94-142`. Consequently there is no per-biome engine
temperature or humidity value to report. The only heat/humidity values in this
mapgen are global native-mapgen noise settings (`r7_native.lua:194-218,240-258,
557-573`), not definitions of the 16 logical IDs. Ordinary and river water CIDs
are resolved globally (`r7_content.lua:211-239`).

| Logical biome | Ground top / filler (depth) | Shore/bed; dust | Current cover, trees and plants | Water CIDs available to the writer | Per-biome temp/humidity |
|---|---|---|---|---|---|
| `grug_badlands` | mesa clay / mesa clay (3) | gravel; none | dry shrub, large cactus | ordinary + river water | none |
| `grug_badlands_east` | mesa clay / mesa clay (3) | gravel; none | dry shrub, large cactus | ordinary + river water | none |
| `grug_beach` | sand / sand (2) | sand; none | no R6 decoration row | ordinary + river water | none |
| `grug_blight` | blight dirt / dirt (3) | gravel; none | bone pile, dry shrub, small gravewood | ordinary + river water | none |
| `grug_bone_forest` | bone litter / dirt (3) | gravel; none | bone pile, tall gravewood | ordinary + river water | none |
| `grug_crags` | gravel / gravel (2) | gravel; none | snowy pine at surface y≥60 | ordinary + river water | none |
| `grug_crags_snowy` | snowblock / gravel (2) | gravel; snow | no separate row; shares the crags surface condition | ordinary + river water | none |
| `grug_deep_forest` | forest litter / dirt (3) | sand; none | apple log/tree, aspen, ferns 1–3 | ordinary + river water | none |
| `grug_deep_jungle` | canopy litter / dirt (3) | sand; none | emergent/jungle trees, junglegrass | ordinary + river water | none |
| `grug_elf_forest` | silver litter / dirt (3) | sand; none | apple tree, grasses 1–3, silverwood | ordinary + river water | none |
| `grug_jungle_edge` | rainforest litter / dirt (3) | sand; none | jungle tree, junglegrass | ordinary + river water | none |
| `grug_jungle_fringe` | canopy litter / dirt (3) | sand; none | emergent/jungle trees, junglegrass | ordinary + river water | none |
| `grug_meadows` | grass dirt / dirt (3) | sand; none | apple tree, bush, grasses 1–5 | ordinary + river water | none |
| `grug_pine_hills` | conifer litter / dirt (3) | gravel; none | blueberry bush, ferns 1–3, pine bush, pine trees | ordinary + river water | none |
| `grug_savanna` | dry grass dirt / dry dirt (3) | sand; none | acacia bush/tree, dry grasses 1–5, dry shrub | ordinary + river water | none |
| `grug_swamp` | mud / mud (2) | mud; none | dry shrub, papyrus | ordinary + river water | none |

## 3. Gathering and foraging catalog

The public accessor is a copy of the 12-row `P9G` table
(`mods/ITEMS/grug_gathering/catalog.lua:81-181,448`). Each row has one raw item
and source node. `grade` is the literal `required_group`; a dash means nil.
The final column is the current `grug_food.converted` result: only `food` and
`found_only_food` are converted, Wild Cocoa to mana and the rest to HP, all at
raw quality (`mods/ITEMS/grug_food/init.lua:142-150`).

| Raw item | Kind / grade | Authored zones | Biome hosts / placement | Farmable | Current food conversion |
|---|---|---|---|---|---|
| `grug_gathering:corn` | food / — | Ashenward, Dawnmere, Goldmead, Whitebridge, Broken Causeway, Shattered Line, Bannerbreak, Redtusk, Speargrass, Sunscar | meadows, savanna | yes | raw HP, 2%/tick |
| `grug_gathering:crimson_lotus` | healing herb / 3 | Skyglass Canopy, Stormscale Summit | deep jungle, jungle fringe | no | — |
| `grug_gathering:dragonweed` | healing herb / 2 | Ashenward, Frostbarrow, Bannerbreak, Ossuary | badlands, bone forest, crags, deep forest | no | — |
| `grug_gathering:gravemoss` | healing herb / 1 | Copperfell, Mournfen | blight, pine hills | no | — |
| `grug_gathering:marshbloom` | spice / 2 | Lorindor, Whitebridge, Ossuary, Whispering Reedlands | swamp | yes | — |
| `grug_gathering:melon` | food / — | Glassroot, Skyglass, Stormscale, Kapok, Raincall, Thunderroot, Totemwater, Whispering Reedlands | deep jungle, jungle edge/fringe | yes | raw HP, 2%/tick |
| `grug_gathering:mushroom` | found-only food / — | 14 named zones listed at `catalog.lua:133-140` | bone forest, deep forest, swamp | no | raw HP, 2%/tick |
| `grug_gathering:potato` | food / — | Ashenward, Dawnmere, Goldmead, Whitebridge, Broken Causeway | meadows | yes | raw HP, 2%/tick |
| `grug_gathering:rock_salt` | found-only food / — | Gravesalt, Stormscale, Wyrmglass | beach plus `salt_cardinal` shore test | no | raw HP, 2%/tick |
| `grug_gathering:stormkelp` | spice / 3 | Gravesalt, Skyglass, Stormscale, Wyrmglass | every dry host plus `dry_cardinal` shore test | yes | — |
| `grug_gathering:sunleaf` | spice / 1 | Goldmead, Starbough, Raincall, Redtusk | elf forest, jungle edge, meadows, savanna | yes | — |
| `grug_gathering:wild_cocoa` | found-only food / — | Skyglass Canopy, Stormscale Summit | deep jungle, jungle fringe | no | raw mana, 2%/tick |

The eight reused mapgen gathering sources are a second catalog
(`catalog.lua:183-231`):

| Source/output | Harvest kind | Placement feature(s) | Farmable | Food conversion |
|---|---|---|---|---|
| `default:apple` | existing food | apple trees/log in deep forest, elf forest, meadows | yes | raw HP, 2%/tick |
| `default:blueberries` | existing food | pine-hills blueberry bush | yes | raw HP, 2%/tick |
| gravewood → `grug_trees:gravewood_wood` | signature wood | blight/bone-forest gravewood | no | — |
| kapok → `default:junglewood` | signature wood | emergent, edge and ordinary jungle trees | no | — |
| mountain pine → `default:pine_wood` | signature wood | snowy/pine-hills pine trees | no | — |
| oak → `default:wood` | signature wood | deep/elf/meadows apple trees and log | no | — |
| silverwood → `grug_trees:silverwood_wood` | signature wood | elf-forest silverwood | no | — |
| spikethorn acacia → `default:acacia_wood` | signature wood | savanna acacia | no | — |

The six cultural-node rows (`catalog.lua:233-302`) are the remaining gathering
registry. Ordinary density is 1/4096; each named concentrated zone uses 1/1024
and concentrated tier 4.

| Raw item | Eligible biomes | Concentrated zone | Ordinary / concentrated tool family |
|---|---|---|---|
| `grug_materials:gravesalt` | beach, blight, bone forest, swamp | Blackwind Rise | shovel / pick |
| `grug_materials:moonresin` | deep forest, elf forest, jungle fringe | Glassroot Wilds | axe / axe |
| `grug_materials:red_ochre` | badlands, savanna | Bannerbreak Mesa | shovel / shovel |
| `grug_materials:runeslate` | crags, snowy crags, pine hills | Stormvault Heights | hand / pick |
| `grug_materials:spirit_resin` | east badlands, deep jungle, jungle edge, swamp | Thunderroot Wilds | axe / axe |
| `grug_materials:sunwax` | deep forest, meadows | Ashenward March | hand / axe |

## 4. Edible and cookable content

### 4.1 Current food behavior and edible items

`grug_food` replaces registered item `on_use` behavior for its current list.
It defines a 180-second status ticking every 10 seconds; raw/cooked/well-cooked
restore 2/5/10 percent per eligible tick (`mods/ITEMS/grug_food/init.lua:6-12,
45-84`). Ticks are skipped in combat (`:51-59`). The exact converted list is:

| Item(s) | Resource / quality | Evidence |
|---|---|---|
| `default:apple`, `default:blueberries` | HP / raw | `grug_food/init.lua:125-140` |
| `mobs:meat_raw`, `mobs:meatblock_raw` | HP / raw | same; original edible registrations at `mods/ENTITIES/mobs/crafts.lua:88-97,421-436` |
| `mobs:meat`, `mobs:meatblock` | HP / cooked | `grug_food/init.lua:125-140`; originals at `mobs/crafts.lua:99-108,395-410` |
| `grug_mobs:raw_fish` | HP / raw | `grug_food/init.lua:132`; registration `mods/ENTITIES/grug_mobs/items.lua:130-141` |
| `grug_fishing:cooked_fish` | HP / cooked | `grug_food/init.lua:133`; registration `mods/ITEMS/grug_fishing/init.lua:90-104` |
| corn, melon, mushroom, potato, rock salt | HP / raw | catalog dispatch `grug_food/init.lua:142-150` |
| wild cocoa | mana / raw | catalog dispatch `grug_food/init.lua:142-150` |

No item currently uses `well_cooked`; the only values appended to
`grug_food.converted` are the rows above (`grug_food/init.lua:95-121,125-150`).

### 4.2 Cooking recipes registered in `mods/`

| Output | Input | Cook time where explicit | Evidence |
|---|---|---:|---|
| `mobs:meat` | `mobs:meat_raw` | 5 | `mods/ENTITIES/mobs/crafts.lua:110-115` |
| `mobs:meatblock` | `mobs:meatblock_raw` | 30 | `mobs/crafts.lua:447-452` |
| `grug_fishing:cooked_fish` | `grug_mobs:raw_fish` | 5 | `mods/ITEMS/grug_fishing/init.lua:137-142` |
| `default:glass` | group sand | default | `mods/BASE/default/crafting.lua:412-416` |
| `default:obsidian_glass` | obsidian shard | default | `default/crafting.lua:418-422` |
| `default:stone` | `default:cobble` | default | `default/crafting.lua:424-428` |
| `default:stone` | `default:mossycobble` | default | `default/crafting.lua:430-434` |
| `default:desert_stone` | desert cobble | default | `default/crafting.lua:436-440` |
| `default:clay_brick` | `default:clay_lump` | default | `mods/BASE/default/craftitems.lua:476-480` |
| `default:copper_ingot` | `default:copper_lump` | default | `default/craftitems.lua:482-486` |
| `default:gold_ingot` | `default:gold_lump` | default | `default/craftitems.lua:488-492` |
| `default:steel_ingot` | `default:iron_lump` | default | `default/craftitems.lua:495-499` |
| `default:tin_ingot` | `default:tin_lump` | default | `default/craftitems.lua:501-505` |
| `default:glass` | `vessels:glass_fragments` | default | `mods/BASE/vessels/init.lua:189-193` |
| `grug_materials:copper_bar` | `default:copper_lump` | 3 | generated table, `mods/ITEMS/grug_smelting/recipes.lua:28-47` |
| `grug_materials:tin_bar` | `default:tin_lump` | 3 | generated table, `grug_smelting/recipes.lua:28-47` |
| `grug_materials:iron_bar` | `default:iron_lump` | 3 | generated table, `grug_smelting/recipes.lua:28-47` |
| `grug_materials:silver_bar` | `grug_materials:silver_lump` | 3 | generated table, `grug_smelting/recipes.lua:28-47` |
| `grug_materials:gold_bar` | `default:gold_lump` | 3 | generated table, `grug_smelting/recipes.lua:28-47` |

The non-food entries remain cookable because Luanti's furnace uses the shared
`cooking` recipe type; this table does not classify them as food.

### 4.3 Fish and food-bearing mob drops

Fishing has one world table: 78% one raw fish, 12% one stick and 10% one
papyrus (`mods/ITEMS/grug_fishing/catch.lua:6-47`), with a 3–10-second wait
(`:64-81`). The same raw fish also drops from Mirefolk
(`mods/ENTITIES/grug_mobs/mirefolk.lua:74-79`).

`mobs:meat_raw` appears in the drop tables of Zebra, Wolf, Rabbit/Hare, Parrot,
Boar and variants, Gull, Cave Bat, Eagle/Vulture, Bear variants, Stag variants,
Cave Crawler, Jungle Ape, Panther, Mountain Ram, Bog Fowl, Crocodile, Jungle
Lynx, Bone Weevil and Hyena. The registrations are directly located by the
itemstring at `mods/ENTITIES/grug_mobs/{zebra.lua:54,wolf.lua:54,
rabbit.lua:71,parrot.lua:70,boar.lua:70,boar_variants.lua:57,gull.lua:74,
cave_bat.lua:74,eagle.lua:102,bear.lua:61,stag.lua:66,cave_crawler.lua:59,
jungle_ape.lua:72,panther.lua:64,ram.lua:57,bog_fowl.lua:68,crocodile.lua:93,
jungle_lynx.lua:68,bone_weevil.lua:71,hyena.lua:59}`.

### 4.4 Current potion

The only registered potion is `grug_traders:potion_healing_weak`: it restores
15% maximum HP, rounded with minimum one, through the central heal path
(`mods/ENTITIES/grug_traders/potion.lua:78-120`). It is usable in combat; there
is no combat refusal. It refuses dead users, an active cooldown, and full
health without consuming the item (`:91-125`). All instant potions share one
60-second wall-clock/player-meta expiry (`:39-68`); the item starts it only
after healing (`:120-125`).

## 5. Stations and recipe-book rules

### 5.1 Decided text

The design documents currently say:

- `docs/design/professions.md` §1, lines 16-27: “Universal secondary skills —
  everyone can learn all of them: Cooking and First Aid”; Cooking “has a recipe
  book with the same six T1–T6 groups and level gates as a profession book” and
  “no keystones”; ingredient regions are the gate.
- `docs/design/items_crafting.md` §2, lines 211-216: “One mechanism only: the
  recipe book. No skill-up grind, no per-recipe unlocks.”
- `items_crafting.md` §2.2, lines 286-329: “exactly one book per profession,
  internally grouped”; right-click browses; it has six T1–T6 groups; player meta
  stores unlock state; Cooking has a book too.
- `items_crafting.md` §3.7, lines 1219-1225: Cooking uses the same six groups and
  level gates, no keystones, and a tier opens on its regional ingredients.

The Round-5 R22 station-book decision is not yet folded into either cited design
document. Its current durable wording is in `BACKLOG.md:33`: “the crafting
inventory has a player recipe book listing every global recipe, while furnace
cooking/smelting, the dual furnace and the VoxeLibre-style alchemy stand each
have a station-specific book.” `TODO-round7.md:103-110` repeats the short form
“player recipe book plus station books.” WP10 remains open in that same backlog
row. This is a source-location discrepancy, not a design choice made here.

### 5.2 Nodes present in code

| Node(s) | Current behavior | Evidence |
|---|---|---|
| `default:furnace`, `default:furnace_active` | functional one-input cooking/fuel inventory and timer | `mods/BASE/default/furnace.lua:354-415` |
| `grug_smelting:dual_furnace`, `grug_smelting:dual_furnace_active` | functional two-material, two-output, one-fuel station | names `mods/ITEMS/grug_smelting/node.lua:64-68`; inventory/registrations `:292-353` |
| `grug_decor:xdecor_workbench` | decorative node; definition contains no formspec, inventory or interaction callback | `mods/ITEMS/grug_decor/xdecor.lua:141-152` |
| `grug_decor:xdecor_cauldron` | decorative node; definition contains no formspec, inventory or interaction callback | `grug_decor/xdecor.lua:154-170` |
| `grug_decor:cottages_anvil` | decorative nodebox; definition contains no station callback | `mods/ITEMS/grug_decor/cottages.lua:626-645` |

There is no implemented profession/Cooking recipe-book item or station-book UI
under `mods/`; the only matching current hooks are gathering's future
`book_group_locked` harvest result (`mods/ITEMS/grug_gathering/harvest.lua:21,
117`) and the unrelated writable `default:book` UI
(`mods/BASE/default/craftitems.lua:1-53,228-247`).

## 6. Day and night in current code

There are three `core.get_timeofday` call sites under `mods/`:

1. `grug_mobs.is_night` treats `timeofday <= 0.1875` or `>= 0.8125` as night
   (`mods/ENTITIES/grug_mobs/init.lua:381-386`). Its current consumer is the
   unprovoked night-truce race perk (`init.lua:563-569`).
2. Vendored mobs_redo stores the clock during environmental processing
   (`mods/ENTITIES/mobs/api.lua:1050-1057`). Its `docile_by_day` predicate uses
   the stored value between 0.2 and 0.8 (`api.lua:1515-1519`).
3. Spawn-time day/night filtering is separate: when `day_toggle` is present,
   mobs_redo reads the clock and maps 4500..19500 of a 24000-unit day to
   daylight, rejecting a night-only row in that interval or a day-only row
   outside it (`mods/ENTITIES/mobs/api.lua:4364-4379`).

Grudgelands' spawn table convention is
day `min_light=10`; night `max_light=5` plus `day_toggle=false`
(`docs/design/biomes_mobs.md` §4, lines 1206-1215). Rows described as 24 h omit
both the light gate and `day_toggle`, as stated next to Golem and Crocodile
(`mods/ENTITIES/grug_mobs/golem.lua:177`; `crocodile.lua:120`). Cave Bat and
Cave Crawler use darkness without a surface-night toggle, so caves remain dark
habitat independent of the surface clock (`cave_bat.lua:102-108`;
`cave_crawler.lua:92`).

## 7. Existing decided constraints for the creative plans

### Round 7 user rulings recorded on 2026-09-18

The Round 7 rulings are recorded in `TODO-round7.md` §1
(`TODO-round7.md:16-69`):

| Ruling | Recorded fact |
|---|---|
| R7.1 “Food v2” | Every food has a “fixed instant HP value per tier”, “never a percentage”, plus a three-minute buff ticking every five seconds. Raw edibles add 1% HP per five seconds; instant healing and regeneration are inactive in combat, while non-regeneration food bonuses remain active (`TODO-round7.md:18-28`). |
| R7.2 “Food tiers” | “T1–T2 dishes: regeneration only”; T3–T4 add one small pool bonus, and T5–T6 add a stronger pool or crit bonus. Role dishes exist, while exact tables remain an output of the cooking plan (`:29-33`). |
| R7.3 “Elixirs and potions” | Elixirs provide stronger tiered stat bonuses and no regeneration. Potions provide instant effects, retain the in-combat monopoly and share a 60-second cooldown. “Food buffs and elixirs stack, also on the same property” (`:34-40`). |
| R7.4 “Minimum level for consumables” | “Food, potions and elixirs enforce a minimum character level on use” through the item-level seam; a refused use consumes nothing (`:41-43`). |
| R7.5 “Mana regeneration” | Mana regeneration “grows clearly slower than the mana pool”. The numerical formula is explicitly recorded as “Proposal (orchestrator, confirm in the lane)”, not as a confirmed value (`:44-48`). |
| R7.6 “Level bands” | Every zone becomes harder in “three bands” from the continent's outer side toward the faction front; underground has three sub-bands per depth step, and the 150 m start band remains (`:49-54`). |
| R7.7 “Mob worlds” | Surface, underground and Nether retain “separate families and separate progressions”. The Nether reserves its own species, and underground favours flying and ranged families without the surface low-flight rule (`:55-60`). |
| R7.8 “Professions order” | “Round 8 delivers Cooking and Alchemy v1”; the listed crafting professions and Scout follow later (`:61-63`). |
| R7.9 “Buff list text” | Buff text names the effect, with the recorded examples “Food +2% HP/5s” and “Food +2% HP, +4% Mana/5s” (`:64-65`). |
| R7.10 “Start preload” | Start preload “must not re-emerge finished start areas on every server start”; a per-world marker is persisted and is absent in a fresh world (`:66-67`). |
| R7.11 “UI overlap” | “UI overlap” on the recorded Character-page and Talents-page locations “is fixed” (`:68-69`). |

### Design-document text currently present

The quotations below are deliberately short and retain their section location.
Where a design-document sentence collides with the Round 7 rulings above, its
row records that it remains in the file but is no longer the plan authority.

| Document / section | Existing rule (quotation) |
|---|---|
| `items_crafting.md` §0 “Decided anchors” | “Quality tiers: Common (white), Uncommon (blue), Rare (yellow), Unique (orange).” (`:38-44`) |
| `items_crafting.md` §2.1 “The two ladders” | Material/gear T1–T6 is “one per ten character levels”: 1–10 through 51–60; mastery is a separate four-tier crafter property (`:218-237`). |
| `items_crafting.md` §3.6 “Alchemist” | Herbs/spices have three grades; instant potions share 60 seconds; one elixir buff may be active (`:1039-1062`). |
| `items_crafting.md` §3.6 “Alchemist” | “The Healing Potion remains the only health consumable that restores health instantly and in combat” (`:1064-1068`). |
| `items_crafting.md` §3.7 “Universal secondaries” | **Still written, superseded by R7.1 on 2026-09-18, not yet folded in:** food ticks each 10 seconds only out of combat (`:1182-1194`). The same paragraph's one-buff, 180-second and replacement statements do not collide with the cited R7 text. |
| `items_crafting.md` §3.7 “Universal secondaries” | **Still written, superseded by R7.1–R7.2 on 2026-09-18, not yet folded in:** raw/simple/well-cooked restore 2%/5%/10% maximum HP per tick and mana food mirrors those percentages (`:1195-1207`). |
| `items_crafting.md` §3.7 “Universal secondaries” | Current raw/cooked assignments and “Nothing is well cooked yet” are written at `:1208-1214`; the six dish groups are listed at `:1227-1242`. |
| `professions.md` §1 “Structure” | Cooking is universal, costs no main-profession slot, uses six groups/level gates, and has no keystones (`:10-29`). |
| `professions.md` §2 “MVP roster” | Alchemist owns “Potions, elixirs, apothecary gear” and gathers its own herbs (`:44-56`). |
| `professions.md` §4 “Vendor floor rule” | “Vendors sell only the lowest tier of each item category” (`:156-160`). |
| `biomes_mobs.md` §3.1 “Families by biome group” | The complete existing families, day/night labels and habitats occupy `:1017-1112`; ranged land families see 16 m and melee families 10–14 m (`:996-1015`). |
| `biomes_mobs.md` §4 “Spawn parameter table” | “Day mobs `min_light 10`; night mobs `max_light 5` + `day_toggle = false`” (`:1206-1215`). |
| `world.md` §4b “Apex world bosses” | Phase 2+ examples are a jungle giant serpent and blight bone colossus; “Phase 3 — the Nether dragon lord” is population-conditional (`:630-640`). |
| `world.md` §6 “Travel” | Phase 2 Nether crossings link authored, level-equivalent portal pairs; the detailed design remains in `TODO-design-nether.md` (`:850-858`). |
| `combat_stats.md` §5 “Recovery” | Natural regeneration is 0.5% max HP/s out of combat and zero in combat (`:720-723`). |
| `combat_stats.md` §5 “Recovery” | The potion has the in-combat monopoly; food may total more but acts only out of combat and over time (`:745-749`). |
| `combat_stats.md` §5 “Recovery” | **Still written, superseded by R7.1 (food percentage) and R7.4 (level-agnostic consumables) on 2026-09-18, not yet folded in:** food/potions are percent-based and level-agnostic, with “no consumable item treadmill in the MVP” (`:750-755`). |
| `progression.md` §1 “Leveling pace” | “Level 60 in ~10–20 played hours”; leveling is the on-ramp (`:6-12`). |
| `progression.md` §4 “Quest structure & level gates” | Main quests use hard minimum levels; first PvP quests begin at levels 31–40 (`:95-102`). |

`world.md` currently has no section headed “Nether”; the two rows above are its
only `Nether` occurrences (`world.md:639,856-858`). Likewise,
`progression.md` does not map material tiers to levels: its uses of “tiers” at
`:58-68` concern Claim Stone tiers. The binding material-tier/level mapping is
instead the quoted `items_crafting.md` §2.1 row above. These are statements of
the current files, not proposed edits.
