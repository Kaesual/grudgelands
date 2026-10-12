# Mage redesign review candidate

Prepared 2026-10-12. **Proposal for user review, not approved design or game
implementation.** This is the balancing correction to the Mage in
[the handoff](../class-redesign-handoff.md#5-mage-design-proposal).
The handoff's node graph, rank counts and worked point allocations remain
the baseline except for the explicit replacements below. Current delivery
is unchanged. The approved [future targeting contract](../../design/ability_targeting.md)
now governs interaction; graph and numerical tuning remain proposals.
See the [implementation design](implementation-design.md). Classification: **compatible,
documentation only**; eventual talent replacement likely needs migration.

## Identity and starting kit

Ember turns short opportunities into heavy damage; it needs space because its
damage does not also heal or protect it. Rime creates breathing room and
converts a successful control action into one strong attack. It should not
win ordinary solo fights by running in circles for a long time.

The user's [Priest/Fire damage ruling](../class-redesign-handoff.md#31-class-development-and-the-mage)
also preserves Ember's role: even the offensive Priest stays slightly below
Fire damage, with healing as its separate strength. Rime accepts lower damage
for slow/root control. The [cross-class review](balance.md#follow-up-priest-damage-below-fire)
contains the corresponding Priest correction and comparison; no further Mage
coefficient increase is proposed merely to restore that hierarchy.

Start with **Fiery Spark and Ice Wave**. Spark replaces Strike at creation,
is free, single target and releases no faster than once per second. Ice Wave
is a short cone for buying space. Blink, Ice Armor and the larger attacks
are earned. The starter count remains a proposal; initial hotbar placement
remains the handoff's open question.

**D** means `(baseline_weapon_damage(L) + Int/10) * level_scale(L)` before
crit, mitigation and the one final rounding. No second gear multiplier is
added. This follows the existing damaging-spell axis in
[combat_stats](../../design/combat_stats.md#2-player-formulas) and
`grug_abilities/kits.lua:543`. With the Mage's native Intelligence and no
enchants, D is P/8 before rounding. **P** is the neutral pool, **K** the
armor constant and **S** the existing support factor, where applicable.

## Correction round

| Element | Revised candidate | Reason |
|---|---|---|
| Fireball / F4 | 1.60D to the primary target, 0.15D to other enemies within 2 m; 5 s cooldown, 6% P mana; 1 s occupied attack action. | The former 1.10D bought almost no extra single-target damage over the free Spark it displaces. |
| Flame Lance / F5 | 2.20D, 1.25 s stationary preparation, 8 s cooldown, 10% P mana, 20 m. Movement cancels preparation. | The paid prepared hit must repay its lost free attacks and exposure. |
| Meteor / F8 | Keep 1.40D, 3 m radius, 1.5 s warning, 18 s cooldown, 14% P, 20 m targeting. Preview the crosshair-derived enemy-footpoint/terrain anchor; fix it on accepted activation. Invalid placement costs nothing. | Its advantage is several targets; it need not be the best single-target filler. |
| Fire Rain / F12 | Five 0.55D pulses at one-second intervals after a 1 s warning; radius 4 m, 60 s cooldown, 22% P, range 20 m. Preview and fix the crosshair-derived area anchor on accepted activation; no tracking after release. | A visible area ultimate needs an appreciable payoff if enemies remain in it. |
| Ice Nova / R9 | Keep its replacement of Ice Wave; raise damage from 0.35D to 0.65D; retain 1.75 s damage-breaking root, 18 s cooldown and 10% P cost. | Less of the Frost player's action is sacrificed for control. |
| Cold Shock / R10 | Next Cold Spark within 4 s gains +0.25/0.50/0.75D after Nova affects an enemy; one charge per Nova. Requires R9 and R1. | A noticeable single-target payoff on an existing button instead of another required skill. |
| Winter Field / R13 | Keep six one-second 0.15D pulses after a 0.75 s warning, 4 m radius, range 15 m, 60 s cooldown and 18% P. Keep 35% slow inside, at most 0.5 s lingering. Preview and fix the crosshair-derived anchor on accepted activation. | Shares the approved area-targeting interaction; damage and control values are unchanged. |
| Projectile counterplay | Cover matters before release. Existing targeted homing shots are not intercepted by new cover during flight. | Correct the handoff's misleading reference to projectile cover; do not invent a different engine contract. |

Everything else in the handoff's two talent tables remains the candidate:
**32 Ember ranks, 33 Rime ranks**, 30 points at level 60. Fire Mastery's
+5/10/15/20% and Heat Focus's +5/10/15% of untalented Lance add, not compound.
Afterglow stays 0.05/0.10/0.15D total over 3 s; Wide Ember sets splash to
0.20/0.25/0.30D. Primary and splash hits never both hit the primary target.
Burn refreshes never add an immediate extra tick. No Spark gains splash.

Cold Spark replaces Fiery Spark in both layouts, stays free and single target,
and loses fire bonuses. Fireball remains separately available. Ice Cage
remains an unresolved alternative to Winter Field; this candidate uses Winter
Field and places no ice nodes.

## Cast timing and counterplay

Propose one occupied action timeline for the Mage: Spark, Fireball, Ice Wave,
Nova, Meteor, Fire Rain, Winter Field, Blink and Ice Armor reserve **1 s**
before another attack/support action may start. Instant skills release at
the beginning of their action; this is recovery time, not a new one-second
input delay. Flame Lance reserves **1.25 s**, releases at its end and has no
additional one-second recovery. No Spark starts during preparation or a
paid skill's occupied time. Existing in-flight hits and previously committed
area pulses may settle during another action.

Costs and cooldowns commit once on valid release. Preparation may start only
after the skill cooldown ends; no pre-casting during a remaining cooldown.
Thus Lance releases recur no sooner than 8 + 1.25 = 9.25 s. An interrupted Lance has
no hit, cost or cooldown, but its already reserved preparation time remains
occupied; no queue of Sparks is banked. Switching layouts cancels preparation
without resetting the action time or any committed cooldown. A dead or invalid
target at release refuses the cast. Projectile impact has its normal separate
lifecycle and permission checks. Ordinary hotbar selection must not bypass
this timeline. These are input proposals requiring later integration with the
existing held-input owner, not a second independently running attack clock.

The current projectile facts are in
[classes](../../design/classes.md#rules-for-hostile-casts-and-projectiles)
and [combat_stats](../../design/combat_stats.md#hostile-casts-and-projectiles-shipped-with-wp39).
Lance's useful counterplay is moving behind cover **during its visible
preparation**, closing on the caster, or forcing movement. Spark has no
long preparation window. Do not promise that moving behind a wall after
release makes an existing homing projectile disappear.

Area attacks still need the handoff's footprint/cover work: ray-derived fixed
centers, one eligible vertical layer per column, no through-wall or through-floor
area damage, no node edits. For Fireball, the primary homing hit follows the
existing contract; secondary splash needs its own impact-centered cover check.
Warnings do not follow a moving target. The conceptual one-second action
does not replace the delayed impact/warning durations in the spell tables.

The [approved area interaction](../../design/ability_targeting.md#4-fixed-area-points-and-previews)
now resolves the former free-cursor ambiguity: preview while selected, capture
enemy footpoint or eligible terrain on activation, and refuse invalid placement
without payment. Radius/height/cover geometry remains a planning dependency;
neither a preview nor an actor-derived anchor authorizes hitting through walls.

## Two trees and useful builds

| Tree | Early identity | Middle growth | Ultimate | Ordinary five-skill example |
|---|---|---|---|---|
| Ember | Level 2 Fire Mastery; level 6 separate Fireball | Level 14 Flame Lance; level 26 Meteor | Fire Rain, earliest level 42 | Spark, Fireball, Ice Wave, Meteor, Fire Rain for pure Fire; a 21/9 build may replace Meteor with Blink. |
| Rime | Level 2 Cold Spark; level 6 Blink | Level 14 Ice Armor; level 26 Nova transformation; Cold Shock develops after buying Nova | Winter Field, earliest level 42 | Cold Spark, Ice Nova, Blink, Ice Armor, Winter Field. |

The handoff's five purchase sequences remain legal because no rank, point gate
or dependency changes. The 21 Ember / 9 Rime build owns eight skills but uses
five or six. A 15/15 mixed build gains both early toolsets and no ultimate.
Pure Frost requires no Ember investment. A prepared Fire hit is an optional
sixth skill in a hybrid Frost loadout, not necessary for viable damage.

The practical Ember choice is Fireball for repeatable pressure, Lance for a
prepared single-target hit, or Meteor for groups. Equipping all three should
not be required to reach ordinary effectiveness. A free attack and reliable
control remain useful even when mana is exhausted.

## Arithmetic checks and their limits

On one stationary, unarmored target, no crits or travel time, full F1 and
F7 give a Fireball action **1.92D + 0.18D burn**, replacing a **1.20D**
Spark action. That is +0.90D per 5 s, or +0.18D/s when used on cooldown and
every burn completes. Continuous Fireball plus free fillers is approximately
**1.38D/s**, before rounding and finite-window edge effects. It spends
**1.2% P/s** before cost talents; it does not sustain indefinitely from
the level-60 base regeneration of 0.25% maximum mana/s.

With full F1/F6, Lance deals `2.20D * (1 + 0.20 + 0.15) = 2.97D`.
Its 1.25 s action displaces roughly 1.50D of Fire Sparks, so its long-run
increment is about **1.47D per 9.25 s** (cooldown plus preparation). This is a continuous-time opportunity
estimate, not permission to fit fractional attacks into a short fight.

Full Cold Shock makes Nova plus its next Spark **0.65D + 1.75D = 2.40D**
in two occupied actions, versus 2D of free Frost attacks. The net damage gain
is modest, but the second hit is visibly stronger and the root buys space.
At Returning Cold 3/3, the pair can recur every 15 s: about **1.027D/s**
for basic attacks plus that pair. Winter Field adds damage only when the
enemy actually remains in its area. Fire is still the damage specialist.

These numbers establish that the buttons have a purpose; they do **not** prove
that the Fire/Frost gap or all four classes are balanced. Compare practical
kill cycles, damage received, defensive actions and recovery in the cross-class
review. Do not make up a fixed percent parity gate from these estimates.

## Survival and shared open decisions

Fire's 21/9 hybrid can afford Blink and basic Ice Armor. Basic Ice Armor's
+0.20K for 6 s is not the deep Frost version's +0.32K for up to 7.5 s.
Both use the ordinary armor curve and 24 s cooldown, never a flat reduction
or immunity. Selecting protection also occupies an action and a hotbar slot.
This hybrid must be compared explicitly, rather than describing every Fire
build as having no defensive options.

The slow/CC risk is material: the handoff's full 18% Cold Spark slow makes
a standard 4.6 m/s melee pursuer move at **3.772 m/s**, below the player's
4 m/s. A freely mobile Spark could then enable indefinite open-ground kiting.
**Correction proposal:** replace R3's 14/16/18% slow with **12/12/12%** and
instead add **+0.03/0.06/0.09D to Cold Spark’s base direct hit**, additive
with Cold Shock and never multiplying its bonus. Rename R3 **Keen Cold**.
R1 retains its 12% slow, 1.5 s refresh and single-target conversion. A standard
4.6 m/s pursuer still closes at 4.048 m/s under it; this alone does not prove
fairness against slower enemies or PvP. This changes no point arithmetic.
With Keen Cold 3/3, the Nova/Spark pair is 0.65D + 1.84D, and sustained free
Frost plus that pair is approximately **1.111D/s**, since the pair replaces
two 1.09D Sparks. Fireball's 1.38D/s comparison then remains about 24% higher.

For all classes, strongest-only hostile slows and a short shared protection
against repeated player roots/stuns remain proposed shared rules, not
silently approved changes. Coordinated control, slows from other sources,
melee closers, ranged enemies and restricted terrain need explicit checks.
Absorbed melee hits triggering Ice Armor remain unresolved. No claim of
finished PvP balance or engine feasibility is made here.

Visual design is deferred. The later brief must give each effect a numeric
particle budget and test concurrent casts within the shared web limit.
