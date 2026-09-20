> Consolidated planning annex. [README.md](README.md) governs any conflict.
> Values are proposed for approval with the complete plan; no runtime is implemented.

# Round 11 AFF / GEAR / SCOUT implementation proposal

Date: 2026-09-20. Planning only. This proposal applies the user's latest
decisions over stale passages; it changes no runtime file.

## 1. Authority and current baseline

The following are already decided: the Scout is the fourth class and replaces
the separate Rogue concept; it uses leather and mana, has no stealth, poison or
traps in V1, and all melee skills read only the equipped main hand
([round11-planning-decisions.md:15-22](../../../docs/research/round11-planning-decisions.md)). Staves stay two-handed, wands are the sole one-handed caster family, Goldsmith books occupy offhand, and scepters/orbs leave the active V1 catalog. Ordinary gear has at most one prefix and one suffix; the existing trinket exception remains. Quivers store arrows and grant no combat bonus
([round11-planning-decisions.md:19-35](../../../docs/research/round11-planning-decisions.md)).

The implementation is behind that design. `grug_gear` still registers all six
scepter and orb tiers alongside wand/staff
([grug_gear/init.lua:183](../../../mods/ITEMS/grug_gear/init.lua)), and base recipes still expose them
([base_recipes.lua:93](../../../mods/ITEMS/grug_professions/base_recipes.lua)). The offhand slot and ordinary two-hand sum already exist, but the present rule has no bow/quiver exception
([inventory_equipment.md:117](../../../docs/design/inventory_equipment.md)). Quality still rolls 1-2 affixes for Uncommon and 3-4 for Rare and allows up to four direct additions
([grug_quality/init.lua:461](../../../mods/ITEMS/grug_quality/init.lua), [grug_quality/init.lua:546](../../../mods/ITEMS/grug_quality/init.lua)).

Leather armor and its profession are already shipped; stale Scout claims that
the line is unregistered must be removed. The bag runtime currently registers
only cloth-neutral 8/16/24-slot identities
([bags.lua:31](../../../mods/PLAYER/grug_inventory/bags.lua)); Tailor owns their three recipes. WP11 X1, X2 and X4 are shipped while X3 remains open
([BACKLOG.md:45](../../../BACKLOG.md)). Scout data and consumers are not registered: the current effect vocabulary explicitly stops at the three existing classes and marks only their remaining X3 consumers
([talents.lua:42](../../../mods/PLAYER/grug_classes/talents.lua)).

## 2. Exact ordinary affix contract (AFF)

Keep the current nine names and value bands. Do not add a second enchant system
or a new `spell_damage` stat: Intelligence already feeds spell power. As part of
the separately accepted armor-rating conversion, **Stalwart / of the Tortoise**
must add the existing band values as armor-rating units, not direct percentage
points; the final rating-to-reduction formula belongs to the armor package.
Prefix and suffix are explicit channels, never alternating array positions
inferred from total count.

| Family | Legal stat pool for either prefix or suffix | Owner of refine/add-affix |
|---|---|---|
| Sword, dagger, greataxe | Str, Dex, attack speed, crit, HP, Mana | Weaponsmith |
| Bow | Dex, crit, attack/draw speed, HP, Mana | Woodcarver |
| Staff or wand | Int, Mana, crit, HP | Woodcarver |
| Shield | Str, Dex, HP, armor | Armorsmith |
| Goldsmith spellbook | Int, Mana, crit, HP | Goldsmith |
| Metal armor | Str, HP, armor | Armorsmith |
| Leather armor | Dex, HP, Mana, crit, dodge | Leatherworker |
| Cloth armor | Int, Mana, HP, crit | Tailor |
| Quiver and bags | none | no refinement or affix operation |
| Trinket special | prefix remains Str/Int/Dex; suffix remains HP/Mana/crit | unchanged Goldsmith special; always its fixed two channels |

For ordinary gear, every legal stat can occupy either channel: its existing
prefix word is used in the prefix slot and its existing “of the …” word in the
suffix slot. A generated item cannot repeat a stat across channels. This permits
useful combinations such as HP + Mana caster gear without forcing Intelligence
into every prefix. The current display vocabulary is authoritative
([grug_quality/init.lua:35](../../../mods/ITEMS/grug_quality/init.lua)); only its pool routing changes. Shield Str/Dex and melee Mana are deliberate accepted shared-family choices. Warrior-only metal armor and shields have no Mana roll; Scout-compatible leather, melee weapons and bows may roll Mana.

Quality mapping becomes exact for ordinary equipment: Common = zero affixes,
Uncommon = exactly one prefix, Rare = exactly one prefix plus one suffix. Value
windows (`world`, `crafted-fine`, `elite`, `rare`, `crafted-masterwork`, two
temper windows and `boss`) remain unchanged. Quality value 4 stays reserved;
do not invent Epic behavior. Found/vendor/boss and kit rolls obey the same slot
shape. Existing special-variant, cultural-finish and target-race channels remain
separate and do not consume these two ordinary slots.

The four mastery thresholds remain levels 1/16/31/46, matching current code
([grug_quality/init.lua:693](../../../mods/ITEMS/grug_quality/init.lua)). Their revised rewards are:

| Mastery | Direct station capability | Kit/value capability |
|---|---|---|
| Apprentice | refine; add/roll the prefix slot | crafted-fine value window |
| Journeyman | add/roll the suffix slot | make/apply the existing Imbue kit; an Imbue produces exactly one prefix if empty |
| Expert | both slots; first value temper | masterwork recipe eligibility and first temper window |
| Master | both slots | second and final value temper, using the existing second-temper window |

This gives all four bands a permanent gain despite only two affix slots. Direct
Add Affix fills prefix first, suffix second and fails closed thereafter. Temper
rerolls values only, never names, slot count or quality. Applying Imbue to an
already-affixed item fails rather than overwriting. The Armorsmith's deliberately
later second kit family can retain its one-band-later catalog placement, but it
must use the same two-slot mechanics. Old prose tying Rare to 3-4 affixes and
Mastery 3/4 to third/fourth slots must be replaced throughout
([items_crafting.md:2244](../../../docs/design/items_crafting.md), [items_crafting.md:2286](../../../docs/design/items_crafting.md)).

## 3. Gear identities, ownership and recipes (GEAR)

**Base rule.** Existing plain tiered Minecraft-like weapons and armor remain
profession-free Basics, using their familiar grid recipes; professions own
refinement, Add Affix and their specialist outputs. This preserves the accepted
Round 10 contract
([inventory_equipment.md:236](../../../docs/design/inventory_equipment.md)). The Round 11 ruling explicitly extends this to **plain bows and plain shields in Basics**. Woodcarver owns bow refinement, Add Affix and later special bow operations; Armorsmith owns the equivalent shield operations. This supersedes the stale Master-only bow and profession-only shield recipe passages in `items_crafting.md`. Arrows are Basics.

Active V1 families are sword, dagger, greataxe, staff, wand and bow. Delete
scepter/orb registrations, Basics recipes, catalog entries and generated vendor
routes on fresh servers. Staff stays two-handed; wand is one-handed. The
Goldsmith spellbook is a profession-exclusive specialist offhand from
Journeyman upward, initially providing its authored Mana stat and accepting the
caster-book affix pool.
This supersedes stale Tailor spell-tome ownership in `professions.md:105`;
Tailor retains cloth armor and cloth bags. The Goldsmith book, quiver and both
bag lines remain profession-specialist items rather than Basics.

The Scout's two-handed melee option is the existing **greataxe**. This is the
only existing two-handed melee family; selecting it avoids inventing a spear or
two-handed-sword ladder. Sword and dagger are its one-handed choices with a
shield. There is still no class gate: the weapon slot remains family-agnostic,
and Scout melee formulas read the current main hand exactly as decided
([inventory_equipment.md:104](../../../docs/design/inventory_equipment.md)).

**Bags.** Register eight concrete bag identities as an explicit, documented
one-item-per-concept exception:

| Band | Slots | Tailor | Leatherworker |
|---|---:|---|---|
| Apprentice | 8 | Small Cloth Bag | Leather Pouch |
| Journeyman | 16 | Cloth Satchel | Leather Satchel |
| Expert | 24 | Large Cloth Bag | Leather Pack |
| Master | 32 | Great Cloth Bag | Leather Rucksack |

Both columns use the same `bagslots` values and runtime safety rules; neither
has stats, armor, refinement or affixes. Each concrete recipe appears only in
its owning profession book. Keep the small 8-slot vendor floor, selecting the
cloth identity as the canonical vendor item. Existing player-list storage needs
no second storage subsystem.

**Quiver.** Register one stack-max-1 Leatherworker offhand at Apprentice, with
four arrow-only stacks and no combat stats or affixes. This supersedes the stale
Master/bag-slot passage at `items_crafting.md:938`. Its contents live in one
persisted player-inventory list and do not increase bag capacity. Removing or
replacing a filled quiver first performs an atomic transfer of every remaining
arrow to the player's main inventory. If all arrows do not fit, refuse the
removal with a clear message and change neither inventory. This avoids portable
container metadata while making bow/melee swapping practical.

The hand contract gains a narrow declaration, e.g. `grug_bow_quiver = 1`:
a bow is `_grug_hands = 2`; a quiver is an offhand with zero hand cost and is
the sole legal offhand beside a bow. A bow still rejects shield, book and torch.
A worn quiver is also legal beside a one-handed sword or dagger for convenient
mode switching, but a two-handed greataxe or staff still requires removing it.
All other offhands continue counting as one hand. Avoid globally treating
arbitrary offhands as zero-handed.

Bow abilities consume ammunition **quiver first, then main inventory**, and
shooting without a quiver remains valid. Validate the total available count
before arming the shot. Remove the full required count atomically when the
projectile action successfully spawns: Loose/Snare/Pinning consume one; Twin
Shot consumes two, potentially across quiver and main. A fired miss still costs
its arrow; any spawn failure consumes nothing. The `Quiver` talent's refund
roll occurs after successful spawn and returns the consumed arrow count to the
quiver when equipped and space exists, otherwise to main inventory, using the
existing safe-give path only as a final overflow fallback. This uses the
existing talent's 10-50% values rather than turning the equipment item into a
combat bonus
([skill_trees.md:447](../../../docs/design/skill_trees.md)).

## 4. Scout minimum delivery (SCOUT)

Starter kit: below-ladder wooden bow in Weapon, 20 player arrows and the
existing stone sword in main inventory. The optional Apprentice quiver is
crafted later, with no separate starter identity. Use the existing safe grant
path; never lose items. Scout armor rank is 2 with +2 Dex / +1 Str / +1 Int
per level. Its four base buttons remain Loose, Snare Shot, Sidestep and Sprint
plus universal Strike; their decided values are in `scout.md` section 2.

The minimum prerequisite is **not all old WP11 X3**. Build a bounded Scout-X3
extension on the shipped X1/X2/X4 machinery:

1. Extend the closed effect vocabulary and real consumers only for the 16 Scout
   talents in `skill_trees.md` §§2.7-2.8.
2. Register the two Scout trees/data, Pinning Shot and Opening; wire Twin Shot,
   Shake Loose, Longshot and Untouchable.
3. Reuse existing projectile exact-once settlement, movement/root aggregator,
   timed windows, dodge/cap override, cooldown/charge, mana and main-hand damage
   seams. Add no stealth, traps, poison, block roll or second weapon source.
4. Resolve the apparent replacement collision as one pipeline: Loose becomes
   Twin Shot when learned; Longshot modifies that resulting shot action's range
   and long-range damage rather than replacing Twin Shot. This preserves both
   selected talents and their single hotbar key.
5. Fine Edge and Opening read generic equipped main-hand damage, so sword,
   dagger and greataxe work without a one-hand/two-hand talent branch. Bow-only
   actions require the bow group; they do not silently use a melee weapon.

The other three classes' unfinished WP11 X3 abilities can remain a separately
owned lane. Shared X3 helpers should be extracted once where Scout needs them,
but Round 11 must not claim full WP11 completion until all original X3 content
is delivered and independently reviewed.

## 5. Package boundaries and interfaces

1. **AFF:** quality schema/pools, two-channel serialization and legacy design
   reconciliation; quality source and station fixtures. It publishes
   `family_for`, legal-prefix/legal-suffix queries and two-slot roll/append APIs.
2. **GEAR:** active weapon roster, bow/starter bow, shield/book/quiver/bags,
   Basics and profession catalogs, equipment compatibility and safe quiver
   inventory. It publishes `is_bow`, `equipped_quiver`, `ammo_count`,
   `reserve_or_consume_ammo`/refund as one transaction boundary.
3. **SCOUT:** class registration, projectile/charge actions and only the Scout
   talent data/consumers. It consumes GEAR APIs and the shipped movement,
   projectile, equipment-change and talent APIs; it does not inspect quiver
   lists directly.

GEAR depends on the design fold and AFF family vocabulary. SCOUT depends on
GEAR. Trader/catalog cleanup consumes the final active-family list rather than
keeping a second roster. Visual work needs six bows, the starter bow, book,
shield, quiver and bag variants plus a bow wield pose, but has no authority to
change their mechanics.

Repair is adjacent, not part of these three packages: define a small canonical
reference-purchase-price provider for only repairable current gear, used by all
profession trainers, and charge `ceil(0.20 * reference_purchase_price *
missing_wear_fraction)`. Never derive it from sell-back and do not pull all of
unshipped WP44 into Round 11. Zero wear costs zero; partial repairs and all
eligible professions use the same provider and price.

## 6. Remaining user choices

No further player-facing AFF/GEAR/SCOUT choice is required: the existing
greataxe is the Scout's two-handed melee family and the simple quiver has four
stacks. The armor-rating formula/cap remains a separate open Round 11 decision
and must not be invented inside AFF/GEAR/SCOUT. Likewise, completing the other
classes' old WP11 X3 is a scope/scheduling choice, not a Scout prerequisite.
