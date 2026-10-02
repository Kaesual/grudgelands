# Round 28 reconciled catalogue

C1 editor handoff, 2026-10-02, under the
[approved frame](../../../round28-design-frame.md). The JSON is ready for
Opus review and C2 authoring. It specifies ingredients and encounters;
the zone lanes still supply their actual locations, quests and route ledgers.

## Contents and counts

| File | Content |
|---|---|
| [subtypes.json](subtypes.json), [tints.json](tints.json) | 188 roles, including 49 unique leaders (37 normal through L59, 12 optional elites); nine reused skins/modifiers |
| [items.json](items.json), [drops.json](drops.json) | 119 items: 94 signatures and 25 existing generic materials; 24 drop families, 86 occurring family/band pairs |
| [enchants.json](enchants.json), [reagents.json](reagents.json) | Six tiers, all 54 stat bindings and 66 equipment-family inputs; zero new universal reagents |
| [world.md](world.md), [economy.md](economy.md) | Encounter vocabulary, required supply packages, profession shopping lists |
| [bounties.md](bounties.md), [calibration.md](calibration.md), [samples/](samples/) | Repeatable rules, XP/copper guidance and six arithmetic fixtures; not zone quest files |

**New item count = C4 icon count.** Counts below exclude later quest props
that have not been designed. Every new entry has an icon brief. The 30
reused items and six existing metal bars in drops need no new icon.

| Tier | Signatures | Reused signatures | New items / icons | New reagents | New quest props |
|---|---:|---:|---:|---:|---:|
| T1 | 11 | 2 | 9 | 0 | 0 |
| T2 | 17 | 2 | 15 | 0 | 0 |
| T3 | 21 | 0 | 21 | 0 | 0 |
| T4 | 19 | 1 | 18 | 0 | 0 |
| T5 | 10 | 0 | 10 | 0 | 0 |
| T6 | 16 | 0 | 16 | 0 | 0 |
| **Total** | **94** | **5** | **89** | **0** | **0** |

The editor previously pruned four unused early dental/strap alternatives,
three redundant crab eyes and six unassigned quest props. The review pass
preserves Rotting Flesh, Bear Claw, Slime Gel, Venom Sac and Stone Core as
**generic existing recipe inputs** across bands. Four of their old signature
slots need no replacement trophy. Only T1 health enchanting gains a new
signature, **Tattered Flesh**, keeping the flesh motif without tier-locking
Rotting Flesh. Net review change: **88 → 89 icons**, not five new trophies.
All 89 briefs specify a distinct silhouette, material and colour; higher
tiers are recognisable by shape and wear as well as palette. No new reagent.

## Stat loot by tier

One application consumes **one own profession material + one listed
signature + one family input**. Prefix and suffix each cost that amount.
The stat input is identical across professions. Existing equipment stat
pools still apply: a shared ingredient does not grant a new stat choice.

The following are item suffixes, all prefixed **`grug_mobs:`**. Their
display names use the same words, for example `last_laugh_dentures` is
**Last-Laugh Dentures**. `tattered_flesh` is **Tattered Flesh**; the separate
generic `zombie_flesh` retains **Rotting Flesh**. Grouped columns mean
separate stats sharing one ingredient.

| Tier | Strength / Critical chance | Dexterity / Attack speed / Dodge | Intelligence / Maximum mana | Maximum HP | Armor rating |
|---|---|---|---|---|---|
| T1 | `boar_tusk` | `rat_tail` | `crab_eye` | `tattered_flesh` | `rat_fur_patch` |
| T2 | `ridged_boar_tusk` | `sinewy_rat_tail` | `clear_crab_eye` | `foul_flesh` | `dense_rat_fur` |
| T3 | `stubborn_molar` | `balanced_weapon_strap` | `coded_talisman` | `pickled_flesh` | `balanced_weapon_strap` |
| T4 | `gritted_teeth` | `reinforced_weapon_strap` | `campaign_talisman` | `leathery_flesh` | `reinforced_weapon_strap` |
| T5 | `clenched_jaw` | `siege_weapon_strap` | `siege_talisman` | `scorched_flesh` | `siege_weapon_strap` |
| T6 | `last_laugh_dentures` | `unbroken_weapon_strap` | `last_pay_talisman` | `salt_cured_flesh` | `unbroken_weapon_strap` |

Five ingredients teach the five motifs in T1/T2. From T3, straps supply
balance and protective seams, giving four ingredients. Eyes become marked
talismans when the route leaves reliable crab beaches. No Fox Tail, rare
trophy, elite drop or island material is a universal stat requirement.

## B2 loot dispatch and band coverage

**Zone authors use catalogue subtype roles for every combat source in this
design.** The family names in the supply/cast tables are shorthand for
those subtypes, not existing mob roles to paste into `areas.species`.
Select a `role` from `subtypes.json`, keep its area levels inside its
`levels`, and use that same role in kill objectives and quest-drop sources.
Critters and the frame's unchanged populations keep their separate rules.

B2 resolves a subtype's loot through its explicit **`drops`** field.
Neither its `base` factory nor its combat `family` makes other registrations
inherit that table. An **existing** mob receives a table only if the drop
family is named exactly after its role, without `grug_mobs:`. For example:

| Intended source | Use an authored role | Why the existing role is insufficient |
|---|---|---|
| T1 rat | `large_rat` (L1–3), `drops: rat` | `giant_rat` does not match family `rat` |
| T1 crab | `quiet_shore_crab` (L3–5), `drops: crab` | Existing `shore_crab` has no matching `crab` table |
| T1 bandit | `confused_bandit` (L9–10), `drops: outlaw` | `bandit` does not match `outlaw`; neither do `bandit_archer` or `poacher` |
| T3/T4 wolf | `briarpack_wolf` (L21–40), `drops: canid` | `wolf` does not match `canid`; shared fangs are not inherited by the base |
| Sunscar undead | `befuddled_husk` (L3–5), `drops: zombie` | `sun_dried_husk` does not match `zombie` |

Exactly **seven** current drop-family names also match existing roles:
`boar`, `zombie`, `fox`, `bear`, `crocodile`, `mirefolk`, `wisp`.
B2 therefore applies their covered-band tables to those exact existing
registrations too. This does not include lookalikes such as `plague_boar`,
`jungle_boar` or `plaguehide_bear`. Even where a name matches, the authored
zone design uses subtypes for its intended levels, disposition and drops.
No family rename or duplicate base-role table is needed.

**A missing or empty band retains the actor's old static drops; it does
not mean no loot and does not borrow a neighbouring band's table.** Never
use that fallback as a designed supply source. Audit of `subtypes.json`
against `drops.json`: **188 roles, 224 role/band combinations, zero missing
or empty bands**. Their required union is exactly the catalogue's **86
nonempty family/band pairs**:

| Drop families | Bands required by their subtype level ranges, all populated |
|---|---|
| `boar`, `fox` | T1, T2, T3 |
| `rat` | T1, T2 |
| `crab`, `grazer` | T1, T2, T3, T4, T6 |
| `zombie`, `outlaw`, `feline`, `venomous` | T1–T6 |
| `canid` | T2–T6 |
| `bear`, `weevil`, `spider` | T3, T4, T6 |
| `crocodile`, `ooze`, `mirefolk` | T2, T3 |
| `wisp`, `goblin` | T2, T3, T4 |
| `treant` | T3, T4 |
| `ape`, `witch` | T4, T6 |
| `skeleton`, `scavenger`, `stone` | T3–T6 |

Other bands are absent because **no authored member can occur there**;
in particular, there is no T5 crab or spider. Do not widen a subtype's
level range or substitute its base without revisiting this table. A
capital subtype spanning L20–25 needs both T2 and T3; both are present.
The `zombie` table covers all six bands, including the L15 case.

Unconverted palette spawns, underground actors and named rares are outside
this authored surface supply proof. For an exact-name base match, B2 still
uses a populated band there; outside that family's listed bands its static
fallback is intentional. For a nonmatching base name the new family does
not apply at all. Neither case is counted toward these quests or enchant
availability. This is not a promise that every unchanged actor keeps its
old loot: unchanged spawning and loot dispatch are separate concerns.

## Supply on all six tracks

These are **requirements for future spawn files**, not claims about the
current engine palettes. `world.md` gives the fuller cast; all required
sources below are normal-tier roles in `subtypes.json`.

| Race / faction | T1: boar, rat, crab, undead | T2: boar, rat, crab, undead | T3: outlaw + undead, L21+ | T4: outlaw + undead |
|---|---|---|---|---|
| Dwarf / Accord | Hearthpine Vale, zombie | Copperfell Foothills, zombie | Dur Brannoc outskirts | Stormvault Heights |
| Human / Accord | Dawnmere Fields, zombie | Goldmead Vale, zombie | Highcourt outskirts | Ashenward March |
| Elf / Accord | Silverleaf Glades, zombie | Starbough Vale, zombie | Lethariel outskirts | Glassroot Wilds |
| Undead / Throng | Stillgrave Hollow, zombie | Mournfen, zombie | Nhal Veyr outskirts | Blackwind Rise |
| Orc / Throng | Sunscar Flats, husk | Redtusk Savanna, husk | Gor Drazhak outskirts, husk | Bannerbreak Mesa, husk |
| Troll / Throng | Kapok Cradle, zombie | Raincall Basin, zombie | Kezamba outskirts | Thunderroot Wilds |

T1 ordinary sources are `small_boar`/`aggressive_boar`, `large_rat`/
`rabid_rat`, `quiet_shore_crab`/`giant_crab`, and the introductory zombie
or husk roles. T2 uses `young_boar`/`bristling_boar`, `granary_rat`/
`mangy_rat`, `tidepool_crab`/`reefclaw_crab`, and the home-band undead.
Both boar lookalikes use the `boar` table; husks use `zombie`. Thus the
four families supply all five exact ingredients in each individual zone.

T3 uses `toll_bandit`/`toll_bandit_archer` and `debtbound_zombie`/
`stubborn_zombie`, with the matching sunproof husks for daytime caches. Place an
ordinary L21–25 source of **both** families: L20 yields T2, and the later
archer must not be the first talisman source. T4 uses `entrenched_bandit`/
archer and `marching_zombie`/`unrelenting_zombie`, or matching husks.

**T5, both factions:** Shattered Line has `siege_deserter`/archer and
`siege_husk`/`unburied_husk`; The Broken Causeway (41–50 since Round 28 W1)
has `causeway_brigand`/`causeway_aqueduct_bowman` and
`causeway_mire_husk`/`causeway_ford_zombie`. **T6, both factions:** each of Gravesalt and
Skyglass has `saltroad_deserter`/`last_pay_archer` and `saltbound_zombie`/
`last_watch_zombie` on blight ground, or their sunproof husk counterparts.
Each pair supplies straps/talismans and flesh/teeth
respectively. The islands offer extra T6 supply; they are never required.

**Raincall Basin is the tightest T2 sea coast:** 4,464 nodes² in the atlas,
compared with Copperfell's 5,616. Use Raincall's west/northwest B1 strip
(L11–13, 3,856 nodes²) and its small B2 patch (L13–14, 592 nodes²);
Copperfell uses its southwest B1/B2 strips. Both need real `shore: true`
areas, small crab requests and measured throughput. No inland crab circles.
Highcourt and Shattered Line have no sea beach; T3+ stats do not need one.

### Daytime supply is mandatory

Night lasts five minutes of the twenty-minute cycle. Each race track must
have **at least one day-available normal source of every stat ingredient**
in its own band, including a source in the lower half. A spawn with
`clock: "night"` that might survive sunrise does not prove this.

- Boars and shore crabs use `clock: "day"`. T1/T2 rats retain night field
  populations and gain a dry burrow/granary supply area with `clock: "both"`.
- Outlaw camps, hideouts and supply caches use `clock: "both"`, including
  poacher camps. Night-only roamers remain an additional encounter choice.
- Flesh/teeth come from a `clock: "both"` corpse-cache area. Use the matching
  **sunproof husk** role on ordinary terrain. A zombie is acceptable only
  when spawned on real blight dirt; canopy shade and clock alone do not
  remove sunlight damage. Stillgrave/Mournfen/Nhal Veyr/Blackwind/Gravesalt
  may use that verified blight host; otherwise use husks there too.

The route table's zombie/husk labels describe the outdoor regional cast;
these corpse caches supplement it. Start caches use `befuddled_husk` then
`sluggish_husk`; homes use `muttering_husk` then `parched_husk`; capitals
use `debtbound_husk` at L21+ then `stubborn_husk`; contested zones use
`marching_husk` then `unrelenting_husk`. Shattered Line uses `siege_husk`/
`unburied_husk`. Both T6 mainland choices can use `saltbound_husk`/
`last_watch_husk`. Their explicit `drops: zombie` supplies the same stats.
Caches tell one reusable story: outlaws stockpile sun-dried remains;
undisturbed fields still teach the local day/night cast. C2/C3 must record
source role, area, level, clock and actual host for each stat/route.

## Solo leaders and zone additions

Every mainland zone now has a normal named leader, with an extra L24
Whitebridge leader for a shorter selected line. All 12 elite leaders remain
optional Group work. A normal leader uses a fixed spot and a 300-second
respawn, with an approach that permits a solo pull; its helpers are counted
separately. Mandatory leaders must survive and be reachable during daylight.
Mortuary Clerk Hush therefore requires actual blight dirt at his fixed spot.

| Zone | Added normal climax (level) | Optional elite stays separate |
|---|---|---|
| Whitebridge | Basket-Poacher Thorn (24); Ferryman Murk (30) remains | — |
| Ashenward | Quartermaster Scrip (33) | Red-Receipt Marshal |
| Stormvault | Bolt-Chewer (36) | Split-Seam Warden |
| Glassroot | Basket-Biter (39) | Canopy-Knuckle |
| Blackwind | Grave-Broker Mute (37) | Hollowbell Treant |
| Bannerbreak | Provisioner Rattle (37) | Banner-Eater |
| Thunderroot | Bottle-Keeper Zek (39) | Storm-Bottle Witch |
| Broken Causeway | Toll-Taker Senn (49) | Last-Toll Construct |
| Shattered Line | Standard-Bearer Ninepins (48) | Engine Nine |
| Gravesalt | Watch-Captain Huskell (58) | Salt-Counter Witch |
| Skyglass | Paymaster Chirr (58) | Glass-Throat Serpent |

**Coordinator ruling:** C2/C3 may add their zone's leader roles and
quest-only items in `docs/planning/round28/design/zones/<zone_id>.catalog.json`:

```json
{"subtypes": [], "items": []}
```

Use the same row schemas as global `subtypes.json` / `items.json`; new items
here have `kind: "quest"`. Global catalogue entries remain the shared base.
Use unique roles/item ids across all catalogues, no overrides or duplicated
registrations. Added normal leaders can close intermediate 21–30 or later
solo lines; they need actual fixed spots in `spawns.json`, quest references,
level fit, a solo pull and ledger accounting. Props need a concrete quest,
drop source, icon brief and addition to the zone's icon count. Guaranteed
leader evidence avoids a second five-minute respawn wait. The coordinator
is extending the tools to load these files; the current global-only 0/0
validation is not certification of a future zone extension.

No subtype may turn a critter base into neutral/aggressive combat. Marrow
and Salt-Boring Weevils use attacking `stone_mite` with the existing
`bone_weevil` texture in Ossuary/Blackwind/Gravesalt. The original critter
remains unchanged. Names follow the frame's naming rule (§5, user
2026-10-02): signal words only on start-zone roles, one ladder there, own
names elsewhere. Aggressive Rat (1.15) exceeds Large Rat (1.05). Stillgrave's Young Gaunt Stag is a neutral L5–7 day grazer.
All bear/ape roles retain authored tiers; none depends on random promotion.

## Supply and consumption

All ordinary loot is shared between party members. Rows roll independently;
having two signatures does not make them alternatives. Normal leaders
are bonuses, never the production plan. Bars remain one at 1-in-50 from
ordinary humanoids/undead, 1-in-25 from elite stone families.

| Input | Final yield per ordinary source kill | Two applications from empty, mean kills |
|---|---:|---:|
| T1/T2 tusk; T3–T6 tooth | 1 at 1-in-3 | 6 |
| T1/T2 tail, fur, eye; all flesh; T3–T6 talisman | 1 at 1-in-2 | 4 |
| T3–T6 strap (four stats) | 1 guaranteed | 2 |
| Other regional signatures | Usually 1 at 1-in-3; T1 crab leg 1-in-2 | Budget the actual row |

A Scout's eight-slot example (four leather pieces, bow, dagger, two
trinkets; two channels each) can consume **14 straps + 2 teeth**: armor
Dexterity/Dodge, weapons Dexterity/Speed, trinkets Dexterity/Crit. That is
14 outlaws + 6 undead in mean supply, down from 42 + 6 with the inherited
rates. A cloth caster choosing Intelligence/Mana throughout consumes
16 talismans: 32 outlaws, down from 48. These are optional full-set
shopping plans across several professions, not solo leveling prerequisites.
The first two applications are the useful onboarding measure. Replacing
affixes repeats the bill; re-enchanting every slot each band is optional.

At T1/T2, eight rats yield four tails and four fur on average; a two-fur
request leaves enough mean stock for two Armor applications and saves the
tails. Five crabs yield 2.5 eyes and, at T1, 2.5 legs: ask for at most two
legs, keeping eyes for the caster. A single 1-in-2 source gives at least
two items in five kills with 81.25% probability, not certainty. The duo
needs twice the total stock. These are supply estimates; do not count
expected inventory as a guaranteed quest completion or a spawn-rate test.

For C2/C3 request authoring:

- T1/T2 compulsory quests consume **at most two of any one stat ingredient
  per player's whole band**, and none of its crab eyes. Prefer legs, local
  Fox Tails or another non-enchant signature. Reserve two of the chosen
  first-enchant input when calculating extra kills; do not spend them twice.
- From T3, compulsory material requests avoid the four common enchant
  ingredients entirely. Use regional signatures, generic surplus or an
  actual quest-only evidence item. Repeatable recovery orders also avoid
  the common stat ingredients; a hunt can add to that stock instead.
- A local request normally consumes one or two signatures; a scarce or
  optional elite source only one. Do not turn every available ingredient
  into a quest. Count all additional drop kills in the route ledger, and
  count repeated consumption across selected lines, zones and party members.

## Existing recipe materials

No recipe or profession gate changes here. Generic feedstock retains its
registered name/id and may span bands; signature and metal tiers match
the dropped band. The economy's own-material table still applies.

| Demand | Preserved supply and practical implication |
|---|---|
| Thread; patch/woven/heavy bolts | Undead/outlaws give linen scraps at 1-in-2 in every band, plus the band's cloth at 1-in-2. One scrap makes two thread; T1 uses its scraps for both bolt and thread. |
| Silkweave/silk/stormweave bolts | Spiders at T3/T4/T6 give 1–2 Spider Silk per kill. T5/T6 outlaws give 1–2 at 1-in-2: recovered cloth from equipment, with no extra reagent. |
| Sleek/nightscale leather | T5/T6 felines give Sleek Pelt at 1-in-2. Shattered Line has tigers; Skyglass has panthers. Nightscale also needs Scaled Hide from venomous enemies or the existing universal leather chain. |
| Current alchemy and ornaments | Venom Gland remains on spiders; Crocodile Tooth on crocodiles; Shiny Scale on mirefolk. They are additional existing generic feedstock, not renamed tier signatures. Underground sources remain unchanged. |
| T2 Basic wand/staff | `zombie_flesh` (Rotting Flesh) stays generic at 1-in-2 on the zombie family T1–T6, including sunproof husks. T1 HP instead uses Tattered Flesh; both roll independently. |
| T3 alchemy; T4 Basic wand/staff | `bear_claw` stays generic at 1-in-3 on bears T3/T4/T6. Normal Bramble Bears (Bonewood Plaguehide Bears in Blackwind) in Ashenward/Glassroot and Blackwind give mainland T4 access. |
| Slime Gel recipes and Mournfen collection | `slime_gel` stays generic at 1-in-3 on ooze T2/T3. Mournfen's Bubbling Bog Ooze supplies it from L11; Whispering/Totemwater remain alternatives in T3. |
| T4 alchemy; T6 Basic wand/staff | `venom_sac` stays generic at 1-in-3 on venomous families T4/T5/T6. Skyglass's normal Glass-Fang Serpent supplies it at T6; no island or elite dependency. |
| T6 ornaments/alchemy and mainland stock | `stone_core` stays generic at 1-in-3 on stone families T3–T6: Frostbarrow/Speargrass, Stormvault/Bannerbreak/Causeway, Shattered Line and Wyrmglass. Mainland stone encounters are optional elites; stock can be gathered earlier. The unchanged normal underground `stone_mite` also retains Stone Core at 1-in-8; its role does not match `stone`, so no family override removes that alternative. Never use a core request as mandatory solo leveling. |
| T5 Basic wand/staff; T6 alchemy | Sharp Feather remains on T3–T6 scavengers at 1-in-2. A T6 recipe's ingredient metadata must not remove its earlier T5 equipment source. |

Two T1 Tailor applications require four scraps for bolts plus one scrap
for two thread: five scraps, ten undead/outlaw kills in mean supply,
before the chosen signature and mineral. Two T5 applications need four
silk and one scrap, plus two signatures and two stormkelp: about 5.33
outlaw kills supply the silk; talismans and scraps arrive on the same
kills. Two T6 applications use two silk, one scrap and **four** stormkelp
(two in bolts, two as family input). Inputs with the same id add together.
These figures cover enchants, not fabrication of the base equipment.

## Regional request ingredients

The remaining regional signatures give each local family a request purpose.
Bear T3, ooze T3, venomous T4 and stone T6 use their existing generic
recipe material for these requests and need no separate signature.
Small Cat Claw deliberately relabels existing `grug_mobs:raptor_claw`; its
id and icon stay, and all authored sources are cats. The following
are request briefs for zone authors, using that family's exact item of the
band in `items.json`; no new crafting output or extra line is implied.
They belong within the already budgeted pantry, provisioning or recovery
lines. If a family/band is omitted or no quest claims its ingredient in the
completed C2/C3 design, remove that unused signature and its icon before E/C4.

| Family / relevant bands | Request purpose to claim in its local zones |
|---|---|
| Boar T3 | Gnarled tusk for a broken field-marker peg; Highcourt/Whitebridge |
| Crab T1/T2/T3/T4/T6 | Legs for the start cook; shells for shore equipment repairs; T6 reef repair optional Group only |
| Fox T1–T3 | Tails for soft dust brushes and instrument cleaning; Accord tracks |
| Outlaw T1/T2 | Talismans as evidence of which gang stole the town's supplies |
| Grazer T1–T4/T6 | Sinew for carrying frames and splints; local grazers, island ram order optional |
| Feline T1–T6 | Claws to identify a livestock predator or snagged camp line |
| Canid T2–T6 | Fangs to identify the pack raiding stores; T2 Fang also has existing alchemy uses |
| Bear T3/T4/T6 | Claws from damaged forage stores; generic Bear Claw also serves current recipes |
| Crocodile T2/T3 | Tier tooth as evidence from damaged reed baskets; the generic Crocodile Tooth still serves recipes |
| Ooze T2/T3 | Gel for sealing sample jars; generic Slime Gel also serves alchemy/ornaments |
| Mirefolk T2/T3 | Pearls recovered with disputed wetland offerings |
| Wisp T2–T4 | Motes as samples for the local night-watch investigation |
| Treant T3/T4 | Resin for weatherproof labels; Ossuary, Blackwind and Ashenward |
| Weevil T3/T4/T6 | Chitin for patching specimen boxes; Undead forests and Gravesalt |
| Ape T4/T6 | Hair snagged around stolen offerings; forest tracks and Skyglass/Stormscale |
| Venomous T1–T6 | Samples identifying poisoned provisions; generic Venom Sac keeps its existing uses |
| Spider T3/T4/T6 | Coarse silk, layered web and glass silk as samples of blocked trails; generic Spider Silk stays with the crafter |
| Goblin T2–T4 | Stolen purses returned to the local supply clerk |
| Skeleton T3–T6 | Marked bones identify a patrol's origin; ordinary Bone remains separate |
| Witch T4/T6 | Bottle shards as evidence at poisoned stores; no promise of a new antidote recipe |
| Scavenger T3–T6 | Tier feathers for wind-marker repairs; generic Sharp Feather kept for recipes |
| Stone T3–T6 | One core for an optional Group survey; generic Stone Core also has current recipes |

## Validation and remaining zone work

Run from the repository root:

```sh
python3 -B tools/r28_design/validate.py --design docs/planning/round28/design --atlas docs/planning/round28/zones
```

Editor result: **0 errors, 0 warnings**. There are no zone files yet;
`W-loot-track` is therefore not exercised, and the tool emits no
`W-loot-unchecked` when an entire tier lacks designed zones. This silent
case is not evidence of availability. The supply matrix above is the
authoring obligation. Once zones exist, resolve every `W-loot-track`;
`W-loot-unchecked` may remain only for explicitly unfinished lanes.

The six calibration fixtures remain arithmetic examples of solo/duo XP;
they are rerun through `ledger.py` using the adapter in `calibration.md`.
All six solo shares remain within tolerance after binding real leaders; five duo questing undershoots
are explained by shared combat XP (Home is within tolerance). The four-tusk stress example
does **not** override the two-item introductory request budget above.
The real route ledger must use the integrated drops and actual area tags.

Additional editor checks pass: exact item names and enchant-use labels,
signature tiers and family occurrence, every retained item's drop source,
the two-signature ceiling, non-critter attacking bases, complete band
coverage and all nine tint references. The actual ledger also
reproduces the T3 shopping examples: 20 Scout / 32 caster kills for the
full-set signatures, or 2 / 4 for their first two weapon applications.
Those checks verify catalogue arithmetic, not authored zone placement.
The B2 follow-up also checks every subtype's full inclusive level range
against nonempty band rows, with no exceptions needed. The validator was
rerun as present on this branch; the coordinator's later tool alignment
has not been merged here. Rerun the aligned validator and real route
ledgers after integration, using the subtype-selection rule above.

Zone designers must still prove lower-band daytime supply, Raincall and
Copperfell shore throughput, the capital L20/T3 boundary and solo access to both T6
mainland sources. A crafted-item ledger does not reserve enchant inputs:
show the separate supply budget alongside XP, including shared duo loot.
Bind each regional request before art is commissioned; count any newly
authored quest-only prop. B2 must enforce the authored bear/ape tiers and
names, with no random promotion or leader renaming.

## Blockers / questions

No change to the frame or rulings is requested. Placement, throughput and
the regional requests cannot be certified before their zone files exist;
the required families and bounded request choices above are the recommended
handoff. Keep Round 28's current-price copper column until the coordinator
explicitly performs the separate WP44 cutover.
