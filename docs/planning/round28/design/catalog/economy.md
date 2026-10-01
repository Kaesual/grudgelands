# C1b economy: know the creature, keep the mineral

Design input for the C1 editor, under the approved
[frame](../../../round28-design-frame.md), especially §2.5 and §4.4–4.5.
The [enchant table](enchants.json) supplies all eleven equipment families
at all six tiers. Each `stat_loot: {}` is deliberately a **PLACEHOLDER**:
the editor fills all nine stat keys from C1a's signature drops. An empty
map does not authorize an enchant without loot. Do not port these recipes
until that reconciliation is complete.

## A recipe players can remember

Every enchant consumes **one own material + one tier-matched signature
drop + one family input**. Prefix and suffix use the same bill, one
channel per application. The profession and tier gates remain unchanged.
The stat explains the creature part; the equipment family explains the
mineral or gathered input. Better tiers change the quality of the loot,
not the meaning of a tooth or a shell.

Bars are ordinary furnace/alloy products anyone can make. All gems in
`family_input` are **raw**, so a Woodcarver never needs a Goldsmith. The
Goldsmith makes its own settings and keeps its existing gem-cutting work
for its own equipment recipes. Weaponsmiths use bars directly; metal
fittings are removed, including from Woodcarver enchants. No enchant
uses another profession's grips, bolts, settings or cut gems.

[reagents.json](reagents.json) is intentionally empty. Tin, copper,
quartz, rough gems, coal, silver, the two late crystals, salt and kelp
already provide distinct ingredients. Turning any pair into a new powder
would add a craft and an icon without adding a useful choice. New universal
reagents per tier: **0 / 0 / 0 / 0 / 0 / 0**; new items and icons from C1b:
**0**. The world-wide signature/quest item count remains C1a/editor work.

## Stat vocabulary for the editor

Use five memorable ingredient motifs for nine stats where supply permits.
These are item *kinds*, not new item registrations or additional drops.

| Stat key | Signature item motif | Reason players can learn |
|---|---|---|
| `str` | Tusk, large tooth or biting fang | Force lives in the bite. |
| `crit_percent` | The same pointed part as Strength | The same point can also find a weak spot. |
| `dex` | Tail, flexible tendon or a dexterous raider's cord | Balance and precise movement. |
| `attack_speed_percent` | The same flexible part as Dexterity | Quick recovery between movements. |
| `dodge_percent` | The same flexible part as Dexterity | Balance also gets you out of the way. |
| `int` | Eye, sensory lens or a caster's focusing charm | Perception becomes understanding. |
| `max_mana_percent` | The same focus as Intelligence | A focus also holds power. |
| `max_hp_percent` | Tough flesh, marrow or a resilient tissue | Endurance is something the creature survived with. |
| `armor_rating` | Shell plate, carapace or dense bone plate | Protection comes from the outside. |

At T1, boar tusks, rat tails, crab eyes, zombie/husk flesh and crab shell
are useful candidates: rats and the boar lookalikes support the six starts,
crabs the coasts, and the Husk covers Sunscar's undead identity. These
are suggestions for C1a's actual signatures, **not** a claim that its
catalogue already supplies them. Fox tails are a good local quest request
but cannot be the sole universal T1 Dexterity input unless every race's
start supports that exact item. The same concern applies to jungle-only
venom, mountain-only cores and elven resin.

At T2–T6 keep the five motifs, with recognizably stronger adjectives on
the tier's existing signature items. Do not invent six grades of every
body part just to fill this table. A common, coherent signature may be
shared by related regional families; it counts against each family's
two-signature ceiling. If C1a needs more than five distinct items to make
the nine mappings coherent, availability wins over the five-item preference.

For **each** stat and tier, the editor records at least one ordinary,
solo-accessible source in every race track's band, on both factions.
T1/T2 supply must stay within that race's start/home zone. T3/T4 check each
race's designated band zones as the validator does, as well as the chosen
multi-zone route. T5/T6 supply must exist on the shared mainland front;
neither an island, a rare, an elite nor the underground is a required
source. Higher-tier lookalikes drop higher-tier parts, not a universal
low-tier part. Two compatible stats intentionally sharing a part is fine.

## The own-material spine

These are the existing own-material families; no extra processing step
is introduced by this catalogue.

| Tier | Weaponsmith / Armorsmith | Leatherworker | Tailor | Woodcarver | Goldsmith setting |
|---|---|---|---|---|---|
| 1 | Bronze bar | Light leather | Patch bolt | Seasoned wood | Tin |
| 2 | Iron bar | Cured leather | Woven bolt | Polished wood | Iron |
| 3 | Steel bar | Heavy leather | Heavy bolt | Hardened wood | Copper-inlaid steel |
| 4 | Silversteel bar | Scaled hide | Silkweave bolt | Inlaid wood | Gold |
| 5 | Embersteel bar | Sleek leather | Silk bolt | Lacquered wood | Gold-filigreed embersteel |
| 6 | Abyssal steel bar | Nightscale leather | Stormweave bolt | Heartwood wood | Gold-filigreed abyssal steel |

The metal spine is cumulative: bronze = copper + tin; iron is smelted
directly; steel = iron + coal; silversteel = steel + silver; embersteel =
silversteel + emberglass; abyssal steel = embersteel + abyssal crystal.
Each listed combination produces one bar. Settings use two tin bars,
two iron bars, steel + copper, two gold bars, embersteel + gold, and
abyssal steel + gold respectively. Wood grades use ordinary planks and
the previous grade; no tree species or culture is a mandatory gate.
Leather and cloth supplies remain C1a's generic loot plus their existing
universal processing. The editor must check those supplies alongside the
signature drops; a perfect stat table cannot repair missing cloth.

For that supply check, the existing universal material recipes are:

| Tier | Leather feedstock | Cloth feedstock |
|---|---|---|
| 1 | Ordinary leather + thread, or light-leather drops | 2 linen scraps + thread |
| 2 | Light leather + thread | 2 linen cloth + thread |
| 3 | Cured leather + thread, or heavy-leather drops | 2 heavy cloth + thread |
| 4 | Heavy leather + thread, or scaled-hide drops | Heavy bolt + spider silk + thread |
| 5 | Sleek pelt + thread | 2 spider silk + thread |
| 6 | Scaled hide + sleek pelt | Spider silk + stormkelp + thread |

One linen scrap makes two thread in the ordinary grid; vendors also sell
thread. These routes do not require learning Tailoring. In particular,
T6 Tailoring needs one kelp for its own bolt **and** one for the enchant's
family input. Equal ids in different ingredient slots add their quantities;
they are not deduplicated. The same applies when a T2 iron weapon or
shield consumes an iron bar in both its own and family-input slots.

## Mining and gathering shopping lists by profession

Read these as **additional family inputs**, one unit per enchant, on top
of the own material above and the stat loot. Slashes preserve equipment
family order, not alternative recipes. Repeated ingredients mean that
several families share one supply pile. Exact ids are in `enchants.json`.

| Tier | Weaponsmith: sword / dagger / greataxe | Armorsmith: armor / shield | Leatherworker | Tailor | Woodcarver: bow / caster weapon | Goldsmith: spellbook / trinket |
|---|---|---|---|---|---|---|
| 1 | Tin bar / quartz / copper bar | Copper bar / tin bar | Quartz | Quartz | Quartz / quartz | Quartz / copper bar |
| 2 | Copper bar / rough garnet / iron bar | Coal / iron bar | Copper bar | Quartz | Rough garnet / rough citrine | Rough citrine / rough jade |
| 3 | Coal / rough garnet / iron bar | Coal / iron bar | Rough jade | Rough citrine | Rough garnet / rough citrine | Rough citrine / rough jade |
| 4 | Silver bar / rough ruby / silver bar | Silver bar / rough diamond | Rough jade | Rough sapphire | Rough ruby / rough sapphire | Rough sapphire / rough diamond |
| 5 | Emberglass / rough ruby / emberglass | Emberglass / rough diamond | Rock salt | Stormkelp | Emberglass / emberglass | Rough sapphire / rough diamond |
| 6 | Abyssal crystal / rough diamond / abyssal crystal | Abyssal crystal / rough diamond | Rock salt | Stormkelp | Emberglass / abyssal crystal | Abyssal crystal / rough diamond |

Jewellery and flexible equipment preserve earlier-tier gems deliberately.
T3 does not pretend that a new gem stratum exists, and T6 does not send
every crafter to an island. Use `grug_gathering:rock_salt` and
`grug_gathering:stormkelp`, the harvested items, not their source nodes.
Both are existing T5 gathering items reused at T6. All additional inputs
are obtainable at or below their enchant tier; the item's harvest tier
can differ from its equipment tier (notably iron).

The complete shopping list is the row above **plus** the own-material
spine: a T4 Armorsmith gathers iron, coal and silver for the silversteel
bar, then another silver bar for armor or a rough diamond for a shield.
A T4 Woodcarver gathers planks and a rough ruby or sapphire, then hunts
the chosen T4 signature; no metalworking profession intervenes. A T5
Tailor combines its cloth supply with a signature drop and harvested kelp.
Each is a short plan, not a chain of appointments with other crafters.

## Knowledge is the second character's advantage

A new character remembers to keep a few quartz pieces and copper/tin
bars, saves flexible parts for agility builds, and plans night hunting
around a daytime gathering trip. A material request can consume loot
already earned on the hunt, so preparation saves travel and fighting.
The player sees every profession recipe in the book, including locked
tiers, and can save an earlier gem that remains useful later.

The advantage comes from route and source knowledge. It does not assume
a funded alternate character, a second profession, an auction market,
or access to another race's 11–20 zone. Normal quest requests take small
amounts of ordinary loot; avoid stripping the whole supply needed for
the player's first enchant. Bounty recovery orders use generic surplus
or quest-only recovery items where appropriate, not large compulsory
deliveries of scarce enchant signatures.

## Blockers / questions

- **Expected editor handoff:** all six `stat_loot` maps are PLACEHOLDERs.
  The available motif choices above were checked against the existing
  family atlas; exact ids and supply cannot be closed before C1a arrives.
  Recommend retaining the five motifs, then checking all nine stat keys
  and every race track against the integrated drop/spawn catalogues.
- No new design ruling is requested by C1b. The copper cutover condition
  and outstanding measurements are recorded in [calibration.md](calibration.md).
