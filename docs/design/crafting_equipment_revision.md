# Crafting stations, enchanting and equipment — topic index

This stable path indexes the current crafting/equipment rules decided on
2026-09-21. Topic ownership is split deliberately:

- production, workspace behavior and recipe-book presentation:
  [inventory_equipment.md](inventory_equipment.md#4-crafting-model-revised-2026-09-21)
  and [professions.md](professions.md);
- item families, enchant pools, fixed values and operation catalogs:
  [items_crafting.md](items_crafting.md);
- wear, broken-item behavior, providers and repair transactions:
  [durability_repair.md](durability_repair.md);
- armor-reduction and Protection specialization math:
  [combat_stats.md](combat_stats.md) and [skill_trees.md](skill_trees.md).

The sections below retain the exact cross-topic tables and rules used by
Round 13 evidence and immutable tool documentation. They are current rules,
not a temporary override layer. Where a topical owner states the same rule,
the topical owner is the maintenance location. The WP44 target price table is
future behavior until its coordinated economy cutover.

## Workspaces and production

Authored capital/POI stations provide a **Personal workspace**: durable inputs,
outputs, fuel and processing state per player and physical station. All
player-placed stations are **Shared stations** with a common node inventory.
Inside an active Claim Stone claim, access follows the claim's permission list
(`housing.md` §6); there are no per-station access menus. Outside protected
areas player-placed stations have no individual owner. Show the mode and a
short explanation in the station UI. Authored loot chests are outside this
change.

Player-placed furnaces, dual furnaces, brewing stands and profession stations
can be dug at any time by anyone the normal protection allows (Round 28
ruling 18): in the open world there is no extra rule, inside a claim the
claim's rights apply and in foreign home territory the territory rule applies.
Digging drops every node list **and** every player's saved workspace record
together with the station itself (to the digger's inventory, overflow on the
ground), exactly what an explosion releases. A station is never undiggable
because it still holds items, including other players' invisible leftovers.
Authored public stations stay undiggable and blast-immune.

Shared 3x3 station ingredients are shared, while output previews depend on the
viewer's recipe qualification. Ineligible viewers see no craftable result.
Only a successful qualified output transaction consumes ingredients and awards
progress; revalidate inputs, station, distance, access, eligibility and capacity
at commit. Partial output transfers retain already-produced remainder without
another material debit or progress award. Closing a UI loses no contents.

All automatic furnace, dual-furnace and brewing completion is universal and
gives no profession progress. Only qualified cooks assemble profession dishes.
Only qualified alchemists assemble potion mixtures, in the player's own 3x3
grid; anyone may finish those mixtures at a Brewing Stand. Direct grid dishes
still require Cooking and grant progress once; the six Hearty dishes that have
a raw assembly come only from that "Raw X" in a furnace (Round 28 ruling 27).
Simple meat/fish/grain roasting
is universal, belongs to Basics and gives no profession progress.

Profession progression belongs to the eligible taker of the protected
preparation/craft and requires exact equality of recipe tier and current
effective profession tier. No inserting-player ownership is recorded. Book
provenance for profession dishes/mixtures includes their universal finishing
instructions; simple universal roasting appears only in Basics.

Personal processing persists in its physical node, uses elapsed server game
time and may catch up lazily. It does not promise real-time work during server
shutdown. Area access and current-version restart/unload persistence remain
mandatory; no old-world migrations are introduced.

## Enchanting

Remove the refined state, +15% refinement bonuses, doubled lifetime, refinement
recipes and the separate Imbue/Temper upgrade paths. Ordinary enchantable
weapons, armor and offhands have one prefix and one suffix from T1 through T6.
There is no new T6 special slot. Trinkets retain their authored identity special,
but follow the same deterministic craft/enchant workflow (user correction during
implementation, 2026-09-21): the Goldsmith crafts the base trinket, then chooses
and applies prefix/suffix separately. Empty channels are permitted before
application. Prefix choices are Strength/Intelligence/Dexterity; suffix choices
are maximum HP/maximum Mana/Crit. Values, tier legality, replacement and progress
follow the same rules as ordinary equipment. Trinkets remain non-wearing.
Found-item random rolls remain a separate loot rule; no crafted item rolls stats.

Each legal family/stat/channel combination has one named recipe at every
enchant tier. Application occurs at the owning profession's station, acts on
the concrete equipment stack, preserves other metadata/wear and leaves the
other channel intact. It may replace an occupied channel with material cost
and an exact result preview. Reapplying an identical enchant is not a paid craft
and grants no progression. The same stat cannot occupy both channels.

The enchant tier must not exceed the target tier. Its fixed bonus never scales
to a higher-tier target. Qualification and progress use the enchant recipe's
tier, not target tier; suffix application has no separate level-16 mastery gate.
Names and family pools retain the nine existing stat-specific prefix/suffix pairs.
Found-item random value windows remain distinct from fixed crafted enchants.

| Bonus | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Strength, Dexterity, Intelligence | 2 | 3 | 5 | 7 | 9 | 10 |
| Maximum HP or Mana (%) | 1 | 2 | 2 | 3 | 4 | 5 |
| Crit or Dodge (percentage points) | 0.5 | 0.8 | 1.2 | 1.6 | 2 | 2.5 |
| Attack speed (%) | 4 | 6 | 8 | 10 | 12 | 14 |
| Armor rating | 1 | 2 | 3 | 4 | 5 | 6 |

**Enchant inputs (Round 28 ruling 28).** Professions are self-contained: no
operation needs another profession's product. An enchant of tier T for
equipment family F and stat S consumes three items:

1. the family's **own material** of tier T: Weaponsmith and Armorsmith the
   metal bar (Bronze … Abyssal Steel), Leatherworker the leather grade, Tailor
   the cloth bolt, Woodcarver the graded wood (Seasoned … Heartwood), Goldsmith
   the setting;
2. the tier's **stat loot** item for S, a mob loot item of the tier band;
3. the tier's **family input** for F, a mining or gathering item (it may come
   from an earlier tier, be a raw gem, an alloy ingredient such as a tin or
   copper bar, or a universal reagent).

Prefix and suffix of one stat share these inputs; the trinket's prefix pool
(Strength/Intelligence/Dexterity) and suffix pool (maximum HP/maximum
Mana/Crit) differ but use the same stat loot. The Weaponsmith metal fittings
are removed (user decision 2026-10-01). The table lives in
`mods/ITEMS/grug_professions/data/enchants.json` (one entry per tier,
`stat_loot` per stat and `family_input` per family; format in the Round 28
design frame §4.4) and is checked at load: every tier present, every stat of
every family pool has stat loot, every family has an input, every item is
registered, no input has a declared ingredient tier above the enchant tier,
and no profession recipe or enchant operation uses an item that another
profession's recipe makes. The shipped table is the reviewed Round 28
catalogue (`docs/planning/round28/design/catalog/enchants.json`, its README
lists the stat loot per tier): five mob signatures per tier at T1/T2 (tusk,
tail, eye, flesh, fur) and four from T3 (tooth, strap, talisman, flesh; the
strap also covers Armor), and per family a mined or gathered input (bar,
quartz, raw gem, coal, emberglass, crystal, rock salt or stormkelp).

These are 552 ordinary family/stat/channel/tier operations plus 36 Goldsmith
trinket operations (three choices per channel across six tiers);
UI selection distinguishes operations without manufacturing ambiguous grid recipes.

**Universal reagents.** A few crafted enchant inputs (about two per tier at
most) anyone can make: one shapeless crafting-grid recipe or one furnace
recipe from loot, mining or gathering items, never from a profession product.
They are listed in `mods/ITEMS/grug_professions/data/reagents.json` (`id`,
`name`, `tier`, `method` grid or furnace, `inputs`, `output_count`; design
frame §4.5), register as new craft items (in grug_professions or a mod it
depends on, never replacing an existing item) with their tier as ingredient
tier, and appear in the Basics book. Every input must be a registered item. The Round 28
catalogue defines none (the shipped list is empty).

## Equipment and lifetime

### Plain caster weapons and bows

User-approved playtest revision, 2026-09-21. All six tiers of plain wands,
staves and bows are profession-free Basics recipes. H means an ordinary
`group:stick`, M one bar of the weapon's metal tier, O the occult component
below and T `grug_professions:thread`. Dashes are empty grid slots.

| Weapon | Top row | Middle row | Bottom row |
|---|---|---|---|
| Wand | `-O-` | `-M-` | `-H-` |
| Staff | `OMO` | `-H-` | `-H-` |
| Bow | `-HT` | `M-T` | `-HT` |
| Mirrored bow | `TH-` | `T-M` | `TH-` |

| Tier / metal | Occult component |
|---|---|
| T1 Bronze | Boar Tusk (`grug_mobs:boar_tusk`) |
| T2 Iron | Rotting Flesh (`grug_mobs:zombie_flesh`) |
| T3 Steel | Bone (`grug_mobs:bone`) |
| T4 Silversteel | Bear Claw (`grug_mobs:bear_claw`) |
| T5 Embersteel | Sharp Feather (`grug_mobs:sharp_feather`) |
| T6 Abyssal Steel | Venom Sac (`grug_mobs:venom_sac`) |

Each wand consumes one occult component; each staff consumes two. Bows need
none. Graded wood and the former metal-rod wand alternative are absent from
these base recipes. Graded-wood production is unchanged; Woodcarver enchant
costs follow the enchant inputs above. Existing mob sources, chances and item stats are unchanged; components
may be collected before their weapon tier, with metal providing the tier gate.
Bronze recipes are visible from the start; later recipes are discovered by
finding their matching metal bar. Discovery only affects book visibility, never
crafting qualification or character-level restrictions.

### Equipment separation and wear

Tools and weapons are disjoint. Woodcutting Axes, picks, shovels and hoes deal
no damage, have no damage tooltip and cannot enter the weapon slot. Two-handed
axes are Battle Axes. Remove wooden/stone weapons. All weapon families start at
Bronze: Warrior sword, Mage/Priest staff, Scout bow plus a Bronze sword in its
Melee slot and 200 arrows in its quiver slot (Round 28). Ordinary Bronze weapons are usable at level 1 even though their
base-stat item level is 3; elevated found-item levels retain their own gate.
Wood/Stone/Bronze tools all retain T1 mining access. Add Stone Hoe.

| Material/tier | Pick, axe, shovel, hoe uses | Weapon, armor, offhand uses |
|---|---:|---:|
| Wood | 30 | no weapons |
| Stone | 60 | no weapons |
| Bronze / T1 | 300 | 1000 |
| Iron / T2 | 600 | 1500 |
| Steel / T3 | 1000 | 2000 |
| Silversteel / T4 | 1500 | 2500 |
| Embersteel / T5 | 2000 | 3000 |
| Abyssal Steel / T6 | 3000 | 4000 |

Tool budgets describe successful ordinary uses; existing deeper-mining penalties
and tier access remain. Only the acting hand slot (the melee slot or, for a
Scout's shot, the bow; Round 28) wears on outgoing accepted
damage/healing actions; reuse existing settlement semantics and debit once per
action, not per victim. Existing settled incoming combat HP damage selects one intact repairable
equipped piece uniformly from four armor slots and offhand. PvP uses the same rule; fully absorbed hits do not count. Preserve the existing
nonlethal-combat notification: no additional fall/environmental or lethal-hit
wear path is needed. Keep existing
effective-heal/miss/cancel handling without an added event framework.

Creative skips wear. Broken items remain present and repairable; existing
money-only service and purchase-price-based repair costs remain unchanged.

## Protection calibration

Unbroken multiplies aggregated armor rating by 1.65 (replacing 1.40), retains
its +15 emergency rating, and never raises the universal 70% reduction cap.
Concrete item-level base armor applies equally to plate and shields. An ilvl75
plate set (71), matching shield (71), five T6 armor enchants (30), Ironbound (5)
and Stoneskin (4) total 181 before specialization. Against L70, K=135:
Protection reaches 298.65 rating / 68.87% reduction, or 313.65 / 69.91% in its
emergency window. The same equipment/sources without Unbroken reach 57.28%.
This calibration changes only the Protection multiplier, not plain item bases.
