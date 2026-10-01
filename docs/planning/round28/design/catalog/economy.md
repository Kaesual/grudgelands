# Catalogue economy: know the creature, keep the mineral

The reconciled economy, under the approved
[frame](../../../round28-design-frame.md), especially §2.5 and §4.4–4.5.
The [enchant table](enchants.json) supplies all eleven equipment families
at all six tiers, with all nine stat keys filled. The
[catalogue README](README.md) records the exact stat table, supply packages,
drop quantities and request budgets. Zone placement and throughput remain
the C2/C3 and E lanes' acceptance work.

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
**0**. The reconciled world-wide count is **88 new signature icons**, with
no preallocated quest-only props; see the README's count by tier.

## Stat vocabulary

Use five memorable ingredient motifs for nine stats.
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
| `armor_rating` | Dense rat fur at T1/T2; reinforced weapon binding at T3–T6 | Protection comes from covering and reinforced seams. |

T1/T2 use tusks, tails, eyes, flesh and fur. Fur is the existing catalogue's
protective covering; no extra crab-shell enchant item is needed. Rat tails
and fur are separate drops, so the introductory mapping uses **five items**
for the five motifs. Crabs keep their legs/shell for pantry or repair orders.
Husks supply the same flesh as zombies without borrowing their sun damage.
Fox tails remain local quest ingredients, never universal Dexterity inputs.

From T3, dental parts, straps, talismans and flesh carry the same meanings.
A strap balances a weapon and reinforces an armour seam, covering two
motifs with one item. These **four items** come from normal outlaws and
zombies/husks in every route. Straps drop one per kill because they serve
four stats; focusing talismans drop at 1-in-2. This makes a cloth caster's
Intelligence/Mana plan and a Scout's Dexterity/Speed plan practical without
creating profession-specific loot. The nine-stat map is shared by all
professions; only the existing equipment stat pools restrict selections.

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
Leather and cloth supplies use the reconciled generic loot and existing
universal processing. Linen scraps remain available on later undead and
outlaws for thread. Spider Silk is generic recipe feedstock in every spider
band, and recovered silk also drops from T5/T6 outlaws. Shattered Line has
no spider family, so those salvaged bundles matter. These are existing
items, not new reagents or new profession dependencies.

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

- No frame change is needed. The exact bindings are closed; final route
  placement and throughput remain open in [README.md](README.md).
- The current-price copper rule and its coordinated WP44 cutover condition
  remain as recorded in [calibration.md](calibration.md).
