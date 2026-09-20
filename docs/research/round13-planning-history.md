# Round 13 planning history — historical only

All decisions below were consolidated into [the current design](../design/crafting_equipment_revision.md) and authorized on 2026-09-21. Pending-Go statements below record the earlier discussion, not current authority.

# TODO — Simplify equipment enchanting

Updated: 2026-09-21. Planning only; user explicitly requires a later implementation Go.

## Current behavior and authority

`docs/design/items_crafting.md` sections 6b.2–6b.5 define refinement as +15%
base weapon damage (or armor equivalent), doubled durability, and prerequisite
for ordinary affixes. `grug_quality/init.lua` and the gear base-stat functions
implement these bonuses. Ordinary gear currently has at most one prefix and one
suffix; crafter mastery unlocks operations. There is no general third T6 enchant
slot. Section 6b.7 separately defines authored special variants, and trinkets
have their own fixed prefix/suffix/special contract.

## Confirmed user direction

Remove the separate refined state and its recipes/prerequisite. The user accepted
removal; no implementation has started. Enchant base equipment directly through
its owning profession. The latest preferred capacity replaces the prior
one-slot-at-T1/T2 proposal:

- One prefix and one suffix from T1 through T6.
- No new third T6 special slot in this round.
- Every legal named prefix and suffix has one recipe at each enchant tier T1–T6.
  Preserve the existing stat-specific words across tiers.
- Enchant tier may not exceed target item tier: T1 fits T1–T6, T3 fits T3–T6,
  T6 fits T6 only. The enchant's strength follows its own tier, never that of a
  higher-tier target item.

The user explicitly rejects added durability from refinement; use the proposed
new tier lifetimes without a refinement multiplier. Alchemy preparation and
profession progress decisions are recorded in `TODO-station-ownership.md`.

## Existing recipe implementation (verified before planning)

`grug_professions.register_add_affix` and the equivalent artisan helpers already
register six-tier in-place affix operations. These are generic "add the next
affix" operations per exact base item, not individually selectable named
prefix/suffix recipes. `grug_items.append_affix` requires refinement, picks a
random unused stat from the legal family pool and rolls its value from target
item level. Prefix/suffix access currently follows crafter mastery (suffix at
level 16); Imbue/Temper paths add further prerequisites and reroll operations.
These rules must be replaced coherently, not retained as hidden extra gates.

The nine existing stat name pairs are Heavy/of the Bear (Strength), Quick/of
the Fox (Dexterity), Clever/of the Owl (Intelligence), Stout/of the Ox (HP),
Attuned/of the Raven (Mana), Lucky/of the Eagle (Crit), Swift/of the Hornet
(attack speed), Elusive/of the Cat (Dodge), Stalwart/of the Tortoise (Armor).
Legal item-family pools remain binding; not every stat fits every item.

## Coordinator feedback and resolved user choices

Support removing the mandatory refinement step rather than preserving it under
another label. Keep profession ownership, item-family affix eligibility and
meaningful resource costs. Slot capacity does not mean a free built-in enchant.
No new ordinary special slot/effect is included. Keep already designed trinket
specials separate from this removal of the proposed new T6 slot.

Recheck the resulting enchanted-vs-base equipment budgets: removing +15% changes
damage, armor and the Protection top-gear target. Do not silently transfer +15%
to all plain items or stack it invisibly onto the first affix. Reconcile mastery,
temper operations, fine/masterwork recipes, special/cultural effects and recipe
progression with the simpler model; do not retain obsolete refinement gates.
Recommend consistency across ordinary enchantable weapons, armor and offhands
while retaining the separately designed trinket exception. The existing rule
against repeating the same stat across prefix/suffix should remain.

The user answered both questions on 2026-09-21:

1. Fixed authored bonus per enchant tier; no random application value and no
   scaling a cheap T1 enchant up to the target's tier.
2. A new enchant may replace its occupied channel with material cost and a clear
   preview. Preserve the other channel.

Recommended profession progression uses the enchant recipe's own tier, not the
target's tier; a T1 application to a T6 item remains T1 work. Remove separate
Imbue/Temper/refinement upgrade paths in favor of this single enchant workflow.
Materials, numeric bonus tables and station presentation need a bounded catalog
design pass before implementation; the user need not choose each individual
recipe value if the round Go delegates that calibration.
The coordinator has no further player-choice blocker under these recommendations.
The implementation round still awaits explicit Go. Fold the settled model into
the living design docs with the complete catalog/round contract before coding;
this TODO remains until that consolidation is complete.


---

# TODO — Starter tool lifetimes

Updated: 2026-09-21. User requested discussion before implementation.
Wood/Stone/Bronze share T1 pick access. Missing immediate wooden/stone Basics
routes are a confirmed bug and were fixed independently; lifetime changes
are not yet approved.

## Current ordinary-use budgets

Base variants, non-Creative, ordinary matching level-0 nodes. Mining below the
natural depth allowance can spend extra wear. Combat wear is a separate system: even wooden/stone slot weapons currently
use the common 3,000 qualifying-action base equipment lifetime. The table below
is strictly digging/tilling.

| Material | Pickaxe | Axe | Shovel | Hoe |
|---|---:|---:|---:|---:|
| Wood | 30 | 30 | 30 | 64 |
| Stone | 60 | 60 | 60 | not implemented |
| Bronze | 180 | 180 | 225 | 128 |
| Iron | 180 | 216 | 252 | 192 |
| Steel | 180 | 180 | 270 | 256 |
| Silversteel | 240 | 288 | 360 | 384 |
| Embersteel | 300 | 360 | 450 | 512 |
| Abyssal Steel | 360 | 432 | 540 | 768 |

Sources: `grug_materials/mining.lua`, `overrides.lua`, `tools.lua`,
`default/tools.lua`, `grug_farming/hoes.lua`; engine `src/tool.cpp` applies
`uses * 3^(maxlevel - node.level)` to ordinary axe/shovel groupcaps. Picks use
maxlevel zero, while hoes spend their explicitly authored conversion budget.
These are not the raw legacy `uses` values. Iron/Steel axe lifetimes are currently
non-monotonic and should be corrected by the eventual calibration.

## User proposal — 2026-09-21

User goal: very short-lived wooden bootstrap tools, somewhat better stone,
then durable metal tools whose tier becomes the main progression limit. Wood,
Stone and Bronze remain T1 from the tool progression perspective.

The earlier coordinator suggestion of 24/64/512 is superseded by the user's
proposal below. No implementation has started; the user explicitly requested
a feedback/discussion round first.

| Tier/material | All four tool families | Weapons and armor |
|---|---:|---:|
| Wood | 30 | removed |
| Stone | 60 | removed |
| Bronze / T1 | 300 | 1000 |
| Iron / T2 | 600 | 1500 |
| Steel / T3 | 1000 | 2000 |
| Silversteel / T4 | 1500 | 2500 |
| Embersteel / T5 | 2000 | 3000 |
| Abyssal Steel / T6 | 3000 | 4000 |

- Tools and weapons are disjoint. One-handed axes become woodcutting tools
  (suggested English label: "Woodcutting Axe"), cannot enter the weapon slot,
  cause no damage and have no damage tooltip. The two-handed weapon is a
  "Battle Axe". Apply the no-damage tool principle consistently to picks,
  shovels and hoes as well; existing direct tool-punch paths need review.
- Remove wooden/stone weapons from registration, recipes, starter grants and
  catalogs. All weapon families begin at Bronze; this is a progression tier,
  not a requirement that a bow or staff be made entirely of metal.
- New characters receive their class's Bronze weapon. Preserve Scout's 200
  arrows; its current backup Stone Sword also needs a Bronze replacement.
- Each successful incoming combat hit spends one use on one randomly selected
  equipped armor piece, rather than on every armor piece. Define eligible
  non-broken candidates and shield participation before implementation.
- Add the missing Stone Hoe. Wood/Stone/Bronze tools all retain T1 access.

The user rejected any refinement lifetime bonus on 2026-09-21. Use the proposed
tier budgets without an x2 multiplier; removal of refinement itself is under
[separate discussion](TODO-equipment-enchanting.md).

The user's revised wear proposal supersedes the earlier incoming-hit description:
only the main-hand weapon wears for outgoing damage or healing. Incoming damage
spends one use on one randomly selected intact equipped item among the four armor
slots and the offhand; do not distinguish offensive/defensive offhands.
Latest user correction: fully absorbed hits do NOT need to count; preserve the
simpler existing final-damage path. Fall damage may count. For overhealing,
dodge, misses and cancellation, use the simplest maintainable existing event
semantics rather than adding a mathematical/event exception framework. The core
goal is outgoing combat/healing wears the main weapon and incoming damage wears
one intact armor/offhand item, including PvP. State previously non-repairable
offhand (quiver) handling in the final contract. No code changes are authorized.

Open details also include retention of deeper-mining wear penalties.
Current 3000/6000 weapon budgets mean this proposal reduces early-tier
weapon lifetime; randomly selecting armor reduces aggregate armor wear. Exact
event rules should preserve one outgoing wear debit per settled action, not per
victim/projectile, and no combat wear for falls or environmental damage.


---

# TODO — Shared crafting station ownership

Updated: 2026-09-21. Raised by the user during Round12 delivery. Investigation and
planning only; the user explicitly instructed the coordinator to finish the
current round without expanding implementation scope.

## Confirmed problem

World stations currently use shared node inventories. Access checks and recipe
profession checks are not ownership of deposited ingredients or completed work.
Another permitted user can remove inputs or take outputs if eligible. Timer-based
furnaces/brewing may consume ingredients before the eventual output-take profession
check, leaving an unusable result for the person who supplied the materials.
Normal digging refuses nonempty stations; blast callbacks require their own
analysis and are not equivalent to normal digging. Inventory Crafting is already
player-owned; this issue concerns node-based workstations.

Detailed source audit: [shared station inventory audit](docs/research/shared-station-ownership-audit.md).

## Accepted mode split and revised transaction proposal — 2026-09-21

The user accepted two fixed modes, selected by placement provenance rather than
player configuration, including the labels below. Implementation has not begun
and the full transaction contract is still open.

- Authored capital/POI stations: persistent personal working inventories per
  player and station. Other players cannot see or take those contents.
- All player-placed stations: shared node inventories, in both Housing and the
  open world. Player crafting never creates a personal-mode station.
- Housing's Protector Stone controls area-wide access, including chests and
  stations. No additional per-station access configuration is proposed.
- Player-placed world stations/chests outside Housing are openly accessible,
  subject to the existing global world-placement/protection rules.
- Show a concise mode/access explanation in the station UI. Suggested labels:
  “Personal workspace” and “Shared station”; shared wording explicitly refers to
  players who have access to the surrounding area.

The earlier coordinator suggestion to bind production/progress to an initiating
crafter is superseded by the user's new proposal:

- Shared 3x3 station inputs remain shared, but the result preview is per viewer.
  Only a player eligible for that recipe sees and may take its output; other
  viewers see an empty result slot. Revalidate eligibility and current ingredients
  on the real take transaction. A preview is not an independently owned item.
- Progress belongs to the collector, only if eligible and the recipe tier is
  exactly their current profession tier; otherwise that progress is lost.
- Automatic furnaces and dual furnaces transform inputs and allow collection
  without profession checks (area access still applies).
- Only qualified cooks may assemble profession-specific raw dishes, but anyone
  may then bake and collect those dishes from an oven.
- No production eligibility is bound to whoever happened to insert an ingredient.

An explicitly requested native GPT-6 Astra [audit](docs/research/station-viewer-rules-audit.md)
checked this against current recipe/engine paths. The Brewing Stand and raw/final
Cooking progress decisions are resolved below; implementation still needs simple
roasted foods, custom affix stations, per-player previews over shared inventories
and exact-once progress settlement.
Authored loot chests remain separate and do not automatically become personal.

User decisions received 2026-09-21 (design approved; implementation awaits round Go):

- Alchemists craft prepared potion mixtures in their personal inventory 3x3
  grid. Anyone may finish those mixtures at the Brewing Stand.
- Only collection of the profession-gated preparation awards profession
  progress, subject to the existing exact-current-tier rule. Finishing in an
  oven or Brewing Stand awards none. No initiating-crafter ownership is needed.

Coordinator recommendations and remaining details:

1. Alchemy follows the accepted qualified-preparation/free-automatic-finish split
   as Cooking. This needs new prepared mixtures and is a real content change,
   not merely removing the existing Brewing Stand output gate.
2. Award progress on collection of the profession-gated preparation only;
   automatic finishing then gives no second credit (accepted above).
3. Simple roasting of meat/fish/grain remains universal under the furnace rule.
   Under the selected preparation-only credit rule, these conversions give no
   Cooking progression. Prepared dishes remain Cooking-exclusive to assemble.
4. Custom refinement/affix Apply transactions retain their metadata-preserving
   commit and commit-time roll. Viewer eligibility also controls their preview
   and confirmation. Do not turn a prospective affix preview into a takeable
   already-generated item or allow repeated preview rolls.

Separate per-viewer output adapters must revalidate distance, area access,
station identity, ingredients and eligibility at commit. A shared node inventory
cannot itself show different contents to two players. Persistent input/fuel/
output data for personal workspaces must survive UI close, reconnect and unload;
the temporary UI is not the persistence store.

Define full-inventory handling, concurrent viewers, profession loss, disconnect,
offline timing and all removal paths without loss/duplication. No personal
inventory may silently teleport contents between different physical stations.

## Next planning package

Cut one cross-station package across WP10/WP26/WP30 and future Housing integration,
with a frozen transaction/ownership contract before code changes. Acceptance:
two simultaneous users, unauthorized recipe attempts, cancellation, full inventory,
reconnect/restart/unload, respec/profession loss, and all node-removal paths.
No implementation or automatic migration is authorized by this TODO.
