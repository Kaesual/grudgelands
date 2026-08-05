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
- **An aggro/threat system is a core combat pillar** — it shaped WoW's
  fights. Group play follows the trinity (tank + healer + 1–2 damage
  dealers); solo play stays viable via food and potions (section 4).
- **Mobs must be slightly faster than players** (or at least fast enough
  that evading them is not trivially easy); pulling several same-level
  mobs solo must be dangerous.

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
  `wob_core.difficulty_at` → mob level (ring table in
  `docs/design/world.md` §1).
- Next step: one spreadsheet-style proposal (level 1 / 10 / 30 / 60
  anchor values) — attributes are decided, so this is unblocked.

**Decision:** _pending_

## 3. Crit/dodge/armor math — OPEN

- Proposal: keep the engine's damage_groups × armor_groups model; add
  crit (×1.5 damage) and dodge (full avoid) as server-side rolls in our
  own damage pipeline (wob_core, mcl_damage-style, already planned in
  AGENTS.md).
- Diminishing returns on crit/dodge from gear: cap both at e.g. 30% —
  simpler than DR curves.

**Decision:** _pending_

## 4. Aggro, group roles & recovery — DIRECTION DECIDED (2026-08-06), numbers open

Decided direction:

- **Threat system**: mobs choose their target by threat, not by proximity
  or last hit. Proposal for the simple core: threat = damage dealt +
  healing done × ~0.5 (healing pulls aggro onto the healer — the classic
  trinity tension); tank abilities generate bonus threat, plus one taunt
  skill (forces the mob onto the tank for a few seconds). Per-mob threat
  table, cleared on leash/reset.
- **Group trinity**: a good group = tank + healer + 1–2 damage dealers.
  Class kits must support this (Warrior: threat/taunt tools, Priest:
  in-combat heals — feeds into classes.md/WP4).
- **Solo path ("detours")**: **food** is the out-of-combat recovery
  (eat + short rest, WoW-style). Natural HP regen is slow, so food
  actually matters. **In-combat healing** comes primarily from a healer
  or **healing potions** (Alchemist tie-in → economy/jobs).
- **Mob pressure**: mobs run slightly faster than players, so kiting/
  evading is not trivially easy; `group_attack` stays on — pulling
  several same-level mobs solo is dangerous. Note for WP6 tuning: the
  WP1 mobs are currently *slower* than the player (boar run 3.4,
  zombie 2.6 vs. player ~4.0) — raise `run_velocity` to ~4.4+ for
  serious mobs.

Open (numbers, decide with section 2's curve proposal):
- Threat formula factors (healing factor, tank bonus, taunt duration).
- Regen/food/potion values (HP/s resting vs. in combat; potion cooldown).

**Decision:** direction decided; numbers _pending_
