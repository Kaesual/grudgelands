# Quests: round history and per-band content record

Archived 2026-11-16 (documentation cleanup, step 7, lane quests) from
`docs/design/quests.md` at `1ca9cde6`, verbatim except that relative links
were rewritten for this folder. These blocks recorded the quest system round
by round: the change narrative that opened the file, the history of the quest
total, the main line's step lists, the group-quest measurement of 0.62.0 and
the content record per level band of Rounds 57–62 and the capitals (which
quests each band shipped, their places, reward slots, kept ids and the tools
that wrote the structure). Their present-tense claims apply to their round.
They are not current design: the rules live in
[quests.md](../../design/quests.md), the per-quest facts in the quest files
(`mods/PLAYER/grug_quests/data/zones/*.json`), the round's decisions in its
plan under `docs/planning/`.

## Opening narrative (old lines 3–19)

Decided 2026-09-21; extended by Round 20 user Go, 2026-09-24, and by the
Round 28 questing redesign, 2026-10-01 (rulings 29, 39–45;
[plan](../../planning/round28-questing-leveling-plan.md),
[design frame](../../planning/round28-design-frame.md) §4.7); text placeholders
and quest copper by Round 29 Lane Q1, 2026-10-02
([quests plan](../../planning/round29-quests-plan.md) §3–4); the Round 29
quest files and the front bounty baseline
([round plan](../../planning/round29-plan.md#completion-2026-10-02)); the "use at
a place" objective, quest tags and the turn-in hook by Round 36 Lane E,
2026-10-05 ([plan](../../planning/round36-plan.md) §2.5, §2.7); the repeatable
quests removed by Round 46 ruling 8, 2026-10-12
([plan](../../planning/round46-plan.md) §2); the system quest kind and the
starter quest by Round 48, 2026-10-14
([mail plan](../../planning/mail-plan.md) rulings 15 and 17.2); shared quests,
story and free play, completion texts, choice rewards and the end of the
repeatable switch by Round 57, 2026-10-23
([plan](../../planning/round57-plan.md) §2 rulings 9–17 and 21, §3).

## The quest total by round (old "Presentation and regional expansion", lines 210–230)

Round 29 replaced the 240 quests of Rounds 14–20 with 491 quests in the
per-zone quest files (below): one track per race from the start zone to its
heartland, the contested 31–40 zones, and the 41–60 front with island
bounties. Round 31 adds 24 PvP fortress quests (below) and Round 36 the main
line's 25 (below); Round 46 removed Round 29's 55 repeatable quests (485 in
total); Round 57 rebuilt the six start zones' 92 quests as 30 (423 in total,
"The start zones" below); Round 58 adds the Miner's Guild's 30 (453 in
total, [miners_guild.md](../../design/miners_guild.md) §11); Round 59 rebuilt the band
11–20's 83 zone quests as 59 and added chapter 1's four story quests in the
capitals (433 in total, "The band 11–20" and "Chapter 1 in the capitals"
below); Round 60 rebuilt the band 21–30's 84 as 71 and the six capitals'
64 as 47 (403 in total, "The band 21–30" and "The capitals" below); Round
61 rebuilt the band 31–40's 60 as 50 with chapter 3's four story quests
among them (393 in total, "The band 31–40" below); Round 62 rebuilt the
front 41–60's 123 (the fourteen front and Battlegrounds files and the main
line in the contested base files) as 120 (390 in total, "The front 41–60"
below); Rounds 71 and 72 add three Expedition party quests (**393 in
total**, counted as the quest ids in
`mods/PLAYER/grug_quests/data/zones/*.json`, "The capitals" below). This
is an editorial budget,
not a filler quota.

## Group quests measured on 0.62.0 (old "Group quests (Round 61)", lines 786–795)

From level 51 a group quest may stand on the story path. The rule holds
in the reworked files, since Round 62 all 48. Measured on 0.62.0 (19
group quests): none below level 39; the band 31–40's six at 39 ("The band
31–40") and the front's two at 50 (`front_engine_nine`,
`front_last_toll`, each shared by both factions, "The front 41–60") are
free, require nothing and are required by nothing; the eleven at 59–60
are the elites Salt-Counter and Glass-Throat per faction (standalone),
the island elites (each the one follow-up of its bounty) and the main
line's four, two of them on the path to the final turn-in
(`accord_main_collector`, `throng_main_finale`).

## The main line (Round 36) as written before the cleanup (old lines 277–330)

Each faction's main line for levels 41–60 (round36-plan §2.2–§2.8, the
[story bible](../../planning/round36/story-bible.md)) runs from its fortress
Warmaster's second line, travel handoffs and turn-ins at the existing
givers the bible names, and the front climaxes folded in as required
steps (their texts carry the thread; their other quests stay as they
were). Chapters open at 40, 45 and 53 (Round 65: their openers' levels
42, 47 and 55 minus two; 41, 46 and 53 before), each with a quest that
requires the previous chapter's last turn-in (a Warmaster turn-in); the
finale "Party: The Collector Comes Due" (level 60) opens at 58 on the rift
boss, and the
last turn-in at the Warmaster carries the bible's last line. Every step a
chapter names carries the faction's tag; every required step is solo but
the finale; optional branches (the war commander's "Party:" hunt, the
islands' interactions) never block the line. The ledger counts a front
host's main line in the front bands (`ledger.py --track`). Since Round 61
the 15 steps homed in the two contested base files (Ashenward March,
Bannerbreak Mesa) are marked `story`, as their files are reworked ("The
band 31–40"); since Round 62 the whole spine is `story` and the story
path: the 17 Accord and 14 Throng steps (the front climaxes on Senn,
Ninepins, Huskell and Chirr among them) each require only spine steps, and
The Throng's Chirr step follows Huskell's ("The front 41–60").

- **The Throng** ("Our Oaths Are Ours", tag `throng_main`, the
  Warmaster's line `oaths`): chapter 1 (40) the false requisition at
  Bannerfall Pocket, Drek Rampbinder's Toll-Taker Senn with his toll-box
  at Causeway Toll Ruin, Orrel Hollowstep's ash slab at Ashen Grave;
  chapter 2 (45) the pledged standard at West Trench Mouth, Yarra
  Standardmender's Ninepins, the Accord Captain's Orders from the Accord's
  high war camp on The Shattered Line, the branded pay buried at Coinpit
  Hollow; chapter 3 (53) the Kiln-Whisper Hexers, Vaska Ashlistener's
  Huskell, Nalo Pathdrum's Chirr with the rootmark at Skyroot Crossing,
  the tally-stone at Tombroad Ambush; then the finale, turned in at Vaska,
  and `throng_main_final` at the Warmaster. Optional: War Commander
  Greyvow (57, Party:), the survey cairn and the wreck's pay chest on the
  islands (60, from the Nhal Veyr and Gor Drazhak envoys, free since Round
  62).
- **The Accord** ("Every Name Accounted For", tag `accord_main`, the
  Warmaster's line `main`): chapter 1 (40) the impounded pay at Ashen
  Wheelbreak, Toren Waterbarrel's Coal-Purse Factors, Alna Archsight's
  rubbing at Brandscar Cairn and Toll-Taker Senn with his toll-box at
  Causeway Toll Ruin (her Senn step, level 48, opens at 46, so chapter 2,
  gated at 45, follows it at 46); chapter 2 (45) the Brandbound Collectors and
  the pledged standard at Siege Ramp Foot, Nella Hedgeward's Ninepins, the
  Throng Captain's Orders from the Throng's high war camp on The Shattered
  Line (47), the courier's pay ledger at Courier's Stump; chapter 3 (53)
  the Debtjaw Hounds, turned in at Borin Splitbolt, his Huskell, Eriath
  Boughwarden's Chirr, the rootmark at Skyroot Crossing and the
  tally-stone at Tombroad Ambush; then the finale at the Warmaster and
  `accord_main_final`, a report given and taken there. Optional: War
  Commander Stonegrudge (57, Party:), the survey cairn and the wreck's
  pay chest on the islands (60, from the Dur Brannoc and Highcourt envoys,
  free since Round 62).

## The per-band content record (old lines 869–1382)

The headings below are demoted one level.

### The start zones (Round 57)

The six start zones (levels 1–10: Dawnmere Fields, Hearthpine Vale and
Silverleaf Glades of The Accord; Sunscar Flats, Kapok Cradle and Stillgrave
Hollow of The Throng) are the rework's pilot (round57-plan.md §2 rulings
9–12 and 15–18): all six files are reworked, every quest is free play and
there is no story quest; the story begins at the level-19 handovers
(Round 59). Each town's two quest givers, the elder (lines `hunt` and
`tools`) and the cook (`pantry` and `kitchen`), offer their quests at once,
each gated only by its level.

- **Shared quests** (one id, a variant per town that gives it; each lives
  in its first variant's file, Dawnmere's, Hearthpine's or Silverleaf's):
  `start_boars` (8 small boars of the town's home kind by day, level 1,
  reward level 2) and `start_rats` (3 large rats after dark and 1 Rat Fur
  Patch, the cook's, level 1) are offered together; `start_stone` (10 stone
  of any kind, a Wooden Pickaxe's first job; a Stone Pickaxe and Stone Axe),
  `start_fuel` (5 logs and 5 Coal Lumps), `start_dead` (3 of the zone's
  zombies or husks, level 3; not in Dawnmere), `start_crabs` (2 Crab Legs,
  level 4; not in Dawnmere), `start_meat` (10 Raw Meat for 3 Meat),
  `start_bars` (3 Copper and 3 Tin Bars for a Dual Furnace, level 5) and
  `start_bronze` (3 Bronze Bars for a Bronze Pickaxe, level 7). Nothing is
  handed in and given back: the Round 29 tool swaps are gone. The hunts
  that would be twins are shared too: `start_foxes` (8 foxes, level 4;
  Dawnmere, Silverleaf), `start_snappers` (5 giant crabs, level 7;
  Dawnmere, Hearthpine) and `start_grunters` (6 aggressive boars, level 7;
  Silverleaf, Kapok, Stillgrave), all by day.
- **Local quests**: the zone's own hunts where no other zone hunts the
  same beast (Hearthpine's ibex, Sunscar's runners and scorpions, Kapok's
  tapirs, Stillgrave's fawns); the finale at the town's thieves' camp with its named leader
  (reward level 9); and the `*_departure` travel quest to the next zone's
  giver, the zone's one follow-up (it requires the finale; since Round 59
  no quest requires a departure: the band 11–20's first quests are free). Dawnmere's strand crabs and zombies live
  in kinds that are no quest target (no region on every seed), so it gives
  neither `start_dead` nor `start_crabs` and keeps its cook's
  shore-and-pasture errand.
- **Counts by phase** (ruling 12): the night's rats and the dead ask 3,
  about a third of the day hunts' 8.
- **Rewards** (ruling 18): `start_boars` a choice of 2 Healing Potion I or
  2 Mana Potion I; each zone's level-5 hunt an armor piece (cloth, leather
  or metal) with the class's main stat as its prefix, its level-7/8 hunt
  another slot with a suffix (mana, crit, maximum HP); a shared hunt has
  one slot wherever it is given (`start_foxes` chest, `start_snappers` legs,
  `start_grunters` feet); the finale one weapon per weapon
  line with a prefix and a suffix (a Wand or Staff, the Bow, a Sword or
  Battle Axe; the two-handed Staff where the Battle Axe is offered). Each
  zone gives two slots; the three Accord towns together give all four. The other quests pay
  XP and copper, the crafting ones their tool or station.
- **Ids**: a quest whose objectives stayed keeps its id (the six finales
  `*_hunt_05`, two hunts and Dawnmere's errand); every other quest is new,
  and the old ids are dropped (upgrade contract §4). The structure was
  written by `tools/r57_startquests/build_structure.py`;
  `tools/r57_startquests/portable_test.lua` checks it.

### The band 11–20 (Round 59)

The six zones of levels 11–20 (Copperfell Foothills, Goldmead Vale and
Starbough Vale of The Accord; Mournfen, Redtusk Savanna and Raincall Basin
of The Throng) are reworked on the same rules (round59-plan.md §2, §2a),
from the story chapter the user picked (every recommendation of the
chapter draft): every quest is free play, nothing chains, a level-11
character finds the zone's first quests (open from level 9 since Round 65) at once,
without a departure. The zone's own people give them: the village's
steward and local, the outpost's scout, the bandit camp's captive (Round
14 and 15) and the mining camp's foreman (Round 58). Each zone offers 13
quests.

- **Shared quests** (the tasks that are the same): `band_repairs` (4 Iron
  Bars and 4 Coal Lumps for the local's repair, all six zones, level 12),
  `band_load_record` (the original load record at the load board of the
  zone's bandit camp, Copperfell and Goldmead, level 15) and
  `band_held_supplies` (supplies the bandits hold at the edge of the
  zone's bandit camp, Redtusk and Raincall, level 19). The two use quests
  stand their object on a town place of the camp (`socket:<zone>_bandit_camp/
  load_record`, `.../held_supplies`; the camp blueprint
  `wp40/r14_poi_blueprint.lua`): the load record by the camp's stores, the
  held supplies in the corner across from the captive enclosure, out of
  the camp leader's sight at the centre. The camp hunt `camp_hunt_t2` and
  the guild report `guild_t2_report_*` (story) stay as Round 58 shipped
  them.
- **Local quests**: the witness (the scout's travel quest to the captive)
  and the named perpetrator (the captive's kill quest; Mournfen's report
  goes to the scout) are each zone's own story; so are the departure (ids
  kept, level 19, requiring nothing, to the capital's envoy), the
  steward's handoff to the scout, Starbough's snares (`snare_bundle` at the
  recipe place `snare_ground` in the Lower Boughs) and Mournfen's names
  (`witness_record` at `name_rest` in the Blightfields), and the zone's
  errands: the steward's first gathering, the scout's gathering or craft,
  two crafts or gatherings of the local (Basic recipes: torches, signs,
  ladders, fences, locked chests; logs, herbs, crops, copper ore) and one
  day hunt in the middle belt.
- **Objectives**: 3 kill objectives per zone (the camp hunt, the day hunt,
  the perpetrator), so 3 mob names, against 8–10 before; no kill-for-drop.
- **Rewards** (ruling 18) at item levels 11–20 (tier-2 pieces, enchant
  tier 2): the steward's first quest a choice of 2 Healing Potion II or 2
  Mana Potion II; the day hunt (level 15–16) an armor piece per armor
  class with the class's main stat as its prefix, the local's last craft
  (level 17) another slot with a suffix (mana, crit, maximum HP); the
  perpetrator (level 19) one weapon per weapon line with a prefix and a
  suffix. Each faction's three zones give all four slots: Copperfell
  chest and feet, Goldmead head and feet, Starbough head and legs,
  Mournfen head and chest, Redtusk head and feet, Raincall chest and legs.
- **Ids**: a quest whose objectives stayed keeps its id (the departures,
  the six witness travels and the six handoffs, five day hunts, three perpetrators);
  every other quest is new. The structure was written by
  `tools/r59_bandquests/build_structure.py` with placeholder texts (since
  the texts landed the JSON files are the source; its `--check` compares
  their structure only); `tools/r59_bandquests/portable_test.lua` checks it.

### The band 21–30 (Round 60)

The eight zones of levels 21–30 (Frostbarrow Shelf, Whitebridge Shire,
Lorindor and Moonfall Wood of The Accord; Ossuary Reach, Speargrass
Reach, Whispering Reedlands and Totemwater Reach of The Throng) are
reworked on the same rules (round60-plan.md §2, §2a), from the story
chapter the user picked (chapter 2, every recommendation K1–K13 "A",
with the feasibility check's fixes). A level-21 character finds each
zone's first quests (open from level 19 since Round 65) at once; free quests require only a
level, and only chapter 2's story quests chain. The zone's own people give
them: the Round 20 hosts (village, outpost, mine) and the mining camp's
foreman; no new giver.

- **Shared quests** (one id, one level, one title; the zone's voice in the
  variant text): `band_steel` (4 Steel Bars at the six mines, level 23:
  Kelda, Halen, Saevin, Neris, Gorren, Zali, each naming its guild in this
  first offer), `band_shore_pinchers` (6 Barnacle Pinchers by day on the
  zone's shore, level 24: Hedra, Orya, Lethen, Tokai), `band_snares` (the
  snare bundle at the recipe place `snare_ground` of Lorindor's Berrywoods
  and Moonfall's Eaves, level 21), `band_corn` (8 Corn, Merren and Brakka,
  level 20, their zone's potion choice), `band_planks` (15 planks of any
  wood, Lethen and Tokai, level 22) and `band_mire_carp` (4 Mire Carp,
  level 20: Tokai and Varda Copperpan in Dur Brannoc, a capital variant of
  a band quest). The givers' lines: `shore` for Hedra, Orya, Lethen and
  Tokai (the shore hunt, the snares, the planks), Tokai's second line
  `provisions` with Varda's (the fish), `steel` for the six mine leaders,
  Merren's and Brakka's `journeys` (the corn).
- **Local quests**: the first errand (Frost Melons, Marshbloom, Glass,
  Gravewood Planks, Melons; the potion choice), a use at a new place or a
  day hunt, a later errand (Basic recipes or gatherings: coal, stone
  bricks, chests, torches, ladders, gates, signs, jungle wood fences), the
  zone's named leader (Nib, Thorn and Murk, Iss, Bracken, the Marrow
  Archivist, Rakk, Ush, the Reed-Maw), the travels between the zone's
  people and to the neighbours, and the departures at 29 to the 31–40
  hosts (ids kept, requiring nothing).
- **Places**: town places (`quest_place` sockets) at Rimebell Watch
  (`socket:r20_anchor_026/signal_stand`, Hedra's `signal_lantern`), at
  Whitebridge Market Close (`socket:r20_anchor_016/basket_check`,
  Merren's `dispatch_record`; the R20 POI blueprint's `QUEST_PLACES`) and
  in every mining camp (`held_load`, Frostbarrow's named by A3; since
  Round 61 four band 31–40 camps' too, "The band 31–40"); recipe
  places Lorindor and Moonfall `snare_ground`, Moonfall `sighting_post`
  (the Deepwood, `sighting_frame`), Ossuary `claim_rest` (the Barrowlands,
  T2a), Speargrass `banner_cache` (the Hunting Grounds, `held_supplies`),
  Reedlands `seized_stores` (the Reedbanks; in the open, not in Hushwater
  Nests, whose members stand up to 24 nodes from its centre) and
  Totemwater `reading_bank` (the Reedbanks, `reading_knots`).
- **Chapter 2's band steps** (story): `story_accord_03` "Held in Our Name"
  (level 24, requires `story_accord_02`): Brodd Deeppeg, the Frostbarrow
  mining camp's foreman, has the player secure the dispatch record and
  release the held load at the camp's `held_load` (two uses, any order),
  turned in at Kelda Screesort; `story_accord_04` "Under a Joint Seal"
  (level 29, requires A3 and `frostbarrow_cutting_04`): Kelda to Hadrin
  Beamset in Dur Brannoc; `story_throng_03` "The Copy Between Them"
  (level 24, requires `story_throng_02`): Rellis Shalemark, the Ossuary
  camp's foreman, has the witness record secured at the `claim_rest`,
  turned in at Mereth Rubbinghand. Lane CAPITALS' T3 requires it.
- **The kept cross-lane ids**: `frostbarrow_cutting_04` (Nib; its one
  Accord follow-up is A4; the Dispatch Folio, a soulbound quest-only item,
  drops from Nib every kill while needed) and `ossuary_rubbings_03` (the
  travel to Neris, given by Mereth and by Rellis; its one Throng follow-up
  is T3). `frostbarrow_departure` requires nothing.
- **Objectives**: at most 3 kill objectives per zone (the camp hunt, the
  shore hunt or a day hunt, the named leader; Speargrass a kill-near item
  instead of a hunt), 17–27 % of the objectives, against 50–62 % before.
- **Rewards** at item levels 21–30 (tier-3 pieces, enchant tier 3): the
  first quest a choice of 2 Healing Potion III or 2 Mana Potion III (reward
  level 21), two armor choices on local quests (a prefix, then a suffix),
  the named leader one weapon per weapon line with a prefix and a suffix;
  no shared quest rewards equipment. Each faction's four zones give every
  slot twice: Frostbarrow head and chest, Whitebridge legs and feet,
  Lorindor head and legs, Moonfall chest and feet; Ossuary chest and legs,
  Speargrass head and feet, Reedlands chest and feet, Totemwater head and
  legs. A3 and T2a pay a potion choice.
- **Ids**: a quest whose objectives stayed keeps its id (the departures
  and travels, six leader or day hunts, the claws), and so do the two
  cross-lane ids (Nib's quest gains the Folio objective); every other
  quest is new. The structure was written by
  `tools/r60_bandquests/build_structure.py` with placeholder texts (its
  `--check` compares the structure only); `tools/r60_bandquests/
  portable_test.lua` checks it.

### The band 31–40 (Round 61)

The six contested zones of levels 31–40 (Stormvault Heights, Ashenward
March and Glassroot Wilds of The Accord; Blackwind Rise, Bannerbreak Mesa
and Thunderroot Wilds of The Throng) are reworked on the same rules
([round61-plan.md](../../planning/round61-plan.md) §2, §2a), from the story
chapter the user picked (chapter 3, every recommendation K1–K13 "A", with
the feasibility check's fixes). A level-30 character finds each zone's
first quests (open from level 29 since Round 65) at once; free quests require only a level,
and only the story quests chain. The Round 20 hosts and the mining camps'
foremen give them; no new giver. The two contested base files
(`elandor_ashenward_march`, `kragmar_bannerbreak_mesa`) are flagged whole:
their 15 main-line steps (41–60, "The main line") keep their ids,
objectives, levels, `requires`, lines, texts and home and are only marked
`story`; the `.front` files stay unflagged. 60 quests of reward level
31–40 became 50.

- **Shared quests** (one id, one level, one title; the hosts that give one
  share the line `border`, beside `front` or, for Faeris Rootbinder and
  Rumela Stormstep, beside their local line): `border_meal` (8 Corn, Toren
  and Drek, level 31), `border_melons` (5 Melons, Faeris and Rumela, level
  30), `border_stores` (3 Chests, Faeris, Orrel and Rumela, level 31),
  `border_packets` "Words Worth Bringing Back" (all six zones' hosts Alna,
  Nella, Faeris, Orrel, Yarra and Rumela, level 38): the **Runner's
  Packet** (`grug_mobs:runners_packet`, a soulbound quest-only item, "Quest-
  only drops"), dropped 1 in 3 by the bandit archers of the zone's Round 20
  bandit camp while needed, each variant's drop limited to its camp
  (Slatehook Hideout, Coalbrand Yard, Rootsnare Camp, Pallcloth Den,
  Sunderstrap Camp, Rainchar Camp; without the area Blackwind's hideout
  archers would count too), and `border_reserve` (a use at the own mining
  camp's `held_load`, `held_supplies`, Nella and Yarra, level 30). The
  camp hunts (`camp_hunt_t4`, `_night`), the raid `camp_site_raid` and the
  guild reports `guild_t4_report_*` stay as Round 58 shipped them; no zone
  quest kills a camp hunt's role in its zone.
- **Local quests**: the hosts' errands (Borin's Silversteel Bars and
  Frostfin, Alna's Emberglass, Toren's Iron Buckets, Faeris's Wooden
  Ladders, Vaska's Mushrooms),
  the uses at the camps' `held_load` (Vaska's `signal_lantern`, Rumela's
  `reading_knots`), A Soldier's Due (`bannerbreak_standard_04`, free), each
  zone's **solo quest with its weapon** (Scrip `ashenward_rations_03` and
  Rattle `bannerbreak_ramp_03`, ids kept, Rattle's asking only for Rattle,
  who stands at 35; and a use at a new recipe place: Alna's
  `sighting_frame` at the Stormvault Survey Stand in the Highcrags,
  Faeris's `snare_bundle` at the Glassroot Carrier Path in the Canopy,
  Orrel's `held_supplies` at the Blackwind Recovery Rest in the Deadmarch,
  Rumela's `storm_vessel` at the Thunderroot Storm Store in the
  Stormglades), the travels between the hosts (ids kept, requiring
  nothing) and the departures at 40 to a host with front work from 40
  (Alna and Faeris to Nella, Orrel to Drek, Rumela to Yarra; Ashenward's
  and Bannerbreak's hosts give their front quests themselves).
- **One optional group quest per zone** ("Group quests" above): the
  zone's elite leader ("Party:", level 38–39, ids kept: Split-Seam,
  Red-Receipt, Canopy-Knuckle, Hollowbell, Banner-Eater, Storm-Bottle),
  free, requiring nothing and required by nothing, its extra a choice of
  three plain tier-4 trinkets; the questing share is met without it. The
  four normal leaders no quest hunts any more (Bolt-Chewer, Basket-Biter,
  Grave-Broker Mute, Bottle-Keeper Zek) left their spawn files and the
  catalogue.
- **Chapter 3** (story): `story_accord_05` A5 "Every Hand on the Road"
  (level 34, requires A4 and Scrip's free quest): Toren Waterbarrel has the
  raided transport's record secured at the Ashenward Broken Load
  (`dispatch_record`, the Wheelbreak) and taken to **Audra Wainholt**, the
  Ashenward mining camp's foreman; `story_accord_06` A6 "The Cost of
  Holding Ground" (level 40, offered from 39, requires A5 and
  `camp_site_raid`): any of the three Accord band foremen sends the
  player with the raid's report to Nella Hedgeward, who points to the
  Warmaster; `story_throng_05` T4 "The
  Hands Behind the Stores" (level 35, requires T3 and Rattle's free quest):
  Drek Rampbinder, the handover record at the Bannerbreak Scattered Load
  (`witness_record`, the Warplains), turned in at **Greda Stonehaul**, the
  Bannerbreak mining camp's foreman; `story_throng_06` T5 "The Promise
  Still Stands" (level 40, requires T4 and the raid): any Throng band
  foreman to Yarra Standardmender, who points to the Warmaster. Scrip's,
  Rattle's and the raid's free quests keep their ids; their one follow-up
  per faction is the story step. The free fortress calls
  (`ashenward_bastion_call`, `bannerbreak_warhold_call`, level 40) carry
  the player on; there is no A7/T6.
- **Objectives**: 4–6 kill objectives per zone with the camp quests (the
  raid's two among them), 3–5 mob names besides the raid's garrison (the
  camp hunt's, the Packet's archers, the group leader; Scrip and
  Red-Receipt in Ashenward, Rattle and the Trench Mummies in Bannerbreak),
  against 8–10 before.
- **Rewards** at item levels 31–40 (tier-4 pieces, enchant tier 4): each
  zone's early potion choice (2 Healing Potion IV or 2 Mana Potion IV, from
  level 31: Frostfin, the Corn, the Chests) and the Runner's Packet's,
  two armor choices (a prefix, then a suffix), the weapon on the zone's
  solo quest (one per weapon line, prefix and suffix). The shared quests
  count in every zone that gives them (`E-reward-budget`) and a player
  takes each once, so armor sits only on shared quests given once per
  faction (the Melons feet, the reserve chest, both prefixes) and the
  Packet, given in all six zones, pays potions: each faction's three zones
  give six pieces, every slot at least once. The Accord: Silversteel Bars
  head and Emberglass legs, the reserve chest and Iron Buckets legs, the
  Melons feet and Faeris's ladders head; the Throng: Mushrooms head and the
  signal lantern chest, the reserve chest and A Soldier's Due legs, the
  Melons feet and the reading cord legs. A5 and T4 pay a potion choice.
- **Ids**: a quest whose objectives stayed keeps its id (the travels,
  Glassroot's and Thunderroot's departures, the six group leaders, Borin's
  bars, Alna's Emberglass, A Soldier's Due, the camp and guild quests), and
  so do the cross-lane ids Scrip and Rattle (Rattle's objectives changed:
  the upgrade contract's 0.61.0 entry); every other quest is new (31 ids
  went, 21 came, 29 stayed). The structure was written by
  `tools/r61_bandquests/build_structure.py` with placeholder texts (its
  `--check` compares the structure only); `tools/r61_bandquests/
  portable_test.lua` checks it.

### The front 41–60 (Round 62)

The front of levels 41–60 (The Broken Causeway and The Shattered Line at
41–50, Gravesalt Escarpment and The Skyglass Canopy at 51–60, the two
islands at 60) is reworked on the same rules
([round62-plan.md](../../planning/round62-plan.md) §2, §2a; the chapter-4
story layer the user picked, K1–K13 all "A", with the feasibility check's
fixes). All fourteen files that stayed unflagged are flagged: the ten
`.front` files of the four contested hosts and six capitals and the four
Battlegrounds files, whose guild and camp quests stay as Round 58 shipped
them. No giver stands in a front zone but the war-camp foremen (lines
`camp` and `guild`); the hosts and envoys give from their own zones and
send the player there. 123 quests of reward level 41–60 became 120.

- **The story path** is the main line ("The main line" above): its 31
  steps (17 Accord, 14 Throng, the climaxes on Senn, Ninepins, Huskell and
  Chirr among them) are `story` and each requires only spine steps; ids,
  objectives, levels, texts and hand-offs stay, each step gets a completion
  (the text lane's). The opener (open from 40) requires nothing, so a character who
  skipped the earlier chapters is not locked out; A6 and T5 reach it
  through the free fortress calls. The Throng's Chirr step
  (`kz_front_04`) follows Huskell's (`bw_front_ashveil_04`, K12 A). The war
  commander hunts stay optional story branches; the two finales are the
  only required group steps.
- **The fortress quests** (Round 31) keep their ids, chains, lines and
  files: the entry call, the three ordinary quests and the eight camp
  raids per faction, the two camps of a band chained by zone.
- **Shared front quests** (one id, one level, one title, the hosts' line
  `border`, each in its first variant's base file, Ashenward March's or
  Stormvault Heights'): `front_potatoes` (8 Potatoes as seed for the
  outposts' field plots, Toren and Drek, level 41), `front_return_light`
  (`signal_lantern` at the Causeway Return Stand, Toren and Drek, 42),
  `front_relief_count` (`witness_record` at the Shattered Relief Rest,
  Nella and Yarra, 43), `front_ford_salvage` (`held_supplies` at Fordward
  Wreck, Toren and Drek, 44), `front_salt_stores` (6 Salt Crust, Nella and
  Yarra, 44), `front_stormkelp` (8 Stormkelp, Alna and Orrel, 47),
  `front_old_wire` (`snare_bundle` at No-Man's Orchard, Nella and Yarra,
  48), the two optional group quests at 49/50 on the elites both factions
  hunt, `front_engine_nine` (Nella and Yarra) and `front_last_toll` (Alna
  and Orrel), and the departure `front_beyond_line` at 50 (Nella or Alna to
  Borin Splitbolt, Yarra to Nalo Pathdrum).
- **Local quests** (line `front`, each giver's `.front` file): Alna's
  `sighting_frame` at the Causeway Crossing Stand and the held tool load at
  the Stormvault mining camp's `held_load`; Dorrin Gateledger's three tasks
  at 45–48 (the returned tools at Dur Brannoc's forge yard, 10 Paper, a
  `sighting_frame` at Aqueduct Last Step), the Accord's third 41–50 giver
  (K1 A); Thorga Roadspeaker's at 42–45 (5 Ember Eel, the front load at Gor
  Drazhak's water depot, 3 Siegepack Fangs from the Siegepack Hyenas, an
  item only); Borin's from 50 (a `sighting_frame` at the Gravesalt Shoring
  Check, 5 Storm Tuna, the brace load at the Gravesalt Work Laydown);
  Eriath Boughwarden's from 51 (a `snare_bundle` at the Skyglass Carrier
  Clearing, 6 Wild Cocoa, a `dispatch_record` at the Skyglass Receiving
  Stand, a `witness_record` at Cloudwatch Fall); Orrel Hollowstep's (a
  `witness_record` at No-Man's Orchard, a `claim_notice` at Saltgate
  Remnant); Vaska Ashlistener's (6 Rock Salt, a `dispatch_record` at the
  Work Laydown, 20 Torches for the vigil); Nalo's (6 Melons, the
  `reading_knots` at the Carrier Clearing, a `sighting_frame` at the
  Receiving Stand); Ossa Quietregister's (the returned belongings at Nhal
  Veyr's receiving court, `nv_front_01`'s Glass Silk from the Gossamer
  Widows, a `witness_record` at the Gravesalt Recovery Post). The free
  departures require nothing and lead to a giver with work at once: Alna to
  Dorrin (45), Drek to Thorga (42), Borin to Eriath (51), Orrel to Vaska
  (52), Vaska to Ossa (53).
- **Group quests**: below 51 only the two shared ones (free, standalone,
  a plain trinket choice); from 51 Salt-Counter (Borin, Vaska) and
  Glass-Throat (Eriath, Nalo) per faction, standalone (a recorded
  exception: the hosts share no line, and Glass-Throat's shared quest would
  live in a capital base file), and the island elites.
- **The islands** (60, weight 0, coin only, "Every quest once"): the
  Accord's Dur Brannoc and Highcourt bounty pairs as shipped, the Throng's
  new pair at Thorga (`gordrazhak_krait_bounty`, 6 Kraits in the Stormscale
  Scorchlands by day, then the group quest on Last-Offering, K9 A); the
  four island uses free from 60 (open from 58 since Round 65).
- **Rewards** per faction and level band (tier 5 at 41–50, tier 6 at
  51–60; the budget per zone and level band, "The rework flag"): six armor
  choices with one enchant (every slot), three weapon choices with prefix
  and suffix on solo quests, three plain trinket choices (the two group
  quests at 50 and the Ninepins step at 41–50; Salt-Counter, Glass-Throat
  and the war commander from 51), a Healing or Mana Potion V/VI choice on
  the openers at 41 and 53 and early errands; the final turn-ins
  (`*_main_final`) a weapon choice. Shared quests given once per faction
  carry Ashenward's and Bannerbreak's (Toren and Drek, Nella and Yarra) and
  Stormvault's and Blackwind's (Alna and Orrel) share; the capitals carry
  the rest.
- **Objectives**: 4–6 mob names per front zone and faction besides the
  camp hunts and the garrisons (the spine's targets and the elites among
  them); the free front about a quarter kill (25 % The Accord, 18 % The
  Throng), the spine, fortress and camp quests keeping theirs (49 % The Accord,
  48 % The Throng over all, lane D's count).
- **Places**: eight new recipe places in the Battlegrounds spawn files
  ([spawn_regions.md](../../design/spawn_regions.md) `places`), the free clash sites
  076, 079, 080, 083 and 085, Stormvault's mining-camp `held_load` and the
  capitals' town places; no new object kind. No text names West Trench
  Mouth (a compass word).
- **Ids**: the spine, the fortress quests, the island uses, the four
  elites and Glass Silk (`nv_front_01`) keep theirs; every other quest is
  new (45 ids went, 42 came). The structure was written by
  `tools/r62_frontquests/build_structure.py` with placeholder texts (its
  `--check` compares the structure only); `tools/r62_frontquests/
  portable_test.lua` checks it.

### Chapter 1 in the capitals (Round 59)

The story arc's first chapter opens at the level-19 handovers in the six
capitals ([round59-plan.md](../../planning/round59-plan.md) §2 and §4
STORYQUESTS; the user's chapter picks K1–K16, all "A", 2026-10-24). Four
story quests, one shared quest per faction and step, a variant per capital;
the capital files stayed unflagged until Round 60 reworked them around
chapter 1, which stays as shipped ("The capitals" below).

- **`story_accord_01` "A Hearing for the Absent" and `story_throng_01` "Our
  Word, Our Witness"** (level 19, no prerequisite): given by the faction's
  three envoys (Mariel Waybook, Dorrin Gateledger, Eriath Boughwarden;
  Thorga Roadspeaker, Nalo Pathdrum, Ossa Quietregister), a travel quest to
  the Miner's Guild leader of the giver's own capital, who takes the turn-in
  (Alis Cartwright, Hadrin Beamset, Caelir Veinward; Drava Flintshoulder,
  Ombali Ropekeeper, Iven Lastshift). The envoy speaks of a reported case and
  never claims the player helped the band's witness; the departures still
  travel to the envoys and are no prerequisite.
- **`story_accord_02` "What a Seal Allows" and `story_throng_02` "Whose Word
  Is This?"** (level 20, requiring the first): given and turned in by each
  capital's leader, one use objective at the capital's **town place** (the
  same object and label in every variant, only the place differs: "Secure
  the dispatch record" or "Secure the witness record", a 3 s hold;
  [settlements.md](../../design/settlements.md) "Chapter 1's town places"). At the
  turn-in the leader decides the capital's case (the right issue, a limited
  release, the foreign claim refused); where the abused papers come from
  stays open, pointing on to Frostbarrow Shelf and Ossuary Reach. No traitor
  and no wrong decision of one's own in this chapter.
- **Givers and lines.** Each faction's two quests live in the file of their
  first variant's capital (Highcourt, Gor Drazhak). The three envoys of a
  faction share the line `envoy` (each envoy's own line was renamed; with
  `front` they keep two lines), and each guild leader is the one giver of a
  hub `<capital key>_guild` of its capital (line `guild`); the guild reports
  (`guild_t<k>_report_*`) still turn in there.
- **Rewards** (capitals are excepted from the zone budget): the first pays a
  travel quest's weight 1, the second weight 3 with a choice of 2 Healing
  Potion II or 2 Mana Potion II.
- The structure was written by `tools/r59_storyquests/build_structure.py`
  with placeholder texts; since the texts landed (Round 59 BANDTEXT) the
  JSON files are the source, its `--check` compares their structure only,
  and `tools/r59_storyquests/portable_test.lua` checks it.

### The capitals (Round 60)

The six capital files (Highcourt, Dur Brannoc and Lethariel of The Accord;
Gor Drazhak, Kezamba and Nhal Veyr of The Throng; levels 19–30) are
reworked on the Round 57 rules ([round60-plan.md](../../planning/round60-plan.md)
§2 point 2, §2a; the chapter-2 picks K1–K13, all "A"): every quest but the
story quests is free play, gated only by its level; nothing else chains.
Chapter 1 ("Chapter 1 in the capitals") stays as shipped, and so do the
envoys' ids and their `front` lines. Each capital keeps its two hubs: the
envoy (lines `envoy` and `front`) with the cook (`provisions` and
`dispatch`; Kezamba's cook's `smokehouse` became `provisions`), and the
guild leader alone (`guild`). 64 quests became 47.

- **Shared quests** (each in its first variant's file, Highcourt's or
  Lethariel's): `capital_torches` (20 Torches, all six envoys, level 20),
  `capital_night_dead` (2 Debtbound Zombies after dark, about a third of
  the capitals' day hunts; the envoys of Highcourt, Dur Brannoc,
  Lethariel and Nhal Veyr, level 21–22), `capital_precision` (the Alchemy
  quest, below) and `capital_raw_meat` (8 Raw Meat from the capital's day
  game, the cooks of Lethariel, Gor Drazhak, Kezamba and Nhal Veyr, level
  20–21). Varda's Mire Carp in Dur Brannoc is a variant of the band's fish
  quest `band_mire_carp`, homed in Totemwater Reach. Round 71 adds
  `capital_stilled_seam` ("Party: The Stilled Seam", the six guild leaders
  on `guild`, level 20, weight 4, turned in at the giver, one text per
  faction): kill Flintback in [the level 20
  Expedition](../../planning/round71-l20-description.md), at any of its levels.
  Optional and free, it follows "Group quests" above. Round 72 adds
  `capital_last_mint` ("Party: The Last Mint", the same six leaders, level 60,
  weight 4, one text per faction): kill Duewarden in [the level 60
  Expedition](../../design/expeditions.md#15-the-last-mint), at any of its levels.
- **Local quests**: each capital's climax, its named leader alone and free
  (Penn, Brakk, Rusk, Garr, Takka's `kezamba_offerings_04` and Hush's
  `nhal_veyr_vigil_03`, ids kept for the two whose objectives stayed or
  that the story requires), one day or night hunt and the cook's own errand
  where it is the capital's own (Highcourt's and Kezamba's Gnarled Boar
  Tusks, Highcourt's bucks, Dur Brannoc's rams, Lethariel's vixens, Gor
  Drazhak's scorpions after dark and hyenas, Kezamba's robbers after
  dark), and the handovers: the cooks' dispatch travels into the band and
  the envoys' departures at 29 to the 31–40 hosts, all free, their ids
  kept. Three kill objectives per capital at most (two in Kezamba and Nhal
  Veyr), two or three mob names.
- **The Alchemy quest** `capital_precision` (round60-plan.md §2 point 6,
  §2a points 4–5): at the first capital visit (level 19, reward level 20)
  each envoy asks, on its `envoy` line and with no prerequisite, for one
  **Elixir of Precision I** (Sunleaf, a Boar Tusk and a Glass Bottle), which
  no quest rewards; each envoy has its own playful occasion. The text names
  the capital's Alchemy trainer by its plot in words (Highcourt's herb
  garden, Dur Brannoc's and Lethariel's brewhouses, Nhal Veyr's physic
  house, Gor Drazhak's herb house, Kezamba's herbalist) and sends the
  player back to where they started, by their start settlement's waystone:
  Sunleaf grows in every start zone (Round 60 HERBS) and the start zones'
  boars by day drop the tusk; it never names the start zone (a text
  follows the giver's race, not the player's). A crafting lesson requests
  the item, so a friend's elixir counts. It is the one quest that may ask
  for a profession's product (`tools/r45_st`).
- **Chapter 2's T3** `story_throng_04` "Strike the False Claim" (story,
  level 29): Ossa Quietregister sends the player to post the claim notice
  (`claim_notice`, a 3 s hold) at the public register in front of Nhal
  Veyr's Miner's Guild house, a town place
  (`socket:nhal_veyr/miners_guild/miners_guild_public_register`,
  [settlements.md](../../design/settlements.md) "Chapter 2's town place"), and to report
  to Iven Lastshift, who takes the turn-in. It requires T2a
  (`story_throng_03`, Ossuary Reach), the free travel quest
  `ossuary_rubbings_03` and the free Hush quest `nhal_veyr_vigil_03`; it is
  the one Throng follow-up of each of the two free quests.
  `nhal_veyr_vigil_04`, the departure to Vaska, requires nothing.
- **Rewards** (capitals are excepted from the zone budget): the climaxes a
  choice of 3 Heavy Leather, 3 Heavy Cloth or 2 Steel Bars (the T3 camp
  hunts' choice), the night task and T3 a choice of 2 Healing Potion III or
  2 Mana Potion III; the others XP and copper.
- The structure was written by `tools/r60_capitals/build_structure.py`
  with placeholder texts (its `--check` compares the structure only);
  `tools/r60_capitals/portable_test.lua` checks it.

