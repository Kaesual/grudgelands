# TODO — Combat, Attributes & Progression Mechanics

Open design questions for `docs/design/combat_stats.md`. Blocks WP3
(classes), WP5 (loot rolls), WP6 (mob tiers). Process: see AGENTS.md
"Documentation layers".

Directions decided in chat (2026-08-06):

- We think in **skills + items**: skills are acquired and improved through
  the class skill tree; items carry stats/enchantments.
- Leveling grants **1 skill point per level** (spent in the skill tree).
- Design principle: **simplify known mechanisms, keep the
  recognizability** (WoW familiarity without WoW complexity).
- A light layer of **lore/story** is delivered through quests, setting and
  environmental storytelling (content question → progression.md later).

## 1. Attributes — DECIDED (2026-08-06)

Three attributes with **automatic per-class growth** (option A below).

| Attribute | Effects (proposal, keep formulas linear) |
|-----------|------------------------------------------|
| Strength | melee damage, small HP bonus |
| Intelligence | mana pool, spell/heal power |
| Dexterity | crit chance, dodge chance |

HP comes mainly from level + class base (no fourth "stamina" attribute —
one knob fewer, still recognizable).

**Decided: A) Auto per class per level** (WoW-style): e.g. Warrior +3
Str/+1 Dex per level. Attributes still matter to the player through item
enchants (+Str rolls etc.). Manual bonus points (Diablo-style) were
considered and rejected for the MVP (respec need, dump-stat balancing
surface); they can later be added on top of auto growth without breaking
anything.

Still open here: the per-class growth rates (part of section 2's curve
work).

## 2. Curves & numbers — OPEN

- HP/damage per level per class (incl. per-class attribute growth
  rates); mob HP/damage/XP per tier; mapping of
  `wow_core.difficulty_at` → mob level (ring table in
  `docs/design/world.md` §1).
- Next step: one spreadsheet-style proposal (level 1 / 10 / 30 / 60
  anchor values) — attributes are decided, so this is unblocked.

**Decision:** _pending_

## 3. Crit/dodge/armor math — OPEN

- Proposal: keep the engine's damage_groups × armor_groups model; add
  crit (×1.5 damage) and dodge (full avoid) as server-side rolls in our
  own damage pipeline (wow_core, mcl_damage-style, already planned in
  AGENTS.md).
- Diminishing returns on crit/dodge from gear: cap both at e.g. 30% —
  simpler than DR curves.

**Decision:** _pending_
