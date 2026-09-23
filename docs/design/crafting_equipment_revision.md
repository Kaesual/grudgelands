# Crafting stations, enchanting and equipment — current rules

Decided 2026-09-21, implementation authorized for Round 13. This document
supersedes conflicting refinement, affix application, station ownership and
durability clauses in older design sections. Existing trinket authored specials,
item-family affix pools, repair prices and mining access/depth rules continue.

The topic owners now carry the reusable rules: production and recipe-book
behavior in [inventory_equipment.md](inventory_equipment.md#4-crafting-model-revised-2026-09-21)
and [professions.md](professions.md), wear and repair in
[durability_repair.md](durability_repair.md), and item/enchant catalogs in
[items_crafting.md](items_crafting.md). This document remains the approved
Round-13 cross-cutting contract and calibration record; it does not make the
WP44 target price table current runtime behavior.

## Workspaces and production

Authored capital/POI stations provide a **Personal workspace**: durable inputs,
outputs, fuel and processing state per player and physical station. All
player-placed stations are **Shared stations** with a common node inventory.
Housing uses area-wide Protector Stone access; there are no per-station access
menus. Outside protected areas player-placed stations have no individual owner.
Show the mode and a short explanation in the station UI. Authored loot chests
are outside this change.

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
still require Cooking and grant progress once. Simple meat/fish/grain roasting
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

Each operation consumes one matching tier professional component plus one tier
reagent: Coal / Venom Gland / Slime Gel / Croc Tooth / Stormkelp / Stone Core.
Components: Weaponsmith metal fittings; Armorsmith metal bar; Leatherworker
leather grade; Tailor cloth bolt; Woodcarver graded wood plus a matching metal
fitting; Goldsmith setting. Existing ingredient identities and component recipes
remain authoritative. These are 420 ordinary family/stat/channel/tier operations plus 36 Goldsmith
trinket operations (three choices per channel across six tiers);
UI selection distinguishes operations without manufacturing ambiguous grid recipes.

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
these base recipes. Graded-wood production and Woodcarver enchant costs remain
unchanged. Existing mob sources, chances and item stats are unchanged; components
may be collected before their weapon tier, with metal providing the tier gate.
Bronze recipes are visible from the start; later recipes are discovered by
finding their matching metal bar. Discovery only affects book visibility, never
crafting qualification or character-level restrictions.

### Equipment separation and wear

Tools and weapons are disjoint. Woodcutting Axes, picks, shovels and hoes deal
no damage, have no damage tooltip and cannot enter the weapon slot. Two-handed
axes are Battle Axes. Remove wooden/stone weapons. All weapon families start at
Bronze: Warrior sword, Mage/Priest staff, Scout bow plus backup Bronze sword and
200 arrows. Ordinary Bronze weapons are usable at level 1 even though their
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
and tier access remain. Only the main-hand weapon wears on outgoing accepted
damage/healing actions; reuse existing settlement semantics and debit once per
action, not per victim. Existing settled incoming combat HP damage selects one intact repairable
equipped piece uniformly from four armor slots and offhand. PvP uses the same rule; fully absorbed hits do not count. Preserve the existing
nonlethal-combat notification: no additional fall/environmental or lethal-hit
wear path is needed. Keep existing
effective-heal/miss/cancel handling without an added event framework.

Quivers join offhand wear/repair; broken quivers retain accessible stored arrows.
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
