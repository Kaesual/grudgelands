# Class redesign and hotbar handoff

Prepared 2026-10-12 from the class, talent and hotbar discussion of
2026-10-11–12. This is the requested **pre-planning handoff**, not a round
execution plan. Its purpose is to resume the discussion on another computer
without reconstructing the conversation.

Continuation 2026-10-12: the user requested the remaining three classes in
parallel, followed by coordinator review and a balancing correction round for
all four. The [four-class review package](class-redesign/README.md) holds those
proposals and the reviewed Mage amendments. It supersedes the sequential
continuation instruction below for that task, but is not design acceptance or
an implementation plan.

Targeting follow-up, 2026-10-12: the user approved retaining first-person
crosshair interaction and the six related ability changes. Their current
owner is [ability targeting](../design/ability_targeting.md); the
[implementation design](class-redesign/implementation-design.md) is the
entry point for the redesign's planning. It supersedes earlier selection wording
here without accepting every candidate number or closing the design round.

Parked 2026-10-12: the rework is a future work package; resume with the
[continuation plan](class-redesign/continuation.md).

The goal is more noticeable character growth and more meaningful build
choices, with a small starting kit, earlier talent unlocks and a satisfying
rotation and flexibility using four to six equipped combat skills. Characters
may have more than six active skills unlocked at once. The Mage is the first worked
example. Two hotbar layouts, a consumables belt and a better talent-tree
presentation support the same goal without crowding out gathering and building.

## 1 Scope and authority

- **User decisions** below record the intended future behavior. They are
  approved directions, not a claim that the current game implements them.
- **Mage design proposal** is a complete discussion candidate, including
  newly worked-out point costs, dependencies and initial tuning values.
  Those details still need the user's approval and balancing evidence.
- **Recommendations and open choices** remain proposals. The user's initial
  Mage examples were explicitly illustrative, not an approved specification.
- No round number, lanes, model routing, implementation schedule or release
  is assigned here. Do not begin implementation from this handoff alone.

This handoff is the conversation record. During actual planning, approved
rules move into their existing topic owners; unresolved questions are tracked
through [the class redesign TODO](../../TODO-design-classes.md). Keep current
delivery information in [STATUS](../STATUS.md). This document does not change
the current [class kits](../design/classes.md),
[talent specification](../design/skill_trees.md),
[inventory rules](../design/inventory_equipment.md) or
[combat formulas](../design/combat_stats.md) by silently rewriting them.

## 2 Why the redesign is needed

The user finds current development too weak in both customization and the
feeling of becoming more powerful. Having most defining tools immediately,
then buying small numerical improvements, does not deliver the desired growth.

The present Mage starts with Strike, Fireball, Ice Nova and Blink. The current
tree gives one point every two levels, 30 at level 60; its first major
keystone is reachable at level 26 and each tree adds at most one active skill.
The existing [reachability table](../design/skill_trees.md#13-points-and-the-arithmetic-rulings-1-2-17-and-18)
explains why substantial changes arrive late.

The original exploration suggested two class starters beside Strike and
roughly three or four skill unlocks per tree, with an ultimate at each tree's
end. Subsequent discussion established the usability goal: a finished
character should need at most six equipped combat skills, with five likely
sufficient. This is not a limit on skill ownership. Transformations,
passives and selecting a useful subset of a larger repertoire all contribute
to customization; the initial unlock count is not a mandatory button quota.

## 3 User decisions

### 3.1 Class development and the Mage

1. Discuss and redesign the classes **one at a time**, in detail, including
   tree structure, skills and PvP. Start with the Mage.
2. Start with a minimal kit and earn important tools through talents. The
   character should visibly gain capabilities during leveling.
3. **Four to six equipped skills must provide a good rotation and gameplay
   flexibility; five may be enough, and more than six must not be necessary.**
   The user explicitly clarified on 2026-10-12 that a character may have
   **more than six skills unlocked simultaneously**. Neither skill ownership
   nor spending is capped at six. Gathering normally needs a pickaxe and
   torches as well. This is a usability goal, not an engine-enforced slot cap.
4. Strike is a starting attack which may become unnecessary. For the Mage,
   the free magical main attack **replaces Strike from character creation**.
   A Mage having only ranged combat attacks is acceptable.
5. The free main attack starts as fire. General fire-damage talents improve
   it. A Frost talent can convert it to ice and add a small slow; fire-damage
   improvements no longer apply to the converted attack. **Fiery Spark and
   Cold Spark are always single-target attacks, without area damage.** Buying
   Cold Spark replaces Fiery Spark, including existing hotbar representations.
   **Fireball is a separate skill**, not a replacement for either Spark, and
   can coexist with Cold Spark. There is no Fireball/Cold Spark exclusion.
6. Fire should deal more damage, with less movement control and protection.
   It is a glass cannon: more immediately dangerous in PvP, but easier for
   melee and ranged opponents to kill. The same tradeoff must be felt in PvE.
7. **Fire Rain is the Fire ultimate.** It does not need an alternative ultimate
   choice. The earlier self-centered fire aura is not the selected ultimate.
8. Offensive elemental effects target enemies; they must not ignite or damage
   the environment. Ice Cage remains a separate, unresolved terrain question.
9. **Priest damage stays slightly below Fire Mage damage**, including an
   offensively specialized Priest (user clarification, 2026-10-12). Healing
   must not come on top of the Fire Mage's offensive strength. Frost pays for
   slow and freeze with lower damage. This is a qualitative tuning direction,
   not a fixed percentage or a requirement that every individual hit be lower.
   The [cross-class review](class-redesign/balance.md) records the candidate
   arithmetic and remaining gameplay checks.

### 3.2 Hotbar layouts

These are the user's latest corrections, on 2026-10-12. They replace the earlier
interpretation that an inactive layout would be excluded from consumption or
retain invalid skills until activation.

1. Each player gets **two eight-slot layouts, A and B**. One is the visible
   hotbar; an invisible eight-slot store holds the other. Switching exchanges
   their contents rather than keeping two references to the same item stacks.
2. **Neither hotbar participates in sorting.** Switching must retain slot
   positions, empty slots, item counts, wear and metadata.
3. Ingredients, quest items and ammunition may be **counted and consumed from
   either layout**, including the inactive one. The exact consumption order
   remains to be specified.
4. The **inactive layout must never receive items automatically**, including
   loot and other item grants. The active hotbar may receive them according to
   the normal inventory insertion order.
5. A player may deliberately activate the other layout and use it as extra
   inventory space. This is allowed. The prohibition is on automatic insertion
   into invisible slots, which would make acquired items appear lost.
6. **New skills are not placed onto a hotbar automatically.** They become
   available through the Skills catalogue for manual placement. Do not retain
   the previous suggestion to fill an available slot on unlock. Whether initial
   character creation is an exception needs an explicit answer; do not assume it.
7. Skill cleanup immediately filters **both** layouts. A lost talent or removed
   skill does not leave its representation in the inactive layout.
8. Skills remain restricted to hotbars. Ordinary inventory, bags, equipment,
   external inventories and the consumables belt do not accept them.
9. Each skill may occur **once per layout**: at most two representations in
   total, one in A and one in B. They share the same character/skill cooldown.
   Switching or placing another representation must never refresh a cooldown.
10. Use **dropdowns**, not toggle buttons: one in Quickbar E, and one replacing
    the **Hotbar** label everywhere an inventory page displays the hotbar.
    Both offer **Hotbar A / Hotbar B** and show the current layout.

The resulting rule is deliberately asymmetric:

| Operation | Active layout | Inactive layout |
|---|---|---|
| Automatic item insertion | Allowed by normal give order | Never |
| Ingredient, quest-item and ammunition consumption | Allowed | Allowed |
| Sorting and sort-driven stack consolidation | Excluded | Excluded |
| Automatic placement of newly unlocked skills | Never | Never |
| Removal of invalid skills | Immediate | Immediate |
| Manual editing | Visible hotbar | Activate it first |

Consumption may reduce or empty an inactive stack. Therefore “untouchable”
must no longer be interpreted as immutable; it means no automatic deposits,
sorting or ordinary direct editing while hidden.

### 3.3 Consumables and talent presentation

- Expand the potion belt to include food and rename it in English.
  **Consumables Belt** is the proposed English UI label; the exact wording
  was not dictated by the user.
- Resolve the input conflict between clicking an item in Quickbar E and the
  current requirement to hold RMB while wielding food. Merely admitting food
  to the belt is insufficient.
- Plan talent trees as **background line graphics with interactive buttons
  over their nodes**. The user proposed this to replace the unattractive
  orthogonal Formspec connector boxes and allow diagonal edges. The precise
  asset-generation method remains a technical recommendation in section 6.

### 3.4 Area targeting direction

The user prefers a **raycast within the spell's allowed range** to determine
Meteor and Fire Rain's target point, rather than assuming a separate free
location-selection interaction. For area damage, the user proposed a shared
horizontal footprint with a limited vertical search: for each x/z position,
choose the eligible surface or whole air block closest in y to the target
point. A column with no eligible candidate remains damage-free. A radius of
5 and a vertical allowance of roughly ±2–3 blocks were **examples**, not
approved spell values. Exact geometry, applicability to all area spells,
performance, particles and runtime behavior remain to be designed in
[section 5.9](#59-raycast-targeting-and-area-footprint-proposal).

## 4 Design principles for all classes

The following synthesis guides the remaining class discussions. The user
directions in section 3 are fixed; the structural recommendations here are
not additional user rulings.

- **Small starting kit, meaningful early growth.** The first changed combat
  behavior should arrive well before level 26. Teach the class before adding
  several specialist tools.
- **Build around useful four-to-six-skill loadouts.** Count the basic attack
  and ultimate when equipped. Five should often suffice. Track the larger
  unlocked repertoire separately: an additional situational skill is welcome,
  but it must not become a seventh mandatory button in the ordinary rotation.
  An upgrade replacing a button does not add a button; a passive does not
  secretly require another active skill.
- **Two layouts do not justify doubling the required combat kit.** They solve
  everyday inventory use and may hold alternative skill selections. Having
  more than six skills available is explicitly allowed; the combat switching
  policy still needs a decision. Ordinary effectiveness must not depend on
  repeatedly swapping layouts to execute a much larger rotation.
- **Earn capabilities, then specialize them.** Useful choices include direct
  damage versus area damage, efficiency versus burst, and protection versus
  control. Not every node should be a small percentage increase.
- **Let dependencies express mechanics.** Prefer tree-wide point thresholds;
  require an actual predecessor when a talent modifies that skill. Avoid
  making every branch a mandatory fully ranked chain.
- **Keep more attractive investments than available points.** A deep build
  should still make choices inside its preferred tree. Mixed builds must be
  playable and give up identifiable strengths.
- **Keep resource failure playable.** A build that has dropped Strike must
  retain a useful ordinary attack. The Mage's free spell is decided; the
  solution for each other class must be discussed separately.
- **Make specialization costs visible in PvE and PvP.** Fire's damage advantage
  must come with less room to recover from mistakes. Frost should win through
  control and prepared damage windows, without requiring endless low-damage
  kiting or indefinite control of an opponent.
- **Provide counterplay.** Telegraph large attacks, respect cover, avoid
  unavoidable burst during long roots and assess multiple attackers together.
- **Make numerical growth durable.** Damage scales with the shared level/gear
  formulas; armor uses the existing rating curve. Avoid flat bonuses that
  matter at low level and disappear at high level.
- **Keep the world intact and the web build usable.** Existing protection,
  PvP authorization and server-authoritative combat remain mandatory.
  Spell visuals must stay within the project's particle budget of hundreds
  active in total, not thousands.

## 5 Mage design proposal

**All numbers, node names, dependencies and build allocations in this section
are proposed tuning, not user-approved or playtested values.** They complete
the conversation's direction into a candidate that can be discussed without
first inventing its missing point arithmetic. Existing ids must be considered
separately during migration; short node codes below are discussion labels.

### 5.1 Starting kit and damage conventions

Start with **Fiery Spark and Ice Wave**, no Strike and no Blink. Two starter
buttons are a recommendation; the user approved replacing Strike but did not
explicitly settle the final number of Mage starters.

For the tables, **D** is this Mage's untalented Fiery Spark hit at the current
level and gear, after ordinary level scaling but before crit and target
mitigation. It is a comparison unit, not another damage scalar. The eventual
implementation must compose each damage formula once through the existing
pipeline. **P** is the existing class-neutral base pool, used for percentage
mana costs. **K** is the existing level-dependent armor-rating constant.

General fire bonuses apply once to fire damage, including secondary effects;
they never multiply an already boosted main hit a second time. Frost damage
does not receive those bonuses. Armor, dodge, absorbs and permitted targets
remain governed by the existing combat rules.

| Skill | Initial proposed behavior |
|---|---|
| Fiery Spark | Free fire projectile; D direct damage to one target only, no splash; 20 m acquisition range; 1 s minimum release interval. Keep the current projectile targeting contract as the baseline. |
| Ice Wave | Frost cone, 5 m reach and 70-degree full angle; 0.25D damage; 35% movement slow for 3 s; 12 s cooldown; 8% P mana. No root. |

The early kit must survive ordinary solo encounters without Blink. Test this
before compensating by making Blink a compulsory pick.

### 5.2 Points and unlock timing

Retain **one point at every even level, 30 points at level 60** for this
candidate. A gate of N requires N already-spent points in that same tree;
buying a one-rank unlock therefore needs at least N+1 points. A listed
predecessor requires one rank unless a different rank is stated.

| Gate | Earliest first purchase when concentrating on that tree |
|---|---|
| 0 | Level 2 |
| 2 | Level 6 |
| 6 | Level 14 |
| 10 | Level 22 |
| 12 | Level 26 |
| 16 | Level 34 |
| 20 | Level 42 |

Each ultimate costs one point after gate 20. Two ultimates cost at least
42 points and cannot coexist with 30. A mixed build may intentionally take
neither; do not misstate this as forcing every character to buy an ultimate.

### 5.3 Ember nodes

Ember has **32 purchasable ranks**, including active unlocks and passives.
Fireball is an additional active skill. The free main attack remains Fiery
Spark or, after conversion, Cold Spark. The conversion affects neither
Fireball nor its explosion; both talents can be learned together.

| Code | Talent | Gate | Ranks | Predecessor | Effect at each rank |
|---|---|---:|---:|---|---|
| F1 | Fire Mastery | 0 | 4 | — | All fire damage +5/10/15/20%. |
| F2 | Measured Fuel | 0 | 3 | — | Mana costs of paid fire spells −4/8/12%. |
| F3 | Far Cast | 0 | 3 | — | Main projectile acquisition range +1/2/3 m, either element. |
| F4 | Fireball | 2 | 1 | F1 | Unlock a separate fire projectile with an explosion: initial damage candidate 1.10D direct hit and 0.15D splash to other enemies within 2 m. Adds a button; coexists with either Spark. Cost and cadence need retuning for the separate skill. |
| F5 | Flame Lance | 6 | 1 | — | Unlock the prepared single-target fire attack below. Does not require Fireball. |
| F6 | Heat Focus | 6 | 3 | F5 | Flame Lance direct damage +5/10/15% of its untalented value. Add to other fire damage bonuses rather than compound them. |
| F7 | Afterglow | 6 | 3 | F4 | Fireball's primary target burns for 0.05/0.10/0.15D total over 3 s. One burn per caster/target; refreshing does not stack or cause an extra immediate tick. |
| F8 | Meteor | 12 | 1 | F4 | Unlock the delayed area strike below. |
| F9 | Wide Ember | 12 | 3 | F4 | Fireball splash becomes 0.20/0.25/0.30D. Main target still receives only its direct hit. |
| F10 | Broad Impact | 12 | 3 | F8 | Meteor radius +0.25/0.50/0.75 m. |
| F11 | Controlled Burn | 16 | 3 | F8 | Meteor and Fire Rain mana costs −5/10/15%, additive with F2. |
| F12 | Fire Rain | 20 | 1 | F8 | Unlock the fixed Fire ultimate below. |
| F13 | Spreading Rain | 20 | 3 | F12 | Fire Rain radius +0.25/0.50/0.75 m; no extra ticks. |

| Additional fire skill | Initial proposed behavior | Opponent response |
|---|---|---|
| Fireball | Separate projectile and explosion as F4 above. Mana cost, release interval and cooldown remain open after correcting its former free-main-attack design; do not inherit Fiery Spark's free cost automatically. | Spread out to reduce splash and use projectile cover. |
| Flame Lance | 1.8D direct damage, 20 m range, 1.25 s visible preparation; movement cancels preparation; 8 s cooldown; 10% P mana. | Pressure the caster or break line of sight before release; ordinary projectile cover still applies. |
| Meteor | Determine the impact point by an aiming raycast within 20 m; 1.4D area damage, 3 m horizontal radius; 1.5 s warning; 18 s cooldown; 14% P mana. Use the provisional column-selection model in section 5.9. | Leave the marked location; the marker never follows a target. |
| Fire Rain | Determine the center by an aiming raycast within 20 m; 4 m horizontal radius; 1 s warning, then five pulses at one-second intervals, each 0.45D; 60 s cooldown; 22% P mana. Use the provisional column-selection model in section 5.9. | Leave the area or use cover. No root, protection or tracking is included. |

For initial comparison, area pulses and Afterglow do not crit; direct Spark,
Fireball and Flame Lance may use the existing crit rules. Meteor is an area
attack under this proposal. This is a proposed spell-specific balancing rule,
not a change already made to the combat engine.

Fire Rain retains its raycast-derived center during the effect. Its footprint
is the proposed bounded per-column selection in section 5.9, not a sphere or
a filled cylinder damaging every vertical layer. It must not hit through
floors or walls. Ceiling behavior and matching particle placement are still
open; do not assume an open-sky requirement or a completed indoor solution.
It changes no world nodes.

### 5.4 Rime nodes

Rime has **33 purchasable ranks**. Its defense, mobility and control should
support solo play while leaving its sustained damage below a Fire specialist.
Its offensive payoff is an empowered main-attack hit after Nova, replacing
the earlier idea of adding a separate Frost Lance button.

| Code | Talent | Gate | Ranks | Predecessor | Effect at each rank |
|---|---|---:|---:|---|---|
| R1 | Cold Spark | 0 | 1 | — | Replace Fiery Spark with a single-target frost attack, including existing hotbar representations: same D base hit, 12% slow for 1.5 s, no fire-damage bonuses and no splash. Refresh only, no stacking. Fireball remains a separate fire skill. |
| R2 | Mana Reserve | 0 | 4 | — | Maximum mana +5/10/15/20% of P; costs still use unmodified P. |
| R3 | Lingering Chill | 0 | 3 | R1 | Cold Spark slow increases to 14/16/18%; duration unchanged. |
| R4 | Blink | 2 | 1 | — | Unlock a 10 m teleport, 20 s cooldown, 8% P mana; safe destination rules remain. No added root break or control immunity. |
| R5 | Clear Thought | 2 | 3 | — | Mana costs of paid frost/utility spells −4/8/12%. |
| R6 | Quick Step | 6 | 3 | R4 | Blink cooldown −1/2/3 s. |
| R7 | Ice Armor | 6 | 1 | — | Unlock the timed protection skill below. |
| R8 | Thick Ice | 10 | 3 | R7 | Ice Armor gains another 0.04/0.08/0.12K armor rating. |
| R9 | Ice Nova | 12 | 1 | — | Replace Ice Wave with the circular control skill below. Same button. |
| R10 | Cold Shock | 12 | 3 | R9 and R1 | A Nova that affects an enemy empowers the next Cold Spark within 4 s by +0.10/0.20/0.30D. One charge per cast, no stacking. |
| R11 | Returning Cold | 12 | 3 | — | Ice Wave/Nova cooldown −1/2/3 s. |
| R12 | Far Frost | 16 | 3 | R9 | Nova radius +0.25/0.50/0.75 m. |
| R13 | Winter Field | 20 | 1 | R9 | Unlock the proposed Frost ultimate below. |
| R14 | Lasting Armor | 16 | 3 | R7 | Ice Armor duration +0.5/1.0/1.5 s. |

R10 has two real prerequisites, providing a concrete two-parent graph case.

| Paid frost skill | Initial proposed behavior | Opponent response |
|---|---|---|
| Ice Armor | Self, +0.20K armor rating for 6 s; a successful hostile melee hit against the caster applies a 20% slow for 2 s to that attacker; 24 s cooldown; 10% P mana. | Attack from range, wait out the armor or force it before committing. Missed/dodged attacks do not trigger it; repeated triggers only refresh. |
| Ice Nova | 0.35D frost damage in a 5 m radius around the caster, followed by a 1.75 s root; 18 s cooldown; 10% P mana. Subsequent damage breaks the root, including an existing burn tick; Nova's own initial hit does not break its new root. | Root does not silence or stun. Attack back or use an available escape; another attacker cannot maintain the root while freely dealing damage. |
| Winter Field | Candidate raycast-derived center within 15 m, horizontal radius 4 m; 0.75 s warning, then six one-second pulses of 0.15D; 35% slow while inside, lingering at most 0.5 s after exit; 60 s cooldown; 18% P mana. Exact occupied area follows the shared proposal in section 5.9 once settled. | Leave the area or pressure the caster outside it. No repeated root, barrier or immunity. |

Frost area damage does not crit in this initial candidate. Ice Armor uses
rating, not a flat percentage of damage reduction; it does not make a Mage
a tank. Whether absorbed melee hits count as successful Ice Armor triggers
needs settlement-level clarification before implementation.

### 5.5 Graph structure

Point gates and direct prerequisites are separate. These edges are the
actual prerequisite graph; gate bands are background annotations, not edges.
Unless otherwise stated, one rank in each parent suffices.

```text
Ember
F1 -> F4 -> F7
         -> F9
         -> F8 -> F10
              -> F11
              -> F12 -> F13
F5 -> F6
F2 and F3 have no direct descendants; F5 uses its tree point gate.

Rime
R1 -> R3
R4 -> R6
R7 -> R8
   -> R14
R9 -> R10 <- R1
   -> R12
   -> R13
R2, R5 and R11 use point gates without direct parents.

F4 and R1 may coexist. Only R1 transforms the free main attack.
```

### 5.6 Worked builds and equipped skill choices

The following rank allocations total 30 points and can be purchased in the
listed order. Repeated entries mean buying additional ranks later; all omitted
nodes remain unranked. They demonstrate feasibility, not optimal performance.

| Build | Purchase sequence by tree | Unlocked repertoire |
|---|---|---|
| Fire with utility, 21 Ember / 9 Rime | Ember: F1×4, F4×1, F2×2, F5×1, F6×3, F7×3, F8×1, F9×3, F10×2, F12×1. Rime: R2×2, R4×1, R2×2, R5×1, R7×1, R6×2. | Fiery Spark, Fireball, Ice Wave, Flame Lance, Meteor, Fire Rain, Blink, Ice Armor: **8 available**. Equip a useful subset below. |
| Frost with a prepared fire hit, 9 Ember / 21 Rime | Rime: R1×1, R2×4, R3×2, R4×1, R5×2, R7×1, R8×1, R9×1, R10×3, R12×3, R8×1, R13×1. Ember: F2×3, F3×3, F5×1, F6×2. | Cold Spark, Ice Nova, Blink, Ice Armor, Winter Field, Flame Lance: **6**. Flame Lance stays fire and gains no Frost conversion. |
| Mixed control and area damage, 15 / 15 | Ember: F1×4, F4×1, F2×1, F5×1, F6×3, F7×3, F8×1, F9×1. Rime: R2×4, R4×1, R5×3, R6×2, R7×1, R8×1, R9×1, R11×2. | Fiery Spark, Fireball, Ice Nova, Blink, Ice Armor, Flame Lance, Meteor: **7**, no ultimate. |
| Pure Fire, 30 / 0 | F1×4, F4×1, F2×3, F3×2, F5×1, F6×3, F7×3, F8×1, F9×3, F10×3, F11×3, F12×1, F13×2. | Fiery Spark, Fireball, Ice Wave, Flame Lance, Meteor, Fire Rain: **6**, no teleport or armor skill. |
| Pure Frost, 0 / 30 | R1×1, R2×4, R3×3, R4×1, R5×3, R6×3, R7×1, R8×3, R9×1, R10×3, R13×1, R11×3, R14×3. | Cold Spark, Ice Nova, Blink, Ice Armor, Winter Field: **5**, no separate burst button. |

| Situation | Equipped example | What stays available but unequipped |
|---|---|---|
| Fire solo play with mobility | Fiery Spark, Fireball, Ice Wave, Blink, Fire Rain: **5** | Meteor for a delayed area strike, Flame Lance for single-target emphasis, or Ice Armor for protection. |
| Fire single-target emphasis | Fiery Spark, Ice Wave, Blink, Flame Lance, Fire Rain: **5** | Fireball, Meteor and Ice Armor. |
| Fire with one extra option | Either five-skill row plus one unequipped skill from that row: **6** | The remaining situational skills; no routine swap required. |
| Frost solo play | Cold Spark, Ice Nova, Blink, Ice Armor, Winter Field: **5** | Flame Lance if the mixed build bought it; use it as an optional sixth. |
| Mixed build | Fiery Spark, Ice Nova, Blink, Ice Armor, Meteor: **5** | Fireball or Flame Lance as an optional sixth. |

Four-skill setups can omit a situational ultimate or area spell when the
encounter does not need it. The target is satisfying ordinary play with four
to six skills, not a claim that every arbitrary subset is equally effective.
These loadouts still need playtesting for damage, flexibility and comfort.

A Fire ultimate build can deliberately buy basic Blink and Ice Armor, but
doing so spends points it could put into more offense. It cannot also acquire
Nova at 13 Rime points; deep Frost can improve its armor and control further.
The Fire-versus-Frost survival difference must still be measured, especially
for this defensive Fire hybrid. A Frost ultimate build can afford Flame Lance
at 7 Ember points but cannot reach Meteor at 13. Two ultimates require 42.

Do not add exclusions, point gates or an ownership limit solely to prevent
a seventh unlocked skill. The eight-skill Fire example is intentional. Its
ordinary effectiveness should not depend on swapping to cast every cooldown
in its repertoire; assess that incentive when deciding combat switching.

### 5.7 PvP and leveling checks still needed

- **Slow combination:** propose strongest hostile slow wins instead of the
  current additive slows. This is a cross-class change requiring a decision;
  do not silently apply it only to the Mage or change beneficial movement.
- **Repeated roots:** short, breakable roots still need a shared response to
  coordinated repeated control. Decide a simple common rule with the other
  classes before implementation; its exact immunity/diminishing duration is
  not settled here.
- **Damage advantage:** compare ordinary damage, burst windows, mana exhaustion
  and recovery on the same level/gear. The tables alone do not establish a
  balanced Fire-versus-Frost damage gap.
- **Leveling milestones:** compare the starter kit, first unlock, mid-level
  specialization, first ultimate and level 60. Returning to lower-level
  enemies should make growth visible; equal-level combat should gain options
  without turning every encounter into an instant kill.
- **Opponent cases:** melee closing successfully, ranged pressure, attacks
  from several directions, cover, escapes and two cooperating Mages. Verify
  that the free slow does not make an ordinary melee opponent helpless.
- **Cross-cast timing:** free Spark must not add a second damage stream during
  Flame Lance preparation. Cost/cooldown commitment and interruption rules
  must be specified using the existing authoritative input/cast path.
- **AoE legality:** test cover, vertical separation and each target's current
  PvP permission at settlement. No damage through walls or friendly targets.
- **Visual performance:** bounded emitters and lifetimes, especially several
  simultaneous ultimates; desktop and web GUI/runtime acceptance remain the
  user's tests.

### 5.8 Ice Cage and discarded Mage variants

**Ice Cage remains an open alternative to Winter Field**, not an approved
second Frost ultimate. The user's original idea was temporary ice blocks in
air around the caster, pushing enemies outward first, with an eye-level
shooting slit and destructible blocks. It has not been rejected or authorized.

The proposed constraints were a short lifetime, no drops, no overwriting of
existing blocks, a slit usable in both directions, and no creation where safe
displacement or protection rules cannot be respected. “Air only” is insufficient:
air in a protected doorway can still be important. Existing world-alteration
protection remains the default; no new exception has been approved. A non-node
barrier was mentioned, but its collision and destruction are not established.

The following earlier suggestions are not part of the worked candidate:
50% fire damage as an approved opening talent (the user gave an example);
Blink as a starter; mandatory Strike for an out-of-mana Mage; a Strike-based
Glutklinge passive; a separate Frost Lance button; a selectable Fire Rain /
Fire Aura ultimate. The earlier free Fireball replacement and Fireball/Cold
Spark exclusion are superseded by the user's correction: Fireball is a
separate skill and neither Spark ever gains splash damage.

### 5.9 Raycast targeting and area footprint proposal

This records the user's preferred direction, **not a finalized geometry or
runtime algorithm**. Meteor and Fire Rain determine their target point using
an aiming raycast limited to the spell's range. No separate ground cursor or
free location-selection UI is assumed. Once determined, the target point
stays fixed for that cast; it does not track the actor originally aimed at.
The same approach should be considered for other targeted area spells.

For a target point, a horizontal damage radius R and a separate vertical
allowance H, the proposed footprint is:

1. Consider x/z positions inside the horizontal radius around the target.
2. For each position, search only within target y minus H to target y plus H.
3. Choose the eligible surface or **whole air block** with the smallest
   absolute y-distance to the target point. Select one candidate per column,
   rather than all layers within that column.
4. If that column has no eligible candidate, leave it damage-free. Do not
   extend the search outside the vertical allowance to fill a gap.

The user's example was R = 5, with H around 2–3 blocks; the user explicitly
noted that radius 5 would already be large. These examples are not assigned
to every spell. Horizontal reach and vertical tolerance must be specified
separately for the final effects. The proposal does not authorize igniting,
placing or removing nodes.

Details to settle before implementation:

- **Target ray:** which node/actor contacts are eligible, how to derive the
  center from an intersection, and what happens on a miss or unloaded terrain.
  Follow the existing aiming seam `grug_core.aim_raycast` for rays involving
  objects; this handoff makes no new engine-feasibility claim.
- **Eligible cells:** what constitutes a usable surface or whole air block;
  whether support below is required; liquids, vegetation, partial node shapes,
  ceilings and stacked floors; deterministic ties between equal y-distances.
  Do not assume these questions are answered by “nearest air.”
- **Damage volume:** how a selected surface/cell becomes an occupied damage
  volume; how actor bodies overlap it; deduplication when one actor overlaps
  several cells; cover and line-of-sight rules. Selecting a nearby floor must
  not grant damage through an intervening wall or floor.
- **Common scope:** decide how explosions, self-centered Nova and directional
  Ice Wave use or specialize this model. The user suggested a common approach
  for area spells; those shapes must not silently become identical.
- **Runtime and performance:** bound the horizontal/vertical work from R and
  H, consider simultaneous casts and repeated pulses, choose when the footprint
  is built and whether it is reused or rebuilt if terrain changes, and define
  unloaded-area behavior and cleanup. Compare representative cases before
  choosing a caching or scheduling strategy; do not add wall-clock budgets.
- **Particles and duration:** warning and damage visuals must match the chosen
  cells, including gaps and height changes. Specify per-cast particle amounts,
  lifetimes, pulse timing and indoor appearance within the shared web budget.
  An empty column must not look like a damaging area when it cannot hit.

The numerical damage, cooldown and duration tables above remain initial tuning
proposals. Geometry, performance and visual checks are required before treating
any of these area spells as implementation-ready.

## 6 Talent tree presentation proposal

Store each node's position and real prerequisite edges once. Generate a
transparent line-art PNG per tree from those coordinates, and position the
Formspec buttons from the same data. Diagonal lines and branches then do not
depend on the current rectangle-based routing in
[talents_ui.lua](../../mods/PLAYER/grug_classes/talents_ui.lua).

Keep text, ranks, tooltips and locked/available/learned states in the buttons.
Start with neutral connector lines; highlighting learned paths using additional
image layers is optional. Avoid putting text in the background bitmap or
hand-maintaining a second copy of the dependency graph. Crossings without
buttons do not create dependencies. Arrowheads and point-gate bands should be
legible at narrow window sizes.

This is code-generated geometric artwork, not an image-generation task.
Validate the graph for cycles, missing parents, impossible gates and layout
overlap. Preview actual Formspec alignment and bitmap sharpness at desktop and
web sizes; keep the image and button coordinate transformations identical.

## 7 Inventory and input recommendations

### 7.1 Hotbar switching details

Persist the inactive eight stacks and the active A/B label with the player.
Start existing characters on A with their current hotbar untouched and B empty.
A switch exchanges the two rows completely, including empty slots. No item
copying, dropping, automatic skill placement or sorting accompanies the swap.

Recommended, but not yet approved: switching is allowed during combat so a
player surprised while mining can return to their combat layout. A switch
cancels a pending cast/charge/eating/held-input action and requires a fresh
press before the new selection acts. Cooldowns and already committed costs
are not refunded by switching. Specify release/commit timing before coding.

Recommended consumption order: retain each consumer's existing preference
and append the inactive layout as its last source. Recipe, quest and ammunition
counts must see the same eligible sources as their actual consumption. Any
refund or new grant follows normal insertion rules and **must not replenish
an inactive source automatically**. Capacity checks must exclude inactive
free slots from automatic grant capacity.

Skill representations may exist once in A and once in B; use one entitlement
and cooldown per character/skill. Cleanup removes invalid representations in
both immediately and resolves duplicates within each layout, never globally
across the two. **Buying Cold Spark replaces existing Fiery Spark representations
in both layouts immediately**, preserving their positions. It does not insert
a skill into an empty slot if neither layout held Fiery Spark. Fireball is a
separate unlock and follows the no-automatic-placement rule. Generalize other
transformation updates consistently during detailed planning; they must not
duplicate skills or reset cooldowns.

Two current seams deserve explicit attention:

- [storage.lua](../../mods/PLAYER/grug_inventory/storage.lua) separates carried
  item lists from the give/sort slot order. Include the inactive list for
  approved reads/consumption without adding it to deposit or sort destinations.
- [ability normalization](../../mods/PLAYER/grug_abilities/init.lua) currently
  traverses inventory lists with a global per-skill duplicate set;
  [bound item guards](../../mods/PLAYER/grug_skills/bound_items.lua) constrain
  skill placement. Both need layout-aware treatment. Do not loosen ordinary
  inventory placement just to permit the hidden second row.

Test swaps with full inventories, metadata-bearing items, partial consumption,
duplicate skill attempts, immediate respec cleanup, rapid switches, reconnects
and restarts. Confirm both dropdowns track the same active layout and never
trigger an unintended action when a form opens.

### 7.2 Consumables Belt and eating

Keep the current four belt slots as a first proposal; accept food as well as
potions and elixirs. Preserve each item's effects and restrictions. A belt
click must not turn food into an instant combat heal or impose potion
cooldowns on food.

**Recommended interaction, not yet decided:** clicking food in Quickbar E
closes the menu and starts one timed eating action from the selected belt
stack. No continued RMB hold is required. Keep the existing eating duration,
slow movement, progress feedback and combat restrictions. Consume one serving
on successful completion; a combat action, invalid source, death or layout
switch cancels it. Define cancellation before enabling this route.

For food held on the hotbar, decide whether RMB still uses the existing
click-versus-hold distinction or whether all eating moves to the belt. Keeping
the old hotbar gesture alongside the new explicit belt action is a possible
solution, not an approved final interaction. Placeable food still needs an
unambiguous world-placement action. Both routes should share one eating
lifecycle and cannot consume the same serving twice.

The current [input state machine](../../mods/PLAYER/grug_abilities/input.lua)
distinguishes a short RMB interaction from a held eating action. The E-menu
click must not be implemented by pretending that RMB is still held after the
menu closes. Review source-stack changes and simultaneous input explicitly.

### 7.3 Tools and everyday layouts

The user suggested removing shovels, absorbing their loose-ground function
into pickaxes, and combining the axe and hoe into a multifunction tool.
**These remain proposals**, not approved item deletions or recipes.

The current pickaxe already digs loose ground, more slowly than the shovel.
Removing the shovel should transfer comfortable digging performance, not merely
remove the faster option. A combined axe/hoe could chop on LMB and till suitable
ground on RMB. Keep tool progression and the roles of crafting professions in
view when deciding its recipes and price.

| Scenario | Possible layout |
|---|---|
| Exploration and mining | Up to six combat skills, pickaxe, torches |
| Surface gathering | Combat subset, axe/hoe or multifunction tool, torches |
| Farming | Work tools, seeds and harvesting/building items, selected combat skills |
| Building | Building materials and tools in B, combat layout in A |

A/B reduces the space pressure that motivated tool consolidation. Decide
whether separate tools contribute useful gameplay before removing them.

## 8 Continuation and future delivery

At the next session, read section 3 first, then the Mage candidate and
[open questions](../../TODO-design-classes.md). Confirm or revise the Mage's
actual nodes, starter count and tuning, then discuss Warrior, Priest and Scout
one at a time under the shared principles. Do not invent their kits from this
Mage example.

Only after those discussions should the coordinator turn the chosen scope
into a round plan. The existing next-round carry-overs remain in
[BACKLOG](../../BACKLOG.md#round-45-carry-overs) and
[the fix-round carry-overs](../../BACKLOG.md#0451-carry-overs); this handoff does
not silently cancel the waiting point, POI placement work or repair icon.

Expected upgrade implications, to verify when scope is frozen:

- The **documentation-only handoff is compatible** and changes no game state.
- New UI artwork, the belt label and an initially empty second hotbar can
  potentially be compatible additions.
- Replacing saved talent structures and removing item/skill representations
  likely requires a declared migration. Recommend refunding affected talent
  points for free, preserving character progress and belongings, and letting
  players place their new skills manually. Exact conversion/refund policy is
  still open.
- Tool removal or combination must account for existing tools wherever they
  are stored. Follow the existing offline migration tool and tested online
  runner where needed, never an ad hoc load conversion.
- None of the class/UI ideas inherently requires a map reset. Separately
  planned world-generation work must classify itself independently.

Before delivery, the eventual plan must cover independent review, relevant
fixtures, combat measurements, migration tests where needed, updated topic
owners and desktop/web GUI acceptance. No such implementation or gameplay
validation is claimed by this handoff.
