# World catalogue: names worth remembering

The fields teach a small vocabulary: yellow animals can be approached, red
ones must be watched, night changes the company, and a familiar family is a
reliable material source. Later zones combine those lessons with existing
packs, archers, poison, webs, ambushers and telegraphs. They do not require a
new combat mechanic for every adjective.

This catalogue follows the [approved frame](../../../round28-design-frame.md).
Its cast below is the supply brief for the zone lanes, not a replacement for
their spawn areas. The [atlas](../../zones/index.md) supplies the geography;
the [mob catalogue](../../mobs/catalogue.md) supplies behaviour. Every one of
the 38 zones has a distinct, single-location leader role. Zone authors choose
the precise placement, quest counts and small local level slices.

## Names, appearances and encounters

- **Small / Young** always means a neutral animal in the lower part of its
  local progression. **Aggressive / Rabid / Giant / Monstrous** always means
  hostile and above its introductory counterpart. Large Rat is the explicit
  L1–3 hostile night lesson; size alone is not a promise of neutrality.
- Names such as Sluggish, Moaning and Confused describe character, not an
  undocumented speed, accuracy or intelligence modifier. Archers really
  shoot; scorpions and vipers really poison; web spiders really slow.
- Boars retain Plague/Jungle identities through zone names and the existing
  baked skins. Gaunt Stags, Blightfang Wolves and Plaguehide Bears similarly
  retain their regional appearance. An ochre rat is still a rat, not a new
  poison mechanic. Eight tint definitions suffice; other regional bases
  already carry their correct textures. Preserve multi-texture model slots
  when applying a baked skin; do not replace armour or held-item slots.
- Sun-Dried Husks use the **husk base**, never a recoloured zombie. They do
  not burn in sunlight. Zombies retain sunlight damage, the blight-ground
  exception and the Undead night truce. Drowned Zombies are walking shore
  enemies, not swimmers. Their quests must not promise daylight survivors
  away from blight ground.
- Ordinary rats, undead, outlaws, goblins, skeletons, witches, spiders and
  treants spawn at night. Grazers and boars spawn by day. Foxes and lynxes
  hunt by day; stalking panthers/leopards by night. Wolves and hyenas work
  both clocks, as do crocodiles, oozes and serpents. Start scorpions/vipers
  work both clocks; their older variants use night. Crabs use day and
  `shore: true`; this deliberately removes the old all-hour crab spawn.
  Clock is authored in **areas**, never inferred from tint or display name.
- Critters stay their existing registrations: rabbit/hare, wild turkey,
  song bird, parrot, bog fowl, gull and the unchanged underground/water
  critters. Ibex, tapir, zebra, ram, stag, Plains Runner and Carrion Crow are
  neutral combat animals, not critters. No critter is a quest kill target.
- A band needs two or three readable steps, not every catalogue role in
  every area. Use a neutral daytime fallback where appropriate and a
  separate night fallback; never leave Small Boars wandering at night just
  to fill space. Keep aggressive areas broad enough for the 32-node leash
  and the road/town drift. Camps use approximately 35–40-node radii,
  30–60-second slot refill and a 16-node player exclusion, as the frame says.

**Leaders:** all 26 leaders through level 30 are normal tier; all 12 later
leaders are optional Group climaxes. The solo budget cannot count their
kills or drops. A normal leader should be pulled separately from its helpers;
an archer plus a melee crowd is not made fair simply by having normal stats.
Each leader role belongs to exactly one zone, with a fixed level and a
300-second respawn. The frame's leader record has no clock field: do not
author a quest that relies on a night-only leader registration. Ordinary
night-spawn enemies can also remain alive into daylight.

The Dawnmere leader is `confused_bandit_chief`, displayed as **Confused
Bandit Chief Crumb**. Other starts get their own chiefs, with stolen ore,
wood, grave goods, water and offerings as distinct motives. Later names
offer a line opener as well as a finale: a toll receipt leads to Tollmaster
Penn; a missing ration reaches Ration-Broker Garr; a relentless demand for
payment ends at the Last-Toll construct. These names imply a problem to
resolve, not a scripted change to the world after the kill.

## Cast and family occurrence

Shared supply packages below are **required ordinary sources**, not new
POIs. Their members can occupy separate areas and clocks. A zone designer
must preserve the package or arrange an equivalent source within the same
permitted route. No recipe relies on the other faction, another race's
11–20 zone, a rare, a critter, an elite, or an island trip.

| Package | Zones | Ordinary role coverage |
|---|---|---|
| Start | Each of the six starts, T1 | Small/Aggressive Boar; Large/Rabid Rat, optionally Monstrous Rat; Shore/Giant Crab; Braindead/Sluggish/Drowned Zombie **or** the three start husks; Confused Bandit |
| Home | Each of the six home zones, T2 | Young/Bristling Boar; Granary/Mangy Rat; Tidepool/Reefclaw Crab; Moaning/Muttering Zombie **or** Muttering/Parched Husk; Quarrelsome Bandit/Watchful Bandit Archer |
| Capital | Each capital outskirts, level 20–30 | Toll Bandit/Toll Bandit Archer; Debtbound/Stubborn Zombie, or Debtbound/Stubborn Husk at Gor Drazhak |
| Contested | Each of the six faction contested zones and Causeway, T4 | Entrenched Bandit/Archer; Marching/Unrelenting Zombie, or the matching husks at Bannerbreak |
| Siege | Shattered Line, T5 | Siege Deserter/Archer; Siege-Worn/Unburied Sun-Dried Husk |
| Last watch | Gravesalt and Skyglass, T6 | Saltroad Deserter/Last-Pay Archer; Saltbound/Last-Watch Zombie |

The rat areas in the home zones, the capital outskirts populations, and
the later outlaw/undead supply pairs are deliberate authored additions to
the old effective palettes. They use existing families on land near the
existing hubs, hideouts or clash sites. Spawn areas replace palette/host
gates as specified by B1; these additions must appear in the zone JSON,
not merely be assumed from this document. Keep supply populations in the
lower half of the band as well as the upper half so an ingredient is not
locked behind the finale.

All six T1/T2 tracks have measured coast. Copperfell has the smallest T2
sea-beach footprint (5,616 nodes² in seed 42): use its actual shore strips
and small requests, never an arbitrary inland crab circle. Capitals,
Ashenward, Bannerbreak, Causeway and Shattered Line have no measured sea
beach. Crab loot is therefore **not** the universal stat source from T3
on. T6 crabs are optional elite Reef Lurkers in Gravesalt/Skyglass; there
is deliberately no T5 crab table.

The following regional cast is added to each shared package. Names are
atlas zone names; role notes in `subtypes.json` give the exact registrations
and ranges. An optional family is a choice for that zone, not a demand to
fill every spawn area with all of it.

| Track | Start additions | Home additions | Capital additions | Heartlands | Contested additions |
|---|---|---|---|---|---|
| Dwarf | Hearthpine: Small Fox, Young Ibex | Copperfell: fox, ibex, goblin melee/slinger/hound | Dur Brannoc: ibex, ram, goblins | Frostbarrow: ibex, ram, eagle, leopard, goblins, optional stone golem; crabs at shore | Stormvault: ibex, ram, eagle, leopard, goblins, Frost Stray, optional stone golem; shore crabs |
| Human | Dawnmere: Small Fox; turkey/rabbit critters | Goldmead: fox, poacher | Highcourt: boar, fox, stag | Whitebridge: boar, stag, wolf, bear, spider, wisp, mirefolk; shore crabs | Ashenward: stag, wolf, bear, spider, wisp, poacher, skeleton, treant, crow |
| Elf | Silverleaf: Small Fox, optional Furtive Poacher; song-bird critter | Starbough: fox, poacher | Lethariel: fox, stag, poacher | Lorindor: stag, poacher, wisp, mirefolk; Moonfall: stag, wolf, bear, spider, poacher, wisp; shore crabs in both | Glassroot: stag, wolf, bear, ape, serpent, panther, jungle spider, wisp, poacher; shore crabs |
| Undead | Stillgrave: plague boars; blight-ground zombie lesson, hare critter | Mournfen: plague boars, crocodile, ooze, wisp, mirefolk; bog-fowl critter | Nhal Veyr: plague boar, gaunt stag | Ossuary: gaunt stag, blightfang wolf, plaguehide bear, bonelurker spider, skeleton archer, treant, bone weevil; shore crabs | Blackwind: the Ossuary forest families plus March Skeleton Raider; shore crabs |
| Orc | Sunscar: Young Plains Runner, scorpions; husks replace zombies | Redtusk: zebra, hyena, scorpion; husks | Gor Drazhak: zebra, hyena, scorpion; husks | Speargrass: zebra, hyena, tiger, vulture, goblins, scorpion, optional mesa golem; shore crabs | Bannerbreak: hyena, tiger, vulture, crow, goblins, scorpion, skeleton, optional mesa golem; husks |
| Troll | Kapok: Young Tapir, Wary Jungle Lynx, vipers; parrot critter | Raincall: tapir, lynx, viper | Kezamba: jungle boar, tapir, lynx, viper | Whispering: tapir, lynx, crocodile, ooze, wisp, mirefolk; Totemwater: tapir, lynx, crocodile, ooze, wisp; shore crabs in both | Thunderroot: ape, serpent, panther, jungle spider, witch; shore crabs |

Heartlands can retain local populations instead of duplicating the capital
pair: each race already has both universal sources in its own capital.
The faction's other capitals provide alternative sources while travelling.
T3 still needs level **21+** sources: a level-20 capital mob drops **T2**,
even though that capital participates in the 20–30 journey.

| Shared zone | Local cast beyond its supply package | Climax |
|---|---|---|
| Broken Causeway | Skeleton Raider, Bog Witch, wisp, crow, optional War Construct | War Construct Last-Toll, L40 |
| Shattered Line | Hyena, tiger, scorpion, vulture, crow, Skeleton Raider, optional mesa golem/War Construct | War Construct Engine Nine, L50 |
| Gravesalt Escarpment | Blightfang wolf, gaunt stag, plaguehide bear, bonelurker spider, bone weevil, witch, skeleton, crow; optional Reef Lurker | Bog Witch Salt-Counter, L59 |
| Skyglass Canopy | Ape, serpent, panther, jungle spider, skeleton, crow; optional Reef Lurker | Serpent Glass-Throat, L59 |
| Wyrmglass Crown | L60 Last-Watch Zombie/Last-Pay Archer beside the existing apex camp; ram, eagle, leopard, Frost Stray, crow, optional stone golem | Stone Golem Rime-Bell, L60 |
| Stormscale Summit | L60 Last-Watch Zombie/Last-Pay Archer beside the existing apex camp; ape, serpent, panther, jungle spider, witch, skeleton, crow | Jungle Ape Last-Offering, L60 |

Rift Spawn, dragons, rares, water populations and underground populations
retain their current rules. Do not use self-removing Rift Spawn as kill or
quest-drop sources. No new subtype clones a dragon, guard or king.
Islands give additional endgame material/coin reasons to visit; they are
never required for the 50–60 leveling or enchanting supply promise.

## Loot that teaches where to return

`family` on a subtype controls combat kinship; `drops` selects its loot
family. The latter can be broader without linking combat behaviours:
wolf/hyena/hound share **canid** fangs; cats/tigers share **feline** claws;
ibex/ram/stag/zebra/tapir/Plains Runner share **grazer** sinew; scorpion,
viper and serpent share **venomous** samples; golems/constructs share
**stone** cores. Boars, rats, crabs, foxes and the remaining families keep
their own tables. A hound does not join a wolf pack merely because both
drop a fang. Bog witches keep their skeleton combat family and distinct
witch glass loot.

There are 24 drop families and 86 occurring family/band combinations.
Each has one signature, except rats, crabs, zombies and outlaws, which
have two. Higher bands keep a recognisable material type: tusks remain
tusks, teeth become braces and dentures, venom stays venom. The full
`drops.json` is the family-per-band occurrence list; missing combinations
are intentional, especially T5 crab and T5 spider. Generic meat, hide,
cloth, arrows, sticks and bones reuse existing items. Generic raw materials
may remain useful below the mob's band; metal and signature tiers do not.

Ordinary signature rolls are independent, usually **1 in 3**, one item.
Flesh and T1 crab legs are **1 in 2**. Thus five crab legs imply ten kills
before overlap, and five crab eyes imply fifteen: the zone ledger must
charge the actual drop demand, not treat a pantry request as free XP.
All ordinary drops are shared party loot. Quest-only props instead use
the frame's per-eligible-player hook; recommend a guaranteed chief's ledger
and 1-in-2 ordinary supply tags. Reuse a prop in sequential lines; separate
concurrently active requests with distinct quest items when they would
otherwise consume one another's evidence.

Metal bars are **1 in 50** for zombies, outlaws, skeletons and goblins;
**1 in 25** for elite stone/construct families, always one bar. The sequence
is bronze, iron, steel, silversteel, embersteel, abyssal steel. This is a
small recovery bonus, not a replacement for mining. No drop uses an alloy
from the wrong tier or Weaponsmith metal fittings.

The frame's `leader_bonus` is one flat list, not a per-band map. It therefore
adds modest existing generic material, never a signature or metal from a
different band. Stone leaders add quartz. A leader still rolls the normal
family table at its own level and can carry the quest's guaranteed prop;
signature farming never depends on the five-minute respawn.

## C1b handoff: available on every track

All ids below have prefix `grug_mobs:`. **Available** here is a design supply
commitment backed by the cast above; the final zone files and E reachability
measurements must prove it. Catalogue-only validation cannot prove spawn
placement or ingredient throughput.

| Stat | T1, every start | T2, every home | T3–T6, every permitted track |
|---|---|---|---|
| `str` | `boar_tusk` | `ridged_boar_tusk` | Band's dental item: a bite that holds |
| `dex` | `rat_tail` | `sinewy_rat_tail` | Band's weapon strap: balanced grip |
| `int` | `crab_eye` | `clear_crab_eye` | Band's talisman: counted knots and marks |
| `attack_speed_percent` | `rat_tail` | `sinewy_rat_tail` | Band's weapon strap: supple binding |
| `crit_percent` | `boar_tusk` | `ridged_boar_tusk` | Band's dental item: force at one sharp point |
| `max_hp_percent` | `zombie_flesh` | `foul_flesh` | Band's flesh: persistent vitality |
| `max_mana_percent` | `crab_eye` | `clear_crab_eye` | Band's talisman: bound intent |
| `dodge_percent` | `rat_tail` | `sinewy_rat_tail` | Band's weapon strap: freedom of movement |
| `armor_rating` | `rat_fur_patch` | `dense_rat_fur` | Band's weapon strap: reinforced seams |

| Tier | Flesh | Dental item | Talisman | Weapon strap |
|---|---|---|---|---|
| T1 | `zombie_flesh` | `broken_tooth` | `bandit_talisman` | `weapon_strap` |
| T2 | `foul_flesh` | `rusted_braces` | `knotted_talisman` | `braided_weapon_strap` |
| T3 | `pickled_flesh` | `stubborn_molar` | `coded_talisman` | `balanced_weapon_strap` |
| T4 | `leathery_flesh` | `gritted_teeth` | `campaign_talisman` | `reinforced_weapon_strap` |
| T5 | `scorched_flesh` | `clenched_jaw` | `siege_talisman` | `siege_weapon_strap` |
| T6 | `salt_cured_flesh` | `last_laugh_dentures` | `last_pay_talisman` | `unbroken_weapon_strap` |

All four items in **every row** of this second table also qualify as
available on every track: starts/home zones have their outlaw and zombie
or husk populations too. This offers C1b a compact four-item alternative
even in T1/T2. The first table is the preferred introductory mapping because
it rewards the taught daytime/nighttime/shore route, while spreading demand.
T1 `crab_leg` and T2 `ridged_crab_shell` are also universally available, but
reserved as pantry/local-material choices. Fox Tail is **not** universal:
do not make an Orc or Troll leave its route to enchant dexterity.

From T3 onward the four core sources occur in the own capital, then every
own-faction contested zone, then shared front zones. This is stricter than
merely relying on access to a sister race's zone or Broken Causeway. T6 has
both sources on **both** mainland front choices. Demand must still be
reconciled: four stats sharing a strap is a natural mapping, not evidence
that its drop rate supports a full equipment set. The editor must compare
C1b recipe quantities with these 1-in-3 rolls before freezing C2.

## Item and icon budget

New ordinary signatures are the tier-specific material vocabulary, not
extra enchant-only drops. Regional signatures support local requests and
optional material bounties; the editor/zone lanes must assign actual sinks
before implementation. They are not universally available enchant inputs.
No universal reagent is authored in C1a; any C1b additions are counted
separately by the editor.

| Tier | Signature items | Existing signatures reused | New signature icons | New quest-only icons | New icons total |
|---|---:|---:|---:|---:|---:|
| T1 | 13 | 3 | 10 | 1 | 11 |
| T2 | 19 | 2 | 17 | 1 | 18 |
| T3 | 24 | 2 | 22 | 1 | 23 |
| T4 | 21 | 3 | 18 | 1 | 19 |
| T5 | 10 | 0 | 10 | 1 | 11 |
| T6 | 18 | 2 | 16 | 1 | 17 |
| **Total** | **105** | **12** | **93** | **6** | **99** |

The inventory catalogue contains 126 entries: 105 signatures, 15 reused
generic items, six new quest props. Twenty-seven entries already have icons.
The six metal bars in the drop tables are existing items and add no icons.
The eight mob tints use existing textures/modifiers and add no skins or
icons. All new inventory items carry an icon brief for C4.

## Blockers / questions

- **Bear/ape inherited random elites:** their bases can randomly promote
  themselves on spawn, while subtype records explicitly say `tier: normal`.
  These records retain the existing behaviour as an optional hazard and do
  not use either family for universal stat supply; no 1–30 leader uses those
  bases. The frame has no separate promotion toggle. Before a zone makes
  these ordinary roles mandatory solo targets, confirm how B2 reconciles
  the inherited callback with the authored tier. Recommended: authored
  normal roles stay normal; existing unchanged base populations may retain
  their random elites. Fixed elite ape leaders must retain their catalogue
  name and tier rather than being renamed Silverback by that callback.
- **Final supply/demand and art total:** the 99 C1a icons exclude C1b's
  reagents and later zone-only props. Reconcile the stat mapping and recipe
  quantities with C1b before freezing C2. Recommended: keep the wildlife
  introduction for T1/T2 and the four-item common supply from T3; cut unused
  regional signatures if their family is omitted from the final zone casts.
