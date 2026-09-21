# Round 14 starter-story catalog

Status: authored STORY handoff, 2026-09-21. This is a research and integration
record, not a living design authority. The approved rules remain in
`docs/design/quests.md`, `docs/design/story.md` and
`docs/research/round14-execution.md`.

## Scope and shape

Each culture receives nine linear story quests and two optional tool lessons.
The story begins with ordinary work, moves through local wildlife and a
night-time nuisance, and ends with signs that the nearby bandits are carrying
freshly scorched goods marked by an unfamiliar hooked-sun sigil. NPC dialogue
may call the sign **the Cinder Mark**; it is a symptom, not the name of the
ancient Nether power. No chain claims that the opposing faction caused it.

The first six main quests belong to the existing start elder. The seventh is a
short handoff to the level-11--20 village, the eighth uses its corresponding
outpost, and the ninth clears the corresponding home-region bandit camp. The
two tool lessons unlock after the first quest and never gate the main chain.
They say "Bring" because provenance is deliberately not tracked.

The catalog stops at an overworld clue. Nether travel is a later-expansion
feature: no V1 quest requires or unlocks a portal, names a Nether destination,
or asks for a Nether item or mob. The Cinder Mark can be investigated further
only by later content.

The reward ladder is paced against `100 * (level - 1)^2`. Main quests award
respectively `150, 300, 550, 900, 1500, 3000, 2200, 2800, 3400` quest XP and
`10, 15, 20, 25, 30, 40, 50, 60, 80` copper. The optional wood-axe and stone-pick
lessons award 150/10 and 250/15. A complete culture catalog therefore grants
15,200 base quest XP and 355 copper. The first reward reaches level 2 without
skipping it; later gates still require ordinary combat. Human quest XP applies through the existing source-tag
bonus. No item reward is required, avoiding early inventory-space traps and
equipment assumptions.

## Stable NPC and POI identities

The existing starts already publish `hall_quest`. The Round 14 POIs must publish
the other sockets below. Settlement keys are stable map anchors, never resolved
coordinates.

| Culture | Faction | Start elder | Home village | Outpost | Bandit camp |
|---|---|---|---|---|---|
| Dwarf | accord | `hearthpine` / `hall_quest` | `anchor_013` / `quest_steward` | `anchor_025` / `quest_scout` | `anchor_049` / `quest_captive` |
| Human | accord | `dawnmere` / `hall_quest` | `anchor_015` / `quest_steward` | `anchor_029` / `quest_scout` | `anchor_051` / `quest_captive` |
| Elf | accord | `silverleaf` / `hall_quest` | `anchor_017` / `quest_steward` | `anchor_033` / `quest_scout` | `anchor_053` / `quest_captive` |
| Undead | throng | `stillgrave` / `hall_quest` | `anchor_019` / `quest_steward` | `anchor_037` / `quest_scout` | `anchor_055` / `quest_captive` |
| Orc | throng | `sunscar` / `hall_quest` | `anchor_021` / `quest_steward` | `anchor_041` / `quest_scout` | `anchor_057` / `quest_captive` |
| Troll | throng | `kapok` / `hall_quest` | `anchor_023` / `quest_steward` | `anchor_045` / `quest_scout` | `anchor_059` / `quest_captive` |

POI-ART requirements are bounded: one passive `quest_steward` in each village,
one passive `quest_scout` in each outpost, and one passive `quest_captive` at
each camp. The captive is a dialogue/turn-in resident and needs no escort,
combat AI or rescue state. The camp quest is accepted from the outpost scout
and turned in to the captive after the camp family is defeated. A camp must not
place its captive inside a hostile respawn collision area. No quest definition
contains coordinates.

## Catalog contract

Production IDs use `r14_<race>_NN_<slug>` and NPC IDs use
`r14_<race>_<elder|steward|scout|captive>`. Every quest has `race`, `faction`,
`min_level`, explicit prerequisites, one kill or item objective, and XP/copper
rewards. Kill-family objectives use `mobs={...}`; they do not depend on parties
or killing blows. Item objectives consume ordinary main/bag holdings through
the quest-core transaction.

For every culture, the shared positions in the chain are:

| No. | Minimum | Source / turn-in | Purpose and objective |
|---|---:|---|---|
| 01 | 1 | elder | Local opening threat, kill 5 culture-specific boars |
| 02 | 2 | elder | Settlement stores, bring 4 `mobs:meat_raw` |
| 03 | 3 | elder | Store pests, kill 5 local boars or night rats |
| 04 | 4 | elder | Boundary patrol, kill 4 local boars or night zombies |
| 05 | 5 | elder | Local identity beat, kill 5 second local targets |
| 06 | 8 | elder | Local road clearance and village handoff, kill 6 start-zone targets |
| 07 | 10 | village steward | First home-region problem, kill 6 home-zone targets |
| 08 | 11 | outpost scout | Outpost patrol, kill 6 home-zone targets |
| 09 | 12 | outpost scout / camp captive | Kill 4 from `grug_mobs:bandit`, `grug_mobs:bandit_archer` |
| 10 | 1 | elder | Optional: bring 1 `default:axe_wood` |
| 11 | 2 | elder | Optional after 10: bring 1 `default:pick_stone` |

Quest 02 counts guaranteed meat rather than tusks or leather. The later kills
never require drops. Quest 06's text directs the player along the authored road
to the home village; it is still a kill objective and introduces no visit
objective. Quest 09 ends with the captive reporting charcoal-black cloth that
was hot without flame and bore the Cinder Mark. This is the first corruption
sign, intentionally evidence rather than a full revelation.

In the cultural tables below, rows 03 and 04 name the nocturnal narrative
target. Their objective families also include that culture's boar variant, so
both steps can be completed during the day without waiting for a time cycle.

## Cultural content

### Dwarf — Hearthpine to Copperfell

NPCs: Elder **Brunna Flintbraid**, steward **Orrik Pineledger**, scout
**Mara Deepwatch**, captive **Tovin Ashthumb**. The through-line is damaged
woodpiles, hungry households, ibex on the slate paths, goblins testing road
markers, and stolen ore ledgers.

| No. | Title | Objective target |
|---|---|---|
| 01 | Tusks at the Timberline | `grug_mobs:boar` |
| 02 | Meat for the Smokehouse | `mobs:meat_raw` |
| 03 | Rats in the Woodpiles | `grug_mobs:giant_rat` |
| 04 | Lanterns After Sundown | `grug_mobs:zombie` |
| 05 | The High Path | `grug_mobs:ibex` |
| 06 | Loose Stone on Copper Road | `grug_mobs:ibex` or `grug_mobs:boar` near the start road |
| 07 | A Ledger in the Scrub | `grug_mobs:fox` |
| 08 | Hold the Marker Stones | goblin raider/slinger/hound family in `elandor_copperfell_foothills` |
| 09 | Ash Under the Nails | bandit family in `elandor_copperfell_foothills` |
| 10/11 | An Axe Worth Carrying / Stone Before Steel | shared tool items |

### Human — Dawnmere to Goldmead

NPCs: Elder **Elian Reed**, steward **Marta Millward**, scout **Jon Vale**,
captive **Pella Thatch**. The through-line is broken fences, smokehouse stores,
field rats, turkey-flock losses, poachers near the orchard road, and burned
grain tallies.

| No. | Title | Objective target |
|---|---|---|
| 01 | Boars Beyond the Fence | `grug_mobs:boar` |
| 02 | The Smokehouse Share | `mobs:meat_raw` |
| 03 | Granary Teeth | `grug_mobs:giant_rat` |
| 04 | Shapes by Lanternlight | `grug_mobs:zombie` |
| 05 | The Missing Flock | `grug_mobs:wild_turkey` |
| 06 | Flock on Mill Road | `grug_mobs:wild_turkey` or `grug_mobs:boar` near the start road |
| 07 | Orchard Watch | `grug_mobs:fox` |
| 08 | Empty Snares | `grug_mobs:poacher` |
| 09 | The Blackened Tally | bandit family in `elandor_goldmead_vale` |
| 10/11 | A Woodsman's Edge / A Pick for the Road | shared tool items |

### Elf — Silverleaf to Starbough

NPCs: Elder **Saelin Dewbough**, steward **Ilyra Mossveil**, scout
**Theren Farstep**, captive **Nima Fern**. The through-line is boars rooting
young groves, food shared without waste, rats beneath seed stores, restless
dead, foxes around sapling guards, and poachers cutting living boughs.

| No. | Title | Objective target |
|---|---|---|
| 01 | Roots Laid Bare | `grug_mobs:boar` |
| 02 | The Grove's Portion | `mobs:meat_raw` |
| 03 | Beneath the Seed Baskets | `grug_mobs:giant_rat` |
| 04 | Footfalls Without Breath | `grug_mobs:zombie` |
| 05 | Keepers of the Saplings | `grug_mobs:fox` |
| 06 | Axes Without Leave | `grug_mobs:poacher` in `elandor_starbough_vale` |
| 07 | Quiet the Lower Boughs | `grug_mobs:poacher` |
| 08 | Watch the Green Road | `grug_mobs:fox` |
| 09 | Cinders in Green Cloth | bandit family in `elandor_starbough_vale` |
| 10/11 | The Careful Axe / Stone's Patient Lesson | shared tool items |

### Undead — Stillgrave to Mournfen

NPCs: Elder **Veyra Pall**, steward **Mordec Silt**, scout **Sera Vane**,
captive **Hollis Grey**. The through-line is plague boars in old plots,
preserved provisions, cellar rats, stray corpses that answer no bell, marsh
ooze, wisps, and bandits carrying heat through cold mud. Dialogue explicitly
separates the people's old blight from the new fiery sign.

| No. | Title | Objective target |
|---|---|---|
| 01 | Boars in the Dead Furrows | `grug_mobs:plague_boar` |
| 02 | Salt for What Remains | `mobs:meat_raw` |
| 03 | Gnawing in the Crypt Stores | `grug_mobs:giant_rat` |
| 04 | The Uncalled Dead | `grug_mobs:zombie` |
| 05 | Furrows Gone Sour | `grug_mobs:plague_boar` |
| 06 | Lights Across the Fen Road | `grug_mobs:wisp` in `kragmar_mournfen` |
| 07 | Mud That Moves | `grug_mobs:bog_ooze` |
| 08 | Clear the Sluice | `grug_mobs:crocodile` |
| 09 | Fire That the Fen Cannot Drown | bandit family in `kragmar_mournfen` |
| 10/11 | A Handle That Will Not Rot / A Pick Among Headstones | shared tool items |

### Orc — Sunscar to Redtusk

NPCs: Elder **Gara Stonevoice**, steward **Borak Redgrass**, scout
**Kesh Longstride**, captive **Rokka Emberhand**. The through-line is boars at
water skins, camp provisions, rats, sun-dried husks, scorpions near sleeping
mats, hyenas on the caravan trail, and raiders branding supplies with alien
heat rather than an orcish forge mark.

| No. | Title | Objective target |
|---|---|---|
| 01 | Tusks at the Water Skins | `grug_mobs:boar` |
| 02 | Meat for the Long Fire | `mobs:meat_raw` |
| 03 | Rats Under the Hide Racks | `grug_mobs:giant_rat` |
| 04 | The Thirsting Dead | `grug_mobs:zombie` |
| 05 | Shells by the Bedrolls | `grug_mobs:scorpion` |
| 06 | Husks on Redtusk Road | `grug_mobs:sun_dried_husk` in `kragmar_redtusk_savanna` |
| 07 | Teeth Around the Herd | `grug_mobs:hyena` |
| 08 | Scour the Dry Wash | `grug_mobs:scorpion` |
| 09 | No Forge Made This Brand | bandit family in `kragmar_redtusk_savanna` |
| 10/11 | Edge of the First Camp / Stone Has No Pride | shared tool items |

### Troll — Kapok to Raincall

NPCs: Elder **Zalima Rainhum**, steward **Daro Kapok**, scout
**Neshi Reedstep**, captive **Veko Bluefeather**. The through-line is jungle
boars in yam beds, shared cookpots, rats, old dead tangled in roots, vipers,
lynx on the rain road, and bandits whose wet cargo smoulders without being
consumed.

| No. | Title | Objective target |
|---|---|---|
| 01 | Boars in the Yam Beds | `grug_mobs:jungle_boar` |
| 02 | Fill the Evening Pot | `mobs:meat_raw` |
| 03 | Teeth in the Basket Weave | `grug_mobs:giant_rat` |
| 04 | Dead in the Rootways | `grug_mobs:zombie` |
| 05 | Vipers Under Broad Leaves | `grug_mobs:viper` |
| 06 | Claws on Raincall Road | `grug_mobs:jungle_lynx` in `kragmar_raincall_basin` |
| 07 | The Coiled Footpath | `grug_mobs:viper` |
| 08 | Cats at the Reed Line | `grug_mobs:jungle_lynx` |
| 09 | Smoke Beneath the Rain | bandit family in `kragmar_raincall_basin` |
| 10/11 | A Dry-Handled Axe / Stone Beneath the Moss | shared tool items |

## Local acquisition audit

Every named target is registered in `mods/ENTITIES/grug_mobs`. The start and
home-zone checks use the closed tables in `spawn_policy.lua`: settled supplies
the correct boar variant and zombie; each culture-specific family is explicitly
enabled in the named zone shown above. Bandits and archers have no ABM by
design; the six `bandit_home` anchors are their authoritative camp source.
`mobs:meat_raw` is a guaranteed one-to-two drop from all three boar variants,
so four meat requires no low-rate grind. Both lesson tools are registered in
`mods/BASE/default/tools.lua` and are ordinary provenance-free turn-ins.

The potentially sparse mobs (rare elites, tusks, leather, random cultural
drops) are absent from objectives. Passive animal kills are used sparingly and
only where the named-zone palette provides them. The catalog assumes Round 14
POI integration places the six camp families and the three required quest
sockets per culture; validation must fail if an anchor/socket is missing.
