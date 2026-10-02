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
the 38 zones has a distinct, single-location leader role; all 36 mainland
zones have a normal solo climax. There are 49 leaders in total. Zone authors choose
the precise placement, quest counts and small local level slices.

## Names, appearances and encounters

- Names follow the [frame's naming rule](../../../round28-design-frame.md#5-naming)
  (user, 2026-10-02): signal words (Small, Young, Large, Aggressive,
  Monstrous, Braindead, Sluggish, Confused) appear only in the six start
  zones, as one ladder; everywhere else each sub-type has its own name and
  the yellow/red name tag shows disposition. Large Rat is the explicit
  L1–3 hostile night lesson; size alone is not a promise of neutrality.
  Aggressive Rat is size 1.15, larger than Large Rat at 1.05; Monstrous Rat
  is 1.25.
- Names such as Sluggish, Braindead and Confused describe character, not an
  undocumented speed, accuracy or intelligence modifier. Archers really
  shoot; scorpions and vipers really poison; web spiders really slow.
- Boars retain Plague/Jungle identities through zone names and the existing
  baked skins. Gaunt Stags, Blightfang Wolves and Plaguehide Bears similarly
  retain their regional appearance. An ochre rat is still a rat, not a new
  poison mechanic. Nine tint definitions suffice; other regional bases
  already carry their correct textures. Preserve multi-texture model slots
  when applying a baked skin; do not replace armour or held-item slots.
- Sun-Dried Husks use the **husk base**, never a recoloured zombie. They do
  not burn in sunlight. Zombies retain sunlight damage, the blight-ground
  exception and the Undead night truce. Monstrous Drowned Zombies are walking shore
  enemies, not swimmers. Their quests must not promise daylight survivors
  away from blight ground.
- Night field populations include rats, zombies, outlaws, goblins,
  skeletons, witches, spiders and treants. **Outlaw camps/hideouts and other
  supply camps use `clock: "both"`**. T1/T2 tracks add both-clock dry rat
  burrows/granaries. Every stat has a day-available normal source per route;
  five minutes of night in a twenty-minute cycle is not a farming plan.
- Both-clock corpse caches use the band's sunproof husks. A daytime zombie
  source instead needs actual blight dirt at spawn; shade does not suffice.
  These small caches supplement the regional field cast in every race's
  start/home/capital/contested band and both T6 mainland routes. Use the
  lower-band roles as well as their successors; see the exact role ladder
  in [README](README.md#daytime-supply-is-mandatory). Never rely on a
  night-spawn survivor to prove day access.
- Grazers, boars, foxes and lynxes use day; stalking panthers/leopards use
  night. Wolves, hyenas, crocodiles, oozes and serpents work both clocks.
  Start scorpions/vipers work both; their older variants use night. Crabs
  use day and `shore: true`. Clock is authored in **areas**, never inferred
  from tint or name. Night roamers can coexist with both-clock camps.
- Critters stay their existing registrations: rabbit/hare, wild turkey,
  song bird, parrot, bog fowl, gull and the unchanged underground/water
  critters. Ibex, tapir, zebra, ram, stag, Plains Runner and Carrion Crow are
  neutral combat animals, not critters. No critter is a quest kill target
  or a base for a combat subtype. The two weevils use attacking Stone Mite
  (same crawler mesh, dogfight) with the existing Bone Weevil texture;
  the original Bone Weevil stays a critter.
- A band needs two or three readable steps, not every catalogue role in
  every area. Use exactly one fallback, as the frame/tool require, and
  broad ordinary area rules that cover the other clock if the fallback is
  day- or night-only. Never give Small Boars night spawns just to fill space.
  Keep aggressive areas broad enough for the 32-node leash
  and the road/town drift. Camps use approximately 35–40-node radii,
  30–60-second slot refill and a 16-node player exclusion, as the frame says.

**Leaders:** 37 normal leaders support solo climaxes through L59; 12 elite
leaders remain optional Group content from L31. The solo budget cannot
count elite kills or drops. Normal leaders must be reachable and separately
pullable from helpers; an archer plus a melee crowd is not made fair by
normal stats. Each role belongs to one fixed spot with a 300-second respawn,
available both clocks. The record has no clock field; zombies need verified
blight ground to survive daylight, including Mortuary Clerk Hush.

The [README leader table](README.md#solo-leaders-and-zone-additions) pairs
new normal resolutions with the optional elite challenges. One zone can
have several leaders; Whitebridge's L24 Basket-Poacher Thorn supports a
shorter line before L30 Ferryman Murk. C2/C3 may add zone leaders and
quest-only items in `zones/<zone_id>.catalog.json` using the coordinator's
extension rule in that README; shared ingredients remain global.

**Authored tier wins.** Bear and ape subtypes never roll the bases' random
Elder Bear/Silverback promotions. Their `tier` and display names remain as
authored; fixed elite ape leaders also keep their own names. The affected
subtype notes state this explicitly. Unchanged base populations outside
this catalogue keep their existing rules; no catalogue role or budget
depends on a random promotion.

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
permitted route. No universal stat ingredient relies on the other faction, another race's
11–20 zone, a rare, a critter, an elite, or an island trip.

| Package | Zones | Ordinary role coverage |
|---|---|---|
| Start | Each of the six starts, T1 | Small/Aggressive Boar; Large/Aggressive Rat, optionally Monstrous Rat; Small/Monstrous Crab; Braindead Zombie, Sluggish Zombie, Monstrous Drowned Zombie **or** the three start husks; Confused Bandit |
| Home | Each of the six home zones, T2 | Rooting Boar/Ridgeback Tusker; Granary Rat/Burrow Gnawer; Tidepool Crab/Reefclaw Snapper; Cairn Zombie/Pauper Shambler **or** Cairn Sun-Dried Husk/Pauper Mummy; Roadside Bandit/Bandit Lookout |
| Capital | Each capital outskirts, level 20–30 | Toll Bandit/Toll Bandit Archer; Debtbound Zombie/Tithe Revenant, or Debtbound Sun-Dried Husk/Tithe Mummy in daytime caches |
| Contested | Each of the six faction contested zones, T4 | Entrenched Bandit/Archer; Marching Zombie/Trench Shambler, or Marching Sun-Dried Husk/Trench Mummy in daytime caches |
| Siege | Shattered Line, T5 | Siege Deserter/Archer; Siege-Worn Sun-Dried Husk/Unburied Mummy |
| Causeway | Broken Causeway, T5 (41–50, Round 28 W1) | Causeway Brigand/Aqueduct Bowman; Mire-Cured Husk by day, Fordwater Zombie at night |
| Last watch | Gravesalt and Skyglass, T6 | Saltroad Deserter/Last-Pay Archer; Saltbound Zombie/Last Watchman on blight ground, or Saltbound Sun-Dried Husk/Last-Watch Mummy |

The rat areas in the home zones, the capital outskirts populations, and
the later outlaw/undead supply pairs are deliberate authored additions to
the old effective palettes. They use existing families on land near the
existing hubs, hideouts or clash sites. Spawn areas replace palette/host
gates as specified by B1; these additions must appear in the zone JSON,
not merely be assumed from this document. Keep supply populations in the
lower half of the band as well as the upper half so an ingredient is not
locked behind the finale.

All six T1/T2 tracks have measured coast. **Raincall is the tightest T2
coast (4,464 nodes²), followed by Copperfell (5,616)** in seed 42. Raincall's
west/northwest B1 shore has 3,856 nodes² at L11–13; B2 has only 592 at
L13–14. Copperfell uses its southwest strips. Give both real `shore: true`
areas, small requests and throughput checks; never an inland crab circle.
Capitals, Ashenward, Bannerbreak, Causeway and Shattered Line have no
measured sea beach. Crab loot is not a universal stat source from T3 on.
T6 Reef Lurkers are optional elites; there is no T5 crab table.

The following regional cast is added to each shared package. Names are
atlas zone names; role notes in `subtypes.json` give the exact registrations
and ranges. An optional family is a choice for that zone, not a demand to
fill every spawn area with all of it.

| Track | Start additions | Home additions | Capital additions | Heartlands | Contested additions |
|---|---|---|---|---|---|
| Dwarf | Hearthpine: Young Fox, Young Ibex | Copperfell: fox, ibex, goblin melee/slinger/hound | Dur Brannoc: ibex, ram, goblins | Frostbarrow: ibex, ram, eagle, leopard, goblins, optional stone golem; crabs at shore | Stormvault: ibex, ram, eagle, leopard, goblins, Frost Stray, optional stone golem; shore crabs |
| Human | Dawnmere: Young Fox; turkey/rabbit critters | Goldmead: fox, poacher | Highcourt: boar, fox, stag | Whitebridge: boar, stag, wolf, bear, spider, wisp, mirefolk; shore crabs | Ashenward: stag, wolf, bear, spider, wisp, poacher, skeleton, treant, crow |
| Elf | Silverleaf: Young Fox, optional Confused Poacher; song-bird critter | Starbough: fox, poacher | Lethariel: fox, stag, poacher | Lorindor: stag, poacher, wisp, mirefolk; Moonfall: stag, wolf, bear, spider, poacher, wisp; shore crabs in both | Glassroot: stag, wolf, bear, ape, serpent, panther, jungle spider, wisp, poacher; shore crabs |
| Undead | Stillgrave: plague boars, neutral L5–7 Young Gaunt Stag; blight-ground zombie lesson, hare critter | Mournfen: plague boars, crocodile, ooze, wisp, mirefolk; bog-fowl critter | Nhal Veyr: plague boar, gaunt stag | Ossuary: gaunt stag, blightfang wolf, plaguehide bear, bonelurker spider, skeleton archer, treant, bone weevil; shore crabs | Blackwind: the Ossuary forest families plus March Skeleton Raider; shore crabs |
| Orc | Sunscar: Young Plains Runner, scorpions; husks replace zombies | Redtusk: zebra, hyena, scorpion; husks | Gor Drazhak: zebra, hyena, scorpion; husks | Speargrass: zebra, hyena, tiger, vulture, goblins, scorpion, optional mesa golem; shore crabs | Bannerbreak: hyena, tiger, vulture, crow, goblins, scorpion, skeleton, optional mesa golem; husks |
| Troll | Kapok: Young Tapir, Aggressive Jungle Lynx, vipers; parrot critter | Raincall: tapir, lynx, viper | Kezamba: jungle boar, tapir, lynx, viper | Whispering: tapir, lynx, crocodile, ooze, wisp, mirefolk; Totemwater: tapir, lynx, crocodile, ooze, wisp; shore crabs in both | Thunderroot: ape, serpent, panther, jungle spider, witch; shore crabs |

Heartlands can retain local populations instead of duplicating the capital
pair: each race already has both universal sources in its own capital.
The faction's other capitals provide alternative sources while travelling.
T3 still needs level **21+** sources: a level-20 capital mob drops **T2**,
even though that capital participates in the 20–30 journey.

| Shared zone | Local cast beyond its supply package | Solo / optional Group climax |
|---|---|---|
| Broken Causeway (41–50) | Tollroad Skeleton, Sinkmire Viper, Fenrunner Wolf, crow, optional War Construct | Toll-Taker Senn, L49 normal / Last-Toll, L50 elite |
| Shattered Line | Hyena, tiger, scorpion, vulture, crow, Skeleton Raider, optional mesa golem/War Construct | Standard-Bearer Ninepins, L48 normal / Engine Nine, L50 elite |
| Gravesalt Escarpment | Blightfang wolf, gaunt stag, plaguehide bear, bonelurker spider, bone weevil, witch, skeleton, crow; optional Reef Lurker | Watch-Captain Huskell, L58 normal / Salt-Counter, L59 elite |
| Skyglass Canopy | Ape, serpent, panther, jungle spider, skeleton, crow; optional Reef Lurker | Paymaster Chirr, L58 normal / Glass-Throat, L59 elite |
| Wyrmglass Crown | L60 Last-Watch Husk/Last-Pay Archer beside the existing apex camp; ram, eagle, leopard, Frost Stray, crow, optional stone golem | Optional Stone Golem Rime-Bell, L60 elite |
| Stormscale Summit | L60 Last-Watch Husk/Last-Pay Archer beside the existing apex camp; ape, serpent, panther, jungle spider, witch, skeleton, crow | Optional Jungle Ape Last-Offering, L60 elite |

Rift Spawn, dragons, rares, water populations and underground populations
retain their current spawning/level rules. Loot dispatch still follows
the B2 exact-name rule in the [README](README.md#b2-loot-dispatch-and-band-coverage).
Do not use self-removing Rift Spawn as kill or
quest-drop sources. No new subtype clones a dragon, guard or king.
Islands give additional endgame material/coin reasons to visit; they are
never required for the 50–60 leveling or enchanting supply promise.

## Loot that teaches where to return

`family` on a subtype controls combat kinship; `drops` selects its loot
family. The latter can be broader without linking combat behaviours:
the authored wolf/hyena/hound subtypes share **canid** fangs; cat/tiger subtypes share **feline** claws;
ibex/ram/stag/zebra/tapir/Plains Runner share **grazer** sinew; scorpion,
viper and serpent share **venomous** samples; golems/constructs share
**stone** cores. Boars, rats, crabs, foxes and the remaining families keep
their own tables. A hound does not join a wolf pack merely because both
drop a fang. Bog witches keep their skeleton combat family and distinct
witch glass loot.

These names describe subtype supply. Existing base registrations do not
inherit a subtype's `drops` family. All designed combat populations must
use the catalogue roles, as specified in the README's B2 dispatch rule;
for example, existing `wolf` does not use `canid`. Every band touched by
any subtype's inclusive level range has nonempty rows. Missing bands are
outside those ranges, not an instruction to suppress the base's static loot.

There are 24 drop families and 86 occurring family/band combinations.
Most have one signature; rats and T1/T2 crabs have two, as do T3–T6
zombies and outlaws. Bear T3, ooze T3, venomous T4 and stone T6 instead
reuse generic recipe ingredients for regional requests, with no signature
needed in those four family/band pairs. Higher bands keep a recognisable material type: tusks remain
tusks, teeth become molars, jaws and dentures, venom stays venom. The full
`drops.json` is the family-per-band occurrence list; missing combinations
are intentional, especially T5 crab and T5 spider. Generic meat, hide,
cloth, arrows, sticks and bones reuse existing items. Generic raw materials
may remain useful below the mob's band; metal and signature tiers do not.

Ordinary signature rolls are independent, one item: usually **1 in 3**;
flesh, rat tails/fur, T1/T2 crab eyes, T1 crab legs and T3–T6 talismans are
**1 in 2**. T3–T6 weapon straps are **guaranteed**, reflecting four stats'
shared demand. Two crab legs imply four kills before overlap, not a
five-leg order hidden beside a five-crab hunt. The zone ledger must charge
the actual drop demand, not treat a pantry request as free XP.
All ordinary drops are shared party loot. Quest-only props instead use
the frame's per-eligible-player hook; recommend guaranteed leader evidence
and 1-in-2 ordinary supply tags. Author a prop only with its actual quest,
rather than pre-registering six tiered pieces of paperwork. Reuse a prop in sequential lines; separate
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

**Keep recipe feedstock working.** Rotting Flesh is now generic on zombies/
husks T1–T6 at 1-in-2; T1 health enchants use separate Tattered Flesh.
Bear Claw stays 1-in-3 on bears T3/T4/T6, Slime Gel 1-in-3 on ooze T2/T3
(including Mournfen), Venom Sac 1-in-3 on venomous families T4/T5/T6, and
Stone Core 1-in-3 on stone families T3–T6. Mainland stone sources at
T3–T5 permit earlier stock for later recipes; those elites are optional
Group material trips, not solo leveling prerequisites. Unchanged normal
underground Stone Mites retain their 1-in-8 Stone Core as an alternative;
their role does not match the `stone` table. These four generic
materials do not need a second trophy in their former signature slot.
The README's complete recipe-material table states the intended sources.

Spider Silk and Sharp Feather are generic
existing materials, not tier-exclusive signatures. Spiders still give silk
(1–2 guaranteed); T5/T6 outlaws salvage 1–2 at 1-in-2, keeping late Tailors
supplied without adding spiders to Shattered Line. Scavengers retain Sharp
Feathers at 1-in-2 in T3–T6; the existing T5 wand/staff recipes need them
before the T6 alchemy recipe does. Linen scraps remain 1-in-2 on all undead
and outlaws for thread; their band cloth also drops at 1-in-2. Felines drop
Sleek Pelts at 1-in-2 in T5/T6. Existing Venom Glands (spiders, 1-in-6),
Crocodile Teeth (crocodiles, 1-in-3) and Shiny Scales (mirefolk, 1-in-4)
remain generic inputs to current alchemy/ornament recipes. These ids keep
their existing recipe-tier metadata; that is not a new spawn-level gate.

## Available on every track

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
| `max_hp_percent` | `tattered_flesh` | `foul_flesh` | Band's flesh: persistent vitality |
| `max_mana_percent` | `crab_eye` | `clear_crab_eye` | Band's talisman: bound intent |
| `dodge_percent` | `rat_tail` | `sinewy_rat_tail` | Band's weapon strap: freedom of movement |
| `armor_rating` | `rat_fur_patch` | `dense_rat_fur` | Band's weapon strap: reinforced seams |

| Tier | Flesh | Dental item | Talisman | Weapon strap |
|---|---|---|---|---|
| T1 | `tattered_flesh` | — | `bandit_talisman` (requests) | — |
| T2 | `foul_flesh` | — | `knotted_talisman` (requests) | — |
| T3 | `pickled_flesh` | `stubborn_molar` | `coded_talisman` | `balanced_weapon_strap` |
| T4 | `leathery_flesh` | `gritted_teeth` | `campaign_talisman` | `reinforced_weapon_strap` |
| T5 | `scorched_flesh` | `clenched_jaw` | `siege_talisman` | `siege_weapon_strap` |
| T6 | `salt_cured_flesh` | `last_laugh_dentures` | `last_pay_talisman` | `unbroken_weapon_strap` |

The first table is the final enchant mapping: it rewards the taught
daytime/nighttime/shore encounters in T1/T2, while spreading demand.
Both-clock refuges ensure all five inputs can also be farmed during day. The second
table names the retained flesh and later common materials. The unused
T1/T2 dental/strap alternatives were removed. Early outlaw talismans
remain local requests, never a second recipe for the same stat.
T1 `crab_leg` and T2 `ridged_crab_shell` are also universally available, but
reserved as pantry/local-material choices. Fox Tail is **not** universal:
do not make an Orc or Troll leave its route to enchant dexterity.

From T3 onward the four core sources occur in the own capital, then every
own-faction contested zone, then shared front zones. This is stricter than
merely relying on access to a sister race's zone or Broken Causeway. T6 has
both sources on **both** mainland front choices. The editor's
[demand comparison](README.md#supply-and-consumption) sets one strap per
ordinary outlaw and keeps compulsory requests away from that shared pile.

## Item and icon budget

New ordinary signatures are the tier-specific material vocabulary, not
extra enchant-only drops. Regional signatures have request briefs in the
[README](README.md#regional-request-ingredients); each zone lane claims its
ingredients in actual quests before implementation. They are not universally
available enchant inputs. There are no new universal reagents.

| Tier | Signature items | Existing signatures reused | New signature icons | New quest-only icons | New icons total |
|---|---:|---:|---:|---:|---:|
| T1 | 11 | 2 | 9 | 0 | 9 |
| T2 | 17 | 2 | 15 | 0 | 15 |
| T3 | 21 | 0 | 21 | 0 | 21 |
| T4 | 19 | 1 | 18 | 0 | 18 |
| T5 | 10 | 0 | 10 | 0 | 10 |
| T6 | 16 | 0 | 16 | 0 | 16 |
| **Total** | **94** | **5** | **89** | **0** | **89** |

The inventory catalogue contains 119 entries: 94 signatures and 25 reused
generic items. Thirty entries already have icons.
The six metal bars in the drop tables are existing items and add no icons.
The nine mob tints use existing textures/modifiers and add no skins or
icons. All new inventory items carry an icon brief for C4.

## Blockers / questions

- No catalogue ruling remains blocked. Authored tiers, stat bindings and
  drop quantities are reconciled. Zone designers must prove the required
  sources, claim the regional request ingredients and count any quest props
  they actually add; see the README's open points.
